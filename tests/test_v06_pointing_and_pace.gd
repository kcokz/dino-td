# res://tests/test_v06_pointing_and_pace.gd
# v0.6 feedback, round two:
#   5. "人经常选中不了，两个scenario，左键人，右键点树，这时候人开始挖树，但是鼠标hover到人身上就没有
#      圈highlight，左键也选不了。从船舱出来也是选不了人"
#   7. "人站着不动的时候还在走，需要不动"
#
# The pointer took the first thing its ray met, and a tree is clicked by its whole crown seen
# from above -- so a man chopping under it could not be pointed at, and the cabin hid him the
# same way. Now a unit near the cursor is taken first, and otherwise the ray goes on through
# what it meets and takes by rank (Main._raycast_object). Walking home goes to the door, and
# he comes out of it picked.
#
# And the walk was played by the STATE, so a man pressed against a wall -- MOVING, and going
# nowhere -- walked on the spot. Travelling is drawn from the feet now (ActorAnimator
# .update_motion, Config.ANIMATIONS.gaits).
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	clear_drops()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	await wait_frames(2)
	return main

## Where the middle of `unit`'s body is on the screen.
func _on_screen(main: Node, unit: Node3D) -> Vector2:
	var size: Vector3 = config_node.get_visual_size("hero")
	return main.camera.unproject_position(unit.global_position + Vector3(0.0, size.y * 0.5, 0.0))

## A tree on the map, standing where the camera can see it.
func _a_tree(main: Node) -> Node3D:
	for node in tree.get_nodes_in_group("resource_nodes"):
		if String(node.resource_type) != "wood" or not node.has_method("has_trunk") or not node.has_trunk():
			continue
		var at: Vector2 = main.camera.unproject_position((node as Node3D).global_position)
		if main.get_viewport().get_visible_rect().grow(-40.0).has_point(at) and not main.camera.is_position_behind(node.global_position):
			return node
	return null

func test_01_a_man_chopping_under_a_crown_is_still_the_one_pointed_at() -> void:
	var main = await _level()
	var hero: Node3D = main.hero
	var trunk_tree: Node3D = _a_tree(main)
	assert_not_null(trunk_tree, "There is a tree in view")
	if trunk_tree == null:
		return
	# Beside the trunk, under the crown -- where he stands to chop it.
	var reach: float = float(trunk_tree.block_radius()) + float(config_node.HERO["width"]) * 0.5 + 0.05
	hero.global_position = trunk_tree.global_position + Vector3(0.0, 0.0, reach)
	await wait_physics_frames(2)
	var at: Vector2 = _on_screen(main, hero)
	var passed: Array = main._objects_along_ray(at)
	assert_true(passed.has(trunk_tree), "The crown is in the way of the ray to him")
	assert_eq(main._raycast_object(at), hero, "and yet he is what the cursor is on")
	main._update_hover(at)
	assert_eq(main._hovered, hero, "He is the one outlined")

func test_02_a_unit_is_taken_a_little_wide_of_its_body() -> void:
	var main = await _level()
	var hero: Node3D = main.hero
	var at: Vector2 = _on_screen(main, hero)
	var slop: float = float(config_node.CONTROLS["pick_slop_px"])
	# Just past his shoulder, inside the slop.
	var wide: Vector2 = at + Vector2(slop * 0.5, 0.0)
	var cam: Camera3D = main.camera
	var size: Vector3 = config_node.get_visual_size("hero")
	var middle: Vector3 = hero.global_position + Vector3(0.0, size.y * 0.5, 0.0)
	var half_px: float = at.distance_to(cam.unproject_position(middle + cam.global_transform.basis.x * size.x * 0.5))
	wide = at + Vector2(half_px + slop * 0.5, 0.0)
	assert_eq(main._raycast_object(wide), hero, "A near miss still takes him")
	var far: Vector2 = at + Vector2(half_px + slop * 4.0, 0.0)
	assert_ne(main._raycast_object(far), hero, "and a real miss does not")

func test_03_walking_home_goes_to_the_door() -> void:
	var main = await _level()
	var hero = main.hero
	hero.global_position = main.current_core.global_position + Vector3(-12.0, 0.0, -10.0)
	assert_true(main.order_enter_cabin(), "The order is taken")
	var door: Vector3 = main.cabin_door()
	var half: float = float(config_node.get_building_footprint("core")) * 0.5
	assert_gt(door.z, main.current_core.global_position.z + half, "The door is past the cabin's south wall")
	var path: Array = hero.current_path
	assert_false(path.is_empty(), "He has a way there")
	if not path.is_empty():
		var end: Vector3 = path[path.size() - 1]
		assert_almost_eq(Vector2(end.x, end.z).distance_to(Vector2(door.x, door.z)), 0.0, 0.3,
			"and it ends at the door, not against a wall")

