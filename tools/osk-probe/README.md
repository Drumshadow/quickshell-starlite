# OSK probe

Answers spec §3.1.8 item 1 of `~/specs/quickshell-starlite-rice.md`:
**does Plasma's on-screen keyboard raise for a Quickshell text field on a layer surface?**

Run this on the StarLite at stage 4, *before writing any shell code*. §1.6 (launcher) and
§1.13 (polkit card) both depend on the answer, and both are unusable folio-detached if it
is no.

```
~/specs/osk-probe/run.sh          # or: qs -p ~/specs/osk-probe/shell.qml
```

## Before you trust a negative

1. **Detach the folio.** Plasma may suppress the OSK while a physical keyboard is
   attached — the easiest way to get a false negative.
2. **Enable a virtual keyboard**: System Settings → Keyboard → Virtual Keyboard.
   With none selected, nothing will ever appear and the probe proves nothing.
3. Confirm Tablet Mode is active if it gates the OSK on this hardware.

## What the probe controls

- **keyboardFocus: None / OnDemand / Exclusive** — `PanelWindow.focusable` defaults to
  **false**, so a text field on an unfocusable panel receives nothing. This is the most
  likely cause of a false "Quickshell can't do input method" reading. Always test OnDemand
  before concluding anything.
- **`Qt.inputMethod.show()`** — if tapping does nothing but this works, you have a
  workaround rather than a blocker.
- **focus by code vs. tap** — some stacks only raise the OSK on a real touch event, not on
  programmatic focus. The launcher opens and focuses programmatically, so this distinction
  matters.
- **Control window** — an ordinary `FloatingWindow` with the same field. Separates "layer
  surfaces can't do input method" from "Quickshell can't".

## What it reports

- `Qt.inputMethod.visible` — whether **Qt** knows an IM is up (distinct from whether an OSK
  is visibly on screen)
- `keyboardRectangle` + screen height — for the §3.1.8 item 2 overlap check
- text actually received — proves `text-input-v3` delivers, not just that a keyboard drew
- a rolling event log, also on stdout

## Decision table

| Observed | Verdict | Action |
|---|---|---|
| OSK raises on tap, text arrives | **Green** | Build as specced. Record `keyboardRectangle` for overlap. |
| Fails at `None`, works at `OnDemand` | **Green** | Not a bug. Set `focusable: true` on every input-taking surface; note it in §1.6/§1.13. |
| Tap fails, `show()` works | **Amber** | Workaround: call `Qt.inputMethod.show()` explicitly on launcher/polkit open. Add to both components' implementation notes. |
| Works in control window, not on panel | **Amber→Red** | Layer-shell specific. Either build the launcher as a `FloatingWindow` (loses layering control) or report upstream. Re-scope §1.6. |
| `visible` stays false but an OSK is drawn | **Amber** | Input may still work — check "text received". You lose keyboard-avoidance layout; keep panels top-anchored so it doesn't matter. |
| OSK raises but no text arrives | **Red** | `text-input-v3` half-wired. Investigate `QT_IM_MODULE` (usually best unset on Wayland) before concluding. |
| Nothing works anywhere, `show()` included | **Red** | Project-level. §1.6 and §1.13 need a different plan — an external launcher that does work, or accept folio-required for text entry. Revisit §6 before proceeding. |

Record the outcome in the spec's §3.1.8 and update ship-queue item 13.

## Note

Written 2026-08-23 against the documented Quickshell API (`PanelWindow`, `FloatingWindow`,
`WlrLayershell.keyboardFocus`, `WlrKeyboardFocus.*`) without hardware to run it on. If it
fails to parse, the API drifted — check `qs --version` against
https://quickshell.org/docs/ and fix the type names. The diagnostic logic is the valuable
part; the syntax is cheap to repair.
