extends SceneTree
## tools/build_sounds.gd -- the game's sounds, synthesised by rule and written as WAV files.
##
## v0.6 round three: "你就做音效吧，恐龙音效不同恐龙尽量不同，这样有区分度". Nothing is downloaded: every
## sound is made here, the way tools/build_ui_textures.gd draws the interface, and written to
## assets/audio/<id>.wav, which Godot imports like any other asset. Config.SOUNDS says which files
## make up which sound and how loud it plays; how each one SOUNDS is here.
##
##   godot --headless --path . --script res://tools/build_sounds.gd [-- id id ...]
##
## The animals are made the way a voice is: a source -- a train of pulses from the throat at a
## pitch, rough where the throat is rough, with breath through it -- shaped by the formants of the
## tract it passes through (source and filter). What tells one animal from another is what tells
## one throat from another, and the palaeontology is followed where there is any:
##
##   Coelophysis   a three-metre, twenty-kilo theropod: a short tract, so high formants and a high
##                 pitch; quick, bird-like chitters, trills and hisses (its nearest living kin
##                 call, they do not roar).
##   its alpha     the same throat, bigger: a fifth lower, rougher, and a two-part honk.
##   Postosuchus   a five-metre rauisuchian, of the crocodiles' side of the family: the crocodile's
##                 bellow -- a very low, rough, closed-mouth rumble -- a hiss like a big croc's, and
##                 a heavy jaw that claps.
##   Placerias     a tonne of dicynodont, a beaked plant-eater: nasal grunts and honks, low and
##                 pulsed, like a hippo or a pig -- a sound that is plainly not a hunter's.
##   the phytosaur the river's night hunter, four metres of long-snouted archosaur: a long tract, so
##                 low formants; a crocodile's low growl with a wet rasp through it, a hiss lower than a
##                 small one's, a long jaw clapped shut. They were Postosuchus's own, pitched up.
##   Hesperosuchus a metre of quick early crocodylomorph: short raspy barks, a thin hiss with a rattle
##                 in it, a light snap -- a small hunter's, not a big one's pitched up.
##
## The Late Cretaceous (a custom game's age, CUSTOM_GAME "age"), each its own -- they borrowed the Late
## Triassic's voices till now:
##
##   Velociraptor  a fifteen-kilo dromaeosaur, feathered, a cousin of the birds: a throat about the
##                 Coelophysis's size, hoarser -- a rattling chatter, a goose's honk, a hiss that breaks into
##                 a screech -- told from the Coelophysis by its rattle and its honk, not by its height.
##   its leader    the same throat, bigger: a fourth lower, a longer, rougher honk.
##   Tyrannosaurus nine tonnes of tyrannosaurid -- and not the films' open-mouthed roar: its living kin, the
##                 crocodiles and the big ground birds, call with the mouth shut. A deep closed-mouth boom,
##                 below Postosuchus's bellow and smooth where that is rough, its sub-octave felt as much as
##                 heard; a long rumbling boom to come in with; a huff for a warning; a jaw that is the
##                 heaviest thing in the valley.
##   the azhdarchid a stork's build and a two-metre bill: a heron's or a crane's harsh croak, a screech, the
##                 bill clacked shut -- nothing like a theropod's.
##
## And the river broken: something heavy coming up out of it onto the bank (river_splash) -- how a
## phytosaur is heard landing in the dark, from the side it lands on.
##
## Things struck are made of their modes: a few damped resonances at the frequencies of the
## material -- wood low and short, stone high and ringing, a bowstring's thrum -- and the burst of
## noise where they were hit.
##
## Everything is mono, 22 050 Hz, 16-bit: the game places it in the world (Fx.play_at), so the
## file needs no stereo of its own.

const RATE: int = 22050
const OUT: String = "res://assets/audio/"

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made: int = 0
	for id in _recipes():
		if not only.is_empty() and not only.has(id):
			continue
		_rng.seed = hash(id)
		var data: PackedFloat32Array = call("_s_" + id)
		_save(id, data)
		made += 1
	print("[sounds] %d written to %s" % [made, OUT])
	quit()

## Every sound this makes, by the name of its file. Each has a function _s_<id>.
func _recipes() -> PackedStringArray:
	var out := PackedStringArray()
	for m in get_script().get_script_method_list():
		var n: String = String(m["name"])
		if n.begins_with("_s_"):
			out.append(n.substr(3))
	out.sort()
	return out

# ==============================================================================
# Coelophysis: small, quick, high -- chitters, trills, hisses
# ==============================================================================

const COELO_FORMANTS: Array = [[1150.0, 5.0, 1.0], [2450.0, 6.0, 0.55], [3700.0, 7.0, 0.25]]

func _s_coelophysis_call_1() -> PackedFloat32Array:
	# A falling chitter: a rattled trill that drops away.
	return _voice({"dur": 0.62, "f0": [[0.0, 640.0], [0.25, 700.0], [1.0, 470.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.7, 0.8], [1.0, 0.0]], "formants": COELO_FORMANTS,
		"trill": [17.0, 0.75], "vibrato": [24.0, 0.05], "breath": 0.18, "tilt": 3200.0, "jitter": 0.02})

func _s_coelophysis_call_2() -> PackedFloat32Array:
	# Two sharp yips, the second higher: "kek -- kek".
	var out := _buf(0.5)
	for i in 2:
		var yip := _voice({"dur": 0.16, "f0": [[0.0, 560.0 + 90.0 * i], [0.4, 780.0 + 90.0 * i], [1.0, 600.0]],
			"amp": [[0.0, 0.0], [0.12, 1.0], [1.0, 0.0]], "formants": COELO_FORMANTS,
			"breath": 0.12, "tilt": 3600.0, "jitter": 0.02})
		_mix(out, yip, 0.03 + 0.2 * i, 1.0)
	return out

func _s_coelophysis_call_3() -> PackedFloat32Array:
	# A rising chirr that ends in a hiss.
	var out := _buf(0.9)
	_mix(out, _voice({"dur": 0.5, "f0": [[0.0, 480.0], [1.0, 720.0]],
		"amp": [[0.0, 0.0], [0.1, 0.9], [0.85, 1.0], [1.0, 0.0]], "formants": COELO_FORMANTS,
		"trill": [21.0, 0.6], "breath": 0.2, "tilt": 3400.0}), 0.0, 1.0)
	_mix(out, _hiss(0.45, [[0.0, 3000.0], [1.0, 4200.0]], 4.0, [[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]]), 0.42, 0.45)
	return out

func _s_coelophysis_alert() -> PackedFloat32Array:
	# Seen something: a sharp rising screech with a hiss under it.
	var out := _buf(0.75)
	_mix(out, _voice({"dur": 0.6, "f0": [[0.0, 520.0], [0.35, 920.0], [1.0, 760.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.6, 0.9], [1.0, 0.0]], "formants": COELO_FORMANTS,
		"rough": 0.25, "breath": 0.3, "tilt": 4200.0, "vibrato": [30.0, 0.04]}), 0.0, 1.0)
	_mix(out, _hiss(0.5, [[0.0, 3500.0], [1.0, 3000.0]], 3.0, [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]]), 0.1, 0.3)
	return out

func _s_coelophysis_bite_1() -> PackedFloat32Array:
	return _snap(1.0, 0.0)

func _s_coelophysis_bite_2() -> PackedFloat32Array:
	return _snap(1.12, 0.0)

func _s_coelophysis_hurt_1() -> PackedFloat32Array:
	return _voice({"dur": 0.32, "f0": [[0.0, 980.0], [0.2, 1040.0], [1.0, 640.0]],
		"amp": [[0.0, 0.0], [0.04, 1.0], [1.0, 0.0]], "formants": COELO_FORMANTS,
		"rough": 0.35, "breath": 0.25, "tilt": 4500.0})

