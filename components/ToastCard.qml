import QtQuick
import Quickshell
import qs.Commons
import "../NotificationLogic.js" as NotificationLogic
import "../Model.js" as Model

Rectangle {
  id: root

  required property var theme
  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property string glyph: ""
  property string appLabel: ""
  property string siteIcon: ""
  property int urgency: 1
  property int repeat: 1
  property double timestamp: 0
  property double now: 0
  property real progress: 1
  property string timerMode: "bar"
  property bool showTimer: false
  property bool footer: false
  property var footerActions: []
  property bool hideBody: false
  property int groupCount: 0
  property real contentOpacity: 1
  property bool closable: true

  signal activated()
  signal dismissRequested()
  signal snoozeRequested()
  signal appRequested()

  readonly property bool hovered: hover.hovered
  readonly property bool critical: urgency === 2
  readonly property string styledBody: hideBody ? "" : NotificationLogic.styledBody(body, app, appIcon)
  readonly property bool hasBody: styledBody.replace(/<[^>]*>/g, "").trim().length > 0
  property bool siteFailed: false
  readonly property string iconSource: resolve(siteIcon.length > 0 && !siteFailed ? siteIcon : appIcon)

  onSiteIconChanged: siteFailed = false
  readonly property bool hasImage: image.length > 0 && avatar.status !== Image.Error
  readonly property bool ring: showTimer && timerMode === "ring"
  readonly property bool wideImage: hasImage && !ring && avatar.ratio > 1.25
  readonly property bool hasIcon: !hasImage && iconImg.status === Image.Ready
  readonly property bool footerOn: footer && footerActions.length > 0
  readonly property color tone: critical ? theme.urgent : theme.accent
  readonly property string when: Model.relativeTime(timestamp, now)
  readonly property string meta: [appLabel, when].filter(function(s) { return s.length > 0 }).join(" · ")
    + (repeat > 1 ? "  ×" + repeat : "")

  function resolve(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  function has(action) { return footerActions.indexOf(action) !== -1 }

  width: theme.cardWidth
  implicitHeight: main.height + (footerOn ? footerBar.height : 0)
  radius: theme.radius
  color: critical ? Qt.tint(theme.glass, theme.urgentFill) : (hovered ? theme.glassHot : theme.glass)
  border.width: theme.hairline
  border.color: critical ? theme.urgentLine : theme.border
  antialiasing: true

  Behavior on color { ColorAnimation { duration: 160 } }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.activated()
      else root.dismissRequested()
    }
  }

  Item {
    id: main
    width: parent.width
    height: Math.max(slot.height, textCol.implicitHeight) + root.theme.px(28)
    opacity: root.contentOpacity

    Behavior on opacity { NumberAnimation { duration: 180 } }

    Item {
      id: slot
      x: root.theme.px(16)
      y: root.theme.px(14)
      width: root.ring ? root.theme.px(44) : (root.wideImage ? root.theme.px(64) : root.theme.px(36))
      height: root.ring ? root.theme.px(44) : root.theme.px(36)

      TimerRing {
        anchors.fill: parent
        visible: root.ring
        progress: root.progress
        color: root.tone
        track: root.theme.line
        thickness: 2
      }

      Rectangle {
        anchors.centerIn: parent
        width: root.ring ? root.theme.px(32) : root.theme.px(36)
        height: width
        radius: root.ring ? width / 2 : root.theme.rowRadius
        visible: !root.hasImage && !root.hasIcon
        color: root.critical ? root.theme.urgentFill : root.theme.accentFill

        Text {
          anchors.centerIn: parent
          text: root.glyph.length > 0 ? root.glyph : (root.critical ? root.theme.glyphWarn : root.theme.glyphBell)
          textFormat: Text.PlainText
          font.family: root.theme.iconFont
          font.pixelSize: root.theme.px(15)
          color: root.tone
        }
      }

      Image {
        id: iconImg
        anchors.centerIn: parent
        width: root.ring ? root.theme.px(22) : root.theme.px(30)
        height: width
        source: root.hasImage ? "" : root.iconSource
        visible: root.hasIcon
        asynchronous: true
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        // favicon not fetched (yet), fall back to the sender's own icon
        onStatusChanged: if (status === Image.Error && root.siteIcon.length > 0) root.siteFailed = true
      }

      RoundImage {
        id: avatar
        anchors.centerIn: parent
        width: root.ring ? root.theme.px(32) : parent.width
        height: root.ring ? root.theme.px(32) : parent.height
        source: root.image
        radius: root.wideImage ? root.theme.px(6) : width / 2
        visible: root.hasImage
      }
    }

    Column {
      id: textCol
      anchors.left: slot.right
      anchors.leftMargin: root.theme.px(12)
      anchors.right: parent.right
      anchors.rightMargin: root.theme.px(16)
      y: root.theme.px(14)
      spacing: root.theme.px(3)

      Item {
        width: parent.width
        height: Math.max(summaryText.implicitHeight, metaRow.height)

        Text {
          id: summaryText
          anchors.left: parent.left
          anchors.right: metaRow.left
          anchors.rightMargin: root.theme.px(8)
          text: root.summary.length > 0 ? root.summary : root.appLabel
          textFormat: Text.PlainText
          font.family: root.theme.font
          font.pixelSize: root.theme.titleSize
          font.weight: Font.DemiBold
          color: root.critical ? root.theme.urgent : root.theme.fg
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }

        Row {
          id: metaRow
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: Math.max(0, (summaryText.font.pixelSize - metaText.font.pixelSize) / 2)
          spacing: root.theme.px(6)
          opacity: root.closable && root.hovered ? 0 : 1

          Rectangle {
            visible: root.groupCount > 1
            anchors.verticalCenter: parent.verticalCenter
            width: countText.implicitWidth + root.theme.px(12)
            height: root.theme.px(17)
            radius: height / 2
            color: root.theme.accentFill

            Text {
              id: countText
              anchors.centerIn: parent
              text: String(root.groupCount)
              font.family: root.theme.font
              font.pixelSize: root.theme.smallSize
              font.weight: Font.DemiBold
              color: root.theme.accent
            }
          }

          Text {
            id: metaText
            text: root.meta
            textFormat: Text.PlainText
            font.family: root.theme.font
            font.pixelSize: root.theme.smallSize
            color: root.theme.faint
          }
        }
      }

      Text {
        width: parent.width
        visible: root.hasBody
        text: root.styledBody
        textFormat: Text.StyledText
        font.family: root.theme.font
        font.pixelSize: root.theme.bodySize
        color: root.theme.dim
        linkColor: root.theme.accent
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
      }
    }
  }

  Rectangle {
    id: closeBtn
    visible: root.closable && root.hovered
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: root.theme.px(10)
    width: root.theme.px(22)
    height: width
    radius: root.theme.px(6)
    color: closeArea.containsMouse ? root.theme.fillHot : root.theme.fill

    Text {
      anchors.centerIn: parent
      text: root.theme.glyphClose
      font.family: root.theme.iconFont
      font.pixelSize: root.theme.px(11)
      color: root.theme.dim
    }

    MouseArea {
      id: closeArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.dismissRequested()
    }
  }

  Item {
    id: footerBar
    visible: root.footerOn
    anchors.bottom: parent.bottom
    width: parent.width
    height: root.theme.px(34)
    opacity: root.contentOpacity

    Rectangle {
      width: parent.width
      height: root.theme.hairline
      color: root.theme.line
    }

    FooterButton {
      anchors.left: parent.left
      anchors.leftMargin: root.theme.px(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: root.has("app")
      label: root.appLabel
      onClicked: root.appRequested()
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: root.theme.px(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.theme.px(2)

      FooterButton {
        visible: root.has("open")
        label: "Open"
        accent: true
        onClicked: root.activated()
      }
      FooterButton {
        visible: root.has("snooze")
        label: "Snooze"
        onClicked: root.snoozeRequested()
      }
      FooterButton {
        visible: root.has("dismiss")
        label: "Dismiss"
        onClicked: root.dismissRequested()
      }
    }
  }

  Rectangle {
    visible: root.showTimer && root.timerMode === "bar"
    x: root.radius
    y: root.height - height - root.theme.hairline - 1
    height: 2
    radius: 1
    width: Math.max(0, (root.width - root.radius * 2) * Math.max(0, Math.min(1, root.progress)))
    color: root.tone
    opacity: 0.8 * root.contentOpacity
  }

  component FooterButton: Rectangle {
    id: btn
    property string label: ""
    property bool accent: false
    signal clicked()

    width: btnText.implicitWidth + root.theme.px(16)
    height: root.theme.px(24)
    radius: root.theme.px(6)
    color: btnArea.containsMouse ? root.theme.fillHot : "transparent"

    Text {
      id: btnText
      anchors.centerIn: parent
      text: btn.label
      textFormat: Text.PlainText
      font.family: root.theme.font
      font.pixelSize: root.theme.smallSize
      font.weight: btn.accent ? Font.DemiBold : Font.Normal
      color: btn.accent ? root.theme.accent : root.theme.dim
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: btn.clicked()
    }
  }
}
