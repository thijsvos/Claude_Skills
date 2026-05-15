---
name: diagnose
description: Multi-agent root cause analysis that traces errors, correlates with recent changes, and identifies fixes with ranked hypotheses.
allowed-tools: Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, Edit, AskUserQuestion, EnterPlanMode, ExitPlanMode
model: opus
effort: max
argument-hint: "[error | path | identifier]"
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a structured, multi-agent root cause analysis. Given an error message, stack trace, or description of unexpected behavior, systematically identify the root cause through parallel investigation and produce a ranked diagnosis with evidence-backed hypotheses and concrete fixes.

**ARGUMENTS:** The user may provide an error message, stack trace, file path, or natural language description of the problem. If no argument is provided, auto-detect recent failures.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

---

## Step 1: Parse the Problem

Determine what to investigate based on the argument and project state.

**If an argument was provided**, classify it:

1. **Stack trace or error message** — if the argument contains recognizable error patterns (exception names, `Error:`, `Traceback`, file paths with line numbers, `at <function>`), parse it to extract:
   - Error type and message
   - File paths and line numbers from the trace
   - Function/method names
   - Variable names mentioned in the error
   - The language/runtime (infer from trace format: Python tracebacks, Node.js stack traces, Go panics, Rust panics, Java exceptions, etc.)

2. **File path** — if the path exists on disk, the user is pointing to where the problem is. Read the file and look for obvious issues. Check recent changes to this file:
   ```bash
   git log --oneline -10 -- "<path>" 2>/dev/null
   git diff HEAD -- "<path>" 2>/dev/null
   ```

3. **Natural language description** — if the argument is a description of unexpected behavior (e.g., "the login page redirects to 404", "API returns 500 on POST"), extract keywords and search for relevant code:
   - Identify the feature area described (login, API, database, etc.)
   - Search for related route handlers, controllers, or entry points
   - Look for the specific behavior described (redirects, status codes, error messages)

4. If the argument is ambiguous, ask the user to clarify:
   > I'm not sure what to investigate. Can you provide an error message, stack trace, or describe the unexpected behavior?

**If no argument was provided**, auto-detect recent failures in this order:

1. **Recent test failures** — detect the project's test framework and run tests to capture failures:
   ```bash
   # Detect test runner
   test -f package.json && npm test 2>&1 | tail -80
   test -f pyproject.toml && pytest --tb=short -q 2>&1 | tail -80
   test -f Cargo.toml && cargo test 2>&1 | tail -80
   test -f go.mod && go test ./... 2>&1 | tail -80
   ```
   If tests fail, use the failure output as the error to investigate.

2. **Recent CI failures** — check for failed GitHub Actions runs. Capture the run id from JSON output and pass it to `gh run view`:
   ```bash
   run_id=$(gh run list --status failure --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)
   [ -n "$run_id" ] && gh run view "$run_id" --log-failed 2>/dev/null | tail -100
   ```

3. **Uncommitted changes with issues** — check if there are unstaged changes that might contain the problem:
   ```bash
   git diff --name-only 2>/dev/null
   ```
   If there are modified files, scan them for syntax errors or obvious issues.

4. If no failures are detected, ask the user:
   > No recent failures detected. What issue are you seeing? You can provide an error message, stack trace, or describe the unexpected behavior.

**After parsing**, state clearly:
- What the error/problem is
- Which files and lines are involved (if known)
- The language/framework context
- What broader code area needs investigation

Also gather project context by reading these files if they exist: `CLAUDE.md`, project manifest files (package.json, pyproject.toml, Cargo.toml, go.mod), and any relevant configuration files near the error site.

---

## Step 2: Parallel Root Cause Investigation

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The parsed error information from Step 1
- The file paths and line numbers involved
- The language/framework context
- Any project context gathered

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during investigation. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

Each agent must return findings in this structured format:
- **Hypothesis**: a clear statement of what might be wrong
- **Confidence**: High / Medium / Low
- **Evidence**: specific file:line references and observations that support the hypothesis
- **Fix**: a concrete code change that would resolve the issue (if applicable)

---

### Agent 1: Error Trace Analysis

Trace the error from the point of failure backward through the call chain.

- Read EVERY file referenced in the stack trace or error, not just the immediate error site
- If no stack trace is available, start from the code area identified in Step 1 and trace the execution path that would produce the described behavior
- Map the full data flow: where does the problematic data originate? What transformations does it undergo? Where do assumptions break?
- For each function in the trace, check:
  - Are input types consistent with what the caller passes?
  - Are return values handled correctly by the caller?
  - Are error cases handled? Could an unhandled error propagate here?
  - Are there null/undefined/nil checks where needed?
- Identify the exact line where behavior diverges from intent
- Check for common root causes by error category:
  - **TypeError / NullPointerException**: trace where the null/undefined value originates, not just where it's accessed
  - **Import / Module errors**: check file paths, export names, circular dependencies
  - **Connection / timeout errors**: check configuration, environment variables, network setup
  - **Permission errors**: check file permissions, authentication state, authorization logic
  - **Logic errors**: compare the code's behavior against its tests or documentation to find the divergence
- Read relevant test files to understand the intended behavior of the failing code

---

### Agent 2: Change Correlation

Investigate whether recent code changes introduced or exposed the bug.

- Get recent project history:
  ```bash
  git log --oneline -20 2>/dev/null
  ```
- Get recent changes to the files involved in the error. For each file path extracted from the error in Step 1, run:
  ```bash
  git log --oneline -10 -- "<path>" 2>/dev/null
  ```
- Get the full diff of the most recent commit touching each error file:
  ```bash
  commit_hash=$(git log -1 --format=%H -- "<path>" 2>/dev/null)
  [ -n "$commit_hash" ] && git show "$commit_hash" 2>/dev/null
  ```
