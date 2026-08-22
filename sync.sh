#!/bin/bash
# Folds this machine's drift back into the repo — the things that live outside
# it and never show up in `git status` on their own: brew packages, VS Code
# extensions, the iTerm2 profile. (Symlinked configs already show up.)
#
#   ./sync.sh               update the repo files, then show git status —
#                           review with `git diff`, commit when happy
#   ./sync.sh --dry-run     report the drift and stop
#
# Nothing is committed or pushed for you; git is the undo button, which is
# what makes applying safe.
#
# To add a target: write a sync_<thing>() below that compares live state with
# the repo copy, prints what drifted, and rewrites the repo file unless
# DRY_RUN is true — then call it in the list at the bottom.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
info() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }

DRY_RUN=false
case "${1:-}" in
    "")           ;;
    -n|--dry-run) DRY_RUN=true ;;
    -h|--help)    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *)            printf "unknown flag '%s' — try --help\n" "$1"; exit 1 ;;
esac

PROFILE=""
[ -f "$HOME/.config/dotfiles/profile" ] && PROFILE="$(cat "$HOME/.config/dotfiles/profile")"
if [ "$(uname)" = Darwin ] && [ -z "$PROFILE" ]; then
    printf "No profile is recorded on this machine — run ./setup.sh <profile> once first.\n"
    exit 1
fi

TMP="${TMPDIR:-/tmp}/dotfiles-sync.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT INT TERM

# ── Homebrew packages ───────────────────────────────────────────────────
# Compares what is installed against Brewfile + Brewfile.$PROFILE. New
# packages are only ever added, and go to Brewfile.$PROFILE (this kind of
# machine); move a line into Brewfile afterwards if it belongs on every Mac.
# Packages tracked but not installed here are reported and left alone — on a
# fresh machine that just means you have not installed them yet.
sync_brew() {
    command -v brew >/dev/null 2>&1 || { info "brew: not installed — skipping"; return 0; }
    # key mas apps by id: the name brew reports ("CARROTweather") often
    # differs from the one in the Brewfile ("CARROT Weather")
    _keyed() {
        awk '{ line=$0
               if ($0 ~ /^mas /) { match($0, /id: [0-9]+/); key = "mas " substr($0, RSTART, RLENGTH) }
               else key = $0
               print key "\t" line }' | sort -u -t"$(printf '\t')" -k1,1
    }
    _clean() { grep -hE '^(tap|brew|cask|mas) ' "$@" 2>/dev/null | awk -F'#' '{print $1}' | awk '{$1=$1};1'; }

    brew bundle dump --file=- 2>/dev/null | _clean - > "$TMP/live"
    _keyed < "$TMP/live" > "$TMP/live.kv"
    _clean "$SCRIPT_DIR/Brewfile" "$SCRIPT_DIR/Brewfile.$PROFILE" | _keyed > "$TMP/repo.kv"
    cut -f1 "$TMP/live.kv" | sort -u > "$TMP/live.k"
    cut -f1 "$TMP/repo.kv" | sort -u > "$TMP/repo.k"
    # untracked here -> original live lines, preserving formatting
    comm -23 "$TMP/live.k" "$TMP/repo.k" \
        | awk -F'\t' 'NR==FNR{want[$0]=1;next} want[$1]{print $2}' - "$TMP/live.kv" > "$TMP/added"
    NOT_HERE="$(comm -13 "$TMP/live.k" "$TMP/repo.k" | grep -c . || true)"

    if [ ! -s "$TMP/added" ]; then
        ok "brew: in sync ($NOT_HERE tracked but not installed here — left alone)"
        return 0
    fi
    printf "%sbrew: installed here but not tracked%s\n" "$BOLD" "$RESET"
    sed 's/^/      + /' "$TMP/added"
    [ "$DRY_RUN" = true ] && return 0
    { grep '^tap ' "$TMP/added"; grep -v '^tap ' "$TMP/added"; } >> "$SCRIPT_DIR/Brewfile.$PROFILE"
    ok "added to Brewfile.$PROFILE"
}

