extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run; GAME-DESIGN 17-24) on set-up cases, headless:
##
##   Godot --headless --path dino-raid --script res://tools/test_home.gd

var failed := 0
var passed := 0


func _init() -> void:
	_first_round()
	_zones()
	_making()
	_neighbours()
	_nest_gifts()
	_terrain()
	_affixes_and_recipes()
	_schools()
	_buying()
	_stash()
	_shelf()
	_deck()
	_reroll_and_interest()
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


## A homeland with nothing built and no special ground, in the first place, plenty of everything.
func bare(region := 0) -> Home:
	var h := Home.new(rng())
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


func shelf(h: Home, ids: Array) -> void:
	h.shelf = ids.map(func(id: String) -> Dictionary: return {"id": id})


func _first_round() -> void:
	var h := Home.new(rng())
	check("lands a red nest on the battle line, a pool behind it", h.buildings.size() == 2
		and h.buildings[Vector2i(2, 0)].kind == "nest_red" and h.buildings[Vector2i(2, 2)].kind == "pool", h.buildings.keys())
	check("special ground lies behind the battle line", h.terrain.size() == 5
		and h.terrain.keys().all(func(p: Vector2i) -> bool: return p.y >= Content.FRONT_ROWS) and not h.terrain.has(Vector2i(2, 2)),
		h.terrain)
	h.start_round(rng(), 0)
	check("income: 5 gold, 3 biomass", h.gold == 5 and h.biomass == 3 + 3, [h.gold, h.biomass])
	check("a shelf of 5, a star after it", h.shelf.size() == Content.SHOP and h.star_offer != "", [h.shelf.size(), h.star_offer])
	var a := h.army()
	check("one red this round, in the front row, its column its lane", a.size() == 1 and a[0].kind == "red"
		and int(a[0].row) == 0 and is_equal_approx(float(a[0].lane), 2.0), a)


func _zones() -> void:
	var h := bare()
	shelf(h, ["b_red", "b_pool"])
	check("a nest only on the battle line", h.targets(0).size() == Home.COLS * Content.FRONT_ROWS
		and h.targets(0).all(func(p: Vector2i) -> bool: return Home.front(p)), h.targets(0))
	check("anything else only behind it", h.targets(1).size() == Home.COLS * (Home.ROWS - Content.FRONT_ROWS)
		and h.targets(1).all(func(p: Vector2i) -> bool: return not Home.front(p)), h.targets(1))
	h.stash = [{"id": "b_blue"}]
	check("a kept nest too", h.stash_targets(0).all(func(p: Vector2i) -> bool: return Home.front(p)))


