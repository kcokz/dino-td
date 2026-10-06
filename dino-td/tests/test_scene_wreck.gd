# res://tests/test_scene_wreck.gd
# SCENE-POLISH S5: Spaceship Wreck Verification Suite.
#
# Acceptance criteria from SCENE-POLISH.md:
# 1. Config.VISUALS["building/core"]["scene"] is non-empty and points to the cabin
#    (cabin/module_a.glb since v0.6 round three: the crew module, outside and in; wreck.glb was
#    the pod, props/cabin_a.glb the three-metre box).
# 2. Spaceship wreck model exists on disk, imports cleanly, and has real art loaded by VisualLibrary.
# 3. Invariant: the core is not a wall, and never seals the Hero in (a free cell beside it is a way past).
# 4. Invariant: Art's horizontal projection strictly fits inside the declared box, and its hull
#    stands as high as the walls that stop a body.
# 5. Core building instantiates cleanly, displays real mesh body, its walls where its hull is and
#    its room open, and manages HP / damage signals.
# 6. assets/CREDITS.md contains Spaceship Wreck entry with CC0 dedication.
extends "res://tests/test_base.gd"

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _keep(n: Node) -> Node:
	_cleanup_nodes.append(n)
	return n

# ==============================================================================
# 1. Asset Manifest & File Existence
# ==============================================================================

func test_01_core_scene_declared_and_file_exists() -> void:
	assert_true(config_node != null and ("VISUALS" in config_node), "Config.VISUALS is available")
	var visuals: Dictionary = config_node.VISUALS
	assert_true(visuals.has("building/core"), "Config.VISUALS has entry for building/core")

	var entry: Dictionary = visuals["building/core"]
	var scene_path: String = String(entry.get("scene", ""))
	assert_false(scene_path.is_empty(), "building/core scene path must not be empty")
	assert_eq(scene_path, "res://assets/models/cabin/module_a.glb", "Scene path points to the cabin")
	assert_true(FileAccess.file_exists(scene_path), "File exists on disk: %s" % scene_path)
	assert_true(VisualLibrary.has_art("building/core"), "VisualLibrary recognizes building/core has real art")

# ==============================================================================
# 2. Barrier Invariant: the core is not a wall
# ==============================================================================

func test_02_the_core_is_not_a_wall_and_never_seals_the_hero_in() -> void:
	# Crucial gameplay invariant: the base must NEVER seal the Hero in. It used to be kept by
	# sizing the cabin to leave a lane inside its block of tiles; since v0.6 round two it fills
	# whole cells of the building grid like everything else, and a way past it is a free cell
	# beside it -- which is wider than he is.
	assert_ne(String(config_node.get_building_kind("core")), "wall", "The base is not a wall")
	assert_almost_eq(float(config_node.get_building_footprint("core")),
		float(config_node.get_building_cells("core")) * float(config_node.BUILD_CELL), 0.001,
		"It fills whole cells")
	assert_gte(float(config_node.BUILD_CELL), float(config_node.HERO.get("width", 0.8)),
		"And one free cell beside it is a way past it for the Hero")

# ==============================================================================
# 3. Scale & Projection Invariant: Visual Projection Fits Inside Collision Box
# ==============================================================================

func test_03_visual_horizontal_projection_within_collision_box() -> void:
	var body = VisualLibrary.make("building/core")
	_keep(body)
	tree.root.add_child(body)

	assert_not_null(body, "VisualLibrary returns Body node")
	var bounds: AABB = VisualLibrary.visual_bounds(body)

	var fitted_x: float = bounds.size.x * body.scale.x
	var fitted_y: float = bounds.size.y * body.scale.y
	var fitted_z: float = bounds.size.z * body.scale.z

	var half: Vector2 = config_node.get_building_half("core")
	var col_height: float = config_node.get_building_height("core")

	# Art horizontal projection must not exceed its box on the ground.
	assert_lte(fitted_x, half.x * 2.0 + 0.05, "Visual width X (%.2fm) <= its box (%.2fm)" % [fitted_x, half.x * 2.0])
	assert_lte(fitted_z, half.y * 2.0 + 0.05, "Visual depth Z (%.2fm) <= its box (%.2fm)" % [fitted_z, half.y * 2.0])
	# Its hull stands as high as the walls that stop a body; the gun, the panel and the aerial on
	# top are not wall.
	var hull: MeshInstance3D = body.find_child("hull", true, false) as MeshInstance3D
	assert_not_null(hull, "The model has its hull")
	if hull:
		var hull_top: float = (body.global_transform.affine_inverse() * hull.global_transform * hull.get_aabb()).end.y
		assert_almost_eq(hull_top, col_height, 0.1, "The hull (%.2fm) stands as high as its walls (%.2fm)" % [hull_top, col_height])

	# Art must have meaningful 3D presence, not empty or collapsed
	assert_gt(fitted_x, 0.3, "Visual width X is substantive (%.2fm)" % fitted_x)
	assert_gt(fitted_y, 0.3, "Visual height Y is substantive (%.2fm)" % fitted_y)
	assert_gt(fitted_z, 0.3, "Visual depth Z is substantive (%.2fm)" % fitted_z)

