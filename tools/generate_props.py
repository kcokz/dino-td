# tools/generate_props.py
# The made and fallen things of the valley: stakes, stone outcrops, fallen trunks.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_props.py
#   ... -- --preview     also renders a lineup to the scratch directory
#
# Built with the same coloured-triangle Builder as tools/generate_flora.py, and exported
# the same way -- ONE surface, coloured by its vertices -- for the same reason: a second
# surface came through the glTF export with its colours filled white.

import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import (Builder, mix, jitter, vertex_colour_material, reset, export,  # noqa: E402
                            UP, PREVIEW_DIR, foliage_clump, frond, FROND_BASE, FROND_TIP)
from mathutils import Matrix, Vector  # noqa: E402

REPO = r"z:\home\zkl-unix\repo\game\dino"
OUT_DIR = os.path.join(REPO, "assets", "models", "props")

SOIL = (0.13, 0.10, 0.07)
SOIL_LIGHT = (0.24, 0.19, 0.13)
BARK = (0.17, 0.11, 0.07)
BARK_LIGHT = (0.30, 0.21, 0.13)
FRESH_WOOD = (0.74, 0.58, 0.36)
CHAR = (0.06, 0.045, 0.035)
VINE = (0.30, 0.30, 0.13)
VINE_DARK = (0.17, 0.18, 0.07)
# Weathered volcanic stone. Authored in sRGB, so these are brighter than they look as
# numbers: the first palette started at 0.14, which is 0.018 once linear -- darker than
# coal -- and every crag seen with the sun behind it was a black shape, whatever the
# ambient light was turned up to.
ROCK_DARK = (0.26, 0.24, 0.22)
ROCK = (0.44, 0.42, 0.38)
ROCK_LIGHT = (0.60, 0.58, 0.53)
MOSS = (0.16, 0.26, 0.07)
LICHEN = (0.55, 0.52, 0.30)


def _dry_stone(b, lo, hi, rng, col):
    """One roughly squared stone from `lo` to `hi`: its corners pushed about a little, the
    top a shade lighter where the light falls and the sides darkening into the joints.
    No bottom face -- it sits on the course below."""
    def corner(x, y, z):
        return Vector((x + rng.uniform(-0.02, 0.02), y + rng.uniform(-0.02, 0.02), z + rng.uniform(-0.015, 0.015)))
    low = [corner(lo.x, lo.y, lo.z), corner(hi.x, lo.y, lo.z), corner(hi.x, hi.y, lo.z), corner(lo.x, hi.y, lo.z)]
    for v in low:
        v.z = lo.z          # flat underneath: it rests on the course below, or on the ground
    high = [corner(lo.x, lo.y, hi.z), corner(hi.x, lo.y, hi.z), corner(hi.x, hi.y, hi.z), corner(lo.x, hi.y, hi.z)]
    top_col = mix(col, ROCK_LIGHT, 0.45)
    low_col = mix(col, ROCK_DARK, 0.4)
    for k in range(4):
        k2 = (k + 1) % 4
        b.quad(low[k], low[k2], high[k2], high[k], low_col, low_col, col, col)
    b.quad(high[0], high[1], high[2], high[3], top_col, top_col, top_col, top_col)


def stone_wall(seed):
    """A drystone wall filling its cell, to Config.BUILDINGS.stone_wall's envelope: a metre square
    (a hair inside, so a row of them does not flicker where they meet) and 1.2 m tall -- one cell
    of the building grid since v0.6 round two, so a line of them is a wall and one stands flush
    against whatever is in the next cell.

    Courses of roughly squared, unmortared stone, the joints staggered from one course to the
    next the way a waller lays them, so no crack runs straight up; each course set in a little
    from the one below -- the batter that lets a drystone wall lean on itself; flat capstones
    laid across the top; rubble and moss at the foot. From twenty metres up it has to read as
    stone heaped ON PURPOSE -- courses, not one more boulder."""
    rng = random.Random(seed)
    b = Builder()
    half = 0.485
    height = 1.2
    cap = 0.13
    courses = 4
    body = height - cap
    rows = 2
    for c in range(courses):
        z0 = body * c / courses
        z1 = body * (c + 1) / courses
        inset = 0.07 * c / courses
        lo_edge, hi_edge = -half + inset, half - inset
        row_w = (hi_edge - lo_edge) / rows
        for r in range(rows):
            y0 = lo_edge + r * row_w
            x = lo_edge - (0.22 if (c + r) % 2 else 0.0)
            while x < hi_edge - 0.06:
                length = rng.uniform(0.24, 0.42)
                x0, x1 = max(lo_edge, x), min(hi_edge, x + length)
                if x1 - x0 > 0.1:
                    col = mix(ROCK_DARK, ROCK, rng.uniform(0.25, 0.95))
                    if rng.random() < 0.12:
                        col = mix(col, MOSS, 0.35)
                    _dry_stone(b, Vector((x0 + 0.012, y0 + 0.012, z0)),
                               Vector((x1 - 0.012, y0 + row_w - 0.012, z1 - 0.006)), rng, col)
                x += length
    # The capstones: slabs laid ACROSS the courses, which is what holds a drystone wall's top
    # together -- and, from above, what says "built".
    inset = 0.07
    lo_edge, hi_edge = -half + inset, half - inset
    x = lo_edge
    while x < hi_edge - 0.06:
        width = rng.uniform(0.22, 0.32)
        x0, x1 = x, min(hi_edge, x + width)
        col = mix(ROCK, ROCK_LIGHT, rng.uniform(0.0, 0.5))
        if rng.random() < 0.3:
            col = mix(col, LICHEN if rng.random() < 0.5 else MOSS, 0.4)
        lift = rng.uniform(0.0, 0.03)
        _dry_stone(b, Vector((x0 + 0.01, lo_edge + 0.02, body)),
                   Vector((x1 - 0.01, hi_edge - 0.02, height - 0.05 + lift)), rng, col)
        x += width
    # Rubble fallen at the foot, and a little moss where it lies.
    for _ in range(4):
        side = rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
        along = rng.uniform(-half * 0.9, half * 0.9)
        # inside the tile: a wall whose rubble spilled past it would be fitted smaller than its tile
        size = rng.uniform(0.05, 0.09)
        # _boulder hangs two thirds of a stone's squashed height below its centre; lifted by
        # that, nothing is under the ground -- the wall is stood on its LOWEST point, and a
        # buried pebble would have held the whole wall up off the grass.
        p = Vector((side[0] * (half - 0.08) + side[1] * along, side[1] * (half - 0.08) + side[0] * along, size * 0.53))
        _boulder(b, p, size, rng)
    return b


# ==============================================================================
# The palisade and the gate (v0.6 round two): a metre of wall that joins what is beside it
# ==============================================================================
# The walls are one cell of the building grid each (Config.BUILD_CELL, a metre), and a
# palisade section's art is a KIT of parts the game shows or hides by what stands in the
# cells beside it (Wall.gd): a post in the middle, and a run of logs out to each side. The
# runs reach the cell's edge, where the next section's run meets them, so a line of sections
# is one palisade. In Blender +Y is north (the glTF export turns it into the game's -Z).

PALISADE_HEIGHT = 1.25
RAIL = (0.36, 0.26, 0.16)


def _palisade_log(b, base, height, radius, rng, bone=False):
    """One sharpened log of a palisade: ridged bark, a lip where the cut begins, and axe-cut
    facets of pale fresh wood darkening to a charred point -- or, with a bone to carry, cut
    down to a short wedge with a bone point lashed upright on it, up to the same height."""
    lean = Vector((rng.uniform(-0.015, 0.015), rng.uniform(-0.015, 0.015), 0.0))
    sides = 7
    shaft_top = height - (0.16 if bone else 0.26)
    n = 4
    spine = [base + UP * (shaft_top * i / n) + lean * (i / n) for i in range(n + 1)]
    radii = [radius * (1.0 - 0.1 * i / n) for i in range(n + 1)]
    cols = [mix(BARK, BARK_LIGHT, 0.45 if i % 2 else 0.12) for i in range(n + 1)]
    ridges = [rng.uniform(0.88, 1.08) for _ in range(sides)]
    rings = b.tube(spine, radii, cols, sides, radial=lambda i, k: ridges[k])
    top = spine[-1]
    tip_col = FRESH_WOOD if bone else CHAR
    tip = top + UP * (0.06 if bone else 0.26) + Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), 0.0))
    for k in range(sides):
        k2 = (k + 1) % sides
        b.tri(rings[-1][k], rings[-1][k2], tip, FRESH_WOOD, FRESH_WOOD, tip_col)
    if bone:
        length = height - top.z + 0.02
        bend = Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.0)).normalized() * 0.02
        foot = top - UP * 0.03
        ts = [0.0, 0.35, 0.7, 1.0]
        pts = [foot + UP * (length * t) + bend * (t * t) for t in ts]
        stained = mix(BONE, (0.45, 0.36, 0.20), 0.35)
        bleached = mix(BONE, (0.95, 0.93, 0.86), 0.45)
        b.tube(pts, [radius * 0.45, radius * 0.38, radius * 0.2, 0.004], [stained, BONE, bleached, bleached], 6)
    return spine


def _spike(b, base, tip, radius, rng, bone=False):
    """A sharpened stake set slanting out of the earth towards whatever comes: bark up to where
    the cut begins, then facets of fresh wood to a charred point -- or, on a bone palisade, a
    bone point lashed on where the cut would be."""
    axis = tip - base
    cut = 0.6 if not bone else 0.72
    sides = 5
    spine = [base + axis * (cut * i / 3) for i in range(4)]
    radii = [radius * (1.0 - 0.12 * i / 3) for i in range(4)]
    cols = [mix(BARK, BARK_LIGHT, 0.4 if i % 2 else 0.1) for i in range(4)]
    rings = b.tube(spine, radii, cols, sides)
    point = tip if not bone else base + axis * (cut + 0.06)
    tip_col = CHAR if not bone else FRESH_WOOD
    for k in range(sides):
        k2 = (k + 1) % sides
        b.tri(rings[-1][k], rings[-1][k2], point, FRESH_WOOD, FRESH_WOOD, tip_col)
    if bone:
        foot = base + axis * (cut - 0.04)
        ts = [0.0, 0.5, 1.0]
        stained = mix(BONE, (0.45, 0.36, 0.20), 0.35)
        bleached = mix(BONE, (0.95, 0.93, 0.86), 0.45)
        b.tube([foot + (tip - foot) * t for t in ts], [radius * 0.5, radius * 0.3, 0.004], [stained, BONE, bleached], 5)


## Where the slanting stakes of a section reach to: a hair inside its cell (Config.BUILD_CELL, a
## metre), so the section is as big as the cell it fills -- and waist-high on a raptor, where it
## presses against them.
SPIKE_REACH = 0.46
SPIKE_TIP_HEIGHT = 0.5


def _lashing(b, centre, radius, rng):
    """A wrap of vine round a log where the rail crosses it."""
    pts = []
    for k in range(10):
        a = math.tau * k / 9 + rng.uniform(0.0, 0.3)
        pts.append(centre + Vector((math.cos(a), math.sin(a), 0.0)) * (radius + 0.012) + UP * (0.012 * math.sin(a * 2)))
    b.tube(pts, [0.011] * 10, [mix(VINE, VINE_DARK, 0.5 if k % 3 == 0 else 0.0) for k in range(10)], 4)


def _earth_strip(b, x0, x1, width, rng):
    """Turned earth along a run, a low ridge from x0 to x1 (the run's own frame)."""
    steps = 3
    for i in range(steps):
        a = x0 + (x1 - x0) * i / steps
        c = x0 + (x1 - x0) * (i + 1) / steps
        h = rng.uniform(0.035, 0.06)
        w = width * rng.uniform(0.85, 1.05)
        pa, pb = Vector((a, -w * 0.5, 0.0)), Vector((c, -w * 0.5, 0.0))
        pc, pd = Vector((c, w * 0.5, 0.0)), Vector((a, w * 0.5, 0.0))
        ridge_a, ridge_c = Vector((a, 0.0, h)), Vector((c, 0.0, h))
        b.quad(pa, pb, ridge_c, ridge_a, SOIL, SOIL, SOIL_LIGHT, SOIL_LIGHT)
        b.quad(ridge_a, ridge_c, pc, pd, SOIL_LIGHT, SOIL_LIGHT, SOIL, SOIL)


def _palisade_run(seed, bone, turn):
    """The run of a palisade section from its post out to the edge of its cell, eastward, then
    turned `turn` radians about the vertical: two logs, the rail they are lashed to, turned
    earth under the whole width of the cell, and sharpened stakes slanting out of it to both
    sides -- out to the cell's edge, so what a raptor walks into is what it sees, and what it
    presses against is the points (Wall.touches)."""
    rng = random.Random(seed)
    b = Builder()
    _earth_strip(b, 0.08, 0.5, SPIKE_REACH * 2.0, rng)
    for x in (0.2, 0.4):
        for side in (-1.0, 1.0):
            along = x + rng.uniform(-0.03, 0.03)
            base = Vector((along, side * 0.1, 0.03))
            tip = Vector((along + rng.uniform(-0.04, 0.04), side * SPIKE_REACH * rng.uniform(0.96, 1.0),
                          SPIKE_TIP_HEIGHT * rng.uniform(0.9, 1.05)))
            _spike(b, base, tip, rng.uniform(0.036, 0.044), rng, bone)
    rail_z = 0.62
    for x in (0.25, 0.42):
        base = Vector((x, rng.uniform(-0.02, 0.02), 0.0))
        radius = rng.uniform(0.08, 0.092)
        height = PALISADE_HEIGHT * rng.uniform(0.92, 1.0)
        _palisade_log(b, base, height, radius, rng, bone)
        _lashing(b, base + UP * rail_z, radius, rng)
    b.tube([Vector((0.06, 0.0, rail_z)), Vector((0.5, 0.0, rail_z + rng.uniform(-0.02, 0.02)))],
           [0.028, 0.026], [RAIL, mix(RAIL, BARK_LIGHT, 0.4)], 5)
    spin = Matrix.Rotation(turn, 3, 'Z')
    b.verts = [spin @ v for v in b.verts]
    return b


