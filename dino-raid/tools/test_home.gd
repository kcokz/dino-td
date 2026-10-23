extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run; GAME-DESIGN 17-28) on set-up cases, headless:
##
##   Godot --headless --path dino-raid --script res://tools/test_home.gd

var failed := 0
var passed := 0


## A homeland whose biomass feeds as many as there are: for the tests of other rules than the population's.
class Fed extends Home:
	func pop_cap() -> int:
		return 999


func _init() -> void:
	_first_round()
	_phases()
	_population()
	_zones()
	_making()
	_neighbours()
	_reach()
	_nest_gifts()
	_terrain()
	_affixes_and_recipes()
	_schools()
	_buying()
	_blueprints()
	_interest()
	_rewards()
	_stars()
	_star_kinds()
	_moving_on()
	_map()
	_formation()
	_fights()
	_falling_hard()
	_run_flow()
	_economy()
	_clone()
	_waves()
	_texts()
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(what: String, ok: bool, got: Variant = null) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL  %s  (got %s)" % [what, got])


func rng(seed := 3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


## A homeland with nothing built and no special ground, in the first place, plenty of everything -- its population
## no bound (Fed) unless `fed` is false.
func bare(region := 0, fed := true) -> Home:
	var h: Home = Fed.new(rng()) if fed else Home.new(rng())
	h.buildings.clear()
	h.terrain.clear()
	h.region = region
	h.gold = 20
	h.biomass = 20
	h.genes = 10
	return h


func _with(stars: Array) -> Home:
	var h := bare()
	for id in stars:
		h.take_star(id)
	return h


func _first_round() -> void:
	var h := Home.new(rng())
	check("a place begins with nothing built and no blueprint", h.buildings.is_empty() and h.plans.is_empty(),
		[h.buildings, h.plans])
	check("special ground lies behind the battle line", h.terrain.size() == 5
		and h.terrain.keys().all(func(p: Vector2i) -> bool: return p.y >= Content.FRONT_ROWS), h.terrain)
	check("nothing in store to start with", h.gold == 0 and h.biomass == 0 and h.genes == 0, [h.gold, h.biomass, h.genes])
	var first := h.first_offer(rng(), 0, 3)
	check("the first nest: one of three, all different, all of the first nests", first.size() == 3 and first[0] != first[1]
		and first[1] != first[2] and first[0] != first[2]
		and first.all(func(id: String) -> bool: return id in Content.FIRST_NESTS), first)
	var never := 0
	for s in 40:
		for id in h.first_offer(rng(s), 0, 3):
			if id in ["b_white", "b_gold"] or int(Content.BUILDINGS[Content.OFFERS[id].builds].cost) > Home.INCOME:
				never += 1
	check("never the healer or the gold; always one the round's pay builds", never == 0, never)
	h.unlock("b_red")
	var ev := h.start_round(rng(), 0)
	check("the start: the round's pay, no interest on nothing", h.gold == 5 and ev == [{"t": "pay", "gold": 5, "interest": 0}],
		[h.gold, ev])
	check("no star while they are put away", h.star_offer == "" and not Content.STARS_ON, h.star_offer)
	check("the homeland feeds 2 of itself", h.pop_cap() == Content.HOME_POP and h.pop_used() == 0, [h.pop_cap(), h.pop_used()])
	h.build_plan("b_red", Vector2i(2, 0))
	check("the first nest built with the round's pay", h.buildings.size() == 1 and h.gold == 2, h.gold)
	check("nothing hatched before the making", h.brood.is_empty() and h.fighters.is_empty())
	h.make()
	check("the making: the population fed, 2; no gold or research points of their own", h.biomass == 2 and h.gold == 2
		and h.genes == 0, [h.biomass, h.gold, h.genes])
	var a := h.brood
	check("one red hatched, for the front row, its column its lane", a.size() == 1 and a[0].kind == "red"
		and int(a[0].row) == 0 and is_equal_approx(float(a[0].lane), 2.0), a)
	h.eat()
	check("the eating: it takes 1 and goes to fight", h.fighters.size() == 1 and h.biomass == 1, [h.fighters.size(), h.biomass])


## A round's parts (GAME-DESIGN 26): each thing a card does happens in one of them.
func _phases() -> void:
	check("the start, the player's, the making, the eating, the battle", Content.PHASES.keys() == ["start", "play", "make",
		"eat", "fight"], Content.PHASES.keys())
	check("the eating only while there are stars", Content.phases() == ["start", "play", "make", "fight"], Content.phases())
	var missing: Array = []
	for k in Content.BUILDINGS:
		for l in Content.BUILDINGS[k].get("levels", []):
			for key in l:
				if not Content.PHASE_OF.has(key):
					missing.append(k + "." + key)
	for id in Content.STARS:
		for key in Content.STARS[id]:
			if not key in Content.STAR_FACTS and not Content.PHASE_OF.has(key):
				missing.append(id + "." + key)
	for key in Content.TRAITS.keys() + ["count", "elite", "affix"]:
		if not Content.PHASE_OF.has(key):
			missing.append(key)
	check("every thing a card does has its part of the round", missing.is_empty(), missing)
	check("and every part is one of the round's", Content.PHASE_OF.values().all(func(p: String) -> bool:
		return Content.PHASES.has(p)))


## The population (GAME-DESIGN 26, 28): as many as the homeland feeds of itself and its pools feed; nothing is built
## past it.
func _population() -> void:
	var h := Home.new(rng())
	h.plans = ["b_red", "b_pool"]
	h.gold = 50
	check("the start: 0 of 2", h.pop_used() == 0 and h.pop_cap() == Content.HOME_POP, [h.pop_used(), h.pop_cap()])
	h.build_plan("b_red", Vector2i(2, 0))
	var t0 := h.targets("b_red")
	check("a red nest: not beside the red one (with their gift, three more), elsewhere on the line", t0.size() == 8
		and not Vector2i(1, 0) in t0 and not Vector2i(3, 0) in t0 and not Vector2i(2, 1) in t0 and Vector2i(0, 0) in t0, t0)
	h.build_plan("b_red", Vector2i(0, 0))
	check("two: 2 of 2", h.pop_used() == 2 and h.pop_room() == 0)
	check("full: a third goes nowhere, for the population alone", h.targets("b_red").is_empty()
		and h.pop_blocks({"id": "b_red"}))
	check("a raise: one more, no; elite, yes", not h.can_raise(Vector2i(0, 0), "count") and h.can_raise(Vector2i(0, 0), "elite"))
	check("so it is not raised for one more", h.raise(Vector2i(0, 0), "count").is_empty()
		and int(h.buildings[Vector2i(0, 0)].level) == 1)
	var bare_ground: Array = h.targets("b_pool").filter(func(p: Vector2i) -> bool: return not h.terrain.has(p))
	h.build_plan("b_pool", bare_ground[0])
	check("a culture pool: three more fed", h.pop_cap() == Content.HOME_POP + 3 and h.pop_room() == 3, [h.pop_cap(), h.pop_room()])
	check("then the nest can hatch one more", not h.raise(Vector2i(0, 0), "count").is_empty() and h.pop_used() == 3)
	h.star_offer = "warlord"
	check("a star that eats 6, with room for 2: not bought", h.star_need("warlord") == 6 and not h.can_buy_star())
	h.star_offer = "belly"
	check("the belly eats nothing and feeds 4", h.star_need("belly") == -4 and h.can_buy_star())
	h.buy_star()
	h.star_offer = "shield"
	h.buy_star()
	h.take_star("doctor")
	h.take_star("mother")
	check("its biomass fed: then it cannot be sold", h.pop_room() < 4 and not h.can_sell_star(0)
		and h.sell_star(0).is_empty(), h.pop_room())
	check("the others can", h.can_sell_star(1))
	var q := Home.new(rng())
	q.build(Vector2i(2, 0), "nest_red")
	check("the queen: what she eats and one more for the nest", q.star_need("queen") == int(Content.STARS.queen.eat) + 1)
	check("the bar's corner: a nest takes what its young eat, a pool feeds", Content.pop_of(Content.offer({"id": "b_red"})) == 1
		and Content.pop_of(Content.offer({"id": "b_pool"})) == -3 and Content.pop_of(Content.offer({"id": "a_shell"})) == 0)
	var r := Run.new(8)
	var nest: String = r.nest_offer()[0].id
	r.take_first(nest)
	r.start_round()
	r.home.build_plan(nest, Vector2i(2, 0))
	r.make()
	r.eat()
	check("within the population, every young hatched is fed and fights", r.home.fighters.size() == r.home.brood.size()
		and r.home.fighters.size() == 1, [nest, r.home.fighters.size()])


func _zones() -> void:
	var h := bare()
	h.plans = ["b_red", "b_pool"]
	check("a nest only on the battle line", h.targets("b_red").size() == Home.COLS * Content.FRONT_ROWS
		and h.targets("b_red").all(func(p: Vector2i) -> bool: return Home.front(p)), h.targets("b_red"))
	check("anything else only behind it", h.targets("b_pool").size() == Home.COLS * (Home.ROWS - Content.FRONT_ROWS)
		and h.targets("b_pool").all(func(p: Vector2i) -> bool: return not Home.front(p)), h.targets("b_pool"))
	check("a blueprint not had: nowhere", h.targets("b_blue").is_empty() and h.build_plan("b_blue", Vector2i(0, 0)).is_empty())


func _making() -> void:
	var h := bare()
	h.build(Vector2i(0, 0), "nest_red")
	check("level 1: one", h.army().size() == 1)
	check("a raise costs the building's level and 2", h.raise_price(Vector2i(0, 0)) == Content.RAISE + 1)
	h.raise(Vector2i(0, 0), "count")
	check("raised for one more: two", h.army().size() == 2 and int(h.buildings[Vector2i(0, 0)].level) == 2
		and h.gold == 20 - 3, [h.army().size(), h.gold])
	h.raise(Vector2i(0, 0), "elite")
	var a := h.army()
	check("then elite: still two, half again the hit points, a quarter more attack, bigger", a.size() == 2
		and is_equal_approx(float(a[0].hp_mult), Content.ELITE_HP) and is_equal_approx(float(a[0].atk_mult), Content.ELITE_ATK)
		and is_equal_approx(float(a[0].size_mult), Content.ELITE_SIZE) and h.gold == 17 - 4, [a.size(), h.gold])
	var st := Content.unit_stats(a[0])
	check("an elite red: 15 hp, 4 attack", int(st.hp) == 15 and int(st.atk) == 4, [st.hp, st.atk])
	check("level 3 at most", not h.can_raise(Vector2i(0, 0), "elite") and h.raise(Vector2i(0, 0), "elite").is_empty())
	var e := bare()
	e.build(Vector2i(0, 0), "nest_red")
	e.buildings[Vector2i(0, 0)].level = 3
	e.buildings[Vector2i(0, 0)].path = ["elite", "elite"]
	var one := e.army()
	check("elite twice: one, much stronger, eating one", one.size() == 1 and e.army_food() == 1
		and is_equal_approx(float(one[0].hp_mult), Content.ELITE_HP * Content.ELITE_HP))
	h.biomass = 1
	check("biomass short: as many as it pays for", h.army().size() == 1, h.army().size())
	h.eat()
	check("the eating pays", h.fighters.size() == 1 and h.biomass == 0, [h.fighters.size(), h.biomass])


func _neighbours() -> void:
	var h := bare()
	h.build(Vector2i(1, 0), "nest_red")
	h.build(Vector2i(2, 0), "nest_red")
	check("two reds side by side: both swarm, one more each", h.army().size() == 4 and h.count(Vector2i(1, 0)) == 2
		and h.trait_on(Vector2i(1, 0)) and h.trait_on(Vector2i(2, 0)))
	h.build(Vector2i(4, 1), "nest_red")
	check("a red with no red beside it is one red short", not h.trait_on(Vector2i(4, 1))
		and h.trait_need(Vector2i(4, 1)) == "还差 1 个红巢挨着", h.trait_need(Vector2i(4, 1)))
	h.build(Vector2i(4, 0), "nest_red")
	check("one in front of it does as well: up and down count as left and right do", h.trait_on(Vector2i(4, 1))
		and h.trait_on(Vector2i(4, 0)) and h.army().size() == 8)
	var corner := bare()
	corner.build(Vector2i(1, 0), "nest_red")
	corner.build(Vector2i(2, 1), "nest_red")
	check("corner to corner is not beside", not corner.trait_on(Vector2i(1, 0)) and not corner.trait_on(Vector2i(2, 1)))
	var bl := bare()
	bl.build(Vector2i(1, 0), "nest_blue")
	bl.build(Vector2i(2, 0), "nest_blue")
	bl.build(Vector2i(0, 0), "nest_blue")
	check("three blues in a row: no one more -- swarming is the red's", bl.army().size() == 3)
	var g := bare()
	g.build(Vector2i(1, 1), "nest_blue")
	g.build(Vector2i(1, 2), "pool")
	g.build(Vector2i(0, 1), "nest_green")
	g.build(Vector2i(0, 2), "mine")
	check("a pool or a mine behind a nest gives its units nothing", is_equal_approx(float(g.spec_of(Vector2i(1, 1)).hp_mult), 1.0)
		and is_equal_approx(float(g.spec_of(Vector2i(0, 1)).hp_mult), 1.0))
	var s := bare()
	s.build(Vector2i(2, 3), "sampler")
	s.build(Vector2i(1, 3), "pool")
	s.build(Vector2i(3, 3), "pool")
	check("a sampler between two pools: 1 + 2 genes", s.income_genes() == 3, s.income_genes())
	s.build(Vector2i(4, 0), "nest_red")
	s.build(Vector2i(4, 3), "stabilizer")
	s.build(Vector2i(5, 2), "stabilizer")
	s.build(Vector2i(2, 2), "stabilizer")
	check("a stabilizer helps the nests of its column and the columns either side only", s.slots(Vector2i(4, 0)) == 3,
		s.slots(Vector2i(4, 0)))
	var sp := bare()
	sp.build(Vector2i(2, 3), "sampler")
	sp.build(Vector2i(1, 3), "spore_pool")
	check("a spore pool beside a sampler counts as a culture pool does", sp.income_genes() == 1 + Content.SAMPLER_POOL,
		sp.income_genes())


## Where each building works (GAME-DESIGN 28): its neighbours, or the battle line's three columns in front of it; a
## nest, where its gift looks.
func _reach() -> void:
	check("near: the four beside", Home.reach("pool", Vector2i(2, 2)).size() == 4 and Vector2i(2, 1) in Home.reach("pool",
		Vector2i(2, 2)))
	check("near, in a corner: two", Home.reach("sampler", Vector2i(0, 3)) == [Vector2i(0, 2), Vector2i(1, 3)],
		Home.reach("sampler", Vector2i(0, 3)))
	var lanes := Home.reach("watchtower", Vector2i(2, 3))
	check("lanes: the battle line's six plots in its column and the two beside", lanes.size() == 6
		and lanes.all(func(p: Vector2i) -> bool: return Home.front(p) and p.x >= 1 and p.x <= 3), lanes)
	check("lanes at the edge: four", Home.reach("vanguard", Vector2i(5, 2)).size() == 4)
	check("a red: its neighbours; a green in front: the one behind it; a blue in the second row: the one in front;"
		+ " a gold: either side; a white: the other of its column", Home.reach("nest_red", Vector2i(2, 0)).size() == 3
		and Home.reach("nest_green", Vector2i(2, 0)) == [Vector2i(2, 1)] and Home.reach("nest_green", Vector2i(2, 1)).is_empty()
		and Home.reach("nest_blue", Vector2i(2, 1)) == [Vector2i(2, 0)] and Home.reach("nest_gold", Vector2i(0, 0)) == [Vector2i(1, 0)]
		and Home.reach("nest_white", Vector2i(3, 1)) == [Vector2i(3, 0)])
	check("the scavenger's and the mutant's gifts work anywhere: no reach", Home.reach("nest_scav", Vector2i(1, 0)).is_empty()
		and Home.reach("nest_mutant", Vector2i(1, 0)).is_empty())
	check("every building but a nest has its reach", Content.BUILDINGS.keys().all(func(k: String) -> bool:
		return Content.is_nest(k) or Content.REACH.has(Content.BUILDINGS[k].get("reach", ""))))
	var odd := 0
	for kind in Content.BUILDINGS:
		for q in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(5, 2), Vector2i(3, 3)]:
			var r := Home.reach(kind, q)
			for y in Home.ROWS:
				for x in Home.COLS:
					var p := Vector2i(x, y)
					if p != q and Home.reaches(kind, q, p) != (p in r):
						odd += 1
	check("reaches says what reach lists", odd == 0, odd)


