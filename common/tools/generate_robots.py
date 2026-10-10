# common/tools/generate_robots.py
# The robots of dino-raid: a walker, a turret and the time machine they come out of.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python common/tools/generate_robots.py
#   ... -- --preview <png>    also renders the three side by side
#
# Hard, cold and exact against the soft green valley: off-white panels over dark steel, an orange stripe, and
# lights that glow. Faceted like the props (one surface each, coloured by its vertices), but each robot is a
# small tree of named parts so the game can move them: leg_l and leg_r swing from the hip, head turns on its
# pivot, ring turns in the machine; every part named glow* is a light (the game makes it shine -- cyan, or
# red for glow_red).
#
# Blender +Y is the robot's front: the glTF export turns that into the game's -Z, the way a Node3D looks.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import Builder, vertex_colour_material, reset  # noqa: E402

COMMON = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(COMMON, "assets", "models", "robots")

WHITE = (0.84, 0.86, 0.88)
PANEL = (0.62, 0.65, 0.69)
STEEL = (0.30, 0.32, 0.35)
DARK = (0.13, 0.14, 0.16)
JOINT = (0.08, 0.08, 0.09)
ORANGE = (0.96, 0.46, 0.10)
YELLOW = (0.93, 0.73, 0.12)
GLOW = (0.35, 0.90, 1.00)
RED = (1.00, 0.22, 0.16)


# -- Shapes, put into a Builder -------------------------------------------------------------------------------

def _take(b, bm, col, shade=0.0):
    """Every face of `bm` into `b` in `col`, upward faces a little lighter when `shade`."""
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    for f in bm.faces:
        k = 1.0 + shade * f.normal.z
        c = tuple(min(1.0, x * k) for x in col)
        v = [x.co.copy() for x in f.verts]
        b.tri(v[0], v[1], v[2], c, c, c)
    bm.free()


def _place(bm, at, rot=None):
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot.to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)


def box(b, at, size, col, bevel=0.0, rot=None, shade=0.12):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1, profile=0.5, affect='EDGES')
    _place(bm, at, rot)
    _take(b, bm, col, shade)


def cyl(b, at, radius, depth, col, sides=12, axis='Z', radius2=None, rot=None, shade=0.12):
    """A cylinder (or a cone, with radius2) of `depth` along `axis`, centred on `at`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    turn = {'Z': Matrix.Identity(3), 'X': Matrix.Rotation(math.pi / 2, 3, 'Y'),
            'Y': Matrix.Rotation(-math.pi / 2, 3, 'X')}[axis]
    if rot is not None:
        turn = rot @ turn
    _place(bm, at, turn)
    _take(b, bm, col, shade)


def bar(b, p0, p1, width, depth, col, bevel=0.0):
    """A box from p0 to p1, `width` across (x) and `depth` deep."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    up = d.normalized()
    side = Vector((1.0, 0.0, 0.0))
    fwd = up.cross(side).normalized()
    side = fwd.cross(up).normalized()
    rot = Matrix((side, fwd, up)).transposed()
    box(b, (p0 + p1) * 0.5, (width, depth, d.length), col, bevel, rot)


def ring(b, at, radius, tube, col, segs=32, sides=8, plane='XZ', cols=None):
    """A torus standing in `plane`, made as a tube round a circle; cols(i) may colour each segment."""
    spine = []
    for i in range(segs + 1):
        a = math.tau * i / segs
        if plane == 'XZ':
            spine.append(Vector(at) + Vector((math.cos(a) * radius, 0.0, math.sin(a) * radius)))
        else:
            spine.append(Vector(at) + Vector((math.cos(a) * radius, math.sin(a) * radius, 0.0)))
    for i in range(segs):
        c = cols(i) if cols else col
        b.tube([spine[i], spine[i + 1]], [tube, tube], [c, c], sides)


def disc(b, at, radius, col, segs=32, plane='XZ', thick=0.02):
    cyl(b, at, radius, thick, col, sides=segs, axis='Y' if plane == 'XZ' else 'Z', shade=0.0)


# -- Parts become objects --------------------------------------------------------------------------------------

