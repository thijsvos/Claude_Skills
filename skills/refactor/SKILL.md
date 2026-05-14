---
name: refactor
description: Comprehensive code refactoring across correctness, security, performance, and maintainability with behavior-preserving, incremental changes.
allowed-tools: Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, TaskCreate, TaskUpdate, EnterPlanMode, ExitPlanMode
model: opus
effort: max
takes-arg: true
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a comprehensive, multi-dimensional refactoring analysis. Examine code through Correctness & Security, Performance & Efficiency, and Structure & Maintainability lenses simultaneously, synthesize cross-cutting insights, and — after user approval — execute behavior-preserving changes incrementally.

**ARGUMENTS:** The user may provide an optional target argument — a file path, directory, function/class name, branch name, commit range, or natural language description of what to refactor. If no argument is provided, auto-detect the scope from git state.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

---

## Step 1: Resolve Refactoring Target

Determine what code to refactor based on the argument and project state.

**If an argument was provided**, resolve it in this order:

1. **File path** — if the path exists on disk as a file, refactor that file:
   ```bash
   test -f "<path>" && echo "file"
   ```
   Read the file in full and identify all functions, classes, and modules within it.

2. **Directory path** — if the path is a directory, find all source files in it:
   ```bash
   test -d "<path>" && echo "directory"
   ```
   Find source files (exclude test files, node_modules, vendor, build artifacts):
   ```bash
   find "<path>" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.rs' -o -name '*.java' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.php' -o -name '*.cs' -o -name '*.kt' -o -name '*.swift' -o -name '*.c' -o -name '*.cpp' -o -name '*.h' \) ! -path '*/node_modules/*' ! -path '*/vendor/*' ! -path '*/__pycache__/*' ! -path '*/dist/*' ! -path '*/build/*' ! -path '*/target/*' ! -name '*.test.*' ! -name '*.spec.*' ! -name '*_test.*' | head -20
   ```
   If the directory contains more than 20 source files, list them and ask the user to narrow the scope or confirm they want to proceed (up to 30 files maximum).

3. **Function, class, or method name** — if the argument is not a valid path, search the codebase for it:
   ```bash
   grep -rn --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rb' --include='*.rs' --include='*.java' --include='*.tsx' --include='*.jsx' --include='*.php' --include='*.cs' --include='*.kt' -E "(function|def|func|class|fn|pub fn|export|interface|struct|enum|trait|impl)\s+<arg>" . 2>/dev/null | grep -v node_modules | grep -v vendor | head -10
   ```
   If found in multiple files, list them and ask the user to confirm which one. Read the full file(s) containing the match.

4. **Git ref** (branch or tag) — if `git rev-parse --verify <arg>` succeeds and it is not a file path, identify files changed on that ref compared to the default branch:
   ```bash
   default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
   [ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
   ```
   ```bash
   git diff "$default_branch"..."<arg>" --name-only --diff-filter=ACMR 2>/dev/null
   ```
   Read those files in full for refactoring analysis.

5. **Commit range** — if the argument contains `..`, use it directly:
   ```bash
   git diff "<range>" --name-only --diff-filter=ACMR 2>/dev/null
   ```
   Read those files in full.

6. **Natural language description** — if none of the above match, interpret the argument as a description of what to refactor (e.g., "the authentication module", "error handling in the API layer"). Search for relevant code by extracting keywords and scanning the codebase. Present found files and ask the user to confirm scope.

7. If none of the above produce results, inform the user and stop:
   > Could not resolve the argument as a file path, directory, code identifier, git ref, or code area description. Try: `/refactor src/auth/handler.ts` (file), `/refactor src/utils/` (directory), `/refactor handleLogin` (function), `/refactor feature-branch` (branch), `/refactor HEAD~3..HEAD` (range), or `/refactor "the database layer"` (description).

**If no argument was provided**, auto-detect in this priority order:

1. **Staged changes** — check for staged files:
   ```bash
   git diff --cached --name-only --diff-filter=ACMR 2>/dev/null
   ```
2. **Unstaged changes** — check for modified files:
   ```bash
   git diff --name-only --diff-filter=ACMR 2>/dev/null
   ```
