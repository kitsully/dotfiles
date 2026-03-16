#!/bin/bash
# macOS system preferences

# Prompt for sudo upfront and keep it alive until the script finishes
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

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
mkdir -p "$HOME/docs/screenshots"
defaults write com.apple.screencapture location -string "$HOME/docs/screenshots"
defaults write com.apple.screencapture type -string "png"

# === Security ===
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

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
defaults write com.apple.Safari IncludeDevelopMenu -bool true

# === Terminal ===
touch ~/.hushlogin  # Disable "Last login" message

# Restart affected apps
killall Dock Finder 2>/dev/null || true

echo "Done. Some changes may require a logout/restart."
