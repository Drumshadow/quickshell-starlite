# Theme system and switcher — implementation spec

Component §1.8 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML + wallust.

Every other component spec contains the line *"resolves from the active scheme"*. **This spec
defines what that means.** §2's token schema is the contract the whole shell is written
against, so settle it before building the second component — retrofitting a token rename
across seven components is miserable.

The source calls it "the showstopper" [07:59], and the claim it makes is strong:

> "Click one and the entire system restyles live, not just the shell, but my apps too through
> wallust… The fills, the shadows, the icons all derived from the active color scheme. The
> flat design works just as well in light mode as it does in dark because nothing is hard
> coded."

---

## 1. Architecture — wallust is the source of truth

The shell is a **pure consumer** of colour. It does not own palette definitions.

```
theme selected  →  wallust theme <name>  →  renders templates:
                                              ├─ shell tokens  (JSON)
                                              ├─ Plasma colour scheme (§5)
                                              ├─ terminal, editor, …
                                            →  post hooks
                   shell reloads its token file  →  every binding updates
```

The alternative — the shell holding its own palettes and *also* calling wallust — means two
definitions of eighteen themes that will drift. The entire selling point is that the shell
and the applications match, so there must be one pipeline.

**One exception: compile in a fallback palette.** If the generated token file is missing,
truncated or unparseable, the shell must fall back to a built-in scheme rather than render
unstyled. An unreadable shell on a tablet with no keyboard is not a recoverable state.

---

## 2. Token schema — the contract

wallust emits base colours (`background`, `foreground`, `cursor`, `color0`–`color15`).
**Components never consume those directly.** They consume *semantic* tokens:

| Token | Use |
|---|---|
| `surface` | panel / island background |
| `surfaceVariant` | inset rows, inactive tiles |
| `onSurface` | primary text |
| `onSurfaceDim` | secondary text — app names, action IDs, percentages |
| `accent` | the single accent: fills, active states, progress |
| `onAccent` | text and glyphs **on** an accent fill |
| `outline` | borders, dividers |
| `shadow` | the island's single drop shadow |
| `critical` | critical notifications, destructive confirm (§1.11) |
| `success` | charging bolt tint |
| `isDark` | bool, derived (§3) |

> **Rule: no component may reference `color7` or a hex literal.** That rule is what makes
> eighteen themes work without eighteen sets of per-theme fixes, and it is why the icon spec's
> acceptance criteria include grepping for colour literals.

Adding a token later means touching every theme's derivation, so try to close this list early.

---

## 3. Why light themes actually work — luminance-aware derivation

The source attributes light-mode success to "nothing is hard coded". That is necessary but
**not sufficient**. A shell where nothing is hardcoded but `onSurface` is always a light grey
still breaks on `e-ink`.

What makes it work is that the semantic tokens are **derived from luminance**, not assigned:

- `isDark` = luminance(`background`) < threshold
- `onSurface` / `onSurfaceDim` chosen for contrast **against** `surface`, not fixed
- `onAccent` chosen for contrast against `accent` — an accent that is pale in one theme and
  saturated in another needs opposite glyph colours
- `shadow` opacity scales with `isDark`; a dark drop shadow that reads as depth on a dark
  surface reads as dirt on a white one
- `surfaceVariant` derived by lightening on light schemes and darkening on dark ones — the
  same delta in both directions is wrong

Do this in one derivation function, applied once at load. It is roughly thirty lines and it is
the difference between a design that adapts and one that merely recolours.

`e-ink` is the canary: it is the only light scheme in the set, so it catches every assumption.

---

## 4. Applying a theme

The shell orchestrates, which sidesteps a race:

1. Shell runs `wallust theme <name>` via `Process`.
2. On process exit **success**, shell reloads its token file and re-derives (§3).
3. On non-zero exit, show an error and keep the current theme — **do not** half-apply.

Because the shell both starts the process and waits for it to exit, there is no partial-read
race. A file watcher alone would fire mid-write and hand you truncated JSON.

