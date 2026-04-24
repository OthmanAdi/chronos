#!/usr/bin/env bash
# chronos — Codex CLI installer. Array-concat merge.
set -euo pipefail

CHRONOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$HOME/.codex"

TARGET="$HOME/.codex/hooks.json"
FRAGMENT="$CHRONOS_ROOT/installers/codex/hooks.json"
[ -f "$TARGET" ] || echo '{}' > "$TARGET"

if ! command -v jq >/dev/null 2>&1; then echo "jq required" >&2; exit 2; fi

BACKUP="$TARGET.chronos-backup-$(date +%s)"
cp "$TARGET" "$BACKUP"

TMP=$(mktemp)
jq -s --arg root "$CHRONOS_ROOT" '
  (.[1] | walk(if type == "string" then gsub("\\$\\{CHRONOS_ROOT\\}"; $root) else . end) | del(._comment)) as $frag
  | .[0] as $target
  | $target
  | .hooks = (.hooks // {})
  | reduce ($frag.hooks | keys[]) as $event (.;
      .hooks[$event] = (
        (.hooks[$event] // [])
        + ($frag.hooks[$event] | map(
            . as $new
            | select(
                ([($target.hooks[$event] // [])[] | .command // ""]
                 | map(contains("chronos/scripts")) | any) | not
              )
          ))
      )
    )
' "$TARGET" "$FRAGMENT" > "$TMP"
mv "$TMP" "$TARGET"

# Enable feature flag
CONF="$HOME/.codex/config.toml"
[ -f "$CONF" ] || touch "$CONF"
if ! grep -q '^\s*codex_hooks\s*=\s*true' "$CONF" 2>/dev/null; then
  if ! grep -q '^\[features\]' "$CONF" 2>/dev/null; then
    printf '\n[features]\ncodex_hooks = true\n' >> "$CONF"
  else
    awk '/^\[features\]/ {print; print "codex_hooks = true"; next} 1' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
  fi
fi

echo "chronos: Codex hooks installed (array concat) at $TARGET"
echo "        backup: $BACKUP"
echo "        enabled [features] codex_hooks=true"
echo "CHRONOS_ROOT=$CHRONOS_ROOT"
