// node test/model-test.js
var assert = require("assert")
var M = require("../Model.js")

var passed = 0
function test(name, fn) {
  try {
    fn()
    passed++
  } catch (error) {
    console.error("FAIL " + name + "\n  " + error.message)
    process.exitCode = 1
  }
}

test("defaults come back for empty or broken settings", function() {
  assert.deepStrictEqual(M.parseSettingsText(""), M.normalizeSettings({}))
  assert.deepStrictEqual(M.parseSettingsText("{nope"), M.normalizeSettings({}))
  var s = M.normalizeSettings({})
  assert.strictEqual(s.style, "glass")
  assert.strictEqual(s.timer, "bar")
  assert.strictEqual(s.silenceFullscreen, false)
  assert.strictEqual(s.dndSchedule.enabled, false)
  assert.strictEqual(s.keepHistory, 100)
})

test("settings are clamped and filtered", function() {
  var s = M.normalizeSettings({
    hideAfter: 999, maxOnScreen: 0, keepHistory: 3, timer: "spinner",
    footerActions: ["dismiss", "bogus", "open"], position: "middle",
    dndSchedule: { enabled: true, from: "25:00", to: "07:30" },
    rules: [{ app: "Slack", mode: "mute" }, { app: "slack", mode: "center" }, { mode: "center" }]
  })
  assert.strictEqual(s.hideAfter, 60)
  assert.strictEqual(s.maxOnScreen, 1)
  assert.strictEqual(s.keepHistory, 10)
  assert.strictEqual(s.timer, "bar")
  assert.deepStrictEqual(s.footerActions, ["open", "dismiss"])
  assert.strictEqual(s.position, "top-right")
  assert.deepStrictEqual(s.dndSchedule, { enabled: true, from: "23:00", to: "07:30" })
  assert.strictEqual(s.rules.length, 1)
  assert.strictEqual(s.rules[0].app, "slack")
  assert.strictEqual(s.rules[0].mode, "mute")
})

test("style is glass or omarchy, old footer style migrates", function() {
  var old = M.normalizeSettings({ style: "footer" })
  assert.strictEqual(old.style, "glass")
  assert.strictEqual(old.footer, true)
  var om = M.normalizeSettings({ style: "omarchy" })
  assert.strictEqual(om.style, "omarchy")
  assert.strictEqual(om.footer, false)
  assert.strictEqual(M.normalizeSettings({ style: "omarchy", footer: true }).footer, true)
  assert.strictEqual(M.normalizeSettings({ style: "neon" }).style, "glass")
})

test("serialize round-trips", function() {
  var s = M.normalizeSettings({ timer: "ring", groupByApp: false })
  assert.deepStrictEqual(M.parseSettingsText(M.serializeSettings(s)), s)
})

test("schedule window wraps midnight", function() {
  assert.strictEqual(M.inWindow(23 * 60 + 30, "23:00", "08:00"), true)
  assert.strictEqual(M.inWindow(7 * 60 + 59, "23:00", "08:00"), true)
  assert.strictEqual(M.inWindow(8 * 60, "23:00", "08:00"), false)
  assert.strictEqual(M.inWindow(12 * 60, "23:00", "08:00"), false)
  assert.strictEqual(M.inWindow(13 * 60, "12:00", "14:00"), true)
  assert.strictEqual(M.inWindow(13 * 60, "12:00", "12:00"), false)
})

test("chrome bodies carry the site", function() {
  assert.strictEqual(M.hostFromBody('<a href="https://app.slack.com/">app.slack.com</a>\n\nhi'), "app.slack.com")
  assert.strictEqual(M.hostFromBody('<a href="https://www.youtube.com/watch">youtube.com</a>\n\nx'), "youtube.com")
  assert.strictEqual(M.hostFromBody("web.whatsapp.com\n\nhello"), "web.whatsapp.com")
  assert.strictEqual(M.hostFromBody("just a sentence. with dots"), "")
  assert.strictEqual(M.hostFromBody(""), "")
})

test("identify uses the site only for chromium senders", function() {
  var body = '<a href="https://app.slack.com/">app.slack.com</a>\n\nyo'
  var chrome = M.identify({ app: "Google Chrome", appIcon: "file:///tmp/x", body: body }, {}, true)
  assert.deepStrictEqual(chrome, { key: "web:app.slack.com", label: "app.slack.com", host: "app.slack.com", icon: "" })
  var known = M.identify({ app: "Google Chrome", body: body }, { "app.slack.com": { name: "Slack", icon: "/x.png" } }, true)
  assert.strictEqual(known.label, "Slack")
  assert.strictEqual(known.icon, "/x.png")
  var off = M.identify({ app: "Google Chrome", body: body }, {}, false)
  assert.strictEqual(off.key, "google chrome")
  assert.strictEqual(off.label, "Chrome")
  var zen = M.identify({ app: "Zen", body: "Sticker" }, {}, true)
  assert.deepStrictEqual(zen, { key: "zen", label: "Zen", host: "", icon: "" })
  assert.strictEqual(M.identify({ app: "omarchy-action" }, {}, true).label, "Omarchy")
  assert.strictEqual(M.identify({ app: "kitty" }, {}, true).label, "Kitty")
})

