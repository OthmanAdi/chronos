# Contributing

## Adding a platform port

To add chronos support for a new agent platform:

1. Create `installers/<platform>/README.md` describing the platform's hook or plugin API
2. Write the context injection: SessionStart must emit `now_utc`, `now_local`, `tz`, `ledger`, `state`, `session`
3. Write per-turn injection: UserPromptSubmit must emit `turn`, `session_duration`, `since_last_user`
4. Write the ledger writer: PreToolUse appends `started_at`, PostToolUse appends `finished_at + duration_ms + success`
5. If the platform has no hook API, add a `SKILL-only` entry to the platform matrix in README.md with degraded mode instructions
6. Test with a pre-existing hook in the config (verify the installer does not clobber it)

## Reporting a bug

Open an issue with:
- Platform and version (Claude Code 1.x, Codex CLI x.y, etc.)
- Shell (bash, zsh, PowerShell version)
- What you ran and what you expected
- The relevant ledger output if available (`tail ~/.chronos/ledger-*.jsonl`)

## Pull request rules

- No new runtime dependencies. bash, PowerShell, and optionally jq are the only allowed tools.
- All script changes must work on both bash and PowerShell (add `.ps1` counterpart for any new `.sh` script)
- Run the installer with a pre-existing hook in `~/.claude/settings.json` and confirm it is preserved
- Keep SKILL.md under 500 lines
- No Co-Authored-By in commits
