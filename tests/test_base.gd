# res://tests/test_base.gd
# Base class for Defend Dinosaur v0.0 test suites.
# Provides structured assertions, signal monitoring, lifecycle hooks, and async utilities.
extends RefCounted

# Inner class for watching signal emissions and capturing arguments.
class SignalWatcher extends RefCounted:
	var target: Object
	var signal_name: String
	var emitted: bool = false
	var emit_count: int = 0
	var emission_args: Array = []
	var last_args: Array = []
	var _callable: Callable

	func _init(p_target: Object, p_signal_name: String) -> void:
		target = p_target
		signal_name = p_signal_name
		_callable = Callable(self, "_on_signal")
		if target != null and target.has_signal(signal_name):
			target.connect(signal_name, _callable)

	func _on_signal(a = null, b = null, c = null, d = null, e = null) -> void:
		emitted = true
		emit_count += 1
		var args: Array = []
		for arg in [a, b, c, d, e]:
			if arg != null:
				args.append(arg)
		last_args = args
		emission_args.append(args)

	func disconnect_watcher() -> void:
		if target != null and is_instance_valid(target) and target.has_signal(signal_name):
			if target.is_connected(signal_name, _callable):
				target.disconnect(signal_name, _callable)
		target = null

var tree: SceneTree = null
var current_test_name: String = ""
var assertions_passed: int = 0
var assertions_failed: int = 0
var failure_records: Array[Dictionary] = []
var _active_watchers: Array[SignalWatcher] = []

# --- Lifecycle Hooks (override in subclass as needed) ---
func before_all() -> void:
	pass

func before_each() -> void:
	pass

func after_each() -> void:
	# Clean up any signal watchers created during the test
	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	pass

# --- Signal Watcher Factory ---
func watch_signal(p_target: Object, p_signal_name: String) -> SignalWatcher:
	var watcher = SignalWatcher.new(p_target, p_signal_name)
	_active_watchers.append(watcher)
	return watcher

# --- Assertion Helpers ---

func _record_pass(_msg: String) -> void:
	assertions_passed += 1

func _record_fail(msg: String) -> void:
	assertions_failed += 1
	var record = {
		"test": current_test_name,
		"message": msg
	}
	failure_records.append(record)
	printerr("  [FAIL] %s: %s" % [current_test_name, msg])

func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		_record_pass(message)
		return true
	_record_fail("Expected TRUE, got FALSE. %s" % message)
	return false

func assert_false(condition: bool, message: String = "") -> bool:
	if not condition:
		_record_pass(message)
		return true
	_record_fail("Expected FALSE, got TRUE. %s" % message)
	return false

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		_record_pass(message)
		return true
	_record_fail("Expected '%s' (type %s), got '%s' (type %s). %s" % [
		str(expected), type_string(typeof(expected)),
		str(actual), type_string(typeof(actual)),
		message
	])
	return false

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected:
		_record_pass(message)
		return true
	_record_fail("Expected value NOT equal to '%s', but values matched. %s" % [str(expected), message])
	return false

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> bool:
	if abs(actual - expected) <= tolerance:
		_record_pass(message)
		return true
	_record_fail("Expected '%s' within tolerance %s, got '%s'. %s" % [
		str(expected), str(tolerance), str(actual), message
	])
	return false

## Ordering comparisons on values of different types are a RUNTIME ERROR in GDScript,
## not a false. An error inside a test aborts that test -- and the runner, which only
## sees assertions, reports whatever ran before it as a pass. So a test could compare a
## Dictionary with an int, silently stop there, and be counted green.
##
## Checking the types first turns that into an ordinary failure with a readable message.
func _comparable(actual: Variant, expected: Variant, op: String, message: String) -> bool:
	if typeof(actual) == typeof(expected):
		return true
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(actual) in numeric and typeof(expected) in numeric:
		return true
	_record_fail("Cannot compare %s %s %s: '%s' is a %s, '%s' is a %s. %s" % [
		str(actual), op, str(expected),
		str(actual), type_string(typeof(actual)),
		str(expected), type_string(typeof(expected)), message])
	return false

