class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 17-22): wherever the ark has landed, a grid of plots -- the top rows the battle line,
## for nests only, where each nest's units will stand in battle; the rows behind for everything else, special ground
## among them -- with the gold and the other resources, the shop's shelf, the goods kept for later (the stash), the
## relics, the wonder, and the homeland's own hit points. One round here: the buildings bring in gold, biomass and
## genes and the shelf is stocked (start_round); the player buys -- buildings, raises, affixes -- puts goods down from
## the stash, takes a kind out of the shop, builds the wonder; then the nests make this round's army, paying biomass
## (produce), and it goes out to fight (Fight). The army lives for that battle only. Gold kept to the round's end earns
## interest. When a place is held, the ark moves on (land): the buildings stay behind but for those packed into the
## stash.
##
## Neighbours are the four plots up, down, left and right; a column, the plots one above another. Plain data and
## rules, nothing on screen: the same rules for the game and for its tests.
##
## A building: {id, kind, level, path, affixes: [ids]} -- path: a nest's raises, each "count" or "elite".
## A good (shelf or stash): {id, plus, packed: {level, path, affixes}} (Content.offer), or null on the shelf where one
##   was bought. A card of the deck (牌库) the shelf is drawn from: {id, plus} -- plus: upgraded.
## A unit (army): {id: "nest id:n", kind, nest: plot, row, lane, slot, of, hp_mult, atk_mult, atk_bonus, armor, range,
##   splash, dive, pierce, haste, charge, size_mult, elite, affixes, guard, care, scavenge, free} -- row, lane: where it
##   stands in battle (row 0 in front; lane its column); slot, of: which of its nest's it is, of how many; guard, care,
##   scavenge: its nest's gift, where it works in battle (Content.TRAITS, Fight); free: eating nothing.
## Events (for the screen): bought {offer}, stored {offer}, placed {offer}, built {at}, replaced {at, was, back},
## raised {at, choice}, affixed {at, affix}, wonder {id}, income {gold, biomass, genes}, rotted {amount}, ash {amount},
## mended {amount}.

const COLS := 6
const ROWS := 4
const INCOME := 5                 # gold each round
const BIOMASS_MAX := 20
const GENES_MAX := 10
const HP := 30
const NOWHERE := Vector2i(-1, -1)
## Where the ark sets things down, first to last: its nests in the middle of the battle line, the rest just behind it.
const LANDING_FRONT := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 0), Vector2i(4, 0),
	Vector2i(1, 1), Vector2i(4, 1), Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 1), Vector2i(5, 1)]
const LANDING_BACK := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(1, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(1, 3), Vector2i(4, 3), Vector2i(0, 2), Vector2i(5, 2), Vector2i(0, 3), Vector2i(5, 3)]

var region := 0                   # the place (Content.LEVELS) the ark has landed in
var buildings := {}               # Vector2i -> building
var terrain := {}                 # Vector2i -> special ground (Content.TERRAIN)
var gold := 0
var biomass := 0
var genes := 0                    # research points (研究点数): for affixes and upgrading cards
var hp := HP
var relics: Array = []            # relic ids
var deck: Array = []              # the cards the shop draws from: {id, plus}
var cuts := 0                     # cards cut from the deck so far (each costs more)
var shelf: Array = []             # offers, or null where bought
var stash: Array = []             # goods kept for later
var rerolls := 0                  # times the shelf was stocked again this round
var wonders: Array = []           # the wonders on offer this run (Content.WONDERS ids)
var wonder := ""                  # the one built, "" until then
var flood := false                # the coast at high tide this round: the last row brings in nothing
var next_id := 1


func _init(rng: RandomNumberGenerator) -> void:
	gold = int(Content.FIRST_STOCK.gold)
	biomass = int(Content.FIRST_STOCK.biomass)
	genes = int(Content.FIRST_STOCK.genes)
	deck = Content.DECK.map(func(id: String) -> Dictionary: return {"id": id, "plus": false})
	land(0, rng, Content.LANDING)


