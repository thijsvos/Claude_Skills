# Claude_Skills

A curated collection of custom skills for Claude Code, distributed via symlinks from `~/.claude/skills/`.

## Architecture

- Each skill lives in `skills/<name>/` with at minimum a `SKILL.md` (consumed by Claude Code) and a `README.md` (human documentation)
- `install.sh` creates symlinks from `~/.claude/skills/<name>` → `skills/<name>/` in this repo
- `git pull` updates all installed skills instantly because they are symlinked
- `lint.sh` validates all skills against the conventions below
- `schemas/skill-frontmatter.schema.json` is the machine-readable frontmatter contract; `skills.json` is an auto-generated catalogue manifest (`tools/generate-manifest.sh`) and `docs/handoff-graph.md` an auto-generated handoff diagram (`tools/generate-handoff-graph.sh`) — `lint.sh` keeps `skills.json` in sync with `skills/`
- `.claude-plugin/plugin.json` makes the repo installable as a Claude Code **plugin** as well (see [Distribution](#distribution))

## Skill Format Specification

### SKILL.md Frontmatter

Every `SKILL.md` must begin with YAML frontmatter between `---` delimiters.

**Schema:** the frontmatter is validated against [`schemas/skill-frontmatter.schema.json`](schemas/skill-frontmatter.schema.json) (JSON Schema 2020-12) — the machine-readable source of truth for field names, types, and allowed values. The tables below are the human-readable view of that schema. `lint.sh` runs the validation via `check-jsonschema` (see [Validation](#validation)). The schema sets `additionalProperties: false`, so unknown keys (typos, stale fields) are rejected — adding a new official Claude Code frontmatter field means adding it to the schema too.

**Required fields:**

| Field | Description |
|-------|-------------|
| `name` | Skill identifier, must match the directory name (e.g., `enhance` for `skills/enhance/`) |
| `description` | One-line summary of what the skill does. Must end with a period and should be verb-first ("Scans...", "Audits...", "Performs..."). The same text must appear verbatim in three places — this field, the skill README's first-line description (line 3), and the skill's row in the root README skills table. `lint.sh` checks all three: the root-table match is a hard error, the README line-3 match a warning. |
| `allowed-tools` | Comma-separated list of tools the skill may use. The same list (in the same order) must appear in the README's `Configuration` table `Allowed tools` row — `lint.sh` enforces this parity. |

**Optional fields** (this table tracks the official [Claude Code skill spec](https://code.claude.com/docs/en/skills#frontmatter-reference); fields not used by any skill in this repo are still listed for discoverability):

| Field | Default | Description |
|-------|---------|-------------|
| `model` | (inherits) | Model to use: `opus`, `sonnet`, `haiku`, `fable`, or `inherit` to keep the session model. Override applies for the rest of the current turn only. Claude Code also accepts full model IDs, but the schema restricts this repo to the aliases — each alias is a live pointer to the **latest** model of its tier, so a skill needs no edits when a new Opus ships — only ever *de-version prose* (never hardcode a number like "Opus 4.7"). `lint.sh` warns on hardcoded model versions. |
| `effort` | (inherits) | Effort level: `low`, `medium`, `high`, `xhigh`, `max` (there is no `min`). Available levels depend on the model. Every skill in this repo declares `xhigh` — see [Quality Standards](#quality-standards). |
| `argument-hint` | (none) | Hint shown during autocomplete (e.g., `[path \| identifier]`). The README's Configuration table `Argument hint` row must match this — `lint.sh` enforces parity. **Replaces the legacy repo-internal `takes-arg` field**, which was never recognized by Claude Code; `lint.sh` now warns on `takes-arg`. |
| `arguments` | (none) | Named positional arguments for `$name` substitution in the body (e.g., `arguments: [target, mode]` enables `$target` and `$mode`). |
| `disallowed-tools` | (none) | Tools removed from Claude's pool while the skill is active (comma-separated string or list). The complement of `allowed-tools` — useful when a skill inherits a broad session toolset but must never, say, `Write`. |
| `when_to_use` | (none) | Additional trigger-phrase guidance for auto-invocation. Appended to `description` in the skill listing, which is budgeted per session (`skillListingBudgetFraction`, default ~1% of the context window; per-skill cap `skillListingMaxDescChars`). `lint.sh` warns when `description` + `when_to_use` exceed 1,536 characters combined. Run `/skill-doctor` (Claude Code 2.1.261+) to see which loaded skills are never used and what they cost in tokens. |
| `paths` | (none) | Glob patterns that auto-activate the skill when working with matching files (e.g., `["**/*.test.*"]`). |
| `disable-model-invocation` | `false` | Set `true` to keep the skill strictly user-triggered (does NOT block subagents launched via the `Agent` tool). Rarely needed — only `enhance` uses this. |
| `user-invocable` | `true` | Set `false` to hide the skill from the `/` menu (for background-knowledge skills only Claude should invoke). Differs from `disable-model-invocation` (which is the inverse). |
| `context` | (none) | Set to `fork` to run the skill in a forked subagent context (skill body becomes the subagent's prompt). |
| `agent` | `general-purpose` | When `context: fork` is set, picks the subagent type (`Explore`, `Plan`, `general-purpose`, or any custom agent in `.claude/agents/`). |
| `background` | `true` | With `context: fork`, whether the forked subagent runs in the background. Set `false` to wait for its result inline. Requires Claude Code 2.1.218+; the schema requires `context` when `background` is set. |
| `hooks` | (none) | Skill-scoped hooks, in the same shape as `settings.json` hooks expressed as YAML (`<Event>: [{ matcher, hooks: [{ type: command, command, once?, if?, timeout? }] }]`). Registered when the skill is invoked and **kept for the rest of the session** unless a handler sets `once: true`. `${CLAUDE_SKILL_DIR}` is *not* expanded in hook commands (only `${CLAUDE_PROJECT_DIR}` is), so keep skill hooks inline-shell — a `./scripts/...` path would resolve against the user's cwd, not the symlinked skill directory. `github-ship` and `idiom-check` use a `PreToolUse` guard on `Bash` that blocks `--no-verify` and force-pushes. See the [Claude Code hooks docs](https://code.claude.com/docs/en/hooks#hooks-in-skills-and-agents). |
| `shell` | `bash` | Shell for `` !`command` `` blocks. `bash` (default) or `powershell` (requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`). |
| `metadata` | (none) | Free-form YAML map for custom data; Claude Code ignores it. |
| `license` | (none) | License identifier for the skill (Agent Skills spec; informational). |
| `compatibility` | (none) | Environment requirements, max 500 characters (Agent Skills spec; informational). |

Boolean fields accept `true`/`false`/`yes`/`no`/`on`/`off`/`1`/`0` in any case; the schema and this repo use `true`/`false` only.

**Body substitutions and dynamic context injection** (Claude Code features the body can use):

| Construct | Description |
|-----------|-------------|
| `$ARGUMENTS` | All user-supplied arguments as a single string. If absent from the body, Claude Code auto-appends `ARGUMENTS: <value>` to the rendered skill content. |
| `$0`, `$1`, ... / `$ARGUMENTS[N]` | Positional arguments by 0-based index (shell-style quoting); `$ARGUMENTS[N]` is the long form of `$N`. |
| `$<name>` | Named argument declared in the `arguments:` frontmatter list. |
| `\$` | Escapes a literal dollar sign before a digit or name (e.g. `\$1.00`, `\$HOME`) so it is not substituted. |
| `${CLAUDE_SESSION_ID}` | Current session ID. |
| `${CLAUDE_EFFORT}` | Active effort level (`low`/`medium`/`high`/`xhigh`/`max`). Lets the skill adapt its depth to the session's effort setting. |
| `${CLAUDE_SKILL_DIR}` | Directory containing the skill's `SKILL.md`. Use to reference bundled scripts regardless of cwd (body only — not expanded inside `hooks` commands). |
| `${CLAUDE_PROJECT_DIR}` | Project root where the session started. The only path placeholder also expanded inside hook commands. |
| `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` | Plugin installation directory and persistent data directory — only when the skill is loaded as part of a plugin (see [Distribution](#distribution)). |
| `` !`<command>` `` | **Dynamic context injection** — runs the shell command BEFORE Claude reads the skill, and the output replaces the placeholder. Use for deterministic, side-effect-free context-gathering. Multi-line variant: ` ```! ` fenced block. |

**Migration note:** The legacy `takes-arg` field is repo-internal only — Claude Code's official spec uses `argument-hint` (autocomplete display) and/or `arguments` (named substitution). Skills should declare `argument-hint` instead; `lint.sh` warns if `takes-arg` is still present.

### SKILL.md Body

The body contains the prompt that Claude follows when the skill is invoked. Conventions:

- Use clear step numbering for multi-phase workflows
- Use `---` separators between major phases
- The first instruction should be the canonical line `` Call `EnterPlanMode` immediately before doing anything else. `` whenever `EnterPlanMode` is declared in `allowed-tools` (`lint.sh` enforces matched-pair body references for both `EnterPlanMode` and `ExitPlanMode`)
- If the skill uses subagents, the analysis step runs them as a **`Workflow` of exactly 3 read-only Explore agents** (an embedded script beginning with `export const meta = {...}` whose `agent()` calls pass `agentType: 'Explore'` and omit `model`), with the `Agent` tool as the fallback when the Workflow tool is unavailable (`subagent_type: "Explore"`, `model: "opus"`). Declare both `Agent` and `Workflow` in `allowed-tools`, and include the canonical IMPORTANT block verbatim from `create-skill` R4 explaining Explore read-only safety on both paths. `lint.sh` warns when this block is missing, fails a body that embeds a script without declaring `Workflow`, and warns when the script's agents are not `Explore`.
- The script never duplicates the agent checklists — each `### Agent N: <Title>` section stays the single source of truth for its brief, and the script's `LENSES` array references those briefs
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
6. Regenerate the manifest: `bash tools/generate-manifest.sh > skills.json`. If the skill offers or receives a handoff, also regenerate the graph (`bash tools/generate-handoff-graph.sh`) and update the README graph block and `docs/handoff-graph.md`. `lint.sh` fails if `skills.json` is stale
7. Update `CHANGELOG.md` with the new skill under `## [Unreleased]` — `release.yml` extracts release notes from this section, so missing the update silently breaks the next release
8. Run `./lint.sh <name>` to validate (and `./lint.sh` to confirm no regressions on the other skills)
9. Run `./install.sh <name>` to create the symlink
10. Commit and push

## Quality Standards

- **Minimal permissions**: Only request the tools the skill actually needs in `allowed-tools`
- **Clear description**: The `description` field should be understandable without reading the full prompt; verb-first phrasing preferred ("Scans...", "Audits...", "Performs...")
- **Simplicity bias**: Default to a single linear workflow. Only fan out to subagents when there are three genuinely orthogonal analysis lenses (see `skills/create-skill/SKILL.md` R4 — Subagent Decision Gate). `github-ship` is the canonical example of a subagent-free skill.
- **Three-agent Workflow by default**: When a skill does fan out, its default path is a single-round **`Workflow` of exactly 3 read-only Explore agents in parallel** — one per lens — with the `Agent` tool kept only as the fallback when the Workflow tool is unavailable or disabled (`disableWorkflows`). The Workflow tool requires an explicit opt-in, and a skill body instructing the call is one of its documented opt-ins, so no `ultra` argument is needed for this tier. Keep it to three agents and one round; `parallel()` is the right primitive because the synthesis step needs all three reports together. Pass `schema` (a JSON Schema mirroring the skill's "structured format" list) whenever the finding shape is regular — `vet`, `refactor`, `docstring-check`, and `idiom-check` do, so each agent's return is a validated `{ findings, looks_good }` object rather than free text; omit it for heterogeneous digests (`enhance`, `github-audit`, `dep-check`, `test-gen`, `diagnose`), where agents return text in the skill's structured format.
- **Opt-in `ultra` tier**: Anything heavier than that single round — loop-until-dry discovery, adversarial verify panels, worktree-isolated parallel edits, budget-scaled fan-out — belongs behind an **explicit opt-in** (an `ultra` argument, or the user running at `effort: max`), never the default invocation, because it spawns many subagents and consumes far more tokens. `vet` is the reference: `/vet` runs the 3-agent Workflow, `/vet ultra` extends it with a find → adversarial-verify → synthesize pipeline. `github-ship` is the reference for skills that should **never** orchestrate. Declaring `Workflow` in `allowed-tools` is a capability declaration, not a harness-gated trigger — the skill body's instruction (default tier) or the user's argument (ultra tier) is what opts in.
- **Safety-conscious**: Skills that launch subagents use read-only agent types during analysis phases on both paths — `agentType: 'Explore'` inside a Workflow script (omit `model`; Explore inherits the session model, capped at Opus), `subagent_type: "Explore"` with `model: "opus"` on the Agent-tool fallback. Never `general-purpose` during analysis.
- **Effort default is `xhigh`**: Every skill declares `effort: xhigh` — deep reasoning without `max`'s latency and token cost. `max` is reserved for the user's own session setting or an `ultra` tier; skills should read `${CLAUDE_EFFORT}` to scale depth down at `medium`/`low` rather than up.
- **Plan-mode discipline**: If a skill enters plan mode, `ExitPlanMode` must be called BEFORE any Edit/Write operation — file modifications are blocked while plan mode is active
- **Self-contained**: Each skill directory should contain everything needed; avoid cross-skill dependencies
- **Cross-skill handoffs**: When a skill's primary action naturally chains into another installed skill (e.g., `/vet` → `/refactor`, `/diagnose` → `/test-gen`, `/refactor` → `/test-gen`), declare `Skill` in `allowed-tools` and add a "Skill handoff" offer after the primary action completes. Offer the handoff only when there's genuine signal that the next skill adds value — never as a generic catch-all. The user must approve before the handoff fires.
- **Dynamic context injection where deterministic**: When a skill's first step gathers context that does not depend on the user's argument (e.g., `git rev-parse --abbrev-ref HEAD`, `gh repo view --json ...`, `ls package.json Cargo.toml ...`), pre-render that context in the skill body using `` !`<command>` `` (or fenced ` ```! ` for multi-line). The harness runs the command BEFORE Claude reads the skill content, replacing the placeholder with the output — so Claude sees the pre-rendered values immediately and skips the redundant Bash round-trip. Use only for **fast, side-effect-free, idempotent** commands (no `git push`, no `gh pr create`, no `npm install`). For commands that depend on the user's argument or runtime decisions, keep them in the body so Claude can run them conditionally.

## Distribution

Two install paths, both driven by `git pull`:

1. **Symlinks** (`install.sh`) — `~/.claude/skills/<name>` → `skills/<name>/`; skills are invoked as `/<name>`. The original and default path.
2. **Plugin** — the repo root carries `.claude-plugin/plugin.json` (name `claude-skills`), so a clone placed under a skills directory (e.g. `~/.claude/skills/claude-skills/`) loads as the plugin `claude-skills@skills-dir` with no install step; skills are namespaced `/claude-skills:<name>`. `skills` is left unset in the manifest because the default `skills/` directory is exactly our layout.

Manifest rules:
- `version` must equal the latest released version in `CHANGELOG.md` — `lint.sh` fails on drift, and `release.yml` refuses a tag whose version differs from the manifest. **Bump it in the same commit that moves `[Unreleased]` to a version heading.**
- Do not add `commands`, `agents`, or `hooks` paths unless those directories actually exist; the validator treats a dangling path as an error.
- `claude plugin validate ./skills --strict` (skills, strict) and `claude plugin validate .` (manifest) run in CI. The root run is intentionally non-strict: the validator warns that the development `CLAUDE.md` is not shipped as plugin context, which is correct and not a defect.
- Inside a plugin, `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` become available to hook commands and bodies; skills in this repo must still work on the symlink path, so never depend on them.

## Validation

Run `./lint.sh` to check all skills, or `./lint.sh <name>` for a specific skill. The linter checks:

- Required frontmatter fields exist (`name`, `description`, `allowed-tools`)
- Skill name matches directory name
- Description ends with a period
- `description` + `when_to_use` stay within the 1,536-character skill-listing cap (warning)
- `EnterPlanMode` and `ExitPlanMode` are paired in `allowed-tools` AND referenced in the body when present
- Canonical IMPORTANT subagent block is present **and well-formed** (contains both `subagent_type: "Explore"` and `model: "opus"`) when `Agent` or `Workflow` is paired with Explore subagents (`subagent_type: "Explore"` or `agentType: 'Explore'` in the body)
- A body embedding a Workflow script (`export const meta = {...}`) declares the `Workflow` tool (hard error otherwise); a skill declaring `Workflow` actually embeds a script (warning otherwise); and the script's `agent()` calls pass `agentType: 'Explore'` so the fan-out stays read-only (warning otherwise)
- README.md exists with required sections
- README line 3 description matches SKILL.md `description` verbatim
- Usage examples invoke the correct `/<skill-name>` (not stale names or unrelated commands)
- Configuration table has `Argument hint` and `Allowed tools` rows
- `Allowed tools` row matches SKILL.md `allowed-tools` frontmatter (whitespace-normalized)
- Warns if a SKILL.md still declares the legacy `takes-arg` field (use `argument-hint` instead)
- Warns if a SKILL.md or README hardcodes a model version in prose (e.g. `Opus 4.7`) — the `opus` alias already resolves to the latest model, so de-version it
- Frontmatter validates against `schemas/skill-frontmatter.schema.json` via `check-jsonschema` — typed enums (`model`, `effort`, `shell`, `context`), unknown-key rejection, and `agent` required when `context: fork`
- Root README skills-table description matches the SKILL.md `description` verbatim (hard error)
- Every cross-skill handoff target (`/<skill>`) resolves to an installed skill
- A body offering a Skill handoff declares the `Skill` tool, and a skill declaring `Skill` actually offers a handoff
- Finding-ID prefixes (e.g. `[C1]`) are unique across skills
- Body section style (`## Phase N` vs `## Step N`) matches the README's "N-phase" / "N steps" phrasing
- `skills.json` is in sync with a fresh `tools/generate-manifest.sh` run
- `.claude-plugin/plugin.json` `version` equals the latest released version heading in `CHANGELOG.md`

Schema validation requires `check-jsonschema` (`pip install check-jsonschema`); it runs in CI and is skipped locally with a `[note]` if the tool is absent, so a clean local run stays green either way. The `skills.json` sync and plugin-version checks require `jq`. CI also runs Claude Code's own validator (`claude plugin validate ./skills --strict`) as a second opinion from the real frontmatter parser — run it locally whenever you add a frontmatter field.
