# res://tests/test_v05_the_players_hand_never_crashes_the_game.gd
# The player's own gestures, sent in the way the player's hand sends them.
#
# Reported as a crash: "木栅栏现在一造就弹出 Trying to assign an array of type "Array" to a
# variable of type "Array[Vector2i]"" -- EVERY single click that laid a stake stopped the
# game. The cause was one line in Main._unhandled_input: `_run_to(...) if _dragging else
# [_drag_from]`, where the array literal inside the ternary is not typed from the variable
# it lands in. Every drag test around it passed, because none of them went through the
# input handler: they set the drag's state by hand and called _commit_run with an array
# they had typed themselves -- so the one line that turns a click into that array was the
# one line nothing ran.
#
# Two rules for this file, both from that:
#
#   1. Gestures go in as InputEvents -- through Main._unhandled_input, or through the
#      engine's own input pipeline -- at screen positions worked out from the camera.
#      Never by setting the handler's state and calling what it would have called.
#   2. It leans on the runner: any SCRIPT ERROR logged while a test runs fails that test
#      (tests/script_error_watch.gd), so a gesture that crashes is a failure even where
#      nothing else here would notice.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	# Nothing held down may leak into the next test: the camera polls held keys.
	for key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_F, KEY_V]:
		var up := InputEventKey.new()
		up.keycode = key
		up.physical_keycode = key
		up.pressed = false
		Input.parse_input_event(up)
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null and "is_paused" in game_state_node:
		game_state_node.is_paused = false
	super.after_each()

# ==============================================================================
# The level, and a hand to use it with
# ==============================================================================

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(8)      # the navigation maps need two syncs before anything is asked of them
	if game_state_node and "resources" in game_state_node:
		for res in ["wood", "stone", "bone", "food", "water"]:
			game_state_node.resources[res] = 4000
	return main

## Picks a building the way the build menu does.
func _select(main: Node, type_id: String) -> void:
	if main.hud != null and is_instance_valid(main.hud) and main.hud.has_method("select_build_type"):
		main.hud.select_build_type(type_id)
	else:
		main.on_build_selected(type_id)

## A spot of open field near the middle of the view that `type_id` can be built on.
func _open_spot(main: Node, type_id: String) -> Vector3:
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	for offset in [Vector3(-5.0, 0.0, 5.0), Vector3(5.0, 0.0, 5.0), Vector3(-6.0, 0.0, -2.0), Vector3(6.0, 0.0, -3.0),
			Vector3(0.0, 0.0, 8.0), Vector3(-8.0, 0.0, 8.0)]:
		var at: Vector3 = core + offset
		if main.build_system.can_place_building(type_id, gm.world_to_cell(at), false, at):
			return at
	return Vector3.INF

func _px(main: Node, world: Vector3) -> Vector2:
	return main.camera.unproject_position(world)