func _making() -> void:
	var h := bare()
	h.build(Vector2i(0, 0), "nest_red")
	check("level 1: one", h.army().size() == 1)
	shelf(h, ["raise"])
	h.buy(0, Vector2i(0, 0), "count")
	check("raised for one more: two", h.army().size() == 2 and int(h.buildings[Vector2i(0, 0)].level) == 2
		and h.gold == 20 - 3, [h.army().size(), h.gold])
	shelf(h, ["raise"])
	h.buy(0, Vector2i(0, 0), "elite")
	var a := h.army()
	check("then elite: still two, half again the hit points, a quarter more attack, bigger", a.size() == 2
		and is_equal_approx(float(a[0].hp_mult), Content.ELITE_HP) and is_equal_approx(float(a[0].atk_mult), Content.ELITE_ATK)
		and is_equal_approx(float(a[0].size_mult), Content.ELITE_SIZE) and h.gold == 17 - 4, [a.size(), h.gold])
	var st := Content.unit_stats(a[0])
	check("an elite red: 15 hp, 4 attack", int(st.hp) == 15 and int(st.atk) == 4, [st.hp, st.atk])
	shelf(h, ["raise"])
	check("level 3 at most", h.targets(0).is_empty())
	var e := bare()
	e.build(Vector2i(0, 0), "nest_red")
	e.buildings[Vector2i(0, 0)].level = 3
	e.buildings[Vector2i(0, 0)].path = ["elite", "elite"]
	var one := e.army()
	check("elite twice: one, much stronger, eating one", one.size() == 1 and e.army_food() == 1
		and is_equal_approx(float(one[0].hp_mult), Content.ELITE_HP * Content.ELITE_HP))
	h.biomass = 1
	check("biomass short: as many as it pays for", h.army().size() == 1, h.army().size())
	var made := h.produce()
	check("produce pays", made.size() == 1 and h.biomass == 0, [made.size(), h.biomass])


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
	check("a stabilizer helps the nests of its column only", s.slots(Vector2i(4, 0)) == 2, s.slots(Vector2i(4, 0)))


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
	var rf := Fight.make(r.home.army(), [], 1.0)
	rf.run()
	var out := r.finish(rf)
	check("and the run gets it", int(out.scavenged) == Content.SCAVENGE
		and r.home.gold == before + Content.WIN_GOLD + Content.SCAVENGE + int(out.interest), [out, r.home.gold - before])
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
	check("pond: a pool on it makes double", h.income_biomass() == 6, h.income_biomass())
	h.build(Vector2i(4, 2), "mine")
	h.build(Vector2i(5, 2), "mine")
	check("ore: a mine on it 2 more; lava: a mine beside it 1 more", h.income_gold() == Home.INCOME + (1 + 2) + (1 + 1),
		h.income_gold())
	h.build(Vector2i(2, 2), "sampler")
	check("a tree beside a sampler: a gene more", h.income_genes() == 1 + Content.TREE_GENES, h.income_genes())
	check("trees and lava: nothing built there", not h.buildable(Vector2i(2, 3)) and not h.buildable(Vector2i(5, 3)))
	shelf(h, ["b_sampler"])
	check("buildings only where they can stand", not Vector2i(2, 3) in h.targets(0) and Vector2i(1, 3) in h.targets(0))
	var t := bare()
	t.terrain = {Vector2i(0, 2): "mire", Vector2i(2, 3): "toadstool", Vector2i(4, 2): "ice_ore", Vector2i(5, 3): "wreck"}
	t.build(Vector2i(0, 2), "pool")
	t.build(Vector2i(4, 2), "mine")
	t.build(Vector2i(5, 2), "mine")
	t.build(Vector2i(2, 2), "sampler")
	check("each place's ground works one of four ways: a mire as a pond, toadstools as a tree, ice ore as ore, a wreck as lava",
		t.income_biomass() == 6 and t.income_genes() == 1 + Content.TREE_GENES
		and t.income_gold() == Home.INCOME + (1 + 2) + (1 + 1), [t.income_biomass(), t.income_genes(), t.income_gold()])
	check("toadstools and wrecks: nothing built there", not t.buildable(Vector2i(2, 3)) and not t.buildable(Vector2i(5, 3)))


func _affixes_and_recipes() -> void:
	var h := bare()
	h.build(Vector2i(2, 1), "nest_red")
	shelf(h, ["a_shell", "a_acid", "a_poison"])
	check("affix goes on a nest", h.targets(0) == [Vector2i(2, 1)], h.targets(0))
	h.buy(0, Vector2i(2, 1))
	check("paid 2 gold, 2 genes", h.gold == 18 and h.genes == 8, [h.gold, h.genes])
	check("one place only", h.targets(1).is_empty())
	h.build(Vector2i(2, 2), "stabilizer")
	h.build(Vector2i(2, 3), "stabilizer")
	h.buy(1, Vector2i(2, 1))
	check("acid: reach 5", float(Content.unit_stats(h.army()[0]).range) == 5.0)
	h.buy(2, Vector2i(2, 1))
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
	shelf(c, ["a_shell"])
	check("an affix costs its genes", c.genes_cost(Content.offer(c.shelf[0])) == 2)
	c.build(Vector2i(5, 3), "gene_bank")
	check("a gene bank: one less", c.genes_cost(Content.offer(c.shelf[0])) == 1)
	c.take_star("doctor")
	check("and the doctor: none", c.genes_cost(Content.offer(c.shelf[0])) == 0)


