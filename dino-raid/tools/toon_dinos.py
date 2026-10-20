# tools/toon_dinos.py
# OUR CREATURES, NINTENDO-STYLE (GAME-DESIGN 23; the user, 2026-10-19: "恐龙模型可以做的任天堂风格，不用那么写实了"):
# each nest's species built by the shared generator (common/tools: generate_dinos, dino_rig, dino_body, dino_moves)
# from its own description made friendlier -- a big round head and big eyes, a short neck and a short thick tail, a
# plump body on short stout legs, few small teeth, no skin texture -- and painted its nest's colours outright (a red
# nest's raptor is red, its belly cream), so the colour says whose it is. Its bones and clips are the generator's own,
# worked out again for the new proportions, so it walks, bites and falls as before.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python dino-raid/tools/toon_dinos.py
#   ... -- velociraptor         only that one
#   ... -- --preview            also renders each (side, three-quarter, head; and the clips) to PREVIEW_DIR
#
# Writes dino-raid/assets/models/toon/<species>.gltf (+ .bin).

import copy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
COMMON_TOOLS = os.path.join(os.path.dirname(GAME), "common", "tools")
sys.path.insert(0, COMMON_TOOLS)

import generate_dinos as gd  # noqa: E402
import dino_body  # noqa: E402
import dino_moves  # noqa: E402
import dino_rig  # noqa: E402

OUT = os.environ.get("TOON_OUT", os.path.join(GAME, "assets", "models", "toon"))

# Each species we use, its nest's colours: back, flank, belly (and its horny parts, plates and horns where it has
# them; a shell's plates, their rims, their bosses and its spikes). Bright and clean, the belly pale.
LOOKS = {
    "velociraptor": {"back": (0.78, 0.18, 0.14), "flank": (0.93, 0.36, 0.26), "belly": (0.99, 0.88, 0.74)},
    "coelophysis": {"back": (0.16, 0.36, 0.84), "flank": (0.36, 0.58, 0.96), "belly": (0.9, 0.94, 1.0)},
    "desmatosuchus": {"back": (0.36, 0.62, 0.24), "flank": (0.55, 0.78, 0.32), "belly": (0.95, 0.94, 0.72),
                      "shell": (0.16, 0.4, 0.18), "rim": (0.95, 0.9, 0.7), "boss": (0.3, 0.56, 0.26),
                      "spike": (0.98, 0.93, 0.74)},
    "allosaurus": {"back": (0.9, 0.58, 0.1), "flank": (0.98, 0.76, 0.28), "belly": (1.0, 0.94, 0.76)},
    "psittacosaurus": {"back": (0.72, 0.77, 0.86), "flank": (0.92, 0.93, 0.97), "belly": (1.0, 1.0, 1.0),
                       "horn": (0.98, 0.66, 0.3)},
    "dilong": {"back": (0.56, 0.42, 0.24), "flank": (0.76, 0.62, 0.42), "belly": (0.96, 0.9, 0.74)},
    "sinornithosaurus": {"back": (0.8, 0.3, 0.62), "flank": (0.94, 0.52, 0.78), "belly": (1.0, 0.9, 0.95)},
    "pterosaur": {"back": (0.9, 0.42, 0.14), "flank": (0.98, 0.62, 0.3), "belly": (1.0, 0.92, 0.78)},
    "stegosaurus": {"back": (0.24, 0.48, 0.88), "flank": (0.42, 0.66, 0.98), "belly": (0.9, 0.95, 1.0),
                    "horn": (0.98, 0.82, 0.36)},
    "sinocalliopteryx": {"back": (0.38, 0.72, 0.2), "flank": (0.58, 0.86, 0.36), "belly": (0.94, 1.0, 0.8)},
    "ceratosaurus": {"back": (0.8, 0.2, 0.08), "flank": (0.96, 0.4, 0.16), "belly": (1.0, 0.86, 0.66),
                     "horn": (0.24, 0.16, 0.12)},
    "tyrannosaurus": {"back": (0.45, 0.33, 0.22), "flank": (0.62, 0.48, 0.32), "belly": (0.94, 0.86, 0.7)},
}

# How each part's size changes, toward a friendlier creature: a short, round, blunt head; a short thick neck; a
# short plump body; a short tail thick to near its tip; short stout legs; bigger arms; big eyes.
SKULL = 0.78         # the skull's length
HEAD = 2.0           # its sections round it, at the back of the skull...
SNOUT = 0.8          # ...and this much more again at the snout's tip: blunt
NECK = 0.6
NECK_FAT = 1.5
SPINE = 0.78
BODY_WIDE = 1.45     # the body: wider and higher over the spine...
BODY_DEEP = 1.08     # ...but not much deeper under it, so the belly does not swallow the thighs
TAIL = 0.36
TAIL_FAT = 1.5       # at the root, growing toward the tip (TAIL_TIP more there): stubby, not a whip
TAIL_TIP = 1.2
LEGS = 0.76
THIGH_FAT = 1.4
LIMB_FAT = 1.9       # the shin and the foot
ARMS = 1.25
ARM_FAT = 1.9
EYES = 2.6
SHELL_REACH = 0.85   # a shell over less of the plumper body: its flanks show
SHELL_PEAKS = 0.45   # the long spikes at its shoulders, shorter

