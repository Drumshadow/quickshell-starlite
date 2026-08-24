#!/usr/bin/env bash
# Render a Quickshell config headlessly and screenshot it.
#
#   tools/dev/run-headless.sh [config.qml] [seconds] [--mock]
#
# Prints Quickshell's log (QML errors included) and writes a PNG to
# tools/dev/out/. Touches nothing on the host session.
set -uo pipefail
CFG="${1:-gallery.qml}"
WAIT="${2:-6}"
MOCK="${3:-}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO/tools/dev/out"; mkdir -p "$OUT"

# Static checks first — they take milliseconds and catch the mechanical
# failures (qmldir drift, on+Uppercase properties, stray semicolons) that would
# otherwise cost a container start and a confusing runtime error.
if ! "$REPO/tools/lint.py"; then
  echo "lint failed — fix the errors above before rendering" >&2
  exit 1
fi
NAME="$(basename "$CFG" .qml)-$(date +%H%M%S)"
[ "$MOCK" = "--mock" ] && QSMOCK=1 || QSMOCK=0

docker run --rm -i -v "$REPO:/shell:ro" -v "$OUT:/out" \
  -e QS_MOCK="$QSMOCK" -e QS_PRESET="${QS_PRESET:-}" \
  quickshell-starlite-dev bash -lc "
set -uo pipefail
export XDG_RUNTIME_DIR=/tmp/xdg
sway-headless -c /etc/sway-headless.conf >/tmp/sway.log 2>&1 &
for i in \$(seq 1 60); do [ -S /tmp/xdg/wayland-1 ] && break; sleep 0.25; done
if [ ! -S /tmp/xdg/wayland-1 ]; then echo 'COMPOSITOR FAILED:'; head -20 /tmp/sway.log; exit 1; fi
export WAYLAND_DISPLAY=wayland-1
echo \"--- quickshell: \$(qs --version 2>&1 | head -1)\"
echo '--- running $CFG (mock=$QSMOCK) ---'
qs -p '/shell/$CFG' >/tmp/qs.log 2>&1 &
sleep $WAIT
sed -e 's/\x1b\[[0-9;]*m//g' /tmp/qs.log
grim /out/$NAME.png >/dev/null 2>&1 && echo '--- screenshot ok: $NAME.png' || echo '--- screenshot FAILED'
pkill -f 'qs -p' 2>/dev/null
"
echo "→ $OUT/$NAME.png"
