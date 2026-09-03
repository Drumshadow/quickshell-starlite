pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Services" as Sys

// Theme registry + the wallust pipeline (docs/quickshell-theming.md §1, §4, §9).
//
// wallust is the source of truth: `set(id)` runs the theme's wallust command,
// which renders ~/.config/quickshell-starlite/tokens.json, then
// starlite-theme-post derives + applies the Plasma colour scheme. On exit 0 the
// shell reloads the token file and every binding follows. On failure nothing
// changes -- never half-apply.
//
// ThemePreviews (generated on the tablet from wallust's own output) gives the
// swatch grid each theme's colours without applying it, and doubles as the
// compiled-in FALLBACK palette: if the token file is missing or unparseable the
// shell renders the preview entry rather than unstyled (§1).
QtObject {
    id: root

    readonly property var palettes: ThemePreviews.list
    readonly property string tokensPath: Quickshell.env("HOME") + "/.config/quickshell-starlite/tokens.json"

    property string current: "ariadne"
    property bool applying: false
    property string error: ""

    function byId(id) {
        for (var i = 0; i < palettes.length; i++) if (palettes[i].id === id) return palettes[i]
        return palettes[0]
    }
    readonly property var preview: byId(current)

    // ---- the token file wallust writes ----
    property var _file: FileView {
        path: root.tokensPath
        onLoaded: root._syncCurrentFromFile()
        onLoadFailed: function (err) { /* fallback palette stays in force */ }
        JsonAdapter {
            id: tok
            property string background: ""
            property string foreground: ""
            property string accent: ""
            property string critical: ""
            property string success: ""
        }
    }
    readonly property bool fileValid: !Sys.Env.mock && _file.loaded && tok.background !== "" && tok.foreground !== ""

    // What Tokens.qml consumes: five colours. Strings are fine for `color` props.
    readonly property var active: fileValid
        ? ({ bg: tok.background, fg: tok.foreground, accent: tok.accent || preview.accent,
             critical: tok.critical || preview.critical, success: tok.success || preview.success })
        : ({ bg: preview.bg, fg: preview.fg, accent: preview.accent, critical: preview.critical, success: preview.success })

    // On startup the theme that is active is simply the one on disk (§9): match
    // the file's background+foreground to a known preview so the grid highlights it.
    function _syncCurrentFromFile() {
        if (!fileValid) return
        var b = String(tok.background).toLowerCase(), f = String(tok.foreground).toLowerCase()
        for (var i = 0; i < palettes.length; i++)
            if (String(palettes[i].bg).toLowerCase() === b && String(palettes[i].fg).toLowerCase() === f) { current = palettes[i].id; return }
    }

    // ---- applying (§4): shell runs wallust, waits for exit, then reloads ----
    property string _pendingId: ""
    property var _apply: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector { id: applyErr }
        onExited: function (code) {
            root.applying = false
            if (code === 0) {
                root.current = root._pendingId
                root.error = ""
                root._file.reload()
            } else {
                var msg = String(applyErr.text).trim().split("\n").pop() || ("exit " + code)
                root.error = "Theme failed: " + msg.substring(0, 80)
            }
            root._pendingId = ""
        }
    }
    function _quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function set(id) {
        var p = null
        for (var i = 0; i < palettes.length; i++) if (palettes[i].id === id) p = palettes[i]
        if (!p) return false
        if (Sys.Env.mock) { current = id; return true }
        if (applying) return false
        var cmd = []
        for (var j = 0; j < p.cmd.length; j++) cmd.push(_quote(p.cmd[j]))
        _pendingId = id; applying = true; error = ""
        _apply.command = ["sh", "-c", "export PATH=\"$HOME/.local/bin:$PATH\"; " + cmd.join(" ") + " && starlite-theme-post"]
        _apply.running = true
        return true
    }
    function names() {
        var out = []
        for (var i = 0; i < palettes.length; i++) out.push(palettes[i].id)
        return out.join(",")
    }
}
