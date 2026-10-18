extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run; GAME-DESIGN 17) on set-up cases, headless:
##
##   Godot --headless --path dino-raid --script res://tools/test_home.gd

var failed := 0
var passed := 0


func _init() -> void:
	_first_round()
	_making()
	_neighbours()
	_terrain()
	_rules()
	_affixes_and_recipes()
	_buying()
	_stash()
	_shelf()
	_reroll_and_interest()
	_gifts()
	_relics()
	_arks()
	_moving_on()
	_potions()
	_walls()
	_fights()
	_falling_hard()
	_run_flow()
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
	h.potions.clear()
	return h


func shelf(h: Home, ids: Array) -> void:
	h.shelf = ids.map(func(id: String) -> Dictionary: return {"id": id, "potion": "gel"} if id == "potion" else {"id": id})


func _first_round() -> void:
	var h := Home.new(rng())
	check("lands with a red nest and a pool", h.buildings.size() == 2 and h.buildings[Vector2i(2, 2)].kind == "nest_red"
		and h.buildings[Vector2i(3, 2)].kind == "pool", h.buildings.keys())
	check("special ground lies about", h.terrain.size() == 5 and not h.terrain.has(Vector2i(2, 2)), h.terrain)
	var ev := h.start_round(rng(), 0)
	check("income: 3 gold; damp: 3 biomass is 4", h.gold == 3 and h.biomass == 2 + 4, [h.gold, h.biomass])
	check("the stored biomass rotted by half", ev.any(func(e: Dictionary) -> bool: return e.t == "rotted" and e.amount == 1))
	check("a shelf of 5", h.shelf.size() == Content.SHOP, h.shelf.size())
	var a := h.army()
	check("one red this round", a.size() == 1 and a[0].kind == "red", a)


func _making() -> void:
	var h := bare()
	h.build(Vector2i(0, 3), "nest_red")
	check("level 1: one", h.army().size() == 1)
	h.buildings[Vector2i(0, 3)].level = 2
	check("level 2: two", h.army().size() == 2)
	h.buildings[Vector2i(0, 3)].level = 3
	var a := h.army()
	check("level 3: three, a fifth stronger", a.size() == 3 and is_equal_approx(float(a[0].atk_mult), 1.2), a.size())
	h.biomass = 2
	check("biomass short: as many as it pays for", h.army().size() == 2, h.army().size())
	var made := h.produce()
	check("produce pays", made.size() == 2 and h.biomass == 0, [made.size(), h.biomass])


func _neighbours() -> void:
	var h := bare()
	h.build(Vector2i(1, 3), "nest_red")
	h.build(Vector2i(2, 3), "nest_red")
	h.build(Vector2i(0, 3), "nest_red")
	check("three in a row: the middle one makes one more", h.army().size() == 4 and h.count(Vector2i(1, 3)) == 2)
	var g := bare()
	g.build(Vector2i(2, 2), "nest_blue")
	g.build(Vector2i(1, 2), "gym")
	g.build(Vector2i(3, 2), "pool")
	g.build(Vector2i(2, 1), "mine")
	var s := g.spec_of(Vector2i(2, 2))
	check("gym: +1 attack", int(s.atk_bonus) == 1, s.atk_bonus)
	check("pool +25%, mine -15%: hp x1.10", is_equal_approx(float(s.hp_mult), 1.10), s.hp_mult)
	g.build(Vector2i(2, 3), "hot_spring")
	check("hot spring: 20% faster", int(g.spec_of(Vector2i(2, 2)).haste) == 20)
	var f := Fight.make(g.army(), {}, ["grey"], 1.0)
	check("faster hits", is_equal_approx(float(f.units[0].every), 1.0 / 1.2), f.units[0].every)
	g.build(Vector2i(1, 2), "forge")
	check("forge beside: +1 attack, and gold", int(g.spec_of(Vector2i(2, 2)).atk_bonus) == 1 and g.income_gold() == 3 + 1 + 1)


