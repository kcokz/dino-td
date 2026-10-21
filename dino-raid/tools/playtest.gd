extends SceneTree
## A run played by a script, with pictures -- for seeing a change at work without playing (GAME-DESIGN 17, 18).
##
##   Godot --path dino-raid --script res://tools/playtest.gd -- <folder for frames> [bot [rounds] [seed] [smart]]
##
## Without "bot": the title and its settings, then the rainforest arrived in, the pause menu; the first rounds slowly --
## the round's army hatching, the shelf, special ground and a nest pointed at, each offer taken up over where it goes
## with what it would change and the forecast it brings, the hoarder bought and an offer kept by it and put down again,
## a nest evolved, the shelf restocked, buys, battles fought, the card picked after each and the deck -- then a
## homeland built up by hand (every kind of building, levels, the four evolved species, stars in their pens), a pen
## pointed at and its star's own screen, the deck worked on (a card picked, upgraded, cut), its boss battle (the mother
## breaking into spores), the star to choose, the map and the next place picked on it, the place arrived in -- the
## homeland made afresh -- and a battle there; a frame at each step.
## "bot": plays rounds the simple way (tools/Policy.gd, random -- or smart), fast, until the run ends or the rounds
## run out; checks every forecast against the battle fought; prints an account. For finding what breaks.

var game: Game
var out := ""
var smart := false
var _star_pick := {}              # the star chosen after a boss, and the pen to let go for it (Policy.best_star)
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
	game.hud._hovered = game.hud._cards[0]
	await _frames(14)
	await _shot("offer_close")
	game.hud._hovered = null
	await _aim_each("r1")
	await _keep_and_put()
	await _evolve()
	game.home.gold += 5
	game.act("reroll")
	await _frames(20)
	await _shot("rerolled")
	for r in 3:
		_play_all()
		await _frames(40)
		await _shot("bought_r%d" % game.run.round)
		await _fight_shots("r%d" % game.run.round)
		await _screens("r%d" % game.run.round)
		await _until_plan()
		if r == 0:
			game.hud.show_deck()
			await _frames(20)
			await _shot("deck_view")
			game.hud.chosen.emit("关闭")
			await _frames(6)
	await _rich()
	_account()
	quit()


## Each offer on the shelf taken up over a place it may go (an empty plot beside a building first): what it lights,
## what it changes, the forecast.
func _aim_each(label: String) -> void:
	var home := game.home
	home.gold += 10
	game.refresh()
	for i in home.shelf.size():
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
		await _shot("aim_%s_%s" % [label, home.shelf[i].id])
		game.held = -1
		game.refresh()
	home.gold -= 10
	game.refresh()


## The hoarder bought from the shop, and an offer kept by it and put down again: its pen lit, the stash, where it can
## go.
func _keep_and_put() -> void:
	var home := game.home
	home.gold += 14
	home.genes += 4
	home.star_offer = "hoarder"
	game.hud.deal(home.shelf)
	game.refresh()
	await _frames(20)
	game.hud._hovered = game.hud._star_card
	await _frames(14)
	await _shot("star_offer")
	game.hud._hovered = null
	if not game.act("star"):
		print("keep: could not buy the hoarder")
		return
	await _frames(30)
	await _shot("star_bought")
	var i := -1
	for k in home.shelf.size():
		if home.can_store(k):
			i = k
			break
	if i < 0:
		print("keep: nothing on the shelf could be kept")
		return
	game.hold(i)
	await _frames(8)
	await _shot("keep_slot")
	if not game.act("store", {"slot": i}):
		print("keep: could not keep it")
		return
	await _frames(20)
	await _shot("kept")
	game.hold_kept(0)
	var fits := home.stash_targets(0)
	if fits.is_empty():
		print("keep: nowhere to put it")
		return
	var at: Variant = fits[0]
	game.hover = {"plot": at, "unit": ""}
	game.refresh()
	await _frames(8)
	await _shot("put_aim")
	if not game.act("place", {"slot": 0, "at": at}):
		print("keep: could not put it down")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	await _frames(20)
	await _shot("put_down")


## A nest evolved: a stabilizer beside it for a second affix, acid and poison put down on it from the stash -- what
## the second shows before it goes on, and the new species.
func _evolve() -> void:
	var home := game.home
	var nest := HomeView.NOWHERE
	for p in home.buildings:
		if Content.is_nest(home.buildings[p].kind) and home.buildings[p].affixes.is_empty():
			nest = p
			break
	var spot := HomeView.NOWHERE
	if nest != HomeView.NOWHERE:
		for y in range(Content.FRONT_ROWS, Home.ROWS):
			var q := Vector2i(nest.x, y)
			if home.buildable(q) and not home.buildings.has(q):
				spot = q
				break
	if spot == HomeView.NOWHERE:
		print("evolve: no nest with room behind it")
		return
	home.build(spot, "stabilizer")
	home.stash = [{"id": "a_acid"}, {"id": "a_poison"}]
	game.home_view.refresh_buildings()
	game._version += 1
	game.refresh()
	game.act("place", {"slot": 0, "at": nest})
	await _frames(20)
	game.hold_kept(0)
	game.hover = {"plot": nest, "unit": ""}
	game.refresh()
	await _frames(10)
	await _shot("evolve_aim")
	if not game.act("place", {"slot": 0, "at": nest}):
		print("evolve: could not put the poison on")
	game.hover = {"plot": nest, "unit": ""}
	game.refresh()
	await _frames(12)
	await _shot("evolved")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	game.refresh()


