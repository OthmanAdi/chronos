---
name: chronos
description: Gives AI coding agents temporal awareness via a hook-backed ledger and decision rules. Activates whenever an agent reasons about recency, retry windows, memory staleness, deploy cooldowns, idle detection, or any "when / how long ago" question. Required for autonomous or long-running agents.
version: 1.0.0
license: MIT
author: OthmanAdi
tags: [time, temporal, autonomy, ledger, agents, hooks, session-management]
homepage: https://github.com/OthmanAdi/chronos
repository: https://github.com/OthmanAdi/chronos
allowed-tools: Read, Bash(date *), Bash(stat *), Bash(cat *), Bash(jq *), Bash(ls *), Bash(git log *), Bash(git status *)
---

# Chronos — Time Awareness for Agents

You are not temporally blind. Stop guessing "when" and "how long ago". You have a ledger. Use it.

## What chronos gives you

When the host platform supports hooks (Claude Code, Codex, OpenCode-plugin), chronos populates three sources of truth:

1. **SessionStart baseline** — injected into your context at session start:
   - `now_utc` — ISO-8601 UTC
   - `now_local` — ISO-8601 with offset
   - `tz` — timezone name + offset
   - `ledger` — absolute path to this session's JSONL tool-use ledger
   - `state` — absolute path to this session's state file
   - `session` — session ID

2. **Per-turn delta** — injected on every user message:
   - `now`, `turn`, `session_duration`, `since_last_user`

3. **Tool-use ledger** — JSONL file, one entry per tool invocation:
   - `{tool_use_id, tool, args_hash, started_at, finished_at, duration_ms, success}`

If the host platform does not support hooks (Cursor, Hermes, ADAL, plain skill-only mode), chronos degrades: run `date -u` or `date -Iseconds` at decision points and state explicitly "derived from shell, not ledger".

## When to consult time — 7 triggers

### 1. Before retrying a failed command

Read the ledger for the same `tool` + `args_hash`.

- If the last failure was `< 60s` ago with the same args, **change strategy** — don't re-run identically.
- If `60s – 10min`, consider one retry with a rationale.
- If `> 10min`, circumstances may have changed; re-run is reasonable.

**Deploy cooldowns**: the same rule applies to deployments and pushes. If the last deploy failed under 60s ago, check logs and fix config before re-deploying. Don't re-trigger a broken pipeline without a changed state.

### 2. Before trusting memory, a cached finding, or a prior read

Staleness thresholds by source:

| Source | Stale after | Action when stale |
|---|---|---|
| `git status`, running processes, env vars | 5 min (same session) | Re-query |
| File contents previously Read | 1 hr OR any write to that path since Read | Re-Read |
| Persistent memory (MemPalace, KG facts) | 7 days since last write | Re-verify before use |
| External API responses (prices, PR status, issues) | 5 min | Re-fetch |
| Build/test results | After any source change since that run | Re-run |
| LLM's own prior claim ("earlier I saw...") | Always verify against ledger | Consult ledger |

### 3. Before reporting progress or writing a summary

Use `session_duration` to pick verbosity:

- `< 5 min` — terse answer, no recap.
- `5 – 30 min` — one-paragraph summary of what changed.
- `> 30 min` — structured recap with timestamped milestones from the ledger.

### 4. Before running a long or destructive command

Scan the ledger for the same `tool` recently. If the last 3 `duration_ms` values for that tool are growing (e.g. each > 2× the previous median), something is degrading. **Surface it**, don't silently wait.

### 5. Idle-loop detection (autonomous mode)

Whenever `since_last_user` exceeds the idle threshold (default 900s / 15 min, configurable via `CHRONOS_IDLE_THRESHOLD_SEC`) and you are still in an autonomous loop: **pause**. Summarize progress, list pending decisions, ask for direction. This prevents silent runaway.

For explicit autonomous loops (`/loop`, `/autonomous`), the threshold may be higher — but always escalate when `session_duration > 2h` without user input.

