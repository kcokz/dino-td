# res://tests/test_scene_asset_survey.gd
# SCENE-POLISH S1: Asset Survey & Licensing Ledger Verification.
#
# The Constitution & SCENE-POLISH rules require:
# 1. License integrity: assets/CREDITS.md must exist, be non-empty, and document every external/generated asset.
# 2. Decision documentation: docs/asset-选型.md must document candidate selection matrix.
# 3. Model integration: Trial model t_rex.glb correctly registers in Config.VISUALS and
#    assembles via VisualLibrary adhering to declared bounds.
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
# 1. Licensing Ledger Integrity (assets/CREDITS.md)
# ==============================================================================

func test_01_credits_file_exists_and_is_non_empty() -> void:
	var path := "res://assets/CREDITS.md"
	assert_true(FileAccess.file_exists(path), "assets/CREDITS.md exists in repository")

	var fa := FileAccess.open(path, FileAccess.READ)
	assert_not_null(fa, "assets/CREDITS.md can be opened for reading")
	var content := fa.get_as_text()
	fa.close()

	assert_gt(content.length(), 100, "assets/CREDITS.md is not an empty stub")
	assert_true(content.contains("CC0"), "Ledger specifies CC0 license commitments")
	assert_true(content.contains("t_rex.glb"), "Ledger documents trial model t_rex.glb")
	assert_true(content.contains("Quaternius"), "Ledger documents Quaternius candidates")
	assert_true(content.contains("Poly Haven"), "Ledger documents Poly Haven candidates")

func test_02_asset_decision_doc_exists_and_is_non_empty() -> void:
	var path := "res://docs/asset-选型.md"
	assert_true(FileAccess.file_exists(path), "docs/asset-选型.md exists in repository")

	var fa := FileAccess.open(path, FileAccess.READ)
	assert_not_null(fa, "docs/asset-选型.md can be opened for reading")
	var content := fa.get_as_text()
	fa.close()

	assert_gt(content.length(), 200, "docs/asset-选型.md contains detailed decision analysis")
	assert_true(content.contains("Quaternius"), "Documents Quaternius candidate evaluation")

# ==============================================================================
# 2. Pipeline Integration & Trial Dinosaur Fitting
# ==============================================================================

func test_03_big_theropod_has_art_and_points_to_valid_glb() -> void:
	var declared: String = VisualLibrary.declared_scene("dino/big_theropod")
	assert_ne(declared, "", "dino/big_theropod has a declared scene path")
	assert_true(ResourceLoader.exists(declared), "dino/big_theropod points to a loadable file")
	assert_true(VisualLibrary.has_art("dino/big_theropod"), "VisualLibrary acknowledges art presence")

func test_04_t_rex_trial_model_assembles_and_fits_within_declared_bounds() -> void:
	var body: Node3D = VisualLibrary.make("dino/big_theropod")
	_keep(body)
	tree.root.add_child(body)
	await wait_frames(1)

	var meshes = body.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Trial dinosaur model instantiates visible mesh geometry")

	var want_size: Vector3 = config_node.get_visual_size("dino/big_theropod")
	var bounds: AABB = VisualLibrary.visual_bounds(body)

	# Fitted by HEIGHT since v0.5 (Config.VISUALS "fit": "height"): a long-tailed animal
	# fitted inside its box by its length stood a third of its declared height. So it is
	# exactly as tall as declared and no wider, and longer than its box -- a tail reaches
	# past a collider, as a tail does -- but not absurdly: a theropod is about twice as
	# long as it stands tall. Measured against its HEIGHT, not the collider's depth, which
	# is the width of the body the game touches and says nothing about a tail.
	assert_lte(bounds.size.x, want_size.x + 0.05, "Fitted model width does not exceed declared width")
	assert_almost_eq(bounds.size.y, want_size.y, 0.05, "Fitted model is exactly the declared height")
	assert_lt(bounds.size.z, want_size.y * 2.5,
		"Longer than it is tall, as a tailed animal is, but not absurdly (%.1f m long, %.1f m tall)" % [bounds.size.z, want_size.y])
	assert_almost_eq(bounds.position.y, 0.0, 0.05, "Trial dinosaur stands planted on ground plane")
