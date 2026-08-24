# Launcher — implementation spec

Component §1.6 of `~/specs/quickshell-starlite-rice.md`. Self-contained: buildable and
changeable without touching the control centre, OSD or notification components.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (per parent §6), Quickshell/QML.

---

## 0. Gate — do not start this before the OSK probe passes

This component is **entirely dependent on `~/specs/osk-probe/`**. The launcher is a text
field; with the folio detached, no on-screen keyboard means no launcher. If the probe comes
back red, stop and re-scope — §11 lists the fallbacks. Everything below assumes green or
amber-with-`Qt.inputMethod.show()`.

Second gate: the probe also tells you whether `keyboardFocus: Exclusive` (§3) still lets the
OSK raise. If it does not, use `OnDemand` and accept a tap-to-focus step.

---

## 1. Architecture: the launcher is a *state*, not a window

The single most important structural decision, and it falls out of two independent
constraints pointing the same way:

- **Design (parent §1.0):** one element morphs into every surface. The launcher is the
  island in a different shape, not a separate popup.
- **Bug (parent §6.5, KWin 503121):** unmapping and remapping a layer surface sends no
  configure event on KWin.

So: **one `PanelWindow`, top-anchored, mapped for the entire session, never hidden.** The
launcher is `island.state === "launcher"`. Its height and content change; its surface does
not go away.

What *does* change on entry and exit:

| | At rest | Launcher open |
|---|---|---|
| `WlrLayershell.keyboardFocus` | `None` | `Exclusive` |
| height | pill (~30) | header + rows (§6) |
| content | clock/media/status | search field + results |

Changing `keyboard_interactivity` on a live surface is legal and needs no remap — that is
what makes this work. **Never** set `visible: false` on the island to dismiss the launcher.

---

## 2. Summon and dismiss

No `GlobalShortcut` — it is Hyprland-only (parent §6.5). Two paths:

**Folio attached — KDE global shortcut.**
System Settings → Shortcuts → Custom → `qs ipc call launcher toggle`, bound to `Alt+D`
(source keybind, keep it).

```qml
IpcHandler {
    target: "launcher"
    function toggle(): void { /* ... */ }
    function open(): void  { /* ... */ }
    function close(): void { /* ... */ }
}
```
`qs ipc show` lists registered targets when debugging.

**Folio detached — bottom-edge swipe.**
A second, separate, permanently-mapped surface: full-width, ~24 px tall, anchored bottom,
`exclusiveZone: 0`, transparent, `keyboardFocus: None`. It exists only to catch an upward
drag past a minimum distance (parent §3.1.6, so a resting palm does not summon it). Bottom
edge is chosen deliberately: it is the reachable edge, and the top edge is already taken by
the island's own shade gesture (parent §3.1.1).

**Dismiss:** Escape, tap outside, swipe down on the launcher, or launching something.

---

## 3. Surface configuration

```qml
PanelWindow {
    anchors { top: true; left: true; right: true }
    WlrLayershell.namespace: "island"
    WlrLayershell.layer: WlrLayer.Overlay        // above fullscreen windows
    WlrLayershell.keyboardFocus: island.state === "launcher"
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    exclusiveZone: 0                              // the island floats, reserves nothing
}
```

---

## 4. Data sources

| Mode | Source |
|---|---|
| Apps | `DesktopEntries.applications` — an ObjectModel of `DesktopEntry`, already filtered of `NoDisplay`/`Hidden` |
| Calc | `qalc -t <expr>` via `Process` (§7) |
| Clipboard | **Klipper** over D-Bus (§8) |

`DesktopEntry` fields used: `id`, `name`, `genericName`, `comment`, `icon`, `keywords`,
`categories`, `command`, `runInTerminal`, `actions`.
Launch with **`entry.execute()`** — it wraps `Quickshell.execDetached()` with the entry's
command and working directory, so the app survives a shell restart. Do not hand-roll it.

Scan `DesktopEntries` **once** and cache a flattened, lower-cased search index at startup.
Never re-walk it per keystroke.

---

## 5. Search and ranking

Match case- and diacritic-insensitively against a precomputed index. Score, sort, cap.

