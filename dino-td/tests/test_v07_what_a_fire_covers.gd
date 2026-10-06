# res://tests/test_v07_what_a_fire_covers.gd
# The player, 2026-10-05: "campfire控制的区域可以用蓝色显示出来，包括cover的建筑，还是说campfire不需要cover？"
#
# WHAT A FIRE COVERS (FireCover): a prowler will not stand in a light to bite (ProwlerDino.would_stand_at), so what a
# fire lights all round is out of its reach at night. While a fire is put down or picked, every fire's ground shows in
# the reach's blue -- the one in hand's as its ghost's ring -- and each building lit all round is outlined in it. Not
# otherwise: by night the light itself is seen.
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
	var eb = tree.root.get_node_or_null("EventBus")
	if eb:
		eb.unit_deselected.emit()
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

func _build(main: Node, type_id: String, off: Vector3) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var b = main.build_system.place_at(type_id, main.grid_manager.world_to_build_cell(door + off), main.buildings_container)
	assert_not_null(b, "(a %s goes down by the cabin)" % type_id)
	if b != null:
		b.complete_construction()
	return b

func test_01_a_fires_ring_is_its_light_at_night_in_the_reachs_blue() -> void:
	var main = await _level()
	var fire = _build(main, "campfire", Vector3(0.0, 0.0, 3.0))
	if fire == null:
		return
	await wait_frames(1)
	assert_almost_eq(float(fire._get_display_range()), float(config_node.BUILDINGS["campfire"]["light"]), 0.001,
		"Its ring reaches as far as it lights at night")
	var blue: Color = config_node.FEEDBACK["reach_color"]
	var c: Color = fire._get_range_indicator_color()
	assert_almost_eq(Vector3(c.r, c.g, c.b).distance_to(Vector3(blue.r, blue.g, blue.b)), 0.0, 0.001, "in the reach's blue")
	assert_almost_eq(float(main._preview_range_for("campfire")), float(config_node.BUILDINGS["campfire"]["light"]), 0.001,
		"and so does its ghost's, in hand")
	assert_eq(main._preview_ring_color("campfire"), main._reach_colour(), "in the same blue")

func test_02_lit_all_round_is_covered() -> void:
	var main = await _level()
	var fire = _build(main, "campfire", Vector3(0.0, 0.0, 3.0))
	var near = _build(main, "wall", Vector3(1.0, 0.0, 3.0))
	var far = _build(main, "wall", Vector3(0.0, 0.0, 3.0 + float(config_node.BUILDINGS["campfire"]["light"]) + 3.0))
	if fire == null or near == null or far == null:
		return
	await wait_frames(1)
	var lights: Array = main.fire_cover.night_lights()
	assert_eq(lights.size(), 1, "One fire, one light (burning or not: its night's)")
	assert_true(FireCover.covers(lights, near, config_node), "A fence beside it is lit all round: covered")
	assert_false(FireCover.covers(lights, far, config_node), "one beyond its light is not")
	assert_false(FireCover.covers(lights, main.current_core, config_node) and main.current_core.global_position.distance_to(fire.global_position) > float(config_node.BUILDINGS["campfire"]["light"]),
		"(and the cabin only where it is lit all round)")

func test_03_shown_while_a_fire_is_picked_and_not_otherwise() -> void:
	var main = await _level()
	var fire = _build(main, "campfire", Vector3(0.0, 0.0, 3.0))
	var other = _build(main, "campfire", Vector3(-4.0, 0.0, 3.0))
	var near = _build(main, "wall", Vector3(1.0, 0.0, 3.0))
	if fire == null or other == null or near == null:
		return
	await wait_frames(1)
	var eb = tree.root.get_node("EventBus")
	assert_false(main.fire_cover.showing(), "Nothing shows with no fire picked")
	assert_true(main.fire_cover.covered().is_empty(), "(no outlines)")
	eb.unit_selected.emit(fire)
	await wait_frames(1)
	assert_true(main.fire_cover.showing(), "A fire picked: it shows")
	assert_true(fire.range_indicator != null and fire.range_indicator.visible, "its ring")
	assert_true(other.range_indicator != null and other.range_indicator.visible, "and every other fire's: what they cover together")
	assert_has(main.fire_cover.covered(), near, "and the fence it lights all round, outlined")
	eb.unit_selected.emit(near)
	await wait_frames(1)
	assert_false(main.fire_cover.showing(), "Something else picked: gone")
	assert_false(fire.range_indicator.visible or other.range_indicator.visible, "rings and all")
	assert_true(main.fire_cover.covered().is_empty(), "(no outlines)")

func test_04_shown_while_one_is_put_down() -> void:
	var main = await _level()
	var near = _build(main, "wall", Vector3(1.0, 0.0, 3.0))
	if near == null:
		return
	var at: Vector3 = near.global_position + Vector3(-1.0, 0.0, 0.0)
	main.current_build_type = "campfire"
	main._fire_in_hand(at)
	await wait_frames(1)
	assert_true(main.fire_cover.showing(), "A fire in hand: what it would cover shows")
	assert_has(main.fire_cover.covered(), near, "the fence it would light all round outlined")
	main._clear_build_preview()
	await wait_frames(1)
	assert_false(main.fire_cover.showing(), "Put away: gone")
	assert_true(main.fire_cover.covered().is_empty(), "(no outlines)")
