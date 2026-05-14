# Enhance

Performs deep multi-phase project analysis to identify and recommend the single most impactful addition to implement.

## What It Does

Runs a strategic 6-phase analysis of your project, then converges on one compelling, concrete recommendation:

1. **Deep Project Reconnaissance** -- scans structure, stack, git history, test coverage, and quality gaps
2. **Project Type Classification** -- categorizes the project (library, CLI, web app, API service, etc.)
3. **Domain & Context Understanding** -- identifies purpose, target users, maturity stage, and strengths
4. **Gap & Opportunity Analysis** -- type-specific analysis of what's missing or underexploited
5. **Innovation Synthesis** -- scores candidates on innovation, feasibility, impact, and delight; picks one winner
6. **The Recommendation** -- presents the chosen addition with an implementation sketch, then exits plan mode and offers to implement

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

## Example

Running `/enhance` against a CLI tool repo that has no observability story:

```
/enhance
```

<details>
<summary>Sample recommendation</summary>

```
### The Enhancement
Structured JSON logging behind a `--log-format` flag.

### Why This?
- The tool already emits 14 distinct log lines; teams running it in CI have no way
  to grep them apart from incidental command output.
- One small flag unlocks downstream ingestion into Loki/Datadog with zero new deps.
- Compounds: once logs are structured, every future command inherits observability.

### What You Considered (and Why Not)
- A full OpenTelemetry tracing layer — overkill for a synchronous CLI.
- A separate `--verbose` mode — addresses the wrong axis (volume, not structure).
- A `--metrics` Prometheus exporter — wrong target audience for this tool.

### Implementation Sketch
Add a `LogFormat` enum to `src/cli/flags.rs`, plumb it into the existing
`println!`-based emit helpers via a `Logger` struct. Default = `text` (no behavior change);
`json` emits one line per event with `ts`, `level`, `event`, `fields` keys.

### Expected Impact
Immediate: CI users can `grep '"level":"error"'`. Compounding: structured logs become
the substrate for a future `--metrics` exporter or a `replay` subcommand.

### Scope & Path
**Medium** (~3 hours). Wire flag → write Logger → migrate ~14 call sites → snapshot tests.
```

</details>

> **Want me to implement this now?**

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | No |
| Disable model invocation | `true` |
| Allowed tools | Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, EnterPlanMode, ExitPlanMode, AskUserQuestion |

## Safety

All subagents are launched as **Explore** type (read-only) with Opus model override. The Edit and Write tools are denied at the agent level, so the analysis phase **cannot modify your project**. Changes only happen after you approve the recommendation and implementation begins.
