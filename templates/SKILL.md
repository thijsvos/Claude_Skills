---
name: SKILL_NAME
description: Verb-first one-line summary of what the skill does, ending with a period.
allowed-tools: Read, Grep, Glob, Bash, EnterPlanMode, ExitPlanMode
# model: opus                        # Optional: opus, sonnet, haiku, inherit
# effort: max                        # Optional: low, medium, high, xhigh, max
# argument-hint: [target]            # Optional: autocomplete hint when the skill accepts an argument
# arguments: [target]                # Optional: declare named positional args usable as $target in the body
# when_to_use: Use when ...          # Optional: extra trigger-phrase guidance for auto-invocation
# paths: ["src/**", "**/*.py"]       # Optional: glob patterns that auto-activate the skill
# disable-model-invocation: true     # Optional: keep skill strictly user-triggered (does NOT block subagents)
# user-invocable: false              # Optional: hide from `/` menu (background-knowledge skills only)
# context: fork                      # Optional: run in a forked subagent context
# agent: Explore                     # Optional: subagent type when context: fork is set
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
<!-- Subagents: default NO. Only add `Agent` to            -->
<!-- allowed-tools and fan out to 3 Explore agents if the  -->
<!-- skill has THREE genuinely orthogonal analysis lenses. -->
<!-- See `skills/create-skill/SKILL.md` R4 decision gate.  -->
<!--                                                       -->
<!-- Body substitutions: $ARGUMENTS, $0/$1/$N, $<name>,   -->
<!-- ${CLAUDE_SESSION_ID}, ${CLAUDE_EFFORT},               -->
<!-- ${CLAUDE_SKILL_DIR}. Use `` !`<command>` `` to run   -->
<!-- a shell command BEFORE Claude reads the skill         -->
<!-- (dynamic context injection).                          -->

Call `EnterPlanMode` immediately before doing anything else.

Your mission statement goes here. Describe what Claude should do when this skill is invoked.
