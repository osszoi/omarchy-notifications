import QtQuick
import QtQuick.Effects

Item {
  id: root

  property alias source: img.source
  property real radius: width / 2
  readonly property alias status: img.status
  readonly property real ratio: probe.implicitHeight > 0 ? probe.implicitWidth / probe.implicitHeight : 1

  // only here to read the aspect ratio, quickshell's provider squashes scaled requests
  Image {
    id: probe
    visible: false
    asynchronous: true
    readonly property bool provider: String(img.source).indexOf("image://") === 0
    source: img.source
    fillMode: Image.PreserveAspectFit
    sourceSize.width: provider ? 0 : 64
    sourceSize.height: provider ? 0 : 64
  }

  Image {
    id: img
    anchors.fill: parent
    visible: false
    asynchronous: true
    smooth: true
    mipmap: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: Math.max(1, Math.round(root.width * 2))
    sourceSize.height: Math.max(1, Math.round(root.height * 2))
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