func assert_gt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if not _comparable(actual, expected, ">", message):
		return false
	if actual > expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s > %s. %s" % [str(actual), str(expected), message])
	return false

func assert_gte(actual: Variant, expected: Variant, message: String = "") -> bool:
	if not _comparable(actual, expected, ">=", message):
		return false
	if actual >= expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s >= %s. %s" % [str(actual), str(expected), message])
	return false

func assert_lt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if not _comparable(actual, expected, "<", message):
		return false
	if actual < expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s < %s. %s" % [str(actual), str(expected), message])
	return false

func assert_lte(actual: Variant, expected: Variant, message: String = "") -> bool:
	if not _comparable(actual, expected, "<=", message):
		return false
	if actual <= expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s <= %s. %s" % [str(actual), str(expected), message])
	return false

func assert_null(value: Variant, message: String = "") -> bool:
	if value == null:
		_record_pass(message)
		return true
	_record_fail("Expected NULL, got '%s'. %s" % [str(value), message])
	return false

func assert_not_null(value: Variant, message: String = "") -> bool:
	if value != null:
		_record_pass(message)
		return true
	_record_fail("Expected NOT NULL, got NULL. %s" % message)
	return false

func assert_has(collection: Variant, element_or_key: Variant, message: String = "") -> bool:
	if collection != null and element_or_key in collection:
		_record_pass(message)
		return true
	_record_fail("Expected collection '%s' to contain '%s'. %s" % [str(collection), str(element_or_key), message])
	return false

func assert_not_has(collection: Variant, element_or_key: Variant, message: String = "") -> bool:
	if collection != null and not (element_or_key in collection):
		_record_pass(message)
		return true
	_record_fail("Expected collection '%s' NOT to contain '%s'. %s" % [str(collection), str(element_or_key), message])
	return false

func assert_has_method(target: Object, method_name: String, message: String = "") -> bool:
	if target != null and target.has_method(method_name):
		_record_pass(message)
		return true
	_record_fail("Object %s does not implement method '%s'. %s" % [str(target), method_name, message])
	return false

func assert_has_signal(target: Object, signal_name: String, message: String = "") -> bool:
	if target != null and target.has_signal(signal_name):
		_record_pass(message)
		return true
	_record_fail("Object %s does not declare signal '%s'. %s" % [str(target), signal_name, message])
	return false

# --- Async Utilities ---

## A REAL LEVEL, which since v0.5 is what anything about walking has to be tested on.
##
## A bare GridManager has no colliders in it, and a bake is made of colliders -- so a
## fixture built that way has no navigation mesh, and every question about where somebody
## can walk comes back "anywhere". Before the grid A* was deleted those fixtures quietly
## answered from the grid instead, which is how "the game runs the mesh and the tests run
## the grid" nearly became true: the PackDino targeting override hid behind exactly that
## gap for a whole version.
##
## Caller owns the node and frees it, the same as anything else it instantiates.
## How many tiles a freshly laid level holds on the grid: the cabin's whole block and
## the nest. The cabin used to be one tile, and "exactly 2" was written into test after
## test.
func level_tiles_at_start() -> int:
	var cfg = tree.root.get_node_or_null("Config")
	var span: int = int(cfg.get_building_span("core")) if cfg and cfg.has_method("get_building_span") else 1
	return span * span + 1

## Where the cabin is: the middle of its block of tiles, not the middle of the tile it
## was placed at -- which is now inside its walls.
func cabin_at(main: Node) -> Vector3:
	return (main.current_core as Node3D).global_position

## A tile near the cabin that nothing in the level uses, for a test to build on. It was
## (1, 1), which is inside the cabin now.
const FREE_TILE := Vector2i(3, 3)

func fresh_level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	tree.root.add_child(main)
	# Long enough for the navigation server to sync its maps twice. Before the second
	# sync map_get_closest_point answers (0, 0, 0) and every route is empty, with nothing
	# in the answer to say so.
	await wait_frames(8)
	return main