func _terrain() -> void:
	var h := bare()
	h.terrain = {Vector2i(0, 0): "pond", Vector2i(2, 0): "tree", Vector2i(4, 0): "ore", Vector2i(5, 1): "lava"}
	h.build(Vector2i(0, 0), "pool")
	h.build(Vector2i(1, 1), "pool")
	check("pond: a pool on it makes double", h.income_biomass() == (6 + 3) * 3 / 2, h.income_biomass())
	h.build(Vector2i(4, 0), "mine")
	check("ore: a mine on it, 2 gold more", h.income_gold() == 3 + 1 + 2, h.income_gold())
	check("trees and lava: nothing built there", not h.buildable(Vector2i(2, 0)) and not h.buildable(Vector2i(5, 1)))
	h.build(Vector2i(2, 1), "nest_red")
	check("a tree and a pool beside: +15% and +25% hp", is_equal_approx(float(h.spec_of(Vector2i(2, 1)).hp_mult), 1.40),
		h.spec_of(Vector2i(2, 1)).hp_mult)
	h.build(Vector2i(5, 2), "nest_red")
	check("lava beside: +1 attack", int(h.spec_of(Vector2i(5, 2)).atk_bonus) == 1)
	shelf(h, ["b_red"])
	check("buildings only where they can stand", not Vector2i(2, 0) in h.targets(0) and Vector2i(3, 3) in h.targets(0))


func _rules() -> void:
	var d := bare(0)
	d.build(Vector2i(0, 3), "pool")
	d.biomass = 10
	d.start_round(rng(), 0)
	check("damp: half of 10 rots, 3 grows to 4", d.biomass == 5 + 4, d.biomass)
	var a := bare(1)
	a.build(Vector2i(0, 3), "nest_red")
	a.hp = 20
	a.start_round(rng(), 1)
	check("ash: 1 hp a round", a.hp == 19, a.hp)
	shelf(a, ["raise"])
	check("ash: raising a gold cheaper", a.price(0, Vector2i(0, 3)) == Content.RAISE + 1 - 1)
	a.hp = 1
	a.start_round(rng(), 1)
	check("ash never kills", a.hp == 1)


func _affixes_and_recipes() -> void:
	var h := bare()
	h.build(Vector2i(2, 3), "nest_red")
	shelf(h, ["a_shell", "a_acid", "a_poison"])
	check("affix goes on a nest", h.targets(0) == [Vector2i(2, 3)], h.targets(0))
	h.buy(0, Vector2i(2, 3))
	check("paid 2 gold, 2 genes", h.gold == 18 and h.genes == 8, [h.gold, h.genes])
	check("one place only", h.targets(1).is_empty())
	h.build(Vector2i(2, 2), "stabilizer")
	h.build(Vector2i(3, 3), "stabilizer")
	h.buy(1, Vector2i(2, 3))
	check("acid: reach 5", float(Content.unit_stats(h.army()[0]).range) == 5.0)
	h.buy(2, Vector2i(2, 3))
	var s := h.spec_of(Vector2i(2, 3))
	check("acid + poison: a miasma beast", s.kind == "miasma" and s.evolved, s.kind)
	var st := Content.unit_stats(s)
	check("the shell still counts, the acid is in it", int(st.armor) == 1 and int(st.pierce) == 2 and float(st.range) == 5.0,
		[st.armor, st.pierce])
	check("it eats 2", h.army_food() == 2, h.army_food())
	check("one half of a recipe tells the other", Content.could_become(["blade"]).any(func(c: Array) -> bool:
		return c[1] == "falcon"))
	var f := bare()
	f.build(Vector2i(0, 3), "nest_red")
	f.buildings[Vector2i(0, 3)].affixes = ["wings", "blade"]
	var fl := Content.unit_stats(f.army()[0])
	check("blade + wings: a falcon, flying, not blade twice", f.army()[0].kind == "falcon" and fl.dive
		and int(fl.atk) == int(Content.UNITS.falcon.atk),
		[f.army()[0].kind, fl.atk])
	var fight := Fight.make(f.army(), {}, ["grey", "purple"], 1.0)
	check("a flier goes for the one furthest back", fight._foe_of(fight.units[0]).kind == "purple")


