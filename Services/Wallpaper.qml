pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper. Plasma owns it, so this needs no daemon (no swww/hyprpaper) and
// persistence is free — Plasma stores the choice, exactly like wallust stores
// the theme.
QtObject {
    id: root
    readonly property string root_: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property string root: root_
    property string collection: "all"
    property var items: []
    property string current: ""

    readonly property int count: items.length
    readonly property bool available: count > 0

    // TODO(real): scan root_ for collections (one folder per theme) and apply
    // with `plasma-apply-wallpaperimage <path>`. Deliberately not shelling out
    // yet — the library is empty until wallpapers are gathered, and an empty
    // picker with an honest empty state is better than a broken one.
    function apply(path) {
        current = path
        if (Env.mock) return
        // Process { command: ["plasma-apply-wallpaperimage", path] }
    }
}
