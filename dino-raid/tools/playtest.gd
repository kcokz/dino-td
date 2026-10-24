extends SceneTree
## A run played by a script, with pictures -- for seeing a change at work without playing (GAME-DESIGN 17, 18).
##
##   Godot --path dino-raid --script res://tools/playtest.gd -- <folder for frames> [bot [rounds] [seed] [smart]]
##
## Without "bot": the title and its settings, then the rainforest arrived in, its first nest picked, the pause menu;
## the first rounds slowly --
## special ground and a nest pointed at, the build bar and a blueprint on it pointed at, each blueprint taken up over
## where it goes with what it would change and the forecast it brings, a nest evolved, buys, battles fought, the
## blueprint picked after each -- then a homeland built up by hand (every kind of building, levels, the four evolved
## species, stars in their pens), a pen pointed at and its star's own screen, a nest clicked and raised elite, its boss
## battle (the mother breaking into spores), the map and the next place picked on it, the place arrived in -- the
## homeland made afresh -- and a battle there; a frame at each step.
## "bot": plays rounds the simple way (tools/Policy.gd, random -- or smart), fast, until the run ends or the rounds
## run out; checks every forecast against the battle fought; prints an account. For finding what breaks.

var game: Game
var out := ""
var smart := false
var seed := 5
var _n := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var bot := args.size() > 1 and args[1] == "bot"
	smart = args.size() > 4 and args[4] == "smart"
	seed = int(args[3]) if args.size() > 3 else 5
	rng.seed = seed
	Run.current = Run.new(seed)
	Game.show_title = not bot
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	if bot:
		_bot(int(args[2]) if args.size() > 2 else 30)
	else:
		_scripted()


func _scripted() -> void:
	while game.menu == null or game.menu.screen != "title":
		await process_frame
	await _wait(3.6)
	await _shot("title")
	game.menu._picked.emit("settings")
	await _wait(0.5)
	await _shot("title_settings")
	game.menu._settings_closed.emit()
	await _frames(10)
	game.menu._picked.emit("new")
	await _until_screen("到了")
	await _frames(30)
	await _shot("arrive_rainforest")
	game.hud.chosen.emit("开始")
	await _screens("first")
	await _until_plan()
	await _shot("plan_r1")
	game.pause()
	await _wait(0.5)
	await _shot("pause")
	game.menu._picked.emit("resume")
	await _frames(10)
	_check_pointing()
	var home := game.home
	for t in ["pond", "tree"]:
		for p in home.terrain:
			if home.terrain[p] == t and not home.buildings.has(p):
				game.hover = {"plot": p, "unit": ""}
				game.refresh()
				await _frames(4)
				await _shot("info_" + t)
				break
	for p in home.buildings:
		if Content.is_nest(home.buildings[p].kind):
			game.hover = {"plot": p, "unit": ""}
			game.refresh()
			await _frames(4)
			await _shot("info_nest")
			break
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	game.hud._bar_hot = "p0"
	await _frames(10)
	await _shot("plan_tip")
	game.hud._bar_hot = ""
	await _aim_each("r1")
	await _evolve()
	for r in 3:
		if r == 1:
			await _tech_shots()
		_play_all()
		await _frames(40)
		await _shot("bought_r%d" % game.run.round)
		await _fight_shots("r%d" % game.run.round)
		await _screens("r%d" % game.run.round)
		await _until_plan()
	await _rich()
	_account()
	quit()