# ── VS Code extensions ──────────────────────────────────────────────────
# vscode/extensions.txt is exactly `code --list-extensions`, so applying is
# a straight rewrite.
sync_vscode() {
    command -v code >/dev/null 2>&1 || { info "vscode: 'code' not on PATH — skipping"; return 0; }
    code --list-extensions 2>/dev/null | sort > "$TMP/ext.live"
    sort "$SCRIPT_DIR/vscode/extensions.txt" > "$TMP/ext.repo"
    if cmp -s "$TMP/ext.live" "$TMP/ext.repo"; then ok "vscode: in sync"; return 0; fi
    if [ ! -s "$TMP/ext.live" ] && [ -s "$TMP/ext.repo" ]; then
        warn "vscode: 'code' reported zero extensions — that looks broken, not like drift; skipping"
        return 0
    fi
    printf "%svscode: extensions changed%s\n" "$BOLD" "$RESET"
    comm -23 "$TMP/ext.live" "$TMP/ext.repo" | sed 's/^/      + /'
    comm -13 "$TMP/ext.live" "$TMP/ext.repo" | sed 's/^/      - /'
    [ "$DRY_RUN" = true ] && return 0
    cp "$TMP/ext.live" "$SCRIPT_DIR/vscode/extensions.txt"
    ok "rewrote vscode/extensions.txt"
}

# ── iTerm2 profile ──────────────────────────────────────────────────────
# The repo copy is a *dynamic* profile with its own Guid and name — iTerm2
# refuses a dynamic profile that reuses the Guid of a real one. Only the
# settings are tracked, and compared semantically (plutil emits ints where
# the repo copy has floats).
sync_iterm2() {
    local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    local repo_json="$SCRIPT_DIR/iterm2/Default.json"
    [ -f "$plist" ] && command -v plutil >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 \
        || { info "iterm2: plist not readable — skipping"; return 0; }
    plutil -extract "New Bookmarks" json -o "$TMP/iterm.live" "$plist" 2>/dev/null \
        || { info "iterm2: no profiles in the plist — skipping"; return 0; }

    local verdict
    verdict="$(DEFAULT_GUID="$(defaults read com.googlecode.iterm2 'Default Bookmark Guid' 2>/dev/null)" \
        python3 - "$TMP/iterm.live" "$repo_json" "$TMP/iterm.new" <<'PYEOF'
import json, os, sys

DYN_GUID = "dotfiles-iterm2-default"
DYN_NAME = "Dotfiles"

live = json.load(open(sys.argv[1]))
want = os.environ.get("DEFAULT_GUID", "")
chosen = next((p for p in live if p.get("Guid") == want), live[0] if live else None)
if chosen is None:
    print("SAME"); sys.exit()

norm = dict(chosen)
norm["Guid"] = DYN_GUID
norm["Name"] = DYN_NAME

try:
    repo = json.load(open(sys.argv[2])).get("Profiles", [])
except Exception:
    repo = []

json.dump({"Profiles": [norm]}, open(sys.argv[3], "w"), indent=2, sort_keys=True)
print("SAME" if repo == [norm] else "DIFF")
PYEOF
)"
    if [ "$verdict" != DIFF ]; then ok "iterm2: in sync"; return 0; fi
    printf "%siterm2: profile changed%s\n" "$BOLD" "$RESET"
    [ "$DRY_RUN" = true ] && return 0
    # write atomically: iTerm2 watches this file and would read a half-written
    # copy as invalid JSON
    cp "$TMP/iterm.new" "$repo_json.tmp" && mv -f "$repo_json.tmp" "$repo_json"
    ok "rewrote iterm2/Default.json"
}

# ── The targets — add new ones here ─────────────────────────────────────
sync_brew
sync_vscode
sync_iterm2

# ── Result ──────────────────────────────────────────────────────────────
printf "\n"
if [ "$DRY_RUN" = true ]; then info "dry run — nothing was changed"; exit 0; fi
cd "$SCRIPT_DIR" || exit 1
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    printf "%sUncommitted changes in the repo:%s\n" "$BOLD" "$RESET"
    git status --short | sed 's/^/    /'
    info "review with: git diff — then commit and push yourself"
else
    ok "everything is in sync — nothing to commit"
fi
