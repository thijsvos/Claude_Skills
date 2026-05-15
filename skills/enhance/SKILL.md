---
name: enhance
description: Performs deep multi-phase project analysis to identify and recommend the single most impactful addition to implement.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, EnterPlanMode, ExitPlanMode, AskUserQuestion
model: opus
effort: max
---

Call `EnterPlanMode` immediately before doing anything else.

You are about to perform a deep, multi-phase analysis of the current project to identify and recommend THE single most impactful, innovative addition you can make. This is not a code review or a list of improvements — it's a strategic deep-dive that culminates in one compelling, concrete recommendation.

Execute each phase thoroughly before moving to the next. Use subagents for parallel exploration wherever possible to maximize depth and speed.

**Ask the user questions at any point during the analysis when it would improve the result.** Don't make assumptions about priorities, pain points, or goals when you can ask. Examples: after Phase 1, ask what areas matter most to them; during Phase 3, confirm which problems they actually feel; before Phase 4, ask if there are constraints or preferences you should know about. The goal is a recommendation tailored to what the user needs right now, not a generic suggestion.

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

---

## Phase 1: Deep Project Reconnaissance

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`) covering three orthogonal lenses on the project. The IMPORTANT block above governs how every subagent must be configured.

Each agent should return a structured digest of its findings. The synthesis in Phase 5 will weight hotspot files higher, flag single-author areas as bus-factor risk, treat deleted files as evidence of abandoned approaches, and use velocity as a proxy for capacity to absorb change.

---

### Agent 1: Structure & Stack

Map the project's shape and the tools it's built from:

- Explore the full directory tree to understand the project layout
- Read all config/manifest files (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Makefile`, `docker-compose.yml`, etc.)
- Identify the tech stack, frameworks, languages, and key dependencies
- Map the architecture: entry points, core modules, data flow, and key abstractions

Return: a one-paragraph architecture summary, the key dependencies + versions, and the 5-10 most important files (entry points, central modules) for downstream agents to assume as context.

---

### Agent 2: Documentation, Intent & History

Recover the *why* behind the project plus the quantitative trajectory of the work:

- Read `README`, `CLAUDE.md`, `CONTRIBUTING.md`, `docs/`, and any project documentation
- Look for ADRs (Architecture Decision Records), changelogs, or design docs

If the project is a git repository, run these specific git commands to get quantitative data:

```bash
# Top 20 most-changed files in the last 12 months (hotspots = highest-ROI improvement targets)
git log --format=format: --name-only --since=12.months 2>/dev/null | sort | uniq -c | sort -rn | head -20

# Contributor distribution (single-author areas = bus factor risk)
git shortlog -sn --no-merges --since=12.months 2>/dev/null

# Recently deleted files (abandoned directions, failed approaches)
git log --format=format: --name-only --diff-filter=D --since=12.months 2>/dev/null | head -20

# Recent velocity (3-month commit count)
git log --oneline --since=3.months 2>/dev/null | wc -l
```

If the project has no git history, skip the commands and note the absence of version control as a finding.

Return: stated project purpose and target audience, the top 10 hotspot files, contributor distribution shape (single-maintainer vs. distributed), recent deletions, and velocity bucket (dormant / steady / active).

---

### Agent 3: Quality & Gaps

Find what's missing, broken, or rotting:

- Examine test coverage: what's tested, what's not, testing patterns used
- Check CI/CD setup (GitHub Actions, GitLab CI, CircleCI, etc.)
- Search for `TODO`, `FIXME`, `HACK`, `XXX`, `WORKAROUND` markers across the codebase
- Look for dead code, unused dependencies, or stale configuration

Return: a coverage summary (which areas have tests, which don't), the CI surface (what runs, what doesn't), the count and rough distribution of in-code TODO/FIXME markers, and any obvious quality cliffs (e.g., a module with zero tests despite high churn).

---

Compile the three returns into a mental model of the project before proceeding.

---

## Phase 2: Project Type Classification

