# res://tests/test_grid_challenge.gd
# Empirical Challenger Test Suite for Milestone 2 GridManager and Coordinate Transforms.
# Stress-tests world-to-cell boundary transformations, float precision thresholds,
# large coordinate spans, rapid high-frequency cell occupancy/vacancy operations,
# self-healing from freed references, and fallback destruction handlers.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var grid_manager_script: GDScript = null
var building_script: GDScript = null

var _allocated_nodes: Array[Node] = []
var _allocated_objects: Array[Object] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")

	if config_node == null and ResourceLoader.exists("res://scripts/autoload/Config.gd"):
		config_node = load("res://scripts/autoload/Config.gd").new()
		_allocated_objects.append(config_node)

	if event_bus_node == null and ResourceLoader.exists("res://scripts/autoload/EventBus.gd"):
		event_bus_node = load("res://scripts/autoload/EventBus.gd").new()
		_allocated_objects.append(event_bus_node)

	if ResourceLoader.exists("res://scripts/core/GridManager.gd"):
		grid_manager_script = load("res://scripts/core/GridManager.gd")
	elif ResourceLoader.exists("res://scripts/core/grid_manager.gd"):
		grid_manager_script = load("res://scripts/core/grid_manager.gd")

	if ResourceLoader.exists("res://scripts/entities/Building.gd"):
		building_script = load("res://scripts/entities/Building.gd")
	elif ResourceLoader.exists("res://scripts/entities/building.gd"):
		building_script = load("res://scripts/entities/building.gd")

func after_each() -> void:
	for n in _allocated_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_allocated_nodes.clear()

	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _allocated_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				obj.free()
	_allocated_objects.clear()

func _create_grid() -> Node:
	assert_not_null(grid_manager_script, "GridManager script must exist")
	var grid = grid_manager_script.new()
	_allocated_nodes.append(grid)
	return grid

func _create_node() -> Node3D:
	var n = Node3D.new()
	_allocated_nodes.append(n)
	return n

# ==============================================================================
# Challenge 1: Origin, Epsilon Boundaries and Negative Zero
# ==============================================================================

func test_challenge_origin_and_epsilon_boundaries() -> void:
	var grid = _create_grid()
	if grid == null: return

	# Standard tile size = 2.0
	assert_eq(grid.tile_size, 2.0, "Tile size should default to 2.0")

	# Exact origin (0, 0, 0)
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, 0.0)), Vector2i(0, 0), "Origin (0,0,0) -> (0,0)")

	# Small positive epsilon within cell (0, 0)
	assert_eq(grid.world_to_cell(Vector3(0.0001, 0.0, 0.0)), Vector2i(0, 0), "+0.0001 X -> cell (0,0)")
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, 0.0001)), Vector2i(0, 0), "+0.0001 Z -> cell (0,0)")
	assert_eq(grid.world_to_cell(Vector3(0.0001, 0.0, 0.0001)), Vector2i(0, 0), "+0.0001 X,Z -> cell (0,0)")

	# Small negative epsilon immediately steps across border into negative cells
	assert_eq(grid.world_to_cell(Vector3(-0.0001, 0.0, 0.0)), Vector2i(-1, 0), "-0.0001 X -> cell (-1,0)")
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, -0.0001)), Vector2i(0, -1), "-0.0001 Z -> cell (0,-1)")
	assert_eq(grid.world_to_cell(Vector3(-0.0001, 0.0, -0.0001)), Vector2i(-1, -1), "-0.0001 X,Z -> cell (-1,-1)")

	# Negative zero float representation (-0.0)
	var neg_zero: float = -0.0
	assert_eq(grid.world_to_cell(Vector3(neg_zero, 0.0, neg_zero)), Vector2i(0, 0), "Negative zero -0.0 -> cell (0,0)")

# ==============================================================================
# Challenge 2: Positive Tile Transition Boundaries (1.9999, 2.0, 3.9999, 4.0)
# ==============================================================================