func _schools() -> void:
	var h := bare()
	for x in 5:
		h.build(Vector2i(x, 0), "nest_red")
	h.build(Vector2i(0, 3), "horde_totem")
	var a := h.army()
	check("ten out (five reds in a row, all swarming): the totem gives all +1", a.size() == 10
		and a.all(func(u: Dictionary) -> bool: return int(u.atk_bonus) == 1), [a.size(), a[0].atk_bonus])
	h.build(Vector2i(1, 3), "horde_totem")
	check("two totems: +2", int(h.army()[0].atk_bonus) == 2)
	h.buildings[Vector2i(1, 3)].level = 3
	check("a totem at 3: one for every 4", h.horde_bonus(10) == 10 / 6 + 10 / 4)
	var e := bare()
	e.build(Vector2i(0, 1), "nest_red")
	e.buildings[Vector2i(0, 1)].path = ["elite"]
	e.build(Vector2i(1, 1), "nest_red")
	e.build(Vector2i(5, 3), "champion_hall")
	check("champion hall: elites 15% more, the rest nothing", is_equal_approx(float(e.spec_of(Vector2i(0, 1)).hp_mult),
		Content.ELITE_HP * 1.15) and is_equal_approx(float(e.spec_of(Vector2i(1, 1)).hp_mult), 1.0))
	var r := bare()
	r.build(Vector2i(0, 1), "nest_blue")
	r.build(Vector2i(1, 1), "nest_red")
	r.build(Vector2i(2, 1), "nest_red")
	r.buildings[Vector2i(2, 1)].affixes = ["acid"]
	r.build(Vector2i(5, 3), "watchtower")
	check("watchtower: those that reach far +1 each hit, armour or not", int(r.spec_of(Vector2i(0, 1)).pierce) == 1
		and int(r.spec_of(Vector2i(1, 1)).pierce) == 0 and int(r.spec_of(Vector2i(2, 1)).pierce) == 1
		and int(r.spec_of(Vector2i(0, 1)).atk_bonus) == 0)
	var v := bare()
	v.build(Vector2i(0, 0), "nest_green")
	v.build(Vector2i(0, 1), "nest_green")
	v.build(Vector2i(5, 3), "vanguard")
	check("vanguard camp: the front row 30% more hp, the row behind nothing", is_equal_approx(float(v.spec_of(Vector2i(0, 0)).hp_mult),
		1.3) and is_equal_approx(float(v.spec_of(Vector2i(0, 1)).hp_mult), 1.0))
	var g := bare()
	g.build(Vector2i(5, 3), "market")
	check("market: the first restock free", g.reroll_price() == 0)
	check("market at 1: the shelf as it was; at 2, one more", g.shelf_size() == Content.SHOP)
	g.buildings[Vector2i(5, 3)].level = 2
	check("market at 2", g.shelf_size() == Content.SHOP + 1)
	g.build(Vector2i(4, 3), "vault")
	check("vault: interest up to 4", g.interest_max() == Content.INTEREST_MAX + 2)


func _buying() -> void:
	var h := bare()
	h.build(Vector2i(2, 2), "pool")
	shelf(h, ["b_sampler", "raise", "b_gold"])
	h.buy(0, Vector2i(2, 2))
	check("over a pool: pulled down, half back", h.buildings[Vector2i(2, 2)].kind == "sampler" and h.gold == 20 - 2 + 1)
	check("raise from level 1 costs 3", h.price(1, Vector2i(2, 2)) == Content.RAISE + 1)
	h.buildings[Vector2i(2, 2)].level = 2
	h.buy(1, Vector2i(2, 2))
	check("level 3 at most, 4 paid", int(h.buildings[Vector2i(2, 2)].level) == 3 and h.gold == 19 - 4, h.gold)
	h.gold = 1
	check("not enough gold: nowhere", h.targets(2).is_empty())