## A bare fixture with a NAVIGATION MESH over it, for suites that do not want a whole
## level but do ask where somebody can walk.
##
## Returns a Node3D holding a ground plane and a NavMaps, already in the bake's source
## group. Anything the test adds as a CHILD of it -- a stake, a turret, a hill from
## `block_out_a_hill` -- is in the next bake. Call `rebake_fixture` after adding
## geometry, because a bake is only redone on a building_placed signal a bare fixture
## never sends.
##
## Caller owns the node and frees it.
func nav_fixture(extent: float = 60.0) -> Node3D:
	var world := Node3D.new()
	world.name = "NavFixture"
	world.add_to_group(NavMaps.SOURCE_GROUP)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1        # the layer the real level's ground is on
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(extent, 0.4, extent)
	shape.shape = box
	shape.position = Vector3(0.0, -0.2, 0.0)
	ground.add_child(shape)
	world.add_child(ground)
	var maps := NavMaps.new()
	maps.name = "NavMaps"
	world.add_child(maps)
	tree.root.add_child(world)
	await wait_frames(8)
	return world

## A cell of hillside in a nav fixture: the same box the level builds, on the same layer.
## The grid has to be told separately -- gm.set_blocked_cells -- exactly as in the level,
## where the rule and the shape are laid down together by Main.spawn_terrain.
func block_out_a_hill(world: Node3D, gm: Node, cell: Vector2i, height: float = 2.2) -> Node3D:
	var hill := StaticBody3D.new()
	hill.name = "Hill_%d_%d" % [cell.x, cell.y]
	hill.collision_layer = 1
	hill.collision_mask = 0
	hill.position = gm.cell_to_world(cell)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(gm.tile_size), height, float(gm.tile_size))
	shape.shape = box
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	hill.add_child(shape)
	world.add_child(hill)
	return hill

## A REAL run of stakes from `from_world` to `to_world`, laid the way the game lays one.
##
## One stake per TILE is not a fence. A stake is 0.62m and tiles are 2m apart, so eight
## of them round a cell is eight cones with 1.38m of open ground between them -- which is
## the v0.4 finding that a stake is as big as the stake, and it means a fixture that
## "encloses" something that way encloses nothing. Stakes seal on their own finer grid
## (Config.BUILDINGS.wall.cell_divisions), 0.67m apart, and that is what this lays.
##
## Registers each one the way BuildSystem does, so the grid knows about them too.
func run_of_stakes(world: Node3D, gm: Node, from_world: Vector3, to_world: Vector3) -> Array[Node]:
	var cfg = tree.root.get_node_or_null("Config")
	var divisions: int = int(cfg.get_cell_divisions("wall")) if cfg else 3
	var step: float = float(gm.tile_size) / float(maxi(1, divisions))
	var span: float = from_world.distance_to(to_world)
	var out: Array[Node] = []
	var seen: Dictionary = {}
	var steps: int = maxi(1, int(ceil(span / (step * 0.5))))
	for i in range(steps + 1):
		var at: Vector3 = from_world.lerp(to_world, float(i) / float(steps))
		var fine: Vector2i = gm.world_to_fine_cell(at, divisions)
		if seen.has(fine):
			continue
		seen[fine] = true
		var w = load("res://scripts/entities/Wall.gd").new()
		world.add_child(w)
		w.setup("wall", gm.fine_cell_to_cell(fine, divisions))
		w.position = gm.fine_cell_to_world(fine, divisions)
		w.complete_construction()
		gm.occupy_fine_cell(fine, w, divisions)
		out.append(w)
	return out

## The maps of a nav fixture (or of a level -- there is only ever one set in the tree).
func maps_of(_world: Node = null) -> Node:
	return tree.root.get_tree().get_first_node_in_group(NavMaps.GROUP)

## Rebuilds a fixture's meshes and waits for the server to take them.
func rebake_fixture() -> void:
	var maps := maps_of()
	if maps != null:
		maps.rebake()
	await wait_frames(8)

## Every mesh inside a building's "Body" holder, at ANY depth.
##
## One level used to be enough, because every building was built from primitives
## directly under Body. A model is not: its meshes sit inside the imported scene's own
## nodes, a level or more further down, and a one-level search finds nothing at all.
func body_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var body: Node = node if String(node.name) == "Body" else node.find_child("Body", false, false)
	if body == null:
		return out
	for m in body.find_children("*", "MeshInstance3D", true, false):
		out.append(m as MeshInstance3D)
	if body is MeshInstance3D:
		out.append(body as MeshInstance3D)
	return out

