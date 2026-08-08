#!/usr/bin/env bash
# Use your phone as a high-quality wireless webcam, piped into the v4l2loopback
# virtual device so any app (browser / OBS / Zoom / Discord) sees "Phone Camera".
#
# Method A — IP Webcam  (Android app, recommended; no extra Linux client):
#   1. Install "IP Webcam" on the phone → open it → "Start server".
#      It shows a URL such as  http://192.168.1.42:8080
#   2. phone-camera.sh start 192.168.1.42:8080     (port optional, default 8080)
#   3. phone-camera.sh stop
#
# Method B — DroidCam  (needs the `droidcam` AUR client + the DroidCam phone app):
#   phone-camera.sh droidcam <phone-ip> [port]      (default port 4747)
#
# Method C — USB cable  (scrcpy, no phone app needed; Android 12+ for camera):
#   1. Plug the phone in via USB, enable "USB debugging" (Developer options).
#   2. phone-camera.sh usb [front|back]             (default front / selfie cam)
#   scrcpy streams the phone's camera into the virtual device and shows a small
#   preview window — close it (or `stop`) to end the stream.
#
# Method D — IP Webcam over USB  (no Wi-Fi needed; works on any Android):
#   Runs the IP Webcam app but tunnels it through the USB cable via adb.
#   phone-camera.sh usb-ipwebcam [port]             (default port 8080)
#
# The virtual device is /dev/video10 by default (set up by install-packages.sh /
# /etc/modprobe.d/v4l2loopback.conf). Override with PHONECAM_DEV.
set -uo pipefail
LOOPDEV="${PHONECAM_DEV:-/dev/video10}"
LABEL="Phone Camera"

have(){ command -v "$1" &>/dev/null; }
notify(){ notify-send -a "Phone Camera" "$@"; }

# Make sure a phone is reachable over USB via adb (debugging authorized).
ensure_adb() {
    have adb || { notify -u critical "android-tools (adb) not installed — run install-packages.sh"; exit 1; }
    adb start-server >/dev/null 2>&1
    case "$(adb get-state 2>/dev/null)" in
        device) : ;;
        unauthorized) notify -u critical "Phone connected but unauthorized — accept the USB-debugging prompt on the phone."; exit 1 ;;
        *) notify -u critical "No phone over USB. Plug in the cable + enable USB debugging."; exit 1 ;;
    esac
}

# Ensure the v4l2loopback virtual device exists (it normally autoloads at boot).
ensure_loopback() {
    [ -e "$LOOPDEV" ] && return 0
    have modprobe || { notify -u critical "v4l2loopback not installed — run install-packages.sh"; exit 1; }
    sudo modprobe v4l2loopback devices=1 video_nr="${LOOPDEV##*video}" \
        card_label="$LABEL" exclusive_caps=1 2>/dev/null \
        || { notify -u critical "Could not load v4l2loopback (run install-packages.sh)"; exit 1; }
}

case "${1:-}" in
    start)
        ip="${2:-}"; [ -z "$ip" ] && { echo "usage: phone-camera.sh start <phone-ip[:port]>"; exit 1; }
        [[ "$ip" == *:* ]] || ip="$ip:8080"
        have ffmpeg || { notify -u critical "ffmpeg not installed"; exit 1; }
        ensure_loopback
        notify "Streaming $ip → $LOOPDEV"
        # IP Webcam exposes an MJPEG stream at /video; transcode to a webcam-friendly format.
        exec ffmpeg -hide_banner -loglevel warning -nostdin \
            -i "http://$ip/video" -vf "format=yuv420p" -f v4l2 "$LOOPDEV"
        ;;
    droidcam)
        ip="${2:-}"; port="${3:-4747}"
        [ -z "$ip" ] && { echo "usage: phone-camera.sh droidcam <phone-ip> [port]"; exit 1; }
        have droidcam-cli || { notify -u critical "Install 'droidcam' from the AUR"; exit 1; }
        ensure_loopback
        notify "DroidCam $ip:$port → $LOOPDEV"
        exec droidcam-cli "$ip" "$port"
        ;;
    usb)
        facing="${2:-front}"
        have scrcpy || { notify -u critical "scrcpy not installed — run install-packages.sh"; exit 1; }
        ensure_adb
        ensure_loopback
        notify "USB camera ($facing) → $LOOPDEV"
        # scrcpy feeds the phone camera straight into the v4l2loopback sink (Android 12+).
        exec scrcpy --video-source=camera --camera-facing="$facing" \
                    --camera-size=1280x720 --no-audio --v4l2-sink="$LOOPDEV"
        ;;
    usb-ipwebcam)
        port="${2:-8080}"
        have ffmpeg || { notify -u critical "ffmpeg not installed"; exit 1; }
        ensure_adb
        ensure_loopback
        # Tunnel the phone's IP Webcam port over USB so we can read it on localhost.
        adb forward "tcp:$port" "tcp:$port" >/dev/null \
            || { notify -u critical "adb port-forward failed"; exit 1; }
        notify "IP Webcam over USB (localhost:$port) → $LOOPDEV"
        exec ffmpeg -hide_banner -loglevel warning -nostdin \
            -i "http://localhost:$port/video" -vf "format=yuv420p" -f v4l2 "$LOOPDEV"
        ;;
    stop)
        pkill -f "ffmpeg.*$LOOPDEV" 2>/dev/null
        pkill -f "scrcpy.*v4l2-sink=$LOOPDEV" 2>/dev/null
        pkill -x droidcam-cli 2>/dev/null
        have adb && adb forward --remove-all >/dev/null 2>&1
        notify "Stopped"
        ;;
    status)
        if [ -e "$LOOPDEV" ]; then echo "virtual device: $LOOPDEV (ready)"; else echo "virtual device: NOT loaded"; fi
        { pgrep -f "ffmpeg.*$LOOPDEV" >/dev/null || pgrep -f "scrcpy.*v4l2-sink=$LOOPDEV" >/dev/null; } \
            && echo "streaming: yes" || echo "streaming: no"
        ;;
    *)
        echo "usage: phone-camera.sh start <ip[:port]> | usb [front|back] | usb-ipwebcam [port] | droidcam <ip> [port] | stop | status"
        ;;
esac
