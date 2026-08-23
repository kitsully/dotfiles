#!/bin/bash
# Copies ~/code (every project, git repos with .git intact), ~/Desktop,
# and ~/Documents onto a flash drive for the 2026 M1 MBP work migration.
# Run this on the OLD machine. Pairs with extract-flash-drive.sh, run on
# the new one.
#
#   ./prep-flash-drive.sh              prompts for the drive path
#   ./prep-flash-drive.sh /Volumes/X   use this path instead of prompting
#   ./prep-flash-drive.sh -n /Volumes/X   dry run: list what would copy,
#                                         write nothing
#
# Reads full-dirs.txt and files.txt (paths relative to ~) from this
# script's directory. node_modules, venv/.venv, __pycache__, .next,
# .cache, graphify-out, and .DS_Store are excluded from every directory
# copy — regenerable caches, not worth the space or the transfer time.
#
# Format the drive APFS (encrypted, ideally — .env secrets and personal
# documents ride along in plaintext), not exFAT: exFAT can't hold
# symlinks or exec bits, and the copied git repos contain both. The
# script warns on a FAT-family drive but does not refuse.
#
# macOS will ask for permission the first time the terminal touches
# Desktop/Documents — grant it or those two copy as empty.
#
# Exits nonzero if any copy failed (e.g. the drive filled up) — "Done"
# with exit 0 means every listed item made it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$HOME"
MIGRATION_NAME="2026-m1-mbp-work-migration"

DRY_RUN=false
DRIVE=""
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help)    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        -*)           echo "prep-flash-drive: unknown flag '$arg' — try --help" >&2; exit 2 ;;
        *)            [ -n "$DRIVE" ] && { echo "prep-flash-drive: more than one path given" >&2; exit 2; }
                      DRIVE="$arg" ;;
    esac
done

if [ -z "$DRIVE" ]; then
    read -r -p "Path to the mounted flash drive (e.g. /Volumes/MIGRATE): " DRIVE
fi
DRIVE="${DRIVE%/}"
[ -d "$DRIVE" ] || { echo "prep-flash-drive: not a directory: $DRIVE" >&2; exit 1; }
[ -w "$DRIVE" ] || { echo "prep-flash-drive: not writable: $DRIVE" >&2; exit 1; }

# exFAT/FAT32 drops symlinks and exec bits, which the copied git repos
# need. Warn, don't refuse — the user may know better.
FS_TYPE="$(mount | awk -v d="$DRIVE" '$3 == d { sub(/^\(/, "", $4); sub(/,$/, "", $4); print $4 }')"
case "$FS_TYPE" in
    exfat|msdos|ntfs)
        echo "WARNING: $DRIVE is $FS_TYPE — symlinks and executable bits will not"
        echo "survive the round trip. Reformat the drive APFS (Disk Utility) unless"
        echo "you're sure nothing being copied needs them."
        ;;
esac

DEST="$DRIVE/$MIGRATION_NAME/home"
RSYNC_FLAGS=(-a --exclude node_modules --exclude .venv --exclude venv \
             --exclude __pycache__ --exclude .next --exclude .cache \
             --exclude graphify-out --exclude .DS_Store)
[ "$DRY_RUN" = true ] && RSYNC_FLAGS=(--dry-run "${RSYNC_FLAGS[@]}")

echo "Copying to: $DEST"
[ "$DRY_RUN" = true ] && echo "(dry run — nothing will be written)"
echo

COPIED=0; MISSING=0; FAILED=0

# strip comments/whitespace from a list line; empty result means skip.
clean_line() {
    printf '%s' "${1%%#*}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

echo "== Directories =="
# "|| [ -n "$raw" ]" keeps a final line that lacks a trailing newline
while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(clean_line "$raw")"
    [ -z "$line" ] && continue
    src="$BASE_DIR/$line"
    dst="$DEST/$line"
    if [ ! -d "$src" ]; then
        echo "  ! missing, skipping: $line"
        MISSING=$((MISSING + 1))
        continue
    fi
    echo "  -> $line"
    [ "$DRY_RUN" = false ] && mkdir -p "$(dirname "$dst")"
    if rsync "${RSYNC_FLAGS[@]}" "$src/" "$dst/" < /dev/null; then
        COPIED=$((COPIED + 1))
    else
        echo "  ! rsync failed: $line" >&2
        FAILED=$((FAILED + 1))
    fi
done < "$SCRIPT_DIR/full-dirs.txt"

echo
echo "== Files =="
while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(clean_line "$raw")"
    [ -z "$line" ] && continue
    src="$BASE_DIR/$line"
    dst="$DEST/$line"
    if [ ! -f "$src" ]; then
        echo "  ! missing, skipping: $line"
        MISSING=$((MISSING + 1))
        continue
    fi
    echo "  -> $line"
    if [ "$DRY_RUN" = true ]; then
        COPIED=$((COPIED + 1))
        continue
    fi
    mkdir -p "$(dirname "$dst")"
    if cp -p "$src" "$dst" < /dev/null; then
        COPIED=$((COPIED + 1))
    else
        echo "  ! copy failed: $line" >&2
        FAILED=$((FAILED + 1))
    fi
done < "$SCRIPT_DIR/files.txt"

echo
echo "Done. $COPIED item(s) copied, $MISSING missing (skipped), $FAILED failed."
if [ "$DRY_RUN" = false ]; then
    du -sh "$DEST" 2>/dev/null | sed 's/^/Total on drive: /'
fi
[ "$FAILED" -eq 0 ] || exit 1
exit 0
