# tools/generate_triassic.py
# The first map's cast (GAME-DESIGN 7.2, station 1: the Late Triassic, the Chinle Formation),
# on the Quaternius rigs the game already animates (tools/convert_quaternius.py):
#
#   coelophysis   on the velociraptor's: the light three-metre theropod that raids in packs (found by
#                 the hundred together at Ghost Ranch)
#   placerias     on the triceratops': the tusked, beaked dicynodont that grazes in herds on the
#                 valley's far side (7.2: "二齿兽类（如 Placerias），成群")
#   postosuchus   on the tyrannosaur's: not a dinosaur -- a rauisuchian, a land crocodile-line archosaur
#                 four or five metres long, forelimbs long enough to walk on
#   hesperosuchus on the velociraptor's: an early crocodylomorph of the same Chinle rocks (Hesperosuchus
#                 agilis -- "agile"), slender and long-legged, the crocodile's line before it went to the
#                 water (GAME-DESIGN 7.2 station one: the runner, from the third day)
#   phytosaur     on the triceratops': not a crocodile, though it looks like one -- a phytosaur
#                 (Machaeroprosopus, from the same Chinle rocks as Coelophysis), the river's night hunter,
#                 with eyes the game makes shine back a light in the dark (GAME-DESIGN 9.3)
#
# THE SKELETON RESHAPED, THE BODY REDRAWN. Each rig is posed -- bones stretched and slimmed, never
# turned -- and that pose made its rest pose; its bones keep their names and their orientation, so every
# clip the game plays (idle, walk, run, attack, death) plays on it as it did on the animal it came from.
# The source's mesh then goes, and a body is sculpted round those bones (tools/triassic_bodies.py,
# tools/sculpt.py; GAME-DESIGN 7.1, the player 2026-09-30: "恐龙目前模型做的都粗糙，我需要它们更精致").
#
# AND ONE CLIP OF ITS OWN where the source has none: the Coelophysis asleep ("sleep"; the guards at
# the nest sleep at night, GAME-DESIGN 9.3). Lying on its belly, its legs folded under it the way a
# resting bird's are, its neck and head down along the ground, its tail laid round beside it -- still,
# but for a slow breath. Upright and belly-down, not on its side: the death clip lies on its side with
# its legs out, and a sleeping guard must not read as a dead one.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_triassic.py
#   ... -- coelophysis         makes only that one
#   ... -- --preview           also renders each to the scratch directory

import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import vertex_colour_material  # noqa: E402
import triassic_bodies  # noqa: E402

REPO = r"z:\home\zkl-unix\repo\game\dino"
SRC = os.path.join(REPO, "assets", "models", "quaternius")
# TRIASSIC_OUT: somewhere else to write them, to look at before the game gets them.
OUT = os.environ.get("TRIASSIC_OUT", os.path.join(REPO, "assets", "models", "triassic"))
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", os.path.join(os.environ.get("TEMP", "."), "triassic_preview"))