# Feathers as a cartoon draws them: no coat of filaments (it reads as hair) but a few broad feathers where they say
# "feathered" -- a crest on the head and neck, the wings and the tail's fan fewer and broader -- in the nest's
# colours, dark at the root and light at the tip; and a bristled tail's bristles as a row of quills. Lengths are
# in skulls (the head's own length, after it is made shorter).
CRESTS = {
    "dilong": {"from": ("Head", 0.55), "to": ("Neck2", 0.5), "length": (0.3, 0.6), "rise": 0.7, "spacing": 0.13,
               "width": 0.42},
    "sinocalliopteryx": {"from": ("Head", 0.4), "to": ("Spine3", 0.5), "length": (0.3, 0.75), "rise": 0.55,
                         "spacing": 0.13, "width": 0.42},
    "sinornithosaurus": {"from": ("Head", 0.45), "to": ("Neck2", 0.5), "length": (0.25, 0.5), "rise": 0.6,
                         "spacing": 0.14, "width": 0.42},
    "psittacosaurus": {"from": ("Tail1", 0.3), "to": ("Tail6", 0.5), "length": (0.35, 1.0), "rise": 1.6,
                       "spacing": 0.17, "width": 0.22, "quills": True},
}
TAIL_TUFTS = {"dilong": 0.8, "sinocalliopteryx": 1.0}


def _linear(c):
    """A colour as the screen shows it, as Blender keeps it (vertex colours are linear)."""
    return tuple(x ** 2.2 for x in c)