def palisade(seed, bone=False):
    """A metre of palisade (Config.BUILDINGS.wall / bone_stake) as a kit the game dresses by what
    is beside it (Wall.dress): Post, the stout log in the middle of the cell on its mound, and
    Run_E / Run_W / Run_N / Run_S, the logs from the post out to each side. With every part
    shown it is a block of stakes as big as the cell, which is how a section stands alone."""
    rng = random.Random(seed)
    post = Builder()
    rim = []
    for k in range(10):
        a = math.tau * k / 10
        rim.append(Vector((math.cos(a), math.sin(a), 0.0)) * 0.2 * rng.uniform(0.9, 1.05))
    crown = [q * 0.5 + UP * rng.uniform(0.05, 0.07) for q in rim]
    for k in range(10):
        k2 = (k + 1) % 10
        post.quad(rim[k], rim[k2], crown[k2], crown[k], SOIL, SOIL, SOIL_LIGHT, SOIL_LIGHT)
        post.tri(crown[k], crown[k2], UP * 0.07, SOIL_LIGHT, SOIL_LIGHT, SOIL)
    _palisade_log(post, Vector((0.0, 0.0, 0.0)), PALISADE_HEIGHT * 1.04, 0.105, rng, bone)
    _lashing(post, UP * 0.62, 0.105, rng)
    # Out to the corners of the cell, which no run reaches: a section at a corner or alone is
    # points all round.
    for k in range(4):
        a = math.pi * 0.25 + math.pi * 0.5 * k + rng.uniform(-0.08, 0.08)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        corner = SPIKE_REACH * math.sqrt(2.0) * 0.92
        _spike(post, d * 0.14 + UP * 0.03, d * corner + UP * SPIKE_TIP_HEIGHT * rng.uniform(0.9, 1.05),
               rng.uniform(0.036, 0.044), rng, bone)
    parts = [("Post", post, Vector((0.0, 0.0, 0.0)))]
    for name, turn, s2 in (("Run_E", 0.0, 1), ("Run_N", math.pi * 0.5, 2), ("Run_W", math.pi, 3), ("Run_S", -math.pi * 0.5, 4)):
        parts.append((name, _palisade_run(seed * 10 + s2, bone, turn), Vector((0.0, 0.0, 0.0))))
    return parts


# ==============================================================================
# The traps (v0.6 round two)
# ==============================================================================
#
# Nothing the player builds aims. A trap is set along a lane of ground in front of it, and an
# animal walking into its tripwire looses it -- the trip bow and the set crossbow, as hunters
# set them on game trails. Each is a kit (KITS) whose parts the game moves (Trap.gd): the
# String, drawn back to the nock and let go forward when it looses, and the Arrow or Bolt on
# it, gone while it is being re-armed. Both are built round the nock, so moving the String
# forward by TRAP_STRING_TRAVEL (the nock to the chord of the bow, Config.TRAPS.string_travel)
# is the string let go. Built pointing along +Y, the game's -Z: north, where the lane runs.

def _wrap(b, centre, axis, radius, turns=3):
    """A few turns of vine round a log lying along `axis`."""
    axis = axis.normalized()
    side = axis.cross(UP)
    if side.length < 1e-4:
        side = Vector((1.0, 0.0, 0.0))
    side.normalize()
    nrm = side.cross(axis).normalized()
    pts = []
    n = turns * 6
    for k in range(n + 1):
        a = math.tau * k / 6
        pts.append(centre + axis * (0.012 * (k / 6.0 - turns * 0.5)) + (side * math.cos(a) + nrm * math.sin(a)) * (radius + 0.01))
    b.tube(pts, [0.009] * len(pts), [mix(VINE, VINE_DARK, 0.5 if k % 4 == 0 else 0.0) for k in range(len(pts))], 4)


def _forked_stake(b, x, y, top, rng):
    """A stake with a fork at its top for something to rest in, driven into a little mound."""
    base = Vector((x, y, 0.0))
    b.tube([base - UP * 0.02, base + UP * 0.05], [0.09, 0.05], [SOIL, SOIL_LIGHT], 7)
    fork = top - 0.09
    b.tube([base + UP * (fork * i / 3) for i in range(4)], [0.032, 0.031, 0.03, 0.029],
           [mix(BARK, BARK_LIGHT, 0.4 if i % 2 else 0.1) for i in range(4)], 6)
    for sx in (-1.0, 1.0):
        root = base + UP * fork
        tip = root + Vector((sx * 0.045, rng.uniform(-0.01, 0.01), 0.1))
        b.tube([root, tip], [0.022, 0.012], [BARK_LIGHT, FRESH_WOOD], 5)


def _stave(b, half_span, y_mid, sweep, z, r_mid, r_tip, col_mid, col_tip):
    """A bow stave across the front, thick in the middle and fine at the tips, its limbs swept
    back towards the nock. Returns the tips."""
    limb, radii, cols = [], [], []
    for k in range(9):
        t = -1.0 + 2.0 * k / 8
        limb.append(Vector((t * half_span, y_mid - sweep * t * t, z)))
        radii.append(r_mid - (r_mid - r_tip) * abs(t))
        cols.append(mix(col_mid, col_tip, abs(t)))
    b.tube(limb, radii, cols, 6)
    return limb[0], limb[-1]


def _string(tips, nock, radius, col):
    """The string drawn back from the tips to the nock, built round the nock."""
    s = Builder()
    for tip in tips:
        s.tube([tip - nock, Vector((0.0, 0.0, 0.0))], [radius, radius], [col, col], 4)
    return s


TRAP_STRING_TRAVEL = 0.26


def trip_bow(seed):
    """The opening's trap, wood and vine: a bow bent from a sapling, lashed across the front of a
    stock that rests in two forked stakes a little above a raptor's knee, drawn back to a trigger
    toggle and an arrow nocked -- and the tripwire from the toggle down to a peg at the front of
    its cell, where the wire across the lane begins."""
    rng = random.Random(seed)
    frame = Builder()
    stock_z = 0.40
    for y in (-0.26, 0.14):
        _forked_stake(frame, 0.0, y, stock_z + 0.05, rng)
    frame.tube([Vector((0.0, -0.42, stock_z)), Vector((0.0, -0.1, stock_z + 0.005)), Vector((0.0, 0.28, stock_z))],
               [0.034, 0.036, 0.032], [BARK, BARK_LIGHT, BARK], 7)
    for y in (-0.26, 0.14):
        _wrap(frame, Vector((0.0, y, stock_z)), Vector((0.0, 1.0, 0.0)), 0.036)
    # The toggle at the back, and the wire from it forward and down to the peg at the cell's
    # front edge.
    toggle = Vector((0.0, -0.4, stock_z + 0.05))
    frame.tube([Vector((0.0, -0.4, stock_z)), toggle], [0.012, 0.012], [FRESH_WOOD, FRESH_WOOD], 4)
    peg = Vector((0.03, 0.46, 0.0))
    frame.tube([peg, peg + UP * 0.12], [0.018, 0.012], [BARK_LIGHT, FRESH_WOOD], 5)
    frame.tube([toggle, Vector((0.02, 0.0, 0.2)), peg + UP * 0.1], [0.005] * 3, [VINE_ROPE] * 3, 3)

    bow = Builder()
    tips = _stave(bow, 0.44, 0.22, 0.16, stock_z + 0.03, 0.026, 0.012, mix(BARK_LIGHT, FRESH_WOOD, 0.5), FRESH_WOOD)
    _wrap(bow, Vector((0.0, 0.22, stock_z + 0.03)), Vector((1.0, 0.0, 0.0)), 0.028)

    nock = tips[0].lerp(tips[1], 0.5) - Vector((0.0, TRAP_STRING_TRAVEL, 0.0))
    string = _string(tips, nock, 0.005, VINE_ROPE)

    arrow = Builder()
    point = Vector((0.0, 0.66, 0.0))
    arrow.tube([Vector((0.0, 0.0, 0.0)), point - Vector((0.0, 0.07, 0.0)), point],
               [0.01, 0.01, 0.0015], [FRESH_WOOD, FRESH_WOOD, CHAR], 5)
    for side in (-1.0, 1.0):
        root = Vector((0.0, 0.03, 0.0))
        arrow.tri(root, root + Vector((0.0, 0.11, 0.0)), root + Vector((side * 0.03, 0.02, 0.01)),
                  FROND_BASE, FROND_TIP, FROND_TIP)
    return [("Frame", frame, Vector((0.0, 0.0, 0.0))), ("Bow", bow, Vector((0.0, 0.0, 0.0))),
            ("String", string, nock), ("Arrow", arrow, nock)]


def _plinth(b, rng, half=0.42, height=0.34):
    """Two courses of unmortared stone under a trap, as the drystone wall is laid."""
    courses = 2
    for c in range(courses):
        z0 = height * c / courses
        z1 = height * (c + 1) / courses
        n = 2 if c % 2 == 0 else 3
        for i in range(n):
            x0 = -half + 2.0 * half * i / n
            x1 = -half + 2.0 * half * (i + 1) / n
            for (y0, y1) in ((-half, 0.0), (0.0, half)):
                col = mix(ROCK, ROCK_DARK, rng.uniform(0.0, 0.5))
                _dry_stone(b, Vector((x0 + 0.01, y0 + 0.01, z0)), Vector((x1 - 0.01, y1 - 0.01, z1)), rng, col)


def set_crossbow(seed, twin=False):
    """The crossbow he sets once he has stone and bone: a heavy timber stock on a plinth of
    stone, a stave of seasoned wood across its front -- two, lashed one over the other, on the
    improved one -- spanned with sinew back to a trigger, and a bone-headed bolt on it. Its
    bolt flies the whole lane, through whatever is on it."""
    rng = random.Random(seed)
    base = Builder()
    _plinth(base, rng)
    top = 0.34
    _slab(base, Vector((-0.06, -0.42, top)), Vector((0.06, 0.40, top + 0.09)), [(1.0, BARK_LIGHT)], 0.012)
    # The trigger lever under the back of the stock, and the wire's peg at the front edge.
    base.tube([Vector((0.0, -0.34, top)), Vector((0.0, -0.40, top - 0.14))], [0.012, 0.012], [FRESH_WOOD, BARK], 4)
    peg = Vector((0.05, 0.46, 0.0))
    base.tube([peg, peg + UP * 0.12], [0.018, 0.012], [BARK_LIGHT, FRESH_WOOD], 5)
    base.tube([Vector((0.0, -0.40, top - 0.14)), Vector((0.05, 0.0, top - 0.1)), peg + UP * 0.1],
              [0.005] * 3, [VINE_ROPE] * 3, 3)
    if twin:
        # A rack of spare bolts along the plinth's flank.
        for k in range(3):
            y0 = -0.3 + 0.03 * k
            z = 0.08 + 0.05 * k
            base.tube([Vector((0.44, y0, z)), Vector((0.44, y0 + 0.5, z))], [0.009, 0.009], [FRESH_WOOD, FRESH_WOOD], 4)
            base.tube([Vector((0.44, y0 + 0.5, z)), Vector((0.44, y0 + 0.58, z))], [0.012, 0.002], [BONE, BONE], 4)

    bow = Builder()
    stave_z = top + 0.12
    tips = list(_stave(bow, 0.46, 0.30, 0.14, stave_z, 0.04, 0.018, BARK_LIGHT, FRESH_WOOD))
    _wrap(bow, Vector((0.0, 0.30, stave_z)), Vector((1.0, 0.0, 0.0)), 0.042)
    strings = [tips]
    if twin:
        upper = list(_stave(bow, 0.44, 0.30, 0.13, stave_z + 0.07, 0.034, 0.016, BARK_LIGHT, FRESH_WOOD))
        _wrap(bow, Vector((0.0, 0.30, stave_z + 0.07)), Vector((1.0, 0.0, 0.0)), 0.036)
        strings.append(upper)
    for tip in tips:
        bow.tube([tip - Vector((0.0, 0.0, 0.02)), tip + Vector((0.0, 0.0, 0.02))], [0.02, 0.02], [BONE, BONE], 5)

    nock = tips[0].lerp(tips[1], 0.5) - Vector((0.0, TRAP_STRING_TRAVEL, 0.0))
    string = Builder()
    for pair in strings:
        for tip in pair:
            string.tube([tip - nock, Vector((0.0, 0.0, tip.z - nock.z))], [0.008, 0.008], [BONE, BONE], 4)

    bolt = Builder()
    head = Vector((0.0, 0.58, 0.02))
    bolt.tube([Vector((0.0, 0.0, 0.02)), head - Vector((0.0, 0.09, 0.0))], [0.013, 0.013], [FRESH_WOOD, FRESH_WOOD], 5)
    bolt.tube([head - Vector((0.0, 0.1, 0.0)), head - Vector((0.0, 0.05, 0.0)), head], [0.02, 0.018, 0.002],
              [BONE, BONE, mix(BONE, (0.95, 0.93, 0.86), 0.45)], 6)
    for side in (-1.0, 1.0):
        root = Vector((0.0, 0.02, 0.02))
        bolt.tri(root, root + Vector((0.0, 0.1, 0.0)), root + Vector((side * 0.035, 0.015, 0.012)),
                 FROND_BASE, FROND_TIP, FROND_TIP)
    return [("Base", base, Vector((0.0, 0.0, 0.0))), ("Bow", bow, Vector((0.0, 0.0, 0.0))),
            ("String", string, nock), ("Bolt", bolt, nock)]


PLANK = (0.46, 0.33, 0.19)
PLANK_LIGHT = (0.60, 0.46, 0.29)


