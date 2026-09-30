# tools/generate_dinos.py
# EVERY DINOSAUR BUILT ANEW (GAME-DESIGN 7.1; the player, 2026-09-30: "精修恐龙blender形象，每个恐龙都要修，因为这是这个
# 游戏最重要的模型，它们最终要有个图鉴系统"): each species' skeleton laid out from its own proportions (tools/dino_rig.py),
# its body sculpted round it (tools/dino_body.py, tools/sculpt.py), the clips the game plays worked out for it
# (tools/dino_moves.py), all from its description (tools/dino_species.py) -- then exported, one glb a species.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_dinos.py
#   ... -- coelophysis         makes only that one
#   ... -- --preview           also renders each, standing and in each clip, to PREVIEW_DIR
#
# Its colours are at its vertices while it is being shaped; the skin's detail is baked to textures after
# (tools/dino_skin.py).

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = r"z:\home\zkl-unix\repo\game\dino"
sys.path.insert(1, os.path.join(REPO, "tools"))
from generate_flora import vertex_colour_material  # noqa: E402
import dino_body  # noqa: E402
import dino_moves  # noqa: E402
import dino_rig  # noqa: E402
import dino_skin  # noqa: E402
import dino_species  # noqa: E402

OUT = os.environ.get("DINOS_OUT", os.path.join(REPO, "assets", "models", "dinos"))
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", os.path.join(os.environ.get("TEMP", "."), "dinos_preview"))
# The paces the game draws a dinosaur's gaits at (Config.ANIMATIONS.gaits.dino): a clip's stride is worked out
# from them, so its feet stay put on the ground as it goes.
GAITS = {"walk": 1.6, "run": 4.0}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def game_height(name, spec):
    """How tall the game shows `name`, head and all (Config.DINOS.<name>.size.y) -- or, for an animal of the
    scenery, what its description says (its "height")."""
    import re
    text = open(os.path.join(REPO, "scripts", "autoload", "Config.gd"), encoding="utf-8").read()
    i = text.find("const DINOS")
    m = re.search(r'\n\t"%s": \{.*?"size": Vector3\(([^)]*)\)' % re.escape(spec.get("config", name)), text[i:], re.S)
    if m:
        return float(m.group(1).split(",")[1])
    return float(spec["height"])


def model_height(meshes):
    return max((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)


def described(name):
    """`name`'s description: its own, or another species' with its own changes laid over it ("same_as": the
    alpha is the pack's animal painted apart)."""
    import copy
    spec = dino_species.SPECIES[name]
    if "same_as" not in spec:
        return spec
    out = copy.deepcopy(described(spec["same_as"]))

    def lay(into, over):
        for key, value in over.items():
            if isinstance(value, dict) and isinstance(into.get(key), dict):
                lay(into[key], value)
            else:
                into[key] = copy.deepcopy(value)
    lay(out, {k: v for (k, v) in spec.items() if k != "same_as"})
    return out


def make(name):
    spec = described(name)
    reset()
    rig = dino_rig.Skeleton(spec["skeleton"])
    arm = rig.build(name)
    mats = [vertex_colour_material("Skin", 0.72, False), vertex_colour_material("Eye", 0.3, False)]
    parts = dino_body.build(name, rig, arm, spec["body"], mats)
    if "--flat" not in sys.argv:
        dino_skin.bake(parts[0], spec["body"].get("skin_detail", {}), size=spec["body"].get("texture", 2048), name=name,
                       normal_size=spec["body"].get("normal_texture", 1024))
    # The game fits it to its height (Config.VISUALS "fit"): its clips' strides are worked out at the paces it is
    # drawn at, in its own units -- so its feet stay put on the ground at the size the game shows it.
    if spec.get("fit") == "length":
        # Scenery fitted by its length (Config.HERDS).
        span = [(m.matrix_world @ v.co).y for m in parts for v in m.data.vertices]
        k = float(spec["length"]) / (max(span) - min(span))
    else:
        k = game_height(name, spec) / model_height(parts)
    paces = dict(GAITS)
    paces.update(spec.get("paces", {}))
    moves = dino_moves.Moves(rig, spec["moves"], {w: v / k for (w, v) in paces.items()})
    print("  %s: %.2f m tall as built, shown at x%.2f" % (name, model_height(parts), k))
    for clip, (frames, at, loop) in moves.all().items():
        dino_rig.key_clip(rig, clip, frames, at, loop)
    return rig, arm, parts


def export(arm, meshes, path):
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.context.scene.render.fps = dino_rig.FPS
    # Its mesh, bones and clips in a .gltf and its .bin, its skin's two images beside them: the game imports the
    # images as they are, where a .glb's would be kept twice (in it, and taken out of it on import).
    # Only the colours each part wears ("Col": the eyes'). Left to export them all, Blender 5.2 wrote a white
    # COLOR_0 "to keep the material unchanged" and the colours after it -- and the game, reading COLOR_0, gave
    # every animal white eyes.
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_anim_single_armature=True,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_image_format='AUTO', export_jpeg_quality=90)