**Secondary path** for changes made outside the shell (someone runs `wallust theme` in a
terminal): add a `post` hook in `wallust.toml` calling `qs ipc call theme reload` — the same
IPC mechanism the launcher already needs. It fails harmlessly when `qs` is not running.

---

## 5. Theming applications on Plasma — write a Plasma colour scheme

The source is on Arch/Hyprland and templates apps individually. **On this target there is a
much better lever**, and it is the same principle that chose Klipper over `cliphist`
(launcher §7) and Solid over `brightnessctl` (control-centre §2):

> Have wallust render a **Plasma colour scheme** (`.colors`) and apply it in a post hook with
> `plasma-apply-colorscheme`.

Every Qt/KDE application — Konsole, Dolphin, Kate, System Settings, and Plasma's own surfaces
— reads that one file. One template themes the entire Qt side of the desktop instead of
per-application templates that rot. GTK apps follow via Plasma's GTK integration.

Keep individual wallust templates only for things outside that umbrella (a non-KDE terminal,
`btop`, editors with their own theming).

This is also what keeps the shell coherent with Plasma's own remaining surfaces — which, per
parent §6.6, are still present.

---

## 6. Transition

Because §2 forbids hardcoded colour, **every surface in the shell is bound to a token** — so
animating the tokens themselves cross-fades the entire shell for free.

Put a colour animation (~200 ms) on the token object. One change, and the island, control
centre, icons, sliders and notifications all transition together. Do not animate per-component.

Keep it short. The source's selling point is that it feels instant; 200 ms reads as polish,
400 ms reads as lag.

---

## 7. UI

`Alt+T` → `qs ipc call theme open` (no `GlobalShortcut` on KWin, parent §6.5). Island state
`"theme"`, same never-unmap rule.

**3-column scrollable swatch grid**, header `Theme`. Each swatch is a rounded rect filled with
**that theme's own background colour**, containing a small accent pill and the theme name in
that theme's own foreground. The active theme carries an accent ring.

That self-previewing swatch is the good idea in the design: the grid is legible without
applying anything, and `e-ink` visibly reads as light next to the others.

The 18 confirmed names, read from the frames:

`anime` · `ariadne` · `catppuccin` · `e-ink` · `everforest` · `gruvbox` · `gruvbox-material` ·
`horizon` · `industrial` · `kanagawa` · `material-you` · `nightfox` · `noir` · `nord` ·
`rose-pine` · `rxyhn` · `tokyo-night` · `vira-palenight`

Touch: swatches are ~100×50 in the source, already above the 48 px floor. Tap applies
immediately — no preview-then-confirm; instant application is the showpiece. 18 items over 3
columns is 6 rows, so the grid **scrolls** within a height-capped island (the source's frames
show it mid-scroll).

> Observation: `material-you` renders dimmed in the source's grid. Most likely it is
> wallpaper-derived and inert until a wallpaper generates it — which couples it to §1.9. Treat
> it as optional in v1.

---

## 8. Contrast validation

Eighteen themes times ten tokens will produce at least one illegible combination, and finding
it by accident three weeks in is the bad outcome.

Extend the **icon gallery** (`~/specs/quickshell-icons.md` §9) into a theme gallery: render
every theme's derived tokens with computed WCAG contrast ratios for the pairs that matter —
`onSurface`/`surface`, `onSurfaceDim`/`surface`, `onAccent`/`accent`, `critical`/`surface` —
and flag anything under 4.5:1 (3:1 for large text and glyphs).

Cheap, and it converts "does e-ink look right?" from a judgement call into a number.

---

## 9. Persistence

**No separate state needed.** wallust already persists by having written the files. On shell
start, read the current token file and derive. The theme that was active is simply the one on
disk.

Only the fallback path (§1) needs care: if the file is unreadable at startup, load the
built-in scheme and surface a visible but non-blocking warning.

---

## 10. Build order

