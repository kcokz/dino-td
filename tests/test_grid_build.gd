# res://tests/test_grid_build.gd
# Requirement R2 Acceptance Test Suite:
# Verifies Grid Coordinate Math, Occupancy Tracking, Building Placement Verification,
# AP/Wood Resource Transactions, and Campfire Core Base Lifecycle.
extends "res://tests/test_base.gd"

## Wood each test starts with: generous enough to cover any single building
## under any balance, so these tests measure transactions rather than affordability.
const START_WOOD: int = 100

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var grid_manager_script: GDScript = null
var build_system_script: GDScript = null
var building_script: GDScript = null
var core_campfire_script: GDScript = null
var wall_script: GDScript = null
var tower_script: GDScript = null

var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# 1. Lifecycle Hooks
# ==============================================================================

func before_all() -> void:
	# 1. Resolve Autoload Singletons from /root or script fallback
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if config_node == null and ResourceLoader.exists("res://scripts/autoload/Config.gd"):
		config_node = load("res://scripts/autoload/Config.gd").new()
		_cleanup_objects.append(config_node)

	if event_bus_node == null and ResourceLoader.exists("res://scripts/autoload/EventBus.gd"):
		event_bus_node = load("res://scripts/autoload/EventBus.gd").new()
		_cleanup_objects.append(event_bus_node)

	if game_state_node == null and ResourceLoader.exists("res://scripts/autoload/GameState.gd"):
		game_state_node = load("res://scripts/autoload/GameState.gd").new()
		_cleanup_objects.append(game_state_node)

	# 2. Load M2 Scripts
	grid_manager_script = _load_script([
		"res://scripts/core/GridManager.gd",
		"res://scripts/core/grid_manager.gd"
	])
	build_system_script = _load_script([
		"res://scripts/core/BuildSystem.gd",
		"res://scripts/core/build_system.gd"
	])
	building_script = _load_script([
		"res://scripts/entities/Building.gd",
		"res://scripts/entities/building.gd"
	])
	core_campfire_script = _load_script([
		"res://scripts/entities/CoreCampfire.gd",
		"res://scripts/entities/core_campfire.gd"
	])
	wall_script = _load_script([
		"res://scripts/entities/Wall.gd",
		"res://scripts/entities/wall.gd"
	])
	tower_script = _load_script([
		"res://scripts/entities/Tower.gd",
		"res://scripts/entities/tower.gd"
	])

func before_each() -> void:
	# Guarantee clean game state before every test
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		if "current_ap" in game_state_node: game_state_node.current_ap = 3
		# reset_game() seeds Config.INITIAL_RESOURCES, which is deliberately lean.
		# Top the wallet up so these tests measure the placement transaction rather
		# than whether the opening balance happens to cover a given building.
		if "resources" in game_state_node: game_state_node.resources = {"wood": START_WOOD, "stone": START_WOOD, "water": START_WOOD, "food": 0}
		if "is_game_over" in game_state_node: game_state_node.is_game_over = false
	# v0.4 gates the turret behind a blueprint and stone behind a pick. This suite is
	# about something else, so it starts with the cabin's work already done rather
	# than walking that chain in every test.
	unlock_all()

func after_each() -> void:
	# Clean up any instantiated nodes from the test to prevent ObjectDB leaks
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_cleanup_nodes.clear()

	# Disconnect watchers via super
	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _cleanup_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				obj.free()
			elif obj is RefCounted:
				pass
	_cleanup_objects.clear()

# ==============================================================================
# 2. Helpers & Factory Utilities
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_grid_manager() -> Object:
	assert_not_null(grid_manager_script, "GridManager.gd script must exist")
	if grid_manager_script == null:
		return null
	var instance = grid_manager_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	return instance

func _create_build_system(grid_mgr: Object) -> Object:
	assert_not_null(build_system_script, "BuildSystem.gd script must exist")
	if build_system_script == null:
		return null
	var instance = build_system_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	
	# Wire GridManager dependency if property or method exists
	if "grid_manager" in instance:
		instance.grid_manager = grid_mgr
	elif instance.has_method("setup"):
		instance.call("setup", grid_mgr)
	elif instance.has_method("set_grid_manager"):
		instance.call("set_grid_manager", grid_mgr)
	return instance

