class_name Run
extends RefCounted
## A run (GAME-DESIGN 17): the gene ark, its homeland and what it carries, through the places it lands in -- each a
## big level of a few rounds (buy and build, then this round's army fights a wave), the last against the place's boss.
## A place held: a relic chosen, then the ark moves on, taking its gold and what it can carry. Over when the homeland's
## hit points are gone.

const LOOT := 1                   # a battle won: this many research points; a big round's (the bosses') double

## The run being played: kept here while the scene is reloaded.
static var current: Run

var level := 0                    # which of the run's big levels this is (0 to Content.TIERS - 1): how strong they come
var place := 0                    # where the ark is (Content.LEVELS)
var map: Array = []               # the places on offer for each level: [[0], [a, b], [c, d]]
var path: Array = [0]             # the places come to, level by level
var round := 1
var home: Home
var ark := ""                     # the ark chosen at the start (Content.ARKS), "" until then
var rng := RandomNumberGenerator.new()
var over := false
var calm := false                 # no one comes (tools/sim_runs.gd measuring how strong a homeland can grow)


func _init(seed := 0) -> void:
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	home = Home.new(rng)
	var ids: Array = Content.WONDERS.keys()
	Home.shuffle(ids, rng)
	home.wonders = ids.slice(0, Content.WONDERS_OFFERED)
	# The map: the rainforest first, then two places to pick from for each level after it, none twice.
	var others: Array = range(1, Content.LEVELS.size())
	Home.shuffle(others, rng)
	map = [[0]]
	for t in range(1, Content.TIERS):
		map.append(others.slice((t - 1) * 2, (t - 1) * 2 + 2))


## The ark the run starts with: what it sets down in the first place, the gold and relic it brings.
func choose_ark(id: String) -> void:
	var a: Dictionary = Content.ARKS[id]
	ark = id
	home.land(0, rng, a.buildings)
	home.gold += int(a.gold)
	if not a.relic in home.relics:
		home.relics.append(a.relic)


func rounds() -> int:
	return Content.ROUNDS


func power() -> float:
	return float(Content.TIER_POWER[level])


## Who comes this round (or `ahead` rounds on).
func wave(ahead := 0) -> Array:
	return [] if calm else Content.wave(place, level, round + ahead)


## The places the map offers for the next level ([] after the last).
func next_places() -> Array:
	return map[level + 1] if level + 1 < map.size() else []


func big(ahead := 0) -> bool:
	return round + ahead in Content.BIG_ROUNDS


func start_round() -> Array:
	home.flood = home.rule() == "tide" and round % 2 == 0
	var ev := home.start_round(rng, level)
	if home.rule() == "tide" and round % 2 == 1:
		home.gold += Content.EBB_GOLD
		ev.append({"t": "ebb", "gold": Content.EBB_GOLD})
	return ev


func reroll() -> bool:
	return home.reroll(rng, level)


## The army goes out (its biomass paid) against this round's wave.
func fight() -> Fight:
	return Fight.make(home.produce(), wave(), power())


## The strength of the army the homeland would send now (Content.strength).
func strength() -> float:
	var n := 0.0
	for u in home.army():
		n += Content.strength(Content.unit_stats(u))
	return n


## After the battle: won, gold and research points found; lost, the homeland harmed; either way what the scavengers
## bring back, and the interest on the gold kept. {result, fallen, took, research, gold, scavenged, interest, level_won}
func finish(f: Fight) -> Dictionary:
	var out := {"result": f.result, "fallen": f.fallen(), "took": 0, "research": 0, "gold": 0, "scavenged": 0,
		"interest": 0, "level_won": false}
	if f.result == "won":
		var n := LOOT * (2 if big() or round >= rounds() else 1)
		out.research = n
		home.genes += int(out.research)
		home.gold += Content.WIN_GOLD
		out.gold = Content.WIN_GOLD
	else:
		out.took = home.harmed(f.harm())
	out.scavenged = f.scavenged()
	home.gold += int(out.scavenged)
	out.interest = home.interest()
	home.gold += int(out.interest)
	if home.hp <= 0:
		over = true
	elif round >= rounds():
		out.level_won = true
	else:
		round += 1
	return out


func last_level() -> bool:
	return level >= Content.TIERS - 1


## Cards to choose one of after each round, to add to the deck (Content.REWARDS of them; one fewer with the sac) -- or
## Content.REWARD_GOLD instead: different cards the shop could sell here, the uncommon and the rare about as often as
## the common (they come no other way).
func reward_offer() -> Array:
	var pool: Array = []
	for id in Content.OFFERS:
		var o: Dictionary = Content.OFFERS[id]
		if int(o.get("from", 0)) <= level and int(o.get("region", home.region)) == home.region:
			for k in [3, 3, 2][int(o.rarity)]:
				pool.append(id)
	Home.shuffle(pool, rng)
	var want := Content.REWARDS - (1 if "sac" in home.relics else 0)
	var out: Array = []
	var ids: Array = []
	for id in pool:
		if id in ids:
			continue
		ids.append(id)
		out.append({"id": id})
		if out.size() == want:
			break
	return out


