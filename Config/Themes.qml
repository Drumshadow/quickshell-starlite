pragma Singleton
import QtQuick

// Palette registry. Only the RAW inputs live here; every semantic token is
// derived in Tokens.qml, so a new palette is four colours and nothing else.
//
// Three to start, deliberately (docs/quickshell-theming.md §12 q1): one dark,
// one light, one saturated-accent. The contrast audit is per-theme work — get
// it passing on a small set, then scale. The remaining schemes are a data task.
QtObject {
    id: root

    readonly property var palettes: [
        { id: "ariadne",     bg: "#0b100e", fg: "#e9f2ef", accent: "#14b88f", critical: "#e5534b", success: "#3fb950" },
        { id: "e-ink",       bg: "#f2f1ec", fg: "#1a1a18", accent: "#3a3a38", critical: "#8c2f26", success: "#2f6b3a" },
        { id: "tokyo-night", bg: "#1a1b26", fg: "#c0caf5", accent: "#7aa2f7", critical: "#f7768e", success: "#9ece6a" },
        { id: "rose-pine",   bg: "#191724", fg: "#e0def4", accent: "#ebbcba", critical: "#eb6f92", success: "#31748f" },
        { id: "gruvbox",     bg: "#282828", fg: "#ebdbb2", accent: "#d79921", critical: "#cc241d", success: "#98971a" },
        { id: "nord",        bg: "#2e3440", fg: "#eceff4", accent: "#88c0d0", critical: "#bf616a", success: "#a3be8c" }
    ]

    property string current: "ariadne"

    readonly property var active: {
        for (var i = 0; i < palettes.length; i++)
            if (palettes[i].id === current) return palettes[i]
        return palettes[0]
    }

    function set(id) {
        for (var i = 0; i < palettes.length; i++)
            if (palettes[i].id === id) { current = id; return true }
        return false
    }
    function names() {
        var out = []
        for (var i = 0; i < palettes.length; i++) out.push(palettes[i].id)
        return out.join(",")
    }
}
