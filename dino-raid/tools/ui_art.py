# tools/ui_art.py
# THE FRAMES AS MADE THINGS (GAME-DESIGN 23; the player, 2026-10-20: "边框还是很像是页游，你可以借鉴比如valve之前的卡牌
# 游戏，炉石传说，这些优秀的界面，不是一定要弄得像网页框，可以是精美贴图"). Each of the game's frames modelled and
# photographed: a moulding of old gold mitred at its cut corners -- bevelled, a round bead along its middle, a stone of
# amber set over each corner -- in gold, in copper (danger), in dark bronze (quiet); the same, finer, for buttons; a
# nameplate of slate pointed at both ends in a gold rim (a red-enamelled one too); bars with round ends; a round rim, and
# a round plate of slate in one; a heavy seal of bronze with a milled edge, red enamel and eight amber stones; small
# stones in gold bezels for badges; enamelled shields. Lit as the HUD is, from the upper left, each throws its own soft
# shadow. The game draws them at half the size they are rendered at (sharp on a large screen), stretched only along
# their straight parts (nine-patch: tools/../scripts/UiArt.gd), with the numbers it needs to do so in ui_art.json.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python dino-raid/tools/ui_art.py
#   ... -- frame seal          only those
#
# Writes dino-raid/assets/ui/<name>.png and ui_art.json.

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.environ.get("UI_OUT", os.path.join(GAME, "assets", "ui"))
SAMPLES = 64

# -- Colours (linear) ---------------------------------------------------------------------------------------------------
GOLD = (0.62, 0.41, 0.15)
GOLD_BRIGHT = (0.86, 0.6, 0.24)
COPPER = (0.6, 0.2, 0.1)
BRONZE = (0.24, 0.18, 0.11)
SLATE = (0.006, 0.008, 0.009)
ENAMEL_RED = (0.16, 0.012, 0.006)
ENAMEL_GREEN = (0.04, 0.2, 0.09)
AMBER = (1.0, 0.42, 0.04)
IVORY = (0.85, 0.77, 0.6)
JADE = (0.12, 0.5, 0.3)


# -- Profiles: across a moulding from its inner edge (0) to its outer (1), (how far across, how high), in its widths ---

def _bead(c, r, h, n=8):
    return [(c - r * math.cos(math.pi * i / n), h + r * 0.95 * math.sin(math.pi * i / n)) for i in range(n + 1)]


MOULDING = [(0.0, 0.0), (0.0, 0.17), (0.05, 0.26), (0.14, 0.3), (0.26, 0.3)] + _bead(0.5, 0.22, 0.3) + \
    [(0.74, 0.3), (0.86, 0.3), (0.95, 0.26), (1.0, 0.17), (1.0, 0.0)]
BEZEL = [(0.0, 0.0), (0.0, 0.32), (0.12, 0.5), (0.32, 0.6), (0.5, 0.63), (0.7, 0.6), (0.88, 0.5), (1.0, 0.32), (1.0, 0.0)]
SEAL_BAND = [(0.0, 0.0), (0.0, 0.1), (0.03, 0.15), (0.1, 0.17)] + _bead(0.2, 0.08, 0.17, 6) + \
    [(0.3, 0.17), (0.38, 0.24), (0.62, 0.3), (0.8, 0.28), (0.94, 0.2), (1.0, 0.1), (1.0, 0.0)]


# -- Outlines (closed, anticlockwise seen from above), and moving one out -----------------------------------------------

def octagon(hw, hh, cut):
    return [(hw - cut, hh), (-(hw - cut), hh), (-hw, hh - cut), (-hw, -(hh - cut)), (-(hw - cut), -hh), (hw - cut, -hh),
            (hw, -(hh - cut)), (hw, hh - cut)]


def hexagon(hw, hh, tip):
    return [(hw - tip, hh), (-(hw - tip), hh), (-hw, 0.0), (-(hw - tip), -hh), (hw - tip, -hh), (hw, 0.0)]


