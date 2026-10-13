import QtQuick

Rectangle {
  id: root

  required property var theme
  property string title: ""
  default property alias content: col.data

  width: theme.cardWidth
  height: col.implicitHeight
  radius: theme.radius
  color: theme.glass
  border.width: theme.borderWidth
  border.color: theme.border

  Column {
    id: col
    width: parent.width
    bottomPadding: root.theme.px(6)

    Text {
      leftPadding: root.theme.px(16)
      topPadding: root.theme.px(10)
      bottomPadding: root.theme.px(2)
      text: root.title
      textFormat: Text.PlainText
      font.family: root.theme.font
      font.pixelSize: root.theme.smallSize
      font.bold: root.theme.sectionBold
      color: root.theme.sectionColor
    }
  }
}
