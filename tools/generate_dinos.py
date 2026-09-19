# tools/generate_dinos.py
# Procedural low-poly rigged & animated dinosaur model generator for Defend Dinosaur v0.5.
# Generates t_rex.glb (big_theropod), raptor.glb, and pterosaur.glb using Blender 5.2.

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

def export_model_glb(arm_obj, mesh_obj, file_path):
    bpy.ops.object.select_all(action='DESELECT')
    arm_obj.select_set(True)
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.export_scene.gltf(
        filepath=file_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_anim_single_armature=True
    )
    print(f"[OK] Exported GLB: {file_path}")

# ==============================================================================
# 1. BIG THEROPOD / T-REX (重型大头霸王龙)
# ==============================================================================
def build_t_rex():
    reset_scene()
    mats = {
        "skin": create_material("TRex_Skin", (0.22, 0.42, 0.20, 1.0), roughness=0.68),
        "belly": create_material("TRex_Belly", (0.76, 0.70, 0.48, 1.0), roughness=0.75),
        "horn": create_material("TRex_Horn", (0.10, 0.08, 0.06, 1.0), roughness=0.4),
        "eye": create_material("TRex_Eye", (0.95, 0.75, 0.1, 1.0), roughness=0.2),
        "pupil": create_material("TRex_Pupil", (0.02, 0.02, 0.02, 1.0), roughness=0.1),
        "teeth": create_material("TRex_Teeth", (0.95, 0.93, 0.85, 1.0), roughness=0.3)
    }

    mesh_parts = []
    def make_box(name, loc, scale, rot=(0,0,0), mat=mats["skin"], bone="Hips"):
        bpy.ops.mesh.primitive_cube_add(location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_cone(name, loc, scale, rot=(0,0,0), mat=mats["horn"], bone="Hips"):
        bpy.ops.mesh.primitive_cone_add(vertices=6, location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_sphere(name, loc, scale, mat=mats["eye"], bone="Head"):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, location=loc, scale=scale)
        obj = bpy.context.active_object
        obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    # Torso & Belly
    make_box("Torso", (0, 0, 2.2), (0.7, 1.3, 0.8), (math.radians(-15), 0, 0), mats["skin"], "Hips")
    make_box("Belly", (0, 0.1, 1.8), (0.55, 1.0, 0.4), (math.radians(-15), 0, 0), mats["belly"], "Hips")

    # Spines
    for idx, (loc, sc) in enumerate([((0, 0.8, 3.1), (0.05, 0.12, 0.25)),
                                     ((0, 0.3, 3.05), (0.05, 0.15, 0.35)),
                                     ((0, -0.3, 2.9), (0.05, 0.16, 0.4))]):
        make_cone(f"Spine_Torso_{idx}", loc, sc, (math.radians(-20), 0, 0), mats["horn"], "Hips")

    # Neck, Head, Jaw
    make_box("Neck", (0, 1.3, 2.9), (0.4, 0.6, 0.5), (math.radians(35), 0, 0), mats["skin"], "Neck")
    make_box("Head_Upper", (0, 1.9, 3.4), (0.5, 0.9, 0.45), (math.radians(5), 0, 0), mats["skin"], "Head")
    make_box("Snout", (0, 2.6, 3.3), (0.38, 0.6, 0.35), (math.radians(2), 0, 0), mats["skin"], "Head")
    make_sphere("Eye_L", (-0.45, 1.8, 3.55), (0.12, 0.12, 0.12), mats["eye"], "Head")
    make_sphere("Pupil_L", (-0.52, 1.85, 3.55), (0.06, 0.06, 0.06), mats["pupil"], "Head")
    make_sphere("Eye_R", (0.45, 1.8, 3.55), (0.12, 0.12, 0.12), mats["eye"], "Head")
    make_sphere("Pupil_R", (0.52, 1.85, 3.55), (0.06, 0.06, 0.06), mats["pupil"], "Head")

    # Teeth upper & lower
    for i in range(4):
        y_pos = 2.2 + i * 0.22
        make_cone(f"Tooth_U_L_{i}", (-0.3, y_pos, 3.05), (0.04, 0.04, 0.12), (math.radians(180), 0, 0), mats["teeth"], "Head")
        make_cone(f"Tooth_U_R_{i}", (0.3, y_pos, 3.05), (0.04, 0.04, 0.12), (math.radians(180), 0, 0), mats["teeth"], "Head")

    make_box("Jaw_Lower", (0, 2.3, 2.9), (0.34, 0.8, 0.18), (math.radians(-10), 0, 0), mats["belly"], "Jaw")
    for i in range(4):
        y_pos = 2.2 + i * 0.22
        make_cone(f"Tooth_L_L_{i}", (-0.28, y_pos - 0.05, 3.05), (0.035, 0.035, 0.1), (0, 0, 0), mats["teeth"], "Jaw")
        make_cone(f"Tooth_L_R_{i}", (0.28, y_pos - 0.05, 3.05), (0.035, 0.035, 0.1), (0, 0, 0), mats["teeth"], "Jaw")

    # Tail chain
    tail_defs = [
        ("Tail_0", (0, -1.05, 2.15), (0.55, 0.40, 0.55), "Tail.0"),
        ("Tail_1", (0, -1.80, 2.10), (0.45, 0.38, 0.45), "Tail.1"),
        ("Tail_2", (0, -2.50, 2.05), (0.35, 0.35, 0.35), "Tail.2"),
        ("Tail_3", (0, -3.15, 2.00), (0.25, 0.32, 0.25), "Tail.3"),
        ("Tail_4", (0, -3.75, 1.95), (0.16, 0.30, 0.16), "Tail.4"),
    ]
    for name, loc, sc, bone in tail_defs:
        make_box(name, loc, sc, (0, 0, 0), mats["skin"], bone)

    # Legs & Feet
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"Thigh_{s_name}", (x_sign * 0.85, -0.2, 2.1), (0.35, 0.6, 0.7), (math.radians(25), 0, 0), mats["skin"], f"Thigh.{s_name}")
        make_box(f"Shin_{s_name}", (x_sign * 1.05, -0.5, 1.2), (0.25, 0.35, 0.65), (math.radians(-35), 0, 0), mats["skin"], f"Shin.{s_name}")
        make_box(f"Ankle_{s_name}", (x_sign * 1.05, -0.1, 0.5), (0.2, 0.25, 0.45), (math.radians(30), 0, 0), mats["skin"], f"Shin.{s_name}")
        make_box(f"Foot_{s_name}", (x_sign * 1.05, 0.3, 0.15), (0.38, 0.55, 0.15), (0, 0, 0), mats["skin"], f"Foot.{s_name}")
        for c_idx, x_off in enumerate([-0.22, 0.0, 0.22]):
            make_cone(f"Claw_{s_name}_{c_idx}", (x_sign * 1.05 + x_off, 0.85, 0.12), (0.08, 0.08, 0.25), (math.radians(80), 0, 0), mats["horn"], f"Foot.{s_name}")

    # Small Arms
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"ArmUpper_{s_name}", (x_sign * 0.65, 0.8, 1.8), (0.15, 0.2, 0.35), (math.radians(-30), math.radians(x_sign * 15), 0), mats["skin"], f"Arm.{s_name}")
        make_box(f"Forearm_{s_name}", (x_sign * 0.95, 1.05, 1.55), (0.12, 0.25, 0.14), (math.radians(45), 0, 0), mats["skin"], f"Arm.{s_name}")

    # Vertex Groups
    for obj, b_name in mesh_parts:
        vg = obj.vertex_groups.new(name=b_name)
        vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')

    bpy.ops.object.select_all(action='DESELECT')
    for obj, _ in mesh_parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_parts[0][0]
    bpy.ops.object.join()
    dino_mesh = bpy.context.active_object
    dino_mesh.name = "TRex_Mesh"

    # Armature
    arm_data = bpy.data.armatures.new("TRex_Armature")
    arm_obj = bpy.data.objects.new("TRex_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    def ab(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent: b.parent = eb[parent]
        return b

    ab("Root", (0, 0, 0), (0, 0, 0.5))
    ab("Hips", (0, -0.2, 2.0), (0, 0.8, 2.4), "Root")
    ab("Neck", (0, 1.0, 2.6), (0, 1.5, 3.2), "Hips")
    ab("Head", (0, 1.5, 3.2), (0, 2.8, 3.4), "Neck")
    ab("Jaw", (0, 1.8, 3.05), (0, 2.7, 2.85), "Head")
    ab("Tail.0", (0, -0.65, 2.15), (0, -1.45, 2.10), "Hips")
    ab("Tail.1", (0, -1.45, 2.10), (0, -2.15, 2.05), "Tail.0")
    ab("Tail.2", (0, -2.15, 2.05), (0, -2.85, 2.00), "Tail.1")
    ab("Tail.3", (0, -2.85, 2.00), (0, -3.45, 1.95), "Tail.2")
    ab("Tail.4", (0, -3.45, 1.95), (0, -4.05, 1.90), "Tail.3")
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        ab(f"Thigh.{s_name}", (x_sign * 0.85, -0.2, 2.4), (x_sign * 1.05, -0.4, 1.55), "Hips")
        ab(f"Shin.{s_name}",  (x_sign * 1.05, -0.4, 1.55), (x_sign * 1.05, -0.2, 0.65), f"Thigh.{s_name}")
        ab(f"Foot.{s_name}",  (x_sign * 1.05, -0.2, 0.65), (x_sign * 1.05, 0.6, 0.15), f"Shin.{s_name}")
        ab(f"Arm.{s_name}",   (x_sign * 0.65, 0.7, 2.0),   (x_sign * 0.95, 1.25, 1.45), "Hips")

    bpy.ops.object.mode_set(mode='OBJECT')
    dino_mesh.parent = arm_obj
    mod = dino_mesh.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj
    arm_obj.animation_data_create()
    pb = arm_obj.pose.bones

    # 1. IDLE (60 frames)
    act_idle = bpy.data.actions.new(name="idle")
    arm_obj.animation_data.action = act_idle
    for f, r in [(1, 0.0), (30, 1.0), (60, 0.0)]:
        set_bone_keyframe(pb["Hips"], f, rot_x=r * -2, loc_z=r * -0.05)
        set_bone_keyframe(pb["Neck"], f, rot_x=r * 3)
        set_bone_keyframe(pb["Head"], f, rot_x=r * -4)
        set_bone_keyframe(pb["Jaw"], f, rot_x=r * 6)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=r * 2)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=r * 2)
    for f, sw in [(1, 0.0), (15, 1.0), (30, 0.0), (45, -1.0), (60, 0.0)]:
        for t_idx in range(5):
            set_bone_keyframe(pb[f"Tail.{t_idx}"], f, rot_z=sw * (2.0 + t_idx * 0.5))
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "idle"; tr.strips.new("idle", 1, act_idle)

    # 2. RUN / WALK (24 frames)
    act_run = bpy.data.actions.new(name="run")
    arm_obj.animation_data.action = act_run
    run_keys = [
        (1,  35, -20,  0,   -30, -25, 25,   0.0, -3.0,  5.0,  -8.0),
        (6,  10, -35, -10,  -10, -10, 10,  -0.1,  0.0,  8.0,  -4.0),
        (13, -30, -25, 25,   35, -20,  0,   0.0,  3.0, -5.0,   8.0),
        (19, -10, -10, 10,   10, -35, -10, -0.1,  0.0, -8.0,   4.0),
        (24, 35, -20,  0,   -30, -25, 25,   0.0, -3.0,  5.0,  -8.0),
    ]
    for f, tl, sl, fl, trt, sr, fr, hz, hrz, trz, hrx in run_keys:
        set_bone_keyframe(pb["Hips"], f, rot_z=hrz, rot_x=5.0, loc_z=hz)
        set_bone_keyframe(pb["Neck"], f, rot_x=-hrx * 0.5)
        set_bone_keyframe(pb["Head"], f, rot_x=hrx)
        set_bone_keyframe(pb["Jaw"], f, rot_x=8.0)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl); set_bone_keyframe(pb["Shin.L"], f, rot_x=sl); set_bone_keyframe(pb["Foot.L"], f, rot_x=fl)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=trt); set_bone_keyframe(pb["Shin.R"], f, rot_x=sr); set_bone_keyframe(pb["Foot.R"], f, rot_x=fr)
        for t_idx in range(4):
            set_bone_keyframe(pb[f"Tail.{t_idx}"], f, rot_z=trz * (0.5 + t_idx * 0.2))
        set_bone_keyframe(pb["Arm.L"], f, rot_x=-tl * 0.6)
        set_bone_keyframe(pb["Arm.R"], f, rot_x=-trt * 0.6)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "run"; tr.strips.new("run", 1, act_run)

    # 3. ATTACK (30 frames)
    act_atk = bpy.data.actions.new(name="attack")
    arm_obj.animation_data.action = act_atk
    for f, h_rx, h_z, n_rx, hd_rx, j_rx in [
        (1, 0, 0, 0, 0, 0),
        (8, -12, -0.15, -15, -20, 35),
        (14, 22, 0.1, 25, 30, -5),
        (18, 15, 0.05, 10, 15, 10),
        (30, 0, 0, 0, 0, 0)
    ]:
        set_bone_keyframe(pb["Hips"], f, rot_x=h_rx, loc_z=h_z)
        set_bone_keyframe(pb["Neck"], f, rot_x=n_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=hd_rx)
        set_bone_keyframe(pb["Jaw"], f, rot_x=j_rx)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "attack"; tr.strips.new("attack", 1, act_atk)

    # 4. DEATH (40 frames - collapse and tip onto side)
    act_death = bpy.data.actions.new(name="death")
    arm_obj.animation_data.action = act_death
    death_keys = [
        (1,   0,   0,   0,    0,   0,   0.0,  0.0),
        (10, -10,  0,  -5,  -15,  25,  -0.2,  0.0),
        (22,  15, -35, 20,   10,  30,  -1.2, -0.3),
        (35,  25, -75, 40,   30,  20,  -1.8, -0.5),
        (40,  25, -75, 40,   30,  20,  -1.8, -0.5),
    ]
    for f, rx, rz, neck_rx, head_rx, jaw_rx, lz, lx in death_keys:
        set_bone_keyframe(pb["Hips"], f, rot_x=rx, rot_z=rz, loc_z=lz, loc_x=lx)
        set_bone_keyframe(pb["Neck"], f, rot_x=neck_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=head_rx)
        set_bone_keyframe(pb["Jaw"], f, rot_x=jaw_rx)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=rx * 0.5, rot_z=rz * 0.4)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=-rx * 0.5, rot_z=rz * 0.4)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "death"; tr.strips.new("death", 1, act_death)

    # 5. ALERT (40 frames)
    act_alert = bpy.data.actions.new(name="alert")
    arm_obj.animation_data.action = act_alert
    for f, n_rx, hd_rx, hd_rz, j_rx in [(1,0,0,0,0), (12,-15,-20,15,10), (25,-15,-20,-15,10), (40,0,0,0,0)]:
        set_bone_keyframe(pb["Neck"], f, rot_x=n_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=hd_rx, rot_z=hd_rz)
        set_bone_keyframe(pb["Jaw"], f, rot_x=j_rx)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "alert"; tr.strips.new("alert", 1, act_alert)

    # 6. JUMP (30 frames)
    act_jump = bpy.data.actions.new(name="jump")
    arm_obj.animation_data.action = act_jump
    for f, h_z, h_rx, tl, sl in [(1,0,0,0,0), (6,-0.3,-15,25,-40), (15,0.6,15,-20,10), (24,-0.1,-5,10,-15), (30,0,0,0,0)]:
        set_bone_keyframe(pb["Hips"], f, loc_z=h_z, rot_x=h_rx)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl); set_bone_keyframe(pb["Shin.L"], f, rot_x=sl)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=tl); set_bone_keyframe(pb["Shin.R"], f, rot_x=sl)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "jump"; tr.strips.new("jump", 1, act_jump)

    glb_path = os.path.join(OUTPUT_DIR, "t_rex.glb")
    export_model_glb(arm_obj, dino_mesh, glb_path)

