#!/usr/bin/env bash
set -euo pipefail

# Force byte-order (C locale) sorting for deterministic, cross-platform output.
export LC_ALL=C

# Generate the cross-skill handoff graph as a Mermaid flowchart from skills.json.
#
# Emits a fenced ```mermaid block to stdout: one node per skill (so skills with
# no handoffs still appear) and one edge per handoff. GitHub renders Mermaid
# natively, so the block can be embedded directly in Markdown.
#
# Usage:
#   bash tools/generate-handoff-graph.sh                 # print the mermaid block
#   bash tools/generate-handoff-graph.sh > docs/handoff-graph.md.frag
#
# The block is embedded in README.md between the <!-- handoff-graph:start --> and
# <!-- handoff-graph:end --> markers and mirrored in docs/handoff-graph.md.
# Regenerate after any change to a skill's handoff offers (which also changes
# skills.json — kept in sync by lint.sh). Node IDs replace "-" with "_" (Mermaid
# identifiers); the human-readable skill name stays in the node label.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_DIR/skills.json"

if ! command -v jq >/dev/null 2>&1; then
    printf 'Error: jq is required to generate the handoff graph\n' >&2
    exit 1
fi
[[ -f "$MANIFEST" ]] || {
    printf 'Error: %s not found — run tools/generate-manifest.sh first\n' "$MANIFEST" >&2
    exit 1
}

{
    echo '```mermaid'
    echo 'flowchart LR'
    jq -r '.skills[].name' "$MANIFEST" | while IFS= read -r n; do
        printf '    %s["%s"]\n' "${n//-/_}" "$n"
    done
    jq -r '.skills[] | .name as $s | .handoffs[]? | "\($s)\t\(.)"' "$MANIFEST" \
        | while IFS=$'\t' read -r src dst; do
            printf '    %s --> %s\n' "${src//-/_}" "${dst//-/_}"
        done
    echo '```'
}
