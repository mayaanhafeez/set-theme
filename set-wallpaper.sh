#!/usr/bin/env bash

current_theme=$(cat ~/set-theme/current_theme)

if [[ "$#" > 1 ]]; then
  echo 'too many args'
  exit 1
fi

if [[ "$#" == "0" ]]; then
  var=$(find ~/Pictures/wallpapers/$current_theme -type f | fzf)
  if [[ -z "$var" ]]; then
    echo "No wallpaper selected"
    exit 1
  fi
else
  var=$1
fi

if [[ ! -f "$var" ]]; then
  echo "Not a file: $var"
  exit 1
fi

# Repaint the displays attached right now. This has to run before we touch the
# index below: WallpaperAgent rewrites the file from memory when it is asked to
# change a picture.
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$var\" as POSIX file"

# `tell every desktop` only reaches the displays and spaces that exist right now.
# macOS keeps a per-display / per-space wallpaper index, so a monitor that is
# unplugged when we run keeps its old picture and restores it on reconnect.
# Write the choice into AllSpacesAndDisplays (and SystemDefault, used by any
# display macOS has never seen), then drop the per-display / per-space entries
# so nothing is left to override it.
index=~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist

python3 - "$var" "$index" <<'PY'
import datetime, os, plistlib, sys, urllib.parse

picture, index = sys.argv[1], sys.argv[2]
url = 'file://' + urllib.parse.quote(os.path.realpath(picture))
now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

entry = {
    'Content': {
        'Choices': [{
            'Provider': 'com.apple.wallpaper.choice.image',
            'Files': [],
            'Configuration': plistlib.dumps(
                {'type': 'imageFile', 'url': {'relative': url}},
                fmt=plistlib.FMT_BINARY,
            ),
        }],
        'Shuffle': '$null',
        'EncodedOptionValues': '$null',
    },
    'LastSet': now,
    'LastUse': now,
}

try:
    with open(index, 'rb') as f:
        store = plistlib.load(f)
except FileNotFoundError:
    store = {}

for key in ('AllSpacesAndDisplays', 'SystemDefault'):
    scope = store.setdefault(key, {})
    scope['Desktop'] = entry
    scope.setdefault('Idle', entry)   # leave the screen saver picture alone
    scope['Type'] = 'individual'

store['Displays'] = {}
store['Spaces'] = {}

tmp = index + '.new'
with open(tmp, 'wb') as f:
    plistlib.dump(store, f, fmt=plistlib.FMT_BINARY)
os.replace(tmp, index)
PY

# WallpaperAgent caches the index in memory; it relaunches on demand and
# re-reads what we just wrote.
killall WallpaperAgent 2>/dev/null
