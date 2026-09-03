import QtQuick
import Quickshell
import "../Config"
import "../Icons"
import "../Services" as Sys

// Wallpaper picker. On Plasma this needs NO wallpaper daemon --
// plasma-apply-wallpaperimage owns it, which removes a dependency rather than
// adding one, and makes persistence free (docs/quickshell-wallpaper.md §2).
//
// Thumbnails (§5): GridView so only visible delegates exist, sourceSize so the
// decoder works small, asynchronous so the UI thread never waits, and a
// placeholder tile that keeps its size so the grid never reflows as images land.
Item {
    id: root
    implicitWidth: Tokens.fontSize * 22
    implicitHeight: col.implicitHeight

    readonly property int cols: 3
    readonly property int gap: Sys.InputMode.gutter
    // GridView cells tile edge to edge, so the gutter lives INSIDE the cell:
    // three cells of width/3 always fit; the tile is the cell minus the gap.
    readonly property int cellW: Math.floor(width / cols)
    readonly property int thumbW: cellW - gap
    readonly property int thumbH: Math.round(thumbW * 9 / 16)
    readonly property int visibleRows: 3

    Column {
        id: col
        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            height: Sys.InputMode.touchTarget
            Text { anchors.verticalCenter: parent.verticalCenter
                   text: "Wallpaper"; color: Tokens.ink
                   font.pixelSize: Tokens.fontSize; font.bold: true }
            Item { width: parent.width - 100 - collBtn.width; height: 1 }
            // collection selector (§4): tap cycles; the label is the touch target
            Rectangle {
                id: collBtn
                anchors.verticalCenter: parent.verticalCenter
                width: collLabel.implicitWidth + Tokens.fontSize * 1.4
                height: Sys.InputMode.touchTarget - 8
                radius: Tokens.radius
                color: collPress.pressed ? Tokens.outline : Tokens.surfaceVariant
                visible: Sys.Wallpaper.available
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { id: collLabel; text: Sys.Wallpaper.collection + "  ·  " + Sys.Wallpaper.count
                           color: Tokens.ink; font.pixelSize: Tokens.fontSize * 0.7 }
                    Glyph { anchors.verticalCenter: parent.verticalCenter
                            width: 11; height: 11; path: Paths.chevronR; ink: Tokens.inkDim }
                }
                MouseArea { id: collPress; anchors.fill: parent; onClicked: Sys.Wallpaper.nextCollection() }
            }
        }

        Text {
            visible: Sys.Wallpaper.applying || Sys.Wallpaper.error !== ""
            text: Sys.Wallpaper.applying ? "Applying…" : Sys.Wallpaper.error
            color: Sys.Wallpaper.error !== "" ? Tokens.critical : Tokens.inkDim
            font.pixelSize: Tokens.fontSize * 0.65
        }

        GridView {
            id: grid
            width: parent.width
            height: Math.min(root.visibleRows, Math.ceil(Sys.Wallpaper.count / root.cols)) * (root.thumbH + root.gap)
            visible: Sys.Wallpaper.count > 0
            clip: true
            model: Sys.Wallpaper.items
            cellWidth: root.cellW
            cellHeight: root.thumbH + root.gap
            cacheBuffer: Math.max(0, root.thumbH * 2)   // modest on this hardware (§5); never negative before layout
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    id: tile
                    width: root.thumbW; height: root.thumbH
                    radius: Tokens.radius
                    color: Tokens.surfaceVariant          // placeholder until the image lands
                    clip: true
                    readonly property bool isCurrent: Sys.Wallpaper.current === modelData.path
                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData.path
                        sourceSize.width: root.thumbW * 2      // 2x for the 1.4 scale factor
                        sourceSize.height: root.thumbH * 2
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    // accent ring on the current wallpaper (§2: read back from Plasma)
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: tile.isCurrent ? 3 : 0
                        border.color: Tokens.accent
                    }
                    Rectangle {   // press feedback
                        anchors.fill: parent; radius: parent.radius
                        color: Tokens.ink; opacity: tilePress.pressed ? 0.18 : 0
                    }
                    MouseArea { id: tilePress; anchors.fill: parent; onClicked: Sys.Wallpaper.apply(modelData.path) }
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
            Text { text: "Add images to " + Sys.Wallpaper.root + "/<collection>/"
                   color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.65 }
        }
    }
}
