# -*- coding: utf-8 -*-
"""Writes the interface's icons: assets/icons/<name>.svg, each with an import stub that
brings it in as a DPITexture -- drawn from the vector at whatever scale the screen asks for,
so a 20-pixel chip and a 48-pixel portrait are both crisp (UI-POLISH T17).

    python tools/build_icons.py

Two families, one geometry (a 64-unit square):

* ITEM icons -- resources, buildings, units, benches: flat colour with a dark rim. The
  rim is drawn by painting the silhouette once in the rim colour with a wide stroke and
  then the real shapes on top, so it runs round the outside of the whole object and never
  across its inside. It is what makes a pale bone and a dark rock read the same on a black
  panel and on the bright valley floor.
* GLYPH icons -- pause, build, repair...: white only, no rim. The theme tints them per
  button state; a glyph that carried colour of its own could not be tinted.

Every value is here and nowhere else; the game only knows the file names (Config.ICON_DIR).
"""
import io
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "icons")

RIM = "#16110c"
RIM_WIDTH = 5.0

C = {
    "bark": "#7b4a27", "grain": "#dca466", "ring": "#b87b42",
    "s1": "#d3d8da", "s2": "#adb4b8", "s3": "#8b9397", "s4": "#6b7378",
    "bone": "#efe6cf", "bone_shade": "#cdbf9b",
    "meat": "#c9533b", "meat_hi": "#ea8a6c", "meat_dark": "#983926",
    "prime": "#a62e28", "marble": "#eba594", "fat": "#f2dcc6", "gold": "#f2c14e",
    "roast": "#a65b27", "roast_hi": "#e0a25a", "roast_dark": "#6c3616", "grill": "#3e1d0b",
    "crackling": "#e9b765", "steam": "#f4eee4",
    "water": "#4aa6e2", "water_hi": "#b1e0f8",
    "post": "#a0703f", "post_dark": "#6f4523", "char": "#2e2019", "rope": "#dcbb7c",
    "hull": "#ebe8e1", "hull_shade": "#c4c0b6", "hazard": "#f28c28", "window": "#58c7e8",
    "skin": "#d9a67c", "hair": "#4b3322", "shirt": "#5d7c8d", "shirt_dark": "#445d6a",
    "claw": "#94512f",
    "leaf": "#64a24c", "leaf_dark": "#3f7334", "trunk": "#6e4a2a",
    "iron": "#5a6166", "iron_dark": "#3b4145", "fire": "#f28c28", "flame": "#f7cb4c",
    "metal": "#98a3aa", "cyan": "#58c7e8", "moss": "#6b9a45",
    "hide": "#a8743f", "hide_dark": "#7a4f28", "hide_hi": "#cf9f64",
    "resin": "#3a2616",
}


def _attrs(d):
    return " ".join('%s="%s"' % (k.replace("_", "-"), v) for k, v in d.items() if v is not None)


def shape(kind, fill=None, stroke=None, sw=None, transform=None, **geo):
    """One SVG element. `stroke` and its width `sw` make it a line rather than a filled area.
    (Not `width`: that is a rectangle's own attribute, and sharing the name swallowed it.)"""
    return {"kind": kind, "fill": fill, "stroke": stroke, "sw": sw, "transform": transform, "geo": geo}


def _element(s, fill, stroke, width):
    geo = dict(s["geo"])
    extra = {"fill": fill, "stroke": stroke, "stroke_width": width,
             "stroke_linejoin": "round" if stroke else None, "stroke_linecap": "round" if stroke else None,
             "transform": s["transform"]}
    if "fill_rule" in geo:
        extra["fill_rule"] = geo.pop("fill_rule")
    return "<%s %s %s/>" % (s["kind"], _attrs(geo), _attrs(extra))


def item_svg(body, detail=()):
    """Body shapes are rimmed as one silhouette; detail sits on top, unrimmed."""
    out = []
    for s in body:   # the rim: every body shape, wider, in one colour, underneath
        w = RIM_WIDTH * 2 + (s["sw"] or 0.0)
        out.append(_element(s, "none" if s["stroke"] else RIM, RIM, w))
    for s in list(body) + list(detail):
        if s["stroke"]:
            out.append(_element(s, "none", s["stroke"], s["sw"]))
        else:
            out.append(_element(s, s["fill"], None, None))
    return out


def glyph_svg(shapes):
    out = []
    for s in shapes:
        if s["stroke"]:
            out.append(_element(s, "none", "#ffffff", s["sw"]))
        else:
            out.append(_element(s, "#ffffff", None, None))
    return out


def star(cx, cy, r_out, r_in, points=5, rot=-90.0):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / points)
        pts.append("%.2f,%.2f" % (cx + r * math.cos(a), cy + r * math.sin(a)))
    return " ".join(pts)


ICONS = {}

# ------------------------------------------------------------------------------ resources
ICONS["wood"] = item_svg(
    [shape("circle", C["bark"], cx=20, cy=43, r=12.5), shape("circle", C["bark"], cx=44, cy=43, r=12.5),
     shape("circle", C["bark"], cx=32, cy=21.5, r=12.5)],
    [s for (x, y) in [(20, 43), (44, 43), (32, 21.5)] for s in (
        shape("circle", C["grain"], cx=x, cy=y, r=9),
        shape("circle", None, C["ring"], 1.8, cx=x, cy=y, r=5),
        shape("circle", C["ring"], cx=x, cy=y, r=1.5))])

ICONS["stone"] = item_svg(
    [shape("polygon", C["s3"], points="9,44 15,23 30,11 48,15 57,34 50,51 25,55")],
    [shape("polygon", C["s1"], points="15,23 30,11 33,28 20,37"),
     shape("polygon", C["s2"], points="30,11 48,15 57,34 33,28"),
     shape("polygon", C["s3"], points="9,44 15,23 20,37 25,55"),
     shape("polygon", C["s4"], points="25,55 20,37 33,28 57,34 50,51")])

_BONE = "rotate(-40 32 32)"
ICONS["bone"] = item_svg(
    [shape("rect", C["bone"], transform=_BONE, x=15, y=27.5, width=34, height=9, rx=4.5)]
    + [shape("circle", C["bone"], transform=_BONE, cx=x, cy=y, r=7.4) for (x, y) in [(15, 26), (15, 38), (49, 26), (49, 38)]],
    [shape("rect", C["bone_shade"], transform=_BONE, x=19, y=33, width=26, height=2.8, rx=1.4),
     shape("circle", C["bone_shade"], transform=_BONE, cx=13.5, cy=40.5, r=2.4),
     shape("circle", C["bone_shade"], transform=_BONE, cx=47.5, cy=40.5, r=2.4)])