func _stash() -> void:
	var h := bare()
	h.build(Vector2i(2, 0), "nest_red")
	shelf(h, ["b_red", "a_shell", "raise"])
	check("no hoarder: nothing kept", not h.can_store(0) and h.stash_size() == 0)
	h.take_star("hoarder")
	check("the hoarder keeps three", h.stash_size() == 3)
	check("buildings and affixes can be kept", h.can_store(0) and h.can_store(1))
	check("raises cannot", not h.can_store(2))
	check("keeping costs what putting it down costs", h.store_price(0) == h.price(0))
	h.store(0)
	h.store(1)
	check("kept: paid, gone from the shelf", h.stash.size() == 2 and h.gold == 20 - 3 - 2 and h.genes == 8
		and h.shelf[0] == null, h.gold)
	h.gold = 0
	h.genes = 0
	check("put down for nothing", Vector2i(0, 0) in h.stash_targets(0) and h.stash_targets(1) == [Vector2i(2, 0)])
	h.place(1, Vector2i(2, 0))
	check("the affix is on", "shell" in h.buildings[Vector2i(2, 0)].affixes and h.stash.size() == 1)
	h.place(0, Vector2i(0, 0))
	check("the nest is up", h.buildings[Vector2i(0, 0)].kind == "nest_red" and h.stash.is_empty())
	h.stash = [{"id": "b_pool"}, {"id": "b_pool"}, {"id": "b_pool"}]
	h.gold = 20
	shelf(h, ["b_red"])
	check("full: nothing more kept", not h.can_store(0))
	h.hungry = [0]
	h.stash = [{"id": "b_pool"}]
	check("the hoarder hungry: nothing more kept, what it keeps still there", not h.can_store(0) and h.stash.size() == 1
		and not h.stash_targets(0).is_empty())
	h.hungry = []
	h.sell_star(0)
	check("the hoarder sold: what it kept gone", h.stash.is_empty() and h.stars.is_empty())

func _shelf() -> void:
	var h := bare()
	h.stock(rng(1), 0)
	check("bare land: nothing to raise or stick affixes on, so all buildings", h.shelf.size() == 5
		and h.shelf.all(func(oi: Dictionary) -> bool: return Content.OFFERS[oi.id].type == "build"))
	var n := bare()
	n.build(Vector2i(0, 0), "nest_red")
	n.stock(rng(1), 0)
	check("a nest standing: 3 buildings and 2 others", n.shelf.size() == 5 and n.shelf.filter(func(oi: Dictionary) -> bool:
		return Content.OFFERS[oi.id].type == "build").size() == 3)
	n.deck.append_array([{"id": "b_gold", "plus": false}, {"id": "a_wings", "plus": false}, {"id": "b_forge", "plus": false},
		{"id": "a_flame", "plus": false}])
	var later := 0
	var elsewhere := 0
	for s in 40:
		n.stock(rng(s), 0)
		for oi in n.shelf:
			if int(Content.OFFERS[oi.id].get("from", 0)) > 0:
				later += 1
			if int(Content.OFFERS[oi.id].get("region", 0)) != 0:
				elsewhere += 1
	check("the rainforest offers nothing from later, nothing of the volcano's", later == 0 and elsewhere == 0, [later, elsewhere])
	var v := bare(1)
	v.build(Vector2i(0, 0), "nest_red")
	v.deck.append({"id": "b_forge", "plus": false})
	var forge := 0
	var theirs := 0
	for s in 40:
		v.stock(rng(s), 1)
		for oi in v.shelf:
			if int(Content.OFFERS[oi.id].get("region", 1)) != 1:
				theirs += 1
			if oi.id == "b_forge":
				forge += 1
	check("the volcano offers nothing of the rainforest's (its spores and poison stay in the deck)", theirs == 0, theirs)
	check("the volcano's own forge, once in the deck, turns up", forge > 0)
	n.gold = 3
	var worst := 0
	for k in 30:
		n.stock(rng(k), 1)
		worst = maxi(worst, n.shelf.filter(func(oi: Dictionary) -> bool: return n._least_price(oi) > n.gold).size())
	check("no more than one that costs more than there is", worst <= 1, worst)
	var st := bare()
	st.build(Vector2i(0, 0), "nest_red")
	st.deck.append({"id": "b_stab", "plus": false})
	var stab := 0
	for k in 40:
		st.stock(rng(k), 0)
		stab += st.shelf.filter(func(oi: Dictionary) -> bool: return oi.id == "b_stab").size()
	check("no stabilizer while no nest wants more affixes", stab == 0, stab)
	st.buildings[Vector2i(0, 0)].affixes = ["shell"]
	for k in 40:
		st.stock(rng(k), 0)
		stab += st.shelf.filter(func(oi: Dictionary) -> bool: return oi.id == "b_stab").size()
	check("a stabilizer once a nest is full", stab > 0, stab)
	var few := bare()
	few.deck = [{"id": "b_red", "plus": false}, {"id": "b_red", "plus": false}, {"id": "raise", "plus": false}]
	few.build(Vector2i(0, 0), "nest_red")
	few.stock(rng(), 0)
	check("a deck of three: a shelf of three, both reds", few.shelf.size() == 3
		and few.shelf.filter(func(oi: Dictionary) -> bool: return oi.id == "b_red").size() == 2, few.shelf)


