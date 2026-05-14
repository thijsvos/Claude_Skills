# Dep Check

Scans all dependency declarations across ecosystems, checks for updates and vulnerabilities, and produces a prioritized update plan with testing recommendations.

## What It Does

Performs a comprehensive dependency audit across every ecosystem present in the repository, delivered in 4 steps:

1. **Ecosystem Discovery** -- scans the repository for all dependency manifests, version pins, and infrastructure files across package managers (npm, pip, Cargo, Go, Bundler, Maven/Gradle, Composer, NuGet), CI/CD (GitHub Actions, GitLab CI, CircleCI), infrastructure (Docker, Terraform, Helm), and tooling (.pre-commit, .tool-versions, runtime version files)
2. **Parallel Dependency Analysis** -- launches 3 parallel agents: Application Dependencies (current vs latest versions via CLI tools or registry APIs), CI/CD and Infrastructure (Actions, Docker base images, Terraform providers, runtime versions), and Security (CVEs via audit tools, breaking change assessments via changelog analysis)
3. **Prioritized Update Plan** -- structured report with grouped updates ordered by risk (security patches first, then patch/minor/major), exact update commands, and testing recommendations for each group
4. **Apply Updates** -- offers to apply version updates to manifest files, group by group, with install and test instructions

## Requirements

- Claude Code with **Opus model** access
- For best results, have ecosystem-specific CLI tools installed (e.g., `npm`, `pip-audit`, `cargo audit`, `gh`). The skill falls back to web registry APIs when CLI tools are unavailable.

## Usage

```
/dep-check                        # Auto-detect: scan all ecosystems in the repository
/dep-check package.json           # Check a specific manifest file
/dep-check src/backend/           # Scan a specific directory
/dep-check python                 # Check only Python dependencies
/dep-check docker                 # Check only Docker base image versions
```

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes (optional: file path, directory, or ecosystem name) |
| Allowed tools | Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, Edit, AskUserQuestion, TaskCreate, TaskUpdate, EnterPlanMode, ExitPlanMode |

## Safety

- **Read-only analysis**: All scanning agents (Step 2) use the Explore subagent type, which cannot modify files
- **User approval gate**: No manifest files are modified until you review the update plan and explicitly approve changes
- **Version declarations only**: When applying updates, the skill edits version pins in manifest files -- it does not run install commands (e.g., `npm install`, `pip install`) unless you explicitly ask
- **No commits or pushes**: The skill never commits, pushes, or publishes -- it only edits local files
- **Rate-limited web lookups**: When falling back to registry APIs, the skill limits queries to avoid rate limiting and tells you which dependencies were not checked
