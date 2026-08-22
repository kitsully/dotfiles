#!/bin/bash
# macOS system preferences

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    DIM="$(tput dim)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
    DIM=""; GREEN=""; YELLOW=""; RESET=""
fi
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }

# === Dock ===
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock largesize -int 128
ok "Dock — autohide, magnified"

# === Finder ===
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"  # List view by default
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true   # Full path in title bar
chflags nohidden ~/Library                                           # Show ~/Library

# Disable .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
ok "Finder — extensions, path bar, list view, no stray .DS_Store"

# === Appearance ===
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
ok "Appearance — dark mode"

# === Keyboard/Input ===
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
ok "Keyboard — fast repeat, no autocorrect or smart quotes"

# === Trackpad ===
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
ok "Trackpad — tap to click, three-finger drag"

# === Screenshots ===
mkdir -p "$HOME/Desktop/screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/screenshots"
defaults write com.apple.screencapture type -string "png"
ok "Screenshots — PNGs into ~/Desktop/screenshots"

# === Security ===
# ${SUDO_ASKPASS:+-A}: when setup.sh stored the password, answer with it
# instead of prompting — the Homebrew installer (the step right before this
# one) wipes sudo's timestamp cache on exit, so a plain sudo here would ask
# again even though the password was just typed.
if [ -t 0 ] || [ -n "${SUDO_ASKPASS:-}" ]; then
    sudo ${SUDO_ASKPASS:+-A} /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
    ok "Firewall — on"

    # Touch ID for sudo: fingerprint instead of a typed password.
    # /etc/pam.d/sudo_local is Apple's hook for this and survives OS updates.
    if [ -f /etc/pam.d/sudo_local.template ] && ! grep -q '^auth' /etc/pam.d/sudo_local 2>/dev/null; then
        sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo ${SUDO_ASKPASS:+-A} tee /etc/pam.d/sudo_local >/dev/null \
            && ok "Touch ID for sudo — enabled"
    else
        ok "Touch ID for sudo — already enabled"
    fi
else
    warn "skipped firewall and Touch ID setup (need sudo; no terminal to ask)"
fi

# === Dialogs ===
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.LaunchServices LSQuarantine -bool false
ok "Dialogs — expanded save/print panels, no iCloud default"

# === Crash Reporter ===
defaults write com.apple.CrashReporter DialogType -string "none"

# === Safari (dev menu) ===
# Safari is sandboxed; writing its prefs needs Full Disk Access for the terminal
if defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null; then
    ok "Safari — develop menu"
else
    warn "skipped Safari dev menu (no Full Disk Access — or turn it on in Safari > Settings > Advanced)"
fi

# === Terminal ===
touch ~/.hushlogin  # Disable "Last login" message

# Restart affected apps
killall Dock Finder 2>/dev/null || true

printf "  %ssome changes need a logout or restart to fully apply%s\n" "$DIM" "$RESET"
