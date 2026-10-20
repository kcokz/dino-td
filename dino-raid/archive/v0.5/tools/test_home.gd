extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run; GAME-DESIGN 14) on set-up cases, headless:
##
##   Godot --headless --path dino-raid --script res://tools/test_home.gd

var failed := 0
var passed := 0


func _init() -> void:
	_first_round()
	_making()
	_neighbours()
	_affixes()
	_cards()
	_potions()
	_land_and_walls()
	_fights()
	_run_flow()
	_deck_changes()
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


func deck() -> Array:
	var d: Array = []
	for id in Content.START_DECK:
		d.append({"id": id, "up": false})
	return d


## A homeland with nothing built, plenty of everything.
func bare() -> Home:
	var h := Home.new([], rng())
	h.buildings.clear()
	h.energy = 10
	h.biomass = 20
	h.genes = 10
	h.alien = 5
	h.potions.clear()
	return h


func _first_round() -> void:
	var h := Home.new(deck(), rng())
	check("starts with a red nest and a pool", h.buildings.size() == 2 and h.buildings[Vector2i(2, 3)].kind == "nest_red"
		and h.buildings[Vector2i(3, 3)].kind == "pool")
	var ev := h.start_round(rng())
	check("income: 3 energy, 3 biomass", h.energy == 3 and h.biomass == 3 + 3, [h.energy, h.biomass])
	check("hand of 5", h.hand.size() == 5, h.hand.size())
	check("income event", ev.any(func(e: Dictionary) -> bool: return e.t == "income"))
	var a := h.army()
	check("one red this round", a.size() == 1 and a[0].kind == "red", a)
	check("the pool beside makes it hardier", is_equal_approx(float(a[0].hp_mult), 1.25), a[0].hp_mult)
	check("a potion to start", h.potions == ["rage"], h.potions)
	h.energy = 10
	var i := 0
	var played := 0
	while i < h.hand.size() and played < 2:
		if h.play(i, h.targets(i)[0] if not h.targets(i).is_empty() else true).is_empty():
			i += 1
		else:
			played += 1
	var left: Array = h.hand.duplicate()
	h.start_round(rng(4))
	check("the hand is kept, filled up to 5", h.hand.size() == Home.HAND and h.hand.slice(0, left.size()) == left,
		[left.size(), h.hand.size()])


func _making() -> void:
	var h := bare()
	h.build(Vector2i(0, 4), "nest_red")
	check("level 1: one", h.army().size() == 1)
	h.buildings[Vector2i(0, 4)].level = 2
	check("level 2: two", h.army().size() == 2)
	h.buildings[Vector2i(0, 4)].level = 5
	var a := h.army()
	check("level 5: three, half again as strong", a.size() == 3 and is_equal_approx(float(a[0].atk_mult), 1.5), a.size())
	h.biomass = 2
	check("biomass short: as many as it pays for", h.army().size() == 2, h.army().size())
	check("they eat 2", h.army_food() == 2, h.army_food())
	var made := h.produce()
	check("produce pays", made.size() == 2 and h.biomass == 0, [made.size(), h.biomass])
	check("next time none", h.army().is_empty())
	h.biomass = 10
	h.build(Vector2i(5, 4), "nest_gold")
	var golds := h.army().filter(func(u: Dictionary) -> bool: return u.kind == "gold")
	check("a gold eats 2", golds.size() == 1 and h.army_food() == 3 + 2, [golds.size(), h.army_food()])
	check("ids stay the same", h.army()[0].id == h.army()[0].id and str(h.army()[0].id).contains(":"))