func _get_wood() -> int:
	if game_state_node != null and "resources" in game_state_node:
		return game_state_node.resources.get("wood", 0)
	return -1

func _get_ap() -> int:
	if game_state_node != null and "current_ap" in game_state_node:
		return game_state_node.current_ap
	return -1

# ==============================================================================
# 3. Category 1: Coordinate Math Tests (R2.1)
# ==============================================================================

func test_coord_origin_roundtrip() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var origin_cell = Vector2i(0, 0)
	var world_pos: Vector3 = grid_mgr.cell_to_world(origin_cell)
	var roundtrip_cell: Vector2i = grid_mgr.world_to_cell(world_pos)

	assert_eq(roundtrip_cell, origin_cell, "Origin cell (0,0) should round-trip perfectly")

func test_coord_positive_quadrant_roundtrip() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var test_cells = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(3, 7),
		Vector2i(12, 25),
		Vector2i(50, 100)
	]
	for c in test_cells:
		var w = grid_mgr.cell_to_world(c)
		var back = grid_mgr.world_to_cell(w)
		assert_eq(back, c, "Positive cell %s round-trip consistency" % str(c))

func test_coord_negative_quadrant_roundtrip() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var test_cells = [
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(-4, -6),
		Vector2i(-15, -20),
		Vector2i(-50, -100)
	]
	for c in test_cells:
		var w = grid_mgr.cell_to_world(c)
		var back = grid_mgr.world_to_cell(w)
		assert_eq(back, c, "Negative cell %s round-trip consistency (tests floor math)" % str(c))

func test_coord_mixed_quadrant_roundtrip() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var test_cells = [
		Vector2i(-3, 7),
		Vector2i(8, -5),
		Vector2i(-12, 34),
		Vector2i(27, -81)
	]
	for c in test_cells:
		var w = grid_mgr.cell_to_world(c)
		var back = grid_mgr.world_to_cell(w)
		assert_eq(back, c, "Mixed quadrant cell %s round-trip consistency" % str(c))

func test_coord_elevation_invariance() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var cell = Vector2i(2, 4)
	var elevations = [0.0, 5.0, 12.5, -3.0, 100.0]
	for y in elevations:
		var w = grid_mgr.cell_to_world(cell, y)
		assert_almost_eq(w.y, y, 0.001, "cell_to_world should preserve requested elevation Y")
		var back = grid_mgr.world_to_cell(w)
		assert_eq(back, cell, "world_to_cell must be invariant with respect to elevation Y (y=%f)" % y)

func test_coord_tile_size_spacing() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var tile_size = 2.0
	if config_node != null and "TILE_SIZE" in config_node:
		tile_size = float(config_node.TILE_SIZE)

	var pos_00 = grid_mgr.cell_to_world(Vector2i(0, 0))
	var pos_10 = grid_mgr.cell_to_world(Vector2i(1, 0))
	var pos_01 = grid_mgr.cell_to_world(Vector2i(0, 1))

	var dx = pos_10.x - pos_00.x
	var dz = pos_01.z - pos_00.z

	assert_almost_eq(dx, tile_size, 0.001, "Adjacent X cell spacing must equal TILE_SIZE (2.0)")
	assert_almost_eq(dz, tile_size, 0.001, "Adjacent Z cell spacing must equal TILE_SIZE (2.0)")

func test_coord_subcell_tolerance_and_bounds() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var tile_size = 2.0
	if config_node != null and "TILE_SIZE" in config_node:
		tile_size = float(config_node.TILE_SIZE)

	# Cell (2, 3) occupies world span: X in [4.0, 6.0), Z in [6.0, 8.0)
	var c = Vector2i(2, 3)
	var base_x = float(c.x) * tile_size
	var base_z = float(c.y) * tile_size

	var interior_points = [
		Vector3(base_x + 0.01, 0.0, base_z + 0.01),
		Vector3(base_x + 0.5, 0.0, base_z + 0.5),
		Vector3(base_x + 1.0, 0.0, base_z + 1.0),
		Vector3(base_x + 1.99, 0.0, base_z + 1.99)
	]
	for pt in interior_points:
		assert_eq(grid_mgr.world_to_cell(pt), c, "Point %s must map to cell %s" % [str(pt), str(c)])

	# Point on adjacent boundary must map to adjacent cell
	var next_point = Vector3(base_x + tile_size + 0.01, 0.0, base_z + 0.01)
	assert_eq(grid_mgr.world_to_cell(next_point), Vector2i(3, 3), "Boundary transition maps to next cell")

