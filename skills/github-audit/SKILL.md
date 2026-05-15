---
name: github-audit
description: Audits a GitHub repository against best practices and provides prioritized recommendations for README, license, community health, CI/CD, and repository settings.
when_to_use: Use when the user asks for a GitHub repo audit, wants to evaluate README/license/community-health/CI-CD coverage, or asks "is this repo ready for public release".
allowed-tools: Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, AskUserQuestion, Skill, EnterPlanMode, ExitPlanMode
model: opus
effort: max
---

Call `EnterPlanMode` immediately before doing anything else.

You are about to perform a comprehensive audit of this GitHub repository against GitHub best practices. Your goal is to identify what's missing, what's incomplete, and what can be improved — then present a prioritized, actionable list of recommendations.

Execute each phase thoroughly before moving to the next. Use subagents for parallel exploration wherever possible.

**Ask the user questions when it would improve the result.** For example: after Phase 1, ask about the project's intended audience (public library vs internal tool vs personal project) since this affects which best practices matter most.

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

## Pre-rendered context

The harness pre-renders the repository identity and a few scoping checks (Claude Code dynamic context injection) so Phase 1 doesn't re-run the same `gh` commands. Substitute the resolved `slug`/`default_branch` directly into the API paths in Phase 1's Agent 3.

- **Repo slug (`owner/name`):** !`gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "(gh unavailable or not a github remote)"`
- **Default branch:** !`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "(unknown)"`
- **License:** !`gh repo view --json licenseInfo --jq '.licenseInfo.spdxId // "(none detected)"' 2>/dev/null || echo "(gh unavailable)"`
- **Topics:** !`gh repo view --json repositoryTopics --jq '[.repositoryTopics[].name] | join(",")' 2>/dev/null || echo "(none)"`
- **Workflows present:** !`ls -1 .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | head -10 || echo "(none)"`

If `Repo slug` is `(gh unavailable...)`, stop in Phase 1 with an actionable error explaining that `gh` must be authenticated and the remote must be GitHub. Otherwise use the resolved slug in subsequent `gh api repos/<slug>/...` calls.

---

## Phase 1: Repository Scan

Launch Explore agents in parallel to gather data on all GitHub-relevant aspects of the repository.

### Agent 1: File & Structure Audit

Scan for the presence, location, and quality of these files:

- `README.md` (or `README`, `readme.md`)
- `LICENSE` (or `LICENSE.md`, `LICENCE`, `COPYING`)
- `.gitignore`
- `CHANGELOG.md` (or `CHANGES.md`, `HISTORY.md`)
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `.github/FUNDING.yml`
- `.github/ISSUE_TEMPLATE/` or `.github/ISSUE_TEMPLATE.md`
- `.github/PULL_REQUEST_TEMPLATE.md` or `.github/PULL_REQUEST_TEMPLATE/`
- `.github/DISCUSSION_TEMPLATE/`
- `.github/workflows/` (GitHub Actions)
- `.github/dependabot.yml`
- `.github/CODEOWNERS`
- `docs/` directory
- `.editorconfig`

Read each file that exists. Note which are missing entirely.

### Agent 2: README Deep Analysis

If a README exists, evaluate it against these criteria:

- **Project title and description** — Is it clear what this project does?
- **Badges** — Build status, version, license, coverage, etc.
- **Installation instructions** — Can someone get started quickly?
- **Usage examples** — Are there code snippets or command examples?
- **Configuration / API reference** — For libraries/tools, is the interface documented?
- **Screenshots or visuals** — For UI projects, are there screenshots or demos?
- **Contributing section** — Is there a link to CONTRIBUTING.md or inline guidelines?
- **License section** — Is the license mentioned/linked?
- **Table of contents** — For longer READMEs, is navigation provided?
- **Links to documentation** — If there are docs, are they linked?
- **Contact / support** — How to get help or report issues?

### Agent 3: GitHub Settings & CI/CD

Use bash commands to check:

```bash
# Check if this is a git repo and has a remote
git remote -v 2>/dev/null

# Check branch setup
git branch -a 2>/dev/null

# Check if there's a default branch protection indicator
# (look for branch protection in CI/CD workflows)
ls -la .github/workflows/ 2>/dev/null

# Check git tags (releases)
git tag -l 2>/dev/null | tail -20

# Check recent commit patterns
git log --oneline -20 2>/dev/null

# Check .gitignore coverage - look for common files that shouldn't be committed
# (node_modules, .env, __pycache__, .DS_Store, etc.)
cat .gitignore 2>/dev/null
```

