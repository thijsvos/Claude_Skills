---
name: docstring-check
description: Scans a codebase for missing, outdated, drifted, or inconsistent docstrings and applies behavior-preserving fixes matching the project's detected convention.
allowed-tools: Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, TaskCreate, TaskUpdate, EnterPlanMode, ExitPlanMode
model: opus
effort: max
takes-arg: true
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a comprehensive docstring audit and — after user approval — applying convention-matching fixes. Scan the target code for three classes of problem in parallel: missing docstrings on public API, signature-vs-docstring drift, and style/convention inconsistency. Synthesize a prioritized fix plan, apply changes incrementally, and verify with the project's existing linter or doc-build tool.

**ARGUMENTS:** The user may provide an optional target argument — a file path, directory, function/class name, branch name, commit range, or natural language description of what to audit. If no argument is provided, default to a full-codebase scan (asking the user to narrow the scope if the repo is large).

**IMPORTANT:** Always quote the user-supplied argument in double quotes when passing it to shell commands.

---

## Step 1: Resolve Scope and Detect Project Context

Determine what code to audit based on the argument and project state.

**If an argument was provided**, resolve it in this order:

1. **File path** — if the path exists on disk as a file, audit that file:
   ```bash
   test -f "<path>" && echo "file"
   ```
   Read the file in full and identify all documentable symbols (functions, methods, classes, modules, exported constants).

2. **Directory path** — if the path is a directory, find all source files in it:
   ```bash
   test -d "<path>" && echo "directory"
   ```
   Find source files (exclude test files, node_modules, vendor, build artifacts, generated code):
   ```bash
   find "<path>" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.rs' -o -name '*.java' -o -name '*.kt' -o -name '*.swift' -o -name '*.php' -o -name '*.cs' \) ! -path '*/node_modules/*' ! -path '*/vendor/*' ! -path '*/__pycache__/*' ! -path '*/dist/*' ! -path '*/build/*' ! -path '*/target/*' ! -path '*/.venv/*' ! -path '*/venv/*' ! -name '*.test.*' ! -name '*.spec.*' ! -name '*_test.*' ! -name 'test_*.py' | head -50
   ```
   If the directory contains more than 30 source files, list a summary by language and ask the user to narrow the scope or confirm they want to proceed (up to 50 files maximum).

3. **Function, class, or method name** — if the argument is not a valid path, search the codebase for it:
   ```bash
   grep -rn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.py' --include='*.go' --include='*.rb' --include='*.rs' --include='*.java' --include='*.kt' --include='*.swift' --include='*.php' --include='*.cs' -E "(function|def|func|class|fn|pub fn|export|interface|struct|enum|trait|impl)\s+<arg>" . 2>/dev/null | grep -v node_modules | grep -v vendor | head -10
   ```
   If found in multiple files, list them and ask the user to confirm which one. Read the full file(s) containing the match.

4. **Git ref** (branch or tag) — if `git rev-parse --verify <arg>` succeeds and it is not a file path, identify files changed on that ref compared to the default branch:
   ```bash
   default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
   [ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
   ```
   ```bash
   git diff "$default_branch"..."<arg>" --name-only --diff-filter=ACMR 2>/dev/null
   ```
   Read those files in full for docstring analysis.

5. **Commit range** — if the argument contains `..`, use it directly:
   ```bash
   git diff "<range>" --name-only --diff-filter=ACMR 2>/dev/null
   ```
   Read those files in full.

6. **Natural language description** — if none of the above match, interpret the argument as a description of a code area (e.g., "the authentication module", "API handlers"). Extract keywords, search the codebase, present found files, and ask the user to confirm scope.

7. If none of the above produce results, inform the user and stop:
   > Could not resolve the argument as a file path, directory, code identifier, git ref, or code area description. Try: `/docstring-check src/auth/handler.ts` (file), `/docstring-check src/utils/` (directory), `/docstring-check handleLogin` (function), `/docstring-check feature-branch` (branch), or `/docstring-check` (full-codebase scan).

