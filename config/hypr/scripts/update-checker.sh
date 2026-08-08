#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  update-checker.sh  —  pending pacman/AUR/flatpak updates for Waybar
#  --status : print the JSON payload for the custom/updates module
#  (no args): open a terminal and run the full system upgrade
#  Behaviour ported from lol's HyDE `system.update.sh` — click opens
#  kitty and runs the real upgrade (no rofi picker), just done directly
#  instead of via hyde-shell.
# ─────────────────────────────────────────────────────────────

AUR_HELPER=""
for helper in paru yay; do
    command -v "$helper" &>/dev/null && AUR_HELPER="$helper" && break
done

OFFICIAL_COUNT=$(checkupdates 2>/dev/null | grep -c '\S')
AUR_COUNT=0
[[ -n "$AUR_HELPER" ]] && AUR_COUNT=$("$AUR_HELPER" -Qua 2>/dev/null | grep -c '\S')
FLATPAK_COUNT=0
command -v flatpak &>/dev/null && FLATPAK_COUNT=$(flatpak remote-ls --updates 2>/dev/null | grep -c '\S')

COUNT=$((OFFICIAL_COUNT + AUR_COUNT + FLATPAK_COUNT))

# Called with --status: print JSON for Waybar
if [[ "$1" == "--status" ]]; then
    if [[ "$COUNT" -eq 0 ]]; then
        echo '{"text":"","tooltip":" Packages are up to date","class":"up-to-date"}'
    else
        tooltip="󱓽 Official $OFFICIAL_COUNT\n󱓾 AUR $AUR_COUNT"
        [[ "$FLATPAK_COUNT" -gt 0 ]] && tooltip+="\n󰏓 Flatpak $FLATPAK_COUNT"
        echo "{\"text\":\"󰮯 $COUNT\",\"tooltip\":\"$tooltip\",\"class\":\"has-updates\"}"
    fi
    exit 0
fi

# Called without args (waybar on-click): open a terminal and run the full
# system upgrade — official + AUR via the AUR helper's -Syu, then flatpak,
# exactly like lol's system.update.sh "up" path. No rofi picker.
if [[ "$COUNT" -eq 0 ]]; then
    notify-send "System up to date" "No pending updates found." -i system-software-update
    exit 0
fi

# Build the upgrade command that runs inside the terminal.
upgrade_cmd="printf '\\n  Official %s   AUR %s   Flatpak %s\\n\\n' '$OFFICIAL_COUNT' '$AUR_COUNT' '$FLATPAK_COUNT'; "
if [[ -n "$AUR_HELPER" ]]; then
    # paru/yay -Syu upgrades official repos AND the AUR in one pass.
    upgrade_cmd+="$AUR_HELPER -Syu; "
else
    upgrade_cmd+="sudo pacman -Syu; "
fi
if command -v flatpak &>/dev/null && [[ "$FLATPAK_COUNT" -gt 0 ]]; then
    upgrade_cmd+="flatpak update; "
fi
upgrade_cmd+="printf '\\n  Upgrade finished. Press any key to close...'; read -n 1"

kitty --title systemupdate sh -c "$upgrade_cmd"
