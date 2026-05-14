# Skill Name

One-line description (must match the SKILL.md `description` field verbatim).

## What It Does

Describe the skill's workflow. Standard intro wording:

- For step-numbered skills: *"…, delivered in N steps:"*
- For phase-numbered skills: *"Runs a strategic N-phase analysis…"*

Then list the steps/phases:

1. **Step 1** -- what happens first
2. **Step 2** -- what happens next

## Requirements

- Claude Code with **model** access (if a specific model is required)
- Any other prerequisites

## Usage

```
/skill-name
```

Or if the skill takes an argument:

```
/skill-name <argument description>
```

## Configuration

| Setting | Value |
|---------|-------|
| Model | `default` |
| Effort | `default` |
| Takes argument | No |
| Allowed tools | `Read, Grep, Glob, Bash, EnterPlanMode, ExitPlanMode` |

The `Allowed tools` row must list the SAME tools as the SKILL.md `allowed-tools` frontmatter.

## Safety

<!-- Remove this section if not applicable -->

Describe what the skill can and cannot modify. Note any read-only guarantees or safety mechanisms. Common bullets:

- **Read-only analysis**: …
- **User approval gate**: …
- **No commits or pushes**: …
