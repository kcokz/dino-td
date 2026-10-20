class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 17, 18): wherever the ark has landed, a grid of plots -- some of them special ground --
## with buildings in them, the gold and the other resources, the shop's shelf, the goods kept for later (the stash),
## the relics, and the homeland's own hit points. One round here: the buildings bring in gold, biomass and genes and the
## shelf is stocked (start_round); the player buys -- buildings, raises, affixes -- and puts goods down from the stash;
## then the nests make this round's army, paying biomass (produce), and it goes out to fight (Fight). The army lives for
## that battle only. Gold kept to the round's end earns interest. When a place is held, the ark moves on (land): the
## buildings stay behind but for those packed into the stash.
##
## Neighbours are the four plots up, down, left and right. Plain data and rules, nothing on screen: the same rules for
## the game and for its tests.
##
## A building: {id, kind, level, affixes: [ids]}.
## A good (shelf or stash): {id, gift, packed: {level, affixes}} (Content.offer), or null on the shelf where one was
##   bought.
## A unit (army): {id: "nest id:n", kind, nest: plot, hp_mult, atk_mult, atk_bonus, armor, range, splash, dive, pierce,
##   haste, affixes, free} -- free: made by a relic, eating nothing.
## Events (for the screen): bought {offer}, stored {offer}, placed {offer}, built {at}, replaced {at, was, back},
## raised {at}, affixed {at, affix}, income {gold, biomass, genes}, rotted {amount}, ash {amount}, mended {amount}.

const COLS := 6
const ROWS := 4
const INCOME := 5                 # gold each round
const BIOMASS_MAX := 20
const GENES_MAX := 10
const HP := 30
## Where the ark sets things down, first to last: the middle outwards.
const LANDING_PLOTS := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(4, 2),
	Vector2i(1, 1), Vector2i(4, 1), Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 0), Vector2i(3, 0)]

var region := 0                   # the place (Content.LEVELS) the ark has landed in
var buildings := {}               # Vector2i -> building
var terrain := {}                 # Vector2i -> special ground (Content.TERRAIN)
var gold := 0
var biomass := 0
var genes := 0
var alien := 0
var hp := HP
var relics: Array = []            # relic ids
var shelf: Array = []             # offers, or null where bought
var stash: Array = []             # goods kept for later
var rerolls := 0                  # times the shelf was stocked again this round
var next_id := 1


func _init(rng: RandomNumberGenerator) -> void:
	gold = int(Content.FIRST_STOCK.gold)
	biomass = int(Content.FIRST_STOCK.biomass)
	genes = int(Content.FIRST_STOCK.genes)
	land(0, rng, Content.LANDING)


## The ark lands in place `r`: the old buildings are left behind, the special ground of the new place lies about, and
## the ark sets down `kit` ([kind, level] each) in the middle. What is in the stash comes along.
func land(r: int, rng: RandomNumberGenerator, kit: Array) -> void:
	region = r
	buildings.clear()
	terrain.clear()
	var plots := _plots_all().filter(func(p: Vector2i) -> bool: return not p in LANDING_PLOTS.slice(0, 4))
	shuffle(plots, rng)
	var lie: Dictionary = Content.LEVELS[r].terrain
	for kind in lie:
		for k in int(lie[kind]):
			if not plots.is_empty():
				terrain[plots.pop_back()] = kind
	for item in kit:
		var p := _free_landing()
		if p != Vector2i(-1, -1):
			build(p, item[0])
			buildings[p].level = int(item[1])
	hp = mini(hp, hp_max())
	shelf = []


func _free_landing() -> Vector2i:
	for p in LANDING_PLOTS:
		if buildable(p) and not buildings.has(p):
			return p
	for p in _plots_all():
		if buildable(p) and not buildings.has(p):
			return p
	return Vector2i(-1, -1)


# -- A round ----------------------------------------------------------------------------------------------

## The place has its way (damp: stored biomass rots; ash falls); the buildings bring in what they make; vines mend;
## the shelf is stocked afresh.
func start_round(rng: RandomNumberGenerator, level: int) -> Array:
	var ev: Array = []
	if rule() == "damp" and biomass > 0:
		var rot := biomass / 2
		biomass -= rot
		ev.append({"t": "rotted", "amount": rot})
	var ash := (1 if rule() == "ash" else 0) + (1 if "heart" in relics else 0)
	if ash > 0:
		var before := hp
		hp = maxi(1, hp - ash)
		ev.append({"t": "ash", "amount": before - hp})
	var g := income_gold()
	var b := income_biomass()
	var n := income_genes()
	gold += g
	biomass = mini(biomass_max(), biomass + b)
	genes = mini(genes_max(), genes + n)
	ev.append({"t": "income", "gold": g, "biomass": b, "genes": n})
	var mend := _sum("mend")
	if mend > 0 and hp < hp_max():
		var before := hp
		hp = mini(hp_max(), hp + mend)
		ev.append({"t": "mended", "amount": hp - before})
	rerolls = 0
	stock(rng, level)
	return ev


