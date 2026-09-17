# res://tests/test_v05_environment.gd
# v0.5 visual MVP: Scene environment and lighting.
#
# In realistic PBR presentation with a fixed high-angle isometric camera, visual
# coherence is driven by lighting, ground occlusion, atmospheric depth, and
# tonemapping rolloff rather than polygon count. Models arriving with varied polygon
# densities still read as one cohesive world if the light and ground occlusion are right.
#
# The Constitution requires:
# 1. All numerical values must come from Config.ENVIRONMENT, never hardcoded in .tscn.
# 2. Tests derive expectations from Config.ENVIRONMENT, never repeating literals.
# 3. Cabin interior (parked at Y = -200) retains indoor light and clear visibility.
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

func _instantiate_main() -> Node:
	var scene = load("res://scenes/Main.tscn")
	var main = scene.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func _get_env(main: Node) -> Environment:
	var env_node := main.find_child("WorldEnvironment", false, false) as WorldEnvironment
	if env_node != null:
		return env_node.environment
	return null

# ==============================================================================
# 1. WorldEnvironment Node Presence & Structure
# ==============================================================================

func test_01_main_has_single_world_environment_with_valid_environment() -> void:
	var main = _instantiate_main()
	var env_nodes = main.find_children("*", "WorldEnvironment", true, false)
	assert_eq(env_nodes.size(), 1, "Main.tscn has exactly one WorldEnvironment node")

	var env_node := env_nodes[0] as WorldEnvironment
	assert_not_null(env_node, "The node is a WorldEnvironment")
	assert_true(env_node is SceneEnvironment, "The node uses SceneEnvironment script")
	assert_not_null(env_node.environment, "WorldEnvironment has an attached Environment resource")

# ==============================================================================
# 2. Tonemapping Configuration
# ==============================================================================

func test_02_environment_tonemap_matches_config() -> void:
	var main = _instantiate_main()
	var env := _get_env(main)
	assert_not_null(env, "Environment is available")

	var env_cfg: Dictionary = config_node.ENVIRONMENT
	assert_eq(env.tonemap_mode, env_cfg["tonemap_mode"],
		"Tonemap mode matches Config (AgX photographic highlight rolloff)")
	assert_almost_eq(env.tonemap_exposure, float(env_cfg["tonemap_exposure"]), 0.001,
		"Tonemap exposure matches Config")
	assert_almost_eq(env.tonemap_white, float(env_cfg["tonemap_white"]), 0.001,
		"Tonemap white point matches Config")

# ==============================================================================
# 3. Procedural Sky Configuration
# ==============================================================================

func test_03_environment_procedural_sky_matches_config() -> void:
	var main = _instantiate_main()
	var env := _get_env(main)
	assert_not_null(env, "Environment is available")

	var env_cfg: Dictionary = config_node.ENVIRONMENT
	assert_eq(env.background_mode, env_cfg["background_mode"],
		"Background mode matches Config (BG_SKY)")
	assert_not_null(env.sky, "Sky resource is set")
	assert_true(env.sky.sky_material is ProceduralSkyMaterial,
		"Sky material is ProceduralSkyMaterial")

	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	assert_eq(sky_mat.sky_top_color, env_cfg["sky_top_color"],
		"Sky top color matches Config")
	assert_eq(sky_mat.sky_horizon_color, env_cfg["sky_horizon_color"],
		"Sky horizon color matches Config")
	assert_eq(sky_mat.ground_bottom_color, env_cfg["ground_bottom_color"],
		"Ground bottom color matches Config")
	assert_eq(sky_mat.ground_horizon_color, env_cfg["ground_horizon_color"],
		"Ground horizon color matches Config")
	assert_almost_eq(sky_mat.sun_angle_max, float(env_cfg["sun_angle_max"]), 0.001,
		"Sun angle max matches Config")
	assert_almost_eq(sky_mat.sun_curve, float(env_cfg["sun_curve"]), 0.001,
		"Sun curve matches Config")

# ==============================================================================
# 4. Ambient Lighting Configuration
# ==============================================================================

func test_04_environment_ambient_light_matches_config() -> void:
	var main = _instantiate_main()
	var env := _get_env(main)
	assert_not_null(env, "Environment is available")

	var env_cfg: Dictionary = config_node.ENVIRONMENT
	assert_eq(env.ambient_light_source, env_cfg["ambient_source"],
		"Ambient light source matches Config (SKY)")
	assert_eq(env.ambient_light_color, env_cfg["ambient_color"],
		"Ambient light color matches Config")
	assert_almost_eq(env.ambient_light_energy, float(env_cfg["ambient_energy"]), 0.001,
		"Ambient light energy matches Config")
	assert_almost_eq(env.ambient_light_sky_contribution, float(env_cfg["ambient_sky_contribution"]), 0.001,
		"Ambient sky contribution matches Config")

# ==============================================================================
# 5. SSAO and Glow Configurations
# ==============================================================================

