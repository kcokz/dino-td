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
ROCK_DARK = (0.14, 0.13, 0.12)
ROCK = (0.30, 0.29, 0.26)
ROCK_LIGHT = (0.46, 0.44, 0.40)
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


PROPS = {
    "stake": (lambda s: stake(s), [3]),
    "outcrop": (lambda s: outcrop(s), [5, 21]),
    "outcrop_quarried": (lambda s: outcrop(s, broken=True), [5]),
    "fallen_log": (lambda s: fallen_log(s), [8, 27]),
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
    if "--preview" in args:
        preview_props(made)


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
