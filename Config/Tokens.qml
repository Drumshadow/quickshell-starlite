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
    // Pick whichever ink reads better on `bg` — this is what makes light schemes work.
    function inkOn(bg) {
        var light = Qt.rgba(0.96,0.95,0.94,1), dark = Qt.rgba(0.05,0.06,0.06,1)
        return contrast(light, bg) >= contrast(dark, bg) ? light : dark
    }

    // ---- derived semantic tokens ----
    readonly property bool  isDark:         lum(background) < 0.35

    readonly property color surface:        background
    readonly property color surfaceVariant: isDark ? lift(background, 0.07) : sink(background, 0.06)
    readonly property color onSurface:      inkOn(surface)
    readonly property color onSurfaceDim:   mix(onSurface, surface, 0.45)
    readonly property color outline:        isDark ? lift(background, 0.14) : sink(background, 0.14)

    readonly property color accent:         accentIn
    readonly property color onAccent:       inkOn(accentIn)
    readonly property color critical:       criticalIn
    readonly property color onCritical:     inkOn(criticalIn)
    readonly property color success:        successIn

    // A dark drop shadow reads as depth on dark and as dirt on white (theming §3).
    readonly property color shadow:         Qt.rgba(0, 0, 0, isDark ? 0.55 : 0.18)

    // ---- metrics (settings §4; icons scale from font size, icons §6) ----
    property int  barHeight: 30
    property int  fontSize:  16
    readonly property int iconSize: Math.round(fontSize * 1.5)
    readonly property int touchMin: 48
    readonly property int radius:   10

    // ---- one Behavior here cross-fades the entire shell (theming §6) ----
    Behavior on background { ColorAnimation { duration: 200 } }
    Behavior on foreground { ColorAnimation { duration: 200 } }
    Behavior on accentIn   { ColorAnimation { duration: 200 } }

    // Contrast self-check, surfaced by the gallery (theming §8).
    readonly property var audit: [
        { pair: "onSurface/surface",    ratio: contrast(onSurface, surface),      min: 4.5 },
        { pair: "onSurfaceDim/surface", ratio: contrast(onSurfaceDim, surface),   min: 4.5 },
        { pair: "onAccent/accent",      ratio: contrast(onAccent, accent),        min: 4.5 },
        { pair: "critical/surface",     ratio: contrast(critical, surface),       min: 3.0 }
    ]
}
