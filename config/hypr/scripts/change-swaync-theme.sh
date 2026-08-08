#!/usr/bin/env bash

# Pick a SwayNC theme via Rofi and apply it live
SWAYNC_DIR="$HOME/.config/swaync"
theme="$HOME/.config/rofi/powermenu/style.rasi"

# Get list of themes
THEMES=$(find "$SWAYNC_DIR/themes" -name "style_*.css" 2>/dev/null | sed -E 's/.*style_(.*)\.css/\1/' | sort)

if [[ -z "$THEMES" ]]; then
    THEMES=$(find "$HOME/auchlinux/config/swaync/themes" -name "style_*.css" 2>/dev/null | sed -E 's/.*style_(.*)\.css/\1/' | sort)
fi

# Get current theme
CURRENT=$(cat "$SWAYNC_DIR/.current_theme" 2>/dev/null || echo "default")

CHOICE=$(echo "$THEMES" | rofi -dmenu -i -p "SwayNC Theme [$CURRENT]" -theme "$theme")
[[ -z "$CHOICE" ]] && exit 0

# Copy selected theme
SRC_CSS="$HOME/auchlinux/config/swaync/themes/style_$CHOICE.css"
if [[ ! -f "$SRC_CSS" ]]; then
    SRC_CSS="$SWAYNC_DIR/themes/style_$CHOICE.css"
fi

[[ -f "$SRC_CSS" ]] || exit 1

# Copy to repo and ~/.config
cp -f "$SRC_CSS" "$HOME/auchlinux/config/swaync/style.css" 2>/dev/null || true
cp -f "$SRC_CSS" "$SWAYNC_DIR/style.css"

echo "$CHOICE" > "$SWAYNC_DIR/.current_theme"
echo "$CHOICE" > "$HOME/auchlinux/config/swaync/.current_theme" 2>/dev/null || true

# Reload SwayNC CSS instantly
swaync-client -rs

notify-send -i dialog-information "SwayNC" "Theme changed to $CHOICE"