def part(name, b, mat, parent=None, origin=(0.0, 0.0, 0.0)):
    """Builder `b` (made round `origin`) as object `name`, placed at `origin` under `parent`."""
    obj = b.to_object(name, mat)
    obj.location = Vector(origin)
    if parent is not None:
        obj.parent = parent
    return obj


def root(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# -- The walker ------------------------------------------------------------------------------------------------

def walker(mat):
    """A walker: a hunched armoured biped a head taller than a child, one round eye, a blaster for a right
    arm and a claw for a left; its legs bend backwards like a bird's."""
    top = root("walker")
    lean = Matrix.Rotation(math.radians(-10), 3, 'X')            # leaning into its stride
    body = Builder()
    box(body, (0, 0, 1.06), (0.56, 0.42, 0.26), DARK, 0.04)                      # pelvis
    for x in (-0.25, 0.25):
        cyl(body, (x, 0, 1.06), 0.12, 0.12, JOINT, 10, 'X')                      # hip housings
    box(body, (0, 0.04, 1.47), (0.84, 0.62, 0.66), WHITE, 0.1, lean)             # torso shell
    box(body, (0, 0.33, 1.47), (0.64, 0.08, 0.46), PANEL, 0.03, lean)            # chest plate
    for k in range(3):                                                            # vents
        box(body, (0, 0.375, 1.38 + k * 0.07), (0.44, 0.02, 0.025), JOINT, 0.0, lean)
    box(body, (-0.2, 0.37, 1.63), (0.22, 0.03, 0.05), ORANGE, 0.0, lean)
    box(body, (0.2, 0.37, 1.63), (0.22, 0.03, 0.05), ORANGE, 0.0, lean)
    for x in (-0.43, 0.43):
        box(body, (x, 0.02, 1.47), (0.06, 0.5, 0.5), PANEL, 0.02, lean)          # side plates
    # The head: low, armoured, one round eye.
    box(body, (0, 0.24, 1.9), (0.5, 0.44, 0.26), WHITE, 0.07)
    box(body, (0, 0.16, 2.05), (0.36, 0.3, 0.06), PANEL, 0.02)
    cyl(body, (0, 0.47, 1.89), 0.12, 0.06, JOINT, 16, 'Y')                       # eye socket
    for x in (-0.2, 0.2):
        box(body, (x, 0.02, 2.08), (0.04, 0.2, 0.14), STEEL, 0.01)              # fins
    # Shoulders.
    for x in (-0.52, 0.52):
        box(body, (x, 0.0, 1.68), (0.26, 0.5, 0.22), PANEL, 0.06, Matrix.Rotation(math.radians(-14 if x < 0 else 14), 3, 'Y'))
        box(body, (x * 1.04, 0.0, 1.8), (0.24, 0.36, 0.04), ORANGE)
    # Right arm: the blaster, with cooling rings and a feed from its back.
    box(body, (0.56, 0.0, 1.42), (0.15, 0.2, 0.36), STEEL, 0.03)
    box(body, (0.6, 0.22, 1.2), (0.24, 0.62, 0.26), WHITE, 0.05)
    box(body, (0.6, 0.26, 1.34), (0.16, 0.4, 0.04), PANEL)
    cyl(body, (0.6, 0.66, 1.2), 0.06, 0.4, DARK, 10, 'Y')
    for y in (0.58, 0.68, 0.78):
        cyl(body, (0.6, y, 1.2), 0.085, 0.03, STEEL, 10, 'Y')
    cyl(body, (0.6, 0.88, 1.2), 0.08, 0.06, DARK, 10, 'Y')
    bar(body, (0.5, -0.32, 1.5), (0.62, -0.05, 1.22), 0.05, 0.05, JOINT)
    # Left arm: a forearm and three hooked fingers.
    box(body, (-0.56, 0.02, 1.4), (0.15, 0.2, 0.36), STEEL, 0.03)
    box(body, (-0.6, 0.14, 1.14), (0.17, 0.36, 0.2), WHITE, 0.04)
    for k in (-1, 0, 1):
        bar(body, (-0.6 + k * 0.05, 0.3, 1.1), (-0.6 + k * 0.06, 0.44, 0.98), 0.035, 0.035, DARK)
    # The pack: a power cell and two exhausts.
    box(body, (0, -0.38, 1.5), (0.5, 0.2, 0.5), DARK, 0.05)
    cyl(body, (0, -0.5, 1.5), 0.13, 0.42, STEEL, 12, 'Z')
    for x in (-0.18, 0.18):
        cyl(body, (x, -0.42, 1.82), 0.05, 0.14, JOINT, 8)
    cyl(body, (-0.2, -0.32, 2.14), 0.016, 0.44, STEEL, 6)
    obj_body = part("body", body, mat, top)

    glow = Builder()
    cyl(glow, (0, 0.5, 1.89), 0.085, 0.012, GLOW, 16, 'Y', shade=0.0)
    box(glow, (0, -0.615, 1.5), (0.03, 0.012, 0.34), GLOW, shade=0.0)
    box(glow, (0.6, 0.534, 1.2), (0.02, 0.01, 0.02), GLOW, shade=0.0)
    part("glow", glow, mat, obj_body)
    red = Builder()
    cyl(red, (-0.2, -0.32, 2.38), 0.035, 0.05, RED, 8, shade=0.0)
    box(red, (0.14, 0.465, 2.0), (0.05, 0.01, 0.03), RED, shade=0.0)
    part("glow_red", red, mat, obj_body)

    for name, x in (("leg_l", -0.25), ("leg_r", 0.25)):
        leg = Builder()
        knee = (0.0, 0.2, -0.44)
        ankle = (0.0, -0.14, -0.84)
        bar(leg, (0, 0, 0), knee, 0.19, 0.19, STEEL, 0.03)
        box(leg, (0, 0.12, -0.2), (0.21, 0.06, 0.3), WHITE, 0.02, Matrix.Rotation(math.radians(-25), 3, 'X'))
        cyl(leg, knee, 0.09, 0.17, JOINT, 10, 'X')
        box(leg, (0, 0.29, -0.44), (0.16, 0.06, 0.14), ORANGE, 0.02)            # knee cap
        bar(leg, knee, ankle, 0.14, 0.14, PANEL, 0.02)
        box(leg, (0, 0.1, -0.64), (0.16, 0.05, 0.3), WHITE, 0.02, Matrix.Rotation(math.radians(40), 3, 'X'))
        cyl(leg, ankle, 0.065, 0.14, JOINT, 8, 'X')
        box(leg, (0, 0.1, -0.96), (0.24, 0.4, 0.08), DARK, 0.02)                 # foot
        for t in (-0.07, 0.07):
            box(leg, (t, 0.33, -0.97), (0.07, 0.14, 0.06), STEEL, 0.015)          # toes
        box(leg, (0, -0.16, -0.95), (0.08, 0.14, 0.06), STEEL, 0.015)             # spur
        part(name, leg, mat, top, (x, 0.0, 1.06))
    return top


# -- The turret ------------------------------------------------------------------------------------------------

def turret(mat):
    """A turret: a braced plinth, a column, and on it a head that turns -- armoured cheeks, twin barrels with
    heat sinks, an ammunition drum, a sensor dome and a small dish."""
    top = root("turret")
    base = Builder()
    cyl(base, (0, 0, 0.18), 1.1, 0.36, DARK, 6)
    cyl(base, (0, 0, 0.4), 0.9, 0.08, STEEL, 6)
    for k in range(6):
        a = math.tau * (k + 0.5) / 6
        c = YELLOW if k % 2 == 0 else JOINT
        box(base, (math.cos(a) * 0.98, math.sin(a) * 0.98, 0.3), (0.06, 1.05, 0.1), c, 0.0,
            Matrix.Rotation(a, 3, 'Z'))
    for k in range(12):                                                           # bolts
        a = math.tau * k / 12
        cyl(base, (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.45), 0.04, 0.04, STEEL, 6)
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        p0 = (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.32)
        p1 = (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.06)
        bar(base, p0, p1, 0.17, 0.17, STEEL, 0.03)
        bar(base, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.9), (math.cos(a) * 1.2, math.sin(a) * 1.2, 0.2), 0.06, 0.06, JOINT)
        box(base, p1, (0.38, 0.38, 0.08), DARK, 0.02)
    cyl(base, (0, 0, 0.85), 0.44, 0.9, PANEL, 10)
    cyl(base, (0, 0, 1.33), 0.48, 0.06, DARK, 10)
    cyl(base, (0, 0, 1.55), 0.4, 0.4, PANEL, 10)
    cyl(base, (0, 0, 1.74), 0.58, 0.16, DARK, 10)
    for k in range(3):                                                            # cable runs
        a = math.tau * k / 3
        bar(base, (math.cos(a) * 0.45, math.sin(a) * 0.45, 1.7), (math.cos(a) * 0.48, math.sin(a) * 0.48, 0.45), 0.05, 0.05, JOINT)
    obj = part("base", base, mat, top)

    head = Builder()
    box(head, (0, 0.05, 0.36), (1.0, 1.0, 0.7), WHITE, 0.1)
    for x in (-0.58, 0.58):                                                       # armoured cheeks
        box(head, (x, 0.1, 0.34), (0.16, 0.9, 0.6), PANEL, 0.04, Matrix.Rotation(math.radians(-8 if x < 0 else 8), 3, 'Z'))
        box(head, (x * 1.06, 0.35, 0.34), (0.06, 0.3, 0.4), ORANGE, 0.01)
    box(head, (0, 0.05, 0.74), (0.66, 0.6, 0.06), ORANGE)
    for x in (-0.2, 0.2):
        cyl(head, (x, 0.72, 0.3), 0.14, 0.5, STEEL, 10, 'Y')
        cyl(head, (x, 1.25, 0.3), 0.08, 0.95, DARK, 10, 'Y')
        for y in (1.0, 1.15, 1.3):
            cyl(head, (x, y, 0.3), 0.11, 0.04, STEEL, 10, 'Y')                   # heat sinks
        box(head, (x, 1.74, 0.3), (0.2, 0.16, 0.2), STEEL, 0.02)
    cyl(head, (0, -0.56, 0.3), 0.3, 0.62, DARK, 12, 'X')
    cyl(head, (0, -0.56, 0.3), 0.31, 0.12, YELLOW, 12, 'X')
    cyl(head, (-0.32, -0.18, 0.86), 0.03, 0.32, STEEL, 6)
    cyl(head, (-0.32, -0.18, 1.06), 0.18, 0.08, PANEL, 10, radius2=0.04)
    cyl(head, (0.18, -0.2, 0.74), 0.15, 0.08, DARK, 12)
    head_obj = part("head", head, mat, obj, (0, 0, 1.82))
    glow = Builder()
    cyl(glow, (0.18, -0.2, 0.8), 0.12, 0.06, GLOW, 12, radius2=0.06, shade=0.0)  # sensor dome
    part("glow", glow, mat, head_obj)
    red = Builder()
    box(red, (0, 0.56, 0.6), (0.34, 0.03, 0.1), RED, shade=0.0)
    part("glow_red", red, mat, head_obj)
    return top


