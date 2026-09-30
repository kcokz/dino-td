# tools/triassic_bodies.py
# THE FIRST MAP'S CAST, SCULPTED ROUND THEIR BONES (tools/sculpt.py; the player, 2026-09-30: "恐龙目前模型做的都
# 粗糙，我需要它们更精致"). Each animal's body as it is drawn: its cross-sections from the tip of the snout to
# the tip of the tail, its limbs, feet and hands, its eyes, teeth and claws, its bony plates, and the colours
# and marks of its skin. Sizes are in the rig's units (a Coelophysis stands about six and a half of them to the
# top of its head); the game fits each animal to its height (Config.VISUALS "fit": "height").
#
# Used by tools/generate_triassic.py, in Blender.

import math

from mathutils import Vector, noise

import sculpt as sc

TRUNK = [("Head_end", True), ("Head", True), ("Neck", True), ("Shoulders", True), ("Torso", True),
         ("Hips", True), ("Back", False), ("Tail1", False), ("Tail2", False), ("Tail3", False),
         ("Tail4", False), ("Tail5", False), ("Tail5_end", False)]


def st(bone, t, w, top, bot, **kw):
    d = {"w": w, "top": top, "bot": bot}
    d.update(kw)
    return (bone, t, d)


def both(limb):
    """A limb given for the left, and the same for the right."""
    def swap(x):
        if isinstance(x, str):
            return x.replace(".L", ".R")
        if isinstance(x, (list, tuple)):
            return type(x)(swap(y) for y in x)
        if isinstance(x, dict):
            return {k: swap(v) for k, v in x.items()}
        return x
    return [limb, swap(limb)]


# ==============================================================================
# Coelophysis bauri: slight, long-necked, long-tailed, big-eyed -- the pack hunter of the Chinle
# ==============================================================================

