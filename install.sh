#!/bin/bash

# ── Engram Skills Installer ─────────────────────────────────────────
# Portable across macOS Bash 3.2 and Zsh.
# All state is in global scalars. No array indexing. No namerefs.
# No C-style for-loops. No IFS word splitting (uses parameter expansion).

SKILLS_URL="https://raw.githubusercontent.com/sagewarehq/engram-ansible/master/skills.txt"

AGENTS=(
    antigravity augment claude-code openclaw codebuddy command-code
    continue cortex crush cursor droid gemini-cli github-copilot
    goose junie iflow-cli kilo kiro-cli kode mcpjam mistral-vibe
    mux opencode openhands pi qoder qwen-code roo trae trae-cn
    windsurf zencoder neovate pochi adal amp kimi-cli replit
    cline codex
)

# ── Picker state (all global scalars) ────────────────────────────────
PICKER_ITEMS_STR=""   # newline-delimited items
PICKER_SEL_STR=""     # comma-delimited 0/1
PICKER_TOTAL=0
PICKER_CURRENT=-1
PICKER_ALL=0
PICKER_WIN_START=0
PICKER_WIN_SIZE=0
PICKER_TITLE=""
PICKER_SUBTITLE=""
PICKER_ALL_LABEL=""

PICKER_RESULT_STR=""
PICKER_RESULT_COUNT=0

_LAST_KEY=""

# ── Helpers ──────────────────────────────────────────────────────────

cleanup() {
    stty echo icanon 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

die() {
    cleanup
    printf "\n%s\n" "$1"
    exit "${2:-1}"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Error: $1 is not installed."
}

render_banner() {
    cat <<'BANNER'
     _    _ _ _           _
 ___| | _(_) | |___   ___| |__
/ __| |/ / | | / __| / __| '_ \
\__ \   <| | | \__ \_\__ \ | | |
|___/_|\_\_|_|_|___(_)___/_| |_|
BANNER
}

# Banner takes 5 lines. Header (title/subtitle/hints) takes 7 lines.
# "All" row + blank line = 2. Scroll indicators = up to 2.
# Total chrome = 5 + 1 + 7 + 2 + 2 = 17 lines.
PICKER_CHROME_LINES=17
_NEEDS_REDRAW=0

get_term_lines() {
    local lines
    lines=$(tput lines 2>/dev/null) || lines=24
    printf "%s" "$lines"
}

# Recalculate how many items can fit in the visible window.
picker_recalc_win_size() {
    local term_lines
    term_lines=$(get_term_lines)
    PICKER_WIN_SIZE=$((term_lines - PICKER_CHROME_LINES))
    if [ "$PICKER_WIN_SIZE" -lt 3 ]; then
        PICKER_WIN_SIZE=3
    fi
    if [ "$PICKER_WIN_SIZE" -gt "$PICKER_TOTAL" ]; then
        PICKER_WIN_SIZE=$PICKER_TOTAL
    fi
}

handle_winch() {
    _NEEDS_REDRAW=1
}

# ── CSV helpers (pure parameter expansion, no IFS tricks) ────────────

# Get the N-th value (0-based) from a comma-delimited string.
nth_csv() {
    local _str="$1" _idx="$2"
    local _i=0 _val
    while true; do
        case "$_str" in
            *,*)
                _val="${_str%%,*}"
                _str="${_str#*,}"
                ;;
            *)
                _val="$_str"
                _str=""
                ;;
        esac
        if [ "$_i" -eq "$_idx" ]; then
            printf "%s" "$_val"
            return
        fi
        _i=$((_i + 1))
        if [ -z "$_str" ]; then
            printf "0"
            return
        fi
    done
}

