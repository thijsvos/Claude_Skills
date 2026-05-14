#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

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

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0

pass() { echo -e "  ${GREEN}[pass]${NC} $1"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { echo -e "  ${RED}[fail]${NC} $1"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }
warn() { echo -e "  ${YELLOW}[warn]${NC} $1"; TOTAL_WARN=$((TOTAL_WARN + 1)); }

# Extract a frontmatter field value from a SKILL.md file.
# Pure-bash implementation so genuine file/read errors aren't swallowed by `|| true`
# the way they were in the old `sed | grep | head | sed || true` pipeline.
get_frontmatter() {
    local file="$1" field="$2" line in_fm=0
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            in_fm=$((in_fm + 1))
            [[ $in_fm -eq 2 ]] && return 0
            continue
        fi
        [[ $in_fm -eq 1 ]] || continue
        if [[ "$line" =~ ^${field}:[[:space:]]*(.*)$ ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done < "$file"
}

lint_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"
    local skill_md="$skill_dir/SKILL.md"
    local readme_md="$skill_dir/README.md"

    echo -e "\n${BOLD}Checking: $skill_name${NC}"

    # Check SKILL.md exists
    if [[ ! -f "$skill_md" ]]; then
        fail "SKILL.md not found"
        return
    fi
    pass "SKILL.md exists"

    # Check frontmatter exists.
    # Read the first line natively (no pipeline, no subshell). `|| true` lets the
    # `read` short-circuit on an empty file without tripping `set -e`.
    local first_line=""
    IFS= read -r first_line < "$skill_md" || true
    if [[ "$first_line" != "---" ]]; then
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
    # (skip the "# Title" heading — line 3 is the description in the README template).
    # Read exactly three lines natively instead of spawning `sed -n '3p'`; the
    # brace group's redirection closes the file after the third read.
    local readme_desc=""
    { IFS= read -r _; IFS= read -r _; IFS= read -r readme_desc; } < "$readme_md" || true
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
    # `grep -v` exits 1 when nothing prints, which is the success case here
    # (no bad invocations). Scope `|| true` to just the grep so real failures
    # in awk / sed / sort propagate via pipefail. Use `grep -Fxv` so $name_val
    # is treated as a literal whole-line string, not a regex — names with
    # metacharacters won't corrupt the match.
    local bad_invocations
    bad_invocations="$(awk '/^## Usage/{flag=1; next} /^## /{flag=0} flag' "$readme_md" \
        | sed -nE 's|^[[:space:]]*>?[[:space:]]*(/[a-z][a-z0-9-]+).*$|\1|p' \
        | sort -u \
        | { grep -Fxv "/$name_val" || true; })"
    if [[ -n "$bad_invocations" ]]; then
        # Native parameter expansion: replace every literal newline with a space,
        # no external `echo`/`tr` and no problematic flag-eating by `echo`.
        warn "README Usage references non-self slash commands: ${bad_invocations//$'\n'/ }"
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

    # allowed-tools in SKILL.md frontmatter == Allowed tools row in README Configuration table.
    # Native bash regex captures the cell in one pass — no grep|head|sed|sed|tr pipeline,
    # no `\|` ambiguity between sed -E (ERE) and sed (BRE).
    if [[ -n "$tools_val" ]]; then
        local readme_tools="" rline
        while IFS= read -r rline; do
            if [[ "$rline" =~ ^\|[[:space:]]*Allowed[[:space:]]+tools[[:space:]]*\|[[:space:]]*(.*[^[:space:]])[[:space:]]*\|[[:space:]]*$ ]]; then
                readme_tools="${BASH_REMATCH[1]//\`/}"
                break
            fi
        done < "$readme_md"
        # Strip whitespace via parameter expansion (no external `tr`, no `echo` flag-eating).
        local norm_skill_tools="${tools_val//[[:space:]]/}"
        local norm_readme_tools="${readme_tools//[[:space:]]/}"
        if [[ "$norm_skill_tools" == "$norm_readme_tools" ]]; then
            pass "Allowed tools row matches SKILL.md allowed-tools"
        else
            warn "Allowed tools row in README does not match SKILL.md allowed-tools frontmatter"
        fi
    fi
}

echo -e "${BOLD}Claude Skills Linter${NC}"
echo "===================="

if [[ $# -gt 0 ]]; then
    for skill in "$@"; do
        if [[ ! -d "$SKILLS_DIR/$skill" ]]; then
            echo -e "\n${RED}Error: Skill '$skill' not found in $SKILLS_DIR${NC}"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            continue
        fi
        lint_skill "$skill"
    done
else
    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        lint_skill "$skill_name"
    done
fi

echo ""
echo -e "${BOLD}Summary${NC}"
echo "-------"
echo -e "  ${GREEN}Passed: $TOTAL_PASS${NC}"
[[ $TOTAL_WARN -gt 0 ]] && echo -e "  ${YELLOW}Warnings: $TOTAL_WARN${NC}"
[[ $TOTAL_FAIL -gt 0 ]] && echo -e "  ${RED}Failed: $TOTAL_FAIL${NC}"

if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo ""
    echo -e "${RED}Lint failed with $TOTAL_FAIL error(s).${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All checks passed.${NC}"
    exit 0
fi
