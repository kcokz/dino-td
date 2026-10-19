extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run; GAME-DESIGN 17-20) on set-up cases, headless:
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
	_rules()
	_affixes_and_recipes()
	_schools()
	_buying()
	_stash()
	_shelf()
	_taking_out()
	_reroll_and_interest()
	_gifts()
	_relics()
	_wonders()
	_arks()
	_moving_on()
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
	h.alien = 5
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
	var ev := h.start_round(rng(), 0)
	check("income: 5 gold; damp: 3 biomass is 4", h.gold == 5 and h.biomass == 2 + 4, [h.gold, h.biomass])
	check("the stored biomass rotted by half", ev.any(func(e: Dictionary) -> bool: return e.t == "rotted" and e.amount == 1))
	check("a shelf of 5", h.shelf.size() == Content.SHOP, h.shelf.size())
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
	h.stash = [{"id": "b_blue", "packed": {"level": 2, "path": ["elite"], "affixes": []}}]
	check("a packed nest too", h.stash_targets(0).all(func(p: Vector2i) -> bool: return Home.front(p)))


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
	h.build(Vector2i(0, 0), "nest_red")
	check("three reds in a row: the middle one swarms, one more", h.army().size() == 4 and h.count(Vector2i(1, 0)) == 2
		and h.trait_on(Vector2i(1, 0)) and not h.trait_on(Vector2i(0, 0)))
	check("an end one is one red short", h.trait_need(Vector2i(0, 0)) == "还差 1 个红巢挨着", h.trait_need(Vector2i(0, 0)))
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
	w.build(Vector2i(1, 1), "nest_red")
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
	r.choose_ark("war")
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
	check("pond: a pool on it makes double", h.income_biomass() == 6 * 3 / 2, h.income_biomass())
	h.build(Vector2i(4, 2), "mine")
	h.build(Vector2i(5, 2), "mine")
	check("ore: a mine on it 2 more; lava: a mine beside it 1 more", h.income_gold() == Home.INCOME + (1 + 2) + (1 + 1),
		h.income_gold())
	h.build(Vector2i(2, 2), "sampler")
	check("a tree beside a sampler: a gene more", h.income_genes() == 1 + Content.TREE_GENES, h.income_genes())
	check("trees and lava: nothing built there", not h.buildable(Vector2i(2, 3)) and not h.buildable(Vector2i(5, 3)))
	shelf(h, ["b_sampler"])
	check("buildings only where they can stand", not Vector2i(2, 3) in h.targets(0) and Vector2i(1, 3) in h.targets(0))


func _rules() -> void:
	var d := bare(0)
	d.build(Vector2i(0, 3), "pool")
	d.biomass = 10
	d.start_round(rng(), 0)
	check("damp: half of 10 rots, 3 grows to 4", d.biomass == 5 + 4, d.biomass)
	var a := bare(1)
	a.build(Vector2i(0, 0), "nest_red")
	a.hp = 20
	a.start_round(rng(), 1)
	check("ash: 1 hp a round", a.hp == 19, a.hp)
	shelf(a, ["raise"])
	check("ash: raising a gold cheaper", a.price(0, Vector2i(0, 0)) == Content.RAISE + 1 - 1)
	a.hp = 1
	a.start_round(rng(), 1)
	check("ash never kills", a.hp == 1)


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
	c.relics.append("tooth")
	check("and the tooth: none", c.genes_cost(Content.offer(c.shelf[0])) == 0)


