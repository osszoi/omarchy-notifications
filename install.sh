#!/bin/bash
# Symlink the plugin into omarchy, swap it in for omarchy.notifications, put the
# bell next to the power button and bind the center shortcut.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_ID=eduardo.notifications
PLUGIN_DIR=$HOME/.config/omarchy/plugins/$PLUGIN_ID

say() { printf '\033[1;32m==>\033[0m %s\n' "$1"; }

if [[ -e $PLUGIN_DIR && ! -L $PLUGIN_DIR ]]; then
  backup=$HOME/.local/share/omarchy-notifications-old-clone-$(date +%Y%m%d%H%M%S)
  say "Moving the old $PLUGIN_ID clone to $backup"
  mv "$PLUGIN_DIR" "$backup"
fi

say "Linking $PLUGIN_DIR -> $REPO_DIR"
mkdir -p "$(dirname "$PLUGIN_DIR")"
ln -sfn "$REPO_DIR" "$PLUGIN_DIR"

say "Enabling $PLUGIN_ID (omarchy.notifications gets disabled while it's on)"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable "$PLUGIN_ID" --before omarchy.power || omarchy plugin enable "$PLUGIN_ID"

say "Binding the notification center to SUPER + N"
"$REPO_DIR/bin/eduardo-notifications-hypr" apply --shortcut "SUPER + N" --blur 1

say "Done. Rollback: omarchy plugin disable $PLUGIN_ID"
