#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

install_skill() {
    local skill_name="$1"
    local source="$SKILLS_DIR/$skill_name"
    local target="$TARGET_DIR/$skill_name"

    if [[ ! -d "$source" ]]; then
        echo -e "  ${RED}[error]${NC} Skill '$skill_name' not found in $SKILLS_DIR"
        return 1
    fi

    mkdir -p "$TARGET_DIR"

    if [[ -L "$target" ]]; then
        local existing_link
        existing_link="$(readlink "$target")"
        if [[ "$existing_link" == "$source" ]]; then
            echo -e "  ${GREEN}[skip]${NC} $skill_name -- already linked correctly"
            return 0
        fi
        echo -e "  ${YELLOW}[update]${NC} $skill_name -- replacing existing symlink (was: $existing_link)"
        rm "$target"
    elif [[ -d "$target" ]]; then
        echo -e "  ${YELLOW}[backup]${NC} $skill_name -- existing directory backed up to ${target}.bak"
        mv "$target" "${target}.bak"
    elif [[ -e "$target" ]]; then
        echo -e "  ${YELLOW}[backup]${NC} $skill_name -- existing file backed up to ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    ln -s "$source" "$target"
    echo -e "  ${GREEN}[installed]${NC} $skill_name -> $source"
}

echo -e "${BOLD}Claude Code Skills Installer${NC}"
echo "============================"
echo ""

if [[ $# -gt 0 ]]; then
    for skill in "$@"; do
        install_skill "$skill"
    done
else
    echo "Installing all skills from $SKILLS_DIR:"
    echo ""
    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        install_skill "$skill_name"
    done
fi

echo ""
echo "Done. Skills are symlinked from ~/.claude/skills/ to this repository."
echo "Run 'git pull' in this repo to update skills."
