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
        spacing: Tokens.fontSize

        // left: media
        Column {
            width: parent.width * 0.32
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

    // grabber — the all-tap path to `control` (island-core §9.1 mechanism 3).
    // Not decoration: it is what makes the shell reachable without the drag.
    Glyph {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Tokens.fontSize; height: Tokens.fontSize * 0.6
        path: Paths.chevronR
        ink: Tokens.inkDim
        rotation: 90
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Sys.InputMode.touchTarget / 3
            onClicked: IslandState.request("control")
        }
    }
}
