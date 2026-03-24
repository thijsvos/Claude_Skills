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

    echo -e "\n${BOLD}Checking: $skill_name${NC}"

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
    fi

    local tools_val
    tools_val="$(get_frontmatter "$skill_md" "allowed-tools")"
    if [[ -z "$tools_val" ]]; then
        fail "Missing required field: allowed-tools"
    else
        pass "Has 'allowed-tools' field"
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
