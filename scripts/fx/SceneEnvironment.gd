# res://scripts/fx/SceneEnvironment.gd
class_name SceneEnvironment
extends WorldEnvironment

## Configures the scene's WorldEnvironment and DirectionalLight3D from Config.ENVIRONMENT.
##
## Keeping all numbers in Config guarantees a single source of truth: designers can tune
## prehistoric sky colors, fog distances, and shadow bias in one data block, and tests can
## verify that presentation properties match declared values without opening .tscn files.

func _ready() -> void:
	apply_environment_config()
	apply_sun_config()

## Builds or updates the attached Environment resource according to Config.ENVIRONMENT.
func apply_environment_config() -> void:
	var cfg = _get_config()
	if cfg == null or not ("ENVIRONMENT" in cfg):
		return
	var env_data: Dictionary = cfg.ENVIRONMENT

	if environment == null:
		environment = Environment.new()

	# 1. Tonemapping -- AgX prevents highlight blowout on pale rock and dinosaur scales.
	environment.tonemap_mode = int(env_data.get("tonemap_mode", Environment.TONE_MAPPER_AGX))
	environment.tonemap_exposure = float(env_data.get("tonemap_exposure", 1.0))
	environment.tonemap_white = float(env_data.get("tonemap_white", 1.0))

	# 2. Background & Procedural Sky -- Prehistoric atmosphere with warm dust-haze horizon.
	environment.background_mode = int(env_data.get("background_mode", Environment.BG_SKY))
	if environment.sky == null:
		environment.sky = Sky.new()
	var sky_mat := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		sky_mat = ProceduralSkyMaterial.new()
		environment.sky.sky_material = sky_mat

	if env_data.has("sky_top_color"):
		sky_mat.sky_top_color = env_data["sky_top_color"]
	if env_data.has("sky_horizon_color"):
		sky_mat.sky_horizon_color = env_data["sky_horizon_color"]
	if env_data.has("ground_bottom_color"):
		sky_mat.ground_bottom_color = env_data["ground_bottom_color"]
	if env_data.has("ground_horizon_color"):
		sky_mat.ground_horizon_color = env_data["ground_horizon_color"]
	if env_data.has("sun_angle_max"):
		sky_mat.sun_angle_max = float(env_data["sun_angle_max"])
	if env_data.has("sun_curve"):
		sky_mat.sun_curve = float(env_data["sun_curve"])

	# 3. Ambient Light -- Sky contribution softly fills shadows so details remain legible.
	environment.ambient_light_source = int(env_data.get("ambient_source", Environment.AMBIENT_SOURCE_SKY))
	if env_data.has("ambient_color"):
		environment.ambient_light_color = env_data["ambient_color"]
	environment.ambient_light_energy = float(env_data.get("ambient_energy", 0.35))
	environment.ambient_light_sky_contribution = float(env_data.get("ambient_sky_contribution", 0.55))

	# 4. SSAO -- Plants stakes, buildings, and dinosaur feet firmly onto terrain.
	environment.ssao_enabled = bool(env_data.get("ssao_enabled", true))
	environment.ssao_radius = float(env_data.get("ssao_radius", 1.5))
	environment.ssao_intensity = float(env_data.get("ssao_intensity", 1.8))
	environment.ssao_power = float(env_data.get("ssao_power", 1.5))
	environment.ssao_detail = float(env_data.get("ssao_detail", 0.5))

	# 5. Glow -- Restrained bloom to preserve natural PBR response without neon bleed.
	environment.glow_enabled = bool(env_data.get("glow_enabled", true))
	environment.glow_intensity = float(env_data.get("glow_intensity", 0.3))
	environment.glow_bloom = float(env_data.get("glow_bloom", 0.08))
	environment.glow_blend_mode = int(env_data.get("glow_blend_mode", Environment.GLOW_BLEND_MODE_SOFTLIGHT))

	# 6. Atmospheric Fog -- Distance haze softening map borders while keeping playfield sharp.
	environment.fog_enabled = bool(env_data.get("fog_enabled", true))
	environment.fog_mode = int(env_data.get("fog_mode", Environment.FOG_MODE_EXPONENTIAL))
	if env_data.has("fog_light_color"):
		environment.fog_light_color = env_data["fog_light_color"]
	environment.fog_light_energy = float(env_data.get("fog_light_energy", 0.85))
	environment.fog_density = float(env_data.get("fog_density", 0.008))
	environment.fog_aerial_perspective = float(env_data.get("fog_aerial_perspective", 0.4))
	environment.fog_sky_affect = float(env_data.get("fog_sky_affect", 0.35))
	environment.fog_depth_begin = float(env_data.get("fog_depth_begin", 26.0))
	environment.fog_depth_end = float(env_data.get("fog_depth_end", 48.0))
	environment.fog_depth_curve = float(env_data.get("fog_depth_curve", 1.0))

## Updates DirectionalLight3D on parent scene with shadow bias and energy from Config.ENVIRONMENT.
func apply_sun_config() -> void:
	var cfg = _get_config()
	if cfg == null or not ("ENVIRONMENT" in cfg):
		return
	var env_data: Dictionary = cfg.ENVIRONMENT
	var sun: DirectionalLight3D = _find_sun()
	if sun == null:
		return

	if env_data.has("sun_light_color"):
		sun.light_color = env_data["sun_light_color"]
	if env_data.has("sun_light_energy"):
		sun.light_energy = float(env_data["sun_light_energy"])
	if env_data.has("sun_shadow_enabled"):
		sun.shadow_enabled = bool(env_data["sun_shadow_enabled"])
	if env_data.has("sun_shadow_bias"):
		sun.shadow_bias = float(env_data["sun_shadow_bias"])
	if env_data.has("sun_shadow_normal_bias"):
		sun.shadow_normal_bias = float(env_data["sun_shadow_normal_bias"])
	if env_data.has("sun_shadow_blur"):
		sun.shadow_blur = float(env_data["sun_shadow_blur"])
	if env_data.has("sun_shadow_max_distance"):
		sun.directional_shadow_max_distance = float(env_data["sun_shadow_max_distance"])

## The sun of THIS level: a sibling, and only a sibling.
##
## There used to be a fallback that searched the whole scene tree. It found a light
## every time, which is the problem -- with two levels loaded at once (the test suite
## does this routinely) one level's environment would configure the other level's sun.
## Finding nothing is the correct answer for a WorldEnvironment that has no sun beside
## it; reaching further to make sure it finds something is how a level ends up quietly
## driving a light it does not own.
func _find_sun() -> DirectionalLight3D:
	var parent_node = get_parent()
	if parent_node == null:
		return null
	return parent_node.find_child("DirectionalLight3D", false, false) as DirectionalLight3D

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