1. **Token schema (§2) and the derivation function (§3).** Before any second component exists.
2. Hardcode one palette; prove every existing component (OSD, icons) binds only to tokens.
3. wallust installed; render the shell token template; shell reads it at startup.
4. Theme gallery + contrast validation (§8) across all 18 — **before** building the picker UI.
   This is where you discover which themes need derivation fixes.
5. `wallust theme <name>` via `Process`, reload on exit (§4).
6. Plasma colour-scheme template + `plasma-apply-colorscheme` post hook (§5).
7. Swatch grid UI (§7).
8. Token transition animation (§6).
9. `post`-hook IPC path for external changes (§4).

Steps 1–2 are the ones that matter and they belong at the very start of the project, before
the OSD is finished. Steps 3–4 can wait; step 7 is cosmetic and can be last.

---

## 11. Acceptance criteria

- [ ] `grep` finds no colour literals and no `colorN` references outside the derivation function
- [ ] All 18 themes load and derive without manual per-theme overrides
- [ ] `e-ink` is fully legible: text, dim text, icons, shadows, critical accent
- [ ] Contrast validator reports ≥4.5:1 for text pairs across every theme, or documented exceptions
- [ ] Switching theme restyles island, control centre, icons and notifications in one animated pass
- [ ] Konsole / Dolphin / System Settings restyle too (proves §5)
- [ ] A failed `wallust` run leaves the previous theme intact — no half-applied state
- [ ] Corrupt or missing token file falls back to the built-in scheme and warns
- [ ] Selected theme survives a `qs` restart and a reboot
- [ ] `wallust theme X` run from a terminal updates the shell (proves the §4 secondary path)
- [ ] Transition completes in ~200 ms and does not stutter on this hardware
- [ ] Island never unmaps entering/leaving `"theme"` (503121 regression check)

## 12. Open questions — answered on hardware 2026-09-03

1. **All built-ins except Ariadne.** wallust 3.5.2 ships 616 themes; the 18 chosen are
   Nord, Nord-Light, Gruvbox-Dark, Gruvbox-Material-Light, Tokyo-Night(-Light),
   Catppuccin-Mocha/Latte, Dracula, Everforest-Dark/Light-Medium, Kanagawa-Wave/Lotus,
   One-Dark, Solarized-Dark/Light, Oxocarbon-Dark, Paper. Ariadne is a pywal-format JSON
   applied with `wallust cs` (tools/tablet/wallust/colorschemes/ariadne.json). No Rose Pine
   in wallust's bundle. The contrast audit ran across all 19 and found 10 failures under the
   original lum<0.35 ink rule — see §3's derivation notes in Config/Tokens.qml.
2. **Yes, `material-you` is wallpaper-derived.** Built as the "From wallpaper" swatch: inert
   until a long-press on a wallpaper thumbnail runs `wallust run <image>`; then it previews the
   token file. Deferred no longer — wallpaper §3 is on hardware.
3. **Live.** `plasma-apply-colorscheme` repaints running Qt/KDE apps immediately. It needs a
   QPA (from a bare SSH shell set `QT_QPA_PLATFORM=offscreen`, else exit 250 with no message).
4. **3 ms** for `wallust theme` end to end on the StarLite (full backend, lab). Plus the
   post step and reload the swap lands well under a second; no optimistic apply needed.
5. **Neither.** No Fedora package and no cargo on the tablet; the static
   `x86_64-unknown-linux-musl` release binary from Codeberg goes to `~/.local/bin`.
6. **Theme → collection only** (wallpaper §3). Picking a theme selects a same-named wallpaper
   collection when one exists; picking a wallpaper never changes the palette.

## 13. Dependencies

- **wallust** — palette generation and template rendering. Packaging unconfirmed (§12 q5).
- `plasma-apply-colorscheme` — ships with Plasma.
- Quickshell `Process` (confirmed, launcher §14), `IpcHandler` (confirmed).
- Token file reading: `FileView` in `Quickshell.Io` — **unverified**, same open item as
  launcher §13 q5. A `Process`-based `cat` is the fallback.
