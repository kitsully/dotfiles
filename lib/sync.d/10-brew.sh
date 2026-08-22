# Homebrew packages — compared against the core Brewfile plus the profile
# this machine actually uses, so the other profile's apps are not reported
# as missing here.

brew_label() { echo "Homebrew packages"; }

brew_detect() {
    command -v brew >/dev/null 2>&1 || { in_sync "brew not found"; return 0; }

    _entries() { grep -hE '^(tap|brew|cask|mas) ' "$@" 2>/dev/null | awk -F'#' '{print $1}' | awk '{$1=$1};1'; }
    # key<TAB>original. mas apps are keyed by id — the display name brew reports
    # ("CARROTweather") often differs from the one in the Brewfile ("CARROT Weather").
    _keyed() {
        awk '{ line=$0
               if ($0 ~ /^mas /) { match($0, /id: [0-9]+/); key = "mas " substr($0, RSTART, RLENGTH) }
               else key = $0
               print key "\t" line }' | sort -u -t"$(printf '\t')" -k1,1
    }
    _lookup() { awk -F'\t' 'NR==FNR{want[$0]=1;next} want[$1]{print $2}' "$1" "$2"; }

    brew bundle dump --file=- 2>/dev/null | grep -E '^(tap|brew|cask|mas) ' \
        | awk -F'#' '{print $1}' | awk '{$1=$1};1' | _keyed > "$TMP/live_kv.txt"
    _entries "$SCRIPT_DIR/Brewfile" "$SCRIPT_DIR/Brewfile.$PROFILE" | _keyed > "$TMP/tracked_kv.txt"
    cut -f1 "$TMP/live_kv.txt"    | sort -u > "$TMP/live_k.txt"
    cut -f1 "$TMP/tracked_kv.txt" | sort -u > "$TMP/tracked_k.txt"
    comm -23 "$TMP/live_k.txt" "$TMP/tracked_k.txt" > "$TMP/added_k.txt"
    comm -13 "$TMP/live_k.txt" "$TMP/tracked_k.txt" > "$TMP/removed_k.txt"
    _lookup "$TMP/added_k.txt"   "$TMP/live_kv.txt"    > "$TMP/added.txt"
    _lookup "$TMP/removed_k.txt" "$TMP/tracked_kv.txt" > "$TMP/removed.txt"

    BREW_ADD=$(awk 'END{print NR}' "$TMP/added.txt")
    BREW_REM=$(awk 'END{print NR}' "$TMP/removed.txt")
    if [ "$BREW_ADD" -gt 0 ]; then
        drift "$BREW_ADD to add, $BREW_REM not installed here"
    elif [ "$BREW_REM" -gt 0 ]; then
        in_sync "in sync ($BREW_REM not installed here)"
    else
        in_sync
    fi
}

brew_report() {
    printf "%sNew packages%s\n" "$BOLD" "$RESET"
    while IFS= read -r l; do [ -n "$l" ] && printf "      %s+ %s%s\n" "$GREEN" "$l" "$RESET"; done < "$TMP/added.txt"
    if [ "${BREW_REM:-0}" -gt 0 ]; then
        printf "  %stracked but not installed here — left alone:%s\n" "$DIM" "$RESET"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s- %s%s\n" "$DIM" "$l" "$RESET"; done < "$TMP/removed.txt"
    fi
}

# Only ever adds. Entries tracked but not installed are left alone — on a
# fresh machine that just means you have not installed them yet.
brew_apply() {
    [ -s "$TMP/added.txt" ] || return 0
    local target="$SCRIPT_DIR/Brewfile.$PROFILE"
    if [ "$INTERACTIVE" = true ]; then
        printf "      %s1%s  Brewfile           %s(every machine)%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
        printf "      %s2%s  Brewfile.%-9s %s(this machine only)%s\n" "$BOLD" "$RESET" "$PROFILE" "$DIM" "$RESET"
        printf "  %s?%s Where do these go? %s[2]%s " "$BOLD" "$RESET" "$DIM" "$RESET"
        read -r pick || pick=""
        [ "$pick" = 1 ] && target="$SCRIPT_DIR/Brewfile"
    fi
    printf "\n# --- added by sync.sh ---\n" >> "$target"
    cat "$TMP/added.txt" >> "$target"
    ok "appended $BREW_ADD entries to $(basename "$target")"
}
