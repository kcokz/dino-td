# res://scripts/core/Main.gd
class_name Main
extends Node3D

## Root Scene Coordinator for Defend Dinosaur v0.0.
## Assembles 3D environment, camera, lighting, systems, containers, and HUD.
## Handles interactive building placement and deterministic game restart.

# ==============================================================================
# Script Dependencies
# ==============================================================================
var core_campfire_script: GDScript = preload("res://scripts/entities/CoreCampfire.gd")
var nest_script: GDScript = preload("res://scripts/entities/Nest.gd")
var grid_manager_script: GDScript = preload("res://scripts/core/GridManager.gd")
var build_system_script: GDScript = preload("res://scripts/core/BuildSystem.gd")
var wave_manager_script: GDScript = preload("res://scripts/core/WaveManager.gd")
var hud_script: GDScript = preload("res://scripts/ui/HUD.gd")

# ==============================================================================
# Node References
# ==============================================================================
@export var camera: Camera3D = null
@export var grid_manager: Node3D = null
@export var build_system: Node = null
@export var wave_manager: Node3D = null
@export var buildings_container: Node3D = null
@export var dinos_container: Node3D = null
@export var nest_holder: Node3D = null
@export var hud: CanvasLayer = null

var current_core: Node = null
var current_nest: Node = null
var current_build_type: String = ""

# Canonical coordinates
var core_cell: Vector2i = Vector2i(0, 0)
var nest_cell: Vector2i = Vector2i(0, -9)
var waypoints: Array[Vector3] = []

# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_init_level_coordinates()
	_ensure_scene_dependencies()
	_wire_signals()
	setup_level()

func _init_level_coordinates() -> void:
	var cfg = _get_config()
	if cfg and "MAP" in cfg and cfg.MAP is Dictionary:
		core_cell = cfg.MAP.get("default_core_cell", Vector2i(0, 0))
		nest_cell = cfg.MAP.get("default_nest_cell", Vector2i(0, -9))

func _ensure_scene_dependencies() -> void:
	# 1. Camera3D (fixed 45-degree isometric projection looking at grid center (0, 0, -9))
	if camera == null:
		camera = find_child("Camera3D", true, false) as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(12.0, 18.0, 5.0)
		camera.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
		add_child(camera)

	# 2. Containers
	if buildings_container == null:
		buildings_container = find_child("Buildings", true, false) as Node3D
	if buildings_container == null:
		buildings_container = Node3D.new()
		buildings_container.name = "Buildings"
		add_child(buildings_container)

	if dinos_container == null:
		dinos_container = find_child("Dinos", true, false) as Node3D
	if dinos_container == null:
		dinos_container = Node3D.new()
		dinos_container.name = "Dinos"
		add_child(dinos_container)

	if nest_holder == null:
		nest_holder = find_child("NestHolder", true, false) as Node3D
	if nest_holder == null:
		nest_holder = Node3D.new()
		nest_holder.name = "NestHolder"
		add_child(nest_holder)

	# 3. GridManager
	if grid_manager == null:
		grid_manager = find_child("GridManager", true, false) as Node3D
	if grid_manager == null:
		grid_manager = grid_manager_script.new()
		grid_manager.name = "GridManager"
		add_child(grid_manager)

	# 4. BuildSystem
	if build_system == null:
		build_system = find_child("BuildSystem", true, false)
	if build_system == null:
		build_system = build_system_script.new()
		build_system.name = "BuildSystem"
		add_child(build_system)
	build_system.setup(grid_manager, buildings_container)

	# 5. WaveManager
	if wave_manager == null:
		wave_manager = find_child("WaveManager", true, false) as Node3D
	if wave_manager == null:
		wave_manager = wave_manager_script.new()
		wave_manager.name = "WaveManager"
		add_child(wave_manager)
	wave_manager.dinos_container = dinos_container

	# 6. Discover Path Waypoints
	_discover_waypoints()

	# 7. HUD
	if hud == null:
		hud = find_child("HUD", true, false) as CanvasLayer

