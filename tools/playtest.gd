# res://tools/playtest.gd
#
# Plays the game with a real renderer and photographs it.
#
#   godot --path . --resolution 1600x900 --script res://tools/playtest.gd -- open cabin
#
# Scenario names come after the `--`; no names runs them all. Frames land in
# `screenshots/` (git-ignored) as `NN_scenario_beat.png`.
#
# Why this exists: the headless suite asserts what the code DOES, and cannot see what
# the game LOOKS like. v0.5's acceptance is literally a screenshot (VERSION.md), and
# the defects this catches -- a map with a visible edge, a room you can see the sky
# over, a label that never got formatted -- are invisible to every assertion we have.
#
# Three rules this file exists to keep, all of them learned the hard way:
#
#   1. WAIT A FRAME BEFORE LOADING THE SCENE. Autoloads are not in the tree during
#      SceneTree._init(), so I18n has not parsed strings.csv yet and tr() returns raw
#      keys. A harness that skips this renders a HUD full of "%d" and reports a bug
#      that does not exist. That happened, and cost an evening.
#   2. FRAMES, NOT SECONDS. Every wait here is a frame count, so two runs of the same
#      scenario produce the same picture. A harness whose output wobbles is a harness
#      nobody reads.
#   3. THIS IS NOT A TEST. It asserts nothing and it never fails a build. It needs a
#      GPU and takes seconds, so it lives in tools/ and stays out of the suite. During
#      v0.5 the art changes daily; pixel-diffing it would produce a red light every
#      morning, and a red light nobody believes is worse than no light at all.
extends SceneTree

const OUT_DIR := "res://screenshots"
const SETTLE_FRAMES := 30      # long enough for shaders to compile and the first draw

var _main: Node = null
var _shot_index: int = 0
var _scenario: String = ""
## What "only:<name>" arguments narrowed a list-going scenario to (gaits); empty for all of it.
var _only: PackedStringArray = []
## The run's seed ("seed:N"), or -1 for a new one each run.
var _seed: int = -1

func _init() -> void:
	# Rule 1. Without this the whole HUD renders untranslated.
	await process_frame

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# The frames are for looking at, not for the game: the editor is kept from importing each
	# one (a .import beside every frame, and a scan of them all on a slow share).
	if not FileAccess.file_exists(OUT_DIR + "/.gdignore"):
		var ignore := FileAccess.open(OUT_DIR + "/.gdignore", FileAccess.WRITE)
		if ignore:
			ignore.close()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var names: Array = []
	for w in wanted:
		# "lang:zh_CN" shoots in that language (the engine's locale only -- the player's saved
		# settings are not touched).
		if String(w).begins_with("lang:"):
			TranslationServer.set_locale(String(w).substr(5))
			continue
		# "seed:7" plays every scenario's run on that seed (GameState.reset_game): the same valley, the same dice --
		# so two plans played on it are told apart by the plan, not by luck.
		if String(w).begins_with("seed:"):
			_seed = int(String(w).substr(5))
			continue
		# "map:valley_large" plays on that map; the default is the small valley.
		if String(w).begins_with("map:"):
			root.get_node("GameState").chosen_map_id = String(w).substr(4)
			continue
		# "only:postosuchus" narrows a scenario that goes through a list (gaits) to that one.
		if String(w).begins_with("only:"):
			_only.append(String(w).substr(5))
			continue
		names.append(String(w))
	if names.is_empty():
		names = ["open", "fence", "cabin", "closeup", "gap", "raid", "hero", "wreck", "snug", "showcase", "scale"]

	for name in names:
		await _run(String(name))

	print("[playtest] %d frames written to %s" % [_shot_index, OUT_DIR])
	quit(0)

func _run(name: String) -> void:
	_scenario = name
	await _fresh_level()
	if name.begins_with("siege"):
		await _scenario_siege(name)
		_tear_down()
		return
	if name.begins_with("play"):
		await _scenario_play(name)
		_tear_down()
		return
	# A look at one thing is taken in the middle of the day, in the valley's own light (Config.DAY):
	# a run lands in its morning, whose low sun throws the trees' shadows across what is looked at.
	# The day's own scenario sets its hours itself.
	var gs_noon := root.get_node_or_null("GameState")
	var cfg_noon := root.get_node_or_null("Config")
	if gs_noon and cfg_noon and "DAY" in cfg_noon and name != "day":
		gs_noon.day_clock = (float(cfg_noon.DAY["light"][2]["at"]) + float(cfg_noon.DAY["light"][3]["at"])) * 0.5
	match name:
		"open":
			await _scenario_open()
		"fence":
			await _scenario_fence()
		"cabin":
			await _scenario_cabin()
		"closeup":
			await _scenario_closeup()
		"jump":
			await _scenario_jump()
		"crash":
			await _scenario_crash()
		"firepot":
			await _scenario_firepot()
		"ammocard":
			await _scenario_ammocard()
		"gap":
			await _scenario_gap()
		"raid":
			await _scenario_raid()
		"hero":
			await _scenario_hero()
		"wreck":
			await _scenario_wreck()
		"snug":
			await _scenario_snug()
		"ram":
			await _scenario_ram()
		"hammer":
			await _scenario_hammer()
		"stages":
			await _scenario_stages()
		"opening":
			await _scenario_opening()
		"showcase":
			await _scenario_showcase()
		"scale":
			await _scenario_scale()
		"cast":
			await _scenario_cast()
		"cast2":
			# Station 2's (the Late Jurassic, MAPS.morrison): the same lineup, by the man.
			await _scenario_cast([["ornitholestes", -1.2], ["harpactognathus", 1.4], ["ceratosaurus", 4.6],
				["allosaurus", 11.0]])
		"chargers":
			# The frightened plant-eaters (v0.7, ChargerDino) by the man and a coelophysis: Desmatosuchus, the Stegosaurus.
			await _scenario_cast([["coelophysis", -1.2], ["desmatosuchus", 2.0], ["stegosaurus", 7.5]])
		"gaits":
			await _scenario_gaits()
		"start":
			await _scenario_start()
		"custom":
			await _scenario_custom()
		"pod":
			await _scenario_pod()
		"ghost":
			await _scenario_ghost()
		"buildings":
			await _scenario_buildings()
		"beacon":
			await _scenario_beacon()
		"summary":
			await _scenario_summary()
		"legible":
			await _scenario_legible()
		"ui":
			await _scenario_ui()
		"buildmenu":
			await _scenario_buildmenu()
		"menu":
			await _scenario_menu()
		"journal":
			await _scenario_journal()
		"paused":
			await _scenario_paused()
		"kit":
			await _scenario_kit()
		"herocard":
			await _scenario_herocard()
		"day":
			await _scenario_day()
		"map":
			await _scenario_map()
		_:
			print("[playtest] unknown scenario: %s" % name)
	_tear_down()

# ==============================================================================
# Scenarios
# ==============================================================================