## A card taken into the deck.
func take_reward(id: String) -> void:
	home.deck.append({"id": id, "plus": false})


## Gold taken instead of a card.
func take_reward_gold() -> void:
	home.gold += Content.REWARD_GOLD


## Whether the round just fought (finish has moved on from it) was against the place's mini-boss.
func was_mini() -> bool:
	return round - 1 in Content.MINI_ROUNDS


## Three different relics not yet held, to choose one of: two fossils and a boss's.
func relic_offer() -> Array:
	var fossils: Array = Content.RELICS.keys().filter(func(id: String) -> bool:
		return not id in home.relics and not Content.RELICS[id].get("boss", false))
	var bosses: Array = Content.RELICS.keys().filter(func(id: String) -> bool:
		return not id in home.relics and Content.RELICS[id].get("boss", false))
	Home.shuffle(fossils, rng)
	Home.shuffle(bosses, rng)
	return fossils.slice(0, 2) + bosses.slice(0, 1)


func take_relic(id: String) -> void:
	if not id in home.relics:
		home.relics.append(id)


## What the ark could carry on: each building packed (with its level and affixes; from: its plot), and what is in the
## stash now (kept: its place there).
func packable() -> Array:
	var out: Array = []
	for p in home._plots():
		var g := home.packed(p)
		if not g.is_empty():
			g.from = p
			out.append(g)
	for k in home.stash.size():
		var g: Dictionary = home.stash[k].duplicate(true)
		g.kept = k
		out.append(g)
	return out


## What the ark carries on unless the player says otherwise: the goods that cost the most (Content.worth), as many as
## the stash holds -- the stash's own first where they are worth the same -- but fed: while the nests taken would eat
## more than the pools taken make (food_of), the least worth nest is left for the pool that makes most.
func default_goods() -> Array:
	var goods := packable()
	goods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wa := Content.worth(a) + (0.01 if a.has("kept") else 0.0)
		var wb := Content.worth(b) + (0.01 if b.has("kept") else 0.0)
		return wa > wb)
	var pick := goods.slice(0, home.stash_size())
	var rest := goods.slice(home.stash_size())
	while true:
		var f := food_of(pick)
		if int(f[0]) <= int(f[1]):
			break
		var pool := -1
		for i in rest.size():
			if int(food_of_good(rest[i])[1]) > (int(food_of_good(rest[pool])[1]) if pool >= 0 else 0):
				pool = i
		var nest := -1
		for i in range(pick.size() - 1, -1, -1):
			if int(food_of_good(pick[i])[0]) > 0:
				nest = i
				break
		if pool < 0 or nest < 0:
			break
		pick[nest] = rest[pool]
		rest.remove_at(pool)
	return pick


## What a building of `kind` at `lv` (a nest with the choices `path`) with `affixes` eats and makes each round:
## [biomass its units eat, biomass it makes] -- before neighbours, ground and the place's rule.
static func food(kind: String, lv: int, path: Array, affixes: Array) -> Array:
	if Content.is_nest(kind):
		var n := 1 + path.count("count")
		return [n * int(Content.UNITS[Content.species(Content.BUILDINGS[kind].nest, affixes).kind].food), 0]
	return [0, int(Content.level(kind, lv).get("biomass", 0))]


static func food_of_good(g: Dictionary) -> Array:
	var o := Content.offer(g)
	return food(o.builds, int(o.get("level", 1)), o.get("path", []), o.get("affixes", [])) if o.type == "build" else [0, 0]


## What the homeland in the next place would eat and make each round, with `goods` put down and what the ark sets down
## of itself (Content.LANDING, its nests' levels each one more a round): [eat, make].
static func food_of(goods: Array) -> Array:
	var eat := 0
	var make := 0
	var all: Array = Content.LANDING.map(func(item: Array) -> Array:
		var path: Array = []
		for k in int(item[1]) - 1:
			path.append("count")
		return food(item[0], int(item[1]), path, []))
	for g in goods:
		all.append(food_of_good(g))
	for f in all:
		eat += int(f[0])
		make += int(f[1])
	return [eat, make]


## On to the next place, carrying `goods` (no more than the stash holds) and all the gold: the buildings left behind,
## the ark landing in the middle of new ground.
func move_on(goods: Array, to := -1) -> void:
	level += 1
	place = to if to >= 0 else int(map[level][0])
	path.append(place)
	round = 1
	var carried: Array = []
	for g in goods.slice(0, home.stash_size()):
		var c: Dictionary = g.duplicate(true)
		c.erase("from")
		c.erase("kept")
		carried.append(c)
	home.stash = carried
	home.land(place, rng, Content.LANDING)