## The ark lands in place `r`: the old buildings are left behind, the special ground of the new place lies about
## behind the battle line, and the ark sets down `kit` ([kind, level] each) -- nests in the middle of the battle line,
## the rest just behind it. What is in the stash comes along, and the wonder.
func land(r: int, rng: RandomNumberGenerator, kit: Array) -> void:
	region = r
	buildings.clear()
	terrain.clear()
	var plots := _plots_all().filter(func(p: Vector2i) -> bool: return not front(p) and not p in LANDING_BACK.slice(0, 3))
	shuffle(plots, rng)
	var lie: Dictionary = Content.LEVELS[r].terrain
	for kind in lie:
		for k in int(lie[kind]):
			if not plots.is_empty():
				terrain[plots.pop_back()] = kind
	for item in kit:
		var p := _free_landing(item[0])
		if p != NOWHERE:
			build(p, item[0])
			_set_level(p, int(item[1]))
	hp = mini(hp, hp_max())
	shelf = []


func _free_landing(kind: String) -> Vector2i:
	var order: Array = LANDING_FRONT if Content.is_nest(kind) else LANDING_BACK
	for p in order:
		if buildable(p) and not buildings.has(p):
			return p
	return NOWHERE


## The building at p made level `lv` at once -- a nest by making one more a round at each level.
func _set_level(p: Vector2i, lv: int) -> void:
	var b: Dictionary = buildings[p]
	b.level = clampi(lv, 1, Content.LEVEL_MAX)
	b.path = []
	if Content.is_nest(b.kind):
		for k in int(b.level) - 1:
			b.path.append("count")


# -- A round ----------------------------------------------------------------------------------------------

## The place has its way (damp: stored biomass rots; ash falls); the buildings bring in what they make; the frill
## mends; the shelf is stocked afresh from the deck.
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
	if "frill" in relics and hp < hp_max():
		var before := hp
		hp = mini(hp_max(), hp + 1)
		ev.append({"t": "mended", "amount": hp - before})
	rerolls = 0
	stock(rng, level)
	return ev


func rule() -> String:
	return str(Content.LEVELS[region].get("rule", ""))


## Stocks the shelf from the deck: buildings by how much land is free (more when there is much; one when there is
## none, to pull something down for), then raises and affixes -- each card at most once, only those that can be used
## now and are found here, no more than one that costs more gold than there is.
func stock(rng: RandomNumberGenerator, level: int) -> void:
	var free := _plots_all().filter(func(p: Vector2i) -> bool: return buildable(p) and not buildings.has(p)).size()
	var builds := clampi(ceili(free / 3.0), 1, 3)
	var size := shelf_size()
	var build_pool: Array = []    # indices into the deck
	var other_pool: Array = []
	for k in deck.size():
		if _here(deck[k].id, level):
			(build_pool if Content.OFFERS[deck[k].id].type == "build" else other_pool).append(k)
	shelf = []
	var taken := {}
	var dear := 1                 # how many more that cost more than there is may go up
	for pool in [[build_pool, builds], [other_pool, size - builds]]:
		var cards: Array = pool[0]
		shuffle(cards, rng)
		var want: int = pool[1]
		for k in cards:
			if want <= 0:
				break
			if _least_price(deck[k]) > gold:
				if dear <= 0:
					continue
				dear -= 1
			taken[k] = true
			shelf.append(_good(deck[k]))
			want -= 1
	# Not enough that could be used: fill with what is left.
	for pool in [build_pool, other_pool]:
		for k in pool:
			if shelf.size() >= size:
				break
			if not taken.has(k):
				taken[k] = true
				shelf.append(_good(deck[k]))


## A card of the deck as a good on the shelf.
static func _good(card: Dictionary) -> Dictionary:
	return {"id": card.id, "plus": true} if card.get("plus", false) else {"id": card.id}