def _plank(b, x0, x1, z0, z1, depth, rng, col):
    """A split plank from x0 to x1 and z0 to z1, `depth` thick, its top cut a little ragged."""
    y = depth * 0.5
    top0, top1 = z1 + rng.uniform(-0.03, 0.02), z1 + rng.uniform(-0.03, 0.02)
    front = [Vector((x0, -y, z0)), Vector((x1, -y, z0)), Vector((x1, -y, top1)), Vector((x0, -y, top0))]
    back = [Vector((x0, y, z0)), Vector((x1, y, z0)), Vector((x1, y, top1)), Vector((x0, y, top0))]
    light = mix(col, PLANK_LIGHT, 0.5)
    b.quad(front[0], front[1], front[2], front[3], col, col, light, light)
    b.quad(back[1], back[0], back[3], back[2], col, col, light, light)
    b.quad(front[3], front[2], back[2], back[3], light, light, light, light)
    b.quad(front[0], front[3], back[3], back[0], col, light, light, col)
    b.quad(front[2], front[1], back[1], back[2], light, col, col, light)


def gate(seed):
    """A gate in a wall (Config.BUILDINGS.gate): Frame -- two gateposts on mounds, a lintel lashed
    across their tops -- and Door, planks lashed to two battens and a brace, hung on vine loops
    from the western post. The Door's origin is its hinge, so turning it about the vertical
    swings it open (Gate.gd). It spans the cell along X, the way the wall it stands in runs."""
    rng = random.Random(seed)
    frame = Builder()
    post_x = 0.43
    for sx in (-1.0, 1.0):
        base = Vector((sx * post_x, 0.0, 0.0))
        _palisade_log(frame, base, 1.45, 0.07, rng)
        _lashing(frame, base + UP * 1.3, 0.07, rng)
        _lashing(frame, base + UP * 0.28, 0.07, rng)
    frame.tube([Vector((-post_x - 0.05, 0.0, 1.3)), Vector((post_x + 0.05, 0.0, 1.32))],
               [0.04, 0.038], [RAIL, mix(RAIL, BARK_LIGHT, 0.4)], 6)
    _earth_strip(frame, -0.5, 0.5, 0.22, rng)
    door = Builder()
    width = 0.78
    count = 5
    for i in range(count):
        x0 = width * i / count + 0.005
        x1 = width * (i + 1) / count - 0.005
        _plank(door, x0, x1, 0.08, 1.12 + rng.uniform(-0.04, 0.02), 0.05, rng, jitter(PLANK, rng, 0.03))
    for z in (0.3, 0.88):
        door.tube([Vector((0.0, -0.045, z)), Vector((width, -0.045, z + rng.uniform(-0.01, 0.01)))],
                  [0.025, 0.025], [RAIL, RAIL], 5)
    door.tube([Vector((0.05, -0.05, 0.32)), Vector((width - 0.05, -0.05, 0.86))], [0.02, 0.02], [RAIL, RAIL], 5)
    for z in (0.3, 0.88):
        _lashing(door, Vector((0.02, 0.0, z)), 0.03, rng)
    return [("Frame", frame, Vector((0.0, 0.0, 0.0))), ("Door", door, Vector((-post_x + 0.04, 0.0, 0.0)))]


# ==============================================================================
# A stone outcrop, for the stone node
# ==============================================================================

def outcrop(seed, broken=False):
    """A cluster of angular boulders half sunk in the ground, dark underneath, lichen and
    moss on the tops. `broken` is what is left after quarrying: lower, split, with pale
    fresh faces and rubble."""
    rng = random.Random(seed)
    b = Builder()
    count = 3 if broken else 4
    for i in range(count):
        a = math.tau * i / count + rng.uniform(-0.4, 0.4)
        r = 0.0 if i == 0 else rng.uniform(0.35, 0.55)
        c = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
        size = (0.62 if i == 0 else rng.uniform(0.32, 0.46)) * (0.7 if broken else 1.0)
        _boulder(b, c, size, rng, fresh=broken and i == 0)
    if broken:
        for _ in range(9):
            a = rng.uniform(0.0, math.tau)
            r = rng.uniform(0.3, 0.8)
            _boulder(b, Vector((math.cos(a) * r, math.sin(a) * r, 0.0)), rng.uniform(0.06, 0.12), rng, fresh=True)
    return b


def _boulder(b, centre, size, rng, fresh=False):
    """An angular boulder: an icosahedron pushed about, flattened on top, sunk a little,
    coloured dark at the foot, rock in the middle, moss and lichen where rain lands."""
    t = (1.0 + 5.0 ** 0.5) / 2.0
    raw = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
           (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    squash = rng.uniform(0.55, 0.8)
    pts = []
    for (x, y, z) in raw:
        v = Vector((x, y, z)).normalized() * size * rng.uniform(0.8, 1.18)
        v.z *= squash
        if v.z > size * squash * 0.55:           # a flatter top, the way rocks weather
            v.z = size * squash * 0.55 + (v.z - size * squash * 0.55) * 0.3
        pts.append(centre + v + UP * (size * squash * 0.35))
    for (i, j, k) in faces:
        cs = []
        for n in (i, j, k):
            h = (pts[n].z - centre.z) / max(0.01, size * squash * 1.5)
            if fresh:
                c = mix((0.40, 0.38, 0.34), (0.62, 0.60, 0.55), max(0.0, min(1.0, h)))
            else:
                c = mix(ROCK_DARK, ROCK, max(0.0, min(1.0, h * 1.6)))
                if h > 0.55:
                    c = mix(c, MOSS if rng.random() < 0.6 else LICHEN, 0.55)
            cs.append(c)
        b.tri(pts[i], pts[j], pts[k], cs[0], cs[1], cs[2])


# ==============================================================================
# A rock formation, for a hillside cell
# ==============================================================================

def _icosphere(radius, rng, jitter_amount):
    """An icosahedron subdivided once -- 80 faces, enough for a crag to have a craggy
    outline -- with every corner pushed in or out."""
    t = (1.0 + 5.0 ** 0.5) / 2.0
    verts = [Vector(v).normalized() for v in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0),
             (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    cache = {}

    def mid(a, b):
        key = (min(a, b), max(a, b))
        if key not in cache:
            verts.append(((verts[a] + verts[b]) * 0.5).normalized())
            cache[key] = len(verts) - 1
        return cache[key]
    sub = []
    for (a, b, c) in faces:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        sub += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    pts = [v * radius * rng.uniform(1.0 - jitter_amount, 1.0 + jitter_amount) for v in verts]
    return pts, sub


def _crag(b, base, width, height, tilt, rng):
    """A standing crag: a rough icosphere stretched up, leaned over, flattened where it
    meets the ground, with moss on whatever faces the sky."""
    pts, faces = _icosphere(1.0, rng, 0.16)
    lean = Vector((math.cos(tilt[0]), math.sin(tilt[0]), 0.0)) * tilt[1]
    out = []
    for p in pts:
        v = Vector((p.x * width, p.y * width * rng.uniform(0.85, 1.0), p.z * height * 0.5))
        v += UP * (height * 0.5)
        v += lean * (v.z / max(0.01, height))          # lean more towards the top
        if v.z < 0.0:
            v.z *= 0.2                                  # sunk flat into the ground
        out.append(base + v)
    for (i, j, k) in faces:
        n = (out[j] - out[i]).cross(out[k] - out[i])
        up = n.normalized().z if n.length > 1e-9 else 0.0
        cs = []
        for m in (i, j, k):
            h = (out[m].z - base.z) / max(0.01, height)
            c = mix(ROCK_DARK, ROCK, max(0.0, min(1.0, 0.25 + h * 0.9)))
            if up > 0.55 and h > 0.35:
                c = mix(c, MOSS, 0.65)                   # moss where it faces the sky
            elif up > 0.2 and h > 0.6 and (m * 7) % 5 == 0:
                c = mix(c, LICHEN, 0.45)                 # a fleck of lichen high up
            cs.append(c)
        b.tri(out[i], out[j], out[k], cs[0], cs[1], cs[2])


def rock_formation(seed):
    """Hillside for one blocked cell: a knot of volcanic crags -- two or three standing
    tall, broken boulders round their feet -- that stays INSIDE the cell's own box
    (Main.spawn_terrain: art may never overhang a free cell, or it would stop things at
    nothing visible). Authored to 1.9 x 1.9 x 2.1 m inside the 2 x 2 x 2.2 m cell."""
    rng = random.Random(seed)
    b = Builder()
    big = rng.randint(2, 3)
    for i in range(big):
        a = math.tau * i / big + rng.uniform(-0.5, 0.5)
        r = rng.uniform(0.1, 0.38)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
        _crag(b, base, rng.uniform(0.42, 0.55), rng.uniform(1.5, 2.05),
              (rng.uniform(0.0, math.tau), rng.uniform(0.05, 0.22)), rng)
    for i in range(rng.randint(4, 6)):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.45, 0.72)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
        _crag(b, base, rng.uniform(0.18, 0.3), rng.uniform(0.35, 0.8),
              (rng.uniform(0.0, math.tau), rng.uniform(0.0, 0.3)), rng)
    for i in range(rng.randint(5, 8)):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.6, 0.85)
        _boulder(b, Vector((math.cos(a) * r, math.sin(a) * r, 0.0)), rng.uniform(0.06, 0.13), rng)
    return b


# ==============================================================================
# A fallen trunk
# ==============================================================================

def fallen_log(seed):
    """A dead tree-fern trunk lying where it came down: ridged bark, a splintered pale
    end and a rotten dark one, moss along the top, a fern growing out of it."""
    rng = random.Random(seed)
    b = Builder()
    length = rng.uniform(2.8, 3.6)
    sides = 10
    ridges = [rng.uniform(0.88, 1.12) for _ in range(sides)]
    spine = []
    for i in range(9):
        u = i / 8
        spine.append(Vector((length * (u - 0.5), 0.12 * math.sin(u * math.pi), 0.24 - 0.04 * u)))
    radii = [0.26 - 0.05 * (i / 8) for i in range(9)]

    def moss_or_bark(i, k):
        return ridges[k]
    cols = [mix(BARK, BARK_LIGHT, 0.4 if i % 2 else 0.0) for i in range(9)]
    rings = b.tube(spine, radii, cols, sides, radial=moss_or_bark)
    # moss along the top: a green skin over the upper vertices, drawn as a thin strip
    for i in range(1, 8):
        for k in range(sides):
            p = rings[i][k]
            if p.z > spine[i].z + radii[i] * 0.55 and rng.random() < 0.7:
                foliage_clump(b, p, rng.uniform(0.04, 0.07), 0.45, rng, MOSS, (0.26, 0.38, 0.10))
    # the splintered end: jagged pale spikes
    end = rings[-1]
    c_end = spine[-1]
    for k in range(sides):
        k2 = (k + 1) % sides
        spike = c_end + (end[k] - c_end) * 0.4 + (spine[-1] - spine[-2]).normalized() * rng.uniform(0.04, 0.18)
        b.tri(end[k], end[k2], spike, FRESH_WOOD, FRESH_WOOD, (0.82, 0.70, 0.50))
    # the rotten end: dark and hollow
    start = rings[0]
    c0 = spine[0] + (spine[0] - spine[1]).normalized() * -0.08
    for k in range(sides):
        k2 = (k + 1) % sides
        b.tri(start[k2], start[k], c0, (0.10, 0.07, 0.05), (0.10, 0.07, 0.05), (0.03, 0.02, 0.015))
    # a young fern growing from it
    at = spine[3] + UP * radii[3] * 0.8
    for k in range(5):
        a = math.tau * k / 5
        frond(b, at, Vector((math.cos(a), math.sin(a), 0.0)), 0.45, rng, 60.0, -10.0, 1, 0.09, 0.24,
              FROND_BASE, FROND_TIP, 0, rachis_r=0.004, segs=7)
    return b


# ==============================================================================
# The nest, where the raid comes from
# ==============================================================================

EGG = (0.80, 0.76, 0.63)
EGG_SPECK = (0.30, 0.22, 0.14)
BONE = (0.74, 0.71, 0.61)
SOIL_DAMP = (0.08, 0.06, 0.045)
BURROW = (0.02, 0.018, 0.015)
DEAD_FERN = (0.30, 0.20, 0.09)
DEAD_FERN_TIP = (0.46, 0.33, 0.14)


def _rings(b, rings, cols, centre=None, centre_col=None):
    """Quads between consecutive rings, outer (or lower) ring first, and a fan from the
    last ring to `centre` when there is one."""
    seg = len(rings[0])
    for i in range(len(rings) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            b.quad(rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k],
                   cols[i][k], cols[i][k2], cols[i + 1][k2], cols[i + 1][k])
    if centre is not None:
        last = rings[-1]
        for k in range(seg):
            k2 = (k + 1) % seg
            b.tri(last[k], last[k2], centre, cols[-1][k], cols[-1][k2], centre_col)


def _egg(b, centre, axis, rng, size=1.0):
    """An egg: a sphere drawn out along `axis`, blunter at the top, speckled; `size` of the mound
    nest's."""
    pts, faces = _icosphere(1.0, rng, 0.02)
    turn = axis.to_track_quat('Z', 'Y').to_matrix()
    out = []
    for q in pts:
        fat = 1.0 + 0.12 * q.z
        out.append(centre + turn @ Vector((q.x * 0.085 * fat * size, q.y * 0.085 * fat * size, q.z * 0.16 * size)))
    for (i, j, k) in faces:
        c = mix(EGG, EGG_SPECK, rng.uniform(0.4, 0.7)) if rng.random() < 0.3 else jitter(EGG, rng, 0.02)
        b.tri(out[i], out[j], out[k], c, c, c)


def _bone(b, p0, p1, rng):
    """A long bone: a shaft with a knuckle at each end."""
    b.tube([p0, p0.lerp(p1, 0.5), p1], [0.022, 0.018, 0.022], [BONE, jitter(BONE, rng, 0.03), BONE], 6)
    for end in (p0, p1):
        pts, faces = _icosphere(0.038, rng, 0.1)
        for (i, j, k) in faces:
            b.tri(end + pts[i], end + pts[j], end + pts[k], BONE, BONE, BONE)


