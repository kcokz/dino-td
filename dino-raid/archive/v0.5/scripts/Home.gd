class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 14): a grid of plots with buildings in them, the resources, the cards and potions, and
## the homeland's own hit points. One round here: the buildings bring in energy, biomass and genes (start_round); the
## player plays cards -- builds, raises, affixes -- and potions; then the nests make this round's army, paying
## biomass (produce), and it goes out to fight (Fight). The army lives for that battle only.
##
## Neighbours are the four plots up, down, left and right. Plain data and rules, nothing on screen: the same rules for
## the game and for its tests.
##
## A building: {id, kind, level, wait, affixes: [ids]}  -- wait: rounds until a lab next brews.
## A unit (army): {id: "nest id:n", kind, nest: plot, hp_mult, atk_mult, atk_bonus, armor, range, splash, dive,
##   affixes, free} -- free: made by a potion, eating nothing.
## Events (for the screen): played {card}, built {at}, replaced {at, was, back}, raised {at}, affixed {at, affix},
## gained {genes, biomass}, income {energy, biomass, genes}, brewed {at, potion}, potion {potion}, mended {amount}.

const COLS := 6
const ROWS := 5                   # rows there can ever be
const OPEN := 3                   # rows open at the start (the south ones); each level held opens one more
const INCOME := 3                 # energy each round
const ENERGY_MAX := 10
const BIOMASS_MAX := 20
const GENES_MAX := 10
const HAND := 5
const HP := 30

var buildings := {}               # Vector2i -> building
var open_rows := OPEN
var energy := 0
var biomass := 0
var genes := 0
var alien := 0
var hp := HP
var potions: Array = []           # potion ids
var draw: Array = []              # card instances {id, up}; the top is the end
var hand: Array = []
var discard: Array = []
var buffs := {}                   # for this round only: atk, armor, haste, breed
var next_id := 1


func _init(deck: Array, rng: RandomNumberGenerator) -> void:
	draw = deck.duplicate(true)
	shuffle(draw, rng)
	for f in Content.FIRST:
		build(f.pos, f.kind)
	biomass = int(Content.FIRST_STOCK.biomass)
	genes = int(Content.FIRST_STOCK.genes)
	potions = Content.FIRST_STOCK.potions.duplicate()


# -- A round ----------------------------------------------------------------------------------------------

## The buildings bring in what they make, the labs brew, and the hand -- what was not played is kept -- is filled
## up to HAND from the draw pile (the discard pile shuffled back in when it runs out).
func start_round(rng: RandomNumberGenerator) -> Array:
	var ev: Array = []
	var e := income_energy()
	var b := income_biomass()
	var g := income_genes()
	energy = mini(ENERGY_MAX, energy + e)
	biomass = mini(biomass_max(), biomass + b)
	genes = mini(genes_max(), genes + g)
	ev.append({"t": "income", "energy": e, "biomass": b, "genes": g})
	for p in _plots():
		var bd: Dictionary = buildings[p]
		if bd.kind != "lab":
			continue
		bd.wait = int(bd.wait) - 1
		if int(bd.wait) <= 0:
			bd.wait = int(_level(bd).brew)
			if potions.size() < Content.POTION_SLOTS:
				var kinds: Array = Content.POTIONS.keys()
				var k: String = kinds[rng.randi() % kinds.size()]
				potions.append(k)
				ev.append({"t": "brewed", "at": p, "potion": k})
	while hand.size() < HAND:
		if draw.is_empty():
			if discard.is_empty():
				break
			draw = discard
			discard = []
			shuffle(draw, rng)
		hand.append(draw.pop_back())
	return ev


## This round's army as things stand: each nest, in reading order, makes its count (more beside nests of its kind,
## one more for each breed potion taken), each unit paid for in biomass as far as the biomass goes -- the ones a
## potion makes eat nothing.
func army() -> Array:
	var out: Array = []
	var food := biomass
	for p in _plots():
		var b: Dictionary = buildings[p]
		if not Content.is_nest(b.kind):
			continue
		var kind: String = Content.BUILDINGS[b.kind].nest
		var cost := int(Content.UNITS[kind].food)
		var spec := spec_of(p)
		var paid := count(p)
		for i in paid + int(buffs.get("breed", 0)):
			var free := i >= paid
			if not free:
				if food < cost:
					continue
				food -= cost
			var u := spec.duplicate()
			u.id = "%d:%d" % [b.id, i]
			u.free = free
			out.append(u)
	return out


## The biomass this round's army eats.
func army_food() -> int:
	var n := 0
	for u in army():
		if not u.free:
			n += int(Content.UNITS[u.kind].food)
	return n


