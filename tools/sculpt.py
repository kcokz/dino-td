# tools/sculpt.py
# AN ANIMAL SCULPTED ROUND ITS OWN BONES (GAME-DESIGN 7.2; the player, 2026-09-30: "恐龙目前模型做的都粗糙，
# 我需要它们更精致").
#
# The cast was the Quaternius animals' meshes, stretched: a few hundred flat facets in two or three flat colours,
# no eyes, bony plates floating over the back. This draws a new body on the same skeleton, so every clip the
# game plays still plays:
#
#   THE TRUNK is one tube from the tip of the snout to the tip of the tail, lofted along the spine -- a ring at
#   every station, each ring the animal's cross-section there: how wide, how high over the spine, how deep under
#   it, how square or keeled (Loft). A skull is a trunk station like any other, only closer together.
#   THE LIMBS are tubes of their own down each leg's bones, their tops sunk into the body.
#   THE PARTS are what a tube cannot be: eyes (a material of their own, "Eye", which the game lights in the
#   dark), teeth along the lip, claws, toes and fingers, the bony plates of the crocodile line -- each set on
#   the skin where it grows and moving with the skin under it.
#   THE SKIN is painted, a colour at each vertex: dark back, paler flanks, a pale belly, and each species' own
#   marks -- bands, blotches, a stripe through the eye.
#   THE WEIGHTS are worked out, not guessed: a vertex belongs to the bone its station is on, shared with the
#   next bone only near the joint between them; the skull is one rigid piece.
#
# Blender only (bpy); used by tools/generate_triassic.py.

import math

import bpy
import bmesh
from mathutils import Vector, noise

UP = Vector((0.0, 0.0, 1.0))


