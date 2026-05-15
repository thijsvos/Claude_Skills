---
name: dep-check
description: Scans all dependency declarations across ecosystems, checks for updates and vulnerabilities, and produces a prioritized update plan with testing recommendations.
allowed-tools: Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, Edit, AskUserQuestion, TaskCreate, TaskUpdate, EnterPlanMode, ExitPlanMode
model: opus
effort: max
takes-arg: true
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a comprehensive dependency audit across all ecosystems present in the repository. Scan every dependency and version declaration, check for available updates and known vulnerabilities, and produce a prioritized update plan with testing recommendations.

**ARGUMENTS:** The user may provide an optional scope argument — a specific manifest file path (e.g., `package.json`), a directory to scan, or an ecosystem name (e.g., `npm`, `python`, `docker`). If no argument is provided, auto-detect all ecosystems in the repository.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

## Pre-rendered context

The harness pre-renders manifest discovery (Claude Code dynamic context injection), so Step 1 starts with the ecosystem inventory already in hand. This is fast deterministic shell — no point spending a Bash round-trip on it.

- **Root-level manifests present:** !`ls -1 package.json Cargo.toml pyproject.toml setup.py setup.cfg requirements.txt Pipfile go.mod Gemfile pom.xml build.gradle build.gradle.kts composer.json Package.swift 2>/dev/null || echo "(none at root)"`
- **C# project files (depth ≤3):** !`find . -maxdepth 3 -type f -name '*.csproj' 2>/dev/null | head -5 || echo "(none)"`
- **GitHub Actions workflows:** !`ls -1 .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | head -10 || echo "(none)"`
- **Dockerfile(s):** !`find . -maxdepth 3 -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name 'docker-compose*.yml' -o -name 'compose*.yml' \) 2>/dev/null | head -10 || echo "(none)"`
- **Tooling pins:** !`ls -1 .tool-versions .nvmrc .node-version .python-version .ruby-version .pre-commit-config.yaml 2>/dev/null || echo "(none)"`
- **Renovate / dependabot config:** !`ls -1 .github/dependabot.yml .github/dependabot.yaml renovate.json renovate.json5 .renovaterc 2>/dev/null || echo "(none)"`

If an argument was provided, scope the scan accordingly and treat the pre-rendered list as background context. If no argument was provided, use the pre-rendered list as the starting inventory and skip the redundant ecosystem-discovery shell calls in Step 1.

---

## Step 1: Discover Ecosystems and Manifest Files

Scan the repository to identify every dependency declaration and version pin. If an argument was provided, scope the scan accordingly.

**If an argument was provided**, resolve it in this order:

1. **File path** — if the path exists on disk and is a recognized manifest file, scan only that file:
   ```bash
   test -f "<path>" && echo "file"
   ```

2. **Directory path** — if the path is a directory, scan for all manifest files within it:
   ```bash
   test -d "<path>" && echo "directory"
   ```

3. **Ecosystem name** — if the argument matches an ecosystem keyword (`npm`, `yarn`, `pnpm`, `python`, `pip`, `rust`, `cargo`, `go`, `ruby`, `java`, `maven`, `gradle`, `php`, `composer`, `dotnet`, `docker`, `terraform`, `helm`, `actions`, `ci`), scan only files related to that ecosystem.

4. If none of the above match, inform the user and stop:
   > Could not resolve the argument as a manifest file, directory, or ecosystem name. Try: `/dep-check package.json` (file), `/dep-check src/services/` (directory), or `/dep-check python` (ecosystem).

**If no argument was provided**, scan the entire repository for all of the following manifest files and version declarations. Use the Glob tool to find these files efficiently. Exclude dependency installation directories (`node_modules/`, `vendor/`, `venv/`, `.venv/`, `target/`).

