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
		"showcase":
			await _scenario_showcase()
		"scale":
			await _scenario_scale()
		"cast":
			await _scenario_cast()
		"gaits":
			await _scenario_gaits()
		"kitchen":
			await _scenario_kitchen()
		"eating":
			await _scenario_eating()
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
## granted, nothing placed by hand: pick up the opening wood, ring the cabin with palisade and a
## gate at its door, chop trees until the raid, stand inside the ring while it comes, gather what
## it leaves, go in and make the pick, cook and eat, then quarry stone and set a crossbow. A line
## of what is happening every ten seconds of game time, and a frame at each beat.
##
## `play:<minutes>` plays that long (default 8), at the game's own 3x.
func _scenario_play(spec: String) -> void:
	var parts: PackedStringArray = spec.split(":")
	var minutes: float = float(parts[1]) if parts.size() > 1 else 8.0
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
	eb.meal_eaten.connect(func(m): note.call("ate %s" % str(m.get("dish", ""))))
	eb.hero_died.connect(func(): note.call("THE HERO DIED"))
	eb.game_lost.connect(func(): note.call("GAME LOST"))
	eb.game_won.connect(func(): note.call("GAME WON -- the jump home"))
	eb.beacon_launched.connect(func(): note.call("BEACON LAUNCHED -- the final wave"))
	eb.beacon_changed.connect(func(n): note.call("beacon: %d steps done" % n))
	eb.cabin_view_changed.connect(func(inside): note.call("he is %s the cabin" % ("in" if inside else "out of")))

	# --- 1. The opening wood --------------------------------------------------------------
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

	# --- 2. A ring of palisade round the cabin, a cell out, a gate at the door -----------
	var centre: Vector2i = gm.world_to_build_cell(cabin.global_position)
	var half := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
	var gate_cell: Vector2i = centre + Vector2i(0, half.y + 1)
	_main.on_build_selected("gate")
	var gate = _main.try_place_at_cell(gm.world_to_cell(gm.build_cell_to_world(gate_cell)), gm.build_cell_to_world(gate_cell))
	note.call("gate ordered: %s" % ("yes" if gate else "NO"))
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
		if cell == gate_cell or _main.current_build_type == "":
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
	while wm.current_wave == 0 and _play_clock < minutes * 60.0:
		await _chop_a_while(hero, "wood", 8.0)
		if wm.raid_timer < 8.0:
			break
	note.call("wood: %d; raid in %.0fs" % [int(gs.resources.get("wood", 0)), wm.raid_timer])

	# --- 4 onwards: raids come and go; between them, what a player would do next -------------
	# In order: the beacon when its next step can be paid; a meal when there is meat and none is
	# put by, and eating one when he is not fed; the pick, then the axe; his row once the hide comes
	# in -- armour, boots, the bone spear, the stone pick; a set crossbow north of the ring, facing
	# the nest, up to four; the ring mended where a raid broke it; and otherwise stone
	# while there is less than a crossbow's worth, and wood. Launched, he shelters till the end.
	var last_status: float = -100.0
	var raids_seen: int = 0
	var crossbow_cells: Array[Vector2i] = []
	for x in [-3, -1, 1, 3]:
		crossbow_cells.append(centre + Vector2i(x, -half.y - 2))
	var shots_taken: Dictionary = {}
	while _play_clock < minutes * 60.0 and not gs.is_game_over:
		# At least a frame every time round: a step that finds nothing to wait for (the raid
		# about to set out, a job it cannot start) must not spin the loop with the game held still.
		await _advance(0.1)
		_play_clock += 0.1 * Engine.time_scale
		if _play_clock - last_status >= 20.0:
			last_status = _play_clock
			note.call(_play_status(hero, cabin, gs, wm))
		# Launched, the valley answers after a grace (MAPS.beacon.launch_grace): he works through
		# it like any quiet spell -- mending, building -- and shelters only once they are out.
		if wm.is_wave_active or wm.final_wave:
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
			var home: Vector3 = cabin.door_inside()
			# In the final wave it is the cabin that is bitten: he goes out to what is at it, as a
			# player would, while he has the health for it -- and eats when he has not.
			var launched: bool = wm.final_wave or gs.is_beacon_launched()
			# Launched, he is sent out at what is at the cabin, as a click sends him; in a raid he
			# fights only what has got to him on his side of the wall (Hero._find_nearest_enemy).
			var near: Node3D = _nearest_dino(hero, 9.0) if launched else hero._find_nearest_enemy(3.0)
			var hurt: bool = hero.current_hp < hero.max_hp * 0.35
			if hurt and not gs.meals.is_empty() and int(hero.current_state) != 6:
				hero.order_eat(String(gs.meals.keys()[0]))
			elif near != null and not (hurt and launched):
				if hero.target_enemy != near:
					hero.order_attack(near)
			elif hero.global_position.distance_to(home) > 1.5 and int(hero.current_state) != 1:
				hero.move_to(home)
			await _advance(1.0)
			_play_clock += Engine.time_scale
			continue
		if wm.current_wave > raids_seen:
			raids_seen = wm.current_wave
			await _gather_drops(hero, note)
			continue
		var wb = cabin.station("workbench")
		var kitchen = cabin.station("kitchen")
		var beacon_job: String = String(gs.beacon_next_job())
		var pick_flag: String = String(cfg.RECIPES["stone_pick"]["unlocks"])
		if beacon_job != "" and cabin.station(String(cfg.BEACON_STATION)).can_afford(beacon_job):
			await _bench_job(hero, cabin, String(cfg.BEACON_STATION), beacon_job, note)
			continue
		# The part the next stage takes, out of its wreck, once the rest of its price is in -- while
		# nothing guards it (the battery's wreck is behind the nest, and is searched by night), and not
		# with a raid about to set out: it set off and turned back every step till the raid came.
		var wreck: Node = _wreck_to_search(beacon_job) if wm.raid_timer >= 6.0 else null
		if wreck != null:
			note.call("to the wreck for the %s" % String(wreck.resource_type))
			await _search_wreck(hero, wreck)
			continue
		var dish: String = ""
		for job in kitchen.jobs():
			if kitchen.is_dish(job) and kitchen.can_afford(job):
				dish = job
		# A meal put by, and more once the beacon is next: the last fight is fought on them.
		var put_by: int = 0
		for key in gs.meals:
			put_by += int(gs.meals[key])
		if dish != "" and (put_by == 0 or (put_by < 3 and beacon_job != "" and not beacon_job.begins_with("beacon_1"))):
			await _bench_job(hero, cabin, "kitchen", dish, note)
			continue
		if not gs.meals.is_empty() and (gs.fed.is_empty() or hero.current_hp < hero.max_hp * 0.6):
			hero.order_eat(String(gs.meals.keys()[0]))
			await _play_until(func(): return int(hero.current_state) != 6, 10.0, "eating")
			continue
		if not gs.has_unlock(pick_flag) and wb.can_afford("stone_pick"):
			await _bench_job(hero, cabin, "workbench", "stone_pick", note)
			continue
		if wb.can_offer("stone_axe") and wb.can_afford("stone_axe"):
			await _bench_job(hero, cabin, "workbench", "stone_axe", note)
			continue
		# His row as a player fills it (v0.6 round three): armour and boots first -- they cost what
		# the elites and the raids leave, not the crossbows' stone -- then the spear, the stone pick.
		var kit_job: String = ""
		for job in ["bone_armor", "hide_vest", "hide_boots", "bone_spear", "quarry_pick"]:
			if kit_job == "" and wb.can_offer(job) and wb.can_afford(job):
				kit_job = job
		if kit_job != "":
			await _bench_job(hero, cabin, "workbench", kit_job, note)
			continue
		var next_bow: Vector2i = Vector2i(999, 999)
		for c in crossbow_cells:
			if gm.building_in_build_cell(c) == null:
				next_bow = c
				break
		if next_bow.x != 999 and gs.can_afford(cfg.BUILDINGS["set_crossbow"]["cost"]):
			_main.on_build_selected("set_crossbow")
			_main._placement_facing = 0
			var b = _main.try_place_at_cell(gm.world_to_cell(gm.build_cell_to_world(next_bow)), gm.build_cell_to_world(next_bow))
			_main.cancel_building_selection()
			note.call("set crossbow ordered at %s: %s" % [str(next_bow), "yes" if b else "NO"])
			await _play_until(func(): return _unfinished() == 0, 40.0, "building a crossbow")
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
			await _play_until(func(): return _unfinished() == 0, 40.0, "mending the ring")
			continue
		# Wood first while there is not enough put by to mend the ring: crossbows eat the stone as
		# fast as it comes, and a bot that only quarried let the ring fall for want of a stake.
		if int(gs.resources.get("wood", 0)) < 8:
			await _chop_a_while(hero, "wood", 8.0)
		elif gs.has_unlock(pick_flag) and int(gs.resources.get("stone", 0)) < 8:
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
		"cook":
			var k = cabin.station("kitchen")
			for job in k.jobs():
				if k.is_dish(job) and k.can_afford(job):
					return true
			return false
		"eat":
			return not gs.meals.is_empty()
		"stone":
			return gs.has_unlock(String(root.get_node("Config").RECIPES["stone_pick"]["unlocks"]))
		"crossbow":
			return gs.can_afford(root.get_node("Config").BUILDINGS["set_crossbow"]["cost"])
		"beacon":
			var job: String = String(gs.beacon_next_job())
			return job != "" and cabin.station(String(root.get_node("Config").BEACON_STATION)).can_afford(job)
	return true

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
		_play_clock += 0.25 * Engine.time_scale
		# Out in the dark he carries a torch, as a player does: the night's hunters are out for a man without
		# one (GAME-DESIGN 9.3). Without, the bot was bitten to death on the small valley's first night, run
		# after run (the debug-agent's note of 2026-09-29).
		if hero.has_method("can_light_torch") and hero.can_light_torch() \
				and not bool(_main.current_core.is_inside(hero.global_position)) and hero.light_torch():
			print("[play %5.1fs] lit a torch, out in the dark while %s" % [_play_clock, what])
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
	if best == null:
		print("[play] nothing of %s he can work" % res_id)
		await _advance(seconds / Engine.time_scale)
		_play_clock += seconds
		return
	hero.order_harvest(best)
	var wm = _main.wave_manager
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
		if is_instance_valid(n) and String(n.resource_type) == part and int(n.current_amount) > 0 and not _guarded(n):
			return n
	return null

