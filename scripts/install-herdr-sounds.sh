#!/bin/bash
# Installs herdr's own "done" and "needs input" sounds as macOS system sounds,
# so notifications sound the same as herdr's built-in ones.
#
# The files come from the herdr repository (Apache-2.0):
#   https://github.com/herdrdev/herdr/tree/master/assets/sounds
# They are converted to AIFF in ~/Library/Sounds as HerdrDone and HerdrInput.
set -u
cd "$(dirname "$0")" || exit 1
. ./lib.sh

ref="${1:-master}"
base="https://raw.githubusercontent.com/herdrdev/herdr/$ref/assets/sounds"
sounds_dir="$HOME/Library/Sounds"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$sounds_dir"
for pair in "done:HerdrDone" "request:HerdrInput"; do
  src="${pair%%:*}"; name="${pair##*:}"
  curl -fsSL "$base/$src.mp3" -o "$tmp/$src.mp3" || { echo "Download failed: $base/$src.mp3"; exit 1; }
  afconvert -f AIFF -d BEI16 "$tmp/$src.mp3" "$sounds_dir/$name.aiff" || { echo "Convert failed: $src.mp3"; exit 1; }
  echo "Installed $sounds_dir/$name.aiff"
done

echo
echo "To use them, add these lines to $CONFIG_DIR/config.env:"
echo '  SOUND_BLOCKED="HerdrInput"'
echo '  SOUND_DONE="HerdrDone"'
