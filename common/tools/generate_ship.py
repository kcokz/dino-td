# tools/generate_ship.py
# The ship he came in, for the opening (scripts/fx/Opening.gd; the player, 2026-10-04: "开场动画还要精致化一点，甚至你可以做
# 一个完整飞船穿越，出现故障，人在船舱中睡眠，然后船舱解体，掉落"): everything of it but the crew module -- which is the
# cabin itself (tools/generate_cabin.py module), docked at its nose and played by the cabin -- so that what breaks off
# it is what lies in the valley afterwards: the antenna's dish, a battery bay, the control unit (the wrecks, GAME-DESIGN
# 9.3).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_ship.py
#   ... -- --preview          also renders it to the scratch directory
#
# In the module's own frame: its length along X, the heat shield at -X (the ship's nose: it went into the past shield
# first) and the module's engine end at +X, where the docking collar takes it; its middle at the origin, the hull's
# axis 1 m up. Everything the ship is runs on behind it along +X: the collar, the spine, the time drive's ring, the
# battery bays, the radiators, the engines. Some 24 m of it after the module's 7.
#
# PARTS, each an object of its own about its own middle (Opening moves them): Collar (stays with the ship; its
# Clamps blow at the separation), Spine, Ring, Ring_glow (the drive's light, drawn lit by itself), Board (the control
# unit, which comes off), Dish (the antenna, which comes off), Bay (the battery bay that comes off), Bays (the one
# that stays), Radiators, Engines, Engines_glow.

import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import Builder, mix, jitter, vertex_colour_material, reset, UP, PREVIEW_DIR  # noqa: E402
from generate_props import export_objects, METAL, METAL_DARK, GUNMETAL, HAZARD  # noqa: E402
from generate_cabin import box, beam, rod, disc, annulus, bounds  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

REPO = r"z:\home\zkl-unix\repo\game\dino"
OUT = os.path.join(REPO, "assets", "models", "cabin", "ship_a.glb")

AXIS_Z = 1.0                      # the hull's axis, as the module's
COLLAR_X = (3.45, 4.3)            # the docking collar, from the module's nozzle back
SPINE_X = (4.3, 21.0)             # the spine's run
RING_X = 11.5                     # the time drive's ring, round the spine
RING_R = 5.2                      # its radius, to the middle of its tube
RING_TUBE = 0.42
BAY_X = (14.2, 16.8)              # the battery bays, either side
RAD_X = (17.0, 20.6)              # the radiators
ENGINE_X = (21.0, 24.6)           # the engine block, its bells beyond
PLATE = mix(METAL, (0.52, 0.50, 0.46), 0.2)
DRIVE = (0.30, 0.86, 1.00)        # the time drive's light: the ship's own colour (the power ring's)
DRIVE_HOT = (0.85, 0.98, 1.00)
THRUST = (0.62, 0.80, 1.00)
CELL = (0.20, 0.42, 0.30)         # a battery cell's casing


def _x(v):
    return Vector((v, 0.0, AXIS_Z))


def collar(b, rng):
    """The docking collar the module sits in: a thick ring, the clamps round it apart (Clamps)."""
    b.tube([_x(COLLAR_X[0]), _x(COLLAR_X[0] + 0.12), _x(COLLAR_X[1] - 0.12), _x(COLLAR_X[1])],
           [1.05, 1.18, 1.18, 0.95], [GUNMETAL, METAL_DARK, METAL_DARK, GUNMETAL], 16)
    annulus(b, _x(COLLAR_X[0]), Vector((-1.0, 0.0, 0.0)), 0.55, 1.05, METAL_DARK, n=16, col_out=GUNMETAL)
    for k in range(16):
        a = math.tau * k / 16
        col = HAZARD if k % 2 == 0 else GUNMETAL
        p0 = _x(COLLAR_X[0] + 0.3) + Vector((0.0, math.cos(a), math.sin(a))) * 1.19
        p1 = _x(COLLAR_X[0] + 0.55) + Vector((0.0, math.cos(a), math.sin(a))) * 1.19
        beam(b, p0, p1, 0.24, 0.03, col, rng)