_HANDLE = "rotate(45 44 44)"
ICONS["food"] = item_svg(
    [shape("rect", C["bone"], transform=_HANDLE, x=36, y=40.5, width=20, height=7, rx=3.5),
     shape("circle", C["bone"], transform=_HANDLE, cx=56, cy=40, r=5.4),
     shape("circle", C["bone"], transform=_HANDLE, cx=56, cy=48, r=5.4),
     shape("ellipse", C["meat"], transform="rotate(-45 27 27)", cx=27, cy=27, rx=21, ry=16)],
    [shape("ellipse", C["meat_dark"], transform="rotate(-45 30 30)", cx=30, cy=31, rx=16, ry=9),
     shape("ellipse", C["meat"], transform="rotate(-45 27 27)", cx=26, cy=25, rx=17, ry=11),
     shape("ellipse", C["meat_hi"], transform="rotate(-45 21 21)", cx=20, cy=20, rx=8, ry=4)])

ICONS["prime_meat"] = item_svg(
    [shape("path", C["prime"], d="M 11 32 C 9 20 21 11 33 12 C 47 13 55 23 53 35 C 51 47 41 55 28 54 C 17 53 12 43 11 32 Z"),
     shape("polygon", C["gold"], points=star(49, 14, 10, 4.3))],
    [shape("path", None, C["fat"], 4.2, d="M 51 31 C 51 43 41 51 29 51"),
     shape("path", None, C["marble"], 1.8, d="M 18 27 C 24 22 29 31 36 26"),
     shape("path", None, C["marble"], 1.8, d="M 20 39 C 27 34 33 43 42 36"),
     shape("path", None, C["marble"], 1.8, d="M 28 18 C 32 21 36 16 41 20"),
     shape("polygon", C["gold"], points=star(49, 14, 10, 4.3))])

# A meal (Config.DISHES.<id>.icon): what comes off the fire -- browned, barred where it lay on the
# stick, still steaming -- so what he eats is never taken for the raw meat he carries in (v0.6 round
# four: "掉落的raw meat和roast meat图标要区分开现在有点confusing"). The leg is the raw one's shape.
_STEAM = shape("path", None, C["steam"], 2.8, d="M 50 33 C 45 28 54 24 50 17 M 58 29 C 53 24 62 20 58 12")
ICONS["roast"] = item_svg(
    [shape("rect", C["bone"], transform=_HANDLE, x=36, y=40.5, width=20, height=7, rx=3.5),
     shape("circle", C["bone"], transform=_HANDLE, cx=56, cy=40, r=5.4),
     shape("circle", C["bone"], transform=_HANDLE, cx=56, cy=48, r=5.4),
     shape("ellipse", C["roast"], transform="rotate(-45 27 27)", cx=27, cy=27, rx=21, ry=16)],
    [shape("ellipse", C["roast_dark"], transform="rotate(-45 30 30)", cx=30, cy=31, rx=16, ry=9),
     shape("ellipse", C["roast"], transform="rotate(-45 27 27)", cx=26, cy=25, rx=17, ry=11),
     shape("ellipse", C["roast_hi"], transform="rotate(-45 21 21)", cx=20, cy=20, rx=8, ry=4),
     shape("path", None, C["grill"], 2.6, d="M 16 30 L 23 37 M 22 22 L 30 30 M 29 16 L 36 23"),
     _STEAM])

# The prime cut, cooked: the raw one's shape and star, browned, its fat crackled gold.
ICONS["roast_prime"] = item_svg(
    [shape("path", C["roast"], d="M 11 32 C 9 20 21 11 33 12 C 47 13 55 23 53 35 C 51 47 41 55 28 54 C 17 53 12 43 11 32 Z"),
     shape("polygon", C["gold"], points=star(49, 14, 10, 4.3))],
    [shape("path", C["roast_dark"], d="M 53 35 C 51 47 41 55 28 54 C 17 53 12 43 11 32 C 18 44 38 49 53 35 Z"),
     shape("path", None, C["crackling"], 4.2, d="M 51 31 C 51 43 41 51 29 51"),
     shape("path", None, C["grill"], 2.6, d="M 17 24 L 27 34 M 24 17 L 37 30 M 33 16 L 42 25"),
     shape("ellipse", C["roast_hi"], cx=22, cy=20, rx=5, ry=2.6, transform="rotate(-35 22 20)"),
     shape("polygon", C["gold"], points=star(49, 14, 10, 4.3)),
     shape("path", None, C["steam"], 2.8, d="M 9 22 C 5 17 13 14 9 7")])

# A hide off an elite (v0.6 round three): a pelt stretched out to dry, its legs out at the corners.
ICONS["hide"] = item_svg(
    [shape("path", C["hide"], d="M 32 7 C 38 7 40 12 44 13 L 55 8 L 52 20 C 55 26 55 37 52 43 L 57 54 "
                                "L 45 51 C 41 56 37 58 32 58 C 27 58 23 56 19 51 L 7 54 L 12 43 "
                                "C 9 37 9 26 12 20 L 9 8 L 20 13 C 24 12 26 7 32 7 Z")],
    [shape("ellipse", C["hide_hi"], cx=32, cy=32, rx=12, ry=17),
     shape("path", None, C["hide_dark"], 2.2, d="M 32 12 L 32 53")])

ICONS["water"] = item_svg(
    [shape("path", C["water"], d="M 32 6 C 32 6 13 28 13 40 C 13 51 21 58 32 58 C 43 58 51 51 51 40 C 51 28 32 6 32 6 Z")],
    [shape("path", None, C["water_hi"], 3.8, d="M 22 40 C 22 46 26 50 30 51")])

# The beacon's parts, out of the ship's wrecks (Config.WRECKS): a dish on its mast, a battery cell,
# the control board in its case.
ICONS["antenna"] = item_svg(
    [shape("rect", C["iron_dark"], x=19, y=51, width=26, height=8, rx=2),
     shape("polygon", C["metal"], points="29,52 35,52 34,27 30,27"),
     shape("ellipse", C["hull"], transform="rotate(-28 30 22)", cx=30, cy=22, rx=21, ry=8.5)],
    [shape("ellipse", C["hull_shade"], transform="rotate(-28 30 22)", cx=31, cy=23, rx=14, ry=4.5),
     shape("path", None, C["iron_dark"], 2.4, d="M 31 23 L 44 8"),
     shape("circle", C["hazard"], cx=45, cy=7, r=3.6)])

ICONS["battery"] = item_svg(
    [shape("rect", C["metal"], x=17, y=9, width=9, height=10, rx=2),
     shape("rect", C["metal"], x=38, y=9, width=9, height=10, rx=2),
     shape("rect", C["iron_dark"], x=11, y=17, width=42, height=40, rx=4)],
    [shape("rect", C["hazard"], x=11, y=32, width=42, height=10),
     shape("rect", "#c9433b", x=17, y=8, width=9, height=4.5, rx=2),
     shape("path", None, C["hull_shade"], 2.4, d="M 18.5 25 L 24.5 25 M 21.5 22 L 21.5 28 M 39.5 25 L 45.5 25")])