func _buying() -> void:
	var h := bare()
	h.build(Vector2i(2, 3), "pool")
	shelf(h, ["b_red", "raise", "sample", "b_pool", "culture"])
	h.buy(0, Vector2i(2, 3))
	check("over a pool: pulled down, half back", h.buildings[Vector2i(2, 3)].kind == "nest_red" and h.gold == 20 - 3 + 1)
	check("raise from level 1 costs 3", h.price(1, Vector2i(2, 3)) == Content.RAISE + 1)
	h.buildings[Vector2i(2, 3)].level = 2
	h.buy(1, Vector2i(2, 3))
	check("level 3 at most, 4 paid", int(h.buildings[Vector2i(2, 3)].level) == 3 and h.gold == 18 - 4, h.gold)
	h.genes = 9
	h.buy(2, true)
	check("genes kept to the store", h.genes == Home.GENES_MAX, h.genes)
	h.gold = 1
	shelf(h, ["b_gold"])
	check("not enough gold: nowhere", h.targets(0).is_empty())


func _stash() -> void:
	var h := bare()
	h.build(Vector2i(2, 3), "nest_red")
	shelf(h, ["b_red", "a_shell", "raise", "sample", "potion"])
	check("buildings and affixes can be kept", h.can_store(0) and h.can_store(1))
	check("raises, gains and potions cannot", not h.can_store(2) and not h.can_store(3) and not h.can_store(4))
	h.store(0)
	h.store(1)
	check("kept: paid, gone from the shelf", h.stash.size() == 2 and h.gold == 20 - 3 - 2 and h.genes == 8 and h.shelf[0] == null)
	h.gold = 0
	h.genes = 0
	check("put down for nothing", Vector2i(0, 0) in h.stash_targets(0) and h.stash_targets(1) == [Vector2i(2, 3)])
	h.place(1, Vector2i(2, 3))
	check("the affix is on", "shell" in h.buildings[Vector2i(2, 3)].affixes and h.stash.size() == 1)
	h.place(0, Vector2i(0, 0))
	check("the nest is up", h.buildings[Vector2i(0, 0)].kind == "nest_red" and h.stash.is_empty())
	h.buildings[Vector2i(2, 3)].level = 2
	var g := h.packed(Vector2i(2, 3))
	check("a building packed keeps its level and affixes", g.id == "b_red" and int(g.packed.level) == 2
		and g.packed.affixes == ["shell"], g)
	h.stash = [g]
	h.place(0, Vector2i(5, 0))
	check("and has them when put down", int(h.buildings[Vector2i(5, 0)].level) == 2 and h.buildings[Vector2i(5, 0)].affixes == ["shell"])
	for k in Content.STASH + 2:
		h.keep({"id": "b_pool"})
	check("no more than the stash holds", h.stash.size() == Content.STASH)
	h.gold = 20
	shelf(h, ["b_red"])
	check("full: nothing more kept", not h.can_store(0))


