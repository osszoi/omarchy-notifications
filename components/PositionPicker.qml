import QtQuick

Rectangle {
  id: root

  required property var theme
  property string value: "top-right"

  signal picked(string value)

  readonly property var spots: [
    { value: "top-left", col: 0, row: 0 }, { value: "top-center", col: 1, row: 0 }, { value: "top-right", col: 2, row: 0 },
    { value: "bottom-left", col: 0, row: 1 }, { value: "bottom-center", col: 1, row: 1 }, { value: "bottom-right", col: 2, row: 1 }
  ]

  width: theme.px(78)
  height: theme.px(46)
  radius: theme.smallRadius
  color: "transparent"
  border.width: theme.hairline
  border.color: theme.fillHot

  Repeater {
    model: root.spots

    delegate: Item {
      id: spot
      required property var modelData
      readonly property bool on: root.value === modelData.value

      width: root.width / 3
      height: root.height / 2
      x: modelData.col * width
      y: modelData.row * height

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: (spot.modelData.col - 1) * root.theme.px(5)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: spot.modelData.row === 0 ? -root.theme.px(3) : root.theme.px(3)
        width: spot.on ? root.theme.px(9) : root.theme.px(6)
        height: width
        radius: width / 2
        color: spot.on ? root.theme.accent : (spotArea.containsMouse ? root.theme.dim : root.theme.faint)
      }

      MouseArea {
        id: spotArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(spot.modelData.value)
      }
    }
  }
}