# -- The time machine ----------------------------------------------------------------------------------------

def machine(mat):
    top = root("machine")
    base = Builder()
    cyl(base, (0, 0, 0.25), 3.4, 0.5, DARK, 8)
    cyl(base, (0, 0, 0.55), 3.1, 0.1, STEEL, 8)
    for k in range(16):                                                           # hazard edge
        a = math.tau * (k + 0.5) / 16
        c = YELLOW if k % 2 == 0 else JOINT
        box(base, (math.cos(a) * 3.28, math.sin(a) * 3.28, 0.42), (0.08, 1.25, 0.12), c, 0.0,
            Matrix.Rotation(a, 3, 'Z'))
    for y, h in ((3.6, 0.17), (3.95, 0.09)):                                       # steps at the front
        box(base, (0, y - 0.2, h), (2.4, 0.45, h * 2), STEEL, 0.02)
    for x in (-2.95, 2.95):                                                        # the pylons
        box(base, (x, 0, 3.2), (0.8, 1.1, 5.4), WHITE, 0.12)
        box(base, (x, 0.56, 3.4), (0.5, 0.06, 4.2), PANEL, 0.02)
        box(base, (x, 0.0, 5.95), (1.0, 1.3, 0.3), DARK, 0.05)
        box(base, (x, 0.6, 1.2), (0.82, 0.04, 0.16), ORANGE)
        box(base, (x * 0.92, 0, 3.4), (0.5, 0.5, 0.7), STEEL, 0.05)                # clamp
    for x, y in ((-2.2, -2.2), (2.2, -2.2), (-2.4, 1.6), (2.4, 1.6)):              # capacitors
        cyl(base, (x, y, 1.1), 0.32, 1.1, PANEL, 10)
        cyl(base, (x, y, 1.72), 0.36, 0.14, DARK, 10)
    box(base, (0, -2.5, 0.95), (1.6, 0.7, 0.8), STEEL, 0.06)                     # console
    box(base, (0, -2.2, 1.38), (1.3, 0.4, 0.1), DARK, 0.02)
    for x in (-2.95, 2.95):                                                        # cables down the back
        bar(base, (x * 0.9, -0.6, 2.2), (x * 0.55, -2.2, 0.62), 0.12, 0.12, JOINT)
    obj = part("base", base, mat, top)

    rim = Builder()
    ring(rim, (0, 0, 0), 2.45, 0.34, PANEL, 36, 10, 'XZ',
         cols=lambda i: STEEL if i % 6 in (0, 3) else PANEL)
    for k in range(12):
        a = math.tau * k / 12
        box(rim, (math.cos(a) * 2.45, 0.0, math.sin(a) * 2.45), (0.3, 0.86, 0.3), DARK, 0.04,
            Matrix.Rotation(-a, 3, 'Y'))
    ring_obj = part("ring", rim, mat, obj, (0, 0, 3.4))
    glow = Builder()
    for k in range(12):
        a = math.tau * (k + 0.5) / 12
        box(glow, (math.cos(a) * 2.45, 0.36, math.sin(a) * 2.45), (0.5, 0.02, 0.08), GLOW, 0.0,
            Matrix.Rotation(-a, 3, 'Y'), shade=0.0)
    part("glow", glow, mat, ring_obj)

    lights = Builder()
    for x, y in ((-2.2, -2.2), (2.2, -2.2), (-2.4, 1.6), (2.4, 1.6)):
        cyl(lights, (x, y, 1.86), 0.2, 0.14, GLOW, 10, shade=0.0)
    for x in (-2.95, 2.95):
        box(lights, (x, 0.6, 4.4), (0.12, 0.02, 1.6), GLOW, shade=0.0)
    part("glow", lights, mat, obj)
    portal = Builder()
    disc(portal, (0, 0, 0), 2.12, GLOW, 40)
    part("portal", portal, mat, obj, (0, 0, 3.4))
    return top


