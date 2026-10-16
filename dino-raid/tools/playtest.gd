extends SceneTree
## A run played by a script, with pictures -- for seeing a change at work without playing (GAME-DESIGN 14).
##
##   Godot --path dino-raid --script res://tools/playtest.gd -- <folder for frames> [bot [rounds] [seed] [smart]]
##
## Without "bot": the first rounds slowly -- the round's army hatching, the hand, each card held over where it goes
## with what it would change and the forecast it brings, a potion pointed at, cards played, a battle fought, the card
## won -- then a homeland built up by hand (every kind of building, levels, affixes, a flier), its battle, and the
## screens after a level with the new row of land; a frame at each step.
## "bot": plays rounds the simple way (tools/Policy.gd, random -- or smart), fast, until the run ends or the rounds
## run out; checks every forecast against the battle fought; prints an account. For finding what breaks.

var game: Game
var out := ""
var smart := false
var _n := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var bot := args.size() > 1 and args[1] == "bot"
	smart = args.size() > 4 and args[4] == "smart"
	var seed := int(args[3]) if args.size() > 3 else 5
	rng.seed = seed
	Run.current = Run.new(seed)
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	if bot:
		_bot(int(args[2]) if args.size() > 2 else 30)
	else:
		_scripted()


func _scripted() -> void:
	while game.hud == null or game.hud.screen == "":
		await process_frame
	await _frames(10)
	await _shot("deck_start")
	game.hud.chosen.emit("开始")
	await _until_plan()
	await _shot("plan_r1")
	_check_pointing()
	game.hover = {"plot": Content.FIRST[0].pos, "unit": ""}
	game.refresh()
	await _frames(4)
	await _shot("info_nest")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	game.hud._hovered = game.hud._cards[1]
	await _frames(14)
	await _shot("card_close")
	game.hud._hovered = null
	await _aim_each("r1")
	game.aim_potion(0)
	await _frames(6)
	game.hud._potion_hover = 0
	await _frames(4)
	await _shot("aim_potion")
	game.hud._potion_hover = -1
	game.aim_potion(-1)
	for r in 3:
		_play_all()
		await _frames(40)
		await _shot("played_r%d" % game.run.round)
		if r == 1:
			for which in ["discard", "draw"]:
				game.hud.view_pile(which)
				await _frames(10)
				await _shot("view_%s" % which)
				game.hud.chosen.emit("关闭")
				await _frames(4)
		await _fight_shots("r%d" % game.run.round)
		await _until_plan_or_screen()
		if game.hud.screen != "":
			await _shot("reward_r%d" % game.run.round)
			game.hud.chosen.emit({"id": "b_pool", "up": false})
			await _until_plan()
	await _rich()
	_account()
	quit()


## Each card in hand held over a place it may go (an empty plot first): what it lights, what it changes, the forecast.
func _aim_each(label: String) -> void:
	var home := game.home
	for i in home.hand.size():
		var fits := home.targets(i)
		if fits.is_empty():
			continue
		var empty := fits.filter(func(t: Variant) -> bool: return not t is Vector2i or not home.buildings.has(t))
		var near := fits.filter(func(t: Variant) -> bool: return t is Vector2i and home.around(t).any(
			func(q: Vector2i) -> bool: return home.buildings.has(q)))
		var at: Variant = (empty.filter(func(t: Variant) -> bool: return t in near) + empty + fits)[0]
		game.hold(i)
		game.hover = {"plot": at if at is Vector2i else HomeView.NOWHERE, "unit": ""}
		game.refresh()
		await _frames(8)
		await _shot("aim_%s_%s" % [label, home.hand[i].id])
		game.held = -1
		game.refresh()


