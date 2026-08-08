#!/usr/bin/env bash

# Toggle: if rofi is already running for the user, kill it and exit
if pgrep -u "$USER" -x rofi >/dev/null; then
  pkill -u "$USER" -x rofi
  exit 0
fi

theme="$HOME/.config/rofi/clipboard/style.rasi"
watcher="$HOME/.config/hypr/scripts/clipboard-watch.sh"
favorites_file="$HOME/.cache/cliphist_favorites"

"$watcher"

# Generate wallpaper blur, quad, sqre and thmb caches dynamically for Rofi theme styling
auch_cache="$HOME/.cache/auch"
current_wall="$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null)"
if [[ -f "$current_wall" ]]; then
  mkdir -p "$auch_cache"
  blur_file="$auch_cache/wall.blur"
  quad_file="$auch_cache/wall.quad"
  sqre_file="$auch_cache/wall.sqre"
  thmb_file="$auch_cache/wall.thmb"

  # If cached files do not exist, or the wallpaper has updated, regenerate
  if [[ ! -f "$blur_file" || "$current_wall" -nt "$blur_file" ]]; then
    magick "$current_wall"[0] -strip -scale 10% -blur 0x3 -resize 100% "$blur_file"
  fi
  if [[ ! -f "$quad_file" || "$current_wall" -nt "$quad_file" || ! -f "$sqre_file" || "$current_wall" -nt "$sqre_file" || ! -f "$thmb_file" || "$current_wall" -nt "$thmb_file" ]]; then
    magick "$current_wall"[0] -strip -thumbnail 500x500^ -gravity center -extent 500x500 "$sqre_file"
    magick "$sqre_file" \( -size 500x500 xc:white -fill "rgba(0,0,0,0.7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" \) -alpha Off -compose CopyOpacity -composite "$quad_file"
    magick "$current_wall"[0] -strip -resize 1000x "$thmb_file"
  fi
fi

notify() {
  notify-send -a "Clipboard" -u low -t 1200 "󰅇  Clipboard" "$1"
}

get_rofi_pos() {
  [[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] || return 1
  local curPos
  readarray -t curPos < <(hyprctl cursorpos -j | jq -r '.x,.y')
  local monRes offRes
  eval "$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) |
      "monRes=(\(.width) \(.height) \(.scale) \(.x) \(.y))"')"
  offRes=( $(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .reserved[]') )

  monRes[2]="${monRes[2]//./}"
  monRes[0]=$((monRes[0] * 100 / monRes[2]))
  monRes[1]=$((monRes[1] * 100 / monRes[2]))
  curPos[0]=$((curPos[0] - monRes[3]))
  curPos[1]=$((curPos[1] - monRes[4]))
  local x_pos x_off y_pos y_off
  if [ "${curPos[0]}" -ge "$((monRes[0] / 2))" ]; then
    x_pos="east"
    x_off="-$((monRes[0] - curPos[0] - offRes[2]))"
  else
    x_pos="west"
    x_off="$((curPos[0] - offRes[0]))"
  fi
  if [ "${curPos[1]}" -ge "$((monRes[1] / 2))" ]; then
    y_pos="south"
    y_off="-$((monRes[1] - curPos[1] - offRes[3]))"
  else
    y_pos="north"
    y_off="$((curPos[1] - offRes[1]))"
  fi
  echo "window{location:$x_pos $y_pos;anchor:$x_pos $y_pos;x-offset:${x_off}px;y-offset:${y_off}px;}"
}

run_rofi() {
  local prompt="$1"
  shift

  local rofi_pos
  rofi_pos=$(get_rofi_pos 2>/dev/null || echo "")

  local extra_theme_str=""
  if [[ "$CLIPHIST_IMAGE_HISTORY" == "true" ]]; then
    extra_theme_str="listview { lines: 4; columns: 2; } element { enabled: true; orientation: vertical; spacing: 0%; padding: 2px; cursor: pointer; background-color: transparent; text-color: @foreground; horizontal-align: 0.5; } element-text { enabled: false; } element-icon { size: 100px; spacing: 0%; padding: 0%; cursor: inherit; background-color: transparent; } element selected.normal { background-color: @selected; text-color: @selected-text; } window { width: 450px; }"
  fi

  local final_theme_str=""
  if [[ -n "$rofi_pos" ]]; then
    final_theme_str="$rofi_pos $extra_theme_str"
  else
    final_theme_str="$extra_theme_str"
  fi

  local rofi_cmd=(rofi -dmenu -i -no-custom -p "$prompt" -theme "$theme")
  if [[ -n "$final_theme_str" ]]; then
    rofi_cmd+=(-theme-str "$final_theme_str")
  fi

  if [[ "$CLIPHIST_IMAGE_HISTORY" == "true" ]]; then
    rofi_cmd+=(-show-icons -eh 3)
  fi

  "${rofi_cmd[@]}" \
    -kb-custom-1 "Alt+c" \
    -kb-custom-2 "Alt+d" \
    -kb-custom-3 "Alt+n" \
    -kb-custom-4 "Alt+w" \
    -kb-custom-5 "Alt+o" \
    -kb-custom-6 "Alt+v" \
    -kb-custom-7 "Alt+s" \
    "$@"

  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    case "$exit_code" in
      10) printf ":c:o:p:y:" ;;
      11) printf ":d:e:l:e:t:e:" ;;
      12) printf ":f:a:v:" ;;
      13) printf ":w:i:p:e:" ;;
      14) printf ":o:p:t:" ;;
      15) printf ":i:m:g:" ;;
      16) printf ":o:c:r:" ;;
    esac
  fi
}