## A run played the way a player plays it, through the same orders a click gives -- nothing
## granted, nothing placed by hand: pick up the opening wood, the first bow tower, ring the cabin with palisade and a
## gate at its door, chop trees until the raid, stand inside the ring while it comes, gather what
## it leaves, go in and make the pick, then quarry stone; towers north of the ring, loaded with what
## the workbench makes for them (the 2026-10-02 rebuild), a strip of spikes before them, the towers raised a level and
## the ring's north side turned to stone as there is the stuff. A line of what is happening every ten seconds of game
## time, and a frame at each beat.
##
## `play:<minutes>` plays that long (default 8), at the game's own 3x.
## "play:<minutes>[:<plan>]" -- a run played as a player would, for `minutes` of game time. THE PLAN (2026-10-04, the
## player: "如果有的事情不做也可以过关，就要考虑这个是玩家可选的方向吗……如果不是，那就是没存在的必要") is what it does
## and what it leaves undone, so a run without one thing can be laid beside a run with it:
##   all          everything below (the default)
##   -<thing>     all but that one (_plan_has): -ring, -bow, -drop, -thrower, -bait, -spikes, -fire, -torch, -axe, -pod,
##                -fight, -upgrade, -wallup
##   +<kind>      all, and three more towers of that kind round the cabin: +bow, +drop, +thrower -- what piling on one
##                thing buys against the rest ("如果某个选项做的多了明显比别的选项要效果好太多……")
##   bows         only bow towers -- five -- and wooden arrows: no ring of palisade, no other tower
##   savvy        how he plays, not what: a raid not near him he works through; with a torch, the night as the day
## (commas between: "play:25:-pod,savvy"). Its account is printed at the end as one line, "[report] {json}" (_report):
## where his time went, what came in and went out, how much timber is left standing, and each raid.
func _scenario_play(spec: String) -> void:
	var parts: PackedStringArray = spec.split(":")
	var minutes: float = float(parts[1]) if parts.size() > 1 else 8.0
	_plan_words = PackedStringArray(String(parts[2]).split(",")) if parts.size() > 2 else PackedStringArray(["all"])
	_ledger_begin()
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	var hero = _main.hero
	var cabin = _main.current_core
	var gm = _main.grid_manager
	var wm = _main.wave_manager
	Engine.time_scale = 3.0
	_play_clock = 0.0
	_play_log = []
	_play_t0 = Time.get_ticks_msec()
	var clock := {"t": 0.0}
	var note := func(text: String) -> void:
		var line: String = "[play %5.1fs] %s" % [_play_clock, text]
		print(line)
		_play_log.append(line)
	eb.raid_warning.connect(func(left): note.call("RAID WARNING, %.0fs" % left))
	eb.wave_started.connect(func(n, big): note.call("raid %d sets out%s" % [n, " (big)" if big else ""]))
	eb.wave_ended.connect(func(n): note.call("raid %d over" % n))
	eb.dino_died.connect(func(d): note.call("a %s died" % d.dino_type))
	eb.building_destroyed.connect(func(b): note.call("LOST a %s" % b.building_type))
	eb.unlock_granted.connect(func(u): note.call("made: %s" % u))
	eb.hero_died.connect(func(): note.call("THE HERO DIED"))
	eb.game_lost.connect(func(): note.call("GAME LOST"))
	eb.game_won.connect(func(): note.call("GAME WON -- the jump home"))
	eb.beacon_launched.connect(func(): note.call("BEACON LAUNCHED -- the final wave"))
	eb.beacon_changed.connect(func(n): note.call("beacon: %d steps done" % n))
	eb.cabin_view_changed.connect(func(inside): note.call("he is %s the cabin" % ("in" if inside else "out of")))
	note.call("plan: %s, seed %d, map %s" % [",".join(_plan_words), _seed, String(gs.map_id)])

	# --- 1. The opening wood --------------------------------------------------------------
	_ctx = "drops"
	var piles: Array = get_nodes_in_group(DropItem.GROUP)
	note.call("%d piles of opening stock on the ground" % piles.size())
	for pile in piles:
		if not is_instance_valid(pile):
			continue
		var pile_id: int = pile.get_instance_id()
		hero.move_to((pile as Node3D).global_position)
		await _play_until(func(): return not is_instance_id_valid(pile_id), 25.0, "picking up a pile")
	note.call("stock: %s" % str(gs.resources))
	await _shoot("stock_picked_up")

	# --- 1b. The first tower, armed, before anything else: the opening's wood pays for one and a batch of its arrows
	# (test_v06_the_opening). A bot that chopped wood till the first raid met it with nothing standing, and three
	# coelophysis had the cabin down in a minute (v0.7: they come for the cabin, and the man last).
	if _plan_has("bow"):
		await _first_tower(hero, cabin, note, minutes)

	# --- 2. A ring of palisade round the cabin, a cell out, a gate at the door -----------
	_ctx = "build"
	var centre: Vector2i = gm.world_to_build_cell(cabin.global_position)
	var half := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
	var gate_cell: Vector2i = centre + Vector2i(0, half.y + 1)
	var ringed: bool = _plan_has("ring")
	if ringed:
		_main.on_build_selected("gate")
	var gate = _main.try_place_at_cell(gm.world_to_cell(gm.build_cell_to_world(gate_cell)), gm.build_cell_to_world(gate_cell)) if ringed else null
	note.call("gate ordered: %s" % ("yes" if gate else "NO"))
	if ringed:
		_main.on_build_selected("wall")
	var ring: Array[Vector2i] = []
	for x in range(-half.x - 1, half.x + 2):
		ring.append(centre + Vector2i(x, -half.y - 1))
	for z in range(-half.y, half.y + 2):
		ring.append(centre + Vector2i(half.x + 1, z))
	for x in range(half.x, -half.x - 2, -1):
		ring.append(centre + Vector2i(x, half.y + 1))
	for z in range(half.y, -half.y - 1, -1):
		ring.append(centre + Vector2i(-half.x - 1, z))
	var ordered: int = 0
	var refused: int = 0
	for cell in ring:
		if not ringed or cell == gate_cell or _main.current_build_type == "":
			continue
		var at: Vector3 = gm.build_cell_to_world(cell)
		if _main.try_place_at_cell(gm.world_to_cell(at), at) != null:
			ordered += 1
		else:
			refused += 1
	_main.cancel_building_selection()
	note.call("palisade ordered: %d sections, %d refused" % [ordered, refused])
	await _play_until(func(): return _unfinished() == 0, 90.0, "building the ring")
	note.call("ring up: %d unfinished left; hero at %s" % [_unfinished(), _cellstr(hero.global_position, gm)])
	await _portrait("ring", cabin.global_position, 13.0, true)

	# --- 3. Wood until the raid ------------------------------------------------------------
	if not ringed:
		ring.clear()
	while wm.current_wave == 0 and _play_clock < minutes * 60.0:
		await _chop_a_while(hero, "wood", 8.0)
		if wm.raid_timer < 8.0:
			break
	note.call("wood: %d; raid in %.0fs" % [int(gs.resources.get("wood", 0)), wm.raid_timer])

	# --- 4 onwards: raids come and go; between them, what a player would do next -------------
	# In order: the beacon when its next step can be paid; a rest in the healing pod when he is hurt;
	# the pick, then the axe; the towers north of the ring, the way the
	# nest is -- a bow tower each side, a drop tower between them where the raid comes past, a bait
	# rack in front of it to hold what comes under it, a catapult further out once there is stone,
	# and a campfire each side of the ring for the towers to see by at night (v0.7: they see only by
	# firelight) -- each loaded with what the workbench makes for it, or with meat, carried over by
	# him; the ring mended where a raid broke it; and otherwise stone while there is little, and wood.
	# Launched, he shelters till the end.
	var last_status: float = -100.0
	var raids_seen: int = 0
	# The two campfires first after the first tower: north and south of the ring, between them the cabin all in their
	# light (FIRE light 7 m) -- what keeps the phytosaurs off it at night, and what the towers see by.
	var tower_plan: Array = [
		["bow_tower", centre + Vector2i(-4, -half.y - 3)],
		["campfire", centre + Vector2i(0, -half.y - 2)],
		["campfire", centre + Vector2i(-2, half.y + 2)],
		["drop_tower", centre + Vector2i(0, -half.y - 4)],
		["bait_rack", centre + Vector2i(0, -half.y - 6)],
		["bow_tower", centre + Vector2i(3, -half.y - 3)],
		["catapult", centre + Vector2i(-9, -half.y - 4)],
		# A strip of spikes across the way the raids come, before the bait rack (CellTrap; re-laid as they wear out).
		["ground_spikes", centre + Vector2i(-2, -half.y - 9)],
		["ground_spikes", centre + Vector2i(-1, -half.y - 9)],
		["ground_spikes", centre + Vector2i(0, -half.y - 9)],
		["ground_spikes", centre + Vector2i(1, -half.y - 9)],
		["ground_spikes", centre + Vector2i(2, -half.y - 9)],
	]
	# Three more of a kind (+bow, +drop, +thrower): round the cabin's east, west and north-east, after the rest.
	for word in _plan_words:
		if String(word).begins_with("+"):
			var kind_id: String = {"bow": "bow_tower", "drop": "drop_tower", "thrower": "catapult"}.get(String(word).substr(1), "")
			if kind_id != "":
				tower_plan.append([kind_id, centre + Vector2i(half.x + 4, -1)])
				tower_plan.append([kind_id, centre + Vector2i(-half.x - 4, -1)])
				tower_plan.append([kind_id, centre + Vector2i(6, -half.y - 7)])
	# Only bow towers (the player's run, 2026-10-03: "我就靠造了5个bow tower，加不停地做木箭装填就行了"): five, round the
	# cabin's north, east and west, the way raids come.
	if _plan_words.has("bows"):
		tower_plan = [
			["bow_tower", centre + Vector2i(-4, -half.y - 3)],
			["bow_tower", centre + Vector2i(3, -half.y - 3)],
			["bow_tower", centre + Vector2i(half.x + 4, 0)],
			["bow_tower", centre + Vector2i(-half.x - 4, 0)],
			["bow_tower", centre + Vector2i(0, -half.y - 7)],
		]
	# Left out by its kind ("-thrower", "-fire", "-spikes") or by itself ("-catapult", "-campfire").
	tower_plan = tower_plan.filter(func(p): return (_plan_has(String(cfg.BUILDINGS[String(p[0])].get("kind", ""))) \
		and _plan_has(String(p[0]))) or _plan_words.has("bows"))
	var refused_towers: Dictionary = {}
	var shots_taken: Dictionary = {}
	while _play_clock < minutes * 60.0 and not gs.is_game_over:
		# At least a frame every time round: a step that finds nothing to wait for (the raid
		# about to set out, a job it cannot start) must not spin the loop with the game held still.
		await _advance(0.1)
		if not is_instance_valid(cabin):
			break
		_ctx = "think"
		_tick(0.1 * Engine.time_scale)
		if _play_clock - last_status >= 20.0:
			last_status = _play_clock
			note.call(_play_status(hero, cabin, gs, wm))
		# Launched, the valley answers after a grace (MAPS.beacon.launch_grace): he works through
		# it like any quiet spell -- mending, building -- and shelters only once they are out.
		# Savvy, a raid that is nowhere near him he works through: it is the cabin they are after, and the man last.
		var working_through: bool = _plan_words.has("savvy") and (wm.is_wave_active or wm.final_wave) \
			and _nearest_dino(hero, 10.0) == null and hero.current_hp >= hero.max_hp * 0.6 \
			and (String(gs.day_part()) == "day" or float(hero.get("torch_left")) > 0.0) \
			and _charger_at(cabin, 10.0) == null
		if (wm.is_wave_active or wm.final_wave) and not working_through:
			if wm.final_wave and not shots_taken.has("final"):
				shots_taken["final"] = true
				await _shoot("final_wave")
			for d in get_nodes_in_group("dinos"):
				if is_instance_valid(d) and String(d.dino_type) == String(gs.map_data()["boss"]) and not shots_taken.has("boss"):
					shots_taken["boss"] = true
					note.call("THE BOSS IS ON THE FIELD")
					await _portrait("boss", (d as Node3D).global_position, 7.0)
				if is_instance_valid(d) and String(d.dino_type) == String(gs.map_data()["minor_boss"]) and not shots_taken.has("alpha"):
					shots_taken["alpha"] = true
					note.call("the alpha is on the field")
					await _portrait("alpha", (d as Node3D).global_position, 4.0)
			if not is_instance_valid(cabin):
				break
			var home: Vector3 = cabin.door_inside()
			# What is at the cabin he goes out to, as a player would, while he has the health for it --
			# and rests in the healing pod when he has not (HealingPod). The cabin's gun used to finish a
			# raid while he sheltered at the door; it has none since 2026-10-02 ("cabin的自动射击得取消了"),
			# and a raid sat out inside brings it down.
			# v0.7: what strikes them is what they go for first -- a man who goes out into a pack is what the pack
			# turns on. He goes out only to one on its own, and only while he has the health for it; else he is
			# in, out of their way (they come for the cabin, and the man last), and in the pod once hurt.
			var near: Node3D = _nearest_dino(hero, 9.0)
			var hurt: bool = hero.current_hp < hero.max_hp * 0.6
			# And not out into the dark to do it: what is out there at night is out for him.
			var alone: bool = near != null and _dinos_round(near, 6.0) <= 1 \
				and (String(gs.day_part()) == "day" or _lit(near.global_position))
			var pod = cabin.station("pod")
			# A frightened charger at the cabin (ChargerDino) he goes out to whatever else is there: it pays him no
			# mind and does not strike back, arrows hardly hurt it, and it is ramming the cabin.
			var charger: Node3D = _charger_at(cabin, 10.0)
			if charger != null and String(gs.day_part()) != "day" and not _lit(charger.global_position):
				charger = null
			# Not into a pack round it, though: the pack is not so indifferent to him (the bench's seed 8 -- he went out
			# to a Desmatosuchus with ten coelophysis about it, and was dead in six seconds).
			if charger != null and _dinos_round(charger, 6.0) > 1:
				charger = null
			if hero.rest_pod() != null:
				pass      # in the pod, or on his way to it: it mends him, and lets him out whole
			elif hurt and _plan_has("pod") and pod != null and pod.can_offer("rest"):
				pod.begin("rest")
			elif charger != null and not hurt and _plan_has("fight"):
				if hero.target_enemy != charger:
					hero.order_attack(charger)
			elif near != null and not hurt and alone and _plan_has("fight"):
				if hero.target_enemy != near:
					hero.order_attack(near)
			elif not cabin.hero_inside and not _sheltering:
				_sheltering = true
				_main.order_enter_cabin()
			elif not cabin.hero_inside and hero.global_position.distance_to(home) > 1.5 and int(hero.current_state) != 1:
				hero.move_to(home)
			_ctx = "raid"
			await _advance(1.0)
			_tick(Engine.time_scale)
			continue
		_sheltering = false
		# v0.7's nights (GAME-DESIGN 9.3; the towers see only by firelight): out of the fires' light he is what the
		# phytosaurs are out for -- a bot that went on working in the dark was bitten back into the pod all night, the
		# towers unbuilt and the cabin bitten. In the dark he works the benches inside, loads what a fire or his torch
		# lights, puts up a campfire, and otherwise waits in the cabin for the morning.
		var dark: bool = String(gs.day_part()) != "day"
		var lit_hero: bool = float(hero.get("torch_left")) > 0.0
		if wm.current_wave > raids_seen and not dark and not wm.is_wave_active:
			raids_seen = wm.current_wave
			_ctx = "drops"
			await _gather_drops(hero, note)
			continue
		var wb = cabin.station("workbench")
		var beacon_job: String = String(gs.beacon_next_job())
		var pick_flag: String = String(cfg.RECIPES["stone_pick"]["unlocks"])
		# The defence's core before the beacon: the first tower, the two fires, the drop tower (what crushes the
		# armoured chargers that come from the second day). The bot that paid the beacon first met the second day's
		# raid with one bow tower, and two Desmatosuchus walked through it to the cabin.
		# The first of the plan not up that can be paid for now, in the plan's order -- one waiting on stone does not
		# hold up the rest (the bench's first run of +bow: the catapult's eleven stone kept the strip of spikes and the
		# three more bow towers unbuilt to the end) -- and the first not up at all, what the stone is quarried for.
		var next_tower: Array = []
		var next_index: int = -1
		var wanted_tower: Array = []
		for i in tower_plan.size():
			var plan: Array = tower_plan[i]
			if refused_towers.has(plan[1]) or gm.building_in_build_cell(plan[1]) != null:
				continue
			if wanted_tower.is_empty():
				wanted_tower = plan
			var cost: Dictionary = cfg.BUILDINGS[plan[0]]["cost"]
			if gs.knows_all(cost) and gs.can_afford(cost) and (not dark or String(cfg.BUILDINGS[plan[0]].get("kind", "")) == "fire"):
				next_tower = plan
				next_index = i
				break
		var can_raise: bool = not next_tower.is_empty()
		if can_raise and next_index < 4:
			await _raise(next_tower, refused_towers, note)
			continue
		if beacon_job != "" and cabin.station(String(cfg.BEACON_STATION)).can_afford(beacon_job):
			await _bench_job(hero, cabin, String(cfg.BEACON_STATION), beacon_job, note)
			continue
		# The part the next stage takes, out of its wreck, once the rest of its price is in -- while
		# nothing guards it (the battery's wreck is behind the nest, and is searched by night), and not
		# with a raid about to set out: it set off and turned back every step till the raid came.
		var wreck: Node = _wreck_to_search(beacon_job) if (wm.raid_timer >= 6.0 and not dark) else null
		if wreck != null:
			note.call("to the wreck for the %s" % String(wreck.resource_type))
			_ctx = "wreck"
			await _search_wreck(hero, wreck)
			continue
		# Hurt, he rests in the healing pod before he goes out again (HealingPod): whole in a few seconds,
		# nothing else done meanwhile.
		var pod = cabin.station("pod")
		# Or tired (Config.STAMINA): he sleeps in it before he is worn out -- under a third of it, by day.
		var tired: bool = "stamina" in hero and float(hero.stamina) < float(hero.max_stamina) * 0.35
		if _plan_has("pod") and pod != null and pod.can_offer("rest") and (hero.current_hp < hero.max_hp * 0.7 or tired):
			_ctx = "rest"
			note.call("resting in the pod (%d/%d)" % [int(hero.current_hp), int(hero.max_hp)])
			pod.begin("rest")
			await _play_until(func(): return hero.rest_pod() == null, float(pod.time_of("rest")) + 20.0, "resting")
			continue
		# Tonight's wood put by before dusk: each fire takes its night's from the stock as it lights (Fire), and one
		# that cannot burns not -- the towers blind by it, the phytosaurs at the cabin.
		if not dark and float(gs.time_of_day()) >= float(cfg.DAY["parts"]["dusk"]) - 50.0 \
				and int(gs.resources.get("wood", 0)) < _fuel_reserve():
			await _chop_a_while(hero, "wood", 8.0)
			continue
		if not gs.has_unlock(pick_flag) and wb.can_afford("stone_pick"):
			await _bench_job(hero, cabin, "workbench", "stone_pick", note)
			continue
		if _plan_has("axe") and wb.can_offer("stone_axe") and wb.can_afford("stone_axe"):
			await _bench_job(hero, cabin, "workbench", "stone_axe", note)
			continue
		if can_raise:
			await _raise(next_tower, refused_towers, note)
			continue
		# Ammunition a tower on the field wants, made at the workbench a batch at a time; then he takes it over.
		var ammo_job: String = _ammo_wanted(wb)
		if ammo_job != "":
			await _bench_job(hero, cabin, "workbench", ammo_job, note)
			continue
		var empty: Node = _tower_wanting_load(dark and not lit_hero)
		if empty != null:
			var empty_id: int = empty.get_instance_id()
			_ctx = "load"
			hero.order_load(empty)
			note.call("loading the %s" % String(empty.building_type))
			await _play_until(func(): return not is_instance_id_valid(empty_id) or not empty.wants_load(), 30.0, "loading a tower")
			continue
		# The line up -- all of the plan built, the three more of a kind among it -- by day: a tower raised a level
		# (Building.begin_upgrade) when it can be paid with tonight's wood still put by -- the first that can, so they go
		# up in turn.
		if not dark and _plan_has("upgrade") and wanted_tower.is_empty():
			var up: Node = _tower_to_raise()
			if up != null:
				await _upgrade(hero, up, String(up.upgrade_target()), note)
				continue
		# And the ring's north side -- the way the raids come -- turned to stone, a section at a time, while there is
		# stone to spare (the pick's: Config.BUILDINGS.stone_wall).
		if not dark and _plan_has("wallup") and _plan_has("ring") and wanted_tower.is_empty():
			var section: Node = _wall_to_stone(ring)
			if section != null:
				await _upgrade(hero, section, "stone_wall", note)
				continue
		# Savvy, with a torch to light he works the night as the day (the phytosaurs keep out of its light).
		if dark and _plan_words.has("savvy") and _plan_has("torch") and hero.has_method("can_light_torch") \
				and (lit_hero or hero.can_light_torch()):
			dark = false
		if dark:
			_ctx = "night"
			# The night is for sleeping (Config.STAMINA: the pod rests him as it mends him) -- in the pod while it can
			# rest him, else in the cabin.
			var bed = cabin.station("pod")
			if _plan_has("pod") and bed != null and bed.can_offer("rest") and hero.rest_pod() == null:
				_ctx = "rest"
				bed.begin("rest")
				await _play_until(func(): return hero.rest_pod() == null or String(gs.day_part()) == "day" or wm.is_wave_active,
					float(bed.time_of("rest")) + 20.0, "asleep in the pod")
				continue
			if not cabin.hero_inside:
				_main.order_enter_cabin()
			await _play_until(func(): return String(gs.day_part()) == "day" or wm.is_wave_active, 12.0, "in the cabin, the night out")
			continue
		var holes: int = 0
		_main.on_build_selected("wall")
		for cell in ring:
			if cell == gate_cell or gm.building_in_build_cell(cell) != null or _main.current_build_type == "":
				continue
			var at: Vector3 = gm.build_cell_to_world(cell)
			if _main.try_place_at_cell(gm.world_to_cell(at), at) != null:
				holes += 1
		_main.cancel_building_selection()
		if holes > 0:
			note.call("mending the ring: %d sections" % holes)
			_ctx = "build"
			await _play_until(func(): return _unfinished() == 0, 40.0, "mending the ring")
			continue
		# Wood first while there is not enough put by to mend the ring: the towers and their arrows eat
		# it as fast as it comes, and a bot that only quarried let the ring fall for want of a stake.
		if int(gs.resources.get("wood", 0)) < 8:
			await _chop_a_while(hero, "wood", 8.0)
		elif gs.has_unlock(pick_flag) and int(gs.resources.get("stone", 0)) < maxi(8, int(cfg.BUILDINGS[wanted_tower[0]]["cost"].get("stone", 0)) if not wanted_tower.is_empty() else 8):
			await _chop_a_while(hero, "stone", 12.0)
		else:
			await _chop_a_while(hero, "wood", 8.0)
	if gs.is_game_over:
		note.call("GAME OVER (cabin %.0f, hero %.1f)" % [cabin.current_hp if is_instance_valid(cabin) else 0.0, hero.current_hp])
	note.call(_play_status(hero, cabin, gs, wm))
	await _shoot("end")
	if is_instance_valid(cabin):
		await _portrait("end_above", cabin.global_position, 16.0, true)
	Engine.time_scale = 1.0
	note.call("played %.1f game minutes in %.0f s" % [_play_clock / 60.0, (Time.get_ticks_msec() - _play_t0) / 1000.0])
	_report(minutes)

# ==============================================================================
# The plan and the account (_scenario_play "play:<minutes>:<plan>")
# ==============================================================================

## The plan's words ("all", "bows", "-catapult" ...).
var _plan_words: PackedStringArray = PackedStringArray(["all"])

## Whether the plan has `thing` in it: everything but what it leaves out ("-thing"); with "bows", only the bow towers
## and their arrows -- no ring, no other tower, no fire -- and what any player does: a torch at night, the axe, a rest
## when hurt. The things -- every option a player has (GAME-DESIGN 3.0, 6.0): "ring" (the palisade), each tower by its
## kind ("bow", "drop", "thrower", "bait"), "spikes" (a strip of them before the line), "fire" (the campfires the towers
## see by at night), "torch", "axe", "pod", "fight" (going out to what is at the cabin), "upgrade" (the towers raised a
## level), "wallup" (the ring's north side turned to stone). And how he plays: "savvy" -- to v0.7's rules: a raid
## comes for the cabin and the man last, so one that is not near him he works through; the torch keeps the
## phytosaurs off, so with one he works the night (else he waits both out inside).
func _plan_has(thing: String) -> bool:
	if _plan_words.has("-" + thing):
		return false
	if _plan_words.has("bows"):
		return thing in ["bow", "torch", "axe", "pod", "fight"]
	return true

## The first tower standing that can be raised a level now (Building.can_upgrade) and paid for with the night's wood
## still put by (_fuel_reserve), or null.
func _tower_to_raise() -> Node:
	var gs := root.get_node("GameState")
	for t in get_nodes_in_group(AmmoTower.GROUP):
		if not is_instance_valid(t) or not t.is_constructed or not t.can_upgrade():
			continue
		var cost: Dictionary = t.upgrade_cost()
		if cost.is_empty() or not gs.knows_all(cost) or not gs.can_afford(cost):
			continue
		if int(gs.resources.get("wood", 0)) - int(cost.get("wood", 0)) < _fuel_reserve():
			continue
		return t
	return null

## The first section of the ring's north side (`ring`'s first row: the way the raids come) still timber that can be
## turned to stone with stone to spare -- some kept for the catapult's shot -- or null.
func _wall_to_stone(ring: Array[Vector2i]) -> Node:
	var gs := root.get_node("GameState")
	var gm = _main.grid_manager
	if ring.is_empty():
		return null
	var north: int = ring[0].y
	for cell in ring:
		if cell.y != north:
			continue
		var b = gm.building_in_build_cell(cell)
		if b == null or not is_instance_valid(b) or String(b.building_type) != "wall" or not b.can_upgrade("stone_wall"):
			continue
		var cost: Dictionary = b.upgrade_cost("stone_wall")
		if not gs.can_afford(cost) or int(gs.resources.get("stone", 0)) - int(cost.get("stone", 0)) < 6:
			return null
		return b
	return null

## `b` turned into `target` where it stands: paid for, and built onto by him (Hero.order_upgrade), the old building at
## work the while.
func _upgrade(hero: Node, b: Node, target: String, note: Callable) -> void:
	_ctx = "build"
	if not b.begin_upgrade(target):
		return
	note.call("raising the %s to a %s" % [String(b.building_type), target])
	var id: int = b.get_instance_id()
	hero.order_upgrade(b)
	await _play_until(func(): return not is_instance_id_valid(id) or not b.is_upgrading(), 60.0, "building an upgrade")

## What he is about this moment, for the account: "gather:wood", "craft:ammo", "build", "load", "raid", "drops",
## "wreck", "rest", "torch", "think" (the bot choosing what next).
var _ctx: String = "think"
var _ctx_time: Dictionary = {}
var _income: Dictionary = {}       # resource -> {where from -> how much}
var _spend: Dictionary = {}        # resource -> {what for -> how much}
var _last_res: Dictionary = {}
var _kills_by: Dictionary = {}     # what killed them (a tower's kind, "hero", "other") -> how many
var _raids_log: Array = []
var _raid_rec: Dictionary = {}
var _timber_at_start: int = 0

## Game seconds passed, counted against what he is about.
func _tick(seconds: float) -> void:
	_play_clock += seconds
	_ctx_time[_ctx] = float(_ctx_time.get(_ctx, 0.0)) + seconds

func _ledger_begin() -> void:
	_ctx = "think"
	_ctx_time.clear()
	_income.clear()
	_spend.clear()
	_kills_by.clear()
	_raids_log.clear()
	_raid_rec = {}
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	_last_res = gs.resources.duplicate()
	_timber_at_start = _timber_standing()
	for pair in [[eb.resources_changed, _on_res_changed], [eb.wave_started, _ledger_raid_began],
			[eb.dino_spawned, _ledger_came], [eb.dino_died, _ledger_died], [eb.building_destroyed, _ledger_lost],
			[eb.wave_ended, _ledger_raid_over]]:
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])

## A raid set out: its line in the account opened.
func _ledger_raid_began(n: int, big: bool) -> void:
	var gs := root.get_node("GameState")
	var cabin = _main.current_core
	_raid_rec = {"n": n, "big": big, "day": int(gs.day_number()), "at": snappedf(_play_clock, 0.1),
		"came": {}, "killed_by": {}, "lost": {},
		"cabin_before": snappedf(float(cabin.current_hp), 0.1) if is_instance_valid(cabin) else 0.0}

## An animal come on the field during the raid: who came.
func _ledger_came(d: Node) -> void:
	if _raid_rec.is_empty() or not is_instance_valid(d):
		return
	var came: Dictionary = _raid_rec["came"]
	came[String(d.dino_type)] = int(came.get(String(d.dino_type), 0)) + 1

## An animal killed: by what.
func _ledger_died(d: Node) -> void:
	var by: String = _killer_of(d)
	_kills_by[by] = int(_kills_by.get(by, 0)) + 1
	if not _raid_rec.is_empty():
		var kb: Dictionary = _raid_rec["killed_by"]
		kb[by] = int(kb.get(by, 0)) + 1

