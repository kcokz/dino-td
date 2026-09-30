# res://tests/test_v06_traps.gd
# v0.6 feedback, round two, 1-3: "Bow tower作为初始防御太过于强大，一开始就能造塔有点不合理，建议换一个角度，
# 想一个能攻击但不是tower的防御，接近一开始人能造的东西 / 防御装置自动可以攻击需要合理解释 / Crossbow tower也一样，
# 自动攻击没法合理化".
#
# NOTHING THE PLAYER BUILDS AIMS. A trap is set along a lane of ground in front of it -- R turns it
# while it is placed -- and an animal walking into its tripwire looses it: the trip bow's arrow at
# the first animal on the wire, the set crossbow's bolt through every animal on the whole lane.
# Then it is re-armed, which takes a while and is seen happen. Only the cabin -- the ship's own
# machinery -- picks its own targets.
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
	unlock_all()

func after_each() -> void:
	if game_state_node != null and "is_paused" in game_state_node:
		game_state_node.is_paused = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

var _world: Node3D = null

## A grid and a bare field with a mesh over it (nav_fixture), and a BuildSystem on them.
func _field() -> Array:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	return [gm, bs]

## `type_id` set with its middle in build cell `cell`, facing `facing`, paid for -- finished unless
## `pending`, which leaves it a blueprint.
func _set_trap(bs: Node, type_id: String, cell: Vector2i, facing: int = 0, pending: bool = false) -> Node:
	stock_everything()
	var b = bs.place_at(type_id, cell, _world, pending, facing)
	if b != null and not pending and not b.is_constructed:
		b.complete_construction()
	return b

## A raptor standing still in build cell `cell`: its own mind switched off, so it is where it is
## put and the trap is what is being tested.
func _raptor_at(gm: Node, cell: Vector2i) -> Node:
	var d = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(d)
	_world.add_child(d)
	d.setup("raptor")
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = gm.build_cell_to_world(cell)
	d.set_physics_process(false)
	return d

func _row(type_id: String) -> Dictionary:
	return config_node.BUILDINGS[type_id]

# ==============================================================================
# 1. Nothing the player builds aims
# ==============================================================================

func test_01_nothing_the_player_builds_aims_and_only_the_cabin_does() -> void:
	for type_id in config_node.BUILDINGS:
		var row: Dictionary = config_node.BUILDINGS[type_id]
		if String(type_id) == "core":
			assert_true(row.has("range"), "The cabin's gun has a reach: the ship's machinery aims")
			continue
		assert_false(row.has("range") or row.has("fire_rate"),
			"%s picks no targets of its own" % type_id)
		if String(row.get("kind", "")) == "trap":
			assert_gt(int(row.get("lane", 0)), 0, "%s is set along a lane" % type_id)
			assert_gt(float(row.get("rearm_seconds", 0.0)), 0.0, "%s has to be re-armed" % type_id)
	for type_id in config_node.BUILDABLE_TYPES:
		assert_ne(String(config_node.get_building_kind(type_id)), "tower", "No tower on the build menu (%s)" % type_id)
	assert_true(config_node.BUILDABLE_TYPES.has("trip_bow"), "The opening's trap is on the menu")
	assert_true(config_node.upgrade_targets("trip_bow").has("set_crossbow"),
		"And bone makes it the set crossbow where it stands (GAME-DESIGN 6.0)")
	assert_eq(config_node.BUILDINGS["trip_bow"]["cost"].keys(), ["wood"], "The trip bow is wood and nothing else")
	assert_eq(config_node.upgrade_target("set_crossbow"), "set_crossbow_2", "The set crossbow improves where it stands")

# ==============================================================================
# 2. It faces a way, and its lane runs that way
# ==============================================================================

func test_02_a_trap_faces_where_it_is_set_and_its_lane_runs_that_way() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var here := Vector2i(0, 0)
	var trap = _set_trap(bs, "trip_bow", here, 1)
	await wait_frames(2)
	assert_not_null(trap, "It is set")
	assert_eq(int(trap.facing), 1, "Facing east, as it was placed")
	var length: int = int(_row("trip_bow")["lane"])
	assert_eq(trap.lane.size(), length, "Its whole lane on open ground")
	for k in range(trap.lane.size()):
		assert_eq(trap.lane[k], here + Vector2i(k + 1, 0), "Cell %d of the lane is %d east of it" % [k, k + 1])
	var body: Node3D = trap.find_child("Body", false, false) as Node3D
	assert_almost_eq(body.rotation.y, Trap.facing_yaw(1), 0.001, "Its body is turned to face along the lane")

	trap.set_facing(2)
	await wait_frames(1)
	assert_eq(trap.lane[0], here + Vector2i(0, 1), "Turned south, the lane runs south")

