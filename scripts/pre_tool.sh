#!/usr/bin/env bash
# chronos — PreToolUse hook. Runs async (settings.json must set async: true).
# Appends started_at entry to ledger. Never blocks the agent.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

INPUT=$(cat)
SESSION=$(resolve_session_id "$INPUT")
LEDGER=$(ledger_path "$SESSION")
NOW_UTC=$(now_utc_iso)
NOW_EPOCH=$(now_epoch)

TOOL=$(read_json_field tool_name "$INPUT" 2>/dev/null || echo unknown)
TOOL_USE_ID=$(read_json_field tool_use_id "$INPUT" 2>/dev/null || echo "na-$NOW_EPOCH")
# args_hash over tool_input (compact)
TOOL_INPUT=""
if command -v jq >/dev/null 2>&1; then
  TOOL_INPUT=$(printf '%s' "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null || echo "{}")
fi
ARGS_HASH=$(printf '%s' "$TOOL_INPUT" | args_hash)

# Append JSONL entry
if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg id "$TOOL_USE_ID" --arg t "$TOOL" --arg h "$ARGS_HASH" \
    --arg sa "$NOW_UTC" --argjson se "$NOW_EPOCH" \
    '{tool_use_id:$id, tool:$t, args_hash:$h, started_at:$sa, started_epoch:$se}' \
    >> "$LEDGER"
else
  printf '{"tool_use_id":"%s","tool":"%s","args_hash":"%s","started_at":"%s","started_epoch":%s}\n' \
    "$TOOL_USE_ID" "$TOOL" "$ARGS_HASH" "$NOW_UTC" "$NOW_EPOCH" >> "$LEDGER"
fi

# Silent exit. No context inject — keeps PreToolUse fast and non-blocking.
exit 0