def nest(seed):
    """Where the raid comes from: a mound of scraped-up earth and rotting fern with a
    clutch of eggs in the hollow on top, a rim of broken branches, and a burrow at its
    foot facing the field -- the mouth the raid pours out of. Blender -Y is the game's
    +Z, which is the way the nest faces the map.

    Everything a player would recognise from above: the eggs say NEST, the burrow says
    this is where they come OUT, and the bones by the mouth say what they eat. Authored
    to 2 x 2 m across, inside the nest's declared 2.0 x 1.2 x 2.0."""
    rng = random.Random(seed)
    b = Builder()

    # The mound: earth heaped into a ring, with the hollow on top where the eggs lie.
    seg = 36
    # Low and broad: a heap scraped together, not a pot. The first profile rose to 0.84 m
    # with steep sides and read as an upturned bowl.
    profile = [(1.0, 0.0), (0.95, 0.13), (0.85, 0.32), (0.72, 0.50), (0.60, 0.58),
               (0.50, 0.53), (0.38, 0.43), (0.22, 0.38), (0.10, 0.37)]
    rings, cols = [], []
    for i, (r, z) in enumerate(profile):
        ring, col = [], []
        for k in range(seg):
            a = math.tau * k / seg
            if i == 0:
                rr = r * rng.uniform(0.97, 0.99)       # the foot stays inside the footprint
            else:
                rr = r * (1.0 + 0.05 * math.sin(a * 3.0 + seed) + rng.uniform(-0.03, 0.03))
            zz = z * (1.0 + rng.uniform(-0.06, 0.06))
            ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr, zz)))
            if i <= 1:
                c = mix(SOIL, SOIL_LIGHT, 0.25)
            elif i <= 4:
                # the crest: turned earth and the fern it was scraped up with
                c = mix(SOIL_LIGHT, DEAD_FERN, rng.uniform(0.2, 0.7)) if rng.random() < 0.45 else mix(SOIL, SOIL_LIGHT, 0.75)
            else:
                c = mix(SOIL_DAMP, SOIL, (len(profile) - 1 - i) / 4.0)   # damp and shaded in the hollow
            col.append(jitter(c, rng, 0.03))
        rings.append(ring)
        cols.append(col)
    _rings(b, rings, cols, Vector((0.0, 0.0, 0.36)), SOIL_DAMP)

    # Stones turned up with the earth, bedded round the foot.
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.2, 0.2)
        if abs(math.atan2(math.sin(a), math.cos(a)) + math.pi / 2) < 0.45:
            continue                                  # not across the mouth
        rr = rng.uniform(0.84, 0.9)
        _boulder(b, Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0)), rng.uniform(0.06, 0.1), rng)

    # The burrow: an earthen hood over a black hole at the foot, facing the field.
    arch = 10
    r_out, r_in = 0.38, 0.29
    y_back, y_front = -0.50, -0.96

    def arc(radius, y):
        return [Vector((math.cos(math.pi * j / arch) * radius, y, math.sin(math.pi * j / arch) * radius))
                for j in range(arch + 1)]
    out_back, out_front = arc(r_out, y_back), arc(r_out, y_front)
    in_back, in_front = arc(r_in, y_back), arc(r_in, y_front)
    for j in range(arch):
        b.quad(out_back[j], out_back[j + 1], out_front[j + 1], out_front[j], SOIL_LIGHT, SOIL_LIGHT, SOIL, SOIL)
        b.quad(out_front[j], out_front[j + 1], in_front[j + 1], in_front[j], SOIL, SOIL, SOIL_DAMP, SOIL_DAMP)
        b.quad(in_front[j], in_front[j + 1], in_back[j + 1], in_back[j], SOIL_DAMP, SOIL_DAMP, BURROW, BURROW)
        b.tri(in_back[j], in_back[j + 1], Vector((0.0, y_back, 0.0)), BURROW, BURROW, BURROW)
    b.quad(Vector((r_in, y_front, 0.005)), Vector((-r_in, y_front, 0.005)),
           Vector((-r_in, y_back, 0.005)), Vector((r_in, y_back, 0.005)), SOIL_DAMP, SOIL_DAMP, BURROW, BURROW)

    # The clutch: one in the middle, six round it, half sunk and leaning out.
    for i in range(7):
        if i == 0:
            _egg(b, Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0.39)), UP, rng)
            continue
        a = math.tau * (i - 1) / 6 + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(0.19, 0.24)
        lean = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0)).normalized()
        _egg(b, Vector((math.cos(a) * rr, math.sin(a) * rr, 0.42)), lean, rng)

    # Broken branches laid round the rim.
    for i in range(20):
        a = math.tau * i / 20 + rng.uniform(-0.12, 0.12)
        rr = rng.uniform(0.52, 0.68)
        mid = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.55 + rng.uniform(-0.04, 0.05)))
        along = Vector((-math.sin(a), math.cos(a), 0.0)) + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5),
                                                                  rng.uniform(-0.25, 0.25)))
        along.normalize()
        half = rng.uniform(0.2, 0.34)
        p0, p1 = mid - along * half, mid + along * half
        r = rng.uniform(0.016, 0.028)
        c0 = mix(BARK, BARK_LIGHT, rng.uniform(0.0, 0.6))
        b.tube([p0.lerp(p1, t / 3) for t in range(4)], [r, r * 0.95, r * 0.9, r * 0.8], [c0] * 4, 5)

    # Dead fronds dragged in with the earth, lying over the rim.
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.3, 0.3)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        frond(b, Vector((math.cos(a) * 0.52, math.sin(a) * 0.52, 0.56)), heading, rng.uniform(0.3, 0.38), rng,
              25.0, -35.0, 1, 0.08, 0.22, DEAD_FERN, DEAD_FERN_TIP, 0, rachis_r=0.006, withered=0.6, segs=7)

    # Live ferns at its foot, so it sits in the valley rather than on it.
    # Kept short and rooted a little up the slope: anything reaching past the foot would
    # widen what gets fitted into the nest's box, and shrink the nest to make room.
    for i in range(5):
        a = math.tau * i / 5 + 0.4 + rng.uniform(-0.2, 0.2)
        if abs(math.atan2(math.sin(a), math.cos(a)) + math.pi / 2) < 0.5:
            continue                                  # not across the mouth
        for f in range(2):
            h = Vector((math.cos(a + (f - 0.5) * 0.6), math.sin(a + (f - 0.5) * 0.6), 0.0))
            frond(b, Vector((math.cos(a) * 0.80, math.sin(a) * 0.80, 0.16)), h, rng.uniform(0.2, 0.24), rng,
                  60.0, 10.0, 1, 0.07, 0.24, jitter(FROND_BASE, rng, 0.1), jitter(FROND_TIP, rng, 0.1), 0,
                  rachis_r=0.005, segs=6)

    # What they eat, left by the door.
    _bone(b, Vector((0.48, -0.80, 0.03)), Vector((0.80, -0.52, 0.03)), rng)
    _bone(b, Vector((-0.62, -0.70, 0.03)), Vector((-0.44, -0.86, 0.05)), rng)
    return b


def nest_colony(seed):
    """A Coelophysis nesting ground (GAME-DESIGN 9.3: each species' nest is its own; v0.6 round
    three: "巢穴也不能长一个样，应该不同的恐龙巢穴也不一样"). They lived in crowds -- Ghost Ranch
    buried a thousand together -- and a ground-nester of that kind scrapes a field of shallow bowls,
    not one mound: a trampled patch of earth with scrapes across it, each lined with needles and
    fern and most with a clutch half sunk in it, and what they ate lying between. No burrow: that is
    the crocodiles' line (the mound nest above, for the maps that have them). Blender -Y is the
    game's +Z. Authored to about 3.6 m across and low, inside NEST.sizes.coelophysis."""
    rng = random.Random(seed)
    b = Builder()
    reach = 1.75

    # The trampled patch: bare earth, darker where it is most trodden, under the whole colony.
    seg = 40
    rings, cols = [], []
    for i, frac in enumerate((1.0, 0.8, 0.45)):
        ring, col = [], []
        for k in range(seg):
            a = math.tau * k / seg
            rr = reach * frac * (1.0 + 0.07 * math.sin(a * 3.0 + seed) + rng.uniform(-0.04, 0.04))
            ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr, 0.004 + 0.002 * i)))
            col.append(jitter(mix(SOIL_LIGHT, SOIL, 0.3 + 0.3 * i), rng, 0.02))
        rings.append(ring)
        cols.append(col)
    _rings(b, rings, cols, Vector((0.0, 0.0, 0.01)), SOIL)

    # The scrapes: shallow bowls kicked out of the earth, a low rim round each, spaced apart.
    scrapes = []
    tries = 0
    while len(scrapes) < 7 and tries < 400:
        tries += 1
        r_s = rng.uniform(0.26, 0.36)
        a = rng.uniform(0.0, math.tau)
        d = rng.uniform(0.0, reach - r_s - 0.12)
        c = Vector((math.cos(a) * d, math.sin(a) * d, 0.0))
        if all((c - o).length > r_s + r0 + 0.12 for (o, r0) in scrapes):
            scrapes.append((c, r_s))
    for n, (c, r_s) in enumerate(scrapes):
        seg = 18
        profile = [(1.0, 0.004), (0.86, 0.05), (0.72, 0.066), (0.58, 0.045), (0.38, 0.016)]
        rings, cols = [], []
        for i, (fr, z) in enumerate(profile):
            ring, col = [], []
            for k in range(seg):
                a = math.tau * k / seg
                rr = r_s * fr * (1.0 + rng.uniform(-0.05, 0.05))
                ring.append(c + Vector((math.cos(a) * rr, math.sin(a) * rr, z)))
                col.append(jitter(mix(SOIL_LIGHT, DEAD_FERN, 0.25) if i in (1, 2) else mix(SOIL, SOIL_DAMP, 0.5), rng, 0.03))
            rings.append(ring)
            cols.append(col)
        _rings(b, rings, cols, c + Vector((0.0, 0.0, 0.012)), SOIL_DAMP)
        # Lined with needles and bits of fern: slivers laid in the bowl.
        for k in range(22):
            a = rng.uniform(0.0, math.tau)
            rr = rng.uniform(0.0, r_s * 0.6)
            p = c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.02))
            h = rng.uniform(0.0, math.tau)
            along = Vector((math.cos(h), math.sin(h), 0.0)) * rng.uniform(0.05, 0.09)
            side = Vector((-math.sin(h), math.cos(h), 0.0)) * 0.006
            col = jitter(mix(DEAD_FERN, (0.18, 0.22, 0.10), rng.uniform(0.0, 0.8)), rng, 0.04)
            b.tri(p - along - side, p + along, p - along + side, col, col, col)
        # A clutch in most: half sunk in the lining, leaning out from the middle.
        if n % 4 != 3:
            eggs = rng.randint(4, 7)
            for e in range(eggs):
                a = math.tau * e / eggs + rng.uniform(-0.2, 0.2)
                rr = r_s * rng.uniform(0.2, 0.3)
                lean = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0)).normalized()
                # A small theropod's clutch: eggs well under the mound nest's, a few to a scrape.
                _egg(b, c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.03)), lean, rng, 0.55)

    # What they ate, dropped between the scrapes and at the edge of the patch.
    for i in range(7):
        a = rng.uniform(0.0, math.tau)
        d = rng.uniform(0.5, reach * 0.95)
        mid = Vector((math.cos(a) * d, math.sin(a) * d, 0.03))
        if any((mid - o).length < r0 + 0.08 for (o, r0) in scrapes):
            continue
        h = rng.uniform(0.0, math.tau)
        along = Vector((math.cos(h), math.sin(h), 0.0)) * rng.uniform(0.12, 0.2)
        _bone(b, mid - along, mid + along, rng)

    # Dead fronds trodden flat at the patch's edge, and live ones round it: it sits in the valley.
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.25, 0.25)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        root = Vector((math.cos(a) * reach * 0.92, math.sin(a) * reach * 0.92, 0.02))
        if i % 3 == 0:
            frond(b, root, heading, rng.uniform(0.3, 0.4), rng, 10.0, -20.0, 1, 0.07, 0.2,
                  DEAD_FERN, DEAD_FERN_TIP, 0, rachis_r=0.005, withered=0.6, segs=6)
        else:
            frond(b, root, heading, rng.uniform(0.22, 0.3), rng, 55.0, 12.0, 1, 0.07, 0.22,
                  jitter(FROND_BASE, rng, 0.1), jitter(FROND_TIP, rng, 0.1), 0, rachis_r=0.005, segs=6)
    return b


# ==============================================================================
# The sentry: salvage from the wreck on a stone-age stand
# ==============================================================================

METAL = (0.80, 0.82, 0.85)          # the wreck's hull plating
METAL_DARK = (0.24, 0.24, 0.27)     # its thruster alloy
GUNMETAL = (0.10, 0.10, 0.11)
HAZARD = (0.94, 0.40, 0.06)         # its emergency markings
LENS = (0.05, 0.09, 0.16)
LENS_DOT = (0.95, 0.22, 0.10)


def _slab(b, lo, hi, bands, bevel):
    """A box from `lo` to `hi` with its top edges chamfered and its sides coloured in
    horizontal bands, [(up_to_fraction, colour), ...] from the bottom. Straight lines and
    flat panels: manufactured, which is the whole read against everything else on the map
    being lumpy and alive."""
    def rect(z, inset):
        return [Vector((lo.x + inset, lo.y + inset, z)), Vector((hi.x - inset, lo.y + inset, z)),
                Vector((hi.x - inset, hi.y - inset, z)), Vector((lo.x + inset, hi.y - inset, z))]
    side_top = hi.z - bevel
    levels = [(lo.z, bands[0][1])]
    for (frac, col) in bands:
        levels.append((min(side_top, lo.z + (hi.z - lo.z) * frac), col))
    for (z0, _), (z1, col) in zip(levels, levels[1:]):
        if z1 <= z0:
            continue
        r0, r1 = rect(z0, 0.0), rect(z1, 0.0)
        for k in range(4):
            k2 = (k + 1) % 4
            b.quad(r0[k], r0[k2], r1[k2], r1[k], col, col, col, col)
    top_col = mix(bands[-1][1], (1.0, 1.0, 1.0), 0.08)
    r0, r1 = rect(side_top, 0.0), rect(hi.z, bevel)
    for k in range(4):
        k2 = (k + 1) % 4
        b.quad(r0[k], r0[k2], r1[k2], r1[k], bands[-1][1], bands[-1][1], top_col, top_col)
    b.quad(r1[0], r1[1], r1[2], r1[3], top_col, top_col, top_col, top_col)
    base = rect(lo.z, 0.0)
    b.quad(base[3], base[2], base[1], base[0], GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)


