#!/bin/bash
# Shared helpers. Compatible with the bash 3.2 that ships with macOS.

PLUGIN_ID="warp-herdr-notifications"
HERDR="${HERDR_BIN_PATH:-$(command -v herdr || echo "$HOME/.local/bin/herdr")}"

# Defaults. Override any of them in "$CONFIG_DIR/config.env".
TRIGGER_STATUSES="blocked done"
SOUND_BLOCKED="Ping"
SOUND_DONE="Glass"
TITLE_BLOCKED="Needs your input"
TITLE_DONE="Finished"
SUPPRESS_WHEN_FOCUSED=1
CLEAR_ON_RESUME=1
WARP_BUNDLE_ID="dev.warp.Warp-Stable"
NOTIFIER=""
DEBUG=0

CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-}"
if [ -z "$CONFIG_DIR" ] && [ -x "$HERDR" ]; then
  CONFIG_DIR="$("$HERDR" plugin config-dir "$PLUGIN_ID" 2>/dev/null | tail -1)"
fi
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.local/state/herdr/plugins/$PLUGIN_ID}"

# shellcheck disable=SC1091
[ -n "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/config.env" ] && . "$CONFIG_DIR/config.env"

# terminal-notifier must run from an app bundle that macOS knows, or macOS
# refuses notifications without asking. setup.sh copies it to ~/Applications.
find_notifier() {
  local c
  for c in "$NOTIFIER" \
    "$HOME/Applications/terminal-notifier.app/Contents/MacOS/terminal-notifier" \
    "/Applications/terminal-notifier.app/Contents/MacOS/terminal-notifier" \
    "$(command -v terminal-notifier 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

frontmost_bundle_id() {
  lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null |
    grep -oE '="[^"]+"' | head -1 | tr -d '="'
}

log() {
  [ "$DEBUG" = "1" ] || return 0
  mkdir -p "$STATE_DIR" && printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$STATE_DIR/debug.log"
}