Based on Phase 1 findings, classify the project as one of:
- **Library/Package** — consumed by other developers as a dependency
- **CLI Tool** — command-line application run by end users
- **Web App** — frontend, backend, or fullstack web application
- **API Service** — backend service exposing endpoints
- **Infrastructure/DevOps** — IaC, CI/CD tooling, platform config
- **Other** — describe it

State the classification clearly before proceeding. This classification shapes the analysis in Phase 4.

---

## Phase 3: Domain & Context Understanding

Based on Phase 1, synthesize a deeper understanding:

- What is this project's **purpose**? Who are its target users?
- What **problem domain** does it operate in?
- What **maturity stage** is it at? (experiment, prototype, MVP, growth-stage product, mature/stable)
- What are its **strengths** — what does it do particularly well?
- What are its **competitive advantages** or unique differentiators?
- If relevant, use web research to understand how it compares to alternatives in its space

Summarize this understanding briefly before moving on.

---

## Phase 4: Gap & Opportunity Analysis

Now think critically about what's missing or underexploited:

- What capabilities does the **tech stack naturally enable** that aren't being used?
- What patterns are **half-implemented or inconsistent** across the codebase?
- Where are the highest-friction **developer experience** pain points?
- What would **users/consumers** of this project benefit from most?
- What **modern techniques, patterns, or tools** could be adopted to level up the project?
- What's the **weakest link** in the project's value chain?
- What's the **biggest risk** the project currently faces (technical debt, scalability, security, DX)?

**Additionally, ask these type-specific questions based on the Phase 2 classification:**

- **Library/Package** — API ergonomics? Documentation and examples quality? Bundle size / tree-shaking? Backwards compatibility strategy? Publishing pipeline?
- **CLI Tool** — UX and help text quality? Shell completions? Config file support? Error messages and exit codes? Interactive vs non-interactive mode?
- **Web App** — Performance / Core Web Vitals? Accessibility (a11y)? State management complexity? SEO? Mobile responsiveness?
- **API Service** — Rate limiting? Caching strategy? OpenAPI/Swagger spec? Observability and tracing? Versioning strategy?
- **Infrastructure/DevOps** — Drift detection? Rollback strategy? Secret management? Environment parity? Disaster recovery?

Generate a broad list of potential improvements and opportunities. Don't filter yet — breadth matters here.

---

## Phase 5: Innovation Synthesis

Now converge. This is the creative, strategic phase — **ultrathink** about which idea matters most:

- **Cross-pollinate**: What ideas from adjacent domains or different ecosystems could apply here?
- **Emerging patterns**: What new techniques or technologies are relevant to this stack that the project hasn't adopted?
- **Second-order effects**: Which improvements would create compounding value — unlocking further improvements or capabilities?
- **Delight factor**: What would genuinely surprise and delight the project's users or developers?

Score each candidate idea on four axes:
1. **Innovation** — How novel and creative is this?
2. **Feasibility** — Can it be implemented cleanly with reasonable effort?
3. **Impact** — How much value does it deliver to users and/or developers?
4. **Delight** — Does it create a "wow, I didn't know I needed this" moment?

**Converge on THE single most compelling addition.** This is not a list — pick one.

---

## Phase 6: The Recommendation

Present your recommendation in this format:

### The Enhancement
A clear, compelling name and one-line description.

### Why This?
- What makes this the #1 choice over everything else you considered
- What gap it fills and why that gap matters now
- What second-order benefits it unlocks

### What You Considered (and Why Not)
Briefly mention 2-3 runner-up ideas and why this one wins.

### Implementation Sketch
- Key files to create or modify
- Architectural approach and core logic
- Pseudocode or code sketches for the critical parts
- Integration points with existing code

### Expected Impact
- Immediate benefits
- Second-order / compounding effects
- Who benefits and how

### Scope & Path
- Estimated scope: **Small** (< 1 hour), **Medium** (1-4 hours), or **Large** (4+ hours)
- Suggested implementation sequence
- Any prerequisites or dependencies

---

After presenting the full recommendation, call `ExitPlanMode`, then ask: **"Want me to implement this now?"**

This way the user can immediately proceed with implementation in the same session.
