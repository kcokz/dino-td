# tools/generate_cabin.py
# The cabin: the crew module the Hero lives in, outside and in, and the three benches he works
# at inside it -- each with the pieces that appear on it as the run goes on.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_cabin.py
#   ... -- module workbench   makes only those
#   ... -- --preview          also renders each to the scratch directory
#
# Built with the same coloured-triangle Builder as the props (tools/generate_props.py) and
# in the same palette -- the module's white plating and orange hazard band, the valley's
# bark, stone and bone -- because the room is the inside of the wreck the player sees
# from the map, fitted out with what the valley gave him.
#
# PARTS. Each model is one file of several objects, and the game shows or hides each by
# its name (CraftingStation.refresh_parts):
#
#   <job id>          shown once that job is done: "stone_axe", "beacon_2", "beacon_launch"
#   before_<job id>   shown until it is done: the roasting spit is "before_stone_pot"
#   anything else     always shown
#
# and a name ending in "_glow" is drawn lit by itself -- fire, a screen, daylight through a
# porthole -- and lights the room round it. So a bench's upgrades are named after the jobs
# that make them, and a new tool is a recipe in Config and a part here with its id.
#
# The module also carries empties named "spot_<station id>": where each bench stands.

import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import Builder, mix, jitter, vertex_colour_material, reset, UP, PREVIEW_DIR  # noqa: E402
from generate_props import (_boulder, _log, _bone, _pot, _rope_coil, export_objects,  # noqa: E402
                            BARK, BARK_LIGHT, FRESH_WOOD, CHAR, VINE, VINE_DARK, ROCK_DARK, ROCK,
                            ROCK_LIGHT, METAL, METAL_DARK, GUNMETAL, HAZARD, LENS, BONE, MEAT,
                            MEAT_DARK, FAT, HEAT_TILE, HEAT_TILE_LIGHT, ASH)
from mathutils import Vector  # noqa: E402

REPO = r"z:\home\zkl-unix\repo\game\dino"
OUT_DIR = os.path.join(REPO, "assets", "models", "cabin")

# The inside of the plating: paler and cleaner than the scorched outside, with a darker
# band to knee height where boots and crates scuff it.
PANEL = (0.70, 0.71, 0.70)
PANEL_ALT = (0.64, 0.655, 0.65)
WAINSCOT = (0.30, 0.32, 0.34)
DECK = (0.26, 0.265, 0.28)
DECK_ALT = (0.225, 0.23, 0.245)
HIDE = (0.50, 0.36, 0.22)
HIDE_EDGE = (0.34, 0.23, 0.13)
# Lit by themselves (the "_glow" parts): these are the colours they are drawn at.
LAMP = (1.00, 0.90, 0.72)
FLAME = (1.00, 0.52, 0.10)
FLAME_TIP = (1.00, 0.86, 0.36)
EMBER = (0.92, 0.28, 0.05)
SCREEN = (0.34, 0.84, 0.96)
SCREEN_LINE = (0.70, 0.97, 1.00)
OK_LIGHT = (0.40, 0.95, 0.45)
ERROR_LIGHT = (0.98, 0.16, 0.10)


# ==============================================================================
# Shapes
# ==============================================================================

def box(b, lo, hi, col, rng=None):
    """A block from `lo` to `hi`, all six faces: its top a touch lighter and its underside
    darker, so a flat colour still reads as a solid under one lamp."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z0)), Vector((x0, y1, z0)),
         Vector((x0, y0, z1)), Vector((x1, y0, z1)), Vector((x1, y1, z1)), Vector((x0, y1, z1))]
    j = (lambda c: jitter(c, rng, 0.012)) if rng else (lambda c: c)
    top, side, under = j(mix(col, (1.0, 1.0, 1.0), 0.07)), j(col), mix(col, (0.0, 0.0, 0.0), 0.35)
    b.quad(v[4], v[5], v[6], v[7], top, top, top, top)
    b.quad(v[3], v[2], v[1], v[0], under, under, under, under)
    for (a, c, d, e) in ((0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        b.quad(v[a], v[c], v[d], v[e], side, side, side, side)


def beam(b, p0, p1, w, t, col, rng=None, up=UP):
    """A squared timber or strip of plate from `p0` to `p1`: `w` wide, `t` thick."""
    axis = (p1 - p0).normalized()
    side = axis.cross(up)
    if side.length < 1e-4:
        side = axis.cross(Vector((1.0, 0.0, 0.0)))
    side.normalize()
    nrm = side.cross(axis).normalized()
    c = [p + side * sx * w * 0.5 + nrm * sn * t * 0.5
         for p in (p0, p1) for (sx, sn) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    j = (lambda k: jitter(k, rng, 0.015)) if rng else (lambda k: k)
    col_top = j(mix(col, (1.0, 1.0, 1.0), 0.06))
    col_side = j(col)
    for k in range(4):
        k2 = (k + 1) % 4
        cc = col_top if k == 2 else col_side
        b.quad(c[k], c[k2], c[4 + k2], c[4 + k], cc, cc, cc, cc)
    b.quad(c[3], c[2], c[1], c[0], col_side, col_side, col_side, col_side)
    b.quad(c[4], c[5], c[6], c[7], col_side, col_side, col_side, col_side)


def rod(b, p0, p1, r, col, sides=6, col1=None):
    """A round bar with capped ends: a haft, a pipe, a pole."""
    col1 = col1 if col1 is not None else col
    rings = b.tube([p0, p0.lerp(p1, 0.5), p1], [r, r, r], [col, mix(col, col1, 0.5), col1], sides)
    for ring, centre, flip in ((rings[0], p0, True), (rings[-1], p1, False)):
        for k in range(sides):
            k2 = (k + 1) % sides
            a, c = (ring[k2], ring[k]) if flip else (ring[k], ring[k2])
            cc = col if flip else col1
            b.tri(a, c, centre, cc, cc, cc)


def disc(b, centre, normal, radius, col, n=14, col_centre=None, squash=1.0):
    """A flat round plate facing `normal`: a porthole's glass, a dish, a lid."""
    normal = normal.normalized()
    u = normal.cross(UP if abs(normal.dot(UP)) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
    v = normal.cross(u).normalized()
    pts = [centre + (u * math.cos(math.tau * i / n) + v * math.sin(math.tau * i / n) * squash) * radius
           for i in range(n)]
    cc = col_centre if col_centre is not None else col
    for i in range(n):
        b.tri(pts[i], pts[(i + 1) % n], centre, col, col, cc)
    return pts


def annulus(b, centre, normal, r_in, r_out, col, n=16, col_out=None):
    """A flat ring: a porthole's frame, a gasket."""
    normal = normal.normalized()
    u = normal.cross(UP if abs(normal.dot(UP)) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
    v = normal.cross(u).normalized()
    co = col_out if col_out is not None else col
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        d0 = u * math.cos(a0) + v * math.sin(a0)
        d1 = u * math.cos(a1) + v * math.sin(a1)
        b.quad(centre + d0 * r_in, centre + d1 * r_in, centre + d1 * r_out, centre + d0 * r_out, col, col, co, co)


def lashing(b, centre, axis, r, rng, width=0.035):
    """A few turns of vine bound round a joint."""
    axis = axis.normalized()
    b.tube([centre - axis * width, centre + axis * width], [r, r], [jitter(VINE, rng, 0.03), VINE_DARK], 7)


def flame(b, base, height, width, rng):
    """One tongue of fire: a twisted four-sided spike, deep orange at the root and pale
    yellow at the tip."""
    lean = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 1.0)).normalized()
    tip = base + lean * height
    mid = base + lean * height * 0.38
    twist = rng.uniform(0.0, math.pi)
    ring = [mid + Vector((math.cos(twist + math.tau * k / 4), math.sin(twist + math.tau * k / 4), 0.0)) * width
            for k in range(4)]
    for k in range(4):
        k2 = (k + 1) % 4
        b.tri(base, ring[k2], ring[k], EMBER, FLAME, FLAME)
        b.tri(ring[k], ring[k2], tip, FLAME, FLAME, FLAME_TIP)


# ==============================================================================
# The workbench: a hull panel on log legs, and a board of tools behind it
# ==============================================================================