func _s_coelophysis_hurt_2() -> PackedFloat32Array:
	return _voice({"dur": 0.26, "f0": [[0.0, 860.0], [1.0, 560.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], "formants": COELO_FORMANTS,
		"rough": 0.5, "breath": 0.3, "tilt": 4000.0})

func _s_coelophysis_death() -> PackedFloat32Array:
	# A squeal that falls away into a rattling breath.
	var out := _buf(1.05)
	_mix(out, _voice({"dur": 0.85, "f0": [[0.0, 760.0], [0.3, 640.0], [1.0, 230.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.5, 0.7], [1.0, 0.0]], "formants": COELO_FORMANTS,
		"fshift": [[0.0, 1.0], [1.0, 0.8]], "rough": 0.45, "rough_am": [28.0, 0.5],
		"breath": 0.35, "tilt": 3000.0}), 0.0, 1.0)
	_mix(out, _hiss(0.5, [[0.0, 1800.0], [1.0, 1200.0]], 2.0, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.55, 0.25)
	return out

# ==============================================================================
# The alpha: the same throat, bigger -- lower, rougher, a two-part honk
# ==============================================================================

const ALPHA_FORMANTS: Array = [[760.0, 5.0, 1.0], [1750.0, 6.0, 0.6], [2900.0, 7.0, 0.3]]

func _s_coelophysis_alpha_call_1() -> PackedFloat32Array:
	# "Hoo -- rrk".
	var out := _buf(1.0)
	_mix(out, _voice({"dur": 0.38, "f0": [[0.0, 330.0], [1.0, 300.0]],
		"amp": [[0.0, 0.0], [0.15, 1.0], [0.8, 0.9], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
		"fshift": [[0.0, 0.8], [1.0, 0.85]], "breath": 0.12, "tilt": 2200.0, "vibrato": [6.0, 0.02]}), 0.02, 0.9)
	_mix(out, _voice({"dur": 0.46, "f0": [[0.0, 290.0], [1.0, 250.0]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.7, 0.8], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
		"rough": 0.6, "rough_am": [26.0, 0.4], "breath": 0.22, "tilt": 2800.0}), 0.45, 1.0)
	return out

func _s_coelophysis_alpha_call_2() -> PackedFloat32Array:
	# A long rattled call, the leader holding the pack together.
	return _voice({"dur": 1.0, "f0": [[0.0, 300.0], [0.3, 380.0], [1.0, 260.0]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.75, 0.85], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
		"trill": [13.0, 0.55], "rough": 0.3, "breath": 0.18, "tilt": 2600.0, "jitter": 0.025})

func _s_coelophysis_alpha_alert() -> PackedFloat32Array:
	# The rally: a rising, rough cry, and the valley answering it back.
	var dry := _voice({"dur": 1.2, "f0": [[0.0, 260.0], [0.35, 430.0], [1.0, 240.0]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
		"rough": 0.55, "rough_am": [24.0, 0.35], "breath": 0.25, "tilt": 3000.0})
	return _space(dry, 0.18, [[0.3, 0.3], [0.62, 0.16]])

func _s_coelophysis_alpha_bite() -> PackedFloat32Array:
	return _snap(0.78, 0.35)

func _s_coelophysis_alpha_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.45, "f0": [[0.0, 520.0], [0.2, 560.0], [1.0, 330.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
		"rough": 0.6, "breath": 0.3, "tilt": 3400.0})

func _s_coelophysis_alpha_death() -> PackedFloat32Array:
	var out := _buf(1.5)
	_mix(out, _voice({"dur": 1.25, "f0": [[0.0, 480.0], [0.3, 400.0], [1.0, 150.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.55, 0.7], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
		"fshift": [[0.0, 1.0], [1.0, 0.75]], "rough": 0.6, "rough_am": [22.0, 0.5],
		"breath": 0.35, "tilt": 2600.0}), 0.0, 1.0)
	_mix(out, _hiss(0.6, [[0.0, 1400.0], [1.0, 900.0]], 2.0, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.85, 0.25)
	return out

# ==============================================================================
# Postosuchus: the crocodile's side -- bellow, hiss, a jaw that claps
# ==============================================================================

const POSTO_FORMANTS: Array = [[330.0, 3.5, 1.0], [880.0, 4.0, 0.55], [1750.0, 5.0, 0.25]]

func _bellow(dur: float, f0_from: float, f0_to: float, rough: float) -> PackedFloat32Array:
	# A closed-mouth rumble: very low, rough, slow to swell and slow to go, with the sub-octave
	# of a big chest under it.
	var out := _voice({"dur": dur, "f0": [[0.0, f0_from], [0.3, f0_from * 1.06], [1.0, f0_to]],
		"amp": [[0.0, 0.0], [0.18, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": POSTO_FORMANTS,
		"rough": rough, "rough_am": [23.0, 0.6], "breath": 0.22, "tilt": 1400.0, "jitter": 0.03})
	var sub := _tone(dur, [[0.0, f0_from * 0.5], [1.0, f0_to * 0.5]], [[0.0, 0.0], [0.25, 1.0], [0.7, 0.8], [1.0, 0.0]])
	_mix(out, sub, 0.0, 0.5)
	return out

func _s_postosuchus_call_1() -> PackedFloat32Array:
	return _space(_bellow(1.9, 64.0, 54.0, 0.7), 0.12, [])

func _s_postosuchus_call_2() -> PackedFloat32Array:
	# A string of grunts: "hrrm -- hrrm -- hrrm".
	var out := _buf(1.8)
	for i in 3:
		var g := _voice({"dur": 0.42, "f0": [[0.0, 82.0 - 6.0 * i], [1.0, 66.0 - 6.0 * i]],
			"amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]], "formants": POSTO_FORMANTS,
			"rough": 0.8, "rough_am": [21.0, 0.6], "breath": 0.3, "tilt": 1500.0})
		_mix(out, g, 0.05 + 0.5 * i, 1.0 - 0.15 * i)
	return _space(out, 0.1, [])

func _s_postosuchus_roar() -> PackedFloat32Array:
	# Its arrival, heard across the valley: a long bellow, and the valley walls throwing it back.
	var dry := _bellow(2.8, 58.0, 46.0, 0.85)
	_mix(dry, _hiss(1.6, [[0.0, 1300.0], [1.0, 900.0]], 1.2, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.9, 0.35)
	return _space(dry, 0.3, [[0.42, 0.45], [0.86, 0.28], [1.35, 0.15]])

func _s_postosuchus_hiss() -> PackedFloat32Array:
	var out := _hiss(1.3, [[0.0, 1600.0], [0.5, 2200.0], [1.0, 1400.0]], 1.1, [[0.0, 0.0], [0.12, 1.0], [0.8, 0.8], [1.0, 0.0]])
	_mix(out, _bellow(1.2, 58.0, 52.0, 0.9), 0.05, 0.35)
	return out

func _s_postosuchus_bite() -> PackedFloat32Array:
	# A heavy jaw clapping shut: a low thump, the crack of it, a wet snap.
	var out := _modes(0.45, [[78.0, 0.14, 1.0], [132.0, 0.1, 0.7], [240.0, 0.06, 0.4], [610.0, 0.03, 0.25]], 0.004)
	_mix(out, _burst(0.05, 2200.0, 1.2), 0.0, 0.6)
	_mix(out, _snap(0.55, 0.6), 0.01, 0.55)
	return out

func _s_postosuchus_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.7, "f0": [[0.0, 120.0], [0.2, 128.0], [1.0, 84.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.6, 0.8], [1.0, 0.0]], "formants": POSTO_FORMANTS,
		"fshift": [[0.0, 1.2], [1.0, 1.0]], "rough": 0.85, "rough_am": [25.0, 0.6],
		"breath": 0.35, "tilt": 1900.0})

func _s_postosuchus_death() -> PackedFloat32Array:
	var out := _bellow(2.4, 70.0, 36.0, 0.9)
	_mix(out, _hiss(1.2, [[0.0, 1100.0], [1.0, 600.0]], 1.5, [[0.0, 0.0], [0.4, 1.0], [1.0, 0.0]]), 1.3, 0.4)
	return _space(out, 0.15, [[0.45, 0.2]])

# ==============================================================================
# The phytosaur: the river at night -- a long snout's low, wet growl, a hiss, a jaw clapped shut
# ==============================================================================

const PHYTO_FORMANTS: Array = [[270.0, 3.0, 1.0], [720.0, 3.5, 0.5], [1450.0, 4.5, 0.2]]

## A low growl through a long snout, a slow wet rasp through it: lower and wetter than Postosuchus's
## bellow, out of a smaller chest.
func _growl(dur: float, f0_from: float, f0_to: float) -> PackedFloat32Array:
	return _voice({"dur": dur, "f0": [[0.0, f0_from], [0.35, f0_from * 1.05], [1.0, f0_to]],
		"amp": [[0.0, 0.0], [0.12, 1.0], [0.75, 0.85], [1.0, 0.0]], "formants": PHYTO_FORMANTS,
		"rough": 0.8, "rough_am": [9.0, 0.7], "breath": 0.32, "tilt": 1100.0, "jitter": 0.04})

func _s_phytosaur_call_1() -> PackedFloat32Array:
	# A growl out over the water, its sub-octave under it.
	var out := _growl(1.6, 74.0, 60.0)
	_mix(out, _tone(1.6, [[0.0, 37.0], [1.0, 30.0]], [[0.0, 0.0], [0.2, 1.0], [0.8, 0.7], [1.0, 0.0]]), 0.0, 0.35)
	return _space(out, 0.14, [[0.5, 0.2]])

func _s_phytosaur_call_2() -> PackedFloat32Array:
	# Two short chuffs and a growl: "hff -- hff -- grrr".
	var out := _buf(1.9)
	for i in 2:
		_mix(out, _hiss(0.16, [[0.0, 700.0], [1.0, 500.0]], 0.9, [[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]]), 0.05 + 0.32 * i, 0.8)
		_mix(out, _growl(0.18, 90.0, 80.0), 0.05 + 0.32 * i, 0.6)
	_mix(out, _growl(1.1, 78.0, 58.0), 0.75, 1.0)
	return _space(out, 0.12, [])

func _s_phytosaur_hiss() -> PackedFloat32Array:
	# A crocodile warned off, mouth open: a hiss lower than a small one's, a growl in it.
	var out := _hiss(1.5, [[0.0, 900.0], [0.4, 1300.0], [1.0, 800.0]], 0.9, [[0.0, 0.0], [0.08, 1.0], [0.75, 0.85], [1.0, 0.0]])
	_mix(out, _growl(1.3, 70.0, 62.0), 0.05, 0.45)
	return out

func _s_phytosaur_bite() -> PackedFloat32Array:
	# A long, narrow jaw clapped shut: a sharp crack -- the snout's length is its lever -- and a knock.
	var out := _modes(0.35, [[150.0, 0.07, 1.0], [290.0, 0.05, 0.7], [880.0, 0.02, 0.4], [1700.0, 0.012, 0.3]], 0.003)
	_mix(out, _snap(0.75, 0.0), 0.0, 0.8)
	_mix(out, _burst(0.04, 2600.0, 1.3), 0.0, 0.5)
	return out

func _s_phytosaur_hurt() -> PackedFloat32Array:
	# A grunt forced out with a hiss.
	var out := _voice({"dur": 0.6, "f0": [[0.0, 110.0], [0.25, 118.0], [1.0, 76.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.55, 0.7], [1.0, 0.0]], "formants": PHYTO_FORMANTS,
		"fshift": [[0.0, 1.25], [1.0, 1.0]], "rough": 0.85, "rough_am": [11.0, 0.5], "breath": 0.5, "tilt": 1700.0})
	_mix(out, _hiss(0.5, [[0.0, 1100.0], [1.0, 800.0]], 1.0, [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]]), 0.02, 0.35)
	return out

func _s_phytosaur_death() -> PackedFloat32Array:
	# A growl that sinks into a gurgle, and the breath going out of it.
	var out := _voice({"dur": 2.2, "f0": [[0.0, 70.0], [0.3, 64.0], [1.0, 32.0]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.6, 0.6], [1.0, 0.0]], "formants": PHYTO_FORMANTS,
		"rough": 0.9, "rough_am": [6.0, 0.85], "breath": 0.4, "tilt": 1000.0, "jitter": 0.05})
	_mix(out, _hiss(1.3, [[0.0, 900.0], [1.0, 500.0]], 1.2, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 1.0, 0.3)
	return _space(out, 0.12, [[0.45, 0.15]])

## Something heavy coming up out of the river onto the bank: the water broken, falling back, running off
## it in drops.
func _s_river_splash() -> PackedFloat32Array:
	var out := _buf(1.4)
	_mix(out, _hiss(0.5, [[0.0, 700.0], [0.3, 1400.0], [1.0, 900.0]], 0.7, [[0.0, 0.0], [0.05, 1.0], [0.4, 0.5], [1.0, 0.0]]), 0.0, 0.9)
	_mix(out, _burst(0.12, 380.0, 0.8), 0.0, 0.6)
	_mix(out, _hiss(0.9, [[0.0, 2400.0], [1.0, 1800.0]], 1.0, [[0.0, 0.0], [0.15, 0.6], [1.0, 0.0]]), 0.2, 0.4)
	_mix(out, _crackle(1.1, 30.0, 2800.0), 0.25, 0.5)
	return _space(out, 0.1, [])

# ==============================================================================
# Hesperosuchus: small and quick -- raspy barks, a thin rattling hiss, a light snap
# ==============================================================================

const HESPERO_FORMANTS: Array = [[720.0, 5.0, 1.0], [1950.0, 5.5, 0.5], [3300.0, 6.5, 0.22]]

## A short raspy bark: "kak".
func _bark(f0: float, dur: float) -> PackedFloat32Array:
	return _voice({"dur": dur, "f0": [[0.0, f0], [1.0, f0 * 0.82]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.5, 0.6], [1.0, 0.0]], "formants": HESPERO_FORMANTS,
		"rough": 0.55, "rough_am": [38.0, 0.5], "breath": 0.45, "tilt": 2600.0})

func _s_hesperosuchus_call_1() -> PackedFloat32Array:
	# "kak-kak-kak-kak", falling.
	var out := _buf(0.9)
	for i in 4:
		_mix(out, _bark(360.0 - 18.0 * i, 0.09), 0.03 + 0.14 * i, 1.0 - 0.12 * i)
	return _space(out, 0.08, [])

func _s_hesperosuchus_call_2() -> PackedFloat32Array:
	var out := _buf(0.7)
	_mix(out, _bark(410.0, 0.12), 0.03, 1.0)
	_mix(out, _bark(330.0, 0.16), 0.22, 0.85)
	return _space(out, 0.08, [])

func _s_hesperosuchus_hiss() -> PackedFloat32Array:
	# A thin hiss, a rattle through it: a small animal's warning.
	var out := _hiss(0.8, [[0.0, 2400.0], [0.4, 3100.0], [1.0, 2100.0]], 1.3, [[0.0, 0.0], [0.08, 1.0], [0.7, 0.8], [1.0, 0.0]])
	for i in out.size():
		out[i] *= 0.65 + 0.35 * sin(TAU * 28.0 * float(i) / float(RATE))
	return out

func _s_hesperosuchus_bite() -> PackedFloat32Array:
	return _snap(1.25, 0.0)

func _s_hesperosuchus_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.28, "f0": [[0.0, 520.0], [0.3, 560.0], [1.0, 360.0]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [1.0, 0.0]], "formants": HESPERO_FORMANTS,
		"rough": 0.4, "breath": 0.4, "tilt": 3000.0})

func _s_hesperosuchus_death() -> PackedFloat32Array:
	var out := _voice({"dur": 0.95, "f0": [[0.0, 440.0], [0.2, 460.0], [1.0, 170.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.6, 0.6], [1.0, 0.0]], "formants": HESPERO_FORMANTS,
		"rough": 0.6, "rough_am": [30.0, 0.5], "breath": 0.5, "tilt": 2400.0})
	return _space(out, 0.08, [])

# ==============================================================================
# Placerias: a tonne of beaked plant-eater -- nasal grunts and honks
# ==============================================================================

const PLAC_FORMANTS: Array = [[420.0, 4.5, 1.0], [1080.0, 5.0, 0.45], [2350.0, 6.0, 0.18]]

func _grunts(count: int, f0: float, gap: float, each: float) -> PackedFloat32Array:
	var out := _buf(0.1 + float(count) * gap + each)
	for i in count:
		var g := _voice({"dur": each, "f0": [[0.0, f0 * (1.0 + 0.04 * i)], [1.0, f0 * 0.86]],
			"amp": [[0.0, 0.0], [0.25, 1.0], [1.0, 0.0]], "formants": PLAC_FORMANTS,
			"rough": 0.35, "breath": 0.3, "tilt": 1800.0, "nasal": 0.6})
		_mix(out, g, 0.03 + gap * i, 1.0 - 0.1 * i)
	return out

func _s_placerias_call_1() -> PackedFloat32Array:
	return _space(_grunts(3, 124.0, 0.26, 0.22), 0.1, [])

func _s_placerias_call_2() -> PackedFloat32Array:
	# A long honk, and a snort to finish.
	var out := _buf(1.3)
	_mix(out, _voice({"dur": 0.8, "f0": [[0.0, 140.0], [0.5, 168.0], [1.0, 118.0]],
		"amp": [[0.0, 0.0], [0.12, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": PLAC_FORMANTS,
		"rough": 0.25, "breath": 0.25, "tilt": 2000.0, "nasal": 0.7, "vibrato": [5.0, 0.02]}), 0.0, 1.0)
	_mix(out, _hiss(0.22, [[0.0, 900.0], [1.0, 700.0]], 1.5, [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]]), 0.9, 0.55)
	return _space(out, 0.1, [])

func _s_placerias_call_3() -> PackedFloat32Array:
	return _space(_grunts(2, 108.0, 0.34, 0.3), 0.1, [])

# ==============================================================================
# Velociraptor: a feathered dromaeosaur -- a rattling chatter, a goose's honk, a hiss into a screech
# ==============================================================================

const RAPTOR_FORMANTS: Array = [[980.0, 5.0, 1.0], [2200.0, 6.0, 0.5], [3400.0, 7.0, 0.22]]

func _s_velociraptor_call_1() -> PackedFloat32Array:
	# A rattling chatter: "k-k-k-krrr", a buzz through it.
	return _voice({"dur": 0.55, "f0": [[0.0, 470.0], [0.3, 520.0], [1.0, 400.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.75, 0.8], [1.0, 0.0]], "formants": RAPTOR_FORMANTS,
		"trill": [32.0, 0.85], "rough": 0.35, "rough_am": [11.0, 0.3], "breath": 0.25, "tilt": 3000.0, "jitter": 0.03})

func _s_velociraptor_call_2() -> PackedFloat32Array:
	# A goose's honk, twice: "hronk -- hronk".
	var out := _buf(0.75)
	for i in 2:
		_mix(out, _voice({"dur": 0.22, "f0": [[0.0, 380.0 + 40.0 * i], [0.5, 430.0 + 40.0 * i], [1.0, 360.0]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [0.7, 0.8], [1.0, 0.0]], "formants": RAPTOR_FORMANTS,
			"rough": 0.3, "breath": 0.15, "tilt": 2600.0, "nasal": 0.45}), 0.03 + 0.3 * i, 1.0 - 0.1 * i)
	return out

func _s_velociraptor_alert() -> PackedFloat32Array:
	# Seen something: a hiss that breaks into a rattling screech.
	var out := _buf(0.8)
	_mix(out, _hiss(0.3, [[0.0, 2600.0], [1.0, 3300.0]], 2.5, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.2]]), 0.0, 0.55)
	_mix(out, _voice({"dur": 0.5, "f0": [[0.0, 520.0], [0.3, 760.0], [1.0, 600.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": RAPTOR_FORMANTS,
		"trill": [36.0, 0.6], "rough": 0.4, "breath": 0.3, "tilt": 3800.0}), 0.22, 1.0)
	return out

func _s_velociraptor_bite_1() -> PackedFloat32Array:
	return _snap(1.05, 0.15)

func _s_velociraptor_bite_2() -> PackedFloat32Array:
	return _snap(1.16, 0.1)

func _s_velociraptor_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.3, "f0": [[0.0, 820.0], [0.2, 880.0], [1.0, 520.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], "formants": RAPTOR_FORMANTS,
		"rough": 0.5, "trill": [30.0, 0.4], "breath": 0.3, "tilt": 3800.0})

func _s_velociraptor_death() -> PackedFloat32Array:
	# A squawk falling away into a rattle.
	var out := _buf(1.0)
	_mix(out, _voice({"dur": 0.8, "f0": [[0.0, 700.0], [0.3, 600.0], [1.0, 210.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.5, 0.7], [1.0, 0.0]], "formants": RAPTOR_FORMANTS,
		"fshift": [[0.0, 1.0], [1.0, 0.8]], "trill": [24.0, 0.5], "rough": 0.5, "breath": 0.35, "tilt": 2800.0}), 0.0, 1.0)
	_mix(out, _hiss(0.4, [[0.0, 1700.0], [1.0, 1100.0]], 2.0, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.55, 0.25)
	return out

# ==============================================================================
# Its leader: the same throat, bigger -- a fourth lower, a longer, rougher honk
# ==============================================================================

const RAPTOR_ALPHA_FORMANTS: Array = [[740.0, 5.0, 1.0], [1700.0, 6.0, 0.55], [2650.0, 7.0, 0.25]]

func _s_velociraptor_alpha_call_1() -> PackedFloat32Array:
	# A long honk that cracks into a rattle.
	return _space(_voice({"dur": 0.75, "f0": [[0.0, 290.0], [0.35, 330.0], [1.0, 250.0]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.7, 0.85], [1.0, 0.0]], "formants": RAPTOR_ALPHA_FORMANTS,
		"rough": 0.55, "rough_am": [14.0, 0.4], "trill": [26.0, 0.35], "breath": 0.2, "tilt": 2400.0, "nasal": 0.4}), 0.08, [])

func _s_velociraptor_alpha_call_2() -> PackedFloat32Array:
	# "hronk -- hronk -- krrr".
	var out := _buf(1.1)
	for i in 2:
		_mix(out, _voice({"dur": 0.28, "f0": [[0.0, 270.0 + 25.0 * i], [0.5, 310.0 + 25.0 * i], [1.0, 250.0]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [0.7, 0.8], [1.0, 0.0]], "formants": RAPTOR_ALPHA_FORMANTS,
			"rough": 0.45, "breath": 0.18, "tilt": 2200.0, "nasal": 0.5}), 0.03 + 0.34 * i, 1.0)
	_mix(out, _voice({"dur": 0.3, "f0": [[0.0, 300.0], [1.0, 240.0]], "amp": [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]],
		"formants": RAPTOR_ALPHA_FORMANTS, "trill": [30.0, 0.8], "rough": 0.5, "breath": 0.25, "tilt": 2600.0}), 0.72, 0.8)
	return out

func _s_velociraptor_alpha_alert() -> PackedFloat32Array:
	# The pack's leader has seen him: a hiss, and a screech that carries.
	var out := _buf(1.0)
	_mix(out, _hiss(0.35, [[0.0, 2200.0], [1.0, 2900.0]], 2.0, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.2]]), 0.0, 0.6)
	_mix(out, _voice({"dur": 0.7, "f0": [[0.0, 380.0], [0.3, 560.0], [1.0, 430.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": RAPTOR_ALPHA_FORMANTS,
		"trill": [28.0, 0.5], "rough": 0.55, "breath": 0.3, "tilt": 3200.0}), 0.25, 1.0)
	return _space(out, 0.12, [[0.4, 0.2]])

func _s_velociraptor_alpha_bite() -> PackedFloat32Array:
	return _snap(0.9, 0.35)

func _s_velociraptor_alpha_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.38, "f0": [[0.0, 600.0], [0.2, 650.0], [1.0, 380.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], "formants": RAPTOR_ALPHA_FORMANTS,
		"rough": 0.6, "trill": [26.0, 0.4], "breath": 0.3, "tilt": 3200.0})

func _s_velociraptor_alpha_death() -> PackedFloat32Array:
	var out := _buf(1.3)
	_mix(out, _voice({"dur": 1.05, "f0": [[0.0, 520.0], [0.3, 440.0], [1.0, 150.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.5, 0.75], [1.0, 0.0]], "formants": RAPTOR_ALPHA_FORMANTS,
		"fshift": [[0.0, 1.0], [1.0, 0.8]], "trill": [20.0, 0.5], "rough": 0.6, "breath": 0.35, "tilt": 2400.0}), 0.0, 1.0)
	_mix(out, _hiss(0.5, [[0.0, 1400.0], [1.0, 900.0]], 2.0, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.75, 0.3)
	return _space(out, 0.1, [])

# ==============================================================================
# Tyrannosaurus: a closed-mouth boom, below Postosuchus's bellow and smooth where that is rough
# ==============================================================================

const TREX_FORMANTS: Array = [[165.0, 3.0, 1.0], [420.0, 3.5, 0.4], [920.0, 4.0, 0.12]]

## A closed-mouth boom: very low and smooth -- the sound pushed down into the throat and chest and out through
## the skin, the way an emu or a crocodile booms -- a deep sub-octave under it, felt more than heard.
func _boom(dur: float, f0_from: float, f0_to: float) -> PackedFloat32Array:
	var out := _voice({"dur": dur, "f0": [[0.0, f0_from], [0.25, f0_from * 1.08], [1.0, f0_to]],
		"amp": [[0.0, 0.0], [0.25, 1.0], [0.65, 0.95], [1.0, 0.0]], "formants": TREX_FORMANTS,
		"rough": 0.15, "rough_am": [6.0, 0.35], "breath": 0.06, "tilt": 600.0, "jitter": 0.02, "nasal": 0.15})
	_mix(out, _tone(dur, [[0.0, f0_from * 0.5], [1.0, f0_to * 0.5]], [[0.0, 0.0], [0.3, 1.0], [0.7, 0.9], [1.0, 0.0]]), 0.0, 0.8)
	return out

func _s_tyrannosaurus_call_1() -> PackedFloat32Array:
	return _space(_boom(2.2, 46.0, 38.0), 0.15, [])

func _s_tyrannosaurus_call_2() -> PackedFloat32Array:
	# "hoom -- hoooom": a short boom, and a long one under it.
	var out := _buf(2.9)
	_mix(out, _boom(0.9, 50.0, 44.0), 0.0, 0.85)
	_mix(out, _boom(1.8, 44.0, 36.0), 0.9, 1.0)
	return _space(out, 0.15, [])

func _s_tyrannosaurus_roar() -> PackedFloat32Array:
	# Its arrival, heard across the valley: a long rumbling boom swelling out of the ground, a rattle in the
	# throat at its height, and the valley walls throwing it back.
	var dry := _boom(3.4, 40.0, 31.0)
	_mix(dry, _voice({"dur": 1.6, "f0": [[0.0, 62.0], [0.5, 70.0], [1.0, 52.0]],
		"amp": [[0.0, 0.0], [0.3, 1.0], [0.8, 0.7], [1.0, 0.0]], "formants": TREX_FORMANTS,
		"rough": 0.7, "rough_am": [17.0, 0.6], "breath": 0.2, "tilt": 1100.0}), 0.9, 0.45)
	return _space(dry, 0.3, [[0.45, 0.45], [0.9, 0.3], [1.4, 0.15]])

func _s_tyrannosaurus_alert() -> PackedFloat32Array:
	# A huff -- a great breath forced out through the nostrils -- over a low rumble.
	var out := _hiss(0.9, [[0.0, 700.0], [0.3, 900.0], [1.0, 500.0]], 1.0, [[0.0, 0.0], [0.08, 1.0], [0.5, 0.6], [1.0, 0.0]])
	_mix(out, _boom(1.0, 44.0, 40.0), 0.05, 0.6)
	return out

func _s_tyrannosaurus_bite() -> PackedFloat32Array:
	# The heaviest jaw in the valley clapping shut: a deep thump, the crack of the teeth, bone in it.
	var out := _modes(0.55, [[58.0, 0.18, 1.0], [104.0, 0.12, 0.75], [190.0, 0.07, 0.45], [480.0, 0.035, 0.25]], 0.005)
	_mix(out, _burst(0.06, 1800.0, 1.1), 0.0, 0.6)
	_mix(out, _snap(0.45, 0.0), 0.01, 0.5)
	return out

func _s_tyrannosaurus_hurt() -> PackedFloat32Array:
	# Hurt, the mouth opens: a rough bellowing grunt, the boom's throat strained.
	return _voice({"dur": 0.8, "f0": [[0.0, 96.0], [0.2, 104.0], [1.0, 66.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.6, 0.8], [1.0, 0.0]], "formants": TREX_FORMANTS,
		"fshift": [[0.0, 1.4], [1.0, 1.1]], "rough": 0.75, "rough_am": [19.0, 0.5], "breath": 0.3, "tilt": 1600.0})

func _s_tyrannosaurus_death() -> PackedFloat32Array:
	var out := _boom(2.8, 48.0, 26.0)
	_mix(out, _hiss(1.4, [[0.0, 900.0], [1.0, 450.0]], 1.2, [[0.0, 0.0], [0.4, 1.0], [1.0, 0.0]]), 1.4, 0.4)
	return _space(out, 0.15, [[0.45, 0.2]])

# ==============================================================================
# The azhdarchid: a stork's build, a two-metre bill -- a heron's croak, a screech, the bill clacked shut
# ==============================================================================

const PTERO_FORMANTS: Array = [[620.0, 4.0, 1.0], [1500.0, 5.0, 0.6], [2700.0, 6.0, 0.3]]

## A croak through a long bill: "kraaak" -- harsh, nasal, low for its height, a heron's.
func _croak(dur: float, f0_from: float, f0_to: float) -> PackedFloat32Array:
	return _voice({"dur": dur, "f0": [[0.0, f0_from], [0.3, f0_from * 1.05], [1.0, f0_to]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.7, 0.85], [1.0, 0.0]], "formants": PTERO_FORMANTS,
		"rough": 0.7, "rough_am": [48.0, 0.6], "breath": 0.35, "tilt": 2200.0, "nasal": 0.35, "jitter": 0.04})

func _s_pterosaur_call_1() -> PackedFloat32Array:
	return _space(_croak(0.6, 300.0, 255.0), 0.1, [])

func _s_pterosaur_call_2() -> PackedFloat32Array:
	# "krek -- krek -- kraaak".
	var out := _buf(1.2)
	_mix(out, _croak(0.16, 330.0, 300.0), 0.02, 0.9)
	_mix(out, _croak(0.16, 340.0, 305.0), 0.25, 0.9)
	_mix(out, _croak(0.5, 320.0, 250.0), 0.5, 1.0)
	return _space(out, 0.1, [])

func _s_pterosaur_alert() -> PackedFloat32Array:
	# A screech through the bill, and the bill clattering.
	var out := _buf(0.9)
	_mix(out, _voice({"dur": 0.55, "f0": [[0.0, 420.0], [0.35, 640.0], [1.0, 480.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": PTERO_FORMANTS,
		"rough": 0.6, "rough_am": [52.0, 0.5], "breath": 0.4, "tilt": 3200.0}), 0.0, 1.0)
	for i in 4:
		_mix(out, _s_pterosaur_bite(), 0.5 + 0.07 * i, 0.35)
	return out

func _s_pterosaur_bite() -> PackedFloat32Array:
	# A long bill clacked shut: hard and light, high -- keratin and bone, no growl behind it.
	var out := _modes(0.12, [[1400.0, 0.03, 1.0], [2600.0, 0.02, 0.6], [3900.0, 0.015, 0.35]], 0.0015)
	_mix(out, _burst(0.015, 4200.0, 1.8), 0.0, 0.5)
	return out

func _s_pterosaur_hurt() -> PackedFloat32Array:
	return _croak(0.28, 420.0, 300.0)

func _s_pterosaur_death() -> PackedFloat32Array:
	var out := _croak(1.0, 360.0, 150.0)
	_mix(out, _hiss(0.5, [[0.0, 1500.0], [1.0, 900.0]], 1.8, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.6, 0.25)
	return _space(out, 0.1, [])

# ==============================================================================
# STATION 2, the Late Jurassic (MAPS.morrison), each its own voice
# ==============================================================================
#   Ornitholestes  a twelve-kilo coelurosaur: a short tract, high -- quick yelping "kit-kit-kit"s and a whistled
#                  trill, brighter and thinner than the Coelophysis's chitter, no rattle in it.
#   Ceratosaurus   six metres: a nasal, resonant honk-growl -- the long snout under its horn -- well below the
#                  small ones, rough.
#   Allosaurus     eight and a half metres: a closed-mouth boom, as the great hunters' kin boom, higher and rougher
#                  than the tyrannosaur's -- a smaller animal -- with a growl worked into it.
#   Harpactognathus  a rhamphorhynchid, two and a half metres across: shrill squawks and a screech -- a gull's
#                  harshness through a toothed bill, far above the azhdarchid's croak.

const ORNI_FORMANTS: Array = [[1350.0, 5.0, 1.0], [2800.0, 6.0, 0.5], [4000.0, 7.0, 0.2]]

func _yip(f0: float, dur: float) -> PackedFloat32Array:
	return _voice({"dur": dur, "f0": [[0.0, f0], [0.3, f0 * 1.15], [1.0, f0 * 0.9]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.6, 0.7], [1.0, 0.0]], "formants": ORNI_FORMANTS,
		"rough": 0.1, "breath": 0.2, "tilt": 4200.0, "jitter": 0.02})

func _s_ornitholestes_call_1() -> PackedFloat32Array:
	# "kit-kit-kit-kit": quick yelps, rising.
	var out := _buf(0.7)
	for i in 4:
		_mix(out, _yip(820.0 + 40.0 * i, 0.09), 0.02 + 0.13 * i, 0.9)
	return out

func _s_ornitholestes_call_2() -> PackedFloat32Array:
	# A whistled trill, falling.
	return _voice({"dur": 0.6, "f0": [[0.0, 1100.0], [0.4, 980.0], [1.0, 760.0]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.7, 0.8], [1.0, 0.0]], "formants": ORNI_FORMANTS,
		"trill": [22.0, 0.5], "rough": 0.05, "breath": 0.25, "tilt": 4500.0})

func _s_ornitholestes_alert() -> PackedFloat32Array:
	# A sharp double yelp, and a hiss.
	var out := _buf(0.6)
	_mix(out, _yip(1000.0, 0.12), 0.0, 1.0)
	_mix(out, _yip(1150.0, 0.14), 0.15, 1.0)
	_mix(out, _hiss(0.25, [[0.0, 3000.0], [1.0, 3600.0]], 2.5, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.32, 0.4)
	return out

func _s_ornitholestes_bite() -> PackedFloat32Array:
	return _snap(1.3, 0.0)

func _s_ornitholestes_hurt() -> PackedFloat32Array:
	return _yip(1300.0, 0.22)

func _s_ornitholestes_death() -> PackedFloat32Array:
	var out := _voice({"dur": 0.7, "f0": [[0.0, 1150.0], [0.3, 950.0], [1.0, 380.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.5, 0.6], [1.0, 0.0]], "formants": ORNI_FORMANTS,
		"fshift": [[0.0, 1.0], [1.0, 0.85]], "rough": 0.2, "breath": 0.35, "tilt": 3800.0})
	_mix(out, _hiss(0.3, [[0.0, 2000.0], [1.0, 1300.0]], 2.0, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.45, 0.25)
	return out

const CERATO_FORMANTS: Array = [[430.0, 4.0, 1.0], [1150.0, 5.0, 0.5], [2050.0, 6.0, 0.2]]

func _s_ceratosaurus_call_1() -> PackedFloat32Array:
	# A long nasal honk with a growl under it.
	return _space(_voice({"dur": 0.9, "f0": [[0.0, 160.0], [0.3, 185.0], [1.0, 140.0]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.7, 0.85], [1.0, 0.0]], "formants": CERATO_FORMANTS,
		"rough": 0.5, "rough_am": [12.0, 0.4], "breath": 0.15, "tilt": 1800.0, "nasal": 0.55}), 0.1, [])

func _s_ceratosaurus_call_2() -> PackedFloat32Array:
	# "hrunk -- hrunk", the second lower.
	var out := _buf(1.0)
	for i in 2:
		_mix(out, _voice({"dur": 0.32, "f0": [[0.0, 175.0 - 20.0 * i], [0.5, 195.0 - 20.0 * i], [1.0, 150.0 - 20.0 * i]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [0.7, 0.8], [1.0, 0.0]], "formants": CERATO_FORMANTS,
			"rough": 0.45, "breath": 0.15, "tilt": 1700.0, "nasal": 0.6}), 0.03 + 0.42 * i, 1.0)
	return _space(out, 0.1, [])

func _s_ceratosaurus_alert() -> PackedFloat32Array:
	# A rasping hiss into a growl.
	var out := _buf(1.0)
	_mix(out, _hiss(0.4, [[0.0, 1600.0], [1.0, 2100.0]], 1.8, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.3]]), 0.0, 0.6)
	_mix(out, _voice({"dur": 0.6, "f0": [[0.0, 150.0], [0.4, 175.0], [1.0, 140.0]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": CERATO_FORMANTS,
		"rough": 0.7, "rough_am": [18.0, 0.5], "breath": 0.25, "tilt": 2000.0}), 0.3, 1.0)
	return out

func _s_ceratosaurus_bite() -> PackedFloat32Array:
	return _snap(0.75, 0.4)

func _s_ceratosaurus_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.45, "f0": [[0.0, 260.0], [0.2, 290.0], [1.0, 170.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], "formants": CERATO_FORMANTS,
		"rough": 0.65, "breath": 0.3, "tilt": 2200.0, "nasal": 0.4})

func _s_ceratosaurus_death() -> PackedFloat32Array:
	var out := _voice({"dur": 1.3, "f0": [[0.0, 230.0], [0.3, 200.0], [1.0, 80.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.5, 0.7], [1.0, 0.0]], "formants": CERATO_FORMANTS,
		"fshift": [[0.0, 1.0], [1.0, 0.8]], "rough": 0.6, "breath": 0.35, "tilt": 1800.0, "nasal": 0.4})
	return _space(out, 0.12, [])

const ALLO_FORMANTS: Array = [[230.0, 3.0, 1.0], [580.0, 3.5, 0.45], [1200.0, 4.0, 0.15]]

## A closed-mouth boom, higher and rougher than the tyrannosaur's, a growl worked into it.
func _allo_boom(dur: float, f0_from: float, f0_to: float) -> PackedFloat32Array:
	var out := _voice({"dur": dur, "f0": [[0.0, f0_from], [0.25, f0_from * 1.1], [1.0, f0_to]],
		"amp": [[0.0, 0.0], [0.2, 1.0], [0.65, 0.9], [1.0, 0.0]], "formants": ALLO_FORMANTS,
		"rough": 0.4, "rough_am": [9.0, 0.45], "breath": 0.1, "tilt": 900.0, "jitter": 0.03, "nasal": 0.2})
	_mix(out, _tone(dur, [[0.0, f0_from * 0.5], [1.0, f0_to * 0.5]], [[0.0, 0.0], [0.3, 1.0], [0.7, 0.8], [1.0, 0.0]]), 0.0, 0.6)
	return out

func _s_allosaurus_call_1() -> PackedFloat32Array:
	return _space(_allo_boom(1.8, 68.0, 56.0), 0.15, [])

func _s_allosaurus_call_2() -> PackedFloat32Array:
	var out := _buf(2.4)
	_mix(out, _allo_boom(0.7, 72.0, 64.0), 0.0, 0.85)
	_mix(out, _allo_boom(1.4, 64.0, 52.0), 0.75, 1.0)
	return _space(out, 0.15, [])

func _s_allosaurus_roar() -> PackedFloat32Array:
	# Its coming, heard over the valley: a long boom that breaks into a rasping growl, and the walls throwing it back.
	var dry := _allo_boom(3.0, 60.0, 46.0)
	_mix(dry, _voice({"dur": 1.4, "f0": [[0.0, 90.0], [0.5, 104.0], [1.0, 76.0]],
		"amp": [[0.0, 0.0], [0.3, 1.0], [0.8, 0.7], [1.0, 0.0]], "formants": ALLO_FORMANTS,
		"rough": 0.8, "rough_am": [21.0, 0.6], "breath": 0.25, "tilt": 1400.0}), 0.8, 0.5)
	return _space(dry, 0.3, [[0.45, 0.45], [0.9, 0.3], [1.4, 0.15]])

func _s_allosaurus_alert() -> PackedFloat32Array:
	var out := _hiss(0.8, [[0.0, 900.0], [0.3, 1150.0], [1.0, 650.0]], 1.1, [[0.0, 0.0], [0.08, 1.0], [0.5, 0.6], [1.0, 0.0]])
	_mix(out, _allo_boom(0.9, 66.0, 60.0), 0.05, 0.6)
	return out

func _s_allosaurus_bite() -> PackedFloat32Array:
	var out := _modes(0.5, [[70.0, 0.16, 1.0], [125.0, 0.1, 0.7], [230.0, 0.06, 0.4], [560.0, 0.03, 0.25]], 0.005)
	_mix(out, _burst(0.06, 2000.0, 1.1), 0.0, 0.6)
	_mix(out, _snap(0.55, 0.1), 0.01, 0.5)
	return out

func _s_allosaurus_hurt() -> PackedFloat32Array:
	return _voice({"dur": 0.7, "f0": [[0.0, 130.0], [0.2, 142.0], [1.0, 90.0]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.6, 0.8], [1.0, 0.0]], "formants": ALLO_FORMANTS,
		"fshift": [[0.0, 1.4], [1.0, 1.1]], "rough": 0.75, "rough_am": [19.0, 0.5], "breath": 0.3, "tilt": 1900.0})

