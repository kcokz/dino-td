class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 17-24): wherever the ark has landed, a grid of plots -- the top rows the battle line,
## for nests only, where each nest's units will stand in battle; the rows behind for everything else, special ground
## among them -- with the gold and the other resources, the shop's shelf, the star dinosaurs in their pens (and the
## goods the hoarder keeps for later, the stash), and the homeland's own hit points. One round here: the buildings
## bring in biomass, the stars eat, gold and genes come in, and the shelf is stocked (start_round); the player buys --
## buildings, raises, affixes, a star -- puts goods down from the stash, takes a kind out of the shop; then the nests
## make this round's army, paying biomass (produce), and it goes out to fight (Fight). The army lives for that battle
## only. Gold kept to the round's end earns interest. When a place is held, the ark moves on (land): the buildings stay
## behind but for those it carries, which it sets down in the new place; the stars go with it.
##
## Neighbours are the four plots up, down, left and right; a column, the plots one above another. Plain data and
## rules, nothing on screen: the same rules for the game and for its tests.
##
## A building: {id, kind, level, path, affixes: [ids]} -- path: a nest's raises, each "count" or "elite".
## A good (shelf or stash): {id, plus} (Content.offer), or null on the shelf where one
##   was bought. A card of the deck (牌库) the shelf is drawn from: {id, plus} -- plus: upgraded.
## A unit (army): {id: "nest id:n", kind, nest: plot, row, lane, slot, of, hp_mult, atk_mult, atk_bonus, armor, range,
##   splash, dive, pierce, haste, charge, size_mult, elite, affixes, guard, care, scavenge, free} -- row, lane: where it
##   stands in battle (row 0 in front; lane its column); slot, of: which of its nest's it is, of how many; guard, care,
##   scavenge: its nest's gift, where it works in battle (Content.TRAITS, Fight); free: eating nothing.
## Events (for the screen): bought {offer}, stored {offer}, placed {offer}, built {at}, replaced {at, was, back},
## raised {at, choice}, affixed {at, affix}, star {id}, sold {id, gold}, fed {ate, hungry: [ids]}, income {gold,
## biomass, genes}, ash {amount}, mended {amount}.
## A star dinosaur (in a pen): {id, grow} -- grow: what it has grown to (Content.STARS grow_boss, grow_round).

const COLS := 6
const ROWS := 4
const INCOME := 5                 # gold each round

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
var stars: Array = []             # the star dinosaurs, a pen each, in order: {id, grow}
var hungry: Array = []            # the pens whose stars went without this round (doing nothing till the next)
var star_offer := ""              # the star dinosaur on offer after the shelf, "" when none (or bought)
var deck: Array = []              # the cards the shop draws from: {id, plus}
var cuts := 0                     # cards cut from the deck so far (each costs more)
var shelf: Array = []             # offers, or null where bought
var stash: Array = []             # goods kept for later (by the hoarder)
var rerolls := 0                  # times the shelf was stocked again this round
var next_id := 1


func _init(rng: RandomNumberGenerator) -> void:
	gold = int(Content.FIRST_STOCK.gold)
	biomass = int(Content.FIRST_STOCK.biomass)
	genes = int(Content.FIRST_STOCK.genes)
	deck = Content.DECK.map(func(id: String) -> Dictionary: return {"id": id, "plus": false})
	land(0, rng, Content.LANDING)


## The homeland made in place `r`: the old buildings are left behind, the special ground of the new place lies about
## behind the battle line, and `kit` ([kind, level] each) is set down -- nests in the middle of the battle line, the
## rest just behind it. The stars come along, and what the hoarder keeps.
func land(r: int, rng: RandomNumberGenerator, kit: Array) -> void:
	region = r
	buildings.clear()
	terrain.clear()
	var plots := _plots_all().filter(func(p: Vector2i) -> bool: return not front(p) and not p in LANDING_BACK.slice(0, 3))
	shuffle(plots, rng)
	hungry = []
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

