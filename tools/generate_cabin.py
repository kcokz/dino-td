# tools/generate_cabin.py
# The cabin: the crew module the Hero lives in, outside and in, and the three things that stand
# along its back wall inside -- the workbench, the healing pod, the beacon -- each with the pieces
# that appear on it as the run goes on.
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
#   before_<job id>   shown until it is done: the beacon's broken mast is "before_beacon_1"
#   anything else     always shown
#
# and a name ending in "_glow" is drawn lit by itself -- the pod's fluid, a screen, the ceiling's
# lamp -- and lights the room round it. So a bench's upgrades are named after the jobs that make
# them, and a new tool is a recipe in Config and a part here with its id.
#
# The module also carries empties named "spot_<station id>": where each bench stands.

import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import Builder, mix, jitter, vertex_colour_material, reset, UP, PREVIEW_DIR  # noqa: E402
from generate_props import (_boulder, _log, _bone, _rope_coil, export_objects,  # noqa: E402
                            BARK, BARK_LIGHT, FRESH_WOOD, VINE, VINE_DARK, ROCK_DARK, ROCK, ROCK_LIGHT,
                            METAL, METAL_DARK, GUNMETAL, HAZARD, LENS, BONE, HEAT_TILE, HEAT_TILE_LIGHT)
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
# The pod's nutrient fluid: blue-green, deeper where the column is thin, paler at its surface and
# where it bubbles.
FLUID = (0.16, 0.86, 0.70)
FLUID_DEEP = (0.03, 0.50, 0.50)
FLUID_PALE = (0.62, 1.00, 0.90)
BUBBLE = (0.88, 1.00, 0.97)
SCREEN = (0.34, 0.84, 0.96)
SCREEN_LINE = (0.70, 0.97, 1.00)
OK_LIGHT = (0.40, 0.95, 0.45)
ERROR_LIGHT = (0.98, 0.16, 0.10)
AMBER_LIGHT = (1.00, 0.62, 0.14)
ROPE = (0.36, 0.30, 0.16)


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
    for x in (-0.33, 0.0, 0.30):
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

    # The hand-drawn map (v0.6 round five), spread on the top at the back left where it was drawn: a hide
    # scraped thin, its edge ragged, the valley inked on it -- the river down one side, a path, a cross
    # where the cabin is.
    hide_map = Builder()
    turn = math.radians(-8.0)
    centre = Vector((-0.46, 0.18, top_z + 0.004))

    def on_map(u, v, lift=0.0):
        """The point `u` across and `v` along the map from its middle, on the bench top."""
        return centre + Vector((u * math.cos(turn) - v * math.sin(turn), u * math.sin(turn) + v * math.cos(turn),
                                lift))

    rim = []
    for k in range(14):
        a = math.tau * k / 14
        r = rng.uniform(0.9, 1.04)
        rim.append(on_map(math.cos(a) * 0.12 * r, math.sin(a) * 0.09 * r))
    scraped = mix(HIDE, (0.86, 0.74, 0.56), 0.55)
    for k in range(14):
        hide_map.tri(on_map(0.0, 0.0), rim[k], rim[(k + 1) % 14], scraped, mix(scraped, HIDE_EDGE, 0.6),
                     mix(scraped, HIDE_EDGE, 0.6))

    def inked(points, width, col):
        """A line of ink along `points` (map coordinates), a hair above the hide."""
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            along = Vector((u1 - u0, v1 - v0, 0.0)).normalized()
            side = Vector((-along.y, along.x, 0.0)) * width * 0.5
            hide_map.quad(on_map(u0 - side.x, v0 - side.y, 0.001), on_map(u1 - side.x, v1 - side.y, 0.001),
                          on_map(u1 + side.x, v1 + side.y, 0.001), on_map(u0 + side.x, v0 + side.y, 0.001),
                          col, col, col, col)

    ink = (0.10, 0.07, 0.05)
    inked([(-0.085, -0.07), (-0.07, -0.02), (-0.09, 0.03), (-0.075, 0.075)], 0.012, (0.20, 0.30, 0.36))
    inked([(-0.02, -0.06), (0.01, -0.01), (0.03, 0.02), (0.07, 0.05)], 0.005, ink)
    inked([(0.015, -0.02), (0.045, 0.005)], 0.006, ink)
    inked([(0.015, 0.005), (0.045, -0.02)], 0.006, ink)

    # The bone shovel (the second station's: GAME-DESIGN 5.2, "骨铲（肩胛骨）"), hung from a peg of its own at the
    # board's lower left, below the pick's head: a dinosaur's shoulder blade bound by its narrow end to a short haft
    # -- the blade down, its broad digging edge smeared with the river's blue-grey clay, the ridge of the blade's
    # spine across its face -- the haft's top hung over the peg by a loop of cord.
    shovel = Builder()
    xc, zn, yb = -0.47, 0.87, 0.272          # its middle line, the blade's neck, and the blade's face off the board
    rod(shovel, Vector((xc, 0.29, 1.15)), Vector((xc, 0.235, 1.165)), 0.011, GUNMETAL)
    rod(shovel, Vector((xc, 0.262, zn - 0.005)), Vector((xc, 0.262, zn + 0.255)), 0.016, BARK_LIGHT, col1=FRESH_WOOD)
    for side in (-1.0, 1.0):
        rod(shovel, Vector((xc + side * 0.011, 0.258, zn + 0.245)), Vector((xc, 0.236, 1.172)), 0.0045, ROPE, sides=4)
    outline = [(-0.022, 0.0), (-0.034, -0.05), (-0.05, -0.1), (-0.063, -0.148), (-0.06, -0.178), (-0.036, -0.192),
               (0.0, -0.198), (0.036, -0.195), (0.061, -0.184), (0.07, -0.165), (0.062, -0.13), (0.046, -0.085),
               (0.03, -0.04), (0.022, 0.0)]
    clay = (0.36, 0.4, 0.41)

    def blade_col(dz, lift):
        c = mix(BONE, (0.93, 0.9, 0.82), 0.25 * lift)
        return mix(c, clay, 0.75 * max(0.0, (-dz - 0.15) / 0.05))   # the digging edge, smeared with clay
    front = [Vector((xc + dx, yb - 0.006, zn + dz)) for (dx, dz) in outline]
    back = [Vector((xc + dx, yb + 0.006, zn + dz)) for (dx, dz) in outline]
    mid_f = Vector((xc + 0.004, yb - 0.011, zn - 0.11))
    mid_b = Vector((xc + 0.004, yb + 0.006, zn - 0.11))
    n = len(outline)
    for k in range(n - 1):
        (dx0, dz0), (dx1, dz1) = outline[k], outline[k + 1]
        shovel.tri(front[k], mid_f, front[k + 1], blade_col(dz0, 1.0), blade_col(-0.11, 0.6), blade_col(dz1, 1.0))
        shovel.tri(back[k + 1], mid_b, back[k], blade_col(dz1, 0.0), blade_col(-0.11, 0.0), blade_col(dz0, 0.0))
        rim = mix(BONE, ROCK_DARK, 0.2)
        shovel.quad(front[k + 1], back[k + 1], back[k], front[k], blade_col(dz1, 0.0), rim, rim, blade_col(dz0, 0.0))
    shovel.tri(front[-1], mid_f, front[0], blade_col(0.0, 1.0), blade_col(-0.11, 0.6), blade_col(0.0, 1.0))
    shovel.quad(front[0], back[0], back[-1], front[-1], BONE, BONE, BONE, BONE)
    # The ridge of its spine, from the neck across the face to the far edge.
    rod(shovel, Vector((xc - 0.004, yb - 0.01, zn - 0.012)), Vector((xc + 0.052, yb - 0.01, zn - 0.165)), 0.0055,
        mix(BONE, ROCK_DARK, 0.12))
    lashing(shovel, Vector((xc, 0.264, zn + 0.012)), UP, 0.026, rng, width=0.022)

    # NOT HIS KIT any more (GAME-DESIGN 3.0, v0.7): the stone pick, the spears, the vest, the thick hide armour and
    # the boots went from the game, and from the board with them.
    return [("base", base), ("stone_pick", pick), ("stone_axe", axe), ("hide_map", hide_map), ("bone_shovel", shovel)]