def clamps(b, rng):
    """Four clamps reaching from the collar onto the module's service ring: blown at the separation."""
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((0.0, math.cos(a), math.sin(a)))
        root = _x(COLLAR_X[0] + 0.15) + d * 1.12
        tip = _x(COLLAR_X[0] - 0.35) + d * 1.25
        beam(b, root, tip, 0.22, 0.16, GUNMETAL, rng, up=d)
        box(b, tuple(tip - Vector((0.08, 0.12, 0.12))), tuple(tip + Vector((0.08, 0.12, 0.12))), HAZARD, rng)


def spine(b, rng):
    """The spine: a pressure tube with a square truss round it, plated in panels a shade apart."""
    xs = [SPINE_X[0] + (SPINE_X[1] - SPINE_X[0]) * i / 12.0 for i in range(13)]
    b.tube([_x(x) for x in xs], [0.62] * len(xs),
           [PLATE if i % 2 == 0 else mix(PLATE, (0.40, 0.40, 0.38), 0.25) for i in range(len(xs))], 12)
    half = 0.95
    corners = [Vector((0.0, half, half)), Vector((0.0, -half, half)), Vector((0.0, -half, -half)), Vector((0.0, half, -half))]
    for c in corners:
        rod(b, _x(SPINE_X[0]) + c, _x(SPINE_X[1]) + c, 0.07, METAL_DARK, sides=6)
    for i in range(len(xs) - 1):
        for k in range(4):
            c0, c1 = corners[k], corners[(k + 1) % 4]
            rod(b, _x(xs[i]) + c0, _x(xs[i + 1]) + c1, 0.035, GUNMETAL, sides=5)
            rod(b, _x(xs[i]) + c0, _x(xs[i]) + c1, 0.035, GUNMETAL, sides=5)


def ring(b, glow, rng):
    """The time drive: a ring round the spine on six spokes, its inner face lit (Ring_glow), hazard marks on its
    housing."""
    n, m = 48, 10
    centre = _x(RING_X)
    pts = []
    for i in range(n + 1):
        a = math.tau * i / n
        pts.append(centre + Vector((0.0, math.cos(a), math.sin(a))) * RING_R)
    # The housing: a tube bent round, plated; the inside face left for the glow.
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        out0 = Vector((0.0, math.cos(a0), math.sin(a0)))
        out1 = Vector((0.0, math.cos(a1), math.sin(a1)))
        for j in range(m):
            t0, t1 = math.tau * j / m, math.tau * (j + 1) / m
            def at(out, t):
                return centre + out * (RING_R + math.cos(t) * RING_TUBE) + Vector((math.sin(t) * RING_TUBE * 1.6, 0.0, 0.0))
            inner = math.cos((t0 + t1) * 0.5) < -0.55
            col = PLATE if (i % 6) else HAZARD
            target = glow if inner else b
            ccol = DRIVE if inner else (mix(col, GUNMETAL, 0.3) if j % 2 else col)
            if inner:
                ccol = DRIVE_HOT if (i % 4 == 0) else DRIVE
            target.quad(at(out0, t0), at(out1, t0), at(out1, t1), at(out0, t1), ccol, ccol, ccol, ccol)
    for k in range(6):
        a = math.tau * k / 6 + math.tau / 12
        d = Vector((0.0, math.cos(a), math.sin(a)))
        beam(b, centre + d * 0.9, centre + d * (RING_R - RING_TUBE * 0.8), 0.32, 0.18, METAL_DARK, rng, up=Vector((1.0, 0.0, 0.0)))
    # The drive's hub round the spine.
    b.tube([_x(RING_X - 0.9), _x(RING_X - 0.6), _x(RING_X + 0.6), _x(RING_X + 0.9)], [0.7, 1.15, 1.15, 0.7],
           [GUNMETAL, METAL_DARK, METAL_DARK, GUNMETAL], 14)


