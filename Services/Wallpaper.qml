pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper. Plasma owns it, so this needs no daemon (no swww/hyprpaper) and
// persistence is free -- Plasma stores the choice, exactly like wallust stores
// the theme (docs/quickshell-wallpaper.md §2). The library scan lives in
// tools/tablet/starlite-wallpapers (installed to ~/.local/bin) and is run ONCE
// per shell start, then cached (§4: never re-walk the tree on every open).
QtObject {
    id: root
    readonly property string root: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property string _bin: Quickshell.env("HOME") + "/.local/bin/starlite-wallpapers"

    property var all: []            // [{path, collection, name}]
    property string collection: "all"
    property string current: ""
    property bool applying: false
    property string error: ""

    readonly property var collections: {
        var seen = {}, out = ["all"]
        for (var i = 0; i < all.length; i++) {
            var c = all[i].collection
            if (!seen[c]) { seen[c] = true; out.push(c) }
        }
        return out
    }
    readonly property var items: {
        if (collection === "all") return all
        var out = []
        for (var i = 0; i < all.length; i++) if (all[i].collection === collection) out.push(all[i])
        return out
    }
    readonly property int count: items.length
    readonly property bool available: all.length > 0

    // theme -> wallpaper (§3): only when a collection of that name exists
    function selectCollection(id) { if (collections.indexOf(id) >= 0) collection = id }
    function nextCollection() {
        var i = collections.indexOf(collection)
        collection = collections[(i + 1) % collections.length]
    }

    property var _scan: Process {
        command: [root._bin]
        running: !Env.mock
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.all = JSON.parse(this.text) } catch (e) { root.all = []; root.error = "scan failed" }
            }
        }
    }
    property var _readCurrent: Process {
        command: [root._bin, "--current"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root.current = String(this.text).trim() }
    }
    property var _apply: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector { id: applyErr }
        onExited: function (code) {
            root.applying = false
            if (code === 0) { root.error = ""; root._readCurrent.running = true }
            else root.error = "Wallpaper failed: " + (String(applyErr.text).trim().split("\\n").pop() || ("exit " + code)).substring(0, 80)
        }
    }
    function _quote(s) { return "'" + String(s).split("'").join("'\\''") + "'" }
    function apply(path) {
        if (!path) return
        if (Env.mock) { current = path; return }
        if (applying) return
        applying = true; error = ""
        // §10 q4: keep the lock screen coherent -- Plasma stores it separately
        _apply.command = ["sh", "-c",
            "plasma-apply-wallpaperimage " + _quote(path) +
            " && kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image " + _quote(path)]   // plain path: Plasma accepts it, and "file:" + "//" would read as a comment to lint
        _apply.running = true
    }
    function rescan() { if (!Env.mock) { _scan.running = true; _readCurrent.running = true } }
}