# ==============================================================================
# The healing pod: the ship's regeneration tank, where he sleeps himself whole
# ==============================================================================
#
# v0.7, the player: "睡觉就能回血不错……把未来船舱的睡觉装置科幻化，有类似泡营养液式的身体完全恢复（七龙珠的泡水
# 装置），这样就不用吃东西喝水". Eating and drinking went, and the kitchen with them; where it stood against the
# back wall stands the module's medical tank. He steps up into it and floats in glowing fluid until he is whole.
#
# A bench is vertex colours and nothing see-through, so there is no glass to draw: the tank is its frame -- a
# ring at its foot, a collar at its head, six slim ribs, the two at the front the hatch's orange jambs -- and
# the fluid is the back of the column, lit from inside, its surface a pale line round the glass. A whole column
# of it, or a lid of it, would hide the man inside from the camera, which looks down into the room from the
# front: so the fluid is open towards the room and the sky, and the cap is a hub on four struts over the collar
# rather than a lid. With the collar at 1.9 m his head shows to a camera tilted 45 degrees down, his face to 60.
#
# He stands on the tank's floor at its axis, facing out through the hatch (-Y): (0, 0, POD_FLOOR). The model is
# a metre square about that axis, so fitting it to its size -- which centres it -- moves nothing. Its pipes run
# back from the base and the cap into the wall, and its spot stands it with its back to the wall.
#
# PARTS: "base" (the machine, the frame, the pipes), "fluid_glow" (the fluid, its bubbles, its surface: lit by
# itself, and it lights the room), "lights_glow" (the collar's ring of lamps and the panel's: lit by
# themselves, too small to light anything). None is a job, so all three always show.

