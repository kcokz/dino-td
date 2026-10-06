"""Copies common/ into a game, so that game's Godot can open it as res://common/.

    python common/sync.py dino-raid

Windows Godot cannot follow a WSL symlink, so a game cannot just point at ../common: it gets a
copy, which git ignores. common/ stays the original -- edit there, then sync.

What goes across: common/assets/ and common/scripts/. The rest of common/ (tools/, scripts-draft/,
this file) is for people, not for a game.

Two kinds of file flow the other way, game copy -> common/, because Godot writes them:
  *.import  how a model, sound or picture is imported (the editor's import dock edits these)
  *.uid     a script's or shader's id
So a new import setting made in the game's editor comes back to common/ and the next game gets it.

Anything else changed or added inside the copy is somebody's edit in the wrong place: the sync
lists those files and stops, touching nothing. Move the edit into common/ and sync again, or pass
--force to throw it away.
"""
import argparse
import json
import os
import shutil
import sys

COMMON = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(COMMON)
PARTS = ("assets", "scripts")
MANIFEST = ".sync.json"
GODOT_OWNED = (".import", ".uid")


def files_under(root):
    """{relative path with / : (size, mtime_ns)} of every file in the synced parts."""
    found = {}
    for part in PARTS:
        for d, _, names in os.walk(os.path.join(root, part)):
            for n in names:
                p = os.path.join(d, n)
                st = os.stat(p)
                found[os.path.relpath(p, root).replace(os.sep, "/")] = (st.st_size, st.st_mtime_ns)
    return found


def owner_of(rel):
    """The file an .import or .uid belongs to: hero.glb.import -> hero.glb."""
    return rel.rsplit(".", 1)[0]


def read(path):
    with open(path, "rb") as f:
        return f.read()


def copy(src_root, dst_root, rel):
    dst = os.path.join(dst_root, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(os.path.join(src_root, rel), dst)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("game", help="the game's folder at the repository root, e.g. dino-raid")
    ap.add_argument("--force", action="store_true", help="overwrite edits made inside the copy")
    args = ap.parse_args()

    game = os.path.join(REPO, args.game)
    if not os.path.isfile(os.path.join(game, "project.godot")):
        sys.exit("sync: %s is not a Godot project (no project.godot)" % game)
    dst_root = os.path.join(game, "common")
    os.makedirs(dst_root, exist_ok=True)

    manifest_path = os.path.join(dst_root, MANIFEST)
    last = {}
    if os.path.isfile(manifest_path):
        with open(manifest_path, encoding="utf-8") as f:
            last = {k: tuple(v) for k, v in json.load(f).items()}

    src = files_under(COMMON)
    dst = files_under(dst_root)

    # 1. What happened in the copy since the last sync.
    back, wrong, settled = [], [], set()
    for rel, stat in sorted(dst.items()):
        if rel.endswith(GODOT_OWNED):
            if owner_of(rel) not in src or (rel in src and stat == src[rel]):
                continue
            if rel in src and read(os.path.join(dst_root, rel)) == read(os.path.join(COMMON, rel)):
                settled.add(rel)  # Godot rewrote it word for word: leave both alone
            else:
                back.append(rel)
        elif rel in last:
            if stat != last[rel]:
                wrong.append("changed in the copy: " + rel)
        elif rel not in src:
            wrong.append("added in the copy:   " + rel)
    if wrong and not args.force:
        print("sync: stopped, nothing touched. These were edited inside %s/common/ instead of common/:" % args.game)
        for w in wrong:
            print("  " + w)
        print("Move the edits into common/ and sync again, or pass --force to discard them.")
        sys.exit(1)

    for rel in back:
        copy(dst_root, COMMON, rel)
    src = files_under(COMMON)

    # 2. common/ -> the copy.
    sent = 0
    for rel, stat in src.items():
        if dst.get(rel) != stat and rel not in back and rel not in settled:
            copy(COMMON, dst_root, rel)
            sent += 1
    gone = 0
    for rel in dst:
        if rel not in src:
            os.remove(os.path.join(dst_root, rel))
            gone += 1

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(files_under(dst_root), f, indent=0, sort_keys=True)
    print("sync %s: %d copied in, %d removed, %d Godot import/uid files kept back into common/"
          % (args.game, sent, gone, len(back)))
    for rel in back:
        print("  kept: " + rel)


if __name__ == "__main__":
    main()