3. **Branch diff** — if on a non-default branch, find files changed on this branch:
   ```bash
   default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
   [ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
   ```
   ```bash
   git diff "$default_branch"...HEAD --name-only --diff-filter=ACMR 2>/dev/null
   ```
4. If no changes are found, inform the user and stop:
   > No changed files detected. Working tree is clean. Specify a target: `/refactor src/auth/handler.ts` or `/refactor src/utils/`

Filter detected files to source files only (exclude test files, configs, docs, generated files). If more than 20 source files are detected, list them and ask the user to confirm or narrow the scope.

**After resolving the target**, gather project context by reading these files if they exist:
- `CLAUDE.md` — project conventions
- `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `pom.xml`, `build.gradle`, `composer.json` — project manifest
- `.eslintrc*`, `biome.json`, `.prettierrc*`, `.rubocop.yml`, `clippy.toml` — linting/style configuration
- `tsconfig.json`, `.editorconfig` — code style settings

**Detect test infrastructure** by checking:
- Existence of test files matching common patterns (`*.test.*`, `*.spec.*`, `*_test.*`, `test_*.*`)
- Test configuration files (`jest.config.*`, `vitest.config.*`, `pytest.ini`, `conftest.py`, etc.)
- Test runner command (look at `package.json` scripts, `Makefile`, CI workflows)

Record the test runner command for use in Step 4.

If the resolved scope covers more than 20 files or the total lines of code across all target files exceeds 1500, note this in the output so the user knows the analysis covers a large scope.

State the resolved target, detected project context, and test coverage status clearly before proceeding.

---

## Step 2: Multi-Dimensional Analysis

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The resolved target files from Step 1
- The project context (manifest, linting config, conventions)
- The language and framework detected

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

**IMPORTANT:** Instruct each agent to read the **full target files** (not just snippets) so they understand the complete code structure, how functions relate to each other, and whether a proposed change would break callers or dependents.

Each agent must return findings in this structured format:
- **ID**: agent-local identifier (e.g., C1, P1, S1)
- **File**: exact file path and line number(s)
- **Title**: short description (under 80 characters)
- **Current pattern**: what the code does now (include the relevant code snippet)
- **Proposed change**: what the code should do instead (include the replacement code snippet)
- **Rationale**: why this change improves the code
- **Confidence**: High / Medium / Low (how certain the agent is that this is an actual issue)
- **Risk**: Safe (behavior-preserving, no regression possible) / Moderate (behavior-preserving but context-dependent) / Breaking (intentionally changes behavior for correctness or security)

Each agent must also return 2-3 **"Strengths"** callouts — things the code already does well in their analysis dimension that should NOT be changed. This prevents unnecessary refactoring and acknowledges good practices.

---

### Agent 1: Correctness & Security

Review the target code for correctness issues, security vulnerabilities, and hardening opportunities:

**Correctness:**
- **Logic errors**: off-by-one errors, boundary conditions, incorrect comparisons, wrong operator precedence, short-circuit evaluation mistakes
- **Null / undefined safety**: potential null dereferences, optional chaining gaps, missing nil checks, unsafe type assertions or casts
- **Error handling**: swallowed exceptions, missing error propagation, catch blocks that hide failures, inconsistent error handling across similar code paths, unhandled promise rejections
- **Type safety**: implicit type coercions that cause bugs, unchecked type assertions, missing generic constraints, stringly-typed APIs that should use enums or unions
- **API contract violations**: wrong return types, missing required fields, incorrect parameter usage, broken interface contracts, violated pre/postconditions
- **Concurrency correctness**: race conditions, deadlock risks, shared mutable state without synchronization, non-atomic read-modify-write sequences, missing locks or semaphores
- **Edge cases**: empty inputs not handled, boundary values not considered, missing default cases in switch/match, unreachable code that should be reachable

**Security:**
- **Injection vulnerabilities**: SQL injection, XSS, command injection, LDAP injection, template injection, header injection
- **Input validation**: missing or insufficient validation at trust boundaries, unsanitized user input passed to sensitive operations
- **Authentication & authorization**: auth bypasses, privilege escalation paths, missing permission checks, session management weaknesses, insecure token handling
- **Secrets in code**: hardcoded API keys, credentials, tokens, connection strings, private keys, encryption keys
- **Error information leaks**: stack traces exposed to users, internal paths or identifiers in error messages, verbose error logging with sensitive data
- **Unsafe deserialization**: untrusted data parsed without validation (JSON.parse of user input with prototype pollution risk, pickle.loads, YAML.load, eval, Function constructor)
- **Cryptographic weaknesses**: weak algorithms (MD5, SHA1 for security purposes), hardcoded IVs/salts, predictable random (Math.random for tokens), custom crypto implementations
- **TOCTOU**: time-of-check-to-time-of-use vulnerabilities in file operations, permission checks, or state validation
- **Access control**: missing authorization on routes/endpoints, insecure direct object references, path traversal, directory traversal
- **Resource safety**: unbounded allocations from user input, missing timeouts on network calls, denial-of-service vectors, regex backtracking (ReDoS)
- **SSRF**: user-controlled URLs passed to HTTP clients without allowlist validation

For each finding, assign:
- **Severity**: Critical / High / Medium / Low

Return findings and strengths in the structured format described above.

---

### Agent 2: Performance & Efficiency

Review the target code for performance issues, resource efficiency, and optimization opportunities:

- **Algorithm complexity**: O(n^2) or worse where O(n) or O(n log n) is possible, unnecessary nested loops, quadratic string concatenation
- **N+1 queries**: database queries inside loops, repeated network calls that could be batched, sequential API calls that could be parallelized
- **Unnecessary allocations**: objects or arrays created in hot paths that could be reused, string concatenation in loops instead of builders/join, creating closures inside loops
- **Missing caching**: expensive pure computations repeated with the same inputs, redundant filesystem or network reads, repeated regex compilation
- **Sync-to-async opportunities**: blocking I/O operations that could be non-blocking, sequential independent operations that could be parallelized (Promise.all, asyncio.gather, goroutines)
- **Redundant computation**: values calculated multiple times when they could be computed once and stored, unnecessary re-renders (React), duplicate processing in middleware chains
- **Memory and resource leaks**: unclosed file handles, database connections, event listeners not removed, subscriptions not unsubscribed, timers not cleared, streams not drained
- **Resource lifecycle**: missing cleanup in destructors/finalizers/defer, connections not returned to pools, temporary files not deleted, acquired locks not released in error paths
- **Inefficient data structures**: arrays used where sets or maps would provide O(1) lookup, linear searches through sorted data, unnecessary copying of large structures, using objects as lookup tables without considering Map
- **Unindexed queries**: database queries on columns without indexes, missing composite indexes for multi-column WHERE clauses, full table scans
- **Scalability bottlenecks**: single-threaded processing where parallelism is possible, unbounded queues, missing backpressure, global locks that serialize concurrent operations
- **Bundle and payload size**: unused imports, large dependencies where lighter alternatives exist, missing tree-shaking, uncompressed responses, oversized payloads without pagination

For each finding, assign:
- **Impact**: High / Medium / Low (estimated performance improvement)

Return findings and strengths in the structured format described above.

---

### Agent 3: Structure & Maintainability

Review the target code for clarity, consistency, architecture, and maintainability:

**Readability:**
- **Naming clarity**: vague or misleading variable/function/class names (e.g., `data`, `temp`, `result`, `handle`), inconsistent naming conventions within the file, abbreviations that hurt readability
- **Function length and complexity**: functions over 40 lines, cyclomatic complexity above 10, functions doing more than one thing, too many parameters (5+)
- **Dead code**: unreachable code, unused imports, unused variables, commented-out code blocks, feature flags for long-removed features, functions with no callers
- **Magic numbers and strings**: unexplained numeric constants, hardcoded string values that should be named constants, repeated literal values
- **Complex conditionals**: deeply nested if/else chains that could be guard clauses, boolean expressions with more than 3 conditions, negated conditions that could be simplified, conditional chains that could be lookup tables
- **Deep nesting**: more than 3 levels of indentation, arrow code, early return patterns that could flatten logic, nested callbacks that could be async/await
- **Missing or misleading comments**: complex algorithms without explanation, comments that contradict the code, TODO/FIXME without context or ticket reference

**Architecture & Design:**
- **Separation of concerns**: business logic mixed with I/O, presentation mixed with data access, configuration scattered through application code
- **Module boundaries**: circular dependencies, modules with too many responsibilities, god classes/files, unclear public API surfaces
- **API ergonomics**: confusing function signatures, inconsistent parameter ordering, boolean parameters that should be enums or option objects, missing builder/fluent patterns for complex construction
- **Testability**: tightly coupled dependencies that prevent unit testing, hidden dependencies on global state, side effects in constructors, untestable private logic that should be extracted
- **Code duplication**: 3 or more occurrences of substantially similar logic (not minor repetition — only flag when extraction genuinely improves clarity), copy-paste patterns with slight variations
- **Inconsistent patterns**: different error handling approaches in the same module, mixed sync/async styles without reason, inconsistent logging or validation patterns
- **Unclear control flow**: complex state machines without documentation, non-obvious side effects, action-at-a-distance patterns, implicit ordering dependencies
- **Overly complex abstractions**: indirection that adds complexity without value, premature generalization, unnecessary design patterns, wrapper classes that only delegate

For each finding, assign:
- **Category**: naming / complexity / dead-code / magic-values / conditionals / nesting / separation / modules / api-design / testability / duplication / inconsistency / control-flow / abstraction / comments

Return findings and strengths in the structured format described above.

---

## Step 3: Synthesize Refactoring Plan

Collect all findings from the 3 agents and produce a single, structured refactoring plan.

**Synthesis rules:**

1. **Deduplicate**: If two agents flagged the same line or function for related reasons, merge into one finding with combined context and note all applicable pillars.

2. **Identify cross-cutting improvements**: Scan every finding's file path and line range. If two findings from different dimensions touch the same function or overlap within a 10-line span, flag them as cross-cutting. Also detect semantic overlaps (e.g., "remove dead code" from Structure that also eliminates an "unused crypto import with a known CVE" from Correctness). Cross-cutting findings get bracket notation: `[C+P]` (Correctness + Performance), `[C+S]` (Correctness + Structure), `[P+S]` (Performance + Structure), `[C+P+S]` (all three).

3. **Priority order**: Cross-cutting improvements first (highest value — one change, multiple benefits), then Correctness & Security (by severity: Critical > High > Medium > Low), then Performance & Efficiency (by impact: High > Medium > Low), then Structure & Maintainability (by category importance).

4. **Track dependencies**: If one change is a prerequisite for another (e.g., "extract validation function" enables "add input sanitization"), note the dependency with "depends on R3" notation.

5. **Assign IDs**: Number findings sequentially across the entire plan: `[R1]`, `[R2]`, `[R3]`, etc. (R for Refactoring).

6. **Be specific**: Every finding must have a file path and line number. Never say "consider improving" without pointing to exact code.

7. **Be actionable**: Every finding must include a concrete proposed change with code showing the transformation.

8. **Omit empty sections**: If there are no cross-cutting findings, do not include the cross-cutting heading. Same for individual pillar sections with no findings.

**Use this report format:**

```
## Refactoring Plan: <target description>

