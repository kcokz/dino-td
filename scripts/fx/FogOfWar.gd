# res://scripts/fx/FogOfWar.gd
class_name FogOfWar
extends Node3D

## The fog of war (GAME-DESIGN 9.3; v0.6 round three: "游戏要加上战争迷雾，人不能一开始就知道恐龙巢穴"):
## the field in three states -- never seen (dark), seen but out of sight now (the land, dimmed, and
## no animals on it), in sight (everything). What sees is the Hero, the cabin and what he has built
## (Config.FOG.sight), and less far at dusk and in the night. Never seen is thick mist in the
## valley's own haze -- the lie of the land a shade through it, and nothing on it drawn: no tree, no
## rock, no herd -- and everything past the field to the valley's far walls with it (v0.6 round four:
## "没去过的地方应该完全看不到"; then "全黑是不是有点不真实"). It is drawn by one quad over the whole
## screen, last of all (assets/shaders/fog_of_war.gdshader), the mist laid over each pixel by how
## seen the ground under it is: a decal laid on the ground left the river, which is drawn
## see-through, and the far walls in their haze as they were. It is the fog of war and not weather
## because it clears round everything that sees, and nowhere else. Animals out of sight are hidden
## outright, and hidden, cannot be pointed at (Main._is_hoverable). The nest is not seen until it
## is: the first time it comes into sight it is found (EventBus.nest_found, GameState.nest_found).
## A moment into a run it is explained, once (EventBus.fog_explained).

## Metres across the field's half, the margin round it included; metres to a cell; cells across.
var half: float = 32.0
var cell: float = 1.0
var cells: int = 64
## Per cell: ever seen; in sight now; how dark it is drawn, eased towards what it should be.
var _seen: PackedByteArray = PackedByteArray()
var _now: PackedByteArray = PackedByteArray()
var _shade: PackedFloat32Array = PackedFloat32Array()
var _bytes: PackedByteArray = PackedByteArray()
var _image: Image = null
var _texture: ImageTexture = null
## The quad over the screen, and its material: the shroud texture (one byte a cell, how dark), and
## where on the field it lies.
var shroud: MeshInstance3D = null
var _material: ShaderMaterial = null
var _clock: float = 0.0
## Seconds of this run played, and whether the mist has been explained yet (Config.FOG.hint_after).
var _played: float = 0.0
var _explained: bool = false
## Everything seen and in sight, and nothing hidden: for a view that has to show the whole field.
var revealed: bool = false

## Laid over a field `field_half` metres from its middle to its edge (Config.TERRAIN.field_half).
## How anything finds the fog without being handed it (Dino: whether it is in sight).
const GROUP: String = "fog_of_war"

func _ready() -> void:
	add_to_group(GROUP)

func setup(field_half: float) -> void:
	var cfg = _cfg()
	cell = maxf(0.25, float(cfg.get("cell", 1.0)))
	half = field_half + float(cfg.get("margin", 10.0))
	cells = int(ceil(half * 2.0 / cell))
	_seen.resize(cells * cells)
	_seen.fill(0)
	_now.resize(cells * cells)
	_now.fill(0)
	_shade.resize(cells * cells)
	_shade.fill(float(cfg.get("unseen", 1.0)))
	_bytes.resize(cells * cells)
	_bytes.fill(255)
	_image = Image.create_from_data(cells, cells, false, Image.FORMAT_R8, _bytes)
	_texture = ImageTexture.create_from_image(_image)
	if shroud == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		_material = ShaderMaterial.new()
		_material.shader = load("res://assets/shaders/fog_of_war.gdshader")
		# Last of everything see-through, so nothing is drawn over it.
		_material.render_priority = Material.RENDER_PRIORITY_MAX
		quad.material = _material
		shroud = MeshInstance3D.new()
		shroud.name = "Shroud"
		shroud.mesh = quad
		shroud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader puts it on the screen wherever the node is: never culled for being off it.
		shroud.extra_cull_margin = 16384.0
		add_child(shroud)
	_material.set_shader_parameter("shroud", _texture)
	_material.set_shader_parameter("origin", Vector2(global_position.x, global_position.z) if is_inside_tree() else Vector2.ZERO)
	_material.set_shader_parameter("half_size", half)
	var mist: Dictionary = cfg.get("mist", {})
	_material.set_shader_parameter("seen_level", float(cfg.get("seen", 0.55)))
	for key in ["veil", "never", "wisps", "wisp_scale", "wisp_drift", "blur", "round_about", "brightest", "ground"]:
		if mist.has(key):
			_material.set_shader_parameter(key, mist[key])
	_material.set_shader_parameter("drift", _wisps())
	_played = 0.0
	_explained = false
	_look()
	_paint(1.0)
	_match_the_haze()

