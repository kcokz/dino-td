# tools/dino_feathers.py
# FEATHERS (GAME-DESIGN 7.1; the player, 2026-09-30: "精修恐龙blender形象，每个恐龙都要修"). A dromaeosaur was
# feathered: Velociraptor's forearm bears quill knobs, where a bird's wing feathers are anchored; its relatives
# preserved in fine-grained rock have a coat of feathers over the body, a fan of long feathers down the tail and
# scales left only on the feet and the face. So the raptors are drawn:
#
#   THE WING: long feathers rooted along the forearm's and the hand's back edge, lying back along the flank as a
#   folded wing lies -- longest at the hand -- each moving with the bone it grows from.
#   THE TAIL'S FAN: feathers out from either side of the tail's far part, spread sideways and back, longest near
#   the tip.
#   PLUMES, where a species has them: a crest of longer feathers along the back of the head and the neck.
#   THE COAT: the body's own skin, where it is feathered, drawn as plumage in the bake (tools/dino_skin.py) --
#   overlapping feather tips and fine streaks where the rest of the skin is scales.
#
# Each feather is a blade: its shaft down the middle, raised a little, a vane either side (the trailing one the
# wider on a flight feather), curving at the tip. Its vertices carry where on the vane they are (the "Feather"
# attribute: along the shaft, and across it) so the bake draws the barbs, the shaft and bars across it.
#
# Blender only (bpy through sculpt); used by tools/dino_body.py.

import math

from mathutils import Vector

import sculpt as sc


def _deg(x):
    return math.radians(x)


def feather(body, root, along, normal, length, width, root_colour, tip_colour, weights, curve=0.12, asym=0.5,
            stations=7):
    """A feather from `root` along `along` (its shaft), lying with its face towards `normal`: `width` across at its
    broadest, its tip curving back towards `-normal` by `curve` of its length, the vane on the trailing side
    `asym` of its width. Coloured from `root_colour` to `tip_colour`."""
    a = along.normalized()
    n = (normal - a * normal.dot(a)).normalized()
    side = a.cross(n).normalized()
    rows = []
    for i in range(stations):
        u = i / (stations - 1)
        # Narrow at the quill, broad along its length, rounded to its tip.
        envelope = sc.smoothstep(0.0, 0.18, u) * (1.0 - 0.85 * sc.smoothstep(0.72, 1.0, u))
        centre = root + a * (length * u) - n * (curve * length * u * u)
        shaft = centre + n * (width * 0.04 * (1.0 - u))
        col = sc.mix(root_colour, tip_colour, sc.smoothstep(0.35, 1.0, u))
        lead = centre - side * (width * (1.0 - asym) * envelope) - n * (width * 0.03 * envelope)
        trail = centre + side * (width * asym * envelope) - n * (width * 0.03 * envelope)
        rows.append([body.add(lead, col, weights, feather=(0.0, 1.0, u, 0.0)),
                     body.add(shaft, col, weights, feather=(0.0, 1.0, u, 0.5)),
                     body.add(trail, col, weights, feather=(0.0, 1.0, u, 1.0))])
    for r0, r1 in zip(rows, rows[1:]):
        body.face((r0[0], r0[1], r1[1], r1[0]))
        body.face((r0[1], r0[2], r1[2], r1[1]))


def wings(body, sk, rig, spec, skin):
    """The wing feathers of each arm: along its forearm and hand, lying back and a little down along the flank."""
    wg = spec.get("wings")
    if not wg:
        return
    for key, info in rig.limbs.items():
        if not key.startswith("fore"):
            continue
        names = info["names"]
        sign = -1.0 if key.endswith(".L") else 1.0
        outward = Vector((sign, 0.0, 0.0))
        for bone, count, lengths in ((names[1], wg["forearm"], wg["secondaries"]), (names[2], wg["hand"], wg["primaries"])):
            a, b = sk.head[bone], sk.tail[bone]
            for k in range(count):
                t = 0.12 + 0.83 * (k + 0.5) / count
                # On the arm's outside, clear of the flank it folds against.
                root = a + (b - a) * t + outward * wg.get("lift", 0.0)
                f = k / max(1, count - 1)
                length = lengths[0] + (lengths[1] - lengths[0]) * f
                # Back along the body, down a little, and out from it.
                along = (Vector((0.0, -1.0, 0.0)) + sc.UP * -wg.get("droop", 0.35) + outward * wg.get("splay", 0.1))
                along = along.normalized()
                feather(body, root, along, outward, length, length * wg.get("width", 0.26),
                        wg["colour"], wg.get("tip", wg["colour"]), {bone: 1.0}, curve=wg.get("curve", 0.1),
                        asym=0.62)


