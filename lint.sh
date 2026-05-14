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

# Colors (disabled if not a terminal or terminal has no color support).
# Use `tput` so the right escape sequence is picked for the actual terminfo
# entry instead of hardcoding xterm-only bytes.
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    RED="$(tput setaf 1)"
    BOLD="$(tput bold)"
    NC="$(tput sgr0)"
else
    GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0

# Use `printf` instead of `echo -e` so behavior is identical across bash
# builtin / dash / BSD echo. The color variables already hold literal escape
# bytes thanks to `tput` above (no `\033` literals to interpret).
pass() { printf '  %s[pass]%s %s\n' "$GREEN"  "$NC" "$1"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { printf '  %s[fail]%s %s\n' "$RED"    "$NC" "$1"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }
warn() { printf '  %s[warn]%s %s\n' "$YELLOW" "$NC" "$1"; TOTAL_WARN=$((TOTAL_WARN + 1)); }

# Extract a frontmatter field value from a SKILL.md file
get_frontmatter() {
    local file="$1" field="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep -E "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" || true
}

lint_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"
    local skill_md="$skill_dir/SKILL.md"
    local readme_md="$skill_dir/README.md"

    printf '\n%sChecking: %s%s\n' "$BOLD" "$skill_name" "$NC"

    # Check SKILL.md exists
    if [[ ! -f "$skill_md" ]]; then
        fail "SKILL.md not found"
        return
    fi
    pass "SKILL.md exists"

    # Check frontmatter exists
    if ! head -1 "$skill_md" | grep -q '^---$'; then
        fail "SKILL.md missing frontmatter (must start with ---)"
        return
    fi
    pass "SKILL.md has frontmatter"

    # Check required frontmatter fields
    local name_val
    name_val="$(get_frontmatter "$skill_md" "name")"
    if [[ -z "$name_val" ]]; then
        fail "Missing required field: name"
    else
        pass "Has 'name' field: $name_val"
        # Cross-reference: name should match directory
        if [[ "$name_val" != "$skill_name" ]]; then
            fail "name '$name_val' does not match directory '$skill_name'"
        else
            pass "name matches directory"
        fi
    fi

    local desc_val
    desc_val="$(get_frontmatter "$skill_md" "description")"
    if [[ -z "$desc_val" ]]; then
        fail "Missing required field: description"
    else
        pass "Has 'description' field"
        # Description should end with a period
        if [[ "$desc_val" == *"." ]]; then
            pass "description ends with a period"
        else
            warn "description does not end with a period"
        fi
    fi

    local tools_val
    tools_val="$(get_frontmatter "$skill_md" "allowed-tools")"
    if [[ -z "$tools_val" ]]; then
        fail "Missing required field: allowed-tools"
    else
        pass "Has 'allowed-tools' field"
    fi

    # Check plan-mode discipline: if EnterPlanMode is present, ExitPlanMode must be too
    if [[ "$tools_val" == *"EnterPlanMode"* ]]; then
        if [[ "$tools_val" == *"ExitPlanMode"* ]]; then
            pass "EnterPlanMode and ExitPlanMode are paired in allowed-tools"
        else
            fail "EnterPlanMode declared without ExitPlanMode in allowed-tools"
        fi
    fi

    # Check that the body calls both EnterPlanMode and ExitPlanMode if either is in tools
    if [[ "$tools_val" == *"EnterPlanMode"* ]]; then
        if grep -q "EnterPlanMode" "$skill_md"; then
            pass "body references EnterPlanMode"
        else
            fail "EnterPlanMode in allowed-tools but never referenced in body"
        fi
        if grep -q "ExitPlanMode" "$skill_md"; then
            pass "body references ExitPlanMode"
        else
            fail "ExitPlanMode in allowed-tools but never referenced in body"
        fi
    fi

    # If multi-agent (Agent in tools and body launches subagents), require the IMPORTANT block
    if [[ "$tools_val" == *"Agent"* ]]; then
        if grep -qE 'subagent_type:[[:space:]]*"?Explore"?' "$skill_md"; then
            # Body uses Explore subagents — must include the canonical IMPORTANT block
            if grep -q 'subagents MUST be launched with' "$skill_md"; then
                pass "IMPORTANT subagent block present"
            else
                warn "Agent + Explore subagents used but canonical IMPORTANT block missing"
            fi
        fi
    fi

    # Check README.md exists
    if [[ ! -f "$readme_md" ]]; then
        fail "README.md not found"
        return
    fi
    pass "README.md exists"

    # Check required README sections
    local required_sections=("What It Does" "Requirements" "Usage" "Configuration")
    for section in "${required_sections[@]}"; do
        if grep -qi "## $section" "$readme_md"; then
            pass "README has section: $section"
        else
            fail "README missing section: $section"
        fi
    done

    # Optional checks
    if grep -qi "## Safety" "$readme_md"; then
        pass "README has section: Safety"
    else
        warn "README has no Safety section (optional)"
    fi

    # README first line description should match SKILL.md description
    # (skip the "# Title" heading — line 3 is the description in the README template)
    local readme_desc
    readme_desc="$(sed -n '3p' "$readme_md")"
    if [[ -n "$desc_val" && -n "$readme_desc" ]]; then
        if [[ "$readme_desc" == "$desc_val" ]]; then
            pass "README description matches SKILL.md description"
        else
            warn "README line 3 description differs from SKILL.md description"
        fi
    fi

    # Usage section examples should invoke /<name>, not /<some-other-name>.
    # Only inspect lines that START with /<token> (after optional leading
    # whitespace and an optional '> ' prompt prefix) — that's how skill
    # invocations are written in the Usage code blocks. This avoids
    # false-positives on path components like `/src/auth/`.
    local bad_invocations
    bad_invocations="$(awk '/^## Usage/{flag=1; next} /^## /{flag=0} flag' "$readme_md" \
        | sed -nE 's|^[[:space:]]*>?[[:space:]]*(/[a-z][a-z0-9-]+).*$|\1|p' \
        | sort -u \
        | grep -v "^/$name_val$" \
        || true)"
    if [[ -n "$bad_invocations" ]]; then
        warn "README Usage references non-self slash commands: $(echo "$bad_invocations" | tr '\n' ' ')"
    else
        pass "README Usage examples reference /$name_val correctly"
    fi

    # Configuration table should include Takes argument and Allowed tools rows
    if grep -qE '\|[[:space:]]*Takes argument[[:space:]]*\|' "$readme_md"; then
        pass "Configuration table has 'Takes argument' row"
    else
        warn "Configuration table missing 'Takes argument' row"
    fi
    if grep -qE '\|[[:space:]]*Allowed tools[[:space:]]*\|' "$readme_md"; then
        pass "Configuration table has 'Allowed tools' row"
    else
        fail "Configuration table missing 'Allowed tools' row"
    fi

    # allowed-tools in SKILL.md frontmatter == Allowed tools row in README Configuration table
    if [[ -n "$tools_val" ]]; then
        local readme_tools
        readme_tools="$(grep -E '\|[[:space:]]*Allowed tools[[:space:]]*\|' "$readme_md" \
            | head -1 \
            | sed -E 's/^\|[[:space:]]*Allowed tools[[:space:]]*\|[[:space:]]*//' \
            | sed -E 's/[[:space:]]*\|[[:space:]]*$//' \
            | tr -d '`')"
        # Normalize whitespace and trailing spaces
        local norm_skill_tools norm_readme_tools
        norm_skill_tools="$(echo "$tools_val" | tr -d '[:space:]')"
        norm_readme_tools="$(echo "$readme_tools" | tr -d '[:space:]')"
        if [[ "$norm_skill_tools" == "$norm_readme_tools" ]]; then
            pass "Allowed tools row matches SKILL.md allowed-tools"
        else
            warn "Allowed tools row in README does not match SKILL.md allowed-tools frontmatter"
        fi
    fi
}

