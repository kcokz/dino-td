# res://scripts/ui/MiniMap.gd
class_name MiniMap
extends Control

## THE HAND-DRAWN MAP (GAME-DESIGN 9.3; v0.6 round five, the player: "小地图没有还是会有点confusing，我们需要设计怎么能获得
## 小地图" -- chosen "在工作台做一张地图"). Not there at the start: he draws it on a hide at the workbench
## (Config.RECIPES.hide_map), and from then it is at the top left for good (HUD). It shows only what he has seen of the
## valley (FogOfWar) -- the ground inked in, the hills darker, the river -- and on it what he has built, the cabin,
## him, the wrecks still smoking (their smoke is seen from anywhere) and, once found, the nest. A click on it
## takes the view there (Main.look_at_ground).

## A click on it: the view to look at `at` on the ground.
signal look_requested(at: Vector3)

## What the ground under each fog cell is -- it does not change in a run.
enum Ground { LAND, HILL, WATER }

var _image: Image = null
var _texture: ImageTexture = null
var _clock: float = 0.0
## The fog it was drawn from, what of it had been seen then, and the ground under its cells.
var _fog_id: int = 0
var _drawn_seen: PackedByteArray = PackedByteArray()
var _ground: PackedByteArray = PackedByteArray()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2.ONE * _number("size", 176.0)

func _cfg() -> Dictionary:
	var cfg = get_node_or_null("/root/Config")
	return cfg.MINIMAP if (cfg and "MINIMAP" in cfg) else {}

func _number(key: String, fallback: float) -> float:
	return float(_cfg().get(key, fallback))

func _colour(key: String, fallback: Color) -> Color:
	return _cfg().get(key, fallback)

## The unlock its recipe grants (Config.RECIPES.hide_map): made, it is shown.
const MADE: String = "hide_map"

func _process(delta: float) -> void:
	# Shown while it is made, and only then -- asked every frame, not told: a new run's level can be built
	# before the run's unlocks are cleared, and a map shown on the old run's word stayed up with none made
	# (the debug-agent's BUG-027).
	var gs = get_node_or_null("/root/GameState")
	var made: bool = gs != null and gs.has_method("has_unlock") and bool(gs.has_unlock(MADE))
	if made != visible:
		visible = made
		if made:
			_clock = 0.0
	if not visible:
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = _number("refresh_seconds", 0.5)
		redraw_ground()
	queue_redraw()

## The level's fog of war, found afresh: a new run lays its own.
func _fog() -> FogOfWar:
	return get_tree().get_first_node_in_group(FogOfWar.GROUP) as FogOfWar if is_inside_tree() else null

## A new run: the ground is worked out again on its next drawing.
func forget() -> void:
	_fog_id = 0
	_drawn_seen = PackedByteArray()

# ==============================================================================
# The ground as he has seen it
# ==============================================================================

## The ground inked in cell by cell from the fog: unseen, the bare hide; seen, the land, the hills darker, the
## river. Only when more has been seen since.
func redraw_ground() -> void:
	var fog: FogOfWar = _fog()
	if fog == null or fog.cells <= 0:
		return
	var n: int = fog.cells
	var seen: PackedByteArray = fog.seen_cells()
	if fog.get_instance_id() != _fog_id or _image == null or _image.get_width() != n or _ground.size() != n * n:
		_fog_id = fog.get_instance_id()
		_image = Image.create(n, n, false, Image.FORMAT_RGBA8)
		_ground = _ground_under(fog)
		_drawn_seen = PackedByteArray()
	elif seen == _drawn_seen:
		return
	var inks: Array[Color] = [_colour("land", Color(0.60, 0.50, 0.34)), _colour("hill", Color(0.40, 0.31, 0.20)),
		_colour("water", Color(0.42, 0.52, 0.55))]
	var hide: Color = _colour("hide", Color(0.80, 0.68, 0.50))
	for i in n * n:
		_image.set_pixel(i % n, i / n, inks[_ground[i]] if (i < seen.size() and seen[i] != 0) else hide)
	_drawn_seen = seen.duplicate()
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)

## What the ground is under each of `fog`'s cells: hillside (GridManager), the river (TerrainBuilder), or land.
func _ground_under(fog: FogOfWar) -> PackedByteArray:
	var n: int = fog.cells
	var out := PackedByteArray()
	out.resize(n * n)
	var grid: Node = get_tree().get_first_node_in_group("grid_manager")
	var cfg = get_node_or_null("/root/Config")
	var river: River = TerrainBuilder.river_of(cfg.terrain()) if (cfg and cfg.has_method("terrain")) else null
	for z in n:
		for x in n:
			var at: Vector3 = cell_world(fog, x, z)
			if river != null and river.water_clearance(at.x, at.z) < 0.0:
				out[z * n + x] = Ground.WATER
			elif grid != null and grid.is_cell_blocked(grid.world_to_cell(at)):
				out[z * n + x] = Ground.HILL
	return out