## The deck the shop draws from, cut and upgraded after a mini-boss (GAME-DESIGN 22).
func _deck() -> void:
	var h := bare()
	check("the run starts with the deck, nothing upgraded", h.deck.size() == Content.DECK.size()
		and h.deck.all(func(c: Dictionary) -> bool: return not c.plus))
	h.build(Vector2i(2, 0), "nest_red")
	var have := {}
	for c in h.deck:
		have[c.id] = int(have.get(c.id, 0)) + 1
	var over := 0
	for s in 30:
		h.stock(rng(s), 0)
		var seen := {}
		for oi in h.shelf:
			seen[oi.id] = int(seen.get(oi.id, 0)) + 1
		for id in seen:
			if int(seen[id]) > int(have.get(id, 0)):
				over += 1
	check("the shelf: only what is in the deck, each card at most once", over == 0, over)
	var n := h.deck.size()
	h.gold = 20
	check("cut: 3 gold", h.cut(0) and h.gold == 17 and h.deck.size() == n - 1)
	check("then 4, then 5", h.cut_price() == 4 and h.cut(0) and h.gold == 13 and h.cut_price() == 5)
	h.gold = 4
	check("not the gold: none cut", not h.cut(0) and h.deck.size() == n - 2)
	var mine := -1
	for k in h.deck.size():
		if h.deck[k].id == "b_mine":
			mine = k
	h.gold = 20
	h.cut(mine)
	var mines := 0
	for s in 30:
		h.stock(rng(s), 0)
		mines += h.shelf.filter(func(oi: Dictionary) -> bool: return oi.id == "b_mine").size()
	check("a card cut never comes again", mines == 0, mines)
	var u := bare()
	check("upgrade: 3 research points", u.upgrade(0) and u.genes == 7 and u.deck[0].plus)
	check("once", not u.can_upgrade(0) and not u.upgrade(0) and u.genes == 7)
	u.genes = 2
	check("not the research points: none", not u.can_upgrade(1))
	var p := bare()
	p.deck = [{"id": "b_red", "plus": true}]
	p.stock(rng(), 0)
	check("an upgraded card comes on the shelf upgraded", p.shelf.size() == 1 and p.shelf[0].get("plus", false)
		and str(Content.offer(p.shelf[0]).name).ends_with("+"), p.shelf)
	p.buy(0, Vector2i(1, 0), "elite")
	check("an upgraded nest goes down at level 2, its first choice made", int(p.buildings[Vector2i(1, 0)].level) == 2
		and p.buildings[Vector2i(1, 0)].path == ["elite"] and p.gold == 20 - 3)
	p.shelf = [{"id": "b_pool", "plus": true}, {"id": "raise", "plus": true}, {"id": "a_shell", "plus": true}]
	p.buy(0, Vector2i(1, 2))
	check("an upgraded building too", int(p.buildings[Vector2i(1, 2)].level) == 2)
	check("an upgraded raise: 2 gold less", p.price(1, Vector2i(1, 2)) == Content.RAISE + 2 - Content.PLUS_RAISE)
	check("an upgraded affix: no research points", p.genes_cost(Content.offer(p.shelf[2])) == 0)
	var s := bare()
	s.take_star("hoarder")
	s.shelf = [{"id": "b_blue", "plus": true}]
	s.store(0)
	s.place(0, Vector2i(3, 0), "count")
	check("kept in the stash, still upgraded", int(s.buildings[Vector2i(3, 0)].level) == 2
		and s.buildings[Vector2i(3, 0)].path == ["count"])


