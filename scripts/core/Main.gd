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
var hero_script: GDScript = preload("res://scripts/entities/Hero.gd")

# ==============================================================================
# Node References
# ==============================================================================
@export var camera: Camera3D = null
@export var grid_manager: Node3D = null
@export var build_system: Node = null
@export var wave_manager: Node3D = null
@export var buildings_container: Node3D = null
@export var dinos_container: Node3D = null
@export var guards_container: Node3D = null
@export var nest_holder: Node3D = null
@export var hud: CanvasLayer = null
@export var hero: CharacterBody3D = null
@export var resource_nodes_container: Node3D = null
@export var drops_container: Node3D = null
@export var cabin_interior: Node3D = null

var resource_node_script: GDScript = null
var current_core: Node = null
var current_nest: Node = null
var current_build_type: String = ""

## Stepping into the cabin moves the camera; it never swaps the scene, so the
## world outside keeps running the whole time the player is in there. That is the
## cost that makes going home a decision.
var in_cabin: bool = false
## Set when the player right-clicks the cabin: the Hero walks over, and the moment
## he arrives the view goes inside. Any other order on the way cancels it.
var _pending_cabin_entry: bool = false

# v0.2 build preview: a translucent ghost of the pending building that follows the
# cursor, together with its coverage ring and a highlight on the resource nodes that
# ring would cover.
var build_preview: Node3D = null
var build_preview_mesh: MeshInstance3D = null
var build_preview_ring: MeshInstance3D = null
var _preview_cell: Vector2i = Vector2i(999999, 999999)

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

func _process(delta: float) -> void:
	_handle_camera_pan(delta)
	_check_pending_cabin_entry()

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

	if guards_container == null:
		guards_container = find_child("Guards", true, false) as Node3D
	if guards_container == null:
		guards_container = Node3D.new()
		guards_container.name = "Guards"
		add_child(guards_container)

	if nest_holder == null:
		nest_holder = find_child("NestHolder", true, false) as Node3D
	if nest_holder == null:
		nest_holder = Node3D.new()
		nest_holder.name = "NestHolder"
		add_child(nest_holder)

	if resource_nodes_container == null:
		resource_nodes_container = find_child("ResourceNodes", true, false) as Node3D
	if resource_nodes_container == null:
		resource_nodes_container = Node3D.new()
		resource_nodes_container.name = "ResourceNodes"
		add_child(resource_nodes_container)
	if resource_node_script == null and ResourceLoader.exists("res://scripts/entities/ResourceNode.gd"):
		resource_node_script = load("res://scripts/entities/ResourceNode.gd")

	# The cabin's inside is a scene of its own, parked far below the map. Instanced
	# rather than swapped to, so entering it never unloads the world.
	if cabin_interior == null:
		cabin_interior = find_child("CabinInterior", true, false) as Node3D
	if cabin_interior == null and ResourceLoader.exists("res://scenes/CabinInterior.tscn"):
		cabin_interior = load("res://scenes/CabinInterior.tscn").instantiate() as Node3D
		if cabin_interior != null:
			cabin_interior.name = "CabinInterior"
			add_child(cabin_interior)
	if cabin_interior != null:
		var cfg_cabin = _get_config()
		if cfg_cabin and "CABIN" in cfg_cabin:
			cabin_interior.position = cfg_cabin.CABIN.get("interior_origin", Vector3(0.0, -200.0, 0.0))

	# Drops are kept in their own container so a restart can sweep the ground with
	# one loop, and so nothing on the floor is ever mistaken for a building.
	if drops_container == null:
		drops_container = find_child(DropItem.CONTAINER_NAME, true, false) as Node3D
	if drops_container == null:
		drops_container = Node3D.new()
		drops_container.name = DropItem.CONTAINER_NAME
		add_child(drops_container)
	if not drops_container.is_in_group(DropItem.CONTAINER_GROUP):
		drops_container.add_to_group(DropItem.CONTAINER_GROUP)

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
	var eb = _get_event_bus()
	if eb and eb.has_signal("phase_changed"):
		if not eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: int) -> void:
	if phase != 0:
		cancel_building_selection()

