import QtQuick
import QtQuick.Shapes
import "../Config"

// icons §4 / status-capsule §5. Arcs are fixed geometry; only colour+opacity
// animate. Bind `bars` to a QUANTISED bucket, never to raw NM strength —
// otherwise this re-animates on dBm wobble nobody can perceive.
Item {
    id: root
    property int bars: 3            // 0..4
    property bool connected: true
    property color ink: Tokens.onSurface
    implicitWidth: Tokens.iconSize
    implicitHeight: Tokens.iconSize

    Repeater {
        model: 3
        delegate: Shape {
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: (!root.connected) ? 0.25
                   : (root.bars >= index + 2 ? 1.0 : 0.22)
            Behavior on opacity { NumberAnimation { duration: 180 } }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.ink
                strokeWidth: Math.max(1.5, root.width*0.075)
                capStyle: ShapePath.RoundCap
                startX: root.width*(0.5 - 0.16*(index+1))
                startY: root.height*(0.66 - 0.13*(index+1))
                PathArc {
                    x: root.width*(0.5 + 0.16*(index+1))
                    y: root.height*(0.66 - 0.13*(index+1))
                    radiusX: root.width*0.20*(index+1)
                    radiusY: root.height*0.20*(index+1)
                    useLargeArc: false
                }
            }
        }
    }

    // dot — present whenever associated at all
    Rectangle {
        width: Math.max(2.5, root.width*0.12); height: width; radius: width/2
        color: root.ink
        opacity: root.connected ? (root.bars >= 1 ? 1.0 : 0.22) : 0.25
        x: (root.width - width)/2
        y: root.height*0.70
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    // disconnected slash — a state distinct from "connected, zero bars"
    Shape {
        anchors.fill: parent
        opacity: root.connected ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 180 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: root.ink
            strokeWidth: Math.max(1.5, root.width*0.075); capStyle: ShapePath.RoundCap
            startX: root.width*0.20; startY: root.height*0.20
            PathLine { x: root.width*0.80; y: root.height*0.80 }
        }
    }
}