def _turret_head(k=1.0):
    """The turret's head: a machine off the wreck -- white plating, the orange band, twin
    barrels and a red eye -- built round its own pivot, the middle of its turntable, with
    its barrels along +Y (the game's -Z, the way a node faces), at `k` times the sentry's
    size. Returns (head, where the muzzle is relative to the pivot)."""
    head = Builder()
    # The housing: plating off the wreck, with the orange band round it. Big enough to
    # be the first thing seen on the stand -- at the first size it was a white box on a
    # tall set of stilts, and the stilts were what read.
    _slab(head, Vector((-0.21, -0.21, 0.0)), Vector((0.21, 0.19, 0.28)),
          [(0.40, METAL), (0.58, HAZARD), (1.0, METAL)], 0.05)
    # Armour plates on the flanks, so the silhouette is not a plain box.
    for sx in (-1.0, 1.0):
        lo = Vector((0.21 if sx > 0 else -0.24, -0.15, 0.03))
        hi = Vector((0.24 if sx > 0 else -0.21, 0.13, 0.22))
        _slab(head, lo, hi, [(1.0, METAL_DARK)], 0.01)
    # Twin barrels, with a brake on each muzzle. Their tips stay within half a metre of
    # the pivot, so however the head turns it never reaches past the stand's footprint.
    for x in (-0.08, 0.08):
        head.tube([Vector((x, 0.19, 0.12)), Vector((x, 0.32, 0.12)), Vector((x, 0.43, 0.12))],
                  [0.034, 0.03, 0.03], [METAL_DARK] * 3, 8)
        head.tube([Vector((x, 0.42, 0.12)), Vector((x, 0.47, 0.12))], [0.042, 0.042], [METAL_DARK, GUNMETAL], 8)
    # The eye: a dark lens with a red light in it.
    _slab(head, Vector((-0.06, 0.18, 0.18)), Vector((0.06, 0.215, 0.25)), [(1.0, LENS)], 0.006)
    head.quad(Vector((-0.014, 0.2155, 0.204)), Vector((0.014, 0.2155, 0.204)),
              Vector((0.014, 0.2155, 0.228)), Vector((-0.014, 0.2155, 0.228)), LENS_DOT, LENS_DOT, LENS_DOT, LENS_DOT)
    # A whip antenna off the back, tipped orange.
    head.tube([Vector((-0.14, -0.16, 0.28)), Vector((-0.14, -0.16, 0.56))], [0.009, 0.006], [METAL_DARK, METAL_DARK], 5)
    _slab(head, Vector((-0.155, -0.175, 0.56)), Vector((-0.125, -0.145, 0.59)), [(1.0, HAZARD)], 0.004)

    if k != 1.0:
        head.verts = [v * k for v in head.verts]
    return head, Vector((0.0, 0.47, 0.12)) * k


# ==============================================================================
# Piles on the ground: what a drop of each resource looks like
# ==============================================================================

MEAT = (0.60, 0.17, 0.13)
MEAT_DARK = (0.36, 0.09, 0.07)
FAT = (0.86, 0.74, 0.62)
# Fired earth, weathered: at (0.55, 0.30, 0.17) the jars at the water spot were the most
# saturated thing on the map, orange as traffic cones.
CLAY = (0.46, 0.29, 0.19)
CLAY_DARK = (0.29, 0.18, 0.12)
WATER = (0.16, 0.42, 0.62)
# A hide (v0.6 round three): the hair side out, dark and dun, the flesh side pale where it shows
# at the ends of the roll.
HIDE_OUT = (0.36, 0.25, 0.15)
HIDE_OUT_LIGHT = (0.47, 0.34, 0.21)
HIDE_IN = (0.72, 0.58, 0.42)


def _log(b, p0, p1, radius, rng):
    """A short split log: bark round the sides, pale cut faces at both ends."""
    sides = 7
    rings = b.tube([p0, p0.lerp(p1, 0.5), p1], [radius, radius * rng.uniform(0.95, 1.05), radius],
                   [mix(BARK, BARK_LIGHT, 0.3), mix(BARK, BARK_LIGHT, 0.6), mix(BARK, BARK_LIGHT, 0.3)], sides)
    for ring, centre, flip in ((rings[0], p0, True), (rings[-1], p1, False)):
        for k in range(sides):
            k2 = (k + 1) % sides
            a, c = (ring[k2], ring[k]) if flip else (ring[k], ring[k2])
            b.tri(a, c, centre, FRESH_WOOD, FRESH_WOOD, mix(FRESH_WOOD, BARK_LIGHT, 0.35))


def drop_wood(seed):
    """Split logs stacked three and two, cut ends out."""
    rng = random.Random(seed)
    b = Builder()
    r = 0.045
    for x in (-0.095, 0.0, 0.095):
        _log(b, Vector((x, -0.18, r)), Vector((x + rng.uniform(-0.02, 0.02), 0.18, r)), r * rng.uniform(0.9, 1.1), rng)
    for x in (-0.048, 0.048):
        _log(b, Vector((x, -0.17, r * 2.7)), Vector((x + rng.uniform(-0.02, 0.02), 0.17, r * 2.7)),
             r * rng.uniform(0.9, 1.05), rng)
    return b


def drop_stone(seed):
    """A few quarried stones heaped together, pale where they were split."""
    rng = random.Random(seed)
    b = Builder()
    for (x, y, z, size) in ((0.0, 0.0, 0.0, 0.11), (0.12, 0.05, 0.0, 0.08), (-0.11, 0.06, 0.0, 0.085),
                            (0.03, -0.12, 0.0, 0.08), (0.02, 0.02, 0.07, 0.07)):
        _boulder(b, Vector((x, y, z)), size, rng, fresh=rng.random() < 0.6)
    return b


def drop_bone(seed):
    """Long bones in a heap."""
    rng = random.Random(seed)
    b = Builder()
    _bone(b, Vector((-0.16, -0.06, 0.03)), Vector((0.15, 0.08, 0.03)), rng)
    _bone(b, Vector((-0.10, 0.13, 0.05)), Vector((0.10, -0.12, 0.08)), rng)
    _bone(b, Vector((0.03, -0.16, 0.03)), Vector((0.07, 0.15, 0.06)), rng)
    return b


def drop_meat(seed):
    """A haunch -- the drumstick everyone reads as MEAT -- with the bone end out."""
    rng = random.Random(seed)
    b = Builder()
    pts, faces = _icosphere(1.0, rng, 0.05)
    centre = Vector((0.03, 0.0, 0.085))
    out = []
    for q in pts:
        taper = 1.0 - 0.25 * max(0.0, -q.x)      # the thigh narrows towards the bone
        out.append(centre + Vector((q.x * 0.15, q.y * 0.10 * taper, q.z * 0.085 * taper)))
    for (i, j, k) in faces:
        n = (out[j] - out[i]).cross(out[k] - out[i])
        up = n.normalized().z if n.length > 1e-9 else 0.0
        c = mix(MEAT, MEAT_DARK, rng.uniform(0.0, 0.45)) if up > 0.3 else mix(MEAT_DARK, MEAT, 0.3)
        if rng.random() < 0.12:
            c = mix(c, FAT, 0.6)                   # marbling
        b.tri(out[i], out[j], out[k], c, c, c)
    _bone(b, Vector((-0.09, 0.0, 0.075)), Vector((-0.21, 0.0, 0.085)), rng)
    return b


def drop_hide(seed):
    """A hide rolled up, hair side out, pale flesh side spiralling at its ends, tied with vine."""
    rng = random.Random(seed)
    b = Builder()
    r = 0.075
    half = 0.17
    seg = 12
    # The roll: a slightly flattened cylinder along x, its outside mottled.
    rings = []
    cols = []
    for i in range(7):
        x = -half + 2 * half * i / 6
        rr = r * (0.9 if i in (0, 6) else 1.0) * rng.uniform(0.97, 1.03)
        rings.append([Vector((x, math.cos(math.tau * k / seg) * rr, r * 0.9 + math.sin(math.tau * k / seg) * rr * 0.82))
                      for k in range(seg)])
        cols.append([jitter(mix(HIDE_OUT, HIDE_OUT_LIGHT, rng.uniform(0.0, 0.7)), rng, 0.02) for _ in range(seg)])
    _rings(b, rings, cols)
    # Its ends: the flesh side, spiralling in.
    for end, sign in ((rings[0], -1.0), (rings[-1], 1.0)):
        centre = Vector((end[0].x + sign * 0.004, 0.0, r * 0.9))
        for k in range(seg):
            a, c = end[k], end[(k + 1) % seg]
            if sign < 0:
                b.tri(c, a, centre, HIDE_IN, HIDE_IN, mix(HIDE_IN, HIDE_OUT, 0.5))
            else:
                b.tri(a, c, centre, HIDE_IN, HIDE_IN, mix(HIDE_IN, HIDE_OUT, 0.5))
    # A loose flap where the roll ends, lying on the ground.
    b.quad(Vector((-0.12, r * 0.95, 0.02)), Vector((0.12, r * 0.95, 0.02)),
           Vector((0.13, r * 1.9, 0.004)), Vector((-0.11, r * 1.8, 0.004)),
           HIDE_OUT, HIDE_OUT, HIDE_OUT_LIGHT, HIDE_OUT_LIGHT)
    # Two ties of vine round it.
    for x in (-0.08, 0.09):
        pts = [Vector((x, math.cos(math.tau * k / 9) * (r + 0.01), r * 0.9 + math.sin(math.tau * k / 9) * (r * 0.82 + 0.01)))
               for k in range(10)]
        b.tube(pts, [0.009] * 10, [VINE_ROPE] * 10, 4)
    return b


def drop_water(seed):
    """Water carried in a clay pot, showing at the mouth."""
    rng = random.Random(seed)
    b = Builder()
    seg = 14
    profile = [(0.07, 0.0), (0.12, 0.05), (0.135, 0.10), (0.11, 0.165), (0.08, 0.195), (0.09, 0.215)]
    rings, cols = [], []
    for (r, z) in profile:
        rings.append([Vector((math.cos(math.tau * k / seg) * r, math.sin(math.tau * k / seg) * r, z))
                      for k in range(seg)])
        cols.append([jitter(mix(CLAY_DARK, CLAY, min(1.0, z / 0.12)), rng, 0.02) for _ in range(seg)])
    _rings(b, rings, cols)
    for k in range(seg):
        b.tri(rings[0][(k + 1) % seg], rings[0][k], Vector((0.0, 0.0, 0.0)), CLAY_DARK, CLAY_DARK, CLAY_DARK)
    # The inside of the lip, down to the water.
    lip, wet = rings[-1], [Vector((math.cos(math.tau * k / seg) * 0.078, math.sin(math.tau * k / seg) * 0.078, 0.2))
                           for k in range(seg)]
    for k in range(seg):
        k2 = (k + 1) % seg
        b.quad(lip[k2], lip[k], wet[k], wet[k2], CLAY, CLAY, CLAY_DARK, CLAY_DARK)
        b.tri(wet[k], wet[k2], Vector((0.0, 0.0, 0.2)), WATER, WATER, mix(WATER, (1.0, 1.0, 1.0), 0.15))
    return b


# ==============================================================================
# The water spot: where the Hero draws water from the river
# ==============================================================================

WET_SOIL = (0.11, 0.085, 0.06)
TRODDEN = (0.19, 0.15, 0.10)
VINE_ROPE = (0.36, 0.30, 0.16)


def _pot(b, base, height, rng, lying=False, water=True):
    """A clay water jar, `height` metres tall: the drop's pot, bigger. `lying` tips it
    on its side with its mouth towards -Y, the way a jar left to drain lies."""
    seg = 14
    k = height / 0.215
    profile = [(0.07, 0.0), (0.12, 0.05), (0.135, 0.10), (0.11, 0.165), (0.08, 0.195), (0.09, 0.215)]
    radius = 0.135 * k

    def place(v):
        if not lying:
            return base + v
        # Axis from +Z to -Y, resting on its widest point.
        return base + Vector((v.x, -v.z, v.y + radius))
    rings, cols = [], []
    for (r, z) in profile:
        rings.append([place(Vector((math.cos(math.tau * i / seg) * r * k, math.sin(math.tau * i / seg) * r * k, z * k)))
                      for i in range(seg)])
        cols.append([jitter(mix(CLAY_DARK, CLAY, min(1.0, z / 0.12)), rng, 0.025) for _ in range(seg)])
    _rings(b, rings, cols)
    bottom = place(Vector((0.0, 0.0, 0.0)))
    for i in range(seg):
        b.tri(rings[0][(i + 1) % seg], rings[0][i], bottom, CLAY_DARK, CLAY_DARK, CLAY_DARK)
    lip = rings[-1]
    inner = [place(Vector((math.cos(math.tau * i / seg) * 0.078 * k, math.sin(math.tau * i / seg) * 0.078 * k, 0.2 * k)))
             for i in range(seg)]
    mouth = place(Vector((0.0, 0.0, 0.2 * k)))
    for i in range(seg):
        i2 = (i + 1) % seg
        b.quad(lip[i2], lip[i], inner[i], inner[i2], CLAY, CLAY, CLAY_DARK, CLAY_DARK)
        c = WATER if water else CHAR
        b.tri(inner[i], inner[i2], mouth, c, c, mix(c, (1.0, 1.0, 1.0), 0.12 if water else 0.0))


