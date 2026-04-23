# Create Skill

Interactive skill generator that scaffolds new skills following all project conventions, serving as the definitive reference for skill creation.

## What It Does

Guides you through creating a new Claude Code skill from scratch, delivered in 4 steps:

1. **Gather Requirements** -- parses a description of the desired skill or asks clarifying questions: name, argument handling, capabilities (read-only vs file modification vs web access), analysis dimensions, and output format
2. **Design the Skill** -- reads existing skills for structural inspiration, then designs the complete skill following every documented and undocumented convention: tool selection, subagent configuration (Opus 4.7, Explore read-only agents), argument resolution cascade, finding IDs, report format, plan mode flow, and action offer
3. **Present the Plan** -- shows the full SKILL.md and README.md content for review before any files are created
4. **Generate, Validate, Install** -- creates the skill directory and files, updates the root README and CHANGELOG, runs the linter to validate, and installs the symlink

The SKILL.md itself contains a comprehensive **Skill Creation Reference** that documents every convention across all existing skills -- both the rules defined in CLAUDE.md and the patterns that have emerged through practice. This makes the skill both a working generator and the definitive guide to skill creation.

## Requirements

- Claude Code with **Opus model** access
- This repository cloned locally (the skill creates files in `skills/` and runs `lint.sh` and `install.sh`)

## Usage

```
/create-skill "security audit for C# codebases"    # Describe what the skill should do
/create-skill "API documentation generator"         # Another example
/create-skill                                       # No argument -- will ask what to create
```

## Configuration

| Setting | Value |
|---------|-------|
| Model | `opus` |
| Effort | `max` |
| Takes argument | Yes (optional: description of the skill to create) |
| Allowed tools | Read, Grep, Glob, Bash, Agent, Edit, Write, AskUserQuestion |

## Safety

- **User approval gate**: No files are created or modified until you review the full SKILL.md and README.md content and explicitly approve
- **Scoped file creation**: Only creates files within the `skills/` directory and updates the root README and CHANGELOG
- **Linter validation**: Runs `lint.sh` after generation to verify the new skill passes all structural checks
- **No commits or pushes**: The skill creates local files only -- it never commits, pushes, or publishes
- **No destructive operations**: The skill only creates new files and appends to existing ones -- it does not delete or overwrite existing skills
