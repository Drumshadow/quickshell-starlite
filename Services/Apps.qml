pragma Singleton
import QtQuick
import Quickshell

// Application list + launching. Deliberately NOT mocked: reading desktop
// entries is harmless, and launching for real is the point. `lastLaunched`
// records what happened so tests can assert on it.
//
// Ranking is docs/quickshell-launcher.md §5, verbatim. Frecency (step 7) is not
// built yet: ties break on name only.
QtObject {
    id: root
    property string lastLaunched: ""

    readonly property var all: DesktopEntries.applications

    // case- and diacritic-insensitive folding, done once per field per query
    function fold(s) {
        if (s === undefined || s === null) return ""
        return String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
    }
    function basename(cmd) {
        if (!cmd || !cmd.length) return ""
        const c = String(cmd[0] || "")
        return c.substring(c.lastIndexOf("/") + 1)
    }
    // subsequence match; denser (shorter span) scores higher
    function fuzzy(name, q) {
        let i = 0, j = 0, first = -1, last = -1
        while (i < name.length && j < q.length) {
            if (name[i] === q[j]) { if (first < 0) first = i; last = i; j++ }
            i++
        }
        if (j < q.length) return -1
        const span = last - first + 1
        return 100 + Math.max(0, 50 - (span - q.length))
    }

    // §5 score table. -1 = no match.
    function score(e, q) {
        const n = fold(e.name)
        if (!n) return -1
        if (q === "") return 0
        if (n === q) return 1000
        const p = n.indexOf(q)
        if (p === 0) return 800
        // word-boundary start: previous char is a separator (kept as a string so
        // the repo's bracket-balance lint does not trip on a regex class)
        if (p > 0 && " -_(./".indexOf(n[p - 1]) >= 0) return 700
        if (p > 0) return 500
        const kw = e.keywords
        if (kw && kw.length) for (let k = 0; k < kw.length; k++) if (fold(kw[k]).indexOf(q) >= 0) return 400
        if (fold(e.genericName).indexOf(q) >= 0 || fold(e.comment).indexOf(q) >= 0) return 300
        if (fold(basename(e.command)).indexOf(q) >= 0) return 200
        return fuzzy(n, q)
    }

    // Returns [{ id, name, generic, icon, score }], best first, capped at 50.
    // Entries are looked up again by id at launch time (DesktopEntries.byId),
    // so a ListModel can hold plain strings.
    function search(q) {
        const out = []
        if (!all) return out
        const needle = fold(q).trim()
        const vals = all.values
        for (let i = 0; i < vals.length; i++) {
            const e = vals[i]
            if (!e || !e.name) continue
            const s = score(e, needle)
            if (s < 0) continue
            out.push({ id: e.id || e.name, name: e.name, generic: e.genericName || "",
                       icon: iconFor(e), score: s })
        }
        out.sort(function (a, b) { return b.score - a.score || a.name.localeCompare(b.name) })
        return out.slice(0, 50)
    }

    function byId(id) {
        if (!all) return null
        const vals = all.values
        for (let i = 0; i < vals.length; i++) if (vals[i] && (vals[i].id === id || vals[i].name === id)) return vals[i]
        return null
    }

    // themed icon path or "" (the row then falls back to the letter avatar)
    function iconFor(e) {
        if (!e || !e.icon) return ""
        try { return Quickshell.iconPath(e.icon, true) || "" } catch (err) { return "" }
    }

    function launch(entry) {
        if (!entry) return false
        root.lastLaunched = entry.id || entry.name
        entry.execute()          // wraps Quickshell.execDetached — survives a shell restart
        return true
    }
    function launchId(id) { return launch(byId(id)) }
}
