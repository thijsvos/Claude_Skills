---
name: create-skill
description: Interactive skill generator that scaffolds new skills following all project conventions, serving as the definitive reference for skill creation.
allowed-tools: Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, EnterPlanMode, ExitPlanMode
model: opus
effort: max
takes-arg: true
---

Call `EnterPlanMode` immediately before doing anything else.

You are creating a new Claude Code skill for the Claude_Skills collection. Gather requirements, design the skill following every convention documented below, present the plan for approval, and — after user approval — generate the skill files, validate, and install.

**ARGUMENTS:** The user may provide a description of what the new skill should do (e.g., "security audit for C# codebases" or "API documentation generator"). If no argument is provided, ask the user what skill they want to create.

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

---

## Skill Creation Reference

This section is the authoritative specification for creating Claude Code skills in this project. It documents every convention — both the rules defined in `CLAUDE.md` and the patterns observed across all existing skills. Use it as the single source of truth when designing and generating new skills.

Before designing the new skill, read `CLAUDE.md` at the project root to verify these rules are still current. If any rule below conflicts with `CLAUDE.md`, defer to `CLAUDE.md`.

---

### R1: Frontmatter

Every `SKILL.md` must begin with YAML frontmatter between `---` delimiters.

**Required fields** (enforced by `lint.sh`):

| Field | Rule |
|-------|------|
| `name` | Must match the directory name exactly (e.g., `my-skill` for `skills/my-skill/`) |
| `description` | One-line summary of what the skill does, ending with a period |
| `allowed-tools` | Comma-separated list of tools the skill may use |

**Standard fields** (used by every existing skill):

| Field | Value | Note |
|-------|-------|------|
| `model` | `opus` | Resolves to Claude Opus 4.7, the most capable model |
| `effort` | `max` | Maximum reasoning depth |

**Optional fields:**

| Field | Default | When to use |
|-------|---------|-------------|
| `takes-arg` | `false` | Set `true` if the skill accepts a user argument |
| `disable-model-invocation` | `false` | Set `true` to prevent invoking other models (rare — only `enhance` uses this) |

---

### R2: Tool Selection

Follow the **minimal permissions principle** — only request tools the skill actually needs.

**Base set (every skill includes these):**
```
Read, Grep, Glob, Bash, Agent, EnterPlanMode, ExitPlanMode
```

**Add based on capability:**

| Capability needed | Add these tools |
|-------------------|----------------|
| Modify existing files | `Edit` |
| Create new files | `Write` |
| Internet access (web search, API lookups) | `WebSearch, WebFetch` |
| Ask the user questions during execution | `AskUserQuestion` |

**Decision tree:**
- Does the skill only analyze/report? → Base set only (+ `AskUserQuestion` if it needs to clarify scope)
- Does the skill modify existing files after analysis? → Add `Edit`
- Does the skill create new files? → Add `Write`
- Does the skill need to look up external information? → Add `WebSearch, WebFetch`

---

### R3: Body Structure

The body follows this order after the frontmatter:

1. **Opening instruction** (always the first line):
   ```
   Call `EnterPlanMode` immediately before doing anything else.
   ```

2. **Mission statement** — 1-3 sentences describing what the skill does and its approach.

3. **ARGUMENTS line** (only if `takes-arg: true`):
   ```
   **ARGUMENTS:** The user may provide an optional <description of what the argument can be>. If no argument is provided, <fallback behavior>.
   ```

4. **IMPORTANT: Quoting** (only if `takes-arg: true`):
   ```
   **IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.
   ```

5. **`---` separator**

6. **Steps** — numbered `## Step N: <Title>`, separated by `---` horizontal rules.

**Standard step flow** (adapt as needed):

| Step | Purpose | Pattern |
|------|---------|---------|
| Step 1 | **Resolve scope** | Parse argument via resolution cascade, auto-detect from git, gather project context |
| Step 2 | **Parallel analysis** | Launch 3 Explore subagents, each covering a distinct dimension |
| Step 3 | **Synthesize report** | Deduplicate, prioritize, format structured report. Call `ExitPlanMode`, ask action question |
| Step 4 | **Execute** | Apply changes after user approval, verify results |

Not every skill needs all 4 steps. Analysis-only skills may have 3 steps. Skills with verification may have 5.

---

### R4: Subagents

Skills that perform multi-dimensional analysis launch **exactly 3 Explore subagents in parallel**.

**Configuration (mandatory):**
```
subagent_type: "Explore"
model: "opus"
```

- `"Explore"` agents are **read-only** — Edit and Write are denied at the agent level. This is the safety mechanism that prevents analysis agents from modifying the project.
- `model: "opus"` overrides the Explore agent's default (Haiku) to use **Opus 4.7**, the most capable model, ensuring thorough deep analysis.
- **Never** use `subagent_type: "general-purpose"` during analysis phases.

**Required IMPORTANT block** (include verbatim in the analysis step):
```
**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.
```

**Launch boilerplate:**
```
Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- <context item 1>
- <context item 2>
- <context item 3>
```

