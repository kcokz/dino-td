extends SceneTree
## Checks the rules of a battle (Sim) on set-up boards: each case builds a state by hand, plays it, and says
## what it expected and what came. Headless, no pictures:
##
##   Godot --headless --path dino-raid --script res://tools/test_sim.gd

var failed := 0
var passed := 0


func _init() -> void:
	_first_turn()
	_pack_hunts_walker()
	_stampede_tramples()
	_hungry_rex()
	_ash_blinds()
	_nests_and_buildings()
	_walled_in()
	_goes_round()
	_win_and_lose()
	_preview_matches()
	_cards_and_deck()
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(what: String, ok: bool, got: Variant = null) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL  %s  (got %s)" % [what, got])


## An empty board: no machine, no nests, nothing but what a case puts there.
func board() -> BattleState:
	var s := BattleState.new()
	s.energy = 10
	s.waves = false
	return s


func dino(s: BattleState, kind: String, p: Vector2i, pack := 1) -> Dictionary:
	return Sim._add_dino(s, kind, p, pack, false)


func robot(s: BattleState, kind: String, p: Vector2i) -> Dictionary:
	return Sim._add_robot(s, kind, p)


func _first_turn() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var deck: Array = []
	for id in Rules.START_DECK:
		deck.append({"id": id, "up": false})
	var s := Sim.new_battle(0, deck, rng)
	check("hand of 5", s.hand.size() == 5, s.hand.size())
	check("energy 4", s.energy == 4, s.energy)
	check("one nest", s.nests.size() == 1)
	var ev := Sim.end_turn(s)
	var hatched := ev.filter(func(e: Dictionary) -> bool: return e.t == "hatch")
	check("pack hatches at the end of turn 1", hatched.size() == 1, ev)
	check("pack of 4 out at (2,1)", hatched.size() == 1 and hatched[0].unit.bodies == 4 and hatched[0].unit.pos == Vector2i(2, 1), hatched)
	var spawned := ev.filter(func(e: Dictionary) -> bool: return e.t == "spawn")
	check("2 walkers out for turn 2", spawned.size() == 2, spawned.size())
	check("turn 2", s.turn == 2, s.turn)


func _pack_hunts_walker() -> void:
	var s := board()
	var pack := dino(s, "coelophysis", Vector2i(2, 1), 4)
	var w := robot(s, "walker", Vector2i(2, 5))
	var ev := Sim.resolve(s)
	var bite := ev.filter(func(e: Dictionary) -> bool: return e.t == "bite")
	check("pack closes 3 and bites 4x2", bite.size() == 1 and bite[0].dmg == 8 and pack.pos == Vector2i(2, 4), [pack.pos, bite])
	check("walker left with 4", w.hp == 4, w.hp)
	var shot := ev.filter(func(e: Dictionary) -> bool: return e.t == "shoot")
	check("walker shoots the pack 4", shot.size() == 1 and shot[0].target == pack.id and pack.hp == 12, pack.hp)
	check("3 bodies left at 12", pack.bodies == 3, pack.bodies)
	Sim.resolve(s)
	check("walker dies next turn", s.unit(w.id) == null)


func _stampede_tramples() -> void:
	var s := board()
	var tri := dino(s, "triceratops", Vector2i(2, 2))
	var w1 := robot(s, "walker", Vector2i(2, 4))
	var w2 := robot(s, "walker", Vector2i(2, 5))
	var small := dino(s, "coelophysis", Vector2i(2, 3), 1)
	s.noises.append({"pos": Vector2i(2, 1), "reach": 2})
	var ev := Sim.resolve(s)
	var charge := ev.filter(func(e: Dictionary) -> bool: return e.t == "charge")
	check("one charge", charge.size() == 1, ev)
	check("own small one trampled and run over", s.unit(small.id) == null)
	check("walker 1 trampled to 7 and stops the charge", w1.hp == 7 and tri.pos == Vector2i(2, 3), [w1.hp, tri.pos])
	check("walker 2 untouched by the charge", w2.hp <= 12)