If the repo has a GitHub remote, use `gh` CLI to check. First resolve the repo slug and default branch so the API paths can be substituted explicitly (`gh api` does not auto-expand `{owner}/{repo}` placeholders):

```bash
# Repository metadata (also yields the slug and default branch)
gh repo view --json name,description,url,homepageUrl,isPrivate,hasIssuesEnabled,hasWikiEnabled,hasDiscussionsEnabled,hasProjectsEnabled,licenseInfo,repositoryTopics,defaultBranchRef,stargazerCount,forkCount 2>/dev/null

# Resolve slug and default branch for the subsequent API calls
slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
default_branch=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)

# Check if GitHub Pages is enabled
[ -n "$slug" ] && gh api "repos/$slug/pages" 2>/dev/null

# Check branch protection rules on the actual default branch (not a guess of main/master)
[ -n "$slug" ] && [ -n "$default_branch" ] && gh api "repos/$slug/branches/$default_branch/protection" 2>/dev/null

# Check if Dependabot alerts are enabled
[ -n "$slug" ] && gh api "repos/$slug/vulnerability-alerts" 2>/dev/null

# Check releases
gh release list --limit 5 2>/dev/null

# Check secrets scanning
[ -n "$slug" ] && gh api "repos/$slug/secret-scanning/alerts" --paginate 2>/dev/null | head -5
```

Note: many of these commands may fail on private repos or repos without certain features enabled. That's fine — a failed check is itself a finding.

---

## Phase 2: Best Practices Evaluation

Based on Phase 1 findings, evaluate the repository across these categories. For each category, assign a status:

- **Good** — Meets or exceeds best practices
- **Needs improvement** — Exists but incomplete or outdated
- **Missing** — Not present at all
- **N/A** — Not applicable for this project type

### Categories

**1. README Quality**
- Does it clearly explain what the project is?
- Can a new user get started in under 5 minutes?
- Are there usage examples?
- Is it well-structured and scannable?

**2. License**
- Is a license file present?
- Is it a recognized open-source license?
- Is it referenced in the README?
- Is it appropriate for the project type?

**3. Community Health**
- Contributing guidelines (CONTRIBUTING.md)
- Code of conduct (CODE_OF_CONDUCT.md)
- Security policy (SECURITY.md)
- Issue templates
- PR templates
- CODEOWNERS

**4. CI/CD & Automation**
- GitHub Actions workflows present?
- Are tests automated?
- Is there a build/lint step?
- Dependabot configured?
- Release automation?

**5. Repository Settings**
- Description set?
- Topics/tags added?
- Homepage URL set (if applicable)?
- Issues enabled?
- Discussions enabled (if appropriate)?
- Wiki configured or disabled?
- Social preview / branding?

**6. Git Hygiene**
- .gitignore comprehensive for the project's tech stack?
- No committed secrets or sensitive files?
- Meaningful commit messages?
- Branch strategy evident?
- Tags/releases used?

**7. Documentation**
- Is documentation sufficient for the project's complexity?
- API docs for libraries?
- Architecture docs for complex projects?
- Changelog maintained?

---

## Phase 3: Prioritized Recommendations

Present your findings in this format:

### Repository Scorecard

| Category | Status | Priority |
|----------|--------|----------|
| README Quality | Good / Needs improvement / Missing | High / Medium / Low |
| License | ... | ... |
| Community Health | ... | ... |
| CI/CD & Automation | ... | ... |
| Repository Settings | ... | ... |
| Git Hygiene | ... | ... |
| Documentation | ... | ... |

### Top Recommendations

For each recommendation (ordered by priority):

#### 1. [Recommendation Title]
**Category**: Which category this falls under
**Effort**: Quick fix (< 5 min) / Small (< 30 min) / Medium (< 2 hours)
**Impact**: Why this matters

**What to do:**
Specific, actionable steps. Include example content, commands, or file templates where helpful.

---

Aim for 5-10 concrete recommendations. Focus on what would have the most impact for this specific project — not a generic checklist. Consider the project's type, audience, and maturity stage when prioritizing.

**Skill handoff.** If a recommendation maps cleanly to another installed skill in this collection, suggest invoking it via the `Skill` tool instead of implementing manually. Examples:
- "Dependencies are stale / no Dependabot configured" → suggest `/dep-check`
- "No tests" or "test coverage gaps" → suggest `/test-gen`
- "Missing docstrings on public API" → suggest `/docstring-check`
- "Code smells / refactoring opportunities surfaced by the audit" → suggest `/refactor`
- "Ready to ship a fix and you don't have a PR workflow set up" → suggest `/github-ship`

After presenting the full audit, call `ExitPlanMode`, then ask: **"Want me to implement any of these recommendations?"**
