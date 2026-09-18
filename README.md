# warp-herdr-notifications

Clickable macOS notifications for [herdr](https://herdr.dev) agents running in [Warp](https://www.warp.dev).

When an agent in herdr **needs your input** or **finishes**, you get a native macOS notification. Click it and:

1. Warp comes to the front.
2. The **exact Warp tab** that runs herdr is selected.
3. herdr focuses the **agent pane** (and its tab) that sent the notification.

> **Tested only on macOS + Warp.** See [Tested with](#tested-with) and [Limitations](#limitations).

## Why

herdr's built-in system notifications (`[ui.toast] delivery = "system"`) are sent with `osascript`. macOS shows them as coming from **Script Editor**, and clicking one opens Script Editor instead of your terminal. This plugin sends notifications through [terminal-notifier](https://github.com/julienXX/terminal-notifier) with a click action.

## Requirements

- macOS
- Warp
- herdr 0.9.0 or newer
- [terminal-notifier](https://github.com/julienXX/terminal-notifier) 3.x (the `setup` action installs it with Homebrew)
- `jq` (included with macOS 15 and newer at `/usr/bin/jq`; otherwise `brew install jq`)

## Install

```bash
# 1. Install the plugin
herdr plugin install rubenbelem/warp-herdr-notifications

# 2. Install terminal-notifier and allow its notifications
herdr plugin action invoke warp-herdr-notifications.setup

# 3. Turn off herdr's own notifications and sounds, so you don't get two
#    In ~/.config/herdr/config.toml:
#      [ui.toast]
#      delivery = "off"
#
#      [ui.sound]
#      enabled = false
herdr server reload-config

# 4. Send a test notification
herdr plugin action invoke warp-herdr-notifications.test
```

**Important:** start (or restart) the herdr server from a Warp tab. See [How it works](#how-it-works).

### About the setup step

macOS does not show a permission prompt for apps that live in the Homebrew Cellar, so terminal-notifier fails with `Notifications are not allowed for this application`, and it is not listed in System Settings. The `setup` action:

1. Runs `brew install terminal-notifier` if needed.
2. Copies `terminal-notifier.app` to `~/Applications` and registers it with Launch Services.
3. Asks macOS for notification permission.

If permission is still not granted, open **System Settings → Notifications → terminal-notifier**, turn on **Allow Notifications**, and choose **Banners** or **Alerts**. If terminal-notifier is not in the list, close System Settings and open it again.

The action writes its output to the plugin log (`herdr plugin log list --plugin warp-herdr-notifications`). To see the output directly, run the script from a terminal:

```bash
bash ~/.config/herdr/plugins/github/warp-herdr-notifications-*/scripts/setup.sh
```

## Configuration

All settings are optional. Put them in `config.env` in the plugin config directory:

```bash
cfg="$(herdr plugin config-dir warp-herdr-notifications)"
curl -fsSL https://raw.githubusercontent.com/rubenbelem/warp-herdr-notifications/main/config.example.env -o "$cfg/config.env"
```

| Setting | Default | What it does |
|---|---|---|
| `TRIGGER_STATUSES` | `"blocked done"` | Agent states that send a notification. `blocked` = needs input, `done` = finished. |
| `SOUND_BLOCKED` | `"Ping"` | Sound for "needs input". |
| `SOUND_DONE` | `"Glass"` | Sound for "finished". |
| `TITLE_BLOCKED` | `"Needs your input"` | Title text. The agent name is added in front, e.g. `Claude: Needs your input`. |
| `TITLE_DONE` | `"Finished"` | Title text for finished agents. |
| `SUPPRESS_WHEN_FOCUSED` | `1` | Skip the notification when the pane is focused in herdr **and** Warp is the front app. |
| `CLEAR_ON_RESUME` | `1` | Remove the notification when the agent starts working again or you view it. |
| `WARP_BUNDLE_ID` | `"dev.warp.Warp-Stable"` | Use `"dev.warp.Warp-Preview"` for Warp Preview. |
| `NOTIFIER` | `""` | Full path to the terminal-notifier binary. Empty = find it automatically. |
| `DEBUG` | `0` | `1` writes `debug.log` and `last-event.json` to the plugin state directory. |

The notification shows the agent's terminal title (for example the Claude Code session name) as the message and the working directory name as the subtitle.

### Sounds

A sound value is a macOS sound name: `Basso Blow Bottle Frog Funk Glass Hero Morse Ping Pop Purr Sosumi Submarine Tink`, or the name of any `.aiff`/`.wav` file in `~/Library/Sounds` (without the extension). Use `""` for no sound.

**Only one sound source.** herdr plays its sounds separately from its toasts: `delivery = "off"` does not stop them. Pick one:

- **Plugin sounds (recommended):** set `[ui.sound] enabled = false` in herdr's `config.toml`. The sound then always comes with the notification.
- **herdr's sounds:** keep herdr's sound on and set `SOUND_BLOCKED=""` and `SOUND_DONE=""` here. herdr skips the "finished" sound when you look at that tab; it always plays the "needs input" sound.

**herdr's own sounds with the plugin.** To use herdr's sound files for the plugin's notifications, run:

```bash
herdr plugin action invoke warp-herdr-notifications.install-herdr-sounds
```

This downloads `done.mp3` and `request.mp3` from the [herdr repository](https://github.com/herdrdev/herdr/tree/master/assets/sounds) (Apache-2.0), converts them to AIFF, and saves them as `~/Library/Sounds/HerdrDone.aiff` and `HerdrInput.aiff`. Then set:

```bash
SOUND_BLOCKED="HerdrInput"
SOUND_DONE="HerdrDone"
```

## How it works

- The plugin listens to herdr's `pane.agent_status_changed` event.
- For `blocked` or `done`, it posts a notification with `terminal-notifier -execute "<click command>"`.
- The click command runs:
  ```bash
  open "$WARP_FOCUS_URL"          # Warp + the exact Warp tab
  herdr agent focus <pane_id>     # the agent pane
  herdr tab focus <tab_id>        # makes herdr 0.9.x show that pane
  ```
- Warp sets `WARP_FOCUS_URL` (`warp://session/<id>`) in every shell it starts. Opening that URL brings that exact Warp window and tab to the front. The herdr server inherits it from the Warp tab it was started in, and passes it on to plugins.
- Each pane has one notification group, so a new notification for the same pane replaces the old one.

## Limitations

- **Tested only on macOS with Warp.** It will not work with other terminals as-is: the exact-tab focus depends on Warp's `WARP_FOCUS_URL`. Without it, the plugin falls back to `open -b <WARP_BUNDLE_ID>`, which only brings Warp to the front.
- **One Warp tab for herdr.** The click opens the Warp tab where the **herdr server was started**. If you close that tab and attach to herdr from a new tab, the link points to a tab that no longer exists. Restart the herdr server from the new tab (`herdr server stop`, then `herdr`) to fix it.
- **The focus check cannot see Warp tabs.** It knows Warp is the front app, but not which Warp tab you are on. If you are on another Warp tab and the focused herdr pane finishes, the notification is skipped.
- **Our focus rule is close to herdr's, not the same.** herdr skips its system notification when the agent's tab is active **and** the terminal window has focus (herdr gets focus events from the terminal). A plugin cannot see those focus events, so this plugin checks whether Warp is the front macOS app instead. That is why it cannot tell Warp tabs apart (see above).
- **States come from herdr.** The plugin reacts to what herdr reports. Whether an agent counts as `blocked` or `done` depends on herdr's agent detection.
- **terminal-notifier setup.** The notifier must be allowed in System Settings. A macOS update can reset the permission; run the `setup` action again.
- **Remote machines.** Not tested with `herdr --remote` or SSH machines.

## Tested with

| Component | Version |
|---|---|
| macOS | 27.0 (Apple Silicon) |
| Warp | v0.2026.09.16 (Stable) |
| herdr | 0.9.1 |
| terminal-notifier | 3.1.0 |
| Agent | Claude Code |

## Troubleshooting

- **No notification at all.** Run `~/Applications/terminal-notifier.app/Contents/MacOS/terminal-notifier -diagnose`. It lists what is wrong (permission, Focus mode, alert style).
- **Two notifications, one from Script Editor.** herdr's own toast is still on. Set `[ui.toast] delivery = "off"`.
- **Two sounds at once.** herdr's sound is still on. Set `[ui.sound] enabled = false`, or set the plugin sounds to `""`.
- **Click opens Warp but not the right tab.** Restart the herdr server from the Warp tab you use.
- **Check what the plugin does.** Set `DEBUG=1` in `config.env`, then read `debug.log` in the plugin state directory (`~/.local/state/herdr/plugins/warp-herdr-notifications/`), or run `herdr plugin log list --plugin warp-herdr-notifications`.

## Uninstall

```bash
herdr plugin uninstall warp-herdr-notifications
```

Then set `[ui.toast] delivery` back to `"system"` or `"herdr"`, and `[ui.sound] enabled` back to `true`, if you want herdr's own notifications and sounds.

## Credits

- [herdr](https://github.com/herdrdev/herdr) and its sounds (Apache-2.0)
- [terminal-notifier](https://github.com/julienXX/terminal-notifier)
- Ideas from [herdr-focus-notify](https://github.com/yankewei/herdr-focus-notify) and [herdr-terminal-notifier](https://github.com/dot/herdr-terminal-notifier)

## License

MIT
