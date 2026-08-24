import QtQuick
import Quickshell
import "../Config"
import "../Icons"
import "../Services" as Sys

// Wallpaper picker. On Plasma this needs NO wallpaper daemon —
// plasma-apply-wallpaperimage owns it, which removes a dependency rather than
// adding one, and makes persistence free (docs/quickshell-wallpaper.md §2).
Item {
    id: root
    implicitWidth: Tokens.fontSize * 22
    implicitHeight: col.implicitHeight

    // sourceSize is mandatory: without it QML decodes each full-resolution image
    // and then scales it down to draw a 100px thumbnail (§5)
    readonly property int thumbW: 104
    readonly property int thumbH: 58

    Column {
        id: col
        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            Text { text: "Wallpaper"; color: Tokens.ink
                   font.pixelSize: Tokens.fontSize; font.bold: true }
            Item { width: parent.width - 160; height: 1 }
            Text { text: Sys.Wallpaper.collection; color: Tokens.inkDim
                   font.pixelSize: Tokens.fontSize * 0.7 }
        }

        Grid {
            width: parent.width
            columns: 3
            spacing: Sys.InputMode.gutter
            visible: Sys.Wallpaper.count > 0
            Repeater {
                model: Sys.Wallpaper.items
                delegate: Rectangle {
                    required property var modelData
                    width: root.thumbW; height: root.thumbH
                    radius: Tokens.radius
                    color: Tokens.surfaceVariant
                    border.width: Sys.Wallpaper.current === modelData ? 2 : 0
                    border.color: Tokens.accent
                    Image {
                        anchors.fill: parent; anchors.margins: 2
                        source: "file://" + modelData
                        sourceSize.width: root.thumbW
                        sourceSize.height: root.thumbH
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: Sys.Wallpaper.apply(modelData) }
                }
            }
        }

        // Honest empty state: the library is CONTENT, not code, and it quietly
        // blocks this component until someone gathers a couple of collections.
        Column {
            visible: Sys.Wallpaper.count === 0
            width: parent.width
            spacing: 6
            Text { text: "No wallpapers found"; color: Tokens.ink
                   font.pixelSize: Tokens.fontSize * 0.8 }
            Text { text: "Add images to " + Sys.Wallpaper.root
                   color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.65 }
        }
    }
}
