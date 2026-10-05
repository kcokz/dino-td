# tools/dino_species.py
# EACH SPECIES AS IT WAS: its skeleton (tools/dino_rig.py), how it moves (tools/dino_moves.py), and its body --
# its sections from snout to tail, its limbs and their muscles, its toes and claws, eyes and teeth, and the
# colours and marks of its skin (tools/dino_body.py). Metres at the size the game shows it
# (Config.DINOS.<id>.size: the height, head and all).
#
# Used by tools/generate_dinos.py.


def st(bone, t, w, top, bot, **kw):
    """A trunk station: on `bone` at `t` along it, `w` half as wide, `top` over the spine's line and `bot` under
    it (and any of lift, n_top, n_bot, keel, step)."""
    d = {"w": w, "top": top, "bot": bot}
    d.update(kw)
    return (bone, t, d)


# ==============================================================================
# Coelophysis bauri: slight, long-necked, long-tailed, big-eyed -- the pack hunter of the Chinle (Ghost Ranch,
# found by the hundred together). About three metres long, a quarter of a metre of skull, 15-20 kg.
# ==============================================================================

COELOPHYSIS = {
    "height": 0.95,
    # After Colbert (1989) and Scott Hartman's skeletal: skull 0.24 m, the neck an S of four, a short deep trunk,
    # the tail half the animal; femur 0.2, tibia 0.23 (a runner's: longer than the femur), the long foot bone
    # 0.13, the middle toe 0.1; small grasping arms.
    "skeleton": {
        "hip_height": 0.5,
        "pelvis_length": 0.1,
        "pelvis_pitch": -6.0,
        "spine": [(0.16, 4.0), (0.16, 6.0), (0.14, 2.0)],
        "neck": [(0.105, 52.0), (0.105, 46.0), (0.1, 28.0), (0.09, 8.0)],
        "skull": (0.24, -14.0),
        "jaw": (0.22, 0.03, -17.0),
        "jaw_hinge": 0.08,
        "tail": [(0.16, 8.0), (0.16, 3.0), (0.15, 0.0), (0.15, -2.0), (0.14, -2.0), (0.13, -2.0),
                 (0.12, -1.0), (0.11, 0.0), (0.1, 0.0), (0.09, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.2, 0.23, 0.13, 0.08],
                     "socket": (0.06, 0.0, -0.01), "stance": (0.005, 0.07), "foot": "digitigrade",
                     "foot_tilt": 22.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.11, 0.085, 0.04, 0.045], "socket": (0.045, -0.02, -0.07), "arm": True,
                     "rest_hand": (0.012, 0.1, -0.09), "bend": "back", "splay": 12.0},
        },
    },
    "moves": {
        "plan": "biped",
        # A quick, light walk -- the game's walk (1.6 m/s) is a brisk one for an animal with hips half a metre up.
        "walk": {"period": 0.5, "duty": 0.6, "step": 0.06, "bob": 0.01, "sway": 0.008, "hip_yaw": 3.0,
                 "hip_roll": 2.0, "tail_swing": 3.0, "neck_bob": 1.5, "steady": 0.7, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.01},
        # A run: level, the neck down and forward, the tail up behind, a bound between the steps.
        "run": {"period": 0.4, "duty": 0.35, "step": 0.1, "bob": 0.016, "lean": -6.0, "crouch": 0.02,
                "neck_pitch": -14.0, "tail_lift": 6.0, "head_pitch": 5.0, "tail_swing": 2.0, "steady": 0.8,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 4.0, "breaths": 2, "look": 25.0, "nod": 3.0, "swell": 0.025, "tail_swing": 3.0},
        "attack": {"period": 0.8, "jaw": 42.0, "lunge": 0.1, "draw": 18.0, "reach": 26.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.3, "roll": 86.0, "pivot": 0.07, "slide": 0.05},
        "sleep": {"period": 3.2, "drop": 0.33, "neck": [(-30.0, 8.0), (-25.0, 10.0), (-15.0, 10.0), (-5.0, 5.0)],
                  "head": (8.0, 10.0, 0.0), "tail": [(-14.0, 6.0), (4.0, 9.0)] + [(1.5, 9.0)] * 8, "tilt": 82.0},
    },
    "body": {
        "around": 40,
        "soften": 0.03,
        "rough": 0.01,
        "scale": 0.15,
        # Under the lip line the head goes with the jaw; into the throat behind the hinge for this much of the
        # skull's length.
        "throat": 0.3,
        "trunk": [
            # The skull: long, low, narrow; the notch behind the nostril; big orbits; the jaw muscles swelling it
            # behind them.
            st("Head", 1.012, 0.006, 0.006, 0.006, step=0.003),
            st("Head", 1.0, 0.0095, 0.0105, 0.0095, step=0.004),
            st("Head", 0.97, 0.0122, 0.0135, 0.012, step=0.006),
            st("Head", 0.92, 0.0132, 0.0148, 0.0135, step=0.008),
            st("Head", 0.84, 0.012, 0.014, 0.013, step=0.01),
            st("Head", 0.76, 0.014, 0.016, 0.015, step=0.01),
            st("Head", 0.64, 0.017, 0.021, 0.019, step=0.01),
            st("Head", 0.5, 0.021, 0.027, 0.024, step=0.01),
            st("Head", 0.36, 0.026, 0.033, 0.028, lift=0.003, step=0.01),
            st("Head", 0.22, 0.032, 0.035, 0.035, step=0.01),
            st("Head", 0.08, 0.03, 0.031, 0.037, step=0.012),
            st("Head", -0.06, 0.025, 0.025, 0.034, step=0.014),
            # The neck: slender, thickening to the chest; the throat under it.
            st("Neck4", 0.5, 0.02, 0.021, 0.028, step=0.016),
            st("Neck3", 0.5, 0.022, 0.022, 0.03, step=0.018),
            st("Neck2", 0.5, 0.024, 0.024, 0.033, step=0.02),
            st("Neck1", 0.5, 0.031, 0.03, 0.045, step=0.02),
            # The body: a deep chest over the arms, a slimmer waist, the hips.
            st("Spine3", 0.7, 0.047, 0.038, 0.068, step=0.022),
            st("Spine3", 0.15, 0.062, 0.047, 0.11, n_bot=2.3, step=0.025),
            st("Spine2", 0.5, 0.074, 0.057, 0.13, n_bot=2.4, step=0.025),
            st("Spine1", 0.6, 0.072, 0.062, 0.116, n_bot=2.2, step=0.025),
            st("Spine1", 0.15, 0.068, 0.068, 0.096, step=0.025),
            st("Hips", 0.3, 0.074, 0.072, 0.086, keel=0.004, step=0.025),
            st("Hips", 0.9, 0.064, 0.066, 0.076, keel=0.004, step=0.025),
            # The tail: deep at the root with the muscle that pulls the legs back, then long and thin.
            st("Tail1", 0.5, 0.049, 0.056, 0.064, step=0.03),
            st("Tail2", 0.5, 0.037, 0.043, 0.048, step=0.03),
            st("Tail3", 0.5, 0.027, 0.032, 0.035, step=0.035),
            st("Tail4", 0.5, 0.021, 0.025, 0.026, step=0.035),
            st("Tail5", 0.5, 0.016, 0.019, 0.019, step=0.035),
            st("Tail6", 0.5, 0.012, 0.014, 0.014, step=0.035),
            st("Tail7", 0.5, 0.0095, 0.0105, 0.0105, step=0.035),
            st("Tail8", 0.5, 0.0072, 0.0078, 0.0078, step=0.035),
            st("Tail9", 0.5, 0.0052, 0.0055, 0.0055, step=0.03),
            st("Tail10", 0.6, 0.0034, 0.0036, 0.0036, step=0.03),
            st("Tail_end", 0.3, 0.0015, 0.0015, 0.0015, step=0.01),
        ],
        # The lip line, where the upper jaw closes over the lower; the mouth's inside dark at it.
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 108.0, "depth": 0.003, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 18, "length": 0.007, "radius": 0.0018,
                  "colour": (0.78, 0.74, 0.64)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 16, "length": 0.005, "radius": 0.0015},
        "eyes": {"at": ("Head", 0.36), "phi": 56.0, "radius": 0.0108, "sunk": 0.62, "forward": 16.0, "up": 6.0,
                 "iris": (0.62, 0.42, 0.05), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.38), "phi": 34.0, "size": 0.016, "height": 0.005},
        # The hollow in front of the eye (the antorbital fenestra, under the skin).
        "fossa": {"from": ("Head", 0.44), "to": ("Head", 0.68), "phi": 70.0, "depth": 0.004, "width": 0.3},
        "nostrils": {"at": ("Head", 0.95), "phi": 50.0, "size": 0.0035},
        "limbs": {
            # Stations: (0 thigh / 1 shin / 2 foot bone, t along it, half-width across, half-depth fore and aft,
            # its middle moved forward of the bone).
            "hind": {
                "stations": [(0, -0.35, 0.016, 0.036, 0.004), (0, -0.08, 0.028, 0.056, 0.008), (0, 0.2, 0.033, 0.056, 0.009),
                             (0, 0.5, 0.029, 0.044, 0.006), (0, 0.8, 0.022, 0.029, 0.002), (0, 0.97, 0.019, 0.023, 0.0),
                             (1, 0.1, 0.019, 0.027, -0.005), (1, 0.3, 0.018, 0.027, -0.008), (1, 0.6, 0.013, 0.016, -0.004),
                             (1, 0.95, 0.0095, 0.0105, 0.0), (2, 0.1, 0.0085, 0.0085, 0.0), (2, 0.95, 0.0075, 0.007, 0.0)],
                "around": 16,
                "digits": {
                    # Three toes forward -- the middle one longest -- and the small first one raised behind.
                    "digits": [(0.0, 0.1, 0.0058, 0.018), (-18.0, 0.075, 0.0054, 0.016), (18.0, 0.07, 0.0052, 0.015)],
                    "hallux": (150.0, 0.028, 0.0035, 0.01, 0.03),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.013, 0.02, 0.0), (0, 0.1, 0.016, 0.02, 0.002), (0, 0.45, 0.013, 0.016, 0.003),
                             (0, 0.95, 0.009, 0.01, 0.0), (1, 0.3, 0.0095, 0.011, 0.001), (1, 0.95, 0.0065, 0.007, 0.0),
                             (2, 0.6, 0.006, 0.0045, 0.0)],
                "around": 12,
                "digits": {
                    "digits": [(0.0, 0.045, 0.0032, 0.013), (-16.0, 0.04, 0.003, 0.012), (16.0, 0.032, 0.0028, 0.01)],
                    "claw_curl": 1.2,
                    "flat": 0.9,
                },
            },
        },
        # Its skin close to (tools/dino_skin.py): pebbly scales about 6 mm across, twice that over the back.
        "skin_detail": {"scales": {"cells": 170.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.0012}},
        "texture": 2048,
        "skin": {
            "back": (0.15, 0.075, 0.025),
            "flank": (0.46, 0.26, 0.09),
            "belly": (0.56, 0.44, 0.27),
            "throat": (0.6, 0.5, 0.34),
            "lips": (0.3, 0.2, 0.12),
            "mouth": (0.28, 0.06, 0.05),
            "claws": (0.14, 0.12, 0.1),
            "mottle": 0.18,
            # Dark saddles over the back that close into rings round the tail.
            "bands": {"colour": (0.04, 0.025, 0.012), "from": ("Spine3", 0.3), "to": ("Tail_end", 0.5),
                      "period": 0.14, "width": 0.34, "strength": 0.78},
            # A dark stripe from the nostril through the eye.
            "eye_stripe": {"colour": (0.05, 0.03, 0.015), "from": ("Head", 1.0), "to": ("Neck4", 0.5),
                           "phi": 62.0, "width": 16.0},
        },
    },
}

# The pack's alpha: the same animal, painted apart -- darker, rust-flanked, its head flushed red -- picked out at a
# glance (GAME-DESIGN 7.5). The game shows it bigger (Config.DINOS.coelophysis_alpha.size).
COELOPHYSIS_ALPHA = {
    "same_as": "coelophysis",
    "body": {
        "skin": {
            "back": (0.07, 0.035, 0.018),
            "flank": (0.44, 0.15, 0.05),
            "belly": (0.5, 0.36, 0.22),
            "throat": (0.55, 0.3, 0.18),
            "bands": {"colour": (0.03, 0.015, 0.008), "strength": 0.85},
            "flush": {"colour": (0.62, 0.1, 0.05), "from": ("Head", 1.0), "to": ("Neck2", 0.5), "strength": 0.7},
        },
    },
}


# ==============================================================================
# Postosuchus kirkpatricki: not a dinosaur -- a rauisuchian, of the crocodile's line: a four-metre land hunter of the
# Late Triassic, the apex predator of the Chinle and the Dockum (the first map's boss). A deep narrow skull with big
# serrated teeth, a short neck, a deep body, pillar-erect legs under it -- the hind ones longer, the back sloping
# down to the shoulders -- two rows of bony plates down its back, a long heavy tail.


POSTOSUCHUS = {
    "height": 2.0,
    "skeleton": {
        "hip_height": 1.16,
        "pelvis_length": 0.24,
        "pelvis_pitch": -8.0,
        # Hips forward and down to the shoulders; the neck curving up from them, the head carried over them.
        "spine": [(0.25, -6.0), (0.25, -8.0), (0.24, -8.0), (0.22, -6.0)],
        "neck": [(0.16, 46.0), (0.15, 32.0), (0.14, 14.0)],
        "skull": (0.56, -14.0),
        "jaw": (0.53, 0.07, -10.0),
        "jaw_hinge": 0.06,
        "tail": [(0.17, -12.0), (0.16, -7.0), (0.15, -5.0), (0.142, -4.0), (0.133, -3.0), (0.124, -2.0),
                 (0.115, -2.0), (0.105, -1.0), (0.096, -1.0), (0.087, 0.0), (0.078, 0.0), (0.07, 0.0), (0.06, 0.0),
                 (0.05, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.56, 0.48, 0.24, 0.15],
                     "socket": (0.15, 0.0, -0.05), "stance": (0.02, 0.04), "foot": "plantigrade", "heel": 28.0,
                     "roll_tilt": 40.0, "bend": "forward", "splay": 6.0},
            # The forelimbs shorter than the hind (about two thirds, Weinbaum 2013), their shoulders low on the
            # deep chest.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.38, 0.33, 0.11, 0.08], "socket": (0.13, -0.05, -0.2), "stance": (0.03, 0.04),
                     "foot": "plantigrade", "heel": 34.0, "roll_tilt": 35.0, "bend": "back", "splay": 8.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        # A heavy walk, each foot down for two thirds of its cycle, the body level; a trot to run.
        "walk": {"period": 1.35, "duty": 0.68, "step": 0.12, "bob": 0.018, "snake": 2.5, "tail_swing": 5.0,
                 "order": "walk", "steady": 0.8, "push": 0.6, "curl": 0.4, "hip_roll": 2.0},
        "run": {"period": 0.8, "duty": 0.45, "step": 0.18, "bob": 0.03, "snake": 2.0, "tail_swing": 4.0,
                "order": "trot", "lean": -2.0, "steady": 0.85, "push": 0.8, "curl": 0.5, "neck_pitch": -8.0},
        "idle": {"period": 5.0, "breaths": 2, "look": 18.0, "nod": 2.0, "swell": 0.018, "tail_swing": 4.0, "heave": 0.006},
        "attack": {"period": 1.0, "jaw": 42.0, "lunge": 0.22, "draw": 10.0, "reach": 16.0, "head_up": 10.0,
                   "head_down": 6.0, "spine_dip": 3.0, "dip": 0.04},
        "death": {"period": 1.6, "roll": 84.0, "pivot": 0.26, "slide": 0.1, "limp_forward": 0.15, "limp_up": 0.2},
    },
    "body": {
        "around": 44,
        "soften": 0.05,
        "rough": 0.012,
        "scale": 0.5,
        "throat": 0.3,
        "trunk": [
            # The skull: deep and narrow, the snout's top straight, the jaw muscles behind the eye.
            st("Head", 1.015, 0.018, 0.03, 0.026, step=0.006),
            st("Head", 0.985, 0.042, 0.068, 0.05, step=0.01),
            st("Head", 0.9, 0.05, 0.094, 0.066, n_top=2.4, step=0.015),
            st("Head", 0.75, 0.056, 0.114, 0.077, n_top=2.4, step=0.02),
            st("Head", 0.58, 0.063, 0.128, 0.087, n_top=2.3, step=0.02),
            st("Head", 0.42, 0.073, 0.134, 0.097, step=0.02),
            st("Head", 0.28, 0.086, 0.14, 0.108, lift=0.01, step=0.02),
            st("Head", 0.14, 0.1, 0.126, 0.128, step=0.02),
            st("Head", 0.0, 0.096, 0.108, 0.134, step=0.025),
            st("Head", -0.1, 0.092, 0.098, 0.134, step=0.03),
            # The neck: thick and short.
            st("Neck3", 0.5, 0.1, 0.095, 0.13, step=0.035),
            st("Neck2", 0.5, 0.12, 0.11, 0.15, step=0.04),
            st("Neck1", 0.5, 0.14, 0.125, 0.18, step=0.04),
            # The body: deep and broad over the forelegs, the belly low.
            st("Spine4", 0.6, 0.18, 0.15, 0.24, step=0.05),
            st("Spine4", 0.1, 0.22, 0.175, 0.33, n_bot=2.3, step=0.05),
            st("Spine3", 0.5, 0.25, 0.19, 0.37, n_bot=2.4, step=0.05),
            st("Spine2", 0.5, 0.25, 0.19, 0.36, n_bot=2.3, step=0.05),
            st("Spine1", 0.5, 0.235, 0.185, 0.3, step=0.05),
            st("Hips", 0.25, 0.22, 0.18, 0.23, step=0.05),
            st("Hips", 0.9, 0.185, 0.16, 0.18, step=0.05),
            # The tail: heavy at the root, deeper than wide as it goes.
            st("Tail1", 0.5, 0.14, 0.13, 0.15, step=0.05),
            st("Tail2", 0.5, 0.12, 0.115, 0.13, step=0.05),
            st("Tail3", 0.5, 0.1, 0.1, 0.11, step=0.05),
            st("Tail4", 0.5, 0.083, 0.087, 0.093, step=0.05),
            st("Tail5", 0.5, 0.068, 0.074, 0.078, step=0.05),
            st("Tail6", 0.5, 0.055, 0.063, 0.065, step=0.05),
            st("Tail7", 0.5, 0.044, 0.053, 0.054, step=0.05),
            st("Tail8", 0.5, 0.035, 0.044, 0.044, step=0.05),
            st("Tail9", 0.5, 0.027, 0.036, 0.035, step=0.045),
            st("Tail10", 0.5, 0.021, 0.028, 0.027, step=0.04),
            st("Tail11", 0.5, 0.016, 0.021, 0.02, step=0.035),
            st("Tail12", 0.5, 0.012, 0.015, 0.014, step=0.03),
            st("Tail13", 0.5, 0.008, 0.01, 0.0095, step=0.03),
            st("Tail14", 0.6, 0.005, 0.006, 0.006, step=0.025),
            st("Tail_end", 0.3, 0.002, 0.002, 0.002, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.08), "to": ("Head", 1.0), "phi": 112.0, "depth": 0.008, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.25), "to": ("Head", 0.97), "count": 12, "length": 0.026, "radius": 0.0075,
                  "colour": (0.8, 0.76, 0.64)},
        "lower_teeth": {"from": ("Head", 0.25), "to": ("Head", 0.94), "count": 10, "length": 0.018, "radius": 0.0065},
        "eyes": {"at": ("Head", 0.3), "phi": 42.0, "radius": 0.021, "sunk": 0.55, "forward": 10.0, "up": 14.0,
                 "iris": (0.62, 0.55, 0.16), "pupil": (0.01, 0.008, 0.005), "slit": 0.22},
        "brow": {"at": ("Head", 0.31), "phi": 26.0, "size": 0.035, "height": 0.014},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.62), "phi": 66.0, "depth": 0.01, "width": 0.3},
        "nostrils": {"at": ("Head", 0.95), "phi": 38.0, "size": 0.01},
        # Two rows of bony plates down the back, from the neck to halfway down the tail.
        "plates": {"from": ("Neck2", 0.2), "to": ("Tail9", 0.5), "rows": [11.0], "length": 0.085, "width": 0.062,
                   "height": 0.016, "spacing": 0.082, "ref": 0.2, "colour": (0.05, 0.035, 0.02), "square": 0.3,
                   "keel": 0.7},
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.077, 0.143, 0.01), (0, -0.05, 0.1232, 0.1782, 0.02), (0, 0.25, 0.1232, 0.1672, 0.024),
                             (0, 0.55, 0.099, 0.1298, 0.014), (0, 0.85, 0.0693, 0.0792, 0.0), (0, 0.98, 0.0627, 0.0693, 0.0),
                             (1, 0.12, 0.066, 0.0902, -0.015), (1, 0.33, 0.0627, 0.088, -0.021), (1, 0.7, 0.0429, 0.0506, -0.006),
                             (1, 0.96, 0.0352, 0.0374, 0.0), (2, 0.15, 0.0385, 0.0308, 0.0), (2, 0.9, 0.0429, 0.0242, 0.0)],
                "around": 18,
                "digits": {"digits": [(-24.0, 0.11, 0.021, 0.038), (-8.0, 0.135, 0.022, 0.042), (8.0, 0.14, 0.022, 0.042),
                                      (24.0, 0.115, 0.02, 0.036)],
                           "flat": 0.75, "claw_curl": 0.7},
            },
            "fore": {
                "stations": [(0, -0.25, 0.055, 0.088, 0.0), (0, 0.0, 0.077, 0.099, 0.006), (0, 0.4, 0.0682, 0.0825, 0.008),
                             (0, 0.9, 0.0495, 0.055, 0.0), (1, 0.2, 0.0506, 0.0572, 0.004), (1, 0.6, 0.0407, 0.044, 0.0),
                             (1, 0.96, 0.033, 0.0352, 0.0), (2, 0.2, 0.0352, 0.0264, 0.0), (2, 0.9, 0.0396, 0.022, 0.0)],
                "around": 16,
                "digits": {"digits": [(-32.0, 0.055, 0.015, 0.024), (-16.0, 0.065, 0.016, 0.026), (0.0, 0.068, 0.016, 0.027),
                                      (16.0, 0.06, 0.015, 0.024), (32.0, 0.045, 0.013, 0.018)],
                           "flat": 0.75, "claw_curl": 0.6},
            },
        },
        "skin_detail": {"scales": {"cells": 100.0, "dorsal_size": 0.55, "groove": 0.38, "groove_dark": 0.3, "tint": 0.12,
                                   "speckle": 0.1, "relief": 0.8, "depth": 0.0025},
                        "scutes": {"size": (0.05, 0.036), "mortar": 0.07, "belly_below": -0.62, "flank_below": -0.45,
                                   "warp": 1.1}},
        "texture": 2048,
        "skin": {
            "back": (0.04, 0.026, 0.014),
            "flank": (0.17, 0.095, 0.042),
            "belly": (0.47, 0.35, 0.2),
            "throat": (0.52, 0.4, 0.24),
            "lips": (0.1, 0.06, 0.035),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.05, 0.04, 0.03),
            "mottle": 0.22,
            "shank_dark": 0.3,
            # Dark bands across the tail, faint on the back.
            "bands": {"colour": (0.012, 0.008, 0.005), "from": ("Hips", 0.5), "to": ("Tail_end", 0.5),
                      "period": 0.32, "width": 0.32, "strength": 0.65},
            # Blotches over the back and the upper flanks.
            "spots": {"colour": (0.02, 0.013, 0.007), "from": ("Neck2", 0.0), "to": ("Tail4", 0.5), "scale": 9.0,
                      "above": 0.3, "strength": 0.55},
        },
    },
}


# ==============================================================================
# A phytosaur (Machaeroprosopus, the Chinle's): not a crocodile, though it looks like one and lived like one -- a
# long-snouted armoured reptile of the rivers, three and a half metres of it, low on sprawling legs. Its nostrils
# are not at the tip of its snout but up on a mound just in front of its eyes; a rosette of bigger teeth at the
# snout's tip; heavy plates down its back; a tail flattened from the sides, to swim with. The river's night
# hunter (GAME-DESIGN 9.3).


PHYTOSAUR = {
    "height": 1.0,
    "skeleton": {
        "hip_height": 0.42,
        "pelvis_length": 0.18,
        "pelvis_pitch": -4.0,
        "spine": [(0.26, 0.0), (0.26, 0.0), (0.25, -1.0), (0.24, -2.0)],
        "neck": [(0.12, 6.0), (0.12, 3.0), (0.11, 0.0)],
        "skull": (0.82, -4.0),
        "jaw": (0.8, 0.05, -5.0),
        "jaw_hinge": 0.03,
        "tail": [(0.18, -6.0), (0.17, -4.0), (0.16, -3.0), (0.15, -2.0), (0.14, -2.0), (0.13, -1.0), (0.12, -1.0),
                 (0.11, 0.0), (0.1, 0.0), (0.09, 0.0), (0.08, 0.0), (0.07, 0.0), (0.06, 0.0), (0.05, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.28, 0.23, 0.13, 0.1],
                     "socket": (0.12, 0.0, -0.05), "stance": (0.13, 0.04), "foot": "plantigrade", "heel": 12.0,
                     "roll_tilt": 45.0, "bend": "forward", "splay": 38.0},
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.21, 0.18, 0.07, 0.06], "socket": (0.1, -0.03, -0.1), "stance": (0.13, 0.05),
                     "foot": "plantigrade", "heel": 16.0, "roll_tilt": 40.0, "bend": "back", "splay": 42.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        # The high walk of a crocodile out of the water: the belly off the ground, the legs out to the sides,
        # the body and tail swinging side to side with them.
        "walk": {"period": 1.25, "duty": 0.72, "step": 0.08, "bob": 0.012, "snake": 9.0, "tail_swing": 8.0,
                 "order": "walk", "steady": 0.85, "push": 0.5, "curl": 0.3, "hip_roll": 3.0},
        "run": {"period": 0.7, "duty": 0.5, "step": 0.11, "bob": 0.02, "snake": 8.0, "tail_swing": 7.0,
                "order": "trot", "steady": 0.85, "push": 0.7, "curl": 0.4, "hip_roll": 3.0},
        "idle": {"period": 6.0, "breaths": 2, "look": 10.0, "nod": 1.5, "swell": 0.02, "tail_swing": 5.0, "heave": 0.004},
        # A sideways snap, as a crocodile takes a fish: the head swung and the jaws shut on it.
        "attack": {"period": 0.9, "jaw": 34.0, "lunge": 0.18, "draw": 6.0, "reach": 8.0, "head_up": 12.0,
                   "head_down": 4.0, "spine_dip": 2.0, "dip": 0.02},
        "death": {"period": 1.5, "roll": 160.0, "pivot": 0.26, "slide": 0.05, "limp_forward": 0.08, "limp_up": 0.08},
    },
    "body": {
        "around": 44,
        "soften": 0.05,
        "rough": 0.012,
        "scale": 0.4,
        "throat": 0.2,
        "scutes_from": ("Neck2", 0.5),
        "trunk": [
            # The snout: long and slender, a little wider at its tip where the bigger teeth are; the nostrils up
            # on a mound before the eyes; the skull broad behind them.
            st("Head", 1.012, 0.012, 0.012, 0.012, step=0.006),
            st("Head", 0.99, 0.034, 0.03, 0.03, step=0.01),
            st("Head", 0.95, 0.036, 0.03, 0.03, step=0.015),
            st("Head", 0.9, 0.031, 0.027, 0.028, step=0.02),
            st("Head", 0.75, 0.034, 0.03, 0.031, step=0.025),
            st("Head", 0.58, 0.04, 0.035, 0.035, step=0.025),
            st("Head", 0.46, 0.05, 0.05, 0.042, step=0.02),
            st("Head", 0.4, 0.058, 0.07, 0.048, step=0.015),
            st("Head", 0.33, 0.08, 0.075, 0.058, step=0.015),
            st("Head", 0.22, 0.11, 0.07, 0.075, step=0.02),
            st("Head", 0.1, 0.13, 0.066, 0.09, step=0.02),
            st("Head", 0.0, 0.125, 0.062, 0.1, step=0.025),
            st("Head", -0.06, 0.12, 0.06, 0.1, step=0.03),
            st("Neck3", 0.5, 0.13, 0.065, 0.105, step=0.03),
            st("Neck2", 0.5, 0.145, 0.07, 0.11, step=0.035),
            st("Neck1", 0.5, 0.165, 0.08, 0.12, step=0.035),
            # The body: low, broad, flat on top, the belly slung between the legs.
            st("Spine4", 0.5, 0.23, 0.1, 0.17, n_top=2.6, step=0.04),
            st("Spine3", 0.5, 0.29, 0.115, 0.22, n_top=2.8, n_bot=2.4, step=0.04),
            st("Spine2", 0.5, 0.3, 0.115, 0.23, n_top=2.8, n_bot=2.4, step=0.04),
            st("Spine1", 0.5, 0.27, 0.11, 0.2, n_top=2.6, step=0.04),
            st("Hips", 0.3, 0.23, 0.11, 0.17, step=0.04),
            st("Hips", 0.9, 0.19, 0.105, 0.14, step=0.04),
            # The tail: flattened from the sides, deeper than wide, a paddle to its tip.
            st("Tail1", 0.5, 0.14, 0.11, 0.12, step=0.04),
            st("Tail2", 0.5, 0.11, 0.11, 0.11, step=0.04),
            st("Tail3", 0.5, 0.085, 0.105, 0.1, step=0.04),
            st("Tail4", 0.5, 0.066, 0.1, 0.09, step=0.04),
            st("Tail5", 0.5, 0.052, 0.094, 0.08, step=0.04),
            st("Tail6", 0.5, 0.042, 0.088, 0.07, step=0.04),
            st("Tail7", 0.5, 0.034, 0.08, 0.06, step=0.04),
            st("Tail8", 0.5, 0.027, 0.072, 0.05, step=0.035),
            st("Tail9", 0.5, 0.022, 0.063, 0.042, step=0.035),
            st("Tail10", 0.5, 0.018, 0.054, 0.034, step=0.03),
            st("Tail11", 0.5, 0.014, 0.045, 0.027, step=0.03),
            st("Tail12", 0.5, 0.011, 0.036, 0.02, step=0.025),
            st("Tail13", 0.5, 0.008, 0.026, 0.014, step=0.025),
            st("Tail14", 0.6, 0.005, 0.015, 0.008, step=0.02),
            st("Tail_end", 0.3, 0.002, 0.004, 0.003, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 100.0, "depth": 0.004, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.2), "to": ("Head", 0.99), "count": 34, "length": 0.018, "radius": 0.004,
                  "rosette": 0.96, "rosette_width": 0.05, "colour": (0.82, 0.78, 0.66)},
        "lower_teeth": {"from": ("Head", 0.2), "to": ("Head", 0.97), "count": 30, "length": 0.014, "radius": 0.0036},
        "eyes": {"at": ("Head", 0.3), "phi": 30.0, "radius": 0.018, "sunk": 0.5, "forward": 6.0, "up": 30.0,
                 "iris": (0.55, 0.5, 0.15), "pupil": (0.01, 0.008, 0.005), "slit": 0.25},
        "brow": {"at": ("Head", 0.31), "phi": 18.0, "size": 0.03, "height": 0.012},
        # The nostrils up on their mound before the eyes -- breathing with all but it under the water.
        "mounds": [{"at": ("Head", 0.42), "phi": 0.0, "size": 0.035, "height": 0.03}],
        "nostrils": {"at": ("Head", 0.42), "phi": 14.0, "size": 0.008},
        "plates": {"from": ("Neck2", 0.0), "to": ("Tail12", 0.5), "rows": [6.0, 19.0, 33.0], "length": 0.085, "width": 0.062,
                   "height": 0.02, "spacing": 0.08, "ref": 0.24, "colour": (0.03, 0.03, 0.018), "square": 0.7,
                   "keel": 0.8},
        "limbs": {
            "hind": {
                "stations": [(0, -0.25, 0.06, 0.09, 0.0), (0, 0.0, 0.082, 0.11, 0.008), (0, 0.35, 0.078, 0.1, 0.01),
                             (0, 0.75, 0.058, 0.066, 0.0), (0, 0.98, 0.048, 0.052, 0.0), (1, 0.2, 0.048, 0.06, -0.008),
                             (1, 0.6, 0.038, 0.044, -0.004), (1, 0.96, 0.031, 0.032, 0.0), (2, 0.2, 0.034, 0.022, 0.0),
                             (2, 0.9, 0.038, 0.018, 0.0)],
                "around": 16,
                "digits": {"digits": [(-26.0, 0.08, 0.014, 0.022), (-9.0, 0.1, 0.015, 0.025), (8.0, 0.1, 0.015, 0.025),
                                      (25.0, 0.085, 0.013, 0.02)],
                           "flat": 0.6, "claw_curl": 0.6},
            },
            "fore": {
                "stations": [(0, -0.25, 0.048, 0.07, 0.0), (0, 0.0, 0.064, 0.076, 0.004), (0, 0.4, 0.058, 0.066, 0.006),
                             (0, 0.95, 0.04, 0.043, 0.0), (1, 0.3, 0.039, 0.043, 0.0), (1, 0.95, 0.028, 0.029, 0.0),
                             (2, 0.3, 0.03, 0.018, 0.0), (2, 0.9, 0.034, 0.016, 0.0)],
                "around": 14,
                "digits": {"digits": [(-34.0, 0.045, 0.01, 0.014), (-17.0, 0.055, 0.011, 0.016), (0.0, 0.058, 0.011, 0.016),
                                      (17.0, 0.05, 0.01, 0.014), (34.0, 0.04, 0.009, 0.012)],
                           "flat": 0.6, "claw_curl": 0.5},
            },
        },
        "skin_detail": {"scales": {"cells": 95.0, "dorsal_size": 0.5, "groove": 0.36, "groove_dark": 0.3, "tint": 0.12,
                                   "speckle": 0.1, "relief": 0.8, "depth": 0.0025},
                        "scutes": {"size": (0.042, 0.03), "mortar": 0.08, "belly_below": -0.5, "flank_below": -0.05,
                                   "warp": 1.0}},
        "texture": 2048,
        "skin": {
            "back": (0.033, 0.038, 0.018),
            "flank": (0.11, 0.11, 0.05),
            "belly": (0.5, 0.45, 0.24),
            "throat": (0.56, 0.5, 0.3),
            "lips": (0.07, 0.065, 0.035),
            "mouth": (0.3, 0.08, 0.06),
            "claws": (0.04, 0.035, 0.025),
            "mottle": 0.22,
            "shank_dark": 0.25,
            "bands": {"colour": (0.01, 0.01, 0.006), "from": ("Neck1", 0.5), "to": ("Tail_end", 0.5),
                      "period": 0.28, "width": 0.3, "strength": 0.7},
            "spots": {"colour": (0.012, 0.012, 0.007), "from": ("Head", 0.4), "to": ("Tail6", 0.5), "scale": 8.0,
                      "above": 0.3, "strength": 0.6},
        },
    },
}


# ==============================================================================
# Hesperosuchus agilis ("the agile western crocodile"): an early crocodylomorph of the Chinle -- the crocodile's line
# before it went to the water -- a metre and a bit long, slight, up on long slender legs, a long narrow snout,
# a pair of plates down its back. It ran. (The game's runner, from the third day.)
#
# Placerias hesterni: a dicynodont -- a plant-eating relative of the mammals' line -- three metres and more of
# barrel on stout legs, a turtle-like beak and a pair of tusks growing down from its upper jaw; in herds (the
# Placerias Quarry held forty of them). It grazes on the valley's far sides.


