# Diagnose

Multi-agent root cause analysis that traces errors, correlates with recent changes, and identifies fixes with ranked hypotheses.

## What It Does

Performs structured root cause analysis through parallel investigation, delivered in 3 steps:

1. **Problem Parsing** -- classifies the input (stack trace, error message, file path, or natural language description) and identifies the error type, affected files, and language/framework context. If no argument is provided, auto-detects recent test or CI failures.
2. **Parallel Investigation** -- launches 3 parallel agents: Error Trace Analysis (follows the call chain backward to find where behavior diverges from intent), Change Correlation (checks recent git history for commits that could have introduced the bug), and Pattern & Context Analysis (searches for similar issues in the codebase and known issues online)
3. **Ranked Diagnosis** -- synthesizes findings into a report with evidence-ranked hypotheses, each with specific file:line references and a concrete code fix. Offers to apply the most likely fix.

## Requirements

- Claude Code with **Opus model** access
- For change correlation: a git repository with commit history
- For CI failure detection: `gh` CLI authenticated with the repository

## Usage

```
/diagnose TypeError: Cannot read properties of undefined (reading 'map')
/diagnose "the login page redirects to 404 after submitting"
/diagnose src/auth/handler.ts
/diagnose                                 # Auto-detect: check recent test/CI failures
```

## Example

Tracking down a runtime TypeError that surfaced after a refactor:

```
/diagnose "TypeError: Cannot read properties of undefined (reading 'map')"
```

<details>
<summary>Sample report</summary>

```
## Debug Report: TypeError on `users.map(...)` in dashboard render

**Error**: TypeError: Cannot read properties of undefined (reading 'map')
**Location**: `src/dashboard/UserList.tsx:54` | **Category**: runtime

---

### Root Cause

**[H1]** Empty-response shape changed from `[]` to `undefined` — Confidence: **High**
`src/api/users.ts:88` — A recent refactor switched the no-users path from `return []`
to `return data?.users`, but the dashboard still calls `.map(...)` without guarding.

**Evidence:**
- Commit `a3f12c4` (3 days ago) changed `return users || []` to `return data?.users`.
- That commit was the last to touch `src/api/users.ts` before the error appeared.
- `UserList.tsx:54` calls `.map` directly on the response.

**Fix:**
    const users = (await fetchUsers()) ?? [];
    return users.map(...);

**Why this fixes it:** Restores the empty-array invariant the caller already depends on.

---

### Alternative Hypotheses

**[H2]** Network failure returning `undefined` instead of throwing — Confidence: Medium
**[H3]** Race condition on initial render — Confidence: Low
```

</details>

> **Want me to apply the fix?** (e.g., "apply H1", "let me try H1 first")

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes (optional: error message, stack trace, file path, or description) |
| Allowed tools | Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, Edit, AskUserQuestion, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only investigation**: All analysis agents (Step 2) use the Explore subagent type, which cannot modify files
- **User approval gate**: No code is modified until you review the diagnosis and explicitly approve a fix
- **No commits or pushes**: The skill never commits, pushes, or publishes -- it only edits local files when you ask it to apply a fix
- **Test-first verification**: After applying a fix, the skill suggests running tests rather than assuming the fix is correct
