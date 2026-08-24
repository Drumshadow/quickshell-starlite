import QtQuick
import "../Config"
import "../Components"
import "../Services" as Sys

// Four rows, and the restraint is deliberate. Two touch problems the morph
// architecture creates are handled here (docs/quickshell-settings.md §3):
//   * you cannot SEE the bar you are configuring — hence the preview swatch
//   * changing font size would reflow the control under your finger — hence
//     this panel renders at a FIXED size, immune to its own setting
Item {
    id: root
    signal navigate(string state)
    readonly property int fixedFont: 16          // deliberately not Tokens.fontSize

    implicitWidth: Tokens.fontSize * 22
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        Text { text: "Settings"; color: Tokens.ink
               font.pixelSize: root.fixedFont; font.bold: true }

        // live preview: the pill you are sizing, rendered right here
        Rectangle {
            width: parent.width
            height: 46
            radius: Tokens.radius
            color: Tokens.surfaceVariant
            Rectangle {
                anchors.centerIn: parent
                width: 96; height: Settings.barHeight
                radius: height / 2
                color: Tokens.surface
                Text {
                    anchors.centerIn: parent
                    text: "12:34"
                    color: Tokens.ink
                    font.pixelSize: Settings.fontSize
                }
            }
        }

        Column {
            width: parent.width
            Text { text: "Bar height   " + Settings.barHeight + " px"
                   color: Tokens.inkDim; font.pixelSize: root.fixedFont * 0.7 }
            SliderRow {
                width: parent.width; kind: "brightness"
                value: (Settings.barHeight - Settings.barMin) / (Settings.barMax - Settings.barMin)
                onMoved: (v) => Settings.setBar(Settings.barMin + v * (Settings.barMax - Settings.barMin))
            }
        }
        Column {
            width: parent.width
            Text { text: "Font size   " + Settings.fontSize + " px"
                   color: Tokens.inkDim; font.pixelSize: root.fixedFont * 0.7 }
            SliderRow {
                width: parent.width; kind: "brightness"
                value: (Settings.fontSize - Settings.fontMin) / (Settings.fontMax - Settings.fontMin)
                onMoved: (v) => Settings.setFont(Settings.fontMin + v * (Settings.fontMax - Settings.fontMin))
            }
        }

        Rectangle { width: parent.width; height: 1; color: Tokens.outline }

        Repeater {
            model: [
                { label: "Theme",     value: Themes.current, state: "theme" },
                { label: "Wallpaper", value: "Choose…",      state: "wallpaper" }
            ]
            delegate: Item {
                required property var modelData
                width: col.width
                height: Sys.InputMode.touchTarget
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: modelData.label; color: Tokens.ink
                    font.pixelSize: root.fixedFont * 0.8
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: modelData.value + "  ›"; color: Tokens.accent
                    font.pixelSize: root.fixedFont * 0.75
                }
                MouseArea { anchors.fill: parent; onClicked: root.navigate(modelData.state) }
            }
        }
    }
}
