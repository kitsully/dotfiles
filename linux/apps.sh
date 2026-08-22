#!/bin/bash
set -uo pipefail

# Desktop (GUI) apps, installed from Flathub — the Linux analogue of the
# Brewfile cask sections. Reads linux/apps.txt (every desktop machine) then
# linux/apps.<profile>.txt (that kind of machine only). Lines are Flathub
# app IDs; blank lines and #-comments are ignored. Adding an app is a data
# change: find its ID on https://flathub.org and add a line — no code.
#
# Apps install per-user (--user): no sudo or polkit prompts, and later
# updates don't need root either. Only installing flatpak itself uses sudo.
#
# Usage: apps.sh <profile> [--upgrade]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="${1:-}"
UPGRADE=false
[ "${2:-}" = "--upgrade" ] && UPGRADE=true

if ! command -v flatpak &>/dev/null; then
    echo "Installing flatpak..."
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y flatpak
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y flatpak
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm flatpak
    else
        echo "No supported package manager found — install flatpak manually."
        exit 1
    fi
fi

flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo || exit 1

INSTALLED="$(flatpak list --user --app --columns=application 2>/dev/null)"
FAILED=""
NEWLY_INSTALLED=false

install_list() {
    local file="$1" line id
    [ -f "$file" ] || return 0
    echo "── ${file##*/}"
    while IFS= read -r line; do
        id="${line%%#*}"
        id="${id//[[:space:]]/}"
        [ -z "$id" ] && continue
        if printf '%s\n' "$INSTALLED" | grep -qxF "$id"; then
            echo "  already installed: $id"
        elif flatpak install --user -y --noninteractive flathub "$id"; then
            NEWLY_INSTALLED=true
        else
            FAILED="$FAILED$id, "
        fi
    done < "$file"
}

install_list "$SCRIPT_DIR/apps.txt"
install_list "$SCRIPT_DIR/apps.$PROFILE.txt"

if [ "$UPGRADE" = true ]; then
    echo "── updating installed apps"
    flatpak update --user -y --noninteractive
fi

echo ""
if [ -n "$FAILED" ]; then
    echo "Some apps failed to install: ${FAILED%, }"
    echo "Check the ID on https://flathub.org and fix the line in linux/apps*.txt."
    exit 1
fi
[ "$NEWLY_INSTALLED" = true ] && \
    echo "Note: newly installed apps may not appear in the launcher until you log out and back in."
echo "Desktop apps installed."
