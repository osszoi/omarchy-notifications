import QtQuick

Rectangle {
  id: root

  required property var theme
  property var options: []
  property var value

  signal picked(var value)

  width: row.implicitWidth + theme.px(4)
  height: theme.px(26)
  radius: theme.px(7)
  color: theme.fill
  border.width: theme.hairline
  border.color: theme.line

  Row {
    id: row
    anchors.centerIn: parent

    Repeater {
      model: root.options

      delegate: Rectangle {
        id: seg
        required property var modelData
        readonly property bool on: root.value === modelData.value

        width: segText.implicitWidth + root.theme.px(18)
        height: root.height - root.theme.px(4)
        radius: root.theme.px(5)
        color: on ? root.theme.fillHot : (segArea.containsMouse ? root.theme.fill : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          id: segText
          anchors.centerIn: parent
          text: seg.modelData.label
          textFormat: Text.PlainText
          font.family: root.theme.font
          font.pixelSize: root.theme.smallSize
          font.weight: seg.on ? Font.DemiBold : Font.Normal
          color: seg.on ? root.theme.accent : root.theme.dim
        }

        MouseArea {
          id: segArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(seg.modelData.value)
        }
      }
    }
  }
}
