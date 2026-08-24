import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// Five tiles. Destructive actions arm-to-confirm — and on touch that needs a
// MINIMUM ARM DURATION, or a fast double-tap arms and fires in ~200ms and the
// whole mechanism is defeated (docs/quickshell-power-menu.md §2).
Item {
    id: root
    property string armed: ""
    property double armedAt: 0

    readonly property int armFloorMs: 400     // below this, a tap pair is not deliberate
    readonly property int armTimeoutMs: 3000  // an armed Power Off left on a table is a mis-tap

    implicitWidth: row.implicitWidth + Tokens.fontSize
    implicitHeight: 74

    function press(id, destructive) {
        var now = Date.now()
        if (!destructive) { Sys.Session[id](); return }
        if (armed === id) {
            if (now - armedAt < armFloorMs) return    // too fast to be deliberate
            armed = ""; Sys.Session[id](); return
        }
        armed = id; armedAt = now
        disarm.restart()
    }
    Timer { id: disarm; interval: root.armTimeoutMs; onTriggered: root.armed = "" }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: [
                { id: "lock",     label: "Lock",      glyph: Paths.lock,   d: false },
                { id: "suspend",  label: "Suspend",   glyph: Paths.moon,   d: false },
                { id: "logout",   label: "Log Out",   glyph: Paths.logout, d: true  },
                { id: "reboot",   label: "Reboot",    glyph: Paths.reboot, d: true  },
                { id: "poweroff", label: "Power Off", glyph: Paths.power,  d: true  }
            ]
            delegate: Rectangle {
                required property var modelData
                readonly property bool isArmed: root.armed === modelData.id
                width: Math.max(64, Sys.InputMode.touchTarget + 16)
                height: 64
                radius: Tokens.radius
                color: isArmed ? Tokens.critical
                               : (pma.pressed ? Tokens.surfaceVariant : Tokens.surfaceVariant)
                border.width: isArmed ? 0 : 1
                border.color: Tokens.outline
                Behavior on color { ColorAnimation { duration: 60 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18; height: 18
                        path: modelData.glyph
                        ink: parent.parent.isArmed ? Tokens.inkOnCritical : Tokens.ink
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.parent.isArmed ? "Confirm" : modelData.label
                        color: parent.parent.isArmed ? Tokens.inkOnCritical : Tokens.inkDim
                        font.pixelSize: Tokens.fontSize * 0.6
                    }
                }
                MouseArea {
                    id: pma
                    anchors.fill: parent
                    onClicked: root.press(modelData.id, modelData.d)
                }
            }
        }
    }
}
