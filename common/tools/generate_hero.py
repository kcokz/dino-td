# tools/generate_hero.py
# Procedural low-poly rigged & animated humanoid Hero generator for Defend Dinosaur v0.5.
# Generates assets/models/hero.glb with 6 core animations: idle, walk, build, harvest, attack, death.

import bpy
import math
import os

OUTPUT_DIR = r"z:\home\zkl-unix\repo\game\dino\assets\models"

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_material(name, base_color, roughness=0.65, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
    return mat

def set_bone_keyframe(pb, frame, rot_x=0.0, rot_y=0.0, rot_z=0.0, loc_x=0.0, loc_y=0.0, loc_z=0.0):
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (math.radians(rot_x), math.radians(rot_y), math.radians(rot_z))
    pb.keyframe_insert(data_path="rotation_euler", frame=frame)
    pb.location = (loc_x, loc_y, loc_z)
    pb.keyframe_insert(data_path="location", frame=frame)

def build_hero():
    reset_scene()

    # 1. Palette & Materials
    mats = {
        "jacket":   create_material("Hero_Jacket",   (0.18, 0.44, 0.52, 1.0), roughness=0.6),  # Sci-Fi explorer teal
        "pants":    create_material("Hero_Pants",    (0.16, 0.18, 0.24, 1.0), roughness=0.7),  # Utility cargo navy
        "skin":     create_material("Hero_Skin",     (0.86, 0.66, 0.52, 1.0), roughness=0.65), # Natural tan skin
        "hair":     create_material("Hero_Hair",     (0.22, 0.14, 0.08, 1.0), roughness=0.75), # Dark brown hair
        "goggles":  create_material("Hero_Goggles",  (0.95, 0.72, 0.15, 1.0), roughness=0.25, metallic=0.4), # Amber visor
        "leather":  create_material("Hero_Leather",  (0.38, 0.24, 0.14, 1.0), roughness=0.6),  # Belts & boots
        "backpack": create_material("Hero_Backpack", (0.24, 0.28, 0.32, 1.0), roughness=0.65), # Survival comm pack
        "metal":    create_material("Hero_Metal",    (0.72, 0.75, 0.78, 1.0), roughness=0.35, metallic=0.7), # Tool steel
        "wood":     create_material("Hero_Wood",     (0.50, 0.35, 0.22, 1.0), roughness=0.7),  # Tool handle
    }

    mesh_parts = []
    def make_box(name, loc, scale, rot=(0,0,0), mat=mats["jacket"], bone="Hips"):
        bpy.ops.mesh.primitive_cube_add(location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_cylinder(name, loc, scale, rot=(0,0,0), vertices=8, mat=mats["wood"], bone="Hand.R"):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    # --- TORSO & CHEST ---
    make_box("Hero_Hips", (0, 0, 0.95), (0.24, 0.16, 0.12), (0, 0, 0), mats["pants"], "Hips")
    make_box("Hero_Belt", (0, 0, 1.03), (0.26, 0.18, 0.05), (0, 0, 0), mats["leather"], "Hips")
    make_box("Hero_Pouch_L", (-0.22, -0.02, 1.01), (0.06, 0.10, 0.07), (0, 0, 0), mats["leather"], "Hips")
    make_box("Hero_Pouch_R", (0.22, -0.02, 1.01), (0.06, 0.10, 0.07), (0, 0, 0), mats["leather"], "Hips")

    make_box("Hero_Spine", (0, 0, 1.15), (0.25, 0.17, 0.12), (0, 0, 0), mats["jacket"], "Spine")
    make_box("Hero_Chest", (0, 0, 1.34), (0.28, 0.19, 0.14), (0, 0, 0), mats["jacket"], "Chest")
    make_box("Hero_Collar", (0, 0, 1.45), (0.16, 0.14, 0.06), (0, 0, 0), mats["jacket"], "Chest")

    # Backpack on Chest
    make_box("Hero_Pack", (0, -0.20, 1.30), (0.22, 0.12, 0.20), (math.radians(-5), 0, 0), mats["backpack"], "Chest")

    # --- NECK & HEAD ---
    make_box("Hero_Neck", (0, 0, 1.50), (0.09, 0.09, 0.08), (0, 0, 0), mats["skin"], "Neck")
    make_box("Hero_Head", (0, 0.02, 1.66), (0.15, 0.16, 0.16), (0, 0, 0), mats["skin"], "Head")
    make_box("Hero_Hair_Top", (0, -0.01, 1.78), (0.17, 0.18, 0.08), (0, 0, 0), mats["hair"], "Head")
    make_box("Hero_Hair_Back", (0, -0.12, 1.66), (0.16, 0.08, 0.15), (0, 0, 0), mats["hair"], "Head")
    make_box("Hero_Goggles_Band", (0, 0.02, 1.71), (0.17, 0.18, 0.05), (0, 0, 0), mats["goggles"], "Head")

    # --- LEGS & BOOTS ---
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"Hero_Thigh_{s_name}", (x_sign * 0.14, 0, 0.72), (0.11, 0.13, 0.22), (0, 0, 0), mats["pants"], f"Thigh.{s_name}")
        make_box(f"Hero_Shin_{s_name}",  (x_sign * 0.14, 0, 0.36), (0.10, 0.11, 0.20), (0, 0, 0), mats["pants"], f"Shin.{s_name}")
        make_box(f"Hero_Boot_{s_name}",  (x_sign * 0.14, 0, 0.18), (0.11, 0.12, 0.14), (0, 0, 0), mats["leather"], f"Shin.{s_name}")
        make_box(f"Hero_Foot_{s_name}",  (x_sign * 0.14, 0.08, 0.06), (0.11, 0.18, 0.06), (0, 0, 0), mats["leather"], f"Foot.{s_name}")

    # --- ARMS & HANDS ---
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"Hero_Shoulder_{s_name}", (x_sign * 0.28, 0, 1.40), (0.10, 0.12, 0.10), (0, 0, 0), mats["jacket"], f"ArmUpper.{s_name}")
        make_box(f"Hero_ArmUpper_{s_name}", (x_sign * 0.32, 0, 1.20), (0.08, 0.09, 0.16), (0, 0, 0), mats["jacket"], f"ArmUpper.{s_name}")
        make_box(f"Hero_Forearm_{s_name}",  (x_sign * 0.33, 0, 0.90), (0.07, 0.08, 0.16), (0, 0, 0), mats["skin"], f"Forearm.{s_name}")
        make_box(f"Hero_Hand_{s_name}",     (x_sign * 0.33, 0, 0.68), (0.06, 0.07, 0.08), (0, 0, 0), mats["leather"], f"Hand.{s_name}")

    # Tool (Multitool / Construction Hammer-Pick held in Hand.R)
    make_cylinder("Hero_Tool_Handle", (0.34, 0.04, 0.70), (0.025, 0.025, 0.35), (math.radians(15), 0, 0), vertices=6, mat=mats["wood"], bone="Hand.R")
    make_box("Hero_Tool_Head", (0.34, 0.06, 1.02), (0.06, 0.18, 0.07), (math.radians(15), 0, 0), mat=mats["metal"], bone="Hand.R")

    # Vertex Groups
    for obj, b_name in mesh_parts:
        vg = obj.vertex_groups.new(name=b_name)
        vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')

    bpy.ops.object.select_all(action='DESELECT')
    for obj, _ in mesh_parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_parts[0][0]
    bpy.ops.object.join()
    hero_mesh = bpy.context.active_object
    hero_mesh.name = "Hero_Mesh"

    # 2. Armature Rig
    arm_data = bpy.data.armatures.new("Hero_Armature")
    arm_obj = bpy.data.objects.new("Hero_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    def ab(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent: b.parent = eb[parent]
        return b

    ab("Root", (0, 0, 0), (0, 0, 0.3))
    ab("Hips", (0, 0, 0.88), (0, 0, 1.05), "Root")
    ab("Spine", (0, 0, 1.05), (0, 0, 1.25), "Hips")
    ab("Chest", (0, 0, 1.25), (0, 0, 1.45), "Spine")
    ab("Neck",  (0, 0, 1.45), (0, 0, 1.55), "Chest")
    ab("Head",  (0, 0, 1.55), (0, 0, 1.82), "Neck")

    for s_name, x_sign in [("L", -1), ("R", 1)]:
        ab(f"ArmUpper.{s_name}", (x_sign * 0.28, 0, 1.40), (x_sign * 0.33, 0, 1.05), "Chest")
        ab(f"Forearm.{s_name}",  (x_sign * 0.33, 0, 1.05), (x_sign * 0.33, 0, 0.75), f"ArmUpper.{s_name}")
        ab(f"Hand.{s_name}",     (x_sign * 0.33, 0, 0.75), (x_sign * 0.33, 0.05, 0.60), f"Forearm.{s_name}")

        ab(f"Thigh.{s_name}",    (x_sign * 0.14, 0, 0.88), (x_sign * 0.14, 0, 0.48), "Hips")
        ab(f"Shin.{s_name}",     (x_sign * 0.14, 0, 0.48), (x_sign * 0.14, 0, 0.12), f"Thigh.{s_name}")
        ab(f"Foot.{s_name}",     (x_sign * 0.14, 0, 0.12), (x_sign * 0.14, 0.16, 0.02), f"Shin.{s_name}")

    bpy.ops.object.mode_set(mode='OBJECT')
    hero_mesh.parent = arm_obj
    mod = hero_mesh.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj
    arm_obj.animation_data_create()
    pb = arm_obj.pose.bones

    # --------------------------------------------------------------------------
    # ACTION 1: IDLE (60 frames = 2.0s, loop)
    # --------------------------------------------------------------------------
    act_idle = bpy.data.actions.new(name="idle")
    arm_obj.animation_data.action = act_idle
    for f, r in [(1, 0.0), (30, 1.0), (60, 0.0)]:
        set_bone_keyframe(pb["Chest"], f, rot_x=r * 2.5, loc_z=r * 0.02)
        set_bone_keyframe(pb["Head"], f, rot_x=r * -1.5, rot_z=r * 2.0)
        set_bone_keyframe(pb["ArmUpper.L"], f, rot_x=r * -2.0, rot_z=r * 1.5)
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_x=r * 2.0, rot_z=r * -1.5)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "idle"; tr.strips.new("idle", 1, act_idle)

    # --------------------------------------------------------------------------
    # ACTION 2: WALK (24 frames = 0.8s, loop)
    # --------------------------------------------------------------------------
    act_walk = bpy.data.actions.new(name="walk")
    arm_obj.animation_data.action = act_walk
    walk_keys = [
        # Frame, Thigh.L, Shin.L, Foot.L, Thigh.R, Shin.R, Foot.R, Arm.L, Arm.R, Hips.Z, Hips.RZ
        (1,   28,  -15,   0,   -25,  -18,  20,   -25,   25,   0.0,   -2.0),
        (6,    8,  -28, -10,   -10,  -10,  10,  -0.05,   0,  -0.03,   0.0),
        (13, -25,  -18,  20,    28,  -15,   0,    25,  -25,   0.0,    2.0),
        (19, -10,  -10,  10,     8,  -28, -10,     0, -0.05,-0.03,   0.0),
        (24,  28,  -15,   0,   -25,  -18,  20,   -25,   25,   0.0,   -2.0),
    ]
    for f, tl, sl, fl, trt, sr, fr, al, ar, hz, hrz in walk_keys:
        set_bone_keyframe(pb["Hips"], f, rot_z=hrz, loc_z=hz)
        set_bone_keyframe(pb["Chest"], f, rot_z=-hrz * 0.6)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl); set_bone_keyframe(pb["Shin.L"], f, rot_x=sl); set_bone_keyframe(pb["Foot.L"], f, rot_x=fl)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=trt); set_bone_keyframe(pb["Shin.R"], f, rot_x=sr); set_bone_keyframe(pb["Foot.R"], f, rot_x=fr)
        set_bone_keyframe(pb["ArmUpper.L"], f, rot_x=al)
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_x=ar)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "walk"; tr.strips.new("walk", 1, act_walk)

    # Push run alias as duplicate strip so 'run' clip is also directly in file
    act_run = bpy.data.actions.new(name="run")
    arm_obj.animation_data.action = act_run
    for f, tl, sl, fl, trt, sr, fr, al, ar, hz, hrz in walk_keys:
        set_bone_keyframe(pb["Hips"], f, rot_z=hrz, loc_z=hz)
        set_bone_keyframe(pb["Chest"], f, rot_z=-hrz * 0.6)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl * 1.2); set_bone_keyframe(pb["Shin.L"], f, rot_x=sl * 1.2); set_bone_keyframe(pb["Foot.L"], f, rot_x=fl)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=trt * 1.2); set_bone_keyframe(pb["Shin.R"], f, rot_x=sr * 1.2); set_bone_keyframe(pb["Foot.R"], f, rot_x=fr)
        set_bone_keyframe(pb["ArmUpper.L"], f, rot_x=al * 1.3)
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_x=ar * 1.3)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "run"; tr.strips.new("run", 1, act_run)

    # --------------------------------------------------------------------------
    # ACTION 3: BUILD (30 frames = 1.0s, loop) - Rhythmic hammer striking
    # --------------------------------------------------------------------------
    act_build = bpy.data.actions.new(name="build")
    arm_obj.animation_data.action = act_build
    for f, sp_rx, arm_rx, fa_rx, h_rx, hz in [
        (1,   10,  -40,  45,  10, -0.02), # Ready / chambering hammer up
        (10,   5,  -75,  65,  25,  0.0),  # Raise hammer high overhead
        (17,  20,   25,  10, -35, -0.05), # Powerful hammer strike impact!
        (22,  15,   10,  20, -15, -0.03), # Rebound
        (30,  10,  -40,  45,  10, -0.02), # Return loop
    ]:
        set_bone_keyframe(pb["Spine"], f, rot_x=sp_rx, loc_z=hz)
        set_bone_keyframe(pb["Chest"], f, rot_x=sp_rx * 0.8)
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_x=arm_rx, rot_y=15, rot_z=-10)
        set_bone_keyframe(pb["Forearm.R"], f, rot_x=fa_rx)
        set_bone_keyframe(pb["Hand.R"], f, rot_x=h_rx)
        # Left arm balances/stabilizes
        set_bone_keyframe(pb["ArmUpper.L"], f, rot_x=20, rot_z=20)
        set_bone_keyframe(pb["Forearm.L"], f, rot_x=40)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "build"; tr.strips.new("build", 1, act_build)

    # --------------------------------------------------------------------------
    # ACTION 4: HARVEST (36 frames = 1.2s, loop) - Two-handed heavy chop / pick swing
    # --------------------------------------------------------------------------
    act_harvest = bpy.data.actions.new(name="harvest")
    arm_obj.animation_data.action = act_harvest
    for f, sp_rx, sp_rz, r_arm_rx, r_fa_rx, l_arm_rx, l_fa_rx, hz in [
        (1,   -5, -10,  -30,  30,  -15,  40,  0.0),   # Start windup
        (12, -15, -25,  -85,  70,  -70,  65,  0.04),  # High overhead coil
        (20,  25,  15,   40,  20,   30,  30, -0.08),  # Full downward cleave impact!
        (26,  20,  10,   25,  30,   15,  35, -0.04),  # Follow-through
        (36,  -5, -10,  -30,  30,  -15,  40,  0.0),   # Return loop
    ]:
        set_bone_keyframe(pb["Hips"], f, rot_z=sp_rz * 0.5, loc_z=hz)
        set_bone_keyframe(pb["Spine"], f, rot_x=sp_rx, rot_z=sp_rz)
        set_bone_keyframe(pb["Chest"], f, rot_x=sp_rx * 0.7, rot_z=sp_rz * 0.7)
        # Right Arm swinging tool
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_x=r_arm_rx, rot_y=10, rot_z=-15)
        set_bone_keyframe(pb["Forearm.R"], f, rot_x=r_fa_rx)
        # Left Arm assisting 2-handed grip
        set_bone_keyframe(pb["ArmUpper.L"], f, rot_x=l_arm_rx, rot_y=-10, rot_z=20)
        set_bone_keyframe(pb["Forearm.L"], f, rot_x=l_fa_rx)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "harvest"; tr.strips.new("harvest", 1, act_harvest)

    # --------------------------------------------------------------------------
    # ACTION 5: ATTACK (24 frames = 0.8s) - Rapid forward strike
    # --------------------------------------------------------------------------
    act_atk = bpy.data.actions.new(name="attack")
    arm_obj.animation_data.action = act_atk
    for f, sp_rx, arm_rx, fa_rx in [
        (1,   0,   0,   0),
        (6, -10, -50,  40), # windup
        (13, 20,  45,  15), # thrust / slash forward
        (18, 10,  15,  10),
        (24,  0,   0,   0),
    ]:
        set_bone_keyframe(pb["Spine"], f, rot_x=sp_rx)
        set_bone_keyframe(pb["Chest"], f, rot_x=sp_rx * 0.8)
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_x=arm_rx, rot_z=-15)
        set_bone_keyframe(pb["Forearm.R"], f, rot_x=fa_rx)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "attack"; tr.strips.new("attack", 1, act_atk)

    # --------------------------------------------------------------------------
    # ACTION 6: DEATH (40 frames = 1.33s) - Recoil and collapse to ground
    # --------------------------------------------------------------------------
    act_death = bpy.data.actions.new(name="death")
    arm_obj.animation_data.action = act_death
    for f, h_rx, h_rz, h_z, l_rx, r_rx in [
        (1,    0,   0,   0.0,   0,   0),
        (10, -15,   0, -0.15, -20, -10), # stumble backwards
        (22, -60,  20, -0.60, -45, -35), # collapse
        (35, -85,  35, -0.85, -60, -50), # flat on terrain
        (40, -85,  35, -0.85, -60, -50),
    ]:
        set_bone_keyframe(pb["Hips"], f, rot_x=h_rx, rot_z=h_rz, loc_z=h_z)
        set_bone_keyframe(pb["Spine"], f, rot_x=h_rx * 0.6)
        set_bone_keyframe(pb["Head"], f, rot_x=h_rx * 0.5)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=l_rx)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=r_rx)
        set_bone_keyframe(pb["ArmUpper.L"], f, rot_z=h_rx * -0.5)
        set_bone_keyframe(pb["ArmUpper.R"], f, rot_z=h_rx * 0.5)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "death"; tr.strips.new("death", 1, act_death)

    blend_path = os.path.join(OUTPUT_DIR, "hero.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[OK] Saved Blender project: {blend_path}")

    # Export GLB
    glb_path = os.path.join(OUTPUT_DIR, "hero.glb")
    bpy.ops.object.select_all(action='DESELECT')
    arm_obj.select_set(True)
    hero_mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_anim_single_armature=True
    )
    print(f"[OK] Exported GLB: {glb_path}")

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("==================================================")
    print("Generating Low-Poly Rigged Hero for Defend Dinosaur")
    print("==================================================")
    build_hero()
    print("==================================================")
    print("Hero generation completed successfully!")
    print("==================================================")
