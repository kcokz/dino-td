extends SceneTree
## A run played by a script, with pictures -- for seeing a change at work without playing.
##
##   Godot --path dino-raid --script res://tools/playtest.gd -- <folder for frames> [bot [turns] [seed]]
##
## Without "bot": the first turns of the first level, slowly -- the hand, a card held over a tile with the
## turn it would bring, cards played, the turn played out -- a frame at each step, and what the board holds.
## "bot": plays whole levels the simple way (every card it can afford, on a tile picked at random among those
## it may go on), through the cards won between levels, until the run ends or the turns run out; prints an
## account. For finding what breaks, not for balance.

var battle: Battle
var out := ""
var _n := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var bot := args.size() > 1 and args[1] == "bot"
	RunState.current = RunState.new(int(args[3]) if args.size() > 3 else 5)
	_load()
	if bot:
		_bot(int(args[2]) if args.size() > 2 else 40)
	elif args.size() > 1 and args[1] == "win":
		_win()
	elif args.size() > 1 and args[1] == "cast":
		_cast()
	else:
		_run()


## Everyone on the board side by side, close: the dinosaurs as hatched and a leader, the robots.
func _cast() -> void:
	await _frames(30)
	var s: BattleState = battle.state
	s.units = s.units.filter(func(u: Dictionary) -> bool: return u.kind == "machine")
	Sim._add_dino(s, "coelophysis", Vector2i(0, 3), 4, true)
	Sim._add_dino(s, "triceratops", Vector2i(1, 3), 1, true)
	Sim._add_dino(s, "tyrannosaurus", Vector2i(2, 3), 1, true)
	Sim._add_robot(s, "walker", Vector2i(3, 3))
	Sim._add_robot(s, "turret", Vector2i(4, 3))
	battle._reconcile()
	battle.refresh()
	battle._hud.visible = false
	battle._marks.visible = false
	for view in [[Vector3(0, 0, 3.5), 26.0], [Vector3(-6.0, 0, 3.5), 14.0], [Vector3(6.0, 0, 3.5), 13.0]]:
		battle._cam_at = view[0]
		battle._cam_dist = view[1]
		battle._place_camera()
		await _frames(30)
		await _shot("cast")
	battle._cam_at = Vector3(0, 0, -16.0)
	battle._cam_dist = 22.0
	battle._place_camera()
	await _frames(10)
	await _shot("machine")
	quit()


## The screens after a level won: a tyrannosaur set beside a time machine with one hit point left.
func _win() -> void:
	await _frames(30)
	var s: BattleState = battle.state
	var m: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.kind == "machine")[0]
	m.hp = 1
	var rex := Sim._add_dino(s, "tyrannosaurus", Vector2i(2, 6), 1, true)
	battle._reconcile()
	await _frames(5)
	await _shot("before_win")
	battle.act(0, "end", {})
	await _wait(5.0)
	await _shot("won_pick")
	var hud: Hud = battle._hud
	var offer := RunState.current.offer()
	RunState.current.deck.append({"id": offer[0], "up": false})
	hud._upgrade()
	await _frames(10)
	await _shot("won_upgrade")
	RunState.current.deck[0].up = true
	hud._remove()
	await _frames(10)
	await _shot("won_remove")
	print("deck now: ", RunState.current.deck.map(func(ci: Dictionary) -> String: return ci.id + ("+" if ci.up else "")))
	quit()


func _load() -> void:
	battle = load("res://scenes/Battle.tscn").instantiate()
	root.add_child(battle)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(30)
	await _shot("start")
	var s: BattleState = battle.state
	# What the hint panel says of the nest, and a card looked at closely.
	battle.hover = Rules.FIRST_NEST
	await _frames(3)
	await _shot("info_nest")
	battle.hover = Board.NOWHERE
	battle._hud._hovered = battle._hud._cards[1]
	await _frames(12)
	await _shot("card_close")
	battle._hud._hovered = null
	# Hold the first card over the first tile it may go on: the turn it would bring.
	for i in s.hand.size():
		var where := Sim.targets(s, i)
		if not where.is_empty():
			battle.hold(i)
			battle.hover = where[where.size() / 2]
			battle.refresh()
			await _frames(4)
			await _shot("aim_%s" % s.hand[i].id)
			battle.hold(i)
			break
	for turn in 4:
		_play_all(false)
		battle.hover = Board.NOWHERE
		battle.refresh()
		await _frames(4)
		await _shot("plan_t%d" % s.turn)
		if turn == 3:
			battle._cam_dist = 24.0
			battle._cam_at = Vector3(0, 0, 0)
			battle._place_camera()
			await _frames(4)
			await _shot("close_t%d" % s.turn)
			battle._cam_dist = 47.0
			battle._cam_at = Vector3(0, 0, 6)
			battle._place_camera()
		battle.act(0, "end", {})
		await _wait(1.6)
		await _shot("playing_t%d" % s.turn)
		while not battle.planning and not s.over:
			await process_frame
		await _frames(10)
		if s.over:
			break
	_account()
	await _shot("end")
	quit()


func _bot(turns: int) -> void:
	var played := 0
	while played < turns:
		await _frames(5)
		var s: BattleState = battle.state
		while not battle.planning and not s.over:
			await process_frame
		if s.over:
			await _wait(1.5)
			_account()
			await _shot("over_l%d" % s.level)
			if not s.won or RunState.current.last_level():
				break
			var run := RunState.current
			var offer := run.offer()
			run.deck.append({"id": offer[0], "up": false})
			for ci in run.deck:
				if not ci.up:
					ci.up = true
					break
			run.level += 1
			battle.queue_free()
			await _frames(3)
			_load()
			continue
		_play_all(true)
		if s.turn % 5 == 0:
			await _shot("bot_l%d_t%d" % [s.level, s.turn])
		battle.act(0, "end", {})
		played += 1
	_account()
	quit()


## Every card it can afford, each on a tile it may go on.
func _play_all(random: bool) -> void:
	var s: BattleState = battle.state
	var tries := 0
	var i := 0
	while i < s.hand.size() and tries < 20:
		tries += 1
		var where := Sim.targets(s, i)
		if where.is_empty():
			i += 1
			continue
		var at: Vector2i = where[randi() % where.size()] if random else _good_spot(s, i, where)
		if not battle.act(0, "play", {"slot": i, "at": at}):
			i += 1


## A sensible tile for the scripted run: eggs and buildings nearest the middle of our end, help where the
## dinosaurs are.
func _good_spot(s: BattleState, i: int, where: Array) -> Vector2i:
	var c := Rules.card(s.hand[i])
	var best: Vector2i = where[0]
	for p in where:
		match c.type:
			"egg", "building":
				if absi(p.x - 2) + p.y < absi(best.x - 2) + best.y:
					best = p
			_:
				if c.id == "scent" and p == Vector2i(2, 4):
					best = p
				elif c.id == "noise" and p == Vector2i(2, 0):
					best = p
	return best


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _account() -> void:
	var s: BattleState = battle.state
	var line := "level %d turn %d energy %d hand %d draw %d discard %d | over %s won %s | " % [s.level, s.turn, s.energy,
		s.hand.size(), s.draw.size(), s.discard.size(), s.over, s.won]
	for u in s.units:
		line += "%s(%d)@%s " % [u.kind.left(4), u.hp, u.pos]
	line += "| nests %d buildings %d" % [s.nests.size(), s.buildings.size()]
	print(line)


func _shot(label: String) -> void:
	await process_frame
	_n += 1
	var path := "%s/%02d_%s.png" % [out, _n, label]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())
