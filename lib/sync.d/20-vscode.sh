# VS Code extensions — vscode/extensions.txt is just the output of
# `code --list-extensions`, so syncing is a straight rewrite.

vscode_label() { echo "VS Code extensions"; }

vscode_detect() {
    command -v code >/dev/null 2>&1 || { in_sync "code not on PATH"; return 0; }
    code --list-extensions 2>/dev/null | sort > "$TMP/ext_live.txt"
    sort "$SCRIPT_DIR/vscode/extensions.txt" > "$TMP/ext_repo.txt"
    comm -23 "$TMP/ext_live.txt" "$TMP/ext_repo.txt" > "$TMP/ext_add.txt"
    comm -13 "$TMP/ext_live.txt" "$TMP/ext_repo.txt" > "$TMP/ext_rem.txt"
    EXT_ADD=$(awk 'END{print NR}' "$TMP/ext_add.txt")
    EXT_REM=$(awk 'END{print NR}' "$TMP/ext_rem.txt")
    if [ "$EXT_ADD" -gt 0 ] || [ "$EXT_REM" -gt 0 ]; then
        drift "$EXT_ADD added, $EXT_REM removed"
    else
        in_sync
    fi
}

vscode_report() {
    printf "%sVS Code extensions%s\n" "$BOLD" "$RESET"
    while IFS= read -r l; do [ -n "$l" ] && printf "      %s+ %s%s\n" "$GREEN" "$l" "$RESET"; done < "$TMP/ext_add.txt"
    while IFS= read -r l; do [ -n "$l" ] && printf "      %s- %s%s\n" "$RED" "$l" "$RESET"; done < "$TMP/ext_rem.txt"
}

vscode_apply() {
    code --list-extensions 2>/dev/null | sort > "$SCRIPT_DIR/vscode/extensions.txt"
    ok "rewrote vscode/extensions.txt"
}