**Agent naming:** Use `### Agent N: <Title>` as subheadings under the analysis step.

**Full file reading instruction** (include when agents analyze code):
```
**IMPORTANT:** Instruct each agent to read the **full target files** (not just snippets) so they understand the complete code structure, how functions relate to each other, and whether a proposed change would break callers or dependents.
```

**Structured return format:** Every agent must return findings in a defined format. Specify the exact fields for the skill's domain. Common fields:
- **ID**: agent-local identifier (e.g., X1, X2)
- **File**: exact file path and line number
- **Title**: short description (under 80 characters)
- **Description / Rationale**: why this matters
- **Fix / Proposed change**: concrete suggestion with code

**Positive callouts:** Require each agent to return 2-3 things the code does well that should NOT be changed. This prevents over-engineering and acknowledges good practices.

---

### R5: Finding IDs

Each skill uses a **unique single-letter prefix** for its findings:

| Existing | Prefix | Meaning |
|----------|--------|---------|
| code-review | `C`, `W`, `S` | Critical, Warning, Suggestion |
| test-gen | `T` | Test |
| diagnose | `H` | Hypothesis |
| refactor | `R` | Refactoring |

Choose a letter that represents the new skill's domain and is not already taken. IDs are sequential: `[X1]`, `[X2]`, `[X3]`.

**Format in reports:** Always bold bracket notation — `**[X1]**` — followed by backtick `file:line` reference.

---

### R6: Report Format

Every skill defines an explicit markdown template for its final output. Common elements:

**Header line** (pipe-separated bold stats):
```
**Scope**: <description> | **Findings**: <count breakdown>
```

**Sections** separated by `---` horizontal rules.

**Finding detail pattern:**
```
**[X1]** `path/to/file.ext:42` — <Title>
<Description of the issue and why it matters>
**Fix:** <Concrete suggestion or code snippet>
```

**Omit empty sections** — if a category has no findings, don't include its heading.

---

### R7: Plan Mode Flow

Every skill follows this bracket pattern:

```
EnterPlanMode          ← first instruction
  |
  [All analysis: scope resolution, agent launches, report synthesis]
  |
ExitPlanMode           ← after presenting report
  |
  Action offer question ← ask user what to do
  |
  [Execution: apply changes, verify results]
```

Plan mode is the boundary between **read-only analysis** and **write operations**. All file modifications happen AFTER ExitPlanMode and AFTER user approval.

**ExitPlanMode placement:** Call it after presenting the full report, before the action offer question:
```
After presenting the <report/plan>, call `ExitPlanMode`, then ask:

> **<Action question>?** (e.g., "<example 1>", "<example 2>")
```

---

### R8: Action Offer

After exiting plan mode, ask the user what to do. The question must be:
- **Bold** formatted
- Include **example responses** in parentheses
- Reference the skill's **finding IDs** in examples

**Pattern:**
```
> **<Verb> <object>?** (e.g., "<example with finding IDs>", "<another example>")
```

**Conditional skip:** If the analysis found nothing actionable, skip the action offer and state that clearly.

---

### R9: Argument Resolution Cascade

Skills with `takes-arg: true` resolve the argument in a priority order. The standard cascade:

1. **File path** — `test -f "<arg>"`
2. **Directory path** — `test -d "<arg>"`
3. **Code identifier** (function/class name) — grep for it
4. **Git ref** (branch/tag) — `git rev-parse --verify "<arg>"`
5. **Commit range** — if argument contains `..`
6. **Natural language** — interpret as description, search, confirm with user
7. **Failure message** — inform user with usage examples

**Auto-detection fallback** (when no argument given):
```
1. Staged changes:   git diff --cached --name-only --diff-filter=ACMR
2. Unstaged changes:  git diff --name-only --diff-filter=ACMR
3. Branch diff:      git diff "$default_branch"...HEAD --name-only --diff-filter=ACMR
4. Nothing found:    inform user and stop
```

**Default branch detection snippet** (used by all skills with auto-detect):
```bash
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
[ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
```

Not every resolution step is needed for every skill. Include only the steps relevant to the skill's domain.

---

### R10: Synthesis Rules

When combining findings from multiple agents, the synthesis step must follow these rules:

1. **Deduplicate** — merge findings from different agents that flag the same code
2. **Prioritize** — sort by severity/impact, highest first
3. **Be specific** — every finding must have a file path and line number
4. **Be actionable** — every finding must include a concrete fix or change
5. **Omit empty sections** — don't include headings for categories with no findings

---

### R11: README Sections

Every skill's `README.md` must contain these sections **in this order**:

1. **Title** — `# <Skill Name>` followed by a one-line description
2. **What It Does** — describe the workflow and phases
3. **Requirements** — model access, dependencies, prerequisites
4. **Usage** — how to invoke (e.g., `/<skill-name>` or `/<skill-name> <argument>`)
5. **Configuration** — table of frontmatter settings (Model, Effort, Takes argument, Allowed tools)
6. **Safety** — bullet points with bold labels describing what the skill can and cannot do

The **Safety** section uses this pattern:
```
- **<Bold label>**: <description>
```

