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


ROCK_ON_TOP = 1.36


def rock_palisade(seed):
    """The palisade with a rock set on it (GAME-DESIGN 6.0: 砸 as a wall's upgrade -- stone is what weighs):
    the same kit, and Rock, a block of the valley's sandstone balanced on the post's points and held by a
    thong, built round its own middle ROCK_ON_TOP up. What bites the section shakes it off onto itself; the
    game drops it to the foot of the post and lifts it back as it is set again (Wall)."""
    rng = random.Random(seed * 7 + 1)
    parts = palisade(seed)
    rock = Builder()
    bands = [(0.62, 0.36, 0.24), (0.52, 0.30, 0.20), (0.66, 0.46, 0.30)]
    lo = Vector((-0.17, -0.14, -0.1))
    hi = Vector((0.17, 0.14, 0.1))
    _dry_stone(rock, lo, hi, rng, jitter(bands[seed % 3], rng, 0.05))
    for sx in (-1.0, 1.0):
        rock.tube([Vector((sx * 0.12, -0.15, 0.05)), Vector((sx * 0.12, -0.04, -0.16)), Vector((sx * 0.1, 0.04, -0.24))],
                  [0.008, 0.008, 0.008], [VINE_ROPE] * 3, 4)
    parts.append(("Rock", rock, UP * ROCK_ON_TOP))
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


def _stave(b, half_span, y_mid, sweep, z, r_mid, r_tip, col_mid, col_tip, segs=8, sides=6):
    """A bow stave across the front, thick in the middle and fine at the tips, its limbs swept
    back towards the nock. Returns the tips. (Fewer `segs` and `sides` for a tower's eight.)"""
    limb, radii, cols = [], [], []
    for k in range(segs + 1):
        t = -1.0 + 2.0 * k / segs
        limb.append(Vector((t * half_span, y_mid - sweep * t * t, z)))
        radii.append(r_mid - (r_mid - r_tip) * abs(t))
        cols.append(mix(col_mid, col_tip, abs(t)))
    b.tube(limb, radii, cols, sides)
    return limb[0], limb[-1]


def _string(tips, nock, radius, col):
    """The string drawn back from the tips to the nock, built round the nock."""
    s = Builder()
    for tip in tips:
        s.tube([tip - nock, Vector((0.0, 0.0, 0.0))], [radius, radius], [col, col], 4)
    return s


TRAP_STRING_TRAVEL = 0.26










# ==============================================================================
# The traps laid in the way (GAME-DESIGN 6.0 rule 3: 刺、砸、困; CellTrap.gd): each on the ground of one
# cell, in nobody's way -- what walks onto it is what it takes.
# ==============================================================================

LITTER = (0.34, 0.25, 0.13)
LITTER_DARK = (0.20, 0.14, 0.08)
GRASS_CORD = (0.52, 0.47, 0.24)
HIDE_CORD = (0.38, 0.24, 0.13)


def _litter(b, rng, n=22, spread=0.44):
    """Dead leaves and needles over the ground of a cell: what half hides a trap."""
    for k in range(n):
        c = Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), 0.006 + 0.001 * (k % 3)))
        a = rng.uniform(0.0, math.tau)
        d = Vector((math.cos(a), math.sin(a), 0.0)) * rng.uniform(0.045, 0.085)
        side = d.cross(UP).normalized() * rng.uniform(0.018, 0.034)
        col = mix(LITTER, LITTER_DARK, rng.uniform(0.0, 0.7))
        b.quad(c - d, c - side, c + d, c + side, col, col, mix(col, LITTER, 0.5), col)


def ground_spikes(seed, bone=False):
    """刺: a patch of stakes driven in points up among the litter, fire-hardened -- or, with bone, each
    with a bone point lashed on (GAME-DESIGN 6.0: bone is what cuts). Nothing moves: it is always set."""
    rng = random.Random(seed)
    b = Builder()
    _litter(b, rng)
    for i in range(4):
        for j in range(4):
            x = -0.36 + i * 0.24 + rng.uniform(-0.05, 0.05)
            y = -0.36 + j * 0.24 + rng.uniform(-0.05, 0.05)
            h = rng.uniform(0.24, 0.34)
            lean = Vector((x * 0.12 + rng.uniform(-0.03, 0.03), y * 0.12 + rng.uniform(-0.03, 0.03), 0.0))
            base = Vector((x, y, -0.02))
            top = base + Vector((0.0, 0.0, h)) + lean
            r = rng.uniform(0.02, 0.028)
            if bone:
                mid = base.lerp(top, 0.62)
                b.tube([base, mid], [r, r * 0.92], [BARK, BARK_LIGHT], 6)
                tip = top + (top - base).normalized() * 0.06
                b.tube([mid - (top - base).normalized() * 0.02, mid, tip], [r * 0.95, r * 0.9, 0.002],
                       [BONE, BONE, mix(BONE, (0.95, 0.93, 0.86), 0.5)], 6)
                _wrap(b, mid, top - base, r * 0.8, turns=1)
            else:
                b.tube([base, base.lerp(top, 0.72), top], [r, r * 0.82, 0.002], [BARK, BARK_LIGHT, CHAR], 6)
    return b


DEADFALL_RISE_DEGREES = 26.0




SNARE_BEND_DEGREES = 58.0




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


def _bed(b, rng, z0, height, rx, ry, offset, col, top_col, n=14, arc=(0.0, math.tau)):
    """One bed of the Chinle's sandstone, laid flat: an uneven slab `rx` by `ry` metres over the arc
    `arc` of a round (a whole bed, or a block split off one), `height` thick, notched where it has
    weathered back, its top edge worn round (the top ring drawn in), its side dark at the foot and its
    own colour above, its top the weathered pale of the rock."""
    shade = mix(col, CHINLE_SHADE, 0.55)
    whole = abs((arc[1] - arc[0]) - math.tau) < 1e-6
    count = n if whole else n // 2 + 1
    wobble = []
    for k in range(count):
        w = rng.uniform(0.8, 1.1)
        if rng.random() < 0.18:
            w *= rng.uniform(0.6, 0.8)          # a notch, weathered back
        wobble.append(w)
    bottom, rim, top = [], [], []
    for k in range(count):
        a = arc[0] + (arc[1] - arc[0]) * k / (count if whole else count - 1)
        r = Vector((math.cos(a) * rx * wobble[k], math.sin(a) * ry * wobble[k], 0.0))
        bottom.append(offset + r + Vector((0.0, 0.0, z0)))
        rim.append(offset + r * 0.98 + Vector((0.0, 0.0, z0 + height * rng.uniform(0.74, 0.86))))
        top.append(offset + r * 0.86 + Vector((0.0, 0.0, z0 + height * rng.uniform(0.94, 1.04))))
    centre = offset + Vector((0.0, 0.0, z0 + height))
    if not whole:
        centre = offset + Vector((math.cos((arc[0] + arc[1]) * 0.5) * rx * 0.25,
                                  math.sin((arc[0] + arc[1]) * 0.5) * ry * 0.25, z0 + height))
    edges = count if whole else count - 1
    for k in range(edges):
        k2 = (k + 1) % count
        b.quad(bottom[k], bottom[k2], rim[k2], rim[k], shade, shade, col, col)
        b.quad(rim[k], rim[k2], top[k2], top[k], col, col, top_col, top_col)
        b.tri(top[k], top[k2], centre, top_col, top_col, mix(top_col, (1.0, 1.0, 1.0), 0.05))
    if not whole:
        # The split face: straight across, fresh-ish where it cracked off.
        face = mix(col, CHINLE_TOP, 0.25)
        base_c = offset + Vector((0.0, 0.0, z0))
        b.quad(bottom[0], base_c, centre, top[0], shade, shade, face, face)
        b.quad(base_c, bottom[-1], top[-1], centre, shade, shade, face, face)


def sandstone_outcrop(seed, quarried=False):
    """Stone to quarry: a ledge of the Chinle's sandstone breaking out of the ground, its beds laid one
    on another -- banded red, ochre, mauve and buff -- each set back from the one below on one side, a
    worn step, and standing sheer on the other; its top bed cracked in two, a couple of blocks fallen at
    its foot. A man's height, and plainly rock to cut, where the first was a spill of red chunks knee-high
    that could not be told for anything at night (the player's report, 2026-09-29: "视角里有很多这个东西，
    也不在动，看不出来是什么"). Quarried, it is cut down to its lowest beds, the cut pale and fresh, rubble
    by it."""
    rng = random.Random(seed)
    b = Builder()
    beds = [(0.34, 0.80, 0.66), (0.30, 0.74, 0.62), (0.34, 0.62, 0.56), (0.30, 0.52, 0.46)]
    if quarried:
        beds = beds[:2]
    z = -0.04
    offset = Vector((0.0, 0.0, 0.0))
    step = Vector((-0.12, 0.05, 0.0))      # each bed set back this way: the stepped side
    for i, (h, rx, ry) in enumerate(beds):
        col = CHINLE_BEDS[(i * 2 + seed) % len(CHINLE_BEDS)]
        last = i == len(beds) - 1
        top_col = CHINLE_FRESH if (quarried and last) else mix(col, CHINLE_TOP, 0.5)
        if last and not quarried:
            # Cracked in two, the halves a hand apart.
            gap = Vector((0.03, 0.03, 0.0))
            _bed(b, rng, z, h, rx, ry, offset + gap, col, top_col, 14, (-0.9, 2.2))
            _bed(b, rng, z, h * 0.9, rx, ry, offset - gap, col, top_col, 14, (2.25, 5.35))
        else:
            _bed(b, rng, z, h, rx, ry, offset, col, top_col)
        z += h
        offset = offset + step + Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0.0))
    for k in range(2):
        a = rng.uniform(-0.8, 0.8)          # fallen off the sheer side
        at = Vector((math.cos(a) * 0.8, math.sin(a) * 0.62, 0.0))
        _sandstone_chunk(b, at, rng.uniform(0.13, 0.17), rng, rng.choice(CHINLE_BEDS), fresh=quarried)
    for _ in range(14 if quarried else 7):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.7, 0.88)
        _chip(b, Vector((math.cos(a) * r, math.sin(a) * r * 0.9, 0.0)), rng.uniform(0.04, 0.08), rng,
              rng.choice(CHINLE_BEDS))
    return b


# ==============================================================================
# The clay he digs (GAME-DESIGN 7.2, station 2; 4.1: 黏土 -- 水边的泥岸, dug with the bone shovel): a bank of the
# river's own clay, slumped and soft where the sandstone is hard and broken -- the blue-grey of clay that has lain
# under water, iron-stained in ochre beds and rusty mottles, its top dried pale and cracked into plates, and a face
# cut into it where it has been dug, wet and smeared, the spade's scoops in it, the cut lumps lying at its foot.
# ==============================================================================

CLAY_GLEY = (0.35, 0.39, 0.41)         # the river's blue-grey clay, as it is cut
CLAY_GLEY_LIGHT = (0.47, 0.51, 0.52)   # a fresh cut catching the light
CLAY_WET = (0.19, 0.22, 0.24)          # wet: at the foot of the cut, smeared where it was dug
CLAY_OCHRE = (0.58, 0.42, 0.19)        # the iron-stained beds through it
CLAY_RUST = (0.45, 0.25, 0.11)         # its mottles
CLAY_CRUST = (0.55, 0.53, 0.48)        # its top, dried pale and cracked into plates
CLAY_CRACK = (0.14, 0.13, 0.12)        # the cracks between them
SILT = (0.26, 0.24, 0.2)               # the river mud about it
PUDDLE = (0.1, 0.13, 0.15)             # water seeping in where it was dug


def _clay_colour(p, top, beds=1.0):
    """The clay at `p`: blue-grey, ochre in its beds (by height; `beds` of their strength -- they show on a cut,
    smeared over where it has weathered), rust-mottled, dried pale towards `top` (0..1)."""
    from mathutils import noise
    c = CLAY_GLEY
    bed = math.sin(p.z * 60.0 + noise.noise(p * 6.0) * 1.6)
    c = mix(c, CLAY_OCHRE, beds * 0.75 * max(0.0, bed - 0.55) / 0.45)
    mottle = noise.noise(p * 14.0 + Vector((3.1, 0.7, 5.3)))
    c = mix(c, CLAY_RUST, 0.6 * max(0.0, mottle - 0.25) / 0.75)
    return mix(c, CLAY_CRUST, top)


def _clay_lump(b, centre, size, rng, cut=None, wet=0.6, ochre=0.0):
    """A lump of dug clay lying where it fell: rounded and slumped flat underneath, its spade-cut side (towards
    `cut`) a flat face showing the fresh clay; wet and dark where it has been handled."""
    # A finer ball than a stone's: clay is soft and rounded, not faceted.
    pts, faces = [], []
    seg, rows = 12, 7
    for r in range(1, rows):
        th = math.pi * r / rows
        for k in range(seg):
            a = math.tau * (k + 0.5 * (r % 2)) / seg
            pts.append(Vector((math.sin(th) * math.cos(a), math.sin(th) * math.sin(a), math.cos(th)))
                       * rng.uniform(0.94, 1.06))
    pts += [Vector((0.0, 0.0, 1.0)), Vector((0.0, 0.0, -1.0))]
    top, bottom = len(pts) - 2, len(pts) - 1
    for k in range(seg):
        k2 = (k + 1) % seg
        faces.append((top, k, k2))
        last = (rows - 2) * seg
        faces.append((bottom, last + k2, last + k))
        for r in range(rows - 2):
            a0, a1 = r * seg, (r + 1) * seg
            faces.append((a0 + k, a1 + k, a1 + k2))
            faces.append((a0 + k, a1 + k2, a0 + k2))
    d = cut.normalized() if cut is not None else None
    out = []
    for q in pts:
        v = Vector((q.x * size * rng.uniform(0.95, 1.12), q.y * size * rng.uniform(0.95, 1.12), q.z * size * 0.6))
        if d is not None and v.dot(d) > size * 0.5:
            v -= d * (v.dot(d) - size * 0.5)             # the spade's cut: flat
        v.z += size * 0.42
        if v.z < 0.0:
            v.z *= 0.1                                    # slumped flat on the ground
        out.append(centre + v)
    for (i, j, k) in faces:
        n = (out[j] - out[i]).cross(out[k] - out[i])
        n = n.normalized() if n.length > 1e-12 else UP
        cs = []
        for m in (i, j, k):
            q = out[m]
            col = mix(_clay_colour(q, 0.0), CLAY_OCHRE, ochre * (0.5 + 0.5 * math.sin(q.z * 90.0 + q.x * 40.0)))
            if d is not None and n.dot(d) > 0.9:
                col = mix(col, CLAY_GLEY_LIGHT, 0.35)    # the cut face, fresh
            else:
                col = mix(col, CLAY_WET, wet * (1.0 - 0.5 * max(0.0, n.z)))
            if q.z - centre.z < size * 0.08:
                col = mix(col, CLAY_WET, 0.5)
            cs.append(col)
        b.tri(out[i], out[j], out[k], cs[0], cs[1], cs[2])


