import QtQuick
import qs.Commons
import qs.Ui

// bell in the bar: click toggles the center, right click toggles do not disturb
BarWidget {
  id: root
  moduleName: "eduardo.notifications"

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property int unread: svc ? svc.unread : 0
  readonly property bool dnd: svc ? svc.doNotDisturb : false
  readonly property bool critical: svc ? svc.unreadCritical : false
  readonly property string badge: svc && svc.cfg ? svc.cfg.badge : "count"
  readonly property bool open: svc ? svc.centerOpen : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.dnd ? "" : ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    active: root.critical
    dimmed: root.dnd && root.unread === 0
    tooltipText: (root.unread > 0 ? root.unread + " new" : "No new notifications")
      + (root.dnd ? " · do not disturb" : "")
    onPressed: function(b) {
      if (!root.svc) return
      if (b === Qt.RightButton) root.svc.setDoNotDisturb(!root.dnd)
      else root.svc.toggleCenter()
    }
  }

  Rectangle {
    visible: root.unread > 0 && root.badge !== "none" && !root.open
    readonly property bool dot: root.badge === "dot"
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: dot ? Style.space(4) : Style.space(1)
    anchors.topMargin: dot ? Style.space(4) : Style.space(1)
    width: dot ? Style.space(6) : Math.max(height, countText.implicitWidth + Style.space(6))
    height: dot ? Style.space(6) : Style.space(13)
    radius: height / 2
    color: root.critical ? Color.urgent : Color.accent

    Text {
      id: countText
      visible: !parent.dot
      anchors.centerIn: parent
      text: root.unread > 99 ? "99+" : String(root.unread)
      font.family: Style.font.family
      font.pixelSize: Math.max(8, Style.font.caption - 1)
      font.weight: Font.Bold
      color: Color.background
    }
  }
}