## Each blueprint on the bar taken up over a place it may go (an empty plot beside a building first): what it lights,
## what it changes, the forecast.
func _aim_each(label: String) -> void:
	var home := game.home
	home.gold += 10
	game._version += 1
	game.refresh()
	for i in home.plans.size():
		var fits := game.fits_of(i)
		if fits.is_empty():
			continue
		var empty := fits.filter(func(t: Vector2i) -> bool: return not home.buildings.has(t))
		var near := fits.filter(func(t: Vector2i) -> bool: return home.around(t).any(
			func(q: Vector2i) -> bool: return home.buildings.has(q)))
		var at: Vector2i = (empty.filter(func(t: Vector2i) -> bool: return t in near) + empty + fits)[0]
		game.hold(i)
		game.hover = {"plot": at, "unit": ""}
		game.refresh()
		await _frames(8)
		await _shot("aim_%s_%s" % [label, home.plans[i]])
		game.held = -1
		game.refresh()
	home.gold -= 10
	game._version += 1
	game.refresh()


## A nest evolved: a stabilizer behind it for a second affix, acid and poison had and stuck on it -- what the second
## shows before it goes on, and the new species. (A red nest put down for it first, where there is none bare yet.)
func _evolve() -> void:
	var home := game.home
	var nest := HomeView.NOWHERE
	var spot := HomeView.NOWHERE
	for p in home.buildings:
		if Content.is_nest(home.buildings[p].kind) and home.buildings[p].affixes.is_empty() and _behind(p) != HomeView.NOWHERE:
			nest = p
			break
	if nest == HomeView.NOWHERE:
		for x in Home.COLS:
			var p := Vector2i(x, 0)
			if not home.buildings.has(p) and _behind(p) != HomeView.NOWHERE:
				home.build(p, "nest_red")
				nest = p
				break
	if nest != HomeView.NOWHERE:
		spot = _behind(nest)
	if spot == HomeView.NOWHERE:
		print("evolve: no nest with room behind it")
		return
	home.build(spot, "stabilizer")
	home.unlock("a_acid")
	home.unlock("a_poison")
	home.gold += 10
	home.genes += 10
	game.home_view.refresh_buildings()
	game._version += 1
	game.refresh()
	game.act("build", {"plan": home.plans.find("a_acid"), "at": nest})
	await _frames(20)
	game.hold(home.plans.find("a_poison"))
	game.hover = {"plot": nest, "unit": ""}
	game.refresh()
	await _frames(10)
	await _shot("evolve_aim")
	if not game.act("build", {"plan": home.plans.find("a_poison"), "at": nest}):
		print("evolve: could not stick the poison on")
	game._let_go()
	game.hover = {"plot": nest, "unit": ""}
	game.refresh()
	await _frames(12)
	await _shot("evolved")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	game.refresh()


## The tech tree (GAME-DESIGN 29): opened, a tech pointed at, one researched, closed.
func _tech_shots() -> void:
	game.home.genes += 6
	game.hud.open_tech()
	await _frames(20)
	await _shot("tech_tree")
	var open: Array = Content.OFFERS.keys().filter(func(id: String) -> bool: return game.home.can_research(id))
	if not open.is_empty():
		game.act("research", {"id": open[0]})
		await _frames(8)
		await _shot("tech_researched")
	game.hud.chosen.emit("close")
	await _frames(10)


## A free plot behind the battle line in p's column, or NOWHERE.
func _behind(p: Vector2i) -> Vector2i:
	for y in range(Content.FRONT_ROWS, Home.ROWS):
		var q := Vector2i(p.x, y)
		if game.home.buildable(q) and not game.home.buildings.has(q):
			return q
	return HomeView.NOWHERE


