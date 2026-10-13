import QtQuick
import qs.Commons

QtObject {
  property real glassOpacity: 0.94

  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color onAccent: Color.background
  readonly property color glass: Util.alpha(Color.menu.background, glassOpacity)
  readonly property color glassHot: Qt.tint(glass, Util.alpha(Color.foreground, 0.05))
  readonly property color border: Util.alpha(Color.foreground, 0.09)
  readonly property color line: Util.alpha(Color.foreground, 0.08)
  readonly property color fill: Util.alpha(Color.foreground, 0.05)
  readonly property color fillHot: Util.alpha(Color.foreground, 0.1)
  readonly property color dim: Util.alpha(Color.foreground, 0.62)
  readonly property color faint: Util.alpha(Color.foreground, 0.4)
  readonly property color accentFill: Util.alpha(Color.accent, 0.16)
  readonly property color accentLine: Util.alpha(Color.accent, 0.5)
  readonly property color urgentFill: Util.alpha(Color.urgent, 0.16)
  readonly property color urgentLine: Util.alpha(Color.urgent, 0.5)

  readonly property string font: Style.font.menuFamily
  readonly property string iconFont: Style.font.family
  readonly property int titleSize: Style.font.title
  readonly property int bodySize: Style.font.body
  readonly property int smallSize: Math.max(Style.font.caption, Math.round(Style.font.body * 0.92))

  readonly property int radius: Style.space(12)
  readonly property int rowRadius: Style.space(8)
  readonly property int hairline: Math.max(1, Style.spacing.hairline)
  readonly property int cardWidth: Style.space(400)
  readonly property int gap: Style.space(10)
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
}
