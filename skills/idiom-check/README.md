# Idiom Check

Audits a codebase through a programming-language-specific idiom lens, produces a prioritized report, and offers remediation in PR-sized bundles.

## What It Does

Where `/code-review` reviews a diff and `/refactor` works against a single target, `/idiom-check` audits the **whole codebase** through a **language-specific** idiom lens. The output is calibrated to the language: a Rust codebase is reviewed for ownership and trait design; a Python codebase for Pythonic constructs and modern type hints; a Go codebase for error-wrapping and channel idioms — and so on.

The skill runs in 5 steps:

1. **Detect Language and Resolve Scope** — Inspects manifests (`Cargo.toml`, `go.mod`, `pyproject.toml`, `package.json`, `Gemfile`, …), counts source files per language to pick the dominant one, gathers project conventions (`CLAUDE.md`, `.editorconfig`, language-specific lint configs), and narrows the scope when the codebase is large.
2. **Multi-Lens Language-Specific Analysis** — Launches 3 parallel read-only Opus 4.7 agents, each looking through one of three orthogonal language-specific lenses (e.g. for Rust: Ownership / Type-System / Idioms-&-Control-Flow). Each agent reads the full files in scope, caps findings at ~12, and frames every finding as "why in THIS codebase".
3. **Severity-Sorted Report** — Synthesizes findings (deduplicated, prioritized by severity and confidence) into a structured report with file:line, current pattern, idiomatic alternative, and rationale. Every report includes mandatory "Looks Good" callouts so positive practices aren't drowned out.
4. **PR-Sized Remediation Bundles** — Groups findings into tight, mergeable bundles (3-7 findings, 1-3 files, ~30-60 minute review effort each). Each bundle gets a title, theme, effort estimate, and risk note.
5. **Full Ship** — After approval, applies each bundle on its own branch off the default branch, commits, pushes, and opens an independent pull request via `gh pr create`. The user merges the PRs manually on GitHub.

The skill explicitly supports Rust, Python, TypeScript / JavaScript, Go, and Ruby with bespoke lens matrices, plus a generic three-lens template (Type System & Null Safety / Idiomatic Patterns / Modern Language Features) that adapts to Java, Kotlin, C#, Swift, PHP, and similar languages.

## Requirements

- Claude Code with **Opus model** access (resolves to Claude Opus 4.7).
- Git repository with a GitHub `origin` remote.
- `gh` CLI installed and authenticated (`gh auth status`) — used for `gh pr create` in Step 5.
- A detectable primary language with a recognized manifest in the repo root.

## Usage

```
/idiom-check
```

The skill takes no argument. It always audits the whole repository (with optional narrowing to a top-level subdirectory if more than 50 source files are detected).

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | No |
| Allowed tools | Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only analysis**: All three analysis agents (Step 2) use the Explore subagent type, which has Edit and Write denied at the agent level. No subagent can modify the project during the audit.
- **User approval gate**: Nothing is written, committed, branched, or pushed until you review the bundle plan and explicitly approve which bundles to apply.
- **One bundle, one PR**: Each approved bundle becomes a single pull request off the default branch. PRs are independent so they can be merged in any order; the skill never merges them itself.
- **Clean working tree required**: Before applying any bundle, the skill checks `git status --porcelain` and refuses to proceed (or offers to stash) if you have uncommitted changes outside the audit scope.
- **No `--no-verify`**: Pre-commit hooks always run on the bundle commits.
- **No network access during analysis**: The skill does not use WebSearch or WebFetch. The only network calls are `git push` and `gh pr create` during the ship phase, both gated on user approval.
- **Stacked-PR caveat surfaced**: The final report reminds you to avoid `gh pr merge --delete-branch` if you later restack any of the bundle PRs on top of each other, since it closes dependent PRs.
