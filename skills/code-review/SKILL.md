---
name: code-review
description: Structured code review across correctness, security, performance, and conventions with prioritized findings and fix offers.
when_to_use: Use when the user asks for a review of pending changes, wants a verdict on a diff, asks "is this ready to merge", or names a file/branch/commit-range to review.
allowed-tools: Read, Grep, Glob, Bash, Agent, EnterPlanMode, ExitPlanMode
model: opus
effort: max
takes-arg: true
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a comprehensive, structured code review. Analyze code changes across multiple quality dimensions and produce a clear, prioritized findings report.

**ARGUMENTS:** The user may provide an optional scope argument — a file path, directory, branch name, or commit range. If no argument is provided, auto-detect the scope.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

---

## Step 1: Determine Review Scope

Resolve what code to review based on the argument and current git state.

**If an argument was provided**, resolve it in this order:

1. **File or directory path** — if the path exists on disk, review changes in those files:
   ```bash
   git diff -- "<path>"
   git diff --cached -- "<path>"
   ```
   If the path has no git changes, read the file(s) and review them holistically.

2. **Git ref** (branch, tag, or commit) — if `git rev-parse --verify <arg>` succeeds and it is not a file path, review the diff between that ref and the current HEAD:
   ```bash
   git diff "<arg>"...HEAD
   ```

3. **Commit range** — if the argument contains `..`, use it directly:
   ```bash
   git diff "<range>"
   ```

4. If none of the above match, inform the user and stop:
   > Could not resolve the argument as a file path, branch, or commit range. Try: `/code-review src/auth/` (directory), `/code-review feature-branch` (branch), or `/code-review HEAD~3..HEAD` (range).

**If no argument was provided**, auto-detect in this priority order:

1. **Staged changes** — run `git diff --cached`. If non-empty, use these as the review scope. Also include unstaged changes in the same files for full context.
2. **Unstaged changes** — run `git diff`. If non-empty, use these as the review scope.
3. **Branch diff** — if on a non-default branch, diff against the default branch:
   ```bash
   default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
   [ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
   ```
   ```bash
   git diff "$default_branch"...HEAD
   ```
4. If none of the above produce changes, inform the user and stop:
   > No changes found to review. Working tree is clean and branch matches the default branch. To review specific files, try: `/code-review src/some-file.ts`

**After resolving scope**, capture:
- The full diff content
- The list of changed files with stats (`git diff --stat`)
- The number of files, insertions, and deletions

If the diff is not in a git repository, fall back to reading the specified files directly and reviewing them holistically.

If the diff covers more than 50 files or 2000+ changed lines, note this in the report header so the user knows the review covers a large scope.

**Also gather project context** by reading these files if they exist: `CLAUDE.md`, `.editorconfig`, and any linting/style configuration files (e.g., `.eslintrc*`, `pyproject.toml`, `.rubocop.yml`, `biome.json`, `.prettierrc`). This context will be passed to the review agents so they can evaluate convention adherence.

State the detected scope clearly before proceeding to Step 2.

---

## Step 2: Multi-Dimensional Review

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The diff content or the exact git commands to obtain it from Step 1
- The list of changed files
- Any project convention context gathered in Step 1

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

**IMPORTANT:** Instruct each agent to read the **full files** being changed (not just the diff hunks) so they understand the surrounding context, module purpose, and how the changes integrate with existing code.

**Effort gate.** Adapt the file-reading depth to the active effort level via `${CLAUDE_EFFORT}`:
- `max` / `xhigh` / `high` — read full files for every changed module (default; current behavior).
- `medium` / `low` / `min` — read the changed hunks plus the immediate surrounding ~50 lines of context, not the full files. The review report header should note this as `read scope: hunks+context (effort=${CLAUDE_EFFORT})` so the user knows the depth was reduced.

This avoids the "max-effort review for a one-line typo fix" wall-clock penalty without compromising deep reviews when the user asked for them.

Each agent must return findings in this structured format:
- **Severity**: Critical / Warning / Suggestion
- **File**: exact file path and line number
- **Title**: short description (under 80 characters)
- **Description**: what the issue is and why it matters
- **Fix**: a concrete, specific suggestion (code snippet when applicable)

Each agent must also return 1-2 **"Looks Good"** callouts — things the changed code does well.

---

### Agent 1: Correctness & Logic

Review the changes for logical correctness:

- Does the code do what it appears to intend?
- Off-by-one errors, boundary conditions, edge cases
- Null / undefined / nil dereferences and unsafe access
- Race conditions, concurrency issues, deadlock risks
- Unhandled error paths and missing error propagation
- State transitions and invariant violations
- API contract violations (wrong types, missing fields, incorrect return values)
- Broken assumptions about input data (empty arrays, missing keys, unexpected types)
- Resource cleanup (open handles, connections, subscriptions not closed)

