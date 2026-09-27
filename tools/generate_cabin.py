# tools/generate_cabin.py
# Inside the cabin: the crew module the Hero lives in, and the three benches he works at --
# each with the pieces that appear on it as the run goes on.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_cabin.py
#   ... -- room workbench     makes only those
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
# The room also carries empties named "spot_<station id>": where each bench stands.

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
DAYLIGHT = (0.80, 0.90, 1.00)
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
# The room: the crew module's cabin, cut away at the front
# ==============================================================================

# The hull's cross-section: a superellipse across (y, z) -- the same squared-off round the
# outside of the module has (generate_props._module_ring) -- lying along X. The deck is laid
# across it at z = 0, and the front third is cut away so the camera looks in.
RY, RZ, ZC, N = 1.55, 1.35, 1.25, 4.5
X0, X1 = -2.8, 2.8
T_CUT = math.radians(128.0)


def hull_at(t):
    c, s = math.cos(t), math.sin(t)
    return (RY * math.copysign(abs(c) ** (2.0 / N), c), ZC + RZ * math.copysign(abs(s) ** (2.0 / N), s))


def t_at_height(z):
    """The angle on the BACK wall (y > 0) where the hull is `z` high."""
    d = (z - ZC) / RZ
    return math.copysign(math.asin(min(1.0, abs(d) ** (N / 2.0))), d)


def hull_inward(t):
    """The unit normal into the room at angle `t`, in (y, z)."""
    e = 1e-3
    y0, z0 = hull_at(t - e)
    y1, z1 = hull_at(t + e)
    tangent = Vector((0.0, y1 - y0, z1 - z0)).normalized()
    n = Vector((1.0, 0.0, 0.0)).cross(tangent).normalized()
    y, z = hull_at(t)
    return n if n.dot(Vector((0.0, -y, ZC - z))) > 0 else -n