## The mist's own shapes: the engine's noise, tiling, soft (Config.FOG.mist.wisp_scale sizes them).
static func _wisps() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex

## The mist in the valley's haze at this hour: the environment's fog colour, which the day turns
## (SceneEnvironment) -- pale by day, warm at dusk, dark blue at night -- as a hue alone, greyed
## towards white (Config.FOG.mist.saturation: the dusk haze as it is made a red desert of the valley).
## How bright it is is the land's under it (the shader), lifted by the hour (Config.DAY.light "mist":
## paler than the land by day, darker than it at dusk and at night -- mist_lift).
func _match_the_haze() -> void:
	if _material == null or not is_inside_tree() or get_world_3d() == null:
		return
	var env: Environment = get_world_3d().environment
	if env == null:
		for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			env = (we as WorldEnvironment).environment
			break
	if env == null:
		return
	_material.set_shader_parameter("mist_hue", mist_hue(env.fog_light_color, float(_cfg().get("mist", {}).get("saturation", 0.5))))
	_material.set_shader_parameter("lift", mist_lift())

## The haze's colour `haze` (as the environment holds it) as the mist's hue: in linear light, `saturation`
## of its own colour kept and the rest white, and as bright as white -- the land under the mist says
## how bright it is.
static func mist_hue(haze: Color, saturation: float) -> Vector3:
	var lin: Color = haze.srgb_to_linear()
	var y: float = maxf(0.0001, 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b)
	var hue: Vector3 = Vector3(lin.r, lin.g, lin.b) / y
	return Vector3.ONE.lerp(hue, clampf(saturation, 0.0, 1.0))

## How much brighter than the land under it the mist is now (Config.DAY.light "mist", at the hour).
func mist_lift() -> float:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if cfg == null or not ("DAY" in cfg) or gs == null or not gs.has_method("time_of_day"):
		return 1.0
	var now: Dictionary = SceneEnvironment.light_at(cfg.DAY.get("light", []), float(cfg.DAY.get("length", 360.0)),
		float(gs.time_of_day()))
	return float(now.get("mist", 1.0))

## What the mist is, said once a moment into the run (Config.FOG.hint_after): mist that is the
## unknown, not the weather (v0.6 round four: "只要玩家能感觉出来这个雾是迷雾不是天气就行").
func _explain(delta: float) -> void:
	if _explained or revealed:
		return
	_played += delta
	if _played < float(_cfg().get("hint_after", 4.0)):
		return
	_explained = true
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("fog_explained"):
		eb.fog_explained.emit()

func _cfg() -> Dictionary:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else Engine.get_main_loop().root.get_node_or_null("Config")
	return cfg.FOG if (cfg and "FOG" in cfg) else {}

func _process(delta: float) -> void:
	if cells <= 0 or _seen.is_empty():
		return
	_explain(delta)
	_clock -= delta
	if _clock > 0.0:
		return
	var every: float = float(_cfg().get("every", 0.1))
	_clock = every
	_look()
	_paint(every)
	_hide_the_unseen()
	_match_the_haze()

# ==============================================================================
# What is seen
# ==============================================================================

