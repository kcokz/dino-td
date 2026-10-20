class_name Run
extends RefCounted
## A run (GAME-DESIGN 14): one homeland carried through the levels, each level a number of rounds -- build up, then
## this round's army fights a wave -- and the deck growing between levels. Over when the homeland's hit points are
## gone.

const WEIGHT := [6, 3, 1]         # how often a common, uncommon and rare card is offered, one against another
const LOOT := 1                   # a battle won: this many potions and alien genes; a big round's or a boss's, double

## The run being played: kept here while the scene is reloaded.
static var current: Run

var level := 0
var round := 1
var home: Home
var rng := RandomNumberGenerator.new()
var over := false
var calm := false                 # no one comes (tools/sim_runs.gd measuring how strong a homeland can grow)
var shown := false                # the deck has been laid out at the start


func _init(seed := 0) -> void:
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	var deck: Array = []
	for id in Content.START_DECK:
		deck.append({"id": id, "up": false})
	home = Home.new(deck, rng)


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
	return home.start_round(rng)


## The army goes out (its biomass paid) against this round's wave.
func fight() -> Fight:
	return Fight.make(home.produce(), home.buffs, wave(), power())


## The strength of the army the homeland would send now (Content.strength), with this round's buffs.
func strength() -> float:
	var n := 0.0
	for u in home.army():
		n += Content.strength(Content.unit_stats(u, home.buffs))
	return n


## After the battle: this round's buffs spent; won, potions and alien genes found; lost, the homeland is harmed.
## {result, fallen, took, loot: [potion ids], alien, level_won}
func finish(f: Fight) -> Dictionary:
	home.buffs.clear()
	var out := {"result": f.result, "fallen": f.fallen(), "took": 0, "loot": [], "alien": 0, "level_won": false}
	if f.result == "won":
		var n := LOOT * (2 if big() or round >= rounds() else 1)
		home.alien += n
		out.alien = n
		for i in n:
			var kinds: Array = Content.POTIONS.keys()
			var k: String = kinds[rng.randi() % kinds.size()]
			if home.add_potion(k):
				out.loot.append(k)
	else:
		out.took = home.harmed(f.harm())
	if home.hp <= 0:
		over = true
	elif round >= rounds():
		out.level_won = true
	else:
		round += 1
	return out


func last_level() -> bool:
	return level >= Content.LEVELS.size() - 1


## On to the next level: a row more of land, the whole deck gathered and shuffled as at the start.
func next_level() -> void:
	level += 1
	round = 1
	home.open_row()
	home.draw = deck()
	home.hand = []
	home.discard = []
	Home.shuffle(home.draw, rng)


## Every card the player owns, wherever it is now.
func deck() -> Array:
	return home.draw + home.hand + home.discard


## A card won: shuffled in among those still to be drawn.
func take(id: String) -> void:
	home.draw.insert(rng.randi_range(0, home.draw.size()), {"id": id, "up": false})


## A card of the deck (one of deck()'s, itself) made its + kind.
func upgrade(ci: Dictionary) -> void:
	ci.up = true


## A card taken out of the deck, wherever it is -- never down to fewer than a hand.
func remove(ci: Dictionary) -> bool:
	if deck().size() <= Home.HAND:
		return false
	for pile in [home.draw, home.hand, home.discard]:
		if ci in pile:
			pile.erase(ci)
			return true
	return false


## Three different cards to choose one of, the rarer the seldomer -- only those this level has opened.
func offer() -> Array:
	var pool: Array = []
	for id in Content.CARDS:
		var c: Dictionary = Content.CARDS[id]
		if int(c.get("from", 0)) > level:
			continue
		for i in WEIGHT[int(c.rarity)]:
			pool.append(id)
	Home.shuffle(pool, rng)
	var out: Array = []
	for id in pool:
		if not id in out:
			out.append(id)
			if out.size() == 3:
				break
	return out