def capsule(hw, hh, n=16):
    r = hh
    out = []
    for i in range(n + 1):
        a = -math.pi * 0.5 + math.pi * i / n
        out.append((hw - r + r * math.cos(a), r * math.sin(a)))
    for i in range(n + 1):
        a = math.pi * 0.5 + math.pi * i / n
        out.append((-(hw - r) + r * math.cos(a), r * math.sin(a)))
    # Anticlockwise: from the right end's bottom round to its top, then the left end top round to its bottom.
    return out


def circle(r, n=96):
    return [(r * math.cos(2.0 * math.pi * i / n), r * math.sin(2.0 * math.pi * i / n)) for i in range(n)]


def shield(w, h, n=10):
    top = h * 0.5
    pts = [(w * 0.5, top), (0.0, top - h * 0.05), (-w * 0.5, top)]
    for i in range(n):
        t = i / (n - 1)
        pts.append((-w * 0.5 * (1.0 - t * t), top - h * (0.22 + 0.78 * t)))
    for i in range(n - 2, -1, -1):
        t = i / (n - 1)
        pts.append((w * 0.5 * (1.0 - t * t), top - h * (0.22 + 0.78 * t)))
    # Anticlockwise from the top right: across the top, down the left, up the right.
    return pts


def offset(pts, d):
    """The outline moved out by `d` (mitred at its corners)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0 = Vector(pts[i - 1])
        p1 = Vector(pts[i])
        p2 = Vector(pts[(i + 1) % n])
        e1 = (p1 - p0).normalized()
        e2 = (p2 - p1).normalized()
        n1 = Vector((e1.y, -e1.x))       # outward, for an anticlockwise outline
        n2 = Vector((e2.y, -e2.x))
        m = (n1 + n2)
        if m.length < 1e-6:
            m = n1
        m.normalize()
        k = d / max(0.2, m.dot(n1))
        out.append(tuple(p1 + m * k))
    return out


def corners(pts, hard=30.0):
    """Which of an outline's points are corners (turning more than `hard` degrees)."""
    n = len(pts)
    out = []
    for i in range(n):
        e1 = (Vector(pts[i]) - Vector(pts[i - 1])).normalized()
        e2 = (Vector(pts[(i + 1) % n]) - Vector(pts[i])).normalized()
        out.append(math.degrees(e1.angle(e2)) > hard)
    return out


# -- Building ------------------------------------------------------------------------------------------------------------

def moulding(name, base, width, profile, mat, z0=0.0, bump=None):
    """A moulding `width` wide along the outline `base` (its inner edge), its cross-section `profile`; hard at the
    outline's corners, smooth along its curves. `bump(i, u)`: how much further out the outline's i-th point sits at
    `u` across (a milled edge)."""
    bm = bmesh.new()
    rings = []
    for (u, v) in profile:
        ring = offset(base, u * width)
        if bump is not None:
            ring = [tuple(Vector(p) + Vector(p).normalized() * bump(i, u)) for i, p in enumerate(ring)]
        rings.append((ring, z0 + v * width))
    sharp = corners(base)
    n = len(base)
    # Each point of the outline: one column of vertices (smooth), or two (a corner: one for each side).
    cols = []
    for i in range(n):
        col = [bm.verts.new((rings[k][0][i][0], rings[k][0][i][1], rings[k][1])) for k in range(len(profile))]
        cols.append((col, [bm.verts.new(v.co) for v in col] if sharp[i] else col))
    for i in range(n):
        j = (i + 1) % n
        a = cols[i][1]           # the side of point i facing on round to i+1
        b = cols[j][0]
        for k in range(len(profile) - 1):
            f = bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
            du = profile[k + 1][0] - profile[k][0]
            dv = profile[k + 1][1] - profile[k][1]
            mid = (Vector(base[i]) + Vector(base[j])) * 0.5
            out = Vector((mid.x, mid.y, 0.0))
            edge = (Vector(base[j]) - Vector(base[i])).normalized()
            out = Vector((edge.y, -edge.x, 0.0))
            want = out * (-dv) + Vector((0, 0, 1)) * du
            if want.length < 1e-6:
                want = Vector((0, 0, 1))
            f.normal_update()
            if f.normal.dot(want) < 0.0:
                f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def face(name, pts, z, mat):
    bm = bmesh.new()
    vs = [bm.verts.new((p[0], p[1], z)) for p in pts]
    f = bm.faces.new(vs)
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def stone(at, r, z, mat, setting=None, flat=0.55):
    """A cabochon stone of radius `r` at `at` (x, y), its base at height z -- in a bezel of `setting` if given."""
    if setting is not None:
        moulding("bezel", circle(r * 0.92, 48), r * 0.42, BEZEL, setting, z)
        for o in bpy.context.scene.objects:
            if o.name.startswith("bezel") and not o.get("placed"):
                o.location.x += at[0]
                o.location.y += at[1]
                o["placed"] = True
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=(at[0], at[1], z))
    s = bpy.context.active_object
    s.scale.z = flat
    bpy.ops.object.shade_smooth()
    s.data.materials.append(mat)
    return s


