# System tray — implementation spec

**Not a component of the source design.** Identified as a functional gap in
`~/specs/quickshell-status-capsule.md` §6 and specced here to close it.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Quickshell/QML.

---

## 1. Why this exists

The source has no system tray, and on its setup that is a choice. Here it is a **consequence**:

> Removing Plasma's panel (parent §6.6) removes the system tray. Applications that "close to
> tray" — KeePassXC, Nextcloud, Syncthing, Signal, Element, Steam, VPN clients — have nowhere to
> go, and once their window is closed they may be **unreachable**.

KeePassXC is the clarifying example: it minimises to tray by default and there is no other way
to bring it back. This is a functional regression from stock Plasma, not a cosmetic one.

Every other spec in this project reconstructs something from the video. This one exists purely
because the port created a hole, so there is no reference design and §4–§6 are original.

**It is not on the critical path.** Nothing else depends on it, and it can be built any time —
but it blocks *daily-driving*, so build it before relying on the tablet.

---

## 2. No gate — and this one is genuinely easy

Notifications are gated on a bus name plasmashell may not release; polkit on an agent that must
be stopped first. **The tray has neither problem**, because StatusNotifierItem separates two
roles:

| Role | Service | Who |
|---|---|---|
| **Watcher** — the registry of items | `org.kde.StatusNotifierWatcher` | plasmashell keeps it |
| **Host** — something that displays them | `org.kde.StatusNotifierHost-<pid>` | Quickshell registers as *an additional one* |

**The spec explicitly allows multiple hosts.** So Quickshell registers alongside plasmashell,
with no name to contest and nothing to disable. Plasma's own tray widget draws nothing because
its panel is gone, so there are no duplicates either.

Nothing to probe, nothing to revert. Note it as the counter-example: not every integration with
plasmashell is a fight.

### The known bug worth planning around
There is a reported Quickshell issue — *"Tray Icons Disappear After Reloading QuickShell"* —
where a `qs` reload loses the tray and new items do not appear until the session restarts, with
errors reading `RegisteredStatusNotifierItems` from the watcher.

> **Hypothesis worth testing early: this may be *better* on Plasma than on the Hyprland setups
> where it is reported.** There, Quickshell may be running the watcher itself, so restarting it
> loses the registry. Here plasmashell owns the watcher and keeps running, so a `qs` restart
> should only lose the *host*, and re-registering should repopulate from a still-live registry.

If the hypothesis holds, the tray survives the constant reloads of active development. If it
does not, expect to relaunch apps after reloads while building — annoying, not blocking.
**Test this in build step 1**, because it changes how pleasant the rest of the work is.

---

## 3. Where it lives

Per status-capsule §6, **not** in the status capsule — that stays at two glyphs, and a tray is
unbounded in length.

**A single icon row in the control centre, directly above the footer** (control-centre §4.1).
Icons only, no labels, wrapping to a second row if needed. Compact, off the critical path, and
it reuses a surface that already exists.

```
├──────────────────────────────┤
│  ⬤  ⬤  ⬤  ⬤                 │  tray row — icons only
├──────────────────────────────┤
│  🎨    🖼️    ⚙️    ⏻        │  footer (control-centre §4.1)
└──────────────────────────────┘
```

Items ≥48 px with 8 px gutters. Empty tray → the row collapses entirely rather than leaving a
gap.

### Attention needs to escape the control centre
SNI's `Status` has three values, and `NeedsAttention` is how an app says *look at me*. An
attention state nobody sees because it is two taps deep is useless.

**A small dot on the island at `rest` when any item is `NeedsAttention`**, clearing when it
resolves. This is the same conditional-surfacing principle as low battery (status-capsule §1):
the rest pill stays clock-only in the normal case and speaks up only when something needs it.

`Passive` items may be shown or hidden — show them; hiding is Plasma-panel behaviour this is not
trying to replicate (§7).

---

## 4. Icons — the deliberate exception

`quickshell-icons.md` argues the entire shell should be hand-authored or `PathSvg` geometry,
tinted from the active theme, with no icon font anywhere.

> **The tray is where that necessarily breaks.** Tray icons belong to the applications. They
> arrive as arbitrary themed names or raw pixmaps, in whatever colours the app chose, and they
> will not match a hand-drawn set.

Do not fight it. **Do not** recolour or desaturate them — an unrecognisable tray icon defeats the
only purpose a tray has. Keep them small, in their own visually separated row, and accept that
this one row looks like the rest of the Linux desktop rather than like the island.

Stating it here so it is a decision rather than a defect someone later tries to "fix".

Mechanically this is easier than expected: `SystemTrayItem.icon` is *"an icon source string,
usable as an `Image` source"* — Quickshell resolves themed names and raw pixmaps for you, so
there is no ARGB32-over-D-Bus decoding to write. Set `sourceSize` anyway (wallpaper §5).

---

## 5. Menus — push, do not fly out

Right-click on a tray item opens a **DBusMenu** (`com.canonical.dbusmenu`) — a tree with
submenus, checkboxes, radio groups, separators and disabled entries. `SystemTrayItem.menu` is a
handle, displayed via `QsMenuAnchor` / `QsMenuOpener`, with `Quickshell.DBusMenu` behind it.