# ==============================================================================
# 4. Core Entity Gameplay & Lifecycle
# ==============================================================================

func test_04_core_campfire_instantiates_with_art_and_valid_collision() -> void:
	var core = CoreCampfire.new()
	_keep(core)
	tree.root.add_child(core)
	await wait_frames(2)

	# 1. Collision: walls where the hull is, filling its box, and nothing in the room.
	var half: Vector2 = config_node.get_building_half("core")
	var h: float = float(config_node.get_building_height("core"))
	var span := AABB()
	var first: bool = true
	var shapes: int = 0
	var room_blocked: bool = false
	for child in core.get_children():
		if not (child is CollisionShape3D) or not ((child as CollisionShape3D).shape is BoxShape3D):
			continue
		shapes += 1
		var box: BoxShape3D = (child as CollisionShape3D).shape as BoxShape3D
		var at: AABB = AABB((child as Node3D).position - box.size * 0.5, box.size)
		span = at if first else span.merge(at)
		first = false
		assert_almost_eq(box.size.y, h, 0.01, "Each wall is its height")
		if at.has_point(Vector3(0.0, 1.0, 0.0)):
			room_blocked = true
	assert_gt(shapes, 1, "The cabin is walls, not a block")
	assert_almost_eq(span.size.x, half.x * 2.0, 0.01, "Its walls span its box east-west")
	assert_almost_eq(span.size.z, half.y * 2.0, 0.01, "and north-south")
	assert_false(room_blocked, "Its room is open")
	var way: StaticBody3D = core.find_child("DoorWay", false, false) as StaticBody3D
	assert_not_null(way, "Its doorway is a body of its own")
	if way:
		assert_eq(int(way.collision_layer), int(config_node.LAYER_GATE), "on the gate layer: his way in, a raid's wall")

	# 2. Visual body
	var body: Node3D = core.find_child("Body", false, false) as Node3D
	assert_not_null(body, "CoreCampfire has Body node")
	var meshes = body.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Body has MeshInstance3D nodes from the cabin model")

	# 3. HP and signals
	assert_eq(core.current_hp, core_hp(), "Initial Core HP is Config's")
	var hp_signal_fired: Array = []
	var eb = tree.root.get_node_or_null("EventBus")
	if eb:
		eb.core_hp_changed.connect(func(cur, max_hp): hp_signal_fired.append([cur, max_hp]))
	core.take_damage(2.0)
	assert_eq(core.current_hp, core_hp() - 2.0, "Core takes damage properly")
	assert_gt(hp_signal_fired.size(), 0, "core_hp_changed signal was emitted")

# ==============================================================================
# 5. Credits Ledger Completeness
# ==============================================================================

func test_05_credits_ledger_covers_wreck_model() -> void:
	var credits_path: String = "res://assets/CREDITS.md"
	assert_true(FileAccess.file_exists(credits_path), "assets/CREDITS.md exists")
	var f = FileAccess.open(credits_path, FileAccess.READ)
	assert_not_null(f, "Can read assets/CREDITS.md")
	var text = f.get_as_text()
	f.close()

	assert_true(text.contains("wreck.glb"), "CREDITS.md records wreck.glb")
	assert_true(text.contains("wreck.blend"), "CREDITS.md records wreck.blend")
	assert_true(text.contains("Spaceship Wreck"), "CREDITS.md records Spaceship Wreck")
	assert_true(text.contains("CC0"), "CREDITS.md documents CC0 licensing")
