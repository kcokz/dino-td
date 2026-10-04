# res://scripts/fx/CabinArt.gd
class_name CabinArt
extends RefCounted

## The cabin's models show how far the run has got. The tools hang on the workbench's board
## once they are made, the beacon's mast goes back up a stage at a time and its screen comes
## alive. Each model is one file of named parts (tools/generate_cabin.py), and a part's name
## says when it shows:
##
##   <job id>          once that job is done ("stone_axe", "beacon_2", "beacon_launch")
##   before_<job id>   until it is done (the beacon's broken mast is "before_beacon_1")
##   anything else     always
##
## ahead of either, a tag for how it is drawn that says nothing about when: "fade_" (faded with
## the cabin's roof while he is inside) and "lamp_" (a light of its own, apart from the bench's
## lights of the same job) -- the cabin's roof mast is "fade_beacon_2", its lamp
## "lamp_beacon_2_glow".
##
## A name ending "_glow" is drawn lit by itself -- the pod's fluid, a screen, daylight through
## a porthole -- and lights the room round it when Config.CABIN.glow_lights names it.
##
## So the art says which job a piece belongs to, and the game's own record of what is done
## -- a recipe's unlock flag, the beacon's steps -- says whether it shows. A new tool is a
## recipe in Config and a part in the model with its id; nothing here changes.

const GLOW_SUFFIX: String = "_glow"
const BEFORE_PREFIX: String = "before_"
## How a part is drawn, ahead of its job in its name; nothing to do with when it shows.
const TAGS: Array[String] = ["fade_", "lamp_"]
## Every light a glowing part carries is named this, so they can be found again to animate.
const LIGHT_NAME: String = "GlowLight"
## The meta a material this makes carries (owns).
const OWNED: StringName = &"cabin_art"
## How far apart two lights read the flicker noise: far enough that no two waver together.
const NOISE_LANE: float = 50.0
## A blinking lamp between its flashes: all but gone, a dull glass.
const BLINK_DARK: float = 0.8

static var _glow_material: StandardMaterial3D = null
static var _noise: FastNoiseLite = null

## The parts of a model: every mesh under `body`.
static func parts(body: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if body == null:
		return out
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		out.append(mi as MeshInstance3D)
	return out

## The job a part's name waits on, and whether it shows BEFORE that job rather than after:
## "before_beacon_1" -> ["beacon_1", true]; "beacon_3_glow" -> ["beacon_3", false].
static func condition(part_name: String) -> Array:
	var n: String = part_name
	for tag in TAGS:
		if n.begins_with(tag):
			n = n.substr(tag.length())
	if n.ends_with(GLOW_SUFFIX):
		n = n.substr(0, n.length() - GLOW_SUFFIX.length())
	if n.begins_with(BEFORE_PREFIX):
		return [n.substr(BEFORE_PREFIX.length()), true]
	return [n, false]

## Shows and hides the parts of `body` by how far the run has got. `is_job` says whether a
## name is a job at all (a part called "base" is not, and always shows); `is_done` whether
## that job is done.
static func show_parts(body: Node, is_job: Callable, is_done: Callable) -> void:
	for mi in parts(body):
		var c: Array = condition(String(mi.name))
		if not bool(is_job.call(String(c[0]))):
			mi.visible = true
			continue
		var done: bool = bool(is_done.call(String(c[0])))
		mi.visible = (not done) if bool(c[1]) else done

## Draws the glowing parts of `body` lit by themselves, and gives each that `lights` names
## an OmniLight3D of its own at its middle: {part name: {color, energy, range, flicker, speed}}.
## A hidden part's light goes out with it -- it is the part's child.
static func light_glows(body: Node, lights: Dictionary) -> void:
	for mi in parts(body):
		var part: String = String(mi.name)
		if not part.ends_with(GLOW_SUFFIX):
			continue
		mi.material_override = glow_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spec: Dictionary = lights.get(part, {})
		if spec.is_empty() or mi.get_node_or_null(LIGHT_NAME) != null:
			continue
		var light := OmniLight3D.new()
		light.name = LIGHT_NAME
		light.light_color = spec.get("color", Color.WHITE)
		light.light_energy = float(spec.get("energy", 1.0))
		light.omni_range = float(spec.get("range", 3.0))
		light.shadow_enabled = false
		light.position = mi.get_aabb().get_center()
		light.set_meta("energy", light.light_energy)
		light.set_meta("flicker", float(spec.get("flicker", 0.0)))
		light.set_meta("speed", float(spec.get("speed", 1.0)))
		light.set_meta("blink", float(spec.get("blink", 0.0)))
		light.set_meta("duty", float(spec.get("duty", 0.5)))
		mi.add_child(light)

## Every light the glowing parts under `root` carry: gathered once, then animated each frame.
static func lights_under(root: Node) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	if root != null:
		for node in root.find_children(LIGHT_NAME, "OmniLight3D", true, false):
			out.append(node as OmniLight3D)
	return out

## Lets `lights` flicker as their parts ask -- a fire's hard, a failing screen's slow -- at
## `time` seconds. Smooth noise rather than random jumps: a flame wavers, it does not strobe.
static func animate(lights: Array[OmniLight3D], time: float) -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		# One feature of the noise per unit, so a light's "speed" is how many times a second
		# it wavers (the default reads a hundred units per feature -- a fire barely moved).
		_noise.frequency = 1.0
	var k: int = 0
	for light in lights:
		k += 1
		if not is_instance_valid(light):
			continue
		# A warning lamp on a mast blinks rather than wavers: on for `duty` of each of `blink`
		# flashes a second, the lamp itself dark between -- each on a beat of its own.
		var blink: float = float(light.get_meta("blink", 0.0))
		if blink > 0.0:
			var on: bool = fposmod(time * blink + float(k) * 0.37, 1.0) < float(light.get_meta("duty", 0.5))
			light.light_energy = float(light.get_meta("energy", 1.0)) if on else 0.0
			var lamp := light.get_parent() as GeometryInstance3D
			if lamp != null:
				lamp.transparency = 0.0 if on else BLINK_DARK
			continue
		var amount: float = float(light.get_meta("flicker", 0.0))
		if amount <= 0.0:
			continue
		# Each light reads its own stretch of the noise, so no two flicker together.
		var n: float = _noise.get_noise_2d(time * float(light.get_meta("speed", 1.0)), float(k) * NOISE_LANE)
		light.light_energy = float(light.get_meta("energy", 1.0)) * maxf(0.0, 1.0 + amount * n)

## Vertex colour at full strength, whatever light falls on it: what a glowing part is drawn
## with. One for every glowing part -- nothing about it ever changes per part.
static func glow_material() -> StandardMaterial3D:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.vertex_color_use_as_albedo = true
		_glow_material.vertex_color_is_srgb = true
		_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow_material.set_meta(OWNED, true)
	return _glow_material

## A window's glass (v0.6 round three: "有透明部分（窗）"): `col`, its alpha how much shows, glossy,
## seen from both sides -- the benches through it from outside, a raid through it from inside.
static func glass_material(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.set_meta(OWNED, true)
	return mat

## Whether `mat` is one of these -- a glow, a glass -- and so not a building's own to tint as it
## goes up (Building._update_visuals_progress made the glass solid).
static func owns(mat: Material) -> bool:
	return mat != null and mat.has_meta(OWNED)