## The cell `pos` is in, as its index, or -1 off the field and its margin.
func _index(pos: Vector3) -> int:
	var local: Vector3 = pos - global_position
	var x: int = int(floor((local.x + half) / cell))
	var z: int = int(floor((local.z + half) / cell))
	if x < 0 or z < 0 or x >= cells or z >= cells:
		return -1
	return z * cells + x

## Whether `pos` has been seen, ever.
func is_seen(pos: Vector3) -> bool:
	if revealed:
		return true
	var i: int = _index(pos)
	return i >= 0 and _seen[i] != 0

## Whether `pos` is in sight now.
func is_in_sight(pos: Vector3) -> bool:
	if revealed:
		return true
	var i: int = _index(pos)
	return i >= 0 and _now[i] != 0

## Whether anything of his -- the Hero, the cabin, a finished building -- sees `pos` now, the fog lifted
## or not: what appears there appears in front of him (WaveManager: nothing steps out where he can
## see it; Dino: hurrying in from the edge).
func sees(pos: Vector3) -> bool:
	var i: int = _index(pos)
	return i >= 0 and _now[i] != 0

## Everything seen, for good: a view that has to show the whole field. What is in sight is still
## only what he and his buildings see -- lifting the fog finds nothing (_hide_the_unseen).
func reveal_all() -> void:
	revealed = true
	_seen.fill(1)
	_paint(1.0)
	_hide_the_unseen()

## What is in sight now, and so seen: a circle round everything that sees (_sources) -- worked out
## with the fog lifted too, for what asks what he sees (sees).
func _look() -> void:
	_now.fill(0)
	for src in _sources():
		_see_round(src[0], float(src[1]))

func _see_round(at: Vector3, radius: float) -> void:
	if radius <= 0.0:
		return
	var local: Vector3 = at - global_position
	var cx: float = (local.x + half) / cell
	var cz: float = (local.z + half) / cell
	var r: float = radius / cell
	var x0: int = maxi(0, int(floor(cx - r)))
	var x1: int = mini(cells - 1, int(ceil(cx + r)))
	var z0: int = maxi(0, int(floor(cz - r)))
	var z1: int = mini(cells - 1, int(ceil(cz + r)))
	var r2: float = r * r
	for z in range(z0, z1 + 1):
		var dz: float = float(z) + 0.5 - cz
		for x in range(x0, x1 + 1):
			var dx: float = float(x) + 0.5 - cx
			if dx * dx + dz * dz <= r2:
				var i: int = z * cells + x
				_now[i] = 1
				_seen[i] = 1

## What sees, and how far (Config.FOG.sight): the Hero; the cabin; each finished building, by its
## kind -- all less far at dusk and at night (Config.FOG.dusk, night) -- and whatever a light reaches:
## a fire burning, the torch in his hand (GAME-DESIGN 9.3: "看得见的范围缩小，火把它撑开"). A light is its
## own, so the night does not shorten it.
func _sources() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var cfg = get_node_or_null("/root/Config")
	var fog: Dictionary = _cfg()
	var sight: Dictionary = fog.get("sight", {})
	var scale: float = 1.0
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("day_part"):
		scale = float(fog.get(String(gs.day_part()), 1.0))
	var hero = get_tree().get_first_node_in_group("hero")
	if hero is Node3D and is_instance_valid(hero):
		var torch: float = float(hero.torch_light()) if hero.has_method("torch_light") else 0.0
		out.append([(hero as Node3D).global_position, maxf(float(sight.get("hero", 10.0)) * scale, torch)])
	for core in get_tree().get_nodes_in_group("core"):
		if core is Node3D and is_instance_valid(core):
			out.append([(core as Node3D).global_position, float(sight.get("core", 9.0)) * scale])
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Node3D) or not is_instance_valid(b) or b.is_in_group("core"):
			continue
		if ("is_constructed" in b and not b.is_constructed) or ("is_destroyed" in b and b.is_destroyed):
			continue
		var kind: String = String(cfg.get_building_kind(String(b.building_type))) if (cfg and "building_type" in b) else ""
		var radius: float = float(sight.get(kind, sight.get("building", 3.0))) * scale
		if b.has_method("light_radius"):
			radius = maxf(radius, float(b.light_radius()))
		out.append([(b as Node3D).global_position, radius])
	return out

