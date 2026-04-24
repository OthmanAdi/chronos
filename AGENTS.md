# chronos — Time Awareness (AGENTS.md mirror)

This file mirrors SKILL.md for agents that load `AGENTS.md` instead of or in addition to skills (Codex, ADAL, OpenClaw, Hermes, PI-mono).

See `SKILL.md` for the full spec. Quick reference below.

## You have a ledger (or you don't)

If hooks are installed on your platform (Claude Code, Codex, OpenCode-plugin), you'll see `chronos baseline` in your context at session start with:
- `now_utc`, `now_local`, `tz`, `ledger` path, `state` path, `session` id

On every user turn:
- `now_utc`, `turn`, `session_duration`, `since_last_user`

Tool-use ledger at `ledger` path is JSONL — one line per event:
- PreToolUse: `{tool_use_id, tool, args_hash, started_at, started_epoch}`
- PostToolUse: `{tool_use_id, tool, finished_at, finished_epoch, duration_ms, success}`

If not installed: use `date -u` + `stat -c %Y` as fallback. State it explicitly.

## 7 triggers — when to consult time

1. **Retry check.** Same tool + args_hash failed < 60s ago → change strategy. 10min+ → re-run ok.
2. **Staleness check.** git/processes > 5min, files > 1h or modified-since, memory > 7 days, API > 5min.
3. **Progress verbosity.** < 5min terse, 5–30min paragraph, > 30min structured recap.
4. **Long-command degradation.** Last 3 durations growing? Surface, don't wait silently.
5. **Idle-loop.** `since_last_user > 15min` in autonomous mode → pause, summarize, ask.
6. **No vague time.** Replace "just now" / "a moment" with concrete delta from ledger.
7. **Date questions.** Read SessionStart baseline if fresh, else `date -u`.

## Read the ledger

```bash
# last 10 min of events
scripts/ledger_read.sh --since 10m

# last 3 Bash runs
scripts/ledger_read.sh --tool Bash | tail -n 6

# specific args_hash
scripts/ledger_read.sh --tool Bash --args-hash abc123 --last
```

## Failure modes

- Don't count turns for elapsed time — use wall clock.
- Don't trust your own "just now" from earlier in context.
- Don't hang silently in autonomous mode.
- If no ledger: say so, use shell fallback.

See `SKILL.md` for full detail.
