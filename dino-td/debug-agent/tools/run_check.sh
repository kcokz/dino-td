#!/usr/bin/env bash
# One agent check, read-only on the game: everything it writes lands in debug-agent/runs/<stamp>/.
#
#   bash debug-agent/tools/run_check.sh [tests] [smoke] [play:<min>] [scenario ...]
#
# No args = tests smoke play:20 probe:all. Any other word is passed to the bot as a playtest scenario
# (open, cabin, raid, beacon, ui, kit, paused, siege:..., see tools/playtest.gd _run()).
# probe:<name> runs one of debug-agent/tools/probe.gd's own checks (probe:all runs every one).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-/c/Users/jobzk/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe}"
# GODOT_PROJECT: run against another copy of the game (tools/snapshot.sh), output still lands here.
PROJ="${GODOT_PROJECT:-$ROOT}"
PROJ_W="$(cygpath -m "$PROJ" 2>/dev/null || echo "$PROJ")"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="debug-agent/runs/$STAMP"
mkdir -p "$OUT"
echo "$STAMP" > debug-agent/runs/LATEST
if [ "$PROJ" = "$ROOT" ]; then git rev-parse --short HEAD > "$OUT/commit.txt"; git status --short >> "$OUT/commit.txt"; else echo "snapshot $PROJ" > "$OUT/commit.txt"; fi
# Frames by absolute path, so a snapshot's run still writes here.
ABS_OUT="$(cygpath -m "$ROOT/$OUT" 2>/dev/null || echo "$ROOT/$OUT")"

# The game's own telemetry (TwitchWatch, since 7c86862) lands in Godot's user dir: every report
# file written during this run is copied into the run's folder at the end.
TELEMETRY="${APPDATA:-$HOME/AppData/Roaming}/Godot/app_userdata/dino/telemetry"
touch "$OUT/.started"
args=("$@"); [ ${#args[@]} -eq 0 ] && args=(tests smoke play:20 probe:all)
scen=()
for a in "${args[@]}"; do
  case "$a" in
    tests)
      echo "== tests"; timeout 1500 "$GODOT" --headless --path "$PROJ_W" --script res://tests/test_runner.gd > "$OUT/tests.log" 2>&1
      echo "exit $?" >> "$OUT/tests.log"
      grep -E "ALL TESTS PASSED|FAIL|passed|failed" "$OUT/tests.log" | tail -5
      echo "SCRIPT ERROR count: $(grep -c 'SCRIPT ERROR' "$OUT/tests.log")";;
    smoke)
      echo "== smoke"; timeout 300 "$GODOT" --headless --path "$PROJ_W" --quit-after 400 > "$OUT/smoke.log" 2>&1
      echo "errors: $(grep -cE 'ERROR|SCRIPT ERROR' "$OUT/smoke.log")";;
    probe:*)
      echo "== probe ${a#probe:}"
      DA_OUT="$ABS_OUT/probe" timeout 900 "$GODOT" --path "$PROJ_W" --resolution 1600x900 --script res://debug-agent/tools/probe.gd -- ${a#probe:} > "$OUT/probe-${a#probe:}.log" 2>&1
      grep -E '^\[probe\] [a-z_]+ (PASS|FAIL|INFO)|SCRIPT ERROR' "$OUT/probe-${a#probe:}.log";;
    *) scen+=("$a");;
  esac
done
if [ ${#scen[@]} -gt 0 ]; then
  bash "$ROOT/debug-agent/tools/sync_harness.sh" "$PROJ" >/dev/null
  echo "== bot: ${scen[*]}"
  DA_OUT="$ABS_OUT/shots" timeout 3600 "$GODOT" --path "$PROJ_W" --resolution 1600x900 --script res://debug-agent/tools/agent_play.gd -- "${scen[@]}" > "$OUT/bot.log" 2>&1
  echo "exit $?" >> "$OUT/bot.log"
  echo "frames: $(ls "$OUT/shots" 2>/dev/null | grep -c png)  errors: $(grep -cE 'SCRIPT ERROR|^ERROR' "$OUT/bot.log")  stuck/gave-up: $(grep -cE 'STUCK|gave up' "$OUT/bot.log")"
fi
if [ -d "$TELEMETRY" ]; then
  mkdir -p "$OUT/telemetry"
  # Only this agent's launches: the dev's own playtest runs write to the same folder.
  for f in $(find "$TELEMETRY" -name '*.jsonl' -newer "$OUT/.started" 2>/dev/null); do
    head -c 400 "$f" | grep -q 'debug-agent' && cp "$f" "$OUT/telemetry/"
  done
  python "$ROOT/debug-agent/tools/twitch_summary.py" "$OUT/telemetry" > "$OUT/twitch.txt" 2>&1 && head -1 "$OUT/twitch.txt"
fi
echo "run dir: $OUT"