def _clay_plates(b, rng, height, inside, count, gap=0.012, lift=0.004, space=0.06):
    """Its dried top cracked into plates: cells round scattered seeds (each the part of the top nearer its seed
    than any other's), drawn in from their cracks by `gap`, a little domed, following the surface `height(x, y)`
    -- only where `inside(x, y)` is."""
    seeds = []
    tries = 0
    while len(seeds) < count and tries < count * 40:
        tries += 1
        s = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.0))
        if inside(s.x, s.y) and all((s - o).length > space for o in seeds):
            seeds.append(s)
    for s in seeds:
        # Its cell: a square about it, no bigger than a plate is, cut by the half-plane of each nearer seed.
        r = space * 1.1
        poly = [s + Vector((x, y, 0.0)) for (x, y) in ((-r, -r), (r, -r), (r, r), (-r, r))]
        for o in seeds:
            if o is s or (o - s).length > 4.0 * r:
                continue
            m = (s + o) * 0.5
            nrm = (o - s).normalized()
            out = []
            for k in range(len(poly)):
                a, c = poly[k], poly[(k + 1) % len(poly)]
                da, dc = (a - m).dot(nrm), (c - m).dot(nrm)
                if da <= 0.0:
                    out.append(a)
                if (da < 0.0) != (dc < 0.0):
                    out.append(a + (c - a) * (da / (da - dc)))
            poly = out
            if len(poly) < 3:
                break
        if len(poly) < 3 or rng.random() < 0.15:
            continue                     # here and there a plate fallen out, the clay bare
        poly = [p + Vector((rng.uniform(-0.005, 0.005), rng.uniform(-0.005, 0.005), 0.0)) for p in poly]
        mid = sum(poly, Vector()) / len(poly)
        ring = []
        for p in poly:
            q = mid + (p - mid) * max(0.0, 1.0 - gap / max(1e-6, (p - mid).length))
            ring.append(Vector((q.x, q.y, height(q.x, q.y) + lift)))
        if len(ring) < 3 or not all(inside(q.x, q.y) for q in ring):
            continue                     # only whole plates, inside the dried top
        top = Vector((mid.x, mid.y, height(mid.x, mid.y) + lift * 2.2))
        col = jitter(mix(CLAY_CRUST, CLAY_GLEY, rng.uniform(0.35, 0.65)), rng, 0.04)
        edge = mix(col, CLAY_GLEY, 0.3)
        for k in range(len(ring)):
            b.tri(ring[k], ring[(k + 1) % len(ring)], top, edge, edge, col)


def clay_bank(seed, dug=False):
    """The clay to dig, a metre across: a low, slumped bank of the river's clay, knee-high to the Hero at its
    highest, lumpy and rounded, its top dried pale and cracked into plates -- and a bay dug into its front, its
    back a wet face cut in the clay, banded blue-grey and ochre, the spade's scoops in it, the cut lumps lying in
    the trodden mud of its floor, water seeping in. Not a rock: soft, rounded, cracked, wet. The bay opens to -Y.
    Dug out (`dug`), it is a shallow, wet hollow where the bank was: a low ring of the clay round it, cut faces
    inside, water in the bottom, the spoil about it."""
    from mathutils import noise
    rng = random.Random(seed)
    b = Builder()
    if dug:
        return _clay_dug(b, rng)
    c0 = Vector((0.0, 0.05, 0.0))
    top_h = 0.17
    # Slumps on it, each a heap of the clay slid down: (x, y, height, spread).
    lumps = [(-0.22, 0.12, 0.09, 0.16), (0.2, 0.16, 0.07, 0.14), (0.0, 0.3, 0.05, 0.15), (-0.32, -0.12, 0.04, 0.11),
             (0.33, -0.05, 0.035, 0.1)]
    # The bay dug into its front: a round notch, its back the cut face.
    bay_c, bay_r = Vector((0.06, -0.42, 0.0)), 0.23
    floor_z = 0.012

    def outline(a):
        """How far out the bank's slumped edge is, at the angle `a` from its middle."""
        rx, ry = 0.54, 0.44
        r = 1.0 / math.sqrt((math.cos(a) / rx) ** 2 + (math.sin(a) / ry) ** 2)
        return r * (1.0 + 0.12 * noise.noise(Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, 4.2))))

    def height(x, y):
        d = Vector((x, y, 0.0)) - c0
        a = math.atan2(d.y, d.x)
        f = d.length / outline(a)
        if f >= 1.0:
            return 0.0
        h = top_h * (1.0 - f ** 2.6) ** 0.7
        for (lx, ly, lh, ls) in lumps:
            h += lh * math.exp(-((x - lx) ** 2 + (y - ly) ** 2) / (ls * ls)) * (1.0 - f ** 3)
        return max(0.0, h + 0.012 * noise.noise(Vector((x * 5.0, y * 5.0, 1.7))) * min(1.0, h / 0.08))

    def inside_top(x, y):
        return (height(x, y) > 0.13 and (Vector((x, y, 0.0)) - bay_c).length > bay_r + 0.07)

    seg, rings = 56, 10
    grid = []                  # each ray from the middle: its points, and whether it ends on the cut
    for k in range(seg):
        a = -math.pi * 0.5 + math.tau * k / seg
        d = Vector((math.cos(a), math.sin(a), 0.0))
        end = outline(a)
        cut = False
        # Where the ray runs into the bay, it ends there, on the top edge of the cut.
        oc = c0 - bay_c
        bq = d.dot(oc)
        disc = bq * bq - (oc.length_squared - bay_r * bay_r)
        if disc > 0.0:
            t1 = -bq - math.sqrt(disc)
            if 0.0 < t1 < end:
                end, cut = t1, True
        ray = []
        for i in range(rings + 1):
            f = (i / rings) ** 0.8
            p = c0 + d * (end * f)
            z = height(p.x, p.y)
            if cut and i == rings:
                z = max(z, floor_z + 0.03)
            ray.append(Vector((p.x, p.y, z)))
        grid.append((ray, cut, d))

    def top_colour(p, n_up):
        dry = 0.85 * min(1.0, max(0.0, (p.z - 0.06) / 0.14)) * n_up
        col = _clay_colour(p, dry, beds=0.2)
        col = mix(col, SILT, 0.55 * max(0.0, 1.0 - p.z / 0.05))
        return mix(col, CLAY_CRACK, 0.35 if inside_top(p.x, p.y) else 0.0)
    for k in range(seg):
        ray_a = grid[k][0]
        ray_b = grid[(k + 1) % seg][0]
        for i in range(rings):
            quad = [ray_a[i], ray_a[i + 1], ray_b[i + 1], ray_b[i]]
            n = (quad[1] - quad[0]).cross(quad[3] - quad[0])
            n_up = max(0.0, n.normalized().z) if n.length > 1e-12 else 1.0
            cols = [top_colour(q, n_up) for q in quad]
            b.quad(quad[0], quad[1], quad[2], quad[3], cols[0], cols[1], cols[2], cols[3])
    _clay_plates(b, rng, height, inside_top, 50, gap=0.006, lift=0.003, space=0.045)
    # The cut face: down from the top edge of the bay's back to its floor, leaning back into the bank, the
    # spade's scoops in it, its beds showing, wet at its foot. Its columns in the order the rays go round,
    # from where the bay's edge meets the bank's on one side to the other.
    first = next(k for k in range(seg) if grid[k][1] and not grid[(k - 1) % seg][1])
    run = []
    while grid[(first + len(run)) % seg][1] and len(run) < seg:
        run.append(grid[(first + len(run)) % seg])
    before = grid[(first - 1) % seg][0][-1]
    after = grid[(first + len(run)) % seg][0][-1]
    rows = 7
    face = [[before.copy() for _ in range(rows + 1)]]
    for (ray, _, d) in run:
        top = ray[-1]
        column = []
        for m in range(rows + 1):
            t = m / rows
            z = floor_z + (top.z - floor_z) * t
            scoop = 0.016 * (0.5 - 0.5 * math.cos(math.atan2(d.y, d.x) * 9.0 + 1.3 * math.floor(z / 0.09)))
            q = top + d * (0.035 * (1.0 - t) - scoop * math.sin(math.pi * t))
            column.append(Vector((q.x, q.y, z)))
        face.append(column)
    face.append([after.copy() for _ in range(rows + 1)])
    for k in range(len(face) - 1):
        for m in range(rows):
            quad = [face[k][m], face[k + 1][m], face[k + 1][m + 1], face[k][m + 1]]
            cols = []
            for q in quad:
                c = mix(_clay_colour(q, 0.0), CLAY_GLEY_LIGHT, 0.15)
                c = mix(c, CLAY_WET, 0.8 * max(0.0, 1.0 - (q.z - floor_z) / 0.07))
                cols.append(c)
            b.quad(quad[0], quad[1], quad[2], quad[3], cols[0], cols[1], cols[2], cols[3])
    # The bay's floor and the trodden mud out before it, water seeping into a hollow of it, and the cut lumps.
    n = 18
    mud_c = bay_c + Vector((0.0, 0.02, floor_z))
    rim = []
    for k in range(n):
        a = math.tau * k / n
        r = rng.uniform(0.9, 1.05)
        rim.append(mud_c + Vector((math.cos(a) * 0.3 * r, math.sin(a) * 0.22 * r, -floor_z + 0.003)))
    for k in range(n):
        ca = mix(SILT, CLAY_GLEY, 0.35)
        b.tri(rim[k], rim[(k + 1) % n], mud_c, ca, ca, mix(CLAY_GLEY, CLAY_WET, 0.45))
    pud_c = bay_c + Vector((0.07, 0.04, floor_z + 0.003))
    pud = [pud_c + Vector((math.cos(math.tau * k / 9) * 0.075 * rng.uniform(0.75, 1.1),
                           math.sin(math.tau * k / 9) * 0.045 * rng.uniform(0.75, 1.1), 0.0)) for k in range(9)]
    for k in range(9):
        b.tri(pud[k], pud[(k + 1) % 9], pud_c, PUDDLE, PUDDLE, mix(PUDDLE, (0.6, 0.7, 0.75), 0.15))
    for (x, y, size) in ((-0.09, 0.08, 0.06), (0.16, -0.02, 0.05), (-0.02, -0.12, 0.045)):
        _clay_lump(b, bay_c + Vector((x, y, 0.0)), size, rng,
                   cut=Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.0)))
    # A few horsetails at its back, where the bank meets the river's edge.
    for k in range(6):
        a = rng.uniform(0.35, 2.8)
        base = c0 + Vector((math.cos(a), math.sin(a), 0.0)) * outline(a) * rng.uniform(0.85, 0.97)
        base.z = height(base.x, base.y) - 0.01
        tall = rng.uniform(0.25, 0.45)
        lean = Vector((rng.uniform(-0.05, 0.05), rng.uniform(0.0, 0.06), 0.0))
        pts = [base + lean * (z / tall) + Vector((0.0, 0.0, z)) for z in (0.0, tall * 0.35, tall * 0.7, tall)]
        cols = [mix((0.24, 0.42, 0.14), (0.07, 0.08, 0.05), 0.6 if i % 2 else 0.0) for i in range(4)]
        b.tube(pts, [0.007, 0.0065, 0.006, 0.003], cols, 5)
    return b


def _clay_dug(b, rng):
    """Where the bank was, dug out: a shallow wet hollow in a low ring of the clay, its inner side cut steep and
    scooped, water lying in its bottom, the spoil heaped about -- open at the front (-Y), where he dug from."""
    from mathutils import noise
    radii = [0.0, 0.1, 0.18, 0.24, 0.27, 0.29, 0.31, 0.34, 0.38, 0.43, 0.48, 0.52]
    seg = 40

    def height(r, a):
        front = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(a))          # lower towards the front (-Y), where he dug in
        wall = 0.13 * front * (1.0 + 0.25 * noise.noise(Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, 0.9))))
        if r <= 0.27:
            return 0.008
        if r <= 0.34:
            t = (r - 0.27) / 0.07
            return 0.008 + wall * (t * t * (3.0 - 2.0 * t))
        t = (r - 0.34) / 0.18
        return wall * (1.0 - t) ** 1.6
    rings = []
    for r in radii:
        ring = []
        for k in range(seg):
            a = math.tau * k / seg
            w = 1.0 + 0.05 * noise.noise(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, r * 4.0)))
            ring.append(Vector((math.cos(a) * r * w, math.sin(a) * r * w * 0.92, height(r, a))))
        rings.append(ring)
    for i in range(len(radii) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            quad = [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]]
            cols = []
            for q in quad:
                r = math.hypot(q.x, q.y / 0.92)
                if r < 0.275:
                    c = mix(CLAY_WET, SILT, 0.3)                     # the hollow's wet floor
                elif r < 0.345:
                    c = mix(_clay_colour(q, 0.0), CLAY_GLEY_LIGHT, 0.15)  # its cut inner side
                    c = mix(c, CLAY_WET, 0.6 * max(0.0, 1.0 - (q.z - 0.008) / 0.05))
                else:
                    c = _clay_colour(q, 0.6)                           # the rim, dried on top
                    c = mix(c, SILT, 0.6 * max(0.0, 1.0 - q.z / 0.04))
                cols.append(c)
            b.quad(quad[0], quad[1], quad[2], quad[3], cols[0], cols[1], cols[2], cols[3])
    # Water in the bottom of the hollow.
    pud_c = Vector((0.03, 0.02, 0.014))
    pud = [pud_c + Vector((math.cos(math.tau * k / 11) * 0.2 * rng.uniform(0.75, 1.0),
                           math.sin(math.tau * k / 11) * 0.17 * rng.uniform(0.75, 1.0), 0.0)) for k in range(11)]
    for k in range(11):
        b.tri(pud[k], pud[(k + 1) % 11], pud_c, PUDDLE, PUDDLE, mix(PUDDLE, (0.6, 0.7, 0.75), 0.15))
    # The spoil: lumps of the clay about the rim.
    for k in range(6):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.4, 0.5)
        _clay_lump(b, Vector((math.cos(a) * r, math.sin(a) * r * 0.92, 0.0)), rng.uniform(0.045, 0.075), rng,
                   cut=Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.0)))
    return b


def drop_clay(seed):
    """Clay as it is carried off the bank: a few lumps of it heaped as the stone's are, wet blue-grey and streaked
    ochre, the spade's cuts flat on them."""
    rng = random.Random(seed)
    b = Builder()
    for (x, y, z, size, ochre) in ((0.0, 0.0, 0.0, 0.1, 0.0), (0.12, 0.05, 0.0, 0.075, 0.55), (-0.11, 0.06, 0.0, 0.08, 0.0),
                                   (0.03, -0.12, 0.0, 0.075, 0.3), (0.02, 0.02, 0.075, 0.065, 0.0)):
        _clay_lump(b, Vector((x, y, z)), size, rng, cut=Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 0.0)),
                   ochre=ochre)
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



def hammer(seed):
    """His hammer, out while he builds and mends (Hero): a lump of stone lashed crosswise to the end of a stick with
    vine -- what a man makes with what is to hand. Held at the origin, the haft's bottom end in his fist and the haft up
    (+Z), the stone across its head (along X)."""
    rng = random.Random(seed)
    b = Builder()
    # A mallet's size, a heavy lump on a long haft: seen in his hand from the game's camera, and the blow seen.
    shaft = [Vector((0.0, 0.0, z)) for z in (-0.05, 0.0, 0.2, 0.38)]
    b.tube(shaft, [0.016, 0.018, 0.019, 0.019], [BARK, mix(BARK, BARK_LIGHT, 0.5), BARK_LIGHT, BARK_LIGHT], 6)
    head = [Vector((x, 0.0, 0.38)) for x in (-0.11, -0.08, 0.0, 0.08, 0.1)]
    b.tube(head, [0.03, 0.048, 0.056, 0.05, 0.032], [ROCK_DARK, ROCK, ROCK_LIGHT, ROCK, ROCK_DARK], 7,
           radial=lambda i, k: rng.uniform(0.85, 1.15))
    _wrap(b, Vector((0.0, 0.0, 0.38)), Vector((0.0, 0.0, 1.0)), 0.024, turns=2)
    _wrap(b, Vector((0.0, 0.0, 0.38)), Vector((1.0, 0.0, 0.0)), 0.042, turns=1)
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


