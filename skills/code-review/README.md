# Code Review

Structured code review across correctness, security, performance, and conventions with prioritized findings and fix offers.

## What It Does

Analyzes code changes across multiple quality dimensions using parallel AI agents and produces a prioritized findings report:

1. **Scope Resolution** — Detects what to review: staged changes, unstaged changes, branch diff, or a user-specified scope (file, directory, branch, commit range)
2. **Project Context** — Reads project conventions (CLAUDE.md, linting configs, style guides) to understand what "good" looks like in this codebase
3. **Multi-Dimensional Review** — Launches 3 parallel agents analyzing correctness & logic, security & performance, and conventions & test coverage
4. **Findings Report** — Structured report with severity levels (Critical / Warning / Suggestion), file:line references, concrete fix suggestions, and a verdict (Ship It / Pass With Warnings / Needs Changes)
5. **Remediation** — Offers to fix identified issues using finding IDs (e.g., "fix C1 and W2")

## Requirements

- Claude Code with Opus model access
- Git repository (for diff-based scope detection; degrades gracefully for explicit file paths without git)

## Usage

```
/code-review                    # Auto-detect: staged → unstaged → branch diff
/code-review src/auth/          # Review changes in a specific directory
/code-review feature-branch     # Review branch diff vs current branch
/code-review HEAD~3..HEAD       # Review a specific commit range
```

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes |
| Allowed tools | Read, Grep, Glob, Bash, Agent, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only analysis**: All review agents use the Explore subagent type, which cannot modify files
- **No auto-fix**: Files are only modified if you explicitly approve fixes after seeing the report
- **No network access**: The skill does not use WebSearch or WebFetch — all analysis is local
- **No commits or pushes**: The skill never commits, pushes, or publishes — it only reviews and optionally edits local files
