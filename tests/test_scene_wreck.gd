# res://tests/test_scene_wreck.gd
# SCENE-POLISH S5: Spaceship Wreck Verification Suite.
#
# Acceptance criteria from SCENE-POLISH.md:
# 1. Config.VISUALS["building/core"]["scene"] is non-empty and points to the cabin
#    (props/cabin_a.glb, since the core became a 2 x 2 crew module; wreck.glb was the pod).
# 2. Spaceship wreck model exists on disk, imports cleanly, and has real art loaded by VisualLibrary.
# 3. Invariant: is_barrier_building("core") remains strictly FALSE (Hero must have a lane past it).
# 4. Invariant: Art's horizontal projection strictly fits inside the declared collision box.
# 5. Core building instantiates cleanly, displays real mesh body, and manages HP / damage signals.
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
	assert_eq(scene_path, "res://assets/models/props/cabin_a.glb", "Scene path points to the cabin")
	assert_true(FileAccess.file_exists(scene_path), "File exists on disk: %s" % scene_path)
	assert_true(VisualLibrary.has_art("building/core"), "VisualLibrary recognizes building/core has real art")

# ==============================================================================
# 2. Barrier Invariant: is_barrier_building("core") Remains FALSE
# ==============================================================================

func test_02_is_barrier_building_core_remains_strictly_false() -> void:
	# Crucial gameplay invariant: footprint past ~1.2 would turn the base into a wall.
	# A ring of buildings or the base itself must NEVER seal the Hero in.
	assert_false(config_node.is_barrier_building("core"),
		"is_barrier_building('core') must remain FALSE -- base is not a wall")

	var fp: float = config_node.get_building_footprint("core")
	var hero_w: float = float(config_node.HERO.get("width", 0.8))
	# Its lane is what is left of its BLOCK of tiles, not of one tile.
	var lane: float = float(config_node.get_building_span("core")) * config_node.TILE_SIZE - fp

	assert_gt(lane, hero_w, "Gap beside core (%.2fm) is wider than Hero width (%.2fm)" % [lane, hero_w])
	assert_almost_eq(fp, float(config_node.get_building_span("core")) * config_node.TILE_SIZE - hero_w
		- float(config_node.BUILDING_CLEARANCE), 0.01, "Core footprint is its block less the Hero's way past")

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

	var col_fp: float = config_node.get_building_footprint("core")
	var col_height: float = config_node.get_building_height("core")

	# Art horizontal projection must not exceed physical collision footprint (1.0m)
	assert_lte(fitted_x, col_fp + 0.05, "Visual width X (%.2fm) <= collision footprint (%.2fm)" % [fitted_x, col_fp])
	assert_lte(fitted_z, col_fp + 0.05, "Visual depth Z (%.2fm) <= collision footprint (%.2fm)" % [fitted_z, col_fp])
	assert_lte(fitted_y, col_height + 0.05, "Visual height Y (%.2fm) <= collision height (%.2fm)" % [fitted_y, col_height])

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

	# 1. Collision shape
	var col: CollisionShape3D = null
	for child in core.get_children():
		if child is CollisionShape3D:
			col = child
			break
	assert_not_null(col, "CoreCampfire has CollisionShape3D")
	assert_true(col.shape is BoxShape3D, "Collision shape is BoxShape3D")
	var box: BoxShape3D = col.shape as BoxShape3D
	var fp: float = float(config_node.get_building_footprint("core"))
	var h: float = float(config_node.get_building_height("core"))
	assert_almost_eq(box.size.x, fp, 0.01, "Collider width X is its footprint")
	assert_almost_eq(box.size.y, h, 0.01, "Collider height Y is its height")
	assert_almost_eq(box.size.z, fp, 0.01, "Collider depth Z is its footprint")

	# 2. Visual body
	var body: Node3D = core.find_child("Body", false, false) as Node3D
	assert_not_null(body, "CoreCampfire has Body node")
	var meshes = body.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Body has MeshInstance3D nodes from the cabin model")

	# 3. HP and signals
	assert_eq(core.current_hp, 10.0, "Initial Core HP is 10.0")
	var hp_signal_fired: Array = []
	var eb = tree.root.get_node_or_null("EventBus")
	if eb:
		eb.core_hp_changed.connect(func(cur, max_hp): hp_signal_fired.append([cur, max_hp]))
	core.take_damage(2.0)
	assert_eq(core.current_hp, 8.0, "Core takes damage properly")
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
