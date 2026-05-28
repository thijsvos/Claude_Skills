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

# Emit a colored, two-bracket-tagged status line to stdout.
#
# Args: $1 = ANSI color escape (may be empty), $2 = short tag (e.g.
# "skip", "backup", "installed"), $3 = message. Generic helper inspired
# by pass/fail/warn in lint.sh but, unlike those, does NOT mutate any
# totals counter (install.sh has no summary block).
emit() {
    printf '  %s[%s]%s %s\n' "$1" "$2" "$NC" "$3"
}

# Crash-safety globals — set by install_skill across the mv→ln window,
# read by restore_on_exit so a Ctrl-C between the `mv` and the `ln`
# doesn't leave the user empty-handed.
PENDING_TARGET=""
PENDING_BACKUP=""

# EXIT/INT/TERM trap handler — the crash-safety net for install_skill.
#
# Reads the PENDING_TARGET / PENDING_BACKUP globals (set by install_skill
# just before `mv "$target" "$bak"` and cleared after the new `ln -snf`
# succeeds). If they're non-empty and the new symlink wasn't created
# (Ctrl-C between the mv and the ln, or the ln itself failed), atomically
# moves the backup back into place. Calls `exit "$rc"` with the original
# exit status so the trap is transparent to `set -euo pipefail`.
# shellcheck disable=SC2329  # invoked indirectly via the `trap` below.
restore_on_exit() {
    local rc=$?
    if [[ -n "$PENDING_BACKUP" && -n "$PENDING_TARGET" ]]; then
        if [[ ! -L "$PENDING_TARGET" && ! -e "$PENDING_TARGET" && -e "$PENDING_BACKUP" ]]; then
            # Loud failure: if the rollback itself fails, the user must know
            # the backup is still at the .bak path — otherwise they'll think
            # the install completed and lose track of the recovery file.
            if ! mv "$PENDING_BACKUP" "$PENDING_TARGET"; then
                # Print an explicit `mv` recovery command so the user can
                # paste it directly rather than reconstructing the paths.
                printf 'WARNING: rollback failed; original is at %s. Restore manually with: mv %q %q\n' \
                    "$PENDING_BACKUP" "$PENDING_BACKUP" "$PENDING_TARGET" >&2
            fi
        fi
    fi
    exit "$rc"
}
trap restore_on_exit EXIT INT TERM

# Install a single skill by symlinking it from $SKILLS_DIR into $TARGET_DIR.
#
# Idempotent: an already-correct symlink is skipped; a stale symlink is
# replaced atomically via `ln -snf`; an existing real file/dir is renamed to
# a `.bak` (timestamp-suffixed if a prior `.bak` already exists). Side
# effects: sets PENDING_TARGET and PENDING_BACKUP across the mv→ln window
# so restore_on_exit can roll back if interrupted, then clears them on
# success. Args: $1 = skill name (a directory under $SKILLS_DIR). Returns
# 1 if the source dir is missing, 0 otherwise.
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

# Remove symlinks in $TARGET_DIR that point into this repo's $SKILLS_DIR but
# whose source no longer exists — skills renamed or deleted between `git pull`s
# (e.g. `code-review` -> `vet`). The install loop only ever visits skills that
# still exist, so without this a stale ~/.claude/skills/<old-name> symlink
# dangles forever. Scoped deliberately to avoid collateral damage:
#   - symlinks only (a real directory the user created is never touched);
#   - only links resolving under $SKILLS_DIR (skills symlinked from elsewhere,
#     or unrelated plugins, are left alone);
#   - only when the target is missing (live skills are kept).
# Runs in "install all" mode only — a targeted `install.sh <name>` must not
# prune skills the user didn't name. Mutates the global exit_code on failure.
prune_stale_links() {
    [[ -d "$TARGET_DIR" ]] || return 0
    shopt -s nullglob
    local link dest
    for link in "$TARGET_DIR"/*; do
        [[ -L "$link" ]] || continue
        dest="$(readlink "$link")"
        [[ "$dest" == "$SKILLS_DIR"/* ]] || continue
        [[ -e "$link" ]] && continue
        if rm "$link"; then
            emit "$YELLOW" "pruned" "${link##*/} -- removed stale symlink (source gone: $dest)"
        else
            emit "$RED" "error" "${link##*/} -- failed to remove stale symlink"
            exit_code=1
        fi
    done
    shopt -u nullglob
}

printf '%sClaude Code Skills Installer%s\n' "$BOLD" "$NC"
printf '============================\n\n'

# Collect failures across all attempted installs rather than aborting on the
# first one (mirrors lint.sh's "report and continue, exit non-zero at the
# end" pattern). Without `|| exit_code=1`, `set -e` would terminate the loop
# the first time `install_skill` returns 1 — so a typo in one of N arguments
# would skip every later argument.
exit_code=0

if [[ $# -gt 0 ]]; then
    for skill in "$@"; do
        install_skill "$skill" || exit_code=1
    done
else
    printf 'Installing all skills from %s:\n\n' "$SKILLS_DIR"
    # `shopt -s nullglob` so the loop body doesn't run on the literal pattern
    # when the directory is empty. Trailing `/` already restricts to directories.
    shopt -s nullglob
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_name="${skill_dir%/}"
        skill_name="${skill_name##*/}"
        install_skill "$skill_name" || exit_code=1
    done
    shopt -u nullglob
    # Only safe in install-all mode: every current skill has just been linked,
    # so any remaining dangling link into $SKILLS_DIR is genuinely orphaned.
    prune_stale_links
fi

printf '\nDone. Skills are symlinked from ~/.claude/skills/ to this repository.\n'
printf "Run 'git pull' in this repo to update skills.\n"
exit "$exit_code"
