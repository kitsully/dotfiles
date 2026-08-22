#!/bin/bash
# macOS system preferences

echo "Configuring macOS defaults..."

# === Dock ===
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock largesize -int 128

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

# === Appearance ===
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# === Keyboard/Input ===
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# === Trackpad ===
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# === Screenshots ===
mkdir -p "$HOME/Desktop/screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/screenshots"
defaults write com.apple.screencapture type -string "png"

# === Security ===
if [ -t 0 ]; then
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

    # Touch ID for sudo: fingerprint instead of a typed password.
    # /etc/pam.d/sudo_local is Apple's hook for this and survives OS updates.
    if [ -f /etc/pam.d/sudo_local.template ] && ! grep -q '^auth' /etc/pam.d/sudo_local 2>/dev/null; then
        sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local >/dev/null             && echo "  Touch ID enabled for sudo"
    fi
else
    echo "  skipped firewall and Touch ID setup (need sudo; no terminal to ask)"
fi

# === Dialogs ===
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.LaunchServices LSQuarantine -bool false

# === Crash Reporter ===
defaults write com.apple.CrashReporter DialogType -string "none"

# === Safari (dev menu) ===
# Safari is sandboxed; writing its prefs needs Full Disk Access for the terminal
defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null \
    || echo "  skipped Safari dev menu (no Full Disk Access — or turn it on in Safari > Settings > Advanced)"

# === Terminal ===
touch ~/.hushlogin  # Disable "Last login" message

# Restart affected apps
killall Dock Finder 2>/dev/null || true

echo "Done. Some changes may require a logout/restart."
