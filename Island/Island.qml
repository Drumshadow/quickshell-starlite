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

    // Warm the service singletons at startup. They are lazy: nothing on the rest
    // surface references Power/Network/Tray, so on hardware their UPower /
    // NetworkManager / SNI connections only began on the first expand -- and the
    // expanded view then showed placeholders for ~20-30 s (StarLite, 2026-09-03).
    // Reading one property each is enough to instantiate them; the values are
    // discarded on purpose.
    Component.onCompleted: {
        void(Sys.Power.available); void(Sys.Network.available)
        void(Sys.Tray.count);      void(Sys.Backlight.value)
        void(Sys.Media.available)
        // InputMode's tablet-mode probe and DesktopEntries are lazy too: without
        // this the first launcher open saw oskNeeded=false (no keyboard) and an
        // empty app list (StarLite, 2026-09-03).
        void(Sys.InputMode.tabletMode); void(Sys.Apps.all)
        void(Sys.NightLight.running); void(Sys.Notifications.peaceMode); void(Sys.Bluetooth.enabled)
        void(Sys.Wallpaper.count)      // the library scan runs once, at startup, not on first open
    }

    WlrLayershell.namespace: "island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:
        IslandState.focusFor(IslandState.current) === "Exclusive" ? WlrKeyboardFocus.Exclusive
      : IslandState.focusFor(IslandState.current) === "OnDemand"  ? WlrKeyboardFocus.OnDemand
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

    // launcher §2: the KDE global shortcut (Alt+D) calls `qs ipc call launcher toggle`.
    // Thin alias over the island state machine so the spec's command works verbatim.
    IpcHandler {
        target: "launcher"
        function toggle(): void { IslandState.toggle("launcher") }
        function open(): void   { IslandState.request("launcher") }
        function close(): void  { if (IslandState.current === "launcher") IslandState.release() }
    }

    // theming §4: reload the token file after an external `wallust theme`
    IpcHandler {
        target: "theme"
        function reload(): void { Themes.reload() }
        function set(id: string): void { Themes.set(id) }
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
        function themeState(): string {
            return "current=" + Themes.current + " applying=" + Themes.applying
                 + " file=" + Themes.fileValid + " bg=" + Tokens.background + " accent=" + Tokens.accent
                 + (Themes.error !== "" ? " error=" + Themes.error : "")
        }
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
                 + " net=" + Sys.Network.type + "/" + Sys.Network.ssid + "/" + Sys.Network.strength
                 + " osk=" + (Sys.Osk.lastResult === "" ? "never" : Sys.Osk.lastResult)
                 + " bt=" + Sys.Bluetooth.enabled + "/" + Sys.Bluetooth.devices.length + "dev"
                 + " night=" + Sys.NightLight.running + (Sys.NightLight.available ? "" : "(n/a)")
                 + " peace=" + Sys.Notifications.peaceMode
                 + " session=" + (Sys.Session.lastResult === "" ? "never" : Sys.Session.lastResult)
        }
        // control-centre sub-views, drivable without a finger
        function view(v: string): void {
            if (IslandState.current === "control" && loader.item) loader.item.view = v
        }
        function wifi(): string {
            var l = Sys.Network.networks, out = []
            for (var i = 0; i < l.length; i++) {
                var n = l[i]
                out.push(n.name + (n.connected ? "*" : "") + (n.known ? "+" : "") + (Sys.Network.isOpen(n) ? "" : "#") + Sys.Network.strengthOf(n))
            }
            return "scanning=" + Sys.Network.scanning + " " + out.join(",")
        }
        function sinks(): string {
            var l = Sys.Audio.sinks, out = []
            for (var i = 0; i < l.length; i++) out.push(Sys.Audio.sinkLabel(l[i]) + (Sys.Audio.isDefaultSink(l[i]) ? "*" : ""))
            return out.join(",")
        }
        function wallpapers(): string {
            return "count=" + Sys.Wallpaper.all.length + " collections=" + Sys.Wallpaper.collections.join("/")
                 + " current=" + Sys.Wallpaper.current + (Sys.Wallpaper.error !== "" ? " error=" + Sys.Wallpaper.error : "")
        }
        function wallpaper(path: string): void { Sys.Wallpaper.apply(path) }
        // Milestone C backends, drivable without a finger
        function night(): void { Sys.NightLight.toggle() }
        function peace(): void { Sys.Notifications.setPeace(!Sys.Notifications.peaceMode) }
        function bluetooth(on: bool): void { Sys.Bluetooth.setEnabled(on) }

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
            var r = loader.item.resultsModel !== undefined ? loader.item.resultsModel : loader.item.results, out = []
            if (r && r.count !== undefined) {           // ListModel (launcher §8)
                for (var i = 0; i < r.count; i++) out.push(r.get(i).name)
            } else if (r && r.length !== undefined) {   // plain array (older content)
                for (var j = 0; j < r.length; j++) out.push(r[j].name)
            }
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
                    if (item.dismissed) item.dismissed.connect(function () { IslandState.release() })
                    if (item.screenHeight !== undefined && win.screen) item.screenHeight = win.screen.height
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