func _reroll_and_interest() -> void:
	var h := bare()
	h.gold = 10
	h.stock(rng(1), 0)
	h.reroll(rng(2), 0)
	h.reroll(rng(3), 0)
	check("restocks: 1, then 2", h.gold == 7, h.gold)
	h.take_star("scout")
	h.rerolls = 0
	check("the scout: the first is free", h.reroll_price() == 0)
	h.gold = 12
	check("interest: 2 for 12", h.interest() == 2)
	h.take_star("saver")
	h.gold = 40
	check("the saver: up to 4", h.interest() == Content.INTEREST_MAX + 2)


## A card after each round, to add to the deck -- or gold (GAME-DESIGN 22).
func _rewards() -> void:
	var r := Run.new(7)
	r.start_round()
	var cards := r.reward_offer()
	check("three cards, all different", cards.size() == Content.REWARDS and cards[0].id != cards[1].id
		and cards[1].id != cards[2].id and cards[0].id != cards[2].id, cards)
	var n := r.home.deck.size()
	r.take_reward("b_green")
	check("the one taken goes into the deck, not the stash", r.home.deck.size() == n + 1 and r.home.deck[-1].id == "b_green"
		and not r.home.deck[-1].plus and r.home.stash.is_empty())
	var gold := r.home.gold
	r.take_reward_gold()
	check("or 3 gold", r.home.gold == gold + Content.REWARD_GOLD)
	var later := 0
	var uncommon := 0
	var rare := 0
	for s in 40:
		var g := Run.new(s + 1)
		for oi in g.reward_offer():
			var o: Dictionary = Content.OFFERS[oi.id]
			if int(o.get("from", 0)) > 0 or int(o.get("region", 0)) != 0:
				later += 1
			if int(o.rarity) == 1:
				uncommon += 1
		g.move_on(1)
		for oi in g.reward_offer():
			if int(Content.OFFERS[oi.id].rarity) == 2:
				rare += 1
	check("only cards found here and now", later == 0, later)
	check("the uncommon and the rare come too", uncommon > 0 and rare > 0, [uncommon, rare])
	var m := Run.new(2)
	m.round = 4
	m.start_round()
	var f := m.fight()
	f.run()
	m.finish(f)
	check("round 4 was a mini-boss's: the deck worked on after it", m.over or (m.round == 5 and m.was_mini()), m.round)
	m.round = 7
	check("round 6 not", not m.was_mini())


## The star dinosaurs (GAME-DESIGN 24): on offer after the shelf, bought into a pen, fed each round, sold.
func _stars() -> void:
	var h := bare()
	h.stock(rng(4), 0)
	check("a star on offer after the shelf, none legendary", h.star_offer != ""
		and int(Content.STARS[h.star_offer].rarity) <= int(Content.STARS_FROM[0]), h.star_offer)
	var odd := 0
	for s in 60:
		var g := bare()
		g.take_star("hoarder")
		g.stock(rng(s + 10), 0)
		if g.star_offer == "hoarder" or int(Content.STARS[g.star_offer].rarity) > 1:
			odd += 1
	check("never one already in a pen, nothing rare in the first place", odd == 0, odd)
	h.star_offer = "trader"
	h.gold = 3
	check("not without the gold", not h.can_buy_star())
	h.gold = 10
	h.buy_star()
	check("bought: paid, in the first pen, gone from the shelf", h.stars.size() == 1 and h.stars[0].id == "trader"
		and h.gold == 6 and h.star_offer == "", [h.gold, h.stars])
	check("the trader: a shelf of 6", h.shelf_size() == Content.SHOP + 1)
	for id in ["mother", "scout", "doctor", "shield"]:
		h.take_star(id)
	h.star_offer = "saver"
	check("five pens full: no more", h.stars.size() == Content.PENS and not h.can_buy_star() and h.take_star("saver").is_empty())
	check("no star twice", bare().take_star("tri").size() == 1 and _with(["tri"]).take_star("tri").is_empty())
	# Fed in pen order: 5 biomass for five stars eating 1 each, but the first round's 3 only reach three.
	h.biomass = 3
	var ev := h.feed()
	check("three fed, the last two without", h.hungry == [3, 4] and h.biomass == 0
		and ev[0].hungry == ["doctor", "shield"], [h.hungry, ev])
	shelf(h, ["a_shell"])
	check("the doctor without: affixes cost as ever", h.genes_cost(Content.offer(h.shelf[0])) == 2)
	check("the shield without: no hit points more", h.hp_max() == Home.HP)
	check("the trader fed: still a shelf of 6", h.shelf_size() == Content.SHOP + 1)
	check("what they eat, all told", h.star_food() == 5)
	h.biomass = 10
	h.feed()
	check("fed again next round: all", h.hungry.is_empty() and h.biomass == 5 and h.hp_max() == Home.HP + 10)
	h.hungry = [1]
	var back := h.sell_price(0)
	h.sell_star(0)
	check("sold: half its price back, the pens closing up, the hungry one still hungry", back == 2 and h.gold == 6 + 2
		and h.stars[0].id == "mother" and h.hungry == [0], [h.gold, h.hungry])
	var r := Run.new(3)
	var offer := r.star_choice()
	check("after a boss: three, two uncommon or rare, one legendary", offer.size() == 3
		and int(Content.STARS[offer[0]].rarity) in [1, 2] and int(Content.STARS[offer[1]].rarity) in [1, 2]
		and int(Content.STARS[offer[2]].rarity) == 3 and offer[0] != offer[1], offer)
	r.home.take_star(offer[2])
	check("none in the pens offered again", not offer[2] in r.star_choice())