func _discover_waypoints() -> void:
	waypoints.clear()
	var path_node = find_child("Path", true, false)
	if path_node:
		for child in path_node.get_children():
			if child is Marker3D:
				waypoints.append(child.global_position)

	if waypoints.is_empty():
		_init_level_coordinates()
		var col_x: int = 0
		var cfg = _get_config()
		if cfg and "MAP" in cfg and cfg.MAP is Dictionary:
			col_x = int(cfg.MAP.get("path_column_x", 0))
		if grid_manager and grid_manager.has_method("cell_to_world"):
			var step: int = 2 if nest_cell.y < core_cell.y else -2
			for cz in range(nest_cell.y, core_cell.y, step):
				waypoints.append(grid_manager.cell_to_world(Vector2i(col_x, cz)))
			waypoints.append(grid_manager.cell_to_world(core_cell))
		else:
			waypoints = [
				Vector3(1.0, 0.0, -17.0),
				Vector3(1.0, 0.0, -13.0),
				Vector3(1.0, 0.0, -9.0),
				Vector3(1.0, 0.0, -5.0),
				Vector3(1.0, 0.0, -1.0),
				Vector3(1.0, 0.0, 1.0)
			]

	if wave_manager:
		wave_manager.waypoints = waypoints.duplicate()
		if not waypoints.is_empty():
			wave_manager.nest_spawn_position = waypoints[0]

func _wire_signals() -> void:
	if hud:
		if not hud.build_requested.is_connected(on_build_selected):
			hud.build_requested.connect(on_build_selected)
		if not hud.restart_requested.is_connected(restart_game):
			hud.restart_requested.connect(restart_game)

# ==============================================================================
# Entity Setup & Placement
# ==============================================================================

## Sets up initial level entities: CoreCampfire and Dinosaur Nest.
func setup_level() -> void:
	setup_initial_entities()

## Provisions initial CoreCampfire and Nest on the map and in GridManager.
func setup_initial_entities() -> void:
	_init_level_coordinates()

	# 1. Place CoreCampfire (Scene Marker -> Config Fallback -> Grid Snapping)
	if current_core == null or not is_instance_valid(current_core):
		var core_pos: Vector3
		var core_marker = find_child("CoreSpawn", true, false)
		if core_marker is Node3D and grid_manager and grid_manager.has_method("world_to_cell") and grid_manager.has_method("cell_to_world"):
			core_cell = grid_manager.world_to_cell(core_marker.global_position)
			core_pos = grid_manager.cell_to_world(core_cell)
		elif grid_manager and grid_manager.has_method("cell_to_world"):
			core_pos = grid_manager.cell_to_world(core_cell)
		else:
			core_pos = Vector3(1.0, 0.0, 1.0)

		var core = core_campfire_script.new()
		core.name = "CoreCampfire"
		core.add_to_group("core")
		core.setup("core", core_cell)
		core.position = core_pos
		buildings_container.add_child(core)

		if grid_manager and grid_manager.has_method("occupy_cell"):
			grid_manager.occupy_cell(core_cell, core)
		current_core = core

	# 2. Place Nest (Scene Marker -> Config Fallback -> Grid Snapping)
	if current_nest == null or not is_instance_valid(current_nest):
		var nest_pos: Vector3
		var nest_marker = find_child("NestSpawn", true, false)
		if nest_marker is Node3D and grid_manager and grid_manager.has_method("world_to_cell") and grid_manager.has_method("cell_to_world"):
			nest_cell = grid_manager.world_to_cell(nest_marker.global_position)
			nest_pos = grid_manager.cell_to_world(nest_cell)
		elif grid_manager and grid_manager.has_method("cell_to_world"):
			nest_pos = grid_manager.cell_to_world(nest_cell)
		else:
			nest_pos = Vector3(1.0, 0.0, -17.0)

		var nest = nest_script.new()
		nest.name = "Nest"
		nest.add_to_group("nest")
		nest.setup(nest_cell)
		nest.position = nest_pos

		var target_nest_parent = nest_holder if is_instance_valid(nest_holder) else self
		target_nest_parent.add_child(nest)

		if grid_manager and grid_manager.has_method("occupy_cell"):
			grid_manager.occupy_cell(nest_cell, nest)
		current_nest = nest

	# 3. Fire initial Core HP notification
	var eb = _get_event_bus()
	if eb and eb.has_signal("core_hp_changed"):
		var core_max_hp: float = 10.0
		if current_core != null and is_instance_valid(current_core) and "max_hp" in current_core:
			core_max_hp = float(current_core.max_hp)
		else:
			var cfg = _get_config()
			if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has("core"):
				core_max_hp = float(cfg.BUILDINGS["core"].get("hp", 10.0))
		var core_cur_hp: float = float(current_core.current_hp) if (current_core != null and is_instance_valid(current_core) and "current_hp" in current_core) else core_max_hp
		eb.core_hp_changed.emit(core_cur_hp, core_max_hp)

