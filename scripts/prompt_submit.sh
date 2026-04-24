#!/usr/bin/env bash
# chronos — UserPromptSubmit hook
# Injects per-turn elapsed delta into agent context.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

INPUT=$(cat)
SESSION=$(resolve_session_id "$INPUT")
STATE=$(state_path "$SESSION")
LEDGER=$(ledger_path "$SESSION")

# If state missing, bootstrap (hook ordering edge case) BEFORE capturing NOW.
# If we captured NOW first, bootstrap would write a later started_at_epoch → negative deltas.
if [ ! -f "$STATE" ]; then
  "$SCRIPT_DIR/session_start.sh" <<< "$INPUT" >/dev/null 2>&1 || true
fi

NOW_UTC=$(now_utc_iso)
NOW_EPOCH=$(now_epoch)

# Clamp: if state's started_at is in the future (bootstrap race or clock adjust),
# treat this as turn 0 with zero deltas rather than negative.

# Read previous state
PREV_LAST_USER_EPOCH=0
PREV_START_EPOCH="$NOW_EPOCH"
PREV_TURN=0
if [ -f "$STATE" ] && command -v jq >/dev/null 2>&1; then
  PREV_LAST_USER_EPOCH=$(jq -r '.last_user_at_epoch // 0' "$STATE")
  PREV_START_EPOCH=$(jq -r '.started_at_epoch // 0' "$STATE")
  PREV_TURN=$(jq -r '.turn // 0' "$STATE")
fi

SINCE_LAST=$(( NOW_EPOCH - PREV_LAST_USER_EPOCH ))
SESSION_DURATION=$(( NOW_EPOCH - PREV_START_EPOCH ))
NEW_TURN=$(( PREV_TURN + 1 ))

# Clamp negatives to 0 (bootstrap race / clock skew).
[ "$SINCE_LAST" -lt 0 ] && SINCE_LAST=0
[ "$SESSION_DURATION" -lt 0 ] && SESSION_DURATION=0

# Write back
if command -v jq >/dev/null 2>&1; then
  TMP=$(mktemp)
  jq --arg u "$NOW_UTC" --argjson e "$NOW_EPOCH" --argjson t "$NEW_TURN" \
    '.last_user_at_utc = $u | .last_user_at_epoch = $e | .turn = $t' \
    "$STATE" > "$TMP" && mv "$TMP" "$STATE"
fi

# Humanize deltas
humanize() {
  local s=$1
  if [ "$s" -lt 60 ]; then echo "${s}s"
  elif [ "$s" -lt 3600 ]; then echo "$((s/60))m $((s%60))s"
  elif [ "$s" -lt 86400 ]; then echo "$((s/3600))h $(((s%3600)/60))m"
  else echo "$((s/86400))d $(((s%86400)/3600))h"
  fi
}

SINCE_LAST_H=$(humanize "$SINCE_LAST")
SESSION_H=$(humanize "$SESSION_DURATION")

IDLE_WARN=""
if [ "$SINCE_LAST" -gt "$CHRONOS_IDLE_THRESHOLD_SEC" ] && [ "$NEW_TURN" -gt 1 ]; then
  IDLE_WARN="
idle_warning: user was away for $SINCE_LAST_H — if running autonomously, re-confirm direction."
fi

CTX="chronos turn
now_utc: $NOW_UTC
turn: $NEW_TURN
session_duration: $SESSION_H ($SESSION_DURATION s)
since_last_user: $SINCE_LAST_H ($SINCE_LAST s)
ledger: $LEDGER$IDLE_WARN"

emit_additional_context UserPromptSubmit "$CTX"
exit 0
