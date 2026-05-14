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
