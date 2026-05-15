# GitHub Audit

Audits a GitHub repository against best practices and provides prioritized recommendations for README, license, community health, CI/CD, and repository settings.

## What It Does

Runs a 3-phase audit of your repository's GitHub presence:

1. **Repository Scan** -- parallel exploration of all GitHub-relevant files (README, LICENSE, templates, workflows, etc.), README deep analysis, and GitHub settings/CI/CD checks via the `gh` CLI
2. **Best Practices Evaluation** -- scores 7 categories (README quality, license, community health, CI/CD, repo settings, git hygiene, documentation) as Good / Needs improvement / Missing
3. **Prioritized Recommendations** -- scorecard summary and 5-10 actionable recommendations ordered by impact, with specific steps and example content

## Requirements

- Claude Code with **Opus model** access
- `gh` CLI authenticated (for GitHub API checks -- the skill gracefully handles missing access)
- The project should be a git repository with a GitHub remote

## Usage

```
/github-audit
```

The skill enters plan mode automatically, performs the audit using read-only Explore subagents, asks about your project's intended audience to calibrate recommendations, then presents findings and offers to implement improvements.

## Example

Auditing a Rust library that just went public:

```
/github-audit
```

<details>
<summary>Sample report</summary>

```
### Repository Scorecard

| Category               | Status            | Priority |
|------------------------|-------------------|----------|
| README Quality         | Needs improvement | High     |
| License                | Good              | —        |
| Community Health       | Missing           | Medium   |
| CI/CD & Automation     | Good              | —        |
| Repository Settings    | Needs improvement | High     |
| Git Hygiene            | Good              | —        |
| Documentation          | Needs improvement | Medium   |

### Top Recommendations

#### 1. Add a `CODE_OF_CONDUCT.md` and issue templates
**Category**: Community Health
**Effort**: Quick fix (< 5 min)
**Impact**: Signals the project welcomes external contributors; required for some org policies.
**What to do**: Use the Contributor Covenant 2.1 template and the GitHub default issue forms.

#### 2. Enable Dependabot for `cargo` updates
**Category**: CI/CD & Automation
**Effort**: Quick fix (< 5 min)
**Impact**: Catches CVE-affected crates within a day of disclosure.
**Skill handoff**: Once enabled, run /dep-check to action the first batch.
```

</details>

> **Want me to implement any of these recommendations?**

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Argument hint | No |
| Allowed tools | Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, AskUserQuestion, Skill, EnterPlanMode, ExitPlanMode |

## Safety

All subagents are launched as **Explore** type (read-only). The audit phase cannot modify your repository. Changes only happen after you review the recommendations and choose which to implement.