func _s_allosaurus_death() -> PackedFloat32Array:
	var out := _allo_boom(2.4, 70.0, 34.0)
	_mix(out, _hiss(1.2, [[0.0, 1000.0], [1.0, 500.0]], 1.2, [[0.0, 0.0], [0.4, 1.0], [1.0, 0.0]]), 1.2, 0.4)
	return _space(out, 0.15, [[0.45, 0.2]])

const HARP_FORMANTS: Array = [[950.0, 4.0, 1.0], [2200.0, 5.0, 0.6], [3500.0, 6.0, 0.3]]

## A shrill squawk through a toothed bill: a gull's harshness, short.
func _squawk(dur: float, f0_from: float, f0_to: float) -> PackedFloat32Array:
	return _voice({"dur": dur, "f0": [[0.0, f0_from], [0.25, f0_from * 1.1], [1.0, f0_to]],
		"amp": [[0.0, 0.0], [0.06, 1.0], [0.7, 0.85], [1.0, 0.0]], "formants": HARP_FORMANTS,
		"rough": 0.55, "rough_am": [60.0, 0.5], "breath": 0.3, "tilt": 3200.0, "nasal": 0.25, "jitter": 0.04})

func _s_harpactognathus_call_1() -> PackedFloat32Array:
	# "kek-kek-keeer".
	var out := _buf(0.9)
	_mix(out, _squawk(0.1, 640.0, 600.0), 0.02, 0.85)
	_mix(out, _squawk(0.1, 660.0, 610.0), 0.18, 0.85)
	_mix(out, _squawk(0.4, 700.0, 520.0), 0.36, 1.0)
	return out

