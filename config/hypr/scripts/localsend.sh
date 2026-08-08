#!/usr/bin/env bash
# Launch / focus LocalSend (cross-platform Wi-Fi file sharing).
# Uses port 53317 (TCP+UDP). The nftables ruleset is default-drop inbound, so
# sending out works but RECEIVING needs those ports open — the base
# config/etc/nftables.conf does not open them; config/etc/nftables.virt-localsend.conf does.
# Symptom when blocked: this laptop never shows up in the other device's list.
# The localsend-bin AUR package installs the binary as `localsend_app`
# (older/source builds use `localsend`); handle both.
set -uo pipefail

bin=""
for c in localsend_app localsend; do command -v "$c" &>/dev/null && { bin="$c"; break; }; done
[ -z "$bin" ] && { notify-send -u critical "LocalSend" "Not installed — run install-packages.sh"; exit 1; }

# If a window is already open, focus it instead of spawning a second instance.
if command -v hyprctl &>/dev/null && hyprctl clients -j 2>/dev/null | grep -qi 'localsend'; then
    hyprctl dispatch 'hl.dsp.focus({ class = "^([Ll]ocalsend.*)$" })' >/dev/null 2>&1 \
        || hyprctl dispatch focuswindow "class:(?i)localsend" >/dev/null 2>&1
    exit 0
fi

exec "$bin"
