// no Qt in here so node can test it (test/model-test.js)

var POSITIONS = ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
var FOOTER_ACTIONS = ["app", "open", "snooze", "dismiss"]
var RULE_MODES = ["normal", "center", "mute"]

var DEFAULTS = {
  version: 1,
  style: "glass",
  footer: false,
  footerActions: ["app", "open", "snooze"],
  timer: "bar",
  hideAfter: 8,
  critical: "stay",
  groupByApp: true,
  position: "top-right",
  monitor: "focused",
  maxOnScreen: 4,
  collapseDuplicates: true,
  pauseOnHover: true,
  snoozeMinutes: 10,
  badge: "count",
  keepHistory: 100,
  shortcut: "SUPER + N",
  dndSchedule: { enabled: false, from: "23:00", to: "08:00" },
  silenceFullscreen: false,
  siteIcons: true,
  glassOpacity: 94,
  blur: true,
  rules: []
}

function clampInt(value, low, high, fallback) {
  var n = Math.round(Number(value))
  if (!isFinite(n)) return fallback
  return Math.max(low, Math.min(high, n))
}

function pick(value, allowed, fallback) {
  return allowed.indexOf(value) !== -1 ? value : fallback
}

function validClock(value, fallback) {
  var s = String(value || "")
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(s) ? s : fallback
}

function normalizeRule(rule) {
  if (!rule || typeof rule !== "object") return null
  var app = String(rule.app || "").trim().toLowerCase()
  if (!app) return null
  return {
    app: app,
    label: String(rule.label || app),
    mode: pick(rule.mode, RULE_MODES, "normal"),
    hideBody: rule.hideBody === true
  }
}

function normalizeSettings(raw) {
  var s = raw && typeof raw === "object" ? raw : {}
  var d = DEFAULTS
  var footer = Array.isArray(s.footerActions)
    ? FOOTER_ACTIONS.filter(function(a) { return s.footerActions.indexOf(a) !== -1 })
    : d.footerActions.slice()
  var schedule = s.dndSchedule && typeof s.dndSchedule === "object" ? s.dndSchedule : {}
  var rules = []
  var seen = {}
  if (Array.isArray(s.rules)) {
    for (var i = 0; i < s.rules.length; i++) {
      var r = normalizeRule(s.rules[i])
      if (r && !seen[r.app]) {
        seen[r.app] = true
        rules.push(r)
      }
    }
  }
  return {
    version: 1,
    style: pick(s.style, ["glass", "omarchy"], d.style),
    footer: typeof s.footer === "boolean" ? s.footer : s.style === "footer",
    footerActions: footer,
    timer: pick(s.timer, ["bar", "ring", "none"], d.timer),
    hideAfter: clampInt(s.hideAfter, 2, 60, d.hideAfter),
    critical: pick(s.critical, ["stay", "auto"], d.critical),
    groupByApp: typeof s.groupByApp === "boolean" ? s.groupByApp : d.groupByApp,
    position: pick(s.position, POSITIONS, d.position),
    monitor: pick(s.monitor, ["focused", "primary"], d.monitor),
    maxOnScreen: clampInt(s.maxOnScreen, 1, 10, d.maxOnScreen),
    collapseDuplicates: typeof s.collapseDuplicates === "boolean" ? s.collapseDuplicates : d.collapseDuplicates,
    pauseOnHover: typeof s.pauseOnHover === "boolean" ? s.pauseOnHover : d.pauseOnHover,
    snoozeMinutes: clampInt(s.snoozeMinutes, 1, 240, d.snoozeMinutes),
    badge: pick(s.badge, ["count", "dot", "none"], d.badge),
    keepHistory: clampInt(s.keepHistory, 10, 500, d.keepHistory),
    shortcut: typeof s.shortcut === "string" && s.shortcut.trim() ? s.shortcut.trim() : d.shortcut,
    dndSchedule: {
      enabled: schedule.enabled === true,
      from: validClock(schedule.from, d.dndSchedule.from),
      to: validClock(schedule.to, d.dndSchedule.to)
    },
    silenceFullscreen: s.silenceFullscreen === true,
    siteIcons: typeof s.siteIcons === "boolean" ? s.siteIcons : d.siteIcons,
    glassOpacity: clampInt(s.glassOpacity, 40, 100, d.glassOpacity),
    blur: typeof s.blur === "boolean" ? s.blur : d.blur,
    rules: rules
  }
}