**If no argument was provided**, default to a **full-codebase scan**. Enumerate source files:

```bash
find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.rs' -o -name '*.java' -o -name '*.kt' -o -name '*.swift' -o -name '*.php' -o -name '*.cs' \) ! -path './node_modules/*' ! -path './vendor/*' ! -path './__pycache__/*' ! -path './dist/*' ! -path './build/*' ! -path './target/*' ! -path './.venv/*' ! -path './venv/*' ! -path './.git/*' ! -name '*.test.*' ! -name '*.spec.*' ! -name '*_test.*' ! -name 'test_*.py'
```

Also exclude generated files (those starting with a `DO NOT EDIT` banner):
```bash
grep -l -m1 "DO NOT EDIT" <file> 2>/dev/null
```

If the scan returns **more than 50 files**, summarize the breakdown by language (e.g., "127 Python files, 34 TypeScript files, 8 Go files") and use `AskUserQuestion` to ask the user how to narrow the scope. Offer these options:

- **Full scan** — audit all source files (higher cost, complete coverage)
- **Hotspots** — scope to the top 30 most-edited files in the last 12 months:
  ```bash
  git log --format=format: --name-only --since=12.months 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rb|rs|java|kt|swift|php|cs)$' | sort | uniq -c | sort -rn | head -30 | awk '{print $2}'
  ```
- **Changed files only** — scope to files changed on the current branch vs the default branch (same `default_branch` detection as above)
- **Public API only** — scope to only the top-level/exported files (language-dependent: `__init__.py`, `index.ts`, `mod.rs`, `lib.rs`, files without a leading underscore)

**After resolving the scope**, gather project context by reading these files if they exist:

- `CLAUDE.md` — project conventions
- `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`, `pom.xml`, `build.gradle`, `composer.json` — language detection + dependency list
- **Docstring style configuration** (authoritative — if present, use instead of inferring):
  - Python: `[tool.pydocstyle]` or `[tool.ruff.lint.pydocstyle]` in `pyproject.toml`, `.pydocstyle`, `setup.cfg` `[pydocstyle]` section
  - TS/JS: `tsdoc.json` (TSDoc), `.eslintrc*` / `eslint.config.*` with `plugin:jsdoc`
  - Ruby: `.rubocop.yml` `Style/Documentation` / `Style/DocumentationMethod`
  - Java: Checkstyle XML `MissingJavadoc*` rules
- **Doc-build infrastructure** (used for verification in Step 4):
  - `docs/conf.py` (Sphinx), `mkdocs.yml`, `typedoc.json`, `Doxyfile`, `Cargo.toml` → `cargo doc`, `godoc`

**Detect the in-use docstring style** if not explicitly configured. Sample 15–20 existing non-trivial docstrings from the scoped files and classify:

- **Python**: `Args:`/`Returns:` → Google; `Parameters\n----------\n` → NumPy; `:param x:`/`:returns:` → reST/Sphinx; otherwise PEP 257 plain
- **TS/JS**: presence of `@param {Type}` in a TS file → JSDoc-in-TS (discouraged); absence of type tags on TS → TSDoc; typed `@param {Type}` on JS → JSDoc
- **Go**: fixed — godoc expects `// FuncName does …` on exported identifiers
- **Rust**: fixed — `///` for item-level, `//!` for module-level, Markdown body
- **Java**: fixed — `/** … */` with `@param`, `@return`, `@throws`
- **C#**: fixed — `/// <summary>`, `<param name="">`, `<returns>`, `<exception>`
- **Ruby**: `# @param [Type]` → YARD; freeform with `+code+`/`*bold*` → RDoc
- **PHP**: fixed — PHPDoc `/** @param Type $x */`

**Detect available docstring linters** (so Step 2 can delegate mechanical checks):

