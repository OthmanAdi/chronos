# chronos — PI (badlogic/pi-mono)

PI supports Agent Skills. Copy SKILL.md into skills directory.

## Install

```bash
mkdir -p ~/.pi/skills/chronos
cp SKILL.md ~/.pi/skills/chronos/SKILL.md
```

## Optional: ledger via PI extension

PI exposes `pi.on("tool_call", ...)` event API. To add a ledger:

```ts
// example extension stub — see pi-mono docs for full wiring
import { pi } from "@badlogic/pi";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const LEDGER = path.join(os.homedir(), ".chronos", "ledger-pi.jsonl");

pi.on("tool_call", (ev) => {
  fs.appendFileSync(LEDGER, JSON.stringify({
    tool: ev.name,
    started_at: new Date().toISOString(),
    duration_ms: ev.duration_ms,
    success: !ev.error,
  }) + "\n");
});
```

## Degraded mode

Without extension: SKILL rules still apply, shell-fallback.
