# chronos — OpenClaw

OpenClaw uses `skills/<name>/SKILL.md` (Agent Skills standard).

## Install

```bash
mkdir -p skills/chronos
cp SKILL.md skills/chronos/SKILL.md
cp AGENTS.md skills/chronos/AGENTS.md
```

## Optional: plugin SDK for ledger

OpenClaw has a plugin-sdk (`openclaw/plugin-sdk`). Time-awareness plugin stub:

```ts
// See openclaw/plugin-sdk docs for full wiring.
// Hook into session + tool events, append to ~/.chronos/ledger-*.jsonl
```

## Degraded mode

SKILL-only works fine. Agent follows decision rules with shell fallback.
