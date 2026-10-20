# -*- coding: utf-8 -*-
"""Works out Content.LIMIT from tools/sim_runs.gd's calm runs (school ... limit), however many were run at once.

    godot --headless --path dino-raid --script res://tools/sim_runs.gd -- school 6 101 limit > runs_101.txt
    ... (more first seeds, each its own file)
    python dino-raid/tools/limit.py runs_*.txt

Each calm run prints its army's strength round by round ("# curve <school>: [...]"). This takes each school's
average, round by round, then the middle of the six (the median), so that one school growing far past the rest does
not make every wave too strong for the others; never less than the round before within a level (each level starts
again from what the ark set down). Prints each school's average at a few rounds, then the line to paste in.
"""
import re
import statistics
import sys
from collections import defaultdict

ROUNDS = 12                       # Content.ROUNDS


def main(paths):
    curves = defaultdict(list)
    for path in paths:
        for line in open(path, encoding="utf-8", errors="replace"):
            m = re.match(r"# curve (\S+): \[(.*)\]", line)
            if m:
                curves[m.group(1)].append([int(x) for x in m.group(2).split(",")])
    if not curves:
        sys.exit("no curves found: run sim_runs.gd with school ... limit")
    n = min(len(c) for cs in curves.values() for c in cs)
    means = {s: [sum(c[i] for c in cs) / len(cs) for i in range(n)] for s, cs in curves.items()}
    shown = [0, 1, 3, 7, 11]
    print("each school's average at rounds 1, 2, 4, 8, 12 of each level:")
    for s in sorted(means):
        print("  %-7s (%2d runs) %s" % (s, len(curves[s]), " | ".join(
            " ".join("%5d" % means[s][t * ROUNDS + r] for r in shown) for t in range(n // ROUNDS))))
    limit = []
    for i in range(n):
        mid = statistics.median(means[s][i] for s in means)
        if i % ROUNDS != 0:
            mid = max(mid, limit[-1])
        limit.append(round(mid))
    rows = [", ".join(str(v) for v in limit[t:t + ROUNDS]) for t in range(0, n, ROUNDS)]
    print("const LIMIT := [" + ",\n\t".join(rows) + "]")


if __name__ == "__main__":
    main(sys.argv[1:])
