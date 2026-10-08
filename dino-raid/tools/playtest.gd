extends SceneTree
## A battle played by a script, with pictures -- for seeing a change at work without playing.
##
##   Godot --path dino-raid --script res://tools/playtest.gd -- <folder for frames> [siege [minutes]]
##
## Without "siege": a fixed run through what v0.2 adds -- the first clutch hatching round its leader,
## three-horn eggs with ferns beside them and without, a compost heap, a carrion pit and a tyrannosaur's egg,
## each help card, the first waves -- saving a frame at each step and printing what it sees.
##
## "siege": plays whole battles the simple way -- keeps eggs while it has few, else the building its eggs lack,
## else any card; plants and builds where a card fits; lets help loose where it does something -- until it ends
## or the minutes pass (15 by default), then prints an account: how long, what was kept, hatched and killed,
## how many waves. For finding what breaks, not for balance.
##
## "duel <species> <how many> <walkers>": that many dinosaurs and walkers meet in the open, no cards or waves;
## prints who is left after 30 s -- for checking a fight works, and how it goes.

var battle: Battle
var out := ""
var _n := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	battle = load("res://scenes/Battle.tscn").instantiate()
	root.add_child(battle)
	if args.size() > 1 and args[1] == "siege":
		_siege(float(args[2]) if args.size() > 2 else 15.0)
	elif args.size() > 4 and args[1] == "duel":
		_duel(args[2], int(args[3]), int(args[4]))
	else:
		_run()


func _duel(kind: String, count: int, walkers: int) -> void:
	await physics_frame
	battle._next_offer = INF
	battle._next_wave = INF
	battle._gate_size = 0
	for r: Robot in battle.robots.duplicate():
		if r.kind == Robot.Kind.WALKER:
			r.queue_free()
			battle.robots.erase(r)
	var lead: Dino = null
	for i in count:
		var d := battle.born(kind, Vector3(-14 + randf_range(-2, 2), 0, randf_range(-3, 3)), Vector3.RIGHT, lead)
		if lead == null:
			lead = d
	for i in walkers:
		var w := battle._add_robot(Robot.Kind.WALKER, Vector3(2, 0, -2 + i * 2.0))
		w.march()
	var start := battle.clock
	while battle.clock < start + 30.0 and not battle.over:
		await physics_frame
		if battle.clock > start + 8.0 and battle.clock < start + 8.1:
			await _shot("duel")
	var hp := 0.0
	for r: Robot in battle.robots:
		if r.kind == Robot.Kind.WALKER:
			hp += r.hp
	print("duel %d %s vs %d walkers: %d dinos left, walkers left %d (hp %.0f), fallen %s" % [count, kind, walkers,
		battle.dinos.size(), battle.robots.filter(func(r: Robot) -> bool: return r.kind == Robot.Kind.WALKER).size(), hp, battle.fallen])
	quit()


