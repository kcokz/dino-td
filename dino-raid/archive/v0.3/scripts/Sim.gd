class_name Sim
## The rules of a battle, worked out exactly (GAME-DESIGN 9). Nothing here is random but the shuffle, and
## nothing waits on a clock: a card changes the state at once, and ending the turn runs everyone in a fixed
## order -- eggs hatch, frightened plant-eaters bolt, the dinosaurs do what their kind does (front ones
## first), the robots do what they were built to (nearest our end first), the buildings work, and the next
## wave comes out of the time machine. The same resolve() both plays the turn and shows it beforehand
## (preview, on a copy): what the player is shown is what will happen.
##
## Events, the record of a turn for the battle to show, each a Dictionary with "t":
##   move {id, path}     bite {id, target, dmg}     shoot {id, target, dmg} or {id, nest, dmg} or {id, building, dmg}
##   charge {id, path, hits: [{target, dmg, step}]}  die {id}   nest_hurt {id, dmg}   nest_lost {id}
##   building_lost {id}  hatch {nest, unit}  spawn {unit}  heal {id, amount}  won  lost

const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


# -- A battle begins, a turn begins -------------------------------------------------------------------------

static func new_battle(level: int, deck: Array, rng: RandomNumberGenerator) -> BattleState:
	var s := BattleState.new()
	s.level = level
	var lv: Dictionary = Rules.LEVELS[level]
	for p in lv.rocks:
		s.rocks[p] = true
	_add_robot(s, "machine", Rules.MACHINE_AT, int(lv.machine))
	for p in lv.turrets:
		_add_robot(s, "turret", p)
	lay(s, Rules.FIRST_NEST, {"id": "egg_coelophysis", "up": false})
	s.draw = deck.duplicate(true)
	shuffle(s.draw, rng)
	start_turn(s, rng)
	return s


## Energy, and a fresh hand of cards.
static func start_turn(s: BattleState, rng: RandomNumberGenerator) -> void:
	s.energy = mini(Rules.ENERGY_MAX, s.energy + Rules.ENERGY_TURN)
	for i in Rules.HAND:
		if s.draw.is_empty():
			if s.discard.is_empty():
				break
			s.draw = s.discard
			s.discard = []
			shuffle(s.draw, rng)
		s.hand.append(s.draw.pop_back())


static func shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = t


# -- Cards ---------------------------------------------------------------------------------------------------