| Signal | Score |
|---|---|
| exact `name` | 1000 |
| `name` starts with query | 800 − start offset |
| word-boundary start inside `name` | 700 |
| `name` contains | 500 |
| `keywords` contains | 400 |
| `genericName` / `comment` contains | 300 |
| `command[0]` basename contains | 200 |
| fuzzy subsequence in `name` | 100 + density bonus |

Tie-break on **frecency** — a persisted launch count decayed by recency. This is the single
cheapest quality win in a launcher: the three things you actually open reach the top after a
day of use. Persist as JSON (`FileView` in `Quickshell.Io`; verify the type name against the
installed version).

Debounce input ~40 ms. Cap results at 50 before display slicing.

---

## 6. Layout, sizing and OSK avoidance

Row height **56 px** — raised from the source's ~30 (parent §3.1.3); this is the one place
the visual size changes, not just the input region.

```
availableHeight = screen.height
                − Qt.inputMethod.keyboardRectangle.height   // ← the tablet-specific part
                − topMargin − safetyMargin
maxVisible      = floor((availableHeight − headerHeight) / 56)
panelHeight     = headerHeight + min(results.count, maxVisible) * 56
```

Bind to `Qt.inputMethod.keyboardRectangle`, do not hardcode. With the OSK up in landscape
expect to fit roughly 4–5 rows; that is acceptable, scroll beyond it. **Shrink-to-fit is
part of the design** — the source collapses to a single row when one result matches. Animate
`panelHeight` with the §1.15 critically-damped spring.

Row: 24 px icon · bold `name` · dim `genericName`. Selected row carries a left accent bar and
a lighter fill.

Icons: resolve `entry.icon` through the icon theme (`Quickshell.iconPath()` — verify). Fall
back to the **themed letter avatar already built for notifications (§1.5)** rather than a
second placeholder style.

---

## 7. Modes

Chips across the top of the header: **Apps · Calc · Clipboard**, each a ≥48 px tap target.

The source drives modes by typing `=` and `:` prefixes. Those need the OSK's symbol layer,
which is two taps deep on touch — hence the chips (parent §3.1.4). Both paths must converge:
typing a prefix activates the matching chip; tapping a chip inserts or strips the prefix.
One state, two entrances.

- Backspace on an empty query clears the mode back to Apps.
- Escape closes the launcher entirely (matches the source).

### Calculator
Evaluate with **`qalc -t`** through `Process` + `StdioCollector`, debounced ~120 ms.

> **Do not `eval()` the query in QML.** That is arbitrary code execution inside the same
> process that draws the polkit prompt (§1.13). Non-negotiable.

