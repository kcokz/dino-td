extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run; GAME-DESIGN 16) on set-up cases, headless:
##
##   Godot --headless --path dino-raid --script res://tools/test_home.gd

var failed := 0
var passed := 0


func _init() -> void:
	_first_round()
	_making()
	_neighbours()
	_affixes()
	_buying()
	_shelf()
	_reroll_and_interest()
	_dear_and_gifts()
	_relics()
	_potions()
	_land_and_walls()
	_fights()
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


## A homeland with nothing built, plenty of everything.
func bare() -> Home:
	var h := Home.new(rng())
	h.buildings.clear()
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
	check("starts with a red nest and a pool", h.buildings.size() == 2 and h.buildings[Vector2i(2, 3)].kind == "nest_red"
		and h.buildings[Vector2i(3, 3)].kind == "pool")
	var ev := h.start_round(rng(), 0)
	check("income: 3 gold, 3 biomass", h.gold == 3 and h.biomass == 3 + 3, [h.gold, h.biomass])
	check("a shelf of 5", h.shelf.size() == Content.SHOP, h.shelf.size())
	var builds := h.shelf.filter(func(oi: Dictionary) -> bool: return Content.OFFERS[oi.id].type == "build").size()
	check("much free land: 3 buildings on it", builds == 3, builds)
	check("income event", ev.any(func(e: Dictionary) -> bool: return e.t == "income"))
	var a := h.army()
	check("one red this round", a.size() == 1 and a[0].kind == "red", a)
	check("the pool beside makes it hardier", is_equal_approx(float(a[0].hp_mult), 1.25), a[0].hp_mult)
	check("a potion to start", h.potions == ["rage"], h.potions)


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
	var made := h.produce()
	check("produce pays", made.size() == 2 and h.biomass == 0, [made.size(), h.biomass])
	h.biomass = 10
	h.build(Vector2i(5, 4), "nest_gold")
	check("a gold eats 2", h.army_food() == 3 + 2, h.army_food())


func _neighbours() -> void:
	var h := bare()
	h.build(Vector2i(1, 4), "nest_red")
	h.build(Vector2i(2, 4), "nest_red")
	check("two reds side by side: no more yet", h.army().size() == 2, h.army().size())
	h.build(Vector2i(0, 4), "nest_red")
	check("three in a row: the middle one makes one more", h.army().size() == 4 and h.count(Vector2i(1, 4)) == 2)
	var g := bare()
	g.build(Vector2i(2, 3), "nest_blue")
	g.build(Vector2i(1, 3), "gym")
	g.build(Vector2i(3, 3), "pool")
	g.build(Vector2i(2, 2), "mine")
	var s := g.spec_of(Vector2i(2, 3))
	check("gym: +1 attack", int(s.atk_bonus) == 1, s.atk_bonus)
	check("pool +25%, mine -15%: hp x1.10", is_equal_approx(float(s.hp_mult), 1.10), s.hp_mult)
	g.build(Vector2i(4, 3), "sampler")
	check("sampler beside a pool: 2 genes", g.income_genes() == 2, g.income_genes())
	check("mine: 4 gold", g.income_gold() == 4, g.income_gold())
	g.build(Vector2i(2, 4), "stabilizer")
	check("stabilizer: two places", g.slots(Vector2i(2, 3)) == 2, g.slots(Vector2i(2, 3)))


func _affixes() -> void:
	var h := bare()
	h.build(Vector2i(2, 4), "nest_red")
	shelf(h, ["a_shell", "a_acid", "a_wings"])
	check("affix goes on a nest", h.targets(0) == [Vector2i(2, 4)], h.targets(0))
	h.buy(0, Vector2i(2, 4))
	check("paid 2 gold, 2 genes", h.gold == 18 and h.genes == 8, [h.gold, h.genes])
	check("shell: armor 1", int(h.army()[0].armor) == 1)
	check("bought: gone from the shelf", h.shelf[0] == null and h.targets(0).is_empty())
	check("one place only", h.targets(1).is_empty(), h.targets(1))
	h.build(Vector2i(2, 3), "stabilizer")
	h.buy(1, Vector2i(2, 4))
	var st := Content.unit_stats(h.army()[0])
	check("acid: reach 5, alien paid", float(st.range) == 5.0 and h.alien == 4, [st.range, h.alien])
	h.alien = 0
	check("no alien genes: no wings", h.targets(2).is_empty())
	var f := bare()
	f.build(Vector2i(0, 4), "nest_red")
	f.buildings[Vector2i(0, 4)].affixes = ["wings"]
	var fight := Fight.make(f.army(), {}, ["grey", "purple"], 1.0)
	check("a flier goes for the one furthest back", fight._foe_of(fight.units[0]).kind == "purple")


