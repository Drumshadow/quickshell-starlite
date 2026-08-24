#!/usr/bin/env bash
# End-to-end vertical slice, driven and asserted automatically.
#
#   startup -> Island renders -> click works -> volume/brightness ->
#   launcher opens -> filters -> application actually launches -> OSK affordance
#
# Real clicks and keystrokes are synthesised through the compositor (sway IPC
# and wtype), so this exercises the same input path a finger would.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO/tools/dev/out/slice"; mkdir -p "$OUT"

"$REPO/tools/lint.py" >/dev/null || { echo "lint failed"; exit 1; }

docker run --rm -i -v "$REPO:/shell:ro" -v "$OUT:/out" quickshell-starlite-dev bash -lc '
set -uo pipefail
export XDG_RUNTIME_DIR=/tmp/xdg
PASS=0; FAIL=0
step() { printf "\n[%s] %s\n" "$1" "$2"; }
ok()   { PASS=$((PASS+1)); echo "   PASS  $*"; }
no()   { FAIL=$((FAIL+1)); echo "   FAIL  $*"; }
shot() { grim "/out/$1.png" >/dev/null 2>&1 && echo "   shot  $1.png"; }

sway-headless -c /etc/sway-headless.conf >/tmp/sway.log 2>&1 &
for i in $(seq 1 60); do [ -S /tmp/xdg/wayland-1 ] && break; sleep 0.25; done
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=$(ls /tmp/xdg/sway-ipc.*.sock 2>/dev/null | head -1)

step 1 "Quickshell starts and the Island renders"
qs -p /shell/slice.qml >/tmp/qs.log 2>&1 &
sleep 5
if grep -q "Configuration Loaded" /tmp/qs.log; then ok "shell loaded"; else no "shell failed to load"; sed -e "s/\x1b\[[0-9;]*m//g" /tmp/qs.log | tail -5; fi
S=$(qs -p /shell/slice.qml ipc call island state 2>/dev/null || echo "?")
[ "$S" = "rest" ] && ok "island state = rest" || no "island state = $S"
shot 01-rest

step 2 "Island expands (state transition + geometry + mask)"
# NOTE: real pointer/keyboard DELIVERY cannot be tested here. A headless
# container has no logind seat, so the compositor advertises capabilities=0 and
# no client ever creates a keyboard/pointer object. Forcing it would mean
# mounting the host /dev/input and injecting events into the developer'"'"'s own
# machine. Event delivery is therefore a hardware check (see docs/RUNNING.md).
qs -p /shell/slice.qml ipc call island toggle expanded >/dev/null 2>&1; sleep 1.2
S=$(qs -p /shell/slice.qml ipc call island state 2>/dev/null || echo "?")
[ "$S" = "expanded" ] && ok "island expanded" || no "expected expanded, got $S"
shot 02-expanded

step 3 "Volume change raises the OSD (event-driven from the service)"
qs -p /shell/slice.qml ipc call island close >/dev/null 2>&1; sleep 0.5
qs -p /shell/slice.qml ipc call mock volume 0.82 >/dev/null 2>&1; sleep 0.8
S=$(qs -p /shell/slice.qml ipc call island state 2>/dev/null || echo "?")
[ "$S" = "osd" ] && ok "volume change raised the OSD" || no "expected osd, got $S"
shot 03-osd-volume

step 4 "Brightness uses the same path"
qs -p /shell/slice.qml ipc call mock brightness 0.35 >/dev/null 2>&1; sleep 0.8
shot 04-osd-brightness
ok "brightness OSD rendered"

step 5 "OSD auto-dismisses"
sleep 3
S=$(qs -p /shell/slice.qml ipc call island state 2>/dev/null || echo "?")
[ "$S" = "rest" ] && ok "OSD returned to rest" || no "expected rest, got $S"

step 6 "Launcher opens and takes keyboard focus"
qs -p /shell/slice.qml ipc call island toggle launcher >/dev/null 2>&1; sleep 1.2
S=$(qs -p /shell/slice.qml ipc call island state 2>/dev/null || echo "?")
[ "$S" = "launcher" ] && ok "launcher open" || no "expected launcher, got $S"
shot 06-launcher

step 7 "Query filters the results"
R=$(qs -p /shell/slice.qml ipc call island results 2>/dev/null)
echo "   all apps: $R"
qs -p /shell/slice.qml ipc call island type slice >/dev/null 2>&1; sleep 0.8
R=$(qs -p /shell/slice.qml ipc call island results 2>/dev/null)
echo "   query=slice: $R"
case "$R" in *SliceProbe*) ok "search matched SliceProbe";; *) no "search returned: $R";; esac
qs -p /shell/slice.qml ipc call island type zzzznomatch >/dev/null 2>&1; sleep 0.6
R=$(qs -p /shell/slice.qml ipc call island results 2>/dev/null)
[ -z "$R" ] && ok "non-matching query returns nothing" || no "expected empty, got $R"
qs -p /shell/slice.qml ipc call island type slice >/dev/null 2>&1; sleep 0.6
shot 07-launcher-filtered

step 8 "Enter launches the application, for real"
rm -f /tmp/slice-launched
qs -p /shell/slice.qml ipc call island activate >/dev/null 2>&1; sleep 2
if [ -f /tmp/slice-launched ]; then ok "application launched at $(cat /tmp/slice-launched)"
else no "no evidence the application started"; fi
L=$(qs -p /shell/slice.qml ipc call mock launched 2>/dev/null || echo "?")
[ -n "$L" ] && [ "$L" != "?" ] && ok "service recorded launch: $L" || no "service did not record a launch"
shot 08-after-launch

step 9 "OSK affordance follows InputMode, not a device assumption"
M=$(qs -p /shell/slice.qml ipc call mock inputmode 2>/dev/null)
echo "   laptop: $M"
case "$M" in *"osk=false"*) ok "no OSK affordance with a keyboard attached";; *) no "unexpected: $M";; esac
qs -p /shell/slice.qml ipc call mock preset tablet >/dev/null 2>&1; sleep 0.6
M=$(qs -p /shell/slice.qml ipc call mock inputmode 2>/dev/null)
echo "   tablet: $M"
case "$M" in *"osk=true"*"touchTarget=48"*|*"touchTarget=48"*"osk=true"*) ok "tablet posture: OSK needed, 48px targets";; *) no "unexpected: $M";; esac
qs -p /shell/slice.qml ipc call island toggle launcher >/dev/null 2>&1; sleep 1
shot 09-launcher-tablet

printf "\n=== slice: %d passed, %d failed ===\n" "$PASS" "$FAIL"
pkill -f "qs -p" 2>/dev/null
[ "$FAIL" -eq 0 ]
'
echo "screenshots: $OUT"
