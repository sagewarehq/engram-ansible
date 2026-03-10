#!/bin/bash

set -e

SKILLS_URL="https://raw.githubusercontent.com/sagewarehq/engram-ansible/master/skills.txt"

if ! command -v npx &> /dev/null; then
    echo "❌ Error: npx is not installed. Please install Node.js first."
    exit 1
fi

AGENTS=(
    "antigravity" "augment" "claude-code" "openclaw" "codebuddy" "command-code"
    "continue" "cortex" "crush" "cursor" "droid" "gemini-cli" "github-copilot"
    "goose" "junie" "iflow-cli" "kilo" "kiro-cli" "kode" "mcpjam" "mistral-vibe"
    "mux" "opencode" "openhands" "pi" "qoder" "qwen-code" "roo" "trae" "trae-cn"
    "windsurf" "zencoder" "neovate" "pochi" "adal" "amp" "kimi-cli" "replit"
    "cline" "codex"
)

declare -a AGENT_SELECTED
for i in "${!AGENTS[@]}"; do
    AGENT_SELECTED[$i]=0
done

AGENT_CURRENT=-1
AGENT_ALL_SELECTED=0
WINDOW_SIZE=15
WINDOW_START=0

get_key() {
    local key
    IFS= read -rsn1 key
    
    if [[ $key == $'\x1b' ]]; then
        read -rsn1 k1
        read -rsn1 k2
        case "$k1$k2" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            *) echo "ESC" ;;
        esac
    elif [[ $key == "" ]] || [[ $key == $'\n' ]]; then
        echo "ENTER"
    elif [[ $key == " " ]]; then
        echo "SPACE"
    elif [[ $key == "q" ]] || [[ $key == "Q" ]]; then
        echo "QUIT"
    fi
}

