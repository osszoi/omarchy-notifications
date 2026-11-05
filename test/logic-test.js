// node test/logic-test.js
var assert = require("assert")
var L = require("../NotificationLogic.js")

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

var file = "/home/u/Pictures/Screenshots/shot.png"
var open = ["xdg-open", file]
var edit = ["/usr/bin/omasnap", "--recent", "f6b1281a30fc4b67a7559f8a67ca5b3c", file]
var hints = {
  "omarchy-actions": JSON.stringify([{ label: "Abrir", argv: open }, { label: "Editar", argv: edit }]),
  "omarchy-exec-argv": JSON.stringify(open)
}

test("omasnap card click runs Edit, whatever the labels say", function() {
  assert.deepStrictEqual(JSON.parse(L.execArgvFromHints(hints, "omasnap")), edit)
  assert.deepStrictEqual(L.parseExecArgv(L.snapshotOf({ appName: "omasnap", hints: hints }).execArgv), edit)
})

test("other apps keep the sender's click", function() {
  assert.deepStrictEqual(JSON.parse(L.execArgvFromHints(hints, "omarchy-action")), open)
})

test("omasnap without a usable Edit falls back to the sender's click", function() {
  var openOnly = { "omarchy-actions": JSON.stringify([{ label: "Open", argv: open }]), "omarchy-exec-argv": JSON.stringify(open) }
  var broken = { "omarchy-actions": "{nope", "omarchy-exec-argv": JSON.stringify(open) }
  var noActions = { "omarchy-exec-argv": JSON.stringify(open) }
  assert.deepStrictEqual(JSON.parse(L.execArgvFromHints(openOnly, "omasnap")), open)
  assert.deepStrictEqual(JSON.parse(L.execArgvFromHints(broken, "omasnap")), open)
  assert.deepStrictEqual(JSON.parse(L.execArgvFromHints(noActions, "omasnap")), open)
  assert.strictEqual(L.execArgvFromHints({}, "omasnap"), "")
})

console.log(passed + " passed")