func _buying() -> void:
	var h := bare()
	h.build(Vector2i(2, 4), "pool")
	shelf(h, ["b_red", "raise", "sample", "b_pool", "culture"])
	check("build: every open plot but its own kind", h.targets(0).size() == Home.COLS * Home.OPEN)
	h.buy(0, Vector2i(2, 4))
	check("over a pool: pulled down, half back", h.buildings[Vector2i(2, 4)].kind == "nest_red" and h.gold == 20 - 3 + 1,
		[h.buildings[Vector2i(2, 4)].kind, h.gold])
	check("not over the same kind", not Vector2i(2, 4) in h.targets(3) or h.buildings[Vector2i(2, 4)].kind != "pool")
	check("raise from level 1 costs 3", h.price(1, Vector2i(2, 4)) == Content.RAISE + 1)
	h.buildings[Vector2i(2, 4)].level = 4
	check("raise from level 4 costs 6", h.price(1, Vector2i(2, 4)) == Content.RAISE + 4)
	h.buy(1, Vector2i(2, 4))
	check("level 5, 6 paid", int(h.buildings[Vector2i(2, 4)].level) == 5 and h.gold == 18 - 6, h.gold)
	h.genes = 9
	h.buy(2, true)
	check("genes kept to the store", h.genes == Home.GENES_MAX, h.genes)
	h.biomass = 0
	h.buy(4, true)
	check("culture: 6 biomass", h.biomass == 6, h.biomass)
	h.gold = 1
	shelf(h, ["b_gold"])
	check("not enough gold: nowhere", h.targets(0).is_empty())
	check("closed rows take nothing", not Vector2i(0, 0) in h._plots_open())


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
	check("no affix with no nest to take it", not ids.any(func(id: String) -> bool: return id.begins_with("a_")), ids)
	for p in h._plots_open():
		h.build(p, "nest_red")
	var later := 0
	for s in 20:
		h.stock(rng(s), 0)
		var b := h.shelf.filter(func(oi: Dictionary) -> bool: return Content.OFFERS[oi.id].type == "build").size()
		check("full land: one building only", b == 1, b)
		for oi in h.shelf:
			if int(Content.OFFERS[oi.id].get("from", 0)) > 0:
				later += 1
	check("level 1 offers nothing from later levels", later == 0, later)
	for p in h.buildings:
		h.buildings[p].level = 5
		h.buildings[p].affixes = ["shell"]
	h.potions = ["rage", "rage", "rage"]
	h.stock(rng(9), 2)
	var useless := h.shelf.filter(func(oi: Dictionary) -> bool:
		var t: String = Content.OFFERS[oi.id].type
		return t == "raise" or t == "affix" or t == "potion")
	check("nothing that cannot be used, when there is enough else", useless.is_empty(), h.shelf)
	h.relics.append("amber")
	h.stock(rng(2), 0)
	check("amber: one more on the shelf", h.shelf.size() == Content.SHOP + 1, h.shelf.size())


func _reroll_and_interest() -> void:
	var h := bare()
	h.gold = 10
	h.stock(rng(1), 0)
	check("first restock: 1", h.reroll_price() == 1)
	h.reroll(rng(2), 0)
	check("second: 2", h.reroll_price() == 2 and h.gold == 9, [h.reroll_price(), h.gold])
	h.reroll(rng(3), 0)
	check("paid 1 then 2", h.gold == 7, h.gold)
	h.gold = 1
	check("cannot pay: no restock", not h.reroll(rng(4), 0) and h.gold == 1)
	h.relics.append("trilobite")
	h.rerolls = 0
	check("trilobite: the first is free", h.reroll_price() == 0 and h.reroll(rng(5), 0) and h.gold == 1)
	check("then 1", h.reroll_price() == 1)
	h.gold = 4
	check("interest: none under 5", h.interest() == 0)
	h.gold = 12
	check("interest: 2 for 12", h.interest() == 2)
	h.gold = 40
	check("interest: no more than 2", h.interest() == Content.INTEREST_MAX)
	h.relics.append("ammonite")
	check("ammonite: up to 4", h.interest() == Content.INTEREST_MAX + 2)