# ==============================================================================
# The towers and engines (v0.6 round eight): the defences rebuilt as machines a lone engineer could
# raise in the valley -- peeled logs, split planks, vine lashings, bone, the Chinle's red sandstone,
# and meat for bait. No metal, no feathers, and no hide: hide is not used for defences. Each is a kit
# the game dresses and moves by its parts' names, built pointing along +Y (the game's -Z: north) as
# the traps are, standing on z = 0 round the middle of its cells, a hair inside its footprint so
# neighbours do not flicker where they meet. The camera looks from the south, so what tells one
# level of a building from the next (its Store parts) is put on that side wherever it can be.
# ==============================================================================

PEELED = (0.58, 0.45, 0.28)          # a log with its bark taken off, weathered
PEELED_DARK = (0.38, 0.28, 0.17)     # the same where it meets the earth
BRACE = (0.26, 0.18, 0.11)           # thin poles with their bark on: braces, rungs, rails
WICKER = (0.56, 0.47, 0.26)          # split cane woven into baskets
WICKER_DARK = (0.34, 0.27, 0.14)
BONE_PALE = (0.95, 0.93, 0.86)       # bone ground to an edge
GORE = (0.25, 0.08, 0.06)            # earth soaked where the meat drips
X_AXIS = Vector((1.0, 0.0, 0.0))
Y_AXIS = Vector((0.0, 1.0, 0.0))


def _timber(b, p0, p1, r0, r1, rng, cols=None, sides=6, segs=2, caps=True):
    """A straight timber from `p0` to `p1`, tapering `r0` to `r1`: a peeled log, pale and a little
    streaked -- or coloured ring by ring by `cols` -- its cut ends the pale of fresh wood."""
    spine = [p0.lerp(p1, i / segs) for i in range(segs + 1)]
    radii = [r0 + (r1 - r0) * i / segs for i in range(segs + 1)]
    if cols is None:
        cols = [jitter(mix(PEELED, PEELED_DARK, 0.3 if i % 2 else 0.05), rng, 0.04) for i in range(segs + 1)]
    rings = b.tube(spine, radii, cols, sides)
    if caps:
        for ring, centre, flip in ((rings[0], p0, True), (rings[-1], p1, False)):
            for k in range(sides):
                k2 = (k + 1) % sides
                a, c = (ring[k2], ring[k]) if flip else (ring[k], ring[k2])
                b.tri(a, c, centre, FRESH_WOOD, FRESH_WOOD, mix(FRESH_WOOD, BARK_LIGHT, 0.35))
    return rings


def _pole(b, p0, p1, r, rng, sides=5, caps=False):
    """A thin pole with its bark on: a brace, a rung, a rail."""
    return _timber(b, p0, p1, r, r * 0.9, rng, [jitter(BRACE, rng, 0.06), jitter(mix(BRACE, BARK_LIGHT, 0.5), rng, 0.06)],
                   sides, 1, caps)


def _band(b, centre, axis, radius, width=0.05, sides=5):
    """Vine lashed round a timber lying along `axis` where another crosses it: a sleeve of turns a
    little proud of the wood. (_wrap draws every turn -- too many triangles for a tower's dozens of
    joints; from the camera a band is what a lashing is.)"""
    h = axis.normalized() * (width * 0.5)
    b.tube([centre - h, centre, centre + h], [radius + 0.007, radius + 0.012, radius + 0.007],
           [VINE_DARK, mix(VINE, VINE_ROPE, 0.5), VINE_DARK], sides)


def _placed(dst, src, yaw, at):
    """`src`'s triangles copied into `dst`, turned `yaw` about the vertical and moved to `at`."""
    turn = Matrix.Rotation(yaw, 3, 'Z')
    src.verts = [turn @ v + at for v in src.verts]
    dst.absorb(src, 0)


def _twisted(b, p0, p1, radii, light, dark, sides=8, strands=2):
    """A hank of rope twisted tight, from `p0` to `p1`, `radii` along it: the light and dark of its
    strands running round it in a spiral, which is what says TWISTED from any distance."""
    axis = (p1 - p0).normalized()
    side = axis.cross(UP)
    if side.length < 1e-4:
        side = X_AXIS.copy()
    side.normalize()
    nrm = side.cross(axis).normalized()
    n = len(radii) - 1
    rings, cols = [], []
    for i in range(n + 1):
        c = p0.lerp(p1, i / n)
        rings.append([c + (side * math.cos(math.tau * k / sides) + nrm * math.sin(math.tau * k / sides)) * radii[i]
                      for k in range(sides)])
        cols.append([light if ((k + i) * strands // sides) % 2 == 0 else dark for k in range(sides)])
    _rings(b, rings, cols)
    return rings


# ------------------------------------------------------------------------------ arrows

ARROW_LENGTH = 0.85


def _arrow(b, tail, direction, length=ARROW_LENGTH, bone=False, r=0.009, sides=5):
    """An arrow from its nock at `tail` along `direction`: a straight shaft and no fletching -- nothing
    in the valley yet has feathers to give -- the nock's notch at its tail, and its point: the shaft
    itself whittled and fire-hardened to a charred tip, or a point of split bone lashed on."""
    d = direction.normalized()
    head = tail + d * length
    if bone:
        joint = head - d * 0.085
        rings = b.tube([tail, joint], [r, r], [FRESH_WOOD, mix(FRESH_WOOD, BARK_LIGHT, 0.2)], sides)
        # Split bone ground to a flat leaf, widest a third of the way up, set into the split shaft.
        b.tube([joint - d * 0.015, joint + d * 0.03, head], [r * 1.2, r * 1.9, 0.0015],
               [mix(BONE, (0.45, 0.36, 0.20), 0.3), BONE, BONE_PALE], 4,
               radial=lambda i, k: 1.0 if k % 2 == 0 else 0.4)
        _band(b, joint - d * 0.008, d, r, width=0.03, sides=4)
    else:
        cut = head - d * 0.075
        rings = b.tube([tail, cut, head - d * 0.03, head], [r, r, r * 0.55, 0.0015],
                       [FRESH_WOOD, FRESH_WOOD, mix(BARK_LIGHT, CHAR, 0.3), CHAR], sides)
    # The nock: the tail darkened where the string bears on it, a prong either side of its notch.
    nock = mix(BARK_LIGHT, CHAR, 0.3)
    tail_ring = rings[0]
    for k in range(sides):
        b.tri(tail_ring[(k + 1) % sides], tail_ring[k], tail, nock, nock, nock)
    side = d.cross(UP)
    if side.length < 1e-4:
        side = X_AXIS.copy()
    side.normalize()
    for s in (-1.0, 1.0):
        root = tail + side * (s * r * 0.55)
        b.tri(root + d * 0.012, root - d * 0.014, root + side * (s * r * 0.5) + d * 0.01, nock, nock, nock)
    return head


def arrow_prop(seed, bone=False):
    """One arrow as it flies from the bow tower: 0.85 m along +Y, round its own middle -- a wooden one,
    its point fire-hardened, or one with a point of bone."""
    b = Builder()
    _arrow(b, Vector((0.0, -ARROW_LENGTH * 0.5, 0.0)), Y_AXIS, ARROW_LENGTH, bone=bone)
    return b


def _basket(b, base, radius, height, rng, sides=8):
    """A basket woven of split cane: a tub flaring a little to its mouth, light and dark where the
    weave goes over and under, a twist of vine round its rim."""
    rings, cols = [], []
    levels = 4
    for i in range(levels + 1):
        t = i / levels
        r = radius * (0.84 + 0.16 * t)
        rings.append([base + Vector((math.cos(math.tau * k / sides) * r, math.sin(math.tau * k / sides) * r, height * t))
                      for k in range(sides)])
        cols.append([jitter(WICKER if (i + k) % 2 else WICKER_DARK, rng, 0.05) for k in range(sides)])
    _rings(b, rings, cols)
    for k in range(sides):
        b.tri(rings[0][(k + 1) % sides], rings[0][k], base + UP * 0.01, WICKER_DARK, WICKER_DARK, WICKER_DARK)
    rim = [p + UP * 0.004 for p in rings[-1]]
    b.tube(rim + [rim[0]], [0.012] * (sides + 1), [VINE_ROPE if k % 2 else VINE_DARK for k in range(sides + 1)], 4)


def _arrow_sheaf(b, base, count, spread, rng, bone=False):
    """Arrows standing points up in a basket, fanned a little as a sheaf leans apart."""
    for k in range(count):
        a = math.tau * k / count + rng.uniform(-0.3, 0.3)
        rr = spread * (0.3 + 0.7 * ((k * 5) % count) / max(1, count - 1))
        foot = base + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.02))
        lean = Vector((math.cos(a) * 0.09 + rng.uniform(-0.03, 0.03), math.sin(a) * 0.09 + rng.uniform(-0.03, 0.03), 1.0))
        _arrow(b, foot, lean, ARROW_LENGTH * rng.uniform(0.95, 1.0), bone=bone, r=0.008, sides=4)


# ------------------------------------------------------------------------------ the towers' plinth
# THE FOUR TOWERS ARE ONE SET (2026-10-03; the player: "我发现这几个tower，在其他defend游戏里都是可以很好的互相配合，模样
# 也很接近，在我这里都长的不一样也很不好互相配合……基座模型一样大？这样会显得一致一些"; and "投石机样子显得很蠢"): each
# stands on the same plinth filling its four cells -- a crib of peeled logs laid crosswise in courses, filled with earth
# and stones, a deck of split planks on it -- and what tells one from another is the machinery on its deck: the bow
# tower's lookout, the catapult's engine on its turntable, the drop tower's crane, the bait rack's poles. Each acts all
# round itself: what moves on it turns to face what it acts on, and nothing is built facing a way it was set down.

PLINTH_SEED = 7                      # every plinth is drawn from the same numbers, so the four are the same
PLINTH_LOG_R = 0.105                 # its logs' radius
PLINTH_SPAN = 0.8                    # their middles from the plot's middle: the crib 1.81 m across their outsides
PLINTH_END = 0.975                   # how far out their ends stand, past the logs they cross: inside the 2 m
PLINTH_RISE = 0.165                  # a course over the one under it, notched down onto it where they cross
PLINTH_COURSES = 4                   # north and south, east and west on them, north and south, east and west
PLINTH_TOP = 0.75                    # the top of its deck's planks: what every tower stands on
_PLINTH_EARTH = PLINTH_SPAN + 0.035  # the face of the earth and stones packed in behind the logs


def _cobble(b, centre, size, rng, out):
    """A stone rammed into the crib's fill, or packed round a post's foot: a rounded lump of the valley's grey stone,
    dirty with the earth round it -- six corners round its middle, wider than it is tall, and a crown towards `out`, the
    face it shows. Its back is in the earth, so it has none: six triangles a stone, as there are a hundred of them."""
    out = out.normalized()
    side = out.cross(UP) if abs(out.z) < 0.9 else X_AXIS.copy()
    side.normalize()
    up = side.cross(out).normalized()
    col = jitter(mix(mix(ROCK_DARK, ROCK, rng.uniform(0.15, 0.8)), SOIL_LIGHT, rng.uniform(0.1, 0.45)), rng, 0.05)
    lit, shade = mix(col, ROCK_LIGHT, 0.2), mix(col, ROCK_DARK, 0.35)
    ring = []
    for k in range(6):
        a = math.tau * k / 6 + rng.uniform(-0.25, 0.25)
        rr = size * rng.uniform(0.82, 1.12)
        ring.append(centre + (side * (math.cos(a) * 1.15) + up * (math.sin(a) * 0.85)) * rr
                    + out * (rng.uniform(-0.12, 0.12) * size))
    crown = centre + out * (size * rng.uniform(0.45, 0.65)) + up * (size * 0.12)
    for k in range(6):
        k2 = (k + 1) % 6
        edge = lit if (ring[k] + ring[k2] - centre * 2.0).dot(up) > 0.0 else shade
        b.tri(ring[k], ring[k2], crown, edge, edge, col)


def _plinth_bands(course_parity):
    """The heights between the logs of one face of the crib -- the face whose logs are the courses of `course_parity` --
    where the earth and stones show, from the ground to the deck: [(bottom, top), ...]."""
    covered = [(PLINTH_LOG_R + c * PLINTH_RISE - PLINTH_LOG_R, PLINTH_LOG_R + c * PLINTH_RISE + PLINTH_LOG_R)
               for c in range(PLINTH_COURSES) if c % 2 == course_parity]
    deck_under = PLINTH_LOG_R + (PLINTH_COURSES - 1) * PLINTH_RISE + PLINTH_LOG_R
    bands, z = [], 0.0
    for (lo, hi) in covered:
        if lo > z + 0.02:
            bands.append((z, lo))
        z = max(z, hi)
    if deck_under > z + 0.02:
        bands.append((z, deck_under))
    return bands


def _tower_plinth(b, rng):
    """The plot every tower stands on, 2 x 2 m and PLINTH_TOP high: a crib of peeled logs laid crosswise in courses --
    north and south on the ground, east and west on those, and so on, notched down where they cross, their ends standing
    out past each other at the corners, pale where they were cut -- the whole of it filled with earth and stones, which
    show in the gaps between the logs; the same earth spilled round its foot; and a deck of split planks laid east-west
    across its top course. Pass it random.Random(PLINTH_SEED): every tower's plinth is then the same."""
    r, span, end = PLINTH_LOG_R, PLINTH_SPAN, PLINTH_END
    # The logs: weathered paler as they go up, the lowest stained with the earth they lie in; each laid either way
    # round, so the thick ends are not all at one corner.
    for c in range(PLINTH_COURSES):
        z = r + c * PLINTH_RISE
        weather = 0.5 - 0.38 * c / (PLINTH_COURSES - 1)
        for s in (-1.0, 1.0):
            if c % 2 == 0:
                p0, p1 = Vector((-end, s * span, z)), Vector((end, s * span, z))
            else:
                p0, p1 = Vector((s * span, -end, z)), Vector((s * span, end, z))
            if rng.random() < 0.5:
                p0, p1 = p1, p0
            cols = [jitter(mix(PEELED, PEELED_DARK, weather + (0.12 if i % 2 else 0.0)), rng, 0.05) for i in range(4)]
            if c == 0:
                cols = [mix(col, SOIL, 0.25) for col in cols]
            _timber(b, p0, p1, r * rng.uniform(1.02, 1.07), r * rng.uniform(0.9, 0.95), rng, cols, 7, 3)
    # The earth packed in behind them, pushed out a little between the logs, and the stones rammed into it: on each
    # face, in each gap between its logs, a strip of earth tucked in behind the logs above and below it.
    faces = [(Vector((0.0, 1.0, 0.0)), 0), (Vector((0.0, -1.0, 0.0)), 0),
             (Vector((1.0, 0.0, 0.0)), 1), (Vector((-1.0, 0.0, 0.0)), 1)]
    n = 12
    half = span + 0.04
    for (out, parity) in faces:
        along = UP.cross(out)
        for (lo, hi) in _plinth_bands(parity):
            rows = [(max(0.0, lo - 0.03), 0.0), ((lo + hi) * 0.5, 1.0), (hi + 0.03, 0.0)]
            grid = []
            for (z, bulge) in rows:
                row = []
                for i in range(n + 1):
                    t = -half + 2.0 * half * i / n
                    push = bulge * rng.uniform(0.01, 0.045) if 0 < i < n else 0.0
                    row.append(out * (_PLINTH_EARTH + push) + along * t + UP * z)
                grid.append(row)
            cols = [[jitter(mix(SOIL, SOIL_LIGHT, rng.uniform(0.15, 0.7) if j == 1 else 0.1), rng, 0.06)
                     for _ in range(n + 1)] for j in range(3)]
            for j in range(2):
                for i in range(n):
                    b.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i],
                           cols[j][i], cols[j][i + 1], cols[j + 1][i + 1], cols[j + 1][i])
            # The stones: packed close along it, as big as the gap takes, a big one and a smaller, standing out nearly
            # to the logs' faces.
            gap = hi - lo
            t = -half + rng.uniform(0.0, 0.04)
            big = True
            while t < half - 0.04:
                size = gap * (rng.uniform(0.42, 0.52) if big else rng.uniform(0.3, 0.38))
                t += size * 1.05
                at = out * (_PLINTH_EARTH + 0.025) + along * t + UP * (lo + gap * (0.5 + rng.uniform(-0.1, 0.1)))
                if lo < 0.01:
                    at.z = size * 0.8          # the ones in the bottom gap sit on the ground
                _cobble(b, at, size, rng, out)
                t += size * rng.uniform(0.9, 1.05)
                big = not big or rng.random() < 0.35
    # The earth spilled round its foot: a low, lumpy bank along each face, out to the edge of its cells, a stone or
    # two fallen on it.
    for (out, parity) in faces:
        along = UP.cross(out)
        inner = span + (r * 0.9 if parity == 0 else 0.035)
        segs = 12
        rows = []
        mid = (inner + 0.94) * 0.5
        bank = [((inner, inner), (0.045, 0.1), 0.0), ((mid - 0.015, mid + 0.015), (0.02, 0.055), 0.025),
                ((0.945, 0.972), (0.0, 0.004), 0.0)]
        for (reach, lift, wobble) in bank:
            row = []
            for i in range(segs + 1):
                t = -span + 2.0 * span * i / segs + (rng.uniform(-wobble, wobble) if 0 < i < segs else 0.0)
                row.append(out * rng.uniform(*reach) + along * t + UP * rng.uniform(*lift))
            rows.append(row)
        cols = [[jitter(c, rng, 0.06) for _ in range(segs + 1)]
                for c in (SOIL_LIGHT, mix(SOIL, SOIL_LIGHT, 0.5), SOIL)]
        for j in range(2):
            for i in range(segs):
                b.quad(rows[j + 1][i], rows[j + 1][i + 1], rows[j][i + 1], rows[j][i],
                       cols[j + 1][i], cols[j + 1][i + 1], cols[j][i + 1], cols[j][i])
        for k in range(3):
            t = rng.uniform(-span * 0.85, span * 0.85)
            _cobble(b, out * rng.uniform(0.88, 0.91) + along * t + UP * 0.045, rng.uniform(0.03, 0.045), rng, UP)
    # Earth under the deck, so nothing shows through between its planks; and the deck: split planks laid east-west
    # across the top course, their ends a little ragged.
    under = r + (PLINTH_COURSES - 1) * PLINTH_RISE + r
    edge = span + r * 0.85
    b.quad(Vector((-edge, -edge, under - 0.004)), Vector((edge, -edge, under - 0.004)),
           Vector((edge, edge, under - 0.004)), Vector((-edge, edge, under - 0.004)), SOIL, SOIL, SOIL, SOIL)
    boards = 9
    for i in range(boards):
        y0 = -edge + 2.0 * edge * i / boards + 0.005
        y1 = -edge + 2.0 * edge * (i + 1) / boards - 0.005
        _deck_board(b, -edge - rng.uniform(-0.01, 0.025), edge + rng.uniform(-0.01, 0.025), y0, y1, under, PLINTH_TOP,
                    rng, jitter(mix(PLANK, PLANK_LIGHT, rng.uniform(0.0, 0.35)), rng, 0.04))