func test_challenge_tile_transition_boundaries_positive() -> void:
	var grid = _create_grid()
	if grid == null: return

	# [0.0, 2.0) -> cell 0
	assert_eq(grid.world_to_cell(Vector3(1.9999, 0.0, 0.0)), Vector2i(0, 0), "1.9999 X -> cell (0,0)")
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, 1.9999)), Vector2i(0, 0), "1.9999 Z -> cell (0,0)")
	assert_eq(grid.world_to_cell(Vector3(1.9999, 0.0, 1.9999)), Vector2i(0, 0), "1.9999 X,Z -> cell (0,0)")

	# Boundary exactly at 2.0 -> cell 1
	assert_eq(grid.world_to_cell(Vector3(2.0, 0.0, 0.0)), Vector2i(1, 0), "2.0 X -> cell (1,0)")
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, 2.0)), Vector2i(0, 1), "2.0 Z -> cell (0,1)")
	assert_eq(grid.world_to_cell(Vector3(2.0, 0.0, 2.0)), Vector2i(1, 1), "2.0 X,Z -> cell (1,1)")

	# Just past boundary at 2.0001 -> cell 1
	assert_eq(grid.world_to_cell(Vector3(2.0001, 0.0, 0.0)), Vector2i(1, 0), "2.0001 X -> cell (1,0)")

	# Next transition: 3.9999 -> cell 1, 4.0 -> cell 2
	assert_eq(grid.world_to_cell(Vector3(3.9999, 0.0, 0.0)), Vector2i(1, 0), "3.9999 X -> cell (1,0)")
	assert_eq(grid.world_to_cell(Vector3(4.0, 0.0, 0.0)), Vector2i(2, 0), "4.0 X -> cell (2,0)")
	assert_eq(grid.world_to_cell(Vector3(4.0001, 0.0, 0.0)), Vector2i(2, 0), "4.0001 X -> cell (2,0)")

	# Mixed coordinates
	assert_eq(grid.world_to_cell(Vector3(1.9999, 0.0, 2.0)), Vector2i(0, 1), "(1.9999, 2.0) -> (0,1)")
	assert_eq(grid.world_to_cell(Vector3(2.0, 0.0, 1.9999)), Vector2i(1, 0), "(2.0, 1.9999) -> (1,0)")

# ==============================================================================
# Challenge 3: Negative Transition Boundaries (-1.9999, -2.0, -2.0001, -4.0)
# ==============================================================================

func test_challenge_negative_transition_boundaries() -> void:
	var grid = _create_grid()
	if grid == null: return

	# In mathematical floor division:
	# [-2.0, 0.0) -> cell -1
	# [-4.0, -2.0) -> cell -2
	# [-6.0, -4.0) -> cell -3

	assert_eq(grid.world_to_cell(Vector3(-1.9999, 0.0, 0.0)), Vector2i(-1, 0), "-1.9999 X -> cell (-1,0)")
	assert_eq(grid.world_to_cell(Vector3(-2.0, 0.0, 0.0)), Vector2i(-1, 0), "-2.0 X -> cell (-1,0)")
	assert_eq(grid.world_to_cell(Vector3(-2.0001, 0.0, 0.0)), Vector2i(-2, 0), "-2.0001 X -> cell (-2,0)")

	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, -1.9999)), Vector2i(0, -1), "-1.9999 Z -> cell (0,-1)")
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, -2.0)), Vector2i(0, -1), "-2.0 Z -> cell (0,-1)")
	assert_eq(grid.world_to_cell(Vector3(0.0, 0.0, -2.0001)), Vector2i(0, -2), "-2.0001 Z -> cell (0,-2)")

	# -3.9999 vs -4.0 vs -4.0001
	assert_eq(grid.world_to_cell(Vector3(-3.9999, 0.0, -3.9999)), Vector2i(-2, -2), "-3.9999 X,Z -> cell (-2,-2)")
	assert_eq(grid.world_to_cell(Vector3(-4.0, 0.0, -4.0)), Vector2i(-2, -2), "-4.0 X,Z -> cell (-2,-2)")
	assert_eq(grid.world_to_cell(Vector3(-4.0001, 0.0, -4.0001)), Vector2i(-3, -3), "-4.0001 X,Z -> cell (-3,-3)")

	# Mixed quadrant boundary
	assert_eq(grid.world_to_cell(Vector3(-2.0, 0.0, 2.0)), Vector2i(-1, 1), "(-2.0, 2.0) -> (-1,1)")
	assert_eq(grid.world_to_cell(Vector3(-2.0001, 0.0, 1.9999)), Vector2i(-2, 0), "(-2.0001, 1.9999) -> (-2,0)")

