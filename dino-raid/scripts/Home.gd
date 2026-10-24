class_name Home
extends RefCounted
## The homeland (GAME-DESIGN 17-33): the place's map (Content.LEVELS map), plots of many shapes with bare land between
## them, a cell each building -- the bottom middle plot open from the start, the others opened for gold (open_plot);
## anything built on any open cell, a nest's units fighting in its column's lane -- with the gold and the research points, the blueprints had (plans: what can be built), the star dinosaurs in their
## pens and the one on offer (put away for now: Content.STARS_ON), and the homeland's own hit points. A place begins
## with nothing built and no blueprint: first a nest is picked (first_offer, unlock). A round here goes in parts
## (GAME-DESIGN 26, Content.PHASES). The start (start_round): the round's pay and the interest on the gold kept come
## in. The player's: the player researches techs for research points (research; the tech tree, GAME-DESIGN 29), builds
## from the blueprints had (build_plan), raises buildings (raise), sticks affixes on nests. The making (make): the
## buildings bring in research points and gold, and the nests hatch the round's young (brood). The eating (eat): those
## fed go out to fight (fighters). The battle (Fight): the young live for it only. The population (人口, pop_cap) is a bound,
## not a store: what the homeland feeds of itself and what its pools feed (in the rules, the round's biomass), nothing
## built that would take more. When a place is held, the homeland is made afresh in the next, carrying nothing (fresh).
##
## Neighbours are the four cells up, down, left and right (up: towards the road out); bare land between plots cuts
## them off. A column, the cells one above another. What a building does for nests, it does for those in its reach
## only (reach, Content.REACH). Plain data and rules, nothing on screen: the
## same rules for the game and for its tests.
##
## A building: {id, kind, level, path, affixes: [ids]} -- path: a nest's raises, each "elite".
## A blueprint (图纸): an id of Content.OFFERS -- as a card, {id} (Content.offer).
## A unit (army): {id: "nest id:n", kind, nest: cell, row, lane, slot, of, hp_mult, atk_mult, atk_bonus, armor, range,
##   splash, dive, pierce, haste, charge, size_mult, elite, affixes, guard, guards, care, scavenge, free} -- row, lane:
##   where it stands in battle (row 0 in front, the close-fighting; 1 behind, those reaching far; lane its nest's
##   column); slot, of: which of those of its lane and row it is, of how many; guard, care, scavenge: its nest's gift,
##   where it works in battle (Content.TRAITS, Fight) -- guards: the cell of the nest a guard keeps; free: eating
##   nothing.
## Events (for the screen): opened {plot, gold}, bought {offer}, stored {offer}, placed {offer}, built {at}, replaced {at, was, back},
## raised {at, choice}, affixed {at, affix}, star {id}, sold {id, gold}, fed {ate, hungry: [ids]}, income {gold,
## biomass, genes}, ash {amount}, mended {amount}.
## A star dinosaur (in a pen): {id, grow} -- grow: what it has grown to (Content.STARS grow_boss, grow_round).

const COLS := 6
const ROWS := 7
const INCOME := 5                 # gold each round, at its start
const ALL := 1 << 20              # biomass enough for every young (army)

const HP := 30
const NOWHERE := Vector2i(-1, -1)

var region := 0                   # the place (Content.LEVELS) the ark has landed in
var buildings := {}               # Vector2i -> building
var plot_of := {}                 # Vector2i -> the letter of the plot the cell is in (bare land not in it): the map
var opened: Array = []            # the plots open, by letter: built on
var terrain := {}                 # Vector2i -> special ground (Content.TERRAIN; put away, Content.TERRAIN_ON)
var gold := 0
var biomass := 0                  # this round's, from its making to its eating; what is left goes to waste
var genes := 0                    # research points (研究点数): for unlocking blueprints, nothing else
var hp := HP
var stars: Array = []             # the star dinosaurs, a pen each, in order: {id, grow}
var hungry: Array = []            # the pens whose stars went without this round (doing nothing till the next)
var star_offer := ""              # the star dinosaur on offer this round, "" when none (or bought)
var plans: Array = []             # the blueprints had in this place (Content.OFFERS ids), in the order had
var brood: Array = []             # this round's young, hatched in its making (make), till its battle
var fighters: Array = []          # those of them fed in its eating (eat), to fight
var next_id := 1