HESPEROSUCHUS = {
    "height": 0.55,
    "skeleton": {
        "hip_height": 0.22,
        "pelvis_length": 0.05,
        "pelvis_pitch": -6.0,
        "spine": [(0.1, 2.0), (0.1, 0.0), (0.09, -2.0)],
        "neck": [(0.045, 20.0), (0.045, 14.0), (0.04, 6.0)],
        "skull": (0.15, -8.0),
        "jaw": (0.14, 0.018, -12.0),
        "jaw_hinge": 0.06,
        "tail": [(0.07, -4.0), (0.07, -3.0), (0.065, -2.0), (0.06, -2.0), (0.055, -1.0), (0.05, -1.0),
                 (0.045, 0.0), (0.04, 0.0), (0.035, 0.0), (0.03, 0.0), (0.028, 0.0), (0.025, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.1, 0.1, 0.055, 0.04],
                     "socket": (0.035, 0.0, -0.012), "stance": (0.005, 0.03), "foot": "digitigrade", "foot_tilt": 45.0,
                     "roll_tilt": 30.0, "bend": "forward", "splay": 5.0},
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.075, 0.075, 0.028, 0.025], "socket": (0.03, -0.01, -0.035), "stance": (0.008, 0.035),
                     "foot": "plantigrade", "heel": 40.0, "roll_tilt": 30.0, "bend": "back", "splay": 6.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        "walk": {"period": 0.55, "duty": 0.62, "step": 0.03, "bob": 0.005, "snake": 4.0, "tail_swing": 6.0,
                 "order": "walk", "steady": 0.8, "push": 0.6, "curl": 0.4, "hip_roll": 2.0},
        # A bounding run: the hind legs together-ish, the fore after, a long flight between.
        "run": {"period": 0.3, "duty": 0.32, "step": 0.05, "bob": 0.012, "snake": 2.0, "tail_swing": 3.0,
                "order": "trot", "lead": 0.12, "lean": -3.0, "steady": 0.85, "push": 0.9, "curl": 0.5, "tail_lift": 6.0},
        "idle": {"period": 3.0, "breaths": 3, "look": 30.0, "nod": 4.0, "swell": 0.03, "tail_swing": 5.0, "heave": 0.002},
        "attack": {"period": 0.55, "jaw": 40.0, "lunge": 0.06, "draw": 14.0, "reach": 18.0, "head_up": 10.0,
                   "head_down": 6.0, "spine_dip": 3.0, "dip": 0.01},
        "death": {"period": 1.1, "roll": 86.0, "pivot": 0.04, "slide": 0.02, "limp_forward": 0.04, "limp_up": 0.05},
    },
    "body": {
        "around": 36,
        "soften": 0.02,
        "rough": 0.01,
        "scale": 0.1,
        "throat": 0.3,
        "trunk": [
            st("Head", 1.015, 0.004, 0.004, 0.004, step=0.003),
            st("Head", 0.99, 0.008, 0.009, 0.008, step=0.004),
            st("Head", 0.9, 0.0095, 0.011, 0.01, step=0.006),
            st("Head", 0.75, 0.011, 0.013, 0.012, step=0.008),
            st("Head", 0.58, 0.014, 0.017, 0.015, step=0.008),
            st("Head", 0.42, 0.018, 0.022, 0.018, step=0.008),
            st("Head", 0.3, 0.022, 0.025, 0.021, lift=0.002, step=0.008),
            st("Head", 0.16, 0.026, 0.024, 0.026, step=0.008),
            st("Head", 0.02, 0.024, 0.021, 0.028, step=0.01),
            st("Head", -0.1, 0.02, 0.018, 0.026, step=0.012),
            st("Neck3", 0.5, 0.02, 0.018, 0.025, step=0.012),
            st("Neck2", 0.5, 0.023, 0.02, 0.028, step=0.012),
            st("Neck1", 0.5, 0.027, 0.023, 0.033, step=0.012),
            st("Spine3", 0.6, 0.036, 0.028, 0.048, step=0.014),
            st("Spine3", 0.1, 0.043, 0.031, 0.06, n_bot=2.3, step=0.015),
            st("Spine2", 0.5, 0.046, 0.032, 0.064, n_bot=2.3, step=0.015),
            st("Spine1", 0.5, 0.044, 0.032, 0.056, step=0.015),
            st("Hips", 0.3, 0.04, 0.032, 0.044, step=0.015),
            st("Hips", 0.9, 0.034, 0.03, 0.036, step=0.015),
            st("Tail1", 0.5, 0.026, 0.026, 0.028, step=0.016),
            st("Tail2", 0.5, 0.021, 0.022, 0.023, step=0.016),
            st("Tail3", 0.5, 0.017, 0.018, 0.019, step=0.016),
            st("Tail4", 0.5, 0.014, 0.015, 0.015, step=0.016),
            st("Tail5", 0.5, 0.011, 0.012, 0.012, step=0.016),
            st("Tail6", 0.5, 0.009, 0.01, 0.0095, step=0.014),
            st("Tail7", 0.5, 0.007, 0.008, 0.0075, step=0.014),
            st("Tail8", 0.5, 0.0055, 0.0062, 0.0058, step=0.012),
            st("Tail9", 0.5, 0.0042, 0.0048, 0.0044, step=0.012),
            st("Tail10", 0.5, 0.0032, 0.0036, 0.0034, step=0.01),
            st("Tail11", 0.5, 0.0024, 0.0027, 0.0025, step=0.01),
            st("Tail12", 0.6, 0.0016, 0.0018, 0.0017, step=0.008),
            st("Tail_end", 0.3, 0.0008, 0.0008, 0.0008, step=0.004),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 106.0, "depth": 0.0015, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 16, "length": 0.0045, "radius": 0.0011,
                  "colour": (0.8, 0.76, 0.66)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.94), "count": 14, "length": 0.0035, "radius": 0.001},
        "eyes": {"at": ("Head", 0.3), "phi": 46.0, "radius": 0.0085, "sunk": 0.55, "forward": 12.0, "up": 14.0,
                 "iris": (0.66, 0.46, 0.12), "pupil": (0.01, 0.008, 0.005), "slit": 0.22},
        "brow": {"at": ("Head", 0.31), "phi": 26.0, "size": 0.012, "height": 0.004},
        "nostrils": {"at": ("Head", 0.96), "phi": 30.0, "size": 0.0022},
        "plates": {"from": ("Neck2", 0.0), "to": ("Tail9", 0.5), "rows": [9.0], "length": 0.016, "width": 0.012,
                   "height": 0.004, "spacing": 0.015, "ref": 0.04, "colour": (0.05, 0.03, 0.015)},
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.015, 0.028, 0.002), (0, -0.05, 0.024, 0.034, 0.004), (0, 0.3, 0.025, 0.033, 0.005),
                             (0, 0.75, 0.018, 0.021, 0.0), (0, 0.97, 0.014, 0.016, 0.0), (1, 0.15, 0.015, 0.021, -0.005),
                             (1, 0.4, 0.014, 0.02, -0.006), (1, 0.75, 0.0095, 0.011, -0.001), (1, 0.96, 0.0072, 0.0076, 0.0),
                             (2, 0.15, 0.0064, 0.006, 0.0), (2, 0.9, 0.0055, 0.0048, 0.0)],
                "around": 14,
                "digits": {"digits": [(-16.0, 0.032, 0.0033, 0.008), (-5.0, 0.04, 0.0035, 0.009), (5.0, 0.04, 0.0035, 0.009),
                                      (16.0, 0.033, 0.0032, 0.008)],
                           "flat": 0.8, "claw_curl": 0.8},
            },
            "fore": {
                "stations": [(0, -0.25, 0.012, 0.017, 0.0), (0, 0.0, 0.015, 0.019, 0.002), (0, 0.4, 0.0145, 0.019, 0.003),
                             (0, 0.95, 0.0098, 0.011, 0.0), (1, 0.3, 0.0105, 0.012, 0.001), (1, 0.95, 0.0068, 0.0071, 0.0),
                             (2, 0.3, 0.0064, 0.0045, 0.0), (2, 0.9, 0.0068, 0.0038, 0.0)],
                "around": 12,
                "digits": {"digits": [(-24.0, 0.02, 0.0022, 0.005), (-8.0, 0.025, 0.0024, 0.006), (8.0, 0.025, 0.0024, 0.006),
                                      (24.0, 0.02, 0.0022, 0.005)],
                           "flat": 0.8, "claw_curl": 0.7},
            },
        },
        "skin_detail": {"scales": {"cells": 330.0, "dorsal_size": 0.5, "groove": 0.36, "groove_dark": 0.28, "tint": 0.12,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.0007},
                        "scutes": {"size": (0.01, 0.0075), "mortar": 0.08, "belly_below": -0.5, "flank_below": -0.2,
                                   "warp": 1.0}},
        "texture": 1024,
        "skin": {
            "back": (0.07, 0.04, 0.018),
            "flank": (0.25, 0.15, 0.065),
            "belly": (0.58, 0.47, 0.28),
            "throat": (0.62, 0.52, 0.32),
            "lips": (0.12, 0.07, 0.04),
            "mouth": (0.32, 0.08, 0.06),
            "claws": (0.04, 0.03, 0.02),
            "mottle": 0.2,
            "shank_dark": 0.25,
            # Dark spots over the back and flanks.
            "spots": {"colour": (0.02, 0.012, 0.006), "from": ("Neck3", 0.0), "to": ("Tail8", 0.5), "scale": 38.0,
                      "above": 0.28, "strength": 0.7},
            "eye_stripe": {"colour": (0.025, 0.015, 0.008), "from": ("Head", 0.95), "to": ("Neck3", 0.5),
                           "phi": 60.0, "width": 14.0},
        },
    },
}

PLACERIAS = {
    # Scenery: the herd (Config.HERDS) fits it to its length and walks it at 0.6 m/s.
    "fit": "length",
    "length": 3.5,
    "paces": {"walk": 0.6, "run": 1.4},
    "skeleton": {
        "hip_height": 0.58,
        "pelvis_length": 0.16,
        "pelvis_pitch": -12.0,
        "spine": [(0.25, 2.0), (0.25, 0.0), (0.25, -2.0), (0.22, -6.0)],
        "neck": [(0.12, -4.0), (0.11, -10.0)],
        "skull": (0.48, -26.0),
        "jaw": (0.36, 0.1, -40.0),
        "jaw_hinge": 0.2,
        "tail": [(0.12, -20.0), (0.1, -22.0), (0.09, -20.0), (0.08, -18.0), (0.07, -16.0), (0.06, -14.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.3, 0.25, 0.12, 0.08],
                     "socket": (0.16, 0.0, -0.06), "stance": (0.03, 0.02), "foot": "plantigrade", "heel": 16.0,
                     "roll_tilt": 40.0, "bend": "forward", "splay": 10.0},
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.26, 0.22, 0.08, 0.06], "socket": (0.17, -0.02, -0.14), "stance": (0.1, 0.05),
                     "foot": "plantigrade", "heel": 18.0, "roll_tilt": 40.0, "bend": "back", "splay": 32.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        "walk": {"period": 1.5, "duty": 0.75, "step": 0.06, "bob": 0.012, "snake": 3.0, "tail_swing": 4.0,
                 "order": "walk", "steady": 0.7, "push": 0.5, "curl": 0.3, "hip_roll": 3.0},
        "run": {"period": 0.9, "duty": 0.55, "step": 0.09, "bob": 0.02, "snake": 3.0, "tail_swing": 4.0,
                "order": "trot", "steady": 0.7, "push": 0.6, "curl": 0.3},
        # Grazing: its head down at the ground, cropping (its jaw working), now and then up to look about.
        "idle": {"period": 6.0, "breaths": 2, "look": 12.0, "nod": 3.0, "swell": 0.015, "tail_swing": 3.0,
                 "heave": 0.004, "graze": {"neck": -30.0, "head": -22.0, "chew": 10.0, "chews": 12, "up": (0.55, 0.8)}},
        "attack": {"period": 1.0, "jaw": 30.0, "lunge": 0.12, "draw": 6.0, "reach": 10.0, "head_up": 10.0,
                   "head_down": 10.0, "spine_dip": 2.0, "dip": 0.02},
        "death": {"period": 1.6, "roll": 86.0, "pivot": 0.26, "slide": 0.05, "limp_forward": 0.1, "limp_up": 0.1},
    },
    "body": {
        "around": 44,
        "soften": 0.05,
        "rough": 0.012,
        "scale": 0.45,
        "throat": 0.25,
        "trunk": [
            # The beak: short, deep, sharp-edged; the tusks behind it; the skull broad and high behind the eyes.
            st("Head", 1.02, 0.02, 0.02, 0.02, step=0.006),
            st("Head", 0.97, 0.05, 0.05, 0.06, step=0.01),
            st("Head", 0.88, 0.07, 0.075, 0.09, step=0.015),
            st("Head", 0.74, 0.09, 0.1, 0.12, step=0.02),
            st("Head", 0.58, 0.11, 0.13, 0.14, step=0.02),
            st("Head", 0.42, 0.135, 0.15, 0.15, step=0.02),
            st("Head", 0.26, 0.16, 0.16, 0.16, lift=0.01, step=0.02),
            st("Head", 0.1, 0.17, 0.15, 0.17, step=0.025),
            st("Head", -0.05, 0.16, 0.14, 0.18, step=0.03),
            st("Neck2", 0.5, 0.18, 0.15, 0.2, step=0.035),
            st("Neck1", 0.5, 0.22, 0.18, 0.24, step=0.04),
            # A barrel of a body.
            st("Spine4", 0.5, 0.28, 0.22, 0.3, step=0.05),
            st("Spine3", 0.5, 0.34, 0.25, 0.36, n_bot=2.2, step=0.05),
            st("Spine2", 0.5, 0.36, 0.26, 0.37, n_bot=2.2, step=0.05),
            st("Spine1", 0.5, 0.34, 0.25, 0.33, step=0.05),
            st("Hips", 0.3, 0.3, 0.23, 0.26, step=0.05),
            st("Hips", 0.9, 0.24, 0.2, 0.2, step=0.05),
            # A short tail.
            st("Tail1", 0.5, 0.16, 0.14, 0.14, step=0.04),
            st("Tail2", 0.5, 0.11, 0.1, 0.1, step=0.04),
            st("Tail3", 0.5, 0.075, 0.07, 0.07, step=0.035),
            st("Tail4", 0.5, 0.05, 0.048, 0.047, step=0.03),
            st("Tail5", 0.5, 0.032, 0.031, 0.03, step=0.025),
            st("Tail6", 0.6, 0.016, 0.016, 0.015, step=0.02),
            st("Tail_end", 0.3, 0.005, 0.005, 0.005, step=0.01),
        ],
        # The beak's edge -- no teeth: the tusks are its only ones.
        "mouth": {"from": ("Head", 0.2), "to": ("Head", 1.0), "phi": 118.0, "depth": 0.006, "width": 0.1, "band": 3.0},
        "eyes": {"at": ("Head", 0.3), "phi": 50.0, "radius": 0.022, "sunk": 0.62, "forward": 10.0, "up": 6.0,
                 "iris": (0.3, 0.2, 0.1), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.31), "phi": 30.0, "size": 0.05, "height": 0.018},
        "nostrils": {"at": ("Head", 0.8), "phi": 40.0, "size": 0.012},
        "tusks": {"at": ("Head", 0.62), "phi": 100.0, "length": 0.11, "radius": 0.022, "colour": (0.42, 0.36, 0.24)},
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.08, 0.13, 0.01), (0, -0.05, 0.11, 0.15, 0.015), (0, 0.3, 0.1, 0.13, 0.015),
                             (0, 0.75, 0.07, 0.08, 0.0), (0, 0.97, 0.058, 0.064, 0.0), (1, 0.18, 0.064, 0.08, -0.012),
                             (1, 0.55, 0.052, 0.058, -0.006), (1, 0.96, 0.04, 0.042, 0.0), (2, 0.3, 0.048, 0.033, 0.0),
                             (2, 0.9, 0.054, 0.028, 0.0)],
                "around": 18,
                "digits": {"digits": [(-28.0, 0.06, 0.02, 0.022), (-10.0, 0.07, 0.022, 0.024), (10.0, 0.07, 0.022, 0.024),
                                      (28.0, 0.06, 0.02, 0.022)],
                           "flat": 0.6, "claw_curl": 0.4},
            },
            "fore": {
                "stations": [(0, -0.25, 0.08, 0.1, 0.0), (0, 0.0, 0.1, 0.12, 0.008), (0, 0.45, 0.076, 0.086, 0.01),
                             (0, 0.93, 0.054, 0.06, 0.0), (1, 0.15, 0.06, 0.07, 0.006), (1, 0.5, 0.05, 0.055, 0.003),
                             (1, 0.95, 0.036, 0.04, 0.0), (2, 0.3, 0.046, 0.03, 0.0), (2, 0.9, 0.052, 0.026, 0.0)],
                "around": 16,
                "digits": {"digits": [(-30.0, 0.05, 0.018, 0.02), (-12.0, 0.06, 0.02, 0.022), (8.0, 0.06, 0.02, 0.022),
                                      (26.0, 0.05, 0.018, 0.02)],
                           "flat": 0.6, "claw_curl": 0.4},
            },
        },
        "skin_detail": {"scales": {"cells": 90.0, "dorsal_size": 0.6, "groove": 0.3, "groove_dark": 0.18, "tint": 0.08,
                                   "speckle": 0.12, "relief": 0.35, "depth": 0.0015}},
        "texture": 1024,
        "skin": {
            "back": (0.055, 0.042, 0.028),
            "flank": (0.15, 0.11, 0.066),
            "belly": (0.36, 0.29, 0.18),
            "throat": (0.4, 0.32, 0.2),
            "lips": (0.05, 0.04, 0.03),
            "mouth": (0.25, 0.1, 0.08),
            "claws": (0.05, 0.04, 0.03),
            "mottle": 0.16,
            "shank_dark": 0.22,
            # The beak horn-coloured.
            "beak": {"from": ("Head", 0.78), "colour": (0.03, 0.025, 0.02)},
            "spots": {"colour": (0.05, 0.035, 0.02), "from": ("Neck1", 0.0), "to": ("Tail3", 0.5), "scale": 5.0,
                      "above": 0.32, "strength": 0.4},
        },
    },
}


# ==============================================================================
# Desmatosuchus spurensis: an aetosaur -- a plant-eater of the crocodile's line, armoured from its neck to the tip of
# its tail -- of the same Chinle rocks as Coelophysis, Postosuchus, the phytosaurs and Placerias (Parker 2008). Four
# and a half metres of it, low and broad on short stout legs, the hind longer than the fore, so its back falls a little
# to its shoulders; a metre high at the hips. Its back and its tail one carapace: transverse rows of thick rectangular
# bony plates, each row a pair of wide paramedians either side of the midline and a lateral at each edge bent down
# over the flank. The laterals of its neck drawn out into long horns, curving back, longer row by row to the biggest
# pair at the shoulders, nearly half a metre each; behind them the laterals keep only a low point. A small head, its
# snout blunt and turned up at the tip like a pig's, toothless at the front -- to root for plants with. Built true to
# size; the game's armoured grazer that, frightened by the crashed capsule, charges it and rams it -- arrows bounce
# off it.


DESMATOSUCHUS = {
    # No Config.DINOS entry fits it yet: its height as built (the top of the carapace over its hips), so it is drawn
    # at its own size -- 4.5 m long.
    "height": 1.01,
    # Its strides drawn at its own paces: a heavy walk, and the trot it charges at.
    "paces": {"walk": 0.8, "run": 2.4},
    "skeleton": {
        # The hip joints 0.66 m up: the back over them a metre (its plates and all).
        "hip_height": 0.66,
        "pelvis_length": 0.24,
        "pelvis_pitch": -10.0,
        # From the hips forward and a little down to the shoulders.
        "spine": [(0.33, -2.0), (0.33, -4.0), (0.33, -5.0), (0.31, -4.0)],
        # A short, thick neck, rising a little from the shoulders; the small head held low before them.
        "neck": [(0.16, 8.0), (0.15, 5.0), (0.14, 0.0)],
        "skull": (0.31, -12.0),
        "jaw": (0.27, 0.05, -15.0),
        "jaw_hinge": 0.1,
        # The tail as long as the rest of it, sloping down from the hips and level towards its tip.
        "tail": [(0.22, -20.0), (0.21, -17.0), (0.2, -14.0), (0.19, -11.0), (0.18, -9.0), (0.17, -7.0), (0.16, -6.0),
                 (0.15, -5.0), (0.14, -4.0), (0.13, -3.0), (0.12, -2.0), (0.11, -2.0), (0.1, -1.0), (0.09, -1.0)],
        "limbs": {
            # Semi-erect: the hind legs under the hips, the knees a little out; plantigrade, four broad-clawed toes.
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.36, 0.27, 0.14, 0.1],
                     "socket": (0.25, 0.0, -0.06), "stance": (0.05, 0.04), "foot": "plantigrade", "heel": 22.0,
                     "roll_tilt": 40.0, "bend": "forward", "splay": 18.0},
            # The forelegs shorter and more sprawled, the elbows out; five short fingers.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.28, 0.21, 0.09, 0.07], "socket": (0.21, -0.07, -0.15), "stance": (0.11, 0.08),
                     "foot": "plantigrade", "heel": 30.0, "roll_tilt": 35.0, "bend": "back", "splay": 36.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        # A heavy walk, each foot down two thirds of its cycle, the body swaying a little over them.
        "walk": {"period": 1.1, "duty": 0.68, "step": 0.08, "bob": 0.014, "snake": 2.5, "tail_swing": 4.0,
                 "order": "walk", "steady": 0.75, "push": 0.5, "curl": 0.3, "hip_roll": 2.5},
        # Its charge: a heavy trot, head and shoulders down, its spikes before it.
        "run": {"period": 0.5, "duty": 0.42, "step": 0.12, "bob": 0.03, "snake": 2.0, "tail_swing": 3.0,
                "order": "trot", "lean": 3.0, "steady": 0.6, "push": 0.7, "curl": 0.4, "neck_pitch": -14.0,
                "head_pitch": -6.0},
        # Rooting: its snout down in the ground, nosing and cropping; up now and then to look about.
        "idle": {"period": 6.0, "breaths": 2, "look": 14.0, "nod": 2.5, "swell": 0.012, "tail_swing": 3.0,
                 "heave": 0.006, "graze": {"neck": -32.0, "head": -13.0, "chew": 8.0, "chews": 10, "up": (0.42, 0.95),
                                           "pitch": 5.0}},
        # Its blow is its body: it gathers itself, then drives in head down, a shoulder swung into what it hits
        # so the spike there hooks it -- and draws back (the game loops it while it rams).
        "attack": {"period": 1.1, "ram": True, "lunge": 0.22, "back": 0.08, "crouch": 0.03, "dip": 0.02,
                   "lower": 4.0, "tuck": 8.0, "head_down": 4.0, "toss": 10.0, "hook": 14.0, "roll": 7.0},
        # Killed, it goes down on its belly -- forelegs first -- its legs sprawled out, tipping a little onto its side.
        "death": {"period": 1.8, "slump": True, "drop": 0.31, "front": 15.0, "roll": 7.0, "splay": 0.9,
                  "reach_hind": 0.26, "limp_neck": 14.0, "limp_head": 18.0, "turn": 16.0},
    },
    "body": {
        "around": 44,
        "soften": 0.05,
        "rough": 0.01,
        "scale": 0.45,
        "throat": 0.25,
        # The snout's tip blunt: its point hardly past its last ring.
        "tips": (0.004, 0.02),
        "trunk": [
            # The skull: small, the snout narrowing from the eyes and widening again at its tip into a blunt spade
            # turned up -- the pig's snout it rooted with.
            st("Head", 1.008, 0.034, 0.02, 0.019, lift=0.017, n_top=2.6, n_bot=2.6, step=0.004),
            st("Head", 0.985, 0.043, 0.029, 0.027, lift=0.015, n_top=2.5, n_bot=2.5, step=0.008),
            st("Head", 0.94, 0.041, 0.034, 0.031, lift=0.01, n_top=2.3, step=0.012),
            st("Head", 0.86, 0.034, 0.039, 0.035, lift=0.004, step=0.015),
            st("Head", 0.74, 0.037, 0.045, 0.04, step=0.02),
            st("Head", 0.6, 0.045, 0.052, 0.046, step=0.02),
            st("Head", 0.45, 0.056, 0.06, 0.053, step=0.02),
            st("Head", 0.32, 0.068, 0.066, 0.06, lift=0.004, step=0.02),
            st("Head", 0.2, 0.078, 0.066, 0.067, step=0.02),
            st("Head", 0.08, 0.083, 0.062, 0.074, step=0.02),
            st("Head", -0.04, 0.084, 0.06, 0.08, step=0.025),
            st("Head", -0.12, 0.088, 0.066, 0.088, step=0.03),
            # The neck: short and thick, armoured round.
            st("Neck3", 0.5, 0.1, 0.085, 0.1, step=0.035),
            st("Neck2", 0.5, 0.13, 0.1, 0.12, step=0.04),
            st("Neck1", 0.5, 0.17, 0.12, 0.14, step=0.04),
            # The body: broad and flat-topped, the carapace's edges bent down over the flanks; the belly flat. Broad
            # already at the shoulders, where the forelegs come out under the great horns.
            st("Spine4", 0.75, 0.27, 0.18, 0.2, n_top=2.7, step=0.045),
            st("Spine4", 0.2, 0.3, 0.22, 0.25, n_top=2.9, n_bot=2.3, step=0.05),
            st("Spine3", 0.5, 0.37, 0.27, 0.3, n_top=3.1, n_bot=2.5, step=0.05),
            st("Spine2", 0.5, 0.4, 0.3, 0.32, n_top=3.1, n_bot=2.5, step=0.05),
            st("Spine1", 0.5, 0.39, 0.31, 0.29, n_top=3.0, n_bot=2.4, step=0.05),
            st("Hips", 0.2, 0.34, 0.32, 0.23, n_top=2.8, step=0.05),
            st("Hips", 0.85, 0.27, 0.27, 0.18, n_top=2.6, step=0.05),
            # The tail: broad at its root, tapering for all its length.
            st("Tail1", 0.5, 0.2, 0.2, 0.15, n_top=2.4, step=0.05),
            st("Tail2", 0.5, 0.165, 0.16, 0.13, n_top=2.3, step=0.05),
            st("Tail3", 0.5, 0.138, 0.128, 0.112, step=0.05),
            st("Tail4", 0.5, 0.116, 0.108, 0.096, step=0.05),
            st("Tail5", 0.5, 0.097, 0.092, 0.082, step=0.05),
            st("Tail6", 0.5, 0.081, 0.078, 0.07, step=0.05),
            st("Tail7", 0.5, 0.067, 0.066, 0.059, step=0.045),
            st("Tail8", 0.5, 0.055, 0.055, 0.05, step=0.045),
            st("Tail9", 0.5, 0.045, 0.045, 0.041, step=0.04),
            st("Tail10", 0.5, 0.036, 0.037, 0.034, step=0.04),
            st("Tail11", 0.5, 0.028, 0.029, 0.027, step=0.035),
            st("Tail12", 0.5, 0.021, 0.022, 0.02, step=0.03),
            st("Tail13", 0.5, 0.015, 0.016, 0.015, step=0.03),
            st("Tail14", 0.6, 0.009, 0.01, 0.009, step=0.025),
            st("Tail_end", 0.3, 0.003, 0.003, 0.003, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.12), "to": ("Head", 0.99), "phi": 110.0, "depth": 0.004, "width": 0.1, "band": 3.0},
        # Small leaf-shaped teeth, set back and hidden by the lips: the front of the snout is toothless.
        "teeth": {"from": ("Head", 0.32), "to": ("Head", 0.7), "count": 7, "length": 0.0035, "radius": 0.0022,
                  "colour": (0.55, 0.5, 0.4)},
        "eyes": {"at": ("Head", 0.3), "phi": 50.0, "radius": 0.016, "sunk": 0.6, "forward": 10.0, "up": 8.0,
                 "iris": (0.42, 0.3, 0.1), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.31), "phi": 30.0, "size": 0.035, "height": 0.012},
        "nostrils": {"at": ("Head", 0.975), "phi": 30.0, "size": 0.008},
        # The carapace (tools/dino_body.py _carapace): rows of plates from behind the head to near the tip of the tail.
        "carapace": {
            "from": ("Neck3", 0.75), "to": ("Tail13", 0.5),
            # A row's length along the body at the trunk's width, less as it narrows; a seam between rows.
            "length": 0.095, "ref": 0.36, "shrink": 0.5, "least": 0.45, "seam": 0.1,
            # How far round from the midline the plates go (degrees round the section): over the flanks' edge.
            "reach": [(("Neck3", 0.75), 106.0), (("Spine4", 0.6), 108.0), (("Spine3", 0.5), 112.0), (("Hips", 0.6), 112.0),
                      (("Tail3", 0.5), 122.0), (("Tail13", 0.5), 130.0)],
            # Across each side: the paramedian (wide, a low boss behind its middle) and the lateral (bent over the
            # flank along a keel, its point at the back of the keel).
            "columns": [{"v": (0.004, 0.505), "height": 0.022, "boss": (0.7, 0.45, 0.45, 0.28)},
                        {"v": (0.515, 1.0), "height": 0.02, "keel": (0.3, 0.6), "boss": (0.72, 0.3, 0.5, 0.2)}],
            # The laterals' points, out sideways from the bend of the plate, raked back, turned up: horns on the
            # neck, longer row by row, the biggest pair at the shoulders; low points behind them, smaller down the
            # tail. (length; rake back from straight out, up, curve; base across and along -- degrees, metres.)
            "points": [
                {"at": ("Neck3", 0.75), "length": 0.08, "rake": 30.0, "up": 12.0, "curve": 0.1, "base": (0.02, 0.035)},
                {"at": ("Neck1", 0.5), "length": 0.24, "rake": 18.0, "up": 12.0, "curve": 0.22, "base": (0.034, 0.065)},
                {"at": ("Spine4", 0.9), "length": 0.3, "rake": 16.0, "up": 12.0, "curve": 0.24, "base": (0.04, 0.075)},
                {"at": ("Spine4", 0.62), "length": 0.04, "rake": 50.0, "up": 4.0, "curve": 0.05, "base": (0.02, 0.035)},
                {"at": ("Hips", 0.5), "length": 0.035, "rake": 55.0, "up": 2.0, "curve": 0.05, "base": (0.018, 0.032)},
                {"at": ("Tail13", 0.5), "length": 0.006, "rake": 55.0, "up": 0.0, "curve": 0.0, "base": (0.005, 0.008)},
            ],
            # The one pair at the shoulders, nearly half a metre each, out to the sides, curving back and a little up.
            "peaks": [{"at": ("Spine4", 0.8), "length": 0.45, "rake": 10.0, "up": 12.0, "curve": 0.3,
                       "base": (0.05, 0.095)}],
            "colour": (0.15, 0.105, 0.042),
            "rim": (0.065, 0.045, 0.02),
            "boss_colour": (0.2, 0.15, 0.065),
            "spike": (0.36, 0.3, 0.19),
            "tip": (0.08, 0.065, 0.045),
            "vary": 0.12,
        },
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.085, 0.15, 0.012), (0, -0.05, 0.115, 0.17, 0.02), (0, 0.3, 0.1, 0.14, 0.018),
                             (0, 0.7, 0.07, 0.085, 0.005), (0, 0.97, 0.058, 0.064, 0.0), (1, 0.15, 0.062, 0.082, -0.012),
                             (1, 0.45, 0.054, 0.065, -0.008), (1, 0.8, 0.044, 0.047, 0.0), (1, 0.97, 0.041, 0.043, 0.0),
                             (2, 0.25, 0.048, 0.034, 0.0), (2, 0.9, 0.054, 0.029, 0.0)],
                "around": 18,
                # Broad, flat, near hoof-like claws (an aetosaur's unguals).
                "digits": {"digits": [(-26.0, 0.07, 0.022, 0.026), (-9.0, 0.085, 0.024, 0.03), (8.0, 0.085, 0.024, 0.03),
                                      (25.0, 0.07, 0.021, 0.026)],
                           "flat": 0.6, "claw_curl": 0.25},
            },
            "fore": {
                "stations": [(0, -0.25, 0.07, 0.1, 0.0), (0, 0.05, 0.082, 0.104, 0.008), (0, 0.45, 0.066, 0.078, 0.01),
                             (0, 0.92, 0.052, 0.058, 0.0), (1, 0.15, 0.055, 0.064, 0.005), (1, 0.5, 0.047, 0.052, 0.002),
                             (1, 0.95, 0.038, 0.04, 0.0), (2, 0.3, 0.045, 0.03, 0.0), (2, 0.9, 0.05, 0.026, 0.0)],
                "around": 16,
                "digits": {"digits": [(-34.0, 0.05, 0.016, 0.02), (-17.0, 0.058, 0.017, 0.022), (0.0, 0.06, 0.017, 0.022),
                                      (17.0, 0.055, 0.016, 0.02), (34.0, 0.045, 0.014, 0.016)],
                           "flat": 0.6, "claw_curl": 0.4},
            },
        },
        # Small scales on its head and legs; under it square belly plates in rows (the scutes), as its kin had.
        "skin_detail": {"scales": {"cells": 110.0, "dorsal_size": 0.6, "groove": 0.34, "groove_dark": 0.28, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.002},
                        "scutes": {"size": (0.05, 0.045), "mortar": 0.08, "belly_below": -0.55, "flank_below": -0.3,
                                   "warp": 1.0},
                        # The plates and horns bare bone and horn: a fine grain, no scales, the bone pitted.
                        "horn": {"grain": 70.0, "relief": 0.2, "mottle": 0.18, "streak": 0.08,
                                 "pits": {"scale": 85.0, "size": 0.3, "depth": 0.6, "dark": 0.25}}},
        "texture": 2048,
        # Earthy: olive-brown skin, the plates a dull ochre, dark in their seams; the belly paler.
        "skin": {
            "back": (0.055, 0.038, 0.02),
            "flank": (0.16, 0.11, 0.055),
            "belly": (0.36, 0.28, 0.17),
            "throat": (0.38, 0.3, 0.19),
            "lips": (0.07, 0.055, 0.035),
            "mouth": (0.3, 0.1, 0.08),
            "claws": (0.06, 0.05, 0.035),
            "mottle": 0.18,
            "shank_dark": 0.25,
            # A horn-dark tip to the snout, where it roots.
            "beak": {"from": ("Head", 0.9), "colour": (0.05, 0.04, 0.028)},
        },
    },
}


# ==============================================================================
# Velociraptor mongoliensis: a dromaeosaur of the Late Cretaceous of Mongolia (the Djadokhta) -- a turkey-sized
# hunter, two metres long with its tail, the tail held stiff and straight by bony rods along it, a long low skull
# with a turned-up snout, and on each foot the second toe held up off the ground carrying a great sickle claw.
# Its forearm has quill knobs (Turner et al. 2007): it had wing feathers, and its kin a coat of feathers over the
# body and a fan down the tail -- scales on its feet and its face. (The later maps' pack.)


RAPTOR = {
    "config": "raptor",
    "height": 0.9,
    # After Norell & Makovicky (1999) and Scott Hartman's skeletal: skull 0.24 m, femur 0.17, tibia 0.24, a
    # short foot bone; the tail half the animal.
    "skeleton": {
        "hip_height": 0.44,
        "pelvis_length": 0.09,
        "pelvis_pitch": -8.0,
        "spine": [(0.15, 2.0), (0.15, 4.0), (0.13, 2.0)],
        "neck": [(0.055, 50.0), (0.055, 38.0), (0.05, 18.0), (0.05, -8.0)],
        "skull": (0.24, -12.0),
        "jaw": (0.22, 0.025, -15.0),
        "jaw_hinge": 0.08,
        # Stiff and straight: the bony rods along it let it swing only at its root.
        "tail": [(0.12, 6.0), (0.12, 2.0), (0.11, 0.0), (0.1, 0.0), (0.1, 0.0), (0.09, 0.0), (0.09, 0.0),
                 (0.08, 0.0), (0.08, 0.0), (0.07, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.17, 0.235, 0.09, 0.06],
                     "socket": (0.045, 0.0, -0.01), "stance": (0.005, 0.05), "foot": "digitigrade",
                     "foot_tilt": 20.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms folded as a bird's wings fold: the upper arm back, the forearm forward to the wrist by the
            # chest, the hand back along the flank.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.12, 0.11, 0.06, 0.07], "socket": (0.04, -0.015, -0.06), "arm": True,
                     "rest_hand": (0.05, 0.05, 0.0), "bend": "back", "splay": 10.0, "hand_angle": 172.0,
                     "finger_angle": 178.0, "hand_out": 0.1},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 0.5, "duty": 0.6, "step": 0.05, "bob": 0.008, "sway": 0.006, "hip_yaw": 2.5,
                 "hip_roll": 2.0, "tail_swing": 1.5, "neck_bob": 1.5, "steady": 0.8, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.005},
        # A run: level, the head low and forward, the stiff tail out behind as a counterweight.
        "run": {"period": 0.36, "duty": 0.35, "step": 0.09, "bob": 0.014, "lean": -5.0, "crouch": 0.02,
                "neck_pitch": -12.0, "tail_lift": 4.0, "head_pitch": 4.0, "tail_swing": 1.0, "steady": 0.85,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 3.5, "breaths": 2, "look": 30.0, "nod": 4.0, "swell": 0.025, "tail_swing": 2.0},
        "attack": {"period": 0.7, "jaw": 44.0, "lunge": 0.1, "draw": 16.0, "reach": 24.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.2, "roll": 86.0, "pivot": 0.07, "slide": 0.05},
        "sleep": {"period": 3.2, "drop": 0.3, "neck": [(-30.0, 8.0), (-25.0, 10.0), (-15.0, 10.0), (-5.0, 5.0)],
                  "head": (8.0, 10.0, 0.0), "tail": [(-10.0, 4.0), (3.0, 6.0)] + [(1.0, 6.0)] * 8, "tilt": 82.0},
    },
    "body": {
        "around": 40,
        "soften": 0.03,
        "rough": 0.008,
        "scale": 0.15,
        "throat": 0.3,
        "trunk": [
            # The skull: long and low, its top dipping behind the nostrils so the snout turns up a little.
            st("Head", 1.012, 0.007, 0.008, 0.007, step=0.003),
            st("Head", 1.0, 0.0105, 0.0115, 0.0105, step=0.004),
            st("Head", 0.96, 0.0125, 0.0138, 0.0125, step=0.006),
            st("Head", 0.88, 0.0145, 0.0138, 0.0148, step=0.008),
            st("Head", 0.78, 0.0158, 0.0125, 0.0172, step=0.01),
            st("Head", 0.64, 0.0195, 0.0155, 0.0215, step=0.01),
            st("Head", 0.5, 0.021, 0.02, 0.024, step=0.01),
            st("Head", 0.36, 0.029, 0.031, 0.032, lift=0.002, step=0.01),
            st("Head", 0.22, 0.037, 0.039, 0.042, step=0.01),
            st("Head", 0.08, 0.037, 0.038, 0.047, step=0.012),
            st("Head", -0.06, 0.032, 0.034, 0.044, step=0.014),
            # The neck: a feathered S, short and thick.
            st("Neck4", 0.5, 0.028, 0.031, 0.038, step=0.016),
            st("Neck3", 0.5, 0.034, 0.036, 0.044, step=0.018),
            st("Neck2", 0.5, 0.038, 0.04, 0.05, step=0.02),
            st("Neck1", 0.5, 0.044, 0.045, 0.06, step=0.02),
            st("Spine3", 0.7, 0.058, 0.052, 0.088, step=0.022),
            st("Spine3", 0.15, 0.072, 0.062, 0.125, n_bot=2.3, step=0.025),
            st("Spine2", 0.5, 0.08, 0.068, 0.14, n_bot=2.4, step=0.025),
            st("Spine1", 0.6, 0.078, 0.072, 0.122, n_bot=2.2, step=0.025),
            st("Spine1", 0.15, 0.073, 0.076, 0.1, step=0.025),
            st("Hips", 0.3, 0.076, 0.08, 0.088, keel=0.004, step=0.025),
            st("Hips", 0.9, 0.064, 0.071, 0.076, keel=0.004, step=0.025),
            st("Tail1", 0.5, 0.046, 0.054, 0.058, step=0.03),
            st("Tail2", 0.5, 0.036, 0.042, 0.044, step=0.03),
            st("Tail3", 0.5, 0.028, 0.033, 0.034, step=0.03),
            st("Tail4", 0.5, 0.022, 0.026, 0.026, step=0.03),
            st("Tail5", 0.5, 0.018, 0.021, 0.021, step=0.03),
            st("Tail6", 0.5, 0.015, 0.017, 0.017, step=0.03),
            st("Tail7", 0.5, 0.012, 0.014, 0.014, step=0.03),
            st("Tail8", 0.5, 0.01, 0.011, 0.011, step=0.03),
            st("Tail9", 0.5, 0.008, 0.009, 0.009, step=0.03),
            st("Tail10", 0.6, 0.006, 0.006, 0.006, step=0.03),
            st("Tail_end", 0.3, 0.003, 0.003, 0.003, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.003, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 15, "length": 0.008, "radius": 0.0019,
                  "colour": (0.78, 0.74, 0.64)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 14, "length": 0.006, "radius": 0.0016},
        "eyes": {"at": ("Head", 0.3), "phi": 52.0, "radius": 0.013, "sunk": 0.6, "forward": 18.0, "up": 8.0,
                 "iris": (0.6, 0.33, 0.03), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.32), "phi": 34.0, "size": 0.016, "height": 0.005},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.62), "phi": 70.0, "depth": 0.004, "width": 0.3},
        "nostrils": {"at": ("Head", 0.93), "phi": 48.0, "size": 0.0035},
        "limbs": {
            "hind": {
                "stations": [(0, -0.35, 0.024, 0.046, 0.004), (0, -0.08, 0.038, 0.066, 0.009), (0, 0.2, 0.042, 0.066, 0.01),
                             (0, 0.5, 0.036, 0.052, 0.007), (0, 0.8, 0.026, 0.034, 0.002), (0, 0.97, 0.021, 0.025, 0.0),
                             (1, 0.1, 0.023, 0.032, -0.006), (1, 0.3, 0.022, 0.032, -0.009), (1, 0.6, 0.016, 0.019, -0.004),
                             (1, 0.95, 0.0105, 0.0115, 0.0), (2, 0.1, 0.0095, 0.0095, 0.0), (2, 0.95, 0.0085, 0.008, 0.0)],
                "around": 16,
                "digits": {
                    # Two toes forward -- the third, the longest, and the fourth -- the second held up with its
                    # sickle claw, the small first one behind.
                    "digits": [(-2.0, 0.075, 0.0065, 0.015), (18.0, 0.065, 0.006, 0.013)],
                    "sickle": (-16.0, 0.04, 0.0065, 0.058, 38.0, 2.3),
                    "hallux": (150.0, 0.022, 0.0035, 0.009, 0.025),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.015, 0.022, 0.0), (0, 0.1, 0.018, 0.022, 0.002), (0, 0.45, 0.015, 0.018, 0.003),
                             (0, 0.95, 0.01, 0.011, 0.0), (1, 0.3, 0.011, 0.012, 0.001), (1, 0.95, 0.0075, 0.008, 0.0),
                             (2, 0.6, 0.0065, 0.005, 0.0)],
                "around": 12,
                "digits": {
                    "digits": [(0.0, 0.07, 0.0036, 0.018), (-14.0, 0.055, 0.0034, 0.016), (14.0, 0.045, 0.003, 0.014)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its feathers (tools/dino_feathers.py): wing feathers along the forearm and the hand, a fan down the
        # tail's far half, a coat over the body and the upper legs and arms -- the feet and the face scaled.
        "wings": {"forearm": 7, "hand": 7, "secondaries": (0.09, 0.13), "primaries": (0.14, 0.19), "width": 0.26,
                  "droop": 0.12, "splay": 0.18, "lift": 0.012, "curve": 0.1, "colour": (0.07, 0.042, 0.02),
                  "tip": (0.2, 0.13, 0.07)},
        "tail_fan": {"from": ("Tail4", 0.0), "length": (0.07, 0.16), "spread": (46.0, 12.0), "spacing": 0.02,
                     "width": 0.34, "droop": 0.05, "colour": (0.2, 0.11, 0.045), "tip": (0.03, 0.02, 0.012)},
        "coat": {"bones": ("Thigh", "Shin", "UpperArm", "Forearm"), "face": ("Head", 0.36), "bare": ("Head", 0.52)},
        "skin_detail": {"scales": {"cells": 170.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.0012},
                        "feathers": {"coat_cells": 95.0, "coat_stretch": 0.4, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.14, "barbs": 45.0, "slant": 0.7, "bars": 5.0, "bar_strength": 0.45,
                                     "bar_width": 0.35, "shaft": 0.08, "shaft_light": 0.4}},
        "texture": 2048,
        # Sand and dust: a dark brown back barred darker, tawny flanks, a cream belly, a dark mask through the eye.
        "skin": {
            "back": (0.06, 0.035, 0.018),
            "flank": (0.3, 0.16, 0.06),
            "belly": (0.42, 0.33, 0.2),
            "throat": (0.5, 0.42, 0.3),
            "lips": (0.12, 0.08, 0.05),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.06, 0.05, 0.04),
            "mottle": 0.16,
            "shank_dark": 0.3,
            "bands": {"colour": (0.02, 0.012, 0.006), "from": ("Spine2", 0.3), "to": ("Tail_end", 0.5),
                      "period": 0.09, "width": 0.3, "strength": 0.6},
            "eye_stripe": {"colour": (0.02, 0.012, 0.008), "from": ("Head", 1.0), "to": ("Neck4", 0.5),
                           "phi": 60.0, "width": 16.0},
        },
    },
}

