// Icon + theme gallery — icons §9, theming §8.
// Run:  qs -p ~/quickshell-starlite/gallery/shell.qml
//
// Renders every icon at every state and size, plus the live contrast audit.
// Consistency problems are invisible one icon at a time and obvious in a grid,
// and this is the only practical way to check crispness at the tablet's real
// fractional scale factor, on the real panel.
import QtQuick
import Quickshell
import "../Config"
import "../Icons"

ShellRoot {
    FloatingWindow {
        implicitWidth: 900
        implicitHeight: 700
        color: Tokens.surface

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: col.implicitHeight
            clip: true

            Column {
                id: col
                width: parent.width
                spacing: 22

                Text {
                    text: "Icon + theme gallery"
                    color: Tokens.onSurface; font.pixelSize: 22; font.bold: true
                }

                // ---- contrast audit (theming §8) ----
                Column {
                    spacing: 4
                    Text { text: "Contrast audit"; color: Tokens.onSurfaceDim; font.pixelSize: 13 }
                    Repeater {
                        model: Tokens.audit
                        delegate: Row {
                            required property var modelData
                            spacing: 10
                            Text {
                                width: 190
                                text: modelData.pair
                                color: Tokens.onSurfaceDim; font.pixelSize: 12; font.family: "monospace"
                            }
                            Text {
                                text: modelData.ratio.toFixed(2) + ":1"
                                font.pixelSize: 12; font.family: "monospace"
                                color: modelData.ratio >= modelData.min ? Tokens.success : Tokens.critical
                            }
                            Text {
                                text: modelData.ratio >= modelData.min ? "ok" : ("FAILS min " + modelData.min)
                                font.pixelSize: 12
                                color: modelData.ratio >= modelData.min ? Tokens.onSurfaceDim : Tokens.critical
                            }
                        }
                    }
                }

                // ---- stateful icons across their range ----
                Text { text: "Stateful — the four that encode a value"; color: Tokens.onSurfaceDim; font.pixelSize: 13 }

                Row {
                    spacing: 18
                    Repeater {
                        model: [0.0, 0.25, 0.5, 0.75, 1.0]
                        delegate: Column {
                            required property real modelData
                            spacing: 4
                            Volume { value: modelData; muted: false }
                            Text { text: Math.round(modelData*100) + "%"; color: Tokens.onSurfaceDim; font.pixelSize: 10 }
                        }
                    }
                    Column { spacing: 4; Volume { muted: true }; Text { text: "mute"; color: Tokens.onSurfaceDim; font.pixelSize: 10 } }
                }

                Row {
                    spacing: 18
                    Repeater {
                        model: [0.0, 0.3, 0.6, 1.0]
                        delegate: Column {
                            required property real modelData
                            spacing: 4
                            Brightness { value: modelData }
                            Text { text: Math.round(modelData*100) + "%"; color: Tokens.onSurfaceDim; font.pixelSize: 10 }
                        }
                    }
                }

                // battery: the legibility case is 10 / 50 / 90 (icons §11)
                Row {
                    spacing: 18
                    Repeater {
                        model: [
                            { p: 10, s: "Critical" }, { p: 25, s: "Low" },
                            { p: 50, s: "Discharging" }, { p: 80, s: "AtCap" },
                            { p: 90, s: "Charging" }, { p: 100, s: "Full" }
                        ]
                        delegate: Column {
                            required property var modelData
                            spacing: 4
                            Battery { percent: modelData.p; state: modelData.s }
                            Text { text: modelData.s; color: Tokens.onSurfaceDim; font.pixelSize: 10 }
                        }
                    }
                }

                Row {
                    spacing: 18
                    Repeater {
                        model: [0, 1, 2, 3, 4]
                        delegate: Column {
                            required property int modelData
                            spacing: 4
                            Wifi { bars: modelData; connected: true }
                            Text { text: modelData + " bars"; color: Tokens.onSurfaceDim; font.pixelSize: 10 }
                        }
                    }
                    Column { spacing: 4; Wifi { connected: false }; Text { text: "offline"; color: Tokens.onSurfaceDim; font.pixelSize: 10 } }
                }

                // ---- static set ----
                Text { text: "Static — imported geometry via PathSvg"; color: Tokens.onSurfaceDim; font.pixelSize: 13 }
                Flow {
                    width: parent.width
                    spacing: 18
                    Repeater {
                        model: [
                            ["lock", Paths.lock], ["power", Paths.power], ["reboot", Paths.reboot],
                            ["logout", Paths.logout], ["moon", Paths.moon], ["search", Paths.search],
                            ["close", Paths.close], ["chevron", Paths.chevronR], ["play", Paths.play],
                            ["pause", Paths.pause], ["next", Paths.next], ["prev", Paths.prev],
                            ["palette", Paths.palette], ["image", Paths.image], ["gear", Paths.gear]
                        ]
                        delegate: Column {
                            required property var modelData
                            spacing: 4
                            Glyph { path: modelData[1] }
                            Text { text: modelData[0]; color: Tokens.onSurfaceDim; font.pixelSize: 10 }
                        }
                    }
                }

                // ---- three sizes: the crispness check at real scale (icons §7) ----
                Text { text: "Sizes — check crispness at the panel's real scale factor"; color: Tokens.onSurfaceDim; font.pixelSize: 13 }
                Row {
                    spacing: 24
                    Repeater {
                        model: [16, 24, 48]
                        delegate: Row {
                            required property int modelData
                            spacing: 10
                            Volume    { width: modelData; height: modelData; value: 0.7 }
                            Battery   { height: modelData; width: modelData * 1.9; percent: 62 }
                            Wifi      { width: modelData; height: modelData; bars: 3 }
                            Glyph     { width: modelData; height: modelData; path: Paths.gear }
                        }
                    }
                }
            }
        }
    }
}
