#!/usr/bin/env bash
# Install/repair/remove Vencord on the native Discord client (themes + plugins).
# Downloads the OFFICIAL Vencord CLI installer to a temp file (inspectable, not a
# blind curl|sh), closes Discord, patches it, and tells you to relaunch.
#
#   discord-vencord.sh            install (or re-patch after a Discord update)
#   discord-vencord.sh uninstall  remove Vencord, restore vanilla Discord
#
# After install: Discord → Settings → Vencord → Themes to apply a theme that
# matches your desktop (e.g. a Catppuccin/cyan theme), and enable plugins.
set -uo pipefail
CLI_URL="https://github.com/Vendicated/VencordInstaller/releases/latest/download/VencordInstallerCli-linux"

have(){ command -v "$1" &>/dev/null; }
have discord || { echo "discord is not installed"; exit 1; }
have curl    || { echo "curl required"; exit 1; }

bin="$(mktemp --suffix=-vencord-cli)"
trap 'rm -f "$bin"' EXIT
echo "Downloading official Vencord installer…"
curl -fsSL --max-time 60 "$CLI_URL" -o "$bin" || { echo "Download failed"; exit 1; }
chmod +x "$bin"

echo "Closing Discord (so the app files can be patched)…"
pkill -x Discord 2>/dev/null; pkill -x discord 2>/dev/null; sleep 1

case "${1:-install}" in
    uninstall) "$bin" -uninstall; msg="Vencord removed — Discord restored to vanilla." ;;
    *)         "$bin" -install;   msg="Vencord installed — relaunch Discord, then Settings → Vencord." ;;
esac

echo "$msg"
have notify-send && notify-send -a Discord -i discord "Vencord" "$msg"