# ==============================================================================
# Challenge 4: Large Offsets & Extreme Coordinates
# ==============================================================================

func test_challenge_large_offsets_and_extreme_coordinates() -> void:
	var grid = _create_grid()
	if grid == null: return

	# Far positive world offset
	var far_pos = Vector3(100000.0, 0.0, 200000.0)
	assert_eq(grid.world_to_cell(far_pos), Vector2i(50000, 100000), "Far positive world position maps accurately")

	# Far negative world offset
	var far_neg = Vector3(-100000.0, 0.0, -200000.0)
	assert_eq(grid.world_to_cell(far_neg), Vector2i(-50000, -100000), "Far negative world position maps accurately")

	# Boundary check at large magnitude (199999.99 vs 200000.0)
	assert_eq(grid.world_to_cell(Vector3(199999.99, 0.0, 0.0)), Vector2i(99999, 0), "Large boundary before 200000.0")
	assert_eq(grid.world_to_cell(Vector3(200000.0, 0.0, 0.0)), Vector2i(100000, 0), "Large boundary exact 200000.0")
	assert_eq(grid.world_to_cell(Vector3(-199999.99, 0.0, 0.0)), Vector2i(-100000, 0), "Large negative boundary before -200000.0")
	assert_eq(grid.world_to_cell(Vector3(-200000.0, 0.0, 0.0)), Vector2i(-100000, 0), "Large negative boundary exact -200000.0")
	assert_eq(grid.world_to_cell(Vector3(-200000.01, 0.0, 0.0)), Vector2i(-100001, 0), "Large negative boundary past -200000.0")

	# Large cell coordinates roundtrip
	var big_cells = [
		Vector2i(100000, -100000),
		Vector2i(-500000, 500000),
		Vector2i(1000000, 1000000),
		Vector2i(-1000000, -1000000)
	]
	for c in big_cells:
		var world_p = grid.cell_to_world(c)
		var back_c = grid.world_to_cell(world_p)
		assert_eq(back_c, c, "Roundtrip consistency for large cell coordinate %s" % str(c))

# ==============================================================================
# Challenge 5: Cell-to-World Center and Origin Geometry
# ==============================================================================