func _s_harpactognathus_call_2() -> PackedFloat32Array:
	return _squawk(0.5, 720.0, 560.0)

func _s_harpactognathus_alert() -> PackedFloat32Array:
	# A screech as it comes down.
	return _voice({"dur": 0.6, "f0": [[0.0, 700.0], [0.35, 1050.0], [1.0, 820.0]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.7, 0.9], [1.0, 0.0]], "formants": HARP_FORMANTS,
		"rough": 0.5, "rough_am": [64.0, 0.45], "breath": 0.4, "tilt": 3800.0})

func _s_harpactognathus_bite() -> PackedFloat32Array:
	# A toothed bill snapping: lighter than a theropod's jaw, sharper than the azhdarchid's clack.
	var out := _modes(0.1, [[1800.0, 0.025, 1.0], [3100.0, 0.015, 0.5]], 0.0012)
	_mix(out, _burst(0.012, 4500.0, 1.8), 0.0, 0.5)
	return out

func _s_harpactognathus_hurt() -> PackedFloat32Array:
	return _squawk(0.22, 900.0, 650.0)

func _s_harpactognathus_death() -> PackedFloat32Array:
	var out := _squawk(0.8, 820.0, 300.0)
	_mix(out, _hiss(0.5, [[0.0, 1800.0], [1.0, 1000.0]], 1.8, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), 0.5, 0.25)
	return out

