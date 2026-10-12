class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 12): a grid of plots with buildings in them, the units they have made, the energy,
## the cards, and the homeland's own hit points. One round here: the producers make (start_round), the player
## plays cards -- builds, buffs, upgrades -- and what has been made goes out to fight (Fight). Who comes back
## stays; the battle-only buffs are spent.
##
## Plain data and rules, nothing on screen: the same rules for the game and for its tests.
##
## A building: {id, kind, level, wait}  -- wait: rounds until a producer next makes.
## A unit:     {id, kind, star, bonus_hp, bonus_atk}
## Events (what start_round and play did, for the screen): played {card}, made {unit, by}, merged {unit, from},
## full {by}, income {amount}, built {at}, raised {at}, starred {id}, trained {id}, mended {amount}.

const COLS := 6
const ROWS := 4
const ROOM := 5                   # units kept with no pens
const INCOME := 3
const ENERGY_MAX := 10
const HAND := 5
const HP := 30

var buildings := {}               # Vector2i -> building
var units: Array = []
var energy := 0
var hp := HP
var draw: Array = []              # card instances {id, up}; the top is the end
var hand: Array = []
var discard: Array = []
var buffs := {}                   # for the coming battle only: atk, armor, haste
var next_id := 1


func _init(deck: Array, rng: RandomNumberGenerator) -> void:
	draw = deck.duplicate(true)
	shuffle(draw, rng)
	build(Content.FIRST.pos, Content.FIRST.kind)


# -- A round ----------------------------------------------------------------------------------------------

## The producers make what is due, the energy comes in, a fresh hand is dealt.
func start_round(rng: RandomNumberGenerator) -> Array:
	var ev: Array = []
	for p in _plots():
		var b: Dictionary = buildings[p]
		if not _level(b).has("makes"):
			continue
		b.wait = int(b.wait) - 1
		if int(b.wait) <= 0:
			ev.append_array(make(p))
			b.wait = every(p)
	ev.append_array(merge())
	var gain := income()
	energy = mini(ENERGY_MAX, energy + gain)
	ev.append({"t": "income", "amount": gain})
	discard.append_array(hand)
	hand.clear()
	for i in HAND:
		if draw.is_empty():
			if discard.is_empty():
				break
			draw = discard
			discard = []
			shuffle(draw, rng)
		hand.append(draw.pop_back())
	return ev


## The producer at p makes its count of units, as far as there is room -- with no room, still one that makes three
## alike, which become one at once; drilled by the gyms beside it.
func make(p: Vector2i) -> Array:
	var ev: Array = []
	var b: Dictionary = buildings[p]
	var l := _level(b)
	var drill := 0
	for q in around(p):
		if buildings.has(q):
			drill += int(_level(buildings[q]).get("drill", 0))
	for i in int(l.count):
		var star := int(l.get("star", 1))
		if units.size() >= room() and not completes(l.makes, star):
			ev.append({"t": "full", "by": p})
			break
		var u := {"id": _id(), "kind": l.makes, "star": star, "bonus_hp": 0, "bonus_atk": drill}
		units.append(u)
		ev.append({"t": "made", "unit": u.duplicate(), "by": p})
		ev.append_array(merge())
	return ev


## Whether one more of kind at these stars would make three alike.
func completes(kind: String, star: int) -> bool:
	if star >= 3:
		return false
	return units.filter(func(u: Dictionary) -> bool: return u.kind == kind and int(u.star) == star).size() >= Content.MERGE - 1


## Three of a kind at the same stars become one a star higher -- keeping the best of what each was given --
## as often as there are three.
func merge() -> Array:
	var ev: Array = []
	var again := true
	while again:
		again = false
		var groups := {}
		for u in units:
			if int(u.star) >= 3:
				continue
			var key := "%s/%d" % [u.kind, u.star]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(u)
		for key in groups:
			var g: Array = groups[key]
			if g.size() >= Content.MERGE:
				var three := g.slice(0, Content.MERGE)
				var top := {"id": _id(), "kind": three[0].kind, "star": int(three[0].star) + 1, "bonus_hp": 0, "bonus_atk": 0}
				for u in three:
					top.bonus_hp = maxi(top.bonus_hp, int(u.bonus_hp))
					top.bonus_atk = maxi(top.bonus_atk, int(u.bonus_atk))
					units.erase(u)
				units.append(top)
				ev.append({"t": "merged", "unit": top.duplicate(), "from": three.map(func(u: Dictionary) -> int: return u.id)})
				again = true
				break
	return ev


# -- Cards ------------------------------------------------------------------------------------------------

## Where hand[i] can go: plots (Vector2i) for build, building, producer; unit ids for unit; [true] for a card
## played at once. [] when it cannot be played now.
func targets(i: int) -> Array:
	var c := Content.card(hand[i])
	if energy < int(c.cost):
		return []
	match c.target:
		"tile":
			return _plots_all().filter(func(p: Vector2i) -> bool: return not buildings.has(p))
		"building":
			return _plots().filter(func(p: Vector2i) -> bool: return int(buildings[p].level) < 3)
		"producer":
			return _plots().filter(func(p: Vector2i) -> bool: return _level(buildings[p]).has("makes"))
		"unit":
			var list := units if not c.has("star_up") else units.filter(func(u: Dictionary) -> bool: return int(u.star) < 3)
			return list.map(func(u: Dictionary) -> int: return u.id)
	return [true]


