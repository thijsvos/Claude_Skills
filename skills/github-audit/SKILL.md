---
name: github-audit
description: Audits a GitHub repository against best practices and provides prioritized recommendations for README, license, community health, CI/CD, and repository settings.
allowed-tools: Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch, AskUserQuestion, EnterPlanMode, ExitPlanMode
model: opus
effort: max
---

**Step 1: Enter Plan Mode immediately using the EnterPlanMode tool before doing anything else.**

You are about to perform a comprehensive audit of this GitHub repository against GitHub best practices. Your goal is to identify what's missing, what's incomplete, and what can be improved — then present a prioritized, actionable list of recommendations.

Execute each phase thoroughly before moving to the next. Use subagents for parallel exploration wherever possible.

**Ask the user questions when it would improve the result.** For example: after Phase 1, ask about the project's intended audience (public library vs internal tool vs personal project) since this affects which best practices matter most.

**IMPORTANT: All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"`.** The Explore agent is read-only by design. Never use general-purpose subagents in this skill.

---

## Phase 1: Repository Scan

Launch Explore agents in parallel to gather data on all GitHub-relevant aspects of the repository.

**Agent 1: File & Structure Audit**

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

**Agent 2: README Deep Analysis**

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

**Agent 3: GitHub Settings & CI/CD**

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

If the repo has a GitHub remote, use `gh` CLI to check:

```bash
# Repository metadata
gh repo view --json name,description,url,homepageUrl,isPrivate,hasIssuesEnabled,hasWikiEnabled,hasDiscussionsEnabled,hasProjectsEnabled,licenseInfo,repositoryTopics,defaultBranchRef,stargazerCount,forkCount 2>/dev/null

# Check if GitHub Pages is enabled
gh api repos/{owner}/{repo}/pages 2>/dev/null

# Check branch protection rules
gh api repos/{owner}/{repo}/branches/main/protection 2>/dev/null || gh api repos/{owner}/{repo}/branches/master/protection 2>/dev/null

# Check if Dependabot alerts are enabled
gh api repos/{owner}/{repo}/vulnerability-alerts 2>/dev/null

# Check releases
gh release list --limit 5 2>/dev/null

# Check secrets scanning
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate 2>/dev/null | head -5
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

**Step 2: After presenting the full audit, exit Plan Mode using the ExitPlanMode tool**, then ask: **"Want me to implement any of these recommendations?"**
