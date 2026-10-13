import QtQuick

Rectangle {
  id: root

  required property var theme
  property bool checked: false

  signal toggled(bool checked)

  width: theme.px(34)
  height: theme.px(20)
  radius: theme.round(height)
  color: checked ? theme.accent : theme.fillHot

  Behavior on color { ColorAnimation { duration: 160 } }

  Rectangle {
    width: root.theme.px(14)
    height: width
    radius: root.theme.round(width)
    y: root.theme.px(3)
    x: root.checked ? root.width - width - root.theme.px(3) : root.theme.px(3)
    color: root.checked ? root.theme.onAccent : root.theme.dim

    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
