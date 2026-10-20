class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 15): a grid of plots with buildings in them, the gold and the other resources, the shop's
## shelf, the potions and the fossil relics, and the homeland's own hit points. One round here: the buildings bring in
## gold, biomass and genes and the shelf is stocked (start_round); the player buys -- buildings, raises, affixes --
## and takes potions; then the nests make this round's army, paying biomass (produce), and it goes out to fight
## (Fight). The army lives for that battle only. Gold kept to the round's end earns interest.
##
## Neighbours are the four plots up, down, left and right. Plain data and rules, nothing on screen: the same rules for
## the game and for its tests.
##
## A building: {id, kind, level, wait, affixes: [ids]}  -- wait: rounds until a lab next brews.
## An offer on the shelf: {id, potion, gift} (Content.offer), or null where one was bought. Gifts (the free pick after
## each round) stand at the front of the shelf, free, until they are used; restocking leaves them.
## A unit (army): {id: "nest id:n", kind, nest: plot, hp_mult, atk_mult, atk_bonus, armor, range, splash, dive,
##   affixes, free} -- free: made by a potion or a relic, eating nothing.
## Events (for the screen): bought {offer}, built {at}, replaced {at, was, back}, raised {at}, affixed {at, affix},
## gained {genes, biomass}, potion_got {potion}, income {gold, biomass, genes}, brewed {at, potion}, potion {potion},
## mended {amount}, stocked.

const COLS := 6
const ROWS := 5                   # rows there can ever be
const OPEN := 3                   # rows open at the start (the south ones); each level held opens one more
const INCOME := 3                 # gold each round
const BIOMASS_MAX := 20
const GENES_MAX := 10
const HP := 30

var buildings := {}               # Vector2i -> building
var open_rows := OPEN
var gold := 0
var biomass := 0
var genes := 0
var alien := 0
var hp := HP
var potions: Array = []           # potion ids
var relics: Array = []            # relic ids
var shelf: Array = []             # offers, or null where bought
var rerolls := 0                  # times the shelf was stocked again this round
var buffs := {}                   # for this round only: atk, armor, haste, breed
var next_id := 1


func _init(rng: RandomNumberGenerator) -> void:
	for f in Content.FIRST:
		build(f.pos, f.kind)
	gold = int(Content.FIRST_STOCK.gold)
	biomass = int(Content.FIRST_STOCK.biomass)
	genes = int(Content.FIRST_STOCK.genes)
	potions = Content.FIRST_STOCK.potions.duplicate()


# -- A round ----------------------------------------------------------------------------------------------

## The buildings bring in what they make, the labs brew, the shelf is stocked afresh.
func start_round(rng: RandomNumberGenerator, level: int) -> Array:
	var ev: Array = []
	var g := income_gold()
	var b := income_biomass()
	var n := income_genes()
	gold += g
	biomass = mini(biomass_max(), biomass + b)
	genes = mini(genes_max(), genes + n)
	ev.append({"t": "income", "gold": g, "biomass": b, "genes": n})
	for p in _plots():
		var bd: Dictionary = buildings[p]
		if bd.kind != "lab":
			continue
		bd.wait = int(bd.wait) - 1
		if int(bd.wait) <= 0:
			bd.wait = int(_level(bd).brew)
			if potions.size() < Content.POTION_SLOTS:
				var k := _any_potion(rng)
				potions.append(k)
				ev.append({"t": "brewed", "at": p, "potion": k})
	rerolls = 0
	stock(rng, level)
	return ev


## Stocks the shelf (the gifts kept in front): buildings by how much open land is free (more when there is much; one
## when there is none, to pull something down for), then raises, affixes, gains and potions -- only those that can be
## used now, none twice, and no more than one that costs more gold than there is.
func stock(rng: RandomNumberGenerator, level: int) -> void:
	var free := _plots_open().filter(func(p: Vector2i) -> bool: return not buildings.has(p)).size()
	var builds := clampi(ceili(free / 3.0), 1, 3)
	var size := shelf_size()
	var build_pool: Array = []
	var other_pool: Array = []
	for id in Content.OFFERS:
		var o: Dictionary = Content.OFFERS[id]
		if int(o.get("from", 0)) > level or not _useful(id):
			continue
		for k in [6, 3, 1][int(o.rarity)]:
			(build_pool if o.type == "build" else other_pool).append(id)
	shelf = shelf.filter(func(oi: Variant) -> bool: return oi != null and oi.get("gift", false))
	size += shelf.size()
	var taken: Array = []
	var dear := 1                 # how many more that cost more than there is may go up
	for pool in [[build_pool, builds], [other_pool, size - shelf.size() - builds]]:
		var ids: Array = pool[0]
		shuffle(ids, rng)
		var want: int = pool[1]
		for id in ids:
			if want <= 0:
				break
			if id in taken:
				continue
			if _least_price(id) > gold:
				if dear <= 0:
					continue
				dear -= 1
			taken.append(id)
			var oi := {"id": id}
			if id == "potion":
				oi.potion = _any_potion(rng)
			shelf.append(oi)
			want -= 1
	# Not enough that could be used: fill with what is left of the other pool.
	for pool in [build_pool, other_pool]:
		for id in pool:
			if shelf.size() >= size:
				break
			if not id in taken:
				taken.append(id)
				shelf.append({"id": id, "potion": _any_potion(rng)} if id == "potion" else {"id": id})