## Whether the shop can offer card `id` here and now: not from a later place, not another place's own, of use now.
func _here(id: String, level: int) -> bool:
	var o: Dictionary = Content.OFFERS[id]
	return int(o.get("from", 0)) <= level and int(o.get("region", region)) == region and _useful(id)


## The least a good can cost now (a raise: on the lowest building).
func _least_price(oi: Dictionary) -> int:
	var o := Content.offer(oi)
	match o.type:
		"build":
			return maxi(1, int(o.price) - _discount())
		"raise":
			var lv := Content.LEVEL_MAX
			for p in _plots():
				lv = mini(lv, int(buildings[p].level))
			return maxi(1, _raise_price(lv) - (Content.PLUS_RAISE if o.plus else 0))
	return int(o.price)


# -- The deck ----------------------------------------------------------------------------------------------------

## What cutting a card from the deck costs now: CUT gold, CUT_STEP more for each cut before.
func cut_price() -> int:
	return Content.CUT + cuts * Content.CUT_STEP


## Cuts deck[k], paying for it. Whether it was.
func cut(k: int) -> bool:
	if k < 0 or k >= deck.size() or gold < cut_price():
		return false
	gold -= cut_price()
	deck.remove_at(k)
	cuts += 1
	return true


## Whether deck[k] can be upgraded: not yet, and the research points for it.
func can_upgrade(k: int) -> bool:
	return k >= 0 and k < deck.size() and not deck[k].get("plus", false) and genes >= Content.UPGRADE


## Upgrades deck[k] (+), paying research points. Whether it was.
func upgrade(k: int) -> bool:
	if not can_upgrade(k):
		return false
	genes -= Content.UPGRADE
	deck[k].plus = true
	return true


func _raise_price(level: int) -> int:
	return maxi(1, Content.RAISE + level - (1 if rule() == "ash" else 0))


func _discount() -> int:
	return 1 if "wood" in relics else 0


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
	return Content.SHOP + (1 if "amber" in relics else 0) + _sum("shelf") - (1 if "crystal" in relics else 0)


func stash_size() -> int:
	return Content.STASH + (2 if "sac" in relics else 0)


func reroll_price() -> int:
	var free := (1 if "trilobite" in relics else 0) + _sum("rerolls")
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
	return Content.INTEREST_MAX + (2 if "ammonite" in relics else 0) + _sum("interest")


# -- This round's army ------------------------------------------------------------------------------------

## This round's army as things stand: each nest, in reading order, makes its count (one more for a red nest swarming,
## one more for the first with the egg relic, one more each with the core and the brood wonder), each unit paid for in
## biomass as far as the biomass goes -- the one the egg makes eats nothing; the titan, with its wonder, in the middle
## of the front row; and then, with horde totems, every unit hits harder for how many there are.
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
		var made: Array = []
		for i in paid + extra:
			var free := i >= paid
			if not free:
				if food < cost:
					continue
				food -= cost
			var u := spec.duplicate()
			u.id = "%d:%d" % [b.id, i]
			u.free = free
			made.append(u)
		for k in made.size():
			made[k].slot = k
			made[k].of = made.size()
		out.append_array(made)
	if wonder == "titan":
		out.append({"id": "titan:0", "kind": "titan", "nest": NOWHERE, "row": 0, "lane": (COLS - 1) * 0.5, "slot": 0,
			"of": 1, "hp_mult": 1.0, "atk_mult": 1.0, "atk_bonus": 0, "armor": 0, "range": 0.0, "splash": 0.0,
			"dive": false, "pierce": 0, "haste": 0, "charge": false, "size_mult": 1.0, "elite": 0, "affixes": [],
			"evolved": false, "free": true})
	var horde := horde_bonus(out.size())
	if horde > 0:
		for u in out:
			u.atk_bonus = int(u.atk_bonus) + horde
	return out


