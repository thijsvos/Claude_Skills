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

# Required README section headings, per CLAUDE.md "README Convention".
# scan_readme_md() iterates this array to populate README_REQUIRED_FOUND[];
# lint_skill() iterates it again to emit pass/fail messages. Adding a new
# required section means editing only this constant (the scanner and lint
# loop both adapt automatically).
REQUIRED_README_SECTIONS=("What It Does" "Requirements" "Usage" "Configuration")

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

# Status-line helpers. Each prints an indented, colored, tagged line to
# stdout and bumps the corresponding TOTAL_* counter that the summary
# block at the bottom of the file reads. Args: $1 = message text.
#   pass: bumps TOTAL_PASS (green [pass] tag).
#   fail: bumps TOTAL_FAIL (red [fail] tag); a non-zero TOTAL_FAIL is
#         what causes the script to `exit 1` at the bottom.
#   warn: bumps TOTAL_WARN (yellow [warn] tag); non-blocking.
#
# Asymmetry vs install.sh: lint.sh has exactly three outcomes that each bump
# a TOTAL_* counter, so per-outcome helpers are clearer than a generic emit.
# install.sh has many distinct tags and no totals — it uses a generic emit().
#
# Implementation note: `printf` instead of `echo -e` so behavior is
# identical across the bash builtin, dash, and BSD echo. The color
# variables already hold literal escape bytes from `tput` above (no
# `\033` literals to interpret).
pass() { printf '  %s[pass]%s %s\n' "$GREEN"  "$NC" "$1"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { printf '  %s[fail]%s %s\n' "$RED"    "$NC" "$1"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }
warn() { printf '  %s[warn]%s %s\n' "$YELLOW" "$NC" "$1"; TOTAL_WARN=$((TOTAL_WARN + 1)); }

# Scan SKILL.md in a single pass. Sets globals:
#   FM_OPENED, FM_CLOSED                          — frontmatter delimiter presence
#   FM_NAME, FM_DESC, FM_TOOLS                    — required frontmatter values
#   BODY_HAS_ENTER, BODY_HAS_EXIT                 — EnterPlanMode/ExitPlanMode references
#   BODY_HAS_EXPLORE, BODY_HAS_IMPORTANT          — Explore subagent + canonical IMPORTANT block
#
# Replaces three get_frontmatter() calls plus four `grep` invocations with a
# single read pass. Strips trailing CR so Windows-saved (CRLF) SKILL.md files
# lint the same as LF-saved ones, strips a UTF-8 BOM from line 1, and uses
# the `|| [[ -n "$line" ]]` idiom so the last line of a file lacking a
# trailing newline is still processed.
#
# Pure-bash implementation: no subprocesses, no command substitution, no
# pipelines whose errors would be swallowed by `|| true`.
scan_skill_md() {
    local file="$1" line in_fm=0 past_fm=0 lineno=0
    FM_OPENED=0
    FM_NAME="" FM_DESC="" FM_TOOLS=""
    FM_ARG_HINT="" FM_HAS_TAKES_ARG=0
    BODY_HAS_ENTER=0 BODY_HAS_EXIT=0 BODY_HAS_EXPLORE=0 BODY_HAS_IMPORTANT=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        [[ $lineno -eq 1 ]] && line="${line#$'\xEF\xBB\xBF'}"
        line="${line%$'\r'}"
        if (( past_fm == 0 )); then
            if [[ "$line" == "---" ]]; then
                in_fm=$((in_fm + 1))
                if (( in_fm == 1 )); then
                    FM_OPENED=1
                elif (( in_fm == 2 )); then
                    past_fm=1
                fi
                continue
            fi
            (( in_fm == 1 )) || continue
            if   [[ "$line" =~ ^name:[[:space:]]*(.*)$          ]]; then FM_NAME="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^description:[[:space:]]*(.*)$   ]]; then FM_DESC="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^allowed-tools:[[:space:]]*(.*)$ ]]; then FM_TOOLS="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^argument-hint:[[:space:]]*(.*)$ ]]; then FM_ARG_HINT="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^takes-arg:[[:space:]]*(true|false)[[:space:]]*$ ]]; then FM_HAS_TAKES_ARG=1
            fi
        else
            [[ "$line" == *"EnterPlanMode"* ]] && BODY_HAS_ENTER=1
            [[ "$line" == *"ExitPlanMode"*  ]] && BODY_HAS_EXIT=1
            [[ "$line" =~ subagent_type:[[:space:]]*\"?Explore\"? ]] && BODY_HAS_EXPLORE=1
            [[ "$line" == *"subagents MUST be launched with"* ]] && BODY_HAS_IMPORTANT=1
        fi
    done < "$file"
    # Pin return status: the body's trailing `&&` chains can yield non-zero
    # exit on the last iteration, which would trip `set -e` in the caller.
    return 0
}

# Scan README.md in a single pass. Sets globals:
#   README_REQUIRED_FOUND[]                       — parallel to REQUIRED_README_SECTIONS
#   HAS_USAGE                                     — convenience flag for the Usage-gated check below
#   HAS_SAFETY, HAS_EXAMPLE                       — optional / recommended sections
#   HAS_TAKES_ARG_ROW, HAS_ALLOWED_TOOLS_ROW      — Configuration table rows
#   README_DESC                                   — line 3 (one-line description per template)
#   README_TOOLS_CELL                             — right-trimmed Allowed tools cell, backticks stripped
#
# Same CRLF/BOM/trailing-newline hardening as scan_skill_md. Required-section
# detection iterates REQUIRED_README_SECTIONS so adding a new required
# section means editing only that constant.
#
# Heading match is case-sensitive (Title Case per project convention). The
# pre-refactor code used `grep -qi` which tolerated arbitrary casing; all 13
# existing skills use Title Case so tightening this is a no-op in practice
# and aligns with what CLAUDE.md actually specifies.
scan_readme_md() {
    local file="$1" line lineno=0 i
    HAS_USAGE=0 HAS_SAFETY=0 HAS_EXAMPLE=0
    HAS_ARG_HINT_ROW=0 HAS_ALLOWED_TOOLS_ROW=0 HAS_LEGACY_TAKES_ARG_ROW=0
    README_DESC="" README_TOOLS_CELL=""
    README_REQUIRED_FOUND=()
    for i in "${!REQUIRED_README_SECTIONS[@]}"; do README_REQUIRED_FOUND[i]=0; done
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        [[ $lineno -eq 1 ]] && line="${line#$'\xEF\xBB\xBF'}"
        line="${line%$'\r'}"
        [[ $lineno -eq 3 ]] && README_DESC="$line"
        for i in "${!REQUIRED_README_SECTIONS[@]}"; do
            if [[ "$line" == "## ${REQUIRED_README_SECTIONS[i]}"* ]]; then
                README_REQUIRED_FOUND[i]=1
            fi
        done
        case "$line" in
            '## Usage'*)    HAS_USAGE=1 ;;
            '## Safety'*)   HAS_SAFETY=1 ;;
            '## Example'*)  HAS_EXAMPLE=1 ;;
        esac
        if [[ "$line" =~ ^\|[[:space:]]*Argument[[:space:]]+hint[[:space:]]*\| ]]; then
            HAS_ARG_HINT_ROW=1
        fi
        # Detect legacy "Takes argument" row from the pre-argument-hint era so
        # `lint.sh` can prompt the user to migrate the README alongside the
        # SKILL.md frontmatter migration.
        if [[ "$line" =~ ^\|[[:space:]]*Takes[[:space:]]+argument[[:space:]]*\| ]]; then
            HAS_LEGACY_TAKES_ARG_ROW=1
        fi
        # Match a Configuration table row of the form:
        #   | Allowed tools | Bash, Read, Edit |
        # Capture group 1 is the right-trimmed middle cell. Backticks in the cell
        # (e.g. "| Allowed tools | `Read, Edit` |") are stripped via parameter expansion.
        if [[ "$line" =~ ^\|[[:space:]]*Allowed[[:space:]]+tools[[:space:]]*\|[[:space:]]*(.*[^[:space:]])[[:space:]]*\|[[:space:]]*$ ]]; then
            HAS_ALLOWED_TOOLS_ROW=1
            README_TOOLS_CELL="${BASH_REMATCH[1]//\`/}"
        fi
    done < "$file"
    # Pin return status (see scan_skill_md for the rationale).
    return 0
}