# The pack's head: the same animal, painted apart -- near-black, rust along the flanks, its head flushed red, black
# wing and tail feathers tipped white, a crest down its neck (GAME-DESIGN 7.5). Shown bigger
# (Config.DINOS.raptor_alpha.size).
RAPTOR_ALPHA = {
    "same_as": "velociraptor",
    "config": "raptor_alpha",
    "body": {
        "wings": {"colour": (0.012, 0.012, 0.012), "tip": (0.62, 0.6, 0.56)},
        "tail_fan": {"colour": (0.015, 0.013, 0.012), "tip": (0.62, 0.6, 0.56)},
        "plumes": {"from": ("Head", 0.25), "to": ("Neck1", 0.5), "rows": [0.0, 22.0], "length": (0.03, 0.06),
                   "spacing": 0.018, "rise": 0.5, "width": 0.22, "colour": (0.35, 0.05, 0.02), "tip": (0.015, 0.013, 0.012)},
        "skin": {
            "back": (0.018, 0.015, 0.013),
            "flank": (0.16, 0.06, 0.022),
            "belly": (0.45, 0.35, 0.24),
            "throat": (0.5, 0.36, 0.26),
            "bands": {"colour": (0.008, 0.006, 0.005), "strength": 0.75},
            "flush": {"colour": (0.45, 0.07, 0.03), "from": ("Head", 1.0), "to": ("Neck2", 0.5), "strength": 0.65},
        },
    },
}


# ==============================================================================
# Tyrannosaurus rex: the Late Cretaceous of western North America (the Hell Creek) -- twelve metres of it, a skull a
# metre and a half long, broad behind the eyes so both of them look forward, teeth the size of bananas, a short
# thick neck, tiny two-fingered arms, legs of a runner grown huge, a tail as long as the rest. Its skin, where it
# was preserved, is small pebbly scales (Bell et al. 2017). The run's climax (GAME-DESIGN 7.4).


TREX = {
    "config": "big_theropod",
    "height": 3.0,
    # After "Sue" (FMNH PR 2081) and Scott Hartman's skeletal: skull 1.4 m, femur 1.3, tibia 1.2, foot bone 0.65.
    "skeleton": {
        "hip_height": 3.0,
        "pelvis_length": 0.9,
        "pelvis_pitch": -6.0,
        "spine": [(0.8, 2.0), (0.8, -2.0), (0.75, -6.0), (0.65, -10.0)],
        "neck": [(0.35, 30.0), (0.35, 20.0), (0.3, 5.0)],
        "skull": (1.45, -10.0),
        "jaw": (1.35, 0.25, -14.0),
        "jaw_hinge": 0.05,
        "tail": [(0.6, 4.0), (0.58, 0.0), (0.55, -2.0), (0.52, -2.0), (0.48, -2.0), (0.44, -1.0), (0.4, -1.0),
                 (0.36, 0.0), (0.32, 0.0), (0.28, 0.0), (0.24, 0.0), (0.2, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [1.3, 1.2, 0.65, 0.35],
                     "socket": (0.45, 0.0, -0.1), "stance": (0.02, 0.25), "foot": "digitigrade",
                     "foot_tilt": 25.0, "roll_tilt": 35.0, "bend": "forward", "splay": 3.0},
            # The arms: small, and held close under the chest.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.38, 0.22, 0.1, 0.1], "socket": (0.35, -0.1, -0.6), "arm": True,
                     "rest_hand": (0.05, 0.2, -0.35), "bend": "back", "splay": 15.0},
        },
    },
    "moves": {
        "plan": "biped",
        # A heavy walk: the body rolling over each foot, the head steady, the tail swinging against the hips.
        "walk": {"period": 1.3, "duty": 0.62, "step": 0.15, "bob": 0.04, "sway": 0.03, "hip_yaw": 3.0,
                 "hip_roll": 2.5, "tail_swing": 3.0, "neck_bob": 2.0, "steady": 0.8, "narrow": 0.9, "push": 0.5,
                 "curl": 0.4, "arm_swing": 0.01},
        "run": {"period": 0.9, "duty": 0.45, "step": 0.22, "bob": 0.06, "lean": -4.0, "crouch": 0.06,
                "neck_pitch": -8.0, "tail_lift": 3.0, "head_pitch": 3.0, "tail_swing": 2.0, "steady": 0.85,
                "narrow": 0.85, "push": 0.8},
        "idle": {"period": 5.0, "breaths": 2, "look": 18.0, "nod": 3.0, "swell": 0.02, "tail_swing": 3.0},
        # A bite from above: the head drawn up and back, then driven down and forward, the jaws slamming shut.
        "attack": {"period": 1.1, "jaw": 38.0, "lunge": 0.35, "draw": 14.0, "reach": 18.0, "head_up": 10.0,
                   "head_down": 14.0},
        "death": {"period": 1.8, "roll": 84.0, "pivot": 0.55, "slide": 0.2},
    },
    "body": {
        "around": 44,
        "soften": 0.06,
        "rough": 0.03,
        "scale": 1.2,
        "throat": 0.35,
        "trunk": [
            # The skull: deep, the snout narrow, the back of it broad -- both eyes look forward past the snout.
            st("Head", 1.01, 0.11, 0.12, 0.11, step=0.02),
            st("Head", 0.98, 0.17, 0.23, 0.2, step=0.03),
            st("Head", 0.9, 0.19, 0.28, 0.25, step=0.05),
            st("Head", 0.75, 0.21, 0.3, 0.29, step=0.06),
            st("Head", 0.58, 0.26, 0.34, 0.32, step=0.06),
            st("Head", 0.42, 0.33, 0.38, 0.36, step=0.06),
            st("Head", 0.28, 0.42, 0.42, 0.42, lift=0.02, step=0.06),
            st("Head", 0.14, 0.48, 0.42, 0.46, step=0.06),
            st("Head", 0.02, 0.46, 0.38, 0.48, step=0.08),
            st("Head", -0.08, 0.38, 0.34, 0.46, step=0.08),
            # The neck: short, thick with muscle.
            st("Neck3", 0.5, 0.3, 0.32, 0.42, step=0.1),
            st("Neck2", 0.5, 0.34, 0.36, 0.48, step=0.1),
            st("Neck1", 0.5, 0.4, 0.42, 0.56, step=0.1),
            st("Spine4", 0.6, 0.5, 0.45, 0.7, step=0.12),
            st("Spine4", 0.1, 0.6, 0.5, 0.95, n_bot=2.3, step=0.12),
            st("Spine3", 0.5, 0.68, 0.55, 1.05, n_bot=2.4, step=0.12),
            st("Spine2", 0.5, 0.7, 0.58, 1.0, n_bot=2.3, step=0.12),
            st("Spine1", 0.5, 0.66, 0.6, 0.85, step=0.12),
            st("Hips", 0.3, 0.6, 0.62, 0.7, keel=0.03, step=0.12),
            st("Hips", 0.9, 0.5, 0.58, 0.6, keel=0.03, step=0.12),
            # The tail: deep with the muscle that pulls the legs back, tapering to a point.
            st("Tail1", 0.5, 0.42, 0.52, 0.55, step=0.14),
            st("Tail2", 0.5, 0.36, 0.45, 0.46, step=0.14),
            st("Tail3", 0.5, 0.3, 0.38, 0.38, step=0.14),
            st("Tail4", 0.5, 0.25, 0.32, 0.3, step=0.14),
            st("Tail5", 0.5, 0.2, 0.26, 0.24, step=0.14),
            st("Tail6", 0.5, 0.16, 0.21, 0.19, step=0.14),
            st("Tail7", 0.5, 0.13, 0.17, 0.15, step=0.12),
            st("Tail8", 0.5, 0.1, 0.13, 0.11, step=0.12),
            st("Tail9", 0.5, 0.075, 0.1, 0.085, step=0.1),
            st("Tail10", 0.5, 0.055, 0.07, 0.06, step=0.1),
            st("Tail11", 0.5, 0.035, 0.045, 0.04, step=0.08),
            st("Tail12", 0.6, 0.02, 0.025, 0.022, step=0.06),
            st("Tail_end", 0.3, 0.008, 0.008, 0.008, step=0.03),
        ],
        "mouth": {"from": ("Head", 0.06), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.03, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.28), "to": ("Head", 0.97), "count": 13, "length": 0.11, "radius": 0.026,
                  "colour": (0.72, 0.66, 0.52)},
        "lower_teeth": {"from": ("Head", 0.28), "to": ("Head", 0.94), "count": 12, "length": 0.085, "radius": 0.022},
        "eyes": {"at": ("Head", 0.26), "phi": 40.0, "radius": 0.045, "sunk": 0.6, "forward": 30.0, "up": 10.0,
                 "iris": (0.55, 0.36, 0.06), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        # The bony bosses over the eyes, and the rough ridges down the snout.
        "brow": {"at": ("Head", 0.28), "phi": 24.0, "size": 0.14, "height": 0.06},
        "mounds": [{"at": ("Head", 0.62), "phi": 8.0, "size": 0.16, "height": 0.03}],
        "fossa": {"from": ("Head", 0.4), "to": ("Head", 0.62), "phi": 70.0, "depth": 0.03, "width": 0.3},
        "nostrils": {"at": ("Head", 0.95), "phi": 42.0, "size": 0.035},
        "limbs": {
            "hind": {
                "stations": [(0, -0.35, 0.32, 0.55, 0.05), (0, -0.05, 0.42, 0.62, 0.07), (0, 0.25, 0.42, 0.58, 0.07),
                             (0, 0.55, 0.34, 0.44, 0.04), (0, 0.85, 0.24, 0.28, 0.01), (0, 0.98, 0.2, 0.22, 0.0),
                             (1, 0.1, 0.2, 0.27, -0.05), (1, 0.3, 0.19, 0.27, -0.07), (1, 0.6, 0.14, 0.17, -0.03),
                             (1, 0.95, 0.1, 0.1, 0.0), (2, 0.1, 0.095, 0.085, 0.0), (2, 0.95, 0.085, 0.07, 0.0)],
                "around": 18,
                "digits": {
                    # Three great toes on the ground, the small first one behind.
                    "digits": [(-18.0, 0.42, 0.06, 0.12), (0.0, 0.5, 0.065, 0.13), (18.0, 0.42, 0.06, 0.12)],
                    "hallux": (150.0, 0.15, 0.03, 0.06, 0.2),
                    "flat": 0.8,
                    "claw_curl": 0.6,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.07, 0.09, 0.0), (0, 0.1, 0.08, 0.09, 0.01), (0, 0.5, 0.065, 0.075, 0.01),
                             (0, 0.95, 0.045, 0.05, 0.0), (1, 0.3, 0.045, 0.05, 0.0), (1, 0.95, 0.035, 0.035, 0.0),
                             (2, 0.6, 0.032, 0.025, 0.0)],
                "around": 12,
                "digits": {
                    # Two fingers.
                    "digits": [(-8.0, 0.12, 0.018, 0.06), (10.0, 0.1, 0.016, 0.05)],
                    "claw_curl": 1.0,
                    "flat": 0.9,
                },
            },
        },
        # Small pebbly scales, bigger over the back.
        "skin_detail": {"scales": {"cells": 40.0, "dorsal_size": 0.5, "groove": 0.36, "groove_dark": 0.28, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.8, "depth": 0.012}},
        "texture": 2048,
        # Dark brown-grey over the back, olive-brown flanks, a paler belly; faint darker stripes across the back.
        "skin": {
            "back": (0.035, 0.03, 0.022),
            "flank": (0.14, 0.1, 0.06),
            "belly": (0.36, 0.3, 0.2),
            "throat": (0.4, 0.33, 0.22),
            "lips": (0.06, 0.045, 0.03),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.03, 0.025, 0.02),
            "mottle": 0.2,
            "shank_dark": 0.3,
            "bands": {"colour": (0.015, 0.012, 0.009), "from": ("Spine3", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.45, "width": 0.25, "strength": 0.4},
        },
    },
}


# ==============================================================================
# An azhdarchid pterosaur (Quetzalcoatlus lawsoni's build): not a dinosaur -- a flying reptile, and the azhdarchids
# stalked the ground on all fours like storks (Witton & Naish 2008), wings folded: a skull longer than the body, a
# toothless beak, a long stiff neck held up, a short body, the forelimbs far longer than the hind -- standing on
# three small fingers, the fourth, the wing finger, folded up alongside the arm, its tip over the back -- the body
# furred with pycnofibres. (GAME-DESIGN 7.2: "大型神龙翼龙类……像鹳一样在地上走着捕猎".)


PTEROSAUR = {
    "height": 2.2,
    "skeleton": {
        "hip_height": 0.62,
        "pelvis_length": 0.1,
        "pelvis_pitch": -10.0,
        # The body short, and steep: the shoulders on the long forelimbs well above the hips.
        "spine": [(0.14, 40.0), (0.14, 45.0), (0.12, 40.0)],
        "neck": [(0.22, 60.0), (0.22, 55.0), (0.2, 45.0), (0.18, 30.0)],
        "skull": (0.85, -40.0),
        "jaw": (0.8, 0.02, -43.0),
        "jaw_hinge": 0.05,
        "tail": [(0.05, -30.0), (0.04, -30.0), (0.03, -30.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.3, 0.38, 0.12, 0.07],
                     "socket": (0.06, 0.0, -0.03), "stance": (0.05, 0.02), "foot": "plantigrade", "heel": 15.0,
                     "roll_tilt": 40.0, "bend": "forward", "splay": 8.0},
            # The upper arm, the forearm, the long hand bone standing near upright, the three small fingers on
            # the ground -- and the wing finger folded back up from the knuckle.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.22, 0.38, 0.48, 0.06], "socket": (0.08, 0.0, -0.05), "stance": (0.12, 0.1),
                     "foot": "digitigrade", "foot_tilt": 12.0, "roll_tilt": 25.0, "bend": "back", "splay": 20.0,
                     "wing_finger": {"lengths": [0.45, 0.35, 0.25, 0.15], "out": 0.05, "sweep": 0.35, "clear": 0.025}},
        },
    },
    "moves": {
        "plan": "quadruped",
        # A stalking walk, the head held high and steady -- a stork's.
        "walk": {"period": 0.9, "duty": 0.7, "step": 0.05, "bob": 0.015, "snake": 2.0, "tail_swing": 1.0,
                 "order": "walk", "steady": 0.9, "push": 0.5, "curl": 0.3, "hip_roll": 2.0},
        "run": {"period": 0.5, "duty": 0.45, "step": 0.08, "bob": 0.03, "snake": 1.5, "tail_swing": 1.0,
                "order": "trot", "lead": 0.1, "steady": 0.9, "push": 0.8, "curl": 0.4},
        "idle": {"period": 4.0, "breaths": 2, "look": 30.0, "nod": 5.0, "swell": 0.02, "tail_swing": 1.0, "heave": 0.004},
        # A stab: the beak drawn up, then driven down at what is on the ground.
        "attack": {"period": 0.8, "jaw": 25.0, "lunge": 0.15, "draw": 20.0, "reach": 30.0, "head_up": 15.0,
                   "head_down": 25.0, "spine_dip": 4.0, "dip": 0.02},
        "death": {"period": 1.3, "roll": 86.0, "pivot": 0.12, "slide": 0.05, "limp_forward": 0.08, "limp_up": 0.08},
    },
    "body": {
        "around": 36,
        "soften": 0.03,
        "rough": 0.004,
        "scale": 0.3,
        "throat": 0.2,
        "trunk": [
            # The skull: a long spear of a beak, a low crest over the back of it.
            st("Head", 1.012, 0.003, 0.003, 0.003, step=0.004),
            st("Head", 0.98, 0.007, 0.008, 0.006, step=0.01),
            st("Head", 0.9, 0.012, 0.014, 0.011, step=0.02),
            st("Head", 0.75, 0.019, 0.022, 0.018, step=0.025),
            st("Head", 0.58, 0.027, 0.032, 0.026, step=0.025),
            st("Head", 0.4, 0.036, 0.046, 0.034, step=0.02),
            st("Head", 0.25, 0.046, 0.06, 0.042, step=0.02),
            st("Head", 0.12, 0.052, 0.066, 0.048, step=0.02),
            st("Head", 0.0, 0.048, 0.056, 0.048, step=0.02),
            st("Head", -0.08, 0.04, 0.044, 0.044, step=0.02),
            # The neck: long, stiff, slender.
            st("Neck4", 0.5, 0.034, 0.035, 0.04, step=0.03),
            st("Neck3", 0.5, 0.037, 0.037, 0.043, step=0.03),
            st("Neck2", 0.5, 0.041, 0.04, 0.048, step=0.03),
            st("Neck1", 0.5, 0.05, 0.046, 0.056, step=0.03),
            st("Spine3", 0.7, 0.08, 0.07, 0.1, step=0.03),
            st("Spine3", 0.2, 0.11, 0.09, 0.14, n_bot=2.2, step=0.03),
            st("Spine2", 0.5, 0.12, 0.1, 0.15, n_bot=2.3, step=0.03),
            st("Spine1", 0.5, 0.1, 0.095, 0.12, step=0.03),
            st("Hips", 0.3, 0.085, 0.085, 0.09, step=0.03),
            st("Hips", 0.9, 0.06, 0.07, 0.06, step=0.03),
            st("Tail1", 0.5, 0.03, 0.03, 0.03, step=0.02),
            st("Tail2", 0.5, 0.018, 0.018, 0.018, step=0.02),
            st("Tail3", 0.6, 0.008, 0.008, 0.008, step=0.02),
            st("Tail_end", 0.3, 0.003, 0.003, 0.003, step=0.01),
        ],
        # The beak's edge: no teeth.
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 100.0, "depth": 0.003, "width": 0.1, "band": 3.0},
        "eyes": {"at": ("Head", 0.1), "phi": 50.0, "radius": 0.018, "sunk": 0.6, "forward": 12.0, "up": 6.0,
                 "iris": (0.5, 0.33, 0.08), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.12), "phi": 30.0, "size": 0.03, "height": 0.008},
        # The crest: low and bony, along the top of the skull.
        "mounds": [{"at": ("Head", 0.22), "phi": 0.0, "size": 0.09, "height": 0.07}],
        "nostrils": {"at": ("Head", 0.62), "phi": 40.0, "size": 0.006},
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.03, 0.045, 0.005), (0, 0.0, 0.04, 0.05, 0.008), (0, 0.4, 0.032, 0.036, 0.004),
                             (0, 0.95, 0.02, 0.022, 0.0), (1, 0.2, 0.021, 0.025, -0.004), (1, 0.6, 0.015, 0.017, -0.002),
                             (1, 0.96, 0.012, 0.012, 0.0), (2, 0.2, 0.014, 0.01, 0.0), (2, 0.9, 0.016, 0.008, 0.0)],
                "around": 12,
                "digits": {"digits": [(-20.0, 0.05, 0.006, 0.012), (-7.0, 0.058, 0.0065, 0.013), (7.0, 0.058, 0.0065, 0.013),
                                      (20.0, 0.05, 0.006, 0.012)],
                           "flat": 0.7, "claw_curl": 0.6},
            },
            "fore": {
                "stations": [(0, -0.2, 0.035, 0.045, 0.0), (0, 0.1, 0.04, 0.045, 0.005), (0, 0.5, 0.03, 0.032, 0.004),
                             (0, 0.95, 0.022, 0.024, 0.0), (1, 0.2, 0.024, 0.026, 0.002), (1, 0.6, 0.018, 0.019, 0.0),
                             (1, 0.97, 0.016, 0.016, 0.0), (2, 0.1, 0.014, 0.014, 0.0), (2, 0.95, 0.012, 0.012, 0.0)],
                "around": 12,
                "digits": {"digits": [(-24.0, 0.05, 0.005, 0.015), (0.0, 0.055, 0.005, 0.016), (24.0, 0.05, 0.005, 0.015)],
                           "claw_curl": 1.0, "flat": 0.9},
            },
        },
        # The folded wing (tools/dino_body.py _membranes): the membrane dark, the finger's bone showing along it.
        "membrane": {"colour": (0.05, 0.035, 0.03), "bone": (0.1, 0.085, 0.07), "rows": 14, "fold": 0.03,
                     "sag": 0.015, "finger": 0.012, "to": "shoulder"},
        # Its fur (pycnofibres) over the body, the neck, the back of the head and the upper limbs.
        "coat": {"bones": ("Thigh", "UpperArm", "Forearm"), "face": ("Head", 0.18), "bare": ("Head", 0.3)},
        "skin_detail": {"scales": {"cells": 150.0, "dorsal_size": 0.6, "groove": 0.36, "groove_dark": 0.22, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.5, "depth": 0.0008},
                        "feathers": {"coat_cells": 220.0, "coat_stretch": 0.3, "coat_groove": 0.4, "coat_tint": 0.08,
                                     "streak": 0.2}},
        "texture": 1024,
        # A stork's colours: pale grey and white, darker over the back, dark wings, the head flushed red about its
        # crest, a horn-coloured beak.
        "skin": {
            "back": (0.12, 0.12, 0.12),
            "flank": (0.42, 0.42, 0.4),
            "belly": (0.62, 0.62, 0.58),
            "throat": (0.6, 0.58, 0.52),
            "lips": (0.1, 0.08, 0.05),
            "mouth": (0.3, 0.08, 0.06),
            "claws": (0.03, 0.03, 0.03),
            "mottle": 0.1,
            "shank_dark": 0.4,
            "beak": {"from": ("Head", 0.45), "colour": (0.32, 0.27, 0.17)},
            "flush": {"colour": (0.5, 0.08, 0.03), "from": ("Head", 0.45), "to": ("Neck4", 0.5), "strength": 0.7},
        },
    },
}


# ==============================================================================
# THE SECOND MAP'S CAST (GAME-DESIGN 7.2, station 2: the Late Jurassic of the American West, the Morrison
# Formation, about 150 million years ago -- the sauropods' golden age). Built at the size the game shows each
# (its "height", head and all; the herds' by their "length"), so a clip's stride is the game's pace as built.
# ==============================================================================

# Ornitholestes hermanni ("Hermann's bird-robber", Osborn 1903; AMNH 619, Bone Cabin Quarry): a small coelurosaur
# -- two metres of it with its tail, a coyote's weight -- a short, deep, blunt skull, a long S of a neck, long arms
# ending in big grasping hands of three fingers, the first finger's claw the biggest; long legs, a long tail. A
# coelurosaur, of the line that is feathered wherever the rock keeps feathers: drawn as the Velociraptor is -- a
# coat of feathers over the body, the neck, the thighs and the upper arms, the face and the feet in scales -- but
# with a basal coelurosaur's short feathers, a fringe along the forearm and the tail, not a raptor's wings. The
# pack that raids, and the nest's guards (the Coelophysis's part on the first map).


