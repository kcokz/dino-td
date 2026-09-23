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
from mathutils import Vector  # noqa: E402

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


# ==============================================================================
# The stake
# ==============================================================================

def stake(seed):
    """One sharpened log driven into the ground, authored to its exact envelope:
    Config.BUILDINGS.wall.spike_diameter wide (0.62m) and its height (0.95m) tall.

    What makes it read as a stake someone MADE, from a camera twenty metres up:

      * the point is CUT -- flat facets of pale fresh wood where the axe went, not a
        smooth cone -- and cut a little off-centre, the way a hand cuts;
      * the very tip is CHARRED black: points were fire-hardened, and a dark tip is
        what says "weapon" rather than "post";
      * a band of VINE lashing round it, with a loose end hanging;
      * the bark is ridged, and a lip of it stands proud where the cut begins;
      * it stands in a MOUND of disturbed earth, because it was driven in.
    """
    rng = random.Random(seed)
    b = Builder()

    # The mound: turned earth round the foot, lumpy at the rim.
    rim = []
    n = 14
    for k in range(n):
        a = math.tau * k / n
        r = 0.30 * rng.uniform(0.86, 1.03)
        rim.append(Vector((math.cos(a) * r, math.sin(a) * r, 0.0)))
    crown = [p * 0.55 + UP * rng.uniform(0.05, 0.08) for p in rim]
    centre = UP * 0.08
    for k in range(n):
        k2 = (k + 1) % n
        b.quad(rim[k], rim[k2], crown[k2], crown[k], SOIL, SOIL, SOIL_LIGHT, SOIL_LIGHT)
        b.tri(crown[k], crown[k2], centre, SOIL_LIGHT, SOIL_LIGHT, SOIL)
    # a few stones kicked up in it
    for _ in range(4):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.18, 0.27)
        foliage_clump(b, Vector((math.cos(a) * r, math.sin(a) * r, 0.04)), rng.uniform(0.025, 0.04),
                      0.7, rng, ROCK_DARK, ROCK)

    # The shaft: ridged bark, a slight lean, tapering a little.
    lean = Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), 0.0))
    sides = 10
    ridges = [rng.uniform(0.9, 1.1) for _ in range(sides)]
    shaft_top = 0.66
    spine = [UP * (0.02 + (shaft_top - 0.02) * i / 6) + lean * (i / 6) for i in range(7)]
    radii = [0.135 - 0.012 * i / 6 for i in range(7)]
    cols = [mix(BARK, BARK_LIGHT, 0.45 if i % 2 else 0.1) for i in range(7)]
    rings = b.tube(spine, radii, cols, sides, radial=lambda i, k: ridges[k] * (1.0 + 0.03 * math.sin(i * 1.7 + k)))

    # The bark lip where the cut begins, a hair proud of the shaft.
    lip_lo = spine[-1]
    lip = [lip_lo + (p - lip_lo) * 1.06 for p in rings[-1]]
    for k in range(sides):
        k2 = (k + 1) % sides
        b.quad(rings[-1][k], rings[-1][k2], lip[k2], lip[k], BARK, BARK, BARK_LIGHT, BARK_LIGHT)

    # The point: flat cut facets, off-centre, pale wood darkening to a charred tip.
    tip = spine[-1] + UP * 0.29 + Vector((rng.uniform(-0.025, 0.025), rng.uniform(-0.025, 0.025), 0.0))
    facets = 6
    for f in range(facets):
        # each facet takes a run of the lip's vertices down to the tip
        k0 = int(f * sides / facets)
        k1 = int((f + 1) * sides / facets)
        mid = tip * 0.45 + lip[k0] * 0.55
        for k in range(k0, k1):
            k2 = (k + 1) % sides
            b.tri(lip[k], lip[k2], mid, FRESH_WOOD, FRESH_WOOD, mix(FRESH_WOOD, CHAR, 0.35))
        b.tri(lip[k0], mid, tip, FRESH_WOOD, mix(FRESH_WOOD, CHAR, 0.35), CHAR)
        b.tri(mid, lip[k1 % sides], tip, mix(FRESH_WOOD, CHAR, 0.35), FRESH_WOOD, CHAR)

    # The lashing: two wraps of vine round the upper shaft, and a hanging end.
    for w in range(2):
        z = 0.46 + w * 0.045
        c = UP * z + lean * (z / shaft_top)
        pts = []
        for k in range(13):
            a = math.tau * k / 12 + w * 0.4
            pts.append(c + Vector((math.cos(a), math.sin(a), 0.0)) * (0.138 + 0.004 * w) + UP * (0.01 * math.sin(a * 2)))
        b.tube(pts, [0.013] * 13, [mix(VINE, VINE_DARK, 0.5 if k % 3 == 0 else 0.0) for k in range(13)], 5)
    end = [UP * 0.47 + Vector((0.14, 0.0, 0.0)), UP * 0.40 + Vector((0.17, 0.02, 0.0)),
           UP * 0.33 + Vector((0.165, 0.035, 0.0))]
    b.tube(end, [0.011, 0.009, 0.006], [VINE, VINE, VINE_DARK], 4)
    return b


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