func test_challenge_cell_to_world_geometry_and_origin_bounds() -> void:
	var grid = _create_grid()
	if grid == null: return

	var s = grid.tile_size # 2.0
	var test_cells = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(15, -23),
		Vector2i(-42, 99)
	]

	for c in test_cells:
		var center = grid.cell_to_world(c)
		var origin = grid.cell_to_world_origin(c)

		# Geometric property: center must be origin + Vector3(0.5*s, 0.0, 0.5*s)
		var offset = center - origin
		assert_almost_eq(offset.x, 0.5 * s, 0.0001, "Cell %s center.x offset from origin must be 0.5*tile_size" % str(c))
		assert_almost_eq(offset.z, 0.5 * s, 0.0001, "Cell %s center.z offset from origin must be 0.5*tile_size" % str(c))
		assert_almost_eq(offset.y, 0.0, 0.0001, "Cell %s center.y offset from origin must be 0.0" % str(c))

		# Origin must map into cell c (since origin is inclusive bottom-left corner)
		assert_eq(grid.world_to_cell(origin), c, "Cell %s origin must map back to cell %s" % [str(c), str(c)])

		# Center must map into cell c
		assert_eq(grid.world_to_cell(center), c, "Cell %s center must map back to cell %s" % [str(c), str(c)])

	# Elevation Y preserves arbitrary values
	var custom_y_values = [-123.456, 0.0, 42.0, 9999.0]
	for y in custom_y_values:
		var w = grid.cell_to_world(Vector2i(3, 4), y)
		assert_almost_eq(w.y, y, 0.0001, "Elevation Y preserved in cell_to_world (%f)" % y)
		var orig = grid.cell_to_world_origin(Vector2i(3, 4), y)
		assert_almost_eq(orig.y, y, 0.0001, "Elevation Y preserved in cell_to_world_origin (%f)" % y)

# ==============================================================================
# Challenge 6: Dynamic and Degenerate Tile Size Handling
# ==============================================================================

func test_challenge_dynamic_and_degenerate_tile_size() -> void:
	var grid = _create_grid()
	if grid == null: return

	# 1. Custom tile size = 1.0
	grid.tile_size = 1.0
	assert_eq(grid.world_to_cell(Vector3(0.9999, 0.0, 0.0)), Vector2i(0, 0), "tile_size=1.0: 0.9999 -> 0")
	assert_eq(grid.world_to_cell(Vector3(1.0, 0.0, 0.0)), Vector2i(1, 0), "tile_size=1.0: 1.0 -> 1")
	assert_eq(grid.world_to_cell(Vector3(-0.0001, 0.0, 0.0)), Vector2i(-1, 0), "tile_size=1.0: -0.0001 -> -1")
	assert_eq(grid.world_to_cell(Vector3(-1.0, 0.0, 0.0)), Vector2i(-1, 0), "tile_size=1.0: -1.0 -> -1")
	assert_eq(grid.world_to_cell(Vector3(-1.0001, 0.0, 0.0)), Vector2i(-2, 0), "tile_size=1.0: -1.0001 -> -2")

	# 2. Custom non-integer tile size = 3.5
	grid.tile_size = 3.5
	assert_eq(grid.world_to_cell(Vector3(3.4999, 0.0, 3.4999)), Vector2i(0, 0), "tile_size=3.5: 3.4999 -> 0")
	assert_eq(grid.world_to_cell(Vector3(3.5, 0.0, 3.5)), Vector2i(1, 1), "tile_size=3.5: 3.5 -> 1")
	assert_eq(grid.world_to_cell(Vector3(-3.5, 0.0, -3.5)), Vector2i(-1, -1), "tile_size=3.5: -3.5 -> -1")
	assert_eq(grid.world_to_cell(Vector3(-3.5001, 0.0, -3.5001)), Vector2i(-2, -2), "tile_size=3.5: -3.5001 -> -2")

	# 3. Degenerate tile size: 0.0 and negative values must fall back to 2.0 without division by zero
	grid.tile_size = 0.0
	assert_eq(grid.world_to_cell(Vector3(3.0, 0.0, 3.0)), Vector2i(1, 1), "tile_size=0.0 falls back to 2.0 safely (3.0 -> 1)")
	var world_0 = grid.cell_to_world(Vector2i(1, 1))
	assert_almost_eq(world_0.x, 3.0, 0.0001, "tile_size=0.0 cell_to_world falls back to 2.0")

	grid.tile_size = -5.0
	assert_eq(grid.world_to_cell(Vector3(3.0, 0.0, 3.0)), Vector2i(1, 1), "tile_size=-5.0 falls back to 2.0 safely (3.0 -> 1)")

# ==============================================================================
# Challenge 7: Coordinate Fuzzing & Oracle Range Verification
# ==============================================================================

