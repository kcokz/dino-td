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
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var names: Array = []
	for w in wanted:
		names.append(String(w))
	if names.is_empty():
		names = ["open", "fence", "cabin", "closeup", "gap", "raid", "hero", "wreck"]

	for name in names:
		await _run(String(name))

	print("[playtest] %d frames written to %s" % [_shot_index, OUT_DIR])
	quit(0)

func _run(name: String) -> void:
	_scenario = name
	await _fresh_level()
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
		_:
			print("[playtest] unknown scenario: %s" % name)
	_tear_down()

# ==============================================================================
# Scenarios
# ==============================================================================

## The first thing a player sees. The frame the whole visual MVP is judged on.
func _scenario_open() -> void:
	await _shoot("start")

## A fence going up, which is the one shape in the game that depends on its
## neighbours -- worth photographing rather than trusting.
func _scenario_fence() -> void:
	_grant({"wood": 400})
	var cfg := root.get_node_or_null("Config")
	var gm = _main.grid_manager
	var divisions: int = int(cfg.get_cell_divisions("wall")) if cfg else 1
	var step: float = float(cfg.TILE_SIZE) / float(maxi(1, divisions))

	# A run laid at the spacing stakes actually snap to, which is the whole point of the
	# finer grid: one stake per click, close enough together to read as a fence.
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
func _scenario_cabin() -> void:
	if _main.has_method("enter_cabin"):
		_main.enter_cabin()
	await _shoot("inside")

## Portraits of the models, from close enough to actually judge them.
##
## The game is played from eighteen metres up, where a two metre wreck is a smudge.
## That is the right camera for playing and the wrong one for deciding whether a model
## is any good -- reviewing art from the play camera is how you end up shipping a
## dinosaur that turns out to have no head. These shots exist only to be looked at.
func _scenario_closeup() -> void:
	_grant({"wood": 40, "stone": 20})
	var cfg := root.get_node_or_null("Config")
	var tile: float = float(cfg.TILE_SIZE) if cfg else 2.0
	var subjects: Array = [
		["wreck", Vector3(tile * 0.5, 0.0, tile * 0.5), 5.0],
		["nest", _main.grid_manager.cell_to_world(cfg.MAP["default_nest_cell"]), 7.0],
		["trees", _main.grid_manager.cell_to_world(Vector2i(4, -2)), 6.0],
		["stone", _main.grid_manager.cell_to_world(Vector2i(4, -6)), 5.0],
	]
	for s in subjects:
		await _portrait(String(s[0]), s[1], float(s[2]))

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
	var step: float = tile / float(maxi(1, int(cfg.get_cell_divisions("wall"))))

	# An outcrop the level put there itself, and ONE stake in the tile beside it, pushed
	# towards the rock so that most of that tile is plainly still open ground.
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
	await _wait(420)

	var span: float = start.distance_to(goal)
	var closed: float = span - hero.global_position.distance_to(goal)
	print("[playtest] gap: hero closed %.1fm of %.1fm" % [closed, span])
	await _portrait("gap_after", gm.cell_to_world(doorway), 9.0, true)

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
	var divisions: int = int(cfg.get_cell_divisions("wall"))
	var step: float = float(cfg.TILE_SIZE) / float(divisions)
	var core: Vector3 = gm.cell_to_world(cfg.MAP["default_core_cell"])

	var placed: int = 0
	if sealed_ring:
		var seen: Dictionary = {}
		var around: int = int(ceil(TAU * 4.0 / step)) * 4
		for i in range(around):
			var a: float = TAU * float(i) / float(around)
			var at: Vector3 = core + Vector3(sin(a) * 4.0, 0.0, cos(a) * 4.0)
			var fine: Vector2i = gm.world_to_fine_cell(at, divisions)
			if seen.has(fine):
				continue
			seen[fine] = true
			_build_at("wall", gm.fine_cell_to_world(fine, divisions))
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
		await process_frame
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
	for i in range(raid.size()):
		worst = maxf(worst, stall_max[i])
		if stall_max[i] >= 2.0:
			stalled += 1
		var d = raid[i]
		if not is_instance_valid(d):
			continue
		if d.global_position.distance_to(goal) < 3.0:
			arrived += 1
		if int(d.current_state) == int(d.State.ATTACKING):
			chewing += 1
	var worst_reversals: int = 0
	for n in reversals:
		worst_reversals = maxi(worst_reversals, n)
	print("[playtest] raid(%s, %s x%d): %d stakes | longest stall %.1fs | stalled>=2s %d | worst reversals %d | arrived %d | biting %d"
		% ["sealed" if sealed_ring else "arc",
			String(cfg.get_dino_script_path("raptor")).get_file(), raid.size(),
			placed, worst, stalled, worst_reversals, arrived, chewing])
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
func _build_at(type_id: String, at: Vector3) -> void:
	if _main == null or _main.build_system == null:
		return
	var cell: Vector2i = _main.grid_manager.world_to_cell(at)
	# Placed as a blueprint and then finished: that path is AP-free, and the harness is
	# not trying to test the action-point budget -- it wants a fence to photograph. The
	# first version paid AP and quietly stopped after three stakes.
	var b = _main.build_system.place_building(type_id, cell, _main.buildings_container, true, at)
	if b != null and b.has_method("complete_construction"):
		b.complete_construction()

func _build(type_id: String, cell: Vector2i) -> void:
	if _main != null and _main.has_method("place_building_at_cell"):
		var b = _main.place_building_at_cell(type_id, cell)
		if b != null and b.has_method("complete_construction"):
			b.complete_construction()

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

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