function parseSettingsText(text) {
  var t = String(text || "").trim()
  if (!t) return normalizeSettings({})
  try {
    return normalizeSettings(JSON.parse(t))
  } catch (e) {
    return normalizeSettings({})
  }
}

function serializeSettings(settings) {
  return JSON.stringify(normalizeSettings(settings), null, 2) + "\n"
}

function clockMinutes(value) {
  var m = /^(\d{2}):(\d{2})$/.exec(String(value || ""))
  if (!m) return -1
  return Number(m[1]) * 60 + Number(m[2])
}

// from == to is never, from > to wraps midnight (23:00 → 08:00)
function inWindow(nowMinutes, from, to) {
  var f = clockMinutes(from)
  var t = clockMinutes(to)
  if (f < 0 || t < 0 || f === t) return false
  if (f < t) return nowMinutes >= f && nowMinutes < t
  return nowMinutes >= f || nowMinutes < t
}

function isChromiumDerived(app, appIcon) {
  var source = (String(app || "") + "\n" + String(appIcon || "")).toLowerCase()
  return source.indexOf("chrom") >= 0 || source.indexOf("brave") >= 0 ||
         source.indexOf("vivaldi") >= 0 || source.indexOf("microsoft-edge") >= 0 ||
         source.indexOf("opera") >= 0
}

function normalizeHost(host) {
  var h = String(host || "").toLowerCase().replace(/^www\./, "").replace(/:\d+$/, "")
  return /^([a-z0-9-]+\.)+[a-z]{2,}$/.test(h) ? h : ""
}

// chromium puts the site on the body's first line, a link since we advertise hyperlinks
function hostFromBody(body) {
  var text = String(body || "")
  var link = /^\s*<a\b[^>]*href\s*=\s*["']?https?:\/\/([^\/"'\s>]+)/i.exec(text)
  if (link) return normalizeHost(link[1])
  var bare = /^\s*(?:https?:\/\/)?((?:[a-z0-9-]+\.)+[a-z]{2,})(?::\d+)?(?:\/\S*)?\s*(?:\n|$)/i.exec(text)
  return bare ? normalizeHost(bare[1]) : ""
}

var APP_LABELS = {
  "omarchy-action": "Omarchy",
  "notify-send": "Notify",
  "google chrome": "Chrome",
  "zen": "Zen"
}

function prettyApp(app) {
  var name = String(app || "").trim()
  if (!name) return "Notification"
  var known = APP_LABELS[name.toLowerCase()]
  if (known) return known
  return name.charAt(0).toUpperCase() + name.slice(1)
}

// webapps comes from bin/eduardo-notifications-webapps
function identify(entry, webapps, siteIcons) {
  var e = entry || {}
  var app = String(e.app || "")
  var host = siteIcons !== false && isChromiumDerived(app, e.appIcon) ? hostFromBody(e.body) : ""
  if (host) {
    var known = webapps && webapps[host]
    return {
      key: "web:" + host,
      label: known && known.name ? String(known.name) : host,
      host: host,
      icon: known && known.icon ? String(known.icon) : ""
    }
  }
  return { key: app.trim().toLowerCase() || "notification", label: prettyApp(app), host: "", icon: "" }
}

function ruleFor(rules, key) {
  if (!Array.isArray(rules)) return null
  for (var i = 0; i < rules.length; i++) {
    if (rules[i] && rules[i].app === key) return rules[i]
  }
  return null
}

function isDuplicate(a, b) {
  if (!a || !b) return false
  return String(a.appKey || "") === String(b.appKey || "")
    && String(a.summary || "") === String(b.summary || "")
    && String(a.body || "") === String(b.body || "")
}

function groupRows(rows, groupByApp) {
  var groups = []
  var byKey = {}
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i] || {}
    var key = groupByApp ? String(row.appKey || "") : "row:" + i
    var g = byKey[key]
    if (!g) {
      g = { key: key, appKey: String(row.appKey || ""), label: String(row.appLabel || ""), indices: [] }
      byKey[key] = g
      groups.push(g)
    }
    g.indices.push(i)
  }
  return groups
}