def workbench(seed):
    rng = random.Random(seed)
    base = Builder()
    # The top: a piece of the module's plating, its orange edge to the front.
    top_z = 0.62
    box(base, (-0.62, -0.30, top_z - 0.05), (0.62, 0.30, top_z), METAL, rng)
    box(base, (-0.62, -0.315, top_z - 0.05), (0.62, -0.30, top_z), HAZARD)
    for (x, y) in ((-0.57, -0.25), (0.57, -0.25), (-0.57, 0.25), (0.57, 0.25)):
        box(base, (x - 0.012, y - 0.012, top_z), (x + 0.012, y + 0.012, top_z + 0.006), GUNMETAL)
    # Log legs, splayed a little, lashed where they meet the top; a shelf low down.
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        foot = Vector((sx * 0.56, sy * 0.25, 0.0))
        head = Vector((sx * 0.52, sy * 0.22, top_z - 0.05))
        base.tube([foot, foot.lerp(head, 0.5), head], [0.046, 0.043, 0.04],
                  [BARK, BARK_LIGHT, BARK], 7)
        lashing(base, head - UP * 0.06, head - foot, 0.05, rng)
    for k in range(3):
        y = -0.18 + k * 0.18
        beam(base, Vector((-0.55, y, 0.20)), Vector((0.55, y, 0.20)), 0.16, 0.035,
             mix(BARK_LIGHT, FRESH_WOOD, rng.uniform(0.1, 0.4)), rng)
    _log(base, Vector((-0.40, -0.05, 0.28)), Vector((-0.02, -0.05, 0.28)), 0.06, rng)
    _log(base, Vector((-0.30, 0.12, 0.28)), Vector((0.10, 0.14, 0.28)), 0.055, rng)
    _rope_coil(base, Vector((0.32, 0.05, 0.22)), 0.1, 0.022, (0.36, 0.30, 0.16), rng)
    # On the top: a vice of two blocks, a knapping stone, a flint knife, shavings.
    box(base, (-0.58, -0.22, top_z), (-0.46, 0.05, top_z + 0.12), BARK_LIGHT, rng)
    box(base, (-0.40, -0.22, top_z), (-0.30, 0.05, top_z + 0.12), BARK_LIGHT, rng)
    rod(base, Vector((-0.60, -0.08, top_z + 0.08)), Vector((-0.26, -0.08, top_z + 0.08)), 0.014, FRESH_WOOD)
    _boulder(base, Vector((0.28, -0.10, top_z)), 0.07, rng, fresh=True)
    blade = [Vector((0.02, -0.16, top_z + 0.01)), Vector((0.14, -0.20, top_z + 0.01)), Vector((0.08, -0.12, top_z + 0.012))]
    base.tri(blade[0], blade[1], blade[2], (0.16, 0.16, 0.18), (0.30, 0.30, 0.33), (0.20, 0.20, 0.22))
    rod(base, Vector((-0.08, -0.12, top_z + 0.015)), Vector((0.03, -0.155, top_z + 0.015)), 0.012, BONE)
    for k in range(9):
        c = Vector((rng.uniform(-0.2, 0.45), rng.uniform(-0.2, 0.2), top_z + 0.004))
        a = rng.uniform(0.0, math.tau)
        d = Vector((math.cos(a), math.sin(a), 0.0)) * 0.03
        base.tri(c, c + d, c + d.cross(UP) * 0.5, FRESH_WOOD, FRESH_WOOD, mix(FRESH_WOOD, BARK_LIGHT, 0.3))
    # The tool board: a sheet of the module's darker alloy on two posts, holes in rows,
    # pegs for what gets made.
    for x in (-0.58, 0.58):
        rod(base, Vector((x, 0.33, 0.0)), Vector((x, 0.33, 1.52)), 0.035, BARK, col1=BARK_LIGHT)
    box(base, (-0.60, 0.29, 0.70), (0.60, 0.32, 1.46), METAL_DARK, rng)
    box(base, (-0.60, 0.287, 1.42), (0.60, 0.29, 1.46), HAZARD)
    for r in range(5):
        for c in range(10):
            x = -0.52 + c * 0.115
            z = 0.78 + r * 0.14
            base.quad(Vector((x - 0.01, 0.2865, z - 0.01)), Vector((x + 0.01, 0.2865, z - 0.01)),
                      Vector((x + 0.01, 0.2865, z + 0.01)), Vector((x - 0.01, 0.2865, z + 0.01)),
                      GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)
    for x in (-0.33, 0.30):
        rod(base, Vector((x, 0.29, 1.22)), Vector((x, 0.22, 1.24)), 0.011, GUNMETAL)

    # The Bone Pick, hung on the board: a haft with a long bone lashed across its head.
    pick = Builder()
    haft0, haft1 = Vector((-0.33, 0.25, 0.74)), Vector((-0.33, 0.24, 1.26))
    rod(pick, haft0, haft1, 0.018, BARK_LIGHT, col1=FRESH_WOOD)
    head = haft1 + Vector((0.0, -0.01, 0.02))
    _bone(pick, head + Vector((-0.17, 0.0, -0.05)), head + Vector((0.16, 0.0, 0.03)), rng)
    lashing(pick, head, Vector((1.0, 0.0, 0.0)), 0.03, rng)

    # The Stone Axe, beside it: a haft and a knapped stone head bound on.
    axe = Builder()
    a0, a1 = Vector((0.30, 0.25, 0.76)), Vector((0.30, 0.24, 1.26))
    rod(axe, a0, a1, 0.019, BARK_LIGHT, col1=FRESH_WOOD)
    h = a1 + Vector((0.0, -0.01, -0.03))
    stone = [h + Vector((0.02, 0.0, 0.06)), h + Vector((0.20, 0.0, 0.07)), h + Vector((0.22, 0.0, -0.06)),
             h + Vector((0.02, 0.0, -0.05))]
    front = Vector((0.0, -0.035, 0.0))
    back = Vector((0.0, 0.03, 0.0))
    dark, pale = ROCK_DARK, ROCK_LIGHT
    axe.quad(stone[0] + front, stone[1] + front * 0.4, stone[2] + front * 0.4, stone[3] + front, ROCK, pale, pale, ROCK)
    axe.quad(stone[3] + back, stone[2] + back * 0.4, stone[1] + back * 0.4, stone[0] + back, dark, ROCK, ROCK, dark)
    for k in range(4):
        k2 = (k + 1) % 4
        f = front if k in (0, 3) else front * 0.4
        f2 = front if k2 in (0, 3) else front * 0.4
        bk = back if k in (0, 3) else back * 0.4
        bk2 = back if k2 in (0, 3) else back * 0.4
        axe.quad(stone[k] + f, stone[k2] + f2, stone[k2] + bk2, stone[k] + bk, ROCK, ROCK, dark, dark)
    lashing(axe, h + Vector((0.0, 0.0, 0.0)), UP, 0.032, rng)

    return [("base", base), ("stone_pick", pick), ("stone_axe", axe)]


# ==============================================================================
# The kitchen: a stone hearth on a heat-shield tile, under a hood
# ==============================================================================

