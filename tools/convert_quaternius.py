# tools/convert_quaternius.py
# The Quaternius CC0 models in assets/source/quaternius/ turned into the GLBs the game
# loads, in assets/models/quaternius/. Downloaded 2026-09-23 with the user's permission
# from the Google Drive folders the packs' pages on quaternius.com link to; the packs,
# files and licence are recorded in assets/CREDITS.md.
#
# What changes on the way through, and why:
#
#   * TURNED to face the game's -Z (Blender +Y). Every one of them faces the other way,
#     and everything in the game turns with look_at, which points -Z at the target: a
#     raptor imported as it comes would chase the Hero backwards.
#   * CLIPS RENAMED to the names Config.ANIMATIONS asks for -- idle, walk, run, attack,
#     death -- and the ones nothing plays dropped, so each file carries only what the game
#     uses. The worker's clips are mapped onto what the Hero does: a punch to attack, a
#     sword swing to chop a tree, picking something up off the ground to build.
#   * MATTE. The packs' materials have a plastic sheen, and nothing else in the valley
#     shines.
#   * STRAYS OUT. The worker file carries an unparented icosphere that is not part of him.
#
# Looping is not decided here: which clips loop is an import setting of the GLB in Godot
# (see the .glb.import files), the engine's own place for it.
#
#   blender --background --python tools/convert_quaternius.py

import bpy
import math
import os

REPO = r"z:\home\zkl-unix\repo\game\dino"
SRC = os.path.join(REPO, "assets", "source", "quaternius")
OUT = os.path.join(REPO, "assets", "models", "quaternius")

DINO_CLIPS = {"Idle": "idle", "Walk": "walk", "Run": "run", "Attack": "attack", "Death": "death", "Jump": "jump"}
HERO_CLIPS = {"Idle": "idle", "Walk": "walk", "Run": "run", "Punch": "attack", "SwordSlash": "harvest",
              "PickUp": "build", "Death": "death"}

# Colours set on the way through, by model and material, in linear RGB.
#
# The worker's skin is authored at 0.013 -- as near black as makes no difference, with a
# white "Face" material for the eyes. In the valley's light that drew a featureless black
# head with two white eyes, a caricature, and not a face anyone could read from the game's
# camera. A warm mid tone keeps his features.
RECOLOUR = {
    "worker": {"Skin": (0.30, 0.16, 0.09)},
}

MODELS = {
    "trex": ("Trex.fbx", DINO_CLIPS),
    "velociraptor": ("Velociraptor.fbx", DINO_CLIPS),
    "apatosaurus": ("Apatosaurus.fbx", DINO_CLIPS),
    "parasaurolophus": ("Parasaurolophus.fbx", DINO_CLIPS),
    "stegosaurus": ("Stegosaurus.fbx", DINO_CLIPS),
    "triceratops": ("Triceratops.fbx", DINO_CLIPS),
    "worker": ("Worker_Male.gltf", HERO_CLIPS),
}


def clip_name(action_name, mapping):
    """'Armature|Armature|TRex_Run' -> 'run'; 'SwordSlash' -> 'harvest'; unused -> None."""
    last = action_name.split("|")[-1]
    if last in mapping:
        return mapping[last]
    if "_" in last:
        tail = last.split("_", 1)[1]           # the dinosaurs prefix every clip with their name
        if tail in mapping:
            return mapping[tail]
    return None


OBJECT_CHANNELS = ("location", "rotation_euler", "rotation_quaternion", "rotation_axis_angle", "scale")


def channel_sets(action):
    """Where an action keeps its F-curves: the layered API Blender 4.4+ gives actions,
    or the action itself before that."""
    bags = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            bags.extend(strip.channelbags)
    return bags if bags else [action]