# Set the N-th value (0-based) in a comma-delimited string.
set_csv() {
    local _str="$1" _idx="$2" _new="$3"
    local _i=0 _val _result=""
    while true; do
        case "$_str" in
            *,*)
                _val="${_str%%,*}"
                _str="${_str#*,}"
                ;;
            *)
                _val="$_str"
                _str=""
                ;;
        esac
        if [ "$_i" -eq "$_idx" ]; then
            _val="$_new"
        fi
        if [ -n "$_result" ]; then
            _result="$_result,$_val"
        else
            _result="$_val"
        fi
        _i=$((_i + 1))
        if [ -z "$_str" ]; then
            break
        fi
    done
    printf "%s" "$_result"
}

# Count "1" values in a comma-delimited string.
count_ones() {
    local _str="$1"
    local _count=0 _val
    while true; do
        case "$_str" in
            *,*)
                _val="${_str%%,*}"
                _str="${_str#*,}"
                ;;
            *)
                _val="$_str"
                _str=""
                ;;
        esac
        if [ "$_val" = "1" ]; then
            _count=$((_count + 1))
        fi
        if [ -z "$_str" ]; then
            break
        fi
    done
    printf "%s" "$_count"
}

# Build a comma-delimited string of N copies of a value.
fill_csv() {
    local _n="$1" _v="$2"
    local _result="" _i=0
    while [ "$_i" -lt "$_n" ]; do
        if [ -n "$_result" ]; then
            _result="$_result,$_v"
        else
            _result="$_v"
        fi
        _i=$((_i + 1))
    done
    printf "%s" "$_result"
}

# ── Newline-string helpers ───────────────────────────────────────────

# Get the N-th line (0-based) from a newline-delimited string.
nth_line() {
    local _str="$1" _idx="$2"
    local _i=0 _line
    while IFS= read -r _line; do
        if [ "$_i" -eq "$_idx" ]; then
            printf "%s" "$_line"
            return
        fi
        _i=$((_i + 1))
    done <<NTHEOF
$_str
NTHEOF
}

# ── Key reader ───────────────────────────────────────────────────────
# Writes to the global _LAST_KEY. Does NOT use a subshell.
# Uses `read -k 1` for zsh (its native single-char read) and
# `read -n 1` for bash. In zsh, -n is a non-blocking test flag,
# not a character count — so `read -rsn1` returns immediately.

_read_one_char() {
    # $1 = variable name to assign
    if [ -n "${ZSH_VERSION:-}" ]; then
        IFS= read -rsk 1 "$1" </dev/tty 2>/dev/null || true
    else
        IFS= read -rsn1 "$1" </dev/tty 2>/dev/null || true
    fi
}

read_key() {
    _LAST_KEY=""
    local _rk=""
    _read_one_char _rk

    if [ "${_rk:-}" = $'\x1b' ]; then
        local _rk1="" _rk2=""
        _read_one_char _rk1
        _read_one_char _rk2
        case "${_rk1:-}${_rk2:-}" in
            '[A') _LAST_KEY="UP" ;;
            '[B') _LAST_KEY="DOWN" ;;
            *)    _LAST_KEY="ESC" ;;
        esac
    elif [ -z "${_rk:-}" ] || [ "${_rk:-}" = $'\n' ]; then
        _LAST_KEY="ENTER"
    elif [ "$_rk" = " " ]; then
        _LAST_KEY="SPACE"
    elif [ "$_rk" = "q" ] || [ "$_rk" = "Q" ]; then
        _LAST_KEY="QUIT"
    elif [ "$_rk" = "j" ] || [ "$_rk" = "J" ]; then
        _LAST_KEY="DOWN"
    elif [ "$_rk" = "k" ] || [ "$_rk" = "K" ]; then
        _LAST_KEY="UP"
    elif [ "$_rk" = "a" ] || [ "$_rk" = "A" ]; then
        _LAST_KEY="TOGGLE_ALL"
    fi
}

# ── Picker logic ─────────────────────────────────────────────────────

picker_sync_all() {
    local _sel
    _sel=$(count_ones "$PICKER_SEL_STR")
    if [ "$PICKER_TOTAL" -gt 0 ] && [ "$_sel" -eq "$PICKER_TOTAL" ]; then
        PICKER_ALL=1
    else
        PICKER_ALL=0
    fi
}