func _shelf() -> void:
	var h := bare()
	h.stock(rng(1), 0)
	check("bare land: 3 buildings and 2 others", h.shelf.size() == 5 and h.shelf.filter(func(oi: Dictionary) -> bool:
		return Content.OFFERS[oi.id].type == "build").size() == 3)
	var ids: Array = h.shelf.map(func(oi: Dictionary) -> String: return oi.id)
	var distinct := {}
	for id in ids:
		distinct[id] = true
	check("none twice", distinct.size() == ids.size(), ids)
	var later := 0
	var elsewhere := 0
	for s in 40:
		h.stock(rng(s), 0)
		for oi in h.shelf:
			if int(Content.OFFERS[oi.id].get("from", 0)) > 0:
				later += 1
			if int(Content.OFFERS[oi.id].get("region", 0)) != 0:
				elsewhere += 1
	check("the rainforest offers nothing from later, nothing of the volcano's", later == 0 and elsewhere == 0, [later, elsewhere])
	var v := bare(1)
	var forge := 0
	for s in 40:
		v.stock(rng(s), 1)
		for oi in v.shelf:
			check("the volcano offers nothing of the rainforest's", int(Content.OFFERS[oi.id].get("region", 1)) == 1, oi.id)
			if oi.id == "b_forge":
				forge += 1
	check("the volcano's own forge turns up", forge > 0)
	h.gold = 3
	h.build(Vector2i(0, 3), "nest_red")
	var worst := 0
	for k in 30:
		h.stock(rng(k), 1)
		worst = maxi(worst, h.shelf.filter(func(oi: Dictionary) -> bool: return h._least_price(oi.id) > h.gold).size())
	check("no more than one that costs more than there is", worst <= 1, worst)


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
	var genes := r.home.genes
	r.take_gift({"id": "sample"})
	check("a gain is had at once", r.home.genes == mini(r.home.genes_max(), genes + 3) and r.home.stash.size() == 1)
	r.home.relics.append("sac")
	check("the sac: two to choose from", r.gift_offer().size() == 2)


func _relics() -> void:
	var h := bare()
	h.build(Vector2i(0, 3), "nest_red")
	h.build(Vector2i(4, 3), "nest_blue")
	h.relics = ["tooth", "frill", "egg", "coprolite", "wood"]
	var a := h.army()
	check("tooth: +1 attack", int(a[0].atk_bonus) == 1)
	check("frill: +15% hp", is_equal_approx(float(a[0].hp_mult), 1.15))
	check("egg: the first nest one more, free", a.size() == 3 and a[1].free)
	check("coprolite: +3 biomass, damp makes it 4", h.income_biomass() == 4)
	shelf(h, ["b_red"])
	check("wood: buildings a gold less", h.price(0) == 2)
	var b := bare(1)
	b.build(Vector2i(0, 3), "nest_red")
	b.relics = ["core", "heart", "crystal", "sac"]
	check("core: one more each", b.army().size() == 2)
	check("heart: +2 attack", int(b.army()[0].atk_bonus) == 2)
	check("crystal: 4 gold more, a shelf of 4", b.income_gold() == 3 + 4 and b.shelf_size() == Content.SHOP - 1)
	check("sac: the stash holds 2 more", b.stash_size() == Content.STASH + 2)
	b.hp = 20
	b.start_round(rng(), 1)
	check("heart and ash: 2 hp a round", b.hp == 18, b.hp)
	var r := Run.new(3)
	var offer := r.relic_offer()
	check("relics offered: two fossils and a boss's", offer.size() == 3 and not Content.RELICS[offer[0]].get("boss", false)
		and Content.RELICS[offer[2]].get("boss", false), offer)


func _arks() -> void:
	for id in Content.ARKS:
		var r := Run.new(5)
		r.choose_ark(id)
		var a: Dictionary = Content.ARKS[id]
		check("ark %s: its buildings" % id, r.home.buildings.size() == a.buildings.size(), r.home.buildings.size())
		check("ark %s: its relic and gold" % id, a.relic in r.home.relics and r.home.gold == int(a.gold))
	var w := Run.new(5)
	w.choose_ark("war")
	check("the war ark's nest at level 2", w.home.buildings.values().any(func(b: Dictionary) -> bool:
		return b.kind == "nest_red" and int(b.level) == 2))


