# res://tests/test_v05_the_view_turns.gd
# The player can look at their base from wherever they like.
#
# Asked for as "所有建筑类游戏都有的功能" -- pan, turn, tilt, zoom -- and the game had only
# pan and a zoom that drifted. That is not only a convenience. A FIXED BEARING HIDES
# THINGS: a stake is 0.95m and the cabin is 1.9m, so from the one angle the game offered,
# the near side of the cabin covered the ground behind it, and a ring of stakes sitting
# the same 0.523m from the cabin on all four sides read as flush on one side and a gap on
# the other. Two rounds of this conversation went into arguing about a picture that could
# not be looked at from anywhere else.
#
# The state is FOUR NUMBERS rather than a transform -- focus, yaw, tilt, distance -- which
# is what makes "not closer than 8 metres", "not tilted past 85 degrees" and "put it back
# where it started" things that can be said at all.
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

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func _rig() -> CameraRig:
	return CameraRig.new(config_node)

# ==============================================================================
# 1. It takes over without changing anything
# ==============================================================================

func test_01_the_scene_still_decides_where_the_game_opens() -> void:
	# The framing is NOT a constant in Config. The rig reads it off whatever the scene's
	# Camera3D is set to, so moving the camera in the editor still moves the opening shot
	# and there is no second copy of it to drift out of step.
	var main = _level()
	await wait_frames(4)
	var cam: Camera3D = main.camera
	assert_not_null(cam, "The level has a camera")
	assert_not_null(main.camera_rig, "And a rig driving it")

	var was_at: Vector3 = cam.global_position
	var was_aimed: Vector3 = -cam.global_transform.basis.z
	main.camera_rig.apply_to(cam)

	assert_almost_eq(cam.global_position.distance_to(was_at), 0.0, 0.001,
		"Applying the rig leaves the opening shot exactly where the scene put it")
	assert_almost_eq((-cam.global_transform.basis.z).distance_to(was_aimed), 0.0, 0.001,
		"Aimed exactly where the scene aimed it")

func test_02_and_what_it_read_is_a_view_of_the_ground() -> void:
	var main = _level()
	await wait_frames(4)
	var rig = main.camera_rig

	assert_gt(rig.distance, 0.0, "It is some way back from what it is looking at")
	assert_almost_eq(rig.focus.y, 0.0, 0.001, "And looking at a point on the ground")
	assert_gt(rig.tilt, 0.0, "Looking down at it rather than up")
	assert_almost_eq(main.camera.global_position.y, rig.distance * sin(deg_to_rad(rig.tilt)), 0.01,
		"Its height is its distance and its tilt, which is the point of keeping them apart")

# ==============================================================================
# 2. Turning
# ==============================================================================

func test_03_turning_swings_the_camera_round_what_it_is_looking_at() -> void:
	# The thing a fixed bearing could not do. What must NOT happen is the view sliding
	# off the base while it turns -- an orbit is about a point, and the point stays.
	var main = _level()
	await wait_frames(4)
	var rig = main.camera_rig
	var looking_at: Vector3 = rig.focus
	var was_at: Vector3 = main.camera.global_position

	rig.rotate_by(90.0)
	rig.apply_to(main.camera)

	assert_almost_eq(rig.focus.distance_to(looking_at), 0.0, 0.001,
		"It is still looking at the same spot")
	assert_gt(main.camera.global_position.distance_to(was_at), 1.0,
		"From somewhere else entirely")
	assert_almost_eq(main.camera.global_position.distance_to(rig.focus), rig.distance, 0.01,
		"And no nearer or further than it was")

func test_04_all_the_way_round_is_back_where_it_started() -> void:
	var rig := _rig()
	rig.yaw = 35.0
	for i in range(8):
		rig.rotate_by(45.0)
	assert_almost_eq(rig.yaw, 35.0, 0.001, "Eight eighths of a turn is a turn")

func test_05_pressing_right_means_right_on_screen_however_it_is_turned() -> void:
	# The half of this that is easy to get wrong. Once the view can turn, panning in
	# WORLD axes means "press D to go right" stops meaning right the moment the player
	# rotates -- and they will rotate, because that is the feature.
	var rig := _rig()
	rig.focus = Vector3.ZERO
	rig.yaw = 0.0
	rig.pan(Vector2(1.0, 0.0), 5.0)
	var facing_north: Vector3 = rig.focus

	rig.focus = Vector3.ZERO
	rig.yaw = 90.0
	rig.pan(Vector2(1.0, 0.0), 5.0)
	var facing_east: Vector3 = rig.focus

	assert_almost_eq(facing_north.length(), 5.0, 0.001, "It moved the distance asked for")
	assert_almost_eq(facing_east.length(), 5.0, 0.001, "Both times")
	assert_gt(facing_north.distance_to(facing_east), 5.0,
		"But somewhere else, because the screen turned with it")

# ==============================================================================
# 3. Zoom and tilt, and where they stop
# ==============================================================================

