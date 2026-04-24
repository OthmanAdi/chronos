# chronos — Hermes (NousResearch)

Hermes injects skills from `~/.hermes/skills/` as user messages. No shell hooks — SKILL-only mode.

## Install

```bash
mkdir -p ~/.hermes/skills/chronos
cp SKILL.md ~/.hermes/skills/chronos/SKILL.md
```

Agent will follow decision rules using shell fallback (`date -u`, `stat`).

## What you get

- Decision rules (7 triggers)
- Shell-fallback time queries

## What you don't get

- Automatic ledger (no hooks)
- Per-turn elapsed inject
- Idle warnings