// positions for every card (toasts and center), maxGroups/fadeAfter 0 = off
function layout(opts) {
  var rows = opts.rows || []
  var heights = opts.heights || []
  var gap = Number(opts.gap || 0)
  var sliver = Number(opts.sliver || 0)
  var headerHeight = Number(opts.headerHeight || 0)
  var overflowHeight = Number(opts.overflowHeight || 0)
  var maxGroups = Number(opts.maxGroups || 0)
  var expanded = opts.expanded || {}
  var fadeAfter = Number(opts.fadeAfter || 0)
  var groups = groupRows(rows, !!opts.groupByApp)

  var cards = []
  for (var c = 0; c < rows.length; c++) cards.push(null)
  var headers = []
  var y = 0
  var hiddenCount = 0
  var shownGroups = 0

  function h(i) {
    var v = Number(heights[i] || 0)
    return v > 0 ? v : 64
  }

  for (var gi = 0; gi < groups.length; gi++) {
    var g = groups[gi]
    var n = g.indices.length
    var over = maxGroups > 0 && shownGroups >= maxGroups
    var fade = fadeAfter > 0 && gi >= fadeAfter ? Math.max(0.5, 1 - (gi - fadeAfter + 1) * 0.12) : 1

    if (over) {
      for (var k = 0; k < n; k++) {
        var idx = g.indices[k]
        cards[idx] = { y: y, h: h(idx), scale: 0.96, opacity: 0, z: 0, visible: false, front: false,
                       groupKey: g.key, groupSize: n, expanded: false }
        hiddenCount++
      }
      continue
    }
    shownGroups++

    var isOpen = n > 1 && !!expanded[g.key]
    if (isOpen) {
      headers.push({ key: g.key, label: g.label, count: n, y: y })
      y += headerHeight + gap
      for (var e = 0; e < n; e++) {
        var ei = g.indices[e]
        cards[ei] = { y: y, h: h(ei), scale: 1, opacity: fade, z: n - e, visible: true, front: true,
                      groupKey: g.key, groupSize: n, expanded: true }
        y += h(ei) + gap
      }
      continue
    }

    var frontH = h(g.indices[0])
    for (var b = 0; b < n; b++) {
      var bi = g.indices[b]
      var layer = Math.min(b, 2)
      cards[bi] = {
        y: y + layer * sliver,
        h: b === 0 ? frontH : frontH,
        scale: 1 - layer * 0.045,
        opacity: b === 0 ? fade : (b <= 2 ? fade * (1 - layer * 0.3) : 0),
        z: n - b,
        visible: b <= 2,
        front: b === 0,
        groupKey: g.key,
        groupSize: n,
        expanded: false
      }
    }
    y += frontH + Math.min(n - 1, 2) * sliver + gap
  }

  var overflow = null
  if (hiddenCount > 0) {
    overflow = { y: y, count: hiddenCount }
    y += overflowHeight + gap
  }

  return { cards: cards, headers: headers, overflow: overflow, height: Math.max(0, y - gap) }
}