func _rich() -> void:
	var h := game.home
	h.open_row()
	game.home_view.open_rows()
	var plan := [[Vector2i(1, 2), "nest_red", 3, ["shell"]], [Vector2i(2, 2), "nest_red", 2, []], [Vector2i(3, 2), "nest_red", 1, []],
		[Vector2i(2, 1), "gym", 2, []], [Vector2i(1, 1), "pool", 3, []], [Vector2i(0, 2), "stabilizer", 1, []],
		[Vector2i(4, 1), "nest_blue", 2, ["acid"]], [Vector2i(5, 1), "sampler", 2, []], [Vector2i(4, 2), "nest_gold", 1, ["plasma"]],
		[Vector2i(5, 2), "power", 1, []], [Vector2i(0, 3), "nest_white", 2, []], [Vector2i(0, 4), "lab", 1, []],
		[Vector2i(4, 3), "store", 1, []], [Vector2i(5, 4), "wall", 2, []], [Vector2i(4, 4), "wall", 1, []],
		[Vector2i(5, 3), "nest_green", 3, ["wings", "blade"]], [Vector2i(1, 4), "pool", 2, []]]
	for step in plan:
		h.build(step[0], step[1])
		h.buildings[step[0]].level = step[2]
		h.buildings[step[0]].affixes = step[3].duplicate()
	h.energy = 10
	h.biomass = 40
	h.genes = 8
	h.alien = 2
	game.home_view.refresh_buildings(false)
	game._version += 1
	game.home_view.sync_army(h.army())
	game.refresh()
	await _frames(60)
	await _shot("rich_home")
	for look in [[Vector2i(1, 2), "rich_info_red"], [Vector2i(5, 3), "rich_info_green"]]:
		game.hover = {"plot": look[0], "unit": ""}
		game.refresh()
		await _frames(4)
		await _shot(look[1])
	var any_unit: String = h.army()[0].id
	game.hover = {"plot": HomeView.NOWHERE, "unit": any_unit}
	game.refresh()
	await _frames(4)
	await _shot("rich_info_unit")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	h.hand = [{"id": "b_red", "up": false}, {"id": "raise", "up": false}, {"id": "b_pool", "up": false},
		{"id": "a_shell", "up": false}, {"id": "b_gym", "up": false}]
	game.hud.deal(h.hand)
	game.refresh()
	await _frames(20)
	for aim in [[0, Vector2i(3, 3), "rich_aim_cluster"], [2, Vector2i(3, 1), "rich_aim_pool"], [0, Vector2i(5, 1), "rich_aim_swap"],
			[1, Vector2i(2, 2), "rich_aim_raise"]]:
		game.hold(aim[0])
		game.hover = {"plot": aim[1], "unit": ""}
		game.refresh()
		await _frames(8)
		await _shot(aim[2])
		game.held = -1
	game.refresh()
	game.run.round = game.run.rounds()
	game.refresh()
	await _fight_shots("rich")
	for k in 3:
		await _until_plan_or_screen()
		if game.hud.screen == "":
			break
		await _frames(10)
		await _shot("level_%d" % k)
		var deck := game.run.deck()
		if game.hud.screen.begins_with("升级"):
			game.hud.chosen.emit(deck[0])
		elif game.hud.screen.begins_with("去掉"):
			game.hud.chosen.emit("不去掉")
		else:
			game.hud.chosen.emit({"id": "a_wings", "up": false})
	await _until_plan()
	await _frames(40)
	await _shot("level_2_start")


## The battle: when it starts, in the thick of it, at its end, and back home.
func _fight_shots(label: String) -> void:
	game.act("fight")
	while not game._fighting:
		await process_frame
	await _shot("fight_%s_start" % label)
	await _wait(1.6)
	await _shot("fight_%s_mid" % label)
	while game._fighting:
		await process_frame
	await _wait(0.5)
	await _shot("fight_%s_end" % label)
	while not game.at_home:
		await process_frame
	await _wait(0.8)
	await _shot("fight_%s_home" % label)