def kitchen(seed):
    rng = random.Random(seed)
    base = Builder()
    # Tiles off the heat shield, laid on the deck so the fire does not reach it.
    for i in range(6):
        for j in range(4):
            x0, y0 = -0.60 + i * 0.2, -0.36 + j * 0.19
            col = HEAT_TILE_LIGHT if (i + j) % 2 == 0 else HEAT_TILE
            box(base, (x0 + 0.004, y0 + 0.004, 0.0), (x0 + 0.196, y0 + 0.186, 0.05), col, rng)
    # The firebox: stones stacked in a horseshoe, open to the front.
    ring = []
    for k in range(7):
        ring.append(Vector((-0.42 + k * 0.14, 0.26, 0.05)))
    for k in range(3):
        ring.append(Vector((-0.44, 0.12 - k * 0.15, 0.05)))
        ring.append(Vector((0.44, 0.12 - k * 0.15, 0.05)))
    for course, lift in enumerate((0.0, 0.13, 0.25)):
        for p in ring:
            if course == 2 and p.y < 0.0:
                continue
            _boulder(base, p + Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), lift)),
                     0.085 * rng.uniform(0.9, 1.1), rng, fresh=True)
    # The fire bed: ash, and logs burnt black.
    bed_c = Vector((0.0, 0.02, 0.055))
    ash = [bed_c + Vector((math.cos(math.tau * k / 12) * 0.3, math.sin(math.tau * k / 12) * 0.2, 0.0)) for k in range(12)]
    for k in range(12):
        base.tri(ash[k], ash[(k + 1) % 12], bed_c + UP * 0.01, ASH, ASH, mix(ASH, CHAR, 0.6))
    for a in (0.3, 1.9, 3.6):
        d = Vector((math.cos(a), math.sin(a) * 0.6, 0.0))
        base.tube([bed_c - d * 0.24 + UP * 0.03, bed_c + d * 0.2 + UP * 0.07], [0.035, 0.03],
                  [CHAR, mix(CHAR, BARK, 0.4)], 6)
    # The hood: a bent sheet of plating on two iron legs, and its pipe up through the
    # ceiling, where the smoke goes out.
    for x in (-0.47, 0.47):
        rod(base, Vector((x, 0.30, 0.05)), Vector((x, 0.30, 1.10)), 0.022, METAL_DARK)
    lo_y, hi_y = -0.20, 0.34
    corners_lo = [Vector((-0.52, lo_y, 1.00)), Vector((0.52, lo_y, 1.00)), Vector((0.52, hi_y, 1.00)), Vector((-0.52, hi_y, 1.00))]
    corners_hi = [Vector((-0.14, -0.02, 1.34)), Vector((0.14, -0.02, 1.34)), Vector((0.14, 0.2, 1.34)), Vector((-0.14, 0.2, 1.34))]
    for k in range(4):
        k2 = (k + 1) % 4
        base.quad(corners_lo[k], corners_lo[k2], corners_hi[k2], corners_hi[k], METAL, METAL, METAL_DARK, METAL_DARK)
    box(base, (-0.53, lo_y - 0.012, 0.96), (0.53, lo_y + 0.005, 1.02), HAZARD)
    base.tube([Vector((0.0, 0.09, 1.30)), Vector((0.0, 0.09, 1.9)), Vector((0.0, 0.12, 2.56))],
              [0.085, 0.085, 0.085], [METAL_DARK, GUNMETAL, METAL_DARK], 10)
    for z in (1.55, 2.1):
        base.tube([Vector((0.0, 0.09, z - 0.02)), Vector((0.0, 0.09, z + 0.02))], [0.095, 0.095], [GUNMETAL, GUNMETAL], 10)
    # Beside the fire: a water jar, a haunch hung to dry from the hood, a skin of fat.
    _pot(base, Vector((-0.53, -0.26, 0.05)), 0.26, rng)
    rod(base, Vector((0.36, -0.12, 1.00)), Vector((0.36, -0.12, 0.86)), 0.006, GUNMETAL)
    haunch = Vector((0.36, -0.12, 0.74))
    base.tube([haunch + UP * 0.12, haunch, haunch - UP * 0.1], [0.03, 0.075, 0.05], [BONE, MEAT_DARK, MEAT], 8)

    # The spit, until there is a pot: two forked sticks and a skewer with meat on it.
    spit = Builder()
    for x in (-0.36, 0.36):
        f = Vector((x, 0.02, 0.05))
        top = Vector((x, 0.02, 0.58))
        rod(spit, f, top, 0.016, BARK_LIGHT)
        for sy in (-1.0, 1.0):
            rod(spit, top - UP * 0.03, top + Vector((0.0, sy * 0.05, 0.07)), 0.011, BARK_LIGHT)
    rod(spit, Vector((-0.46, 0.02, 0.61)), Vector((0.46, 0.02, 0.61)), 0.011, FRESH_WOOD)
    meat_c = Vector((0.0, 0.02, 0.61))
    spit.tube([meat_c - Vector((0.12, 0.0, 0.0)), meat_c - Vector((0.04, 0.0, 0.0)), meat_c + Vector((0.05, 0.0, 0.0)),
               meat_c + Vector((0.12, 0.0, 0.0))], [0.04, 0.075, 0.07, 0.035], [MEAT_DARK, MEAT, MEAT, MEAT_DARK], 8)

    # The stone pot: a slab ground hollow, set across the firebox, searing a cut.
    pot = Builder()
    pc = Vector((0.0, 0.04, 0.40))
    outer, inner, top = [], [], []
    n = 12
    for k in range(n):
        a = math.tau * k / n
        d = Vector((math.cos(a) * 0.30, math.sin(a) * 0.22, 0.0))
        outer.append(pc + d * rng.uniform(0.97, 1.03))
        top.append(pc + d * 1.0 + UP * 0.07)
        inner.append(pc + d * 0.72 + UP * 0.035)
    floor_c = pc + UP * 0.03
    for k in range(n):
        k2 = (k + 1) % n
        pot.quad(outer[k], outer[k2], top[k2], top[k], ROCK_DARK, ROCK_DARK, ROCK_LIGHT, ROCK_LIGHT)
        pot.quad(top[k], top[k2], inner[k2], inner[k], ROCK_LIGHT, ROCK_LIGHT, ROCK, ROCK)
        pot.tri(inner[k], inner[k2], floor_c, ROCK_DARK, ROCK_DARK, (0.15, 0.13, 0.12))
        pot.tri(outer[k2], outer[k], pc - UP * 0.01, ROCK_DARK, ROCK_DARK, ROCK_DARK)
    cut = floor_c + UP * 0.012
    pot.tube([cut - Vector((0.1, 0.0, 0.0)), cut, cut + Vector((0.1, 0.0, 0.0))], [0.02, 0.035, 0.02],
             [FAT, MEAT, FAT], 8)

    # The fire itself, lit.
    fire = Builder()
    for k in range(7):
        a = math.tau * k / 7 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.02, 0.14)
        flame(fire, bed_c + Vector((math.cos(a) * r, math.sin(a) * r * 0.6, 0.04)), rng.uniform(0.16, 0.3),
              rng.uniform(0.035, 0.06), rng)
    for k in range(10):
        c = bed_c + Vector((rng.uniform(-0.22, 0.22), rng.uniform(-0.12, 0.12), 0.02))
        fire.tri(c, c + Vector((0.03, 0.0, 0.0)), c + Vector((0.0, 0.03, 0.0)), EMBER, EMBER, FLAME)

    return [("base", base), ("before_stone_pot", spit), ("stone_pot", pot), ("fire_glow", fire)]


# ==============================================================================
# The beacon: the module's radio, and the mast that brings it back up in three stages
# ==============================================================================

