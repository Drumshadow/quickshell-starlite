import QtQuick
import "../Config"
import "../Icons"

// island-core §7: three zones. Portrait needs an explicit variant — a
// horizontal three-zone row does not fit a portrait 3:2 panel (parent §3.1.7).
Item {
    id: root
    property bool playing: false
    property string title: ""
    property string artist: ""
    property int batteryPercent: 80
    property string batteryState: "Discharging"
    property int wifiBars: 3
    property bool wifiConnected: true

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
                text: root.title; color: Tokens.onSurface
                font.pixelSize: Tokens.fontSize * 0.8; elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.artist; color: Tokens.onSurfaceDim
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
                color: Tokens.onSurface
                font.pixelSize: Tokens.fontSize * 1.5
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "ddd, MMM d")
                color: Tokens.onSurfaceDim
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
        ink: Tokens.onSurfaceDim
        rotation: 90
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Tokens.touchMin / 3
            onClicked: IslandState.request("control")
        }
    }
}