ORNITHOLESTES = {
    "height": 0.83,
    # After Carpenter et al. (2005) and Scott Hartman's skeletal: skull 0.15 m, femur 0.21, tibia 0.23, the long
    # foot bone 0.125; the hand nearly as long as the forearm.
    "skeleton": {
        "hip_height": 0.51,
        "pelvis_length": 0.11,
        "pelvis_pitch": -6.0,
        "spine": [(0.15, 6.0), (0.15, 9.0), (0.13, 5.0)],
        "neck": [(0.104, 66.0), (0.098, 58.0), (0.088, 38.0), (0.074, 8.0)],
        "skull": (0.15, -12.0),
        "jaw": (0.138, 0.024, -17.0),
        "jaw_hinge": 0.08,
        "tail": [(0.1, 7.0), (0.1, 3.0), (0.095, 0.0), (0.09, -1.0), (0.09, -1.0), (0.085, -1.0), (0.08, 0.0),
                 (0.075, 0.0), (0.07, 0.0), (0.065, 0.0), (0.06, 0.0), (0.05, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.21, 0.23, 0.125, 0.07],
                     "socket": (0.05, 0.0, -0.01), "stance": (0.008, 0.06), "foot": "digitigrade",
                     "foot_tilt": 22.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms folded before the chest, the big hands hanging, palms in.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.1, 0.085, 0.045, 0.055], "socket": (0.04, -0.015, -0.065), "arm": True,
                     "rest_hand": (0.028, 0.07, -0.08), "bend": "back", "splay": 12.0, "hand_angle": 58.0,
                     "finger_angle": 100.0},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 0.46, "duty": 0.6, "step": 0.055, "bob": 0.009, "sway": 0.007, "hip_yaw": 3.0,
                 "hip_roll": 2.0, "tail_swing": 3.0, "neck_bob": 1.5, "steady": 0.7, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.008},
        "run": {"period": 0.36, "duty": 0.35, "step": 0.09, "bob": 0.014, "lean": -6.0, "crouch": 0.02,
                "neck_pitch": -16.0, "tail_lift": 6.0, "head_pitch": 6.0, "tail_swing": 2.0, "steady": 0.8,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 3.6, "breaths": 2, "look": 30.0, "nod": 4.0, "swell": 0.025, "tail_swing": 3.0},
        "attack": {"period": 0.7, "jaw": 44.0, "lunge": 0.09, "draw": 18.0, "reach": 26.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.2, "roll": 86.0, "pivot": 0.07, "slide": 0.05},
        # Asleep, belly down, its neck laid forward and down and turned a little aside, the head flat on the
        # ground.
        "sleep": {"period": 3.2, "drop": 0.38, "neck": [(-61.0, 8.0), (-7.0, 10.0), (10.0, 10.0), (35.0, 5.0)],
                  "head": (30.0, 10.0, 0.0), "tail": [(-14.0, 6.0), (4.0, 9.0)] + [(1.5, 9.0)] * 10, "tilt": 82.0},
    },
    "body": {
        "around": 40,
        "soften": 0.03,
        "rough": 0.008,
        "scale": 0.13,
        "throat": 0.3,
        # The snout's point just past its last ring -- a blunt snout, not a needle.
        "tips": (0.004, 0.01),
        "trunk": [
            # The skull: short, deep and blunt for a small theropod's, rounded over the snout; big orbits; the
            # jaw muscles swelling it behind them.
            st("Head", 1.008, 0.0085, 0.0095, 0.0085, step=0.003),
            st("Head", 0.995, 0.0125, 0.0158, 0.0145, step=0.004),
            st("Head", 0.965, 0.0142, 0.0198, 0.0182, step=0.005),
            st("Head", 0.9, 0.0152, 0.0222, 0.0202, step=0.006),
            st("Head", 0.8, 0.0164, 0.0242, 0.0218, step=0.007),
            st("Head", 0.68, 0.0176, 0.0258, 0.0232, step=0.008),
            st("Head", 0.55, 0.0202, 0.029, 0.0258, step=0.008),
            st("Head", 0.42, 0.0242, 0.032, 0.0286, step=0.008),
            st("Head", 0.3, 0.0282, 0.0334, 0.0312, lift=0.002, step=0.008),
            st("Head", 0.18, 0.0312, 0.0322, 0.0342, step=0.008),
            st("Head", 0.06, 0.0298, 0.0292, 0.0348, step=0.01),
            st("Head", -0.08, 0.0255, 0.0245, 0.0315, step=0.012),
            # The neck: a feathered S.
            st("Neck4", 0.5, 0.0238, 0.0248, 0.0312, step=0.014),
            st("Neck3", 0.5, 0.0262, 0.0268, 0.0342, step=0.015),
            st("Neck2", 0.5, 0.0292, 0.0296, 0.0382, step=0.016),
            st("Neck1", 0.5, 0.0352, 0.0342, 0.0465, step=0.018),
            # The body: a deep chest over the arms, a slimmer waist, the hips broad over the thighs.
            st("Spine3", 0.7, 0.046, 0.039, 0.065, step=0.02),
            st("Spine3", 0.15, 0.06, 0.048, 0.105, n_bot=2.3, step=0.022),
            st("Spine2", 0.5, 0.068, 0.056, 0.121, n_bot=2.4, step=0.022),
            st("Spine1", 0.6, 0.066, 0.058, 0.101, n_bot=2.2, step=0.022),
            st("Spine1", 0.15, 0.066, 0.063, 0.086, step=0.022),
            st("Hips", 0.3, 0.074, 0.068, 0.077, keel=0.004, step=0.022),
            st("Hips", 0.9, 0.061, 0.062, 0.068, keel=0.004, step=0.022),
            # The tail: deep at its root with the muscle that pulls the legs back, then long and slender.
            st("Tail1", 0.5, 0.043, 0.049, 0.055, step=0.025),
            st("Tail2", 0.5, 0.034, 0.039, 0.042, step=0.025),
            st("Tail3", 0.5, 0.027, 0.031, 0.032, step=0.03),
            st("Tail4", 0.5, 0.0215, 0.0245, 0.0245, step=0.03),
            st("Tail5", 0.5, 0.0175, 0.0198, 0.0196, step=0.03),
            st("Tail6", 0.5, 0.0142, 0.0162, 0.0158, step=0.03),
            st("Tail7", 0.5, 0.0115, 0.0132, 0.0128, step=0.03),
            st("Tail8", 0.5, 0.0092, 0.0106, 0.0102, step=0.03),
            st("Tail9", 0.5, 0.0073, 0.0083, 0.008, step=0.03),
            st("Tail10", 0.5, 0.0057, 0.0064, 0.0062, step=0.03),
            st("Tail11", 0.5, 0.0043, 0.0047, 0.0046, step=0.025),
            st("Tail12", 0.6, 0.003, 0.0032, 0.0032, step=0.02),
            st("Tail_end", 0.3, 0.0013, 0.0013, 0.0013, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 106.0, "depth": 0.0022, "width": 0.1, "band": 3.0},
        # Conical teeth at the front of the snout, blades behind them.
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 13, "length": 0.0062, "radius": 0.0016,
                  "colour": (0.8, 0.76, 0.66)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.94), "count": 12, "length": 0.0048, "radius": 0.0014},
        "eyes": {"at": ("Head", 0.32), "phi": 54.0, "radius": 0.0085, "sunk": 0.6, "forward": 18.0, "up": 8.0,
                 "iris": (0.55, 0.3, 0.06), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.34), "phi": 34.0, "size": 0.012, "height": 0.004},
        "fossa": {"from": ("Head", 0.44), "to": ("Head", 0.66), "phi": 70.0, "depth": 0.0028, "width": 0.3},
        "nostrils": {"at": ("Head", 0.94), "phi": 48.0, "size": 0.0028},
        "limbs": {
            "hind": {
                # Its top inside the hips, so the thigh comes out of the flank rather than standing on it.
                "stations": [(0, -0.3, 0.013, 0.03, 0.004), (0, -0.06, 0.026, 0.056, 0.008), (0, 0.2, 0.033, 0.058, 0.009),
                             (0, 0.5, 0.03, 0.046, 0.006), (0, 0.8, 0.022, 0.029, 0.002), (0, 0.97, 0.019, 0.022, 0.0),
                             (1, 0.1, 0.019, 0.027, -0.005), (1, 0.3, 0.018, 0.027, -0.008), (1, 0.6, 0.013, 0.016, -0.004),
                             (1, 0.95, 0.009, 0.01, 0.0), (2, 0.1, 0.008, 0.008, 0.0), (2, 0.95, 0.0072, 0.0068, 0.0)],
                "around": 16,
                "digits": {
                    "digits": [(0.0, 0.07, 0.0055, 0.016), (-18.0, 0.055, 0.0051, 0.015), (18.0, 0.05, 0.005, 0.014)],
                    "hallux": (150.0, 0.022, 0.0032, 0.009, 0.026),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.014, 0.02, 0.0), (0, 0.1, 0.0165, 0.02, 0.002), (0, 0.45, 0.0135, 0.016, 0.003),
                             (0, 0.95, 0.0095, 0.0105, 0.0), (1, 0.3, 0.0102, 0.0115, 0.001), (1, 0.95, 0.0072, 0.0078, 0.0),
                             (2, 0.6, 0.0068, 0.0052, 0.0)],
                "around": 12,
                # Three long fingers, the first (the inner) the shortest with the biggest claw -- a grasping hand.
                "digits": {
                    "digits": [(-15.0, 0.04, 0.0038, 0.021), (0.0, 0.056, 0.0036, 0.018), (15.0, 0.047, 0.0032, 0.015)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its feathers (tools/dino_feathers.py): a fringe of short ones down the back of each forearm, a fringe out
        # either side of the tail's far half, the coat over the body, the neck, the thighs and the upper arms --
        # the face to behind the eyes, the shins, the feet and the hands in scales.
        "wings": {"forearm": 6, "hand": 0, "secondaries": (0.03, 0.05), "primaries": (0.05, 0.05), "width": 0.3,
                  "droop": 0.3, "splay": 0.1, "lift": 0.005, "curve": 0.12, "colour": (0.24, 0.12, 0.05),
                  "tip": (0.05, 0.034, 0.022)},
        "tail_fan": {"from": ("Tail5", 0.0), "length": (0.045, 0.1), "spread": (58.0, 16.0), "spacing": 0.015,
                     "width": 0.3, "droop": 0.06, "colour": (0.05, 0.034, 0.022), "tip": (0.55, 0.49, 0.38)},
        "coat": {"bones": ("Thigh", "UpperArm"), "face": ("Head", 0.3), "bare": ("Head", 0.46)},
        "skin_detail": {"scales": {"cells": 210.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.001},
                        "feathers": {"coat_cells": 120.0, "coat_stretch": 0.4, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.16, "barbs": 40.0, "slant": 0.7, "bars": 3.0, "bar_strength": 0.3,
                                     "bar_width": 0.35, "shaft": 0.08, "shaft_light": 0.4}},
        "texture": 2048,
        # A dark grey-brown back, rufous flanks, a cream belly and throat; a dark mask through the eye, and the tail
        # ringed dark and pale to its tip.
        "skin": {
            "back": (0.05, 0.035, 0.024),
            "flank": (0.33, 0.165, 0.06),
            "belly": (0.62, 0.55, 0.42),
            "throat": (0.66, 0.6, 0.48),
            "lips": (0.14, 0.09, 0.06),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.07, 0.055, 0.045),
            "mottle": 0.14,
            "shank_dark": 0.35,
            "bands": {"colour": (0.03, 0.02, 0.012), "from": ("Tail2", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.1, "width": 0.36, "strength": 0.8},
            "eye_stripe": {"colour": (0.03, 0.02, 0.012), "from": ("Head", 0.97), "to": ("Neck4", 0.6),
                           "phi": 60.0, "width": 15.0},
        },
    },
}


# Ceratosaurus nasicornis ("the horned lizard", Marsh 1884; USNM 4735): the Morrison's other big hunter, a ceratosaur
# -- six metres of it, a deep skull with a blade of a horn over its nostrils and a hornlet over each eye, upper teeth
# as long as a man's fingers in a lower jaw deep enough to sheathe them, a strong neck, short arms with four stubby
# fingers, a deep narrow tail; and alone among the big theropods, a row of small bony plates (osteoderms) down the
# middle of its back from the neck along the tail (Gilmore 1920). Otherwise scaled. The second map's minor boss: at
# the head of every big wave.


CERATOSAURUS = {
    "height": 2.0,
    # After Gilmore (1920) and Scott Hartman's skeletal, at six metres: skull 0.62 m, femur 0.66, tibia 0.56, the
    # long foot bone 0.28; the arm short, the forearm half the upper arm.
    "skeleton": {
        "hip_height": 1.55,
        "pelvis_length": 0.4,
        "pelvis_pitch": -6.0,
        "spine": [(0.4, 3.0), (0.4, 0.0), (0.38, -3.0), (0.34, -6.0)],
        "neck": [(0.21, 53.0), (0.2, 43.0), (0.18, 22.0), (0.16, -4.0)],
        "skull": (0.62, -12.0),
        "jaw": (0.58, 0.11, -15.0),
        "jaw_hinge": 0.06,
        "tail": [(0.3, 5.0), (0.3, 1.0), (0.28, -1.0), (0.27, -2.0), (0.25, -2.0), (0.23, -1.0), (0.21, -1.0),
                 (0.19, 0.0), (0.17, 0.0), (0.15, 0.0), (0.13, 0.0), (0.11, 0.0), (0.09, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.66, 0.56, 0.28, 0.18],
                     "socket": (0.17, 0.0, -0.05), "stance": (0.04, 0.12), "foot": "digitigrade",
                     "foot_tilt": 24.0, "roll_tilt": 36.0, "bend": "forward", "splay": 3.0},
            # The short arms held bent before the chest, the stubby hands down.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.26, 0.15, 0.07, 0.065], "socket": (0.16, -0.05, -0.3), "arm": True,
                     "rest_hand": (0.045, 0.2, -0.2), "bend": "back", "splay": 14.0, "hand_angle": 45.0,
                     "finger_angle": 80.0},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 1.05, "duty": 0.62, "step": 0.11, "bob": 0.03, "sway": 0.022, "hip_yaw": 3.0,
                 "hip_roll": 2.5, "tail_swing": 3.5, "neck_bob": 2.0, "steady": 0.8, "narrow": 0.9, "push": 0.5,
                 "curl": 0.4, "arm_swing": 0.01},
        "run": {"period": 0.76, "duty": 0.42, "step": 0.17, "bob": 0.05, "lean": -5.0, "crouch": 0.05,
                "neck_pitch": -10.0, "tail_lift": 3.0, "head_pitch": 4.0, "tail_swing": 2.0, "steady": 0.85,
                "narrow": 0.85, "push": 0.8},
        "idle": {"period": 4.6, "breaths": 2, "look": 20.0, "nod": 3.0, "swell": 0.02, "tail_swing": 3.5},
        "attack": {"period": 1.0, "jaw": 42.0, "lunge": 0.26, "draw": 14.0, "reach": 20.0, "head_up": 10.0,
                   "head_down": 12.0},
        "death": {"period": 1.6, "roll": 84.0, "pivot": 0.32, "slide": 0.14},
    },
    "body": {
        "around": 44,
        "soften": 0.05,
        "rough": 0.02,
        "scale": 0.6,
        "throat": 0.32,
        "trunk": [
            # The skull: deep and narrow, deep even at the snout, its top straight under its horn; the lower jaw
            # deep enough to sheathe the long upper teeth.
            st("Head", 1.012, 0.014, 0.022, 0.02, step=0.008),
            st("Head", 0.985, 0.032, 0.06, 0.058, step=0.012),
            st("Head", 0.93, 0.042, 0.086, 0.086, step=0.02),
            st("Head", 0.85, 0.048, 0.103, 0.104, step=0.025),
            st("Head", 0.72, 0.053, 0.116, 0.117, step=0.03),
            st("Head", 0.58, 0.06, 0.125, 0.127, step=0.03),
            st("Head", 0.44, 0.07, 0.131, 0.137, step=0.03),
            st("Head", 0.32, 0.084, 0.137, 0.147, lift=0.01, step=0.03),
            st("Head", 0.2, 0.1, 0.13, 0.156, step=0.03),
            st("Head", 0.08, 0.106, 0.118, 0.164, step=0.035),
            st("Head", -0.04, 0.1, 0.104, 0.16, step=0.04),
            st("Head", -0.12, 0.094, 0.096, 0.152, step=0.04),
            # The neck: short for a theropod's, and thick.
            st("Neck4", 0.5, 0.094, 0.097, 0.142, step=0.05),
            st("Neck3", 0.5, 0.104, 0.106, 0.156, step=0.05),
            st("Neck2", 0.5, 0.119, 0.12, 0.172, step=0.05),
            st("Neck1", 0.5, 0.145, 0.135, 0.198, step=0.05),
            st("Spine4", 0.6, 0.175, 0.153, 0.255, step=0.06),
            st("Spine4", 0.1, 0.215, 0.195, 0.42, n_bot=2.3, step=0.06),
            st("Spine3", 0.5, 0.25, 0.22, 0.5, n_bot=2.4, step=0.06),
            st("Spine2", 0.5, 0.26, 0.23, 0.48, n_bot=2.3, step=0.06),
            st("Spine1", 0.5, 0.255, 0.235, 0.38, step=0.06),
            # The hips broad over the thighs, which come out of them.
            st("Hips", 0.25, 0.265, 0.23, 0.26, keel=0.012, step=0.06),
            st("Hips", 0.9, 0.215, 0.22, 0.22, keel=0.012, step=0.06),
            # The tail: deep and narrow, crocodile-like -- tall spines over it and chevrons under.
            st("Tail1", 0.5, 0.15, 0.21, 0.24, step=0.07),
            st("Tail2", 0.5, 0.125, 0.192, 0.212, step=0.07),
            st("Tail3", 0.5, 0.105, 0.172, 0.182, step=0.07),
            st("Tail4", 0.5, 0.088, 0.152, 0.156, step=0.07),
            st("Tail5", 0.5, 0.074, 0.131, 0.131, step=0.07),
            st("Tail6", 0.5, 0.062, 0.111, 0.11, step=0.07),
            st("Tail7", 0.5, 0.051, 0.092, 0.09, step=0.06),
            st("Tail8", 0.5, 0.041, 0.075, 0.072, step=0.06),
            st("Tail9", 0.5, 0.032, 0.058, 0.056, step=0.05),
            st("Tail10", 0.5, 0.024, 0.043, 0.041, step=0.05),
            st("Tail11", 0.5, 0.017, 0.03, 0.028, step=0.04),
            st("Tail12", 0.5, 0.011, 0.018, 0.017, step=0.04),
            st("Tail13", 0.6, 0.006, 0.009, 0.008, step=0.03),
            st("Tail_end", 0.3, 0.0025, 0.0025, 0.0025, step=0.015),
        ],
        "mouth": {"from": ("Head", 0.07), "to": ("Head", 1.0), "phi": 108.0, "depth": 0.01, "width": 0.1, "band": 3.0},
        # The upper teeth very long, blade-like (Madsen & Welles 2000); the lower shorter.
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 14, "length": 0.058, "radius": 0.0115,
                  "colour": (0.78, 0.73, 0.6)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 13, "length": 0.032, "radius": 0.0095},
        "eyes": {"at": ("Head", 0.3), "phi": 40.0, "radius": 0.023, "sunk": 0.6, "forward": 12.0, "up": 10.0,
                 "iris": (0.66, 0.46, 0.08), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.31), "phi": 26.0, "size": 0.05, "height": 0.018},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.64), "phi": 66.0, "depth": 0.012, "width": 0.3},
        "nostrils": {"at": ("Head", 0.92), "phi": 40.0, "size": 0.012},
        # The blade of a horn on the nasals, over the nostrils -- thin side to side, long fore and aft -- and a
        # rounded hornlet over and before each eye (the lacrimals). Sheathed in horn, darker than the skin.
        "horns": [
            {"at": ("Head", 0.76), "phi": 0.0, "length": 0.085, "base": (0.009, 0.065), "rake": -6.0, "taper": 0.45,
             "colour": (0.42, 0.12, 0.05), "tip": (0.16, 0.06, 0.03), "bone": "Head", "rings": 8, "around": 12},
            {"at": ("Head", 0.36), "phi": 22.0, "length": 0.042, "base": (0.02, 0.05), "rake": 8.0, "splay": 10.0,
             "taper": 0.4, "colour": (0.42, 0.12, 0.05), "tip": (0.18, 0.07, 0.035), "bone": "Head", "rings": 7,
             "around": 12},
        ],
        # The row of osteoderms down the middle of the back, from the neck along the tail.
        "plates": {"from": ("Neck2", 0.2), "to": ("Tail10", 0.5), "rows": [0.0], "length": 0.058, "width": 0.042,
                   "height": 0.022, "spacing": 0.07, "ref": 0.22, "colour": (0.03, 0.026, 0.022), "square": 0.15,
                   "keel": 0.6},
        "limbs": {
            "hind": {
                # Its top inside the hips, so the thigh comes out of the flank.
                "stations": [(0, -0.28, 0.1, 0.2, 0.02), (0, -0.05, 0.165, 0.265, 0.03), (0, 0.25, 0.18, 0.25, 0.03),
                             (0, 0.55, 0.145, 0.19, 0.018), (0, 0.85, 0.1, 0.12, 0.005), (0, 0.98, 0.085, 0.095, 0.0),
                             (1, 0.1, 0.085, 0.115, -0.022), (1, 0.3, 0.08, 0.115, -0.03), (1, 0.6, 0.06, 0.072, -0.013),
                             (1, 0.95, 0.042, 0.042, 0.0), (2, 0.1, 0.04, 0.036, 0.0), (2, 0.95, 0.036, 0.03, 0.0)],
                "around": 18,
                "digits": {
                    "digits": [(-18.0, 0.15, 0.026, 0.05), (0.0, 0.18, 0.028, 0.055), (18.0, 0.15, 0.026, 0.05)],
                    "hallux": (150.0, 0.065, 0.013, 0.03, 0.085),
                    "flat": 0.8,
                    "claw_curl": 0.6,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.05, 0.062, 0.0), (0, 0.1, 0.056, 0.062, 0.007), (0, 0.5, 0.045, 0.05, 0.006),
                             (0, 0.95, 0.033, 0.035, 0.0), (1, 0.3, 0.033, 0.035, 0.0), (1, 0.95, 0.025, 0.025, 0.0),
                             (2, 0.6, 0.024, 0.018, 0.0)],
                "around": 12,
                # Four short fingers, blunt-clawed.
                "digits": {
                    "digits": [(-24.0, 0.04, 0.01, 0.022), (-8.0, 0.05, 0.0105, 0.024), (8.0, 0.046, 0.01, 0.02),
                               (24.0, 0.028, 0.008, 0.01)],
                    "claw_curl": 0.9,
                    "flat": 0.9,
                },
            },
        },
        "skin_detail": {"scales": {"cells": 60.0, "dorsal_size": 0.5, "groove": 0.36, "groove_dark": 0.3, "tint": 0.11,
                                   "speckle": 0.1, "relief": 0.8, "depth": 0.007},
                        "horn": {"grain": 90.0, "relief": 0.12, "mottle": 0.12, "streak": 0.06}},
        "texture": 2048,
        # Charcoal over the back, dark olive-grey flanks barred black, a pale belly; its horns and the face about them
        # flushed red -- what it shows off with.
        "skin": {
            "back": (0.022, 0.02, 0.017),
            "flank": (0.12, 0.105, 0.075),
            "belly": (0.44, 0.39, 0.29),
            "throat": (0.48, 0.4, 0.29),
            "lips": (0.08, 0.06, 0.04),
            "mouth": (0.32, 0.07, 0.06),
            "claws": (0.035, 0.03, 0.025),
            "mottle": 0.2,
            "shank_dark": 0.3,
            "bands": {"colour": (0.012, 0.01, 0.008), "from": ("Neck1", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.4, "width": 0.26, "strength": 0.72},
            "flush": {"colour": (0.42, 0.1, 0.05), "from": ("Head", 1.0), "to": ("Head", 0.2), "strength": 0.38},
        },
    },
}


# Allosaurus fragilis (Marsh 1877): the Morrison's great hunter, and the Late Jurassic's best known -- eight and a half
# metres of it, the big ones; a skull near a metre long, deep but lightly built, a low ridge down each side of the
# snout ending before the eye in a horn-like crest (the lacrimal horn); a strong S of a neck; arms longer and stronger
# than a tyrannosaur's, three fingers, the first with a great hooked claw; a long tail. Its skin, where impressions
# survive ("Big Al Two"), small scales. The second map's boss: last of all, in the beacon's final wave.


ALLOSAURUS = {
    "height": 2.8,
    # After Madsen (1976) and Scott Hartman's skeletal of a big one: skull 0.88 m, femur 0.9, tibia 0.76, the long
    # foot bone 0.38; the arm 0.7 m to the wrist.
    "skeleton": {
        "hip_height": 2.17,
        "pelvis_length": 0.55,
        "pelvis_pitch": -6.0,
        "spine": [(0.55, 3.0), (0.55, 0.0), (0.52, -4.0), (0.48, -8.0)],
        "neck": [(0.31, 53.0), (0.29, 43.0), (0.26, 24.0), (0.22, -4.0)],
        "skull": (0.88, -10.0),
        "jaw": (0.82, 0.16, -14.0),
        "jaw_hinge": 0.06,
        "tail": [(0.42, 5.0), (0.41, 1.0), (0.4, -1.0), (0.38, -2.0), (0.36, -2.0), (0.34, -1.0), (0.32, -1.0),
                 (0.29, 0.0), (0.26, 0.0), (0.23, 0.0), (0.2, 0.0), (0.17, 0.0), (0.14, 0.0), (0.11, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.9, 0.76, 0.38, 0.25],
                     "socket": (0.23, 0.0, -0.07), "stance": (0.06, 0.16), "foot": "digitigrade",
                     "foot_tilt": 24.0, "roll_tilt": 35.0, "bend": "forward", "splay": 3.0},
            # The arms held bent before the chest, the forearm down and forward, the great claws hooked.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.34, 0.25, 0.1, 0.15], "socket": (0.23, -0.07, -0.42), "arm": True,
                     "rest_hand": (0.07, 0.36, -0.34), "bend": "back", "splay": 14.0, "hand_angle": 40.0,
                     "finger_angle": 75.0},
        },
    },
    "moves": {
        "plan": "biped",
        # A heavy walk, the body rolling over each foot, the head steady.
        "walk": {"period": 1.2, "duty": 0.62, "step": 0.14, "bob": 0.038, "sway": 0.028, "hip_yaw": 3.0,
                 "hip_roll": 2.5, "tail_swing": 3.0, "neck_bob": 2.0, "steady": 0.8, "narrow": 0.9, "push": 0.5,
                 "curl": 0.4, "arm_swing": 0.012},
        "run": {"period": 0.86, "duty": 0.44, "step": 0.21, "bob": 0.06, "lean": -4.0, "crouch": 0.06,
                "neck_pitch": -8.0, "tail_lift": 3.0, "head_pitch": 3.0, "tail_swing": 2.0, "steady": 0.85,
                "narrow": 0.85, "push": 0.8},
        "idle": {"period": 5.0, "breaths": 2, "look": 18.0, "nod": 3.0, "swell": 0.02, "tail_swing": 3.0},
        # The hatchet blow (Rayfield et al. 2001): the head drawn up with its jaws wide, then driven down and forward
        # through what it strikes.
        "attack": {"period": 1.1, "jaw": 48.0, "lunge": 0.34, "draw": 16.0, "reach": 18.0, "head_up": 14.0,
                   "head_down": 16.0},
        "death": {"period": 1.8, "roll": 84.0, "pivot": 0.45, "slide": 0.2},
    },
    "body": {
        "around": 44,
        "soften": 0.06,
        "rough": 0.025,
        "scale": 0.9,
        "throat": 0.34,
        "trunk": [
            # The skull: deep, narrow, lightly built; the ridges down the snout and the crests before the eyes
            # ("ridges", "horns").
            st("Head", 1.012, 0.02, 0.026, 0.024, step=0.012),
            st("Head", 0.985, 0.042, 0.068, 0.066, step=0.018),
            st("Head", 0.93, 0.054, 0.1, 0.1, step=0.03),
            st("Head", 0.84, 0.062, 0.124, 0.12, step=0.04),
            st("Head", 0.7, 0.073, 0.142, 0.142, step=0.04),
            st("Head", 0.56, 0.086, 0.158, 0.162, step=0.04),
            st("Head", 0.42, 0.104, 0.172, 0.182, step=0.04),
            st("Head", 0.3, 0.124, 0.184, 0.2, lift=0.012, step=0.04),
            st("Head", 0.18, 0.144, 0.178, 0.216, step=0.04),
            st("Head", 0.06, 0.15, 0.162, 0.226, step=0.05),
            st("Head", -0.05, 0.14, 0.146, 0.222, step=0.05),
            st("Head", -0.12, 0.13, 0.136, 0.212, step=0.05),
            # The neck: a strong S, deep with muscle.
            st("Neck4", 0.5, 0.128, 0.13, 0.192, step=0.06),
            st("Neck3", 0.5, 0.142, 0.142, 0.21, step=0.06),
            st("Neck2", 0.5, 0.166, 0.16, 0.235, step=0.07),
            st("Neck1", 0.5, 0.205, 0.185, 0.28, step=0.07),
            st("Spine4", 0.6, 0.255, 0.215, 0.36, step=0.08),
            st("Spine4", 0.1, 0.31, 0.27, 0.62, n_bot=2.3, step=0.08),
            st("Spine3", 0.5, 0.36, 0.3, 0.72, n_bot=2.4, step=0.08),
            st("Spine2", 0.5, 0.37, 0.32, 0.68, n_bot=2.3, step=0.08),
            st("Spine1", 0.5, 0.36, 0.33, 0.55, step=0.08),
            # The hips broad over the thighs, which come out of them.
            st("Hips", 0.3, 0.37, 0.32, 0.37, keel=0.015, step=0.08),
            st("Hips", 0.9, 0.3, 0.3, 0.31, keel=0.015, step=0.08),
            st("Tail1", 0.5, 0.22, 0.28, 0.3, step=0.09),
            st("Tail2", 0.5, 0.185, 0.245, 0.255, step=0.09),
            st("Tail3", 0.5, 0.155, 0.21, 0.215, step=0.09),
            st("Tail4", 0.5, 0.13, 0.18, 0.18, step=0.09),
            st("Tail5", 0.5, 0.108, 0.15, 0.15, step=0.09),
            st("Tail6", 0.5, 0.09, 0.125, 0.122, step=0.09),
            st("Tail7", 0.5, 0.074, 0.103, 0.1, step=0.08),
            st("Tail8", 0.5, 0.06, 0.084, 0.08, step=0.08),
            st("Tail9", 0.5, 0.047, 0.066, 0.063, step=0.07),
            st("Tail10", 0.5, 0.036, 0.05, 0.048, step=0.07),
            st("Tail11", 0.5, 0.026, 0.036, 0.034, step=0.06),
            st("Tail12", 0.5, 0.018, 0.024, 0.023, step=0.05),
            st("Tail13", 0.5, 0.011, 0.014, 0.013, step=0.04),
            st("Tail14", 0.6, 0.006, 0.007, 0.007, step=0.03),
            st("Tail_end", 0.3, 0.0025, 0.0025, 0.0025, step=0.015),
        ],
        "mouth": {"from": ("Head", 0.06), "to": ("Head", 1.0), "phi": 106.0, "depth": 0.014, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.28), "to": ("Head", 0.97), "count": 17, "length": 0.05, "radius": 0.0115,
                  "colour": (0.78, 0.73, 0.6)},
        "lower_teeth": {"from": ("Head", 0.28), "to": ("Head", 0.93), "count": 15, "length": 0.04, "radius": 0.01},
        "eyes": {"at": ("Head", 0.27), "phi": 42.0, "radius": 0.028, "sunk": 0.6, "forward": 14.0, "up": 10.0,
                 "iris": (0.7, 0.42, 0.07), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.28), "phi": 26.0, "size": 0.06, "height": 0.02},
        "fossa": {"from": ("Head", 0.4), "to": ("Head", 0.64), "phi": 64.0, "depth": 0.016, "width": 0.3},
        "nostrils": {"at": ("Head", 0.92), "phi": 40.0, "size": 0.016},
        # A low ridge down each side of the snout's top, from the nostril back to the crest before the eye.
        "ridges": [{"from": ("Head", 0.4), "to": ("Head", 0.92), "phi": 16.0, "height": 0.022, "width": 0.08}],
        # The lacrimal horns: a triangular crest before and over each eye, leaning back.
        "horns": [
            {"at": ("Head", 0.39), "phi": 18.0, "length": 0.08, "base": (0.024, 0.07), "rake": 22.0, "splay": 6.0,
             "taper": 1.0, "colour": (0.34, 0.1, 0.05), "tip": (0.16, 0.06, 0.03), "bone": "Head", "rings": 7,
             "around": 12},
        ],
        "limbs": {
            "hind": {
                # Its top inside the hips, so the thigh comes out of the flank.
                "stations": [(0, -0.28, 0.14, 0.28, 0.03), (0, -0.05, 0.235, 0.37, 0.045), (0, 0.25, 0.26, 0.355, 0.045),
                             (0, 0.55, 0.205, 0.27, 0.025), (0, 0.85, 0.14, 0.17, 0.006), (0, 0.98, 0.12, 0.135, 0.0),
                             (1, 0.1, 0.138, 0.19, -0.034), (1, 0.3, 0.132, 0.19, -0.048), (1, 0.6, 0.098, 0.118, -0.02),
                             (1, 0.95, 0.068, 0.068, 0.0), (2, 0.1, 0.064, 0.057, 0.0), (2, 0.95, 0.057, 0.047, 0.0)],
                "around": 18,
                "digits": {
                    "digits": [(-18.0, 0.24, 0.037, 0.075), (0.0, 0.28, 0.04, 0.085), (18.0, 0.24, 0.037, 0.075)],
                    "hallux": (150.0, 0.095, 0.018, 0.04, 0.12),
                    "flat": 0.8,
                    "claw_curl": 0.6,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.075, 0.094, 0.0), (0, 0.1, 0.083, 0.093, 0.011), (0, 0.5, 0.066, 0.073, 0.01),
                             (0, 0.95, 0.047, 0.05, 0.0), (1, 0.3, 0.048, 0.053, 0.003), (1, 0.95, 0.036, 0.038, 0.0),
                             (2, 0.6, 0.035, 0.025, 0.0)],
                "around": 12,
                # Three fingers, the first short with the great hooked claw.
                "digits": {
                    "digits": [(-16.0, 0.085, 0.016, 0.095), (0.0, 0.14, 0.015, 0.075), (16.0, 0.115, 0.013, 0.06)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        "skin_detail": {"scales": {"cells": 50.0, "dorsal_size": 0.5, "groove": 0.36, "groove_dark": 0.28, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.8, "depth": 0.009},
                        "horn": {"grain": 80.0, "relief": 0.12, "mottle": 0.12, "streak": 0.06}},
        "texture": 2048,
        # A dark brown back with darker saddles down it and round the tail, tawny flanks, a pale belly; a dark mask back
        # from the eye; the crests before the eyes red.
        "skin": {
            "back": (0.042, 0.028, 0.018),
            "flank": (0.27, 0.15, 0.065),
            "belly": (0.55, 0.46, 0.33),
            "throat": (0.58, 0.49, 0.35),
            "lips": (0.1, 0.07, 0.045),
            "mouth": (0.32, 0.08, 0.06),
            "claws": (0.045, 0.035, 0.028),
            "mottle": 0.18,
            "shank_dark": 0.3,
            "bands": {"colour": (0.016, 0.011, 0.007), "from": ("Spine3", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.55, "width": 0.26, "strength": 0.65},
            "eye_stripe": {"colour": (0.03, 0.02, 0.014), "from": ("Head", 0.42), "to": ("Neck4", 0.6),
                           "phi": 52.0, "width": 13.0},
        },
    },
}


# Stegosaurus stenops (Marsh 1887): seven metres of it, a small low head with a horny beak, a short neck bent down,
# short forelegs and long hind ones so its back rises to a peak over the hips; seventeen plates up its neck, back and
# tail in two rows whose plates alternate (Gilmore 1914; "Sophie", Maidment et al. 2015), the biggest over the hips;
# four long spikes at the end of its tail (the "thagomizer") -- an Allosaurus vertebra has one's wound in it (Carpenter
# et al. 2005). Scenery on the second map: it grazes the valley's sides (Config.HERDS), and it is never fought.


STEGOSAURUS = {
    # Scenery: the herd fits it to its length and walks it at its own pace.
    "fit": "length",
    "length": 7.0,
    "height": 3.3,
    # Its strides drawn at the herd's pace (MAPS.morrison.herds: 0.6 m/s), so its feet stay put.
    "paces": {"walk": 0.6, "run": 1.2},
    "skeleton": {
        "hip_height": 2.05,
        "pelvis_length": 0.45,
        "pelvis_pitch": -14.0,
        # The back arched: from the hips forward and steeply down to the low shoulders.
        "spine": [(0.5, -8.0), (0.5, -18.0), (0.48, -26.0), (0.42, -28.0)],
        "neck": [(0.2, -18.0), (0.19, -24.0), (0.18, -26.0), (0.16, -22.0)],
        "skull": (0.42, -26.0),
        "jaw": (0.33, 0.07, -30.0),
        "jaw_hinge": 0.22,
        "tail": [(0.4, -16.0), (0.38, -14.0), (0.36, -11.0), (0.34, -8.0), (0.32, -5.0), (0.3, -3.0), (0.28, -1.0),
                 (0.26, 0.0), (0.24, 1.0), (0.22, 1.0), (0.2, 2.0), (0.18, 2.0), (0.16, 2.0)],
        "limbs": {
            # Pillars: the hind leg long and near straight, the foot short with three hoofed toes.
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [1.1, 0.68, 0.22, 0.14],
                     "socket": (0.28, 0.0, -0.08), "stance": (0.0, 0.03), "foot": "digitigrade", "foot_tilt": 18.0,
                     "roll_tilt": 30.0, "bend": "forward", "splay": 2.0},
            # The foreleg short and stout, its hand bones standing near upright in a half-ring, five short toes.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.52, 0.4, 0.15, 0.08], "socket": (0.27, -0.05, -0.34), "stance": (0.06, 0.05),
                     "foot": "digitigrade", "foot_tilt": 6.0, "roll_tilt": 25.0, "bend": "back", "splay": 10.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        "walk": {"period": 1.7, "duty": 0.72, "step": 0.1, "bob": 0.02, "snake": 2.0, "tail_swing": 3.0,
                 "order": "walk", "steady": 0.7, "push": 0.5, "curl": 0.3, "hip_roll": 2.0},
        "run": {"period": 1.0, "duty": 0.55, "step": 0.14, "bob": 0.035, "snake": 2.0, "tail_swing": 3.0,
                "order": "trot", "steady": 0.7, "push": 0.6, "curl": 0.3},
        # Grazing low: its head down among the ferns cropping, swung a little from side to side; up for a while to
        # look about.
        "idle": {"period": 7.0, "breaths": 2, "look": 14.0, "nod": 3.0, "swell": 0.012, "tail_swing": 2.5,
                 "heave": 0.006, "graze": {"neck": -24.0, "head": -16.0, "chew": 12.0, "chews": 14, "up": (0.6, 0.82),
                                           "sweep": 8.0, "sweeps": 2}},
        "graze": {"period": 6.0},
        # Its blow is with its tail: the spikes swung round at what comes at it.
        "attack": {"period": 1.4, "swipe": 70.0, "turn": 0.15, "look": 0.25, "tail_up": 4.0, "dip": 0.03},
        "death": {"period": 2.0, "roll": 70.0, "pivot": 0.5, "slide": 0.1, "limp_forward": 0.15, "limp_up": 0.15},
    },
    "body": {
        "around": 44,
        "soften": 0.06,
        "rough": 0.02,
        "scale": 0.7,
        "throat": 0.3,
        "trunk": [
            # The skull: small, long and low, narrow, a horny beak at its front.
            st("Head", 1.012, 0.012, 0.012, 0.012, step=0.008),
            st("Head", 0.985, 0.03, 0.034, 0.032, step=0.012),
            st("Head", 0.9, 0.042, 0.048, 0.047, step=0.02),
            st("Head", 0.75, 0.052, 0.06, 0.06, step=0.025),
            st("Head", 0.58, 0.06, 0.07, 0.068, step=0.025),
            st("Head", 0.42, 0.068, 0.078, 0.076, step=0.025),
            st("Head", 0.28, 0.077, 0.084, 0.082, lift=0.006, step=0.025),
            st("Head", 0.14, 0.084, 0.082, 0.088, step=0.025),
            st("Head", 0.02, 0.082, 0.076, 0.092, step=0.03),
            st("Head", -0.08, 0.078, 0.07, 0.096, step=0.03),
            # The neck: short, bent down, deepening to the shoulders.
            st("Neck4", 0.5, 0.085, 0.085, 0.108, step=0.04),
            st("Neck3", 0.5, 0.105, 0.105, 0.135, step=0.04),
            st("Neck2", 0.5, 0.135, 0.135, 0.175, step=0.045),
            st("Neck1", 0.5, 0.175, 0.175, 0.23, step=0.05),
            # The body: deep and fairly narrow, highest over the hips.
            st("Spine4", 0.6, 0.24, 0.21, 0.4, step=0.06),
            st("Spine4", 0.1, 0.34, 0.25, 0.66, n_bot=2.3, step=0.06),
            st("Spine3", 0.5, 0.41, 0.28, 0.8, n_bot=2.4, step=0.06),
            st("Spine2", 0.5, 0.45, 0.31, 0.86, n_bot=2.4, step=0.06),
            st("Spine1", 0.5, 0.46, 0.33, 0.78, n_bot=2.2, step=0.06),
            st("Hips", 0.25, 0.45, 0.35, 0.6, step=0.06),
            st("Hips", 0.8, 0.38, 0.33, 0.42, step=0.06),
            # The tail: deep at its root, held off the ground, tapering to the spikes.
            st("Tail1", 0.5, 0.3, 0.3, 0.32, step=0.06),
            st("Tail2", 0.5, 0.25, 0.26, 0.27, step=0.06),
            st("Tail3", 0.5, 0.21, 0.22, 0.23, step=0.06),
            st("Tail4", 0.5, 0.18, 0.19, 0.19, step=0.06),
            st("Tail5", 0.5, 0.15, 0.16, 0.16, step=0.06),
            st("Tail6", 0.5, 0.13, 0.135, 0.13, step=0.05),
            st("Tail7", 0.5, 0.11, 0.115, 0.11, step=0.05),
            st("Tail8", 0.5, 0.095, 0.1, 0.095, step=0.05),
            st("Tail9", 0.5, 0.08, 0.085, 0.08, step=0.04),
            st("Tail10", 0.5, 0.068, 0.072, 0.068, step=0.04),
            st("Tail11", 0.5, 0.058, 0.06, 0.057, step=0.04),
            st("Tail12", 0.5, 0.048, 0.05, 0.047, step=0.035),
            st("Tail13", 0.6, 0.035, 0.036, 0.034, step=0.03),
            st("Tail_end", 0.3, 0.012, 0.012, 0.012, step=0.015),
        ],
        # The beak's edge: its cheek teeth small and hidden behind it.
        "mouth": {"from": ("Head", 0.2), "to": ("Head", 1.0), "phi": 112.0, "depth": 0.006, "width": 0.1, "band": 3.0},
        "eyes": {"at": ("Head", 0.25), "phi": 48.0, "radius": 0.017, "sunk": 0.6, "forward": 8.0, "up": 6.0,
                 "iris": (0.42, 0.3, 0.1), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.27), "phi": 30.0, "size": 0.035, "height": 0.012},
        "nostrils": {"at": ("Head", 0.88), "phi": 40.0, "size": 0.011},
        # The plates: two rows, alternating, seventeen; small on the neck, the biggest over the hips and the root of
        # the tail.
        "back_plates": {"from": ("Neck3", 0.0), "to": ("Tail9", 0.5), "count": 17, "rows": 2, "phi": 4.0,
                        "lean": 9.0, "thick": 0.045, "sink": 0.06,
                        "sizes": [(0.0, 0.15, 0.16), (0.14, 0.32, 0.32), (0.32, 0.64, 0.6), (0.5, 0.9, 0.8),
                                  (0.62, 0.98, 0.84), (0.76, 0.72, 0.64), (0.9, 0.42, 0.4), (1.0, 0.22, 0.22)],
                        "colour": (0.28, 0.13, 0.06), "rim": (0.42, 0.23, 0.1), "groove": 0.04, "groove_dark": 0.18},
        # The four spikes, out, up and back from the end of the tail.
        "horns": [
            {"at": ("Tail11", 0.3), "phi": 62.0, "length": 0.78, "base": (0.07, 0.075), "rake": 30.0, "splay": 30.0,
             "taper": 1.0, "colour": (0.42, 0.38, 0.29), "tip": (0.14, 0.12, 0.09), "rings": 6, "around": 10},
            {"at": ("Tail12", 0.8), "phi": 72.0, "length": 0.8, "base": (0.066, 0.07), "rake": 44.0, "splay": 26.0,
             "taper": 1.0, "colour": (0.42, 0.38, 0.29), "tip": (0.14, 0.12, 0.09), "rings": 6, "around": 10},
        ],
        "limbs": {
            "hind": {
                "stations": [(0, -0.22, 0.12, 0.22, 0.02), (0, 0.02, 0.2, 0.3, 0.035), (0, 0.3, 0.2, 0.27, 0.03),
                             (0, 0.6, 0.16, 0.2, 0.015), (0, 0.9, 0.12, 0.14, 0.0), (0, 0.98, 0.11, 0.12, 0.0),
                             (1, 0.15, 0.11, 0.14, -0.015), (1, 0.4, 0.1, 0.12, -0.012), (1, 0.75, 0.083, 0.092, -0.004),
                             (1, 0.96, 0.078, 0.078, 0.0), (2, 0.2, 0.082, 0.072, 0.0), (2, 0.9, 0.088, 0.066, 0.0)],
                "around": 18,
                "digits": {"digits": [(-24.0, 0.11, 0.045, 0.05), (0.0, 0.13, 0.05, 0.055), (24.0, 0.11, 0.045, 0.05)],
                           "flat": 0.6, "claw_curl": 0.25},
            },
            "fore": {
                "stations": [(0, -0.2, 0.1, 0.13, 0.0), (0, 0.05, 0.13, 0.16, 0.015), (0, 0.45, 0.11, 0.13, 0.015),
                             (0, 0.92, 0.08, 0.09, 0.0), (1, 0.2, 0.085, 0.095, 0.006), (1, 0.6, 0.07, 0.075, 0.0),
                             (1, 0.96, 0.06, 0.062, 0.0), (2, 0.2, 0.066, 0.06, 0.0), (2, 0.9, 0.072, 0.056, 0.0)],
                "around": 16,
                "digits": {"digits": [(-40.0, 0.055, 0.026, 0.03), (-20.0, 0.062, 0.028, 0.03), (0.0, 0.065, 0.028, 0.03),
                                      (20.0, 0.06, 0.027, 0.028), (40.0, 0.05, 0.024, 0.022)],
                           "flat": 0.6, "claw_curl": 0.3},
            },
        },
        "skin_detail": {"scales": {"cells": 45.0, "dorsal_size": 0.55, "groove": 0.34, "groove_dark": 0.26, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.6, "depth": 0.007},
                        "horn": {"grain": 40.0, "relief": 0.14, "mottle": 0.16, "streak": 0.08}},
        "texture": 2048,
        # Olive-brown over the back, dark-blotched, paler down the flanks, a pale belly; a horn-dark beak; the plates
        # flushed rust-red, their rims paler.
        "skin": {
            "back": (0.06, 0.058, 0.032),
            "flank": (0.25, 0.23, 0.13),
            "belly": (0.5, 0.46, 0.33),
            "throat": (0.52, 0.47, 0.35),
            "lips": (0.08, 0.07, 0.05),
            "mouth": (0.3, 0.1, 0.08),
            "claws": (0.1, 0.09, 0.07),
            "mottle": 0.2,
            "shank_dark": 0.3,
            "beak": {"from": ("Head", 0.8), "colour": (0.07, 0.06, 0.045)},
            "spots": {"colour": (0.03, 0.03, 0.018), "from": ("Neck2", 0.0), "to": ("Tail8", 0.5), "scale": 2.4,
                      "above": 0.3, "strength": 0.5},
        },
    },
}


# Diplodocus (Marsh 1878; D. carnegii, "Dippy", Hatcher 1901): twenty-five metres of it -- a long, low neck of fifteen
# vertebrae held out level, a small, long, low head with peg teeth at the front of its square muzzle, a deep narrow
# body on pillar legs, the hind longer, so it stands highest at the hips; and a tail longer than the rest of it,
# ending in a whip. A row of spines down its back and tail (Czerkas 1992). Scenery on the second map: a herd on the
# valley's walls, grazing low and sweeping its neck from side to side (Config.HERDS); never fought.


DIPLODOCUS = {
    "fit": "length",
    "length": 25.0,
    "height": 4.0,
    # Its strides drawn at the herd's pace (MAPS.morrison.herds: 0.5 m/s), so its feet stay put.
    "paces": {"walk": 0.5, "run": 1.0},
    "skeleton": {
        "hip_height": 3.1,
        "pelvis_length": 0.9,
        "pelvis_pitch": -8.0,
        "spine": [(0.8, -4.0), (0.8, -6.0), (0.75, -8.0), (0.7, -6.0)],
        # The neck held out level, rising a little from the shoulders and falling a little to the head.
        "neck": [(0.65, 12.0), (0.69, 8.0), (0.71, 4.0), (0.71, 2.0), (0.69, 0.0), (0.67, -2.0), (0.63, -4.0),
                 (0.59, -6.0), (0.53, -8.0), (0.46, -10.0)],
        "skull": (0.62, -40.0),
        "jaw": (0.5, 0.07, -44.0),
        "jaw_hinge": 0.25,
        "tail": [(1.04, -10.0), (0.99, -8.0), (0.95, -6.0), (0.9, -4.0), (0.86, -2.0), (0.81, -1.0), (0.77, 0.0),
                 (0.73, 0.0), (0.68, 1.0), (0.64, 1.0), (0.6, 1.0), (0.57, 1.0), (0.55, 0.0), (0.53, 0.0),
                 (0.51, 0.0), (0.48, 0.0), (0.46, 0.0), (0.44, -1.0), (0.42, -1.0), (0.4, -1.0), (0.37, -1.0),
                 (0.33, -1.0)],
        "limbs": {
            # Pillars: the hind foot short, its bones inclined, a great claw on its first toe.
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [1.7, 1.1, 0.35, 0.28],
                     "socket": (0.42, 0.0, -0.12), "stance": (0.02, 0.05), "foot": "plantigrade", "heel": 35.0,
                     "roll_tilt": 25.0, "bend": "forward", "splay": 2.0},
            # The foreleg a column, its hand bones upright in a horseshoe, a claw on the thumb alone.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [1.08, 0.74, 0.38, 0.1], "socket": (0.4, -0.1, -0.6), "stance": (0.1, 0.05),
                     "foot": "digitigrade", "foot_tilt": 4.0, "roll_tilt": 20.0, "bend": "back", "splay": 4.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        # A slow, heavy walk, each foot down three quarters of its cycle; the long tail swinging in a slow wave.
        "walk": {"period": 2.6, "duty": 0.72, "step": 0.16, "bob": 0.04, "snake": 1.5, "tail_swing": 0.8,
                 "order": "walk", "steady": 0.6, "push": 0.4, "curl": 0.2, "hip_roll": 1.5},
        # Its "run": a quicker amble, never off all its feet.
        "run": {"period": 1.7, "duty": 0.6, "step": 0.2, "bob": 0.06, "snake": 1.5, "tail_swing": 0.8,
                "order": "walk", "steady": 0.6, "push": 0.5, "curl": 0.25, "hip_roll": 1.5},
        # Grazing low: the neck swung down to the ferns and swept slowly across them, cropping; now and then up
        # to look about.
        "idle": {"period": 9.0, "breaths": 2, "look": 14.0, "nod": 2.0, "swell": 0.01, "tail_swing": 0.8,
                 "heave": 0.012, "graze": {"neck": -48.0, "head": -6.0, "chew": 8.0, "chews": 18, "up": (0.6, 0.84),
                                           "sweep": 22.0, "sweeps": 1}},
        "graze": {"period": 8.0},
        # Its blow: the whip of its tail.
        "attack": {"period": 2.0, "swipe": 50.0, "turn": 0.06, "look": 0.3, "tail_up": 2.0, "dip": 0.03},
        "death": {"period": 2.6, "roll": 82.0, "pivot": 0.75, "slide": 0.3, "limp_forward": 0.3, "limp_up": 0.3},
    },
    "body": {
        "around": 48,
        "soften": 0.1,
        "rough": 0.02,
        "scale": 2.0,
        "throat": 0.3,
        "tips": (0.02, 0.03),
        "trunk": [
            # The skull: small, long and low, the muzzle square and wide, a dome over the eyes.
            st("Head", 1.012, 0.05, 0.035, 0.035, step=0.012, n_top=2.6, n_bot=2.6),
            st("Head", 0.98, 0.084, 0.058, 0.058, step=0.02, n_top=2.6, n_bot=2.6),
            st("Head", 0.88, 0.09, 0.07, 0.07, step=0.025, n_top=2.4),
            st("Head", 0.72, 0.086, 0.08, 0.075, step=0.03),
            st("Head", 0.56, 0.086, 0.09, 0.08, step=0.03),
            st("Head", 0.4, 0.092, 0.108, 0.086, step=0.03),
            st("Head", 0.26, 0.1, 0.118, 0.092, lift=0.006, step=0.03),
            st("Head", 0.12, 0.104, 0.11, 0.1, step=0.03),
            st("Head", 0.0, 0.1, 0.1, 0.112, step=0.035),
            st("Head", -0.1, 0.095, 0.095, 0.12, step=0.04),
            # The neck: deeper than wide (its long cervical ribs under it), thickening all the way to the shoulders.
            st("Neck10", 0.5, 0.1, 0.1, 0.145, step=0.06),
            st("Neck9", 0.5, 0.112, 0.11, 0.162, step=0.07),
            st("Neck8", 0.5, 0.126, 0.12, 0.182, step=0.08),
            st("Neck7", 0.5, 0.142, 0.132, 0.205, step=0.09),
            st("Neck6", 0.5, 0.162, 0.15, 0.235, step=0.1),
            st("Neck5", 0.5, 0.186, 0.172, 0.27, step=0.1),
            st("Neck4", 0.5, 0.225, 0.21, 0.34, step=0.11),
            st("Neck3", 0.5, 0.27, 0.255, 0.41, step=0.12),
            st("Neck2", 0.5, 0.33, 0.315, 0.5, step=0.12),
            st("Neck1", 0.5, 0.42, 0.39, 0.64, step=0.13),
            # The body: deep, the belly well off the ground.
            st("Spine4", 0.6, 0.6, 0.45, 0.82, step=0.14),
            st("Spine4", 0.1, 0.74, 0.52, 1.05, n_bot=2.3, step=0.14),
            st("Spine3", 0.5, 0.8, 0.57, 1.22, n_bot=2.4, step=0.14),
            st("Spine2", 0.5, 0.84, 0.6, 1.24, n_bot=2.3, step=0.14),
            st("Spine1", 0.5, 0.83, 0.62, 1.1, step=0.14),
            st("Hips", 0.25, 0.8, 0.64, 0.9, step=0.14),
            st("Hips", 0.85, 0.66, 0.6, 0.72, step=0.14),
            # The tail: deep at its root, tapering for most of its length to the whip at its end.
            st("Tail1", 0.5, 0.55, 0.6, 0.62, step=0.15),
            st("Tail2", 0.5, 0.47, 0.53, 0.53, step=0.15),
            st("Tail3", 0.5, 0.4, 0.45, 0.45, step=0.15),
            st("Tail4", 0.5, 0.33, 0.38, 0.37, step=0.15),
            st("Tail5", 0.5, 0.275, 0.32, 0.31, step=0.15),
            st("Tail6", 0.5, 0.22, 0.25, 0.24, step=0.15),
            st("Tail7", 0.5, 0.18, 0.21, 0.2, step=0.15),
            st("Tail8", 0.5, 0.15, 0.17, 0.16, step=0.15),
            st("Tail9", 0.5, 0.125, 0.14, 0.13, step=0.15),
            st("Tail10", 0.5, 0.1, 0.115, 0.105, step=0.15),
            st("Tail11", 0.5, 0.082, 0.092, 0.085, step=0.14),
            st("Tail12", 0.5, 0.066, 0.074, 0.068, step=0.14),
            st("Tail13", 0.5, 0.053, 0.059, 0.054, step=0.13),
            st("Tail14", 0.5, 0.042, 0.047, 0.043, step=0.13),
            st("Tail15", 0.5, 0.034, 0.037, 0.034, step=0.12),
            st("Tail16", 0.5, 0.027, 0.029, 0.027, step=0.12),
            st("Tail17", 0.5, 0.021, 0.023, 0.021, step=0.11),
            st("Tail18", 0.5, 0.017, 0.018, 0.017, step=0.1),
            st("Tail19", 0.5, 0.013, 0.014, 0.013, step=0.1),
            st("Tail20", 0.5, 0.01, 0.011, 0.01, step=0.09),
            st("Tail21", 0.5, 0.008, 0.0085, 0.008, step=0.08),
            st("Tail22", 0.6, 0.006, 0.0062, 0.006, step=0.07),
            st("Tail_end", 0.3, 0.003, 0.003, 0.003, step=0.03),
        ],
        "mouth": {"from": ("Head", 0.45), "to": ("Head", 1.0), "phi": 108.0, "depth": 0.006, "width": 0.1, "band": 3.0},
        # Peg teeth at the front of the muzzle only.
        "teeth": {"from": ("Head", 0.84), "to": ("Head", 0.99), "count": 7, "length": 0.024, "radius": 0.0055,
                  "colour": (0.8, 0.76, 0.64)},
        "lower_teeth": {"from": ("Head", 0.84), "to": ("Head", 0.98), "count": 6, "length": 0.02, "radius": 0.005},
        "eyes": {"at": ("Head", 0.24), "phi": 46.0, "radius": 0.021, "sunk": 0.6, "forward": 10.0, "up": 8.0,
                 "iris": (0.4, 0.3, 0.12), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.26), "phi": 30.0, "size": 0.04, "height": 0.012},
        "mounds": [{"at": ("Head", 0.36), "phi": 0.0, "size": 0.1, "height": 0.03}],
        "nostrils": {"at": ("Head", 0.8), "phi": 30.0, "size": 0.016},
        # The row of spines down the middle of its back and tail.
        "back_plates": {"from": ("Neck4", 0.0), "to": ("Tail15", 0.5), "count": 46, "rows": 1, "shape": "spine",
                        "thick": 0.22, "sink": 0.12, "levels": 2,
                        "sizes": [(0.0, 0.08, 0.1), (0.25, 0.14, 0.16), (0.45, 0.2, 0.22), (0.6, 0.2, 0.2),
                                  (0.8, 0.12, 0.13), (1.0, 0.04, 0.05)],
                        "colour": (0.07, 0.065, 0.055), "rim": (0.12, 0.11, 0.09), "groove": 0.03, "groove_dark": 0.05},
        "limbs": {
            "hind": {
                # The foot's flesh raised over its inclined bones -- the heel pad stands on the ground, not in it.
                "stations": [(0, -0.14, 0.22, 0.4, 0.04), (0, 0.05, 0.4, 0.6, 0.07), (0, 0.35, 0.4, 0.55, 0.06),
                             (0, 0.65, 0.33, 0.4, 0.035), (0, 0.92, 0.26, 0.28, 0.0), (1, 0.15, 0.26, 0.31, -0.025),
                             (1, 0.45, 0.235, 0.27, -0.02), (1, 0.8, 0.21, 0.22, 0.0), (1, 0.97, 0.2, 0.205, 0.0),
                             (2, 0.2, 0.22, 0.17, 0.1), (2, 0.9, 0.27, 0.15, 0.11)],
                "around": 18,
                "digits": {"digits": [(-32.0, 0.17, 0.06, 0.17), (-14.0, 0.19, 0.065, 0.13), (4.0, 0.18, 0.064, 0.1),
                                      (22.0, 0.14, 0.06, 0.03), (38.0, 0.1, 0.05, 0.02)],
                           "flat": 0.6, "claw_curl": 0.5},
            },
            "fore": {
                "stations": [(0, -0.12, 0.18, 0.26, 0.0), (0, 0.05, 0.27, 0.34, 0.035), (0, 0.5, 0.24, 0.27, 0.025),
                             (0, 0.92, 0.19, 0.2, 0.0), (1, 0.2, 0.19, 0.2, 0.012), (1, 0.6, 0.165, 0.17, 0.0),
                             (1, 0.96, 0.15, 0.15, 0.0), (2, 0.15, 0.155, 0.15, 0.0), (2, 0.9, 0.17, 0.155, 0.0)],
                "around": 18,
                "digits": {"digits": [(-34.0, 0.06, 0.06, 0.13), (-14.0, 0.06, 0.065, 0.02), (6.0, 0.06, 0.065, 0.02),
                                      (24.0, 0.055, 0.06, 0.02), (40.0, 0.05, 0.055, 0.02)],
                           "flat": 0.6, "claw_curl": 0.4},
            },
        },
        "skin_detail": {"scales": {"cells": 32.0, "dorsal_size": 0.5, "groove": 0.34, "groove_dark": 0.26, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.6, "depth": 0.012}},
        "texture": 2048,
        # Grey-brown, darker over the back, counter-shaded; faint darker blotches, the tail banded towards the whip.
        "skin": {
            "back": (0.075, 0.07, 0.06),
            "flank": (0.28, 0.25, 0.2),
            "belly": (0.5, 0.46, 0.4),
            "throat": (0.48, 0.44, 0.38),
            "lips": (0.1, 0.09, 0.07),
            "mouth": (0.3, 0.1, 0.08),
            "claws": (0.08, 0.07, 0.06),
            "mottle": 0.18,
            "shank_dark": 0.25,
            "spots": {"colour": (0.05, 0.045, 0.035), "from": ("Neck8", 0.0), "to": ("Tail8", 0.5), "scale": 0.9,
                      "above": 0.32, "strength": 0.35},
            "bands": {"colour": (0.03, 0.028, 0.024), "from": ("Tail6", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.9, "width": 0.3, "strength": 0.45},
        },
    },
}


# Harpactognathus gentryii ("Gentry's grasping jaw", Carpenter et al. 2003; a snout from the Morrison of Wyoming): a
# rhamphorhynchid pterosaur, one of the big ones -- two and a half metres from wingtip to wingtip, a robust skull with
# a thin crest along the top of its snout and big, spaced, hooked teeth, the front ones the biggest; a short neck, a
# short body furred with pycnofibres; a long stiff tail ending in a kite-shaped vane. Its wing the membrane from the
# tip of its long fourth finger to its ankle, a smaller one before the arm and one between the legs. The second map's
# flying raider -- the first thing that comes at the man out of the sky. Drawn on the wing: its origin is its middle,
# at its wings' roots; forward +Y.


HARPACTOGNATHUS = {
    # Fitted by its wingspan as it flies; its height (as it flies, wings level: 0.11 m) is no measure of it.
    "fit": "span",
    "span": 2.5,
    "height": 0.11,
    "skeleton": {
        # The hips at the origin's height, a little behind it: the origin between the shoulders and the hips.
        "hip_height": 0.0,
        "hip_y": -0.08,
        "pelvis_length": 0.04,
        "pelvis_pitch": 0.0,
        "spine": [(0.075, 0.0), (0.075, 2.0)],
        "neck": [(0.045, 18.0), (0.045, 14.0), (0.045, 6.0)],
        "skull": (0.26, -4.0),
        "jaw": (0.24, 0.012, -6.0),
        "jaw_hinge": 0.08,
        "tail": [(0.07, -2.0), (0.068, -1.0), (0.066, 0.0), (0.064, 0.0), (0.062, 0.0), (0.06, 0.0), (0.058, 0.0),
                 (0.056, 0.0)],
        "limbs": {
            # The wing spread as it flies (right side, mirrored): the upper arm out and a little back and up, the
            # forearm out and forward to the wrist, the short hand on, the three small fingers forward and down --
            # and the four long bones of the wing finger out and sweeping back to the tip.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.1, 0.16, 0.045, 0.035], "socket": (0.024, -0.01, 0.006),
                     "spread": [(1.0, -0.25, 0.12), (0.85, 0.5, 0.05), (0.8, 0.55, 0.0), (0.3, 0.8, -0.5)],
                     "wing": [(0.29, (0.98, 0.1, -0.02)), (0.272, (0.99, -0.05, -0.02)), (0.233, (0.97, -0.2, -0.02)),
                              (0.185, (0.9, -0.38, -0.03))]},
            # The legs trailing behind, a little apart, the feet back.
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.075, 0.1, 0.035, 0.028],
                     "socket": (0.016, 0.0, -0.012),
                     "spread": [(0.3, -0.9, -0.3), (0.2, -0.97, -0.05), (0.1, -0.98, 0.1), (0.12, -0.96, 0.12)]},
        },
    },
    "moves": {
        "plan": "flyer",
        # How far the wing folds as it beats (degrees at the elbow, the wrist and the wing finger's root, fully
        # folded).
        "wings": {"elbow": 55.0, "wrist": 10.0, "finger": 70.0},
        # Its cruising wingbeat, about two and a half beats a second (and "walk"): the upper arm through 76 degrees,
        # the forearm and the wing finger after it; the body rising 5 cm on the downstroke.
        "fly": {"period": 0.42, "amplitude": (30.0, 6.0, 9.0, 2.0), "dihedral": 6.0, "fold": 0.3, "twist": 10.0,
                "sweep": 0.0, "sweep_beat": 6.0, "bob": 0.025, "pitch_bob": 2.0, "tail_wave": 1.5, "leg_swing": 4.0,
                "leg_spread": 4.0, "steady": 0.9},
        # Chasing ("run"): quicker, deeper beats, the head down.
        "run": {"period": 0.32, "amplitude": (36.0, 8.0, 11.0, 3.0), "dihedral": 4.0, "fold": 0.36, "twist": 12.0,
                "sweep": 4.0, "sweep_beat": 7.0, "bob": 0.03, "pitch_bob": 2.5, "tail_wave": 2.0, "leg_swing": 5.0,
                "leg_spread": 3.0, "neck_pitch": -6.0, "head_pitch": -4.0, "steady": 0.9},
        "glide": {"period": 3.2, "bank": 5.0, "look": 22.0, "dihedral": 7.0, "trim": 2.0, "tips": 3.0, "fold": 0.04,
                  "head_pitch": -8.0},
        "attack": {"period": 1.0, "lunge": 0.25, "drop": 0.12, "rise": 0.06, "dive": 28.0, "draw": 16.0, "reach": 34.0,
                   "jaw": 44.0, "head_up": 14.0, "head_down": 18.0, "sweep": 26.0, "fold": 0.55},
        "hurt": {"period": 0.45, "knock": 0.06, "roll": 20.0, "recoil": 20.0, "jaw": 30.0},
        # Killed: falling, it tumbles ("fall", looped while it drops); down, it crashes and lies ("death").
        "fall": {"period": 0.9, "nose": 35.0},
        "death": {"period": 1.4, "nose": 14.0, "lie": 0.0, "limp_neck": 10.0, "turn": 30.0},
    },
    "body": {
        "around": 32,
        "soften": 0.01,
        "rough": 0.004,
        "scale": 0.1,
        "throat": 0.25,
        "tips": (0.004, 0.004),
        "trunk": [
            # The skull: long and robust, deep behind the eyes, the snout tapering; its crest ("horns").
            st("Head", 1.012, 0.0042, 0.0042, 0.0042, step=0.004),
            st("Head", 0.99, 0.0088, 0.0098, 0.0088, step=0.006),
            st("Head", 0.92, 0.0118, 0.0138, 0.0118, step=0.008),
            st("Head", 0.8, 0.0138, 0.0168, 0.0138, step=0.01),
            st("Head", 0.65, 0.0158, 0.0198, 0.0158, step=0.01),
            st("Head", 0.5, 0.0188, 0.0228, 0.0178, step=0.01),
            st("Head", 0.36, 0.0228, 0.0268, 0.0208, step=0.01),
            st("Head", 0.24, 0.0268, 0.0298, 0.0238, lift=0.002, step=0.01),
            st("Head", 0.12, 0.0288, 0.0288, 0.0268, step=0.01),
            st("Head", 0.02, 0.0268, 0.0258, 0.0278, step=0.01),
            st("Head", -0.08, 0.0218, 0.0208, 0.0248, step=0.01),
            # The neck: short, furred.
            st("Neck3", 0.5, 0.019, 0.019, 0.022, step=0.012),
            st("Neck2", 0.5, 0.021, 0.02, 0.024, step=0.012),
            st("Neck1", 0.5, 0.025, 0.023, 0.028, step=0.012),
            # The body: short and stout, deep at the chest over the keel of the breastbone.
            st("Spine2", 0.75, 0.034, 0.028, 0.038, step=0.012),
            st("Spine2", 0.25, 0.043, 0.033, 0.05, n_bot=2.3, step=0.012),
            st("Spine1", 0.5, 0.039, 0.031, 0.044, step=0.012),
            st("Hips", 0.4, 0.03, 0.026, 0.03, step=0.012),
            # The tail: long, thin and stiff.
            st("Tail1", 0.4, 0.013, 0.013, 0.013, step=0.015),
            st("Tail2", 0.5, 0.0085, 0.0088, 0.0088, step=0.02),
            st("Tail3", 0.5, 0.0068, 0.007, 0.007, step=0.02),
            st("Tail4", 0.5, 0.0058, 0.006, 0.006, step=0.02),
            st("Tail5", 0.5, 0.005, 0.0052, 0.0052, step=0.02),
            st("Tail6", 0.5, 0.0042, 0.0044, 0.0044, step=0.02),
            st("Tail7", 0.5, 0.0034, 0.0036, 0.0036, step=0.02),
            st("Tail8", 0.6, 0.0026, 0.0027, 0.0027, step=0.02),
            st("Tail_end", 0.3, 0.0015, 0.0015, 0.0015, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.08), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.0015, "width": 0.1, "band": 3.0},
        # Big, spaced, hooked teeth, the front ones the biggest.
        "teeth": {"from": ("Head", 0.4), "to": ("Head", 0.98), "count": 8, "length": 0.014, "radius": 0.0026,
                  "rosette": 0.94, "rosette_width": 0.1, "colour": (0.86, 0.82, 0.72)},
        "lower_teeth": {"from": ("Head", 0.4), "to": ("Head", 0.97), "count": 7, "length": 0.012, "radius": 0.0024},
        "eyes": {"at": ("Head", 0.22), "phi": 52.0, "radius": 0.0105, "sunk": 0.55, "forward": 14.0, "up": 8.0,
                 "iris": (0.6, 0.38, 0.06), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.24), "phi": 30.0, "size": 0.012, "height": 0.003},
        "fossa": {"from": ("Head", 0.34), "to": ("Head", 0.58), "phi": 66.0, "depth": 0.0022, "width": 0.3},
        "nostrils": {"at": ("Head", 0.8), "phi": 40.0, "size": 0.003},
        # The crest: a thin blade of bone along the top of the snout.
        "horns": [{"at": ("Head", 0.6), "phi": 0.0, "length": 0.012, "base": (0.0016, 0.07), "rake": 2.0, "taper": 0.45,
                   "colour": (0.3, 0.1, 0.045), "tip": (0.45, 0.2, 0.07), "bone": "Head", "rings": 6, "around": 10}],
        "limbs": {
            "fore": {
                "stations": [(0, -0.1, 0.012, 0.014, 0.0), (0, 0.15, 0.013, 0.014, 0.002), (0, 0.6, 0.01, 0.011, 0.0),
                             (0, 0.95, 0.008, 0.009, 0.0), (1, 0.2, 0.0085, 0.009, 0.0), (1, 0.6, 0.007, 0.007, 0.0),
                             (1, 0.95, 0.006, 0.006, 0.0), (2, 0.2, 0.006, 0.0055, 0.0), (2, 0.95, 0.007, 0.006, 0.0)],
                "around": 10,
                "digits": {"digits": [(-20.0, 0.022, 0.0022, 0.009), (0.0, 0.025, 0.0022, 0.01), (20.0, 0.022, 0.002, 0.009)],
                           "claw_curl": 1.2, "flat": 0.9},
            },
            "hind": {
                "stations": [(0, -0.15, 0.009, 0.011, 0.0), (0, 0.2, 0.0095, 0.011, 0.001), (0, 0.8, 0.006, 0.0065, 0.0),
                             (1, 0.2, 0.0055, 0.006, 0.0), (1, 0.8, 0.004, 0.0042, 0.0), (2, 0.2, 0.004, 0.0035, 0.0),
                             (2, 0.9, 0.0045, 0.003, 0.0)],
                "around": 10,
                "digits": {"digits": [(-15.0, 0.02, 0.0017, 0.006), (-5.0, 0.023, 0.0018, 0.006), (5.0, 0.023, 0.0018, 0.006),
                                      (15.0, 0.02, 0.0017, 0.006)],
                           "flat": 0.8, "claw_curl": 0.9},
            },
        },
        # The wings (tools/dino_body.py _patagia): dark membranes, darker to their trailing edges, the finger bones
        # paler along their leading edges.
        "patagia": {"colour": (0.075, 0.048, 0.036), "edge": (0.03, 0.02, 0.016), "bone": (0.14, 0.1, 0.075),
                    "rows": 24, "chord": 7, "thick": 0.004, "concave": 0.24, "finger": 0.007, "uro_cut": 0.03},
        # The vane at the end of the tail, red with a dark rim -- a flag it steers with.
        "vane": {"from": ("Tail7", 0.0), "height": 0.055, "thick": 0.003, "colour": (0.42, 0.11, 0.04),
                 "rim": (0.05, 0.025, 0.018), "past": 0.012},
        # Its fur (pycnofibres) over the body, the neck, the back of the head and the upper limbs.
        "coat": {"bones": ("Thigh", "Shin", "UpperArm"), "face": ("Head", 0.16), "bare": ("Head", 0.3)},
        "skin_detail": {"scales": {"cells": 320.0, "dorsal_size": 0.6, "groove": 0.36, "groove_dark": 0.22, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.5, "depth": 0.0006},
                        "feathers": {"coat_cells": 280.0, "coat_stretch": 0.3, "coat_groove": 0.4, "coat_tint": 0.08,
                                     "streak": 0.2},
                        "horn": {"grain": 260.0, "relief": 0.08, "mottle": 0.14, "streak": 0.05}},
        "texture": 2048,
        # Dark brown fur over the back, warmer down the flanks, a pale belly and throat; the crest and the face
        # about it flushed red.
        "skin": {
            "back": (0.05, 0.034, 0.024),
            "flank": (0.2, 0.12, 0.065),
            "belly": (0.5, 0.42, 0.31),
            "throat": (0.52, 0.44, 0.32),
            "lips": (0.1, 0.07, 0.05),
            "mouth": (0.32, 0.08, 0.06),
            "claws": (0.05, 0.04, 0.03),
            "mottle": 0.12,
            "shank_dark": 0.3,
            "flush": {"colour": (0.42, 0.12, 0.05), "from": ("Head", 0.95), "to": ("Head", 0.2), "strength": 0.3},
        },
    },
}