def _flat_stone(b, centre, sx, sy, height, rng, wet_side=None):
    """A flat stone laid on the ground to kneel or step on: an irregular octagon with a
    chamfered, slightly domed top. `wet_side` darkens the edge facing that way -- the edge
    the river laps."""
    n = 9
    base, top = [], []
    for i in range(n):
        a = math.tau * i / n + rng.uniform(-0.12, 0.12)
        r = rng.uniform(0.86, 1.08)
        d = Vector((math.cos(a) * sx * r, math.sin(a) * sy * r, 0.0))
        base.append(centre + d + Vector((0.0, 0.0, -0.03)))
        top.append(centre + d * 0.86 + Vector((0.0, 0.0, height * rng.uniform(0.85, 1.0))))
    crown = centre + Vector((0.0, 0.0, height * 1.12))

    def shade(p, lift):
        c = mix(ROCK_DARK, ROCK, lift)
        if wet_side is not None and (p - centre).normalized().dot(wet_side) > 0.35:
            c = mix(c, (0.12, 0.12, 0.11), 0.55)
        return jitter(c, rng, 0.02)
    for i in range(n):
        i2 = (i + 1) % n
        b.quad(base[i], base[i2], top[i2], top[i], shade(base[i], 0.1), shade(base[i2], 0.1),
               shade(top[i2], 0.7), shade(top[i], 0.7))
        b.tri(top[i], top[i2], crown, shade(top[i], 0.75), shade(top[i2], 0.75), mix(ROCK, ROCK_LIGHT, 0.4))


def _rope_coil(b, centre, radius, thickness, turns_col, rng):
    """A coil of vine rope lying flat: a fat ring."""
    around, tube = 14, 5
    rings = []
    for i in range(around):
        a = math.tau * i / around
        c = centre + Vector((math.cos(a) * radius, math.sin(a) * radius, thickness))
        out = Vector((math.cos(a), math.sin(a), 0.0))
        rings.append([c + (out * math.cos(math.tau * j / tube) + UP * math.sin(math.tau * j / tube)) * thickness
                      for j in range(tube)])
    for i in range(around):
        i2 = (i + 1) % around
        for j in range(tube):
            j2 = (j + 1) % tube
            col = jitter(turns_col, rng, 0.03)
            b.quad(rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2], col, col, col, col)


def water_landing(seed):
    """The spot on the bank where the Hero draws water: a patch of trodden wet mud, a flat
    stone at the water's edge to kneel on, clay jars set down behind it, one tipped over to
    drain, and a coil of vine rope. The river side is -Y: the game turns it to face the
    water. It was a blue puddle in the middle of the field."""
    rng = random.Random(seed)
    b = Builder()
    # The trodden mud, darkest and wettest towards the water.
    n = 20
    centre = Vector((0.0, 0.05, 0.012))
    rim = []
    for i in range(n):
        a = math.tau * i / n
        r = rng.uniform(0.72, 0.86)
        rim.append(centre + Vector((math.cos(a) * r, math.sin(a) * r * 0.95, 0.0)))
    mid = centre + Vector((0.0, 0.0, 0.012))
    for i in range(n):
        i2 = (i + 1) % n
        ca = mix(TRODDEN, WET_SOIL, max(0.0, -rim[i].y) * 1.2)
        cb = mix(TRODDEN, WET_SOIL, max(0.0, -rim[i2].y) * 1.2)
        b.tri(rim[i], rim[i2], mid, ca, cb, mix(TRODDEN, SOIL_LIGHT, 0.25))
    # The kneeling stone at the water's edge, and a smaller one beside it.
    _flat_stone(b, Vector((0.0, -0.5, 0.0)), 0.46, 0.28, 0.11, rng, wet_side=Vector((0.0, -1.0, 0.0)))
    _flat_stone(b, Vector((0.5, -0.12, 0.0)), 0.22, 0.2, 0.08, rng)
    # The jars.
    _pot(b, Vector((-0.38, 0.38, 0.0)), 0.46, rng)
    _pot(b, Vector((-0.02, 0.5, 0.0)), 0.3, rng)
    _pot(b, Vector((0.42, 0.42, 0.0)), 0.28, rng, lying=True, water=False)
    _rope_coil(b, Vector((0.36, -0.52, 0.0)), 0.13, 0.028, VINE_ROPE, rng)
    return b


# ==============================================================================
# The cabin's palette: the crew module itself is tools/generate_cabin.py module
# ==============================================================================

HEAT_TILE = (0.12, 0.12, 0.13)
HEAT_TILE_LIGHT = (0.20, 0.20, 0.21)
SCORCH = (0.05, 0.05, 0.055)
SOLAR = (0.07, 0.11, 0.24)
SOLAR_LINE = (0.30, 0.34, 0.42)
ASH = (0.30, 0.29, 0.27)


# ==============================================================================
# Cliffs: columnar basalt, for the valley walls
# ==============================================================================

# Basalt is DARK. The crag palette above is weathered and lichened, pale enough to read
# against the sun; columns cut from it came out as a cluster of white pencils.
BASALT = (0.17, 0.17, 0.18)
BASALT_MID = (0.25, 0.25, 0.26)
BASALT_TOP = (0.33, 0.33, 0.34)

def _hex_column(b, centre, radius, height, tilt, top_col, rng):
    """One basalt column: a hexagonal prism, dark at the foot, a slightly tilted top."""
    lean = Vector((tilt[0], tilt[1], 0.0))
    base = [centre + Vector((math.cos(math.tau * k / 6 + 0.5236) * radius,
                             math.sin(math.tau * k / 6 + 0.5236) * radius, -0.3)) for k in range(6)]
    slope = Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.0))
    top = []
    for k in range(6):
        off = base[k] - centre
        top.append(Vector((base[k].x, base[k].y, 0.0)) + lean * height + UP * (height + off.dot(slope) * 2.0))
    # Flat on top, which is what makes a column read as basalt rather than a crystal:
    # the middle of the top sits at the height of its rim.
    top_mid = centre + lean * height + UP * height
    foot = BASALT
    upper = mix(BASALT, BASALT_MID, rng.uniform(0.55, 1.0))
    for k in range(6):
        k2 = (k + 1) % 6
        b.quad(base[k], base[k2], top[k2], top[k], foot, foot, upper, upper)
    for k in range(6):
        b.tri(top[k], top[(k + 1) % 6], top_mid, top_col, top_col, jitter(top_col, rng, 0.03))


def basalt_cliff(seed):
    """A stretch of escarpment: basalt columns packed in a honeycomb strip, tallest along
    the back and in the middle, stepping down to the front and the ends, moss and ferns
    on the tops. The volcanic cliff everyone recognises, and it says VOLCANIC VALLEY
    where a smooth green bowl said nothing.

    The front -- the side that steps down -- faces Blender -Y, the game's +Z; the game
    turns each one to face into the valley. About 7 m along and 4 m tall."""
    rng = random.Random(seed)
    b = Builder()
    r = 0.36
    dx = r * math.sqrt(3.0)
    dy = r * 1.5
    across = 12
    rows = 4
    for row in range(rows):
        back = row / (rows - 1)                        # 0 at the front, 1 at the back
        for i in range(across):
            x = (i - (across - 1) / 2.0) * dx + (dx * 0.5 if row % 2 else 0.0)
            y = (row - (rows - 1) / 2.0) * dy
            along = abs(x) / (across * dx * 0.5)       # 0 in the middle, 1 at the ends
            h = 4.0 * (0.45 + 0.55 * back) * (1.0 - 0.55 * along * along) * rng.uniform(0.8, 1.1)
            if row == 0 and rng.random() < 0.25:
                h *= 0.45                              # the odd broken stump at the front
            # In steps, the way the columns break: a stair of flat tops, not a slope.
            h = max(0.35, round(h / 0.35) * 0.35)
            top = mix(MOSS, VINE, rng.uniform(0.0, 0.5)) if rng.random() < 0.55 else mix(BASALT_MID, BASALT_TOP, rng.uniform(0.3, 1.0))
            _hex_column(b, Vector((x, y, 0.0)), r * rng.uniform(0.94, 1.0), h,
                        (rng.uniform(-0.03, 0.03), rng.uniform(-0.05, 0.0)), top, rng)
    # Scree at the foot of the front: fallen pieces of column.
    for _ in range(9):
        x = rng.uniform(-across * dx * 0.45, across * dx * 0.45)
        y = -(rows / 2.0) * dy - rng.uniform(0.2, 0.9)
        _boulder(b, Vector((x, y, 0.0)), rng.uniform(0.18, 0.32), rng)
    return b


# ==============================================================================
# The stone he quarries (UI-POLISH T21, v0.6 round four, the player: "比如石头，树木，能点的个背景现在很
# 像"). It was a heap of mossy grey boulders, like every rock the valley is strewn with. It is the
# Chinle's own bedded sandstone now, breaking out of the ground in a low ledge -- angular slabs banded
# red, ochre and mauve, the way those rocks are -- with a spill of broken pieces at its foot: what can be
# cut is the rock that is already breaking, and the grey rounded boulders are the valley.
# ==============================================================================

# sRGB, as the rest: the Chinle's red and ochre beds, a mauve one, and the pale sand between.
CHINLE_BEDS = [(0.50, 0.28, 0.20), (0.58, 0.43, 0.29), (0.46, 0.35, 0.35), (0.66, 0.57, 0.45), (0.54, 0.33, 0.24)]
CHINLE_TOP = (0.66, 0.58, 0.47)          # the weathered top of a slab, the palest
CHINLE_FRESH = (0.86, 0.74, 0.58)        # a fresh break
CHINLE_SHADE = (0.34, 0.20, 0.14)        # the foot of it, in the joints


def _chip(b, centre, size, rng, col):
    """A broken piece of sandstone lying on the ground: a small squat wedge, angular."""
    w = size * rng.uniform(0.8, 1.2)
    d = size * rng.uniform(0.6, 1.0)
    h = size * rng.uniform(0.4, 0.7)
    a = rng.uniform(0.0, math.pi)
    ax = Vector((math.cos(a), math.sin(a), 0.0))
    ay = Vector((-ax.y, ax.x, 0.0))
    base = [centre + ax * sx * w + ay * sy * d for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    top = [p + UP * h + ax * rng.uniform(-0.3, 0.1) * w for p in base]
    lit = mix(col, CHINLE_TOP, 0.35)
    for k in range(4):
        k2 = (k + 1) % 4
        b.quad(base[k], base[k2], top[k2], top[k], mix(col, CHINLE_SHADE, 0.3), mix(col, CHINLE_SHADE, 0.3), col, col)
    b.quad(top[0], top[1], top[2], top[3], lit, lit, lit, lit)


def _sandstone_chunk(b, centre, size, rng, base, fresh=False):
    """A broken block of the Chinle's sandstone: an icosahedron pushed about into an angular chunk,
    flat-topped where it weathers, its colour the bed it came from -- only faintly banded, as the
    beds show through a weathered face -- darker at its foot, paler on top, pale and clean where it is
    freshly broken. Angular and red-brown where the valley's boulders are rounded and grey."""
    t = (1.0 + 5.0 ** 0.5) / 2.0
    raw = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
           (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    squash = rng.uniform(0.75, 1.0)
    pts = []
    for (x, y, z) in raw:
        v = Vector((x, y, z)).normalized() * size * rng.uniform(0.78, 1.2)
        v.z *= squash
        if v.z > size * squash * 0.45:           # a flat weathered top, as sandstone breaks
            v.z = size * squash * 0.45 + (v.z - size * squash * 0.45) * 0.2
        pts.append(centre + v + UP * (size * squash * 0.4))
    top_z = max(q.z for q in pts)
    for (i, j, k) in faces:
        cs = []
        for n in (i, j, k):
            h = max(0.0, min(1.0, (pts[n].z - centre.z) / max(0.01, top_z - centre.z)))
            bed = CHINLE_BEDS[int(pts[n].z / 0.16) % len(CHINLE_BEDS)]
            col = mix(base, bed, 0.25)
            col = mix(mix(col, CHINLE_SHADE, 0.45), mix(col, CHINLE_TOP, 0.35), h)
            if fresh and h > 0.7:
                col = mix(col, CHINLE_FRESH, 0.6)
            cs.append(col)
        b.tri(pts[i], pts[j], pts[k], cs[0], cs[1], cs[2])


def sandstone_outcrop(seed, quarried=False):
    """Stone to quarry: an outcrop of the Chinle's sandstone breaking out of the ground in angular
    red-brown blocks, broken pieces spilled at its foot. Quarried, it is cut down to low stubs with
    pale fresh tops, and the spill is rubble."""
    rng = random.Random(seed)
    b = Builder()
    chunks = [
        # (x, y, size): the big block at the back, smaller ones leaning on it
        (0.05, 0.12, 0.62), (-0.42, -0.22, 0.44), (0.42, -0.30, 0.40), (-0.30, 0.42, 0.32),
    ]
    for (x, y, size) in chunks:
        at = Vector((x, y, -size * 0.1))
        _sandstone_chunk(b, at, size * (0.55 if quarried else 1.0), rng, rng.choice(CHINLE_BEDS), fresh=quarried)
    for _ in range(18 if quarried else 11):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.75, 1.05)
        centre = Vector((math.cos(a) * r, math.sin(a) * r * 0.9, 0.0))
        _chip(b, centre, rng.uniform(0.05, 0.1), rng, rng.choice(CHINLE_BEDS))
    return b


# ==============================================================================
# Fire (GAME-DESIGN 9.3, v0.7 "火与夜"): what the Hero burns wood in. The flame is the game's own
# (Fire.gd: the engine's particles and a light, lit at dusk); these are the stones and the wood.
# ==============================================================================

ASH = (0.22, 0.21, 0.20)
ASH_DARK = (0.08, 0.075, 0.07)
RESIN = (0.10, 0.07, 0.04)


def _ash_bed(b, radius, rng, z=0.012):
    """A disc of ash and coals, darker in the middle where it burns hottest."""
    n = 14
    centre = Vector((0.0, 0.0, z))
    ring = [Vector((math.cos(math.tau * k / n) * radius * rng.uniform(0.85, 1.05),
                    math.sin(math.tau * k / n) * radius * rng.uniform(0.85, 1.05), z * 0.3)) for k in range(n)]
    for k in range(n):
        b.tri(ring[k], ring[(k + 1) % n], centre, ASH, ASH, ASH_DARK)


def _charred_log(b, p0, p1, radius):
    """A log with one end in the fire: bark at `p0`, charcoal at `p1`."""
    sides = 6
    rings = b.tube([p0, p0.lerp(p1, 0.5), p1], [radius, radius * 0.95, radius * 0.75],
                   [mix(BARK, BARK_LIGHT, 0.3), mix(BARK, CHAR, 0.5), CHAR], sides)
    for k in range(sides):
        k2 = (k + 1) % sides
        b.tri(rings[0][k2], rings[0][k], p0, FRESH_WOOD, FRESH_WOOD, mix(FRESH_WOOD, BARK_LIGHT, 0.35))
        b.tri(rings[-1][k], rings[-1][k2], p1, CHAR, CHAR, CHAR)


def campfire(seed):
    """A ring of stones round a bed of ash, logs leaned together over it -- a metre across, a cell of
    the building grid: the fire he can make with his hands and wood."""
    rng = random.Random(seed)
    b = Builder()
    _ash_bed(b, 0.3, rng)
    n = 9
    for k in range(n):
        a = math.tau * (k + rng.uniform(-0.15, 0.15)) / n
        _boulder(b, Vector((math.cos(a) * 0.37, math.sin(a) * 0.37, 0.0)), rng.uniform(0.07, 0.095), rng)
    # Leaned together, their feet in the ash and their tops meeting over the middle.
    m = 5
    for k in range(m):
        a = math.tau * (k + rng.uniform(-0.1, 0.1)) / m
        foot = Vector((math.cos(a) * 0.27, math.sin(a) * 0.27, 0.02))
        top = Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.3 + rng.uniform(-0.03, 0.03)))
        _charred_log(b, foot, top, rng.uniform(0.022, 0.03))
    return b


