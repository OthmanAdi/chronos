#!/usr/bin/env bash
# chronos — shared library (bash)
# Sourced by all hook scripts. Provides: now_iso, ledger_path, state_path, json helpers.

set -euo pipefail

CHRONOS_HOME="${CHRONOS_HOME:-$HOME/.chronos}"
CHRONOS_IDLE_THRESHOLD_SEC="${CHRONOS_IDLE_THRESHOLD_SEC:-900}"   # 15 min
CHRONOS_LEDGER_RETENTION_DAYS="${CHRONOS_LEDGER_RETENTION_DAYS:-30}"
CHRONOS_LEDGER_GZIP_AFTER_DAYS="${CHRONOS_LEDGER_GZIP_AFTER_DAYS:-1}"

mkdir -p "$CHRONOS_HOME"

now_utc_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
now_local_iso() { date +"%Y-%m-%dT%H:%M:%S%z"; }
now_epoch() { date +%s; }
tz_name() { date +%Z 2>/dev/null || echo "UTC"; }
utc_offset() { date +%z 2>/dev/null || echo "+0000"; }

# Read field from stdin JSON using jq if available, else python fallback.
read_json_field() {
  local field="$1" input="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r ".$field // empty"
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))"
  elif command -v python >/dev/null 2>&1; then
    printf '%s' "$input" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))"
  else
    echo "chronos: need jq or python" >&2; return 1
  fi
}

# Emit additionalContext JSON for Claude Code / Codex hooks.
emit_additional_context() {
  local event="$1" ctx="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg e "$event" --arg c "$ctx" \
      '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
  else
    # Minimal JSON escape for quotes + newlines; good enough for ASCII context.
    local esc=${ctx//\\/\\\\}
    esc=${esc//\"/\\\"}
    esc=${esc//$'\n'/\\n}
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$esc"
  fi
}

ledger_path() { local session="$1"; echo "$CHRONOS_HOME/ledger-$session.jsonl"; }
state_path()  { local session="$1"; echo "$CHRONOS_HOME/session-$session.json"; }

# sha256 of stdin, short (12 hex).
args_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print substr($1,1,12)}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print substr($1,1,12)}'
  else
    awk '{s+=length($0)} END {printf "%012x\n", s}'  # crude fallback, length-based
  fi
}

# Human-duration → seconds. 10m, 2h, 30s, 1d.
parse_duration_to_sec() {
  local d="$1"
  local n=${d%[smhd]}
  local u=${d: -1}
  case "$u" in
    s) echo "$n" ;;
    m) echo "$((n*60))" ;;
    h) echo "$((n*3600))" ;;
    d) echo "$((n*86400))" ;;
    *) echo "$d" ;;  # assume seconds
  esac
}

# ISO → epoch (uses date -d if available; works on GNU + BSD via `date -j` fallback).
iso_to_epoch() {
  local iso="$1"
  if date -d "$iso" +%s >/dev/null 2>&1; then
    date -d "$iso" +%s
  elif date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s >/dev/null 2>&1; then
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s
  else
    echo 0
  fi
}

# Cleanup old ledgers. Gzip > N days, delete > M days.
cleanup_ledgers() {
  local now today_epoch
  today_epoch=$(date +%s)
  find "$CHRONOS_HOME" -name 'ledger-*.jsonl' -type f 2>/dev/null | while read -r f; do
    local mtime
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$today_epoch")
    local age_days=$(( (today_epoch - mtime) / 86400 ))
    if [ "$age_days" -gt "$CHRONOS_LEDGER_RETENTION_DAYS" ]; then
      rm -f "$f" "${f%.jsonl}.jsonl.gz" 2>/dev/null || true
    elif [ "$age_days" -gt "$CHRONOS_LEDGER_GZIP_AFTER_DAYS" ] && [ ! -f "${f}.gz" ]; then
      gzip -q "$f" 2>/dev/null || true
    fi
  done
}

# Get session ID from stdin JSON, or fall back to persistent file.
resolve_session_id() {
  local input="$1"
  local sid
  sid=$(read_json_field session_id "$input" 2>/dev/null || true)
  if [ -z "${sid:-}" ]; then
    local file="$CHRONOS_HOME/current-session"
    if [ -f "$file" ]; then
      sid=$(cat "$file")
    else
      sid="anon-$(now_epoch)"
      echo "$sid" > "$file"
    fi
  fi
  echo "$sid"
}