def toonify(name, spec):
    s = copy.deepcopy(spec)
    sk = s["skeleton"]
    length, pitch = sk["skull"]
    sk["skull"] = (length * SKULL, pitch * 0.5)
    if "jaw" in sk:
        j = sk["jaw"]
        sk["jaw"] = (j[0] * SKULL, j[1] * SKULL, j[2] * 0.5)
    if "jaw_hinge" in sk:
        sk["jaw_hinge"] *= SKULL
    sk["neck"] = [(l * NECK, a * 0.7) for (l, a) in sk["neck"]]
    sk["spine"] = [(l * SPINE, a) for (l, a) in sk["spine"]]
    sk["tail"] = [(l * TAIL, a) for (l, a) in sk["tail"]]
    hind = sk["limbs"].get("hind")
    if hind:
        hind["lengths"] = [x * LEGS for x in hind["lengths"]]
        sk["hip_height"] *= LEGS
    fore = sk["limbs"].get("fore")
    if fore and fore.get("arm"):
        fore["lengths"] = [x * ARMS for x in fore["lengths"]]
    body = s["body"]
    body["soften"] = max(float(body.get("soften", 0.0)), 0.14)
    body["rough"] = 0.0
    tails = len(sk["tail"])
    trunk = []
    for (bone, t, d) in body["trunk"]:
        d = dict(d)
        k = 1.0
        if bone in ("Head", "Head_end"):
            k = HEAD * (1.0 + SNOUT * max(0.0, min(1.0, t)))
        elif bone.startswith("Neck"):
            k = NECK_FAT
        elif bone.startswith("Spine") or bone == "Hips":
            d["w"] = d["w"] * BODY_WIDE
            d["top"] = d["top"] * BODY_WIDE
            d["bot"] = d["bot"] * BODY_DEEP
            trunk.append((bone, t, d))
            continue
        elif bone.startswith("Tail"):
            i = int(bone[4:]) if bone[4:].isdigit() else tails
            k = TAIL_FAT * (1.0 + TAIL_TIP * i / max(1, tails))
        for key in ("w", "top", "bot"):
            d[key] = d[key] * k
        trunk.append((bone, t, d))
    body["trunk"] = trunk
    if "eyes" in body:
        e = body["eyes"]
        e["radius"] = e["radius"] * EYES
        e["sunk"] = 0.55
        e["iris"] = (0.98, 0.8, 0.22)
        e["slit"] = 0.0
    for teeth in ("teeth", "lower_teeth"):
        if teeth in body:
            body[teeth]["count"] = max(4, int(body[teeth]["count"]) // 2)
            body[teeth]["length"] = body[teeth]["length"] * 0.6
            body[teeth]["radius"] = body[teeth]["radius"] * 1.2
    for gone in ("fossa", "brow"):
        body.pop(gone, None)
    for key, limb in body.get("limbs", {}).items():
        def fat(i):
            if key == "fore" and fore and fore.get("arm"):
                return ARM_FAT
            return THIGH_FAT if i == 0 else LIMB_FAT
        limb["stations"] = [(i, t, w * fat(i), dd * fat(i), f) for (i, t, w, dd, f) in limb["stations"]]
    body.pop("skin_detail", None)
    look = {k: _linear(v) for (k, v) in LOOKS.get(name, {}).items()}
    skin = body["skin"]
    for key in ("back", "flank", "belly"):
        if key in look:
            skin[key] = look[key]
    skin["throat"] = look.get("belly", skin.get("throat"))
    skin["mottle"] = 0.0
    for gone in ("bands", "eye_stripe", "spots", "flush"):
        skin.pop(gone, None)
    if "horn" in look:
        for part in ("plates", "horns", "back_plates", "frill", "carapace"):
            if part in body and isinstance(body[part], dict):
                body[part]["colour"] = look["horn"]
    if "carapace" in body and "shell" in look:
        cp = body["carapace"]
        cp["colour"] = look["shell"]
        cp["rim"] = look["rim"]
        cp["boss_colour"] = look["boss"]
        cp["spike"] = look["spike"]
        cp["tip"] = look["spike"]
        cp["vary"] = 0.04
        cp["reach"] = [(at, deg * SHELL_REACH) for (at, deg) in cp["reach"]]
        for peak in cp.get("peaks", []):
            peak["length"] = peak["length"] * SHELL_PEAKS
    _feathers(name, body, sk, look)
    return s


def _feathers(name, body, sk, look):
    body.pop("fuzz", None)
    skull = sk["skull"][0]
    deep = look.get("back")
    light = look.get("flank")
    if "wings" in body:
        wg = body["wings"]
        wg["forearm"] = max(3, wg["forearm"] * 3 // 5)
        wg["hand"] = max(3, wg["hand"] * 3 // 5)
        wg["secondaries"] = tuple(x * 1.3 for x in wg["secondaries"])
        wg["primaries"] = tuple(x * 1.3 for x in wg["primaries"])
        wg["width"] = wg["width"] * 1.5
        wg["colour"], wg["tip"] = deep, light
    if "tail_fan" in body:
        fan = body["tail_fan"]
        fan["spacing"] = fan["spacing"] * 1.8
        fan["width"] = fan["width"] * 1.4
        fan["length"] = tuple(x * 1.3 for x in fan["length"])
        fan["colour"], fan["tip"] = deep, light
    elif name in TAIL_TUFTS:
        k = TAIL_TUFTS[name]
        body["tail_fan"] = {"from": ("Tail4", 0.0), "length": (0.25 * k * skull, 0.6 * k * skull),
                            "spread": (40.0, 10.0), "spacing": 0.14 * skull, "width": 0.4, "droop": 0.05,
                            "colour": deep, "tip": light}
    crest = CRESTS.get(name)
    if crest:
        colour = look.get("horn", deep) if crest.get("quills") else deep
        tip = tuple(min(1.0, c * 0.6 + 0.4) for c in colour) if crest.get("quills") else light
        body["plumes"] = {"from": crest["from"], "to": crest["to"], "rows": [0.0], "rise": crest["rise"],
                          "length": tuple(x * skull for x in crest["length"]), "spacing": crest["spacing"] * skull,
                          "width": crest["width"], "colour": colour, "tip": tip}


def make(name):
    spec = toonify(name, gd.described(name))
    gd.reset()
    rig = dino_rig.Skeleton(spec["skeleton"])
    arm = rig.build(name)
    mats = [gd.vertex_colour_material("Skin", 0.6, False), gd.vertex_colour_material("Eye", 0.25, False)]
    parts = dino_body.build(name, rig, arm, spec["body"], mats)
    k = float(spec.get("height", 1.0)) / gd.model_height(parts)
    paces = dict(gd.GAITS)
    paces.update(spec.get("paces", {}))
    moves = dino_moves.Moves(rig, spec["moves"], {w: v / k for (w, v) in paces.items()})
    for clip, (frames, at, loop) in moves.all().items():
        dino_rig.key_clip(rig, clip, frames, at, loop)
    return rig, arm, parts


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for a in args if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    for name in LOOKS:
        if only and name not in only:
            continue
        rig, arm, parts = make(name)
        path = os.path.join(OUT, name + ".gltf")
        gd.export(arm, parts, path)
        print("[OK] %s: %d verts" % (name, sum(len(m.data.vertices) for m in parts)))
        if "--preview" in args:
            gd.preview(name, arm, parts, clips="--stills" not in args)


if __name__ == "__main__":
    main()