- Python: `ruff --select D --no-fix`, `pydocstyle`, `interrogate`, `pydoclint`, `darglint`
- TS/JS: `eslint-plugin-jsdoc` (check if in `package.json` deps)
- Go: `go vet`, `staticcheck` (ST1020/ST1021/ST1022), `revive`
- Rust: `#![warn(missing_docs)]` in crate roots; `cargo doc --no-deps 2>&1 | grep warning`
- Java: `javadoc -Xwerror`, Checkstyle
- C#: Roslyn `CS1591` via `dotnet build -warnaserror:CS1591`

For each candidate linter, verify it's actually runnable (`command -v <linter>` or present in project deps). Record the runnable set.

State the resolved scope, file count, detected language(s), detected docstring style, available linters, and detected doc-build tool clearly before proceeding.

---

## Step 2: Multi-Dimensional Docstring Analysis

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The resolved scope (file list) from Step 1
- The detected docstring style (or explicit project configuration)
- The list of runnable linters
- The language(s) present

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

**IMPORTANT:** Instruct each agent to read the **full target files** (not just snippets). Understanding the function body is essential for both drift detection (does the docstring describe what the code actually does?) and proposed-content generation (what should the docstring say?).

Each agent must return findings in this structured format:
- **ID**: agent-local identifier (e.g., A1, B1, C1)
- **File:Line**: exact file path and line number of the symbol
- **Symbol**: the function/class/method/constant name and signature
- **Current docstring**: the existing docstring verbatim, or `"(missing)"`
- **Proposed docstring**: the complete replacement text in the detected project style
- **Rationale**: why this change improves the docstring
- **Confidence**: High / Medium / Low (how certain the agent is this is a real issue)
- **Severity**: Critical / High / Medium / Low

Each agent must also return 2-3 **"Looks Good"** callouts — symbols that are already well-documented and should NOT be changed. This prevents unnecessary rewrites and acknowledges good practice.

---

### Agent 1: Coverage & Presence

Identify symbols that lack docstrings entirely, with emphasis on the public API surface.

**Public API detection (language-specific):**

- **Python**: non-underscore identifiers at module top level (respect `__all__` if defined — symbols in `__all__` are always public; symbols not in `__all__` are internal even if non-underscore)
- **TS/JS**: `export` keyword (named or default); top-level declarations in files re-exported via `index.ts`
- **Go**: identifiers starting with a capital letter at package level
- **Rust**: items with `pub` / `pub(crate)` / `pub(super)` visibility
- **Java/C#**: `public` (also `protected` if the class is extensible)
- **Ruby**: methods outside `private` / `protected` blocks
- **PHP**: methods with `public` visibility; classes without explicit visibility

**Also check:**

- Any runnable linter detected in Step 1 — run it and capture structured output. Parse findings into the agent's format.
- Module-level / file-level / crate-level documentation (Python module docstring, Go package comment, Rust `//!`, TSDoc `@packageDocumentation`).

**Severity assignment:**

- **Critical** — public API symbol with zero docstring
- **High** — public API symbol with a single-line docstring shorter than 10 words
- **Medium** — internal symbol with a complex signature (3+ parameters, or raises/returns non-trivially) and no docstring
- **Low** — internal symbol with a simple signature and no docstring

Skip: test files, generated code, `__init__.py` files that only re-export, trivial getters/setters in some languages if the convention is to skip them. Respect `.gitignore`.

Return findings sorted by severity (Critical first), and 2-3 Looks Good callouts (e.g., "The public API of `src/auth/` is consistently documented at the module level").

---

### Agent 2: Accuracy & Drift

For every function/method that *has* a docstring in the scoped files, verify it still matches the code. This is the agent that catches bugs.

**Drift categories:**

- **Param drift** — documented parameters don't match the actual signature:
  - Renamed (docstring says `user_id`, signature has `uid`)
  - Reordered (docstring lists params in different order than signature)
  - Added (signature has a param not documented)
  - Removed (docstring describes a param that no longer exists)