def board(b, rng):
    """The control unit on the spine's back, its screens and cable runs: it comes off in the break-up."""
    lo = Vector((5.4, -0.55, AXIS_Z + 0.95))
    hi = Vector((7.0, 0.55, AXIS_Z + 1.55))
    box(b, tuple(lo), tuple(hi), METAL_DARK, rng)
    for k in range(3):
        x0 = 5.55 + k * 0.5
        box(b, (x0, -0.57, AXIS_Z + 1.05), (x0 + 0.38, -0.55, AXIS_Z + 1.42), (0.10, 0.24, 0.16), rng)
        box(b, (x0 + 0.05, -0.585, AXIS_Z + 1.1), (x0 + 0.33, -0.57, AXIS_Z + 1.36), (0.34, 0.84, 0.96), rng)
    rod(b, Vector((5.5, 0.35, AXIS_Z + 1.55)), Vector((5.5, 0.35, AXIS_Z + 1.9)), 0.03, GUNMETAL)
    box(b, (5.42, 0.30, AXIS_Z + 1.9), (5.58, 0.40, AXIS_Z + 1.96), HAZARD, rng)


def dish(b, rng):
    """The antenna: a mast off the spine and a dish on it, turned forward and up: it comes off in the break-up."""
    foot = Vector((8.6, 0.0, AXIS_Z + 0.95))
    top = Vector((8.6, 0.0, AXIS_Z + 3.0))
    rod(b, foot, top, 0.09, METAL_DARK, sides=6)
    rod(b, foot + Vector((0.4, 0.0, 0.0)), top - Vector((0.0, 0.0, 0.6)), 0.04, GUNMETAL, sides=5)
    face = Vector((-0.6, 0.0, 0.8)).normalized()
    centre = top + face * 0.15
    rows = 6
    rim = 1.35
    prev = None
    for r in range(rows + 1):
        rr = rim * r / rows
        depth = 0.42 * (rr / rim) ** 2
        ring_pts = disc(Builder(), centre + face * depth, face, max(rr, 0.001), PLATE, n=18)
        if prev is not None:
            for i in range(18):
                i2 = (i + 1) % 18
                col = PLATE if r % 2 else mix(PLATE, (1.0, 1.0, 1.0), 0.15)
                b.quad(prev[i], prev[i2], ring_pts[i2], ring_pts[i], col, col, col, col)
                b.quad(prev[i2], prev[i], ring_pts[i], ring_pts[i2], METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)
        prev = ring_pts
    rod(b, centre, centre + face * 0.95, 0.03, GUNMETAL)
    box(b, tuple(centre + face * 0.95 - Vector((0.06, 0.06, 0.06))), tuple(centre + face * 0.95 + Vector((0.06, 0.06, 0.06))), HAZARD, rng)


def bay(b, rng, side):
    """A battery bay off the spine's `side` (+1 or -1): a box of cells under a hatch, on a strut."""
    y0, y1 = (1.15, 2.35) if side > 0 else (-2.35, -1.15)
    box(b, (BAY_X[0], y0, AXIS_Z - 0.55), (BAY_X[1], y1, AXIS_Z + 0.55), PLATE, rng)
    for k in range(5):
        x0 = BAY_X[0] + 0.15 + k * 0.48
        yy = y1 if side > 0 else y0
        box(b, (x0, yy - 0.025, AXIS_Z - 0.4), (x0 + 0.36, yy + 0.025, AXIS_Z + 0.4), CELL, rng)
    beam(b, Vector((BAY_X[0] + 0.3, 0.6 * side, AXIS_Z)), Vector((BAY_X[0] + 0.3, (y0 if side > 0 else y1), AXIS_Z)), 0.2, 0.2, METAL_DARK, rng)
    beam(b, Vector((BAY_X[1] - 0.3, 0.6 * side, AXIS_Z)), Vector((BAY_X[1] - 0.3, (y0 if side > 0 else y1), AXIS_Z)), 0.2, 0.2, METAL_DARK, rng)
    box(b, (BAY_X[0] + 0.2, y0 + 0.1, AXIS_Z + 0.55), (BAY_X[1] - 0.2, y1 - 0.1, AXIS_Z + 0.6), HAZARD, rng)