## Each nest's gift, where it stands (GAME-DESIGN 20).
func _nest_gifts() -> void:
	# Guarding: a green in front keeps theirs off the one behind it in its column while it stands.
	var g := bare()
	g.build(Vector2i(0, 0), "nest_green")
	g.build(Vector2i(0, 1), "nest_red")
	g.build(Vector2i(1, 1), "nest_green")
	check("a green in front guards; in the second row it does not", g.spec_of(Vector2i(0, 0)).guard
		and not g.spec_of(Vector2i(1, 1)).guard and g.trait_need(Vector2i(1, 1)) == "要站第一排")
	var gf := Fight.make(g.army(), ["grey", "grey", "grey", "grey", "purple"], 1.0)
	var bad := 0
	var on_guard := 0
	while not gf.over:
		var up := gf.alive("ours").any(func(u: Dictionary) -> bool: return u.get("guard", false))
		for e in gf.step():
			if e.t == "hit":
				var to: Dictionary = gf.unit(e.to)
				if to.side == "ours" and int(to.row) == 1 and float(to.lane) == 0.0 and up:
					bad += 1
				if to.side == "ours" and to.get("guard", false):
					on_guard += 1
	check("while the green stands, the red behind it is not hit; the green is", bad == 0 and on_guard > 0, [bad, on_guard])
	# Cover: a blue in the second row with a nest in front of it reaches further and hits through armour.
	var c := bare()
	c.build(Vector2i(1, 0), "nest_red")
	c.build(Vector2i(1, 1), "nest_blue")
	c.build(Vector2i(2, 1), "nest_blue")
	c.build(Vector2i(3, 0), "nest_blue")
	var cs := Content.unit_stats(c.spec_of(Vector2i(1, 1)))
	var bare_blue := Content.unit_stats(c.spec_of(Vector2i(2, 1)))
	check("a blue under cover: 2 m further, 1 more each hit", is_equal_approx(float(cs.range), 8.0) and int(cs.pierce) == 1
		and is_equal_approx(float(bare_blue.range), 6.0) and int(bare_blue.pierce) == 0, [cs.range, cs.pierce, bare_blue.range])
	check("no cover: nothing in front; in front: not the second row", c.trait_need(Vector2i(2, 1)) == "身前同一列还没有巢"
		and c.trait_need(Vector2i(3, 0)) == "要站第二排", [c.trait_need(Vector2i(2, 1)), c.trait_need(Vector2i(3, 0))])
	c.buildings[Vector2i(1, 1)].affixes = ["blade", "wings"]
	check("a blue nest hatching fliers: no cover for those that do not reach far",
		is_equal_approx(float(Content.unit_stats(c.spec_of(Vector2i(1, 1))).range), float(Content.UNITS.falcon.range)))
	# Alone: a gold with no nest left or right of it is bigger and stronger.
	var a := bare()
	a.build(Vector2i(2, 0), "nest_gold")
	a.build(Vector2i(2, 1), "nest_red")
	var lone := a.spec_of(Vector2i(2, 0))
	check("a gold alone (one behind it does not count): +30% hit points and attack, bigger",
		is_equal_approx(float(lone.hp_mult), Content.ALONE) and is_equal_approx(float(lone.atk_mult), Content.ALONE)
		and is_equal_approx(float(lone.size_mult), Content.ALONE_SIZE))
	a.build(Vector2i(3, 0), "nest_red")
	check("with a nest beside it, no more", is_equal_approx(float(a.spec_of(Vector2i(2, 0)).hp_mult), 1.0)
		and a.trait_need(Vector2i(2, 0)) == "左右有巢挨着")
	# Care: a white heals twice as much, only its own column.
	var w := bare()
	w.build(Vector2i(0, 0), "nest_green")
	w.build(Vector2i(0, 1), "nest_white")
	w.build(Vector2i(1, 0), "nest_red")
	w.build(Vector2i(3, 1), "nest_red")
	check("a white heals 3 x 2", int(Content.unit_stats(w.spec_of(Vector2i(0, 1))).heal) == 3 * Content.CARE)
	var wf := Fight.make(w.army(), ["grey", "grey", "grey", "grey", "grey"], 1.0)
	var heals := 0
	var astray := 0
	for e in wf.run():
		if e.t == "heal":
			heals += 1
			if not is_equal_approx(float(wf.unit(e.to).lane), 0.0):
				astray += 1
	check("it heals only its own column", heals > 0 and astray == 0, [heals, astray])
	# Scavenging: those standing at the end bring back gold.
	var s := bare()
	s.build(Vector2i(2, 1), "nest_scav")
	s.buildings[Vector2i(2, 1)].path = ["count"]
	s.build(Vector2i(2, 0), "nest_green")
	var sf := Fight.make(s.army(), ["mite"], 1.0)
	sf.run()
	check("two scavengers standing: 2 gold each", sf.result == "won" and sf.scavenged() == 2 * Content.SCAVENGE,
		[sf.result, sf.scavenged()])
	var r := Run.new(5)
	r.home.buildings.clear()
	r.home.build(Vector2i(2, 1), "nest_scav")
	r.home.build(Vector2i(2, 0), "nest_green")
	var before := r.home.gold
	var rf := Fight.make(r.home.army(Home.ALL), [], 1.0)
	rf.run()
	var out := r.finish(rf)
	check("and the run gets it", int(out.scavenged) == Content.SCAVENGE
		and r.home.gold == before + Content.WIN_GOLD + Content.SCAVENGE, [out, r.home.gold - before])
	# Mutant: one more affix place.
	var m := bare()
	m.build(Vector2i(0, 0), "nest_mutant")
	m.build(Vector2i(1, 0), "nest_red")
	check("a mutant nest carries two affixes, a red one", m.slots(Vector2i(0, 0)) == 2 and m.slots(Vector2i(1, 0)) == 1)
	check("the cards say each gift", Content.building_text("nest_blue", 1).contains("掩护射击")
		and Content.building_text("nest_mutant", 1).contains("变异"))