def stud(at, size, z, metal_mat, gem_mat):
    """A diamond of metal over a corner, a stone set in it."""
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=size, radius2=size * 0.6, depth=size * 0.32,
                                    location=(at[0], at[1], z + size * 0.16))
    d = bpy.context.active_object
    mod = d.modifiers.new("bevel", 'BEVEL')
    mod.width = size * 0.08
    mod.segments = 3
    d.data.materials.append(metal_mat)
    stone(at, size * 0.36, z + size * 0.3, gem_mat, flat=0.6)


# -- Materials -----------------------------------------------------------------------------------------------------------

def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def _mix_colour(nt):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = 'RGBA'
    a = [s for s in m.inputs if s.name == "A" and s.type == 'RGBA'][0]
    b = [s for s in m.inputs if s.name == "B" and s.type == 'RGBA'][0]
    out = [s for s in m.outputs if s.type == 'RGBA'][0]
    return m, a, b, out


def metal(name, colour, rough=0.3, dirt=0.65):
    """Old metal: its colour, a little rougher and smoother by turns, darker in its hollows."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = 1.0
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = _node(nt, "ShaderNodeTexNoise", Scale=0.09, Detail=6.0, Roughness=0.55)
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    rmap = _node(nt, "ShaderNodeMapRange")
    rmap.inputs["To Min"].default_value = rough - 0.08
    rmap.inputs["To Max"].default_value = rough + 0.1
    nt.links.new(noise.outputs["Fac"], rmap.inputs["Value"])
    nt.links.new(rmap.outputs["Result"], bsdf.inputs["Roughness"])
    ao = _node(nt, "ShaderNodeAmbientOcclusion", Distance=6.0)
    mix, a, b, out = _mix_colour(nt)
    a.default_value = (colour[0] * 0.18, colour[1] * 0.14, colour[2] * 0.1, 1.0)
    b.default_value = (colour[0], colour[1], colour[2], 1.0)
    curve = _node(nt, "ShaderNodeMapRange")
    curve.inputs["From Min"].default_value = 0.0
    curve.inputs["From Max"].default_value = 1.0
    curve.inputs["To Min"].default_value = 1.0 - dirt
    curve.inputs["To Max"].default_value = 1.0
    nt.links.new(ao.outputs["AO"], curve.inputs["Value"])
    nt.links.new(curve.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(out, bsdf.inputs["Base Color"])
    return m


def stone_mat(name, colour, glow=0.25, rough=0.06):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (colour[0], colour[1], colour[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Coat Roughness"].default_value = 0.03
    bsdf.inputs["Emission Color"].default_value = (colour[0], colour[1], colour[2], 1.0)
    bsdf.inputs["Emission Strength"].default_value = glow
    return m


def enamel(name, colour, rough=0.18, coat=0.7, grain=0.0):
    """A face: enamel (glossy, coated), or slate (`grain`: a fine texture in its surface)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (colour[0], colour[1], colour[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    if grain > 0.0:
        # Slate: matte -- it shows the light's fall across its grain, not the sky.
        bsdf.inputs["Specular IOR Level"].default_value = 0.18
        bsdf.inputs["Coat Weight"].default_value = 0.0
        coord = nt.nodes.new("ShaderNodeTexCoord")
        noise = _node(nt, "ShaderNodeTexNoise", Scale=0.16, Detail=10.0, Roughness=0.62)
        nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
        bump = _node(nt, "ShaderNodeBump", Strength=grain, Distance=1.0)
        nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# -- The studio ------------------------------------------------------------------------------------------------------------

def studio(w, h):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.render.film_transparent = True
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = max(w, h)
    cam_data.clip_end = 2000.0
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = (0.0, 0.0, 600.0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    # The sky the metal shows: bright and warm up and to the upper left (where the light is), dark below.
    world = bpy.data.worlds.new("sky")
    sc.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = (-0.62, 0.62, 0.48)
    nt.links.new(coord.outputs["Generated"], dot.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.004, 0.0035, 0.003, 1.0)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (3.4, 2.9, 2.3, 1.0)
    mid = ramp.color_ramp.elements.new(0.55)
    mid.color = (0.06, 0.05, 0.04, 1.0)
    knee = ramp.color_ramp.elements.new(0.82)
    knee.color = (0.5, 0.42, 0.33, 1.0)
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -0.6
    rng.inputs["From Max"].default_value = 1.0
    nt.links.new(dot.outputs["Value"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    # The light: from the upper left, a little soft; a faint fill from the lower right.
    key = bpy.data.lights.new("key", 'SUN')
    key.energy = 2.6
    key.angle = math.radians(4.0)
    ko = bpy.data.objects.new("key", key)
    ko.rotation_euler = Vector((-0.55, 0.55, 0.62)).normalized().to_track_quat('Z', 'Y').to_euler()
    sc.collection.objects.link(ko)
    fill = bpy.data.lights.new("fill", 'SUN')
    fill.energy = 0.25
    fill.use_shadow = False
    fo = bpy.data.objects.new("fill", fill)
    fo.rotation_euler = Vector((0.6, -0.5, 0.6)).normalized().to_track_quat('Z', 'Y').to_euler()
    sc.collection.objects.link(fo)
    # The ground it lies on, there only for the shadow it takes.
    bpy.ops.mesh.primitive_plane_add(size=4000.0, location=(0.0, 0.0, -0.05))
    bpy.context.active_object.is_shadow_catcher = True


def shoot(name):
    path = os.path.join(OUT, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[OK] " + name)


# -- The pieces ------------------------------------------------------------------------------------------------------------

INFO = {}


def frame(name, size, pad, band, cut, colour, rough=0.3, gem=AMBER):
    """A frame for a panel or a button (nine-patch): `size` square, its outer edge `pad` in from the picture's."""
    studio(size, size)
    gold = metal("metal", colour, rough)
    hw = size * 0.5 - pad
    inner = octagon(hw - band, hw - band, cut - band * (2.0 - math.sqrt(2.0)))
    moulding("rim", inner, band, MOULDING, gold)
    # A stone over each cut corner, on the bead.
    gems = stone_mat("gem", gem)
    mid = hw - band * 0.5
    c_mid = cut - band * 0.5 * (2.0 - math.sqrt(2.0))
    d = mid - c_mid * 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            stud((sx * d, sy * d), band * 0.95, band * 0.3, gold, gems)
    shoot(name)
    INFO[name] = {"w": size, "h": size, "pad": pad, "margin": pad + cut + band * 0.6, "band": band, "cut": cut}


def plate(name, w, h, pad, tip, band, colour, face_colour, grain=0.4):
    """A nameplate pointed at both ends (stretched along its middle)."""
    studio(w, h)
    gold = metal("metal", colour)
    hw = w * 0.5 - pad
    hh = h * 0.5 - pad
    # The tip's angle the same for the inner edge as the outer: moved in by `band`, the tip shortens with the height.
    k = tip / hh
    inner = hexagon(hw - band * math.sqrt(1.0 + k * k), hh - band, tip * (hh - band) / hh)
    moulding("rim", inner, band, MOULDING, gold)
    face("face", inner, band * 0.1, enamel("face", face_colour, 0.55 if grain else 0.14, 0.15 if grain else 0.8, grain))
    shoot(name)
    INFO[name] = {"w": w, "h": h, "pad": pad, "margin_x": pad + tip + band, "margin_y": 0, "band": band}


def bar(name, w, h, pad, band, colour, face_colour):
    """A bar with round ends (stretched along its middle)."""
    studio(w, h)
    gold = metal("metal", colour)
    hw = w * 0.5 - pad
    hh = h * 0.5 - pad
    inner = capsule(hw - band, hh - band)
    moulding("rim", inner, band, MOULDING, gold)
    face("face", inner, band * 0.1, enamel("face", face_colour, 0.55, 0.15, 0.5))
    shoot(name)
    INFO[name] = {"w": w, "h": h, "pad": pad, "margin_x": pad + hh, "margin_y": 0, "band": band}


def ring(name, size, pad, band, colour, face_colour=None):
    """A round rim -- with a face of slate in it, or open."""
    studio(size, size)
    gold = metal("metal", colour)
    r = size * 0.5 - pad
    inner = circle(r - band)
    moulding("rim", inner, band, MOULDING, gold)
    if face_colour is not None:
        face("face", inner, band * 0.1, enamel("face", face_colour, 0.55, 0.15, 0.5))
    shoot(name)
    INFO[name] = {"w": size, "h": size, "pad": pad, "radius": r, "inner": r - band}


def seal(name, size, pad):
    """The great seal: a heavy band of bronze with a milled edge and eight amber stones round it, a face of red enamel,
    a fine gold ring inside it."""
    studio(size, size)
    bronze = metal("bronze", (0.72, 0.46, 0.22), 0.34)
    gold = metal("gold", GOLD_BRIGHT, 0.24)
    r = size * 0.5 - pad
    band = r * 0.27
    inner = circle(r - band, 160)
    moulding("band", inner, band, SEAL_BAND, bronze, 0.0)
    moulding("bead", circle(r - band * 0.12, 128), band * 0.12, BEZEL, gold, band * 0.1)
    face("face", inner, band * 0.06, enamel("red", ENAMEL_RED, 0.16, 0.85))
    moulding("line", circle(r - band - band * 0.32, 128), band * 0.12, BEZEL, gold, band * 0.06)
    gems = stone_mat("gem", AMBER, 0.35)
    for k in range(8):
        a = math.pi * 0.25 * k + math.pi / 8.0
        at = (math.cos(a) * (r - band * 0.4), math.sin(a) * (r - band * 0.4))
        stone(at, band * 0.2, band * 0.3, gems, gold)
    shoot(name)
    INFO[name] = {"w": size, "h": size, "pad": pad, "radius": r, "inner": r - band}


def gem(name, size, pad, colour, glow):
    studio(size, size)
    gold = metal("metal", GOLD_BRIGHT, 0.26)
    r = size * 0.5 - pad
    stone((0.0, 0.0), r * 0.78, r * 0.18, stone_mat("stone", colour, glow, 0.12), gold)
    shoot(name)
    INFO[name] = {"w": size, "h": size, "pad": pad, "radius": r}


def shield_piece(name, w, h, pad, face_colour):
    studio(w, h)
    gold = metal("metal", GOLD)
    sw = w - pad * 2.0
    sh = h - pad * 2.0
    band = sw * 0.09
    inner = offset(shield(sw, sh, 12), -band)
    moulding("rim", inner, band, MOULDING, gold)
    face("face", inner, band * 0.1, enamel("face", face_colour, 0.2, 0.8))
    shoot(name)
    INFO[name] = {"w": w, "h": h, "pad": pad}


def coin(name, size, pad):
    """The gold coin (the HUD's): a raised rim with a bead inside it, a field a little lower, a fine ring round it."""
    studio(size, size)
    gold = metal("metal", GOLD_BRIGHT, 0.26, 0.5)
    r = size * 0.5 - pad
    band = r * 0.2
    inner = circle(r - band, 128)
    moulding("rim", inner, band, MOULDING, gold)
    face("field", inner, band * 0.12, metal("field", (0.8, 0.56, 0.22), 0.36, 0.3))
    moulding("ring", circle(r - band * 1.9, 128), band * 0.2, BEZEL, gold, band * 0.12)
    shoot(name)
    INFO[name] = {"w": size, "h": size, "pad": pad, "radius": r, "inner": r - band}


def _card_rect(x0, y0, x1, y1, hw, hh, cut=0.0):
    """A rectangle given in the card's own pixels (from its top left, down), as an anticlockwise outline -- its corners
    cut by `cut`."""
    ax, ay, bx, by = x0 - hw, hh - y1, x1 - hw, hh - y0
    if cut <= 0.0:
        return [(bx, by), (ax, by), (ax, ay), (bx, ay)]
    return [(bx - cut, by), (ax + cut, by), (ax, by - cut), (ax, ay + cut), (ax + cut, ay), (bx - cut, ay), (bx, ay + cut), (bx, by - cut)]


def card(name, colour, gem_colour, rough=0.3):
    """A card's frame, whole (the card is always the same size): a moulding of `colour` round it with stones of
    `gem_colour` over its corners; a face of slate with a window left open for the picture, the window rimmed; a band of
    darker slate for the name; a slip of parchment for what it does; a bezel for the price's coin at the top left."""
    W, H, pad = 300.0, 424.0, 16
    studio(int(W) + pad * 2, int(H) + pad * 2)
    rim = metal("metal", colour, rough)
    hw, hh = W * 0.5, H * 0.5
    band, cut = 14.0, 24.0
    inner = octagon(hw - band, hh - band, cut - band * (2.0 - math.sqrt(2.0)))
    moulding("rim", inner, band, MOULDING, rim)
    gems = stone_mat("gem", gem_colour, 0.25)
    mid_x, mid_y = hw - band * 0.5, hh - band * 0.5
    c_mid = cut - band * 0.5 * (2.0 - math.sqrt(2.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            stud((sx * (mid_x - c_mid * 0.5), sy * (mid_y - c_mid * 0.5)), band * 0.95, band * 0.3, rim, gems)
    # The face, the window left open in it.
    window = _card_rect(24, 60, 276, 220, hw, hh)
    bm = bmesh.new()
    loops = []
    for loop in (inner, window):
        vs = [bm.verts.new((p[0], p[1], band * 0.1)) for p in loop]
        loops += [bm.edges.new((vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=loops)
    for f in bm.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    me = bpy.data.meshes.new("face")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("face", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(enamel("slate", SLATE, 0.6, 0.0, 0.5))
    moulding("window", window, 6.0, BEZEL, rim, band * 0.1)
    # The name's band: darker slate, edged.
    name_band = _card_rect(18, 230, 282, 274, hw, hh, 6.0)
    face("band", name_band, band * 0.16, enamel("band", (0.003, 0.004, 0.005), 0.5, 0.0, 0.4))
    moulding("band_rim", name_band, 4.0, BEZEL, rim, band * 0.1)
    # The slip of parchment: a little raised, a fine rim.
    slip = _card_rect(24, 286, 276, 386, hw, hh, 6.0)
    paper = bpy.data.materials.new("paper")
    paper.use_nodes = True
    nt = paper.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = _node(nt, "ShaderNodeTexNoise", Scale=0.05, Detail=8.0, Roughness=0.6)
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    mix, a, b, out = _mix_colour(nt)
    a.default_value = (0.62, 0.5, 0.31, 1.0)
    b.default_value = (0.86, 0.76, 0.55, 1.0)
    rng = _node(nt, "ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = 0.3
    rng.inputs["From Max"].default_value = 0.7
    nt.links.new(noise.outputs["Fac"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(out, bsdf.inputs["Base Color"])
    fibre = _node(nt, "ShaderNodeTexNoise", Scale=0.6, Detail=12.0, Roughness=0.7)
    nt.links.new(coord.outputs["Object"], fibre.inputs["Vector"])
    bump = _node(nt, "ShaderNodeBump", Strength=0.15, Distance=1.0)
    nt.links.new(fibre.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    face("slip", slip, band * 0.22, paper)
    moulding("slip_rim", slip, 3.0, BEZEL, rim, band * 0.1)
    # The price's coin sits in a bezel at the top left, over the window's corner (hiding it).
    bezel = [(p[0] + 42.0 - hw, p[1] + hh - 42.0) for p in circle(19.5, 64)]
    face("socket", bezel, band * 0.45, enamel("socket", SLATE, 0.6, 0.0, 0.4))
    moulding("bezel", bezel, 5.0, BEZEL, rim, band * 0.45)
    shoot(name)
    INFO[name] = {"w": int(W) + pad * 2, "h": int(H) + pad * 2, "pad": pad}


def crest(name, size, pad):
    """The jewel on a heading panel's top edge: a diamond of gold with an amber stone in it."""
    studio(size, size)
    gold = metal("metal", GOLD_BRIGHT, 0.24)
    stud((0.0, 0.0), size * 0.5 - pad, 0.0, gold, stone_mat("gem", AMBER, 0.3))
    shoot(name)
    INFO[name] = {"w": size, "h": size, "pad": pad}


PIECES = {
    "frame": lambda: frame("frame", 224, 16, 22, 26, GOLD),
    "frame_red": lambda: frame("frame_red", 224, 16, 22, 26, COPPER, 0.32, AMBER),
    "frame_dim": lambda: frame("frame_dim", 224, 16, 22, 26, BRONZE, 0.42, (0.5, 0.3, 0.1)),
    "button": lambda: frame("button", 128, 10, 13, 15, GOLD),
    "button_bright": lambda: frame("button_bright", 128, 10, 13, 15, GOLD_BRIGHT, 0.2),
    "button_dim": lambda: frame("button_dim", 128, 10, 13, 15, BRONZE, 0.45, (0.4, 0.3, 0.2)),
    "plate": lambda: plate("plate", 256, 120, 16, 38, 12, GOLD, SLATE),
    "plate_small": lambda: plate("plate_small", 192, 72, 12, 22, 8, GOLD, SLATE),
    "plate_small_red": lambda: plate("plate_small_red", 192, 72, 12, 22, 8, GOLD_BRIGHT, ENAMEL_RED, 0.0),
    "bar": lambda: bar("bar", 256, 104, 16, 10, GOLD, SLATE),
    "bar_small": lambda: bar("bar_small", 192, 84, 14, 8, GOLD, SLATE),
    "ring": lambda: ring("ring", 160, 14, 14, GOLD),
    "medallion": lambda: ring("medallion", 160, 14, 14, GOLD, SLATE),
    "seal": lambda: seal("seal", 256, 22),
    "gem_ivory": lambda: gem("gem_ivory", 64, 6, IVORY, 0.05),
    "gem_amber": lambda: gem("gem_amber", 64, 6, AMBER, 0.3),
    "gem_jade": lambda: gem("gem_jade", 64, 6, JADE, 0.15),
    "shield_green": lambda: shield_piece("shield_green", 104, 120, 12, ENAMEL_GREEN),
    "shield_red": lambda: shield_piece("shield_red", 104, 120, 12, (0.36, 0.05, 0.03)),
    "crest": lambda: crest("crest", 64, 8),
    "coin": lambda: coin("coin", 128, 10),
    "card_bronze": lambda: card("card_bronze", (0.5, 0.27, 0.11), (0.45, 0.025, 0.02), 0.34),
    "card_silver": lambda: card("card_silver", (0.6, 0.62, 0.66), (0.04, 0.16, 0.6), 0.26),
    "card_gold": lambda: card("card_gold", GOLD_BRIGHT, AMBER, 0.24),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "ui_art.json")
    if os.path.exists(path):
        INFO.update(json.load(open(path, encoding="utf-8")))
    for name, make in PIECES.items():
        if args and name not in args:
            continue
        make()
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(INFO, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