## Each star's own ability (Content.STARS).
func _star_kinds() -> void:
	var m := _with(["mother"])
	m.build(Vector2i(0, 0), "nest_red")
	m.build(Vector2i(4, 0), "nest_blue")
	var a := m.army()
	check("the mother: the first nest one more, free", a.size() == 3 and a[1].free and not a[2].free)
	var b := _with(["belly", "fisher"])
	b.build(Vector2i(0, 2), "pool")
	b.biomass = 0
	b.start_round(rng(), 0)
	check("the belly: 4 more a round, the fisher a pool one more; neither eats", b.income_biomass() == 4 + 3 + 1
		and b.biomass == 8 and b.hungry.is_empty(), [b.income_biomass(), b.biomass])
	var sh := _with(["shield"])
	sh.hp = 20
	sh.biomass = 5
	sh.start_round(rng(), 0)
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
	for id in ["trader", "scout"]:
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
		nk.start_round(rng(), 0)
	check("the neck: a biomass more each round it has been here", nk.income_biomass() == 3, nk.income_biomass())
	var si := _with(["sickle"])
	si.build(Vector2i(0, 0), "nest_red")
	si.hp = 20
	si.biomass = 5
	si.start_round(rng(), 0)
	check("the sickle: an affix place more, a hit point a round", si.slots(Vector2i(0, 0)) == 2 and si.hp == 19, si.hp)
	si.hp = 1
	si.start_round(rng(), 0)
	check("never kills", si.hp == 1)
	var q := _with(["queen"])
	q.build(Vector2i(0, 0), "nest_red")
	check("the queen: every nest one more, a tenth less hit points", q.army().size() == 2
		and is_equal_approx(float(q.spec_of(Vector2i(0, 0)).hp_mult), 0.9))
	var gc := _with(["goldcrown"])
	check("the gold crown: 6 more a round, a shelf of 4", gc.income_gold() == Home.INCOME + 6 and gc.shelf_size() == Content.SHOP - 1)
	var fb := _with(["firstbird"])
	fb.build(Vector2i(0, 0), "nest_red")
	shelf(fb, ["a_shell"])
	check("the first bird: an affix place more, affixes for no research", fb.slots(Vector2i(0, 0)) == 2
		and fb.genes_cost(Content.offer(fb.shelf[0])) == 0)
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
	h.take_star("hoarder")
	h.take_star("neck")
	h.stars[1].grow = 3
	h.stash = [{"id": "a_blade"}]
	h.gold = 17
	h.genes = 9
	var deck := h.deck.size()
	r.round = Content.ROUNDS
	r.move_on(1)
	check("on to the volcano", r.level == 1 and r.place == 1 and r.round == 1 and h.region == 1 and r.path == [0, 1])
	check("the homeland made afresh: a red nest and a pool", h.buildings.size() == 2 and h.buildings.values().all(
		func(b: Dictionary) -> bool: return int(b.level) == 1 and b.kind in ["nest_red", "pool"]))
	check("the volcano's ground, behind the line", h.terrain.values().all(func(t: String) -> bool: return t in ["ore", "lava"])
		and h.terrain.size() == 5 and h.terrain.keys().all(func(p: Vector2i) -> bool: return not Home.front(p)))
	check("the stars come along, grown as they were; gold, research, the deck and what the hoarder keeps too",
		h.stars.size() == 2 and int(h.stars[1].grow) == 3 and h.gold == 17 and h.genes == 9 and h.deck.size() == deck
		and h.stash.size() == 1)

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
	var food := r.home.army_food()
	var biomass := r.home.biomass
	var gold := r.home.gold
	var f := r.fight()
	f.run()
	var out := r.finish(f)
	check("round 1: a result", out.result in ["won", "lost", "time"], out)
	check("biomass paid", r.home.biomass == biomass - food, [biomass, food, r.home.biomass])
	check("gold: kept, won, interest", r.home.gold == gold + int(out.gold) + int(out.interest))
	var g := Run.new(4)
	g.round = Content.ROUNDS
	g.start_round()
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
	r.home.gold = 0
	var f := r.fight()
	f.run()
	var research := r.home.genes
	var out := r.finish(f)
	check("a battle won: 2 gold and a research point", f.result != "won" or (out.gold == 2
		and r.home.genes == research + 1 and r.home.gold == 2), [f.result, out])
	var piles := bare()
	piles.build(Vector2i(0, 2), "pool")
	piles.build(Vector2i(1, 2), "sampler")
	piles.biomass = 40
	piles.genes = 30
	piles.start_round(rng(), 0)
	check("no cap on what is kept: biomass and research points pile up", piles.biomass == 40 + 3
		and piles.genes == 30 + 1 + Content.SAMPLER_POOL, [piles.biomass, piles.genes])


