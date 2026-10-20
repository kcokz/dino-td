extends SceneTree
## Whole runs played by the rules alone, no screen, many at once -- to see how hard the places are, and how each way of
## playing does (GAME-DESIGN 17-19).
##
##   Godot --headless --path dino-raid --script res://tools/sim_runs.gd -- [smart|random|school] [runs] [first seed] [measure|limit]
##
## random, smart and school play as tools/Policy.gd says, each run with the next ark (Content.ARKS) in turn; school is
## smart keeping to the next school (Content.SCHOOLS) in turn, taking another school's kind out of the shop each round
## (its ark turns once all the schools have had a run, starting from the first seed's).
## All carry on what the packing screen picks to begin with. Prints, for each run, how far it got, the homeland's
## health at each place's end and how many goods it carried on, what it built; then how many held each place -- and,
## for school, how each school did. "measure": also, each round, the army's strength against the wave's. "limit": no
## one comes, every battle is won, everything goes to growing; prints, round by round, the strength the runs' armies
## had on average -- Content.LIMIT, to paste in after changing what can be built or made (run it with school, so that
## every way of playing counts) -- and the most any had.

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
	for l in Content.LEVELS:
		held.append(0)
	var lost_battles := 0
	var battles := 0
	var arks: Array = Content.ARKS.keys()
	var schools: Array = Content.SCHOOLS.keys()
	var by_school := {}                # school -> [runs, held all, battles lost, hp left]
	for k in runs:
		var seed := first + k
		rng.seed = seed
		var run := Run.new(seed)
		run.calm = limit
		var school: String = schools[k % schools.size()] if policy == "school" else ""
		# Each school in turn; for school, the ark turns once a round of schools, so no school always has the same one.
		run.choose_ark(arks[(k / schools.size() + first) % arks.size()] if school != "" else arks[k % arks.size()])
		var line := "seed %3d %-5s %-6s:" % [seed, run.ark, school]
		var losses := 0
		var lost_here := 0
		var g := 0
		var all_held := false
		while not run.over:
			run.start_round()
			if policy == "random":
				_random(run)
			else:
				_smart(run, school)
			g += 1
			if limit:
				while best.size() < g:
					best.append(0.0)
					total.append(0.0)
					seen.append(0)
				best[g - 1] = maxf(best[g - 1], run.strength())
				total[g - 1] += run.strength()
				seen[g - 1] += 1
			if measure:
				var wave_strength := 0.0
				for kind in run.wave():
					wave_strength += Content.enemy_strength(kind, run.power())
				print("  %s r%d: army of %2d, strength %4d; the wave %4d (%d of them)" % [Content.LEVELS[run.level].name,
					run.round, run.home.army().size(), roundi(run.strength()), roundi(wave_strength), run.wave().size()])
			var f := run.fight()
			f.run()
			var out := run.finish(f)
			battles += 1
			if out.result != "won":
				losses += 1
				lost_here += 1
				lost_battles += 1
			if run.over:
				line += "  died in %s round %d" % [Content.LEVELS[run.level].name, run.round]
				break
			var gifts := run.gift_offer()
			if not gifts.is_empty():
				run.take_gift(gifts[Policy.best_gift(run, run.home, gifts) if policy != "random" else 0])
			if out.level_won:
				held[run.level] += 1
				line += "  %s hp %d/%d (lost %d)" % [Content.LEVELS[run.level].name, run.home.hp, run.home.hp_max(), losses]
				losses = 0
				if run.last_level():
					line += "  ALL HELD"
					all_held = true
					break
				var offer := run.relic_offer()
				run.take_relic(Policy.best_relic(run, run.home, offer) if policy != "random" else offer[rng.randi() % offer.size()])
				var goods := Policy.best_goods(run)
				line += " carried %d" % mini(goods.size(), run.home.stash_size())
				run.move_on(goods)
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
		print(line, "  | wonder ", run.home.wonder, " relics ", run.home.relics, " built ", built)
	var said: Array = []
	for i in held.size():
		said.append("%s %d" % [Content.LEVELS[i].name, held[i]])
	print("%s: %d runs; held %s; battles lost %d of %d" % [policy, runs, ", ".join(said), lost_battles, battles])
	for s in by_school:
		var sc: Array = by_school[s]
		print("  %s: %d runs, held all %d, battles lost %d, hp left %d" % [Content.SCHOOLS[s].name, sc[0], sc[1], sc[2], sc[3]])
	if limit:
		var out := "const LIMIT := ["
		var most := "# the most: ["
		var top := 0.0
		for i in best.size():
			top = maxf(top, total[i] / maxf(1.0, seen[i]))     # never less than the round before
			out += "%d%s" % [roundi(top), ", " if i < best.size() - 1 else "]"]
			most += "%d%s" % [roundi(best[i]), ", " if i < best.size() - 1 else "]"]
		print(out)
		print(most)
	quit()


func _random(run: Run) -> void:
	for guard in 20:
		var play := Policy.any_play(run.home, rng)
		if play.is_empty():
			break
		Policy.play(run.home, play)


func _smart(run: Run, school: String) -> void:
	var restocked := 0
	for guard in 16:
		var play := Policy.best_play(run, run.home, school)
		if play.is_empty():
			# Nothing worth it on the shelf: restock it, if that leaves enough to buy with.
			if restocked < 2 and run.home.gold >= run.home.reroll_price() + 4:
				var k := Policy.best_removal(run.home, school)
				if k >= 0:
					run.home.remove_kind(k)
				run.reroll()
				restocked += 1
				continue
			break
		Policy.play(run.home, play)
	var k := Policy.best_removal(run.home, school)
	if k >= 0:
		run.home.remove_kind(k)
