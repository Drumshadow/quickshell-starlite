import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// Thick rounded slider. Visual stays slim; the INPUT region meets the touch
// floor, and tap-to-set is added because drag alone is fussy with a finger.
Item {
    id: root
    property string kind: "volume"     // volume | brightness
    property real value: 0.5
    property bool muted: false
    signal moved(real v)

    implicitHeight: Math.max(Sys.InputMode.touchTarget, 34)

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 22
        radius: height / 2
        color: Tokens.surfaceVariant

        Rectangle {
            height: parent.height; radius: parent.radius
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
            color: Tokens.accent
            opacity: root.muted ? 0.35 : 1
            Behavior on width { NumberAnimation { duration: 90 } }
        }
        Loader {
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            sourceComponent: root.kind === "volume" ? v : b
        }
        Component { id: v; Volume { width: 15; height: 15; value: root.value; muted: root.muted
                                    ink: Tokens.inkOnAccent } }
        Component { id: b; Brightness { width: 15; height: 15; value: root.value
                                        ink: Tokens.inkOnAccent } }
    }

    MouseArea {
        anchors.fill: parent      // full-height target, not just the 22px visual
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: (m) => set(m.x)
        onPositionChanged: (m) => { if (pressed) set(m.x) }
    }
}
