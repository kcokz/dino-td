# tools/generate_triassic.py
# The first map's cast (GAME-DESIGN 7.2, station 1: the Late Triassic, the Chinle Formation),
# made from the Quaternius rigs the game already animates (tools/convert_quaternius.py):
#
#   coelophysis   from the velociraptor: a long S of a neck, a long narrow snout, a slighter
#                 body and a longer tail, sand-ochre with a pale belly -- the light three-metre
#                 theropod that raids in packs (found by the hundred together at Ghost Ranch)
#   placerias     from the triceratops: its frill and horns cut away, a short beaked head, a
#                 short tail and a barrel of a body -- the dicynodont that grazes in
#                 herds on the valley's far side (7.2: "二齿兽类（如 Placerias），成群")
#   postosuchus   from the tyrannosaur: not a dinosaur -- a rauisuchian, a land crocodile-line
#                 archosaur four or five metres long: a deep, narrow skull, a longer body and
#                 tail, forelimbs long enough to walk on, and rows of bony scutes down its back,
#                 dark olive and umber
#
# RESHAPED, NOT REDRAWN. Each is posed -- bones stretched and slimmed, never turned -- the pose
# baked into its mesh, and that pose made the rest pose. Its bones keep their names and their
# orientation, so every clip the game plays (idle, walk, run, attack, death) plays on it as it
# did on the animal it came from.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_triassic.py
#   ... -- coelophysis         makes only that one
#   ... -- --preview           also renders each to the scratch directory

import bpy
import math
import os
import sys

REPO = r"z:\home\zkl-unix\repo\game\dino"
SRC = os.path.join(REPO, "assets", "models", "quaternius")
OUT = os.path.join(REPO, "assets", "models", "triassic")
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", os.path.join(os.environ.get("TEMP", "."), "triassic_preview"))

# Per bone: a scale along its own axes in pose (x across, y along the bone, z the third), and
# whether its children keep their own size (a longer neck does not make a bigger head).
# Colours are linear RGB, by the source model's material names.
ANIMALS = {
    "coelophysis": {
        "source": "velociraptor.glb",
        "bones": {
            "Neck": ((0.85, 2.1, 0.85), True),
            "Shoulders": ((0.85, 1.25, 0.9), True),
            "Head": ((0.72, 1.35, 0.72), True),
            "Torso": ((0.82, 1.08, 0.85), True),
            "Hips": ((0.85, 1.0, 0.9), True),
            "Tail1": ((0.85, 1.12, 0.85), True),
            "Tail2": ((0.82, 1.15, 0.82), True),
            "Tail3": ((0.8, 1.15, 0.8), True),
            "Tail4": ((0.8, 1.15, 0.8), True),
            "Tail5": ((0.8, 1.2, 0.8), True),
            "BackUpLeg.L": ((0.8, 1.0, 0.8), True),
            "BackUpLeg.R": ((0.8, 1.0, 0.8), True),
            "FrontUpLeg.L": ((0.8, 0.9, 0.8), True),
            "FrontUpLeg.R": ((0.8, 0.9, 0.8), True),
        },
        "colours": {
            "Brown": (0.30, 0.17, 0.055),        # sand-ochre back
            "LightBrown": (0.52, 0.40, 0.24),    # a pale belly and throat
            "Black": (0.012, 0.010, 0.008),
        },
        "scutes": None,
    },
    "placerias": {
        "source": "triceratops.glb",
        "bones": {
            "Head": ((0.9, 0.62, 0.95), True),
            "Neck": ((1.1, 0.55, 1.05), True),
            "Torso": ((1.18, 1.0, 1.12), True),
            "Shoulders": ((1.15, 0.95, 1.1), True),
            "Hips": ((1.15, 1.0, 1.1), True),
            "Tail1": ((0.9, 0.55, 0.9), True),
            "Tail2": ((0.8, 0.5, 0.8), True),
            "Tail3": ((0.7, 0.45, 0.7), True),
            "Tail4": ((0.6, 0.45, 0.6), True),
            "Tail5": ((0.5, 0.45, 0.5), True),
        },
        "colours": {
            "Purple": (0.16, 0.11, 0.07),        # a dun, pig-like hide
            "LightBrown": (0.30, 0.24, 0.16),
            "Brown": (0.12, 0.08, 0.05),
        },
        # The frill and the horns: what is weighted to the head or the neck and stands up off the
        # line of them. (Its tusks are a few centimetres at the distance a herd is seen from.)
        "cut": {"bones": ["Head", "Neck"], "above": 0.4},
        "scutes": None,
    },
    "postosuchus": {
        "source": "trex.glb",
        "bones": {
            "Head": ((0.7, 1.3, 1.1), True),
            "Neck": ((0.9, 1.15, 1.0), True),
            "Torso": ((0.9, 1.5, 0.95), True),
            "Hips": ((0.95, 1.2, 0.95), True),
            "Tail1": ((0.9, 1.25, 0.9), True),
            "Tail2": ((0.85, 1.3, 0.85), True),
            "Tail3": ((0.8, 1.3, 0.8), True),
            "Tail4": ((0.8, 1.3, 0.8), True),
            "Tail5": ((0.8, 1.35, 0.8), True),
            # Forelimbs long and strong enough to walk on: not a tyrannosaur's.
            "FrontUpLeg.L": ((2.0, 2.6, 2.0), True),
            "FrontUpLeg.R": ((2.0, 2.6, 2.0), True),
            "FrontLowLeg.L": ((1.8, 2.5, 1.8), True),
            "FrontLowLeg.R": ((1.8, 2.5, 1.8), True),
            "FrontFoot.L": ((1.8, 1.5, 1.8), True),
            "FrontFoot.R": ((1.8, 1.5, 1.8), True),
        },
        "colours": {
            "Green": (0.075, 0.052, 0.030),      # dark umber back
            "LightGreen": (0.24, 0.19, 0.11),    # a dun belly
            "LightYellow": (0.55, 0.36, 0.10),   # its eye
            "Red": (0.30, 0.05, 0.05),           # its mouth
            "Black": (0.012, 0.010, 0.008),
        },
        # Rows of bony plates down its back, as in its fossils: (bone, how far along it, size).
        "scutes": {
            "colour": (0.035, 0.030, 0.020),
            "rows": [("Neck", 0.5, 0.22), ("Shoulders", 0.5, 0.26), ("Torso", 0.1, 0.28), ("Torso", 0.35, 0.3),
                     ("Torso", 0.6, 0.3), ("Torso", 0.85, 0.3), ("Hips", 0.5, 0.28), ("Back", 0.5, 0.26),
                     ("Tail1", 0.3, 0.24), ("Tail1", 0.8, 0.22), ("Tail2", 0.4, 0.19), ("Tail2", 0.9, 0.17),
                     ("Tail3", 0.5, 0.14), ("Tail4", 0.5, 0.11)],
            "spread": 0.16,              # each row is a pair, this far either side of the spine
        },
    },
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_source(name):
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == arm)
    for o in list(bpy.data.objects):
        if o not in (arm, mesh) and o.type == 'MESH' and o.parent is None:
            bpy.data.objects.remove(o)           # the importer's stray bone-shape sphere
    return arm, mesh


