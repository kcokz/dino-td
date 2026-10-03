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
                # A long neck swept slowly from side to side as it crops ("sweep": degrees either way, "sweeps"
                # times round the loop).
                sweep = graze.get("sweep", 0.0) * math.sin(TAU * graze.get("sweeps", 1) * t) * down
                neck = [((graze["neck"] * down + nod * up) / n_neck, (look * up + sweep) / n_neck)] * n_neck
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

    def swipe(self):
        """A blow of the tail (a stegosaur's spikes, a sauropod's whip): the body turned a little away and the
        tail drawn round to one side, then swung hard across to the other and back, a wave down it, the feet
        planted -- in place of a bite (spec attack "swipe": the tail's swing in degrees, all along it)."""
        g = self.spec["attack"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_tail = len(s.chains["tail"])
        n_neck = len(s.chains["neck"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            pose.set_root()
            # Drawn round to the left, swung across to the right, back to the middle.
            wind = ramp(t, 0.0, 0.35) * (1.0 - ramp(t, 0.35, 0.6))
            blow = ramp(t, 0.35, 0.6) * (1.0 - ramp(t, 0.62, 1.0))
            swing = g["swipe"] * (0.55 * wind - blow)
            tail = [(g.get("tail_up", 2.0) * blow / n_tail, swing / n_tail * (0.6 + 0.8 * i / max(1, n_tail - 1)))
                    for i in range(n_tail)]
            yaw = -swing * g.get("turn", 0.12)
            spine = [(0.0, yaw / n_spine)] * n_spine
            # The head turned back over its shoulder to see what it strikes.
            neck = [(0.0, -swing * g.get("look", 0.2) / n_neck)] * n_neck
            self.body(pose, Vector((0.0, 0.0, -g.get("dip", 0.02) * blow)), 0.0, 0.0, yaw * 0.5, spine, neck,
                      (0.0, 0.0, 0.0), g.get("jaw", 0.0) * blow, tail)
            self.standing(pose, t)
            return pose
        return frames, at, True

    def graze(self):
        """Grazing and nothing else: its head down at the ground the whole loop, cropping, its neck sweeping --
        the idle's grazing (spec idle "graze") without its looks about."""
        g = dict(self.spec["idle"])
        gz = dict(g["graze"])
        gz["up"] = (2.0, 2.0)
        g["graze"] = gz
        g["period"] = self.spec.get("graze", {}).get("period", g["period"])
        keep = self.spec["idle"]
        self.spec["idle"] = g
        try:
            return self.idle()
        finally:
            self.spec["idle"] = keep

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

    # ==========================================================================
    # Flight (plan "flyer": a pterosaur on the wing -- tools/dino_rig.py "spread", "wing")
    # ==========================================================================

    def _wings(self, pose, up, sweep=0.0, fold=0.0, twist=0.0):
        """Both wings posed, each bone from its rest on the one before: `up` the pitches raising them (the upper
        arm, the forearm, the hand, then each bone of the wing finger -- a wave out along the wing is each a little
        behind the one before), swept back by `sweep` at the shoulder, folded by `fold` (0 spread, 1 the elbow
        and the wing finger closed up to the body), pronated by `twist` (the leading edge turned down). Degrees;
        the same for both sides, mirrored."""
        for key, info in self.skel.limbs.items():
            wing = info.get("wing")
            if not wing:
                continue
            sign = info["sign"]
            names = info["names"]
            ups = list(up) + [up[-1]] * (3 + len(wing) - len(up))
            pose.bend(names[0], ups[0], -sign * sweep, sign * twist)
            pose.bend(names[1], ups[1], sign * fold * self.spec["wings"].get("elbow", 55.0), sign * twist * 0.3)
            pose.bend(names[2], ups[2], -sign * fold * self.spec["wings"].get("wrist", 10.0))
            pose.bend(names[3], -10.0 * fold)
            for i, n in enumerate(wing):
                flex = self.spec["wings"].get("finger", 70.0) if i == 0 else 6.0
                pose.bend(n, ups[3 + i], -sign * fold * flex, sign * twist * (0.4 if i == 0 else 0.0))

    def _trail(self, pose, swing=0.0, spread=0.0, tuck=0.0):
        """The legs trailing behind in flight: swung up and down by `swing` degrees, spread apart by `spread`,
        drawn up under the body by `tuck` (0 trailing, 1 drawn in)."""
        for key, info in self.skel.limbs.items():
            if info.get("wing") or not key.startswith("hind"):
                continue
            sign = info["sign"]
            names = info["names"]
            pose.bend(names[0], swing - 50.0 * tuck, sign * spread)
            pose.bend(names[1], swing * 0.5 + 70.0 * tuck)
            pose.bend(names[2], -20.0 * tuck)
            pose.bend(names[3], 0.0)

    def flap(self, which):
        """A wingbeat, round and round (spec["fly"] / ["walk"] / ["run"]): the downstroke the wing held out and
        turned leading edge down, driving the body up; the upstroke the elbow and the wing finger a little
        folded, the wing turned back, the body sinking; the wing finger a little behind the arm all through, so
        the beat runs out along the wing in a wave; the head held steady, the tail and the legs swinging with
        it."""
        g = self.spec[which]
        frames = max(8, int(round(g["period"] * FPS)))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            ph = TAU * t
            # Highest at the bottom of the downstroke, lowest at its top.
            pose.set_root(Vector((0.0, 0.0, -g.get("bob", 0.02) * math.sin(ph))))
            pitch = -g.get("pitch_bob", 2.0) * math.sin(ph) + g.get("pitch", 0.0)
            tail = [(g.get("tail_lift", 0.0) / n_tail + g.get("tail_wave", 1.5) * math.sin(ph - 0.6 * i), 0.0)
                    for i in range(n_tail)]
            neck = [(g.get("neck_pitch", 0.0) / n_neck, 0.0)] * n_neck
            self.body(pose, None, pitch, 0.0, 0.0, [(0.0, 0.0)] * n_spine, neck, (g.get("head_pitch", 0.0), 0.0, 0.0),
                      g.get("jaw", 0.0), tail, steady=g.get("steady", 0.9))
            amp = g["amplitude"]
            up = [g.get("dihedral", 6.0) + amp[0] * math.sin(ph),
                  amp[1] * math.sin(ph - 0.5),
                  0.0] + [amp[2] * math.sin(ph - 1.0)] + [amp[3] * math.sin(ph - 1.4)] * 3
            fold = g.get("fold", 0.3) * max(0.0, math.cos(ph)) ** 1.5
            # Pronated (its leading edge down) through the downstroke, turned back up through the upstroke.
            twist = g.get("twist", 10.0) * math.cos(ph)
            self._wings(pose, up, g.get("sweep", 0.0) + g.get("sweep_beat", 6.0) * math.cos(ph), fold, twist)
            self._trail(pose, g.get("leg_swing", 4.0) * math.sin(ph - 1.2), g.get("leg_spread", 4.0))
            return pose
        return frames, at, True

    def glide(self):
        """Soaring on still wings: the wings held out with a little dihedral, trimmed now and then; the body
        banking gently one way and the other, the head turning to look down about it, the tail's vane steering."""
        g = self.spec["glide"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            ph = TAU * t
            bank = g.get("bank", 5.0) * math.sin(ph)
            pose.set_root(Vector((0.0, 0.0, g.get("bob", 0.01) * math.sin(2.0 * ph))),
                          Quaternion(FWD, math.radians(bank)))
            look = g.get("look", 20.0) * math.sin(ph + 0.8)
            neck = [(g.get("neck_pitch", 0.0) / n_neck, look / n_neck)] * n_neck
            tail = [(0.3 * math.sin(ph - 0.3 * i), g.get("steer", 2.0) * math.sin(ph + 1.5) / n_tail) for i in range(n_tail)]
            self.body(pose, None, g.get("pitch", 0.0), 0.0, 0.0, [(0.0, 0.0)] * n_spine, neck,
                      (g.get("head_pitch", -6.0), look * 0.4, 0.0), 0.0, tail)
            trim = g.get("trim", 2.0) * math.sin(2.0 * ph)
            up = [g.get("dihedral", 6.0) + trim, 0.0, 0.0, g.get("tips", 3.0), 1.0, 1.0, 1.0]
            self._wings(pose, up, g.get("sweep", 0.0) + 2.0 * math.sin(ph), g.get("fold", 0.04), 0.0)
            self._trail(pose, 1.5 * math.sin(ph), g.get("leg_spread", 4.0))
            return pose
        return frames, at, True

    def dive(self):
        """The strike from the air, round and round as the game holds it: the wings swept back and half folded,
        the body pitched down and the neck drawn back, the jaws opening; the head driven forward and down and
        the jaws snapping shut; a hard downstroke to climb out, back to where it began."""
        g = self.spec["attack"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            stoop = ramp(t, 0.0, 0.3) * (1.0 - ramp(t, 0.5, 0.75))
            strike = pulse(t, 0.32, 0.56)
            climb = pulse(t, 0.5, 1.0)
            lunge = Vector((0.0, g.get("lunge", 0.25) * strike, -g.get("drop", 0.12) * stoop + g.get("rise", 0.06) * climb))
            pose.set_root(lunge)
            pitch = -g.get("dive", 28.0) * stoop + 10.0 * climb
            neck = [((g.get("draw", 16.0) * stoop * (1.0 - strike) - g.get("reach", 30.0) * strike) / n_neck, 0.0)] * n_neck
            jaw = g.get("jaw", 40.0) * ramp(t, 0.12, 0.38) * (1.0 - ramp(t, 0.44, 0.52))
            tail = [(4.0 * stoop / n_tail - 6.0 * climb / n_tail, 0.0)] * n_tail
            self.body(pose, None, pitch, 0.0, 0.0, [(0.0, 0.0)] * n_spine, neck,
                      (g.get("head_up", 14.0) * stoop * (1.0 - strike) - g.get("head_down", 16.0) * strike, 0.0, 0.0),
                      jaw, tail)
            beat = math.sin(math.pi * ramp(t, 0.55, 0.95))
            up = [6.0 + 24.0 * stoop - 40.0 * beat, 6.0 * stoop - 6.0 * beat, 0.0, -6.0 * beat, -2.0 * beat,
                  -2.0 * beat, -2.0 * beat]
            self._wings(pose, up, g.get("sweep", 26.0) * stoop, g.get("fold", 0.55) * stoop,
                        8.0 * beat - 6.0 * stoop)
            self._trail(pose, -6.0 * stoop, 4.0 + 6.0 * strike, 0.6 * strike)
            return pose
        return frames, at, True

    def hurt(self):
        """Struck: the wings flung up and back, the body knocked over and the head thrown up, the jaws open --
        and back to the glide. Played once."""
        g = self.spec["hurt"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            jolt = ramp(t, 0.0, 0.18) * (1.0 - ramp(t, 0.25, 1.0))
            pose.set_root(Vector((g.get("knock", 0.06) * jolt, -0.04 * jolt, 0.03 * jolt)),
                          Quaternion(FWD, math.radians(g.get("roll", 18.0) * jolt)))
            neck = [(g.get("recoil", 20.0) * jolt / n_neck, 6.0 * jolt / n_neck)] * n_neck
            tail = [(5.0 * jolt / n_tail, 4.0 * jolt / n_tail)] * n_tail
            self.body(pose, None, 8.0 * jolt, 0.0, 0.0, [(0.0, 0.0)] * n_spine, neck, (10.0 * jolt, 0.0, 0.0),
                      g.get("jaw", 30.0) * jolt, tail)
            up = [6.0 + 34.0 * jolt, 8.0 * jolt, 0.0, 10.0 * jolt, 3.0, 3.0, 3.0]
            self._wings(pose, up, 14.0 * jolt, 0.3 * jolt, -6.0 * jolt)
            self._trail(pose, 8.0 * jolt, 4.0 + 8.0 * jolt, 0.4 * jolt)
            return pose
        return frames, at, False

    def crash(self):
        """Killed on the wing, down on the ground: the jolt -- its wings flung up and back, its head thrown up, the
        jaws open -- then it crumples, nose down, the wings collapsing, and lies spread on its belly, the wings
        crumpled out flat to either side, its head turned aside on the ground. No roll: it is the same whether the
        game drops it from the air first or lays it straight on the ground. It ends lying with its belly where its
        lowest point is as it flies (the origin's level less a body's half depth), so a model stood on its lowest
        point (VISUALS anchor "feet") lies on the ground."""
        g = self.spec["death"]
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            jolt = pulse(t, 0.0, 0.32)
            slump = ramp(t, 0.12, 0.6)
            settle = ramp(t, 0.5, 1.0)
            air = 1.0 - settle
            # A bounce at the blow, nose down as it crumples, level again lying.
            nose = Quaternion(RIGHT, math.radians(-g.get("nose", 14.0) * pulse(t, 0.1, 0.75) + 6.0 * jolt))
            pose.set_root(Vector((0.0, 0.0, 0.025 * jolt + g.get("lie", 0.0) * settle)), nose)
            neck = [((14.0 * jolt * air - g.get("limp_neck", 10.0) * settle) / n_neck,
                     g.get("turn", 30.0) * settle / n_neck)] * n_neck
            tail = [((3.0 * jolt - 3.0 * settle) / n_tail, 2.0 * settle * math.sin(1.7 * i)) for i in range(n_tail)]
            self.body(pose, None, 0.0, 0.0, 0.0, [(0.0, 0.0)] * n_spine, neck,
                      (16.0 * jolt * air + 4.0 * settle, 10.0 * settle, 0.0), 32.0 * jolt + 8.0 * settle, tail)
            flail = [6.0 + 46.0 * jolt - 18.0 * slump, 6.0 * jolt - 8.0 * slump, 0.0, 10.0 * jolt - 10.0 * slump,
                     -4.0 * slump, -3.0 * slump, -3.0 * slump]
            lying = [-28.0, 24.0, 0.0, 6.0, 2.0, 0.0, 0.0]
            up = [a * air + b * settle for a, b in zip(flail, lying)]
            self._wings(pose, up, 14.0 * jolt * air + 16.0 * settle, 0.55 * slump * air + 0.45 * settle,
                        -8.0 * slump * air)
            self._trail(pose, 10.0 * jolt * air - 4.0 * settle, 4.0 + 10.0 * settle, 0.3 * slump * air)
            return pose
        return frames, at, False

    def tumble(self):
        """Falling out of the sky, killed, round and round as long as the game drops it: limp, rolling over and
        over nose down, the wings half folded and flailing -- for the drop, before its "death" on the ground."""
        g = self.spec.get("fall", {"period": 0.9})
        frames = int(round(g["period"] * FPS))
        s = self.skel
        n_neck = len(s.chains["neck"])
        n_tail = len(s.chains["tail"])
        n_spine = len(s.chains["spine"])

        def at(t):
            pose = Pose(s)
            roll = Quaternion(FWD, math.radians(360.0 * t))
            nose = Quaternion(RIGHT, math.radians(-g.get("nose", 35.0) - 10.0 * math.sin(TAU * t)))
            pose.set_root(None, nose @ roll)
            neck = [((-8.0 + 6.0 * math.sin(TAU * t)) / n_neck, 8.0 * math.sin(TAU * t + 1.0) / n_neck)] * n_neck
            tail = [(4.0 * math.sin(TAU * t - 0.5 * i) / n_tail, 3.0 * math.cos(TAU * t - 0.5 * i) / n_tail)
                    for i in range(n_tail)]
            self.body(pose, None, 0.0, 0.0, 0.0, [(0.0, 0.0)] * n_spine, neck, (-6.0, 0.0, 0.0), 14.0, tail)
            flap = math.sin(TAU * t)
            up = [-10.0 + 14.0 * flap, -8.0, 0.0, -10.0 + 6.0 * flap, -4.0, -4.0, -4.0]
            self._wings(pose, up, 20.0, 0.75, -10.0)
            self._trail(pose, 6.0 * flap, 10.0, 0.2)
            return pose
        return frames, at, True

    def all(self):
        """Each clip the game plays: name -> (frames, pose_at, looped)."""
        if self.plan == "flyer":
            # A flyer's: its wingbeat ("fly"; "walk" the same beat, "run" a harder, quicker one -- so the game's
            # gaits drawn by pace make it flap), its glide ("glide"; "idle" the same), the strike from the air
            # ("attack"), hurt, killed -- falling out of the sky ("fall", round and round as it drops) and down on
            # the ground ("death").
            return {"fly": self.flap("fly"), "walk": self.flap("fly"), "run": self.flap("run"),
                    "glide": self.glide(), "idle": self.glide(), "attack": self.dive(), "hurt": self.hurt(),
                    "fall": self.tumble(), "death": self.crash()}
        out = {"idle": self.idle(), "walk": self.gait("walk"), "run": self.gait("run"),
               "attack": self.swipe() if "swipe" in self.spec["attack"] else self.attack(),
               "death": self.death()}
        if "sleep" in self.spec:
            out["sleep"] = self.sleep()
        if "graze" in self.spec:
            out["graze"] = self.graze()
        return out
