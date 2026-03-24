# Enhance

Deep multi-phase project analysis that identifies and recommends the single most impactful addition to implement.

## What It Does

Runs a strategic 5-phase analysis of your project, then converges on one compelling, concrete recommendation:

1. **Deep Project Reconnaissance** -- scans structure, stack, git history, test coverage, and quality gaps
2. **Project Type Classification** -- categorizes the project (library, CLI, web app, API service, etc.)
3. **Domain & Context Understanding** -- identifies purpose, target users, maturity stage, and strengths
4. **Gap & Opportunity Analysis** -- type-specific analysis of what's missing or underexploited
5. **Innovation Synthesis** -- scores candidates on innovation, feasibility, impact, and delight; picks one winner

The skill asks clarifying questions throughout the analysis to tailor its recommendation to your actual priorities and constraints.

## Requirements

- Claude Code with **Opus model** access (the skill specifies `model: opus`)
- The project should ideally be a **git repository** (for history analysis), but this is not required

## Usage

```
/enhance
```

The skill automatically:
1. Enters plan mode
2. Launches read-only Explore subagents for parallel analysis
3. Asks you questions during analysis for context
4. Presents a final recommendation with implementation sketch
5. Exits plan mode and offers to implement

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Disable model invocation | `true` |
| Allowed tools | Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, LSP, EnterPlanMode, ExitPlanMode, AskUserQuestion |

## Safety

All subagents are launched as **Explore** type (read-only) with Opus model override. The Edit and Write tools are denied at the agent level, so the analysis phase **cannot modify your project**. Changes only happen after you approve the recommendation and implementation begins.