# Per bone: a scale along its own axes in pose (x across, y along the bone, z the third), and
# whether its children keep their own size (a longer neck does not make a bigger head). Each
# animal's body -- its shape, its parts, its colours -- is tools/triassic_bodies.py's ("sculpt").
ANIMALS = {
    "coelophysis": {
        "source": "velociraptor.glb",
        "bones": {
            "Neck": ((0.85, 1.75, 0.85), True),
            "Shoulders": ((0.85, 1.25, 0.9), True),
            "Head": ((0.72, 1.45, 0.72), True),
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
            # The hips and the shoulders drawn in: the velociraptor stood with its feet a leg's width apart,
            # and a theropod walks with them nearly under its middle. Its feet, which hang off the root, are
            # brought in after them (feet_follow).
            "BackLeg.L": ((1.0, 0.62, 1.0), True),
            "BackLeg.R": ((1.0, 0.62, 1.0), True),
            "FrontLeg.L": ((1.0, 0.8, 1.0), True),
            "FrontLeg.R": ((1.0, 0.8, 1.0), True),
        },
        "feet_follow": [("BackFoot.L", "BackLowLeg.L"), ("BackFoot.R", "BackLowLeg.R")],
        "sculpt": "coelophysis",
        # Asleep (add_sleep): the body let down `drop` model units (its hips stand a little over 3),
        # then each bone turned to point along a direction in the armature's space -- forward is -y, up
        # is +z, its left +x -- in this order, parents first; each foot, which hangs off the root, put
        # at the end of its leg on the ground and pointed ahead. The breath: `bone` raised by `degrees`
        # halfway through `frames` and down again, the bones after it on the list kept pointing where
        # they were, so the chest rises and the head stays on the ground.
        "sleep": {
            "drop": 2.2,
            "aim": [
                ("Hips", (0.0, -1.0, -0.05)),
                ("Torso", (0.0, -1.0, -0.02)),
                ("BackUpLeg.L", (0.15, -0.95, -0.15)),
                ("BackUpLeg.R", (-0.15, -0.95, -0.15)),
                ("BackLowLeg.L", (0.05, 0.8, -0.45)),
                ("BackLowLeg.R", (-0.05, 0.8, -0.45)),
                ("Shoulders", (0.0, -0.8, -0.35)),
                ("Neck", (0.12, -0.93, -0.3)),
                ("Head", (0.3, -0.94, 0.1)),
                ("FrontUpLeg.L", (0.2, 0.6, -0.8)),
                ("FrontUpLeg.R", (-0.2, 0.6, -0.8)),
                ("FrontLowLeg.L", (0.1, -0.9, -0.3)),
                ("FrontLowLeg.R", (-0.1, -0.9, -0.3)),
                ("Back", (0.0, 1.0, -0.15)),
                ("Tail1", (0.15, 0.9, -0.45)),
                ("Tail2", (0.35, 0.93, -0.1)),
                ("Tail3", (0.75, 0.65, 0.0)),
                ("Tail4", (0.98, 0.1, 0.0)),
                ("Tail5", (0.75, -0.65, 0.0)),
            ],
            "feet": [("BackFoot.L", "BackLowLeg.L", (0.1, -1.0, 0.0)), ("BackFoot.R", "BackLowLeg.R", (-0.1, -1.0, 0.0))],
            "foot_height": 0.09,
            "breath": {"bone": "Torso", "degrees": 4.0, "frames": 96},
        },
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
        "sculpt": "placerias",
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
            # Its legs under it, as a rauisuchian's were -- pillars, not a sprawl.
            "BackLeg.L": ((1.0, 0.72, 1.0), True),
            "BackLeg.R": ((1.0, 0.72, 1.0), True),
        },
        "feet_follow": [("BackFoot.L", "BackLowLeg.L"), ("BackFoot.R", "BackLowLeg.R")],
        "sculpt": "postosuchus",
    },
    "hesperosuchus": {
        "source": "velociraptor.glb",
        "bones": {
            # The snout: long and narrow and low, a crocodile's -- not a theropod's short deep skull.
            "Head": ((0.52, 1.85, 0.5), True),
            # A short, thick neck carried low.
            "Neck": ((0.85, 0.7, 0.8), True),
            "Shoulders": ((0.8, 1.0, 0.8), True),
            "Torso": ((0.72, 1.12, 0.68), True),
            "Hips": ((0.75, 1.0, 0.72), True),
            # A long tail.
            "Tail1": ((0.7, 1.2, 0.7), True),
            "Tail2": ((0.66, 1.25, 0.66), True),
            "Tail3": ((0.62, 1.25, 0.62), True),
            "Tail4": ((0.6, 1.25, 0.6), True),
            "Tail5": ((0.55, 1.3, 0.55), True),
            # Forelimbs long enough to walk on, as a sphenosuchian's were.
            "FrontUpLeg.L": ((0.8, 1.7, 0.8), True),
            "FrontUpLeg.R": ((0.8, 1.7, 0.8), True),
            "FrontLowLeg.L": ((0.8, 1.6, 0.8), True),
            "FrontLowLeg.R": ((0.8, 1.6, 0.8), True),
            "BackLeg.L": ((1.0, 0.62, 1.0), True),
            "BackLeg.R": ((1.0, 0.62, 1.0), True),
            "FrontLeg.L": ((1.0, 0.8, 1.0), True),
            "FrontLeg.R": ((1.0, 0.8, 1.0), True),
        },
        "feet_follow": [("BackFoot.L", "BackLowLeg.L"), ("BackFoot.R", "BackLowLeg.R")],
        "sculpt": "hesperosuchus",
    },
    "phytosaur": {
        "source": "triceratops.glb",
        "bones": {
            # The snout: long and narrow, flat on top -- a phytosaur's skull is a fifth of it.
            "Head": ((0.5, 2.9, 0.55), True),
            "Neck": ((0.85, 1.25, 0.8), True),
            # A long, low trunk: stretched from end to end and a little flattened.
            "Shoulders": ((0.95, 1.35, 0.8), True),
            "Torso": ((1.15, 2.0, 1.1), True),
            "Hips": ((1.0, 1.5, 0.8), True),
            "Back": ((0.9, 1.3, 0.8), True),
            # A long tail flattened from the sides: what it swims with.
            "Tail1": ((0.75, 1.7, 0.85), True),
            "Tail2": ((0.62, 1.8, 0.85), True),
            "Tail3": ((0.55, 1.9, 0.85), True),
            "Tail4": ((0.5, 1.7, 0.85), True),
            "Tail5": ((0.45, 1.7, 0.85), True),
        },
        "sculpt": "phytosaur",
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


def add_sleep(arm, spec):
    """A clip of its own, "sleep": the pose in `spec` (ANIMALS.<name>.sleep) keyed on every bone -- the
    game plays one clip after another, and a bone this one left unkeyed would keep whatever the last
    clip left it at -- with a slow breath."""
    from mathutils import Vector
    act = bpy.data.actions.new("sleep")
    arm.animation_data_create()
    arm.animation_data.action = act
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'

    def settle():
        bpy.context.view_layer.update()

    def aim(name, direction):
        pb = arm.pose.bones.get(name)
        if pb is None:
            return
        m = pb.matrix.copy()
        cur = (m.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
        turned = (cur.rotation_difference(Vector(direction).normalized()).to_matrix() @ m.to_3x3()).to_4x4()
        turned.translation = m.translation
        pb.matrix = turned
        settle()

    def pose(breath):
        for pb in arm.pose.bones:
            pb.location = (0.0, 0.0, 0.0)
            pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
            pb.scale = (1.0, 1.0, 1.0)
        settle()
        body = arm.pose.bones["Body"]
        m = body.matrix.copy()
        m.translation = m.translation + Vector((0.0, 0.0, -spec["drop"]))
        body.matrix = m
        settle()
        lift = spec["breath"]
        for (name, direction) in spec["aim"]:
            d = Vector(direction)
            if breath and name == lift["bone"]:
                # Its front end up by the breath's angle, about its own side-to-side axis.
                d = d.normalized()
                side = d.cross(Vector((0.0, 0.0, 1.0))).normalized()
                from mathutils import Quaternion
                d = Quaternion(side, math.radians(lift["degrees"])) @ d
            aim(name, d)
        for (foot, leg, direction) in spec["feet"]:
            pb = arm.pose.bones.get(foot)
            if pb is None:
                continue
            ankle = arm.pose.bones[leg].tail.copy()
            m = pb.matrix.copy()
            m.translation = Vector((ankle.x, ankle.y, spec["foot_height"]))
            pb.matrix = m
            settle()
            aim(foot, direction)

    last = spec["breath"]["frames"]
    for (frame, breath) in ((1, False), (last // 2 + 1, True), (last + 1, False)):
        pose(breath)
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("scale", frame=frame)
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.animation_data.action = None
    print("  sleep: %d bones keyed" % len(arm.pose.bones))


def export(arm, mesh, path):
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for m in (mesh if isinstance(mesh, list) else [mesh]):
        m.select_set(True)
    bpy.context.view_layer.objects.active = arm
    # Every surface's colours (the eyes' too): left to the materials, only the skin's went, and the eyes came
    # out white.
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_anim_single_armature=True,
                              export_vertex_color='ACTIVE')


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


def feet_follow(arm, pairs):
    """Each foot that hangs off the root brought to where its leg now ends -- the hips drawn in -- along the
    ground, its own bones after it. Moved, not turned: its clips move it from where it rests."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for (foot, leg) in pairs:
        eb = arm.data.edit_bones.get(foot)
        lb = arm.data.edit_bones.get(leg)
        if eb is None or lb is None:
            continue
        delta = lb.tail - eb.head
        delta.z = 0.0
        moved = [eb] + list(eb.children_recursive)
        was = [(b.head.copy(), b.tail.copy()) for b in moved]
        for b, (h, t) in zip(moved, was):
            b.head = h + delta
            b.tail = t + delta
    bpy.ops.object.mode_set(mode='OBJECT')


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
        if spec.get("feet_follow"):
            feet_follow(arm, spec["feet_follow"])
        # Drawn anew round its bones (tools/triassic_bodies.py): the source's own mesh goes.
        mats = [vertex_colour_material("Skin", 0.72, False), vertex_colour_material("Eye", 0.3, False)]
        parts = triassic_bodies.build(spec["sculpt"], arm, mats)
        bpy.data.objects.remove(mesh)
        mesh = parts
        if spec.get("sleep"):
            add_sleep(arm, spec["sleep"])
        path = os.path.join(OUT, name + ".glb")
        export(arm, mesh, path)
        meshes = mesh if isinstance(mesh, list) else [mesh]
        print("[OK] %s: %d verts, %.2f x %.2f x %.2f, clips %s" % (
            name, sum(len(m.data.vertices) for m in meshes), *meshes[0].dimensions, [a.name for a in bpy.data.actions]))
        if "--preview" in args:
            preview(name, arm, meshes[0])


if __name__ == "__main__":
    main()