func _run() -> void:
	Engine.time_scale = 2.0
	while battle.offer.is_empty() and not battle.over:
		await physics_frame
	battle.offer = ["scent", "noise", "egg_coelophysis"]  # the two that steer, to see their cards
	for i in 3:
		await process_frame  # the cards' pictures are taken a frame after they are asked for
	await _shot("offer")
	await _until(1.5)
	battle.hand = ["egg_triceratops", "ferns", "egg_triceratops", "compost"]
	_put(Vector2i(2, 0))   # three-horn eggs...
	_put(Vector2i(2, 1))   # ...with ferns beside them
	_put(Vector2i(2, 4))   # three-horn eggs with no ferns...
	_put(Vector2i(3, 4))   # ...but a compost heap
	await _shot("planted")
	await _until(8.0)
	await _shot("hatching")
	await _until(12.0)
	battle.hand = ["carrion", "egg_tyrannosaurus", "egg_tyrannosaurus"]
	_put(Vector2i(0, 0))   # a carrion pit at the back...
	_put(Vector2i(0, 1))   # ...a tyrannosaur's egg beside it
	_put(Vector2i(3, 2))   # and one at the front with no pit
	await _until(20.0)
	_nests()
	for n: Nest in battle.nests:
		print("  -- ", n.plot, " --")
		print(n.describe())
	await _shot("buildings")
	await _until(30.0)
	_nests()
	battle.hand = ["call", "scent", "blood", "ash"]
	print("call: ", battle.act(0, "play", {"slot": 0, "at": Vector3(-6, 0, -4)}))
	await _until(32.0)
	print("scent: ", battle.act(0, "play", {"slot": 0, "at": Vector3(-6, 0, 2)}))
	await _shot("called")
	await _until(40.0)
	var hunters := battle.dinos.filter(func(d: Dino) -> bool: return d.s.diet == "meat")
	if not hunters.is_empty():
		print("blood: ", battle.act(0, "play", {"slot": 0, "at": (hunters[0] as Dino).global_position}))
	print("ash: ", battle.act(0, "play", {"slot": 0, "at": Vector3(14, 0, -7)}))
	await _shot("blood_ash")
	for t in [46.0, 55.0]:
		await _until(t)
		await _shot("wave")
	var grazers := battle.dinos.filter(func(d: Dino) -> bool: return d.s.diet == "plant")
	if not grazers.is_empty():
		battle.hand = ["noise"]
		var g: Dino = grazers[0]
		print("noise: ", battle.act(0, "play", {"slot": 0, "at": g.global_position + Vector3(-6, 0, 0)}))
		await _until(57.0)
		await _shot("noise")
		print("  grazers: ", grazers.map(func(d: Dino) -> String: return Dino.Mode.keys()[d.mode] if d.alive() else "dead"))
	for t in [70.0, 90.0]:
		await _until(t)
		await _shot("wave")
	battle.hand = ["ferns", "compost", "blood", "ash"]
	while battle.offer.is_empty() and not battle.over:
		await physics_frame
	if not battle.over:
		for i in 3:
			await process_frame
		await _shot("full_hand")
		battle.act(0, "choose", {"offer": 0, "replace": 2})
		print("kept with a full hand: ", battle.hand)
	else:
		await _shot("over")
	_nests()
	_account()
	quit()


func _siege(minutes: float) -> void:
	Engine.time_scale = 4.0
	var next_shot := 0.0
	while not battle.over and battle.clock < minutes * 60.0:
		await physics_frame
		if not battle.offer.is_empty():
			battle.act(0, "choose", {"offer": _bot_choose(), "replace": randi() % Battle.HAND})
			continue
		_bot_play()
		if battle.clock >= next_shot:
			next_shot += 60.0
			await _shot("siege")
	await _shot("end")
	_account()
	quit()


## Until the battle's clock says `t`, keeping no card offered meanwhile.
func _until(t: float) -> void:
	while battle.clock < t and not battle.over:
		if not battle.offer.is_empty():
			battle.act(0, "choose", {"offer": -1})
		await physics_frame


## The first card in the hand, played in plot `p`.
func _put(p: Vector2i) -> void:
	var card: String = battle.hand[0]
	print("play %s at %s: %s" % [card, p, battle.act(0, "play", {"slot": 0, "at": battle.garden.centre(p)})])


## Which card of the offer the bot keeps: eggs while it has few, the building its eggs lack, else any.
func _bot_choose() -> int:
	var eggs := 0
	var lacking := {}
	for n: Nest in battle.nests:
		eggs += n.left
		for need in n.missing:
			lacking[need] = true
	var best := []
	var top := -1
	for i in battle.offer.size():
		var card: String = battle.offer[i]
		var score := 1
		if Cards.ALL[card].type == "egg" and eggs < 8:
			score = 3
		elif lacking.has(card):
			score = 2
		if score > top:
			top = score
			best = [i]
		elif score == top:
			best.append(i)
	return best.pick_random()


func _bot_play() -> void:
	for slot in range(battle.hand.size() - 1, -1, -1):
		var at: Variant = _spot_for(battle.hand[slot])
		if at != null:
			battle.act(0, "play", {"slot": slot, "at": at})