# ==============================================================================
# 2. RAPTOR / VELOCIRAPTOR (迅捷条纹迅猛龙, 镰刀爪)
# ==============================================================================
def build_raptor():
    reset_scene()
    mats = {
        "skin": create_material("Raptor_Skin", (0.75, 0.42, 0.18, 1.0), roughness=0.62),    # Amber copper
        "belly": create_material("Raptor_Belly", (0.86, 0.82, 0.68, 1.0), roughness=0.72),  # Sand parchment
        "stripe": create_material("Raptor_Stripe", (0.22, 0.14, 0.08, 1.0), roughness=0.6), # Dark tiger stripes
        "feather": create_material("Raptor_Feather", (0.15, 0.52, 0.48, 1.0), roughness=0.5), # Teal quill accent
        "horn": create_material("Raptor_Horn", (0.12, 0.10, 0.08, 1.0), roughness=0.35),
        "eye": create_material("Raptor_Eye", (0.98, 0.60, 0.05, 1.0), roughness=0.2),
        "pupil": create_material("Raptor_Pupil", (0.01, 0.01, 0.01, 1.0), roughness=0.1),
        "teeth": create_material("Raptor_Teeth", (0.96, 0.95, 0.90, 1.0), roughness=0.3)
    }

    mesh_parts = []
    def make_box(name, loc, scale, rot=(0,0,0), mat=mats["skin"], bone="Hips"):
        bpy.ops.mesh.primitive_cube_add(location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_cone(name, loc, scale, rot=(0,0,0), mat=mats["horn"], bone="Hips"):
        bpy.ops.mesh.primitive_cone_add(vertices=6, location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_sphere(name, loc, scale, mat=mats["eye"], bone="Head"):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, location=loc, scale=scale)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    # Sleek Torso (horizontal, aerodynamic)
    make_box("Raptor_Torso", (0, 0, 1.6), (0.40, 0.95, 0.45), (math.radians(-8), 0, 0), mats["skin"], "Hips")
    make_box("Raptor_Belly", (0, 0.05, 1.35), (0.32, 0.80, 0.28), (math.radians(-8), 0, 0), mats["belly"], "Hips")

    # Tiger stripes on back
    for i in range(4):
        y_stripe = -0.5 + i * 0.35
        make_box(f"Raptor_Stripe_{i}", (0, y_stripe, 1.9), (0.42, 0.08, 0.18), (math.radians(-8), 0, 0), mats["stripe"], "Hips")

    # Feathery neck tufts & Neck
    make_box("Raptor_Neck", (0, 0.9, 2.0), (0.24, 0.50, 0.30), (math.radians(45), 0, 0), mats["skin"], "Neck")
    make_box("Raptor_Crest", (0, 0.85, 2.25), (0.05, 0.35, 0.20), (math.radians(45), 0, 0), mats["feather"], "Neck")

    # Slender raptor head & long predatory snout
    make_box("Raptor_Head", (0, 1.45, 2.45), (0.30, 0.65, 0.28), (math.radians(8), 0, 0), mats["skin"], "Head")
    make_box("Raptor_Snout", (0, 2.05, 2.38), (0.22, 0.55, 0.20), (math.radians(5), 0, 0), mats["skin"], "Head")
    make_sphere("Raptor_Eye_L", (-0.28, 1.45, 2.55), (0.08, 0.08, 0.08), mats["eye"], "Head")
    make_sphere("Raptor_Pupil_L", (-0.33, 1.5, 2.55), (0.04, 0.04, 0.04), mats["pupil"], "Head")
    make_sphere("Raptor_Eye_R", (0.28, 1.45, 2.55), (0.08, 0.08, 0.08), mats["eye"], "Head")
    make_sphere("Raptor_Pupil_R", (0.33, 1.5, 2.55), (0.04, 0.04, 0.04), mats["pupil"], "Head")

    # Jaw & razor teeth
    make_box("Raptor_Jaw", (0, 1.85, 2.15), (0.20, 0.65, 0.12), (math.radians(-6), 0, 0), mats["belly"], "Jaw")
    for i in range(5):
        y_pos = 1.7 + i * 0.16
        make_cone(f"R_Tooth_U_L_{i}", (-0.18, y_pos, 2.22), (0.025, 0.025, 0.08), (math.radians(180), 0, 0), mats["teeth"], "Head")
        make_cone(f"R_Tooth_U_R_{i}", (0.18, y_pos, 2.22), (0.025, 0.025, 0.08), (math.radians(180), 0, 0), mats["teeth"], "Head")

    # Long counterbalancing tail with feather fan at the tip
    tail_defs = [
        ("R_Tail_0", (0, -0.75, 1.55), (0.30, 0.35, 0.30), "Tail.0"),
        ("R_Tail_1", (0, -1.35, 1.50), (0.24, 0.35, 0.24), "Tail.1"),
        ("R_Tail_2", (0, -1.95, 1.45), (0.18, 0.35, 0.18), "Tail.2"),
        ("R_Tail_3", (0, -2.55, 1.40), (0.14, 0.35, 0.14), "Tail.3"),
        ("R_Tail_4", (0, -3.15, 1.38), (0.10, 0.35, 0.10), "Tail.4"),
    ]
    for name, loc, sc, bone in tail_defs:
        make_box(name, loc, sc, (0, 0, 0), mats["skin"], bone)
    # Feathery rudder at tail end
    make_box("Raptor_Tail_Feathers", (0, -3.2, 1.40), (0.45, 0.40, 0.04), (0, 0, 0), mats["feather"], "Tail.4")

    # Long legs, runner anatomy, prominent SICKLE CLAW
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"R_Thigh_{s_name}", (x_sign * 0.50, -0.15, 1.5), (0.22, 0.45, 0.50), (math.radians(30), 0, 0), mats["skin"], f"Thigh.{s_name}")
        make_box(f"R_Shin_{s_name}", (x_sign * 0.62, -0.40, 0.85), (0.16, 0.25, 0.55), (math.radians(-40), 0, 0), mats["skin"], f"Shin.{s_name}")
        make_box(f"R_Ankle_{s_name}", (x_sign * 0.62, -0.10, 0.35), (0.12, 0.18, 0.38), (math.radians(35), 0, 0), mats["skin"], f"Shin.{s_name}")
        make_box(f"R_Foot_{s_name}", (x_sign * 0.62, 0.20, 0.10), (0.24, 0.40, 0.10), (0, 0, 0), mats["skin"], f"Foot.{s_name}")
        # The iconic raised sickle claw (inner toe, curved menacingly upward)
        make_cone(f"Sickle_Claw_{s_name}", (x_sign * 0.50, 0.40, 0.30), (0.06, 0.06, 0.28), (math.radians(-45), 0, 0), mats["horn"], f"Foot.{s_name}")
        # Ground walking outer claws
        for c_idx, x_off in enumerate([-0.06, 0.08]):
            make_cone(f"R_Claw_{s_name}_{c_idx}", (x_sign * 0.62 + x_off, 0.60, 0.08), (0.05, 0.05, 0.18), (math.radians(80), 0, 0), mats["horn"], f"Foot.{s_name}")

    # Longer raptor arms with feathered wings & grasping claws
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"R_ArmUpper_{s_name}", (x_sign * 0.42, 0.55, 1.35), (0.12, 0.18, 0.30), (math.radians(-25), math.radians(x_sign * 15), 0), mats["skin"], f"Arm.{s_name}")
        make_box(f"R_Forearm_{s_name}", (x_sign * 0.60, 0.85, 1.15), (0.10, 0.28, 0.12), (math.radians(40), 0, 0), mats["skin"], f"Arm.{s_name}")
        make_box(f"R_ArmFeather_{s_name}", (x_sign * 0.68, 0.85, 1.05), (0.02, 0.30, 0.20), (math.radians(40), 0, 0), mats["feather"], f"Arm.{s_name}")
        for c_idx, x_off in enumerate([-0.05, 0.05]):
            make_cone(f"R_HandClaw_{s_name}_{c_idx}", (x_sign * 0.60 + x_off, 1.15, 1.05), (0.03, 0.03, 0.15), (math.radians(75), 0, 0), mats["horn"], f"Arm.{s_name}")

    for obj, b_name in mesh_parts:
        vg = obj.vertex_groups.new(name=b_name)
        vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')

    bpy.ops.object.select_all(action='DESELECT')
    for obj, _ in mesh_parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_parts[0][0]
    bpy.ops.object.join()
    raptor_mesh = bpy.context.active_object
    raptor_mesh.name = "Raptor_Mesh"

    arm_data = bpy.data.armatures.new("Raptor_Armature")
    arm_obj = bpy.data.objects.new("Raptor_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    def ab(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent: b.parent = eb[parent]
        return b

    ab("Root", (0, 0, 0), (0, 0, 0.4))
    ab("Hips", (0, -0.15, 1.45), (0, 0.55, 1.70), "Root")
    ab("Neck", (0, 0.70, 1.85), (0, 1.15, 2.30), "Hips")
    ab("Head", (0, 1.15, 2.30), (0, 2.10, 2.45), "Neck")
    ab("Jaw", (0, 1.35, 2.25), (0, 2.05, 2.15), "Head")
    ab("Tail.0", (0, -0.45, 1.55), (0, -1.05, 1.50), "Hips")
    ab("Tail.1", (0, -1.05, 1.50), (0, -1.65, 1.45), "Tail.0")
    ab("Tail.2", (0, -1.65, 1.45), (0, -2.25, 1.40), "Tail.1")
    ab("Tail.3", (0, -2.25, 1.40), (0, -2.85, 1.38), "Tail.2")
    ab("Tail.4", (0, -2.85, 1.38), (0, -3.45, 1.35), "Tail.3")
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        ab(f"Thigh.{s_name}", (x_sign * 0.50, -0.15, 1.65), (x_sign * 0.62, -0.30, 1.10), "Hips")
        ab(f"Shin.{s_name}",  (x_sign * 0.62, -0.30, 1.10), (x_sign * 0.62, -0.15, 0.45), f"Thigh.{s_name}")
        ab(f"Foot.{s_name}",  (x_sign * 0.62, -0.15, 0.45), (x_sign * 0.62, 0.40, 0.10), f"Shin.{s_name}")
        ab(f"Arm.{s_name}",   (x_sign * 0.42, 0.50, 1.45),   (x_sign * 0.65, 0.95, 1.05), "Hips")

    bpy.ops.object.mode_set(mode='OBJECT')
    raptor_mesh.parent = arm_obj
    mod = raptor_mesh.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj
    arm_obj.animation_data_create()
    pb = arm_obj.pose.bones

    # 1. IDLE (nimble predatory breathing, twitching head)
    act_idle = bpy.data.actions.new(name="idle")
    arm_obj.animation_data.action = act_idle
    for f, r in [(1, 0.0), (25, 1.0), (50, 0.0)]:
        set_bone_keyframe(pb["Hips"], f, rot_x=r * -3, loc_z=r * -0.04)
        set_bone_keyframe(pb["Neck"], f, rot_x=r * 4)
        set_bone_keyframe(pb["Head"], f, rot_x=r * -5, rot_z=r * 6)
        set_bone_keyframe(pb["Jaw"], f, rot_x=r * 4)
    for f, sw in [(1, 0.0), (12, 1.0), (25, 0.0), (37, -1.0), (50, 0.0)]:
        for t_idx in range(5):
            set_bone_keyframe(pb[f"Tail.{t_idx}"], f, rot_z=sw * (3.0 + t_idx * 0.8))
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "idle"; tr.strips.new("idle", 1, act_idle)

    # 2. RUN / WALK (rapid predatory sprint, 16 frames = 0.53s loop)
    act_run = bpy.data.actions.new(name="run")
    arm_obj.animation_data.action = act_run
    run_keys = [
        (1,   45, -30,   5,   -40, -30,  30,   0.0, -4.0,  6.0, -10.0),
        (5,   15, -45, -15,   -15, -15,  15,  -0.12, 0.0, 10.0,  -5.0),
        (9,  -40, -30,  30,    45, -30,   5,   0.0,  4.0, -6.0,  10.0),
        (13, -15, -15,  15,    15, -45, -15,  -0.12, 0.0,-10.0,   5.0),
        (16,  45, -30,   5,   -40, -30,  30,   0.0, -4.0,  6.0, -10.0),
    ]
    for f, tl, sl, fl, trt, sr, fr, hz, hrz, trz, hrx in run_keys:
        set_bone_keyframe(pb["Hips"], f, rot_z=hrz, rot_x=10.0, loc_z=hz)
        set_bone_keyframe(pb["Neck"], f, rot_x=-hrx * 0.4)
        set_bone_keyframe(pb["Head"], f, rot_x=hrx)
        set_bone_keyframe(pb["Jaw"], f, rot_x=12.0)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl); set_bone_keyframe(pb["Shin.L"], f, rot_x=sl); set_bone_keyframe(pb["Foot.L"], f, rot_x=fl)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=trt); set_bone_keyframe(pb["Shin.R"], f, rot_x=sr); set_bone_keyframe(pb["Foot.R"], f, rot_x=fr)
        for t_idx in range(4):
            set_bone_keyframe(pb[f"Tail.{t_idx}"], f, rot_z=trz * (0.6 + t_idx * 0.25))
        set_bone_keyframe(pb["Arm.L"], f, rot_x=-tl * 0.8)
        set_bone_keyframe(pb["Arm.R"], f, rot_x=-trt * 0.8)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "run"; tr.strips.new("run", 1, act_run)

    # 3. ATTACK (pounce, sickle claw slash & bite, 24 frames)
    act_atk = bpy.data.actions.new(name="attack")
    arm_obj.animation_data.action = act_atk
    for f, h_rx, h_z, n_rx, hd_rx, j_rx, tl_rx in [
        (1, 0, 0, 0, 0, 0, 0),
        (6, -18, -0.2, -20, -25, 45, 30), # crouch pounce windup
        (12, 30, 0.25, 30, 35, -5, -45), # lunge leap
        (18, 15, 0.05, 10, 15, 20, 10),
        (24, 0, 0, 0, 0, 0, 0)
    ]:
        set_bone_keyframe(pb["Hips"], f, rot_x=h_rx, loc_z=h_z)
        set_bone_keyframe(pb["Neck"], f, rot_x=n_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=hd_rx)
        set_bone_keyframe(pb["Jaw"], f, rot_x=j_rx)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl_rx)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "attack"; tr.strips.new("attack", 1, act_atk)

    # 4. DEATH (collapse sideways, 35 frames)
    act_death = bpy.data.actions.new(name="death")
    arm_obj.animation_data.action = act_death
    for f, rx, rz, lz, lx in [
        (1, 0, 0, 0.0, 0.0),
        (8, -15, 10, -0.15, 0.05),
        (18, 20, -45, -0.8, -0.2),
        (30, 30, -85, -1.2, -0.4),
        (35, 30, -85, -1.2, -0.4),
    ]:
        set_bone_keyframe(pb["Hips"], f, rot_x=rx, rot_z=rz, loc_z=lz, loc_x=lx)
        set_bone_keyframe(pb["Neck"], f, rot_x=rx * 0.8)
        set_bone_keyframe(pb["Head"], f, rot_x=rx * 0.6)
        set_bone_keyframe(pb["Jaw"], f, rot_x=30)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "death"; tr.strips.new("death", 1, act_death)

    # 5. ALERT (30 frames)
    act_alert = bpy.data.actions.new(name="alert")
    arm_obj.animation_data.action = act_alert
    for f, n_rx, hd_rx, hd_rz in [(1,0,0,0), (10,-20,-25,25), (20,-20,-25,-25), (30,0,0,0)]:
        set_bone_keyframe(pb["Neck"], f, rot_x=n_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=hd_rx, rot_z=hd_rz)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "alert"; tr.strips.new("alert", 1, act_alert)

    glb_path = os.path.join(OUTPUT_DIR, "raptor.glb")
    export_model_glb(arm_obj, raptor_mesh, glb_path)