# Run every lint check against a single skill directory.
#
# Validates the skill's SKILL.md frontmatter (name/dir agreement, description
# punctuation, allowed-tools, EnterPlanMode/ExitPlanMode pairing in both
# frontmatter and body, IMPORTANT subagent block when Agent + Explore are
# used) and README.md (required sections, line-3 description match, Usage
# slash-command references, Configuration table rows, allowed-tools parity
# between SKILL.md frontmatter and README). Side effects: bumps the global
# TOTAL_PASS/TOTAL_FAIL/TOTAL_WARN counters via the pass/fail/warn helpers,
# and prints a "Checking: <skill>" banner to stdout. Args: $1 = skill name
# (a directory under $SKILLS_DIR). Uses bare `return` (not `return 1`) for
# early-exit on missing SKILL.md/README.md so the outer summary still runs.
lint_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"
    local skill_md="$skill_dir/SKILL.md"
    local readme_md="$skill_dir/README.md"
    local i

    printf '\n%sChecking: %s%s\n' "$BOLD" "$skill_name" "$NC"

    # Check SKILL.md exists
    if [[ ! -f "$skill_md" ]]; then
        fail "SKILL.md not found"
        return
    fi
    pass "SKILL.md exists"

    # Single-pass SKILL.md scan: populates FM_OPENED, FM_NAME, FM_DESC, FM_TOOLS,
    # BODY_HAS_ENTER/EXIT/EXPLORE/IMPORTANT.
    scan_skill_md "$skill_md"

    # Check frontmatter exists (file opens with ---)
    if (( ! FM_OPENED )); then
        fail "SKILL.md missing frontmatter (must start with ---)"
        return
    fi
    pass "SKILL.md has frontmatter"

    # Check required frontmatter fields
    if [[ -z "$FM_NAME" ]]; then
        fail "Missing required field: name"
    else
        pass "Has 'name' field: $FM_NAME"
        # Cross-reference: name should match directory
        if [[ "$FM_NAME" != "$skill_name" ]]; then
            fail "name '$FM_NAME' does not match directory '$skill_name'"
        else
            pass "name matches directory"
        fi
    fi

    if [[ -z "$FM_DESC" ]]; then
        fail "Missing required field: description"
    else
        pass "Has 'description' field"
        # Description should end with a period
        if [[ "$FM_DESC" == *"." ]]; then
            pass "description ends with a period"
        else
            warn "description does not end with a period"
        fi
    fi

    if [[ -z "$FM_TOOLS" ]]; then
        fail "Missing required field: allowed-tools"
    else
        pass "Has 'allowed-tools' field"
    fi

    # Argument-hint hygiene: the legacy `takes-arg: true` field is repo-internal
    # and never recognized by Claude Code. Warn (non-blocking) so existing forks
    # keep linting clean while the migration progresses.
    if (( FM_HAS_TAKES_ARG )); then
        warn "frontmatter declares legacy 'takes-arg' (repo-internal, ignored by Claude Code) — replace with 'argument-hint: <hint>'"
    fi
    if [[ -n "$FM_ARG_HINT" ]]; then
        pass "Has 'argument-hint' field: $FM_ARG_HINT"
    fi

    # Plan-mode discipline: when EnterPlanMode is declared, ExitPlanMode must
    # be paired in frontmatter AND both must be referenced in the body.
    if [[ "$FM_TOOLS" == *"EnterPlanMode"* ]]; then
        if [[ "$FM_TOOLS" == *"ExitPlanMode"* ]]; then
            pass "EnterPlanMode and ExitPlanMode are paired in allowed-tools"
        else
            fail "EnterPlanMode declared without ExitPlanMode in allowed-tools"
        fi
        if (( BODY_HAS_ENTER )); then
            pass "body references EnterPlanMode"
        else
            fail "EnterPlanMode in allowed-tools but never referenced in body"
        fi
        if (( BODY_HAS_EXIT )); then
            pass "body references ExitPlanMode"
        else
            fail "ExitPlanMode in allowed-tools but never referenced in body"
        fi
    fi

    # If multi-agent (Agent in tools and body launches Explore subagents),
    # require the canonical IMPORTANT block.
    if [[ "$FM_TOOLS" == *"Agent"* ]] && (( BODY_HAS_EXPLORE )); then
        if (( BODY_HAS_IMPORTANT )); then
            pass "IMPORTANT subagent block present"
        else
            warn "Agent + Explore subagents used but canonical IMPORTANT block missing"
        fi
    fi

    # Check README.md exists
    if [[ ! -f "$readme_md" ]]; then
        fail "README.md not found"
        return
    fi
    pass "README.md exists"

    # Single-pass README.md scan: populates README_REQUIRED_FOUND[], HAS_USAGE,
    # HAS_SAFETY, HAS_EXAMPLE, HAS_TAKES_ARG_ROW, HAS_ALLOWED_TOOLS_ROW,
    # README_DESC, README_TOOLS_CELL.
    scan_readme_md "$readme_md"

    # Required README sections (iterates the top-of-file constant)
    for i in "${!REQUIRED_README_SECTIONS[@]}"; do
        if (( README_REQUIRED_FOUND[i] )); then
            pass "README has section: ${REQUIRED_README_SECTIONS[i]}"
        else
            fail "README missing section: ${REQUIRED_README_SECTIONS[i]}"
        fi
    done

    # Optional checks
    if (( HAS_SAFETY )); then
        pass "README has section: Safety"
    else
        warn "README has no Safety section (optional)"
    fi

    # README discoverability: Example section is recommended (non-blocking).
    # Catches drift on new skills that forget to include sample output, which
    # is the strongest "is this the skill I need?" signal for users browsing
    # the catalogue. Non-fatal so existing forks keep linting clean.
    if (( HAS_EXAMPLE )); then
        pass "README has section: Example"
    else
        warn "README has no Example section (recommended — adds a sample-output transcript)"
    fi

    # README first line description should match SKILL.md description
    # (skip the "# Title" heading — line 3 is the description in the README template).
    if [[ -n "$FM_DESC" && -n "$README_DESC" ]]; then
        if [[ "$README_DESC" == "$FM_DESC" ]]; then
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
    # in awk / sed / sort propagate via pipefail. Use `grep -Fxv` so $FM_NAME
    # is treated as a literal whole-line string, not a regex — names with
    # metacharacters won't corrupt the match.
    #
    # Gate on HAS_USAGE so a README missing the Usage section doesn't get a
    # spurious "Usage examples reference /name correctly" pass alongside the
    # already-emitted "README missing section: Usage" failure.
    if (( HAS_USAGE )); then
        local bad_invocations
        bad_invocations="$(awk '/^## Usage/{flag=1; next} /^## /{flag=0} flag' "$readme_md" \
            | sed -nE 's|^[[:space:]]*>?[[:space:]]*(/[a-z][a-z0-9-]+).*$|\1|p' \
            | sort -u \
            | { grep -Fxv "/$FM_NAME" || true; })"
        if [[ -n "$bad_invocations" ]]; then
            # Native parameter expansion: replace every literal newline with a space,
            # no external `echo`/`tr` and no problematic flag-eating by `echo`.
            warn "README Usage references non-self slash commands: ${bad_invocations//$'\n'/ }"
        else
            pass "README Usage examples reference /$FM_NAME correctly"
        fi
    fi

    # Configuration table should include Argument hint and Allowed tools rows.
    # The legacy "Takes argument" row name predates the migration to the
    # official `argument-hint` field; warn separately so users know to rename.
    if (( HAS_ARG_HINT_ROW )); then
        pass "Configuration table has 'Argument hint' row"
    elif (( HAS_LEGACY_TAKES_ARG_ROW )); then
        warn "Configuration table uses legacy 'Takes argument' row — rename to 'Argument hint'"
    else
        warn "Configuration table missing 'Argument hint' row"
    fi
    if (( HAS_ALLOWED_TOOLS_ROW )); then
        pass "Configuration table has 'Allowed tools' row"
    else
        fail "Configuration table missing 'Allowed tools' row"
    fi

    # allowed-tools in SKILL.md frontmatter == Allowed tools row in README Configuration table.
    if [[ -n "$FM_TOOLS" && -n "$README_TOOLS_CELL" ]]; then
        # Strip whitespace via parameter expansion (no external `tr`, no `echo` flag-eating).
        local norm_skill_tools="${FM_TOOLS//[[:space:]]/}"
        local norm_readme_tools="${README_TOOLS_CELL//[[:space:]]/}"
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
