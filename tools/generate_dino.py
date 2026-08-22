import bpy
import math
import os

def create_dinosaur():
    # Clear existing objects in scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # Create a new collection
    dino_col = bpy.data.collections.new("Dinosaur")
    bpy.context.scene.collection.children.link(dino_col)
    
    # Material definitions
    # 1. Main Skin (Green/Camo reptile)
    skin_mat = bpy.data.materials.new(name="Dino_Skin")
    skin_mat.use_nodes = True
    bsdf = skin_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.18, 0.42, 0.16, 1.0) # Forest Green
        bsdf.inputs["Roughness"].default_value = 0.7
        
    # 2. Underbelly (Pale yellow / tan)
    belly_mat = bpy.data.materials.new(name="Dino_Belly")
    belly_mat.use_nodes = True
    bsdf_belly = belly_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_belly:
        bsdf_belly.inputs["Base Color"].default_value = (0.75, 0.68, 0.45, 1.0)
        bsdf_belly.inputs["Roughness"].default_value = 0.8

    # 3. Claws / Spikes / Horns (Dark horn color)
    horn_mat = bpy.data.materials.new(name="Dino_Horn")
    horn_mat.use_nodes = True
    bsdf_horn = horn_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_horn:
        bsdf_horn.inputs["Base Color"].default_value = (0.08, 0.06, 0.05, 1.0)
        bsdf_horn.inputs["Roughness"].default_value = 0.4
        
    # 4. Teeth / Eyes (White/Off-white and black pupils)
    eye_mat = bpy.data.materials.new(name="Dino_Eye")
    eye_mat.use_nodes = True
    bsdf_eye = eye_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_eye:
        bsdf_eye.inputs["Base Color"].default_value = (0.9, 0.7, 0.1, 1.0) # Golden predatory eye
        bsdf_eye.inputs["Roughness"].default_value = 0.2

    pupil_mat = bpy.data.materials.new(name="Dino_Pupil")
    pupil_mat.use_nodes = True
    bsdf_pupil = pupil_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_pupil:
        bsdf_pupil.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1.0)

    teeth_mat = bpy.data.materials.new(name="Dino_Teeth")
    teeth_mat.use_nodes = True
    bsdf_teeth = teeth_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_teeth:
        bsdf_teeth.inputs["Base Color"].default_value = (0.95, 0.93, 0.85, 1.0)

    # Helper function to add low-poly mesh parts
    def add_box(name, location, scale, rotation=(0,0,0), material=skin_mat):
        bpy.ops.mesh.primitive_cube_add(location=location, scale=scale, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        if material:
            obj.data.materials.append(material)
        return obj

    def add_cylinder(name, location, scale, rotation=(0,0,0), vertices=8, material=skin_mat):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, location=location, scale=scale, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        if material:
            obj.data.materials.append(material)
        return obj

    def add_cone(name, location, scale, rotation=(0,0,0), vertices=6, material=horn_mat):
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, location=location, scale=scale, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        if material:
            obj.data.materials.append(material)
        return obj

    def add_uv_sphere(name, location, scale, segments=12, ring_count=8, material=skin_mat):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=ring_count, location=location, scale=scale)
        obj = bpy.context.active_object
        obj.name = name
        if material:
            obj.data.materials.append(material)
        return obj

    # --- BODY & TORSO ---
    body = add_box("Torso", location=(0, 0, 2.2), scale=(0.7, 1.3, 0.8), rotation=(math.radians(-15), 0, 0), material=skin_mat)
    belly = add_box("Belly", location=(0, 0.1, 1.8), scale=(0.55, 1.0, 0.4), rotation=(math.radians(-15), 0, 0), material=belly_mat)

    # --- NECK & HEAD ---
    neck = add_box("Neck", location=(0, 1.3, 2.9), scale=(0.4, 0.6, 0.5), rotation=(math.radians(35), 0, 0), material=skin_mat)
    head_upper = add_box("Head_Upper", location=(0, 1.9, 3.4), scale=(0.5, 0.9, 0.45), rotation=(math.radians(5), 0, 0), material=skin_mat)
    snout = add_box("Snout", location=(0, 2.6, 3.3), scale=(0.38, 0.6, 0.35), rotation=(math.radians(2), 0, 0), material=skin_mat)
    jaw_lower = add_box("Jaw_Lower", location=(0, 2.3, 2.9), scale=(0.34, 0.8, 0.18), rotation=(math.radians(-10), 0, 0), material=belly_mat)

    # Eyes
    add_uv_sphere("Eye_L", location=(-0.45, 1.8, 3.55), scale=(0.12, 0.12, 0.12), material=eye_mat)
    add_uv_sphere("Pupil_L", location=(-0.52, 1.85, 3.55), scale=(0.06, 0.06, 0.06), material=pupil_mat)
    add_uv_sphere("Eye_R", location=(0.45, 1.8, 3.55), scale=(0.12, 0.12, 0.12), material=eye_mat)
    add_uv_sphere("Pupil_R", location=(0.52, 1.85, 3.55), scale=(0.06, 0.06, 0.06), material=pupil_mat)

    # Brow Ridges
    add_box("Brow_L", location=(-0.42, 1.8, 3.7), scale=(0.15, 0.4, 0.1), rotation=(0, math.radians(-15), math.radians(10)), material=skin_mat)
    add_box("Brow_R", location=(0.42, 1.8, 3.7), scale=(0.15, 0.4, 0.1), rotation=(0, math.radians(15), math.radians(-10)), material=skin_mat)

    # Teeth
    for i in range(4):
        y_pos = 2.2 + i * 0.22
        # Upper teeth L/R
        add_cone(f"Tooth_Upper_L_{i}", location=(-0.3, y_pos, 3.05), scale=(0.04, 0.04, 0.12), rotation=(math.radians(180), 0, 0), material=teeth_mat)
        add_cone(f"Tooth_Upper_R_{i}", location=(0.3, y_pos, 3.05), scale=(0.04, 0.04, 0.12), rotation=(math.radians(180), 0, 0), material=teeth_mat)
        # Lower teeth L/R
        add_cone(f"Tooth_Lower_L_{i}", location=(-0.28, y_pos - 0.05, 3.05), scale=(0.035, 0.035, 0.1), rotation=(0, 0, 0), material=teeth_mat)
        add_cone(f"Tooth_Lower_R_{i}", location=(0.28, y_pos - 0.05, 3.05), scale=(0.035, 0.035, 0.1), rotation=(0, 0, 0), material=teeth_mat)

    # --- TAIL (Segmented curving tail) ---
    tail_segments = [
        {"loc": (0, -1.3, 2.1), "scale": (0.55, 0.7, 0.55), "rot": math.radians(-10)},
        {"loc": (0, -2.3, 2.0), "scale": (0.45, 0.7, 0.45), "rot": math.radians(-5)},
        {"loc": (0.1, -3.3, 2.1), "scale": (0.35, 0.7, 0.35), "rot": math.radians(5)},
        {"loc": (0.3, -4.2, 2.3), "scale": (0.25, 0.6, 0.25), "rot": math.radians(15)},
        {"loc": (0.5, -5.0, 2.6), "scale": (0.16, 0.5, 0.16), "rot": math.radians(20)},
    ]
    for idx, seg in enumerate(tail_segments):
        add_box(f"Tail_{idx}", location=seg["loc"], scale=seg["scale"], rotation=(seg["rot"], 0, math.radians(idx * 4)), material=skin_mat)

    # --- BACK SPINES / DORSAL RIDGES ---
    spines = [
        {"loc": (0, 0.8, 3.1), "scale": (0.05, 0.12, 0.25)},
        {"loc": (0, 0.3, 3.05), "scale": (0.05, 0.15, 0.35)},
        {"loc": (0, -0.3, 2.9), "scale": (0.05, 0.16, 0.4)},
        {"loc": (0, -0.9, 2.7), "scale": (0.05, 0.15, 0.35)},
        {"loc": (0, -1.6, 2.55), "scale": (0.05, 0.13, 0.3)},
        {"loc": (0, -2.4, 2.4), "scale": (0.04, 0.11, 0.22)},
        {"loc": (0.1, -3.3, 2.4), "scale": (0.04, 0.09, 0.18)},
    ]
    for idx, sp in enumerate(spines):
        add_cone(f"Spine_{idx}", location=sp["loc"], scale=sp["scale"], rotation=(math.radians(-20), 0, 0), material=horn_mat)

    # --- LEGS & FEET (Muscular Theropod Legs) ---
    for side, x_sign, side_name in [(-1, -0.85, "L"), (1, 0.85, "R")]:
        # Thigh / Hip
        add_box(f"Thigh_{side_name}", location=(x_sign, -0.2, 2.1), scale=(0.35, 0.6, 0.7), rotation=(math.radians(25), 0, 0), material=skin_mat)
        # Shin / Calf
        add_box(f"Shin_{side_name}", location=(x_sign * 1.05, -0.5, 1.2), scale=(0.25, 0.35, 0.65), rotation=(math.radians(-35), 0, 0), material=skin_mat)
        # Ankle / Metatarsal
        add_box(f"Ankle_{side_name}", location=(x_sign * 1.05, -0.1, 0.5), scale=(0.2, 0.25, 0.45), rotation=(math.radians(30), 0, 0), material=skin_mat)
        # Foot Base
        add_box(f"Foot_{side_name}", location=(x_sign * 1.05, 0.3, 0.15), scale=(0.38, 0.55, 0.15), material=skin_mat)
        # 3 Claws per foot
        for claw_idx, x_off in enumerate([-0.22, 0.0, 0.22]):
            add_cone(
                f"Claw_{side_name}_{claw_idx}",
                location=(x_sign * 1.05 + x_off, 0.85, 0.12),
                scale=(0.08, 0.08, 0.25),
                rotation=(math.radians(80), 0, 0),
                material=horn_mat
            )

    # --- ARMS & CLAWS (T-Rex style short, muscular forearms) ---
    for side, x_sign, side_name in [(-1, -0.65, "L"), (1, 0.65, "R")]:
        # Shoulder / Upper Arm
        add_box(f"ArmUpper_{side_name}", location=(x_sign, 0.8, 1.8), scale=(0.15, 0.2, 0.35), rotation=(math.radians(-30), math.radians(x_sign * 15), 0), material=skin_mat)
        # Forearm
        add_box(f"Forearm_{side_name}", location=(x_sign * 0.95, 1.05, 1.55), scale=(0.12, 0.25, 0.14), rotation=(math.radians(45), 0, 0), material=skin_mat)
        # 2 Hand claws
        for claw_idx, x_off in enumerate([-0.06, 0.06]):
            add_cone(
                f"HandClaw_{side_name}_{claw_idx}",
                location=(x_sign * 0.95 + x_off, 1.3, 1.45),
                scale=(0.04, 0.04, 0.12),
                rotation=(math.radians(70), 0, 0),
                material=horn_mat
            )

    # --- LIGHTING & CAMERA SETUP ---
    # Create dino target empty
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 1.8))
    target = bpy.context.active_object
    target.name = "Dino_Target"

    # Ambient World Lighting
    world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs["Color"].default_value = (0.5, 0.55, 0.6, 1.0)
        bg_node.inputs["Strength"].default_value = 1.0

    # Key Light (Sun)
    bpy.ops.object.light_add(type='SUN', location=(-8, 8, 12))
    sun = bpy.context.active_object
    sun.data.energy = 3.5
    sun_track = sun.constraints.new(type='TRACK_TO')
    sun_track.target = target
    sun_track.track_axis = 'TRACK_NEGATIVE_Z'
    sun_track.up_axis = 'UP_Y'

    # Fill Light (Warm point light from right side)
    bpy.ops.object.light_add(type='POINT', location=(6, 4, 5))
    fill = bpy.context.active_object
    fill.data.energy = 600.0
    fill.data.color = (1.0, 0.95, 0.85)

    # Rim Light (Blue rim from back)
    bpy.ops.object.light_add(type='POINT', location=(2, -7, 4))
    rim = bpy.context.active_object
    rim.data.energy = 800.0
    rim.data.color = (0.5, 0.8, 1.0)

    # Ground Shadow Plane
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane_mat = bpy.data.materials.new(name="Shadow_Catcher")
    bsdf_p = plane_mat.node_tree.nodes.get("Principled BSDF")
    if bsdf_p:
        bsdf_p.inputs["Base Color"].default_value = (0.15, 0.18, 0.16, 1.0)
    plane.data.materials.append(plane_mat)

    # Camera (Front-3/4 angle)
    bpy.ops.object.camera_add(location=(-6.5, 7.5, 4.0))
    camera = bpy.context.active_object
    bpy.context.scene.camera = camera
    
    # Track To Constraint
    track_constraint = camera.constraints.new(type='TRACK_TO')
    track_constraint.target = target
    track_constraint.track_axis = 'TRACK_NEGATIVE_Z'
    track_constraint.up_axis = 'UP_Y'
    camera.data.lens = 42

    # Render settings
    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    bpy.context.scene.render.resolution_x = 1024
    bpy.context.scene.render.resolution_y = 768
    bpy.context.scene.render.film_transparent = True

    # Output paths
    output_dir = r"z:\home\zkl-unix\repo\game\dino\assets\models"
    os.makedirs(output_dir, exist_ok=True)
    
    blend_path = os.path.join(output_dir, "t_rex.blend")
    glb_path = os.path.join(output_dir, "t_rex.glb")
    render_path = os.path.join(output_dir, "t_rex_render.png")

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[OK] Saved Blender project: {blend_path}")

    # Export GLB
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB')
    print(f"[OK] Exported GLTF / GLB: {glb_path}")

    # Render preview
    bpy.context.scene.render.filepath = render_path
    bpy.ops.render.render(write_still=True)
    print(f"[OK] Rendered preview image: {render_path}")

if __name__ == "__main__":
    create_dinosaur()
