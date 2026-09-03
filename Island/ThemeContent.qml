import QtQuick
import "../Config"
import "../Services" as Sys

// 3-column swatch grid. Each swatch previews its OWN background and accent, so
// the grid is legible without applying anything — the good idea in the source's
// design, and the reason e-ink visibly reads as light next to the others.
Item {
    id: root
    implicitWidth: Tokens.fontSize * 22
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            Text { text: "Theme"; color: Tokens.ink
                   font.pixelSize: Tokens.fontSize; font.bold: true }
            Item { width: parent.width - 60 - applyState.width; height: 1 }
            Text { id: applyState
                   text: Themes.applying ? "Applying…" : (Themes.error !== "" ? Themes.error : "")
                   color: Themes.error !== "" ? Tokens.critical : Tokens.inkDim
                   font.pixelSize: Tokens.fontSize * 0.65 }
        }

        Grid {
            width: parent.width
            columns: 3
            spacing: Sys.InputMode.gutter
            readonly property real unit: (width - spacing * 2) / 3

            Repeater {
                model: Themes.palettes
                delegate: Rectangle {
                    required property var modelData
                    width: parent.unit
                    height: Math.max(52, Sys.InputMode.touchTarget + 4)
                    radius: Tokens.radius
                    color: modelData.bg
                    border.width: Themes.current === modelData.id ? 2 : 1
                    border.color: Themes.current === modelData.id
                                  ? Tokens.accent
                                  : Qt.tint(modelData.bg, Qt.rgba(modelData.fg.r, modelData.fg.g, modelData.fg.b, 0.18))

                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.parent.width * 0.42; height: 5; radius: 2.5
                            color: modelData.accent
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label !== undefined ? modelData.label : modelData.id
                            color: modelData.fg
                            font.pixelSize: Tokens.fontSize * 0.62
                        }
                    }
                    opacity: Themes.applying && Themes.current !== modelData.id ? 0.6 : 1
                    MouseArea { anchors.fill: parent; onClicked: Themes.set(modelData.id) }
                }
            }
        }

        // live proof the derivation holds on whatever is selected
        Text {
            width: parent.width
            text: "contrast  ink " + Tokens.cOnSurface.toFixed(1)
                  + "   dim " + Tokens.cOnSurfaceDim.toFixed(1)
                  + "   onAccent " + Tokens.cOnAccent.toFixed(1)
            color: (Tokens.cOnSurface >= 4.5 && Tokens.cOnSurfaceDim >= 4.5 && Tokens.cOnAccent >= 4.5)
                   ? Tokens.success : Tokens.critical
            font.pixelSize: Tokens.fontSize * 0.6
            font.family: "monospace"
        }
    }
}
