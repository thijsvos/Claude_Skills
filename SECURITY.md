# Security Policy

## Understanding the Trust Model

Claude Code skills are prompt-based extensions that can request access to powerful tools — including shell commands, file reads/writes, and web access. A malicious or poorly written skill could:

- Read or modify files on your system
- Execute arbitrary shell commands
- Exfiltrate data via network requests

**Users should review any skill's `SKILL.md` before installing it**, paying particular attention to the `allowed-tools` field and the prompt content.

## Reporting a Vulnerability

If you discover a security issue in a skill (e.g., a skill that exfiltrates data, executes unintended commands, or requests excessive permissions), please report it responsibly:

1. **Do not open a public issue.** Security vulnerabilities should be reported privately.
2. **Use [GitHub Security Advisories](https://github.com/thijsvos/Claude_Skills/security/advisories/new)** to report the issue privately.

You should receive an acknowledgment within 48 hours and a resolution timeline within 7 days.

## What Counts as a Security Issue

- A skill requesting more permissions than it needs (`allowed-tools` is too broad)
- A skill prompt that could cause data exfiltration or destructive actions
- A skill that bypasses Claude Code's safety boundaries
- The `install.sh` script overwriting files without proper backup/warning

## Scope

This policy covers the skills, install script, and linter in this repository. It does not cover Claude Code itself — for Claude Code security issues, refer to [Anthropic's security page](https://www.anthropic.com/security).