def settle_the_rig(arm, meshes):
    """Every model the same way round and the same way up: the rig's own transform is
    one turn and nothing else, and each mesh's data sits in the rig's space.

    Why each step, all found by exporting and reading the file back:

      * The FBX clips key the RIG OBJECT's own location, rotation and scale on every frame
        -- scale 3, rotation none, for the T-Rex. Those keys overrode anything set on the
        object at export, and in the game every clip would have snapped the model back to
        three times its size, facing backwards, the moment it played. Out.
      * Each mesh carries a transform relative to its rig (x1/3 on the T-Rex, x3.5 on the
        raptor), and a skinned mesh is drawn from its bones while Godot works out its box
        from its data and its node. Left in, the T-Rex was boxed at 93 m around a 30 m
        animal, and VisualLibrary fits every model by its box. Baked into the vertices,
        the data is in the rig's space and the box is what is drawn.
      * The rig itself then goes to scale 1 and turns round, and is NOT applied: applying
        a scale to a rig re-bases its bones, and the exporter wrote the mesh three times
        too big again. Unapplied, the bones and every key in every clip stay exactly as
        authored; the whole animal is simply smaller, which the game's fit undoes.
    """
    for a in bpy.data.actions:
        for bag in channel_sets(a):
            for fc in list(bag.fcurves):
                if fc.data_path in OBJECT_CHANNELS:
                    bag.fcurves.remove(fc)
    for m in meshes:
        bpy.ops.object.select_all(action='DESELECT')
        m.select_set(True)
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    arm.location = (0.0, 0.0, 0.0)
    arm.scale = (1.0, 1.0, 1.0)
    arm.rotation_mode = 'XYZ'
    arm.rotation_euler = (0.0, 0.0, math.pi)     # every one of them faces -Y
    bpy.context.view_layer.update()


def export(objs, arm, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True, export_animations=True,
                  export_apply=False)
    try:
        bpy.ops.export_scene.gltf(export_animation_mode='ACTIONS', export_anim_single_armature=True,
                                  export_force_sampling=True, **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def convert(name, src, mapping):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = os.path.join(SRC, src)
    if src.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)

    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    keep = [arm] + [o for o in bpy.data.objects if o.parent == arm]
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)

    for a in list(bpy.data.actions):
        new = clip_name(a.name, mapping)
        if new is None:
            bpy.data.actions.remove(a)
        else:
            a.name = new
            a.use_fake_user = True
    have = {a.name for a in bpy.data.actions}
    missing = set(mapping.values()) - have
    assert not missing, "%s is missing clips %s" % (name, sorted(missing))

    for m in bpy.data.materials:
        if m.use_nodes:
            b = m.node_tree.nodes.get("Principled BSDF")
            if b:
                b.inputs["Roughness"].default_value = 0.9
                b.inputs["Metallic"].default_value = 0.0
                # OPAQUE. The FBX materials come in with an alpha of 0 -- the files' opacity
                # read the wrong way round -- and exported as alpha-masked at 0, every
                # pixel of every dinosaur was cut away: the raptor and the T-Rex were in
                # the game, skinned and animating, and completely invisible.
                b.inputs["Alpha"].default_value = 1.0
                c = b.inputs["Base Color"].default_value
                b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
                if hasattr(m, "surface_render_method"):
                    m.surface_render_method = 'DITHERED'
                if hasattr(m, "blend_method"):
                    m.blend_method = 'OPAQUE'
                recolour = RECOLOUR.get(name, {}).get(m.name)
                if recolour is not None:
                    b.inputs["Base Color"].default_value = (recolour[0], recolour[1], recolour[2], 1.0)

    settle_the_rig(arm, [o for o in keep if o.type == 'MESH'])
    if arm.animation_data:
        arm.animation_data.action = None        # export the rest pose, not a frame of a clip

    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, name + ".glb")
    export(keep, arm, out)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in keep if o.type == 'MESH')
    print("[OK] %-16s %5d triangles  clips %s" % (name, tris, sorted(have)))


def main():
    for name, (src, mapping) in MODELS.items():
        convert(name, src, mapping)


if __name__ == "__main__":
    main()
