#!/usr/bin/env bash
# Pick an animation preset via Rofi and apply it live to Hyprland

ANIM_DIR="$HOME/.config/hypr/animations"
STATE_FILE="$HOME/.config/hypr/animations/.current"
theme="$HOME/.config/rofi/powermenu/style.rasi"

# List available presets (strip .conf extension)
PRESETS=$(ls "$ANIM_DIR"/*.conf 2>/dev/null | xargs -I{} basename {} .conf | sort)

# Show current
CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "default")

CHOICE=$(echo "$PRESETS" | rofi -dmenu -i -p "Animation  [$CURRENT]" -theme "$theme")
[[ -z "$CHOICE" ]] && exit 0

CONF="$ANIM_DIR/$CHOICE.conf"
[[ ! -f "$CONF" ]] && exit 1

# Apply: source the conf into hyprctl
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    # Only pass animation/bezier lines
    if [[ "$line" =~ ^[[:space:]]*(animation|bezier)[[:space:]]*= ]]; then
        hyprctl keyword "$line" 2>/dev/null || true
    fi
done < "$CONF"

echo "$CHOICE" > "$STATE_FILE"
notify-send -i preferences-desktop "Animation" "Preset: $CHOICE" -t 2000