def _corner_layout(layout, sx, sy):
    """A heap's layout (x, y, course), drawn in the deck's north-east corner, laid out in its corner (sx, sy)."""
    return [(sx * x, sy * y, course) for (x, y, course) in layout]


# ------------------------------------------------------------------------------ the bow tower

# Its legs, standing on the plinth's deck: how far out from the middle each stands at the foot and at the top, and how
# long -- splayed, a slender lookout a metre across at the foot in the middle of the deck.
_TOWER_FOOT, _TOWER_TOP, _TOWER_HEIGHT = 0.46, 0.30, 2.49
BOW_TOWER_DECK = PLINTH_TOP + 1.85   # the top of its deck's planks


def _tower_leg(sx, sy, z):
    """The middle of the bow tower's leg at corner (sx, sy), at height `z` (from the ground): splayed, wider at the
    foot, which stands on the plinth's deck."""
    c = _TOWER_FOOT + (_TOWER_TOP - _TOWER_FOOT) * (z - PLINTH_TOP) / _TOWER_HEIGHT
    return Vector((sx * c, sy * c, z))


def _tower_leg_r(z):
    return 0.066 - 0.014 * (z - PLINTH_TOP) / _TOWER_HEIGHT


def _leg_band(b, sx, sy, z, width=0.07):
    """Vine lashed round a leg of the bow tower at `z`, where something crosses it."""
    at = _tower_leg(sx, sy, z)
    _band(b, at, _tower_leg(sx, sy, z + 1.0) - at, _tower_leg_r(z), width)


def _set_bow():
    """One of the bow tower's bows in its own frame -- the mount at the origin, forward +Y: a short
    self bow, half a metre tip to tip, lashed across the front of its bracket, bent, its string drawn
    back to the catch. Returns (bow, arrow): and the arrow nocked on it."""
    bow = Builder()
    z = 0.024
    tips = _stave(bow, 0.24, 0.1, 0.06, z, 0.017, 0.008, mix(BARK_LIGHT, FRESH_WOOD, 0.45), FRESH_WOOD,
                  segs=6, sides=5)
    _band(bow, Vector((0.0, 0.1, z)), X_AXIS, 0.017, 0.045)
    nock = Vector((0.0, -0.1, 0.037))
    for tip in tips:
        bow.tube([tip, nock], [0.004, 0.004], [VINE_ROPE, VINE_ROPE], 4)
    arrow = Builder()
    _arrow(arrow, nock, Y_AXIS, 0.3, sides=4)
    return bow, arrow


def _bow_bracket(rng):
    """The bracket a tower bow sits on, in the bow's frame: a short stock lashed across the rail at the
    origin, and the catch its string is drawn back to at the inboard end."""
    b = Builder()
    _timber(b, Vector((0.0, -0.16, 0.0)), Vector((0.0, 0.12, 0.0)), 0.019, 0.016, rng,
            [BARK_LIGHT, mix(BARK_LIGHT, FRESH_WOOD, 0.3)], 5, 1)
    b.tube([Vector((0.0, -0.123, 0.0)), Vector((0.0, -0.12, 0.045))], [0.008, 0.006],
           [FRESH_WOOD, mix(FRESH_WOOD, CHAR, 0.2)], 4)
    return b


def _deck_board(b, x0, x1, y0, y1, z0, z1, rng, col):
    """A split board lying flat, `x0`..`x1` by `y0`..`y1`, `z0` to `z1` thick, its top a little out of
    true. No underside: it lies on its bearers."""
    lo = [Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z0)), Vector((x0, y1, z0))]
    hi = [Vector((p.x, p.y, z1 + rng.uniform(-0.006, 0.006))) for p in lo]
    top = mix(col, PLANK_LIGHT, 0.35)
    side = mix(col, BARK, 0.3)
    for k in range(4):
        k2 = (k + 1) % 4
        b.quad(lo[k], lo[k2], hi[k2], hi[k], side, side, col, col)
    b.quad(hi[0], hi[1], hi[2], hi[3], top, top, top, top)


def bow_tower(seed):
    """The towers' plinth (_tower_plinth) and on its deck a lookout of four peeled logs splayed at the foot, each on a
    flat stone, cross-braced and lashed with vine, a deck of split planks at BOW_TOWER_DECK with a low rail round it, a
    ladder of lashed rungs up its south face (the side the camera sees) -- and round the deck eight short self bows set
    on brackets, one to each point of the compass, each spanned with an arrow on it. Nothing aims: what comes along a
    bearing looses the bow that points along it. A slender lookout, its deck 0.8 m across, of the poles one man cuts and
    lashes up in a moment, on the plot the other towers stand on.

    Parts: Base, the plinth and the lookout; Bow0..Bow7 -- Bow0 north, then round by the east (NE, E, SE, S, SW, W, NW)
    -- each built round its mount on the deck's edge and turned so its own forward (Blender +Y, the game's -Z) points
    straight out along its bearing, for the game to recoil it along; Arrow0..Arrow7, the arrow on each, with its bow's
    origin and heading; Quiver, a basket of spare arrows on the deck; Store2 and Store3, a basket of arrows standing on
    the plinth's deck at its south-west corner and one at its south-east, the two levels of capacity. 2 x 2 m, 3.5 m to
    the spare arrows' points."""
    rng = random.Random(seed)
    base = Builder()
    _tower_plinth(base, random.Random(PLINTH_SEED))
    top_z = PLINTH_TOP + _TOWER_HEIGHT
    corners = [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)]
    # The legs, each stood on a flat stone laid on the plinth's deck -- a footing, so it does not work into the planks.
    for (sx, sy) in corners:
        foot = _tower_leg(sx, sy, PLINTH_TOP)
        _flat_stone(base, Vector((foot.x, foot.y, PLINTH_TOP + 0.03)), 0.105, 0.105, 0.035, rng)
        cols = [jitter(c, rng, 0.04) for c in (mix(PEELED_DARK, SOIL, 0.2), PEELED_DARK, mix(PEELED, PEELED_DARK, 0.3),
                                               PEELED, mix(PEELED, PEELED_DARK, 0.15))]
        _timber(base, _tower_leg(sx, sy, PLINTH_TOP + 0.05), _tower_leg(sx, sy, top_z), _tower_leg_r(PLINTH_TOP),
                _tower_leg_r(top_z), rng, cols, 7, 4)
    # Cross-bracing: an X of poles lashed across the inside of each face (there is no room outside the legs), the
    # second bowed in under the first where they cross. The east and west faces' are lashed on a hand above and below
    # the north and south faces', so where two faces' pass inside a corner, they pass clear.
    faces = [((-1.0, 1.0), (1.0, 1.0), Vector((0.0, 1.0, 0.0)), 0.25, 1.62),
             ((1.0, 1.0), (1.0, -1.0), Vector((1.0, 0.0, 0.0)), 0.38, 1.49),
             ((1.0, -1.0), (-1.0, -1.0), Vector((0.0, -1.0, 0.0)), 0.25, 1.62),
             ((-1.0, -1.0), (-1.0, 1.0), Vector((-1.0, 0.0, 0.0)), 0.38, 1.49)]
    brace_r = 0.03
    for (c1, c2, out, lo, hi) in faces:
        lo_z, hi_z = PLINTH_TOP + lo, PLINTH_TOP + hi
        first = None
        for n, (a, b2) in enumerate(((c1, c2), (c2, c1))):
            p0 = _tower_leg(a[0], a[1], lo_z) - out * (_tower_leg_r(lo_z) + brace_r)
            p1 = _tower_leg(b2[0], b2[1], hi_z) - out * (_tower_leg_r(hi_z) + brace_r)
            mid = p0.lerp(p1, 0.5) - out * (0.064 * n)
            base.tube([p0, mid, p1], [brace_r, brace_r * 0.95, brace_r * 0.9],
                      [jitter(BRACE, rng, 0.06), jitter(mix(BRACE, BARK_LIGHT, 0.4), rng, 0.06), jitter(BRACE, rng, 0.06)], 5)
            if first is None:
                first = (p0, p1)
            else:
                _band(base, first[0].lerp(first[1], 0.5), first[1] - first[0], brace_r, 0.06)
        for (cc, zz) in ((c1, lo_z), (c2, hi_z), (c2, lo_z), (c1, hi_z)):
            _leg_band(base, cc[0], cc[1], zz, 0.06)
    # The deck: two bearers along Y through the legs under it, two edge logs along X through them at the north and
    # south, lashed at the legs; split boards laid across between the edge logs; the rail round it.
    deck = BOW_TOWER_DECK
    for sx in (-1.0, 1.0):
        z = deck - 0.095
        c = _tower_leg(1.0, 1.0, z).x
        _timber(base, Vector((sx * c, -0.4, z)), Vector((sx * c, 0.4, z)), 0.048, 0.044, rng, None, 6, 2)
    for sy in (-1.0, 1.0):
        z = deck - 0.04
        c = _tower_leg(1.0, 1.0, z).y
        _timber(base, Vector((-0.42, sy * c, z)), Vector((0.42, sy * c, z)), 0.05, 0.046, rng, None, 6, 2)
    for (sx, sy) in corners:
        _leg_band(base, sx, sy, deck - 0.07, 0.11)
    boards = 4
    for i in range(boards):
        y0 = -0.27 + 0.54 * i / boards + 0.005
        y1 = -0.27 + 0.54 * (i + 1) / boards - 0.005
        _deck_board(base, rng.uniform(-0.43, -0.4), rng.uniform(0.4, 0.43), y0, y1, deck - 0.045, deck, rng,
                    jitter(mix(PLANK, PLANK_LIGHT, rng.uniform(0.1, 0.6)), rng, 0.04))
    rail_ns, rail_ew, rail_r = deck + 0.39, deck + 0.435, 0.03
    for sy in (-1.0, 1.0):
        c = _tower_leg(1.0, 1.0, rail_ns).y
        _pole(base, Vector((-0.4, sy * c, rail_ns)), Vector((0.4, sy * c, rail_ns)), rail_r, rng, 5, True)
    for sx in (-1.0, 1.0):
        c = _tower_leg(1.0, 1.0, rail_ew).x
        _pole(base, Vector((sx * c, -0.4, rail_ew)), Vector((sx * c, 0.4, rail_ew)), rail_r, rng, 5, True)
    for (sx, sy) in corners:
        _leg_band(base, sx, sy, (rail_ns + rail_ew) * 0.5, 0.1)
    # The ladder up the middle of the south face, from the plinth's deck: two peeled stiles stood all but upright
    # outside the legs and leaned on the deck's edge log, rungs lashed across every 30 cm.
    lad_x = (-0.14, 0.14)

    def lad(x, z):
        return Vector((x, -0.472 + 0.0283 * (z - PLINTH_TOP), z))
    for x in lad_x:
        _timber(base, lad(x, PLINTH_TOP + 0.005), lad(x, deck + 0.21), 0.027, 0.024, rng, None, 6, 2)
        _band(base, lad(x, deck - 0.04), lad(x, 3.0) - lad(x, 0.0), 0.027, 0.07)
    z = PLINTH_TOP + 0.3
    while z < deck - 0.11:
        _pole(base, lad(lad_x[0] + 0.02, z), lad(lad_x[1] - 0.02, z), 0.018, rng, 5, False)
        for x in lad_x:
            _band(base, lad(x, z), lad(x, 3.0) - lad(x, 0.0), 0.027, 0.04, 4)
        z += 0.3
    # The bows' brackets: N, E, S and W on the middle of the rail, the four between on the legs' cut tops.
    mounts = []
    stock_r = 0.019
    for k in range(8):
        yaw = -math.pi * 0.25 * k
        fwd = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
        if k % 2 == 0:
            z = rail_ns if k in (0, 4) else rail_ew
            c = _tower_leg(1.0, 1.0, z).x
            at = Vector((round(fwd.x) * c, round(fwd.y) * c, z + rail_r + stock_r))
            _band(base, at - UP * stock_r, X_AXIS if k in (0, 4) else Y_AXIS, rail_r, 0.08)
        else:
            top = _tower_leg(math.copysign(1.0, fwd.x), math.copysign(1.0, fwd.y), top_z)
            at = top + UP * stock_r
            _band(base, top - UP * 0.05, UP, _tower_leg_r(top_z), 0.07)
        mounts.append((k, yaw, at))
        _placed(base, _bow_bracket(rng), yaw, at)
    parts = [("Base", base, Vector((0.0, 0.0, 0.0)))]
    arrows = []
    for (k, yaw, at) in mounts:
        bow, arrow = _set_bow()
        parts.append(("Bow%d" % k, bow, at, yaw))
        arrows.append(("Arrow%d" % k, arrow, at, yaw))
    parts += arrows
    # The quiver: a basket of spare arrows standing in the middle of the deck, clear of the bows' stocks.
    quiver = Builder()
    spot = Vector((0.0, 0.0, deck))
    _basket(quiver, spot, 0.085, 0.3, rng)
    _arrow_sheaf(quiver, spot, 8, 0.05, rng)
    parts.append(("Quiver", quiver, Vector((0.0, 0.0, 0.0))))
    # The stores: a basket of arrows standing on the plinth's deck at its south-west corner, and one at its south-east
    # -- either side of the ladder's foot, where the camera sees them.
    for name, sx in (("Store2", -1.0), ("Store3", 1.0)):
        store = Builder()
        spot = Vector((sx * 0.7, -0.66, PLINTH_TOP))
        _basket(store, spot, 0.085, 0.3, rng)
        _arrow_sheaf(store, spot, 7, 0.045, rng)
        parts.append((name, store, Vector((0.0, 0.0, 0.0))))
    return parts