COELOPHYSIS = {
    "around": 36,
    "soften": 0.22,
    "rough": 0.012,
    "trunk": [
        # The skull: long, low and narrow, a kink in the upper jaw behind the nostril, big orbits, the
        # jaw muscles swelling its back.
        st("Head", 1.07, 0.02, 0.02, 0.02, step=0.03),
        st("Head", 1.035, 0.07, 0.07, 0.065, step=0.03),
        st("Head", 0.98, 0.1, 0.12, 0.1, n_top=2.2, step=0.04),
        st("Head", 0.86, 0.12, 0.155, 0.13, step=0.05),
        st("Head", 0.74, 0.14, 0.18, 0.155, step=0.05),
        st("Head", 0.56, 0.18, 0.27, 0.2, step=0.05),
        st("Head", 0.38, 0.23, 0.35, 0.26, lift=0.03, step=0.05),
        st("Head", 0.2, 0.27, 0.34, 0.32, lift=0.02, step=0.05),
        st("Head", 0.06, 0.23, 0.27, 0.29, step=0.06),
        # The neck: slender, thickening to the chest.
        st("Neck", 0.9, 0.17, 0.18, 0.22, step=0.08),
        st("Neck", 0.6, 0.175, 0.19, 0.23, step=0.1),
        st("Neck", 0.28, 0.2, 0.21, 0.27, step=0.1),
        st("Shoulders", 0.6, 0.25, 0.23, 0.33, step=0.1),
        st("Shoulders", 0.1, 0.34, 0.28, 0.48, step=0.12),
        # The body: a deep chest, a slim waist, the hips.
        st("Torso", 0.8, 0.43, 0.34, 0.74, n_bot=2.3, step=0.12),
        st("Torso", 0.45, 0.47, 0.37, 0.8, n_bot=2.3, step=0.14),
        st("Torso", 0.1, 0.45, 0.39, 0.66, step=0.14),
        st("Hips", 0.5, 0.46, 0.42, 0.55, keel=0.03, step=0.14),
        st("Back", 0.4, 0.43, 0.41, 0.52, keel=0.03, step=0.14),
        # The tail: deep at its root with the muscle that pulls the legs back, then long and thin.
        st("Tail1", 0.3, 0.34, 0.35, 0.44, step=0.16),
        st("Tail1", 0.9, 0.26, 0.27, 0.33, step=0.18),
        st("Tail2", 0.5, 0.19, 0.2, 0.23, step=0.2),
        st("Tail3", 0.5, 0.125, 0.13, 0.145, step=0.22),
        st("Tail4", 0.5, 0.082, 0.085, 0.09, step=0.22),
        st("Tail5", 0.5, 0.05, 0.05, 0.05, step=0.2),
        st("Tail5_end", 0.25, 0.018, 0.018, 0.018, step=0.1),
    ],
    # The lip line, where the upper jaw closes over the lower (a groove, and the teeth along it).
    "mouth": {"from": ("Head", 0.2), "to": ("Head", 1.03), "phi": 106.0, "depth": 0.03, "width": 0.14},
    "teeth": {"from": ("Head", 0.32), "to": ("Head", 0.98), "count": 18, "length": 0.04, "radius": 0.013,
              "colour": (0.74, 0.7, 0.6)},
    "eyes": {"at": ("Head", 0.37), "phi": 58.0, "radius": 0.085, "sunk": 0.5, "forward": 14.0, "up": 6.0,
             "iris": (0.62, 0.42, 0.05), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
    "brow": {"at": ("Head", 0.39), "phi": 32.0, "size": 0.1, "height": 0.05},
    # The hollow in front of the eye (the antorbital fenestra, under the skin).
    "fossa": {"from": ("Head", 0.45), "to": ("Head", 0.68), "phi": 70.0, "depth": 0.03, "width": 0.3},
    "nostrils": {"at": ("Head", 0.97), "phi": 52.0, "size": 0.024},
    "legs": both({"links": [("BackLeg.L", False), ("BackUpLeg.L", False), ("BackLowLeg.L", False)],
                  "stations": [("BackLeg.L", 0.2, 0.26, 0.46), ("BackUpLeg.L", 0.0, 0.31, 0.46),
                               ("BackUpLeg.L", 0.25, 0.29, 0.4), ("BackUpLeg.L", 0.6, 0.2, 0.27),
                               ("BackUpLeg.L", 0.92, 0.13, 0.17), ("BackLowLeg.L", 0.15, 0.115, 0.16),
                               ("BackLowLeg.L", 0.55, 0.085, 0.11), ("BackLowLeg.L", 0.95, 0.07, 0.085)],
                  "foot": "BackFoot.L"})
    + both({"links": [("FrontLeg.L", False), ("FrontUpLeg.L", False), ("FrontLowLeg.L", False), ("FrontFoot.L", False)],
            "stations": [("FrontLeg.L", 0.5, 0.12, 0.14), ("FrontUpLeg.L", 0.0, 0.11, 0.12),
                         ("FrontUpLeg.L", 0.6, 0.075, 0.085), ("FrontLowLeg.L", 0.1, 0.065, 0.07),
                         ("FrontLowLeg.L", 0.9, 0.05, 0.055), ("FrontFoot.L", 0.12, 0.055, 0.045),
                         ("FrontFoot.L", 0.3, 0.05, 0.035)],
            "hand": "FrontFoot.L"}),
    # Three toes forward and the small first one behind, raised (degrees off the foot's line, outward
    # positive; length; radius at the root; its claw's length).
    "toes": [(0.0, 0.6, 0.05, 0.13), (-19.0, 0.5, 0.047, 0.12), (19.0, 0.47, 0.044, 0.11)],
    "hallux": (150.0, 0.18, 0.03, 0.08),
    # Three grasping fingers.
    "fingers": [(0.0, 0.34, 0.028, 0.1), (-16.0, 0.3, 0.026, 0.09), (16.0, 0.24, 0.024, 0.08)],
    "skin": {
        "back": (0.12, 0.06, 0.02),
        "flank": (0.36, 0.2, 0.07),
        "belly": (0.62, 0.52, 0.36),
        "mottle": 0.18,
        # Dark saddles over the back and rings round the tail.
        "bands": {"colour": (0.04, 0.025, 0.012), "from": ("Shoulders", 0.4), "to": ("Tail5_end", 0.5),
                  "period": 0.95, "width": 0.34, "strength": 0.78},
        # A dark stripe from the nostril through the eye, and a pale throat.
        "eye_stripe": {"colour": (0.05, 0.032, 0.018), "phi": 72.0, "width": 16.0, "from": ("Head", 1.0),
                       "to": ("Neck", 0.85)},
        "throat": (0.66, 0.58, 0.44),
        "lips": (0.12, 0.07, 0.04),
        "claws": (0.045, 0.036, 0.03),
    },
}


# ==============================================================================
# Hesperosuchus agilis: the crocodile's line before it took to the water -- small, slender, long-legged, a
# long narrow snout and big eyes, paired bony plates down its back
# ==============================================================================

HESPEROSUCHUS = {
    "around": 32,
    "soften": 0.2,
    "rough": 0.01,
    "trunk": [
        st("Head", 1.01, 0.02, 0.02, 0.02, step=0.03),
        st("Head", 0.97, 0.06, 0.065, 0.055, step=0.04),
        st("Head", 0.85, 0.075, 0.09, 0.075, n_top=2.4, step=0.05),
        st("Head", 0.62, 0.1, 0.13, 0.1, n_top=2.4, step=0.05),
        st("Head", 0.42, 0.15, 0.19, 0.15, step=0.05),
        st("Head", 0.27, 0.21, 0.27, 0.22, lift=0.02, step=0.05),
        st("Head", 0.12, 0.23, 0.26, 0.27, step=0.05),
        st("Head", 0.0, 0.19, 0.21, 0.25, step=0.06),
        st("Neck", 0.5, 0.2, 0.22, 0.28, step=0.08),
        st("Shoulders", 0.5, 0.29, 0.28, 0.4, step=0.1),
        st("Torso", 0.8, 0.41, 0.33, 0.58, n_top=2.3, step=0.12),
        st("Torso", 0.4, 0.45, 0.35, 0.6, n_top=2.3, step=0.14),
        st("Torso", 0.05, 0.43, 0.37, 0.5, step=0.14),
        st("Hips", 0.5, 0.43, 0.39, 0.46, step=0.14),
        st("Back", 0.5, 0.39, 0.37, 0.42, step=0.14),
        st("Tail1", 0.4, 0.29, 0.31, 0.34, step=0.16),
        st("Tail2", 0.5, 0.18, 0.2, 0.21, step=0.2),
        st("Tail3", 0.5, 0.115, 0.125, 0.125, step=0.22),
        st("Tail4", 0.5, 0.072, 0.078, 0.076, step=0.22),
        st("Tail5", 0.5, 0.043, 0.045, 0.043, step=0.2),
        st("Tail5_end", 0.3, 0.015, 0.015, 0.015, step=0.1),
    ],
    "mouth": {"from": ("Head", 0.12), "to": ("Head", 0.98), "phi": 104.0, "depth": 0.022, "width": 0.14},
    "teeth": {"from": ("Head", 0.2), "to": ("Head", 0.96), "count": 16, "length": 0.035, "radius": 0.011,
              "colour": (0.74, 0.7, 0.58)},
    "eyes": {"at": ("Head", 0.26), "phi": 50.0, "radius": 0.08, "sunk": 0.5, "forward": 10.0, "up": 12.0,
             "iris": (0.58, 0.52, 0.12), "pupil": (0.008, 0.006, 0.005), "slit": 0.28},
    "brow": {"at": ("Head", 0.28), "phi": 28.0, "size": 0.09, "height": 0.035},
    "nostrils": {"at": ("Head", 0.95), "phi": 38.0, "size": 0.02},
    "plates": {"from": ("Neck", 0.3), "to": ("Tail4", 0.6), "rows": [11.0], "spacing": 0.24, "ref": 0.43,
               "length": 0.22, "width": 0.17, "height": 0.05, "colour": (0.07, 0.058, 0.038)},
    "legs": both({"links": [("BackLeg.L", False), ("BackUpLeg.L", False), ("BackLowLeg.L", False)],
                  "stations": [("BackLeg.L", 0.2, 0.25, 0.42), ("BackUpLeg.L", 0.0, 0.29, 0.43),
                               ("BackUpLeg.L", 0.3, 0.26, 0.36), ("BackUpLeg.L", 0.65, 0.17, 0.22),
                               ("BackUpLeg.L", 0.93, 0.12, 0.15), ("BackLowLeg.L", 0.15, 0.105, 0.14),
                               ("BackLowLeg.L", 0.55, 0.08, 0.1), ("BackLowLeg.L", 0.95, 0.065, 0.08)],
                  "foot": "BackFoot.L"})
    # Forelimbs long enough to walk on: the hand is a foot.
    + both({"links": [("FrontLeg.L", False), ("FrontUpLeg.L", False), ("FrontLowLeg.L", False), ("FrontFoot.L", False)],
            "stations": [("FrontLeg.L", 0.5, 0.13, 0.16), ("FrontUpLeg.L", 0.0, 0.14, 0.16),
                         ("FrontUpLeg.L", 0.55, 0.1, 0.11), ("FrontLowLeg.L", 0.1, 0.085, 0.09),
                         ("FrontLowLeg.L", 0.9, 0.06, 0.065), ("FrontFoot.L", 0.15, 0.06, 0.05),
                         ("FrontFoot.L", 0.4, 0.055, 0.04)],
            "hand": "FrontFoot.L"}),
    "toes": [(0.0, 0.5, 0.045, 0.1), (-16.0, 0.44, 0.042, 0.09), (16.0, 0.42, 0.04, 0.09), (32.0, 0.3, 0.034, 0.07)],
    "hallux": None,
    "fingers": [(-8.0, 0.26, 0.026, 0.07), (8.0, 0.26, 0.026, 0.07), (-24.0, 0.2, 0.022, 0.06), (24.0, 0.2, 0.022, 0.06)],
    "hand_at": 0.45,
    "skin": {
        "back": (0.09, 0.075, 0.048),
        "flank": (0.25, 0.21, 0.14),
        "belly": (0.56, 0.51, 0.41),
        "mottle": 0.14,
        # Dark speckles over the back and flanks.
        "spots": {"colour": (0.03, 0.025, 0.017), "scale": 2.6, "above": 0.32, "strength": 0.75,
                  "from": ("Head", 0.1), "to": ("Tail5", 0.5)},
        "throat": (0.6, 0.56, 0.46),
        "lips": (0.07, 0.06, 0.04),
        "claws": (0.04, 0.035, 0.03),
    },
}


# ==============================================================================
# The phytosaur (Machaeroprosopus): the river's hunter -- a long, narrow snout with a rosette of teeth at its
# tip and its nostrils on a mound in front of the eyes, a broad armoured back, a deep tail it swims with
# ==============================================================================

PHYTOSAUR = {
    "around": 36,
    "soften": 0.3,
    "rough": 0.01,
    "trunk": [
        st("Head", 1.76, 0.04, 0.04, 0.04, step=0.04),
        st("Head", 1.73, 0.12, 0.09, 0.09, step=0.04),
        st("Head", 1.63, 0.155, 0.12, 0.12, step=0.05),
        st("Head", 1.48, 0.11, 0.1, 0.1, n_top=2.4, step=0.06),
        st("Head", 1.1, 0.13, 0.12, 0.12, n_top=2.4, step=0.07),
        st("Head", 0.75, 0.19, 0.16, 0.15, n_top=2.5, step=0.07),
        st("Head", 0.48, 0.3, 0.22, 0.2, n_top=2.8, step=0.06),
        st("Head", 0.3, 0.44, 0.28, 0.26, n_top=3.0, step=0.06),
        st("Head", 0.13, 0.52, 0.29, 0.34, n_top=3.2, step=0.07),
        st("Head", 0.0, 0.46, 0.28, 0.4, n_top=2.6, step=0.08),
        # A heavy, low-slung body: its belly hangs well down between the legs, as a crocodile's does -- the
        # triceratops' legs it walks on are long, and a slim body stood on them like stilts.
        st("Neck", 0.5, 0.54, 0.36, 0.55, n_top=2.4, step=0.1),
        st("Shoulders", 0.9, 0.8, 0.42, 0.8, n_top=2.6, step=0.12),
        st("Shoulders", 0.4, 1.05, 0.46, 1.12, n_top=2.8, n_bot=2.4, step=0.14),
        st("Torso", 0.8, 1.12, 0.48, 1.3, n_top=2.8, n_bot=2.6, step=0.14),
        st("Torso", 0.3, 1.14, 0.5, 1.28, n_top=2.8, n_bot=2.6, step=0.14),
        st("Hips", 0.5, 1.16, 0.5, 1.02, n_top=2.6, step=0.14),
        st("Back", 0.5, 0.82, 0.45, 0.72, n_top=2.4, step=0.14),
        # The tail: deep and narrow -- what it swims with -- a crest of plates along its top, lying on the
        # ground towards its tip as a crocodile's does.
        st("Tail1", 0.4, 0.45, 0.46, 0.44, keel=0.04, step=0.16),
        st("Tail2", 0.5, 0.3, 0.4, 0.34, keel=0.05, lift=0.05, step=0.18),
        st("Tail3", 0.5, 0.2, 0.34, 0.26, keel=0.05, lift=0.2, step=0.2),
        st("Tail4", 0.5, 0.13, 0.26, 0.18, keel=0.04, lift=0.5, step=0.2),
        st("Tail5", 0.5, 0.08, 0.17, 0.1, keel=0.03, lift=0.75, step=0.2),
        st("Tail5_end", 0.4, 0.03, 0.06, 0.03, lift=0.92, step=0.12),
    ],
    "mouth": {"from": ("Head", 0.12), "to": ("Head", 1.73), "phi": 100.0, "depth": 0.03, "width": 0.15},
    "teeth": {"from": ("Head", 0.2), "to": ("Head", 1.71), "count": 30, "length": 0.08, "radius": 0.02,
              "colour": (0.72, 0.68, 0.56), "rosette": 1.7},
    "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 1.68), "count": 24, "length": 0.06, "radius": 0.017},
    "eyes": {"at": ("Head", 0.31), "phi": 36.0, "radius": 0.1, "sunk": 0.45, "forward": 6.0, "up": 26.0,
             "iris": (0.62, 0.5, 0.16), "pupil": (0.008, 0.006, 0.005), "slit": 0.22},
    "brow": {"at": ("Head", 0.33), "phi": 24.0, "size": 0.12, "height": 0.05},
    # Its nostrils on a mound in front of the eyes, where a phytosaur's are -- not at the tip of its snout.
    "mound": {"at": ("Head", 0.5), "size": 0.14, "height": 0.07},
    "nostrils": {"at": ("Head", 0.5), "phi": 12.0, "size": 0.03},
    "plates": {"from": ("Neck", 0.1), "to": ("Tail5", 0.3), "rows": [10.0, 34.0], "spacing": 0.3, "ref": 0.9,
               "length": 0.3, "width": 0.24, "height": 0.08, "colour": (0.024, 0.027, 0.016)},
    # Each leg from just over its hip or shoulder, down: the body is broad enough to take the top of it, and
    # a leg that came out along the hip bone and turned down stood up over the back in a hump.
    "legs": both({"links": [("BackUpLeg.L", False), ("BackLowLeg.L", False)],
                  "stations": [("BackUpLeg.L", -0.18, 0.4, 0.55), ("BackUpLeg.L", 0.0, 0.48, 0.64),
                               ("BackUpLeg.L", 0.35, 0.42, 0.54), ("BackUpLeg.L", 0.8, 0.3, 0.35),
                               ("BackLowLeg.L", 0.1, 0.27, 0.31), ("BackLowLeg.L", 0.6, 0.21, 0.23),
                               ("BackLowLeg.L", 0.96, 0.19, 0.2)],
                  "foot": "BackFoot.L",
                  "toes": [(-26.0, 0.5, 0.07, 0.1), (-9.0, 0.62, 0.075, 0.11), (9.0, 0.64, 0.075, 0.11),
                           (27.0, 0.52, 0.068, 0.1)]})
    + both({"links": [("FrontUpLeg.L", False), ("FrontLowLeg.L", False)],
            "stations": [("FrontUpLeg.L", -0.18, 0.32, 0.42), ("FrontUpLeg.L", 0.0, 0.4, 0.48),
                         ("FrontUpLeg.L", 0.5, 0.3, 0.34), ("FrontUpLeg.L", 0.95, 0.23, 0.25),
                         ("FrontLowLeg.L", 0.2, 0.21, 0.23), ("FrontLowLeg.L", 0.6, 0.17, 0.19),
                         ("FrontLowLeg.L", 0.96, 0.16, 0.18)],
            "foot": "FrontFoot.L",
            "toes": [(-44.0, 0.28, 0.05, 0.07), (-20.0, 0.34, 0.055, 0.08), (0.0, 0.36, 0.055, 0.08),
                     (20.0, 0.33, 0.052, 0.07), (42.0, 0.26, 0.045, 0.06)]}),
    "hallux": None,
    "skin": {
        "back": (0.022, 0.026, 0.014),
        "flank": (0.065, 0.068, 0.038),
        "belly": (0.34, 0.32, 0.23),
        "mottle": 0.16,
        "bands": {"colour": (0.012, 0.014, 0.008), "from": ("Shoulders", 0.5), "to": ("Tail5_end", 0.5),
                  "period": 1.3, "width": 0.3, "strength": 0.55},
        "throat": (0.46, 0.43, 0.32),
        "lips": (0.02, 0.02, 0.012),
        "claws": (0.03, 0.03, 0.025),
    },
}


# ==============================================================================
# Postosuchus: the valley's great land hunter, of the crocodile's line -- a deep, narrow skull with a hooked
# profile and big teeth, a heavy body, paired plates down its back
# ==============================================================================

POSTOSUCHUS = {
    "around": 36,
    "soften": 0.25,
    "rough": 0.012,
    "trunk": [
        st("Head", 1.07, 0.05, 0.05, 0.05, step=0.03),
        st("Head", 1.03, 0.19, 0.25, 0.23, step=0.04),
        st("Head", 0.9, 0.23, 0.39, 0.31, n_top=2.3, step=0.05),
        st("Head", 0.7, 0.27, 0.47, 0.39, n_top=2.3, step=0.05),
        st("Head", 0.45, 0.33, 0.52, 0.47, lift=0.02, step=0.05),
        st("Head", 0.2, 0.43, 0.5, 0.6, step=0.06),
        st("Head", 0.02, 0.37, 0.42, 0.52, step=0.07),
        st("Neck", 0.7, 0.42, 0.46, 0.6, step=0.1),
        st("Neck", 0.2, 0.5, 0.5, 0.7, step=0.12),
        st("Shoulders", 0.5, 0.7, 0.56, 0.95, step=0.14),
        st("Torso", 0.8, 0.86, 0.6, 1.15, n_bot=2.3, step=0.14),
        st("Torso", 0.4, 0.92, 0.62, 1.1, n_bot=2.3, step=0.16),
        st("Torso", 0.05, 0.88, 0.64, 0.9, step=0.16),
        st("Hips", 0.5, 0.86, 0.66, 0.78, step=0.16),
        st("Back", 0.5, 0.78, 0.62, 0.7, step=0.16),
        st("Tail1", 0.5, 0.6, 0.56, 0.6, step=0.18),
        st("Tail2", 0.5, 0.42, 0.42, 0.44, step=0.2),
        st("Tail3", 0.5, 0.28, 0.3, 0.3, step=0.22),
        st("Tail4", 0.5, 0.17, 0.18, 0.18, step=0.22),
        st("Tail5", 0.5, 0.1, 0.1, 0.1, step=0.2),
        st("Tail5_end", 0.3, 0.03, 0.03, 0.03, step=0.1),
    ],
    "mouth": {"from": ("Head", 0.15), "to": ("Head", 1.04), "phi": 110.0, "depth": 0.045, "width": 0.14},
    "teeth": {"from": ("Head", 0.25), "to": ("Head", 1.0), "count": 11, "length": 0.15, "radius": 0.038,
              "colour": (0.78, 0.72, 0.56)},
    "eyes": {"at": ("Head", 0.43), "phi": 52.0, "radius": 0.11, "sunk": 0.5, "forward": 16.0, "up": 4.0,
             "iris": (0.72, 0.46, 0.07), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
    "brow": {"at": ("Head", 0.46), "phi": 30.0, "size": 0.14, "height": 0.08},
    "fossa": {"from": ("Head", 0.55), "to": ("Head", 0.78), "phi": 72.0, "depth": 0.05, "width": 0.3},
    "nostrils": {"at": ("Head", 1.0), "phi": 48.0, "size": 0.04},
    "plates": {"from": ("Neck", 0.2), "to": ("Tail4", 0.2), "rows": [9.0], "spacing": 0.44, "ref": 0.9,
               "length": 0.42, "width": 0.34, "height": 0.1, "colour": (0.03, 0.022, 0.015)},
    "legs": both({"links": [("BackLeg.L", False), ("BackUpLeg.L", False), ("BackLowLeg.L", False)],
                  "stations": [("BackLeg.L", 0.2, 0.44, 0.64), ("BackUpLeg.L", 0.0, 0.5, 0.68),
                               ("BackUpLeg.L", 0.3, 0.46, 0.6), ("BackUpLeg.L", 0.65, 0.32, 0.4),
                               ("BackUpLeg.L", 0.93, 0.24, 0.28), ("BackLowLeg.L", 0.15, 0.22, 0.26),
                               ("BackLowLeg.L", 0.6, 0.17, 0.2), ("BackLowLeg.L", 0.95, 0.16, 0.18)],
                  "foot": "BackFoot.L"})
    + both({"links": [("FrontLeg.L", False), ("FrontUpLeg.L", False), ("FrontLowLeg.L", False), ("FrontFoot.L", False)],
            "stations": [("FrontLeg.L", 0.4, 0.26, 0.3), ("FrontUpLeg.L", 0.0, 0.27, 0.31),
                         ("FrontUpLeg.L", 0.6, 0.2, 0.22), ("FrontLowLeg.L", 0.1, 0.18, 0.19),
                         ("FrontLowLeg.L", 0.9, 0.13, 0.14), ("FrontFoot.L", 0.2, 0.13, 0.12),
                         ("FrontFoot.L", 0.45, 0.12, 0.1)],
            "hand": "FrontFoot.L"}),
    "toes": [(0.0, 0.62, 0.09, 0.16), (-18.0, 0.55, 0.085, 0.15), (18.0, 0.52, 0.08, 0.14), (34.0, 0.36, 0.065, 0.1)],
    "hallux": (150.0, 0.2, 0.05, 0.1),
    "fingers": [(-10.0, 0.3, 0.05, 0.12), (10.0, 0.3, 0.05, 0.12), (-28.0, 0.24, 0.045, 0.1), (28.0, 0.22, 0.042, 0.09)],
    "hand_at": 0.5,
    "skin": {
        "back": (0.05, 0.032, 0.02),
        "flank": (0.15, 0.09, 0.05),
        "belly": (0.34, 0.26, 0.17),
        "mottle": 0.15,
        "bands": {"colour": (0.018, 0.012, 0.008), "from": ("Shoulders", 0.3), "to": ("Tail5_end", 0.5),
                  "period": 1.4, "width": 0.28, "strength": 0.6},
        "throat": (0.38, 0.28, 0.18),
        "lips": (0.03, 0.02, 0.012),
        "claws": (0.035, 0.03, 0.025),
    },
}


# ==============================================================================
# Placerias: the dicynodont that grazes in herds on the valley's sides -- a barrel of a body on short thick
# legs, a short tail, a big head with a horny beak and two short tusks
# ==============================================================================

PLACERIAS = {
    "around": 32,
    "soften": 0.2,
    "rough": 0.02,
    "trunk": [
        st("Head", 2.42, 0.08, 0.08, 0.1, step=0.04),
        st("Head", 2.34, 0.26, 0.18, 0.3, step=0.05),
        st("Head", 2.1, 0.42, 0.3, 0.44, step=0.06),
        st("Head", 1.7, 0.56, 0.4, 0.5, step=0.07),
        st("Head", 1.2, 0.64, 0.46, 0.5, step=0.08),
        st("Head", 0.6, 0.7, 0.47, 0.52, n_top=2.5, step=0.08),
        st("Head", 0.0, 0.62, 0.44, 0.56, step=0.08),
        st("Neck", 0.5, 0.74, 0.5, 0.68, step=0.1),
        st("Shoulders", 0.8, 1.06, 0.62, 0.9, step=0.12),
        st("Shoulders", 0.3, 1.3, 0.72, 1.06, n_bot=2.3, step=0.12),
        st("Torso", 0.5, 1.38, 0.76, 1.1, n_bot=2.3, step=0.12),
        st("Hips", 0.6, 1.3, 0.74, 0.96, step=0.12),
        st("Hips", 0.1, 1.15, 0.7, 0.8, step=0.12),
        st("Back", 0.6, 0.9, 0.56, 0.6, step=0.12),
        st("Tail1", 0.5, 0.55, 0.38, 0.4, step=0.12),
        st("Tail2", 0.6, 0.35, 0.25, 0.26, step=0.12),
        st("Tail3", 0.8, 0.2, 0.15, 0.15, step=0.12),
        st("Tail4", 0.6, 0.1, 0.08, 0.08, step=0.1),
        st("Tail4", 0.95, 0.03, 0.03, 0.03, step=0.06),
    ],
    "mouth": {"from": ("Head", 0.5), "to": ("Head", 2.38), "phi": 112.0, "depth": 0.04, "width": 0.16},
    "tusks": {"at": ("Head", 1.95), "phi": 100.0, "length": 0.36, "radius": 0.075, "colour": (0.7, 0.64, 0.5)},
    "eyes": {"at": ("Head", 1.25), "phi": 48.0, "radius": 0.1, "sunk": 0.5, "forward": 18.0, "up": 6.0,
             "iris": (0.3, 0.2, 0.08), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
    "brow": {"at": ("Head", 1.3), "phi": 30.0, "size": 0.14, "height": 0.05},
    "nostrils": {"at": ("Head", 2.12), "phi": 40.0, "size": 0.04},
    "legs": both({"links": [("BackLeg.L", False), ("BackUpLeg.L", False), ("BackLowLeg.L", False)],
                  "stations": [("BackLeg.L", 0.3, 0.5, 0.7), ("BackUpLeg.L", 0.0, 0.52, 0.7),
                               ("BackUpLeg.L", 0.4, 0.42, 0.52), ("BackUpLeg.L", 0.9, 0.3, 0.34),
                               ("BackLowLeg.L", 0.2, 0.28, 0.3), ("BackLowLeg.L", 0.7, 0.25, 0.26),
                               ("BackLowLeg.L", 0.97, 0.25, 0.27)],
                  "foot": "BackFoot.L"})
    + both({"links": [("FrontLeg.L", False), ("FrontUpLeg.L", False), ("FrontLowLeg.L", False)],
            "stations": [("FrontLeg.L", 0.3, 0.44, 0.58), ("FrontUpLeg.L", 0.0, 0.45, 0.56),
                         ("FrontUpLeg.L", 0.5, 0.35, 0.4), ("FrontUpLeg.L", 0.95, 0.27, 0.3),
                         ("FrontLowLeg.L", 0.2, 0.25, 0.27), ("FrontLowLeg.L", 0.7, 0.23, 0.24),
                         ("FrontLowLeg.L", 0.97, 0.23, 0.25)],
            "foot": "FrontFoot.L"}),
    "toes": [(-40.0, 0.2, 0.07, 0.05), (-20.0, 0.24, 0.075, 0.05), (0.0, 0.26, 0.078, 0.05),
             (20.0, 0.24, 0.075, 0.05), (40.0, 0.2, 0.07, 0.05)],
    "hallux": None,
    "skin": {
        "back": (0.085, 0.07, 0.055),
        "flank": (0.19, 0.16, 0.12),
        "belly": (0.34, 0.29, 0.23),
        "mottle": 0.2,
        "spots": {"colour": (0.05, 0.04, 0.03), "scale": 1.4, "above": 0.45, "strength": 0.35,
                  "from": ("Neck", 0.5), "to": ("Tail3", 0.5)},
        "beak": {"colour": (0.05, 0.045, 0.04), "from": ("Head", 2.2)},
        "throat": (0.36, 0.31, 0.25),
        "lips": (0.06, 0.05, 0.04),
        "claws": (0.05, 0.045, 0.04),
    },
}

PLANS = {"coelophysis": COELOPHYSIS, "hesperosuchus": HESPEROSUCHUS, "phytosaur": PHYTOSAUR,
         "postosuchus": POSTOSUCHUS, "placerias": PLACERIAS}


# ==============================================================================
# Building one
# ==============================================================================

def _deg(x):
    return math.radians(x)


def build(name, arm, materials):
    plan = PLANS[name]
    skel = sc.Skeleton(arm)
    path = sc.Path(skel, TRUNK, rename={"Head_end": "Head"}, rigid={"Head"})
    loft = sc.Loft(skel, path, plan["trunk"], around=plan["around"], soften=plan["soften"])
    body = sc.Body()
    skin = plan["skin"]

    def s_at(where):
        return path.s_of(where[0], where[1])

    # The lip groove, and the brow over the eye.
    # (The path runs from the snout to the tail: a stretch named head-end first is taken either way round.)
    for key in ("mouth", "fossa"):
        m = plan.get(key)
        if m:
            a, b = sorted((s_at(m["from"]), s_at(m["to"])))
            loft.dents.append((a, b, _deg(m["phi"]), m["depth"], m["width"]))
    b = plan.get("brow")
    if b:
        loft.bumps.append((s_at(b["at"]), _deg(b["phi"]), b["size"], b["height"]))
    mound = plan.get("mound")
    if mound:
        # On the midline: the bump is laid on both sides of it, so each is half.
        loft.bumps.append((s_at(mound["at"]), 0.0, mound["size"], mound["height"] * 0.5))

    paint = _painter(plan, path, loft, skin)
    loft.build(body, paint, rough=plan.get("rough", 0.0))

    for limb in plan["legs"]:
        _limb(body, skel, limb, skin, plan)
    _eyes(body, loft, path, plan)
    _teeth(body, loft, path, plan)
    _plates(body, loft, path, plan)
    _tusks(body, loft, path, plan)
    return body.make(name + "_body", arm, materials)


def _painter(plan, path, loft, skin):
    bands = skin.get("bands")
    stripe = skin.get("eye_stripe")
    spots = skin.get("spots")
    beak = skin.get("beak")
    s_nose = path.s_of(*plan["nostrils"]["at"]) if plan.get("nostrils") else None
    s_head0 = path.s_of("Head", 0.0)
    s_eye = path.s_of(*plan["eyes"]["at"])
    m = plan.get("mouth")
    lip = tuple(sorted((path.s_of(*m["from"]), path.s_of(*m["to"])))) + (_deg(m["phi"]),) if m else None
    b_from = path.s_of(*bands["from"]) if bands else 0.0
    b_to = path.s_of(*bands["to"]) if bands else 0.0
    st_range = sorted((path.s_of(*stripe["from"]), path.s_of(*stripe["to"]))) if stripe else (0.0, 0.0)
    sp_range = sorted((path.s_of(*spots["from"]), path.s_of(*spots["to"]))) if spots else (0.0, 0.0)
    s_beak = path.s_of(*beak["from"]) if beak else None

    def paint(s, phi, p, n):
        v = math.cos(phi)
        side = phi if phi <= math.pi else 2.0 * math.pi - phi     # 0 on top to pi underneath, either side
        if v > 0.2:
            c = sc.mix(skin["flank"], skin["back"], sc.smoothstep(0.2, 0.92, v))
        else:
            c = sc.mix(skin["belly"], skin["flank"], sc.smoothstep(-0.55, 0.2, v))
        # A pale throat under the head and neck.
        if s < s_head0 + 1.4 and v < -0.2:
            c = sc.mix(c, skin["throat"], 0.7 * sc.smoothstep(-0.2, -0.6, v) * (1.0 - sc.smoothstep(s_head0 + 0.6, s_head0 + 1.4, s)))
        if bands and b_from <= s <= b_to:
            k = math.sin(2.0 * math.pi * (s - b_from) / bands["period"])
            band = sc.smoothstep(1.0 - bands["width"] * 2.0, 1.0 - bands["width"] * 0.6, k)
            reach = sc.smoothstep(-0.35, 0.35, v)
            # On the tail the saddles close into rings.
            tail = sc.smoothstep(b_from + (b_to - b_from) * 0.45, b_from + (b_to - b_from) * 0.6, s)
            reach = max(reach, tail * 0.8)
            fade = sc.smoothstep(b_from, b_from + bands["period"], s)
            c = sc.mix(c, bands["colour"], bands["strength"] * band * reach * fade)
        if spots and sp_range[0] <= s <= sp_range[1]:
            k = noise.noise(p * spots["scale"]) + 0.5 * noise.noise(p * spots["scale"] * 2.3)
            spot = sc.smoothstep(spots["above"], spots["above"] + 0.12, k) * sc.smoothstep(-0.5, 0.2, v)
            c = sc.mix(c, spots["colour"], spots["strength"] * spot)
        if stripe and st_range[0] <= s <= st_range[1]:
            lo, hi = st_range
            d = (side - _deg(stripe["phi"])) / _deg(stripe["width"])
            k = math.exp(-d * d) * sc.smoothstep(lo, lo + 0.15, s) * (1.0 - sc.smoothstep(hi - 0.3, hi, s))
            c = sc.mix(c, stripe["colour"], 0.75 * k)
        if lip and lip[0] <= s <= lip[1]:
            d = (side - lip[2]) / 0.13
            k = math.sin(math.pi * (s - lip[0]) / (lip[1] - lip[0])) ** 0.3
            c = sc.mix(c, skin["lips"], 0.9 * k * math.exp(-d * d))
        if s_beak is not None and s < s_beak + 0.1:
            c = sc.mix(c, beak["colour"], 0.85 * (1.0 - sc.smoothstep(s_beak - 0.05, s_beak + 0.1, s)))
        if s_nose is not None and abs(s - s_nose) < 0.1:
            size = plan["nostrils"]["size"]
            d = (side - _deg(plan["nostrils"]["phi"])) / 0.22
            k = math.exp(-((s - s_nose) / (size * 1.2)) ** 2 - d * d)
            c = sc.mix(c, (0.02, 0.015, 0.01), 0.9 * k)
        # Round the eye, darker skin.
        if abs(s - s_eye) < 0.3:
            d = (side - _deg(plan["eyes"]["phi"])) / 0.45
            c = sc.shade(c, -0.25 * math.exp(-((s - s_eye) / 0.12) ** 2 - d * d))
        mot = noise.noise(p * 1.7) * 0.6 + noise.noise(p * 5.3) * 0.4
        return sc.shade(c, skin["mottle"] * mot)
    return paint


def _limb(body, skel, limb, skin, plan):
    lb = sc.Limb(skel, limb["links"], limb["stations"], around=14, step=0.09)
    top_s = lb.stations[0]["s"]
    end = lb.stations[-1]["s"]

    def paint(s, a, p, n):
        # Coloured as the body is where it meets it -- the flank, darkening to the back over the top of the
        # thigh -- the outside of the leg the flank's, the inside paler, the shank darker.
        out = n.dot(skel.side) * (1.0 if p.dot(skel.side) > 0 else -1.0)
        down = (s - top_s) / max(0.01, end - top_s)
        c = sc.mix(sc.shade(skin["belly"], -0.08), skin["flank"], sc.smoothstep(-0.7, 0.3, out + 0.5 * n.dot(sc.UP)))
        c = sc.mix(c, sc.mix(skin["flank"], skin["back"], 0.45), 0.6 * (1.0 - sc.smoothstep(0.0, 0.35, down)) * sc.smoothstep(-0.2, 0.6, n.dot(sc.UP) + out * 0.5))
        c = sc.shade(c, -0.2 * sc.smoothstep(0.35, 1.0, down))
        mot = noise.noise(p * 3.1) * 0.5
        return sc.shade(c, skin["mottle"] * mot)

    foot = limb.get("foot") or limb.get("hand")

    def to_foot(s, w):
        # The last bit above the ankle moves with the foot a little: the joint does not tear.
        k = 0.4 * sc.smoothstep(end - 0.14, end, s)
        if k <= 0.0:
            return w
        out = {b: x * (1.0 - k) for b, x in w.items()}
        out[foot] = out.get(foot, 0.0) + k
        return out

    lb.build(body, paint, extra=to_foot if limb.get("foot") else None)
    if limb.get("foot"):
        _foot(body, skel, limb["foot"], skin, limb.get("toes", plan.get("toes")), plan.get("hallux"))
    if limb.get("hand"):
        _hand(body, skel, limb["hand"], skin, limb.get("fingers", plan.get("fingers")), plan.get("hand_at", 0.3))


def _foot(body, skel, bone, skin, toes, hallux):
    ankle = skel.head[bone]
    fwd = (skel.tail[bone] - skel.head[bone])
    fwd.z = 0.0
    fwd.normalize()
    outward = sc.UP.cross(fwd).normalized()
    if outward.dot(ankle - skel.head.get("Body", ankle)) < 0.0:
        outward = -outward
    w = {bone: 1.0}
    toe_col = sc.shade(skin["flank"], -0.1)
    for (deg, length, radius, claw_len) in toes:
        ang = _deg(deg)
        d = (fwd * math.cos(ang) + outward * math.sin(ang)).normalized()
        base = ankle + d * 0.04 + sc.UP * 0.02
        pts = []
        radii = []
        for k in range(5):
            f = k / 4.0
            p = base + d * (length * f)
            p.z = max(p.z, 0.0) + radius * (1.1 - 0.4 * f) + 0.02 * math.sin(math.pi * f)
            pts.append(p)
            radii.append(radius * (1.0 - 0.45 * f))
        sc.tube(body, pts, radii, [toe_col] * 5, w, around=8, close_tip=False, flat=0.85)
        sc.claw(body, pts[-1] + d * radii[-1] * 0.3, d, claw_len, radii[-1] * 1.05, skin["claws"], w, curl=0.9)
    if hallux:
        deg, length, radius, claw_len = hallux
        ang = _deg(deg)
        d = (fwd * math.cos(ang) + outward * math.sin(ang) * -0.6).normalized()
        base = ankle + sc.UP * 0.12
        pts = [base, base + d * length * 0.5 + sc.UP * -0.02, base + d * length]
        sc.tube(body, pts, [radius, radius * 0.8, radius * 0.6], [toe_col] * 3, w, around=6, close_tip=False)
        sc.claw(body, pts[-1], d, claw_len, radius * 0.6, skin["claws"], w, curl=0.8)


def _hand(body, skel, bone, skin, fingers, at):
    wrist = skel.at(bone, at)
    down = (skel.tail[bone] - skel.head[bone]).normalized()
    across = skel.forward.cross(down)
    if across.length < 1e-4:
        across = skel.side.copy()
    across.normalize()
    w = {bone: 1.0}
    col = sc.shade(skin["flank"], -0.05)
    for (deg, length, radius, claw_len) in fingers:
        ang = _deg(deg)
        d = (down * math.cos(ang) + across * math.sin(ang) + skel.forward * 0.25).normalized()
        pts = [wrist + d * (length * f) for f in (0.0, 0.35, 0.7, 1.0)]
        sc.tube(body, pts, [radius, radius * 0.9, radius * 0.75, radius * 0.6], [col] * 4, w, around=6, close_tip=False)
        sc.claw(body, pts[-1], d, claw_len, radius * 0.7, skin["claws"], w, curl=1.1)


def _eyes(body, loft, path, plan):
    e = plan["eyes"]
    s = path.s_of(*e["at"])
    for phi in (_deg(e["phi"]), 2.0 * math.pi - _deg(e["phi"])):
        p, n = loft.surface(s, phi)
        c, t, x, u = loft.frame(s)
        # Looking out, a little forward (against the path, which runs to the tail) and up.
        look = (n * math.cos(_deg(e["forward"])) - t * math.sin(_deg(e["forward"]))).normalized()
        look = (look + u * math.sin(_deg(e["up"]))).normalized()
        centre = p - n * (e["radius"] * e["sunk"])
        sc.eye(body, centre, look, e["radius"], e["iris"], e["pupil"], {"Head": 1.0}, slit=e["slit"], mat=1)
        # The lids: a ring of skin round it, heavier over the top.
        sc.lids(body, centre, look, e["radius"], sc.shade(plan["skin"]["flank"], -0.3), {"Head": 1.0},
                upper=0.24, lower=0.14, rise=0.5)


def _teeth(body, loft, path, plan):
    """The upper teeth along the lip, pointing down and a little back; the lower (where a jaw shows them)
    pointing up just under them. Bigger in the middle of the row -- or, with a rosette, at the snout's tip."""
    m = plan.get("mouth")
    for key, sign, lift in (("teeth", 1.0, 4.0), ("lower_teeth", -1.0, 12.0)):
        tt = plan.get(key)
        if not tt or not m:
            continue
        colour = tt.get("colour", plan.get("teeth", {}).get("colour", (0.74, 0.7, 0.6)))
        s0, s1 = path.s_of(*tt["from"]), path.s_of(*tt["to"])
        s_rose = path.s_of("Head", plan["teeth"]["rosette"]) if plan.get("teeth", {}).get("rosette") else None
        for side in (1, -1):
            phi = _deg(m["phi"]) + _deg(lift)
            phi = phi if side > 0 else 2.0 * math.pi - phi
            for i in range(tt["count"]):
                f = (i + 0.5) / tt["count"]
                s = s0 + (s1 - s0) * f
                p, n = loft.surface(s, phi, out=-0.02)
                c, t, x, u = loft.frame(s)
                size = 0.7 + 0.5 * math.sin(math.pi * min(1.0, f * 1.25))
                if s_rose is not None:
                    size = 0.75 + 0.6 * math.exp(-((s - s_rose) / 0.3) ** 2) + 0.15 * math.sin(i * 1.7)
                point = (-u * 0.92 * sign + t * 0.3 * sign + n * 0.12).normalized()
                pts = [p - point * tt["radius"], p + point * tt["length"] * size * 0.45, p + point * tt["length"] * size]
                sc.tube(body, pts, [tt["radius"] * size * 1.1, tt["radius"] * size * 0.75, tt["radius"] * size * 0.25],
                        [colour] * 3, {"Head": 1.0}, around=5, close_tip=True, flat=0.6, up=t)


def _plates(body, loft, path, plan):
    """Rows of bony plates down the back, each on the skin where it grows, shrinking along the tail."""
    pl = plan.get("plates")
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
                sc.plate(body, p, t, n, pl["length"] * k, pl["width"] * k, pl["height"] * k, pl["colour"], w)
        s += pl["spacing"] * max(0.55, k)


def _tusks(body, loft, path, plan):
    tk = plan.get("tusks")
    if not tk:
        return
    s = path.s_of(*tk["at"])
    for phi in (_deg(tk["phi"]), 2.0 * math.pi - _deg(tk["phi"])):
        p, n = loft.surface(s, phi, out=-0.05)
        c, t, x, u = loft.frame(s)
        # Down, a little forward (against the path) and out.
        d = (-u * 0.85 - t * 0.35 + n * 0.25).normalized()
        pts = [p, p + d * tk["length"] * 0.5, p + d * tk["length"]]
        sc.tube(body, pts, [tk["radius"], tk["radius"] * 0.75, tk["radius"] * 0.35], [tk["colour"]] * 3,
                {"Head": 1.0}, around=7, close_tip=True)
