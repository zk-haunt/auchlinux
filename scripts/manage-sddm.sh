#!/usr/bin/env bash

set -euo pipefail

LOG="$HOME/sddm-manager-$(date +%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYLAND_DIR="/usr/share/wayland-sessions"
SDDM_THEME_DIR="/usr/share/sddm/themes"
SDDM_CONF_DIR="/etc/sddm.conf.d"
THEME_REPO="https://github.com/JaKooLit/simple-sddm-2.git"

print() {
  echo -e "$1" | tee -a "$LOG"
}

# Ensure run as root
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run with sudo/root privileges."
  exit 1
fi

print "==== SDDM Display Manager Setup & Theming ===="

# -----------------------------
# 1. Install SDDM & dependencies
# -----------------------------
PACKAGES=(
  sddm
  qt6-declarative
  qt6-svg
  qt6-virtualkeyboard
  qt6-multimedia-ffmpeg
  qt6-5compat
  qt5-quickcontrols2
  # Most SDDM themes (including simple-sddm-2) are Qt5 QML and do
  # `import QtGraphicalEffects 1.0`. That module ships ONLY in this package —
  # qt6-5compat provides the Qt6 spelling (Qt5Compat.GraphicalEffects) and does
  # NOT satisfy it. Without this, SDDM falls back to a blank/plain greeter and
  # logs "module QtGraphicalEffects is not installed".
  qt5-graphicaleffects
)

print "\n[1/6] Installing SDDM and dependencies..."
pacman -S --needed --noconfirm "${PACKAGES[@]}" 2>&1 | tee -a "$LOG"

# -----------------------------
# 2. Disable other display managers
# -----------------------------
LOGIN_MANAGERS=(
  lightdm
  gdm
  gdm3
  lxdm
  lxdm-gtk3
)

print "\n[2/6] Disabling other display managers..."
for dm in "${LOGIN_MANAGERS[@]}"; do
  if systemctl list-unit-files | grep -q "^$dm.service"; then
    print "Disabling $dm..."
    systemctl disable "$dm" --now 2>/dev/null || true
  fi
done

# -----------------------------
# 3. Enable SDDM
# -----------------------------
print "\n[3/6] Enabling SDDM service..."
systemctl enable sddm 2>&1 | tee -a "$LOG"

# -----------------------------
# 4. Wayland session setup
# -----------------------------
print "\n[4/6] Setting up Wayland session directory..."
if [[ ! -d "$WAYLAND_DIR" ]]; then
  mkdir -p "$WAYLAND_DIR"
fi

# -----------------------------
# 5. Theme Selection & Installation
# -----------------------------
print "\n[5/6] Select SDDM theme to configure:"
echo "  [1] Candy (Local Archive)"
echo "  [2] Corners (Local Archive)"
echo "  [3] Simple SDDM 2 (Clone from GitHub)"
echo "  [4] Keep current / Skip theme setup"
read -rp "Enter choice [1-4]: " choice

THEME=""
case "$choice" in
  1)
    THEME="Candy"
    THEMEFILE="${SCRIPT_DIR}/sddm/Sddm_Candy.tar.gz"
    if [[ -f "$THEMEFILE" ]]; then
      print "Installing Candy theme..."
      mkdir -p "$SDDM_THEME_DIR"
      tar -xzf "$THEMEFILE" -C "$SDDM_THEME_DIR"
    else
      print "[ERROR] Candy theme archive not found at: $THEMEFILE"
      exit 1
    fi
    ;;
  2)
    THEME="Corners"
    THEMEFILE="${SCRIPT_DIR}/sddm/Sddm_Corners.tar.gz"
    if [[ -f "$THEMEFILE" ]]; then
      print "Installing Corners theme..."
      mkdir -p "$SDDM_THEME_DIR"
      tar -xzf "$THEMEFILE" -C "$SDDM_THEME_DIR"
    else
      print "[ERROR] Corners theme archive not found at: $THEMEFILE"
      exit 1
    fi
    ;;
  3)
    THEME="simple_sddm_2"
    print "Cloning Simple SDDM 2 theme from GitHub..."
    rm -rf "/tmp/$THEME"
    git clone --depth=1 "$THEME_REPO" "/tmp/$THEME"
    mkdir -p "$SDDM_THEME_DIR"
    rm -rf "$SDDM_THEME_DIR/$THEME"
    mv "/tmp/$THEME" "$SDDM_THEME_DIR/$THEME"
    ;;
  *)
    print "Skipping theme installation."
    ;;
esac

if [[ -n "$THEME" ]]; then
  mkdir -p "$SDDM_CONF_DIR"
  cat > "${SDDM_CONF_DIR}/the_theme.conf" <<EOF
[Theme]
Current=$THEME
EOF
  print "[OK] SDDM configured to use theme: $THEME"
fi

# -----------------------------
# 6. Copy User Avatar
# -----------------------------
print "\n[6/6] Checking for user avatar..."
# Find the real user calling sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
AVATAR="${REAL_HOME}/.face.icon"

if [[ -f "$AVATAR" ]]; then
  mkdir -p /usr/share/sddm/faces
  cp "$AVATAR" "/usr/share/sddm/faces/${REAL_USER}.face.icon"
  print "[OK] Avatar face icon configured for $REAL_USER"
else
  print "No avatar file found at $AVATAR (optional)."
fi

print "\n==== SDDM Setup Completed Successfully! ===="
print "Log saved to: $LOG"
print "Please reboot to see your new login screen."
