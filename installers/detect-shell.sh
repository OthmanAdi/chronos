#!/usr/bin/env bash
# chronos — shell detector. Picks bash or powershell variant based on env.
# Usage: eval "$(./installers/detect-shell.sh)"
# Exports: CHRONOS_SHELL=bash|powershell, CHRONOS_SETTINGS_FRAGMENT=<path>

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v bash >/dev/null 2>&1 && [ "${OS:-}" != "Windows_NT" ] || [ -n "${WSL_DISTRO_NAME:-}" ]; then
  echo "export CHRONOS_SHELL=bash"
  echo "export CHRONOS_SETTINGS_FRAGMENT=$ROOT/installers/claude-code/settings.json"
elif command -v pwsh >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
  echo "export CHRONOS_SHELL=powershell"
  echo "export CHRONOS_SETTINGS_FRAGMENT=$ROOT/installers/claude-code/settings.windows-ps.json"
else
  echo "export CHRONOS_SHELL=bash"
  echo "export CHRONOS_SETTINGS_FRAGMENT=$ROOT/installers/claude-code/settings.json"
fi
