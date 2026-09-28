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
    "water": "#4aa6e2", "water_hi": "#b1e0f8",
    "post": "#a0703f", "post_dark": "#6f4523", "char": "#2e2019", "rope": "#dcbb7c",
    "hull": "#ebe8e1", "hull_shade": "#c4c0b6", "hazard": "#f28c28", "window": "#58c7e8",
    "skin": "#d9a67c", "hair": "#4b3322", "shirt": "#5d7c8d", "shirt_dark": "#445d6a",
    "claw": "#94512f",
    "leaf": "#64a24c", "leaf_dark": "#3f7334", "trunk": "#6e4a2a",
    "iron": "#5a6166", "iron_dark": "#3b4145", "fire": "#f28c28", "flame": "#f7cb4c",
    "metal": "#98a3aa", "cyan": "#58c7e8", "moss": "#6b9a45",
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

ICONS["water"] = item_svg(
    [shape("path", C["water"], d="M 32 6 C 32 6 13 28 13 40 C 13 51 21 58 32 58 C 43 58 51 51 51 40 C 51 28 32 6 32 6 Z")],
    [shape("path", None, C["water_hi"], 3.8, d="M 22 40 C 22 46 26 50 30 51")])

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

_PLINTH = [(9, 48, 22, 10, "s2"), (32, 48, 23, 10, "s3"), (12, 38, 19, 10, "s1"), (32, 38, 19, 10, "s2")]


def _set_crossbow(twin=False):
    """The set crossbow: a seasoned stave with bone tips over a stock on a plinth of stone, a
    bone-headed bolt on the sinew -- and, improved, a second stave and the upgrade's chevrons."""
    staves = [shape("path", None, C["post"], 6.0, d="M 6 30 Q 32 10 58 30")]
    if twin:
        staves.append(shape("path", None, C["post"], 5.0, d="M 9 22 Q 32 4 55 22"))
    body = ([shape("rect", C[c], x=x, y=y, width=w, height=h, rx=2.5) for (x, y, w, h, c) in _PLINTH]
            + [shape("rect", C["post"], x=15, y=31, width=34, height=7, rx=1.5)] + staves
            + [shape("rect", C["post_dark"], x=57, y=50, width=3.5, height=9, rx=1)])
    detail = ([shape("rect", C[c], x=x, y=y, width=w, height=h, rx=2.5) for (x, y, w, h, c) in _PLINTH]
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

ICONS["core"] = item_svg(
    [shape("rect", C["hull"], x=5, y=17, width=54, height=31, rx=15.5)],
    [shape("rect", C["hull_shade"], x=10, y=37, width=44, height=8, rx=4),
     shape("rect", C["hazard"], x=19, y=17.6, width=7, height=29.8),
     shape("circle", C["iron_dark"], cx=44, cy=30, r=7.5),
     shape("circle", C["window"], cx=44, cy=30, r=5.6),
     shape("circle", "#ffffff", cx=42, cy=28, r=1.8)])

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
GLYPHS["close"] = glyph_svg([shape("path", None, "#ffffff", 8, d="M 17 17 L 47 47"), shape("path", None, "#ffffff", 8, d="M 47 17 L 17 47")])
# The launch: a mast calling out, two rings each side. (The beacon's item icon, tinted flat to
# sit on an accent button, ran its rings and mast together into one blot.)
GLYPHS["signal"] = glyph_svg([shape("circle", cx=32, cy=24, r=6), shape("path", d="M 29 31 L 35 31 L 41 58 L 23 58 Z"),
                              shape("path", None, "#ffffff", 5, d="M 22 15.6 A 13 13 0 0 0 22 32.4"),
                              shape("path", None, "#ffffff", 5, d="M 42 15.6 A 13 13 0 0 1 42 32.4"),
                              shape("path", None, "#ffffff", 5, d="M 14.4 9.2 A 23 23 0 0 0 14.4 38.8"),
                              shape("path", None, "#ffffff", 5, d="M 49.6 9.2 A 23 23 0 0 1 49.6 38.8")])


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