func test_03_the_wire_stops_at_what_is_built_and_runs_on_when_it_goes() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "set_crossbow", Vector2i(0, 0), 0)
	var wall = _set_trap(bs, "wall", Vector2i(0, -3), 0)
	await wait_frames(3)
	assert_eq(trap.lane.size(), 2, "A wall three cells north cuts the wire at two")
	wall.destroy()
	await wait_frames(3)
	assert_eq(trap.lane.size(), int(_row("set_crossbow")["lane"]), "Taken down, the wire runs its whole length again")

# ==============================================================================
# 3. An animal on the wire looses it, and it has to be re-armed
# ==============================================================================

func test_04_an_animal_on_the_wire_looses_it_and_it_has_to_be_rearmed() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	var raptor = _raptor_at(gm, Vector2i(0, -2))
	var before: float = raptor.current_hp
	await wait_physics_frames(4)

	var damage: float = float(_row("trip_bow")["damage"])
	assert_almost_eq(raptor.current_hp, before - damage, 0.001, "The animal on the wire took the arrow")
	assert_false(trap.armed, "And the trap is let go")
	assert_gt(trap.rearm_left, 0.0, "It is being re-armed")

	# While it is, the animal still standing on the wire takes nothing more.
	var after_one: float = raptor.current_hp
	await wait_physics_frames(6)
	assert_almost_eq(raptor.current_hp, after_one, 0.001, "Nothing more until it is re-armed")

	# The rest of the re-arming, driven rather than waited out.
	trap._physics_process(trap.rearm_left + 0.01)
	assert_true(trap.armed, "Re-armed after its time")
	await wait_physics_frames(4)
	assert_almost_eq(raptor.current_hp, after_one - damage, 0.001, "And it looses again at what is still on the wire")

func test_05_a_trip_bow_strikes_only_the_first_animal_on_the_wire() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	_set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	var near = _raptor_at(gm, Vector2i(0, -1))
	var far = _raptor_at(gm, Vector2i(0, -3))
	var hp: float = near.current_hp
	await wait_physics_frames(4)
	assert_lt(near.current_hp, hp, "The nearest takes the arrow")
	assert_almost_eq(far.current_hp, hp, 0.001, "The one behind it does not")

func test_06_a_set_crossbows_bolt_goes_through_everything_on_the_lane() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	_set_trap(bs, "set_crossbow", Vector2i(0, 0), 3)
	await wait_frames(2)
	var file: Array = []
	for k in [1, 3, 5]:
		file.append(_raptor_at(gm, Vector2i(-k, 0)))
	var hp: float = file[0].current_hp
	await wait_physics_frames(4)
	var damage: float = float(_row("set_crossbow")["damage"])
	for i in range(file.size()):
		assert_almost_eq(file[i].current_hp, hp - damage, 0.001, "Raptor %d in the file is struck" % i)

func test_07_nothing_off_the_lane_trips_it() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	var beside = _raptor_at(gm, Vector2i(1, -2))     # the next lane over
	var behind = _raptor_at(gm, Vector2i(0, 2))      # behind the bow
	var hp: float = beside.current_hp
	await wait_physics_frames(6)
	assert_true(trap.armed, "Still set")
	assert_almost_eq(beside.current_hp, hp, 0.001, "The next lane over is not on the wire")
	assert_almost_eq(behind.current_hp, hp, 0.001, "Nor is what is behind it")

func test_08_the_hero_does_not_trip_his_own_wire() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	_world.add_child(hero)
	hero.global_position = gm.build_cell_to_world(Vector2i(0, -2))
	hero.set_physics_process(false)
	await wait_physics_frames(6)
	assert_true(trap.armed, "He set it; he steps over it")
	assert_eq(trap.animals_on_wire().size(), 0, "Nothing on the wire")

func test_09_a_trap_still_being_built_has_no_wire() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0, true)
	await wait_frames(2)
	var raptor = _raptor_at(gm, Vector2i(0, -2))
	var hp: float = raptor.current_hp
	await wait_physics_frames(6)
	assert_false(trap.is_constructed, "Only ordered")
	assert_almost_eq(raptor.current_hp, hp, 0.001, "An order looses nothing")
	trap.complete_construction()
	await wait_physics_frames(6)
	assert_lt(raptor.current_hp, hp, "Finished, it does")

func test_10_being_rearmed_can_be_seen() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	var string: Node3D = trap.find_child("String", true, false) as Node3D
	var arrow: Node3D = trap.find_child("Arrow", true, false) as Node3D
	assert_not_null(string, "The model has a string")
	assert_not_null(arrow, "And an arrow on it")
	if string == null or arrow == null:
		return
	var drawn: Vector3 = string.position
	assert_true(arrow.visible, "Set: the arrow is on the string")

	_raptor_at(gm, Vector2i(0, -1))
	await wait_physics_frames(4)
	var travel: float = float(config_node.TRAPS["string_travel"])
	assert_false(arrow.visible, "Let go: the arrow is gone")
	assert_almost_eq(string.position.distance_to(drawn), travel, 0.01, "And the string has gone forward to the bow")
	assert_true(trap._panel_status().length() > 0, "Its panel says it is being re-armed")

	trap._physics_process(trap.rearm_seconds * 0.5 - 0.01)
	assert_almost_eq(string.position.distance_to(drawn), travel * 0.5, 0.02, "Half re-armed, half drawn back")
	trap._physics_process(trap.rearm_seconds)
	assert_almost_eq(string.position.distance_to(drawn), 0.0, 0.001, "Re-armed, drawn right back")
	assert_true(arrow.visible, "With an arrow on it again")