# ------------------------------------------------------------------------------ the drop tower's rounds


def _round_log(b, centre, rng, length, radius, sides=10, segs=4):
    """A log lying along X round `centre`, `length` long and `radius` round: bark a little ridged, and its cut ends
    pale, ringed with its years, darker at the heart."""
    ridges = [rng.uniform(0.95, 1.04) for _ in range(sides)]
    half = length * 0.5
    spine = [centre + Vector((-half + length * i / segs, 0.0, 0.0)) for i in range(segs + 1)]
    cols = [jitter(mix(BARK, BARK_LIGHT, 0.5 if i % 2 else 0.2), rng, 0.05) for i in range(segs + 1)]
    rings = b.tube(spine, [radius * rng.uniform(0.98, 1.02) for _ in range(segs + 1)], cols, sides,
                   radial=lambda i, k: ridges[k])
    year = mix(FRESH_WOOD, BARK_LIGHT, 0.5)
    heart = mix(FRESH_WOOD, BARK, 0.45)
    for ring, end, flip in ((rings[0], spine[0], True), (rings[-1], spine[-1], False)):
        layers = [ring] + [[end + (p - end) * f for p in ring] for f in (0.86, 0.62, 0.34)]
        shades = [BARK_LIGHT, FRESH_WOOD, year, FRESH_WOOD]
        for i in range(len(layers) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                a, c = (k2, k) if flip else (k, k2)
                b.quad(layers[i][a], layers[i][c], layers[i + 1][c], layers[i + 1][a],
                       shades[i], shades[i], shades[i + 1], shades[i + 1])
        last = layers[-1]
        for k in range(sides):
            k2 = (k + 1) % sides
            a, c = (k2, k) if flip else (k, k2)
            b.tri(last[a], last[c], end, FRESH_WOOD, FRESH_WOOD, heart)
    return rings


def _sandstone_block(b, lo, hi, rng, col):
    """A roughly squared block of the valley's sandstone from `lo` to `hi` -- _dry_stone's shape, but
    shaded as the Chinle's beds are, paler where it weathers and darker into its foot, so it reads red
    and not as the grey of the drystone. Closed underneath: it is lashed on, not laid."""
    def corner(x, y, z):
        return Vector((x + rng.uniform(-0.02, 0.02), y + rng.uniform(-0.02, 0.02), z + rng.uniform(-0.015, 0.015)))
    low = [corner(lo.x, lo.y, lo.z), corner(hi.x, lo.y, lo.z), corner(hi.x, hi.y, lo.z), corner(lo.x, hi.y, lo.z)]
    high = [corner(lo.x, lo.y, hi.z), corner(hi.x, lo.y, hi.z), corner(hi.x, hi.y, hi.z), corner(lo.x, hi.y, hi.z)]
    top_col = mix(col, CHINLE_TOP, 0.3)
    low_col = mix(col, CHINLE_SHADE, 0.45)
    for k in range(4):
        k2 = (k + 1) % 4
        b.quad(low[k], low[k2], high[k2], high[k], low_col, low_col, col, col)
    b.quad(high[0], high[1], high[2], high[3], top_col, top_col, top_col, top_col)
    b.quad(low[3], low[2], low[1], low[0], low_col, low_col, low_col, low_col)


def _bone_spike(b, base, tip, r, rng):
    """A splinter of bone ground to a point: stained where it is bound, bleached at the tip."""
    stained = mix(BONE, (0.45, 0.36, 0.20), 0.35)
    b.tube([base, base.lerp(tip, 0.45), tip], [r, r * 0.75, 0.002], [stained, BONE, BONE_PALE], 4)


def drop_log(seed, spiked=False, stone=False):
    """What the drop tower lets fall (drop_tower's Load, GAME-DESIGN 3.0): a short heavy log DROP_LOG_LENGTH long and
    DROP_LOG_RADIUS round, built along X round its middle, so the game can turn it as it falls -- bark, pale cut ends
    ringed with its years. `spiked`: sharpened splinters of bone lashed round it in two bands, their points out.
    `stone`: a block of the valley's red sandstone lashed on with vine, to make it heavier. (The log tower's 2.4 m
    rolling logs went with it.)"""
    rng = random.Random(seed)
    b = Builder()
    r = DROP_LOG_RADIUS
    _round_log(b, Vector((0.0, 0.0, 0.0)), rng, DROP_LOG_LENGTH, r, sides=10, segs=2)
    if spiked:
        for i, x in enumerate((-0.17, 0.17)):
            _band(b, Vector((x, 0.0, 0.0)), X_AXIS, r, 0.05, 10)
            for k in range(6):
                a = math.tau * (k + 0.5 * (i % 2)) / 6 + rng.uniform(-0.12, 0.12)
                out = Vector((0.0, math.cos(a), math.sin(a)))
                lean = 1.0 if (k + i) % 2 else -1.0       # bound down along the log, points raised
                base = Vector((x - lean * 0.02, 0.0, 0.0)) + out * (r * 0.9)
                tip = Vector((x + lean * 0.05, 0.0, 0.0)) + out * (r + rng.uniform(0.1, 0.13))
                _bone_spike(b, base, tip, rng.uniform(0.015, 0.019), rng)
    if stone:
        block = Builder()
        col = jitter(CHINLE_BEDS[rng.choice((0, 4))], rng, 0.05)
        _sandstone_block(block, Vector((-0.18, -0.13, r * 0.72)), Vector((0.18, 0.13, r + 0.2)), rng, col)
        b.absorb(block, 0)
        # Lashed on: turns of vine round the log and over the block's back, near both its ends.
        for dx in (-0.11, 0.11):
            loop = []
            for k in range(13):
                ang = math.tau * k / 12
                dy, dz = math.cos(ang), math.sin(ang)
                reach = r + 0.012
                if dz > 0.25:
                    reach = min((r + 0.212) / dz, 0.142 / max(abs(dy), 1e-3))
                loop.append(Vector((dx, dy * reach, dz * reach)))
            b.tube(loop, [0.011] * 13, [mix(VINE, VINE_ROPE, 0.5) if k % 3 else VINE_DARK for k in range(13)], 4)
    return b


# ------------------------------------------------------------------------------ the catapult

# The engine stands on a turntable on the plinth's deck, and all that turns with it is built in the turntable's frame:
# its origin on the deck in the middle, its forward (+Y, the game's -Z) the way it throws.
CATAPULT_TABLE_R = 0.65                    # the turntable's radius
CATAPULT_TABLE_TOP = 0.175                 # the top of its planks, over the deck
CATAPULT_AXLE = Vector((0.0, 0.1, 0.46))   # the arm through the skein, in the turntable's frame: the Arm's origin
CATAPULT_ARM = 1.5                         # from the axle to the foot of the cup on its end
CATAPULT_LEAN_DEGREES = 20.0               # how far forward of upright the arm stands at rest, against its padded stop
CATAPULT_COCK_DEGREES = 60.0               # how far it is wound back from there to be loaded (about its axle's +X)
CATAPULT_CUP_DEGREES = 35.0                # how far the cup's mouth is turned from the arm's line to its front
CATAPULT_SHOT_RADIUS = 0.16


def _shot(b, centre, rng, radius=CATAPULT_SHOT_RADIUS):
    """A round shot pecked out of the valley's sandstone: a ball a little out of true, faintly banded
    where the beds run through it, shaded under and paler on top."""
    pts, faces = _icosphere(1.0, rng, 0.05)
    bed = CHINLE_BEDS[rng.choice((0, 4, 0, 4, 2))]       # the red beds, mostly
    tilt = rng.uniform(0.0, math.tau)
    out = [centre + Vector((p.x, p.y, p.z * 0.94)) * radius for p in pts]
    for (i, j, k) in faces:
        cs = []
        for n in (i, j, k):
            q = pts[n]
            band = CHINLE_BEDS[int((q.z * math.cos(tilt) + q.x * math.sin(tilt) + 1.0) * 2.2) % len(CHINLE_BEDS)]
            col = mix(bed, band, 0.3)
            cs.append(mix(mix(col, CHINLE_SHADE, 0.4), mix(col, CHINLE_TOP, 0.12), (q.z + 1.0) * 0.5))
        b.tri(out[i], out[j], out[k], cs[0], cs[1], cs[2])


def shot_stone(seed):
    """One shot as the catapult throws it: a ball of sandstone CATAPULT_SHOT_RADIUS round, about its middle."""
    b = Builder()
    _shot(b, Vector((0.0, 0.0, 0.0)), random.Random(seed))
    return b


# The second map's shot (GAME-DESIGN 5.2, 6.0: 投石塔的火罐, fire moved to station 2): a pot of fired clay the
# catapult throws, about as round as the stone shot, filled with pine resin, its neck stoppered, a resin-soaked rag
# bound round the neck and set alight before it is loosed -- it bursts where it lands and burns.
FIRE_POT_RADIUS = 0.15                 # the belly's: 0.3 m across, the stone shot's size (CATAPULT_SHOT_RADIUS)
POT_FIRED = (0.5, 0.31, 0.19)          # fired earthenware, unglazed
POT_FIRED_DARK = (0.3, 0.18, 0.11)
POT_SOOT = (0.08, 0.065, 0.055)
RAG = (0.3, 0.24, 0.16)
FLAME_ROOT = (1.0, 0.86, 0.45)
FLAME_TIP = (0.95, 0.33, 0.05)


def fire_pot(seed):
    """One fire pot, round its own middle (the belly's), its neck up (+Z): a round-bellied pot of fired clay
    0.3 m across, a cord-pressed band round its shoulder, a short neck stoppered with a wooden plug, a rag soaked
    in resin bound round the neck with cord and alight, the clay sooted under it. Parts: Pot (the pot, the plug,
    the rag and its cord) and Flame (the burning rag's flame: a few tongues of fire, light at the root, for the
    game to light up or put its own fire in place of; in the file, a material of its own that glows)."""
    from mathutils import noise
    rng = random.Random(seed)
    pot = Builder()
    k = FIRE_POT_RADIUS / 0.15
    seg = 16
    profile = [(0.0, -0.138), (0.055, -0.136), (0.1, -0.12), (0.135, -0.075), (0.15, -0.015), (0.146, 0.035),
               (0.128, 0.08), (0.095, 0.115), (0.062, 0.135), (0.047, 0.15), (0.045, 0.17), (0.056, 0.182),
               (0.05, 0.19), (0.04, 0.186)]
    rings, cols = [], []
    for i, (r, z) in enumerate(profile):
        ring, row = [], []
        for j in range(seg):
            a = math.tau * j / seg
            rr = r * k * (1.0 + 0.012 * noise.noise(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, z * 9.0))))
            p = Vector((math.cos(a) * rr, math.sin(a) * rr, z * k))
            ring.append(p)
            c = mix(POT_FIRED_DARK, POT_FIRED, min(1.0, max(0.0, (z + 0.13) / 0.12)))
            c = jitter(c, rng, 0.03)
            # Fire-clouded where it was fired; the cord-pressed band round its shoulder.
            c = mix(c, POT_SOOT, 0.35 * max(0.0, noise.noise(p * 9.0 + Vector((1.3, 2.1, 0.4)))))
            if 0.06 < z < 0.1:
                c = mix(c, POT_FIRED_DARK, 0.55 if j % 2 == 0 else 0.2)
            # Sooted up the neck and the shoulder, under the burning rag.
            c = mix(c, POT_SOOT, 0.85 * min(1.0, max(0.0, (z - 0.09) / 0.06)))
            row.append(c)
        rings.append(ring)
        cols.append(row)
    # The bottom (its first ring all one point) up to the lip and in over its top.
    for i in range(len(rings) - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            pot.quad(rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j], cols[i][j], cols[i][j2],
                     cols[i + 1][j2], cols[i + 1][j])
    # The plug: a short round of wood standing out of the neck.
    plug = [Vector((0.0, 0.0, z * k)) for z in (0.16, 0.2, 0.215)]
    pot.tube(plug, [0.04 * k, 0.04 * k, 0.034 * k], [BARK, BARK_LIGHT, FRESH_WOOD], 9)
    cap = Vector((0.0, 0.0, 0.217 * k))
    for j in range(9):
        a0, a1 = math.tau * j / 9, math.tau * (j + 1) / 9
        pot.tri(Vector((math.cos(a0) * 0.034 * k, math.sin(a0) * 0.034 * k, 0.215 * k)),
                Vector((math.cos(a1) * 0.034 * k, math.sin(a1) * 0.034 * k, 0.215 * k)), cap,
                mix(FRESH_WOOD, CHAR, 0.6), mix(FRESH_WOOD, CHAR, 0.6), CHAR)
    # The rag bound round the neck, its folds, soaked dark with resin and charring where it burns.
    rag = []
    for z in (0.13, 0.15, 0.175, 0.2, 0.215):
        rag.append(Vector((0.0, 0.0, z * k)))
    rag_r = [0.06 * k, 0.07 * k, 0.068 * k, 0.062 * k, 0.045 * k]
    rag_c = [mix(RAG, RESIN, 0.4), mix(RAG, RESIN, 0.6), mix(RESIN, CHAR, 0.4), CHAR, CHAR]
    pot.tube(rag, rag_r, rag_c, 11, radial=lambda i, j: 1.0 + 0.12 * math.sin(j * 2.3 + i * 1.7) + rng.uniform(-0.04, 0.04))
    # A loose end of it hanging down the shoulder.
    end = [Vector((0.06 * k, 0.0, 0.15 * k)), Vector((0.1 * k, 0.012 * k, 0.11 * k)), Vector((0.125 * k, 0.02 * k, 0.07 * k))]
    pot.tube(end, [0.02 * k, 0.018 * k, 0.012 * k], [mix(RAG, RESIN, 0.5), RAG, RAG], 5)
    # The cord bound round it, twice.
    for z in (0.145, 0.168):
        loop = [Vector((math.cos(math.tau * j / 12) * 0.077 * k, math.sin(math.tau * j / 12) * 0.077 * k, z * k))
                for j in range(13)]
        pot.tube(loop, [0.0055 * k] * 13, [VINE_ROPE] * 13, 4)
    # The flame: tongues of fire up from the rag, leaning a little as they go, light at the root, red at the tip.
    flame = Builder()
    tongues = [(0.0, 0.0, 0.2, 0.034), (0.03, 0.4, 0.15, 0.022), (-0.028, 2.4, 0.14, 0.022), (0.02, 4.3, 0.12, 0.018)]
    for (off, a, tall, rad) in tongues:
        base = Vector((math.cos(a) * abs(off), math.sin(a) * abs(off), 0.2 * k))
        lean = Vector((math.cos(a + 1.0) * 0.03, math.sin(a + 1.0) * 0.03, 0.0))
        pts = [base + lean * (f * f) + Vector((0.0, 0.0, tall * f * k)) for f in (0.0, 0.3, 0.6, 0.85, 1.0)]
        radii = [rad * k * s for s in (0.9, 1.0, 0.75, 0.4, 0.06)]
        cols = [mix(FLAME_ROOT, FLAME_TIP, f) for f in (0.0, 0.25, 0.55, 0.85, 1.0)]
        flame.tube(pts, radii, cols, 7, radial=lambda i, j: 1.0 + 0.15 * math.sin(j * 2.0 + i))
    return [("Pot", pot, (0.0, 0.0, 0.0)), ("Flame", flame, (0.0, 0.0, 0.0))]