---

### Agent 2: Security & Performance

Review the changes for security vulnerabilities and performance issues:

**Security:**
- Injection vulnerabilities: SQL injection, XSS, command injection, LDAP injection
- Hardcoded secrets, API keys, credentials, or tokens in the diff
- Path traversal and directory traversal risks
- Insecure cryptography (weak algorithms, hardcoded IVs, predictable random)
- Authentication and authorization bypasses
- Sensitive data exposure (logging PII, returning internal errors to users)
- Unsafe deserialization
- SSRF (server-side request forgery) risks
- Missing input validation at trust boundaries

**Performance:**
- N+1 query patterns and unnecessary database round-trips
- O(n²) or worse algorithmic complexity where linear is possible
- Unnecessary memory allocations in hot paths
- Blocking operations on event loops or main threads
- Missing caching opportunities for expensive operations
- Resource leaks (unclosed streams, connections, file handles)
- Unbounded growth (missing pagination, unbounded arrays, unlimited retries)

---

### Agent 3: Conventions, Tests & Documentation

Review the changes for project consistency, test coverage, and documentation:

**Conventions:**
- Does the code follow the project's established patterns and style?
- Naming consistency (variables, functions, files, classes)
- File organization and module structure conventions
- Error handling patterns (does it match how the rest of the codebase handles errors?)
- Import style and dependency patterns
- Code hygiene: leftover debug statements (`console.log`, `print`, `debugger`, `binding.pry`), commented-out code blocks, TODO/FIXME without context or ticket reference, hardcoded magic numbers or strings

**Test Coverage:**
- Are the changes covered by tests? Identify which changed functions/paths lack tests.
- Are there missing test cases for edge cases, error paths, or boundary conditions?
- Do existing tests still make sense after the changes?
- If the project has no test infrastructure, note this as a single suggestion rather than flagging every file.

**Documentation:**
- Do public APIs, exports, or interfaces have appropriate documentation?
- Are complex algorithms or non-obvious logic explained with comments?
- Do README, docs, or changelogs need updates for these changes?

---

## Step 3: Synthesize Findings Report

Collect all findings from the 3 agents and produce a single, structured report.

**Synthesis rules:**
- **Deduplicate**: If two agents flagged the same line for related reasons, merge into one finding with combined context.
- **Prioritize**: Sort by severity — Critical first, then Warnings, then Suggestions.
- **Be specific**: Every finding must have a file path and line number. Never say "potential issue" without pointing to the exact code.
- **Be actionable**: Every finding must include a concrete fix suggestion. Include a code snippet showing the fix when possible.
- **Omit empty sections**: If there are no Critical findings, do not include the Critical heading.
- **"Looks Good" is mandatory**: Always include 3-5 positive callouts from the agents. Acknowledge what was done well.

**Use this report format:**

```
## Code Review: <scope description>

**Scope**: <N files changed (+X, -Y)> | **Findings**: <A critical, B warnings, C suggestions>

### Verdict: <SHIP IT ✓ | NEEDS CHANGES ✗ | PASS WITH WARNINGS ⚠>

<One-sentence summary of the overall assessment>

---

### Critical

**[C1]** `path/to/file.ext:line` — <Title>
<Description of the issue and why it matters>
**Fix:** <Concrete suggestion or code snippet>

---

### Warnings

**[W1]** `path/to/file.ext:line` — <Title>
<Description>
**Fix:** <Suggestion>

---

### Suggestions

**[S1]** `path/to/file.ext:line` — <Title>
<Description>
**Fix:** <Suggestion>

---

### Looks Good

- <Positive callout with specific file/pattern reference>
- <Positive callout>
```

**Verdict logic:**
- **SHIP IT ✓** — Zero critical findings, zero or few minor warnings
- **PASS WITH WARNINGS ⚠** — Zero critical findings, but warnings that should be addressed
- **NEEDS CHANGES ✗** — One or more critical findings that must be fixed before shipping

---

## Step 4: Offer Remediation

After presenting the report, call `ExitPlanMode`.

If there are any Critical or Warning findings, ask:

> **Want me to fix any of these?** (e.g., "fix all", "fix C1 and W2", "fix all critical")

If the user requests fixes:
1. Address findings in severity order (Critical first, then Warnings)
2. Show each change clearly
3. After all fixes are applied, briefly note what was changed

If the report verdict is **SHIP IT ✓** with no actionable findings, skip the fix offer and confirm the code looks good.
