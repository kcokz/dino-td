# tools/dino_rig.py
# EACH ANIMAL ON BONES OF ITS OWN, AND MOVING AS IT MOVED (GAME-DESIGN 7.1; the player, 2026-09-30: "精修恐龙blender
# 形象，每个恐龙都要修，因为这是这个游戏最重要的模型，它们最终要有个图鉴系统"; chosen: the body and its muscles, the skin,
# its marks and colours, and how it moves -- "四足的用四足的走法，不借两足恐龙的步子").
#
# The cast stood on the Quaternius animals' rigs and played their clips: a Postosuchus walked a tyrannosaur's
# walk on its hind legs with its arms hanging, a Hesperosuchus a velociraptor's. Here each species' skeleton is
# laid out from its own proportions (tools/dino_species.py) and every clip it plays is worked out for it:
#
#   THE SKELETON: a pelvis at hip height; the spine forward from it to the shoulders, the neck and the skull,
#   and the lower jaw hinged under it; the tail back from it; the legs down from the hips, the arms from the
#   chest -- each limb's bones laid out standing, its foot on the ground (the same leg solver the walk uses).
#   THE POSE: every bone's matrix in the armature's space, worked out top down -- the spine, neck and tail bent
#   a little at each joint (forward kinematics), each limb reaching its foot's place on the ground (inverse
#   kinematics, two bones solved exactly and the foot laid as its gait lays it) -- then written back as each
#   bone's own transform from its rest, and keyed.
#   THE CLIPS the game plays (Config.ANIMATIONS): tools/dino_moves.py.
#
# Blender space: the animal faces +Y, up is +Z, its left is -X (glTF puts +Y at the game's -Z, which is
# forward there). Lengths are metres at the size the game shows it (Config.DINOS.<id>.size), so a clip's
# stride is the game's pace.
#
# Blender only (bpy); used by tools/generate_dinos.py.

import math

import bpy
from mathutils import Matrix, Quaternion, Vector

UP = Vector((0.0, 0.0, 1.0))
FWD = Vector((0.0, 1.0, 0.0))
RIGHT = Vector((1.0, 0.0, 0.0))
FPS = 30


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def pitch_dir(deg):
    """A direction in the animal's plane: `deg` above the forward line (below for less than nought)."""
    r = math.radians(deg)
    return Vector((0.0, math.cos(r), math.sin(r)))


# ==============================================================================
# The skeleton laid out
# ==============================================================================

class Bone:
    """A bone at rest: its head and tail in the armature's space, its parent, and which way its Z should face
    (its roll: for a bone along the body, up; for a limb's, forward)."""

    def __init__(self, name, parent, head, tail, z_hint, deform=True):
        self.name = name
        self.parent = parent
        self.head = head.copy()
        self.tail = tail.copy()
        self.z_hint = z_hint.copy()
        self.deform = deform

    @property
    def length(self):
        return (self.tail - self.head).length


