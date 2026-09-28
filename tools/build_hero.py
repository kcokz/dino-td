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
import math
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

# Colours laid over a material's texture as a multiply (linear RGB). The kit's hair is grey,
# meant to be dyed by a shader only its paid version has. (The clothes are the suit's now: see
# THE SUIT below.)
TINT = {
    "MI_Hair_1": (0.16, 0.11, 0.07),
}

TEXTURE_SIZE = 1024

# THE SUIT (v0.6: "人物要有未来感，不能是现代人……带个宇航服之类的防护服"). The crew module he lives in
# is the ship that brought him, so he wears its crew's suit, in its colours -- the white and the
# orange of the cabin's hull: his clothes re-dyed as a white suit (their folds kept), his boots
# and gloves dark, his bare forearms sleeved; and on him the suit's hard parts, each riding one
# bone as a rigid piece does -- a ring at his neck where a helmet locks on, a life-support pack
# on his back, a unit on his chest with its screen lit the ship's cyan, bands of the ship's
# orange round his arms, cuffs at his wrists and ankles. His face stays bare: a portrait of a
# helmet is a portrait of nobody. Colours linear RGB, lengths metres on the kit's 1.8 m figure.
SUIT_LIGHT = (0.84, 0.85, 0.87)   # the suit's white, where its cloth faces the light
SUIT_DARK = (0.36, 0.38, 0.42)    # and deep in its folds
DARKEN = (0.2, 0.21, 0.23)        # boots and gloves: the suit dyed this dark
ORANGE = (0.9, 0.3, 0.05)         # the ship's orange, the cabin's stripe
METAL = (0.5, 0.53, 0.57)         # the neck ring, the cuffs
PACK = (0.72, 0.73, 0.75)         # the life-support pack's shell
GREY = (0.16, 0.17, 0.19)         # the chest unit, the pack's panel
SCREEN = (0.25, 0.85, 1.0)        # the chest unit's lit screen: the ship's cyan
HANDS = ("hand_", "index_", "middle_", "ring_", "pinky_", "thumb_")


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