handle_special_commands() {
  local selected="$1"
  case "$selected" in
    :c:o:p:y:*) exec "$0" history ;;
    :d:e:l:e:t:e:*) exec "$0" delete ;;
    :f:a:v:*) exec "$0" favorites ;;
    :w:i:p:e:*) exec "$0" wipe ;;
    :o:p:t:*) exec "$0" options ;;
    :i:m:g:*) exec "$0" image-history ;;
    :o:c:r:*) exec "$0" scan ;;
  esac
}

history_empty() {
  ! cliphist list >/dev/null 2>&1 || [[ -z "$(cliphist list 2>/dev/null)" ]]
}

paste_string() {
  if ! command -v wtype >/dev/null; then return 0; fi
  local ignore_paste_file="$HOME/.cache/ignore.paste"
  if [[ ! -e "$ignore_paste_file" ]]; then
    mkdir -p "$(dirname "$ignore_paste_file")"
    cat <<EOF >"$ignore_paste_file"
kitty
org.kde.konsole
terminator
XTerm
Alacritty
xterm-256color
EOF
  fi

  local class
  class=$(hyprctl -j activewindow | jq -r '.initialClass')
  if ! grep -Fxq "$class" "$ignore_paste_file"; then
    sleep 0.15
    hyprctl -q dispatch exec 'wtype -M ctrl V -m ctrl'
  fi
}

copy_item() {
  local item="$1"

  if [[ "$item" == *"[[ binary data"* ]]; then
    printf '%s' "$item" | cliphist decode | wl-copy
    notify "Copied binary item"
    paste_string
  else
    printf '%s' "$item" | cliphist decode | wl-copy
    notify "Copied to clipboard"
    paste_string
  fi
}

show_history() {
  local selected
  local cmd_list
  if [[ "$CLIPHIST_IMAGE_HISTORY" == "true" ]]; then
    cmd_list="$(python3 "$HOME/.config/hypr/scripts/cliphist-image.py")"
  else
    cmd_list="$(
      printf ':favorites:\t📌 Favorites\n'
      printf ':options:\t⚙️ Options\n'
      cliphist list
    )"
  fi

  selected="$(printf '%s\n' "$cmd_list" | run_rofi "History" -selected-row 2)"

  [[ -z "$selected" ]] && exit 0

  handle_special_commands "$selected"

  case "$selected" in
    :favorites:*) view_favorites ;;
    :options:*) show_options ;;
    *)
      copy_item "$selected"
      ;;
  esac
}

delete_items() {
  if history_empty; then
    notify "History is empty."
    return
  fi

  local selected
  selected="$(cliphist list | run_rofi "Delete" -multi-select -display-columns 2)"
  [[ -z "$selected" ]] && return

  handle_special_commands "$selected"

  while IFS= read -r item; do
    [[ -n "$item" ]] && printf '%s' "$item" | cliphist delete
  done <<< "$selected"

  notify "Deleted selected item(s)"
}

ensure_favorites_file() {
  mkdir -p "$(dirname "$favorites_file")"
  touch "$favorites_file"
}

favorite_preview() {
  base64 --decode <<< "$1" | tr '\n' ' '
}

add_favorite() {
  if history_empty; then
    notify "History is empty."
    return
  fi

  ensure_favorites_file

  local item decoded encoded
  item="$(cliphist list | run_rofi "Add Favorite" -display-columns 2)"
  [[ -z "$item" ]] && return

  handle_special_commands "$item"

  decoded="$(printf '%s' "$item" | cliphist decode)"
  encoded="$(printf '%s' "$decoded" | base64 -w 0)"

  if grep -Fxq "$encoded" "$favorites_file"; then
    notify "Already in favorites"
  else
    printf '%s\n' "$encoded" >> "$favorites_file"
    notify "Added to favorites"
  fi
}

