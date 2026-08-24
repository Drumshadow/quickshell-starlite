#!/usr/bin/env bash
# OSK probe runner — spec §3.1.8 item 1. Tees console output to a log.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HERE/probe-$(date +%Y%m%dT%H%M%S).log"

command -v qs >/dev/null 2>&1 || { echo "ERROR: 'qs' not found. dnf copr enable errornointernet/quickshell && dnf install quickshell" >&2; exit 1; }

echo "=== environment ===" | tee "$LOG"
{
  echo "XDG_SESSION_TYPE = ${XDG_SESSION_TYPE:-unset}"
  echo "XDG_CURRENT_DESKTOP = ${XDG_CURRENT_DESKTOP:-unset}"
  echo "QT_IM_MODULE = ${QT_IM_MODULE:-unset}   # on Wayland this is usually best left UNSET"
  echo "qs version: $(qs --version 2>&1 | head -1)"
  echo "plasmashell: $(plasmashell --version 2>&1 | head -1)"
} | tee -a "$LOG"

echo | tee -a "$LOG"
echo ">>> Folio DETACHED? Plasma may deliberately suppress the OSK while a" | tee -a "$LOG"
echo ">>> physical keyboard is attached. Detach it before trusting a negative." | tee -a "$LOG"
echo | tee -a "$LOG"
echo "=== probe (ctrl-c to stop) ===" | tee -a "$LOG"

qs -p "$HERE/shell.qml" 2>&1 | tee -a "$LOG"
echo "log: $LOG"