## Out to the wreck `node` and through it, till its part is in the stock -- or a raid is coming. What its din
## brings (Din) he does not stand and fight bare-handed: he goes in and waits for it to give up -- one brought
## out of its hours goes back once he is out of its reach -- and comes back to the wreck, as a player learns
## to. Standing, the bot was bitten to death at the river's antenna on its first day.
func _search_wreck(hero: Node, node: Node) -> void:
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
		_main.order_enter_cabin()
		# (The run lost while he waits, the cabin may be gone: asked of what is still there.)
		await _play_until(func():
			var core = _main.current_core
			return gs.is_game_over or (core != null and is_instance_valid(core) and core.hero_inside 				and _drawn_near(core, 12.0) == null), 60.0, "in the cabin, waiting out the din")

## The animals a wreck's din brought that the log has named.
var _din_said: Dictionary = {}

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
	_main._walk_to_bench(bench)
	await _play_until(func(): return cabin.hero_inside and int(hero.current_state) == 0, 40.0, "walking to the %s" % bench_id)
	if not cabin.hero_inside:
		note.call("did not get into the cabin for the %s" % bench_id)
		return
	var began: bool = bench.begin(job)
	note.call("%s at the %s: %s" % [job, bench_id, "begun" if began else "REFUSED"])
	if bench_id == "kitchen" and began:
		await _shoot("cooking")
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
		["idle", "moving", "building", "attacking", "DEAD", "harvesting", "eating"][int(hero.current_state)],
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
	_main._end_drag()
	_main.cancel_building_selection()
	await _wait(4)
	await _portrait("cabin_side", centre + Vector3(1.0, 0.0, 0.0), 8.0, true)

