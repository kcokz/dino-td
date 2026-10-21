class_name Run
extends RefCounted
## A run (GAME-DESIGN 17, 24, 26): the dinosaur park's homeland, through the places it goes to -- each a big level of
## a few rounds (Content.PHASES: the round's pay, buying and building, the making, the eating, the battle), the last
## against the place's boss. A place held, on to the next, where the homeland is made afresh carrying nothing. Over
## when the homeland's hit points are gone.

const LOOT := 1                   # a battle won: this many research points; a big round's (the bosses') double

## The run being played: kept here while the scene is reloaded.
static var current: Run

var level := 0                    # which of the run's big levels this is (0 to Content.TIERS - 1): how strong they come
var place := 0                    # where the ark is (Content.LEVELS)
var map: Array = []               # the places on offer for each level: [[0], [a, b], [c, d]]
var path: Array = [0]             # the places come to, level by level
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
	# The map: the rainforest first, then two places to pick from for each level after it, none twice.
	var others: Array = range(1, Content.LEVELS.size())
	Home.shuffle(others, rng)
	map = [[0]]
	for t in range(1, Content.TIERS):
		map.append(others.slice((t - 1) * 2, (t - 1) * 2 + 2))


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


## The start of the round (Home.start_round): the round's pay and the interest, the shelf stocked.
func start_round() -> Array:
	return home.start_round(rng, level)


## The making, the player done (Home.make): what comes in, the young hatched.
func make() -> Array:
	return home.make()


## The eating (Home.eat): the stars and the young fed, those fed to fight.
func eat() -> Array:
	return home.eat()


## The young fed go out against this round's wave.
func fight() -> Fight:
	return Fight.make(home.fighters, wave(), power())


## The strength of the young fed this round, to fight (Content.strength).
func strength() -> float:
	var n := 0.0
	for u in home.fighters:
		n += Content.strength(Content.unit_stats(u))
	return n


## After the battle, still its part of the round: won, gold and research points found (the bounty hunter's gold too),
## a mini-boss or boss beaten growing the stars that grow so; lost, the homeland harmed; either way what the
## scavengers bring back. {result, fallen, took, research, gold, scavenged, level_won}
func finish(f: Fight) -> Dictionary:
	var out := {"result": f.result, "fallen": f.fallen(), "took": 0, "research": 0, "gold": 0, "scavenged": 0,
		"level_won": false}
	if f.result == "won":
		var n := LOOT * (2 if big() or round >= rounds() else 1)
		out.research = n
		home.genes += int(out.research)
		out.gold = Content.WIN_GOLD + home._star("win_gold")
		home.gold += int(out.gold)
		if round in Content.MINI_ROUNDS or round >= rounds():
			home.boss_beaten()
	else:
		out.took = home.harmed(f.harm())
	out.scavenged = f.scavenged()
	home.gold += int(out.scavenged)
	if home.hp <= 0:
		over = true
	elif round >= rounds():
		out.level_won = true
	else:
		round += 1
	return out


func last_level() -> bool:
	return level >= Content.TIERS - 1


## Blueprints to choose one of after each round (Content.REWARDS of them, as cards {id}) -- or Content.REWARD_GOLD
## instead (Home.plan_offer).
func reward_offer() -> Array:
	return home.plan_offer(rng, level, Content.REWARDS).map(func(id: String) -> Dictionary: return {"id": id})


## After a mini-boss: blueprints of the uncommon and the rare, to choose one of.
func rare_offer() -> Array:
	return home.plan_offer(rng, level, Content.REWARDS, true).map(func(id: String) -> Dictionary: return {"id": id})


## A blueprint chosen: had from now on, in this place.
func take_reward(id: String) -> void:
	home.unlock(id)


## Gold taken instead of a blueprint.
func take_reward_gold() -> void:
	home.gold += Content.REWARD_GOLD


## Whether the round just fought (finish has moved on from it) was against the place's mini-boss.
func was_mini() -> bool:
	return round - 1 in Content.MINI_ROUNDS


## On to place `to` (by default the map's first for the next level): the homeland made afresh there, carrying nothing
## (Home.fresh).
func move_on(to := -1) -> void:
	level += 1
	place = to if to >= 0 else int(map[level][0])
	path.append(place)
	round = 1
	home.fresh(place, rng)