def smoothstep(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    """`c` lighter (k > 0) or darker (k < 0) by the fraction k."""
    if k >= 0.0:
        return mix(c, (1.0, 1.0, 1.0), k)
    return tuple(x * (1.0 + k) for x in c)


# ==============================================================================
# The skeleton, and paths through it
# ==============================================================================

class Skeleton:
    """The rest skeleton in world space: each bone's head and tail."""

    def __init__(self, arm):
        self.arm = arm
        self.head = {}
        self.tail = {}
        for b in arm.data.bones:
            self.head[b.name] = arm.matrix_world @ b.head_local
            self.tail[b.name] = arm.matrix_world @ b.tail_local
        # Which way the animal faces, and its left: from its hips to its head, level.
        f = self.head.get("Head", Vector((0.0, 1.0, 0.0))) - self.head.get("Hips", Vector())
        f.z = 0.0
        self.forward = f.normalized() if f.length > 1e-6 else Vector((0.0, 1.0, 0.0))
        self.side = self.forward.cross(UP).normalized()

    def at(self, bone, t):
        h, tl = self.head[bone], self.tail[bone]
        return h + (tl - h) * t

    def has(self, bone):
        return bone in self.head


class Path:
    """A path through the skeleton bone by bone -- a polyline with its length along it -- that a tube is lofted
    along. `links` are (bone, backwards) in order from the path's start; a bone run backwards goes tail to head.
    Where one bone does not end where the next begins, the gap is bridged and belongs to the next."""

    def __init__(self, skel, links, rename=None, rigid=()):
        self.skel = skel
        # A bone's vertices given to another (a skull's end bone to the skull), and the bones that do not bend
        # at a joint -- the blend there is all on the other bone's side.
        self.rename = dict(rename or {})
        self.rigid = set(rigid)
        self.segs = []       # (bone, p0, p1, t0, t1, s0, length)
        s = 0.0
        last = None
        for (bone, back) in links:
            if not skel.has(bone):
                continue
            p0, p1 = (skel.tail[bone], skel.head[bone]) if back else (skel.head[bone], skel.tail[bone])
            t0, t1 = (1.0, 0.0) if back else (0.0, 1.0)
            if last is not None and (p0 - last).length > 1e-4:
                gap = (p0 - last).length
                self.segs.append((bone, last.copy(), p0.copy(), None, None, s, gap))
                s += gap
            n = (p1 - p0).length
            self.segs.append((bone, p0.copy(), p1.copy(), t0, t1, s, n))
            s += n
            last = p1
        self.length = s

    def s_of(self, bone, t):
        """How far along the path the point `t` along `bone` is (t outside 0..1 runs on past its ends)."""
        for (b, p0, p1, t0, t1, s0, n) in self.segs:
            if b == bone and t0 is not None:
                return s0 + (t - t0) / (t1 - t0) * n
        raise KeyError(bone)

    def point(self, s):
        segs = [x for x in self.segs if x[6] > 1e-6]
        if s <= 0.0:
            b, p0, p1, _, _, s0, n = segs[0]
            return p0 + (p1 - p0).normalized() * s
        for (b, p0, p1, t0, t1, s0, n) in segs:
            if s <= s0 + n:
                return p0 + (p1 - p0) * ((s - s0) / n)
        b, p0, p1, _, _, s0, n = segs[-1]
        return p1 + (p1 - p0).normalized() * (s - s0 - n)

    def centre(self, s, soften):
        """The path at `s`, its corners rounded over about `soften` either side."""
        if soften <= 1e-6:
            return self.point(s)
        acc = Vector()
        total = 0.0
        for k in range(-4, 5):
            g = math.exp(-0.5 * (k / 2.0) ** 2)
            acc += self.point(s + k * soften / 4.0) * g
            total += g
        return acc / total

    def tangent(self, s, soften):
        e = max(0.02, soften * 0.25)
        d = self.centre(s + e, soften) - self.centre(s - e, soften)
        return d.normalized()

    def weights(self, s, blend):
        """Which bones a station at `s` moves with: its own segment's bone, shared with the one before or after
        it near the joint between them -- over `blend` = (a fraction of the shorter bone, at most so far) either
        side of it, or all on one side where the other bone is rigid."""
        segs = [x for x in self.segs if x[6] > 1e-6]
        out = {}
        for i, seg in enumerate(segs):
            lo = 1.0 if i == 0 else self._ramp(segs, i, s, blend)
            hi = 1.0 if i == len(segs) - 1 else 1.0 - self._ramp(segs, i + 1, s, blend)
            w = lo * hi
            if w > 1e-4:
                b = self.rename.get(seg[0], seg[0])
                out[b] = out.get(b, 0.0) + w
        total = sum(out.values())
        return {b: w / total for (b, w) in out.items()} if total > 0 else {}

    def _ramp(self, segs, i, s, blend):
        """0 before the joint at the start of segs[i], 1 after it, eased over the blend zone."""
        a, b = segs[i - 1], segs[i]
        half = min(blend[0] * min(a[6], b[6]), blend[1])
        j = b[5]
        ra = self.rename.get(a[0], a[0]) in self.rigid
        rb = self.rename.get(b[0], b[0]) in self.rigid
        if ra and not rb:
            lo, hi = j, j + 2.0 * half
        elif rb and not ra:
            lo, hi = j - 2.0 * half, j
        else:
            lo, hi = j - half, j + half
        return smoothstep(lo, hi, s)


# ==============================================================================
# The mesh being built
# ==============================================================================

class Body:
    """Vertices with a colour and bone weights each, and faces with a material each (0 the skin, 1 the eyes)."""

    def __init__(self):
        self.v = []
        self.col = []
        self.w = []
        self.f = []
        self.fm = []

    def add(self, p, col, w):
        self.v.append(p.copy())
        self.col.append(tuple(col))
        self.w.append(dict(w))
        return len(self.v) - 1

    def face(self, idx, mat=0):
        self.f.append(tuple(idx))
        self.fm.append(mat)

    def rings(self, rings, closed_start=None, closed_end=None, mat=0):
        """Quads between rings of equal size (index lists), and a fan to a tip vertex at either end."""
        for a, b in zip(rings, rings[1:]):
            n = len(a)
            for j in range(n):
                self.face((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]), mat)
        if closed_start is not None:
            a = rings[0]
            for j in range(len(a)):
                self.face((closed_start, a[(j + 1) % len(a)], a[j]), mat)
        if closed_end is not None:
            b = rings[-1]
            for j in range(len(b)):
                self.face((b[j], b[(j + 1) % len(b)], closed_end), mat)

    def make(self, name, arm, materials):
        """The Blender objects, one for each material -- the glTF exporter gives a second material that reads
        the same vertex colours none of them, and the eyes came out white (Blender 5.2, primitive_extract) --
        each with shared vertices, smooth, the colours as its "Col", a vertex group per bone, an armature
        modifier, parented to `arm`."""
        out = []
        for m, mat in enumerate(materials):
            faces = [f for f, fm in zip(self.f, self.fm) if fm == m]
            if not faces:
                continue
            used = sorted({i for f in faces for i in f})
            back = {old: new for new, old in enumerate(used)}
            part = Body()
            part.v = [self.v[i] for i in used]
            part.col = [self.col[i] for i in used]
            part.w = [self.w[i] for i in used]
            part.f = [tuple(back[i] for i in f) for f in faces]
            part.fm = [0] * len(faces)
            out.append(part._object(name if m == 0 else "%s_%s" % (name, mat.name.lower()), arm, mat))
        return out

    def _object(self, name, arm, mat):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(p) for p in self.v], [], self.f)
        mesh.update()
        for poly in mesh.polygons:
            poly.use_smooth = True
        attr = mesh.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='POINT')
        for i, c in enumerate(self.col):
            attr.data[i].color = (c[0], c[1], c[2], 1.0)
        mesh.color_attributes.active_color = attr
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        # Every face outward, whatever order its ring was walked in.
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        groups = {}
        for i, w in enumerate(self.w):
            for bone, x in w.items():
                if x <= 1e-4:
                    continue
                g = groups.get(bone)
                if g is None:
                    g = groups[bone] = obj.vertex_groups.new(name=bone)
                g.add([i], x, 'REPLACE')
        obj.parent = arm
        obj.matrix_parent_inverse = arm.matrix_world.inverted()
        mod = obj.modifiers.new("Armature", 'ARMATURE')
        mod.object = arm
        return obj


