# chronos — Cursor

Cursor has no hooks. SKILL-only degraded mode via `.cursor/rules/chronos.mdc`.

## Install (project)

```bash
mkdir -p .cursor/rules
cp .cursor/rules/chronos.mdc .cursor/rules/chronos.mdc
```

## Install (user global)

```bash
mkdir -p ~/.cursor/rules
cp .cursor/rules/chronos.mdc ~/.cursor/rules/chronos.mdc
```

Rule has `alwaysApply: true` — agent sees it every chat.

## What you get

- Decision rules always in context
- Instructions to run `date -u` + `stat` for time queries

## What you don't get

No ledger, no per-turn delta, no idle detection.