## A homeland built up by hand -- the battle line full of nests (the four new species, elites), behind it every school's
## buildings, stars in their pens -- a pen pointed at, a star's own screen, a nest raised elite, the deck worked on,
## its boss battle, the star to choose, the map, the next place.
func _rich() -> void:
	var h := game.home
	h.terrain = {Vector2i(0, 2): "pond", Vector2i(5, 3): "tree", Vector2i(3, 3): "pond"}
	h.buildings.clear()
	# [plot, kind, nest's choices (or a level), affixes] -- the battle line laid out for the nests' gifts: two greens
	# guarding (a white caring behind one, scavengers behind the other), four reds swarming, a gold alone at the edge, a
	# blue with no cover yet (nothing in front of it), a mutant with two affixes.
	var plan := [[Vector2i(0, 0), "nest_green", ["count"], ["shell"]],
		[Vector2i(1, 0), "nest_red", ["elite"], ["blade", "wings"]], [Vector2i(2, 0), "nest_red", ["count", "count"], ["flame", "blade"]],
		[Vector2i(3, 0), "nest_green", [], []], [Vector2i(5, 0), "nest_gold", ["elite"], []],
		[Vector2i(0, 1), "nest_white", [], []], [Vector2i(1, 1), "nest_red", ["count"], ["hide"]],
		[Vector2i(2, 1), "nest_red", [], ["haste"]], [Vector2i(3, 1), "nest_scav", ["count"], []],
		[Vector2i(4, 1), "nest_blue", ["count"], []], [Vector2i(5, 1), "nest_mutant", ["count"], ["acid", "poison"]],
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
	h.stars = [{"id": "hoarder", "grow": 0}, {"id": "scar", "grow": 0}, {"id": "tri", "grow": 0}, {"id": "oldking", "grow": 2},
		{"id": "belly", "grow": 0}]
	h.hungry = [2]
	h.star_offer = "neck"
	h.gold = 30
	h.biomass = 40
	h.genes = 8
	h.hp = h.hp_max()
	h.deck.append_array([{"id": "b_green", "plus": false}, {"id": "b_white", "plus": true}, {"id": "a_acid", "plus": false},
		{"id": "b_stab", "plus": false}, {"id": "raise", "plus": true}])
	h.stock(game.run.rng, 0)
	game.home_view.lay_ground()
	game.home_view.refresh_buildings(false)
	game._version += 1
	game.home_view.sync_army(h.army())
	game.hud.deal(h.shelf)
	game.refresh()
	await _frames(60)
	await _shot("rich_home")
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
	h.stash = [{"id": "raise"}]
	game.refresh()
	await _frames(10)
	game.hold_kept(0)
	game.hover = {"plot": Vector2i(3, 0), "unit": ""}
	game._click()
	await _frames(10)
	await _shot("raise_choice")
	game.aim("elite")
	await _frames(6)
	await _shot("raise_choice_elite")
	game.act("choose", {"choice": "elite"})
	game.hover = {"plot": Vector2i(3, 0), "unit": ""}
	game.refresh()
	await _frames(20)
	await _shot("raised_elite")
	game.hover = {"plot": HomeView.NOWHERE, "unit": ""}
	await _deck_work()
	# A green taken up over the gap in front of the blue: the blue would be under cover, the gold no longer alone.
	h.shelf[1] = {"id": "b_green"}
	game.hud.deal(h.shelf)
	game.refresh()
	await _frames(20)
	game.hold(1)
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
	await _frames(10)
	await _shot("boss_plan")
	await _fight_shots("boss")
	await _screens("boss")
	await _screens("boss")
	await _screens("boss")
	await _screens("boss")
	await _until_screen("到了")
	await _frames(20)
	await _shot("arrive_next")
	game.hud.chosen.emit("开始")
	await _until_plan()
	await _shot("next_r1")
	game.hud._hovered = game.hud._cards[0]
	await _frames(14)
	await _shot("next_offer")
	game.hud._hovered = null
	_play_all()
	await _frames(30)
	await _fight_shots("next")
	await _screens("next")
	await _until_plan()
	await _shot("next_r2")


## The deck worked on, as after a mini-boss: laid out, a card picked, the upgrade pointed at (the card shown upgraded),
## upgraded; another picked and cut; done.
func _deck_work() -> void:
	game.home.gold += 10
	game._workshop()
	await _until_screen("整理牌库")
	await _frames(20)
	await _shot("workshop")
	var cards := _deck_cards()
	var pick: CardView = cards[4]
	pick.clicked.emit(pick)
	await _frames(6)
	await _shot("workshop_picked")
	var up: Button = _button_saying("强化")
	if up != null and not up.disabled:
		up.mouse_entered.emit()
		await _frames(6)
		await _shot("workshop_upgrade_aim")
		up.mouse_exited.emit()
		up.pressed.emit()
	await _frames(10)
	await _until_screen("整理牌库")
	await _frames(10)
	await _shot("workshop_upgraded")
	cards = _deck_cards()
	(cards[0] as CardView).clicked.emit(cards[0])
	await _frames(4)
	var cut: Button = _button_saying("删掉")
	if cut != null and not cut.disabled:
		cut.pressed.emit()
	await _frames(10)
	await _until_screen("整理牌库")
	await _frames(10)
	await _shot("workshop_cut")
	game.hud.chosen.emit("完成")
	await _frames(10)
	game.home.gold = 30
	game.refresh()


## The deck's cards laid out on the screen up (the last of the HUD's cards: the shelf's come before them).
func _deck_cards() -> Array:
	var all := game.hud.find_children("*", "CardView", true, false)
	return all.slice(all.size() - game.home.deck.size())


## The button up on the screen whose words begin with `words`, or null.
func _button_saying(words: String) -> Button:
	for b in game.hud.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(words) and (b as Button).is_visible_in_tree():
			return b
	return null


## The screen after a battle (the card to pick, the deck to work on, the star, the map), shot and answered -- the map
## with a place picked on it first.
func _screens(label: String) -> void:
	while game.hud.screen == "" and not game.phase in [Game.Phase.PLAN, Game.Phase.DONE]:
		await process_frame
	if game.hud.screen == "":
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
		await _shot(("reward_" if s.begins_with("挑一张") else "screen_") + label)
	_answer()
	await _frames(4)


## Answers the screen up: the arrival, a card (smart: the best, or the gold), the deck (smart: as tools/Policy.gd works
## it; else left as it is), a star after a boss (smart: the best, letting one go for it if that is better; else the
## first, letting none go), the next place.
func _answer() -> void:
	var s: String = game.hud.screen
	var offered: Array = game.hud.offered
	if s.begins_with("到了"):
		game.hud.chosen.emit("开始")
	elif s.begins_with("挑一张"):
		var k := Policy.best_reward(game.run, game.home, offered) if smart else 0
		if k >= 0 and k < offered.size():
			game.hud.chosen.emit(offered[k])
		else:
			game.hud.chosen.emit("不要牌，拿 %d 金" % Content.REWARD_GOLD)
	elif s.begins_with("整理牌库"):
		var step := Policy.workshop_step(game.run, game.home) if smart else {}
		game.hud.chosen.emit(step if not step.is_empty() else "完成")
	elif s.begins_with("牌库"):
		game.hud.chosen.emit("关闭")
	elif s.begins_with("下一站"):
		game.hud.chosen.emit(Policy.best_place(game.run))
	elif s.ends_with("守住了！"):
		_star_pick = Policy.best_star(game.run, game.home, offered) if smart else {"id": offered[0], "release": -1}
		game.hud.chosen.emit(_star_pick.id)
	elif s.begins_with("围栏满了"):
		game.hud.chosen.emit(int(_star_pick.get("release", -1)))


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
	for u in game.home.army():
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
			var restocked := 0
			for guard in 16:
				var play := Policy.best_play(game.run, game.home)
				if play.is_empty():
					if restocked < 2 and game.home.gold >= game.home.reroll_price() + 4:
						game.act("reroll")
						restocked += 1
						continue
					break
				_do(play)
		else:
			_play_all()
		await _frames(4)
		if game.run.round == 1 or game.run.round == game.run.rounds():
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


## Buys and puts down the careless way (tools/Policy.gd any_play).
func _play_all() -> void:
	for guard in 20:
		var play := Policy.any_play(game.home, rng)
		if play.is_empty():
			break
		_do(play)


## A Policy play done through the game's one door.
func _do(play: Array) -> void:
	if play[0] == "star":
		game.act("star")
	else:
		game.act(play[0], {"slot": play[1], "at": play[2], "choice": play[3] if play.size() > 3 else "count"})


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
	var plus := h.deck.filter(func(c: Dictionary) -> bool: return c.plus).size()
	var stars: Array = h.stars.map(func(s: Dictionary) -> String: return s.id + ("(%d)" % int(s.grow) if int(s.grow) > 0 else ""))
	print("%s (level %d) round %d hp %d/%d gold %d biomass %d research %d deck %d (+%d) stash %d stars %s hungry %d army %d | %s" % [
		Content.LEVELS[r.place].name, r.level + 1, r.round, h.hp, h.hp_max(), h.gold, h.biomass, h.genes, h.deck.size(), plus,
		h.stash.size(), stars, h.hungry.size(), h.army().size(), built])


func _shot(label: String) -> void:
	await process_frame
	_n += 1
	var path := "%s/%02d_%s.png" % [out, _n, label]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())
