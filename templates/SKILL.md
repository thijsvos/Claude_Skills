---
name: SKILL_NAME
description: Verb-first one-line summary of what the skill does, ending with a period.
allowed-tools: Read, Grep, Glob, Bash, EnterPlanMode, ExitPlanMode
# model: opus                        # Optional: opus, sonnet, haiku
# effort: max                        # Optional: min, low, medium, high, max
# disable-model-invocation: true     # Optional: keep skill strictly user-triggered (does NOT block subagents)
# takes-arg: true                    # Optional: accept an argument from the user
---

<!-- Skill prompt body. Replace this comment with content. -->
<!--                                                       -->
<!-- Canonical structure:                                  -->
<!-- 1. First line: `Call \`EnterPlanMode\` immediately   -->
<!--    before doing anything else.`                       -->
<!-- 2. 1-3 sentence mission statement                     -->
<!-- 3. If takes-arg: ARGUMENTS line + quoting note        -->
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

Call `EnterPlanMode` immediately before doing anything else.

Your mission statement goes here. Describe what Claude should do when this skill is invoked.