**Package Managers:**
- npm/yarn/pnpm: `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- Python: `requirements*.txt`, `pyproject.toml`, `Pipfile`, `Pipfile.lock`, `setup.py`, `setup.cfg`
- Rust: `Cargo.toml`, `Cargo.lock`
- Go: `go.mod`, `go.sum`
- Ruby: `Gemfile`, `Gemfile.lock`
- Java/Kotlin: `pom.xml`, `build.gradle`, `build.gradle.kts`
- PHP: `composer.json`, `composer.lock`
- .NET: `*.csproj`, `Directory.Packages.props`, `Directory.Build.props`

**CI/CD:**
- GitHub Actions: `.github/workflows/*.yml` (scan for `uses:` directives with version pins)
- GitLab CI: `.gitlab-ci.yml` (scan for `image:` directives)
- CircleCI: `.circleci/config.yml` (scan for `image:` and orb versions)

**Infrastructure:**
- Docker: `Dockerfile*`, `docker-compose*.yml`, `compose*.yml` (scan for `FROM` directives)
- Terraform: `*.tf`, `.terraform.lock.hcl`
- Helm: `Chart.yaml`

**Tooling:**
- `.pre-commit-config.yaml` (hook repo versions)
- `.tool-versions` (asdf version pins)
- `.node-version`, `.nvmrc` (Node.js version)
- `.python-version` (Python version)
- `.ruby-version` (Ruby version)
- `dependabot.yml` or `renovate.json` / `renovate.json5` / `.renovaterc` (check configuration completeness)

Read every discovered manifest file and extract all dependencies with their current version constraints.

If no manifest files are found at all, inform the user and stop:
> No dependency manifests or version declarations found in this repository. This skill requires at least one package manager, CI/CD workflow, or infrastructure file with version pins.

**After discovery**, produce a brief summary listing each detected ecosystem, the manifest files found, and the count of dependencies in each. If the repository spans many ecosystems, ask the user whether to check all of them or focus on specific ones.

---

## Step 2: Parallel Dependency Analysis

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with the complete list of discovered manifest files, their full contents, the dependency names, current versions, version constraints, and the detected ecosystems from Step 1.

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"`. The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis.

---

### Agent 1: Application Dependencies — Package Manager Updates

For each package manager ecosystem detected, check every dependency for available updates.

**IMPORTANT — issue commands in parallel.** When checking multiple ecosystems, the per-ecosystem `outdated`/`audit`/`list` commands are independent and should be issued as **parallel `Bash` tool calls in a single response** (one tool-call block, multiple `Bash` entries). Sequential execution serializes 8+ commands that each take 10-60 seconds and inflates wall-clock time without improving accuracy. Wrap each command with `timeout 60 ...` so a slow/hanging tool doesn't block the rest of the sweep, and record which invocations timed out vs which were unavailable vs which returned empty results.

**Use CLI tools when available (preferred — faster and more accurate):**

```bash
# npm/yarn/pnpm
npm outdated --json 2>/dev/null
yarn outdated --json 2>/dev/null
pnpm outdated --format json 2>/dev/null

# Python
pip list --outdated --format json 2>/dev/null
pip-audit --format json 2>/dev/null

# Rust
cargo outdated --format json 2>/dev/null
# If cargo-outdated is not installed:
cargo update --dry-run 2>&1

# Go
go list -m -u all 2>/dev/null

# Ruby
bundle outdated --parseable 2>/dev/null

# PHP
composer outdated --format json 2>/dev/null

# .NET
dotnet list package --outdated --format json 2>/dev/null
```

**Fallback when CLI tools are not installed:** Use WebFetch to query package registries directly:

```
# npm registry
https://registry.npmjs.org/<package>/latest

# PyPI
https://pypi.org/pypi/<package>/json

# crates.io
https://crates.io/api/v1/crates/<package>

# RubyGems
https://rubygems.org/api/v1/versions/<gem>/latest.json

# Packagist (PHP)
https://repo.packagist.org/p2/<vendor>/<package>.json

# Go proxy
https://proxy.golang.org/<module>/@latest

# NuGet
https://api.nuget.org/v3-flatcontainer/<package>/index.json
```

Limit WebFetch to **at most 15 dependencies per ecosystem** to avoid rate limiting. Prioritize dependencies that appear to have the oldest pinned versions. For the rest, note that they were not checked due to volume and suggest running the appropriate CLI tool.

**For each dependency, record:**
- Package name
- Current version (as declared in the manifest)
- Latest stable version
- Version delta category: **patch** (x.x.BUMP), **minor** (x.BUMP.x), or **major** (BUMP.x.x)
- Whether it is a production dependency or dev/test dependency

If a lockfile is present alongside the manifest, note any discrepancies between the manifest constraint and the locked version.

Return findings as a structured list grouped by ecosystem, then sorted by version delta (major updates first).

---

### Agent 2: CI/CD and Infrastructure Versions

Check all non-package-manager version declarations for available updates.

**GitHub Actions:**
For each `uses:` directive in workflow files (e.g., `actions/checkout@v4`):
- Extract the action name and pinned version (tag, branch, or SHA)
- Check the latest release via:
  ```bash
  gh api repos/<owner>/<action>/releases/latest --jq '.tag_name' 2>/dev/null
  ```
  Or fall back to WebFetch: `https://api.github.com/repos/<owner>/<action>/releases/latest`
- Flag any actions pinned to a branch (e.g., `@main`) instead of a tag or SHA
- Flag any actions pinned to a major-only tag (e.g., `@v4`) vs a full SHA — note this as a style choice, not an error

**Docker base images:**
For each `FROM` directive in Dockerfiles:
- Extract the image name and tag
- If the tag is `latest`, flag as unpinned
- If the tag is a version, check for newer versions via:
  ```bash
  skopeo list-tags docker://docker.io/<image> 2>/dev/null | head -20
  ```
  Or fall back to WebFetch: `https://hub.docker.com/v2/repositories/library/<image>/tags/?page_size=10&ordering=last_updated`
  Or use WebSearch as a last resort
- Flag images using deprecated or EOL base versions (e.g., `node:14`, `python:3.7`, `ubuntu:18.04`)

**Terraform providers:**
For each `required_providers` block in `.tf` files:
- Extract provider name and version constraint
- Check latest via WebFetch: `https://registry.terraform.io/v1/providers/<namespace>/<provider>/versions`

**Helm chart dependencies:**
For each dependency in `Chart.yaml`:
- Extract chart name, repository, and version
- Note the current version for manual verification

**Pre-commit hooks:**
For each `repo` entry in `.pre-commit-config.yaml`:
- Extract the repo URL and `rev` (version tag)
- Check latest tag via:
  ```bash
  gh api repos/<owner>/<repo>/releases/latest --jq '.tag_name' 2>/dev/null
  ```

**Runtime version files** (`.tool-versions`, `.node-version`, `.python-version`, `.ruby-version`, `.nvmrc`):
- Extract the pinned version
- Check whether it is still actively supported (not EOL) using WebSearch if needed
- Note the current LTS version for comparison

**Dependency update tool configuration** (`dependabot.yml`, `renovate.json`):
- Check which ecosystems are configured for automatic updates
- Identify ecosystems present in the repo that are NOT covered by the update tool configuration
- Report missing coverage as a finding

Return findings as a structured list grouped by category (Actions, Docker, Terraform, Helm, Tooling, Update Tool Coverage).

---

### Agent 3: Security Vulnerabilities and Breaking Changes

Scan for known security vulnerabilities and assess breaking change risk for major updates.

**Use CLI audit tools when available (preferred):**

```bash
# npm
npm audit --json 2>/dev/null

# Python
pip-audit --format json 2>/dev/null
# Or: safety check --json 2>/dev/null

# Rust
cargo audit --json 2>/dev/null

# Ruby
bundle audit check 2>/dev/null
# Or: bundler-audit check 2>/dev/null

# Go
govulncheck ./... 2>/dev/null

# PHP
composer audit --format json 2>/dev/null

# .NET
dotnet list package --vulnerable --format json 2>/dev/null
```

**Fallback when CLI audit tools are not installed:** Use WebSearch to query vulnerability databases:
- Search: `<package> <version> CVE vulnerability`
- Check: `https://github.com/advisories?query=<package>` (via WebFetch to the GitHub Advisory Database API)

**For each vulnerability found, record:**
- Package name and affected version range
- CVE identifier (if available)
- Severity: **critical**, **high**, **medium**, **low**
- Brief description of the vulnerability
- Fixed-in version (the minimum version that resolves it)
- Whether the vulnerability is in a production or dev dependency

**Breaking change assessment:**
For dependencies with major version updates available (identified by Agent 1), assess the breaking change risk:
- Use WebSearch to find the changelog or migration guide: `<package> <current_major> to <latest_major> migration guide`
- Categorize the effort: **drop-in** (likely no code changes needed), **minor migration** (configuration or import changes), **significant migration** (API changes requiring code rewrites)
- Note any dependencies that have been deprecated or archived

Return findings as two structured lists:
1. **Vulnerabilities** — sorted by severity (critical first)
2. **Breaking change assessments** — for each major update, with migration effort estimate

---

## Step 3: Synthesize Update Plan

Collect all findings from the 3 agents and produce a single, structured dependency report with a prioritized update plan.

**Synthesis rules:**
- **Deduplicate**: If multiple agents flagged the same dependency, merge into one entry with combined context.
- **Prioritize**: Security vulnerabilities first, then EOL runtimes, then patch, minor, and major updates.
- **Group updates**: Combine updates that should be applied and tested together (e.g., all `@testing-library/*` packages, all AWS SDK packages, related Terraform providers).
- **Be specific**: Every finding must reference the exact manifest file, dependency name, current version, and target version.
- **Be actionable**: Every update group must include the exact commands to apply the update and test it.

**Use this report format:**

```
## Dependency Report: <repository name>

**Scanned**: <N manifest files> across <M ecosystems> | **Dependencies**: <total count>
**Updates available**: <count> | **Vulnerabilities**: <count> (<X critical, Y high, Z medium>)

---

### Security Vulnerabilities (act immediately)

**[V1]** `<package>` <current_version> — <CVE-ID>: <brief description>
Severity: **critical** | File: `<manifest_path>`
Fixed in: `<fixed_version>`
Update command:
\`\`\`
<exact command to update>
\`\`\`

(repeat for each vulnerability)

---

### Update Plan

Updates are grouped for safe, incremental application. Apply and test each group before proceeding to the next.

#### Group 1: Security patches (no breaking changes expected)
**Risk**: Low | **Effort**: Minimal

| Package | Current | Target | Delta | File |
|---------|---------|--------|-------|------|
| pkg-a   | 1.2.3   | 1.2.5  | patch | package.json |

**Apply:**
\`\`\`
<exact command(s) to apply these updates>
\`\`\`

**Test:**
- Run `<test command>` to verify no regressions
- <specific areas to smoke-test based on what these packages do>

#### Group 2: Minor updates (backward-compatible)
**Risk**: Low-Medium | **Effort**: Minimal

(same table + apply + test format)

#### Group 3: Major updates (breaking changes possible)
**Risk**: Medium-High | **Effort**: <estimated effort>

| Package | Current | Target | Delta | Migration |
|---------|---------|--------|-------|-----------|
| pkg-x   | 2.1.0   | 3.0.0  | major | Minor migration — see changelog |

**Apply:**
\`\`\`
<commands>
\`\`\`

**Test:**
- <specific testing recommendations based on what changed>

**Migration notes:**
- <specific breaking changes and how to address them>

#### Group N: CI/CD and infrastructure updates
**Risk**: <varies> | **Effort**: <varies>

| Component | Current | Target | Type | File |
|-----------|---------|--------|------|------|
| actions/checkout | v4 | v6 | GitHub Action | .github/workflows/ci.yml |

**Apply:**
<exact file edits needed>

**Test:**
- <CI/CD testing recommendations>

---

### Already Up to Date

<count> dependencies are already at their latest version.

---

### Not Checked

<list any dependencies that could not be checked, with reasons (e.g., private registry, CLI tool not installed, rate limit)>
If applicable: To check these, install `<tool>` and re-run, or run: `<manual command>`

---

### Dependency Update Tool Coverage

<If dependabot.yml or renovate.json exists>:
- Configured ecosystems: <list>
- Missing ecosystems: <list of ecosystems present in repo but not covered>
- Recommendation: <what to add to the configuration>

<If no dependency update tool is configured>:
- **Recommendation**: Configure Dependabot or Renovate to automate dependency updates. Here is a starter configuration covering all detected ecosystems:
\`\`\`yaml
<dependabot.yml or renovate.json snippet>
\`\`\`
```

**Priority logic for grouping:**
1. **Security patches** — vulnerabilities with fixes available, especially in production dependencies
2. **EOL runtime versions** — Node.js, Python, Ruby, etc. versions past end-of-life
3. **Patch updates** — safe, low-risk version bumps
4. **Minor updates** — backward-compatible feature releases
5. **Major updates** — ordered by migration effort (easiest first)
6. **CI/CD and infrastructure** — Actions, Docker, Terraform versions

After the report is presented, call `ExitPlanMode`.

---

## Step 4: Offer to Apply Updates

If there are any updates available, ask:

> **Want me to apply any of these updates?** (e.g., "apply all", "apply group 1", "apply security patches only", "apply V1 and V3")

If the user requests updates, apply them by **editing the manifest files in place** — do not run any install/network commands. The user runs install/test themselves after reviewing the diff.

**Track progress with tasks.** Before applying the first update, call `TaskCreate` once per approved update group so the user sees live progress through Step 4. Each task's subject should be the group title (e.g., `Group 1: Security patches`). Mark a task `in_progress` when you begin the group's edits and `completed` once all manifests in that group have been edited.

1. Apply updates group by group in the order specified.
2. For each manifest, use the `Edit` tool to bump the version constraint to the target version. Examples (the literal text in your `old_string`/`new_string` will match each ecosystem's manifest syntax):
   - **npm/yarn/pnpm** — bump the version in `package.json` `dependencies` / `devDependencies`.
   - **Python `requirements.txt`** — replace `<package>==<old>` with `<package>==<new>`.
   - **Python `pyproject.toml` / `Pipfile`** — bump the version constraint.
   - **Rust** — bump the version in `Cargo.toml` `[dependencies]`. (A subsequent `cargo update -p "<package>"` is something the user runs to refresh `Cargo.lock`.)
   - **Go** — bump the version in `go.mod` `require`. (User runs `go get "<module>@<version>"` afterward to refresh `go.sum`.)
   - **Ruby** — bump the version in `Gemfile`. (User runs `bundle update "<gem>"` to refresh `Gemfile.lock`.)
   - **PHP** — bump the version in `composer.json` `require`. (User runs `composer update "<package>"` to refresh `composer.lock`.)
   - **.NET** — bump the version in the `.csproj` `<PackageReference Version="..." />`.
3. For CI/CD and infrastructure updates (GitHub Actions `uses:`, Docker `FROM`, Terraform `version`, pre-commit `rev:`), use `Edit` to modify the version pin in the relevant file.
4. After applying each group, show a summary of what changed:
   > **Applied Group 1**: Updated 3 packages in `package.json`. Run `<install command>` then `<test command>` to verify.
5. Do **not** run install commands (`npm install`, `pip install`, `cargo update`, `bundle install`, etc.) or test commands automatically. Once you've finished editing manifests, tell the user what to run. Always quote `<package>` and `<version>` arguments in the commands you suggest, since version constraints can contain shell metacharacters like `<`, `>`, and spaces:
   > I've updated the version declarations. Run `npm install` (or `cargo update -p "<package>"`, `bundle update "<gem>"`, `composer update "<package>"`, etc. — quote the package/version) to refresh lockfiles and install the new versions, then `<test command>` to verify.

If the report shows zero updates and zero vulnerabilities, skip the update offer:
> All dependencies are up to date and no known vulnerabilities were found.