func test_challenge_coordinate_fuzz_oracle() -> void:
	var grid = _create_grid()
	if grid == null: return
	grid.tile_size = 2.0
	var s = 2.0

	# Deterministic pseudo-random seed generator
	var rng = RandomNumberGenerator.new()
	rng.seed = 987654321

	for i in range(250):
		var rx = rng.randf_range(-5000.0, 5000.0)
		var rz = rng.randf_range(-5000.0, 5000.0)
		var ry = rng.randf_range(-100.0, 100.0)
		var pos = Vector3(rx, ry, rz)

		var cell = grid.world_to_cell(pos)

		# Oracle range check: rx must be in [cell.x * s, (cell.x + 1) * s)
		var min_x = float(cell.x) * s
		var max_x = float(cell.x + 1) * s
		var min_z = float(cell.y) * s
		var max_z = float(cell.y + 1) * s

		assert_gte(rx, min_x, "Fuzz iteration %d: rx >= min_x" % i)
		assert_lt(rx, max_x, "Fuzz iteration %d: rx < max_x" % i)
		assert_gte(rz, min_z, "Fuzz iteration %d: rz >= min_z" % i)
		assert_lt(rz, max_z, "Fuzz iteration %d: rz < max_z" % i)

		# Center roundtrip
		var center = grid.cell_to_world(cell)
		assert_eq(grid.world_to_cell(center), cell, "Fuzz iteration %d: roundtrip center matches cell" % i)

# ==============================================================================
# Challenge 8: Rapid Cell Occupancy Burst and Duplicate Rejection
# ==============================================================================

func test_challenge_rapid_cell_occupancy_burst() -> void:
	var grid = _create_grid()
	if grid == null: return

	var count = 200
	var nodes: Array[Node3D] = []
	var duplicate_nodes: Array[Node3D] = []

	for i in range(count):
		nodes.append(_create_node())
		duplicate_nodes.append(_create_node())

	# Burst occupy 200 distinct cells spanning positive and negative quadrants
	for i in range(count):
		var cell = Vector2i(i - 100, (i * 3) - 300)
		var success = grid.occupy_cell(cell, nodes[i])
		assert_true(success, "Burst occupy cell %s must return true" % str(cell))
		assert_true(grid.is_cell_occupied(cell), "Cell %s must report occupied" % str(cell))
		assert_eq(grid.get_building_at(cell), nodes[i], "Cell %s must hold placed node" % str(cell))

	assert_eq(grid.occupied_cells.size(), count, "occupied_cells dictionary size must equal burst count")
	assert_eq(grid.get_all_buildings().size(), count, "get_all_buildings() must return all %d buildings" % count)

	# Burst attempt duplicate placement on all 200 occupied cells
	for i in range(count):
		var cell = Vector2i(i - 100, (i * 3) - 300)
		var dup_success = grid.occupy_cell(cell, duplicate_nodes[i])
		assert_false(dup_success, "Duplicate occupy on cell %s must be rejected" % str(cell))
		assert_eq(grid.get_building_at(cell), nodes[i], "Original node in cell %s preserved" % str(cell))

	assert_eq(grid.occupied_cells.size(), count, "Dictionary size remains unchanged after duplicate attempts")

# ==============================================================================
# Challenge 9: Rapid Burst Vacate and Re-occupy
# ==============================================================================

