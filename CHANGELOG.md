# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **Every fan-out skill now runs its analysis as a `Workflow` of exactly 3 read-only Explore agents by default.** `vet`, `refactor`, `test-gen`, `diagnose`, `dep-check`, `docstring-check`, `idiom-check`, `enhance`, and `github-audit` previously launched their three lenses through the `Agent` tool; each now embeds a small Workflow script (`export const meta = {...}` + one `parallel()` round of three `agent()` calls with `agentType: 'Explore'`) that gives the fan-out deterministic orchestration, `/workflows` live progress, and resumable results. The `### Agent N` sections remain the single source of truth for each brief — the script references them rather than duplicating the checklists. The `Agent`-tool fan-out is retained verbatim as a **fallback** for sessions where the Workflow tool is unavailable or disabled (`disableWorkflows`), so `Agent` stays in `allowed-tools` alongside the newly declared `Workflow`. Since the Workflow tool's own gate accepts "a skill whose instructions tell you to call Workflow" as an explicit opt-in, no `ultra` argument is needed for this three-agent tier; `vet ultra` still layers its adversarial-verify stage on top of the same script.
- **Default `effort` is now `xhigh` instead of `max` across all 11 skills** (frontmatter, README Configuration tables, the root README skills table, `create-skill` R1/R13, and the template). `xhigh` keeps the deep-reasoning tier without `max`'s latency and token cost; `max` is reserved for the user's own session setting or an `ultra` tier. `CLAUDE.md` records this as a Quality Standard.
- **The canonical IMPORTANT subagent block now covers both launch paths** — `agentType: 'Explore'` (omit `model`) inside the Workflow script, `subagent_type: "Explore"` + `model: "opus"` on the Agent-tool fallback — and its rationale for the Opus override is corrected (see Fixed). `create-skill` R2/R3/R4 are rewritten around the Workflow launch boilerplate, R1 documents the `xhigh` default, and the Step 1 fan-out option reads "3-agent Workflow".
- **`CLAUDE.md` replaces the single "opt-in orchestration tier" bullet with three:** *Three-agent Workflow by default* (the new default fan-out and why `parallel()` without `schema` is the right shape), *Opt-in `ultra` tier* (everything heavier than one round of three agents still requires `ultra` or the user's `effort: max`), and *Effort default is `xhigh`*. The SKILL.md Body conventions and Validation list are updated to match.
- **`tools/generate-manifest.sh` emits a new `uses_workflow` signal per skill** and its `uses_subagents` detection now also recognises `agentType: 'Explore'` inside Workflow scripts. `skills.json` regenerated.

- **The four skills with a regular finding shape now pass a `schema` to their Workflow agents.** `vet`, `refactor`, `docstring-check`, and `idiom-check` define a `FINDINGS` JSON Schema that mirrors their "structured format" list (fields, severity/confidence/risk enums, `looks_good` callout counts, and `idiom-check`'s ~12-finding cap as `maxItems`), so the harness validates every agent's return and Step 3 synthesizes from `{ findings, looks_good }` objects instead of free text. `vet ultra` now reuses Step 2's `FINDINGS` (its private copy is gone), verifies against `description` rather than `detail`, and carries the finders' `looks_good` callouts through the pipeline so the report's "Looks Good" section is still populated. The five skills whose agents return heterogeneous digests (`enhance`, `github-audit`, `dep-check`, `test-gen`, `diagnose`) stay text-returning; `CLAUDE.md` and `create-skill` R4 document the rule.

### Added

- **Five official frontmatter fields the schema previously rejected:** `disallowed-tools` (string or list), `background` (boolean; the schema requires `context` alongside it), `metadata` (free-form map), `license`, and `compatibility` (≤ 500 chars). `hooks` is now typed too — event-name keys, `matcher` + `hooks[]` entries, handler `type` restricted to the five documented kinds (`command`, `http`, `mcp_tool`, `prompt`, `agent`), with `if`/`once`/`timeout`/`statusMessage` — while leaving handler objects open for type-specific fields. `model` gains the `fable` alias (full model IDs stay rejected by policy). Documented in `CLAUDE.md`, `create-skill` R1, and `templates/SKILL.md`.
- **Body-substitution docs for `$ARGUMENTS[N]`, `\$` escaping, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, and `${CLAUDE_PLUGIN_DATA}`**, with the caveat that `${CLAUDE_SKILL_DIR}` is not expanded inside hook commands.
- **Skill-scoped `PreToolUse` guard hooks on `github-ship` and `idiom-check`.** Both skills already said "never `--no-verify`" in prose; each now declares an inline-shell hook on `Bash` that exits 2 (blocking the call, with an explanatory message) on any command containing `--no-verify` or a `git push` with `--force`/`-f`, while still allowing the skills' own `push -u`, `push --delete`, and `branch -D`. The hook is inline because `${CLAUDE_SKILL_DIR}` is not available in hook commands; it stays active for the rest of the session, which the README Safety sections call out. Verified against 13 block/allow payloads.
- **`.claude-plugin/plugin.json` — the repo is now installable as a Claude Code plugin** (`claude-skills`). A clone placed under a skills directory loads as `claude-skills@skills-dir` with no install step, namespacing skills as `/claude-skills:<name>`; `install.sh` symlinks remain the default path. The manifest `version` is pinned to the current release and guarded twice: `lint.sh` fails if it differs from the latest `CHANGELOG.md` release heading, and `release.yml` refuses a tag whose version differs from the manifest. `CLAUDE.md` gains a *Distribution* section.
- **CI runs Claude Code's own validator.** A new `plugin-validate` job in `lint.yml` installs the pinned CLI and runs `claude plugin validate ./skills --strict` (real frontmatter parser, unrecognized fields fail the build) plus `claude plugin validate .` for the manifest — non-strict at the root because the validator warns that the development `CLAUDE.md` is not shipped as plugin context, which is correct.
- **Skill-listing budget lint:** warns when `description` + `when_to_use` exceed the documented 1,536-character per-entry cap (`skillListingMaxDescChars`), so a verbose trigger phrase can't be silently truncated in the session listing. The root README gains a *Managing Context Cost* section covering `/skill-doctor` (Claude Code 2.1.261+) and `skillOverrides` (`on` / `name-only` / `user-invocable-only` / `off`).
- **Three `lint.sh` checks for the Workflow tier:** (1) a body embedding a Workflow script (`export const meta = {...}`) must declare the `Workflow` tool — hard error otherwise, mirroring the existing Skill-handoff coupling rule; (2) a skill declaring `Workflow` without embedding a script gets a dangling-permission warning; (3) a script whose `agent()` calls never pass `agentType: 'Explore'` is warned as not read-only. The canonical-IMPORTANT-block check now also triggers when `Workflow` (not only `Agent`) is paired with Explore subagents.
- **README Requirements bullets for the Workflow tool** on every fan-out skill, noting the paid-plan/API availability and the `Agent`-tool fallback, plus Safety bullets naming the read-only mechanism on both paths.

### Fixed

- **The canonical IMPORTANT block claimed "Explore defaults to Haiku"; the official sub-agents reference says the built-in Explore agent *inherits the session model* (capped at Opus).** The rationale for `model: "opus"` on the Agent path is corrected to what it actually buys — pinning the fan-out to the latest Opus even when a cheaper default subagent model is configured — and the Workflow path correctly omits `model` so agents inherit the session model.
- **`min` was documented as an effort level in three places** (root README frontmatter example, and the `${CLAUDE_EFFORT}` gates in `vet` and `dep-check`); the official model-config reference states the minimum level is `low`. Removed, and the `CLAUDE.md` `effort` row now says so explicitly.

## [0.3.0] - 2026-05-29

### Added

- **`schemas/skill-frontmatter.schema.json` — a JSON Schema 2020-12 contract for SKILL.md frontmatter.** Encodes the full Claude Code skill spec from `CLAUDE.md` (required + optional fields) as a machine-readable, publishable, `$ref`-able artifact: typed enums (`model`, `effort`, `shell`, `context`), kebab-case `name`, period-terminated `description`, comma-separated `allowed-tools`, and a conditional requiring `agent` when `context: fork`. `additionalProperties: false` rejects unknown keys (typos, stale fields). `lint.sh` validates every skill against it via `check-jsonschema`; CI installs the tool, local runs skip it with a `[note]` if absent.
- **`skills.json` — an auto-generated machine-readable manifest of the catalogue.** Produced by `tools/generate-manifest.sh` (frontmatter + body signals: subagent use, handoff targets, finding-ID prefixes). `lint.sh` fails if the committed manifest drifts from a fresh generation, so it stays a faithful index of `skills/`. Unblocks future tooling (discovery, IDE integration, dashboards).
- **`docs/handoff-graph.md` and a README diagram — an auto-generated Mermaid graph of cross-skill handoffs.** Produced by `tools/generate-handoff-graph.sh` from `skills.json` and embedded in the root README between `<!-- handoff-graph:start -->`/`<!-- handoff-graph:end -->` markers, giving the catalogue its first visual, GitHub-rendered representation as a system rather than a flat table.
- **Six new `lint.sh` checks**, each closing a documented-but-previously-unenforced convention: (1) frontmatter schema validation; (2) root README skills-table description parity (hard error — see Fixed below); (3) cross-skill handoff targets resolve to installed skills; (4) `Skill`-tool / body-handoff coupling; (5) finding-ID prefix uniqueness across skills; (6) `## Phase N` / `## Step N` body style matching the README's "N-phase" / "N steps" phrasing.
- **`/vet ultra` — an opt-in deep-review tier orchestrated with the `Workflow` tool.** The default `/vet` still runs the fast three-Explore fan-out; `/vet ultra [scope]` instead drives a `Workflow` pipeline that finds across the three review dimensions and then **adversarially verifies** every finding with an independent three-vote skeptic panel (a finding survives only if a majority can't refute it), trading latency and tokens for higher precision. Subagents inherit the session's Opus and stay read-only via `agentType: 'Explore'`. Establishes the repo's first "opt-in orchestration tier", now documented in `CLAUDE.md`.
- **Two further `lint.sh` checks:** (1) the canonical IMPORTANT subagent block must be *well-formed* — it must now contain both the literal `subagent_type: "Explore"` and `model: "opus"`, not merely the sentinel phrase; (2) a drift guard warns when any SKILL.md or README hardcodes a model version in prose (e.g. `Opus 4.7`), since the `opus` alias already resolves to the latest model.

### Fixed

- **`CLAUDE.md` claimed `lint.sh` "enforces all three [description] matches" — it only enforced two.** The root README skills-table description cell was never compared against the SKILL.md `description`; only the skill-local README line-3 match was checked (and only as a warning). The new root-table parity check makes the claim true (the root-table match is now a hard error), and the wording is corrected to state the per-location severities precisely.
- **De-versioned the canonical IMPORTANT block and all model-version prose (17 references across 10 `SKILL.md` + 5 `README.md` files).** Following the Opus 4.8 release, every "resolves to Claude Opus 4.7, the most capable model" (and the README variants such as "3 parallel read-only Opus 4.7 agents") hardcoded a now-stale version number. They now read "the latest Claude Opus" / "Opus", so the prose tracks whatever the `opus` alias resolves to and never goes stale on a future Opus release. Frontmatter was already correct (`model: opus` is a live alias); only the prose was wrong.

### Changed

- **`lint.sh` now uses `check-jsonschema` (Python) for frontmatter schema validation and `jq` for the `skills.json` sync check.** Both are optional locally — missing tools produce an uncounted `[note]` and a clean run stays green — and both are present in CI (the `lint` workflow adds `actions/setup-python` + `pip install check-jsonschema==0.37.2`; `jq` is preinstalled on the runner). The pure-bash structural checks are unchanged and the script's bash 3.2 floor is preserved (the cross-skill aggregation uses `sort`/`uniq`/`awk`, not bash 4 associative arrays).
- **`CLAUDE.md` documents the "opt-in orchestration tier" convention and clarifies the `model` field.** A new Quality-Standards bullet draws the line between the simple default path and `Workflow`-tool orchestration gated behind an explicit `ultra` / `effort: max` opt-in (with `vet` as the reference and `github-ship` as the never-orchestrate reference); the `model` row now notes the `opus` alias resolves to the latest Opus, so skills are de-versioned in prose only.
- **`enhance` now declares `when_to_use`** — the only fan-out skill that lacked it, closing a catalogue-listing/discovery gap (it remains user-triggered via `disable-model-invocation: true`).
- **`tools/generate-manifest.sh` warns on stderr when a skill directory has no `SKILL.md`** instead of silently dropping it from `skills.json`.

## [0.2.6] - 2026-05-28

### Fixed

- **`lint.sh` function-header comments now match the code they document.** Two block comments listed an outdated set of mutated globals — leftover drift from the v0.2.3 `takes-arg` → `argument-hint` migration that updated the function bodies but not the headers above them. `scan_skill_md()` claimed to set a `FM_CLOSED` global that doesn't exist (close-delimiter is tracked locally as `past_fm`) while omitting the `FM_ARG_HINT` and `FM_HAS_TAKES_ARG` it actually does set; `scan_readme_md()` documented a `HAS_TAKES_ARG_ROW` that was renamed to `HAS_ARG_HINT_ROW` and `HAS_LEGACY_TAKES_ARG_ROW`. Comment-only fix; no behavior change, all 259 lint checks still pass.

## [0.2.5] - 2026-05-28

### Fixed

- **`install.sh` now prunes stale skill symlinks (install-all mode).** Previously the installer only created or replaced links for skills that still exist in `skills/`, so a skill that was renamed or removed — e.g. `code-review` → `vet` in v0.2.4 — left a dangling `~/.claude/skills/<old-name>` symlink that re-running `./install.sh` never cleaned up, contradicting the v0.2.4 note that said it would. The installer now removes any symlink under `~/.claude/skills/` that points into this repo's `skills/` directory but whose source is gone. Symlinks pointing elsewhere, dangling links outside this repo, and real directories the user created are all left untouched, and pruning only runs when `./install.sh` is invoked with no arguments.
- **`vet` report heading now reads `## Vet:` instead of `## Code Review:`.** The v0.2.4 rename updated the skill's invocation, directory, and README title but left the generated report — and the sample transcript in `skills/vet/README.md` — branded with the old `Code Review` name. Both now match the skill's name.

## [0.2.4] - 2026-05-16

### Changed

- **Renamed the `code-review` skill to `vet`** to avoid collision with Claude Code's built-in `/review` and `/security-review` commands (the old `/code-review` was confusingly adjacent). Behavior, `description`, `allowed-tools`, the `argument-hint`, and the report format are unchanged — only the invocation (`/code-review` → `/vet`), the skill directory (`skills/code-review/` → `skills/vet/`), and the README title (`# Code Review` → `# Vet`) changed. Cross-skill handoff and example references in `idiom-check`, `refactor`, `create-skill`, the root `README.md`, and `CLAUDE.md` were updated to `/vet`. Re-run `./install.sh` to create the `~/.claude/skills/vet` symlink and remove the now-stale `~/.claude/skills/code-review` link.

## [0.2.3] - 2026-05-15

### Fixed

- **`code-review` can now actually apply fixes its Step 4 promises.** Step 4 ("Address findings... Show each change clearly") existed in the body but `Edit` was missing from `allowed-tools`, so the skill could only review and never edit. Added `Edit` to both the SKILL.md frontmatter and the README's `Allowed tools` row.
- **`dep-check` and `diagnose` IMPORTANT subagent blocks restored to the canonical wording.** Both skills had an abbreviated version of the block that omitted (a) the rationale for the model override (`The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis.`) and (b) the closing prohibition on general-purpose subagents (`Never use general-purpose subagents in this skill.`). Now matches `code-review`, `enhance`, `idiom-check`, `refactor`, and `test-gen` verbatim.
- **`idiom-check` Step 5 now uses the safer `git stash create` + `git stash store` backup pattern** instead of `git stash push`. `git stash push` exits 0 even when there's nothing to stash, which makes a "revert all" hard to reason about; the explicit-SHA pattern gives the user a referenceable backup. This brings `idiom-check` in line with `refactor` and `docstring-check` (which migrated to this pattern in v0.1.0).
- **`enhance` Phase 1 restructured to follow the standard `### Agent N: <Title>` convention.** Was 4 bold-prefixed bullet groups (Structure & Stack / Documentation & Intent / History & Trajectory / Quality & Gaps) launched via "Launch multiple exploration agents in parallel" with no fixed count; now 3 explicit `### Agent N:` subheadings (Structure & Stack / Documentation, Intent & History / Quality & Gaps), matching every other multi-agent skill and the canonical structure documented in `CLAUDE.md` and `create-skill` R4.

### Changed

- **Migrated all skills from the repo-internal `takes-arg` field to the official Claude Code `argument-hint` field.** `takes-arg: true` was a documentation-only convention this repo invented; Claude Code never recognized it. Skills now declare `argument-hint: "[hint]"` (e.g., `code-review` → `[path | identifier | ref | range]`) which surfaces in `/<skill> <Tab>` autocomplete. The 7 affected skills: `code-review`, `create-skill`, `dep-check`, `diagnose`, `docstring-check`, `refactor`, `test-gen`.
- **Documented the full official Claude Code skill frontmatter in `CLAUDE.md`.** Previously the optional-fields table listed 4 fields (`model`, `effort`, `disable-model-invocation`, `takes-arg`); it now lists every Claude Code-supported field (`argument-hint`, `arguments`, `when_to_use`, `paths`, `disable-model-invocation`, `user-invocable`, `context`, `agent`, `hooks`, `shell`) with the body-substitution table (`$ARGUMENTS`, `$N`, `$<name>`, `${CLAUDE_*}`) and dynamic context injection syntax (`` !`<command>` ``).
- **`templates/SKILL.md` and `templates/README.md` updated to the new spec.** Template frontmatter now shows `argument-hint`, `arguments`, `when_to_use`, `paths`, `user-invocable`, `context`, `agent` as commented-out optional fields. Configuration table row renamed from `Takes argument` to `Argument hint`.
- **All 11 skill READMEs renamed `Takes argument` row to `Argument hint`** with the matching hint string (or `No` for skills that take no argument).
- **`create-skill`'s embedded R1–R13 reference updated to match the new spec.** R1 frontmatter table now documents `argument-hint`, `arguments`, `when_to_use`, `paths`, `user-invocable`, `context`, `agent`. R3 ARGUMENTS-line guidance, R9 argument-resolution cascade, and R11 README configuration table all use the new field name.
- **Standardized "Strengths" callouts to "Looks Good" across every skill.** `code-review` and `idiom-check` already used "Looks Good"; `docstring-check` and `refactor` used the synonymous "Strengths". Picked "Looks Good" as the project-wide name. Affects 8 occurrences in `docstring-check/SKILL.md`, 2 in `refactor/SKILL.md`, and 1 in `refactor/README.md`.

### Added

- **`lint.sh` enforces the new `argument-hint` contract.** The single-pass SKILL.md scanner now extracts the `argument-hint` value (passes when present) and the legacy `takes-arg` flag (warns when present so authors know to migrate). The README scanner now looks for the new `Argument hint` row and warns separately when it sees the legacy `Takes argument` row.
- **Cross-skill handoffs via the `Skill` tool in 5 skills.** Previously only `github-audit` wired any handoffs. Now:
  - `/code-review` → offers `/refactor` after fixes are applied (when structural smells go beyond the diff).
  - `/diagnose` → offers `/test-gen` after a fix lands (write a regression test for the bug).
  - `/refactor` → offers `/test-gen` after refactoring (refresh tests for renamed/restructured surfaces).
  - `/idiom-check` → offers `/code-review` on each bundle PR (independent second pass before merge).
  - `/dep-check` → offers `/test-gen` after major version bumps (cover the breaking-change surface).
  Each handoff is gated on signal (only offered when warranted) and requires user approval before firing. `Skill` added to `allowed-tools` in both SKILL.md frontmatter and the README's `Allowed tools` row for each skill.
- **`code-review` now declares `AskUserQuestion` in `allowed-tools`** alongside `Skill` (the action-offer step needs it for the structured handoff offer). Previously the body asked questions inline via prose only.
- **`CLAUDE.md` Quality Standards section documents the Cross-skill handoffs pattern** — when to wire it (genuine workflow chaining), how it's gated (offer only when warranted), and the interaction model (user must approve the handoff before it fires).
- **`when_to_use` frontmatter on every auto-invocable skill (10 of 11).** Each skill now declares 1-2 sentences of trigger-phrase guidance complementing `description`, so Claude has stronger signal when matching a user request to a skill. Examples: `/code-review` triggers on "is this ready to merge"; `/diagnose` triggers on a pasted stack trace; `/dep-check` triggers on "outdated dependencies" / "package CVEs". `/enhance` is excluded — it has `disable-model-invocation: true` so auto-invocation matching does not apply.
- **`ultrathink` keyword in synthesis steps of 3 strategic skills.** Including `ultrathink` anywhere in skill content requests deeper reasoning ([per docs](https://code.claude.com/docs/en/model-config#use-ultrathink-for-one-off-deep-reasoning)). Added to `/enhance` Phase 5 (Innovation Synthesis), `/diagnose` Step 3 (hypothesis ranking), and `/idiom-check` Step 3 (deduplication + prioritization across 3 agent reports). The skills where the synthesis step's quality drives the entire output's value.
- **`${CLAUDE_EFFORT}` substitution for adaptive depth in 2 skills.** `/code-review` Step 2 now scales the agent's file-reading depth to effort: max/xhigh/high read full files (current default behavior), medium/low/min read changed hunks plus ~50 surrounding lines. `/dep-check` Agent 3 scales the breaking-change WebSearch step similarly: max/xhigh/high check every major bump, medium only ≥3-version drift, low/min skip entirely. Both modes annotate the report header so users know depth was reduced.
- **Dynamic context injection (`` !`<command>` ``) in 4 skills.** Each skill now pre-renders its deterministic, side-effect-free context-gathering at the top of the body, so the data arrives in Claude's context before the skill body is read — saving a Bash round-trip and a chunk of tokens per invocation.
  - `/github-ship` pre-renders: in-git-repo, github-remote, gh-authed, current branch, default branch, working-tree state, existing PR for current branch.
  - `/code-review` pre-renders (auto-detect path only): current branch, default branch, staged files, unstaged files, branch-ahead-of-upstream commits.
  - `/dep-check` pre-renders (no-arg path only): root-level manifest inventory, C# project files, GitHub Actions workflows, Dockerfiles, tooling pins, renovate/dependabot config presence.
  - `/github-audit` pre-renders: repo slug (`owner/name`), default branch, license SPDX ID, topics, workflow file list. The slug + default branch are then substituted into the Phase 1 `gh api repos/<slug>/...` paths instead of being re-resolved.
- **`CLAUDE.md` Quality Standards now documents the dynamic-context-injection idiom.** Specifies when to use it (deterministic, side-effect-free, idempotent commands; no `git push`/`gh pr create`/`npm install`) and when to keep commands in the body (anything that depends on the user's argument or runtime decisions).

### Notes

- **`paths` frontmatter intentionally not adopted.** Initial plan was to add `paths` globs to `/test-gen` and `/docstring-check` for path-based auto-activation. On reflection, both skills naturally apply to "any source file", which is too broad to be a useful narrowing trigger — `paths` shines for narrowly-scoped skills (e.g., a "rails-helper" skill matching `**/*.rb`), not for general-purpose code skills. Skipping unless a future skill emerges that benefits from it.

## [0.2.2] - 2026-05-15

### Fixed

- **`lint.sh` no longer breaks on CRLF-saved SKILL.md/README.md files.** Previously, a Windows-saved skill failed every check (the `---` and `## Section` matches don't equal `---\r` / `## Section\r`) with the unhelpful diagnostic "missing frontmatter". The two new single-pass scanners (`scan_skill_md`, `scan_readme_md`) strip a trailing `\r` per line and a leading UTF-8 BOM on line 1 before any comparison. Lines without a trailing newline are now handled via the `|| [[ -n "$line" ]]` idiom so the last line of a truncated file still parses.
- **`lint.sh` no longer prints "README Usage examples reference /name correctly" alongside a "README missing section: Usage" failure.** The slash-command parity check is now gated on `HAS_USAGE`, eliminating a contradictory pass/fail pair on the same skill.
- **`install.sh` collects failures across all skill arguments instead of aborting on the first one.** Under `set -e`, `install_skill "$skill"` returning 1 in a `for` loop terminated the script — so `bash install.sh nonexistent_skill another_skill` would error on the first and silently skip the second. Now uses `install_skill ... || exit_code=1` per iteration and ends with `exit "$exit_code"`. Mirrors `lint.sh`'s "report and continue, exit non-zero at the end" semantics.
- **`install.sh` rollback-failure message now prints the exact `mv` recovery command** (`Restore manually with: mv <backup> <target>`, both paths `%q`-quoted). Previously the user was told "backup left in place" with no actionable next step.

### Changed

- **`lint.sh` consolidates ~17 file scans per skill into 2 single-pass scanners.** Replaces three `get_frontmatter` calls plus ~10 separate `grep` invocations per skill (and the brace-grouped 3-line read for README line 3, and the separate `while read` loop for the Allowed-tools cell) with `scan_skill_md` and `scan_readme_md`. Each function reads its file once, sets named flag globals (`FM_*`, `BODY_HAS_*`, `HAS_*`, `README_REQUIRED_FOUND[]`), and returns. Across 13 skills this is ~120 fewer subprocesses per CI lint run.
- **`REQUIRED_README_SECTIONS` is now a top-of-file constant** near `SKILLS_DIR`. Both the scanner (iterates it to populate `README_REQUIRED_FOUND[]`) and the lint loop (iterates the parallel arrays to emit pass/fail) consume the same constant — adding a new required section means editing one array. The canonical list now sits where readers expect "what does this script know about the project" data.
- **README required-section heading matching tightened to Title Case.** The pre-refactor code used `grep -qi`, tolerating arbitrary casing. The new scanner matches `## What It Does` literally (and the other three). All 13 existing skills use Title Case, and `CLAUDE.md`'s `## README Convention` only specifies Title Case, so this aligns the implementation with the documented contract.
- **Plan-mode pairing logic in `lint.sh` consolidated.** The two adjacent `if [[ "$tools" == *"EnterPlanMode"* ]]; then ... fi` guards (one for frontmatter pairing, one for body references) are now a single outer guard. The stale "if either is in tools" comment that suggested the guard checked both `EnterPlanMode` and `ExitPlanMode` (it only ever checked the former) is gone.

### Added

- **Design-rationale comments** on the dense bits of `lint.sh`: an example row above the allowed-tools regex (`Match a Configuration table row of the form: | Allowed tools | Bash, Read, Edit |`), an explicit "Asymmetry vs install.sh" header on the `pass`/`fail`/`warn` helper block explaining why `lint.sh` uses per-outcome helpers while `install.sh` uses a generic `emit`, and a "Pin return status" comment on each new scanner explaining why an explicit `return 0` is required (the body's trailing `&&` chains can yield non-zero on the last iteration and trip `set -e` in the caller).

## [0.2.1] - 2026-05-14

### Added

- **Per-skill `## Example` sections** in every skill README (`skills/*/README.md`), placed between `## Usage` and `## Configuration`. Each example shows a 1-line scenario, the exact invocation, and an abbreviated transcript using the skill's real distinctive output surface (e.g., `code-review`'s `NEEDS CHANGES ✗` verdict, `dep-check`'s `[V1]` vulnerability format, `idiom-check`'s Remediation Bundle table). Long transcripts are wrapped in `<details><summary>Sample output</summary>…</details>` so the README stays scannable.
- **`Example` column in the root README skills table** with deep-links to each skill's new `#example` anchor — turns the catalogue into a thumbnail gallery.
- **`templates/README.md`** gains an `## Example` skeleton between Usage and Configuration so new skills inherit the convention.
- **`create-skill` R11 (README Sections)** documents the new `## Example` section, explicitly noting it's exempt from the `## Usage` cross-skill awk check so handoff examples (e.g., a `github-audit` example referencing `/dep-check`) are safe inside `## Example`.
- **`lint.sh`** gains a soft `[warn]` if a skill README lacks `## Example` — non-blocking drift prevention modeled on the existing `## Safety` warn rule.

## [0.2.0] - 2026-05-14

### Fixed

- **`release.yml` is now idempotent on re-pushed tags** (`gh release view ... && gh release edit ... || gh release create ...`). Was the exact bug that required manual tag deletion + recreation during the v0.1.1 release.
- **`release.yml` awk extraction no longer leaks CHANGELOG link references** into the oldest release's notes. Stops emitting at the first `^[...]: http...` line.
- **`lint.yml` declares an explicit `permissions: contents: read`** instead of inheriting the repo-default `GITHUB_TOKEN` scope.
- **`lint.yml` runs `bash lint.sh`** instead of `chmod +x lint.sh && ./lint.sh`. The chmod was silently re-adding the executable bit on every run, masking any real permission regression.
- **`.gitignore` no longer ignores the whole `.claude/` directory** (which is project-tracked). Narrowed to `.claude/local/` and `.claude/settings.local.json` so new files added under `.claude/` aren't silently swallowed by `git add`.
- **`install.sh` `restore_on_exit`** now prints a loud warning to stderr if the rollback `mv` itself fails (previously swallowed via `|| true`), so users know the backup is still at the `.bak` path.

### Changed

- **Root `README.md` skills-table descriptions now match each `SKILL.md` `description` field verbatim.** Same canonical description in SKILL.md frontmatter + README line 3 + root README table cell. Previously 6 of 11 table cells diverged.
- **`CLAUDE.md` updated to document what `lint.sh` actually enforces post-v0.1.0**: description must end with a period; Configuration table requires `Model`/`Effort`/`Takes argument`/`Allowed tools` rows; `Allowed tools` row must match SKILL.md frontmatter verbatim; canonical IMPORTANT subagent block required when `Agent` + Explore are used; `### Agent N:` subheading style. Validation section enumerates all 11 lint checks explicitly.
- **`CLAUDE.md` "Adding a New Skill"** step list now mentions `CHANGELOG.md` (previously omitted — silently broke `release.yml`'s notes extraction). Step order reconciled with `CONTRIBUTING.md`.
- **PR template checklist** expanded from 5 items to 12 to cover the v0.1.0 lint rules contributors might forget (description period, three-way verbatim description match, Configuration row parity, IMPORTANT block presence, `EnterPlanMode`/`ExitPlanMode` pairing).
- **`SECURITY.md` SLA softened** from "48h ack / 7d resolution" to best-effort "7d ack / 30d resolution" for a maintainer-led repo. Added a "Supported Versions" section explaining the forward-only `git pull` model.
- **`CHANGELOG.md` v0.1.1 entry restructured** from one ~30-line paragraph into a top-line summary + 4 sub-bullets.
- **CONTRIBUTING.md** sample frontmatter description now ends with a period, matching the lint rule.

### Added

- **Release workflow hardening (defense-in-depth)**: `release.yml` validates the tag against `^v[0-9]+\.[0-9]+\.[0-9]+(-...)?$` up front; uses a random `EOF_$(openssl rand -hex 16)` `GITHUB_OUTPUT` heredoc delimiter so a literal `RELEASE_NOTES_EOF` in CHANGELOG can't terminate the value early; awk uses an anchored regex (`^## \[<ver>\]`) instead of substring search.
- **Issue templates** gain `title:` prefills (`[Bug] `, `[Skill Request] `) for triage searchability. `bug_report.yml`'s `model` input is now a `dropdown` for consistency with `skill_request.yml`.
- **`.editorconfig` adds explicit `[*.{yml,yaml}]`** (2-space) and `[*.md]` (2-space + `trim_trailing_whitespace = false` to preserve Markdown hard line breaks) blocks.
- **`.gitignore` gains Python** (`venv/`, `.venv/`, `.pytest_cache/`, `.coverage`, `htmlcov/`, `*.egg-info/`) and Windows (`Thumbs.db`) entries.
- **`dependabot.yml`** gains `labels: [ci, dependencies]`, `open-pull-requests-limit: 5`, a `groups.actions` block that batches all action updates into one weekly PR, and `commit-message: prefix: ci`.
- **README "Contributing" section** now links `CODE_OF_CONDUCT.md` alongside CONTRIBUTING, issue templates, and SECURITY.md.

## [0.1.1] - 2026-05-14

### Changed
- Bash function comment headers added/expanded across `install.sh` and `lint.sh` (`docstring-check` audit). Comment-only — no behavior or output changes:
  - `install_skill`, `lint_skill`, and `restore_on_exit` gained block-comment headers documenting purpose, args, return semantics, and side effects (mutated globals `PENDING_TARGET`/`PENDING_BACKUP`, counter mutations `TOTAL_*`, EXIT/INT/TERM trap role).
  - `emit`'s mixed block + inline arg comment was collapsed into a single block header that notes the deliberate non-mutation of counters (no summary block in install.sh).
  - The shared `pass`/`fail`/`warn` header now documents the load-bearing `TOTAL_FAIL > 0 → exit 1` contract that was previously implicit.
  - `get_frontmatter`'s header was tightened to specify the no-output-on-key-absent return convention and the don't-trim-trailing-whitespace contract.

## [0.1.0] - 2026-05-14

### Fixed
- `dep-check`: `ExitPlanMode` was called AFTER Step 4 attempted manifest edits, which made the apply phase unreachable while plan mode was still active. Moved the call to the end of Step 3 (before the action offer).
- `diagnose` README: every Usage example invoked `/debug` (the pre-rename name), which would either fail or hit a different built-in command. Replaced with `/diagnose`.
- `github-audit`: several `gh api repos/{owner}/{repo}/...` calls relied on placeholder substitution that `gh api` does not perform, returning 404 at runtime. Now resolves `nameWithOwner` and the default branch explicitly via `gh repo view` and substitutes them into each subsequent API call.
- `github-ship`: the PR-body heredoc used an unquoted `<<EOF` delimiter, allowing `$variable`, backtick, and `$(...)` expansion inside the body — a shell-substitution injection risk if the body included quoted code snippets. Switched to a quoted `<<'EOF'` body with `$issue_number` interpolated separately, piped via `--body-file -`.
- `github-ship`: branch cleanup unconditionally deleted the remote branch even after the user declined a force-delete on the local one. Remote delete is now gated on local-delete success or explicit user approval.
- `diagnose`: shell snippets contained literal placeholders (`<id>`, `<error_file_1>`, `<error_file_N>`, `<error_keywords>`) that would be passed unchanged if the model didn't pattern-match. Replaced with explicit `jq` extraction (`run_id`, `commit_hash`) and per-path loops.
- `refactor` and `docstring-check`: pre-change backup used `git stash push`, which exits 0 even when there's nothing to stash — a later `git stash pop` could pop an unrelated stash. Switched to `git stash create` + `git stash store` so the backup is captured by SHA.
- `dep-check`: Step 4 mixed "run `npm install <package>@<version>`" guidance with a "do NOT run install commands" rule. Now consistently edits manifests via `Edit` and instructs the user to run install/test themselves. Version/package arguments in suggested commands are quoted.

### Changed
- **Meta-skill overhaul (`create-skill`).** R4 (Subagents) now defaults to NO subagents and adds a Decision Gate: skills only fan out to 3 Explore agents when there are three genuinely orthogonal analysis lenses. This aligns the meta-skill with the project's simplicity bias (e.g., `github-ship`). R2 (Tool Selection) now documents modern primitives — `TaskCreate`/`TaskUpdate`, `Monitor`, `Skill`, `CronCreate`, `LSP` — and when to add each. Step 1 now batches the structured questions into an explicit `AskUserQuestion` call. R11 codifies "delivered in N steps" wording and verbatim-match between SKILL.md description and README first line.
- **`CLAUDE.md`**: clarified `disable-model-invocation` semantics (controls auto-invocation by other models/skills, does NOT block subagents); added Simplicity Bias and Plan-Mode Discipline to Quality Standards.
- **Templates** (`templates/SKILL.md`, `templates/README.md`): regenerated to reflect canonical opening line, default tool set (no `Agent` by default), and full Configuration table including `Takes argument`.
- **Consistency pass.** `enhance` and `github-audit` SKILL.md now use the canonical `` Call `EnterPlanMode` immediately before doing anything else. `` opening (was an older "Step 1: Enter Plan Mode..." phrasing). `github-audit` agent subheadings switched from bold inline text to `### Agent N:`. `enhance`, `github-audit`, `test-gen`, `code-review` now carry the full canonical IMPORTANT subagent block (Explore + Opus + safety reasoning). `enhance` SKILL.md phases renumbered to 1-6 (was 1, 1.5, 2-5); README phase list updated to match. `enhance` description shortened to one sentence and aligned across SKILL.md / README / root README. `enhance` allowed-tools no longer declares `LSP` (was unused).
- **Configuration tables** in all skill READMEs now list the exact same tools as the SKILL.md `allowed-tools` frontmatter (previously some omitted `EnterPlanMode`/`ExitPlanMode`). `github-audit` and `enhance` READMEs gained the `Takes argument | No` row.
- **`test-gen`** allowed-tools gained `AskUserQuestion` (the skill prompts the user mid-flow); SKILL.md gained the canonical IMPORTANT subagent block.

### Added
- **Modern primitives wired into looping skills.** `idiom-check`, `dep-check`, `docstring-check`, and `refactor` now use `TaskCreate`/`TaskUpdate` during their execution phases so the user sees live progress through multi-unit work (one task per bundle / update group / file / refactoring finding). `TaskCreate, TaskUpdate` added to each skill's `allowed-tools`.
- **`github-audit`** can now hand off to other installed skills via the `Skill` tool when a recommendation maps cleanly to another skill (e.g., dependency hygiene → `/dep-check`). `Skill` added to allowed-tools.
- **`dep-check`** Step 2 now mandates parallel `Bash` tool calls for the per-ecosystem `outdated`/`audit`/`list` sweep, with `timeout 60` per command and explicit recording of which invocations timed out vs were unavailable vs returned empty.
- **`lint.sh`** gained 6+ new regression-prevention checks: description ends with a period; matched `EnterPlanMode`/`ExitPlanMode` pairs in frontmatter and body references; canonical IMPORTANT subagent block presence when `Agent` is used with Explore subagents; README line 3 matches SKILL.md description; Usage examples invoke the correct `/<name>`; Configuration table includes `Takes argument` and `Allowed tools` rows; allowed-tools parity between SKILL.md frontmatter and README Configuration table.

## [0.0.10] - 2026-04-25

### Added
- `idiom-check` skill: audits a codebase through a programming-language-specific idiom lens (Rust/Python/TypeScript/Go/Ruby + a generic template for Java/Kotlin/C#/Swift/PHP), produces a severity-sorted report with concrete fixes, and ships remediation as PR-sized bundles

## [0.0.9] - 2026-04-24

### Added
- `github-ship` skill: turns local changes into a GitHub issue and linked PR, or cleans up the branch if the PR was already merged — auto-detects which

## [0.0.8] - 2026-04-23

### Changed
- Updated Opus 4.6 references to Opus 4.7 across all skill docs and the bug report template (Claude bumped the Opus model version; no functional change — `model: opus` still resolves to the current Opus)

## [0.0.7] - 2026-04-23

### Added
- `docstring-check` skill: scans a codebase for missing, outdated, drifted, or inconsistent docstrings and applies behavior-preserving fixes matching the project's detected convention

## [0.0.6] - 2026-04-01

### Added
- `create-skill` skill: interactive skill generator that scaffolds new skills following all project conventions, serving as the definitive reference for skill creation

## [0.0.5] - 2026-04-01

### Added
- `refactor` skill: comprehensive refactoring across correctness, security, performance, and maintainability with behavior-preserving, incremental changes
- `diagnose` skill (renamed from `debug` to avoid conflict with built-in Claude Code command): multi-agent root cause analysis that traces errors, correlates with recent changes, and identifies fixes with ranked hypotheses

## [0.0.4] - 2026-03-29

### Added
- `dep-check` skill: scans all dependency declarations across ecosystems for updates and vulnerabilities, produces a prioritized update plan with testing recommendations

## [0.0.3] - 2026-03-26

### Added
- `code-review` skill: structured multi-dimensional code review with prioritized findings and fix offers
- `test-gen` skill: comprehensive test generation with deep code analysis, convention detection, and edge case coverage

## [0.0.2] - 2026-03-25

### Added
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- Dependabot configuration for GitHub Actions updates
- Release automation workflow: auto-creates GitHub Releases from CHANGELOG when a version tag is pushed

### Changed
- Updated `actions/checkout` to v6 across all workflows
- Removed dangling email reference from SECURITY.md
- Fixed misleading "discussion" link in CONTRIBUTING.md

## [0.0.1] - 2026-03-25

### Added
- `enhance` skill: deep multi-phase project analysis with install script
- `github-audit` skill: audits GitHub repositories against best practices
- Skill Quality Kit: CLAUDE.md specification, starter templates, and lint.sh validator
- CONTRIBUTING.md with guidelines for creating and submitting skills
- SECURITY.md with trust model and vulnerability reporting process
- GitHub Actions CI workflow to run the skill linter on push and PR
- Issue templates for bug reports and skill requests
- Pull request template with submission checklist
- CHANGELOG.md
- .editorconfig for consistent formatting
- README.md with badges, usage example, contributing section, and support info
- .gitignore with defensive entries for .env, logs, node_modules, and __pycache__

[Unreleased]: https://github.com/thijsvos/Claude_Skills/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/thijsvos/Claude_Skills/compare/v0.2.6...v0.3.0
[0.2.1]: https://github.com/thijsvos/Claude_Skills/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/thijsvos/Claude_Skills/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/thijsvos/Claude_Skills/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.10...v0.1.0
[0.0.10]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.9...v0.0.10
[0.0.9]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.8...v0.0.9
[0.0.8]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.7...v0.0.8
[0.0.7]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.6...v0.0.7
[0.0.6]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.5...v0.0.6
[0.0.5]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/thijsvos/Claude_Skills/releases/tag/v0.0.1