# ==============================================================================
# His work: an axe in wood, a pick on stone, a mallet on a stake
# ==============================================================================

func _s_chop_1() -> PackedFloat32Array:
	return _chop(1.0)

func _s_chop_2() -> PackedFloat32Array:
	return _chop(0.92)

func _s_chop_3() -> PackedFloat32Array:
	return _chop(1.09)

func _chop(k: float) -> PackedFloat32Array:
	# The blade bites (a bright crack), the trunk answers (low woody modes, short).
	var out := _modes(0.32, [[175.0 * k, 0.07, 1.0], [410.0 * k, 0.05, 0.75], [760.0 * k, 0.03, 0.45], [1320.0 * k, 0.018, 0.25]], 0.003)
	_mix(out, _burst(0.03, 2600.0, 1.0), 0.0, 0.7)
	_mix(out, _crackle(0.18, 90.0, 1400.0), 0.02, 0.18)
	return out

func _s_quarry_1() -> PackedFloat32Array:
	return _quarry(1.0)

func _s_quarry_2() -> PackedFloat32Array:
	return _quarry(0.9)

func _s_quarry_3() -> PackedFloat32Array:
	return _quarry(1.12)

func _quarry(k: float) -> PackedFloat32Array:
	# Stone on stone rings high and hard, and grit falls after it.
	var out := _modes(0.4, [[2150.0 * k, 0.06, 1.0], [3380.0 * k, 0.045, 0.7], [4720.0 * k, 0.03, 0.45], [980.0 * k, 0.05, 0.4]], 0.0015)
	_mix(out, _burst(0.02, 4200.0, 0.8), 0.0, 0.8)
	_mix(out, _crackle(0.3, 160.0, 3200.0), 0.03, 0.3)
	return out