## The middle of `fog`'s cell (x, z), in the world.
static func cell_world(fog: FogOfWar, x: int, z: int) -> Vector3:
	return fog.global_position + Vector3(-fog.half + (float(x) + 0.5) * fog.cell, 0.0, -fog.half + (float(z) + 0.5) * fog.cell)

## Where on the map a world point is drawn.
func to_map(pos: Vector3) -> Vector2:
	var fog: FogOfWar = _fog()
	if fog == null:
		return Vector2.ZERO
	var span: float = fog.half * 2.0
	return Vector2((pos.x - fog.global_position.x + fog.half) / span * size.x,
		(pos.z - fog.global_position.z + fog.half) / span * size.y)

## Where in the world a point on the map is.
func to_world(p: Vector2) -> Vector3:
	var fog: FogOfWar = _fog()
	if fog == null:
		return Vector3.ZERO
	var span: float = fog.half * 2.0
	return Vector3(fog.global_position.x - fog.half + p.x / maxf(1.0, size.x) * span, 0.0,
		fog.global_position.z - fog.half + p.y / maxf(1.0, size.y) * span)

# ==============================================================================
# Drawn
# ==============================================================================

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, _colour("hide", Color(0.80, 0.68, 0.50)))
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
	var ink: Color = _colour("ink", Color(0.16, 0.10, 0.06))
	draw_rect(rect, ink, false, 2.0)
	if not is_inside_tree() or _fog() == null:
		return
	var cfg = get_node_or_null("/root/Config")
	# What he has built, each at its size and as it is turned; the cabin pale.
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Node3D) or not is_instance_valid(b) or b.get("is_destroyed") == true or cfg == null:
			continue
		var half: Vector2 = cfg.get_building_half(String(b.get("building_type")))
		var basis: Basis = (b as Node3D).global_transform.basis
		var centre: Vector3 = (b as Node3D).global_position
		var corners := PackedVector2Array()
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(to_map(centre + basis.x.normalized() * half.x * c.x + basis.z.normalized() * half.y * c.y))
		var cabin: bool = (b as Node).is_in_group("core")
		draw_colored_polygon(corners, _colour("cabin", Color(0.92, 0.92, 0.88)) if cabin else _colour("built", Color(0.20, 0.14, 0.09)))
		if cabin:
			corners.append(corners[0])
			draw_polyline(corners, ink, 1.0)
	# The wrecks still smoking: a smudge and its plume -- where the smoke is up, which is where a wreck is
	# known to lie (Config.WRECKS: found one from another).
	for s in get_tree().get_nodes_in_group(WreckSmoke.GROUP):
		if not is_instance_valid(s) or not (s as WreckSmoke).is_smoking() or (s as WreckSmoke).wreck == null \
				or not is_instance_valid((s as WreckSmoke).wreck):
			continue
		var p: Vector2 = to_map((s as WreckSmoke).wreck.global_position)
		var smoke: Color = _colour("smoke", Color(0.30, 0.28, 0.26))
		draw_circle(p, 3.2, smoke)
		draw_line(p, p + Vector2(3.0, -8.0), smoke, 2.0)
	# The nests, each once found (FogOfWar marks it).
	for nest in get_tree().get_nodes_in_group("nest"):
		if nest is Node3D and is_instance_valid(nest) and bool(nest.get_meta(&"found", false)):
			draw_circle(to_map((nest as Node3D).global_position), 4.0, _colour("nest", Color(0.55, 0.12, 0.08)))
	# Him.
	var hero: Node3D = get_tree().get_first_node_in_group("hero") as Node3D
	if hero != null:
		var h: Vector2 = to_map(hero.global_position)
		draw_circle(h, 3.6, ink)
		draw_circle(h, 2.4, _colour("hero", Color(0.95, 0.35, 0.18)))
	# Where the view is looking: where the camera's line of sight meets the ground.
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		var forward: Vector3 = -cam.global_transform.basis.z
		if forward.y < -0.05:
			var f: Vector2 = to_map(cam.global_position + forward * (cam.global_position.y / -forward.y))
			draw_arc(f, 7.0, 0.0, TAU, 20, Color(ink.r, ink.g, ink.b, 0.6), 1.2)

## A click takes the view there.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		look_at_point((event as InputEventMouseButton).position)
		accept_event()

func look_at_point(p: Vector2) -> void:
	if _fog() != null:
		look_requested.emit(to_world(p))
