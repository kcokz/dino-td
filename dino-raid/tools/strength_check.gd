extends SceneTree
## Checks the strength numbers (Content.strength) against the battles themselves (GAME-DESIGN 12):
##
##   Godot --headless --path dino-raid --script res://tools/strength_check.gd
##
## 1. Each kind alone: a band of it against greys (ours) or reds (theirs) -- how many it beats, against what its
##    strength says it should (ratio 1.00 is right).
## 2. Mixed sides: random armies against random waves of a given strength ratio -- how often the army wins.
##    At 1.0 it should be about half.

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7
	print("-- each kind, a band of about 80 strength, against greys (ours) or reds (theirs)")
	for kind in Content.UNITS:
		for star in [1, 2, 3]:
			if star > 1 and kind != "red" and kind != "blue":
				continue
			_alone("ours", kind, star)
	for kind in Content.ENEMIES:
		_alone("theirs", kind, 1)
	print("-- mixed: random armies against random waves (wins of 60 at each ratio of wave to army)")
	for ratio in [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.4]:
		var wins := 0
		for t in 60:
			if _mixed(ratio):
				wins += 1
		print("  wave %.1f x army: army wins %2d of 60" % [ratio, wins])
	quit()


func _alone(side: String, kind: String, star: int) -> void:
	var one := Content.unit_strength(side, kind, star)
	var n := maxi(1, roundi(80.0 / one))
	var foe := "grey" if side == "ours" else "red"
	var lo := 0
	var hi := 1
	while hi < 300 and _beats(side, kind, star, n, foe, hi):
		lo = hi
		hi *= 2
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _beats(side, kind, star, n, foe, mid):
			lo = mid
		else:
			hi = mid
	var foe_strength := Content.unit_strength("theirs" if side == "ours" else "ours", foe)
	print("  %-6s %d* strength %5.1f: %2d of them beat %3d %s -> ratio %.2f" % [kind, star, one, n, lo, foe,
		lo * foe_strength / (n * one)])


func _beats(side: String, kind: String, star: int, n: int, foe: String, m: int) -> bool:
	var f := Fight.new()
	for i in n:
		f._add(side, kind, star, 0, 0, 0, 0, 1.0, 0)
	for i in m:
		f._add("theirs" if side == "ours" else "ours", foe, 1, 0, 0, 0, 0, 1.0, 0)
	f._form("ours")
	f._form("theirs")
	f.run()
	return f.result == "won" if side == "ours" else f.result != "won"


## A random army of about 100 strength against a random wave of `ratio` times that.
func _mixed(ratio: float) -> bool:
	var f := Fight.new()
	var ours := 0.0
	var kinds := Content.UNITS.keys()
	while ours < 100.0:
		var k: String = kinds[rng.randi() % kinds.size()]
		var star := 1 + (1 if rng.randf() < 0.3 else 0)
		f._add("ours", k, star, 0, 0, 0, 0, 1.0, 0)
		ours += Content.unit_strength("ours", k, star)
	var theirs := 0.0
	var foes := ["grey", "grey", "purple", "black"]
	if ratio >= 1.0 and rng.randf() < 0.3:
		f._add("theirs", "boss", 1, 0, 0, 0, 0, 1.0, 0)
		theirs += Content.unit_strength("theirs", "boss")
	while theirs < ours * ratio - 5.0:
		var k: String = foes[rng.randi() % foes.size()]
		f._add("theirs", k, 1, 0, 0, 0, 0, 1.0, 0)
		theirs += Content.unit_strength("theirs", k)
	f._form("ours")
	f._form("theirs")
	f.run()
	return f.result == "won"
