#!/usr/bin/env bash

current_theme=$(cat ~/set-theme/current_theme)

if [[ "$#" > 1 ]]; then
  echo 'too many args'
else
  var=0
  if [[ "$#" == "0" ]]; then
    var=$(find ~/Pictures/wallpapers/$current_theme | fzf)
  else
    var=$1
  fi
  if [ $? -eq 130 ]; then
    echo "No wallpaper selected"
  else
    osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$var\" as POSIX file"
  fi
fi