func test_04_he_comes_out_of_the_door_picked() -> void:
	var main = await _level()
	var hero: Node3D = main.hero
	hero.global_position = main.current_core.global_position + Vector3(0.0, 0.0, -2.6)   # the north side
	main.enter_cabin()
	await wait_frames(1)
	var told = watch_signal(tree.root.get_node("EventBus"), "unit_selected")
	assert_true(main.leave_cabin(), "Out he comes")
	assert_eq(told.emit_count, 1, "and he is the one picked")
	if told.emit_count > 0:
		assert_eq(told.last_args[0], hero, "him")
	var door: Vector3 = main.cabin_door()
	assert_almost_eq(Vector2(hero.global_position.x, hero.global_position.z).distance_to(Vector2(door.x, door.z)), 0.0, 0.05,
		"standing at the door, on the camera's side")
	await wait_physics_frames(2)
	assert_eq(main._raycast_object(_on_screen(main, hero)), hero, "where a click finds him")

func test_05_a_man_going_nowhere_stands() -> void:
	var main = await _level()
	var hero = main.hero
	var anim: Dictionary = config_node.ANIMATIONS
	hero.current_state = hero.State.MOVING
	hero.animator.update_motion(0.0, 1.0)
	assert_false(hero.animator.is_moving, "Pressed against something, he is not moving")
	assert_eq(hero.animator.requested_clip, String(anim["standing"]["hero"]), "so he stands, whatever his orders")
	hero.animator.update_motion(float(config_node.HERO["move_speed"]), 1.0)
	assert_true(hero.animator.is_moving, "Going at his pace, he is")
	var gaits: Dictionary = anim["gaits"]["hero"]
	assert_true(gaits.has(hero.animator.requested_clip), "and plays one of his gaits (%s)" % hero.animator.requested_clip)
	hero.current_state = hero.State.IDLE

func test_06_his_stride_keeps_pace_with_his_feet() -> void:
	var main = await _level()
	var hero = main.hero
	var player: AnimationPlayer = hero.animator.animation_player
	assert_not_null(player, "He is animated")
	if player == null:
		return
	var anim: Dictionary = config_node.ANIMATIONS
	var gaits: Dictionary = anim["gaits"]["hero"]
	var span: Vector2 = anim["pace_scale_range"]
	hero.current_state = hero.State.MOVING
	var pace: float = float(config_node.HERO["move_speed"])
	hero.animator.update_motion(pace, 1.0)
	var drawn: float = float(gaits[hero.animator.requested_clip])
	assert_almost_eq(player.speed_scale, clampf(pace / drawn, span.x, span.y), 0.001, "The clip plays at his pace")
	var fed: float = pace * 1.2
	hero.animator.update_motion(fed, 1.0)
	drawn = float(gaits[hero.animator.requested_clip])
	assert_almost_eq(player.speed_scale, clampf(fed / drawn, span.x, span.y), 0.001, "and quicker when he is quicker")
	hero.current_state = hero.State.IDLE
	assert_almost_eq(player.speed_scale, 1.0, 0.001, "Out of a travelling state it plays as drawn")

func test_07_the_walk_waits_for_the_feet_to_stop_before_it_stops() -> void:
	# Between the two thresholds nothing changes, so easing to a stop cannot flicker.
	var main = await _level()
	var hero = main.hero
	var anim: Dictionary = config_node.ANIMATIONS
	var still: float = float(anim["still_speed"])
	var moving: float = float(anim["moving_speed"])
	assert_lt(still, moving, "Standing and moving are apart")
	hero.current_state = hero.State.MOVING
	hero.animator.update_motion(moving * 2.0, 1.0)
	assert_true(hero.animator.is_moving, "Going")
	hero.animator.update_motion((still + moving) * 0.5, 1.0)
	assert_true(hero.animator.is_moving, "Slowing between the two, still going")
	hero.animator.update_motion(still * 0.5, 1.0)
	assert_false(hero.animator.is_moving, "Under the lower, stopped")
	hero.animator.update_motion((still + moving) * 0.5, 1.0)
	assert_false(hero.animator.is_moving, "and between the two again, still stopped")
	hero.current_state = hero.State.IDLE

func test_08_a_raptor_held_up_stands_too() -> void:
	var main = await _level()
	var d = load(config_node.get_dino_script_path("raptor")).new("raptor")
	main.add_child(d)
	await wait_frames(1)
	d.current_state = d.State.WALKING
	d.animator.update_motion(0.0, 1.0)
	assert_eq(d.animator.requested_clip, String(config_node.ANIMATIONS["standing"]["dino"]), "Waiting its turn, it stands")
	d.animator.update_motion(float(config_node.DINOS["raptor"]["speed"]), 1.0)
	assert_true(config_node.ANIMATIONS["gaits"]["dino"].has(d.animator.requested_clip), "Running, it runs")
