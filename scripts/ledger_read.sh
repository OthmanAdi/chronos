#!/usr/bin/env bash
# chronos — ledger reader. Query ledger by tool, age, args_hash.
#
# Usage:
#   ledger_read.sh [--session SID] [--tool NAME] [--args-hash HASH] [--since DURATION] [--last] [--count] [--path-only]
#
# Examples:
#   ledger_read.sh --since 10m
#   ledger_read.sh --tool Bash --since 1h
#   ledger_read.sh --tool Bash --args-hash abc123 --last
#   ledger_read.sh --count

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

SESSION=""
TOOL=""
ARGS_HASH=""
SINCE=""
LAST=0
COUNT=0
PATH_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --session) SESSION="$2"; shift 2 ;;
    --tool) TOOL="$2"; shift 2 ;;
    --args-hash) ARGS_HASH="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --last) LAST=1; shift ;;
    --count) COUNT=1; shift ;;
    --path-only) PATH_ONLY=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SESSION" ]; then
  if [ -f "$CHRONOS_HOME/current-session" ]; then
    SESSION=$(cat "$CHRONOS_HOME/current-session")
  else
    echo "no session — pass --session SID" >&2; exit 2
  fi
fi

LEDGER=$(ledger_path "$SESSION")
if [ "$PATH_ONLY" = 1 ]; then echo "$LEDGER"; exit 0; fi
if [ ! -f "$LEDGER" ]; then echo "no ledger at $LEDGER" >&2; exit 0; fi

NOW_EPOCH=$(now_epoch)
CUTOFF_EPOCH=0
if [ -n "$SINCE" ]; then
  SEC=$(parse_duration_to_sec "$SINCE")
  CUTOFF_EPOCH=$(( NOW_EPOCH - SEC ))
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required for ledger_read" >&2; exit 2
fi

FILTER='.'
[ -n "$TOOL" ] && FILTER="$FILTER | select(.tool == \"$TOOL\")"
[ -n "$ARGS_HASH" ] && FILTER="$FILTER | select(.args_hash == \"$ARGS_HASH\")"
if [ "$CUTOFF_EPOCH" -gt 0 ]; then
  FILTER="$FILTER | select((.started_epoch // .finished_epoch // 0) >= $CUTOFF_EPOCH)"
fi

OUT=$(jq -c "$FILTER" "$LEDGER" 2>/dev/null)

if [ "$LAST" = 1 ]; then OUT=$(printf '%s\n' "$OUT" | tail -n 1); fi
if [ "$COUNT" = 1 ]; then printf '%s\n' "$OUT" | grep -c '^' || echo 0; exit 0; fi

printf '%s\n' "$OUT"
