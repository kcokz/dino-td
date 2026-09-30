# tools/dino_moves.py
# THE CLIPS EACH ANIMAL PLAYS, WORKED OUT FOR ITS OWN BODY (tools/dino_rig.py; the player, 2026-09-30: "四足的用四足
# 的走法，不借两足恐龙的步子；待机时呼吸、转头"). The game plays them by name (Config.ANIMATIONS): idle, walk, run,
# attack, death, sleep.
#
#   idle    breathing (the chest swelling and the back rising with it), the head turning to look about, the
#           tail swaying; its feet where they stand.
#   walk    each foot on the ground for most of its cycle and carried forward in an arc for the rest, as far as
#   run     the body goes in that time at the pace the game draws the gait at (ANIMATIONS.gaits: a walk at 1.6
#           metres a second, a run at 4) -- so the feet stay where they are put. A biped's legs in turn, its
#           hips highest over a planted foot in a walk and lowest in a run's bound, the tail swinging against
#           them; a quadruped's feet in a walk's order (left hind, left fore, right hind, right fore) or a
#           trot's diagonal pairs, the head steady; a sprawler's body and tail bending side to side, a wave
#           down it, its feet wide.
#   attack  drawn back, the jaws open, a lunge and a bite, back to where it began (the game loops it).
#   death   a stagger, the legs going, down onto its side, the head last; it lies as it fell.
#   sleep   belly down, legs folded under it, the head laid on the ground, the tail round beside it,
#           breathing slowly.
#
# Blender only (bpy, through dino_rig); used by tools/generate_dinos.py.

import math

from mathutils import Quaternion, Vector

import dino_rig as rig
from dino_rig import FPS, FWD, RIGHT, UP, Pose, smooth

TAU = 2.0 * math.pi


def ease(q):
    """A swing's easing: quick off the ground, slowing into the landing."""
    return 1.0 - (1.0 - q) ** 2.2 if q < 1.0 else 1.0


def pulse(t, a, b):
    """0 before `a`, up to 1 by the middle of a..b and down to 0 again by `b`."""
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def ramp(t, a, b):
    return smooth((t - a) / (b - a)) if b > a else (1.0 if t >= b else 0.0)