def recolor(image, name, light, dark):
    """`image` as the suit's cloth: its colour taken away and its light and shade kept, laid
    between `dark` (its deepest folds) and `light` (where it faces the light)."""
    import numpy as np
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
    lum = px[:, :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    lo, hi = np.percentile(lum, 4), np.percentile(lum, 96)
    t = np.clip((lum - lo) / max(hi - lo, 1e-4), 0.0, 1.0)[:, None]
    rgb = np.array(dark, dtype=np.float32) + (np.array(light, dtype=np.float32) - np.array(dark, dtype=np.float32)) * t
    out = bpy.data.images.new(name, w, h, alpha=True)
    out.colorspace_settings.name = image.colorspace_settings.name
    out.pixels.foreach_set(np.concatenate([rgb, px[:, 3:4]], axis=1).ravel())
    out.pack()
    return out


def base_image(mat):
    """The picture a material's Base Color is read from."""
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = bsdf.inputs["Base Color"].links[0]
    node = link.from_node
    while node.type != "TEX_IMAGE":
        node = next(i.links[0].from_node for i in node.inputs if i.links)
    return node


def dyed(mat, name, image, darken=None):
    """A copy of `mat` reading its colour from `image` instead -- its normal and roughness
    kept -- darkened by `darken` (a multiply) if given."""
    out = mat.copy()
    out.name = name
    node = base_image(out)
    node.image = image
    if darken is not None:
        bsdf = next(n for n in out.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        link = bsdf.inputs["Base Color"].links[0]
        mul = out.node_tree.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        out.node_tree.links.new(link.from_socket, mul.inputs["A"])
        mul.inputs["B"].default_value = (darken[0], darken[1], darken[2], 1.0)
        out.node_tree.links.new(mul.outputs["Result"], bsdf.inputs["Base Color"])
    return out


def plain(name, colour, metallic=0.0, roughness=0.6, glow=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (colour[0], colour[1], colour[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if glow is not None:
        bsdf.inputs["Emission Color"].default_value = (glow[0], glow[1], glow[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    return mat


def dominant_bone(mesh, poly):
    groups = {g.index: g.name for g in mesh.vertex_groups}
    totals = {}
    for vi in poly.vertices:
        for g in mesh.data.vertices[vi].groups:
            name = groups.get(g.group)
            totals[name] = totals.get(name, 0.0) + g.weight
    return max(totals, key=totals.get) if totals else ""


def rigid(obj, arm, bone, mat):
    """A hard part riding `bone` whole: every vertex weighted to it, and to nothing else."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.matrix_world = world
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def bevelled(obj, width, segments=2):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def box(name, size, at):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def ring(name, major, minor, at, axis="Z", tilt=0.0):
    rot = {"Z": (math.radians(tilt), 0.0, 0.0), "X": (0.0, math.radians(90.0), 0.0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32,
                                     minor_segments=10, location=at, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def cylinder(name, radius, depth, at):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=at)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def suit(arm):
    """The crew's suit (see THE SUIT above): the clothes and bare arms dyed, the hard parts on."""
    meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    cloth = bpy.data.materials["MI_Peasant"]
    skin = bpy.data.materials["MI_Regular_Male"]
    cloth_img = recolor(base_image(cloth).image, "T_Suit", SUIT_LIGHT, SUIT_DARK)
    sleeve_img = recolor(base_image(skin).image, "T_Suit_Sleeve", SUIT_LIGHT, SUIT_DARK)
    suit_mat = dyed(cloth, "MI_Suit", cloth_img)
    boots_mat = dyed(cloth, "MI_Suit_Boots", cloth_img, DARKEN)
    sleeve_mat = dyed(skin, "MI_Suit_Sleeve", sleeve_img)
    glove_mat = dyed(skin, "MI_Suit_Gloves", sleeve_img, DARKEN)
    for name, obj in meshes.items():
        if not name.startswith("Male_Peasant"):
            continue
        slots = obj.data.materials
        for i, m in enumerate(slots):
            if m is None:
                continue
            base = m.name.split(".")[0]
            if base == "MI_Peasant":
                slots[i] = boots_mat if name.endswith("_Feet") else suit_mat
            elif base == "MI_Regular_Male":
                slots[i] = sleeve_mat
        if name.endswith("_Arms"):
            # The bare forearms become the suit's sleeves; the hands, its gloves.
            slots.append(glove_mat)
            glove_at = len(slots) - 1
            for poly in obj.data.polygons:
                if slots[poly.material_index] is sleeve_mat and dominant_bone(obj, poly).startswith(HANDS):
                    poly.material_index = glove_at

    orange = plain("MI_Suit_Orange", ORANGE, roughness=0.5)
    metal = plain("MI_Suit_Metal", METAL, metallic=0.7, roughness=0.35)
    shell = plain("MI_Suit_Pack", PACK, roughness=0.45)
    grey = plain("MI_Suit_Grey", GREY, metallic=0.3, roughness=0.5)
    screen = plain("MI_Suit_Screen", (0.05, 0.2, 0.25), roughness=0.3, glow=SCREEN)

    # The neck ring a helmet locks onto, the ship's orange along its top: on the chest bone, so
    # it stays with his shoulders when he turns his head.
    rigid(ring("Suit_NeckRing", 0.105, 0.022, (0.0, 0.02, 1.49), "Z", -8.0), arm, "spine_03", metal)
    rigid(ring("Suit_NeckBand", 0.1, 0.009, (0.0, 0.022, 1.512), "Z", -8.0), arm, "spine_03", orange)
    # The life-support pack on his back: a shell, a dark panel on it, two orange valves on top.
    pack = box("Suit_Pack", (0.3, 0.12, 0.4), (0.0, 0.225, 1.31))
    bevelled(pack, 0.025)
    rigid(pack, arm, "spine_03", shell)
    panel = box("Suit_PackPanel", (0.22, 0.02, 0.28), (0.0, 0.29, 1.3))
    bevelled(panel, 0.006)
    rigid(panel, arm, "spine_03", grey)
    for x in (-0.085, 0.085):
        rigid(cylinder("Suit_Valve", 0.022, 0.05, (x, 0.225, 1.525)), arm, "spine_03", orange)
    # The chest unit, its screen lit.
    unit = box("Suit_ChestUnit", (0.14, 0.045, 0.09), (0.0, -0.17, 1.36))
    bevelled(unit, 0.01)
    rigid(unit, arm, "spine_03", grey)
    rigid(box("Suit_Screen", (0.085, 0.006, 0.045), (0.0, -0.194, 1.365)), arm, "spine_03", screen)
    # The ship's orange round each upper arm; cuffs at the wrists and the ankles.
    for side, sign in (("l", 1.0), ("r", -1.0)):
        rigid(ring("Suit_ArmBand_" + side, 0.066, 0.013, (0.3 * sign, 0.07, 1.456), "X"), arm, "upperarm_" + side, orange)
        rigid(ring("Suit_Cuff_" + side, 0.049, 0.014, (0.655 * sign, 0.066, 1.456), "X"), arm, "lowerarm_" + side, metal)
        rigid(ring("Suit_Ankle_" + side, 0.072, 0.017, (0.091 * sign, 0.078, 0.17), "Z"), arm, "calf_" + side, metal)


def channel_sets(action):
    """Where an action keeps its F-curves: the layered API Blender 4.4+ gives actions,
    or the action itself before that."""
    bags = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            bags.extend(strip.channelbags)
    return bags if bags else [action]


# EATING (v0.6 round two: "做完之后也没有吃的动作"). The library has no clip for it, so it is made
# here: his idle, with his right hand brought up to his mouth and down again -- two bites a loop
# -- by an IK chain on the arm reaching for a target that moves between his chest and his
# mouth, baked to keys. Where those are is in the rig's own space before he is turned round
# (he faces -Y here, his right hand is at -X), at the kit's own size.
EAT_MOUTH = (-0.03, -0.25, 1.51)
EAT_CHEST = (-0.12, -0.32, 1.27)
EAT_POLE = (-0.5, 0.15, 0.95)          # the elbow goes down and out, as an arm does
EAT_BITES = 2                          # bites a loop of the idle


def play(obj, action):
    """Puts `action` on `obj` so that it actually drives it: since Blender 4.4 an action animates
    through a slot, and one that came in on another armature (the library's) is not bound to
    this one until its slot is named."""
    obj.animation_data.action = action
    slots = getattr(action, "slots", None)
    if slots is not None and len(slots) > 0 and hasattr(obj.animation_data, "action_slot"):
        obj.animation_data.action_slot = slots[0]


def author_eat(arm):
    """Makes the "eat" clip: the idle, over its own length so it loops as the idle does, with
    the right arm bringing a mouthful up EAT_BITES times."""
    idle = bpy.data.actions.get("idle")
    if idle is None:
        print("[WARN] no idle clip to eat over")
        return
    scene = bpy.context.scene
    start, end = int(idle.frame_range[0]), int(idle.frame_range[1])
    scene.frame_start, scene.frame_end = start, end
    play(arm, idle)

    target = bpy.data.objects.new("EatTarget", None)
    pole = bpy.data.objects.new("EatPole", None)
    for o in (target, pole):
        scene.collection.objects.link(o)
    pole.location = EAT_POLE
    cycle = float(end - start) / float(EAT_BITES)
    for k in range(EAT_BITES):
        f0 = start + cycle * k
        # Up to the mouth, a moment there, and down again.
        for (t, where) in ((0.0, EAT_CHEST), (0.38, EAT_MOUTH), (0.62, EAT_MOUTH), (1.0, EAT_CHEST)):
            target.location = where
            target.keyframe_insert("location", frame=f0 + cycle * t)

    bone = arm.pose.bones["lowerarm_r"]
    ik = bone.constraints.new("IK")
    ik.target = target
    ik.pole_target = pole
    ik.pole_angle = -math.pi * 0.5
    ik.chain_count = 2

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=start, frame_end=end, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    eat = arm.animation_data.action
    eat.name = "eat"
    eat.use_fake_user = True
    arm.animation_data.action = None
    # The target's own keys go with it: an action left behind would be exported as a clip.
    moved = target.animation_data.action if target.animation_data else None
    for o in (target, pole):
        bpy.data.objects.remove(o, do_unlink=True)
    if moved is not None:
        bpy.data.actions.remove(moved)


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

    suit(arm)

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
    author_eat(arm)

    # TURNED to face the game's -Z (Blender +Y), as the dinosaurs are
    # (tools/convert_quaternius.py): everything in the game turns with look_at, which points
    # -Z at the target, and the kits' figures face the other way -- he walked backwards and
    # chopped with his back to the tree. A key on the rig OBJECT in any clip would turn him
    # straight back the moment it played, so the clips keep their bones' keys and nothing else.
    for act in bpy.data.actions:
        for bag in channel_sets(act):
            for fc in list(bag.fcurves):
                if not fc.data_path.startswith("pose.bones"):
                    bag.fcurves.remove(fc)
    arm.rotation_mode = "XYZ"
    arm.rotation_euler = (0.0, 0.0, math.pi)
    bpy.context.view_layer.update()

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
