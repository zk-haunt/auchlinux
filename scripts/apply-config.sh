#!/usr/bin/env bash
# Script to safely apply/sync configurations from the repository to ~/.config

set -euo pipefail

REPO_CONFIG_DIR="$(cd "$(dirname "$0")/../config" && pwd)"
TARGET_DIR="$HOME/.config"

echo "==== Applying configurations from repository to ~/.config ===="

# Folders to sync (will overwrite destination completely after backup)
FOLDERS=(
  "cava"
  "dunst"
  "fastfetch"
  "gtk-3.0"
  "gtk-4.0"
  "hypr"
  "kitty"
  "menus"
  "matugen"
  "nwg-look"
  "pypr"
  "Kvantum"
  "qt5ct"
  "qt6ct"
  "uwsm"
  "xsettingsd"
  "satty"
  "rofi"
  "starship"
  "swaync"
  "waybar"
  "xfce4"
  "zsh"
)

# Folders to merge (will copy files recursively without wiping the target folder)
MERGE_FOLDERS=(
  "Code - OSS"
)

# Filter folders if arguments are provided
SELECTED_FOLDERS=()
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    found=false
    for f in "${FOLDERS[@]}" "${MERGE_FOLDERS[@]}"; do
      if [[ "$arg" == "$f" ]]; then
        SELECTED_FOLDERS+=("$arg")
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      echo "[Warning] Folder '$arg' is not configured for syncing. Skipping."
    fi
  done
  if [[ ${#SELECTED_FOLDERS[@]} -eq 0 ]]; then
    echo "[Error] No valid folders specified. Exiting."
    exit 1
  fi
else
  # Default to syncing all folders
  SELECTED_FOLDERS=("${FOLDERS[@]}" "${MERGE_FOLDERS[@]}")
fi

contains_folder() {
  local item="$1"
  for f in "${SELECTED_FOLDERS[@]}"; do
    if [[ "$f" == "$item" ]]; then
      return 0
    fi
  done
  return 1
}

# Sync each standard folder
for folder in "${FOLDERS[@]}"; do
  contains_folder "$folder" || continue
  SRC="$REPO_CONFIG_DIR/$folder"
  DST="$TARGET_DIR/$folder"
  
  if [ -d "$SRC" ]; then
    # If the destination is a file or symlink, remove it so rsync can write to the directory
    if [ -f "$DST" ] || [ -L "$DST" ]; then
      echo "[Clean] Removing file/symlink at $DST"
      rm -f "$DST"
    fi
    
    echo "[Sync] Syncing $folder to ~/.config/..."
    mkdir -p "$DST"
    # Build per-folder exclude list to protect runtime-installed dirs not tracked in repo
    RSYNC_EXCLUDES=()
    if [[ "$folder" == "zsh" ]]; then
      RSYNC_EXCLUDES+=("--exclude=ohmyzsh/")       # installed by term-n-font.sh
      RSYNC_EXCLUDES+=("--exclude=.zcompdump*")    # zsh completion cache
      RSYNC_EXCLUDES+=("--exclude=.zsh_history")   # shell history
      RSYNC_EXCLUDES+=("--exclude=.zsh_sessions/") # zsh session files
    elif [[ "$folder" == "rofi" ]]; then
      RSYNC_EXCLUDES+=("--exclude=launcher/style.rasi")       # managed by rofi-theme
      RSYNC_EXCLUDES+=("--exclude=launcher/rofi_theme_mode")  # active theme state
    elif [[ "$folder" == "waybar" ]]; then
      RSYNC_EXCLUDES+=("--exclude=modules/")
      RSYNC_EXCLUDES+=("--exclude=includes/")
      RSYNC_EXCLUDES+=("--exclude=theme.css")
      RSYNC_EXCLUDES+=("--exclude=config.jsonc")
      RSYNC_EXCLUDES+=("--exclude=style.css")
      RSYNC_EXCLUDES+=("--exclude=themes/waybar_theme_mode")
    fi
    rsync --archive --delete "${RSYNC_EXCLUDES[@]}" "$SRC/" "$DST/"
  else
    echo "[Skip] Folder $folder does not exist in repository config."
  fi
done

# Merge each merge-folder
for folder in "${MERGE_FOLDERS[@]}"; do
  contains_folder "$folder" || continue
  SRC="$REPO_CONFIG_DIR/$folder"
  DST="$TARGET_DIR/$folder"
  
  if [ -d "$SRC" ]; then
    echo "[Sync-Merge] Merging $folder into ~/.config/..."
    mkdir -p "$DST"
    rsync --archive "$SRC/" "$DST/"
  else
    echo "[Skip] Merge folder $folder does not exist in repository config."
  fi
done

# Sync individual files (like dolphinrc, kdeglobals)
FILES=(
  "dolphinrc"
  "kdeglobals"
  "dolphinstaterc"
  "mimeapps.list"
)

for file in "${FILES[@]}"; do
  if [ -f "$REPO_CONFIG_DIR/$file" ]; then
    echo "[Sync] Syncing file $file to ~/.config/..."
    cp -f "$REPO_CONFIG_DIR/$file" "$TARGET_DIR/$file"
  fi
done

# Waybar VPN module script.
# Kept in scripts/vpn/ with its docs rather than config/waybar/scripts/, but
# waybar loads it from ~/.config/waybar/scripts/ — and the waybar sync above
# runs with --delete, so this MUST come after it or the deployed copy is
# removed on every run.
if [ -f "$REPO_CONFIG_DIR/../scripts/vpn/vpn.sh" ]; then
  echo "[Sync] Deploying VPN waybar module script..."
  mkdir -p "$TARGET_DIR/waybar/scripts"
  cp -f "$REPO_CONFIG_DIR/../scripts/vpn/vpn.sh" "$TARGET_DIR/waybar/scripts/vpn.sh"
  chmod +x "$TARGET_DIR/waybar/scripts/vpn.sh"
fi

# Sync keepassxc config (lives in its own subdir).
# KeePassXC rewrites its ini on exit, so a running instance would clobber what we
# deploy. Kill it first (-9, so it can't write back), copy the config, then
# relaunch — this makes the dark theme (GUI/ApplicationTheme=dark) actually apply.
if [ -f "$REPO_CONFIG_DIR/keepassxc/keepassxc.ini" ]; then
  echo "[Sync] Syncing keepassxc config..."
  kp_was_running=false
  if pgrep -x keepassxc >/dev/null; then
    kp_was_running=true
    pkill -9 -x keepassxc 2>/dev/null
    sleep 1
  fi
  mkdir -p "$TARGET_DIR/keepassxc"
  cp -f "$REPO_CONFIG_DIR/keepassxc/keepassxc.ini" "$TARGET_DIR/keepassxc/keepassxc.ini"
  if [ "$kp_was_running" = true ]; then
    echo "[Reload] Restarting keepassxc to apply theme..."
    (keepassxc >/dev/null 2>&1 &)
  fi
fi

if [ -f "$REPO_CONFIG_DIR/dolphinstaterc" ]; then
  mkdir -p "$HOME/.local/state"
  cp -f "$REPO_CONFIG_DIR/dolphinstaterc" "$HOME/.local/state/dolphinstaterc"
fi

if [ -f "$REPO_CONFIG_DIR/dolphin_kxmlgui/dolphinui.rc" ]; then
  echo "[Sync] Syncing Dolphin UI layout to ~/.local/share/kxmlgui5/dolphin/..."
  mkdir -p "$HOME/.local/share/kxmlgui5/dolphin"
  cp -f "$REPO_CONFIG_DIR/dolphin_kxmlgui/dolphinui.rc" "$HOME/.local/share/kxmlgui5/dolphin/dolphinui.rc"
fi

if [ -f "$REPO_CONFIG_DIR/dolphin_global_dir" ]; then
  echo "[Sync] Syncing Dolphin global sorting layout..."
  mkdir -p "$HOME/.local/share/dolphin/view_properties/global"
  cp -f "$REPO_CONFIG_DIR/dolphin_global_dir" "$HOME/.local/share/dolphin/view_properties/global/.directory"
fi

# Rebuild the KDE application cache (ksycoca).
# uwsm exports XDG_MENU_PREFIX=hyprland-, so kbuildsycoca6 needs
# ~/.config/menus/hyprland-applications.menu (synced above) to exist —
# without it the cache is built with ZERO applications and Dolphin/KIO
# cannot open files with their default apps (imv, mpv, ark, ...).
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  echo "[KDE] Rebuilding application cache (ksycoca)..."
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

# Ensure all scripts under ~/.config/ are executable
echo "[Permissions] Ensuring all scripts under ~/.config/ are executable..."
find "$TARGET_DIR" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} + 2>/dev/null || true

# Reload Hyprland config (if running)
if pgrep -x "Hyprland" > /dev/null; then
  echo "[Reload] Reloading Hyprland configuration..."
  hyprctl reload || true
  
  # Also reload waybar if running
  if systemctl --user is-active waybar.service >/dev/null 2>&1; then
    echo "[Reload] Restarting Waybar via systemd..."
    systemctl --user restart waybar || true
  elif pgrep -u "$USER" -x "waybar" > /dev/null; then
    echo "[Reload] Restarting Waybar manually..."
    pkill -u "$USER" -USR2 waybar || pkill -u "$USER" waybar && waybar &
  fi
  
  # Restart notification daemon
  if command -v swaync >/dev/null 2>&1; then
    echo "[Reload] Restarting SwayNC notification daemon..."
    systemctl --user restart swaync || (pkill -x swaync || true && swaync &)
  else
    echo "[Reload] Restarting Dunst notification daemon..."
    systemctl --user restart dunst || systemctl --user start dunst || true
  fi
fi

# Sync GTK Settings to dconf/gsettings
echo "[GTK] Syncing cursor theme to GSettings database..."
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice" || true
gsettings set org.gnome.desktop.interface cursor-size 24 || true
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" || true

echo "[GTK] Configuring fallback cursor in ~/.icons/default..."
mkdir -p "$HOME/.icons/default"
echo -e "[Icon Theme]\nInherits=Bibata-Modern-Ice" > "$HOME/.icons/default/index.theme"

# Extract offline cursor/icon themes to ~/.icons (only if not already extracted)
REPO_ICONS="$REPO_CONFIG_DIR/../scripts/icons"
if [ -d "$REPO_ICONS" ]; then
  mkdir -p "$HOME/.icons"
  for tarball in "$REPO_ICONS"/*.tar.gz; do
    [ -f "$tarball" ] || continue
    name=$(basename "$tarball" .tar.gz)
    if [ ! -d "$HOME/.icons/$name" ]; then
      echo "[Sync] Extracting cursor/icon theme $name to ~/.icons..."
      tar -xzf "$tarball" -C "$HOME/.icons/"
    fi
  done
fi

# Extract offline GTK themes to ~/.themes (only if not already extracted)
REPO_GTK_THEMES="$REPO_CONFIG_DIR/../scripts/gtk-themes"
if [ -d "$REPO_GTK_THEMES" ]; then
  mkdir -p "$HOME/.themes"
  for tarball in "$REPO_GTK_THEMES"/*.tar.gz; do
    [ -f "$tarball" ] || continue
    # NOTE: `| head -1` here would kill this script. head closes the pipe after
    # one line, tar dies of SIGPIPE (141), `set -o pipefail` propagates that, and
    # `set -e` aborts — silently, right before the success message, taking any
    # caller (term-n-font.sh) down with it. awk reads the whole listing instead.
    theme_dir=$(tar -tzf "$tarball" | awk -F/ 'NR==1{print $1}')
    if [ -n "$theme_dir" ] && [ ! -d "$HOME/.themes/$theme_dir" ]; then
      echo "[Sync] Extracting GTK theme $theme_dir to ~/.themes..."
      tar -xzf "$tarball" -C "$HOME/.themes/"
    fi
  done
fi

echo "==== Configurations successfully applied! ===="
