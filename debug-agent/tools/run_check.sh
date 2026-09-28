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
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="debug-agent/runs/$STAMP"
mkdir -p "$OUT"
echo "$STAMP" > debug-agent/runs/LATEST
git rev-parse --short HEAD > "$OUT/commit.txt"; git status --short >> "$OUT/commit.txt"

args=("$@"); [ ${#args[@]} -eq 0 ] && args=(tests smoke play:20 probe:all)
scen=()
for a in "${args[@]}"; do
  case "$a" in
    tests)
      echo "== tests"; timeout 1500 "$GODOT" --headless --path . --script res://tests/test_runner.gd > "$OUT/tests.log" 2>&1
      echo "exit $?" >> "$OUT/tests.log"
      grep -E "ALL TESTS PASSED|FAIL|passed|failed" "$OUT/tests.log" | tail -5
      echo "SCRIPT ERROR count: $(grep -c 'SCRIPT ERROR' "$OUT/tests.log")";;
    smoke)
      echo "== smoke"; timeout 300 "$GODOT" --headless --path . --quit-after 400 > "$OUT/smoke.log" 2>&1
      echo "errors: $(grep -cE 'ERROR|SCRIPT ERROR' "$OUT/smoke.log")";;
    probe:*)
      echo "== probe ${a#probe:}"
      DA_OUT="res://$OUT/probe" timeout 900 "$GODOT" --path . --resolution 1600x900 --script res://debug-agent/tools/probe.gd -- ${a#probe:} > "$OUT/probe-${a#probe:}.log" 2>&1
      grep -E '^\[probe\] [a-z_]+ (PASS|FAIL|INFO)|SCRIPT ERROR' "$OUT/probe-${a#probe:}.log";;
    *) scen+=("$a");;
  esac
done
if [ ${#scen[@]} -gt 0 ]; then
  bash debug-agent/tools/sync_harness.sh >/dev/null
  echo "== bot: ${scen[*]}"
  DA_OUT="res://$OUT/shots" timeout 3600 "$GODOT" --path . --resolution 1600x900 --script res://debug-agent/tools/agent_play.gd -- "${scen[@]}" > "$OUT/bot.log" 2>&1
  echo "exit $?" >> "$OUT/bot.log"
  echo "frames: $(ls "$OUT/shots" 2>/dev/null | grep -c png)  errors: $(grep -cE 'SCRIPT ERROR|^ERROR' "$OUT/bot.log")  stuck/gave-up: $(grep -cE 'STUCK|gave up' "$OUT/bot.log")"
fi
echo "run dir: $OUT"
