import QtQuick

Rectangle {
  id: root

  required property var theme
  property string label: ""
  property string glyph: ""
  property bool primary: false
  property bool active: false
  property string tooltip: ""

  signal clicked()

  readonly property bool iconOnly: label.length === 0

  width: iconOnly ? height : content.implicitWidth + theme.px(18)
  height: theme.px(26)
  radius: theme.round(height)
  color: primary ? theme.accent
    : (active ? theme.accentFill : (area.containsMouse ? theme.fillHot : (iconOnly ? "transparent" : theme.fill)))

  Behavior on color { ColorAnimation { duration: 140 } }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: root.theme.px(6)

    Text {
      visible: root.glyph.length > 0
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      font.family: root.theme.iconFont
      font.pixelSize: root.theme.px(12)
      color: root.primary ? root.theme.onAccent : (root.active ? root.theme.accent : root.theme.dim)
    }

    Text {
      visible: !root.iconOnly
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      textFormat: Text.PlainText
      font.family: root.theme.font
      font.pixelSize: root.theme.smallSize
      font.weight: root.primary ? Font.DemiBold : Font.Normal
      color: root.primary ? root.theme.onAccent : (root.active ? root.theme.accent : root.theme.dim)
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