# ==============================================================================
# Interactive & Programmatic Building Placement
# ==============================================================================

func on_build_selected(type_id: String) -> void:
	current_build_type = type_id

func _unhandled_input(event: InputEvent) -> void:
	if current_build_type == "" or camera == null or grid_manager == null or build_system == null:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit_pos = _raycast_ground(event.position)
		if hit_pos != null:
			var cell = grid_manager.world_to_cell(hit_pos)
			var placed = build_system.place_building(current_build_type, cell, buildings_container)
			if placed != null:
				current_build_type = ""

func _raycast_ground(screen_pos: Vector2) -> Variant:
	if camera == null or not is_inside_tree():
		return null
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 # Layer 1: Ground
	var result = space_state.intersect_ray(query)
	if result and result.has("position"):
		return result["position"]
	return null

## Direct programmatic placement API for automated tests and scripts.
func build_at_cell(type_id: String, cell: Vector2i) -> bool:
	if build_system:
		var placed = build_system.place_building(type_id, cell, buildings_container)
		return placed != null
	return false

## Helper returning the instantiated building node.
func place_building_at_cell(type_id: String, cell: Vector2i) -> Node:
	if build_system:
		return build_system.place_building(type_id, cell, buildings_container)
	return null

# ==============================================================================
# Game Lifecycle & Restart
# ==============================================================================

## Completely restores pristine starting game state without reloading scene.
func restart_game() -> void:
	current_build_type = ""

	# 1. Reset GameState (AP, resources, multipliers, wave, phase, game_over flag)
	var gs = _get_game_state()
	if gs:
		gs.reset_game()

	# 2. Deactivate and reset WaveManager
	if wave_manager and is_instance_valid(wave_manager):
		wave_manager.is_wave_active = false
		if wave_manager.spawn_timer and is_instance_valid(wave_manager.spawn_timer):
			wave_manager.spawn_timer.stop()
		wave_manager.current_wave = 0
		wave_manager.dinos_alive_count = 0
		wave_manager.dinos_to_spawn = 0

	# 3. Clean leftover Dinos immediately
	if dinos_container and is_instance_valid(dinos_container):
		for dino in dinos_container.get_children():
			dinos_container.remove_child(dino)
			dino.queue_free()

	# 4. Clean leftover Buildings immediately
	if buildings_container and is_instance_valid(buildings_container):
		for b in buildings_container.get_children():
			buildings_container.remove_child(b)
			b.queue_free()

	# 5. Clean leftover Nest immediately
	if nest_holder and is_instance_valid(nest_holder):
		for n in nest_holder.get_children():
			nest_holder.remove_child(n)
			n.queue_free()

	if current_nest and is_instance_valid(current_nest):
		if current_nest.is_inside_tree():
			current_nest.get_parent().remove_child(current_nest)
		current_nest.queue_free()
		current_nest = null

	# 6. Reset GridManager occupancy
	if grid_manager and is_instance_valid(grid_manager):
		grid_manager.clear_grid()

	# 7. Re-instantiate pristine Core and Nest
	current_core = null
	setup_initial_entities()

	# 8. Reset HUD
	if hud and is_instance_valid(hud):
		hud.reset_hud()

# ==============================================================================
# Resolvers
# ==============================================================================

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("EventBus")
	return null

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
