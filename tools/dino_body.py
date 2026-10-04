# tools/dino_body.py
# THE BODY ROUND THE BONES (tools/dino_rig.py): a species' trunk lofted from the tip of its snout to the tip of its
# tail, section by section (tools/sculpt.py); its limbs with the muscles on them -- the thigh's bulk before the
# femur and the calf behind the shin, drawn off the bone -- and its hands and feet, toe by toe with their
# claws; its eyes and lids, its teeth along both jaws; the crocodile line's bony plates; its skin painted.
#
# THE JAW OPENS. Under the lip line the head's skin goes with the lower jaw (dino_rig "Jaw"), fully forward
# of the hinge and less behind it, into the throat; the rings are close at the lip so what stretches when it
# opens is a narrow band -- dark, the mouth's inside -- and the teeth of each jaw go with it.
#
# Blender only (bpy through sculpt); used by tools/generate_dinos.py.

import math

from mathutils import Vector, noise

import dino_feathers
import sculpt as sc


def _deg(x):
    return math.radians(x)


def trunk_links(skel):
    """The trunk's path: the snout's tip back along the skull, the neck and the spine to the hips, then out
    along the tail to its tip."""
    links = [("Head_end", True), ("Head", True)]
    links += [(n, True) for n in reversed(skel.chains["neck"])]
    links += [(n, True) for n in reversed(skel.chains["spine"])]
    links += [("Hips", False)]
    links += [(n, False) for n in skel.chains["tail"]]
    links += [("Tail_end", False)]
    return links


def ring_angles(around, lip_deg, dense=4, spread=5.0):
    """The angles round a ring (0 on top, a half-turn underneath): `around` evenly, and `dense` more packed
    about the lip line on each side, `spread` degrees either side of it."""
    angles = [2.0 * math.pi * j / around for j in range(around)]
    lip = _deg(lip_deg)
    extra = []
    for side in (lip, 2.0 * math.pi - lip):
        for k in range(dense):
            extra.append(side + _deg(spread) * (-1.0 + 2.0 * (k + 0.5) / dense))
    out = sorted(set(round(a, 6) for a in angles + extra))
    # Drop even ones too close to an added one: no slivers.
    clean = []
    for a in out:
        if clean and a - clean[-1] < _deg(spread) / dense * 0.6:
            continue
        clean.append(a)
    return clean


def build(name, rig, arm, spec, materials):
    """The body of the species `spec` (dino_species.<X>["body"]) round `rig`'s bones, as Blender objects."""
    sk = sc.Skeleton(arm)
    path = sc.Path(sk, trunk_links(rig), rename={"Head_end": "Head"}, rigid={"Head"})
    loft = sc.Loft(sk, path, spec["trunk"], around=spec["around"], soften=spec["soften"])
    if "tips" in spec:
        loft.tips = tuple(spec["tips"])
    body = sc.Body()
    skin = spec["skin"]

    def s_at(where):
        return path.s_of(where[0], where[1])

    for key in ("mouth", "fossa"):
        m = spec.get(key)
        if m:
            a, b = sorted((s_at(m["from"]), s_at(m["to"])))
            loft.dents.append((a, b, _deg(m["phi"]), m["depth"], m["width"]))
    for key in ("brow", "cheek"):
        b = spec.get(key)
        if b:
            loft.bumps.append((s_at(b["at"]), _deg(b["phi"]), b["size"], b["height"]))
    for mound in spec.get("mounds", []):
        loft.bumps.append((s_at(mound["at"]), _deg(mound.get("phi", 0.0)), mound["size"], mound["height"] * 0.5))
    # Ridges along the skin (an Allosaurus's down each side of its snout): a groove turned outward, laid on both
    # sides as a groove is -- once only on the midline, where both sides are the same place.
    for ridge in spec.get("ridges", []):
        a, b = sorted((s_at(ridge["from"]), s_at(ridge["to"])))
        h = ridge["height"] * (0.5 if ridge.get("phi", 0.0) == 0.0 else 1.0)
        loft.dents.append((a, b, _deg(ridge.get("phi", 0.0)), -h, ridge.get("width", 0.1)))

    paint = painter(spec, path, loft, skin)
    weigh = jaw_weights(spec, path, rig)
    phis = ring_angles(spec["around"], spec["mouth"]["phi"]) if spec.get("mouth") else None
    loft.build(body, paint, rough=spec.get("rough", 0.0), weigh=weigh, phis=phis)

    trunk_count = len(body.v)
    for key, info in rig.limbs.items():
        limb_spec = spec["limbs"][key.split(".")[0]]
        _limb(body, sk, info, limb_spec, skin, key)
    _membranes(body, sk, rig, spec)
    limb_count = len(body.v)
    _eyes(body, loft, path, spec)
    _teeth(body, loft, path, spec)
    _plates(body, loft, path, spec)
    _carapace(body, loft, path, spec)
    _tusks(body, loft, path, spec)
    _horns(body, loft, path, spec)
    _back_plates(body, loft, path, spec)
    _patagia(body, sk, rig, spec)
    _tail_vane(body, loft, path, spec)
    # Feathers, where the species had them (tools/dino_feathers.py).
    dino_feathers.wings(body, sk, rig, spec, skin)
    dino_feathers.tail_fan(body, loft, path, spec)
    dino_feathers.plumes(body, loft, path, spec)
    dino_feathers.coat(body, path, spec, trunk_count, limb_count, spec.get("coat", {}).get("bones", ()))
    body.mask = masks(body, path, spec, trunk_count, limb_count)
    return body.make(name + "_body", arm, materials)


def masks(body, path, spec, trunk_count, limb_count):
    """Each vertex's regions, for the skin (tools/dino_skin.py): R the body and the tail (where a crocodile's rows of
    square scales run), G the head, B a limb or a digit."""
    s_head = path.s_of("Head", 0.0)
    s_neck = path.s_of(spec.get("scutes_from", ("Neck1", 0.5))[0], spec.get("scutes_from", ("Neck1", 0.5))[1])
    out = []
    for i in range(len(body.v)):
        s = body.tag[i]
        if i < trunk_count:
            if s is None:                 # the snout's and the tail's tips
                out.append((0.0, 0.0, 0.0))
                continue
            trunk = sc.smoothstep(s_neck - 0.05, s_neck + 0.05, s)
            head = 1.0 - sc.smoothstep(s_head - 0.02, s_head + 0.04, s)
            out.append((trunk, head, 0.0))
        elif i < limb_count:
            out.append((0.0, 0.0, 1.0))
        else:
            out.append((0.0, 1.0, 1.0))
    return out


# ==============================================================================
# The lower jaw's skin
# ==============================================================================

