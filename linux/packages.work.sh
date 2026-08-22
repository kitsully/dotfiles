#!/bin/bash
set -uo pipefail

# Work-machine CLI tools — the Linux analogue of Brewfile.work, run by
# linux/packages.sh after the shared list.
#
# Intentionally minimal, for the same reasons as Brewfile.work: the core
# list already covers the toolchain. Before adding anything here, check it
# against your employer's policy on software licensing and data handling.
#
# Container runtime: Docker Desktop's licensing question doesn't exist on
# Linux — the docker engine and podman are free. Uncomment one if needed
# (this script has no distro detection; adjust apt/dnf/pacman to taste):
# sudo apt install -y podman          # open source, no per-seat licensing
# sudo apt install -y docker.io       # the plain docker engine

echo "nothing to install — see the comments in linux/packages.work.sh"
