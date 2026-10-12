class_name Run
extends RefCounted
## A run (GAME-DESIGN 12): one homeland carried through the levels, each level a number of rounds -- build up,
## then fight a wave -- and the deck growing between levels. Over when the homeland's hit points are gone.

const WEIGHT := [6, 3, 1]         # how often a common, uncommon and rare card is offered, one against another
## The fallen come home hurt but alive, as in an auto-battler: a battle lost costs the homeland, never the units.
## (false: the fallen are gone for good.)
const FALLEN_COME_BACK := true

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


## The strength of the homeland's units all told (Content.strength), without this battle's buffs.
func strength() -> float:
	var n := 0.0
	for u in home.units:
		n += Content.unit_strength("ours", u.kind, int(u.star), int(u.bonus_hp), int(u.bonus_atk))
	return n


func start_round() -> Array:
	return home.start_round(rng)


func fight() -> Fight:
	return Fight.make(home, wave(), power())


## After the battle: the battle's buffs spent; lost, the homeland is harmed (and the fallen gone, if they do
## not come back). {result, fallen, took, level_won}
func finish(f: Fight) -> Dictionary:
	var fallen := f.fallen()
	if not FALLEN_COME_BACK:
		home.units = home.units.filter(func(u: Dictionary) -> bool: return not int(u.id) in fallen)
	home.buffs.clear()
	var took := 0 if f.result == "won" else home.harmed(f.harm())
	var out := {"result": f.result, "fallen": fallen.size(), "took": took, "level_won": false}
	if home.hp <= 0:
		over = true
	elif round >= rounds():
		out.level_won = true
	else:
		round += 1
	return out


func last_level() -> bool:
	return level >= Content.LEVELS.size() - 1


## On to the next level: the whole deck gathered and shuffled, as at the start.
func next_level() -> void:
	level += 1
	round = 1
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


## Three different cards to choose one of, the rarer the seldomer.
func offer() -> Array:
	var pool: Array = []
	for id in Content.CARDS:
		for i in WEIGHT[int(Content.CARDS[id].rarity)]:
			pool.append(id)
	Home.shuffle(pool, rng)
	var out: Array = []
	for id in pool:
		if not id in out:
			out.append(id)
			if out.size() == 3:
				break
	return out