## Where the bot would put `card`, or null to keep it for now.
func _spot_for(card: String) -> Variant:
	var g := battle.garden
	match Cards.ALL[card].type:
		"egg", "building":
			var fits: Array = []
			var good: Array = []
			for x in Garden.ROWS:
				for z in Garden.COLS:
					var p := Vector2i(x, z)
					if not battle.can_play(card, g.centre(p)):
						continue
					fits.append(p)
					var want: String = {"egg_triceratops": "ferns", "egg_tyrannosaurus": "carrion"}.get(card, "")
					if want != "" and g.beside(p, want):
						good.append(p)
					elif card in ["ferns", "carrion", "compost"]:
						for q in g.around(p):
							if g.things.get(q) is Nest:
								good.append(p)
								break
			if fits.is_empty():
				return null
			return g.centre((good if not good.is_empty() else fits).pick_random())
	var front: Array = battle.robots.filter(func(r: Robot) -> bool: return r.kind != Robot.Kind.WALKER)
	var hunters := battle.dinos.filter(func(d: Dino) -> bool: return d.s.diet == "meat")
	var grazers := battle.dinos.filter(func(d: Dino) -> bool: return d.s.diet == "plant")
	match card:
		"scent":
			# Home, to meet walkers come for the nests; else, with a pack big enough, a step at their buildings.
			if hunters.is_empty():
				return null
			for r: Robot in battle.robots:
				var n := battle.nearest_nest(r.global_position)
				if r.kind == Robot.Kind.WALKER and not r.waiting and n and Geo.flat(n.global_position, r.global_position) < 25.0:
					return r.global_position
			if hunters.size() < 8:
				return null
			var mid := Vector3.ZERO
			for d: Dino in hunters:
				mid += d.global_position
			mid /= hunters.size()
			var goal := battle.nearest_robot(mid, 200.0)
			return null if goal == null else battle.clamp_to_field(mid + (goal.global_position - mid).limit_length(16.0), 1.0)
		"noise":
			# Behind a plant-eater, to send it at them.
			return null if grazers.is_empty() else (grazers.pick_random() as Dino).global_position + Vector3(-6, 0, randf_range(-3, 3))
		"blood":
			return null if hunters.is_empty() else (hunters.pick_random() as Dino).global_position
		"call":
			if grazers.is_empty() or front.is_empty():
				return null
			return (front.pick_random() as Robot).global_position + Vector3(-8, 0, 0)
		"ash":
			return null if front.is_empty() else (front.pick_random() as Robot).global_position
	return null


func _nests() -> void:
	for n: Nest in battle.nests:
		print("  nest %s %s left=%d progress=%.2f missing=%s stopped=%s" % [n.plot, n.card, n.left, n.progress, n.missing, n.stopped])


func _account() -> void:
	var how := ("won" if battle.won else "lost") if battle.over else "undecided"
	print("battle ends at %.0f s: %s, %d waves" % [battle.clock, how, battle.waves])
	print("  kept: ", battle.taken)
	print("  hatched: ", battle.hatched)
	var alive := {}
	for d: Dino in battle.dinos:
		alive[d.kind] = alive.get(d.kind, 0) + 1
	print("  alive: ", alive, "  nests: ", battle.nests.size(), "  robots: ", battle.robots.size())
	print("  fallen: ", battle.fallen)


func _shot(label: String) -> void:
	await process_frame
	_n += 1
	var path := "%s/%02d_t%03d_%s.png" % [out, _n, int(battle.clock), label]
	root.get_viewport().get_texture().get_image().save_png(path)
	var kinds := {}
	for d: Dino in battle.dinos:
		var key := "%s/%s%s" % [d.kind.left(4), Dino.Mode.keys()[d.mode], "*" if d.leader == null else ""]
		kinds[key] = kinds.get(key, 0) + 1
	var bots := {}
	for r: Robot in battle.robots:
		var key: String = Robot.Kind.keys()[r.kind].left(4) + ("/wait" if r.waiting else "")
		bots[key] = bots.get(key, 0) + 1
	print("t=%5.1f %s hand=%s dinos=%s robots=%s nests=%d" % [battle.clock, label, battle.hand, kinds, bots, battle.nests.size()])