func _button(main: Node, at: Vector2, index: int, pressed: bool, shift: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.pressed = pressed
	e.position = at
	e.global_position = at
	e.shift_pressed = shift
	main._unhandled_input(e)

func _motion(main: Node, at: Vector2, from: Vector2, mask: int = 0, shift: bool = false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = at - from
	e.button_mask = mask
	e.shift_pressed = shift
	main._unhandled_input(e)

func _key(main: Node, keycode: int, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		e.ctrl_pressed = ctrl
		main._unhandled_input(e)

## A left click: down and up again in the same place, as a click is.
func _click(main: Node, at: Vector2, index: int = MOUSE_BUTTON_LEFT) -> void:
	_button(main, at, index, true)
	_button(main, at, index, false)

func _count(main: Node, type_id: String) -> int:
	var n: int = 0
	for b in main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and ("building_type" in b) and String(b.building_type) == type_id:
			n += 1
	return n

# ==============================================================================
# 1. Laying things down
# ==============================================================================

func test_01_one_click_lays_one_stake() -> void:
	# The crash itself. Press, let go, same place: one stake, and the game still running.
	var main = await _level()
	_select(main, "wall")
	var spot: Vector3 = _open_spot(main, "wall")
	assert_ne(spot, Vector3.INF, "There is open ground to build on")
	if spot == Vector3.INF:
		return
	_click(main, _px(main, spot))
	await wait_frames(2)
	assert_eq(_count(main, "wall"), 1, "One click, one stake")
	assert_eq(main.current_build_type, "wall", "And the fence tool is still in hand for the next one")

func test_02_clicking_stake_after_stake_keeps_working() -> void:
	# Not just the first: the report was "一造就" -- every time.
	var main = await _level()
	_select(main, "wall")
	var spot: Vector3 = _open_spot(main, "wall")
	if spot == Vector3.INF:
		_record_fail("No open ground")
		return
	for i in range(4):
		_click(main, _px(main, spot + Vector3(float(i) * 0.9, 0.0, 0.0)))
		await wait_frames(1)
	assert_eq(_count(main, "wall"), 4, "Four clicks, four stakes")

func test_03_a_drag_lays_a_run() -> void:
	var main = await _level()
	_select(main, "wall")
	var from: Vector3 = _open_spot(main, "wall")
	if from == Vector3.INF:
		_record_fail("No open ground")
		return
	var to: Vector3 = from + Vector3(4.0, 0.0, 0.0)
	var a: Vector2 = _px(main, from)
	var b: Vector2 = _px(main, to)
	_button(main, a, MOUSE_BUTTON_LEFT, true)
	var last: Vector2 = a
	for step in range(1, 9):
		var at: Vector2 = a.lerp(b, float(step) / 8.0)
		_motion(main, at, last, MOUSE_BUTTON_MASK_LEFT)
		last = at
		await wait_frames(1)
	_button(main, b, MOUSE_BUTTON_LEFT, false)
	await wait_frames(2)
	assert_gt(_count(main, "wall"), 3, "One drag, a whole run of stakes")

func test_04_a_click_places_a_turret() -> void:
	var main = await _level()
	_select(main, "tower")
	var spot: Vector3 = _open_spot(main, "tower")
	assert_ne(spot, Vector3.INF, "There is open ground for a turret")
	if spot == Vector3.INF:
		return
	_click(main, _px(main, spot))
	await wait_frames(2)
	assert_eq(_count(main, "tower"), 1, "One click, one turret")

func test_05_a_click_on_ground_that_cannot_be_built_on_places_nothing() -> void:
	# On top of a hill, and on the cabin's own ground: refused, quietly, with the game
	# still running.
	#
	# Aimed where the build ray actually lands. It hits the ground layer only -- the
	# ground and the hills -- so aimed at a hill's FOOT from this camera it meets the
	# side of the hill first, at the edge of the open cell in front of it, where a stake
	# is perfectly allowed; and aimed at the cabin's ROOF it passes through the cabin
	# (buildings are not on that layer) and lands on the open ground behind it, which is
	# where the ghost shows the stake would go.
	var main = await _level()
	var gm = main.grid_manager
	var hill_top := Vector3.UP * float(config_node.MAP["hill_height"])
	for type_id in ["wall", "tower"]:
		_select(main, type_id)
		var hill: Vector3 = gm.cell_to_world(config_node.MAP["default_blocked_cells"][0]) + hill_top
		var cabin: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
		_click(main, _px(main, hill))
		_click(main, _px(main, cabin))
		await wait_frames(1)
		assert_eq(_count(main, type_id), 0, "No %s on a hill or in the cabin" % type_id)

# ==============================================================================
# 2. Everything else the hand does
# ==============================================================================

func test_06_cancelling_in_every_way_there_is() -> void:
	var main = await _level()
	var spot: Vector3 = _open_spot(main, "wall")
	if spot == Vector3.INF:
		_record_fail("No open ground")
		return
	# Escape with the fence in hand, then a right-click with it, then Escape half-way
	# through a drag: each lays nothing.
	_select(main, "wall")
	_motion(main, _px(main, spot), _px(main, spot))
	_key(main, KEY_ESCAPE)
	assert_eq(main.current_build_type, "", "Escape puts the tool down")
	_select(main, "wall")
	_click(main, _px(main, spot), MOUSE_BUTTON_RIGHT)
	assert_eq(main.current_build_type, "", "So does a right-click")
	_select(main, "wall")
	_button(main, _px(main, spot), MOUSE_BUTTON_LEFT, true)
	_motion(main, _px(main, spot + Vector3(3.0, 0.0, 0.0)), _px(main, spot), MOUSE_BUTTON_MASK_LEFT)
	_key(main, KEY_ESCAPE)
	_button(main, _px(main, spot + Vector3(3.0, 0.0, 0.0)), MOUSE_BUTTON_LEFT, false)
	await wait_frames(1)
	assert_eq(_count(main, "wall"), 0, "And nothing was laid by any of it")

func test_07_selecting_and_ordering_the_hero() -> void:
	var main = await _level()
	var hero = main.hero
	assert_not_null(hero, "There is a Hero")
	if hero == null:
		return
	_click(main, _px(main, hero.global_position + Vector3(0.0, 0.8, 0.0)))     # select him
	var ground: Vector3 = _open_spot(main, "wall")
	_click(main, _px(main, ground), MOUSE_BUTTON_RIGHT)                          # send him
	await wait_frames(3)
	_click(main, _px(main, ground + Vector3(3.0, 0.0, 3.0)))                    # empty ground: deselect
	var tree_node: Node = null
	for n in main.resource_nodes_container.get_children():
		if "resource_type" in n and String(n.resource_type) == "wood":
			tree_node = n
			break
	if tree_node != null:
		_click(main, _px(main, (tree_node as Node3D).global_position + Vector3(0.0, 1.0, 0.0)), MOUSE_BUTTON_RIGHT)
	await wait_frames(3)
	assert_true(is_instance_valid(hero), "The Hero is still there after all of it")

func test_08_every_key_the_game_listens_for() -> void:
	var main = await _level()
	var controls: Dictionary = config_node.CONTROLS
	# Pressed and released one at a time, with the fence in hand and without.
	var keys: Array = [KEY_PAGEUP, KEY_PAGEDOWN, KEY_EQUAL, KEY_MINUS, int(controls["camera_reset_key"]),
		int(controls["pause_key"]), int(controls["pause_key"])]
	for with_tool in [false, true]:
		if with_tool:
			_select(main, "wall")
		for k in keys:
			_key(main, k)
			await wait_frames(1)
		_key(main, KEY_EQUAL, true)
		_key(main, KEY_MINUS, true)
		_key(main, KEY_0, true)
	# Escape until there is nothing left to cancel, which opens the pause menu, and once
	# more to close it again.
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	await wait_frames(2)
	assert_false(game_state_node.is_paused, "Two presses of pause cancel out")
	assert_true(is_instance_valid(main.camera), "The camera is still there")

func test_09_the_camera_keys_held_down() -> void:
	# The camera polls held keys every frame, so these go in through the engine's own
	# input, as a real keyboard's do.
	var main = await _level()
	var controls: Dictionary = config_node.CONTROLS
	for k in [KEY_LEFT, KEY_UP, KEY_A, KEY_D, int(controls["camera_rotate_left_key"]),
			int(controls["camera_rotate_right_key"]), int(controls["camera_tilt_up_key"]), int(controls["camera_tilt_down_key"])]:
		var down := InputEventKey.new()
		down.keycode = k
		down.physical_keycode = k
		down.pressed = true
		Input.parse_input_event(down)
		await wait_frames(5)
		var up := InputEventKey.new()
		up.keycode = k
		up.physical_keycode = k
		up.pressed = false
		Input.parse_input_event(up)
		await wait_frames(1)
	assert_true(is_instance_valid(main.camera), "The camera survived every key")

func test_10_the_mouse_wheel_and_middle_drag() -> void:
	var main = await _level()
	var centre: Vector2 = _px(main, main.grid_manager.cell_to_world(config_node.MAP["default_core_cell"]))
	for index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_click(main, centre, index)
	_button(main, centre, MOUSE_BUTTON_MIDDLE, true)
	_motion(main, centre + Vector2(40.0, 10.0), centre, MOUSE_BUTTON_MASK_MIDDLE)
	_motion(main, centre + Vector2(60.0, 30.0), centre + Vector2(40.0, 10.0), MOUSE_BUTTON_MASK_MIDDLE, true)
	_button(main, centre + Vector2(60.0, 30.0), MOUSE_BUTTON_MIDDLE, false)
	await wait_frames(2)
	assert_true(is_instance_valid(main.camera), "The view moved and the game did not fall over")

func test_11_a_click_through_the_engines_own_input_pipeline() -> void:
	# Everything above calls the handler directly. This once goes the whole way a real
	# click goes -- into the engine, past the HUD, into _unhandled_input -- because a
	# crash could as easily live on that road as in the handler.
	var main = await _level()
	_select(main, "wall")
	var spot: Vector3 = _open_spot(main, "wall")
	if spot == Vector3.INF:
		_record_fail("No open ground")
		return
	var at: Vector2 = _px(main, spot)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await wait_frames(2)
	assert_eq(_count(main, "wall"), 1, "A real click lays a real stake")

# ==============================================================================
# 3. The trap itself
# ==============================================================================

func test_12_no_array_literal_is_handed_to_a_typed_array_through_a_ternary() -> void:
	# `var cells: Array[Vector2i] = _run_to(p) if _dragging else [_drag_from]` compiles,
	# and crashes at run time on the else side: an array literal is typed from the
	# variable it is assigned to only when it is assigned DIRECTLY, never from inside a
	# ternary. The tests above cover the one place it happened; this keeps the pattern
	# out of every script, including paths no test reaches.
	var typed_ternary := RegEx.new()
	typed_ternary.compile(r":\s*Array\[[^\]]+\]\s*=.*\bif\b.*\belse\b")
	var literal := RegEx.new()
	literal.compile(r"(^|[=,(\s])\[")
	var offenders: Array[String] = []
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			stack.append(dir_path.path_join(sub))
		for file_name in dir.get_files():
			if not file_name.ends_with(".gd"):
				continue
			var path: String = dir_path.path_join(file_name)
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for i in range(lines.size()):
				var code: String = lines[i].get_slice("#", 0)
				var m := typed_ternary.search(code)
				if m == null:
					continue
				# Only a literal on either side of the ternary is the trap.
				var rhs: String = code.substr(code.find("=", code.find("Array[")) + 1)
				if literal.search(rhs) != null:
					offenders.append("%s:%d  %s" % [path, i + 1, lines[i].strip_edges()])
	assert_eq(offenders.size(), 0, "No typed array is given an array literal through a ternary: %s" % str(offenders))
