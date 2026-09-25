# tools/build_hero.py
# The Hero: a man of ordinary build, put together from Quaternius's CC0 character kits.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/build_hero.py
#
# Reported as "人不应该带个安全帽，显得太卡通了，应该就是写实风格的人物形象": the worker in a
# yellow hard hat, from the Ultimate Animated Character Pack, is built to cartoon
# proportions -- a big head on a short body -- and taking the hat off would not change that.
# Quaternius's newer kits are built to real proportions on one humanoid rig:
#
#   Modular Character Outfits - Fantasy   Male_Peasant: the Regular male body in a plain
#                                         shirt, trousers and shoes -- but with no head
#   Universal Base Characters             Superhero_Male_FullBody: the only body in the free
#                                         kit with a head; its head, eyes and brows are taken
#   (same kit)                            Hair_SimpleParted, rigged to the head bone
#   Universal Animation Library           the clips, made on the same rig
#
# All three kits put the spine, neck and head bones in exactly the same places (measured),
# so the head sits on the Regular body where it grew, and its neck ends inside the collar.
#
# The files used are in assets/source/quaternius/ubc/, their textures cut from 4096 to 1024
# pixels to keep the repository small: the figure is little more than a metre tall on the
# screen. The originals are the free Standard downloads of the three kits on
# quaternius.itch.io (CC0; see assets/CREDITS.md).
#
# Godot extracts the model's textures next to it, as hero_T_*.jpg. Their .import files are
# committed set the way the editor settles a 3D texture once it has seen it drawn -- VRAM
# compressed, the normal maps marked as normal maps, each roughness map limited by its
# material's normal map -- so the editor has nothing left to rewrite, and a rebuild keeps
# them (the importer only fills in settings a file does not have). Imported lossless, as
# they first came out, every load decoded all of them.

import bpy
import hashlib
import os

REPO = r"z:\home\zkl-unix\repo\game\dino"
SRC = os.path.join(REPO, "assets", "source", "quaternius", "ubc")
OUT = os.path.join(REPO, "assets", "models", "quaternius", "hero.glb")

BODY = "Male_Peasant.gltf"
HEAD_FROM = "Superhero_Male_FullBody.gltf"
HAIR = "Hair_SimpleParted.gltf"
CLIPS_FROM = "UAL1_Standard.glb"

# The library's clips the game plays, under the names it asks for (Config.ANIMATIONS.hero).
CLIPS = {
    "Idle_Loop": "idle",
    "Walk_Loop": "walk",
    "Jog_Fwd_Loop": "run",
    "Punch_Jab": "attack",
    "Fixing_Kneeling": "build",      # down on one knee, working at the thing in front of him
    "Interact": "harvest",
    "Death01": "death",
    "Hit_Chest": "hit",
}

# The shirt and trousers came dyed for a fantasy village. Outdoor colours instead, laid over
# the texture as a multiply on each named material (linear RGB): a man a long way from home,
# not a peasant. None of it is the Hero's own design -- change the numbers to taste.
TINT = {
    "MI_Peasant": (0.78, 0.80, 0.70),
    # The kit's hair is grey, meant to be dyed by a shader only its paid version has.
    "MI_Hair_1": (0.16, 0.11, 0.07),
}

TEXTURE_SIZE = 1024


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_gltf(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name))
    return [o for o in bpy.data.objects if o not in before]


def armature_of(objs):
    return next(o for o in objs if o.type == "ARMATURE")


def drop(objs):
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def keep_head(mesh):
    """Keep only what hangs from the neck and head bones: the head, face and neck."""
    groups = {g.index: g.name for g in mesh.vertex_groups}
    keep = {"Head", "neck_01"}
    doomed = []
    for v in mesh.data.vertices:
        best, weight = None, 0.0
        for g in v.groups:
            if g.weight > weight:
                best, weight = groups.get(g.group), g.weight
        if best not in keep:
            doomed.append(v.index)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for i in doomed:
        mesh.data.vertices[i].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")