func _terrain() -> void:
	var h := bare()
	h.terrain = {Vector2i(0, 2): "pond", Vector2i(2, 3): "tree", Vector2i(4, 2): "ore", Vector2i(5, 3): "lava"}
	h.build(Vector2i(0, 2), "pool")
	check("pond: a pool on it makes double", h.income_biomass() == Content.HOME_POP + 6, h.income_biomass())
	h.build(Vector2i(4, 2), "mine")
	h.build(Vector2i(5, 2), "mine")
	check("ore: a mine on it 2 more; lava: a mine beside it 1 more", h.income_gold() == (1 + 2) + (1 + 1),
		h.income_gold())
	h.build(Vector2i(2, 2), "sampler")
	check("a tree beside a sampler: a gene more", h.income_genes() == 1 + Content.TREE_GENES, h.income_genes())
	check("trees and lava: nothing built there", not h.buildable(Vector2i(2, 3)) and not h.buildable(Vector2i(5, 3)))
	h.plans = ["b_sampler"]
	check("buildings only where they can stand", not Vector2i(2, 3) in h.targets("b_sampler")
		and Vector2i(1, 3) in h.targets("b_sampler"))
	var t := bare()
	t.terrain = {Vector2i(0, 2): "mire", Vector2i(2, 3): "toadstool", Vector2i(4, 2): "ice_ore", Vector2i(5, 3): "wreck"}
	t.build(Vector2i(0, 2), "pool")
	t.build(Vector2i(4, 2), "mine")
	t.build(Vector2i(5, 2), "mine")
	t.build(Vector2i(2, 2), "sampler")
	check("each place's ground works one of four ways: a mire as a pond, toadstools as a tree, ice ore as ore, a wreck as lava",
		t.income_biomass() == Content.HOME_POP + 6 and t.income_genes() == 1 + Content.TREE_GENES
		and t.income_gold() == (1 + 2) + (1 + 1), [t.income_biomass(), t.income_genes(), t.income_gold()])
	check("toadstools and wrecks: nothing built there", not t.buildable(Vector2i(2, 3)) and not t.buildable(Vector2i(5, 3)))


