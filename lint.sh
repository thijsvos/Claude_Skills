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

# Optional frontmatter schema validation. The SKILL.md frontmatter is checked
# against schemas/skill-frontmatter.schema.json with check-jsonschema when it is
# available (always in CI; opt-in locally via `pip install check-jsonschema`).
# When absent, the per-skill schema check is skipped and a single notice is
# printed near the top — local linting still works without Python tooling.
SCHEMA_FILE="$REPO_DIR/schemas/skill-frontmatter.schema.json"
if command -v check-jsonschema >/dev/null 2>&1 && [[ -f "$SCHEMA_FILE" ]]; then
    HAVE_JSONSCHEMA=1
else
    HAVE_JSONSCHEMA=0
fi

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

# Validate a SKILL.md's frontmatter against the JSON Schema with check-jsonschema.
# Typed validation of every frontmatter field: catches bad enum values
# (model/effort/shell/context), unknown keys (typos, stale fields — the schema
# sets additionalProperties:false), malformed allowed-tools, and a missing
# `agent` when `context: fork`. Complements the field-specific checks in
# lint_skill(), which emit friendlier messages for the common required-field
# mistakes. No-op when check-jsonschema is unavailable (announced once at
# startup) so local linting still works without Python tooling.
#
# Extracts the YAML between the first two `---` delimiters into a temp file and
# forces `--default-filetype yaml` so check-jsonschema parses the fragment as
# YAML regardless of the temp file's extension. Strips trailing CR so CRLF-saved
# SKILL.md files validate the same as LF-saved ones. Args: $1 = path to SKILL.md.
validate_frontmatter_schema() {
    local skill_md="$1"
    (( HAVE_JSONSCHEMA )) || return 0
    local fmfile schema_out schema_rc=0
    fmfile="$(mktemp "${TMPDIR:-/tmp}/skillfm.XXXXXX")" || { warn "could not create temp file for schema validation"; return 0; }
    awk 'BEGIN{c=0} {sub(/\r$/,"")} /^---$/{c++; if(c>=2) exit; next} c==1{print}' "$skill_md" > "$fmfile"
    schema_out="$(check-jsonschema --default-filetype yaml --schemafile "$SCHEMA_FILE" "$fmfile" 2>&1)" || schema_rc=$?
    rm -f "$fmfile"
    if (( schema_rc == 0 )); then
        pass "frontmatter validates against schema"
    else
        fail "frontmatter fails schema validation"
        # Indent the validator's own diagnostics under the [fail] line.
        printf '%s\n' "$schema_out" | sed 's/^/        /'
    fi
}

