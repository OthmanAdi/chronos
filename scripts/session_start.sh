#!/usr/bin/env bash
# chronos — SessionStart hook
# Reads hook stdin JSON, initializes ledger + state, emits baseline context.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

INPUT=$(cat)
SESSION=$(resolve_session_id "$INPUT")
LEDGER=$(ledger_path "$SESSION")
STATE=$(state_path "$SESSION")
NOW_UTC=$(now_utc_iso)
NOW_LOCAL=$(now_local_iso)
NOW_EPOCH=$(now_epoch)
TZ=$(tz_name)
OFFSET=$(utc_offset)

# Init ledger (truncate if fresh session start)
: > "$LEDGER"

# Init state
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg s "$SESSION" --arg iso "$NOW_UTC" --arg loc "$NOW_LOCAL" \
    --arg tz "$TZ" --arg off "$OFFSET" --argjson ep "$NOW_EPOCH" \
    '{session_id:$s, started_at_utc:$iso, started_at_local:$loc, started_at_epoch:$ep, tz:$tz, utc_offset:$off, turn:0, last_user_at_utc:$iso, last_user_at_epoch:$ep}' \
    > "$STATE"
else
  cat > "$STATE" <<EOF
{"session_id":"$SESSION","started_at_utc":"$NOW_UTC","started_at_local":"$NOW_LOCAL","started_at_epoch":$NOW_EPOCH,"tz":"$TZ","utc_offset":"$OFFSET","turn":0,"last_user_at_utc":"$NOW_UTC","last_user_at_epoch":$NOW_EPOCH}
EOF
fi

# Opportunistic cleanup of old ledgers
cleanup_ledgers 2>/dev/null || true

# Persist current session ID for platforms without stdin session_id
echo "$SESSION" > "$CHRONOS_HOME/current-session"

CTX="chronos baseline
now_utc: $NOW_UTC
now_local: $NOW_LOCAL
tz: $TZ ($OFFSET)
ledger: $LEDGER
state: $STATE
session: $SESSION

Before reasoning about 'when' or 'how long ago', consult the ledger or run \`date -u\`. Follow chronos/SKILL.md decision rules."

emit_additional_context SessionStart "$CTX"
exit 0
