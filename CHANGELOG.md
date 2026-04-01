# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `refactor` skill: comprehensive refactoring across correctness, security, performance, and maintainability with behavior-preserving, incremental changes
- `diagnose` skill (renamed from `debug` to avoid conflict with built-in Claude Code command): multi-agent root cause analysis that traces errors, correlates with recent changes, and identifies fixes with ranked hypotheses

## [0.0.4] - 2026-03-29

### Added
- `dep-check` skill: scans all dependency declarations across ecosystems for updates and vulnerabilities, produces a prioritized update plan with testing recommendations

## [0.0.3] - 2026-03-26

### Added
- `code-review` skill: structured multi-dimensional code review with prioritized findings and fix offers
- `test-gen` skill: comprehensive test generation with deep code analysis, convention detection, and edge case coverage

## [0.0.2] - 2026-03-25

### Added
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- Dependabot configuration for GitHub Actions updates
- Release automation workflow: auto-creates GitHub Releases from CHANGELOG when a version tag is pushed

### Changed
- Updated `actions/checkout` to v6 across all workflows
- Removed dangling email reference from SECURITY.md
- Fixed misleading "discussion" link in CONTRIBUTING.md

## [0.0.1] - 2026-03-25

### Added
- `enhance` skill: deep multi-phase project analysis with install script
- `github-audit` skill: audits GitHub repositories against best practices
- Skill Quality Kit: CLAUDE.md specification, starter templates, and lint.sh validator
- CONTRIBUTING.md with guidelines for creating and submitting skills
- SECURITY.md with trust model and vulnerability reporting process
- GitHub Actions CI workflow to run the skill linter on push and PR
- Issue templates for bug reports and skill requests
- Pull request template with submission checklist
- CHANGELOG.md
- .editorconfig for consistent formatting
- README.md with badges, usage example, contributing section, and support info
- .gitignore with defensive entries for .env, logs, node_modules, and __pycache__

[Unreleased]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.4...HEAD
[0.0.4]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/thijsvos/Claude_Skills/releases/tag/v0.0.1