# ==============================================================================
# The trunk: a tube from the snout to the tail
# ==============================================================================

KEYS = ("w", "top", "bot", "lift", "n_top", "n_bot", "keel", "step")


def _interp(stations, s):
    """The cross-section at `s`, eased between the stations either side of it."""
    if s <= stations[0]["s"]:
        return dict(stations[0])
    if s >= stations[-1]["s"]:
        return dict(stations[-1])
    for a, b in zip(stations, stations[1:]):
        if a["s"] <= s <= b["s"]:
            t = (s - a["s"]) / max(1e-6, b["s"] - a["s"])
            t = t * t * (3.0 - 2.0 * t)
            out = {"s": s}
            for k in KEYS:
                out[k] = a[k] + (b[k] - a[k]) * t
            return out
    return dict(stations[-1])


def section_point(sec, phi):
    """The point of the cross-section `sec` at `phi` (0 on top, a quarter-turn to its side, a half under it),
    as (sideways, up) from the path: a superellipse, its upper and lower halves each their own height and
    squareness, a keel along the top."""
    c, sn = math.cos(phi), math.sin(phi)
    if c >= 0.0:
        e = 2.0 / sec["n_top"]
        up = sec["top"] * (abs(c) ** e)
        from_top = phi if phi < math.pi else 2.0 * math.pi - phi
        up += sec["keel"] * math.exp(-(from_top / 0.35) ** 2)
    else:
        e = 2.0 / sec["n_bot"]
        up = -sec["bot"] * (abs(c) ** e)
    e_side = 2.0 / (sec["n_top"] if c >= 0.0 else sec["n_bot"])
    x = sec["w"] * math.copysign(abs(sn) ** e_side, sn)
    return x, up + sec["lift"]