# ==============================================================================
# 4. Category 2: GridManager Occupancy Tracking Tests (R2.2)
# ==============================================================================

func test_grid_initial_unoccupied() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var test_cell = Vector2i(5, 5)
	assert_false(grid_mgr.is_cell_occupied(test_cell), "Cell (5,5) should initially be unoccupied")
	assert_null(grid_mgr.get_building_at(test_cell), "get_building_at should initially return null")

func test_grid_occupy_cell_success() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var dummy_building = Node3D.new()
	_cleanup_nodes.append(dummy_building)
	var cell = Vector2i(3, 2)

	var success = grid_mgr.occupy_cell(cell, dummy_building)
	assert_true(success, "occupy_cell should return true for empty cell")
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell should now be occupied")
	assert_eq(grid_mgr.get_building_at(cell), dummy_building, "get_building_at should return the placed building")

func test_grid_occupy_duplicate_rejected() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var b1 = Node3D.new()
	var b2 = Node3D.new()
	_cleanup_nodes.append(b1)
	_cleanup_nodes.append(b2)
	var cell = Vector2i(4, 4)

	var first_res = grid_mgr.occupy_cell(cell, b1)
	assert_true(first_res, "First occupation must succeed")

	var second_res = grid_mgr.occupy_cell(cell, b2)
	assert_false(second_res, "Duplicate occupation on same cell must return false")
	assert_eq(grid_mgr.get_building_at(cell), b1, "Cell must retain the original building b1")

func test_grid_vacate_cell() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var dummy = Node3D.new()
	_cleanup_nodes.append(dummy)
	var cell = Vector2i(1, 1)

	grid_mgr.occupy_cell(cell, dummy)
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell should be occupied before vacate")

	grid_mgr.vacate_cell(cell)
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell should be unoccupied after vacate")
	assert_null(grid_mgr.get_building_at(cell), "get_building_at should be null after vacate")

func test_grid_vacate_empty_cell_safe() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var cell = Vector2i(99, 99)
	# Vacating an unoccupied cell must be a safe no-op without error
	grid_mgr.vacate_cell(cell)
	assert_false(grid_mgr.is_cell_occupied(cell), "Unoccupied cell remains unoccupied")

func test_grid_independent_cells() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var b1 = Node3D.new()
	var b2 = Node3D.new()
	_cleanup_nodes.append(b1)
	_cleanup_nodes.append(b2)

	grid_mgr.occupy_cell(Vector2i(1, 1), b1)
	grid_mgr.occupy_cell(Vector2i(2, 2), b2)

	assert_true(grid_mgr.is_cell_occupied(Vector2i(1, 1)), "Cell (1,1) is occupied")
	assert_true(grid_mgr.is_cell_occupied(Vector2i(2, 2)), "Cell (2,2) is occupied")
	assert_false(grid_mgr.is_cell_occupied(Vector2i(1, 2)), "Adjacent cell (1,2) must remain unoccupied")
	assert_false(grid_mgr.is_cell_occupied(Vector2i(2, 1)), "Adjacent cell (2,1) must remain unoccupied")

# ==============================================================================
# 5. Category 3: Building Entities & Stats Tests (R2.2)
# ==============================================================================

func test_building_wall_initialization() -> void:
	assert_not_null(wall_script, "Wall.gd script must exist")
	if wall_script == null: return

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)

	assert_has(wall, "building_type", "Wall must declare building_type")
	assert_eq(wall.building_type, "wall", "Wall building_type should be 'wall'")
	assert_has(wall, "max_hp", "Wall must declare max_hp")
	assert_almost_eq(float(wall.max_hp), float(config_node.BUILDINGS["wall"]["hp"]), 0.01, "Wall max_hp matches Config")
	assert_almost_eq(float(wall.current_hp), float(config_node.BUILDINGS["wall"]["hp"]), 0.01, "Wall starts at full hp")