## Eating (v0.6 round two: "吃饭也是一个图标……吃了饭之后会有一个 boost"): his card -- his three bars,
## his commands as icons, a count of meals on the eat command -- and the eat page with meals
## cooked; then him eating, the meat in his hand at his mouth; then fed -- the boost gold on the
## end of his bars, the meal and its time under them, and the ring at his feet.
func _scenario_eating() -> void:
	var gs := root.get_node("GameState")
	var hero = _main.hero
	var panel = _main.hud.option_panel
	if hero == null or panel == null:
		return
	hero.set_physics_process(true)
	panel.select_target(hero)
	_main.hud.toggle_hero_details()    # his sheet: his bars are on it (v0.6 round four)
	gs.stock_meal("meat")
	gs.stock_meal("meat")
	gs.stock_meal("prime_meat")
	hero.current_hp = hero.max_hp * 0.6      # hurt, so the heal is seen
	# Two tools made, so his ability slots have something in them (round three, 4).
	var cfg_tools := root.get_node("Config")
	for recipe_id in cfg_tools.RECIPES.keys().slice(0, 2):
		gs.grant_unlock(String(cfg_tools.RECIPES[recipe_id].get("unlocks", "")))
	await _wait(6)
	await _shoot("card")
	panel._on_eat_pressed()
	await _wait(4)
	await _shoot("eat_page")
	panel._trigger_eat(gs.meal_key("meat", String(root.get_node("Config").cooking_method(gs.unlocks).get("id", ""))))
	await _advance(0.6)
	await _portrait("eating", hero.global_position, 2.6, false, true)
	await _advance(float(root.get_node("Config").EATING["eat_seconds"]))
	await _wait(6)
	await _shoot("fed")
	await _portrait("fed", hero.global_position, 3.5)

