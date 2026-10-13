import QtQuick

FocusScope {
  id: root

  required property var host
  required property var theme
  property real progress: 0
  property string view: "list"
  property real topMargin: 0
  property real rightMargin: 0
  property bool capturing: false

  readonly property var cfg: host.cfg
  readonly property int count: host.centerCount

  function back() {
    if (view === "rules") view = "settings"
    else view = "list"
  }

  anchors.fill: parent
  focus: true

  Keys.onEscapePressed: function(event) {
    event.accepted = true
    if (root.capturing) return
    if (root.view !== "list") root.back()
    else root.host.closeCenter()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.host.closeCenter()
  }

  Item {
    id: column
    width: root.theme.cardWidth
    x: parent.width - width - root.rightMargin
    y: root.topMargin
    height: parent.height - root.topMargin - root.theme.px(16)
    opacity: root.progress
    scale: 0.98 + 0.02 * root.progress
    transformOrigin: Item.TopRight

    Rectangle {
      id: header
      anchors.right: parent.right
      width: headerRow.implicitWidth + root.theme.px(root.view === "list" ? 20 : 26)
      height: root.theme.px(36)
      radius: height / 2
      color: root.theme.glass
      border.width: root.theme.hairline
      border.color: root.theme.border

      Behavior on width { NumberAnimation { duration: root.theme.motion; easing.type: Easing.OutQuint } }

      MouseArea { anchors.fill: parent }

      Row {
        id: headerRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.theme.px(root.view === "list" ? 5 : 14)
        spacing: root.theme.px(4)

        PillButton {
          theme: root.theme
          visible: root.view !== "list"
          glyph: root.theme.glyphBack
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.back()
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          rightPadding: root.theme.px(6)
          text: root.view === "settings" ? "Settings"
            : root.view === "rules" ? "Per-app rules"
            : root.count === 0 ? "No notifications"
            : root.count === 1 ? "1 notification" : root.count + " notifications"
          textFormat: Text.PlainText
          font.family: root.theme.font
          font.pixelSize: root.theme.bodySize
          font.weight: Font.DemiBold
          color: root.theme.fg
        }

        PillButton {
          theme: root.theme
          visible: root.view === "list"
          glyph: root.host.doNotDisturb ? root.theme.glyphBellOff : root.theme.glyphMoon
          active: root.host.doNotDisturb
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.host.setDoNotDisturb(!root.host.doNotDisturb)
        }

        PillButton {
          theme: root.theme
          visible: root.view === "list"
          glyph: root.theme.glyphSettings
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.view = "settings"
        }

        PillButton {
          theme: root.theme
          visible: root.view === "list" && root.count > 0
          label: "Clear"
          primary: true
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.host.centerClearAll()
        }
      }
    }

    Flickable {
      id: flick
      y: header.height + root.theme.gap
      width: parent.width
      height: Math.min(contentHeight, parent.height - y)
      contentWidth: width
      contentHeight: root.view === "list" ? stack.height
        : root.view === "settings" ? (settingsLoader.item ? settingsLoader.item.height : 0)
        : (rulesLoader.item ? rulesLoader.item.height : 0)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      onContentHeightChanged: if (contentY > Math.max(0, contentHeight - height)) contentY = Math.max(0, contentHeight - height)

      CardStack {
        id: stack
        theme: root.theme
        visible: root.view === "list"
        model: root.host.centerModel
        mode: "center"
        groupByApp: root.cfg.groupByApp
        fadeAfter: 3
        expanded: root.host.centerExpanded
        now: root.host.now
        onCardActivated: function(i) { root.host.centerActivate(i) }
        onCardDismissed: function(i) { root.host.centerDismiss(i) }
        onGroupToggled: function(key) { root.host.centerToggleGroup(key) }
        onGroupCleared: function(key) { root.host.centerClearGroup(key) }
      }

      Loader {
        id: settingsLoader
        active: root.view === "settings"
        width: parent.width
        sourceComponent: SettingsView {
          theme: root.theme
          cfg: root.cfg
          shortcutStatus: root.host.shortcutStatus
          shortcutConflict: root.host.shortcutConflict
          rulesCount: root.cfg.rules.length
          opacity: 0
          Component.onCompleted: opacity = 1
          Behavior on opacity { NumberAnimation { duration: 220 } }
          onUpdate: function(patch) { root.host.updateSettings(patch) }
          onShortcutPicked: function(chord) { root.host.applyShortcut(chord, false) }
          onShortcutForce: root.host.applyShortcut(root.host.pendingShortcut, true)
          onOpenRules: root.view = "rules"
          onCaptureChanged: function(on) { root.capturing = on }
        }
      }

      Loader {
        id: rulesLoader
        active: root.view === "rules"
        width: parent.width
        sourceComponent: RulesView {
          theme: root.theme
          apps: root.host.knownApps
          rules: root.cfg.rules
          opacity: 0
          Component.onCompleted: opacity = 1
          Behavior on opacity { NumberAnimation { duration: 220 } }
          onSetRule: function(key, label, patch) { root.host.setRule(key, label, patch) }
        }
      }
    }
  }
}