func _affixes_and_recipes() -> void:
	var h := bare()
	h.build(Vector2i(2, 1), "nest_red")
	h.plans = ["a_shell", "a_acid", "a_poison"]
	check("affix goes on a nest", h.targets("a_shell") == [Vector2i(2, 1)], h.targets("a_shell"))
	h.build_plan("a_shell", Vector2i(2, 1))
	check("paid 3 gold, no research points", h.gold == 17 and h.genes == 10, [h.gold, h.genes])
	check("one place only", h.targets("a_acid").is_empty())
	h.build(Vector2i(2, 2), "stabilizer")
	h.build(Vector2i(2, 3), "stabilizer")
	h.build_plan("a_acid", Vector2i(2, 1))
	check("acid: reach 5", float(Content.unit_stats(h.army()[0]).range) == 5.0)
	h.build_plan("a_poison", Vector2i(2, 1))
	var s := h.spec_of(Vector2i(2, 1))
	check("acid + poison: a miasma beast", s.kind == "miasma" and s.evolved, s.kind)
	var st := Content.unit_stats(s)
	check("the shell still counts, the acid is in it", int(st.armor) == 1 and int(st.pierce) == 2 and float(st.range) == 5.0,
		[st.armor, st.pierce])
	check("it eats 2", h.army_food() == 2, h.army_food())
	check("one half of a recipe tells the other", Content.could_become(["blade"]).any(func(c: Array) -> bool:
		return c[1] == "falcon"))
	var f := bare()
	f.build(Vector2i(0, 0), "nest_red")
	f.buildings[Vector2i(0, 0)].affixes = ["wings", "blade"]
	var fl := Content.unit_stats(f.army()[0])
	check("blade + wings: a falcon, flying, not blade twice", f.army()[0].kind == "falcon" and fl.dive
		and int(fl.atk) == int(Content.UNITS.falcon.atk), [f.army()[0].kind, fl.atk])
	var n := bare()
	n.build(Vector2i(0, 0), "nest_red")
	n.buildings[Vector2i(0, 0)].affixes = ["haste"]
	check("haste: 30% faster", is_equal_approx(float(Content.unit_stats(n.army()[0]).every), 1.0 / 1.3))
	n.buildings[Vector2i(0, 0)].affixes = ["hide"]
	check("hide: 40% more hit points", int(Content.unit_stats(n.army()[0]).hp) == 14)
	n.buildings[Vector2i(0, 0)].affixes = ["horn"]
	var fight := Fight.make(n.army(), ["black"], 1.0)
	var hits := fight.run().filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.from == 1)
	check("horn: the first blow twice as hard, then not", int(hits[0].dmg) == 3 * 2 - 1 and hits[0].charge
		and int(hits[1].dmg) == 3 - 1 and not hits[1].charge, hits.slice(0, 2))
	var c := bare()
	c.build(Vector2i(0, 0), "nest_red")
	c.build(Vector2i(4, 0), "nest_red")
	var shell := Content.offer({"id": "a_shell"})
	check("an affix costs gold only", c.price_at(shell, Vector2i(0, 0)) == 3 and not shell.has("genes"))
	c.build(Vector2i(1, 3), "gene_bank")
	check("a gene bank: a gold less for the nests in front of it, not the others", c.price_at(shell, Vector2i(0, 0)) == 2
		and c.price_at(shell, Vector2i(4, 0)) == 3)
	c.buildings[Vector2i(1, 3)].level = 3
	c.build(Vector2i(0, 3), "gene_bank")
	check("never below 1", c.price_at(shell, Vector2i(0, 0)) == 1)
	c.plans = ["a_shell"]
	c.gold = 1
	check("so with 1 gold it goes only there", c.targets("a_shell") == [Vector2i(0, 0)], c.targets("a_shell"))
	c.build_plan("a_shell", Vector2i(0, 0))
	check("and is paid 1", c.gold == 0, c.gold)


func _schools() -> void:
	var h := bare()
	for x in 5:
		h.build(Vector2i(x, 0), "nest_red")
	h.build(Vector2i(1, 3), "horde_totem")
	var a := h.army()
	var near := a.filter(func(u: Dictionary) -> bool: return (u.nest as Vector2i).x <= 2)
	var far := a.filter(func(u: Dictionary) -> bool: return (u.nest as Vector2i).x > 2)
	check("ten out (five reds in a row, all swarming): the totem gives +1 to those of the three columns in front of it",
		a.size() == 10 and near.size() == 6 and near.all(func(u: Dictionary) -> bool: return int(u.atk_bonus) == 1)
		and far.all(func(u: Dictionary) -> bool: return int(u.atk_bonus) == 0), a.map(func(u: Dictionary) -> int: return u.atk_bonus))
	h.build(Vector2i(2, 3), "horde_totem")
	check("two totems: +2 where both reach", int(h.army()[2].atk_bonus) == 2 and int(h.army()[0].atk_bonus) == 1
		and int(h.army()[8].atk_bonus) == 0)
	h.buildings[Vector2i(2, 3)].level = 3
	check("a totem at 3: one for every 4", h.horde_bonus(10, Vector2i(1, 0)) == 10 / 6 + 10 / 4)
	var e := bare()
	e.build(Vector2i(0, 1), "nest_red")
	e.buildings[Vector2i(0, 1)].path = ["elite"]
	e.build(Vector2i(1, 1), "nest_red")
	e.build(Vector2i(4, 1), "nest_red")
	e.buildings[Vector2i(4, 1)].path = ["elite"]
	e.build(Vector2i(0, 3), "champion_hall")
	check("champion hall: the elites in front of it 15% more, the rest nothing, an elite out of its reach nothing",
		is_equal_approx(float(e.spec_of(Vector2i(0, 1)).hp_mult), Content.ELITE_HP * 1.15)
		and is_equal_approx(float(e.spec_of(Vector2i(1, 1)).hp_mult), 1.0)
		and is_equal_approx(float(e.spec_of(Vector2i(4, 1)).hp_mult), Content.ELITE_HP))
	var r := bare()
	r.build(Vector2i(0, 1), "nest_blue")
	r.build(Vector2i(1, 1), "nest_red")
	r.build(Vector2i(2, 1), "nest_red")
	r.buildings[Vector2i(2, 1)].affixes = ["acid"]
	r.build(Vector2i(4, 1), "nest_blue")
	r.build(Vector2i(1, 3), "watchtower")
	check("watchtower: those in front of it that reach far +1 each hit, armour or not", int(r.spec_of(Vector2i(0, 1)).pierce) == 1
		and int(r.spec_of(Vector2i(1, 1)).pierce) == 0 and int(r.spec_of(Vector2i(2, 1)).pierce) == 1
		and int(r.spec_of(Vector2i(0, 1)).atk_bonus) == 0 and int(r.spec_of(Vector2i(4, 1)).pierce) == 0)
	var v := bare()
	v.build(Vector2i(0, 0), "nest_green")
	v.build(Vector2i(0, 1), "nest_green")
	v.build(Vector2i(5, 0), "nest_green")
	v.build(Vector2i(0, 2), "vanguard")
	check("vanguard camp: the front row in front of it 30% more hp, the row behind nothing, out of reach nothing",
		is_equal_approx(float(v.spec_of(Vector2i(0, 0)).hp_mult), 1.3) and is_equal_approx(float(v.spec_of(Vector2i(0, 1)).hp_mult), 1.0)
		and is_equal_approx(float(v.spec_of(Vector2i(5, 0)).hp_mult), 1.0))
	var g := bare()
	g.build(Vector2i(4, 3), "vault")
	check("vault: interest up to 1 more", g.interest_max() == Content.INTEREST_MAX + 1, g.interest_max())
	g.build(Vector2i(3, 3), "mine")
	g.build(Vector2i(4, 2), "mine")
	g.build(Vector2i(0, 2), "mine")
	check("and 1 more for each mine beside it", g.interest_max() == Content.INTEREST_MAX + 1 + 2 * Content.VAULT_MINE,
		g.interest_max())