## How wide the top of a mesh is against its base, from its own vertices: a sharpened
## thing is narrow at the top. Works the same on a primitive cone and on a model, which is
## the point -- "is it pointed" is a question about shape, not about which Mesh class drew it.
func top_to_base_width(mi: MeshInstance3D, slice: float = 0.12) -> float:
	if mi == null or mi.mesh == null:
		return 1.0
	var aabb: AABB = mi.mesh.get_aabb()
	var top_y: float = aabb.end.y - aabb.size.y * slice
	var tlo := Vector2(INF, INF)
	var thi := Vector2(-INF, -INF)
	for si in range(mi.mesh.get_surface_count()):
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y >= top_y:
				tlo = Vector2(minf(tlo.x, v.x), minf(tlo.y, v.z))
				thi = Vector2(maxf(thi.x, v.x), maxf(thi.y, v.z))
	if is_inf(tlo.x):
		return 1.0
	var top_w: float = maxf(thi.x - tlo.x, thi.y - tlo.y)
	return top_w / maxf(0.0001, maxf(aabb.size.x, aabb.size.z))

func wait_frames(frame_count: int = 1) -> void:
	if tree != null:
		for i in range(frame_count):
			await tree.process_frame

## Waits for PHYSICS frames, which is a different clock from process frames: physics is
## a fixed sixty ticks a second and process frames in a headless run are uncapped. Use it
## when the code under test counts frames or moves -- everything that moves moves in
## _physics_process.
func wait_physics_frames(frame_count: int = 1) -> void:
	if tree != null:
		for i in range(frame_count):
			await tree.physics_frame

func wait_seconds(sec: float) -> void:
	if tree != null:
		var start_time: int = Time.get_ticks_msec()
		var target_ms: int = int(sec * 1000.0)
		while (Time.get_ticks_msec() - start_time) < target_ms:
			await tree.process_frame

func wait_for_signal(p_target: Object, p_signal_name: String, timeout_sec: float = 1.0) -> bool:
	if p_target == null or not p_target.has_signal(p_signal_name):
		return false
	var fired: Array[bool] = [false]
	var cb = func(_a = null, _b = null, _c = null, _d = null, _e = null):
		fired[0] = true
	p_target.connect(p_signal_name, cb, Object.CONNECT_ONE_SHOT)
	var start_time: int = Time.get_ticks_msec()
	var timeout_ms: int = int(timeout_sec * 1000.0)
	while not fired[0] and (Time.get_ticks_msec() - start_time) < timeout_ms:
		if tree != null:
			await tree.process_frame
		else:
			break
	if p_target.is_connected(p_signal_name, cb):
		p_target.disconnect(p_signal_name, cb)
	return fired[0]

# ==============================================================================
# Balance helpers
# ==============================================================================

## Cost of a building straight from Config. Tests that only care about "the right
## amount was deducted" should use this instead of restating the tuning values,
## so a balance pass does not break them.
func cost_of(type_id: String, res_id: String = "wood") -> int:
	var cfg = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(type_id):
		return 0
	return int(cfg.BUILDINGS[type_id].get("cost", {}).get(res_id, 0))

## The wood a fresh game opens with, straight from Config.
##
## Since v0.3 that is wood lying on the ground by the cabin rather than a number
## in the wallet, so this is what the player has once they have picked it up --
## "the wallet is untouched" is `banked_wood() == 0` at the start of a game, and
## this figure is what the opening is balanced around.
func opening_wood() -> int:
	var cfg = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null:
		return 0
	var banked: int = 0
	if "INITIAL_RESOURCES" in cfg:
		banked = int(cfg.INITIAL_RESOURCES.get("wood", 0))
	var on_ground: int = 0
	if cfg.has_method("get_opening_stock"):
		on_ground = int(cfg.get_opening_stock("wood"))
	return banked + on_ground