class Loft:
    """The trunk: `plan` is its stations from the snout's tip to the tail's, each (bone, t, dict) -- the
    cross-section there (w half-width; top, bot heights over and under the path; lift, the section raised off
    the path; n_top, n_bot squareness, 2 round; keel; step, the spacing of the rings about it)."""

    def __init__(self, skel, path, plan, around=32, soften=0.25):
        self.skel = skel
        self.path = path
        self.around = around
        self.soften = soften
        defaults = {"lift": 0.0, "n_top": 2.0, "n_bot": 2.0, "keel": 0.0, "step": 0.12}
        self.stations = []
        for (bone, t, d) in plan:
            st = dict(defaults)
            st.update(d)
            st["s"] = path.s_of(bone, t)
            self.stations.append(st)
        self.stations.sort(key=lambda x: x["s"])
        self.s0 = self.stations[0]["s"]
        self.s1 = self.stations[-1]["s"]
        # Where the rings go: `step` apart, as the stations say.
        self.ss = [self.s0]
        while self.ss[-1] < self.s1:
            self.ss.append(min(self.s1, self.ss[-1] + max(0.02, _interp(self.stations, self.ss[-1])["step"])))
        self.dents = []      # (s0, s1, phi, depth, width): a groove -- the lip line
        self.bumps = []      # (s, phi, radius, height): a swelling -- a brow
        self.blend = (0.35, 0.6)

    def frame(self, s):
        c = self.path.centre(s, self.soften)
        t = self.path.tangent(s, self.soften)
        x = self.skel.side - t * self.skel.side.dot(t)
        x = x.normalized()
        u = t.cross(x)
        if u.z < 0.0:
            u = -u
        return c, t, x, u

    def section(self, s):
        return _interp(self.stations, s)

    def surface(self, s, phi, out=0.0):
        """The skin at `s`, `phi`, and its outward direction there -- `out` further out along it."""
        c, t, x, u = self.frame(s)
        sec = self.section(s)
        sx, su = section_point(sec, phi)
        sx2, su2 = section_point(sec, phi + 0.01)
        tang = (x * (sx2 - sx) + u * (su2 - su)).normalized()
        n = tang.cross(t).normalized()
        radial = x * sx + u * (su - sec["lift"])
        if n.dot(radial) < 0.0:
            n = -n
        r = self._relief(s, phi)
        p = c + x * sx + u * su + n * (r + out)
        return p, n

    def _relief(self, s, phi):
        r = 0.0
        for (a, b, ph, depth, width) in self.dents:
            if a <= s <= b:
                k = math.sin(math.pi * (s - a) / (b - a)) ** 0.5
                for side in (ph, 2.0 * math.pi - ph):
                    d = (phi - side + math.pi) % (2.0 * math.pi) - math.pi
                    r -= depth * k * math.exp(-(d / width) ** 2)
        for (bs, ph, rad, h) in self.bumps:
            for side in (ph, 2.0 * math.pi - ph):
                d = (phi - side + math.pi) % (2.0 * math.pi) - math.pi
                r += h * math.exp(-((s - bs) / rad) ** 2 - (d / (rad * 2.2)) ** 2)
        return r

    def build(self, body, paint, rough=0.0):
        """The tube into `body`: its rings, the tip of the snout and of the tail closed. `paint(s, phi, p, n)`
        colours each vertex; `rough`, the skin's unevenness, a fraction of its local size."""
        rings = []
        for s in self.ss:
            sec = self.section(s)
            w = self.path.weights(s, self.blend)
            ring = []
            size = max(sec["w"], 0.5 * (sec["top"] + sec["bot"]))
            for j in range(self.around):
                phi = 2.0 * math.pi * j / self.around
                p, n = self.surface(s, phi)
                if rough > 0.0:
                    p = p + n * (rough * size * noise.noise(p * (3.0 / max(0.05, size))))
                ring.append(body.add(p, paint(s, phi, p, n), w))
            rings.append(ring)
        ends = []
        for (s, sign) in ((self.s0, -1.0), (self.s1, 1.0)):
            c, t, x, u = self.frame(s)
            p = c + u * self.section(s)["lift"] + t * (0.02 * sign)
            ends.append(body.add(p, paint(s, 0.0, p, t * sign), self.path.weights(s, self.blend)))
        body.rings(rings, closed_start=ends[0], closed_end=ends[1])
        return rings


# ==============================================================================
# The limbs: tubes down the legs' bones
# ==============================================================================

