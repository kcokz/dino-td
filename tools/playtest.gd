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
		"buildmenu":
			await _scenario_buildmenu()
		"menu":
			await _scenario_menu()
		"paused":
			await _scenario_paused()
		_:
			print("[playtest] unknown scenario: %s" % name)
	_tear_down()

# ==============================================================================
# Scenarios
# ==============================================================================

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
	gs.stock_meal("meat")
	gs.stock_meal("meat")
	gs.stock_meal("prime_meat")
	hero.current_hp = hero.max_hp * 0.6      # hurt, so the heal is seen
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
	_main.enter_cabin()
	var kitchen: Node = _main.cabin_interior.station("kitchen") if _main.cabin_interior else null
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
	_main.leave_cabin()
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
	_main.enter_cabin()
	var bench: Node = _main.cabin_interior.station("beacon") if _main.cabin_interior else null
	if bench and eb:
		eb.unit_selected.emit(bench)
	await _shoot("bench")
	for i in range(int(gs.beacon_stage_count())):
		gs.finish_beacon_job(String(gs.beacon_next_job()))
	if bench and eb:
		eb.unit_selected.emit(bench)
	await _shoot("ready_to_launch")
	gs.finish_beacon_job(String(gs.beacon_next_job()))
	_main.leave_cabin()
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
## long run.
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
	var around: int = 0 if bare else int(ceil(TAU * 6.5 / float(cfg.BUILD_CELL))) * 4
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
	for i in range(towers if not ring.is_empty() else 0):
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
	wm.auto_raid_enabled = false
	if every_side:
		wm.final_wave = true
		wm._entry_turn = 0
	wm.start_wave(1, raiders)
	if every_side:
		var beacon: Dictionary = gs.map_data()["beacon"]
		wm.spawn_timer.start(float(beacon["charge_seconds"]) * float(beacon["stream_share"]) / float(raiders))
	var seconds: int = 0
	while wm.is_wave_active and not gs.is_game_over and seconds < 400:
		await _advance(1.0)
		seconds += 1
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

## Paused with the menu shut: the frame and the word (UI-POLISH T9).
func _scenario_paused() -> void:
	var gs := root.get_node_or_null("GameState")
	_grant({"wood": 12, "stone": 3, "bone": 1})
	gs.set_paused(true)
	await _shoot("paused")

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

## Inside the cabin. The interior is the same world 200 metres down, so anything
## wrong with the environment shows here first.
##
## The room as a new run finds it -- the beacon's mast down, the spit over the fire, an
## empty tool board -- then fitted out: every tool on the board, the pot on the fire, the
## beacon repaired and waiting; and a meal under way at the kitchen.
func _scenario_cabin() -> void:
	if not _main.has_method("enter_cabin"):
		return
	_main.enter_cabin()
	await _wait(6)
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
	var kitchen: Node = _main.cabin_interior.station("kitchen") if _main.cabin_interior else null
	if kitchen and eb:
		eb.unit_selected.emit(kitchen)
	await _wait(4)
	await _shoot("inside_fitted_out")
	if kitchen:
		for job in kitchen.jobs():
			if kitchen.can_afford(job) and kitchen.begin(job):
				break
		if kitchen.active_recipe != "":
			kitchen.work(kitchen.time_of(kitchen.active_recipe) * 0.4)
	await _wait(4)
	await _shoot("inside_cooking")

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
	cam.current = true
	await _shoot(name)
	cam.current = false
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
