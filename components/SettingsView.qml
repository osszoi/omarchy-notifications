import QtQuick
import "../Model.js" as Model

Column {
  id: root

  required property var theme
  property var cfg: Model.normalizeSettings({})
  property string shortcutStatus: ""
  property bool shortcutConflict: false
  property int rulesCount: 0

  signal update(var patch)
  signal shortcutPicked(string chord)
  signal shortcutForce()
  signal openRules()
  signal captureChanged(bool on)

  function hhmm(minutes) {
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
  }

  function patchSchedule(key, value) {
    var s = { enabled: root.cfg.dndSchedule.enabled, from: root.cfg.dndSchedule.from, to: root.cfg.dndSchedule.to }
    s[key] = value
    root.update({ dndSchedule: s })
  }

  width: theme.cardWidth
  spacing: theme.gap

  SettingsSection {
    theme: root.theme
    title: "Toasts"

    SettingRow {
      theme: root.theme
      label: "Style"
      Segmented {
        theme: root.theme
        options: [{ value: "glass", label: "Glass" }, { value: "footer", label: "+ Footer" }]
        value: root.cfg.style
        onPicked: function(v) { root.update({ style: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Footer"
      dimmed: root.cfg.style !== "footer"
      ChipSet {
        theme: root.theme
        options: [{ value: "app", label: "App" }, { value: "open", label: "Open" },
                  { value: "snooze", label: "Snooze" }, { value: "dismiss", label: "Dismiss" }]
        selected: root.cfg.footerActions
        onChanged: function(v) { root.update({ footerActions: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Timer"
      Segmented {
        theme: root.theme
        options: [{ value: "bar", label: "Bar" }, { value: "ring", label: "Ring" }, { value: "none", label: "None" }]
        value: root.cfg.timer
        onPicked: function(v) { root.update({ timer: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Hide after"
      Stepper {
        theme: root.theme
        value: root.cfg.hideAfter
        from: 2
        to: 60
        suffix: " s"
        onChanged: function(v) { root.update({ hideAfter: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Critical"
      Segmented {
        theme: root.theme
        options: [{ value: "stay", label: "Stay" }, { value: "auto", label: "Auto-hide" }]
        value: root.cfg.critical
        onPicked: function(v) { root.update({ critical: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Group by app"
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.groupByApp
        onToggled: function(v) { root.update({ groupByApp: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Position"
      Row {
        spacing: root.theme.px(8)
        PositionPicker {
          theme: root.theme
          value: root.cfg.position
          anchors.verticalCenter: parent.verticalCenter
          onPicked: function(v) { root.update({ position: v }) }
        }
        Segmented {
          theme: root.theme
          anchors.verticalCenter: parent.verticalCenter
          options: [{ value: "focused", label: "Focused" }, { value: "primary", label: "Primary" }]
          value: root.cfg.monitor
          onPicked: function(v) { root.update({ monitor: v }) }
        }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Max on screen"
      Stepper {
        theme: root.theme
        value: root.cfg.maxOnScreen
        from: 1
        to: 10
        onChanged: function(v) { root.update({ maxOnScreen: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Collapse duplicates"
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.collapseDuplicates
        onToggled: function(v) { root.update({ collapseDuplicates: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Pause while hovered"
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.pauseOnHover
        onToggled: function(v) { root.update({ pauseOnHover: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Snooze for"
      Stepper {
        theme: root.theme
        value: root.cfg.snoozeMinutes
        from: 5
        to: 120
        step: 5
        suffix: " min"
        onChanged: function(v) { root.update({ snoozeMinutes: v }) }
      }
    }
  }

  SettingsSection {
    theme: root.theme
    title: "Center"

    SettingRow {
      theme: root.theme
      label: "Shortcut"
      hint: root.shortcutStatus
      ShortcutField {
        theme: root.theme
        chord: root.cfg.shortcut
        onPicked: function(c) { root.shortcutPicked(c) }
        onCaptureChanged: function(on) { root.captureChanged(on) }
      }
    }

    SettingRow {
      theme: root.theme
      visible: root.shortcutConflict
      label: "Take it anyway"
      hint: "unbinds the other action"
      PillButton {
        theme: root.theme
        label: "Use"
        primary: true
        onClicked: root.shortcutForce()
      }
    }

    SettingRow {
      theme: root.theme
      label: "Bar badge"
      Segmented {
        theme: root.theme
        options: [{ value: "count", label: "Count" }, { value: "dot", label: "Dot" }, { value: "none", label: "None" }]
        value: root.cfg.badge
        onPicked: function(v) { root.update({ badge: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Keep history"
      Stepper {
        theme: root.theme
        value: root.cfg.keepHistory
        from: 10
        to: 500
        step: 10
        onChanged: function(v) { root.update({ keepHistory: v }) }
      }
    }
  }

  SettingsSection {
    theme: root.theme
    title: "Do not disturb"

    SettingRow {
      theme: root.theme
      label: "Schedule"
      hint: root.cfg.dndSchedule.enabled ? root.cfg.dndSchedule.from + " – " + root.cfg.dndSchedule.to : ""
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.dndSchedule.enabled
        onToggled: function(v) { root.patchSchedule("enabled", v) }
      }
    }

    SettingRow {
      theme: root.theme
      visible: root.cfg.dndSchedule.enabled
      label: "From"
      Stepper {
        theme: root.theme
        value: Model.clockMinutes(root.cfg.dndSchedule.from)
        from: 0
        to: 1410
        step: 30
        wrap: true
        format: root.hhmm
        onChanged: function(v) { root.patchSchedule("from", root.hhmm(v)) }
      }
    }

    SettingRow {
      theme: root.theme
      visible: root.cfg.dndSchedule.enabled
      label: "To"
      Stepper {
        theme: root.theme
        value: Model.clockMinutes(root.cfg.dndSchedule.to)
        from: 0
        to: 1410
        step: 30
        wrap: true
        format: root.hhmm
        onChanged: function(v) { root.patchSchedule("to", root.hhmm(v)) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Silence over fullscreen"
      hint: "toasts go straight to the center"
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.silenceFullscreen
        onToggled: function(v) { root.update({ silenceFullscreen: v }) }
      }
    }
  }

  SettingsSection {
    theme: root.theme
    title: "Apps"

    SettingRow {
      theme: root.theme
      label: "Site icon for web apps"
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.siteIcons
        onToggled: function(v) { root.update({ siteIcons: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Per-app rules"
      clickable: true
      onClicked: root.openRules()
      Row {
        spacing: root.theme.px(6)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.rulesCount === 1 ? "1 rule" : root.rulesCount + " rules"
          font.family: root.theme.font
          font.pixelSize: root.theme.smallSize
          color: root.theme.dim
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.theme.glyphNext
          font.family: root.theme.iconFont
          font.pixelSize: root.theme.px(10)
          color: root.theme.dim
        }
      }
    }
  }

  SettingsSection {
    theme: root.theme
    title: "Appearance"

    SettingRow {
      theme: root.theme
      label: "Glass opacity"
      Stepper {
        theme: root.theme
        value: root.cfg.glassOpacity
        from: 40
        to: 100
        step: 2
        suffix: "%"
        onChanged: function(v) { root.update({ glassOpacity: v }) }
      }
    }

    SettingRow {
      theme: root.theme
      label: "Blur behind"
      SwitchToggle {
        theme: root.theme
        checked: root.cfg.blur
        onToggled: function(v) { root.update({ blur: v }) }
      }
    }
  }
}
