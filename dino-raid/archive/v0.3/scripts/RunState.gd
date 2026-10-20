class_name RunState
extends RefCounted
## A run: the levels one after another, and the deck the player carries through them -- growing by a card
## after each level won, one card upgraded, maybe one taken out (GAME-DESIGN 9).

const WEIGHT := [6, 3, 1]        # how often a common, uncommon and rare card is offered, one against another

## The run being played: kept here while the battle scene is reloaded for the next level.
static var current: RunState

var deck: Array = []             # card instances {id, up}
var level := 0
var rng := RandomNumberGenerator.new()


func _init(seed := 0) -> void:
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	for id in Rules.START_DECK:
		deck.append({"id": id, "up": false})


## Three different cards to choose one of, the rarer the seldomer.
func offer() -> Array:
	var pool: Array = []
	for id in Rules.CARDS:
		for i in WEIGHT[int(Rules.CARDS[id].rarity)]:
			pool.append(id)
	Sim.shuffle(pool, rng)
	var out: Array = []
	for id in pool:
		if not id in out:
			out.append(id)
			if out.size() == 3:
				break
	return out


func last_level() -> bool:
	return level >= Rules.LEVELS.size() - 1
