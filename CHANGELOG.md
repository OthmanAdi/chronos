# Changelog

## v1.0.0 (2026-04-24)

Initial release.

**Core skill:**
- SKILL.md with 7 temporal decision triggers for AI coding agents
- Staleness thresholds table by source type (git status, file contents, persistent memory, external APIs, build results)
- Degraded mode instructions for platforms without hook support
- `args_hash` documentation for ledger-based retry detection

**Hook stack:**
- SessionStart: injects UTC baseline, timezone, ledger path, session ID
- UserPromptSubmit: per-turn elapsed counters (turn, session_duration, since_last_user)
- PreToolUse: records tool call start to JSONL ledger
- PostToolUse: records tool call finish with duration_ms and success flag
- Stop: idle detection for autonomous agents, configurable threshold

**Platform support:**
- Full hook stack: Claude Code, Codex CLI
- Partial (TS plugin or extension): OpenCode, PI, OpenClaw
- Skill-only degraded mode: Cursor, Hermes, ADAL

**Scripts:**
- bash and PowerShell parity for all 5 hooks plus ledger_read utility
- jq-optional on Windows via PowerShell ConvertFrom-Json fallback
- Ledger self-cleanup: gzip after 1 day, delete after 30 days

**Installer:**
- Non-destructive array concat merge into settings.json (no existing hook clobber)
- Backup before every write
- `--uninstall` flag: removes chronos hooks and skill directory cleanly
- `--dry-run` flag: shows diff without writing
- Project scope (`--project`) and user scope support