func _neighbours() -> void:
	var h := bare()
	h.build(Vector2i(1, 4), "nest_red")
	h.build(Vector2i(2, 4), "nest_red")
	check("two reds side by side: no more yet", h.army().size() == 2, h.army().size())
	h.build(Vector2i(0, 4), "nest_red")
	check("three in a row: the middle one makes one more", h.army().size() == 4 and h.count(Vector2i(1, 4)) == 2, h.army().size())
	h.build(Vector2i(1, 3), "nest_red")
	check("never more than one more", h.count(Vector2i(1, 4)) == 2, h.count(Vector2i(1, 4)))
	var g := bare()
	g.build(Vector2i(2, 3), "nest_blue")
	g.build(Vector2i(1, 3), "gym")
	g.build(Vector2i(3, 3), "pool")
	g.build(Vector2i(2, 2), "power")
	var s := g.spec_of(Vector2i(2, 3))
	check("gym: +1 attack", int(s.atk_bonus) == 1, s.atk_bonus)
	check("pool +25%, power -15%: hp x1.10", is_equal_approx(float(s.hp_mult), 1.10), s.hp_mult)
	g.build(Vector2i(4, 3), "sampler")
	check("sampler beside a pool: 2 genes", g.income_genes() == 2, g.income_genes())
	check("power station: 4 energy", g.income_energy() == 4, g.income_energy())
	g.build(Vector2i(2, 4), "stabilizer")
	check("stabilizer: two places", g.slots(Vector2i(2, 3)) == 2, g.slots(Vector2i(2, 3)))
	g.build(Vector2i(0, 2), "nest_red")
	check("diagonal is not beside", g.slots(Vector2i(1, 3)) == 1)


func _affixes() -> void:
	var h := bare()
	h.build(Vector2i(2, 4), "nest_red")
	h.hand = [{"id": "a_shell", "up": false}, {"id": "a_acid", "up": false}, {"id": "a_wings", "up": false}]
	check("affix goes on a nest", h.targets(0) == [Vector2i(2, 4)], h.targets(0))
	h.play(0, Vector2i(2, 4))
	check("paid 2 energy, 2 genes", h.energy == 8 and h.genes == 8, [h.energy, h.genes])
	check("shell: armor 1", int(h.army()[0].armor) == 1)
	check("one place only", h.targets(0).is_empty(), h.targets(0))
	h.build(Vector2i(2, 3), "stabilizer")
	h.play(0, Vector2i(2, 4))
	var st := Content.unit_stats(h.army()[0])
	check("acid: reach 5, alien paid", float(st.range) == 5.0 and h.alien == 4, [st.range, h.alien])
	h.alien = 0
	check("no alien genes: no wings", h.targets(0).is_empty())
	var f := bare()
	f.build(Vector2i(0, 4), "nest_red")
	f.buildings[Vector2i(0, 4)].affixes = ["wings"]
	var fight := Fight.make(f.army(), {}, ["grey", "purple"], 1.0)
	var flier: Dictionary = fight.units[0]
	check("a flier goes for the one furthest back", fight._foe_of(flier).kind == "purple", fight._foe_of(flier).kind)


func _cards() -> void:
	var h := bare()
	h.build(Vector2i(2, 4), "pool")
	h.hand = [{"id": "b_red", "up": false}, {"id": "raise", "up": false}, {"id": "sample", "up": false},
		{"id": "b_pool", "up": false}]
	var tiles := h.targets(0)
	check("build: every open plot", tiles.size() == Home.COLS * Home.OPEN, tiles.size())
	h.play(0, Vector2i(2, 4))
	check("over a pool: pulled down, half back", h.buildings[Vector2i(2, 4)].kind == "nest_red" and h.energy == 10 - 3 + 1,
		[h.buildings[Vector2i(2, 4)].kind, h.energy])
	h.hand.append({"id": "b_red", "up": false})
	check("not over the same kind", not Vector2i(2, 4) in h.targets(3), h.targets(3))
	h.hand.pop_back()
	h.buildings[Vector2i(2, 4)].level = 4
	check("raise: up to 5", h.targets(0) == [Vector2i(2, 4)], h.targets(0))
	h.play(0, Vector2i(2, 4))
	check("level 5", int(h.buildings[Vector2i(2, 4)].level) == 5)
	h.hand = [{"id": "raise", "up": false}]
	check("no further", h.targets(0).is_empty())
	h.hand = [{"id": "sample", "up": false}, {"id": "culture", "up": true}]
	h.genes = 0
	h.biomass = 0
	h.play(0, true)
	h.play(0, true)
	check("gains", h.genes == 3 and h.biomass == 10, [h.genes, h.biomass])
	check("closed rows take nothing", not Vector2i(0, 0) in h._plots_open())
	h.genes = 9
	h.hand = [{"id": "sample", "up": false}]
	h.play(0, true)
	check("genes kept to the store", h.genes == Home.GENES_MAX, h.genes)
	h.build(Vector2i(0, 4), "store")
	check("a store keeps more", h.genes_max() == Home.GENES_MAX + 5 and h.biomass_max() == Home.BIOMASS_MAX + 10)