## A homeland built up by hand -- the battle line full of nests (the four new species, elites), behind it every school's
## buildings, stars in their pens -- a pen pointed at, a star's own screen, a nest clicked and raised elite, its boss
## battle, the map, the next place.
func _rich() -> void:
	var h := game.home
	h.terrain = {Vector2i(0, 2): "pond", Vector2i(5, 3): "tree", Vector2i(3, 3): "pond"}
	h.buildings.clear()
	# [plot, kind, nest's choices (or a level), affixes] -- the battle line laid out for the nests' gifts: two greens
	# guarding (a white caring behind one, scavengers behind the other), four reds swarming, a gold alone at the edge, a
	# blue with no cover yet (nothing in front of it), a mutant with two affixes.
	var plan := [[Vector2i(0, 0), "nest_green", ["elite"], ["shell"]],
		[Vector2i(1, 0), "nest_red", ["elite"], ["blade", "wings"]], [Vector2i(2, 0), "nest_red", ["elite", "elite"], ["flame", "blade"]],
		[Vector2i(3, 0), "nest_green", [], []], [Vector2i(5, 0), "nest_gold", ["elite"], []],
		[Vector2i(0, 1), "nest_white", [], []], [Vector2i(1, 1), "nest_red", [], ["hide"]],
		[Vector2i(2, 1), "nest_red", [], ["haste"]], [Vector2i(3, 1), "nest_scav", ["elite"], []],
		[Vector2i(4, 1), "nest_blue", ["elite"], []], [Vector2i(5, 1), "nest_mutant", [], ["acid", "poison"]],
		[Vector2i(0, 2), "pool", 3, []], [Vector2i(1, 2), "stabilizer", 1, []], [Vector2i(2, 2), "stabilizer", 1, []],
		[Vector2i(3, 2), "horde_totem", 1, []], [Vector2i(4, 2), "champion_hall", 1, []], [Vector2i(5, 2), "watchtower", 1, []],
		[Vector2i(0, 3), "stabilizer", 1, []], [Vector2i(1, 3), "sampler", 2, []], [Vector2i(2, 3), "vanguard", 1, []],
		[Vector2i(3, 3), "spore_pool", 2, []], [Vector2i(4, 3), "vault", 1, []]]
	for step in plan:
		h.build(step[0], step[1])
		var b: Dictionary = h.buildings[step[0]]
		if step[2] is Array:
			b.path = step[2].duplicate()
			b.level = 1 + b.path.size()
		else:
			b.level = step[2]
		b.affixes = step[3].duplicate()
	if Content.STARS_ON:
		h.stars = [{"id": "doctor", "grow": 0}, {"id": "scar", "grow": 0}, {"id": "tri", "grow": 0}, {"id": "oldking", "grow": 2},
			{"id": "belly", "grow": 0}]
		h.hungry = [2]
		h.star_offer = "neck"
	h.gold = 30
	h.biomass = 40
	h.genes = 8
	h.hp = h.hp_max()
	h.plans = Content.OFFERS.keys().filter(func(id: String) -> bool:
		return int(Content.OFFERS[id].get("region", h.region)) == h.region)
	game.home_view.lay_ground()
	game.home_view.refresh_buildings(false)
	game._version += 1
	game.home_view.sync_army(h.army())
	game.refresh()
	await _frames(60)
	await _shot("rich_home")
	if Content.STARS_ON:
		game.hover = {"plot": HomeView.NOWHERE, "unit": "", "pen": 3}
		game.refresh()
		await _frames(4)
		await _shot("rich_pen")
		game.hover = {"plot": HomeView.NOWHERE, "unit": "", "pen": -1}
		game._pen_screen(1)
		await _frames(30)
		await _shot("pen_screen")
		game.hud.chosen.emit("")
		await _frames(10)
	game.hover = {"plot": Vector2i(3, 0), "unit": ""}
	game._click()
	await _frames(10)
	await _shot("raise_choice")
	game.aim("raise")
	await _frames(6)
	await _shot("raise_choice_elite")
	game.act("choose")
	game.hover = {"plot": Vector2i(3, 0), "unit": ""}
	game.refresh()
	await _frames(20)
	await _shot("raised_elite")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	# A green taken up over the gap in front of the blue: the blue would be under cover, the gold no longer alone.
	game.hold(h.plans.find("b_green"))
	game.hover = {"plot": Vector2i(4, 0), "unit": ""}
	game.refresh()
	await _frames(10)
	await _shot("aim_gift_tradeoff")
	game._let_go()
	for look in [[Vector2i(5, 1), "rich_info_miasma"], [Vector2i(1, 0), "rich_info_falcon"], [Vector2i(3, 2), "rich_info_totem"],
			[Vector2i(0, 0), "rich_info_guard"], [Vector2i(4, 1), "rich_info_cover_off"], [Vector2i(5, 0), "rich_info_alone"],
			[Vector2i(3, 1), "rich_info_scav"]]:
		game.hover = {"plot": look[0], "unit": ""}
		game.refresh()
		await _frames(4)
		await _shot(look[1])
	for u in h.army():
		if u.kind == "scav":
			game.hover = {"plot": HomeView.NOWHERE, "unit": u.id}
			game.refresh()
			await _frames(4)
			await _shot("rich_info_scav_unit")
			break
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	game.refresh()
	game.run.round = game.run.rounds()
	game._version += 1
	game.refresh()
	# Made strong enough for the boss, so that the run goes on to the next place: every nest elite twice over.
	if game.forecast.get("result", "") != "won":
		for p in h.buildings:
			if Content.is_nest(h.buildings[p].kind):
				h.buildings[p].path = ["elite", "elite"]
				h.buildings[p].level = Content.LEVEL_MAX
		game.home_view.refresh_buildings(false)
		game._version += 1
		game.home_view.sync_army(h.army())
		game.refresh()
		print("boss: made elite, the forecast now %s" % game.forecast.get("result", ""))
	await _frames(10)
	await _shot("boss_plan")
	await _fight_shots("boss")
	# The map -- till the next place is come to.
	for k in 3:
		await _screens("boss")
		if game.hud.screen.begins_with("到了"):
			break
	await _until_screen("到了")
	await _frames(20)
	await _shot("arrive_next")
	game.hud.chosen.emit("开始")
	await _screens("next_first")
	await _until_plan()
	await _shot("next_r1")
	game.hud._bar_hot = "p0"
	await _frames(10)
	await _shot("next_plan_tip")
	game.hud._bar_hot = ""
	_play_all()
	await _frames(30)
	await _fight_shots("next")
	await _screens("next")
	await _until_plan()
	await _shot("next_r2")