picker_toggle() {
    if [ "$PICKER_CURRENT" -eq -1 ]; then
        if [ "$PICKER_ALL" -eq 1 ]; then
            PICKER_SEL_STR=$(fill_csv "$PICKER_TOTAL" 0)
            PICKER_ALL=0
        else
            PICKER_SEL_STR=$(fill_csv "$PICKER_TOTAL" 1)
            PICKER_ALL=1
        fi
    else
        local _cv
        _cv=$(nth_csv "$PICKER_SEL_STR" "$PICKER_CURRENT")
        if [ "$_cv" = "1" ]; then
            PICKER_SEL_STR=$(set_csv "$PICKER_SEL_STR" "$PICKER_CURRENT" 0)
        else
            PICKER_SEL_STR=$(set_csv "$PICKER_SEL_STR" "$PICKER_CURRENT" 1)
        fi
        picker_sync_all
    fi
}

picker_toggle_all() {
    if [ "$PICKER_ALL" -eq 1 ]; then
        PICKER_SEL_STR=$(fill_csv "$PICKER_TOTAL" 0)
        PICKER_ALL=0
    else
        PICKER_SEL_STR=$(fill_csv "$PICKER_TOTAL" 1)
        PICKER_ALL=1
    fi
}

picker_draw() {
    picker_recalc_win_size

    local sel_count marker radio
    sel_count=$(count_ones "$PICKER_SEL_STR")

    # Clamp cursor and window to current dimensions
    if [ "$PICKER_CURRENT" -ge 0 ]; then
        if [ "$PICKER_CURRENT" -lt "$PICKER_WIN_START" ]; then
            PICKER_WIN_START=$PICKER_CURRENT
        elif [ "$PICKER_CURRENT" -ge $((PICKER_WIN_START + PICKER_WIN_SIZE)) ]; then
            PICKER_WIN_START=$((PICKER_CURRENT - PICKER_WIN_SIZE + 1))
        fi
    else
        PICKER_WIN_START=0
    fi
    if [ "$PICKER_WIN_START" -lt 0 ]; then
        PICKER_WIN_START=0
    fi

    local end=$((PICKER_WIN_START + PICKER_WIN_SIZE))
    if [ "$end" -gt "$PICKER_TOTAL" ]; then end=$PICKER_TOTAL; fi

    tput clear
    render_banner
    printf "\n"
    printf "%s\n" "$PICKER_TITLE"
    printf "%s\n" "$PICKER_SUBTITLE"
    printf "Selected: %s/%s  |  arrows/j/k  |  space  |  a=all  |  enter  |  q\n\n" "$sel_count" "$PICKER_TOTAL"

    marker=" "; radio="[ ]"
    if [ "$PICKER_CURRENT" -eq -1 ]; then marker=">"; fi
    if [ "$PICKER_ALL" -eq 1 ]; then radio="[x]"; fi
    printf "%s %s %s\n\n" "$marker" "$radio" "$PICKER_ALL_LABEL"

    if [ "$PICKER_WIN_START" -gt 0 ]; then
        printf "  ... %s above ...\n" "$PICKER_WIN_START"
    fi

    local _di=$PICKER_WIN_START
    local _d_item _d_val
    while [ "$_di" -lt "$end" ]; do
        _d_item=$(nth_line "$PICKER_ITEMS_STR" "$_di")
        _d_val=$(nth_csv "$PICKER_SEL_STR" "$_di")

        marker=" "; radio="[ ]"
        if [ "$_di" -eq "$PICKER_CURRENT" ]; then marker=">"; fi
        if [ "$_d_val" = "1" ]; then radio="[x]"; fi
        printf "%s %s %s\n" "$marker" "$radio" "$_d_item"
        _di=$((_di + 1))
    done

    if [ "$end" -lt "$PICKER_TOTAL" ]; then
        printf "  ... %s more ...\n" "$((PICKER_TOTAL - end))"
    fi
}