class Limb:
    """A tube down a limb's bones: `plan` its stations top to bottom, each (bone, t, w, d) -- half as wide
    across the animal and as deep fore and aft; the top sunk in the body, the bottom closed."""

    def __init__(self, skel, links, plan, around=16, soften=0.12, step=0.1):
        self.skel = skel
        self.path = Path(skel, links)
        self.around = around
        self.soften = soften
        self.stations = []
        for (bone, t, w, d) in plan:
            self.stations.append({"s": self.path.s_of(bone, t), "w": w, "d": d})
        self.stations.sort(key=lambda x: x["s"])
        self.ss = [self.stations[0]["s"]]
        while self.ss[-1] < self.stations[-1]["s"]:
            self.ss.append(min(self.stations[-1]["s"], self.ss[-1] + step))
        self.blend = (0.3, 0.35)

    def section(self, s):
        st = self.stations
        if s <= st[0]["s"]:
            return st[0]["w"], st[0]["d"]
        for a, b in zip(st, st[1:]):
            if a["s"] <= s <= b["s"]:
                t = (s - a["s"]) / max(1e-6, b["s"] - a["s"])
                t = t * t * (3.0 - 2.0 * t)
                return a["w"] + (b["w"] - a["w"]) * t, a["d"] + (b["d"] - a["d"]) * t
        return st[-1]["w"], st[-1]["d"]

    def frame(self, s):
        c = self.path.centre(s, self.soften)
        t = self.path.tangent(s, self.soften)
        f = self.skel.forward - t * self.skel.forward.dot(t)
        if f.length < 1e-4:
            f = UP - t * UP.dot(t)
        f = f.normalized()
        x = t.cross(f).normalized()
        return c, t, x, f

    def build(self, body, paint, extra=None):
        rings = []
        for s in self.ss:
            c, t, x, f = self.frame(s)
            w, d = self.section(s)
            wt = self.path.weights(s, self.blend)
            if extra:
                wt = extra(s, wt)
            ring = []
            for j in range(self.around):
                a = 2.0 * math.pi * j / self.around
                n = (x * math.cos(a) + f * math.sin(a)).normalized()
                p = c + x * (w * math.cos(a)) + f * (d * math.sin(a))
                ring.append(body.add(p, paint(s, a, p, n), wt))
            rings.append(ring)
        c, t, _, _ = self.frame(self.ss[-1])
        end = body.add(c + t * 0.3 * min(self.section(self.ss[-1])), paint(self.ss[-1], 0.0, c, t),
                       self.path.weights(self.ss[-1], self.blend))
        # The top closed too: sunk in the body it is never seen, and where a joint stands out past the body's
        # side it is a rounded shoulder, not an open tube.
        c0, t0, _, _ = self.frame(self.ss[0])
        wt0 = self.path.weights(self.ss[0], self.blend)
        top = body.add(c0 - t0 * 0.5 * min(self.section(self.ss[0])), paint(self.ss[0], 0.0, c0, -t0), wt0)
        body.rings(rings, closed_start=top, closed_end=end)
        return rings


# ==============================================================================
# The parts
# ==============================================================================

def tube(body, points, radii, colours, weights, around=8, close_tip=True, flat=1.0, up=UP):
    """A tapering tube along `points` -- a toe, a finger, a claw, a tooth -- each ring `radii` round (squashed
    to `flat` of it up and down), coloured `colours`, moving with `weights`; its base open (it is sunk in
    what it grows from), its tip closed to a point."""
    rings = []
    for i, p in enumerate(points):
        if i == 0:
            t = (points[1] - points[0]).normalized()
        elif i == len(points) - 1:
            t = (points[-1] - points[-2]).normalized()
        else:
            t = (points[i + 1] - points[i - 1]).normalized()
        u = up - t * up.dot(t)
        if u.length < 1e-4:
            u = Vector((1.0, 0.0, 0.0)) - t * t.x
        u = u.normalized()
        x = t.cross(u).normalized()
        ring = []
        for j in range(around):
            a = 2.0 * math.pi * j / around
            q = p + (x * math.cos(a) + u * (math.sin(a) * flat)) * radii[i]
            ring.append(body.add(q, colours[i], weights))
        rings.append(ring)
    tip = None
    if close_tip:
        last = points[-1] + (points[-1] - points[-2]).normalized() * radii[-1]
        tip = body.add(last, colours[-1], weights)
    body.rings(rings, closed_end=tip)


def claw(body, base, direction, length, radius, colour, weights, curl=0.6):
    """A claw: a cone from `base` along `direction`, bending down by `curl` (radians over its length), deeper
    than it is wide."""
    d = direction.normalized()
    pts = [base.copy()]
    for k in range(1, 5):
        ang = curl * (k - 0.5) / 4.0
        dk = (d * math.cos(ang) - UP * math.sin(ang)).normalized()
        pts.append(pts[-1] + dk * (length / 4.0))
    radii = [radius, radius * 0.82, radius * 0.6, radius * 0.34, radius * 0.1]
    tube(body, pts, radii, [colour] * 5, weights, around=6, flat=1.3)