## The attack every unit gets with an army of n: +1 for every so many units, for each horde totem.
func horde_bonus(n: int) -> int:
	var k := 0
	for p in buildings:
		if buildings[p].kind == "horde_totem":
			k += n / int(_level(buildings[p]).per)
	return k


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


## How many the nest at p makes a round (before biomass and the egg): one, one more for each raise chosen so, one more
## for a red nest swarming (its gift: CLUSTER red nests beside it), one more with the core, one more with the brood
## wonder.
func count(p: Vector2i) -> int:
	var b: Dictionary = buildings[p]
	return 1 + b.path.count("count") + (1 if trait_of(p) == "swarm" and trait_on(p) else 0) \
		+ (1 if "core" in relics else 0) + (1 if wonder == "brood" else 0)


## The gift (Content.TRAITS) of the nest at p, or "".
func trait_of(p: Vector2i) -> String:
	if not buildings.has(p) or not Content.is_nest(buildings[p].kind):
		return ""
	return str(Content.BUILDINGS[buildings[p].kind].trait)


## Whether the nest at p stands where its gift works: swarming with CLUSTER of its kind beside it; guarding in the
## front row; under cover in the second row with a nest in front of it; alone with no nest left or right of it. The
## others work anywhere.
func trait_on(p: Vector2i) -> bool:
	match trait_of(p):
		"":
			return false
		"swarm":
			return _beside(p, around(p)) >= Content.CLUSTER
		"guard":
			return p.y == 0
		"cover":
			return p.y == 1 and buildings.has(Vector2i(p.x, 0))
		"alone":
			return _beside(p, [p + Vector2i.LEFT, p + Vector2i.RIGHT], true) == 0
	return true


## What the nest at p lacks for its gift to work, in the player's words ("" when it works).
func trait_need(p: Vector2i) -> String:
	if trait_on(p) or trait_of(p) == "":
		return ""
	match trait_of(p):
		"swarm":
			return "还差 %d 个红巢挨着" % (Content.CLUSTER - _beside(p, around(p)))
		"guard":
			return "要站第一排"
		"cover":
			return "要站第二排" if p.y == 0 else "身前同一列还没有巢"
		"alone":
			return "左右有巢挨着"
	return ""


## How many of `plots` hold a nest of the same kind as p's -- or, with `any`, any nest.
func _beside(p: Vector2i, plots: Array, any := false) -> int:
	var n := 0
	for q in plots:
		if buildings.has(q) and (Content.is_nest(buildings[q].kind) if any else buildings[q].kind == buildings[p].kind):
			n += 1
	return n


