# res://scripts/entities/CabinInterior.gd
class_name CabinInterior
extends Node3D

## The inside of the cabin: a small room with a bench in it, and the one place the
## Hero gains anything.
##
## It is a scene of its own so the art for it can be made without touching game
## code, but it is **not a scene swap**. It is instanced into the level and parked
## far below the map, and stepping inside only moves the camera. Swapping scenes
## would unload the world -- dinosaurs, raid timers, half-built stakes -- and then
## walking home would cost nothing, which is the opposite of the point: the whole
## reason the cabin is worth defending is that time passes while you are in it.
##
## While the player is inside:
##   * the world keeps running, raid warnings included;
##   * the Hero is here, so he is not out there holding anything;
##   * work only advances while he is at the bench, and Esc puts him outside at once.

signal station_selected(station: Node)

const CAMERA_NAME: String = "CabinCamera"

var camera: Camera3D = null
var stations: Array[Node] = []
var is_open: bool = false

func _ready() -> void:
	add_to_group("cabin_interior")
	_ensure_room()
	_ensure_stations()
	set_process(true)

## Work only happens while somebody is standing in here. Walking out leaves the
## bench exactly as far along as it was -- the same deal an unfinished building
## gets -- but nothing progresses in an empty room.
func _process(delta: float) -> void:
	if not is_open:
		return
	var gs := _get_game_state()
	if gs and ("is_paused" in gs and gs.is_paused or "is_game_over" in gs and gs.is_game_over):
		return
	for st in stations:
		if is_instance_valid(st) and st.has_method("work"):
			st.work(delta)

func set_open(open: bool) -> void:
	is_open = open
	if camera and is_instance_valid(camera):
		camera.current = open

func station(station_id: String) -> Node:
	for st in stations:
		if is_instance_valid(st) and "station_id" in st and String(st.station_id) == station_id:
			return st
	return null

## Seconds of work left on every bench, so a caller can ask "is anything cooking"
## without reaching into the stations.
func busy_stations() -> Array[Node]:
	var out: Array[Node] = []
	for st in stations:
		if is_instance_valid(st) and "active_recipe" in st and String(st.active_recipe) != "":
			out.append(st)
	return out

# ==============================================================================
# The room
# ==============================================================================

func _ensure_room() -> void:
	# Placeholder geometry: a floor and three walls, so the camera has something to
	# look at and the benches read as being *inside* something. v0.5 replaces this
	# wholesale with the real cabin -- the code never names a shape, only the scene.
	if find_child("Room", false, false) == null:
		var room := Node3D.new()
		room.name = "Room"
		add_child(room)
		room.add_child(_slab(Vector3(9.0, 0.2, 7.0), Vector3(0.0, -0.1, 0.0), Color(0.34, 0.29, 0.25)))
		room.add_child(_slab(Vector3(9.0, 3.0, 0.2), Vector3(0.0, 1.5, -3.5), Color(0.42, 0.37, 0.33)))
		room.add_child(_slab(Vector3(0.2, 3.0, 7.0), Vector3(-4.5, 1.5, 0.0), Color(0.38, 0.33, 0.30)))
		room.add_child(_slab(Vector3(0.2, 3.0, 7.0), Vector3(4.5, 1.5, 0.0), Color(0.38, 0.33, 0.30)))

	if camera == null:
		camera = find_child(CAMERA_NAME, false, false) as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = CAMERA_NAME
		# Close and low: this is the one place in the game that is not seen from
		# halfway up the sky.
		camera.position = Vector3(0.0, 3.2, 6.2)
		camera.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
		camera.current = false
		add_child(camera)
	camera.environment = _interior_environment()

	if find_child("CabinLight", false, false) == null:
		var lamp := OmniLight3D.new()
		lamp.name = "CabinLight"
		lamp.position = Vector3(0.0, 2.6, 0.5)
		lamp.omni_range = 14.0
		lamp.light_energy = 1.4
		lamp.light_color = Color(1.0, 0.92, 0.78)
		add_child(lamp)

## The room's own environment, used only while this camera is the one rendering.
##
## Without it the interior borrows the level's sky and fog, and since the room has no
## ceiling the camera sees daylight over the top of the wall. A flat dark background
## puts the room back indoors, and the lamp is left to do the lighting it was always
## meant to do.
func _interior_environment() -> Environment:
	var cfg = _get_config()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.26, 0.24)
	env.ambient_light_energy = 0.45
	env.fog_enabled = false
	if cfg and "CABIN" in cfg:
		env.background_color = cfg.CABIN.get("interior_background", env.background_color)
		env.ambient_light_color = cfg.CABIN.get("interior_ambient", env.ambient_light_color)
		env.ambient_light_energy = float(cfg.CABIN.get("interior_ambient_energy", env.ambient_light_energy))
	# The tonemapper has to match the one outside, or stepping in and out would change
	# how every colour in the game is rendered.
	if cfg and "ENVIRONMENT" in cfg:
		env.tonemap_mode = int(cfg.ENVIRONMENT.get("tonemap_mode", Environment.TONE_MAPPER_AGX))
		env.tonemap_exposure = float(cfg.ENVIRONMENT.get("tonemap_exposure", 1.0))
		env.tonemap_white = float(cfg.ENVIRONMENT.get("tonemap_white", 1.0))
	return env

func _slab(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mi.material_override = mat
	return mi

## One node per station in Config.STATIONS, laid out along the back wall. Adding a
## station is an entry in Config and nothing else.
func _ensure_stations() -> void:
	stations.clear()
	var ids: Array = _station_ids()
	var spacing: float = 2.6
	var start_x: float = -spacing * (ids.size() - 1) * 0.5
	var script = load("res://scripts/entities/CraftingStation.gd")
	for i in range(ids.size()):
		var id: String = String(ids[i])
		var existing = find_child("Station_%s" % id, false, false)
		if existing == null and script != null:
			existing = script.new(id)
			existing.name = "Station_%s" % id
			existing.position = Vector3(start_x + spacing * i, 0.0, -1.6)
			add_child(existing)
		if existing != null:
			stations.append(existing)

func _station_ids() -> Array:
	var cfg := _get_config()
	if cfg and "STATIONS" in cfg:
		return cfg.STATIONS
	return ["workbench", "kitchen"]

# ==============================================================================
# Resolvers
# ==============================================================================

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
