# tools/generate_flora.py
# The plants of a Jurassic valley, generated in Blender.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/generate_flora.py
#   ... -- --preview     also renders a lineup to the scratch directory, for looking at
#
# WHY GENERATED, when the rule is "use what is ready-made": nothing ready-made is the
# right PERIOD. Every free nature pack worth using is temperate -- oaks, birches, pines --
# and a Jurassic valley grown from them reads as a modern forest with dinosaurs in it.
# What says "a hundred million years ago" is the flora: tree ferns, cycads, horsetails,
# the monkey-puzzle araucaria, and ferns carpeting the ground where grass would be now.
#
# And these particular plants are the ones procedural generation is GOOD at. The box-
# built hero and dinosaurs looked like boxes because animals are sculpted, organic
# forms. A fern is not: it is one frond repeated round a crown, and a frond is one
# leaflet repeated along a stem. Get the leaflet and the frond right and the plant
# follows.
#
# THE DETAILS THAT MAKE IT READ AS A PLANT rather than as a plastic pot plant, each of
# which is deliberate below:
#
#   * leaflets are FOLDED along the midrib and LOBED along the edge, not flat blades --
#     the fold catches light on one side and shadow on the other, and the lobes are what
#     a twice-divided fern frond looks like from more than a metre away;
#   * fronds ARCH, rising from the crown and drooping at the tip, and their leaflets are
#     longest a third of the way out -- a frond with even leaflets is a feather;
#   * young fronds stand up and end in a FIDDLEHEAD, the tightly curled crozier that is
#     the single most fern-like shape there is;
#   * a tree fern wears a SKIRT of dead fronds hanging brown down its trunk, and its
#     trunk is fibrous and scarred where old fronds fell;
#   * a cycad's trunk is armoured in diamond-shaped leaf bases;
#   * colour runs dark at the base of a frond to light yellow-green at the tip, and no
#     two fronds are quite the same green.
#
# Everything is vertex-coloured on a single material per surface, so Godot can scatter
# thousands of them through MultiMesh at one draw call each.

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix

REPO = r"z:\home\zkl-unix\repo\game\dino"
OUT_DIR = os.path.join(REPO, "assets", "models", "flora")
PREVIEW_DIR = os.path.join(os.environ.get("TEMP", REPO), "claude", "Z--home-zkl-unix-repo-game-dino",
                           "5cbab4bd-98dc-47f7-b046-5aa8e1c5677b", "scratchpad", "art")

UP = Vector((0.0, 0.0, 1.0))


# ==============================================================================
# Colour
# ==============================================================================

def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def jitter(c, rng, amount):
    """A colour nudged a little in brightness and hue, so no two fronds match."""
    k = 1.0 + rng.uniform(-amount, amount)
    h = rng.uniform(-amount, amount) * 0.5
    return (min(1.0, c[0] * k + h * 0.3), min(1.0, c[1] * k), min(1.0, c[2] * k - h * 0.3))


# Greens of a humid Mesozoic understorey: deep at the base, catching light at the tips.
FROND_BASE = (0.06, 0.16, 0.04)
FROND_TIP = (0.36, 0.52, 0.12)
FIDDLE = (0.46, 0.50, 0.18)
DEAD_FROND = (0.30, 0.20, 0.09)
DEAD_TIP = (0.46, 0.33, 0.14)
TREEFERN_TRUNK = (0.10, 0.07, 0.05)
TREEFERN_FIBRE = (0.20, 0.13, 0.08)
CYCAD_TRUNK = (0.22, 0.16, 0.10)
CYCAD_SCALE_EDGE = (0.36, 0.28, 0.17)
CYCAD_BASE = (0.05, 0.14, 0.05)
CYCAD_TIP = (0.20, 0.38, 0.10)
HORSETAIL = (0.24, 0.42, 0.14)
HORSETAIL_RING = (0.07, 0.08, 0.05)
STROBILUS = (0.38, 0.28, 0.12)
ARAUCARIA_BARK = (0.24, 0.20, 0.16)
ARAUCARIA_RING = (0.16, 0.13, 0.10)
# Near-black green: a monkey-puzzle is the darkest thing in the forest, and a mid-green
# one reads as an ordinary broadleaf -- measured, the first clumped crown came out as a
# generic lollipop tree.
ARAUCARIA_NEEDLE = (0.03, 0.09, 0.04)
ARAUCARIA_NEEDLE_TIP = (0.09, 0.19, 0.07)