def eye(body, centre, look, radius, iris, pupil, weights, slit=0.0, mat=1):
    """An eyeball at `centre` looking along `look`: a dark pupil (a slit, `slit` > 0, as narrow as that of its
    width), a coloured iris round it, dark at its rim. In the "Eye" material."""
    look = look.normalized()
    rings = []
    lat = 12
    lon = 16
    ref = UP if abs(look.dot(UP)) < 0.9 else Vector((1.0, 0.0, 0.0))
    a = look.cross(ref).normalized()
    b = a.cross(look).normalized()
    th_iris = 0.82
    th_pupil = 0.36
    for i in range(1, lat):
        th = math.pi * i / lat
        ring = []
        for j in range(lon):
            ph = 2.0 * math.pi * j / lon
            d = look * math.cos(th) + (a * math.cos(ph) + b * math.sin(ph)) * math.sin(th)
            p = centre + d * radius
            # The pupil: round, or a slit up and down (`a` is level, across it).
            across = abs(math.sin(th) * math.cos(ph))
            if th < th_iris and ((slit > 0.0 and across < slit * math.sin(th_iris)) or (slit <= 0.0 and th < th_pupil)):
                col = pupil
            elif th < th_iris:
                col = mix(iris, shade(iris, -0.45), smoothstep(th_iris * 0.5, th_iris, th))
            else:
                col = shade(iris, -0.75)
            ring.append(body.add(p, col, weights))
        rings.append(ring)
    front = body.add(centre + look * radius, pupil, weights)
    back = body.add(centre - look * radius, shade(iris, -0.8), weights)
    body.rings(rings, closed_start=front, closed_end=back, mat=mat)


def lids(body, centre, look, radius, colour, weights, upper=0.3, lower=0.2, rise=0.45):
    """The lids round an eye: one ring of skin about it, heavier over the top, set `rise` of the eye's radius
    out along its look."""
    look = look.normalized()
    a = look.cross(UP if abs(look.dot(UP)) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
    b = a.cross(look).normalized()
    if b.dot(UP) < 0.0:
        b = -b
    k = 20
    m = 6
    loop = []
    for j in range(k):
        ang = 2.0 * math.pi * j / k
        radial = a * math.cos(ang) + b * math.sin(ang)
        # The upper lid heavier, easing round to the lower.
        r = lower + (upper - lower) * (0.5 + 0.5 * math.sin(ang))
        mid = centre + look * (radius * rise) + radial * radius * (1.0 + r * 0.55)
        ring = []
        for i in range(m):
            q = 2.0 * math.pi * i / m
            off = (radial * math.cos(q) + look * math.sin(q)) * radius * r
            ring.append(body.add(mid + off, colour, weights))
        loop.append(ring)
    for j in range(k):
        r0, r1 = loop[j], loop[(j + 1) % k]
        for i in range(m):
            body.face((r0[i], r0[(i + 1) % m], r1[(i + 1) % m], r1[i]))


def plate(body, centre, along, normal, length, width, height, colour, weights):
    """A bony plate lying on the skin: an oval `length` by `width`, `height` high along a keel down its middle,
    its underside sunk a little into the skin."""
    n = normal.normalized()
    t = (along - n * along.dot(n)).normalized()
    x = t.cross(n).normalized()
    ring = []
    k = 10
    base = centre - n * height * 0.35
    for j in range(k):
        a = 2.0 * math.pi * j / k
        p = base + t * (math.cos(a) * length * 0.5) + x * (math.sin(a) * width * 0.5)
        ring.append(body.add(p, shade(colour, -0.15), weights))
    mid = []
    for j in range(k):
        a = 2.0 * math.pi * j / k
        keel = 1.0 - abs(math.sin(a)) * 0.55
        p = centre + t * (math.cos(a) * length * 0.33) + x * (math.sin(a) * width * 0.22) + n * height * 0.5 * keel
        mid.append(body.add(p, colour, weights))
    top = body.add(centre + n * height + t * length * 0.08, shade(colour, 0.06), weights)
    body.rings([ring, mid], closed_end=top)
