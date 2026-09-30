# res://tests/test_v06_the_map.gd
# The player, v0.6 round five: "小地图没有还是会有点confusing，我们需要设计怎么能获得小地图" -- chosen "在工作台做一张
# 地图" (GAME-DESIGN 9.3). Not there at the start; drawn on a hide at the workbench; then in the corner for good:
# only what he has seen, the cabin, him, the smoking wrecks, the nest once found. A click on it takes the view there.
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
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func test_01_no_map_at_first_and_the_bench_draws_one_on_a_hide() -> void:
	var main = await _level()
	assert_false(main.hud.minimap.visible, "No map at the start")
	var row: Dictionary = config_node.RECIPES["hide_map"]
	assert_eq(String(row["station"]), "workbench", "It is drawn at the workbench")
	assert_eq(row["inputs"].keys(), ["hide"], "on a hide, and nothing else")
	var bench = main.current_core.station("workbench")
	assert_false(bench.can_offer("hide_map"), "(not before there is hide)")
	game_state_node.add_resource("hide", 1)
	assert_true(bench.can_offer("hide_map"), "Hide in the stock, the bench offers it")
	game_state_node.grant_unlock(String(row["unlocks"]))
	await wait_frames(2)
	assert_true(main.hud.minimap.visible, "Made, it is in the corner")
	assert_false(bench.can_offer("hide_map"), "(and it is made once)")
	# At the left, clear of the right side's panels: under the goal's panel it was pushed down onto the cards
	# as the panel grew with a goal pinned.
	var at: Rect2 = main.hud.minimap.get_global_rect()
	assert_false(at.intersects(main.hud.objective_panel.get_global_rect()), "(clear of the goal's panel)")
	assert_lt(at.end.x, main.hud.get_viewport().get_visible_rect().size.x * 0.5, "At the left, away from the cards at the right")

func test_02_it_shows_only_what_he_has_seen() -> void:
	var main = await _level()
	game_state_node.grant_unlock("hide_map")
	await wait_seconds(float(config_node.FOG["every"]) * 2.0 + 0.2)
	var map: MiniMap = main.hud.minimap
	map.redraw_ground()
	var fog = main.fog
	var seen: PackedByteArray = fog.seen_cells()
	var here: int = fog._index(main.hero.global_position)
	var far: int = -1
	for i in seen.size():
		if seen[i] == 0:
			far = i
			break
	assert_gte(here, 0, "(he is on the field)")
	assert_gt(far, -1, "(somewhere he has not been)")
	var hx: int = here % int(fog.cells)
	var hz: int = here / int(fog.cells)
	var fx: int = far % int(fog.cells)
	var fz: int = far / int(fog.cells)
	assert_ne(map._image.get_pixel(hx, hz), map._image.get_pixel(fx, fz), "Where he has been is drawn; where he has not is bare hide")
	assert_true(_same_ink(map._image.get_pixel(fx, fz), config_node.MINIMAP["hide"] as Color), "(the bare hide)")

## The same colour, as a picture of a byte a channel keeps it.
func _same_ink(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 1.5 / 255.0 and absf(a.g - b.g) <= 1.5 / 255.0 and absf(a.b - b.b) <= 1.5 / 255.0

func test_03_a_click_on_it_takes_the_view_there() -> void:
	var main = await _level()
	game_state_node.grant_unlock("hide_map")
	await wait_frames(2)
	var map: MiniMap = main.hud.minimap
	var target: Vector3 = main.current_core.global_position + Vector3(12.0, 0.0, -8.0)
	var p: Vector2 = map.to_map(target)
	map.look_at_point(p)
	var focus: Vector3 = main.camera_rig.focus
	assert_lt(Vector2(focus.x - target.x, focus.z - target.z).length(), 0.6, "The view is where the click was on the map")
	var cabin: Vector2 = map.to_map(main.current_core.global_position)
	assert_true(Rect2(Vector2.ZERO, map.size).has_point(cabin), "and the cabin is on it")