## The cursor test: each open plot's middle, and each unit, found again from where it is on screen.
func _check_pointing() -> void:
	var bad := 0
	for y in Home.ROWS:
		for x in Home.COLS:
			var p := Vector2i(x, y)
			var sp := game.camera.unproject_position(HomeView.plot_pos(p) + Vector3(0, 0.15, 1.2))
			var got: Dictionary = game.home_view.pick(game.camera, sp, "tile")
			if got.plot != p:
				bad += 1
				print("pointing: plot %s found as %s" % [p, got.plot])
	for u in game.home.army():
		var n := game.home_view.unit_node(u.id)
		if n == null:
			bad += 1
			print("pointing: no block for unit %s" % u.id)
			continue
		var sp := game.camera.unproject_position(n.position + Vector3.UP * 0.4)
		var got: Dictionary = game.home_view.pick(game.camera, sp, "unit")
		if got.unit != u.id:
			bad += 1
			print("pointing: unit %s found as %s" % [u.id, got.unit])
	print("pointing: %s" % ("all found" if bad == 0 else "%d missed" % bad))


func _bot(rounds: int) -> void:
	while game.hud == null:
		await process_frame
	Engine.time_scale = 6.0
	game.speed = 4.0
	var played := 0
	while played < rounds:
		await _until_plan_or_screen()
		if game.phase == Game.Phase.DONE:
			await _wait(1.0)
			_account()
			await _shot("bot_over")
			break
		if game.hud.screen != "":
			var deck := game.run.deck()
			if game.hud.screen.begins_with("升级"):
				game.hud.chosen.emit(deck.filter(func(ci: Dictionary) -> bool: return not ci.up).front())
			elif game.hud.screen.begins_with("去掉"):
				game.hud.chosen.emit("不去掉")
			else:
				game.hud.chosen.emit({"id": game.run.offer()[0], "up": false})
			await _frames(3)
			continue
		if smart:
			for guard in 12:
				var play := Policy.best_play(game.run, game.home)
				if play.is_empty():
					break
				game.act("play", {"slot": play[0], "at": play[1]})
			var k := Policy.best_potion(game.run, game.home)
			if k >= 0:
				game.act("potion", {"slot": k})
		else:
			_play_all()
		await _frames(4)
		if game.run.round % 5 == 0:
			await _frames(30)
			await _shot("bot_l%d_r%d" % [game.run.level, game.run.round])
		var before := game.home.hp
		var f := game.forecast.duplicate()
		game.act("fight")
		while game.phase == Game.Phase.FIGHT and game.hud.screen == "":
			await process_frame
		var took := before - game.home.hp
		var expect := 0 if f.result == "won" else int(f.harm)
		if took != expect and game.home.hp > 0:
			print("FORECAST MISSED: said %s, harm %d; took %d" % [f.result, f.harm, took])
		played += 1
		_account()
	_account()
	quit()


## Plays the careless way (tools/Policy.gd any_play), and now and then a potion.
func _play_all() -> void:
	for guard in 20:
		var play := Policy.any_play(game.home, rng)
		if play.is_empty():
			break
		game.act("play", {"slot": play[0], "at": play[1]})
	if not game.home.potions.is_empty() and rng.randf() < 0.3:
		game.act("potion", {"slot": 0})


func _until_plan() -> void:
	while game.phase != Game.Phase.PLAN:
		await process_frame
	await _frames(20)


func _until_plan_or_screen() -> void:
	while game.phase != Game.Phase.PLAN and game.hud.screen == "" and game.phase != Game.Phase.DONE:
		await process_frame
	await _frames(20)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _account() -> void:
	var r := game.run
	var h := game.home
	var built := {}
	for p in h.buildings:
		var b: Dictionary = h.buildings[p]
		var key := "%s%d" % [b.kind, b.level]
		built[key] = built.get(key, 0) + 1
	print("level %d round %d hp %d/%d energy %d biomass %d genes %d alien %d potions %d army %d | %s" % [r.level + 1,
		r.round, h.hp, h.hp_max(), h.energy, h.biomass, h.genes, h.alien, h.potions.size(), h.army().size(), built])


func _shot(label: String) -> void:
	await process_frame
	_n += 1
	var path := "%s/%02d_%s.png" % [out, _n, label]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())