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

## The light of the time of day (GameState.time_of_day, Config.DAY.light), every frame; the sky's
## own colours every Config.DAY.sky_every seconds, a change of them being a redraw of the sky.
func _process(delta: float) -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("time_of_day"):
		return
	_sky_clock -= delta
	# Through a leap of the clock -- the night of a game without one, in a few seconds -- every frame.
	var leaping: bool = gs.has_method("light_leaping") and bool(gs.light_leaping())
	var sky: bool = _sky_clock <= 0.0 or leaping
	if sky:
		var cfg = _get_config()
		_sky_clock = float(cfg.DAY.get("sky_every", 0.5)) if (cfg and "DAY" in cfg) else 0.5
	apply_time_of_day(float(gs.light_time()) if gs.has_method("light_time") else float(gs.time_of_day()), sky)

## Seconds till the sky's own colours are set again.
var _sky_clock: float = 0.0

## The light at `t` seconds into the day (Config.DAY.light, light_at) -- where the sun stands (at
## night, the moon), its colour and strength; the sky's light in the shadows; the haze's light; and,
## with `sky`, the sky's own colours.
func apply_time_of_day(t: float, sky: bool = true) -> void:
	var cfg = _get_config()
	if cfg == null or not ("DAY" in cfg):
		return
	var now: Dictionary = light_at(cfg.DAY.get("light", []), float(cfg.DAY.get("length", 360.0)), t)
	if now.is_empty():
		return
	var sun: DirectionalLight3D = _find_sun()
	if sun:
		sun.rotation_degrees = Vector3(-float(now["sun_elevation"]), float(now["sun_azimuth"]), 0.0)
		sun.light_color = now["sun_color"]
		sun.light_energy = float(now["sun_energy"])
	if environment == null:
		return
	environment.ambient_light_energy = float(now["ambient_energy"])
	environment.fog_light_color = now["fog_color"]
	if sky and environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
		var m := environment.sky.sky_material as ProceduralSkyMaterial
		m.sky_top_color = now["sky_top"]
		m.sky_horizon_color = now["sky_horizon"]

## The day's light at `t` seconds into a day `length` long, from its keyframes (Config.DAY.light): the
## two either side of `t` blended, every number and colour of them -- what the light is at a moment,
## for anything that follows it (the mist's brightness, FogOfWar). Empty with no keyframes.
static func light_at(keys: Array, length: float, t: float) -> Dictionary:
	if keys.is_empty():
		return {}
	var i: int = keys.size() - 1
	for k in keys.size():
		if float(keys[k]["at"]) <= t:
			i = k
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[(i + 1) % keys.size()]
	var a_at: float = float(a["at"])
	var b_at: float = float(b["at"])
	if b_at <= a_at:
		b_at += length   # across the night to the next first light
	var w: float = clampf((t - a_at) / maxf(0.001, b_at - a_at), 0.0, 1.0)
	var out: Dictionary = {}
	for key in a:
		var from: Variant = a[key]
		var to: Variant = b.get(key, from)
		if from is Color:
			out[key] = (from as Color).lerp(to, w)
		elif from is float or from is int:
			out[key] = lerpf(float(from), float(to), w)
		else:
			out[key] = from
	out["at"] = t
	return out

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

	# 7. Volumetric fog -- the humid air of a warm Mesozoic valley, with the sun in it.
	#
	# The distance fog above is a flat wash that only ever thickens with range, so it can
	# make a place look FAR but never make it look WET. Volumetric fog is actual haze in
	# the volume: it lies in the low ground, catches the sun (anisotropy -- forward
	# scattering is what makes light shafts), and gives even a steep top-down view a sense
	# of air between the camera and the ground. The engine's own, not a shader: rule 8.
	environment.volumetric_fog_enabled = bool(env_data.get("volumetric_fog_enabled", false))
	if environment.volumetric_fog_enabled:
		environment.volumetric_fog_density = float(env_data.get("volumetric_fog_density", 0.01))
		if env_data.has("volumetric_fog_albedo"):
			environment.volumetric_fog_albedo = env_data["volumetric_fog_albedo"]
		if env_data.has("volumetric_fog_emission"):
			environment.volumetric_fog_emission = env_data["volumetric_fog_emission"]
		environment.volumetric_fog_emission_energy = float(env_data.get("volumetric_fog_emission_energy", 0.0))
		environment.volumetric_fog_anisotropy = float(env_data.get("volumetric_fog_anisotropy", 0.3))
		environment.volumetric_fog_length = float(env_data.get("volumetric_fog_length", 64.0))
		environment.volumetric_fog_detail_spread = float(env_data.get("volumetric_fog_detail_spread", 2.0))
		environment.volumetric_fog_ambient_inject = float(env_data.get("volumetric_fog_ambient_inject", 0.0))
		environment.volumetric_fog_sky_affect = float(env_data.get("volumetric_fog_sky_affect", 1.0))

	# 8. Grading -- warmth and saturation, the engine's own colour adjustment.
	environment.adjustment_enabled = bool(env_data.get("adjustment_enabled", false))
	if environment.adjustment_enabled:
		environment.adjustment_brightness = float(env_data.get("adjustment_brightness", 1.0))
		environment.adjustment_contrast = float(env_data.get("adjustment_contrast", 1.0))
		environment.adjustment_saturation = float(env_data.get("adjustment_saturation", 1.0))

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
	# How strongly the sun lights the volumetric haze -- which is what draws the shafts.
	if env_data.has("sun_volumetric_fog_energy"):
		sun.light_volumetric_fog_energy = float(env_data["sun_volumetric_fog_energy"])
	# Where the sun stands. A lower, warmer sun than a flat noon rakes across the ground
	# and throws the long shadows that give tree ferns and dinosaurs their scale.
	if env_data.has("sun_elevation_degrees") and env_data.has("sun_azimuth_degrees"):
		sun.rotation_degrees = Vector3(-float(env_data["sun_elevation_degrees"]),
			float(env_data["sun_azimuth_degrees"]), 0.0)

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
