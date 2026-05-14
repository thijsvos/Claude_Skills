---
name: test-gen
description: Analyzes code to generate comprehensive tests covering happy paths, edge cases, error handling, and integration points, matching the project's existing test conventions.
allowed-tools: Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, EnterPlanMode, ExitPlanMode
model: opus
effort: max
takes-arg: true
---

Call `EnterPlanMode` immediately before doing anything else.

You are generating comprehensive, high-quality tests for a codebase. Analyze the target code deeply, detect the project's test framework and conventions, present a structured test plan, and — after user approval — write the test files and verify they pass.

**ARGUMENTS:** The user may provide an optional target argument — a file path, directory, function name, class name, or module. If no argument is provided, auto-detect recently changed files.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

---

## Step 1: Resolve Test Target

Determine what code to generate tests for based on the argument and project state.

**If an argument was provided**, resolve it in this order:

1. **File path** — if the path exists on disk, generate tests for that file:
   ```bash
   test -f "<path>" && echo "file"
   ```
   Read the file and identify all testable exports (functions, classes, methods).

2. **Directory path** — if the path is a directory, find all source files in it:
   ```bash
   test -d "<path>" && echo "directory"
   ```
   Find source files (exclude test files, node_modules, vendor, build artifacts):
   ```bash
   find "<path>" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.rs' -o -name '*.java' -o -name '*.tsx' -o -name '*.jsx' \) ! -path '*/node_modules/*' ! -path '*/vendor/*' ! -path '*/__pycache__/*' ! -path '*/dist/*' ! -path '*/build/*' ! -name '*.test.*' ! -name '*.spec.*' ! -name '*_test.*' | head -20
   ```
   If the directory contains more than 20 source files, inform the user and ask them to narrow the scope.

3. **Function, class, or method name** — if the argument is not a valid path, search the codebase for it:
   ```bash
   grep -rn --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rb' --include='*.rs' --include='*.java' --include='*.tsx' --include='*.jsx' -E "(function|def|func|class|fn|pub fn|export)\s+<arg>" . 2>/dev/null | grep -v node_modules | grep -v vendor | head -10
   ```
   If found, resolve to the file(s) containing the match. If found in multiple files, list them and ask the user to confirm which one.

4. If none of the above match, inform the user and stop:
   > Could not resolve the argument as a file path, directory, or code identifier. Try: `/test-gen src/utils.ts` (file), `/test-gen src/auth/` (directory), or `/test-gen handleLogin` (function name).

**If no argument was provided**, auto-detect changed files:

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
   > No changed files detected. Working tree is clean. Specify a target: `/test-gen src/utils.ts` or `/test-gen src/auth/`

Filter the detected files to source files only (exclude test files, configs, docs, generated files). If more than 10 files are detected, list them and ask the user to confirm or narrow the scope.

