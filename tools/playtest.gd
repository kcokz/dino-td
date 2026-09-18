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
		names = ["open", "fence", "cabin", "closeup", "gap", "raid"]

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
## Reported as "恐龙来进攻的时候并不会绕过栅栏去进攻 cabin，并且会停在离栅栏比较远的地方".
## The arc here is the one in that report: a curve of stakes in front of the wreck, open
## at both ends, which a raid is supposed to walk around.
##
## What it prints is ground COVERED. That is the only honest measure, because a dinosaur
## stalled against a fence and a dinosaur walking round it look identical in a still, and
## the failure this exists to catch is a raid that stops moving without stopping to eat.
##
## `raidsealed` walls the wreck in completely instead, which has to come out the other
## way: nobody gets through, and the fence is what gets chewed.
func _scenario_raid() -> void:
	_grant({"wood": 400})
	var cfg := root.get_node_or_null("Config")
	var gm = _main.grid_manager
	var sealed_ring: bool = OS.get_cmdline_user_args().has("raidsealed")
	var step: float = float(cfg.TILE_SIZE) / float(cfg.get_cell_divisions("wall"))
	var core: Vector3 = gm.cell_to_world(cfg.MAP["default_core_cell"])

	var placed: int = 0
	if sealed_ring:
		var seen: Dictionary = {}
		var around: int = int(ceil(TAU * 4.0 / step)) * 4
		for i in range(around):
			var a: float = TAU * float(i) / float(around)
			var at: Vector3 = core + Vector3(sin(a) * 4.0, 0.0, cos(a) * 4.0)
			var fine: Vector2i = gm.world_to_fine_cell(at, cfg.get_cell_divisions("wall"))
			if seen.has(fine):
				continue
			seen[fine] = true
			_build_at("wall", gm.fine_cell_to_world(fine, cfg.get_cell_divisions("wall")))
			placed += 1
	else:
		var n: int = 11
		for i in range(n):
			var ang: float = lerp(-0.9, 0.9, float(i) / float(n - 1))
			_build_at("wall", core + Vector3(sin(ang) * 5.0, 0.0, -cos(ang) * 5.0))
			placed += 1
	await _wait(4)

	var dino_script := load("res://scripts/entities/Dino.gd")
	var raid: Array[Node] = []
	var started: Array[float] = []
	for i in range(5):
		var d = dino_script.new()
		_main.add_child(d)
		d.setup("raptor")
		d.global_position = core + Vector3(-4.0 + float(i) * 2.0, 0.0, -18.0)
		d.set_waypoints([core])
		raid.append(d)
		started.append(d.global_position.distance_to(core))
	await _wait(4)
	await _portrait("raid_before", core + Vector3(0.0, 0.0, -7.0), 14.0, true)

	await _wait(18 * 60)

	var total: float = 0.0
	var chewing: int = 0
	for i in range(raid.size()):
		var d = raid[i]
		if not is_instance_valid(d):
			continue
		total += started[i] - d.global_position.distance_to(core)
		if int(d.current_state) == int(d.State.ATTACKING):
			chewing += 1
	print("[playtest] raid(%s): %d stakes, average %.1fm closed of %.1fm in 18s, %d biting"
		% ["sealed" if sealed_ring else "arc", placed, total / float(raid.size()), started[0], chewing])
	await _portrait("raid_after", core + Vector3(0.0, 0.0, -7.0), 14.0, true)

## Puts a camera at eye level a short way off `at`, looking at it, and takes one frame.
## The camera is removed again afterwards, so the level is left exactly as it was.
## `overhead` looks almost straight down instead, which is the only angle a GAP reads
## from: from eye level a stake in front of a rock and a stake beside one look the same.
func _portrait(name: String, at: Vector3, distance: float, overhead: bool = false) -> void:
	var cam := Camera3D.new()
	_main.add_child(cam)
	if overhead:
		cam.position = at + Vector3(0.0, distance, distance * 0.28)
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
