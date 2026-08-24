// Development entry point — mock mode.
//
//   tools/dev/run-mock.sh
//   qs -p dev/shell.qml           (on a machine with a Wayland session)
//
// Sets Env.mock, then shows the mock control panel beside live components so
// you can watch them react. Touches nothing on the host session.
import QtQuick
import Quickshell
import "Config"
import "Icons"
import "Services" as Sys
import "dev"

ShellRoot {
    Component.onCompleted: {
        Sys.Env.mock = true
        // posture can be preset from the environment so headless runs can
        // capture laptop vs tablet vs portrait without clicking
        var p = Quickshell.env("QS_PRESET")
        if (p) Sys.Mock.preset(p)
    }

    FloatingWindow {
        implicitWidth: 900
        implicitHeight: 620
        color: Tokens.background

        Row {
            anchors { fill: parent; margins: 14 }
            spacing: 14

            MockPanel { height: parent.height }

            Column {
                spacing: 14
                width: 470

                Text { text: "LIVE COMPONENTS (reading services only)"
                       color: Tokens.ink; font.pixelSize: 14; font.bold: true }

                // the rest pill, driven entirely by services
                Rectangle {
                    width: 200; height: Tokens.barHeight
                    radius: height / 2
                    color: Tokens.surface
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Row {
                            visible: Sys.Media.playing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 2; radius: 1; color: Tokens.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4 + index * 3
                                }
                            }
                        }
                        Text { text: Qt.formatDateTime(new Date(), "HH:mm")
                               color: Tokens.ink; font.pixelSize: Tokens.fontSize }
                    }
                }

                // status capsule
                Rectangle {
                    width: cap.implicitWidth + 24; height: 40; radius: 20
                    color: Tokens.surfaceVariant
                    Row {
                        id: cap
                        anchors.centerIn: parent; spacing: 10
                        Wifi { anchors.verticalCenter: parent.verticalCenter
                               bars: Sys.Network.strength; connected: Sys.Network.connected }
                        Battery { anchors.verticalCenter: parent.verticalCenter
                                  percent: Sys.Power.percentage; state: Sys.Power.state }
                    }
                }

                // OSD row
                Row {
                    spacing: 20
                    Volume { width: 34; height: 34; value: Sys.Audio.volume; muted: Sys.Audio.muted }
                    Brightness { width: 34; height: 34; value: Sys.Backlight.value }
                }

                Rectangle { width: parent.width; height: 1; color: Tokens.outline }

                // adaptive behaviour — a generic component sizing itself from InputMode
                Text { text: "ADAPTIVE: a generic button, no device assumptions"
                       color: Tokens.inkDim; font.pixelSize: 11 }
                Rectangle {
                    width: 190
                    height: Sys.InputMode.touchTarget
                    radius: 8
                    color: Tokens.accent
                    Behavior on height { NumberAnimation { duration: 180 } }
                    Text { anchors.centerIn: parent
                           text: "height = " + Sys.InputMode.touchTarget + "px"
                           color: Tokens.inkOnAccent; font.pixelSize: 12 }
                }
                Text {
                    text: "orientation=" + Sys.InputMode.orientation
                          + "  tablet=" + Sys.InputMode.tabletMode
                          + "  gestures=" + Sys.InputMode.gesturesPrimary
                    color: Tokens.inkDim; font.pixelSize: 10; font.family: "monospace"
                }
                Text {
                    text: "session.lastAction = " + (Sys.Session.lastAction || "(none)")
                    color: Tokens.inkDim; font.pixelSize: 10; font.family: "monospace"
                }
            }
        }
    }
}
