class_name Run
extends RefCounted
## A run (GAME-DESIGN 15): one homeland carried through the levels, each level a number of rounds -- buy and build,
## then this round's army fights a wave -- and a fossil relic chosen when a level is held. Over when the homeland's
## hit points are gone.

const LOOT := 1                   # a battle won: this many potions and alien genes; a big round's or a boss's, double
const GIFTS := 3                  # gifts kept on the shelf at most

## The run being played: kept here while the scene is reloaded.
static var current: Run

var level := 0
var round := 1
var home: Home
var rng := RandomNumberGenerator.new()
var over := false
var calm := false                 # no one comes (tools/sim_runs.gd measuring how strong a homeland can grow)


func _init(seed := 0) -> void:
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	home = Home.new(rng)


func rounds() -> int:
	return int(Content.LEVELS[level].rounds)


func power() -> float:
	return float(Content.LEVELS[level].power)


## Who comes this round (or `ahead` rounds on).
func wave(ahead := 0) -> Array:
	return [] if calm else Content.wave(level, round + ahead)


func big(ahead := 0) -> bool:
	return round + ahead in Content.BIG_ROUNDS


func start_round() -> Array:
	return home.start_round(rng, level)


func reroll() -> bool:
	return home.reroll(rng, level)


## The army goes out (its biomass paid) against this round's wave.
func fight() -> Fight:
	return Fight.make(home.produce(), home.buffs, wave(), power())


## The strength of the army the homeland would send now (Content.strength), with this round's buffs.
func strength() -> float:
	var n := 0.0
	for u in home.army():
		n += Content.strength(Content.unit_stats(u, home.buffs))
	return n


## After the battle: this round's buffs spent; won, gold, potions and alien genes found; lost, the homeland harmed;
## either way the interest on the gold kept. {result, fallen, took, loot: [potion ids], alien, gold, interest,
## level_won}
func finish(f: Fight) -> Dictionary:
	home.buffs.clear()
	var out := {"result": f.result, "fallen": f.fallen(), "took": 0, "loot": [], "alien": 0, "gold": 0, "interest": 0,
		"level_won": false}
	if f.result == "won":
		var n := LOOT * (2 if big() or round >= rounds() else 1)
		home.alien += n
		out.alien = n
		for i in n:
			var k := home._any_potion(rng)
			if home.add_potion(k):
				out.loot.append(k)
		home.gold += Content.WIN_GOLD
		out.gold = Content.WIN_GOLD
	else:
		out.took = home.harmed(f.harm())
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
	return level >= Content.LEVELS.size() - 1


## On to the next level: a row more of land.
func next_level() -> void:
	level += 1
	round = 1
	home.open_row()


## Three offers to choose one of, free, after each round: from what the shop could sell now that is of use, the rarer
## more often than on the shelf.
func gift_offer() -> Array:
	var pool: Array = []
	for id in Content.OFFERS:
		var o: Dictionary = Content.OFFERS[id]
		if int(o.get("from", 0)) > level or not home._useful(id):
			continue
		for k in [3, 3, 2][int(o.rarity)]:
			pool.append(id)
	Home.shuffle(pool, rng)
	var out: Array = []
	var ids: Array = []
	for id in pool:
		if id in ids:
			continue
		ids.append(id)
		out.append({"id": id, "potion": home._any_potion(rng), "gift": true} if id == "potion" else {"id": id, "gift": true})
		if out.size() == 3:
			break
	return out


## A gift taken: to the front of the shelf (no more than GIFTS kept; the oldest goes).
func take_gift(oi: Dictionary) -> void:
	var g := oi.duplicate()
	g.gift = true
	home.shelf.insert(0, g)
	var gifts := home.shelf.filter(func(o: Variant) -> bool: return o != null and o.get("gift", false))
	if gifts.size() > GIFTS:
		home.shelf.erase(gifts[-1])


## Three different relics not yet held, to choose one of.
func relic_offer() -> Array:
	var pool: Array = Content.RELICS.keys().filter(func(id: String) -> bool: return not id in home.relics)
	Home.shuffle(pool, rng)
	return pool.slice(0, 3)


func take_relic(id: String) -> void:
	if not id in home.relics:
		home.relics.append(id)