## Plays hand[i] on `at` (a plot, a unit id, or anything for a card with no target). Its events; [] if it could
## not be played.
func play(i: int, at: Variant) -> Array:
	if i < 0 or i >= hand.size():
		return []
	var c := Content.card(hand[i])
	var fits := targets(i)
	if fits.is_empty() or (c.target != "none" and not at in fits):
		return []
	energy -= int(c.cost)
	discard.append(hand[i])
	hand.remove_at(i)
	var ev: Array = [{"t": "played", "card": c.id}]
	if c.type == "build":
		build(at, c.builds)
		ev.append({"t": "built", "at": at})
	if c.has("battle"):
		for k in c.battle:
			buffs[k] = int(buffs.get(k, 0)) + int(c.battle[k])
	if c.has("mend"):
		var before := hp
		hp = mini(hp_max(), hp + int(c.mend))
		ev.append({"t": "mended", "amount": hp - before})
	if c.has("unit"):
		var u: Variant = unit(at)
		u.bonus_hp = int(u.bonus_hp) + int(c.unit.hp)
		u.bonus_atk = int(u.bonus_atk) + int(c.unit.atk)
		ev.append({"t": "trained", "id": u.id})
	if c.has("level_up"):
		var b: Dictionary = buildings[at]
		var was := hp_max()
		b.level = mini(3, int(b.level) + 1)
		hp += hp_max() - was
		ev.append({"t": "raised", "at": at})
	if c.has("star_up"):
		var u: Variant = unit(at)
		u.star = mini(3, int(u.star) + 1)
		ev.append({"t": "starred", "id": u.id})
		ev.append_array(merge())
	if c.has("make_now"):
		for k in int(c.make_now):
			ev.append_array(make(at))
		ev.append_array(merge())
	return ev


## A copy to try a card on (the forecast): the same homeland, nothing shared.
func clone() -> Home:
	var h := Home.new([], RandomNumberGenerator.new())
	h.buildings = buildings.duplicate(true)
	h.units = units.duplicate(true)
	h.energy = energy
	h.hp = hp
	h.draw = draw.duplicate(true)
	h.hand = hand.duplicate(true)
	h.discard = discard.duplicate(true)
	h.buffs = buffs.duplicate(true)
	h.next_id = next_id
	return h


func build(p: Vector2i, kind: String) -> void:
	var was := hp_max()
	buildings[p] = {"id": _id(), "kind": kind, "level": 1, "wait": 1}
	hp += hp_max() - was


# -- What the homeland comes to ---------------------------------------------------------------------------

func room() -> int:
	var n := ROOM
	for p in buildings:
		n += int(_level(buildings[p]).get("room", 0))
	return n


func income() -> int:
	var n := INCOME
	for p in buildings:
		n += int(_level(buildings[p]).get("income", 0))
	return n


func hp_max() -> int:
	var n := HP
	for p in buildings:
		n += int(_level(buildings[p]).get("wall", 0))
	return n


## How much less harm a lost battle does.
func block() -> int:
	var n := 0
	for p in buildings:
		n += int(_level(buildings[p]).get("block", 0))
	return n


## Rounds between the producer at p's makings: its own, sooner by the nurseries beside it.
func every(p: Vector2i) -> int:
	var hurry := 0
	for q in around(p):
		if buildings.has(q):
			hurry += int(_level(buildings[q]).get("hurry", 0))
	return maxi(1, int(_level(buildings[p]).every) - hurry)


## The battle's lost: the homeland takes the harm, less what its walls block. What it took.
func harmed(harm: int) -> int:
	var took := maxi(0, harm - block())
	hp = maxi(0, hp - took)
	return took


func unit(id: Variant) -> Variant:
	for u in units:
		if u.id == id:
			return u
	return null


func around(p: Vector2i) -> Array:
	var out: Array = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if q != p and q.x >= 0 and q.x < COLS and q.y >= 0 and q.y < ROWS:
				out.append(q)
	return out


func level_of(p: Vector2i) -> Dictionary:
	return _level(buildings[p])


static func _level(b: Dictionary) -> Dictionary:
	return Content.BUILDINGS[b.kind].levels[int(b.level) - 1]


## The plots with buildings, in reading order -- the order producers make in.
func _plots() -> Array:
	return _plots_all().filter(func(p: Vector2i) -> bool: return buildings.has(p))


func _plots_all() -> Array:
	var out: Array = []
	for y in ROWS:
		for x in COLS:
			out.append(Vector2i(x, y))
	return out


func _id() -> int:
	next_id += 1
	return next_id - 1


static func shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = t