def brazier(seed):
    """A stone bowl on a drystone plinth, logs laid crosswise in it: a fire raised to the Hero's chest,
    which lights further than one on the ground. Stone, as the set crossbow's plinth is laid."""
    rng = random.Random(seed)
    b = Builder()
    half = 0.3
    height = 0.45
    courses = 3
    for c in range(courses):
        z0 = height * c / courses
        z1 = height * (c + 1) / courses
        n = 2 if c % 2 == 0 else 3
        for i in range(n):
            x0 = -half + 2.0 * half * i / n
            x1 = -half + 2.0 * half * (i + 1) / n
            for (y0, y1) in ((-half, 0.0), (0.0, half)):
                col = mix(ROCK, ROCK_DARK, rng.uniform(0.0, 0.5))
                _dry_stone(b, Vector((x0 + 0.01, y0 + 0.01, z0)), Vector((x1 - 0.01, y1 - 0.01, z1)), rng, col)
    # The bowl, turned in stone: out and up from the plinth to its rim, and down inside to a sooty floor.
    up = [Vector((0.0, 0.0, height + dz)) for dz in (0.0, 0.1, 0.2, 0.24)]
    b.tube(up, [0.2, 0.3, 0.36, 0.37], [ROCK_DARK, ROCK, ROCK, ROCK_LIGHT], 12)
    rim = [Vector((0.0, 0.0, height + 0.24)), Vector((0.0, 0.0, height + 0.245))]
    b.tube(rim, [0.37, 0.31], [ROCK_LIGHT, mix(ROCK, CHAR, 0.4)], 12)
    down = [Vector((0.0, 0.0, height + dz)) for dz in (0.245, 0.17, 0.12)]
    b.tube(down, [0.31, 0.26, 0.14], [mix(ROCK, CHAR, 0.4), CHAR, CHAR], 12)
    floor = height + 0.12
    for k in range(12):
        a0 = math.tau * k / 12
        a1 = math.tau * (k + 1) / 12
        b.tri(Vector((math.cos(a0) * 0.14, math.sin(a0) * 0.14, floor)), Vector((math.cos(a1) * 0.14, math.sin(a1) * 0.14, floor)),
              Vector((0.0, 0.0, floor)), ASH_DARK, ASH_DARK, ASH)
    # Logs laid crosswise, two and two, burnt where they cross.
    for layer, turn in ((0, 0.0), (1, math.pi * 0.5)):
        z = floor + 0.04 + layer * 0.05
        for off in (-0.07, 0.07):
            d = Vector((math.cos(turn), math.sin(turn), 0.0))
            n = Vector((-d.y, d.x, 0.0))
            p0 = d * -0.22 + n * off + Vector((0.0, 0.0, z))
            p1 = d * 0.22 + n * (off + rng.uniform(-0.02, 0.02)) + Vector((0.0, 0.0, z + 0.01))
            _charred_log(b, p0, p0.lerp(p1, 0.5), 0.028)
            _charred_log(b, p1, p0.lerp(p1, 0.5), 0.028)
    return b


def torch(seed):
    """A torch: a straight stick, its head wrapped in resin-soaked bark lashed with vine. Held at the
    origin, the head up -- the flame is the game's, at the top of the head."""
    rng = random.Random(seed)
    b = Builder()
    shaft = [Vector((0.0, 0.0, z)) for z in (-0.2, 0.0, 0.2, 0.34)]
    b.tube(shaft, [0.014, 0.016, 0.017, 0.018], [BARK, mix(BARK, BARK_LIGHT, 0.5), BARK_LIGHT, BARK_LIGHT], 6)
    head = [Vector((0.0, 0.0, z)) for z in (0.32, 0.36, 0.42, 0.47, 0.49)]
    b.tube(head, [0.02, 0.036, 0.04, 0.033, 0.012], [RESIN, RESIN, mix(RESIN, CHAR, 0.5), CHAR, CHAR], 7,
           radial=lambda i, k: rng.uniform(0.9, 1.1))
    for z in (0.35, 0.43):
        _wrap(b, Vector((0.0, 0.0, z)), Vector((0.0, 0.0, 1.0)), 0.036, turns=2)
    return b



# ==============================================================================
# The ship's wrecks (GAME-DESIGN 9.3, "信标变成冒险"): torn pieces of the time-travel ship lying where
# they came down, each holding one of the beacon's parts. Plated as the cabin is -- the white plating,
# the orange markings -- and scorched by the fall, half in a burnt furrow, plates spilled round. The
# smoke over one is the game's own (WreckSmoke); what is here is metal and burnt ground.
# ==============================================================================

SCORCH = (0.09, 0.08, 0.07)
PLATE_ALT = (0.70, 0.72, 0.75)
CABLE = (0.14, 0.13, 0.12)
CABLE_RED = (0.55, 0.12, 0.08)
CIRCUIT = (0.10, 0.24, 0.16)
CHIP_DARK = (0.06, 0.06, 0.07)
OK_DOT = (0.30, 0.85, 0.40)