func _s_hammer_1() -> PackedFloat32Array:
	return _hammer(1.0)

func _s_hammer_2() -> PackedFloat32Array:
	return _hammer(1.1)

func _s_hammer_3() -> PackedFloat32Array:
	return _hammer(0.93)

func _hammer(k: float) -> PackedFloat32Array:
	# A mallet on a stake: a knock with more body than the axe and no bite.
	var out := _modes(0.26, [[290.0 * k, 0.06, 1.0], [640.0 * k, 0.04, 0.6], [1150.0 * k, 0.025, 0.35]], 0.002)
	_mix(out, _burst(0.015, 1500.0, 1.0), 0.0, 0.45)
	return out

func _s_swing() -> PackedFloat32Array:
	# A blow through the air.
	return _hiss(0.2, [[0.0, 500.0], [0.6, 1600.0], [1.0, 900.0]], 1.8, [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]])

func _s_strike() -> PackedFloat32Array:
	# The blow landing on an animal: a dull, fleshy thump.
	var out := _modes(0.22, [[105.0, 0.07, 1.0], [210.0, 0.05, 0.5], [420.0, 0.03, 0.2]], 0.003)
	_mix(out, _burst(0.04, 700.0, 1.5), 0.0, 0.6)
	return out

func _s_hero_hurt() -> PackedFloat32Array:
	# Bitten: the thump of it, and the tear of cloth.
	var out := _modes(0.25, [[120.0, 0.06, 1.0], [260.0, 0.04, 0.5]], 0.003)
	_mix(out, _hiss(0.16, [[0.0, 2500.0], [1.0, 1800.0]], 2.0, [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]]), 0.01, 0.45)
	return out

func _s_eat() -> PackedFloat32Array:
	# Chewing: three crunches, softer each time.
	var out := _buf(1.0)
	for i in 3:
		_mix(out, _crackle(0.16, 260.0, 1800.0), 0.05 + 0.3 * i, 1.0 - 0.2 * i)
		_mix(out, _modes(0.1, [[190.0, 0.03, 1.0]], 0.004), 0.05 + 0.3 * i, 0.3)
	return out

func _s_pickup() -> PackedFloat32Array:
	# Something taken up off the ground: a rustle and a soft knock.
	var out := _hiss(0.14, [[0.0, 1400.0], [1.0, 2200.0]], 1.2, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]])
	_mix(out, _modes(0.12, [[520.0, 0.03, 1.0], [880.0, 0.02, 0.5]], 0.002), 0.06, 0.8)
	return out

# ==============================================================================
# What is built, and what becomes of it
# ==============================================================================

func _s_build_done() -> PackedFloat32Array:
	# The last stake driven home: two knocks and the timber settling.
	var out := _buf(0.6)
	_mix(out, _hammer(1.0), 0.0, 0.9)
	_mix(out, _hammer(0.86), 0.16, 1.0)
	_mix(out, _modes(0.35, [[140.0, 0.12, 1.0], [230.0, 0.08, 0.5]], 0.004), 0.2, 0.5)
	return out

func _s_wood_hit_1() -> PackedFloat32Array:
	# A fence bitten: teeth on timber, a creak.
	var out := _modes(0.24, [[230.0, 0.05, 1.0], [520.0, 0.035, 0.6], [980.0, 0.02, 0.3]], 0.003)
	_mix(out, _crackle(0.14, 120.0, 2000.0), 0.0, 0.35)
	return out

func _s_wood_hit_2() -> PackedFloat32Array:
	var out := _modes(0.24, [[205.0, 0.05, 1.0], [470.0, 0.035, 0.6], [1100.0, 0.02, 0.3]], 0.003)
	_mix(out, _crackle(0.12, 150.0, 2400.0), 0.0, 0.4)
	return out

func _s_wood_break() -> PackedFloat32Array:
	# Gone: timber splitting, a fall, the pieces after it.
	var out := _buf(1.1)
	_mix(out, _crackle(0.35, 420.0, 2600.0), 0.0, 0.8)
	_mix(out, _modes(0.5, [[95.0, 0.16, 1.0], [180.0, 0.12, 0.6], [340.0, 0.07, 0.4]], 0.006), 0.18, 1.0)
	_mix(out, _crackle(0.5, 60.0, 1700.0), 0.3, 0.4)
	return out

func _s_trap_twang() -> PackedFloat32Array:
	# A bowstring let go: the snap of the release and the string thrumming down.
	var out := _burst(0.012, 3000.0, 1.0)
	var thrum := _tone(0.35, [[0.0, 196.0], [1.0, 178.0]], [[0.0, 0.0], [0.02, 1.0], [1.0, 0.0]])
	_mix(thrum, _tone(0.35, [[0.0, 392.0], [1.0, 356.0]], [[0.0, 0.0], [0.02, 0.5], [0.5, 0.1], [1.0, 0.0]]), 0.0, 1.0)
	_mix(out, thrum, 0.0, 0.8)
	_mix(out, _hiss(0.1, [[0.0, 1200.0], [1.0, 2400.0]], 1.5, [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]]), 0.02, 0.3)
	return out

# The towers (AmmoTower, the 2026-10-02 rebuild): what each does is heard as what it is.

func _s_bow_loose() -> PackedFloat32Array:
	# A bow on the tower let go (BowTower): the string's snap, a short bright thrum -- a smaller bow than the
	# old trap's, so higher and shorter -- and the arrow hissing away.
	var out := _burst(0.008, 3600.0, 1.2)
	var thrum := _tone(0.22, [[0.0, 262.0], [1.0, 240.0]], [[0.0, 0.0], [0.03, 1.0], [1.0, 0.0]])
	_mix(thrum, _tone(0.22, [[0.0, 524.0], [1.0, 480.0]], [[0.0, 0.0], [0.03, 0.4], [0.5, 0.08], [1.0, 0.0]]), 0.0, 1.0)
	_mix(out, thrum, 0.0, 0.7)
	_mix(out, _hiss(0.26, [[0.0, 2600.0], [1.0, 1500.0]], 2.2, [[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]]), 0.02, 0.45)
	return out

func _s_log_roll() -> PackedFloat32Array:
	# A log let go down the ramp (LogTower): the lever's clack, the log dropping onto the boards, and a
	# long low rumble of timber rolling over earth, knocking as it turns.
	var out := _buf(1.5)
	_mix(out, _modes(0.12, [[610.0, 0.03, 1.0], [1350.0, 0.015, 0.5]], 0.002), 0.0, 0.6)
	_mix(out, _modes(0.4, [[88.0, 0.16, 1.0], [170.0, 0.1, 0.6], [330.0, 0.05, 0.35]], 0.004), 0.08, 1.0)
	var rumble := _hiss(1.3, [[0.0, 160.0], [1.0, 120.0]], 0.9, [[0.0, 0.0], [0.08, 1.0], [0.7, 0.8], [1.0, 0.0]])
	_lowpass(rumble, 420.0)
	_mix(out, rumble, 0.15, 1.1)
	for i in 5:
		_mix(out, _modes(0.14, [[120.0 + 9.0 * i, 0.05, 1.0], [250.0, 0.03, 0.4]], 0.003), 0.25 + 0.22 * i, 0.45 - 0.06 * i)
	_mix(out, _crackle(1.2, 50.0, 1500.0), 0.2, 0.25)
	return out

func _s_catapult_throw() -> PackedFloat32Array:
	# The catapult's arm thrown (Catapult): the twisted rope's creak let go, the arm whooshing up, and the
	# heavy knock of it against its stop beam.
	var out := _buf(0.9)
	_mix(out, _crackle(0.18, 220.0, 900.0), 0.0, 0.5)
	_mix(out, _hiss(0.32, [[0.0, 300.0], [0.5, 900.0], [1.0, 500.0]], 1.4, [[0.0, 0.0], [0.4, 1.0], [1.0, 0.0]]), 0.05, 0.8)
	_mix(out, _modes(0.5, [[74.0, 0.2, 1.0], [150.0, 0.12, 0.7], [310.0, 0.06, 0.4], [640.0, 0.03, 0.2]], 0.005), 0.26, 1.0)
	_mix(out, _modes(0.25, [[180.0, 0.08, 1.0], [400.0, 0.04, 0.4]], 0.003), 0.36, 0.35)
	return out

func _s_stone_impact() -> PackedFloat32Array:
	# A thrown stone coming down (Catapult): a heavy, dull blow on earth and on what is under it, a thump of
	# air, and grit and pebbles after.
	var out := _modes(0.55, [[58.0, 0.22, 1.0], [112.0, 0.14, 0.65], [230.0, 0.07, 0.4], [880.0, 0.02, 0.2]], 0.006)
	_mix(out, _hiss(0.3, [[0.0, 500.0], [1.0, 260.0]], 0.7, [[0.0, 0.0], [0.04, 1.0], [1.0, 0.0]]), 0.0, 0.55)
	_mix(out, _crackle(0.45, 160.0, 2400.0), 0.05, 0.35)
	return out

func _s_reload() -> PackedFloat32Array:
	# A tower loaded (AmmoTower.load_from_stock): a bundle set in -- shafts rattling against each other, and a
	# soft knock as it settles.
	var out := _buf(0.5)
	_mix(out, _crackle(0.28, 120.0, 1700.0), 0.0, 0.6)
	for i in 3:
		_mix(out, _modes(0.08, [[700.0 + 140.0 * i, 0.02, 1.0], [1500.0, 0.012, 0.4]], 0.002), 0.03 + 0.07 * i, 0.4)
	_mix(out, _modes(0.18, [[210.0, 0.05, 1.0], [480.0, 0.03, 0.5]], 0.003), 0.26, 0.7)
	return out

func _s_stone_hit() -> PackedFloat32Array:
	# A stone wall bitten or struck: a dull knock, higher and harder than timber, grit after.
	var out := _modes(0.2, [[880.0, 0.03, 1.0], [1560.0, 0.02, 0.6], [2700.0, 0.012, 0.35]], 0.002)
	_mix(out, _crackle(0.16, 140.0, 2600.0), 0.01, 0.35)
	return out

func _s_hull_hit() -> PackedFloat32Array:
	# Teeth on the cabin's hull: plate metal, which rings inharmonically and a while, and the
	# scrape of it.
	var out := _modes(0.7, [[412.0, 0.25, 1.0], [1127.0, 0.18, 0.55], [1873.0, 0.12, 0.4], [2951.0, 0.07, 0.25]], 0.0015)
	_mix(out, _hiss(0.2, [[0.0, 3200.0], [1.0, 2400.0]], 3.0, [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]]), 0.02, 0.3)
	return out

