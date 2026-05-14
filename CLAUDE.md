# Claude_Skills

A curated collection of custom skills for Claude Code, distributed via symlinks from `~/.claude/skills/`.

## Architecture

- Each skill lives in `skills/<name>/` with at minimum a `SKILL.md` (consumed by Claude Code) and a `README.md` (human documentation)
- `install.sh` creates symlinks from `~/.claude/skills/<name>` → `skills/<name>/` in this repo
- `git pull` updates all installed skills instantly because they are symlinked
- `lint.sh` validates all skills against the conventions below

## Skill Format Specification

### SKILL.md Frontmatter

Every `SKILL.md` must begin with YAML frontmatter between `---` delimiters.

**Required fields:**

| Field | Description |
|-------|-------------|
| `name` | Skill identifier, must match the directory name (e.g., `enhance` for `skills/enhance/`) |
| `description` | One-line summary of what the skill does |
| `allowed-tools` | Comma-separated list of tools the skill may use |

**Optional fields:**

| Field | Default | Description |
|-------|---------|-------------|
| `model` | (inherits) | Model to use: `opus`, `sonnet`, or `haiku` |
| `effort` | (inherits) | Effort level: `min`, `low`, `medium`, `high`, `max` |
| `disable-model-invocation` | `false` | Controls whether other models/skills may auto-invoke this skill via discovery/matching. Set `true` to keep the skill strictly user-triggered (the user must type `/<skill-name>` themselves). Does NOT prevent the skill from launching subagents via the `Agent` tool. Rarely needed — only `enhance` uses this in the current collection. |
| `takes-arg` | `false` | Set `true` if the skill accepts an argument from the user |

### SKILL.md Body

The body contains the prompt that Claude follows when the skill is invoked. Conventions:

- Use clear step numbering for multi-phase workflows
- Use `---` separators between major phases
- If the skill uses subagents, explicitly state the required `subagent_type` and `model`
- If the skill enters plan mode, the first instruction should be to call `EnterPlanMode` and the last should call `ExitPlanMode`

## README Convention

Every skill's `README.md` must contain these sections (in order):

1. **Title** — `# <Skill Name>` followed by a one-line description
2. **What It Does** — Describe the workflow and phases
3. **Requirements** — Model access, dependencies, prerequisites
4. **Usage** — How to invoke (e.g., `/<skill-name>` or `/<skill-name> <argument>`)
5. **Configuration** — Table of frontmatter settings
6. **Safety** (if applicable) — What the skill can and cannot modify

See `skills/enhance/README.md` as the reference implementation.

## Adding a New Skill

1. Copy `templates/SKILL.md` and `templates/README.md` to `skills/<name>/`
2. Fill in the SKILL.md frontmatter and prompt
3. Fill in the README.md sections
4. Ensure the `name` field in frontmatter matches the directory name
5. Run `./lint.sh <name>` to validate
6. Update the skills table in the root `README.md`
7. Run `./install.sh <name>` to create the symlink
8. Commit and push

## Quality Standards

- **Minimal permissions**: Only request the tools the skill actually needs in `allowed-tools`
- **Clear description**: The `description` field should be understandable without reading the full prompt; verb-first phrasing preferred ("Scans...", "Audits...", "Performs...")
- **Simplicity bias**: Default to a single linear workflow. Only fan out to subagents when there are three genuinely orthogonal analysis lenses (see `skills/create-skill/SKILL.md` R4 — Subagent Decision Gate). `github-ship` is the canonical example of a subagent-free skill.
- **Safety-conscious**: Skills that launch subagents should use read-only agent types (e.g., Explore) during analysis phases
- **Plan-mode discipline**: If a skill enters plan mode, `ExitPlanMode` must be called BEFORE any Edit/Write operation — file modifications are blocked while plan mode is active
- **Self-contained**: Each skill directory should contain everything needed; avoid cross-skill dependencies

## Validation

Run `./lint.sh` to check all skills, or `./lint.sh <name>` for a specific skill. The linter checks:

- Required frontmatter fields exist
- Skill name matches directory name
- README.md exists with required sections