func _dear_and_gifts() -> void:
	var h := bare()
	h.build(Vector2i(0, 4), "nest_red")
	h.gold = 3
	var worst := 0
	for k in 30:
		h.stock(rng(k), 2)
		var dear := h.shelf.filter(func(oi: Dictionary) -> bool: return h._least_price(oi.id) > h.gold).size()
		worst = maxi(worst, dear)
	check("no more than one on the shelf that costs more than there is", worst <= 1, worst)
	var r := Run.new(7)
	r.home.gold = 0
	r.home.genes = 0
	r.start_round()
	var gifts := r.gift_offer()
	check("three gifts, all different", gifts.size() == 3 and gifts[0].id != gifts[1].id and gifts[1].id != gifts[2].id, gifts)
	var shell := {"id": "a_shell", "gift": true}
	r.take_gift(shell)
	check("a gift goes in front, free", r.home.shelf[0].get("gift", false) and r.home.price(0) == 0)
	r.home.gold = 0
	r.home.genes = 0
	check("free of genes too", r.home.targets(0) == [Vector2i(2, 3)], r.home.targets(0))
	r.home.reroll(rng(1), 0)
	check("restocking keeps it", r.home.shelf[0].get("gift", false) and r.home.shelf[0].id == "a_shell")
	var before := r.home.shelf.size()
	r.home.buy(0, Vector2i(2, 3))
	check("used: gone, nothing paid", r.home.shelf.size() == before - 1 and r.home.gold == 0
		and "shell" in r.home.buildings[Vector2i(2, 3)].affixes, [r.home.shelf.size(), r.home.gold])
	for k in 4:
		r.take_gift({"id": "sample"})
	check("no more than three gifts kept", r.home.shelf.filter(func(o: Variant) -> bool:
		return o != null and o.get("gift", false)).size() == Run.GIFTS)


func _relics() -> void:
	var h := bare()
	h.build(Vector2i(0, 4), "nest_red")
	h.build(Vector2i(4, 4), "nest_blue")
	h.relics = ["tooth", "frill", "egg", "coprolite", "wood"]
	var a := h.army()
	check("tooth: +1 attack", int(a[0].atk_bonus) == 1)
	check("frill: +15% hp", is_equal_approx(float(a[0].hp_mult), 1.15), a[0].hp_mult)
	check("egg: the first nest one more, free", a.size() == 3 and a[1].free and not a[2].free, a.size())
	check("coprolite: +3 biomass a round", h.income_biomass() == 3)
	shelf(h, ["b_red"])
	check("wood: buildings a gold less", h.price(0) == 2)


func _potions() -> void:
	var h := bare()
	h.build(Vector2i(0, 4), "nest_red")
	h.build(Vector2i(2, 4), "nest_blue")
	h.potions = ["breed", "rage", "gel"]
	check("full: no more", not h.add_potion("rush"))
	shelf(h, ["potion"])
	check("full: none to buy", h.targets(0).is_empty())
	h.use_potion(0)
	check("breed: each nest one more", h.army().size() == 4, h.army().size())
	check("those eat nothing", h.army_food() == 2, h.army_food())
	h.use_potion(0)
	var f := Fight.make(h.army(), h.buffs, ["grey"], 1.0)
	check("rage: +2 attack", int(f.units[0].atk) == 3 + 2, f.units[0].atk)
	h.hp = 20
	h.use_potion(0)
	check("gel mends 6", h.hp == 26 and h.potions.is_empty(), h.hp)
	h.buy(0, true)
	check("bought: a potion kept", h.potions == ["gel"] and h.gold == 20 - 3, [h.potions, h.gold])
	var lab := bare()
	lab.build(Vector2i(0, 4), "lab")
	var brewed := 0
	for r in 6:
		brewed += lab.start_round(rng(r), 0).filter(func(e: Dictionary) -> bool: return e.t == "brewed").size()
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
	var lone := Fight.make([], {}, ["grey"], 1.0)
	lone.run()
	check("no army: lost", lone.result == "lost" and lone.harm() == 1, lone.result)
	var g := bare()
	g.build(Vector2i(0, 4), "nest_gold")
	var f3 := Fight.make(g.army(), {}, ["grey", "grey", "grey"], 1.0)
	check("gold splashes", f3.run().filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.from == 1).size() >= 2)
	var w := bare()
	w.build(Vector2i(0, 4), "nest_green")
	w.build(Vector2i(2, 4), "nest_white")
	var f4 := Fight.make(w.army(), {}, ["grey", "grey"], 1.0)
	check("the white heals", f4.run().any(func(e: Dictionary) -> bool: return e.t == "heal"))


