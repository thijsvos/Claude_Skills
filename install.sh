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

# Crash safety: if a backup was made but the symlink wasn't recreated (e.g. Ctrl-C
# between the `mv` and `ln`), restore the backup so the user isn't left empty-handed.
PENDING_TARGET=""
PENDING_BACKUP=""

restore_on_exit() {
    local rc=$?
    if [[ -n "$PENDING_BACKUP" && -n "$PENDING_TARGET" ]]; then
        if [[ ! -L "$PENDING_TARGET" && ! -e "$PENDING_TARGET" && -e "$PENDING_BACKUP" ]]; then
            mv "$PENDING_BACKUP" "$PENDING_TARGET" 2>/dev/null || true
        fi
    fi
    exit "$rc"
}
trap restore_on_exit EXIT INT TERM

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
        # No `rm` needed — `ln -snf` below replaces the symlink atomically.
    elif [[ -d "$target" || -e "$target" ]]; then
        # Timestamp the backup so a second run doesn't silently overwrite the first.
        local bak="${target}.bak"
        if [[ -e "$bak" || -L "$bak" ]]; then
            bak="${target}.bak.$(date +%Y%m%d-%H%M%S)"
        fi
        local kind="file"
        [[ -d "$target" ]] && kind="directory"
        emit "$YELLOW" "backup" "$skill_name -- existing $kind backed up to $bak"
        PENDING_TARGET="$target"
        PENDING_BACKUP="$bak"
        mv "$target" "$bak"
    fi

    # `ln -snf` atomically replaces an existing symlink and refuses to descend into
    # a symlink-to-directory (the `-n` flag matters on BSD `ln` for macOS).
    ln -snf "$source" "$target"
    PENDING_TARGET=""
    PENDING_BACKUP=""
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
    # when the directory is empty. Trailing `/` already restricts to directories.
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