func _schools() -> void:
	var h := bare()
	for x in Home.COLS:
		h.build(Vector2i(x, 0), "nest_red")
	h.build(Vector2i(0, 3), "horde_totem")
	var a := h.army()
	check("ten out (the middle four make two): the totem gives all +1", a.size() == 10 and a.all(func(u: Dictionary) -> bool:
		return int(u.atk_bonus) == 1), [a.size(), a[0].atk_bonus])
	h.build(Vector2i(1, 3), "horde_totem")
	check("two totems: +2", int(h.army()[0].atk_bonus) == 2)
	h.buildings[Vector2i(1, 3)].level = 3
	check("a totem at 3: one for every 4", h.horde_bonus(10) == 10 / 6 + 10 / 4)
	var e := bare()
	e.build(Vector2i(0, 1), "nest_red")
	e.buildings[Vector2i(0, 1)].path = ["elite"]
	e.build(Vector2i(1, 1), "nest_red")
	e.build(Vector2i(5, 3), "champion_hall")
	check("champion hall: elites 30% more, the rest nothing", is_equal_approx(float(e.spec_of(Vector2i(0, 1)).hp_mult),
		Content.ELITE_HP * 1.3) and is_equal_approx(float(e.spec_of(Vector2i(1, 1)).hp_mult), 1.0))
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
	check("buildings and affixes can be kept", h.can_store(0) and h.can_store(1))
	check("raises cannot", not h.can_store(2))
	h.store(0)
	h.store(1)
	check("kept: paid, gone from the shelf", h.stash.size() == 2 and h.gold == 20 - 3 - 2 and h.genes == 8 and h.shelf[0] == null)
	h.gold = 0
	h.genes = 0
	check("put down for nothing", Vector2i(0, 0) in h.stash_targets(0) and h.stash_targets(1) == [Vector2i(2, 0)])
	h.place(1, Vector2i(2, 0))
	check("the affix is on", "shell" in h.buildings[Vector2i(2, 0)].affixes and h.stash.size() == 1)
	h.place(0, Vector2i(0, 0))
	check("the nest is up", h.buildings[Vector2i(0, 0)].kind == "nest_red" and h.stash.is_empty())
	h.buildings[Vector2i(2, 0)].level = 3
	h.buildings[Vector2i(2, 0)].path = ["count", "elite"]
	var g := h.packed(Vector2i(2, 0))
	check("a nest packed keeps its level, its choices, its affixes", g.id == "b_red" and int(g.packed.level) == 3
		and g.packed.path == ["count", "elite"] and g.packed.affixes == ["shell"], g)
	h.stash = [g]
	h.place(0, Vector2i(5, 1))
	var b: Dictionary = h.buildings[Vector2i(5, 1)]
	check("and has them when put down", int(b.level) == 3 and b.path == ["count", "elite"] and b.affixes == ["shell"])
	for k in Content.STASH + 2:
		h.keep({"id": "b_pool"})
	check("no more than the stash holds", h.stash.size() == Content.STASH)
	h.gold = 20
	shelf(h, ["b_red"])
	check("full: nothing more kept", not h.can_store(0))


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
	var ids: Array = n.shelf.map(func(oi: Dictionary) -> String: return oi.id)
	var distinct := {}
	for id in ids:
		distinct[id] = true
	check("none twice", distinct.size() == ids.size(), ids)
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
	var forge := 0
	for s in 40:
		v.stock(rng(s), 1)
		for oi in v.shelf:
			check("the volcano offers nothing of the rainforest's", int(Content.OFFERS[oi.id].get("region", 1)) == 1, oi.id)
			if oi.id == "b_forge":
				forge += 1
	check("the volcano's own forge turns up", forge > 0)
	n.gold = 3
	var worst := 0
	for k in 30:
		n.stock(rng(k), 1)
		worst = maxi(worst, n.shelf.filter(func(oi: Dictionary) -> bool: return n._least_price(oi.id) > n.gold).size())
	check("no more than one that costs more than there is", worst <= 1, worst)
	var st := bare()
	st.build(Vector2i(0, 0), "nest_red")
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


func _taking_out() -> void:
	var h := bare()
	h.build(Vector2i(2, 0), "nest_red")
	h.start_round(rng(), 0)
	var id: String = h.shelf[0].id
	check("a kind taken out of the shop", h.remove_kind(0) and h.shelf[0] == null and h.struck.has(0) and id in h.removed)
	check("one a round", not h.remove_kind(1))
	var seen := 0
	for s in 40:
		h.stock(rng(s), 0)
		seen += h.shelf.filter(func(oi: Dictionary) -> bool: return oi.id == id).size()
	check("never on the shelf again", seen == 0, seen)
	h.start_round(rng(5), 0)
	check("next round, another", h.remove_kind(0))
	var r := Run.new(14)
	r.start_round()
	r.home.removed = ["b_red", "b_blue", "b_pool", "a_shell", "a_blade", "raise"]
	var gifted := 0
	for k in 20:
		for oi in r.gift_offer():
			if oi.id in r.home.removed:
				gifted += 1
	check("nor among the gifts", gifted == 0, gifted)