- **Missing return documentation** — function returns a non-void/non-None value but has no `@returns` / `Returns:` / `:returns:` / `<returns>` section
- **Missing error documentation** — function throws/raises but has no `@throws` / `Raises:` / `:raises:` / `<exception>` — check for `throw`, `raise`, `panic!`, `return Err(...)` in the body
- **Type mismatch** — the docstring-declared type contradicts the actual type annotation (e.g., JSDoc `@param {string}` on a TS function whose signature types it as `number`; Python docstring says `int` but annotation says `str`)
- **Copy-paste rot** — identical docstring on symbols with different signatures. Detect by hashing docstring text and flagging duplicates across different signatures.
- **Stale description** — the docstring describes behavior the code no longer exhibits (e.g., mentions a side effect that has been removed, or references a removed dependency). Only flag at **High confidence**; this is the hardest category and false positives are costly.
- **Example drift** — code examples in docstrings reference APIs that no longer exist (e.g., example imports a removed symbol).

**Severity assignment:**

- **Critical** — param drift on public API (callers will be misled), or type mismatch on public API
- **High** — missing `@returns`/`@throws` on public API, stale description on public API
- **Medium** — drift on internal API, copy-paste rot
- **Low** — example drift, minor wording issues

For each finding, provide the corrected docstring that reflects the current code. Do not speculate about the original author's intent — describe what the code actually does now.

Return findings and 2-3 Looks Good callouts (e.g., "The database layer's docstrings consistently and accurately document thrown exceptions").

---

### Agent 3: Style & Convention Consistency

Flag docstrings that deviate from the project's detected style or lack the informational quality a reader needs.

**Checks:**