def rehome(mesh, arm):
    """Onto the body's skeleton: same bone names, so the weights carry straight over."""
    world = mesh.matrix_world.copy()
    mesh.parent = arm
    mesh.matrix_world = world
    for m in mesh.modifiers:
        if m.type == "ARMATURE":
            m.object = arm


def dedupe_images():
    """One copy of each picture: the brows and the hair bring the same normal map under two
    names, and every image is one more texture for the game to load."""
    by_content = {}
    for img in bpy.data.images:
        if img.packed_file is not None:
            data = img.packed_file.data
        else:
            path = bpy.path.abspath(img.filepath)
            if not os.path.isfile(path):
                continue
            with open(path, "rb") as f:
                data = f.read()
        by_content.setdefault(hashlib.md5(data).hexdigest(), []).append(img)
    for same in by_content.values():
        keep = min(same, key=lambda i: (len(i.name), i.name))
        for img in same:
            if img is not keep:
                img.user_remap(keep)
                bpy.data.images.remove(img)


def main():
    reset()
    body = import_gltf(BODY)
    arm = armature_of(body)
    arm.name = "Hero"
    drop([o for o in body if o.type == "MESH" and o.parent is None])       # a stray icosphere

    head_objs = import_gltf(HEAD_FROM)
    for o in head_objs:
        if o.type != "MESH" or o.parent is None:
            continue
        if o.name.startswith("SuperHero"):
            keep_head(o)
            # Not "Head": that is the head BONE's name, and the importer makes names unique
            # across the scene -- the bone came through as "Head_2".
            o.name = "Face"
        rehome(o, arm)
    drop([o for o in head_objs if o.type == "ARMATURE" or (o.type == "MESH" and o.parent is None)])

    hair_objs = import_gltf(HAIR)
    for o in hair_objs:
        if o.type == "MESH" and o.parent is not None:
            rehome(o, arm)
    drop([o for o in hair_objs if o.type == "ARMATURE" or (o.type == "MESH" and o.parent is None)])

    # The clips: the library's armature brings every one of them in; the ones the game uses
    # are renamed, the rest discarded, and the library's own mannequin goes.
    before = set(bpy.data.actions)
    lib = import_gltf(CLIPS_FROM)
    drop(lib)
    for act in [a for a in bpy.data.actions if a not in before]:
        name = CLIPS.get(act.name)
        if name is None:
            bpy.data.actions.remove(act)
        else:
            act.name = name
            act.use_fake_user = True
    # Animation data, but none of the clips left active: the exporter's ACTIONS mode skips an
    # armature with no animation data at all, and dropped whichever clip was active -- it was
    # the idle, so he stood in his T-pose.
    arm.animation_data_create()
    arm.animation_data.action = None

    for mat in bpy.data.materials:
        # By the name before any ".001": the brows and the hair each bring a MI_Hair_1, and
        # Blender renames the second.
        base = mat.name.split(".")[0]
        if base in TINT and mat.node_tree is not None:
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            tint = TINT[base]
            link = bsdf.inputs["Base Color"].links[0] if bsdf.inputs["Base Color"].links else None
            if link is not None:
                mul = mat.node_tree.nodes.new("ShaderNodeMix")
                mul.data_type = "RGBA"
                mul.blend_type = "MULTIPLY"
                mul.inputs["Factor"].default_value = 1.0
                mat.node_tree.links.new(link.from_socket, mul.inputs["A"])
                mul.inputs["B"].default_value = (tint[0], tint[1], tint[2], 1.0)
                mat.node_tree.links.new(mul.outputs["Result"], bsdf.inputs["Base Color"])

    dedupe_images()
    for img in bpy.data.images:
        if img.size[0] > TEXTURE_SIZE:
            img.scale(TEXTURE_SIZE, TEXTURE_SIZE)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_image_format="JPEG", export_image_quality=88)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print("[OK] hero.glb: %d meshes, %d triangles, %d images, clips %s" % (
        len(meshes), tris, len(bpy.data.images), sorted(a.name for a in bpy.data.actions)))


main()
