# Docstring Check

Scans a codebase for missing, outdated, drifted, or inconsistent docstrings and applies behavior-preserving fixes matching the project's detected convention.

## What It Does

Audits code for three classes of docstring problem in parallel and produces a prioritized fix plan, delivered in 4 steps:

1. **Scope Resolution & Context Detection** -- resolves the audit target from a file path, directory, function/class name, branch, commit range, or natural language description. Defaults to a full-codebase scan if no target is given, with a scope-narrowing prompt for large repos. Reads project configuration to find the authoritative docstring style (`[tool.pydocstyle]`, `tsdoc.json`, `.rubocop.yml`, etc.); infers the style from existing docstrings when not configured. Detects available linters (ruff/pydocstyle, eslint-plugin-jsdoc, staticcheck, `missing_docs`, Javadoc, CS1591) and doc-build tools (Sphinx, TypeDoc, rustdoc, Doxygen) for verification.
2. **Multi-Dimensional Analysis** -- launches 3 parallel read-only Opus 4.7 agents: Coverage & Presence (missing docstrings on public API, delegating to native linters where available), Accuracy & Drift (signature-vs-docstring mismatch, missing `@returns`/`@throws`, type mismatches, copy-paste rot, stale descriptions), and Style & Convention (cross-file style consistency, under-informative content, formatting violations, link rot).
3. **Docstring Plan** -- synthesizes findings across all agents, deduplicates, batches by file, prioritizes public API first, and presents a plan with severity/confidence ratings and the full proposed docstring text for every finding.
4. **Incremental Execution** -- after user approval, applies docstring fixes via `Edit` (preserving indentation and matching the detected style), creates a git stash backup beforehand, re-runs the detected linter/doc-build tool to verify nothing regressed, and offers rollback if anything breaks.

The key behaviors are **convention-matching** (fixes adopt the project's detected style rather than imposing a default) and **linter delegation** (mechanical checks are offloaded to the project's existing tooling when available, so LLM effort goes to things only LLMs can do — signature drift, stale prose, and cross-file consistency).

## Requirements

- Claude Code with **Opus model** access
- Git repository (for pre-change backup and full-codebase scope-narrowing heuristics; not strictly required when specifying a target explicitly)
- Optional: the project's own docstring linter or doc-build tool installed (`ruff`, `pydocstyle`, `eslint-plugin-jsdoc`, `staticcheck`, `cargo doc`, `sphinx-build`, `typedoc`, etc.) — the skill auto-detects and uses whatever is present for verification

## Usage

```
/docstring-check                              # Full-codebase scan (prompts to narrow if > 50 files)
/docstring-check src/auth/handler.py          # Audit a specific file
/docstring-check src/utils/                   # Audit all files in a directory
/docstring-check AuthHandler                  # Find and audit a specific class or function
/docstring-check feature-branch               # Audit files changed on a branch
/docstring-check HEAD~10..HEAD                # Audit files from a commit range
/docstring-check "the public API"             # Natural language scope description
```

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes (optional: file path, directory, symbol name, branch, commit range, or description) |
| Allowed tools | Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion |

## Safety

- **Read-only analysis**: All analysis agents (Step 2) use the Explore subagent type, which cannot modify files
- **User approval gate**: No docstrings are edited until you review the full plan and explicitly approve changes
- **Pre-change backup**: Before applying fixes, the skill creates a git stash so you can restore the original state at any time
- **Post-change verification**: After fixes are applied, the skill re-runs the detected docstring linter or doc-build tool to catch regressions (link rot, type mismatches, broken `{@link}` references)
- **Rollback support**: If verification reports regressions, the skill offers to revert individual fixes or restore the entire pre-fix state
- **Convention-matching**: Fixes adopt the project's detected docstring style rather than imposing one; no cross-style rewrites happen without the user asking for them
- **No network access**: The skill does not use WebSearch or WebFetch — all analysis is purely local
- **No commits or pushes**: The skill never commits, pushes, or publishes — it only edits local files when you ask it to