func test_11_a_paused_game_springs_no_traps() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	game_state_node.is_paused = true
	var raptor = _raptor_at(gm, Vector2i(0, -2))
	var hp: float = raptor.current_hp
	await wait_physics_frames(6)
	assert_almost_eq(raptor.current_hp, hp, 0.001, "Paused: nothing is loosed")
	game_state_node.is_paused = false
	await wait_physics_frames(4)
	assert_lt(raptor.current_hp, hp, "Unpaused, it is")

# ==============================================================================
# 4. Placing one: R turns it, and the lane shows where it will shoot
# ==============================================================================

func test_12_r_turns_the_trap_in_hand_and_the_ghost_shows_its_lane() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	stock_everything()
	main.on_build_selected("trip_bow")
	assert_eq(int(main._placement_facing), 0, "It starts facing north")
	main.turn_placement(1)
	assert_eq(int(main._placement_facing), 1, "R turns it a quarter, clockwise")
	main.turn_placement(-1)
	main.turn_placement(-1)
	assert_eq(int(main._placement_facing), 3, "Shift+R turns it back, round past north")
	main.turn_placement(2)

	# The ghost's lane from ground by the cabin nothing in the level uses, facing east.
	var gm = main.grid_manager
	var snap: Vector2i = gm.tile_centre_build_cell(FREE_TILE)
	main._show_lane(snap)
	var lanes: Node = main.build_preview.find_child("LanePreview", false, false)
	assert_not_null(lanes, "A trap's ghost has its lane")
	var shown: Array = []
	for square in lanes.get_children():
		if (square as Node3D).visible:
			shown.append(square)
	var expected: Array[Vector2i] = Trap.lane_from(gm, snap, 1, int(_row("trip_bow")["lane"]))
	assert_eq(shown.size(), expected.size(), "A square for every cell the wire will run through")
	if not shown.is_empty():
		var first: Vector3 = (shown[0] as Node3D).position
		assert_almost_eq(first.x, float(config_node.BUILD_CELL), 0.001, "The first a cell east of the ghost")
		assert_almost_eq(first.z, 0.0, 0.001, "In line with it")

	var placed = main.try_place_at_cell(Vector2i.ZERO, gm.build_cell_to_world(snap))
	assert_not_null(placed, "It is set where the ghost was")
	if placed != null:
		assert_eq(int(placed.facing), 1, "Facing the way it was turned")

func test_13_only_a_trap_is_turned() -> void:
	# R is the camera's reset the rest of the time (Config.CONTROLS): only a trap in hand takes it.
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.on_build_selected("wall")
	assert_false(main._faces("wall"), "A wall does not face a way")
	assert_false(main._faces(""), "Nor does an empty hand")
	assert_true(main._faces("trip_bow"), "A trap does")
	assert_eq(int(config_node.CONTROLS["trap_turn_key"]), int(config_node.CONTROLS["camera_reset_key"]),
		"On the key the view's reset has the rest of the time")

# ==============================================================================
# 5. What it does to a raid, and what a raid does to it
# ==============================================================================

func test_14_a_pack_goes_for_the_trap_that_is_shooting_it() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "trip_bow", Vector2i(0, 0), 0)
	await wait_frames(2)
	var raptor = _raptor_at(gm, Vector2i(2, -2))
	await wait_frames(1)
	assert_true(raptor._is_shooter(trap), "A trap is what shoots at it")
	assert_eq(raptor._preferred_target(), trap, "So it leaves its path for it")

func test_15_improved_where_it_stands_it_keeps_its_facing() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var trap = _set_trap(bs, "set_crossbow", Vector2i(0, 0), 2)
	await wait_frames(2)
	stock_everything()
	assert_true(trap.begin_upgrade(), "The upgrade is started")
	trap.add_upgrade_progress(1000.0)
	await wait_frames(2)
	assert_eq(String(trap.building_type), "set_crossbow_2", "It is the twin set crossbow now")
	assert_eq(int(trap.facing), 2, "Still facing south")
	var body: Node3D = trap.find_child("Body", false, false) as Node3D
	assert_almost_eq(body.rotation.y, Trap.facing_yaw(2), 0.001, "Its new body turned the same way")
	assert_almost_eq(trap.rearm_seconds, float(_row("set_crossbow_2")["rearm_seconds"]), 0.0001,
		"And it re-arms as the improved one does")
	assert_lt(trap.rearm_seconds, float(_row("set_crossbow")["rearm_seconds"]), "Faster than it did")