def beacon(seed):
    rng = random.Random(seed)
    base = Builder()
    # The console: a desk of the module's alloy with a slanted face.
    box(base, (-0.58, -0.22, 0.0), (0.22, 0.30, 0.72), METAL_DARK, rng)
    box(base, (-0.58, -0.235, 0.66), (0.22, -0.22, 0.72), HAZARD)
    face = [Vector((-0.55, -0.20, 0.72)), Vector((0.19, -0.20, 0.72)), Vector((0.19, 0.22, 1.02)), Vector((-0.55, 0.22, 1.02))]
    base.quad(face[0], face[1], face[2], face[3], METAL, METAL, METAL, METAL)
    back_top = [Vector((-0.55, 0.30, 1.02)), Vector((0.19, 0.30, 1.02))]
    base.quad(face[3], face[2], back_top[1], back_top[0], METAL, METAL, METAL, METAL)
    for (a, c, d) in ((face[0], face[3], Vector((-0.55, 0.30, 0.72))), (face[1], Vector((0.19, 0.30, 0.72)), face[2])):
        base.tri(a, c, d, METAL_DARK, METAL_DARK, METAL_DARK)
    base.quad(Vector((-0.55, 0.30, 0.72)), Vector((0.19, 0.30, 0.72)), back_top[1], back_top[0],
              METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)

    def on_face(u, v, lift=0.004):
        # A point on the slanted face: u across (0 left .. 1 right), v up it (0 .. 1).
        p = face[0].lerp(face[1], u).lerp(face[3].lerp(face[2], u), v)
        n = (face[1] - face[0]).cross(face[3] - face[0]).normalized()
        return p + n * lift
    # The screen, dark until the radio is working again (see the glow parts).
    scr = [on_face(0.08, 0.45), on_face(0.62, 0.45), on_face(0.62, 0.93), on_face(0.08, 0.93)]
    base.quad(*scr, LENS, LENS, LENS, LENS)
    for r in range(2):
        for c in range(4):
            u0, v0 = 0.08 + c * 0.13, 0.08 + r * 0.17
            k = [on_face(u0, v0), on_face(u0 + 0.1, v0), on_face(u0 + 0.1, v0 + 0.12), on_face(u0, v0 + 0.12)]
            col = HAZARD if (r, c) == (0, 3) else GUNMETAL
            base.quad(*k, col, col, col, col)
    for k in range(3):
        rod(base, on_face(0.72 + k * 0.08, 0.3, 0.0), on_face(0.72 + k * 0.08, 0.3, 0.05), 0.012,
            GUNMETAL, col1=HAZARD if k == 1 else METAL)
    # The mast's socket beside it, and the cable run from the console.
    mast_x, mast_y = 0.42, 0.10
    foot = Vector((mast_x, mast_y, 0.0))
    box(base, (mast_x - 0.16, mast_y - 0.16, 0.0), (mast_x + 0.16, mast_y + 0.16, 0.04), GUNMETAL)
    rod(base, foot, foot + UP * 0.32, 0.06, METAL_DARK, sides=10)
    base.tube([Vector((0.1, 0.28, 0.35)), Vector((0.25, 0.24, 0.12)), Vector((mast_x, mast_y + 0.05, 0.2))],
              [0.018, 0.018, 0.018], [GUNMETAL, GUNMETAL, GUNMETAL], 5)

    # Broken: the upper mast snapped off and lying on the deck, its dish crumpled beside it,
    # and the cut cable hanging from the socket.
    broken = Builder()
    rod(broken, Vector((0.05, -0.28, 0.05)), Vector((0.62, -0.05, 0.05)), 0.05, METAL_DARK, sides=10)
    rod(broken, foot + UP * 0.32, foot + UP * 0.40 + Vector((0.04, -0.03, 0.0)), 0.05, METAL_DARK, sides=10)
    dish_c = Vector((0.45, -0.24, 0.12))
    disc(broken, dish_c, Vector((0.35, -0.6, 0.72)), 0.22, METAL, 12, METAL_DARK, squash=0.8)
    broken.tube([foot + UP * 0.34 + Vector((0.05, 0.0, 0.0)), foot + UP * 0.2 + Vector((0.12, -0.1, 0.0)),
                 foot + UP * 0.05 + Vector((0.1, -0.22, 0.0))], [0.012] * 3, [HAZARD, HAZARD, GUNMETAL], 5)

    # Short enough that its dish stays in the cabin camera's frame, under the hull's shoulder.
    top = foot + UP * 1.55
    # Stage 1 (wood): the mast stood up again, splinted by three poles lashed round it.
    s1 = Builder()
    rod(s1, foot + UP * 0.3, top, 0.045, METAL_DARK, sides=10, col1=METAL)
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        d = Vector((math.cos(a), math.sin(a), 0.0))
        pole_foot = foot + d * 0.28
        pole_top = foot + d * 0.06 + UP * 1.32
        rod(s1, pole_foot, pole_top, 0.024, BARK, col1=BARK_LIGHT)
        for z in (0.45, 0.9, 1.24):
            t = z / 1.32
            lashing(s1, pole_foot.lerp(pole_top, t), pole_top - pole_foot, 0.032, rng)
    # Stage 2 (stone): a cairn round the foot, and two stays weighted down with stones.
    s2 = Builder()
    for k in range(9):
        a = math.tau * k / 9
        _boulder(s2, foot + Vector((math.cos(a) * 0.25, math.sin(a) * 0.2, 0.045)), 0.075, rng, fresh=True)
    for k in range(5):
        a = math.tau * k / 5 + 0.3
        _boulder(s2, foot + Vector((math.cos(a) * 0.16, math.sin(a) * 0.13, 0.15)), 0.06, rng, fresh=True)
    for (sx, sy) in ((0.14, -0.30), (-0.52, 0.02)):
        anchor = foot + Vector((sx, sy, 0.05))
        _boulder(s2, anchor, 0.08, rng, fresh=True)
        s2.tube([foot + UP * 1.2, anchor + UP * 0.09], [0.006, 0.006], [(0.36, 0.30, 0.16), (0.36, 0.30, 0.16)], 4)
    # Stage 3 (stone and bone): the dish rebuilt on bone ribs with a hide stretched over it.
    s3 = Builder()
    hub = top + UP * 0.03
    face_dir = Vector((-0.25, -0.75, 0.62)).normalized()
    u = face_dir.cross(UP).normalized()
    v = face_dir.cross(u).normalized()
    ribs = 8
    rim_pts = []
    for k in range(ribs):
        a = math.tau * k / ribs
        d = u * math.cos(a) + v * math.sin(a)
        mid = hub + d * 0.13 + face_dir * 0.05
        tip = hub + d * 0.27 + face_dir * 0.16
        s3.tube([hub, mid, tip], [0.012, 0.011, 0.009], [BONE, BONE, mix(BONE, (1.0, 1.0, 1.0), 0.2)], 5)
        rim_pts.append(tip)
    for k in range(ribs):
        s3.tri(rim_pts[k], rim_pts[(k + 1) % ribs], hub + face_dir * 0.04, (0.55, 0.42, 0.28), (0.55, 0.42, 0.28), HIDE)
    s3.tube([hub, hub + face_dir * 0.26], [0.01, 0.006], [BONE, BONE], 5)
    for z in (0.8, 1.1):
        c = foot + UP * z
        s3.tube([c - UP * 0.03, c + UP * 0.03], [0.055, 0.055], [BONE, mix(BONE, (0.45, 0.36, 0.2), 0.3)], 8)

    # Lit: the screen alive once the radio is whole, a red fault light until then, and at
    # the launch the lamp in the dish's throat.
    screen = Builder()
    s_in = [on_face(0.10, 0.48, 0.007), on_face(0.60, 0.48, 0.007), on_face(0.60, 0.90, 0.007), on_face(0.10, 0.90, 0.007)]
    screen.quad(*s_in, SCREEN, SCREEN, SCREEN, SCREEN)
    for k in range(4):
        v0 = 0.54 + k * 0.08
        w = [0.4, 0.28, 0.35, 0.18][k]
        ln = [on_face(0.14, v0, 0.009), on_face(0.14 + w, v0, 0.009), on_face(0.14 + w, v0 + 0.025, 0.009),
              on_face(0.14, v0 + 0.025, 0.009)]
        screen.quad(*ln, SCREEN_LINE, SCREEN_LINE, SCREEN_LINE, SCREEN_LINE)
    ok = [on_face(0.86, 0.72, 0.006), on_face(0.93, 0.72, 0.006), on_face(0.93, 0.8, 0.006), on_face(0.86, 0.8, 0.006)]
    screen.quad(*ok, OK_LIGHT, OK_LIGHT, OK_LIGHT, OK_LIGHT)
    fault = Builder()
    er = [on_face(0.86, 0.72, 0.006), on_face(0.93, 0.72, 0.006), on_face(0.93, 0.8, 0.006), on_face(0.86, 0.8, 0.006)]
    fault.quad(*er, ERROR_LIGHT, ERROR_LIGHT, ERROR_LIGHT, ERROR_LIGHT)
    lamp = Builder()
    lamp_c = hub + face_dir * 0.2
    for k in range(3):
        disc(lamp, lamp_c + face_dir * (0.01 * k), face_dir, 0.06 - 0.015 * k, SCREEN_LINE, 10, (1.0, 1.0, 1.0))
    rod(lamp, hub, lamp_c, 0.02, SCREEN)

    return [("base", base), ("before_beacon_1", broken), ("beacon_1", s1), ("beacon_2", s2), ("beacon_3", s3),
            ("beacon_3_glow", screen), ("before_beacon_3_glow", fault), ("beacon_launch_glow", lamp)]