# ==============================================================================
# THE THIRD MAP'S CAST (GAME-DESIGN 7.2, station 3: the Early Cretaceous of north-east China, the Jehol Biota -- the
# Yixian Formation of western Liaoning, about 125 million years ago: cool and temperate, lakes among conifer forests,
# volcanoes whose ash fell on the lakes and kept the feathers of what died in them). Built at their own sizes; the
# game shows each at its "height", head and all.
# ==============================================================================

# Yutyrannus huali ("beautiful feathered tyrant", Xu et al. 2012; the holotype ZCDM V5000 and two smaller ones from
# Batu Yingzi): a basal tyrannosauroid nine metres long and a tonne and a half -- the biggest animal known with
# direct evidence of feathers: long simple filaments over the body, 15 cm by the hips, 16 cm on the upper arm, 20 cm
# on the neck. A skull of 0.9 m, longer, lower and narrower behind than a tyrannosaurid's, a low rugose crest along
# the middle of the snout (the premaxillae and nasals, pitted with air spaces); arms longer than a tyrannosaurid's,
# with three working fingers; long legs without a tyrannosaurid's pinched foot; a lighter build. Derived from the
# Tyrannosaurus: its skull's length from Xu et al. 2012 (905 mm), the rest proportioned as a big basal
# tyrannosauroid's. The third map's boss.


