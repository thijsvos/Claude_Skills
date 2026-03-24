# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- CONTRIBUTING.md with guidelines for creating and submitting skills
- SECURITY.md with trust model and vulnerability reporting process
- GitHub Actions CI workflow to run the skill linter on push and PR
- Issue templates for bug reports and skill requests
- Pull request template with submission checklist
- CHANGELOG.md (this file)
- .editorconfig for consistent formatting

### Changed
- README.md: added badges, usage example, contributing section, and support info
- .gitignore: added defensive entries for .env, logs, node_modules, and __pycache__

## [1.0.0] - 2025-03-25

### Added
- `github-audit` skill: audits GitHub repositories against best practices
- Skill Quality Kit: CLAUDE.md specification, starter templates, and lint.sh validator
- `enhance` skill: deep multi-phase project analysis with install script