## The kitchen and what eating does (v0.6): its menu before the stone pot is made and
## after -- the same meat cooked a new way -- and then, fed, the line under the top bar that
## says how much faster he is and for how long.
func _scenario_kitchen() -> void:
	var gs := root.get_node_or_null("GameState")
	var cfg := root.get_node_or_null("Config")
	var eb := root.get_node_or_null("EventBus")
	_grant({"food": 2, "prime_meat": 1})
	await _walk_in()
	var kitchen: Node = _main.current_core.station("kitchen")
	if kitchen and eb:
		eb.unit_selected.emit(kitchen)
	await _shoot("menu_before_the_pot")
	if gs and cfg:
		gs.grant_unlock(String(cfg.COOKING_METHODS[0]["vessel"]))
	if kitchen and eb:
		eb.unit_selected.emit(kitchen)
	await _shoot("menu_with_the_pot")
	if gs:
		gs.eat("meat")
	await _walk_out()
	await _shoot("fed")

## The v0.6 buildings side by side, south of the cabin where nothing else stands: a run of
## a palisade, a run of bone palisade, a stone wall, and in front of the line a trip bow and two
## set crossbows, one improved where it stands, their wires out across the ground -- and then a
## set crossbow's panel, offering the improvement and what it changes.
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
	# Facing south, away from the line: their lanes across the ground a raid comes over.
	_build_at("set_crossbow", Vector3(-3.0, 0.0, z + step), 2)
	_build_at("set_crossbow", Vector3(1.0, 0.0, z + step), 2)
	_build_at("trip_bow", Vector3(4.0, 0.0, z + step), 2)
	var gm = _main.grid_manager
	var upgraded = gm.building_at_point(Vector3(1.0, 0.0, z + step))
	if upgraded and upgraded.has_method("begin_upgrade") and upgraded.begin_upgrade():
		upgraded.add_upgrade_progress(1000.0)
	await _wait(10)
	await _portrait("the_line", Vector3(-1.0, 0.0, z + 1.0), 11.0)
	await _portrait("the_line_from_above", Vector3(-1.0, 0.0, z), 11.0, true)
	var plain = gm.building_at_point(Vector3(-3.0, 0.0, z + step))
	if plain and eb:
		eb.unit_selected.emit(plain)
	await _shoot("upgrade_offered")

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
## A sealed ring of palisade round the cabin with N set crossbows set into it, facing out, their
## wires across the ground a raid comes over and chews the ring from -- where a player sets
## them -- against one raid of that many raptors at that hit-point multiplier (what GameState
## compounds after each big wave), sent the way the game sends it: down the path from the nest,
## or -- with `all` -- streamed from every way in, as the beacon's final wave is. It prints what
## got through and what it cost, so the raid curve in Config is tuned against a base rather than
## a guess. `twin` sets the improved set crossbow instead. Real game, real speed: a long raid is a
## long run. `inside` sets the traps in a yard inside the ring instead, facing out over it, the
## ring whole -- the base a player built (v0.6 round three, "摆成这样的时候，恐龙进攻又会傻站着不攻击了"),
## printing every few seconds what the raid is doing.
func _scenario_siege(spec: String) -> void:
	var parts: PackedStringArray = spec.split(":")
	var towers: int = int(parts[1]) if parts.size() > 1 else 4
	var raiders: int = int(parts[2]) if parts.size() > 2 else 10
	var hp_mult: float = float(parts[3]) if parts.size() > 3 else 1.0
	var every_side: bool = parts.size() > 4 and parts[4] == "all"
	# "bare": no ring -- the cabin and its own gun against the raid (v0.6).
	var bare: bool = parts.size() > 4 and parts[4] == "bare"
	# "twin" anywhere after: the traps improved where they stand, as a late base has them.
	var trap_type: String = "set_crossbow_2" if parts.slice(4).has("twin") else "set_crossbow"
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
	_grant({"wood": 4000, "stone": 4000, "bone": 4000})
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
	# The traps in the ring, spread over the side facing the nest (north) for a raid from the
	# nest, all round for the final wave; each facing straight out.
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
		trap_cells[nearest] = facing
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
		if (seconds == 15 or seconds == 60) and OS.has_environment("SIEGE_DEBUG"):
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
	eb.raid_summary.emit({"wave": 12, "killed": 39, "drops": {"food": 38, "bone": 40, "prime_meat": 1},
		"lost": {"wall": 6, "set_crossbow": 1, "stone_wall": 2}})
	await _shoot("raid_over")

