# iTerm2 profile. The repo copy is a *dynamic* profile, so it carries its own
# Guid and name — iTerm2 refuses to load a dynamic profile that reuses the Guid
# of a real one. Only the settings are tracked.

iterm2_label() { echo "iTerm2 profile"; }

ITERM_FILE_PATH=""

iterm2_detect() {
    ITERM_FILE_PATH="$SCRIPT_DIR/iterm2/Default.json"
    local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    [ -f "$plist" ] && command -v plutil >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 \
        || { in_sync "iTerm2 plist not readable"; return 0; }
    plutil -extract "New Bookmarks" json -o "$TMP/iterm_live.json" "$plist" 2>/dev/null \
        || { in_sync "no profiles in the plist"; return 0; }

    local verdict
    verdict="$(DEFAULT_GUID="$(defaults read com.googlecode.iterm2 'Default Bookmark Guid' 2>/dev/null)" \
        python3 - "$TMP/iterm_live.json" "$ITERM_FILE_PATH" "$TMP/iterm_new.json" <<'PYEOF'
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
# compare semantically: plutil emits ints where the repo copy has floats
print("SAME" if repo == [norm] else "DIFF")
PYEOF
)"
    [ "$verdict" = DIFF ] && drift "profile changed" || in_sync
}

iterm2_apply() {
    # write atomically: iTerm2 watches this file and would read a half-written
    # copy as invalid JSON
    cp "$TMP/iterm_new.json" "$ITERM_FILE_PATH.tmp" && mv -f "$ITERM_FILE_PATH.tmp" "$ITERM_FILE_PATH"
    ok "rewrote iterm2/Default.json"
}