## What the nest at p gives each unit it makes: the species its affixes make of it, where it stands, how elite it is,
## its other affixes -- the only things that make a unit itself stronger -- its gift where it works, and what the
## homeland's schools give units of its kind: the champion halls elites, the vanguard camps the front row, the
## watchtowers those that reach far, the banner wonder all.
func spec_of(p: Vector2i) -> Dictionary:
	var b: Dictionary = buildings[p]
	var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
	var e: int = b.path.count("elite")
	var s := {"kind": sp.kind, "nest": p, "row": p.y, "lane": float(p.x), "hp_mult": pow(Content.ELITE_HP, e),
		"atk_mult": pow(Content.ELITE_ATK, e), "atk_bonus": 0, "armor": 0, "range": 0.0, "splash": 0.0, "dive": false,
		"pierce": 0, "haste": 0, "charge": false, "size_mult": pow(Content.ELITE_SIZE, e), "elite": e,
		"affixes": b.affixes.duplicate(), "evolved": sp.kind != Content.BUILDINGS[b.kind].nest,
		"guard": false, "care": false, "scavenge": false}
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
		s.haste = int(s.haste) + int(af.get("haste", 0))
		s.charge = bool(s.charge) or bool(af.get("charge", false))
		s.hp_mult = float(s.hp_mult) * (1.0 + float(af.get("hp", 0)) / 100.0)
	var gift := trait_of(p)
	var on := trait_on(p)
	s.guard = gift == "guard" and on
	s.care = gift == "care"
	s.scavenge = gift == "scavenge"
	var reach := maxf(float(Content.UNITS[sp.kind].range), float(s.range))
	if gift == "cover" and on and reach >= 3.0:
		s.range = reach + Content.COVER_RANGE
		s.pierce = int(s.pierce) + Content.COVER_PIERCE
	if gift == "alone" and on:
		s.hp_mult = float(s.hp_mult) * Content.ALONE
		s.atk_mult = float(s.atk_mult) * Content.ALONE
		s.size_mult = float(s.size_mult) * Content.ALONE_SIZE
	if e > 0:
		var more := 1.0 + _sum("elite") / 100.0
		s.hp_mult = float(s.hp_mult) * more
		s.atk_mult = float(s.atk_mult) * more
	if p.y == 0:
		s.hp_mult = float(s.hp_mult) * (1.0 + _sum("front") / 100.0)
	if maxf(float(Content.UNITS[sp.kind].range), float(s.range)) >= 3.0:
		s.pierce = int(s.pierce) + _sum("ranged")
	if wonder == "banner":
		s.atk_bonus = int(s.atk_bonus) + 2
		s.hp_mult = float(s.hp_mult) * 1.25
	match rule():
		"bog":
			s.hp_mult = float(s.hp_mult) * Content.BOG_HP
		"cold":
			s.haste = int(s.haste) + Content.COLD_HASTE
	return s


## How many affixes the nest at p can carry: one, more for each stabilizer in its column, one more with the heart and
## with the tower of evolution, more for a mutant nest.
func slots(p: Vector2i) -> int:
	var n := 1 + (1 if "heart" in relics else 0) + (1 if wonder == "evo_tower" else 0) \
		+ (Content.MUTANT_SLOTS if trait_of(p) == "mutant" else 0)
	for y in ROWS:
		var q := Vector2i(p.x, y)
		if buildings.has(q) and buildings[q].kind == "stabilizer":
			n += int(_level(buildings[q]).slots)
	return n


# -- Buying, keeping, putting down ------------------------------------------------------------------------

## What shelf[i] costs in gold -- on `at`, for a raise (more for a higher building).
func price(i: int, at: Variant = null) -> int:
	var o := Content.offer(shelf[i])
	match o.type:
		"build":
			return maxi(1, int(o.price) - _discount())
		"raise":
			var lv := int(buildings[at].level) if at is Vector2i and buildings.has(at) else 1
			return maxi(1, _raise_price(lv) - (Content.PLUS_RAISE if o.plus else 0))
	return int(o.price)


## The research points an offer costs here: an affix's (none upgraded), less the gene banks' and the tooth's -- none
## with the tower of evolution.
func genes_cost(o: Dictionary) -> int:
	if o.type != "affix" or wonder == "evo_tower":
		return 0
	return maxi(0, int(o.get("genes", 0)) - _sum("gene_off") - (1 if "tooth" in relics else 0))


## Whether shelf[i] can be paid for (research points too; for a raise, on the cheapest building).
func affordable(i: int) -> bool:
	if i < 0 or i >= shelf.size() or shelf[i] == null:
		return false
	var o := Content.offer(shelf[i])
	if genes < genes_cost(o):
		return false
	return gold >= (_least_price(shelf[i]) if o.type == "raise" else price(i))


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


## Whether shelf[i] can be bought into the stash: a building or an affix (what is put somewhere), paid for (a gold
## more than putting it down now: store_price), and room.
func can_store(i: int) -> bool:
	return affordable(i) and stash.size() < stash_size() and Content.offer(shelf[i]).type in ["build", "affix"] \
		and gold >= store_price(i)


## What keeping shelf[i] for later costs: its price and Content.STORE_EXTRA more.
func store_price(i: int) -> int:
	return price(i) + Content.STORE_EXTRA