POD_R = 0.50                     # the machine base's radius: the pod is a metre across and a metre deep
POD_FLOOR = 0.30                 # the top of the base, the floor of the tank: where he stands
POD_GLASS = 0.457                # where the glass would be: the ribs stand on it
POD_FLUID = 0.44                 # the fluid's edge, inside the glass
POD_SURFACE = 1.86               # the fluid's surface
POD_COLLAR = (1.90, 2.02)        # the collar round the head of the tank, under and over
POD_TOP = 2.10                   # the crown of the cap
POD_DOOR = math.radians(30.0)    # the hatch, this far either side of the front
POD_OPEN = math.radians(75.0)    # the fluid's back reaches round to this far either side of the front


def _round(th, r, z):
    """The point `r` out from the pod's axis and `z` up, `th` round from its front (-Y) towards +X."""
    return Vector((r * math.sin(th), -r * math.cos(th), z))


def _lathe(b, th0, th1, n, profile, cols, ends=False):
    """Turns `profile` -- (r, z) points up the outside of a ring, across its top and down its inside -- round
    the pod's axis from `th0` to `th1` in `n` steps: the base's drum, the frame's foot and collar, the cap's
    hub. Segment j is coloured cols[j], a colour or a function of the step's middle angle; `ends` closes an
    arc's two ends."""
    for i in range(n):
        a, c = th0 + (th1 - th0) * i / n, th0 + (th1 - th0) * (i + 1) / n
        mid = (a + c) * 0.5
        for j in range(len(profile) - 1):
            (r0, z0), (r1, z1) = profile[j], profile[j + 1]
            col = cols[j](mid) if callable(cols[j]) else cols[j]
            if r0 < 1e-6 and r1 < 1e-6:
                continue
            if r1 < 1e-6:
                b.tri(_round(a, r0, z0), _round(c, r0, z0), _round(a, 0.0, z1), col, col, col)
            elif r0 < 1e-6:
                b.tri(_round(a, 0.0, z0), _round(c, r1, z1), _round(a, r1, z1), col, col, col)
            else:
                b.quad(_round(a, r0, z0), _round(c, r0, z0), _round(c, r1, z1), _round(a, r1, z1), col, col, col, col)
    if ends:
        for th, flip in ((th0, False), (th1, True)):
            pts = [_round(th, r, z) for (r, z) in profile[:-1]]
            col = cols[0](th) if callable(cols[0]) else cols[0]
            for k in range(1, len(pts) - 1):
                tri = (pts[0], pts[k + 1], pts[k]) if flip else (pts[0], pts[k], pts[k + 1])
                b.tri(*tri, col, col, col)