func rule() -> String:
	return str(Content.LEVELS[region].get("rule", ""))


## Stocks the shelf: buildings by how much land is free (more when there is much; one when there is none, to pull
## something down for), then raises and affixes -- only those that can be used now and are found here, none twice, and
## no more than one that costs more gold than there is.
func stock(rng: RandomNumberGenerator, level: int) -> void:
	var free := _plots_all().filter(func(p: Vector2i) -> bool: return buildable(p) and not buildings.has(p)).size()
	var builds := clampi(ceili(free / 3.0), 1, 3)
	var size := shelf_size()
	var build_pool: Array = []
	var other_pool: Array = []
	for id in pool_ids(level):
		var o: Dictionary = Content.OFFERS[id]
		for k in [6, 3, 1][int(o.rarity)]:
			(build_pool if o.type == "build" else other_pool).append(id)
	shelf = []
	var taken: Array = []
	var dear := 1                 # how many more that cost more than there is may go up
	for pool in [[build_pool, builds], [other_pool, size - builds]]:
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
			shelf.append({"id": id})
			want -= 1
	# Not enough that could be used: fill with what is left.
	for pool in [build_pool, other_pool]:
		for id in pool:
			if shelf.size() >= size:
				break
			if not id in taken:
				taken.append(id)
				shelf.append({"id": id})


## The offers this place's shop deals in, of use now: none from a later place, none of another place's own.
func pool_ids(level: int) -> Array:
	return Content.OFFERS.keys().filter(func(id: String) -> bool:
		var o: Dictionary = Content.OFFERS[id]
		return int(o.get("from", 0)) <= level and int(o.get("region", region)) == region and _useful(id))


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
			return _raise_price(lv)
	return int(o.price)


func _raise_price(level: int) -> int:
	return maxi(1, Content.RAISE + level - (1 if rule() == "ash" else 0))


## Whether an offer could be used now -- a stabilizer only once a nest has as many affixes as it has places.
func _useful(id: String) -> bool:
	match Content.OFFERS[id].type:
		"build":
			if Content.OFFERS[id].builds == "stabilizer":
				return _plots().any(func(p: Vector2i) -> bool:
					var b: Dictionary = buildings[p]
					return Content.is_nest(b.kind) and not b.affixes.is_empty() and b.affixes.size() >= slots(p))
		"raise":
			return _plots().any(func(p: Vector2i) -> bool: return int(buildings[p].level) < Content.LEVEL_MAX)
		"affix":
			var a: String = Content.OFFERS[id].affix
			return _plots().any(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not a in b.affixes and b.affixes.size() < slots(p))
	return true


func shelf_size() -> int:
	return Content.SHOP + (1 if "amber" in relics else 0) - (1 if "crystal" in relics else 0)


func stash_size() -> int:
	return Content.STASH + (2 if "sac" in relics else 0)


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
## one more for the first with the egg relic, one more each with the core), each unit paid for in biomass as far as the
## biomass goes -- the one the egg makes eats nothing.
func army() -> Array:
	var out: Array = []
	var food := biomass
	var first := true
	for p in _plots():
		var b: Dictionary = buildings[p]
		if not Content.is_nest(b.kind):
			continue
		var spec := spec_of(p)
		var cost := int(Content.UNITS[spec.kind].food)
		var paid := count(p)
		var extra := 1 if first and "egg" in relics else 0
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


## How many the nest at p makes a round (before biomass and the egg): its level's count, one more with CLUSTER
## neighbours of its kind, one more with the core.
func count(p: Vector2i) -> int:
	var b: Dictionary = buildings[p]
	var same := 0
	for q in around(p):
		if buildings.has(q) and buildings[q].kind == b.kind:
			same += 1
	return int(_level(b).count) + (1 if same >= Content.CLUSTER else 0) + (1 if "core" in relics else 0)