func _buying() -> void:
	var h := bare()
	h.plans = ["b_sampler", "b_gold"]
	h.build(Vector2i(2, 2), "pool")
	h.build_plan("b_sampler", Vector2i(2, 2))
	check("over a pool: pulled down, half back", h.buildings[Vector2i(2, 2)].kind == "sampler" and h.gold == 20 - 2 + 1)
	check("built, the blueprint still there", h.targets("b_sampler").size() > 0 and "b_sampler" in h.plans)
	check("raise from level 1 costs 3", h.raise_price(Vector2i(2, 2)) == Content.RAISE + 1)
	h.buildings[Vector2i(2, 2)].level = 2
	h.raise(Vector2i(2, 2))
	check("level 3 at most, 4 paid", int(h.buildings[Vector2i(2, 2)].level) == 3 and h.gold == 19 - 4, h.gold)
	h.gold = 1
	check("not enough gold: nowhere", h.targets("b_gold").is_empty())


## The blueprints (GAME-DESIGN 27, 28): none to begin with, one more to unlock after each round for research points.
func _blueprints() -> void:
	var h := Home.new(rng())
	check("a place starts with no blueprint", h.plans.is_empty(), h.plans)
	h.unlock("b_red")
	var three := h.plan_offer(rng(1), 0, Content.REWARDS)
	check("three to choose, all different", three.size() == 3 and three[0] != three[1] and three[1] != three[2]
		and three[0] != three[2], three)
	var feeds := 0
	for s in 40:
		if h.plan_offer(rng(s), 0, Content.REWARDS).any(func(id: String) -> bool: return id in ["b_pool", "b_spore"]):
			feeds += 1
	check("while nothing had feeds more of the population, a pool always comes", feeds == 40, feeds)
	h.unlock("b_pool")
	var bad := 0
	var uncommon := 0
	for s in 60:
		for id in h.plan_offer(rng(s), 0, Content.REWARDS):
			var o: Dictionary = Content.OFFERS[id]
			if id in h.plans or int(o.get("from", 0)) > 0 or int(o.get("region", 0)) != 0:
				bad += 1
			if int(o.rarity) == 1:
				uncommon += 1
	check("none had, none from later, none of another place's; the uncommon too", bad == 0 and uncommon > 0, [bad, uncommon])
	var rare := 0
	for s in 30:
		for id in h.plan_offer(rng(s), 1, Content.REWARDS, true):
			if int(Content.OFFERS[id].rarity) < 1:
				rare += 1
	check("after a mini-boss: only the uncommon and the rare", rare == 0, rare)
	check("taken: had from now on, once", h.unlock("b_blue") and "b_blue" in h.plans and not h.unlock("b_blue"))
	var u := bare()
	u.plans = []
	u.genes = 2
	check("unlocked for research points by rarity: a common 1, an uncommon 2, a rare 3", Home.unlock_price("b_pool") == 1
		and Home.unlock_price("b_green") == 2 and Home.unlock_price("b_gold") == 3)
	check("an uncommon for 2", u.buy_plan("b_green") and u.genes == 0 and "b_green" in u.plans, [u.genes, u.plans])
	check("short of research points: not", not u.buy_plan("b_pool") and not "b_pool" in u.plans)
	var v := bare(1)
	v.plans = []
	var forge := 0
	var theirs := 0
	for s in 40:
		for id in v.plan_offer(rng(s), 1, Content.REWARDS):
			if id == "b_forge":
				forge += 1
			if int(Content.OFFERS[id].get("region", 1)) != 1:
				theirs += 1
	check("the volcano: its own forge, none of the rainforest's own", forge > 0 and theirs == 0, [forge, theirs])
	var few := bare()
	few.plans = Content.OFFERS.keys().filter(func(id: String) -> bool: return not id in ["b_blue", "b_green"])
	check("two left: two to choose", few.plan_offer(rng(), 0, Content.REWARDS).size() == 2)


func _interest() -> void:
	var h := bare()
	h.gold = 12
	check("interest: 2 for 12", h.interest() == 2)
	h.gold = 40
	check("5 at most", h.interest() == Content.INTEREST_MAX and Content.INTEREST_MAX == 5, h.interest())
	h.take_star("saver")
	h.gold = 60
	check("the saver: up to 7", h.interest() == Content.INTEREST_MAX + 2)
	var s := bare()
	s.gold = 12
	s.start_round(rng(), 0)
	check("the interest comes at the start, with the round's pay", s.gold == 12 + Home.INCOME + 2, s.gold)


## A blueprint after each round -- or gold; after a mini-boss, an uncommon or rare one (GAME-DESIGN 27).
func _rewards() -> void:
	var r := Run.new(7)
	r.start_round()
	var cards := r.reward_offer()
	check("three blueprints, all different, none had", cards.size() == Content.REWARDS and cards[0].id != cards[1].id
		and cards[1].id != cards[2].id and cards[0].id != cards[2].id
		and cards.all(func(c: Dictionary) -> bool: return not c.id in r.home.plans), cards)
	check("no research points: none had", not r.take_reward(cards[0].id) and not cards[0].id in r.home.plans)
	r.home.genes = 5
	check("the one taken is had, for its research points", r.take_reward(cards[0].id) and cards[0].id in r.home.plans
		and r.home.genes == 5 - Home.unlock_price(cards[0].id), r.home.genes)
	var gold := r.home.gold
	r.take_reward_gold()
	check("or 3 gold", r.home.gold == gold + Content.REWARD_GOLD)
	var rare := 0
	for s in 40:
		var g := Run.new(s + 1)
		g.move_on(1)
		for oi in g.reward_offer():
			if int(Content.OFFERS[oi.id].rarity) == 2:
				rare += 1
	check("later, the rare come too", rare > 0, rare)
	check("after a mini-boss: none common", r.rare_offer().all(func(c: Dictionary) -> bool:
		return int(Content.OFFERS[c.id].rarity) >= 1))
	var m := Run.new(2)
	m.round = 4
	m.start_round()
	m.make()
	m.eat()
	var f := m.fight()
	f.run()
	m.finish(f)
	check("round 4 was a mini-boss's: a rarer blueprint after it", m.over or (m.round == 5 and m.was_mini()), m.round)
	m.round = 7
	check("round 6 not", not m.was_mini())


