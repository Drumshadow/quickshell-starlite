import QtQuick
import QtQuick.Shapes
import "../Config"

// icons §4 / osd §6. Mute is a SEPARATE input from volume 0 — never infer one.
// Waves are fixed geometry whose opacity animates: never regenerate path data
// per frame (icons §8).
Item {
    id: root
    property real value: 0.6        // 0..1
    property bool muted: false
    property color ink: Tokens.onSurface
    implicitWidth: Tokens.iconSize
    implicitHeight: Tokens.iconSize

    readonly property bool wave1: !muted && value > 0.001
    readonly property bool wave2: !muted && value > 0.5

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // speaker body
        ShapePath {
            fillColor: root.ink
            strokeColor: "transparent"
            startX: root.width*0.16; startY: root.height*0.38
            PathLine { x: root.width*0.30; y: root.height*0.38 }
            PathLine { x: root.width*0.46; y: root.height*0.22 }
            PathLine { x: root.width*0.46; y: root.height*0.78 }
            PathLine { x: root.width*0.30; y: root.height*0.62 }
            PathLine { x: root.width*0.16; y: root.height*0.62 }
            PathLine { x: root.width*0.16; y: root.height*0.38 }
        }
    }

    // wave 1
    Shape {
        anchors.fill: parent
        opacity: root.wave1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: root.ink
            strokeWidth: Math.max(1.5, root.width*0.07); capStyle: ShapePath.RoundCap
            startX: root.width*0.58; startY: root.height*0.36
            PathArc { x: root.width*0.58; y: root.height*0.64
                      radiusX: root.width*0.16; radiusY: root.height*0.16; useLargeArc: false }
        }
    }
    // wave 2
    Shape {
        anchors.fill: parent
        opacity: root.wave2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: root.ink
            strokeWidth: Math.max(1.5, root.width*0.07); capStyle: ShapePath.RoundCap
            startX: root.width*0.72; startY: root.height*0.26
            PathArc { x: root.width*0.72; y: root.height*0.74
                      radiusX: root.width*0.26; radiusY: root.height*0.26; useLargeArc: false }
        }
    }
    // mute cross
    Shape {
        anchors.fill: parent
        opacity: root.muted ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: root.ink
            strokeWidth: Math.max(1.5, root.width*0.07); capStyle: ShapePath.RoundCap
            startX: root.width*0.58; startY: root.height*0.34
            PathLine { x: root.width*0.86; y: root.height*0.66 }
        }
        ShapePath {
            fillColor: "transparent"; strokeColor: root.ink
            strokeWidth: Math.max(1.5, root.width*0.07); capStyle: ShapePath.RoundCap
            startX: root.width*0.86; startY: root.height*0.34
            PathLine { x: root.width*0.58; y: root.height*0.66 }
        }
    }
}
