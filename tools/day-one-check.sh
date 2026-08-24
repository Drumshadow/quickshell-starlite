#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Day-one verification for the Quickshell StarLite rice.
# Implements §2 of ~/specs/quickshell-build-order.md.
#
#   ~/specs/day-one-check.sh            # run everything
#   ~/specs/day-one-check.sh --section B
#
# STRICTLY READ-ONLY. This script changes nothing. Where a fix is needed it
# prints the command for you to run yourself.
#
# Run it on the tablet, on stock Plasma, WITH THE FOLIO DETACHED where noted.
# ---------------------------------------------------------------------------
set -uo pipefail

LOG="${HOME}/specs/day-one-$(date +%Y%m%dT%H%M%S).log"
SECTION="${2:-all}"
[ "${1:-}" = "--section" ] || SECTION=all

if [ -t 1 ]; then
  B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; Z=$'\e[0m'
else B=""; R=""; G=""; Y=""; C=""; Z=""; fi

PASS=0; FAIL=0; MANUAL=0
declare -a FINDINGS

say()  { printf '%s\n' "$*" | tee -a "$LOG"; }
hdr()  { say ""; say "${B}=== $* ===${Z}"; }
sub()  { say ""; say "${C}-- $* --${Z}"; }
ok()   { PASS=$((PASS+1));   say "  ${G}[PASS]${Z} $*"; }
no()   { FAIL=$((FAIL+1));   say "  ${R}[FAIL]${Z} $*"; }
warn() {                     say "  ${Y}[WARN]${Z} $*"; }
info() {                     say "  [info] $*"; }
manual(){ MANUAL=$((MANUAL+1)); say "  ${Y}[YOU]${Z}  $*"; }
record(){ FINDINGS+=("$*"); }

have() { command -v "$1" >/dev/null 2>&1; }
# run a command only if it exists; never let a missing tool abort the script
try()  { if have "$1"; then "$@" 2>/dev/null; else return 127; fi; }

want_section() { [ "$SECTION" = all ] || [ "$SECTION" = "$1" ]; }

say "${B}Quickshell StarLite — day-one verification${Z}"
say "$(date -Is)   host=$(hostname)   user=$USER"
say "log: $LOG"
say "read-only: this script changes nothing"

# ---------------------------------------------------------------------------
if want_section A; then
hdr "A. Hardware and session facts"