## The star dinosaurs (GAME-DESIGN 24): one on offer each round, bought into a pen, fed each round, sold.
func _stars() -> void:
	var h := bare()
	h.start_round(rng(4), 0)
	if Content.STARS_ON:
		check("a star on offer at the round's start, none legendary", h.star_offer != ""
			and int(Content.STARS[h.star_offer].rarity) <= int(Content.STARS_FROM[0]), h.star_offer)
		var odd := 0
		for s in 60:
			var g := bare()
			g.take_star("doctor")
			g.start_round(rng(s + 10), 0)
			if g.star_offer == "doctor" or int(Content.STARS[g.star_offer].rarity) > 1:
				odd += 1
		check("never one already in a pen, nothing rare in the first place", odd == 0, odd)
	else:
		check("the stars put away: none comes", h.star_offer == "")
	h.star_offer = "mother"
	h.gold = 3
	check("not without the gold", not h.can_buy_star())
	h.gold = 10
	h.buy_star()
	check("bought: paid, in the first pen, no longer on offer", h.stars.size() == 1 and h.stars[0].id == "mother"
		and h.gold == 6 and h.star_offer == "", [h.gold, h.stars])
	for id in ["bounty", "doctor", "shield", "saver"]:
		h.take_star(id)
	h.star_offer = "tri"
	check("five pens full: no more", h.stars.size() == Content.PENS and not h.can_buy_star() and h.take_star("tri").is_empty())
	var full := bare()
	for id in ["mother", "bounty", "doctor", "shield", "saver"]:
		full.take_star(id)
	full.start_round(rng(), 0)
	check("the pens full: none comes", full.star_offer == "")
	check("no star twice", bare().take_star("tri").size() == 1 and _with(["tri"]).take_star("tri").is_empty())
	# Fed in pen order: five stars eating 1 each, but 3 biomass only reach three.
	h.biomass = 3
	var ev := h.feed()
	check("three fed, the last two without", h.hungry == [3, 4] and h.biomass == 0
		and ev[0].hungry == ["shield", "saver"], [h.hungry, ev])
	check("the shield without: no hit points more", h.hp_max() == Home.HP)
	check("what they eat, all told", h.star_food() == 5)
	h.biomass = 10
	h.feed()
	check("fed again next round: all", h.hungry.is_empty() and h.biomass == 5 and h.hp_max() == Home.HP + 10)
	h.hungry = [1]
	var back := h.sell_price(0)
	h.sell_star(0)
	check("sold: half its price back, the pens closing up, the hungry one still hungry", back == 2 and h.gold == 6 + 2
		and h.stars[0].id == "bounty" and h.hungry == [0], [h.gold, h.hungry])

## Each star's own ability (Content.STARS).
func _star_kinds() -> void:
	var m := _with(["mother"])
	m.build(Vector2i(0, 0), "nest_red")
	m.build(Vector2i(4, 0), "nest_blue")
	var a := m.army()
	check("the mother: the first nest one more, free", a.size() == 3 and a[1].free and not a[2].free)
	var b := _with(["belly", "fisher"])
	b.build(Vector2i(0, 2), "pool")
	b.make()
	b.eat()
	check("the belly: 4 more a round, the fisher a pool one more; neither eats", b.income_biomass() == Content.HOME_POP + 4 + 3 + 1
		and b.biomass == Content.HOME_POP + 8 and b.hungry.is_empty(), [b.income_biomass(), b.biomass])
	var sh := _with(["shield"])
	sh.hp = 20
	sh.make()
	check("the shield: 10 more hit points, one back a round", sh.hp_max() == Home.HP + 10 and sh.hp == 21, sh.hp)
	var t := _with(["tri"])
	t.build(Vector2i(0, 0), "nest_red")
	t.build(Vector2i(0, 1), "nest_red")
	check("the triceratops: the front row armour 1, not the second", int(t.spec_of(Vector2i(0, 0)).armor) == 1
		and int(t.spec_of(Vector2i(0, 1)).armor) == 0)
	for id in ["mother", "shield"]:
		t.take_star(id)
	check("three plant-eaters: armour 2", int(t.spec_of(Vector2i(0, 0)).armor) == 2)
	var sc := _with(["scar"])
	sc.build(Vector2i(0, 0), "nest_red")
	sc.build(Vector2i(1, 0), "nest_blue")
	check("scar: red units +1, not blue", int(sc.spec_of(Vector2i(0, 0)).atk_bonus) == 1 and int(sc.spec_of(Vector2i(1, 0)).atk_bonus) == 0)
	for id in ["bounty", "doctor"]:
		sc.take_star(id)
	check("three meat-eaters: +2", int(sc.spec_of(Vector2i(0, 0)).atk_bonus) == 2)
	var ho := _with(["horn"])
	ho.build(Vector2i(0, 0), "nest_red")
	check("the horn: 15% quicker", int(ho.spec_of(Vector2i(0, 0)).haste) == 15)
	var sp := _with(["spitter"])
	sp.build(Vector2i(0, 0), "nest_blue")
	sp.build(Vector2i(1, 0), "nest_red")
	var far := sp.spec_of(Vector2i(0, 0))
	check("the spitter: the far-reaching a metre further, a point through armour; the near ones not",
		float(far.range) == float(Content.UNITS.blue.range) + 1.0 and int(far.pierce) == 1
		and int(sp.spec_of(Vector2i(1, 0)).pierce) == 0, [far.range, far.pierce])
	var ok := _with(["oldking"])
	ok.build(Vector2i(0, 0), "nest_red")
	for k in 6:
		ok.boss_beaten()
	check("the old king: +1 a boss beaten, up to 4", int(ok.stars[0].grow) == 4 and int(ok.spec_of(Vector2i(0, 0)).atk_bonus) == 4)
	ok.hungry = [0]
	check("hungry: not growing, not giving", int(ok.spec_of(Vector2i(0, 0)).atk_bonus) == 0)
	var nk := _with(["neck"])
	for k in 3:
		nk.make()
	check("the neck: a biomass more each round it has been here", nk.income_biomass() == Content.HOME_POP + 3, nk.income_biomass())
	var si := _with(["sickle"])
	si.build(Vector2i(0, 0), "nest_red")
	si.hp = 20
	si.biomass = 5
	si.eat()
	check("the sickle: an affix place more, a hit point a round (in the eating)", si.slots(Vector2i(0, 0)) == 2 and si.hp == 19,
		si.hp)
	si.hp = 1
	si.biomass = 5
	si.eat()
	check("never kills", si.hp == 1)
	var q := _with(["queen"])
	q.build(Vector2i(0, 0), "nest_red")
	check("the queen: every nest one more, a tenth less hit points", q.army().size() == 2
		and is_equal_approx(float(q.spec_of(Vector2i(0, 0)).hp_mult), 0.9))
	var fb := _with(["firstbird"])
	fb.build(Vector2i(0, 0), "nest_red")
	check("the first bird: an affix place more", fb.slots(Vector2i(0, 0)) == 2)
	var w := _with(["warlord"])
	w.build(Vector2i(0, 0), "nest_red")
	var s := w.spec_of(Vector2i(0, 0))
	check("the warlord: +2 attack, a quarter more hit points", int(s.atk_bonus) == 2 and is_equal_approx(float(s.hp_mult), 1.25))
	var ti := _with(["titan"])
	ti.build(Vector2i(0, 0), "nest_red")
	var titan: Array = ti.army().filter(func(u: Dictionary) -> bool: return u.kind == "titan")
	check("the titan: a titan, free, in the middle of the front row", titan.size() == 1 and titan[0].free
		and int(titan[0].row) == 0 and is_equal_approx(float(titan[0].lane), (Home.COLS - 1) * 0.5))
	var r := Run.new(5)
	r.home.take_star("bounty")
	r.home.buildings.clear()
	var before := r.home.gold
	var f := Fight.make([], [], 1.0)
	f.run()
	var out := r.finish(f)
	check("the bounty hunter: 2 gold more for a battle won", f.result != "won" or int(out.gold) == Content.WIN_GOLD + 2, out)
	var gr := Run.new(5)
	gr.home.take_star("oldking")
	gr.round = 4
	var gf := Fight.make([], [], 1.0)
	gf.run()
	gr.finish(gf)
	check("a mini-boss beaten grows the old king", gf.result != "won" or int(gr.home.stars[0].grow) == 1, gr.home.stars)