func _hungry_rex() -> void:
	var s := board()
	var rex := dino(s, "tyrannosaurus", Vector2i(1, 1))
	var pack := dino(s, "coelophysis", Vector2i(3, 1), 4)
	var ev := Sim.resolve(s)
	var bite := ev.filter(func(e: Dictionary) -> bool: return e.t == "bite" and e.id == rex.id)
	check("hungry rex eats the pack", bite.size() == 1 and bite[0].target == pack.id, ev)
	check("12 kills 3 of 4", pack.bodies == 1 and pack.hp == 4, [pack.bodies, pack.hp])
	var s2 := board()
	var rex2 := dino(s2, "tyrannosaurus", Vector2i(1, 1))
	dino(s2, "coelophysis", Vector2i(3, 1), 4)
	s2.buildings.append({"id": 900, "pos": Vector2i(0, 0), "kind": "carrion", "up": false, "hp": 8})
	var ev2 := Sim.resolve(s2)
	check("fed rex leaves them be", ev2.filter(func(e: Dictionary) -> bool: return e.t == "bite").is_empty(), ev2)
	check("fed rex stays", rex2.pos == Vector2i(1, 1))


func _ash_blinds() -> void:
	var s := board()
	dino(s, "triceratops", Vector2i(2, 1))
	robot(s, "turret", Vector2i(2, 5))
	var ev := Sim.resolve(s)
	check("turret shoots 4 tiles off", ev.filter(func(e: Dictionary) -> bool: return e.t == "shoot").size() == 1)
	var a := board()
	var tri := dino(a, "triceratops", Vector2i(2, 1))
	robot(a, "turret", Vector2i(2, 5))
	a.ashes.append({"pos": Vector2i(2, 5), "turns": 2})
	Sim.resolve(a)
	check("in ash it only shoots beside it", tri.hp == 24, tri.hp)
	check("ash wears off by a turn", a.ashes.size() == 1 and a.ashes[0].turns == 1, a.ashes)


func _nests_and_buildings() -> void:
	var s := board()
	Sim.lay(s, Vector2i(1, 0), {"id": "egg_triceratops", "up": false})
	var n: Dictionary = s.nests[0]
	check("no ferns: 4 turns", Sim.hatch_time(s, n) == 4, Sim.hatch_time(s, n))
	s.buildings.append({"id": 901, "pos": Vector2i(0, 0), "kind": "ferns", "up": false, "hp": 8})
	check("ferns beside: 2 turns", Sim.hatch_time(s, n) == 2, Sim.hatch_time(s, n))
	s.buildings.append({"id": 902, "pos": Vector2i(2, 0), "kind": "compost", "up": false, "hp": 8})
	check("and compost: 1 turn", Sim.hatch_time(s, n) == 1, Sim.hatch_time(s, n))
	var ev := Sim.resolve(s)
	check("first three-horn out", ev.filter(func(e: Dictionary) -> bool: return e.t == "hatch").size() == 1, ev)
	var lead: Dictionary = s.units[0]
	check("the first is the leader, 30 hp", lead.lead and lead.hp == 30, lead)
	Sim.resolve(s)
	check("second out, not a leader", s.units.size() == 2 and not s.units[1].lead and s.units[1].hp == 24)
	check("nest empty", n.eggs == 0)
	var rex := board()
	Sim.lay(rex, Vector2i(2, 0), {"id": "egg_tyrannosaurus", "up": false})
	robot(rex, "walker", Vector2i(2, 3))
	var rn: Dictionary = rex.nests[0]
	check("rex eggs paused with a robot 3 off", Sim.paused(rex, rn))
	rex.units[0].pos = Vector2i(2, 7)
	check("not paused once it is far", not Sim.paused(rex, rn))