**Scope**: <N files, M total lines> | **Findings**: <X total> (<A cross-cutting, B correctness/security, C performance, D structure/maintainability>)

### Test Coverage

<Status: "Tests found — runner: `<command>`" or "No test coverage detected. Consider running `/test-gen` before applying changes to establish a regression baseline.">

---

### Cross-Cutting Improvements (one change, multiple benefits)

| ID | File:Line | Change | Pillars | Confidence | Risk |
|----|-----------|--------|---------|------------|------|
| [R1] | `path:42` | <description> | [C+S] | High | Safe |

**[R1]** `path/to/file.ext:42` — <Title>
**Current**: <what the code does now — include code snippet>
**Proposed**: <what it should do — include replacement code snippet>
**Why**: <benefits across the noted pillars>

---

### Correctness & Security

| ID | File:Line | Change | Severity | Confidence | Risk |
|----|-----------|--------|----------|------------|------|
| [R3] | `path:15` | <description> | High | High | Moderate |

**[R3]** `path/to/file.ext:15` — <Title>
**Current**: <pattern>
**Proposed**: <change>
**Why**: <rationale>

---

### Performance & Efficiency

| ID | File:Line | Change | Impact | Confidence | Risk |
|----|-----------|--------|--------|------------|------|

(same detail format)