func _moving_on() -> void:
	var r := Run.new(6)
	r.start_round()
	var h := r.home
	h.build(Vector2i(0, 1), "nest_blue")
	h.take_star("doctor")
	h.take_star("neck")
	h.stars[1].grow = 3
	h.unlock("b_green")
	h.gold = 17
	h.genes = 9
	h.hp = 12
	r.round = Content.ROUNDS
	r.move_on(1)
	check("on to the volcano", r.level == 1 and r.place == 1 and r.round == 1 and h.region == 1 and r.path == [0, 1])
	check("the homeland made afresh: nothing built, its first nest to pick from three", h.buildings.is_empty()
		and r.nest_offer().size() == 3)
	check("the volcano's ground, behind the line", h.terrain.values().all(func(t: String) -> bool: return t in ["ore", "lava"])
		and h.terrain.size() == 5 and h.terrain.keys().all(func(p: Vector2i) -> bool: return not Home.front(p)))
	check("nothing carried (the player, 2026-10-21): no stars, gold, research points or blueprints; the hit points whole",
		h.stars.is_empty() and h.gold == 0 and h.genes == 0 and h.plans.is_empty() and h.hp == Home.HP,
		[h.stars, h.gold, h.genes, h.plans, h.hp])

## The map: the rainforest, then two places to pick one of for each level after it, none twice (GAME-DESIGN 22).
func _map() -> void:
	var bad := 0
	for s in 30:
		var m := Run.new(s + 1)
		var later: Array = m.map[1] + m.map[2]
		var distinct := {}
		for p in later:
			distinct[p] = true
		if m.map.size() != Content.TIERS or m.map[0] != [0] or later.size() != 4 or distinct.size() != 4 or 0 in later:
			bad += 1
	check("the rainforest, then two to pick from, twice, none twice", bad == 0, bad)
	var r := Run.new(8)
	check("first the second level's two", r.next_places() == r.map[1] and not r.last_level())
	var to: int = r.map[1][1]
	r.move_on(to)
	check("on to the one picked", r.place == to and r.home.region == to and r.level == 1 and r.path == [0, to])
	check("its own ground", r.home.terrain.values().all(func(t: String) -> bool: return Content.LEVELS[to].terrain.has(t)))
	r.round = 3
	check("its own wave, as strong as the second level", r.wave() == Content.wave(to, 1, 3)
		and is_equal_approx(r.power(), Content.TIER_POWER[1]))
	check("then the third level's two", r.next_places() == r.map[2])
	r.move_on(int(r.map[2][0]))
	check("the third level the last", r.last_level() and r.next_places().is_empty() and r.path.size() == 3)


func _formation() -> void:
	var h := bare()
	h.build(Vector2i(0, 0), "nest_green")
	h.build(Vector2i(5, 1), "nest_blue")
	var f := Fight.make(h.army(), ["grey"], 1.0)
	var g: Dictionary = f.units[0]
	var b: Dictionary = f.units[1]
	check("the top row stands in front, the row behind further back", is_equal_approx((g.pos as Vector2).x, -Fight.OUR_FRONT)
		and is_equal_approx((b.pos as Vector2).x, -(Fight.OUR_FRONT + Fight.ROW_GAP)), [g.pos, b.pos])
	check("the left column on the far lane, the right one near", (g.pos as Vector2).y < 0.0 and (b.pos as Vector2).y > 0.0)
	var two := bare()
	two.build(Vector2i(2, 0), "nest_green")
	two.build(Vector2i(2, 1), "nest_red")
	var f2 := Fight.make(two.army(), ["grey"], 1.0)
	var first: Dictionary = f2.run().filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.from == 3).front()
	check("the enemy meets the front row first", first.to == 1, first)
	var many := bare()
	many.build(Vector2i(3, 0), "nest_red")
	many.buildings[Vector2i(3, 0)].path = ["count", "count"]
	var f3 := Fight.make(many.army(), ["grey"], 1.0)
	var zs: Array = f3.units.filter(func(u: Dictionary) -> bool: return u.side == "ours").map(func(u: Dictionary) -> float:
		return (u.pos as Vector2).y)
	check("a nest's three stand side by side in its lane", zs.size() == 3 and zs[0] < zs[1] and zs[1] < zs[2], zs)


func _fights() -> void:
	var h := bare()
	h.build(Vector2i(0, 0), "nest_red")
	h.buildings[Vector2i(0, 0)].path = ["count", "count"]
	var f1 := Fight.make(h.army(), ["grey", "grey", "purple"], 1.0)
	var f2 := Fight.make(h.army(), ["grey", "grey", "purple"], 1.0)
	var e1 := f1.run()
	f2.run()
	check("the same each time", f1.result == f2.result and f1.time == f2.time and e1.size() > 0)
	var lone := Fight.make([], ["grey"], 1.0)
	lone.run()
	check("no army: lost", lone.result == "lost" and lone.harm() == 1)
	var w := bare()
	w.build(Vector2i(0, 0), "nest_green")
	w.build(Vector2i(0, 1), "nest_white")
	check("the white heals", Fight.make(w.army(), ["grey", "grey"], 1.0).run().any(func(e: Dictionary) -> bool:
		return e.t == "heal"))


func _falling_hard() -> void:
	var h := bare()
	h.build(Vector2i(0, 0), "nest_red")
	h.buildings[Vector2i(0, 0)].path = ["count", "count"]
	var f := Fight.make(h.army(), ["spore"], 1.0)
	var ev := f.run()
	var spawned := ev.filter(func(e: Dictionary) -> bool: return e.t == "spawn")
	check("a spore breaks into two mites", spawned.size() == 2 and spawned[0].unit.kind == "mite", spawned.size())
	check("and they are fought too", f.result == "won" and f.units.size() == 3 + 3, [f.result, f.units.size()])
	var b := bare()
	b.build(Vector2i(0, 0), "nest_red")
	var g := Fight.make(b.army(), ["beetle"], 1.0)
	var eb := g.run()
	check("a beetle bursts when it falls", eb.any(func(e: Dictionary) -> bool: return e.t == "burst") or g.result != "won")
	var p := bare()
	p.build(Vector2i(0, 0), "nest_red")
	p.buildings[Vector2i(0, 0)].affixes = ["poison"]
	var fp := Fight.make(p.army(), ["beetle"], 1.0)
	var hit: Dictionary = fp.run().filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.from == 1).front()
	check("poison: 2 more through armour 2", int(hit.dmg) == maxi(1, 3 - 2) + 2, hit.dmg)
	check("strength counts what it breaks into", Content.enemy_strength("spore") > Content.strength(Content.enemy_stats("spore")) - 0.01
		and Content.enemy_strength("spore") > 10.0)


func _run_flow() -> void:
	var r := Run.new(9)
	r.start_round()
	r.make()
	r.eat()
	var gold := r.home.gold
	var f := r.fight()
	check("the young fed are the ones that fight", f.alive("ours").size() == r.home.fighters.size())
	f.run()
	var out := r.finish(f)
	check("round 1: a result", out.result in ["won", "lost", "time"], out)
	check("gold: kept, won, brought back -- the interest comes at the next start", r.home.gold == gold + int(out.gold)
		+ int(out.scavenged) and not out.has("interest"))
	var g := Run.new(4)
	g.round = Content.ROUNDS
	g.start_round()
	g.make()
	g.eat()
	var w := g.fight()
	w.run()
	var o := g.finish(w)
	check("the last round ends the place or the run", o.level_won or g.over, [o, g.home.hp])
	check("a run: three levels of 12 rounds, out of six places", Content.TIERS == 3 and Content.ROUNDS == 12
		and Content.LEVELS.size() == 6)


