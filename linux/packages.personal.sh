#!/bin/bash
set -uo pipefail

# Personal-machine CLI tools — the Linux analogue of Brewfile.personal's
# CLI section, run by linux/packages.sh after the shared list. Same rules
# as everything else here: safe to re-run, each install skipped once the
# tool is present. (xcodegen is mac-only and has no line here.)

mkdir -p "$HOME/.local/bin"

# doctl — personal DigitalOcean account. Not in distro repos; the official
# install is the GitHub release tarball, dropped into ~/.local/bin.
if ! command -v doctl &>/dev/null; then
    echo "Installing doctl..."
    case "$(uname -m)" in
        x86_64)        arch=amd64 ;;
        aarch64|arm64) arch=arm64 ;;
        *)             arch="" ;;
    esac
    ver="$(curl -fsSL https://api.github.com/repos/digitalocean/doctl/releases/latest \
        | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')"
    if [ -n "$arch" ] && [ -n "$ver" ] && curl -fsSL \
        "https://github.com/digitalocean/doctl/releases/download/v${ver}/doctl-${ver}-linux-${arch}.tar.gz" \
        | tar -xz -C "$HOME/.local/bin" doctl; then
        echo "  doctl ${ver} installed to ~/.local/bin"
    else
        echo "  ! could not install doctl (arch '$(uname -m)' or GitHub API lookup failed) — install manually"
    fi
fi

# heroku — personal Heroku account. Official installer (uses sudo itself).
if ! command -v heroku &>/dev/null; then
    echo "Installing heroku CLI..."
    curl -fsSL https://cli-assets.heroku.com/install.sh | sh
fi
