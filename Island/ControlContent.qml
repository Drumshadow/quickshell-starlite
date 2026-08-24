import QtQuick
import "../Config"
import "../Icons"
import "../Components"
import "../Services" as Sys

// Control centre. Deliberately WITHOUT the notification list: that section is
// gated on whether plasmashell will release org.freedesktop.Notifications, which
// cannot be tested off-hardware (docs/quickshell-notifications.md §0).
Item {
    id: root
    property string view: "main"        // main | wifi | audio | bluetooth
    signal navigate(string state)

    implicitWidth: Tokens.fontSize * 22
    implicitHeight: stack.implicitHeight

    function back() { view = "main" }

    // sub-views push in horizontally while the height animates to the incoming
    // content — one driver, or the two visibly desync
    Item {
        id: stack
        width: parent.width
        implicitHeight: (root.view === "main" ? mainCol.implicitHeight : detail.implicitHeight)
                        + Tokens.fontSize
        Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        // ---------------- main ----------------
        Column {
            id: mainCol
            width: parent.width
            spacing: 8
            x: root.view === "main" ? 0 : -width * 0.35
            opacity: root.view === "main" ? 1 : 0
            visible: opacity > 0.01
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Text { text: "Control Center"; color: Tokens.ink
                   font.pixelSize: Tokens.fontSize; font.bold: true }

            // Two explicit rows rather than a Grid: Grid counts ITEMS, not
            // span units, so a 2-unit tile pushes the next one out of the panel.
            Column {
                id: grid
                width: parent.width
                spacing: Sys.InputMode.gutter
                readonly property real unit: (width - Sys.InputMode.gutter * 2) / 3

                Row {
                    width: parent.width
                    spacing: Sys.InputMode.gutter
                    Tile {
                        width: grid.unit; glyph: Paths.search
                        label: "Wi-Fi"
                        value: Sys.Network.connected ? (Sys.Network.ssid || "On") : "Off"
                        active: Sys.Network.connected
                        hasDetail: true
                        onToggled: Sys.Network.setEnabled(!Sys.Network.enabled)
                        onDetail: root.view = "wifi"
                    }
                    Tile {
                        width: grid.unit * 2 + Sys.InputMode.gutter; glyph: Paths.play
                        label: "Audio"
                        value: Sys.Audio.sinkName || (Sys.Audio.available ? "Default" : "Unavailable")
                        active: !Sys.Audio.muted && Sys.Audio.available
                        hasDetail: true
                        onToggled: Sys.Audio.toggleMute()
                        onDetail: root.view = "audio"
                    }
                }
                Row {
                    width: parent.width
                    spacing: Sys.InputMode.gutter
                    Tile {
                        width: grid.unit; glyph: Paths.moon
                        label: "Bluetooth"
                        value: Sys.Bluetooth.enabled ? (Sys.Bluetooth.connectedCount + " conn") : "Off"
                        active: Sys.Bluetooth.enabled
                        hasDetail: true
                        onToggled: Sys.Bluetooth.setEnabled(!Sys.Bluetooth.enabled)
                        onDetail: root.view = "bluetooth"
                    }
                    Tile {
                        width: grid.unit; glyph: Paths.close
                        label: "Peace"
                        value: Sys.Notifications.peaceMode ? "On" : "Off"
                        active: Sys.Notifications.peaceMode
                        onToggled: Sys.Notifications.setPeace(!Sys.Notifications.peaceMode)
                    }
                    Tile {
                        width: grid.unit; glyph: Paths.moon
                        label: "Night"
                        value: "Off"
                        onToggled: {}       // TODO(real): org.kde.KWin.NightLight
                    }
                }
            }

            SliderRow {
                width: parent.width; kind: "volume"
                value: Sys.Audio.volume; muted: Sys.Audio.muted
                onMoved: (v) => Sys.Audio.setVolume(v)
            }
            SliderRow {
                width: parent.width; kind: "brightness"
                value: Sys.Backlight.value
                onMoved: (v) => Sys.Backlight.setValue(v)
            }

            // media card — blurred art belongs here later; MultiEffect, never
            // Qt5Compat.GraphicalEffects (docs/quickshell-control-center.md §8)
            Rectangle {
                width: parent.width
                height: Sys.Media.hasPlayer ? 54 : 0
                visible: Sys.Media.hasPlayer
                radius: Tokens.radius
                color: Tokens.surfaceVariant
                Row {
                    anchors { fill: parent; margins: 10 }
                    spacing: 10
                    Column {
                        width: parent.width - 90
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: Sys.Media.title; color: Tokens.ink
                               font.pixelSize: Tokens.fontSize * 0.8; font.bold: true
                               elide: Text.ElideRight; width: parent.width }
                        Text { text: Sys.Media.artist; color: Tokens.inkDim
                               font.pixelSize: Tokens.fontSize * 0.65
                               elide: Text.ElideRight; width: parent.width }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Glyph { width: 18; height: 18; path: Paths.prev; ink: Tokens.inkDim
                                opacity: Sys.Media.canPrev ? 1 : 0.3
                                MouseArea { anchors.fill: parent; anchors.margins: -10
                                            onClicked: Sys.Media.previous() } }
                        Glyph { width: 20; height: 20
                                path: Sys.Media.playing ? Paths.pause : Paths.play
                                ink: Tokens.ink
                                MouseArea { anchors.fill: parent; anchors.margins: -10
                                            onClicked: Sys.Media.playPause() } }
                        Glyph { width: 18; height: 18; path: Paths.next; ink: Tokens.inkDim
                                opacity: Sys.Media.canNext ? 1 : 0.3
                                MouseArea { anchors.fill: parent; anchors.margins: -10
                                            onClicked: Sys.Media.next() } }
                    }
                }
            }

            // tray row: icons only, collapses to nothing when empty so it costs
            // nothing until something registers
            Flow {
                width: parent.width
                spacing: Sys.InputMode.gutter
                visible: Sys.Tray.count > 0
                Repeater {
                    model: Sys.Tray.items
                    delegate: Rectangle {
                        required property var modelData
                        width: Sys.InputMode.touchTarget
                        height: Sys.InputMode.touchTarget
                        radius: Tokens.radius
                        color: tma.pressed ? Tokens.surfaceVariant : "transparent"
                        Image {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            source: modelData.icon
                            sourceSize.width: 20; sourceSize.height: 20
                            asynchronous: true
                            // tray icons belong to the applications: never recolour
                            // them, an unrecognisable tray icon defeats the point
                        }
                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            onClicked: Sys.Tray.activate(modelData)
                            onPressAndHold: Sys.Tray.menu(modelData)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Tokens.outline }

            // FOOTER: navigation, deliberately NOT tiles. This is how theme,
            // wallpaper, settings and power become reachable with no keyboard
            // (island-core §9.1) — without it half the shell is unreachable.
            Row {
                width: parent.width
                height: Math.max(Sys.InputMode.touchTarget, 44)
                Repeater {
                    model: [
                        { g: Paths.palette, s: "theme" },
                        { g: Paths.image,   s: "wallpaper" },
                        { g: Paths.gear,    s: "settings" },
                        { g: Paths.power,   s: "power" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: parent.width / 4
                        height: parent.height
                        Glyph {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            path: modelData.g
                            ink: fma.pressed ? Tokens.accent : Tokens.inkDim
                        }
                        MouseArea {
                            id: fma
                            anchors.fill: parent
                            onClicked: root.navigate(modelData.s)
                        }
                    }
                }
            }
        }

        // ---------------- sub-view ----------------
        Column {
            id: detail
            width: parent.width
            spacing: 8
            x: root.view === "main" ? width * 0.35 : 0
            opacity: root.view === "main" ? 0 : 1
            visible: opacity > 0.01
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Row {
                spacing: 8
                height: Sys.InputMode.touchTarget
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; path: Paths.chevronL; ink: Tokens.ink
                    MouseArea { anchors.fill: parent; anchors.margins: -14; onClicked: root.back() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.view === "wifi" ? "Wi-Fi"
                        : root.view === "audio" ? "Audio" : "Bluetooth"
                    color: Tokens.ink; font.pixelSize: Tokens.fontSize; font.bold: true
                }
            }

            Text {
                visible: root.view === "bluetooth"
                text: Sys.Bluetooth.devices.length + " known device(s)"
                color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.75
            }
            Repeater {
                model: root.view === "bluetooth" ? Sys.Bluetooth.devices : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: detail.width
                    height: Sys.InputMode.touchTarget
                    radius: Tokens.radius
                    color: Tokens.surfaceVariant
                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData.name; color: Tokens.ink; font.pixelSize: Tokens.fontSize * 0.8
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData.connected ? "Disconnect" : "Connect"
                        color: Tokens.accent; font.pixelSize: Tokens.fontSize * 0.75
                    }
                    MouseArea { anchors.fill: parent; onClicked: Sys.Bluetooth.toggleDevice(index) }
                }
            }

            Text {
                visible: root.view === "wifi"
                text: Sys.Network.available
                      ? (Sys.Network.connected ? "Connected to " + (Sys.Network.ssid || "network")
                                               : "Not connected")
                      : "No network device"
                color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.75
            }
            Text {
                visible: root.view === "audio"
                text: Sys.Audio.available ? ("Output: " + (Sys.Audio.sinkName || "default"))
                                          : "No audio device"
                color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.75
            }
        }
    }
}