def _through(points, steps=4):
    """A smooth run through `points` (Catmull-Rom), `steps` pieces between each two: a hose's spine."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
                              + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
    out.append(points[-1])
    return out


def _hose(b, points, r, col, col_rib):
    """A ribbed hose through `points`, its ribs a shade apart."""
    spine = _through(points, 3)
    b.tube(spine, [r] * len(spine), [col_rib if i % 2 else col for i in range(len(spine))], 7)


def _port(b, at, half_w, half_h, r):
    """Where a pipe of radius `r` goes into the wall behind the pod, at `at`: a plate on the wall and a
    collar round the pipe."""
    box(b, (at.x - half_w, POD_R - 0.02, at.z - half_h), (at.x + half_w, POD_R, at.z + half_h), METAL_DARK)
    b.tube([Vector((at.x, POD_R - 0.06, at.z)), Vector((at.x, POD_R - 0.02, at.z))], [r * 1.3, r * 1.3],
           [GUNMETAL, GUNMETAL], 8)


def _bead(b, c, r, col, col_top):
    """A bubble: a little bead, paler on top."""
    top, bottom = c + UP * r, c - UP * r
    ring = [c + Vector((math.cos(a), math.sin(a), 0.0)) * r for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi)]
    for k in range(4):
        a, d = ring[k], ring[(k + 1) % 4]
        b.tri(a, d, top, col, col, col_top)
        b.tri(d, a, bottom, col, col, col)


def pod(seed):
    rng = random.Random(seed)
    base, fluid, lamps = Builder(), Builder(), Builder()

    # --- The machine: a drum of the module's white plating with an orange band, on a dark plinth, the step
    # up into the tank cut into its front under the hatch. Its top is the tank's floor.
    n = 24
    step = math.tau / n
    dark_floor = mix(GUNMETAL, METAL_DARK, 0.4)

    def nosing(th):
        # The step's front edge, striped like the door's threshold.
        return HAZARD if int(math.floor((th + POD_DOOR) / (POD_DOOR / 4.0))) % 2 == 0 else GUNMETAL

    full = [(0.47, 0.0), (0.47, 0.04), (POD_R, 0.04), (POD_R, 0.19), (POD_R, 0.225), (POD_R, 0.285),
            (0.485, POD_FLOOR), (0.40, POD_FLOOR), (0.0, POD_FLOOR)]
    notch = [(0.47, 0.0), (0.47, 0.04), (POD_R, 0.04), (POD_R, 0.135), (POD_R, 0.15), (0.465, 0.15),
             (0.40, 0.15), (0.40, POD_FLOOR), (0.0, POD_FLOOR)]
    for k in range(n):
        a = k * step
        signed = (a + math.pi) % math.tau - math.pi
        white = jitter(METAL, rng, 0.012)
        if -POD_DOOR - 1e-6 <= signed and signed + step <= POD_DOOR + 1e-6:
            _lathe(base, signed, signed + step, 2, notch,
                   [GUNMETAL, METAL_DARK, white, HAZARD, nosing, GUNMETAL, METAL_DARK, dark_floor])
        else:
            _lathe(base, a, a + step, 1, full,
                   [GUNMETAL, METAL_DARK, white, HAZARD, white, METAL_DARK, mix(white, (1.0, 1.0, 1.0), 0.06),
                    dark_floor])
    # The cut's two cheeks.
    cheek = [(0.40, 0.15), (POD_R, 0.15), (POD_R, 0.19), (POD_R, 0.225), (POD_R, 0.285), (0.485, POD_FLOOR),
             (0.40, POD_FLOOR)]
    for th, flip in ((-POD_DOOR, True), (POD_DOOR, False)):
        pts = [_round(th, r, z) for (r, z) in cheek]
        for k in range(1, len(pts) - 1):
            tri = (pts[0], pts[k + 1], pts[k]) if flip else (pts[0], pts[k], pts[k + 1])
            base.tri(*tri, METAL, METAL, METAL)

    def on_facet(k, u, z, lift=0.002):
        """A point on the drum's facet k (vertex k to k + 1), `u` of the way across it, `z` up."""
        p = _round(k * step, POD_R, z).lerp(_round((k + 1) * step, POD_R, z), u)
        return p + _round((k + 0.5) * step, 1.0, 0.0) * lift

    # Vents low on either side, and a panel at the front right, beside the step: its screen and buttons
    # are lit (the lamps, below).
    for k in (5, 18):
        for z in (0.075, 0.11, 0.145):
            base.quad(on_facet(k, 0.15, z), on_facet(k, 0.85, z), on_facet(k, 0.85, z + 0.018),
                      on_facet(k, 0.15, z + 0.018), GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)
    panel = 3
    base.quad(on_facet(panel, 0.08, 0.06), on_facet(panel, 0.92, 0.06), on_facet(panel, 0.92, 0.18),
              on_facet(panel, 0.08, 0.18), LENS, LENS, LENS, LENS)
    # The threshold: the tank floor's front edge, striped, where he steps over.
    for s in range(4):
        a = -POD_DOOR + 2.0 * POD_DOOR * s / 4
        c = -POD_DOOR + 2.0 * POD_DOOR * (s + 1) / 4
        col = HAZARD if s % 2 == 0 else GUNMETAL
        base.quad(_round(a, 0.365, POD_FLOOR + 0.001), _round(a, 0.40, POD_FLOOR + 0.001),
                  _round(c, 0.40, POD_FLOOR + 0.001), _round(c, 0.365, POD_FLOOR + 0.001), col, col, col, col)

    # --- The frame: the foot ring the glass stands in (broken by the hatch), the collar at its head, and
    # six slim ribs between -- the hatch's two orange jambs, two at the sides, two behind.
    _lathe(base, POD_DOOR, math.tau - POD_DOOR, 20,
           [(0.484, POD_FLOOR), (0.484, 0.36), (0.43, 0.36), (0.43, POD_FLOOR), (0.484, POD_FLOOR)],
           [METAL_DARK, mix(METAL_DARK, METAL, 0.2), GUNMETAL, GUNMETAL], ends=True)
    z0, z1 = POD_COLLAR

    def lintel(th):
        # Orange over the hatch, as round the module's own door.
        return HAZARD if abs((th + math.pi) % math.tau - math.pi) < POD_DOOR else METAL_DARK
    _lathe(base, 0.0, math.tau, n,
           [(0.485, z0), (0.485, z0 + 0.025), (0.485, z0 + 0.04), (0.485, z0 + 0.072), (0.485, z1 - 0.02),
            (0.47, z1), (0.40, z1), (0.40, z0), (0.485, z0)],
           [lintel, METAL, GUNMETAL, METAL, mix(METAL, (1.0, 1.0, 1.0), 0.05), mix(METAL, (1.0, 1.0, 1.0), 0.08),
            METAL_DARK, mix(METAL_DARK, (0.0, 0.0, 0.0), 0.3)])
    for th in (-POD_DOOR, POD_DOOR, math.pi / 2, -math.pi / 2, math.pi - POD_DOOR, math.pi + POD_DOOR):
        jamb = abs(abs(th) - POD_DOOR) < 1e-6
        beam(base, _round(th, POD_GLASS, 0.355), _round(th, POD_GLASS, z0 + 0.005), 0.036 if jamb else 0.026,
             0.036 if jamb else 0.03, HAZARD if jamb else METAL_DARK, up=_round(th, 1.0, 0.0))
    # The hatch's hinges on the right jamb and its latch on the left.
    for z in (0.56, 1.12, 1.66):
        rod(base, _round(POD_DOOR - 0.05, 0.468, z), _round(POD_DOOR - 0.05, 0.468, z + 0.07), 0.012, GUNMETAL,
            sides=5)
    latch = [_round(-POD_DOOR + 0.05, 0.47, z) for z in (1.0, 1.2)]
    out = _round(-POD_DOOR + 0.05, 0.028, 0.0)
    for p in latch:
        rod(base, p, p + out, 0.007, GUNMETAL, sides=4)
    rod(base, latch[0] + out, latch[1] + out, 0.01, METAL_DARK, sides=5)

    # --- The cap: a hub over the open top on four struts from the collar, a nozzle under it where the fluid
    # comes in, and two hoses from it back into the wall over the collar.
    _lathe(base, 0.0, math.tau, 12,
           [(0.0, 1.985), (0.15, 1.985), (0.15, 2.02), (0.15, 2.035), (0.15, 2.06), (0.115, 2.085), (0.05, POD_TOP),
            (0.0, POD_TOP)],
           [METAL_DARK, METAL, HAZARD, METAL, mix(METAL, (1.0, 1.0, 1.0), 0.05), mix(METAL, (1.0, 1.0, 1.0), 0.08),
            mix(METAL, (1.0, 1.0, 1.0), 0.1)])
    rod(base, Vector((0.0, 0.0, 1.935)), Vector((0.0, 0.0, 1.99)), 0.042, GUNMETAL, sides=10)
    for th in (math.pi / 4, -math.pi / 4, 3 * math.pi / 4, -3 * math.pi / 4):
        beam(base, _round(th, 0.44, z1 + 0.017), _round(th, 0.14, 2.045), 0.04, 0.034, METAL_DARK)
        beam(base, _round(th, 0.475, z1 + 0.006), _round(th, 0.405, z1 + 0.006), 0.062, 0.012, GUNMETAL)
    # The hoses end inside the collars on their plates, so a hose's last ring, tilted, stays off the wall.
    hose_r = 0.027
    for sx in (-1.0, 1.0):
        _hose(base, [Vector((sx * 0.05, 0.10, 2.035)), Vector((sx * 0.17, 0.2, 2.066)),
                     Vector((sx * 0.30, 0.30, 2.068)), Vector((sx * 0.405, 0.39, 2.0)),
                     Vector((sx * 0.43, 0.425, 1.85)), Vector((sx * 0.43, POD_R - 0.035, 1.80))],
              hose_r, METAL_DARK, GUNMETAL)
        _port(base, Vector((sx * 0.43, POD_R, 1.80)), 0.05, 0.06, hose_r)

    # --- Under it, the feed: a thick hose out of either side of the base and back into the wall, and an
    # orange cable along the deck beside it.
    for sx in (-1.0, 1.0):
        _hose(base, [_round(sx * math.radians(118), 0.47, 0.13), Vector((sx * 0.462, 0.30, 0.17)),
                     Vector((sx * 0.46, 0.40, 0.30)), Vector((sx * 0.455, POD_R - 0.035, 0.42))],
              0.032, GUNMETAL, METAL_DARK)
        _port(base, Vector((sx * 0.455, POD_R, 0.42)), 0.045, 0.06, 0.032)
        cable = _through([_round(sx * math.radians(100), 0.47, 0.05), Vector((sx * 0.488, 0.16, 0.02)),
                          Vector((sx * 0.475, 0.40, 0.015)), Vector((sx * 0.41, POD_R - 0.02, 0.09))], 3)
        base.tube(cable, [0.011] * len(cable), [HAZARD] * len(cable), 6)
        box(base, (sx * 0.41 - 0.03, POD_R - 0.018, 0.06), (sx * 0.41 + 0.03, POD_R, 0.12), GUNMETAL)

    # --- The fluid: the back of the column, round to POD_OPEN either side of the front -- brightest at the
    # back, where it is deepest, and paler at the floor and up at the surface -- the surface a pale line
    # round the glass and its edge a ring, the floor's emitter lit in rings, and bubbles rising.
    def fluid_col(th, z):
        s = max(0.0, 1.0 - abs(th - math.pi) / (math.pi - POD_OPEN))
        c = mix(FLUID_DEEP, FLUID, 0.3 + 0.7 * s ** 0.7)
        c = mix(c, FLUID_PALE, 0.35 * max(0.0, 1.0 - (z - POD_FLOOR) / 0.25))
        return mix(c, FLUID_PALE, 0.3 * max(0.0, 1.0 - (POD_SURFACE - z) / 0.2))
    rows = [0.33, 0.42, 0.7, 1.1, 1.5, 1.72, POD_SURFACE]
    segs = 14
    for i in range(segs):
        a = POD_OPEN + (math.tau - 2.0 * POD_OPEN) * i / segs
        c = POD_OPEN + (math.tau - 2.0 * POD_OPEN) * (i + 1) / segs
        for j in range(len(rows) - 1):
            za, zb = rows[j], rows[j + 1]
            fluid.quad(_round(c, POD_FLUID, za), _round(a, POD_FLUID, za), _round(a, POD_FLUID, zb),
                       _round(c, POD_FLUID, zb), fluid_col(c, za), fluid_col(a, za), fluid_col(a, zb), fluid_col(c, zb))
    _lathe(fluid, 0.0, math.tau, n, [(POD_FLUID + 0.003, POD_SURFACE - 0.016), (POD_FLUID + 0.003, POD_SURFACE)],
           [FLUID_PALE])
    _lathe(fluid, 0.0, math.tau, n, [(POD_FLUID, POD_SURFACE), (0.405, POD_SURFACE)], [mix(FLUID, FLUID_PALE, 0.5)])
    for (r0, r1, col) in ((0.0, 0.07, FLUID_PALE), (0.12, 0.2, mix(FLUID, FLUID_PALE, 0.6)),
                          (0.25, 0.34, mix(FLUID, FLUID_PALE, 0.3))):
        _lathe(fluid, 0.0, math.tau, 16, [(r1, POD_FLOOR + 0.002), (r0, POD_FLOOR + 0.002)], [col])
    disc(fluid, Vector((0.0, 0.0, 1.933)), Vector((0.0, 0.0, -1.0)), 0.032, FLUID_PALE, 10, BUBBLE)
    streams = [(110, 0.36), (150, 0.30), (182, 0.37), (212, 0.26), (248, 0.35), (168, 0.14), (82, 0.37), (280, 0.36)]
    for (deg, r) in streams:
        z = rng.uniform(0.38, 0.6)
        while z < POD_SURFACE - 0.06:
            size = 0.008 + 0.013 * (z - 0.35) / 1.5 + rng.uniform(-0.002, 0.003)
            c = _round(math.radians(deg) + rng.uniform(-0.05, 0.05), r + rng.uniform(-0.02, 0.02), z)
            _bead(fluid, c, size, FLUID_PALE, BUBBLE)
            z += rng.uniform(0.18, 0.32)
    for k in range(9):
        th = math.radians(rng.uniform(95.0, 265.0))
        at = _round(th, rng.uniform(0.15, 0.4), POD_SURFACE - rng.uniform(0.02, 0.06))
        _bead(fluid, at, rng.uniform(0.006, 0.011), FLUID_PALE, BUBBLE)

    # --- The lamps: a ring of them round the collar -- the one over the hatch green, the rest the fluid's
    # own pale -- and the panel's screen and three buttons.
    for k in range(12):
        th = math.tau * k / 12
        d = 0.017 / 0.487
        col = OK_LIGHT if k == 0 else FLUID_PALE
        lamps.quad(_round(th - d, 0.487, z0 + 0.044), _round(th + d, 0.487, z0 + 0.044),
                   _round(th + d, 0.487, z0 + 0.068), _round(th - d, 0.487, z0 + 0.068), col, col, col, col)
    lamps.quad(on_facet(panel, 0.16, 0.125, 0.004), on_facet(panel, 0.84, 0.125, 0.004),
               on_facet(panel, 0.84, 0.165, 0.004), on_facet(panel, 0.16, 0.165, 0.004),
               SCREEN, SCREEN, SCREEN_LINE, SCREEN_LINE)
    for (u, col) in ((0.2, OK_LIGHT), (0.45, AMBER_LIGHT), (0.7, FLUID_PALE)):
        lamps.quad(on_facet(panel, u, 0.075, 0.004), on_facet(panel, u + 0.12, 0.075, 0.004),
                   on_facet(panel, u + 0.12, 0.1, 0.004), on_facet(panel, u, 0.1, 0.004), col, col, col, col)

    return [("base", base), ("fluid_glow", fluid), ("lights_glow", lamps)]


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
    # --- The beacon's mast on the roof, back up a stage at a time --------------------------------
    # v0.6 round three: "每次信标修复一格，船舱的样式要看得出信标做出来了的部分，也有小的灯". The bench
    # inside is where the work is done; this is what the valley sees of it. Named by the jobs, as
    # the bench's parts are (CabinArt): before the first stage the antenna the crash bent over;
    # then each stage is what it cost -- a pole lashed up (wood), a cairn and stays to hold it
    # (stone), the dish on bone ribs with hide over them (stone and bone) -- each with a lamp of
    # its own ("lamp_"), and at the launch the dish's throat alight. The mast fades with the roof
    # while he is inside ("fade_"); the lamps, small, do not.
    mast = Vector((1.4, -0.3, roof_z - 0.02))
    wreck, s1, s2, s3 = Builder(), Builder(), Builder(), Builder()
    g1, g2, g3, g_launch = Builder(), Builder(), Builder(), Builder()
    wreck.tube([mast, mast + Vector((0.02, 0.0, 0.3)), mast + Vector((0.2, -0.06, 0.45))],
               [0.035, 0.025, 0.018], [METAL_DARK, METAL, HAZARD], 6)

    def bulb(b, c, r, col):
        b.tube([c - UP * r, c - UP * (r * 0.4), c + UP * (r * 0.4), c + UP * r], [0.002, r, r, 0.002],
               [col, col, col, (1.0, 1.0, 1.0)], 8)

    pole_top = mast + UP * 2.0
    rod(s1, mast, pole_top, 0.045, BARK, col1=BARK_LIGHT)
    # The bent antenna straightened and lashed along the pole.
    s1.tube([mast + Vector((0.07, 0.0, 0.04)), mast + Vector((0.07, 0.0, 0.9))], [0.022, 0.016], [METAL_DARK, METAL], 6)
    for z in (0.25, 0.7, 1.3, 1.8):
        lashing(s1, mast + UP * z, UP, 0.052, rng)
    # A lamp housing salvaged from the hull, at the top.
    box(s1, pole_top + Vector((-0.055, -0.055, -0.03)), pole_top + Vector((0.055, 0.055, 0.035)), METAL_DARK)
    bulb(g1, pole_top + UP * 0.09, 0.05, ERROR_LIGHT)

    # Stage 2: stones round its foot on the roof, and two stays out to stones along the ridge.
    for k in range(9):
        a = math.tau * k / 9
        _boulder(s2, mast + Vector((math.cos(a) * 0.24, math.sin(a) * 0.17, 0.04)), 0.07, rng, fresh=True)
    for sx in (0.95, -0.95):
        anchor = mast + Vector((sx, 0.05, 0.04))
        _boulder(s2, anchor, 0.085, rng, fresh=True)
        s2.tube([mast + UP * 1.55, anchor + UP * 0.07], [0.008, 0.008], [ROPE, ROPE], 4)
    bulb(g2, mast + UP * 1.15 + Vector((-0.08, 0.0, 0.0)), 0.045, AMBER_LIGHT)

    # Stage 3: the dish on bone ribs at the top, facing out over the valley.
    hub = pole_top + UP * 0.12
    face_dir = Vector((0.35, -0.55, 0.76)).normalized()
    u = face_dir.cross(UP).normalized()
    v = face_dir.cross(u).normalized()
    ribs = 9
    rim_pts = []
    for k in range(ribs):
        a = math.tau * k / ribs
        d = u * math.cos(a) + v * math.sin(a)
        mid = hub + d * 0.2 + face_dir * 0.07
        tip = hub + d * 0.42 + face_dir * 0.24
        s3.tube([hub, mid, tip], [0.016, 0.014, 0.011], [BONE, BONE, mix(BONE, (1.0, 1.0, 1.0), 0.2)], 5)
        rim_pts.append(tip)
    for k in range(ribs):
        s3.tri(rim_pts[k], rim_pts[(k + 1) % ribs], hub + face_dir * 0.05, (0.55, 0.42, 0.28), (0.55, 0.42, 0.28), HIDE)
    s3.tube([hub, hub + face_dir * 0.36], [0.013, 0.008], [BONE, BONE], 5)
    bulb(g3, hub + face_dir * 0.4, 0.045, SCREEN)
    # The launch: the dish's throat alight.
    throat = hub + face_dir * 0.16
    for k in range(3):
        disc(g_launch, throat + face_dir * (0.012 * k), face_dir, 0.14 - 0.035 * k, SCREEN_LINE, 12, (1.0, 1.0, 1.0))

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
    # Each bench with its back to the back wall (Config.CABIN.station_sizes: their depths); the pod's
    # back right against it, where its pipes go in, between the two middle ribs.
    spots = {"workbench": Vector((-1.75, y_back - 0.37, 0.0)), "pod": Vector((0.0, y_back - POD_R, 0.0)),
             "beacon": Vector((1.75, y_back - 0.41, 0.0)),
             "door": Vector((0.0, _wall_y(MOD_OUT, 0.0, True) - 0.6, 0.0))}
    ports = {"west": Vector((-3.5, 0.0, 1.0)), "east": Vector((3.5, 0.0, 1.0))}
    head, muzzle = _turret_head(1.0)
    parts = [("hull", hull), ("fade_shell", fade), ("fade_glass", fade_glass), ("glass", glass),
             ("fade_lamp_glow", lamp), ("door", door),
             ("fade_before_beacon_1", wreck), ("fade_beacon_1", s1), ("fade_beacon_2", s2), ("fade_beacon_3", s3),
             ("lamp_beacon_1_glow", g1), ("lamp_beacon_2_glow", g2), ("lamp_beacon_3_glow", g3),
             ("lamp_beacon_launch_glow", g_launch)]
    return parts, spots, {"ports": ports, "head": (head, pivot, muzzle)}


# ==============================================================================
# Export
# ==============================================================================

MODELS = {
    "module": (module, 23),
    "workbench": (workbench, 11),
    "pod": (pod, 13),
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