## Where a good can go, whoever pays: a building on a plot of its part of the homeland (a nest on the battle line,
## anything else behind it); a raise on a building below the top level; an affix on a nest with a place for it.
func _fits(oi: Dictionary) -> Array:
	var o := Content.offer(oi)
	match o.target:
		"tile":
			var nest := Content.is_nest(o.builds)
			return _plots_all().filter(func(p: Vector2i) -> bool:
				return buildable(p) and front(p) == nest and (not buildings.has(p) or buildings[p].kind != o.builds or oi.has("packed")))
		"building":
			return _plots().filter(func(p: Vector2i) -> bool: return int(buildings[p].level) < Content.LEVEL_MAX)
		"nest":
			return _plots().filter(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not o.affix in b.affixes and b.affixes.size() < slots(p))
	return []


## Buys shelf[i] for plot `at` -- a nest's raise as `choice`, "count" or "elite". Its events; [] if it could not be
## bought.
func buy(i: int, at: Variant, choice := "count") -> Array:
	var fits := targets(i)
	if fits.is_empty() or not at in fits:
		return []
	var o := Content.offer(shelf[i])
	_pay(i, at)
	var oi: Dictionary = shelf[i]
	shelf[i] = null
	return [{"t": "bought", "offer": o.id}] + _apply(oi, at, choice)


## Buys shelf[i] into the stash, to be put down later. Its events; [] if it could not be.
func store(i: int) -> Array:
	if not can_store(i):
		return []
	var o := Content.offer(shelf[i])
	_pay(i, null)
	gold -= Content.STORE_EXTRA
	stash.append(shelf[i])
	shelf[i] = null
	return [{"t": "stored", "offer": o.id}]


## Puts stash[k] down at `at` (a nest's raise as `choice`). Its events; [] if it could not go there.
func place(k: int, at: Variant, choice := "count") -> Array:
	var fits := stash_targets(k)
	if fits.is_empty() or not at in fits:
		return []
	var oi: Dictionary = stash[k]
	var o := Content.offer(oi)
	stash.remove_at(k)
	return [{"t": "placed", "offer": o.id}] + _apply(oi, at, choice)


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
	genes -= genes_cost(o)


func _apply(oi: Dictionary, at: Variant, choice: String) -> Array:
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
				buildings[at].level = int(oi.packed.level)
				buildings[at].path = oi.packed.get("path", []).duplicate()
				buildings[at].affixes = oi.packed.affixes.duplicate()
			elif o.plus:
				buildings[at].level = 2
				if Content.is_nest(o.builds):
					buildings[at].path = ["elite" if choice == "elite" else "count"]
		"raise":
			var b: Dictionary = buildings[at]
			if Content.is_nest(b.kind):
				b.path.append("elite" if choice == "elite" else "count")
			b.level = mini(Content.LEVEL_MAX, int(b.level) + 1)
			ev.append({"t": "raised", "at": at, "choice": choice if Content.is_nest(b.kind) else ""})
		"affix":
			buildings[at].affixes.append(o.affix)
			ev.append({"t": "affixed", "at": at, "affix": o.affix})
	return ev


## The building at p as a good to carry: its offer, with its level, its nest's choices and its affixes.
func packed(p: Vector2i) -> Dictionary:
	var b: Dictionary = buildings[p]
	for id in Content.OFFERS:
		if Content.OFFERS[id].get("builds", "") == b.kind:
			return {"id": id, "packed": {"level": int(b.level), "path": b.path.duplicate(), "affixes": b.affixes.duplicate()}}
	return {}


## A building put up at p (whatever was there pulled down), at level 1.
func build(p: Vector2i, kind: String) -> void:
	buildings[p] = {"id": _id(), "kind": kind, "level": 1, "path": [], "affixes": []}