Enter copies the result to the clipboard (`wl-copy`, or Klipper's `setClipboardContents`).

### Clipboard
Use **Klipper**, Plasma's built-in clipboard history, over D-Bus — *not* `cliphist`. It is
already running, already has the history, and stays in sync with the rest of the desktop.
Consistent with parent §6's "reuse what Plasma provides" principle.

Confirm the interface on hardware with `qdbus org.kde.klipper /klipper`; expected methods are
`getClipboardHistoryMenu`, `getClipboardHistoryItem(int)`, `setClipboardContents(string)`.
Enter sets the clipboard and closes; it does **not** synthesise a paste keystroke.

---

## 8. The reflow animation — the part that is easy to get wrong

The source's signature behaviour: results do not snap. Non-matches fade out, new matches fade
in, survivors *slide* to their new positions.

Use `ListView` transitions — `add`, `remove`, `displaced`, `move` — with `displaced` on the
same critically-damped spring family as everything else (no bounce, per §1.15).

> **The trap:** these transitions only fire if the model changes *incrementally*. Reassigning
> `model` to a fresh array on every keystroke tears the delegates down and rebuilds them, no
> transition runs, and you get exactly the snap the design exists to avoid.
>
> **Therefore:** hold results in a stable `ListModel` and **apply a diff** — insert, remove
> and move individual rows to reach the new result set. Write the diff first and the styling
> second; retrofitting it later means rewriting the view.

---

## 9. Input model

| Action | Touch (folio off) | Keyboard (folio on) |
|---|---|---|
| Summon | swipe up from bottom edge | `Alt+D` → `qs ipc call launcher toggle` |
| Focus field | automatic on open; call `Qt.inputMethod.show()` if the probe says tap-focus alone fails | automatic |
| Choose | tap the row | `↑`/`↓` then `Enter` |
| Mode | tap a chip | type `=` or `:` |
| Dismiss | tap outside / swipe down | `Escape` |

Row 0 carries the selection highlight by default so the OSK's own Enter key launches the top
hit without any arrow-key use. Keyboard navigation is not removed on touch — it is the
secondary path, not a dead one.

Every row and chip needs an **immediate** press state (<50 ms, not a spring) — parent §3.1.6.

---

## 10. Theming

No hardcoded colours. Every fill, accent, text and border resolves from the active scheme
(§1.8) so all 18 palettes and the light `e-ink` scheme work without launcher-specific
changes. Row height and font size read from the §1.10 settings values.

---

## 11. Build order

1. Island enters/exits `"launcher"` state; `keyboardFocus` flips; height animates. No results yet.
2. Search field + OSK raise verified end-to-end on hardware.
3. `DesktopEntries` index + ranking (§5). Plain list, no animation.
4. **Diffed `ListModel` + reflow transitions (§8).** Before styling.
5. Row styling, icons, letter-avatar fallback.
6. OSK-aware sizing + shrink-to-fit (§6).
7. Frecency persistence.
8. Calc mode. 9. Clipboard mode. 10. Mode chips.
11. Bottom-edge swipe surface (§2).

Stop after 6 and use it for a week before building 7–11; that is enough to know whether the
interaction actually works on this hardware.

### Fallbacks if the OSK probe fails
- **Amber (`show()` needed):** call it explicitly on open. No design change.
- **Works only in an ordinary window:** build the launcher as a `FloatingWindow` instead of a
  layer surface. Costs the morph — it becomes a separate window, breaking §1.0's conceit for
  this component only. Everything else in this spec survives.
- **Red:** the launcher is folio-only. Provide a tap-driven app *grid* (no text entry) as the
  detached-mode alternative, and revisit parent §6.

---

## 12. Acceptance criteria

- [ ] Island never unmaps; `qs ipc call launcher toggle` works repeatedly with no missing configure events (503121 regression check)
- [ ] OSK raises, and typed text reaches the field, folio detached
- [ ] Results never overlap the OSK, in both orientations
- [ ] Typing a character that removes results **animates** them out — no snap (§8)
- [ ] Single-result query collapses the panel to one row
- [ ] Launched app survives `qs` being restarted (proves `execute()`/detached)
- [ ] Every interactive element ≥48 px effective and has a visible press state
- [ ] Works in `e-ink` (light) and at least two dark schemes with no launcher-specific changes
- [ ] Calc never evaluates the query in-process
- [ ] Full flow — summon, type, launch — is achievable with no physical keyboard

## 13. Open questions

1. **`qs ipc call` latency.** Each invocation spawns a process. Measure summon-to-visible; if
   perceptible (>~150 ms), fall back to a KWin script that signals without a spawn.
2. Does `keyboardFocus: Exclusive` still permit the OSK? (Probe answers this.)
3. Does the bottom-edge swipe surface conflict with KWin's own edge gestures? (Parent §3.1.8 item 4.)
4. Klipper D-Bus method names — confirm on hardware.
5. `FileView` and `Quickshell.iconPath()` names against the installed Quickshell version.

## 14. APIs confirmed 2026-08-23

`DesktopEntries.applications` / `.byId()` / `.heuristicLookup()` · `DesktopEntry.execute()`
(wraps `Quickshell.execDetached`) · `IpcHandler { target; function … }` + `qs ipc call` /
`qs ipc show` · `Process` + `StdioCollector.onStreamFinished` · `PanelWindow.exclusiveZone`
/ `.focusable` · `WlrLayershell.keyboardFocus` / `.layer` / `.namespace` ·
`WlrKeyboardFocus.None|OnDemand|Exclusive`.

Unverified, check on hardware: `FileView`, `Quickshell.iconPath()`.
