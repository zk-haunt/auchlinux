#!/usr/bin/env python3
# Native Spotify status for waybar (custom/spotify module) — no hyde-shell,
# just playerctl. Emits the now-playing line + tooltip + a status class.
import json
import subprocess
import sys

PLAYER = "spotify"
SPOTIFY = ""   # nf spotify glyph


def pctl(*args):
    try:
        r = subprocess.run(
            ["playerctl", f"--player={PLAYER}", *args],
            capture_output=True, text=True, timeout=2,
        )
        return r.stdout.strip()
    except Exception:
        return ""


status = pctl("status")
if not status:
    print(json.dumps({"text": "", "tooltip": "Spotify not running", "class": "stopped"}))
    sys.exit(0)

title = pctl("metadata", "title")
artist = pctl("metadata", "artist")
album = pctl("metadata", "album")

label = f"{title} — {artist}" if title and artist else (title or "Spotify")
if len(label) > 38:
    label = label[:37].rstrip() + "…"

text = f"{SPOTIFY}  {label}"
tooltip = "\n".join(filter(None, [
    title and f"  {title}",
    artist and f"  {artist}",
    album and f"  {album}",
    "",
    "/ click: play/pause    scroll: next/prev",
]))
print(json.dumps({"text": text, "tooltip": tooltip, "class": status.lower()}))