## The button up on the screen whose words begin with `words`, or null.
func _button_saying(words: String) -> Button:
	for b in game.hud.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(words) and (b as Button).is_visible_in_tree():
			return b
	return null


## The screen after a battle (the map) or at a place's start (its first nest), shot and answered -- the map with a place
## picked on it first. A place come to is left to the caller.
func _screens(label: String) -> void:
	while game.hud.screen == "" and not game.phase in [Game.Phase.PLAN, Game.Phase.DONE]:
		await process_frame
	if game.hud.screen == "" or game.hud.screen.begins_with("到了"):
		return
	await _frames(10)
	var s: String = game.hud.screen
	if s.begins_with("下一站"):
		await _shot("map_" + label)
		for b in game.hud.find_children("*", "Button", true, false):
			if (b as Button).flat and (b as Button).custom_minimum_size == Vector2(84, 84):
				(b as Button).mouse_entered.emit()
				(b as Button).pressed.emit()
				break
		await _frames(6)
		await _shot("map_picked_" + label)
	else:
		await _shot(("plan_pick_" if s.begins_with("选第一个巢") else "screen_") + label)
	_answer()
	await _frames(4)


## Answers the screen up: the arrival, the first nest (smart: the best), the next place.
func _answer() -> void:
	var s: String = game.hud.screen
	var offered: Array = game.hud.offered
	if s.begins_with("到了"):
		game.hud.chosen.emit("开始")
	elif s.begins_with("选第一个巢"):
		game.hud.chosen.emit(offered[Policy.best_first(game.run, game.home, offered) if smart else 0])
	elif s.begins_with("下一站"):
		game.hud.chosen.emit(Policy.best_place(game.run))


