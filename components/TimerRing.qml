import QtQuick
import QtQuick.Shapes

Item {
  id: root

  property real progress: 1
  property color color: "white"
  property color track: "transparent"
  property real thickness: 2

  readonly property real r: Math.max(0, Math.min(width, height) / 2 - thickness / 2)

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.track
      strokeWidth: root.thickness
      fillColor: "transparent"
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.r
        radiusY: root.r
        startAngle: 0
        sweepAngle: 360
      }
    }

    ShapePath {
      strokeColor: root.color
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.r
        radiusY: root.r
        startAngle: -90
        sweepAngle: 360 * Math.max(0, Math.min(1, root.progress))
      }
    }
  }
}