function relativeTime(timestamp, now) {
  var t = Number(timestamp || 0)
  var n = Number(now || 0)
  if (!(t > 0)) return ""
  var s = Math.max(0, Math.floor((n - t) / 1000))
  if (s < 45) return "now"
  if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m"
  var then = new Date(t)
  var today = new Date(n)
  var sameDay = then.toDateString() === today.toDateString()
  if (sameDay) return Math.floor(s / 3600) + "h"
  var yesterday = new Date(n - 86400000)
  if (then.toDateString() === yesterday.toDateString()) return "yesterday"
  if (s < 6 * 86400) return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][then.getDay()]
  return then.getDate() + "/" + (then.getMonth() + 1)
}

function dayLabel(timestamp, now) {
  var then = new Date(Number(timestamp || 0))
  var today = new Date(Number(now || 0))
  if (then.toDateString() === today.toDateString()) return "Today"
  var yesterday = new Date(Number(now || 0) - 86400000)
  if (then.toDateString() === yesterday.toDateString()) return "Yesterday"
  return "Earlier"
}

var QT_KEYS = {
  0x20: "SPACE", 0x2c: "comma", 0x2e: "period", 0x2f: "slash", 0x2d: "minus", 0x3d: "equal",
  0x3b: "semicolon", 0x27: "apostrophe", 0x5b: "bracketleft", 0x5d: "bracketright",
  0x5c: "backslash", 0x60: "grave",
  0x01000001: "TAB", 0x01000004: "RETURN", 0x01000005: "RETURN", 0x01000003: "BACKSPACE",
  0x01000007: "DELETE", 0x01000010: "HOME", 0x01000011: "END",
  0x01000012: "LEFT", 0x01000013: "UP", 0x01000014: "RIGHT", 0x01000015: "DOWN",
  0x01000016: "PAGE_UP", 0x01000017: "PAGE_DOWN"
}

var MODIFIER_KEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000053, 0x01000054, 0x01001103]

// "" until a real key lands, and always needs a modifier so typing can't become a bind
function chordFromKey(modifiers, key) {
  var k = Number(key)
  if (MODIFIER_KEYS.indexOf(k) !== -1) return ""
  var name = ""
  if (k >= 0x41 && k <= 0x5a) name = String.fromCharCode(k)
  else if (k >= 0x30 && k <= 0x39) name = String.fromCharCode(k)
  else if (k >= 0x01000030 && k <= 0x0100003b) name = "F" + (k - 0x01000030 + 1)
  else if (QT_KEYS[k]) name = QT_KEYS[k]
  if (!name) return ""
  var m = Number(modifiers)
  var parts = []
  if (m & 0x10000000) parts.push("SUPER")
  if (m & 0x04000000) parts.push("CTRL")
  if (m & 0x08000000) parts.push("ALT")
  if (m & 0x02000000) parts.push("SHIFT")
  if (parts.length === 0) return ""
  parts.push(name)
  return parts.join(" + ")
}

function chordParts(chord) {
  return String(chord || "").split("+").map(function(p) { return p.trim() }).filter(function(p) { return p.length > 0 })
}

function unreadCount(timestamps, lastSeen) {
  var seen = Number(lastSeen || 0)
  var n = 0
  for (var i = 0; i < timestamps.length; i++) if (Number(timestamps[i] || 0) > seen) n++
  return n
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULTS: DEFAULTS,
    POSITIONS: POSITIONS,
    normalizeSettings: normalizeSettings,
    parseSettingsText: parseSettingsText,
    serializeSettings: serializeSettings,
    clockMinutes: clockMinutes,
    inWindow: inWindow,
    hostFromBody: hostFromBody,
    identify: identify,
    prettyApp: prettyApp,
    ruleFor: ruleFor,
    isDuplicate: isDuplicate,
    groupRows: groupRows,
    layout: layout,
    relativeTime: relativeTime,
    dayLabel: dayLabel,
    chordFromKey: chordFromKey,
    chordParts: chordParts,
    unreadCount: unreadCount
  }
}