# Scan SKILL.md in a single pass. Sets globals:
#   FM_OPENED                                     — frontmatter opening-delimiter seen
#   FM_NAME, FM_DESC, FM_TOOLS                    — required frontmatter values
#   FM_ARG_HINT                                   — optional argument-hint value
#   FM_HAS_TAKES_ARG                              — legacy takes-arg field detected (for migration warning)
#   BODY_HAS_ENTER, BODY_HAS_EXIT                 — EnterPlanMode/ExitPlanMode references
#   BODY_HAS_EXPLORE, BODY_HAS_IMPORTANT          — Explore subagent + canonical IMPORTANT block
#   BODY_HAS_HANDOFF                              — canonical "**Skill handoff.**" offer present
#   BODY_USES_PHASE, BODY_USES_STEP              — "## Phase N" / "## Step N" section style
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
    BODY_HAS_IMPORTANT_EXPLORE=0 BODY_HAS_IMPORTANT_OPUS=0
    BODY_HAS_HANDOFF=0 BODY_USES_PHASE=0 BODY_USES_STEP=0
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
            if [[ "$line" == *"subagents MUST be launched with"* ]]; then
                BODY_HAS_IMPORTANT=1
                [[ "$line" == *'subagent_type: "Explore"'* ]] && BODY_HAS_IMPORTANT_EXPLORE=1
                [[ "$line" == *'model: "opus"'* ]] && BODY_HAS_IMPORTANT_OPUS=1
            fi
            [[ "$line" == *"**Skill handoff.**"* ]] && BODY_HAS_HANDOFF=1
            [[ "$line" =~ ^##[[:space:]]+Phase[[:space:]]+[0-9] ]] && BODY_USES_PHASE=1
            [[ "$line" =~ ^##[[:space:]]+Step[[:space:]]+[0-9]  ]] && BODY_USES_STEP=1
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
#   HAS_ARG_HINT_ROW, HAS_LEGACY_TAKES_ARG_ROW,
#   HAS_ALLOWED_TOOLS_ROW                         — Configuration table rows
#   README_DESC                                   — line 3 (one-line description per template)
#   README_TOOLS_CELL                             — right-trimmed Allowed tools cell, backticks stripped
#   README_SAYS_PHASE, README_SAYS_STEP          — "N-phase" / "delivered in N steps" workflow phrasing
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
    README_SAYS_PHASE=0 README_SAYS_STEP=0
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
        # Workflow-style phrasing in the "What It Does" prose, per CLAUDE.md README
        # Convention ("delivered in N steps" for step-numbered skills, "N-phase
        # analysis" for phase-numbered ones). Used to cross-check the body's
        # section style. A README that states neither leaves both flags 0.
        [[ "$line" =~ [0-9]+-phase|[0-9]+[[:space:]]+phases ]] && README_SAYS_PHASE=1
        [[ "$line" =~ [0-9]+[[:space:]]+steps ]] && README_SAYS_STEP=1
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

    # Comprehensive typed validation of the whole frontmatter (no-op when
    # check-jsonschema is unavailable). Backstops the field-specific checks above
    # and validates every optional field the bash scanner does not inspect.
    validate_frontmatter_schema "$skill_md"

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
        if (( BODY_HAS_IMPORTANT && BODY_HAS_IMPORTANT_EXPLORE && BODY_HAS_IMPORTANT_OPUS )); then
            pass "IMPORTANT subagent block present and well-formed"
        elif (( BODY_HAS_IMPORTANT )); then
            warn "IMPORTANT block present but missing the literal subagent_type: \"Explore\" and/or model: \"opus\" specifics"
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

    # Drift guard: skill prose must not hardcode a model version (e.g. "Opus 4.7").
    # The `opus` alias already resolves to the latest model, so de-version the prose
    # instead — otherwise it goes stale on every Opus/Haiku release. Scoped to this
    # skill's own files (never CHANGELOG, whose historical entries are intentional).
    if grep -Eq '(Opus|Haiku) [0-9]+\.[0-9]+' "$skill_md" "$readme_md"; then
        warn "hardcoded model version in prose (e.g. 'Opus 4.7') — de-version it; the 'opus' alias resolves to the latest model"
    else
        pass "no hardcoded model version in prose"
    fi

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

    # Root README skills-table parity: the description cell for this skill in the
    # root README table must match the SKILL.md description verbatim. CLAUDE.md
    # documents this as a hard requirement; before this check only the skill-local
    # README line-3 description was enforced, so the root table could silently drift.
    # index() does a literal (non-regex) substring search for the table link cell,
    # so skill names with metacharacters can't corrupt the match.
    local root_readme="$REPO_DIR/README.md"
    if [[ -n "$FM_DESC" && -f "$root_readme" ]]; then
        local root_row_desc
        root_row_desc="$(awk -F'|' -v n="$skill_name" \
            'index($0, "["n"](skills/"n"/)"){d=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", d); print d; exit}' \
            "$root_readme")"
        if [[ -z "$root_row_desc" ]]; then
            warn "no row found in root README skills table for '$skill_name'"
        elif [[ "$root_row_desc" == "$FM_DESC" ]]; then
            pass "root README skills-table description matches SKILL.md"
        else
            fail "root README skills-table description differs from SKILL.md description"
        fi
    fi

    # Handoff target existence: every skill named in a handoff offer — a
    # "**Skill handoff.**" line, a "> **Next:**" blockquote, or a github-audit
    # "suggest \`/x\`" bullet — must resolve to an installed skill directory.
    # Guards against typo'd handoff targets that would fail silently at runtime.
    # `tr -d` strips the backtick/slash wrapper from \`/name\` tokens.
    local handoff_targets bad_handoffs=""
    handoff_targets="$(grep -hE '\*\*Skill handoff\.\*\*|\*\*Next:\*\*|suggest `/' "$skill_md" 2>/dev/null \
        | grep -oE '`/[a-z][a-z0-9-]+`' \
        | tr -d '`/' | sort -u || true)"
    if [[ -n "$handoff_targets" ]]; then
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            [[ -d "$SKILLS_DIR/$t" ]] || bad_handoffs="$bad_handoffs /$t"
        done <<< "$handoff_targets"
        if [[ -n "$bad_handoffs" ]]; then
            warn "handoff references non-existent skill(s):$bad_handoffs"
        else
            pass "handoff targets resolve to installed skills"
        fi
    fi

    # Skill-tool / handoff coupling: a body that offers a Skill handoff must
    # declare the Skill tool (otherwise the handoff cannot fire — hard fail), and
    # a skill that declares Skill should actually use it (warn on a dangling
    # permission). No tool name other than the Skill tool contains "Skill", so the
    # substring test is unambiguous.
    local has_skill_tool=0
    [[ "$FM_TOOLS" == *"Skill"* ]] && has_skill_tool=1
    if (( BODY_HAS_HANDOFF )) && (( ! has_skill_tool )); then
        fail "body offers a Skill handoff but 'Skill' is not in allowed-tools"
    elif (( BODY_HAS_HANDOFF )) && (( has_skill_tool )); then
        pass "Skill handoff is backed by the Skill tool"
    elif (( has_skill_tool )) && (( ! BODY_HAS_HANDOFF )); then
        warn "'Skill' is in allowed-tools but no Skill handoff is offered in the body"
    fi

    # Phase/Step terminology consistency: the body's section style (## Phase N vs
    # ## Step N) must agree with the README's workflow phrasing ("N-phase analysis"
    # vs "delivered in N steps"). Only a genuine contradiction is flagged — a
    # README that states neither (a bare numbered list) is left alone.
    if (( BODY_USES_PHASE )) && (( README_SAYS_STEP )) && (( ! README_SAYS_PHASE )); then
        warn "body uses '## Phase' headings but README describes the workflow in steps"
    elif (( BODY_USES_STEP )) && (( README_SAYS_PHASE )) && (( ! README_SAYS_STEP )); then
        warn "body uses '## Step' headings but README describes the workflow in phases"
    elif (( BODY_USES_PHASE )) && (( README_SAYS_PHASE )); then
        pass "Phase terminology consistent between body and README"
    elif (( BODY_USES_STEP )) && (( README_SAYS_STEP )); then
        pass "Step terminology consistent between body and README"
    fi
}

# Cross-skill invariant: finding-ID prefixes must be unique across skills.
# Each skill reports findings under a distinct bold-bracket prefix (e.g. **[C1]**,
# **[R3]**); a prefix claimed by two skills makes report IDs ambiguous when one
# skill hands off to another. Builds "PREFIX skill" pairs (deduped per skill) and
# warns (non-blocking) on any prefix used by 2+ skills. awk associative arrays are
# fine here — that's awk, not bash, so the script's bash-3.2 constraint is unaffected.
# Repo-wide check: only meaningful across the whole catalogue, so callers gate it
# to no-argument (all-skills) runs.
check_finding_id_uniqueness() {
    printf '\n%sCross-skill checks%s\n' "$BOLD" "$NC"
    local pairs collisions
    pairs="$(
        for d in "$SKILLS_DIR"/*/; do
            s="${d%/}"; s="${s##*/}"
            [[ -f "$d/SKILL.md" ]] || continue
            grep -hoE '\*\*\[[A-Z]+[0-9]+\]\*\*' "$d/SKILL.md" 2>/dev/null \
                | sed -E 's/.*\[([A-Z]+)[0-9]+\].*/\1/' | sort -u \
                | sed "s/\$/ $s/" || true
        done
    )"
    collisions="$(printf '%s\n' "$pairs" \
        | awk 'NF==2{c[$1]++; m[$1]=(m[$1]==""?$2:m[$1]", "$2)} END{for(k in c) if(c[k]>1) print "["k"] used by "m[k]}' \
        | sort)"
    if [[ -n "$collisions" ]]; then
        while IFS= read -r c; do
            [[ -n "$c" ]] && warn "finding-ID prefix reused across skills: $c"
        done <<< "$collisions"
    else
        pass "finding-ID prefixes are unique across skills"
    fi
}

