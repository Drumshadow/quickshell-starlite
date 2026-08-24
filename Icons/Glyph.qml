import QtQuick
import QtQuick.Shapes
import "../Config"

// icons §1: the ~15 STATIC icons are imported SVG path data fed to PathSvg, so
// they remain real Shapes — same tinting, same crispness, no icon font.
// Paths below are placeholders on a 24x24 grid; replace with the chosen set
// (Lucide ISC / Phosphor MIT) and record the licence.
Item {
    id: root
    property string path: ""
    property color ink: Tokens.onSurface
    property real strokeW: 2.0          // match the source set's stroke weight
    property bool filled: false
    implicitWidth: Tokens.iconSize
    implicitHeight: Tokens.iconSize

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // viewBox is 24x24; scale to the requested size
        transform: Scale { xScale: root.width/24; yScale: root.height/24 }
        ShapePath {
            fillColor: root.filled ? root.ink : "transparent"
            strokeColor: root.filled ? "transparent" : root.ink
            strokeWidth: root.strokeW
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