func test_06_zoom_keeps_looking_at_the_same_spot() -> void:
	# It used to slide the camera along its own forward vector, so every notch walked the
	# view off whatever was being studied. Distance from a fixed point cannot do that.
	var rig := _rig()
	rig.focus = Vector3(3.0, 0.0, -4.0)
	rig.distance = 25.0
	var looking_at: Vector3 = rig.focus

	rig.zoom_step(1.0)
	assert_lt(rig.distance, 25.0, "A notch forward comes closer")
	assert_almost_eq(rig.focus.distance_to(looking_at), 0.0, 0.001, "At the same thing")

func test_07_it_stops_before_the_ground_and_before_the_horizon() -> void:
	var rig := _rig()
	var near: float = float(config_node.CAMERA["min_distance"])
	var far: float = float(config_node.CAMERA["max_distance"])
	var flat: float = float(config_node.CAMERA["min_tilt_degrees"])
	var steep: float = float(config_node.CAMERA["max_tilt_degrees"])

	for i in range(200):
		rig.zoom_step(1.0)
	assert_almost_eq(rig.distance, near, 0.001, "Zooming in stops where Config says")
	for i in range(400):
		rig.zoom_step(-1.0)
	assert_almost_eq(rig.distance, far, 0.001, "And out")

	for i in range(200):
		rig.tilt_by(5.0)
	assert_almost_eq(rig.tilt, steep, 0.001, "Tilting stops short of straight down")
	for i in range(400):
		rig.tilt_by(-5.0)
	assert_almost_eq(rig.tilt, flat, 0.001, "And short of the horizon, where the ground goes edge-on")
	assert_lt(steep, 90.0, "Straight down would lose every silhouette")
	assert_gt(flat, 0.0, "And level would lose the ground")

func test_08_panning_scales_with_how_far_out_the_view_is() -> void:
	# A fixed rate is wrong at every zoom but one: it crawls when the player pulls back
	# to look at the whole map and flings when they lean in to place a stake.
	var main = _level()
	await wait_frames(4)
	var rig = main.camera_rig
	rig.reset()
	var start: Vector3 = rig.focus
	rig.pan_keys(Vector2(1.0, 0.0), 1.0)
	var close_up: float = start.distance_to(rig.focus)

	rig.reset()
	rig.distance = float(config_node.CAMERA["max_distance"])
	rig.pan_keys(Vector2(1.0, 0.0), 1.0)
	var far_out: float = start.distance_to(rig.focus)

	assert_gt(far_out, close_up, "Pulled back, the same key covers more ground")

# ==============================================================================
# 4. Getting un-lost
# ==============================================================================

func test_09_reset_puts_it_back_where_the_scene_opened_it() -> void:
	# The control that makes the rest safe to use. Somebody who has spun the view round
	# and tilted it flat needs one key that undoes all of it.
	var main = _level()
	await wait_frames(4)
	var cam: Camera3D = main.camera
	var opened_at: Vector3 = cam.global_position
	var opened_aimed: Vector3 = -cam.global_transform.basis.z

	main.camera_rig.rotate_by(137.0)
	main.camera_rig.tilt_by(-25.0)
	main.camera_rig.zoom_step(4.0)
	main.camera_rig.pan(Vector2(1.0, 1.0), 9.0)
	main.camera_rig.apply_to(cam)
	assert_gt(cam.global_position.distance_to(opened_at), 1.0, "Thoroughly moved")

	main.reset_camera()
	assert_almost_eq(cam.global_position.distance_to(opened_at), 0.0, 0.001,
		"And back to the opening shot exactly")
	assert_almost_eq((-cam.global_transform.basis.z).distance_to(opened_aimed), 0.0, 0.01,
		"Aimed the same way too")

# ==============================================================================
# 5. The rules the project keeps
# ==============================================================================

func test_10_every_number_the_camera_obeys_is_in_config() -> void:
	# Rule 1. There were nine of them buried in Main as literals, including two pan
	# speeds that did not agree with each other and a zoom clamp written in metres of
	# HEIGHT -- which stops meaning anything the moment the tilt can change.
	for key in ["min_distance", "max_distance", "min_tilt_degrees", "max_tilt_degrees",
			"pan_speed", "drag_pan", "rotate_speed", "tilt_speed", "drag_rotate",
			"drag_tilt", "zoom_step"]:
		assert_true(config_node.CAMERA.has(key), "Config.CAMERA declares %s" % key)

	var source := FileAccess.open("res://scripts/core/Main.gd", FileAccess.READ)
	assert_not_null(source, "Main.gd is readable")
	var text: String = source.get_as_text()
	assert_false(text.contains("zoom_camera(1.8)"), "No zoom step left hardcoded in Main")
	assert_false(text.contains("0.015 * (camera.global_position.y"), "No pan speed left hardcoded")

func test_11_the_keys_are_declared_and_the_player_is_told_them() -> void:
	# Rule 2, and the reason it matters here: a control nobody can find is a control
	# nobody has. The settings page lists them.
	for key in ["camera_rotate_left_key", "camera_rotate_right_key", "camera_tilt_up_key",
			"camera_tilt_down_key", "camera_reset_key", "camera_pan_button"]:
		assert_true(config_node.CONTROLS.has(key), "Config.CONTROLS declares %s" % key)

	assert_ne(tr("MENU_CAMERA_KEYS"), "MENU_CAMERA_KEYS",
		"The controls are written down somewhere the player can read them")
	assert_ne(tr("MENU_CAMERA"), "MENU_CAMERA", "Under a heading")