ICONS["board"] = item_svg(
    [shape("rect", C["hull"], x=7, y=12, width=50, height=38, rx=3)]
    + [shape("rect", C["metal"], x=12 + 7 * k, y=48, width=4, height=8, rx=1) for k in range(6)],
    [shape("rect", "#2b5a40", x=11, y=16, width=42, height=30, rx=2),
     shape("rect", C["iron_dark"], x=15, y=20, width=11, height=9, rx=1),
     shape("rect", C["cyan"], x=30, y=20, width=19, height=11, rx=1),
     shape("rect", C["iron_dark"], x=15, y=33, width=8, height=9, rx=1),
     shape("rect", C["iron_dark"], x=27, y=35, width=12, height=7, rx=1),
     shape("rect", C["hazard"], x=44, y=36, width=6, height=6, rx=1)])

# ------------------------------------------------------------------------------ commands
# Build, as a card on his panel (UiKit.command_button): a stone head lashed to a wooden haft.
ICONS["hammer"] = item_svg(
    [shape("polygon", C["post"], points="30,20 36,20 38,58 28,58"),
     shape("rect", C["s2"], x=14, y=8, width=34, height=16, rx=3)],
    [shape("polygon", C["post_dark"], points="30,20 32,20 31,58 28,58"),
     shape("rect", C["s1"], x=14, y=8, width=34, height=6, rx=3),
     shape("rect", C["s3"], x=14, y=19, width=34, height=5, rx=2),
     shape("rect", C["rope"], x=27, y=22, width=12, height=6, rx=2)])

# ------------------------------------------------------------------------------ abilities
# What he has made for good (Config.RECIPES), a square each on his card (OptionPanel ability
# slots): named for the recipe, so a new tool's slot finds its icon by its id.
# The bone pick: a curved bone head, sharp both ends, lashed across a wooden haft.
ICONS["stone_pick"] = item_svg(
    [shape("path", None, C["post"], 6.5, d="M 13 55 L 44 21"),
     shape("path", C["bone"], d="M 26 11 Q 55 3 59 38 Q 47 17 26 11 Z")],
    [shape("path", None, C["post_dark"], 2.0, d="M 15 51 L 41 22"),
     shape("path", None, C["bone_shade"], 1.8, d="M 33 12 Q 50 11 55 28"),
     shape("rect", C["rope"], transform="rotate(-48 43 22)", x=38, y=18.5, width=10, height=7, rx=2)])

# The stone axe: a ground stone head, its edge to the left, lashed to a haft.
ICONS["stone_axe"] = item_svg(
    [shape("path", None, C["post"], 6.5, d="M 20 58 L 41 8"),
     shape("path", C["s2"], d="M 40 12 L 38 25 L 23 30 C 16 31 10 27 9 20 C 9 13 14 8 21 8 Z")],
    [shape("path", C["s1"], d="M 21 8 C 14 8 9 13 9 20 L 17 19 C 17 15 19 12 23 12 L 39 13 L 40 12 Z"),
     shape("path", C["s3"], d="M 23 30 L 38 25 L 38.5 22 L 21 26 C 16 26.5 12 24 11 22 C 12 27 17 31 23 30 Z"),
     shape("rect", C["rope"], transform="rotate(23 38 18)", x=33, y=14, width=10, height=8, rx=2)])

# The stone pick (v0.6 round three): the bone pick's shape, a ground stone head in the bone's place.
ICONS["quarry_pick"] = item_svg(
    [shape("path", None, C["post"], 6.5, d="M 13 55 L 44 21"),
     shape("path", C["s2"], d="M 26 11 Q 55 3 59 38 Q 47 17 26 11 Z")],
    [shape("path", None, C["post_dark"], 2.0, d="M 15 51 L 41 22"),
     shape("path", None, C["s1"], 2.4, d="M 33 12 Q 50 11 55 28"),
     shape("path", None, C["s3"], 1.6, d="M 30 14 Q 46 17 52 31"),
     shape("rect", C["rope"], transform="rotate(-48 43 22)", x=38, y=18.5, width=10, height=7, rx=2)])

# A spear: a long haft, its point lashed on -- ground stone, then a split bone ground sharp.
def _spear(point, light, dark):
    return item_svg(
        [shape("path", None, C["post"], 5.5, d="M 8 59 L 45 19"),
         shape("polygon", point, points="41,24 46,11 59,4 54,18")],
        [shape("path", None, C["post_dark"], 1.8, d="M 10 55 L 43 19"),
         shape("polygon", light, points="46,11 59,4 48,16"),
         shape("polygon", dark, points="41,24 48,16 59,4 54,18"),
         shape("rect", C["rope"], transform="rotate(-47 42 23)", x=37, y=19.5, width=10, height=7, rx=2)])

ICONS["stone_spear"] = _spear(C["s2"], C["s1"], C["s3"])
ICONS["bone_spear"] = _spear(C["bone"], "#fbf5e6", C["bone_shade"])

# Armour: a vest of hide, laced up the front -- and with bone plates sewn over it in rows.
_VEST = ("M 20 8 L 27 8 C 28 14 36 14 37 8 L 44 8 C 46 14 50 18 54 20 L 52 57 L 12 57 L 10 20 "
         "C 14 18 18 14 20 8 Z")

def _vest(plates):
    detail = [shape("path", None, C["hide_hi"], 2.4, d="M 21 11 C 17 17 14 19 12 22"),
              shape("path", None, C["hide_hi"], 2.4, d="M 43 11 C 47 17 50 19 52 22"),
              shape("path", None, C["hide_dark"], 2.0, d="M 32 16 L 32 55")]
    if plates:
        # The thick hide armour (v0.6 round six: all hide -- it was bone lamellar): the vest under a second
        # layer, broad panels of darker tanned hide overlapping like shingles, stitched along their tops.
        for row, y in enumerate((20, 31, 42)):
            for (x, w) in ((13, 17), (34, 17)):
                detail.append(shape("rect", C["hide_dark"], x=x, y=y, width=w, height=12, rx=2.5))
                detail.append(shape("rect", C["hide"], x=x, y=y, width=w, height=3.2, rx=1.2))
                detail.append(shape("path", None, C["rope"], 1.3, d="M %d %d L %d %d" % (x + 2, y + 1.6, x + w - 2, y + 1.6)))
    else:
        for y in (22, 30, 38, 46):
            detail.append(shape("path", None, C["rope"], 1.8, d="M 29 %d L 35 %d M 35 %d L 29 %d" % (y, y + 5, y, y + 5)))
    return item_svg([shape("path", C["hide"], d=_VEST)], detail)

ICONS["hide_vest"] = _vest(False)
ICONS["bone_armor"] = _vest(True)

# Boots: one boot of hide in profile, a cuff at the top, laced, on a darker sole.
ICONS["hide_boots"] = item_svg(
    [shape("path", C["hide"], d="M 19 7 L 37 7 L 37 36 C 45 38 55 41 57 49 L 57 57 L 15 57 L 15 44 "
                                "C 17 40 19 35 19 29 Z")],
    [shape("rect", C["hide_hi"], x=19, y=7, width=18, height=7, rx=2),
     shape("rect", C["hide_dark"], x=15, y=52, width=42, height=5, rx=2),
     shape("path", None, C["rope"], 1.8, d="M 24 18 L 32 22 M 32 18 L 24 22 M 24 26 L 32 30 M 32 26 L 24 30"),
     shape("path", None, C["hide_dark"], 1.6, d="M 37 38 C 44 40 51 43 54 48")])