func test_05_environment_ssao_and_glow_match_config() -> void:
	var main = _instantiate_main()
	var env := _get_env(main)
	assert_not_null(env, "Environment is available")

	var env_cfg: Dictionary = config_node.ENVIRONMENT
	# SSAO
	assert_eq(env.ssao_enabled, bool(env_cfg["ssao_enabled"]),
		"SSAO enabled tracks Config")
	assert_almost_eq(env.ssao_radius, float(env_cfg["ssao_radius"]), 0.001,
		"SSAO radius matches Config")
	assert_almost_eq(env.ssao_intensity, float(env_cfg["ssao_intensity"]), 0.001,
		"SSAO intensity matches Config")
	assert_almost_eq(env.ssao_power, float(env_cfg["ssao_power"]), 0.001,
		"SSAO power matches Config")
	assert_almost_eq(env.ssao_detail, float(env_cfg["ssao_detail"]), 0.001,
		"SSAO detail matches Config")

	# Glow
	assert_eq(env.glow_enabled, bool(env_cfg["glow_enabled"]),
		"Glow enabled tracks Config")
	assert_almost_eq(env.glow_intensity, float(env_cfg["glow_intensity"]), 0.001,
		"Glow intensity matches Config")
	assert_almost_eq(env.glow_bloom, float(env_cfg["glow_bloom"]), 0.001,
		"Glow bloom matches Config")
	assert_eq(env.glow_blend_mode, env_cfg["glow_blend_mode"],
		"Glow blend mode matches Config")

# ==============================================================================
# 6. Atmospheric Fog Configuration
# ==============================================================================

func test_06_environment_atmospheric_fog_matches_config() -> void:
	var main = _instantiate_main()
	var env := _get_env(main)
	assert_not_null(env, "Environment is available")

	var env_cfg: Dictionary = config_node.ENVIRONMENT
	assert_eq(env.fog_enabled, bool(env_cfg["fog_enabled"]),
		"Fog enabled tracks Config")
	assert_eq(env.fog_mode, env_cfg["fog_mode"],
		"Fog mode matches Config")
	assert_eq(env.fog_light_color, env_cfg["fog_light_color"],
		"Fog light color matches Config")
	assert_almost_eq(env.fog_light_energy, float(env_cfg["fog_light_energy"]), 0.001,
		"Fog light energy matches Config")
	assert_almost_eq(env.fog_density, float(env_cfg["fog_density"]), 0.0001,
		"Fog density matches Config")
	assert_almost_eq(env.fog_aerial_perspective, float(env_cfg["fog_aerial_perspective"]), 0.001,
		"Fog aerial perspective matches Config")
	assert_almost_eq(env.fog_sky_affect, float(env_cfg["fog_sky_affect"]), 0.001,
		"Fog sky affect matches Config")
	assert_almost_eq(env.fog_depth_begin, float(env_cfg["fog_depth_begin"]), 0.001,
		"Fog depth begin matches Config")
	assert_almost_eq(env.fog_depth_end, float(env_cfg["fog_depth_end"]), 0.001,
		"Fog depth end matches Config")

# ==============================================================================
# 7. Directional Sun Light Configuration
# ==============================================================================

func test_07_sun_directional_light_matches_config() -> void:
	var main = _instantiate_main()
	var sun := main.find_child("DirectionalLight3D", false, false) as DirectionalLight3D
	assert_not_null(sun, "DirectionalLight3D exists in Main")

	var env_cfg: Dictionary = config_node.ENVIRONMENT
	assert_eq(sun.light_color, env_cfg["sun_light_color"],
		"Sun light color matches Config")
	assert_almost_eq(sun.light_energy, float(env_cfg["sun_light_energy"]), 0.001,
		"Sun light energy matches Config")
	assert_eq(sun.shadow_enabled, bool(env_cfg["sun_shadow_enabled"]),
		"Sun shadow enabled matches Config")
	assert_almost_eq(sun.shadow_bias, float(env_cfg["sun_shadow_bias"]), 0.001,
		"Sun shadow bias matches Config")
	assert_almost_eq(sun.shadow_normal_bias, float(env_cfg["sun_shadow_normal_bias"]), 0.001,
		"Sun shadow normal bias matches Config")
	assert_almost_eq(sun.shadow_blur, float(env_cfg["sun_shadow_blur"]), 0.001,
		"Sun shadow blur matches Config")
	assert_almost_eq(sun.directional_shadow_max_distance, float(env_cfg["sun_shadow_max_distance"]), 0.001,
		"Sun shadow max distance matches Config")

# ==============================================================================
# 8. Cabin Interior Compatibility & Fog Legibility
# ==============================================================================

func test_08_cabin_interior_preserves_lighting_and_visibility() -> void:
	var main = _instantiate_main()
	await wait_frames(2)

	assert_not_null(main.cabin_interior, "Cabin interior is instanced")
	var cabin_light := main.cabin_interior.find_child("CabinLight", false, false) as Light3D
	assert_not_null(cabin_light, "Cabin has dedicated CabinLight")
	assert_true(cabin_light.visible, "CabinLight is visible")
	assert_gt(cabin_light.light_energy, 0.0, "CabinLight is lit with positive energy")

	# Enter cabin: camera switches to cabin camera
	assert_true(main.enter_cabin(), "Stepping into cabin succeeds")
	assert_true(main.in_cabin, "Main registers in_cabin state")
	assert_true(main.cabin_interior.camera.current, "Cabin camera becomes current")
	assert_false(main.camera.current, "Map camera is not current while inside cabin")

	# Visibility assertion: fog begin distance must exceed cabin room dimensions so
	# the indoor scene is not obscured by outdoor prehistoric distance fog.
	var cam_distance_to_origin = main.cabin_interior.camera.position.length()
	var fog_begin: float = float(config_node.ENVIRONMENT["fog_depth_begin"])
	assert_lt(cam_distance_to_origin, fog_begin,
		"Cabin interior is within fog_depth_begin, preserving unclouded indoor visibility")

	# Exit cabin: restores map camera
	assert_true(main.leave_cabin(), "Leaving cabin succeeds")
	assert_false(main.in_cabin, "Main outside")
	assert_true(main.camera.current, "Map camera is active again")