# ==============================================================================
# The crew module: the whole cabin, outside and in (v0.6 round three)
# ==============================================================================
#
# "船舱应该做成一个完整的模型，可进入，镂空，有透明部分（窗）里面的设施也在". One model, the
# size of the room: the hull with a door in its south side and windows, the room inside it with
# the benches' spots along the back wall, and the ends where the next module docks. The Hero
# walks in through the door; while he is inside, the roof and the front wall above the sill fade
# so the camera sees him at work (Cabin.gd).
#
# Blender axes: X along the module (east), +Y the back wall (north), -Y the front (south, the
# door, the camera's side), Z up; the deck is the ground, z = 0.
#
# PARTS, by name (the game reads them):
#   hull          always drawn: the deck, the back wall to the eaves, the front wall to the sill,
#                 the bulkheads and the ends, and what lies about inside
#   fade_*        faded while he is inside: the roof and the front above the sill ("fade_shell"),
#                 the front windows' glass ("fade_glass"), the ceiling lamp ("fade_lamp_glow")
#   glass         the back windows' panes (see-through, Cabin.gd gives it glass)
#   door          the hatch's door, which slides east into the wall as he comes up to it
#   Head, Muzzle  the ship's turret on the engine end (Tower.gd turns Head, fires from Muzzle)
#   spot_<bench>  where each bench stands; spot_door, in front of the door; port_west and
#                 port_east, where the next modules dock (GAME-DESIGN 8.2)

from generate_props import _turret_head, SOIL, SOIL_LIGHT, MOSS, SCORCH, SOLAR, SOLAR_LINE  # noqa: E402

# The hull's section, inside and out: superellipses across (y, z) about a centre 1 m up, squarer
# than the old pod's -- near-vertical walls to head height, a rounded roof. Inside is 2.6 m
# across the floor and 2.5 m high; outside 2.84 across and 2.62 high: three cells of the
# building grid deep with a hand's breadth to spare.
MOD_IN = (1.30, 1.50, 1.00)       # half-depth, half-height, centre height
MOD_OUT = (1.42, 1.62, 1.00)
MOD_N = 6.0
MOD_X_IN = 2.8                    # the bulkheads' inner faces
MOD_X_OUT = 2.92                  # and outer
SILL = 1.0                        # the front wall above this fades
EAVES = 2.0                       # the roof: everything above this fades
DOOR = (-0.6, 0.6, 1.8)           # x from, x to, height
FRONT_WINDOWS = [(-2.05, -1.35), (1.35, 2.05)]
FRONT_WINDOW_Z = (1.05, 1.6)
BACK_WINDOWS = [(-1.05, -0.65), (0.65, 1.05)]
BACK_WINDOW_Z = (1.45, 1.85)
BAND_X = (2.1, 2.4)               # the orange band round the hull, towards the engine end
GLASS = (0.55, 0.72, 0.80)


def _se(shape, t):
    ry, rz, zc = shape
    c, s = math.cos(t), math.sin(t)
    return (ry * math.copysign(abs(c) ** (2.0 / MOD_N), c), zc + rz * math.copysign(abs(s) ** (2.0 / MOD_N), s))


def _t_back(shape, z):
    """The angle on the back wall where the section is `z` high; the front's is pi minus it."""
    ry, rz, zc = shape
    d = max(-1.0, min(1.0, (z - zc) / rz))
    return math.copysign(math.asin(min(1.0, abs(d) ** (MOD_N / 2.0))), d)


def _wall_y(shape, z, front):
    y = _se(shape, _t_back(shape, z))[0]
    return -y if front else y


def _in_hole(side_front, x0, x1, z0, z1):
    holes = []
    if side_front:
        holes.append((DOOR[0], DOOR[1], 0.0, DOOR[2]))
        holes += [(a, b, FRONT_WINDOW_Z[0], FRONT_WINDOW_Z[1]) for (a, b) in FRONT_WINDOWS]
    else:
        holes += [(a, b, BACK_WINDOW_Z[0], BACK_WINDOW_Z[1]) for (a, b) in BACK_WINDOWS]
    for (a, b, c, d) in holes:
        if x0 >= a - 1e-6 and x1 <= b + 1e-6 and z0 >= c - 1e-6 and z1 <= d + 1e-6:
            return True
    return False


