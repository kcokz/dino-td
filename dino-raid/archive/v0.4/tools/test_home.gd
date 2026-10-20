extends SceneTree
## Checks the homeland's and the battle's rules (Home, Fight, Run) on set-up cases, headless:
##
##   Godot --headless --path dino-raid --script res://tools/test_home.gd

var failed := 0
var passed := 0


func _init() -> void:
	_first_round()
	_producers()
	_beside()
	_room_and_merge()
	_cards()
	_fights()
	_run_flow()
	_full_yard()
	_deck_changes()
	_clone()
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


func _first_round() -> void:
	var h := Home.new(deck(), rng())
	check("starts with the red nest", h.buildings.has(Vector2i(2, 1)) and h.buildings[Vector2i(2, 1)].kind == "hatch_red")
	var ev := h.start_round(rng())
	check("it makes a red at once", h.units.size() == 1 and h.units[0].kind == "red", h.units)
	check("energy 3", h.energy == 3, h.energy)
	check("hand of 5", h.hand.size() == 5, h.hand.size())
	check("made event", ev.filter(func(e: Dictionary) -> bool: return e.t == "made").size() == 1, ev)


func _producers() -> void:
	var h := Home.new([], rng())
	h.buildings.clear()
	h.build(Vector2i(0, 0), "hatch_blue")
	var made := []
	for r in 5:
		made.append(h.start_round(rng()).filter(func(e: Dictionary) -> bool: return e.t == "made").size())
	check("blue: made in rounds 1, 3, 5", made == [1, 0, 1, 0, 1], made)
	check("and the three became one of two stars", h.units.size() == 1 and h.units[0].star == 2, h.units)


func _beside() -> void:
	var h := Home.new([], rng())
	h.buildings.clear()
	h.build(Vector2i(1, 1), "hatch_blue")
	h.build(Vector2i(2, 1), "nursery")
	h.build(Vector2i(0, 1), "gym")
	check("a nursery beside: every round", h.every(Vector2i(1, 1)) == 1, h.every(Vector2i(1, 1)))
	h.start_round(rng())
	h.start_round(rng())
	check("two in two rounds", h.units.size() == 2, h.units.size())
	check("drilled +1 atk", h.units[0].bonus_atk == 1, h.units[0])
	h.build(Vector2i(5, 3), "farm")
	check("income 4 with a farm", h.income() == 4, h.income())
	h.build(Vector2i(5, 2), "wall")
	check("wall: hp max 35, hp follows", h.hp_max() == 35 and h.hp == 35, [h.hp_max(), h.hp])
	check("blocks 1", h.harmed(3) == 2 and h.hp == 33, h.hp)


func _room_and_merge() -> void:
	var h := Home.new([], rng())
	for i in 2:
		h.start_round(rng())
	check("two reds", h.units.size() == 2)
	h.start_round(rng())
	check("three reds merge to one of two stars", h.units.size() == 1 and h.units[0].star == 2, h.units)
	var full := Home.new([], rng())
	full.buildings.clear()
	full.build(Vector2i(0, 0), "hatch_red")
	full.buildings[Vector2i(0, 0)].level = 2
	full.build(Vector2i(3, 0), "hatch_blue")
	full.buildings[Vector2i(3, 0)].level = 2
	var evs: Array = []
	for i in 6:
		evs.append_array(full.start_round(rng()))
	check("never more than room", full.units.size() <= full.room(), [full.units.size(), full.room()])
	check("a full event when it was", evs.filter(func(e: Dictionary) -> bool: return e.t == "full").size() > 0)


