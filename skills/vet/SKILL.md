---
name: vet
description: Structured code review across correctness, security, performance, and conventions with prioritized findings and fix offers.
when_to_use: Use when the user asks for a review of pending changes, wants a verdict on a diff, asks "is this ready to merge", or names a file/branch/commit-range to review.
allowed-tools: Read, Grep, Glob, Bash, Agent, Workflow, Edit, AskUserQuestion, Skill, EnterPlanMode, ExitPlanMode
model: opus
effort: xhigh
argument-hint: "[ultra] [path | identifier | ref | range]"
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a comprehensive, structured code review. Analyze code changes across multiple quality dimensions and produce a clear, prioritized findings report.

**ARGUMENTS:** The user may provide an optional scope argument — a file path, directory, branch name, or commit range. If no argument is provided, auto-detect the scope.

**Ultra mode.** If the first argument token is `ultra` (e.g. `/vet ultra`, `/vet ultra src/auth/`), enable **Ultra mode** — a deeper review that adds an adversarial verification stage to the Workflow — and treat the *remaining* tokens as the scope argument. Without `ultra`, run the default review (Step 2's three-agent Workflow). See the **Ultra mode: Orchestrated Deep Review** section for how the two modes diverge.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

## Pre-rendered context

These values are computed by the harness before this skill runs (Claude Code dynamic context injection), so Step 1's auto-detect path has the working state in hand without spending a Bash round-trip on commands whose output is the same regardless of the argument:

- **Current branch:** !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)"`
- **Default branch:** !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || git rev-parse --verify main >/dev/null 2>&1 && echo main || git rev-parse --verify master >/dev/null 2>&1 && echo master || echo "(unknown)"`
- **Staged files:** !`git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | head -20 || echo "(none)"`
- **Unstaged files:** !`git diff --name-only --diff-filter=ACMR 2>/dev/null | head -20 || echo "(none)"`
- **Branch ahead of upstream:** !`git log --oneline @{u}.. 2>/dev/null | head -10 || echo "(no upstream or no ahead-commits)"`

If an argument was provided, prefer that argument over the pre-rendered auto-detect data. The pre-rendered context is an optimization for the no-argument path.

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
   > Could not resolve the argument as a file path, branch, or commit range. Try: `/vet src/auth/` (directory), `/vet feature-branch` (branch), or `/vet HEAD~3..HEAD` (range).

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
   > No changes found to review. Working tree is clean and branch matches the default branch. To review specific files, try: `/vet src/some-file.ts`

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

**Mode selection:**
- **Default** (no `ultra` argument) — run the three-agent Workflow described in this step. Fast and lightweight; the right call for everyday reviews.
- **Ultra** (`/vet ultra …`) — run the same Workflow with the extra adversarial-verify stage from the **Ultra mode: Orchestrated Deep Review** section, then continue to Step 3 with the confirmed findings. Use it when correctness matters more than latency: security-sensitive diffs, large changesets, or "leave no stone unturned" reviews.

Run the review as a **`Workflow` of exactly 3 read-only Explore agents in parallel** — one per dimension below. Call the `Workflow` tool with a script along these lines, substituting the scope and convention context resolved in Step 1 and each agent's brief verbatim from its `### Agent N` section:

```js
export const meta = {
  name: 'vet-review',
  description: 'Three-lens code review: correctness, security & performance, conventions',
  phases: [{ title: 'Review' }],
}

const SCOPE = `<the diff / changed files / exact git commands resolved in Step 1>`
const CONTEXT = `<the project convention context gathered in Step 1>`

// Mirrors the structured format below — the harness validates each agent's return against it.
const FINDINGS = {
  type: 'object', additionalProperties: false,
  properties: {
    findings: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        severity: { type: 'string', enum: ['critical', 'warning', 'suggestion'] },
        file: { type: 'string' }, line: { type: 'string' },
        title: { type: 'string', maxLength: 80 },
        description: { type: 'string' }, fix: { type: 'string' },
      },
      required: ['severity', 'file', 'line', 'title', 'description', 'fix'],
    } },
    looks_good: { type: 'array', minItems: 1, maxItems: 2, items: { type: 'string' } },
  },
  required: ['findings', 'looks_good'],
}

const DIMENSIONS = [
  { key: 'correctness',   brief: `<Agent 1 brief, verbatim>` },
  { key: 'security-perf', brief: `<Agent 2 brief, verbatim>` },
  { key: 'conventions',   brief: `<Agent 3 brief, verbatim>` },
]

const reports = await parallel(DIMENSIONS.map(d => () =>
  agent(`Review the following change set through the ${d.key} lens. Read the FULL files being changed, not just the diff hunks.\nSCOPE:\n${SCOPE}\nCONVENTIONS:\n${CONTEXT}\n\n${d.brief}`,
    { label: `review:${d.key}`, phase: 'Review', agentType: 'Explore', schema: FINDINGS })))

return { dimensions: DIMENSIONS.map((d, i) => ({ key: d.key, report: reports[i] })) }
```

Wait for the Workflow's completion notification before continuing — never synthesize from partial results. Each `report` is a validated `{ findings, looks_good }` object; a `null` report means that agent was skipped or failed — say so in the report header rather than silently dropping the dimension.

