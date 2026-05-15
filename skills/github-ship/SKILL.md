---
name: github-ship
description: Turns local changes into a GitHub issue and linked PR, or cleans up the branch if the PR was already merged. Auto-detects which.
when_to_use: Use when the user wants to ship pending changes as a GitHub issue + PR pair, or wants to clean up a feature branch after the PR has been merged on GitHub. Auto-detects create vs cleanup mode.
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, EnterPlanMode, ExitPlanMode
model: opus
effort: max
---

Call `EnterPlanMode` immediately before doing anything else.

You automate a GitHub issue + PR workflow. The user runs you with no arguments. You look at the current branch and figure out what to do:

- If there is a merged PR for the current branch → **clean up** the branch.
- Otherwise → **create** an issue and a linked PR for the local changes.

You never merge the PR yourself — that is always the user's action on GitHub.

---

## Step 1: Pre-flight and Decide

Check the environment. Stop with an actionable error on any failure.

```bash
git rev-parse --is-inside-work-tree 2>/dev/null || echo "not_a_repo"
git remote get-url origin 2>/dev/null | grep -qE 'github\.com[:/]' || echo "no_github_remote"
gh auth status 2>&1 | grep -q "Logged in" || echo "gh_not_authenticated"
```

Resolve the default branch:

```bash
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
[ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
current_branch=$(git rev-parse --abbrev-ref HEAD)
```

Check whether a PR already exists for the current branch:

```bash
gh pr list --head "$current_branch" --state all --json number,state,mergedAt,url --limit 1 2>/dev/null
```

- If the PR state is `MERGED` → go to **Step 3 (Cleanup)**.
- Otherwise → go to **Step 2 (Create)**. If a non-merged PR already exists, note that in the plan and offer to update it rather than create a new one.

---

## Step 2: Create — Draft, Approve, Execute

Gather the change:

```bash
git status --porcelain
git log "$default_branch"..HEAD --format="%h %s"
git diff "$default_branch"...HEAD --stat
git diff "$default_branch"...HEAD
git diff HEAD
```

Read the full content of any non-trivial files in the diff so your descriptions are accurate.

Draft these yourself:

- **Issue title** (≤70 chars, imperative mood, no trailing period).
- **Issue body** (2-4 sentences describing the problem or need).
- **PR title** (≤70 chars).
- **PR body**: starts with `Closes #<N>` (placeholder until the issue is created), then a Summary (bullets) and Test plan (checklist).
- **Branch name** (kebab-case, prefixed `fix/`, `feat/`, `chore/`, `docs/`, or `refactor/`) — only if currently on the default branch.
- **Commit message** (imperative, ≤72 chars) — only if there are uncommitted changes.

Present the plan:

```
## Ship Plan

**On**: `<current_branch>` → `<default_branch>` on `<repo>`

### Actions

- [<x or space>] Commit: `<commit message>`          (skip if nothing uncommitted)
- [<x or space>] Create branch: `<branch name>`      (skip if already on a feature branch)
- [<x or space>] Push to origin
- [ ] Create issue
- [ ] Create PR linking to the issue

### Issue

**Title**: <title>
**Body**:
> <body>

### Pull Request

**Title**: <title>
**Body**:
> Closes #<N>
>
> ## Summary
> <bullets>
>
> ## Test plan
> <checklist>
```

Call `ExitPlanMode`, then ask:

> **Ship it?** (e.g., "go", "shorten the title", "rewrite the body")

After approval, execute in order. If any step fails, stop and report.

1. Commit if needed:
   ```bash
   git add -A && git commit -m "<commit message>"
   ```
   Never use `--no-verify`.

2. Create a feature branch if currently on `$default_branch`:
   ```bash
   git checkout -b "<branch name>"
   ```

3. Push:
   ```bash
   git push -u origin HEAD
   ```

4. Create the issue and capture the number:
   ```bash
   issue_url=$(gh issue create --title "<title>" --body "$(cat <<'EOF'
   <issue body>
   EOF
   )")
   issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')
   ```

5. Create the PR. Build the body with `Closes #$issue_number` interpolated into the first line, but use a quoted heredoc (`<<'EOF'`) for the rest so that any `$`, backtick, or `$(...)` sequences inside the bullets or checklist are treated as literal text (no shell substitution):
   ```bash
   pr_body=$(printf 'Closes #%s\n\n' "$issue_number"; cat <<'EOF'
   ## Summary
   <bullets>

   ## Test plan
   <checklist>
   EOF
   )
   printf '%s\n' "$pr_body" | gh pr create --base "$default_branch" --title "<pr title>" --body-file -
   ```

6. Report:
   > **Shipped.**
   > - Issue: `<issue_url>`
   > - PR: `<pr_url>`
   >
   > Merge the PR on GitHub when ready, then run `/github-ship` again to clean up.

---

## Step 3: Cleanup — Verify, Approve, Execute

Verify the state:

```bash
git status --porcelain    # must be clean
gh pr view --json number,state,mergedAt,headRefName,url 2>/dev/null
```

If the working tree is dirty, stop: `Commit or stash your changes before cleanup.`

Present the cleanup plan:

```
## Ship Cleanup

**PR**: #<N> merged (<url>)
**Branch**: `<current_branch>`

### Actions

1. Checkout `<default_branch>`
2. `git pull --ff-only`
3. Delete local branch `<current_branch>`
4. Delete remote branch `<current_branch>` (if it still exists)
```

Call `ExitPlanMode`, then ask:

> **Clean up?** ("go" / "no")

After approval:

```bash
git checkout "$default_branch"
git pull --ff-only
```

Try the safe local delete. Capture the exit code — do NOT proceed to remote delete unless local delete succeeded or the user explicitly approves the force-delete:

```bash
if git branch -d "$current_branch" 2>&1; then
  local_deleted=yes
else
  local_deleted=no
fi
```

If `local_deleted=no` (normal for squash-merged or rebase-merged PRs), ask inline:

> Local branch has commits not on `<default>`. This is normal for squash/rebase merges. Force-delete? (yes/no)

If the user answers yes:
```bash
git branch -D "$current_branch" && local_deleted=yes
```

If the user answers no, stop here — do NOT delete the remote branch. The user can rerun the skill after sorting the branch out, or delete it manually.

Only after `local_deleted=yes`, delete the remote branch if it still exists:
```bash
if [ "$local_deleted" = "yes" ] && git ls-remote --heads origin "$current_branch" | grep -q .; then
  git push origin --delete "$current_branch"
fi
```

Report:
> **Cleaned up.** On `<default_branch>` at `<sha>`. Branch `<current_branch>` removed.
