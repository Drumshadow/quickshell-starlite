import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Config"
import "../Services" as Sys

// ONE surface, full-width, mapped for the life of the session.
//
//  * `visible` is NEVER set false anywhere (KWin bug 503121).
//  * Full-width anchoring keeps surface geometry stable, supplies the top-edge
//    input strip, and lets the drawn island resize freely.
//  * The mask is what makes a full-width surface tolerable, and it MUST track
//    the drawn island or the top of the desktop silently stops responding.
PanelWindow {
    id: win
    anchors { top: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    implicitHeight: 560

    WlrLayershell.namespace: "island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:
        IslandState.focusFor(IslandState.current) === "Exclusive"
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

    // ---- OSD: event-driven from the services, not from a keypress ----------
    // Bind to the VALUE so it works for every source of change, not only ours
    // (docs/quickshell-osd.md §2). `_armed` is the suppression list: no OSD on
    // startup or first binding (§8).
    property bool _armed: false
    Timer { interval: 900; running: true; repeat: false; onTriggered: win._armed = true }

    Connections {
        target: Sys.Audio
        function onVolumeChanged() { win._showOsd("volume") }
        function onMutedChanged()  { win._showOsd("volume") }
    }
    Connections {
        target: Sys.Backlight
        function onValueChanged() { win._showOsd("brightness") }
    }

    property string osdKind: "volume"
    function _showOsd(kind) {
        if (!win._armed) return
        // transients never interrupt a user panel (island-core §3)
        if (IslandState.prio(IslandState.current) >= 2) return
        win.osdKind = kind
        IslandState.request("osd")
        osdTimer.restart()
    }
    Timer {
        id: osdTimer
        interval: 2500          // raised from the source's ~1.5s: on a tablet you
        repeat: false           // are less likely to be watching the top edge
        onTriggered: if (IslandState.current === "osd") IslandState.release()
    }

    // ---- IPC: one target, per island-core §9 -------------------------------
    IpcHandler {
        target: "island"
        function open(state: string): void  { IslandState.request(state) }
        function toggle(state: string): void { IslandState.toggle(state) }
        function close(): void { IslandState.release() }
        function state(): string { return IslandState.current }

        // Service health — proves real mode degrades honestly rather than
        // pretending, when a daemon is absent.
        function theme(id: string): void { Themes.set(id) }

        // Drive the power menu so the arm-to-confirm floor can be tested. The
        // mock Session never actually acts; it records lastAction.
        function powerPress(id: string): void {
            if (IslandState.current === "power" && loader.item)
                loader.item.press(id, id !== "lock" && id !== "suspend")
        }
        function powerArmed(): string {
            return (IslandState.current === "power" && loader.item) ? loader.item.armed : ""
        }
        function lastAction(): string { return Sys.Session.lastAction }
        function themes(): string { return Themes.names() + " | current=" + Themes.current }
        function contrast(): string {
            return "ink=" + Tokens.cOnSurface.toFixed(2)
                 + " dim=" + Tokens.cOnSurfaceDim.toFixed(2)
                 + " onAccent=" + Tokens.cOnAccent.toFixed(2)
                 + " isDark=" + Tokens.isDark
        }

        function health(): string {
            return "mock=" + Sys.Env.mock
                 + " audio=" + Sys.Audio.available
                 + " power=" + Sys.Power.available
                 + " media=" + Sys.Media.available
                 + " net="   + Sys.Network.available
                 + " tray="  + Sys.Tray.count
                 + " | vol=" + Sys.Audio.volume.toFixed(2)
                 + " bat=" + Sys.Power.percentage + "/" + Sys.Power.state
                 + " net=" + Sys.Network.type
        }

        // Drive the launcher without synthetic input. A headless container has
        // no logind seat, so the compositor advertises no input capabilities and
        // no client can receive pointer/keyboard events at all. The only way to
        // change that is to mount the HOST's /dev/input, which would inject real
        // events into the developer's machine — not acceptable. These hooks test
        // everything except event delivery; delivery itself is a hardware check.
        function type(text: string): void {
            if (IslandState.current === "launcher" && loader.item) loader.item.query = text
        }
        function activate(): void {
            if (IslandState.current === "launcher" && loader.item) loader.item.activate()
        }
        function results(): string {
            if (IslandState.current !== "launcher" || !loader.item) return ""
            var r = loader.item.results, out = []
            for (var i = 0; i < r.length; i++) out.push(r[i].name)
            return out.join(",")
        }
    }

    // ---- the drawn island --------------------------------------------------
    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        radius: Math.min(height / 2, Tokens.radius * 1.8)
        color: Tokens.surface
        implicitWidth:  loader.item ? loader.item.implicitWidth  + Tokens.fontSize * 1.4 : 90
        implicitHeight: loader.item ? loader.item.implicitHeight + Tokens.fontSize * 0.5 : Settings.barHeight
        width: implicitWidth
        height: implicitHeight

        Behavior on width  { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Loader {
            id: loader
            anchors.centerIn: parent
            source: {
                switch (IslandState.current) {
                case "expanded": return "ExpandedContent.qml"
                case "osd":      return "OsdContent.qml"
                case "launcher": return "LauncherContent.qml"
                case "control":  return "ControlContent.qml"
                case "theme":    return "ThemeContent.qml"
                case "power":    return "PowerContent.qml"
                case "settings": return "SettingsContent.qml"
                case "wallpaper": return "WallpaperContent.qml"
                default:         return "RestContent.qml"
                }
            }
            onLoaded: {
                if (IslandState.current === "osd" && item) item.kind = win.osdKind
                if (IslandState.current === "launcher" && item) {
                    item.launched.connect(function () { IslandState.release() })
                    // a layer surface having keyboard focus is not enough — the
                    // field inside it must take ACTIVE focus or keystrokes go nowhere
                    if (item.focusInput) item.focusInput()
                }
                if ((IslandState.current === "control" || IslandState.current === "settings") && item)
                    item.navigate.connect(function (s) { IslandState.request(s) })
            }
        }

        // tap the pill to expand; tap again to collapse
        MouseArea {
            anchors.fill: parent
            enabled: IslandState.current === "rest" || IslandState.current === "expanded"
            onClicked: IslandState.toggle("expanded")
        }
    }

    // full-width strip: the summon gesture target, reachable from any top corner
    Item {
        id: topStrip
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 20
    }

    // tap-outside dismiss, only while a panel is open — never swallows clicks at rest
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: win.panelOpen && IslandState.current !== "auth"
        onClicked: IslandState.release()
    }

    // ---- input mask --------------------------------------------------------
    // Recomputed whenever the island resizes or the state changes; when a panel
    // is open the whole surface is live so tap-outside works.
    // NOTE: `Region { item: null }` silently disables the ENTIRE mask, so the
    // surface accepts no input at all. Use explicit geometry instead.
    readonly property bool panelOpen: IslandState.prio(IslandState.current) >= 2

    mask: Region {
        // the island itself — or the whole surface while a panel is open, so
        // tap-outside can dismiss it
        Region {
            x: win.panelOpen ? 0 : island.x
            y: win.panelOpen ? 0 : island.y
            width:  win.panelOpen ? win.width  : island.width
            height: win.panelOpen ? win.height : island.height
        }
        // top-edge summon strip, always live
        Region { x: 0; y: 0; width: win.width; height: 20 }
    }
}
