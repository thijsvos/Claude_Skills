# Test Gen

Analyzes code to generate comprehensive tests covering happy paths, edge cases, error handling, and integration points, matching the project's existing test conventions.

## What It Does

Generates high-quality tests through deep code analysis and convention detection, delivered in 5 steps:

1. **Scope Resolution** -- resolves the test target from a file path, directory, function/class name, or auto-detects recently changed files via git
2. **Deep Analysis** -- launches 3 parallel agents: Code Analysis (maps all functions, code paths, side effects), Test Environment Discovery (detects framework, conventions, existing coverage), and Edge Case Mapping (identifies boundary conditions, error scenarios, and coverage gaps)
3. **Test Plan** -- presents a structured plan showing every test scenario grouped by priority (critical vs nice-to-have), with already-covered scenarios identified
4. **Test Generation** -- after user approval, writes test files that match the project's exact conventions (naming, structure, assertions, mocking patterns)
5. **Verification** -- runs the generated tests and reports results, offering to fix any failures

## Requirements

- Claude Code with **Opus model** access
- Git repository (for auto-detection of changed files; not required when specifying a target explicitly)

## Usage

```
/test-gen                          # Auto-detect: staged -> unstaged -> branch diff
/test-gen src/utils.ts             # Generate tests for a specific file
/test-gen src/auth/                # Generate tests for all files in a directory
/test-gen handleLogin              # Find the function and generate tests for it
/test-gen src/api/users.py         # Works with any language
```

## Example

Generating tests for a date-parsing utility that has no test coverage:

```
/test-gen src/utils/parseDate.ts
```

<details>
<summary>Sample plan + result</summary>

```
## Test Plan: src/utils/parseDate.ts

**Target**: `parseDate` (5 branches) | **Tests**: 8 planned
**Framework**: Vitest | **Pattern**: Co-located `*.test.ts` files
**Test file**: `src/utils/parseDate.test.ts`

### Critical Tests (must-have)

**[T1]** `parseDate` — Parses ISO 8601 with timezone offset
Type: unit
Covers: happy path, the most-called shape in production usage

**[T2]** `parseDate` — Returns `null` for empty input
Type: edge case
Covers: explicit early-return branch at line 12

**[T3]** `parseDate` — Throws `InvalidDateError` for malformed input
Type: error handling
Covers: catch branch at line 28

### Additional Coverage (nice-to-have)

**[T4]–[T8]**: boundary years (1970, 2038), leap day, DST transitions, naive vs aware …

### Already Covered (skipping)

- `formatDate` — covered by `src/utils/formatDate.test.ts`

[After approval, generation, and verification]

> **All 8 tests passed.**
```

</details>

> **Ready to generate these tests?** (e.g., "yes", "skip T5 and T7", "only critical")

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes |
| Allowed tools | Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only analysis**: All analysis agents (Step 2) use the Explore subagent type, which cannot modify files
- **User approval gate**: No test files are written until you review and approve the test plan
- **No dependency installation without consent**: If no test framework is detected, the skill proposes setup steps and waits for approval before installing anything
- **No source code modification**: The skill only creates new test files -- it never modifies your source code
- **No commits or pushes**: The skill never commits, pushes, or publishes -- it only writes test files locally
