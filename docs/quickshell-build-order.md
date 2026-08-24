# Quickshell StarLite rice — build order

The cross-spec sequence. Each of the fifteen component specs orders its own internals; this
orders them against each other, for **one person**.

Written 2026-08-23. Parent: `~/specs/quickshell-starlite-rice.md`.

---

## 0. The organising principle

`~/specs/SHIP-QUEUE.md` opens by naming the recurring failure mode here: **built and unshipped.**
So this document is organised around **usable milestones, not completed components.** Every phase
ends with something you can actually run on the tablet, and each says explicitly when to stop
and use it before continuing.

Two consequences:

- **Components are built partially, in dependency order, not one at a time to completion.** The
  control centre appears in three different phases. That is deliberate.
- **A phase is done when the tablet is better than it was**, not when a spec is exhausted.

The tempting alternative — build the icon system fully, then the control centre fully — produces
nothing usable for weeks and is exactly the failure mode named above.

---

## 1. Phase 0 — before the hardware (now)

Nothing to build. Two things to decide and one to gather.

| Item | Why now |
|---|---|
| **Pick the SVG icon set** — Lucide (ISC) or Phosphor (MIT) | Sets the stroke language everything else matches (`icons.md` §5). Blocks nothing else, costs ten minutes |
| **Answer the design questions in §7** | They are yours to make, not discoverable on hardware |
| **Gather wallpapers** — two or three collections, not eighteen | Asset work, not code (`wallpaper.md` §4). The picker is untestable without them, and this quietly blocks a "finished" component |

> **Phases 2–3 are partly written already: `~/quickshell-starlite/`.** Tokens + luminance
> derivation, the island surface with its mask and preemption matrix, the four stateful icons,
> and the gallery harness — ~950 lines of QML. **Never run**; structure-checked only. It turns
> day one from "start writing" into "install and debug". See its README for what is placeholder.

**Optional stretch:** Quickshell is not packaged for Pop!_OS, but COSMIC does implement
wlr-layer-shell, so a Nix install on this box could let you prototype the compositor-agnostic
parts early — the icon library and its gallery, the token derivation, the morph animation. Only
worth it if the week feels long; the Nix setup is real work and none of the Plasma integrations
would function.

---

## 2. Phase 1 — day one on hardware: verify before you build

Half a day, no code. **Run in this order** — the first item can invalidate the entire
architecture.

> **Most of this is scripted: `~/specs/day-one-check.sh`.**
> Strictly read-only — it changes nothing and prints the command wherever a fix is needed. Run
> it on stock Plasma, folio detached. It gathers the hardware facts, tests the gates it can test
> without a UI, flags shortcut collisions and D-Bus methods, and ends with a **findings block to
> paste into the specs that ask you to record an outcome**. Items it cannot judge — anything
> visual — are printed as `[YOU]` steps. Logs to `~/specs/day-one-<timestamp>.log`.
>
> `--section A|B|C` runs one part. Smoke-tested 2026-08-23 on a machine with none of the target
> software installed: exits clean, every check degrades to a readable message.

### 2.1 Verify the premise (do this first)
Boot **stock Plasma**. Detach the folio. Confirm Tablet Mode actually does what parent §6.4
claims: raises render scaling, auto-rotates, enables touch, and raises the on-screen keyboard.

> This is the load-bearing claim behind choosing Plasma over Hyprland (parent §6). If it does not
> hold, **stop and re-read §6 before writing anything.** Everything downstream assumes it.