func _cards() -> void:
	var h := Home.new([], rng())
	h.energy = 10
	h.hand = [{"id": "b_gym", "up": false}, {"id": "expand", "up": false}, {"id": "overtime", "up": false},
		{"id": "rally", "up": false}, {"id": "mend", "up": false}]
	check("build: plots are the empty ones", h.targets(0).size() == Home.COLS * Home.ROWS - 1)
	check("cannot build on a building", h.play(0, Vector2i(2, 1)).is_empty())
	check("build the gym", not h.play(0, Vector2i(3, 1)).is_empty() and h.buildings[Vector2i(3, 1)].kind == "gym")
	check("energy 7", h.energy == 7, h.energy)
	check("expand the nest", not h.play(0, Vector2i(2, 1)).is_empty() and h.buildings[Vector2i(2, 1)].level == 2)
	var ev := h.play(0, Vector2i(2, 1))
	check("overtime makes two now (level 2), drilled", h.units.size() == 2 and h.units[0].bonus_atk == 1, [h.units, ev])
	check("rally played", not h.play(0, true).is_empty())
	check("battle atk is 2", h.buffs.get("atk", 0) == 2, h.buffs)
	h.hp = 20
	h.energy = 10
	h.play(0, true)
	check("mend +5", h.hp == 25, h.hp)
	check("hand used up", h.hand.is_empty())
	h.energy = 10
	h.hand = [{"id": "train", "up": true}, {"id": "star", "up": false}]
	var id: int = h.units[0].id
	h.play(0, id)
	check("train+: +6 hp +2 atk", h.unit(id).bonus_hp == 6 and h.unit(id).bonus_atk == 3, h.unit(id))
	h.play(0, id)
	check("star: two stars", h.unit(id).star == 2, h.unit(id))
	h.energy = 0
	h.hand = [{"id": "b_red", "up": false}]
	check("no energy: no targets", h.targets(0).is_empty())


func _fights() -> void:
	var a := Home.new([], rng())
	a.units = [{"id": 90, "kind": "red", "star": 1, "bonus_hp": 0, "bonus_atk": 0},
		{"id": 91, "kind": "red", "star": 1, "bonus_hp": 0, "bonus_atk": 0},
		{"id": 92, "kind": "blue", "star": 1, "bonus_hp": 0, "bonus_atk": 0}]
	var f1 := Fight.make(a, ["grey", "grey"], 1.0)
	var e1 := f1.run()
	var f2 := Fight.make(a, ["grey", "grey"], 1.0)
	var e2 := f2.run()
	check("the same armies end the same way", str(e1) == str(e2) and f1.result == f2.result, [f1.result, f2.result])
	check("2 red 1 blue beat 2 grey", f1.result == "won", [f1.result, f1.time])
	var b := Home.new([], rng())
	b.units = [{"id": 95, "kind": "red", "star": 1, "bonus_hp": 0, "bonus_atk": 0}]
	var f3 := Fight.make(b, ["black", "black", "black"], 1.0)
	f3.run()
	check("one red loses to three black", f3.result == "lost", f3.result)
	check("harm 6", f3.harm() == 6, f3.harm())
	check("the red fell", f3.fallen() == [95], f3.fallen())
	var c := Home.new([], rng())
	c.units = [{"id": 96, "kind": "green", "star": 1, "bonus_hp": 0, "bonus_atk": 0},
		{"id": 97, "kind": "white", "star": 1, "bonus_hp": 0, "bonus_atk": 0}]
	var f4 := Fight.make(c, ["grey", "grey"], 1.0)
	var e4 := f4.run()
	check("the white heals", e4.filter(func(e: Dictionary) -> bool: return e.t == "heal").size() > 0)
	var d := Home.new([], rng())
	d.units = [{"id": 98, "kind": "gold", "star": 1, "bonus_hp": 0, "bonus_atk": 0}]
	var f5 := Fight.make(d, ["grey", "grey", "grey"], 1.0)
	var e5 := f5.run()
	var first_hits := e5.filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.from == 1)
	check("gold splashes", first_hits.size() >= 2, first_hits.size())


func _run_flow() -> void:
	var r := Run.new(9)
	r.start_round()
	var f := r.fight()
	f.run()
	var out := r.finish(f)
	check("round 1 against 2 grey with 1 red: a result", out.result in ["won", "lost", "time"], out)
	check("the fallen come back", r.home.units.size() == f.alive("ours").size() + f.fallen().size() or not Run.FALLEN_COME_BACK,
		[r.home.units.size(), f.fallen()])
	check("round goes on unless over", r.round == 2 or r.over or out.level_won, r.round)
	var g := Run.new(4)
	g.round = 10
	g.start_round()
	var w := g.fight()
	w.run()
	var o := g.finish(w)
	check("round 10 ends the level or the run", o.level_won or g.over, [o, g.home.hp])
	check("offer of 3 different", g.offer().size() == 3)
	check("deck is all the cards", g.deck().size() == Content.START_DECK.size(), g.deck().size())