# ==============================================================================
# How it is drawn
# ==============================================================================

## The shroud's texture from what is seen: dark where never seen, dim where seen but out of sight,
## clear in sight -- each cell eased towards that over Config.FOG.ease seconds, so the fog's edge
## moves rather than jumps; and the margin round the field fading out to its edge, into the
## valley's walls.
func _paint(dt: float) -> void:
	if _image == null:
		return
	var fog: Dictionary = _cfg()
	var unseen: float = float(fog.get("unseen", 1.0))
	var dim: float = float(fog.get("seen", 0.55))
	var step: float = clampf(dt / maxf(0.01, float(fog.get("ease", 0.4))), 0.0, 1.0)
	var changed: bool = false
	for i in cells * cells:
		var want: float = 0.0 if (revealed or _now[i] != 0) else (dim if _seen[i] != 0 else unseen)
		_shade[i] += (want - _shade[i]) * step
		var dark: int = int(round(clampf(_shade[i], 0.0, 1.0) * 255.0))
		if _bytes[i] != dark:
			changed = true
			_bytes[i] = dark
	if shroud != null:
		shroud.visible = not revealed
	# Nothing to send when nothing moved: he stood still and the fog had settled.
	if not changed:
		return
	_image.set_data(cells, cells, false, Image.FORMAT_R8, _bytes)
	_texture.update(_image)

## How dark `pos` is drawn now, 0 clear to 1 black: what a test can ask of the shroud. Past its
## square nothing is ever seen.
func shade_at(pos: Vector3) -> float:
	if revealed:
		return 0.0
	var i: int = _index(pos)
	return _shade[i] if i >= 0 else float(_cfg().get("unseen", 1.0))

# ==============================================================================
# What is hidden
# ==============================================================================

## The animals out of sight, hidden; the nest, until it has been seen -- and the first time it is
## in sight, found.
func _hide_the_unseen() -> void:
	if not is_inside_tree():
		return
	for d in get_tree().get_nodes_in_group("dinos"):
		if d is Node3D and is_instance_valid(d):
			(d as Node3D).visible = is_in_sight((d as Node3D).global_position)
	# What stands on never-seen ground is not drawn at all: through the mist its shape showed -- a
	# tree, a rock, a pile -- lighter than the ground round it. Seen once, it is there for good, as
	# the land is. The herds on the valley's walls are never seen.
	for group in ["resource_nodes", "drops"]:
		for thing in get_tree().get_nodes_in_group(group):
			if thing is Node3D and is_instance_valid(thing):
				(thing as Node3D).visible = is_seen((thing as Node3D).global_position)
	var herds: Node = get_parent().get_node_or_null("Herds") if get_parent() != null else null
	if herds != null:
		for animal in herds.get_children():
			if animal is Node3D:
				(animal as Node3D).visible = is_seen((animal as Node3D).global_position)
	for nest in get_tree().get_nodes_in_group("nest"):
		if not (nest is Node3D) or not is_instance_valid(nest):
			continue
		(nest as Node3D).visible = is_seen((nest as Node3D).global_position)
		# Found by being seen -- by him or what he built -- not by a view with the fog lifted.
		var i: int = _index((nest as Node3D).global_position)
		if i >= 0 and _now[i] != 0:
			var gs = get_node_or_null("/root/GameState")
			if gs and "nest_found" in gs and not bool(gs.nest_found):
				gs.nest_found = true
				var eb = get_node_or_null("/root/EventBus")
				if eb and eb.has_signal("nest_found"):
					eb.nest_found.emit(nest)