def jaw_weights(spec, path, rig):
    """Below the lip line, the head's skin goes with the jaw: all of it forward of the hinge, less and less
    behind it into the throat (`throat`, a fraction of the skull's length) -- and the band at the lip itself
    shared, so it stretches (the mouth's inside) rather than tears."""
    m = spec.get("mouth")
    if not m:
        return None
    lip = _deg(m["phi"])
    s_tip = path.s_of("Head", 1.0)
    s_back = path.s_of("Head", 0.0)
    skull = abs(s_back - s_tip)
    hinge_t = rig.spec.get("jaw_hinge", 0.1)
    s_hinge = path.s_of("Head", hinge_t)
    throat = spec.get("throat", 0.35) * skull
    band = _deg(m.get("band", 3.0))

    def weigh(s, phi, w):
        side = phi if phi <= math.pi else 2.0 * math.pi - phi    # 0 on top, pi under, either side
        below = sc.smoothstep(lip - band, lip + band, side)
        if below <= 0.0:
            return w
        # Forward of the hinge (the path runs from the snout, so smaller s is further forward): all the jaw's.
        along = 1.0 - sc.smoothstep(s_hinge, s_hinge + throat, s)
        k = below * along
        if k <= 0.0:
            return w
        out = {b: x * (1.0 - k) for b, x in w.items()}
        out["Jaw"] = out.get("Jaw", 0.0) + k
        return out
    return weigh


# ==============================================================================
# The skin's colours
# ==============================================================================

def painter(spec, path, loft, skin):
    bands = skin.get("bands")
    stripe = skin.get("eye_stripe")
    spots = skin.get("spots")
    flush = skin.get("flush")
    fl_range = sorted((path.s_of(*flush["from"]), path.s_of(*flush["to"]))) if flush else (0.0, 0.0)
    s_nose = path.s_of(*spec["nostrils"]["at"]) if spec.get("nostrils") else None
    s_head0 = path.s_of("Head", 0.0)
    s_tip = path.s_of("Head", 1.0)
    skull = abs(s_head0 - s_tip)
    s_eye = path.s_of(*spec["eyes"]["at"])
    m = spec.get("mouth")
    lip = tuple(sorted((path.s_of(*m["from"]), path.s_of(*m["to"])))) + (_deg(m["phi"]),) if m else None
    b_from = path.s_of(*bands["from"]) if bands else 0.0
    b_to = path.s_of(*bands["to"]) if bands else 0.0
    st_range = sorted((path.s_of(*stripe["from"]), path.s_of(*stripe["to"]))) if stripe else (0.0, 0.0)
    sp_range = sorted((path.s_of(*spots["from"]), path.s_of(*spots["to"]))) if spots else (0.0, 0.0)
    beak = skin.get("beak")
    s_beak = path.s_of(*beak["from"]) if beak else None
    scale = spec.get("scale", 1.0)          # a length of this species, to size noise and bands by

    def paint(s, phi, p, n):
        v = math.cos(phi)
        side = phi if phi <= math.pi else 2.0 * math.pi - phi
        if v > 0.2:
            c = sc.mix(skin["flank"], skin["back"], sc.smoothstep(0.2, 0.92, v))
        else:
            c = sc.mix(skin["belly"], skin["flank"], sc.smoothstep(-0.55, 0.2, v))
        if s < s_head0 + 2.0 * skull and v < -0.2:
            c = sc.mix(c, skin["throat"], 0.7 * sc.smoothstep(-0.2, -0.6, v) * (1.0 - sc.smoothstep(s_head0 + skull, s_head0 + 2.0 * skull, s)))
        if bands and b_from <= s <= b_to:
            k = math.sin(2.0 * math.pi * (s - b_from) / bands["period"])
            band = sc.smoothstep(1.0 - bands["width"] * 2.0, 1.0 - bands["width"] * 0.6, k)
            reach = sc.smoothstep(-0.35, 0.35, v)
            tail = sc.smoothstep(b_from + (b_to - b_from) * 0.45, b_from + (b_to - b_from) * 0.6, s)
            reach = max(reach, tail * 0.8)
            fade = sc.smoothstep(b_from, b_from + bands["period"], s)
            c = sc.mix(c, bands["colour"], bands["strength"] * band * reach * fade)
        if flush and fl_range[0] <= s <= fl_range[1]:
            k = (1.0 - sc.smoothstep(fl_range[1] - 0.4 * skull * 3.0, fl_range[1], s)) * sc.smoothstep(-0.6, 0.3, v)
            c = sc.mix(c, flush["colour"], flush["strength"] * k)
        if spots and sp_range[0] <= s <= sp_range[1]:
            k = noise.noise(p * spots["scale"]) + 0.5 * noise.noise(p * spots["scale"] * 2.3)
            spot = sc.smoothstep(spots["above"], spots["above"] + 0.12, k) * sc.smoothstep(-0.5, 0.2, v)
            c = sc.mix(c, spots["colour"], spots["strength"] * spot)
        if stripe and st_range[0] <= s <= st_range[1]:
            lo, hi = st_range
            d = (side - _deg(stripe["phi"])) / _deg(stripe["width"])
            k = math.exp(-d * d) * sc.smoothstep(lo, lo + 0.1 * skull, s) * (1.0 - sc.smoothstep(hi - 0.2 * skull, hi, s))
            c = sc.mix(c, stripe["colour"], 0.75 * k)
        if lip and lip[0] <= s <= lip[1]:
            # The lip line dark -- the inside of the mouth, where the jaws part.
            d = (side - lip[2]) / _deg(m.get("dark", 4.0))
            k = math.sin(math.pi * (s - lip[0]) / (lip[1] - lip[0])) ** 0.3
            c = sc.mix(c, skin["mouth"], 0.95 * k * math.exp(-d * d))
            d2 = (side - lip[2] + _deg(8.0)) / 0.1
            c = sc.mix(c, skin["lips"], 0.5 * k * math.exp(-d2 * d2))
        if s_beak is not None and s < s_beak + 0.05 * skull:
            # A horny beak over the front of the jaws.
            c = sc.mix(c, beak["colour"], 0.85 * (1.0 - sc.smoothstep(s_beak - 0.03 * skull, s_beak + 0.05 * skull, s)))
        if s_nose is not None and abs(s - s_nose) < 0.2 * skull:
            size = spec["nostrils"]["size"]
            d = (side - _deg(spec["nostrils"]["phi"])) / 0.22
            k = math.exp(-((s - s_nose) / (size * 1.2)) ** 2 - d * d)
            c = sc.mix(c, (0.02, 0.015, 0.01), 0.9 * k)
        if abs(s - s_eye) < 0.4 * skull:
            d = (side - _deg(spec["eyes"]["phi"])) / 0.45
            c = sc.shade(c, -0.25 * math.exp(-((s - s_eye) / (0.14 * skull)) ** 2 - d * d))
        mot = noise.noise(p * (1.7 / scale)) * 0.6 + noise.noise(p * (5.3 / scale)) * 0.4
        return sc.shade(c, skin["mottle"] * mot)
    return paint


# ==============================================================================
# Limbs, feet and hands
# ==============================================================================