## What a material is for and where it comes from (v0.6 T2): the line the first bone
## brings, and the build menu's reason for a set crossbow before the pick has been made.
func _scenario_legible() -> void:
	var eb := root.get_node_or_null("EventBus")
	eb.resource_picked_up.emit("bone", 1, null)
	await _shoot("first_bone")
	var panel = _main.hud.option_panel
	if panel and panel.has_method("_show_build_detail"):
		panel._show_build_detail("set_crossbow")
	await _shoot("why_no_crossbow")

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
	var kitchen = _main.current_core.station("kitchen")
	eb.unit_selected.emit(kitchen)
	await _wait(8)
	var job: Control = panel.button_container.get_child(0) as Control if panel.button_container.get_child_count() > 0 else null
	if job:
		root.get_viewport().warp_mouse(job.get_global_rect().get_center())
		await _wait(20)
	await _shoot("kitchen_menu")
	eb.raid_summary.emit({"wave": 3, "killed": 7, "drops": {"food": 6, "bone": 7, "prime_meat": 1},
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

## The pause menu and its settings page (UI-POLISH T16).
func _scenario_menu() -> void:
	_main.hud.toggle_pause_menu()
	await _shoot("root")
	var menu = _main.hud.pause_menu
	if menu and menu.has_method("open_settings"):
		menu.open_settings()
	await _shoot("settings")

## His row (v0.6 round three): the workbench with hide known -- what it offers now -- then his
## card with a pick, an axe, a spear, armour and boots in it, the armour's part on his bar in
## leather, and fed on the pot's meal besides so the three parts of his bar show together.
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
	for recipe_id in ["quarry_pick", "bone_spear", "hide_vest", "hide_boots", "stone_pot"]:
		gs.grant_unlock(String(cfg.RECIPES[recipe_id]["unlocks"]))
	gs.eat("meat")
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
	for recipe_id in ["stone_pick", "stone_axe", "stone_pot"]:
		gs.grant_unlock(String(cfg.RECIPES[recipe_id]["unlocks"]))
	gs.eat("meat")
	gs.stock_meal("meat")
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
## tool and the pot, him at the kitchen with a meal under way.
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
	_grant({"food": 3, "prime_meat": 1})
	var kitchen: Node = core.station("kitchen")
	if kitchen and eb:
		eb.unit_selected.emit(kitchen)
		_main._walk_to_bench(kitchen)
	await _advance(3.0)
	if kitchen:
		for job in kitchen.jobs():
			if kitchen.can_afford(job) and kitchen.begin(job):
				break
	await _advance(2.0)
	await _shoot("inside_cooking")
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

	# The traps, set and facing across the frame, their wires out along the ground.
	var bow_at: Vector3 = _main.grid_manager.cell_to_world(Vector2i(3, 2))
	_build_at("trip_bow", bow_at, 1)
	await _wait(4)
	await _portrait("trip_bow", bow_at + Vector3(1.0, 0.0, 0.0), 3.0)
	var crossbow_at: Vector3 = _main.grid_manager.cell_to_world(Vector2i(3, 4))
	_build_at("set_crossbow", crossbow_at, 1)
	await _wait(4)
	await _portrait("set_crossbow", crossbow_at + Vector3(1.0, 0.0, 0.0), 3.0)

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
func _scenario_cast() -> void:
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
	var lineup: Array = [["coelophysis", -1.2], ["coelophysis_alpha", 1.4], ["hesperosuchus", 3.8],
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
		"placerias", "raptor", "raptor_alpha", "big_theropod", "pterosaur"]
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

func _scenario_scale() -> void:
	if _main.hud:
		_main.hud.visible = false
	_grant({"wood": 40, "stone": 20})
	var core_at: Vector3 = _main.current_core.global_position
	# A row in front of the cabin's south wall, the cabin at its left end.
	var row_z: float = core_at.z + float(cfg_row_half()) + 1.4
	_build_at("wall", Vector3(core_at.x - 2.2, 0.0, row_z))
	_build_at("set_crossbow", _main.grid_manager.cell_to_world(Vector2i(-2, 0)))
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
		gs.reset_game()
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
## `type_id` put up whole in the cell under `at`, facing `facing` if it is a trap (Trap.FACINGS).
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
