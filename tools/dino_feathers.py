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
#   FUZZ, where a species was clothed in filaments rather than vaned feathers (the Jehol's tyrannosauroids and
#   compsognathids -- Yutyrannus's up to 20 cm long, Xu et al. 2012): tufts of them standing a little off the skin
#   and lying back along it, hanging under their own weight, coloured as the skin they grow from -- over the body
#   and along the limbs, so the animal's outline is shaggy, not smooth.
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


def tuft(body, root, along, normal, length, width, colour, weights, curve=0.1, droop=0.3, twist=0.0):
    """A tuft of filaments from `root` along `along`, its face towards `normal` (turned `twist` radians about
    itself): `width` across at its root, tapering to a point; its tip curving back towards the skin by `curve` of
    its length and hanging by `droop` of it. Five vertices -- a coat is thousands of them -- coloured `colour`
    (what it shows unbaked: baked, it wears the skin's texture where it grows, tools/dino_skin.py)."""
    a = along.normalized()
    n = normal - a * normal.dot(a)
    n = n.normalized() if n.length > 1e-6 else sc.UP.copy()
    side = a.cross(n).normalized()
    face = n * math.cos(twist) + side * math.sin(twist)
    side = a.cross(face).normalized()

    def at(u):
        return root + a * (length * u) - n * (curve * length * u * u) - sc.UP * (droop * length * u * u)
    plumage = (1.0, 0.0, 0.0, 0.0)
    r0 = [body.add(at(0.0) - side * (width * 0.5), colour, weights, feather=plumage),
          body.add(at(0.0) + side * (width * 0.5), colour, weights, feather=plumage)]
    r1 = [body.add(at(0.5) - side * (width * 0.42), colour, weights, feather=plumage),
          body.add(at(0.5) + side * (width * 0.42), colour, weights, feather=plumage)]
    end = body.add(at(1.0), colour, weights, feather=plumage)
    body.face((r0[0], r0[1], r1[1], r1[0]))
    body.face((r1[0], r1[1], end))


