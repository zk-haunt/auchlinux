#!/usr/bin/env bash
# Cursor-anchored quick-apps dock (Super+R): a horizontal row of app icons that
# pops up centered on the mouse pointer. Click an icon (or arrow-key + Enter) to
# launch it. Edit the `apps` list below to taste — "Label;icon-name;command".
#
# (Distinct from quick-apps.sh, the centered rofi text menu on Super+Alt+Q.)
set -uo pipefail
theme="$HOME/.config/rofi/launcher/quickdock.rasi"

apps=(
    "Browser;zen-browser;zen-browser"
    "Terminal;kitty;kitty"
    "Files;system-file-manager;dolphin"
    "Code;visual-studio-code;code"
    "Music;spotify;spotify"
    "Chat;discord;discord"
)

# Build rofi rows:  Label<NUL>icon<US><icon-name>
entries=""
for a in "${apps[@]}"; do
    IFS=';' read -r label icon _cmd <<< "$a"
    entries+="${label}\0icon\x1f${icon}\n"
done

cols=${#apps[@]}
# Approx dock width: each tile ≈ icon 46 + padding 20 + spacing 10, plus the
# mainbox padding/border (~30). Keeps the window snug around the icons.
width=$(( cols * 76 + 30 ))

# Cursor position (global compositor coords), then clamp so the dock — centered
# on the cursor — stays fully on the focused monitor.
read -r cx cy < <(hyprctl cursorpos | tr -d ',')
read -r mx my mw mh < <(hyprctl monitors -j \
    | python3 -c 'import json,sys
for m in json.load(sys.stdin):
    if m["focused"]:
        s=m["scale"]
        print(int(m["x"]), int(m["y"]), int(m["width"]/s), int(m["height"]/s)); break' 2>/dev/null)
if [ -n "${mw:-}" ]; then
    half=$(( width / 2 + 12 ))
    (( cx < mx + half ))        && cx=$(( mx + half ))
    (( cx > mx + mw - half ))   && cx=$(( mx + mw - half ))
    (( cy < my + 70 ))          && cy=$(( my + 70 ))
    (( cy > my + mh - 70 ))     && cy=$(( my + mh - 70 ))
fi

sel=$(printf "%b" "$entries" | rofi -dmenu -i -no-custom -show-icons -p "" \
        -theme "$theme" \
        -theme-str "window { width: ${width}px; location: north west; anchor: center; x-offset: ${cx}px; y-offset: ${cy}px; } listview { columns: ${cols}; lines: 1; }")

[ -z "$sel" ] && exit 0
for a in "${apps[@]}"; do
    IFS=';' read -r label _icon cmd <<< "$a"
    [ "$label" = "$sel" ] && { setsid -f $cmd >/dev/null 2>&1; exit 0; }
done
