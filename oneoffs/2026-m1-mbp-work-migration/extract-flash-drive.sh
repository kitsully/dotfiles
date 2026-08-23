#!/bin/bash
# Copies everything prep-flash-drive.sh put on the flash drive into place
# under ~ on the NEW machine — ~/code projects, ~/Desktop, ~/Documents —
# recreating directories as needed.
#
#   ./extract-flash-drive.sh              prompts for the drive path
#   ./extract-flash-drive.sh /Volumes/X   use this path instead of prompting
#   ./extract-flash-drive.sh -n /Volumes/X   dry run: list what would copy,
#                                            write nothing
#
# Reads full-dirs.txt and files.txt (paths relative to ~) from this
# script's directory — the same lists prep-flash-drive.sh used. Safe to
# re-run (unchanged files are skipped, but a file edited on THIS machine
# since the last run is overwritten by the drive's copy). Exits nonzero
# if any copy failed.

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
        -*)           echo "extract-flash-drive: unknown flag '$arg' — try --help" >&2; exit 2 ;;
        *)            [ -n "$DRIVE" ] && { echo "extract-flash-drive: more than one path given" >&2; exit 2; }
                      DRIVE="$arg" ;;
    esac
done

if [ -z "$DRIVE" ]; then
    read -r -p "Path to the mounted flash drive (e.g. /Volumes/MIGRATE): " DRIVE
fi
DRIVE="${DRIVE%/}"
SRC_ROOT="$DRIVE/$MIGRATION_NAME/home"
[ -d "$SRC_ROOT" ] || { echo "extract-flash-drive: not found: $SRC_ROOT" >&2; exit 1; }

RSYNC_FLAGS=(-a)
[ "$DRY_RUN" = true ] && RSYNC_FLAGS=(--dry-run "${RSYNC_FLAGS[@]}")

echo "Copying from: $SRC_ROOT"
[ "$DRY_RUN" = true ] && echo "(dry run — nothing will be written)"
echo

COPIED=0; MISSING=0; FAILED=0

clean_line() {
    printf '%s' "${1%%#*}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

echo "== Directories =="
while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(clean_line "$raw")"
    [ -z "$line" ] && continue
    src="$SRC_ROOT/$line"
    dst="$BASE_DIR/$line"
    if [ ! -d "$src" ]; then
        echo "  ! not on drive, skipping: $line"
        MISSING=$((MISSING + 1))
        continue
    fi
    echo "  -> $line"
    [ "$DRY_RUN" = false ] && mkdir -p "$dst"
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
    src="$SRC_ROOT/$line"
    dst="$BASE_DIR/$line"
    if [ ! -f "$src" ]; then
        echo "  ! not on drive, skipping: $line"
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
echo "Done. $COPIED copied, $MISSING missing on drive, $FAILED failed."
[ "$FAILED" -eq 0 ] || exit 1
exit 0
