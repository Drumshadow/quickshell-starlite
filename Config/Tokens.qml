pragma Singleton
import QtQuick

// Semantic token schema + luminance-aware derivation.
// Contract for every component: see ~/specs/quickshell-theming.md §2-§3.
// NOTHING in the shell may reference a colour literal or a wallust colorN.
QtObject {
    id: root

    // ---- raw inputs (replaced by the wallust-generated file, theming §1) ----
    property color background: "#0b100e"
    property color foreground: "#e9f2ef"
    property color accentIn:   "#14b88f"
    property color criticalIn: "#e5534b"
    property color successIn:  "#3fb950"

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

    // ---- derived semantic tokens ----
    //
    // IMPORTANT (learned by running this): a CUSTOM JS function that returns a
    // colour is unreliable inside a property binding here — `mix(...)` and
    // `inkOn(...)` both evaluated to black at startup while returning correct
    // values when called imperatively. Functions returning NUMBERS or BOOLS are
    // fine (`lum()`, `isDark`). So: derive booleans/numbers with functions, and
    // build every colour from Qt's own built-ins (Qt.tint / Qt.rgba) inline.
    readonly property bool  isDark:         lum(background) < 0.35

    readonly property color surface:        background
    readonly property color surfaceVariant: isDark
        ? Qt.tint(background, Qt.rgba(1, 1, 1, 0.08))
        : Qt.tint(background, Qt.rgba(0, 0, 0, 0.07))
    readonly property color ink:      isDark ? inkLight : inkDark
    readonly property color inkDim:   Qt.tint(surface, Qt.rgba(ink.r, ink.g, ink.b, 0.62))
    readonly property color outline:        isDark
        ? Qt.tint(background, Qt.rgba(1, 1, 1, 0.16))
        : Qt.tint(background, Qt.rgba(0, 0, 0, 0.16))

    readonly property color accent:         accentIn
    readonly property bool  accentIsDark:   lum(accentIn) < 0.35
    readonly property color inkOnAccent:       accentIsDark ? inkLight : inkDark
    readonly property color critical:       criticalIn
    readonly property color inkOnCritical:     lum(criticalIn) < 0.35 ? inkLight : inkDark
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
