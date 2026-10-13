// stock omarchy.notifications (4.0.4) underneath: history files, dnd, click actions
// and ipc names untouched so omarchy's own binds keep working

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.Commons

import "components"
import "NotificationLogic.js" as NotificationLogic
import "Model.js" as Model

Item {
  id: service

  property var shell: null

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/+$/, "")
  readonly property string stateDir: home + "/.local/state/omarchy/"
  readonly property string settingsPath: stateDir + "notifications.json"
  readonly property string popupStateDir: stateDir + "notifications/"
  readonly property string historyDir: popupStateDir + "history/"
  readonly property string imagesDir: popupStateDir + "images/"
  readonly property string cfgPath: home + "/.config/omarchy/notifications.json"
  readonly property string faviconDir: home + "/.cache/eduardo-notifications/favicons/"
  readonly property string stockDir: "/usr/share/omarchy/shell/plugins/notifications"

  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property int defaultBarSize: barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property int liveBarSize: shell && shell.bar && !shell.bar.barHidden ? Math.max(0, shell.bar.barSize) : defaultBarSize
  readonly property int barClearance: liveBarSize + Style.gapsOut

  property var liveRefs: ({})


  property var cfg: Model.normalizeSettings({})
  property bool cfgLoaded: false

  Theme {
    id: glassTheme
    glassOpacity: service.cfg.glassOpacity / 100
  }

  FileView {
    id: cfgFile
    path: service.cfgPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: service.adoptSettings(Model.parseSettingsText(text()))
    onLoadFailed: service.adoptSettings(Model.normalizeSettings({}))
  }

  Timer {
    id: cfgSaveTimer
    interval: 250
    onTriggered: cfgFile.setText(Model.serializeSettings(service.cfg))
  }

  function adoptSettings(next) {
    var hyprChanged = cfgLoaded && next.blur !== cfg.blur
    cfg = next
    cfgLoaded = true
    if (hyprChanged) applyHypr(cfg.shortcut, true)
  }

  function updateSettings(patch) {
    var next = {}
    for (var k in cfg) next[k] = cfg[k]
    for (var p in patch) next[p] = patch[p]
    var normalized = Model.normalizeSettings(next)
    var blurChanged = normalized.blur !== cfg.blur
    cfg = normalized
    cfgSaveTimer.restart()
    if (blurChanged) applyHypr(cfg.shortcut, true)
    if (patch.rules !== undefined || patch.siteIcons !== undefined || patch.hideAfter !== undefined
        || patch.critical !== undefined) redecorate()
  }

  function setRule(key, label, patch) {
    var rules = cfg.rules.slice()
    var found = -1
    for (var i = 0; i < rules.length; i++) if (rules[i].app === key) found = i
    var rule = found >= 0 ? Object.assign({}, rules[found]) : { app: key, label: label, mode: "normal", hideBody: false }
    for (var p in patch) rule[p] = patch[p]
    if (found >= 0) rules[found] = rule
    else rules.push(rule)
    rules = rules.filter(function(r) { return r.mode !== "normal" || r.hideBody })
    updateSettings({ rules: rules })
  }


  property string shortcutStatus: ""
  property bool shortcutConflict: false
  property string pendingShortcut: ""

  function applyShortcut(chord, force) {
    if (!chord) return
    pendingShortcut = chord
    shortcutStatus = "checking…"
    shortcutConflict = false
    applyHypr(chord, force)
  }

  function applyHypr(chord, force) {
    var argv = [pluginDir + "/bin/eduardo-notifications-hypr", "apply", "--shortcut", chord, "--blur", cfg.blur ? "1" : "0"]
    if (force) argv.push("--force")
    hyprProc.command = argv
    hyprProc.running = true
  }

  Process {
    id: hyprProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.hyprDone(text)
    }
  }

  function hyprDone(raw) {
    var res = {}
    try { res = JSON.parse(String(raw || "").trim() || "{}") } catch (e) { res = { ok: false, error: "helper failed" } }
    if (res.ok) {
      shortcutStatus = ""
      shortcutConflict = false
      if (res.shortcut && res.shortcut !== cfg.shortcut) updateSettings({ shortcut: res.shortcut })
    } else if (res.conflict) {
      shortcutStatus = "used by: " + res.conflict
      shortcutConflict = true
    } else {
      shortcutStatus = res.error || "couldn't apply"
      shortcutConflict = false
    }
  }


  PersistentProperties {
    id: persisted
    reloadableId: "eduardo-notifications"
    property bool doNotDisturb: false
    onDoNotDisturbChanged: {
      if (service._hydrating) return
      service.scheduleSettingsSave()
    }
  }

  property bool _hydrating: false
  readonly property alias doNotDisturb: persisted.doNotDisturb

  function setDoNotDisturb(value) {
    persisted.doNotDisturb = !!value
  }

  property var scheduleState: null

  Timer {
    interval: 30000
    repeat: true
    triggeredOnStart: true
    running: service.cfgLoaded && service.cfg.dndSchedule.enabled
    onRunningChanged: if (!running) service.scheduleState = null
    onTriggered: {
      var d = new Date()
      var inside = Model.inWindow(d.getHours() * 60 + d.getMinutes(), service.cfg.dndSchedule.from, service.cfg.dndSchedule.to)
      if (service.scheduleState !== inside && (service.scheduleState !== null || inside)) service.setDoNotDisturb(inside)
      service.scheduleState = inside
    }
  }

  function fullscreenNow() {
    var m = Hyprland.focusedMonitor
    return !!(m && m.activeWorkspace && m.activeWorkspace.hasFullscreen)
  }


  property var webapps: ({})
  property var faviconState: ({})
  property var faviconRev: ({})
  property var faviconQueue: []

  Process {
    id: webappsProc
    command: [service.pluginDir + "/bin/eduardo-notifications-webapps"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { service.webapps = JSON.parse(text || "{}") } catch (e) { service.webapps = {} }
        service.redecorate()
      }
    }
  }

  function siteIconFor(ident) {
    if (!ident.host) return ""
    if (ident.icon) return ident.icon
    ensureFavicon(ident.host)
    var rev = faviconRev[ident.host]
    return "file://" + faviconDir + ident.host + ".png" + (rev ? "?v=" + rev : "")
  }

  function ensureFavicon(host) {
    if (faviconState[host]) return
    faviconState[host] = "pending"
    faviconQueue = faviconQueue.concat([host])
    nextFavicon()
  }

  function nextFavicon() {
    if (faviconProc.running || faviconQueue.length === 0) return
    var host = faviconQueue[0]
    faviconQueue = faviconQueue.slice(1)
    faviconProc.host = host
    faviconProc.command = [pluginDir + "/bin/eduardo-notifications-favicon", host, faviconDir + host + ".png"]
    faviconProc.running = true
  }

  Process {
    id: faviconProc
    property string host: ""
    running: false
    onExited: function(exitCode) {
      var host = faviconProc.host
      service.faviconState[host] = exitCode === 0 ? "done" : "failed"
      if (exitCode === 0) {
        var revs = {}
        for (var k in service.faviconRev) revs[k] = service.faviconRev[k]
        revs[host] = Date.now()
        service.faviconRev = revs
        service.redecorate()
      }
      service.nextFavicon()
    }
  }

  function identityOf(entry) {
    return Model.identify(entry, webapps, cfg.siteIcons)
  }

  function rowOf(e, now, live) {
    var ident = identityOf(e)
    var rule = Model.ruleFor(cfg.rules, ident.key)
    var lifetime = live ? durationFor(e.urgency, e.expireTimeout) : 0
    return {
      id: e.id || 0,
      originalId: e.originalId || e.id || 0,
      app: String(e.app || ""),
      appIcon: String(e.appIcon || ""),
      summary: String(e.summary || ""),
      body: String(e.body || ""),
      image: String(e.image || ""),
      glyph: String(e.glyph || ""),
      execArgv: String(e.execArgv || ""),
      urgency: typeof e.urgency === "number" ? e.urgency : NotificationUrgency.Normal,
      expireTimeout: Number(e.expireTimeout || 0),
      timestamp: Number(e.timestamp || 0),
      stem: NotificationLogic.imageStem(e),
      appKey: ident.key,
      appLabel: ident.label,
      siteIcon: siteIconFor(ident),
      hideBody: !!(rule && rule.hideBody),
      repeat: 1,
      lifetime: lifetime,
      deadline: lifetime > 0 ? now + lifetime : 0,
      leaving: false,
      live: !!live
    }
  }

  // identity, site icons and rules can change after a row exists
  function redecorate() {
    var models = [popupModel, centerModel]
    for (var m = 0; m < models.length; m++) {
      var model = models[m]
      for (var i = 0; i < model.count; i++) {
        var row = model.get(i)
        if (!row) continue
        var ident = identityOf(row)
        var rule = Model.ruleFor(cfg.rules, ident.key)
        var icon = siteIconFor(ident)
        if (row.appKey !== ident.key) model.setProperty(i, "appKey", ident.key)
        if (row.appLabel !== ident.label) model.setProperty(i, "appLabel", ident.label)
        if (row.siteIcon !== icon) model.setProperty(i, "siteIcon", icon)
        if (row.hideBody !== !!(rule && rule.hideBody)) model.setProperty(i, "hideBody", !!(rule && rule.hideBody))
      }
    }
    refreshKnownApps()
  }


  property alias popupModel: popupModel
  ListModel { id: popupModel }

  readonly property int historyLimit: cfg.keepHistory
  readonly property int maxPopupDuration: 120000

  function durationFor(urgency, expireTimeout) {
    var base = cfg.hideAfter * 1000
    if (urgency === NotificationUrgency.Critical) return cfg.critical === "stay" ? 0 : base * 2
    return Math.min(maxPopupDuration, Math.max(base, requestedDuration(expireTimeout)))
  }

  function requestedDuration(expireTimeout) {
    var ms = Number(expireTimeout || 0)
    if (!isFinite(ms) || ms <= 0) return 0
    return Math.round(ms)
  }

  function shouldBypassDnd(notification) {
    return NotificationLogic.shouldBypassDnd(notification, NotificationUrgency.Critical)
  }

  function snapshotOf(notification) {
    return NotificationLogic.snapshotOf(notification, Date.now())
  }

  function isEphemeral(notification) {
    var transient = false
    try {
      transient = !!(notification.hints && notification.hints["transient"])
    } catch (e) { transient = false }
    return transient || NotificationLogic.isEphemeralApp(String(notification.appName || ""))
  }

  function indexByStem(model, stem) {
    for (var i = 0; i < model.count; i++) {
      var row = model.get(i)
      if (row && row.stem === stem) return i
    }
    return -1
  }

  function firstActiveIndex() {
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (row && !row.leaving) return i
    }
    return -1
  }

  function findDuplicate(appKey, snapshot) {
    var probe = { appKey: appKey, summary: snapshot.summary, body: snapshot.body }
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (row && !row.leaving && row.originalId !== snapshot.originalId && Model.isDuplicate(row, probe)) return i
    }
    return -1
  }

  function handleNotification(notification) {
    notification.tracked = true
    var snapshot = snapshotOf(notification)
    liveRefs[snapshot.originalId] = notification
    notification.closed.connect(function() {
      if (service.liveRefs[snapshot.originalId] === notification)
        delete service.liveRefs[snapshot.originalId]
    })

    var ident = identityOf(snapshot)
    var rule = Model.ruleFor(cfg.rules, ident.key)
    var bypass = shouldBypassDnd(notification)

    if (rule && rule.mode === "mute" && !bypass) {
      delete liveRefs[snapshot.originalId]
      notification.tracked = false
      return
    }

    var silenced = !bypass && (service.doNotDisturb || (rule && rule.mode === "center")
      || (cfg.silenceFullscreen && fullscreenNow()))
    if (silenced) {
      if (!isEphemeral(notification)) {
        noteUnread(snapshot, notification)
        writeSilenced(notification, snapshot)
        if (centerOpen) refreshCenter()
        return
      }
      delete liveRefs[snapshot.originalId]
      notification.tracked = false
      return
    }

    if (cfg.collapseDuplicates) {
      var dup = findDuplicate(ident.key, snapshot)
      if (dup >= 0) {
        var existing = popupModel.get(dup)
        popupModel.setProperty(dup, "repeat", (existing.repeat || 1) + 1)
        if (existing.lifetime > 0) popupModel.setProperty(dup, "deadline", Date.now() + existing.lifetime)
        clearExtra(existing.stem)
        delete liveRefs[snapshot.originalId]
        notification.tracked = false
        return
      }
    }

    noteUnread(snapshot, notification)
    persistPopupFile(snapshot)
    watchForUpdates(notification, snapshot)
    Qt.callLater(function() {
      removePopupsByOriginalId(snapshot.originalId, NotificationLogic.popupFileName(snapshot))
      popupModel.insert(0, service.rowOf(snapshot, Date.now(), true))
      service.refreshPopup(notification, snapshot.originalId, snapshot.timestamp)
      if (service.centerOpen) service.refreshCenter()
    })
  }

  function writeSilenced(notification, written) {
    writeHistoryFile(written, function() {
      var updated = null
      try {
        updated = NotificationLogic.replacementSnapshot(notification, written.originalId, written.timestamp)
      } catch (e) {
      }
      if (updated && NotificationLogic.popupRowChanged(written, updated)) {
        service.writeSilenced(notification, updated)
        return
      }
      service.releaseSilenced(notification, written.originalId)
    })
  }

  function releaseSilenced(notification, originalId) {
    if (liveRefs[originalId] === notification) delete liveRefs[originalId]
    try {
      notification.tracked = false
    } catch (e) {
    }
  }

  readonly property var updateSignals: [
    "summaryChanged", "bodyChanged", "appNameChanged", "appIconChanged",
    "imageChanged", "urgencyChanged", "expireTimeoutChanged", "hintsChanged"
  ]

  function watchForUpdates(notification, snapshot) {
    function refresh() {
      service.refreshPopup(notification, snapshot.originalId, snapshot.timestamp)
    }

    for (var i = 0; i < updateSignals.length; i++) {
      var signal = notification[updateSignals[i]]
      if (signal && typeof signal.connect === "function") signal.connect(refresh)
    }
  }

  function refreshPopup(notification, originalId, timestamp) {
    if (service.liveRefs[originalId] !== notification) return

    var updated
    try {
      updated = NotificationLogic.replacementSnapshot(notification, originalId, timestamp)
    } catch (e) {
      return
    }

    var roles = NotificationLogic.popupRoles()
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (!row || row.originalId !== originalId || row.timestamp !== timestamp || row.leaving) continue
      if (!NotificationLogic.popupRowChanged(row, updated)) return
      var contentChanged = row.summary !== updated.summary || row.body !== updated.body || row.image !== updated.image
      for (var r = 0; r < roles.length; r++) popupModel.setProperty(i, roles[r], updated[roles[r]])
      var fresh = rowOf(updated, Date.now(), true)
      popupModel.setProperty(i, "appKey", fresh.appKey)
      popupModel.setProperty(i, "appLabel", fresh.appLabel)
      popupModel.setProperty(i, "siteIcon", fresh.siteIcon)
      popupModel.setProperty(i, "lifetime", fresh.lifetime)
      if (contentChanged) {
        popupModel.setProperty(i, "deadline", fresh.deadline)
        clearExtra(row.stem)
      }
      persistPopupFile(updated)
      return
    }
  }

  function isRestoredRow(row) {
    return !!row && !!restoredPopups[NotificationLogic.popupFileName(row)]
  }

  function removePopupsByOriginalId(originalId, keepFileName) {
    for (var i = popupModel.count - 1; i >= 0; i--) {
      var row = popupModel.get(i)
      if (!row || row.originalId !== originalId) continue
      if (isRestoredRow(row)) continue
      if (NotificationLogic.popupFileName(row) !== keepFileName) deletePopupFileFor(row)
      clearExtra(row.stem)
      popupModel.remove(i)
    }
  }

  function dismissPopup(index) {
    removePopup(index, "dismiss", true)
  }

  function expirePopup(index) {
    removePopup(index, "expire", true)
  }

  function removePopup(index, reason, archive) {
    if (index < 0 || index >= popupModel.count) return
    var entry = popupModel.get(index)
    if (!entry || entry.leaving) return
    var originalId = entry.originalId
    var restored = isRestoredRow(entry)
    var ref = !restored && originalId >= 0 ? liveRefs[originalId] : null
    if (archive) archivePopupFileFor(entry)
    else deletePopupFileFor(entry)
    if (restored) delete restoredPopups[NotificationLogic.popupFileName(entry)]
    clearExtra(entry.stem)
    beginLeave(popupModel, index)
    if (ref) {
      try {
        if (ref.tracked) {
          if (reason === "expire" && typeof ref.expire === "function") ref.expire()
          else ref.dismiss()
        }
      } catch (e) {
      }
    }
    if (centerOpen) refreshCenter()
  }

  function clearPopups(archive) {
    for (var i = popupModel.count - 1; i >= 0; i--) {
      var row = popupModel.get(i)
      if (row && !row.leaving) removePopup(i, "dismiss", archive !== false)
    }
  }

  function invokePopupDefault(index) {
    if (index < 0 || index >= popupModel.count) return
    var entry = popupModel.get(index)
    if (!entry || entry.leaving) return

    var argv = NotificationLogic.parseExecArgv(entry.execArgv)
    if (argv) {
      Util.execArgv(argv)
      dismissPopup(index)
      return
    }
    var ref = !isRestoredRow(entry) ? liveRefs[entry.originalId] : null
    var invoked = false
    try {
      if (ref && ref.actions) {
        for (var i = 0; i < ref.actions.length; i++) {
          var action = ref.actions[i]
          if (action && action.identifier === "default") {
            action.invoke()
            invoked = true
            break
          }
        }
      }
    } catch (e) {
      console.warn("invoke default failed:", e)
    }
    if (!invoked) focusApp(entry)
    dismissPopup(index)
  }

  function focusApp(entry) {
    if (!entry || !entry.app) return
    focusAppProc.command = [service.omarchyPath + "/bin/omarchy-hyprland-focus-app", String(entry.app)]
    focusAppProc.running = true
  }

  Process { id: focusAppProc; running: false }


  property var leaveQueue: []

  function beginLeave(model, index) {
    var row = model.get(index)
    if (!row || row.leaving) return
    model.setProperty(index, "leaving", true)
    leaveQueue = leaveQueue.concat([{ model: model, stem: row.stem, at: Date.now() + 190 }])
    leaveTimer.start()
  }

  Timer {
    id: leaveTimer
    interval: 60
    repeat: true
    onTriggered: {
      var t = Date.now()
      var keep = []
      for (var i = 0; i < service.leaveQueue.length; i++) {
        var job = service.leaveQueue[i]
        if (job.at > t) {
          keep.push(job)
          continue
        }
        var idx = service.indexByStem(job.model, job.stem)
        if (idx >= 0 && job.model.get(idx).leaving) job.model.remove(idx)
      }
      service.leaveQueue = keep
      if (keep.length === 0) stop()
    }
  }


  property double now: Date.now()
  property double lastTick: 0
  property var extraMs: ({})
  property bool toastHovered: false
  property var toastExpanded: ({})
  property int activePopups: 0

  function recountPopups() {
    var n = 0
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (row && !row.leaving) n++
    }
    activePopups = n
  }

  Connections {
    target: popupModel
    function onCountChanged() { service.recountPopups() }
    function onDataChanged() { service.recountPopups() }
  }

  function clearExtra(stem) {
    if (extraMs[stem] === undefined) return
    var next = {}
    for (var k in extraMs) if (k !== stem) next[k] = extraMs[k]
    extraMs = next
  }

  function toggleToastGroup(key) {
    var next = {}
    for (var k in toastExpanded) next[k] = toastExpanded[k]
    if (next[key]) delete next[key]
    else next[key] = true
    toastExpanded = next
  }

  Timer {
    interval: service.activePopups > 0 ? 50 : 1000
    repeat: true
    running: service.activePopups > 0 || service.centerOpen
    onRunningChanged: service.lastTick = 0
    onTriggered: service.tick()
  }

  function tick() {
    var t = Date.now()
    var dt = lastTick > 0 ? Math.min(1000, t - lastTick) : 0
    lastTick = t
    now = t

    var rows = []
    var idx = []
    for (var i = 0; i < popupModel.count; i++) {
      var r = popupModel.get(i)
      if (!r || r.leaving) continue
      rows.push({ appKey: r.appKey })
      idx.push(i)
    }
    if (idx.length === 0) return

    var running = {}
    var paused = centerOpen || (cfg.pauseOnHover && toastHovered)
    if (!paused) {
      var groups = Model.groupRows(rows, cfg.groupByApp)
      for (var g = 0; g < groups.length && g < cfg.maxOnScreen; g++) {
        var grp = groups[g]
        if (grp.indices.length > 1 && toastExpanded[grp.key]) {
          for (var k = 0; k < grp.indices.length; k++) running[idx[grp.indices[k]]] = true
        } else {
          running[idx[grp.indices[0]]] = true
        }
      }
    }

    var next = {}
    for (var key in extraMs) next[key] = extraMs[key]
    var expired = []
    for (var j = 0; j < idx.length; j++) {
      var row = popupModel.get(idx[j])
      if (!(row.lifetime > 0)) continue
      if (!running[idx[j]]) {
        next[row.stem] = (next[row.stem] || 0) + dt
        continue
      }
      if (t >= row.deadline + (next[row.stem] || 0)) expired.push(row.stem)
    }
    extraMs = next
    for (var e = 0; e < expired.length; e++) {
      var at = indexByStem(popupModel, expired[e])
      if (at >= 0) expirePopup(at)
    }
  }


  property var snoozed: []

  function snoozePopup(index) {
    var row = popupModel.get(index)
    if (!row || row.leaving) return
    var entry = {
      id: row.id, originalId: row.originalId, app: row.app, appIcon: row.appIcon, summary: row.summary,
      body: row.body, image: row.image, glyph: row.glyph, execArgv: row.execArgv, urgency: row.urgency,
      expireTimeout: row.expireTimeout, timestamp: row.timestamp
    }
    var kept = NotificationLogic.persistablePopup(entry, imagesDir).entry
    removePopup(index, "dismiss", true)
    snoozed = snoozed.concat([{ entry: kept, at: Date.now() + cfg.snoozeMinutes * 60000 }])
  }

  Timer {
    interval: 15000
    repeat: true
    running: service.snoozed.length > 0
    onTriggered: {
      var t = Date.now()
      var keep = []
      for (var i = 0; i < service.snoozed.length; i++) {
        var s = service.snoozed[i]
        if (s.at > t) {
          keep.push(s)
          continue
        }
        service.restoredPopups[NotificationLogic.popupFileName(s.entry)] = true
        service.persistPopupFile(s.entry)
        service.noteUnread(s.entry, null)
        popupModel.insert(0, service.rowOf(s.entry, t, true))
      }
      service.snoozed = keep
    }
  }


  property int unread: 0
  property bool unreadCritical: false
  property double lastSeen: 0

  function noteUnread(snapshot, notification) {
    if (centerOpen) return
    if (notification && isEphemeral(notification)) return
    if (!notification && NotificationLogic.isEphemeralApp(String(snapshot.app || ""))) return
    unread++
    if (snapshot.urgency === NotificationUrgency.Critical) unreadCritical = true
  }

  property bool centerOpen: false
  property string centerScreenName: ""
  property var centerExpanded: ({})
  property var knownApps: []
  property int centerCount: 0
  property real centerProgress: centerOpen ? 1 : 0
  readonly property bool centerVisible: centerOpen || centerProgress > 0.001

  Behavior on centerProgress {
    NumberAnimation {
      duration: service.centerOpen ? 220 : 140
      easing.type: service.centerOpen ? Easing.OutCubic : Easing.InCubic
    }
  }

  property alias centerModel: centerModel
  ListModel { id: centerModel }

  Connections {
    target: centerModel
    function onCountChanged() { service.recountCenter() }
    function onDataChanged() { service.recountCenter() }
  }

  function recountCenter() {
    var n = 0
    for (var i = 0; i < centerModel.count; i++) {
      var row = centerModel.get(i)
      if (row && !row.leaving) n++
    }
    centerCount = n
  }

  function openCenter() {
    if (centerOpen) return
    centerScreenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    centerOpen = true
    unread = 0
    unreadCritical = false
    lastSeen = Date.now()
    scheduleSettingsSave()
    refreshCenter()
  }

  function closeCenter() {
    centerOpen = false
  }

  function toggleCenter() {
    if (centerOpen) closeCenter()
    else openCenter()
  }

  function refreshCenter() {
    if (readHistoryProc.running || historyReadQueued) {
      centerRefreshPending = true
      return
    }
    historyReadQueued = true
    enqueueHistoryRead()
  }

  property bool centerRefreshPending: false

  function buildCenter(raw) {
    var live = liveRowsForReplay()
    var liveStems = {}
    for (var l = 0; l < live.length; l++) liveStems[NotificationLogic.imageStem(live[l])] = true
    var rows = NotificationLogic.historyRows(raw, live, NotificationUrgency.Normal, cfg.keepHistory + live.length)
    var t = Date.now()
    var desired = []
    var want = {}
    for (var i = 0; i < rows.length; i++) {
      var row = rowOf(rows[i], t, false)
      row.live = !!liveStems[row.stem]
      desired.push(row)
      want[row.stem] = true
    }

    for (var r = centerModel.count - 1; r >= 0; r--) {
      var cur = centerModel.get(r)
      if (!cur || cur.leaving || !want[cur.stem]) centerModel.remove(r)
    }
    for (var j = 0; j < desired.length; j++) {
      var at = indexByStem(centerModel, desired[j].stem)
      if (at === j) {
        if (centerModel.get(j).live !== desired[j].live) centerModel.setProperty(j, "live", desired[j].live)
        continue
      }
      if (at > j) centerModel.move(at, j, 1)
      else centerModel.insert(j, desired[j])
    }
    refreshKnownApps()

    if (centerRefreshPending) {
      centerRefreshPending = false
      Qt.callLater(refreshCenter)
    }
  }

  function refreshKnownApps() {
    var seen = {}
    var apps = []
    function add(key, label) {
      if (!key || seen[key]) return
      seen[key] = true
      apps.push({ key: key, label: label || key })
    }
    for (var i = 0; i < cfg.rules.length; i++) add(cfg.rules[i].app, cfg.rules[i].label)
    var models = [popupModel, centerModel]
    for (var m = 0; m < models.length; m++)
      for (var k = 0; k < models[m].count; k++) {
        var row = models[m].get(k)
        if (row) add(row.appKey, row.appLabel)
      }
    knownApps = apps
  }

  function deleteHistoryStem(stem) {
    enqueuePopupFileJob(["bash", "-c", "rm -f \"$1/$2.json\" \"$3/$2\"-*", "--", historyDir, stem, imagesDir])
  }

  function centerActivate(index) {
    var row = centerModel.get(index)
    if (!row || row.leaving) return
    var stem = row.stem
    if (row.live) {
      var p = indexByStem(popupModel, stem)
      if (p >= 0) invokePopupDefault(p)
    } else {
      var argv = NotificationLogic.parseExecArgv(row.execArgv)
      if (argv) Util.execArgv(argv)
      else focusApp(row)
    }
    deleteHistoryStem(stem)
    beginLeave(centerModel, index)
    closeCenter()
  }

  function centerDismiss(index) {
    var row = centerModel.get(index)
    if (!row || row.leaving) return
    if (row.live) {
      var p = indexByStem(popupModel, row.stem)
      if (p >= 0) removePopup(p, "dismiss", false)
    } else {
      deleteHistoryStem(row.stem)
    }
    beginLeave(centerModel, index)
  }

  function centerClearGroup(key) {
    for (var i = centerModel.count - 1; i >= 0; i--) {
      var row = centerModel.get(i)
      if (row && !row.leaving && row.appKey === key) centerDismiss(i)
    }
    centerToggleGroup(key)
  }

  function centerClearAll() {
    clearPopups(false)
    clearHistory()
    for (var i = centerModel.count - 1; i >= 0; i--) beginLeave(centerModel, i)
    centerExpanded = ({})
  }

  function centerToggleGroup(key) {
    var next = {}
    for (var k in centerExpanded) next[k] = centerExpanded[k]
    if (next[key]) delete next[key]
    else next[key] = true
    centerExpanded = next
  }

  Process {
    id: ensureDirsProc
    command: ["mkdir", "-p", service.stateDir, service.popupStateDir, service.historyDir, service.imagesDir, service.faviconDir]
    running: false
  }


  property var restoredPopups: ({})
  property var popupFileQueue: []
  property var runningPopupFileJobDone: null

  function enqueuePopupFileJob(command, done) {
    popupFileQueue = popupFileQueue.concat([{ command: command, done: done || null }])
    runNextPopupFileJob()
  }

  function enqueueHistoryRead() {
    popupFileQueue = popupFileQueue.concat([{ read: true }])
    runNextPopupFileJob()
  }

  function runNextPopupFileJob() {
    if (readHistoryProc.running || popupFileProc.running) return
    if (popupFileQueue.length === 0) return

    var job = popupFileQueue[0]
    popupFileQueue = popupFileQueue.slice(1)

    if (job.read) {
      startHistoryRead()
      return
    }

    popupFileProc.command = job.command
    service.runningPopupFileJobDone = job.done || null
    popupFileProc.running = true
  }

  Process {
    id: popupFileProc
    running: false
    onExited: {
      var done = service.runningPopupFileJobDone
      service.runningPopupFileJobDone = null
      if (done) {
        try {
          done()
        } catch (e) {
          console.warn("notifications: file job callback failed:", e)
        }
      }
      service.runNextPopupFileJob()
    }
  }

  readonly property string copyImagesScript:
    "while (( $# >= 2 )); do\n" +
    "  if [[ -f $1 ]] && timeout 5 head -c 5242881 -- \"$1\" > \"$2.tmp\" 2>/dev/null &&\n" +
    "     (( $(stat -c%s -- \"$2.tmp\") <= 5242880 )); then mv -f -- \"$2.tmp\" \"$2\"; else rm -f -- \"$2.tmp\"; fi\n" +
    "  shift 2\n" +
    "done\n"

  function persistPopupFile(snapshot) {
    var persistable = NotificationLogic.persistablePopup(snapshot, imagesDir)
    var command = ["bash", "-c",
      "mkdir -p \"$1\" \"$2\" || exit 0\n" +
      "dir=\"$1\" json=\"$3\" name=\"$4\"\n" +
      "shift 4\n" +
      copyImagesScript +
      "printf '%s\\n' \"$json\" > \"$dir/$name\"", "--",
      popupStateDir,
      imagesDir,
      NotificationLogic.serializePopup(persistable.entry, NotificationUrgency.Normal),
      NotificationLogic.popupFileName(snapshot)]
    for (var i = 0; i < persistable.copies.length; i++)
      command.push(persistable.copies[i].from, persistable.copies[i].to)
    enqueuePopupFileJob(command)
  }

  function deletePopupFileFor(row) {
    if (!row) return
    enqueuePopupFileJob(["bash", "-c",
      "rm -f \"$1/$2.json\" \"$3/$2\"-*", "--",
      popupStateDir, NotificationLogic.imageStem(row), imagesDir])
  }

  readonly property string trimHistoryScript:
    "ls -1 \"$hist\" 2>/dev/null | sort -n | head -n \"-$limit\" | while IFS= read -r stale; do rm -f \"$hist/$stale\" \"$imgs/${stale%.json}\"-*; done"

  function archivePopupFileFor(row) {
    if (!row) return
    enqueuePopupFileJob(["bash", "-c",
      "mkdir -p \"$1\" || exit 0\n" +
      "hist=\"$1\" limit=\"$2\" imgs=\"$5\"\n" +
      "mv -f \"$4/$3\" \"$1/$3\" 2>/dev/null || exit 0\n" +
      trimHistoryScript, "--",
      historyDir,
      String(historyLimit),
      NotificationLogic.popupFileName(row),
      popupStateDir,
      imagesDir])
  }

  function writeHistoryFile(entry, done) {
    if (!entry) {
      if (done) done()
      return
    }
    var persistable = NotificationLogic.persistablePopup(entry, imagesDir)
    var command = ["bash", "-c",
      "mkdir -p \"$1\" \"$5\" || exit 0\n" +
      "hist=\"$1\" limit=\"$2\" name=\"$3\" json=\"$4\" imgs=\"$5\"\n" +
      "shift 5\n" +
      copyImagesScript +
      "printf '%s\\n' \"$json\" > \"$hist/$name\" || exit 0\n" +
      trimHistoryScript, "--",
      historyDir,
      String(historyLimit),
      NotificationLogic.popupFileName(entry),
      NotificationLogic.serializePopup(persistable.entry, NotificationUrgency.Normal),
      imagesDir]
    for (var i = 0; i < persistable.copies.length; i++)
      command.push(persistable.copies[i].from, persistable.copies[i].to)
    enqueuePopupFileJob(command, done)
  }

  function clearHistory() {
    unread = 0
    unreadCritical = false
    enqueuePopupFileJob(["bash", "-c",
      "for f in \"$1\"/*.json; do\n" +
      "  [[ -e $f ]] || continue\n" +
      "  stale=\"${f##*/}\"\n" +
      "  rm -f \"$f\" \"$2/${stale%.json}\"-*\n" +
      "done", "--", historyDir, imagesDir])
  }

  function sweepOrphanImages() {
    enqueuePopupFileJob(["bash", "-c",
      "for img in \"$3\"/*; do\n" +
      "  [[ -e $img ]] || continue\n" +
      "  [[ $img == *.tmp ]] && { rm -f -- \"$img\"; continue; }\n" +
      "  stem=\"${img##*/}\"\n" +
      "  stem=\"${stem%-*}\"\n" +
      "  [[ -e $1/$stem.json || -e $2/$stem.json ]] || rm -f \"$img\"\n" +
      "done", "--", popupStateDir, historyDir, imagesDir])
  }

  Process {
    id: readHistoryProc
    running: false
    onExited: service.runNextPopupFileJob()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.buildCenter(text)
    }
  }

  property bool historyReadQueued: false

  function startHistoryRead() {
    service.historyReadQueued = false
    readHistoryProc.command = ["bash", "-c",
      "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", historyDir]
    readHistoryProc.running = true
  }

  function liveRowsForReplay() {
    var rows = []
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (!row || row.originalId < 0 || row.leaving) continue
      rows.push(NotificationLogic.persistablePopup({
        id: row.id,
        originalId: row.originalId,
        app: row.app,
        appIcon: row.appIcon,
        summary: row.summary,
        body: row.body,
        image: row.image,
        glyph: row.glyph || "",
        execArgv: row.execArgv || "",
        urgency: row.urgency,
        timestamp: row.timestamp
      }, imagesDir).entry)
    }
    return rows
  }

  Process {
    id: restorePopupsProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.restorePopups(text)
    }
  }

  function restorePopups(raw) {
    var entries = NotificationLogic.parsePopupFiles(raw, NotificationUrgency.Normal)
    var t = Date.now()
    var live = []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      var duration = durationFor(entry.urgency, entry.expireTimeout)
      if (NotificationLogic.popupExpired(entry, duration, t)) {
        archivePopupFileFor(entry)
        continue
      }
      if (duration > 0) {
        entry.deadline = t + duration
        persistPopupFile(entry)
        delete entry.deadline
      }
      live.push(entry)
    }
    if (live.length === 0) return

    Qt.callLater(function() {
      for (var j = 0; j < live.length; j++) {
        var restored = live[j]
        var duplicate = false
        for (var k = 0; k < popupModel.count; k++) {
          var row = popupModel.get(k)
          if (row && row.originalId === restored.originalId && row.timestamp === restored.timestamp) {
            duplicate = true
            break
          }
        }
        if (duplicate) continue
        service.restoredPopups[NotificationLogic.popupFileName(restored)] = true
        popupModel.append(service.rowOf(restored, Date.now(), true))
      }
    })
  }

  // counts what arrived while the shell was down or the center was closed
  Process {
    id: unreadProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var stamps = String(text || "").split("\n").map(function(n) { return Number(String(n).split("-")[0]) })
        service.unread += Model.unreadCount(stamps, service.lastSeen)
      }
    }
  }


  FileView {
    id: settingsFile
    path: service.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: service.loadSettings(text())
    onLoadFailed: service.loadSettings("")
  }

  Timer {
    id: settingsSaveTimer
    interval: 200
    repeat: false
    onTriggered: service.flushSettings()
  }

  function scheduleSettingsSave() {
    if (!service.settingsLoaded) return
    settingsSaveTimer.restart()
  }

  property bool settingsLoaded: false
  property string upstreamAck: ""

  function loadSettings(raw) {
    if (service.settingsLoaded) return

    var parsed = NotificationLogic.parseSettings(raw)
    if (parsed.error) console.warn("notifications: settings parse failed:", parsed.errorMessage || "")

    if (parsed.dnd !== null) {
      service._hydrating = true
      persisted.doNotDisturb = parsed.dnd
      service._hydrating = false
    }

    try {
      var extra = JSON.parse(String(raw || "").trim() || "{}")
      service.lastSeen = Number(extra.lastSeen || 0)
      service.upstreamAck = String(extra.upstreamAck || "")
    } catch (e) {
    }

    service.settingsLoaded = true
    if (parsed.legacy) service.scheduleSettingsSave()

    upstreamProc.running = true
    if (service.lastSeen <= 0) {
      service.lastSeen = Date.now()
      service.scheduleSettingsSave()
      return
    }
    unreadProc.command = ["bash", "-c", "ls -1 \"$1\" 2>/dev/null; ls -1 \"$2\" 2>/dev/null | grep '\\.json$'", "--", historyDir, popupStateDir]
    unreadProc.running = true
  }

  function flushSettings() {
    settingsFile.setText(JSON.stringify({
      version: 3,
      dnd: persisted.doNotDisturb,
      lastSeen: service.lastSeen,
      upstreamAck: service.upstreamAck
    }, null, 2) + "\n")
  }


  Process {
    id: upstreamProc
    running: false
    command: ["bash", "-c",
      "cd \"$1\" 2>/dev/null || exit 0\n" +
      "sha256sum -c --quiet \"$2\" >/dev/null 2>&1 && { echo same; exit 0; }\n" +
      "cat Service.qml NotificationLogic.js components/NotificationCard.qml manifest.json 2>/dev/null | sha256sum | cut -c1-16",
      "--", service.stockDir, service.pluginDir + "/upstream.sha256"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.upstreamChecked(String(text || "").trim())
    }
  }

  function upstreamChecked(result) {
    if (!result || result === "same" || result === upstreamAck) return
    upstreamAck = result
    scheduleSettingsSave()
    var entry = {
      id: -2, originalId: -2, app: "eduardo.notifications", appIcon: "",
      summary: "omarchy.notifications changed in this update",
      body: "eduardo.notifications is based on omarchy 4.0.4. Click to see what changed upstream.",
      image: "", glyph: "", urgency: NotificationUrgency.Normal, expireTimeout: 0, timestamp: Date.now(),
      execArgv: JSON.stringify(["omarchy-launch-floating-terminal-with-presentation", pluginDir + "/bin/eduardo-notifications-upstream-diff"])
    }
    restoredPopups[NotificationLogic.popupFileName(entry)] = true
    persistPopupFile(entry)
    popupModel.insert(0, rowOf(entry, Date.now(), true))
  }

  Component.onCompleted: {
    ensureDirsProc.running = true
    webappsProc.running = true
    Qt.callLater(function() {
      settingsFile.reload()
      restorePopupsProc.command = ["bash", "-c",
        "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", service.popupStateDir]
      restorePopupsProc.running = true
      service.sweepOrphanImages()
    })
  }


  IpcHandler {
    target: "notifications"

    function dndState(): string {
      return service.doNotDisturb ? "on" : "off"
    }

    function toggleDnd(): string {
      service.setDoNotDisturb(!service.doNotDisturb)
      return dndState()
    }

    function setDnd(value: string): string {
      var v = String(value || "").toLowerCase()
      var on = v === "true" || v === "1" || v === "on" || v === "yes"
      service.setDoNotDisturb(on)
      return dndState()
    }

    function isDnd(): string {
      return dndState()
    }

    // stock replayed history as toasts, the center is the history now
    function showHistory(): string {
      service.openCenter()
      return "ok"
    }

    function clear(): string {
      service.clearHistory()
      return "ok"
    }

    function dismissAll(): string {
      service.clearPopups(true)
      return "ok"
    }

    function dismissOne(): string {
      var i = service.firstActiveIndex()
      if (i < 0) return "none"
      service.dismissPopup(i)
      return "ok"
    }

    function invokeLast(): string {
      var i = service.firstActiveIndex()
      if (i < 0) return "none"
      service.invokePopupDefault(i)
      return "ok"
    }

    function dismiss(summary: string): string {
      var needle = String(summary || "")
      if (!needle) return "none"
      var hit = false
      for (var i = popupModel.count - 1; i >= 0; i--) {
        var row = popupModel.get(i)
        if (row && !row.leaving && String(row.summary || "").indexOf(needle) !== -1) {
          service.dismissPopup(i)
          hit = true
        }
      }
      return hit ? "ok" : "none"
    }

    function toggleCenter(): string {
      service.toggleCenter()
      return service.centerOpen ? "open" : "closed"
    }

    function openCenter(): string {
      service.openCenter()
      return "open"
    }

    function closeCenter(): string {
      service.closeCenter()
      return "closed"
    }

    function unreadCount(): string {
      return String(service.unread)
    }

    function ping(): string { return "ok" }
  }


  NotificationServer {
    id: server
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    persistenceSupported: true

    onNotification: function(notification) {
      service.handleNotification(notification)
    }
  }


  readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

  function isToastScreen(screen) {
    if (cfg.monitor === "primary") return Quickshell.screens.length > 0 && screen === Quickshell.screens[0]
    return !focusedScreenName || screen.name === focusedScreenName
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: popupWindow
      required property var modelData
      screen: modelData
      visible: popupModel.count > 0 && !service.centerVisible && service.isToastScreen(modelData)

      WlrLayershell.namespace: "eduardo-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors { top: true; bottom: true; left: true; right: true }
      mask: Region { item: toastStack }

      readonly property string pos: service.cfg.position
      readonly property bool atBottom: pos.indexOf("bottom") === 0
      readonly property int marginTop: service.barPosition === "top" ? service.barClearance : Style.gapsOut
      readonly property int marginBottom: service.barPosition === "bottom" ? service.barClearance : Style.gapsOut
      readonly property int marginLeft: service.barPosition === "left" ? service.barClearance : Style.gapsOut
      readonly property int marginRight: service.barPosition === "right" ? service.barClearance : Style.gapsOut

      CardStack {
        id: toastStack
        theme: glassTheme
        model: popupModel
        mode: "toast"
        groupByApp: service.cfg.groupByApp
        maxGroups: service.cfg.maxOnScreen
        flip: popupWindow.atBottom
        expanded: service.toastExpanded
        now: service.now
        extraMs: service.extraMs
        timerMode: service.cfg.timer
        footer: service.cfg.style === "footer"
        footerActions: service.cfg.footerActions
        x: popupWindow.pos.indexOf("left") > 0 ? popupWindow.marginLeft
          : popupWindow.pos.indexOf("center") > 0 ? Math.round((parent.width - width) / 2)
          : parent.width - width - popupWindow.marginRight
        y: popupWindow.atBottom ? parent.height - height - popupWindow.marginBottom : popupWindow.marginTop

        Behavior on y {
          enabled: popupWindow.atBottom
          NumberAnimation { duration: glassTheme.motion; easing.type: Easing.OutQuint }
        }

        onHoveredChanged: service.toastHovered = hovered
        onCardActivated: function(i) { service.invokePopupDefault(i) }
        onCardDismissed: function(i) { service.dismissPopup(i) }
        onCardSnoozed: function(i) { service.snoozePopup(i) }
        onCardApp: function(i) {
          var row = popupModel.get(i)
          service.focusApp(row)
          service.dismissPopup(i)
        }
        onGroupToggled: function(key) { service.toggleToastGroup(key) }
        onGroupCleared: function(key) {
          for (var i = popupModel.count - 1; i >= 0; i--) {
            var row = popupModel.get(i)
            if (row && !row.leaving && row.appKey === key) service.dismissPopup(i)
          }
          service.toggleToastGroup(key)
        }
        onOverflowClicked: service.openCenter()
      }
    }
  }


  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: centerWindow
      required property var modelData
      screen: modelData
      visible: service.centerVisible && (!service.centerScreenName || modelData.name === service.centerScreenName)

      WlrLayershell.namespace: "eduardo-notifications-center"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: service.centerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors { top: true; bottom: true; left: true; right: true }

      CenterView {
        id: centerView
        host: service
        theme: glassTheme
        progress: service.centerProgress
        topMargin: service.barPosition === "top" ? service.barClearance : Style.gapsOut
        rightMargin: service.barPosition === "right" ? service.barClearance : Style.gapsOut

        Connections {
          target: service
          function onCenterOpenChanged() {
            if (service.centerOpen) {
              centerView.view = "list"
              centerView.forceActiveFocus()
            }
          }
        }
      }
    }
  }
}