func _s_cook_done() -> PackedFloat32Array:
	# Meat off the fire: a last sizzle, and the pot set down.
	var out := _crackle(0.6, 380.0, 3400.0)
	_mix(out, _hiss(0.6, [[0.0, 5000.0], [1.0, 4200.0]], 1.0, [[0.0, 0.3], [0.3, 1.0], [1.0, 0.0]]), 0.0, 0.25)
	_mix(out, _modes(0.2, [[240.0, 0.05, 1.0], [520.0, 0.03, 0.5]], 0.003), 0.45, 0.5)
	return out

func _s_craft_done() -> PackedFloat32Array:
	# A tool finished at the bench: a last tap, and the ring of a good edge.
	var out := _hammer(1.2)
	_mix(out, _modes(0.7, [[1760.0, 0.25, 0.6], [2640.0, 0.18, 0.35]], 0.001), 0.14, 0.5)
	return out

# ==============================================================================
# The raid, the ship
# ==============================================================================

func _s_raid_warning() -> PackedFloat32Array:
	# Nothing built: the pack itself, far off -- calling from over by the nest, one and then
	# another answering, the valley softening all of it. Heard, not announced.
	var out := _buf(2.6)
	var calls: Array = [_s_coelophysis_call_1(), _s_coelophysis_alpha_call_2(), _s_coelophysis_call_3(), _s_coelophysis_call_2()]
	var at: Array = [0.0, 0.45, 1.0, 1.5]
	var gain: Array = [0.8, 1.0, 0.7, 0.6]
	for i in calls.size():
		_mix(out, calls[i], at[i], gain[i])
	_lowpass(out, 1900.0)
	return _space(out, 0.35, [[0.5, 0.3]])

func _s_beacon_stage() -> PackedFloat32Array:
	# A stage of the beacon back on line: the ship's own voice, a clean struck tone.
	var out := _bell(1.6, 880.0, 1.4)
	_mix(out, _bell(1.4, 1320.0, 1.4), 0.12, 0.6)
	return out

func _s_beacon_launch() -> PackedFloat32Array:
	# The charge beginning: a hum climbing, and the tones of the stages over it.
	var out := _tone(3.0, [[0.0, 55.0], [1.0, 110.0]], [[0.0, 0.0], [0.3, 0.8], [0.8, 1.0], [1.0, 0.0]])
	_mix(out, _tone(3.0, [[0.0, 110.0], [1.0, 220.0]], [[0.0, 0.0], [0.4, 0.4], [0.85, 0.6], [1.0, 0.0]]), 0.0, 0.6)
	for i in 3:
		_mix(out, _bell(1.2, 660.0 * pow(1.26, i), 1.4), 0.6 + 0.6 * i, 0.4)
	return out

func _s_landing() -> PackedFloat32Array:
	# The capsule come down at the next station (StationJump): the air it pushes before it, a hull's weight on earth
	# -- plate ringing, a deep thud felt more than heard -- and earth and grit falling back after.
	var out := _buf(2.2)
	_mix(out, _hiss(0.6, [[0.0, 300.0], [1.0, 900.0]], 1.0, [[0.0, 0.0], [0.8, 1.0], [1.0, 0.2]]), 0.0, 0.5)
	_mix(out, _modes(1.4, [[38.0, 0.6, 1.0], [71.0, 0.4, 0.7], [140.0, 0.2, 0.4]], 0.008), 0.55, 1.0)
	_mix(out, _modes(1.2, [[412.0, 0.35, 1.0], [1127.0, 0.25, 0.5], [1873.0, 0.15, 0.3]], 0.0015), 0.55, 0.35)
	_mix(out, _crackle(1.4, 90.0, 1800.0), 0.75, 0.4)
	return out

func _s_ui_click() -> PackedFloat32Array:
	# A button: a small, dry knock, like a bone toggle.
	var out := _modes(0.06, [[1400.0, 0.012, 1.0], [2600.0, 0.008, 0.5]], 0.0008)
	return out

# ==============================================================================
# The valley itself
# ==============================================================================

