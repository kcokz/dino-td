# res://tests/test_v06_the_cabin_room.gd
# The cabin is a room, not a menu: the crew module, outside and in (tools/generate_cabin.py
# module), with the Hero's benches in it as models whose parts show how far the run has got --
# the tools on the workbench's board, the pot on the fire, the beacon's mast going back up a
# stage at a time (scripts/fx/CabinArt.gd). A bench clicked is worked where it stands: its menu
# on the panel, and him sent to it (v0.6 round three; it was a dock along the bottom of a room
# parked under the map).
#
# Everything expected is read from Config and from the models themselves.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var event_bus_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
		event_bus_node = tree.root.get_node_or_null("EventBus")

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
		game_state_node.is_paused = false
		game_state_node.reset_game()
	super.after_each()

func _keep(node: Node) -> Node:
	_cleanup_nodes.append(node)
	return node

func _level() -> Node:
	var main = await fresh_level()
	_keep(main)
	return main

## A model's parts by name.
func _parts(body: Node) -> Dictionary:
	var out: Dictionary = {}
	for mi in CabinArt.parts(body):
		out[String(mi.name)] = mi
	return out

## The box round a model's meshes, in `body`'s own space -- meshes only: a glowing part's
## light is a visual instance too, and its reach is not the model's size.
func _mesh_bounds(body: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in CabinArt.parts(body):
		var box: AABB = body.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

## Whether a part's name is one of its bench's jobs, and so shows by how far the run is.
func _is_job(station: Node, part_name: String) -> bool:
	return not station.recipe_data(String(CabinArt.condition(part_name)[0])).is_empty()

# ==============================================================================
# 1. Models
# ==============================================================================

func test_01_the_module_and_every_bench_have_a_model() -> void:
	assert_true(VisualLibrary.has_art("building/core"), "The cabin, outside and in, is a model")
	var parts: Dictionary = _parts(_keep(VisualLibrary.make("building/core")))
	for part in ["hull", "fade_shell", "glass", "door"]:
		assert_true(parts.has(part), "It has its %s" % part)
	for station_id in config_node.STATIONS:
		assert_true(VisualLibrary.has_art("station/%s" % station_id), "The %s is a model" % station_id)

func test_02_everything_a_bench_makes_for_good_has_a_part_that_shows_it() -> void:
	# A tool, a pot, a stage of the beacon: each lasting job has a part named after it in its
	# bench's model. Without one the run would move on and the room would not.
	for recipe_id in config_node.RECIPES:
		var row: Dictionary = config_node.RECIPES[recipe_id]
		if String(row.get("unlocks", "")) == "":
			continue
		var parts: Dictionary = _parts(_keep(VisualLibrary.make("station/%s" % String(row["station"]))))
		assert_true(parts.has(recipe_id) or parts.has(recipe_id + CabinArt.GLOW_SUFFIX),
			"%s shows at the %s once made" % [recipe_id, row["station"]])
	var beacon_parts: Dictionary = _parts(_keep(VisualLibrary.make("station/%s" % String(config_node.BEACON_STATION))))
	for job_id in config_node.beacon_jobs(game_state_node.map_data()):
		assert_true(beacon_parts.has(job_id) or beacon_parts.has(job_id + CabinArt.GLOW_SUFFIX),
			"The beacon shows %s once it is done" % job_id)

func test_03_the_benches_show_how_far_the_run_has_got() -> void:
	var main = await _level()
	var stations: Array = main.current_core.stations
	var parts_seen: int = 0
	# A new run: nothing made -- what shows "before" a job shows, what shows once it is done
	# does not, and a part that belongs to no job always shows.
	for st in stations:
		assert_not_null(st.body, "%s is drawn as its model" % st.station_id)
		for mi in CabinArt.parts(st.body):
			parts_seen += 1
			var before: bool = bool(CabinArt.condition(String(mi.name))[1])
			var expect: bool = before if _is_job(st, String(mi.name)) else true
			assert_eq(mi.visible, expect, "A new run: %s's %s" % [st.station_id, mi.name])
	assert_gt(parts_seen, 0, "The benches have parts")
	# Everything made, the beacon repaired and launched: the other way round.
	for recipe_id in config_node.RECIPES:
		game_state_node.grant_unlock(String(config_node.RECIPES[recipe_id].get("unlocks", "")))
	for job_id in config_node.beacon_jobs(game_state_node.map_data()):
		assert_true(game_state_node.finish_beacon_job(job_id), "%s done" % job_id)
	for st in stations:
		for mi in CabinArt.parts(st.body):
			var before: bool = bool(CabinArt.condition(String(mi.name))[1])
			var expect: bool = (not before) if _is_job(st, String(mi.name)) else true
			assert_eq(mi.visible, expect, "All done: %s's %s" % [st.station_id, mi.name])

func test_04_the_kitchen_swaps_its_spit_for_the_pot() -> void:
	# The one upgrade that takes something away, said plainly: the kitchen's vessel recipe
	# replaces what was over the fire before it.
	var main = await _level()
	var kitchen: Node = null
	var vessel: String = ""
	for st in main.current_core.stations:
		for recipe_id in st.recipes():
			if _parts(st.body).has(CabinArt.BEFORE_PREFIX + recipe_id):
				kitchen = st
				vessel = recipe_id
	assert_not_null(kitchen, "A bench has something that goes when a recipe is made")
	if kitchen == null:
		return
	var parts: Dictionary = _parts(kitchen.body)
	assert_true(parts[CabinArt.BEFORE_PREFIX + vessel].visible, "Before: the old way over the fire")
	assert_false(parts[vessel].visible, "And no %s" % vessel)
	game_state_node.grant_unlock(String(config_node.RECIPES[vessel]["unlocks"]))
	assert_false(parts[CabinArt.BEFORE_PREFIX + vessel].visible, "Made: the old way is gone")
	assert_true(parts[vessel].visible, "And the %s stands in its place" % vessel)

func test_05_a_bench_is_clicked_by_its_declared_size_and_drawn_inside_it() -> void:
	var main = await _level()
	for st in main.current_core.stations:
		var size: Vector3 = config_node.get_visual_size("station/%s" % st.station_id)
		var shape: BoxShape3D = null
		for child in st.get_children():
			if child is CollisionShape3D:
				shape = (child as CollisionShape3D).shape as BoxShape3D
		assert_not_null(shape, "%s can be clicked" % st.station_id)
		if shape:
			assert_eq(shape.size, size, "%s is clicked by its declared size" % st.station_id)
		var art: AABB = _mesh_bounds(st.body)
		for axis in 3:
			assert_lte(art.size[axis], size[axis] + 0.01, "%s's model fits its size on axis %d" % [st.station_id, axis])

func test_06_the_benches_stand_where_the_module_marks_them() -> void:
	var main = await _level()
	var cabin = main.current_core
	for st in cabin.stations:
		var spot: Node3D = cabin.spot_of(String(st.station_id))
		assert_not_null(spot, "The module marks where the %s stands" % st.station_id)
		if spot:
			assert_almost_eq(st.global_position.distance_to(spot.global_position), 0.0, 0.01,
				"The %s stands on its mark" % st.station_id)
		assert_true(cabin.is_inside(st.global_position), "inside the room")
		var size: Vector3 = config_node.get_visual_size("station/%s" % st.station_id)
		var back: float = (st.global_position.z - size.z * 0.5) - cabin.global_position.z
		assert_gte(back, -cabin.room_half().y - 0.01, "its back not through the back wall")

func test_07_a_bench_clicked_shows_its_menu_and_sends_him_to_it() -> void:
	var main = await _level()
	var kitchen: Node = main.current_core.station("kitchen")
	assert_not_null(kitchen, "The kitchen is in the cabin")
	main.hero.global_position = main.cabin_door()
	await wait_physics_frames(2)
	event_bus_node.unit_selected.emit(kitchen)
	main._walk_to_bench(kitchen)
	assert_eq(main.hud.option_panel.selected_unit, kitchen, "Its menu is on the panel")
	var seconds: float = 12.0
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if main.current_core.is_inside(main.hero.global_position) 				and main.hero.global_position.distance_to(kitchen.global_position) < 1.2:
			break
	assert_true(main.current_core.is_inside(main.hero.global_position), "He went in, through the door")
	assert_lt(main.hero.global_position.distance_to(kitchen.global_position), 1.2, "and stands at the kitchen")

func test_08_inside_the_roof_fades_and_outside_it_comes_back() -> void:
	var main = await _level()
	var cabin = main.current_core
	assert_almost_eq(cabin.roof_transparency(), 0.0, 0.001, "From outside, the roof is on")
	main.hero.global_position = cabin.door_inside()
	cabin.recheck_hero()
	assert_true(cabin.hero_inside, "Him inside is noticed")
	assert_true(main.in_cabin, "and the level is told")
	await wait_seconds(float(config_node.CABIN["fade_seconds"]) + 0.2)
	assert_almost_eq(cabin.roof_transparency(), float(config_node.CABIN["fade_transparency"]), 0.01,
		"Inside, the roof fades so he can be seen at work")
	assert_almost_eq(main.camera_rig.distance, float(config_node.CABIN["inside_camera_distance"]), 0.5,
		"and the camera eases in over the room")
	main.hero.global_position = cabin.door_outside()
	cabin.recheck_hero()
	await wait_seconds(float(config_node.CABIN["fade_seconds"]) + 0.2)
	assert_almost_eq(cabin.roof_transparency(), 0.0, 0.01, "Out again, it is back")
	assert_false(main.in_cabin, "and the level knows he is out")

func test_09_what_glows_is_drawn_lit_and_lights_the_room() -> void:
	var main = await _level()
	var glowing: int = 0
	var lit: int = 0
	var lights: Dictionary = config_node.CABIN.get("glow_lights", {})
	var bodies: Array = [main.current_core.find_child("Body", false, false)]
	for st in main.current_core.stations:
		bodies.append(st.body)
	for body in bodies:
		for mi in CabinArt.parts(body):
			if not String(mi.name).ends_with(CabinArt.GLOW_SUFFIX):
				continue
			glowing += 1
			assert_eq(mi.material_override, CabinArt.glow_material(), "%s is drawn lit by itself" % mi.name)
			if lights.has(String(mi.name)):
				lit += 1
				assert_not_null(mi.get_node_or_null(CabinArt.LIGHT_NAME), "%s lights the room round it" % mi.name)
	assert_gt(glowing, 0, "Something in the cabin glows")
	assert_eq(lit, lights.size(), "Every light Config names has a part to hang on")

func test_10_the_fire_wavers() -> void:
	# The light that flickers hardest is not a lamp: over one second it brightens and dims by
	# a good part of what Config says it may (a fire at the noise's default scale barely moved).
	var main = await _level()
	var lights: Array[OmniLight3D] = CabinArt.lights_under(main.current_core)
	var hardest: OmniLight3D = null
	for light in lights:
		if hardest == null or float(light.get_meta("flicker", 0.0)) > float(hardest.get_meta("flicker", 0.0)):
			hardest = light
	assert_not_null(hardest, "Something in the cabin flickers")
	if hardest == null:
		return
	var base: float = float(hardest.get_meta("energy", 1.0))
	var amount: float = float(hardest.get_meta("flicker", 0.0))
	var lo: float = INF
	var hi: float = -INF
	var one: Array[OmniLight3D] = [hardest]
	for step in 20:
		CabinArt.animate(one, step * 0.05)
		lo = minf(lo, hardest.light_energy)
		hi = maxf(hi, hardest.light_energy)
	assert_gt(hi - lo, base * amount * 0.3, "Over a second it wavers (%.2f .. %.2f)" % [lo, hi])
