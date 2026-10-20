class_name Policy
## How the tools play (GAME-DESIGN 14), shared by playtest.gd and sim_runs.gd. Not part of the game.
##
## random: any card it can afford, on a target picked at random; now and then a potion.
## smart: the play that does the most good for its cost -- this round's battle worked out after it (the forecast the
## player sees), and what the homeland comes to: the army its nests make (as far as the biomass coming in feeds it),
## what comes in each round, what is kept. A potion only when it turns a lost battle.


## A random play: [hand index, target], or [] when none can be played. A careless player, not a wrecker: it builds
## on empty plots while there are any, and pulls nothing down.
static func any_play(h: Home, rng: RandomNumberGenerator) -> Array:
	var can: Array = []
	for i in h.hand.size():
		if not _careless(h, i).is_empty():
			can.append(i)
	if can.is_empty():
		return []
	var i: int = can[rng.randi() % can.size()]
	var fits := _careless(h, i)
	return [i, fits[rng.randi() % fits.size()]]


static func _careless(h: Home, i: int) -> Array:
	var fits := h.targets(i)
	if Content.card(h.hand[i]).type == "build":
		fits = fits.filter(func(p: Vector2i) -> bool: return not h.buildings.has(p))
	return fits


## The best play for its cost: [hand index, target], or [] when nothing beats keeping the energy.
static func best_play(run: Run, h: Home) -> Array:
	var base := score(run, h)
	var best_gain := 0.01
	var best: Array = []
	for i in h.hand.size():
		var c := Content.card(h.hand[i])
		var cost := maxf(1.0, float(c.cost) + 0.5 * float(c.get("genes", 0)) + 2.0 * float(c.get("alien", 0)))
		for at in h.targets(i):
			var t := h.clone()
			t.play(i, at)
			var gain := (score(run, t) - base) / cost
			if gain > best_gain:
				best_gain = gain
				best = [i, at]
	return best


## The potion that turns this round's battle (won where it was lost, or less harm), or -1.
static func best_potion(run: Run, h: Home) -> int:
	var now := _battle(run, h)
	if now.won:
		return -1
	var best := -1
	var best_harm := int(now.harm)
	for k in h.potions.size():
		var t := h.clone()
		t.use_potion(k)
		var then := _battle(run, t)
		if then.won:
			return k
		if int(then.harm) < best_harm:
			best_harm = int(then.harm)
			best = k
	return best


static func score(run: Run, h: Home) -> float:
	var b := _battle(run, h)
	var s := 300.0 + float(b.left) * 5.0 if b.won else -float(b.harm) * 12.0
	# The army the nests can make, as far as what comes in feeds it.
	var full := h.clone()
	full.biomass = 999
	var army := full.army()
	var food := 0
	var strength := 0.0
	for u in army:
		food += int(Content.UNITS[u.kind].food)
		strength += Content.strength(Content.unit_stats(u))
	var fed := minf(1.0, (float(h.income_biomass()) + 1.0) / maxf(1.0, float(food)))
	s += strength * (0.4 + 0.6 * fed) * 1.5
	s += 10.0 * h.income_energy() + 5.0 * h.income_biomass() + 4.0 * h.income_genes()
	s += 0.5 * h.biomass + 1.0 * h.genes + 3.0 * h.alien + 2.0 * h.energy + 8.0 * h.potions.size()
	s += 5.0 * h.block() + 0.5 * h.hp_max()
	return s


static func _battle(run: Run, h: Home) -> Dictionary:
	var f := Fight.make(h.army(), h.buffs, run.wave(), run.power())
	f.run()
	return {"won": f.result == "won", "left": f.alive("ours").size(), "harm": maxi(0, f.harm() - h.block())}