## How much of `res_id` is lying on the ground as drops (v0.3). Production no
## longer banks anything directly -- a machine leaves a pile beside it and the
## warehouse only grows when the Hero fetches it -- so a test that means
## "production happened" asks this, not the wallet.
func ground_total(res_id: String) -> int:
	var sum: int = 0
	if not (Engine.get_main_loop() is SceneTree):
		return 0
	for d in Engine.get_main_loop().get_nodes_in_group("drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if "resource_type" in d and String(d.resource_type) == res_id:
			sum += int(d.amount)
	return sum

## Everything the player has earned of `res_id`, banked or still on the floor.
## The right measure for "did this produce anything", since where it currently
## sits is a matter of whether anyone has walked over it yet.
func earned_total(res_id: String) -> int:
	var gs = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		gs = Engine.get_main_loop().root.get_node_or_null("GameState")
	var banked: int = 0
	if gs and "resources" in gs:
		banked = int(gs.resources.get(res_id, 0))
	return banked + ground_total(res_id)

## Clears every drop on the ground. Suites that produce resources should call this
## between tests, or one test's piles turn up in the next one's totals.
func clear_drops() -> void:
	if not (Engine.get_main_loop() is SceneTree):
		return
	for d in Engine.get_main_loop().get_nodes_in_group("drops"):
		if is_instance_valid(d):
			if d.is_inside_tree():
				d.get_parent().remove_child(d)
			if not d.is_queued_for_deletion():
				d.free()

## What the wallet actually holds when a game starts, which since v0.3 is nothing:
## the opening stock is on the ground by the cabin. Tests asserting "a reset put
## the wallet back where it began" want this; tests asking "what can the opening
## buy" want opening_wood().
func opening_banked_wood() -> int:
	var cfg = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null or not ("INITIAL_RESOURCES" in cfg):
		return 0
	return int(cfg.INITIAL_RESOURCES.get("wood", 0))

## Grants every unlock the cabin can make. v0.4 gates stone-cutting behind a pick
## and the turret behind a blueprint; a test about something *else* should not have
## to walk that whole chain first, and naming the flags by hand would restate
## Config in every suite.
func unlock_all() -> void:
	var cfg = null
	var gs = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
		gs = Engine.get_main_loop().root.get_node_or_null("GameState")
	if cfg == null or gs == null or not gs.has_method("grant_unlock"):
		return
	if "RECIPES" in cfg:
		for recipe_id in cfg.RECIPES:
			gs.grant_unlock(String(cfg.RECIPES[recipe_id].get("unlocks", "")))

## Seeds the wallet with exactly what `type_ids` cost, in every resource they ask
## for. Since v0.4 a turret is bought with wood *and* stone, so "give them enough
## wood" is no longer the same as "they can afford it".
func pay_for(type_ids: Array, spare: int = 0) -> void:
	var cfg = null
	var gs = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
		gs = Engine.get_main_loop().root.get_node_or_null("GameState")
	if cfg == null or gs == null or not ("resources" in gs):
		return
	for t in type_ids:
		var type_id: String = String(t)
		if not cfg.BUILDINGS.has(type_id):
			continue
		for res_id in cfg.BUILDINGS[type_id].get("cost", {}):
			var have: int = int(gs.resources.get(res_id, 0))
			gs.resources[res_id] = have + int(cfg.BUILDINGS[type_id]["cost"][res_id])
	if spare > 0:
		for res_id in cfg.RESOURCES:
			gs.resources[res_id] = int(gs.resources.get(res_id, 0)) + spare

## Everything `type_id` costs, added up across resources. The figure the build-time
## curve is derived from.
func total_price_of(type_id: String) -> int:
	var cfg = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null or not cfg.BUILDINGS.has(type_id):
		return 0
	var sum: int = 0
	for res_id in cfg.BUILDINGS[type_id].get("cost", {}):
		sum += int(cfg.BUILDINGS[type_id]["cost"][res_id])
	return sum

## Total wood needed to place every type in `type_ids` once.
func total_cost_of(type_ids: Array, res_id: String = "wood") -> int:
	var sum: int = 0
	for t in type_ids:
		sum += cost_of(String(t), res_id)
	return sum
