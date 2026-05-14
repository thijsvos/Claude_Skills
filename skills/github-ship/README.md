# GitHub Ship

Turns local changes into a GitHub issue and linked PR, or cleans up the branch if the PR was already merged. Auto-detects which.

## What It Does

You make changes, run `/github-ship`, approve the proposed issue + PR — the skill creates both. You merge the PR on GitHub yourself. Run `/github-ship` again and, because it now sees a merged PR on the current branch, it switches to cleanup and tears down the feature branch.

One command, no arguments, one mental model.

1. **Pre-flight** — checks git repo, GitHub remote, `gh` auth. Resolves default branch. Looks up any existing PR for the current branch.
2. **Decide** — merged PR exists → cleanup. Otherwise → create.
3. **Create** — reads the diff and commits, drafts issue title/body, PR title/body (with `Closes #N`), commit message (if dirty), branch name (if on default). Shows the plan, asks for approval, then runs commit → branch → push → `gh issue create` → `gh pr create`.
4. **Cleanup** — verifies the PR is merged, checks out default, `git pull --ff-only`, deletes the local and remote feature branches.

## Requirements

- Claude Code with **Opus model** access
- Git repository with a `github.com` remote named `origin`
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)

## Usage

```
/github-ship
```

Typical flow:

```
# 1. Claude Code makes changes in your repo.
# 2. You run:
/github-ship
# Review the proposed issue + PR, approve. The skill creates both.

# 3. You go to GitHub and merge the PR manually.

# 4. Run it again:
/github-ship
# It sees the merged PR, switches to cleanup, and deletes the branch.
```

## Example

Shipping a small fix from a clean working tree on `main`:

```
/github-ship
```

<details>
<summary>Sample flow</summary>

```
## Ship Plan

**On**: `main` → `main` on `thijsvos/myapp`

### Actions

- [x] Commit: `Fix off-by-one in pagination cursor`
- [x] Create branch: `fix/pagination-cursor`
- [x] Push to origin
- [ ] Create issue
- [ ] Create PR linking to the issue

### Issue
**Title**: Fix off-by-one in pagination cursor
**Body**: The cursor advance in `paginate.ts` skips the last item on each page boundary …

### Pull Request
**Title**: Fix off-by-one in pagination cursor
**Body**:
> Closes #42
>
> ## Summary
> - Cursor now advances by `pageSize` instead of `pageSize - 1`.
> …

> **Ship it?** (e.g., "go", "shorten the title")

[After approval]

> **Shipped.**
> - Issue: https://github.com/thijsvos/myapp/issues/42
> - PR:    https://github.com/thijsvos/myapp/pull/43
>
> Merge the PR on GitHub when ready, then run /github-ship again to clean up.
```

</details>

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | No |
| Allowed tools | Read, Grep, Glob, Bash, AskUserQuestion, EnterPlanMode, ExitPlanMode |

No `Edit` or `Write` — all changes run through `git` or `gh`.

## Safety

- **User approval gate**: Nothing runs until you approve the plan via `ExitPlanMode`
- **Manual merge, always**: The skill never calls `gh pr merge`
- **Force-delete confirmation**: Deleting a local branch with unmerged commits (common with squash-merged PRs) requires a second inline confirmation
- **Dirty tree refusal**: Cleanup stops if the working tree has uncommitted changes
- **No hook bypass**: Commits never use `--no-verify`; if a pre-commit hook fails, the skill stops and surfaces the error