# ==============================================================================
# A mesh builder: triangles with a colour at every corner
# ==============================================================================

class Builder:
    """Collects coloured triangles for ONE surface, then turns them into a mesh."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.cols = []
        self.face_mats = []

    def tri(self, a, b, c, ca, cb, cc):
        i = len(self.verts)
        self.verts += [a, b, c]
        self.cols += [ca, cb, cc]
        self.faces.append((i, i + 1, i + 2))
        self.face_mats.append(0)

    def absorb(self, other, material_index):
        """Takes another builder's triangles in as material `material_index`: how a trunk
        and its leaves become one mesh without an object join in between."""
        base = len(self.verts)
        self.verts += other.verts
        self.cols += other.cols
        self.faces += [(a + base, b + base, c + base) for (a, b, c) in other.faces]
        self.face_mats += [material_index] * len(other.faces)

    def quad(self, a, b, c, d, ca, cb, cc, cd):
        self.tri(a, b, c, ca, cb, cc)
        self.tri(a, c, d, ca, cc, cd)

    def tube(self, spine, radii, colours, sides, radial=None):
        """A tube along `spine`. `radial(i, k)` may scale the radius per vertex, which is
        how bark gets fibres and a cycad gets its diamond scales."""
        rings = []
        for i, p in enumerate(spine):
            if i == 0:
                t = (spine[1] - spine[0]).normalized()
            elif i == len(spine) - 1:
                t = (spine[-1] - spine[-2]).normalized()
            else:
                t = (spine[i + 1] - spine[i - 1]).normalized()
            side = t.cross(UP)
            if side.length < 1e-4:
                side = Vector((1.0, 0.0, 0.0))
            side.normalize()
            nrm = side.cross(t).normalized()
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                r = radii[i] * (radial(i, k) if radial else 1.0)
                ring.append(p + (side * math.cos(a) + nrm * math.sin(a)) * r)
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                self.quad(rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k],
                          colours[i], colours[i], colours[i + 1], colours[i + 1])
        return rings

    def to_object(self, name, material):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        mesh.update()
        attr = mesh.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='CORNER')
        for poly in mesh.polygons:
            for li in poly.loop_indices:
                vi = mesh.loops[li].vertex_index
                c = self.cols[vi]
                attr.data[li].color = (c[0], c[1], c[2], 1.0)
        for m in (material if isinstance(material, (list, tuple)) else [material]):
            mesh.materials.append(m)
        for poly in mesh.polygons:
            poly.use_smooth = False     # faceted on purpose: the stylised low-poly look
            poly.material_index = self.face_mats[poly.index]
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# ==============================================================================
# Materials: vertex colour does the colouring
# ==============================================================================

def vertex_colour_material(name, roughness, two_sided):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    mat.use_backface_culling = not two_sided
    return mat


# ==============================================================================
# The leaflet and the frond -- everything else is built from these
# ==============================================================================

def leaflet(b, base, direction, normal, length, width, col_base, col_tip, lobes, fold=0.25):
    """One leaflet: a folded blade, pointed at both ends, with lobed edges.

    FOLDED: the midrib stands proud and the edges drop, so one half catches the light and
    the other falls into shadow -- a flat blade reads as paper. LOBED: the edge swells and
    pinches `lobes` times, which is what a twice-divided frond looks like from any
    distance the game is played at.
    """
    d = direction.normalized()
    n = normal.normalized()
    s = d.cross(n).normalized()
    # A leaflet with no lobes is a diamond -- two segments. Lobes cost two segments each,
    # and that is where the triangles go, so they are spent only where they are SEEN.
    steps = 2 if lobes == 0 else lobes * 2 + 1
    prev = None
    for j in range(steps + 1):
        u = j / steps
        centre = base + d * (length * u)
        # pointed ends; lobes pinch every other step
        env = math.sin(math.pi * u) ** 0.75
        lobe = 1.0 if (lobes == 0 or j % 2 == 1) else 0.62
        w = width * 0.5 * env * lobe
        drop = n * (-w * fold)          # the fold: edges lower than the midrib
        left = centre + s * w + drop
        right = centre - s * w + drop
        col = mix(col_base, col_tip, u)
        if prev is not None:
            pc, pl, pr, pcol = prev
            b.quad(pc, pl, left, centre, pcol, pcol, col, col)
            b.quad(pc, centre, right, pr, pcol, col, col, pcol)
        prev = (centre, left, right, col)


def frond(b, root, heading, length, rng, rise_deg, droop_deg, pinnae, leaf_len, leaf_width,
          col_base, col_tip, lobes, stiff=False, rachis_r=0.012, withered=0.0, segs=12):
    """An arching frond with leaflets down both sides, returned as its tip position.

    It rises from the crown at `rise_deg` and bends down to `droop_deg` by the tip.
    Leaflets are longest about a third of the way out and shrink to nothing at both
    ends: a frond whose leaflets are all the same length reads as a feather, not a fern.
    `withered` shortens and browns it, for the dead ones hanging under a crown.
    """
    pts = [root]
    dirs = []
    step = length / segs
    p = root.copy()
    for i in range(segs):
        t = (i + 0.5) / segs
        pitch = math.radians(rise_deg + (droop_deg - rise_deg) * (t ** (1.0 if stiff else 1.4)))
        d = Vector((math.cos(pitch) * heading.x, math.cos(pitch) * heading.y, math.sin(pitch)))
        d.normalize()
        dirs.append(d)
        p = p + d * step
        pts.append(p.copy())

    # The stem itself: thin, so it reads from above as a line holding the leaflets.
    b.tube(pts, [rachis_r * (1.0 - 0.7 * i / segs) for i in range(len(pts))],
           [mix(col_base, col_tip, i / segs * 0.6) for i in range(len(pts))], 4)

    side = heading.cross(UP).normalized()
    for i in range(1, segs):
        t = i / segs
        if t < 0.12 or t > 0.97:
            continue
        profile = math.sin(math.pi * min(1.0, t / 0.96) ** 0.72)
        if withered > 0.0:
            profile *= (1.0 - withered * 0.55)
        L = leaf_len * profile * rng.uniform(0.9, 1.08)
        if L < 0.015:
            continue
        per = pinnae
        for k in range(per):
            u = (i + k / per) / segs
            if u > 0.97:
                continue
            base = pts[i] + (pts[i + 1] - pts[i]) * (k / per)
            tangent = dirs[min(i, len(dirs) - 1)]
            nrm = side.cross(tangent).normalized()
            for sgn in (1.0, -1.0):
                sweep = math.radians(38.0 if not stiff else 55.0)
                d = (side * sgn * math.cos(sweep) + tangent * math.sin(sweep))
                d = d - nrm * (0.18 if not stiff else 0.05)       # leaflets droop a little
                cb = mix(col_base, col_tip, u * 0.7)
                ct = mix(col_base, col_tip, min(1.0, u * 0.7 + 0.35))
                if withered > 0.0:
                    cb = mix(cb, DEAD_FROND, withered)
                    ct = mix(ct, DEAD_TIP, withered)
                leaflet(b, base, d, nrm, L, L * leaf_width, cb, ct, lobes)
    return pts[-1]


def fiddlehead(b, root, heading, height, rng, col):
    """A young frond standing up and curled tight at the top: the crozier.

    Rises straight, then rolls over into a logarithmic spiral -- the one shape that says
    FERN more than any frond does.
    """
    pts = []
    radii = []
    # the stalk
    for i in range(6):
        t = i / 5
        pts.append(root + UP * (height * 0.75 * t) + heading * (height * 0.08 * t * t))
        radii.append(0.022 * (1.0 - 0.3 * t))
    top = pts[-1]
    side = heading.cross(UP).normalized()
    # the curl, in the plane of the heading, rolling outward and down
    r0 = height * 0.14
    turns = 2.4
    for i in range(1, 22):
        th = math.pi * turns * i / 21
        r = r0 * math.exp(-0.34 * th)
        centre = top + heading * r0
        off = (heading * -math.cos(th) + UP * math.sin(th)) * r
        pts.append(centre + off + side * 0.0)
        radii.append(max(0.004, 0.02 * math.exp(-0.28 * th)))
    b.tube(pts, radii, [mix((0.30, 0.34, 0.10), col, i / len(pts)) for i in range(len(pts))], 5)


# ==============================================================================
# The plants
# ==============================================================================

def tree_fern(seed):
    """Cyathea / Dicksonia: a fibrous trunk three or four metres tall, a crown of arching
    fronds, fiddleheads rising in the middle, and a skirt of dead fronds below."""
    rng = random.Random(seed)
    trunk_b = Builder()
    leaf_b = Builder()
    h = rng.uniform(3.0, 4.4)
    lean = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0.0))

    # The trunk: a gentle S, fibrous, scarred in rings where old fronds fell.
    spine = []
    for i in range(13):
        t = i / 12
        bend = math.sin(t * math.pi) * 0.12
        spine.append(Vector((lean.x * t * h * 0.12 + bend * lean.y,
                             lean.y * t * h * 0.12 - bend * lean.x, t * h)))
    radii = [0.20 * (1.0 - 0.25 * (i / 12)) + (0.06 if i >= 11 else 0.0) for i in range(13)]
    fibres = [rng.uniform(0.86, 1.14) for _ in range(9)]
    colours = [mix(TREEFERN_TRUNK, TREEFERN_FIBRE, 0.7 if i % 2 == 0 else 0.1) for i in range(13)]
    trunk_b.tube(spine, radii, colours, 9, radial=lambda i, k: fibres[k] * (1.0 + 0.05 * math.sin(i * 2.1 + k)))

    crown = spine[-1]
    # A collar of old frond bases at the top of the trunk.
    for k in range(10):
        a = math.tau * k / 10 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        base = crown + d * 0.18 - UP * 0.1
        tip = base + d * 0.14 + UP * 0.22
        s = d.cross(UP).normalized() * 0.05
        trunk_b.tri(base + s, base - s, tip, TREEFERN_FIBRE, TREEFERN_FIBRE, (0.28, 0.20, 0.10))

    # The skirt: dead fronds hanging down the trunk.
    for k in range(rng.randint(5, 7)):
        a = math.tau * k / 6 + rng.uniform(-0.3, 0.3)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        frond(leaf_b, crown - UP * 0.15 + heading * 0.12, heading, rng.uniform(1.4, 2.0), rng,
              -35.0, -78.0, 1, 0.30, 0.20, DEAD_FROND, DEAD_TIP, 1, rachis_r=0.01, withered=1.0)

    # The living crown.
    count = rng.randint(12, 15)
    for k in range(count):
        a = math.tau * k / count + rng.uniform(-0.18, 0.18)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        base_c = jitter(FROND_BASE, rng, 0.12)
        tip_c = jitter(FROND_TIP, rng, 0.12)
        frond(leaf_b, crown + heading * 0.1, heading, rng.uniform(2.1, 2.7), rng,
              rng.uniform(42.0, 58.0), rng.uniform(-38.0, -20.0), 2, 0.46, 0.22,
              base_c, tip_c, 2, rachis_r=0.016)

    # Fiddleheads unrolling in the middle of the crown.
    for k in range(rng.randint(3, 4)):
        a = math.tau * k / 4 + rng.uniform(-0.4, 0.4)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        fiddlehead(leaf_b, crown + heading * 0.05, heading, rng.uniform(0.55, 0.8), rng, FIDDLE)
    return trunk_b, leaf_b


def cycad(seed):
    """Cycas: a squat trunk armoured in diamond leaf bases, a rosette of stiff glossy
    fronds, and a cone in the middle."""
    rng = random.Random(seed)
    trunk_b = Builder()
    leaf_b = Builder()
    h = rng.uniform(0.8, 1.6)
    spine = [Vector((0.0, 0.0, h * i / 10)) for i in range(11)]
    radii = [0.30 * (1.0 - 0.18 * (i / 10)) for i in range(11)]
    # Diamond scales: a lattice of bumps, alternate rings offset half a step.
    # Diamond scales: bumps alternate round each ring and swap over on the next one, which
    # is a checkerboard wrapped on a cylinder -- and a checkerboard on a cylinder IS a
    # lattice of diamonds. The first version bulged whole rings and read as a stack of tyres.
    def scales(i, k):
        return 1.0 + (0.12 if (k + i) % 2 == 0 else -0.04)
    colours = [mix(CYCAD_TRUNK, CYCAD_SCALE_EDGE, 0.55 if i % 2 else 0.0) for i in range(11)]
    spine = [Vector((0.0, 0.0, h * i / 16)) for i in range(17)]
    radii = [0.30 * (1.0 - 0.18 * (i / 16)) for i in range(17)]
    colours = [mix(CYCAD_TRUNK, CYCAD_SCALE_EDGE, 0.6 if i % 2 else 0.0) for i in range(17)]
    trunk_b.tube(spine, radii, colours, 14, radial=scales)
    top = spine[-1]
    # The cone: a fat spindle in the middle of the crown.
    cone = [top + UP * (0.45 * i / 6) for i in range(7)]
    trunk_b.tube(cone, [0.12 * math.sin(math.pi * min(0.98, 0.15 + i / 6)) + 0.01 for i in range(7)],
                 [mix(STROBILUS, (0.55, 0.42, 0.20), i / 6) for i in range(7)], 8)

    count = rng.randint(18, 24)
    for k in range(count):
        a = math.tau * k / count + rng.uniform(-0.12, 0.12)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        rise = rng.uniform(25.0, 55.0) if k % 3 else rng.uniform(55.0, 72.0)
        frond(leaf_b, top + heading * 0.14, heading, rng.uniform(1.3, 1.8), rng,
              rise, rise - rng.uniform(25.0, 45.0), 2, 0.30, 0.10,
              jitter(CYCAD_BASE, rng, 0.1), jitter(CYCAD_TIP, rng, 0.1), 0, stiff=True, rachis_r=0.014)
    return trunk_b, leaf_b


def horsetail(seed):
    """Equisetum: a clump of jointed green stems, dark rings at every joint, whorls of
    fine needles, and a brown cone on the tallest."""
    rng = random.Random(seed)
    b = Builder()
    for s in range(rng.randint(8, 13)):
        a = rng.uniform(0.0, math.tau)
        rr = rng.uniform(0.0, 0.28)
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0))
        h = rng.uniform(0.55, 1.35)
        tilt = Vector((math.cos(a), math.sin(a), 0.0)) * rng.uniform(0.02, 0.12)
        joints = int(h / 0.1)
        pts = [base + (UP + tilt) * (h * i / joints) for i in range(joints + 1)]
        cols = [HORSETAIL_RING if i % 1 == 0 and i > 0 else HORSETAIL for i in range(joints + 1)]
        cols = [mix(HORSETAIL, HORSETAIL_RING, 0.85) if (i % 1 == 0 and i not in (0, joints)) and i % 2 == 0 else HORSETAIL
                for i in range(joints + 1)]
        b.tube(pts, [0.011 * (1.0 - 0.4 * i / joints) for i in range(joints + 1)], cols, 5)
        for i in range(2, joints - 1):
            t = i / joints
            n_len = 0.13 * (1.0 - t) + 0.02
            for k in range(9):
                an = math.tau * k / 9 + i * 0.4
                d = Vector((math.cos(an), math.sin(an), 0.55)).normalized()
                p0 = pts[i]
                side = d.cross(UP).normalized() * 0.004
                b.tri(p0 + side, p0 - side, p0 + d * n_len, HORSETAIL, HORSETAIL, mix(HORSETAIL, (0.4, 0.55, 0.2), 0.5))
        if h > 1.0:
            tip = pts[-1]
            cone = [tip + (UP + tilt) * (0.07 * i / 4) for i in range(5)]
            b.tube(cone, [0.018 * math.sin(math.pi * (0.2 + 0.7 * i / 4)) for i in range(5)],
                   [STROBILUS] * 5, 6)
    return None, b


def ground_fern(seed):
    """A low rosette of arching fronds: the carpet a Jurassic valley has instead of grass."""
    rng = random.Random(seed)
    b = Builder()
    count = rng.randint(7, 10)
    size = rng.uniform(0.55, 0.9)
    for k in range(count):
        a = math.tau * k / count + rng.uniform(-0.25, 0.25)
        heading = Vector((math.cos(a), math.sin(a), 0.0))
        frond(b, Vector((0.0, 0.0, 0.02)) + heading * 0.03, heading, size * rng.uniform(0.8, 1.1), rng,
              rng.uniform(52.0, 70.0), rng.uniform(-30.0, -5.0), 1, 0.16 * size, 0.24,
              jitter(FROND_BASE, rng, 0.14), jitter(FROND_TIP, rng, 0.14), 1, rachis_r=0.006,
              segs=9)
    if rng.random() < 0.6:
        fiddlehead(b, Vector((0.0, 0.0, 0.0)), Vector((1.0, 0.0, 0.0)), size * 0.45, rng, FIDDLE)
    return None, b


def foliage_clump(b, centre, radius, squash, rng, col_under, col_top, along=None, stretch=1.0):
    """A cloud of needles: an icosahedron with its corners pushed in and out, flattened,
    dark underneath and catching the light on top.

    Clumps are how a conifer's crown reads from any distance past a few metres -- not as
    branches, and certainly not as smooth tubes. The first attempt modelled each branch
    as a tube with a star-shaped section, and the tree came out looking like a green
    plastic coat rack.
    """
    t = (1.0 + 5.0 ** 0.5) / 2.0
    raw = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
           (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    pts = []
    # Optionally drawn out ALONG a branch, so that a row of clumps reads as one leafy arm
    # radiating from the trunk -- which is what gives a monkey-puzzle its tiered look,
    # where round clumps just pile into a single blob.
    ax = along.normalized() if along is not None else None
    sx = ax.cross(UP).normalized() if ax is not None else None
    for (x, y, z) in raw:
        v = Vector((x, y, z)).normalized() * radius * rng.uniform(0.78, 1.2)
        if ax is not None:
            v = ax * (v.dot(ax) * stretch) + sx * (v.dot(sx) * 0.8) + UP * (v.dot(UP) * squash)
        else:
            v.z *= squash
        pts.append(centre + v)
    for (i, j, k) in faces:
        cs = [mix(col_under, col_top, max(0.0, min(1.0, 0.5 + (pts[n].z - centre.z) / (radius * squash * 1.6))))
              for n in (i, j, k)]
        b.tri(pts[i], pts[j], pts[k], cs[0], cs[1], cs[2])


def araucaria(seed):
    """Monkey-puzzle: a tall straight fluted trunk, and branches only near the top, in
    whorls, dipping and then turning up at the ends -- each one carrying its needles as
    clumps. The crown reads as a ragged dark umbrella, which is the silhouette that says
    JURASSIC from across a valley."""
    rng = random.Random(seed)
    trunk_b = Builder()
    leaf_b = Builder()
    h = rng.uniform(11.0, 15.0)
    spine = [Vector((0.0, 0.0, h * i / 16)) for i in range(17)]
    # A flared foot and a long taper, fluted with shallow vertical ridges.
    radii = [0.30 * (1.0 - 0.7 * (i / 16)) + 0.05 + (0.18 if i == 0 else 0.07 if i == 1 else 0.0)
             for i in range(17)]
    colours = [mix(ARAUCARIA_BARK, ARAUCARIA_RING, 0.7 if i % 3 == 0 else 0.0) for i in range(17)]
    trunk_b.tube(spine, radii, colours, 10, radial=lambda i, k: 1.07 if k % 2 == 0 else 0.95)

    whorls = rng.randint(7, 9)
    for w in range(whorls):
        frac = w / (whorls - 1)
        t = 0.52 + 0.44 * frac
        at = Vector((0.0, 0.0, h * t))
        reach = (3.1 - 2.3 * (frac ** 1.25)) * rng.uniform(0.88, 1.1)
        n = rng.randint(5, 7)
        for k in range(n):
            a = math.tau * k / n + w * 0.55 + rng.uniform(-0.18, 0.18)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            pts = []
            for i in range(8):
                u = i / 7
                # out and dipping, then turning up at the end
                z = -0.32 * math.sin(math.pi * u) * reach * 0.35 + (u ** 2.4) * reach * 0.45
                pts.append(at + d * (reach * u) + UP * z)
            # the bare branch, thin and brown, visible between the clumps
            trunk_b.tube(pts, [0.07 * (1.0 - 0.8 * i / 7) + 0.01 for i in range(8)],
                         [ARAUCARIA_BARK] * 8, 5)
            # Needles as a rope of slim clumps drawn out along the branch, so each branch
            # reads as a dark arm and the crown as tiers of arms -- not one mass.
            for c in range(1, 8):
                u = c / 7
                seg = (pts[min(c + 1, 7)] - pts[c - 1])
                size = (0.2 + 0.1 * math.sin(math.pi * u)) * (0.8 + 0.4 * (1.0 - frac))
                foliage_clump(leaf_b, pts[c], size, 0.55, rng,
                              jitter(ARAUCARIA_NEEDLE, rng, 0.1), jitter(ARAUCARIA_NEEDLE_TIP, rng, 0.1),
                              along=seg, stretch=1.9)
    # the crown's own tuft at the very top
    top = spine[-1]
    for c in range(3):
        foliage_clump(leaf_b, top + UP * (0.25 + 0.3 * c), 0.55 - 0.13 * c, 0.9, rng,
                      ARAUCARIA_NEEDLE, ARAUCARIA_NEEDLE_TIP)
    return trunk_b, leaf_b


PLANTS = {
    "tree_fern": (tree_fern, [11, 23, 37]),
    "cycad": (cycad, [5, 17, 29]),
    "horsetail": (horsetail, [3, 41]),
    "ground_fern": (ground_fern, [7, 19, 31]),
    "araucaria": (araucaria, [13, 47]),
}


# ==============================================================================
# Assembly and export
# ==============================================================================

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build(name, fn, seed, mats):
    trunk_b, leaf_b = fn(seed)
    # ONE SURFACE, ONE MATERIAL, and the vertex colours do all the colouring.
    #
    # It was two surfaces -- trunk and leaf, for different roughness and culling -- and
    # the glTF export filled the SECOND surface's vertex colours with 1.0. Measured on
    # the imported mesh: surface 0 (trunk) r 0.11-0.28, surface 1 (leaves) exactly 1.0
    # everywhere. Every tree fern, cycad and monkey-puzzle came into the game with a crown
    # of white fronds, like palms under snow, while the single-surface ground ferns beside
    # them were green.
    #
    # Nothing was gained by the split in the first place: the game draws a whole plant
    # with one override material (GroundCover.flora_material), so the two Blender
    # materials never reached the screen. One surface is also one draw call per variant
    # instead of two.
    whole = Builder()
    if trunk_b is not None:
        whole.absorb(trunk_b, 0)
    if leaf_b is not None:
        whole.absorb(leaf_b, 0)
    return whole.to_object(name, [mats["leaf"]])


def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def preview(objs):
    """A lineup under a warm low sun, for looking at before anything goes near the game."""
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 900
    x = 0.0
    for o in objs:
        dims = o.dimensions
        o.location = (x + max(dims.x, dims.y) * 0.5, 0.0, 0.0)
        x += max(dims.x, dims.y) + 1.2
    # ground
    bpy.ops.mesh.primitive_plane_add(size=200, location=(x * 0.5, 0.0, 0.0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.14, 0.05, 1.0)
    g.data.materials.append(gm)
    # sun
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(52), 0.0, math.radians(35)))
    sun = bpy.context.active_object
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.93, 0.8)
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.6, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    # camera
    bpy.ops.object.empty_add(location=(x * 0.5, 0.0, 3.2))
    aim = bpy.context.active_object
    bpy.ops.object.camera_add(location=(x * 0.5, -x * 1.02, 9.0))
    cam = bpy.context.active_object
    track = cam.constraints.new('TRACK_TO')
    track.target = aim
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    scene.camera = cam
    cam.data.lens = 35
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(PREVIEW_DIR, "flora_preview.png")
    bpy.ops.render.render(write_still=True)
    print("[OK] preview:", scene.render.filepath)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    reset()
    mats = {
        "trunk": vertex_colour_material("FloraTrunk", 0.85, False),
        "leaf": vertex_colour_material("FloraLeaf", 0.6, True),
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    made = []
    for name, (fn, seeds) in PLANTS.items():
        for v, seed in enumerate(seeds):
            label = "%s_%s" % (name, "abc"[v])
            obj = build(label, fn, seed, mats)
            tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            export(obj, os.path.join(OUT_DIR, label + ".glb"))
            print("[OK] %-14s %6d triangles  %.1f x %.1f x %.1f m" % (
                label, tris, obj.dimensions.x, obj.dimensions.y, obj.dimensions.z))
            made.append(obj)
    if "--preview" in args:
        # one of each kind, side by side
        pick = [o for o in made if o.name.endswith("_a")]
        for o in made:
            if o not in pick:
                o.hide_render = True
        preview(pick)


if __name__ == "__main__":
    main()