def module(seed):
    rng = random.Random(seed)
    hull, fade, fade_glass, glass, lamp, door = Builder(), Builder(), Builder(), Builder(), Builder(), Builder()

    xs = sorted(set([-MOD_X_IN, MOD_X_IN, DOOR[0], DOOR[1], BAND_X[0], BAND_X[1], -BAND_X[1], -BAND_X[0]]
                    + [x for w in FRONT_WINDOWS + BACK_WINDOWS for x in w]
                    + [-2.8 + 0.35 * i for i in range(17)]))
    xs = [x for x in xs if -MOD_X_IN - 1e-6 <= x <= MOD_X_IN + 1e-6]

    def out_x(x):
        return math.copysign(MOD_X_OUT, x) if abs(abs(x) - MOD_X_IN) < 1e-6 else x

    def inner_col(z, x, front):
        if z < 0.84:
            return jitter(WAINSCOT, rng, 0.01)
        if z < 0.90:
            return GUNMETAL
        if z < 1.00:
            return HAZARD
        return jitter(PANEL if int((x + 2.8) / 0.7) % 2 == 0 else PANEL_ALT, rng, 0.008)

    # The plating outside: off-white gone grey with weather -- the camera looks down on it, and a
    # clean white slab from above was the brightest thing in the valley -- in panels a shade apart,
    # grimed towards the ground and scorched towards the shield end.
    PLATE = mix(METAL, (0.52, 0.50, 0.46), 0.35)

    def outer_col(z, x):
        if BAND_X[0] <= x <= BAND_X[1]:
            base = mix(HAZARD, SCORCH, 0.12)
        else:
            base = PLATE if int(math.floor((x + 3.0) / 0.7)) % 2 == 0 else mix(PLATE, (0.40, 0.40, 0.38), 0.18)
        burn = max(0.0, (-1.2 - x)) * 0.35 + (0.2 if rng.random() < 0.05 else 0.0)
        c = mix(base, SCORCH, min(0.75, burn))
        if z < 0.6:
            c = mix(c, SOIL_LIGHT, 0.5 * (1.0 - z / 0.6))
        return jitter(c, rng, 0.02)

    # --- The walls, row by row, both faces --------------------------------------------------
    for front in (False, True):
        rows = [0.0, 0.42, 0.84, 0.90, 1.0, EAVES]
        rows += list(BACK_WINDOW_Z) if not front else [FRONT_WINDOW_Z[0], FRONT_WINDOW_Z[1], DOOR[2]]
        rows = sorted(set(rows))
        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            for j in range(len(rows) - 1):
                z0, z1 = rows[j], rows[j + 1]
                if _in_hole(front, x0, x1, z0, z1):
                    continue
                part = fade if (front and z0 >= SILL - 1e-6) else hull
                zm = (z0 + z1) * 0.5
                yi0, yi1 = _wall_y(MOD_IN, z0, front), _wall_y(MOD_IN, z1, front)
                yo0, yo1 = _wall_y(MOD_OUT, z0, front), _wall_y(MOD_OUT, z1, front)
                ci = inner_col(zm, (x0 + x1) * 0.5, front)
                a, b, c, d = (Vector((x0, yi0, z0)), Vector((x1, yi0, z0)), Vector((x1, yi1, z1)), Vector((x0, yi1, z1)))
                if front:
                    part.quad(b, a, d, c, ci, ci, ci, ci)
                else:
                    part.quad(a, b, c, d, ci, ci, ci, ci)
                co = outer_col(zm, (x0 + x1) * 0.5)
                ox0, ox1 = out_x(x0), out_x(x1)
                a, b, c, d = (Vector((ox0, yo0, z0)), Vector((ox1, yo0, z0)), Vector((ox1, yo1, z1)), Vector((ox0, yo1, z1)))
                if front:
                    part.quad(a, b, c, d, co, co, co, co)
                else:
                    part.quad(b, a, d, c, co, co, co, co)
        # Where the fading stops, the wall's thickness shows: a cap along the cut.
        cut = SILL if front else EAVES
        yi, yo = _wall_y(MOD_IN, cut, front), _wall_y(MOD_OUT, cut, front)
        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            if front and x0 >= DOOR[0] - 1e-6 and x1 <= DOOR[1] + 1e-6:
                continue
            hull.quad(Vector((x0, yi, cut)), Vector((x1, yi, cut)), Vector((out_x(x1), yo, cut)), Vector((out_x(x0), yo, cut)),
                      GUNMETAL, GUNMETAL, METAL_DARK, METAL_DARK)

    # --- The roof: over the eaves from the back to the front, faded ---------------------------
    tb_in, tb_out = _t_back(MOD_IN, EAVES), _t_back(MOD_OUT, EAVES)
    steps = 12
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        for k in range(steps):
            f0, f1 = k / steps, (k + 1) / steps
            ti0, ti1 = tb_in + (math.pi - 2 * tb_in) * f0, tb_in + (math.pi - 2 * tb_in) * f1
            to0, to1 = tb_out + (math.pi - 2 * tb_out) * f0, tb_out + (math.pi - 2 * tb_out) * f1
            (ya, za), (yb, zb) = _se(MOD_IN, ti0), _se(MOD_IN, ti1)
            ci = jitter(PANEL if int((x0 + 2.8) / 0.7) % 2 == 0 else PANEL_ALT, rng, 0.008)
            fade.quad(Vector((x0, ya, za)), Vector((x1, ya, za)), Vector((x1, yb, zb)), Vector((x0, yb, zb)), ci, ci, ci, ci)
            (ya, za), (yb, zb) = _se(MOD_OUT, to0), _se(MOD_OUT, to1)
            co = outer_col(2.2, (x0 + x1) * 0.5)
            fade.quad(Vector((out_x(x1), ya, za)), Vector((out_x(x0), ya, za)), Vector((out_x(x0), yb, zb)), Vector((out_x(x1), yb, zb)),
                      co, co, co, co)

    # --- The openings: jambs through the wall, glass in the windows ---------------------------
    def jamb(front, x0, x1, z0, z1, col, part, sill=True):
        rows = [z0 + (z1 - z0) * k / 6 for k in range(7)]
        for x in (x0, x1):
            for k in range(6):
                za, zb = rows[k], rows[k + 1]
                p = [Vector((x, _wall_y(MOD_IN, za, front), za)), Vector((x, _wall_y(MOD_OUT, za, front), za)),
                     Vector((x, _wall_y(MOD_OUT, zb, front), zb)), Vector((x, _wall_y(MOD_IN, zb, front), zb))]
                part.quad(p[0], p[1], p[2], p[3], col, col, col, col)
        for z in ((z0, z1) if sill else (z1,)):
            yi, yo = _wall_y(MOD_IN, z, front), _wall_y(MOD_OUT, z, front)
            part.quad(Vector((x0, yi, z)), Vector((x1, yi, z)), Vector((x1, yo, z)), Vector((x0, yo, z)), col, col, col, col)

    def pane(front, x0, x1, z0, z1, part):
        yi0, yo0 = _wall_y(MOD_IN, z0, front), _wall_y(MOD_OUT, z0, front)
        yi1, yo1 = _wall_y(MOD_IN, z1, front), _wall_y(MOD_OUT, z1, front)
        y0, y1 = (yi0 + yo0) * 0.5, (yi1 + yo1) * 0.5
        part.quad(Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z1)), Vector((x0, y1, z1)),
                  GLASS, GLASS, mix(GLASS, (1.0, 1.0, 1.0), 0.3), mix(GLASS, (1.0, 1.0, 1.0), 0.3))

    jamb(True, DOOR[0], DOOR[1], 0.0, DOOR[2], HAZARD, hull, sill=False)
    for (a, b) in FRONT_WINDOWS:
        jamb(True, a, b, FRONT_WINDOW_Z[0], FRONT_WINDOW_Z[1], GUNMETAL, fade)
        pane(True, a, b, FRONT_WINDOW_Z[0], FRONT_WINDOW_Z[1], fade_glass)
    for (a, b) in BACK_WINDOWS:
        jamb(False, a, b, BACK_WINDOW_Z[0], BACK_WINDOW_Z[1], GUNMETAL, hull)
        pane(False, a, b, BACK_WINDOW_Z[0], BACK_WINDOW_Z[1], glass)
    # The door's threshold, striped, and a frame proud of the hull outside.
    y_sill = _wall_y(MOD_OUT, 0.0, True)
    for s in range(6):
        xa, xb = DOOR[0] + (DOOR[1] - DOOR[0]) * s / 6, DOOR[0] + (DOOR[1] - DOOR[0]) * (s + 1) / 6
        col = HAZARD if s % 2 == 0 else GUNMETAL
        hull.quad(Vector((xa, y_sill - 0.06, 0.012)), Vector((xb, y_sill - 0.06, 0.012)),
                  Vector((xb, _wall_y(MOD_IN, 0.0, True) + 0.05, 0.012)), Vector((xa, _wall_y(MOD_IN, 0.0, True) + 0.05, 0.012)),
                  col, col, col, col)

    # The door: a slab in the wall's thickness, striped outside, with a slit of glass. Cabin.gd
    # slides it east, into the wall beside the opening.
    y_door = (_wall_y(MOD_IN, 0.9, True) + _wall_y(MOD_OUT, 0.9, True)) * 0.5
    box(door, (DOOR[0] - 0.04, y_door - 0.025, 0.0), (DOOR[1] + 0.04, y_door + 0.025, DOOR[2] + 0.02), METAL)
    for s in range(5):
        za = 0.15 + s * 0.3
        beam(door, Vector((DOOR[0] + 0.08, y_door - 0.03, za)), Vector((DOOR[1] - 0.08, y_door - 0.03, za + 0.18)),
             0.07, 0.01, HAZARD, up=Vector((0.0, -1.0, 0.0)))
    door.quad(Vector((-0.12, y_door - 0.031, 1.3)), Vector((0.12, y_door - 0.031, 1.3)),
              Vector((0.12, y_door - 0.031, 1.62)), Vector((-0.12, y_door - 0.031, 1.62)), LENS, LENS, LENS, LENS)

    # --- The bulkheads: flat ends, inside and out ---------------------------------------------
    def outline(shape):
        t0 = _t_back(shape, 0.0)
        pts = [Vector((0.0, *_se(shape, t0 + (math.pi - 2 * t0) * k / 30))) for k in range(31)]
        return pts

    for sign in (-1.0, 1.0):
        for (shape, xe, inward) in ((MOD_IN, MOD_X_IN, True), (MOD_OUT, MOD_X_OUT, False)):
            ring = outline(shape)
            centre = Vector((sign * xe, 0.0, 1.1))
            for k in range(len(ring)):
                a = ring[k] + Vector((sign * xe, 0.0, 0.0))
                c = ring[(k + 1) % len(ring)] + Vector((sign * xe, 0.0, 0.0))
                if inward:
                    col = WAINSCOT if min(a.z, c.z) < 0.84 else PANEL_ALT
                else:
                    col = outer_col(min(a.z, c.z), sign * 2.9)
                if (sign > 0) == inward:
                    hull.tri(c, a, centre, col, col, mix(col, PANEL, 0.3))
                else:
                    hull.tri(a, c, centre, col, col, mix(col, PANEL, 0.3))

    # --- The ends: the heat shield ploughed into the earth (west), the engine and the gun (east)
    dome = []
    for (x, sc) in ((-2.92, 1.0), (-3.08, 0.93), (-3.22, 0.76), (-3.32, 0.5), (-3.37, 0.22)):
        dome.append([Vector((x, y * sc, 1.0 + (z - 1.0) * sc)) for (y, z) in
                     (_se(MOD_OUT, math.tau * k / 28) for k in range(28))])
    for j in range(len(dome) - 1):
        for k in range(28):
            k2 = (k + 1) % 28
            col = HEAT_TILE_LIGHT if (k + j) % 2 == 0 else HEAT_TILE
            pts = [dome[j][k], dome[j][k2], dome[j + 1][k2], dome[j + 1][k]]
            pts = [Vector((p.x, p.y, max(0.0, p.z))) for p in pts]
            hull.quad(pts[1], pts[0], pts[3], pts[2], col, col, col, col)
    tip = Vector((-3.40, 0.0, 1.0))
    for k in range(28):
        a, c = dome[-1][k], dome[-1][(k + 1) % 28]
        hull.tri(c, a, tip, HEAT_TILE, HEAT_TILE, SCORCH)
    # Earth thrown up round the shield where it dug in.
    mound_c = Vector((-3.1, 0.0, 0.0))
    ring_n = 18
    outer_r = [mound_c + Vector((math.cos(math.tau * i / ring_n) * rng.uniform(0.3, 0.42),
                                 math.sin(math.tau * i / ring_n) * rng.uniform(1.35, 1.5), 0.0)) for i in range(ring_n)]
    inner_r = [mound_c + Vector((math.cos(math.tau * i / ring_n) * 0.22, math.sin(math.tau * i / ring_n) * 1.2,
                                 rng.uniform(0.28, 0.4))) for i in range(ring_n)]
    for i in range(ring_n):
        i2 = (i + 1) % ring_n
        hull.quad(outer_r[i], outer_r[i2], inner_r[i2], inner_r[i], SOIL, SOIL, SOIL_LIGHT, SOIL_LIGHT)

    # The engine end: a service ring, a bulkhead, a stubby nozzle.
    svc = [[Vector((x, y * sc, 1.0 + (z - 1.0) * sc)) for (y, z) in (_se(MOD_OUT, math.tau * k / 28) for k in range(28))]
           for (x, sc) in ((2.92, 1.0), (3.02, 0.97), (3.18, 0.94))]
    for j in range(len(svc) - 1):
        for k in range(28):
            k2 = (k + 1) % 28
            col = GUNMETAL if j == 0 else METAL_DARK
            pts = [Vector((p.x, p.y, max(0.0, p.z))) for p in (svc[j][k], svc[j][k2], svc[j + 1][k2], svc[j + 1][k])]
            hull.quad(pts[0], pts[1], pts[2], pts[3], col, col, col, col)
    hub = Vector((3.18, 0.0, 1.0))
    for k in range(28):
        a, c = svc[-1][k], svc[-1][(k + 1) % 28]
        hull.tri(Vector((a.x, a.y, max(0.0, a.z))), Vector((c.x, c.y, max(0.0, c.z))), hub, METAL_DARK, METAL_DARK, GUNMETAL)
    hull.tube([Vector((3.18, 0.0, 1.0)), Vector((3.32, 0.0, 1.0)), Vector((3.45, 0.0, 1.0))],
              [0.36, 0.42, 0.5], [GUNMETAL, METAL_DARK, SCORCH], 14)
    # The gun's pylon on the service ring's top.
    top_z = _se(MOD_OUT, math.pi / 2)[1] * 0.94 + 1.0 * 0.06
    pylon = Vector((3.08, 0.0, top_z - 0.1))
    hull.tube([pylon, pylon + UP * 0.2], [0.16, 0.13], [METAL_DARK, METAL_DARK], 12)
    pivot = pylon + UP * 0.2

    # --- On the roof, what the camera sees most of (faded with it): a darker walkway along the
    # ridge, the seams between its plates, a dorsal hatch, vents -----------------------------------
    ridge = _se(MOD_OUT, math.pi / 2)[1]
    walk_w = 0.32
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        if BAND_X[0] <= (x0 + x1) * 0.5 <= BAND_X[1]:
            continue
        col = jitter(mix(GUNMETAL, METAL_DARK, 0.5), rng, 0.02)
        fade.quad(Vector((out_x(x0), -walk_w, ridge + 0.006)), Vector((out_x(x1), -walk_w, ridge + 0.006)),
                  Vector((out_x(x1), walk_w, ridge + 0.006)), Vector((out_x(x0), walk_w, ridge + 0.006)), col, col, col, col)
    # Seams across the roof every plate, a dark line over the crown.
    for k in range(-4, 5):
        xs_ = k * 0.7
        tb = _t_back(MOD_OUT, EAVES)
        for j in range(12):
            ta = tb + (math.pi - 2 * tb) * j / 12
            tt = tb + (math.pi - 2 * tb) * (j + 1) / 12
            (ya, za), (yb, zb) = _se(MOD_OUT, ta), _se(MOD_OUT, tt)
            fade.quad(Vector((xs_ - 0.012, ya, za + 0.004)), Vector((xs_ + 0.012, ya, za + 0.004)),
                      Vector((xs_ + 0.012, yb, zb + 0.004)), Vector((xs_ - 0.012, yb, zb + 0.004)),
                      METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)
    # The dorsal hatch: a square with a raised frame and a wheel, towards the engine end.
    hc = Vector((0.95, 0.0, ridge + 0.01))
    box(fade, (hc.x - 0.36, -0.36, hc.z), (hc.x + 0.36, 0.36, hc.z + 0.05), GUNMETAL)
    box(fade, (hc.x - 0.3, -0.3, hc.z + 0.05), (hc.x + 0.3, 0.3, hc.z + 0.07), mix(PLATE, SCORCH, 0.15))
    annulus(fade, hc + Vector((0.0, 0.0, 0.075)), Vector((0.0, 0.0, 1.0)), 0.09, 0.13, HAZARD, 12)
    # Vents in a row near the back edge of the roof.
    for vx in (-2.2, -1.75, -0.3, 0.2):
        vy = 0.78
        vz = _se(MOD_OUT, math.acos(min(1.0, (vy / MOD_OUT[0]) ** (MOD_N / 2.0))))[1]
        box(fade, (vx - 0.14, vy - 0.08, vz - 0.02), (vx + 0.14, vy + 0.08, vz + 0.06), METAL_DARK)
        for g in range(3):
            gy = vy - 0.05 + g * 0.05
            box(fade, (vx - 0.12, gy - 0.008, vz + 0.06), (vx + 0.12, gy + 0.008, vz + 0.065), SCORCH)

    # --- The roof's wreckage: a torn solar panel and a bent antenna (faded with the roof) ------
    roof_z = _se(MOD_OUT, math.pi / 2)[1]
    root = Vector((-1.2, 0.35, roof_z - 0.02))
    fade.tube([root, root + Vector((0.0, 0.1, 0.22))], [0.05, 0.04], [METAL_DARK, METAL_DARK], 6)
    pa, pb = root + Vector((-0.7, 0.05, 0.2)), root + Vector((0.6, 0.2, 0.26))
    pc, pd = root + Vector((0.5, 0.8, 0.56)), root + Vector((-0.3, 0.68, 0.6))
    fade.quad(pa, pb, pc, pd, SOLAR, SOLAR, SOLAR, SOLAR)
    back = (pb - pa).cross(pd - pa).normalized() * -0.025
    fade.quad(pd + back, pc + back, pb + back, pa + back, METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)
    for t in (0.33, 0.66):
        l0, l1 = pa.lerp(pd, t), pb.lerp(pc, t)
        fade.quad(l0, l1, l1 + Vector((0.0, 0.0, 0.015)), l0 + Vector((0.0, 0.0, 0.015)),
                  SOLAR_LINE, SOLAR_LINE, SOLAR_LINE, SOLAR_LINE)
    mast = Vector((1.4, -0.3, roof_z - 0.02))
    fade.tube([mast, mast + Vector((0.02, 0.0, 0.3)), mast + Vector((0.2, -0.06, 0.45))],
              [0.035, 0.025, 0.018], [METAL_DARK, METAL, HAZARD], 6)

    # --- Inside: the deck, ribs, the lamp, what lies about -----------------------------------
    y_back, y_front = _wall_y(MOD_IN, 0.0, False), _wall_y(MOD_IN, 0.0, True)
    for i in range(8):
        xa, xb = -MOD_X_IN + 2 * MOD_X_IN * i / 8, -MOD_X_IN + 2 * MOD_X_IN * (i + 1) / 8
        for j in range(4):
            ya, yb = y_front + (y_back - y_front) * j / 4, y_front + (y_back - y_front) * (j + 1) / 4
            col = jitter(DECK if (i + j) % 2 == 0 else DECK_ALT, rng, 0.006)
            hull.quad(Vector((xa, ya, 0.005)), Vector((xb, ya, 0.005)), Vector((xb, yb, 0.005)), Vector((xa, yb, 0.005)),
                      col, col, col, col)
    fine_t = [_t_back(MOD_IN, 0.0) + (math.pi - 2 * _t_back(MOD_IN, 0.0)) * k / 32 for k in range(33)]
    for xr in (-2.45, -0.3, 0.3, 2.45):
        for k in range(len(fine_t) - 1):
            (ya, za), (yb, zb) = _se(MOD_IN, fine_t[k]), _se(MOD_IN, fine_t[k + 1])
            pa, pb = Vector((0.0, ya, za)), Vector((0.0, yb, zb))
            n_a = Vector((0.0, -ya, 1.0 - za)).normalized() * 0.06
            n_b = Vector((0.0, -yb, 1.0 - zb)).normalized() * 0.06
            ox0, ox1 = Vector((xr - 0.05, 0.0, 0.0)), Vector((xr + 0.05, 0.0, 0.0))
            front_side = ya < 0 and yb < 0
            part = fade if (min(za, zb) >= EAVES - 1e-6 or (front_side and min(za, zb) >= SILL - 1e-6)) else hull
            part.quad(pa + n_a + ox0, pa + n_a + ox1, pb + n_b + ox1, pb + n_b + ox0, METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)
            part.quad(pa + ox0, pa + n_a + ox0, pb + n_b + ox0, pb + ox0, GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)
            part.quad(pa + n_a + ox1, pa + ox1, pb + ox1, pb + n_b + ox1, GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)
    lamp_z = _se(MOD_IN, math.pi / 2)[1] - 0.05
    box(fade, (-2.25, -0.11, lamp_z - 0.03), (2.25, 0.11, lamp_z + 0.04), METAL_DARK)
    lamp.quad(Vector((-2.15, 0.07, lamp_z - 0.032)), Vector((-2.15, -0.07, lamp_z - 0.032)),
              Vector((2.15, -0.07, lamp_z - 0.032)), Vector((2.15, 0.07, lamp_z - 0.032)), LAMP, LAMP, LAMP, LAMP)
    rug_c = Vector((0.0, -0.25, 0.012))
    rim = [rug_c + Vector((math.cos(math.tau * k / 11) * 0.72 * rng.uniform(0.85, 1.1),
                           math.sin(math.tau * k / 11) * 0.4 * rng.uniform(0.85, 1.1), 0.0)) for k in range(11)]
    for k in range(11):
        hull.tri(rim[k], rim[(k + 1) % 11], rug_c, HIDE_EDGE, HIDE_EDGE, HIDE)
    bed = Vector((-2.55, 0.75, 0.0))
    hull.tube([bed, bed + UP * 0.62], [0.13, 0.13], [HIDE_EDGE, HIDE], 9)
    lashing(hull, bed + UP * 0.2, UP, 0.135, rng)
    lashing(hull, bed + UP * 0.45, UP, 0.135, rng)
    tank = Vector((2.55, 0.78, 0.0))
    hull.tube([tank, tank + UP * 0.30, tank + UP * 0.36, tank + UP * 0.72], [0.19, 0.19, 0.19, 0.17],
              [METAL, METAL, HAZARD, METAL], 12)
    for (p0, p1) in ((Vector((-2.55, -0.55, 0.07)), Vector((-2.55, 0.1, 0.07))),
                     (Vector((-2.4, -0.55, 0.07)), Vector((-2.4, 0.1, 0.07))),
                     (Vector((-2.47, -0.5, 0.2)), Vector((-2.47, 0.12, 0.2)))):
        _log(hull, p0, p1, 0.07, rng)

    # --- Where things stand -------------------------------------------------------------------
    # Each bench with its back to the back wall (Config.CABIN.station_sizes: their depths).
    spots = {"workbench": Vector((-1.75, y_back - 0.37, 0.0)), "kitchen": Vector((0.0, y_back - 0.44, 0.0)),
             "beacon": Vector((1.75, y_back - 0.41, 0.0)),
             "door": Vector((0.0, _wall_y(MOD_OUT, 0.0, True) - 0.6, 0.0))}
    ports = {"west": Vector((-3.5, 0.0, 1.0)), "east": Vector((3.5, 0.0, 1.0))}
    head, muzzle = _turret_head(1.0)
    parts = [("hull", hull), ("fade_shell", fade), ("fade_glass", fade_glass), ("glass", glass),
             ("fade_lamp_glow", lamp), ("door", door)]
    return parts, spots, {"ports": ports, "head": (head, pivot, muzzle)}


