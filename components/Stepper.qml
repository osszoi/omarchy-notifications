import QtQuick

Row {
  id: root

  required property var theme
  property int value: 0
  property int from: 0
  property int to: 100
  property int step: 1
  property bool wrap: false
  property string suffix: ""
  property var format: null

  signal changed(int value)

  function bump(direction) {
    var next = value + direction * step
    if (wrap) {
      var span = to - from + step
      next = ((next - from) % span + span) % span + from
    } else {
      next = Math.max(from, Math.min(to, next))
    }
    if (next !== value) changed(next)
  }

  spacing: theme.px(6)

  StepButton { label: "−"; dimmed: !root.wrap && root.value <= root.from; onClicked: root.bump(-1) }

  Text {
    width: Math.max(root.theme.px(46), implicitWidth)
    height: root.theme.px(24)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: root.format ? root.format(root.value) : root.value + root.suffix
    font.family: root.theme.font
    font.pixelSize: root.theme.smallSize + 1
    color: root.theme.fg
  }

  StepButton { label: "+"; dimmed: !root.wrap && root.value >= root.to; onClicked: root.bump(1) }

  component StepButton: Rectangle {
    id: btn
    property string label: ""
    property bool dimmed: false
    signal clicked()

    width: root.theme.px(24)
    height: width
    radius: root.theme.px(6)
    color: btnArea.containsMouse && !dimmed ? root.theme.fillHot : root.theme.fill
    opacity: dimmed ? 0.4 : 1

    Text {
      anchors.centerIn: parent
      text: btn.label
      font.family: root.theme.font
      font.pixelSize: root.theme.bodySize
      color: root.theme.fg
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (!btn.dimmed) btn.clicked()
    }
  }
}
