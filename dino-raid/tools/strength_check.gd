extends SceneTree
## Checks the strength numbers (Content.strength) against the battles themselves (GAME-DESIGN 15, 17):
##
##   Godot --headless --path dino-raid --script res://tools/strength_check.gd
##
## 1. Each kind alone: a band of it against greys (ours) or of greys against it (theirs) -- how many it beats, against
##    what its strength says it should (ratio 1.00 is right).
## 2. Mixed sides: random armies (some with affixes) against random waves of a given strength ratio -- how often the
##    army wins. At 1.0 it should be about half.

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7
	print("-- each kind, a band of about 80 strength, against greys")
	for kind in Content.UNITS:
		_alone(kind, [])
	for affix in Content.AFFIXES:
		_alone("red", [affix])
	print("-- each enemy, a band of about 80 strength, against reds")
	for kind in Content.ENEMIES:
		_enemy(kind)
	print("-- mixed: random armies against random waves (wins of 60 at each ratio of wave to army)")
	for ratio in [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.4]:
		var wins := 0
		for t in 60:
			if _mixed(ratio):
				wins += 1
		print("  wave %.1f x army: army wins %2d of 60" % [ratio, wins])
	quit()


## What a nest of `kind` with `affixes` gives its units, standing alone; an evolved kind (no nest of its own), plain.
func _spec(kind: String, affixes: Array) -> Dictionary:
	if not Content.BUILDINGS.has("nest_" + kind):
		return {"kind": kind, "nest": Vector2i.ZERO, "hp_mult": 1.0, "atk_mult": 1.0, "atk_bonus": 0, "affixes": []}
	var h := Home.new(rng)
	h.buildings.clear()
	h.terrain.clear()
	h.build(Vector2i(0, 3), "nest_" + kind)
	h.buildings[Vector2i(0, 3)].affixes = affixes
	return h.spec_of(Vector2i(0, 3))


func _alone(kind: String, affixes: Array) -> void:
	var spec := _spec(kind, affixes)
	var one := Content.strength(Content.unit_stats(spec))
	var n := maxi(1, roundi(80.0 / one))
	var lo := 0
	var hi := 1
	while hi < 300 and _beats(spec, n, hi):
		lo = hi
		hi *= 2
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _beats(spec, n, mid):
			lo = mid
		else:
			hi = mid
	print("  %-6s %-8s strength %5.1f: %2d of them beat %3d grey -> ratio %.2f" % [kind, ",".join(affixes), one, n, lo,
		lo * 10.0 / (n * one)])


func _beats(spec: Dictionary, n: int, m: int) -> bool:
	var army: Array = []
	for i in n:
		var u := spec.duplicate()
		u.id = "x:%d" % i
		army.append(u)
	var wave: Array = []
	for i in m:
		wave.append("grey")
	var f := Fight.make(army, wave, 1.0)
	f.run()
	return f.result == "won"


func _enemy(kind: String) -> void:
	var one := Content.enemy_strength(kind)
	var n := maxi(1, roundi(80.0 / one))
	var red := _spec("red", [])
	red.hp_mult = 1.0
	var red_strength := Content.strength(Content.unit_stats(red))
	var lo := 0
	var hi := 1
	while hi < 300 and not _red_band_wins(red, hi, kind, n):
		lo = hi
		hi *= 2
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _red_band_wins(red, mid, kind, n):
			hi = mid
		else:
			lo = mid
	print("  %-6s strength %5.1f: %2d of them beat %3d red -> ratio %.2f" % [kind, one, n, lo, lo * red_strength / (n * one)])


func _red_band_wins(red: Dictionary, reds: int, kind: String, n: int) -> bool:
	var army: Array = []
	for i in reds:
		var u := red.duplicate()
		u.id = "r:%d" % i
		army.append(u)
	var wave: Array = []
	for i in n:
		wave.append(kind)
	var f := Fight.make(army, wave, 1.0)
	f.run()
	return f.result == "won"


## A random army of about 100 strength against a random wave of `ratio` times that.
func _mixed(ratio: float) -> bool:
	var army: Array = []
	var ours := 0.0
	var kinds := Content.UNITS.keys()
	var affixes := Content.AFFIXES.keys()
	while ours < 100.0:
		var k: String = kinds[rng.randi() % kinds.size()]
		var a: Array = [affixes[rng.randi() % affixes.size()]] if rng.randf() < 0.3 else []
		var u := _spec(k, a)
		u.id = "m:%d" % army.size()
		army.append(u)
		ours += Content.strength(Content.unit_stats(u))
	var wave: Array = []
	var theirs := 0.0
	var foes := ["grey", "grey", "purple", "black", "spore", "beetle", "salamander"]
	if ratio >= 1.0 and rng.randf() < 0.3:
		var boss: String = ["boss_rain", "boss_lava"][rng.randi() % 2]
		wave.append(boss)
		theirs += Content.enemy_strength(boss)
	while theirs < ours * ratio - 5.0:
		var k: String = foes[rng.randi() % foes.size()]
		wave.append(k)
		theirs += Content.enemy_strength(k)
	var f := Fight.make(army, wave, 1.0)
	f.run()
	return f.result == "won"