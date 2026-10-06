# tools/generate_wreck.py
# Procedural low-poly Spaceship Wreck (Core Building) generator for Defend Dinosaur v0.5.
# Generates assets/models/wreck.glb and assets/models/wreck.blend using Blender 5.2.
#
# Proportions:
#   Authored in Blender:
#     X: [-0.47, 0.47] (width ~0.94m)
#     Y: [-0.47, 0.47] (depth ~0.94m)
#     Z: [0.00, 1.86]  (height ~1.86m)
#   When fitted by VisualLibrary.fit() into Vector3(1.0, 1.9, 1.0):
#     Fitted width  ~0.96m <= 1.0m (strictly inside collision footprint)
#     Fitted depth  ~0.96m <= 1.0m (strictly inside collision footprint)
#     Fitted height ~1.89m (imposing landmark, taller than the 1.6m Hero)

import bpy
import math
import os

OUTPUT_DIR = r"z:\home\zkl-unix\repo\game\dino\assets\models"

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_material(name, base_color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
    return mat

def build_spaceship_wreck():
    reset_scene()

    # 1. Materials Palette
    mats = {
        # Aerospace composite primary plating (Crisp off-white / silver titanium)
        "hull": create_material("Wreck_Hull", (0.82, 0.84, 0.88, 1.0), roughness=0.35, metallic=0.5),
        # Heat shield carbon tiles (Underbelly & re-entry surface)
        "heat_shield": create_material("Wreck_HeatShield", (0.14, 0.14, 0.16, 1.0), roughness=0.85, metallic=0.1),
        # High-visibility emergency aerospace markings
        "hazard_orange": create_material("Wreck_Hazard", (0.94, 0.40, 0.06, 1.0), roughness=0.45, metallic=0.15),
        # Polarized reinforced canopy glass
        "canopy": create_material("Wreck_Canopy", (0.04, 0.08, 0.15, 1.0), roughness=0.15, metallic=0.85),
        # Engine bell & thruster exhaust alloy
        "thruster": create_material("Wreck_Thruster", (0.28, 0.28, 0.32, 1.0), roughness=0.3, metallic=0.9),
        # Internal titanium spars & structural ribbing
        "internal_frame": create_material("Wreck_Frame", (0.46, 0.48, 0.52, 1.0), roughness=0.5, metallic=0.75),
        # Charred re-entry burn & blast scorch
        "scorch": create_material("Wreck_Scorch", (0.06, 0.06, 0.07, 1.0), roughness=0.9, metallic=0.0),
        # Wiring harnesses & emergency conduits
        "wiring": create_material("Wreck_Wiring", (0.88, 0.65, 0.12, 1.0), roughness=0.6, metallic=0.2),
    }

    mesh_objects = []

    def add_cube(name, loc, scale, rot=(0, 0, 0), mat=mats["hull"]):
        # primitive_cube default size is 2x2x2; scale=(sx, sy, sz) makes dimensions (2*sx, 2*sy, 2*sz)
        bpy.ops.mesh.primitive_cube_add(location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        mesh_objects.append(obj)
        return obj

    def add_cylinder(name, loc, scale, rot=(0, 0, 0), vertices=10, mat=mats["thruster"]):
        # primitive_cylinder default r=1, h=2; scale=(sx, sy, sz) makes r=(sx+sy)/2, h=2*sz
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, location=loc, scale=scale, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        mesh_objects.append(obj)
        return obj

    # Steep crash impact angle: ~35 degrees pitch forward-down
    crash_pitch = math.radians(35)

    # --------------------------------------------------------------------------
    # 1. GROUND IMPACT FOUNDATION & CRUMPLED NOSE
    # --------------------------------------------------------------------------
    # Impact furrow / crushed nose resting in dirt
    add_cube("Wreck_Impact_Footing", (0.0, -0.22, 0.10), (0.36, 0.22, 0.10), (0, 0, 0), mats["heat_shield"])
    add_cube("Wreck_Nose_Crushed", (0.0, -0.28, 0.24), (0.28, 0.18, 0.14), (crash_pitch + math.radians(15), 0, 0), mats["scorch"])

    # --------------------------------------------------------------------------
    # 2. MAIN LOWER COMMAND CAPSULE (MIDSECTION)
    # --------------------------------------------------------------------------
    # Main lower cabin hull block
    add_cube("Wreck_Lower_Hull", (0.0, -0.08, 0.68), (0.38, 0.36, 0.38), (crash_pitch, 0, 0), mats["hull"])
    # Heat shield tile underbelly
    add_cube("Wreck_Lower_Shield", (0.0, -0.20, 0.58), (0.39, 0.12, 0.36), (crash_pitch, 0, 0), mats["heat_shield"])
    # Orange emergency hatch & hazard identification bands
    add_cube("Wreck_Hatch_Door", (-0.38, -0.06, 0.68), (0.02, 0.18, 0.24), (crash_pitch, 0, 0), mats["hazard_orange"])
    add_cube("Wreck_Hatch_Stripe_R", (0.38, -0.06, 0.68), (0.02, 0.24, 0.08), (crash_pitch, 0, 0), mats["hazard_orange"])

    # Polarized Cockpit Canopy (front-facing observation visor)
    add_cube("Wreck_Canopy_Main", (0.0, -0.26, 0.88), (0.28, 0.14, 0.22), (crash_pitch - math.radians(14), 0, 0), mats["canopy"])
    add_cube("Wreck_Canopy_Frame", (0.0, -0.25, 0.90), (0.30, 0.04, 0.24), (crash_pitch - math.radians(14), 0, 0), mats["internal_frame"])

    # --------------------------------------------------------------------------
    # 3. UPPER HULL & PROPULSION MODULE (TALL IMPOSING SILHOUETTE)
    # --------------------------------------------------------------------------
    # Upper equipment bay & reactor housing
    add_cube("Wreck_Upper_Hull", (0.0, 0.08, 1.22), (0.32, 0.30, 0.32), (crash_pitch, 0, 0), mats["hull"])
    add_cube("Wreck_Upper_Shield", (0.0, -0.02, 1.15), (0.33, 0.08, 0.30), (crash_pitch, 0, 0), mats["heat_shield"])
    add_cube("Wreck_Upper_Stripe", (0.0, 0.12, 1.25), (0.33, 0.28, 0.06), (crash_pitch, 0, 0), mats["hazard_orange"])

    # Main Sub-Light Thruster Engine Bell (Tilted high rearward)
    add_cylinder("Wreck_Main_Thruster", (0.0, 0.22, 1.55), (0.22, 0.22, 0.20), (crash_pitch + math.radians(90), 0, 0), vertices=10, mat=mats["thruster"])
    add_cylinder("Wreck_Thruster_Chamber", (0.0, 0.26, 1.62), (0.16, 0.16, 0.14), (crash_pitch + math.radians(90), 0, 0), vertices=8, mat=mats["scorch"])

    # Dorsal Stabilizer Fin & Comm Antenna Mast (Reaching peak height ~1.85m)
    add_cube("Wreck_Dorsal_Fin", (0.0, 0.14, 1.62), (0.05, 0.26, 0.24), (crash_pitch + math.radians(6), math.radians(4), 0), mats["hull"])
    add_cube("Wreck_Dorsal_Scorch", (0.0, 0.22, 1.68), (0.06, 0.15, 0.16), (crash_pitch + math.radians(6), math.radians(4), 0), mats["scorch"])
    add_cylinder("Wreck_Antenna_Pylon", (0.12, 0.02, 1.74), (0.025, 0.025, 0.12), (crash_pitch + math.radians(10), math.radians(8), 0), vertices=6, mat=mats["internal_frame"])

    # --------------------------------------------------------------------------
    # 4. DAMAGED AERODYNAMIC WINGS & EXPOSED INTERNAL TITANIUM FRAME
    # --------------------------------------------------------------------------
    # Starboard Wing Stub (Right: clipped aerodynamic wing with upward bend)
    add_cube("Wreck_Wing_R_Root", (0.42, 0.02, 0.85), (0.05, 0.26, 0.18), (crash_pitch, math.radians(18), math.radians(-6)), mats["hull"])
    add_cube("Wreck_Wing_R_Tip", (0.45, 0.04, 0.98), (0.02, 0.16, 0.12), (crash_pitch, math.radians(28), math.radians(-12)), mats["hazard_orange"])

    # Port Wing (Left: sheared violently, jagged structural ribbing & orange wiring)
    add_cube("Wreck_Wing_L_Stub", (-0.40, 0.02, 0.82), (0.03, 0.24, 0.16), (crash_pitch, math.radians(-12), 0), mats["hull"])
    add_cube("Wreck_Rib_1", (-0.43, -0.06, 0.78), (0.03, 0.03, 0.14), (crash_pitch, math.radians(-8), math.radians(15)), mats["internal_frame"])
    add_cube("Wreck_Rib_2", (-0.44, 0.10, 0.86), (0.03, 0.03, 0.12), (crash_pitch, math.radians(-15), math.radians(-10)), mats["internal_frame"])
    add_cylinder("Wreck_Cable_1", (-0.42, 0.02, 0.75), (0.015, 0.015, 0.12), (0, math.radians(70), 0), vertices=6, mat=mats["wiring"])
    add_cylinder("Wreck_Cable_2", (-0.43, 0.05, 0.72), (0.012, 0.012, 0.10), (math.radians(15), math.radians(80), 0), vertices=6, mat=mats["wiring"])

    # Lateral Reaction Control Thrusters (RCS blocks)
    add_cube("Wreck_RCS_L", (-0.37, 0.18, 1.18), (0.05, 0.08, 0.08), (crash_pitch, 0, 0), mats["thruster"])
    add_cube("Wreck_RCS_R", (0.37, 0.18, 1.18), (0.05, 0.08, 0.08), (crash_pitch, 0, 0), mats["thruster"])

    # --------------------------------------------------------------------------
    # JOIN ALL INTO COHERENT OBJECT
    # --------------------------------------------------------------------------
    bpy.ops.object.select_all(action='DESELECT')
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objects[0]
    bpy.ops.object.join()

    wreck_obj = bpy.context.active_object
    wreck_obj.name = "Spaceship_Wreck"

    # Save Blender project
    blend_path = os.path.join(OUTPUT_DIR, "wreck.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[OK] Saved Blender project: {blend_path}")

    # Export glTF / GLB
    glb_path = os.path.join(OUTPUT_DIR, "wreck.glb")
    bpy.ops.object.select_all(action='DESELECT')
    wreck_obj.select_set(True)
    bpy.context.view_layer.objects.active = wreck_obj

    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        use_selection=True,
    )
    print(f"[OK] Exported GLB: {glb_path}")

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("==================================================")
    print("Generating Proportional Spaceship Wreck for Defend Dinosaur")
    print("==================================================")
    build_spaceship_wreck()
    print("==================================================")
    print("Spaceship Wreck generation completed successfully!")
    print("==================================================")
