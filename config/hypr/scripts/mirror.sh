#!/usr/bin/env bash
# Android screen mirroring + control via scrcpy (USB or Wi-Fi), audio included.
# scrcpy 2.0+ forwards audio natively on Android 11+; older phones can use sndcpy.
#
#   mirror.sh                 — mirror over USB (auto-detect device)
#   mirror.sh wifi <ip[:port]>— mirror wirelessly (default port 5555; auto adb tcpip)
#   mirror.sh audio           — forward phone audio only, no screen (sndcpy)
#   mirror.sh stop            — close mirror + drop wireless adb connection
#
# Tips: enable "USB debugging" in Developer options. For Wi-Fi the phone must be
# on the same network; the first wireless connect may need a one-time USB plug-in.
set -uo pipefail

have(){ command -v "$1" &>/dev/null; }
notify(){ notify-send -a "Phone Mirror" "$@"; }

ensure_adb() {
    have adb || { notify -u critical "android-tools (adb) not installed — run install-packages.sh"; exit 1; }
    adb start-server >/dev/null 2>&1
}

# Common scrcpy flags: keep awake, turn the phone screen off while mirroring,
# and stay on top so it behaves like a floating window.
SCRCPY_OPTS=(--stay-awake --turn-screen-off --window-title="Phone")

case "${1:-}" in
    ""|usb)
        have scrcpy || { notify -u critical "scrcpy not installed — run install-packages.sh"; exit 1; }
        ensure_adb
        case "$(adb get-state 2>/dev/null)" in
            device) : ;;
            unauthorized) notify -u critical "Unauthorized — accept the USB-debugging prompt on the phone."; exit 1 ;;
            *) notify -u critical "No phone over USB. Plug in + enable USB debugging."; exit 1 ;;
        esac
        notify "Mirroring over USB"
        exec scrcpy "${SCRCPY_OPTS[@]}"
        ;;
    wifi)
        ip="${2:-}"; [ -z "$ip" ] && { echo "usage: mirror.sh wifi <ip[:port]>"; exit 1; }
        [[ "$ip" == *:* ]] || ip="$ip:5555"
        have scrcpy || { notify -u critical "scrcpy not installed"; exit 1; }
        ensure_adb
        notify "Connecting to $ip…"
        adb connect "$ip" >/dev/null 2>&1
        exec scrcpy --tcpip="$ip" "${SCRCPY_OPTS[@]}"
        ;;
    audio)
        have sndcpy || { notify -u critical "Install 'sndcpy' from the AUR (or use plain mirror for Android 11+ audio)"; exit 1; }
        ensure_adb
        notify "Forwarding phone audio"
        exec sndcpy
        ;;
    stop)
        pkill -x scrcpy 2>/dev/null
        pkill -x sndcpy 2>/dev/null
        have adb && adb disconnect >/dev/null 2>&1
        notify "Stopped"
        ;;
    *)
        echo "usage: mirror.sh [usb] | wifi <ip[:port]> | audio | stop"
        ;;
esac
