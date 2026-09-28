#!/usr/bin/env bash
# Exports a commit of the game (default HEAD) to a local folder, with the import cache and
# debug-agent's current tools, so a task can be tested at the commit the dev named even while the
# working tree is mid-edit (it happened: an uncommitted class_name broke loading). Writes nothing in
# the repo or .git -- git archive only reads.
#
#   bash debug-agent/tools/snapshot.sh [commit] [dest]      -> prints the folder
#   then: GODOT_PROJECT=<folder> bash debug-agent/tools/run_check.sh ...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REV="${1:-HEAD}"
DEST="${2:-${DA_SNAPSHOT_DIR:-$HOME/AppData/Local/Temp/da-snapshot}/$(git -C "$ROOT" rev-parse --short "$REV")}"
if [ ! -f "$DEST/project.godot" ]; then
  mkdir -p "$DEST"
  git -C "$ROOT" archive "$REV" | tar -x -C "$DEST"
  # The import cache: without it the first run re-imports every model and texture.
  [ -d "$ROOT/.godot" ] && cp -r "$ROOT/.godot" "$DEST/.godot"
fi
# Always the current tools, not the ones the commit carried.
mkdir -p "$DEST/debug-agent/tools" "$DEST/debug-agent/runs"
cp "$ROOT"/debug-agent/tools/*.gd "$ROOT"/debug-agent/tools/*.sh "$DEST/debug-agent/tools/" 2>/dev/null || true
touch "$DEST/debug-agent/runs/.gdignore"
echo "$DEST"