# ==============================================================================
# Entity Setup & Placement
# ==============================================================================

## Sets up initial level entities: CoreCampfire and Dinosaur Nest.
func setup_level() -> void:
	setup_initial_entities()
	spawn_resource_nodes()
	scatter_opening_stock()
	if hero and is_instance_valid(hero):
		hero.continuous_mode = true
	if wave_manager and is_instance_valid(wave_manager):
		wave_manager.auto_raid_enabled = true
	var gs_cont = _get_game_state()
	if gs_cont and "continuous_mode" in gs_cont:
		gs_cont.continuous_mode = true
		if wave_manager.has_method("reset_raid_state"):
			wave_manager.reset_raid_state()

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

		if current_nest.has_method("spawn_guards"):
			current_nest.spawn_guards(guards_container if is_instance_valid(guards_container) else self)

	# 3. Place Hero (Modern Person)
	if hero == null or not is_instance_valid(hero):
		var hero_pos = Vector3(1.0, 0.0, 3.0)
		if current_core != null and is_instance_valid(current_core):
			hero_pos = current_core.global_position + Vector3(0.0, 0.0, 2.0)
		var hero_inst = hero_script.new()
		hero_inst.name = "Hero"
		hero_inst.position = hero_pos
		add_child(hero_inst)
		hero = hero_inst

	# 4. Fire initial Core HP notification
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

func is_resource_at_cell(cell: Vector2i) -> bool:
	if grid_manager and is_instance_valid(grid_manager) and grid_manager.has_method("is_resource_at_cell"):
		if grid_manager.is_resource_at_cell(cell):
			return true
	if resource_nodes_container == null:
		return false
	for child in resource_nodes_container.get_children():
		if is_instance_valid(child) and "cell_pos" in child and child.cell_pos == cell:
			return true
	return false

func get_resource_node_at_cell(cell: Vector2i) -> Node:
	if grid_manager and is_instance_valid(grid_manager) and grid_manager.has_method("get_resource_at"):
		var res_node = grid_manager.get_resource_at(cell)
		if res_node != null:
			return res_node
	if resource_nodes_container == null:
		return null
	for child in resource_nodes_container.get_children():
		if is_instance_valid(child) and "cell_pos" in child and child.cell_pos == cell:
			return child
	return null

func spawn_resource_nodes() -> void:
	if resource_nodes_container == null:
		_ensure_scene_dependencies()
	if resource_nodes_container == null or resource_node_script == null:
		return
	if grid_manager and grid_manager.has_method("clear_resource_cells"):
		grid_manager.clear_resource_cells()
	for child in resource_nodes_container.get_children():
		resource_nodes_container.remove_child(child)
		child.queue_free()

	var nodes_def: Array = []
	var cfg = _get_config()
	if cfg and "MAP" in cfg and cfg.MAP is Dictionary and cfg.MAP.has("default_resource_nodes"):
		nodes_def = cfg.MAP["default_resource_nodes"]
	else:
		nodes_def = [
			{"type": "wood", "cell": Vector2i(-4, -2)},
			{"type": "wood", "cell": Vector2i(4, -2)},
			{"type": "stone", "cell": Vector2i(-4, -6)},
			{"type": "stone", "cell": Vector2i(4, -6)},
			{"type": "water", "cell": Vector2i(-4, -4)}
		]

	var t_size: float = 2.0
	if cfg and "TILE_SIZE" in cfg:
		t_size = float(cfg.TILE_SIZE)

	for item in nodes_def:
		var node = resource_node_script.new(item["type"], item["cell"])
		node.name = "ResourceNode_%s_%d_%d" % [item["type"], item["cell"].x, item["cell"].y]
		var world_pos = grid_manager.cell_to_world(item["cell"]) if grid_manager else Vector3(float(item["cell"].x) * t_size, 0.0, float(item["cell"].y) * t_size)
		node.position = world_pos
		resource_nodes_container.add_child(node)
		if grid_manager and grid_manager.has_method("occupy_resource_cell"):
			grid_manager.occupy_resource_cell(item["cell"], node)