def _flame_material():
    """A fire pot's flame's own material (generate_props main: a kit's part named "Flame..."): coloured by its
    vertices like the rest, and glowing (glTF emissive) -- lit in the file as it is; the game may light it its own
    way instead."""
    mat = vertex_colour_material("FlameGlow", 0.9, True)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.55, 0.18, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


# A heap of shot on the plinth's deck, in a corner clear of the turntable: (x, y, course) of each, laid out in the
# north-east corner (_corner_layout turns it to the others).
_HEAP_CORNER = [(0.73, 0.46, 0), (0.46, 0.73, 0), (0.73, 0.73, 0)]


def _heap(b, centre, layout, rng):
    r = CATAPULT_SHOT_RADIUS
    for (x, y, course) in layout:
        z = r * 0.94 + course * 0.27
        _shot(b, centre + Vector((x + rng.uniform(-0.01, 0.01), y + rng.uniform(-0.01, 0.01), z)), rng)


def _board(b, outline, z0, z1, rng, col):
    """A split board lying flat, its outline the corners `outline` [(x, y), ...] counter-clockwise from above, `z0` to
    `z1` thick, its top a little out of true: _deck_board's, cut to any shape. No underside: it lies on its bearers."""
    lo = [Vector((x, y, z0)) for (x, y) in outline]
    hi = [Vector((p.x, p.y, z1 + rng.uniform(-0.005, 0.005))) for p in lo]
    top = mix(col, PLANK_LIGHT, 0.35)
    side = mix(col, BARK, 0.3)
    for k in range(len(lo)):
        k2 = (k + 1) % len(lo)
        b.quad(lo[k], lo[k2], hi[k2], hi[k], side, side, col, col)
    for k in range(1, len(hi) - 1):
        b.tri(hi[0], hi[k], hi[k + 1], top, top, top)


def _cup(b, rim_centre, axis, rng):
    """The catapult's cup: a bowl carved from a burl, its mouth along `axis` (in the arm's plane, YZ) -- deep, so a
    shot sits down in it whichever way the arm stands."""
    side = X_AXIS.copy()
    other = axis.cross(side).normalized()
    sides = 10
    profile = [(0.08, -0.2), (0.16, -0.175), (0.2, -0.1), (0.205, 0.0), (0.172, 0.006), (0.158, -0.06), (0.11, -0.135),
               (0.02, -0.15)]
    rings, cols = [], []
    for i, (rad, h) in enumerate(profile):
        rings.append([rim_centre + (side * math.cos(math.tau * k / sides) + other * math.sin(math.tau * k / sides)) * rad
                      + axis * h for k in range(sides)])
        col = BARK_LIGHT if i < 3 else (mix(FRESH_WOOD, BARK_LIGHT, 0.3) if i < 5 else mix(BARK_LIGHT, CHAR, 0.35))
        cols.append([jitter(col, rng, 0.03) for _ in range(sides)])
    _rings(b, rings, cols, rim_centre + axis * -0.15, mix(BARK_LIGHT, CHAR, 0.45))
    bottom = rim_centre + axis * -0.2
    for k in range(sides):
        b.tri(rings[0][(k + 1) % sides], rings[0][k], bottom, BARK, BARK, BARK)


def catapult(seed):
    """A throwing engine on a turntable, on the towers' plinth (_tower_plinth) -- the player: "投石机样子显得很蠢" --
    the turntable a round of split planks on a stout centre post, so the whole engine turns to throw whichever way; on
    it a frame of two peeled sills lashed with vine, between them a skein of plant-fibre rope wound over twisting levers
    on the outside and twisted tight, the throwing arm through the middle of it; in front two uprights with the stop
    across them, padded with a bundle of the same rope, struts raking up to them from the skein's cheeks; a windlass at
    the back to wind the arm down. The arm, 1.7 m of peeled timber with a little spring in it and a bowl carved from a
    burl on its end, stands up against its stop at rest, leaning forward: an onager, small and stone-age, raised high,
    2.9 m to the top of the shot in its bowl.

    Parts: Base, the plinth and the socket the post turns in; Turn, the turntable and all of the engine but its arm,
    round the vertical through the plinth's middle at the deck (0, 0, PLINTH_TOP) -- the game turns it about the
    vertical to throw a way, its forward (+Y, the game's -Z) the way it throws; Arm, a CHILD of Turn, round its axle in
    the skein (CATAPULT_AXLE in the Turn's frame), built at rest against the stop, CATAPULT_LEAN_DEGREES forward of
    upright -- the game winds it back to load by turning it about its own +X by +CATAPULT_COCK_DEGREES (the bowl goes
    back and down, over the windlass, and opens to the sky), and throws by letting it go back to 0, where it meets the
    stop and its bowl opens the way it throws; Stone, a CHILD of Arm, the shot in the bowl, round its own middle; Pile,
    three shot in the south-east corner of the deck beside the turntable; Store2, three more in the south-west corner,
    and Store3, three in each of the north corners, the two levels of capacity."""
    rng = random.Random(seed)
    base = Builder()
    _tower_plinth(base, random.Random(PLINTH_SEED))
    # The socket the turntable's post turns in: stones packed round it on the deck, under the turntable.
    for k in range(7):
        a = math.tau * k / 7 + rng.uniform(-0.15, 0.15)
        at = Vector((math.cos(a) * 0.19, math.sin(a) * 0.19, PLINTH_TOP + 0.02))
        _cobble(base, at, rng.uniform(0.045, 0.055), rng, UP)

    turn = Builder()
    R, top = CATAPULT_TABLE_R, CATAPULT_TABLE_TOP
    # The turntable: the post it turns on, two battens across under its planks, the planks cut round, a hoop of bent
    # sapling round its edge.
    _timber(turn, Vector((0.0, 0.0, -0.02)), Vector((0.0, 0.0, top - 0.04)), 0.1, 0.096, rng, None, 8, 1, False)
    for y in (-0.3, 0.3):
        half = math.sqrt(R * R - y * y) - 0.05
        _pole(turn, Vector((-half, y, top - 0.077)), Vector((half, y, top - 0.077)), 0.033, rng, 5, True)
    planks = 7
    for i in range(planks):
        x0 = -R + 2.0 * R * i / planks + 0.004
        x1 = -R + 2.0 * R * (i + 1) / planks - 0.004
        y0, y1 = math.sqrt(max(0.0, R * R - x0 * x0)), math.sqrt(max(0.0, R * R - x1 * x1))
        _board(turn, [(x0, -y0), (x1, -y1), (x1, y1), (x0, y0)], top - 0.045, top, rng,
               jitter(mix(PLANK, PLANK_LIGHT, rng.uniform(0.15, 0.6)), rng, 0.04))
    hoop = [Vector((math.cos(math.tau * k / 24) * (R + 0.01), math.sin(math.tau * k / 24) * (R + 0.01), top - 0.024))
            for k in range(25)]
    turn.tube(hoop, [0.021] * 25, [jitter(mix(BRACE, BARK_LIGHT, 0.4 * (k % 2)), rng, 0.05) for k in range(25)], 5)

    # The frame: two sills along the turntable, the way it throws.
    ax = CATAPULT_AXLE
    sill_x, sill_r = 0.25, 0.085
    sill_z = top + sill_r
    sill_top = sill_z + sill_r
    for sx in (-1.0, 1.0):
        _timber(turn, Vector((sx * sill_x, -0.54, sill_z)), Vector((sx * sill_x, 0.54, sill_z)), sill_r, sill_r * 0.92,
                rng, None, 7, 3)
    # The skein's cheeks: a pair of posts on each sill clamping it, capped; the skein between them, twisted tight over a
    # lever lashed across each end of it outside the sills, the lever's foot tied down to the sill.
    cheek_y = (ax.y - 0.13, ax.y + 0.13)
    cap_z = ax.z + 0.19
    for sx in (-1.0, 1.0):
        x = sx * sill_x
        for y in cheek_y:
            _timber(turn, Vector((x, y, sill_top - 0.03)), Vector((x, y, cap_z)), 0.06, 0.055, rng, None, 6, 2)
            _band(turn, Vector((x, y, sill_z)), Y_AXIS, sill_r, 0.12)
        _timber(turn, Vector((x, ax.y - 0.22, cap_z + 0.045)), Vector((x, ax.y + 0.22, cap_z + 0.045)), 0.05, 0.048,
                rng, None, 6, 1)
        for y in cheek_y:
            _band(turn, Vector((x, y, cap_z + 0.045)), Y_AXIS, 0.05, 0.1)
        lx = sx * 0.4
        lev0 = Vector((lx, ax.y - 0.3, ax.z - 0.17))
        lev1 = Vector((lx, ax.y + 0.27, ax.z + 0.15))
        _timber(turn, lev0, lev1, 0.034, 0.03, rng, [BARK_LIGHT, mix(BARK_LIGHT, FRESH_WOOD, 0.3)], 6, 1)
        _band(turn, Vector((lx, ax.y, ax.z)), X_AXIS, 0.085, 0.07)
        turn.tube([lev0 + (lev1 - lev0) * 0.04, Vector((x + sx * 0.06, ax.y - 0.33, sill_z + 0.02))], [0.01, 0.01],
                  [VINE_ROPE] * 2, 4)
    sk = 12
    _twisted(turn, Vector((-0.44, ax.y, ax.z)), Vector((0.44, ax.y, ax.z)),
             [0.075 + 0.05 * math.sin(math.pi * i / sk) ** 0.6 for i in range(sk + 1)], GRASS_CORD, VINE_ROPE, 8, 2)
    # The uprights and the stop across them, where the arm comes to rest leaning forward: its pad a bundle of the
    # skein's rope, as far in front of the arm as the two are thick.
    lean = math.radians(CATAPULT_LEAN_DEGREES)
    d = Vector((0.0, math.sin(lean), math.cos(lean)))         # along the arm, up to its cup
    f = Vector((0.0, math.cos(lean), -math.sin(lean)))        # its front: the way it throws
    arm_r0, arm_r1, arm_back, arm_end, arm_bow = 0.1, 0.062, 0.2, CATAPULT_ARM + 0.05, 0.04

    def arm_r(t):
        return arm_r0 + (arm_r1 - arm_r0) * (t + arm_back) / (arm_end + arm_back)

    def arm_at(t):
        # The arm's middle `t` along it from the axle: a timber with a little spring in it, bowed towards the throw.
        return d * t + f * (arm_bow * math.sin(math.pi * (t + arm_back) / (arm_end + arm_back)))
    up_y, pad_r = ax.y + 0.45, 0.1
    # Where on the arm the pad meets it: the stop's middle is the pad's and the arm's thickness in front of the arm.
    t_hit = 0.9
    for _ in range(5):
        gap = pad_r + arm_r(t_hit) + 0.004 + (arm_at(t_hit) - d * t_hit).length
        rise = ((up_y - ax.y) * math.cos(lean) - gap) / math.sin(lean)
        t_hit = (up_y - ax.y) * math.sin(lean) + rise * math.cos(lean)
    stop = Vector((0.0, up_y, ax.z + rise))
    for sx in (-1.0, 1.0):
        x = sx * sill_x
        _timber(turn, Vector((x, up_y, sill_top - 0.03)), Vector((x, up_y, stop.z + 0.12)), 0.078, 0.07, rng,
                None, 7, 3)
        _band(turn, Vector((x, up_y, sill_z)), Y_AXIS, sill_r, 0.15)
        _band(turn, Vector((x, up_y, stop.z)), UP, 0.072, 0.17)
        # A strut raking up to the upright's head from its skein's cap, and a rail across low between the uprights.
        foot = Vector((x, cheek_y[1] + 0.02, cap_z + 0.04))
        head = Vector((x, up_y - 0.07, stop.z - 0.07))
        _pole(turn, foot, head, 0.04, rng, 5, True)
        _band(turn, head, head - foot, 0.04, 0.06)
    rail_z = sill_top + 0.26
    _pole(turn, Vector((-sill_x - 0.08, up_y, rail_z)), Vector((sill_x + 0.08, up_y, rail_z)), 0.04, rng, 5, True)
    for sx in (-1.0, 1.0):
        _band(turn, Vector((sx * sill_x, up_y, rail_z)), UP, 0.075, 0.08)
    _timber(turn, stop - X_AXIS * 0.42, stop + X_AXIS * 0.42, 0.066, 0.062, rng, None, 7, 2)
    _twisted(turn, stop - X_AXIS * 0.16, stop + X_AXIS * 0.16, [0.07, 0.092, pad_r, pad_r, 0.092, 0.07],
             mix(GRASS_CORD, VINE_ROPE, 0.3), VINE_DARK, 8, 3)
    # The windlass at the back that winds the arm down: a roller borne on a block on each sill, the rope on it, a cross
    # of handspikes at each end.
    wy, wz = -0.4, sill_top + 0.1
    for sx in (-1.0, 1.0):
        x = sx * sill_x
        _oriented_box(turn, Vector((x, wy, (sill_top - 0.02 + wz) * 0.5)), (0.05, 0.065, (wz - sill_top + 0.02) * 0.5),
                      0.0, side=mix(PEELED, PEELED_DARK, 0.3), top=PEELED)
        _band(turn, Vector((x, wy, sill_z)), Y_AXIS, sill_r, 0.1)
    _timber(turn, Vector((-0.39, wy, wz)), Vector((0.39, wy, wz)), 0.05, 0.05, rng, None, 6, 2)
    _twisted(turn, Vector((-0.16, wy, wz)), Vector((0.16, wy, wz)), [0.075] * 5, VINE_ROPE, VINE_DARK, 7, 4)
    for sx in (-1.0, 1.0):
        hub = Vector((sx * 0.36, wy, wz))
        for a in (0.5, 0.5 + math.pi * 0.5):
            spoke = Vector((0.0, math.cos(a), math.sin(a))) * 0.13
            turn.tube([hub - spoke, hub + spoke], [0.018, 0.016], [BARK_LIGHT, FRESH_WOOD], 5)

    # The arm, built at rest in its own frame (the axle at the origin): peeled, thickest through the skein, a little
    # spring in it, lashed along its length; the cup on its end, its mouth turned forward of the arm's line, so that
    # wound back it opens to the sky with the shot in it, and standing at the stop it opens the way it throws.
    arm = Builder()
    n = 6
    spine = [arm_at(-arm_back + (arm_end + arm_back) * i / n) for i in range(n + 1)]
    radii = [arm_r(-arm_back + (arm_end + arm_back) * i / n) for i in range(n + 1)]
    rings = arm.tube(spine, radii, [jitter(mix(PEELED, PEELED_DARK, 0.25 if i % 2 else 0.05), rng, 0.04)
                                    for i in range(n + 1)], 8)
    for ring, centre, flip in ((rings[0], spine[0], True), (rings[-1], spine[-1], False)):
        for k in range(8):
            p0, p1 = (ring[(k + 1) % 8], ring[k]) if flip else (ring[k], ring[(k + 1) % 8])
            arm.tri(p0, p1, centre, FRESH_WOOD, FRESH_WOOD, mix(FRESH_WOOD, BARK_LIGHT, 0.35))
    for t in (0.24, t_hit + 0.13, CATAPULT_ARM - 0.1):
        _band(arm, arm_at(t), arm_at(t + 0.01) - arm_at(t), arm_r(t), 0.08)
    cup = math.radians(CATAPULT_CUP_DEGREES)
    mouth = (d * math.cos(cup) + f * math.sin(cup)).normalized()
    rim = arm_at(CATAPULT_ARM) + mouth * 0.2
    _cup(arm, rim, mouth, rng)
    for sx in (-1.0, 1.0):
        tie = rim + X_AXIS * (sx * 0.2) - mouth * 0.03
        arm.tube([arm_at(CATAPULT_ARM - 0.1), tie], [0.009, 0.009], [VINE_ROPE] * 2, 4)
    stone_at = rim + mouth * 0.005
    stone = Builder()
    _shot(stone, Vector((0.0, 0.0, 0.0)), rng)

    deck = Vector((0.0, 0.0, PLINTH_TOP))
    pile = Builder()
    _heap(pile, deck, _corner_layout(_HEAP_CORNER, 1.0, -1.0), rng)
    store2 = Builder()
    _heap(store2, deck, _corner_layout(_HEAP_CORNER, -1.0, -1.0), rng)
    store3 = Builder()
    for sx in (-1.0, 1.0):
        _heap(store3, deck, _corner_layout(_HEAP_CORNER, sx, 1.0), rng)
    return [("Base", base, Vector((0.0, 0.0, 0.0))),
            ("Turn", turn, deck.copy()),
            ("Arm", arm, ax.copy(), 0.0, "Turn"),
            ("Stone", stone, stone_at, 0.0, "Arm"),
            ("Pile", pile, Vector((0.0, 0.0, 0.0))),
            ("Store2", store2, Vector((0.0, 0.0, 0.0))),
            ("Store3", store3, Vector((0.0, 0.0, 0.0)))]