def radiators(b, rng):
    """Four radiator fins off the spine's back end, ribbed."""
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((0.0, math.cos(a), math.sin(a)))
        for i in range(8):
            x0 = RAD_X[0] + (RAD_X[1] - RAD_X[0]) * i / 8.0
            x1 = RAD_X[0] + (RAD_X[1] - RAD_X[0]) * (i + 1) / 8.0
            col = mix(METAL_DARK, (0.30, 0.26, 0.20), 0.3) if i % 2 else METAL_DARK
            p0 = _x(x0) + d * 0.7
            p1 = _x(x1) + d * 0.7
            p2 = _x(x1) + d * 3.0
            p3 = _x(x0) + d * 3.0
            b.quad(p0, p1, p2, p3, col, col, col, col)
            b.quad(p3, p2, p1, p0, col, col, col, col)


def engines(b, glow, rng):
    """The engine block and three bells beyond it, their throats lit (Engines_glow)."""
    b.tube([_x(ENGINE_X[0]), _x(ENGINE_X[0] + 0.3), _x(ENGINE_X[1] - 0.4), _x(ENGINE_X[1])], [0.8, 1.6, 1.6, 1.3],
           [GUNMETAL, METAL_DARK, METAL_DARK, GUNMETAL], 12)
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        off = Vector((0.0, math.cos(a), math.sin(a))) * 0.75
        root = _x(ENGINE_X[1]) + off
        bell = [root, root + Vector((0.4, 0.0, 0.0)), root + Vector((0.9, 0.0, 0.0)), root + Vector((1.4, 0.0, 0.0))]
        b.tube(bell, [0.32, 0.36, 0.5, 0.64], [GUNMETAL, METAL_DARK, (0.20, 0.16, 0.13), (0.12, 0.10, 0.09)], 14)
        disc(glow, root + Vector((0.45, 0.0, 0.0)), Vector((1.0, 0.0, 0.0)), 0.34, THRUST, n=14, col_centre=(0.95, 0.98, 1.0))


def ship(seed):
    rng = random.Random(seed)
    parts = {name: Builder() for name in ("Collar", "Clamps", "Spine", "Ring", "Ring_glow", "Board", "Dish", "Bay", "Bays",
                                          "Radiators", "Engines", "Engines_glow")}
    collar(parts["Collar"], rng)
    clamps(parts["Clamps"], rng)
    spine(parts["Spine"], rng)
    ring(parts["Ring"], parts["Ring_glow"], rng)
    board(parts["Board"], rng)
    dish(parts["Dish"], rng)
    bay(parts["Bay"], rng, 1)
    bay(parts["Bays"], rng, -1)
    radiators(parts["Radiators"], rng)
    engines(parts["Engines"], parts["Engines_glow"], rng)
    return parts


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    reset()
    mat = vertex_colour_material("ShipVertex", 0.7, True)
    objs = []
    for name, b in ship(7).items():
        if not b.verts:
            continue
        o = b.to_object(name, [mat])
        # About its own middle: the pieces that come off turn about themselves as they tumble.
        lo = Vector((min(v.x for v in b.verts), min(v.y for v in b.verts), min(v.z for v in b.verts)))
        hi = Vector((max(v.x for v in b.verts), max(v.y for v in b.verts), max(v.z for v in b.verts)))
        mid = (lo + hi) * 0.5
        o.data.transform(Matrix.Translation(-mid))
        o.location = mid
        objs.append(o)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    export_objects(objs, OUT)
    lo, hi = bounds(objs)
    tris = sum(len(o.data.polygons) for o in objs)
    print("[OK] ship %d triangles, %.1f x %.1f x %.1f m, parts: %s" % (tris, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
                                                                    ", ".join(o.name for o in objs)))
    if "--preview" in args:
        from generate_cabin import preview
        preview("ship", objs)


if __name__ == "__main__":
    main()
