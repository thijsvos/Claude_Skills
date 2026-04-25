---
name: idiom-check
description: Audits a codebase through a programming-language-specific idiom lens, produces a prioritized report, and offers remediation in PR-sized bundles.
allowed-tools: Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion, EnterPlanMode, ExitPlanMode
model: opus
effort: max
---

Call `EnterPlanMode` immediately before doing anything else.

You are performing a comprehensive, language-aware idiom audit on the entire codebase. Detect the primary programming language, examine the source through three orthogonal language-specific lenses simultaneously, synthesize a prioritized report, and — after user approval — ship the remediation as one or more PR-sized bundles, each landed as an independent pull request on GitHub.

This skill takes no argument. The audit always covers the whole repository (with optional narrowing if the codebase is large).

---

## Step 1: Detect Primary Language and Resolve Scope

Determine the primary programming language and gather the source files to audit.

**Detect the primary language** by inspecting manifest files in the repository root:

```bash
ls -1 Cargo.toml go.mod pyproject.toml setup.py setup.cfg package.json tsconfig.json Gemfile pom.xml build.gradle build.gradle.kts composer.json Package.swift 2>/dev/null
find . -maxdepth 3 -type f -name '*.csproj' 2>/dev/null | head -5
```

Map manifests to languages:

| Manifest | Primary language |
|----------|------------------|
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml`, `setup.py`, `setup.cfg` | Python |
| `package.json` + `tsconfig.json` | TypeScript |
| `package.json` (no `tsconfig.json`) | JavaScript |
| `Gemfile` | Ruby |
| `pom.xml`, `build.gradle*` | Java / Kotlin |
| `*.csproj` | C# |
| `Package.swift` | Swift |
| `composer.json` | PHP |

**If multiple manifests are present**, count source files per language to pick the dominant one. Use these extension globs (excluding common vendor/build directories):

```bash
find . -type f \( -name '*.rs' -o -name '*.go' -o -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.rb' -o -name '*.java' -o -name '*.kt' -o -name '*.cs' -o -name '*.swift' -o -name '*.php' \) ! -path '*/node_modules/*' ! -path '*/vendor/*' ! -path '*/target/*' ! -path '*/dist/*' ! -path '*/build/*' ! -path '*/__pycache__/*' ! -path '*/.next/*' ! -path '*/.venv/*' ! -path '*/.git/*' ! -path '*/coverage/*' | sed 's/.*\.//' | sort | uniq -c | sort -rn
```

Pick the language with the most source files. If the top two languages are within ~20% of each other (genuinely polyglot repo), use `AskUserQuestion` to let the user pick the lens.

**Enumerate source files in scope** — non-test, non-vendored source files for the chosen language. For example, for Rust:

```bash
find . -type f -name '*.rs' ! -path '*/target/*' ! -path '*/.git/*' ! -name 'build.rs' ! -path '*/tests/*'
```

Adjust the extensions and exclusions per the chosen language. Always exclude tests, generated code, and vendored / dependency directories.

**Read project conventions** to ground findings in the repo's actual style:

- `CLAUDE.md` — project-specific instructions
- `.editorconfig` — formatting rules
- Language-specific:
  - **Rust**: `clippy.toml`, `rustfmt.toml`, `rust-toolchain*`
  - **Python**: `pyproject.toml` (ruff/black/mypy sections), `.flake8`, `mypy.ini`
  - **TypeScript / JavaScript**: `tsconfig.json`, `biome.json`, `.eslintrc*`, `.prettierrc*`
  - **Go**: `.golangci.yml`, `go.mod` (Go version)
  - **Ruby**: `.rubocop.yml`, `.ruby-version`
  - **Java / Kotlin**: `build.gradle*`, `pom.xml`, `.editorconfig`
  - **C#**: `.editorconfig`, `*.csproj` (TargetFramework, LangVersion)
  - **Swift**: `.swift-version`, `.swiftlint.yml`
  - **PHP**: `composer.json`, `phpcs.xml`, `phpstan.neon`

**Scope narrowing** — if more than 50 source files are in scope, list the top-level subdirectories with file counts and use `AskUserQuestion` to ask the user to narrow the audit (e.g. "audit only `src/`" vs. "audit the whole tree"). This is the only prompt before launching the analysis agents.

State the resolved language (with version if detected), the file count and total lines, the conventions discovered, and the final scope clearly before proceeding to Step 2.

---

## Step 2: Multi-Lens Language-Specific Analysis

Launch **3 Explore subagents in parallel** (`subagent_type: "Explore"`, `model: "opus"`).

Provide each agent with:
- The detected primary language (and version, if known)
- The full list of source files in scope
- The project conventions gathered in Step 1 (CLAUDE.md excerpts, lint/style configs)
- The agent's specific lens (one of the three lenses for the detected language — see the lens matrix below)

**IMPORTANT:** All subagents MUST be launched with `subagent_type: "Explore"` and `model: "opus"` (resolves to Claude Opus 4.7, the most capable model). The Explore agent is read-only by design (Edit and Write are denied at the agent level). This ensures no subagent can accidentally modify the project during analysis. The model override to Opus is required because Explore defaults to Haiku, which lacks the depth needed for this skill's thorough analysis. Never use general-purpose subagents in this skill.

**IMPORTANT:** Instruct each agent to read the **full target files** (not just snippets) so they understand the complete code structure, how functions relate to each other, and whether a proposed change would break callers or dependents.

**Each agent's instructions must include:**

1. **Cap findings at ~12** per agent. Quality over quantity — nit-flooding kills signal. If the agent has more candidates than that, keep only the most consequential ones for this codebase.
2. **Frame every finding as "why in THIS codebase"** — not generic blog advice. Tie each finding to the surrounding code, the project's conventions, the data flow, or the call sites. A finding that could appear verbatim in a tutorial is not a finding.
3. **Return 2-3 mandatory "Looks Good" callouts** — things this codebase already does well in the agent's lens. This grounds the report and prevents over-engineering.

**Each finding must be returned in this structured format:**

- **ID**: agent-local identifier (e.g., O1, T1, F1 for the first agent's findings)
- **File**: exact path and line number(s)
- **Title**: short description, under 80 characters
- **Current pattern**: the code as it stands now, with a code snippet
- **Idiomatic alternative**: the proposed replacement, with a code snippet
- **Why (in this codebase)**: rationale tied to the surrounding code, the conventions, or specific call sites
- **Severity**: High (correctness or safety risk from non-idiomatic pattern), Medium (clarity or maintainability impact), Low (style / preference)
- **Confidence**: High / Medium / Low (how certain the agent is that this is an actual issue)
- **Risk**: Safe (behavior-preserving), Moderate (behavior-preserving but context-dependent), Breaking (intentionally changes behavior for correctness)

---

### Language Lens Matrix

The three lenses are language-specific. Use the row that matches the language detected in Step 1.

#### Rust

- **Lens 1 — Ownership, Borrowing & Lifetimes**: unnecessary `.clone()` and `.to_owned()`, `String` parameters where `&str` or `Cow<'_, str>` fits, premature `RefCell`/`Mutex` where `&mut self` would work, `Rc<T>`/`Arc<T>` introduced before there's actual sharing, lifetime annotations that could be elided, ownership inversion at API boundaries (taking `T` when `&T` suffices), unnecessary `Box<T>` indirection.
- **Lens 2 — Type System & Trait Design**: `?` propagation over `.unwrap()`/`.expect()` outside tests, idiomatic `From`/`Into`/`TryFrom`/`AsRef` usage, `Display` vs `Debug` placement on user-facing types, newtype pattern for invariants and unit safety, trait objects (`dyn Trait`) vs generics, sealed traits via private supertraits, missing `#[non_exhaustive]` on public enums/structs, missing `#[must_use]` on result-like types.
- **Lens 3 — Idioms & Control Flow**: exhaustive `match` over chained `if let`, iterator chains over manual index loops, `?` propagation over nested `match`, `Default` impl over manual zero-init constructors, builder pattern for >3-arg constructors, `NonZero*` / `NonNull` for invariants, `OnceCell`/`LazyLock` over runtime-init globals, `let-else` for early returns.

#### Python

- **Lens 1 — Pythonic Constructs**: comprehensions over manual `for`-append loops, context managers (`with`) over manual `try/finally`, EAFP over LBYL where appropriate, tuple unpacking over indexing, walrus `:=` where it improves clarity, `pathlib.Path` over `os.path` strings, f-strings over `.format()` and `%`, `enumerate`/`zip` over index counters, `any`/`all` over manual flag loops.
- **Lens 2 — Type Hints & Data Modeling**: modern syntax (`X | Y`, `list[T]`, `dict[K, V]`) on Python ≥3.9/3.10, `Protocol` over `ABC` for structural typing, `dataclass`/`Pydantic`/`TypedDict` over plain dicts as records, `Generic[T]` and `TypeVar` correctness, `Optional[T]` vs `T | None` consistency, `Final`/`ClassVar`, `Self` (3.11+), missing return-type annotations on public APIs.
- **Lens 3 — Std Library & Patterns**: `collections` (`Counter`, `defaultdict`, `deque`, `ChainMap`), `functools` (`@cache`, `partial`, `singledispatch`, `reduce`), `itertools` (`chain`, `groupby`, `pairwise`, `batched`), `contextlib` (`@contextmanager`, `ExitStack`, `suppress`), async idioms (`asyncio.gather`, `asyncio.TaskGroup`, `async with`), generators over building intermediate lists.

#### TypeScript / JavaScript

- **Lens 1 — Type System & Inference**: `any` discipline (replace with `unknown` or a real type), narrowing via discriminated unions, `satisfies` operator over `as` assertions, `as const` for literal-narrowed values, generic constraints (`T extends ...`), branded / nominal types for invariants (IDs, units), exhaustive `switch` with `never` fallthrough, avoiding non-null assertions (`!`), type predicates over runtime checks.
- **Lens 2 — Async & Functional Patterns**: `Promise.all`/`Promise.allSettled` over serial `await`, `async/await` over `.then` chains, immutability (spread, `as const`, `readonly`), `map`/`filter`/`reduce` over imperative loops where it improves clarity, optional chaining (`?.`) and nullish coalescing (`??`) over manual null checks, `AbortController` for cancellable operations.
- **Lens 3 — Module Boundaries & Modern Syntax**: ESM imports over CJS where the project supports it, named exports over default, `import type` for type-only imports, structural patterns over inheritance, modern features (`Set`/`Map` over object-as-dict, `structuredClone`, `Object.groupBy`, `Array.prototype.at`), avoiding namespace imports, top-level `await` where supported.

#### Go

- **Lens 1 — Idioms & Error Handling**: error wrapping with `fmt.Errorf("...: %w", err)` and inspection via `errors.Is`/`errors.As`, sentinel vs typed errors used appropriately, `defer` correctness (argument capture vs invocation order), `errgroup.Group` for fan-out with cancellation, returning errors over panics, named return values used sparingly and only when they aid clarity, package naming (lowercase, no underscores).
- **Lens 2 — Concurrency & Channels**: channel direction (`chan<-`/`<-chan`) in function signatures, `context.Context` propagation as first parameter, `sync.Once` / `sync.Map` for the right shape of problem, goroutine leak risks (missing `select` on `ctx.Done()`), mutex granularity (`sync.RWMutex` where reads dominate), `select` patterns with timeouts, `sync.WaitGroup` correctness.
- **Lens 3 — Interface Design & Composition**: small interfaces (accept-interfaces, return-structs), embedding over inheritance, type assertions with comma-ok form, generics (Go 1.18+) used only for genuinely generic code (not as a Java-style cure-all), receiver naming (single-letter, consistent across methods), package-private types where the API doesn't require export.

#### Ruby

- **Lens 1 — Object Design & Duck Typing**: `Module` vs `Class` (mixins for behavior, classes for things), `attr_reader`/`attr_writer`/`attr_accessor` over manual accessors, `Struct`/`Data` for value types, `Comparable`/`Enumerable` inclusion to inherit batteries, `# frozen_string_literal: true` magic comment, refinements over global monkey-patching.
- **Lens 2 — Blocks, Procs & Enumerable**: `yield` vs `&block` parameters, lazy enumerables (`.lazy`) for large or infinite sequences, `each` vs `map` vs `reduce` choice, `tap` for side-effecting in a chain, `then` / `yield_self` for piping, avoiding `.each_with_index { |x, i| arr << ... }` in favor of `.map.with_index`.
- **Lens 3 — Metaprogramming Restraint & Style**: `define_method` only when the method shape genuinely varies, `method_missing` paired with `respond_to_missing?`, `class << self` over repeated `self.` prefixes, `Symbol#to_proc` (`&:method`) over `{ |x| x.method }`, keyword arguments over option hashes, hash shorthand syntax (Ruby 3.1+), avoiding clever metaprogramming where plain code reads better.

#### Java / Kotlin / C# / Swift / PHP (generic template)

For languages without an explicit matrix above, instruct the three lenses as:

- **Lens 1 — Type System & Null Safety**: non-null annotations / non-optional types, sealed interfaces / sealed classes, records / data classes, generics correctness, optional types over null sentinels, immutability where the language supports it.
- **Lens 2 — Idiomatic Patterns**: collection / stream / sequence operations over manual loops, builder patterns for complex construction, modern equality / hashing / `toString`, pattern matching where supported, language-specific resource management (`try-with-resources`, `using`, `defer`, `Disposable`).
- **Lens 3 — Modern Language Features**: switch expressions / pattern matching, sealed interfaces, records / data classes, primary constructors, `var` / `val` inference, extension methods / extension functions, modern null-safe operators, structured concurrency primitives where applicable.

In your prompt to each agent, explicitly include:
- The language name and detected version
- Which of the three lenses the agent is responsible for (with the bullet list of focus areas)
- The list of files in scope
- The conventions discovered in Step 1
- The required structured return format
- The cap of ~12 findings
- The "why in THIS codebase" framing requirement
- The mandatory 2-3 "Looks Good" callouts

---

## Step 3: Synthesize Severity-Sorted Report

Collect all findings from the 3 agents and produce a single, prioritized report.

**Synthesis rules:**

1. **Deduplicate**: if two agents flagged the same line or function for related reasons, merge into one finding with combined context. Note all applicable lenses on the merged finding.
2. **Prioritize**: sort by severity (High > Medium > Low). Within each severity, sort by confidence (High > Medium > Low).
3. **Be specific**: every finding must have a file path and line number. No hand-waving.
4. **Be actionable**: every finding must include both the current code snippet and the idiomatic replacement. No "consider improving" without showing what to do.
5. **Frame "why in THIS codebase"**: every finding's rationale must reference something specific in the surrounding code, conventions, or call sites — not generic best-practice prose.
6. **Omit empty sections**: if there are no High findings, do not include the High heading. Same for Medium and Low.
7. **Looks Good is mandatory**: include 3-5 callouts merged from the agents' "Looks Good" lists. This is non-negotiable per the skill's design.

Assign findings sequential IDs across the entire report: `[I1]`, `[I2]`, `[I3]`, etc.

**Use this report format:**

```
## Idiom Audit: <language> — <scope description>

**Scope**: <N files, M total lines> | **Language**: <name + version if detected>
**Findings**: <X total> (<A high, B medium, C low>)

---

### High

| ID | File:Line | Title | Lens | Confidence | Risk |
|----|-----------|-------|------|------------|------|
| [I1] | `src/foo.rs:42` | <title> | Ownership | High | Safe |

**[I1]** `src/foo.rs:42` — <Title>
**Current**:
```<lang>
<current code>
```
**Idiomatic**:
```<lang>
<replacement code>
```
**Why (in this codebase)**: <rationale tied to surrounding code, conventions, or call sites>

---

### Medium

| ID | File:Line | Title | Lens | Confidence | Risk |
|----|-----------|-------|------|------------|------|

(same per-finding detail format)

---

### Low

| ID | File:Line | Title | Lens | Confidence | Risk |
|----|-----------|-------|------|------------|------|

(same per-finding detail format)

---

### Looks Good (do not change)

- <Strength callout from Lens 1>
- <Strength callout from Lens 2>
- <Strength callout from Lens 3>
```

---

## Step 4: Group Findings into PR-Sized Remediation Bundles

Cluster the findings into tight, mergeable units. Each bundle becomes one pull request.

**Bundling rules:**

- Group by **file proximity** (same file or adjacent modules) and **theme** (same lens, same idiom). A bundle should read as one coherent change.
- Target size: **3-7 findings, 1-3 files, ~30-60 minute review effort**. A single high-impact finding can be its own bundle if the change is large.
- Avoid mixing severities in a single bundle when possible — High-severity bundles get reviewed under more scrutiny than style-only bundles.
- Skip findings that are too risky to bundle automatically (Risk = Breaking). Leave them in the report so the user can decide manually.

**Each bundle has:**

- **ID**: `B1`, `B2`, `B3`, …
- **Title**: imperative, ≤60 chars (this becomes the PR title and commit subject)
- **Theme**: one-line description of the unifying idea
- **Findings**: list of finding IDs covered (e.g., I1, I3, I7)
- **Files**: count + paths
- **Effort**: S (<30 min review) / M (30-60 min) / L (>60 min)
- **Risk**: Safe / Moderate / Breaking
- **Branch name**: `idiom-check/<kebab-slug-of-title>`

**Bundle plan format:**

```
### Remediation Bundles

| ID | Title | Findings | Files | Effort | Risk |
|----|-------|----------|-------|--------|------|
| B1 | Replace clones with borrows in parser | I1, I3, I7 | 2 | M | Safe |
| B2 | Idiomatic error propagation with ? | I2, I5, I9, I12 | 3 | M | Safe |
| B3 | Iterator chains over manual loops | I4, I6 | 1 | S | Safe |

**[B1]** Replace clones with borrows in parser
- Findings: I1, I3, I7
- Files: `src/parser/mod.rs`, `src/parser/tokens.rs`
- Effort: M (~45 min review)
- Risk: Safe — behavior-preserving
- Branch: `idiom-check/replace-clones-with-borrows`

**[B2]** …
```

After presenting the bundle plan, call `ExitPlanMode`, then ask:

> **Apply which bundles?** (e.g., "apply all", "apply B1 and B2", "apply B1 only", "skip — keep the report")

If there are no actionable bundles (e.g., the report is all "Looks Good" with a couple of Low-severity stylistic notes), skip the apply offer and confirm the codebase is in good shape.

---

## Step 5: Apply Selected Bundles (Full Ship)

After the user picks one or more bundles, ship each one as an independent PR. Process bundles in their listed order; each bundle branches off the default branch so the PRs are independent and can be merged in any order.

**Pre-flight checks** — do these once before processing the first bundle:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null || echo "not_a_repo"
git remote get-url origin 2>/dev/null | grep -qE 'github\.com[:/]' || echo "no_github_remote"
gh auth status 2>&1 | grep -q "Logged in" || echo "gh_not_authenticated"
git status --porcelain
```

If the working tree is dirty, stop and ask the user whether to stash (`git stash push -m "idiom-check: pre-bundle stash"`) or abort. If `gh` is not authenticated or the remote is not GitHub, stop with an actionable error.

**Resolve the default branch:**

```bash
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$default_branch" ] && git rev-parse --verify main >/dev/null 2>&1 && default_branch=main
[ -z "$default_branch" ] && git rev-parse --verify master >/dev/null 2>&1 && default_branch=master
```

**Per-bundle workflow** — repeat for each approved bundle:

1. **Start from a clean default branch:**
   ```bash
   git checkout "$default_branch"
   git pull --ff-only origin "$default_branch" 2>/dev/null || true
   git checkout -b "idiom-check/<bundle-slug>"
   ```

2. **Apply each finding's edit** with the `Edit` tool (or `Write` if the bundle introduces a new file). After each edit, briefly state what was applied:
   > **[I1]** Applied: replace `.clone()` with `&` borrow (`src/parser/mod.rs:42`)

3. **Commit** with the bundle title as the subject and the theme + finding IDs in the body. Never use `--no-verify`:
   ```bash
   git add -A
   git commit -m "<bundle title>" -m "$(cat <<'EOF'
   <bundle theme>
   
   Applied findings: I1, I3, I7
   EOF
   )"
   ```

4. **Push the branch:**
   ```bash
   git push -u origin HEAD
   ```

5. **Open the PR** with `gh pr create`:
   ```bash
   gh pr create --base "$default_branch" --title "<bundle title>" --body "$(cat <<'EOF'
   ## Summary
   <bundle theme>

   Generated by `/idiom-check`. Idiomatic improvements:
   - **[I1]** <I1 title> (`file:line`)
   - **[I3]** <I3 title> (`file:line`)
   - **[I7]** <I7 title> (`file:line`)

   ## Test plan
   - [ ] Run the project's test suite
   - [ ] Manual sanity check on the touched modules
   EOF
   )"
   ```

6. **Return to the default branch** before processing the next bundle so each bundle branches independently:
   ```bash
   git checkout "$default_branch"
   ```

**Final report** after every approved bundle has been shipped:

> **Idiom audit applied.** Opened <N> PRs:
> - **[B1]** <B1 title> → <pr_url>
> - **[B2]** <B2 title> → <pr_url>
> - **[B3]** <B3 title> → <pr_url>
>
> Note: when merging these PRs, avoid `gh pr merge --delete-branch` if you stack any of them on top of each other — it closes dependent PRs.
