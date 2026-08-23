#!/bin/bash
# Clones the repos listed under repos/ into ~/Code. Safe to re-run any time:
# already-cloned repos are skipped, never touched.
#
#   ./clone-repos.sh              clone from repos/core.txt plus
#                                 repos/<profile>.txt (the profile recorded by
#                                 setup.sh in ~/.config/dotfiles/profile)
#   ./clone-repos.sh <file>...    clone from these list files instead
#   ./clone-repos.sh --dry-run    show what would be cloned, change nothing
#
# List format — one repo per line, in any of the three GitHub notations:
#   git@github.com:owner/repo.git     (ssh)
#   https://github.com/owner/repo     (https)
#   owner/repo                        (gh CLI shorthand)
# Repos are grouped into directories YAML-style: a "name:" heading opens a
# directory, the repos indented under it clone there, and headings nest to
# any depth. The ":" is what makes a heading — repos never end with one —
# so the two cannot be confused. A top-level heading is a subdirectory of
# ~/Code; a ~/… or absolute heading roots its own tree. Unindented repos go
# straight to ~/Code:
#   cli/cli                   -> ~/Code/cli
#   work:
#     acme/api                -> ~/Code/work/api
#     clients:
#       acme/webapp           -> ~/Code/work/clients/webapp
#   ~/somewhere:
#     owner/other             -> ~/somewhere/other
# Blank lines and comments (a whole line, or trailing after whitespace) are
# ignored. Indent with spaces or tabs — mixing them is an error, caught
# before anything is cloned. The format is bin/outline's; see its --help.
#
# The notation only identifies the repo: cloning always goes over ssh (so
# your keys and 1Password's agent apply), falling back to https only when
# ssh fails — a machine with no key set up yet can still fetch public repos.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODE_DIR="$HOME/Code"
PROFILE_FILE="$HOME/.config/dotfiles/profile"

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
info() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }

# ── Arguments: [file]... [--dry-run] ────────────────────────────────────
DRY_RUN=false
FILES=()
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help)    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        -*)           printf "unknown flag '%s' — try --help\n" "$arg"; exit 1 ;;
        *)            [ -f "$arg" ] || { printf "no such list file: %s\n" "$arg"; exit 1; }
                      FILES=(${FILES[@]+"${FILES[@]}"} "$arg") ;;
    esac
done

# With no files named, use core plus the recorded profile's list — the same
# core/<profile> split the Brewfiles use. Either file may simply not exist.
if [ ${#FILES[@]} -eq 0 ]; then
    [ -f "$SCRIPT_DIR/repos/core.txt" ] && FILES=(${FILES[@]+"${FILES[@]}"} "$SCRIPT_DIR/repos/core.txt")
    if [ -f "$PROFILE_FILE" ]; then
        PROFILE="$(cat "$PROFILE_FILE")"
        [ -f "$SCRIPT_DIR/repos/$PROFILE.txt" ] && FILES=(${FILES[@]+"${FILES[@]}"} "$SCRIPT_DIR/repos/$PROFILE.txt")
    fi
fi
if [ ${#FILES[@]} -eq 0 ]; then
    printf "Nothing to clone from: no repos/core.txt, and no repos/<profile>.txt for this\nmachine. Add repos to a list under repos/ or name a file:  ./clone-repos.sh <file>\n"
    exit 1
fi

# owner/repo out of any of the three notations; empty if unrecognizable
repo_slug() {
    printf '%s' "$1" \
        | sed -e 's/\.git$//' \
              -e 's|^git@github\.com:||' \
              -e 's|^ssh://git@github\.com/||' \
              -e 's|^https\{0,1\}://github\.com/||' \
        | grep -E '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
}

CLONED=0; SKIPPED=0; FAILED=""
clone_one() { # url [group-dir]
    local url="$1" dest="${2:-}" slug name
    url="${url%/}"   # a pasted URL may carry a trailing slash
    slug="$(repo_slug "$url")"
    if [ -z "$slug" ]; then
        warn "cannot read '$url' as a GitHub repo (ssh, https, or owner/repo) — skipping"
        FAILED="$FAILED$url, "
        return
    fi
    name="${slug#*/}"
    # the group heading names the directory cloned INTO: plain names live
    # under ~/Code, ~/… and absolute paths are taken as written
    case "$dest" in
        '')     dest="$CODE_DIR" ;;
        '~'/*)  dest="$HOME/${dest#'~'/}" ;;
        /*)     ;;
        *)      dest="$CODE_DIR/$dest" ;;
    esac
    dest="$dest/$name"
    if [ -d "$dest/.git" ]; then
        ok "$slug — already cloned ($dest)"
        SKIPPED=$((SKIPPED+1))
        return
    fi
    if [ -e "$dest" ]; then
        warn "$slug — $dest exists but is not a git repo; move it aside and re-run"
        FAILED="$FAILED$slug, "
        return
    fi
    # whatever notation the list used, clone over ssh (your keys and their
    # agent apply); https is only the fallback for when ssh cannot work here
    if [ "$DRY_RUN" = true ]; then
        info "would run: git clone git@github.com:$slug.git $dest  (https fallback if ssh fails)"
        return
    fi
    info "cloning $slug -> $dest"
    if git clone "git@github.com:$slug.git" "$dest"; then
        CLONED=$((CLONED+1))
    elif { warn "ssh failed for $slug — retrying over https"
           git clone "https://github.com/$slug.git" "$dest"; }; then
        CLONED=$((CLONED+1))
    else
        warn "$slug failed over ssh and https — see git's messages above"
        FAILED="$FAILED$slug, "
    fi
}

printf "\n%s┌─ repos%s%s\n" "$BOLD" "$([ "$DRY_RUN" = true ] && echo " (dry run)")" "$RESET"
for f in "${FILES[@]}"; do
    printf "%s│%s  %s%s%s\n" "$BOLD" "$RESET" "$DIM" "$f" "$RESET"
done
printf "%s└─%s\n" "$BOLD" "$RESET"

# bin/outline does the parsing (nesting, comments, strictness checks) and
# prints group<TAB>repo pairs. Parsing the whole list happens HERE, before
# any clone: a malformed file stops the run with nothing half-done.
if ! PARSED="$("$SCRIPT_DIR/bin/outline" "${FILES[@]}")"; then
    printf "%s✗ could not parse the list (see above) — nothing was cloned%s\n" "$RED" "$RESET"
    exit 1
fi
TAB="$(printf '\t')"
while IFS= read -r pline; do
    # split on the TAB by hand: `IFS=tab read` counts tab as whitespace and
    # swallows the empty group field of a top-level repo
    case "$pline" in *"$TAB"*) ;; *) continue ;; esac
    GROUP="${pline%%"$TAB"*}"
    url="${pline#*"$TAB"}"
    [ -z "$url" ] && continue
    clone_one "$url" "$GROUP"
done <<EOF
$PARSED
EOF

printf "\n"
if [ -n "$FAILED" ]; then
    printf "%s%s✗ some repos could not be cloned:%s %s\n" "$BOLD" "$RED" "$RESET" "${FAILED%, }"
    info "fix the cause (auth? typo in the list?) and re-run — done repos are skipped"
    exit 1
fi
if [ "$DRY_RUN" = true ]; then info "dry run — nothing was changed"; exit 0; fi
info "$CLONED cloned, $SKIPPED already present"
