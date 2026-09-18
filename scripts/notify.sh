#!/bin/bash
# Handles herdr's pane.agent_status_changed event.
# Posts a clickable notification when an agent needs input (blocked) or
# finished (done). A click opens the Warp tab that runs herdr, then focuses the
# agent pane and its tab.
#
# Usage:
#   notify.sh           called by herdr with HERDR_PLUGIN_EVENT_JSON
#   notify.sh --test    sends a test notification for the current pane
set -u
cd "$(dirname "$0")" || exit 0
. ./lib.sh

notifier="$(find_notifier)" || { log "terminal-notifier not found"; exit 0; }
mkdir -p "$STATE_DIR"

test_mode=0
if [ "${1:-}" = "--test" ]; then
  test_mode=1
  status="blocked"
  pane="${HERDR_PANE_ID:-}"
  if [ -z "$pane" ]; then
    pane="$("$HERDR" agent list 2>/dev/null | jq -r '[.result.agents[] | select(.focused)][0].pane_id // empty')"
  fi
  [ -n "$pane" ] || { echo "No agent pane found to test with."; exit 1; }
else
  event="${HERDR_PLUGIN_EVENT_JSON:-}"
  [ -n "$event" ] || exit 0
  [ "$DEBUG" = "1" ] && printf '%s\n' "$event" > "$STATE_DIR/last-event.json"
  pane="$(jq -r '.data.pane_id // empty' <<<"$event")"
  status="$(jq -r '.data.agent_status // empty' <<<"$event")"
fi
[ -n "$pane" ] || exit 0

group="herdr-$pane"
marker="$STATE_DIR/active-$(printf '%s' "$pane" | tr -c 'A-Za-z0-9_-' '_')"

case " $TRIGGER_STATUSES " in
  *" $status "*) ;;
  *)
    # The agent runs again or you saw it: remove the old notification.
    if [ "$CLEAR_ON_RESUME" = "1" ] && [ -f "$marker" ]; then
      "$notifier" -remove "$group" >/dev/null 2>&1
      rm -f "$marker"
    fi
    exit 0
    ;;
esac

case "$status" in
  blocked) title="$TITLE_BLOCKED"; sound="$SOUND_BLOCKED" ;;
  done)    title="$TITLE_DONE";    sound="$SOUND_DONE" ;;
  *)       title="$status";        sound="$SOUND_DONE" ;;
esac

info="$("$HERDR" agent get "$pane" 2>/dev/null)"
field() { jq -r ".result.agent.$1 // empty" <<<"$info" 2>/dev/null; }
tab="$(field tab_id)"
focused="$(field focused)"
label="$(field terminal_title_stripped)"
cwd="$(field cwd)"
agent="$(field agent)"
[ -n "$agent" ] || agent="agent"
agent="$(printf '%s' "${agent:0:1}" | tr '[:lower:]' '[:upper:]')${agent:1}"

# Skip when you already look at this pane: focused in herdr and Warp is in front.
if [ "$test_mode" = "0" ] && [ "$SUPPRESS_WHEN_FOCUSED" = "1" ] &&
   [ "$focused" = "true" ] && [ "$(frontmost_bundle_id)" = "$WARP_BUNDLE_ID" ]; then
  log "skip $pane $status: already focused"
  exit 0
fi

# WARP_FOCUS_URL (warp://session/<id>) comes from the Warp tab that started the
# herdr server. Opening it brings that exact window and tab to the front.
if [ -n "${WARP_FOCUS_URL:-}" ]; then
  click="open $(printf '%q' "$WARP_FOCUS_URL") || open -b $(printf '%q' "$WARP_BUNDLE_ID")"
else
  click="open -b $(printf '%q' "$WARP_BUNDLE_ID")"
fi
herdr_cmd="HERDR_SOCKET_PATH=$(printf '%q' "${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}") $(printf '%q' "$HERDR")"
click="$click; $herdr_cmd agent focus $(printf '%q' "$pane") >/dev/null"
[ -n "$tab" ] && click="$click; $herdr_cmd tab focus $(printf '%q' "$tab") >/dev/null"

args=(-title "$agent: $title" -message "${label:-$pane}" -group "$group" -execute "$click")
[ -n "$cwd" ] && args+=(-subtitle "${cwd##*/}")
[ -n "$sound" ] && args+=(-sound "$sound")

log "notify $pane $status (tab=$tab focused=$focused)"
"$notifier" "${args[@]}" >/dev/null 2>&1 &
touch "$marker"
exit 0