func _potions() -> void:
	var h := bare()
	h.build(Vector2i(0, 4), "nest_red")
	h.build(Vector2i(2, 4), "nest_blue")
	h.potions = ["breed", "rage", "gel"]
	check("full: no more", not h.add_potion("rush"))
	h.use_potion(0)
	check("breed: each nest one more", h.army().size() == 4, h.army().size())
	check("those eat nothing", h.army_food() == 2, h.army_food())
	h.use_potion(0)
	var f := Fight.make(h.army(), h.buffs, ["grey"], 1.0)
	check("rage: +2 attack", int(f.units[0].atk) == 3 + 2, f.units[0].atk)
	h.hp = 20
	h.use_potion(0)
	check("gel mends 6", h.hp == 26 and h.potions.is_empty(), h.hp)
	var lab := bare()
	lab.build(Vector2i(0, 4), "lab")
	var brewed := 0
	for r in 6:
		brewed += lab.start_round(rng(r)).filter(func(e: Dictionary) -> bool: return e.t == "brewed").size()
	check("a lab brews every 3 rounds", brewed == 2 and lab.potions.size() == 2, [brewed, lab.potions])


func _land_and_walls() -> void:
	var h := bare()
	check("three rows open", h._plots_open().size() == Home.COLS * 3)
	h.open_row()
	h.open_row()
	check("five at most", not h.open_row() and h._plots_open().size() == Home.COLS * Home.ROWS)
	var w := bare()
	w.build(Vector2i(0, 4), "wall")
	check("wall: hp 35", w.hp_max() == 35 and w.hp == 35, [w.hp_max(), w.hp])
	w.build(Vector2i(1, 4), "wall")
	check("walls side by side block more", w.block() == 1 + 1 + 2 * Content.WALL_CHAIN, w.block())
	check("harm less block", w.harmed(5) == 1, w.hp)


func _fights() -> void:
	var h := bare()
	h.build(Vector2i(0, 4), "nest_red")
	h.buildings[Vector2i(0, 4)].level = 4
	var f1 := Fight.make(h.army(), {}, ["grey", "grey", "purple"], 1.0)
	var f2 := Fight.make(h.army(), {}, ["grey", "grey", "purple"], 1.0)
	var e1 := f1.run()
	f2.run()
	check("the same each time", f1.result == f2.result and f1.time == f2.time and e1.size() > 0)
	check("an end", f1.result in ["won", "lost", "time"], f1.result)
	var lone := Fight.make([], {}, ["grey"], 1.0)
	lone.run()
	check("no army: lost", lone.result == "lost" and lone.harm() == 1, lone.result)
	var g := bare()
	g.build(Vector2i(0, 4), "nest_gold")
	var f3 := Fight.make(g.army(), {}, ["grey", "grey", "grey"], 1.0)
	var e3 := f3.run()
	check("gold splashes", e3.filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.from == 1).size() >= 2)
	var w := bare()
	w.build(Vector2i(0, 4), "nest_green")
	w.build(Vector2i(2, 4), "nest_white")
	var f4 := Fight.make(w.army(), {}, ["grey", "grey"], 1.0)
	check("strength adds up", f4.strength("ours") > 20.0 and f4.strength("theirs") > 19.0, [f4.strength("ours"), f4.strength("theirs")])
	check("the white heals", f4.run().any(func(e: Dictionary) -> bool: return e.t == "heal"))