picker_run() {
    local max_index=$((PICKER_TOTAL - 1))

    trap handle_winch WINCH 2>/dev/null || true

    while true; do
        # Handle pending resize
        if [ "$_NEEDS_REDRAW" -eq 1 ]; then
            _NEEDS_REDRAW=0
            picker_draw
            continue
        fi

        picker_draw
        read_key

        case "$_LAST_KEY" in
            UP)
                if [ "$PICKER_CURRENT" -gt -1 ]; then
                    PICKER_CURRENT=$((PICKER_CURRENT - 1))
                fi
                ;;
            DOWN)
                if [ "$PICKER_CURRENT" -lt "$max_index" ]; then
                    PICKER_CURRENT=$((PICKER_CURRENT + 1))
                fi
                ;;
            SPACE)
                picker_toggle
                ;;
            TOGGLE_ALL)
                picker_toggle_all
                ;;
            ENTER)
                trap - WINCH 2>/dev/null || true
                break
                ;;
            QUIT|ESC)
                die "Installation cancelled." 0
                ;;
        esac
    done
}

# Initialise picker from positional arguments.
picker_setup() {
    PICKER_TITLE="$1";     shift
    PICKER_SUBTITLE="$1";  shift
    PICKER_ALL_LABEL="$1"; shift
    shift  # ignore legacy win_size argument; computed dynamically

    PICKER_CURRENT=-1
    PICKER_ALL=0
    PICKER_WIN_START=0
    PICKER_TOTAL=$#

    PICKER_ITEMS_STR=""
    local _first=1
    for _ps_item in "$@"; do
        if [ "$_first" -eq 1 ]; then
            PICKER_ITEMS_STR="$_ps_item"
            _first=0
        else
            PICKER_ITEMS_STR="$PICKER_ITEMS_STR
$_ps_item"
        fi
    done

    PICKER_SEL_STR=$(fill_csv "$PICKER_TOTAL" 0)
    picker_recalc_win_size
}

# Initialise picker from an already-built newline-delimited string + count.
picker_setup_from_str() {
    PICKER_TITLE="$1"
    PICKER_SUBTITLE="$2"
    PICKER_ALL_LABEL="$3"
    PICKER_ITEMS_STR="$4"
    PICKER_TOTAL="$5"

    PICKER_CURRENT=-1
    PICKER_ALL=0
    PICKER_WIN_START=0
    PICKER_SEL_STR=$(fill_csv "$PICKER_TOTAL" 0)
    picker_recalc_win_size
}

picker_collect() {
    PICKER_RESULT_STR=""
    PICKER_RESULT_COUNT=0
    local _pc_i=0 _pc_val _pc_item
    while [ "$_pc_i" -lt "$PICKER_TOTAL" ]; do
        _pc_val=$(nth_csv "$PICKER_SEL_STR" "$_pc_i")
        if [ "$_pc_val" = "1" ]; then
            _pc_item=$(nth_line "$PICKER_ITEMS_STR" "$_pc_i")
            if [ -n "$PICKER_RESULT_STR" ]; then
                PICKER_RESULT_STR="$PICKER_RESULT_STR
$_pc_item"
            else
                PICKER_RESULT_STR="$_pc_item"
            fi
            PICKER_RESULT_COUNT=$((PICKER_RESULT_COUNT + 1))
        fi
        _pc_i=$((_pc_i + 1))
    done
}

# ── Fetch skills from remote ────────────────────────────────────────

SKILLS_STR=""
SKILLS_COUNT=0

