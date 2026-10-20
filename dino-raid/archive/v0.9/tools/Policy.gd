class_name Policy
## How the tools play (GAME-DESIGN 17, 18), shared by playtest.gd and sim_runs.gd. Not part of the game.
##
## random: buys anything it can afford, put anywhere it may go (but building only on empty land, pulling nothing
## down), and puts down what it keeps the same way. smart: the buy or the putting down that does the most good for its
## price -- this round's battle worked out after it (the forecast the player sees), and what the homeland comes to: the
## army its nests make (as far as the biomass coming in feeds it), what comes in each round, what is kept (gold earns
## interest); restocks the shelf when nothing on it is worth buying; the gift and the relic that do the most good.
## Both carry on what the packing screen picks to begin with (Run.default_goods).


## A random play: ["buy" or "place", index, target], or [] when there is none.
static func any_play(h: Home, rng: RandomNumberGenerator) -> Array:
	var can: Array = []
	for i in h.shelf.size():
		var fits := _careless(h, h.targets(i), h.shelf[i])
		if not fits.is_empty():
			can.append(["buy", i, fits])
	for k in h.stash.size():
		var fits := _careless(h, h.stash_targets(k), h.stash[k])
		if not fits.is_empty():
			can.append(["place", k, fits])
	if can.is_empty():
		return []
	var c: Array = can[rng.randi() % can.size()]
	return [c[0], c[1], c[2][rng.randi() % c[2].size()]]


static func _careless(h: Home, fits: Array, oi: Variant) -> Array:
	if not fits.is_empty() and Content.offer(oi).type == "build":
		return fits.filter(func(p: Vector2i) -> bool: return not h.buildings.has(p))
	return fits


## Does a play (["buy" or "place", index, target]) to `h`. Its events.
static func play(h: Home, p: Array) -> Array:
	return h.buy(p[1], p[2]) if p[0] == "buy" else h.place(p[1], p[2])


## The best play for its price -- a buy, or putting down what was kept (paid for already): ["buy" or "place", index,
## target], or [] when nothing beats keeping the gold.
static func best_play(run: Run, h: Home) -> Array:
	var base := score(run, h)
	var best_gain := 0.01
	var best: Array = []
	for i in h.shelf.size():
		for at in h.targets(i):
			var o := Content.offer(h.shelf[i])
			var cost := maxf(1.0, float(h.price(i, at)) + 0.5 * float(o.get("genes", 0)) + 2.0 * float(o.get("alien", 0)))
			var t := h.clone()
			t.buy(i, at)
			var gain := (score(run, t) - base) / cost
			if gain > best_gain:
				best_gain = gain
				best = ["buy", i, at]
	for k in h.stash.size():
		for at in h.stash_targets(k):
			var t := h.clone()
			t.place(k, at)
			var gain := score(run, t) - base
			if gain > best_gain:
				best_gain = gain
				best = ["place", k, at]
	return best


## The gift that does the most good where it goes best: its index in `gifts`.
static func best_gift(run: Run, h: Home, gifts: Array) -> int:
	var best := 0
	var best_score := -INF
	for k in gifts.size():
		var t := h.clone()
		t.stash.append(gifts[k].duplicate())
		var last := t.stash.size() - 1
		for at in t.stash_targets(last):
			var u := t.clone()
			u.place(last, at)
			var s := score(run, u)
			if s > best_score:
				best_score = s
				best = k
	return best


## The relic that does the most good now: one of `ids`.
static func best_relic(run: Run, h: Home, ids: Array) -> String:
	var best: String = ids[0]
	var best_score := -INF
	for id in ids:
		var t := h.clone()
		t.relics.append(id)
		var s := score(run, t)
		if s > best_score:
			best_score = s
			best = id
	return best


## What to carry on to the next place: the goods that cost the most (Run.default_goods), as the packing screen picks.
static func best_goods(run: Run) -> Array:
	return run.default_goods()



static func score(run: Run, h: Home) -> float:
	var b := _battle(run, h)
	var s := 300.0 + float(b.left) * 5.0 if b.won else -float(b.harm) * 12.0
	# The army the nests can make, as far as what comes in feeds it.
	var full := h.clone()
	full.biomass = 999
	var food := 0
	var strength := 0.0
	for u in full.army():
		food += int(Content.UNITS[u.kind].food)
		strength += Content.strength(Content.unit_stats(u))
	var fed := minf(1.0, (float(h.income_biomass()) + 1.0) / maxf(1.0, float(food)))
	s += strength * (0.4 + 0.6 * fed) * 1.5
	s += 10.0 * h.income_gold() + 5.0 * h.income_biomass() + 4.0 * h.income_genes()
	s += 0.5 * h.biomass + 1.0 * h.genes + 3.0 * h.alien + 2.0 * h.gold + 4.0 * h.interest()
	s += 5.0 * h.block() + 0.5 * h.hp_max()
	return s


static func _battle(run: Run, h: Home) -> Dictionary:
	var f := Fight.make(h.army(), run.wave(), run.power())
	f.run()
	return {"won": f.result == "won", "left": f.alive("ours").size(), "harm": maxi(0, f.harm() - h.block())}