## The homeland at the run's start, in the rainforest -- or, with no `rng`, nothing yet (clone fills it in).
func _init(rng: RandomNumberGenerator) -> void:
	if rng != null:
		fresh(0, rng)


## The homeland made afresh in place `r`, carrying nothing from the last (the player, 2026-10-21: "什么都不带"): no
## gold, research points or stars, no blueprint -- the first, a nest, is picked (first_offer; the player, 2026-10-22:
## "开场什么建筑都没有，先三选一一个巢穴") -- the hit points whole.
func fresh(r: int, rng: RandomNumberGenerator) -> void:
	gold = 0
	genes = 0
	stars = []
	hungry = []
	star_offer = ""
	plans = []
	hp = HP
	land(r, rng)


## The homeland laid out in place `r`: its map, only its first plot open (Content.START_PLOT), nothing built -- and,
## with Content.TERRAIN_ON, the special ground of the place lying about on its plots.
func land(r: int, rng: RandomNumberGenerator) -> void:
	region = r
	buildings.clear()
	terrain.clear()
	biomass = 0
	brood = []
	fighters = []
	plot_of = map_of(r)
	opened = [Content.START_PLOT]
	hungry = []
	if Content.TERRAIN_ON:
		var plots: Array = plot_of.keys()
		shuffle(plots, rng)
		var lie: Dictionary = Content.LEVELS[r].terrain
		for kind in lie:
			for k in int(lie[kind]):
				if not plots.is_empty():
					terrain[plots.pop_back()] = kind
	hp = mini(hp, hp_max())


## Place r's map: each cell of a plot, its plot's letter (Content.LEVELS map; bare land not in it).
static func map_of(r: int) -> Dictionary:
	var out := {}
	var rows: Array = Content.LEVELS[r].map
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != ".":
				out[Vector2i(x, y)] = row[x]
	return out


# -- The plots (地块, GAME-DESIGN 33) -----------------------------------------------------------------------------

## The cells of plot `id`, in reading order.
func plot_cells(id: String) -> Array:
	return _plots_all().filter(func(p: Vector2i) -> bool: return plot_of.get(p, "") == id)


## The map's plots, by letter, in reading order of their first cells.
func plot_ids() -> Array:
	var out: Array = []
	for p in _plots_all():
		var id: String = plot_of.get(p, "")
		if id != "" and not id in out:
			out.append(id)
	return out


## Whether plot `id`, not open, is near enough an open one to be opened: at most one cell of bare land between them
## (two steps up, down, left or right -- a corner's touch counting).
func reachable(id: String) -> bool:
	if id in opened:
		return false
	for p in plot_cells(id):
		for q in plot_of:
			if plot_of[q] in opened and absi(p.x - q.x) + absi(p.y - q.y) <= 2:
				return true
	return false


## What opening plot `id` costs: Content.OPEN_BASE, 1 for each of its cells, Content.OPEN_MORE for each plot opened in
## this place before it.
func open_price(id: String) -> int:
	return Content.OPEN_BASE + plot_cells(id).size() + Content.OPEN_MORE * (opened.size() - 1)


## Whether plot `id` can be opened now: near an open one, and the gold for it.
func can_open(id: String) -> bool:
	return reachable(id) and gold >= open_price(id)


## Plot `id` opened, paid for: its cells can be built on from now on. Its events: opened {plot, gold}; [] if it could
## not be.
func open_plot(id: String) -> Array:
	if not can_open(id):
		return []
	var price := open_price(id)
	gold -= price
	opened.append(id)
	return [{"t": "opened", "plot": id, "gold": price}]


# -- A round ----------------------------------------------------------------------------------------------

## The start of a round (GAME-DESIGN 26): the round's pay (INCOME) comes in, and the interest on the gold kept; a star
## dinosaur comes to be had (while a pen is free, and the stars are out: Content.STARS_ON); no young are out yet. Its
## events: pay {gold, interest}.
func start_round(rng: RandomNumberGenerator, level: int) -> Array:
	var more := interest()
	gold += INCOME + more
	brood = []
	fighters = []
	star_offer = _draw_star(rng, level) if Content.STARS_ON and stars.size() < Content.PENS else ""
	return [{"t": "pay", "gold": INCOME, "interest": more}]