def _limb(body, sk, info, spec, skin, key):
    """A limb's tube down its first three bones (thigh, shin, foot -- or upper arm, forearm, hand), its
    stations off the species' limb, then its toes or fingers on its last bone."""
    names = info["names"]
    links = [(n, False) for n in names[:3]]
    stations = [(names[i],) + tuple(st[1:]) for st in spec["stations"] for i in [int(st[0])]]
    lb = sc.Limb(sk, links, stations, around=spec.get("around", 14), step=spec.get("step", 0.02))
    top_s = lb.stations[0]["s"]
    end = lb.stations[-1]["s"]

    def paint(s, a, p, n):
        # The outside of the limb the flank's, darker over its top where it comes out of the body, the inside
        # a shade paler -- never the belly's pale, which read as a bare leg -- and the shank and foot darker.
        out = n.dot(sk.side) * (1.0 if p.dot(sk.side) > 0 else -1.0)
        down = (s - top_s) / max(0.01, end - top_s)
        c = sc.mix(sc.mix(skin["flank"], skin["belly"], 0.35), skin["flank"], sc.smoothstep(-0.7, 0.3, out + 0.5 * n.dot(sc.UP)))
        c = sc.mix(c, sc.mix(skin["flank"], skin["back"], 0.5), 0.7 * (1.0 - sc.smoothstep(0.0, 0.4, down)) * sc.smoothstep(-0.3, 0.6, n.dot(sc.UP) + out * 0.6))
        c = sc.shade(c, -skin.get("shank_dark", 0.2) * sc.smoothstep(0.45, 1.0, down))
        mot = noise.noise(p * 31.0) * 0.5
        return sc.shade(c, skin["mottle"] * mot)

    lb.build(body, paint)
    digits = spec.get("digits")
    if digits:
        _digits(body, sk, names[2], names[3], digits, skin, spec.get("hand", False))


def _digits(body, sk, foot_bone, toe_bone, d, skin, hand):
    """The toes (or fingers) from the ball of the foot, spread about the toe bone's line: each (spread in degrees
    -- outward positive --, length, radius at its root, its claw's length), and a first toe (`hallux`) raised
    off the ground at the back of the foot."""
    ball = sk.head[toe_bone]
    along = (sk.tail[toe_bone] - sk.head[toe_bone]).normalized()
    up = sc.UP - along * sc.UP.dot(along)
    up = up.normalized() if up.length > 1e-4 else sc.UP
    outward = along.cross(up).normalized()
    if outward.dot(ball - Vector((0.0, ball.y, ball.z))) < 0.0:
        outward = -outward
    w = {toe_bone: 1.0}
    col = sc.shade(skin["flank"], -skin.get("toe_dark", 0.15))
    for (deg, length, radius, claw_len) in d["digits"]:
        ang = _deg(deg)
        direction = (along * math.cos(ang) + outward * math.sin(ang)).normalized()
        base = ball - direction * radius * 0.6
        pts, radii = [], []
        for k in range(6):
            f = k / 5.0
            q = base + direction * (length * f)
            # A toe's pads: a little swelling at each joint, and its underside on the ground.
            pad = 1.0 + 0.12 * math.sin(math.pi * f * 3.0) ** 2
            q = q + up * (radius * (0.9 - 0.3 * f) + d.get("arch", 0.0) * math.sin(math.pi * f))
            pts.append(q)
            radii.append(radius * (1.0 - 0.45 * f) * pad)
        sc.tube(body, pts, radii, [col] * len(pts), w, around=8, close_tip=False, flat=d.get("flat", 0.8), up=up)
        sc.claw(body, pts[-1] + direction * radii[-1] * 0.2, direction, claw_len, radii[-1] * 1.05, skin["claws"], w,
                curl=d.get("claw_curl", 0.9))
    sickle = d.get("sickle")
    if sickle:
        # The second toe held up, its great claw clear of the ground: the toe forward and up from the ball of
        # the foot, the claw up from its end and curling over -- a sickle.
        deg, length, radius, claw_len, raise_deg, curl = sickle
        ang = _deg(deg)
        fwd = (along * math.cos(ang) + outward * math.sin(ang)).normalized()
        direction = (fwd * math.cos(_deg(raise_deg)) + up * math.sin(_deg(raise_deg))).normalized()
        base = ball - fwd * radius * 0.6 + up * radius * 0.9
        pts = [base, base + direction * length * 0.5, base + direction * length]
        sc.tube(body, pts, [radius, radius * 0.88, radius * 0.72], [col] * 3, w, around=8, close_tip=False,
                flat=d.get("flat", 0.8) * 1.1, up=up)
        claw_dir = (fwd * 0.45 + up * 0.9).normalized()
        sc.claw(body, pts[-1], claw_dir, claw_len, radius * 0.8, skin["claws"], w, curl=curl)
    hallux = d.get("hallux")
    if hallux:
        deg, length, radius, claw_len, height = hallux
        ankle_w = {foot_bone: 1.0}
        foot_dir = (sk.head[toe_bone] - sk.head[foot_bone]).normalized()
        at = sk.head[toe_bone] - foot_dir * height
        direction = (-along * 0.4 + outward * math.sin(_deg(deg)) * 0.6 - up * 0.5).normalized()
        pts = [at, at + direction * length * 0.5, at + direction * length]
        sc.tube(body, pts, [radius, radius * 0.8, radius * 0.6], [col] * 3, ankle_w, around=6, close_tip=False)
        sc.claw(body, pts[-1], direction, claw_len, radius * 0.6, skin["claws"], ankle_w, curl=0.8)


def _membranes(body, sk, rig, spec):
    """A pterosaur's wings, folded (dino_rig "wing_finger"): the bony finger itself, and the membrane between it
    and the arm, gathered in a fold that stands out from the arm -- each edge moving with the bones along it."""
    mb = spec.get("membrane")
    if not mb:
        return
    for key, info in rig.limbs.items():
        wing = info.get("wing")
        if not wing:
            continue
        names = info["names"]
        out = Vector((info["sign"], 0.0, 0.0))
        for n in wing:
            a, b = sk.head[n], sk.tail[n]
            r = mb.get("finger", 0.012) * (1.0 - 0.6 * wing.index(n) / len(wing))
            sc.tube(body, [a, (a + b) * 0.5, b], [r, r * 0.9, r * 0.75], [mb["bone"]] * 3, {n: 1.0}, around=8,
                    close_tip=(n == wing[-1]))
        # The finger's line, knuckle to tip; the arm's, knuckle up the hand and the forearm to the shoulder.
        f_line = [(sk.head[n], {n: 1.0}) for n in wing] + [(sk.tail[wing[-1]], {wing[-1]: 1.0})]
        a_line = [(sk.tail[names[2]], {names[2]: 1.0}), (sk.head[names[2]], {names[2]: 0.5, names[1]: 0.5}),
                  (sk.head[names[1]], {names[1]: 0.5, names[0]: 0.5})]
        if mb.get("to", "elbow") == "shoulder":
            a_line.append((sk.head[names[0]], {names[0]: 1.0}))
        rows = mb.get("rows", 12)
        grid = []
        for i in range(rows + 1):
            f = i / rows
            p, pw = _along(f_line, f)
            q, qw = _along(a_line, f)
            # The fold: out from the arm and hanging a little.
            mid = (p + q) * 0.5 + out * mb.get("fold", 0.03) * math.sin(math.pi * min(1.0, f * 1.4)) - sc.UP * mb.get("sag", 0.02)
            mw = {}
            for w in (pw, qw):
                for bone, x in w.items():
                    mw[bone] = mw.get(bone, 0.0) + x * 0.5
            grid.append([body.add(p, mb["colour"], pw), body.add(mid, sc.shade(mb["colour"], -0.12), mw),
                         body.add(q, mb["colour"], qw)])
        for r0, r1 in zip(grid, grid[1:]):
            body.face((r0[0], r0[1], r1[1], r1[0]))
            body.face((r0[1], r0[2], r1[2], r1[1]))