## The army goes out: its biomass is paid. The army.
func produce() -> Array:
	var out := army()
	biomass -= army_food()
	return out


## How many the nest at p makes a round (before biomass and potions): its level's count, one more with CLUSTER
## neighbours of its kind.
func count(p: Vector2i) -> int:
	var b: Dictionary = buildings[p]
	var same := 0
	for q in around(p):
		if buildings.has(q) and buildings[q].kind == b.kind:
			same += 1
	return int(_level(b).count) + (1 if same >= Content.CLUSTER else 0)


## What the nest at p gives each unit it makes: its level's quality, what its neighbours add, its affixes.
func spec_of(p: Vector2i) -> Dictionary:
	var b: Dictionary = buildings[p]
	var q := float(_level(b).quality)
	var hp_pct := 0
	var drill := 0
	for n in around(p):
		if not buildings.has(n):
			continue
		match buildings[n].kind:
			"pool":
				hp_pct += Content.POOL_HP
			"power":
				hp_pct += Content.POWER_HP
			"gym":
				drill += int(_level(buildings[n]).drill)
	var s := {"kind": Content.BUILDINGS[b.kind].nest, "nest": p, "hp_mult": q * (1.0 + hp_pct / 100.0), "atk_mult": q,
		"atk_bonus": drill, "armor": 0, "range": 0.0, "splash": 0.0, "dive": false, "affixes": b.affixes.duplicate()}
	for a in b.affixes:
		var af: Dictionary = Content.AFFIXES[a]
		s.atk_bonus = int(s.atk_bonus) + int(af.get("atk", 0))
		s.armor = int(s.armor) + int(af.get("armor", 0))
		s.range = maxf(float(s.range), float(af.get("range", 0.0)))
		s.splash = float(s.splash) + float(af.get("splash", 0.0))
		s.dive = bool(s.dive) or bool(af.get("dive", false))
	return s


## How many affixes the nest at p can carry: one, more beside stabilizers.
func slots(p: Vector2i) -> int:
	var n := 1
	for q in around(p):
		if buildings.has(q) and buildings[q].kind == "stabilizer":
			n += int(_level(buildings[q]).slots)
	return n


# -- Cards and potions ------------------------------------------------------------------------------------

## Where hand[i] can go: plots (Vector2i) for build, raise and affix; [true] for a card played at once. [] when it
## cannot be played now.
func targets(i: int) -> Array:
	var c := Content.card(hand[i])
	if energy < int(c.cost) or genes < int(c.get("genes", 0)) or alien < int(c.get("alien", 0)):
		return []
	match c.target:
		"tile":
			return _plots_open().filter(func(p: Vector2i) -> bool:
				return not buildings.has(p) or buildings[p].kind != c.builds)
		"building":
			return _plots().filter(func(p: Vector2i) -> bool: return int(buildings[p].level) < Content.LEVEL_MAX)
		"nest":
			return _plots().filter(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not c.affix in b.affixes and b.affixes.size() < slots(p))
	return [true]


## Plays hand[i] on `at` (a plot, or anything for a card with no target). Its events; [] if it could not be played.
func play(i: int, at: Variant) -> Array:
	if i < 0 or i >= hand.size():
		return []
	var c := Content.card(hand[i])
	var fits := targets(i)
	if fits.is_empty() or (c.target != "none" and not at in fits):
		return []
	energy -= int(c.cost)
	genes -= int(c.get("genes", 0))
	alien -= int(c.get("alien", 0))
	discard.append(hand[i])
	hand.remove_at(i)
	var ev: Array = [{"t": "played", "card": c.id}]
	match c.type:
		"build":
			if buildings.has(at):
				var was: String = buildings[at].kind
				var back := int(Content.BUILDINGS[was].cost) / 2
				energy = mini(ENERGY_MAX, energy + back)
				build(at, c.builds)
				ev.append({"t": "replaced", "at": at, "was": was, "back": back})
			else:
				build(at, c.builds)
				ev.append({"t": "built", "at": at})
		"raise":
			var b: Dictionary = buildings[at]
			var max_was := hp_max()
			b.level = mini(Content.LEVEL_MAX, int(b.level) + 1)
			hp += hp_max() - max_was
			ev.append({"t": "raised", "at": at})
		"affix":
			buildings[at].affixes.append(c.affix)
			ev.append({"t": "affixed", "at": at, "affix": c.affix})
		"gain":
			var g := int(c.get("gain_genes", 0))
			var bm := int(c.get("gain_biomass", 0))
			genes = mini(genes_max(), genes + g)
			biomass = mini(biomass_max(), biomass + bm)
			ev.append({"t": "gained", "genes": g, "biomass": bm})
	return ev