**After resolving the target**, gather project context by reading these files if they exist:
- `CLAUDE.md` — project conventions
- `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `pom.xml`, `build.gradle` — project manifest
- `jest.config.*`, `vitest.config.*`, `pytest.ini`, `setup.cfg`, `conftest.py`, `phpunit.xml`, `.rspec`, `Cargo.toml [dev-dependencies]` — test configuration
- `tsconfig.json`, `.babelrc`, `babel.config.*` — build/transpile config that affects test setup
- `.github/workflows/*` — CI configuration (to identify how tests are run)

State the resolved target and detected project context clearly before proceeding.

---

## Step 2: Deep Analysis

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The resolved target files from Step 1
- The project context (manifest, test config, conventions)

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

**IMPORTANT:** Instruct each agent to read the **full target files** (not just snippets) so they understand the complete code structure, all branches, and how functions relate to each other.

---

### Agent 1: Code Analysis

Analyze the target code in depth. For every testable unit (function, method, class), document:

- **Signature**: name, parameters (types if available), return type
- **Purpose**: what the function does in one sentence
- **Code paths**: enumerate all branches (if/else, switch/case, early returns, try/catch, guard clauses). Count the total number of distinct paths.
- **Preconditions**: what must be true for the function to work correctly (parameter constraints, required state, environment assumptions)
- **Postconditions**: what the function guarantees after execution (return value properties, state changes, side effects)
- **Side effects**: does it modify external state? (database writes, file system operations, network calls, global/module state mutations, event emissions)
- **Dependencies**: what does it call or import? (other functions, modules, external services)
- **Error handling**: how does it handle errors? (throws, returns error codes, swallows exceptions, propagates)
- **Complexity assessment**: simple (linear, few paths), moderate (multiple branches, some edge cases), complex (nested logic, many paths, async flows, state machines)

Return findings as a structured list grouped by file, then by function/method.

---

### Agent 2: Test Environment Discovery

Detect the project's test infrastructure and conventions. Return:

**Framework Detection:**
- Which test framework is used (Jest, Vitest, Mocha, pytest, unittest, go test, RSpec, Minitest, Cargo test, JUnit, PHPUnit, etc.)
- Which assertion library (expect, assert, should, chai, etc.)
- Which mocking library (jest.mock, unittest.mock, gomock, RSpec doubles, mockito, etc.)
- Test runner command (how tests are executed: `npm test`, `pytest`, `go test ./...`, etc.)

**Convention Analysis** — find 3-5 existing test files and analyze them for:
- File naming pattern (e.g., `*.test.ts`, `*.spec.js`, `*_test.go`, `test_*.py`)
- File location pattern (e.g., `__tests__/` directory, `test/` directory, co-located `*.test.*` files)
- Test structure pattern (e.g., `describe/it` blocks, `test()` calls, `func TestX(t *testing.T)`, `def test_x():`)
- Import style for the module under test (relative imports, aliases, etc.)
- Setup/teardown patterns (`beforeEach`, `setUp`, `TestMain`, fixtures, factories)
- Mocking patterns (how are dependencies mocked — jest.mock, dependency injection, monkey patching, interfaces)
- Assertion style (which assertion methods are preferred, custom matchers, snapshot testing)
- Available test utilities (custom helpers, factories, fixtures, test data builders already in the project)

**Existing Test Coverage:**
- Are there already tests for the target files? If so, list them with file paths.
- What percentage of the target's public API is already covered?

If no test framework is detected, report this clearly. Include the project's language and package manager so the test plan can recommend an appropriate framework.

---

### Agent 3: Edge Case & Coverage Mapping

For each testable unit identified by Agent 1, identify specific test scenarios:

**Happy paths:**
- Normal input with expected output
- Common usage patterns

**Edge cases:**
- Empty inputs (empty string, empty array, empty object, zero, null, undefined, None)
- Boundary values (0, -1, MAX_INT, empty string vs whitespace, single element arrays)
- Type boundaries (NaN, Infinity, very long strings, deeply nested objects)

**Error paths:**
- Invalid input types
- Missing required parameters
- Network/IO failures (timeouts, connection refused, permission denied)
- Downstream dependency failures
- Concurrent access issues
- Resource exhaustion (out of memory patterns, file handle limits)

**Integration points:**
- How does this code interact with its dependencies?
- What happens when a dependency returns unexpected results?
- Are there ordering dependencies between calls?

**Already covered:**
- Cross-reference with existing tests (if any). For each scenario that is already tested, note the existing test file and describe what it covers.
- Identify gaps: which scenarios exist in the code but have no corresponding test?

Return findings as a structured list of test scenarios, each with:
- Target function/method
- Scenario description
- Category (happy path / edge case / error path / integration)
- Priority (critical / nice-to-have)
- Whether it is already covered by an existing test (and if so, where)

---

## Step 3: Synthesize Test Plan

Collect all findings from the 3 agents and produce a structured test plan.

**Synthesis rules:**
- **Deduplicate**: If agents identified the same scenario, merge into one test entry.
- **Prioritize**: Critical tests first (core functionality, error handling that prevents crashes, security-relevant paths), then nice-to-have (uncommon edge cases, performance characteristics).
- **Skip already covered**: If an existing test already covers a scenario comprehensively, list it under "Already Covered" and do not regenerate it.
- **Match conventions**: The plan should reference the detected framework, naming pattern, and file location so the user can confirm.
- **Be specific**: Each test entry should describe exactly what will be asserted, not vague statements like "test error handling."

**If no test framework was detected**, prepend this section to the plan:

```
### Test Infrastructure Setup (required first)

No test framework detected. Before generating tests, the following setup is needed:

**Recommended framework**: <framework appropriate for the language/project>
**Setup steps**:
1. Install: `<install command>`
2. Configuration file: `<what to create>`
3. Test script: `<what to add to package.json/pyproject.toml/etc.>`
4. Test directory: `<where tests will live>`

Shall I set this up before proceeding with test generation?
```

**Use this test plan format:**

```
## Test Plan: <target description>

**Target**: <file/module being tested> | **Tests**: <N tests planned>
**Framework**: <detected framework> | **Pattern**: <detected test pattern>
**Test file**: <path where the test file will be created>

### Critical Tests (must-have)

**[T1]** `<function_name>` — <scenario description>
Type: <unit / integration / edge case>
Covers: <what behavior or code path this validates>

**[T2]** `<function_name>` — <scenario description>
Type: <unit / integration / edge case>
Covers: <what behavior or code path this validates>

### Additional Coverage (nice-to-have)

**[T3]** `<function_name>` — <scenario description>
Type: <unit / integration / edge case>
Covers: <what behavior or code path this validates>

### Already Covered (skipping)

- `<function_name>` — <scenario> (covered by `<test_file_path>:<line>`)
```

After presenting the test plan, call `ExitPlanMode`, then ask:

> **Ready to generate these tests?** (e.g., "yes", "skip T5 and T7", "only critical", "add a test for <scenario>")

---

## Step 4: Generate Tests

After the user approves the test plan (or modifies it), write the test files.

**If test infrastructure setup was needed and approved**, do that first:
1. Install the test framework (run the install command)
2. Create the configuration file
3. Add the test script to the project manifest
4. Create the test directory if needed

**Test generation rules:**

1. **Follow the project's exact conventions** — use the naming pattern, file location, structure, import style, assertion style, and mocking patterns detected by Agent 2. The generated tests should look like they were written by the same developer who wrote the existing tests.

2. **File placement** — put the test file where the project convention dictates. If co-located tests, place next to the source file. If centralized test directory, place there with matching structure.

3. **Test structure** — group tests logically:
   - By function/method (each function gets its own describe block or test class)
   - Within each group, order: happy paths first, then edge cases, then error paths

4. **Descriptive names** — test names should describe the scenario in plain language:
   - Good: `it('returns empty array when input array is empty')`
   - Bad: `it('test empty')`

5. **Comments** — add comments only where the test setup or assertion is non-obvious. Do not add comments that restate what the code clearly does.

6. **Mocking** — use the project's mocking patterns. Mock external dependencies (network, database, file system) but not the unit under test. Keep mocks minimal and focused.

7. **Test data** — use realistic but minimal test data. Use the project's existing fixtures or factories if available. Define test data close to where it is used.

8. **Assertions** — make assertions specific. Assert exact values where possible, not just truthiness. For error paths, assert the specific error type or message.

9. **Independence** — each test must be independent. No test should depend on another test's execution or state. Clean up any side effects in teardown.

Write the complete test file(s) using Write or Edit tools. After writing, show the user a summary of what was created:

> **Generated**: `<test_file_path>` (<N tests> across <M test groups>)

---

## Step 5: Verify

Run the generated tests and report results.

```bash
# Use the detected test runner command from Agent 2
# Examples:
# npm test -- --testPathPattern="<test_file>"
# npx jest "<test_file>"
# npx vitest run "<test_file>"
# pytest "<test_file>" -v
# go test -v -run "TestFunctionName" ./path/to/package/
# cargo test --test <test_name>
# ruby -Itest "<test_file>"
# rspec "<test_file>"
```

**If all tests pass:**

> **All <N> tests passed.** The test file is ready at `<test_file_path>`.

**If some tests fail:**

Report which tests failed and why. Then offer to fix:

> **<P> passed, <F> failed.** The failures appear to be caused by <brief diagnosis>. Want me to fix them?

If the user agrees, fix the failing tests and re-run. Repeat until all tests pass or the user is satisfied.

**If the test runner is not available** (framework not installed, missing configuration):

> Could not run tests: <reason>. The test file has been written to `<test_file_path>`. Run it manually with: `<command>`