func _clone() -> void:
	var h := Home.new(rng())
	h.start_round(rng(), 0)
	h.gold = 20
	h.stash = [{"id": "b_red"}]
	var c := h.clone()
	c.build(Vector2i(0, 0), "nest_red")
	var bought := -1
	for i in c.shelf.size():
		if not c.targets(i).is_empty():
			c.buy(i, c.targets(i)[0])
			bought = i
			break
	c.stash.clear()
	c.take_star("doctor")
	c.hungry = [0]
	c.gold = 40
	c.cut(0)
	c.genes = 10
	c.upgrade(0)
	check("the copy changes alone", not h.buildings.has(Vector2i(0, 0)) and (bought < 0 or h.shelf[bought] != null)
		and h.stars.is_empty() and h.hungry.is_empty() and h.stash.size() == 1 and h.terrain == c.terrain
		and h.deck.size() == Content.DECK.size() and h.cuts == 0 and not h.deck[0].plus)
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
	var weaker := 0
	for place in Content.LEVELS.size():
		for r in range(1, Content.ROUNDS + 1):
			if _strength(Content.wave(place, 1, r), 1) <= _strength(Content.wave(place, 0, r), 0):
				weaker += 1
	check("the second level comes stronger, round for round", weaker == 0, weaker)
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
	for id in Content.OFFERS:
		var p := Content.offer({"id": id, "plus": true})
		check("upgraded text for " + id, str(p.name).ends_with("+") and Content.offer_text(p).length() > 3, Content.offer_text(p))
	for l in Content.LEVELS:
		check("ground of " + l.name, l.terrain.keys().all(func(t: String) -> bool: return Content.TERRAIN.has(t)))
		check("foes of " + l.name, Content.ENEMIES.has(l.boss) and l.minis.size() == 2
			and l.minis.all(func(k: String) -> bool: return Content.ENEMIES.has(k))
			and l.mix.all(func(m: Array) -> bool: return Content.ENEMIES.has(m[0])))
