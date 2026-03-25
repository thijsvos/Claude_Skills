# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/thijsvos/Claude_Skills/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/thijsvos/Claude_Skills/releases/tag/v0.0.1