func _run_flow() -> void:
	var r := Run.new(9)
	r.start_round()
	var food := r.home.army_food()
	var f := r.fight()
	f.run()
	var out := r.finish(f)
	check("round 1: a result", out.result in ["won", "lost", "time"], out)
	check("biomass paid", r.home.biomass == 3 + 3 - food, r.home.biomass)
	if out.result == "won":
		check("won: loot", r.home.alien == 1 and out.alien == 1, [r.home.alien, out])
	check("round goes on", r.round == 2 or r.over)
	var g := Run.new(4)
	g.round = 10
	g.start_round()
	var w := g.fight()
	w.run()
	var o := g.finish(w)
	check("round 10 ends the level or the run", o.level_won or g.over, [o, g.home.hp])
	g.over = false
	g.next_level()
	check("next level: a row more", g.home.open_rows == Home.OPEN + 1 and g.level == 1 and g.round == 1)
	check("offer of 3 different", g.offer().size() == 3)
	var first := Run.new(5)
	var late := 0
	for k in 30:
		for id in first.offer():
			if int(Content.CARDS[id].get("from", 0)) > 0:
				late += 1
	check("level 1 offers no later card", late == 0, late)


func _deck_changes() -> void:
	var r := Run.new(5)
	r.start_round()
	r.take("b_gold")
	check("a card won is in the deck", r.deck().size() == Content.START_DECK.size() + 1)
	var one: Dictionary = r.deck()[0]
	r.upgrade(one)
	check("upgraded where it lies", r.deck().filter(func(ci: Dictionary) -> bool: return ci.up).size() == 1)
	check("removed", r.remove(one) and r.deck().size() == Content.START_DECK.size())
	while r.deck().size() > Home.HAND:
		r.remove(r.deck()[0])
	check("never fewer than a hand", not r.remove(r.deck()[0]) and r.deck().size() == Home.HAND)


func _clone() -> void:
	var h := Home.new(deck(), rng())
	h.start_round(rng())
	h.energy = 10
	var c := h.clone()
	c.build(Vector2i(0, 4), "nest_red")
	c.buildings[Vector2i(2, 3)].affixes.append("shell")
	c.use_potion(0)
	check("the copy changes alone", not h.buildings.has(Vector2i(0, 4)) and h.buildings[Vector2i(2, 3)].affixes.is_empty()
		and h.potions.size() == 1 and h.buffs.is_empty())
	var f1 := Fight.make(h.army(), h.buffs, ["grey", "grey"], 1.0)
	var f2 := Fight.make(h.clone().army(), h.buffs, ["grey", "grey"], 1.0)
	f1.run()
	f2.run()
	check("a copy fights the same", f1.result == f2.result and f1.time == f2.time)


func _waves() -> void:
	for level in Content.LEVELS.size():
		for r in range(1, 11):
			check("wave %d/%d" % [level, r], not Content.wave(level, r).is_empty())
	var calm := 0.0
	for k in Content.wave(0, 4):
		calm += Content.enemy_strength(k)
	var big := 0.0
	for k in Content.wave(0, 5):
		big += Content.enemy_strength(k)
	check("round 5 is a big wave", big > calm * 1.2, [calm, big])
	check("the last round has the boss", "boss" in Content.wave(0, 10))


func _texts() -> void:
	for id in Content.CARDS:
		var c := Content.card({"id": id, "up": false})
		check("text for " + id, Content.text(c).length() > 3, Content.text(c))
		var u := Content.card({"id": id, "up": true})
		check("upgraded name for " + id, u.name.ends_with("+"), u.name)
	for kind in Content.BUILDINGS:
		for l in range(1, Content.LEVEL_MAX + 1):
			check("building text %s %d" % [kind, l], Content.building_text(kind, l) != "")