## Lays the opening stock on the ground around the cabin instead of handing it
## over as a number. The first thing the game teaches is that resources are
## carried, and that only works if the very first wood has to be walked to --
## so every pile starts outside the Hero's pickup radius, and a ring keeps them
## evenly spread rather than bunched on one side.
func scatter_opening_stock() -> void:
	if current_core == null or not is_instance_valid(current_core) or not is_inside_tree():
		return
	var cfg = _get_config()
	if cfg == null or not ("DROPS" in cfg):
		return
	var stock: Dictionary = cfg.DROPS.get("opening_stock", {})
	if stock.is_empty():
		return
	var piles: int = maxi(1, int(cfg.DROPS.get("opening_piles", 1)))
	var radius: float = float(cfg.DROPS.get("opening_ring_radius", 4.5))
	var centre: Vector3 = current_core.global_position

	var slots: int = piles * stock.size()
	var slot: int = 0
	for res_id in stock:
		var left: int = int(stock[res_id])
		for i in range(piles):
			var share: int = int(ceil(float(left) / float(piles - i)))
			left -= share
			var angle: float = TAU * (float(slot) / float(slots))
			slot += 1
			if share <= 0:
				continue
			DropItem.spawn(self, centre + Vector3(cos(angle), 0.0, sin(angle)) * radius,
				String(res_id), share)

# ==============================================================================
# The cabin: stepping inside and back out
# ==============================================================================

