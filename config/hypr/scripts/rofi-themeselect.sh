#!/usr/bin/env bash
# Unified visual rofi STYLE picker (Super+Shift+D). Shows every launcher style
# as a grid tile — a real screenshot preview for the lol-derived styles, an
# auto-generated text tile for our own — and applies the choice to the launcher
# using the SAME state the cmdline cycler (rofi-theme.lua) uses, so the visual
# picker and `rofi-theme` stay in sync. Adapted from HyDE's rofiselect.sh; no
# hyde-shell. Tiles live in launcher/previews/<name>.png.
launcherDir="$HOME/.config/rofi/launcher"
previewDir="$launcherDir/previews"
theme="$launcherDir/themeselect.rasi"   # mirrors the wallpaper picker grid
modeFile="$launcherDir/rofi_theme_mode"

sel=$(for f in "$launcherDir"/style_*.rasi; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .rasi); name="${name#style_}"
        img="$previewDir/$name.png"
        if [ -f "$img" ]; then
            printf '%s\x00icon\x1f%s\n' "$name" "$img"
        else
            printf '%s\n' "$name"
        fi
      done | sort -V | rofi -dmenu -i -no-custom -show-icons -p "Style" -theme "$theme")

[ -z "$sel" ] && exit 0
[ -f "$launcherDir/style_$sel.rasi" ] || exit 1

# Apply: same as rofi-theme.lua → write mode + symlink style.rasi + notify.
echo "$sel" > "$modeFile"
ln -sf "$launcherDir/style_$sel.rasi" "$launcherDir/style.rasi"
notify-send -a "Rofi Theme" -i "$previewDir/$sel.png" "Active theme: $sel"

# Live preview: open the launcher in the chosen style so you see it right away.
rofi -show drun -theme "$launcherDir/style_$sel.rasi"