def _egg(b, centre, axis, rng):
    """An egg: a sphere drawn out along `axis`, blunter at the top, speckled."""
    pts, faces = _icosphere(1.0, rng, 0.02)
    turn = axis.to_track_quat('Z', 'Y').to_matrix()
    out = []
    for q in pts:
        fat = 1.0 + 0.12 * q.z
        out.append(centre + turn @ Vector((q.x * 0.085 * fat, q.y * 0.085 * fat, q.z * 0.16)))
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


def sentry(seed):
    """The auto turret: a machine off the wreck -- white plating, the orange hazard band,
    twin barrels and a red eye -- on a stand the Hero put up out of what the valley had:
    four lashed timber legs on a drystone plinth, and a deck of split planks.

    Two pieces, because the head turns and the stand does not. The head is built round
    its own pivot, the middle of the turntable, with its barrels along +Y -- the game's
    -Z, the way a node faces -- so turning it in the game is setting one angle. Returned
    as (stand, head, where the pivot is, where the muzzle is relative to it)."""
    rng = random.Random(seed)
    stand = Builder()

    # A drystone plinth, two courses round a packed-earth core.
    for course, (n, radius, z, size) in enumerate([(10, 0.36, 0.0, 0.13), (8, 0.30, 0.15, 0.11)]):
        for k in range(n):
            a = math.tau * k / n + course * 0.35 + rng.uniform(-0.08, 0.08)
            _boulder(stand, Vector((math.cos(a) * radius, math.sin(a) * radius, z)), size * rng.uniform(0.9, 1.1), rng)
    core = [Vector((math.cos(math.tau * k / 12) * 0.28, math.sin(math.tau * k / 12) * 0.28, 0.27)) for k in range(12)]
    for k in range(12):
        stand.tri(core[k], core[(k + 1) % 12], Vector((0.0, 0.0, 0.30)), SOIL, SOIL, SOIL_LIGHT)

    # Four timber legs, leaning in a little, braced and lashed.
    corners = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
    foot_z, top_z = 0.22, 1.50

    def leg_at(sx, sy, z):
        t = (z - foot_z) / (top_z - foot_z)
        w = 0.28 - 0.08 * t
        return Vector((sx * w, sy * w, z))
    for (sx, sy) in corners:
        spine = [leg_at(sx, sy, foot_z + (top_z - foot_z) * i / 6) for i in range(7)]
        cols = [mix(BARK, BARK_LIGHT, 0.45 if i % 2 else 0.1) for i in range(7)]
        stand.tube(spine, [0.05 - 0.01 * i / 6 for i in range(7)], cols, 7)
        for z in (0.55, 1.25):
            c = leg_at(sx, sy, z)
            stand.tube([c - UP * 0.035, c + UP * 0.035], [0.058, 0.058], [VINE, VINE_DARK], 7)
    for i in range(4):
        (ax, ay), (bx, by) = corners[i], corners[(i + 1) % 4]
        for (z0, z1) in ((0.55, 1.25), (1.25, 0.55)):
            p0, p1 = leg_at(ax, ay, z0), leg_at(bx, by, z1)
            stand.tube([p0, p0.lerp(p1, 0.5), p1], [0.024, 0.022, 0.02], [BARK_LIGHT, BARK, BARK_LIGHT], 5)

    # A deck of split planks across the tops of the legs.
    for i in range(5):
        x0 = -0.29 + i * 0.116
        _slab(stand, Vector((x0 + 0.004, -0.29, top_z)), Vector((x0 + 0.112, 0.29, top_z + 0.045)),
              [(1.0, mix(BARK_LIGHT, FRESH_WOOD, rng.uniform(0.05, 0.3)))], 0.01)

    # And the turntable the head sits on, off the wreck like the head.
    deck = top_z + 0.045
    pivot_z = deck + 0.055
    stand.tube([Vector((0.0, 0.0, deck)), Vector((0.0, 0.0, pivot_z))], [0.17, 0.16], [METAL_DARK, METAL_DARK], 12)
    rim = [Vector((math.cos(math.tau * k / 12) * 0.16, math.sin(math.tau * k / 12) * 0.16, pivot_z)) for k in range(12)]
    for k in range(12):
        stand.tri(rim[k], rim[(k + 1) % 12], Vector((0.0, 0.0, pivot_z)), METAL_DARK, METAL_DARK, METAL_DARK)

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

    return stand, head, Vector((0.0, 0.0, pivot_z)), Vector((0.0, 0.47, 0.12))


