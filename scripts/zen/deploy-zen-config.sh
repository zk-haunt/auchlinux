#!/usr/bin/env bash
# Deploys userChrome/userContent/user.js into the active Zen Browser profile.
# Source assets live alongside this script in userconfig/. Extensions are
# installed manually via about:addons.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR"
ZEN_DIR="$HOME/.config/zen"

[[ -d "$ZEN_DIR" ]] || { echo "No Zen profile directory at $ZEN_DIR — is Zen installed?"; exit 1; }

# Resolve the profile actually used at launch: installs.ini (per-install default)
# takes priority over profiles.ini's Default=1 flag.
profile_name=""
if [[ -f "$ZEN_DIR/installs.ini" ]]; then
    profile_name="$(grep -m1 '^Default=' "$ZEN_DIR/installs.ini" | cut -d= -f2-)"
fi
if [[ -z "$profile_name" && -f "$ZEN_DIR/profiles.ini" ]]; then
    profile_name="$(awk -F= '/^Default=1/{found=1} found && /^Path=/{print substr($0,6); exit}' "$ZEN_DIR/profiles.ini")"
fi
[[ -n "$profile_name" ]] || { echo "Could not resolve active Zen profile from installs.ini/profiles.ini"; exit 1; }

PROFILE="$ZEN_DIR/$profile_name"
[[ -d "$PROFILE" ]] || { echo "Resolved profile dir does not exist: $PROFILE"; exit 1; }

echo "[zen-deploy] Target profile: $PROFILE"

# Backup anything we're about to touch
BKP="$HOME/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')_zen"
mkdir -p "$BKP"
[[ -d "$PROFILE/chrome" ]] && cp -r "$PROFILE/chrome" "$BKP/" && echo "[zen-deploy] Backed up existing chrome/ -> $BKP"
[[ -f "$PROFILE/user.js" ]] && cp "$PROFILE/user.js" "$BKP/" && echo "[zen-deploy] Backed up existing user.js -> $BKP"

echo "[zen-deploy] Installing chrome/ and user.js..."
mkdir -p "$PROFILE/chrome"
cp "$SRC/userconfig/chrome/userChrome.css" "$SRC/userconfig/chrome/userContent.css" "$PROFILE/chrome/"
cp "$SRC/userconfig/user.js" "$PROFILE/user.js"

echo "[zen-deploy] Done."
echo "[zen-deploy] Extensions are not managed here — install them yourself from about:addons."
echo "[zen-deploy] Restart Zen Browser to apply userChrome.css."
