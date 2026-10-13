import QtQuick

Row {
  id: root

  required property var theme
  property var options: []
  property var selected: []

  signal changed(var selected)

  function toggle(value) {
    var on = selected.indexOf(value) !== -1
    var next = options.map(function(o) { return o.value }).filter(function(v) {
      return v === value ? !on : root.selected.indexOf(v) !== -1
    })
    changed(next)
  }

  spacing: theme.px(4)

  Repeater {
    model: root.options

    delegate: Rectangle {
      id: chip
      required property var modelData
      readonly property bool on: root.selected.indexOf(modelData.value) !== -1

      width: chipText.implicitWidth + root.theme.px(16)
      height: root.theme.px(24)
      radius: height / 2
      color: on ? root.theme.accentFill : (chipArea.containsMouse ? root.theme.fill : "transparent")
      border.width: root.theme.hairline
      border.color: on ? root.theme.accentLine : root.theme.fillHot

      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.modelData.label
        textFormat: Text.PlainText
        font.family: root.theme.font
        font.pixelSize: root.theme.smallSize
        color: chip.on ? root.theme.accent : root.theme.dim
      }

      MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle(chip.modelData.value)
      }
    }
  }
}