# Cross-skill invariant: the committed skills.json must match a fresh run of
# tools/generate-manifest.sh — catches a manifest left stale after a frontmatter
# or handoff change. Skips gracefully (uncounted note) when jq or the generator
# is unavailable so local linting still works without them; CI has both.
check_manifest_sync() {
    local gen="$REPO_DIR/tools/generate-manifest.sh"
    local committed="$REPO_DIR/skills.json"
    if ! command -v jq >/dev/null 2>&1; then
        printf '  %s[note]%s jq not found — skills.json sync check skipped (install jq to enable)\n' "$YELLOW" "$NC"
        return 0
    fi
    if [[ ! -f "$gen" ]]; then
        printf '  %s[note]%s tools/generate-manifest.sh missing — skills.json sync check skipped\n' "$YELLOW" "$NC"
        return 0
    fi
    if [[ ! -f "$committed" ]]; then
        fail "skills.json not found — generate it with: bash tools/generate-manifest.sh > skills.json"
        return 0
    fi
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/skillsmanifest.XXXXXX")" || { warn "could not create temp file for manifest sync check"; return 0; }
    if bash "$gen" > "$tmp" 2>/dev/null; then
        if diff -q "$tmp" "$committed" >/dev/null 2>&1; then
            pass "skills.json is in sync with skills/"
        else
            fail "skills.json is stale — regenerate with: bash tools/generate-manifest.sh > skills.json"
        fi
    else
        fail "tools/generate-manifest.sh failed to run"
    fi
    rm -f "$tmp"
}

printf '%sClaude Skills Linter%s\n' "$BOLD" "$NC"
printf '====================\n'

# Announce reduced coverage once (uncounted note — does not affect pass/fail/warn
# totals) when the optional schema validator is unavailable, so a clean local run
# without Python tooling stays green while signalling that schema checks were skipped.
if (( ! HAVE_JSONSCHEMA )); then
    if ! command -v check-jsonschema >/dev/null 2>&1; then
        printf '  %s[note]%s check-jsonschema not found — frontmatter schema validation skipped (enable: pip install check-jsonschema)\n' "$YELLOW" "$NC"
    else
        printf '  %s[note]%s schema file missing at %s — frontmatter schema validation skipped\n' "$YELLOW" "$NC" "$SCHEMA_FILE"
    fi
fi

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

# Repo-wide invariants run only on a full (no-argument) lint, not when checking a
# single named skill — they describe the whole catalogue, not one skill.
if [[ $# -eq 0 ]]; then
    check_finding_id_uniqueness
    check_manifest_sync
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
