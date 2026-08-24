# Media / MPRIS service — implementation spec

A shared service, not a screen. Backs the media elements of §1.1, §1.2, §1.7 and §1.12 of
`~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Quickshell/QML.

**Four consumers, no owner until now** — the same gap the icon library and notification server
had. Build the service once, here:

| Consumer | Needs |
|---|---|
| `rest` (island-core §6) | *is something playing* — nothing else |
| `expanded` (island-core §7) | small art, title, artist |
| Control-centre media card (§8) | large art (blurred), title, artist, position, capabilities |
| Lock screen (lock-greeter §7) | title, artist, art, transport controls |

---

## 1. Player selection — the problem MPRIS always has

`Mpris.players` is a list, and on a real desktop it is rarely length 1. Browsers register a
player **per tab** (`org.mpris.MediaPlayer2.chromium.instance1234`), so a forgotten background
video will contend with Spotify for the island.

Taking `players[0]` is the naive answer and it gives you whatever D-Bus enumerated first.

**Policy:**
1. Prefer `Playing` over `Paused` over `Stopped`
2. Among equals, prefer the most recent state change
3. **Be sticky** — once chosen, do not switch away merely because another player appeared or
   changed. Switch on: the current player disappearing, or another transitioning to `Playing`
   while the current is not
4. Ignore players reporting no title and no art
5. Expose the resolved choice as one `activePlayer` binding — **consumers never iterate the
   list themselves**

Stickiness is what stops the island flickering between sources; without it the display changes
under you for reasons you cannot see.

---

## 2. The art race — documented, and easy to get wrong

Straight from Quickshell's docs:

> "A large number of players will update track information, particularly `trackArtUrl`, slightly
> after the `postTrackChanged` signal is emitted."

> **So: never fetch art in response to a track change.** You will fetch the *previous* track's
> art. React to **`trackArtUrl` itself changing**, and treat the track change only as a cue to
> clear the old art.

Sequence: `trackChanged` → clear art, show title/artist → `trackArtUrl` changes → fetch → fade
in. The brief artless moment is correct and honest; a stale cover is worse.

---

## 3. Album art — remote URLs are the real work

`mpris:artUrl` may be `file://` (easy), a `data:` URI (rare), **`https://` (Spotify, and
common)**, or absent.

Remote art means the shell performs network I/O, on battery, for a URL supplied by another
process. Handle it deliberately:

- **Cache on disk**, keyed by a hash of the URL. Repeat plays and album repeats must not refetch
- **Always set `sourceSize`** to the display size before decoding — same lesson as the wallpaper
  grid (wallpaper §5); without it a 1500 px cover is decoded in full to draw a 48 px thumbnail
- **Cap the download** (size and timeout) and fail to the fallback rather than hanging
- **Fail gracefully offline.** No error UI — just no art
- Decode asynchronously; never block the UI thread
- **Fallback:** a themed placeholder derived from the track title, reusing the letter-avatar
  component from notifications §7. Third consumer of that component; still do not draw it twice

Two caches, deliberately: the **disk** cache survives restarts, an in-memory cache of the
current and previous art avoids rework when a track repeats.

---

## 4. Position without polling

Quickshell's docs again:

> "Position usually will not update reactively unless a nonlinear change occurs, however reading
> it will always return the current position." — and Quickshell "does not automatically emit
> `positionChanged` every frame to save CPU."

So reading is always cheap and correct; **you choose the cadence.** Do not poll D-Bus yourself
and do not interpolate — just drive reads at the rate the visible UI actually needs:

| Consumer visible | Cadence |
|---|---|
| Nothing showing position (`rest`, `expanded`) | **no timer at all** |
| Control centre / lock screen with a progress bar | `Timer`, ~1 Hz |
| A slider being dragged | `FrameAnimation`, for that drag only |

> **Gate the timer on a consumer being visible.** At `rest` nobody displays position, so nothing
> should tick. This is the single largest battery saving in this spec, and it is free.

Writing position requires **both `canSeek` and `positionSupported`** (§6).

---

## 5. The EQ bars are decorative — say so before someone builds an FFT

island-core §6: small accent bars animate beside the clock while music plays, and they are the
only continuously-animating thing at `rest`.

> **MPRIS carries no audio levels.** There is no spectrum, no peak, no VU data in the protocol.
> Real levels would require capturing the Pipewire sink monitor and running an FFT in the shell
> — continuous DSP on an Intel N-series tablet, for decoration.
>
> **These bars are procedural animation gated on `PlaybackStatus === Playing`.** Nothing more.
> The source's setup cannot be doing anything else either.

Worth stating plainly, because "make the EQ bars real" is an obvious-sounding improvement that
would cost meaningful battery for no legibility gain. **Stop** the animation on pause — do not
merely hide it, or it keeps burning frames behind an opacity of zero.

---

## 6. Capabilities — do not render dead buttons

Players advertise what they support. Respect it:

| Capability | Governs |
|---|---|
| `canPlay` / `canPause` | the play/pause control |
| `canGoNext` / `canGoPrevious` | transport arrows |
| `canSeek` **and** `positionSupported` | whether the progress bar is draggable |
| `canControl` | whether *any* control is offered |

