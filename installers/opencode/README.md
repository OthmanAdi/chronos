# chronos — OpenCode install

OpenCode plugins can't push arbitrary context into the model. Chronos works in "ledger-only" mode: the plugin writes the ledger + state file; SKILL.md instructs the agent to `Read` those files at decision points.

## Install

```bash
mkdir -p ~/.config/opencode/plugins
cp installers/opencode/plugin.ts ~/.config/opencode/plugins/chronos.ts
```

Also copy the portable `SKILL.md` to a skills location OpenCode loads:

```bash
mkdir -p ~/.config/opencode/skills/chronos
cp SKILL.md ~/.config/opencode/skills/chronos/SKILL.md
```

## How the agent uses it

SKILL.md tells the agent to:
1. Read `~/.chronos/session-<sid>.json` for baseline + last_user timestamp
2. Read `~/.chronos/ledger-<sid>.jsonl` for tool-use history

No `additionalContext` injection on this platform — honest degraded mode.

## Env

- `CHRONOS_HOME` — override ledger location (default: `~/.chronos`)
- `CHRONOS_IDLE_THRESHOLD_SEC` — idle warning threshold (default: 900)
