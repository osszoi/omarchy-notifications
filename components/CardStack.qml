import QtQuick
import "../Model.js" as Model

// every card is placed absolutely from Model.layout so inserts, decks opening
// and dismissals all animate as plain moves
Item {
  id: stack

  required property var theme
  property var model: null
  property string mode: "toast"
  property bool groupByApp: true
  property int maxGroups: 0
  property int fadeAfter: 0
  property bool flip: false
  property var expanded: ({})
  property double now: 0
  property var extraMs: ({})
  property string timerMode: "bar"
  property bool footer: false
  property var footerActions: []

  signal cardActivated(int index)
  signal cardDismissed(int index)
  signal cardSnoozed(int index)
  signal cardApp(int index)
  signal groupToggled(string key)
  signal groupCleared(string key)
  signal overflowClicked()

  property int revision: 0
  property var heights: ({})
  property int heightsRev: 0

  readonly property bool hovered: hoverArea.hovered
  readonly property var layoutData: compute(revision, heightsRev, expanded, groupByApp, maxGroups, fadeAfter)
  readonly property real contentHeight: layoutData.height

  width: theme.cardWidth
  height: contentHeight

  function compute() {
    var count = model ? model.count : 0
    var rows = []
    var map = []
    var hs = []
    for (var i = 0; i < count; i++) {
      var r = model.get(i)
      if (!r || r.leaving) continue
      rows.push({ appKey: r.appKey, appLabel: r.appLabel })
      map.push(i)
      hs.push(heights[r.stem] || 0)
    }
    var out = Model.layout({
      rows: rows, heights: hs, groupByApp: groupByApp, expanded: expanded, maxGroups: maxGroups,
      gap: theme.gap, sliver: theme.sliver, headerHeight: theme.pillHeight,
      overflowHeight: theme.pillHeight, fadeAfter: fadeAfter
    })
    var cards = []
    for (var c = 0; c < count; c++) cards.push(null)
    for (var k = 0; k < map.length; k++) cards[map[k]] = out.cards[k]
    return { cards: cards, headers: out.headers, overflow: out.overflow, height: out.height }
  }

  function ticking(index) {
    var c = layoutData.cards[index]
    return !!c && c.visible && (c.front || c.expanded)
  }

  function reportHeight(stem, h) {
    if (!stem || !(h > 0) || heights[stem] === h) return
    var next = {}
    for (var k in heights) next[k] = heights[k]
    next[stem] = h
    heights = next
    heightsRev++
  }

  function pruneHeights() {
    if (!model) return
    var keep = {}
    for (var i = 0; i < model.count; i++) {
      var r = model.get(i)
      if (r && heights[r.stem]) keep[r.stem] = heights[r.stem]
    }
    heights = keep
  }

  function flipY(y, h) {
    return flip ? layoutData.height - y - h : y
  }

  Connections {
    target: stack.model
    function onRowsInserted() { stack.revision++ }
    function onRowsRemoved() { stack.pruneHeights(); stack.revision++ }
    function onRowsMoved() { stack.revision++ }
    function onModelReset() { stack.pruneHeights(); stack.revision++ }
    function onDataChanged() { stack.revision++ }
  }

  HoverHandler { id: hoverArea }

  Repeater {
    model: stack.model

    delegate: Item {
      id: slot
      required property int index
      required property string stem
      required property string app
      required property string appIcon
      required property string summary
      required property string body
      required property string image
      required property string glyph
      required property string appKey
      required property string appLabel
      required property string siteIcon
      required property int urgency
      required property int repeat
      required property double timestamp
      required property double lifetime
      required property double deadline
      required property bool leaving
      required property bool hideBody

      readonly property var live: stack.layoutData.cards[index] || null
      property var held: null
      readonly property var spot: leaving ? (held || live) : (live || held)
      readonly property bool back: !!spot && !spot.front && !spot.expanded
      property bool entered: false

      onLiveChanged: if (live && !leaving) held = live

      width: stack.width
      height: card.height
      x: leaving ? stack.theme.px(28) : 0
      y: spot ? stack.flipY(spot.y, spot.h) : 0
      z: spot ? spot.z : 0
      opacity: !entered || leaving || !spot ? 0 : spot.opacity
      scale: spot ? spot.scale : 1
      transformOrigin: stack.flip ? Item.Bottom : Item.Top
      visible: opacity > 0.001
      enabled: !leaving && !!spot && spot.visible

      transform: Translate {
        y: slot.entered ? 0 : (stack.flip ? 8 : -8)
        Behavior on y { NumberAnimation { duration: stack.theme.motion; easing.type: Easing.OutQuint } }
      }

      Behavior on y {
        enabled: slot.entered
        NumberAnimation { duration: stack.theme.motion; easing.type: Easing.OutQuint }
      }
      Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.InCubic } }
      Behavior on opacity { NumberAnimation { duration: slot.leaving ? 150 : 240; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: stack.theme.motion; easing.type: Easing.OutQuint } }

      Component.onCompleted: Qt.callLater(function() { slot.entered = true })

      ToastCard {
        id: card
        theme: stack.theme
        width: parent.width
        height: slot.back && slot.spot ? slot.spot.h : implicitHeight
        app: slot.app
        appIcon: slot.appIcon
        summary: slot.summary
        body: slot.body
        image: slot.image
        glyph: slot.glyph
        appLabel: slot.appLabel
        siteIcon: slot.siteIcon
        urgency: slot.urgency
        repeat: slot.repeat
        timestamp: slot.timestamp
        now: stack.now
        progress: slot.lifetime > 0 ? (slot.deadline + (stack.extraMs[slot.stem] || 0) - stack.now) / slot.lifetime : 1
        showTimer: stack.mode === "toast" && slot.lifetime > 0 && stack.timerMode !== "none"
        timerMode: stack.timerMode
        footer: stack.mode === "toast" && stack.footer
        footerActions: stack.footerActions
        hideBody: slot.hideBody
        groupCount: slot.spot && slot.spot.front && !slot.spot.expanded ? slot.spot.groupSize : 0
        contentOpacity: slot.back ? 0 : 1
        closable: !slot.back

        Behavior on height { NumberAnimation { duration: stack.theme.motion; easing.type: Easing.OutQuint } }

        onImplicitHeightChanged: stack.reportHeight(slot.stem, implicitHeight)
        Component.onCompleted: stack.reportHeight(slot.stem, implicitHeight)

        onActivated: {
          if (slot.spot && slot.spot.groupSize > 1 && !slot.spot.expanded) stack.groupToggled(slot.spot.groupKey)
          else stack.cardActivated(slot.index)
        }
        onDismissRequested: stack.cardDismissed(slot.index)
        onSnoozeRequested: stack.cardSnoozed(slot.index)
        onAppRequested: stack.cardApp(slot.index)
      }
    }
  }

  Repeater {
    model: stack.layoutData.headers

    delegate: Rectangle {
      id: header
      required property var modelData
      property bool entered: false

      width: stack.width
      height: stack.theme.pillHeight
      y: stack.flipY(modelData.y, height)
      z: 1000
      radius: height / 2
      color: stack.theme.glass
      border.width: stack.theme.hairline
      border.color: stack.theme.border
      opacity: entered ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 220 } }
      Behavior on y { NumberAnimation { duration: stack.theme.motion; easing.type: Easing.OutQuint } }
      Component.onCompleted: Qt.callLater(function() { header.entered = true })

      Row {
        anchors.left: parent.left
        anchors.leftMargin: stack.theme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: stack.theme.px(8)

        Text {
          id: headerLabel
          text: header.modelData.label
          textFormat: Text.PlainText
          font.family: stack.theme.font
          font.pixelSize: stack.theme.bodySize
          font.weight: Font.DemiBold
          color: stack.theme.fg
        }

        Text {
          anchors.baseline: headerLabel.baseline
          text: String(header.modelData.count)
          font.family: stack.theme.font
          font.pixelSize: stack.theme.smallSize
          color: stack.theme.faint
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: stack.theme.px(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: stack.theme.px(4)

        PillButton {
          theme: stack.theme
          label: "Show less"
          glyph: stack.theme.glyphUp
          height: stack.theme.px(24)
          onClicked: stack.groupToggled(header.modelData.key)
        }
        PillButton {
          theme: stack.theme
          label: "Clear"
          height: stack.theme.px(24)
          onClicked: stack.groupCleared(header.modelData.key)
        }
      }
    }
  }

  Rectangle {
    id: overflowPill
    readonly property var info: stack.layoutData.overflow
    visible: !!info
    x: stack.width - width
    y: info ? stack.flipY(info.y, height) : 0
    z: 1000
    width: overflowText.implicitWidth + stack.theme.px(24)
    height: stack.theme.pillHeight
    radius: height / 2
    color: overflowArea.containsMouse ? stack.theme.glassHot : stack.theme.glass
    border.width: stack.theme.hairline
    border.color: stack.theme.border

    Behavior on y { NumberAnimation { duration: stack.theme.motion; easing.type: Easing.OutQuint } }

    Text {
      id: overflowText
      anchors.centerIn: parent
      text: overflowPill.info ? "+" + overflowPill.info.count + " more" : ""
      font.family: stack.theme.font
      font.pixelSize: stack.theme.smallSize
      color: stack.theme.dim
    }

    MouseArea {
      id: overflowArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: stack.overflowClicked()
    }
  }
}