---

### Structure & Maintainability

| ID | File:Line | Change | Category | Confidence | Risk |
|----|-----------|--------|----------|------------|------|

(same detail format)

---

### Dependencies

- [R5] depends on [R2] (extraction must happen before the security fix)

### Strengths (do not change)

- <Positive observation from Correctness & Security agent>
- <Positive observation from Performance & Efficiency agent>
- <Positive observation from Structure & Maintainability agent>

---

### Recommendation

<Brief assessment: how many changes are safe to apply immediately, how many need review, overall code quality impression, suggested approach (e.g., "apply all Safe changes first, then review the 2 Moderate-risk changes individually")>
```

After presenting the refactoring plan, call `ExitPlanMode`, then ask:

> **Ready to apply these changes?** (e.g., "apply all", "apply R1 through R4", "apply all safe changes", "apply security only", "skip R7")

---

## Step 4: Execute Refactoring

After the user approves (or modifies) the plan, apply the changes.

**Before making any changes**, capture a backup stash that you can identify reliably later. `git stash push` exits 0 even when there's nothing to stash, so use `git stash create` + `git stash store` to capture an explicit SHA instead:

```bash
backup_sha=$(git stash create "refactor-backup: before /refactor changes" 2>/dev/null)
if [ -n "$backup_sha" ]; then
  git stash store -m "refactor-backup: before /refactor changes" "$backup_sha"