# The day's dial and its words (HUD, GAME-DESIGN 9.3): the sun, rayed; the moon, a crescent.
ICONS["sun"] = item_svg(
    [shape("circle", C["gold"], cx=32, cy=32, r=13)],
    [shape("path", None, C["flame"], 3.2, d="M 32 6 L 32 14 M 32 50 L 32 58 M 6 32 L 14 32 M 50 32 L 58 32 "
                                            "M 14 14 L 19.5 19.5 M 44.5 44.5 L 50 50 M 14 50 L 19.5 44.5 M 44.5 19.5 L 50 14"),
     shape("circle", C["flame"], cx=27, cy=27, r=4.5)])
ICONS["moon"] = item_svg(
    [shape("path", "#dfe6f2", d="M 38 8 A 24 24 0 1 0 56 44 A 18 18 0 1 1 38 8 Z")],
    [shape("circle", "#bfc8d8", cx=24, cy=40, r=3.2), shape("circle", "#bfc8d8", cx=33, cy=49, r=2.2)])

# The stone pot: a flat stone over the fire, a piece of meat searing on it.
ICONS["stone_pot"] = item_svg(
    [shape("path", C["fire"], d="M 17 60 C 14 54 18 50 21 46 C 23 51 26 53 24 60 Z"),
     shape("path", C["fire"], d="M 29 60 C 27 53 31 48 34 44 C 36 50 40 53 37 60 Z"),
     shape("path", C["fire"], d="M 41 60 C 39 55 42 51 45 48 C 47 52 49 55 47 60 Z"),
     shape("polygon", C["s2"], points="6,36 12,29 50,27 58,33 53,42 11,43"),
     shape("ellipse", C["meat"], cx=32, cy=26, rx=13, ry=7)],
    [shape("polygon", C["s1"], points="6,36 12,29 50,27 58,33"),
     shape("polygon", C["s3"], points="6,36 58,33 53,42 11,43"),
     shape("ellipse", C["meat"], cx=32, cy=26, rx=13, ry=7),
     shape("ellipse", C["meat_hi"], cx=28, cy=24, rx=6, ry=2.6),
     shape("path", C["flame"], d="M 31 60 C 30 56 32 53 34 50 C 35 54 37 56 36 60 Z")])