def _along(line, f):
    """The point `f` of the way along a polyline of (point, weights), by length, and its weights there."""
    lengths = [(b[0] - a[0]).length for a, b in zip(line, line[1:])]
    total = sum(lengths) or 1.0
    want = f * total
    for k, seg in enumerate(lengths):
        if want <= seg or k == len(lengths) - 1:
            a, b = line[k], line[k + 1]
            t = 0.0 if seg <= 1e-9 else max(0.0, min(1.0, want / seg))
            w = {}
            for bone, x in a[1].items():
                w[bone] = w.get(bone, 0.0) + x * (1.0 - t)
            for bone, x in b[1].items():
                w[bone] = w.get(bone, 0.0) + x * t
            return a[0].lerp(b[0], t), w
        want -= seg
    return line[-1][0].copy(), dict(line[-1][1])


# ==============================================================================
# The head's parts
# ==============================================================================

def _eyes(body, loft, path, spec):
    e = spec["eyes"]
    s = path.s_of(*e["at"])
    for phi in (_deg(e["phi"]), 2.0 * math.pi - _deg(e["phi"])):
        p, n = loft.surface(s, phi)
        c, t, x, u = loft.frame(s)
        look = (n * math.cos(_deg(e["forward"])) - t * math.sin(_deg(e["forward"]))).normalized()
        look = (look + u * math.sin(_deg(e["up"]))).normalized()
        centre = p - n * (e["radius"] * e["sunk"])
        sc.eye(body, centre, look, e["radius"], e["iris"], e["pupil"], {"Head": 1.0}, slit=e["slit"], mat=1)
        sc.lids(body, centre, look, e["radius"], sc.shade(spec["skin"]["flank"], -0.3), {"Head": 1.0},
                upper=0.24, lower=0.14, rise=0.5)


def _teeth(body, loft, path, spec):
    """The upper teeth along the lip pointing down, going with the skull; the lower pointing up just inside them,
    going with the jaw. Bigger in the middle of the row, or at a rosette at the snout's tip."""
    m = spec.get("mouth")
    for key, sign, lift, bone in (("teeth", 1.0, -3.0, "Head"), ("lower_teeth", -1.0, 9.0, "Jaw")):
        tt = spec.get(key)
        if not tt or not m:
            continue
        colour = tt.get("colour", spec.get("teeth", {}).get("colour", (0.74, 0.7, 0.6)))
        s0, s1 = path.s_of(*tt["from"]), path.s_of(*tt["to"])
        s_rose = path.s_of("Head", spec["teeth"]["rosette"]) if spec.get("teeth", {}).get("rosette") else None
        rose_w = spec.get("teeth", {}).get("rosette_width", 0.08) * abs(path.s_of("Head", 0.0) - path.s_of("Head", 1.0))
        for side in (1, -1):
            phi = _deg(m["phi"]) + _deg(lift)
            phi = phi if side > 0 else 2.0 * math.pi - phi
            for i in range(tt["count"]):
                f = (i + 0.5) / tt["count"]
                s = s0 + (s1 - s0) * f
                p, n = loft.surface(s, phi, out=-tt["radius"] * 0.6)
                c, t, x, u = loft.frame(s)
                size = 0.7 + 0.5 * math.sin(math.pi * min(1.0, f * 1.25))
                if s_rose is not None:
                    size = 0.75 + 0.6 * math.exp(-((s - s_rose) / rose_w) ** 2) + 0.15 * math.sin(i * 1.7)
                point = (-u * 0.92 * sign + t * 0.3 * sign + n * 0.1).normalized()
                pts = [p - point * tt["radius"], p + point * tt["length"] * size * 0.45, p + point * tt["length"] * size]
                sc.tube(body, pts, [tt["radius"] * size * 1.1, tt["radius"] * size * 0.75, tt["radius"] * size * 0.25],
                        [colour] * 3, {bone: 1.0}, around=5, close_tip=True, flat=0.6, up=t)


def _plates(body, loft, path, spec):
    """Rows of bony plates down the back, each on the skin where it grows, shrinking along the tail."""
    pl = spec.get("plates")
    if not pl:
        return
    a, b = sorted((path.s_of(*pl["from"]), path.s_of(*pl["to"])))
    s = a
    while s <= b:
        sec = loft.section(s)
        k = max(0.3, min(1.0, sec["w"] / pl["ref"]))
        c, t, x, u = loft.frame(s)
        w = path.weights(s, loft.blend)
        for row in pl["rows"]:
            for phi in ((0.0,) if row == 0.0 else (_deg(row), 2.0 * math.pi - _deg(row))):
                p, n = loft.surface(s, phi)
                sc.plate(body, p, t, n, pl["length"] * k, pl["width"] * k, pl["height"] * k, pl["colour"], w,
                         square=pl.get("square", 0.0), keel=pl.get("keel", 0.55))
        s += pl["spacing"] * max(0.55, k)