class Skeleton:
    """The bones of a species (dino_species.<X>["skeleton"]), laid out standing."""

    def __init__(self, spec):
        self.spec = spec
        self.bones = {}
        self.order = []
        self.chains = {}             # "spine", "neck", "tail": bone names, pelvis outward
        self.limbs = {}              # "hind.L", ...: the limb's description, its bones and its foot at rest
        self._lay_out()

    def add(self, name, parent, head, tail, z_hint, deform=True):
        b = Bone(name, parent, head, tail, z_hint, deform)
        self.bones[name] = b
        self.order.append(name)
        return b

    def _chain(self, key, parent, start, segments, name, z_hint=UP):
        """A run of bones from `start`, each (length, direction)."""
        at = start.copy()
        names = []
        for i, (length, direction) in enumerate(segments):
            tail = at + direction.normalized() * length
            n = name % (i + 1)
            self.add(n, parent, at, tail, z_hint)
            names.append(n)
            parent = n
            at = tail
        self.chains[key] = names
        return names, at

    def _lay_out(self):
        s = self.spec
        hip = Vector((0.0, 0.0, s["hip_height"]))
        # The root on the ground under the hips, the game's origin: nothing is weighted to it.
        self.add("Root", None, Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.1, 0.0)), UP, deform=False)
        # The pelvis: from the hip joints back over the first of the tail.
        pelvis_back = hip + pitch_dir(180.0 + s.get("pelvis_pitch", 0.0)) * s["pelvis_length"]
        self.add("Hips", "Root", hip, pelvis_back, UP)
        # The spine forward from the hips to the shoulders.
        spine = [(length, pitch_dir(deg)) for (length, deg) in s["spine"]]
        spine_names, shoulder = self._chain("spine", "Hips", hip, spine, "Spine%d")
        self.chest = spine_names[-1]
        # The neck on from the shoulders, and the skull on the neck: from the back of the skull to the tip of
        # the snout.
        neck = [(length, pitch_dir(deg)) for (length, deg) in s["neck"]]
        neck_names, occiput = self._chain("neck", self.chest, shoulder, neck, "Neck%d")
        skull_len, skull_deg = s["skull"]
        tip = occiput + pitch_dir(skull_deg) * skull_len
        self.add("Head", neck_names[-1], occiput, tip, UP)
        # The tip of the snout, a little on: where the portrait frames the head from (tools/render_portraits.gd).
        self.add("Head_end", "Head", tip, tip + pitch_dir(skull_deg) * skull_len * 0.08, UP, deform=False)
        # The lower jaw: hinged at the back of the skull, under it, to the chin.
        jaw_len, jaw_drop, jaw_deg = s["jaw"]
        hinge = occiput + pitch_dir(skull_deg) * (skull_len * s.get("jaw_hinge", 0.12)) - UP * jaw_drop
        self.add("Jaw", "Head", hinge, hinge + pitch_dir(jaw_deg) * jaw_len, UP)
        # The tail back from the hips: each segment a length and a pitch, pointing back.
        tail = [(length, pitch_dir(180.0 - deg)) for (length, deg) in s["tail"]]
        tail_names, tail_tip = self._chain("tail", "Hips", pelvis_back, tail, "Tail%d")
        last = self.bones[tail_names[-1]]
        self.add("Tail_end", tail_names[-1], tail_tip, tail_tip + (tail_tip - last.head).normalized() * 0.03,
                 UP, deform=False)
        # The limbs, each laid out by the same solver the gaits use, its foot at its standing place.
        for key, limb in s["limbs"].items():
            for side, sign in (("L", -1.0), ("R", 1.0)):
                self._lay_limb(key, side, sign, limb)

    def _lay_limb(self, key, side, sign, limb):
        """A limb's bones, standing: from its socket (on the hips or the chest), its foot on the ground where
        its stance puts it."""
        parent = "Hips" if limb["from"] == "hips" else self.chest
        base = self.bones[parent].head if limb["from"] == "hips" else self.bones[parent].tail
        socket = base + Vector((sign * limb["socket"][0], limb["socket"][1], limb["socket"][2]))
        names = [n + "." + side for n in limb["bones"]]
        rig = LimbRig(limb, sign)
        if limb.get("arm"):
            # Held off the ground: its wrist where it rests, in front of the chest.
            r = limb["rest_hand"]
            foot = socket + Vector((sign * r[0], r[1], r[2]))
        else:
            foot = Vector((socket.x + sign * limb["stance"][0], socket.y + limb["stance"][1], 0.0))
        joints = rig.solve(socket, foot, FWD, 0.0)
        prev = parent
        for i, n in enumerate(names):
            self.add(n, prev, joints[i], joints[i + 1], FWD if i < 2 else UP)
            prev = n
        self.limbs["%s.%s" % (key, side)] = {"spec": limb, "names": names, "sign": sign, "socket": socket,
                                            "foot": foot, "parent": parent}
        wing = limb.get("wing_finger")
        if wing:
            # A pterosaur's wing finger, folded: from the knuckle at the foot of the long hand bone flat back up
            # along it (moving with it), along the forearm (with that), and on past the elbow, its tip standing up
            # behind. Folded so, it stays folded however the arm swings -- hinged at the knuckle alone, it swung out
            # from the forearm at every step and opened the wing like a sail.
            knuckle, wrist, elbow = joints[3], joints[2], joints[1]
            clear = Vector((sign * wing.get("clear", 0.02), 0.0, 0.0))
            beyond = max(0.05, sum(wing["lengths"]) - (wrist - knuckle).length - (elbow - wrist).length)
            d = (elbow - wrist).normalized()
            tip_dir = (d - FWD * wing.get("sweep", 0.3) + Vector((sign * wing.get("out", 0.05), 0.0, 0.0))).normalized()
            wnames = ["Wing1." + side, "Wing2." + side, "Wing3." + side, "Wing4." + side]
            self.add(wnames[0], names[2], knuckle + clear, wrist + clear, UP)
            self.add(wnames[1], names[1], wrist + clear, elbow + clear, UP)
            mid = elbow + clear + tip_dir * beyond * 0.6
            self.add(wnames[2], wnames[1], elbow + clear, mid, UP)
            self.add(wnames[3], wnames[2], mid, mid + tip_dir * beyond * 0.4, UP)
            self.limbs["%s.%s" % (key, side)]["wing"] = wnames

    # --------------------------------------------------------------------------

    def build(self, name):
        """The armature in Blender, bones laid as above, each with its roll."""
        data = bpy.data.armatures.new(name)
        arm = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='EDIT')
        for n in self.order:
            b = self.bones[n]
            eb = data.edit_bones.new(n)
            eb.head = b.head
            eb.tail = b.tail
            eb.use_deform = b.deform
            if b.parent:
                eb.parent = data.edit_bones[b.parent]
                eb.use_connect = False
            eb.align_roll(b.z_hint)
        bpy.ops.object.mode_set(mode='OBJECT')
        self.arm = arm
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        return arm


