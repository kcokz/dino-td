class_name Policy
## How the tools play (GAME-DESIGN 12), shared by playtest.gd and sim_runs.gd. Not part of the game.
##
## random: any card it can afford, on a target picked at random.
## smart: the play that does the most good for its cost -- this round's battle worked out after it (the forecast the
## player sees), and what the homeland comes to: nests, room when the yard is filling, income, units' stars.


## A random play: [hand index, target], or [] when none can be played.
static func any_play(h: Home, rng: RandomNumberGenerator) -> Array:
	var can: Array = []
	for i in h.hand.size():
		if not h.targets(i).is_empty():
			can.append(i)
	if can.is_empty():
		return []
	var i: int = can[rng.randi() % can.size()]
	var fits := h.targets(i)
	return [i, fits[rng.randi() % fits.size()]]


## The best play for its cost: [hand index, target], or [] when nothing beats keeping the energy.
static func best_play(run: Run, h: Home) -> Array:
	var base := score(run, h)
	var best_gain := 0.01
	var best: Array = []
	for i in h.hand.size():
		var cost := maxf(1.0, float(Content.card(h.hand[i]).cost))
		for at in h.targets(i):
			var c := h.clone()
			c.play(i, at)
			var gain := (score(run, c) - base) / cost
			if gain > best_gain:
				best_gain = gain
				best = [i, at]
	return best


static func score(run: Run, h: Home) -> float:
	var f := Fight.make(h, run.wave(), run.power())
	f.run()
	var s := 300.0 + float(f.alive("ours").size()) * 5.0 if f.result == "won" else -float(maxi(0, f.harm() - h.block())) * 12.0
	var crowded := h.units.size() >= h.room() - 1
	for p in h.buildings:
		var l := h.level_of(p)
		if l.has("makes"):
			s += (15.0 if crowded else 40.0) * float(l.count) / float(h.every(p)) * pow(3.0, int(l.get("star", 1)) - 1)
		s += 8.0 * float(l.get("income", 0)) + (24.0 if crowded else 5.0) * float(l.get("room", 0))
		s += 4.0 * float(l.get("block", 0)) + 6.0 * float(l.get("hurry", 0)) + 6.0 * float(l.get("drill", 0))
	for u in h.units:
		s += 10.0 * pow(3.0, int(u.star) - 1) + 1.5 * float(int(u.bonus_hp) + int(u.bonus_atk))
	s += float(h.energy) * 2.0
	return s
