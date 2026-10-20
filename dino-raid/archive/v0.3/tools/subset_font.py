# -*- coding: utf-8 -*-
"""Cuts Noto Serif SC (思源宋体) down to the characters dino-raid says.

    python dino-raid/tools/subset_font.py

The whole face is 25 MB, every character in the language; the game uses a few hundred. This reads every
character in the game's scripts (scripts/*.gd), adds Latin and the punctuation a line may carry, and cuts
from the whole face (kept out of the repository in dino-td/tools/font_sources/, git-ignored) just those,
with its weight axis kept from regular to black, into assets/fonts/NotoSerifSC-Raid.ttf.

Run it again after adding a string with a character the cut face lacks (the game would fall back to the
system's face for it). Needs fontTools (pip install fonttools).
"""
import glob
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SOURCE = os.path.join(GAME, "..", "dino-td", "tools", "font_sources", "NotoSerifSC-VF.ttf")
OUT = os.path.join(GAME, "assets", "fonts", "NotoSerifSC-Raid.ttf")
WEIGHTS = (400, 900)
ALWAYS = "".join(chr(c) for c in range(0x20, 0x7F)) + "，。、：；！？（）《》「」『』“”‘’—…·×←→↑↓％＋－" + "字"


def characters() -> str:
    seen = set(ALWAYS)
    for path in glob.glob(os.path.join(GAME, "scripts", "*.gd")):
        with open(path, encoding="utf-8") as f:
            seen.update(f.read())
    return "".join(sorted(c for c in seen if not c.isspace() or c == " "))


def main() -> int:
    if not os.path.exists(SOURCE):
        print("The whole face is not here: %s" % SOURCE)
        return 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    font = TTFont(SOURCE)
    options = subset.Options()
    options.layout_features = ["*"]
    options.hinting = False
    options.name_IDs = ["*"]
    options.notdef_outline = True
    sub = subset.Subsetter(options)
    chars = characters()
    sub.populate(text=chars)
    sub.subset(font)
    font = instancer.instantiateVariableFont(font, {"wght": WEIGHTS})
    font.save(OUT)
    print("[OK] %s: %d characters, %d KB" % (OUT, len(chars), os.path.getsize(OUT) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
