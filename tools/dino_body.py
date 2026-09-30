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
    _tusks(body, loft, path, spec)
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
            for phi in (_deg(row), 2.0 * math.pi - _deg(row)):
                p, n = loft.surface(s, phi)
                sc.plate(body, p, t, n, pl["length"] * k, pl["width"] * k, pl["height"] * k, pl["colour"], w,
                         square=pl.get("square", 0.0), keel=pl.get("keel", 0.55))
        s += pl["spacing"] * max(0.55, k)


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