func test_building_turret_initialization() -> void:
	assert_not_null(tower_script, "Tower.gd script must exist")
	if tower_script == null: return

	var hut = tower_script.new()
	_cleanup_nodes.append(hut)

	assert_eq(hut.building_type, "tower", "Tower building_type should be 'tower'")
	var want_hp: float = float(config_node.BUILDINGS["tower"]["hp"])
	assert_almost_eq(float(hut.max_hp), want_hp, 0.01, "Tower max_hp comes from Config")
	assert_almost_eq(float(hut.current_hp), want_hp, 0.01, "And it starts at full")

func test_building_tower_initialization() -> void:
	assert_not_null(tower_script, "Tower.gd script must exist")
	if tower_script == null: return

	var tower = tower_script.new()
	_cleanup_nodes.append(tower)

	assert_eq(tower.building_type, "tower", "Tower building_type should be 'tower'")
	assert_almost_eq(float(tower.max_hp), 20.0, 0.01, "Tower max_hp should match Config (20.0)")

func test_building_take_damage_and_destruction_signal() -> void:
	assert_not_null(wall_script, "Wall.gd script must exist")
	if wall_script == null or event_bus_node == null: return

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)

	var watcher = watch_signal(event_bus_node, "building_destroyed")

	# This test is about the damage/destroy signal, not about balance: pin the hp.
	wall.max_hp = 30.0
	wall.current_hp = 30.0

	# Take non-lethal damage
	assert_has_method(wall, "take_damage", "Building must implement take_damage")
	wall.take_damage(10.0)
	assert_almost_eq(float(wall.current_hp), 20.0, 0.01, "Wall HP should be 20.0 after 10 damage")
	assert_false(watcher.emitted, "building_destroyed should NOT emit on non-lethal damage")

	# Take lethal damage
	wall.take_damage(20.0)
	assert_lte(float(wall.current_hp), 0.0, "Wall HP should be <= 0 after lethal damage")
	assert_true(watcher.emitted, "building_destroyed should emit on lethal damage")
	if not watcher.last_args.is_empty():
		assert_eq(watcher.last_args[0], wall, "building_destroyed argument must be the destroyed building")

# ==============================================================================
# 6. Category 4: BuildSystem Placement Verification & Transactions (R2.2)
# ==============================================================================

func test_place_wall_success_transactions() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var watcher = watch_signal(event_bus_node, "building_placed")
	var cell = Vector2i(1, 1)

	assert_true(build_sys.can_place_building("wall", cell), "can_place_building should return true for empty cell with enough resources")

	var building = build_sys.place_building("wall", cell)
	if building is Node: _cleanup_nodes.append(building)

	assert_not_null(building, "place_building should return the instantiated building")
	assert_eq(_get_ap(), 2, "Wall placement should consume 1 AP (3 -> 2)")
	assert_eq(_get_wood(), START_WOOD - cost_of("wall"), "Wall placement consumes its wood cost")
	assert_true(watcher.emitted, "building_placed signal must be emitted")
	if not watcher.last_args.is_empty():
		assert_eq(watcher.last_args[0], building, "building_placed signal argument must be the placed building")
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell (1,1) must be occupied in GridManager")
	assert_eq(grid_mgr.get_building_at(cell), building, "GridManager building at (1,1) matches return instance")

func test_place_turret_success_transactions() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var watcher = watch_signal(event_bus_node, "building_placed")
	var cell = Vector2i(2, 1)

	var building = build_sys.place_building("tower", cell)
	if building is Node: _cleanup_nodes.append(building)

	assert_not_null(building, "place_building tower should succeed")
	assert_eq(_get_ap(), 2, "Placement consumes 1 AP (3 -> 2)")
	assert_eq(_get_wood(), START_WOOD - cost_of("tower"), "Placement consumes its wood cost")
	assert_true(watcher.emitted, "building_placed emitted")
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell (2,1) occupied in GridManager")