func _walled_in() -> void:
	var s := board()
	Sim.lay(s, Vector2i(2, 0), {"id": "egg_coelophysis", "up": false})
	s.nests[0].eggs = 0
	for x in Rules.COLS:
		s.buildings.append({"id": 910 + x, "pos": Vector2i(x, 2), "kind": "ferns", "up": false, "hp": 8})
	var w := robot(s, "walker", Vector2i(2, 4))
	var ev := Sim.resolve(s)
	var shots := ev.filter(func(e: Dictionary) -> bool: return e.t == "shoot" and e.has("building"))
	check("walled out, it shoots the wall", shots.size() == 1, ev)
	check("and does not walk through", w.pos.y >= 3, w.pos)


## A nest walled round by its own side's things is no goal: the walker goes for one it can get to.
func _goes_round() -> void:
	var s := board()
	for p in [Vector2i(2, 0), Vector2i(4, 1), Vector2i(0, 1), Vector2i(4, 0), Vector2i(1, 0), Vector2i(2, 1), Vector2i(0, 0)]:
		Sim.lay(s, p, {"id": "egg_coelophysis", "up": false})
		s.nests[-1].eggs = 0
	for p in [Vector2i(0, 3), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(0, 2), Vector2i(2, 2)]:
		s.buildings.append({"id": 950 + p.x * 10 + p.y, "pos": p, "kind": "ferns", "up": false, "hp": 8})
	s.rocks[Vector2i(0, 4)] = true
	s.rocks[Vector2i(4, 3)] = true
	dino(s, "triceratops", Vector2i(3, 0))
	var w := robot(s, "walker", Vector2i(3, 5))
	var ev := Sim.resolve(s)
	check("it moves, round to a nest it can reach", ev.filter(func(e: Dictionary) -> bool: return e.t == "move").size() == 1, ev)
	Sim.resolve(s)
	var shots: int = 0
	for i in 3:
		shots += Sim.resolve(s).filter(func(e: Dictionary) -> bool: return e.t == "shoot").size()
	check("and gets to shooting", shots > 0, w.pos)


func _win_and_lose() -> void:
	var s := board()
	var m := Sim._add_robot(s, "machine", Rules.MACHINE_AT, 6)
	dino(s, "tyrannosaurus", Vector2i(2, 5))
	Sim.resolve(s)
	check("machine down: won", s.over and s.won and s.unit(m.id) == null)
	var l := board()
	Sim.lay(l, Vector2i(2, 0), {"id": "egg_coelophysis", "up": false})
	l.nests[0].eggs = 0
	l.nests[0].hp = 3
	robot(l, "walker", Vector2i(2, 3))
	Sim.resolve(l)
	check("last nest down: lost", l.over and not l.won, [l.over, l.nests.size()])


func _preview_matches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var deck: Array = []
	for id in Rules.START_DECK:
		deck.append({"id": id, "up": false})
	var s := Sim.new_battle(1, deck, rng)
	for turn in 6:
		var i := 0
		while i < s.hand.size():
			var where := Sim.targets(s, i)
			if where.is_empty():
				i += 1
				continue
			Sim.play(s, i, where[rng.randi_range(0, where.size() - 1)])
		var shown := Sim.preview(s)
		var done := Sim.end_turn(s)
		check("turn %d: preview is what happens" % (turn + 1), str(shown) == str(done), [shown.size(), done.size()])
		if s.over:
			break
		Sim.start_turn(s, rng)


func _cards_and_deck() -> void:
	var c := Rules.card({"id": "egg_coelophysis", "up": true})
	check("upgrade: pack of 6", c.pack == 6 and c.name == "腔骨龙蛋+", c)
	check("text has the numbers", Rules.text(c).find("6") >= 0, Rules.text(c))
	var run := RunState.new(5)
	var o := run.offer()
	check("offer of 3 different", o.size() == 3 and o[0] != o[1] and o[1] != o[2] and o[0] != o[2], o)
	check("waves keep coming", Rules.wave(0, 8).size() == 3 and Rules.wave(0, 9).is_empty(), [Rules.wave(0, 8), Rules.wave(0, 9)])
	for id in Rules.CARDS:
		check("text for " + id, Rules.text(Rules.card({"id": id, "up": false})) != "")
