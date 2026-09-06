#!/usr/bin/env bash
set -euo pipefail

# Force byte-order (C locale) sorting so output is identical across platforms
# (macOS dev vs. Ubuntu CI) — lint.sh diffs the committed skills.json against a
# fresh run, so any locale-dependent `sort` order would cause a false mismatch.
export LC_ALL=C

# Generate skills.json — a machine-readable manifest of the skill catalogue.
#
# Walks skills/*/SKILL.md (alphabetical glob order for deterministic output),
# parses the frontmatter plus a few body signals (subagent use, cross-skill
# handoff targets, finding-ID prefixes), and emits the manifest to stdout.
#
# Usage:
#   bash tools/generate-manifest.sh > skills.json
#
# Requires jq (for safe JSON construction/escaping). lint.sh checks that the
# committed skills.json matches a fresh run of this script, so regenerate and
# commit whenever a SKILL.md frontmatter or handoff offer changes.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

if ! command -v jq >/dev/null 2>&1; then
    printf 'Error: jq is required to generate skills.json\n' >&2
    exit 1
fi

# Extract a single frontmatter field's raw value (text between the first two
# `---` delimiters). Matches only lines that start with "<field>:". Strips the
# trailing CR for CRLF-saved files. Prints empty when the field is absent.
fm_field() {
    awk -v field="$1" '
        BEGIN { c = 0 }
        { sub(/\r$/, "") }
        /^---$/ { c++; if (c >= 2) exit; next }
        c == 1 && index($0, field ":") == 1 {
            v = substr($0, length(field) + 2)
            sub(/^[[:space:]]+/, "", v)
            print v
            exit
        }
    ' "$2"
}

# Strip a single pair of surrounding double quotes (argument-hint values are
# YAML-quoted; everything else is a plain scalar and passes through unchanged).
strip_quotes() {
    local v="$1"
    v="${v#\"}"
    v="${v%\"}"
    printf '%s' "$v"
}

objs=()
for d in "$SKILLS_DIR"/*/; do
    smd="$d/SKILL.md"
    if [[ ! -f "$smd" ]]; then
        printf 'Warning: %s has no SKILL.md, skipping\n' "${d%/}" >&2
        continue
    fi

    name="$(strip_quotes "$(fm_field name "$smd")")"
    desc="$(strip_quotes "$(fm_field description "$smd")")"
    model="$(strip_quotes "$(fm_field model "$smd")")"
    effort="$(strip_quotes "$(fm_field effort "$smd")")"
    arghint="$(strip_quotes "$(fm_field argument-hint "$smd")")"
    wtu="$(strip_quotes "$(fm_field when_to_use "$smd")")"

    # allowed-tools: comma-separated scalar -> trimmed JSON array.
    tools_json="$(printf '%s' "$(fm_field allowed-tools "$smd")" \
        | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))')"

    # disable-model-invocation: boolean (default false when absent).
    if [[ "$(fm_field disable-model-invocation "$smd")" == "true" ]]; then dmi=true; else dmi=false; fi

    # uses_subagents: does the body launch Explore subagents — via the Agent tool
    # (subagent_type: "Explore") or inside a Workflow script (agentType: 'Explore')?
    if grep -qE 'subagent_type:[[:space:]]*"?Explore"?|agentType:[[:space:]]*['"'"'"]Explore['"'"'"]' "$smd"; then subagents=true; else subagents=false; fi

    # uses_workflow: does the body embed a Workflow script (`export const meta = {...}`)?
    if grep -qE '^export[[:space:]]+const[[:space:]]+meta' "$smd"; then workflow=true; else workflow=false; fi

    # handoffs: skills named in a handoff offer (same patterns lint.sh validates).
    handoffs_json="$(grep -hE '\*\*Skill handoff\.\*\*|\*\*Next:\*\*|suggest `/' "$smd" 2>/dev/null \
        | grep -oE '`/[a-z][a-z0-9-]+`' | tr -d '`/' | sort -u \
        | jq -R -s 'split("\n") | map(select(length > 0))' || true)"
    [[ -n "$handoffs_json" ]] || handoffs_json='[]'

    # finding_id_prefixes: distinct bold-bracket prefixes used in the body.
    prefixes_json="$(grep -hoE '\*\*\[[A-Z]+[0-9]+\]\*\*' "$smd" 2>/dev/null \
        | sed -E 's/.*\[([A-Z]+)[0-9]+\].*/\1/' | sort -u \
        | jq -R -s 'split("\n") | map(select(length > 0))' || true)"
    [[ -n "$prefixes_json" ]] || prefixes_json='[]'

    obj="$(jq -n \
        --arg name "$name" \
        --arg description "$desc" \
        --argjson allowed_tools "$tools_json" \
        --arg model "$model" \
        --arg effort "$effort" \
        --arg argument_hint "$arghint" \
        --arg when_to_use "$wtu" \
        --argjson disable_model_invocation "$dmi" \
        --argjson uses_subagents "$subagents" \
        --argjson uses_workflow "$workflow" \
        --argjson handoffs "$handoffs_json" \
        --argjson finding_id_prefixes "$prefixes_json" \
        '{
            name: $name,
            description: $description,
            allowed_tools: $allowed_tools,
            model: $model,
            effort: $effort,
            argument_hint: $argument_hint,
            when_to_use: $when_to_use,
            disable_model_invocation: $disable_model_invocation,
            uses_subagents: $uses_subagents,
            uses_workflow: $uses_workflow,
            handoffs: $handoffs,
            finding_id_prefixes: $finding_id_prefixes
        }
        | del(.[] | select(. == ""))
        | if .disable_model_invocation == false then del(.disable_model_invocation) else . end')"
    objs+=("$obj")
done

printf '%s\n' "${objs[@]}" | jq -s '{
    "$schema": "schemas/skill-frontmatter.schema.json",
    manifest_version: 1,
    generated_from: "skills/",
    skills: .
}'