sub "A1. System"
info "model:   $(try hostnamectl --json=short 2>/dev/null | grep -o '"Hardware Model":"[^"]*"' | cut -d'"' -f4 || cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
info "os:      $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
info "kernel:  $(uname -r)"
info "session: type=${XDG_SESSION_TYPE:-unset} desktop=${XDG_CURRENT_DESKTOP:-unset}"
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then ok "Wayland session"
else no "not a Wayland session (got '${XDG_SESSION_TYPE:-unset}') — everything assumes Wayland"; fi

PLASMA_VER="$(try plasmashell --version | awk '{print $NF}')"
info "plasma:  ${PLASMA_VER:-not found}"
if [ -n "${PLASMA_VER:-}" ]; then
  MAJ="${PLASMA_VER%%.*}"; REST="${PLASMA_VER#*.}"; MIN="${REST%%.*}"
  if [ "${MAJ:-0}" -gt 6 ] 2>/dev/null || { [ "${MAJ:-0}" -eq 6 ] && [ "${MIN:-0}" -ge 6 ]; } 2>/dev/null; then
    ok "Plasma >= 6.6 — clears the ext-session-lock threshold (parent §6.2)"
    record "Plasma $PLASMA_VER (>=6.6, session-lock OK)"
  else
    warn "Plasma $PLASMA_VER < 6.6 — Quickshell lock screen unavailable (lock-greeter §4)"
    record "Plasma $PLASMA_VER (<6.6 — no WlSessionLock)"
  fi
fi

sub "A2. Display — records the numbers every spec sizes against"
if have kscreen-doctor; then
  kscreen-doctor -o 2>/dev/null | sed 's/^/    /' | tee -a "$LOG" >/dev/null
  kscreen-doctor -o 2>/dev/null | grep -iE 'Output|Geometry|Scale|Enabled' | sed 's/^/  /' | tee -a "$LOG"
  manual "record panel resolution + the scale factor tablet mode picks (build-order §2.1)"
else
  warn "kscreen-doctor not found — record resolution and scale manually"
fi

sub "A3. Inputs the design depends on"
if grep -qi "touch" /proc/bus/input/devices 2>/dev/null; then ok "touchscreen present"
else no "no touchscreen detected — the entire §3.1 touch redesign assumes one"; fi

if grep -qi "power button" /proc/bus/input/devices 2>/dev/null; then
  ok "power button present — island-core §9.1 mechanism 1 is available"
  record "power button: present"
else
  warn "no power button found — island-core §9.1 falls back to the control-centre footer only"
  record "power button: NOT found"
fi

if [ -d /sys/bus/iio/devices ] && ls /sys/bus/iio/devices 2>/dev/null | grep -q .; then
  ok "IIO sensors present: $(ls /sys/bus/iio/devices | tr '\n' ' ')"
  for d in /sys/bus/iio/devices/iio:device*; do
    [ -r "$d/name" ] && info "  $(basename "$d"): $(cat "$d/name" 2>/dev/null)"
  done
  if ls /sys/bus/iio/devices/*/in_illuminance* >/dev/null 2>&1; then
    warn "ambient light sensor present — may drive auto-brightness (osd §12 q3/q5: add to the OSD suppression list)"
    record "ambient light sensor: present — check OSD suppression"
  fi
else
  warn "no IIO devices — auto-rotate may not work (parent §3.3)"
fi
if try systemctl is-active --quiet iio-sensor-proxy; then ok "iio-sensor-proxy active"; else warn "iio-sensor-proxy not active"; fi

sub "A4. Fingerprint — could erase the lock screen's worst hazard"
if have fprintd-list; then
  if fprintd-list "$USER" 2>&1 | grep -qi "no devices"; then
    info "fprintd installed, no reader found"
    record "fingerprint: none"
  else
    ok "fingerprint reader available — lock-greeter §10 q6: a reader or PIN sidesteps the OSK hazard entirely"
    record "fingerprint: PRESENT — revisit lock-greeter §3.1"
  fi
else
  info "fprintd not installed — 'lsusb | grep -i finger' to check for hardware"
  have lsusb && lsusb 2>/dev/null | grep -i -E 'finger|biometric' | sed 's/^/    /' | tee -a "$LOG"
fi

sub "A5. Battery and the charge-cap trap (status-capsule §4)"
BAT="$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)"
if [ -n "$BAT" ]; then
  info "battery: $(basename "$BAT")  capacity=$(cat "$BAT/capacity" 2>/dev/null)%  status=$(cat "$BAT/status" 2>/dev/null)"
  THR=""
  for f in charge_control_end_threshold charge_stop_threshold; do
    [ -r "$BAT/$f" ] && THR="$(cat "$BAT/$f" 2>/dev/null)" && info "charge cap ($f): ${THR}%"
  done
  if [ -n "$THR" ] && [ "$THR" != "100" ]; then
    warn "charge cap at ${THR}% — status-capsule §4: do NOT treat 100% as the only 'full', and do not animate a charging bolt at the cap"
    record "charge cap: ${THR}% — battery state machine must handle AtCap"
  else
    info "no charge cap set (or 100%)"
    record "charge cap: none"
  fi
  if have upower; then
    UDEV="$(upower -e 2>/dev/null | grep -i BAT | head -1)"
    [ -n "$UDEV" ] && upower -i "$UDEV" 2>/dev/null | grep -E 'state|percentage|time to' | sed 's/^/    /' | tee -a "$LOG"
    manual "plug in AC while at the cap and re-run — does UPower report 'charging' or something else? (status-capsule §11 q2)"
  fi
else
  warn "no battery found"
fi
fi

# ---------------------------------------------------------------------------
if want_section B; then
hdr "B. The four gates (build-order §2.2)"

sub "B1. OSK on a Quickshell surface — gates launcher, polkit, lock screen"
VK="$(try kreadconfig6 --file kwinrc --group Wayland --key InputMethod)"
if [ -n "${VK:-}" ]; then ok "virtual keyboard configured: $VK"
else no "no virtual keyboard set — System Settings > Keyboard > Virtual Keyboard. Without one the probe proves nothing"; fi
if have qs; then
  manual "DETACH THE FOLIO, then run:  ~/specs/osk-probe/run.sh"
  manual "  read the decision table in ~/specs/osk-probe/README.md and record the verdict"
else
  warn "quickshell not installed yet — install, then run the probe"
fi

sub "B2. Notification bus name — gates notifications + CC notification list"
if have busctl; then
  OWNER="$(busctl --user list --no-legend 2>/dev/null | awk '$1=="org.freedesktop.Notifications"{print $2}' | head -1)"
  if [ -n "${OWNER:-}" ]; then
    PNAME="$(ps -p "$OWNER" -o comm= 2>/dev/null || echo '?')"
    info "org.freedesktop.Notifications owned by pid $OWNER ($PNAME)"
    if [ "$PNAME" = "plasmashell" ]; then
      warn "owned by plasmashell, as expected — notifications §0: test whether a Quickshell NotificationServer can take it"
      record "notification name: held by plasmashell (pid $OWNER) — gate UNTESTED"
    else
      info "owned by $PNAME"
      record "notification name: held by $PNAME"
    fi
    manual "run a minimal Quickshell NotificationServer, re-check this, then: notify-send probe 'who renders this?'"
    manual "  WRITE DOWN how to re-enable Plasma's before disabling anything (notifications §0)"
  else
    warn "nobody owns org.freedesktop.Notifications right now"
  fi
else warn "busctl not found"; fi

sub "B3. Polkit agent — gates polkit only, expected clean"
if try systemctl --user cat plasma-polkit-agent.service >/dev/null; then
  ST="$(systemctl --user is-active plasma-polkit-agent.service 2>/dev/null)"
  ok "plasma-polkit-agent.service exists (state: $ST) — stoppable independently of plasmashell"
  info "  stop:   systemctl --user stop plasma-polkit-agent.service"
  info "  revert: systemctl --user start plasma-polkit-agent.service"
  record "polkit agent: plasma-polkit-agent.service, $ST — clean gate"
else
  warn "plasma-polkit-agent.service not found — find what owns the agent before polkit §1.2"
  try systemctl --user list-units --type=service --no-legend 2>/dev/null | grep -i polkit | sed 's/^/    /' | tee -a "$LOG"
  record "polkit agent: unit NOT found — investigate"
fi

sub "B4. Quickshell version — polkit needs >= 0.3.0"
if have qs; then
  QSV="$(qs --version 2>&1 | head -1)"
  info "$QSV"
  QNUM="$(printf '%s' "$QSV" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -n "${QNUM:-}" ]; then
    if [ "$(printf '%s\n0.3.0\n' "$QNUM" | sort -V | head -1)" = "0.3.0" ]; then
      ok "Quickshell $QNUM >= 0.3.0 — Quickshell.Services.Polkit available"
      record "quickshell: $QNUM (polkit OK)"
    else
      warn "Quickshell $QNUM < 0.3.0 — polkit (§1.13) blocked until the COPR updates. Nothing else affected"
      record "quickshell: $QNUM (polkit BLOCKED)"
    fi
  fi
  QMLDIR="$(ls -d /usr/lib64/qt6/qml/Quickshell /usr/lib/qt6/qml/Quickshell 2>/dev/null | head -1)"
  if [ -n "${QMLDIR:-}" ]; then
    info "modules present: $(ls "$QMLDIR" 2>/dev/null | tr '\n' ' ')"
    for m in Services Wayland Bluetooth Io Widgets DBusMenu; do
      [ -d "$QMLDIR/$m" ] && info "  ✓ $m"
    done
    [ -d "$QMLDIR/Services/Polkit" ] && ok "Services/Polkit present" || warn "Services/Polkit absent"
  fi
else
  no "quickshell not installed — dnf copr enable errornointernet/quickshell && dnf install quickshell"
fi
fi

# ---------------------------------------------------------------------------
if want_section C; then
hdr "C. Quick confirmations (build-order §2.3)"

sub "C1. Tooling the specs depend on"
for c in wallust plasma-apply-colorscheme plasma-apply-wallpaperimage qdbus busctl notify-send; do
  if have "$c"; then ok "$c"; else warn "$c missing"; fi
done
have wallust || info "  wallust: check 'dnf search wallust' / COPR, else cargo install (theming §12 q5)"

sub "C2. Plasma's own OSD — will duplicate yours (osd §1)"
OSDV="$(try kreadconfig6 --file plasmashellrc --group OSD --key Enabled)"
if [ -n "${OSDV:-}" ]; then
  info "plasmashellrc [OSD] Enabled = $OSDV"
  ok "the config key exists — osd §1's first option is real"
  record "plasma OSD key: exists (=$OSDV)"
else
  warn "no [OSD] Enabled key found — may be default-true and unset, or moved. osd §12 q2"
  record "plasma OSD key: not found — verify osd §1 fallback"
fi

sub "C3. Shortcut collisions"
if [ -r "$HOME/.config/kglobalshortcutsrc" ]; then
  if grep -qi "Ctrl+Alt+Del" "$HOME/.config/kglobalshortcutsrc" 2>/dev/null; then
    warn "Ctrl+Alt+Del already bound — unbind before claiming it (power-menu §9 q1)"
    grep -i -B2 "Ctrl+Alt+Del" "$HOME/.config/kglobalshortcutsrc" 2>/dev/null | head -6 | sed 's/^/    /' | tee -a "$LOG"
    record "Ctrl+Alt+Del: ALREADY BOUND — unbind first"
  else
    ok "Ctrl+Alt+Del appears unbound"
    record "Ctrl+Alt+Del: free"
  fi
  for k in "Alt+D" "Alt+A" "Alt+T"; do
    grep -qi -- "$k" "$HOME/.config/kglobalshortcutsrc" 2>/dev/null && warn "$k also appears bound — check before claiming"
  done
else
  info "no kglobalshortcutsrc yet (fresh install) — nothing bound"
fi

sub "C4. D-Bus interfaces the specs call into"
if have qdbus; then
  for svc in org.kde.Shutdown org.kde.klipper org.kde.KWin org.freedesktop.NetworkManager; do
    if qdbus "$svc" >/dev/null 2>&1 || qdbus --system "$svc" >/dev/null 2>&1; then ok "$svc reachable"
    else warn "$svc not reachable"; fi
  done
  say ""
  info "org.kde.Shutdown methods (power-menu §1 — must act directly, not prompt):"
  qdbus org.kde.Shutdown /Shutdown 2>/dev/null | grep -i -E 'logout|shutdown|reboot' | sed 's/^/    /' | tee -a "$LOG"
  info "org.kde.klipper methods (launcher §7):"
  qdbus org.kde.klipper /klipper 2>/dev/null | grep -i -E 'history|clipboard' | head -8 | sed 's/^/    /' | tee -a "$LOG"
else warn "qdbus not found — install qt6-qttools"; fi

sub "C5. System tray reload behaviour (system-tray §2 hypothesis)"
if have busctl; then
  W="$(busctl --user list --no-legend 2>/dev/null | awk '$1=="org.kde.StatusNotifierWatcher"{print $2}' | head -1)"
  if [ -n "${W:-}" ]; then
    ok "StatusNotifierWatcher owned by pid $W ($(ps -p "$W" -o comm= 2>/dev/null))"
    info "  if plasmashell owns it, a qs restart should only lose the HOST — the tray should repopulate"
    record "SNI watcher: pid $W ($(ps -p "$W" -o comm= 2>/dev/null))"
  else warn "no StatusNotifierWatcher running"; fi
  manual "with tray apps running, restart qs and confirm icons return (system-tray §10 q1)"
fi

sub "C6. Tablet mode — THE PREMISE (build-order §2.1)"
manual "DETACH THE FOLIO and confirm ALL of:"
manual "   [ ] render scaling increases"
manual "   [ ] screen auto-rotates"
manual "   [ ] on-screen keyboard appears in a normal app (e.g. a text field in Dolphin)"
manual "   [ ] touch input works"
say "  ${Y}If these do not hold, STOP and re-read parent §6 before writing anything.${Z}"
fi

# ---------------------------------------------------------------------------
hdr "Summary"
say "  ${G}pass: $PASS${Z}   ${R}fail: $FAIL${Z}   ${Y}manual steps: $MANUAL${Z}"
say ""
say "${B}Findings — paste into the specs that ask you to record them:${Z}"
say ""
say "  Day-one verification, $(date +%Y-%m-%d):"
for f in "${FINDINGS[@]:-}"; do [ -n "$f" ] && say "    - $f"; done
say ""
say "Still to do by hand: the $MANUAL items marked [YOU] above."
say "Next: build-order §3 (architecture) once §2.1 holds."
say ""
say "log saved: $LOG"
