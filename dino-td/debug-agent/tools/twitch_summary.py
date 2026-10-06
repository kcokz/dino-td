"""Summarises TwitchWatch report files (one JSON object per line; the first is the launch header).

    python debug-agent/tools/twitch_summary.py <dir or .jsonl files...>

Prints the count by kind and one line per report: number, kind, species, where, mode, target,
and the window's figures -- enough to find it again in a screenshot or a log.
"""
import json, sys, glob, os, collections

paths = []
for a in sys.argv[1:]:
    paths += sorted(glob.glob(os.path.join(a, "*.jsonl"))) if os.path.isdir(a) else [a]
reports = []
for p in paths:
    with open(p, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except ValueError:
                continue
            # A report has "n" and "kind" at the top; the first line is the launch header.
            if isinstance(r, dict) and "n" in r and isinstance(r.get("kind"), str):
                r["_file"] = os.path.basename(p)
                reports.append(r)
kinds = collections.Counter(r["kind"] for r in reports)
print("twitch reports: %d  %s" % (len(reports), " ".join("%s %d" % kv for kv in sorted(kinds.items()))))
for r in reports:
    d = r.get("dino", {})
    g = r.get("game", {})
    tgt = d.get("target") or {}
    pos = d.get("pos", ["?", "?", "?"])
    w = r.get("window", {})
    press = d.get("pressed") or {}
    pb = (press.get("building") or {}).get("type", "-") if isinstance(press, dict) else "-"
    print("  #%-3s %-7s %-12s at (%5.1f,%5.1f) %-7s -> %-12s wave %s clock %6.1f | %s s: jitter %s shake %s flicker %s dither %s path %s net %s | pressed: %s bodies, %s" % (
        r["n"], r["kind"], d.get("species", "?"), float(pos[0]), float(pos[2]), d.get("mode", "?"), tgt.get("type", "-"),
        g.get("wave", "?"), float(g.get("day_clock", 0)), w.get("seconds"), w.get("jitter"), w.get("shake"),
        w.get("flicker"), w.get("dither"), w.get("path"), w.get("net"), press.get("bodies", "?") if isinstance(press, dict) else "?", pb))
