import QtQuick
import QtQuick.Effects

Item {
  id: root

  property alias source: img.source
  property real radius: width / 2
  readonly property alias status: img.status
  readonly property real ratio: img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 1

  Image {
    id: img
    anchors.fill: parent
    visible: false
    asynchronous: true
    smooth: true
    mipmap: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.height: 160
  }

  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: parent
    source: img
    visible: img.status === Image.Ready
    maskEnabled: true
    maskSource: mask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }
}