# ==============================================================================
# Export
# ==============================================================================

MODELS = {
    "module": (module, 23),
    "workbench": (workbench, 11),
    "kitchen": (kitchen, 13),
    "beacon": (beacon, 17),
}


def build_model(name, fn, seed, mat):
    made = fn(seed)
    spots = {}
    extra = {}
    if isinstance(made, tuple):
        if len(made) == 3:
            made, spots, extra = made
        else:
            made, spots = made
    objs = []
    for part, builder in made:
        if not builder.verts:
            continue
        objs.append(builder.to_object(part, [mat]))
    for station_id, at in spots.items():
        e = bpy.data.objects.new("spot_" + station_id, None)
        bpy.context.scene.collection.objects.link(e)
        e.location = at
        objs.append(e)
    for port_id, at in extra.get("ports", {}).items():
        e = bpy.data.objects.new("port_" + port_id, None)
        bpy.context.scene.collection.objects.link(e)
        e.location = at
        objs.append(e)
    if "head" in extra:
        # Named for the game: Tower.gd turns the node called Head and fires from Muzzle.
        head_b, pivot, muzzle = extra["head"]
        head = head_b.to_object("Head", [mat])
        head.location = pivot
        tip = bpy.data.objects.new("Muzzle", None)
        bpy.context.scene.collection.objects.link(tip)
        tip.parent = head
        tip.location = muzzle
        objs += [head, tip]
    return objs


def bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != 'MESH':
            continue
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    return lo, hi


def preview(name, objs):
    """One model under a warm lamp, from about where the game's cabin camera stands."""
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    lo, hi = bounds(objs)
    size = hi - lo
    mid = (lo + hi) * 0.5
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    bpy.ops.object.light_add(type='AREA', location=(mid.x, mid.y - size.y - 1.5, hi.z + 1.5))
    key = bpy.context.active_object
    key.data.energy = 400.0 * max(1.0, size.x)
    key.data.size = 3.0
    key.rotation_euler = (math.radians(50), 0.0, 0.0)
    bpy.ops.object.empty_add(location=(mid.x, mid.y, mid.z * 0.8))
    aim = bpy.context.active_object
    dist = max(size.x, size.z) * 1.35 + 0.6
    bpy.ops.object.camera_add(location=(mid.x, mid.y - dist, mid.z + dist * 0.35))
    cam = bpy.context.active_object
    tr = cam.constraints.new('TRACK_TO')
    tr.target = aim
    tr.track_axis = 'TRACK_NEGATIVE_Z'
    tr.up_axis = 'UP_Y'
    scene.camera = cam
    cam.data.lens = 32
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(PREVIEW_DIR, "cabin_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[OK] preview:", scene.render.filepath)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in args if not a.startswith("--")]
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (fn, seed) in MODELS.items():
        if only and name not in only:
            continue
        reset()
        mat = vertex_colour_material("CabinVertex", 0.85, True)
        objs = build_model(name, fn, seed, mat)
        path = os.path.join(OUT_DIR, "%s_a.glb" % name)
        export_objects(objs, path)
        lo, hi = bounds(objs)
        tris = sum(len(o.data.polygons) for o in objs if o.type == 'MESH')
        print("[OK] %-10s %6d triangles  %.2f x %.2f x %.2f m (x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f)  parts: %s" % (
            name, tris, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z,
            ", ".join(o.name for o in objs)))
        if "--preview" in args:
            preview(name, objs)


if __name__ == "__main__":
    main()