## The making, the player done (GAME-DESIGN 26): the round's biomass, made afresh (what was left of the last is gone);
## research points and gold come in -- the buildings', and the stars' that ate last time; the stars that grow grow; the
## shield mends; and the nests hatch this round's young, every one they make (brood). Its events: income {gold,
## biomass, genes}, mended {amount}.
func make() -> Array:
	var ev: Array = []
	biomass = income_biomass()
	var n := income_genes()
	var g := income_gold()
	genes += n
	gold += g
	ev.append({"t": "income", "gold": g, "biomass": biomass, "genes": n})
	for k in stars.size():
		var info: Dictionary = Content.STARS[stars[k].id]
		if not k in hungry and info.has("grow_round"):
			stars[k].grow = mini(int(info.grow_max), int(stars[k].grow) + int(info.grow_round))
	if _star("mend") > 0 and hp < hp_max():
		var before := hp
		hp = mini(hp_max(), hp + _star("mend"))
		ev.append({"t": "mended", "amount": hp - before})
	brood = army(ALL)
	return ev


## The eating, after the making (GAME-DESIGN 26): the stars eat first, pen by pen (feed); then the young, nest by nest,
## each what it eats. The population kept within what the biomass feeds (pop_room), there is enough for all; should
## there not be, those it does not reach stay behind. The young fed go out to fight (fighters). The sickle costs the
## homeland a hit point. Its events: fed {ate, hungry}, young {ate, behind}, ash {amount}.
func eat() -> Array:
	var ev := feed()
	fighters = army()
	var ate := food_of(fighters)
	biomass -= ate
	ev.append({"t": "young", "ate": ate, "behind": maxi(0, brood.size() - fighters.size())})
	var ash := _star("ash")
	if ash > 0:
		var before := hp
		hp = maxi(1, hp - ash)
		ev.append({"t": "ash", "amount": before - hp})
	return ev


## The homeland as this round's making and eating will leave it (on a copy): what the player's part leads to -- the
## young that will fight (fighters), which stars will have eaten.
func settled() -> Home:
	var h := clone()
	h.make()
	h.eat()
	return h


# -- The population -------------------------------------------------------------------------------------------------

## The population (人口, GAME-DESIGN 26, 28): as many as the homeland feeds of itself (Content.HOME_POP) and its pools
## feed -- the biomass made a round.
func pop_cap() -> int:
	return income_biomass()


## The population taken: what every young the nests hatch a round eats (the free eat nothing), and every star.
func pop_used() -> int:
	var n := food_of(army(ALL))
	for s in stars:
		n += int(Content.STARS[s.id].eat)
	return n


## The population free: what more the biomass would feed (below 0: more is eaten than it feeds).
func pop_room() -> int:
	return pop_cap() - pop_used()


## Whether `h` -- this homeland with something done to it -- keeps within what its biomass feeds, or no further over it
## than this one is.
func _pop_fits(h: Home) -> bool:
	return h.pop_room() >= mini(0, pop_room())


## Whether blueprint `oi` put on `at` keeps the population within the biomass (_pop_fits).
func pop_fits(oi: Dictionary, at: Variant) -> bool:
	var h := clone()
	h._apply(oi, at)
	return _pop_fits(h)


## The population blueprint `oi` takes on `at` (less than 0: it feeds more than it takes).
func pop_need(oi: Dictionary, at: Variant) -> int:
	var h := clone()
	h._apply(oi, at)
	return pop_room() - h.pop_room()


# -- The blueprints ---------------------------------------------------------------------------------------------------

## The nests a place's first is picked from (Content.FIRST_NESTS): `n` of those found here.
func first_offer(rng: RandomNumberGenerator, n: int) -> Array:
	var pool: Array = Content.FIRST_NESTS.filter(func(id: String) -> bool: return tech_here(id))
	shuffle(pool, rng)
	return pool.slice(0, n)


## Blueprint `id` had: from now on, in this place, it can be built (or stuck on). Whether it was new.
func unlock(id: String) -> bool:
	if id in plans or not Content.OFFERS.has(id):
		return false
	plans.append(id)
	return true


# -- The tech tree (科技树, GAME-DESIGN 29) ---------------------------------------------------------------------------

