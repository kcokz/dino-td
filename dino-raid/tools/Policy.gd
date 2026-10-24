class_name Policy
## How the tools play (GAME-DESIGN 17-28), shared by playtest.gd and sim_runs.gd. Not part of the game.
##
## random: builds anything had that it can pay for, anywhere it may go (but only on empty land, pulling nothing down),
## raises buildings (a nest either way), buys the star on offer when it can.
## smart: the play that does the most good for its price -- a blueprint built, a building raised (a nest's both ways),
## the star on offer -- this round's battle worked out after it, and what the homeland comes to: the army its nests
## make (as far as the biomass coming in, less what the stars eat, feeds it), what comes in each round, what is kept
## (gold earns interest); a place's first nest, the one that does the most good built with the round's pay; each
## round, before building, the techs that would do the most good for their research points (GAME-DESIGN 29); the
## first place the map offers; when the battle would be lost, the nests moved to face the wave's lanes. A smart one may keep to a school (Content.SCHOOLS): it leans to that school's blueprints and raises,
## never builds another school's own buildings (those that are not just for biomass, research or gold), and -- for
## gold -- saves.

const LEAN := 1.6                 # a school's own goods look this much better to one keeping to it...
const SHUN := 0.8                 # ...and another school's this much worse
const COMMIT := 30.0              # each level of its school's own buildings, up to COMMIT_UPTO, is worth this to it
const COMMIT_UPTO := 4            # (what a school's own buildings do may only show later: more slots, cheaper affixes)
const HOPE := 25.0                # to the genes school, a nest halfway to a new species, with room for the other half
const ROOM := 4                   # population past what the nests use that still counts: room for the next
const RESEARCH_WORTH := 1.0       # the least good a tech must do for each research point it costs


## A random play: ["build", id, target], ["raise", target], ["star"], or [] when there is none.
static func any_play(h: Home, rng: RandomNumberGenerator) -> Array:
	var can: Array = []
	for id in h.plans:
		for at in _careless(h, h.targets(id), id):
			can.append(["build", id, at])
	for at in h.buildings:
		if h.can_raise(at):
			can.append(["raise", at])
	if h.can_buy_star():
		can.append(["star"])
	return can[rng.randi() % can.size()] if not can.is_empty() else []


static func _careless(h: Home, fits: Array, id: String) -> Array:
	if not fits.is_empty() and Content.OFFERS[id].type == "build":
		return fits.filter(func(p: Vector2i) -> bool: return not h.buildings.has(p))
	return fits


## Does a play (any_play's, best_play's) to `h`. Its events.
static func play(h: Home, p: Array) -> Array:
	match p[0]:
		"build":
			return h.build_plan(p[1], p[2])
		"raise":
			return h.raise(p[1])
		"move":
			return h.move_building(p[1], p[2])
		"star":
			return h.buy_star()
	return []


## Which school a blueprint is for: its building's -- a nest's none, its gift fitting several (GAME-DESIGN 20); an
## affix's genes.
static func school_of(id: String) -> String:
	var o: Dictionary = Content.OFFERS[id]
	return "genes" if o.type == "affix" else str(Content.BUILDINGS[o.builds].get("school", ""))


## How much better a play looks to one keeping to `school`, the play being for `of` (a school, "" for none).
static func _lean(of: String, school: String, other := false) -> float:
	if school == "":
		return 1.0
	if of == school:
		return LEAN
	return 0.0 if other else SHUN


## Is blueprint `id` another school's own building?
static func _others(id: String, school: String) -> bool:
	var o: Dictionary = Content.OFFERS[id]
	return o.type == "build" and _own(o.builds) != "" and _own(o.builds) != school


## The school a kind of building is the own building of -- what that school comes to, not what everyone needs (biomass,
## genes, gold) -- or "".
static func _own(kind: String) -> String:
	var b: Dictionary = Content.BUILDINGS[kind]
	if not b.has("school"):
		return ""
	var first: Dictionary = b.levels[0]
	return "" if first.has("biomass") or first.has("genes") or first.has("gold") else str(b.school)