Common safety bullets:
- **Read-only analysis**: All analysis agents use the Explore subagent type, which cannot modify files
- **User approval gate**: No code is modified until the user reviews and approves
- **No commits or pushes**: The skill never commits, pushes, or publishes

---

### R12: Post-Execution Patterns

After applying changes:

- **Test verification**: If the project has a test runner, run it after changes and report results
- **Rollback support**: If tests fail, offer to revert (e.g., `git stash pop` or `git checkout -- <files>`)
- **Change reporting**: After each applied change, state what was done:
  ```
  > **[X1]** Applied: <description> (`file:line`)
  ```
- **Summary**: After all changes, summarize the total applied

---

### R13: Project Integration

After creating a new skill, these project files must also be updated:

- **Root `README.md`** — add a row to the skills table:
  ```
  | [<name>](skills/<name>/) | <description> | Opus | Max |
  ```
  And add a usage example in the Quick Start section.

- **`CHANGELOG.md`** — add an entry under `[Unreleased]`:
  ```
  ### Added
  - `<name>` skill: <description>
  ```

- **Validation** — run `./lint.sh <name>` to verify the skill passes all checks.
- **Installation** — run `./install.sh <name>` to create the symlink from `~/.claude/skills/<name>`.

---

## Step 1: Gather Requirements

If no argument was provided, ask the user what skill they want to create using `AskUserQuestion`.

If an argument was provided, parse it as a description of the desired skill's purpose.

Then ask the user the following questions (skip any that are already answered by the argument):

1. **Name** — What should the skill be called? Suggest a name following the existing pattern (lowercase, hyphenated, concise). The name must be unique among existing skills.

2. **Argument** — Does the skill accept a user argument? If so, what kinds of input? (file path, directory, identifier, description, etc.)

3. **Capability** — Does the skill:
   - Only analyze and report? (read-only)
   - Modify existing files? (needs Edit)
   - Create new files? (needs Write)
   - Need internet access? (needs WebSearch, WebFetch)

4. **Workflow** — What is the core workflow? What are the analysis dimensions? Skills typically analyze through 2-3 complementary lenses — what are the right lenses for this skill?

5. **Output** — What does the final report look like? What finding ID prefix should be used?

Read the existing skills directory to check for name conflicts:
```bash
ls skills/
```

State the gathered requirements clearly before proceeding.

---

## Step 2: Design the Skill

Based on the requirements from Step 1, design the complete skill. Read 1-2 existing skills that are closest in nature to the new skill for structural inspiration.

**Design decisions to make:**

1. **Allowed tools** — assemble from the base set + capability additions per R2.

2. **Argument resolution** — which steps from the R9 cascade are relevant? Design the resolution logic.

3. **Agent structure** — define the 3 analysis agents per R4:
   - What dimension does each agent cover?
   - What specific checklist items does each agent evaluate?
   - What structured format does each agent return?
   - What positive callouts should each agent provide?

4. **Finding IDs** — choose an unused letter prefix per R5.

5. **Report format** — design the markdown template per R6:
   - What sections does the report have?
   - What table columns are needed?
   - What detail format for each finding?

6. **Action offer** — design the post-report question per R8:
   - What verb? (fix, apply, generate, implement)
   - What example responses?
   - What conditional skip logic?

7. **Post-execution** — what happens after changes are applied per R12?

Present the complete design as a structured summary before proceeding to Step 3.

---

## Step 3: Present the Plan

Generate the full content of both files and present them for review:

1. **SKILL.md** — complete frontmatter + body following all conventions from the reference above
2. **README.md** — all 6 sections per R11

Also show the planned changes to:
3. **Root README.md** — the new skills table row and usage example
4. **CHANGELOG.md** — the new Unreleased entry

After presenting the full plan, call `ExitPlanMode`, then ask:

> **Ready to create this skill?** (e.g., "yes", "change the name to X", "add Y to agent 2", "use a different finding prefix")

---

## Step 4: Generate, Validate, and Install

After the user approves the plan, execute in this order:

1. **Create the skill directory:**
   ```bash
   mkdir -p skills/<name>
   ```

2. **Write the SKILL.md** using the Write tool.

3. **Write the README.md** using the Write tool.

4. **Update root README.md** using the Edit tool — add the skills table row and usage example.

5. **Update CHANGELOG.md** using the Edit tool — add the entry under `[Unreleased]`.

6. **Validate:**
   ```bash
   ./lint.sh <name>
   ```
   If any check fails, fix the issue and re-run.

7. **Validate all skills** (no regressions):
   ```bash
   ./lint.sh
   ```

8. **Install:**
   ```bash
   ./install.sh <name>
   ```

9. **Report success:**
   > **Skill created and installed.** `/<name>` is ready to use.
   >
   > Files created:
   > - `skills/<name>/SKILL.md`
   > - `skills/<name>/README.md`
   >
   > Files updated:
   > - `README.md` (skills table)
   > - `CHANGELOG.md` (Unreleased section)
   >
   > Run `/<name>` to try it out.