func test_place_tower_success_transactions() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var watcher = watch_signal(event_bus_node, "building_placed")
	var cell = Vector2i(3, 1)

	var building = build_sys.place_building("tower", cell)
	if building is Node: _cleanup_nodes.append(building)

	assert_not_null(building, "place_building tower should succeed")
	assert_eq(_get_ap(), 2, "Tower placement consumes 1 AP (3 -> 2)")
	assert_eq(_get_wood(), START_WOOD - cost_of("tower"), "Tower placement consumes its wood cost")
	assert_true(watcher.emitted, "building_placed emitted for Tower")
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell (3,1) occupied in GridManager")

func test_duplicate_placement_rejected_no_deductions() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var cell = Vector2i(4, 4)

	# 1. Place initial Wall
	var b1 = build_sys.place_building("wall", cell)
	if b1 is Node: _cleanup_nodes.append(b1)
	assert_not_null(b1, "Initial wall placement should succeed")
	assert_eq(_get_ap(), 2, "AP is 2 after first placement")
	assert_eq(_get_wood(), START_WOOD - cost_of("wall"), "Wood reduced by the wall cost after first placement")

	# 2. Watcher for second placement attempt
	var watcher = watch_signal(event_bus_node, "building_placed")

	# Check validation
	assert_false(build_sys.can_place_building("tower", cell), "can_place_building on occupied cell must return false")

	# Execute duplicate placement attempt
	var b2 = build_sys.place_building("tower", cell)
	if b2 is Node: _cleanup_nodes.append(b2)

	assert_null(b2, "Duplicate placement on occupied cell must return null")
	assert_eq(_get_ap(), 2, "AP must NOT be deducted on rejected duplicate placement")
	assert_eq(_get_wood(), START_WOOD - cost_of("wall"), "Wood must NOT be deducted again on rejected duplicate placement")
	assert_false(watcher.emitted, "building_placed signal must NOT be emitted for rejected placement")
	assert_eq(grid_mgr.get_building_at(cell), b1, "Cell must retain original building b1")

func test_placement_rejected_insufficient_ap() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Drain AP to 0
	game_state_node.current_ap = 0
	var cell = Vector2i(5, 5)

	assert_false(build_sys.can_place_building("wall", cell), "can_place_building must return false when AP is 0")

	var watcher = watch_signal(event_bus_node, "building_placed")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "place_building must return null when AP is insufficient")
	assert_eq(_get_ap(), 0, "AP must remain 0")
	assert_eq(_get_wood(), START_WOOD, "Wood must remain untouched")
	assert_false(watcher.emitted, "No signal emitted on AP failure")
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell must remain empty")

func test_placement_rejected_insufficient_wood() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# One wood short of a wall, so the placement below must be rejected.
	game_state_node.resources["wood"] = maxi(0, cost_of("wall") - 1)
	var cell = Vector2i(6, 6)

	assert_false(build_sys.can_place_building("wall", cell), "can_place_building must return false when wood is insufficient")

	var watcher = watch_signal(event_bus_node, "building_placed")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "place_building must return null when wood is insufficient")
	assert_eq(_get_ap(), 3, "AP must remain untouched (3)")
	assert_eq(_get_wood(), maxi(0, cost_of("wall") - 1), "Wood must remain untouched")
	assert_false(watcher.emitted, "No signal emitted on wood failure")
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell must remain empty")

func test_placement_exact_cost_boundary() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Exactly 1 AP and exactly the wall's cost in wood
	game_state_node.current_ap = 1
	game_state_node.resources["wood"] = cost_of("wall")
	var cell = Vector2i(7, 7)

	assert_true(build_sys.can_place_building("wall", cell), "can_place_building with exact cost must be true")

	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_not_null(b, "Placement with exact resources must succeed")
	assert_eq(_get_ap(), 0, "AP must be exactly 0 after consuming last point")
	assert_eq(_get_wood(), 0, "Wood must be exactly 0 after consuming exact cost")

	# Immediate second placement must fail
	var b2 = build_sys.place_building("wall", Vector2i(7, 8))
	if b2 is Node: _cleanup_nodes.append(b2)
	assert_null(b2, "Immediate next placement must fail due to 0 AP and 0 wood")