func test_challenge_rapid_burst_vacate_and_reoccupy() -> void:
	var grid = _create_grid()
	if grid == null: return

	var count = 150
	var initial_nodes: Array[Node3D] = []
	var replacement_nodes: Array[Node3D] = []

	for i in range(count):
		initial_nodes.append(_create_node())
		replacement_nodes.append(_create_node())

	# Initial population
	for i in range(count):
		var cell = Vector2i(i, -i)
		grid.occupy_cell(cell, initial_nodes[i])

	assert_eq(grid.occupied_cells.size(), count, "Grid fully occupied")

	# Burst vacate all 150 cells
	for i in range(count):
		var cell = Vector2i(i, -i)
		grid.vacate_cell(cell)
		assert_false(grid.is_cell_occupied(cell), "Cell %s must be unoccupied after vacate" % str(cell))
		assert_null(grid.get_building_at(cell), "Cell %s building must be null after vacate" % str(cell))

	assert_eq(grid.occupied_cells.size(), 0, "occupied_cells dictionary must be completely empty")
	assert_eq(grid.get_all_buildings().size(), 0, "get_all_buildings() returns empty list")

	# Repeated vacate on empty cells (must be safe no-op)
	for i in range(count):
		var cell = Vector2i(i, -i)
		grid.vacate_cell(cell)
		assert_false(grid.is_cell_occupied(cell), "Empty cell remains unoccupied after redundant vacate")

	# Re-occupy all 150 cells with replacement nodes
	for i in range(count):
		var cell = Vector2i(i, -i)
		var res = grid.occupy_cell(cell, replacement_nodes[i])
		assert_true(res, "Re-occupying cell %s must succeed" % str(cell))
		assert_true(grid.is_cell_occupied(cell), "Cell %s is now re-occupied" % str(cell))
		assert_eq(grid.get_building_at(cell), replacement_nodes[i], "Cell %s holds replacement node" % str(cell))

	assert_eq(grid.occupied_cells.size(), count, "Grid fully re-occupied")

# ==============================================================================
# Challenge 10: High-Frequency Single-Cell Ping-Pong (Chicane)
# ==============================================================================

func test_challenge_high_frequency_single_cell_pingpong() -> void:
	var grid = _create_grid()
	if grid == null: return

	var target_cell = Vector2i(77, -99)

	for cycle in range(150):
		var node = _create_node()

		# 1. Occupy
		assert_true(grid.occupy_cell(target_cell, node), "Cycle %d: occupy must succeed" % cycle)
		assert_true(grid.is_cell_occupied(target_cell), "Cycle %d: is_cell_occupied true" % cycle)
		assert_eq(grid.get_building_at(target_cell), node, "Cycle %d: holds correct node" % cycle)

		# 2. Duplicate attempt
		var dup_node = _create_node()
		assert_false(grid.occupy_cell(target_cell, dup_node), "Cycle %d: duplicate occupy must fail" % cycle)

		# 3. Vacate
		grid.vacate_cell(target_cell)
		assert_false(grid.is_cell_occupied(target_cell), "Cycle %d: is_cell_occupied false" % cycle)
		assert_null(grid.get_building_at(target_cell), "Cycle %d: building is null" % cycle)
		assert_false(grid.occupied_cells.has(target_cell), "Cycle %d: cell key removed from map" % cycle)

# ==============================================================================
# Challenge 11: Stale Node Pruning & Self-Healing Stress
# ==============================================================================