def tail_fan(body, loft, path, spec):
    """Feathers out from either side of the tail's far part: spread back and sideways, lying level, longest near
    the tip, the last ones straight back."""
    fan = spec.get("tail_fan")
    if not fan:
        return
    s0 = path.s_of(*fan["from"])
    s1 = path.s_of("Tail_end", 0.0)
    s = s0
    while s < s1:
        f = (s - s0) / max(1e-6, s1 - s0)
        c, t, x, u = loft.frame(s)
        length = fan["length"][0] + (fan["length"][1] - fan["length"][0]) * math.sin(math.pi * 0.5 * min(1.0, f * 1.15))
        spread = _deg(fan["spread"][0] + (fan["spread"][1] - fan["spread"][0]) * f)
        w = path.weights(s, loft.blend)
        for sign in (1.0, -1.0):
            p, n = loft.surface(s, math.pi * 0.5 if sign > 0 else math.pi * 1.5)
            along = (t * math.cos(spread) + x * (sign * math.sin(spread)) - u * fan.get("droop", 0.05)).normalized()
            feather(body, p - n * 0.002, along, u, length, length * fan.get("width", 0.22), fan["colour"],
                    fan.get("tip", fan["colour"]), w, curve=0.04, asym=0.5, stations=6)
        # The next pair a little on, a little longer or shorter by chance: a fan grown, not stamped.
        s += fan["spacing"]
    # The tip: a few straight back.
    c, t, x, u = loft.frame(s1)
    w = path.weights(s1, loft.blend)
    for k, off in enumerate((-1.0, 0.0, 1.0)):
        along = (t + x * (0.12 * off)).normalized()
        feather(body, c - t * 0.01, along, u, fan["length"][1] * 0.9, fan["length"][1] * 0.2, fan["colour"],
                fan.get("tip", fan["colour"]), w, curve=0.03, asym=0.5, stations=6)


def plumes(body, loft, path, spec):
    """A crest: longer feathers along the top of the head and the neck, lying back and up."""
    pl = spec.get("plumes")
    if not pl:
        return
    a, b = sorted((path.s_of(*pl["from"]), path.s_of(*pl["to"])))
    s = a
    while s <= b:
        f = (s - a) / max(1e-6, b - a)
        c, t, x, u = loft.frame(s)
        w = path.weights(s, loft.blend)
        length = pl["length"][0] + (pl["length"][1] - pl["length"][0]) * math.sin(math.pi * f)
        for phi in pl.get("rows", [0.0]):
            for sign in ((1.0,) if phi == 0.0 else (1.0, -1.0)):
                p, n = loft.surface(s, _deg(phi) if sign > 0 else 2.0 * math.pi - _deg(phi))
                along = (t * 0.85 + u * pl.get("rise", 0.45) + x * (sign * math.sin(_deg(phi)) * 0.3)).normalized()
                feather(body, p - n * 0.001, along, n, length, length * pl.get("width", 0.2), pl["colour"],
                        pl.get("tip", pl["colour"]), w, curve=0.15, asym=0.5, stations=6)
        s += pl["spacing"]


def coat(body, path, spec, trunk_count, limb_count, feathered_bones):
    """How feathered each vertex of the body and the limbs is (the "Feather" attribute's first channel): the
    body from behind the eyes to the tail's tip, the limbs' bones named in `feathered_bones` -- the feet, the
    hands and the face left in scales."""
    ct = spec.get("coat")
    if not ct:
        return
    s_face = path.s_of(*ct.get("face", ("Head", 0.35)))
    s_bare = path.s_of(*ct.get("bare", ("Head", 0.5)))
    for i in range(limb_count):
        if i < trunk_count:
            s = body.tag[i]
            k = 1.0 if s is None else sc.smoothstep(min(s_bare, s_face), max(s_bare, s_face), s)
        else:
            w = body.w[i]
            total = sum(w.values()) or 1.0
            k = sum(x for b, x in w.items() if b.split(".")[0] in feathered_bones) / total
        f = body.feather[i]
        body.feather[i] = (k, f[1], f[2], f[3])
