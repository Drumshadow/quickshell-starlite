pragma Singleton
import QtQuick
import Quickshell

// Application list + launching. Deliberately NOT mocked: reading desktop
// entries is harmless, and launching for real is the point of the vertical
// slice. `lastLaunched` records what happened so tests can assert on it.
QtObject {
    id: root
    property string lastLaunched: ""

    readonly property var all: DesktopEntries.applications

    // simple ranked match; the full scoring model is docs/quickshell-launcher.md §5
    function search(q) {
        var out = []
        if (!all) return out
        var needle = (q || "").toLowerCase().trim()
        for (var i = 0; i < all.values.length; i++) {
            var e = all.values[i]
            if (!e || !e.name) continue
            var n = e.name.toLowerCase()
            var score = -1
            if (needle === "") score = 0
            else if (n === needle) score = 1000
            else if (n.indexOf(needle) === 0) score = 800
            else if (n.indexOf(needle) >= 0) score = 500
            else if ((e.genericName || "").toLowerCase().indexOf(needle) >= 0) score = 300
            if (score >= 0) out.push({ entry: e, score: score, name: e.name })
        }
        out.sort(function (a, b) { return b.score - a.score || a.name.localeCompare(b.name) })
        return out.slice(0, 8)
    }

    function launch(entry) {
        if (!entry) return false
        root.lastLaunched = entry.id || entry.name
        entry.execute()          // wraps Quickshell.execDetached — survives a shell restart
        return true
    }
}