## What the nest at p gives each unit it makes: the species its affixes make of it, its level's quality, what its
## neighbours (buildings and ground) add, its other affixes, the relics.
func spec_of(p: Vector2i) -> Dictionary:
	var b: Dictionary = buildings[p]
	var q := float(_level(b).quality)
	var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
	var hp_pct := 0
	var drill := 0
	var haste := 0
	for n in around(p):
		match terrain.get(n, ""):
			"tree":
				hp_pct += Content.TREE_HP
			"lava":
				drill += Content.LAVA_ATK
		if not buildings.has(n):
			continue
		var nb: Dictionary = buildings[n]
		var nl := _level(nb)
		if nb.kind == "pool":
			hp_pct += Content.POOL_HP
		elif nb.kind == "mine":
			hp_pct += Content.MINE_HP
		drill += int(nl.get("drill", 0))
		haste += int(nl.get("haste", 0))
	if "frill" in relics:
		hp_pct += 15
	if "tooth" in relics:
		drill += 1
	if "heart" in relics:
		drill += 2
	var s := {"kind": sp.kind, "nest": p, "hp_mult": q * (1.0 + hp_pct / 100.0), "atk_mult": q, "atk_bonus": drill,
		"armor": 0, "range": 0.0, "splash": 0.0, "dive": false, "pierce": 0, "haste": haste, "affixes": b.affixes.duplicate(),
		"evolved": sp.kind != Content.BUILDINGS[b.kind].nest}
	for a in b.affixes:
		if a in sp.used:
			continue
		var af: Dictionary = Content.AFFIXES[a]
		s.atk_bonus = int(s.atk_bonus) + int(af.get("atk", 0))
		s.armor = int(s.armor) + int(af.get("armor", 0))
		s.range = maxf(float(s.range), float(af.get("range", 0.0)))
		s.splash = float(s.splash) + float(af.get("splash", 0.0))
		s.dive = bool(s.dive) or bool(af.get("dive", false))
		s.pierce = int(s.pierce) + int(af.get("pierce", 0))
	return s


## How many affixes the nest at p can carry: one, more beside stabilizers.
func slots(p: Vector2i) -> int:
	var n := 1
	for q in around(p):
		if buildings.has(q) and buildings[q].kind == "stabilizer":
			n += int(_level(buildings[q]).slots)
	return n


# -- Buying, keeping, putting down ------------------------------------------------------------------------

## What shelf[i] costs in gold -- on `at`, for a raise (more for a higher building).
func price(i: int, at: Variant = null) -> int:
	var o := Content.offer(shelf[i])
	match o.type:
		"build":
			return maxi(1, int(o.price) - (1 if "wood" in relics else 0))
		"raise":
			var lv := int(buildings[at].level) if at is Vector2i and buildings.has(at) else 1
			return _raise_price(lv)
	return int(o.price)


## Whether shelf[i] can be paid for (genes and alien genes too; for a raise, on the cheapest building).
func affordable(i: int) -> bool:
	if i < 0 or i >= shelf.size() or shelf[i] == null:
		return false
	var o := Content.offer(shelf[i])
	if genes < int(o.get("genes", 0)) or alien < int(o.get("alien", 0)):
		return false
	return gold >= (_least_price(o.id) if o.type == "raise" else price(i))


## Where shelf[i] can go and be paid for: plots (Vector2i) for build, raise and affix. [] when it cannot be bought now.
func targets(i: int) -> Array:
	if not affordable(i):
		return []
	var fits := _fits(shelf[i])
	var o := Content.offer(shelf[i])
	if o.type == "raise":
		fits = fits.filter(func(p: Vector2i) -> bool: return gold >= price(i, p))
	return fits


## Where stash[k] can be put down (it is paid for already).
func stash_targets(k: int) -> Array:
	if k < 0 or k >= stash.size():
		return []
	return _fits(stash[k])


## Whether shelf[i] can be bought into the stash: a building or an affix (what is put somewhere), paid for, and room.
func can_store(i: int) -> bool:
	return affordable(i) and stash.size() < stash_size() and Content.offer(shelf[i]).type in ["build", "affix"]


## Where a good can go, whoever pays: plots for build, raise and affix; [] for none.
func _fits(oi: Dictionary) -> Array:
	var o := Content.offer(oi)
	match o.target:
		"tile":
			return _plots_all().filter(func(p: Vector2i) -> bool:
				return buildable(p) and (not buildings.has(p) or buildings[p].kind != o.builds or oi.has("packed")))
		"building":
			return _plots().filter(func(p: Vector2i) -> bool: return int(buildings[p].level) < Content.LEVEL_MAX)
		"nest":
			return _plots().filter(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not o.affix in b.affixes and b.affixes.size() < slots(p))
	return []


## Buys shelf[i] for `at` (a plot). Its events; [] if it could not be bought.
func buy(i: int, at: Variant) -> Array:
	var fits := targets(i)
	if fits.is_empty() or not at in fits:
		return []
	var o := Content.offer(shelf[i])
	_pay(i, at)
	var oi: Dictionary = shelf[i]
	shelf[i] = null
	return [{"t": "bought", "offer": o.id}] + _apply(oi, at)


## Buys shelf[i] into the stash, to be put down later. Its events; [] if it could not be.
func store(i: int) -> Array:
	if not can_store(i):
		return []
	var o := Content.offer(shelf[i])
	_pay(i, null)
	stash.append(shelf[i])
	shelf[i] = null
	return [{"t": "stored", "offer": o.id}]