func test_placement_invalid_building_type_rejected() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(8, 8)
	assert_false(build_sys.can_place_building("quantum_cannon", cell), "Invalid building type must be rejected by can_place_building")

	var b = build_sys.place_building("quantum_cannon", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "place_building with invalid type must return null")
	assert_eq(_get_ap(), 3, "AP unchanged on invalid type")
	assert_eq(_get_wood(), START_WOOD, "Wood unchanged on invalid type")
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell remains empty")

# ==============================================================================
# 7. Category 5: Core Campfire Base Tests (R2.3)
# ==============================================================================

func test_core_initial_placement_and_hp() -> void:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)

	assert_eq(core.building_type, "core", "Core building_type should be 'core'")
	assert_almost_eq(float(core.max_hp), 10.0, 0.01, "Core max_hp should match Config (10.0)")
	assert_almost_eq(float(core.current_hp), 10.0, 0.01, "Core initial current_hp should be 10.0")

func test_core_take_damage_emits_core_hp_changed() -> void:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null or event_bus_node == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)

	var watcher = watch_signal(event_bus_node, "core_hp_changed")

	core.take_damage(3.0)
	assert_almost_eq(float(core.current_hp), 7.0, 0.01, "Core HP should be 7.0 after 3.0 damage")
	assert_true(watcher.emitted, "core_hp_changed signal must be emitted on damage")
	if not watcher.last_args.is_empty():
		assert_almost_eq(float(watcher.last_args[0]), 7.0, 0.01, "Arg 0 should be current_hp (7.0)")
		assert_almost_eq(float(watcher.last_args[1]), 10.0, 0.01, "Arg 1 should be max_hp (10.0)")

func test_core_partial_damage_does_not_emit_game_lost() -> void:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null or event_bus_node == null or game_state_node == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	core.take_damage(5.0)
	assert_almost_eq(float(core.current_hp), 5.0, 0.01, "Core HP should be 5.0")
	assert_false(lost_watcher.emitted, "game_lost must NOT be emitted on partial damage")
	assert_false(game_state_node.is_game_over, "GameState.is_game_over must remain false")

func test_core_destruction_emits_game_lost() -> void:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null or event_bus_node == null or game_state_node == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")
	var destroyed_watcher = watch_signal(event_bus_node, "building_destroyed")

	# Deal lethal damage (10.0)
	core.take_damage(10.0)
	assert_lte(float(core.current_hp), 0.0, "Core HP should be <= 0")
	assert_true(destroyed_watcher.emitted, "building_destroyed must be emitted for Core")
	assert_true(lost_watcher.emitted, "game_lost must be emitted on Core destruction")
	assert_true(game_state_node.is_game_over, "GameState.is_game_over must transition to true")

func test_core_cannot_be_overwritten_by_build_system() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or core_campfire_script == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)
	var origin_cell = Vector2i(0, 0)

	# Register core at cell (0, 0)
	grid_mgr.occupy_cell(origin_cell, core)
	assert_true(grid_mgr.is_cell_occupied(origin_cell), "Cell (0,0) occupied by Core")

	# Attempt placing Wall at cell (0, 0)
	assert_false(build_sys.can_place_building("wall", origin_cell), "can_place_building at core cell (0,0) must return false")
	var wall = build_sys.place_building("wall", origin_cell)
	if wall is Node: _cleanup_nodes.append(wall)

	assert_null(wall, "Attempting to build over CoreCampfire must return null")
	assert_eq(_get_ap(), 3, "AP must not be deducted")
	assert_eq(_get_wood(), START_WOOD, "Wood must not be deducted")
	assert_eq(grid_mgr.get_building_at(origin_cell), core, "Core remains at cell (0,0)")

# ==============================================================================
# 8. Category 6: Stress & Adversarial Hardening Tests (R2.4)
# ==============================================================================