### 6. Before any "wait" / "in a few minutes" / "just now" statement

Replace imprecise language with a concrete delta from the ledger:

- ❌ "Just tried that."
- ✅ "Last attempt was 47s ago (tool_use_id abc123, failed with EACCES)."

- ❌ "Let's wait a moment."
- ✅ "Retry at 2026-04-23T20:45:00Z (+3 min from now)."

### 7. Date or time questions

Never guess. In order of preference:

1. Read `now_utc` / `now_local` from the SessionStart context if `session_duration < 10 min`.
2. Read latest `finished_at` in the ledger if `< 10 min` ago.
3. Run `date -u +"%Y-%m-%dT%H:%M:%SZ"` fresh.

## How to read the ledger

Ledger path is injected as `ledger: <path>` in SessionStart context.

**One line = one event** (JSONL, append-only). Latest line for a given `tool_use_id` wins.

```bash
# Last 10 events
tail -n 10 "$LEDGER_PATH"

# Events in last 10 minutes (helper script)
./scripts/ledger_read.sh --since 10m

# Events for a specific tool in last hour
./scripts/ledger_read.sh --tool Bash --since 1h

# Last duration for a specific args_hash
./scripts/ledger_read.sh --tool Bash --args-hash abc123 --last
```

Entry shape:

```json
{"tool_use_id":"abc","tool":"Bash","args_hash":"f0e1","started_at":"2026-04-23T20:00:00Z"}
{"tool_use_id":"abc","tool":"Bash","args_hash":"f0e1","finished_at":"2026-04-23T20:00:12Z","duration_ms":12034,"success":true}
```

Two lines per tool call: one on PreToolUse (started_at), one on PostToolUse (finished_at + duration). This is deliberate — async writes avoid adding latency.

`args_hash` is written by the PreToolUse hook: SHA-256 of the serialized tool arguments, first 12 hex characters. Filter the ledger by it to identify identical repeated calls. Do not compute it yourself — read it from the ledger only.

## Failure modes to avoid

- **Do not** re-derive elapsed time by counting messages or turns. Use wall clock from ledger.
- **Do not** trust your own prior claim of "just now" from earlier in context. Ledger is the source of truth.
- **Do not** issue "try again in a few minutes" without a concrete ISO timestamp or delta.
- **Do not** silently hang in autonomous mode. Trigger #5 always applies.
- **Do not** assume the ledger exists. Check for `ledger: ` in your context first; degrade to `date -u` if absent.

## Degraded mode (no hooks platform)

If you don't see `chronos baseline` in your context, the host platform doesn't support hooks. You still follow the decision rules — just swap ledger reads for:

- Current time: `date -u +"%Y-%m-%dT%H:%M:%SZ"` (bash) or `Get-Date -AsUTC -Format o` (pwsh)
- File mtime: `stat -c %Y <path>` (bash) or `(Get-Item <path>).LastWriteTimeUtc` (pwsh)
- Git age: `git log -1 --format=%cI <path>` for last-commit ISO timestamp

State this explicitly: "No ledger on this platform; I'm using `date -u` as fallback."

## Install / wiring

See `installers/<platform>/` for platform-specific setup:

- `claude-code/` — full hook stack (5 events)
- `codex/` — full hook stack (PreToolUse matches Bash only)
- `opencode/` — TS plugin writes ledger; read via `ledger_read.sh`
- `cursor/` — rules-only degraded mode
- `hermes/`, `adal/`, `pi/`, `openclaw/` — SKILL-only ports

## Why this matters

From [arxiv 2510.23853](https://arxiv.org/html/2510.23853) "Your LLM Agents are Temporally Blind" (Oct 2025): even when timestamps are present in context, the best frontier models achieve only 65% alignment with human temporal judgment. Timestamps appear in fewer than 4% of reasoning traces. The fix is not more plumbing — it's explicit decision rules that make the agent **look at the clock at the right moments**.

This SKILL.md is those rules.
