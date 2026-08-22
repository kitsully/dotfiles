# Sync targets

One file per thing that can drift. `sync.sh` loads every `*.sh` here in name
order and works out the target's key from the filename: `20-vscode.sh` → `vscode`.
Adding a target means adding a file — there is no list to register it in.

Each file defines, where `<key>` is that name:

| Function | Required | Does |
|----------|----------|------|
| `<key>_label`  | yes | One-line name shown in the picker |
| `<key>_detect` | yes | Works out whether anything drifted, then calls `drift "..."` or `in_sync ["..."]` |
| `<key>_report` | no  | Prints the detail (what would be added/removed) |
| `<key>_apply`  | yes | Folds the change into the repo |

`_detect` runs before anything is printed, so it should be quiet. Put your
scratch files under `$TMP`, which is created and cleaned up for you.

Available: `$SCRIPT_DIR`, `$PROFILE` (`work`/`personal`), `$TMP`,
`$INTERACTIVE`, and everything in `lib/ui.sh` (`ok`, `warn`, `info`, colours).

A skeleton:

```bash
raycast_label()  { echo "Raycast settings"; }
raycast_detect() {
    command -v raycast >/dev/null 2>&1 || { in_sync "Raycast not installed"; return 0; }
    # ... compare live state with the repo copy ...
    drift "3 changed"      # or: in_sync
}
raycast_report() { printf "      %s+ something%s\n" "$GREEN" "$RESET"; }
raycast_apply()  { cp "$TMP/raycast_new" "$SCRIPT_DIR/raycast/settings"; ok "rewrote it"; }
```