func _reroll_and_interest() -> void:
	var h := bare()
	h.gold = 10
	h.stock(rng(1), 0)
	h.reroll(rng(2), 0)
	h.reroll(rng(3), 0)
	check("restocks: 1, then 2", h.gold == 7, h.gold)
	h.relics.append("trilobite")
	h.rerolls = 0
	check("trilobite: the first is free", h.reroll_price() == 0)
	h.gold = 12
	check("interest: 2 for 12", h.interest() == 2)
	h.relics.append("ammonite")
	h.gold = 40
	check("ammonite: up to 4", h.interest() == Content.INTEREST_MAX + 2)


func _gifts() -> void:
	var r := Run.new(7)
	r.start_round()
	var gifts := r.gift_offer()
	check("three gifts, all different", gifts.size() == 3 and gifts[0].id != gifts[1].id and gifts[1].id != gifts[2].id)
	r.take_gift({"id": "a_shell"})
	check("a gift goes into the stash", r.home.stash.size() == 1 and r.home.stash[0].get("gift", false))
	var used_up := 0
	for s in 30:
		var g := Run.new(s + 1)
		g.start_round()
		for oi in g.gift_offer():
			if not Content.OFFERS[oi.id].type in ["build", "raise", "affix"]:
				used_up += 1
	check("gifts are all things that last", used_up == 0, used_up)
	r.home.relics.append("sac")
	check("the sac: two to choose from", r.gift_offer().size() == 2)


func _relics() -> void:
	var h := bare()
	h.build(Vector2i(0, 0), "nest_red")
	h.build(Vector2i(4, 0), "nest_blue")
	h.relics = ["frill", "egg", "coprolite", "wood"]
	var a := h.army()
	check("no relic makes units stronger", is_equal_approx(float(a[0].hp_mult), 1.0) and int(a[0].atk_bonus) == 0)
	check("egg: the first nest one more, free", a.size() == 3 and a[1].free)
	check("coprolite: +3 biomass, damp makes it 4", h.income_biomass() == 4)
	check("frill: the homeland 10 more", h.hp_max() == Home.HP + 10)
	h.hp = 20
	h.start_round(rng(), 0)
	check("frill: mends 1 a round", h.hp == 21, h.hp)
	shelf(h, ["b_red"])
	check("wood: buildings a gold less", h.price(0) == 2)
	var b := bare(1)
	b.build(Vector2i(0, 0), "nest_red")
	b.relics = ["core", "heart", "crystal", "sac"]
	check("core: one more each", b.army().size() == 2)
	check("heart: an affix place more", b.slots(Vector2i(0, 0)) == 2)
	check("crystal: 4 gold more, a shelf of 4", b.income_gold() == Home.INCOME + 4 and b.shelf_size() == Content.SHOP - 1)
	check("sac: the stash holds 2 more", b.stash_size() == Content.STASH + 2)
	b.hp = 20
	b.start_round(rng(), 1)
	check("heart and ash: 2 hp a round", b.hp == 18, b.hp)
	var r := Run.new(3)
	var offer := r.relic_offer()
	check("relics offered: two fossils and a boss's", offer.size() == 3 and not Content.RELICS[offer[0]].get("boss", false)
		and Content.RELICS[offer[2]].get("boss", false), offer)


func _wonders() -> void:
	var r := Run.new(21)
	check("two wonders on offer, different", r.home.wonders.size() == Content.WONDERS_OFFERED
		and r.home.wonders[0] != r.home.wonders[1], r.home.wonders)
	var h := bare()
	h.wonders = ["brood", "titan"]
	h.build(Vector2i(2, 0), "nest_red")
	h.gold = 10
	check("not without the gold", not h.can_build_wonder("brood"))
	h.gold = 40
	check("only one on offer", not h.can_build_wonder("banner"))
	h.build_wonder("brood")
	check("the brood: built, paid, every nest one more", h.wonder == "brood" and h.gold == 40 - 18 and h.army().size() == 2)
	check("only one wonder a run", not h.can_build_wonder("titan"))
	var g := bare()
	g.wonder = "gold_city"
	check("city of gold: 6 more a round", g.income_gold() == Home.INCOME + 6)
	var t := bare()
	t.build(Vector2i(0, 0), "nest_red")
	t.wonder = "evo_tower"
	shelf(t, ["a_shell"])
	check("tower of evolution: an affix place more, affixes for no genes", t.slots(Vector2i(0, 0)) == 2
		and t.genes_cost(Content.offer(t.shelf[0])) == 0)
	t.wonder = "banner"
	var s := t.spec_of(Vector2i(0, 0))
	check("banner: +2 attack, a quarter more hp", int(s.atk_bonus) == 2 and is_equal_approx(float(s.hp_mult), 1.25))
	t.wonder = "titan"
	var titan: Array = t.army().filter(func(u: Dictionary) -> bool: return u.kind == "titan")
	check("titan cage: a titan, free, in the middle of the front row", titan.size() == 1 and titan[0].free
		and int(titan[0].row) == 0 and is_equal_approx(float(titan[0].lane), (Home.COLS - 1) * 0.5))