## The best play for its price -- a blueprint built, a building raised, the star on offer: ["build", id, target],
## ["raise", target, choice] or ["star"], or [] when nothing beats keeping the gold. With no nest built yet, a nest
## first, wherever it does the most good: one nest may lose the battle all the same, so that no one battle shows
## what it is worth, and keeping the gold would look better (the interest) for ever.
static func best_play(run: Run, h: Home, school := "") -> Array:
	if not h.buildings.values().any(func(b: Dictionary) -> bool: return Content.is_nest(b.kind)):
		var top := -INF
		var first: Array = []
		for id in h.plans:
			var o: Dictionary = Content.OFFERS[id]
			if o.type != "build" or not Content.is_nest(o.builds):
				continue
			for at in h.targets(id):
				var t := h.clone()
				t.build_plan(id, at)
				var s := score(run, t, school)
				if s > top:
					top = s
					first = ["build", id, at]
		if not first.is_empty():
			return first
	var base := score(run, h, school)
	var best_gain := 0.01
	var best: Array = []
	for id in h.plans:
		var o := Content.offer({"id": id})
		var lean := _lean(school_of(id), school, _others(id, school))
		if lean <= 0.0:
			continue
		for at in h.targets(id):
			var t := h.clone()
			t.build_plan(id, at)
			var gain := (score(run, t, school) - base) / maxf(1.0, float(h.price_at(o, at))) * lean
			if gain > best_gain:
				best_gain = gain
				best = ["build", id, at]
	for at in h.buildings:
		if not h.can_raise(at):
			continue
		var t := h.clone()
		t.raise(at)
		var of := "elite" if Content.is_nest(h.buildings[at].kind) else str(Content.BUILDINGS[h.buildings[at].kind].get("school", ""))
		var gain := (score(run, t, school) - base) / float(h.raise_price(at)) * _lean(of, school)
		if gain > best_gain:
			best_gain = gain
			best = ["raise", at]
	if h.can_buy_star():
		var t := h.clone()
		t.buy_star()
		var gain := (score(run, t, school) - base) / float(Content.STARS[h.star_offer].price)
		if gain > best_gain:
			best_gain = gain
			best = ["star"]
	return best


## A place's first nest (`cards`: {id} each): the one that does the most good built with the round's pay, where it
## fits best, whatever the school (the gold school would take the cheapest) -- its index in `cards`.
static func best_first(run: Run, h: Home, cards: Array, _school := "") -> int:
	var best := 0
	var best_score := -INF
	for k in cards.size():
		var id: String = cards[k].id
		var u := h.clone()
		u.unlock(id)
		u.gold += Home.INCOME
		for at in u.targets(id):
			var v := u.clone()
			v.build_plan(id, at)
			var s := score(run, v)
			if s > best_score:
				best_score = s
				best = k
	return best


## The tech to research now (Home.research): of those open that there are research points for, the one that would do
## the most good built now (gold aside; a few places tried), for its research points, leaning to the school -- "" when
## none would do enough good for them. Weighed without this round's battle (score's `fought` false): it is asked of
## every open tech at every place it could go, each round, and a battle worked out each time made the runs too slow.
## (What it opens further down its line is not counted: a school's own buildings count for themselves, score's
## COMMIT.)
static func best_research(run: Run, h: Home, school := "") -> String:
	var t := h.clone()
	t.gold += 30
	var base := score(run, t, school, false)
	var best := ""
	var best_gain := RESEARCH_WORTH
	for id in Content.OFFERS:
		if not h.can_research(id):
			continue
		var lean := _lean(school_of(id), school, _others(id, school))
		if lean <= 0.0:
			continue
		var u := t.clone()
		u.unlock(id)
		var top := 0.0
		for at in u.targets(id).slice(0, 8):
			var v := u.clone()
			v.build_plan(id, at)
			top = maxf(top, score(run, v, school, false) - base)
		var gain := top * lean / float(Home.tech_cost(id))
		if gain > best_gain:
			best_gain = gain
			best = id
	return best


