#!/usr/bin/env bash
set -euo pipefail

# Require bash 3.2+ (macOS system /bin/bash is 3.2; Homebrew bash and Ubuntu CI
# are 5+). Fails loud on `sh`-as-bash or ancient bash setups so we don't get
# the "works on CI, silently broken on macOS" class of bug.
if (( BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
    printf 'Error: bash 3.2+ required (found %s)\n' "$BASH_VERSION" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

# Colors (disabled if not a terminal or terminal has no color support).
# Use `tput` so the right escape sequence is picked for the actual terminfo
# entry (xterm, screen, dumb, etc.) instead of hardcoding xterm-only bytes.
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    RED="$(tput setaf 1)"
    BOLD="$(tput bold)"
    NC="$(tput sgr0)"
else
    GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

# Emit a colored tagged line. Mirrors the pass/fail/warn helpers in lint.sh.
emit() {  # emit COLOR TAG MSG
    printf '  %s[%s]%s %s\n' "$1" "$2" "$NC" "$3"
}

install_skill() {
    local skill_name="$1"
    local source="$SKILLS_DIR/$skill_name"
    local target="$TARGET_DIR/$skill_name"

    if [[ ! -d "$source" ]]; then
        emit "$RED" "error" "Skill '$skill_name' not found in $SKILLS_DIR"
        return 1
    fi

    mkdir -p "$TARGET_DIR"

    if [[ -L "$target" ]]; then
        local existing_link
        existing_link="$(readlink "$target")"
        if [[ "$existing_link" == "$source" ]]; then
            emit "$GREEN" "skip" "$skill_name -- already linked correctly"
            return 0
        fi
        emit "$YELLOW" "update" "$skill_name -- replacing existing symlink (was: $existing_link)"
        rm "$target"
    elif [[ -d "$target" ]]; then
        emit "$YELLOW" "backup" "$skill_name -- existing directory backed up to ${target}.bak"
        mv "$target" "${target}.bak"
    elif [[ -e "$target" ]]; then
        emit "$YELLOW" "backup" "$skill_name -- existing file backed up to ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    ln -s "$source" "$target"
    emit "$GREEN" "installed" "$skill_name -> $source"
}

printf '%sClaude Code Skills Installer%s\n' "$BOLD" "$NC"
printf '============================\n\n'

if [[ $# -gt 0 ]]; then
    for skill in "$@"; do
        install_skill "$skill"
    done
else
    printf 'Installing all skills from %s:\n\n' "$SKILLS_DIR"
    # `shopt -s nullglob` so the loop body doesn't run on the literal pattern
    # when the directory is empty (otherwise `set -u` + a literal `$SKILLS_DIR/*/`
    # would still pass `-d`, but be safer than sorry).
    shopt -s nullglob
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_name="${skill_dir%/}"
        skill_name="${skill_name##*/}"
        install_skill "$skill_name"
    done
    shopt -u nullglob
fi

printf '\nDone. Skills are symlinked from ~/.claude/skills/ to this repository.\n'
printf "Run 'git pull' in this repo to update skills.\n"