def reshape(arm, mesh, bones):
    """Poses the stretch into the bones, bakes it into the mesh, and makes it the rest."""
    arm.animation_data_create()
    arm.animation_data.action = None
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    keep = {}
    for name, (_, own) in bones.items():
        eb = arm.data.edit_bones.get(name)
        if eb is None:
            continue
        for child in eb.children:
            keep[child.name] = child.inherit_scale
            if own:
                child.inherit_scale = 'NONE'
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    for name, (scale, _) in bones.items():
        pb = arm.pose.bones.get(name)
        if pb is not None:
            pb.scale = scale
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode='OBJECT')
    # The pose into the mesh...
    mod = next(m for m in mesh.modifiers if m.type == 'ARMATURE')
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # ...and the pose as the rest.
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, mode in keep.items():
        eb = arm.data.edit_bones.get(name)
        if eb is not None:
            eb.inherit_scale = mode
    bpy.ops.object.mode_set(mode='OBJECT')
    m = mesh.modifiers.new("Armature", 'ARMATURE')
    m.object = arm


def recolour(mesh, colours):
    for mat in mesh.data.materials:
        if mat is None or mat.name not in colours or not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            c = colours[mat.name]
            bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)


def add_scutes(arm, mesh, spec):
    """Low pyramids down the back in pairs, each weighted wholly to the bone it rides on."""
    mat = bpy.data.materials.new("Scute")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*spec["colour"], 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    mesh.data.materials.append(mat)
    slot = len(mesh.data.materials) - 1
    to_mesh = mesh.matrix_world.inverted() @ arm.matrix_world
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    deform = bm.verts.layers.deform.verify()
    top_of = _top_along(mesh)
    for (bone_name, t, size) in spec["rows"]:
        bone = arm.data.bones.get(bone_name)
        if bone is None:
            continue
        group = mesh.vertex_groups.get(bone_name) or mesh.vertex_groups.new(name=bone_name)
        at = to_mesh @ bone.head_local.lerp(bone.tail_local, t)
        for side in (-1.0, 1.0):
            base = at.copy()
            base.x += side * spec["spread"]
            base.z = top_of(base) - size * 0.1
            half = size * 0.5
            corners = [bm.verts.new((base.x + dx * half, base.y + dy * half * 1.3, base.z))
                       for (dx, dy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            tip = bm.verts.new((base.x + side * half * 0.15, base.y + half * 0.4, base.z + size * 0.5))
            for v in corners + [tip]:
                v[deform][group.index] = 1.0
            for k in range(4):
                f = bm.faces.new((corners[k], corners[(k + 1) % 4], tip))
                f.material_index = slot
    bm.normal_update()
    bm.to_mesh(mesh.data)
    bm.free()


def _top_along(mesh):
    """The top of the mesh near a point (x, y), in mesh space: where a scute sits."""
    verts = [v.co.copy() for v in mesh.data.vertices]

    def top(p):
        best = None
        for v in verts:
            if abs(v.y - p.y) < 0.35 and abs(v.x - p.x) < 0.35:
                best = v.z if best is None else max(best, v.z)
        return best if best is not None else p.z
    return top


def cut_off(arm, mesh, spec):
    """Deletes what is weighted mostly to `bones` and stands `above` (model units) over the line
    they make -- a frill, a horn -- and closes the holes it leaves."""
    import bmesh
    to_mesh = mesh.matrix_world.inverted() @ arm.matrix_world
    line = []
    for name in spec["bones"]:
        bone = arm.data.bones[name]
        line.append((to_mesh @ bone.head_local, to_mesh @ bone.tail_local))
    groups = [mesh.vertex_groups[n].index for n in spec["bones"]]
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    deform = bm.verts.layers.deform.verify()

    def line_z(y):
        best = None
        for (h, t) in line:
            lo, hi = min(h.y, t.y), max(h.y, t.y)
            k = (y - t.y) / (h.y - t.y) if abs(h.y - t.y) > 1e-4 else 0.0
            z = t.z + (h.z - t.z) * max(0.0, min(1.0, k))
            if lo - 0.5 <= y <= hi + 0.5:
                best = z if best is None else max(best, z)
        return best

    doomed = []
    for v in bm.verts:
        if sum(v[deform].get(g, 0.0) for g in groups) < 0.5:
            continue
        z = line_z(v.co.y)
        if z is not None and v.co.z - z > spec["above"]:
            doomed.append(v)
    bmesh.ops.delete(bm, geom=doomed, context='VERTS')
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(mesh.data)
    bm.free()
    print("  cut %d vertices" % len(doomed))


def export(arm, mesh, path):
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_anim_single_armature=True)


def preview(name, arm, mesh):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    lo = [min(v[i] for v in (mesh.matrix_world @ p.co for p in mesh.data.vertices)) for i in range(3)]
    hi = [max(v[i] for v in (mesh.matrix_world @ p.co for p in mesh.data.vertices)) for i in range(3)]
    mid = [(a + b) * 0.5 for a, b in zip(lo, hi)]
    size = max(h - l for h, l in zip(hi, lo))
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.38, 0.33, 1.0)
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(50), 0.0, math.radians(30)))
    bpy.context.active_object.data.energy = 3.5
    bpy.ops.object.camera_add(location=(mid[0] + size * 1.5, mid[1] - size * 0.35, mid[2] + size * 0.4))
    cam = bpy.context.active_object
    bpy.ops.object.empty_add(location=mid)
    aim = bpy.context.active_object
    c = cam.constraints.new('TRACK_TO')
    c.target, c.track_axis, c.up_axis = aim, 'TRACK_NEGATIVE_Z', 'UP_Y'
    scene.camera = cam
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(PREVIEW_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("[OK] preview", scene.render.filepath)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in args if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    for name, spec in ANIMALS.items():
        if only and name not in only:
            continue
        reset()
        arm, mesh = import_source(spec["source"])
        reshape(arm, mesh, spec["bones"])
        recolour(mesh, spec["colours"])
        if spec.get("cut"):
            cut_off(arm, mesh, spec["cut"])
        if spec["scutes"]:
            add_scutes(arm, mesh, spec["scutes"])
        path = os.path.join(OUT, name + ".glb")
        export(arm, mesh, path)
        print("[OK] %s: %d verts, %.2f x %.2f x %.2f, clips %s" % (
            name, len(mesh.data.vertices), *mesh.dimensions, [a.name for a in bpy.data.actions]))
        if "--preview" in args:
            preview(name, arm, mesh)


if __name__ == "__main__":
    main()