# -- Out to the game ---------------------------------------------------------------------------------------------

def export_tree(top, path):
    bpy.ops.object.select_all(action='DESELECT')
    stack = [top]
    while stack:
        o = stack.pop()
        o.select_set(True)
        stack += list(o.children)
    bpy.context.view_layer.objects.active = top
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def preview(tops, path):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 800
    shine = bpy.data.materials.new("Shine")
    shine.use_nodes = True
    bsdf = shine.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Emission Color"].default_value = (0.35, 0.9, 1.0, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 6.0
    for o in bpy.data.objects:
        if o.name.startswith("glow") or o.name.startswith("portal"):
            o.data.materials.clear()
            o.data.materials.append(shine)
    for t, x in zip(tops, (-6.0, -2.5, 4.0)):
        t.location.x = x
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.27, 0.18, 1.0)
    g.data.materials.append(gm)
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(50), math.radians(10), math.radians(-30)))
    bpy.context.active_object.data.energy = 3.5
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.6, 0.66, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    bpy.ops.object.camera_add(location=(-1.0, 15.0, 6.5))
    cam = bpy.context.active_object
    aim = bpy.data.objects.new("Aim", None)
    bpy.context.scene.collection.objects.link(aim)
    aim.location = (-1.0, 0.0, 2.6)
    track = cam.constraints.new('TRACK_TO')
    track.target = aim
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    cam.data.lens = 32
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    reset()
    mat = vertex_colour_material("Robot", 0.45, False)
    os.makedirs(OUT_DIR, exist_ok=True)
    tops = [walker(mat), turret(mat), machine(mat)]
    for t in tops:
        export_tree(t, os.path.join(OUT_DIR, t.name + ".glb"))
        print("wrote", t.name)
    if "--preview" in argv:
        preview(tops, argv[argv.index("--preview") + 1])


main()