# ------------------------------------------------------------------------------ buildings
def _post(x0, top=22, tip=10, w=12):
    return "%d,58 %d,%d %d,%d %d,%d %d,58" % (x0, x0, top, x0 + w // 2, tip, x0 + w, top, x0 + w)


ICONS["wall"] = item_svg(
    [shape("polygon", C["post"], points=_post(x)) for x in (10, 26, 42)]
    + [shape("rect", C["rope"], x=7, y=36, width=50, height=5.5, rx=2)],
    [s for x in (10, 26, 42) for s in (
        shape("polygon", C["post_dark"], points="%d,58 %d,22 %d,14 %d,58" % (x, x, x + 4, x + 4)),
        shape("polygon", C["char"], points="%.1f,18.5 %d,10 %.1f,18.5" % (x + 2.2, x + 6, x + 9.8)))]
    + [shape("rect", C["rope"], x=7, y=36, width=50, height=5.5, rx=2)])

# The palisade with bone points lashed to its logs (tools/generate_props.py bone_palisade): the
# same three posts, each tipped with a pale point.
ICONS["bone_stake"] = item_svg(
    [shape("rect", C["post"], x=x, y=24, width=12, height=34) for x in (10, 26, 42)]
    + [shape("polygon", C["bone"], points="%d,25 %d,6 %d,25" % (x - 1, x + 6, x + 13)) for x in (10, 26, 42)]
    + [shape("rect", C["rope"], x=7, y=36, width=50, height=5.5, rx=2)],
    [s for x in (10, 26, 42) for s in (
        shape("rect", C["post_dark"], x=x, y=24, width=4, height=34),
        shape("polygon", C["bone_shade"], points="%d,25 %d,6 %d,25" % (x - 1, x + 6, x + 6)))]
    + [shape("rect", C["rope"], x=7, y=36, width=50, height=5.5, rx=2)])

_STONES = [(6, 44, 18, 13, "s2"), (25, 44, 16, 13, "s3"), (42, 44, 16, 13, "s1"),
           (9, 31, 15, 12, "s1"), (25, 31, 19, 12, "s2"), (45, 31, 12, 12, "s3"),
           (12, 19, 17, 11, "s3"), (30, 19, 16, 11, "s1"), (47, 21, 8, 9, "s2")]
ICONS["stone_wall"] = item_svg(
    [shape("rect", C[c], x=x, y=y, width=w, height=h, rx=3) for (x, y, w, h, c) in _STONES],
    [shape("rect", C[c], x=x, y=y, width=w, height=h, rx=3) for (x, y, w, h, c) in _STONES]
    + [shape("ellipse", C["moss"], cx=20, cy=19.5, rx=7, ry=2.4), shape("ellipse", C["moss"], cx=38, cy=19.5, rx=5, ry=2)])


# The fence with a rock on it (v0.6 round six): the three posts, a block of sandstone balanced on their points,
# a thong round it.
ICONS["rock_fence"] = item_svg(
    [shape("polygon", C["post"], points=_post(x, top=30, tip=20)) for x in (10, 26, 42)]
    + [shape("rect", C["rope"], x=7, y=44, width=50, height=5.5, rx=2),
       shape("rect", "#b0603c", x=16, y=6, width=32, height=17, rx=4)],
    [s for x in (10, 26, 42) for s in (
        shape("polygon", C["post_dark"], points="%d,58 %d,30 %d,22 %d,58" % (x, x, x + 4, x + 4)),)]
    + [shape("rect", C["rope"], x=7, y=44, width=50, height=5.5, rx=2),
       shape("rect", "#c97a50", x=16, y=6, width=32, height=6, rx=3),
       shape("rect", "#8a4a2e", x=16, y=17, width=32, height=6, rx=3),
       shape("path", None, C["rope"], 2.0, d="M 22 5 L 22 25 M 42 5 L 42 25")])

# A crossbow set into a stone wall (v0.6 round six): the drystone courses, a dark loophole, the stave across it.
ICONS["wall_crossbow"] = item_svg(
    [shape("rect", C[c], x=x, y=y, width=w, height=h, rx=3) for (x, y, w, h, c) in _STONES]
    + [shape("path", None, C["post"], 5.5, d="M 10 30 Q 32 16 54 30")],
    [shape("rect", C[c], x=x, y=y, width=w, height=h, rx=3) for (x, y, w, h, c) in _STONES]
    + [shape("rect", C["char"], x=25, y=26, width=14, height=12, rx=2),
       shape("path", None, C["post"], 5.5, d="M 10 30 Q 32 16 54 30"),
       shape("circle", C["bone"], cx=10, cy=30, r=3.2), shape("circle", C["bone"], cx=54, cy=30, r=3.2),
       shape("path", None, C["bone"], 1.8, d="M 10 31 L 32 34 L 54 31"),
       shape("polygon", C["bone"], points="32,8 36,17 28,17")])


# A gate: two sharpened posts with a door of planks hung between them on rope, braced with a Z --
# a door that swings, not more fence (tools/generate_props.py gate).
ICONS["gate"] = item_svg(
    [shape("polygon", C["post"], points=_post(5, top=16, tip=6, w=10)),
     shape("polygon", C["post"], points=_post(49, top=16, tip=6, w=10)),
     shape("rect", C["grain"], x=16, y=20, width=32, height=37, rx=2)],
    [shape("rect", C["ring"], x=16, y=20, width=10, height=37, rx=1.5),
     shape("rect", C["grain"], x=27, y=20, width=10, height=37, rx=1.5),
     shape("rect", C["ring"], x=38, y=20, width=10, height=37, rx=1.5),
     shape("rect", C["post_dark"], x=16, y=25, width=32, height=5, rx=1.5),
     shape("rect", C["post_dark"], x=16, y=47, width=32, height=5, rx=1.5),
     shape("path", None, C["post_dark"], 4.5, d="M 20 47 L 44 30"),
     shape("polygon", C["post_dark"], points="5,58 5,16 8,9 8,58"),
     shape("polygon", C["post_dark"], points="49,58 49,16 52,9 52,58"),
     shape("rect", C["rope"], x=3, y=26, width=16, height=4.5, rx=2),
     shape("rect", C["rope"], x=3, y=47, width=16, height=4.5, rx=2)])


# The fires (Fire.gd, tools/generate_props.py campfire, brazier, torch): each with its flame up, as it
# is at night -- what it is for.
def _flame(cx, base, h, w):
    """A flame standing `h` tall on `base`, `w` wide: an outer tongue and a pale heart."""
    outer = shape("path", C["fire"], d="M %g %g C %g %g %g %g %g %g C %g %g %g %g %g %g Z" % (
        cx - w, base, cx - w * 1.2, base - h * 0.45, cx - w * 0.2, base - h * 0.6, cx, base - h,
        cx + w * 0.3, base - h * 0.55, cx + w * 1.25, base - h * 0.45, cx + w, base))
    heart = shape("path", C["flame"], d="M %g %g C %g %g %g %g %g %g C %g %g %g %g %g %g Z" % (
        cx - w * 0.5, base, cx - w * 0.65, base - h * 0.3, cx - w * 0.1, base - h * 0.4, cx + w * 0.05, base - h * 0.62,
        cx + w * 0.2, base - h * 0.35, cx + w * 0.7, base - h * 0.3, cx + w * 0.5, base))
    return outer, heart


# The campfire: a ring of stones, logs leaned together, the fire in them.
_CAMP_FLAME = _flame(32, 50, 34, 11)
ICONS["campfire"] = item_svg(
    [shape("path", None, C["post"], 6.0, d="M 14 56 L 30 26"), shape("path", None, C["post"], 6.0, d="M 50 56 L 34 26"),
     _CAMP_FLAME[0]]
    + [shape("ellipse", C[c], cx=x, cy=y, rx=6.5, ry=4.5) for (x, y, c) in
       [(8, 56, "s2"), (20, 59, "s3"), (32, 60, "s1"), (44, 59, "s3"), (56, 56, "s2")]],
    [_CAMP_FLAME[1], shape("path", None, C["char"], 3.0, d="M 25 36 L 30 26 M 39 36 L 34 26")]
    + [shape("ellipse", C[c], cx=x, cy=y, rx=6.5, ry=4.5) for (x, y, c) in
       [(8, 56, "s2"), (20, 59, "s3"), (32, 60, "s1"), (44, 59, "s3"), (56, 56, "s2")]])

# The brazier: a stone bowl on a plinth of stone, the fire standing up out of it.
_BRAZIER_FLAME = _flame(32, 30, 28, 12)
ICONS["brazier"] = item_svg(
    [_BRAZIER_FLAME[0],
     shape("path", C["s2"], d="M 10 28 L 54 28 C 53 36 45 41 32 41 C 19 41 11 36 10 28 Z"),
     shape("rect", C["s3"], x=20, y=41, width=24, height=9, rx=2),
     shape("rect", C["s2"], x=17, y=50, width=30, height=9, rx=2)],
    [_BRAZIER_FLAME[1], shape("rect", C["char"], x=12, y=26.5, width=40, height=3.5, rx=1.5),
     shape("path", None, C["s1"], 2.0, d="M 14 32 C 20 37 44 37 50 32"),
     shape("path", None, C["s4"], 1.6, d="M 32 41 L 32 50 M 26 50 L 26 59 M 38 50 L 38 59")])

# The torch in his hand: a stick held up, its wrapped head alight.
_TORCH_FLAME = _flame(40, 22, 20, 8)
ICONS["torch"] = item_svg(
    [shape("path", None, C["post"], 6.0, d="M 20 60 L 38 24"),
     shape("rect", C["resin"], transform="rotate(27 39 23)", x=34, y=16, width=10, height=13, rx=3),
     _TORCH_FLAME[0]],
    [shape("path", None, C["rope"], 2.2, d="M 34.5 21 L 43.5 25.5 M 33.5 25.5 L 41.5 29.5"), _TORCH_FLAME[1]])


# The traps (Trap.gd): each drawn on its tripwire, which runs off down to a peg at the right --
# the wire is what makes it a trap and not a tower, so it is in every one of them.
def _tripwire():
    return [shape("path", None, C["rope"], 1.6, d="M 47 41 L 59 55"),
            shape("rect", C["post_dark"], x=57, y=50, width=3.5, height=9, rx=1)]


# The opening's trap, all wood: a sapling bow lashed across a stock in two forked stakes, the
# string drawn back, an arrow with a charred point and leaves for fletching.
ICONS["trip_bow"] = item_svg(
    [shape("polygon", C["post"], points="18,58 23,58 25,38 20,38"),
     shape("polygon", C["post"], points="39,58 44,58 42,38 37,38"),
     shape("rect", C["post"], x=12, y=34, width=38, height=6, rx=2),
     shape("path", None, C["grain"], 5.5, d="M 8 30 Q 32 8 56 30"),
     shape("rect", C["post_dark"], x=57, y=50, width=3.5, height=9, rx=1)],
    [shape("path", None, C["post_dark"], 2.5, d="M 20 38 L 17 32 M 25 38 L 27 32 M 37 38 L 35 32 M 42 38 L 45 32"),
     shape("path", None, C["rope"], 1.6, d="M 9 31 L 32 36 L 55 31"),
     shape("path", None, C["grain"], 2.4, d="M 32 36 L 32 12"),
     shape("polygon", C["char"], points="32,6 35,12 29,12"),
     shape("polygon", C["leaf"], points="32,34 27,39 32,37"),
     shape("polygon", C["leaf"], points="32,34 37,39 32,37")] + _tripwire())

# The crib of logs the set crossbow stands on (v0.6 round six: wood and bone; it was a plinth of stone),
# two courses, each log's cut end showing.
_CRIB = [(8, 49, 48, 9, "post"), (12, 39, 40, 9, "post_dark")]
_CRIB_ENDS = [(12, 53.5), (52, 53.5), (16, 43.5), (48, 43.5)]


def _set_crossbow(twin=False):
    """The set crossbow: a seasoned stave with bone tips over a stock on a crib of logs, a
    bone-headed bolt on the sinew -- and, improved, a second stave and the upgrade's chevrons."""
    staves = [shape("path", None, C["post"], 6.0, d="M 6 30 Q 32 10 58 30")]
    if twin:
        staves.append(shape("path", None, C["post"], 5.0, d="M 9 22 Q 32 4 55 22"))
    body = ([shape("rect", C[c], x=x, y=y, width=w, height=h, rx=4.5) for (x, y, w, h, c) in _CRIB]
            + [shape("rect", C["post"], x=15, y=31, width=34, height=7, rx=1.5)] + staves
            + [shape("rect", C["post_dark"], x=57, y=50, width=3.5, height=9, rx=1)])
    detail = ([shape("rect", C[c], x=x, y=y, width=w, height=h, rx=4.5) for (x, y, w, h, c) in _CRIB]
              + [shape("circle", C["grain"], cx=x, cy=y, r=4.0) for (x, y) in _CRIB_ENDS]
              + [shape("circle", C["ring"], cx=x, cy=y, r=1.6) for (x, y) in _CRIB_ENDS]
              + [shape("circle", C["bone"], cx=7, cy=30, r=3.2), shape("circle", C["bone"], cx=57, cy=30, r=3.2),
                 shape("path", None, C["bone"], 1.8, d="M 7 31 L 32 34 L 57 31"),
                 shape("path", None, C["grain"], 3.0, d="M 32 34 L 32 13"),
                 shape("polygon", C["bone"], points="32,4 36.5,14 27.5,14"),
                 shape("polygon", C["leaf"], points="32,32 27,37 32,35"),
                 shape("polygon", C["leaf"], points="32,32 37,37 32,35")]
              + _tripwire())
    if twin:
        detail += [shape("path", None, C["bone"], 1.5, d="M 10 23 L 32 27 L 54 23"),
                   shape("path", None, C["gold"], 4.0, d="M 3 50 L 9 44 L 15 50"),
                   shape("path", None, C["gold"], 4.0, d="M 3 58 L 9 52 L 15 58")]
    return item_svg(body, detail)


ICONS["set_crossbow"] = _set_crossbow()
ICONS["set_crossbow_2"] = _set_crossbow(twin=True)

# The crew module (tools/generate_cabin.py module) from the front: a long hull with a rounded roof,
# the orange band towards its engine end, its door and two windows in its side.
ICONS["core"] = item_svg(
    [shape("path", C["hull"], d="M 4 52 L 4 26 C 4 17 9 13 18 13 L 46 13 C 55 13 60 17 60 26 L 60 52 Z")],
    [shape("rect", C["hull_shade"], x=4, y=44, width=56, height=8),
     shape("rect", C["hazard"], x=47, y=13.6, width=5, height=38.4),
     shape("rect", C["iron_dark"], x=27, y=26, width=10, height=26),
     shape("rect", C["hazard"], x=27, y=26, width=10, height=3),
     shape("rect", C["iron_dark"], x=10, y=25, width=11, height=8, rx=1.5),
     shape("rect", C["window"], x=11.5, y=26.5, width=8, height=5, rx=1),
     shape("rect", C["iron_dark"], x=40, y=25, width=5, height=8, rx=1.5),
     shape("rect", C["window"], x=41, y=26.5, width=3, height=5, rx=0.8)])

# ------------------------------------------------------------------------------ units, nodes, benches
# The engineer in the crew's suit (tools/build_hero.py): the hull's white at his shoulders, the
# ring a helmet locks onto with the ship's orange along it, the chest unit's lit screen.
ICONS["hero"] = item_svg(
    [shape("path", C["hull"], d="M 11 59 C 11 45 19 38 32 38 C 45 38 53 45 53 59 Z"),
     shape("circle", C["skin"], cx=32, cy=24, r=11.5),
     shape("path", C["hair"], d="M 20.5 23 C 20 12 26 8 33 8 C 40 8 45 13 44 22 C 39 17 29 17 20.5 23 Z")],
    [shape("path", C["hull_shade"], d="M 11 59 C 11 51 13 46 17 43 L 20 59 Z"),
     shape("rect", C["metal"], x=20.5, y=35, width=23, height=5.5, rx=2.75),
     shape("rect", C["hazard"], x=20.5, y=35, width=23, height=1.8, rx=0.9),
     shape("rect", C["iron_dark"], x=26.5, y=46, width=11, height=7.5, rx=1.6),
     shape("rect", C["window"], x=28.4, y=47.7, width=7.2, height=4, rx=0.8)])

_TOE = "M 29.5 37 L 30.3 12 C 30.5 8 33.5 8 33.7 12 L 34.5 37 Z"
ICONS["dino"] = item_svg(
    [shape("ellipse", C["claw"], cx=32, cy=45, rx=10, ry=12),
     shape("path", C["claw"], d=_TOE),
     shape("path", C["claw"], transform="rotate(-32 32 44)", d=_TOE),
     shape("path", C["claw"], transform="rotate(32 32 44)", d=_TOE)],
    [shape("ellipse", "#a8603c", cx=31, cy=43, rx=5.5, ry=6.5)])

_FROND = [(-160, 18), (-125, 17), (-90, 16), (-55, 17), (-20, 18)]
ICONS["tree"] = item_svg(
    [shape("rect", C["trunk"], x=28.5, y=28, width=7, height=31, rx=2.5)]
    + [shape("ellipse", C["leaf"], transform="rotate(%d 32 26)" % a, cx=32 + L, cy=26, rx=L, ry=5.2) for (a, L) in _FROND],
    [shape("path", None, C["leaf_dark"], 1.6, transform="rotate(%d 32 26)" % a, d="M 33 26 L %d 26" % (32 + 2 * L - 3))
     for (a, L) in _FROND])

# A wreck of the ship (Config.WRECKS): a torn piece of the hull, its orange band, smoke over it.
ICONS["wreck"] = item_svg(
    [shape("path", C["hull"], d="M 6 56 C 6 36 16 26 32 24 L 38 29 L 35 33 L 44 35 L 41 40 L 50 42 L 47 48 L 58 50 L 58 56 Z"),
     shape("circle", "#8f8a82", cx=42, cy=15, r=7), shape("circle", "#8f8a82", cx=50, cy=9, r=5.5),
     shape("circle", "#8f8a82", cx=34, cy=11, r=4.5)],
    [shape("path", C["hazard"], d="M 17 31 C 20 29 23 27.5 26 26.5 L 30 56 L 22 56 Z"),
     shape("path", None, C["char"], 2.4, d="M 38 29 L 35 33 L 44 35 L 41 40 L 50 42 L 47 48 L 58 50"),
     shape("path", None, C["hull_shade"], 2.0, d="M 11 50 C 12 42 16 36 22 32")])

ICONS["workbench"] = item_svg(
    [shape("rect", C["post"], x=7, y=31, width=50, height=8, rx=2),
     shape("rect", C["post_dark"], x=11, y=39, width=6, height=19, rx=1),
     shape("rect", C["post_dark"], x=47, y=39, width=6, height=19, rx=1),
     shape("rect", C["metal"], x=28, y=10, width=18, height=8.5, rx=2),
     shape("rect", C["post"], x=34.5, y=18, width=5, height=13, rx=1.5)],
    [shape("rect", C["post_dark"], x=7, y=36, width=50, height=3, rx=1)])

ICONS["kitchen"] = item_svg(
    [shape("path", C["fire"], d="M 21 60 C 18 54 22 50 25 46 C 27 51 30 53 28 60 Z"),
     shape("path", C["fire"], d="M 30 60 C 28 53 32 48 35 44 C 37 50 41 53 38 60 Z"),
     shape("path", C["fire"], d="M 40 60 C 38 55 41 51 44 48 C 46 52 48 55 46 60 Z"),
     shape("path", C["iron"], d="M 14 25 L 50 25 L 47 40 C 46 44 42 46 38 46 L 26 46 C 22 46 18 44 17 40 Z"),
     shape("rect", C["iron_dark"], x=10, y=20, width=44, height=6.5, rx=3)],
    [shape("path", C["flame"], d="M 32 60 C 31 56 33 53 35 50 C 36 54 38 56 37 60 Z"),
     shape("path", None, "#7d868c", 2.0, d="M 20 30 L 44 30")])

ICONS["beacon"] = item_svg(
    [shape("rect", C["iron_dark"], x=21, y=52, width=22, height=7, rx=2),
     shape("polygon", C["metal"], points="28.5,53 35.5,53 33.5,24 30.5,24"),
     shape("circle", C["cyan"], cx=32, cy=20, r=5.5),
     shape("path", None, C["cyan"], 3.6, d="M 22 11 C 17 16 17 25 22 30"),
     shape("path", None, C["cyan"], 3.6, d="M 42 11 C 47 16 47 25 42 30"),
     shape("path", None, C["cyan"], 3.6, d="M 14 5 C 6 13 6 29 14 37"),
     shape("path", None, C["cyan"], 3.6, d="M 50 5 C 58 13 58 29 50 37")],
    [shape("circle", "#e8fbff", cx=30.5, cy=18.5, r=1.8)])

# ------------------------------------------------------------------------------ glyphs
GLYPHS = {}
GLYPHS["pause"] = glyph_svg([shape("rect", x=15, y=12, width=12, height=40, rx=4), shape("rect", x=37, y=12, width=12, height=40, rx=4)])
GLYPHS["play"] = glyph_svg([shape("path", d="M 20 13 C 20 9 24 7.5 27.5 9.8 L 51 28.6 C 53.8 30.5 53.8 33.5 51 35.4 L 27.5 54.2 C 24 56.5 20 55 20 51 Z")])
GLYPHS["menu"] = glyph_svg([shape("rect", x=11, y=14, width=42, height=7, rx=3.5), shape("rect", x=11, y=28.5, width=42, height=7, rx=3.5),
                            shape("rect", x=11, y=43, width=42, height=7, rx=3.5)])
GLYPHS["heart"] = glyph_svg([shape("path", d="M 32 55 C 32 55 7 41 7 23 C 7 14 14 8.5 21.5 8.5 C 26.5 8.5 30 11.5 32 15 C 34 11.5 37.5 8.5 42.5 8.5 C 50 8.5 57 14 57 23 C 57 41 32 55 32 55 Z")])
GLYPHS["build"] = glyph_svg([shape("rect", transform="rotate(-45 32 32)", x=28.5, y=22, width=7, height=38, rx=3.5),
                             shape("path", transform="rotate(-45 32 32)", d="M 15 11 L 45 11 C 48 11 50 13 50 16 L 50 21 C 50 24 48 25 45 25 L 15 25 C 13 25 12 23.5 12 22 L 12 14 C 12 12.5 13 11 15 11 Z")])
GLYPHS["upgrade"] = glyph_svg([shape("path", None, "#ffffff", 7.5, d="M 15 33 L 32 16 L 49 33"), shape("path", None, "#ffffff", 7.5, d="M 15 50 L 32 33 L 49 50")])
GLYPHS["repair"] = glyph_svg([shape("path", transform="rotate(45 32 32)", fill_rule="evenodd",
                                    d="M 32 4 A 13 13 0 1 1 31.99 4 Z M 27 2 L 37 2 L 37 16 L 27 16 Z"),
                              shape("rect", transform="rotate(45 32 32)", x=27.5, y=25, width=9, height=36, rx=4.5)])
GLYPHS["demolish"] = glyph_svg([shape("rect", x=12, y=13, width=40, height=6.5, rx=3), shape("rect", x=25, y=7, width=14, height=7, rx=3),
                                shape("path", fill_rule="evenodd", d="M 16 23 L 48 23 L 45 55 C 44.8 57.5 43 59 40.5 59 L 23.5 59 C 21 59 19.2 57.5 19 55 Z M 25 29 L 28.5 29 L 29.5 52 L 26 52 Z M 35.5 29 L 39 29 L 38 52 L 34.5 52 Z")])
GLYPHS["back"] = glyph_svg([shape("path", None, "#ffffff", 8, d="M 39 13 L 20 32 L 39 51")])
GLYPHS["clock"] = glyph_svg([shape("circle", None, "#ffffff", 6, cx=32, cy=32, r=22), shape("path", None, "#ffffff", 6, d="M 32 19 L 32 32 L 42 38")])
GLYPHS["warning"] = glyph_svg([shape("path", fill_rule="evenodd",
                                     d="M 32 6 C 34.3 6 36 7.2 37.1 9.3 L 57.6 49.6 C 59.4 53.2 57 57.5 53 57.5 L 11 57.5 C 7 57.5 4.6 53.2 6.4 49.6 L 26.9 9.3 C 28 7.2 29.7 6 32 6 Z M 28.8 21 L 35.2 21 L 34 39 L 30 39 Z M 32 43.5 A 3.6 3.6 0 1 1 31.99 43.5 Z")])
GLYPHS["lock"] = glyph_svg([shape("path", None, "#ffffff", 6.5, d="M 21 29 L 21 21 C 21 9.5 43 9.5 43 21 L 43 29"),
                            shape("path", fill_rule="evenodd", d="M 18 27 L 46 27 C 49 27 51 29 51 32 L 51 53 C 51 56 49 58 46 58 L 18 58 C 15 58 13 56 13 53 L 13 32 C 13 29 15 27 18 27 Z M 29.5 37 A 3.5 3.5 0 1 1 34.5 37 L 34 47 L 30 47 Z")])
GLYPHS["info"] = glyph_svg([shape("path", fill_rule="evenodd", d="M 32 6 A 26 26 0 1 1 31.99 6 Z M 28.5 27 L 35.5 27 L 35.5 47 L 28.5 47 Z M 32 15 A 4 4 0 1 1 31.99 15 Z")])
GLYPHS["check"] = glyph_svg([shape("path", None, "#ffffff", 8, d="M 13 33 L 26 46 L 51 19")])
GLYPHS["fed"] = glyph_svg([shape("ellipse", transform="rotate(-45 26 26)", cx=26, cy=26, rx=18, ry=13),
                           shape("rect", transform="rotate(45 44 44)", x=36, y=41, width=18, height=6, rx=3),
                           shape("circle", transform="rotate(45 44 44)", cx=54, cy=40.5, r=4.8),
                           shape("circle", transform="rotate(45 44 44)", cx=54, cy=47.5, r=4.8)])
# His stride, for the walking speed on his panel: a boot.
GLYPHS["walk"] = glyph_svg([shape("path", d="M 22 8 L 38 8 L 38 36 L 54 44 Q 58 48 54 54 L 16 54 Q 12 54 12 50 L 12 44 Q 22 40 22 30 Z")])
GLYPHS["close"] = glyph_svg([shape("path", None, "#ffffff", 8, d="M 17 17 L 47 47"), shape("path", None, "#ffffff", 8, d="M 47 17 L 17 47")])
# The launch: a mast calling out, two rings each side. (The beacon's item icon, tinted flat to
# sit on an accent button, ran its rings and mast together into one blot.)
GLYPHS["signal"] = glyph_svg([shape("circle", cx=32, cy=24, r=6), shape("path", d="M 29 31 L 35 31 L 41 58 L 23 58 Z"),
                              shape("path", None, "#ffffff", 5, d="M 22 15.6 A 13 13 0 0 0 22 32.4"),
                              shape("path", None, "#ffffff", 5, d="M 42 15.6 A 13 13 0 0 1 42 32.4"),
                              shape("path", None, "#ffffff", 5, d="M 14.4 9.2 A 23 23 0 0 0 14.4 38.8"),
                              shape("path", None, "#ffffff", 5, d="M 49.6 9.2 A 23 23 0 0 1 49.6 38.8")])


# The traps laid in the way (CellTrap; GAME-DESIGN 6.0: 刺、砸、困): each on the ground, in the litter.
def _litter_line():
    return [shape("path", None, C["post_dark"], 2.2, d="M 4 59 L 60 59")]


def _spikes(bone=False):
    """Stakes driven in points up -- charred, or with bone points lashed on."""
    posts = [(8, 30), (19, 22), (30, 16), (41, 22), (52, 30)]
    body = [shape("polygon", C["post"], points="%d,58 %d,%d %d,%d %d,%d %d,58" % (x, x, top + 8, x + 3, top, x + 6, top + 8, x + 6))
            for (x, top) in posts]
    detail = []
    for (x, top) in posts:
        detail.append(shape("polygon", C["post_dark"], points="%d,58 %d,%d %d,%d %d,58" % (x, x, top + 8, x + 2, top + 3, x + 2)))
        if bone:
            detail.append(shape("polygon", C["bone"], points="%d,%d %d,%d %d,%d" % (x - 1, top + 11, x + 3, top - 4, x + 7, top + 11)))
            detail.append(shape("polygon", C["bone_shade"], points="%d,%d %d,%d %d,%d" % (x - 1, top + 11, x + 3, top - 4, x + 3, top + 11)))
            detail.append(shape("rect", C["rope"], x=x - 1, y=top + 10, width=8, height=3, rx=1))
        else:
            detail.append(shape("polygon", C["char"], points="%d,%d %d,%d %d,%d" % (x + 1, top + 4, x + 3, top, x + 5, top + 4)))
    return item_svg(body, detail + _litter_line())


ICONS["ground_spikes"] = _spikes()
ICONS["bone_spikes"] = _spikes(bone=True)


def _deadfall(stone=False):
    """A weight propped over the way on a figure four of sticks: a log, or a slab of stone."""
    if stone:
        weight = [shape("polygon", C["s2"], points="4,52 50,22 58,30 12,58")]
        weight_detail = [shape("polygon", C["s1"], points="4,52 50,22 54,26 8,55"),
                         shape("polygon", C["s3"], points="12,58 58,30 58,33 13,60")]
    else:
        weight = [shape("path", None, C["post"], 11.0, d="M 7 54 L 53 25")]
        weight_detail = [shape("path", None, C["post_dark"], 3.0, d="M 9 57 L 55 28"),
                         shape("circle", C["grain"], cx=54, cy=24.5, r=5.2), shape("circle", C["ring"], cx=54, cy=24.5, r=2.0)]
    trigger = [shape("path", None, C["grain"], 3.2, d="M 42 58 L 42 34"),
               shape("path", None, C["grain"], 3.0, d="M 30 50 L 50 32"),
               shape("path", None, C["grain"], 3.0, d="M 28 57 L 56 51")]
    return item_svg(trigger + weight, weight_detail + _litter_line())


ICONS["log_deadfall"] = _deadfall()
ICONS["stone_deadfall"] = _deadfall(stone=True)


def _snare(hide=False):
    """A sapling bent over to a peg, a running noose on the ground where a foot will go."""
    cord = C["hide"] if hide else C["rope"]
    body = [shape("path", None, C["post"], 5.0, d="M 10 58 C 8 30 22 10 44 30"),
            shape("rect", C["post_dark"], x=44, y=44, width=4, height=15, rx=1)]
    detail = [shape("path", None, cord, 2.4 if hide else 1.8, d="M 44 30 L 38 50"),
              shape("ellipse", None, cord, 3.0 if hide else 2.2, cx=32, cy=53, rx=13, ry=4.5),
              shape("polygon", C["leaf"], points="16,22 10,18 17,17"),
              shape("polygon", C["leaf"], points="27,14 24,7 31,11")]
    return item_svg(body, detail + _litter_line())


ICONS["grass_snare"] = _snare()
ICONS["hide_snare"] = _snare(hide=True)


def write():
    os.makedirs(OUT, exist_ok=True)
    names = []
    for group in (ICONS, GLYPHS):
        for name, parts in group.items():
            svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n  '
                   + "\n  ".join(parts) + "\n</svg>\n")
            io.open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8", newline="\n").write(svg)
            stub = os.path.join(OUT, name + ".svg.import")
            if not os.path.exists(stub):
                io.open(stub, "w", encoding="utf-8", newline="\n").write('[remap]\n\nimporter="svg"\ntype="DPITexture"\n')
            names.append(name)
    print("%d icons: %s" % (len(names), ", ".join(names)))


if __name__ == "__main__":
    write()