- **Style deviation** — files using a different style from the project default (NumPy-style in a Google-style Python project; JSDoc type tags in a TSDoc project; single-line godoc that doesn't start with the identifier name in Go)
- **Intra-docstring inconsistency** — mixed tag conventions within a single docstring (e.g., `Args:` followed by `:returns:` in Python)
- **Under-informative docstrings** — docstrings that merely restate the function name ("does_login: does the login", "get_user: gets a user") without adding information the signature doesn't already convey
- **Formatting violations** (language-specific):
  - Python PEP 257: first line not ending in a period, first line not a complete sentence, no blank line between summary and body for multi-line docstrings, triple single quotes instead of triple double quotes
  - Go: doc comment doesn't start with the identifier name
  - Rust: missing `# Examples`, `# Panics`, `# Errors`, `# Safety` sections where appropriate (e.g., `unsafe fn` should document safety invariants)
  - Javadoc: missing `@param` for documented parameters, `{@link}` pointing to non-existent types
  - TSDoc: use of `@param {type}` (banned — types belong in TS signature)
- **Link rot** — `{@link Foo}`, `[Foo]`, `{@see Foo}` references pointing to symbols that no longer exist in the codebase

**Severity assignment:**

- **High** — style violations that break doc-build (missing required tags in Javadoc/rustdoc that cause `-Xwerror` / `--deny warnings` failures)
- **Medium** — style deviation from project default, under-informative descriptions on public API
- **Low** — intra-docstring inconsistency, formatting nits, under-informative descriptions on internal API

For each finding, provide the rewritten docstring that matches the project's detected style.

Return findings and 2-3 Looks Good callouts (e.g., "All public functions in `src/api/` consistently follow Google-style with Args/Returns/Raises sections").

---

## Step 3: Synthesize Docstring Plan

Collect all findings from the 3 agents and produce a single, prioritized plan.

**Synthesis rules:**

1. **Deduplicate**: if Agent 1 flagged a symbol as missing and Agent 3 flagged the same symbol for style deviation (because a stub was added in a different style), merge into one finding under the Missing category.
2. **Priority order**: Missing on public API (by severity) → Drift (Critical first) → Missing on internal API → Style & Convention → Formatting nits. Within each group, sort by severity then by file path.
3. **Batch by file**: findings in the same file should be listed together in the final report so the user can review them in context.
4. **Assign IDs**: Number findings sequentially across the entire plan: `[D1]`, `[D2]`, `[D3]`, etc. (D for Docstring).
5. **Cap the plan**: If the total findings exceed 50, show the top 50 by priority and note: "X additional findings not shown — rerun `/docstring-check` with a narrower scope to address them."
6. **Be specific**: Every finding must have a file path and line number. Every finding must include the full proposed docstring text.
7. **Omit empty sections**: If a category has no findings, do not include its heading.

**Use this report format:**

```
## Docstring Plan: <target description>

**Scope**: <N files, M documentable symbols inspected> | **Findings**: <X total> (<A missing, B drift, C style>)
**Detected style**: <Google / NumPy / TSDoc / godoc / rustdoc / Javadoc / XML / YARD / PHPDoc / …>
**Linters run**: <list, or "none detected">

### Verification Strategy
<Status: "Linter available — will re-run `<cmd>` after fixes" or "Doc build detected — will run `<cmd>` after fixes" or "No automated verification — user will review via `git diff`.">

---

### Missing Docstrings — Public API (fix first)

| ID | File:Line | Symbol | Severity | Confidence |
|----|-----------|--------|----------|------------|
| [D1] | `src/auth/handler.py:42` | `class AuthHandler` | Critical | High |

**[D1]** `src/auth/handler.py:42` — `class AuthHandler`
**Current**: (missing)
**Proposed**:
\`\`\`python
"""Handle user authentication via OAuth and session tokens.

AuthHandler is the entry point for all login flows. Instances are
stateless and safe to share across requests.
"""
\`\`\`
**Why**: Public class exported from `src/auth/__init__.py`, used in 14 call sites across the codebase. No docstring means IDE hover, `help()`, and generated docs all show nothing.

---

### Signature / Content Drift

| ID | File:Line | Symbol | Severity | Confidence |
|----|-----------|--------|----------|------------|
| [D5] | `src/users.py:88` | `def update_user(uid, **kwargs)` | Critical | High |

**[D5]** `src/users.py:88` — `def update_user(uid, **kwargs)`
**Current**:
\`\`\`
"""Update a user.

Args:
    user_id: The ID of the user to update.
    name: The new name.
"""
\`\`\`
**Proposed**:
\`\`\`
"""Update a user.

Args:
    uid: The ID of the user to update.
    **kwargs: Fields to update. Supported keys: name, email, role.

Returns:
    The updated User object.

Raises:
    UserNotFound: If no user exists with the given uid.
"""
\`\`\`
**Why**: Param `user_id` was renamed to `uid` in commit X (but the docstring wasn't updated), `**kwargs` isn't documented, and the function returns a User and raises UserNotFound — both undocumented.

---

### Missing Docstrings — Internal

(same detail format)

---

### Style & Convention

(same detail format)

---

### Looks Good (do not change)

- <Callout from Agent 1 — well-covered area>
- <Callout from Agent 2 — accurately maintained docstrings>
- <Callout from Agent 3 — consistent style>

---

### Recommendation

<Brief assessment: how many fixes are safe to apply immediately, how many benefit from review, whether public-API-only is a useful first pass, and whether the user should scope the next run narrower if the plan was capped.>
```

After presenting the plan, call `ExitPlanMode`, then ask:

> **Ready to apply these docstring fixes?** (e.g., "apply all", "apply D1 through D10", "apply missing only", "apply public API only", "apply drift only", "skip D7 and D12")

---

## Step 4: Execute Fixes

After the user approves (or modifies) the plan, apply the changes.

**Before making any changes**, capture a backup stash that you can identify reliably later. `git stash push` exits 0 even when there's nothing to stash, so use `git stash create` + `git stash store` to capture an explicit SHA instead:

```bash
backup_sha=$(git stash create "docstring-check-backup: before /docstring-check changes" 2>/dev/null)
if [ -n "$backup_sha" ]; then
  git stash store -m "docstring-check-backup: before /docstring-check changes" "$backup_sha"
fi
```

If `$backup_sha` is non-empty, a backup exists at that SHA — record it so a later "revert all" can use `git stash apply "$backup_sha"` to restore exactly that snapshot. If `$backup_sha` is empty, the working tree was clean — proceed without a backup.

If the repository has uncommitted changes outside the docstring fix scope, warn the user before proceeding.

**Track progress with tasks.** Before applying the first fix, call `TaskCreate` once per file touched by the selected findings (one task per file, batching the findings within that file into the task description). Mark `in_progress` when you begin editing the file and `completed` once all its findings are applied. For large plans (20+ files) this gives the user a real-time view of how many files are left and which one is currently being edited.

**Execution rules:**

1. **Apply in priority order**: Missing on public API (by severity) → Drift → Missing on internal → Style. Within each group, go file-by-file to minimize Edit churn.

2. **Respect the user's selection**:
   - "apply all" — all findings
   - "apply D1 through D10" — by ID range
   - "apply missing only" — filter to the Missing Docstrings sections
   - "apply public API only" — filter to Missing-public-API + Drift findings on public symbols
   - "apply drift only" — filter to the Signature / Content Drift section
   - "skip Dn" / "skip Dn and Dm" — apply everything else

3. **Use `Edit` for modifications**. Match the exact existing docstring text (including delimiters, leading whitespace, and line endings) for the `old_string`. For missing docstrings, the `old_string` is the line containing the symbol declaration, and the `new_string` inserts the docstring on the following line(s) per the language's placement rules (Python: inside the body first; Go/Rust/TSDoc: immediately above the declaration; Javadoc: immediately above).

4. **Preserve indentation**. Docstring indentation must match the surrounding code. For Python class methods inside a class with 4-space indentation, the docstring opening `"""` is indented 8 spaces.

5. **Show each change**: After applying each finding, briefly report:
   > **[D1]** Applied: Added Google-style docstring to `class AuthHandler` (`src/auth/handler.py:42`)

6. **After all changes are applied**, run verification:
   - **If a docstring linter was detected in Step 1**, rerun it on the modified files:
     ```bash
     # Python example
     ruff check --select D <modified_files>
     # Go example
     staticcheck <modified_packages>
     # Rust example
     cargo doc --no-deps 2>&1 | grep warning
     ```
   - **If a doc-build tool was detected**, run it in no-fail-fast mode and capture warnings:
     ```bash
     # Sphinx example
     sphinx-build -b html -W --keep-going docs/ /tmp/docs-build
     # TypeDoc example
     npx typedoc --emit none
     ```

7. **If verification passes:**
   > **All changes applied successfully.** <N> docstring fixes across <M> files. Linter/doc-build reports no new warnings.
   >
   > Run `git diff` to review the changes before committing.

8. **If verification reports regressions**, diagnose the likely cause and present options:
   > **<X> docstring fixes applied, but <Y> verification warnings.** Most likely caused by [D4] (<brief diagnosis, e.g., "the new docstring references a type `Foo` that doesn't exist — was it renamed?">).
   >
   > Options:
   > - "revert D4" — undo just that change
   > - "revert all" — restore to pre-fix state (`git stash apply "$backup_sha"` against the SHA captured before Step 4)
   > - "fix it" — attempt to correct the proposed docstring while preserving the fix intent

9. **If no verification tool is available**, instruct the user:
   > **All changes applied.** No docstring linter or doc-build detected — review with `git diff` before committing. Consider adopting `ruff --select D` / `eslint-plugin-jsdoc` / `staticcheck` / `#![warn(missing_docs)]` to catch future regressions automatically.
