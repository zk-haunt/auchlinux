#!/usr/bin/env bash
# Pick a workflow preset via Rofi and apply it live to Hyprland
# Workflows change: gaps, blur, shadows, animations, opacity

WORKFLOW_DIR="$HOME/.config/hypr/workflows"
STATE_FILE="/tmp/hypr-workflow.state"
theme="$HOME/.config/rofi/powermenu/style.rasi"

declare -A DESCRIPTIONS
DESCRIPTIONS["default"]="  Default — balanced gaps, blur, animations"
DESCRIPTIONS["gaming"]="  Gaming — no blur, no gaps, max FPS"
DESCRIPTIONS["powersaver"]="  Powersaver — no animations, no blur, min power"
DESCRIPTIONS["snappy"]="  Snappy — fast animations, lightweight"
DESCRIPTIONS["editing"]="  Editing — wide layout, focused, calm"

CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "default")

# Build menu
MENU=""
for key in default gaming powersaver snappy editing; do
    [[ -f "$WORKFLOW_DIR/$key.conf" ]] && MENU+="${DESCRIPTIONS[$key]}\n"
done

CHOICE=$(printf "$MENU" | rofi -dmenu -i -p "Workflow  [$CURRENT]" -theme "$theme")
[[ -z "$CHOICE" ]] && exit 0

# Extract key from description
KEY=""
for k in default gaming powersaver snappy editing; do
    [[ "${DESCRIPTIONS[$k]}" == "$CHOICE" ]] && KEY="$k" && break
done
[[ -z "$KEY" ]] && exit 1

CONF="$WORKFLOW_DIR/$KEY.conf"
[[ ! -f "$CONF" ]] && exit 1

# Apply using hyprctl source
hyprctl --batch "source $CONF" 2>/dev/null || \
    hyprctl reload 2>/dev/null || true

echo "$KEY" > "$STATE_FILE"
notify-send -i preferences-system "Workflow" "Active: $KEY" -t 2000