class Moves:
    """The clips of one species: `spec` is dino_species.<X>["moves"] -- its plan ("biped", "quadruped",
    "sprawler") and the figures of its gaits."""

    def __init__(self, skel, spec, gaits):
        self.skel = skel
        self.spec = spec
        self.gaits = gaits           # {"walk": metres a second, "run": ...} (Config.ANIMATIONS.gaits.dino)
        self.plan = spec["plan"]
        self.legs = [k for k in skel.limbs if not skel.limbs[k]["spec"].get("arm")]
        self.arms = [k for k in skel.limbs if skel.limbs[k]["spec"].get("arm")]
        self.rest_feet = {k: skel.limbs[k]["foot"].copy() for k in skel.limbs}

    # ==========================================================================
    # The body, bone by bone
    # ==========================================================================

    def body(self, pose, lift=None, pitch=0.0, roll=0.0, yaw=0.0, spine=None, neck=None, head=(0.0, 0.0, 0.0),
             jaw=0.0, tail=None, breath=0.0, steady=0.0):
        """The trunk posed: the hips moved by `lift` and turned; each spine, neck and tail bone bent by its
        (pitch, yaw) -- or roll too; the head by `head`, less `steady` of what the body beneath it turned (a
        head kept level as the body moves under it); the jaw opened `jaw` degrees; the chest swollen by
        `breath` (a fraction)."""
        s = self.skel
        pose.bend("Hips", pitch, yaw, roll, move=lift)
        turned_p, turned_y = pitch, yaw
        spine_names = s.chains["spine"]
        for i, n in enumerate(spine_names):
            p, y = (spine[i] if spine else (0.0, 0.0))[:2]
            sc = None
            if n == s.chest and breath:
                sc = (1.0 + breath, 1.0, 1.0 + breath * 0.8)
            pose.bend(n, p, y, 0.0, scale=sc)
            turned_p += p
            turned_y += y
        for i, n in enumerate(s.chains["neck"]):
            p, y = (neck[i] if neck else (0.0, 0.0))[:2]
            pose.bend(n, p, y)
            turned_p += p
            turned_y += y
        pose.bend("Head", head[0] - steady * turned_p, head[1] - steady * turned_y, head[2])
        pose.bend("Jaw", -jaw)
        for i, n in enumerate(s.chains["tail"]):
            p, y = (tail[i] if tail else (0.0, 0.0))[:2]
            pose.bend(n, p, y)

    def wave(self, count, t, amp, lag, bias=0.0, grow=0.0):
        """A wave down a chain of `count` bones: each bent `amp` degrees (and `grow` more a bone further down)
        at the phase `t` less `lag` a bone -- a tail swinging, a body snaking."""
        return [(bias, (amp + grow * i) * math.sin(TAU * t - lag * i)) for i in range(count)]

    def arms_at(self, pose, swing=0.0, t=0.0, raise_=0.0, curl=0.0, forward=FWD, up=UP):
        """A biped's arms, held before its chest, swinging by `swing` metres against the legs."""
        for k in self.arms:
            info = self.skel.limbs[k]
            chest = info["parent"]
            rest_wrist = self.skel.bones[info["names"][1]].tail
            local = self.skel.rest[chest].inverted() @ rest_wrist
            phase = 0.0 if info["sign"] < 0 else 0.5
            local = local + Vector((0.0, swing * math.sin(TAU * (t + phase)), raise_))
            cm = pose.m[chest] if chest in pose.m else pose.follow(chest)
            pose.limb(k, cm @ local, curl=curl, forward=forward, up=up)

    # ==========================================================================
    # Gaits
    # ==========================================================================

    def _cycle(self, which):
        g = self.spec[which]
        period = g["period"]
        stride = self.gaits[which] * period
        return g, period, stride

    def _offsets(self, which):
        """When in its cycle each foot lands (a fraction of it)."""
        g = self.spec[which]
        if self.plan == "biped":
            return {"hind.L": 0.0, "hind.R": 0.5}
        order = g.get("order", "walk")
        if order == "trot":
            return {"hind.L": 0.0, "fore.R": 0.0 + g.get("lead", 0.05), "hind.R": 0.5, "fore.L": 0.5 + g.get("lead", 0.05)}
        # A walk: left hind, left fore, right hind, right fore, a quarter apart.
        return {"hind.L": 0.0, "fore.L": 0.25, "hind.R": 0.5, "fore.R": 0.75}

    def _foot(self, key, p, g, stride):
        """Where foot `key` is at phase `p` of its cycle: planted and sliding back under the body for `duty` of
        it, then lifted and carried forward in an arc. Its roll: up onto its toes at the end of the stance,
        tipped down leaving the ground, flat again as it lands."""
        duty = g["duty"]
        rest = self.rest_feet[key].copy()
        rest.x *= g.get("narrow", 1.0)
        # On the ground it goes back under the body as far as the body goes forward meanwhile.
        reach = stride * duty
        if p < duty:
            s = p / duty
            y = reach * (0.5 - s)
            lift = ramp(s, 0.7, 1.0) * g.get("push", 0.7)
            return rest + Vector((0.0, y, 0.0)), lift, 0.0
        q = (p - duty) / (1.0 - duty)
        y = -reach * 0.5 + reach * ease(q)
        z = g["step"] * math.sin(math.pi * min(1.0, q * 1.08)) ** 0.85
        lift = (1.0 - smooth(q * 1.6)) * g.get("push", 0.7)
        curl = g.get("curl", 0.5) * math.sin(math.pi * q)
        return rest + Vector((0.0, y, max(0.0, z))), lift, curl

    def gait(self, which):
        g, period, stride = self._cycle(which)
        frames = max(8, int(round(period * FPS)))
        offs = self._offsets(which)
        duty = g["duty"]
        s = self.skel
        n_spine = len(s.chains["spine"])
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])

        def at(t):
            pose = Pose(s)
            pose.set_root()
            ph = t - duty * 0.5
            if self.plan == "biped":
                # The hips highest over a planted foot walking, lowest in a run's bound; swaying over the
                # foot that bears them; the pelvis turning with the legs.
                bob = g["bob"] * math.cos(2.0 * TAU * ph) * (1.0 if which == "walk" else -1.0)
                sway = -g.get("sway", 0.0) * math.cos(TAU * ph)
                lift = Vector((sway, 0.0, bob - g.get("crouch", 0.0)))
                pitch = g.get("lean", 0.0) + g.get("pitch_bob", 0.0) * math.cos(2.0 * TAU * ph)
                yaw = g.get("hip_yaw", 0.0) * math.sin(TAU * t)
                roll = g.get("hip_roll", 0.0) * math.cos(TAU * ph)
                spine = [(0.0, -yaw / n_spine * 1.2)] * n_spine
                neck = [(g.get("neck_pitch", 0.0) / n_neck + g.get("neck_bob", 0.0) * math.cos(2.0 * TAU * ph + 0.6), -yaw / n_neck * 0.3)] * n_neck
                tail = self.wave(n_tail, t + 0.25, g.get("tail_swing", 4.0), 0.35, bias=g.get("tail_lift", 0.0) / n_tail)
                self.body(pose, lift, pitch, roll, yaw, spine, neck, (g.get("head_pitch", 0.0), 0.0, 0.0), 0.0, tail,
                          steady=g.get("steady", 0.6))
                self.arms_at(pose, g.get("arm_swing", 0.02), t, curl=0.3)
            else:
                # A quadruped's body level over its feet, bobbing twice a cycle; a sprawler's snaking side to
                # side, a wave from its head to its tail, its girdles turned with the feet.
                bob = g["bob"] * math.cos(2.0 * TAU * ph)
                lift = Vector((0.0, 0.0, bob - g.get("crouch", 0.0)))
                snake = g.get("snake", 0.0)
                yaw = snake * math.sin(TAU * t)
                roll = g.get("hip_roll", 0.0) * math.cos(TAU * ph)
                spine = [(0.0, -2.0 * yaw / n_spine * math.cos(math.pi * i / max(1, n_spine - 1)))
                         for i in range(n_spine)]
                neck = [(g.get("neck_pitch", 0.0) / n_neck, yaw * 0.5 / n_neck)] * n_neck
                tail = self.wave(n_tail, t + 0.5, g.get("tail_swing", 4.0) + snake * 0.3, 0.45,
                                 bias=g.get("tail_lift", 0.0) / n_tail)
                self.body(pose, lift, g.get("lean", 0.0), roll, yaw, spine, neck, (g.get("head_pitch", 0.0), 0.0, 0.0),
                          0.0, tail, steady=g.get("steady", 0.8))
            for key in (self.legs if self.plan == "biped" else list(offs.keys())):
                foot, lift_, curl = self._foot(key, (t + offs[key]) % 1.0, g, stride)
                pose.limb(key, foot, lift_, curl=curl)
            return pose
        return frames, at, True

    # ==========================================================================
    # Standing still
    # ==========================================================================

    def standing(self, pose, t=0.0):
        """The legs where they stand; a biped's arms held before its chest."""
        for key in self.legs:
            pose.limb(key, self.rest_feet[key], 0.0)
        if self.plan == "biped":
            self.arms_at(pose, 0.0, t, curl=0.3)

    def idle(self):
        g = self.spec["idle"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])

        graze = g.get("graze")

        def at(t):
            pose = Pose(s)
            pose.set_root()
            breath = math.sin(TAU * g["breaths"] * t)
            look = math.sin(TAU * t) * g["look"]
            nod = math.sin(TAU * 2.0 * t + 1.0) * g.get("nod", 3.0)
            lift = Vector((0.0, 0.0, breath * g.get("heave", 0.004)))
            spine = [(breath * 0.6, 0.0)] * len(s.chains["spine"])
            neck = [(nod / n_neck, look / n_neck)] * n_neck
            head = (0.0, look * 0.3, 0.0)
            jaw = max(0.0, breath) * g.get("pant", 0.0)
            if graze:
                # Its head down at the ground cropping, its jaw working; up for a while to look about.
                a, b = graze["up"]
                up = ramp(t, a, a + 0.08) * (1.0 - ramp(t, b - 0.08, b))
                down = 1.0 - up
                neck = [((graze["neck"] * down + nod * up) / n_neck, look * up / n_neck)] * n_neck
                head = (graze["head"] * down, look * 0.3 * up, 0.0)
                jaw = graze["chew"] * max(0.0, math.sin(TAU * graze["chews"] * t)) * down
            tail = self.wave(n_tail, t, g.get("tail_swing", 3.0), 0.3)
            self.body(pose, lift, 0.0, 0.0, 0.0, spine, neck, head, jaw=jaw, tail=tail,
                      breath=breath * g.get("swell", 0.02))
            self.standing(pose, t)
            return pose
        return frames, at, True

    # ==========================================================================
    # The bite
    # ==========================================================================

    def attack(self):
        g = self.spec["attack"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            pose.set_root()
            back = ramp(t, 0.0, 0.35) * (1.0 - ramp(t, 0.35, 0.5))
            strike = ramp(t, 0.35, 0.5) * (1.0 - ramp(t, 0.62, 1.0))
            jaw = g["jaw"] * (ramp(t, 0.1, 0.45) * (1.0 - ramp(t, 0.5, 0.6)))
            lunge = Vector((0.0, g["lunge"] * strike - g["lunge"] * 0.3 * back, -g.get("dip", 0.02) * strike))
            spine = [(-g.get("spine_dip", 4.0) * strike / n_spine + g.get("rear", 3.0) * back / n_spine, 0.0)] * n_spine
            neck = [((g["draw"] * back - g["reach"] * strike) / n_neck * (1.4 - 0.8 * i / max(1, n_neck - 1)), 0.0)
                    for i in range(n_neck)]
            head = (g.get("head_up", 10.0) * back - g.get("head_down", 8.0) * strike, 0.0, 0.0)
            tail = [(g.get("tail_up", 4.0) * strike / len(s.chains["tail"]), 0.0)] * len(s.chains["tail"])
            self.body(pose, lunge, -g.get("pitch", 4.0) * strike, 0.0, 0.0, spine, neck, head, jaw, tail)
            self.standing(pose, t)
            if self.plan == "biped":
                self.arms_at(pose, 0.0, t, raise_=0.04 * strike, curl=0.8 * strike)
            return pose
        return frames, at, True

    # ==========================================================================
    # The fall
    # ==========================================================================

    def death(self):
        g = self.spec["death"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])

        def at(t):
            pose = Pose(s)
            rear = pulse(t, 0.0, 0.4)
            fall = ramp(t, 0.22, 0.75)
            settle = ramp(t, 0.7, 1.0)
            # Over onto its right side, about a point its body's half-width off the ground: it lies on its side.
            roll = Quaternion(FWD, math.radians(g["roll"] * fall))
            pose.set_root(Vector((g.get("slide", 0.05) * fall, 0.0, 0.0)), roll, Vector((0.0, 0.0, g["pivot"])))
            up = roll @ UP
            fwd = roll @ FWD
            buckle = ramp(t, 0.05, 0.4)
            lift = Vector((0.0, -0.02 * rear, -g.get("sag", 0.1) * buckle * (1.0 - fall)))
            neck = [((g.get("rear_neck", 10.0) * rear - g.get("limp_neck", 18.0) * settle) / n_neck, 0.0)] * n_neck
            head = (g.get("rear_head", 12.0) * rear - g.get("limp_head", 10.0) * settle, 0.0, 0.0)
            tail = [(-g.get("limp_tail", 12.0) * settle / n_tail, 3.0 * settle)] * n_tail
            self.body(pose, lift, g.get("rear_pitch", 6.0) * rear - 4.0 * settle, 0.0, 0.0, None, neck, head,
                      g.get("jaw", 20.0) * rear + 8.0 * settle, tail)
            # The legs giving way and going slack: each foot a little forward and up of where it stood, as the
            # body turns over them, and lying out from it once it is down.
            root = pose.m["Root"]
            for key in self.legs:
                rest = self.rest_feet[key]
                limp = rest + Vector((0.0, g.get("limp_forward", 0.08), g.get("limp_up", 0.1))) * (0.5 * buckle + 0.5 * fall)
                pose.limb(key, root @ limp, 0.3 * fall, forward=fwd, curl=0.5 * settle, up=up)
            if self.plan == "biped":
                self.arms_at(pose, 0.0, t, raise_=0.03 * settle, curl=0.9, forward=fwd, up=up)
            return pose
        return frames, at, False

    # ==========================================================================
    # Asleep
    # ==========================================================================

    def sleep(self):
        g = self.spec["sleep"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])

        def at(t):
            pose = Pose(s)
            pose.set_root()
            breath = math.sin(TAU * t)
            lift = Vector((0.0, g.get("back", -0.05), -g["drop"] + breath * 0.004))
            neck = [(p, y) for (p, y) in g["neck"]]
            tail = [(p, y) for (p, y) in g["tail"]]
            self.body(pose, lift, g.get("pitch", 0.0), 0.0, 0.0, [(breath * 0.8, 0.0)] * len(s.chains["spine"]),
                      neck, tuple(g["head"]), 0.0, tail, breath=breath * 0.025)
            # The legs folded under it: each hind foot's toes ahead of it on the ground, the long foot bone laid
            # down behind them -- sitting on its heels, as a resting bird does.
            for key in self.legs:
                rest = self.rest_feet[key]
                foot = Vector((rest.x * g.get("tuck", 1.1), rest.y + g.get("toes_ahead", 0.05), 0.0))
                pose.limb(key, foot, 0.0, tilt=g.get("tilt", 80.0))
            if self.plan == "biped":
                self.arms_at(pose, 0.0, t, raise_=-0.04, curl=0.9)
            return pose
        return frames, at, True

    # ==========================================================================

    def all(self):
        """Each clip the game plays: name -> (frames, pose_at, looped)."""
        out = {"idle": self.idle(), "walk": self.gait("walk"), "run": self.gait("run"), "attack": self.attack(),
               "death": self.death()}
        if "sleep" in self.spec:
            out["sleep"] = self.sleep()
        return out
