import QtQuick
import "../Model.js" as Model

Column {
  id: root

  required property var theme
  property var apps: []
  property var rules: []

  signal setRule(string key, string label, var patch)

  width: theme.cardWidth
  spacing: theme.gap

  SettingsSection {
    theme: root.theme
    title: root.apps.length > 0 ? "Center: no toast, kept in the center · Mute: dropped" : "No apps have notified yet"

    Repeater {
      model: root.apps

      delegate: Column {
        id: appRow
        required property var modelData
        required property int index
        readonly property var rule: Model.ruleFor(root.rules, modelData.key)
        readonly property string mode: rule ? rule.mode : "normal"

        width: parent.width

        Rectangle {
          visible: appRow.index > 0
          x: root.theme.px(16)
          width: parent.width - root.theme.px(32)
          height: root.theme.hairline
          color: root.theme.line
        }

        SettingRow {
          theme: root.theme
          label: appRow.modelData.label
          Segmented {
            theme: root.theme
            options: [{ value: "normal", label: "Normal" }, { value: "center", label: "Center" }, { value: "mute", label: "Mute" }]
            value: appRow.mode
            onPicked: function(v) { root.setRule(appRow.modelData.key, appRow.modelData.label, { mode: v }) }
          }
        }

        SettingRow {
          theme: root.theme
          label: "Hide text in toasts"
          dimmed: appRow.mode === "mute"
          height: root.theme.px(32)
          SwitchToggle {
            theme: root.theme
            checked: appRow.rule ? appRow.rule.hideBody : false
            onToggled: function(v) { root.setRule(appRow.modelData.key, appRow.modelData.label, { hideBody: v }) }
          }
        }
      }
    }
  }
}