func _arks() -> void:
	for id in Content.ARKS:
		var r := Run.new(5)
		r.choose_ark(id)
		var a: Dictionary = Content.ARKS[id]
		check("ark %s: its buildings" % id, r.home.buildings.size() == a.buildings.size(), r.home.buildings.size())
		check("ark %s: its relic and gold" % id, a.relic in r.home.relics and r.home.gold == int(a.gold))
		check("ark %s: nests on the battle line" % id, r.home.buildings.keys().all(func(p: Vector2i) -> bool:
			return Home.front(p) == Content.is_nest(r.home.buildings[p].kind)))
	var w := Run.new(5)
	w.choose_ark("war")
	check("the war ark's nest at level 2, making two", w.home.buildings.values().any(func(b: Dictionary) -> bool:
		return b.kind == "nest_red" and int(b.level) == 2 and b.path == ["count"]))


func _moving_on() -> void:
	var r := Run.new(6)
	r.start_round()
	var h := r.home
	h.build(Vector2i(0, 1), "nest_blue")
	h.buildings[Vector2i(0, 1)].level = 3
	h.buildings[Vector2i(0, 1)].path = ["count", "elite"]
	h.buildings[Vector2i(0, 1)].affixes = ["shell"]
	h.stash = [{"id": "a_blade"}]
	h.gold = 17
	h.relics.append("amber")
	h.wonder = "gold_city"
	var goods := r.packable()
	check("every building can be packed, and the stash comes too", goods.size() == h.buildings.size() + 1)
	var blue: Dictionary = goods.filter(func(g: Dictionary) -> bool: return g.id == "b_blue").front()
	r.level = 0
	r.round = 5
	r.move_on([blue, {"id": "a_blade"}])
	check("on to the volcano", r.level == 1 and r.round == 1 and h.region == 1)
	check("the ark lands its nest and pool", h.buildings.size() == 2 and h.buildings.values().all(func(b: Dictionary) -> bool:
		return int(b.level) == 1 and b.kind in ["nest_red", "pool"]))
	check("the volcano's ground, behind the line", h.terrain.values().all(func(t: String) -> bool: return t in ["ore", "lava"])
		and h.terrain.size() == 5 and h.terrain.keys().all(func(p: Vector2i) -> bool: return not Home.front(p)))
	check("gold, relics and the wonder kept", h.gold == 17 and "amber" in h.relics and h.wonder == "gold_city")
	check("the goods carried", h.stash.size() == 2 and h.stash[0].id == "b_blue" and not h.stash[0].has("from")
		and not h.stash[1].has("kept"))
	var p: Vector2i = h.stash_targets(0)[0]
	h.place(0, p)
	check("the blue nest, level 3, its choices and its shell, set down again", int(h.buildings[p].level) == 3
		and h.buildings[p].path == ["count", "elite"] and h.buildings[p].affixes == ["shell"])
	var fed := Run.new(10)
	fed.home.buildings.clear()
	fed.home.terrain.clear()
	for x in 5:
		fed.home.build(Vector2i(x, 0), "nest_red")
		fed.home.buildings[Vector2i(x, 0)].level = 3
		fed.home.buildings[Vector2i(x, 0)].path = ["count", "count"]
	fed.home.build(Vector2i(0, 2), "pool")
	fed.home.buildings[Vector2i(0, 2)].level = 3
	var load := fed.default_goods()
	check("five red nests at 3 and a pool at 3: the pool goes in place of a nest, so they are fed",
		load.size() == 4 and load.any(func(g: Dictionary) -> bool: return g.id == "b_pool"), load.map(func(g: Dictionary) -> String:
			return g.id))
	check("fed: 3 nests and the ark's red eat 10, the pools make 11", Run.food_of(load) == [10, 11], Run.food_of(load))
	var many := Run.new(8)
	var lots: Array = []
	for k in 9:
		lots.append({"id": "b_pool"})
	many.move_on(lots)
	check("no more carried than the stash holds", many.home.stash.size() == Content.STASH)


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
	g.round = 5
	g.start_round()
	var w := g.fight()
	w.run()
	var o := g.finish(w)
	check("round 5 ends the place or the run", o.level_won or g.over, [o, g.home.hp])
	check("two places in a run", Content.LEVELS.size() == 2 and not Run.new(1).last_level())