## The research points tech `id` costs.
static func tech_cost(id: String) -> int:
	return int(Content.OFFERS[id].get("cost", 1))


## The tech tech `id` needs had first ("" for none).
static func tech_needs(id: String) -> String:
	return str(Content.OFFERS[id].get("needs", ""))


## Whether tech `id` is found here at all (none another place's own).
func tech_here(id: String) -> bool:
	return int(Content.OFFERS[id].get("region", region)) == region


## Whether tech `id` can be researched, the research points aside: found here, not had yet, what it needs had.
func tech_open(id: String) -> bool:
	return tech_here(id) and not id in plans and (tech_needs(id) == "" or tech_needs(id) in plans) and not tech_shut(id)


## The tech tech `id` is one of two with, where its line forks ("" for none: Content.OFFERS mutex).
static func tech_other(id: String) -> String:
	return str(Content.OFFERS[id].get("mutex", ""))


## Whether tech `id` is shut here: the other of its fork had (v0.15).
func tech_shut(id: String) -> bool:
	return tech_other(id) != "" and tech_other(id) in plans


## Whether tech `id` can be researched now: open, and the research points for it.
func can_research(id: String) -> bool:
	return tech_open(id) and genes >= tech_cost(id)


## Tech `id` researched: its research points paid, its blueprint had. Whether it could be.
func research(id: String) -> bool:
	if not can_research(id):
		return false
	genes -= tech_cost(id)
	return unlock(id)


func _raise_price(level: int) -> int:
	return maxi(1, Content.RAISE + level)



## The interest on the gold kept from the last round (paid at the round's start).
func interest() -> int:
	return mini(interest_max(), gold / Content.INTEREST_STEP)


## The most interest a round: Content.INTEREST_MAX, the saver's more, each vault's -- more for each mine or forge beside
## it (Content.VAULT_MINE).
func interest_max() -> int:
	var n := Content.INTEREST_MAX + _star("interest")
	for p in buildings:
		if buildings[p].kind == "vault":
			n += int(_level(buildings[p]).interest)
			for q in around(p):
				if buildings.has(q) and buildings[q].kind in ["mine", "forge"]:
					n += Content.VAULT_MINE
	return n


# -- This round's army ------------------------------------------------------------------------------------

## This round's army as things stand: each nest, in reading order, makes its count (one more for a red nest swarming,
## one more with the brood queen), each unit paid for in biomass as far as the biomass (or `food`, if given: ALL for as
## many as the nests make) goes; the first nest one more with the mother, eating nothing; the titan, with its star, in
## the middle of the front row; and then the units of the nests in a horde totem's reach hit harder for how many there
## are.
func army(food := -1) -> Array:
	var out: Array = []
	if food < 0:
		food = biomass
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
		out.append_array(made)
	if _star("titan") > 0:
		out.append({"id": "titan:0", "kind": "titan", "nest": NOWHERE, "row": 0, "lane": (COLS - 1) * 0.5, "slot": 0,
			"of": 1, "hp_mult": 1.0, "atk_mult": 1.0, "atk_bonus": 0, "armor": 0, "range": 0.0, "splash": 0.0,
			"dive": false, "pierce": 0, "haste": 0, "charge": false, "size_mult": 1.0, "elite": 0, "affixes": [],
			"evolved": false, "free": true})
	var n := out.size()
	var many := {}
	for u in out:
		u.atk_bonus = int(u.atk_bonus) + horde_bonus(n, u.nest)
		var key := [float(u.lane), int(u.row)]
		many[key] = int(many.get(key, 0)) + 1
	# Each where it stands: those of a lane and row one beside another, in the order made, more behind when many.
	var placed := {}
	for u in out:
		var key := [float(u.lane), int(u.row)]
		u.slot = int(placed.get(key, 0))
		u.of = int(many[key])
		placed[key] = int(u.slot) + 1
	return out


## The attack the units of the nest at p get with an army of n: +1 for every so many units, for each horde totem whose
## reach takes it in.
func horde_bonus(n: int, p: Vector2i) -> int:
	var k := 0
	for q in buildings:
		if buildings[q].kind == "horde_totem" and reaches("horde_totem", q, p):
			k += n / int(_level(buildings[q]).per)
	return k