draw_agent_menu() {
    if [ $AGENT_CURRENT -ge 0 ]; then
        if [ $AGENT_CURRENT -lt $WINDOW_START ]; then
            WINDOW_START=$AGENT_CURRENT
        elif [ $AGENT_CURRENT -ge $((WINDOW_START + WINDOW_SIZE)) ]; then
            WINDOW_START=$((AGENT_CURRENT - WINDOW_SIZE + 1))
        fi
    else
        WINDOW_START=0
    fi
    
    tput cup 0 0
    
    echo "███████╗██╗  ██╗██╗██╗     ██╗     ███████╗"
    echo "██╔════╝██║ ██╔╝██║██║     ██║     ██╔════╝"
    echo "███████╗█████╔╝ ██║██║     ██║     ███████╗"
    echo "╚════██║██╔═██╗ ██║██║     ██║     ╚════██║"
    echo "███████║██║  ██╗██║███████╗███████╗███████║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ Select Agents                                                       │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    local selected_count=0
    for i in "${!AGENTS[@]}"; do
        if [ ${AGENT_SELECTED[$i]} -eq 1 ]; then
            selected_count=$((selected_count + 1))
        fi
    done
    
    printf "│ %-67s │\n" "  Selected: $selected_count/${#AGENTS[@]} agents"
    printf "│ %-67s │\n" "  Use ↑/↓ arrows, SPACE to select, ENTER to continue"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
    
    if [ $AGENT_CURRENT -eq -1 ]; then
        if [ $AGENT_ALL_SELECTED -eq 1 ]; then
            echo "❯ ◉ All agents"
        else
            echo "❯ ○ All agents"
        fi
    else
        if [ $AGENT_ALL_SELECTED -eq 1 ]; then
            echo "  ◉ All agents"
        else
            echo "  ○ All agents"
        fi
    fi
    echo ""
    
    local end=$((WINDOW_START + WINDOW_SIZE))
    if [ $end -gt ${#AGENTS[@]} ]; then
        end=${#AGENTS[@]}
    fi
    
    if [ $WINDOW_START -gt 0 ]; then
        echo "  ↑ $WINDOW_START more"
    fi
    
    for i in $(seq $WINDOW_START $((end - 1))); do
        if [ $i -eq $AGENT_CURRENT ]; then
            if [ ${AGENT_SELECTED[$i]} -eq 1 ]; then
                echo "❯ ◉ ${AGENTS[$i]}"
            else
                echo "❯ ○ ${AGENTS[$i]}"
            fi
        else
            if [ ${AGENT_SELECTED[$i]} -eq 1 ]; then
                echo "  ◉ ${AGENTS[$i]}"
            else
                echo "  ○ ${AGENTS[$i]}"
            fi
        fi
    done
    
    if [ $end -lt ${#AGENTS[@]} ]; then
        echo "  ↓ $((${#AGENTS[@]} - end)) more"
    fi
    
    tput ed
}

toggle_agent_selection() {
    if [ $AGENT_CURRENT -eq -1 ]; then
        if [ $AGENT_ALL_SELECTED -eq 1 ]; then
            AGENT_ALL_SELECTED=0
            for i in "${!AGENTS[@]}"; do
                AGENT_SELECTED[$i]=0
            done
        else
            AGENT_ALL_SELECTED=1
            for i in "${!AGENTS[@]}"; do
                AGENT_SELECTED[$i]=1
            done
        fi
    else
        if [ ${AGENT_SELECTED[$AGENT_CURRENT]} -eq 1 ]; then
            AGENT_SELECTED[$AGENT_CURRENT]=0
            AGENT_ALL_SELECTED=0
        else
            AGENT_SELECTED[$AGENT_CURRENT]=1
        fi
    fi
}

stty -echo -icanon time 0 min 0
draw_agent_menu

while true; do
    key=$(get_key)
    
    case "$key" in
        UP)
            if [ $AGENT_CURRENT -gt -1 ]; then
                AGENT_CURRENT=$((AGENT_CURRENT - 1))
            fi
            draw_agent_menu
            ;;
        DOWN)
            if [ $AGENT_CURRENT -lt $((${#AGENTS[@]} - 1)) ]; then
                AGENT_CURRENT=$((AGENT_CURRENT + 1))
            fi
            draw_agent_menu
            ;;
        SPACE)
            toggle_agent_selection
            draw_agent_menu
            ;;
        ENTER)
            break
            ;;
        QUIT)
            stty echo icanon
            tput clear
            echo "❌ Installation cancelled"
            exit 0
            ;;
    esac
done

stty echo icanon
tput clear

SELECTED_AGENTS=()
for i in "${!AGENTS[@]}"; do
    if [ ${AGENT_SELECTED[$i]} -eq 1 ]; then
        SELECTED_AGENTS+=("${AGENTS[$i]}")
    fi
done

if [ ${#SELECTED_AGENTS[@]} -eq 0 ]; then
    echo "❌ No agents selected"
    exit 0
fi

echo "📥 Fetching skills list..."
SKILLS_CONTENT=$(curl -fsSL "$SKILLS_URL")

SKILLS=()
while IFS= read -r line; do
    if [[ -n "$line" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
        SKILLS+=("$line")
    fi
done < <(echo "$SKILLS_CONTENT")

if [ ${#SKILLS[@]} -eq 0 ]; then
    echo "❌ No skills found"
    exit 1
fi

declare -a SELECTED
for i in "${!SKILLS[@]}"; do
    SELECTED[$i]=0
done

CURRENT=-1
ALL_SELECTED=0

draw_menu() {
    tput cup 0 0
    
    echo "███████╗██╗  ██╗██╗██╗     ██╗     ███████╗"
    echo "██╔════╝██║ ██╔╝██║██║     ██║     ██╔════╝"
    echo "███████╗█████╔╝ ██║██║     ██║     ███████╗"
    echo "╚════██║██╔═██╗ ██║██║     ██║     ╚════██║"
    echo "███████║██║  ██╗██║███████╗███████╗███████║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ Select Skills                                                       │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    local selected_count=0
    for i in "${!SKILLS[@]}"; do
        if [ ${SELECTED[$i]} -eq 1 ]; then
            selected_count=$((selected_count + 1))
        fi
    done
    
    printf "│ %-67s │\n" "  Selected: $selected_count/${#SKILLS[@]} skills"
    printf "│ %-67s │\n" "  Use ↑/↓ arrows, SPACE to select, ENTER to install"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
    
    if [ $CURRENT -eq -1 ]; then
        if [ $ALL_SELECTED -eq 1 ]; then
            echo "❯ ◉ Install all skills"
        else
            echo "❯ ○ Install all skills"
        fi
    else
        if [ $ALL_SELECTED -eq 1 ]; then
            echo "  ◉ Install all skills"
        else
            echo "  ○ Install all skills"
        fi
    fi
    echo ""
    
    for i in "${!SKILLS[@]}"; do
        if [ $i -eq $CURRENT ]; then
            if [ ${SELECTED[$i]} -eq 1 ]; then
                echo "❯ ◉ ${SKILLS[$i]}"
            else
                echo "❯ ○ ${SKILLS[$i]}"
            fi
        else
            if [ ${SELECTED[$i]} -eq 1 ]; then
                echo "  ◉ ${SKILLS[$i]}"
            else
                echo "  ○ ${SKILLS[$i]}"
            fi
        fi
    done
    
    tput ed
}

toggle_selection() {
    if [ $CURRENT -eq -1 ]; then
        if [ $ALL_SELECTED -eq 1 ]; then
            ALL_SELECTED=0
            for i in "${!SKILLS[@]}"; do
                SELECTED[$i]=0
            done
        else
            ALL_SELECTED=1
            for i in "${!SKILLS[@]}"; do
                SELECTED[$i]=1
            done
        fi
    else
        if [ ${SELECTED[$CURRENT]} -eq 1 ]; then
            SELECTED[$CURRENT]=0
            ALL_SELECTED=0
        else
            SELECTED[$CURRENT]=1
        fi
    fi
}

stty -echo -icanon time 0 min 0
draw_menu

while true; do
    key=$(get_key)
    
    case "$key" in
        UP)
            if [ $CURRENT -gt -1 ]; then
                CURRENT=$((CURRENT - 1))
            fi
            draw_menu
            ;;
        DOWN)
            if [ $CURRENT -lt $((${#SKILLS[@]} - 1)) ]; then
                CURRENT=$((CURRENT + 1))
            fi
            draw_menu
            ;;
        SPACE)
            toggle_selection
            draw_menu
            ;;
        ENTER)
            break
            ;;
        QUIT)
            stty echo icanon
            tput clear
            echo "❌ Installation cancelled"
            exit 0
            ;;
    esac
done

stty echo icanon
tput clear

SELECTED_SKILLS=()
for i in "${!SKILLS[@]}"; do
    if [ ${SELECTED[$i]} -eq 1 ]; then
        SELECTED_SKILLS+=("${SKILLS[$i]}")
    fi
done

if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
    echo "❌ No skills selected"
    exit 0
fi

echo "🚀 Installing ${#SELECTED_SKILLS[@]} skill(s) to ${#SELECTED_AGENTS[@]} agent(s)..."
echo ""

INSTALLED=0
FAILED=0

AGENT_FLAGS=""
for agent in "${SELECTED_AGENTS[@]}"; do
    AGENT_FLAGS="$AGENT_FLAGS -a $agent"
done

for skill in "${SELECTED_SKILLS[@]}"; do
    echo "Installing $skill..."
    
    if [[ $skill =~ ^([^/]+)/([^/]+)/(.+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        skill_name="${BASH_REMATCH[3]}"
        cmd="npx skills add ${owner}/${repo} --skill ${skill_name}${AGENT_FLAGS} -y"
    else
        cmd="npx skills add ${skill}${AGENT_FLAGS} -y"
    fi
    
    if eval "$cmd"; then
        echo "✅ Successfully installed $skill"
        INSTALLED=$((INSTALLED + 1))
    else
        echo "⚠️  Failed to install $skill"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "✨ Installation complete!"
echo "   Installed: $INSTALLED"
if [ $FAILED -gt 0 ]; then
    echo "   Failed: $FAILED"
fi
