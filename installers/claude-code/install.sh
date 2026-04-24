#!/usr/bin/env bash
# chronos — Claude Code installer
# Concatenates chronos hooks into ~/.claude/settings.json (or .claude/settings.json with --project).
# Uses array concat per hook event so existing hooks (mempalace, planning-with-files, etc.) are preserved.

set -euo pipefail

CHRONOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE=user
TARGET=""
UNINSTALL=false
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --project)   SCOPE=project; shift ;;
    --path)      TARGET="$2"; shift 2 ;;
    --uninstall) UNINSTALL=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: install.sh [OPTIONS]

Options:
  --project      Install to .claude/settings.json (project scope) instead of user scope
  --path PATH    Install to a specific settings.json path
  --uninstall    Remove chronos hooks from settings.json and delete the skill directory
  --dry-run      Show what would change without writing anything
  -h, --help     Show this help
EOF
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TARGET" ]; then
  if [ "$SCOPE" = project ]; then
    mkdir -p .claude; TARGET=.claude/settings.json
  else
    mkdir -p "$HOME/.claude"; TARGET="$HOME/.claude/settings.json"
  fi
fi

[ -f "$TARGET" ] || echo '{}' > "$TARGET"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required. Install: https://jqlang.org" >&2; exit 2
fi

SKILL_DIR="$HOME/.claude/skills/chronos"
if [ "$SCOPE" = project ]; then SKILL_DIR=".claude/skills/chronos"; fi

# ── Uninstall ──────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
  BACKUP="$TARGET.chronos-backup-$(date +%s)"
  cp "$TARGET" "$BACKUP"
  TMP=$(mktemp)

  jq '
    if .hooks then
      .hooks |= with_entries(
        .value |= map(
          . as $entry
          | if (.command // "" | contains("chronos/scripts")) then empty
            elif (.hooks // [] | map(.command // "") | map(contains("chronos/scripts")) | any) then empty
            else . end
        )
      )
      | .hooks |= with_entries(select(.value | length > 0))
    else . end
  ' "$TARGET" > "$TMP"

  if [ "$DRY_RUN" = true ]; then
    echo "=== dry-run: hooks that would be removed ==="
    diff <(jq '.hooks // {}' "$TARGET") <(jq '.hooks // {}' "$TMP") || true
    rm -f "$TMP"
    exit 0
  fi

  mv "$TMP" "$TARGET"
  echo "chronos: removed hooks from $TARGET"
  echo "        backup: $BACKUP"

  if [ -d "$SKILL_DIR" ]; then
    rm -rf "$SKILL_DIR"
    echo "chronos: removed skill directory $SKILL_DIR"
  fi
  exit 0
fi

# ── Install ────────────────────────────────────────────────────────────────
FRAGMENT="$CHRONOS_ROOT/installers/claude-code/settings.json"
BACKUP="$TARGET.chronos-backup-$(date +%s)"
cp "$TARGET" "$BACKUP"

# Strategy: per-event array concat. If chronos hook already present (by command substring), skip.
# Never replace existing user hooks.
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
                ([($target.hooks[$event] // [])[]
                  | (.hooks // [])[]
                  | .command // ""
                 ] | map(contains("chronos/scripts")) | any) | not
              )
          ))
      )
    )
' "$TARGET" "$FRAGMENT" > "$TMP"

if [ "$DRY_RUN" = true ]; then
  echo "=== dry-run: hooks that would be added ==="
  diff <(jq '.hooks // {}' "$TARGET") <(jq '.hooks // {}' "$TMP") || true
  rm -f "$TMP"
  echo "        (no files written)"
  exit 0
fi

mv "$TMP" "$TARGET"

echo "chronos: installed hooks (array concat, no clobbers) at $TARGET"
echo "        backup: $BACKUP"

# Also install SKILL.md to ~/.claude/skills/chronos so it shows in the / menu.
mkdir -p "$SKILL_DIR"
cp "$CHRONOS_ROOT/SKILL.md" "$SKILL_DIR/SKILL.md"
if [ ! -e "$SKILL_DIR/scripts" ]; then
  cp -r "$CHRONOS_ROOT/scripts" "$SKILL_DIR/scripts"
fi
echo "chronos: installed SKILL.md at $SKILL_DIR"
echo "CHRONOS_ROOT=$CHRONOS_ROOT"
echo "Restart Claude Code for /chronos to appear in the slash menu."