printf '%sClaude Skills Linter%s\n' "$BOLD" "$NC"
printf '====================\n'

if [[ $# -gt 0 ]]; then
    for skill in "$@"; do
        if [[ ! -d "$SKILLS_DIR/$skill" ]]; then
            printf '\n%sError: Skill %s not found in %s%s\n' "$RED" "'$skill'" "$SKILLS_DIR" "$NC"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            continue
        fi
        lint_skill "$skill"
    done
else
    # `shopt -s nullglob` so the loop body doesn't run on the literal pattern
    # when the directory is empty. Trailing `/` in the glob already restricts
    # to directories, so the in-loop `-d` test is redundant.
    shopt -s nullglob
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_name="${skill_dir%/}"
        skill_name="${skill_name##*/}"
        lint_skill "$skill_name"
    done
    shopt -u nullglob
fi

printf '\n%sSummary%s\n' "$BOLD" "$NC"
printf -- '-------\n'
printf '  %sPassed: %s%s\n' "$GREEN" "$TOTAL_PASS" "$NC"
[[ $TOTAL_WARN -gt 0 ]] && printf '  %sWarnings: %s%s\n' "$YELLOW" "$TOTAL_WARN" "$NC"
[[ $TOTAL_FAIL -gt 0 ]] && printf '  %sFailed: %s%s\n' "$RED" "$TOTAL_FAIL" "$NC"

if [[ $TOTAL_FAIL -gt 0 ]]; then
    printf '\n%sLint failed with %s error(s).%s\n' "$RED" "$TOTAL_FAIL" "$NC"
    exit 1
else
    printf '\n%sAll checks passed.%s\n' "$GREEN" "$NC"
    exit 0
fi
