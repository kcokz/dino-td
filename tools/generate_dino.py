import bpy
import math
import os

def build_rigged_dinosaur():
    # 1. Reset factory settings
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 2. Materials setup
    materials = {}
    
    # Dino Skin
    mat = bpy.data.materials.new(name="Dino_Skin")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.22, 0.45, 0.20, 1.0) # Vibrant reptilian green
        bsdf.inputs["Roughness"].default_value = 0.65
    materials["skin"] = mat

    # Underbelly
    mat = bpy.data.materials.new(name="Dino_Belly")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.78, 0.72, 0.50, 1.0) # Pale sand tan
        bsdf.inputs["Roughness"].default_value = 0.75
    materials["belly"] = mat

    # Horn / Spines / Claws
    mat = bpy.data.materials.new(name="Dino_Horn")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.10, 0.08, 0.06, 1.0) # Dark horn
        bsdf.inputs["Roughness"].default_value = 0.4
    materials["horn"] = mat

    # Eyes
    mat = bpy.data.materials.new(name="Dino_Eye")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.95, 0.75, 0.1, 1.0) # Golden yellow
        bsdf.inputs["Roughness"].default_value = 0.2
    materials["eye"] = mat

    # Pupils
    mat = bpy.data.materials.new(name="Dino_Pupil")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1.0)
    materials["pupil"] = mat

    # Teeth
    mat = bpy.data.materials.new(name="Dino_Teeth")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.95, 0.93, 0.85, 1.0)
    materials["teeth"] = mat

    # List of mesh parts to combine: (obj, bone_name)
    mesh_parts = []

    def make_box(name, location, scale, rotation=(0,0,0), mat=materials["skin"], bone="Hips"):
        bpy.ops.mesh.primitive_cube_add(location=location, scale=scale, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_cone(name, location, scale, rotation=(0,0,0), vertices=6, mat=materials["horn"], bone="Hips"):
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, location=location, scale=scale, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    def make_sphere(name, location, scale, segments=12, rings=8, mat=materials["skin"], bone="Head"):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location, scale=scale)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        mesh_parts.append((obj, bone))
        return obj

    # --- BODY & TORSO ---
    make_box("Torso", location=(0, 0, 2.2), scale=(0.7, 1.3, 0.8), rotation=(math.radians(-15), 0, 0), mat=materials["skin"], bone="Hips")
    make_box("Belly", location=(0, 0.1, 1.8), scale=(0.55, 1.0, 0.4), rotation=(math.radians(-15), 0, 0), mat=materials["belly"], bone="Hips")

    # Spines on Torso
    spines_torso = [
        {"loc": (0, 0.8, 3.1), "scale": (0.05, 0.12, 0.25)},
        {"loc": (0, 0.3, 3.05), "scale": (0.05, 0.15, 0.35)},
        {"loc": (0, -0.3, 2.9), "scale": (0.05, 0.16, 0.4)},
    ]
    for idx, sp in enumerate(spines_torso):
        make_cone(f"Spine_Torso_{idx}", location=sp["loc"], scale=sp["scale"], rotation=(math.radians(-20), 0, 0), mat=materials["horn"], bone="Hips")

    # --- NECK ---
    make_box("Neck", location=(0, 1.3, 2.9), scale=(0.4, 0.6, 0.5), rotation=(math.radians(35), 0, 0), mat=materials["skin"], bone="Neck")

    # --- HEAD (UPPER) ---
    make_box("Head_Upper", location=(0, 1.9, 3.4), scale=(0.5, 0.9, 0.45), rotation=(math.radians(5), 0, 0), mat=materials["skin"], bone="Head")
    make_box("Snout", location=(0, 2.6, 3.3), scale=(0.38, 0.6, 0.35), rotation=(math.radians(2), 0, 0), mat=materials["skin"], bone="Head")
    make_sphere("Eye_L", location=(-0.45, 1.8, 3.55), scale=(0.12, 0.12, 0.12), mat=materials["eye"], bone="Head")
    make_sphere("Pupil_L", location=(-0.52, 1.85, 3.55), scale=(0.06, 0.06, 0.06), mat=materials["pupil"], bone="Head")
    make_sphere("Eye_R", location=(0.45, 1.8, 3.55), scale=(0.12, 0.12, 0.12), mat=materials["eye"], bone="Head")
    make_sphere("Pupil_R", location=(0.52, 1.85, 3.55), scale=(0.06, 0.06, 0.06), mat=materials["pupil"], bone="Head")
    make_box("Brow_L", location=(-0.42, 1.8, 3.7), scale=(0.15, 0.4, 0.1), rotation=(0, math.radians(-15), math.radians(10)), mat=materials["skin"], bone="Head")
    make_box("Brow_R", location=(0.42, 1.8, 3.7), scale=(0.15, 0.4, 0.1), rotation=(0, math.radians(15), math.radians(-10)), mat=materials["skin"], bone="Head")

    # Upper Teeth
    for i in range(4):
        y_pos = 2.2 + i * 0.22
        make_cone(f"Tooth_Upper_L_{i}", location=(-0.3, y_pos, 3.05), scale=(0.04, 0.04, 0.12), rotation=(math.radians(180), 0, 0), mat=materials["teeth"], bone="Head")
        make_cone(f"Tooth_Upper_R_{i}", location=(0.3, y_pos, 3.05), scale=(0.04, 0.04, 0.12), rotation=(math.radians(180), 0, 0), mat=materials["teeth"], bone="Head")

    # --- JAW (LOWER) ---
    make_box("Jaw_Lower", location=(0, 2.3, 2.9), scale=(0.34, 0.8, 0.18), rotation=(math.radians(-10), 0, 0), mat=materials["belly"], bone="Jaw")
    for i in range(4):
        y_pos = 2.2 + i * 0.22
        make_cone(f"Tooth_Lower_L_{i}", location=(-0.28, y_pos - 0.05, 3.05), scale=(0.035, 0.035, 0.1), rotation=(0, 0, 0), mat=materials["teeth"], bone="Jaw")
        make_cone(f"Tooth_Lower_R_{i}", location=(0.28, y_pos - 0.05, 3.05), scale=(0.035, 0.035, 0.1), rotation=(0, 0, 0), mat=materials["teeth"], bone="Jaw")

    # --- TAIL SEGMENTS (Seamless end-to-end alignment) ---
    tail_configs = [
        {"name": "Tail_0", "loc": (0, -1.05, 2.15), "scale": (0.55, 0.40, 0.55), "bone": "Tail.0"},
        {"name": "Tail_1", "loc": (0, -1.80, 2.10), "scale": (0.45, 0.38, 0.45), "bone": "Tail.1"},
        {"name": "Tail_2", "loc": (0, -2.50, 2.05), "scale": (0.35, 0.35, 0.35), "bone": "Tail.2"},
        {"name": "Tail_3", "loc": (0, -3.15, 2.00), "scale": (0.25, 0.32, 0.25), "bone": "Tail.3"},
        {"name": "Tail_4", "loc": (0, -3.75, 1.95), "scale": (0.16, 0.30, 0.16), "bone": "Tail.4"},
    ]
    for seg in tail_configs:
        make_box(seg["name"], location=seg["loc"], scale=seg["scale"], rotation=(0, 0, 0), mat=materials["skin"], bone=seg["bone"])

    # Spines on Tail
    spines_tail = [
        {"loc": (0, -1.05, 2.75), "scale": (0.05, 0.15, 0.35), "bone": "Tail.0"},
        {"loc": (0, -1.80, 2.60), "scale": (0.05, 0.13, 0.30), "bone": "Tail.1"},
        {"loc": (0, -2.50, 2.45), "scale": (0.04, 0.11, 0.22), "bone": "Tail.2"},
        {"loc": (0, -3.15, 2.32), "scale": (0.04, 0.09, 0.18), "bone": "Tail.3"},
    ]
    for idx, sp in enumerate(spines_tail):
        make_cone(f"Spine_Tail_{idx}", location=sp["loc"], scale=sp["scale"], rotation=(math.radians(-20), 0, 0), mat=materials["horn"], bone=sp["bone"])

    # --- LEGS & FEET ---
    for side_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"Thigh_{side_name}", location=(x_sign * 0.85, -0.2, 2.1), scale=(0.35, 0.6, 0.7), rotation=(math.radians(25), 0, 0), mat=materials["skin"], bone=f"Thigh.{side_name}")
        make_box(f"Shin_{side_name}", location=(x_sign * 1.05, -0.5, 1.2), scale=(0.25, 0.35, 0.65), rotation=(math.radians(-35), 0, 0), mat=materials["skin"], bone=f"Shin.{side_name}")
        make_box(f"Ankle_{side_name}", location=(x_sign * 1.05, -0.1, 0.5), scale=(0.2, 0.25, 0.45), rotation=(math.radians(30), 0, 0), mat=materials["skin"], bone=f"Shin.{side_name}")
        make_box(f"Foot_{side_name}", location=(x_sign * 1.05, 0.3, 0.15), scale=(0.38, 0.55, 0.15), mat=materials["skin"], bone=f"Foot.{side_name}")
        for claw_idx, x_off in enumerate([-0.22, 0.0, 0.22]):
            make_cone(
                f"Claw_{side_name}_{claw_idx}",
                location=(x_sign * 1.05 + x_off, 0.85, 0.12),
                scale=(0.08, 0.08, 0.25),
                rotation=(math.radians(80), 0, 0),
                mat=materials["horn"],
                bone=f"Foot.{side_name}"
            )

    # --- ARMS & CLAWS ---
    for side_name, x_sign in [("L", -1), ("R", 1)]:
        make_box(f"ArmUpper_{side_name}", location=(x_sign * 0.65, 0.8, 1.8), scale=(0.15, 0.2, 0.35), rotation=(math.radians(-30), math.radians(x_sign * 15), 0), mat=materials["skin"], bone=f"Arm.{side_name}")
        make_box(f"Forearm_{side_name}", location=(x_sign * 0.95, 1.05, 1.55), scale=(0.12, 0.25, 0.14), rotation=(math.radians(45), 0, 0), mat=materials["skin"], bone=f"Arm.{side_name}")
        for claw_idx, x_off in enumerate([-0.06, 0.06]):
            make_cone(
                f"HandClaw_{side_name}_{claw_idx}",
                location=(x_sign * 0.95 + x_off, 1.3, 1.45),
                scale=(0.04, 0.04, 0.12),
                rotation=(math.radians(70), 0, 0),
                mat=materials["horn"],
                bone=f"Arm.{side_name}"
            )

    # 3. Create Vertex Groups on each object before joining
    for obj, bone_name in mesh_parts:
        vg = obj.vertex_groups.new(name=bone_name)
        vert_indices = [v.index for v in obj.data.vertices]
        vg.add(vert_indices, 1.0, 'REPLACE')

    # 4. Join all objects into a single clean mesh
    bpy.ops.object.select_all(action='DESELECT')
    for obj, _ in mesh_parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_parts[0][0]
    bpy.ops.object.join()
    dino_mesh = bpy.context.active_object
    dino_mesh.name = "Dino_Mesh"

    # 5. Create Armature
    arm_data = bpy.data.armatures.new("Dino_Armature")
    arm_data.display_type = 'STICK'
    arm_obj = bpy.data.objects.new("Dino_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    # Enter Edit Mode to create bones
    bpy.ops.object.mode_set(mode='EDIT')
    edit_bones = arm_data.edit_bones

    def add_edit_bone(name, head, tail, parent_name=None):
        b = edit_bones.new(name)
        b.head = head
        b.tail = tail
        if parent_name:
            b.parent = edit_bones[parent_name]
        return b

    # Main Spine / Body
    add_edit_bone("Root", (0, 0, 0), (0, 0, 0.5))
    add_edit_bone("Hips", (0, -0.2, 2.0), (0, 0.8, 2.4), parent_name="Root")
    add_edit_bone("Neck", (0, 1.0, 2.6), (0, 1.5, 3.2), parent_name="Hips")
    add_edit_bone("Head", (0, 1.5, 3.2), (0, 2.8, 3.4), parent_name="Neck")
    add_edit_bone("Jaw",  (0, 1.8, 3.05), (0, 2.7, 2.85), parent_name="Head")

    # Tail chain with exact joint alignment
    add_edit_bone("Tail.0", (0, -0.65, 2.15), (0, -1.45, 2.10), parent_name="Hips")
    add_edit_bone("Tail.1", (0, -1.45, 2.10), (0, -2.15, 2.05), parent_name="Tail.0")
    add_edit_bone("Tail.2", (0, -2.15, 2.05), (0, -2.85, 2.00), parent_name="Tail.1")
    add_edit_bone("Tail.3", (0, -2.85, 2.00), (0, -3.45, 1.95), parent_name="Tail.2")
    add_edit_bone("Tail.4", (0, -3.45, 1.95), (0, -4.05, 1.90), parent_name="Tail.3")

    # Legs
    for side_name, x_sign in [("L", -1), ("R", 1)]:
        add_edit_bone(f"Thigh.{side_name}", (x_sign * 0.85, -0.2, 2.4), (x_sign * 1.05, -0.4, 1.55), parent_name="Hips")
        add_edit_bone(f"Shin.{side_name}",  (x_sign * 1.05, -0.4, 1.55), (x_sign * 1.05, -0.2, 0.65), parent_name=f"Thigh.{side_name}")
        add_edit_bone(f"Foot.{side_name}",  (x_sign * 1.05, -0.2, 0.65), (x_sign * 1.05, 0.6, 0.15), parent_name=f"Shin.{side_name}")

    # Arms
    for side_name, x_sign in [("L", -1), ("R", 1)]:
        add_edit_bone(f"Arm.{side_name}", (x_sign * 0.65, 0.7, 2.0), (x_sign * 0.95, 1.25, 1.45), parent_name="Hips")

    bpy.ops.object.mode_set(mode='OBJECT')

    # 6. Bind Mesh to Armature
    dino_mesh.parent = arm_obj
    mod = dino_mesh.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj

    # 7. Animation Setup
    arm_obj.animation_data_create()

    # Helper function to keyframe pose bones
    def set_bone(pb, frame, rot_x=0.0, rot_y=0.0, rot_z=0.0, loc_x=0.0, loc_y=0.0, loc_z=0.0):
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(rot_x), math.radians(rot_y), math.radians(rot_z))
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        if loc_x != 0.0 or loc_y != 0.0 or loc_z != 0.0:
            pb.location = (loc_x, loc_y, loc_z)
            pb.keyframe_insert(data_path="location", frame=frame)
        else:
            pb.location = (0, 0, 0)
            pb.keyframe_insert(data_path="location", frame=frame)

    pose_bones = arm_obj.pose.bones

    # -------------------------------------------------------------
    # ACTION 1: IDLE (呼吸待机, 60 frames = 2.0s, loop)
    # -------------------------------------------------------------
    act_idle = bpy.data.actions.new(name="idle")
    arm_obj.animation_data.action = act_idle

    for frame, ratio in [(1, 0.0), (30, 1.0), (60, 0.0)]:
        # Breathing & vertical bob
        set_bone(pose_bones["Hips"], frame, rot_x=ratio * -2, loc_z=ratio * -0.05)
        set_bone(pose_bones["Neck"], frame, rot_x=ratio * 3)
        set_bone(pose_bones["Head"], frame, rot_x=ratio * -4)
        set_bone(pose_bones["Jaw"], frame, rot_x=ratio * 6) # subtle jaw relaxation
        
        # Legs slightly compensate
        set_bone(pose_bones["Thigh.L"], frame, rot_x=ratio * 2)
        set_bone(pose_bones["Thigh.R"], frame, rot_x=ratio * 2)

    # Tail subtle sinusoidal sway
    tail_frames = [
        (1, 0.0),
        (15, 1.0),
        (30, 0.0),
        (45, -1.0),
        (60, 0.0)
    ]
    for frame, sway in tail_frames:
        set_bone(pose_bones["Tail.0"], frame, rot_z=sway * 2.0)
        set_bone(pose_bones["Tail.1"], frame, rot_z=sway * 2.5)
        set_bone(pose_bones["Tail.2"], frame, rot_z=sway * 3.0)
        set_bone(pose_bones["Tail.3"], frame, rot_z=sway * 3.5)
        set_bone(pose_bones["Tail.4"], frame, rot_z=sway * 4.0)

    # Push to NLA Track
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = "idle"
    track.strips.new("idle", 1, act_idle)

    # -------------------------------------------------------------
    # ACTION 2: RUN (奔跑循环, 24 frames = 0.8s, loop)
    # -------------------------------------------------------------
    act_run = bpy.data.actions.new(name="run")
    arm_obj.animation_data.action = act_run

    # 24-frame run cycle
    run_keyframes = [
        # Frame 1: Left forward, Right back
        (1,  35, -20,  0,   -30, -25, 25,   0.0, -3.0,  5.0,  -8.0),
        # Frame 6: Passing / contact left
        (6,  10, -35, -10,  -10, -10, 10,  -0.1,  0.0,  8.0,  -4.0),
        # Frame 13: Left back, Right forward
        (13, -30, -25, 25,   35, -20,  0,   0.0,  3.0, -5.0,   8.0),
        # Frame 19: Passing / contact right
        (19, -10, -10, 10,   10, -35, -10, -0.1,  0.0, -8.0,   4.0),
        # Frame 24: Loop return
        (24, 35, -20,  0,   -30, -25, 25,   0.0, -3.0,  5.0,  -8.0),
    ]

    for f, tl_x, sl_x, fl_x, tr_x, sr_x, fr_x, hips_z, hips_rz, tail_rz, head_rx in run_keyframes:
        set_bone(pose_bones["Hips"], f, rot_z=hips_rz, rot_x=5.0, loc_z=hips_z)
        set_bone(pose_bones["Neck"], f, rot_x=-head_rx * 0.5)
        set_bone(pose_bones["Head"], f, rot_x=head_rx)
        set_bone(pose_bones["Jaw"], f, rot_x=8.0) # mouth slightly open panting

        # Left Leg
        set_bone(pose_bones["Thigh.L"], f, rot_x=tl_x)
        set_bone(pose_bones["Shin.L"], f, rot_x=sl_x)
        set_bone(pose_bones["Foot.L"], f, rot_x=fl_x)

        # Right Leg
        set_bone(pose_bones["Thigh.R"], f, rot_x=tr_x)
        set_bone(pose_bones["Shin.R"], f, rot_x=sr_x)
        set_bone(pose_bones["Foot.R"], f, rot_x=fr_x)

        # Tail counter-balance
        set_bone(pose_bones["Tail.0"], f, rot_z=tail_rz * 0.5)
        set_bone(pose_bones["Tail.1"], f, rot_z=tail_rz * 0.8)
        set_bone(pose_bones["Tail.2"], f, rot_z=tail_rz)
        set_bone(pose_bones["Tail.3"], f, rot_z=tail_rz * 1.2)

        # Arms pumping
        set_bone(pose_bones["Arm.L"], f, rot_x=-tl_x * 0.6)
        set_bone(pose_bones["Arm.R"], f, rot_x=-tr_x * 0.6)

    track = arm_obj.animation_data.nla_tracks.new()
    track.name = "run"
    track.strips.new("run", 1, act_run)

    # -------------------------------------------------------------
    # ACTION 3: ATTACK (突进撕咬, 30 frames = 1.0s, one-shot)
    # -------------------------------------------------------------
    act_attack = bpy.data.actions.new(name="attack")
    arm_obj.animation_data.action = act_attack

    attack_keyframes = [
        # Frame 1: Base pose
        (1,  0.0,  0.0,   0.0,   0.0,   0.0,  0.0),
        # Frame 8: Wind up / Reel back
        (8, -15.0, -0.3, -10.0, -20.0, 50.0, -15.0), # Jaw snaps wide open!
        # Frame 14: Violent lunge forward & bite clamp!
        (14, 15.0,  0.6,  25.0,  15.0, -8.0, 20.0),  # Jaw clamps shut tight!
        # Frame 20: Savage head shake
        (20, 5.0,   0.3,  10.0,  -5.0,  0.0, 10.0),
        # Frame 30: Recover
        (30, 0.0,   0.0,   0.0,   0.0,  0.0,  0.0),
    ]

    for f, hips_rx, hips_y, neck_rx, head_rx, jaw_rx, tail_rx in attack_keyframes:
        set_bone(pose_bones["Hips"], f, rot_x=hips_rx, loc_y=hips_y)
        set_bone(pose_bones["Neck"], f, rot_x=neck_rx)
        set_bone(pose_bones["Head"], f, rot_x=head_rx)
        set_bone(pose_bones["Jaw"], f, rot_x=jaw_rx)
        set_bone(pose_bones["Tail.0"], f, rot_x=-tail_rx * 0.5)
        set_bone(pose_bones["Tail.2"], f, rot_x=-tail_rx)
        set_bone(pose_bones["Arm.L"], f, rot_x=neck_rx * 0.8)
        set_bone(pose_bones["Arm.R"], f, rot_x=neck_rx * 0.8)

    # Head shake on bite impact (Z axis)
    set_bone(pose_bones["Head"], 14, rot_x=15.0, rot_z=15.0)
    set_bone(pose_bones["Head"], 17, rot_x=10.0, rot_z=-15.0)
    set_bone(pose_bones["Head"], 21, rot_x=5.0,  rot_z=0.0)

    track = arm_obj.animation_data.nla_tracks.new()
    track.name = "attack"
    track.strips.new("attack", 1, act_attack)

    # -------------------------------------------------------------
    # ACTION 4: JUMP (蓄力跳跃与着陆, 30 frames = 1.0s, one-shot)
    # -------------------------------------------------------------
    act_jump = bpy.data.actions.new(name="jump")
    arm_obj.animation_data.action = act_jump

    jump_keyframes = [
        # Frame 1: Base
        (1,   0.0,   0.0,  0.0,  0.0,  0.0),
        # Frame 6: Crouch compression
        (6,  -0.35,  15.0, 35.0, -45.0, 15.0),
        # Frame 12: Apex leap
        (12,  0.65, -15.0,-25.0,  10.0,-15.0),
        # Frame 18: Fall hang
        (18,  0.30,  -5.0, 15.0, -20.0,  0.0),
        # Frame 23: Impact landing
        (23, -0.40,  20.0, 40.0, -50.0, 20.0),
        # Frame 30: Stand up
        (30,  0.0,    0.0,  0.0,   0.0,  0.0),
    ]

    for f, hips_z, hips_rx, thigh_x, shin_x, foot_x in jump_keyframes:
        set_bone(pose_bones["Hips"], f, loc_z=hips_z, rot_x=hips_rx)
        set_bone(pose_bones["Thigh.L"], f, rot_x=thigh_x)
        set_bone(pose_bones["Shin.L"], f, rot_x=shin_x)
        set_bone(pose_bones["Foot.L"], f, rot_x=foot_x)
        set_bone(pose_bones["Thigh.R"], f, rot_x=thigh_x)
        set_bone(pose_bones["Shin.R"], f, rot_x=shin_x)
        set_bone(pose_bones["Foot.R"], f, rot_x=foot_x)
        set_bone(pose_bones["Neck"], f, rot_x=-hips_rx * 0.7)
        set_bone(pose_bones["Tail.0"], f, rot_x=-hips_rx * 0.6)
        set_bone(pose_bones["Tail.2"], f, rot_x=-hips_rx * 0.9)

    track = arm_obj.animation_data.nla_tracks.new()
    track.name = "jump"
    track.strips.new("jump", 1, act_jump)

    # -------------------------------------------------------------
    # ACTION 5: ALERT (警觉环顾, 36 frames = 1.2s, one-shot)
    # -------------------------------------------------------------
    act_alert = bpy.data.actions.new(name="alert")
    arm_obj.animation_data.action = act_alert

    alert_keyframes = [
        # Frame 1: Base
        (1,   0.0,   0.0,   0.0,   0.0,  0.0),
        # Frame 6: Flinch / Stand tall alert
        (6,   0.15, -15.0, -10.0,  0.0, 15.0),
        # Frame 14: Sharp scan left
        (14,  0.15, -15.0, -10.0, 35.0, 15.0),
        # Frame 24: Sharp scan right
        (24,  0.15, -15.0, -10.0,-35.0, 15.0),
        # Frame 36: Return to rest
        (36,  0.0,    0.0,   0.0,  0.0,  0.0),
    ]

    for f, hips_z, neck_rx, head_rx, head_rz, jaw_rx in alert_keyframes:
        set_bone(pose_bones["Hips"], f, loc_z=hips_z)
        set_bone(pose_bones["Neck"], f, rot_x=neck_rx, rot_z=head_rz * 0.5)
        set_bone(pose_bones["Head"], f, rot_x=head_rx, rot_z=head_rz)
        set_bone(pose_bones["Jaw"], f, rot_x=jaw_rx)
        set_bone(pose_bones["Tail.0"], f, rot_z=-head_rz * 0.2)
        set_bone(pose_bones["Tail.2"], f, rot_z=-head_rz * 0.4)

    track = arm_obj.animation_data.nla_tracks.new()
    track.name = "alert"
    track.strips.new("alert", 1, act_alert)

    # Set active action back to idle
    arm_obj.animation_data.action = act_idle

    # 8. Setup Camera & Lighting for render preview
    # Target
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 1.8))
    target = bpy.context.active_object
    target.name = "Dino_Target"

    # World Lighting
    world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs["Color"].default_value = (0.5, 0.55, 0.6, 1.0)
        bg_node.inputs["Strength"].default_value = 1.0

    # Sun Light
    bpy.ops.object.light_add(type='SUN', location=(-8, 8, 12))
    sun = bpy.context.active_object
    sun.data.energy = 3.8
    sun_track = sun.constraints.new(type='TRACK_TO')
    sun_track.target = target
    sun_track.track_axis = 'TRACK_NEGATIVE_Z'
    sun_track.up_axis = 'UP_Y'

    # Fill Light
    bpy.ops.object.light_add(type='POINT', location=(6, 4, 5))
    fill = bpy.context.active_object
    fill.data.energy = 600.0
    fill.data.color = (1.0, 0.95, 0.85)

    # Ground Plane
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane_mat = bpy.data.materials.new(name="Ground_Plane")
    bsdf_p = plane_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_p:
        bsdf_p.inputs["Base Color"].default_value = (0.15, 0.18, 0.16, 1.0)
    plane.data.materials.append(plane_mat)

    # Camera
    bpy.ops.object.camera_add(location=(-6.5, 7.5, 4.0))
    cam = bpy.context.active_object
    bpy.context.scene.camera = cam
    track_constraint = cam.constraints.new(type='TRACK_TO')
    track_constraint.target = target
    track_constraint.track_axis = 'TRACK_NEGATIVE_Z'
    track_constraint.up_axis = 'UP_Y'
    cam.data.lens = 42

    # Render settings
    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    bpy.context.scene.render.resolution_x = 1024
    bpy.context.scene.render.resolution_y = 768
    bpy.context.scene.render.film_transparent = True

    # 9. Save and Export
    output_dir = r"z:\home\zkl-unix\repo\game\dino\assets\models"
    os.makedirs(output_dir, exist_ok=True)

    blend_path = os.path.join(output_dir, "t_rex.blend")
    glb_path = os.path.join(output_dir, "t_rex.glb")
    render_path = os.path.join(output_dir, "t_rex_render.png")

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[OK] Saved Blender project: {blend_path}")

    # Export glTF / glb with animations (only rig and dinosaur mesh)
    bpy.ops.object.select_all(action='DESELECT')
    arm_obj.select_set(True)
    dino_mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_anim_single_armature=True
    )
    print(f"[OK] Exported GLTF / GLB: {glb_path}")

    # Render still preview at frame 10 (slight breathing / dynamic pose)
    bpy.context.scene.frame_set(10)
    bpy.context.scene.render.filepath = render_path
    bpy.ops.render.render(write_still=True)
    print(f"[OK] Rendered preview: {render_path}")

if __name__ == "__main__":
    build_rigged_dinosaur()
