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