fi
```

If `$backup_sha` is non-empty, a backup exists at that SHA — record it so a later "revert all" can use `git stash apply "$backup_sha"` (or `git checkout "$backup_sha" -- .`) to restore exactly that snapshot rather than popping whatever stash happens to be on top. If `$backup_sha` is empty, the working tree was clean — proceed without a backup.

If the repository has uncommitted changes outside the refactoring scope, warn the user before proceeding.

**Track progress with tasks.** Before applying the first change, call `TaskCreate` once per selected refactoring (one task per `[R<n>]` finding). The subject should be the finding ID + title (e.g., `[R3] Extract input validation`). Mark `in_progress` when you start the Edit for that finding and `completed` after it's applied. Refactoring plans regularly have 10-30 findings; this keeps the user oriented through the execution phase.

**Execution rules:**

1. **Apply in priority order**: Cross-cutting first, then Correctness & Security, then Performance & Efficiency, then Structure & Maintainability. Within each group, respect dependency ordering.

2. **Respect the user's selection**: If the user said "apply R1 through R4", only apply those. If "apply all safe changes", filter to Risk=Safe only. If "apply security only", filter to Correctness & Security findings and cross-cutting findings that include the Correctness pillar.

3. **Use Edit for modifications** to existing files. Use Write only when creating genuinely new files (e.g., extracting a module into a new file).

4. **Show each change**: After applying each finding, briefly state what was changed:
   > **[R1]** Applied: Extracted input validation into `validateUserInput()` and added sanitization. (`src/auth/handler.ts:42-58`)

5. **After all changes are applied**, if a test runner was detected, run the test suite:
   ```bash
   <test_runner_command> 2>&1
   ```

6. **If all tests pass:**
   > **All changes applied successfully.** <N> refactorings across <M> files. All tests pass.
   >
   > Run `git diff` to review the changes before committing.

7. **If tests fail**, report which tests failed and diagnose the likely cause:
   > **<P> tests passed, <F> failed.** The failure appears related to [R4] (<brief diagnosis>).
   >
   > Options:
   > - "revert R4" — undo just that change
   > - "revert all" — restore to pre-refactoring state (`git stash apply "$backup_sha"` against the SHA captured before Step 4)
   > - "fix it" — attempt to fix the failing test while preserving the refactoring intent

8. **If no test runner is available:**
   > **All changes applied.** No test runner detected — review changes manually with `git diff` before committing.
   >
   > Consider running `/test-gen` to create tests for the refactored code.