## The buildings bring in biomass; the stars eat (feed) and grow; gold and genes come in -- what the fed stars bring
## with them; the sickle costs the homeland a hit point; the shield mends; the shelf is stocked afresh from the deck, a
## star after it.
func start_round(rng: RandomNumberGenerator, level: int) -> Array:
	var ev: Array = []
	var b := income_biomass()
	biomass += b
	ev.append_array(feed())
	for k in stars.size():
		var info: Dictionary = Content.STARS[stars[k].id]
		if not k in hungry and info.has("grow_round"):
			stars[k].grow = mini(int(info.grow_max), int(stars[k].grow) + int(info.grow_round))
	var g := income_gold()
	var n := income_genes()
	gold += g
	genes += n
	ev.append({"t": "income", "gold": g, "biomass": b, "genes": n})
	var ash := _star("ash")
	if ash > 0:
		var before := hp
		hp = maxi(1, hp - ash)
		ev.append({"t": "ash", "amount": before - hp})
	if _star("mend") > 0 and hp < hp_max():
		var before := hp
		hp = mini(hp_max(), hp + _star("mend"))
		ev.append({"t": "mended", "amount": hp - before})
	rerolls = 0
	stock(rng, level)
	return ev


## Stocks the shelf from the deck: buildings by how much land is free (more when there is much; one when there is
## none, to pull something down for), then raises and affixes -- each card at most once, only those that can be used
## now and are found here, no more than one that costs more gold than there is -- and a star dinosaur after them.
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
	star_offer = _draw_star(rng, level)


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
			return int(o.price)
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
	return maxi(1, Content.RAISE + level)



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
	return maxi(1, Content.SHOP + _sum("shelf") + _star("shelf"))


## How many goods can be kept for later: as many as the hoarder keeps, while it is fed.
func stash_size() -> int:
	return _star("keep")


func reroll_price() -> int:
	var free := _star("rerolls") + _sum("rerolls")
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
	return Content.INTEREST_MAX + _star("interest") + _sum("interest")


# -- This round's army ------------------------------------------------------------------------------------

## This round's army as things stand: each nest, in reading order, makes its count (one more for a red nest swarming,
## one more with the brood queen), each unit paid for in biomass as far as the biomass goes; the first nest one more
## with the mother, eating nothing; the titan, with its star, in the middle of the front row; and then, with horde
## totems, every unit hits harder for how many there are.
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
		var extra := _star("first_free") if first else 0
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
	if _star("titan") > 0:
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


## How many the nest at p makes a round (before biomass and the mother): one, one more for each raise chosen so, one
## more for a red nest swarming (its gift: CLUSTER red nests beside it), one more with the brood queen.
func count(p: Vector2i) -> int:
	var b: Dictionary = buildings[p]
	return 1 + b.path.count("count") + (1 if trait_of(p) == "swarm" and trait_on(p) else 0) + _star("count")


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
			return Lang.t("还差 %d 个红巢挨着") % (Content.CLUSTER - _beside(p, around(p)))
		"guard":
			return Lang.t("要站第一排")
		"cover":
			return Lang.t("要站第二排" if p.y == 0 else "身前同一列还没有巢")
		"alone":
			return Lang.t("左右有巢挨着")
	return ""


## How many of `plots` hold a nest of the same kind as p's -- or, with `any`, any nest.
func _beside(p: Vector2i, plots: Array, any := false) -> int:
	var n := 0
	for q in plots:
		if buildings.has(q) and (Content.is_nest(buildings[q].kind) if any else buildings[q].kind == buildings[p].kind):
			n += 1
	return n


## What the nest at p gives each unit it makes: the species its affixes make of it, where it stands, how elite it is,
## its other affixes -- the only things that make a unit itself stronger -- its gift where it works, what the
## homeland's schools give units of its kind (the champion halls elites, the vanguard camps the front row, the
## watchtowers those that reach far), and what the fed stars give: the front row's armour, red units' attack, quicker
## strikes, reach, attack and hit points for all (less with the brood queen), what the old king has grown to.
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
	var far := maxf(float(Content.UNITS[sp.kind].range), float(s.range)) >= 3.0
	if far:
		s.pierce = int(s.pierce) + _sum("ranged") + _star("reach")
		s.range = maxf(float(Content.UNITS[sp.kind].range), float(s.range)) + _star("reach")
	if p.y == 0 and _star("front_armor") > 0:
		s.armor = int(s.armor) + _star("front_armor") + (1 if diet_count("plant") >= Content.STARS_COUNT else 0)
	if sp.kind == "red" and _star("red_atk") > 0:
		s.atk_bonus = int(s.atk_bonus) + _star("red_atk") + (1 if diet_count("meat") >= Content.STARS_COUNT else 0)
	s.haste = int(s.haste) + _star("haste")
	s.atk_bonus = int(s.atk_bonus) + _star("atk") + grown("grow_boss")
	s.hp_mult = float(s.hp_mult) * (1.0 + (_star("hp_pct") - _star("weak")) / 100.0)
	return s


