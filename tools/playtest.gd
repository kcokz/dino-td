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
		names = ["open", "fence", "cabin", "closeup"]

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
	_grant({"wood": 40})
	for x in range(-2, 3):
		_build("wall", Vector2i(x, -3))
	_build("wall", Vector2i(2, -2))        # a corner, so the L shows
	await _wait(10)
	await _shoot("fence_line")

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

## Puts a camera at eye level a short way off `at`, looking at it, and takes one frame.
## The camera is removed again afterwards, so the level is left exactly as it was.
func _portrait(name: String, at: Vector3, distance: float) -> void:
	var cam := Camera3D.new()
	_main.add_child(cam)
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
