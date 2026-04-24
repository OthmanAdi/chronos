#!/usr/bin/env bash
# chronos — Stop hook. Checks idle status for autonomous loops.
# Exit 0 = normal. Chronos never blocks Stop — only surfaces warnings to stderr (agent may see in transcript).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

INPUT=$(cat)
SESSION=$(resolve_session_id "$INPUT")
STATE=$(state_path "$SESSION")
NOW_EPOCH=$(now_epoch)

if [ ! -f "$STATE" ]; then exit 0; fi

LAST_USER_EPOCH=0
if command -v jq >/dev/null 2>&1; then
  LAST_USER_EPOCH=$(jq -r '.last_user_at_epoch // 0' "$STATE")
fi

SINCE_LAST=$(( NOW_EPOCH - LAST_USER_EPOCH ))

# If idle > threshold and agent is stopping, emit a soft notice (exit 0).
if [ "$SINCE_LAST" -gt "$CHRONOS_IDLE_THRESHOLD_SEC" ]; then
  echo "chronos: stop after idle=${SINCE_LAST}s (threshold=${CHRONOS_IDLE_THRESHOLD_SEC}s). If autonomous, consider escalation." >&2
fi

exit 0