- If on a feature branch, diff each error file against the default branch:
  ```bash
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  [ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
  [ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
  ```
  ```bash
  git diff "$default_branch"...HEAD -- "<path>" 2>/dev/null
  ```
  (Repeat the per-file `git log` / `git diff` commands for every path Step 1 extracted from the error.)
- Read the full diff of any suspect commits and assess:
  - Did a recent change modify the failing code path?
  - Did a recent change modify a dependency of the failing code (a function it calls, a config it reads)?
  - Were there merge conflicts in the relevant files that might have been resolved incorrectly?
  - Did a configuration change (.env, config files, manifest) coincide with the error?
  - Did a dependency version change that could cause behavioral differences?
- Check if the same code worked before the recent changes:
  ```bash
  git stash list 2>/dev/null
  ```
- If a specific commit looks suspect, identify exactly which lines it changed and whether those changes could cause the observed error

---

### Agent 3: Pattern & Context Analysis

Search for broader context: similar patterns, known issues, and environmental factors.

- Search the codebase for similar error patterns:
  - Same error type occurring elsewhere (might reveal a known workaround or correct pattern)
  - Same API or function used correctly elsewhere (might reveal what the failing code is doing differently)
  - Same data type or structure handled differently in other modules
- Search for markers near the error site. For each file path extracted in Step 1:
  ```bash
  grep -n "TODO\|FIXME\|HACK\|XXX\|WORKAROUND\|BUG" "<path>" 2>/dev/null
  ```
- Check project issues for similar problems. Extract 2-4 short keywords from the error message (function names, distinctive nouns) and pass them as a quoted search string:
  ```bash
  gh issue list --state all --search "<keywords>" --limit 5 2>/dev/null
  ```
- If the error involves a third-party library or API, search for known issues:
  - Use WebSearch: `"<library_name>" "<error_message>" site:github.com OR site:stackoverflow.com`
  - Check if there are known bugs in the version being used
  - Check if the API has been deprecated or changed
- Check for environmental factors:
  - Are there environment variables that the code expects but might not be set?
  - Does the error only occur in specific contexts (test vs production, CI vs local)?
  - Are there version mismatches between runtime/compiler and what the code expects?
- Check for dependency conflicts:
  - Are there multiple versions of the same package installed?
  - Are there peer dependency warnings?

---

## Step 3: Synthesize Diagnosis

Collect all findings from the 3 agents and produce a single, structured diagnosis report.

**Synthesis rules:**
- **Rank by evidence**: Order hypotheses by strength of evidence, not just plausibility. A hypothesis with a clear file:line reference and matching git diff is stronger than a guess based on the error message alone.
- **Prefer root causes**: If one hypothesis explains the surface error and another explains the deeper cause, lead with the root cause. "The null comes from line 42" is a symptom; "line 42 is null because the API response shape changed in commit abc123" is the root cause.
- **Deduplicate**: If multiple agents identified the same cause from different angles, merge into one hypothesis with combined evidence.
- **Be specific**: Every hypothesis must include exact file paths and line numbers. Never say "there might be an issue" without pointing to where.
- **Include the fix**: Every hypothesis with Medium or High confidence must include a concrete code fix — not "consider adding a null check" but the actual code that should replace the current code.

**Use this report format:**

```
## Debug Report: <one-line error summary>

**Error**: <error type and message>
**Location**: `<primary file:line>` | **Category**: <runtime / type / logic / configuration / dependency / concurrency>

---

### Root Cause

**[H1]** <Title> — Confidence: **High/Medium**
`<file:line>` — <description of what is wrong and why it produces the observed error>

**Evidence:**
- <specific observation from the code>
- <correlation with recent change, pattern, or known issue>
- <any additional supporting evidence>

**Fix:**
\`\`\`<language>
<exact code that should replace the buggy code>
\`\`\`

**Why this fixes it:** <one-sentence explanation connecting the fix to the root cause>

---

### Alternative Hypotheses

**[H2]** <Title> — Confidence: **Medium/Low**
`<file:line>` — <description>
**Evidence:** <what supports this hypothesis>
**Fix:**
\`\`\`<language>
<code fix>
\`\`\`

(repeat for additional hypotheses, if any)

---

### Related Findings

- <observations that are not direct causes but are worth noting>
- <e.g., missing error handling that could cause similar issues in the future>
- <e.g., test coverage gaps for the failing code path>

---

### Change History

<summary of relevant recent changes and whether they correlate with the error>
<if a specific commit introduced the regression, name it>
```

**Report guidelines:**
- If confidence in H1 is **High** and there is strong evidence, do not pad the report with unlikely alternatives. One strong hypothesis is better than three weak ones.
- If no hypothesis reaches **High** confidence, present all Medium/Low hypotheses clearly and suggest how the user can narrow it down (e.g., "add a console.log at line X to check the value of Y").
- If the error appears to be environmental (wrong Node version, missing env var, misconfigured database), say so clearly and provide the exact steps to fix the environment.
- If the error is in a third-party dependency and not in user code, link to the relevant issue/PR and suggest a workaround or version pin.

---

After presenting the diagnosis, call `ExitPlanMode`.

If the root cause hypothesis has **High** or **Medium** confidence and includes a code fix, ask:

> **Want me to apply the fix?** (e.g., "apply H1", "apply H1 and H2", "let me try H1 first")

If the user requests a fix:
1. Apply the fix using Edit, starting with the highest-confidence hypothesis
2. Show what was changed
3. If tests exist for the affected code, suggest running them:
   > Run `<test command>` to verify the fix resolves the issue.
4. If the user reports the fix for H1 didn't work, suggest trying H2

If no hypothesis has a code fix (e.g., environmental issue), provide the exact steps the user should take to resolve it.