## A tech at random of those there are research points for, or "".
static func any_research(h: Home, rng: RandomNumberGenerator) -> String:
	var can: Array = Content.OFFERS.keys().filter(func(id: String) -> bool: return h.can_research(id))
	return can[rng.randi() % can.size()] if not can.is_empty() else ""


## A nest moved to face the wave's lanes (Home.move_building; GAME-DESIGN 32): of each nest to each other plot of the
## battle line, the move after which this round's battle goes best -- ["move", from, to] -- or [] when none does
## better. Only when the battle would not be won as things stand, and never with no one coming.
static func best_move(run: Run, h: Home) -> Array:
	if run.calm:
		return []
	var b := _battle(run, h)
	if b.won:
		return []
	var best_s := _battle_worth(b)
	var best: Array = []
	for p in h.buildings:
		if not Content.is_nest(h.buildings[p].kind):
			continue
		for x in Home.COLS:
			for y in Content.FRONT_ROWS:
				var q := Vector2i(x, y)
				if q == p:
					continue
				var t := h.clone()
				if t.move_building(p, q).is_empty():
					continue
				var s := _battle_worth(_battle(run, t))
				if s > best_s + 0.01:
					best_s = s
					best = ["move", p, q]
	return best


## What a battle's end is worth (score's battle part).
static func _battle_worth(b: Dictionary) -> float:
	return 300.0 + float(b.left) * 5.0 if b.won else -float(b.harm) * 12.0


## The next place on the map: the first of the two (the map is shuffled already).
static func best_place(run: Run) -> int:
	return int(run.next_places()[0])


## How good a homeland looks: this round's battle (and what scavengers bring back; not when `fought` is false); the
## army its nests can make, as far
## as the population allows; a little room in the population; the gold and research points that come in and are kept
## -- for the gold school, saving and the most interest count more; for any school, its own buildings (up to a few
## levels of them; only with this round's battle won -- what they do shows later, and a homeland about to lose needs
## fighters first); for the genes school, nests halfway to a new species. The population is a bound, not something
## had (GAME-DESIGN 28): it counts as far as the nests can use it and a few more (ROOM) for what comes next -- more is
## worth nothing.
static func score(run: Run, h: Home, school := "", fought := true) -> float:
	var s := 0.0
	var losing := false
	if fought:
		var b := _battle(run, h)
		losing = not b.won
		s = (300.0 + float(b.left) * 5.0 if b.won else -float(b.harm) * 12.0) + 10.0 * float(b.loot)
	var full := h.clone()
	full.biomass = 999
	var food := 0
	var strength := 0.0
	for u in full.army():
		food += int(Content.UNITS[u.kind].food)
		strength += Content.strength(Content.unit_stats(u))
	var fed := minf(1.0, (float(h.income_biomass() - h.star_food()) + 1.0) / maxf(1.0, float(food)))
	s += strength * (0.4 + 0.6 * fed) * 1.5
	s += 10.0 * h.income_gold() + 5.0 * mini(h.income_biomass(), food + ROOM) + 4.0 * h.income_genes()
	s += 1.0 * h.genes + 2.0 * h.gold + 4.0 * h.interest() + 0.5 * h.hp_max() + 2.0 * mini(h.pop_room(), 4)
	if school == "gold":
		s += 3.0 * h.interest_max() + 2.0 * h.gold
	if school != "" and not losing:
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


## This round's battle as `h` would fight it. With no one coming (a calm run, measuring how strong a homeland grows)
## every scavenger would stand at its end: what they bring back is not counted then, or what is measured would be
## scavengers, not strength.
static func _battle(run: Run, h: Home) -> Dictionary:
	var f := Fight.make(h.settled().fighters, run.wave(), run.power(), run.wave_lanes())
	f.run()
	return {"won": f.result == "won", "left": f.alive("ours").size(), "harm": maxi(0, f.harm()),
		"loot": 0 if run.calm else f.scavenged()}
