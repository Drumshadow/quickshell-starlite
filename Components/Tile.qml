import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// A control-centre toggle tile. Tap toggles; long-press (or the chevron) opens
// the sub-view — the source's tap-the-icon-badge split target is a mis-tap
// generator at finger size (docs/quickshell-control-center.md §5).
Rectangle {
    id: tile
    property string label: ""
    property string value: ""
    property bool active: false
    property bool hasDetail: false
    property string glyph: ""

    signal toggled()
    signal detail()

    implicitHeight: Math.max(56, Sys.InputMode.touchTarget + 8)
    radius: Tokens.radius
    color: tile.active ? Tokens.accent
                       : (ma.pressed ? Qt.tint(Tokens.surfaceVariant, Qt.rgba(1,1,1,0.06))
                                     : Tokens.surfaceVariant)
    // press feedback must be immediate, not a spring: with no hover there is no
    // pre-touch affordance, so post-touch has to carry it
    Behavior on color { ColorAnimation { duration: 60 } }

    readonly property color fg: tile.active ? Tokens.inkOnAccent : Tokens.ink
    readonly property color fgDim: tile.active
        ? Qt.tint(Tokens.accent, Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, 0.7))
        : Tokens.inkDim

    Row {
        anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter
                  right: parent.right; rightMargin: 4 }
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 11
            color: tile.active ? Qt.rgba(0,0,0,0.18) : Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.18)
            Glyph {
                anchors.centerIn: parent
                width: 13; height: 13
                path: tile.glyph
                ink: tile.active ? tile.fg : Tokens.accent
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - 17
            Text { text: tile.label; color: tile.fg
                   font.pixelSize: Tokens.fontSize * 0.72; font.bold: true
                   elide: Text.ElideRight; width: parent.width }
            Text { text: tile.value; color: tile.fgDim
                   font.pixelSize: Tokens.fontSize * 0.6
                   elide: Text.ElideRight; width: parent.width; visible: text !== "" }
        }
    }

    // chevron: the discoverable path to the sub-view, since long-press alone
    // teaches nobody
    Glyph {
        id: chev
        visible: tile.hasDetail
        anchors { right: parent.right; rightMargin: 5; top: parent.top; topMargin: 5 }
        width: 11; height: 11
        path: Paths.chevronR
        ink: tile.fgDim
        MouseArea {
            anchors.fill: parent
            anchors.margins: -12          // >=48px effective target
            onClicked: tile.detail()
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        onClicked: tile.toggled()
        onPressAndHold: if (tile.hasDetail) tile.detail()
    }

    // long-press progress, so a hold never reads as a dropped tap
    Rectangle {
        visible: ma.pressed && tile.hasDetail
        anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 2; leftMargin: 6 }
        height: 2; radius: 1
        color: tile.fg
        width: 0
        NumberAnimation on width {
            running: ma.pressed && tile.hasDetail
            from: 0; to: tile.width - 12; duration: 800
        }
    }
}