## Every tile the card in hand[i] can be played on (none when there is not the energy for it).
static func targets(s: BattleState, i: int) -> Array:
	var out: Array = []
	var c := Rules.card(s.hand[i])
	if s.over or s.energy < int(c.cost):
		return out
	for y in Rules.ROWS:
		for x in Rules.COLS:
			if fits(s, c, Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


static func fits(s: BattleState, c: Dictionary, p: Vector2i) -> bool:
	if not inside(p):
		return false
	match c.type:
		"egg":
			if p.y >= Rules.NEST_ROWS:
				return false
			var n: Variant = nest_at(s, p)
			return n.eggs == 0 if n != null else empty(s, p)
		"building":
			return p.y < Rules.OUR_HALF and empty(s, p)
	if c.id == "quicken":
		var n: Variant = nest_at(s, p)
		return n != null and n.eggs > 0
	return true


## Plays hand[i] on tile p. Whether it could.
static func play(s: BattleState, i: int, p: Vector2i) -> bool:
	if i < 0 or i >= s.hand.size():
		return false
	var ci: Dictionary = s.hand[i]
	var c := Rules.card(ci)
	if s.over or s.energy < int(c.cost) or not fits(s, c, p):
		return false
	s.energy -= int(c.cost)
	s.hand.remove_at(i)
	s.discard.append(ci)
	match c.type:
		"egg":
			lay(s, p, ci)
		"building":
			s.buildings.append({"id": _id(s), "pos": p, "kind": c.id, "up": ci.get("up", false), "hp": Rules.BUILDING_HP})
		_:
			match c.id:
				"scent":
					s.scents.append({"pos": p, "turns": int(c.turns)})
				"noise":
					s.noises.append({"pos": p, "reach": int(c.reach)})
				"blood":
					for u in s.units:
						if u.side == "dino" and _diet(u) == "meat" and dist(u.pos, p) <= int(c.reach):
							u.frenzy = maxi(int(u.frenzy), int(c.turns))
				"call":
					s.calls.append({"pos": p, "reach": int(c.reach)})
				"ash":
					s.ashes.append({"pos": p, "turns": int(c.turns)})
				"quicken":
					var n: Dictionary = nest_at(s, p)
					n.progress = int(n.progress) + int(c.speed)
	return true


## A clutch in tile p: a new nest, or the empty one there.
static func lay(s: BattleState, p: Vector2i, ci: Dictionary) -> void:
	var c := Rules.card(ci)
	var n: Variant = nest_at(s, p)
	if n == null:
		n = {"id": _id(s), "pos": p, "hp": Rules.NEST_HP}
		s.nests.append(n)
	n.species = c.species
	n.pack = int(c.pack)
	n.eggs = int(c.eggs)
	n.hatch = int(c.hatch)
	n.needs = c.needs.duplicate()
	n.progress = 0
	n.card = ci.duplicate()
	n.lead = 0


## Turns the next egg of nest n takes, from what is round it now: twice as long for each building it needs
## and has not beside it; sooner by a compost heap's warmth.
static func hatch_time(s: BattleState, n: Dictionary) -> int:
	var t: int = n.hatch
	for need in n.needs:
		if need != "quiet" and not beside(s, n.pos, need):
			t *= 2
	var warm := 0
	for b in s.buildings:
		if b.kind == "compost" and dist(b.pos, n.pos) == 1:
			warm = maxi(warm, int(Rules.card({"id": "compost", "up": b.up}).warm))
	return maxi(1, t - warm)


## Turns until nest n's next egg hatches (0: at the end of this turn).
static func turns_left(s: BattleState, n: Dictionary) -> int:
	return maxi(0, hatch_time(s, n) - int(n.progress) - 1)


## Whether a tyrannosaur's eggs keep still: a robot too near, and they want quiet.
static func paused(s: BattleState, n: Dictionary) -> bool:
	if not "quiet" in n.needs:
		return false
	for u in s.units:
		if u.side == "robot" and dist(u.pos, n.pos) <= Rules.QUIET:
			return true
	return false


# -- The turn ------------------------------------------------------------------------------------------------

## The player ends the turn: the hand goes to the discard pile and the turn is played out.
static func end_turn(s: BattleState) -> Array:
	s.discard.append_array(s.hand)
	s.hand.clear()
	return resolve(s)


## What ending the turn now would do, worked out on a copy.
static func preview(s: BattleState) -> Array:
	return resolve(s.clone())


static func resolve(s: BattleState) -> Array:
	var ev: Array = []
	if s.over:
		return ev
	# Eggs hatch. The young do nothing this turn.
	var fresh := {}
	for n in s.nests.duplicate():
		if n.eggs <= 0:
			continue
		if not paused(s, n):
			n.progress = int(n.progress) + 1
		if int(n.progress) < hatch_time(s, n):
			continue
		var spot: Variant = _hatch_spot(s, n.pos)
		if spot == null:
			continue
		var lead: bool = n.lead == 0 or s.unit(int(n.lead)) == null
		var u := _add_dino(s, n.species, spot, int(n.pack), lead)
		if lead:
			n.lead = u.id
		n.eggs = int(n.eggs) - 1
		n.progress = 0
		fresh[u.id] = true
		ev.append({"t": "hatch", "nest": n.id, "unit": u.duplicate(true)})
	# A noise: the plant-eaters near it bolt away from it.
	var bolted := {}
	for noise in s.noises:
		for id in _order(s, "dino"):
			var u: Variant = s.unit(id)
			if u == null or fresh.has(id) or bolted.has(id) or _diet(u) != "plant":
				continue
			if dist(u.pos, noise.pos) <= int(noise.reach):
				bolted[id] = true
				_charge(s, u, _away(noise.pos, u.pos), Rules.STAMPEDE, ev)
				if s.over:
					return ev
	# The dinosaurs, front ones first.
	for id in _order(s, "dino"):
		var u: Variant = s.unit(id)
		if u == null or fresh.has(id) or bolted.has(id):
			continue
		_dino_act(s, u, ev)
		u.angry_at = 0
		if s.over:
			return ev
	# The robots, nearest our end first.
	for id in _order(s, "robot"):
		var r: Variant = s.unit(id)
		if r != null:
			_robot_act(s, r, ev)
			if s.over:
				return ev
	# The buildings work; what lasts a while runs down.
	for b in s.buildings:
		var heal := 0
		var diet := ""
		match b.kind:
			"ferns":
				heal = int(Rules.card({"id": "ferns", "up": b.up}).heal)
				diet = "plant"
			"carrion":
				heal = int(Rules.card({"id": "carrion", "up": b.up}).heal)
				diet = "meat"
		if heal > 0:
			for u in s.units:
				if u.side == "dino" and _diet(u) == diet and dist(u.pos, b.pos) == 1:
					var top: int = int(u.bodies) * int(u.body_hp) if u.pack else int(u.max)
					var gain := mini(heal, top - int(u.hp))
					if gain > 0:
						u.hp = int(u.hp) + gain
						ev.append({"t": "heal", "id": u.id, "amount": gain})
	for u in s.units:
		if u.side == "dino" and int(u.frenzy) > 0:
			u.frenzy = int(u.frenzy) - 1
	for list in [s.scents, s.ashes]:
		for e in list.duplicate():
			e.turns = int(e.turns) - 1
			if e.turns <= 0:
				list.erase(e)
	s.noises.clear()
	s.calls.clear()
	# The next wave comes out of the time machine.
	s.turn += 1
	for kind in (Rules.wave(s.level, s.turn) if s.waves else []):
		var p: Variant = _spawn_spot(s)
		if p == null:
			break
		var r := _add_robot(s, kind, p)
		ev.append({"t": "spawn", "unit": r.duplicate(true)})
	return ev


# -- What each kind does --------------------------------------------------------------------------------------

static func _dino_act(s: BattleState, u: Dictionary, ev: Array) -> void:
	var st: Dictionary = Rules.DINOS[u.kind]
	var wild := int(u.frenzy) > 0
	var move: int = int(st.move) + (2 if wild else 0)
	var sight: int = int(st.sight) + (2 if wild else 0)
	if st.diet == "meat":
		var foe: Variant = _nearest(s, u.pos, sight, func(o: Dictionary) -> bool: return o.side == "robot")
		if foe == null and st.get("apex", false) and not fed(s, u):
			foe = _nearest(s, u.pos, sight, func(o: Dictionary) -> bool:
				return o.side == "dino" and o.id != u.id and Rules.DINOS[o.kind].get("small", false))
		if foe != null:
			_close_and_bite(s, u, foe, move, ev)
			return
		var lure: Variant = _nearest_spot(u.pos, s.scents, Rules.SCENT_SMELL)
		if lure == null:
			lure = _nearest_spot(u.pos, s.noises, Rules.NOISE_HEARD)
		if lure != null:
			_walk_to(s, u, lure.pos, move, ev)
		return
	var call: Variant = null
	for c in s.calls:
		if dist(u.pos, c.pos) <= int(c.reach) and (call == null or dist(u.pos, c.pos) < dist(u.pos, call.pos)):
			call = c
	if call != null:
		_walk_to(s, u, call.pos, move, ev)
		return
	var foe: Variant = s.unit(int(u.angry_at)) if int(u.angry_at) != 0 else null
	if foe == null:
		foe = _nearest(s, u.pos, 1, func(o: Dictionary) -> bool: return o.side == "robot")
	if foe != null:
		_close_and_bite(s, u, foe, move, ev)


static func _robot_act(s: BattleState, r: Dictionary, ev: Array) -> void:
	var st: Dictionary = Rules.ROBOTS[r.kind]
	if int(st.shot) <= 0:
		return
	var reach := _reach(s, r)
	var is_dino := func(o: Dictionary) -> bool: return o.side == "dino"
	var aim: Variant = _nearest(s, r.pos, reach, is_dino)
	if aim == null and int(st.move) > 0:
		# Off towards the nearest nest it can get to -- or, walled out of every one, the nearest building.
		var goal: Array = s.nests
		var path := _route(s, r.pos, func(q: Vector2i) -> bool: return _near(q, s.nests, 1))
		if path.is_empty() and not _near(r.pos, s.nests, 1):
			goal = s.buildings
			path = _route(s, r.pos, func(q: Vector2i) -> bool: return _near(q, s.buildings, 1))
		var walked: Array = []
		for q in path:
			if walked.size() >= int(st.move) or _near(r.pos, goal, reach):
				break
			walked.append(q)
			r.pos = q
			reach = _reach(s, r)
			if _nearest(s, r.pos, reach, is_dino) != null:
				break
		if not walked.is_empty():
			ev.append({"t": "move", "id": r.id, "path": walked})
		aim = _nearest(s, r.pos, reach, is_dino)
	var dmg: int = st.shot
	if aim != null:
		ev.append({"t": "shoot", "id": r.id, "target": aim.id, "dmg": dmg})
		_hurt(s, aim, dmg, ev, r.id)
		return
	if int(st.move) <= 0:
		return
	var n: Variant = _nearest_of(r.pos, s.nests)
	if n != null and dist(r.pos, n.pos) <= reach:
		ev.append({"t": "shoot", "id": r.id, "nest": n.id, "dmg": dmg})
		n.hp = int(n.hp) - dmg
		ev.append({"t": "nest_hurt", "id": n.id, "dmg": dmg})
		if int(n.hp) <= 0:
			s.nests.erase(n)
			ev.append({"t": "nest_lost", "id": n.id})
			if s.nests.is_empty():
				s.over = true
				ev.append({"t": "lost"})
		return
	var b: Variant = _nearest_of(r.pos, s.buildings)
	if b != null and dist(r.pos, b.pos) <= reach and not _can_reach_nest(s, r):
		ev.append({"t": "shoot", "id": r.id, "building": b.id, "dmg": dmg})
		b.hp = int(b.hp) - dmg
		if int(b.hp) <= 0:
			s.buildings.erase(b)
			ev.append({"t": "building_lost", "id": b.id})


static func _can_reach_nest(s: BattleState, r: Dictionary) -> bool:
	return _near(r.pos, s.nests, 1) or not _route(s, r.pos, func(q: Vector2i) -> bool: return _near(q, s.nests, 1)).is_empty()


## Whether any of `things` is within `d` steps of p.
static func _near(p: Vector2i, things: Array, d: int) -> bool:
	for t in things:
		if dist(p, t.pos) <= d:
			return true
	return false


## A robot in volcanic ash can only shoot what is beside it.
static func _reach(s: BattleState, r: Dictionary) -> int:
	for a in s.ashes:
		if dist(a.pos, r.pos) <= 1:
			return 1
	return int(Rules.ROBOTS[r.kind].range)


## Up to `move` steps towards `foe`, then a bite if it is beside it.
static func _close_and_bite(s: BattleState, u: Dictionary, foe: Dictionary, move: int, ev: Array) -> void:
	if dist(u.pos, foe.pos) > 1:
		var at: Vector2i = foe.pos
		var path := _route(s, u.pos, func(q: Vector2i) -> bool: return dist(q, at) <= 1)
		if path.size() > move:
			path = path.slice(0, move)
		if not path.is_empty():
			u.pos = path[-1]
			ev.append({"t": "move", "id": u.id, "path": path})
	if dist(u.pos, foe.pos) <= 1:
		var dmg: int = int(Rules.DINOS[u.kind].bite) * int(u.bodies) * (2 if int(u.frenzy) > 0 else 1)
		ev.append({"t": "bite", "id": u.id, "target": foe.id, "dmg": dmg})
		_hurt(s, foe, dmg, ev, u.id)


## Up to `move` steps towards tile `to` -- onto it, or beside it when it is taken.
static func _walk_to(s: BattleState, u: Dictionary, to: Vector2i, move: int, ev: Array) -> void:
	if u.pos == to:
		return
	var path := _route(s, u.pos, func(q: Vector2i) -> bool: return q == to)
	if path.is_empty():
		path = _route(s, u.pos, func(q: Vector2i) -> bool: return dist(q, to) <= 1)
	if path.size() > move:
		path = path.slice(0, move)
	if not path.is_empty():
		u.pos = path[-1]
		ev.append({"t": "move", "id": u.id, "path": path})


## A plant-eater bolting `steps` tiles in `dir`, running down whatever is in its way: what the trample kills,
## it runs on over; what it does not, stops it.
static func _charge(s: BattleState, u: Dictionary, dir: Vector2i, steps: int, ev: Array) -> void:
	var path: Array = []
	var hits: Array = []
	var after: Array = []
	var p: Vector2i = u.pos
	for i in steps:
		var q := p + dir
		if not inside(q) or s.rocks.has(q) or nest_at(s, q) != null or building_at(s, q) != null:
			break
		var o: Variant = unit_at(s, q)
		if o != null:
			hits.append({"target": o.id, "dmg": Rules.TRAMPLE, "step": path.size()})
			_hurt(s, o, Rules.TRAMPLE, after, u.id)
			if s.unit(int(o.id)) != null:
				break
		p = q
		path.append(p)
	u.pos = p
	ev.append({"t": "charge", "id": u.id, "path": path, "hits": hits})
	ev.append_array(after)


static func _hurt(s: BattleState, o: Dictionary, dmg: int, ev: Array, from: int) -> void:
	o.hp = int(o.hp) - dmg
	if o.side == "dino":
		if o.pack:
			o.bodies = maxi(0, ceili(float(o.hp) / float(o.body_hp)))
		var by: Variant = s.unit(from)
		if by != null and by.side == "robot" and _diet(o) == "plant":
			o.angry_at = from
	if int(o.hp) <= 0:
		s.units.erase(o)
		ev.append({"t": "die", "id": o.id})
		if o.kind == "machine":
			s.over = true
			s.won = true
			ev.append({"t": "won"})


# -- Where things are --------------------------------------------------------------------------------------

static func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < Rules.COLS and p.y >= 0 and p.y < Rules.ROWS


## Steps between two tiles, a diagonal step counting one.
static func dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func unit_at(s: BattleState, p: Vector2i) -> Variant:
	for u in s.units:
		if u.pos == p:
			return u
	return null


static func nest_at(s: BattleState, p: Vector2i) -> Variant:
	for n in s.nests:
		if n.pos == p:
			return n
	return null


static func building_at(s: BattleState, p: Vector2i) -> Variant:
	for b in s.buildings:
		if b.pos == p:
			return b
	return null


## Nothing standing in it: no rock, unit, nest or building.
static func empty(s: BattleState, p: Vector2i) -> bool:
	return inside(p) and not s.rocks.has(p) and unit_at(s, p) == null and nest_at(s, p) == null \
		and building_at(s, p) == null


## Whether a building of `kind` stands beside tile p.
static func beside(s: BattleState, p: Vector2i, kind: String) -> bool:
	for b in s.buildings:
		if b.kind == kind and dist(b.pos, p) == 1:
			return true
	return false


## A tyrannosaur near a carrion pit is fed.
static func fed(s: BattleState, u: Dictionary) -> bool:
	for b in s.buildings:
		if b.kind == "carrion" and dist(b.pos, u.pos) <= Rules.FED:
			return true
	return false


## The way from `from` to the nearest tile `goal` accepts, through empty tiles, not counting `from`; [] when
## there is none, or `from` is one already.
static func _route(s: BattleState, from: Vector2i, goal: Callable) -> Array:
	if goal.call(from):
		return []
	var prev := {from: from}
	var queue: Array = [from]
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var q: Vector2i = p + d
			if prev.has(q) or not empty(s, q):
				continue
			prev[q] = p
			if goal.call(q):
				var path: Array = [q]
				while prev[path[0]] != from:
					path.push_front(prev[path[0]])
				return path
			queue.append(q)
	return []


## The nearest unit within `reach` that `which` accepts: nearest, then weakest, then nearest our end, then
## leftmost -- so there is never a doubt which.
static func _nearest(s: BattleState, at: Vector2i, reach: int, which: Callable) -> Variant:
	var best: Variant = null
	for o in s.units:
		if not which.call(o) or o.pos == at:
			continue
		var d := dist(at, o.pos)
		if d > reach:
			continue
		if best == null or _before(d, o, dist(at, best.pos), best):
			best = o
	return best


static func _before(d: int, o: Dictionary, bd: int, b: Dictionary) -> bool:
	if d != bd:
		return d < bd
	if int(o.hp) != int(b.hp):
		return int(o.hp) < int(b.hp)
	if o.pos.y != b.pos.y:
		return o.pos.y < b.pos.y
	return o.pos.x < b.pos.x


static func _nearest_of(at: Vector2i, things: Array) -> Variant:
	var best: Variant = null
	for t in things:
		if best == null or dist(at, t.pos) < dist(at, best.pos) \
				or dist(at, t.pos) == dist(at, best.pos) and t.id < best.id:
			best = t
	return best


static func _nearest_spot(at: Vector2i, spots: Array, reach: int) -> Variant:
	var best: Variant = null
	for e in spots:
		if dist(at, e.pos) <= reach and (best == null or dist(at, e.pos) < dist(at, best.pos)):
			best = e
	return best


## Ids of one side in the order they act: dinosaurs front first, robots nearest our end first.
static func _order(s: BattleState, side: String) -> Array:
	var list: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == side)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.pos.y != b.pos.y:
			return a.pos.y > b.pos.y if side == "dino" else a.pos.y < b.pos.y
		return a.pos.x < b.pos.x)
	return list.map(func(u: Dictionary) -> int: return u.id)


