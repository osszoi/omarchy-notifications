# omarchy-notifications

Notification daemon for the Omarchy shell with glass toasts and a floating notification center behind a bell in the bar. It's a drop-in for `omarchy.notifications`: same history directory, same do-not-disturb state, same `omarchy-shell notifications …` commands, so `SUPER + ,` and friends keep working.

Based on `omarchy.notifications` from Omarchy 4.0.4 (MIT).

## Install

```bash
./install.sh
```

Symlinks the repo to `~/.config/omarchy/plugins/eduardo.notifications`, enables it (Omarchy turns the stock plugin off while this one is on), puts the bell before the power button and binds `SUPER + N` to the center.

Rollback: `omarchy plugin disable eduardo.notifications` (or `./uninstall.sh`). The stock plugin comes back on its own.

## What you get

- **Toasts**: glass cards, newest on top. Click runs the notification's action (or focuses the app), right/middle click or `×` dismisses. Grouped per app as a deck; clicking a deck opens it in place.
- **Center**: click the bell or press `SUPER + N`. Same cards, grouped, history included. `esc` or a click outside closes it. Right click on the bell toggles do not disturb.
- **Settings**: gear in the center. Everything is also in `~/.config/omarchy/notifications.json` and reloads live.

| Setting | Default |
|---|---|
| Style: glass (spotlight look) / omarchy (stock look: solid, accent border, Hyprland rounding) | glass |
| Footer with App, Open, Snooze, Dismiss | off |
| Timer (bar / ring / none), hide after | bar, 8 s |
| Critical stays or auto-hides | stays |
| Group by app, max on screen, collapse duplicates, pause while hovered | on, 4, on, on |
| Position (6 spots) and monitor (focused / primary) | top right, focused |
| Snooze for | 10 min |
| Center shortcut, bar badge (count / dot / none), history kept | `SUPER + N`, count, 100 |
| Do not disturb schedule, silence over fullscreen | off, off |
| Site icon for web apps, glass opacity, blur | on, 94 %, on |
| Per-app rules: normal / center only / mute, hide text in toasts | — |

## Web apps

Chrome-family browsers put the site in the notification, so toasts from `app.slack.com` show the installed web app's name and icon, or the site's own favicon (fetched once from that site, cached in `~/.cache/eduardo-notifications/favicons`). Firefox-family browsers (Zen) don't send the site at all, so those stay "Zen", with the sender's avatar when the page provides one.

## Shortcut and blur

The shortcut and the blur layer rule live in `~/.local/state/omarchy/toggles/hypr/eduardo-notifications.lua`, which Hyprland loads after `bindings.lua`. `bin/eduardo-notifications-hypr` writes it, reloads Hyprland and puts the old file back if the reload reports errors. Your `bindings.lua` is never edited.

## When Omarchy updates

The plugin keeps fingerprints of the stock files it was cut from (`upstream.sha256`). If an update changes them you get a notification; clicking it shows the upstream diff (`bin/eduardo-notifications-upstream-diff`) so the change can be ported.

## Tests

```bash
node test/model-test.js
```