YUTYRANNUS = {
    "height": 2.3,
    # Skull 0.9 m, femur 0.86, tibia 0.82, the long foot bone 0.42 (not pinched); the arm 0.67 m to the wrist, the
    # hand and its three fingers 0.28 more; the tail half the animal.
    "skeleton": {
        "hip_height": 1.92,
        "pelvis_length": 0.62,
        "pelvis_pitch": -6.0,
        "spine": [(0.56, 3.0), (0.56, 0.0), (0.53, -4.0), (0.48, -8.0)],
        "neck": [(0.25, 50.0), (0.24, 40.0), (0.22, 20.0), (0.2, -4.0)],
        "skull": (0.9, -10.0),
        "jaw": (0.84, 0.14, -14.0),
        "jaw_hinge": 0.06,
        "tail": [(0.46, 5.0), (0.45, 1.0), (0.43, -1.0), (0.41, -2.0), (0.39, -2.0), (0.37, -1.0), (0.34, -1.0),
                 (0.31, 0.0), (0.28, 0.0), (0.25, 0.0), (0.22, 0.0), (0.19, 0.0), (0.16, 0.0), (0.13, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.86, 0.82, 0.42, 0.27],
                     "socket": (0.22, 0.0, -0.07), "stance": (0.05, 0.16), "foot": "digitigrade",
                     "foot_tilt": 24.0, "roll_tilt": 35.0, "bend": "forward", "splay": 3.0},
            # The arms held bent before the chest, longer than a tyrannosaurid's: the forearm down and forward, the
            # three fingers hooked.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.4, 0.27, 0.11, 0.17], "socket": (0.22, -0.07, -0.4), "arm": True,
                     "rest_hand": (0.07, 0.34, -0.3), "bend": "back", "splay": 14.0, "hand_angle": 42.0,
                     "finger_angle": 76.0},
        },
    },
    "moves": {
        "plan": "biped",
        # A heavy walk, lighter on its feet than a tyrannosaurid's.
        "walk": {"period": 1.15, "duty": 0.62, "step": 0.13, "bob": 0.034, "sway": 0.026, "hip_yaw": 3.0,
                 "hip_roll": 2.5, "tail_swing": 3.0, "neck_bob": 2.0, "steady": 0.8, "narrow": 0.9, "push": 0.5,
                 "curl": 0.4, "arm_swing": 0.012},
        "run": {"period": 0.82, "duty": 0.44, "step": 0.2, "bob": 0.055, "lean": -4.0, "crouch": 0.055,
                "neck_pitch": -8.0, "tail_lift": 3.0, "head_pitch": 3.0, "tail_swing": 2.0, "steady": 0.85,
                "narrow": 0.85, "push": 0.8},
        "idle": {"period": 5.0, "breaths": 2, "look": 20.0, "nod": 3.0, "swell": 0.02, "tail_swing": 3.0},
        # A bite from above, as the tyrannosaur's: drawn up and back, then driven down and forward.
        "attack": {"period": 1.05, "jaw": 42.0, "lunge": 0.3, "draw": 14.0, "reach": 18.0, "head_up": 10.0,
                   "head_down": 14.0},
        "death": {"period": 1.7, "roll": 84.0, "pivot": 0.48, "slide": 0.18},
    },
    "body": {
        "around": 44,
        "soften": 0.05,
        "rough": 0.02,
        "scale": 0.85,
        "throat": 0.34,
        "trunk": [
            # The skull: deep, the snout broad and blunt at its tip (a tyrannosauroid's U-shaped snout), narrower
            # behind the eyes than a tyrannosaurid's -- they look out to the sides more than forward.
            st("Head", 1.012, 0.026, 0.03, 0.028, step=0.012),
            st("Head", 0.985, 0.052, 0.08, 0.076, step=0.018),
            st("Head", 0.93, 0.064, 0.114, 0.11, step=0.03),
            st("Head", 0.84, 0.071, 0.134, 0.13, step=0.035),
            st("Head", 0.7, 0.08, 0.148, 0.148, step=0.04),
            st("Head", 0.56, 0.092, 0.158, 0.164, step=0.04),
            st("Head", 0.42, 0.109, 0.166, 0.18, step=0.04),
            st("Head", 0.3, 0.13, 0.172, 0.196, lift=0.01, step=0.04),
            st("Head", 0.18, 0.158, 0.166, 0.212, step=0.04),
            st("Head", 0.06, 0.168, 0.15, 0.222, step=0.05),
            st("Head", -0.05, 0.152, 0.136, 0.216, step=0.05),
            st("Head", -0.12, 0.138, 0.128, 0.206, step=0.05),
            # The neck: a strong S, under its mane.
            st("Neck4", 0.5, 0.134, 0.134, 0.198, step=0.06),
            st("Neck3", 0.5, 0.148, 0.146, 0.22, step=0.06),
            st("Neck2", 0.5, 0.17, 0.163, 0.246, step=0.07),
            st("Neck1", 0.5, 0.208, 0.188, 0.288, step=0.07),
            # The body: deep in the chest, lighter than a tyrannosaurid's.
            st("Spine4", 0.6, 0.248, 0.208, 0.35, step=0.08),
            st("Spine4", 0.1, 0.3, 0.26, 0.6, n_bot=2.3, step=0.08),
            st("Spine3", 0.5, 0.348, 0.29, 0.7, n_bot=2.4, step=0.08),
            st("Spine2", 0.5, 0.358, 0.31, 0.66, n_bot=2.3, step=0.08),
            st("Spine1", 0.5, 0.348, 0.318, 0.52, step=0.08),
            # The hips broad over the thighs, which come out of them.
            st("Hips", 0.3, 0.358, 0.31, 0.36, keel=0.014, step=0.08),
            st("Hips", 0.9, 0.29, 0.29, 0.3, keel=0.014, step=0.08),
            st("Tail1", 0.5, 0.214, 0.272, 0.29, step=0.09),
            st("Tail2", 0.5, 0.18, 0.238, 0.248, step=0.09),
            st("Tail3", 0.5, 0.151, 0.204, 0.209, step=0.09),
            st("Tail4", 0.5, 0.126, 0.175, 0.175, step=0.09),
            st("Tail5", 0.5, 0.105, 0.146, 0.146, step=0.09),
            st("Tail6", 0.5, 0.087, 0.121, 0.118, step=0.09),
            st("Tail7", 0.5, 0.072, 0.1, 0.097, step=0.08),
            st("Tail8", 0.5, 0.058, 0.081, 0.078, step=0.08),
            st("Tail9", 0.5, 0.046, 0.064, 0.061, step=0.07),
            st("Tail10", 0.5, 0.035, 0.048, 0.046, step=0.07),
            st("Tail11", 0.5, 0.025, 0.035, 0.033, step=0.06),
            st("Tail12", 0.5, 0.017, 0.023, 0.022, step=0.05),
            st("Tail13", 0.5, 0.011, 0.014, 0.013, step=0.04),
            st("Tail14", 0.6, 0.006, 0.007, 0.007, step=0.03),
            st("Tail_end", 0.3, 0.0025, 0.0025, 0.0025, step=0.015),
        ],
        "mouth": {"from": ("Head", 0.06), "to": ("Head", 1.0), "phi": 106.0, "depth": 0.014, "width": 0.1, "band": 3.0},
        # Blade-like teeth, the front ones (the premaxilla's) D-shaped and small, as a tyrannosauroid's.
        "teeth": {"from": ("Head", 0.28), "to": ("Head", 0.97), "count": 15, "length": 0.055, "radius": 0.012,
                  "colour": (0.78, 0.73, 0.6)},
        "lower_teeth": {"from": ("Head", 0.28), "to": ("Head", 0.93), "count": 14, "length": 0.045, "radius": 0.0105},
        "eyes": {"at": ("Head", 0.27), "phi": 42.0, "radius": 0.028, "sunk": 0.6, "forward": 16.0, "up": 10.0,
                 "iris": (0.7, 0.52, 0.16), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.29), "phi": 26.0, "size": 0.06, "height": 0.02},
        "fossa": {"from": ("Head", 0.4), "to": ("Head", 0.64), "phi": 66.0, "depth": 0.016, "width": 0.3},
        "nostrils": {"at": ("Head", 0.93), "phi": 40.0, "size": 0.016},
        # The crest: low and long down the middle of the snout, from the premaxillae back along the nasals --
        # rugose bone under a horny sheath, darker and redder than the skin.
        "horns": [
            {"at": ("Head", t), "phi": 0.0, "length": h, "base": (0.01, 0.075), "rake": 0.0, "taper": 0.22,
             "colour": (0.15, 0.055, 0.03), "tip": (0.2, 0.1, 0.06), "bone": "Head", "rings": 4, "around": 10}
            for (t, h) in ((0.5, 0.02), (0.57, 0.032), (0.64, 0.04), (0.71, 0.044), (0.78, 0.042), (0.85, 0.034),
                           (0.91, 0.022))
        ],
        "limbs": {
            "hind": {
                # Its top inside the hips, so the thigh comes out of the flank.
                "stations": [(0, -0.28, 0.135, 0.27, 0.03), (0, -0.05, 0.225, 0.355, 0.043), (0, 0.25, 0.248, 0.34, 0.043),
                             (0, 0.55, 0.196, 0.258, 0.024), (0, 0.85, 0.134, 0.162, 0.006), (0, 0.98, 0.115, 0.13, 0.0),
                             (1, 0.1, 0.132, 0.182, -0.033), (1, 0.3, 0.126, 0.182, -0.046), (1, 0.6, 0.094, 0.113, -0.019),
                             (1, 0.95, 0.065, 0.065, 0.0), (2, 0.1, 0.061, 0.055, 0.0), (2, 0.95, 0.055, 0.045, 0.0)],
                "around": 18,
                "digits": {
                    "digits": [(-18.0, 0.25, 0.036, 0.075), (0.0, 0.29, 0.039, 0.085), (18.0, 0.25, 0.036, 0.075)],
                    "hallux": (150.0, 0.1, 0.018, 0.04, 0.12),
                    "flat": 0.8,
                    "claw_curl": 0.6,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.075, 0.094, 0.0), (0, 0.1, 0.082, 0.092, 0.011), (0, 0.5, 0.064, 0.071, 0.01),
                             (0, 0.95, 0.046, 0.049, 0.0), (1, 0.3, 0.047, 0.052, 0.003), (1, 0.95, 0.035, 0.037, 0.0),
                             (2, 0.6, 0.034, 0.025, 0.0)],
                "around": 12,
                # Three fingers, the first short with a big hooked claw, the third slender.
                "digits": {
                    "digits": [(-16.0, 0.1, 0.016, 0.085), (0.0, 0.16, 0.015, 0.07), (16.0, 0.13, 0.012, 0.05)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its coat (tools/dino_feathers.py): long filaments in tufts over the body from behind the eyes to the tip of
        # the tail -- longest on the neck, a mane -- along the arms to the wrists and down the thighs; the face, the
        # shins, the feet and the fingers in scales. The skin under it drawn as plumage in the bake.
        "fuzz": {
            "seed": 11, "width": 0.26, "lie": 9.0, "droop": 0.3, "curve": 0.1, "twist": 25.0, "jitter": 0.4,
            "askew": 0.3, "trunk": [
                {"from": ("Head", 0.16), "to": ("Tail_end", 0.0), "phi": (26.0, 174.0), "spacing": 0.075, "gap": 0.07,
                 "length": [(("Head", 0.16), 0.05), (("Head", -0.12), 0.12), (("Neck3", 0.5), 0.18),
                            (("Neck1", 0.5), 0.2), (("Spine4", 0.5), 0.17), (("Spine2", 0.5), 0.15),
                            (("Tail3", 0.5), 0.15), (("Tail8", 0.5), 0.12), (("Tail12", 0.5), 0.07),
                            (("Tail_end", 0.0), 0.035)],
                 "around": [(26.0, 0.9), (90.0, 0.75), (150.0, 0.9), (174.0, 1.0)]},
                {"from": ("Head", 0.16), "to": ("Tail_end", 0.0), "phi": (0.0, 26.0), "spacing": 0.07, "gap": 0.06,
                 "lie": 22.0, "droop": 0.12, "curve": 0.06,
                 "length": [(("Head", 0.16), 0.06), (("Head", -0.12), 0.16), (("Neck3", 0.5), 0.23),
                            (("Neck1", 0.5), 0.24), (("Spine4", 0.5), 0.2), (("Spine2", 0.5), 0.17),
                            (("Tail3", 0.5), 0.16), (("Tail8", 0.5), 0.12), (("Tail12", 0.5), 0.07),
                            (("Tail_end", 0.0), 0.035)]},
            ],
            "limbs": [
                {"limb": "fore", "from": (0, 0.05), "to": (1, 0.95), "around": (0.0, 360.0), "length": (0.16, 0.09),
                 "spacing": 0.055, "gap": 0.06},
                {"limb": "hind", "from": (0, -0.1), "to": (1, 0.2), "around": (-150.0, 150.0), "length": (0.15, 0.07),
                 "spacing": 0.07, "gap": 0.07},
            ],
        },
        "coat": {"bones": ("Thigh", "UpperArm", "Forearm", "Hand"), "face": ("Head", 0.16), "bare": ("Head", 0.3)},
        "skin_detail": {"scales": {"cells": 50.0, "dorsal_size": 0.5, "groove": 0.36, "groove_dark": 0.28, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.8, "depth": 0.009},
                        "feathers": {"coat_cells": 26.0, "coat_stretch": 0.3, "coat_groove": 0.4, "coat_tint": 0.14,
                                     "streak": 0.22},
                        "horn": {"grain": 80.0, "relief": 0.14, "mottle": 0.14, "streak": 0.06}},
        "texture": 2048,
        # Conjectural (nothing of its colour is known): charcoal over the back, dun grey-brown flanks, a paler belly --
        # a thick grey coat for the Yixian's cold winters (mean yearly temperatures about 10 C, Amiot et al. 2011)
        # and its conifer woods; faint darker saddles down the back, closing into rings round the tail; the crest and
        # the face about it flushed dull red, what it shows off with. Greyer than the tyrannosaur's olive-brown.
        "skin": {
            "back": (0.024, 0.021, 0.018),
            "flank": (0.12, 0.1, 0.08),
            "belly": (0.38, 0.35, 0.3),
            "throat": (0.44, 0.4, 0.34),
            "lips": (0.08, 0.06, 0.05),
            "mouth": (0.32, 0.08, 0.06),
            "claws": (0.04, 0.035, 0.03),
            "mottle": 0.16,
            "shank_dark": 0.35,
            "bands": {"colour": (0.014, 0.012, 0.01), "from": ("Spine4", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.5, "width": 0.28, "strength": 0.55},
            "flush": {"colour": (0.36, 0.11, 0.06), "from": ("Head", 1.0), "to": ("Head", 0.3), "strength": 0.3},
        },
    },
}


# Dilong paradoxus ("the emperor dragon", Xu et al. 2004; IVPP V14243 from the Lujiatun beds): a small basal
# tyrannosauroid, the first of its line found with feathers -- the holotype a metre and sixty, not full grown;
# slender and long-legged, a long low skull with a crest along its top (the fused nasals' ridge, forking in a Y back
# over the eyes), long arms for a tyrannosauroid with three fingers; a coat of simple filaments, about 2 cm long,
# kept by the jaw and along the tail. Derived from the Ornitholestes, its proportions after Xu et al. 2004. The third
# map's pack -- the raiders, and the nest's guards.


DILONG = {
    "height": 0.75,
    # Skull 0.19 m, femur 0.175, tibia 0.21, the long foot bone 0.115; the arm 0.15 m to the wrist, the hand and its
    # fingers 0.085 more; the tail more than half the animal.
    "skeleton": {
        "hip_height": 0.44,
        "pelvis_length": 0.085,
        "pelvis_pitch": -6.0,
        "spine": [(0.12, 5.0), (0.12, 8.0), (0.1, 4.0)],
        "neck": [(0.065, 60.0), (0.062, 50.0), (0.058, 30.0), (0.054, 4.0)],
        "skull": (0.19, -12.0),
        "jaw": (0.175, 0.02, -16.0),
        "jaw_hinge": 0.08,
        "tail": [(0.09, 7.0), (0.09, 3.0), (0.085, 0.0), (0.08, -1.0), (0.08, -1.0), (0.075, -1.0), (0.07, 0.0),
                 (0.065, 0.0), (0.06, 0.0), (0.055, 0.0), (0.05, 0.0), (0.045, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.175, 0.21, 0.115, 0.06],
                     "socket": (0.04, 0.0, -0.008), "stance": (0.006, 0.05), "foot": "digitigrade",
                     "foot_tilt": 22.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms folded before the chest, the hands hanging, palms in.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.085, 0.065, 0.035, 0.05], "socket": (0.032, -0.012, -0.052), "arm": True,
                     "rest_hand": (0.022, 0.06, -0.065), "bend": "back", "splay": 12.0, "hand_angle": 52.0,
                     "finger_angle": 88.0},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 0.46, "duty": 0.6, "step": 0.05, "bob": 0.008, "sway": 0.006, "hip_yaw": 3.0,
                 "hip_roll": 2.0, "tail_swing": 3.0, "neck_bob": 1.5, "steady": 0.7, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.007},
        "run": {"period": 0.34, "duty": 0.35, "step": 0.085, "bob": 0.013, "lean": -6.0, "crouch": 0.018,
                "neck_pitch": -16.0, "tail_lift": 6.0, "head_pitch": 6.0, "tail_swing": 2.0, "steady": 0.8,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 3.6, "breaths": 2, "look": 30.0, "nod": 4.0, "swell": 0.025, "tail_swing": 3.0},
        "attack": {"period": 0.7, "jaw": 44.0, "lunge": 0.08, "draw": 18.0, "reach": 26.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.2, "roll": 86.0, "pivot": 0.06, "slide": 0.05},
        # Asleep, belly down, its neck laid forward and down and turned a little aside, the head on the ground.
        "sleep": {"period": 3.2, "drop": 0.33, "neck": [(-61.0, 8.0), (-7.0, 10.0), (10.0, 10.0), (35.0, 5.0)],
                  "head": (30.0, 10.0, 0.0), "tail": [(-14.0, 6.0), (4.0, 9.0)] + [(1.5, 9.0)] * 10, "tilt": 82.0,
                  "arm_raise": 0.045},
    },
    "body": {
        "around": 40,
        "soften": 0.03,
        "rough": 0.008,
        "scale": 0.12,
        "throat": 0.3,
        "tips": (0.004, 0.01),
        "trunk": [
            # The skull: long and low, the snout narrow and its top straight under the crest; big orbits; the jaw
            # muscles swelling it behind them.
            st("Head", 1.012, 0.006, 0.007, 0.006, step=0.003),
            st("Head", 0.99, 0.0095, 0.0115, 0.0105, step=0.004),
            st("Head", 0.95, 0.0115, 0.0145, 0.0135, step=0.005),
            st("Head", 0.88, 0.0128, 0.0165, 0.0152, step=0.006),
            st("Head", 0.78, 0.0138, 0.0178, 0.0168, step=0.007),
            st("Head", 0.66, 0.0152, 0.0192, 0.0186, step=0.008),
            st("Head", 0.54, 0.0172, 0.021, 0.0205, step=0.008),
            st("Head", 0.42, 0.0205, 0.0232, 0.0228, step=0.008),
            st("Head", 0.3, 0.025, 0.0252, 0.0252, lift=0.0015, step=0.008),
            st("Head", 0.18, 0.0285, 0.0255, 0.0275, step=0.008),
            st("Head", 0.06, 0.0282, 0.0235, 0.0285, step=0.01),
            st("Head", -0.08, 0.0232, 0.0205, 0.0265, step=0.012),
            # The neck: a slender S.
            st("Neck4", 0.5, 0.02, 0.021, 0.0265, step=0.012),
            st("Neck3", 0.5, 0.0222, 0.0228, 0.029, step=0.013),
            st("Neck2", 0.5, 0.0248, 0.0252, 0.0325, step=0.014),
            st("Neck1", 0.5, 0.03, 0.029, 0.0395, step=0.015),
            # The body: slim, a deep chest over the arms, the hips broad over the thighs.
            st("Spine3", 0.7, 0.0377, 0.032, 0.053, step=0.017),
            st("Spine3", 0.15, 0.049, 0.039, 0.086, n_bot=2.3, step=0.018),
            st("Spine2", 0.5, 0.056, 0.046, 0.099, n_bot=2.4, step=0.018),
            st("Spine1", 0.6, 0.054, 0.048, 0.083, n_bot=2.2, step=0.018),
            st("Spine1", 0.15, 0.054, 0.052, 0.07, step=0.018),
            st("Hips", 0.3, 0.061, 0.056, 0.063, keel=0.0035, step=0.018),
            st("Hips", 0.9, 0.05, 0.051, 0.056, keel=0.0035, step=0.018),
            # The tail: deep at its root, then long and slender.
            st("Tail1", 0.5, 0.035, 0.04, 0.045, step=0.02),
            st("Tail2", 0.5, 0.028, 0.032, 0.0345, step=0.02),
            st("Tail3", 0.5, 0.022, 0.0255, 0.026, step=0.024),
            st("Tail4", 0.5, 0.0176, 0.02, 0.02, step=0.024),
            st("Tail5", 0.5, 0.0143, 0.0162, 0.016, step=0.024),
            st("Tail6", 0.5, 0.0116, 0.0133, 0.013, step=0.024),
            st("Tail7", 0.5, 0.0094, 0.0108, 0.0105, step=0.024),
            st("Tail8", 0.5, 0.0075, 0.0087, 0.0084, step=0.024),
            st("Tail9", 0.5, 0.006, 0.0068, 0.0066, step=0.024),
            st("Tail10", 0.5, 0.0047, 0.0052, 0.0051, step=0.024),
            st("Tail11", 0.5, 0.0035, 0.0039, 0.0038, step=0.02),
            st("Tail12", 0.6, 0.0025, 0.0026, 0.0026, step=0.016),
            st("Tail_end", 0.3, 0.0011, 0.0011, 0.0011, step=0.008),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.0018, "width": 0.1, "band": 3.0},
        # Small teeth, the front ones (the premaxilla's) D-shaped in section, a tyrannosauroid's mark.
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 15, "length": 0.0055, "radius": 0.0015,
                  "colour": (0.8, 0.76, 0.66)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 14, "length": 0.0045, "radius": 0.0013},
        "eyes": {"at": ("Head", 0.3), "phi": 52.0, "radius": 0.0095, "sunk": 0.6, "forward": 16.0, "up": 8.0,
                 "iris": (0.62, 0.46, 0.08), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.32), "phi": 34.0, "size": 0.01, "height": 0.003},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.66), "phi": 68.0, "depth": 0.0024, "width": 0.3},
        "nostrils": {"at": ("Head", 0.93), "phi": 46.0, "size": 0.0026},
        # The crest: a low ridge down the middle of the snout (the fused nasals), forking behind into two that run
        # back over the eyes -- a Y seen from above.
        "horns": [
            {"at": ("Head", t), "phi": 0.0, "length": h, "base": (0.0012, 0.012), "rake": 0.0, "taper": 0.25,
             "colour": (0.24, 0.12, 0.05), "tip": (0.3, 0.18, 0.09), "bone": "Head", "rings": 4, "around": 8}
            for (t, h) in ((0.6, 0.0035), (0.65, 0.0048), (0.7, 0.0056), (0.75, 0.0058), (0.8, 0.0055), (0.85, 0.0045),
                           (0.9, 0.003))
        ] + [
            {"at": ("Head", t), "phi": phi, "length": h, "base": (0.0011, 0.011), "rake": 0.0, "splay": 10.0,
             "taper": 0.25, "colour": (0.24, 0.12, 0.05), "tip": (0.3, 0.18, 0.09), "bone": "Head", "rings": 4,
             "around": 8}
            for (t, phi, h) in ((0.56, 7.0, 0.0038), (0.51, 11.0, 0.0042), (0.46, 15.0, 0.0042), (0.41, 19.0, 0.0038),
                                (0.36, 23.0, 0.003))
        ],
        "limbs": {
            "hind": {
                # Its top inside the hips, so the thigh comes out of the flank rather than standing on it.
                "stations": [(0, -0.3, 0.0123, 0.028, 0.0037), (0, -0.06, 0.0242, 0.052, 0.0074),
                             (0, 0.2, 0.0307, 0.0538, 0.0084), (0, 0.5, 0.028, 0.0426, 0.0056), (0, 0.8, 0.019, 0.0255, 0.0018),
                             (0, 0.97, 0.0158, 0.018, 0.0), (1, 0.1, 0.0158, 0.0224, -0.004),
                             (1, 0.3, 0.015, 0.0224, -0.0066), (1, 0.6, 0.0108, 0.0133, -0.0033),
                             (1, 0.95, 0.0075, 0.0083, 0.0), (2, 0.1, 0.0066, 0.0066, 0.0), (2, 0.95, 0.006, 0.0056, 0.0)],
                "around": 16,
                "digits": {
                    "digits": [(0.0, 0.06, 0.0046, 0.013), (-18.0, 0.047, 0.0043, 0.012), (18.0, 0.043, 0.0042, 0.0115)],
                    "hallux": (150.0, 0.018, 0.0027, 0.0075, 0.022),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.012, 0.017, 0.0), (0, 0.1, 0.014, 0.017, 0.0017), (0, 0.45, 0.0115, 0.0136, 0.0025),
                             (0, 0.95, 0.008, 0.009, 0.0), (1, 0.3, 0.0087, 0.0098, 0.0008), (1, 0.95, 0.0061, 0.0066, 0.0),
                             (2, 0.5, 0.0058, 0.0044, 0.0), (2, 0.95, 0.0052, 0.0038, 0.0)],
                "around": 12,
                # Three fingers, the first the shortest with the biggest claw.
                "digits": {
                    "digits": [(-14.0, 0.034, 0.0032, 0.016), (0.0, 0.048, 0.003, 0.014), (14.0, 0.04, 0.0027, 0.011)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its coat (tools/dino_feathers.py): short filaments in tufts from behind the eyes to the tip of the tail, a
        # little longer down the back and the neck; along the arms and down the thighs. The face, the shins, the feet
        # and the hands in scales.
        "fuzz": {
            "seed": 5, "width": 0.3, "lie": 12.0, "droop": 0.25, "curve": 0.1, "twist": 25.0, "jitter": 0.35,
            "askew": 0.3, "trunk": [
                {"from": ("Head", 0.2), "to": ("Tail_end", 0.0), "phi": (24.0, 172.0), "spacing": 0.019, "gap": 0.018,
                 "length": [(("Head", 0.2), 0.01), (("Head", -0.08), 0.018), (("Neck2", 0.5), 0.024),
                            (("Spine2", 0.5), 0.022), (("Tail3", 0.5), 0.022), (("Tail9", 0.5), 0.017),
                            (("Tail_end", 0.0), 0.01)]},
                {"from": ("Head", 0.2), "to": ("Tail_end", 0.0), "phi": (0.0, 24.0), "spacing": 0.017, "gap": 0.014,
                 "lie": 24.0, "droop": 0.1,
                 "length": [(("Head", 0.2), 0.012), (("Head", -0.08), 0.022), (("Neck2", 0.5), 0.03),
                            (("Spine2", 0.5), 0.026), (("Tail3", 0.5), 0.024), (("Tail9", 0.5), 0.018),
                            (("Tail_end", 0.0), 0.01)]},
            ],
            "limbs": [
                {"limb": "fore", "from": (0, 0.05), "to": (1, 0.95), "around": (0.0, 360.0), "length": (0.02, 0.015),
                 "spacing": 0.014, "gap": 0.016},
                {"limb": "hind", "from": (0, -0.1), "to": (1, 0.2), "around": (-150.0, 150.0), "length": (0.022, 0.014),
                 "spacing": 0.016, "gap": 0.018},
            ],
        },
        "coat": {"bones": ("Thigh", "UpperArm", "Forearm"), "face": ("Head", 0.2), "bare": ("Head", 0.34)},
        "skin_detail": {"scales": {"cells": 220.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.001},
                        "feathers": {"coat_cells": 130.0, "coat_stretch": 0.35, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.18},
                        "horn": {"grain": 300.0, "relief": 0.1, "mottle": 0.12, "streak": 0.05}},
        "texture": 2048,
        # Conjectural (nothing of its colour is known): a woodland coat for the Lujiatun's forest floor -- dark
        # olive-umber over the back, dappled darker, olive-khaki flanks, a pale buff throat and belly; a dark stripe
        # from the snout back through the eye; dark rings round the far half of the tail; the crest a dull rust.
        "skin": {
            "back": (0.022, 0.02, 0.008),
            "flank": (0.08, 0.072, 0.03),
            "belly": (0.32, 0.3, 0.2),
            "throat": (0.4, 0.37, 0.26),
            "lips": (0.12, 0.09, 0.05),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.06, 0.05, 0.04),
            "mottle": 0.16,
            "shank_dark": 0.35,
            "spots": {"colour": (0.02, 0.019, 0.01), "from": ("Neck3", 0.0), "to": ("Tail6", 0.5), "scale": 15.0,
                      "above": 0.18, "strength": 0.85},
            "bands": {"colour": (0.025, 0.022, 0.012), "from": ("Tail4", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.07, "width": 0.32, "strength": 0.7},
            "eye_stripe": {"colour": (0.022, 0.02, 0.01), "from": ("Head", 0.97), "to": ("Neck4", 0.6),
                           "phi": 60.0, "width": 14.0},
        },
    },
}


# Sinocalliopteryx gigas ("the giant Chinese beautiful feather", Ji et al. 2007; JMP-V-05-8-01 from the Jianshangou
# beds): the biggest compsognathid -- 2.4 metres, most of it tail; a long low skull, long legs, short arms with big
# hands, the first finger's claw the biggest; clothed in simple filaments up to 10 cm long, the longest over the hips
# and down the legs (its "feathered drumsticks"). What it ate is still inside two of them (Xing et al. 2012): the
# bird Confuciusornis, and a dromaeosaur's leg -- a Sinornithosaurus. Derived from the Ornitholestes. The third map's
# minor boss: at the head of the big raids.


SINOCALLIOPTERYX = {
    "height": 1.1,
    # After Ji et al. 2007: skull 0.22 m, femur 0.23, tibia 0.27, the long foot bone 0.16; the arm 0.17 m to the
    # wrist, the hand and its fingers 0.12 more; the tail sixty per cent of the animal.
    "skeleton": {
        "hip_height": 0.585,
        "pelvis_length": 0.1,
        "pelvis_pitch": -6.0,
        "spine": [(0.14, 5.0), (0.14, 8.0), (0.12, 4.0)],
        "neck": [(0.08, 60.0), (0.075, 50.0), (0.07, 30.0), (0.065, 4.0)],
        "skull": (0.22, -12.0),
        "jaw": (0.203, 0.024, -16.0),
        "jaw_hinge": 0.08,
        "tail": [(0.13, 7.0), (0.13, 3.0), (0.125, 0.0), (0.12, -1.0), (0.12, -1.0), (0.115, -1.0), (0.11, 0.0),
                 (0.105, 0.0), (0.1, 0.0), (0.095, 0.0), (0.09, 0.0), (0.08, 0.0), (0.07, 0.0), (0.06, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.23, 0.27, 0.16, 0.08],
                     "socket": (0.05, 0.0, -0.012), "stance": (0.008, 0.065), "foot": "digitigrade",
                     "foot_tilt": 22.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms folded before the chest, the big hands hanging, palms in.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.1, 0.07, 0.045, 0.075], "socket": (0.045, -0.015, -0.07), "arm": True,
                     "rest_hand": (0.03, 0.07, -0.075), "bend": "back", "splay": 12.0, "hand_angle": 55.0,
                     "finger_angle": 90.0},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 0.5, "duty": 0.6, "step": 0.06, "bob": 0.01, "sway": 0.008, "hip_yaw": 3.0,
                 "hip_roll": 2.0, "tail_swing": 3.0, "neck_bob": 1.5, "steady": 0.7, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.008},
        "run": {"period": 0.38, "duty": 0.35, "step": 0.1, "bob": 0.016, "lean": -6.0, "crouch": 0.022,
                "neck_pitch": -16.0, "tail_lift": 6.0, "head_pitch": 6.0, "tail_swing": 2.0, "steady": 0.8,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 3.8, "breaths": 2, "look": 30.0, "nod": 4.0, "swell": 0.025, "tail_swing": 3.0},
        "attack": {"period": 0.72, "jaw": 46.0, "lunge": 0.1, "draw": 18.0, "reach": 26.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.25, "roll": 86.0, "pivot": 0.08, "slide": 0.06},
        # Asleep, belly down, its neck laid forward and down and turned a little aside, the long tail round beside it.
        "sleep": {"period": 3.4, "drop": 0.44, "neck": [(-61.0, 8.0), (-7.0, 10.0), (10.0, 10.0), (35.0, 5.0)],
                  "head": (30.0, 10.0, 0.0), "tail": [(-14.0, 6.0), (4.0, 8.0)] + [(1.5, 8.0)] * 12, "tilt": 82.0,
                  "arm_raise": 0.04},
    },
    "body": {
        "around": 40,
        "soften": 0.03,
        "rough": 0.008,
        "scale": 0.15,
        "throat": 0.3,
        "tips": (0.004, 0.012),
        "trunk": [
            # The skull: long, low and pointed, as a compsognathid's; big orbits; the jaw muscles swelling it behind.
            st("Head", 1.012, 0.0055, 0.0065, 0.0055, step=0.003),
            st("Head", 0.99, 0.0095, 0.012, 0.0105, step=0.004),
            st("Head", 0.95, 0.0118, 0.0155, 0.0138, step=0.005),
            st("Head", 0.88, 0.0132, 0.0178, 0.0158, step=0.006),
            st("Head", 0.78, 0.0145, 0.0195, 0.0178, step=0.007),
            st("Head", 0.66, 0.0162, 0.0214, 0.0198, step=0.008),
            st("Head", 0.54, 0.0186, 0.0236, 0.022, step=0.008),
            st("Head", 0.42, 0.0222, 0.0262, 0.0248, step=0.008),
            st("Head", 0.3, 0.0272, 0.0285, 0.0276, lift=0.0018, step=0.008),
            st("Head", 0.18, 0.031, 0.029, 0.0305, step=0.008),
            st("Head", 0.06, 0.0305, 0.0268, 0.0318, step=0.01),
            st("Head", -0.08, 0.026, 0.0232, 0.03, step=0.012),
            # The neck: a long S.
            st("Neck4", 0.5, 0.0245, 0.0255, 0.032, step=0.014),
            st("Neck3", 0.5, 0.027, 0.0278, 0.0352, step=0.015),
            st("Neck2", 0.5, 0.0302, 0.0306, 0.0395, step=0.016),
            st("Neck1", 0.5, 0.0365, 0.0355, 0.048, step=0.018),
            # The body: slim, a deep chest over the arms, the hips broad over the thighs.
            st("Spine3", 0.7, 0.047, 0.04, 0.066, step=0.02),
            st("Spine3", 0.15, 0.062, 0.05, 0.108, n_bot=2.3, step=0.022),
            st("Spine2", 0.5, 0.07, 0.058, 0.124, n_bot=2.4, step=0.022),
            st("Spine1", 0.6, 0.068, 0.06, 0.104, n_bot=2.2, step=0.022),
            st("Spine1", 0.15, 0.068, 0.065, 0.088, step=0.022),
            st("Hips", 0.3, 0.076, 0.07, 0.079, keel=0.004, step=0.022),
            st("Hips", 0.9, 0.063, 0.064, 0.07, keel=0.004, step=0.022),
            # The tail: deep at its root, then very long and slender.
            st("Tail1", 0.5, 0.045, 0.051, 0.057, step=0.025),
            st("Tail2", 0.5, 0.037, 0.042, 0.045, step=0.025),
            st("Tail3", 0.5, 0.03, 0.034, 0.035, step=0.03),
            st("Tail4", 0.5, 0.0245, 0.028, 0.028, step=0.03),
            st("Tail5", 0.5, 0.0205, 0.0232, 0.0232, step=0.03),
            st("Tail6", 0.5, 0.0172, 0.0195, 0.0193, step=0.03),
            st("Tail7", 0.5, 0.0144, 0.0164, 0.016, step=0.03),
            st("Tail8", 0.5, 0.012, 0.0137, 0.0133, step=0.03),
            st("Tail9", 0.5, 0.0099, 0.0113, 0.011, step=0.03),
            st("Tail10", 0.5, 0.008, 0.0092, 0.009, step=0.03),
            st("Tail11", 0.5, 0.0064, 0.0073, 0.0071, step=0.03),
            st("Tail12", 0.5, 0.0049, 0.0056, 0.0055, step=0.025),
            st("Tail13", 0.5, 0.0036, 0.004, 0.004, step=0.02),
            st("Tail14", 0.6, 0.0025, 0.0027, 0.0027, step=0.02),
            st("Tail_end", 0.3, 0.0012, 0.0012, 0.0012, step=0.01),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 105.0, "depth": 0.002, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 15, "length": 0.0075, "radius": 0.0018,
                  "colour": (0.8, 0.76, 0.66)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 14, "length": 0.006, "radius": 0.0016},
        "eyes": {"at": ("Head", 0.3), "phi": 52.0, "radius": 0.0105, "sunk": 0.6, "forward": 16.0, "up": 8.0,
                 "iris": (0.66, 0.36, 0.06), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.32), "phi": 34.0, "size": 0.012, "height": 0.0035},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.66), "phi": 68.0, "depth": 0.0028, "width": 0.3},
        "nostrils": {"at": ("Head", 0.94), "phi": 46.0, "size": 0.003},
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.0143, 0.033, 0.0044), (0, -0.06, 0.0286, 0.0616, 0.0088),
                             (0, 0.2, 0.0363, 0.0638, 0.0099), (0, 0.5, 0.033, 0.0506, 0.0066),
                             (0, 0.8, 0.0242, 0.0319, 0.0022), (0, 0.97, 0.0209, 0.0242, 0.0),
                             (1, 0.1, 0.0209, 0.0297, -0.0055), (1, 0.3, 0.0198, 0.0297, -0.0088),
                             (1, 0.6, 0.0143, 0.0176, -0.0044), (1, 0.95, 0.0099, 0.011, 0.0),
                             (2, 0.1, 0.0088, 0.0088, 0.0), (2, 0.95, 0.0079, 0.0075, 0.0)],
                "around": 16,
                "digits": {
                    "digits": [(0.0, 0.08, 0.006, 0.018), (-18.0, 0.062, 0.0056, 0.016), (18.0, 0.056, 0.0055, 0.015)],
                    "hallux": (150.0, 0.025, 0.0035, 0.01, 0.03),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.014, 0.02, 0.0), (0, 0.1, 0.0165, 0.02, 0.002), (0, 0.45, 0.0135, 0.016, 0.003),
                             (0, 0.95, 0.0095, 0.0105, 0.0), (1, 0.3, 0.0102, 0.0115, 0.001), (1, 0.95, 0.0078, 0.0082, 0.0),
                             (2, 0.5, 0.0092, 0.0068, 0.0), (2, 0.95, 0.0088, 0.0062, 0.0)],
                "around": 12,
                # Big hands: three fingers, the first stout with the biggest claw.
                "digits": {
                    "digits": [(-16.0, 0.052, 0.006, 0.036), (0.0, 0.07, 0.0052, 0.028), (16.0, 0.052, 0.0042, 0.019)],
                    "claw_curl": 1.35,
                    "flat": 0.9,
                },
            },
        },
        # Its coat (tools/dino_feathers.py): filaments in tufts from behind the eyes to the tip of the tail, the
        # longest over the hips and the root of the tail; long ones down the thighs and the shins, shorter down the
        # back of the long foot bone -- the feathered drumsticks; along the arms to the wrists. The face, the toes
        # and the hands in scales.
        "fuzz": {
            "seed": 23, "width": 0.28, "lie": 11.0, "droop": 0.3, "curve": 0.1, "twist": 25.0, "jitter": 0.35,
            "askew": 0.3, "trunk": [
                {"from": ("Head", 0.22), "to": ("Tail_end", 0.0), "phi": (24.0, 172.0), "spacing": 0.022, "gap": 0.02,
                 "length": [(("Head", 0.22), 0.012), (("Head", -0.08), 0.025), (("Neck2", 0.5), 0.035),
                            (("Spine2", 0.5), 0.04), (("Hips", 0.5), 0.055), (("Tail2", 0.5), 0.06),
                            (("Tail6", 0.5), 0.04), (("Tail11", 0.5), 0.025), (("Tail_end", 0.0), 0.012)]},
                {"from": ("Head", 0.22), "to": ("Tail_end", 0.0), "phi": (0.0, 24.0), "spacing": 0.02, "gap": 0.016,
                 "lie": 22.0, "droop": 0.12,
                 "length": [(("Head", 0.22), 0.014), (("Head", -0.08), 0.03), (("Neck2", 0.5), 0.045),
                            (("Spine2", 0.5), 0.05), (("Hips", 0.5), 0.075), (("Tail2", 0.5), 0.07),
                            (("Tail6", 0.5), 0.045), (("Tail11", 0.5), 0.025), (("Tail_end", 0.0), 0.012)]},
            ],
            "limbs": [
                {"limb": "fore", "from": (0, 0.05), "to": (1, 0.95), "around": (0.0, 360.0), "length": (0.035, 0.025),
                 "spacing": 0.016, "gap": 0.018},
                {"limb": "hind", "from": (0, -0.1), "to": (1, 0.95), "around": (-150.0, 150.0), "length": (0.07, 0.04),
                 "spacing": 0.02, "gap": 0.02, "droop": 0.4},
                {"limb": "hind", "from": (2, 0.0), "to": (2, 0.75), "around": (-160.0, -20.0), "length": (0.03, 0.018),
                 "spacing": 0.016, "gap": 0.014, "droop": 0.45},
            ],
        },
        "coat": {"bones": ("Thigh", "Shin", "UpperArm", "Forearm"), "face": ("Head", 0.22), "bare": ("Head", 0.36)},
        "skin_detail": {"scales": {"cells": 200.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.001},
                        "feathers": {"coat_cells": 110.0, "coat_stretch": 0.35, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.18}},
        "texture": 2048,
        # Its marks after its relative Sinosauropteryx, whose colours are known (Zhang et al. 2010; Smithwick et al.
        # 2017): countershaded -- dark above, pale below -- a dark mask through the eye, and a tail ringed dark and
        # pale. The rest conjectural: a golden tawny spotted dark brown over the back and flanks (an ambush hunter's
        # in a forest's broken light), a cream belly; the shanks dark.
        "skin": {
            "back": (0.1, 0.058, 0.02),
            "flank": (0.3, 0.19, 0.075),
            "belly": (0.52, 0.45, 0.32),
            "throat": (0.58, 0.5, 0.36),
            "lips": (0.12, 0.08, 0.05),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.06, 0.05, 0.04),
            "mottle": 0.14,
            "shank_dark": 0.45,
            "spots": {"colour": (0.03, 0.018, 0.008), "from": ("Neck3", 0.0), "to": ("Tail5", 0.5), "scale": 7.0,
                      "above": 0.14, "strength": 0.9},
            "bands": {"colour": (0.025, 0.016, 0.008), "from": ("Tail3", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.11, "width": 0.36, "strength": 0.9},
            "eye_stripe": {"colour": (0.015, 0.01, 0.006), "from": ("Head", 0.97), "to": ("Neck4", 0.6),
                           "phi": 58.0, "width": 20.0},
        },
    },
}


# Sinornithosaurus millenii ("the Chinese bird-lizard", Xu, Wang & Wu 1999; IVPP V12811 from the Jianshangou beds):
# a microraptorine dromaeosaur about a metre long -- a long low skull with a big opening before the eye and long
# grooved teeth halfway along the upper jaw (fangs, Gong et al. 2010 thought for venom; most since have not); arms
# long for its size, with wing feathers on them; feathered legs; a stiff tail with a fan; its sickle claw. Its body
# feathers were downy, branched tufts (Xu et al. 2001). Derived from the Velociraptor. The third map's quick
# raider -- past the defences, for the man.