## The biomass this round's army eats.
func army_food() -> int:
	return food_of(army())


## What `units` eat (the free nothing).
static func food_of(units: Array) -> int:
	var n := 0
	for u in units:
		if not u.free:
			n += int(Content.UNITS[u.kind].food)
	return n


## How many the nest at p makes a round (before biomass and the mother): one, one more for a red nest swarming (its
## gift: CLUSTER red nests beside it), one more with the brood queen.
func count(p: Vector2i) -> int:
	return 1 + (1 if trait_of(p) == "swarm" and trait_on(p) else 0) + _star("count")


## The gift (Content.TRAITS) of the nest at p, or "".
func trait_of(p: Vector2i) -> String:
	if not buildings.has(p) or not Content.is_nest(buildings[p].kind):
		return ""
	return str(Content.BUILDINGS[buildings[p].kind].trait)


## Whether the nest at p stands where its gift works: swarming with CLUSTER of its kind beside it; guarding a nest
## below it; under cover of a nest above it; alone with no nest beside it at all. The others work anywhere.
func trait_on(p: Vector2i) -> bool:
	match trait_of(p):
		"":
			return false
		"swarm":
			return _beside(p, around(p)) >= Content.CLUSTER
		"guard":
			return _beside(p, [p + Vector2i.DOWN], true) == 1
		"cover":
			return _beside(p, [p + Vector2i.UP], true) == 1
		"alone":
			return _beside(p, around(p), true) == 0
	return true


## What the nest at p lacks for its gift to work, in the player's words ("" when it works).
func trait_need(p: Vector2i) -> String:
	if trait_on(p) or trait_of(p) == "":
		return ""
	match trait_of(p):
		"swarm":
			return Lang.t("还差 %d 个红巢挨着") % (Content.CLUSTER - _beside(p, around(p)))
		"guard":
			return Lang.t("下面还没有巢挨着")
		"cover":
			return Lang.t("上面还没有巢挨着")
		"alone":
			return Lang.t("有巢挨着")
	return ""


## How many of `plots` hold a nest of the same kind as p's -- or, with `any`, any nest.
func _beside(p: Vector2i, plots: Array, any := false) -> int:
	var n := 0
	for q in plots:
		if buildings.has(q) and (Content.is_nest(buildings[q].kind) if any else buildings[q].kind == buildings[p].kind):
			n += 1
	return n


## What the nest at p gives each unit it makes: the species its affixes make of it, where it stands (its column its
## lane; in front if it fights close, behind if it reaches far), how elite it is, its other affixes -- the only things
## that make a unit itself stronger -- its gift where it works, what the schools' buildings whose reach takes it in give
## units of its kind (the champion halls elites, the vanguard camps the close-fighting, the watchtowers those that
## reach far), and what the fed stars give: the front row's armour, red units' attack, quicker strikes, reach, attack and
## hit points for all (less with the brood queen), what the old king has grown to.
func spec_of(p: Vector2i) -> Dictionary:
	var b: Dictionary = buildings[p]
	var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
	var e: int = b.path.count("elite")
	var s := {"kind": sp.kind, "nest": p, "row": 0, "lane": float(p.x), "hp_mult": pow(Content.ELITE_HP, e),
		"atk_mult": pow(Content.ELITE_ATK, e), "atk_bonus": 0, "armor": 0, "range": 0.0, "splash": 0.0, "dive": false,
		"pierce": 0, "haste": 0, "charge": false, "knock": 0.0, "devour": false, "roar": false,
		"size_mult": pow(Content.ELITE_SIZE, e), "elite": e,
		"affixes": b.affixes.duplicate(), "evolved": sp.kind != Content.BUILDINGS[b.kind].nest,
		"guard": false, "guards": NOWHERE, "care": false, "scavenge": false}
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
		s.knock = maxf(float(s.knock), float(af.get("knock", 0.0)))
		s.devour = bool(s.devour) or bool(af.get("devour", false))
		s.roar = bool(s.roar) or bool(af.get("roar", false))
		s.hp_mult = float(s.hp_mult) * (1.0 + float(af.get("hp", 0)) / 100.0)
	var gift := trait_of(p)
	var on := trait_on(p)
	s.guard = gift == "guard" and on
	if s.guard:
		s.guards = p + Vector2i.DOWN
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
		var more := 1.0 + _given("elite", p) / 100.0
		s.hp_mult = float(s.hp_mult) * more
		s.atk_mult = float(s.atk_mult) * more
	var far := maxf(float(Content.UNITS[sp.kind].range), float(s.range)) >= 3.0
	s.row = 1 if far else 0
	if not far:
		s.hp_mult = float(s.hp_mult) * (1.0 + _given("front", p) / 100.0)
	if far:
		s.pierce = int(s.pierce) + _given("ranged", p) + _star("reach")
		s.range = maxf(float(Content.UNITS[sp.kind].range), float(s.range)) + _star("reach")
	if not far and _star("front_armor") > 0:
		s.armor = int(s.armor) + _star("front_armor") + (1 if diet_count("plant") >= Content.STARS_COUNT else 0)
	if sp.kind == "red" and _star("red_atk") > 0:
		s.atk_bonus = int(s.atk_bonus) + _star("red_atk") + (1 if diet_count("meat") >= Content.STARS_COUNT else 0)
	s.haste = int(s.haste) + _star("haste")
	s.atk_bonus = int(s.atk_bonus) + _star("atk") + grown("grow_boss")
	s.hp_mult = float(s.hp_mult) * (1.0 + (_star("hp_pct") - _star("weak")) / 100.0)
	return s


