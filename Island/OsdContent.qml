import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// island-core: a compact level meter. Display-only by design — it auto-dismisses,
// so an interactive target that vanishes would be a bad affordance
// (docs/quickshell-osd.md §9).
Item {
    id: root
    property string kind: "volume"      // volume | brightness
    readonly property real value: kind === "volume" ? Sys.Audio.volume : Sys.Backlight.value
    readonly property bool muted: kind === "volume" && Sys.Audio.muted

    implicitWidth: Tokens.fontSize * 13
    implicitHeight: Settings.barHeight

    Row {
        anchors.centerIn: parent
        spacing: Tokens.fontSize * 0.6

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.kind === "volume" ? volIcon : briIcon
        }
        Component { id: volIcon; Volume { width: Tokens.iconSize; height: Tokens.iconSize
                                          value: root.value; muted: root.muted } }
        Component { id: briIcon; Brightness { width: Tokens.iconSize; height: Tokens.iconSize
                                              value: root.value } }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.fontSize * 7.5
            height: Tokens.fontSize * 0.5
            radius: height / 2
            color: Tokens.surfaceVariant
            Rectangle {
                height: parent.height; radius: parent.radius
                width: parent.width * Math.max(0, Math.min(1, root.value))
                color: Tokens.accent
                opacity: root.muted ? 0.35 : 1
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.value * 100) + "%"
            color: Tokens.inkDim
            font.pixelSize: Tokens.fontSize * 0.75
            font.features: ({ "tnum": 1 })
        }
    }
}