## The least an offer can cost now (a raise: on the lowest building).
func _least_price(id: String) -> int:
	var o: Dictionary = Content.OFFERS[id]
	match o.type:
		"build":
			return maxi(1, int(Content.BUILDINGS[o.builds].cost) - (1 if "wood" in relics else 0))
		"raise":
			var lv := Content.LEVEL_MAX
			for p in _plots():
				lv = mini(lv, int(buildings[p].level))
			return Content.RAISE + lv
	return int(o.price)


## Whether an offer could be used now.
func _useful(id: String) -> bool:
	match Content.OFFERS[id].type:
		"raise":
			return _plots().any(func(p: Vector2i) -> bool: return int(buildings[p].level) < Content.LEVEL_MAX)
		"affix":
			var a: String = Content.OFFERS[id].affix
			return _plots().any(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not a in b.affixes and b.affixes.size() < slots(p))
		"potion":
			return potions.size() < Content.POTION_SLOTS
	return true


func shelf_size() -> int:
	return Content.SHOP + (1 if "amber" in relics else 0)


func reroll_price() -> int:
	var free := 1 if "trilobite" in relics else 0
	return 0 if rerolls < free else Content.REROLL + rerolls - free


## The shelf stocked again, for gold. Whether it was.
func reroll(rng: RandomNumberGenerator, level: int) -> bool:
	var p := reroll_price()
	if gold < p:
		return false
	gold -= p
	rerolls += 1
	stock(rng, level)
	return true


## The interest on the gold kept to the round's end (Run.finish pays it).
func interest() -> int:
	return mini(interest_max(), gold / Content.INTEREST_STEP)


func interest_max() -> int:
	return Content.INTEREST_MAX + (2 if "ammonite" in relics else 0)


# -- This round's army ------------------------------------------------------------------------------------

## This round's army as things stand: each nest, in reading order, makes its count (one more beside nests of its kind,
## one more for each breed potion taken, one more for the first with the egg relic), each unit paid for in biomass as
## far as the biomass goes -- the ones a potion or a relic makes eat nothing.
func army() -> Array:
	var out: Array = []
	var food := biomass
	var first := true
	for p in _plots():
		var b: Dictionary = buildings[p]
		if not Content.is_nest(b.kind):
			continue
		var kind: String = Content.BUILDINGS[b.kind].nest
		var cost := int(Content.UNITS[kind].food)
		var spec := spec_of(p)
		var paid := count(p)
		var extra := int(buffs.get("breed", 0)) + (1 if first and "egg" in relics else 0)
		first = false
		for i in paid + extra:
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


## How many the nest at p makes a round (before biomass, potions and relics): its level's count, one more with CLUSTER
## neighbours of its kind.
func count(p: Vector2i) -> int:
	var b: Dictionary = buildings[p]
	var same := 0
	for q in around(p):
		if buildings.has(q) and buildings[q].kind == b.kind:
			same += 1
	return int(_level(b).count) + (1 if same >= Content.CLUSTER else 0)


## What the nest at p gives each unit it makes: its level's quality, what its neighbours add, its affixes, the relics.
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
			"mine":
				hp_pct += Content.MINE_HP
			"gym":
				drill += int(_level(buildings[n]).drill)
	if "frill" in relics:
		hp_pct += 15
	if "tooth" in relics:
		drill += 1
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


# -- Buying and potions -----------------------------------------------------------------------------------

## What shelf[i] costs in gold -- on `at`, for a raise (more for a higher building); nothing, for a gift.
func price(i: int, at: Variant = null) -> int:
	if shelf[i].get("gift", false):
		return 0
	var o := Content.offer(shelf[i])
	match o.type:
		"build":
			return maxi(1, int(o.price) - (1 if "wood" in relics else 0))
		"raise":
			var lv := int(buildings[at].level) if at is Vector2i and buildings.has(at) else 1
			return Content.RAISE + lv
	return int(o.price)