## How many affixes the nest at p can carry: one, more for each stabilizer whose reach takes it in, more with the
## sickle and the first bird, more for a mutant nest.
func slots(p: Vector2i) -> int:
	return 1 + _star("slots") + (Content.MUTANT_SLOTS if trait_of(p) == "mutant" else 0) + _given("slots", p)


## Where the building of `kind` standing at p works (its 作用范围, Content.REACH; GAME-DESIGN 28, 33) -- lit blue while
## it is placed or pointed at: "near", the four cells beside it. A nest, where its gift looks (Content.TRAITS): a red's
## neighbours (more reds), the cell below a green (whom it guards), the cell above a blue (its cover), a gold's
## neighbours (to be without nests), the rest of a white's column (whom it heals). [] for nowhere. (Bare land among
## them holds nothing.)
static func reach(kind: String, p: Vector2i) -> Array:
	var b: Dictionary = Content.BUILDINGS[kind]
	var r := str(b.get("reach", ""))
	var out: Array = []
	if b.has("nest"):
		match str(b.trait):
			"swarm", "alone":
				r = "near"
			"guard":
				out.append(p + Vector2i.DOWN)
			"cover":
				out.append(p + Vector2i.UP)
			"care":
				for y in ROWS:
					out.append(Vector2i(p.x, y))
	if r == "near":
		out = [p + Vector2i.UP, p + Vector2i.DOWN, p + Vector2i.LEFT, p + Vector2i.RIGHT]
	return out.filter(func(q: Vector2i) -> bool: return q != p and on_map(q))


## Whether the building of `kind` standing at q works on p (reach, worked out without the list: this is asked for
## every unit made).
static func reaches(kind: String, q: Vector2i, p: Vector2i) -> bool:
	if str(Content.BUILDINGS[kind].get("reach", "")) == "near":
		return absi(p.x - q.x) + absi(p.y - q.y) == 1
	return p in reach(kind, q)


## What the buildings whose reach takes in the nest at p give it of `key` (their levels' Content.BUILDINGS) all told.
func _given(key: String, p: Vector2i) -> int:
	var n := 0
	for q in buildings:
		var b: Dictionary = buildings[q]
		var k := int(_level(b).get(key, 0))
		if k != 0 and not Content.is_nest(b.kind) and reaches(b.kind, q, p):
			n += k
	return n


# -- Building, raising ----------------------------------------------------------------------------------------------

## What blueprint `o` (Content.offer) costs put on `at`, in gold: its price -- an affix's less what the gene banks whose
## reach takes in the nest there give, at least 1.
func price_at(o: Dictionary, at: Variant) -> int:
	if o.type == "build":
		return int(o.price) + _more(str(o.builds))
	if not at is Vector2i:
		return int(o.price)
	return maxi(1, int(o.price) - _given("affix_off", at))


