class_name Policy
## How the tools play (GAME-DESIGN 17-19), shared by playtest.gd and sim_runs.gd. Not part of the game.
##
## random: buys anything it can afford, put anywhere it may go (but building only on empty land, pulling nothing
## down), raising nests either way, and puts down what it keeps the same way; builds a wonder when it can. smart: the
## play that does the most good for its price -- a buy (a nest's raise tried both ways), putting down what was kept,
## the wonder -- this round's battle worked out after it (the forecast the player sees), and what the homeland comes
## to: the army its nests make (as far as the biomass coming in feeds it), what comes in each round, what is kept (gold
## earns interest); restocks the shelf when nothing on it is worth buying; the gift and the relic that do the most
## good. A smart one may keep to a school (Content.SCHOOLS): it leans to that school's goods, never builds another
## school's own buildings (those that are not just for biomass, genes or gold) and takes one of them out of the shop
## each round, and -- for gold -- saves. All carry on what the packing screen picks to begin with
## (Run.default_goods).

const LEAN := 1.6                 # a school's own goods look this much better to one keeping to it...
const SHUN := 0.8                 # ...and another school's this much worse
const COMMIT := 30.0              # each level of its school's own buildings, up to COMMIT_UPTO, is worth this to it
const COMMIT_UPTO := 4            # (what a school's own buildings do may only show later: more slots, cheaper affixes)
const HOPE := 25.0                # to the genes school, a nest halfway to a new species, with room for the other half


## A random play: ["buy" or "place", index, target, choice], ["wonder", id], or [] when there is none.
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
	for id in h.wonders:
		if h.can_build_wonder(id):
			can.append(["wonder", id, []])
	if can.is_empty():
		return []
	var c: Array = can[rng.randi() % can.size()]
	if c[0] == "wonder":
		return ["wonder", c[1]]
	return [c[0], c[1], c[2][rng.randi() % c[2].size()], "elite" if rng.randf() < 0.5 else "count"]


static func _careless(h: Home, fits: Array, oi: Variant) -> Array:
	if not fits.is_empty() and Content.offer(oi).type == "build":
		return fits.filter(func(p: Vector2i) -> bool: return not h.buildings.has(p))
	return fits


## Does a play (any_play's, best_play's) to `h`. Its events.
static func play(h: Home, p: Array) -> Array:
	match p[0]:
		"buy":
			return h.buy(p[1], p[2], p[3] if p.size() > 3 else "count")
		"place":
			return h.place(p[1], p[2], p[3] if p.size() > 3 else "count")
		"wonder":
			return h.build_wonder(p[1])
	return []


## Which school a good is for: its building's -- a nest's none, its gift fitting several (GAME-DESIGN 20); an affix's
## genes; a raise's by its choice.
static func school_of(oi: Dictionary, choice := "count") -> String:
	var o := Content.offer(oi)
	match o.type:
		"build":
			return str(Content.BUILDINGS[o.builds].get("school", ""))
		"affix":
			return "genes"
		"raise":
			return "elite" if choice == "elite" else "horde"
	return ""


static func _lean(oi: Dictionary, choice: String, school: String) -> float:
	if school == "":
		return 1.0
	if school_of(oi, choice) == school:
		return LEAN
	return 0.0 if _others(oi, school) else SHUN


## Is it another school's own building?
static func _others(oi: Variant, school: String) -> bool:
	var o := Content.offer(oi)
	return o.type == "build" and _own(o.builds) != "" and _own(o.builds) != school


## The school a kind of building is the own building of -- what that school comes to, not what everyone needs (biomass,
## genes, gold) -- or "".
static func _own(kind: String) -> String:
	var b: Dictionary = Content.BUILDINGS[kind]
	if not b.has("school"):
		return ""
	var first: Dictionary = b.levels[0]
	return "" if first.has("biomass") or first.has("genes") or first.has("gold") else str(b.school)


## The choices a good on `at` can be put down with: both for a nest's raise.
static func _choices(h: Home, oi: Dictionary, at: Variant) -> Array:
	if Content.offer(oi).type == "raise" and at is Vector2i and h.buildings.has(at) and Content.is_nest(h.buildings[at].kind):
		return ["count", "elite"]
	return ["count"]


