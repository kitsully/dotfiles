# 2026 M1 MBP work migration

One-off scripts for moving `~/code` (every project, git repos with `.git`
intact — remotes, branches, stashes, and uncommitted work all preserved),
`~/Desktop`, and `~/Documents` to the new M1 MBP by flash drive. Nothing
is re-cloned from GitHub: a full copy is a faithful mirror of whatever
state exists on migration day, needs no SSH setup first, and can't lose
local-only work the way a fresh clone can.

## The drive

~35GB of payload after cache excludes (Desktop ~8.5GB and Documents
~0.8GB included) — a 256GB drive has ample room. Format it **APFS,
encrypted** (Disk Utility), not exFAT: exFAT can't hold symlinks or exec
bits (which the copied git repos contain), and the drive carries `.env`
secrets and personal documents in plaintext — encryption is the backstop
if it's lost. `prep-flash-drive.sh` warns on a FAT-family drive but
doesn't refuse.

## Order of operations

1. **Old machine:** `./prep-flash-drive.sh` — copies everything in
   `full-dirs.txt` / `files.txt` onto the drive. macOS will prompt for
   Desktop/Documents access the first time — grant it, or those two copy
   as empty.
2. **New machine:** install dotfiles via its own `install.sh` /
   `setup.sh` (these scripts live in it), then run
   `./extract-flash-drive.sh` — copies everything into place under `~`.

Both scripts support `-n`/`--dry-run` to preview without writing
anything, are safe to re-run, and exit nonzero if anything failed — exit
0 means every listed item made it.

## Files

- `full-dirs.txt` — directories copied wholesale, relative to `~`:
  everything under `~/code` (except dotfiles, which arrives via its own
  install), plus `Desktop` and `Documents`. `node_modules`, `venv`/
  `.venv`, `__pycache__`, `.next`, `.cache`, `graphify-out`, and
  `.DS_Store` are excluded everywhere — regenerable, reinstall on the
  new machine.
- `files.txt` — standalone `.zip` archives sitting next to project
  directories.
- `prep-flash-drive.sh`, `extract-flash-drive.sh` — see above.

## Known leftovers

`~/code/work/ultra-oms-institutional` contains two stray untracked files
whose names look like pasted shell commands (`$ curl -u ksullivan@…:AKC.md`,
`docker login -u ….md`) — if that's a real token fragment, rotate it and
delete the files before migrating; they ride along in the wholesale copy
otherwise.