func _s_ambience_valley() -> PackedFloat32Array:
	# Ten seconds that loop: wind in the conifers, insects stridulating far off in the grass (there
	# were crickets' kin in the Triassic; there were no birds), and the river.
	var dur: float = 10.0
	var n: int = int(dur * RATE)
	var out := _buf(dur)
	# Wind: brown noise, swelling and falling.
	var brown: float = 0.0
	var lp: float = 0.0
	for i in n:
		brown = clampf(brown + _rng.randf_range(-1.0, 1.0) * 0.02, -1.0, 1.0)
		lp += 0.06 * (brown - lp)
		var t: float = float(i) / float(RATE)
		var swell: float = 0.55 + 0.45 * sin(TAU * t / dur * 2.0 + 0.7) * sin(TAU * t / dur * 3.0)
		out[i] += lp * swell * 1.6
	# The river: a band of noise with bubbles in it.
	var river := _hiss(dur, [[0.0, 700.0], [1.0, 700.0]], 0.8, [[0.0, 1.0], [1.0, 1.0]])
	_mix(out, river, 0.0, 0.12)
	for b in 40:
		var at: float = _rng.randf_range(0.0, dur - 0.1)
		_mix(out, _tone(0.05, [[0.0, _rng.randf_range(600.0, 1200.0)], [1.0, _rng.randf_range(1200.0, 1800.0)]],
			[[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]]), at, 0.03)
	# Insects: trains of short chirps, in bursts, here and there.
	for burst in 7:
		var at0: float = _rng.randf_range(0.0, dur - 1.6)
		var pitch: float = _rng.randf_range(4200.0, 5400.0)
		var chirps: int = _rng.randi_range(6, 14)
		for c in chirps:
			_mix(out, _tone(0.03, [[0.0, pitch], [1.0, pitch]], [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), at0 + 0.085 * c, 0.035)
	_seamless(out, 0.6)
	return out

func _s_ambience_night() -> PackedFloat32Array:
	# The valley after dark, ten seconds that loop: the wind down, the river, the insects' chorus thick in
	# the grass (every one of them at it now, not a few here and there), and now and then, far off by the
	# water, the low croak of something amphibian (the Chinle's big metoposaurs; there were no birds).
	var dur: float = 10.0
	var n: int = int(dur * RATE)
	var out := _buf(dur)
	var brown: float = 0.0
	var lp: float = 0.0
	for i in n:
		brown = clampf(brown + _rng.randf_range(-1.0, 1.0) * 0.02, -1.0, 1.0)
		lp += 0.05 * (brown - lp)
		var t: float = float(i) / float(RATE)
		out[i] += lp * (0.6 + 0.4 * sin(TAU * t / dur * 2.0 + 1.3)) * 0.7
	var river := _hiss(dur, [[0.0, 650.0], [1.0, 650.0]], 0.8, [[0.0, 1.0], [1.0, 1.0]])
	_mix(out, river, 0.0, 0.1)
	# The chorus: five singers, each its own pitch and its own rhythm of chirp trains, over the whole take.
	for singer in 5:
		var pitch: float = _rng.randf_range(3600.0, 5200.0)
		var rate: float = _rng.randf_range(22.0, 34.0)
		var period: float = _rng.randf_range(0.7, 1.4)
		var train: float = period * _rng.randf_range(0.35, 0.6)
		var gain: float = _rng.randf_range(0.02, 0.035)
		var at: float = _rng.randf_range(0.0, period)
		while at < dur - train:
			var chirps: int = int(train * rate)
			for c in chirps:
				_mix(out, _tone(0.022, [[0.0, pitch], [1.0, pitch * 0.99]], [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]), at + float(c) / rate, gain)
			at += period
	# Far off by the water, now and then: a low, breathy croak.
	for k in 4:
		var croak := _voice({"dur": 0.24, "f0": [[0.0, 150.0], [1.0, 120.0]],
			"amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]], "formants": [[480.0, 4.0, 1.0], [1350.0, 5.0, 0.4]],
			"rough": 0.6, "rough_am": [30.0, 0.7], "breath": 0.35, "tilt": 1500.0})
		_mix(out, croak, _rng.randf_range(0.3, dur - 0.6), 0.08)
	_seamless(out, 0.6)
	return out

func _s_fire_crackle() -> PackedFloat32Array:
	# A fire, six seconds that loop: the low breath of it burning, the crackle of its wood, and now and
	# then a pop.
	var dur: float = 6.0
	var n: int = int(dur * RATE)
	var out := _buf(dur)
	var brown: float = 0.0
	var lp: float = 0.0
	for i in n:
		brown = clampf(brown + _rng.randf_range(-1.0, 1.0) * 0.03, -1.0, 1.0)
		lp += 0.08 * (brown - lp)
		out[i] += lp * 0.5
	_mix(out, _crackle(dur, 16.0, 2600.0), 0.0, 0.5)
	_mix(out, _crackle(dur, 6.0, 1300.0), 0.0, 0.45)
	for k in 5:
		_mix(out, _burst(0.035, _rng.randf_range(2200.0, 3600.0), 1.4), _rng.randf_range(0.1, dur - 0.2), 0.6)
	_seamless(out, 0.4)
	return out

# ==============================================================================
# The voice: a source through the formants of a throat
# ==============================================================================

## A call. `spec`:
##   dur        seconds
##   f0         [[t, hz], ...] the pitch over the call, t 0..1
##   amp        [[t, a], ...] its loudness
##   formants   [[hz, q, gain], ...] the tract's resonances
##   fshift     [[t, k], ...] the formants moved by k over the call (the mouth opening, closing)
##   rough      0..1 every other pulse weaker: the sub-octave of a rough, strained throat
##   rough_am   [hz, depth] a slower rasp
##   trill      [hz, depth] the call pulsed, a rattle
##   vibrato    [hz, depth] pitch wobbling, as a fraction
##   jitter     how far the pitch wanders at random
##   breath     noise through the tract with the pulses
##   tilt       where the source is rolled off, Hz: lower is a softer throat
##   nasal      0..1 a low extra resonance and the highs taken down: through the nose
func _voice(spec: Dictionary) -> PackedFloat32Array:
	var dur: float = float(spec["dur"])
	var n: int = int(dur * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	var f0_pts: Array = spec["f0"]
	var amp_pts: Array = spec["amp"]
	var rough: float = float(spec.get("rough", 0.0))
	var rough_am: Array = spec.get("rough_am", [0.0, 0.0])
	var trill: Array = spec.get("trill", [0.0, 0.0])
	var vib: Array = spec.get("vibrato", [0.0, 0.0])
	var jitter: float = float(spec.get("jitter", 0.015))
	var breath: float = float(spec.get("breath", 0.1))
	var tilt_a: float = 1.0 - exp(-TAU * float(spec.get("tilt", 3000.0)) / float(RATE))
	var phase: float = 0.0
	var periods: int = 0
	var wander: float = 0.0
	var tilt_y: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(n)
		wander = clampf(wander + _rng.randf_range(-1.0, 1.0) * 0.02, -1.0, 1.0)
		var f: float = _curve(f0_pts, u) * (1.0 + float(vib[1]) * sin(TAU * float(vib[0]) * t) + jitter * wander)
		var dt: float = f / float(RATE)
		phase += dt
		if phase >= 1.0:
			phase -= 1.0
			periods += 1
		var saw: float = 2.0 * phase - 1.0 - _blep(phase, dt)
		var pulse: float = -saw
		if rough > 0.0 and periods % 2 == 1:
			pulse *= 1.0 - rough
		tilt_y += tilt_a * (pulse - tilt_y)
		var s: float = tilt_y + _rng.randf_range(-1.0, 1.0) * breath
		var a: float = _curve(amp_pts, u)
		if float(rough_am[1]) > 0.0:
			a *= 1.0 - float(rough_am[1]) * (0.5 + 0.5 * sin(TAU * float(rough_am[0]) * t))
		if float(trill[1]) > 0.0:
			a *= 1.0 - float(trill[1]) * (0.5 + 0.5 * sin(TAU * float(trill[0]) * t))
		src[i] = s * a
	var formants: Array = spec["formants"].duplicate(true)
	var nasal: float = float(spec.get("nasal", 0.0))
	if nasal > 0.0:
		formants.append([250.0, 3.0, nasal])
	var out := _formant_bank(src, formants, spec.get("fshift", [[0.0, 1.0], [1.0, 1.0]]))
	if nasal > 0.0:
		_lowpass(out, 2600.0)
	return out

## `src` through a bank of parallel resonators, each a band-pass (the RBJ cookbook, 0 dB at
## its peak), their centres moved over the sound by `shift`.
func _formant_bank(src: PackedFloat32Array, formants: Array, shift: Array) -> PackedFloat32Array:
	var n: int = src.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for fm in formants:
		var base: float = float(fm[0])
		var q: float = float(fm[1])
		var gain: float = float(fm[2])
		var x1: float = 0.0
		var x2: float = 0.0
		var y1: float = 0.0
		var y2: float = 0.0
		var b0: float = 0.0
		var b2: float = 0.0
		var a1: float = 0.0
		var a2: float = 0.0
		for i in n:
			if i % 32 == 0:
				var f: float = minf(base * _curve(shift, float(i) / float(n)), float(RATE) * 0.45)
				var w0: float = TAU * f / float(RATE)
				var alpha: float = sin(w0) / (2.0 * q)
				var a0: float = 1.0 + alpha
				b0 = alpha / a0
				b2 = -alpha / a0
				a1 = -2.0 * cos(w0) / a0
				a2 = (1.0 - alpha) / a0
			var x: float = src[i]
			var y: float = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			out[i] += y * gain
	return out

## PolyBLEP: the saw's corner smoothed, so a high call does not alias.
func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x: float = t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x: float = (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0

# ==============================================================================
# Noise, tones, things struck
# ==============================================================================

## Breath or wind: noise through one band-pass whose centre follows `centre` [[t, hz]].
func _hiss(dur: float, centre: Array, q: float, amp: Array) -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	for i in n:
		src[i] = _rng.randf_range(-1.0, 1.0) * _curve(amp, float(i) / float(n))
	var base: float = float(centre[0][1])
	var shift: Array = []
	for p in centre:
		shift.append([float(p[0]), float(p[1]) / base])
	return _formant_bank(src, [[base, q, 1.0]], shift)

## A plain sine that glides along `hz` [[t, hz]] under `amp`.
func _tone(dur: float, hz: Array, amp: Array) -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var u: float = float(i) / float(n)
		phase += _curve(hz, u) / float(RATE)
		out[i] = sin(TAU * phase) * _curve(amp, u)
	return out

## Something struck: its modes [[hz, decay seconds, gain]], each a damped sine, and a click of
## noise `strike` seconds long where it was hit.
func _modes(dur: float, modes: Array, strike: float) -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for m in modes:
		var hz: float = float(m[0]) * _rng.randf_range(0.98, 1.02)
		var decay: float = float(m[1])
		var gain: float = float(m[2])
		var ph: float = _rng.randf_range(0.0, TAU)
		for i in n:
			var t: float = float(i) / float(RATE)
			out[i] += sin(TAU * hz * t + ph) * exp(-t / decay) * gain
	for i in mini(n, int(strike * RATE * 4.0)):
		var t: float = float(i) / float(RATE)
		out[i] += _rng.randf_range(-1.0, 1.0) * exp(-t / maxf(strike, 0.0001)) * 0.8
	return out

## A burst of noise, band-passed round `hz`, gone in `dur`.
func _burst(dur: float, hz: float, q: float) -> PackedFloat32Array:
	return _hiss(dur, [[0.0, hz], [1.0, hz]], q, [[0.0, 1.0], [0.3, 0.5], [1.0, 0.0]])

## Many small clicks over `dur`, `per_second` of them, band-passed round `hz`: grit, splinters.
func _crackle(dur: float, per_second: float, hz: float) -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	var count: int = int(per_second * dur)
	for c in count:
		var at: int = _rng.randi_range(0, maxi(0, n - 40))
		var g: float = _rng.randf_range(0.3, 1.0) * (1.0 - float(at) / float(n))
		for j in 30:
			src[at + j] += _rng.randf_range(-1.0, 1.0) * g * exp(-float(j) / 6.0)
	return _formant_bank(src, [[hz, 1.2, 1.0]], [[0.0, 1.0], [1.0, 1.0]])

## A jaw snapping shut: the click of teeth and a short knock; `k` scales its pitch (bigger is
## lower) and `growl` mixes in a short rough grunt.
func _snap(k: float, growl: float) -> PackedFloat32Array:
	var out := _modes(0.2, [[1900.0 * k, 0.018, 1.0], [3100.0 * k, 0.012, 0.6], [760.0 * k, 0.03, 0.5]], 0.0012)
	_mix(out, _burst(0.02, 3600.0 * k, 1.5), 0.0, 0.6)
	if growl > 0.0:
		_mix(out, _voice({"dur": 0.22, "f0": [[0.0, 260.0 * k], [1.0, 210.0 * k]],
			"amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]], "formants": ALPHA_FORMANTS,
			"rough": 0.7, "breath": 0.3, "tilt": 2000.0}), 0.02, growl)
	return out

## A struck bell by frequency modulation (Chowning): inharmonic partials that fade together.
func _bell(dur: float, hz: float, ratio: float) -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(RATE)
		var env: float = exp(-t / (dur * 0.3))
		var index: float = 3.0 * exp(-t / (dur * 0.2))
		out[i] = sin(TAU * hz * t + index * sin(TAU * hz * ratio * t)) * env
	return out

# ==============================================================================
# Space, mixing, saving
# ==============================================================================

## The valley round a sound: `wet` of a small reverb (Schroeder: four combs, two all-passes),
## and discrete echoes [[seconds, gain]] off the valley walls. The tail is added to the end.
func _space(dry: PackedFloat32Array, wet: float, echoes: Array) -> PackedFloat32Array:
	var tail: float = 0.9
	for e in echoes:
		tail = maxf(tail, float(e[0]) + 0.4)
	var out := PackedFloat32Array()
	out.resize(dry.size() + int(tail * RATE))
	for i in dry.size():
		out[i] = dry[i]
	for e in echoes:
		var d: int = int(float(e[0]) * RATE)
		var g: float = float(e[1])
		var lp: float = 0.0
		for i in dry.size():
			lp += 0.25 * (dry[i] - lp)
			out[i + d] += lp * g
	if wet > 0.0:
		var rev := _reverb(out, 1.4)
		for i in out.size():
			out[i] += rev[i] * wet
	return out

func _reverb(src: PackedFloat32Array, rt60: float) -> PackedFloat32Array:
	var n: int = src.size()
	var sum := PackedFloat32Array()
	sum.resize(n)
	for ms in [29.7, 37.1, 41.1, 43.7]:
		var d: int = int(ms * 0.001 * RATE)
		var g: float = pow(10.0, -3.0 * (ms * 0.001) / rt60)
		var buf := PackedFloat32Array()
		buf.resize(n)
		for i in n:
			var fb: float = buf[i - d] if i >= d else 0.0
			buf[i] = src[i] + fb * g
			sum[i] += buf[i] * 0.25
	for ms in [5.0, 1.7]:
		var d: int = int(ms * 0.001 * RATE)
		var g: float = 0.7
		var buf := PackedFloat32Array()
		buf.resize(n)
		var outp := PackedFloat32Array()
		outp.resize(n)
		for i in n:
			var delayed: float = buf[i - d] if i >= d else 0.0
			buf[i] = sum[i] + delayed * g
			outp[i] = delayed - g * buf[i]
		sum = outp
	return sum

func _lowpass(buf: PackedFloat32Array, hz: float) -> void:
	var a: float = 1.0 - exp(-TAU * hz / float(RATE))
	var y: float = 0.0
	for i in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y

## A loop that joins itself: its last `fade` seconds crossfaded into its start.
func _seamless(buf: PackedFloat32Array, fade: float) -> void:
	var m: int = int(fade * RATE)
	var n: int = buf.size()
	for i in m:
		var w: float = float(i) / float(m)
		buf[i] = buf[i] * w + buf[n - m + i] * (1.0 - w)
	buf.resize(n - m)

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

## `src` added into `dst` at `at` seconds, times `gain`; `dst` grows if it must.
func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float) -> void:
	var off: int = int(at * RATE)
	if off + src.size() > dst.size():
		dst.resize(off + src.size())
	for i in src.size():
		dst[off + i] += src[i] * gain

## A piecewise-linear curve [[t, v], ...] read at `u` (0..1).
func _curve(points: Array, u: float) -> float:
	if points.size() == 1:
		return float(points[0][1])
	if u <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var p0: Array = points[i - 1]
		var p1: Array = points[i]
		if u <= float(p1[0]):
			var span: float = maxf(0.0001, float(p1[0]) - float(p0[0]))
			return lerpf(float(p0[1]), float(p1[1]), (u - float(p0[0])) / span)
	return float(points[points.size() - 1][1])

## Written as 16-bit mono: its DC taken off, a few milliseconds faded in and out so nothing
## clicks, and its peak set just under full scale -- how loud it plays is Config.SOUNDS'.
func _save(id: String, data: PackedFloat32Array) -> void:
	var n: int = data.size()
	var mean: float = 0.0
	for i in n:
		mean += data[i]
	mean /= maxf(1.0, float(n))
	var hp: float = 0.0
	var prev: float = 0.0
	var peak: float = 0.0001
	for i in n:
		# A gentle high-pass at ~20 Hz: nothing below what a speaker can move.
		var x: float = data[i] - mean
		hp = 0.994 * (hp + x - prev)
		prev = x
		data[i] = hp
		peak = maxf(peak, absf(hp))
	var fade: int = mini(int(0.004 * RATE), int(n / 4.0))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = data[i] / peak * 0.89
		if i < fade:
			v *= float(i) / float(fade)
		elif i >= n - fade:
			v *= float(n - 1 - i) / float(fade)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var err: int = wav.save_to_wav(OUT + id + ".wav")
	print("[%s] %s  %.2fs" % ["OK" if err == OK else "ERR %d" % err, id, float(n) / float(RATE)])
