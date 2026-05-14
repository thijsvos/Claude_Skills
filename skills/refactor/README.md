# Refactor

Comprehensive code refactoring across correctness, security, performance, and maintainability with behavior-preserving, incremental changes.

## What It Does

Analyzes code through three complementary dimensions simultaneously and produces a prioritized refactoring plan, delivered in 4 steps:

1. **Scope Resolution** -- resolves the refactoring target from a file path, directory, function/class name, branch, commit range, or natural language description. Auto-detects recently changed files via git if no target is specified. Gathers project conventions and detects test coverage.
2. **Multi-Dimensional Analysis** -- launches 3 parallel read-only Opus 4.7 agents: Correctness & Security (logic errors, null safety, type safety, error handling, OWASP patterns, injection, auth, crypto), Performance & Efficiency (complexity, N+1 queries, allocations, caching, resource leaks, scalability), and Structure & Maintainability (naming, complexity, dead code, architecture, separation of concerns, API design, testability, duplication)
3. **Refactoring Plan** -- synthesizes findings across all dimensions, identifies cross-cutting improvements (one change benefiting multiple dimensions), deduplicates, tracks dependencies, and presents a prioritized plan with confidence and risk ratings for each change
4. **Incremental Execution** -- after user approval, applies changes in priority order, runs tests to verify behavior preservation, and offers rollback if anything breaks

The key innovation is **cross-cutting synthesis**: changes that improve multiple dimensions simultaneously are identified and prioritized highest, so you get maximum value from minimal changes.

## Requirements

- Claude Code with **Opus model** access
- Git repository (for auto-detection of changed files and pre-change backup; not strictly required when specifying a target explicitly)

## Usage

```
/refactor                                # Auto-detect: staged -> unstaged -> branch diff
/refactor src/auth/handler.ts            # Refactor a specific file
/refactor src/utils/                     # Refactor all files in a directory
/refactor handleLogin                    # Find and refactor a specific function
/refactor feature-branch                 # Refactor all files changed on a branch
/refactor HEAD~3..HEAD                   # Refactor files from a commit range
/refactor "the database layer"           # Natural language scope description
```

## Example

Refactoring a TypeScript auth handler that mixes correctness, security, and performance concerns:

```
/refactor src/auth/handler.ts
```

<details>
<summary>Sample plan</summary>

```
## Refactoring Plan: src/auth/handler.ts

**Scope**: 1 file, 240 total lines | **Findings**: 7 (2 cross-cutting, 2 correctness/security, 1 performance, 2 structure)

### Test Coverage
Tests found — runner: `npm test -- src/auth/handler.test.ts`. 14 tests, all passing.

---

### Cross-Cutting Improvements (one change, multiple benefits)

| ID   | File:Line                | Change                                      | Pillars | Confidence | Risk |
|------|--------------------------|---------------------------------------------|---------|------------|------|
| [R1] | `src/auth/handler.ts:42` | Replace inline crypto with `subtle.digest`  | [C+S]   | High       | Safe |
| [R2] | `src/auth/handler.ts:88` | Memoize `decodeToken` per request           | [P+S]   | High       | Safe |

---

### Correctness & Security

**[R3]** `src/auth/handler.ts:115` — Constant-time comparison missing on session-id check
The `===` comparison is variable-time; switch to `crypto.timingSafeEqual` to close the timing-oracle gap.

---

### Strengths

- Rate-limit middleware is correctly applied to `/login` and `/refresh` only.
- Error responses do not leak internal detail to clients.
```

</details>

> **Ready to apply these changes?** (e.g., "apply all", "apply R1 and R2", "apply all safe changes")

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes (optional: file path, directory, function name, branch, commit range, or description) |
| Allowed tools | Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, TaskCreate, TaskUpdate, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only analysis**: All analysis agents (Step 2) use the Explore subagent type, which cannot modify files
- **User approval gate**: No code is modified until you review the full refactoring plan and explicitly approve changes
- **Pre-change backup**: Before applying changes, the skill creates a git stash so you can restore the original state at any time
- **Test verification**: After applying changes, the skill runs the project's test suite (if detected) to verify behavior preservation
- **Rollback support**: If tests fail, the skill offers to revert individual changes or restore the entire pre-refactoring state
- **No network access**: The skill does not use WebSearch or WebFetch -- all analysis is purely local
- **No commits or pushes**: The skill never commits, pushes, or publishes -- it only edits local files when you ask it to