A radio stream typically cannot seek. Show its progress bar as a **non-interactive** indicator
rather than a slider that ignores you — a control that silently does nothing is worse on touch
than no control, because there is no hover state to hint at it first.

Hide unsupported controls rather than disabling them, except where hiding would reflow the
layout mid-track.

---

## 7. Metadata normalisation

Do this once in the service; no consumer should touch raw MPRIS fields.

- **`xesam:artist` is an array** — join sensibly, do not print `[object Object]`
- **`mpris:length` and position are microseconds** — convert once, centrally
- Missing title → fall back to the URL basename, then to "Unknown"
- Trim whitespace; collapse the empty-string-vs-null distinction
- Expose one flat, typed shape to consumers

### The output-device label is not MPRIS
The control-centre media card shows `Raptor Lake-P/U/H cAVS HDMI / DisplayPort 1 Output`
(control-centre §8). **That is the Pipewire sink description**, not MPRIS metadata. The card
composes two services; do not go hunting for it in `xesam:`.

---

## 8. Consumer contract

One `activePlayer` object, one shape, four subscribers. Consumers bind — they do not query, do
not iterate `Mpris.players`, and do not fetch art themselves.

```
isPlaying   : bool                 → rest (EQ gate)
title       : string               → expanded, control, lock
artist      : string               → expanded, control, lock
artSource   : url | null           → expanded (small), control (blurred), lock
position    : int (seconds)        → control, lock — only while visible (§4)
length      : int (seconds)
canPlay/canPause/canNext/canPrev/canSeek : bool  → §6
play() pause() next() previous() seek()
```

Blur belongs to the **consumer**, not the service (control-centre §8 uses `MultiEffect`); the
service hands over one resolved image.

---

## 9. Battery summary

Everything above, as one list — this is a service that runs all day:

- No D-Bus polling anywhere; all signal-driven
- Position timer **only** while a consumer displaying position is visible (§4)
- `FrameAnimation` only during an actual drag
- EQ bars stopped, not hidden, on pause (§5)
- Art decoded once at display size, cached on disk (§3)
- No network request per track when the album repeats

---

## 10. Build order

1. `Mpris.players` → selection policy with stickiness (§1). Log the choice; no UI.
2. Metadata normalisation (§7); wire `expanded`'s title/artist.
3. `isPlaying` → EQ bars at `rest`, gated and stopped on pause (§5).
4. Art: `file://` only, with the letter-avatar fallback (§3).
5. **Art over `https://`** with disk cache, `sourceSize`, timeout — driven off `trackArtUrl`
   changing, not track change (§2).
6. Capabilities (§6) and transport controls.
7. Position with the visibility-gated timer (§4); progress bar in the control centre.
8. Hand the same object to the lock screen (lock-greeter §7).

Steps 1–3 are enough for the island. Steps 4–5 are where the real work is.

---

## 11. Acceptance criteria

- [ ] With Spotify **and** a browser tab both registered, the island shows the playing one and does not flicker between them
- [ ] Pausing Spotify and playing the browser tab switches the active player; merely opening a tab does not
- [ ] Art matches the **current** track immediately after a change — never the previous one (§2)
- [ ] A track with no art shows the themed letter avatar, not a blank or broken image
- [ ] Playing the same album twice makes **no second network request** (§3)
- [ ] No full-resolution decode of cover art — `sourceSize` set everywhere
- [ ] Offline playback shows art-less cards with no error UI and no hang
- [ ] At `rest` with music playing, **no position timer is running** (§4)
- [ ] EQ bars animate only while playing and **stop** on pause — verify frames are not still being rendered
- [ ] A non-seekable stream shows a non-draggable progress indicator (§6)
- [ ] `xesam:artist` arrays render as readable text; lengths are correct (microseconds handled)
- [ ] Closing the player mid-track leaves every consumer in a clean empty state, not a stale card

## 12. Open questions

1. Do browser per-tab players need explicit filtering, or does §1's stickiness suffice? Decide
   after living with it — over-filtering breaks legitimate browser playback.
2. Should the control centre offer a **player picker** when several exist? The source does not
   have one. Probably not in v1; §1's policy should make it unnecessary.
3. Art cache eviction — size cap, or age? A cap is simpler; pick a number once and move on.
4. Does anything on this system provide art locally for Spotify, avoiding §3 entirely? Worth
   ten minutes on the tablet before building the fetcher.
5. Should `next`/`previous` on the lock screen be available before authentication? Convenient;
   arguably a small information leak (skipping reveals the library). Default: yes for transport,
   no for anything that displays a track list.

## 13. APIs confirmed 2026-08-23

`Quickshell.Services.Mpris` (v0.2.0) → `Mpris` singleton, `MprisPlayer`, `MprisPlaybackState`
(`Playing` / `Paused` / `Stopped`), `MprisLoopState`.

Documented behaviours this spec is built around:
- `positionChanged` is **not** emitted per frame, by design; reading position always returns the
  current value — drive updates with a `Timer` or `FrameAnimation` (§4)
- position is writable only when `canSeek` **and** `positionSupported`
- `trackArtUrl` commonly arrives **after** `postTrackChanged` (§2)

Signals: `trackChanged`, `postTrackChanged`.