func test_challenge_stale_node_pruning_and_self_healing() -> void:
	var grid = _create_grid()
	if grid == null: return

	var total = 60
	var nodes: Array[Node3D] = []
	for i in range(total):
		nodes.append(_create_node())
		grid.occupy_cell(Vector2i(i, 0), nodes[i])

	assert_eq(grid.occupied_cells.size(), total, "Initial 60 cells occupied")

	# External state mutations without notifying GridManager:
	# - Free 20 nodes immediately via .free()
	# - Queue-free 20 nodes via .queue_free() (simulating pending dealloc)
	# - Leave 20 nodes untouched (alive)
	for i in range(20):
		nodes[i].free()
		# nodes[i] is now dead

	for i in range(20, 40):
		nodes[i].queue_free()

	# GridManager.is_cell_occupied must self-heal on access
	for i in range(20):
		var c = Vector2i(i, 0)
		assert_false(grid.is_cell_occupied(c), "Freed node at cell %s must self-heal to unoccupied" % str(c))
		assert_null(grid.get_building_at(c), "Freed node at cell %s must return null" % str(c))

	for i in range(20, 40):
		var c = Vector2i(i, 0)
		assert_false(grid.is_cell_occupied(c), "Queued-for-deletion node at cell %s must self-heal to unoccupied" % str(c))
		assert_null(grid.get_building_at(c), "Queued-for-deletion node at cell %s must return null" % str(c))

	for i in range(40, 60):
		var c = Vector2i(i, 0)
		assert_true(grid.is_cell_occupied(c), "Living node at cell %s must remain occupied" % str(c))
		assert_eq(grid.get_building_at(c), nodes[i], "Living node returned correctly")

	# get_all_buildings() must self-heal and return only living instances
	var living = grid.get_all_buildings()
	assert_eq(living.size(), 20, "get_all_buildings() returns exactly the 20 alive nodes")

	# Self-healed cells must now be eligible for new occupation
	for i in range(40):
		var c = Vector2i(i, 0)
		var new_node = _create_node()
		assert_true(grid.occupy_cell(c, new_node), "Self-healed cell %s must accept new placement" % str(c))

# ==============================================================================
# Challenge 12: Reactive Destruction Fast-Path vs Fallback Search
# ==============================================================================

func test_challenge_reactive_destruction_and_fallback_search() -> void:
	var grid = _create_grid()
	if grid == null or building_script == null or event_bus_node == null: return

	# Case A: Normal building where building.cell_pos matches grid cell (fast-path)
	var b1 = building_script.new()
	_allocated_nodes.append(b1)
	var cell_1 = Vector2i(5, 5)
	grid.occupy_cell(cell_1, b1)
	assert_eq(b1.cell_pos, cell_1, "Building cell_pos assigned on occupy")
	assert_true(grid.is_cell_occupied(cell_1), "Cell 1 occupied")

	# Trigger destruction
	b1.take_damage(b1.max_hp)
	assert_false(grid.is_cell_occupied(cell_1), "Fast-path vacates cell_1 on building_destroyed")

	# Case B: Desynchronized building where cell_pos was corrupted/tampered
	var b2 = building_script.new()
	_allocated_nodes.append(b2)
	var real_cell = Vector2i(10, 10)
	grid.occupy_cell(real_cell, b2)
	b2.cell_pos = Vector2i(999, 999) # Intentionally corrupt cell_pos to non-existent cell

	# Trigger destruction - must trigger linear fallback search in GridManager._on_building_destroyed
	b2.take_damage(b2.max_hp)
	assert_false(grid.is_cell_occupied(real_cell), "Fallback linear search vacates real_cell even if cell_pos was desynchronized")

	# Case C: Plain Node3D without cell_pos property
	var plain_node = _create_node()
	var plain_cell = Vector2i(-12, 34)
	grid.occupy_cell(plain_cell, plain_node)
	assert_true(grid.is_cell_occupied(plain_cell), "Plain node occupied")

	# Simulate building_destroyed event for plain node
	event_bus_node.building_destroyed.emit(plain_node)
	assert_false(grid.is_cell_occupied(plain_cell), "Fallback search vacates plain node without cell_pos")

	# Case D: Event with null building or unmapped building
	event_bus_node.building_destroyed.emit(null)
	var stranger = _create_node()
	event_bus_node.building_destroyed.emit(stranger)
	# No crash, safe execution

# ==============================================================================
# Challenge 13: Null, Invalid and Semantic Alias Invariants
# ==============================================================================