func test_rapid_consecutive_placements_drain_ap() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	# Starting AP = 3. Place 3 walls in distinct cells (1 AP + one wall cost each).
	for i in range(3):
		var cell = Vector2i(10 + i, 10)
		var b = build_sys.place_building("wall", cell)
		if b is Node: _cleanup_nodes.append(b)
		assert_not_null(b, "Placement %d must succeed" % (i + 1))
		assert_eq(_get_ap(), 2 - i, "AP correctly decremented to %d" % (2 - i))
		assert_eq(_get_wood(), START_WOOD - (i + 1) * cost_of("wall"), "Wood correctly decremented")

	# 4th placement must fail due to 0 AP
	var fail_cell = Vector2i(13, 10)
	assert_false(build_sys.can_place_building("wall", fail_cell), "4th placement rejected due to 0 AP")
	var fail_b = build_sys.place_building("wall", fail_cell)
	if fail_b is Node: _cleanup_nodes.append(fail_b)
	assert_null(fail_b, "4th placement returns null")
	assert_eq(_get_ap(), 0, "AP clamped at 0")
	assert_eq(_get_wood(), START_WOOD - 3 * cost_of("wall"), "Wood unchanged by the rejected 4th placement")

func test_negative_coordinates_placement() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var neg_cell = Vector2i(-5, -8)
	var b = build_sys.place_building("wall", neg_cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_not_null(b, "Building placement at negative cell coordinates must succeed")
	assert_true(grid_mgr.is_cell_occupied(neg_cell), "Negative grid cell (-5, -8) is occupied")
	if "cell_pos" in b:
		assert_eq(b.cell_pos, neg_cell, "Building.cell_pos matches negative coordinate")

# ==============================================================================
# 9. Category 7: Lifecycle & Reclamation Tests
# ==============================================================================

func test_grid_auto_vacate_on_building_destroyed() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var target_cell = Vector2i(1, 0)
	var wall = build_sys.place_building("wall", target_cell)
	if wall is Node: _cleanup_nodes.append(wall)

	assert_not_null(wall, "Wall should be placed successfully")
	assert_true(grid_mgr.is_cell_occupied(target_cell), "Cell (1, 0) must be occupied")

	# Destroy wall
	wall.take_damage(30.0)
	assert_false(grid_mgr.is_cell_occupied(target_cell), "GridManager must automatically vacate cell (1, 0) on building_destroyed")

	# Re-placing on vacated cell should now be permitted
	# Give player AP and wood if needed
	game_state_node.current_ap = 2
	game_state_node.resources["wood"] = 10
	assert_true(build_sys.can_place_building("wall", target_cell), "Vacated cell (1, 0) must now be eligible for new placement")
	var new_wall = build_sys.place_building("wall", target_cell)
	if new_wall is Node: _cleanup_nodes.append(new_wall)
	assert_not_null(new_wall, "New wall placed successfully on reclaimed cell")
	assert_true(grid_mgr.is_cell_occupied(target_cell), "Cell (1, 0) is re-occupied")


func test_building_collision_layer_layer2() -> void:
	assert_not_null(building_script, "Building.gd script must exist")
	if building_script == null or tree == null or tree.root == null: return

	var b = building_script.new()
	_cleanup_nodes.append(b)
	tree.root.add_child(b)

	assert_eq(b.collision_layer, 2, "Building collision_layer must be 2 (Layer 2: Buildings)")
	assert_eq(b.collision_mask, 0, "Building collision_mask should be 0")

func test_grid_stale_node_pruning() -> void:
	var grid_mgr = _create_grid_manager()
	if grid_mgr == null: return

	var stale_node = Node3D.new()
	var test_cell = Vector2i(8, 9)
	grid_mgr.occupy_cell(test_cell, stale_node)
	assert_true(grid_mgr.is_cell_occupied(test_cell), "Cell is initially occupied")

	# Free the node externally
	stale_node.free()

	# is_cell_occupied should self-heal and return false
	assert_false(grid_mgr.is_cell_occupied(test_cell), "is_cell_occupied should detect freed instance and return false")
	assert_null(grid_mgr.get_building_at(test_cell), "get_building_at should return null for pruned cell")