def _carapace(body, loft, path, spec):
    """An aetosaur's armour (Desmatosuchus: Parker 2008): its neck, back and tail covered in transverse rows of thick
    bony plates -- osteoderms -- each row a wide paramedian either side of the midline and a lateral at each edge, bent
    down over the flank along a keel; the rows touching, a narrow seam between each plate and the next. Each plate a
    slab lying on the skin and following it round, its edges bevelled down into it, its back edge a little higher than
    its front (the rows step like shingles), a low boss raised on it.

    A row is `length` long where the body is `ref` wide -- shorter as it narrows, by its width to the power `shrink`,
    to no less than `least` of it -- a `seam` of it left before the next. The plates go `reach` degrees round from the
    midline (anchors along the body, straight between). `columns`, from the midline out on each side: each one's span
    across (`v`, fractions of the reach), its height, its boss (where along the plate and across it, its height as a
    fraction of the plate's, its radius) and the keel it is bent along (where across it, its height as a fraction).
    The outermost column's boss is drawn out into a point -- a lateral's spike: `points` are anchors along the body
    (length; rake back, up, curve; base across and along), straight between, and each of `peaks` is set on the row
    nearest it alone (the one pair of great horns at the shoulders). Each plate moves with the skin under it, each
    point with the skin at its root; all of it bone and horn to the bake (no scales)."""
    cp = spec.get("carapace")
    if not cp:
        return
    start = len(body.v)
    s0, s1 = sorted((path.s_of(*cp["from"]), path.s_of(*cp["to"])))
    reach = sorted((path.s_of(*at), deg) for (at, deg) in cp["reach"])

    def reach_at(s):
        return _deg(_through(reach, s)[0])

    def point_row(p):
        return (path.s_of(*p["at"]), p["length"], p["rake"], p["up"], p["curve"], p["base"][0], p["base"][1])
    points = sorted(point_row(p) for p in cp.get("points", []))
    # The rows, front to back: (start, end, how much smaller than at the trunk).
    rows = []
    s = s0
    while s < s1 - 0.01:
        k = 1.0
        for _ in range(2):
            sec = loft.section(min(s1, s + 0.5 * cp["length"] * k))
            k = max(cp.get("least", 0.4), min(1.0, (sec["w"] / cp["ref"]) ** cp.get("shrink", 1.0)))
        length = cp["length"] * k
        rows.append((s, min(s1, s + length * (1.0 - cp.get("seam", 0.1))), k))
        s += length
    spikes = [_through(points, 0.5 * (a + b)) if points else None for (a, b, _) in rows]
    for p in cp.get("peaks", []):
        at = point_row(p)
        nearest = min(range(len(rows)), key=lambda i: abs(0.5 * (rows[i][0] + rows[i][1]) - at[0]))
        spikes[nearest] = at[1:]
    bevel = cp.get("bevel", 0.006)
    sink = cp.get("sink", 0.004)
    colour, rim = cp["colour"], cp.get("rim", cp["colour"])
    boss_colour = cp.get("boss_colour", colour)
    columns = cp["columns"]
    for r, (sa, sb, k) in enumerate(rows):
        width_k = reach_at(0.5 * (sa + sb))
        for c, col in enumerate(columns):
            va, vb = col["v"]
            bu, bv, bh, br = col.get("boss", (0.5, 0.5, 0.0, 0.3))
            kv, kh = col.get("keel", (None, 0.0))
            height = col["height"] * k
            outer = c == len(columns) - 1
            for side in (1.0, -1.0):
                def phi_of(v):
                    phi = width_k * (va + (vb - va) * v)
                    return phi if side > 0 else 2.0 * math.pi - phi

                def s_of(u):
                    return sa + (sb - sa) * u
                # Its size on the skin, to bevel its edges by the same few millimetres all round.
                p_a, _ = loft.surface(s_of(0.5), phi_of(0.0))
                p_b, _ = loft.surface(s_of(0.5), phi_of(1.0))
                across = max(0.005, (p_b - p_a).length)
                along = max(0.005, sb - sa)
                eu, ev = min(0.3, bevel / along), min(0.3, bevel / across)
                # Its lines: the bevel all round, and through its boss and along its keel.
                us = sorted(set([0.0, eu, bu, 1.0 - eu, 1.0]))
                vs = sorted(set([0.0, ev, bv, 1.0 - ev, 1.0] + ([kv] if kv is not None else [])))
                if across > 4.0 * along:
                    # A wide plate (a paramedian) bent round the body: a line more across it, so it lies on it.
                    vs = sorted(set(vs + [0.5 * (bv + 1.0 - ev)]))
                # A shade of its own, so the plates read one by one.
                c_mid, _ = loft.surface(s_of(0.5), phi_of(0.5))
                own = cp.get("vary", 0.1) * noise.noise(c_mid * 9.0 + Vector((r * 0.37, c * 1.3, side)))

                def rise(u, v):
                    edge = min(u / eu, (1.0 - u) / eu, v / ev, (1.0 - v) / ev)
                    edge = sc.smoothstep(0.0, 1.0, min(1.0, edge))
                    boss = bh * math.exp(-((u - bu) / br) ** 2 - ((v - bv) / br) ** 2)
                    keel = kh * max(0.0, 1.0 - abs(v - kv) / 0.3) * (0.4 + 0.6 * u) if kv is not None else 0.0
                    h = height * (0.85 + 0.3 * u) * (1.0 + boss + keel)
                    return -sink + (h + sink) * edge, edge, boss + keel
                grid = []
                for u in us:
                    line = []
                    s_u = s_of(u)
                    w = path.weights(s_u, loft.blend)
                    for v in vs:
                        out, edge, lump = rise(u, v)
                        p, n = loft.surface(s_u, phi_of(v), out=out)
                        tone = sc.mix(rim, colour, sc.smoothstep(0.0, 1.0, edge))
                        tone = sc.mix(tone, boss_colour, min(1.0, lump * 1.4))
                        line.append(body.add(p, sc.shade(tone, own), w))
                    grid.append(line)
                for i in range(len(us) - 1):
                    for j in range(len(vs) - 1):
                        body.face((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
                if outer and spikes[r] is not None and spikes[r][0] > 0.004:
                    _spike(body, loft, path, s_of(bu), phi_of(bv), rise(bu, bv)[0], spikes[r], sc.shade(colour, own),
                           cp)
    if spec.get("skin_detail", {}).get("horn"):
        body.mark_horn(start, cp.get("horn", 1.0))


def _spike(body, loft, path, s, phi, out, spike, base_colour, cp):
    """A lateral plate's point: from the bend of the plate at `s`, `phi` (`out` above the skin), straight out to the
    side, raked back towards the tail by `rake`, turned up by `up`, its tip curving on back -- flattened, broad along
    the body and thin up and down, as an aetosaur's horns are. Moving with the skin at its root."""
    length, rake, up, curve, across, along = spike
    p, n = loft.surface(s, phi, out=out)
    c, t, x, u = loft.frame(s)
    out_dir = x if x.dot(p - c) >= 0.0 else -x
    axis = (out_dir * math.cos(_deg(rake)) + t * math.sin(_deg(rake))).normalized()
    axis = (axis * math.cos(_deg(up)) + u * math.sin(_deg(up))).normalized()
    lie = t - axis * t.dot(axis)
    lie = lie.normalized() if lie.length > 1e-6 else t
    base = p - n * (across * 0.8)
    # A big horn round and smooth; a low point a few facets.
    big = length > 0.08
    rings = 6 if big else 2
    pts, radii, cols = [], [], []
    for k in range(rings + 1):
        f = k / rings
        pts.append(base + axis * (length * f) + t * (curve * length * f * f))
        radii.append(across * max(0.05, (1.0 - f) ** 0.9))
        col = sc.mix(base_colour, cp.get("spike", base_colour), sc.smoothstep(0.0, 0.45, f))
        cols.append(sc.mix(col, cp.get("tip", col), sc.smoothstep(0.6, 1.0, f)))
    sc.tube(body, pts, radii, cols, path.weights(s, loft.blend), around=10 if big else 6, close_tip=True,
            flat=along / max(1e-6, across), up=lie)


def _tusks(body, loft, path, spec):
    tk = spec.get("tusks")
    if not tk:
        return
    s = path.s_of(*tk["at"])
    for phi in (_deg(tk["phi"]), 2.0 * math.pi - _deg(tk["phi"])):
        p, n = loft.surface(s, phi, out=-tk["radius"])
        c, t, x, u = loft.frame(s)
        d = (-u * 0.85 - t * 0.35 + n * 0.25).normalized()
        pts = [p, p + d * tk["length"] * 0.5, p + d * tk["length"]]
        sc.tube(body, pts, [tk["radius"], tk["radius"] * 0.75, tk["radius"] * 0.35], [tk["colour"]] * 3,
                {"Head": 1.0}, around=7, close_tip=True)


def _horns(body, loft, path, spec):
    """Horns and bony crests out of the skin, each where it grows: a Ceratosaurus's blade over its nostrils and the
    hornlet over each eye, an Allosaurus's crest before each eye. Each a tube from its base -- sunk a little into
    the skin -- to its tip: `base` its half-width across the animal and its half-length along it (a blade is thin
    across and long along), tapering by `taper`; standing out along the skin's normal, leant back by `rake`
    degrees (forward if less than nought) and out to its side by `splay`, its tip bent back by `curve` of its
    length. Its colour from the skin's at its foot to `colour`, and `tip` at the point. A pair, one each side,
    unless it is on the midline (phi 0). It moves with the bone it grows on (`bone`), or with the skin there."""
    skin = spec["skin"]
    for h in spec.get("horns", []):
        s = path.s_of(*h["at"])
        phi0 = _deg(h.get("phi", 0.0))
        c, t, x, u = loft.frame(s)
        w = {h["bone"]: 1.0} if h.get("bone") else path.weights(s, loft.blend)
        across, along = h["base"]
        rake = _deg(h.get("rake", 0.0))
        splay = _deg(h.get("splay", 0.0))
        rings = h.get("rings", 6)
        for phi in ((phi0,) if phi0 == 0.0 else (phi0, 2.0 * math.pi - phi0)):
            p, n = loft.surface(s, phi)
            out = x if x.dot(p - c) >= 0.0 else -x
            axis = (n * math.cos(rake) + t * math.sin(rake)).normalized()
            if phi0 != 0.0:
                axis = (axis * math.cos(splay) + out * math.sin(splay)).normalized()
            # Its along-the-animal direction, square to its axis: what its blade's length lies along.
            lie = t - axis * t.dot(axis)
            lie = lie.normalized() if lie.length > 1e-6 else t
            base = p - n * (across * 0.6)
            pts, radii, cols = [], [], []
            for k in range(rings + 1):
                f = k / rings
                q = base + axis * (h["length"] * f) + t * (h.get("curve", 0.0) * h["length"] * f * f)
                pts.append(q)
                radii.append(across * max(0.04, (1.0 - f) ** h.get("taper", 0.8)))
                col = sc.mix(skin.get("horn_base", skin["back"]), h["colour"], sc.smoothstep(0.0, 0.4, f))
                cols.append(sc.mix(col, h.get("tip", h["colour"]), sc.smoothstep(0.55, 1.0, f)))
            start = len(body.v)
            sc.tube(body, pts, radii, cols, w, around=h.get("around", 10), close_tip=True,
                    flat=along / max(1e-6, across), up=lie)
            if spec.get("skin_detail", {}).get("horn"):
                body.mark_horn(start)


def _through(points, f):
    """The value at `f` on a run of (f, a, b, ...) points, straight between them."""
    if f <= points[0][0]:
        return points[0][1:]
    for p, q in zip(points, points[1:]):
        if f <= q[0]:
            k = (f - p[0]) / max(1e-9, q[0] - p[0])
            return tuple(a + (b - a) * k for a, b in zip(p[1:], q[1:]))
    return points[-1][1:]


def _back_plates(body, loft, path, spec):
    """A stegosaur's plates (Stegosaurus stenops: seventeen, Gilmore 1914; "Sophie", Maidment et al. 2015): thin and
    tall, standing up off the back in two rows a hand either side of the spine whose plates alternate -- small on
    the neck, the biggest over the hips and the root of the tail, smaller again down it -- each a broad leaf in
    outline leaning back a little, thick at its root and thin at its rim, the whole plate leant out from the
    midline by `lean`. With "rows": 1, a single row down the midline (a sauropod's spines, "shape": "spine": a
    narrow triangle). `sizes`: (fraction along from..to, height, length at the root). Each moves with the bone at
    its root; its colour from the skin's at the root to `colour`, its rim `rim`, grooved up its faces."""
    bp = spec.get("back_plates")
    if not bp:
        return
    skin = spec["skin"]
    s0, s1 = sorted((path.s_of(*bp["from"]), path.s_of(*bp["to"])))
    n = bp["count"]
    rows = bp.get("rows", 2)
    spine = bp.get("shape", "plate") == "spine"
    # The outline, (along the back -- forward negative --, up), for a plate one long and one high: a broad leaf,
    # its tip set back over its rear half; or a spine's narrow triangle.
    if spine:
        outline = [(-0.5, 0.0), (-0.3, 0.35), (-0.05, 0.75), (0.12, 1.0), (0.22, 0.7), (0.36, 0.32), (0.5, 0.0)]
    else:
        # Broadest a third of the way up, a blunt point at the top set back over the rear half.
        outline = [(-0.5, 0.0), (-0.6, 0.2), (-0.56, 0.4), (-0.36, 0.7), (-0.06, 0.94), (0.1, 1.0), (0.3, 0.8),
                   (0.52, 0.48), (0.58, 0.22), (0.46, 0.0)]
    # Rounded: each corner cut, twice (Chaikin).
    for _ in range(2):
        cut = [outline[0]]
        for a, b in zip(outline, outline[1:]):
            cut.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            cut.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        cut.append(outline[-1])
        outline = cut
    levels = bp.get("levels", 2 if spine else 4)
    for i in range(n):
        f = i / max(1, n - 1)
        s = s0 + (s1 - s0) * f
        height, length = _through(bp["sizes"], f)
        side = 0.0 if rows == 1 else (1.0 if i % 2 == 0 else -1.0)
        c, t, x, u = loft.frame(s)
        phi = 0.0 if side == 0.0 else _deg(bp.get("phi", 5.0))
        if side < 0.0:
            phi = 2.0 * math.pi - phi
        p, nrm = loft.surface(s, phi)
        out = x if x.dot(p - c) >= 0.0 else -x
        lean = _deg(bp.get("lean", 8.0)) if side != 0.0 else 0.0
        up = (u * math.cos(lean) + out * math.sin(lean)).normalized()
        back = (t - up * t.dot(up)).normalized()           # along the back, towards the tail
        across = back.cross(up).normalized()
        w = path.weights(s, loft.blend)
        root = p - up * bp.get("sink", 0.05) * height
        thick = bp.get("thick", 0.06) * height
        centre2 = (0.02, 0.32)

        def at(a, b, k, face):
            # The point (a, b) of the outline drawn in to `k` of the way from its middle, on one face.
            q = (centre2[0] + (a - centre2[0]) * k, centre2[1] + (b - centre2[1]) * k)
            swell = thick * 0.5 * (1.0 - k * k) * (1.0 - 0.5 * q[1])
            return root + back * (q[0] * length) + up * (q[1] * height) + across * (swell * face)

        def colour(a, b, k):
            col = sc.mix(skin["back"], bp["colour"], sc.smoothstep(0.0, 0.35, b))
            col = sc.mix(col, bp.get("rim", bp["colour"]), sc.smoothstep(0.7, 1.0, k) * sc.smoothstep(0.1, 0.4, b))
            # Grooves up its faces, where the vessels ran.
            groove = 0.5 + 0.5 * math.sin((a * length) / max(0.01, bp.get("groove", 0.05)) * math.pi)
            return sc.shade(col, -bp.get("groove_dark", 0.12) * groove * (1.0 - k))
        # Its rim shared by its two faces, so the plate is one closed piece.
        start = len(body.v)
        rim = [body.add(at(a, b, 1.0, 1.0), colour(a, b, 1.0), w) for (a, b) in outline]
        for face in (1.0, -1.0):
            def put(idx):
                # Wound so its normal faces the side the face is on (the outline runs clockwise seen from it).
                body.face(tuple(reversed(idx)) if face > 0 else tuple(idx))
            mid = body.add(at(0.0, 0.0, 0.0, face), colour(centre2[0], centre2[1], 0.0), w)
            prev = None
            for lv in range(1, levels + 1):
                k = lv / levels
                ring = rim if lv == levels else [body.add(at(a, b, k, face), colour(a, b, k), w) for (a, b) in outline]
                if prev is None:
                    for j in range(len(ring) - 1):
                        put((mid, ring[j], ring[j + 1]))
                else:
                    for j in range(len(ring) - 1):
                        put((prev[j], ring[j], ring[j + 1], prev[j + 1]))
                prev = ring
            # Closed along the root, down in the skin.
            put((mid, prev[-1], prev[0]))
        if spec.get("skin_detail", {}).get("horn"):
            body.mark_horn(start, bp.get("horn", 1.0))


# ==============================================================================
# A pterosaur on the wing
# ==============================================================================

def _blend(*parts):
    """Weights mixed: each (k, weights)."""
    out = {}
    for k, w in parts:
        if k <= 0.0:
            continue
        for b, x in w.items():
            out[b] = out.get(b, 0.0) + x * k
    total = sum(out.values()) or 1.0
    return {b: x / total for b, x in out.items() if x / total > 1e-3}


def _sheet(body, grid, weights, colours, thick, closed_rows=()):
    """A thin closed sheet over a grid of points (rows of equal length): its top and its underside, apart by
    `thick` (a grid of its own: nought at the edges), sharing the points round its edge. A row in `closed_rows`
    is all one point (a wing's tip). Wound so each side faces out: the top up."""
    rows, cols = len(grid), len(grid[0])
    normals = []
    for i in range(rows):
        line = []
        for j in range(cols):
            du = grid[min(rows - 1, i + 1)][j] - grid[max(0, i - 1)][j]
            dv = grid[i][min(cols - 1, j + 1)] - grid[i][max(0, j - 1)]
            n = du.cross(dv)
            if n.length < 1e-9:
                n = Vector((0.0, 0.0, 1.0))
            n = n.normalized()
            if n.z < 0.0:
                n = -n
            line.append(n)
        normals.append(line)
    top, bottom = [], []
    for i in range(rows):
        t_row, b_row = [], []
        for j in range(cols):
            edge = i in (0, rows - 1) or j in (0, cols - 1)
            if i in closed_rows and j > 0:
                t_row.append(t_row[0])
                b_row.append(b_row[0])
                continue
            h = 0.0 if edge else thick[i][j] * 0.5
            vi = body.add(grid[i][j] + normals[i][j] * h, colours[i][j], weights[i][j])
            t_row.append(vi)
            b_row.append(vi if edge else body.add(grid[i][j] - normals[i][j] * h, sc.shade(colours[i][j], -0.15),
                                                  weights[i][j]))
        top.append(t_row)
        bottom.append(b_row)
    # Which way round is up: the first real quad's normal against the grid's.
    for layer, sign in ((top, 1.0), (bottom, -1.0)):
        for i in range(rows - 1):
            for j in range(cols - 1):
                quad = [layer[i][j], layer[i + 1][j], layer[i + 1][j + 1], layer[i][j + 1]]
                pts = [body.v[k] for k in quad]
                n = (pts[1] - pts[0]).cross(pts[3] - pts[0])
                if n.length < 1e-12:
                    n = (pts[2] - pts[1]).cross(pts[3] - pts[1])
                want = normals[i][j] * sign
                if n.dot(want) < 0.0:
                    quad.reverse()
                # A wing's tip: all its row one point -- a triangle, not a quad.
                clean = []
                for k in quad:
                    if k not in clean:
                        clean.append(k)
                if len(clean) >= 3:
                    body.face(tuple(clean))


def _patagia(body, sk, rig, spec):
    """A flying pterosaur's wings, spread (dino_rig "spread", "wing"; spec "patagia"): the wing finger's four long
    bones a slim tube along the leading edge; the main membrane (the brachiopatagium) from the tip of the wing
    finger in along the hand, the forearm and the upper arm to the shoulder, back along the flank and down the
    leg to the ankle, its trailing edge cut in between the tip and the ankle; the membrane before the arm (the
    propatagium) from the neck's root to the wrist; and the one between the legs (the cruropatagium). Each a thin
    closed sheet, thickest in its middle, every point moving with the bones it lies between -- and drawn as bare
    skin, not scales (the "Horn" surface: smooth, finely grained)."""
    pt = spec.get("patagia")
    if not pt:
        return
    start = len(body.v)
    colour = pt["colour"]
    edge = pt.get("edge", colour)
    rows_u = pt.get("rows", 22)
    rows_v = pt.get("chord", 7)
    thick = pt.get("thick", 0.004)
    legs = {}
    for key, info in rig.limbs.items():
        if key.startswith("hind"):
            legs[key.split(".")[1]] = info
    for key, info in rig.limbs.items():
        wing = info.get("wing")
        if not wing:
            continue
        side = key.split(".")[1]
        names = info["names"]
        chest = info["parent"]
        leg = legs[side]["names"]
        out = Vector((info["sign"], 0.0, 0.0))
        # The wing finger's bones.
        for i, n in enumerate(wing):
            a, b = sk.head[n], sk.tail[n]
            r = pt.get("finger", 0.007) * (1.0 - 0.55 * i / len(wing))
            sc.tube(body, [a, (a + b) * 0.5, b], [r, r * 0.92, r * 0.8], [pt["bone"]] * 3, {n: 1.0}, around=8,
                    close_tip=(i == len(wing) - 1), flat=0.75)
        # The leading edge, from the tip in to the shoulder; and in from the shoulder along the flank and down
        # the leg to the ankle.
        tip = sk.tail[wing[-1]]
        lead = [(tip, {wing[-1]: 1.0})]
        for n in reversed(wing):
            lead.append((sk.head[n], {n: 1.0}))
        lead += [(sk.head[names[2]], {names[2]: 0.5, names[1]: 0.5}),
                 (sk.head[names[1]], {names[1]: 0.5, names[0]: 0.5}),
                 (sk.head[names[0]], {names[0]: 0.5, chest: 0.5})]
        shoulder = sk.head[names[0]]
        hip = sk.head[leg[0]]
        ankle = sk.head[leg[2]]
        inner = [(shoulder, {names[0]: 0.5, chest: 0.5}),
                 (shoulder.lerp(hip, 0.5) + out * 0.004, {chest: 0.5, "Hips": 0.5}),
                 (hip, {"Hips": 0.5, leg[0]: 0.5}),
                 (sk.head[leg[1]], {leg[0]: 0.5, leg[1]: 0.5}),
                 (ankle, {leg[1]: 0.6, leg[2]: 0.4})]
        ankle_w = inner[-1][1]
        cut = pt.get("concave", 0.22)
        grid, weights, cols, th = [], [], [], []
        for i in range(rows_u + 1):
            u = i / rows_u
            # Closer rows towards the tip, where the wing is narrow and moves most.
            u = u ** 1.15
            lp, lw = _along(lead, u)
            straight = tip.lerp(ankle, u)
            tp = straight + (lp - straight) * cut * math.sin(math.pi * u) ** 0.7
            tw = _blend((1.0 - u ** 1.4, lw), (u ** 1.4, ankle_w))
            g_row, w_row, c_row, t_row = [], [], [], []
            for j in range(rows_v + 1):
                v = j / rows_v
                ip, iw = _along(inner, v)
                p = lp * (1.0 - v) + tp * v + (ip - (shoulder * (1.0 - v) + ankle * v)) * u
                w = _blend((1.0 - v, lw), (v, tw))
                w = _blend((1.0 - sc.smoothstep(0.78, 1.0, u), w), (sc.smoothstep(0.78, 1.0, u), iw))
                g_row.append(p)
                w_row.append(w)
                # Darker towards its trailing edge, fibres running out along it.
                c = sc.mix(colour, edge, sc.smoothstep(0.65, 1.0, v))
                c = sc.shade(c, 0.06 * math.sin(u * 90.0) * (1.0 - v))
                c_row.append(c)
                t_row.append(thick * math.sin(math.pi * v) ** 0.6 * min(1.0, 3.0 * u))
            grid.append(g_row)
            weights.append(w_row)
            cols.append(c_row)
            th.append(t_row)
        _sheet(body, grid, weights, cols, th, closed_rows=(0,))
        # The propatagium: from the root of the neck out to the wrist, before the upper arm and the forearm.
        if pt.get("pro", True):
            neck_root = sk.tail[chest] + out * 0.012 + Vector((0.0, 0.01, 0.0))
            wrist = sk.head[names[2]]
            elbow = sk.head[names[1]]
            arm = [(shoulder, {names[0]: 0.5, chest: 0.5}), (elbow, {names[1]: 0.5, names[0]: 0.5}),
                   (wrist, {names[2]: 0.5, names[1]: 0.5})]
            front_w = {names[2]: 0.4, names[1]: 0.6}
            grid, weights, cols, th = [], [], [], []
            n_u, n_v = 8, 3
            for i in range(n_u + 1):
                u = i / n_u
                ap, aw = _along(arm, u)
                fp = neck_root.lerp(wrist + Vector((0.0, 0.012, 0.0)), u)
                fw = _blend((1.0 - u, {chest: 0.6, names[0]: 0.4}), (u, front_w))
                g_row, w_row, c_row, t_row = [], [], [], []
                for j in range(n_v + 1):
                    v = j / n_v
                    g_row.append(ap.lerp(fp, v))
                    w_row.append(_blend((1.0 - v, aw), (v, fw)))
                    c_row.append(sc.mix(colour, edge, 0.3 * v))
                    t_row.append(thick * 0.7 * math.sin(math.pi * v) ** 0.6)
                grid.append(g_row)
                weights.append(w_row)
                cols.append(c_row)
                th.append(t_row)
            _sheet(body, grid, weights, cols, th)
    # The cruropatagium: between the legs, from the knees to the toes, under the root of the tail.
    if pt.get("uro", True) and "L" in legs and "R" in legs:
        ln, rn = legs["L"]["names"], legs["R"]["names"]
        root_bone = rig.chains["tail"][0]
        under = sk.head[root_bone] - Vector((0.0, 0.0, 0.02))
        grid, weights, cols, th = [], [], [], []
        n_u, n_v = 8, 4
        for i in range(n_u + 1):
            u = i / n_u
            g_row, w_row, c_row, t_row = [], [], [], []
            for j in range(n_v + 1):
                v = j / n_v
                lp = sk.head[ln[1]].lerp(sk.tail[ln[2]], v)
                rp = sk.head[rn[1]].lerp(sk.tail[rn[2]], v)
                p = lp.lerp(rp, u)
                mid = math.sin(math.pi * u)
                p = p + (under - sk.head[ln[1]].lerp(sk.head[rn[1]], 0.5)) * mid * (1.0 - v) ** 2
                p = p + Vector((0.0, 1.0, 0.0)) * pt.get("uro_cut", 0.03) * mid * v
                lw = {ln[1]: 1.0 - v, ln[2]: v}
                rw = {rn[1]: 1.0 - v, rn[2]: v}
                w = _blend((1.0 - u, lw), (u, rw), (mid * (1.0 - v) ** 2, {root_bone: 1.0}))
                g_row.append(p)
                w_row.append(w)
                c_row.append(sc.mix(colour, edge, 0.5 * v))
                t_row.append(thick * 0.7 * math.sin(math.pi * u) ** 0.6 * math.sin(math.pi * v) ** 0.6)
            grid.append(g_row)
            weights.append(w_row)
            cols.append(c_row)
            th.append(t_row)
        _sheet(body, grid, weights, cols, th)
    if spec.get("skin_detail", {}).get("horn"):
        body.mark_horn(start, pt.get("horn", 1.0))


def _tail_vane(body, loft, path, spec):
    """The vane at the end of a rhamphorhynchid's tail (spec "vane"): a kite of skin standing up and down from the
    tail's last length, its long axis along it -- a thin closed lens, each point moving with the tail where it is."""
    vn = spec.get("vane")
    if not vn:
        return
    s0 = path.s_of(*vn["from"])
    s1 = path.s_of("Tail_end", 0.0) + vn.get("past", 0.0)
    length = s1 - s0
    # The outline, (along, up): from its front point on the tail, up to its top, back to its rear point and down
    # to its bottom -- a diamond, its widest a third of the way back, rounded.
    outline = [(0.0, 0.0), (0.18, 0.32), (0.38, 0.5), (0.62, 0.36), (1.0, 0.0), (0.62, -0.36), (0.38, -0.5),
               (0.18, -0.32)]
    for _ in range(2):
        cut = []
        for a, b in zip(outline, outline[1:] + outline[:1]):
            cut.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            cut.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        outline = cut
    centre2 = (0.4, 0.0)
    levels = 3
    start = len(body.v)

    def place(a, b, k, face):
        q = (centre2[0] + (a - centre2[0]) * k, centre2[1] + (b - centre2[1]) * k)
        s = s0 + q[0] * length
        c, t, x, u = loft.frame(min(s, path.length))
        p = c + u * (q[1] * vn["height"]) + x * (vn.get("thick", 0.004) * 0.5 * (1.0 - k * k) * face)
        return p, path.weights(min(s, s1), loft.blend)

    def colour(a, b, k):
        c = sc.mix(vn["colour"], vn.get("rim", vn["colour"]), sc.smoothstep(0.6, 1.0, k))
        return c
    rim = []
    for (a, b) in outline:
        p, w = place(a, b, 1.0, 1.0)
        rim.append(body.add(p, colour(a, b, 1.0), w))
    n = len(outline)
    for face in (1.0, -1.0):
        p, w = place(centre2[0], centre2[1], 0.0, face)
        mid = body.add(p, colour(centre2[0], centre2[1], 0.0), w)
        prev = None
        for lv in range(1, levels + 1):
            k = lv / levels
            if lv == levels:
                ring = rim
            else:
                ring = []
                for (a, b) in outline:
                    p, w = place(a, b, k, face)
                    ring.append(body.add(p, colour(a, b, k), w))
            for j in range(n):
                j2 = (j + 1) % n
                idx = (mid, ring[j], ring[j2]) if prev is None else (prev[j], ring[j], ring[j2], prev[j2])
                # The outline runs clockwise along and up the tail, so as it is wound a face looks to the animal's
                # right: the right face so, the left reversed.
                body.face(idx if face > 0 else tuple(reversed(idx)))
            prev = ring
    if spec.get("skin_detail", {}).get("horn"):
        body.mark_horn(start, vn.get("horn", 1.0))