## Puts stash[k] down at `at`. Its events; [] if it could not go there.
func place(k: int, at: Variant) -> Array:
	var fits := stash_targets(k)
	if fits.is_empty() or not at in fits:
		return []
	var oi: Dictionary = stash[k]
	var o := Content.offer(oi)
	stash.remove_at(k)
	return [{"t": "placed", "offer": o.id}] + _apply(oi, at)


## A good kept, at the end of the stash -- the oldest one going if there is no room. Whether one went.
func keep(oi: Dictionary) -> bool:
	stash.append(oi)
	if stash.size() > stash_size():
		stash.pop_front()
		return true
	return false


func _pay(i: int, at: Variant) -> void:
	var o := Content.offer(shelf[i])
	gold -= price(i, at)
	genes -= int(o.get("genes", 0))
	alien -= int(o.get("alien", 0))


func _apply(oi: Dictionary, at: Variant) -> Array:
	var o := Content.offer(oi)
	var ev: Array = []
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
			if oi.has("packed"):
				var max_was := hp_max()
				buildings[at].level = int(oi.packed.level)
				buildings[at].affixes = oi.packed.affixes.duplicate()
				hp += maxi(0, hp_max() - max_was)
		"raise":
			var b: Dictionary = buildings[at]
			var max_was := hp_max()
			b.level = mini(Content.LEVEL_MAX, int(b.level) + 1)
			hp += maxi(0, hp_max() - max_was)
			ev.append({"t": "raised", "at": at})
		"affix":
			buildings[at].affixes.append(o.affix)
			ev.append({"t": "affixed", "at": at, "affix": o.affix})
	return ev


## The building at p as a good to carry: its offer, with its level and affixes.
func packed(p: Vector2i) -> Dictionary:
	var b: Dictionary = buildings[p]
	for id in Content.OFFERS:
		if Content.OFFERS[id].get("builds", "") == b.kind:
			return {"id": id, "packed": {"level": int(b.level), "affixes": b.affixes.duplicate()}}
	return {}


## A building put up at p (whatever was there pulled down), at level 1. The homeland's hit points follow its walls.
func build(p: Vector2i, kind: String) -> void:
	var max_was := hp_max()
	var b := {"id": _id(), "kind": kind, "level": 1, "affixes": []}
	buildings[p] = b
	hp = mini(hp_max(), hp + maxi(0, hp_max() - max_was))


## A copy to try a good on (the forecast): the same homeland, nothing shared.
func clone() -> Home:
	var h := Home.new(RandomNumberGenerator.new())
	h.region = region
	h.buildings = buildings.duplicate(true)
	h.terrain = terrain.duplicate()
	h.gold = gold
	h.biomass = biomass
	h.genes = genes
	h.alien = alien
	h.hp = hp
	h.relics = relics.duplicate()
	h.shelf = shelf.duplicate(true)
	h.stash = stash.duplicate(true)
	h.rerolls = rerolls
	h.next_id = next_id
	return h


func is_open(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS


## Whether a building can stand at p: on the grid, and not on ground nothing can be built on.
func buildable(p: Vector2i) -> bool:
	return is_open(p) and bool(Content.TERRAIN.get(terrain.get(p, ""), {"build": true}).build)


# -- What the homeland comes to ---------------------------------------------------------------------------

func income_gold() -> int:
	var n := INCOME + _sum("gold") + (4 if "crystal" in relics else 0)
	for p in buildings:
		if terrain.get(p, "") == "ore" and int(_level(buildings[p]).get("gold", 0)) > 0:
			n += 2
	return n


func income_biomass() -> int:
	var n := 0
	for p in buildings:
		var b := int(_level(buildings[p]).get("biomass", 0))
		n += b * (2 if terrain.get(p, "") == "pond" else 1)
	n += 3 if "coprolite" in relics else 0
	if rule() == "damp":
		n = n * 3 / 2
	if "core" in relics:
		n = n * 7 / 10
	return n


func income_genes() -> int:
	var n := _sum("genes")
	for p in buildings:
		if buildings[p].kind == "sampler":
			for q in around(p):
				if buildings.has(q) and buildings[q].kind == "pool":
					n += Content.SAMPLER_POOL
	return n


func biomass_max() -> int:
	return BIOMASS_MAX


func genes_max() -> int:
	return GENES_MAX


func hp_max() -> int:
	return HP + _sum("wall")


## How much less harm a lost battle does: each wall's block, more for each wall beside it.
func block() -> int:
	var n := 0
	for p in buildings:
		var l := _level(buildings[p])
		if not l.has("block"):
			continue
		n += int(l.block)
		for q in around(p):
			if buildings.has(q) and _level(buildings[q]).has("block"):
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