# ------------------------------------------------------------------------------ the drop tower

# A mast on the plinth's deck and a boom pivoted on its head like a well sweep's, the load slung from its long end and
# stones lashed on its short: it turns to face what is at the tower's foot and tips its long end down to let the load
# fall on it. The boom and its yoke are built in the frame of the collar that turns on the mast's head.
DROP_MAST_TOP = PLINTH_TOP + 2.03          # the top of the mast, inside the collar
DROP_TURN_Z = DROP_MAST_TOP - 0.15         # the foot of the collar that turns on its head: the Turn's origin
DROP_PIVOT = Vector((0.0, 0.0, 0.32))      # the boom's pin through the yoke, in the collar's frame: the Boom's origin
DROP_REACH = 1.19                          # from the pin out to the sling at the boom's long end: just past the plinth
DROP_TAIL = 0.5                            # from the pin back to the stones lashed on its short end
DROP_REST_DEGREES = 12.0                   # how far the long end stands up from level at rest, its load raised
# How far it nods from rest to let the load go (about the pin's +X; negative, the long end down): to level, the log
# still hanging clear of the plinth -- its sling turns with the boom, so a deeper nod would swing the log back in over
# the plinth's edge.
DROP_TIP_DEGREES = -14.0
DROP_LOG_LENGTH = 0.62                     # the log it drops: short and heavy, slung crosswise
DROP_LOG_RADIUS = 0.14


def _log_stack(b, centre, rng, top=True):
    """Two short logs of the drop tower's lying side by side along X round `centre` on the deck, a third on them."""
    r = DROP_LOG_RADIUS * 0.93
    for dy in (-0.135, 0.135):
        _round_log(b, centre + Vector((rng.uniform(-0.02, 0.02), dy, r)), rng,
                   length=DROP_LOG_LENGTH * rng.uniform(0.93, 1.0), radius=r, sides=9, segs=2)
    if top:
        _round_log(b, centre + Vector((rng.uniform(-0.03, 0.03), 0.0, r + math.sqrt((2 * r) ** 2 - 0.135 ** 2))), rng,
                   length=DROP_LOG_LENGTH * rng.uniform(0.9, 0.98), radius=r, sides=9, segs=2)


def drop_tower(seed):
    """A crane to drop a log on what comes to the tower's foot, on the towers' plinth (_tower_plinth): a stout peeled
    mast stepped into the deck, stones packed round its foot and four struts raking up to it lashed with vine; on its
    head a collar that turns, carrying the yoke a boom is pinned in, as a well sweep's is -- stones lashed on its short
    end, and from its long end, out past the plinth's edge, a sling of vine holding a short heavy log crosswise. It
    turns to face what is at its foot, all round, nods, and lets the log fall on it. 3.3 m to the top of the boom.

    Parts: Base, the plinth and the mast; Turn, the collar and the yoke, round the vertical through the mast at the
    collar's foot (0, 0, DROP_TURN_Z) -- the game turns it about the vertical to face, its forward (+Y, the game's -Z)
    the way the boom reaches; Boom, a CHILD of Turn, round its pin (DROP_PIVOT in the Turn's frame), built at rest with
    its long end raised DROP_REST_DEGREES -- the game nods it about its own +X by DROP_TIP_DEGREES (negative: the long
    end down) to let the load go, and back; Load, a CHILD of Boom, the log in the sling, along X round its own middle,
    1.16 m out from the mast -- where the dropped log starts from -- shown while it has one; Pile, three short logs in
    the south-east corner of the deck, the stock; Store2, three more in the south-west corner, and Store3, two in each
    of the north corners, the two levels of capacity."""
    rng = random.Random(seed)
    base = Builder()
    _tower_plinth(base, random.Random(PLINTH_SEED))
    # The mast, stepped down through the deck into the crib, stones packed round its foot.
    cols = [jitter(c, rng, 0.04) for c in (mix(PEELED_DARK, SOIL, 0.2), PEELED_DARK, mix(PEELED, PEELED_DARK, 0.3),
                                           PEELED, mix(PEELED, PEELED_DARK, 0.15))]
    mast_r0, mast_r1 = 0.115, 0.09

    def mast_r(z):
        return mast_r0 + (mast_r1 - mast_r0) * (z - PLINTH_TOP) / (DROP_MAST_TOP - PLINTH_TOP)
    _timber(base, Vector((0.0, 0.0, PLINTH_TOP - 0.02)), Vector((0.0, 0.0, DROP_MAST_TOP)), mast_r0, mast_r1, rng, cols,
            8, 4)
    for k in range(8):
        a = math.tau * k / 8 + rng.uniform(-0.12, 0.12)
        at = Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, PLINTH_TOP + 0.03))
        _cobble(base, at, rng.uniform(0.055, 0.07), rng, UP)
    # Four struts raking up to it from the middles of the deck's edges, each footed against a chock, lashed at the head.
    head_z = PLINTH_TOP + 1.05
    for (dx, dy) in ((0.0, 1.0), (1.0, 0.0), (0.0, -1.0), (-1.0, 0.0)):
        out = Vector((dx, dy, 0.0))
        foot = out * 0.62 + UP * (PLINTH_TOP + 0.035)
        head = out * (mast_r(head_z) + 0.04) + UP * head_z
        _pole(base, foot, head, 0.042, rng, 6, True)
        _oriented_box(base, foot + out * 0.075, (0.035, 0.09, 0.03), math.atan2(dy, dx),
                      side=mix(PEELED, PEELED_DARK, 0.4), top=PEELED)
        _band(base, foot.lerp(head, 0.9), head - foot, 0.042, 0.06)
    _band(base, UP * head_z, UP, mast_r(head_z), 0.13)
    _band(base, UP * (head_z - 0.12), UP, mast_r(head_z - 0.12), 0.05)

    # The collar that turns on the mast's head: a block bored to fit it, capped, bound with vine -- and the yoke on it,
    # two cheeks stood up either side of the boom, the pin through them.
    turn = Builder()
    collar_r, collar_h = 0.15, 0.17
    ring_cols = [jitter(c, rng, 0.04) for c in (mix(PEELED, PEELED_DARK, 0.5), mix(PEELED, PEELED_DARK, 0.25), PEELED)]
    rings = turn.tube([Vector((0.0, 0.0, -0.01)), Vector((0.0, 0.0, collar_h * 0.5)), Vector((0.0, 0.0, collar_h))],
                      [collar_r, collar_r * 1.03, collar_r * 0.97], ring_cols, 9)
    for k in range(9):
        k2 = (k + 1) % 9
        turn.tri(rings[-1][k], rings[-1][k2], Vector((0.0, 0.0, collar_h + 0.012)), FRESH_WOOD, FRESH_WOOD,
                 mix(FRESH_WOOD, BARK_LIGHT, 0.3))
        inner_a = Vector((rings[0][k].x, rings[0][k].y, 0.0)) * (mast_r1 / collar_r) + UP * -0.01
        inner_b = Vector((rings[0][k2].x, rings[0][k2].y, 0.0)) * (mast_r1 / collar_r) + UP * -0.01
        turn.quad(rings[0][k2], rings[0][k], inner_a, inner_b, ring_cols[0], ring_cols[0], CHAR, CHAR)
    for z in (0.035, collar_h - 0.03):
        _band(turn, UP * z, UP, collar_r, 0.05, 9)
    cheek_top = DROP_PIVOT.z + 0.09
    for sx in (-1.0, 1.0):
        _oriented_box(turn, Vector((sx * 0.112, 0.0, (collar_h + cheek_top) * 0.5)),
                      (0.03, 0.085, (cheek_top - collar_h) * 0.5 + 0.01), 0.0, side=mix(PLANK, BARK, 0.15),
                      top=PLANK_LIGHT)
        turn.tube([Vector((sx * 0.112, -0.1, collar_h + 0.03)), Vector((sx * 0.112, 0.1, collar_h + 0.03))],
                  [0.034] * 2, [VINE_DARK, mix(VINE, VINE_ROPE, 0.5)], 5)
    pin = DROP_PIVOT
    turn.tube([pin - X_AXIS * 0.17, pin + X_AXIS * 0.17], [0.021, 0.021], [FRESH_WOOD, FRESH_WOOD], 6)
    for sx in (-1.0, 1.0):
        turn.tube([pin + X_AXIS * (sx * 0.15), pin + X_AXIS * (sx * 0.175)], [0.032, 0.032],
                  [mix(FRESH_WOOD, BARK_LIGHT, 0.4)] * 2, 6)

    # The boom, built at rest in its own frame (the pin at the origin): a peeled pole, thickest at its short end.
    rest = math.radians(DROP_REST_DEGREES)
    a_ = Vector((0.0, math.cos(rest), math.sin(rest)))     # along it, out to its long end
    boom = Builder()
    boom_r0, boom_r1 = 0.08, 0.05
    tail, reach = -(DROP_TAIL + 0.07), DROP_REACH + 0.06

    def boom_r(s):
        return boom_r0 + (boom_r1 - boom_r0) * (s - tail) / (reach - tail)
    _timber(boom, a_ * tail, a_ * reach, boom_r0, boom_r1, rng,
            [jitter(c, rng, 0.04) for c in (PEELED, mix(PEELED, PEELED_DARK, 0.25), PEELED,
                                            mix(PEELED, PEELED_DARK, 0.2), PEELED)], 7, 4)
    for s in (-0.12, 0.12, 0.75):
        _band(boom, a_ * s, a_, boom_r(s), 0.06)
    # Its counterweight: stones lashed in a bundle round the short end, hanging under it.
    cw = a_ * -(DROP_TAIL - 0.1) - UP * 0.07
    for (ox, oy, oz, size) in ((-0.07, 0.05, 0.0, 0.1), (0.07, 0.04, 0.02, 0.095), (0.0, -0.06, -0.03, 0.105),
                               (-0.05, -0.02, -0.11, 0.085), (0.06, -0.03, -0.1, 0.09)):
        _boulder(boom, cw + Vector((ox, oy, oz - 0.04)), size, rng)
    for side in (Y_AXIS, X_AXIS):
        loop = [cw + (side * math.cos(math.tau * j / 12) + UP * math.sin(math.tau * j / 12)) * 0.165 for j in range(13)]
        boom.tube(loop, [0.013] * 13, [VINE_ROPE if j % 3 else VINE_DARK for j in range(13)], 4)
    _band(boom, a_ * -(DROP_TAIL - 0.1), a_, boom_r(-(DROP_TAIL - 0.1)), 0.1)
    # The sling at its long end: a bridle down from a band on the boom to a spreader, and a loop of vine from each end
    # of the spreader round under the log, which hangs crosswise in them.
    tip = a_ * DROP_REACH
    _band(boom, tip, a_, boom_r(DROP_REACH), 0.07)
    spreader = tip - UP * 0.17
    sp_half = DROP_LOG_LENGTH * 0.36
    for sx in (-1.0, 1.0):
        boom.tube([tip - UP * boom_r(DROP_REACH), spreader + X_AXIS * (sx * (sp_half - 0.02))], [0.011, 0.011],
                  [VINE_ROPE, VINE_ROPE], 4)
    boom.tube([spreader - X_AXIS * (sp_half + 0.04), spreader + X_AXIS * (sp_half + 0.04)], [0.019, 0.017],
              [BARK_LIGHT, mix(BARK_LIGHT, FRESH_WOOD, 0.3)], 5)
    load_at = spreader - UP * (0.06 + DROP_LOG_RADIUS)
    wrap = DROP_LOG_RADIUS + 0.013
    for sx in (-1.0, 1.0):
        x = sx * (sp_half - 0.02)
        hang = spreader + X_AXIS * x
        arc = [load_at + X_AXIS * x + Vector((0.0, math.cos(math.pi * j / 8), -math.sin(math.pi * j / 8))) * wrap
               for j in range(9)]
        boom.tube([hang] + arc + [hang], [0.011] * 11, [VINE_ROPE if j % 2 else mix(VINE_ROPE, VINE_DARK, 0.4)
                                                         for j in range(11)], 4)
    load = Builder()
    _round_log(load, Vector((0.0, 0.0, 0.0)), rng, length=DROP_LOG_LENGTH, radius=DROP_LOG_RADIUS, sides=10, segs=2)

    deck = Vector((0.0, 0.0, PLINTH_TOP))
    pile = Builder()
    _log_stack(pile, deck + Vector((0.56, -0.6, 0.0)), rng)
    store2 = Builder()
    _log_stack(store2, deck + Vector((-0.56, -0.6, 0.0)), rng)
    store3 = Builder()
    for sx in (-1.0, 1.0):
        _log_stack(store3, deck + Vector((sx * 0.56, 0.6, 0.0)), rng, top=False)
    return [("Base", base, Vector((0.0, 0.0, 0.0))),
            ("Turn", turn, Vector((0.0, 0.0, DROP_TURN_Z))),
            ("Boom", boom, DROP_PIVOT.copy(), 0.0, "Turn"),
            ("Load", load, load_at, 0.0, "Boom"),
            ("Pile", pile, Vector((0.0, 0.0, 0.0))),
            ("Store2", store2, Vector((0.0, 0.0, 0.0))),
            ("Store3", store3, Vector((0.0, 0.0, 0.0)))]


# ------------------------------------------------------------------------------ the bait rack