# ==============================================================================
# 3. PTEROSAUR / PTERODACTYL (翼手龙, 突起头冠与翼膜双翅)
# ==============================================================================
def build_pterosaur():
    reset_scene()
    mats = {
        "skin": create_material("Ptero_Skin", (0.32, 0.38, 0.44, 1.0), roughness=0.6),      # Slate blue-grey
        "belly": create_material("Ptero_Belly", (0.78, 0.72, 0.62, 1.0), roughness=0.7),    # Cream tan
        "wing": create_material("Ptero_Wing", (0.68, 0.48, 0.32, 1.0), roughness=0.55),     # Leathery warm amber
        "crest": create_material("Ptero_Crest", (0.85, 0.18, 0.15, 1.0), roughness=0.4),    # Vivid red cranial crest
        "beak": create_material("Ptero_Beak", (0.82, 0.65, 0.15, 1.0), roughness=0.35),     # Horn amber beak
        "eye": create_material("Ptero_Eye", (0.95, 0.85, 0.1, 1.0), roughness=0.2),
        "pupil": create_material("Ptero_Pupil", (0.01, 0.01, 0.01, 1.0), roughness=0.1),
    }

    mesh_parts = []
    def make_box(name, loc, scale, rot=(0,0,0), mat=mats["skin"], bone="Hips"):
        bpy.ops.mesh.primitive_cube_add(location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_cone(name, loc, scale, rot=(0,0,0), mat=mats["beak"], bone="Head"):
        bpy.ops.mesh.primitive_cone_add(vertices=6, location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_sphere(name, loc, scale, mat=mats["eye"], bone="Head"):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, location=loc, scale=scale)
        obj = bpy.context.active_object; obj.name = name
        if mat: obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    # Compact lightweight Torso
    make_box("Ptero_Torso", (0, 0, 1.4), (0.35, 0.70, 0.35), (math.radians(-10), 0, 0), mats["skin"], "Hips")
    make_box("Ptero_Chest", (0, 0.15, 1.3), (0.28, 0.55, 0.30), (math.radians(-10), 0, 0), mats["belly"], "Hips")

    # Long flexible neck
    make_box("Ptero_Neck", (0, 0.65, 1.7), (0.18, 0.45, 0.22), (math.radians(50), 0, 0), mats["skin"], "Neck")

    # Head, spectacular backward cranial crest & long sharp beak
    make_box("Ptero_Head", (0, 1.05, 2.1), (0.22, 0.45, 0.22), (math.radians(10), 0, 0), mats["skin"], "Head")
    # Giant backward crest (symbolic Pteranodon horn)
    make_cone("Ptero_Crest", (0, 0.55, 2.5), (0.08, 0.25, 0.75), (math.radians(-65), 0, 0), mats["crest"], "Head")
    # Long needle beak
    make_cone("Ptero_Beak_Upper", (0, 1.85, 2.05), (0.12, 0.12, 0.85), (math.radians(95), 0, 0), mats["beak"], "Head")
    make_cone("Ptero_Beak_Lower", (0, 1.75, 1.90), (0.09, 0.09, 0.75), (math.radians(95), 0, 0), mats["beak"], "Jaw")

    make_sphere("Ptero_Eye_L", (-0.20, 1.05, 2.18), (0.06, 0.06, 0.06), mats["eye"], "Head")
    make_sphere("Ptero_Pupil_L", (-0.24, 1.08, 2.18), (0.03, 0.03, 0.03), mats["pupil"], "Head")
    make_sphere("Ptero_Eye_R", (0.20, 1.05, 2.18), (0.06, 0.06, 0.06), mats["eye"], "Head")
    make_sphere("Ptero_Pupil_R", (0.24, 1.08, 2.18), (0.03, 0.03, 0.03), mats["pupil"], "Head")

    # Small short tail
    make_box("Ptero_Tail", (0, -0.6, 1.3), (0.10, 0.25, 0.10), (math.radians(-25), 0, 0), mats["skin"], "Tail")

    # Quadrupedal walking hind limbs
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"P_Thigh_{s_name}", (x_sign * 0.35, -0.15, 1.25), (0.14, 0.25, 0.35), (math.radians(20), 0, 0), mats["skin"], f"Thigh.{s_name}")
        make_box(f"P_Shin_{s_name}", (x_sign * 0.42, -0.25, 0.75), (0.10, 0.18, 0.40), (math.radians(-30), 0, 0), mats["skin"], f"Shin.{s_name}")
        make_box(f"P_Foot_{s_name}", (x_sign * 0.42, 0.05, 0.10), (0.16, 0.25, 0.08), (0, 0, 0), mats["skin"], f"Foot.{s_name}")

    # Broad expansive wings with folding joints
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        # Humerus / Upper Arm
        make_box(f"Wing_Arm_{s_name}", (x_sign * 0.45, 0.3, 1.45), (0.12, 0.25, 0.20), (0, math.radians(x_sign * 25), 0), mats["skin"], f"WingArm.{s_name}")
        # Elongated 4th wing finger
        make_box(f"Wing_Finger_{s_name}", (x_sign * 1.15, 0.25, 1.55), (0.08, 0.12, 0.65), (0, math.radians(x_sign * 65), 0), mats["skin"], f"WingArm.{s_name}")
        # Broad membrane plane
        make_box(f"Wing_Membrane_{s_name}", (x_sign * 1.25, -0.1, 1.35), (0.02, 0.55, 0.55), (math.radians(10), math.radians(x_sign * 35), 0), mats["wing"], f"WingArm.{s_name}")

    for obj, b_name in mesh_parts:
        vg = obj.vertex_groups.new(name=b_name)
        vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')

    bpy.ops.object.select_all(action='DESELECT')
    for obj, _ in mesh_parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_parts[0][0]
    bpy.ops.object.join()
    ptero_mesh = bpy.context.active_object
    ptero_mesh.name = "Pterosaur_Mesh"

    arm_data = bpy.data.armatures.new("Pterosaur_Armature")
    arm_obj = bpy.data.objects.new("Pterosaur_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    def ab(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent: b.parent = eb[parent]
        return b

    ab("Root", (0, 0, 0), (0, 0, 0.4))
    ab("Hips", (0, -0.1, 1.3), (0, 0.45, 1.55), "Root")
    ab("Neck", (0, 0.50, 1.6), (0, 0.90, 2.05), "Hips")
    ab("Head", (0, 0.90, 2.05), (0, 1.80, 2.10), "Neck")
    ab("Jaw",  (0, 1.05, 1.95), (0, 1.75, 1.85), "Head")
    ab("Tail", (0, -0.40, 1.35), (0, -0.85, 1.25), "Hips")
    for s_name, x_sign in [("L", -1), ("R", 1)]:
        ab(f"Thigh.{s_name}", (x_sign * 0.35, -0.10, 1.35), (x_sign * 0.42, -0.20, 0.95), "Hips")
        ab(f"Shin.{s_name}",  (x_sign * 0.42, -0.20, 0.95), (x_sign * 0.42, -0.10, 0.35), f"Thigh.{s_name}")
        ab(f"Foot.{s_name}",  (x_sign * 0.42, -0.10, 0.35), (x_sign * 0.42, 0.25, 0.10), f"Shin.{s_name}")
        # Wing Arm
        ab(f"WingArm.{s_name}", (x_sign * 0.35, 0.30, 1.45), (x_sign * 1.65, 0.15, 1.50), "Hips")

    bpy.ops.object.mode_set(mode='OBJECT')
    ptero_mesh.parent = arm_obj
    mod = ptero_mesh.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj
    arm_obj.animation_data_create()
    pb = arm_obj.pose.bones

    # 1. IDLE (folded wings, alert head movement, 60 frames)
    act_idle = bpy.data.actions.new(name="idle")
    arm_obj.animation_data.action = act_idle
    for f, r in [(1, 0.0), (30, 1.0), (60, 0.0)]:
        set_bone_keyframe(pb["Hips"], f, rot_x=r * -2, loc_z=r * -0.03)
        set_bone_keyframe(pb["Neck"], f, rot_x=r * 5)
        set_bone_keyframe(pb["Head"], f, rot_x=r * -4)
        set_bone_keyframe(pb["WingArm.L"], f, rot_y=r * 5, rot_x=r * 2)
        set_bone_keyframe(pb["WingArm.R"], f, rot_y=r * -5, rot_x=r * 2)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "idle"; tr.strips.new("idle", 1, act_idle)

    # 2. RUN / WALK / GLIDE (flapping lope locomotion, 20 frames)
    act_run = bpy.data.actions.new(name="run")
    arm_obj.animation_data.action = act_run
    for f, flap, tl, trt, hz in [
        (1,   25,   30,  -25,   0.0),
        (5,  -35,   10,  -10,  -0.1),
        (10, -10,  -25,   30,   0.05),
        (15,  35,  -10,   10,  -0.1),
        (20,  25,   30,  -25,   0.0),
    ]:
        set_bone_keyframe(pb["Hips"], f, loc_z=hz, rot_x=8)
        set_bone_keyframe(pb["WingArm.L"], f, rot_z=flap, rot_y=flap * 0.4)
        set_bone_keyframe(pb["WingArm.R"], f, rot_z=-flap, rot_y=-flap * 0.4)
        set_bone_keyframe(pb["Thigh.L"], f, rot_x=tl)
        set_bone_keyframe(pb["Thigh.R"], f, rot_x=trt)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "run"; tr.strips.new("run", 1, act_run)

    # 3. ATTACK (diving beak peck & talon sweep, 24 frames)
    act_atk = bpy.data.actions.new(name="attack")
    arm_obj.animation_data.action = act_atk
    for f, n_rx, hd_rx, w_rz, j_rx in [
        (1, 0, 0, 0, 0),
        (8, -25, -30, 45, 30),  # rear up with wings high
        (14, 35, 40, -40, -10), # strike downward with beak spear
        (18, 15, 15, -15, 10),
        (24, 0, 0, 0, 0)
    ]:
        set_bone_keyframe(pb["Neck"], f, rot_x=n_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=hd_rx)
        set_bone_keyframe(pb["Jaw"], f, rot_x=j_rx)
        set_bone_keyframe(pb["WingArm.L"], f, rot_z=w_rz)
        set_bone_keyframe(pb["WingArm.R"], f, rot_z=-w_rz)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "attack"; tr.strips.new("attack", 1, act_atk)

    # 4. DEATH (crumple wings, collapse flat, 35 frames)
    act_death = bpy.data.actions.new(name="death")
    arm_obj.animation_data.action = act_death
    for f, rx, rz, lz, w_ry in [
        (1, 0, 0, 0.0, 0),
        (10, -15, 15, -0.2, 35),
        (20, 25, -60, -0.7, 75),
        (35, 35, -85, -1.0, 85),
    ]:
        set_bone_keyframe(pb["Hips"], f, rot_x=rx, rot_z=rz, loc_z=lz)
        set_bone_keyframe(pb["Neck"], f, rot_x=rx * 0.7)
        set_bone_keyframe(pb["Head"], f, rot_x=rx * 0.5)
        set_bone_keyframe(pb["WingArm.L"], f, rot_y=w_ry, rot_z=rx)
        set_bone_keyframe(pb["WingArm.R"], f, rot_y=-w_ry, rot_z=-rx)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "death"; tr.strips.new("death", 1, act_death)

    # 5. ALERT (24 frames)
    act_alert = bpy.data.actions.new(name="alert")
    arm_obj.animation_data.action = act_alert
    for f, n_rx, hd_rx, hd_rz in [(1,0,0,0), (8,-25,-25,30), (16,-25,-25,-30), (24,0,0,0)]:
        set_bone_keyframe(pb["Neck"], f, rot_x=n_rx)
        set_bone_keyframe(pb["Head"], f, rot_x=hd_rx, rot_z=hd_rz)
    tr = arm_obj.animation_data.nla_tracks.new(); tr.name = "alert"; tr.strips.new("alert", 1, act_alert)

    glb_path = os.path.join(OUTPUT_DIR, "pterosaur.glb")
    export_model_glb(arm_obj, ptero_mesh, glb_path)

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("==================================================")
    print("Generating Low-Poly Dinosaurs for Defend Dinosaur")
    print("==================================================")
    print(">>> 1/3 Generating T-Rex (big_theropod)...")
    build_t_rex()
    print(">>> 2/3 Generating Raptor (raptor)...")
    build_raptor()
    print(">>> 3/3 Generating Pterosaur (pterosaur)...")
    build_pterosaur()
    print("==================================================")
    print("All dinosaur models generated successfully!")
    print("==================================================")