> **Fly-out submenus do not work on touch.** They assume a pointer that can travel a corridor
> without lifting. On a small panel with a finger they are unusable.
>
> **Render nested menus as pushed sub-views** — the same slide-with-coupled-height transition the
> control centre already uses for its tile sub-views (control-centre §6). Reuse that component.

Menu rows ≥48 px. Checkbox and radio states must render; a menu that silently ignores toggle
state is worse than no menu.

---

## 6. Activation on touch

| Input | Action |
|---|---|
| **Tap** | `activate()` — unless `onlyMenu`, in which case open the menu |
| **Long-press** | open the menu (`display()` / `menu`) |
| ~~Middle-click~~ | `secondaryActivate()` — **no touch equivalent; unavailable** |
| ~~Scroll over icon~~ | `scroll()` — **no touch equivalent; unavailable** |

`onlyMenu` is documented as *"if this tray item only offers a menu and activation will do
nothing"* — **respect it**, or tapping some items does nothing at all and reads as broken.

`hasMenu` gates whether long-press does anything; give items without a menu no long-press
affordance rather than a dead gesture.

Losing `secondaryActivate` and `scroll` is acceptable — both are rarely-used and neither has a
sane finger equivalent. With the folio attached a real pointer restores them, so wire them for
mouse input even though touch cannot reach them.

---

## 7. Deliberately not doing

- **No hide/show configuration.** Plasma lets you choose which items are visible; this shows all
  of them. Fewer settings, per settings §1's rule.
- **No drag-to-reorder.** Sort stably by `id` so positions do not shuffle between sessions.
- **No tooltips.** `tooltipTitle` / `tooltipDescription` exist, but tooltips are a hover concept.
  Surface `title` in the menu header instead, where there is room to read it.
- **Not an XEmbed tray.** SNI only. Ancient apps using the old X11 protocol will not appear —
  correct for a Wayland session, and Plasma would not show them either.

---

## 8. Build order

1. `SystemTray.items` → log ids and statuses. **Test the §2 reload hypothesis here**, before any
   UI, by restarting `qs` with several tray apps running.
2. Icon row in the control centre (§3); tap → `activate()`, respecting `onlyMenu`.
3. Long-press → menu via `QsMenuAnchor`, flat menus only.
4. Nested submenus as pushed sub-views (§5).
5. `NeedsAttention` dot on the island at `rest` (§3).
6. Mouse-only `secondaryActivate` and `scroll` for folio-attached use.

Steps 1–2 already close the regression in §1 — an app that closed to tray becomes reachable
again. Everything after is refinement.

---

## 9. Acceptance criteria

- [ ] KeePassXC (or any close-to-tray app) minimised to tray can be **restored** — the actual point of this component
- [ ] Restarting `qs` with tray apps running: items return without restarting the apps (§2 hypothesis) — outcome recorded here with a date
- [ ] Items with `onlyMenu` open their menu on tap and do not appear inert
- [ ] Items with no menu present no long-press affordance
- [ ] Nested submenus navigate by push, never fly out (§5)
- [ ] Checkbox and radio menu items render and reflect their state
- [ ] `NeedsAttention` surfaces a dot at `rest`; it clears when the item returns to `Active`/`Passive`
- [ ] Empty tray collapses the row; no empty gap in the control centre
- [ ] Item order is stable across restarts
- [ ] Tray icons are **not** recoloured (§4)
- [ ] No duplicate items — plasmashell is not also drawing a tray
- [ ] All targets ≥48 px

## 10. Open questions

1. **Does the §2 reload hypothesis hold on Plasma?** Cheapest possible test, big quality-of-life
   impact during development. Do it first.
2. Does removing every Plasma panel actually stop plasmashell hosting, or does it keep an
   invisible host that competes? Watch for duplicates in step 2.
3. How many tray items in practice? If routinely more than ~8, the single row needs a rethink —
   possibly its own island state rather than a control-centre row.
4. Should `NeedsAttention` also raise a notification? Probably not — most such apps already send
   one, and doubling would be noise.
5. Is `QsMenuAnchor` usable inside a layer-shell surface, or does it want a real popup window?
   Affects §5 materially; verify early.

## 11. APIs confirmed 2026-08-23

`Quickshell.Services.SystemTray` (v0.2.0) → `SystemTray`, `SystemTrayItem`, `Status`, `Category`.

`SystemTrayItem`: `id`, `title`, `status`, `category`, **`icon`** *(icon source string, usable
directly as an `Image` source — §4)*, `tooltipTitle`, `tooltipDescription`, `hasMenu`,
**`onlyMenu`** *(item only offers a menu; activation does nothing — §6)*, `menu`.
Functions: `activate()`, `secondaryActivate()`, `scroll(delta, horizontal)`,
`display(parentWindow, relativeX, relativeY)`.

`Quickshell.DBusMenu` with `QsMenuAnchor` / `QsMenuOpener` for menu rendering (§5, §10 q5).