func test_challenge_null_and_semantic_alias_invariants() -> void:
	var grid = _create_grid()
	if grid == null: return

	# 1. Null building rejection
	assert_false(grid.occupy_cell(Vector2i(0, 0), null), "occupy_cell with null building must return false")
	assert_false(grid.set_cell_occupied(Vector2i(0, 0), null), "set_cell_occupied with null building must return false")
	assert_false(grid.is_cell_occupied(Vector2i(0, 0)), "Cell remains unoccupied after null attempt")

	# 2. Semantic aliases equivalence
	var n1 = _create_node()
	var c1 = Vector2i(12, 12)
	assert_true(grid.set_cell_occupied(c1, n1), "set_cell_occupied works identically to occupy_cell")
	assert_true(grid.is_cell_occupied(c1), "Cell is occupied")

	grid.clear_cell(c1)
	assert_false(grid.is_cell_occupied(c1), "clear_cell works identically to vacate_cell")

	# 3. Double clear_grid safety
	grid.occupy_cell(Vector2i(1, 1), _create_node())
	grid.occupy_cell(Vector2i(2, 2), _create_node())
	assert_eq(grid.occupied_cells.size(), 2, "2 occupied cells")

	grid.clear_grid()
	assert_eq(grid.occupied_cells.size(), 0, "clear_grid empties map")
	grid.clear_grid()
	assert_eq(grid.occupied_cells.size(), 0, "Repeated clear_grid is safe idempotent no-op")

# ==============================================================================
# Challenge 14: Pseudo-Random State Machine Fuzz Harness (Oracle Simulation)
# ==============================================================================

func test_challenge_state_machine_fuzz_harness() -> void:
	var grid = _create_grid()
	if grid == null: return

	var rng = RandomNumberGenerator.new()
	rng.seed = 54321

	# Oracle shadow state
	var oracle_map: Dictionary = {} # Vector2i -> Node3D
	var grid_span: int = 8 # Grid range [-8, 8] x [-8, 8]

	for step in range(400):
		var op = rng.randi_range(0, 3)
		var cx = rng.randi_range(-grid_span, grid_span)
		var cz = rng.randi_range(-grid_span, grid_span)
		var cell = Vector2i(cx, cz)

		match op:
			0: # Attempt Occupy
				if oracle_map.has(cell):
					# Expect duplicate failure
					var dummy = _create_node()
					var res = grid.occupy_cell(cell, dummy)
					assert_false(res, "Fuzz step %d: duplicate occupy on %s must fail" % [step, str(cell)])
					assert_eq(grid.get_building_at(cell), oracle_map[cell], "Fuzz step %d: oracle node preserved" % step)
				else:
					var new_n = _create_node()
					var res = grid.occupy_cell(cell, new_n)
					assert_true(res, "Fuzz step %d: occupy empty cell %s must succeed" % [step, str(cell)])
					oracle_map[cell] = new_n

			1: # Attempt Vacate
				grid.vacate_cell(cell)
				oracle_map.erase(cell)
				assert_false(grid.is_cell_occupied(cell), "Fuzz step %d: cell %s must be unoccupied after vacate" % [step, str(cell)])
				assert_null(grid.get_building_at(cell), "Fuzz step %d: building at %s must be null" % [step, str(cell)])

			2: # Query Occupancy
				var expected_occ = oracle_map.has(cell)
				assert_eq(grid.is_cell_occupied(cell), expected_occ, "Fuzz step %d: is_cell_occupied matches oracle for %s" % [step, str(cell)])
				if expected_occ:
					assert_eq(grid.get_building_at(cell), oracle_map[cell], "Fuzz step %d: node matches oracle" % step)
				else:
					assert_null(grid.get_building_at(cell), "Fuzz step %d: node is null for unoccupied" % step)

			3: # Random Batch Verification
				assert_eq(grid.occupied_cells.size(), oracle_map.size(), "Fuzz step %d: dictionary size matches oracle size" % step)

	# Final clear verification
	grid.clear_grid()
	oracle_map.clear()
	assert_eq(grid.occupied_cells.size(), 0, "Fuzz final clear: grid is empty")
	assert_eq(grid.get_all_buildings().size(), 0, "Fuzz final clear: get_all_buildings empty")