Also record: panel resolution, the scale factor tablet mode picks, and whether the tablet body
has a **power button** (island-core §9.1) and a **fingerprint reader** (lock-greeter §10 q6 — a
reader or PIN could erase that spec's worst hazard).

### 2.2 The four gates
| Gate | Test | Blocks |
|---|---|---|
| **OSK on a Quickshell surface** | `~/specs/osk-probe/run.sh` — already written | launcher, polkit, lock screen |
| **Notification bus name** | `busctl --user list \| grep -i notif`, then try a Quickshell `NotificationServer` | notifications, CC notification list |
| **Polkit agent stoppable** | `systemctl --user status plasma-polkit-agent.service` | polkit (expected clean) |
| **Quickshell version** | `qs --version` — polkit needs **≥0.3.0** | polkit only |

Each has a documented fallback in its own spec. None is fatal to the project.

### 2.3 Quick confirmations — section C of the script
`wallust` packaged? · `plasma-apply-colorscheme` applies live? · `plasma-apply-wallpaperimage`
applies live? · `plasmashellrc [OSD] Enabled` real? · is `Ctrl+Alt+Del` already bound? ·
`qdbus org.kde.Shutdown /Shutdown` — prompts or direct? · Klipper's D-Bus methods · does UPower
distinguish *at charge cap* from *charging*? · tray survives a `qs` restart?

### 2.4 Install
Quickshell (COPR), wallust. **Do not remove Plasma's panel yet.**

---

## 3. Phase 2 — architecture

The only phase with no user-visible payoff, and the only one where mistakes propagate into
everything.

1. `island-core` §11 steps 1–4 — surface, **mask**, state machine, preemption matrix
2. `theming` §2 token schema and §3 luminance-aware derivation, with one hardcoded palette

> **Settle the token schema before the second component exists.** Renaming a token later means
> touching fifteen specs' worth of code.
>
> **Verify the mask before any real content.** A stale input region means the top of the desktop
> silently stops responding, and it is miserable to debug later.

---

## 4. Phase 3 — Milestone A: a shell that tells the time

**First useful thing.** Everything here is compositor-agnostic QML and none of it depends on a
gate.

3. `icons` steps 1–4 — the gallery, the static set, volume + brightness glyphs
4. `osd` steps 1–3 — volume OSD, event-driven, with the suppression list
5. `media` steps 1–3 — player selection, metadata, EQ bars at rest
6. `status-capsule` steps 1–2 — battery, including the charge-cap states
7. `settings` steps 2–3 — the two sliders and the preview swatch
8. `island-core` steps 6–9 — rest content, IPC, shade gesture, `expanded`

**Stop here and use it for a few days.** You now have a clock, media indication, battery,
working volume and brightness OSDs, and the calibration sliders to size it all to the panel —
running *alongside* an untouched Plasma panel. Everything after this is additive.

This is also where the QML learning curve is paid off, on the smallest component in the set.

---

## 5. Phase 4 — Milestone B: you can launch things

*Gated on the OSK probe.*

9. `launcher` steps 1–6 — including the **diffed ListModel** before any styling
10. `icons` steps 5–6 — battery and Wi-Fi glyphs finished

**Stop and use it.** With a launcher you can start removing Plasma's panel — the point at which
this stops being a widget on top of a desktop and starts being the desktop.

---

## 6. Phase 5 — Milestone C: daily-driveable

7 is the order that matters here: the tray closes a regression the panel removal *creates*, so
it lands in the same phase.

11. `control-center` steps 1–5 — including the **footer row early** (step 1b), or half the shell is unreachable folio-detached
12. `system-tray` steps 1–2 — restores close-to-tray apps
13. `notifications` steps 1–4 *(if the bus-name gate passed)*
14. `control-center` steps 6–9 — brightness, night light, media card, notification list
15. `power-menu` — including the **400 ms arm floor** and the hardware-button binding

**Stop and daily-drive it.** Plasma's panel can now be gone for good.

---

## 7. Phase 6 — Milestone D: the showpiece

16. `theming` steps 3–9 — wallust, the Plasma colour scheme template, contrast validation across all 18, then the swatch grid
17. `wallpaper` steps 1–4
18. `icons` steps 7–8 + `settings` steps 4–6 — polish pass

**This is the part that looks like the video.** It is deliberately last, because it is the part
that changes nothing about whether the tablet works.

---

## 8. Phase 7 — deferred, and genuinely optional

19. `polkit` — highest risk, lowest reward; keep `polkit-kde` one command away
20. `lock-greeter` lock screen — the only component that can fail **hard**; needs a tested second way in first
21. **Greeter: do not build.** Write an SDDM QML theme instead (`lock-greeter` §2)

Neither of these makes the tablet better at anything. Both can break it.

---

## 9. Dependency graph

```
island-core §11 1-4  ──┬─→ everything
theming §2 tokens    ──┘

icons ──┬─→ osd ──→ control-center sliders
        ├─→ status-capsule
        └─→ everywhere else

media ──┬─→ island rest (EQ) ──→ island expanded
        └─→ control-center media card ──→ lock screen

notifications (service) ──→ control-center notification list
OSK probe ──┬─→ launcher
            ├─→ polkit
            └─→ lock screen
```

Only two things are true bottlenecks: **island-core + tokens**, and **icons**.

---

## 10. Effort shape

Relative, not calendar — and the first component costs disproportionately more than its size
because it is where QML is learned.

| | Size |
|---|---|
| `icons` | **XL** — the long pole; four hand-authored stateful glyphs plus a gallery |
| `control-center` | **L** — largest surface, most sub-views |
| `launcher`, `theming`, `island-core` | **M** |
| `notifications`, `media`, `wallpaper`, `lock-greeter` | **M** |
| `osd`, `status-capsule`, `settings`, `power-menu`, `system-tray`, `polkit` | **S** |

Two structural traps worth their own line, because both are cheap now and expensive later:
the launcher's **diffed ListModel** (`launcher` §8) and island-core's **mask recomputation**
(`island-core` §2.3).

---

## 11. Work that is not code

| Item | Notes |
|---|---|
| Wallpaper library | 18 collections eventually; **two or three unblock the picker** |
| SVG icon set + licence notice | Phase 0 decision; attribution file if ISC/MIT requires |
| The 15 hardware confirmations (§2) | An afternoon, no code |
| Design decisions in §12 | Yours; not discoverable by testing |

Nothing here needs finance, legal, or external design. This project is entirely self-resourced —
worth stating, since that is unusual for the work in this queue.

---

## 12. Decisions still owed

**Closed 2026-08-23** — decided rather than left hanging:
1. ~~Lucide or Phosphor~~ → **Lucide (ISC), 2 px on a 24×24 grid** (`icons` §1)
2. ~~18 themes or fewer~~ → **derivation for all 18, populate three first** (`theming` §12 q1)
4. ~~Icon nominal grid~~ → **24×24** (`icons` §1)

Still genuinely open:
3. Battery permanently at rest, or only when low? (`status-capsule` §11 q1) — **revisit after a
   week of use**; it needs the tablet in hand, not a decision now.

Answerable only on hardware — all covered by §2.

---

## 13. What could still reshape this

| Finding | Effect |
|---|---|
| **Tablet mode does not behave as researched** (§2.1) | Re-open the compositor decision. The largest risk, checked first, costs ten minutes |
| OSK does not work on a Quickshell surface | Launcher, polkit and lock screen all re-scope. Fallbacks exist for each |
| plasmashell will not release the notification name | Drop notifications; Peace mode proxies Plasma's DND |
| Quickshell < 0.3.0 in the COPR | Polkit blocked until it updates. Nothing else affected |
| Blur or animation costs too much battery | Tune animation and the media card's blur first (`icons` §8, `control-center` §8) |

Every one has a documented fallback. **None of them stops you reaching Milestone A**, which is
the point of ordering it this way.