def _through(points, x):
    """The value at `x` on a run of (x, value) points, straight between them, level past the ends."""
    if x <= points[0][0]:
        return points[0][1]
    for (x0, v0), (x1, v1) in zip(points, points[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * (x - x0) / max(1e-9, x1 - x0)
    return points[-1][1]


def _arc(points):
    """How long a polyline is, and a function from a length along it to the fraction of the way through its
    points there."""
    cum = [0.0]
    for p, q in zip(points, points[1:]):
        cum.append(cum[-1] + (q - p).length)

    def at(d):
        for k in range(len(cum) - 1):
            if d <= cum[k + 1] or k == len(cum) - 2:
                seg = max(1e-9, cum[k + 1] - cum[k])
                return (k + max(0.0, min(1.0, (d - cum[k]) / seg))) / (len(cum) - 1)
        return 1.0
    return cum[-1], at


def _spread(rng, count, arc_at, total, jitter=0.6):
    """`count` places spread evenly along an arc `total` long, each moved by chance up to `jitter` of a gap: the
    fraction of the way round each is (`arc_at`)."""
    out = []
    for j in range(count):
        f = (j + 0.5 + (rng.random() - 0.5) * jitter) / count
        out.append(arc_at(max(0.0, min(1.0, f)) * total))
    return out


def fuzz(body, sk, rig, loft, path, spec, paint):
    """A coat of filaments (spec "fuzz"). Over the trunk ("trunk": patches), each patch from `from` to `to` along
    it and `phi` degrees round from the top on both sides, its tufts `spacing` apart along it and `gap` apart
    round it, as long as `length` says there (anchors along the body, straight between) times `around` (a factor
    by the angle round). Along the limbs ("limbs"): `limb` "fore" or "hind", from (bone, t) to (bone, t) down it
    (0 the thigh or upper arm, 1 the shin or forearm, 2 the foot or hand), `around` degrees round it -- 0 the
    outside, 90 the front, 180 the inside, 270 the back -- `length` at its top and at its bottom. Each tuft stands
    `lie` degrees off the skin, lying back along the body (down the limb), hangs by `droop` and curls back by
    `curve` (of its length), `width` of its length across, turned up to `twist` degrees about itself and leaning
    up to `askew` of its length to one side, its length varying by `jitter` -- by a chance drawn from `seed`, so
    the same coat grows each time. Any of these set on the coat holds for all its patches unless a patch says
    otherwise. Each moves with the skin it grows from, and wears its colours: the bake lays each tuft on the
    skin's texture where it grows (tools/dino_skin.py) -- so the coat's colours and marks are the skin's
    ("skin")."""
    fz = spec.get("fuzz")
    if not fz:
        return
    import random
    rng = random.Random(fz.get("seed", 7))
    start = len(body.v)
    for patch in fz.get("trunk", []):
        _trunk_fuzz(body, loft, path, patch, fz, paint, rng)
    for patch in fz.get("limbs", []):
        _limb_fuzz(body, sk, rig, spec, patch, fz, rng)
    print("  fuzz: %d tufts, %d vertices" % ((len(body.v) - start) // 5, len(body.v) - start))


def mark_tufts(obj, body, start, end):
    """Which of the skin object's vertices are the coat's tufts (`body`'s vertices `start` to `end`), and which tuft
    each is of -- the "Tuft" attribute, 1 for the first tuft, 2 for the next: the bake lays each on the skin's own
    texture where it grows (tools/dino_skin.py), rather than giving thousands of them room of their own in it."""
    used = sorted({i for f, fm in zip(body.f, body.fm) if fm == 0 for i in f})
    index = {old: new for new, old in enumerate(used)}
    attr = obj.data.attributes.new("Tuft", 'FLOAT', 'POINT')
    for old in range(start, end):
        if old in index:
            attr.data[index[old]].value = 1.0 + (old - start) // 5


def _opt(patch, fz, key, default):
    return patch.get(key, fz.get(key, default))


def _trunk_fuzz(body, loft, path, pt, fz, paint, rng):
    a, b = sorted((path.s_of(*pt["from"]), path.s_of(*pt["to"])))
    lengths = sorted((path.s_of(*at), length) for (at, length) in pt["length"])
    around = sorted(pt.get("around", [(0.0, 1.0)]))
    phi0, phi1 = (_deg(v) for v in pt.get("phi", (0.0, 150.0)))
    spacing = pt["spacing"]
    gap = pt.get("gap", spacing)
    lie = _deg(_opt(pt, fz, "lie", 15.0))
    width = _opt(pt, fz, "width", 0.25)
    jitter = _opt(pt, fz, "jitter", 0.25)
    twist = _deg(_opt(pt, fz, "twist", 30.0))
    askew = _opt(pt, fz, "askew", 0.15)
    s = a + spacing * 0.5 * rng.random()
    while s <= b:
        samples = [loft.surface(s, phi0 + (phi1 - phi0) * i / 12.0)[0] for i in range(13)]
        total, arc_at = _arc(samples)
        count = max(1, int(round(total / gap)))
        base = _through(lengths, s)
        for sign in (1.0, -1.0):
            for f in _spread(rng, count, arc_at, total):
                phi = phi0 + (phi1 - phi0) * f
                s_j = min(b, max(a, s + (rng.random() - 0.5) * spacing * 0.7))
                length = base * _through(around, math.degrees(phi)) * (1.0 + (rng.random() * 2.0 - 1.0) * jitter)
                if length < 0.002:
                    continue
                phi_s = phi if sign > 0 else 2.0 * math.pi - phi
                p, n = loft.surface(s_j, phi_s)
                c, t, x, u = loft.frame(s_j)
                # Back along the body, standing off it, a little askew by chance as a coat lies.
                along = t * math.cos(lie) + n * math.sin(lie) + x * ((rng.random() * 2.0 - 1.0) * askew)
                tuft(body, p - n * (width * length * 0.15), along, n, length, width * length,
                     paint(s_j, phi_s, p, n), path.weights(s_j, loft.blend), curve=_opt(pt, fz, "curve", 0.1),
                     droop=_opt(pt, fz, "droop", 0.3), twist=twist * (rng.random() * 2.0 - 1.0))
        s += spacing


def _limb_fuzz(body, sk, rig, spec, pt, fz, rng):
    skin = spec["skin"]
    limb_spec = spec["limbs"][pt["limb"]]
    lie = _deg(_opt(pt, fz, "lie", 15.0))
    width = _opt(pt, fz, "width", 0.25)
    jitter = _opt(pt, fz, "jitter", 0.25)
    twist = _deg(_opt(pt, fz, "twist", 30.0))
    askew = _opt(pt, fz, "askew", 0.15)
    spacing = pt["spacing"]
    gap = pt.get("gap", spacing)
    a0, a1 = pt.get("around", (0.0, 360.0))
    for key, info in rig.limbs.items():
        if key.split(".")[0] != pt["limb"]:
            continue
        # The limb's own tube (tools/dino_body.py _limb), laid out again to find its skin.
        names = info["names"]
        links = [(n, False) for n in names[:3]]
        stations = [(names[int(st[0])],) + tuple(st[1:]) for st in limb_spec["stations"]]
        lb = sc.Limb(sk, links, stations, around=limb_spec.get("around", 14), step=limb_spec.get("step", 0.02))
        top_s, end_s = lb.stations[0]["s"], lb.stations[-1]["s"]
        sa = max(top_s, lb.path.s_of(names[pt["from"][0]], pt["from"][1]))
        sb = min(end_s, lb.path.s_of(names[pt["to"][0]], pt["to"][1]))
        right = info["sign"] > 0
        s = sa + spacing * 0.5 * rng.random()
        while s <= sb:
            c, t, x, f = lb.frame(s)
            w, d, shift = lb.section3(s)

            def ring(local_deg):
                # Mirrored for the left limb: 0 is always the outside, 90 the front.
                ang = _deg(local_deg if right else 180.0 - local_deg)
                return (c + f * shift + x * (w * math.cos(ang)) + f * (d * math.sin(ang)),
                        (x * (math.cos(ang) / max(1e-4, w)) + f * (math.sin(ang) / max(1e-4, d))).normalized())
            samples = [ring(a0 + (a1 - a0) * i / 12.0)[0] for i in range(13)]
            total, arc_at = _arc(samples)
            count = max(1, int(round(total / gap)))
            k = (s - sa) / max(1e-6, sb - sa)
            base = pt["length"][0] + (pt["length"][1] - pt["length"][0]) * k
            wt = lb.path.weights(s, lb.blend)
            down = (s - top_s) / max(0.01, end_s - top_s)
            for frac in _spread(rng, count, arc_at, total):
                p, n = ring(a0 + (a1 - a0) * frac)
                length = base * (1.0 + (rng.random() * 2.0 - 1.0) * jitter)
                # The limb's own colours, as tools/dino_body.py _limb paints them: the flank's outside, paler
                # inside, darker over its top and down the shank.
                out = n.dot(sk.side) * (1.0 if p.dot(sk.side) > 0 else -1.0)
                col = sc.mix(sc.mix(skin["flank"], skin["belly"], 0.35), skin["flank"],
                             sc.smoothstep(-0.7, 0.3, out + 0.5 * n.dot(sc.UP)))
                col = sc.mix(col, sc.mix(skin["flank"], skin["back"], 0.5),
                             0.7 * (1.0 - sc.smoothstep(0.0, 0.4, down))
                             * sc.smoothstep(-0.3, 0.6, n.dot(sc.UP) + out * 0.6))
                col = sc.shade(col, -skin.get("shank_dark", 0.2) * sc.smoothstep(0.45, 1.0, down))
                along = t * math.cos(lie) + n * math.sin(lie) + f * ((rng.random() * 2.0 - 1.0) * askew)
                tuft(body, p - n * (width * length * 0.15), along, n, length, width * length, col, wt,
                     curve=_opt(pt, fz, "curve", 0.1), droop=_opt(pt, fz, "droop", 0.3),
                     twist=twist * (rng.random() * 2.0 - 1.0))
            s += spacing


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