SINORNITHOSAURUS = {
    "height": 0.45,
    # After Xu et al. 1999: skull 0.13 m, femur 0.12, tibia 0.155, the long foot bone 0.068; the arm 0.19 m to the
    # wrist, the hand and its fingers 0.105 more -- near the length of the leg; the tail half the animal.
    "skeleton": {
        "hip_height": 0.31,
        "pelvis_length": 0.05,
        "pelvis_pitch": -8.0,
        "spine": [(0.08, 2.0), (0.08, 4.0), (0.07, 2.0)],
        "neck": [(0.035, 50.0), (0.035, 38.0), (0.032, 18.0), (0.03, -8.0)],
        "skull": (0.13, -10.0),
        "jaw": (0.12, 0.014, -14.0),
        "jaw_hinge": 0.08,
        # Stiff and straight: the bony rods along it let it swing only at its root.
        "tail": [(0.065, 6.0), (0.065, 2.0), (0.06, 0.0), (0.06, 0.0), (0.055, 0.0), (0.055, 0.0), (0.05, 0.0),
                 (0.05, 0.0), (0.045, 0.0), (0.04, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.12, 0.155, 0.068, 0.04],
                     "socket": (0.026, 0.0, -0.006), "stance": (0.003, 0.03), "foot": "digitigrade",
                     "foot_tilt": 20.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms folded as a bird's wings fold: the upper arm back, the forearm forward to the wrist by the
            # chest, the hand back along the flank.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.1, 0.09, 0.045, 0.06], "socket": (0.023, -0.009, -0.035), "arm": True,
                     "rest_hand": (0.04, 0.04, 0.0), "bend": "back", "splay": 10.0, "hand_angle": 172.0,
                     "finger_angle": 178.0, "hand_out": 0.1},
        },
    },
    "moves": {
        "plan": "biped",
        # Quick short steps -- the game's walk (1.6 m/s) a brisk one for an animal with hips a third of a metre up.
        "walk": {"period": 0.3, "duty": 0.6, "step": 0.035, "bob": 0.006, "sway": 0.004, "hip_yaw": 2.5,
                 "hip_roll": 2.0, "tail_swing": 1.5, "neck_bob": 1.5, "steady": 0.8, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.003},
        # A run: level, the head low and forward, the stiff tail out behind; long bounds.
        "run": {"period": 0.22, "duty": 0.34, "step": 0.06, "bob": 0.01, "lean": -5.0, "crouch": 0.014,
                "neck_pitch": -12.0, "tail_lift": 4.0, "head_pitch": 4.0, "tail_swing": 1.0, "steady": 0.85,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 3.0, "breaths": 2, "look": 32.0, "nod": 4.0, "swell": 0.025, "tail_swing": 2.0},
        "attack": {"period": 0.6, "jaw": 44.0, "lunge": 0.06, "draw": 16.0, "reach": 24.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.1, "roll": 86.0, "pivot": 0.045, "slide": 0.035},
        # Asleep, belly down, its neck laid forward and down and turned a little aside, the head on the ground.
        "sleep": {"period": 3.0, "drop": 0.215, "neck": [(-55.0, 8.0), (2.0, 10.0), (15.0, 10.0), (31.0, 5.0)],
                  "head": (12.0, 10.0, 0.0), "tail": [(-10.0, 4.0), (3.0, 6.0)] + [(1.0, 6.0)] * 8, "tilt": 82.0,
                  "arm_raise": 0.0},
    },
    "body": {
        "around": 40,
        "soften": 0.02,
        "rough": 0.006,
        "scale": 0.08,
        "throat": 0.3,
        # The snout's point just past its last ring.
        "tips": (0.003, 0.008),
        "trunk": [
            # The skull: long and low, its snout straighter and deeper than a Velociraptor's, the big opening before
            # the eye.
            st("Head", 1.012, 0.004, 0.0045, 0.004, step=0.002),
            st("Head", 0.99, 0.0068, 0.0086, 0.008, step=0.003),
            st("Head", 0.95, 0.0078, 0.0102, 0.0095, step=0.004),
            st("Head", 0.88, 0.0086, 0.011, 0.0105, step=0.005),
            st("Head", 0.78, 0.0092, 0.0108, 0.0108, step=0.005),
            st("Head", 0.64, 0.0108, 0.0118, 0.0124, step=0.005),
            st("Head", 0.5, 0.0125, 0.013, 0.0138, step=0.005),
            st("Head", 0.36, 0.0158, 0.0162, 0.0168, lift=0.0011, step=0.005),
            st("Head", 0.22, 0.0196, 0.0198, 0.0218, step=0.005),
            st("Head", 0.08, 0.0198, 0.0198, 0.0245, step=0.006),
            st("Head", -0.06, 0.0172, 0.0178, 0.0232, step=0.007),
            # The neck: a feathered S, short and thick.
            st("Neck4", 0.5, 0.0154, 0.017, 0.021, step=0.008),
            st("Neck3", 0.5, 0.0187, 0.0198, 0.0242, step=0.009),
            st("Neck2", 0.5, 0.021, 0.022, 0.0275, step=0.01),
            st("Neck1", 0.5, 0.0242, 0.0248, 0.033, step=0.011),
            st("Spine3", 0.7, 0.032, 0.0286, 0.048, step=0.012),
            st("Spine3", 0.15, 0.04, 0.034, 0.069, n_bot=2.3, step=0.014),
            st("Spine2", 0.5, 0.044, 0.0374, 0.077, n_bot=2.4, step=0.014),
            st("Spine1", 0.6, 0.043, 0.04, 0.067, n_bot=2.2, step=0.014),
            st("Spine1", 0.15, 0.04, 0.042, 0.055, step=0.014),
            st("Hips", 0.3, 0.042, 0.044, 0.048, keel=0.0022, step=0.014),
            st("Hips", 0.9, 0.035, 0.039, 0.042, keel=0.0022, step=0.014),
            st("Tail1", 0.5, 0.0253, 0.0297, 0.032, step=0.016),
            st("Tail2", 0.5, 0.0198, 0.023, 0.0242, step=0.016),
            st("Tail3", 0.5, 0.0154, 0.018, 0.0187, step=0.016),
            st("Tail4", 0.5, 0.0121, 0.0143, 0.0143, step=0.016),
            st("Tail5", 0.5, 0.0099, 0.0115, 0.0115, step=0.016),
            st("Tail6", 0.5, 0.0083, 0.0094, 0.0094, step=0.016),
            st("Tail7", 0.5, 0.0066, 0.0077, 0.0077, step=0.016),
            st("Tail8", 0.5, 0.0055, 0.006, 0.006, step=0.016),
            st("Tail9", 0.5, 0.0044, 0.005, 0.005, step=0.016),
            st("Tail10", 0.6, 0.0033, 0.0033, 0.0033, step=0.016),
            st("Tail_end", 0.3, 0.0017, 0.0017, 0.0017, step=0.006),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.0016, "width": 0.1, "band": 3.0},
        # The fangs: the teeth halfway along the upper jaw the longest.
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 12, "length": 0.0055, "radius": 0.0013,
                  "rosette": 0.62, "rosette_width": 0.07, "colour": (0.8, 0.76, 0.66)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 11, "length": 0.0038, "radius": 0.0011},
        "eyes": {"at": ("Head", 0.3), "phi": 52.0, "radius": 0.0075, "sunk": 0.6, "forward": 18.0, "up": 8.0,
                 "iris": (0.72, 0.38, 0.06), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.32), "phi": 34.0, "size": 0.009, "height": 0.0025},
        "fossa": {"from": ("Head", 0.4), "to": ("Head", 0.66), "phi": 68.0, "depth": 0.0022, "width": 0.3},
        "nostrils": {"at": ("Head", 0.92), "phi": 46.0, "size": 0.0018},
        "limbs": {
            "hind": {
                "stations": [(0, -0.35, 0.0168, 0.0322, 0.0028), (0, -0.08, 0.0266, 0.0462, 0.0063),
                             (0, 0.2, 0.0294, 0.0462, 0.007), (0, 0.5, 0.0252, 0.0364, 0.0049),
                             (0, 0.8, 0.0182, 0.0238, 0.0014), (0, 0.97, 0.0147, 0.0175, 0.0),
                             (1, 0.1, 0.0161, 0.0224, -0.0042), (1, 0.3, 0.0154, 0.0224, -0.0063),
                             (1, 0.6, 0.0112, 0.0133, -0.0028), (1, 0.95, 0.0074, 0.008, 0.0),
                             (2, 0.1, 0.0066, 0.0066, 0.0), (2, 0.95, 0.006, 0.0056, 0.0)],
                "around": 16,
                "digits": {
                    # Two toes forward, the second held up with its sickle claw, the small first one behind.
                    "digits": [(-2.0, 0.048, 0.0042, 0.01), (18.0, 0.042, 0.0039, 0.0085)],
                    "sickle": (-16.0, 0.026, 0.0042, 0.036, 38.0, 2.3),
                    "hallux": (150.0, 0.014, 0.0023, 0.006, 0.016),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.0108, 0.0158, 0.0), (0, 0.1, 0.013, 0.0158, 0.0014), (0, 0.45, 0.0108, 0.013, 0.0022),
                             (0, 0.95, 0.0072, 0.0079, 0.0), (1, 0.3, 0.0079, 0.0086, 0.0007), (1, 0.95, 0.0054, 0.0058, 0.0),
                             (2, 0.5, 0.0047, 0.0036, 0.0), (2, 0.95, 0.0042, 0.0032, 0.0)],
                "around": 12,
                "digits": {
                    "digits": [(0.0, 0.058, 0.0026, 0.013), (-14.0, 0.046, 0.0025, 0.012), (14.0, 0.038, 0.0022, 0.01)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its feathers (tools/dino_feathers.py): wing feathers along the forearm and the hand, longer for its size
        # than a Velociraptor's; a fan down the tail's far half; downy tufts over the body and the neck; feathers
        # round the thighs and down the backs of the shins. The feet, the face and the fingers' ends in scales.
        "wings": {"forearm": 7, "hand": 7, "secondaries": (0.07, 0.1), "primaries": (0.11, 0.15), "width": 0.26,
                  "droop": 0.12, "splay": 0.18, "lift": 0.008, "curve": 0.1, "colour": (0.03, 0.027, 0.025),
                  "tip": (0.2, 0.18, 0.17)},
        "tail_fan": {"from": ("Tail4", 0.0), "length": (0.04, 0.09), "spread": (46.0, 12.0), "spacing": 0.013,
                     "width": 0.34, "droop": 0.05, "colour": (0.16, 0.06, 0.025), "tip": (0.015, 0.013, 0.012)},
        "fuzz": {
            "seed": 31, "width": 0.32, "lie": 12.0, "droop": 0.25, "curve": 0.1, "twist": 25.0, "jitter": 0.35,
            "askew": 0.3, "trunk": [
                {"from": ("Head", 0.3), "to": ("Tail4", 0.2), "phi": (24.0, 172.0), "spacing": 0.012, "gap": 0.011,
                 "length": [(("Head", 0.3), 0.008), (("Head", -0.06), 0.016), (("Neck2", 0.5), 0.022),
                            (("Spine2", 0.5), 0.026), (("Hips", 0.5), 0.028), (("Tail2", 0.5), 0.022),
                            (("Tail4", 0.2), 0.014)]},
                {"from": ("Head", 0.3), "to": ("Tail4", 0.2), "phi": (0.0, 24.0), "spacing": 0.011, "gap": 0.009,
                 "lie": 20.0, "droop": 0.1,
                 "length": [(("Head", 0.3), 0.009), (("Head", -0.06), 0.02), (("Neck2", 0.5), 0.026),
                            (("Spine2", 0.5), 0.028), (("Hips", 0.5), 0.03), (("Tail2", 0.5), 0.024),
                            (("Tail4", 0.2), 0.014)]},
            ],
            "limbs": [
                {"limb": "hind", "from": (0, -0.1), "to": (0, 1.0), "around": (-160.0, 150.0), "length": (0.03, 0.026),
                 "spacing": 0.011, "gap": 0.011, "droop": 0.35, "width": 0.36},
                {"limb": "hind", "from": (1, 0.0), "to": (1, 0.85), "around": (-165.0, -25.0), "length": (0.03, 0.02),
                 "spacing": 0.011, "gap": 0.01, "droop": 0.4, "width": 0.36},
                {"limb": "fore", "from": (0, 0.05), "to": (0, 0.95), "around": (0.0, 360.0), "length": (0.018, 0.014),
                 "spacing": 0.011, "gap": 0.011},
            ],
        },
        "coat": {"bones": ("Thigh", "Shin", "UpperArm", "Forearm"), "face": ("Head", 0.34), "bare": ("Head", 0.5)},
        "skin_detail": {"scales": {"cells": 300.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.0007},
                        "feathers": {"coat_cells": 170.0, "coat_stretch": 0.4, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.14, "barbs": 45.0, "slant": 0.7, "bars": 4.0, "bar_strength": 0.6,
                                     "bar_width": 0.4, "shaft": 0.08, "shaft_light": 0.4}},
        "texture": 2048,
        # After its melanosomes (Zhang et al. 2010: both eumelanin's, black and grey, and phaeomelanin's, reddish-
        # brown, in different parts of it) -- the parts here conjectural: a chestnut red-brown body, darker over the
        # back, a grey-buff belly; slate-black wing feathers tipped grey; the tail ringed dark to its tip, its fan
        # red-brown tipped black and barred dark; a dark mask through the eye.
        "skin": {
            "back": (0.075, 0.028, 0.013),
            "flank": (0.2, 0.078, 0.032),
            "belly": (0.34, 0.29, 0.25),
            "throat": (0.4, 0.34, 0.29),
            "lips": (0.1, 0.06, 0.04),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.04, 0.035, 0.03),
            "mottle": 0.14,
            "shank_dark": 0.35,
            "bands": {"colour": (0.012, 0.01, 0.01), "from": ("Tail2", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.06, "width": 0.34, "strength": 0.85},
            "eye_stripe": {"colour": (0.015, 0.01, 0.008), "from": ("Head", 0.97), "to": ("Neck4", 0.5),
                           "phi": 60.0, "width": 16.0},
        },
    },
}


# Psittacosaurus ("parrot lizard", Osborn 1923; P. lujiatunensis and the Liaoning specimen SMF R 4970 of the Yixian,
# Mayr et al. 2002): an early horned dinosaur two metres long at most, the commonest dinosaur of the Jehol. A short,
# deep, boxy skull with a hooked parrot's beak (its own rostral bone) and a horn out of each cheek (the jugal horns),
# big eyes; a short neck; it walked on its hind legs, its arms short, four fingers on each hand. Along the top of the
# first half of its tail a row of long bristles -- quills up to 16 cm long in SMF R 4970, standing up and back like a
# brush. Its colours are known from that specimen's melanosomes (Vinther et al. 2016): dark brown above, pale below,
# the shading low on its flanks as a forest animal's is (diffuse light, a closed habitat); dark about its face and
# its cheek horns. Scenery on the third map: a herd at the forest's edge by the lake (Config.MAPS herds), never fought.


PSITTACOSAURUS = {
    # Scenery: the herd fits it to its length and walks it at its own pace.
    "fit": "length",
    "length": 1.8,
    # Its strides drawn at the herd's pace (MAPS herds "speed": 0.6), so its feet stay put.
    "paces": {"walk": 0.6, "run": 2.4},
    "skeleton": {
        # The hip joints 0.43 m up (femur 0.17, tibia 0.2 -- a runner's, longer than the femur -- foot bones 0.1).
        "hip_height": 0.44,
        "pelvis_length": 0.08,
        "pelvis_pitch": -4.0,
        # The back rising a little to the shoulders, balanced over the hips.
        "spine": [(0.14, 4.0), (0.14, 7.0), (0.13, 10.0)],
        "neck": [(0.055, 40.0), (0.055, 26.0), (0.05, 8.0)],
        # The short, deep skull, its beak turned down.
        "skull": (0.17, -30.0),
        "jaw": (0.14, 0.04, -36.0),
        "jaw_hinge": 0.14,
        # About half the animal, held out level behind.
        "tail": [(0.1, 4.0), (0.1, 0.0), (0.095, -2.0), (0.09, -3.0), (0.085, -3.0), (0.08, -3.0), (0.075, -2.0),
                 (0.07, -2.0), (0.065, -1.0), (0.06, -1.0), (0.055, 0.0), (0.05, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.17, 0.2, 0.1, 0.07],
                     "socket": (0.05, 0.0, -0.015), "stance": (0.005, 0.04), "foot": "digitigrade",
                     "foot_tilt": 22.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms short, held bent before the chest, off the ground.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.085, 0.065, 0.025, 0.03], "socket": (0.04, -0.03, -0.07), "arm": True,
                     "rest_hand": (0.03, 0.06, -0.045), "bend": "back", "splay": 14.0, "hand_angle": 35.0,
                     "finger_angle": 60.0},
        },
    },
    "moves": {
        "plan": "biped",
        # A light walk at the herd's slow pace.
        "walk": {"period": 0.8, "duty": 0.6, "step": 0.04, "bob": 0.007, "sway": 0.005, "hip_yaw": 3.0,
                 "hip_roll": 2.0, "tail_swing": 3.0, "neck_bob": 1.5, "steady": 0.7, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.006},
        "run": {"period": 0.4, "duty": 0.38, "step": 0.07, "bob": 0.014, "lean": -6.0, "crouch": 0.02,
                "neck_pitch": -10.0, "tail_lift": 4.0, "head_pitch": 5.0, "tail_swing": 2.0, "steady": 0.8,
                "narrow": 0.7, "push": 0.9},
        # Cropping low plants: leaning forward over its hips, its beak at the ground; up now and then to look about.
        "idle": {"period": 6.0, "breaths": 3, "look": 22.0, "nod": 3.0, "swell": 0.02, "tail_swing": 3.0,
                 "graze": {"neck": -30.0, "head": -20.0, "chew": 14.0, "chews": 14, "up": (0.5, 0.8), "pitch": 16.0}},
        "graze": {"period": 5.0},
        # A snap of the beak.
        "attack": {"period": 0.8, "jaw": 30.0, "lunge": 0.05, "draw": 10.0, "reach": 16.0, "head_up": 8.0,
                   "head_down": 8.0},
        "death": {"period": 1.3, "roll": 86.0, "pivot": 0.07, "slide": 0.04},
    },
    "body": {
        "around": 40,
        "soften": 0.02,
        "rough": 0.01,
        "scale": 0.15,
        "throat": 0.3,
        "tips": (0.002, 0.004),
        "trunk": [
            # The skull: a hooked beak, the face rising steeply behind it, deep and short; the cheeks flaring out to
            # the horns under the big eyes.
            st("Head", 1.01, 0.004, 0.008, 0.004, lift=-0.004, step=0.003),
            st("Head", 0.97, 0.009, 0.03, 0.012, step=0.003),
            st("Head", 0.92, 0.014, 0.048, 0.02, step=0.004),
            st("Head", 0.85, 0.02, 0.06, 0.026, step=0.005),
            st("Head", 0.75, 0.027, 0.068, 0.032, step=0.005),
            st("Head", 0.62, 0.035, 0.072, 0.038, step=0.006),
            st("Head", 0.5, 0.044, 0.072, 0.044, step=0.006),
            st("Head", 0.38, 0.054, 0.068, 0.05, step=0.006),
            st("Head", 0.28, 0.064, 0.062, 0.054, n_bot=2.4, step=0.006),
            st("Head", 0.18, 0.058, 0.055, 0.054, step=0.007),
            st("Head", 0.08, 0.046, 0.046, 0.05, step=0.008),
            st("Head", 0.0, 0.038, 0.038, 0.045, step=0.009),
            st("Head", -0.1, 0.033, 0.033, 0.04, step=0.01),
            st("Neck3", 0.5, 0.031, 0.031, 0.04, step=0.01),
            st("Neck2", 0.5, 0.034, 0.034, 0.045, step=0.012),
            st("Neck1", 0.5, 0.042, 0.04, 0.056, step=0.014),
            # The body: a deep chest, the hips over the thighs.
            st("Spine3", 0.7, 0.055, 0.045, 0.075, step=0.016),
            st("Spine3", 0.2, 0.07, 0.052, 0.11, n_bot=2.3, step=0.018),
            st("Spine2", 0.5, 0.082, 0.058, 0.125, n_bot=2.4, step=0.018),
            st("Spine1", 0.5, 0.085, 0.062, 0.115, n_bot=2.3, step=0.018),
            st("Hips", 0.2, 0.08, 0.066, 0.09, step=0.018),
            st("Hips", 0.85, 0.068, 0.062, 0.075, step=0.018),
            # The tail: deep at its root, long and thin.
            st("Tail1", 0.5, 0.055, 0.056, 0.066, step=0.02),
            st("Tail2", 0.5, 0.045, 0.047, 0.054, step=0.02),
            st("Tail3", 0.5, 0.037, 0.04, 0.044, step=0.02),
            st("Tail4", 0.5, 0.03, 0.033, 0.036, step=0.02),
            st("Tail5", 0.5, 0.025, 0.028, 0.029, step=0.02),
            st("Tail6", 0.5, 0.02, 0.023, 0.023, step=0.02),
            st("Tail7", 0.5, 0.016, 0.018, 0.018, step=0.018),
            st("Tail8", 0.5, 0.0125, 0.014, 0.014, step=0.016),
            st("Tail9", 0.5, 0.0095, 0.0105, 0.0105, step=0.014),
            st("Tail10", 0.5, 0.007, 0.0075, 0.0075, step=0.012),
            st("Tail11", 0.5, 0.005, 0.0052, 0.0052, step=0.01),
            st("Tail12", 0.6, 0.003, 0.003, 0.003, step=0.008),
            st("Tail_end", 0.3, 0.0012, 0.0012, 0.0012, step=0.004),
        ],
        # The beak's edge and the jaws behind it: the cheek teeth hidden inside.
        "mouth": {"from": ("Head", 0.15), "to": ("Head", 1.0), "phi": 116.0, "depth": 0.002, "width": 0.1, "band": 3.0,
                  "dark": 3.0},
        "eyes": {"at": ("Head", 0.48), "phi": 46.0, "radius": 0.015, "sunk": 0.6, "forward": 14.0, "up": 8.0,
                 "iris": (0.5, 0.36, 0.12), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.5), "phi": 30.0, "size": 0.014, "height": 0.004},
        "nostrils": {"at": ("Head", 0.86), "phi": 32.0, "size": 0.004},
        # The jugal horns: out and a little down and back from the cheeks.
        "horns": [
            {"at": ("Head", 0.27), "phi": 104.0, "length": 0.032, "base": (0.012, 0.016), "rake": 25.0, "splay": 20.0,
             "taper": 0.9, "colour": (0.05, 0.035, 0.025), "tip": (0.03, 0.022, 0.016), "rings": 4, "around": 8,
             "bone": "Head"},
        ],
        # The bristles: one row of long quills along the top of the tail's first half, standing up and back
        # (tools/dino_feathers.py fuzz), the skin's colour where they grow.
        "fuzz": {
            "seed": 5, "width": 0.07, "lie": 55.0, "droop": 0.04, "curve": 0.06, "twist": 20.0, "jitter": 0.2,
            "askew": 0.08, "trunk": [
                {"from": ("Tail1", 0.3), "to": ("Tail6", 0.5), "phi": (0.0, 3.0), "spacing": 0.011, "gap": 0.02,
                 "length": [(("Tail1", 0.3), 0.06), (("Tail2", 0.5), 0.15), (("Tail4", 0.0), 0.17),
                            (("Tail5", 0.5), 0.12), (("Tail6", 0.5), 0.05)]},
            ],
        },
        "limbs": {
            "hind": {
                "stations": [(0, -0.3, 0.028, 0.042, 0.005), (0, -0.05, 0.044, 0.06, 0.01), (0, 0.25, 0.045, 0.057, 0.01),
                             (0, 0.6, 0.035, 0.042, 0.005), (0, 0.95, 0.023, 0.024, 0.0), (1, 0.12, 0.024, 0.031, -0.006),
                             (1, 0.35, 0.023, 0.03, -0.008), (1, 0.7, 0.015, 0.016, -0.002), (1, 0.97, 0.011, 0.0115, 0.0),
                             (2, 0.15, 0.0095, 0.009, 0.0), (2, 0.95, 0.0095, 0.008, 0.0)],
                "around": 16,
                # Three toes forward, blunt-clawed, and the short first one.
                "digits": {"digits": [(-16.0, 0.065, 0.0065, 0.014), (0.0, 0.075, 0.007, 0.016), (16.0, 0.062, 0.0062, 0.013)],
                           "hallux": (150.0, 0.025, 0.004, 0.008, 0.025), "flat": 0.8, "claw_curl": 0.5},
            },
            "fore": {
                "stations": [(0, -0.15, 0.013, 0.017, 0.0), (0, 0.1, 0.0145, 0.017, 0.002), (0, 0.5, 0.0115, 0.013, 0.002),
                             (0, 0.95, 0.0085, 0.009, 0.0), (1, 0.3, 0.0085, 0.0095, 0.001), (1, 0.95, 0.0062, 0.0066, 0.0),
                             (2, 0.95, 0.006, 0.0045, 0.0)],
                "around": 12,
                # Four fingers, the first three clawed.
                "digits": {"digits": [(-20.0, 0.026, 0.0032, 0.008), (-5.0, 0.031, 0.0033, 0.009), (10.0, 0.029, 0.0031, 0.008),
                                      (25.0, 0.019, 0.0026, 0.004)],
                           "claw_curl": 0.8, "flat": 0.9},
            },
        },
        "skin_detail": {"scales": {"cells": 150.0, "dorsal_size": 0.5, "groove": 0.3, "groove_dark": 0.25, "tint": 0.12,
                                   "speckle": 0.1, "relief": 0.6, "depth": 0.0012}},
        "texture": 1024,
        # After Vinther et al. 2016: dark brown above and down the flanks, cream below; dark round the face, the
        # cheek horns and the beak black.
        "skin": {
            "back": (0.08, 0.045, 0.025),
            "flank": (0.22, 0.13, 0.07),
            "belly": (0.62, 0.55, 0.42),
            "throat": (0.64, 0.57, 0.45),
            "lips": (0.06, 0.04, 0.03),
            "mouth": (0.14, 0.06, 0.05),
            "claws": (0.06, 0.05, 0.04),
            "mottle": 0.14,
            "shank_dark": 0.2,
            "toe_dark": 0.3,
            "horn_base": (0.04, 0.03, 0.02),
            "beak": {"from": ("Head", 0.82), "colour": (0.035, 0.028, 0.022)},
            "eye_stripe": {"colour": (0.04, 0.025, 0.015), "from": ("Head", 0.6), "to": ("Head", 0.12), "phi": 80.0,
                           "width": 26.0},
        },
    },
}


# ==============================================================================
# THE HELL CREEK'S OWN DROMAEOSAURS (the Late Cretaceous of Montana and the Dakotas, the tyrannosaur's country --
# where the Velociraptor, a Mongolian animal, never was).
# ==============================================================================

# Acheroraptor temeertyorum ("the thief from the underworld river", Evans, Larson & Currie 2013; a maxilla and a
# dentary from the Hell Creek of Montana): a velociraptorine, closer to the Asian ones than to any other North
# American -- two and a half to three metres long, a Velociraptor's build grown a third bigger; its snout's maxilla
# long and low, its teeth ridged along their crowns. Known from its jaws alone: the rest after the Velociraptor, from
# which it is derived, its snout straighter (the Velociraptor's dished one is its own) and its body a little stouter.


ACHERORAPTOR = {
    "height": 0.9,
    # The Velociraptor's proportions a third over: skull 0.32 m, femur 0.23, tibia 0.32, the long foot bone 0.12;
    # the tail half the animal.
    "skeleton": {
        "hip_height": 0.594,
        "pelvis_length": 0.12,
        "pelvis_pitch": -8.0,
        "spine": [(0.2, 2.0), (0.2, 4.0), (0.175, 2.0)],
        "neck": [(0.074, 50.0), (0.074, 38.0), (0.068, 18.0), (0.068, -8.0)],
        "skull": (0.32, -11.0),
        "jaw": (0.297, 0.034, -14.0),
        "jaw_hinge": 0.08,
        # Stiff and straight: the bony rods along it let it swing only at its root.
        "tail": [(0.162, 6.0), (0.162, 2.0), (0.149, 0.0), (0.135, 0.0), (0.135, 0.0), (0.122, 0.0), (0.122, 0.0),
                 (0.108, 0.0), (0.108, 0.0), (0.095, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.23, 0.317, 0.122, 0.081],
                     "socket": (0.061, 0.0, -0.0135), "stance": (0.007, 0.068), "foot": "digitigrade",
                     "foot_tilt": 20.0, "roll_tilt": 40.0, "bend": "forward", "splay": 4.0},
            # The arms folded as a bird's wings fold, the hand back along the flank.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.162, 0.149, 0.081, 0.095], "socket": (0.054, -0.02, -0.081), "arm": True,
                     "rest_hand": (0.068, 0.068, 0.0), "bend": "back", "splay": 10.0, "hand_angle": 172.0,
                     "finger_angle": 178.0, "hand_out": 0.1},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 0.58, "duty": 0.6, "step": 0.068, "bob": 0.011, "sway": 0.008, "hip_yaw": 2.5,
                 "hip_roll": 2.0, "tail_swing": 1.5, "neck_bob": 1.5, "steady": 0.8, "narrow": 0.8, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.007},
        "run": {"period": 0.42, "duty": 0.35, "step": 0.12, "bob": 0.019, "lean": -5.0, "crouch": 0.027,
                "neck_pitch": -12.0, "tail_lift": 4.0, "head_pitch": 4.0, "tail_swing": 1.0, "steady": 0.85,
                "narrow": 0.7, "push": 0.9},
        "idle": {"period": 3.8, "breaths": 2, "look": 30.0, "nod": 4.0, "swell": 0.025, "tail_swing": 2.0},
        "attack": {"period": 0.75, "jaw": 44.0, "lunge": 0.135, "draw": 16.0, "reach": 24.0, "head_up": 12.0,
                   "head_down": 6.0},
        "death": {"period": 1.3, "roll": 86.0, "pivot": 0.095, "slide": 0.068},
        "sleep": {"period": 3.4, "drop": 0.405, "neck": [(-55.0, 8.0), (2.0, 10.0), (15.0, 10.0), (31.0, 5.0)],
                  "head": (12.0, 10.0, 0.0), "tail": [(-10.0, 4.0), (3.0, 6.0)] + [(1.0, 6.0)] * 8, "tilt": 82.0},
    },
    "body": {
        "around": 40,
        "soften": 0.04,
        "rough": 0.008,
        "scale": 0.2,
        "throat": 0.3,
        # The snout's point just past its last ring.
        "tips": (0.006, 0.02),
        "trunk": [
            # The skull: long and low, its snout's top straight (no dish), the maxilla long and low.
            st("Head", 1.012, 0.0095, 0.0108, 0.0095, step=0.004),
            st("Head", 1.0, 0.0142, 0.0158, 0.0142, step=0.005),
            st("Head", 0.96, 0.0169, 0.0192, 0.0172, step=0.008),
            st("Head", 0.88, 0.0196, 0.0206, 0.0204, step=0.011),
            st("Head", 0.78, 0.0215, 0.0218, 0.0236, step=0.0135),
            st("Head", 0.64, 0.0263, 0.0246, 0.029, step=0.0135),
            st("Head", 0.5, 0.0292, 0.0292, 0.0328, step=0.0135),
            st("Head", 0.36, 0.0392, 0.0419, 0.0432, lift=0.0027, step=0.0135),
            st("Head", 0.22, 0.05, 0.0527, 0.0567, step=0.0135),
            st("Head", 0.08, 0.05, 0.0513, 0.0635, step=0.016),
            st("Head", -0.06, 0.0432, 0.0459, 0.0594, step=0.019),
            # The neck: a feathered S, short and thick.
            st("Neck4", 0.5, 0.0378, 0.0419, 0.0513, step=0.0216),
            st("Neck3", 0.5, 0.0459, 0.0486, 0.0594, step=0.0243),
            st("Neck2", 0.5, 0.0513, 0.054, 0.0675, step=0.027),
            st("Neck1", 0.5, 0.0612, 0.0625, 0.0834, step=0.027),
            # The body a little stouter than the Velociraptor's.
            st("Spine3", 0.7, 0.0806, 0.0723, 0.1224, step=0.0297),
            st("Spine3", 0.15, 0.1021, 0.0862, 0.1739, n_bot=2.3, step=0.0338),
            st("Spine2", 0.5, 0.1134, 0.0946, 0.1947, n_bot=2.4, step=0.0338),
            st("Spine1", 0.6, 0.1106, 0.1001, 0.1696, n_bot=2.2, step=0.0338),
            st("Spine1", 0.15, 0.1034, 0.1057, 0.139, step=0.0338),
            st("Hips", 0.3, 0.1077, 0.1112, 0.1224, keel=0.0054, step=0.0338),
            st("Hips", 0.9, 0.0907, 0.0988, 0.1057, keel=0.0054, step=0.0338),
            st("Tail1", 0.5, 0.064, 0.0751, 0.0806, step=0.0405),
            st("Tail2", 0.5, 0.05, 0.0584, 0.0612, step=0.0405),
            st("Tail3", 0.5, 0.0389, 0.0459, 0.0473, step=0.0405),
            st("Tail4", 0.5, 0.0306, 0.0362, 0.0362, step=0.0405),
            st("Tail5", 0.5, 0.025, 0.0292, 0.0292, step=0.0405),
            st("Tail6", 0.5, 0.0209, 0.0237, 0.0237, step=0.0405),
            st("Tail7", 0.5, 0.0167, 0.0195, 0.0195, step=0.0405),
            st("Tail8", 0.5, 0.0139, 0.0153, 0.0153, step=0.0405),
            st("Tail9", 0.5, 0.0111, 0.0125, 0.0125, step=0.0405),
            st("Tail10", 0.6, 0.0083, 0.0083, 0.0083, step=0.0405),
            st("Tail_end", 0.3, 0.0041, 0.0041, 0.0041, step=0.0135),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.004, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 15, "length": 0.0115, "radius": 0.0027,
                  "colour": (0.78, 0.74, 0.64)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 14, "length": 0.0085, "radius": 0.0022},
        "eyes": {"at": ("Head", 0.3), "phi": 52.0, "radius": 0.0168, "sunk": 0.6, "forward": 18.0, "up": 8.0,
                 "iris": (0.74, 0.56, 0.12), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.32), "phi": 34.0, "size": 0.0216, "height": 0.0068},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.62), "phi": 70.0, "depth": 0.0054, "width": 0.3},
        "nostrils": {"at": ("Head", 0.93), "phi": 48.0, "size": 0.0047},
        "limbs": {
            "hind": {
                "stations": [(0, -0.35, 0.0324, 0.0621, 0.0054), (0, -0.08, 0.0513, 0.0891, 0.0121),
                             (0, 0.2, 0.0567, 0.0891, 0.0135), (0, 0.5, 0.0486, 0.0702, 0.0095),
                             (0, 0.8, 0.0351, 0.0459, 0.0027), (0, 0.97, 0.0284, 0.0338, 0.0),
                             (1, 0.1, 0.0311, 0.0432, -0.0081), (1, 0.3, 0.0297, 0.0432, -0.0121),
                             (1, 0.6, 0.0216, 0.0257, -0.0054), (1, 0.95, 0.0142, 0.0155, 0.0),
                             (2, 0.1, 0.0128, 0.0128, 0.0), (2, 0.95, 0.0115, 0.0108, 0.0)],
                "around": 16,
                "digits": {
                    # Two toes forward, the second held up with its sickle claw, the small first one behind.
                    "digits": [(-2.0, 0.1013, 0.0088, 0.0203), (18.0, 0.0878, 0.0081, 0.0175)],
                    "sickle": (-16.0, 0.054, 0.0088, 0.0783, 38.0, 2.3),
                    "hallux": (150.0, 0.0297, 0.0047, 0.0121, 0.0338),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.0203, 0.0297, 0.0), (0, 0.1, 0.0243, 0.0297, 0.0027), (0, 0.45, 0.0203, 0.0243, 0.0041),
                             (0, 0.95, 0.0135, 0.0149, 0.0), (1, 0.3, 0.0149, 0.0162, 0.0014), (1, 0.95, 0.0101, 0.0108, 0.0),
                             (2, 0.6, 0.0088, 0.0068, 0.0)],
                "around": 12,
                "digits": {
                    "digits": [(0.0, 0.0945, 0.0049, 0.0243), (-14.0, 0.0743, 0.0046, 0.0216), (14.0, 0.0607, 0.0041, 0.0189)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its feathers (tools/dino_feathers.py), as the Velociraptor's: wing feathers along the forearm and the hand,
        # a fan down the tail's far half, a coat over the body and the upper legs and arms; the feet and the face
        # scaled.
        "wings": {"forearm": 7, "hand": 7, "secondaries": (0.12, 0.175), "primaries": (0.19, 0.255), "width": 0.26,
                  "droop": 0.12, "splay": 0.18, "lift": 0.016, "curve": 0.1, "colour": (0.02, 0.02, 0.022),
                  "tip": (0.55, 0.53, 0.5)},
        "tail_fan": {"from": ("Tail4", 0.0), "length": (0.095, 0.215), "spread": (46.0, 12.0), "spacing": 0.027,
                     "width": 0.34, "droop": 0.05, "colour": (0.03, 0.03, 0.032), "tip": (0.55, 0.53, 0.5)},
        "coat": {"bones": ("Thigh", "Shin", "UpperArm", "Forearm"), "face": ("Head", 0.36), "bare": ("Head", 0.52)},
        "skin_detail": {"scales": {"cells": 126.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.0016},
                        "feathers": {"coat_cells": 70.0, "coat_stretch": 0.4, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.14, "barbs": 45.0, "slant": 0.7, "bars": 5.0, "bar_strength": 0.5,
                                     "bar_width": 0.35, "shaft": 0.08, "shaft_light": 0.4}},
        "texture": 2048,
        # Conjectural (nothing of its colour is known): slate grey over the back, flecked pale, grey flanks, a white
        # throat and belly; a dark stripe through the eye; slate wing and tail feathers tipped white and barred dark,
        # dark rings down the tail. Apart from the Velociraptor's sand and its alpha's black and rust.
        "skin": {
            "back": (0.035, 0.035, 0.038),
            "flank": (0.11, 0.105, 0.1),
            "belly": (0.5, 0.48, 0.45),
            "throat": (0.56, 0.54, 0.5),
            "lips": (0.08, 0.07, 0.065),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.04, 0.04, 0.04),
            "mottle": 0.12,
            "shank_dark": 0.3,
            "spots": {"colour": (0.46, 0.45, 0.42), "from": ("Neck2", 0.0), "to": ("Tail6", 0.5), "scale": 70.0,
                      "above": 0.34, "strength": 0.45},
            "bands": {"colour": (0.015, 0.015, 0.016), "from": ("Tail3", 0.0), "to": ("Tail_end", 0.5),
                      "period": 0.12, "width": 0.3, "strength": 0.6},
            "eye_stripe": {"colour": (0.012, 0.012, 0.014), "from": ("Head", 1.0), "to": ("Neck4", 0.5),
                           "phi": 60.0, "width": 16.0},
        },
    },
}


# Dakotaraptor steini (DePalma et al. 2015; from the Hell Creek of South Dakota): a giant dromaeosaur, four and a
# half to six metres long -- the big ones' size, but built for running, its legs long; a great sickle claw on each
# foot; and on its ulna a row of quill knobs, where the wing feathers were anchored -- feathered arms on an animal far
# too big to fly. Its skull unknown:
# drawn after its kin's (Utahraptor's, Dromaeosaurus's) -- deeper in the snout than a Velociraptor's. Derived from the
# Velociraptor.