## Where shelf[i] can go and be paid for: plots (Vector2i) for build, raise and affix; [true] for one used at once. []
## when it cannot be bought now.
func targets(i: int) -> Array:
	if i < 0 or i >= shelf.size() or shelf[i] == null:
		return []
	var o := Content.offer(shelf[i])
	var gift: bool = shelf[i].get("gift", false)
	if not gift and (genes < int(o.get("genes", 0)) or alien < int(o.get("alien", 0))):
		return []
	match o.target:
		"tile":
			if gold < price(i):
				return []
			return _plots_open().filter(func(p: Vector2i) -> bool:
				return not buildings.has(p) or buildings[p].kind != o.builds)
		"building":
			return _plots().filter(func(p: Vector2i) -> bool:
				return int(buildings[p].level) < Content.LEVEL_MAX and gold >= price(i, p))
		"nest":
			if gold < price(i):
				return []
			return _plots().filter(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not o.affix in b.affixes and b.affixes.size() < slots(p))
	if gold < price(i) or (o.type == "potion" and potions.size() >= Content.POTION_SLOTS):
		return []
	return [true]


## Buys shelf[i] for `at` (a plot, or anything for one used at once). Its events; [] if it could not be bought.
func buy(i: int, at: Variant) -> Array:
	var fits := targets(i)
	if fits.is_empty():
		return []
	var o := Content.offer(shelf[i])
	if o.target != "none" and not at in fits:
		return []
	if shelf[i].get("gift", false):
		shelf.remove_at(i)
	else:
		gold -= price(i, at)
		genes -= int(o.get("genes", 0))
		alien -= int(o.get("alien", 0))
		shelf[i] = null
	var ev: Array = [{"t": "bought", "offer": o.id}]
	match o.type:
		"build":
			if buildings.has(at):
				var was: String = buildings[at].kind
				var back := int(Content.BUILDINGS[was].cost) / 2
				gold += back
				build(at, o.builds)
				ev.append({"t": "replaced", "at": at, "was": was, "back": back})
			else:
				build(at, o.builds)
				ev.append({"t": "built", "at": at})
		"raise":
			var b: Dictionary = buildings[at]
			var max_was := hp_max()
			b.level = mini(Content.LEVEL_MAX, int(b.level) + 1)
			hp += hp_max() - max_was
			ev.append({"t": "raised", "at": at})
		"affix":
			buildings[at].affixes.append(o.affix)
			ev.append({"t": "affixed", "at": at, "affix": o.affix})
		"gain":
			var g := int(o.get("gain_genes", 0))
			var bm := int(o.get("gain_biomass", 0))
			genes = mini(genes_max(), genes + g)
			biomass = mini(biomass_max(), biomass + bm)
			ev.append({"t": "gained", "genes": g, "biomass": bm})
		"potion":
			potions.append(o.potion)
			ev.append({"t": "potion_got", "potion": o.potion})
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


func _any_potion(rng: RandomNumberGenerator) -> String:
	var kinds: Array = Content.POTIONS.keys()
	return kinds[rng.randi() % kinds.size()]


## A building put up at p (whatever was there pulled down), at level 1. The homeland's hit points follow its walls.
func build(p: Vector2i, kind: String) -> void:
	var max_was := hp_max()
	var b := {"id": _id(), "kind": kind, "level": 1, "wait": 0, "affixes": []}
	if kind == "lab":
		b.wait = int(Content.level(kind, 1).brew)
	buildings[p] = b
	hp = mini(hp_max(), hp + maxi(0, hp_max() - max_was))


## A copy to try an offer or a potion on (the forecast): the same homeland, nothing shared.
func clone() -> Home:
	var h := Home.new(RandomNumberGenerator.new())
	h.buildings = buildings.duplicate(true)
	h.open_rows = open_rows
	h.gold = gold
	h.biomass = biomass
	h.genes = genes
	h.alien = alien
	h.hp = hp
	h.potions = potions.duplicate()
	h.relics = relics.duplicate()
	h.shelf = shelf.duplicate(true)
	h.rerolls = rerolls
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

func income_gold() -> int:
	return INCOME + _sum("gold")


func income_biomass() -> int:
	return _sum("biomass") + (3 if "coprolite" in relics else 0)


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


static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = items[i]
		items[i] = items[j]
		items[j] = t