# ==============================================================================
# Piles on the ground: what a drop of each resource looks like
# ==============================================================================

MEAT = (0.60, 0.17, 0.13)
MEAT_DARK = (0.36, 0.09, 0.07)
FAT = (0.86, 0.74, 0.62)
CLAY = (0.55, 0.30, 0.17)
CLAY_DARK = (0.36, 0.19, 0.11)
WATER = (0.16, 0.42, 0.62)


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


PROPS = {
    "stake": (lambda s: stake(s), [3]),
    "outcrop": (lambda s: outcrop(s), [5, 21]),
    "outcrop_quarried": (lambda s: outcrop(s, broken=True), [5]),
    "fallen_log": (lambda s: fallen_log(s), [8, 27]),
    "rock_formation": (lambda s: rock_formation(s), [4, 17, 33]),
    "nest": (lambda s: nest(s), [9]),
    "basalt_cliff": (lambda s: basalt_cliff(s), [41, 59, 77]),
    # What a drop of each resource is drawn as, named by the resource id the game uses.
    "drop_wood": (lambda s: drop_wood(s), [3]),
    "drop_stone": (lambda s: drop_stone(s), [5]),
    "drop_bone": (lambda s: drop_bone(s), [7]),
    "drop_food": (lambda s: drop_meat(s), [11]),
    "drop_water": (lambda s: drop_water(s), [13]),
}

# Props with a part that moves: exported as a small hierarchy rather than one mesh.
RIGS = {
    "sentry": (lambda s: sentry(s), [2]),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    reset()
    mat = vertex_colour_material("PropVertex", 0.85, True)
    os.makedirs(OUT_DIR, exist_ok=True)
    made = []
    for name, (fn, seeds) in PROPS.items():
        for v, seed in enumerate(seeds):
            label = "%s_%s" % (name, "abc"[v])
            obj = fn(seed).to_object(label, [mat])
            tris = len(obj.data.polygons)
            export(obj, os.path.join(OUT_DIR, label + ".glb"))
            print("[OK] %-20s %6d triangles  %.2f x %.2f x %.2f m" % (
                label, tris, obj.dimensions.x, obj.dimensions.y, obj.dimensions.z))
            made.append(obj)
    for name, (fn, seeds) in RIGS.items():
        for v, seed in enumerate(seeds):
            label = "%s_%s" % (name, "abc"[v])
            stand_b, head_b, pivot, muzzle = fn(seed)
            # Named for the game: Tower.gd turns the node called Head and fires from
            # the one called Muzzle.
            stand = stand_b.to_object("Stand", [mat])
            head = head_b.to_object("Head", [mat])
            head.parent = stand
            head.location = pivot
            tip = bpy.data.objects.new("Muzzle", None)
            bpy.context.scene.collection.objects.link(tip)
            tip.parent = head
            tip.location = muzzle
            export_objects([stand, head, tip], os.path.join(OUT_DIR, label + ".glb"))
            print("[OK] %-20s %6d triangles  stand %.2f x %.2f x %.2f m, head at %.2f m" % (
                label, len(stand.data.polygons) + len(head.data.polygons),
                stand.dimensions.x, stand.dimensions.y, stand.dimensions.z, pivot.z))
            made.append(stand)
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
