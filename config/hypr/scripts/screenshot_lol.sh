#!/usr/bin/env bash
# screenshot_lol.sh — standalone adaptation of lol/HyDE's screenshot.sh.
# Same modes (p / s / sf / m / sc) and feel (grim+slurp capture, swappy/satty
# annotation, clipboard copy, notification), but with the HyDE dependencies
# (hyde-shell, bundled grimblast, send_notifs/pkg_installed/ocr.sh) replaced by
# native tools — because hyde-shell is broken on this machine.
#
#   p   all outputs            s   select area
#   sf  select area (frozen)   m   focused monitor
#   sc  select area → OCR to clipboard (tesseract)
set -uo pipefail

save_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$save_dir"
save_file="$save_dir/$(date +'%y%m%d_%Hh%Mm%Ss')_screenshot.png"
temp="${XDG_RUNTIME_DIR:-/tmp}/screenshot_lol_$$.png"

have()   { command -v "$1" &>/dev/null; }
notify() { notify-send -a "Screenshot" "$@"; }

# Freeze the screen for selection (HyDE uses grimblast --freeze; we don't have
# grimblast, so render a frozen overlay with hyprpicker while slurp runs).
freeze_pid=""
freeze_on()  { have hyprpicker && { hyprpicker -r -z & freeze_pid=$!; sleep 0.2; }; }
freeze_off() { [ -n "$freeze_pid" ] && kill "$freeze_pid" 2>/dev/null; }

focused_monitor() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name'; }

annotate_and_save() {
    # lol/HyDE prefers SATTY when both are installed — match that so this script
    # opens satty (ours/poc uses swappy, letting you compare the two editors).
    if have satty; then
        satty -f "$temp" -o "$save_file" --copy-command wl-copy
    elif have swappy; then
        mkdir -p "$HOME/.config/swappy"
        printf '[Default]\nsave_dir=%s\nsave_filename_format=%s\n' \
            "$save_dir" "$(basename "$save_file")" > "$HOME/.config/swappy/config"
        swappy -f "$temp" -o "$save_file"
    else
        cp "$temp" "$save_file"
    fi
}

# Area selection that ALSO snaps to windows: pipe the geometry of every visible
# window to slurp (without -r, so a click snaps to a window box while a drag
# still makes a custom area) — the grimblast "click a window to grab it" feel.
select_region() {
    local vis
    vis=$(hyprctl monitors -j 2>/dev/null | jq '[.[].activeWorkspace.id]')
    hyprctl clients -j 2>/dev/null | jq -r --argjson vis "$vis" \
        '.[] | select(.hidden==false and .mapped==true and ((.workspace.id) as $w | $vis | index($w))) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
        | slurp -d \
            -b "1e1e2e66" \
            -c "a6bbdaff" \
            -s "a6bbda33" \
            -B "89b4fa22"
}

# slurp dims the whole screen while selecting (-b 1e1e2e66) and hyprpicker
# paints a frozen copy over it. Both are gone the instant they exit, but the
# compositor still has to repaint — call grim too early and that grey wash (or
# the freeze layer) ends up baked into the capture. Wait for one repaint first.
settle() { sleep 0.15; }

case "${1:-}" in
    p)  grim "$temp" ;;
    m)  mon=$(focused_monitor); [ -n "$mon" ] && grim -o "$mon" "$temp" || grim "$temp" ;;
    s)  geom=$(select_region) || exit 0; [ -z "$geom" ] && exit 0; settle; grim -g "$geom" "$temp" ;;
    sf) freeze_on; geom=$(select_region); freeze_off; [ -z "$geom" ] && exit 0; settle; grim -g "$geom" "$temp" ;;
    sc) freeze_on; geom=$(select_region); freeze_off; [ -z "$geom" ] && exit 0
        settle
        grim -g "$geom" "$temp"
        text=$(tesseract "$temp" - 2>/dev/null)
        printf '%s' "$text" | wl-copy
        notify -i document-scan "OCR text copied to clipboard"
        rm -f "$temp"; exit 0 ;;
    *)  echo "usage: $(basename "$0") p|s|sf|m|sc"; exit 1 ;;
esac

[ -f "$temp" ] || { notify -u critical "Screenshot failed"; exit 1; }
wl-copy < "$temp"               # copy raw capture to clipboard
annotate_and_save               # annotate + save to ~/Pictures/Screenshots
[ -f "$save_file" ] && notify -i "$save_file" "Saved to $save_dir"
rm -f "$temp"
