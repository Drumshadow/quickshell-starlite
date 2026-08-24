import QtQuick
import "../Config"

// island-core §6 (as corrected 2026-08-23): the pill is the TIME ONLY, plus
// animated EQ bars while something is playing. There is NO status glyph here.
Item {
    id: root
    property bool playing: false
    implicitWidth: row.implicitWidth + Tokens.fontSize * 1.6
    implicitHeight: Settings.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.fontSize * 0.4

        // The ONLY continuously-animating thing at rest, and therefore the
        // shell's only idle battery cost. Gated strictly on playback, and
        // STOPPED (not merely hidden) on pause — media §5.
        Row {
            id: eq
            visible: root.playing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.max(1, Tokens.fontSize * 0.1)
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: Math.max(1.5, Tokens.fontSize * 0.13)
                    radius: width / 2
                    color: Tokens.accent
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.fontSize * 0.35
                    SequentialAnimation on height {
                        running: root.playing          // stops entirely on pause
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 90 }
                        NumberAnimation { to: Tokens.fontSize * 0.75; duration: 320; easing.type: Easing.InOutSine }
                        NumberAnimation { to: Tokens.fontSize * 0.25; duration: 320; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Text {
            id: clock
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.onSurface
            font.pixelSize: Tokens.fontSize
            // tabular figures so the pill does not jitter (island-core §6)
            font.features: ({ "tnum": 1 })
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }
    }

    // ticks on the minute boundary, not every 60s from start (island-core §6)
    Timer {
        interval: 1000
        running: true; repeat: true
        onTriggered: {
            var now = new Date()
            clock.text = Qt.formatDateTime(now, "HH:mm")
            interval = (60 - now.getSeconds()) * 1000
        }
    }
}