func _moving_on() -> void:
	var r := Run.new(6)
	r.start_round()
	var h := r.home
	h.build(Vector2i(0, 3), "nest_blue")
	h.buildings[Vector2i(0, 3)].level = 3
	h.buildings[Vector2i(0, 3)].affixes = ["shell"]
	h.stash = [{"id": "a_blade"}]
	h.gold = 17
	h.relics.append("amber")
	var goods := r.packable()
	check("every building can be packed, and the stash comes too", goods.size() == h.buildings.size() + 1)
	var blue: Dictionary = goods.filter(func(g: Dictionary) -> bool: return g.id == "b_blue").front()
	r.level = 0
	r.round = 5
	r.move_on([blue, {"id": "a_blade"}])
	check("on to the volcano", r.level == 1 and r.round == 1 and h.region == 1)
	check("the ark lands its nest and pool", h.buildings.size() == 2 and h.buildings.values().all(func(b: Dictionary) -> bool:
		return int(b.level) == 1 and b.kind in ["nest_red", "pool"]))
	check("the volcano's ground", h.terrain.values().all(func(t: String) -> bool: return t in ["ore", "lava"]) and h.terrain.size() == 5)
	check("gold and relics kept", h.gold == 17 and "amber" in h.relics)
	check("the goods carried", h.stash.size() == 2 and h.stash[0].id == "b_blue" and not h.stash[0].has("from")
		and not h.stash[1].has("kept"))
	var p: Vector2i = h.stash_targets(0)[0]
	h.place(0, p)
	check("the blue nest, level 3 with its shell, set down again", int(h.buildings[p].level) == 3 and h.buildings[p].affixes == ["shell"])
	var fed := Run.new(10)
	fed.home.buildings.clear()
	fed.home.terrain.clear()
	for x in 5:
		fed.home.build(Vector2i(x, 0), "nest_red")
		fed.home.buildings[Vector2i(x, 0)].level = 3
	fed.home.build(Vector2i(0, 2), "pool")
	fed.home.buildings[Vector2i(0, 2)].level = 3
	var load := fed.default_goods()
	check("five red nests at 3 and a pool at 3: the pool goes in place of a nest, so they are fed",
		load.size() == 4 and load.any(func(g: Dictionary) -> bool: return g.id == "b_pool"), load.map(func(g: Dictionary) -> String:
			return g.id))
	check("fed: 3 nests and the ark's red eat 10, the pools make 11", Run.food_of(load) == [10, 11], Run.food_of(load))
	check("worth: a red nest at 3 costs more than a pool at 3", Content.worth(fed.home.packed(Vector2i(0, 0)))
		> Content.worth(fed.home.packed(Vector2i(0, 2))))
	var many := Run.new(8)
	var lots: Array = []
	for k in 9:
		lots.append({"id": "b_pool"})
	many.move_on(lots)
	check("no more carried than the stash holds", many.home.stash.size() == Content.STASH)


func _potions() -> void:
	var h := bare()
	h.build(Vector2i(0, 3), "nest_red")
	h.build(Vector2i(2, 3), "nest_blue")
	h.potions = ["breed", "rage", "gel"]
	check("full: no more", not h.add_potion("rush"))
	h.use_potion(0)
	check("breed: each nest one more", h.army().size() == 4, h.army().size())
	h.use_potion(0)
	var f := Fight.make(h.army(), h.buffs, ["grey"], 1.0)
	check("rage: +2 attack", int(f.units[0].atk) == 3 + 2, f.units[0].atk)
	h.hp = 20
	h.use_potion(0)
	check("gel mends 6", h.hp == 26 and h.potions.is_empty(), h.hp)
	var lab := bare()
	lab.build(Vector2i(0, 3), "lab")
	var brewed := 0
	for r in 6:
		brewed += lab.start_round(rng(r), 0).filter(func(e: Dictionary) -> bool: return e.t == "brewed").size()
	check("a lab brews every 3 rounds", brewed == 2, brewed)


func _walls() -> void:
	var w := bare()
	w.build(Vector2i(0, 3), "wall")
	check("wall: hp 35", w.hp_max() == 35 and w.hp == 35, [w.hp_max(), w.hp])
	w.build(Vector2i(1, 3), "vine_wall")
	check("walls side by side block more", w.block() == 1 + 1 + 2 * Content.WALL_CHAIN, w.block())
	w.hp = 30
	w.start_round(rng(), 0)
	check("vines mend 1 a round", w.hp == 31, w.hp)
	check("harm less block", w.harmed(5) == 1)


