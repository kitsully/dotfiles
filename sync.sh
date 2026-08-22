#!/bin/bash
# Fold this machine's current state back into the repo, then commit.
#
# Symlinked configs (zsh, git, nvim, ...) already show up in `git status`
# on their own. This is for the things that do not, because they live
# outside the repo and drift silently.
#
# There are no targets hard-coded here: each one is a file in lib/sync.d/.
# See lib/sync.d/README.md to add another.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COLS=66
. "$SCRIPT_DIR/lib/ui.sh"

PROFILE=""
DRY_RUN=false
ASSUME_YES=false
DO_COMMIT=true

usage() {
    cat <<USAGE
${BOLD}Dotfiles Sync${RESET} — bring the repo back in line with this machine

  ${BOLD}./sync.sh${RESET}              pick what to fold in, then commit
  ${BOLD}./sync.sh --dry-run${RESET}    show what drifted and stop

${BOLD}Flags${RESET}
  --personal | --work    which profile this machine uses (default: guessed)
  -n, --dry-run          report only; change nothing
  -y, --yes              accept the defaults, no questions
      --no-commit        update the files but do not commit
  -h, --help             this message
USAGE
    exit "${1:-1}"
}

for arg in "$@"; do
    case "$arg" in
        --work)       PROFILE=work ;;
        --personal)   PROFILE=personal ;;
        -n|--dry-run) DRY_RUN=true ;;
        -y|--yes)     ASSUME_YES=true ;;
        --no-commit)  DO_COMMIT=false ;;
        -h|--help)    usage 0 ;;
        *) printf "%sError:%s unknown flag '%s'\n\n" "$RED" "$RESET" "$arg"; usage ;;
    esac
done

INTERACTIVE=true
{ [ "$ASSUME_YES" = true ] || [ ! -t 0 ] || [ ! -t 1 ]; } && INTERACTIVE=false

[ -z "$PROFILE" ] && { [ -d "/Applications/Setapp.app" ] && PROFILE=personal || PROFILE=work; }

TMP="${TMPDIR:-/tmp}/dotfiles-sync.$$"
mkdir -p "$TMP"
# also restores the cursor: this replaces the trap lib/ui.sh set
trap 'rm -rf "$TMP"; printf "\033[?25h"' EXIT INT TERM

# ─── Load the targets ───────────────────────────────────────────────────
TARGETS=""
for f in "$SCRIPT_DIR"/lib/sync.d/*.sh; do
    [ -f "$f" ] || continue
    . "$f"
    key="$(basename "$f" .sh)"; key="${key#*-}"
    TARGETS="$TARGETS $key"
done

if [ -z "$TARGETS" ]; then
    printf "%sError:%s no sync targets found in lib/sync.d/\n" "$RED" "$RESET"; exit 1
fi

# What a target's _detect calls to say how it went. CURRENT is set by the
# driver so targets do not have to name themselves.
CURRENT=""
drift()   { _v="$1"; eval "${CURRENT}_DRIFT=yes"; eval "${CURRENT}_DETAIL=\$_v"; }
in_sync() { _v="${1:-in sync}"; eval "${CURRENT}_DRIFT=no"; eval "${CURRENT}_DETAIL=\$_v"; }
getvar()  { eval "printf '%s' \"\${$1:-}\""; }

sync_label()   { ${1}_label; }
sync_detail()  { getvar "${1}_DETAIL"; }
sync_drifted() { [ "$(getvar "${1}_DRIFT")" = yes ]; }
has_fn()       { type "$1" >/dev/null 2>&1; }

# Every target must be able to describe, detect and apply itself.
for t in $TARGETS; do
    for fn in "${t}_label" "${t}_detect" "${t}_apply"; do
        has_fn "$fn" || { printf "%sError:%s lib/sync.d/*%s.sh does not define %s()\n" "$RED" "$RESET" "$t" "$fn"; exit 1; }
    done
done

banner "Dotfiles Sync" "$PROFILE profile$([ "$DRY_RUN" = true ] && echo ' · dry run')"
printf "\n"

# ─── Detect ─────────────────────────────────────────────────────────────
spin_start "checking what changed on this machine"
for t in $TARGETS; do
    CURRENT="$t"
    in_sync
    "${t}_detect"
done
spin_stop

DRIFTED=""
for t in $TARGETS; do sync_drifted "$t" && DRIFTED="$DRIFTED $t"; done

# ─── Report ─────────────────────────────────────────────────────────────
for t in $DRIFTED; do
    if has_fn "${t}_report"; then "${t}_report"; printf "\n"; fi
done

cd "$SCRIPT_DIR" || exit 1
GIT_DIRTY="$(git status --porcelain 2>/dev/null)"
if [ -n "$GIT_DIRTY" ]; then
    printf "%sAlready modified in the repo%s\n" "$BOLD" "$RESET"
    printf "%s\n" "$GIT_DIRTY" | while IFS= read -r l; do printf "      %s%s%s\n" "$DIM" "$l" "$RESET"; done
    printf "\n"
fi

if [ -z "$DRIFTED" ] && [ -z "$GIT_DIRTY" ]; then
    rule; ok "Everything is already in sync."; printf "\n"; exit 0
fi
if [ "$DRY_RUN" = true ]; then
    rule; warn "Dry run — nothing was changed."; printf "\n"; exit 0
fi

# ─── Choose ─────────────────────────────────────────────────────────────
SELECTED=""
if [ -n "$DRIFTED" ]; then
    printf "%sWhat should I fold into the repo?%s\n" "$BOLD" "$RESET"
    checkbox_menu "$TARGETS" sync_label sync_detail sync_drifted
    SELECTED="$CB_SELECTED"
fi

# ─── Apply ──────────────────────────────────────────────────────────────
TOTAL=0; for t in $SELECTED; do TOTAL=$((TOTAL+1)); done
IDX=0
for t in $SELECTED; do
    IDX=$((IDX+1))
    step_header "$IDX" "$TOTAL" "$(sync_label "$t")"
    "${t}_apply" || bad "$(sync_label "$t") failed"
    progress "$IDX" "$TOTAL"
done

# ─── Commit ─────────────────────────────────────────────────────────────
printf "\n"; rule
if [ "$DO_COMMIT" = false ]; then
    info "--no-commit given; review with: git diff"; printf "\n"; exit 0
fi
if [ -z "$(git status --porcelain)" ]; then
    ok "Nothing to commit."; printf "\n"; exit 0
fi

printf "\n%sReady to commit%s\n\n" "$BOLD" "$RESET"
git status --short | while IFS= read -r l; do printf "      %s%s%s\n" "$DIM" "$l" "$RESET"; done
printf "\n"

if ask_yn "Commit these changes?" Y; then
    MSG="Sync dotfiles from $(hostname -s)"
    if [ "$INTERACTIVE" = true ]; then
        printf "  %s?%s Message %s[%s]%s " "$BOLD" "$RESET" "$DIM" "$MSG" "$RESET"
        read -r custom || custom=""
        [ -n "$custom" ] && MSG="$custom"
    fi
    git add -A && git commit -q -m "$MSG" && ok "committed: $(git log -1 --format=%h) $MSG"
    printf "\n"
    if ask_yn "Push to origin?" N; then git push && ok "pushed"; else info "not pushed — run: git push"; fi
else
    info "left uncommitted"
fi
printf "\n"