func _full_yard() -> void:
	var h := Home.new([], rng())
	h.units.clear()
	for k in ["red", "red", "blue", "blue", "green"]:
		h.units.append({"id": h._id(), "kind": k, "star": 1, "bonus_hp": 0, "bonus_atk": 0})
	var ev := h.make(Content.FIRST.pos)
	check("full yard: a third red is still made, and three become one",
		ev.any(func(e: Dictionary) -> bool: return e.t == "made") and ev.any(func(e: Dictionary) -> bool: return e.t == "merged")
		and h.units.size() == 4, [ev.map(func(e: Dictionary) -> String: return e.t), h.units.size()])
	h.build(Vector2i(0, 0), "hatch_green")
	h.units.append({"id": h._id(), "kind": "white", "star": 1, "bonus_hp": 0, "bonus_atk": 0})
	h.units.append({"id": h._id(), "kind": "gold", "star": 1, "bonus_hp": 0, "bonus_atk": 0})
	var before := h.units.size()
	var ev2 := h.make(Vector2i(0, 0))
	check("full yard: a green that makes no three is not", ev2.size() == 1 and ev2[0].t == "full" and h.units.size() == before,
		[ev2, h.units.size()])


func _deck_changes() -> void:
	var r := Run.new(5)
	r.start_round()
	r.take("b_gold")
	check("a card won is in the deck", r.deck().size() == Content.START_DECK.size() + 1 and
		r.home.draw.any(func(ci: Dictionary) -> bool: return ci.id == "b_gold"), r.deck().size())
	var one: Dictionary = r.deck()[0]
	r.upgrade(one)
	check("upgraded where it lies", r.deck().filter(func(ci: Dictionary) -> bool: return ci.up).size() == 1)
	check("removed", r.remove(one) and r.deck().size() == Content.START_DECK.size())
	while r.deck().size() > Home.HAND:
		r.remove(r.deck()[0])
	check("never fewer than a hand", not r.remove(r.deck()[0]) and r.deck().size() == Home.HAND, r.deck().size())
	var s := Run.new(6)
	s.start_round()
	s.next_level()
	check("next level: all cards to draw", s.home.draw.size() == Content.START_DECK.size() and s.home.hand.is_empty()
		and s.home.discard.is_empty() and s.level == 1 and s.round == 1, [s.home.draw.size(), s.level, s.round])


func _clone() -> void:
	var h := Home.new(deck(), rng())
	h.start_round(rng())
	h.energy = 10
	var c := h.clone()
	c.play(c.hand.find(c.hand.filter(func(ci: Dictionary) -> bool: return ci.id == "rally").front()) if
		c.hand.any(func(ci: Dictionary) -> bool: return ci.id == "rally") else 0, true)
	c.units[0].bonus_atk = 9
	c.build(Vector2i(0, 0), "farm")
	check("the copy changes alone", h.units[0].bonus_atk == 0 and not h.buildings.has(Vector2i(0, 0)) and h.energy == 10
		and h.hand.size() == 5, [h.units[0], h.energy, h.hand.size()])
	var f1 := Fight.make(h, ["grey", "grey"], 1.0)
	var f2 := Fight.make(h.clone(), ["grey", "grey"], 1.0)
	f1.run()
	f2.run()
	check("a copy fights the same", f1.result == f2.result and f1.time == f2.time and f1.fallen() == f2.fallen())


func _texts() -> void:
	for id in Content.CARDS:
		var c := Content.card({"id": id, "up": false})
		check("text for " + id, Content.text(c).length() > 3, Content.text(c))
		var u := Content.card({"id": id, "up": true})
		check("upgraded name for " + id, u.name.ends_with("+"), u.name)
	for kind in Content.BUILDINGS:
		for l in [1, 2, 3]:
			check("building text %s %d" % [kind, l], Content.building_text(kind, l) != "")
	for level in Content.LEVELS.size():
		for r in range(1, 11):
			check("wave %d/%d" % [level, r], not Content.wave(level, r).is_empty())
