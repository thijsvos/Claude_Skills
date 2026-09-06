---
name: SKILL_NAME
description: Verb-first one-line summary of what the skill does, ending with a period.
allowed-tools: Read, Grep, Glob, Bash, EnterPlanMode, ExitPlanMode
# disallowed-tools: Write, Edit      # Optional: tools removed from the pool while the skill is active
# model: opus                        # Optional: opus, sonnet, haiku, fable, inherit (aliases only — never a full model ID)
# effort: xhigh                      # Optional: low, medium, high, xhigh, max (repo default: xhigh)
# argument-hint: [target]            # Optional: autocomplete hint when the skill accepts an argument
# arguments: [target]                # Optional: declare named positional args usable as $target in the body
# when_to_use: Use when ...          # Optional: extra trigger-phrase guidance for auto-invocation (description + this ≤ 1,536 chars)
# paths: ["src/**", "**/*.py"]       # Optional: glob patterns that auto-activate the skill
# disable-model-invocation: true     # Optional: keep skill strictly user-triggered (does NOT block subagents)
# user-invocable: false              # Optional: hide from `/` menu (background-knowledge skills only)
# context: fork                      # Optional: run in a forked subagent context
# agent: Explore                     # Optional: subagent type when context: fork is set
# background: false                  # Optional: with context: fork, wait for the fork inline (Claude Code 2.1.218+)
# hooks:                             # Optional: skill-scoped hooks (same shape as settings.json hooks, in YAML).
#   PreToolUse:                      #   Registered on invocation and kept for the rest of the session unless
#     - matcher: Bash                #   a handler sets `once: true`. Keep commands inline — ${CLAUDE_SKILL_DIR}
#       hooks:                       #   is NOT expanded here. See skills/github-ship/SKILL.md for a real guard.
#         - type: command
#           command: "..."
# metadata: { team: platform }       # Optional: free-form map, ignored by Claude Code
# license: MIT                       # Optional: informational (Agent Skills spec)
# compatibility: Requires gh CLI     # Optional: environment requirements, ≤ 500 chars (Agent Skills spec)
---

<!-- Skill prompt body. Replace this comment with content. -->
<!--                                                       -->
<!-- Canonical structure:                                  -->
<!-- 1. First line: `Call \`EnterPlanMode\` immediately   -->
<!--    before doing anything else.`                       -->
<!-- 2. 1-3 sentence mission statement                     -->
<!-- 3. If argument-hint declared: ARGUMENTS line +       -->
<!--    quoting note (use $ARGUMENTS / $0 / $name as       -->
<!--    needed)                                            -->
<!-- 4. `---` separator                                    -->
<!-- 5. Numbered steps (`## Step N: <Title>`) separated   -->
<!--    by `---` rules                                     -->
<!-- 6. The LAST step ends with: present report → call    -->
<!--    `ExitPlanMode` → action offer question →         -->
<!--    execute changes (Edit/Write happen here, AFTER    -->
<!--    plan mode exit)                                    -->
<!--                                                       -->
<!-- Subagents: default NO. Only add `Agent, Workflow` to  -->
<!-- allowed-tools and run a Workflow of exactly 3 read-   -->
<!-- only Explore agents (Agent tool as fallback) if the   -->
<!-- skill has THREE genuinely orthogonal analysis lenses. -->
<!-- See `skills/create-skill/SKILL.md` R4 decision gate.  -->
<!--                                                       -->
<!-- Body substitutions: $ARGUMENTS, $0/$1/$N (or          -->
<!-- $ARGUMENTS[N]), $<name>, \$ to escape a literal $,   -->
<!-- ${CLAUDE_SESSION_ID}, ${CLAUDE_EFFORT},               -->
<!-- ${CLAUDE_SKILL_DIR}, ${CLAUDE_PROJECT_DIR}. Use        -->
<!-- `` !`<command>` `` to run a shell command BEFORE      -->
<!-- Claude reads the skill (dynamic context injection).   -->

Call `EnterPlanMode` immediately before doing anything else.

Your mission statement goes here. Describe what Claude should do when this skill is invoked.
