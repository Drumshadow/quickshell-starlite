pragma Singleton
import QtQuick

// Semantic token schema + luminance-aware derivation.
// Contract for every component: see ~/specs/quickshell-theming.md §2-§3.
// NOTHING in the shell may reference a colour literal or a wallust colorN.
QtObject {
    id: root

    // ---- raw inputs ----
    // Sourced from the palette registry today; wallust replaces this with a
    // generated file later (docs/quickshell-theming.md §1). Either way it is
    // FOUR colours in, and everything else derives.
    readonly property color background: Themes.active.bg
    readonly property color foreground: Themes.active.fg
    readonly property color accentIn:   Themes.active.accent
    readonly property color criticalIn: Themes.active.critical
    readonly property color successIn:  Themes.active.success

    // ---- colour maths ----
    function _lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    function lum(c)  { return 0.2126*_lin(c.r) + 0.7152*_lin(c.g) + 0.0722*_lin(c.b) }
    function contrast(a, b) {
        var la = lum(a), lb = lum(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r-a.r)*t, a.g + (b.g-a.g)*t, a.b + (b.b-a.b)*t, 1)
    }
    // Qt.lighter() is useless on near-black; mix toward white/black instead.
    function lift(c, t)  { return mix(c, Qt.rgba(1,1,1,1), t) }
    function sink(c, t)  { return mix(c, Qt.rgba(0,0,0,1), t) }
    // Two inks; everything picks between them by measured luminance.
    //
    // NOTE (learned by running this): do NOT write
    //     readonly property color ink: inkOn(surface)
    // A colour-returning function inside a property binding evaluated to
    // #000000 here while the same call returned #f5f2f0 imperatively — an
    // initialisation-order trap, and NaN comparisons silently fall through to
    // the wrong branch. Derive a BOOLEAN first, then pick. Booleans are safe
    // in bindings; colour-returning functions are not.
    // WARNING: never name a property `on` + Uppercase (onSurface, onAccent...).
    // QML parses `onFoo` as a signal handler, so such a property silently reads
    // back as default-constructed black. This cost an hour; the Material Design
    // token names (`onSurface`, `onPrimary`) walk straight into it.
    readonly property color inkLight: "#f5f2f0"
    readonly property color inkDark:  "#0d1110"

    function isDarkColor(c) { return lum(c) < 0.35 }
    function inkOn(bg) { return isDarkColor(bg) ? inkLight : inkDark }

    // Contrast audit across 19 wallust themes (2026-09-03) killed the fixed
    // luminance threshold: mid-luminance accents (Nord #81A1C1, Kanagawa,
    // Solarized) got the wrong ink at 2.4:1. Pick the ink that MEASURES higher.
    function lightInkBetter(c) { return contrast(inkLight, c) >= contrast(inkDark, c) }
    // How far (0..0.6) to push a fill AWAY from its ink until ink-on-fill >= 4.5.
    // Returns a number, so it is safe inside a colour binding (see the note below).
    function pushFor(fill, useLight) {
        var ink = useLight ? inkLight : inkDark
        var away = useLight ? Qt.rgba(0,0,0,1) : Qt.rgba(1,1,1,1)
        for (var t = 0; t <= 0.6; t += 0.05) if (contrast(ink, mix(fill, away, t)) >= 4.5) return t
        return 0.6
    }
    // How far to pull a status colour toward the surface ink until it reads >= 3:1.
    function liftFor(c, bg, useLight) {
        var ink = useLight ? inkLight : inkDark
        for (var t = 0; t <= 0.6; t += 0.05) if (contrast(mix(c, ink, t), bg) >= 3.0) return t
        return 0.6
    }

    // ---- derived semantic tokens ----
    //
    // IMPORTANT (learned by running this): a CUSTOM JS function that returns a
    // colour is unreliable inside a property binding here — `mix(...)` and
    // `inkOn(...)` both evaluated to black at startup while returning correct
    // values when called imperatively. Functions returning NUMBERS or BOOLS are
    // fine (`lum()`, `isDark`). So: derive booleans/numbers with functions, and
    // build every colour from Qt's own built-ins (Qt.tint / Qt.rgba) inline.
    readonly property bool  isDark:         lum(background) < 0.35
    readonly property bool  useLightInk:    lightInkBetter(background)

    readonly property color surface:        background
    readonly property color surfaceVariant: isDark
        ? Qt.tint(background, Qt.rgba(1, 1, 1, 0.08))
        : Qt.tint(background, Qt.rgba(0, 0, 0, 0.07))
    readonly property color ink:      useLightInk ? inkLight : inkDark
    readonly property color inkDim:   Qt.tint(surface, Qt.rgba(ink.r, ink.g, ink.b, 0.62))
    readonly property color outline:        isDark
        ? Qt.tint(background, Qt.rgba(1, 1, 1, 0.16))
        : Qt.tint(background, Qt.rgba(0, 0, 0, 0.16))

    readonly property bool  accentUseLight: lightInkBetter(accentIn)
    readonly property real  accentPush:     pushFor(accentIn, accentUseLight)
    // pushed away from its ink only when the raw accent cannot carry text (Gruvbox,
    // Latte, Paper sat at 4.4-4.5); zero for the other sixteen
    readonly property color accent:         accentUseLight
        ? Qt.tint(accentIn, Qt.rgba(0, 0, 0, accentPush))
        : Qt.tint(accentIn, Qt.rgba(1, 1, 1, accentPush))
    readonly property bool  accentIsDark:   accentUseLight
    readonly property color inkOnAccent:       accentUseLight ? inkLight : inkDark
    readonly property real  criticalLift:   liftFor(criticalIn, background, useLightInk)
    readonly property color critical:       Qt.tint(criticalIn, Qt.rgba(ink.r, ink.g, ink.b, criticalLift))
    readonly property color inkOnCritical:     lightInkBetter(critical) ? inkLight : inkDark
    readonly property color success:        successIn

    // A dark drop shadow reads as depth on dark and as dirt on white.
    readonly property color shadow:         Qt.rgba(0, 0, 0, isDark ? 0.55 : 0.18)

    // ---- metrics (settings §4; icons scale from font size, icons §6) ----
    // NOTE: touch target size lives in Services/InputMode, not here — it is a
    // form-factor question, not a theme constant. Components use
    // InputMode.touchTarget so they stay generic across laptop/tablet.
    property int  barHeight: 30
    property int  fontSize:  16
    readonly property int iconSize: Math.round(fontSize * 1.5)
    readonly property int radius:   10

    // Theme cross-fade (theming §6) deliberately NOT enabled yet: Behaviors on
    // these inputs animate from a default value at startup, which is what
    // exposed the binding trap documented above. Re-add when the theme switcher
    // exists and can be tested end to end.

    // Contrast self-check, rendered by the gallery (theming §8).
    // Individual real properties — an array-of-objects binding did NOT
    // re-evaluate and reported stale ratios.
    readonly property real cOnSurface:    contrast(ink, surface)
    readonly property real cOnSurfaceDim: contrast(inkDim, surface)
    readonly property real cOnAccent:     contrast(inkOnAccent, accent)
    readonly property real cCritical:     contrast(critical, surface)
}
