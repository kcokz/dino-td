extends SceneTree
## Whole runs played by the rules alone, no screen, many at once -- to see how hard the levels are (GAME-DESIGN 15).
##
##   Godot --headless --path dino-raid --script res://tools/sim_runs.gd -- [smart|random] [runs] [first seed] [measure|limit]
##
## random and smart play as tools/Policy.gd says; at each level's end both take the first relic offered.
## Prints, for each run, how far it got and the homeland's health at each level's end, what it built; then how many
## held each level. "measure": also, each round, the army's strength against the wave's. "limit": no one comes, every
## battle is won, everything goes to growing; prints, round by round, the most strength any run's army had --
## Content.LIMIT, to paste in after changing what can be built or made.

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
		var losses := 0
		var g := 0
		while not run.over:
			run.start_round()
			if policy == "smart":
				_smart(run)
			else:
				_random(run)
			g += 1
			if limit:
				while best.size() < g:
					best.append(0.0)
				best[g - 1] = maxf(best[g - 1], run.strength())
			if measure:
				var wave_strength := 0.0
				for kind in run.wave():
					wave_strength += Content.enemy_strength(kind, run.power())
				print("  %s r%2d: army of %2d, strength %4d; the wave %4d (%d of them)" % [Content.LEVELS[run.level].name,
					run.round, run.home.army().size(), roundi(run.strength()), roundi(wave_strength), run.wave().size()])
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
			var gifts := run.gift_offer()
			if not gifts.is_empty():
				run.take_gift(gifts[Policy.best_gift(run, run.home, gifts) if policy == "smart" else 0])
			if out.level_won:
				held[run.level] += 1
				line += "  %s hp %d/%d (lost %d)" % [Content.LEVELS[run.level].name, run.home.hp, run.home.hp_max(), losses]
				losses = 0
				if run.last_level():
					line += "  ALL HELD"
					break
				run.take_relic(run.relic_offer()[0])
				run.next_level()
		var built := {}
		for p in run.home.buildings:
			var b: Dictionary = run.home.buildings[p]
			var key := "%s%d%s" % [b.kind, b.level, "+" + "+".join(b.affixes) if not b.affixes.is_empty() else ""]
			built[key] = built.get(key, 0) + 1
		print(line, "  | built ", built)
	print("%s: %d runs; held level 1: %d, level 2: %d, level 3: %d; battles lost %d of %d" % [policy, runs, held[0], held[1],
		held[2], lost_battles, battles])
	if limit:
		var out := "const LIMIT := ["
		var top := 0.0
		for i in best.size():
			top = maxf(top, best[i])     # never less than the round before
			out += "%d%s" % [roundi(top), ", " if i < best.size() - 1 else "]"]
		print(out)
	quit()


func _random(run: Run) -> void:
	for guard in 20:
		var play := Policy.any_play(run.home, rng)
		if play.is_empty():
			break
		run.home.buy(play[0], play[1])
	if not run.home.potions.is_empty() and rng.randf() < 0.3:
		run.home.use_potion(rng.randi() % run.home.potions.size())


func _smart(run: Run) -> void:
	var restocked := 0
	for guard in 16:
		var play := Policy.best_play(run, run.home)
		if play.is_empty():
			# Nothing worth it on the shelf: restock it, if that leaves enough to buy with.
			if restocked < 2 and run.home.gold >= run.home.reroll_price() + 4:
				run.reroll()
				restocked += 1
				continue
			break
		run.home.buy(play[0], play[1])
	var k := Policy.best_potion(run, run.home)
	if k >= 0:
		run.home.use_potion(k)