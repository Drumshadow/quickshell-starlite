# Running and testing quickshell-starlite

Everything runs in a container. **Nothing touches the host's desktop session**, and there is
no host session on the dev machine anyway (it is headless/SSH).

## Why a container

The dev machine is a System76 Meerkat on **Pop!_OS 24.04**, which has **Qt 6.4** — Quickshell
needs 6.6+, and Quickshell is not packaged for Debian/Ubuntu at all. The container is
**Fedora 44**, matching the eventual StarLite exactly, so every API difference found here is a
real target difference rather than an artefact of the dev box.

Inside it, a **headless wlroots compositor (sway)** provides `wlr-layer-shell` — the same
protocol KWin implements on the target — so layer-shell surfaces can be rendered and
screenshotted with no display.

## Lint first

```bash
tools/lint.py           # static checks, no container needed
tools/lint.py --list    # the rules
```

Every rule corresponds to something that actually broke this codebase at runtime
(`QUICKSHELL-NOTES.md`) or to an architectural boundary we keep on purpose. Three of the nine
runtime bugs were mechanically detectable; this is that grep. It runs automatically before
every headless render.

`ERROR` means it will break at runtime. `WARN` means architectural drift — a colour literal
outside `Tokens`, a hardcoded `48` instead of `InputMode.touchTarget`, UI reaching for `Mock`
directly, or a `Process` outside `Services/`.

## Build once

```bash
docker build -t quickshell-starlite-dev -f tools/dev/Dockerfile tools/dev
```

## Run

```bash
tools/dev/run-mock.sh                 # mocked dev shell + control panel
tools/dev/run-headless.sh gallery.qml # icon + theme gallery with contrast audit
QS_PRESET=tablet tools/dev/run-mock.sh          # start in tablet posture
QS_PRESET=tablet-portrait tools/dev/run-mock.sh
QS_PRESET=low-battery tools/dev/run-mock.sh
```

Each run prints Quickshell's log (QML errors included) and writes a PNG to `tools/dev/out/`.

Presets: `laptop` · `tablet` · `tablet-portrait` · `low-battery` · `charging` · `at-cap` ·
`offline`.

## Vertical slice test

```bash
tools/dev/slice-test.sh
```

Drives the whole path — startup → island renders → expand → volume/brightness OSD →
auto-dismiss → launcher opens → query filters → **application actually launches** → OSK
affordance follows `InputMode` — asserting each step and writing screenshots to
`tools/dev/out/slice/`. 13 assertions, exits non-zero on any failure.

The application launch is real: the container ships a `SliceProbe` desktop entry whose binary
writes `/tmp/slice-launched`, so "it started" is asserted rather than eyeballed.

**Not covered:** real pointer/keyboard *delivery* — see `QUICKSHELL-NOTES.md` §12. A headless
seat has no input capabilities, and the only workaround would inject events into the host.

## On a machine that has a Wayland session

```bash
qs -p dev-shell.qml     # mocked
qs -p gallery.qml
qs -p shell.qml         # real services (mostly unimplemented — see Services/*.qml TODOs)
```

## Mock mode

`Services/Env.qml` holds one switch. Every service reads
`Env.mock ? Mock.<value> : <real backend>`, and **everything is a binding**, so mock mode can
even be toggled at runtime.

`dev-shell.qml` sets `Env.mock = true` and shows `dev/MockPanel.qml` — sliders and toggles for
battery, charge state, volume, mute, brightness, Wi-Fi, Bluetooth, media, peace mode, and the
form-factor inputs — beside live components that read only services.

**Mocking happens at the service boundary.** No UI component knows whether it is talking to a
simulation or to hardware. Swapping in real backends means filling in the `_real*` properties
and the `TODO(real)` blocks in `Services/*.qml`; the UI does not change.

## Adding a real backend

1. Open the service, e.g. `Services/Backlight.qml`
2. Replace the `_real` property with the actual source (D-Bus preferred, native Quickshell API
   preferred over that)
3. Leave the public API identical
4. Verify in mock mode that the UI is unchanged, then verify against hardware

Order of preference for backends: **native Quickshell API → D-Bus → helper program → raw
shell**. There is currently no `Process` object anywhere in this repo, and it should stay that
way for as long as possible.