## What a building of `kind` costs more for those of its kind there are already (v0.15: Content.MORE each) -- the nests
## and the pools nothing more.
func _more(kind: String) -> int:
	if Content.is_nest(kind) or kind in Content.NEVER_MORE:
		return 0
	return Content.MORE * buildings.values().filter(func(b: Dictionary) -> bool: return b.kind == kind).size()


## Whether blueprint `id` could be paid for somewhere: the gold for it where it costs least.
func affordable(id: String) -> bool:
	var o := Content.offer({"id": id})
	return gold >= (1 if o.type == "affix" and _sum("affix_off") > 0 else price_at(o, null))


## Where blueprint `id` can go now and be paid for there: plots (Vector2i). [] when it is not had, or cannot be paid for.
func targets(id: String) -> Array:
	if not id in plans or not affordable(id):
		return []
	var o := Content.offer({"id": id})
	return _fits({"id": id}).filter(func(p: Vector2i) -> bool: return gold >= price_at(o, p))


## Where a blueprint could go, the population aside: a building on an open cell -- empty, or with another of its
## sort to pull down (a nest for a nest, anything else for anything else); an affix on a nest with a place for it.
func _places(oi: Dictionary) -> Array:
	var o := Content.offer(oi)
	match o.target:
		"tile":
			var nest := Content.is_nest(o.builds)
			return _plots_all().filter(func(p: Vector2i) -> bool:
				return buildable(p) and (not buildings.has(p)
					or buildings[p].kind != o.builds and Content.is_nest(buildings[p].kind) == nest))
		"nest":
			return _plots().filter(func(p: Vector2i) -> bool:
				var b: Dictionary = buildings[p]
				return Content.is_nest(b.kind) and not o.affix in b.affixes and b.affixes.size() < slots(p))
	return []


## Where a blueprint can go: where it could (_places), the population kept within what the biomass feeds -- a building
## put on bare ground, not a nest, takes none.
func _fits(oi: Dictionary) -> Array:
	var o := Content.offer(oi)
	return _places(oi).filter(func(p: Vector2i) -> bool:
		return (o.type == "build" and not Content.is_nest(o.builds) and not buildings.has(p)) or pop_fits(oi, p))


## Whether only the population keeps `oi` from going anywhere.
func pop_blocks(oi: Dictionary) -> bool:
	return _fits(oi).is_empty() and not _places(oi).is_empty()


## Builds blueprint `id` on `at` (an affix: sticks it on the nest there), paying for it. Its events; [] if it could not
## be.
func build_plan(id: String, at: Vector2i) -> Array:
	if not at in targets(id):
		return []
	gold -= price_at(Content.offer({"id": id}), at)
	return [{"t": "bought", "offer": id}] + _apply({"id": id}, at)


## What raising the building at p a level costs: RAISE more than its level.
func raise_price(p: Vector2i) -> int:
	return _raise_price(int(buildings[p].level)) if buildings.has(p) else 0


## Whether the building at p can be raised a level: below the top level, and paid for. (A nest's raise makes it elite,
## taking no more of the population; a pool's feeds more.)
func can_raise(p: Vector2i) -> bool:
	return buildings.has(p) and int(buildings[p].level) < Content.LEVEL_MAX and gold >= raise_price(p)


## Raises the building at p a level -- a nest elite once more -- paying for it. Its events; [] if it could not be.
func raise(p: Vector2i) -> Array:
	if not can_raise(p):
		return []
	gold -= raise_price(p)
	return _raise(p)


func _raise(p: Vector2i) -> Array:
	var b: Dictionary = buildings[p]
	var nest := Content.is_nest(b.kind)
	if nest:
		b.path.append("elite")
	b.level = mini(Content.LEVEL_MAX, int(b.level) + 1)
	return [{"t": "raised", "at": p, "elite": nest}]


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
		"affix":
			buildings[at].affixes.append(o.affix)
			ev.append({"t": "affixed", "at": at, "affix": o.affix})
	return ev


