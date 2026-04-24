#!/usr/bin/env bash
# chronos — PostToolUse hook. Runs async.
# Appends finished_at + duration_ms entry to ledger.

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

# Find matching started_epoch from ledger (last match wins)
STARTED_EPOCH=0
if [ -f "$LEDGER" ] && command -v jq >/dev/null 2>&1; then
  STARTED_EPOCH=$(grep -F "\"tool_use_id\":\"$TOOL_USE_ID\"" "$LEDGER" 2>/dev/null | \
    jq -s 'map(select(.started_epoch != null)) | last.started_epoch // 0' 2>/dev/null || echo 0)
fi

DURATION_MS=0
if [ "${STARTED_EPOCH:-0}" -gt 0 ]; then
  DURATION_MS=$(( (NOW_EPOCH - STARTED_EPOCH) * 1000 ))
fi

# Detect success: Claude Code passes tool_response; if it has .error or is_error true, fail.
SUCCESS=true
if command -v jq >/dev/null 2>&1; then
  IS_ERR=$(printf '%s' "$INPUT" | jq -r '.tool_response.is_error // .tool_response.error // empty' 2>/dev/null || true)
  if [ -n "${IS_ERR:-}" ] && [ "$IS_ERR" != "null" ] && [ "$IS_ERR" != "false" ]; then
    SUCCESS=false
  fi
fi

if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg id "$TOOL_USE_ID" --arg t "$TOOL" \
    --arg fa "$NOW_UTC" --argjson fe "$NOW_EPOCH" \
    --argjson dms "$DURATION_MS" --argjson ok "$SUCCESS" \
    '{tool_use_id:$id, tool:$t, finished_at:$fa, finished_epoch:$fe, duration_ms:$dms, success:$ok}' \
    >> "$LEDGER"
else
  printf '{"tool_use_id":"%s","tool":"%s","finished_at":"%s","finished_epoch":%s,"duration_ms":%s,"success":%s}\n' \
    "$TOOL_USE_ID" "$TOOL" "$NOW_UTC" "$NOW_EPOCH" "$DURATION_MS" "$SUCCESS" >> "$LEDGER"
fi

exit 0
