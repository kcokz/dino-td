# res://scripts/fx/FogOfWar.gd
class_name FogOfWar
extends Node3D

## The fog of war (GAME-DESIGN 9.3; v0.6 round three: "游戏要加上战争迷雾，人不能一开始就知道恐龙巢穴"):
## the field in three states -- never seen (dark), seen but out of sight now (the land, dimmed, and
## no animals on it), in sight (everything). What sees is the Hero, the cabin and what he has built
## (Config.FOG.sight), and less far at dusk and in the night. It is drawn by one of the engine's
## decals laid over the field, its texture the fog; animals out of sight are hidden outright, and
## hidden, cannot be pointed at (Main._is_hoverable). The nest is not seen until it is: the first
## time it comes into sight it is found (EventBus.nest_found, GameState.nest_found).

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
var shroud: Decal = null
var _clock: float = 0.0
## Everything seen and in sight, and nothing hidden: for a view that has to show the whole field.
var revealed: bool = false

## Laid over a field `field_half` metres from its middle to its edge (Config.TERRAIN.field_half).
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
	_shade.fill(float(cfg.get("unseen", 0.94)))
	_bytes.resize(cells * cells * 4)
	_bytes.fill(0)
	_image = Image.create_from_data(cells, cells, false, Image.FORMAT_RGBA8, _bytes)
	_texture = null
	if shroud == null:
		shroud = Decal.new()
		shroud.name = "Shroud"
		add_child(shroud)
	var height: float = float(cfg.get("height", 40.0))
	shroud.size = Vector3(half * 2.0, height, half * 2.0)
	shroud.position = Vector3(0.0, height * 0.5 - float(cfg.get("below", 6.0)), 0.0)
	# And the light it would have caught, taken with the colour and under the same shade: no light
	# from the sky in its shadows (occlusion 0) and no shine (roughness 1) -- or never seen was a dark
	# grey the rocks and the river glinted through. The engine lays it on by the colour's alpha, so
	# one picture serves for good (measured: the ground in sight the same to four places with it,
	# without it, and with no shroud).
	var orm: Image = Image.create(cells, cells, false, Image.FORMAT_RGB8)
	orm.fill(Color(0.0, 1.0, 0.0))
	shroud.texture_orm = ImageTexture.create_from_image(orm)
	shroud.albedo_mix = 1.0
	shroud.upper_fade = 0.0
	shroud.lower_fade = 0.0
	shroud.normal_fade = 0.0
	_look()
	_paint(1.0)

func _cfg() -> Dictionary:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else Engine.get_main_loop().root.get_node_or_null("Config")
	return cfg.FOG if (cfg and "FOG" in cfg) else {}

func _process(delta: float) -> void:
	if cells <= 0 or _seen.is_empty():
		return
	_clock -= delta
	if _clock > 0.0:
		return
	var every: float = float(_cfg().get("every", 0.1))
	_clock = every
	_look()
	_paint(every)
	_hide_the_unseen()

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

## Everything seen, for good: a view that has to show the whole field. What is in sight is still
## only what he and his buildings see -- lifting the fog finds nothing (_hide_the_unseen).
func reveal_all() -> void:
	revealed = true
	_seen.fill(1)
	_paint(1.0)
	_hide_the_unseen()

## What is in sight now, and so seen: a circle round everything that sees (_sources).
func _look() -> void:
	if revealed:
		return
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
## kind -- all less far at dusk and at night (Config.FOG.dusk, night).
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
		out.append([(hero as Node3D).global_position, float(sight.get("hero", 10.0)) * scale])
	for core in get_tree().get_nodes_in_group("core"):
		if core is Node3D and is_instance_valid(core):
			out.append([(core as Node3D).global_position, float(sight.get("core", 9.0)) * scale])
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Node3D) or not is_instance_valid(b) or b.is_in_group("core"):
			continue
		if ("is_constructed" in b and not b.is_constructed) or ("is_destroyed" in b and b.is_destroyed):
			continue
		var kind: String = String(cfg.get_building_kind(String(b.building_type))) if (cfg and "building_type" in b) else ""
		var radius: float = float(sight.get(kind, sight.get("building", 3.0)))
		out.append([(b as Node3D).global_position, radius * scale])
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
	var unseen: float = float(fog.get("unseen", 0.94))
	var dim: float = float(fog.get("seen", 0.55))
	var step: float = clampf(dt / maxf(0.01, float(fog.get("ease", 0.4))), 0.0, 1.0)
	var fade: float = float(fog.get("edge_fade", 6.0)) / cell
	var changed: bool = _texture == null
	for z in cells:
		var edge_z: float = minf(float(z) + 0.5, float(cells - z) - 0.5)
		for x in cells:
			var i: int = z * cells + x
			var want: float = 0.0 if (revealed or _now[i] != 0) else (dim if _seen[i] != 0 else unseen)
			_shade[i] += (want - _shade[i]) * step
			var edge: float = minf(edge_z, minf(float(x) + 0.5, float(cells - x) - 0.5))
			var a: float = _shade[i] * clampf(edge / maxf(0.001, fade), 0.0, 1.0)
			var alpha: int = int(clampf(a, 0.0, 1.0) * 255.0)
			if _bytes[i * 4 + 3] != alpha:
				changed = true
				_bytes[i * 4 + 3] = alpha
	# Nothing to draw anew when nothing moved -- he stood still and the fog had settled: each new
	# texture has the engine lay its decals out again.
	if not changed:
		return
	_image.set_data(cells, cells, false, Image.FORMAT_RGBA8, _bytes)
	# A new texture each time, not the old one updated: a decal keeps its textures in an atlas, and
	# took an updated texture's first picture for good -- the fog drew where it was when the run
	# began and never moved (measured: lifted, not a pixel changed).
	_texture = ImageTexture.create_from_image(_image)
	if shroud != null:
		shroud.texture_albedo = _texture

## How dark `pos` is drawn now, 0 clear to 1 black: what a test can ask of the shroud.
func shade_at(pos: Vector3) -> float:
	var i: int = _index(pos)
	return _shade[i] if i >= 0 else 0.0

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