## How many affixes the nest at p can carry: one, more for each stabilizer in its column, more with the sickle and the
## first bird, more for a mutant nest.
func slots(p: Vector2i) -> int:
	var n := 1 + _star("slots") + (Content.MUTANT_SLOTS if trait_of(p) == "mutant" else 0)
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
			return int(o.price)
		"raise":
			var lv := int(buildings[at].level) if at is Vector2i and buildings.has(at) else 1
			return maxi(1, _raise_price(lv) - (Content.PLUS_RAISE if o.plus else 0))
	return int(o.price)


## The research points an offer costs here: an affix's (none upgraded), less the gene banks' and the doctor's -- none
## with the first bird.
func genes_cost(o: Dictionary) -> int:
	if o.type != "affix" or _star("free_affix") > 0:
		return 0
	return maxi(0, int(o.get("genes", 0)) - _sum("gene_off") - _star("gene_off"))


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


## Whether shelf[i] can be bought into the stash: a building or an affix (what is put somewhere), paid for, and room
## with the hoarder.
func can_store(i: int) -> bool:
	return affordable(i) and stash.size() < stash_size() and Content.offer(shelf[i]).type in ["build", "affix"] \
		and gold >= store_price(i)


## What keeping shelf[i] for later costs: its price.
func store_price(i: int) -> int:
	return price(i)


## Where a good can go, whoever pays: a building on a plot of its part of the homeland (a nest on the battle line,
## anything else behind it); a raise on a building below the top level; an affix on a nest with a place for it.
func _fits(oi: Dictionary) -> Array:
	var o := Content.offer(oi)
	match o.target:
		"tile":
			var nest := Content.is_nest(o.builds)
			return _plots_all().filter(func(p: Vector2i) -> bool:
				return buildable(p) and front(p) == nest and (not buildings.has(p) or buildings[p].kind != o.builds))
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
			if o.plus:
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


## A building put up at p (whatever was there pulled down), at level 1.
func build(p: Vector2i, kind: String) -> void:
	buildings[p] = {"id": _id(), "kind": kind, "level": 1, "path": [], "affixes": []}


# -- The star dinosaurs -----------------------------------------------------------------------------------------

## The stars eat, pen by pen: each what it eats, while the biomass lasts; one it does not reach goes without, and does
## nothing this round. Its events.
func feed() -> Array:
	hungry = []
	var ate := 0
	var without: Array = []
	for k in stars.size():
		var eat := int(Content.STARS[stars[k].id].eat)
		if biomass >= eat:
			biomass -= eat
			ate += eat
		else:
			hungry.append(k)
			without.append(stars[k].id)
	return [{"t": "fed", "ate": ate, "hungry": without}] if not stars.is_empty() else []


## What the stars eat a round, all told.
func star_food() -> int:
	var n := 0
	for s in stars:
		n += int(Content.STARS[s.id].eat)
	return n


## What the fed stars give of `key` (Content.STARS) all told.
func _star(key: String) -> int:
	var n := 0
	for k in stars.size():
		if not k in hungry:
			n += int(Content.STARS[stars[k].id].get(key, 0))
	return n


## What the fed stars that grow by `how` ("grow_boss", "grow_round") have grown to, all told.
func grown(how: String) -> int:
	var n := 0
	for k in stars.size():
		if not k in hungry and Content.STARS[stars[k].id].has(how):
			n += int(stars[k].grow)
	return n


## A star `id` in the pens (fed or not).
func has_star(id: String) -> bool:
	return stars.any(func(s: Dictionary) -> bool: return s.id == id)


## How many stars of `diet` ("plant", "meat") are in the pens.
func diet_count(diet: String) -> int:
	return stars.filter(func(s: Dictionary) -> bool: return Content.STARS[s.id].diet == diet).size()


## Whether the star on offer can be bought now: there is one, the gold for it, and a pen free.
func can_buy_star() -> bool:
	return star_offer != "" and stars.size() < Content.PENS and gold >= int(Content.STARS[star_offer].price)