func _fights() -> void:
	var h := bare()
	h.build(Vector2i(0, 3), "nest_red")
	h.buildings[Vector2i(0, 3)].level = 3
	var f1 := Fight.make(h.army(), {}, ["grey", "grey", "purple"], 1.0)
	var f2 := Fight.make(h.army(), {}, ["grey", "grey", "purple"], 1.0)
	var e1 := f1.run()
	f2.run()
	check("the same each time", f1.result == f2.result and f1.time == f2.time and e1.size() > 0)
	var lone := Fight.make([], {}, ["grey"], 1.0)
	lone.run()
	check("no army: lost", lone.result == "lost" and lone.harm() == 1)
	var w := bare()
	w.build(Vector2i(0, 3), "nest_green")
	w.build(Vector2i(2, 3), "nest_white")
	check("the white heals", Fight.make(w.army(), {}, ["grey", "grey"], 1.0).run().any(func(e: Dictionary) -> bool:
		return e.t == "heal"))


func _falling_hard() -> void:
	var h := bare()
	h.build(Vector2i(0, 3), "nest_red")
	h.buildings[Vector2i(0, 3)].level = 3
	var f := Fight.make(h.army(), {}, ["spore"], 1.0)
	var ev := f.run()
	var spawned := ev.filter(func(e: Dictionary) -> bool: return e.t == "spawn")
	check("a spore breaks into two mites", spawned.size() == 2 and spawned[0].unit.kind == "mite", spawned.size())
	check("and they are fought too", f.result == "won" and f.units.size() == 3 + 3, [f.result, f.units.size()])
	var b := bare()
	b.build(Vector2i(0, 3), "nest_red")
	var g := Fight.make(b.army(), {}, ["beetle"], 1.0)
	var eb := g.run()
	check("a beetle bursts when it falls", eb.any(func(e: Dictionary) -> bool: return e.t == "burst") or g.result != "won")
	var p := bare()
	p.build(Vector2i(0, 3), "nest_red")
	p.buildings[Vector2i(0, 3)].affixes = ["poison"]
	var fp := Fight.make(p.army(), {}, ["beetle"], 1.0)
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


func _clone() -> void:
	var h := Home.new(rng())
	h.start_round(rng(), 0)
	h.gold = 20
	h.stash = [{"id": "b_red"}]
	var c := h.clone()
	c.build(Vector2i(0, 3), "nest_red")
	c.use_potion(0)
	c.buy(0, c.targets(0)[0] if not c.targets(0).is_empty() else true)
	c.stash.clear()
	c.relics.append("tooth")
	check("the copy changes alone", not h.buildings.has(Vector2i(0, 3)) and h.potions.size() == 1 and h.buffs.is_empty()
		and h.shelf[0] != null and h.relics.is_empty() and h.stash.size() == 1 and h.terrain == c.terrain)
	var f1 := Fight.make(h.army(), h.buffs, ["grey", "grey"], 1.0)
	var f2 := Fight.make(h.clone().army(), h.buffs, ["grey", "grey"], 1.0)
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
		var o := Content.offer({"id": id, "potion": "rage"})
		check("text for " + id, Content.offer_text(o).length() > 3 and str(o.name) != "", Content.offer_text(o))
	check("a packed building says its level", Content.offer({"id": "b_red", "packed": {"level": 2, "affixes": ["shell"]}}).name.contains("2 级"))
	for kind in Content.BUILDINGS:
		for l in range(1, Content.LEVEL_MAX + 1):
			check("building text %s %d" % [kind, l], Content.building_text(kind, l) != "" and Content.level_text(kind, l) != "")
	for id in Content.RELICS:
		check("relic " + id, Content.RELICS[id].says != "")
	for id in Content.TERRAIN:
		check("terrain " + id, Content.TERRAIN[id].says != "")
	for l in Content.LEVELS:
		check("rule of " + l.name, Content.RULES.has(l.rule))