## The best play for its price -- a buy, putting down what was kept (paid for already), the wonder: ["buy" or "place",
## index, target, choice] or ["wonder", id], or [] when nothing beats keeping the gold.
static func best_play(run: Run, h: Home, school := "") -> Array:
	var base := score(run, h, school)
	var best_gain := 0.01
	var best: Array = []
	for i in h.shelf.size():
		for at in h.targets(i):
			var o := Content.offer(h.shelf[i])
			var cost := maxf(1.0, float(h.price(i, at)) + 0.5 * float(h.genes_cost(o)) + 2.0 * float(o.get("alien", 0)))
			for choice in _choices(h, h.shelf[i], at):
				var t := h.clone()
				t.buy(i, at, choice)
				var gain := (score(run, t, school) - base) / cost * _lean(h.shelf[i], choice, school)
				if gain > best_gain:
					best_gain = gain
					best = ["buy", i, at, choice]
	for k in h.stash.size():
		for at in h.stash_targets(k):
			for choice in _choices(h, h.stash[k], at):
				var t := h.clone()
				t.place(k, at, choice)
				var gain := (score(run, t, school) - base) * _lean(h.stash[k], choice, school)
				if gain > best_gain:
					best_gain = gain
					best = ["place", k, at, choice]
	for id in h.wonders:
		if h.can_build_wonder(id):
			var t := h.clone()
			t.build_wonder(id)
			var gain := (score(run, t, school) - base) / float(Content.WONDERS[id].price) * (LEAN if school == "gold" else 1.0)
			if gain > best_gain:
				best_gain = gain
				best = ["wonder", id]
	return best


## The kind a player keeping to `school` takes out of the shop this round: the first of another school's own
## buildings left on the shelf (-1 for none, or with no school).
static func best_removal(h: Home, school: String) -> int:
	if school == "" or h.removes <= 0:
		return -1
	for i in h.shelf.size():
		if h.shelf[i] != null and _others(h.shelf[i], school):
			return i
	return -1


## The gift that does the most good where it goes best: its index in `gifts`.
static func best_gift(run: Run, h: Home, gifts: Array) -> int:
	var best := 0
	var best_score := -INF
	for k in gifts.size():
		var t := h.clone()
		t.stash.append(gifts[k].duplicate())
		var last := t.stash.size() - 1
		for at in t.stash_targets(last):
			for choice in _choices(t, t.stash[last], at):
				var u := t.clone()
				u.place(last, at, choice)
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


## How good a homeland looks: this round's battle (and what scavengers bring back); the army its nests can make, as far
## as what comes in feeds it; what comes in and what is kept -- for the gold school, saving and the most interest count
## more; for any school, its own buildings (up to a few levels of them); for the genes school, nests halfway to a new
## species.
static func score(run: Run, h: Home, school := "") -> float:
	var b := _battle(run, h)
	var s := (300.0 + float(b.left) * 5.0 if b.won else -float(b.harm) * 12.0) + 10.0 * float(b.loot)
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
	s += 0.5 * h.biomass + 1.0 * h.genes + 3.0 * h.alien + 2.0 * h.gold + 4.0 * h.interest() + 0.5 * h.hp_max()
	if school == "gold":
		s += 3.0 * h.interest_max() + 2.0 * h.gold
	if school != "":
		var own := 0
		for p in h.buildings:
			if _own(h.buildings[p].kind) == school:
				own += int(h.buildings[p].level)
		s += COMMIT * mini(own, COMMIT_UPTO)
	if school == "genes":
		s += HOPE * _halfway(h)
	return s


## How many nests carry one affix of a recipe (Content.RECIPES) and have room for the other.
static func _halfway(h: Home) -> int:
	var n := 0
	for p in h.buildings:
		var b: Dictionary = h.buildings[p]
		if Content.is_nest(b.kind) and b.affixes.size() < h.slots(p) and not Content.could_become(b.affixes).is_empty():
			n += 1
	return n


static func _battle(run: Run, h: Home) -> Dictionary:
	var f := Fight.make(h.army(), run.wave(), run.power())
	f.run()
	return {"won": f.result == "won", "left": f.alive("ours").size(), "harm": maxi(0, f.harm()), "loot": f.scavenged()}