def room(seed):
    rng = random.Random(seed)
    shell = Builder()
    glow_day = Builder()
    glow_lamp = Builder()

    # The angles the wall is cut at: the bands' edges exactly, so each band is one colour,
    # then even steps over the ceiling to the cut.
    t_floor = t_at_height(0.0)
    heights = [0.0, 0.42, 0.84, 0.90, 1.00, 1.35, 1.72, 2.05, 2.30]
    ts = [t_at_height(z) for z in heights]
    ts += [math.radians(a) for a in (55.0, 68.0, 80.0, 90.0, 100.0, 112.0)]
    ts.append(T_CUT)
    ts = sorted(set(ts))
    xs = [X0 + (X1 - X0) * i / 16 for i in range(17)]
    for i in range(len(xs) - 1):
        panel = PANEL if (i // 2) % 2 == 0 else PANEL_ALT
        for j in range(len(ts) - 1):
            ya, za = hull_at(ts[j])
            yb, zb = hull_at(ts[j + 1])
            zm = (za + zb) * 0.5
            if zm < 0.84:
                col = jitter(WAINSCOT, rng, 0.01)
            elif zm < 0.90:
                col = GUNMETAL
            elif zm < 1.00 and ya > 0.0:
                col = HAZARD
            else:
                col = jitter(panel, rng, 0.008)
            p = [Vector((xs[i], ya, za)), Vector((xs[i + 1], ya, za)),
                 Vector((xs[i + 1], yb, zb)), Vector((xs[i], yb, zb))]
            shell.quad(p[0], p[1], p[2], p[3], col, col, col, col)

    # Ribs: the frames the plating hangs on, standing proud of it.
    fine = [t_floor + (T_CUT - t_floor) * k / 28 for k in range(29)]
    for xr in (-2.62, -0.52, 0.52, 2.62):
        for k in range(len(fine) - 1):
            pa = Vector((0.0, *hull_at(fine[k])))
            pb = Vector((0.0, *hull_at(fine[k + 1])))
            qa = pa + hull_inward(fine[k]) * 0.06
            qb = pb + hull_inward(fine[k + 1]) * 0.06
            ox0, ox1 = Vector((xr - 0.055, 0.0, 0.0)), Vector((xr + 0.055, 0.0, 0.0))
            shell.quad(qa + ox0, qa + ox1, qb + ox1, qb + ox0, METAL_DARK, METAL_DARK, METAL_DARK, METAL_DARK)
            shell.quad(pa + ox0, qa + ox0, qb + ox0, pb + ox0, GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)
            shell.quad(qa + ox1, pa + ox1, pb + ox1, qb + ox1, GUNMETAL, GUNMETAL, GUNMETAL, GUNMETAL)

    # The deck: plates in two tones. Nothing goes below it -- the game stands a model on its
    # lowest point, so a lip hanging under the deck would lift the floor off the ground.
    y_front = hull_at(T_CUT)[0]
    y_back = hull_at(t_floor)[0]
    for i in range(8):
        x0, x1 = X0 + (X1 - X0) * i / 8, X0 + (X1 - X0) * (i + 1) / 8
        for j in range(4):
            y0, y1 = y_front + (y_back - y_front) * j / 4, y_front + (y_back - y_front) * (j + 1) / 4
            col = jitter(DECK if (i + j) % 2 == 0 else DECK_ALT, rng, 0.006)
            shell.quad(Vector((x0, y0, 0.0)), Vector((x1, y0, 0.0)), Vector((x1, y1, 0.0)), Vector((x0, y1, 0.0)),
                       col, col, col, col)
    # A kick plate along the cut edge of the deck, so the floor reads as having a thickness.
    beam(shell, Vector((X0, y_front + 0.03, 0.03)), Vector((X1, y_front + 0.03, 0.03)), 0.06, 0.06, HAZARD)

    # The bulkheads at either end: flat, filling the section behind the cut.
    outline = [Vector((0.0, *hull_at(t))) for t in fine]
    outline.append(Vector((0.0, y_front, 0.0)))
    centre = Vector((0.0, 0.1, 1.15))
    for xe in (X0, X1):
        ox = Vector((xe, 0.0, 0.0))
        for k in range(len(outline)):
            a, c = outline[k] + ox, outline[(k + 1) % len(outline)] + ox
            col = WAINSCOT if min(a.z, c.z) < 0.5 else PANEL_ALT
            shell.tri(a, c, centre + ox, col, col, mix(col, PANEL, 0.4))

    # The left bulkhead's window, and the hatch in the right one -- daylight both.
    win_c = Vector((X0 + 0.012, 0.05, 1.45))
    annulus(shell, win_c + Vector((0.004, 0.0, 0.0)), Vector((1.0, 0.0, 0.0)), 0.30, 0.40, GUNMETAL, 18, METAL_DARK)
    disc(glow_day, win_c, Vector((1.0, 0.0, 0.0)), 0.30, DAYLIGHT, 18, mix(DAYLIGHT, (1.0, 1.0, 1.0), 0.4))
    hx = X1 - 0.012
    hy0, hy1, hz0, hz1 = -0.78, 0.12, 0.04, 1.70
    glow_day.quad(Vector((hx, hy1, hz0)), Vector((hx, hy0, hz0)), Vector((hx, hy0, hz1)), Vector((hx, hy1, hz1)),
                  mix(DAYLIGHT, (0.55, 0.62, 0.40), 0.5), mix(DAYLIGHT, (0.55, 0.62, 0.40), 0.5), DAYLIGHT, DAYLIGHT)
    # Its frame, striped the way the outside of the hatch is.
    for (p0, p1) in ((Vector((hx - 0.01, hy0 - 0.06, hz0)), Vector((hx - 0.01, hy0 - 0.06, hz1 + 0.06))),
                     (Vector((hx - 0.01, hy1 + 0.06, hz0)), Vector((hx - 0.01, hy1 + 0.06, hz1 + 0.06))),
                     (Vector((hx - 0.01, hy0 - 0.06, hz1 + 0.06)), Vector((hx - 0.01, hy1 + 0.06, hz1 + 0.06)))):
        n_seg = 7
        for s in range(n_seg):
            a, c = p0.lerp(p1, s / n_seg), p0.lerp(p1, (s + 1) / n_seg)
            beam(shell, a, c, 0.12, 0.04, HAZARD if s % 2 == 0 else GUNMETAL, up=Vector((1.0, 0.0, 0.0)))

    # Portholes in the back wall, between the benches.
    for xp in (-0.87, 0.87):
        tp = t_at_height(1.68)
        yp, zp = hull_at(tp)
        nrm = hull_inward(tp)
        c = Vector((xp, yp, zp)) + nrm * 0.012
        annulus(shell, c + nrm * 0.004, nrm, 0.17, 0.25, GUNMETAL, 16, METAL_DARK)
        disc(glow_day, c, nrm, 0.17, DAYLIGHT, 16, mix(DAYLIGHT, (1.0, 1.0, 1.0), 0.4))

    # The ceiling: a lamp strip down the middle, and cables.
    lamp_z = ZC + RZ - 0.05
    box(shell, (-2.25, -0.11, lamp_z - 0.03), (2.25, 0.11, lamp_z + 0.04), METAL_DARK)
    glow_lamp.quad(Vector((-2.15, 0.07, lamp_z - 0.032)), Vector((-2.15, -0.07, lamp_z - 0.032)),
                   Vector((2.15, -0.07, lamp_z - 0.032)), Vector((2.15, 0.07, lamp_z - 0.032)),
                   LAMP, LAMP, LAMP, LAMP)
    for (cy, col) in ((0.52, GUNMETAL), (0.60, HAZARD), (0.68, METAL_DARK)):
        cz = hull_at(math.acos(min(1.0, (cy / RY) ** (N / 2.0))))[1] - 0.09
        spine = [Vector((X0 + (X1 - X0) * k / 12, cy, cz - 0.05 * math.sin(math.pi * ((k % 3) / 3.0)))) for k in range(13)]
        shell.tube(spine, [0.022] * 13, [col] * 13, 5)

    # What lies about: a hide by the stove, firewood between the stove and the beacon, a
    # rolled bedding in the corner, the ship's water tank.
    rug_c = Vector((0.0, -0.45, 0.004))
    rim = [rug_c + Vector((math.cos(math.tau * k / 11) * 0.72 * rng.uniform(0.85, 1.1),
                           math.sin(math.tau * k / 11) * 0.42 * rng.uniform(0.85, 1.1), 0.0)) for k in range(11)]
    for k in range(11):
        shell.tri(rim[k], rim[(k + 1) % 11], rug_c, HIDE_EDGE, HIDE_EDGE, HIDE)
    for (p0, p1) in ((Vector((0.80, 0.20, 0.07)), Vector((0.80, 0.85, 0.07))),
                     (Vector((0.96, 0.18, 0.07)), Vector((0.96, 0.83, 0.07))),
                     (Vector((0.88, 0.22, 0.20)), Vector((0.88, 0.86, 0.20)))):
        _log(shell, p0, p1, 0.07, rng)
    bed = Vector((-2.58, 0.78, 0.0))
    shell.tube([bed, bed + UP * 0.62], [0.13, 0.13], [HIDE_EDGE, HIDE], 9)
    lashing(shell, bed + UP * 0.2, UP, 0.135, rng)
    lashing(shell, bed + UP * 0.45, UP, 0.135, rng)
    tank = Vector((2.55, 0.80, 0.0))
    shell.tube([tank, tank + UP * 0.30, tank + UP * 0.36, tank + UP * 0.72], [0.19, 0.19, 0.19, 0.17],
               [METAL, METAL, HAZARD, METAL], 12)

    spots = {"workbench": Vector((-1.75, 0.52, 0.0)), "kitchen": Vector((0.0, 0.48, 0.0)),
             "beacon": Vector((1.75, 0.52, 0.0))}
    return [("room", shell), ("daylight_glow", glow_day), ("lamp_glow", glow_lamp)], spots


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
# Export
# ==============================================================================

MODELS = {
    "room": (room, 7),
    "workbench": (workbench, 11),
    "kitchen": (kitchen, 13),
    "beacon": (beacon, 17),
}


def build_model(name, fn, seed, mat):
    made = fn(seed)
    spots = {}
    if isinstance(made, tuple):
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
