pragma Singleton
import QtQuick
import Quickshell.Services.SystemTray

// System tray. NOT in the source design — it exists because removing Plasma's
// panel removes the tray, and apps that "close to tray" (KeePassXC, Nextcloud,
// Syncthing) would otherwise become unreachable.
//
// Unusually for this project it needs NO gate: StatusNotifierItem separates the
// watcher (plasmashell keeps it) from hosts (multiple allowed), so Quickshell
// registers alongside with nothing to disable.
QtObject {
    id: root
    readonly property var items: SystemTray.items ? SystemTray.items.values : []
    readonly property int count: items.length
    readonly property bool available: count > 0

    // NeedsAttention must escape the control centre — an attention state nobody
    // sees because it is two taps deep is useless.
    // Quickshell 0.3.1 exposes the SNI status enum as `Status` (Passive=0, Active=1,
    // NeedsAttention=2); `SystemTrayStatus` was a ReferenceError on the StarLite and
    // silently disabled the whole binding. Resolve the enum defensively so a rename in
    // either direction degrades to the numeric value instead of killing the property.
    readonly property int _needsAttentionValue:
        (typeof Status !== "undefined" && Status.NeedsAttention !== undefined) ? Status.NeedsAttention : 2
    readonly property bool needsAttention: {
        for (var i = 0; i < items.length; i++)
            if (items[i] && items[i].status === _needsAttentionValue) return true
        return false
    }

    function activate(item) {
        if (!item) return
        // onlyMenu means activation does nothing — respect it, or tapping some
        // items silently does nothing and reads as broken
        if (item.onlyMenu) { if (item.hasMenu) item.display(null, 0, 0); return }
        item.activate()
    }
    function menu(item) {
        if (item && item.hasMenu) item.display(null, 0, 0)
    }
}