## Takes potion k (an index into potions). Its events; [] if there is none there.
func use_potion(k: int) -> Array:
	if k < 0 or k >= potions.size():
		return []
	var id: String = potions[k]
	potions.remove_at(k)
	var pt: Dictionary = Content.POTIONS[id]
	var ev: Array = [{"t": "potion", "potion": id}]
	if pt.has("battle"):
		for key in pt.battle:
			buffs[key] = int(buffs.get(key, 0)) + int(pt.battle[key])
	if pt.has("breed"):
		buffs.breed = int(buffs.get("breed", 0)) + int(pt.breed)
	if pt.has("mend"):
		var before := hp
		hp = mini(hp_max(), hp + int(pt.mend))
		ev.append({"t": "mended", "amount": hp - before})
	return ev


## A potion found: kept if there is a free place.
func add_potion(id: String) -> bool:
	if potions.size() >= Content.POTION_SLOTS:
		return false
	potions.append(id)
	return true


## A building put up at p (whatever was there pulled down), at level 1. The homeland's hit points follow its walls.
func build(p: Vector2i, kind: String) -> void:
	var max_was := hp_max()
	var b := {"id": _id(), "kind": kind, "level": 1, "wait": 0, "affixes": []}
	if kind == "lab":
		b.wait = int(Content.level(kind, 1).brew)
	buildings[p] = b
	hp = mini(hp_max(), hp + maxi(0, hp_max() - max_was))
	hp = mini(hp, hp_max())


## A copy to try a card or a potion on (the forecast): the same homeland, nothing shared.
func clone() -> Home:
	var h := Home.new([], RandomNumberGenerator.new())
	h.buildings = buildings.duplicate(true)
	h.open_rows = open_rows
	h.energy = energy
	h.biomass = biomass
	h.genes = genes
	h.alien = alien
	h.hp = hp
	h.potions = potions.duplicate()
	h.draw = draw.duplicate(true)
	h.hand = hand.duplicate(true)
	h.discard = discard.duplicate(true)
	h.buffs = buffs.duplicate(true)
	h.next_id = next_id
	return h


## A level held: one more row of land opens, to the north.
func open_row() -> bool:
	if open_rows >= ROWS:
		return false
	open_rows += 1
	return true


func is_open(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= ROWS - open_rows and p.y < ROWS


# -- What the homeland comes to ---------------------------------------------------------------------------

func income_energy() -> int:
	return INCOME + _sum("energy")


func income_biomass() -> int:
	return _sum("biomass")


func income_genes() -> int:
	var n := _sum("genes")
	for p in buildings:
		if buildings[p].kind == "sampler":
			for q in around(p):
				if buildings.has(q) and buildings[q].kind == "pool":
					n += Content.SAMPLER_POOL
	return n


func biomass_max() -> int:
	return BIOMASS_MAX + _sum("store")


func genes_max() -> int:
	return GENES_MAX + _sum("store_genes")


func hp_max() -> int:
	return HP + _sum("wall")


## How much less harm a lost battle does: each wall's block, more for each wall beside it.
func block() -> int:
	var n := 0
	for p in buildings:
		if buildings[p].kind != "wall":
			continue
		n += int(_level(buildings[p]).block)
		for q in around(p):
			if buildings.has(q) and buildings[q].kind == "wall":
				n += Content.WALL_CHAIN
	return n


## The battle's lost: the homeland takes the harm, less what its walls block. What it took.
func harmed(harm: int) -> int:
	var took := maxi(0, harm - block())
	hp = maxi(0, hp - took)
	return took


func around(p: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var q: Vector2i = p + d
		if q.x >= 0 and q.x < COLS and q.y >= 0 and q.y < ROWS:
			out.append(q)
	return out


func level_of(p: Vector2i) -> Dictionary:
	return _level(buildings[p])


static func _level(b: Dictionary) -> Dictionary:
	return Content.level(b.kind, int(b.level))


func _sum(key: String) -> int:
	var n := 0
	for p in buildings:
		n += int(_level(buildings[p]).get(key, 0))
	return n


## The plots with buildings, in reading order -- the order nests make in.
func _plots() -> Array:
	return _plots_all().filter(func(p: Vector2i) -> bool: return buildings.has(p))


func _plots_open() -> Array:
	return _plots_all().filter(func(p: Vector2i) -> bool: return is_open(p))


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
