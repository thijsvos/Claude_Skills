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
| `description` | One-line summary of what the skill does. Must end with a period and should be verb-first ("Scans...", "Audits...", "Performs..."). The same text must appear verbatim as the README first-line description and as the row in the root README skills table — `lint.sh` enforces all three matches. |
| `allowed-tools` | Comma-separated list of tools the skill may use. The same list (in the same order) must appear in the README's `Configuration` table `Allowed tools` row — `lint.sh` enforces this parity. |

**Optional fields** (this table tracks the official [Claude Code skill spec](https://code.claude.com/docs/en/skills#frontmatter-reference); fields not used by any skill in this repo are still listed for discoverability):

| Field | Default | Description |
|-------|---------|-------------|
| `model` | (inherits) | Model to use: `opus`, `sonnet`, `haiku`, or `inherit` to keep the session model. Override applies for the rest of the current turn only. |
| `effort` | (inherits) | Effort level: `low`, `medium`, `high`, `xhigh`, `max`. Available levels depend on the model. |
| `argument-hint` | (none) | Hint shown during autocomplete (e.g., `[path \| identifier]`). The README's Configuration table `Argument hint` row must match this — `lint.sh` enforces parity. **Replaces the legacy repo-internal `takes-arg` field**, which was never recognized by Claude Code; `lint.sh` now warns on `takes-arg`. |
| `arguments` | (none) | Named positional arguments for `$name` substitution in the body (e.g., `arguments: [target, mode]` enables `$target` and `$mode`). |
| `when_to_use` | (none) | Additional trigger-phrase guidance for auto-invocation. Appended to `description` in the skill listing (counts toward the 1,536-character cap). |
| `paths` | (none) | Glob patterns that auto-activate the skill when working with matching files (e.g., `["**/*.test.*"]`). |
| `disable-model-invocation` | `false` | Set `true` to keep the skill strictly user-triggered (does NOT block subagents launched via the `Agent` tool). Rarely needed — only `enhance` uses this. |
| `user-invocable` | `true` | Set `false` to hide the skill from the `/` menu (for background-knowledge skills only Claude should invoke). Differs from `disable-model-invocation` (which is the inverse). |
| `context` | (none) | Set to `fork` to run the skill in a forked subagent context (skill body becomes the subagent's prompt). |
| `agent` | `general-purpose` | When `context: fork` is set, picks the subagent type (`Explore`, `Plan`, `general-purpose`, or any custom agent in `.claude/agents/`). |
| `hooks` | (none) | Skill-scoped hooks. See the [Claude Code hooks docs](https://code.claude.com/docs/en/hooks#hooks-in-skills-and-agents). |
| `shell` | `bash` | Shell for `` !`command` `` blocks. `bash` (default) or `powershell` (requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`). |

**Body substitutions and dynamic context injection** (Claude Code features the body can use):

| Construct | Description |
|-----------|-------------|
| `$ARGUMENTS` | All user-supplied arguments as a single string. If absent from the body, Claude Code auto-appends `ARGUMENTS: <value>` to the rendered skill content. |
| `$0`, `$1`, ... | Positional arguments by 0-based index (shell-style quoting). |
| `$<name>` | Named argument declared in the `arguments:` frontmatter list. |
| `${CLAUDE_SESSION_ID}` | Current session ID. |
| `${CLAUDE_EFFORT}` | Active effort level (`low`/`medium`/`high`/`xhigh`/`max`). Lets the skill adapt its depth to the session's effort setting. |
| `${CLAUDE_SKILL_DIR}` | Directory containing the skill's `SKILL.md`. Use to reference bundled scripts regardless of cwd. |
| `` !`<command>` `` | **Dynamic context injection** — runs the shell command BEFORE Claude reads the skill, and the output replaces the placeholder. Use for deterministic, side-effect-free context-gathering. Multi-line variant: ` ```! ` fenced block. |

**Migration note:** The legacy `takes-arg` field is repo-internal only — Claude Code's official spec uses `argument-hint` (autocomplete display) and/or `arguments` (named substitution). Skills should declare `argument-hint` instead; `lint.sh` warns if `takes-arg` is still present.

### SKILL.md Body

The body contains the prompt that Claude follows when the skill is invoked. Conventions:

- Use clear step numbering for multi-phase workflows
- Use `---` separators between major phases
- The first instruction should be the canonical line `` Call `EnterPlanMode` immediately before doing anything else. `` whenever `EnterPlanMode` is declared in `allowed-tools` (`lint.sh` enforces matched-pair body references for both `EnterPlanMode` and `ExitPlanMode`)
- If the skill uses subagents (`Agent` in `allowed-tools` + `subagent_type: "Explore"` in the body), include the canonical IMPORTANT block verbatim from `create-skill` R4 explaining Explore read-only safety and the Opus model override. `lint.sh` warns when this block is missing.
- Agent subheadings use `### Agent N: <Title>` (not `**Agent N:**`)

## README Convention

Every skill's `README.md` must contain these sections (in order):

1. **Title** — `# <Skill Name>` followed by a one-line description on line 3 that matches the SKILL.md `description` field verbatim (`lint.sh` enforces this)
2. **What It Does** — Describe the workflow and phases. Use "delivered in N steps:" for step-numbered skills or "Runs a strategic N-phase analysis…" for phase-numbered skills.
3. **Requirements** — Model access, dependencies, prerequisites
4. **Usage** — How to invoke. Examples must use the skill's actual name (`/<skill-name>` — `lint.sh` enforces this).
5. **Configuration** — Table of frontmatter settings with required rows: `Model`, `Effort`, `Argument hint`, `Allowed tools`. The `Allowed tools` row must list the same tools as the SKILL.md `allowed-tools` frontmatter (`lint.sh` enforces this parity). The `Argument hint` row should mirror the SKILL.md `argument-hint` frontmatter value, or say `No` for skills that take no argument.
6. **Safety** (if applicable) — What the skill can and cannot modify

See `skills/enhance/README.md` as the reference implementation.

## Adding a New Skill

1. Copy `templates/SKILL.md` and `templates/README.md` to `skills/<name>/`
2. Fill in the SKILL.md frontmatter and prompt
3. Fill in the README.md sections
4. Ensure the `name` field in frontmatter matches the directory name
5. Update the skills table in the root `README.md` (the table cell must match the SKILL.md `description` verbatim)
6. Update `CHANGELOG.md` with the new skill under `## [Unreleased]` — `release.yml` extracts release notes from this section, so missing the update silently breaks the next release
7. Run `./lint.sh <name>` to validate (and `./lint.sh` to confirm no regressions on the other skills)
8. Run `./install.sh <name>` to create the symlink
9. Commit and push

## Quality Standards

- **Minimal permissions**: Only request the tools the skill actually needs in `allowed-tools`
- **Clear description**: The `description` field should be understandable without reading the full prompt; verb-first phrasing preferred ("Scans...", "Audits...", "Performs...")
- **Simplicity bias**: Default to a single linear workflow. Only fan out to subagents when there are three genuinely orthogonal analysis lenses (see `skills/create-skill/SKILL.md` R4 — Subagent Decision Gate). `github-ship` is the canonical example of a subagent-free skill.
- **Safety-conscious**: Skills that launch subagents should use read-only agent types (e.g., Explore) during analysis phases
- **Plan-mode discipline**: If a skill enters plan mode, `ExitPlanMode` must be called BEFORE any Edit/Write operation — file modifications are blocked while plan mode is active
- **Self-contained**: Each skill directory should contain everything needed; avoid cross-skill dependencies
- **Cross-skill handoffs**: When a skill's primary action naturally chains into another installed skill (e.g., `/code-review` → `/refactor`, `/diagnose` → `/test-gen`, `/refactor` → `/test-gen`), declare `Skill` in `allowed-tools` and add a "Skill handoff" offer after the primary action completes. Offer the handoff only when there's genuine signal that the next skill adds value — never as a generic catch-all. The user must approve before the handoff fires.
- **Dynamic context injection where deterministic**: When a skill's first step gathers context that does not depend on the user's argument (e.g., `git rev-parse --abbrev-ref HEAD`, `gh repo view --json ...`, `ls package.json Cargo.toml ...`), pre-render that context in the skill body using `` !`<command>` `` (or fenced ` ```! ` for multi-line). The harness runs the command BEFORE Claude reads the skill content, replacing the placeholder with the output — so Claude sees the pre-rendered values immediately and skips the redundant Bash round-trip. Use only for **fast, side-effect-free, idempotent** commands (no `git push`, no `gh pr create`, no `npm install`). For commands that depend on the user's argument or runtime decisions, keep them in the body so Claude can run them conditionally.

## Validation

Run `./lint.sh` to check all skills, or `./lint.sh <name>` for a specific skill. The linter checks:

- Required frontmatter fields exist (`name`, `description`, `allowed-tools`)
- Skill name matches directory name
- Description ends with a period
- `EnterPlanMode` and `ExitPlanMode` are paired in `allowed-tools` AND referenced in the body when present
- Canonical IMPORTANT subagent block is present when `Agent` is paired with Explore subagents
- README.md exists with required sections
- README line 3 description matches SKILL.md `description` verbatim
- Usage examples invoke the correct `/<skill-name>` (not stale names or unrelated commands)
- Configuration table has `Argument hint` and `Allowed tools` rows
- `Allowed tools` row matches SKILL.md `allowed-tools` frontmatter (whitespace-normalized)
- Warns if a SKILL.md still declares the legacy `takes-arg` field (use `argument-hint` instead)
