# chronos — ADAL (SylphAI adal-cli)

ADAL supports Agent Skills. Drop SKILL.md into the ADAL skills location (docs at https://docs.sylph.ai/).

## Install

```bash
# path may vary by ADAL version — check docs
mkdir -p ~/.adal/skills/chronos
cp SKILL.md ~/.adal/skills/chronos/SKILL.md
cp AGENTS.md ~/.adal/skills/chronos/AGENTS.md
```

## Degraded mode only

ADAL hook API is not publicly documented. Chronos runs in SKILL-only mode: decision rules + shell fallback (`date -u`).
