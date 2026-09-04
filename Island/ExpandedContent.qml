import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// island-core §7: three zones. Portrait needs an explicit variant — a
// horizontal three-zone row does not fit a portrait 3:2 panel (parent §3.1.7).
//
// Defaults bind to the services (the single source of truth); they stay plain
// properties so the gallery / mock harness can override them. The literal
// placeholders that were here (80%, 3 bars) shipped to the real tablet and showed
// "80" next to a 63% battery — StarLite, 2026-09-03.
Item {
    id: root
    property bool playing: Sys.Media.playing
    property string title: Sys.Media.title
    property string artist: Sys.Media.artist
    property int batteryPercent: Sys.Power.percentage
    property string batteryState: Sys.Power.state
    property int wifiBars: Sys.Network.strength
    property bool wifiConnected: Sys.Network.connected

    implicitWidth: Tokens.fontSize * 22
    implicitHeight: Tokens.fontSize * 3.4

    Row {
        anchors.fill: parent
        anchors.margins: Tokens.fontSize * 0.6
        spacing: Tokens.fontSize * 0.8

        // grabber -- the all-tap path to `control` (island-core §9.1 mechanism 3).
        // Not decoration: it is what makes the shell reachable without the drag.
        // A full touch-target button on the left of the pill; the old 16x10 px
        // chevron under the date was unfindable by finger (Stephen, 2026-09-03).
        Rectangle {
            id: grabber
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(40, Sys.InputMode.touchTarget - 6)
            height: width
            radius: width / 2
            color: grabPress.pressed ? Tokens.accent : Tokens.surfaceVariant
            Behavior on color { ColorAnimation { duration: 60 } }
            Glyph {
                anchors.centerIn: parent
                width: parent.width * 0.42; height: parent.width * 0.42
                path: Paths.chevronR
                rotation: 90
                ink: grabPress.pressed ? Tokens.inkOnAccent : Tokens.ink
            }
            MouseArea {
                id: grabPress
                anchors.fill: parent
                anchors.margins: -6
                onClicked: IslandState.request("control")
            }
        }

        // left: media
        Column {
            width: parent.width * 0.26
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: root.title; color: Tokens.ink
                font.pixelSize: Tokens.fontSize * 0.8; elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.artist; color: Tokens.inkDim
                font.pixelSize: Tokens.fontSize * 0.65; elide: Text.ElideRight
                width: parent.width
            }
        }

        // centre: hero clock
        Column {
            width: parent.width * 0.32
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "HH:mm")
                color: Tokens.ink
                font.pixelSize: Tokens.fontSize * 1.5
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "ddd, MMM d")
                color: Tokens.inkDim
                font.pixelSize: Tokens.fontSize * 0.6
            }
        }

        // right: the status capsule (status-capsule §2)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: capsule.implicitWidth + Tokens.fontSize
            height: Tokens.fontSize * 1.9
            radius: height / 2
            color: Tokens.surfaceVariant
            Row {
                id: capsule
                anchors.centerIn: parent
                spacing: Tokens.fontSize * 0.5
                Wifi {
                    anchors.verticalCenter: parent.verticalCenter
                    bars: root.wifiBars; connected: root.wifiConnected
                }
                Battery {
                    anchors.verticalCenter: parent.verticalCenter
                    percent: root.batteryPercent; state: root.batteryState
                }
            }
        }
    }

}
