#!/bin/bash

set -euo pipefail

SKILLS_URL="https://raw.githubusercontent.com/sagewarehq/engram-ansible/master/skills.txt"

AGENTS=(
    "antigravity" "augment" "claude-code" "openclaw" "codebuddy" "command-code"
    "continue" "cortex" "crush" "cursor" "droid" "gemini-cli" "github-copilot"
    "goose" "junie" "iflow-cli" "kilo" "kiro-cli" "kode" "mcpjam" "mistral-vibe"
    "mux" "opencode" "openhands" "pi" "qoder" "qwen-code" "roo" "trae" "trae-cn"
    "windsurf" "zencoder" "neovate" "pochi" "adal" "amp" "kimi-cli" "replit"
    "cline" "codex"
)

BANNER=(
    "███████╗██╗  ██╗██╗██╗     ██╗     ███████╗"
    "██╔════╝██║ ██╔╝██║██║     ██║     ██╔════╝"
    "███████╗█████╔╝ ██║██║     ██║     ███████╗"
    "╚════██║██╔═██╗ ██║██║     ██║     ╚════██║"
    "███████║██║  ██╗██║███████╗███████╗███████║"
    "╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝"
)

cleanup() {
    stty echo icanon 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

die() {
    cleanup
    printf "\n%s\n" "$1"
    exit "${2:-1}"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        die "Error: $1 is not installed."
    fi
}

repeat_char() {
    local char="$1"
    local count="$2"
    local out=""
    local i
    for ((i = 0; i < count; i++)); do
        out+="$char"
    done
    printf "%s" "$out"
}

render_banner() {
    local line
    for line in "${BANNER[@]}"; do
        printf "%s\n" "$line"
    done
}

fetch_skills() {
    local raw
    printf "Fetching skills list...\n"
    raw="$(curl -fsSL "$SKILLS_URL")"

    SKILLS=()
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
            SKILLS+=("$line")
        fi
    done <<< "$raw"

    if [ ${#SKILLS[@]} -eq 0 ]; then
        die "No skills found in remote list."
    fi
}

init_selection() {
    local -n items_ref=$1
    local -n selected_ref=$2
    local i

    selected_ref=()
    for i in "${!items_ref[@]}"; do
        selected_ref[$i]=0
    done
}

count_selected() {
    local -n selected_ref=$1
    local count=0
    local i

    for i in "${!selected_ref[@]}"; do
        if [ "${selected_ref[$i]}" -eq 1 ]; then
            count=$((count + 1))
        fi
    done

    printf "%s" "$count"
}

sync_all_flag() {
    local -n items_ref=$1
    local -n selected_ref=$2
    local -n all_ref=$3
    local selected_count

    selected_count="$(count_selected selected_ref)"
    if [ "$selected_count" -eq "${#items_ref[@]}" ] && [ "${#items_ref[@]}" -gt 0 ]; then
        all_ref=1
    else
        all_ref=0
    fi
}

move_cursor() {
    local direction="$1"
    local max_index="$2"
    local -n current_ref=$3

    if [ "$direction" = "up" ]; then
        if [ "$current_ref" -gt -1 ]; then
            current_ref=$((current_ref - 1))
        fi
    else
        if [ "$current_ref" -lt "$max_index" ]; then
            current_ref=$((current_ref + 1))
        fi
    fi
}

toggle_item() {
    local -n selected_ref=$1
    local index="$2"

    if [ "${selected_ref[$index]}" -eq 1 ]; then
        selected_ref[$index]=0
    else
        selected_ref[$index]=1
    fi
}

toggle_all() {
    local -n selected_ref=$1
    local -n all_ref=$2
    local i
    local next_value=1

    if [ "$all_ref" -eq 1 ]; then
        next_value=0
    fi

    for i in "${!selected_ref[@]}"; do
        selected_ref[$i]=$next_value
    done

    all_ref=$next_value
}

build_chosen_items() {
    local -n items_ref=$1
    local -n selected_ref=$2
    local -n chosen_ref=$3
    local i

    chosen_ref=()
    for i in "${!items_ref[@]}"; do
        if [ "${selected_ref[$i]}" -eq 1 ]; then
            chosen_ref+=("${items_ref[$i]}")
        fi
    done
}

get_key() {
    local key rest

    IFS= read -rsn1 key || true
    if [[ -z "$key" ]]; then
        echo ""
        return
    fi

    case "$key" in
        $'\x1b')
            IFS= read -rsn2 -t 0.01 rest || true
            case "$rest" in
                '[A') echo "UP" ;;
                '[B') echo "DOWN" ;;
                *) echo "ESC" ;;
            esac
            ;;
        "")
            echo "ENTER"
            ;;
        $'\n'|$'\r')
            echo "ENTER"
            ;;
        " ")
            echo "SPACE"
            ;;
        q|Q)
            echo "QUIT"
            ;;
        j|J)
            echo "DOWN"
            ;;
        k|K)
            echo "UP"
            ;;
        a|A)
            echo "TOGGLE_ALL"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

