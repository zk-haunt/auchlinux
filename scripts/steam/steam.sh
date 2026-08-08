#!/usr/bin/env bash

# Steam + Proton setup script for Arch Linux
# GPU-aware: detects AMD / Intel / NVIDIA (including hybrid laptops) and
# installs the matching Vulkan stack. Run as your normal user: ./steam.sh

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user (it uses sudo where needed)." >&2
    exit 1
fi

echo "========================================="
echo " Steam + Proton Setup for Arch Linux"
echo "========================================="
echo

# Detect AUR helper (only needed if proton-ge isn't in a binary repo)
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
else
    AUR_HELPER=""
fi

# Enable multilib if not enabled
echo "[1/7] Checking multilib repository..."

if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "Enabling multilib repository..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/s/^#//' /etc/pacman.conf
else
    echo "Multilib already enabled."
fi

# Update package database
echo
echo "[2/7] Updating system packages..."
sudo pacman -Syu --noconfirm

# Install graphics drivers — check every GPU line so hybrid setups
# (e.g. AMD iGPU + NVIDIA dGPU) get both stacks, not just the first match.
echo
echo "[3/7] Installing Vulkan + graphics support..."

GPU_INFO=$(lspci | grep -Ei "vga|3d|display" || true)
echo "$GPU_INFO"

GPU_PKGS=(
    vulkan-icd-loader
    lib32-vulkan-icd-loader
    vulkan-tools
    vulkan-mesa-layers
    lib32-vulkan-mesa-layers
)
GPU_FOUND=0

if grep -qi "nvidia" <<<"$GPU_INFO"; then
    GPU_FOUND=1
    echo "-> NVIDIA GPU detected."
    # nvidia/nvidia-dkms were dropped from the repos; nvidia-open-dkms is the
    # current driver and builds for every installed kernel (incl. linux-zen).
    GPU_PKGS+=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils)
    pacman -Q linux     >/dev/null 2>&1 && GPU_PKGS+=(linux-headers)
    pacman -Q linux-zen >/dev/null 2>&1 && GPU_PKGS+=(linux-zen-headers)
    pacman -Q linux-lts >/dev/null 2>&1 && GPU_PKGS+=(linux-lts-headers)
fi
if grep -Eqi "amd|ati|radeon" <<<"$GPU_INFO"; then
    GPU_FOUND=1
    echo "-> AMD GPU detected."
    GPU_PKGS+=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon mesa-demos)
fi
if grep -qi "intel" <<<"$GPU_INFO"; then
    GPU_FOUND=1
    echo "-> Intel GPU detected."
    GPU_PKGS+=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel)
fi
if [[ $GPU_FOUND -eq 0 ]]; then
    echo "-> Unknown GPU. Installing generic Mesa/Vulkan stack..."
    GPU_PKGS+=(mesa lib32-mesa)
fi

sudo pacman -S --needed --noconfirm "${GPU_PKGS[@]}"

# Install Steam (+ fonts and 32-bit audio, the two most common missing pieces)
echo
echo "[4/7] Installing Steam..."
sudo pacman -S --needed --noconfirm steam ttf-liberation lib32-pipewire

# Install Proton-GE
echo
echo "[5/7] Installing Proton-GE..."

if pacman -Si proton-ge-custom-bin >/dev/null 2>&1; then
    # Available as a binary package (chaotic-aur)
    sudo pacman -S --needed --noconfirm proton-ge-custom-bin
elif [[ -n "$AUR_HELPER" ]]; then
    "$AUR_HELPER" -S --needed --noconfirm proton-ge-custom-bin
else
    echo "No AUR helper found — skipping Proton-GE."
    echo "Install paru/yay, or just use Proton Experimental from Steam."
fi

# Extra gaming tools
echo
echo "[6/7] Installing extra gaming utilities..."

sudo pacman -S --needed --noconfirm \
    gamemode \
    lib32-gamemode \
    mangohud \
    lib32-mangohud \
    gamescope

# Default MangoHud overlay config. This script is the only thing that installs
# it — apply-config.sh deliberately doesn't, so there's one source of truth.
# Never overwrites an existing config, so your own tweaks survive a re-run.
echo
echo "[7/7] Installing default MangoHud config..."
SRC_CONF="$(cd "$(dirname "$0")" && pwd)/MangoHud/MangoHud.conf"
if [[ ! -f "$SRC_CONF" ]]; then
    echo "No MangoHud config alongside this script ($SRC_CONF) — skipped."
elif [[ -e "$HOME/.config/MangoHud/MangoHud.conf" ]]; then
    echo "MangoHud config already present at ~/.config/MangoHud/ — left alone."
else
    mkdir -p "$HOME/.config/MangoHud"
    cp "$SRC_CONF" "$HOME/.config/MangoHud/"
    echo "MangoHud config installed to ~/.config/MangoHud/."
fi

echo
echo "========================================="
echo " Setup Complete!"
echo "========================================="
echo
echo "Next steps:"
echo "1. Launch Steam"
echo "2. Login"
echo "3. Go to:"
echo "   Steam > Settings > Compatibility"
echo "4. Enable:"
echo "   ✓ Enable Steam Play for supported titles"
echo "   ✓ Enable Steam Play for all other titles"
echo "5. Select Proton-GE or Proton Experimental"
echo
echo "========================================="
echo " 🎮 Counter-Strike 2 (CS2) Optimizations"
echo "========================================="
echo
echo "Recommended Steam Launch Options:"
echo "  gamemoderun %command% -novid -nojoy -fullscreen +fps_max 120"
echo
echo "With the MangoHud overlay (FPS/frametime/temps, toggle Shift_R+F12):"
echo "  mangohud gamemoderun %command% -novid -nojoy -fullscreen +fps_max 120"
echo
echo "Running under Wayland (Native):"
echo "To bypass Xwayland for lower input latency, you can run CS2 natively on Wayland"
echo "by adding this environment variable to your Steam Launch Options:"
echo "  SDL_VIDEODRIVER=wayland gamemoderun %command% -novid -nojoy -fullscreen +fps_max 120"
echo
echo "Alternatively, you can run it via Gamescope (Valve's Wayland micro-compositor):"
echo "  gamescope -W 1280 -H 720 -r 120 -F fsr -- gamemoderun %command% -novid -nojoy -fullscreen +fps_max 120"
echo
echo "Recommended In-Game Settings (Ryzen 5 5500U / Vega 7):"
echo "  - Resolution: 1280x720"
echo "  - FSR: ON (Quality or Balanced)"
echo "  - Global Shadow Quality: Low"
echo "  - MSAA: Off"
echo "  - Ambient Occlusion: Off"
echo "  - V-Sync: Off"
echo
echo "Note: The first few runs may stutter due to background shader compilation."
echo "Using the Zen kernel provides a smoother frametime distribution!"
echo

# gamemoderun %command% -novid -nojoy -fullscreen +fps_max 120