view_favorites() {
  ensure_favorites_file

  if [[ ! -s "$favorites_file" ]]; then
    notify "No favorites yet."
    return
  fi

  local previews selected index encoded
  previews="$(while IFS= read -r encoded; do favorite_preview "$encoded"; printf '\n'; done < "$favorites_file")"
  selected="$(printf '%s' "$previews" | run_rofi "Favorites")"
  [[ -z "$selected" ]] && return

  handle_special_commands "$selected"

  index="$(printf '%s' "$previews" | grep -nxF "$selected" | cut -d: -f1 | head -n 1)"
  [[ -z "$index" ]] && return

  encoded="$(sed -n "${index}p" "$favorites_file")"
  base64 --decode <<< "$encoded" | wl-copy
  notify "Copied favorite"
  paste_string
}

delete_favorite() {
  ensure_favorites_file

  if [[ ! -s "$favorites_file" ]]; then
    notify "No favorites to remove."
    return
  fi

  local previews selected index
  previews="$(while IFS= read -r encoded; do favorite_preview "$encoded"; printf '\n'; done < "$favorites_file")"
  selected="$(printf '%s' "$previews" | run_rofi "Remove Favorite")"
  [[ -z "$selected" ]] && return

  handle_special_commands "$selected"

  index="$(printf '%s' "$previews" | grep -nxF "$selected" | cut -d: -f1 | head -n 1)"
  [[ -z "$index" ]] && return

  sed -i "${index}d" "$favorites_file"
  notify "Removed favorite"
}

manage_favorites() {
  local action
  action="$(printf 'Add Favorite\nRemove Favorite\nClear Favorites\n' | run_rofi "Favorites")"

  [[ -z "$action" ]] && return
  handle_special_commands "$action"

  case "$action" in
    "Add Favorite") add_favorite ;;
    "Remove Favorite") delete_favorite ;;
    "Clear Favorites")
      local confirm
      confirm="$(printf 'No\nYes\n' | run_rofi "Clear Favorites?")"
      handle_special_commands "$confirm"
      [[ "$confirm" == "Yes" ]] && : > "$favorites_file" && notify "Favorites cleared"
      ;;
  esac
}

wipe_history() {
  local confirm
  confirm="$(printf 'No\nYes\n' | run_rofi "Clear History?")"
  [[ -z "$confirm" ]] && return
  handle_special_commands "$confirm"
  if [[ "$confirm" == "Yes" ]]; then
    cliphist wipe
    notify "History cleared"
  fi
}

scan_image() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/cliphist"
  mkdir -p "$runtime_dir"
  local image_path="${runtime_dir}/cliphist_ocr.png"

  local index
  index="$(AUCH_CLIPHIST_IMAGE_ONLY=true python3 "$HOME/.config/hypr/scripts/cliphist-image.py" | head -n1 | awk '{print $1}')"

  if [[ -z "$index" ]]; then
    notify "OCR Error: No images in clipboard history"
    return 1
  fi

  cliphist decode "$index" > "$image_path"
  if [[ ! -s "$image_path" ]]; then
    notify "OCR Error: Failed to decode image data"
    return 1
  fi

  notify "Scanning latest image from clipboard..."

  local tesseract_output
  tesseract_output=$(tesseract --psm 6 --oem 3 -l eng "$image_path" stdout 2>/dev/null)

  if [[ -n "$tesseract_output" ]]; then
    printf "%s" "$tesseract_output" | wl-copy
    notify "OCR Success: ${#tesseract_output} symbols recognized"
  else
    notify "OCR Error: No text recognized in image"
  fi
}

show_options() {
  local action
  action="$(printf 'Delete\nManage Favorites\nClear History\nImage History\nOCR Scan Image\n' | run_rofi "Options")"

  [[ -z "$action" ]] && return
  handle_special_commands "$action"

  case "$action" in
    "Delete") delete_items ;;
    "Manage Favorites") manage_favorites ;;
    "Clear History") wipe_history ;;
    "Image History") exec "$0" image-history ;;
    "OCR Scan Image") scan_image ;;
  esac
}

case "$1" in
  delete | -d | --delete) delete_items ;;
  favorites | -f | --favorites) view_favorites ;;
  manage-favorites | -mf | --manage-fav) manage_favorites ;;
  wipe | -w | --wipe) wipe_history ;;
  image-history | -i | --image-history)
    CLIPHIST_IMAGE_HISTORY=true show_history
    ;;
  scan | -s | --scan-image) scan_image ;;
  options | -o | --options) show_options ;;
  "" | history | -c | --copy) show_history ;;
  *)
    printf 'Usage: %s [history|options|image-history|delete|favorites|manage-favorites|wipe|scan]\n' "$0" >&2
    exit 1
    ;;
esac