func _run_flow() -> void:
	var r := Run.new(9)
	r.start_round()
	var food := r.home.army_food()
	var gold := r.home.gold
	var f := r.fight()
	f.run()
	var out := r.finish(f)
	check("round 1: a result", out.result in ["won", "lost", "time"], out)
	check("biomass paid", r.home.biomass == 3 + 3 - food, r.home.biomass)
	if out.result == "won":
		check("won: gold, alien genes, a potion", out.gold == Content.WIN_GOLD and out.alien == 1 and r.home.alien == 1, out)
	check("gold: what was kept, won gold, interest", r.home.gold == gold + int(out.gold) + int(out.interest),
		[gold, r.home.gold, out])
	check("round goes on", r.round == 2 or r.over)
	var g := Run.new(4)
	g.round = 5
	g.start_round()
	var w := g.fight()
	w.run()
	var o := g.finish(w)
	check("round 5 ends the level or the run", o.level_won or g.over, [o, g.home.hp])
	g.over = false
	g.next_level()
	check("next level: a row more", g.home.open_rows == Home.OPEN + 1 and g.level == 1 and g.round == 1)
	var offer := g.relic_offer()
	check("three relics to choose from", offer.size() == 3)
	g.take_relic(offer[0])
	check("taken, and not offered again", offer[0] in g.home.relics and not offer[0] in g.relic_offer())


func _clone() -> void:
	var h := Home.new(rng())
	h.start_round(rng(), 0)
	h.gold = 20
	var c := h.clone()
	c.build(Vector2i(0, 4), "nest_red")
	c.buildings[Vector2i(2, 3)].affixes.append("shell")
	c.use_potion(0)
	c.buy(0, c.targets(0)[0])
	c.relics.append("tooth")
	check("the copy changes alone", not h.buildings.has(Vector2i(0, 4)) and h.buildings[Vector2i(2, 3)].affixes.is_empty()
		and h.potions.size() == 1 and h.buffs.is_empty() and h.shelf[0] != null and h.relics.is_empty() and h.gold == 20)
	var f1 := Fight.make(h.army(), h.buffs, ["grey", "grey"], 1.0)
	var f2 := Fight.make(h.clone().army(), h.buffs, ["grey", "grey"], 1.0)
	f1.run()
	f2.run()
	check("a copy fights the same", f1.result == f2.result and f1.time == f2.time)


func _waves() -> void:
	for level in Content.LEVELS.size():
		for r in range(1, int(Content.LEVELS[level].rounds) + 1):
			check("wave %d/%d" % [level, r], not Content.wave(level, r).is_empty())
	var calm := 0.0
	for k in Content.wave(0, 4):
		calm += Content.enemy_strength(k)
	var big := 0.0
	for k in Content.wave(0, 5):
		big += Content.enemy_strength(k)
	check("round 5 is a big wave", big > calm * 1.2, [calm, big])
	check("the last round has the level's boss", "boss1" in Content.wave(0, 5) and "boss2" in Content.wave(1, 5)
		and "boss3" in Content.wave(2, 5))


func _texts() -> void:
	for id in Content.OFFERS:
		var o := Content.offer({"id": id, "potion": "rage"})
		check("text for " + id, Content.offer_text(o).length() > 3 and str(o.name) != "", Content.offer_text(o))
	for kind in Content.BUILDINGS:
		for l in range(1, Content.LEVEL_MAX + 1):
			check("building text %s %d" % [kind, l], Content.building_text(kind, l) != "")
	for id in Content.RELICS:
		check("relic " + id, Content.RELICS[id].says != "")