## The step pointing from `from` towards `to` (straight ahead, away from our end, when they are the same).
static func _away(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	return d if d != Vector2i.ZERO else Vector2i(0, 1)


## Where a hatchling comes out: the empty tile beside the nest nearest the enemy, then the middle.
static func _hatch_spot(s: BattleState, at: Vector2i) -> Variant:
	var best: Variant = null
	for d in DIRS:
		var q: Vector2i = at + d
		if not empty(s, q):
			continue
		if best == null or q.y > best.y or q.y == best.y and absi(q.x - 2) < absi(best.x - 2):
			best = q
	return best


static func _spawn_spot(s: BattleState) -> Variant:
	for p in Rules.SPAWN:
		if empty(s, p):
			return p
	return null


static func _diet(u: Dictionary) -> String:
	return Rules.DINOS[u.kind].diet if u.side == "dino" else ""


# -- Making things ------------------------------------------------------------------------------------------

static func _id(s: BattleState) -> int:
	s.next_id += 1
	return s.next_id - 1


static func _add_dino(s: BattleState, kind: String, p: Vector2i, pack: int, lead: bool) -> Dictionary:
	var st: Dictionary = Rules.DINOS[kind]
	var hp: int = st.hp
	var whole: int = hp * pack if pack > 1 else (roundi(hp * Rules.LEAD_HP) if lead else hp)
	var u := {"id": _id(s), "side": "dino", "kind": kind, "pos": p, "hp": whole, "max": whole, "bodies": pack,
		"pack": pack > 1, "body_hp": hp, "frenzy": 0, "angry_at": 0, "lead": lead}
	s.units.append(u)
	return u


static func _add_robot(s: BattleState, kind: String, p: Vector2i, hp := 0) -> Dictionary:
	var h: int = hp if hp > 0 else int(Rules.ROBOTS[kind].hp)
	var r := {"id": _id(s), "side": "robot", "kind": kind, "pos": p, "hp": h, "max": h, "bodies": 1, "pack": false}
	s.units.append(r)
	return r
