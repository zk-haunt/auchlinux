#!/usr/bin/env bash
# USB backup & recovery for the important bits of $HOME.
# Uses rsync (preserves perms/ACLs/xattrs). Safe by default: no --delete unless
# you pass --mirror.
#
#   usb-backup.sh backup  [/mount/point] [--mirror]   # HOME → USB
#   usb-backup.sh restore [/mount/point]              # USB → HOME (asks first)
#   usb-backup.sh list    [/mount/point]              # show what's on the backup
#
# If no mount point is given, the first directory under /run/media/$USER is used.
set -uo pipefail

DEST_SUBDIR="auch-backup"
# What to clone (relative to $HOME). Add your own lines as needed.
INCLUDE=(
    ".config"
    ".local/share"
    ".ssh"
    ".gnupg"
    ".zshrc" ".zshenv" ".zprofile"
    "auchlinux"
    "Documents"
)
EXCLUDE=(
    ".config/google-chrome" ".config/BraveSoftware" ".config/Cache" "*/Cache" "*/cache"
    ".local/share/Trash" ".local/share/Steam" "*.sock"
)

have(){ command -v "$1" &>/dev/null; }
note(){ echo -e "\033[0;36m[backup]\033[0m $*"; notify-send -a "USB Backup" "$*" 2>/dev/null; }
die(){ echo -e "\033[0;31m[backup] $*\033[0m" >&2; notify-send -u critical -a "USB Backup" "$*" 2>/dev/null; exit 1; }

have rsync || die "rsync not installed"

autodetect_mount() {
    local base="/run/media/$USER"
    [ -d "$base" ] || base="/media/$USER"
    find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1
}

build_rsync_args() {
    RSYNC_ARGS=(-aAXH --info=progress2 --human-readable)
    [ "${MIRROR:-0}" = 1 ] && RSYNC_ARGS+=(--delete)
    for e in "${EXCLUDE[@]}"; do RSYNC_ARGS+=(--exclude="$e"); done
}

cmd="${1:-}"; shift || true
MOUNT=""; MIRROR=0
for a in "$@"; do
    case "$a" in
        --mirror) MIRROR=1 ;;
        *) MOUNT="$a" ;;
    esac
done
[ -z "$MOUNT" ] && MOUNT="$(autodetect_mount)"
[ -z "$MOUNT" ] && die "No USB drive found under /run/media/$USER — plug one in or pass a path."
[ -d "$MOUNT" ] || die "Mount point '$MOUNT' does not exist."
DEST="$MOUNT/$DEST_SUBDIR"

case "$cmd" in
    backup)
        mkdir -p "$DEST" || die "Cannot write to $DEST (is the drive read-only?)"
        build_rsync_args
        note "Backing up to $DEST ${MIRROR:+(mirror mode)}…"
        for item in "${INCLUDE[@]}"; do
            src="$HOME/$item"
            [ -e "$src" ] || continue
            # Recreate parent path on the destination so nested items land correctly.
            mkdir -p "$DEST/$(dirname "$item")"
            rsync "${RSYNC_ARGS[@]}" "$src" "$DEST/$(dirname "$item")/"
        done
        date '+backed up: %F %T' > "$DEST/.last-backup"
        note "Backup complete → $DEST"
        ;;
    restore)
        [ -d "$DEST" ] || die "No backup found at $DEST"
        echo "About to restore $DEST → $HOME (existing files may be overwritten)."
        read -rp "Type 'yes' to continue: " ok
        [ "$ok" = yes ] || die "Aborted."
        build_rsync_args
        note "Restoring from $DEST…"
        rsync "${RSYNC_ARGS[@]}" "$DEST"/ "$HOME"/
        note "Restore complete."
        ;;
    list)
        [ -d "$DEST" ] || die "No backup found at $DEST"
        cat "$DEST/.last-backup" 2>/dev/null
        du -sh "$DEST"/* 2>/dev/null
        ;;
    *)
        echo "usage: usb-backup.sh backup|restore|list [/mount/point] [--mirror]"
        exit 1
        ;;
esac
