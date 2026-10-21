extends SceneTree
## Whole runs played by the rules alone, no screen, many at once -- to see how hard the places are, and how each way of
## playing does (GAME-DESIGN 17-22).
##
##   Godot --headless --path dino-raid --script res://tools/sim_runs.gd -- [smart|random|school] [runs] [first seed] [measure|limit]
##
## random, smart and school play as tools/Policy.gd says; school is smart keeping to the next school (Content.SCHOOLS)
## in turn. After each round random takes a blueprint (or the gold) at random, the others the best (Policy.best_reward)
## -- after a mini-boss, of the uncommon and the rare; on the map, the first of the two. Prints,
## for each run, how far it got, the homeland's health at each level's end, its stars and what it built; then how many
## held each level -- and,
## for school, how each school did. "measure": also, each round, the army's strength against the wave's. "limit": no
## one comes, every battle is won, everything goes to growing; prints each run's strength round by round ("# curve") --
## tools/limit.py makes Content.LIMIT from them (run it with school, so that every way of playing counts) -- and, round
## by round, the strength the runs' armies had on average (never less than the round before within a level; each level
## starting again from what every place starts with), the most any had, and the plain average.

var policy := "smart"
var measure := false
var limit := false
var best: Array = []               # limit: the most strength seen at each round of the run
var total: Array = []              # limit: the strength seen at each round, all runs together
var seen: Array = []               # limit: how many runs got to each round
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	policy = args[0] if args.size() > 0 else "smart"
	var runs := int(args[1]) if args.size() > 1 else 10
	var first := int(args[2]) if args.size() > 2 else 1
	measure = args.size() > 3 and args[3] == "measure"
	limit = args.size() > 3 and args[3] == "limit"
	var held: Array = []
	for t in Content.TIERS:
		held.append(0)
	var lost_battles := 0
	var battles := 0
	var schools: Array = Content.SCHOOLS.keys()
	var by_school := {}                # school -> [runs, held all, battles lost, hp left]
	for k in runs:
		var seed := first + k
		rng.seed = seed
		var run := Run.new(seed)
		run.calm = limit
		var school: String = schools[k % schools.size()] if policy == "school" else ""
		var line := "seed %3d %-6s:" % [seed, school]
		var losses := 0
		var lost_here := 0
		var g := 0
		var all_held := false
		var curve: Array = []             # limit: this run's strength, round by round
		while not run.over:
			run.start_round()
			if policy == "random":
				_random(run)
			else:
				_smart(run, school)
			run.make()
			run.eat()
			g += 1
			if limit:
				while best.size() < g:
					best.append(0.0)
					total.append(0.0)
					seen.append(0)
				best[g - 1] = maxf(best[g - 1], run.strength())
				curve.append(roundi(run.strength()))
				total[g - 1] += run.strength()
				seen[g - 1] += 1
			if measure:
				var wave_strength := 0.0
				for kind in run.wave():
					wave_strength += Content.enemy_strength(kind, run.power())
				print("  %s r%d: army of %2d, strength %4d; the wave %4d (%d of them)" % [Content.LEVELS[run.place].name,
					run.round, run.home.fighters.size(), roundi(run.strength()), roundi(wave_strength), run.wave().size()])
			var f := run.fight()
			f.run()
			var out := run.finish(f)
			battles += 1
			if out.result != "won":
				losses += 1
				lost_here += 1
				lost_battles += 1
			if run.over:
				line += "  died in %s (level %d) round %d" % [Content.LEVELS[run.place].name, run.level + 1, run.round]
				break
			var cards := run.rare_offer() if run.was_mini() else run.reward_offer()
			if not cards.is_empty():
				var pick := Policy.best_reward(run, run.home, cards, school) if policy != "random" else rng.randi_range(-1, cards.size() - 1)
				if pick >= 0:
					run.take_reward(cards[pick].id)
				else:
					run.take_reward_gold()
			if out.level_won:
				held[run.level] += 1
				line += "  %s hp %d/%d (lost %d)" % [Content.LEVELS[run.place].name, run.home.hp, run.home.hp_max(), losses]
				losses = 0
				if run.last_level():
					line += "  ALL HELD"
					all_held = true
					break
				run.move_on(Policy.best_place(run))
		if school != "":
			var sc: Array = by_school.get(school, [0, 0, 0, 0])
			sc[0] += 1
			sc[1] += 1 if all_held else 0
			sc[2] += lost_here
			sc[3] += run.home.hp if all_held else 0
			by_school[school] = sc
		var built := {}
		for p in run.home.buildings:
			var b: Dictionary = run.home.buildings[p]
			var key := "%s%d%s%s" % [b.kind, b.level, "*" + "*".join(b.path) if b.path.count("elite") > 0 else "",
				"+" + "+".join(b.affixes) if not b.affixes.is_empty() else ""]
			built[key] = built.get(key, 0) + 1
		print(line, "  | stars ", run.home.stars.map(func(s: Dictionary) -> String: return s.id), " built ", built)
		if limit:
			print("# curve %s: %s" % [school if school != "" else "-", curve])
	var said: Array = []
	for i in held.size():
		said.append("level %d: %d" % [i + 1, held[i]])
	print("%s: %d runs; held %s; battles lost %d of %d" % [policy, runs, ", ".join(said), lost_battles, battles])
	for s in by_school:
		var sc: Array = by_school[s]
		print("  %s: %d runs, held all %d, battles lost %d, hp left %d" % [Content.SCHOOLS[s].name, sc[0], sc[1], sc[2], sc[3]])
	if limit:
		var out := "const LIMIT := ["
		var most := "# the most: ["
		var mean := "# the average, round by round: ["
		var top := 0.0
		for i in best.size():
			if i % Content.ROUNDS == 0:
				top = 0.0                                       # a new level: the homeland starts again
			top = maxf(top, total[i] / maxf(1.0, seen[i]))     # never less than the round before, within a level
			var end := ", " if i < best.size() - 1 else "]"
			out += "%d%s" % [roundi(top), end]
			most += "%d%s" % [roundi(best[i]), end]
			mean += "%d%s" % [roundi(total[i] / maxf(1.0, seen[i])), end]
		print(out)
		print(most)
		print(mean)
	quit()


func _random(run: Run) -> void:
	for guard in 20:
		var play := Policy.any_play(run.home, rng)
		if play.is_empty():
			break
		Policy.play(run.home, play)


func _smart(run: Run, school: String) -> void:
	for guard in 16:
		var play := Policy.best_play(run, run.home, school)
		if play.is_empty():
			break
		Policy.play(run.home, play)