func _economy() -> void:
	check("only what lasts on sale", Content.OFFERS.values().all(func(o: Dictionary) -> bool:
		return o.type in ["build", "raise", "affix"]))
	check("no gym, wall, vine wall, hot spring", not Content.BUILDINGS.has("gym") and not Content.BUILDINGS.has("wall")
		and not Content.BUILDINGS.has("vine_wall") and not Content.BUILDINGS.has("hot_spring"))
	check("no building but a school's makes units stronger", Content.BUILDINGS.values().all(func(b: Dictionary) -> bool:
		return b.has("nest") or b.levels.all(func(l: Dictionary) -> bool:
			return not l.has("drill") and not l.has("haste") and not l.has("hp"))))
	var r := Run.new(12)
	r.start_round()
	check("round 1: 5 gold", r.home.gold == 5, r.home.gold)
	r.make()
	r.eat()
	r.home.gold = 0
	var f := r.fight()
	f.run()
	var research := r.home.genes
	var out := r.finish(f)
	check("a battle won: 2 gold; won or lost, a research point", r.home.genes == research + 1 and (f.result != "won"
		or (out.gold == 2 and r.home.gold == 2)), [f.result, out])
	var piles := bare()
	piles.build(Vector2i(0, 2), "pool")
	piles.build(Vector2i(1, 2), "sampler")
	piles.biomass = 40
	piles.genes = 30
	piles.make()
	check("research points pile up; the biomass is each round's own", piles.biomass == Content.HOME_POP + 3
		and piles.genes == 30 + 1 + Content.SAMPLER_POOL, [piles.biomass, piles.genes])


func _clone() -> void:
	var h := Home.new(rng())
	h.unlock("b_red")
	h.build(Vector2i(2, 0), "nest_red")
	h.start_round(rng(), 0)
	h.gold = 20
	var c := h.clone()
	c.build(Vector2i(0, 0), "nest_red")
	c.unlock("b_pool")
	c.build_plan("b_pool", c.targets("b_pool")[0])
	c.unlock("b_blue")
	c.take_star("doctor")
	c.hungry = [0]
	c.gold = 40
	check("the copy changes alone", not h.buildings.has(Vector2i(0, 0)) and h.buildings.size() == 1
		and h.stars.is_empty() and h.hungry.is_empty() and h.terrain == c.terrain and h.plans == ["b_red"]
		and h.gold == 20)
	h.biomass = 5
	var f1 := Fight.make(h.army(), ["grey", "grey"], 1.0)
	var f2 := Fight.make(h.clone().army(), ["grey", "grey"], 1.0)
	f1.run()
	f2.run()
	check("a copy fights the same", f1.result == f2.result and f1.time == f2.time)


## The waves (GAME-DESIGN 22): every place at every level, the mini-bosses in rounds 4 and 8, the boss in the last.
func _waves() -> void:
	var empty := 0
	var bosses := 0
	var minis := 0
	var stray := 0
	for place in Content.LEVELS.size():
		var lv: Dictionary = Content.LEVELS[place]
		for tier in Content.TIERS:
			for r in range(1, Content.ROUNDS + 1):
				var w := Content.wave(place, tier, r)
				if w.is_empty():
					empty += 1
				if r == Content.ROUNDS:
					bosses += 1 if lv.boss in w else 0
				elif r in Content.MINI_ROUNDS:
					minis += 1 if lv.minis[Content.MINI_ROUNDS.find(r)] in w else 0
				else:
					stray += w.filter(func(k: String) -> bool: return k == lv.boss or k in lv.minis).size()
	var n := Content.LEVELS.size() * Content.TIERS
	check("a wave every round, every place, every level", empty == 0, empty)
	check("the last round: the place's boss", bosses == n, bosses)
	check("rounds 4 and 8: its two mini-bosses", minis == n * Content.MINI_ROUNDS.size(), minis)
	check("no mini-boss or boss in the other rounds", stray == 0, stray)
	check("each place its own kinds", Content.wave(0, 0, 6).any(func(k: String) -> bool: return k == "spore")
		and Content.wave(1, 0, 6).any(func(k: String) -> bool: return k == "beetle" or k == "salamander"))
	var own := 0
	for place in range(2, Content.LEVELS.size()):
		var kinds: Array = Content.LEVELS[place].mix.map(func(m: Array) -> String: return m[0])
		if Content.wave(place, 1, 6).any(func(k: String) -> bool: return k != "grey" and k in kinds):
			own += 1
	check("the four new places their own monsters", own == 4, own)
	# Every level being begun from nothing (GAME-DESIGN 26), the second comes about as strong as the first, round for
	# round, and stronger later on as its own curve rises -- never weaker but for what one monster more or less makes
	# of it (a tenth at most, past the first two rounds, where a wave is two or three).
	var weaker := 0
	for place in Content.LEVELS.size():
		for r in range(3, Content.ROUNDS + 1):
			if _strength(Content.wave(place, 1, r), 1) < 0.9 * _strength(Content.wave(place, 0, r), 0):
				weaker += 1
	check("the second level never weaker, round for round past its first two", weaker == 0, weaker)
	var first := Content.danger(Content.wave(0, 0, 1))
	var last := Content.danger(Content.wave(0, 2, Content.ROUNDS), Content.TIER_POWER[2])
	check("danger: a skull or two at first, five or six at the end", first <= 2 and last >= 5 and last <= 6, [first, last])


func _strength(kinds: Array, tier: int) -> float:
	var s := 0.0
	for k in kinds:
		s += Content.enemy_strength(k, Content.TIER_POWER[tier])
	return s


func _texts() -> void:
	for id in Content.OFFERS:
		var o := Content.offer({"id": id})
		check("text for " + id, Content.offer_text(o).length() > 3 and str(o.name) != "", Content.offer_text(o))
	for kind in Content.BUILDINGS:
		for l in range(1, Content.LEVEL_MAX + 1):
			check("building text %s %d" % [kind, l], Content.building_text(kind, l) != "" and Content.level_text(kind, l) != "")
		var b: Dictionary = Content.BUILDINGS[kind]
		check("a school for " + kind, b.has("nest") or Content.SCHOOLS.has(b.get("school", "")))
	for id in Content.STARS:
		var s: Dictionary = Content.STARS[id]
		check("star " + id, s.says != "" and s.name != "" and Content.DIETS.has(s.diet) and int(s.price) > 0
			and int(s.eat) >= 0 and int(s.rarity) in [0, 1, 2, 3])
	check("the legendary ones dear, the common cheap", Content.STARS.values().all(func(s: Dictionary) -> bool:
		return int(s.price) >= 14 if int(s.rarity) == 3 else int(s.price) <= 9))
	for id in Content.TERRAIN:
		check("terrain " + id, Content.TERRAIN[id].says != "")
	check("every blueprint in a group of the bar", Content.OFFERS.keys().all(func(id: String) -> bool:
		return Content.GROUPS.has(Content.group_of(id))))
	for l in Content.LEVELS:
		check("ground of " + l.name, l.terrain.keys().all(func(t: String) -> bool: return Content.TERRAIN.has(t)))
		check("foes of " + l.name, Content.ENEMIES.has(l.boss) and l.minis.size() == 2
			and l.minis.all(func(k: String) -> bool: return Content.ENEMIES.has(k))
			and l.mix.all(func(m: Array) -> bool: return Content.ENEMIES.has(m[0])))
