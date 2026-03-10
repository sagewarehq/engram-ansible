#!/bin/bash

set -e

echo "🚀 Installing agent skills..."
echo ""

# Check if npx is available
if ! command -v npx &> /dev/null; then
    echo "❌ Error: npx is not installed. Please install Node.js first."
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_FILE="$SCRIPT_DIR/skills.txt"

# Check if skills.txt exists
if [ ! -f "$SKILLS_FILE" ]; then
    echo "❌ Error: skills.txt not found in $SCRIPT_DIR"
    exit 1
fi

# Count total skills
TOTAL=$(grep -v '^#' "$SKILLS_FILE" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')
CURRENT=0

echo "📦 Found $TOTAL skills to install"
echo ""

# Read skills.txt and install each skill
while IFS= read -r skill || [ -n "$skill" ]; do
    # Skip empty lines and comments
    if [[ -z "$skill" ]] || [[ "$skill" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    CURRENT=$((CURRENT + 1))
    echo "[$CURRENT/$TOTAL] Installing $skill..."
    
    if npx skillsadd "$skill"; then
        echo "✅ Successfully installed $skill"
    else
        echo "⚠️  Failed to install $skill (continuing...)"
    fi
    echo ""
done < "$SKILLS_FILE"

echo "✨ Installation complete!"
echo ""
echo "Installed $CURRENT skills from your collection."
