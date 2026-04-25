# Claude Code Custom Skills

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Lint Skills](https://github.com/thijsvos/Claude_Skills/actions/workflows/lint.yml/badge.svg)](https://github.com/thijsvos/Claude_Skills/actions/workflows/lint.yml)

A curated collection of custom skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that extend its capabilities with specialized, reusable workflows.

[Claude Code skills](https://docs.anthropic.com/en/docs/claude-code) are prompt-based extensions that add new slash commands to your Claude Code CLI. Install a skill, then invoke it with `/<skill-name>` — no plugins or config needed.

## Available Skills

| Skill | Description | Model | Effort |
|-------|-------------|-------|--------|
| [enhance](skills/enhance/) | Deep multi-phase project analysis that identifies and recommends the single most impactful addition to implement | Opus | Max |
| [github-audit](skills/github-audit/) | Audits a GitHub repository against best practices and provides prioritized recommendations | Opus | Max |
| [code-review](skills/code-review/) | Structured code review with prioritized findings and fix offers | Opus | Max |
| [test-gen](skills/test-gen/) | Comprehensive test generation with deep code analysis, convention detection, and edge case coverage | Opus | Max |
| [dep-check](skills/dep-check/) | Scans dependencies across ecosystems for updates and vulnerabilities, produces a prioritized update plan | Opus | Max |
| [diagnose](skills/diagnose/) | Multi-agent root cause analysis with error tracing, change correlation, and ranked fix hypotheses | Opus | Max |
| [refactor](skills/refactor/) | Comprehensive refactoring across correctness, security, performance, and maintainability with behavior-preserving changes | Opus | Max |
| [create-skill](skills/create-skill/) | Interactive skill generator that scaffolds new skills following all project conventions | Opus | Max |
| [docstring-check](skills/docstring-check/) | Scans a codebase for missing, outdated, drifted, or inconsistent docstrings and applies convention-matching fixes | Opus | Max |
| [github-ship](skills/github-ship/) | Turns local changes into a GitHub issue and linked PR, or cleans up the branch if the PR was already merged. Auto-detects which | Opus | Max |
| [idiom-check](skills/idiom-check/) | Audits a codebase through a programming-language-specific idiom lens, produces a prioritized report, and offers remediation in PR-sized bundles | Opus | Max |

## Quick Start

### Install All Skills

```bash
git clone https://github.com/thijsvos/Claude_Skills.git
cd Claude_Skills
./install.sh
```

### Install a Single Skill

```bash
./install.sh enhance
```

### Use a Skill

Once installed, invoke any skill inside Claude Code:

```
> /enhance
> /github-audit
> /code-review src/auth/
> /test-gen src/utils.ts
> /dep-check
> /diagnose TypeError: Cannot read properties of undefined
> /refactor src/auth/handler.ts
> /create-skill "API documentation generator"
> /docstring-check src/
> /github-ship
> /idiom-check
```

## How It Works

Skills are installed as **symlinks** from `~/.claude/skills/<name>` to this repository. The repo is the source of truth — pull to update, and your skills update automatically.

```
~/.claude/skills/enhance  ->  /path/to/Claude_Skills/skills/enhance
```

### Updating Skills

```bash
cd /path/to/Claude_Skills
git pull
```

That's it. Since skills are symlinked, pulling updates the actual skill files.

## Adding a New Skill

Each skill lives in its own directory under `skills/` with at minimum a `SKILL.md` file:

```
skills/
└── my-skill/
    ├── SKILL.md      # Skill definition (consumed by Claude Code)
    └── README.md     # Human-readable documentation
```

The `SKILL.md` file uses frontmatter to configure the skill:

```yaml
---
name: my-skill
description: What the skill does
allowed-tools: Read, Grep, Glob
model: opus          # optional: opus, sonnet, haiku
effort: max          # optional: min, low, medium, high, max
---

Skill prompt content here...
```

After adding a skill, update the table in this README and run `./install.sh my-skill`.

Starter templates are available in the `templates/` directory. See [CLAUDE.md](CLAUDE.md) for the full skill format specification and conventions.

## Development

### Validating Skills

Run the linter to check all skills follow the project conventions:

```bash
./lint.sh            # Check all skills
./lint.sh enhance    # Check a specific skill
```

The linter validates:
- Required frontmatter fields (`name`, `description`, `allowed-tools`)
- Skill name matches directory name
- README.md exists with required sections (What It Does, Requirements, Usage, Configuration)

### Templates

The `templates/` directory contains starter files for new skills:
- `templates/SKILL.md` — Skill definition with all frontmatter fields documented
- `templates/README.md` — Documentation template with all required sections

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on creating and submitting skills.

- **Propose a skill**: [open a Skill Request](https://github.com/thijsvos/Claude_Skills/issues/new?template=skill_request.yml)
- **Report a bug**: [open a Bug Report](https://github.com/thijsvos/Claude_Skills/issues/new?template=bug_report.yml)
- **Security issues**: see [SECURITY.md](SECURITY.md)

## License

[MIT](LICENSE)
