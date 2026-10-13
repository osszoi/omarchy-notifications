#!/bin/bash
# Back to stock omarchy.notifications. History and DND state are shared, so
# nothing is lost (stock trims history back to its 10 entries on next archive).

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_ID=eduardo.notifications
PLUGIN_DIR=$HOME/.config/omarchy/plugins/$PLUGIN_ID

omarchy plugin disable "$PLUGIN_ID" || true
"$REPO_DIR/bin/eduardo-notifications-hypr" remove >/dev/null || true
[[ -L $PLUGIN_DIR ]] && rm "$PLUGIN_DIR"
echo "omarchy.notifications is back. Settings stay in ~/.config/omarchy/notifications.json"
