# -*- coding: utf-8 -*-
"""Cuts the Chinese title face down to the characters the game says.

    python tools/subset_fonts.py

Titles, names and buttons are set in Cinzel, whose letters are Latin only; Chinese falls
back to Noto Serif SC (思源宋体), the inscriptional serif that goes with it. That face is
25 MB with every character in the language -- too big to ship for the few hundred the game
uses. So it is kept out of the repository (tools/font_sources/, git-ignored) and this cuts
from it just the characters in translations/strings.csv, with Latin and the punctuation a
line may carry, into assets/fonts/NotoSerifSC-Title.ttf, keeping its weight axis between
the weights the titles use.

Add a string with a character the cut face lacks and test_v06_the_face says so: run this
again. Without the source it stops and says where to get it.

Needs fontTools (pip install fonttools).
"""
import csv
import io
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SOURCE = os.path.join(ROOT, "tools", "font_sources", "NotoSerifSC-VF.ttf")
SOURCE_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf"
STRINGS = os.path.join(ROOT, "translations", "strings.csv")
OUT = os.path.join(ROOT, "assets", "fonts", "NotoSerifSC-Title.ttf")

# The weights the titles are set at (UiTheme: a heading is semibold, a title black), so the
# cut face keeps its axis only between them.
WEIGHTS = (600, 900)
# Latin, and the punctuation a Chinese line uses beside what the strings hold today, so a
# new line of the same kind is covered before this is run again.
ALWAYS = "".join(chr(c) for c in range(0x20, 0x7F)) + "，。、：；！？（）《》「」『』“”‘’—…·×←→↑↓％＋－"
# And the character the engine tries a face with before it will set Han in it (ICU's sample
# for the script): without it the cut is taken for a face that has no Chinese at all, and
# every title falls through to the system's -- whatever else it holds.
SCRIPT_SAMPLES = "字"


def characters() -> str:
    seen = set(ALWAYS) | set(SCRIPT_SAMPLES)
    with io.open(STRINGS, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            for cell in row[1:]:
                seen.update(cell)
    return "".join(sorted(c for c in seen if not c.isspace() or c == " "))


def main() -> int:
    # The whole face is for cutting from, not for the game: the editor is kept from importing it.
    ignore = os.path.join(os.path.dirname(SOURCE), ".gdignore")
    if os.path.isdir(os.path.dirname(SOURCE)) and not os.path.exists(ignore):
        open(ignore, "w").close()
    if not os.path.exists(SOURCE):
        print("The source face is not here: %s\nGet it (SIL OFL) from %s" % (SOURCE, SOURCE_URL))
        return 1
    font = TTFont(SOURCE)
    options = subset.Options()
    options.layout_features = ["*"]
    options.hinting = False
    options.name_IDs = ["*"]
    options.notdef_outline = True
    sub = subset.Subsetter(options)
    chars = characters()
    sub.populate(text=chars)
    # Cut first, then narrow the axis: narrowing first leaves the variations table without
    # entries for glyphs it has no deltas for, and the cut trips over them.
    sub.subset(font)
    font = instancer.instantiateVariableFont(font, {"wght": WEIGHTS})
    font.save(OUT)
    print("[OK] %s: %d characters, %d KB" % (os.path.relpath(OUT, ROOT), len(chars), os.path.getsize(OUT) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