## True while the given node is the cabin the player can walk into.
func _is_cabin(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("core"):
		return true
	return "building_type" in node and String(node.building_type) == "core"

## Sends the Hero home and remembers why. Right-clicking the cabin is the only way
## in: walk over, and the view goes inside the moment he arrives -- one click, and
## the same "right-click a thing to act on it" rule as everything else.
func order_enter_cabin() -> bool:
	if hero == null or not is_instance_valid(hero) or current_core == null or not is_instance_valid(current_core):
		return false
	_pending_cabin_entry = true
	if _hero_is_at_cabin():
		return enter_cabin()
	hero.move_to(current_core.global_position)
	return true

func _hero_is_at_cabin() -> bool:
	if hero == null or not is_instance_valid(hero) or current_core == null or not is_instance_valid(current_core):
		return false
	var reach: float = 2.5
	var cfg = _get_config()
	if cfg and "CABIN" in cfg:
		reach = float(cfg.CABIN.get("enter_range", reach))
	return hero.global_position.distance_to(current_core.global_position) <= reach

func _check_pending_cabin_entry() -> void:
	if not _pending_cabin_entry or in_cabin:
		return
	if _hero_is_at_cabin():
		enter_cabin()

## Moves the camera inside. Deliberately not a scene change: the raid timer, the
## dinosaurs already on the map and every half-built stake carry on exactly as
## they were, which is what makes the trip home cost something.
func enter_cabin() -> bool:
	_pending_cabin_entry = false
	if in_cabin or cabin_interior == null or not is_instance_valid(cabin_interior):
		return false
	cancel_building_selection()
	in_cabin = true
	if cabin_interior.has_method("set_open"):
		cabin_interior.set_open(true)
	var eb = _get_event_bus()
	if eb and eb.has_signal("unit_deselected"):
		eb.unit_deselected.emit()
	if eb and eb.has_signal("cabin_view_changed"):
		eb.cabin_view_changed.emit(true)
	return true

## Steps back out. Instant on purpose -- the player has to be able to leave the
## moment a raid warning sounds, or being inside stops being a risk and starts
## being a trap.
func leave_cabin() -> bool:
	_pending_cabin_entry = false
	if not in_cabin:
		return false
	in_cabin = false
	if cabin_interior and is_instance_valid(cabin_interior) and cabin_interior.has_method("set_open"):
		cabin_interior.set_open(false)
	if camera and is_instance_valid(camera):
		camera.current = true
	var eb = _get_event_bus()
	if eb and eb.has_signal("unit_deselected"):
		eb.unit_deselected.emit()
	if eb and eb.has_signal("cabin_view_changed"):
		eb.cabin_view_changed.emit(false)
	return true

# ==============================================================================
# Interactive & Programmatic Building Placement
# ==============================================================================

func on_build_selected(type_id: String) -> void:
	current_build_type = type_id
	_rebuild_build_preview(type_id)

func cancel_building_selection() -> void:
	current_build_type = ""
	_clear_build_preview()
	if hud and is_instance_valid(hud) and hud.has_method("deselect_build"):
		hud.deselect_build()

func _can_afford_building(type_id: String) -> bool:
	if type_id.is_empty():
		return false
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs == null or cfg == null:
		return false
	if not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(type_id):
		return false
	var b_data: Dictionary = cfg.BUILDINGS[type_id]
	var cost: Dictionary = b_data.get("cost", {})
	if "infinite_ap" in gs and gs.infinite_ap:
		return gs.can_afford(cost)
	var ap_cost: int = int(b_data.get("ap_cost", 1))
	return gs.can_spend_ap(ap_cost) and gs.can_afford(cost)

func _unhandled_input(event: InputEvent) -> void:
	if camera == null or grid_manager == null or build_system == null:
		return

	var cfg = _get_config()
	var controls: Dictionary = cfg.CONTROLS if (cfg and "CONTROLS" in cfg and cfg.CONTROLS is Dictionary) else {}
	var pause_key: int = int(controls.get("pause_key", KEY_SPACE))
	var cancel_key: int = int(controls.get("cancel_key", KEY_ESCAPE))
	var move_btn: int = int(controls.get("hero_move_button", MOUSE_BUTTON_RIGHT))
	var place_btn: int = int(controls.get("build_place_button", MOUSE_BUTTON_LEFT))

	# F11 to toggle fullscreen
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return

	# Mouse Wheel Zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(1.8)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(-1.8)
			get_viewport().set_input_as_handled()
			return

	# Build preview follows the cursor while a building type is selected
	if event is InputEventMouseMotion and current_build_type != "" and not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_update_build_preview(event.position)

	# Middle mouse drag camera pan
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		if camera:
			var right = camera.global_transform.basis.x
			var cam_fwd = Vector3(camera.global_transform.basis.z.x, 0.0, camera.global_transform.basis.z.z).normalized()
			var speed = 0.015 * (camera.global_position.y / 18.0)
			camera.global_position -= (right * event.relative.x - cam_fwd * event.relative.y) * speed
			get_viewport().set_input_as_handled()
			return

	# Keyboard Zoom (+/- / PageUp/PageDown) & UI Scale (Ctrl +/-)
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed or event.meta_pressed:
			if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
				set_ui_scale(get_ui_scale() + 0.1)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_MINUS:
				set_ui_scale(get_ui_scale() - 0.1)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_0:
				set_ui_scale(1.0)
				get_viewport().set_input_as_handled()
				return
		else:
			if event.keycode == KEY_PAGEUP or event.keycode == KEY_EQUAL:
				zoom_camera(1.8)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_PAGEDOWN or event.keycode == KEY_MINUS:
				zoom_camera(-1.8)
				get_viewport().set_input_as_handled()
				return

	# Space key to toggle pause
	if event is InputEventKey and event.pressed and event.keycode == pause_key:
		var gs = _get_game_state()
		if gs and gs.has_method("toggle_pause"):
			gs.toggle_pause()
			get_viewport().set_input_as_handled()
			return

	# ESC key to cancel current building selection or deselect unit
	# ESC peels off one layer at a time: the build ghost first, then a pinned
	# selection, and only when there is nothing left to cancel does it open the menu.
	if event is InputEventKey and event.pressed and event.keycode == cancel_key:
		get_viewport().set_input_as_handled()
		if hud and is_instance_valid(hud) and hud.has_method("is_pause_menu_open") and hud.is_pause_menu_open():
			hud.toggle_pause_menu()
			return
		# Inside the cabin, Esc is the way out and nothing else. It has to be
		# instant: the player must be able to leave the moment a raid warning
		# sounds, or being inside stops being a risk and becomes a trap.
		if in_cabin:
			leave_cabin()
			return
		if current_build_type != "":
			cancel_building_selection()
			return
		var eb = _get_event_bus()
		var panel = _get_option_panel()
		var showing_other: bool = panel != null and is_instance_valid(panel) 			and "selected_unit" in panel and panel.selected_unit != null and panel.selected_unit != hero
		if showing_other and eb and eb.has_signal("unit_deselected"):
			eb.unit_deselected.emit()
			return
		if hud and is_instance_valid(hud) and hud.has_method("toggle_pause_menu"):
			hud.toggle_pause_menu()
		return

	# Right-click ACTS, and it acts on whatever is SELECTED. The Hero is the only
	# unit that takes orders, so while a building or a tree is selected right-click
	# does nothing at all rather than quietly commanding the Hero instead -- issuing
	# an order to something the player is not looking at is worse than doing nothing.
	# Left-clicking empty ground (or pressing ESC) hands the Hero back.
	#
	# It still never changes what the panel shows; that is left-click's job alone.
	if event is InputEventMouseButton and event.pressed and event.button_index == move_btn:
		# Inside there is nowhere to send anyone: the Hero is standing right here.
		if in_cabin:
			get_viewport().set_input_as_handled()
			return
		if current_build_type != "":
			cancel_building_selection()
			get_viewport().set_input_as_handled()
			return
		if not _selected_unit_takes_orders():
			get_viewport().set_input_as_handled()
			return
		var hit_pos = _raycast_ground(event.position)
		if hit_pos != null and hero != null and is_instance_valid(hero):
			_pending_cabin_entry = false   # a new order replaces the walk home
			var cell = grid_manager.world_to_cell(hit_pos) if grid_manager else Vector2i.ZERO
			var res_node = get_resource_node_at_cell(cell)
			var b = grid_manager.get_building_at(cell) if grid_manager else null
			if res_node != null and is_instance_valid(res_node):
				hero.order_harvest(res_node)
			elif b != null and is_instance_valid(b):
				if _is_cabin(b):
					order_enter_cabin()
				elif "is_constructed" in b and not b.is_constructed:
					hero.order_build(b, true)
				else:
					hero.move_to(hit_pos)
			else:
				var hit_obj = _raycast_object(event.position)
				if hit_obj != null and is_instance_valid(hit_obj):
					if hit_obj.is_in_group("resource_nodes") or ("resource_type" in hit_obj):
						hero.order_harvest(hit_obj)
					elif hit_obj.is_in_group("dinos"):
						hero.order_attack(hit_obj)
					elif hit_obj.is_in_group("buildings") or _is_cabin(hit_obj):
						if _is_cabin(hit_obj):
							order_enter_cabin()
						elif "is_constructed" in hit_obj and not hit_obj.is_constructed:
							hero.order_build(hit_obj, true)
						else:
							hero.move_to(hit_pos)
					else:
						hero.move_to(hit_pos)
				else:
					hero.move_to(hit_pos)
		get_viewport().set_input_as_handled()
		return

	# Left-click (Default build place button / Unit selection)
	if event is InputEventMouseButton and event.pressed and event.button_index == place_btn:
		# Inside, a click picks a bench and nothing else -- there is no ground to
		# build on and no units to inspect.
		if in_cabin:
			var station = _raycast_object(event.position)
			var eb_cabin = _get_event_bus()
			if station != null and is_instance_valid(station) and station.is_in_group("stations"):
				if eb_cabin and eb_cabin.has_signal("unit_selected"):
					eb_cabin.unit_selected.emit(station)
			elif eb_cabin and eb_cabin.has_signal("unit_deselected"):
				eb_cabin.unit_deselected.emit()
			get_viewport().set_input_as_handled()
			return
		if current_build_type == "":
			var hit_obj = _raycast_object(event.position)
			var eb = _get_event_bus()
			if hit_obj != null and is_instance_valid(hit_obj) and (hit_obj.is_in_group("selectable") or hit_obj.is_in_group("hero") or hit_obj.is_in_group("buildings")):
				if eb and eb.has_signal("unit_selected"):
					eb.unit_selected.emit(hit_obj)
			else:
				if eb and eb.has_signal("unit_deselected"):
					eb.unit_deselected.emit()
			get_viewport().set_input_as_handled()
			return

		var hit_pos = _raycast_ground(event.position)
		if hit_pos != null:
			try_place_at_cell(grid_manager.world_to_cell(hit_pos))
		get_viewport().set_input_as_handled()
		return

## Places the currently selected building type at `cell` and keeps the build mode
## alive so the player can lay down a whole row of blueprints in one go, dropping
## it only when the next one is no longer affordable. The Hero picks the blueprints
## up one at a time. Returns the blueprint, or null if the spot was rejected.
func try_place_at_cell(cell: Vector2i) -> Node:
	if current_build_type == "" or build_system == null:
		return null

	if (grid_manager and grid_manager.has_method("is_cell_occupied") and grid_manager.is_cell_occupied(cell)) or is_resource_at_cell(cell):
		_hint("HINT_CELL_OCCUPIED")
		return null

	var placed = build_system.place_building(current_build_type, cell, buildings_container, true)
	if placed != null:
		if hero != null and is_instance_valid(hero):
			hero.order_build(placed, false)
		if not _can_afford_building(current_build_type):
			cancel_building_selection()
		return placed

	# Rejected: the only reason the player can act on is affordability.
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs and cfg and cfg.BUILDINGS.has(current_build_type):
		if not gs.can_afford(cfg.BUILDINGS[current_build_type].get("cost", {})):
			_hint("HINT_NO_RESOURCES")
	return null

func _hint(key: String) -> void:
	if hud and is_instance_valid(hud) and hud.has_method("show_hint"):
		hud.show_hint(tr(key))

## Whether the currently selected unit is one that can be given an order. Only the
## Hero can; everything else is inspected, not commanded. With nothing selected the
## Hero is the default subject, so orders still work.
func _selected_unit_takes_orders() -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	var panel = _get_option_panel()
	if panel == null or not is_instance_valid(panel):
		return true
	var sel = panel.selected_unit if "selected_unit" in panel else null
	if sel == null or not is_instance_valid(sel):
		return true
	return sel == hero

func _get_option_panel() -> Node:
	if hud and is_instance_valid(hud):
		if "option_panel" in hud and hud.option_panel != null and is_instance_valid(hud.option_panel):
			return hud.option_panel
		return hud.find_child("OptionPanel", true, false)
	return null

## Whichever camera the player is actually looking through -- the map's, or the
## cabin's while they are inside. Clicks have to be cast from the same place.
func _active_camera() -> Camera3D:
	if in_cabin and cabin_interior and is_instance_valid(cabin_interior) and "camera" in cabin_interior:
		var cam = cabin_interior.camera
		if cam is Camera3D and is_instance_valid(cam):
			return cam
	return camera

func _raycast_ground(screen_pos: Vector2) -> Variant:
	var cam := _active_camera()
	if cam == null or not is_inside_tree():
		return null
	var space_state = get_world_3d().direct_space_state
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 1000.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 # Layer 1: Ground
	var result = space_state.intersect_ray(query)
	if result and result.has("position"):
		return result["position"]
	return null

func _raycast_object(screen_pos: Vector2) -> Node:
	var cam := _active_camera()
	if cam == null or not is_inside_tree() or get_world_3d() == null:
		return null
	var space_state = get_world_3d().direct_space_state
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 1000.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4 # Layer 1: Ground/Obstacles, Layer 2: Buildings, Layer 4: Units
	var result = space_state.intersect_ray(query)
	if result and result.has("collider"):
		return result["collider"]
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
	cancel_building_selection()
	leave_cabin()

	# 1. Reset GameState (AP, resources, multipliers, wave, phase, game_over flag)
	var gs = _get_game_state()
	if gs:
		gs.reset_game()

	Dino.clear_all_attack_slots()

	# 2. Deactivate and reset WaveManager
	if wave_manager and is_instance_valid(wave_manager):
		wave_manager.is_wave_active = false
		if wave_manager.spawn_timer and is_instance_valid(wave_manager.spawn_timer):
			wave_manager.spawn_timer.stop()
		wave_manager.current_wave = 0
		wave_manager.dinos_alive_count = 0
		wave_manager.dinos_to_spawn = 0
		if wave_manager.has_method("reset_raid_state"):
			wave_manager.reset_raid_state()

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

	# 5b. Clean leftover Hero immediately
	if hero and is_instance_valid(hero):
		if hero.is_inside_tree():
			hero.get_parent().remove_child(hero)
		hero.queue_free()
		hero = null

	# 5c. Clean leftover Guards immediately
	if guards_container and is_instance_valid(guards_container):
		for g in guards_container.get_children():
			guards_container.remove_child(g)
			g.queue_free()

	# 5d. Clean leftover ResourceNodes immediately
	if resource_nodes_container and is_instance_valid(resource_nodes_container):
		for r in resource_nodes_container.get_children():
			resource_nodes_container.remove_child(r)
			r.queue_free()

	# 5e. Sweep the ground: anything still lying about belongs to the old game.
	# By group rather than by container, so a drop that ended up somewhere else
	# still cannot survive into the new one.
	if is_inside_tree():
		for d in get_tree().get_nodes_in_group(DropItem.GROUP):
			if is_instance_valid(d):
				if d.is_inside_tree():
					d.get_parent().remove_child(d)
				d.queue_free()

	# 6. Reset GridManager occupancy
	if grid_manager and is_instance_valid(grid_manager):
		grid_manager.clear_grid()

	# 7. Re-instantiate pristine level entities (Core, Nest, Resources, Hero, Raids)
	current_core = null
	setup_level()

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

# ==============================================================================
# Camera & View Controls (Zoom, Pan, Fullscreen, UI Scale)
# ==============================================================================

func zoom_camera(amount: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var forward = -camera.global_transform.basis.z
	var new_pos = camera.global_position + forward * amount
	# Clamped camera height between 6.0m (close zoom) and 32.0m (tactical overview)
	if new_pos.y >= 6.0 and new_pos.y <= 32.0:
		camera.global_position = new_pos

func toggle_fullscreen() -> void:
	var cur_mode = DisplayServer.window_get_mode()
	if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func get_ui_scale() -> float:
	var win = get_window()
	return win.content_scale_factor if win else 1.0

func set_ui_scale(p_scale: float) -> void:
	var win = get_window()
	if win:
		win.content_scale_factor = clampf(p_scale, 0.75, 2.0)

func _handle_camera_pan(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var pan_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_vec.y += 1.0

	if pan_vec != Vector2.ZERO:
		pan_vec = pan_vec.normalized()
		var right = camera.global_transform.basis.x
		var cam_fwd = Vector3(camera.global_transform.basis.z.x, 0.0, camera.global_transform.basis.z.z).normalized()
		var pan_speed = 18.0 * (camera.global_position.y / 18.0) * delta
		camera.global_position += (right * pan_vec.x + cam_fwd * pan_vec.y) * pan_speed

# ==============================================================================
# Build Preview Ghost (v0.2 follow-up)
# ==============================================================================

## (Re)creates the ghost for `type_id`: a translucent box the size of the building
## plus, when the type has an area of effect, a ring showing what it would cover.
func _rebuild_build_preview(type_id: String) -> void:
	_clear_build_preview()
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(type_id):
		return

	build_preview = Node3D.new()
	build_preview.name = "BuildPreview"
	add_child(build_preview)

	var tile: float = float(cfg.TILE_SIZE) if "TILE_SIZE" in cfg else 2.0
	build_preview_mesh = MeshInstance3D.new()
	build_preview_mesh.name = "PreviewMesh"
	var box := BoxMesh.new()
	box.size = Vector3(tile * 0.8, tile * 0.8, tile * 0.8)
	build_preview_mesh.mesh = box
	build_preview_mesh.position = Vector3(0.0, tile * 0.4, 0.0)
	build_preview_mesh.material_override = _make_preview_material(Color.WHITE)
	build_preview.add_child(build_preview_mesh)

	var r: float = _preview_range_for(type_id)
	if r > 0.0:
		build_preview_ring = MeshInstance3D.new()
		build_preview_ring.name = "PreviewRing"
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 0.05
		build_preview_ring.mesh = cyl
		build_preview_ring.position = Vector3(0.0, 0.06, 0.0)
		build_preview_ring.material_override = _make_preview_material(_preview_ring_color(type_id), 0.16)
		build_preview.add_child(build_preview_ring)

	build_preview.visible = false
	_preview_cell = Vector2i(999999, 999999)

## Area of effect a pending building would have: attack range for towers,
## attack range for turrets, nothing for plain stakes.
func _preview_range_for(type_id: String) -> float:
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(type_id):
		return 0.0
	var b: Dictionary = cfg.BUILDINGS[type_id]
	if b.has("harvest_range"):
		return float(b["harvest_range"])
	if b.has("range"):
		return float(b["range"])
	return 0.0

func _preview_ring_color(type_id: String) -> Color:
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(type_id):
		return Color(0.4, 0.8, 0.4)
	var b: Dictionary = cfg.BUILDINGS[type_id]
	if b.has("produces_per_sec") and "RESOURCE_NODES" in cfg:
		for res_id in b["produces_per_sec"]:
			if cfg.RESOURCE_NODES.has(res_id):
				return cfg.RESOURCE_NODES[res_id].get("color", Color(0.4, 0.8, 0.4))
	if b.has("range"):
		return Color(0.35, 0.65, 1.0)
	return Color(0.4, 0.8, 0.4)

func _make_preview_material(col: Color, alpha: float = 0.38) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	return mat

## Snaps the ghost to the hovered cell and recolours it by whether placement
## would actually succeed there.
func _update_build_preview(screen_pos: Vector2) -> void:
	if build_preview == null or not is_instance_valid(build_preview):
		_rebuild_build_preview(current_build_type)
		if build_preview == null:
			return

	var hit = _raycast_ground(screen_pos)
	if hit == null:
		build_preview.visible = false
		return

	var cell: Vector2i = grid_manager.world_to_cell(hit)
	build_preview.visible = true
	if cell == _preview_cell:
		return
	_preview_cell = cell
	build_preview.global_position = grid_manager.cell_to_world(cell)

	var ok: bool = _can_afford_building(current_build_type)
	if ok and build_system and build_system.has_method("can_place_building"):
		ok = bool(build_system.can_place_building(current_build_type, cell))
	elif ok and grid_manager and grid_manager.has_method("is_cell_occupied"):
		ok = not grid_manager.is_cell_occupied(cell)

	var tint: Color = Color(0.35, 1.0, 0.4) if ok else Color(1.0, 0.3, 0.25)
	if build_preview_mesh:
		build_preview_mesh.material_override = _make_preview_material(tint)




func _clear_build_preview() -> void:
	if build_preview and is_instance_valid(build_preview):
		build_preview.queue_free()
	build_preview = null
	build_preview_mesh = null
	build_preview_ring = null
	_preview_cell = Vector2i(999999, 999999)
