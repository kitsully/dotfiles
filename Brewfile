# Core packages — installed on every machine, work or personal.
#
# Profile-specific additions live in Brewfile.personal / Brewfile.work.
# setup.sh installs this file first, then the profile file.

# On a managed (MDM) work Mac some of these apps may already be installed.
# adopt makes brew take ownership of a same-version copy instead of erroring;
# if MDM's version differs it still refuses — for those, let MDM own the app
# and remove its line here.
cask_args adopt: true

# === CLI Tools ===
brew "atuin"
brew "awscli"
brew "cmake"
brew "dockutil"
brew "fd"
brew "findutils"
brew "fzf"
brew "gh"
brew "graphviz"
brew "hey"
brew "jq"
brew "mas"
brew "mise"
brew "mosh"
brew "neovim"
brew "opentofu"
brew "pandoc"
brew "postgresql@18"
brew "rclone"
brew "ripgrep"
brew "sqlite"
brew "tree"
brew "tree-sitter"
brew "wget"
brew "zoxide"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

# === Fonts ===
cask "font-jetbrains-mono-nerd-font"
cask "font-meslo-lg-nerd-font"

# === Cask Apps ===
cask "1password"
cask "1password-cli"
cask "bbedit"
cask "claude"
cask "elgato-stream-deck"
cask "firefox"
cask "google-chrome"
cask "hazel"
cask "intellij-idea"
cask "iterm2"
cask "microsoft-edge"
cask "microsoft-excel"
cask "microsoft-powerpoint"
cask "microsoft-word"
cask "obsidian"
cask "postman"
cask "raycast"
cask "textexpander"
cask "tower"
cask "transmit"
cask "visual-studio-code"
cask "zoom"

# === Mac App Store ===
# Requires an Apple ID signed into the machine, including on work Macs.
mas "Amphetamine", id: 937984704
mas "Drafts", id: 1435957248
