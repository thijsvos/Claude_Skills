# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/thijsvos/Claude_Skills/compare/v0.2.1...HEAD
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