**Fallback.** If the `Workflow` tool is not available in this session, launch the same three briefs as **3 Explore subagents in parallel** via the `Agent` tool (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The diff content or the exact git commands to obtain it from Step 1
- The list of changed files
- Any project convention context gathered in Step 1

**IMPORTANT:** All subagents MUST be launched with `agentType: 'Explore'` inside the `Workflow` script (omit `model` — each agent inherits the session model), or, on the `Agent`-tool fallback, with `subagent_type: "Explore"` and `model: "opus"` (resolves to the latest Claude Opus, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The explicit `model: "opus"` on the `Agent` path pins the fan-out to the latest Opus even when a cheaper default subagent model is configured, so the analysis never silently runs on a smaller model. Never use general-purpose subagents in this skill.

**IMPORTANT:** Instruct each agent to read the **full files** being changed (not just the diff hunks) so they understand the surrounding context, module purpose, and how the changes integrate with existing code.

**Effort gate.** Adapt the file-reading depth to the active effort level via `${CLAUDE_EFFORT}`:
- `max` / `xhigh` / `high` — read full files for every changed module (default; current behavior).
- `medium` / `low` — read the changed hunks plus the immediate surrounding ~50 lines of context, not the full files. The review report header should note this as `read scope: hunks+context (effort=${CLAUDE_EFFORT})` so the user knows the depth was reduced.

This avoids the "max-effort review for a one-line typo fix" wall-clock penalty without compromising deep reviews when the user asked for them.

Each agent must return findings in this structured format (the `FINDINGS` schema above enforces it on the Workflow path; on the Agent-tool fallback, include the list in each prompt):
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

## Ultra mode: Orchestrated Deep Review (opt-in)

Run this **only** when Ultra mode is active (the user invoked `/vet ultra …`). It extends Step 2's three-agent Workflow with a stage that **adversarially verifies** every finding before you synthesize — trading latency and tokens for materially higher precision (fewer false positives). This is an explicit opt-in tier (see CLAUDE.md → *Opt-in orchestration tier*); never run it for a plain `/vet`, because the verify stage spawns three extra skeptics per finding.

Call the `Workflow` tool with a script along these lines. It reuses Step 2's `SCOPE`, `CONTEXT`, `FINDINGS`, and `DIMENSIONS` (same three briefs, same validated shape) and adds a verify stage that votes on each finding programmatically:

```js
export const meta = {
  name: 'vet-ultra',
  description: 'Deep multi-agent code review: find across dimensions, adversarially verify, synthesize',
  phases: [{ title: 'Find' }, { title: 'Verify' }],
}

const SCOPE = `<same as Step 2>`
const CONTEXT = `<same as Step 2>`
const FINDINGS = { /* same schema as Step 2 */ }
const DIMENSIONS = [ /* same three { key, brief } entries as Step 2 */ ]

const VERDICT = {
  type: 'object', additionalProperties: false,
  properties: {
    real: { type: 'boolean' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    reason: { type: 'string' },
  },
  required: ['real', 'confidence', 'reason'],
}

// Find -> adversarially verify each finding, per dimension, pipelined (no barrier):
// a dimension's findings start verifying as soon as that dimension returns.
const results = await pipeline(
  DIMENSIONS,
  d => agent(
    `Review the following change set through the ${d.key} lens. Read the FULL files, not just hunks.\nSCOPE:\n${SCOPE}\nCONVENTIONS:\n${CONTEXT}\n\n${d.brief}`,
    { label: `find:${d.key}`, phase: 'Find', schema: FINDINGS, agentType: 'Explore' }),
  found => parallel((found?.findings || []).map(f => () =>
    parallel([0, 1, 2].map(i => () =>
      agent(
        `Adversarially verify this review finding against the actual code. Try to REFUTE it; default to real=false if uncertain.\nSCOPE:\n${SCOPE}\nFINDING: ${f.severity.toUpperCase()} ${f.file}:${f.line} — ${f.title}\n${f.description}`,
        { label: `verify:${f.file}:${f.line}#${i}`, phase: 'Verify', schema: VERDICT, agentType: 'Explore' })))
      .then(votes => ({ finding: f, real: votes.filter(Boolean).filter(v => v.real).length >= 2 }))))
    .then(verified => ({ looks_good: found?.looks_good || [], verified }))   // carry the finder's callouts through
)

const confirmed = results.filter(Boolean).flatMap(r => r.verified).filter(Boolean).filter(v => v.real).map(v => v.finding)
const looks_good = results.filter(Boolean).flatMap(r => r.looks_good)
return { confirmed, looks_good }
```

Notes:
- **Model:** omit `model` on `agent()` — it inherits the session model, so under Opus (and ultracode) every subagent is the latest Opus automatically. `agentType: 'Explore'` keeps them **read-only** (Edit/Write denied), the same safety guarantee as the default Workflow.
- **Why a pipeline, not a barrier:** each dimension's findings begin verifying the moment that dimension returns — the security lens doesn't wait on the conventions lens.
- **Three skeptics per finding:** a finding survives only if ≥2 of 3 independent verifiers fail to refute it. This is what buys the precision gain over the default single-pass Workflow.
- After the Workflow returns `confirmed` and `looks_good`, continue to **Step 3** and render the standard report from them. Add `mode: ultra (adversarially verified)` to the report header so the user knows the deep tier ran.

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
## Vet: <scope description>

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

**Skill handoff.** If the review surfaced structural issues that go beyond the diff (e.g., a Critical finding that points at a long-standing architectural smell, or repeated patterns across the touched files), offer to hand off to `/refactor` via the `Skill` tool:

> **Next:** Want me to run `/refactor` on the touched files for a deeper structural pass? It uses three orthogonal lenses (correctness/security, performance, structure) and produces an incremental plan.

Only suggest the handoff when there's genuine signal that more work is warranted — don't surface it after a clean SHIP IT ✓ verdict or when only stylistic Suggestions remain.

If the report verdict is **SHIP IT ✓** with no actionable findings, skip the fix offer and confirm the code looks good.