## The battle: when it starts, in the thick of it, at its end, and back home.
func _fight_shots(label: String) -> void:
	game.act("fight")
	while not game._fighting:
		await process_frame
	await _shot("fight_%s_start" % label)
	await _wait(1.3)
	await _shot("fight_%s_mid" % label)
	await _wait(1.6)
	await _shot("fight_%s_later" % label)
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
	for u in game.home.brood:
		var n := game.home_view.unit_node(u.id)
		if n == null:
			bad += 1
			continue
		var sp := game.camera.unproject_position(n.position + Vector3.UP * 0.4)
		var got: Dictionary = game.home_view.pick(game.camera, sp, "unit")
		if got.unit != u.id:
			bad += 1
	print("pointing: %s" % ("all found" if bad == 0 else "%d missed" % bad))


func _bot(rounds: int) -> void:
	while game.hud == null:
		await process_frame
	Engine.time_scale = 6.0
	game.speed = 4.0
	var played := 0
	while played < rounds:
		await _until_turn()
		if game.phase == Game.Phase.DONE:
			await _wait(1.0)
			_account()
			await _shot("bot_over")
			break
		if game.hud.screen != "":
			_answer()
			await _frames(3)
			continue
		if smart:
			for guard in 20:
				var tech := Policy.best_research(game.run, game.home)
				if tech == "" or not game.act("research", {"id": tech}):
					break
			for guard in 16:
				var play := Policy.best_play(game.run, game.home)
				if play.is_empty():
					break
				_do(play)
			for guard in 3:
				var move := Policy.best_move(game.run, game.home)
				if move.is_empty():
					break
				_do(move)
		else:
			_play_all()
		await _frames(4)
		if game.run.round == 1 or game.run.round == game.run.rounds():
			await _frames(30)
			await _shot("bot_l%d_r%d" % [game.run.level, game.run.round])
		var before := game.home.hp
		var f := game.forecast.duplicate()
		game.act("fight")
		# The making comes first (and the eating), then the battle: till it is fought and what it brought is had.
		while game.phase != Game.Phase.FIGHT and game.phase != Game.Phase.DONE and game.hud.screen == "":
			await process_frame
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


## Researches, builds and raises the careless way (tools/Policy.gd any_research, any_play).
func _play_all() -> void:
	for guard in 20:
		var tech := Policy.any_research(game.home, rng)
		if tech == "" or not game.act("research", {"id": tech}):
			break
	for guard in 20:
		var play := Policy.any_play(game.home, rng)
		if play.is_empty():
			break
		_do(play)


## A Policy play done through the game's one door.
func _do(play: Array) -> void:
	match play[0]:
		"star":
			game.act("star")
		"build":
			game.act("build", {"plan": game.home.plans.find(play[1]), "at": play[2]})
		"raise":
			game.act("raise", {"at": play[1]})
		"move":
			game.act("move", {"from": play[1], "to": play[2]})


func _until_plan() -> void:
	while game.phase != Game.Phase.PLAN:
		await process_frame
	await _frames(20)


func _until_screen(prefix: String) -> void:
	while game.hud == null or not game.hud.screen.begins_with(prefix):
		await process_frame


## Until the player has something to do: plan, a screen to answer -- or the run is over.
func _until_turn() -> void:
	while game.hud.screen == "" and not game.phase in [Game.Phase.PLAN, Game.Phase.DONE]:
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
	var stars: Array = h.stars.map(func(s: Dictionary) -> String: return s.id + ("(%d)" % int(s.grow) if int(s.grow) > 0 else ""))
	print("%s (level %d) round %d hp %d/%d gold %d population %d/%d research %d blueprints %d stars %s hungry %d army %d | %s" % [
		Content.LEVELS[r.place].name, r.level + 1, r.round, h.hp, h.hp_max(), h.gold, h.pop_used(), h.pop_cap(), h.genes,
		h.plans.size(), stars, h.hungry.size(), h.settled().fighters.size(), built])


func _shot(label: String) -> void:
	await process_frame
	_n += 1
	var path := "%s/%02d_%s.png" % [out, _n, label]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())
