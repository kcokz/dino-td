extends SceneTree
## Whole runs played by the rules alone, no screen, many at once -- to see how hard the levels are (GAME-DESIGN 12).
##
##   Godot --headless --path dino-raid --script res://tools/sim_runs.gd -- [smart|random] [runs] [first seed] [measure|limit]
##
## random and smart play as tools/Policy.gd says. Both take the first card offered and upgrade the first they can. Prints, for each run, how far it got and the homeland's health at
## each level's end; then how many held each level. "measure": also, each round, how many greys (at the level's
## power) the army just made ready could beat -- how strong a wave would have to be to stop it. "limit": no one
## comes, every battle is won, everything goes to growing; prints, round by round, the most strength any run had
## in its yard -- Content.LIMIT, to paste in after changing what can be built or made.

var policy := "smart"
var measure := false
var limit := false
var best: Array = []               # limit: the most strength seen at each round of the run
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	policy = args[0] if args.size() > 0 else "smart"
	var runs := int(args[1]) if args.size() > 1 else 10
	var first := int(args[2]) if args.size() > 2 else 1
	measure = args.size() > 3 and args[3] == "measure"
	limit = args.size() > 3 and args[3] == "limit"
	var held := [0, 0, 0]
	var lost_battles := 0
	var battles := 0
	for k in runs:
		var seed := first + k
		rng.seed = seed
		var run := Run.new(seed)
		run.calm = limit
		var line := "seed %3d:" % seed
		var g := 0
		var losses := 0
		while not run.over:
			run.start_round()
			if policy == "smart":
				_smart(run)
			else:
				_random(run)
			if measure:
				print("  %s r%2d: %2d units, beats %3d greys; the wave is %s" % [Content.LEVELS[run.level].name, run.round,
					run.home.units.size(), _beats(run), _count(run.wave())])
			g += 1
			if limit:
				while best.size() < g:
					best.append(0.0)
				best[g - 1] = maxf(best[g - 1], run.strength())
			var f := run.fight()
			f.run()
			var out := run.finish(f)
			battles += 1
			if out.result != "won":
				losses += 1
				lost_battles += 1
			if run.over:
				line += "  died in %s round %d" % [Content.LEVELS[run.level].name, run.round]
				break
			if out.level_won:
				held[run.level] += 1
				line += "  %s hp %d/%d (lost %d)" % [Content.LEVELS[run.level].name, run.home.hp, run.home.hp_max(), losses]
				losses = 0
				if run.last_level():
					line += "  ALL HELD"
					break
				run.take(run.offer()[0])
				for ci in run.deck():
					if not ci.up:
						run.upgrade(ci)
						break
				run.next_level()
			elif out.result == "won":
				run.take(run.offer()[0])
		var army := {}
		for u in run.home.units:
			var key := "%s%d" % [u.kind, u.star]
			army[key] = army.get(key, 0) + 1
		var built := {}
		for p in run.home.buildings:
			var b: Dictionary = run.home.buildings[p]
			var key := "%s%d" % [b.kind, b.level]
			built[key] = built.get(key, 0) + 1
		print(line, "  | army ", army, " | built ", built, " | deck ", run.deck().map(func(ci: Dictionary) -> String:
			return ci.id + ("+" if ci.up else "")))
	print("%s: %d runs; held level 1: %d, level 2: %d, level 3: %d; battles lost %d of %d" % [policy, runs, held[0], held[1],
		held[2], lost_battles, battles])
	if limit:
		var line := "const LIMIT := ["
		var top := 0.0
		for i in best.size():
			top = maxf(top, best[i])     # never less than the round before
			line += "%d%s" % [roundi(top), ", " if i < best.size() - 1 else "]"]
		print(line)
	quit()


## The most greys at the level's power the army (with this round's buffs) beats.
func _beats(run: Run) -> int:
	var lo := 0
	var hi := 1
	while hi < 400 and _wins(run, hi):
		lo = hi
		hi *= 2
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _wins(run, mid):
			lo = mid
		else:
			hi = mid
	return lo


func _wins(run: Run, n: int) -> bool:
	var wave: Array = []
	for i in n:
		wave.append("grey")
	var f := Fight.make(run.home, wave, run.power())
	f.run()
	return f.result == "won"


func _count(wave: Array) -> Dictionary:
	var out := {}
	for k in wave:
		out[k] = out.get(k, 0) + 1
	return out


func _random(run: Run) -> void:
	for guard in 20:
		var play := Policy.any_play(run.home, rng)
		if play.is_empty():
			return
		run.home.play(play[0], play[1])


func _smart(run: Run) -> void:
	for guard in 12:
		var play := Policy.best_play(run, run.home)
		if play.is_empty():
			return
		run.home.play(play[0], play[1])