## Whether wonder `id` can be built now: one of those on offer, none built yet, and the gold for it.
func can_build_wonder(id: String) -> bool:
	return wonder == "" and id in wonders and gold >= int(Content.WONDERS[id].price)


## Builds wonder `id`. Its events; [] if it could not be.
func build_wonder(id: String) -> Array:
	if not can_build_wonder(id):
		return []
	gold -= int(Content.WONDERS[id].price)
	wonder = id
	return [{"t": "wonder", "id": id}]


## A copy to try a good on (the forecast): the same homeland, nothing shared.
func clone() -> Home:
	var h := Home.new(RandomNumberGenerator.new())
	h.region = region
	h.buildings = buildings.duplicate(true)
	h.terrain = terrain.duplicate()
	h.gold = gold
	h.biomass = biomass
	h.genes = genes
	h.hp = hp
	h.relics = relics.duplicate()
	h.deck = deck.duplicate(true)
	h.cuts = cuts
	h.flood = flood
	h.shelf = shelf.duplicate(true)
	h.stash = stash.duplicate(true)
	h.rerolls = rerolls
	h.wonders = wonders.duplicate()
	h.wonder = wonder
	h.next_id = next_id
	return h


func is_open(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS


## Whether p is on the battle line (the top Content.FRONT_ROWS rows): nests only.
static func front(p: Vector2i) -> bool:
	return p.y < Content.FRONT_ROWS


## Whether a building can stand at p: on the grid, and not on ground nothing can be built on.
func buildable(p: Vector2i) -> bool:
	return is_open(p) and bool(Content.TERRAIN.get(terrain.get(p, ""), {"build": true}).build)


# -- What the homeland comes to ---------------------------------------------------------------------------

func income_gold() -> int:
	var n := INCOME + (4 if "crystal" in relics else 0) + (6 if wonder == "gold_city" else 0) \
		+ (Content.COLD_GOLD if rule() == "cold" else 0)
	for p in _working():
		var g := int(_level(buildings[p]).get("gold", 0))
		if g <= 0:
			continue
		n += g + (2 if _like(p) == "ore" else 0)
		for q in around(p):
			if _like(q) == "lava":
				n += Content.LAVA_GOLD
	return n


func income_biomass() -> int:
	var n := 0
	for p in _working():
		var b := int(_level(buildings[p]).get("biomass", 0))
		n += b * (2 if _like(p) == "pond" else 1)
	n += 3 if "coprolite" in relics else 0
	if rule() in ["damp", "bog"]:
		n = n * 3 / 2
	elif rule() == "drought":
		n = int(n * Content.DROUGHT_BIOMASS)
	if "core" in relics:
		n = n * 7 / 10
	return n


func income_genes() -> int:
	var n := Content.DROUGHT_GENES if rule() == "drought" else 0
	for p in _working():
		n += int(_level(buildings[p]).get("genes", 0))
		if buildings[p].kind == "sampler":
			for q in around(p):
				if buildings.has(q) and buildings[q].kind == "pool":
					n += Content.SAMPLER_POOL
				if _like(q) == "tree":
					n += Content.TREE_GENES
	return n


## The plots whose buildings bring in what they make this round -- all but the last row at the coast's high tide.
func _working() -> Array:
	return buildings.keys().filter(func(p: Vector2i) -> bool: return not (flood and p.y == ROWS - 1))


## Which of the four ways the special ground at p works (Content.TERRAIN like), or "".
func _like(p: Vector2i) -> String:
	return str(Content.TERRAIN[terrain[p]].get("like", terrain[p])) if terrain.has(p) else ""


func biomass_max() -> int:
	return BIOMASS_MAX


func genes_max() -> int:
	return GENES_MAX


func hp_max() -> int:
	return HP + (10 if "frill" in relics else 0)


## The battle's lost: the homeland takes the harm. What it took.
func harmed(harm: int) -> int:
	var took := maxi(0, harm)
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


## What the homeland's buildings give of `key` all told.
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