func _economy() -> void:
	check("only what lasts on sale", Content.OFFERS.values().all(func(o: Dictionary) -> bool:
		return o.type in ["build", "raise", "affix"]))
	check("no gym, wall, vine wall, hot spring", not Content.BUILDINGS.has("gym") and not Content.BUILDINGS.has("wall")
		and not Content.BUILDINGS.has("vine_wall") and not Content.BUILDINGS.has("hot_spring"))
	check("no building but a school's makes units stronger", Content.BUILDINGS.values().all(func(b: Dictionary) -> bool:
		return b.has("nest") or b.levels.all(func(l: Dictionary) -> bool:
			return not l.has("drill") and not l.has("haste") and not l.has("hp"))))
	var r := Run.new(12)
	r.choose_ark("war")
	r.start_round()
	check("round 1: 5 gold", r.home.gold == 5, r.home.gold)
	r.home.gold = 0
	var f := r.fight()
	f.run()
	var alien := r.home.alien
	var out := r.finish(f)
	check("a battle won: 2 gold and an alien gene", f.result != "won" or (out.gold == 2 and r.home.alien == alien + 1
		and r.home.gold == 2), [f.result, out])


func _clone() -> void:
	var h := Home.new(rng())
	h.start_round(rng(), 0)
	h.gold = 20
	h.stash = [{"id": "b_red"}]
	h.wonders = ["brood", "banner"]
	var c := h.clone()
	c.build(Vector2i(0, 0), "nest_red")
	var bought := -1
	for i in c.shelf.size():
		if not c.targets(i).is_empty():
			c.buy(i, c.targets(i)[0])
			bought = i
			break
	c.stash.clear()
	c.relics.append("tooth")
	c.remove_kind(4)
	c.gold = 40
	c.build_wonder("brood")
	check("the copy changes alone", not h.buildings.has(Vector2i(0, 0)) and (bought < 0 or h.shelf[bought] != null)
		and h.relics.is_empty() and h.stash.size() == 1 and h.terrain == c.terrain and h.removed.is_empty()
		and h.wonder == "" and c.wonder == "brood")
	var f1 := Fight.make(h.army(), ["grey", "grey"], 1.0)
	var f2 := Fight.make(h.clone().army(), ["grey", "grey"], 1.0)
	f1.run()
	f2.run()
	check("a copy fights the same", f1.result == f2.result and f1.time == f2.time)


func _waves() -> void:
	for level in Content.LEVELS.size():
		for r in range(1, int(Content.LEVELS[level].rounds) + 1):
			check("wave %d/%d" % [level, r], not Content.wave(level, r).is_empty())
	check("the last round has the place's boss", "boss_rain" in Content.wave(0, 5) and "boss_lava" in Content.wave(1, 5))
	check("each place its own kinds", Content.wave(0, 3).any(func(k: String) -> bool: return k == "spore")
		and Content.wave(1, 3).any(func(k: String) -> bool: return k == "beetle" or k == "salamander"))


func _texts() -> void:
	for id in Content.OFFERS:
		var o := Content.offer({"id": id})
		check("text for " + id, Content.offer_text(o).length() > 3 and str(o.name) != "", Content.offer_text(o))
	check("a packed nest says its level and that it is elite", Content.offer({"id": "b_red", "packed": {"level": 2,
		"path": ["elite"], "affixes": ["shell"]}}).name.contains("精英"))
	for kind in Content.BUILDINGS:
		for l in range(1, Content.LEVEL_MAX + 1):
			check("building text %s %d" % [kind, l], Content.building_text(kind, l) != "" and Content.level_text(kind, l) != "")
		var b: Dictionary = Content.BUILDINGS[kind]
		check("a school for " + kind, b.has("nest") or Content.SCHOOLS.has(b.get("school", "")))
	for id in Content.RELICS:
		check("relic " + id, Content.RELICS[id].says != "")
	for id in Content.WONDERS:
		check("wonder " + id, Content.WONDERS[id].says != "" and int(Content.WONDERS[id].price) > 10)
	for id in Content.TERRAIN:
		check("terrain " + id, Content.TERRAIN[id].says != "")
	for l in Content.LEVELS:
		check("rule of " + l.name, Content.RULES.has(l.rule))