draw_picker() {
    local title="$1"
    local subtitle="$2"
    local all_label="$3"
    local -n items_ref=$4
    local -n selected_ref=$5
    local current="$6"
    local all_selected="$7"
    local window_start="$8"
    local window_size="$9"

    local selected_count total end i marker radio label width
    selected_count="$(count_selected selected_ref)"
    total=${#items_ref[@]}
    end=$((window_start + window_size))
    if [ "$end" -gt "$total" ]; then
        end=$total
    fi

    width=70

    tput cup 0 0
    render_banner
    printf "\n"
    printf ".%s.\n" "$(repeat_char "-" "$width")"
    printf "| %-68s |\n" "$title"
    printf "| %-68s |\n" "$subtitle"
    printf "| %-68s |\n" "Selected: $selected_count/$total  |  arrows or j/k to move  |  space to toggle"
    printf "| %-68s |\n" "a toggles all  |  enter confirms  |  q quits"
    printf "'%s'\n\n" "$(repeat_char "-" "$width")"

    if [ "$current" -eq -1 ]; then
        marker=">"
    else
        marker=" "
    fi
    if [ "$all_selected" -eq 1 ]; then
        radio="[x]"
    else
        radio="[ ]"
    fi
    printf "%s %s %s\n\n" "$marker" "$radio" "$all_label"

    if [ "$window_start" -gt 0 ]; then
        printf "  ... %s above ...\n" "$window_start"
    fi

    for ((i = window_start; i < end; i++)); do
        if [ "$i" -eq "$current" ]; then
            marker=">"
        else
            marker=" "
        fi

        if [ "${selected_ref[$i]}" -eq 1 ]; then
            radio="[x]"
        else
            radio="[ ]"
        fi

        label="${items_ref[$i]}"
        printf "%s %s %s\n" "$marker" "$radio" "$label"
    done

    if [ "$end" -lt "$total" ]; then
        printf "  ... %s more ...\n" "$((total - end))"
    fi

    tput ed
}

run_picker() {
    local title="$1"
    local subtitle="$2"
    local all_label="$3"
    local -n items_ref=$4
    local -n selected_ref=$5
    local window_size="$6"

    local current=-1
    local all_selected=0
    local window_start=0
    local max_index=$(( ${#items_ref[@]} - 1 ))
    local key

    while true; do
        if [ "$current" -ge 0 ]; then
            if [ "$current" -lt "$window_start" ]; then
                window_start=$current
            elif [ "$current" -ge $((window_start + window_size)) ]; then
                window_start=$((current - window_size + 1))
            fi
        else
            window_start=0
        fi

        draw_picker "$title" "$subtitle" "$all_label" items_ref selected_ref "$current" "$all_selected" "$window_start" "$window_size"
        key="$(get_key)"

        case "$key" in
            UP)
                move_cursor up "$max_index" current
                ;;
            DOWN)
                move_cursor down "$max_index" current
                ;;
            SPACE)
                if [ "$current" -eq -1 ]; then
                    toggle_all selected_ref all_selected
                else
                    toggle_item selected_ref "$current"
                    sync_all_flag items_ref selected_ref all_selected
                fi
                ;;
            TOGGLE_ALL)
                toggle_all selected_ref all_selected
                ;;
            ENTER)
                break
                ;;
            QUIT|ESC)
                die "Installation cancelled." 0
                ;;
        esac
    done
}

install_skills() {
    local -n skills_ref=$1
    local -n agents_ref=$2
    local installed=0
    local failed=0
    local skill owner repo skill_name cmd agent
    local -a cmd_parts

    printf "Installing %s skill(s) to %s agent(s)...\n\n" "${#skills_ref[@]}" "${#agents_ref[@]}"

    for skill in "${skills_ref[@]}"; do
        printf "-> %s\n" "$skill"
        cmd_parts=(npx skills add)

        if [[ "$skill" =~ ^([^/]+)/([^/]+)/(.+)$ ]]; then
            owner="${BASH_REMATCH[1]}"
            repo="${BASH_REMATCH[2]}"
            skill_name="${BASH_REMATCH[3]}"
            cmd_parts+=("${owner}/${repo}" --skill "$skill_name")
        else
            cmd_parts+=("$skill")
        fi

        for agent in "${agents_ref[@]}"; do
            cmd_parts+=(-a "$agent")
        done
        cmd_parts+=(-y)

        if "${cmd_parts[@]}"; then
            printf "   ok\n\n"
            installed=$((installed + 1))
        else
            printf "   failed\n\n"
            failed=$((failed + 1))
        fi
    done

    printf "Done. Installed: %s" "$installed"
    if [ "$failed" -gt 0 ]; then
        printf "  Failed: %s" "$failed"
    fi
    printf "\n"
}

main() {
    local -a SKILLS=()
    local -a AGENT_SELECTED=()
    local -a SKILL_SELECTED=()
    local -a SELECTED_AGENTS=()
    local -a SELECTED_SKILLS=()

    require_command npx
    require_command curl
    require_command tput
    require_command stty

    trap cleanup EXIT INT TERM

    stty -echo -icanon time 0 min 0
    tput civis

    init_selection AGENTS AGENT_SELECTED
    run_picker \
        "Select Agents" \
        "Choose which agent integrations receive the skills." \
        "All agents" \
        AGENTS AGENT_SELECTED 14

    build_chosen_items AGENTS AGENT_SELECTED SELECTED_AGENTS
    if [ ${#SELECTED_AGENTS[@]} -eq 0 ]; then
        die "No agents selected." 0
    fi

    tput clear
    fetch_skills
    init_selection SKILLS SKILL_SELECTED
    run_picker \
        "Select Skills" \
        "Choose which skills to install from the remote list." \
        "All skills" \
        SKILLS SKILL_SELECTED 12

    build_chosen_items SKILLS SKILL_SELECTED SELECTED_SKILLS
    if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
        die "No skills selected." 0
    fi

    cleanup
    trap - EXIT INT TERM
    tput clear
    install_skills SELECTED_SKILLS SELECTED_AGENTS
}

main "$@"
