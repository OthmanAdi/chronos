// chronos — OpenCode plugin
// Writes ledger + state to ~/.chronos. SKILL.md instructs agent to Read the state file at decision points.
// Install: drop into ~/.config/opencode/plugins/chronos.ts or <repo>/.opencode/plugins/chronos.ts

import type { Plugin } from "@opencode/plugin-sdk";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import * as crypto from "node:crypto";

const CHRONOS_HOME = process.env.CHRONOS_HOME ?? path.join(os.homedir(), ".chronos");
const IDLE_THRESHOLD_SEC = Number(process.env.CHRONOS_IDLE_THRESHOLD_SEC ?? 900);

fs.mkdirSync(CHRONOS_HOME, { recursive: true });

const nowUtc = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const nowEpoch = () => Math.floor(Date.now() / 1000);
const tzName = () => Intl.DateTimeFormat().resolvedOptions().timeZone ?? "UTC";
const argsHash = (s: string) => crypto.createHash("sha256").update(s).digest("hex").slice(0, 12);

const ledgerPath = (sid: string) => path.join(CHRONOS_HOME, `ledger-${sid}.jsonl`);
const statePath = (sid: string) => path.join(CHRONOS_HOME, `session-${sid}.json`);

const start: Record<string, number> = {};

export default {
  name: "chronos",
  version: "1.0.0",

  onEvent: {
    "session.created": async (ctx: any) => {
      const sid = ctx.session?.id ?? `anon-${nowEpoch()}`;
      fs.writeFileSync(ledgerPath(sid), "");
      fs.writeFileSync(
        statePath(sid),
        JSON.stringify({
          session_id: sid,
          started_at_utc: nowUtc(),
          started_at_epoch: nowEpoch(),
          tz: tzName(),
          turn: 0,
          last_user_at_utc: nowUtc(),
          last_user_at_epoch: nowEpoch(),
        })
      );
      fs.writeFileSync(path.join(CHRONOS_HOME, "current-session"), sid);
    },

    "tool.execute.before": async (ctx: any) => {
      const sid = ctx.session?.id ?? fs.readFileSync(path.join(CHRONOS_HOME, "current-session"), "utf8");
      const tuid = ctx.toolUseId ?? `na-${nowEpoch()}`;
      const tool = ctx.tool?.name ?? "unknown";
      const input = JSON.stringify(ctx.tool?.input ?? {});
      const hash = argsHash(input);
      start[tuid] = nowEpoch();
      const entry = {
        tool_use_id: tuid,
        tool,
        args_hash: hash,
        started_at: nowUtc(),
        started_epoch: nowEpoch(),
      };
      fs.appendFileSync(ledgerPath(sid), JSON.stringify(entry) + "\n");
    },

    "tool.execute.after": async (ctx: any) => {
      const sid = ctx.session?.id ?? fs.readFileSync(path.join(CHRONOS_HOME, "current-session"), "utf8");
      const tuid = ctx.toolUseId ?? `na-${nowEpoch()}`;
      const tool = ctx.tool?.name ?? "unknown";
      const startedEpoch = start[tuid] ?? 0;
      const durationMs = startedEpoch > 0 ? (nowEpoch() - startedEpoch) * 1000 : 0;
      const success = !(ctx.result?.error || ctx.result?.is_error);
      const entry = {
        tool_use_id: tuid,
        tool,
        finished_at: nowUtc(),
        finished_epoch: nowEpoch(),
        duration_ms: durationMs,
        success,
      };
      fs.appendFileSync(ledgerPath(sid), JSON.stringify(entry) + "\n");
      delete start[tuid];
    },

    "session.idle": async (ctx: any) => {
      const sid = ctx.session?.id;
      if (!sid) return;
      const state = JSON.parse(fs.readFileSync(statePath(sid), "utf8"));
      const idle = nowEpoch() - (state.last_user_at_epoch ?? nowEpoch());
      if (idle > IDLE_THRESHOLD_SEC) {
        console.error(`chronos: idle ${idle}s > threshold ${IDLE_THRESHOLD_SEC}s`);
      }
    },
  },
} satisfies Plugin;
