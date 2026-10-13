import QtQuick
import qs.Commons

// "glass" is the spotlight look, "omarchy" mimics the stock surfaces
// (solid theme colors, accent border, hyprland rounding, stock fonts)
QtObject {
  id: theme

  property string style: "glass"
  property real glassOpacity: 0.94

  readonly property bool omarchy: style === "omarchy"

  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color onAccent: Color.background
  readonly property color glass: omarchy ? Color.notifications.background : Util.alpha(Color.menu.background, glassOpacity)
  readonly property color glassHot: Qt.tint(glass, Util.alpha(Color.foreground, 0.05))
  readonly property color border: omarchy ? Color.notifications.border : Util.alpha(Color.foreground, 0.09)
  readonly property int borderWidth: omarchy ? Math.max(1, Style.space(2)) : hairline
  readonly property color line: Util.alpha(Color.foreground, omarchy ? 0.14 : 0.08)
  readonly property color fill: Util.alpha(Color.foreground, 0.05)
  readonly property color fillHot: Util.alpha(Color.foreground, 0.1)
  readonly property color dim: omarchy ? Qt.darker(Color.notifications.text, 1.15) : Util.alpha(Color.foreground, 0.62)
  readonly property color faint: omarchy ? Qt.darker(Color.notifications.text, 1.4) : Util.alpha(Color.foreground, 0.4)
  readonly property color accentFill: Util.alpha(Color.accent, 0.16)
  readonly property color accentLine: Util.alpha(Color.accent, 0.5)
  readonly property color urgentFill: Util.alpha(Color.urgent, 0.16)
  readonly property color urgentLine: omarchy ? Color.urgent : Util.alpha(Color.urgent, 0.5)
  readonly property color countdown: omarchy ? Color.notifications.countdown : Color.accent
  readonly property color tileFill: omarchy ? "transparent" : accentFill
  readonly property color tileGlyph: omarchy ? Color.notifications.text : accent

  readonly property string font: omarchy ? Style.font.family : Style.font.menuFamily
  readonly property string cardFont: omarchy ? "Liberation Sans" : Style.font.menuFamily
  readonly property string iconFont: Style.font.family
  readonly property int titleSize: Style.font.title
  readonly property int bodySize: Style.font.body
  readonly property int cardBodySize: omarchy ? Style.font.title : Style.font.body
  readonly property int cardTitleWeight: omarchy ? Font.Bold : Font.DemiBold
  readonly property int smallSize: Math.max(Style.font.caption, Math.round(Style.font.body * 0.92))
  readonly property color sectionColor: omarchy ? Color.foreground : faint
  readonly property bool sectionBold: omarchy

  readonly property int hairline: Math.max(1, Style.spacing.hairline)
  readonly property int radius: omarchy ? Style.cornerRadius : Style.space(12)
  readonly property int rowRadius: omarchy ? Style.cornerRadius : Style.space(8)
  readonly property int smallRadius: omarchy ? Style.cornerRadius : Style.space(6)
  readonly property int cardWidth: Style.space(400)
  readonly property int gap: Style.space(omarchy ? 8 : 10)
  readonly property int sliver: Style.space(8)
  readonly property int pillHeight: Style.space(32)
  readonly property int motion: 320

  // nerd font (font awesome range), kept as escapes on purpose
  readonly property string glyphBell: ""
  readonly property string glyphBellOff: ""
  readonly property string glyphClose: ""
  readonly property string glyphSettings: ""
  readonly property string glyphMoon: ""
  readonly property string glyphBack: ""
  readonly property string glyphNext: ""
  readonly property string glyphUp: ""
  readonly property string glyphWarn: ""

  function px(value) { return Style.space(value) }
  function round(height) { return omarchy ? Style.cornerRadius : height / 2 }
}
