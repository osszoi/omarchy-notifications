import QtQuick

Item {
  id: root

  required property var theme
  property string label: ""
  property string hint: ""
  property bool dimmed: false
  property bool clickable: false
  default property alias control: holder.data

  signal clicked()

  width: parent ? parent.width : theme.cardWidth
  height: Math.max(theme.px(38), holder.height + theme.px(10), labelCol.implicitHeight + theme.px(12))
  opacity: dimmed ? 0.45 : 1

  Behavior on opacity { NumberAnimation { duration: 160 } }

  MouseArea {
    anchors.fill: parent
    enabled: root.clickable
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Column {
    id: labelCol
    anchors.left: parent.left
    anchors.leftMargin: root.theme.px(16)
    anchors.right: holder.left
    anchors.rightMargin: root.theme.px(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.theme.px(1)

    Text {
      width: parent.width
      text: root.label
      textFormat: Text.PlainText
      font.family: root.theme.font
      font.pixelSize: root.theme.bodySize
      color: root.theme.fg
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: root.hint.length > 0
      text: root.hint
      textFormat: Text.PlainText
      font.family: root.theme.font
      font.pixelSize: root.theme.smallSize
      color: root.theme.faint
      wrapMode: Text.Wrap
    }
  }

  Item {
    id: holder
    anchors.right: parent.right
    anchors.rightMargin: root.theme.px(16)
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
}