DAKOTARAPTOR = {
    "height": 1.5,
    # After DePalma et al. 2015: femur 0.5 m, tibia 0.58, the long foot bone 0.26; the arm 0.57 to the wrist, the
    # hand and its fingers 0.31 more; the skull (unknown) 0.5 m; the tail half the animal.
    "skeleton": {
        "hip_height": 1.2,
        "pelvis_length": 0.22,
        "pelvis_pitch": -8.0,
        "spine": [(0.37, 2.0), (0.37, 4.0), (0.32, 2.0)],
        "neck": [(0.15, 50.0), (0.15, 38.0), (0.135, 18.0), (0.13, -8.0)],
        "skull": (0.5, -12.0),
        "jaw": (0.465, 0.055, -15.0),
        "jaw_hinge": 0.08,
        # Stiff and straight: the bony rods along it let it swing only at its root.
        "tail": [(0.29, 6.0), (0.29, 2.0), (0.27, 0.0), (0.245, 0.0), (0.245, 0.0), (0.22, 0.0), (0.22, 0.0),
                 (0.195, 0.0), (0.195, 0.0), (0.17, 0.0)],
        "limbs": {
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [0.5, 0.58, 0.26, 0.17],
                     "socket": (0.12, 0.0, -0.03), "stance": (0.015, 0.14), "foot": "digitigrade",
                     "foot_tilt": 20.0, "roll_tilt": 38.0, "bend": "forward", "splay": 4.0},
            # The arms folded as a bird's wings fold, the hand back along the flank.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.3, 0.27, 0.14, 0.17], "socket": (0.1, -0.04, -0.15), "arm": True,
                     "rest_hand": (0.12, 0.12, 0.0), "bend": "back", "splay": 10.0, "hand_angle": 172.0,
                     "finger_angle": 178.0, "hand_out": 0.1},
        },
    },
    "moves": {
        "plan": "biped",
        "walk": {"period": 0.75, "duty": 0.6, "step": 0.12, "bob": 0.02, "sway": 0.015, "hip_yaw": 2.5,
                 "hip_roll": 2.0, "tail_swing": 1.5, "neck_bob": 1.5, "steady": 0.8, "narrow": 0.85, "push": 0.6,
                 "curl": 0.5, "arm_swing": 0.012},
        # A run: level, long strides, the head low and forward, the stiff tail out behind.
        "run": {"period": 0.56, "duty": 0.36, "step": 0.22, "bob": 0.034, "lean": -5.0, "crouch": 0.049,
                "neck_pitch": -12.0, "tail_lift": 4.0, "head_pitch": 4.0, "tail_swing": 1.0, "steady": 0.85,
                "narrow": 0.75, "push": 0.9},
        "idle": {"period": 4.4, "breaths": 2, "look": 26.0, "nod": 3.0, "swell": 0.022, "tail_swing": 2.0},
        "attack": {"period": 0.9, "jaw": 44.0, "lunge": 0.24, "draw": 16.0, "reach": 22.0, "head_up": 12.0,
                   "head_down": 8.0},
        "death": {"period": 1.5, "roll": 86.0, "pivot": 0.17, "slide": 0.12},
        "sleep": {"period": 3.8, "drop": 0.82, "neck": [(-55.0, 8.0), (2.0, 10.0), (15.0, 10.0), (31.0, 5.0)],
                  "head": (12.0, 10.0, 0.0), "tail": [(-10.0, 4.0), (3.0, 6.0)] + [(1.0, 6.0)] * 8, "tilt": 82.0},
    },
    "body": {
        "around": 40,
        "soften": 0.05,
        "rough": 0.01,
        "scale": 0.36,
        "throat": 0.3,
        # The snout's point just past its last ring.
        "tips": (0.01, 0.03),
        "trunk": [
            # The skull: a big dromaeosaur's -- deeper in the snout than a Velociraptor's, its top straight.
            st("Head", 1.012, 0.0146, 0.0175, 0.0155, step=0.008),
            st("Head", 1.0, 0.0225, 0.0265, 0.024, step=0.01),
            st("Head", 0.96, 0.027, 0.032, 0.03, step=0.014),
            st("Head", 0.88, 0.031, 0.036, 0.035, step=0.02),
            st("Head", 0.78, 0.034, 0.039, 0.04, step=0.024),
            st("Head", 0.64, 0.041, 0.044, 0.049, step=0.024),
            st("Head", 0.5, 0.046, 0.051, 0.056, step=0.024),
            st("Head", 0.36, 0.0603, 0.0645, 0.0666, lift=0.0042, step=0.024),
            st("Head", 0.22, 0.077, 0.0811, 0.0874, step=0.024),
            st("Head", 0.08, 0.077, 0.079, 0.0978, step=0.028),
            st("Head", -0.06, 0.0666, 0.0707, 0.0915, step=0.033),
            # The neck: a feathered S, short and thick.
            st("Neck4", 0.5, 0.0672, 0.0744, 0.0912, step=0.0384),
            st("Neck3", 0.5, 0.0816, 0.0864, 0.1056, step=0.0432),
            st("Neck2", 0.5, 0.0912, 0.096, 0.12, step=0.048),
            st("Neck1", 0.5, 0.108, 0.11, 0.147, step=0.048),
            st("Spine3", 0.7, 0.146, 0.131, 0.222, step=0.0528),
            st("Spine3", 0.15, 0.181, 0.156, 0.315, n_bot=2.3, step=0.06),
            st("Spine2", 0.5, 0.2, 0.171, 0.353, n_bot=2.4, step=0.06),
            st("Spine1", 0.6, 0.195, 0.181, 0.307, n_bot=2.2, step=0.06),
            st("Spine1", 0.15, 0.183, 0.191, 0.252, step=0.06),
            st("Hips", 0.3, 0.19, 0.2, 0.22, keel=0.0096, step=0.06),
            st("Hips", 0.9, 0.16, 0.177, 0.19, keel=0.0096, step=0.06),
            st("Tail1", 0.5, 0.1135, 0.133, 0.143, step=0.072),
            st("Tail2", 0.5, 0.0888, 0.1035, 0.1085, step=0.072),
            st("Tail3", 0.5, 0.069, 0.0813, 0.0838, step=0.072),
            st("Tail4", 0.5, 0.0542, 0.0641, 0.0641, step=0.072),
            st("Tail5", 0.5, 0.0444, 0.0518, 0.0518, step=0.072),
            st("Tail6", 0.5, 0.037, 0.0419, 0.0419, step=0.072),
            st("Tail7", 0.5, 0.0296, 0.0345, 0.0345, step=0.072),
            st("Tail8", 0.5, 0.0247, 0.0271, 0.0271, step=0.072),
            st("Tail9", 0.5, 0.0197, 0.0222, 0.0222, step=0.072),
            st("Tail10", 0.6, 0.0148, 0.0148, 0.0148, step=0.072),
            st("Tail_end", 0.3, 0.0074, 0.0074, 0.0074, step=0.024),
        ],
        "mouth": {"from": ("Head", 0.1), "to": ("Head", 1.0), "phi": 104.0, "depth": 0.006, "width": 0.1, "band": 3.0},
        "teeth": {"from": ("Head", 0.3), "to": ("Head", 0.97), "count": 15, "length": 0.02, "radius": 0.0045,
                  "colour": (0.78, 0.74, 0.64)},
        "lower_teeth": {"from": ("Head", 0.3), "to": ("Head", 0.93), "count": 14, "length": 0.015, "radius": 0.0038},
        "eyes": {"at": ("Head", 0.3), "phi": 50.0, "radius": 0.024, "sunk": 0.6, "forward": 18.0, "up": 8.0,
                 "iris": (0.76, 0.62, 0.1), "pupil": (0.008, 0.006, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.32), "phi": 32.0, "size": 0.034, "height": 0.011},
        "fossa": {"from": ("Head", 0.42), "to": ("Head", 0.64), "phi": 68.0, "depth": 0.008, "width": 0.3},
        "nostrils": {"at": ("Head", 0.93), "phi": 46.0, "size": 0.0075},
        "limbs": {
            "hind": {
                # Long, a runner's: the thigh's muscle long, the shank slender.
                "stations": [(0, -0.35, 0.068, 0.13, 0.011), (0, -0.08, 0.108, 0.187, 0.025),
                             (0, 0.2, 0.119, 0.187, 0.028), (0, 0.5, 0.102, 0.147, 0.02),
                             (0, 0.8, 0.074, 0.096, 0.0057), (0, 0.97, 0.06, 0.071, 0.0),
                             (1, 0.1, 0.06, 0.084, -0.016), (1, 0.3, 0.058, 0.084, -0.024),
                             (1, 0.6, 0.04, 0.048, -0.01), (1, 0.95, 0.026, 0.029, 0.0),
                             (2, 0.1, 0.024, 0.024, 0.0), (2, 0.95, 0.021, 0.02, 0.0)],
                "around": 16,
                "digits": {
                    # Two toes forward, the second held up with its great sickle claw, the small first one behind.
                    "digits": [(-2.0, 0.18, 0.0156, 0.036), (18.0, 0.156, 0.0144, 0.0312)],
                    "sickle": (-16.0, 0.1, 0.017, 0.19, 38.0, 2.3),
                    "hallux": (150.0, 0.0528, 0.0084, 0.0216, 0.06),
                    "flat": 0.85,
                },
            },
            "fore": {
                "stations": [(0, -0.15, 0.04, 0.058, 0.0), (0, 0.1, 0.048, 0.058, 0.005), (0, 0.45, 0.04, 0.048, 0.008),
                             (0, 0.95, 0.027, 0.029, 0.0), (1, 0.3, 0.029, 0.032, 0.0026), (1, 0.95, 0.02, 0.021, 0.0),
                             (2, 0.6, 0.017, 0.013, 0.0)],
                "around": 12,
                "digits": {
                    "digits": [(0.0, 0.168, 0.0092, 0.046), (-14.0, 0.132, 0.0088, 0.041), (14.0, 0.108, 0.0078, 0.036)],
                    "claw_curl": 1.3,
                    "flat": 0.9,
                },
            },
        },
        # Its feathers (tools/dino_feathers.py): wing feathers along the forearm (its quill knobs) and the hand, a fan
        # down the tail's far half, a coat over the body and the upper legs and arms; the feet and the face scaled.
        "wings": {"forearm": 8, "hand": 7, "secondaries": (0.25, 0.36), "primaries": (0.38, 0.5), "width": 0.26,
                  "droop": 0.12, "splay": 0.18, "lift": 0.028, "curve": 0.1, "colour": (0.025, 0.017, 0.012),
                  "tip": (0.36, 0.32, 0.26)},
        "tail_fan": {"from": ("Tail4", 0.0), "length": (0.17, 0.38), "spread": (46.0, 12.0), "spacing": 0.048,
                     "width": 0.34, "droop": 0.05, "colour": (0.03, 0.02, 0.014), "tip": (0.6, 0.58, 0.53)},
        "coat": {"bones": ("Thigh", "Shin", "UpperArm", "Forearm"), "face": ("Head", 0.36), "bare": ("Head", 0.52)},
        "skin_detail": {"scales": {"cells": 70.0, "dorsal_size": 0.5, "groove": 0.38, "groove_dark": 0.28, "tint": 0.14,
                                   "speckle": 0.1, "relief": 0.7, "depth": 0.003},
                        "feathers": {"coat_cells": 40.0, "coat_stretch": 0.4, "coat_groove": 0.35, "coat_tint": 0.12,
                                     "streak": 0.14, "barbs": 45.0, "slant": 0.7, "bars": 5.0, "bar_strength": 0.45,
                                     "bar_width": 0.35, "shaft": 0.08, "shaft_light": 0.4}},
        "texture": 2048,
        # Conjectural (nothing of its colour is known): dark umber above and down the flanks, sharply white below and
        # up the throat -- an osprey's countershading -- the dark running forward through the eye; dark wing feathers
        # tipped buff, the tail's fan dark with a white end.
        "skin": {
            "back": (0.03, 0.02, 0.013),
            "flank": (0.055, 0.037, 0.024),
            "belly": (0.6, 0.57, 0.52),
            "throat": (0.64, 0.61, 0.56),
            "lips": (0.07, 0.05, 0.035),
            "mouth": (0.3, 0.07, 0.06),
            "claws": (0.03, 0.025, 0.02),
            "mottle": 0.12,
            "shank_dark": 0.3,
            "eye_stripe": {"colour": (0.012, 0.009, 0.007), "from": ("Head", 1.0), "to": ("Neck4", 0.5),
                           "phi": 64.0, "width": 18.0},
        },
    },
}


# ==============================================================================
# THE FOURTH MAP'S PLANT-EATERS (GAME-DESIGN 7.2, station 4: the Hell Creek Formation of Montana and the Dakotas, the
# last two million years of the Cretaceous): built at their own sizes.
# ==============================================================================

# Triceratops horridus (Marsh 1889; Hatcher, Marsh and Lull 1907; the "Hatcher" composite USNM 4842, "Lane" HMNS PR
# 2440 with its skin): eight metres of it and the commonest big animal of the Hell Creek. A skull two metres long with
# its frill -- the frill solid bone, unpierced (the parietals and squamosals), its edge set with small bony points
# (the epoccipitals); a long horn over each eye, a short one over the nostrils, a narrow hooked beak (the rostral and
# the predentary), a little point out of each cheek (the epijugal). A short neck under the frill, a broad barrel of a
# body, a short thick tail; four columns of legs, the hind longer, so its back falls to the shoulders; the forelegs
# held under it with the elbows a little out (Fujiwara 2009; the Ceratopsipes trackways), five fingers, the first
# three hoofed. Its skin (Lane): big polygonal scales, and bigger round ones among them each with a low cone at its
# middle. Colour unknown: drawn a muted grey-brown. The fourth map's frightened charger: it rams the cabin as the
# stegosaur does, its horns before it.


TRICERATOPS = {
    # No Config.DINOS row yet: the game shows it 2.6 m high, head and all (fitted by its height).
    "height": 2.6,
    # Its strides drawn at its own paces: a heavy walk, and the trot it charges at.
    "paces": {"walk": 0.8, "run": 2.4},
    "skeleton": {
        # The hip joints 2.2 m up (femur 1.1, tibia 0.84, the foot bones 0.32): the back over them 2.6 m.
        "hip_height": 2.3,
        "pelvis_length": 0.62,
        "pelvis_pitch": 0.0,
        # The back from the hips forward and down to the low shoulders.
        "spine": [(0.7, -3.0), (0.7, -6.0), (0.7, -12.0), (0.65, -22.0)],
        # A short neck curving down under the frill; the head held low, the beak a metre off the ground.
        "neck": [(0.26, -38.0), (0.25, -28.0), (0.24, -12.0)],
        "skull": (1.25, -24.0),
        "jaw": (1.05, 0.2, -22.0),
        "jaw_hinge": 0.13,
        # Short and thick, hanging from the hips.
        "tail": [(0.34, -20.0), (0.32, -27.0), (0.3, -32.0), (0.28, -35.0), (0.26, -36.0), (0.24, -35.0),
                 (0.22, -32.0), (0.2, -28.0), (0.18, -23.0), (0.15, -18.0), (0.11, -12.0)],
        "limbs": {
            # Columns: the knee a little bent, the foot bones near upright on a pad, four hoofed toes.
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [1.1, 0.84, 0.32, 0.22],
                     "socket": (0.4, 0.0, -0.1), "stance": (0.0, 0.06), "foot": "digitigrade", "foot_tilt": 24.0,
                     "roll_tilt": 30.0, "bend": "forward", "splay": 3.0},
            # The forelegs shorter, under the chest, the elbows a little out, the hands a little wider than the feet.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.78, 0.56, 0.2, 0.14], "socket": (0.44, -0.2, -0.32), "stance": (0.14, 0.12),
                     "foot": "digitigrade", "foot_tilt": 12.0, "roll_tilt": 25.0, "bend": "back", "splay": 14.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        # A heavy walk, each foot down most of its cycle, the body rolling a little over them.
        "walk": {"period": 1.5, "duty": 0.7, "step": 0.12, "bob": 0.025, "snake": 1.5, "tail_swing": 3.0,
                 "order": "walk", "steady": 0.75, "push": 0.5, "curl": 0.3, "hip_roll": 2.0},
        # Its charge: a heavy trot, head down, the horns before it.
        "run": {"period": 0.75, "duty": 0.45, "step": 0.17, "bob": 0.045, "snake": 1.5, "tail_swing": 2.5,
                "order": "trot", "lean": 2.0, "steady": 0.6, "push": 0.7, "curl": 0.4, "neck_pitch": -10.0,
                "head_pitch": -8.0},
        # Cropping low plants with its beak, swinging its head a little; up now and then to look about.
        "idle": {"period": 7.0, "breaths": 2, "look": 14.0, "nod": 2.5, "swell": 0.01, "tail_swing": 2.5,
                 "heave": 0.008, "graze": {"neck": -18.0, "head": -11.0, "chew": 9.0, "chews": 14, "up": (0.55, 0.84),
                                           "sweep": 6.0, "sweeps": 2, "pitch": 4.0}},
        "graze": {"period": 6.0},
        # Its blow is its horns: it gathers itself, drives in head down, and tosses its head as it meets what it hits
        # (the game loops it while it rams).
        "attack": {"period": 1.2, "ram": True, "lunge": 0.4, "back": 0.14, "crouch": 0.05, "dip": 0.04,
                   "lower": 4.0, "tuck": 12.0, "head_down": 12.0, "toss": 22.0, "hook": 12.0, "roll": 5.0,
                   "push": 0.5, "step": 0.1},
        # Killed, it goes down on its belly, forelegs first, the frill and the horns kept clear of the ground.
        "death": {"period": 2.0, "slump": True, "drop": 0.85, "front": 10.0, "roll": 8.0, "edge": 0.5, "splay": 0.6,
                  "reach_fore": 0.25, "reach_hind": 0.4, "rear_neck": 6.0, "rear_head": 6.0, "limp_neck": -4.0,
                  "limp_head": 2.0, "turn": 14.0},
    },
    "body": {
        "around": 48,
        "soften": 0.08,
        "rough": 0.012,
        "scale": 0.9,
        "throat": 0.3,
        "tips": (0.006, 0.02),
        "trunk": [
            # The skull: a narrow, deep, pointed beak; the face deepening and widening back to the eyes, the cheeks
            # flaring out under them (the jugals); behind them the jaws' muscles under the root of the frill.
            st("Head", 1.008, 0.016, 0.026, 0.012, lift=-0.016, step=0.008),
            st("Head", 0.98, 0.032, 0.08, 0.036, lift=-0.008, step=0.012),
            st("Head", 0.94, 0.052, 0.14, 0.06, step=0.015),
            st("Head", 0.88, 0.075, 0.2, 0.088, step=0.02),
            st("Head", 0.8, 0.1, 0.265, 0.115, step=0.025),
            st("Head", 0.7, 0.135, 0.33, 0.15, step=0.025),
            st("Head", 0.6, 0.175, 0.39, 0.185, step=0.025),
            st("Head", 0.5, 0.225, 0.45, 0.23, step=0.025),
            st("Head", 0.42, 0.28, 0.5, 0.27, step=0.025),
            st("Head", 0.34, 0.37, 0.53, 0.31, step=0.025),
            st("Head", 0.27, 0.46, 0.52, 0.35, n_bot=2.5, step=0.025),
            st("Head", 0.19, 0.39, 0.45, 0.37, step=0.03),
            st("Head", 0.1, 0.3, 0.37, 0.36, step=0.03),
            st("Head", 0.0, 0.26, 0.3, 0.32, step=0.035),
            st("Head", -0.1, 0.26, 0.28, 0.33, step=0.04),
            # The neck: short and thick, under the frill.
            st("Neck3", 0.5, 0.28, 0.29, 0.36, step=0.045),
            st("Neck2", 0.5, 0.34, 0.34, 0.45, step=0.05),
            st("Neck1", 0.5, 0.42, 0.38, 0.6, step=0.06),
            # The body: a broad, deep barrel.
            st("Spine4", 0.7, 0.54, 0.36, 0.78, step=0.07),
            st("Spine4", 0.2, 0.67, 0.36, 1.0, n_bot=2.3, step=0.07),
            st("Spine3", 0.5, 0.76, 0.34, 1.17, n_bot=2.5, step=0.08),
            st("Spine2", 0.5, 0.8, 0.33, 1.3, n_bot=2.6, step=0.08),
            st("Spine1", 0.5, 0.77, 0.33, 1.25, n_bot=2.5, step=0.08),
            st("Hips", 0.15, 0.68, 0.34, 1.0, n_top=2.3, step=0.08),
            st("Hips", 0.6, 0.56, 0.33, 0.72, n_top=2.3, step=0.08),
            st("Hips", 1.0, 0.48, 0.33, 0.56, step=0.08),
            # The tail: thick at its root, tapering quickly.
            st("Tail1", 0.5, 0.4, 0.36, 0.46, step=0.07),
            st("Tail2", 0.5, 0.32, 0.31, 0.37, step=0.07),
            st("Tail3", 0.5, 0.255, 0.26, 0.29, step=0.06),
            st("Tail4", 0.5, 0.205, 0.21, 0.225, step=0.06),
            st("Tail5", 0.5, 0.165, 0.17, 0.175, step=0.05),
            st("Tail6", 0.5, 0.13, 0.135, 0.137, step=0.05),
            st("Tail7", 0.5, 0.1, 0.105, 0.105, step=0.045),
            st("Tail8", 0.5, 0.075, 0.079, 0.078, step=0.04),
            st("Tail9", 0.5, 0.053, 0.056, 0.055, step=0.035),
            st("Tail10", 0.5, 0.034, 0.036, 0.035, step=0.03),
            st("Tail11", 0.6, 0.018, 0.019, 0.018, step=0.02),
            st("Tail_end", 0.3, 0.006, 0.006, 0.006, step=0.01),
        ],
        # The beak's edge and the jaws behind it: the cheek teeth hidden inside.
        "mouth": {"from": ("Head", 0.15), "to": ("Head", 1.0), "phi": 118.0, "depth": 0.012, "width": 0.1, "band": 3.0,
                  "dark": 3.0},
        "eyes": {"at": ("Head", 0.38), "phi": 54.0, "radius": 0.034, "sunk": 0.6, "forward": 16.0, "up": 6.0,
                 "iris": (0.36, 0.26, 0.1), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.4), "phi": 36.0, "size": 0.07, "height": 0.02},
        "nostrils": {"at": ("Head", 0.83), "phi": 58.0, "size": 0.03},
        "horns": [
            # Over each eye, up and forward and a little apart, nearly a metre long.
            {"at": ("Head", 0.37), "phi": 20.0, "length": 0.95, "base": (0.085, 0.1), "rake": -35.0, "splay": 0.0,
             "taper": 0.85, "curve": -0.06, "colour": (0.3, 0.27, 0.22), "tip": (0.12, 0.105, 0.085), "rings": 8,
             "around": 12, "bone": "Head"},
            # Over the nostrils, short and blunt.
            {"at": ("Head", 0.73), "phi": 0.0, "length": 0.2, "base": (0.055, 0.085), "rake": -12.0, "taper": 0.8,
             "colour": (0.3, 0.27, 0.22), "tip": (0.12, 0.105, 0.085), "rings": 5, "around": 10, "bone": "Head"},
            # Out of the back of each cheek, down and out: the epijugals.
            {"at": ("Head", 0.27), "phi": 110.0, "length": 0.14, "base": (0.06, 0.075), "rake": 12.0, "splay": 30.0,
             "taper": 1.0, "colour": (0.3, 0.27, 0.22), "tip": (0.2, 0.18, 0.14), "rings": 4, "around": 10,
             "bone": "Head"},
        ],
        # The frill (tools/dino_body.py _frill): back from behind the brow horns along the skull's roof and up over
        # the neck, its sides curving down; the squamosals forward beside the head to the cheeks; seventeen points
        # round its edge.
        "frill": {"at": ("Head", 0.32), "lift": -0.04, "tilt": 78.0, "width": 0.7, "height": 1.4,
                  "outline": [(0.0, 1.0), (0.3, 0.98), (0.56, 0.9), (0.77, 0.76), (0.92, 0.57), (1.0, 0.36),
                              (0.99, 0.15), (0.92, -0.04), (0.8, -0.17), (0.62, -0.15), (0.45, -0.07), (0.28, -0.01),
                              (0.0, 0.0)],
                  "corner": 8, "centre": (0.0, 0.42), "curve": -0.5, "cup": -0.08, "thick": 0.1, "rim": 0.03,
                  "levels": 6, "around": 160, "points": {"count": 17, "size": 0.045, "sharp": 1.0},
                  "colour": (0.17, 0.13, 0.085), "edge": (0.07, 0.055, 0.04), "point": (0.36, 0.32, 0.25)},
        "limbs": {
            "hind": {
                "stations": [(0, -0.2, 0.27, 0.44, 0.05), (0, 0.05, 0.37, 0.52, 0.07), (0, 0.35, 0.33, 0.44, 0.05),
                             (0, 0.65, 0.26, 0.32, 0.02), (0, 0.92, 0.21, 0.23, 0.0), (1, 0.12, 0.21, 0.27, -0.035),
                             (1, 0.4, 0.2, 0.25, -0.03), (1, 0.75, 0.17, 0.18, -0.008), (1, 0.97, 0.155, 0.155, 0.0),
                             (2, 0.25, 0.155, 0.14, 0.0), (2, 0.9, 0.175, 0.13, -0.01)],
                "around": 18,
                # Four short toes, each with a broad hoof.
                "digits": {"digits": [(-34.0, 0.13, 0.05, 0.06), (-12.0, 0.17, 0.058, 0.07), (10.0, 0.17, 0.058, 0.07),
                                      (30.0, 0.14, 0.052, 0.06)],
                           "flat": 0.6, "claw_curl": 0.25},
            },
            "fore": {
                "stations": [(0, -0.2, 0.21, 0.29, 0.0), (0, 0.05, 0.28, 0.33, 0.03), (0, 0.45, 0.24, 0.27, 0.03),
                             (0, 0.9, 0.18, 0.19, 0.0), (1, 0.15, 0.185, 0.21, 0.02), (1, 0.55, 0.155, 0.165, 0.005),
                             (1, 0.95, 0.13, 0.135, 0.0), (2, 0.25, 0.135, 0.12, 0.0), (2, 0.9, 0.145, 0.11, 0.0)],
                "around": 16,
                # Five fingers turned a little out, the first three hoofed, the last two small.
                "digits": {"digits": [(-28.0, 0.08, 0.04, 0.05), (-8.0, 0.1, 0.045, 0.055), (12.0, 0.1, 0.044, 0.05),
                                      (34.0, 0.07, 0.035, 0.01), (54.0, 0.05, 0.028, 0.008)],
                           "flat": 0.6, "claw_curl": 0.3},
            },
        },
        # Its skin (Lane): polygonal scales a few centimetres across, and among them big round feature scales with a
        # cone at the middle of each; the horns' sheaths smooth.
        "skin_detail": {"scales": {"cells": 26.0, "dorsal_size": 0.6, "groove": 0.16, "groove_dark": 0.32, "tint": 0.1,
                                   "speckle": 0.08, "relief": 0.75, "depth": 0.01,
                                   "features": {"scale": 7.0, "share": 0.3, "size": 0.36, "edge": 0.9, "height": 0.7, "cone": 1.1,
                                                "tip": 0.6, "tint": 0.05}},
                        "horn": {"grain": 30.0, "relief": 0.12, "mottle": 0.14, "streak": 0.1}},
        "texture": 2048,
        # Conjectural: a muted grey-brown, darker over the back, paler below; the beak horn-dark; the frill a little
        # warmer, darker at its edge, its points pale.
        "skin": {
            "back": (0.07, 0.055, 0.035),
            "flank": (0.2, 0.15, 0.095),
            "belly": (0.37, 0.31, 0.215),
            "throat": (0.38, 0.33, 0.25),
            "lips": (0.06, 0.05, 0.038),
            "mouth": (0.1, 0.05, 0.04),
            "claws": (0.08, 0.07, 0.055),
            "mottle": 0.18,
            "shank_dark": 0.3,
            "toe_dark": 0.3,
            "horn_base": (0.09, 0.075, 0.055),
            "beak": {"from": ("Head", 0.86), "colour": (0.045, 0.04, 0.032)},
            # Darker blotches over the back and down the flanks.
            "spots": {"colour": (0.045, 0.038, 0.028), "from": ("Neck2", 0.0), "to": ("Tail8", 0.5), "scale": 1.0,
                      "above": 0.3, "strength": 0.42},
        },
    },
}


# Edmontosaurus annectens (Marsh 1892; Campione and Evans 2011; the "mummies" AMNH 5060 and SM 4036, their skin and
# the horny beak over the bill): a duck-billed hadrosaur twelve metres long -- a long, low skull, its front flared
# into a broad, flat, toothless bill, a battery of grinding teeth behind it; a long neck carried in an S; a deep body
# and a long, deep tail stiffened by bony tendons, held straight out behind; the hind legs long and strong, three
# hoofed toes; the forelegs long and slender, the hand's middle three fingers bound in one hoofed pad -- it went on
# all fours when it grazed, and could rise onto its hind legs. A soft, fleshy comb over the top of its head, as one
# mummy shows (Bell et al. 2014, an E. regalis from Alberta). Scenery on the fourth map: a herd on the valley's walls,
# grazing (Config.MAPS herds), never fought.


EDMONTOSAURUS = {
    # Scenery: the herd fits it to its length and walks it at its own pace.
    "fit": "length",
    "length": 12.0,
    # Its strides drawn at the herd's pace (MAPS herds "speed": 0.6), so its feet stay put.
    "paces": {"walk": 0.6, "run": 1.4},
    "skeleton": {
        # The hip joints 2.7 m up (femur 1.25, tibia 1.1, the foot bones 0.45): the back over them 3.3 m.
        "hip_height": 2.8,
        "pelvis_length": 0.55,
        "pelvis_pitch": -4.0,
        # The back from the hips forward and down to the shoulders, on all fours.
        "spine": [(0.8, -8.0), (0.8, -12.0), (0.75, -15.0), (0.7, -18.0)],
        # The neck in an S: down from the shoulders, up, and the head bent down at its end.
        "neck": [(0.3, -18.0), (0.3, 0.0), (0.28, 22.0), (0.26, 32.0), (0.24, 20.0)],
        "skull": (1.15, -28.0),
        "jaw": (0.95, 0.12, -30.0),
        "jaw_hinge": 0.1,
        # Long and deep, held straight out behind.
        "tail": [(0.6, -6.0), (0.58, -6.0), (0.55, -5.0), (0.52, -4.0), (0.5, -3.0), (0.47, -2.0), (0.44, -2.0),
                 (0.41, -1.0), (0.38, -1.0), (0.35, 0.0), (0.32, 0.0), (0.29, 0.0), (0.26, 0.0), (0.23, 0.0)],
        "limbs": {
            # The hind legs long, the foot bones steep on a pad, three hoofed toes.
            "hind": {"from": "hips", "bones": ["Thigh", "Shin", "Foot", "Toes"], "lengths": [1.25, 1.1, 0.45, 0.32],
                     "socket": (0.35, 0.0, -0.1), "stance": (0.0, 0.08), "foot": "digitigrade", "foot_tilt": 25.0,
                     "roll_tilt": 30.0, "bend": "forward", "splay": 3.0},
            # The forelegs long and slender, the hand's long bones near upright, a hoofed pad under them.
            "fore": {"from": "chest", "bones": ["UpperArm", "Forearm", "Hand", "Fingers"],
                     "lengths": [0.6, 0.64, 0.32, 0.12], "socket": (0.36, -0.3, -0.6), "stance": (0.04, 0.12),
                     "foot": "digitigrade", "foot_tilt": 10.0, "roll_tilt": 25.0, "bend": "back", "splay": 6.0},
        },
    },
    "moves": {
        "plan": "quadruped",
        # A slow amble on all fours.
        "walk": {"period": 1.8, "duty": 0.7, "step": 0.14, "bob": 0.03, "snake": 1.5, "tail_swing": 1.5,
                 "order": "walk", "steady": 0.7, "push": 0.5, "curl": 0.3, "hip_roll": 1.5},
        # Its "run": a quicker amble, on all fours still.
        "run": {"period": 1.2, "duty": 0.6, "step": 0.18, "bob": 0.05, "snake": 1.5, "tail_swing": 1.5,
                "order": "walk", "steady": 0.6, "push": 0.6, "curl": 0.35, "hip_roll": 1.5},
        # Grazing: the neck swung down to the ground and swept slowly across it, the bill cropping; up now and then
        # to look about.
        "idle": {"period": 8.0, "breaths": 2, "look": 16.0, "nod": 2.5, "swell": 0.01, "tail_swing": 1.2,
                 "heave": 0.01, "graze": {"neck": -52.0, "head": -4.0, "chew": 8.0, "chews": 16, "up": (0.58, 0.84),
                                           "sweep": 12.0, "sweeps": 1, "pitch": 4.0}},
        "graze": {"period": 7.0},
        # It has no weapon: a shove of its shoulder.
        "attack": {"period": 1.3, "ram": True, "lunge": 0.3, "back": 0.12, "crouch": 0.05, "dip": 0.04, "lower": 3.0,
                   "tuck": 6.0, "head_down": 4.0, "toss": 6.0, "hook": 8.0, "roll": 4.0},
        "death": {"period": 2.4, "roll": 80.0, "pivot": 0.85, "slide": 0.25, "limp_forward": 0.3, "limp_up": 0.3},
    },
    "body": {
        "around": 48,
        "soften": 0.1,
        "rough": 0.015,
        "scale": 1.2,
        "throat": 0.3,
        "tips": (0.005, 0.03),
        "trunk": [
            # The skull: long and low; the bill broad and flat at its front, narrower behind it; deepest at the back,
            # over the jaws' hinge.
            st("Head", 1.01, 0.095, 0.02, 0.02, n_top=3.0, n_bot=3.0, step=0.01),
            st("Head", 0.985, 0.14, 0.04, 0.045, n_top=2.8, n_bot=2.6, step=0.015),
            st("Head", 0.94, 0.15, 0.06, 0.065, n_top=2.6, n_bot=2.4, step=0.02),
            st("Head", 0.86, 0.135, 0.08, 0.085, n_top=2.4, step=0.03),
            st("Head", 0.76, 0.12, 0.1, 0.105, step=0.03),
            st("Head", 0.64, 0.115, 0.125, 0.13, step=0.03),
            st("Head", 0.52, 0.125, 0.15, 0.16, step=0.03),
            st("Head", 0.4, 0.145, 0.175, 0.2, step=0.03),
            st("Head", 0.28, 0.165, 0.2, 0.24, lift=0.005, step=0.03),
            st("Head", 0.17, 0.18, 0.2, 0.28, step=0.03),
            st("Head", 0.07, 0.17, 0.17, 0.27, step=0.035),
            st("Head", -0.03, 0.16, 0.15, 0.24, step=0.04),
            st("Head", -0.1, 0.155, 0.15, 0.22, step=0.04),
            # The neck: deeper than wide, thickening to the shoulders.
            st("Neck5", 0.5, 0.15, 0.15, 0.21, step=0.05),
            st("Neck4", 0.5, 0.17, 0.17, 0.24, step=0.05),
            st("Neck3", 0.5, 0.2, 0.2, 0.29, step=0.06),
            st("Neck2", 0.5, 0.27, 0.26, 0.4, step=0.06),
            st("Neck1", 0.5, 0.36, 0.34, 0.58, step=0.07),
            # The body: deep, a little narrower than tall; the hips high.
            st("Spine4", 0.7, 0.4, 0.34, 0.72, step=0.08),
            st("Spine4", 0.2, 0.5, 0.36, 1.02, n_bot=2.3, step=0.08),
            st("Spine3", 0.5, 0.56, 0.38, 1.2, n_bot=2.4, step=0.09),
            st("Spine2", 0.5, 0.58, 0.42, 1.24, n_bot=2.4, step=0.09),
            st("Spine1", 0.5, 0.56, 0.48, 1.12, n_bot=2.3, step=0.09),
            st("Hips", 0.2, 0.52, 0.52, 0.85, step=0.09),
            st("Hips", 0.8, 0.44, 0.54, 0.68, step=0.09),
            # The tail: tall and narrow (its high spines over it, long chevrons under it), tapering all its length.
            st("Tail1", 0.5, 0.33, 0.55, 0.62, step=0.1),
            st("Tail2", 0.5, 0.28, 0.52, 0.58, step=0.1),
            st("Tail3", 0.5, 0.24, 0.48, 0.52, step=0.1),
            st("Tail4", 0.5, 0.215, 0.45, 0.48, step=0.1),
            st("Tail5", 0.5, 0.19, 0.41, 0.43, step=0.1),
            st("Tail6", 0.5, 0.165, 0.36, 0.38, step=0.1),
            st("Tail7", 0.5, 0.14, 0.31, 0.32, step=0.09),
            st("Tail8", 0.5, 0.118, 0.26, 0.27, step=0.09),
            st("Tail9", 0.5, 0.097, 0.21, 0.215, step=0.08),
            st("Tail10", 0.5, 0.077, 0.16, 0.165, step=0.08),
            st("Tail11", 0.5, 0.058, 0.115, 0.118, step=0.07),
            st("Tail12", 0.5, 0.04, 0.075, 0.076, step=0.06),
            st("Tail13", 0.5, 0.026, 0.045, 0.046, step=0.05),
            st("Tail14", 0.6, 0.014, 0.02, 0.02, step=0.04),
            st("Tail_end", 0.3, 0.004, 0.004, 0.004, step=0.02),
        ],
        # The bill's edge and the long line of the jaws behind it: the teeth hidden in the cheeks.
        "mouth": {"from": ("Head", 0.12), "to": ("Head", 1.0), "phi": 110.0, "depth": 0.01, "width": 0.1, "band": 3.0,
                  "dark": 3.0},
        "eyes": {"at": ("Head", 0.27), "phi": 50.0, "radius": 0.032, "sunk": 0.6, "forward": 12.0, "up": 8.0,
                 "iris": (0.42, 0.3, 0.12), "pupil": (0.01, 0.008, 0.005), "slit": 0.0},
        "brow": {"at": ("Head", 0.29), "phi": 34.0, "size": 0.05, "height": 0.015},
        # The long hollow round the nostril, down the side of the snout (the circumnarial fossa).
        "fossa": {"from": ("Head", 0.55), "to": ("Head", 0.9), "phi": 55.0, "depth": 0.015, "width": 0.3},
        "nostrils": {"at": ("Head", 0.86), "phi": 50.0, "size": 0.025},
        # The comb: a low, soft crest along the top of the head behind the eyes, in lobes.
        "back_plates": {"from": ("Head", 0.38), "to": ("Head", 0.04), "count": 7, "rows": 1, "shape": "plate",
                        "thick": 0.3, "sink": 0.3, "levels": 3,
                        "sizes": [(0.0, 0.04, 0.14), (0.3, 0.085, 0.17), (0.65, 0.08, 0.16), (1.0, 0.04, 0.12)],
                        "colour": (0.22, 0.095, 0.065), "rim": (0.27, 0.12, 0.085), "groove": 0.03, "groove_dark": 0.0},
        "limbs": {
            "hind": {
                "stations": [(0, -0.2, 0.26, 0.48, 0.06), (0, 0.05, 0.38, 0.62, 0.09), (0, 0.35, 0.34, 0.52, 0.06),
                             (0, 0.65, 0.25, 0.34, 0.03), (0, 0.92, 0.18, 0.22, 0.0), (1, 0.12, 0.18, 0.26, -0.05),
                             (1, 0.4, 0.19, 0.26, -0.045), (1, 0.75, 0.14, 0.16, -0.015), (1, 0.97, 0.12, 0.125, 0.0),
                             (2, 0.25, 0.12, 0.105, 0.0), (2, 0.9, 0.13, 0.1, 0.0)],
                "around": 18,
                # Three broad toes, each ending in a hoof.
                "digits": {"digits": [(-22.0, 0.26, 0.06, 0.07), (0.0, 0.3, 0.068, 0.08), (22.0, 0.26, 0.06, 0.07)],
                           "flat": 0.55, "claw_curl": 0.15},
            },
            "fore": {
                "stations": [(0, -0.2, 0.15, 0.22, 0.0), (0, 0.05, 0.18, 0.24, 0.025), (0, 0.45, 0.14, 0.17, 0.025),
                             (0, 0.9, 0.1, 0.105, 0.0), (1, 0.15, 0.105, 0.12, 0.015), (1, 0.55, 0.085, 0.09, 0.005),
                             (1, 0.95, 0.065, 0.068, 0.0), (2, 0.25, 0.065, 0.06, 0.0), (2, 0.9, 0.07, 0.058, 0.0)],
                "around": 16,
                # The middle three fingers close together in their pad, hoofed; the little fifth apart.
                "digits": {"digits": [(-14.0, 0.1, 0.03, 0.03), (0.0, 0.11, 0.032, 0.03), (14.0, 0.1, 0.03, 0.03),
                                      (40.0, 0.12, 0.022, 0.01)],
                           "flat": 0.6, "claw_curl": 0.2},
            },
        },
        # Small polygonal scales all over (the mummies'), bigger ones over the back.
        "skin_detail": {"scales": {"cells": 45.0, "dorsal_size": 0.55, "groove": 0.3, "groove_dark": 0.26, "tint": 0.1,
                                   "speckle": 0.1, "relief": 0.6, "depth": 0.006}},
        "texture": 2048,
        # Conjectural: grey-olive over the back, buff down the flanks, a pale belly; faint darker bands across the
        # back and the tail; the bill horn-dark; the comb flushed a dull red.
        "skin": {
            "back": (0.085, 0.07, 0.045),
            "flank": (0.29, 0.24, 0.155),
            "belly": (0.5, 0.45, 0.34),
            "throat": (0.52, 0.47, 0.36),
            "lips": (0.08, 0.07, 0.05),
            "mouth": (0.12, 0.06, 0.05),
            "claws": (0.09, 0.08, 0.06),
            "mottle": 0.18,
            "shank_dark": 0.25,
            "toe_dark": 0.35,
            "beak": {"from": ("Head", 0.88), "colour": (0.06, 0.055, 0.045)},
            "bands": {"colour": (0.045, 0.036, 0.025), "from": ("Spine3", 0.0), "to": ("Tail_end", 0.5), "period": 0.85,
                      "width": 0.24, "strength": 0.42},
        },
    },
}

# ==============================================================================

# Each by the name its files go by (assets/models/dinos/<name>.gltf); "config" names its row in Config.DINOS where
# that is another.
SPECIES = {"coelophysis": COELOPHYSIS, "coelophysis_alpha": COELOPHYSIS_ALPHA, "postosuchus": POSTOSUCHUS,
           "phytosaur": PHYTOSAUR, "hesperosuchus": HESPEROSUCHUS, "placerias": PLACERIAS,
           "desmatosuchus": DESMATOSUCHUS,
           "velociraptor": RAPTOR, "velociraptor_alpha": RAPTOR_ALPHA, "tyrannosaurus": TREX,
           "pterosaur": PTEROSAUR,
           # The second map's (GAME-DESIGN 7.2, station 2).
           "ornitholestes": ORNITHOLESTES, "ceratosaurus": CERATOSAURUS, "allosaurus": ALLOSAURUS,
           "stegosaurus": STEGOSAURUS, "diplodocus": DIPLODOCUS, "harpactognathus": HARPACTOGNATHUS,
           # The third map's (GAME-DESIGN 7.2, station 3: the Jehol Biota).
           "yutyrannus": YUTYRANNUS, "dilong": DILONG, "sinocalliopteryx": SINOCALLIOPTERYX,
           "sinornithosaurus": SINORNITHOSAURUS,
           # ... and its herd at the forest's edge.
           "psittacosaurus": PSITTACOSAURUS,
           # The Hell Creek's own dromaeosaurs, beside the tyrannosaur.
           "acheroraptor": ACHERORAPTOR, "dakotaraptor": DAKOTARAPTOR,
           # The Hell Creek's plant-eaters: the frightened charger, and a herd on the valley's walls.
           "triceratops": TRICERATOPS, "edmontosaurus": EDMONTOSAURUS}
