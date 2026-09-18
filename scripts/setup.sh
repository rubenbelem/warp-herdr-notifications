#!/bin/bash
# One-time setup for terminal-notifier on macOS.
#
# terminal-notifier from Homebrew lives in the Homebrew Cellar. macOS does not
# list apps from there in System Settings > Notifications and refuses them
# without asking. This script copies the app to ~/Applications, registers it
# with Launch Services, and asks macOS for notification permission.
set -u
cd "$(dirname "$0")" || exit 1
. ./lib.sh

[ "$(uname)" = "Darwin" ] || { echo "This plugin supports macOS only."; exit 1; }

target="$HOME/Applications/terminal-notifier.app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

source_app=""
if command -v brew >/dev/null 2>&1; then
  if ! brew list terminal-notifier >/dev/null 2>&1; then
    echo "Installing terminal-notifier with Homebrew..."
    brew install terminal-notifier || { echo "brew install terminal-notifier failed."; exit 1; }
  fi
  source_app="$(brew --prefix terminal-notifier)/terminal-notifier.app"
fi

if [ -n "$source_app" ] && [ -d "$source_app" ]; then
  src_version="$(defaults read "$source_app/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
  dst_version="$(defaults read "$target/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
  if [ "$src_version" != "$dst_version" ]; then
    echo "Copying terminal-notifier $src_version to $target"
    mkdir -p "$HOME/Applications"
    rm -rf "$target"
    cp -R "$source_app" "$target" || { echo "Copy failed."; exit 1; }
  fi
elif [ ! -d "$target" ] && [ ! -d "/Applications/terminal-notifier.app" ]; then
  echo "terminal-notifier not found. Install Homebrew and run: brew install terminal-notifier"
  exit 1
fi

[ -d "$target" ] && "$lsregister" -f "$target"

notifier="$(find_notifier)" || { echo "terminal-notifier not found."; exit 1; }
echo "Using: $notifier"

auth="$("$notifier" -diagnose 2>&1 | awk '/authorization/ {print $2}')"
if [ "$auth" != "authorized" ]; then
  echo "Asking macOS for notification permission..."
  app="${notifier%/Contents/MacOS/*}"
  open -a "$app" --args -title "Warp Herdr Notifications" -message "Allow notifications to finish setup" >/dev/null 2>&1
  sleep 3
  auth="$("$notifier" -diagnose 2>&1 | awk '/authorization/ {print $2}')"
fi

if [ "$auth" = "authorized" ]; then
  echo "Done. Notifications are allowed."
  echo "Send a test: herdr plugin action invoke $PLUGIN_ID.test"
else
  echo
  echo "Permission status: ${auth:-unknown}"
  echo "Open System Settings > Notifications > terminal-notifier and turn on Allow Notifications."
  echo "If terminal-notifier is not in the list, close System Settings and open it again."
  open "x-apple.systempreferences:com.apple.Notifications-Settings.extension" >/dev/null 2>&1
  exit 2
fi
