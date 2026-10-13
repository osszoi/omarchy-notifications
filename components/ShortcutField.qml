import QtQuick
import "../Model.js" as Model

Item {
  id: root

  required property var theme
  property string chord: ""
  property bool capturing: false

  signal picked(string chord)
  signal captureChanged(bool on)

  function start() {
    capturing = true
    forceActiveFocus()
    captureChanged(true)
  }

  function stop() {
    if (!capturing) return
    capturing = false
    captureChanged(false)
  }

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight
  width: implicitWidth
  height: implicitHeight

  Keys.onPressed: function(event) {
    if (!root.capturing) return
    event.accepted = true
    if (event.key === Qt.Key_Escape) {
      root.stop()
      return
    }
    var next = Model.chordFromKey(event.modifiers, event.key)
    if (next) {
      root.stop()
      root.picked(next)
    }
  }

  onActiveFocusChanged: if (!activeFocus) stop()

  Row {
    id: row
    spacing: root.theme.px(4)

    Text {
      visible: root.capturing
      anchors.verticalCenter: parent.verticalCenter
      text: "Press a shortcut…"
      font.family: root.theme.font
      font.pixelSize: root.theme.smallSize
      color: root.theme.accent
    }

    Repeater {
      model: root.capturing ? [] : Model.chordParts(root.chord)

      delegate: Rectangle {
        required property string modelData
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.theme.px(22), capText.implicitWidth + root.theme.px(12))
        height: root.theme.px(22)
        radius: root.theme.smallRadius
        color: root.theme.fill
        border.width: root.theme.hairline
        border.color: root.theme.fillHot

        Text {
          id: capText
          anchors.centerIn: parent
          text: modelData
          textFormat: Text.PlainText
          font.family: root.theme.font
          font.pixelSize: root.theme.smallSize
          color: root.theme.fg
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: root.theme.px(6)
      text: root.capturing ? "Cancel" : "Change"
      font.family: root.theme.font
      font.pixelSize: root.theme.smallSize
      font.weight: Font.DemiBold
      color: changeArea.containsMouse ? root.theme.fg : root.theme.accent

      MouseArea {
        id: changeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.capturing ? root.stop() : root.start()
      }
    }
  }
}