## Buys the star on offer into the next pen. Its events; [] if it could not be.
func buy_star() -> Array:
	if not can_buy_star():
		return []
	var id := star_offer
	gold -= int(Content.STARS[id].price)
	star_offer = ""
	return take_star(id)


## Star `id` into the next pen (from the shop, the ark, a boss beaten): fed from the start. Its events; [] if there was
## no pen free or it is there already.
func take_star(id: String) -> Array:
	if stars.size() >= Content.PENS or has_star(id):
		return []
	stars.append({"id": id, "grow": 0})
	return [{"t": "star", "id": id}]


## What selling the star in pen k brings back: half its price.
func sell_price(k: int) -> int:
	return int(Content.STARS[stars[k].id].price) / 2 if k >= 0 and k < stars.size() else 0


## The star in pen k sold: its pen free, the pens after it closing up -- and with the hoarder, what it kept gone. Its
## events.
func sell_star(k: int) -> Array:
	if k < 0 or k >= stars.size():
		return []
	var id: String = stars[k].id
	var back := sell_price(k)
	gold += back
	stars.remove_at(k)
	hungry = hungry.filter(func(j: int) -> bool: return j != k).map(func(j: int) -> int: return j - 1 if j > k else j)
	if Content.STARS[id].has("keep") and not stars.any(func(s: Dictionary) -> bool: return Content.STARS[s.id].has("keep")):
		stash.clear()
	return [{"t": "sold", "id": id, "gold": back}]


## A boss or mini-boss beaten: the stars that grow so grow.
func boss_beaten() -> void:
	for k in stars.size():
		var info: Dictionary = Content.STARS[stars[k].id]
		if not k in hungry and info.has("grow_boss"):
			stars[k].grow = mini(int(info.grow_max), int(stars[k].grow) + int(info.grow_boss))


## A star for the shop to offer after its shelf, none of those in the pens: commons the likeliest, then uncommons, then
## rares -- none rarer than the run's level allows (Content.STARS_FROM), no legendary.
func _draw_star(rng: RandomNumberGenerator, level: int) -> String:
	var pool: Array = []
	for id in Content.STARS:
		var r := int(Content.STARS[id].rarity)
		if r <= int(Content.STARS_FROM[clampi(level, 0, Content.STARS_FROM.size() - 1)]) and not has_star(id):
			for k in int(Content.STAR_ODDS[r]):
				pool.append(id)
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else ""


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
	h.stars = stars.duplicate(true)
	h.hungry = hungry.duplicate()
	h.star_offer = star_offer
	h.deck = deck.duplicate(true)
	h.cuts = cuts

	h.shelf = shelf.duplicate(true)
	h.stash = stash.duplicate(true)
	h.rerolls = rerolls
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
	var n := INCOME + _star("gold")
	for p in _working():
		var g := int(_level(buildings[p]).get("gold", 0))
		if g <= 0:
			continue
		n += g + (2 if _like(p) == "ore" else 0)
		for q in around(p):
			if _like(q) == "lava":
				n += Content.LAVA_GOLD
	return n


## The biomass the buildings bring in a round (the fisher's more from each culture pool), and the stars that bring it
## in themselves (the belly, the neck as far as it has grown) -- these eat nothing, so are never without.
func income_biomass() -> int:
	var n := 0
	for p in _working():
		var b := int(_level(buildings[p]).get("biomass", 0))
		if b > 0 and buildings[p].kind == "pool":
			b += _star("pool")
		n += b * (2 if _like(p) == "pond" else 1)
	n += _star("biomass") + grown("grow_round")
	return n


func income_genes() -> int:
	var n := 0
	for p in _working():
		n += int(_level(buildings[p]).get("genes", 0))
		if buildings[p].kind == "sampler":
			for q in around(p):
				if buildings.has(q) and buildings[q].kind == "pool":
					n += Content.SAMPLER_POOL
				if _like(q) == "tree":
					n += Content.TREE_GENES
	return n


## The plots whose buildings bring in what they make this round.
func _working() -> Array:
	return buildings.keys()


## Which of the four ways the special ground at p works (Content.TERRAIN like), or "".
func _like(p: Vector2i) -> String:
	return str(Content.TERRAIN[terrain[p]].get("like", terrain[p])) if terrain.has(p) else ""



func hp_max() -> int:
	return HP + _star("hp")


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