## The nest at `from` moved to `to`, for nothing, while the player builds (v0.15: to face the lanes the wave comes
## down) -- an empty open cell, or one with another nest, the two then changing places; its level and affixes go with
## it. Not so far that the population no longer feeds what the nests hatch (moved beside its kind, a red swarms). Its
## events: moved {from, to}; [] if it could not be.
func move_building(from: Vector2i, to: Vector2i) -> Array:
	if from == to or not buildings.has(from) or not Content.is_nest(buildings[from].kind) or not buildable(to):
		return []
	if buildings.has(to) and not Content.is_nest(buildings[to].kind):
		return []
	var h := clone()
	h._swap(from, to)
	if not _pop_fits(h):
		return []
	_swap(from, to)
	return [{"t": "moved", "from": from, "to": to}]


func _swap(from: Vector2i, to: Vector2i) -> void:
	var b: Dictionary = buildings[from]
	if buildings.has(to):
		buildings[from] = buildings[to]
	else:
		buildings.erase(from)
	buildings[to] = b


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
	return star_offer != "" and stars.size() < Content.PENS and gold >= int(Content.STARS[star_offer].price) \
		and star_fits(star_offer)


## Whether star `id` in a pen keeps the population within what the biomass feeds (it eats, and some hatch more).
func star_fits(id: String) -> bool:
	var h := clone()
	h.take_star(id)
	return _pop_fits(h)


## The population star `id` takes, in a pen here.
func star_need(id: String) -> int:
	var h := clone()
	h.take_star(id)
	return pop_room() - h.pop_room()


## Whether the star in pen k can be sold: not when the biomass it brings in feeds what eats.
func can_sell_star(k: int) -> bool:
	if k < 0 or k >= stars.size():
		return false
	var h := clone()
	h.stars.remove_at(k)
	h.hungry = []
	return _pop_fits(h)


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
	if not can_sell_star(k):
		return []
	var id: String = stars[k].id
	var back := sell_price(k)
	gold += back
	stars.remove_at(k)
	hungry = hungry.filter(func(j: int) -> bool: return j != k).map(func(j: int) -> int: return j - 1 if j > k else j)
	return [{"t": "sold", "id": id, "gold": back}]


## A boss or mini-boss beaten: the stars that grow so grow.
func boss_beaten() -> void:
	for k in stars.size():
		var info: Dictionary = Content.STARS[stars[k].id]
		if not k in hungry and info.has("grow_boss"):
			stars[k].grow = mini(int(info.grow_max), int(stars[k].grow) + int(info.grow_boss))


## A star to be had this round, none of those in the pens: commons the likeliest, then uncommons, then
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
	var h: Home = get_script().new(null)
	h.region = region
	h.buildings = buildings.duplicate(true)
	h.plot_of = plot_of
	h.opened = opened.duplicate()
	h.terrain = terrain.duplicate()
	h.gold = gold
	h.biomass = biomass
	h.genes = genes
	h.hp = hp
	h.stars = stars.duplicate(true)
	h.hungry = hungry.duplicate()
	h.star_offer = star_offer
	h.plans = plans.duplicate()

	h.brood = brood.duplicate(true)
	h.fighters = fighters.duplicate(true)
	h.next_id = next_id
	return h


## Whether p is on the map at all.
static func on_map(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS


## Whether p is a cell of an open plot.
func is_open(p: Vector2i) -> bool:
	return plot_of.has(p) and plot_of[p] in opened


## Whether a building can stand at p: a cell of an open plot, and not on ground nothing can be built on.
func buildable(p: Vector2i) -> bool:
	return is_open(p) and bool(Content.TERRAIN.get(terrain.get(p, ""), {"build": true}).build)


# -- What the homeland comes to ---------------------------------------------------------------------------

## The gold the buildings and the stars bring in a round, in its making (the round's pay, INCOME, comes at its start).
func income_gold() -> int:
	var n := _star("gold")
	for p in _working():
		var g := int(_level(buildings[p]).get("gold", 0))
		if g <= 0:
			continue
		n += g + (2 if _like(p) == "ore" else 0)
		for q in around(p):
			if _like(q) == "lava":
				n += Content.LAVA_GOLD
	return n


## The biomass a round -- the population fed: the homeland's own (Content.HOME_POP), what the buildings bring in (the
## fisher's more from each culture pool), and the stars that bring it in themselves (the belly, the neck as far as it
## has grown) -- these eat nothing, so are never without.
func income_biomass() -> int:
	var n := Content.HOME_POP
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
				if buildings.has(q) and buildings[q].kind in ["pool", "spore_pool"]:
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