def _oriented_box(b, centre, half, yaw, pitch=0.0, roll=0.0, side=None, top=None, open_top=False):
    """A box of half-extents `half` about `centre`, turned `yaw` round the vertical, then pitched and
    rolled: a plate lying skew on the ground, a bay standing out of a hull. `open_top` leaves its lid
    off and shows its inside dark."""
    rot = Matrix.Rotation(yaw, 3, 'Z') @ Matrix.Rotation(pitch, 3, 'X') @ Matrix.Rotation(roll, 3, 'Y')
    hx, hy, hz = half
    lo = [centre + rot @ Vector((sx * hx, sy * hy, -hz)) for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [centre + rot @ Vector((sx * hx, sy * hy, hz)) for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    side = side or METAL
    top = top or mix(side, (1.0, 1.0, 1.0), 0.06)
    under = mix(side, (0.0, 0.0, 0.0), 0.4)
    if open_top:
        inside = CHIP_DARK
        for k in range(4):
            k2 = (k + 1) % 4
            b.quad(hi[k], hi[k2], lo[k2], lo[k], inside, inside, inside, inside)
    else:
        b.quad(hi[0], hi[1], hi[2], hi[3], top, top, top, top)
    b.quad(lo[3], lo[2], lo[1], lo[0], under, under, under, under)
    for k in range(4):
        k2 = (k + 1) % 4
        b.quad(lo[k], lo[k2], hi[k2], hi[k], side, side, side, side)
    return rot


def _scorched_furrow(b, rng, half_x, half_y):
    """Burnt ground where it came down: an uneven dark oval, ash at its middle, and clods of the
    earth it ploughed up heaped at its far end."""
    n = 18
    centre = Vector((0.0, 0.0, 0.012))
    ring = []
    for k in range(n):
        a = math.tau * k / n
        wob = rng.uniform(0.82, 1.08)
        ring.append(Vector((math.cos(a) * half_x * wob, math.sin(a) * half_y * wob, 0.004)))
    for k in range(n):
        b.tri(ring[k], ring[(k + 1) % n], centre, mix(SCORCH, SOIL, 0.5), mix(SCORCH, SOIL, 0.5), SCORCH)
    for _ in range(9):
        a = rng.uniform(-0.7, 0.7)
        at = Vector((math.cos(a) * half_x * rng.uniform(0.85, 1.05), math.sin(a) * half_y * rng.uniform(0.6, 1.0), 0.0))
        _chip(b, at, rng.uniform(0.07, 0.13), rng, mix(SOIL_LIGHT, CHINLE_SHADE, 0.4))


def _hull_shell(b, rng, length, radius, arc0, arc1, sink, roll, band_at=0.35):
    """A torn piece of the hull: `arc0`..`arc1` (radians round its axis, which runs along X) of a tube
    of plating `radius` round and `length` long, rolled `roll` onto its side and sunk `sink` into the
    ground. Its plating in panels, a band of the orange markings `band_at` along it, scorched towards
    the end it was torn off at (+X), which is ragged. Returns where on it things stand: its top."""
    n_a, n_l = 10, 8
    thick = 0.05
    rot = Matrix.Rotation(roll, 3, 'X')

    def at(a, x, r):
        return rot @ Vector((x, math.cos(a) * r, math.sin(a) * r)) + Vector((0.0, 0.0, -sink))

    x0 = -length * 0.5
    ends = [length * 0.5 - rng.uniform(0.0, 0.3) * length for _ in range(n_a + 1)]
    starts = [x0 + rng.uniform(0.0, 0.08) * length for _ in range(n_a + 1)]
    # Dented by the fall: the plating pushed in and out, the more towards the end it tore at.
    dents = [[rng.uniform(-1.0, 1.0) for _ in range(n_l + 1)] for _ in range(n_a + 1)]
    outer, inner = [], []
    for j in range(n_a + 1):
        a = arc0 + (arc1 - arc0) * j / n_a
        col_o, col_i = [], []
        for i in range(n_l + 1):
            x = starts[j] + (ends[j] - starts[j]) * i / n_l
            r = radius + dents[j][i] * (0.03 + 0.1 * (i / n_l) ** 2)
            col_o.append(at(a, x, r))
            col_i.append(at(a, x, r - thick))
        outer.append(col_o)
        inner.append(col_i)
    for j in range(n_a):
        for i in range(n_l):
            t = i / n_l
            panel = METAL if ((i // 2) + (j // 3)) % 2 == 0 else PLATE_ALT
            if abs(t - band_at) < 0.07:
                panel = HAZARD
            # Burnt towards the torn end, and soot streaked back along it from there.
            burn = max(0.0, min(1.0, (t - 0.2) * 1.5 + rng.uniform(-0.2, 0.2)))
            if rng.random() < 0.18:
                burn = min(1.0, burn + 0.45)
            c = mix(panel, SCORCH, burn * 0.9)
            b.quad(outer[j][i], outer[j][i + 1], outer[j + 1][i + 1], outer[j + 1][i], c, c, c, c)
            ci = mix(METAL_DARK, SCORCH, burn * 0.6)
            b.quad(inner[j + 1][i], inner[j + 1][i + 1], inner[j][i + 1], inner[j][i], ci, ci, ci, ci)
    # Its edges: the long ones, and the two ends -- the torn one charred.
    for j in (0, n_a):
        for i in range(n_l):
            c = METAL_DARK
            if j == 0:
                b.quad(inner[j][i], inner[j][i + 1], outer[j][i + 1], outer[j][i], c, c, c, c)
            else:
                b.quad(outer[j][i], outer[j][i + 1], inner[j][i + 1], inner[j][i], c, c, c, c)
    for j in range(n_a):
        b.quad(outer[j][0], outer[j + 1][0], inner[j + 1][0], inner[j][0], METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)
        b.quad(inner[j][n_l], inner[j + 1][n_l], outer[j + 1][n_l], outer[j][n_l], CHAR, CHAR, CHAR, CHAR)
    # Its ribs, bared at the torn end and bent.
    for j in (2, 5, 8):
        a = arc0 + (arc1 - arc0) * j / n_a
        base = at(a, ends[j] - 0.05, radius - thick * 0.5)
        tip = at(a + rng.uniform(-0.2, 0.2), ends[j] + rng.uniform(0.2, 0.45), radius * rng.uniform(0.8, 1.05))
        mid = base.lerp(tip, 0.5) + Vector((0.0, 0.0, rng.uniform(-0.08, 0.08)))
        b.tube([base, mid, tip], [0.035, 0.03, 0.022], [METAL_DARK, METAL_DARK, CHAR], 5)
    top_a = (arc0 + arc1) * 0.5
    return at(top_a, -length * 0.1, radius)


def _spilled_plates(b, rng, count, reach):
    """Plating torn off in the fall, lying skew round the wreck; one with its orange marking."""
    for k in range(count):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(reach * 0.65, reach)
        centre = Vector((math.cos(a) * r, math.sin(a) * r * 0.8, 0.02))
        panel = HAZARD if k == 0 else mix(METAL, SCORCH, rng.uniform(0.1, 0.55))
        _oriented_box(b, centre, (rng.uniform(0.14, 0.3), rng.uniform(0.1, 0.22), 0.012),
                      rng.uniform(0.0, math.pi), rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), side=panel)


def wreck(seed, part, searched=False):
    """A wreck of the ship holding `part` -- "antenna", "battery", "board": three metres of torn hull
    lying on its side in a scorched furrow, plates spilled round it, and on it what the part was
    fitted in: a bent mast with its dish, a battery bay, a console. `searched`: the part is gone out
    of it -- the mast's dish broken off, the bay's lid thrown down by it, the console's screen torn out."""
    rng = random.Random(seed)
    b = Builder()
    _scorched_furrow(b, rng, 1.65, 1.15)
    top = _hull_shell(b, rng, 2.5, 1.05, math.radians(25.0), math.radians(145.0), 0.42, math.radians(32.0))
    _spilled_plates(b, rng, 6, 1.55)
    if part == "antenna":
        foot = top + Vector((0.25, 0.1, -0.05))
        if searched:
            b.tube([foot, foot + Vector((0.06, 0.02, 0.45))], [0.04, 0.035], [METAL_DARK, CHAR], 6)
            _oriented_box(b, Vector((1.25, -0.9, 0.03)), (0.2, 0.14, 0.012), 0.6, side=mix(METAL, SCORCH, 0.3))
        else:
            knee = foot + Vector((0.12, 0.05, 0.7))
            tip = knee + Vector((0.35, 0.1, 0.25))
            b.tube([foot, knee, tip], [0.04, 0.035, 0.03], [METAL_DARK, METAL_DARK, METAL], 6)
            # The dish, hanging off the bent top, and the orange light at the tip.
            rim = []
            n = 10
            axis = Vector((0.6, 0.2, -0.3)).normalized()
            side = axis.cross(UP).normalized()
            up2 = side.cross(axis).normalized()
            centre = tip + axis * 0.1
            for k in range(n):
                a = math.tau * k / n
                rim.append(centre + (side * math.cos(a) + up2 * math.sin(a)) * 0.3 + axis * 0.1)
            for k in range(n):
                b.tri(rim[k], rim[(k + 1) % n], centre, METAL, METAL, PLATE_ALT)
                b.tri(rim[(k + 1) % n], rim[k], centre, METAL_DARK, METAL_DARK, METAL_DARK)
            _oriented_box(b, tip + Vector((0.0, 0.0, 0.05)), (0.035, 0.035, 0.035), 0.0, side=HAZARD)
    elif part == "battery":
        bay = top + Vector((-0.35, -0.25, 0.05))
        _oriented_box(b, bay, (0.34, 0.24, 0.2), 0.2, side=METAL_DARK, open_top=searched)
        if searched:
            _oriented_box(b, Vector((-1.2, -1.05, 0.03)), (0.34, 0.24, 0.015), 0.9, 0.1, side=mix(METAL, SCORCH, 0.2))
        else:
            _oriented_box(b, bay + Vector((0.0, 0.0, 0.21)), (0.35, 0.25, 0.015), 0.2, side=METAL)
            _oriented_box(b, bay + Vector((0.22, -0.1, 0.23)), (0.08, 0.08, 0.01), 0.2, side=HAZARD)
        # Its cables, run out of it onto the ground -- cut short once it has been opened.
        for (k, colr) in ((0, CABLE), (1, CABLE_RED)):
            start = bay + Vector((0.3, 0.1 * k - 0.05, -0.05))
            far = 0.35 if searched else 0.9
            mid = start + Vector((far * 0.5, 0.15 + 0.1 * k, -0.25))
            end = start + Vector((far, 0.3 + 0.15 * k, -start.z + 0.03))
            b.tube([start, mid, end], [0.022, 0.022, 0.02], [colr, colr, colr], 5)
    else:
        face = top + Vector((0.1, -0.35, 0.1))
        rot = _oriented_box(b, face, (0.42, 0.07, 0.3), 0.15, math.radians(-25.0), side=METAL)
        n_out = rot @ Vector((0.0, -1.0, 0.0))
        screen_at = face + n_out * 0.075
        if searched:
            _oriented_box(b, screen_at, (0.32, 0.01, 0.2), 0.15, math.radians(-25.0), side=CHIP_DARK)
            _oriented_box(b, Vector((0.9, -1.25, 0.03)), (0.32, 0.22, 0.012), 1.2, side=mix(METAL, SCORCH, 0.25))
            for k in range(3):
                start = screen_at + Vector((-0.15 + 0.15 * k, 0.0, -0.05))
                b.tube([start, start + Vector((0.02, -0.12, -0.18))], [0.012, 0.012], [CABLE_RED if k == 1 else CABLE] * 2, 4)
        else:
            _oriented_box(b, screen_at, (0.32, 0.01, 0.2), 0.15, math.radians(-25.0), side=LENS)
            for k in range(4):
                dot = screen_at + rot @ Vector((-0.24 + 0.16 * k, -0.012, -0.14))
                _oriented_box(b, dot, (0.025, 0.004, 0.018), 0.15, math.radians(-25.0),
                              side=LENS_DOT if k % 2 == 0 else OK_DOT)
    return b


def drop_antenna(seed):
    """The antenna out of its wreck: a dish folded half shut on a short mast, a base plate, the orange
    light at its tip."""
    rng = random.Random(seed)
    b = Builder()
    _oriented_box(b, Vector((0.0, 0.0, 0.02)), (0.09, 0.09, 0.02), 0.3, side=METAL_DARK)
    foot = Vector((0.0, 0.0, 0.04))
    head = Vector((0.04, 0.02, 0.24))
    b.tube([foot, head], [0.016, 0.013], [METAL_DARK, METAL], 6)
    n = 12
    axis = Vector((0.35, 0.1, 0.9)).normalized()
    side = axis.cross(Vector((1.0, 0.0, 0.0))).normalized()
    up2 = side.cross(axis).normalized()
    centre = head + axis * 0.02
    rim = [centre + (side * math.cos(math.tau * k / n) + up2 * math.sin(math.tau * k / n)) * 0.17 + axis * 0.07
           for k in range(n)]
    for k in range(n):
        b.tri(rim[k], rim[(k + 1) % n], centre, METAL, METAL, PLATE_ALT)
        b.tri(rim[(k + 1) % n], rim[k], centre, METAL_DARK, METAL_DARK, METAL_DARK)
    b.tube([centre, centre + axis * 0.16], [0.01, 0.008], [METAL_DARK, METAL_DARK], 5)
    _oriented_box(b, centre + axis * 0.17, (0.02, 0.02, 0.02), 0.0, side=HAZARD)
    return b


def drop_battery(seed):
    """A battery cell out of its bay: a dark block with the orange band round it and its two
    terminals, one capped red."""
    rng = random.Random(seed)
    b = Builder()
    body = Vector((0.0, 0.0, 0.1))
    _oriented_box(b, body, (0.16, 0.11, 0.1), 0.25, side=METAL_DARK)
    _oriented_box(b, body + Vector((0.0, 0.0, 0.01)), (0.165, 0.115, 0.03), 0.25, side=HAZARD)
    rot = Matrix.Rotation(0.25, 3, 'Z')
    for (k, cap) in ((-1, CABLE_RED), (1, METAL)):
        at = body + rot @ Vector((k * 0.08, 0.0, 0.1))
        b.tube([at, at + Vector((0.0, 0.0, 0.045))], [0.022, 0.02], [METAL_DARK, cap], 6)
    return b


def drop_board(seed):
    """The control board, in its case: a flat unit, its top a dark panel of chips and a lit screen,
    connector pins along one edge, the orange tab at a corner."""
    rng = random.Random(seed)
    b = Builder()
    yaw = -0.35
    rot = Matrix.Rotation(yaw, 3, 'Z')
    body = Vector((0.0, 0.0, 0.035))
    _oriented_box(b, body, (0.19, 0.14, 0.035), yaw, side=METAL)
    _oriented_box(b, body + Vector((0.0, 0.0, 0.037)), (0.16, 0.115, 0.004), yaw, side=CIRCUIT)
    for (x, y, sx, sy, colr) in ((-0.08, 0.04, 0.045, 0.035, CHIP_DARK), (0.05, 0.05, 0.03, 0.03, CHIP_DARK),
                                 (0.06, -0.05, 0.06, 0.035, LENS), (-0.09, -0.05, 0.03, 0.025, CHIP_DARK)):
        _oriented_box(b, body + rot @ Vector((x, y, 0.045)), (sx, sy, 0.006), yaw, side=colr)
    for k in range(7):
        _oriented_box(b, body + rot @ Vector((-0.12 + 0.04 * k, -0.15, 0.0)), (0.008, 0.012, 0.008), yaw, side=METAL_DARK)
    _oriented_box(b, body + rot @ Vector((0.17, 0.12, 0.04)), (0.025, 0.025, 0.006), yaw, side=HAZARD)
    return b


PROPS = {
    "stone_wall": (lambda s: stone_wall(s), [23]),
    "outcrop": (lambda s: outcrop(s), [5, 21]),
    "outcrop_quarried": (lambda s: outcrop(s, broken=True), [5]),
    "fallen_log": (lambda s: fallen_log(s), [8, 27]),
    "rock_formation": (lambda s: rock_formation(s), [4, 17, 33]),
    "nest": (lambda s: nest(s), [9]),
    "nest_coelophysis": (lambda s: nest_colony(s), [21]),
    "basalt_cliff": (lambda s: basalt_cliff(s), [41, 59, 77]),
    # What a drop of each resource is drawn as, named by the resource id the game uses.
    "drop_wood": (lambda s: drop_wood(s), [3]),
    "drop_stone": (lambda s: drop_stone(s), [5]),
    "drop_bone": (lambda s: drop_bone(s), [7]),
    "drop_food": (lambda s: drop_meat(s), [11]),
    "drop_water": (lambda s: drop_water(s), [13]),
    "drop_hide": (lambda s: drop_hide(s), [19]),
    "water_landing": (lambda s: water_landing(s), [17]),
    "sandstone_outcrop": (lambda s: sandstone_outcrop(s), [61]),
    "sandstone_quarried": (lambda s: sandstone_outcrop(s, quarried=True), [61]),
    "campfire": (lambda s: campfire(s), [31]),
    "brazier": (lambda s: brazier(s), [37]),
    "torch": (lambda s: torch(s), [43]),
    # The ship's wrecks, each by the part it holds, whole and searched; and the parts on the ground.
    "wreck_antenna": (lambda s: wreck(s, "antenna"), [71]),
    "wreck_antenna_searched": (lambda s: wreck(s, "antenna", searched=True), [71]),
    "wreck_battery": (lambda s: wreck(s, "battery"), [73]),
    "wreck_battery_searched": (lambda s: wreck(s, "battery", searched=True), [73]),
    "wreck_board": (lambda s: wreck(s, "board"), [79]),
    "wreck_board_searched": (lambda s: wreck(s, "board", searched=True), [79]),
    "drop_antenna": (lambda s: drop_antenna(s), [83]),
    "drop_battery": (lambda s: drop_battery(s), [89]),
    "drop_board": (lambda s: drop_board(s), [97]),
}

# Props made of named parts the game shows, hides or moves (Wall.dress, Gate): each part an
# object of its own, exported side by side into one file.
KITS = {
    "palisade": (lambda s: palisade(s), [3]),
    "bone_palisade": (lambda s: palisade(s, bone=True), [3]),
    "gate": (lambda s: gate(s), [5]),
    "trip_bow": (lambda s: trip_bow(s), [7]),
    "set_crossbow": (lambda s: set_crossbow(s), [11]),
    "set_crossbow_2": (lambda s: set_crossbow(s, twin=True), [11]),
}

def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    reset()
    mat = vertex_colour_material("PropVertex", 0.85, True)
    os.makedirs(OUT_DIR, exist_ok=True)
    made = []
    # Names after the "--" make only those props, so adding one does not re-export the rest.
    only = [a for a in args if not a.startswith("--")]
    for name, (fn, seeds) in PROPS.items():
        if only and name not in only:
            continue
        for v, seed in enumerate(seeds):
            label = "%s_%s" % (name, "abc"[v])
            obj = fn(seed).to_object(label, [mat])
            tris = len(obj.data.polygons)
            export(obj, os.path.join(OUT_DIR, label + ".glb"))
            print("[OK] %-20s %6d triangles  %.2f x %.2f x %.2f m" % (
                label, tris, obj.dimensions.x, obj.dimensions.y, obj.dimensions.z))
            made.append(obj)
    for name, (fn, seeds) in KITS.items():
        if only and name not in only:
            continue
        for v, seed in enumerate(seeds):
            label = "%s_%s" % (name, "abc"[v])
            objs = []
            for part, builder, where in fn(seed):
                obj = builder.to_object(part, [mat])
                obj.location = where
                objs.append(obj)
            export_objects(objs, os.path.join(OUT_DIR, label + ".glb"))
            print("[OK] %-20s %6d triangles  parts %s" % (
                label, sum(len(o.data.polygons) for o in objs), ", ".join(o.name for o in objs)))
            # The game finds the parts by name, and Blender makes a taken name unique, so the
            # names are freed for the next kit once this one is written.
            for o in objs:
                o.name = "%s.%s" % (label, o.name)
            made.extend(objs)
    if "--preview" in args:
        preview_props(made)


def export_objects(objs, path):
    """Several objects into one file, parents and all."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def preview_props(objs):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 900
    x = 0.0
    for o in objs:
        w = max(o.dimensions.x, o.dimensions.y)
        o.location = (x + w * 0.5, 0.0, 0.0)
        x += w + 0.5
    bpy.ops.mesh.primitive_plane_add(size=80, location=(x * 0.5, 0.0, 0.0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.14, 0.05, 1.0)
    g.data.materials.append(gm)
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(52), 0.0, math.radians(35)))
    bpy.context.active_object.data.energy = 4.0
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.6, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    bpy.ops.object.empty_add(location=(x * 0.5, 0.0, 0.3))
    aim = bpy.context.active_object
    bpy.ops.object.camera_add(location=(x * 0.5, -x * 0.78, x * 0.42))
    cam = bpy.context.active_object
    tr = cam.constraints.new('TRACK_TO')
    tr.target = aim
    tr.track_axis = 'TRACK_NEGATIVE_Z'
    tr.up_axis = 'UP_Y'
    scene.camera = cam
    cam.data.lens = 30
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(PREVIEW_DIR, "props_preview.png")
    bpy.ops.render.render(write_still=True)
    print("[OK] preview:", scene.render.filepath)


if __name__ == "__main__":
    main()