# ==============================================================================
# A limb reaching the ground
# ==============================================================================

class LimbRig:
    """How a limb's bones reach its foot: the top two solved exactly (a knee or an elbow bending the way its
    `bend` says), the rest laid by the foot's kind --
      "digitigrade"  (a theropod's hind foot): the long foot bone standing up off the toes at `foot_tilt`
                     from upright, the toes flat on the ground;
      "plantigrade"  (a crocodile's, a dicynodont's): the foot flat on the ground back from the ball to the
                     ankle, the toes on from the ball;
    and the whole limb splayed out to the side by `splay` degrees (a sprawler's elbows and knees out)."""

    def __init__(self, spec, sign):
        self.spec = spec
        self.sign = sign
        self.lengths = spec["lengths"]

    def solve(self, socket, foot, forward, lift, curl=0.0, up=UP, tilt=None):
        """The limb's joints from the socket to the tip of its toes, the ball of its foot at `foot`, rolled up by
        `lift` (0 flat, 1 up on the toes, pushing off) and its toes curled by `curl` (radians, in the air). An arm
        held off the ground (spec "arm") reaches its wrist to `foot` instead, the hand and fingers hanging on
        from it. `forward` and `up` are the body's own (a body fallen on its side has them turned); `tilt`, the
        foot bone's lean from upright in degrees, when a pose wants its own (sitting back on the heels)."""
        L = self.lengths
        fwd = forward - up * forward.dot(up)
        fwd = fwd.normalized() if fwd.length > 1e-6 else FWD.copy()
        out = fwd.cross(up).normalized() * self.sign
        if self.spec.get("arm"):
            wrist = foot.copy()
            elbow = two_bone(socket, wrist, L[0], L[1], self._pole(fwd, out))
            # The hand down from forward by `hand_angle` (a folded wing's, past straight down, points back along
            # the flank), the fingers by `finger_angle`.
            ha = math.radians(self.spec.get("hand_angle", 40.0) + curl * 30.0)
            hand_dir = fwd * math.cos(ha) - up * math.sin(ha) + out * self.spec.get("hand_out", 0.0)
            knuckle = wrist + hand_dir.normalized() * L[2]
            fa = math.radians(self.spec.get("finger_angle", 75.0) + curl * 30.0)
            finger_dir = fwd * math.cos(fa) - up * math.sin(fa) + out * self.spec.get("hand_out", 0.0)
            return [socket, elbow, wrist, knuckle, knuckle + finger_dir.normalized() * L[3]]
        if self.spec["foot"] == "digitigrade":
            # The foot bone up from the ball at its tilt (more as it rolls up to push off), the toes flat ahead.
            lean = tilt if tilt is not None else self.spec.get("foot_tilt", 20.0) + lift * self.spec.get("roll_tilt", 35.0)
            lean = math.radians(lean)
            up_back = (up * math.cos(lean) - fwd * math.sin(lean)).normalized()
            ankle = foot + up_back * L[2]
        else:
            # The foot flat from the ball back to the ankle (the heel lifting as it rolls).
            heel = tilt if tilt is not None else self.spec.get("heel", 8.0) + lift * self.spec.get("roll_tilt", 45.0)
            heel = math.radians(heel)
            back = (-fwd * math.cos(heel) + up * math.sin(heel)).normalized()
            ankle = foot + back * L[2]
        down = lift * self.spec.get("toe_drop", 0.8) + curl
        toe_dir = (fwd * math.cos(down) - up * math.sin(down)).normalized()
        toe_tip = foot + toe_dir * L[3]
        knee = two_bone(socket, ankle, L[0], L[1], self._pole(fwd, out))
        return [socket, knee, ankle, foot.copy(), toe_tip]

    def _pole(self, fwd, out):
        """Which way the middle joint points: forward for a hind leg's knee, back for a foreleg's elbow, and out
        to the side by the limb's splay."""
        bend = fwd if self.spec.get("bend", "forward") == "forward" else -fwd
        splay = math.radians(self.spec.get("splay", 0.0))
        return (bend * math.cos(splay) + out * math.sin(splay)).normalized()