def _meat_hunk(b, top, rng, length, width, bone=False):
    """A hunk of raw meat hung from `top`: a lump drawn out downwards, narrower at the top where the
    vine bites into it, dark where it is drying, red where it was cut, fat in seams; the bone end of a
    joint showing at the bottom of some."""
    pts, faces = _icosphere(1.0, rng, 0.12)
    centre = top - UP * (length * 0.5)
    spin = Matrix.Rotation(rng.uniform(0.0, math.tau), 3, 'Z')
    out = []
    for q in pts:
        taper = 1.0 - 0.32 * max(0.0, q.z)
        out.append(centre + spin @ Vector((q.x * width * taper, q.y * width * 0.72 * taper, q.z * length * 0.5)))
    for (i, j, k) in faces:
        n = (out[j] - out[i]).cross(out[k] - out[i])
        lit = abs(n.normalized().z) if n.length > 1e-9 else 0.0
        c = mix(MEAT, MEAT_DARK, rng.uniform(0.15, 0.6))
        if rng.random() < 0.07:
            c = mix(c, FAT, 0.45)
        elif lit < 0.3 and rng.random() < 0.5:
            c = mix(c, MEAT_DARK, 0.4)
        b.tri(out[i], out[j], out[k], c, c, c)
    b.tube([top + UP * 0.002, top - UP * (length * 0.12)], [0.012, 0.03], [VINE_ROPE, VINE_DARK], 4)
    if bone:
        foot = top - UP * (length * 0.92)
        b.tube([foot + UP * 0.08, foot - UP * 0.05], [0.022, 0.02], [BONE, BONE], 6)
        knob, faces2 = _icosphere(0.034, rng, 0.1)
        for (i, j, k) in faces2:
            p = foot - UP * 0.07
            b.tri(p + knob[i], p + knob[j], p + knob[k], BONE, BONE, mix(BONE, BONE_PALE, 0.4))


def _forked_post(b, x, height, rng, z0=0.0):
    """A tall peeled post forked at the top, its fork open north-south for a crossbar to lie in, stood at `z0` (the
    plinth's deck) with stones packed round its foot."""
    foot = Vector((x, 0.0, z0))
    for k in range(5):
        a = math.tau * k / 5 + rng.uniform(-0.2, 0.2)
        _cobble(b, foot + Vector((math.cos(a) * 0.11, math.sin(a) * 0.11, 0.03)), rng.uniform(0.05, 0.065), rng, UP)
    fork = height - 0.24
    _timber(b, foot - UP * 0.02, foot + UP * fork, 0.062, 0.054, rng,
            [jitter(c, rng, 0.04) for c in (mix(PEELED_DARK, SOIL, 0.2), PEELED_DARK, mix(PEELED, PEELED_DARK, 0.3),
                                            PEELED)], 6, 3, False)
    for sy in (-1.0, 1.0):
        root = foot + UP * (fork - 0.02)
        tip = root + Vector((rng.uniform(-0.01, 0.01), sy * 0.07, 0.24))
        _timber(b, root, tip, 0.04, 0.026, rng, [mix(PEELED, PEELED_DARK, 0.2), PEELED], 5, 1)


def _bone_hook(b, top, rng):
    """A hook ground from a splinter of bone, hung on a loop of vine: down, then up to its point."""
    b.tube([top, top - UP * 0.07], [0.006, 0.006], [VINE_ROPE, VINE_ROPE], 4)
    turn = Vector((rng.uniform(-0.3, 0.3), 1.0, 0.0)).normalized()
    p0 = top - UP * 0.065
    p1 = p0 - UP * 0.1
    p2 = p1 - UP * 0.035 + turn * 0.04
    p3 = p2 + UP * 0.06 + turn * 0.02
    b.tube([p0, p1, p2, p3], [0.014, 0.012, 0.01, 0.002], [mix(BONE, (0.45, 0.36, 0.2), 0.3), BONE, BONE, BONE_PALE], 5)


def bait_rack(seed):
    """Meat hung to draw them in, on the towers' plinth (_tower_plinth): a drying rack of two forked posts 1.44 m apart
    stood on its deck, stones packed round their feet and a pair of struts raking up to each, a crossbar laid in their
    forks and lashed with vine 1.66 m over the deck -- out of reach of what scavenges -- hunks of raw meat hung from it
    on loops of vine, bone scraps on the planks and the planks darkened with blood beneath.

    Parts: Base; Meat0..Meat3, the hunks, each round the point it hangs from on the crossbar (the game shows as many as
    it holds; the loops they hang on stay); Store2 and Store3, a short crossbar lashed across the west post and one
    across the east, bone hooks hung from each, for the two levels of capacity. 2 x 2 m, 2.6 m to the tips of the
    forks."""
    rng = random.Random(seed)
    base = Builder()
    _tower_plinth(base, random.Random(PLINTH_SEED))
    deck = PLINTH_TOP
    # The planks under it: dark with the blood that drips, darkest under each hunk.
    n = 16
    centre = Vector((0.0, 0.0, deck + 0.006))
    ring = [centre + Vector((math.cos(math.tau * k / n) * 0.62 * rng.uniform(0.75, 1.05),
                             math.sin(math.tau * k / n) * 0.4 * rng.uniform(0.75, 1.05), -0.003)) for k in range(n)]
    for k in range(n):
        b0 = mix(PLANK, GORE, 0.55)
        base.tri(ring[k], ring[(k + 1) % n], centre, b0, b0, mix(GORE, SOIL, 0.25))
    hang_x = (-0.45, -0.15, 0.15, 0.45)
    for x in hang_x:
        spot = Vector((x + rng.uniform(-0.04, 0.04), rng.uniform(-0.05, 0.05), deck + 0.009))
        drip = [spot + Vector((math.cos(math.tau * k / 7) * 0.09 * rng.uniform(0.7, 1.1),
                               math.sin(math.tau * k / 7) * 0.08 * rng.uniform(0.7, 1.1), 0.0)) for k in range(7)]
        for k in range(7):
            base.tri(drip[k], drip[(k + 1) % 7], spot, GORE, GORE, mix(GORE, CHAR, 0.4))
    _bone(base, Vector((-0.44, -0.3, deck + 0.025)), Vector((-0.16, -0.42, deck + 0.03)), rng)
    _bone(base, Vector((0.3, 0.34, deck + 0.025)), Vector((0.52, 0.14, deck + 0.03)), rng)
    rib = [Vector((0.14 + 0.2 * math.sin(a), -0.36 + 0.16 * math.cos(a), deck + 0.012 + 0.03 * math.sin(a)))
           for a in (0.0, 0.5, 1.0, 1.5, 2.0)]
    base.tube(rib, [0.012, 0.014, 0.014, 0.012, 0.006], [BONE, BONE, mix(BONE, BONE_PALE, 0.3), BONE, BONE], 5)
    for k in range(5):
        a = rng.uniform(0.0, math.tau)
        rr = rng.uniform(0.2, 0.6)
        _chip(base, Vector((math.cos(a) * rr, math.sin(a) * rr * 0.6, deck)), rng.uniform(0.018, 0.03), rng,
              mix(BONE, BONE_PALE, 0.2))
    # The rack: two forked posts, the crossbar in their forks, lashed; two struts raking up to each post from the deck,
    # north and south, lashed to it.
    post_x, bar_z = 0.72, deck + 1.66
    for sx in (-1.0, 1.0):
        _forked_post(base, sx * post_x, 1.86, rng, deck)
        for sy in (-1.0, 1.0):
            foot = Vector((sx * post_x, sy * 0.56, deck + 0.03))
            head = Vector((sx * post_x, sy * 0.075, deck + 0.9))
            _pole(base, foot, head, 0.036, rng, 5, True)
            _band(base, head + Vector((0.0, -sy * 0.01, 0.0)), UP, 0.058, 0.08)
    _timber(base, Vector((-0.86, 0.0, bar_z)), Vector((0.86, 0.0, bar_z)), 0.045, 0.042, rng,
            [PEELED, mix(PEELED, PEELED_DARK, 0.3), PEELED], 6, 2)
    for sx in (-1.0, 1.0):
        _wrap(base, Vector((sx * post_x, 0.0, bar_z)), X_AXIS, 0.05, turns=2)
    parts = [("Base", base, Vector((0.0, 0.0, 0.0)))]
    # The loops the meat hangs on, and the meat.
    for n_, x in enumerate(hang_x):
        hang = Vector((x, 0.0, bar_z - 0.05))
        _band(base, Vector((x, 0.0, bar_z)), X_AXIS, 0.045, 0.022, 5)
        base.tube([Vector((x, 0.0, bar_z - 0.04)), hang], [0.008, 0.008], [VINE_ROPE, VINE_ROPE], 4)
        meat = Builder()
        _meat_hunk(meat, Vector((0.0, 0.0, 0.0)), rng, rng.uniform(0.3, 0.38), rng.uniform(0.12, 0.15),
                   bone=(n_ % 2 == 1))
        parts.append(("Meat%d" % n_, meat, hang))
    # The stores: a short crossbar lashed north-south across each post, outside it, bone hooks hung on it.
    for name, sx in (("Store2", -1.0), ("Store3", 1.0)):
        store = Builder()
        x = sx * (post_x + 0.06 + 0.034)
        z = deck + 1.3
        _timber(store, Vector((x, -0.38, z)), Vector((x, 0.38, z)), 0.034, 0.03, rng,
                [BARK_LIGHT, mix(BARK_LIGHT, FRESH_WOOD, 0.3)], 5, 1)
        _band(store, Vector((sx * post_x, 0.0, z)), UP, 0.058, 0.09)
        for y in (-0.27, 0.0, 0.27):
            _band(store, Vector((x, y, z)), Y_AXIS, 0.034, 0.02, 4)
            _bone_hook(store, Vector((x, y, z - 0.03)), rng)
        parts.append((name, store, Vector((0.0, 0.0, 0.0))))
    return parts



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
    # The second map's clay (GAME-DESIGN 7.2, station 2): what a dug lump of it is drawn as.
    "drop_clay": (lambda s: drop_clay(s), [23]),
    "water_landing": (lambda s: water_landing(s), [17]),
    "sandstone_outcrop": (lambda s: sandstone_outcrop(s), [61]),
    "sandstone_quarried": (lambda s: sandstone_outcrop(s, quarried=True), [61]),
    # The second map's clay to dig with the bone shovel: a bank of it on the river's edge, and where it was, dug out.
    "clay_bank": (lambda s: clay_bank(s), [67]),
    "clay_bank_dug": (lambda s: clay_bank(s, dug=True), [67]),
    "campfire": (lambda s: campfire(s), [31]),
    "brazier": (lambda s: brazier(s), [37]),
    "torch": (lambda s: torch(s), [43]),
    # His hammer, out while he builds and mends (Hero).
    "hammer": (lambda s: hammer(s), [47]),
    # The traps laid in the way that do not move: always set (CellTrap).
    "ground_spikes": (lambda s: ground_spikes(s), [13]),
    "bone_spikes": (lambda s: ground_spikes(s, bone=True), [13]),
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
    # What the towers and engines throw (v0.6 round eight), each built round its own middle: the drop tower's three
    # rounds (along X, to be turned as they fall; v0.7 -- the log tower's rolling logs went), the catapult's shot, and
    # the arrows.
    "drop_log": (lambda s: drop_log(s), [29]),
    "drop_log_spiked": (lambda s: drop_log(s, spiked=True), [29]),
    "drop_log_stone": (lambda s: drop_log(s, stone=True), [29]),
    "shot_stone": (lambda s: shot_stone(s), [31]),
    "arrow_wood": (lambda s: arrow_prop(s), [37]),
    "arrow_bone": (lambda s: arrow_prop(s, bone=True), [37]),
}

# Props made of named parts the game shows, hides or moves (Wall.dress, Gate): each part an
# object of its own, exported side by side into one file. A kit's builder returns its parts as
# (part, builder, where[, heading[, parent]]): `where` its origin and `heading` its turn about the
# vertical -- in the frame of the earlier part named `parent` when there is one, which it is then
# exported as a child of, so it moves with it (a catapult's Arm on its Turn, the Stone in the Arm).
KITS = {
    "palisade": (lambda s: palisade(s), [3]),
    "bone_palisade": (lambda s: palisade(s, bone=True), [3]),
    "gate": (lambda s: gate(s), [5]),
    "rock_palisade": (lambda s: rock_palisade(s), [3]),
    # The towers and engines (v0.6 round eight; one set on one plinth since 2026-10-03, _tower_plinth).
    "bow_tower": (lambda s: bow_tower(s), [13]),
    "catapult": (lambda s: catapult(s), [19]),
    "drop_tower": (lambda s: drop_tower(s), [29]),
    "bait_rack": (lambda s: bait_rack(s), [23]),
    # The second map's catapult shot: a burning fire pot (its Pot, and its Flame, which glows).
    "fire_pot": (lambda s: fire_pot(s), [41]),
}

def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    reset()
    mat = vertex_colour_material("PropVertex", 0.85, True)
    flame_mat = _flame_material()
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
            objs, by_part = [], {}
            for spec in fn(seed):
                part, builder, where = spec[:3]
                obj = builder.to_object(part, [flame_mat if part.startswith("Flame") else mat])
                obj.location = where
                if len(spec) > 3:
                    # Turned about the vertical: a part that moves along its own forward (a tower's bows)
                    # carries its heading in its node, so the game finds it in the part's basis.
                    obj.rotation_euler = (0.0, 0.0, spec[3])
                if len(spec) > 4 and spec[4]:
                    # A part that moves with another (an arm on its turntable): its child, `where` in the
                    # parent's own frame -- set without the parent-inverse an operator would add, so the
                    # node's transform in the file is exactly `where` and `heading`, from the parent.
                    obj.parent = by_part[spec[4]]
                by_part[part] = obj
                objs.append(obj)
            export_objects(objs, os.path.join(OUT_DIR, label + ".glb"))
            lo, hi = _extent(objs)
            print("[OK] %-20s %6d triangles  %.2f x %.2f x %.2f m (x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f)  parts %s" % (
                label, sum(len(o.data.polygons) for o in objs), hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
                lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, ", ".join(o.name for o in objs)))
            # The game finds the parts by name, and Blender makes a taken name unique, so the
            # names are freed for the next kit once this one is written.
            for o in objs:
                o.name = "%s.%s" % (label, o.name)
            made.extend(objs)
    if "--preview" in args:
        preview_props(made)


def _extent(objs):
    """The box round every part of a kit as it stands assembled, in its own frame: (lowest, highest)."""
    bpy.context.view_layer.update()
    corners = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return (Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners))),
            Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners))))


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


def _preview_hero(x):
    """The Hero at the head of the preview's lineup, at the 1.2 m the game stands him (his file is
    authored taller): what every prop is judged against. Returns where the lineup goes on from."""
    before = set(bpy.data.objects)
    try:
        bpy.ops.import_scene.gltf(filepath=os.path.join(REPO, "assets", "models", "hero.glb"))
    except Exception as e:          # the lineup is still worth having without him
        print("[--] preview: no hero (%s)" % e)
        return x
    new = [o for o in bpy.data.objects if o not in before]
    for o in [o for o in new if o.type == 'MESH' and not o.name.startswith("Hero")]:
        new.remove(o)               # a helper shape in his file, not him
        bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in new if o.type == 'MESH']
    if not meshes:
        return x
    lo, hi = _extent(meshes)
    k = 1.2 / max(hi.z - lo.z, 1e-3)
    for o in new:
        if o.parent is None:
            o.scale = o.scale * k
            o.location = (x + 0.35, 0.0, 0.0)
    return x + 0.9


def preview_props(objs):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 900
    # A kit stands assembled, as the game puts its parts together -- its parts move along the lineup as
    # one, grouped by the file they went into (main() names them "<file>.<part>"); a round built about
    # its own middle is stood on the ground; and the Hero heads the line at his 1.2 m, to judge each by.
    groups, order = {}, []
    for o in objs:
        key = o.name.split(".")[0]
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(o)
    x = _preview_hero(0.0)
    for key in order:
        lo, hi = _extent(groups[key])
        for o in groups[key]:
            if o.parent is None:        # a child goes with its parent
                o.location.x += x - lo.x
                o.location.z -= min(0.0, lo.z)
        x += (hi.x - lo.x) + 0.5
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