## A building brought down in the raid (not one he pulled down: it has hit points left).
func _ledger_lost(b: Node) -> void:
	if _raid_rec.is_empty() or not is_instance_valid(b) or not ("building_type" in b) or float(b.get("current_hp")) > 0.0:
		return
	var lost: Dictionary = _raid_rec["lost"]
	lost[String(b.building_type)] = int(lost.get(String(b.building_type), 0)) + 1

## The raid over: the cabin as it left it, and the line closed.
func _ledger_raid_over(_n: int) -> void:
	if _raid_rec.is_empty():
		return
	var cabin = _main.current_core
	_raid_rec["cabin_after"] = snappedf(float(cabin.current_hp), 0.1) if is_instance_valid(cabin) else 0.0
	_raid_rec["ended"] = snappedf(_play_clock, 0.1)
	_raids_log.append(_raid_rec)
	_raid_rec = {}

## What came in and what went out, by what he was about as it did.
func _on_res_changed(res: Dictionary) -> void:
	var cfg := root.get_node("Config")
	for k in res:
		var d: int = int(res[k]) - int(_last_res.get(k, 0))
		if d > 0:
			var from: String = "made" if _ctx.begins_with("craft") else ("gather" if _ctx.begins_with("gather") else _ctx)
			_book(_income, String(k), from, d)
		elif d < 0:
			var for_what: String = _ctx
			if _ctx.begins_with("craft:"):
				for_what = _ctx.substr(6)
			elif cfg.AMMO.has(String(k)):
				for_what = "loaded"
			elif _ctx in ["think", "raid", "drops", "gather:wood", "gather:stone", "wreck"]:
				for_what = "fires & the rest"
			_book(_spend, String(k), for_what, -d)
	_last_res = res.duplicate()

func _book(into: Dictionary, res_id: String, key: String, amount: int) -> void:
	if not into.has(res_id):
		into[res_id] = {}
	into[res_id][key] = int(into[res_id].get(key, 0)) + amount

## What killed `d`: the tower that shot it lately (its kind), him if he was at it, or "other" (the spikes, fire).
func _killer_of(d: Node) -> String:
	if d == null or not is_instance_valid(d):
		return "other"
	var cfg := root.get_node("Config")
	var by = d.get("_shot_by")
	if by != null and is_instance_valid(by) and "building_type" in by \
			and float(d.get("_mind_clock")) - float(d.get("_shot_at")) <= 4.0:
		return String(cfg.BUILDINGS.get(String(by.building_type), {}).get("kind", by.building_type))
	var hero = _main.hero if _main != null else null
	if hero != null and is_instance_valid(hero) and hero.get("target_enemy") == d:
		return "hero"
	return "other"

## The timber still standing in the valley: what is left in its trees.
func _timber_standing() -> int:
	var n: int = 0
	for node in get_nodes_in_group("resource_nodes"):
		if is_instance_valid(node) and String(node.resource_type) == "wood":
			n += int(node.current_amount)
	return n

## What a job at a bench is, for the account: the beacon, a rest, ammunition (a recipe that makes some), a tool.
func _job_kind(bench_id: String, job: String) -> String:
	var cfg := root.get_node("Config")
	if bench_id == String(cfg.BEACON_STATION):
		return "beacon"
	if bench_id == HealingPod.STATION:
		return "rest"
	if cfg.RECIPES.get(job, {}).has("makes"):
		return "ammo"
	return "tools"

## The run's account, as one line of JSON (the comparisons are made from these).
func _report(minutes: float) -> void:
	var gs := root.get_node("GameState")
	var cabin = _main.current_core if _main != null else null
	var hero = _main.hero if _main != null else null
	var result: String = "running"
	if gs.is_game_over:
		result = "won" if bool(gs.is_game_won) else "lost"
	if not _raid_rec.is_empty():
		_raids_log.append(_raid_rec)
	var report: Dictionary = {
		"plan": ",".join(_plan_words), "seed": _seed, "map": String(gs.map_id), "minutes": minutes,
		"played": snappedf(_play_clock / 60.0, 0.1), "result": result, "lost_to": String(gs.get("lost_to")),
		"cabin": snappedf(float(cabin.current_hp), 0.1) if (cabin != null and is_instance_valid(cabin)) else 0.0,
		"hero_alive": hero != null and is_instance_valid(hero) and float(hero.current_hp) > 0.0,
		"beacon_steps": int(gs.beacon_steps), "beacon_charge": snappedf(float(gs.beacon_charge_ratio()), 0.01),
		"day": int(gs.day_number()) if gs.has_method("day_number") else 0,
		"time": _ctx_time, "income": _income, "spend": _spend, "stock": gs.resources,
		"timber": [_timber_at_start, _timber_standing()], "kills_by": _kills_by, "raids": _raids_log,
	}
	print("[report] " + JSON.stringify(report))

var _play_log: Array = []
var _play_t0: int = 0
## Game seconds played, raids included (WaveManager.elapsed_time stands still during a raid).
var _play_clock: float = 0.0

## Whether plan step `what` can be done now.
func _can_do(what: String, cabin: Node, gs: Node) -> bool:
	match what:
		"pick":
			return cabin.station("workbench").can_afford("stone_pick")
		"axe":
			return cabin.station("workbench").can_afford("stone_axe")
		"rest":
			var pod = cabin.station(HealingPod.STATION)
			return pod != null and pod.can_offer(HealingPod.REST)
		"stone":
			return gs.has_unlock(String(root.get_node("Config").RECIPES["stone_pick"]["unlocks"]))
		"tower":
			return gs.can_afford(root.get_node("Config").BUILDINGS["bow_tower"]["cost"])
		"beacon":
			var job: String = String(gs.beacon_next_job())
			return job != "" and cabin.station(String(root.get_node("Config").BEACON_STATION)).can_afford(job)
	return true

## The ammunition job a standing tower wants made (AmmoTower): the kind it is set to -- or the first of its kinds
## the workbench can make -- while the stock holds less than it has room for and the workbench can make it now.
func _ammo_wanted(wb: Node) -> String:
	var gs := root.get_node("GameState")
	for t in get_nodes_in_group(AmmoTower.GROUP):
		if not is_instance_valid(t) or not t.is_constructed or t.room() <= 0:
			continue
		var kinds: Array = [String(t.ammo_type)] if String(t.ammo_type) != "" else t.accepts()
		for kind in kinds:
			if int(gs.resources.get(kind, 0)) < t.room() and wb.can_offer(kind) and wb.can_afford(kind):
				return String(kind)
	return ""

## A standing tower that loading would fill from the stock now, or null -- `lit_only`, only one a fire's light is on.
func _tower_wanting_load(lit_only: bool = false) -> Node:
	for t in get_nodes_in_group(AmmoTower.GROUP):
		if is_instance_valid(t) and t.wants_load() and (not lit_only or _lit((t as Node3D).global_position)):
			return t
	return null

## Whether a light is on `at` (ProwlerDino.lights: a burning fire, the burning ground, his torch).
func _lit(at: Vector3) -> bool:
	return not ProwlerDino.light_over(self, at).is_empty()

## The wood tonight's fires take from the stock as they light (Fire.fuel_cost), every standing fire's.
func _fuel_reserve() -> int:
	var n: int = 0
	for b in _main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and b.has_method("fuel_cost") and bool(b.get("is_constructed")):
			n += int(b.fuel_cost().get("wood", 0))
	return n

## Out through the gate for what the raid left, and back.
func _gather_drops(hero: Node, note: Callable) -> void:
	var gs := root.get_node("GameState")
	var before: Dictionary = gs.resources.duplicate()
	for d in get_nodes_in_group(DropItem.GROUP):
		if not is_instance_valid(d):
			continue
		var id: int = d.get_instance_id()
		hero.move_to((d as Node3D).global_position)
		await _play_until(func(): return not is_instance_id_valid(id), 20.0, "gathering a drop")
	var got: Dictionary = {}
	for k in gs.resources:
		if int(gs.resources[k]) != int(before.get(k, 0)):
			got[k] = int(gs.resources[k]) - int(before.get(k, 0))
	note.call("gathered after the raid: %s" % str(got))

## Lets the game run until `done` says so or `seconds` of game time pass; says so if it gave up,
## and if the Hero stood still the whole while with an order in hand.
func _play_until(done: Callable, seconds: float, what: String) -> bool:
	var wm = _main.wave_manager
	var start: float = wm.elapsed_time
	var hero = _main.hero
	var was: Vector3 = hero.global_position
	var still: float = 0.0
	var warned: bool = false
	var start_clock: float = _play_clock
	while _play_clock - start_clock < seconds:
		if done.call():
			return true
		await _advance(0.25)
		_tick(0.25 * Engine.time_scale)
		# Out in the dark he carries a torch, as a player does: the night's hunters are out for a man without
		# one (GAME-DESIGN 9.3). Without, the bot was bitten to death on the small valley's first night, run
		# after run (the debug-agent's note of 2026-09-29).
		if not _no_torch and _plan_has("torch") and hero.has_method("can_light_torch") and hero.can_light_torch() \
				and not bool(_main.current_core.is_inside(hero.global_position)):
			var was_ctx: String = _ctx
			_ctx = "torch"
			if hero.light_torch():
				print("[play %5.1fs] lit a torch, out in the dark while %s" % [_play_clock, what])
			_ctx = was_ctx
		var moved: float = hero.global_position.distance_to(was)
		was = hero.global_position
		if int(hero.current_state) == 1 and moved < 0.02:
			still += 0.25 * Engine.time_scale
			if still > 4.0 and not warned:
				warned = true
				print("[play %5.1fs] STUCK? he has been walking on the spot for 4s while %s, at %s" % [_play_clock, what, str(hero.global_position)])
		else:
			still = 0.0
		if root.get_node("GameState").is_game_over:
			return false
	if not what.begins_with("working"):
		print("[play %5.1fs] gave up %s after %.0fs" % [_play_clock, what, seconds])
	return false

