extends SceneTree
## A run played by a script, with pictures -- for seeing a change at work without playing (GAME-DESIGN 12).
##
##   Godot --path dino-raid --script res://tools/playtest.gd -- <folder for frames> [bot [rounds] [seed] [smart]]
##
## Without "bot": the first rounds slowly -- the nests making, the hand, a card held over where it goes with the
## forecast it brings, cards played, a battle fought, the card won -- then a homeland built up by hand, its
## battle, and the screens after a level; a frame at each step.
## "bot": plays rounds the simple way (every card it can afford, on a target picked at random), takes the first
## card offered and upgrades the first it can, fast, until the run ends or the rounds run out; prints an
## account. For finding what breaks, not for balance. "smart": each card where the forecast says it does the most
## good, then what builds the homeland up -- to see whether a level can be held at all.

var game: Game
var out := ""
var smart := false
var _n := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var bot := args.size() > 1 and args[1] == "bot"
	smart = args.size() > 4 and args[4] == "smart"
	Run.current = Run.new(int(args[3]) if args.size() > 3 else 5)
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	if bot:
		_bot(int(args[2]) if args.size() > 2 else 30)
	else:
		_scripted()


func _scripted() -> void:
	await _until_plan()
	await _shot("plan_r1")
	_check_pointing()
	# The panel on the red nest, a card looked at closely.
	game.hover = {"plot": Content.FIRST.pos, "unit": -1}
	game.refresh()
	await _frames(4)
	await _shot("info_nest")
	game.hover = {"plot": HomeView.NOWHERE, "unit": -1}
	game.hud._hovered = game.hud._cards[1]
	await _frames(14)
	await _shot("card_close")
	game.hud._hovered = null
	# Each card held over the first place it may go: what it lights, and the forecast with it.
	var home := game.home
	for i in home.hand.size():
		var fits := home.targets(i)
		if fits.is_empty():
			continue
		game.hold(i)
		var at: Variant = fits[fits.size() / 2]
		game.hover = {"plot": at if at is Vector2i else HomeView.NOWHERE, "unit": at if at is int else -1}
		game.refresh()
		await _frames(8)
		await _shot("aim_%s" % home.hand[i].id)
		game.held = -1
		game.refresh()
	for r in 3:
		_play_all(false)
		await _frames(30)
		await _shot("played_r%d" % game.run.round)
		await _fight_shots("r%d" % game.run.round)
		await _until_plan_or_screen()
		if game.hud.screen != "":
			await _shot("reward_r%d" % game.run.round)
			game.hud.chosen.emit({"id": "b_green", "up": false})
			await _until_plan()
	# A homeland built up by hand: every kind of building, a yard of units, some of them starred.
	await _rich()
	_account()
	quit()


func _rich() -> void:
	var h := game.home
	var kinds := ["hatch_blue", "hatch_green", "hatch_gold", "hatch_white", "pen", "pen", "farm", "nursery", "gym", "wall"]
	var free: Array = h._plots_all().filter(func(p: Vector2i) -> bool: return not h.buildings.has(p))
	for k in kinds.size():
		h.build(free[k], kinds[k])
		if k % 3 == 0:
			h.buildings[free[k]].level = 2 + k % 2
	var mix := ["red", "red", "blue", "blue", "green", "gold", "white", "red", "green", "blue", "gold"]
	h.units.clear()
	for k in mix.size():
		var star := 1
		if k % 4 == 0:
			star += 1
		if k == 8:
			star += 1
		h.units.append({"id": 900 + k, "kind": mix[k], "star": star, "bonus_hp": 0, "bonus_atk": 0})
	h.energy = 10
	game.home_view.refresh_buildings(false)
	game.home_view.settle()
	game._version += 1
	game.refresh()
	await _frames(40)
	await _shot("rich_home")
	game.hover = {"plot": free[0], "unit": -1}
	game.refresh()
	await _frames(4)
	await _shot("rich_info_blue")
	game.hover = {"plot": HomeView.NOWHERE, "unit": 908}
	game.refresh()
	await _frames(4)
	await _shot("rich_info_unit")
	game.hover = {"plot": HomeView.NOWHERE, "unit": -1}
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
			game.hud.chosen.emit({"id": "b_gold", "up": false})
	await _until_plan()
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


## The cursor test: each plot's middle, and each unit, found again from where it is on screen.
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
	for u in game.home.units:
		var n := game.home_view.unit_node(u.id)
		var sp := game.camera.unproject_position(n.position + Vector3.UP * 0.4)
		var got: Dictionary = game.home_view.pick(game.camera, sp, "unit")
		if got.unit != u.id:
			bad += 1
			print("pointing: unit %d found as %d" % [u.id, got.unit])
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
				game.hud.chosen.emit(deck[0])
			else:
				game.hud.chosen.emit({"id": game.run.offer()[0], "up": false})
			await _frames(3)
			continue
		if smart:
			_play_smart()
		else:
			_play_all(true)
		if game.run.round % 5 == 0:
			await _frames(10)
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


## The best play it can see (tools/Policy.gd), again and again, while one does more good than keeping the energy.
func _play_smart() -> void:
	for guard in 12:
		var play := Policy.best_play(game.run, game.home)
		if play.is_empty():
			return
		game.act("play", {"slot": play[0], "at": play[1]})


## Every card it can afford, each on a target it may go on.
func _play_all(random: bool) -> void:
	var h := game.home
	var tries := 0
	var i := 0
	while i < h.hand.size() and tries < 20:
		tries += 1
		var fits := h.targets(i)
		if fits.is_empty():
			i += 1
			continue
		var at: Variant = fits[randi() % fits.size()] if random else fits[0]
		if not game.act("play", {"slot": i, "at": at}):
			i += 1


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
	var units := {}
	for u in h.units:
		var key := "%s%d" % [u.kind, u.star]
		units[key] = units.get(key, 0) + 1
	var built := {}
	for p in h.buildings:
		var b: Dictionary = h.buildings[p]
		built[b.kind] = built.get(b.kind, 0) + 1
	print("level %d round %d hp %d/%d energy %d deck %d | units %s | buildings %s" % [r.level + 1, r.round, h.hp, h.hp_max(),
		h.energy, r.deck().size(), units, built])


func _shot(label: String) -> void:
	await process_frame
	_n += 1
	var path := "%s/%02d_%s.png" % [out, _n, label]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())