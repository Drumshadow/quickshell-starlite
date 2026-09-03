import QtQuick
import "../Config"

// Themed letter avatar: the fallback for anything that should have an icon and
// does not (launcher rows without a themed icon, notifications without an app
// icon). One style for both, per launcher §6.
Rectangle {
    id: root
    property string name: ""
    width: Tokens.iconSize
    height: width
    radius: width / 2
    color: Tokens.accent
    Text {
        anchors.centerIn: parent
        text: root.name.trim() !== "" ? root.name.trim().charAt(0).toUpperCase() : "?"
        color: Tokens.inkOnAccent
        font.bold: true
        font.pixelSize: root.width * 0.55
    }
}