test("duplicates need same app, summary and body", function() {
  var a = { appKey: "kitty", summary: "Claude Code", body: "done" }
  assert.strictEqual(M.isDuplicate(a, { appKey: "kitty", summary: "Claude Code", body: "done" }), true)
  assert.strictEqual(M.isDuplicate(a, { appKey: "kitty", summary: "Claude Code", body: "other" }), false)
  assert.strictEqual(M.isDuplicate(a, null), false)
})

test("groups keep newest-first order", function() {
  var rows = [{ appKey: "slack" }, { appKey: "kitty" }, { appKey: "slack" }, { appKey: "zen" }]
  var g = M.groupRows(rows, true)
  assert.deepStrictEqual(g.map(function(x) { return x.key }), ["slack", "kitty", "zen"])
  assert.deepStrictEqual(g[0].indices, [0, 2])
  var flat = M.groupRows(rows, false)
  assert.strictEqual(flat.length, 4)
})

test("collapsed deck stacks slivers behind the front card", function() {
  var rows = [{ appKey: "slack" }, { appKey: "slack" }, { appKey: "slack" }, { appKey: "slack" }, { appKey: "kitty" }]
  var out = M.layout({ rows: rows, heights: [80, 120, 60, 60, 50], groupByApp: true, gap: 10, sliver: 8 })
  assert.strictEqual(out.cards[0].y, 0)
  assert.strictEqual(out.cards[1].y, 8)
  assert.strictEqual(out.cards[2].y, 16)
  assert.strictEqual(out.cards[3].visible, false)
  assert.strictEqual(out.cards[1].h, 80)
  assert.strictEqual(out.cards[4].y, 80 + 16 + 10)
  assert.strictEqual(out.height, 80 + 16 + 10 + 50)
})

test("expanded deck lists every card under a header", function() {
  var rows = [{ appKey: "slack", appLabel: "Slack" }, { appKey: "slack", appLabel: "Slack" }, { appKey: "kitty" }]
  var out = M.layout({ rows: rows, heights: [80, 60, 50], groupByApp: true, expanded: { slack: true },
                       gap: 10, sliver: 8, headerHeight: 32 })
  assert.deepStrictEqual(out.headers, [{ key: "slack", label: "Slack", count: 2, y: 0 }])
  assert.strictEqual(out.cards[0].y, 42)
  assert.strictEqual(out.cards[1].y, 132)
  assert.strictEqual(out.cards[2].y, 202)
})

test("groups past the limit fold into the overflow pill", function() {
  var rows = [{ appKey: "a" }, { appKey: "b" }, { appKey: "c" }, { appKey: "c" }]
  var out = M.layout({ rows: rows, heights: [50, 50, 50, 50], groupByApp: true, maxGroups: 2,
                       gap: 10, sliver: 8, overflowHeight: 28 })
  assert.strictEqual(out.cards[2].visible, false)
  assert.strictEqual(out.cards[3].visible, false)
  assert.deepStrictEqual(out.overflow, { y: 120, count: 2 })
  assert.strictEqual(out.height, 148)
})

test("relative times", function() {
  var now = new Date(2026, 9, 13, 20, 0, 0).getTime()
  assert.strictEqual(M.relativeTime(now - 10000, now), "now")
  assert.strictEqual(M.relativeTime(now - 5 * 60000, now), "5m")
  assert.strictEqual(M.relativeTime(now - 3 * 3600000, now), "3h")
  assert.strictEqual(M.relativeTime(new Date(2026, 9, 12, 21, 0).getTime(), now), "yesterday")
  assert.strictEqual(M.dayLabel(now - 1000, now), "Today")
})

test("chords need a modifier and a nameable key", function() {
  assert.strictEqual(M.chordFromKey(0x10000000, 0x4e), "SUPER + N")
  assert.strictEqual(M.chordFromKey(0x10000000 | 0x02000000, 0x2c), "SUPER + SHIFT + comma")
  assert.strictEqual(M.chordFromKey(0x14000000, 0x01000031), "SUPER + CTRL + F2")
  assert.strictEqual(M.chordFromKey(0, 0x4e), "")
  assert.strictEqual(M.chordFromKey(0x10000000, 0x01000022), "")
  assert.deepStrictEqual(M.chordParts("SUPER + SHIFT + N"), ["SUPER", "SHIFT", "N"])
})

test("unread counts entries after last seen", function() {
  assert.strictEqual(M.unreadCount([5, 10, 15], 10), 1)
  assert.strictEqual(M.unreadCount([], 0), 0)
})

console.log(passed + " passed")