fetch_skills() {
    local raw line

    printf "Fetching skills list...\n"
    raw=$(curl -fsSL "$SKILLS_URL") || die "Failed to fetch skills list."

    SKILLS_STR=""
    SKILLS_COUNT=0
    while IFS= read -r line; do
        # trim leading/trailing whitespace
        while true; do
            case "$line" in
                " "*) line="${line# }" ;;
                *" ") line="${line% }" ;;
                *)    break ;;
            esac
        done
        # skip empty lines and comments
        if [ -z "$line" ] || [ "${line#\#}" != "$line" ]; then
            continue
        fi
        if [ -n "$SKILLS_STR" ]; then
            SKILLS_STR="$SKILLS_STR
$line"
        else
            SKILLS_STR="$line"
        fi
        SKILLS_COUNT=$((SKILLS_COUNT + 1))
    done <<FETCHEOF
$raw
FETCHEOF

    if [ "$SKILLS_COUNT" -eq 0 ]; then
        die "No skills found in remote list."
    fi
}

# ── Install ──────────────────────────────────────────────────────────

install_skills() {
    local agent_str="$1"
    local skill_str="$2"
    local agent_count="$3"
    local skill_count="$4"
    local installed=0 failed=0

    if [ "$agent_count" -gt 0 ]; then
        printf "Installing %s skill(s) to %s agent(s)...\n\n" "$skill_count" "$agent_count"
    else
        printf "Installing %s skill(s) (no agents specified)...\n\n" "$skill_count"
    fi

    local _is_skill _is_agent cmd owner rest repo skill_name stripped stripped2
    while IFS= read -r _is_skill; do
        printf "Installing %s...\n" "$_is_skill"

        cmd="npx skills add"

        stripped="${_is_skill#*/}"
        stripped2="${stripped#*/}"
        if [ "$stripped" != "$_is_skill" ] && [ "$stripped2" != "$stripped" ]; then
            owner="${_is_skill%%/*}"
            rest="${_is_skill#*/}"
            repo="${rest%%/*}"
            skill_name="${rest#*/}"
            cmd="$cmd ${owner}/${repo} --skill ${skill_name}"
        else
            cmd="$cmd ${_is_skill}"
        fi

        if [ "$agent_count" -gt 0 ]; then
            while IFS= read -r _is_agent; do
                cmd="$cmd -a $_is_agent"
            done <<AGENTEOF
$agent_str
AGENTEOF
        fi
        cmd="$cmd -y"

        if eval "$cmd"; then
            printf "  ok\n\n"
            installed=$((installed + 1))
        else
            printf "  failed\n\n"
            failed=$((failed + 1))
        fi
    done <<INSTALLEOF
$skill_str
INSTALLEOF

    printf "Done. Installed: %s" "$installed"
    if [ "$failed" -gt 0 ]; then
        printf " | Failed: %s" "$failed"
    fi
    printf "\n"
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
    require_cmd npx
    require_cmd curl
    require_cmd stty
    require_cmd tput

    trap cleanup EXIT
    trap 'die "Installation cancelled." 0' INT TERM

    stty -echo -icanon isig min 1 time 0
    tput civis
    tput clear

    # ── Step 1: Pick agents ──────────────────────────────────────────
    picker_setup \
        "Select Agents" \
        "Choose which agent integrations receive the skills." \
        "All agents" \
        14 \
        "${AGENTS[@]}"

    picker_run
    picker_collect

    local agents_result="$PICKER_RESULT_STR"
    local agents_count="$PICKER_RESULT_COUNT"

    # ── Step 2: Fetch & pick skills ──────────────────────────────────
    tput clear
    fetch_skills

    picker_setup_from_str \
        "Select Skills" \
        "Choose which skills to install from the remote list." \
        "All skills" \
        "$SKILLS_STR" \
        "$SKILLS_COUNT"

    picker_run
    picker_collect

    if [ "$PICKER_RESULT_COUNT" -eq 0 ]; then
        die "No skills selected." 0
    fi

    # ── Step 3: Install ──────────────────────────────────────────────
    cleanup
    trap - EXIT INT TERM
    tput clear
    install_skills "$agents_result" "$PICKER_RESULT_STR" "$agents_count" "$PICKER_RESULT_COUNT"
}

main "$@"
