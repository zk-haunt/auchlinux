#!/usr/bin/env bash

export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRIMBLAST="$SCRIPT_DIR/grimblast.sh"

tmp="/tmp/screenshot_$$.png"
save_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$save_dir"
save_file="$save_dir/$(date +'%y%m%d_%Hh%Mm%Ss').png"

need() { command -v "$1" &>/dev/null; }

start_picker() {
    hyprpicker -r -z &
    PICKER_PID=$!
    sleep 0.2
}

stop_picker() {
    kill "$PICKER_PID" 2>/dev/null
}

open_editor_tmp() {
    sleep 0.1
    if need swappy; then
        swappy -f "$tmp"
    elif need satty; then
        satty -f "$tmp"
    fi
}

open_editor_saved() {
    if need swappy; then
        swappy -f "$save_file"
    elif need satty; then
        satty -f "$save_file"
    fi
}

notify_with_editor_btn() {
    action=$(notify-send -a "Screenshot" \
        -i "$save_file" \
        -A "edit=Open Editor" \
        --wait \
        "Screenshot Saved" "$save_file")

    [[ "$action" == "edit" ]] && open_editor_saved
}

notify_simple() {
    notify-send -a "Screenshot" -i "$tmp" "$1" "$2"
}

save_file_only() {
    mv "$tmp" "$save_file"
}

ocr() {
    if need tesseract; then
        tesseract "$tmp" stdout | wl-copy
        notify_simple "OCR Copied" "Text copied to clipboard"
    else
        notify_simple "Error" "Tesseract not installed"
    fi
}

qr() {
    if need zbarimg; then
        zbarimg "$tmp" | wl-copy
        notify_simple "QR Copied" "QR data copied"
    else
        notify_simple "Error" "zbar not installed"
    fi
}

case "$1" in
    # ✂️ AREA SNIP → clipboard + temp file + auto editor
    s)
        "$GRIMBLAST" copysave area "$tmp" && open_editor_tmp
        ;;
    sf)
        start_picker
        "$GRIMBLAST" copysave area "$tmp"
        stop_picker
        open_editor_tmp
        ;;

    # 🖥 FULLSCREEN
    p)
        "$GRIMBLAST" copysave screen "$tmp" && save_file_only
        notify_with_editor_btn
        ;;
    
    # 🪟 WINDOW PICKER → clipboard + temp file + auto editor
    w)
        "$GRIMBLAST" copysave window "$tmp" && open_editor_tmp
        ;;

    # 🔍 OCR
    sc)
        start_picker
        "$GRIMBLAST" copysave area "$tmp" && ocr
        stop_picker
        ;;

    # 🔳 QR
    sq)
        start_picker
        "$GRIMBLAST" copysave area "$tmp" && qr
        stop_picker
        ;;

    *) echo "Usage: screenshot.sh [s|sf|m|p|sc|sq]" ;;
esac

rm -f "$tmp"
