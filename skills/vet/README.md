# Vet

Structured code review across correctness, security, performance, and conventions with prioritized findings and fix offers.

## What It Does

Analyzes code changes across multiple quality dimensions using parallel AI agents and produces a prioritized findings report:

1. **Scope Resolution** — Detects what to review: staged changes, unstaged changes, branch diff, or a user-specified scope (file, directory, branch, commit range)
2. **Project Context** — Reads project conventions (CLAUDE.md, linting configs, style guides) to understand what "good" looks like in this codebase
3. **Multi-Dimensional Review** — Runs a Workflow of 3 parallel read-only agents analyzing correctness & logic, security & performance, and conventions & test coverage
4. **Findings Report** — Structured report with severity levels (Critical / Warning / Suggestion), file:line references, concrete fix suggestions, and a verdict (Ship It / Pass With Warnings / Needs Changes)
5. **Remediation** — Offers to fix identified issues using finding IDs (e.g., "fix C1 and W2")

**Ultra mode** (`/vet ultra`) — an opt-in deep tier that extends the default Workflow with a verification stage: each dimension's findings are **adversarially verified** by an independent three-vote panel (a finding survives only if a majority can't refute it) before they reach the report, trading latency and tokens for higher precision. The default `/vet` keeps the fast single-round three-agent Workflow.

## Requirements

- Claude Code with Opus model access
- The `Workflow` tool (available on paid plans and the API); the skill falls back to the `Agent` tool when it is unavailable or disabled via the `disableWorkflows` setting
- Git repository (for diff-based scope detection; degrades gracefully for explicit file paths without git)

## Usage

```
/vet                    # Auto-detect: staged → unstaged → branch diff
/vet src/auth/          # Review changes in a specific directory
/vet feature-branch     # Review branch diff vs current branch
/vet HEAD~3..HEAD       # Review a specific commit range
/vet ultra              # Deep review: orchestrated find → adversarial-verify → synthesize
/vet ultra src/auth/    # Deep review scoped to a directory
```

## Example

Reviewing a recent change to an auth handler:

```
/vet src/auth/handler.ts
```

<details>
<summary>Sample report</summary>

```
## Vet: src/auth/handler.ts

**Scope**: 1 file changed (+47, -12) | **Findings**: 1 critical, 2 warnings, 3 suggestions

### Verdict: NEEDS CHANGES ✗

Token validation is bypassable on the refresh path; addressing C1 unblocks ship.

---

### Critical

**[C1]** `src/auth/handler.ts:88` — Refresh token reused after rotation
The refresh-token branch returns the *old* token to the client even after rotating server-side, leaving the previous token valid for the full TTL.
**Fix:** Return the rotated token from `rotateRefreshToken()` rather than the parameter passed in.

### Warnings

**[W1]** `src/auth/handler.ts:42` — Missing rate-limit on `/login` …
**[W2]** `src/auth/handler.ts:115` — Sensitive error returned to client …

### Looks Good

- Session expiry uses `crypto.timingSafeEqual` — constant-time comparison is the idiomatic Node choice.
- New tests in `handler.test.ts` cover the rotation path end-to-end.
```

</details>

> **Want me to fix any of these?** (e.g., "fix C1 and W2", "fix all critical")

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `xhigh` |
| Argument hint | `[ultra] [path \| identifier \| ref \| range]` |
| Allowed tools | Read, Grep, Glob, Bash, Agent, Workflow, Edit, AskUserQuestion, Skill, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only analysis**: All review agents use the Explore subagent type, which cannot modify files — the default and Ultra Workflows both spawn them with `agentType: 'Explore'`, the Agent-tool fallback with `subagent_type: "Explore"`
- **No auto-fix**: Files are only modified if you explicitly approve fixes after seeing the report
- **No network access**: The skill does not use WebSearch or WebFetch — all analysis is local
- **No commits or pushes**: The skill never commits, pushes, or publishes — it only reviews and optionally edits local files