def flat(name, rgb, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def preview(name, arm, meshes, clips=True):
    """Stills of it: standing, side on and three-quarter, its head close; and a few frames of each clip."""
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 960, 600
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.36, 0.4, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(50), 0.0, math.radians(35)))
    bpy.context.active_object.data.energy = 3.2
    bpy.ops.mesh.primitive_plane_add(size=20.0)
    bpy.context.active_object.data.materials.append(flat("Ground", (0.16, 0.19, 0.12)))
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for m in meshes:
        for v in m.data.vertices:
            p = m.matrix_world @ v.co
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    mid = (lo + hi) * 0.5
    # Far enough back that all of it is in the picture, long or tall (a 40 mm lens on the 36 mm frame, 960 x 600).
    size = max(hi.y - lo.y, (hi.z - lo.z) * 2.0, hi.x - lo.x)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 40
    os.makedirs(PREVIEW_DIR, exist_ok=True)

    def shot(fname, at, look):
        cam.location = at
        cam.rotation_euler = (look - at).normalized().to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, fname)
        bpy.ops.render.render(write_still=True)

    arm.animation_data_create()
    arm.animation_data.action = None
    scene.frame_set(1)
    shot(name + "_side.png", mid + Vector((size * 1.05, 0.0, size * 0.06)), mid)
    shot(name + "_three.png", mid + Vector((size * 0.62, size * 0.62, size * 0.25)), mid)
    head = arm.matrix_world @ arm.data.bones["Head"].head_local
    tip = arm.matrix_world @ arm.data.bones["Head"].tail_local
    hm = (head + tip) * 0.5
    hl = (tip - head).length
    shot(name + "_head.png", hm + Vector((hl * 2.2, hl * 1.2, hl * 0.6)), hm)
    # Its right hind foot from in front and a little inside: its toes and claws (a raptor's sickle is the inner).
    if "Foot.R" in arm.data.bones and "Toes.R" in arm.data.bones:
        a = arm.matrix_world @ arm.data.bones["Foot.R"].head_local
        b = arm.matrix_world @ arm.data.bones["Toes.R"].tail_local
        fm = (a + b) * 0.5
        fl = max(0.02, (b - a).length)
        shot(name + "_foot.png", fm + Vector((-fl * 0.9, fl * 2.4, fl * 0.7)), fm)
    shot(name + "_top.png", mid + Vector((0.0, 0.0, size * 1.1)) + Vector((0.001, 0.0, 0.0)), mid)
    if not clips:
        return
    for act in bpy.data.actions:
        arm.animation_data.action = act
        f0, f1 = act.frame_range
        for k, frac in enumerate((0.0, 0.25, 0.5, 0.75) if act.name != "death" else (0.0, 0.4, 0.7, 1.0)):
            scene.frame_set(int(round(f0 + (f1 - f0) * frac)))
            shot("%s_%s_%d.png" % (name, act.name, k), mid + Vector((size * 1.0, size * 0.2, size * 0.12)), mid - Vector((0.0, 0.0, size * 0.05)))
    arm.animation_data.action = None


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in args if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    for name in dino_species.SPECIES:
        if only and name not in only:
            continue
        rig, arm, parts = make(name)
        path = os.path.join(OUT, name + ".gltf")
        export(arm, parts, path)
        print("[OK] %s: %d verts, %.2f x %.2f x %.2f m, clips %s" % (
            name, sum(len(m.data.vertices) for m in parts), *parts[0].dimensions, [a.name for a in bpy.data.actions]))
        if "--preview" in args:
            preview(name, arm, parts, clips="--stills" not in args)


if __name__ == "__main__":
    main()