def two_bone(a, c, l1, l2, pole):
    """The middle joint of a two-bone chain from `a` reaching `c` (as near as it can), bending towards `pole`."""
    d = c - a
    dist = max(abs(l1 - l2) + 1e-4, min(l1 + l2 - 1e-4, d.length))
    axis = d.normalized()
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(0.0, l1 * l1 - x * x))
    side = pole - axis * pole.dot(axis)
    if side.length < 1e-6:
        side = UP - axis * UP.dot(axis)
    return a + axis * x + side.normalized() * h


# ==============================================================================
# A pose: every bone's matrix in the armature's space
# ==============================================================================

class Pose:
    """A pose worked out top down: set each bone by a rotation at its joint (bend) or by pointing it (aim);
    what is not set follows its parent as at rest."""

    def __init__(self, skel):
        self.skel = skel
        self.rest = skel.rest
        self.m = {}

    def rel(self, name):
        b = self.skel.bones[name]
        if b.parent is None:
            return self.rest[name]
        return self.rest[b.parent].inverted() @ self.rest[name]

    def parent_m(self, name):
        p = self.skel.bones[name].parent
        if p is None:
            return Matrix.Identity(4)
        if p not in self.m:
            self.follow(p)
        return self.m[p]

    def follow(self, name):
        """The bone as at rest on its posed parent."""
        self.m[name] = self.parent_m(name) @ self.rel(name)
        return self.m[name]

    def set_root(self, offset=None, rot=None, pivot=None):
        """The whole animal moved by `offset` and turned by `rot` (armature space) about `pivot` -- a body
        falling over onto its side turns about a point a body's half-width off the ground, so it lies on it."""
        m = Matrix.Translation(offset if offset is not None else Vector())
        if rot is not None:
            p = pivot if pivot is not None else Vector()
            m = m @ Matrix.Translation(p) @ rot.to_matrix().to_4x4() @ Matrix.Translation(-p)
        self.m["Root"] = m @ self.rest["Root"]
        return self.m["Root"]

    def bend(self, name, pitch=0.0, yaw=0.0, roll=0.0, move=None, scale=None):
        """The bone turned at its joint from its rest on its parent: `pitch` up (degrees, about its own sideways
        axis), `yaw` to its left, `roll` about itself -- and `move`, its head moved (armature space), `scale` it
        swollen (a breath)."""
        base = self.parent_m(name) @ self.rel(name)
        rot3 = base.to_3x3().normalized()
        side = rot3.col[0].normalized()
        along = rot3.col[1].normalized()
        up = rot3.col[2].normalized()
        q = (Quaternion(along, math.radians(roll)) @ Quaternion(up, math.radians(yaw))
             @ Quaternion(side, math.radians(pitch)))
        m = (q.to_matrix() @ rot3).to_4x4()
        m.translation = base.translation + (move if move is not None else Vector())
        if scale is not None:
            m = m @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        self.m[name] = m
        return m

    def aim(self, name, head, target):
        """The bone from `head` pointing at `target`, turned no more than it must be from its rest on its parent."""
        base = self.parent_m(name) @ self.rel(name)
        rot3 = base.to_3x3().normalized()
        y0 = rot3.col[1].normalized()
        want = target - head
        q = y0.rotation_difference(want.normalized() if want.length > 1e-6 else y0)
        m = (q.to_matrix() @ rot3).to_4x4()
        m.translation = head
        self.m[name] = m
        return m

    def head_of(self, name):
        m = self.m[name] if name in self.m else self.follow(name)
        return m.translation.copy()

    def tail_of(self, name):
        m = self.m[name] if name in self.m else self.follow(name)
        return m @ Vector((0.0, self.skel.bones[name].length, 0.0))

    def socket_of(self, key):
        info = self.skel.limbs[key]
        parent = info["parent"]
        pm = self.m[parent] if parent in self.m else self.follow(parent)
        return pm @ (self.rest[parent].inverted() @ info["socket"])

    def limb(self, key, foot, lift=0.0, forward=FWD, curl=0.0, up=UP, tilt=None):
        """The limb `key` reaching the ball of its foot at `foot` (armature space), rolled up by `lift`."""
        info = self.skel.limbs[key]
        rig = LimbRig(info["spec"], info["sign"])
        joints = rig.solve(self.socket_of(key), foot, forward, lift, curl, up, tilt)
        for i, n in enumerate(info["names"]):
            self.aim(n, joints[i], joints[i + 1])
        return joints

    def keyed(self):
        """Each bone's own transform from its rest on its parent -- what is keyed."""
        for n in self.skel.order:
            if n not in self.m:
                self.follow(n)
        out = {}
        for n in self.skel.order:
            pm = self.parent_m(n) if self.skel.bones[n].parent else Matrix.Identity(4)
            out[n] = (pm @ self.rel(n)).inverted() @ self.m[n]
        return out


# ==============================================================================
# Keying a clip
# ==============================================================================

def key_clip(skel, name, frames, pose_at, loop=True):
    """A clip `name` of `frames` frames: `pose_at(t)` for t from 0 to 1 gives each frame's Pose; a looped clip's
    last frame is its first again, so it plays round without a seam."""
    arm = skel.arm
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    count = frames + (1 if loop else 0)
    prev = {}
    for f in range(count):
        t = (f % frames) / float(frames) if loop else f / float(max(1, frames - 1))
        local = pose_at(t).keyed()
        for n, m in local.items():
            pb = arm.pose.bones[n]
            loc, rot, scl = m.decompose()
            # The shorter way round from the last key: a quaternion and its negative are the same turn, and
            # keyed the long way the bone spins between them.
            if n in prev and prev[n].dot(rot) < 0.0:
                rot = -rot
            prev[n] = rot
            pb.location = loc
            pb.rotation_quaternion = rot
            pb.scale = scl
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
            pb.keyframe_insert("scale", frame=f + 1)
    act.use_fake_user = True
    arm.animation_data.action = None
    return act