## The nearest node of `res_id` he can work, worked for `seconds` of game time.
func _chop_a_while(hero: Node, res_id: String, seconds: float) -> void:
	var best: Node = null
	var best_d: float = INF
	for n in get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(n) or String(n.resource_type) != res_id or int(n.current_amount) <= 0:
			continue
		if not hero.can_harvest(n) or _guarded(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(hero.global_position)
		if d < best_d:
			best_d = d
			best = n
	_ctx = "gather:" + res_id
	if best == null:
		print("[play] nothing of %s he can work" % res_id)
		await _advance(seconds / Engine.time_scale)
		_tick(seconds)
		return
	hero.order_harvest(best)
	var wm = _main.wave_manager
	# Savvy, he works on through a raid till something comes near him (_scenario_play); else he stops for it.
	if _plan_words.has("savvy"):
		await _play_until(func(): return _nearest_dino(hero, 8.0) != null or hero.current_hp < hero.max_hp * 0.6, seconds,
			"working %s" % res_id)
		return
	await _play_until(func(): return wm.is_wave_active or wm.raid_timer < 6.0, seconds, "working %s" % res_id)

## The wreck holding the part `job` (a beacon stage) still lacks, when that is all it lacks and the
## wreck can be worked now (not searched, not guarded); null otherwise.
func _wreck_to_search(job: String) -> Node:
	var cfg = root.get_node("Config")
	var gs = root.get_node("GameState")
	if job == "":
		return null
	var inputs: Dictionary = cfg.beacon_job(gs.map_data(), job).get("inputs", {})
	var part: String = ""
	for res_id in inputs:
		var short: bool = int(gs.resources.get(res_id, 0)) < int(inputs[res_id])
		if cfg.is_part(String(res_id)):
			if short:
				part = String(res_id)
		elif short:
			return null
	if part == "":
		return null
	for n in get_nodes_in_group("resource_nodes"):
		if is_instance_valid(n) and String(n.resource_type) == part and int(n.current_amount) > 0 and not _guarded(n) \
				and (_plan_words.has("guarded") or not _draws_guards(n)):
			return n
	return null

## Whether working `n` wakes a nest's guards (Config.RESOURCE_NODES.<type>.din.draws): the battery's wreck, behind the
## nest. The bot goes there only when its plan says "guarded": woken, they dash at him, and a bot that went was bitten
## to death there, run after run (v0.7 bench) -- the rest of the run's account lost with him.
func _draws_guards(n: Node) -> bool:
	var cfg = root.get_node("Config")
	return String(cfg.RESOURCE_NODES.get(String(n.resource_type), {}).get("din", {}).get("draws", "")) == "guards"

## The first bow tower north of the cabin, its arrows made and carried over: wood chopped for it first if the stock
## is short, and all of it before the first raid if it can be.
func _first_tower(hero: Node, cabin: Node, note: Callable, minutes: float) -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var gm = _main.grid_manager
	var wm = _main.wave_manager
	var c0: Vector2i = gm.world_to_build_cell(cabin.global_position)
	var h0 := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
	var at: Vector2i = c0 + Vector2i(-4, -h0.y - 3)
	var cost: Dictionary = cfg.BUILDINGS["bow_tower"]["cost"]
	while not gs.can_afford(cost) and _play_clock < minutes * 60.0 and not gs.is_game_over:
		await _chop_a_while(hero, "wood", 8.0)
		if wm.is_wave_active:
			return
	_ctx = "build"
	_main.on_build_selected("bow_tower")
	var pos: Vector3 = gm.build_cell_to_world(at)
	var b = _main.try_place_at_cell(gm.world_to_cell(pos), pos)
	_main.cancel_building_selection()
	note.call("the first bow_tower ordered at %s: %s" % [str(at), "yes" if b else "NO"])
	if b == null:
		return
	await _play_until(func(): return _unfinished() == 0, 40.0, "building the first tower")
	var arrows: String = _ammo_wanted(cabin.station("workbench"))
	if arrows != "":
		await _bench_job(hero, cabin, "workbench", arrows, note)
	var empty: Node = _tower_wanting_load()
	if empty != null:
		var id: int = empty.get_instance_id()
		_ctx = "load"
		hero.order_load(empty)
		note.call("loading the first tower")
		await _play_until(func(): return not is_instance_id_valid(id) or not empty.wants_load(), 30.0, "loading the first tower")

## Out to the wreck `node` and through it, till its part is in the stock -- or a raid is coming. What its din
## brings (Din) he does not stand and fight bare-handed: he goes in and waits for it to give up -- one brought
## out of its hours goes back once he is out of its reach -- and comes back to the wreck, as a player learns
## to. Standing, the bot was bitten to death at the river's antenna on its first day.
func _search_wreck(hero: Node, node: Node) -> void:
	# The nest's wreck he goes to in the dark without a torch, as a player learns to: its light wakes the
	# guards (NEST_GUARDS), and since 2026-10-02 they dash at a man close by (DINO_AI.bursts) -- the bot went
	# with its torch lit and was dead in three seconds, run after run.
	var cfg = root.get_node("Config")
	_no_torch = String(cfg.RESOURCE_NODES.get(String(node.resource_type), {}).get("din", {}).get("draws", "")) == "guards"
	if _no_torch and hero.has_method("put_out_torch"):
		hero.put_out_torch()
	await _search_wreck_through(hero, node)
	_no_torch = false

## Whether he keeps his torch out for now (_search_wreck).
var _no_torch: bool = false

func _search_wreck_through(hero: Node, node: Node) -> void:
	var gs = root.get_node("GameState")
	var wm = _main.wave_manager
	var part: String = String(node.resource_type)
	var over := func() -> bool: return int(gs.resources.get(part, 0)) > 0 or wm.is_wave_active or wm.raid_timer < 6.0
	for turn in 4:
		if gs.is_game_over or not is_instance_valid(node):
			return
		hero.order_harvest(node)
		await _play_until(func(): return over.call() or _drawn_near(hero, 12.0) != null, 90.0,
			"searching the wreck for the %s" % part)
		var drawn: Node = _drawn_near(hero, 12.0) if not gs.is_game_over else null
		if over.call() or drawn == null:
			return
		# Said once for each that came, not at every look round (the debug-agent's TASK-028: seven lines, one
		# phytosaur).
		if not _din_said.has(drawn.get_instance_id()):
			_din_said[drawn.get_instance_id()] = true
			print("[play %5.1fs] the wreck's din brought a %s: in, till it goes" % [_play_clock, String(drawn.get("dino_type"))])
		# One that came up out of the river or in from the edge he fights, as a player would -- hiding in
		# the cabin waited it out only while the cabin's gun shot what followed him there (it has none
		# since 2026-10-02). A nest's guards, woken, come all together: he runs for the cabin from them,
		# and from anything once hurt.
		if hero.current_hp >= hero.max_hp * 0.35 and not drawn.is_in_group("guard_dinos"):
			hero.order_attack(drawn)
			await _play_until(func(): return gs.is_game_over or not is_instance_valid(drawn) or bool(drawn.get("is_dead")) \
				or hero.current_hp < hero.max_hp * 0.35, 30.0, "fighting what the din brought")
			continue
		_main.order_enter_cabin()
		# (The run lost while he waits, the cabin may be gone: asked of what is still there.)
		await _play_until(func():
			var core = _main.current_core
			return gs.is_game_over or (core != null and is_instance_valid(core) and core.hero_inside 				and _drawn_near(core, 12.0) == null), 60.0, "in the cabin, waiting out the din")

## The animals a wreck's din brought that the log has named.
var _din_said: Dictionary = {}

## Whether he has gone in for this raid (the raid's step of _scenario_play): ordered in once, not every second.
var _sheltering: bool = false

## Puts up `plan` ([type, build cell]) and waits for it to stand; a cell that refuses it is remembered in `refused`.
func _raise(plan: Array, refused: Dictionary, note: Callable) -> void:
	var gm = _main.grid_manager
	_ctx = "build"
	_main.on_build_selected(String(plan[0]))
	_main._placement_facing = 0
	var at: Vector3 = gm.build_cell_to_world(plan[1])
	var b = _main.try_place_at_cell(gm.world_to_cell(at), at)
	_main.cancel_building_selection()
	note.call("%s ordered at %s: %s" % [plan[0], str(plan[1]), "yes" if b else "NO"])
	if b == null:
		refused[plan[1]] = true
	await _play_until(func(): return _unfinished() == 0, 40.0, "building a tower")

## The nearest living frightened charger (ChargerDino) within `radius` of the cabin, not running from a fire; or null.
func _charger_at(cabin: Node, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d: float = radius
	for d in get_nodes_in_group("dinos"):
		if not (d is ChargerDino) or not is_instance_valid(d) or bool(d.get("is_dead")) or bool(d.get("going_home")):
			continue
		var dist: float = (d as Node3D).global_position.distance_to((cabin as Node3D).global_position)
		if dist <= best_d:
			best_d = dist
			best = d
	return best

## How many living animals are within `radius` of `at` (it among them).
func _dinos_round(at: Node3D, radius: float) -> int:
	var n: int = 0
	for d in get_nodes_in_group("dinos"):
		if d is Node3D and is_instance_valid(d) and not bool(d.get("is_dead")) \
				and (d as Node3D).global_position.distance_to(at.global_position) <= radius:
			n += 1
	return n

## A living animal a wreck's din brought (Din.GROUP_DRAWN) within `radius` of `at`, or null.
func _drawn_near(at: Node, radius: float) -> Node:
	for d in get_nodes_in_group(Din.GROUP_DRAWN):
		if is_instance_valid(d) and not bool(d.get("is_dead")) \
				and (d as Node3D).global_position.distance_to((at as Node3D).global_position) <= radius:
			return d
	return null

## Whether a nest's guards are awake and near enough `n` to go for him there -- the bot leaves the
## nest's stones be while they are, as a player does once warned: it went on quarrying through their
## warning and was bitten to death, and a long run ended at 3:47 (the debug-agent, 7f8ee65).
func _guarded(n: Node) -> bool:
	var cfg = root.get_node("Config")
	var gs = root.get_node("GameState")
	var guards: Dictionary = cfg.NEST_GUARDS
	var reach: float = float(guards.get("aggro_radius", 6.0)) + float(guards.get("post_radius", 3.0)) + 1.0
	for g in get_nodes_in_group("guard_dinos"):
		if not is_instance_valid(g) or bool(g.get("is_dead")):
			continue
		if not cfg.keeps_hours(String(g.get("dino_type")), String(gs.day_part())):
			continue
		var post: Vector3 = g.post_position if "post_position" in g else (g as Node3D).global_position
		if post.distance_to((n as Node3D).global_position) <= reach:
			return true
	return false

## Walks in, to the bench, starts `job` and stays till it is done.
## The nearest living raider within `radius` of him, wall or no wall: what a player would click.
func _nearest_dino(hero: Node, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d: float = radius
	for d in get_nodes_in_group("dinos"):
		if d is Node3D and hero._is_enemy_valid(d):
			var dist: float = (hero as Node3D).global_position.distance_to((d as Node3D).global_position)
			if dist <= best_d:
				best_d = dist
				best = d
	return best

func _bench_job(hero: Node, cabin: Node, bench_id: String, job: String, note: Callable) -> void:
	var bench = cabin.station(bench_id)
	if bench == null or job == "":
		note.call("no %s job %s" % [bench_id, job])
		return
	if not bench.can_afford(job):
		note.call("cannot afford %s at the %s (%s)" % [job, bench_id, str(root.get_node("GameState").resources)])
		return
	_ctx = "craft:" + _job_kind(bench_id, job)
	_main._walk_to_bench(bench)
	await _play_until(func(): return cabin.hero_inside and int(hero.current_state) == 0, 40.0, "walking to the %s" % bench_id)
	if not cabin.hero_inside:
		note.call("did not get into the cabin for the %s" % bench_id)
		return
	var began: bool = bench.begin(job)
	note.call("%s at the %s: %s" % [job, bench_id, "begun" if began else "REFUSED"])
	await _play_until(func(): return String(bench.active_recipe) == "", float(bench.time_of(job)) + 5.0, "working at the %s" % bench_id)

func _unfinished() -> int:
	var n: int = 0
	for b in _main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and "is_constructed" in b and not b.is_constructed:
			n += 1
	return n

func _cellstr(p: Vector3, gm: Node) -> String:
	return str(gm.world_to_build_cell(p))

func _play_status(hero: Node, cabin: Variant, gs: Node, wm: Node) -> String:
	if cabin == null or not is_instance_valid(cabin):
		return "the cabin is gone"
	var dinos: int = get_nodes_in_group("dinos").size()
	var walls: int = 0
	for b in _main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and "building_type" in b and String(b.building_type) != "core":
			walls += 1
	return "hero %s hp %.1f/%.0f at %s | cabin %.0f/%.0f | %d buildings | %d dinos | %s | next raid %.0fs" % [
		["idle", "moving", "building", "attacking", "DEAD", "harvesting", "resting"][int(hero.current_state)],
		hero.current_hp, hero.max_hp, _cellstr(hero.global_position, _main.grid_manager),
		cabin.current_hp, cabin.max_hp, walls, dinos, str(gs.resources), wm.raid_timer]

## The ghost is what goes up (v0.6 round three: "pending的样子就是造下去的样子"): a line of palisade
## with a ghost at its end, turning the corner -- the end section shown already turned to meet it;
## a run dragged down from the other end; a row laid along the cabin's side, straight, not reaching
## for the cabin; and a lone section on open ground, straight along the way it faces, not an X.
func _scenario_ghost() -> void:
	_grant({"wood": 400})
	var gm = _main.grid_manager
	var centre: Vector3 = _main.current_core.global_position
	var c: Vector2i = gm.world_to_build_cell(centre)
	var half: int = int(root.get_node("Config").get_building_cells("core")) / 2
	# Along the cabin's east side, a cell out: straight, north to south.
	for dz in range(-half, half + 1):
		_build_at("wall", gm.build_cell_to_world(c + Vector2i(half + 1, dz)), 1)
	# A line along X, south of the cabin.
	var z0: int = c.y + half + 5
	for x in range(c.x - 6, c.x - 1):
		_build_at("wall", gm.build_cell_to_world(Vector2i(x, z0)), 0)
	# A lone section, turned.
	_build_at("wall", gm.build_cell_to_world(Vector2i(c.x + 2, z0)), 1)
	await _wait(6)
	_main.on_build_selected("wall")
	_main._placement_facing = 0
	var corner: Vector2i = Vector2i(c.x - 2, z0 + 1)
	_main._update_build_preview(_main.camera.unproject_position(gm.build_cell_to_world(corner)))
	await _wait(4)
	await _portrait("ghost_corner", gm.build_cell_to_world(Vector2i(c.x - 2, z0 + 1)), 7.0, true)
	# A run dragged south from the line's west end.
	_main.build_preview.visible = false
	_main._restore_neighbours()
	var run: Array[Vector2i] = []
	for dz in range(1, 5):
		run.append(Vector2i(c.x - 6, z0 + dz))
	_main._drag_from = run[0]
	_main._dragging = true
	_main._show_run_preview(run)
	await _wait(4)
	await _portrait("ghost_run", gm.build_cell_to_world(Vector2i(c.x - 4, z0 + 2)), 8.0, true)
	_main._end_drag()
	# A run longer than the stock stretches: the sections past it red, and said (v0.6 round six).
	var cost: Dictionary = root.get_node("Config").BUILDINGS["wall"]["cost"]
	for res_id in cost:
		root.get_node("GameState").resources[res_id] = int(cost[res_id]) * 2
	var long_run: Array[Vector2i] = []
	for dz in range(1, 7):
		long_run.append(Vector2i(c.x - 9, z0 + dz))
	_main._drag_from = long_run[0]
	_main._dragging = true
	_main._show_run_preview(long_run)
	await _wait(4)
	await _portrait("ghost_short", gm.build_cell_to_world(Vector2i(c.x - 9, z0 + 3)), 9.0, true)
	# Let go with red in it -- as a release does it, the drag ended first: none of it goes down, and the hint
	# says how much is short (v0.6 round seven: "我要的效果是all or nothing").
	_main._end_drag()
	_main._commit_run(long_run)
	await _wait(4)
	await _shoot("run_refused")
	# A strip of spikes, dragged out as a fence is (v0.6 round seven: "地刺这种也可以连续建造"), past the stock.
	var spike_cost: Dictionary = root.get_node("Config").BUILDINGS["ground_spikes"]["cost"]
	for res_id in spike_cost:
		root.get_node("GameState").resources[res_id] = int(spike_cost[res_id]) * 4
	_main.on_build_selected("ground_spikes")
	var strip: Array[Vector2i] = []
	for dz in range(1, 7):
		strip.append(Vector2i(c.x - 12, z0 + dz))
	_main._drag_from = strip[0]
	_main._dragging = true
	_main._show_run_preview(strip)
	await _wait(4)
	await _portrait("spikes_run", gm.build_cell_to_world(Vector2i(c.x - 12, z0 + 3)), 9.0, true)
	_main._end_drag()
	_main.cancel_building_selection()
	await _wait(4)
	await _portrait("cabin_side", centre + Vector3(1.0, 0.0, 0.0), 8.0, true)

## The healing pod (GAME-DESIGN 3.0: "泡营养液式的身体完全恢复"): him hurt, his Rest command come into the corner; the
## pod's card and its one job; him in it, floating in the fluid, the room's other benches idle; whole again, out in
## front of it.
func _scenario_pod() -> void:
	var hero = _main.hero
	var core = _main.current_core
	var eb := root.get_node_or_null("EventBus")
	if hero == null or core == null:
		return
	hero.set_physics_process(true)
	hero.current_hp = hero.max_hp * 0.4
	if eb:
		eb.hero_hp_changed.emit(hero.current_hp, hero.max_hp)
	await _wait(8)
	await _shoot("rest_command")
	await _walk_in()
	var pod: Node = core.station(HealingPod.STATION)
	if pod == null:
		print("[playtest] no pod in the cabin")
		return
	if eb:
		eb.unit_selected.emit(pod)
	await _wait(8)
	await _shoot("pod_card")
	pod.begin(HealingPod.REST)
	for i in range(600):
		await physics_frame
		if hero.is_resting():
			break
	await _advance(1.0)
	await _shoot("in_the_pod")
	await _portrait("in_the_pod_close", (pod as Node3D).global_position, 4.0, true)
	for i in range(60 * 40):
		await physics_frame
		if not hero.is_resting():
			break
	await _advance(1.5)
	await _shoot("whole_again")

## The buildings side by side, south of the cabin where nothing else stands: a run of a palisade, a run of bone
## palisade, a stone wall, and in front of the line the four towers (one set on one plinth, GAME-DESIGN 3.0), loaded,
## one bow tower upgraded where it stands -- and then a bow tower's card, its ammunition and its bigger store.
func _scenario_buildings() -> void:
	var cfg := root.get_node_or_null("Config")
	var eb := root.get_node_or_null("EventBus")
	_grant({"wood": 400, "stone": 400, "bone": 400})
	var step: float = float(cfg.BUILD_CELL)
	var z: float = 6.0
	# A palisade with a corner and a gate in it, flush against the next thing along: bone
	# stakes, then a stone wall -- and a turret right up against the line (v0.6 round two: the
	# walls fill their cells and join whatever is beside them).
	for i in range(6):
		_build_at("wall", Vector3(-7.0 + float(i) * step, 0.0, z))
	for i in range(1, 3):
		_build_at("wall", Vector3(-7.0, 0.0, z - float(i) * step))
	_build_at("gate", Vector3(-1.0, 0.0, z))
	for i in range(3):
		_build_at("bone_stake", Vector3(0.0 + float(i) * step, 0.0, z))
	for i in range(3):
		_build_at("stone_wall", Vector3(3.0 + float(i) * step, 0.0, z))
	# In front of the line, the four of the set side by side on their one plinth.
	var towers: Array = [
		_build_at("bow_tower", Vector3(-6.0, 0.0, z + 3.0 * step)),
		_build_at("drop_tower", Vector3(-2.0, 0.0, z + 3.0 * step)),
		_build_at("bait_rack", Vector3(2.0, 0.0, z + 3.0 * step)),
		_build_at("catapult", Vector3(6.0, 0.0, z + 3.0 * step)),
		_build_at("bow_tower", Vector3(-10.0, 0.0, z + 3.0 * step)),
	]
	_grant({"arrow_wood": 200, "log_round": 200, "shot_stone": 200, "food": 20})
	for t in towers:
		if t != null and t.has_method("load_from_stock"):
			t.load_from_stock()
	var upgraded = towers[4]
	if upgraded and upgraded.has_method("begin_upgrade") and upgraded.begin_upgrade():
		upgraded.add_upgrade_progress(1000.0)
	await _wait(10)
	await _portrait("the_line", Vector3(-1.0, 0.0, z + 2.0), 13.0)
	await _portrait("the_line_from_above", Vector3(-1.0, 0.0, z + 1.0), 13.0, true)
	var plain = towers[0]
	if plain and eb:
		eb.unit_selected.emit(plain)
	await _shoot("upgrade_offered")

## A tower's card, its ammunition (OptionPanel._add_ammo_choice; the player, 2026-10-03: "弹夹，装填是新系统，不能做的这么
## 粗糙"): a bow tower empty with wooden arrows in the stock and no bone ones; Load pressed, he on his way; loaded; and
## the drop tower's and the catapult's cards, their reach shown in blue as they are picked.
func _scenario_ammocard() -> void:
	var eb := root.get_node_or_null("EventBus")
	var gs := root.get_node("GameState")
	_grant({"wood": 200, "stone": 200, "bone": 1})
	var at: Vector3 = _main.current_core.global_position
	var bow = _build_at("bow_tower", at + Vector3(-5.0, 0.0, 6.0))
	var logs = _build_at("drop_tower", at + Vector3(0.0, 0.0, 7.0))
	var cat = _build_at("catapult", at + Vector3(7.0, 0.0, 8.0))
	_grant({"arrow_wood": 34, "log_round": 40, "shot_stone": 20})
	gs.resources["arrow_bone"] = 0
	if gs.has_method("knows") and "known" in gs:
		gs.known["arrow_bone"] = true
	if logs:
		logs.load_from_stock()
	if cat:
		cat.load_from_stock()
	await _wait(6)
	if bow and eb:
		eb.unit_selected.emit(bow)
	await _wait(6)
	await _shoot("bow_empty")
	var panel = _main.hud.option_panel
	var load_btn: Button = panel.button_container.find_child("LoadCommand", true, false) as Button
	if load_btn:
		load_btn.pressed.emit()
	await _advance(0.3)
	await _shoot("bow_going")
	if bow:
		bow.load_from_stock()
		for i in 7:
			bow.take_use()
	await _wait(6)
	await _shoot("bow_loaded")
	if logs and eb:
		eb.unit_selected.emit(logs)
		_look_at(logs.global_position)
	await _wait(6)
	await _shoot("drop_tower")
	if cat and eb:
		eb.unit_selected.emit(cat)
		_look_at(cat.global_position)
	await _wait(6)
	await _shoot("catapult")

## The game's own camera turned on `at` (its rig's focus), as the player's view would be.
func _look_at(at: Vector3) -> void:
	var rig: Object = _main.camera_rig if "camera_rig" in _main else null
	if rig == null:
		return
	rig.focus = at
	if "camera" in _main and _main.camera != null:
		rig.apply_to(_main.camera)

## A fire pot thrown (station 2: AMMO.fire_pot, FirePatch): a catapult south of the cabin, loaded with them, a raptor
## within its throw at dusk -- the pot in the air, and the ground burning where it broke.
func _scenario_firepot() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	gs.day_clock = float(cfg.DAY["light"][6]["at"]) if cfg.DAY["light"].size() > 6 else gs.day_clock
	_grant({"fire_pot": 40, "wood": 100, "stone": 100})
	var at: Vector3 = _main.current_core.global_position + Vector3(0.0, 0.0, 8.0)
	var cat = _build_at("catapult", at)
	if cat == null:
		print("[playtest] no room for the catapult")
		return
	cat.set_ammo("fire_pot")
	cat.load_from_stock()
	# Where it will throw: south, between too near and as far as it throws.
	var spot: Vector3 = cat.global_position + Vector3(0.0, 0.0, (cat.min_reach() + cat.reach()) * 0.5)
	# A campfire beside the spot, to judge the burning ground against the fire everybody knows.
	_build_at("campfire", spot + Vector3(-4.0, 0.0, 0.0))
	var d = load(String(cfg.get_dino_script_path("raptor"))).new()
	_main.dinos_container.add_child(d)
	d.setup("raptor")
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = spot
	d.set_physics_process(false)
	var fog = _main.get("fog")
	if fog != null and is_instance_valid(fog):
		fog.revealed = true
		fog._paint(1.0)
		fog._hide_the_unseen()
	# The pot in the air, burning: waited for until the catapult lets go, and looked at a third of the way over.
	var pot: Node3D = null
	for i in 80:
		for c in cat.get_parent().get_children():
			if c is Projectile:
				pot = c
		if pot != null:
			break
		await _advance(0.1)
	if pot == null:
		print("[playtest] the catapult never threw")
	else:
		await _advance(float(cfg.BUILDINGS["catapult"].get("flight_seconds", 1.2)) * 0.3)
	var seen: Vector3 = pot.global_position if (pot != null and is_instance_valid(pot)) else cat.global_position
	await _portrait("fire_pot_flight", seen, 5.0)
	await _advance(1.2)
	await _portrait("fire_patch", spot, 7.0)
	await _advance(2.0)
	await _portrait("fire_patch_burning", spot, 7.0)

## The jump between our game's stations (StationJump, v0.7), beat by beat: the first station won, the view swinging
## in, the beacon's light, the white and the card -- then the second station's level (built here by hand: the game's
## own scene is built afresh by the jump) and the capsule coming down onto it, and the run begun.
func _scenario_jump() -> void:
	var gs := root.get_node("GameState")
	gs.play("campaign")
	_tear_down()
	await _fresh_level()
	await _shoot("before")
	_main.station_jump.depart(_main)
	await _advance(1.2)
	await _shoot("view_in")
	await _advance(1.4)
	await _shoot("beam")
	await _advance(1.0)
	await _shoot("lift")
	await _advance(1.4)
	await _shoot("card")
	await _advance(3.0)
	print("[playtest] after the jump: station %d, map %s" % [int(gs.station), String(gs.map_id)])
	_tear_down()
	await _fresh_level()
	print("[playtest] the level built for it: map %s" % String(gs.map_id))
	_main.station_jump.arrive(_main)
	await _wait(3)
	await _shoot("arrive_card")
	await _advance(3.4)
	await _shoot("falling")
	await _advance(1.0)
	await _shoot("landed")
	await _advance(2.0)
	await _shoot("begun")
	await _portrait("morrison_from_above", _main.current_core.global_position, 30.0, true)
	gs.game = {}
	gs.station = 0

## The opening (StationJump.crash; v0.7, GAME-DESIGN 3.0), beat by beat: the capsule high over its spot, burning; on
## its way down; the blow; the dust; the valley answering; the run begun.
func _scenario_crash() -> void:
	_main.station_jump.crash(_main)
	await _wait(3)
	await _shoot("high")
	await _advance(1.3)
	await _shoot("falling")
	await _advance(0.8)
	await _shoot("nearly_down")
	await _advance(0.35)
	await _shoot("blow")
	await _advance(0.5)
	await _shoot("dust")
	await _advance(2.0)
	await _shoot("answer")
	await _advance(3.5)
	await _shoot("begun")
	print("[playtest] the crash over: running %s, paused %s" % [str(_main.station_jump.is_running()),
		str(root.get_node("GameState").is_paused)])

## The run's end (v0.6 T7), beat by beat: the beacon's line on a fresh landing, its bench in
## the cabin, repaired and waiting for the launch, charging while the final wave comes in from
## every side, and the jump.
func _scenario_beacon() -> void:
	var gs := root.get_node_or_null("GameState")
	var eb := root.get_node_or_null("EventBus")
	await _shoot("broken")
	await _walk_in()
	var bench: Node = _main.current_core.station("beacon")
	if bench and eb:
		eb.unit_selected.emit(bench)
	await _shoot("bench")
	for i in range(int(gs.beacon_stage_count())):
		gs.finish_beacon_job(String(gs.beacon_next_job()))
	if bench and eb:
		eb.unit_selected.emit(bench)
	await _shoot("ready_to_launch")
	gs.finish_beacon_job(String(gs.beacon_next_job()))
	await _walk_out()
	await _advance(20.0)
	await _shoot("charging")
	gs.charge_beacon(10000.0)
	await _shoot("jumped")

## How much a base holds (v0.6 balance): `siege:<traps>:<raiders>:<hp_mult>[:all]`.
##
## A sealed ring of palisade round the cabin with N bow towers inside it against the ring, loaded with wooden
## arrows (the 2026-10-02 rebuild), against one raid of that many raptors at that hit-point multiplier (what
## GameState compounds after each big wave), sent the way the game sends it: down the path from the nest, or --
## with `all` -- streamed from every way in, as the beacon's final wave is. It prints what got through and what it
## cost. `twin` sets the bigger-stored bow tower instead. Real game, real speed: a long raid is a long run.
## `inside` sets them in two rows across the yard instead -- the base a player built (v0.6 round three,
## "摆成这样的时候，恐龙进攻又会傻站着不攻击了"), printing every few seconds what the raid is doing.
func _scenario_siege(spec: String) -> void:
	var parts: PackedStringArray = spec.split(":")
	var towers: int = int(parts[1]) if parts.size() > 1 else 4
	var raiders: int = int(parts[2]) if parts.size() > 2 else 10
	var hp_mult: float = float(parts[3]) if parts.size() > 3 else 1.0
	var every_side: bool = parts.size() > 4 and parts[4] == "all"
	# "bare": no ring -- the cabin alone against the raid (it has had no gun since 2026-10-02).
	var bare: bool = parts.size() > 4 and parts[4] == "bare"
	# "twin" anywhere after: the towers' bigger store, as a late base has them.
	var trap_type: String = "bow_tower_2" if parts.slice(4).has("twin") else "bow_tower"
	var inside: bool = parts.slice(4).has("inside")
	# "back": no ring -- a fence hugging the cabin's back (the nest side) and its east end, open to
	# the west and the door, as a player half-way round has it (v0.6 round three: "即使没有完全包裹住
	# cabin，恐龙实际攻击效果很差，因为大多数都在后面转来转去"). Printed: how many bite the cabin.
	var back: bool = parts.slice(4).has("back")
	var cfg := root.get_node_or_null("Config")
	var gs := root.get_node_or_null("GameState")
	var eb := root.get_node_or_null("EventBus")
	var gm = _main.grid_manager
	var wm = _main.wave_manager
	_grant({"wood": 4000, "stone": 4000, "bone": 4000, "arrow_wood": 4000})
	var centre: Vector3 = _main.current_core.global_position

	# The ring's cells, in order round it. 6.5 m: clear of the trees and the hills, which a ring
	# cannot be built through -- and a tree is not solid to a raid, so a ring across one has a
	# door in it.
	var ring: Array[Vector2i] = []
	var seen: Dictionary = {}
	var around: int = 0 if (bare or back) else int(ceil(TAU * 6.5 / float(cfg.BUILD_CELL))) * 4
	for i in range(around):
		var a: float = TAU * float(i) / float(around)
		var cell: Vector2i = gm.world_to_build_cell(centre + Vector3(sin(a) * 6.5, 0.0, -cos(a) * 6.5))
		if not seen.has(cell):
			seen[cell] = true
			ring.append(cell)
	# The towers against the ring, inside it, spread over the side facing the nest (north) for a raid from
	# the nest, all round for the final wave.
	var placed_towers: Array[Node] = []
	var trap_cells: Dictionary = {}
	for i in range(towers if (not ring.is_empty() and not inside) else 0):
		var a: float = TAU * float(i) / float(maxi(1, towers))
		if not every_side:
			a = deg_to_rad(-80.0 + 160.0 * (float(i) + 0.5) / float(maxi(1, towers)))
		var out := Vector2(sin(a), -cos(a))
		var nearest: Vector2i = ring[0]
		for c in ring:
			var d: Vector3 = gm.build_cell_to_world(c) - centre
			var n: Vector3 = gm.build_cell_to_world(nearest) - centre
			if Vector2(d.x, d.z).normalized().dot(out) > Vector2(n.x, n.z).normalized().dot(out):
				nearest = c
		var facing: int = (1 if out.x > 0.0 else 3) if absf(out.x) > absf(out.y) else (2 if out.y > 0.0 else 0)
		# In from the ring towards the cabin -- a bow tower is two cells a side -- as near the ring as it goes down:
		# further in, it stood in the cabin's own cells, and was refused.
		var towards: Vector3 = (centre - gm.build_cell_to_world(nearest)).normalized()
		for metres in [1.5, 2.0, 2.5, 3.0]:
			var spot: Vector2i = gm.world_to_build_cell(gm.build_cell_to_world(nearest) + towards * float(metres) * float(cfg.BUILD_CELL))
			if _main.build_system.can_place_at(trap_type, spot):
				trap_cells[spot] = facing
				break
	if back:
		var c: Vector2i = gm.world_to_build_cell(centre)
		var h := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
		for x in range(-h.x - 1, h.x + 2):
			ring.append(c + Vector2i(x, -h.y - 1))
		for z in range(-h.y, h.y + 2):
			ring.append(c + Vector2i(h.x + 1, z))
		for cell in ring:
			seen[cell] = true
	# Inside: in two rows across the yard between the cabin and the ring's nest side, facing out.
	if inside:
		for i in range(towers):
			var row: int = i % 2
			var k: int = i / 2
			var per_row: int = int(ceil(float(towers) / 2.0))
			var x: float = -3.0 + 6.0 * (float(k) + 0.5) / float(maxi(1, per_row))
			var cell: Vector2i = gm.world_to_build_cell(centre + Vector3(x, 0.0, -3.0 - 1.4 * float(row)))
			if not seen.has(cell):
				trap_cells[cell] = 0
	for cell in trap_cells:
		var b = _main.build_system.place_at(trap_type, cell, _main.buildings_container, true, int(trap_cells[cell]))
		if b != null:
			b.complete_construction()
			b.set_ammo("arrow_wood")
			b.load_from_stock()
			placed_towers.append(b)
	var stakes: Array[Node] = []
	for cell in ring:
		if trap_cells.has(cell):
			continue
		var b = _main.build_system.place_at("wall", cell, _main.buildings_container, true)
		if b != null:
			b.complete_construction()
			stakes.append(b)
	await _wait(10)
	_main.nav_maps.rebake()
	await _wait(10)
	var sealed: bool = not _main.nav_maps.is_reachable(wm.nest_spawn_position, centre, false)
	print("[siege] the ring %s" % ("is sealed" if sealed else "HAS A WAY IN"))

	var killed: Array[int] = [0]
	var on_death := func(_d): killed[0] += 1
	eb.dino_died.connect(on_death)
	gs.dino_stat_multipliers["hp"] = hp_mult
	gs.day_clock = 110.0
	wm.auto_raid_enabled = false
	if every_side:
		wm.final_wave = true
		wm._edge_turn = 0
	wm.start_wave(1, raiders)
	if every_side:
		var beacon: Dictionary = gs.map_data()["beacon"]
		wm.spawn_timer.start(float(beacon["charge_seconds"]) * float(beacon["stream_share"]) / float(raiders))
	var seconds: int = 0
	while wm.is_wave_active and not gs.is_game_over and seconds < 400:
		await _advance(1.0)
		seconds += 1
		# The clock held in the middle of the day: a siege is a measure of the base, and dusk would
		# send the raid home half-way (GAME-DESIGN 9.3).
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		if seconds % 5 == 0:
			print("[siege] %3ds %s" % [seconds, _raid_minds(stakes)])
		# The seconds to print every animal's mind at: SIEGE_DEBUG="15,60" (any value but a list: 15 and 60).
		var at_seconds: PackedStringArray = OS.get_environment("SIEGE_DEBUG").split(",") if OS.has_environment("SIEGE_DEBUG") else PackedStringArray()
		if OS.has_environment("SIEGE_DEBUG") and (at_seconds.has(str(seconds)) or (not OS.get_environment("SIEGE_DEBUG").contains(",") and (seconds == 15 or seconds == 60))):
			var cpos: Vector3 = _main.current_core.global_position
			for d in get_nodes_in_group("dinos"):
				if not is_instance_valid(d) or d.is_in_group("guard_dinos") or d.is_dead:
					continue
				var rel := func(p: Vector3) -> String: return "(%.1f,%.1f)" % [p.x - cpos.x, p.z - cpos.z]
				var wps: Array = []
				for w in d.waypoints:
					wps.append(rel.call(w))
				var route_end: String = rel.call(d._route[d._route.size() - 1]) if not d._route.is_empty() else "-"
				print("[debug] at %s mode %d target %s slot %s can stand %s wp %d/%d goal %s route end %s (%d corners) patience %.2f stuck %d v %.2f | wps %s" % [
					rel.call(d.global_position), int(d.mode), str(d.current_target.name) if is_instance_valid(d.current_target) else "-",
					rel.call(d.assigned_slot) if d.assigned_slot != Vector3.ZERO else "-",
					str(d.can_stand_at(d.assigned_slot)) if d.assigned_slot != Vector3.ZERO else "-",
					d.current_waypoint_index, d.waypoints.size(), rel.call(d._journey_goal()),
					route_end, d._route.size(), d._patience, d._stuck_count, d.velocity.length(), " ".join(wps)])
	eb.dino_died.disconnect(on_death)

	var towers_left: int = 0
	for t in placed_towers:
		if is_instance_valid(t) and not t.is_destroyed:
			towers_left += 1
	var stakes_left: int = 0
	for w in stakes:
		if is_instance_valid(w) and not w.is_destroyed:
			stakes_left += 1
	var core = _main.current_core
	print("[siege] traps %d, %d raptors at hp x%.2f from %s: %s after %ds -- killed %d, cabin %d/%d, stakes %d/%d, traps %d/%d" % [
		placed_towers.size(), raiders, hp_mult, "every side" if every_side else "the nest",
		"LOST" if gs.is_game_over else ("held" if not wm.is_wave_active else "still going"), seconds,
		killed[0], int(ceil(core.current_hp)) if is_instance_valid(core) else 0, int(core.max_hp) if is_instance_valid(core) else 0,
		stakes_left, stakes.size(), towers_left, placed_towers.size()])
	await _shoot("end")

## What the raid is doing, in a line: its animals by mode and by what they are going for, and how
## many stakes still stand.
func _raid_minds(stakes: Array) -> String:
	var modes: Dictionary = {}
	var going_for: Dictionary = {}
	var still: int = 0
	for d in get_nodes_in_group("dinos"):
		if not is_instance_valid(d) or ("is_dead" in d and d.is_dead):
			continue
		var m: String = ["march", "engage", "attack", "breach"][int(d.mode)] if int(d.mode) < 4 else str(d.mode)
		modes[m] = int(modes.get(m, 0)) + 1
		var t = d.current_target
		var what: String = "nothing"
		if t != null and is_instance_valid(t):
			what = String(t.building_type) if "building_type" in t else ("hero" if t.is_in_group("hero") else t.name)
		going_for[what] = int(going_for.get(what, 0)) + 1
		if (d as Node3D).get("velocity") is Vector3 and (d.velocity as Vector3).length() < 0.1 and int(d.mode) != 2:
			still += 1
	var standing: int = 0
	for w in stakes:
		if is_instance_valid(w) and not w.is_destroyed:
			standing += 1
	var core = _main.current_core
	if core == null or not is_instance_valid(core):
		return "modes %s | going for %s | the cabin is gone | stakes %d/%d" % [str(modes), str(going_for), standing, stakes.size()]
	var at_cabin: int = 0
	var far: float = 0.0
	var n: int = 0
	for d in get_nodes_in_group("dinos"):
		if not is_instance_valid(d) or ("is_dead" in d and d.is_dead) or d.is_in_group("guard_dinos"):
			continue
		n += 1
		far += (d as Node3D).global_position.distance_to((core as Node3D).global_position)
		if int(d.mode) == 2 and d.current_target == core:
			at_cabin += 1
	return "modes %s | going for %s | standing still, not biting: %d | biting the cabin %d of %d, %.1f m off on average | stakes %d/%d" % [
		str(modes), str(going_for), still, at_cabin, n, far / maxf(1.0, float(n)), standing, stakes.size()]

## A raid's account as it ends (v0.6 T8): the longest line the HUD says in the middle of
## the screen, so it is worth seeing that it fits.
func _scenario_summary() -> void:
	var eb := root.get_node_or_null("EventBus")
	eb.raid_summary.emit({"wave": 12, "killed": 39, "drops": {"food": 38, "bone": 40, "hide": 1},
		"lost": {"wall": 6, "bow_tower": 1, "stone_wall": 2}})
	await _shoot("raid_over")

## What a material is for and where it comes from (v0.6 T2): the line the first bone
## brings, and the build menu's reason for a catapult before the pick has been made.
func _scenario_legible() -> void:
	var eb := root.get_node_or_null("EventBus")
	eb.resource_picked_up.emit("bone", 1, null)
	await _shoot("first_bone")
	var panel = _main.hud.option_panel
	if panel and panel.has_method("_show_build_detail"):
		panel._show_build_detail("catapult")
	await _shoot("why_no_catapult")

## The interface at its busiest (v0.6 round three: "界面……往精致游戏上靠近，比如学习暗黑破坏神4……
## 界面质感在于细节"): a raid's warning naming the alpha; a tooltip, hovered for real, on an ability
## slot; a bench chosen and its menu on the card; the account a raid leaves.
func _scenario_ui() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	for recipe_id in cfg.RECIPES.keys().slice(0, 2):
		gs.grant_unlock(String(cfg.RECIPES[recipe_id].get("unlocks", "")))
	_grant({"wood": 14, "stone": 6, "bone": 2, "food": 2})
	eb.raid_warning.emit(15.0)
	eb.boss_warning.emit(String(gs.map_data()["minor_boss"]))
	await _wait(8)
	await _shoot("raid_warning")
	var panel = _main.hud.option_panel
	panel.select_target(_main.hero)
	_main.hud.toggle_hero_details()    # his sheet: his kit is on it (v0.6 round four)
	await _wait(6)
	var slot: Control = panel.find_child("Ability_stone_pick", true, false) as Control
	if slot:
		root.get_viewport().warp_mouse(slot.get_global_rect().get_center())
		for i in 90:
			await process_frame
		await _shoot("tooltip")
	var bench = _main.current_core.station("workbench")
	eb.unit_selected.emit(bench)
	await _wait(8)
	var job: Control = panel.button_container.get_child(0) as Control if panel.button_container.get_child_count() > 0 else null
	if job:
		root.get_viewport().warp_mouse(job.get_global_rect().get_center())
		await _wait(20)
	await _shoot("bench_menu")
	eb.raid_summary.emit({"wave": 3, "killed": 7, "drops": {"food": 6, "bone": 7, "hide": 1},
		"lost": {"wall": 2}})
	await _wait(8)
	await _shoot("raid_over")
	# A building's card: a bitten section of fence, to mend or pull down.
	_grant({"wood": 20})
	var wall = _build_at("wall", _main.hero.global_position + Vector3(3.0, 0.0, 4.0))
	if wall:
		wall.take_damage(wall.max_hp * 0.5)
		eb.unit_selected.emit(wall)
		await _wait(8)
		await _shoot("bitten_fence")
	# The map's boss out and hurt: the longer bar over it that tells it from the rank and file.
	var species: String = String(gs.map_data()["boss"])
	var boss = load(String(cfg.get_dino_script_path(species))).new()
	_main.add_child(boss)
	boss.setup(species)
	boss.set_physics_process(false)
	boss.global_position = _main.hero.global_position + Vector3(-4.0, 0.0, 3.0)
	eb.boss_arrived.emit(boss)
	await _wait(10)
	boss.take_damage(boss.max_hp * 0.35)
	await _wait(4)
	await _shoot("boss_hurt")

## The build menu (v0.6): a hide card for each thing the known materials build -- wood's, and
## bone's once the first bone is in -- priced, the trip bow within the stock; then,
## stone in too, the whole menu, its longest names and all.
func _scenario_buildmenu() -> void:
	var gs := root.get_node("GameState")
	# As a pickup brings them, so the bar and the menu hear of each new material.
	gs.add_resources({"wood": 6, "bone": 1})
	var panel = _main.hud.option_panel
	if panel:
		panel.select_target(_main.hero)
		panel._on_build_pressed()
	await _shoot("cards")
	gs.add_resources({"stone": 3})
	await _shoot("all_known")
	# Its tabs (v0.7): each one open in turn -- the camp's with the kiln once there is clay.
	gs.add_resources({"clay": 6})
	if panel:
		for tab in panel._shown_tabs():
			panel.show_build_tab(String(tab))
			await _shoot("tab_" + String(tab))

## The pause menu and its settings page (UI-POLISH T16).
func _scenario_menu() -> void:
	_main.hud.toggle_pause_menu()
	await _shoot("root")
	var menu = _main.hud.pause_menu
	if menu and menu.has_method("open_settings"):
		menu.open_settings()
	await _shoot("settings")
	# Its Keys tab (v0.7), one of them waiting for a press.
	if menu and menu.has_method("show_settings_tab"):
		menu.show_settings_tab("keys")
		menu._listen("camera_rotate_left_key")
		await _shoot("settings_keys")

## The goal's card and the journal (v0.7: "Beacon右上角的提示应该不要一直显示……应该有个类似日志或者任务之类的显示方法"): the
## card folded to its mark; opened with the news of the goal given; the journal open over the valley.
func _scenario_journal() -> void:
	var gs := root.get_node("GameState")
	gs.play("campaign")
	gs.reset_game()
	_main.hud.reset_hud(true)
	# The opening skipped: the briefing (HUD.brief), then the goal his -- its dial beside the cabin's medallion.
	_main.hud.hold_objective()
	_main.hud.brief()
	await _wait(10)
	await _shoot("briefing")
	_main.hud.briefing.close()
	await _wait(10)
	await _shoot("dial")
	# A raid on its way: the mark at the day's dial.
	_main.hud._on_raid_warning(20.0)
	await _wait(6)
	await _shoot("raid_mark")
	_main.hud.toggle_journal()
	await _wait(6)
	await _shoot("journal")

## His row (v0.6 round three): the workbench with hide known -- what it offers now -- then his
## card with the pick and the axe in it (v0.7: the spear, the armour and the boots went), and the
## map made.
func _scenario_kit() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	# As pickups bring them, so the bench hears of each material (GameState.knows).
	gs.add_resources({"wood": 20, "stone": 12, "bone": 8, "hide": 3, "food": 2})
	gs.grant_unlock(String(cfg.RECIPES["stone_pick"]["unlocks"]))
	gs.grant_unlock(String(cfg.RECIPES["stone_axe"]["unlocks"]))
	var bench = _main.current_core.station("workbench")
	eb.unit_selected.emit(bench)
	await _wait(8)
	await _shoot("workbench")
	gs.grant_unlock(String(cfg.RECIPES["hide_map"]["unlocks"]))
	_main.hero.current_hp = _main.hero.max_hp * 0.8
	var panel = _main.hud.option_panel
	panel.select_target(_main.hero)
	_main.hud.toggle_hero_details()    # his sheet: his row is on it (v0.6 round four)
	await _wait(8)
	await _shoot("his_row")

## His card (v0.6 round four: "surviver面板太大"): chosen, his two commands in the corner and no
## card; Build and its menu above them; a building in hand and the menu gone; the details key, his
## sheet; a fence chosen, its whole card -- his commands where they were throughout.
func _scenario_herocard() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	gs.add_resources({"wood": 30, "stone": 8, "bone": 4, "food": 2})
	for recipe_id in ["stone_pick", "stone_axe"]:
		gs.grant_unlock(String(cfg.RECIPES[recipe_id]["unlocks"]))
	# Hurt, so his Rest command is in the corner too.
	_main.hero.current_hp = _main.hero.max_hp * 0.7
	eb.hero_hp_changed.emit(_main.hero.current_hp, _main.hero.max_hp)
	var panel = _main.hud.option_panel
	panel.select_target(_main.hero)
	await _wait(12)
	await _shoot("commands")
	panel._on_build_pressed()
	await _wait(8)
	await _shoot("build_menu")
	panel._trigger_build(String(panel._shown_buildables()[0]))
	var spot: Vector3 = _main.hero.global_position + Vector3(2.5, 0.0, 2.5)
	_main._update_build_preview(_main.camera.unproject_position(spot))
	await _wait(8)
	await _shoot("in_hand")
	_main.cancel_building_selection()
	_main.hud.toggle_hero_details()
	await _wait(8)
	await _shoot("details")
	var wall = _build_at("wall", _main.hero.global_position + Vector3(3.0, 0.0, 4.0))
	if wall:
		wall.take_damage(wall.max_hp * 0.4)
		eb.unit_selected.emit(wall)
		await _wait(8)
		await _shoot("fence")

## The day (GAME-DESIGN 9.3): the base at first light, in the middle of the day, at dusk and in the
## night -- the same view each time, from over the cabin, the dial on the strip saying which.
## The hand-drawn map in the corner (v0.6 round five): made at the bench, it shows where he has been -- the
## cabin, a fence, him, the smoking wrecks -- under the goal's panel.
func _scenario_map() -> void:
	var gs := root.get_node("GameState")
	_grant({"wood": 20})
	for k in 4:
		_build_at("wall", _main.current_core.global_position + Vector3(-3.0 + float(k), 0.0, 5.0))
	# Out a way first, so there is more on it than the cabin's clearing.
	for at in [Vector3(10.0, 0.0, -6.0), Vector3(-12.0, 0.0, 4.0), Vector3(0.0, 0.0, 0.0)]:
		_main.hero.global_position = _main.current_core.global_position + at
		await _wait(12)
	gs.grant_unlock("hide_map")
	await _wait(30)
	await _shoot("map")

func _scenario_day() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var parts: Dictionary = cfg.DAY["parts"]
	var noon: float = (float(cfg.DAY["light"][2]["at"]) + float(cfg.DAY["light"][3]["at"])) * 0.5
	for beat in [["dawn", 8.0], ["noon", noon], ["dusk", float(parts["dusk"]) + 6.0], ["night", float(parts["night"]) + 40.0]]:
		gs.day_clock = float(beat[1])
		await _wait(20)
		await _shoot(String(beat[0]))

## Paused with the menu shut: the frame and the word (UI-POLISH T9).
## And a pause is a snapshot (v0.6 round three: "pause就得像take snapshot一样，不能有任何状态在改变"): a raid
## at the cabin, its gun firing; paused, two frames a second apart must be the same picture, and
## unpaused they must not be. It prints how many pixels differ.
func _scenario_paused() -> void:
	var gs := root.get_node_or_null("GameState")
	var cfg := root.get_node_or_null("Config")
	_grant({"wood": 12, "stone": 3, "bone": 1})
	var wm = _main.wave_manager
	wm.auto_raid_enabled = false
	wm.start_wave(1, 6)
	var core: Node3D = _main.current_core
	await _advance(1.0)
	for d in get_nodes_in_group("dinos"):
		if d is Node3D and not d.is_in_group("guard_dinos"):
			(d as Node3D).global_position = core.global_position + Vector3(randf_range(-3.0, 3.0), 0.0, float(cfg.get_building_half("core").y) + randf_range(1.0, 3.0))
	await _advance(2.0)
	gs.set_paused(true)
	await _advance(1.0)
	await _shoot("paused")
	var first: Image = root.get_viewport().get_texture().get_image()
	await _advance(1.0)
	var second: Image = root.get_viewport().get_texture().get_image()
	gs.set_paused(false)
	await _advance(1.0)
	var running: Image = root.get_viewport().get_texture().get_image()
	print("[paused] a second apart, paused: %d pixels differ; running: %d" % [_pixels_apart(first, second), _pixels_apart(second, running)])

## How many pixels of two frames differ by more than the renderer's own frame-to-frame grain
## (its temporal anti-aliasing and fog dither move a still picture by a few hundredths), looking
## at every other one each way.
func _pixels_apart(a: Image, b: Image) -> int:
	var n: int = 0
	for y in range(0, mini(a.get_height(), b.get_height()), 2):
		for x in range(0, mini(a.get_width(), b.get_width()), 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.1:
				n += 1
	return n

## The first thing a player sees. The frame the whole visual MVP is judged on.
func _scenario_open() -> void:
	await _shoot("start")

## A fence going up, which is the one shape in the game that depends on its
## neighbours -- worth photographing rather than trusting.
func _scenario_fence() -> void:
	_grant({"wood": 400})
	var cfg := root.get_node_or_null("Config")
	var gm = _main.grid_manager
	var step: float = float(cfg.BUILD_CELL)

	# A run laid a cell at a time, which is how a wall is laid: one section per cell, each
	# joining the next.
	var z: float = -6.0
	var x: float = -5.0
	while x < 5.0:
		_build_at("wall", Vector3(x, 0.0, z))
		x += step
	# And a short arm, so a corner is in frame too.
	var zz: float = z + step
	while zz < z + step * 5.0:
		_build_at("wall", Vector3(5.0 - step, 0.0, zz))
		zz += step

	await _wait(10)
	await _shoot("fence_line")
	# And from close enough to judge the spacing, which is the thing this scenario is
	# really about -- from the play camera a gap and a join look the same.
	await _portrait("fence_close", Vector3(0.0, 0.0, z), 6.0)

## The cabin (v0.6 round three: "可进入，镂空，有透明部分（窗）里面的设施也在"): the module from outside,
## the benches showing through its windows; him at its door, the door sliding open; inside, the
## roof faded and the camera in over the room -- as a new run finds it, then fitted out with every
## tool, him floating in the healing pod.
func _scenario_cabin() -> void:
	var core: Node3D = _main.current_core
	if core == null:
		return
	var hero = _main.hero
	hero.set_physics_process(true)
	await _wait(6)
	await _portrait("outside", core.global_position + Vector3(0.0, 0.0, 0.5), 10.0, false, false)
	await _portrait("outside_front", core.global_position, 9.5, false, true)
	_main.order_enter_cabin()
	for i in range(240):
		await physics_frame
		if core.is_door_open():
			break
	await _advance(0.3)
	await _shoot("at_the_door")
	await _walk_in()
	await _advance(0.8)
	await _shoot("inside")
	var gs := root.get_node_or_null("GameState")
	var cfg := root.get_node_or_null("Config")
	var eb := root.get_node_or_null("EventBus")
	if gs and cfg:
		for recipe_id in cfg.RECIPES:
			gs.grant_unlock(String(cfg.RECIPES[recipe_id].get("unlocks", "")))
		for job_id in cfg.beacon_jobs(gs.map_data()).slice(0, gs.beacon_stage_count()):
			gs.finish_beacon_job(job_id)
	var pod: Node = core.station(HealingPod.STATION)
	hero.current_hp = hero.max_hp * 0.3
	if pod and eb:
		eb.unit_selected.emit(pod)
		pod.begin(HealingPod.REST)
	for i in range(600):
		await physics_frame
		if hero.is_resting():
			break
	await _advance(1.0)
	await _shoot("inside_resting")
	await _portrait("inside_close", core.global_position, 7.0, true)
	await _walk_out()
	await _advance(0.8)
	await _shoot("back_out")

## Sends him in through the door and waits until he is in (Main.order_enter_cabin): walked, not
## put there.
func _walk_in() -> void:
	_main.hero.set_physics_process(true)
	_main.order_enter_cabin()
	for i in range(900):
		await physics_frame
		if _main.in_cabin:
			return
	print("[playtest] he did not get into the cabin")

## And out, to the front of the door.
func _walk_out() -> void:
	_main.order_leave_cabin()
	for i in range(900):
		await physics_frame
		if not _main.in_cabin:
			return
	print("[playtest] he did not get out of the cabin")

## Portraits of the models, from close enough to actually judge them.
##
## The game is played from eighteen metres up, where a two metre wreck is a smudge.
## That is the right camera for playing and the wrong one for deciding whether a model
## is any good -- reviewing art from the play camera is how you end up shipping a
## dinosaur that turns out to have no head. These shots exist only to be looked at.
func _scenario_closeup() -> void:
	_grant({"wood": 40, "stone": 20, "bone": 4})
	var cfg := root.get_node_or_null("Config")
	var tile: float = float(cfg.TILE_SIZE) if cfg else 2.0
	var subjects: Array = [
		["wreck", _main.current_core.global_position, 8.0],
		["nest", _main.grid_manager.cell_to_world(cfg.map_data()["default_nest_cell"]), 7.0],
		["trees", _main.grid_manager.cell_to_world(Vector2i(4, -2)), 6.0],
		["stone", _main.grid_manager.cell_to_world(Vector2i(4, -6)), 5.0],
	]
	for item in cfg.map_data().get("default_resource_nodes", []):
		if String(item["type"]) == "water":
			subjects.append(["water", _main.grid_manager.cell_to_world(item["cell"]), 7.0])
	for s in subjects:
		await _portrait(String(s[0]), s[1], float(s[2]))

	# Two of the towers close up, loaded: the bow tower's ring of bows, the drop tower's boom and its log.
	var bow_at: Vector3 = _main.grid_manager.cell_to_world(Vector2i(3, 2))
	_grant({"arrow_wood": 40, "log_round": 40})
	var bow = _build_at("bow_tower", bow_at)
	if bow != null:
		bow.load_from_stock()
	await _wait(4)
	await _portrait("bow_tower", bow_at, 5.0)
	var logs_at: Vector3 = _main.grid_manager.cell_to_world(Vector2i(3, 5))
	var logs = _build_at("drop_tower", logs_at)
	if logs != null:
		logs.load_from_stock()
	await _wait(4)
	await _portrait("drop_tower", logs_at, 5.0)

	var dino_script := load("res://scripts/entities/Dino.gd")
	var dinos_to_shoot: Array = [
		["dino_t_rex", "big_theropod", 5.0],
		["dino_raptor", "raptor", 3.5],
		["dino_pterosaur", "pterosaur", 4.0],
	]
	for d_info in dinos_to_shoot:
		var d = dino_script.new()
		_main.add_child(d)
		d.setup(String(d_info[1]))
		d.global_position = Vector3(2.0, 0.0, 0.0)
		await _wait(4)
		await _portrait(String(d_info[0]), d.global_position, float(d_info[2]))
		d.queue_free()

## Portraits of the Hero model in core gameplay action poses.
func _scenario_hero() -> void:
	var hero = _main.hero
	if hero == null:
		return
	hero.set_physics_process(false)
	hero.global_position = Vector3(2.0, 0.0, 0.0)

	# 1. Idle pose
	hero.current_state = Hero.State.IDLE
	await _wait(16)
	await _portrait("hero_idle", hero.global_position, 2.5, false, true)

	# 2. Walk / locomotion pose
	hero.current_state = Hero.State.MOVING
	await _wait(10)
	await _portrait("hero_walk", hero.global_position, 2.5, false, true)

	# 3. Build / construction hammer pose
	hero.current_state = Hero.State.BUILDING
	await _wait(12)
	await _portrait("hero_build", hero.global_position, 2.5, false, true)

	# 4. Harvest / chopping cleave pose
	hero.current_state = Hero.State.HARVESTING
	await _wait(14)
	await _portrait("hero_harvest", hero.global_position, 2.5, false, true)

## Dedicated close-up and gameplay framing of the Spaceship Wreck (Core Base).
func _scenario_wreck() -> void:
	var cfg := root.get_node_or_null("Config")
	var tile: float = float(cfg.TILE_SIZE) if cfg else 2.0
	var core_pos := Vector3(tile * 0.5, 0.0, tile * 0.5)

	# 1. Close-up portrait of the crashed command pod (3.6m distance, 40-degree angle)
	await _portrait("wreck_closeup", core_pos, 3.6)

	# 2. Tactical gameplay view from standard play camera (18.0m)
	await _shoot("wreck_gameplay")

## The reported bug, walked rather than argued about: a stake beside a hillside with a
## plain gap between them, and the Hero told to go through it.
##
## Reported as "圆锥和丘陵之间明显有缝隙的情况下，人就没法走过去了". The hillside is one of
## the level's OWN outcrops rather than a synthetic blocked cell, so what the picture
## shows and what the pathfinder believes are the same thing.
##
## It prints the distance he actually closed, because at eighteen metres up a screenshot
## of a man standing still and a screenshot of a man who has arrived look far too alike.
func _scenario_gap() -> void:
	_grant({"wood": 400})
	var cfg := root.get_node_or_null("Config")
	var gm = _main.grid_manager
	var tile: float = float(cfg.TILE_SIZE)
	var step: float = float(cfg.BUILD_CELL)

	# An outcrop the level put there itself, and ONE section of wall in the tile beside it,
	# pushed towards the rock so that a cell of that tile is plainly still open ground.
	var hill: Vector2i = Vector2i(3, -3)
	var doorway: Vector2i = hill + Vector2i(-1, 0)
	_build_at("wall", gm.cell_to_world(doorway) + Vector3(tile * 0.5 - step * 0.5, 0.0, 0.0))

	var hero = _main.hero
	var start: Vector3 = gm.cell_to_world(doorway + Vector2i(0, -4))
	var goal: Vector3 = gm.cell_to_world(doorway + Vector2i(0, 4))
	hero.global_position = start
	await _wait(4)
	await _portrait("gap_before", gm.cell_to_world(doorway), 9.0, true)

	if hero.has_method("move_to"):
		hero.move_to(goal)
	await _advance(10.0)

	var span: float = start.distance_to(goal)
	var closed: float = span - hero.global_position.distance_to(goal)
	print("[playtest] gap: hero closed %.1fm of %.1fm" % [closed, span])
	await _portrait("gap_after", gm.cell_to_world(doorway), 9.0, true)

## The tightest ring of stakes the game will let the player put round the cabin.
##
## Reported as "cabin 的范围在右边大一点，左边小" and then, more precisely, as one stake's
## worth of ground on some sides that cannot be filled. Measured, the gap is 0.523m from
## every one of the cabin's four faces -- but stakes OFFSET along the other axis tuck in
## beside it, so the ring is not a uniform distance away and from a rotated camera some
## of it reads as flush and some does not. This is the shot to look at rather than argue
## about.
func _scenario_snug() -> void:
	_grant({"wood": 400})
	var cfg := root.get_node_or_null("Config")
	var gm = _main.grid_manager
	var core_cell: Vector2i = cfg.map_data()["default_core_cell"]
	var core: Vector3 = gm.cell_to_world(core_cell)
	var centre: Vector2i = gm.world_to_build_cell(_main.current_core.global_position)
	var ring: int = (int(cfg.get_building_cells("core")) - 1) / 2 + 1
	# The Hero standing there is not the cabin's business.
	if _main.hero:
		_main.hero.global_position = core + Vector3(0.0, 0.0, 14.0)
	await _wait(2)
	var placed: int = 0
	# The cells right round the cabin's own: flush against its walls, on every side.
	for dx in range(-ring, ring + 1):
		for dz in range(-ring, ring + 1):
			if absi(dx) != ring and absi(dz) != ring:
				continue
			var b = _main.build_system.place_at("wall", centre + Vector2i(dx, dz), _main.buildings_container, true)
			if b != null:
				b.complete_construction()
				placed += 1
	# The cabin's TRUE footprint, painted flat on the ground. The cabin is 1.9m tall and
	# a stake is 0.95m, so under any tilted camera their tops lean by different amounts
	# and the gap looks bigger on one side than the other. This is the thing the stakes
	# are actually measured from.
	var mark := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	var w: float = float(cfg.get_building_footprint("core"))
	quad.size = Vector2(w, w)
	mark.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mark.material_override = mat
	_main.add_child(mark)
	# On the cabin's own middle: it runs south and east from its tile, so its middle is not the tile's.
	mark.global_position = (_main.current_core as Node3D).global_position + Vector3(0.0, 0.05, 0.0)
	await _wait(8)
	print("[playtest] snug: %d sections on the tightest ring the game allows" % placed)
	print("[playtest] snug: the red square is the cabin's real %.1fm footprint on the ground" % w)
	# STRAIGHT DOWN, with no tilt at all, which is the only view with no parallax in it.
	# Everything else leans: the cabin is 1.9m tall and a stake 0.95m, so under any tilted
	# camera their tops shift by different amounts and the gap reads differently on each
	# side. Here the red square and the cones are all at ground level and nothing leans.
	var top := Camera3D.new()
	_main.add_child(top)
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 5.0
	top.global_position = core + Vector3(0.0, 20.0, 0.0)
	top.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	top.current = true
	await _wait(6)
	await _shoot("tightest_ring_plan")
	top.queue_free()
	await _wait(2)
	# THE SAME RING FROM TWO OPPOSITE BEARINGS, using the player's own camera controls.
	# This is what the view turning is for: from one fixed angle the near side of a 1.9m
	# cabin covers the ground behind it, so a gap that is the same all the way round
	# reads as flush on one side and open on the other. Turn half a circle and the two
	# sides swap over -- which is the proof that the ground is symmetric and the picture
	# was not.
	var rig = _main.camera_rig
	if rig != null:
		rig.look_at_point(core)
		rig.distance = 9.0
		rig.tilt = 38.0
		for shot in [["near_side", 35.0], ["far_side", 215.0]]:
			rig.yaw = float(shot[1])
			rig.apply_to(_main.camera)
			_main.camera.current = true
			await _wait(6)
			await _shoot("tightest_ring_%s" % String(shot[0]))
		rig.reset()
		rig.apply_to(_main.camera)
		await _wait(2)

## The opening film (Opening; the player, 2026-10-04: "开场动画还要精致化一点……这个开场动画要有大片感"), a frame every
## so often from its first shot to the run's first moment.
func _scenario_opening() -> void:
	var gs := root.get_node("GameState")
	gs.play("campaign")
	_main.hud.reset_hud(true)
	_main.hud.hold_objective()
	var film := Opening.new()
	_main.add_child(film)
	var began: int = Time.get_ticks_msec()
	film.play(_main)
	var every: float = 1.5
	var k: int = 0
	while film.is_playing() and k < 48:
		var due: float = every * float(k) + 0.6
		while (Time.get_ticks_msec() - began) / 1000.0 < due and film.is_playing():
			await process_frame
		await _shoot("film_%02d" % k)
		k += 1
	print("[playtest] opening: %d frames, %.1f s, skipped %s" % [k, (Time.get_ticks_msec() - began) / 1000.0, film.was_skipped])
	await _wait(10)
	await _shoot("film_after")

## The work seen (Config.CONSTRUCTION; the player, 2026-10-04: "造的塔首先要有造的阶段样子……至少要有四个阶段的成型前
## 样子，升级也要有两个阶段"): a bow tower and a drop tower side by side, ordered, at each stage of going up, whole; then
## the bow tower built onto, at each of its two stages.
func _scenario_stages() -> void:
	_grant({"wood": 400, "stone": 100, "bone": 100})
	var core: Vector3 = _main.current_core.global_position
	var at: Vector3 = core + Vector3(0.0, 0.0, 9.0)
	var towers: Array = []
	for row in [["bow_tower", Vector3(-1.6, 0.0, 0.0)], ["drop_tower", Vector3(1.6, 0.0, 0.0)]]:
		var b = _main.build_system.place_at(String(row[0]), _main.grid_manager.world_to_build_cell(at + (row[1] as Vector3)),
			_main.buildings_container, true)
		if b != null:
			towers.append(b)
	if _main.hero:
		_main.hero.global_position = core + Vector3(6.0, 0.0, 14.0)
	await _wait(6)
	for p in [0.0, 0.1, 0.35, 0.6, 0.85]:
		for b in towers:
			b.build_progress = p
			b._update_visuals_progress()
		await _wait(4)
		await _portrait("stage_%02d" % int(p * 100), at, 7.0)
	for b in towers:
		b.complete_construction()
	await _wait(4)
	await _portrait("stage_done", at, 7.0)
	var bow = towers[0] if not towers.is_empty() else null
	if bow != null:
		var cfg := root.get_node_or_null("Config")
		var to: String = String(cfg.upgrade_targets(String(bow.building_type))[0])
		bow.begin_upgrade(to)
		await _wait(4)
		await _portrait("upgrade_1", at, 7.0)
		bow.add_upgrade_progress(float(cfg.get_upgrade_time(String(bow.building_type), to)) * 0.6)
		await _wait(4)
		await _portrait("upgrade_2", at, 7.0)

## His hammering (the player, 2026-10-04: "人在造塔的时候要有敲打的动作，而不是跪下来，维修也是"): at work, the hammer in
## his right hand; stopped at points through a blow -- held up, coming down, on the work, rising -- close, from his side
## and from in front.
func _scenario_hammer() -> void:
	var hero = _main.hero
	if hero == null:
		return
	hero.set_physics_process(false)
	hero.global_position = _main.current_core.global_position + Vector3(0.0, 0.0, 9.0)
	hero.rotation.y = 0.0
	hero.current_state = Hero.State.BUILDING
	await _wait(30)
	var ap: AnimationPlayer = hero.animator.animation_player
	var cfg := root.get_node_or_null("Config")
	var blow: float = float(cfg.SOUNDS.get("hammer_every", 0.625))
	print("[playtest] hammer: out %s, clip %s %.2fs" % [hero.has_hammer_out(), ap.current_animation, ap.current_animation_length])
	for f in [0.2, 0.45, 0.55, 0.62, 0.8]:
		ap.seek(blow * f, true)
		Engine.time_scale = 0.0
		await _portrait("hammer_side_%02d" % int(f * 100), hero.global_position, 2.4)
		await _portrait("hammer_front_%02d" % int(f * 100), hero.global_position, 2.4, false, true)
		Engine.time_scale = 1.0

## Ramming the cabin (the player's bug report, 2026-10-04: "有个恐龙离船舱很远，但有进攻动作……撞击需要真的撞的动作，
## 而且要贴着船舱，不然像隔山打牛"): one of each raider set on the cabin from round it -- the long walls, both ends, the
## corners -- let come to it and ram. Shot from straight above, the hull's outline (Config.hull_outline) drawn on the
## ground in red, and from beside it. Printed: each one's middle from the hull against where it stands to ram.
func _scenario_ram() -> void:
	var cfg := root.get_node_or_null("Config")
	var core: Node3D = _main.current_core
	var c: Vector3 = core.global_position
	if _main.hero:
		_main.hero.global_position = c + Vector3(0.0, 0.0, 16.0)
	_main.wave_manager.auto_raid_enabled = false
	var cast: Array = [["desmatosuchus", Vector3(9.0, 0.0, -5.0)], ["coelophysis", Vector3(-1.0, 0.0, -9.0)],
		["postosuchus", Vector3(11.0, 0.0, 0.5)], ["raptor", Vector3(-10.0, 0.0, 0.5)],
		["allosaurus", Vector3(3.0, 0.0, -13.0)], ["desmatosuchus", Vector3(-8.0, 0.0, -6.0)],
		["hesperosuchus", Vector3(-3.0, 0.0, 9.0)]]
	var dinos: Array = []
	for row in cast:
		var d = load(String(cfg.get_dino_script_path(String(row[0])))).new()
		_main.dinos_container.add_child(d)
		d.setup(String(row[0]))
		d.max_hp = 9999.0
		d.current_hp = 9999.0
		d.global_position = c + (row[1] as Vector3)
		d.set_waypoints([d.global_position, c])
		dinos.append(d)
	await _advance(14.0)
	for d in dinos:
		var on: Vector3 = d._hull_point(core, d.global_position)
		var gap: float = Vector2(d.global_position.x - on.x, d.global_position.z - on.z).length()
		print("[playtest] ram: %-14s %-7s middle %.2f m from the hull, stands to ram at %.2f (%+.2f)  ram_front %.2f" % [
			d.dino_type, Dino.Mode.keys()[int(d.mode)], gap, d._ram_stand(), gap - d._ram_stand(), d.ram_front()])
	# The hull's outline on the ground, a red ribbon a few centimetres wide.
	var ribbon := ImmediateMesh.new()
	var outline: PackedVector2Array = cfg.hull_outline("core")
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := Vector3(outline[i].x, 0.06, outline[i].y)
		var b := Vector3(outline[(i + 1) % outline.size()].x, 0.06, outline[(i + 1) % outline.size()].y)
		var side: Vector3 = (b - a).cross(Vector3.UP).normalized() * 0.03
		for p in [a - side, b - side, b + side, a - side, b + side, a + side]:
			ribbon.surface_add_vertex(p)
	ribbon.surface_end()
	var mark := MeshInstance3D.new()
	mark.mesh = ribbon
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = mat
	_main.add_child(mark)
	mark.global_position = c
	var top := Camera3D.new()
	_main.add_child(top)
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 13.0
	top.global_position = c + Vector3(0.0, 30.0, 0.0)
	top.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	var fog = _main.get("fog")
	if fog != null and is_instance_valid(fog):
		fog.revealed = true
		fog._paint(1.0)
		fog._hide_the_unseen()
	top.current = true
	for k in 3:
		await _advance(0.37)
		await _shoot("ram_plan_%d" % k)
	top.current = false
	top.queue_free()
	await _portrait("ram_east_end", c + Vector3(3.5, 0.0, -0.5), 7.0)
	await _portrait("ram_north_wall", c + Vector3(0.0, 0.0, -2.0), 8.0, false, true)
	# Each at the height of its ram -- the clip's drive, about 0.57 of it (tools/dino_moves.py ram) -- the game stopped
	# there for the picture: its head at the hull.
	for k in [0, 1, 4]:
		var d = dinos[k]
		var ap: AnimationPlayer = d.animator.animation_player if d.animator else null
		for i in 240:
			if ap != null and ap.current_animation_length > 0.0:
				var f: float = ap.current_animation_position / ap.current_animation_length
				if f >= 0.55 and f <= 0.6:
					break
			await physics_frame
		Engine.time_scale = 0.0
		var head: Vector3 = d.global_position - d.global_transform.basis.z.normalized() * float(d.ram_front())
		# Where the tip of its head is now, and how far from the hull (inside it, less than nought).
		var sk: Skeleton3D = d.find_child("Body", false, false).find_children("*", "Skeleton3D", true, false)[0]
		var tip_bone: int = sk.find_bone("Head_end")
		var tip: Vector3 = sk.global_transform * sk.get_bone_global_pose(tip_bone).origin
		var on: Vector3 = d._hull_point(core, tip)
		var inside: bool = Geometry2D.is_point_in_polygon(Vector2(tip.x - c.x, tip.z - c.z), cfg.hull_outline("core"))
		var gap: float = Vector2(tip.x - on.x, tip.z - on.z).length() * (-1.0 if inside else 1.0)
		var ahead: Vector3 = -d.global_transform.basis.z.normalized()
		var rel: Vector3 = tip - d.global_position
		print("[playtest] ram peak: %-14s at %.2f of its clip, tip of its head %.2f m from the hull (%.2f up), %.2f ahead, %.2f aside" % [
			d.dino_type, ap.current_animation_position / ap.current_animation_length, gap, tip.y,
			rel.dot(ahead), rel.dot(ahead.cross(Vector3.UP))])
		var above := Camera3D.new()
		_main.add_child(above)
		above.projection = Camera3D.PROJECTION_ORTHOGONAL
		above.size = 4.0
		above.global_position = head + Vector3(0.0, 30.0, 0.0)
		above.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		above.current = true
		await _shoot("ram_peak_%s" % d.dino_type)
		above.current = false
		above.queue_free()
		Engine.time_scale = 1.0

## The valley as somebody standing in it would see it: low, looking across the field to
## the forest edge and the monkey-puzzles on the skyline.
##
## The opening camera looks steeply down and barely sees a horizon, so it can never show
## whether the place FEELS like the Jurassic -- which was the whole brief ("远古恐龙时代的
## 风貌，让人身临其境之感"). These are the angles the player gets to by turning and tilting
## the view, taken through the player's own camera rig, with the HUD hidden.
func _scenario_showcase() -> void:
	var rig = _main.camera_rig
	if rig == null:
		return
	if _main.hud:
		_main.hud.visible = false
	var shots := [
		["across_the_field", Vector3(-2.0, 0.0, -8.0), 215.0, 20.0, 22.0],
		["to_the_skyline", Vector3(4.0, 0.0, 6.0), 20.0, 24.0, 16.0],
		["over_the_forest_edge", Vector3(16.0, 0.0, -14.0), 300.0, 18.0, 30.0],
		# The opening view's own bearing, tilted as far up as the player can tilt it.
		["to_the_volcano", Vector3(6.0, 0.0, 2.0), 62.0, 24.0, 15.0],
	]
	for s in shots:
		rig.look_at_point(s[1])
		rig.yaw = float(s[2])
		rig.distance = float(s[3])
		rig.tilt = float(s[4])
		rig.apply_to(_main.camera)
		_main.camera.current = true
		await _shoot(String(s[0]))
	rig.reset()
	rig.apply_to(_main.camera)
	if _main.hud:
		_main.hud.visible = true

## Everything that has a size, side by side: the Hero, a raptor and the big theropod
## lined up beside the wreck, with a stake and a turret, seen side-on from a person's eye
## height and then from the game's own camera.
##
## Portraits one at a time cannot show proportion -- each is framed to fill the picture --
## which is how the Hero came to stand as tall as the tyrannosaur and twice the height of
## the raptors without any single shot looking wrong.
## Half the width of the cabin's box, for lining things up beside it.
func cfg_row_half() -> float:
	var cfg := root.get_node_or_null("Config")
	return float(cfg.get_building_footprint("core")) * 0.5 if cfg else 0.5

## The first map's cast side by side with him (tools/generate_dinos.py; the player, 2026-09-30: "恐龙目前模型做的都
## 粗糙，我需要它们更精致"): from the side at eye height, from the game's camera, and each close by its head --
## standing, then the Coelophysis walking.
func _scenario_cast(lineup: Array = []) -> void:
	if _main.hud:
		_main.hud.visible = false
	var core_at: Vector3 = _main.current_core.global_position
	var row_z: float = core_at.z + float(cfg_row_half()) + 3.0
	var hero = _main.hero
	if hero != null:
		hero.set_physics_process(false)
		hero.global_position = Vector3(core_at.x - 3.2, 0.0, row_z)
		hero.rotation.y = PI * 0.5
	var dino_script := load("res://scripts/entities/Dino.gd")
	if lineup.is_empty():
		lineup = [["coelophysis", -1.2], ["coelophysis_alpha", 1.4], ["hesperosuchus", 3.8],
			["phytosaur", 6.8], ["postosuchus", 11.5]]
	var dinos: Array = []
	for item in lineup:
		var d = dino_script.new()
		_main.add_child(d)
		d.setup(String(item[0]))
		d.set_physics_process(false)
		d.global_position = Vector3(core_at.x + float(item[1]), 0.0, row_z)
		d.rotation.y = PI * 0.5
		dinos.append(d)
	# The fog of war lifted, as for a portrait (FogOfWar): these are pictures of the models.
	var fog = _main.get("fog")
	if fog != null and is_instance_valid(fog):
		fog.revealed = true
		fog._paint(1.0)
		fog._hide_the_unseen()
	await _wait(8)
	var mid := Vector3(core_at.x + 4.0, 0.0, row_z)
	var cam := Camera3D.new()
	# No depth of field: the game's blurs the near ground, and these are looked at close.
	cam.attributes = CameraAttributesPractical.new()
	_main.add_child(cam)
	var was: Camera3D = _main.camera
	cam.current = true
	cam.position = mid + Vector3(0.0, 1.1, 11.0)
	cam.look_at(mid + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	await _shoot("side_on")
	# Each close by, a little in front and above, framed by its own size.
	for d in dinos:
		var box := AABB()
		var first := true
		for m in (d as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var wb: AABB = mi.global_transform * mi.get_aabb()
			box = wb if first else box.merge(wb)
			first = false
		var size: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		var look: Vector3 = box.get_center()
		cam.position = look + Vector3(size * 0.3, size * 0.22, size * 0.8)
		cam.look_at(look, Vector3.UP)
		await _shoot("close_%s" % String(d.get("dino_type")))
	cam.current = false
	if was != null and is_instance_valid(was):
		was.current = true
	_main.remove_child(cam)
	cam.queue_free()
	# From the game's own camera, over the row.
	if _main.get("camera_rig") != null:
		_main.look_at_ground(mid)
	await _wait(4)
	await _shoot("from_the_game_camera")
	# Killed where they stand: each falls as its death clip has it, lies a while, and sinks away
	# (Fx.lay_down; the debug-agent's BUG-029) -- under the running scene, as in the game.
	current_scene = _main
	for d in dinos:
		d.die()
	await _advance(0.5)
	await _shoot("falling")
	await _advance(1.5)
	await _shoot("fallen")
	await _advance(float(root.get_node("Config").FEEDBACK["carcass_lie"]) + 0.6)
	await _shoot("sinking")
	current_scene = null
	if _main.hud:
		_main.hud.visible = true

## The cast going (tools/dino_moves.py): each on its own, side on and close, at four points of its walk, its run
## and its idle -- the herd's Placerias too -- to see how each carries itself as the game draws it.
func _scenario_gaits() -> void:
	if _main.hud:
		_main.hud.visible = false
	var fog = _main.get("fog")
	if fog != null and is_instance_valid(fog):
		fog.revealed = true
		fog._paint(1.0)
		fog._hide_the_unseen()
	var cfg := root.get_node("Config")
	var core_at: Vector3 = _main.current_core.global_position
	var at := Vector3(core_at.x + 4.0, 0.0, core_at.z + float(cfg_row_half()) + 3.0)
	var cam := Camera3D.new()
	cam.attributes = CameraAttributesPractical.new()
	cam.fov = 40.0
	_main.add_child(cam)
	var was: Camera3D = _main.camera
	cam.current = true
	var dino_script := load("res://scripts/entities/Dino.gd")
	var species_list: Array = ["coelophysis", "coelophysis_alpha", "hesperosuchus", "phytosaur", "postosuchus",
		"placerias", "raptor", "raptor_alpha", "big_theropod", "pterosaur", "desmatosuchus", "stegosaurus"]
	for species in species_list:
		if not _only.is_empty() and not _only.has(String(species)):
			continue
		var body: Node3D = null
		var player: AnimationPlayer = null
		if species == "placerias":
			# As the herd makes it (Herds): its scene, fitted to its length.
			var herd: Dictionary = {}
			for h in cfg.HERDS["herds"]:
				if String(h.get("species", "")) == species:
					herd = h
			body = Node3D.new()
			_main.add_child(body)
			var art: Node3D = VisualLibrary.scene_at(String(herd["scene"])).instantiate()
			body.add_child(art)
			VisualLibrary.read_vertex_colours(art)
			var bounds: AABB = VisualLibrary.visual_bounds(art)
			VisualLibrary.place(art, float(herd["length"]) / bounds.size.z, "feet")
			var players: Array = art.find_children("*", "AnimationPlayer", true, false)
			player = players[0] if not players.is_empty() else null
		else:
			var d = dino_script.new()
			_main.add_child(d)
			d.setup(String(species))
			d.set_physics_process(false)
			d.set_process(false)
			body = d
			player = d.animator.animation_player if d.animator != null else null
		body.global_position = at
		body.rotation.y = PI * 0.5
		await _wait(4)
		if player == null:
			body.queue_free()
			continue
		# Framed by the animal's model (a dinosaur's "Body", Dino._ensure_body), not whatever else the entity
		# carries.
		var art_root: Node = body.find_child("Body", false, false)
		if art_root == null:
			art_root = body
		var box := AABB()
		var first := true
		for m in art_root.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var wb: AABB = mi.global_transform * mi.get_aabb()
			box = wb if first else box.merge(wb)
			first = false
		# All of it in the picture, long or tall.
		var size: float = maxf(box.size.x, maxf(box.size.y * 1.6, box.size.z))
		var look: Vector3 = box.get_center()
		cam.position = look + Vector3(0.0, size * 0.08, size * 0.95)
		cam.look_at(look, Vector3.UP)
		for clip in ["walk", "run", "idle"]:
			if not player.has_animation(clip):
				continue
			var length: float = player.get_animation(clip).length
			for i in range(4):
				player.play(clip)
				player.seek(length * float(i) / 4.0, true)
				player.pause()
				await _shoot("%s_%s_%d" % [species, clip, i])
		body.queue_free()
		await _wait(2)
	cam.current = false
	if was != null and is_instance_valid(was):
		was.current = true
	_main.remove_child(cam)
	cam.queue_free()
	if _main.hud:
		_main.hud.visible = true

## The start screen (StartScreen) over the stopped valley, as the game launched opens on it: its title page, and
## the custom game's page -- its first rows, and scrolled to its last.
func _scenario_start() -> void:
	_main.hud.show_start_screen(true)
	await _wait(4)
	await _shoot("title")
	var screen = _main.hud.start_screen
	screen.show_custom()
	await _wait(4)
	await _shoot("custom_page")
	var scroll := screen.find_child("SettingsScroll", true, false) as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 10000
		await _wait(4)
		await _shoot("custom_page_end")
	screen.close()
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.set_paused(false)

## A custom game (GameState.play): the Late Cretaceous, the hardest, on the small valley, no fog -- its three nests
## with their raptor guards from the game's camera, the goal's card counting the days to rescue, and its first raid.
func _scenario_custom() -> void:
	var gs := root.get_node_or_null("GameState")
	gs.play("custom", {"era": "late_cretaceous", "difficulty": "nightmare", "map": "small", "fog": "off"}, 7)
	_tear_down()
	await _fresh_level()
	await _wait(10)
	await _shoot("nests")
	var nest: Node3D = _main.current_nest as Node3D
	if nest != null and _main.get("camera_rig") != null:
		_main.look_at_ground(nest.global_position + Vector3(4.0, 0.0, 3.0))
		await _wait(6)
		await _shoot("the_nests_up_close")
	_main.look_at_ground(_main.current_core.global_position)
	# To the first raid, and it on its way to the cabin.
	var first: float = float(gs.map_data().get("beats", {}).get("first_raid", 60.0))
	await _advance(first + 12.0)
	await _shoot("its_first_raid")
	gs.game = {}

func _scenario_scale() -> void:
	if _main.hud:
		_main.hud.visible = false
	_grant({"wood": 40, "stone": 20})
	var core_at: Vector3 = _main.current_core.global_position
	# A row in front of the cabin's south wall, the cabin at its left end.
	var row_z: float = core_at.z + float(cfg_row_half()) + 1.4
	_build_at("wall", Vector3(core_at.x - 2.2, 0.0, row_z))
	_build_at("bow_tower", _main.grid_manager.cell_to_world(Vector2i(-2, 0)))
	var hero = _main.hero
	if hero != null:
		hero.set_physics_process(false)
		hero.global_position = Vector3(core_at.x + 1.4, 0.0, row_z)
		hero.rotation.y = PI * 0.5
	var dino_script := load("res://scripts/entities/Dino.gd")
	var lineup: Array = [["raptor", 3.2], ["big_theropod", 7.4]]
	var dinos: Array = []
	for item in lineup:
		var d = dino_script.new()
		_main.add_child(d)
		d.setup(String(item[0]))
		d.set_physics_process(false)
		d.global_position = Vector3(core_at.x + float(item[1]), 0.0, row_z)
		d.rotation.y = PI * 0.5
		dinos.append(d)
	await _wait(6)
	var mid := Vector3(core_at.x + 2.6, 0.0, row_z)
	var cam := Camera3D.new()
	_main.add_child(cam)
	cam.position = mid + Vector3(0.0, 1.7, 13.0)
	cam.look_at(mid + Vector3(0.0, 1.5, 0.0), Vector3.UP)
	var was: Camera3D = _main.camera
	cam.current = true
	await _shoot("side_on")
	cam.current = false
	if was != null and is_instance_valid(was):
		was.current = true
	_main.remove_child(cam)
	cam.queue_free()
	await _shoot("from_the_game_camera")
	for d in dinos:
		d.queue_free()
	if _main.hud:
		_main.hud.visible = true

## A raid meeting a fence, measured rather than watched.
##
## Reported as "恐龙站在木尖刺前（有一段距离）就不进攻了，然后就卡着不动". This scenario
## existed for that report already and did not catch it, twice over, and both reasons are
## worth keeping in mind for anything else built to watch a raid:
##
##   * IT USED FIVE DINOSAURS. A raid is twenty. The jam that was being reported is a
##     crowd problem and barely exists in a queue of five.
##   * IT USED Dino.gd DIRECTLY. Every raptor in the game is a PackDino, which overrode
##     the targeting outright -- so this was measuring code no wave has ever run.
##
## It now spawns whatever Config says a raptor is, twenty of them by default, and reports
## the thing the report was about: HOW LONG ANYONE STANDS STILL with somewhere left to go
## and nothing being bitten. Averages hide exactly the case that gets reported -- most of
## a raid arriving while three park in front of the fence still averages well, and the
## three are what the player is looking at.
##
## `raidsealed` walls the wreck in completely instead, which has to come out the other
## way: nobody gets through, and the fence is what gets chewed.
func _scenario_raid() -> void:
	_grant({"wood": 2000})
	var cfg := root.get_node_or_null("Config")
	var gm = _main.grid_manager
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sealed_ring: bool = args.has("raidsealed")
	var count: int = 20
	for a in args:
		if String(a).is_valid_int():
			count = int(String(a))
	var step: float = float(cfg.BUILD_CELL)
	var core: Vector3 = _main.current_core.global_position

	var placed: int = 0
	if sealed_ring:
		var seen: Dictionary = {}
		var around: int = int(ceil(TAU * 4.0 / step)) * 4
		for i in range(around):
			var a: float = TAU * float(i) / float(around)
			var at: Vector3 = core + Vector3(sin(a) * 4.0, 0.0, cos(a) * 4.0)
			var cell: Vector2i = gm.world_to_build_cell(at)
			if seen.has(cell):
				continue
			seen[cell] = true
			_build_at("wall", gm.build_cell_to_world(cell))
			placed += 1
	else:
		# The diagonal run from the report, shoulder to shoulder, open at both ends.
		for i in range(9):
			_build_at("wall", core + Vector3(-5.0 + float(i) * step, 0.0, -7.0 + float(i) * step))
			placed += 1
	await _wait(4)

	# WHAT THE GAME ACTUALLY SPAWNS, not the base class.
	var dino_script := load(String(cfg.get_dino_script_path("raptor")))
	var goal: Vector3 = core if sealed_ring else core + Vector3(0.0, 0.0, 4.0)
	var raid: Array[Node] = []
	var stall_now: Array[float] = []
	var stall_max: Array[float] = []
	for i in range(count):
		var d = dino_script.new()
		_main.add_child(d)
		d.setup("raptor")
		# Not a combat test: nobody is to die of contact damage part way through.
		d.max_hp = 9999.0
		d.current_hp = 9999.0
		d.global_position = core + Vector3(-4.0 + float(i % 5) * 1.2, 0.0, -18.0 + float(i / 5) * 1.2)
		d.set_waypoints([goal])
		raid.append(d)
		stall_now.append(0.0)
		stall_max.append(0.0)
	await _wait(4)
	await _portrait("raid_before", core + Vector3(0.0, 0.0, -5.0), 16.0, true)

	# Reversals as well as stalls. A raid that shuttles back and forth is never still, so
	# a stall counter says it is fine -- and it is going nowhere while the spikes bleed
	# it, which is what "来回穿梭，进攻不了还掉血" was.
	var last_dir: Array[Vector3] = []
	var reversals: Array[int] = []
	for i in range(raid.size()):
		last_dir.append(Vector3.ZERO)
		reversals.append(0)

	var dt: float = 1.0 / 60.0
	for frame in range(22 * 60):
		await physics_frame
		for i in range(raid.size()):
			var d = raid[i]
			if not is_instance_valid(d):
				continue
			var idle: bool = d.velocity.length() < 0.2 				and int(d.current_state) != int(d.State.ATTACKING) 				and d.global_position.distance_to(goal) > 3.0
			stall_now[i] = (stall_now[i] + dt) if idle else 0.0
			stall_max[i] = maxf(stall_max[i], stall_now[i])
			var v: Vector3 = d.velocity
			v.y = 0.0
			if v.length() >= 0.5:
				var dir: Vector3 = v.normalized()
				if last_dir[i] != Vector3.ZERO and dir.dot(last_dir[i]) < -0.5:
					reversals[i] += 1
				last_dir[i] = dir

	var worst: float = 0.0
	var stalled: int = 0
	var arrived: int = 0
	var chewing: int = 0
	var gnawing_stakes: int = 0
	for i in range(raid.size()):
		worst = maxf(worst, stall_max[i])
		if stall_max[i] >= 2.0:
			stalled += 1
		var d = raid[i]
		if not is_instance_valid(d):
			continue
		# REACHING THE CABIN, not reaching the goal marker. The arc run's goal sits four
		# metres behind the cabin, so a raid that does the right thing -- walks round the
		# fence, arrives at the cabin and eats it -- never gets within three metres of the
		# marker, and the old count read that as nineteen failures. Every one of them had
		# walked the fence perfectly and was biting the thing it came for.
		if d.global_position.distance_to(core) < 4.0:
			arrived += 1
		# And what it is biting is the whole question this scenario asks. Chewing a STAKE
		# with open ground either side of it is the bug; chewing the cabin is the point.
		if int(d.current_state) == int(d.State.ATTACKING):
			chewing += 1
			var t = d.current_target
			if t != null and is_instance_valid(t) and ("building_type" in t) and String(t.building_type) == "wall":
				gnawing_stakes += 1
	# HOW MUCH FENCE IS LEFT. Without it "they are at the cabin" cannot tell a raid that
	# ATE its way in from one that walked through a fence that is still standing -- and
	# walking through is exactly the bug this scenario was built to catch.
	var standing: int = 0
	for b in gm.get_all_buildings():
		if is_instance_valid(b) and ("building_type" in b) and String(b.building_type) == "wall":
			standing += 1
	var worst_reversals: int = 0
	for n in reversals:
		worst_reversals = maxi(worst_reversals, n)
	print("[playtest] raid(%s, %s x%d): %d stakes | longest stall %.1fs | stalled>=2s %d | worst reversals %d | at the cabin %d | biting %d (stakes %d) | fence %d of %d left"
		% ["sealed" if sealed_ring else "arc",
			String(cfg.get_dino_script_path("raptor")).get_file(), raid.size(),
			placed, worst, stalled, worst_reversals, arrived, chewing, gnawing_stakes,
			standing, placed])
	await _portrait("raid_after", core + Vector3(0.0, 0.0, -5.0), 16.0, true)

## Puts a camera at eye level a short way off `at`, looking at it, and takes one frame.
## The camera is removed again afterwards, so the level is left exactly as it was.
## `overhead` looks almost straight down instead, which is the only angle a GAP reads
## from: from eye level a stake in front of a rock and a stake beside one look the same.
func _portrait(name: String, at: Vector3, distance: float, overhead: bool = false, front_view: bool = false) -> void:
	var cam := Camera3D.new()
	_main.add_child(cam)
	if overhead:
		cam.position = at + Vector3(0.0, distance, distance * 0.28)
		cam.look_at(at + Vector3(0.0, 0.6, 0.0), Vector3.UP)
	elif front_view:
		cam.position = at + Vector3(distance * 0.65, distance * 0.35, -distance * 0.75)
		cam.look_at(at + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	else:
		cam.position = at + Vector3(distance * 0.72, distance * 0.42, distance * 0.72)
		cam.look_at(at + Vector3(0.0, 0.6, 0.0), Vector3.UP)
	var was: Camera3D = _main.camera
	# A portrait is of the model: the fog of war lifted for it and put back after (FogOfWar).
	var fog = _main.get("fog")
	var lifted: bool = fog != null and is_instance_valid(fog) and not bool(fog.revealed)
	if lifted:
		fog.revealed = true
		fog._paint(1.0)
		fog._hide_the_unseen()
	cam.current = true
	await _shoot(name)
	cam.current = false
	if lifted:
		fog.revealed = false
	if was != null and is_instance_valid(was):
		was.current = true
	_main.remove_child(cam)
	cam.queue_free()

# ==============================================================================
# Driving the game
# ==============================================================================

## A level, freshly built, settled, and ready to be photographed.
##
## Driven through the game's own API rather than through synthetic mouse events: what
## is being checked here is how the world LOOKS, and going through the API keeps the
## picture reproducible. Clicking real pixels is the right tool for checking a UI flow,
## and belongs in a scenario of its own when that is what is being asked.
func _fresh_level() -> void:
	# Each scenario is a run of its own: what one granted, made or repaired is not the next
	# one's starting point (the cabin's shots repair the beacon the beacon's shots start from).
	var gs := root.get_node_or_null("GameState")
	if gs and gs.has_method("reset_game"):
		gs.reset_game(_seed)
	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)
	await _wait(SETTLE_FRAMES)

func _tear_down() -> void:
	if _main != null and is_instance_valid(_main):
		root.remove_child(_main)
		_main.queue_free()
	_main = null

func _grant(amounts: Dictionary) -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null or not ("resources" in gs):
		return
	for res_id in amounts:
		gs.resources[res_id] = int(gs.resources.get(res_id, 0)) + int(amounts[res_id])

## Places at an exact world point, which is what the player's click does. Stakes snap
## to a finer grid than the tile, so placing them by tile would put one every two metres
## and photograph the wrong thing entirely.
## `type_id` put up whole in the cell under `at`, facing `facing` if it faces a way (AmmoTower.FACINGS).
func _build_at(type_id: String, at: Vector3, facing: int = 0) -> Node:
	if _main == null or _main.build_system == null:
		return null
	# Placed as a blueprint and then finished: that path is AP-free, and the harness is
	# not trying to test the action-point budget -- it wants a fence to photograph. The
	# first version paid AP and quietly stopped after three stakes.
	var b = _main.build_system.place_at(type_id, _main.grid_manager.world_to_build_cell(at),
		_main.buildings_container, true, facing)
	if b != null and b.has_method("complete_construction"):
		b.complete_construction()
	return b

func _build(type_id: String, cell: Vector2i) -> void:
	if _main != null and _main.has_method("place_building_at_cell"):
		var b = _main.place_building_at_cell(type_id, cell)
		if b != null and b.has_method("complete_construction"):
			b.complete_construction()

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

## Lets the GAME run for `seconds`, which is not the same as waiting for frames.
##
## Everything that moves moves in _physics_process, and physics is a fixed sixty ticks a
## second while process frames in a headless run are uncapped -- so a loop of 420 process
## frames is 420 frames of nothing in particular and about a second and a half of game.
## The gap scenario read "hero closed 12.7m of 16.0m" for a walk he finishes, with 0.12m
## to spare, in five seconds: the harness was stopping the clock early and reporting it as
## a Hero who could not get through. Same error in the raid loop, where twenty-two seconds
## of raid was a fraction of that, and the number moved every run.
func _advance(seconds: float) -> void:
	for i in range(int(round(seconds * 60.0))):
		await physics_frame

# ==============================================================================
# The camera
# ==============================================================================

func _shoot(beat: String) -> void:
	await _wait(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s_%s.png" % [OUT_DIR, _shot_index, _scenario, beat]
	var err := img.save_png(path)
	if err != OK:
		printerr("[playtest] could not write %s (err %d)" % [path, err])
		return
	_shot_index += 1
	print("[playtest] %s" % path)
