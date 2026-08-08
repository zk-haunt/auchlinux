#!/usr/bin/env bash

# EasyEffects setup — system-wide audio effects for PipeWire (EQ, bass, etc).
# Optional: nothing else in the repo depends on it. Run it when you want it.
#
# Usage:
#   ./easyeffects.sh            # install packages + copy presets
#   ./easyeffects.sh presets    # copy presets only (no package install)
#
# After it runs: launch `easyeffects`, click Presets (bottom-left), pick one
# under Output, and Load. The autostart entry in autostart.lua then starts it
# as a background service on login — it's a no-op until this script installs it.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user (it uses sudo where needed)." >&2
    exit 1
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)/presets"

# EasyEffects 8 reads presets from here. 7.x used ~/.config/easyeffects/ and
# also keeps its live settings under ~/.config/easyeffects/db/ now — never
# rsync over that directory or you wipe the running configuration.
DEST_DIR="$HOME/.local/share/easyeffects/output"

# EasyEffects ships no DSP of its own: every effect is an LV2 plugin from a
# separate package, and a preset silently drops any effect whose provider is
# missing (no error, the effect just doesn't appear). These cover what the
# bundled presets use.
PKGS=(
    easyeffects
    lsp-plugins-lv2        # equalizer, compressor, delay, loudness
    calf                   # limiter, exciter, bass enhancer
    zam-plugins-lv2        # maximizer
)

install_presets() {
    mkdir -p "$DEST_DIR"
    local n=0
    for f in "$SRC_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        cp -f "$f" "$DEST_DIR/"
        echo "  + $(basename "${f%.json}")"
        n=$((n + 1))
    done
    if (( n == 0 )); then
        echo "No presets found in $SRC_DIR."
    else
        echo "$n preset(s) installed to $DEST_DIR"
    fi
}

case "${1:-all}" in
    presets)
        echo "Installing EasyEffects presets..."
        install_presets
        ;;
    all)
        echo "[1/2] Installing EasyEffects + LV2 plugin providers..."
        sudo pacman -S --needed --noconfirm "${PKGS[@]}"

        echo
        echo "[2/2] Installing presets..."
        install_presets

        echo
        echo "Done. Launch 'easyeffects', then Presets (bottom-left) -> Load."
        echo "Effects apply to all audio; the power toggle (top-left) bypasses"
        echo "the whole chain so you can A/B it while something is playing."
        ;;
    *)
        sed -n '3,12p' "$0"
        exit 1
        ;;
esac
