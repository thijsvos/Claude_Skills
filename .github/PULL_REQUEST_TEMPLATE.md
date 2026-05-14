## Summary

<!-- What does this PR do? If it adds a new skill, describe what the skill does. -->

## Checklist

- [ ] `./lint.sh` passes with no errors
- [ ] Skill `name` field matches directory name
- [ ] `description` ends with a period and is verb-first
- [ ] `description` in SKILL.md frontmatter matches README line 3 AND the root README table cell verbatim
- [ ] `README.md` has all required sections (What It Does, Requirements, Usage, Configuration, Safety if applicable)
- [ ] Configuration table has rows for `Model`, `Effort`, `Takes argument`, `Allowed tools`
- [ ] `Allowed tools` row matches the SKILL.md `allowed-tools` frontmatter exactly
- [ ] Usage examples invoke `/<skill-name>` (not a stale name or another command)
- [ ] If the skill uses `Agent` + Explore subagents: canonical IMPORTANT subagent block is present in the body
- [ ] If `EnterPlanMode` is declared in `allowed-tools`: `ExitPlanMode` is paired in both frontmatter and body
- [ ] Skills table in root `README.md` is updated (if adding/removing a skill)
- [ ] `CHANGELOG.md` is updated under `## [Unreleased]`
