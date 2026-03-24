# Contributing

Thanks for your interest in contributing to Claude Code Custom Skills! This guide will help you get started.

## Proposing a New Skill

Before writing code, [open a Skill Request issue](https://github.com/thijsvos/Claude_Skills/issues/new?template=skill_request.yml) to discuss the idea. This helps avoid duplicate work and ensures the skill fits the collection.

## Creating a Skill

1. **Copy the templates** to a new directory under `skills/`:
   ```bash
   cp -r templates/ skills/my-skill/
   ```

2. **Edit `SKILL.md`** — fill in the frontmatter and write the skill prompt:
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

3. **Edit `README.md`** — document the skill with these required sections:
   - **Title** and one-line description
   - **What It Does** — describe the workflow
   - **Requirements** — model access, dependencies
   - **Usage** — how to invoke (e.g., `/my-skill`)
   - **Configuration** — table of frontmatter settings
   - **Safety** (if applicable) — what the skill can and cannot modify

4. **Validate** your skill:
   ```bash
   ./lint.sh my-skill
   ```

5. **Update the skills table** in the root `README.md`.

6. **Update `CHANGELOG.md`** with your addition under `## [Unreleased]`.

See [CLAUDE.md](CLAUDE.md) for the full specification and quality standards.

## Submitting a Pull Request

1. Fork the repository and create a feature branch
2. Make your changes following the steps above
3. Ensure `./lint.sh` passes with no errors
4. Open a PR — the [PR template](.github/PULL_REQUEST_TEMPLATE.md) includes a checklist

## Quality Standards

- **Minimal permissions**: only request tools the skill actually needs in `allowed-tools`
- **Clear description**: the `description` field should be understandable without reading the full prompt
- **Safety-conscious**: skills that launch subagents should use read-only agent types during analysis phases
- **Self-contained**: each skill directory should contain everything needed; avoid cross-skill dependencies

## Reporting Bugs

Found a broken skill? [Open a Bug Report](https://github.com/thijsvos/Claude_Skills/issues/new?template=bug_report.yml).

## Questions?

Open a [discussion](https://github.com/thijsvos/Claude_Skills/issues) or file an issue — we're happy to help.
