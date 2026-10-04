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
@export var terrain_container: Node3D = null

var resource_node_script: GDScript = null
var current_core: Node = null
var current_nest: Node = null
## A harder game's other nests (Config.CUSTOM_GAME "difficulty": the map's "nest_cells"), each with its guards.
var extra_nests: Array[Node] = []
var current_build_type: String = ""

## Whether the Hero is in the cabin (CoreCampfire says, over the bus). It never swaps the scene:
## the world outside keeps running the whole time he is in there, which is the cost that makes
## going home a decision.
var in_cabin: bool = false

# v0.2 build preview: a translucent ghost of the pending building that follows the
# cursor, together with its coverage ring and a highlight on the resource nodes that
# ring would cover.
var build_preview: Node3D = null
var build_preview_mesh: MeshInstance3D = null
var build_preview_ring: MeshInstance3D = null
var _preview_cell: Vector2i = Vector2i(999999, 999999)
## Which way the next facing tower or lone section of wall faces (AmmoTower.FACINGS): kept from one to the next,
## so a row of them set along a funnel all face the same way without being turned each time.
var _placement_facing: int = 0
## Built sections of wall dressed, for the moment, as they will stand once what the ghost shows is
## up (_preview_neighbours); refresh_joins puts them back.
var _redressed: Array[Node] = []
## Whether the Hero can get to a build cell to raise what is in hand there (_can_reach_cell),
## asked once per cell for the length of one gesture: a drag asks the whole line again on every
## step of the cursor.
var _reach_asked: Dictionary = {}


# Canonical coordinates
var core_cell: Vector2i = Vector2i(0, 0)
var nest_cell: Vector2i = Vector2i(0, -9)
var waypoints: Array[Vector3] = []

# ==============================================================================
# Lifecycle
# ==============================================================================

## The level pauses with the game (GameState.is_paused, the engine's pause); Main itself goes on --
## the camera, and the player's orders, which wait for the world to move again.
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	child_entered_tree.connect(_pause_with_the_world)

## Every child of the level -- the map, the buildings, the raid, the Hero, a drop, and whatever is
## added to it later -- pauses with the game unless it says otherwise, which only the interface
## does (HUD). So a new kind of unit pauses without a line of its own.
func _pause_with_the_world(child: Node) -> void:
	if child.process_mode == Node.PROCESS_MODE_INHERIT:
		child.process_mode = Node.PROCESS_MODE_PAUSABLE

func _ready() -> void:
	_choose_the_map()
	_init_level_coordinates()
	_ensure_scene_dependencies()
	_wire_signals()
	setup_level()
	_ensure_nav_maps()
	_warm_the_cast()
	_add_bug_report()
	_ensure_station_jump()
	# The game launched opens on the start screen, the valley stopped behind it -- unless it was the start screen
	# that built this level, for the game chosen there (GameState.launch_straight_in).
	var gs_start = _get_game_state()
	if _plays_the_players_map() and gs_start:
		if bool(gs_start.launch_straight_in):
			gs_start.launch_straight_in = false
		elif hud and hud.has_method("show_start_screen"):
			hud.show_start_screen(true)
	# The valley under everything: wind, insects, the river (Config.SOUNDS.ambience).
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("start_ambience"):
		fx.start_ambience()

func _exit_tree() -> void:
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("stop_ambience"):
		fx.stop_ambience()
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_won") and eb.game_won.is_connected(_on_won_jump):
		eb.game_won.disconnect(_on_won_jump)

## The jump between our game's stations (StationJump; GAME-DESIGN 8.3): the beacon charged with a station still ahead
## sends the capsule on, and a level built by the jump opens on its landing.
var station_jump: StationJump = null

func _ensure_station_jump() -> void:
	if station_jump == null or not is_instance_valid(station_jump):
		station_jump = StationJump.new()
		add_child(station_jump)
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_won") and not eb.game_won.is_connected(_on_won_jump):
		eb.game_won.connect(_on_won_jump)
	var gs = _get_game_state()
	if gs and bool(gs.arrived_by_jump) and _plays_the_players_map():
		station_jump.arrive.call_deferred(self)

## Won with a station still to go: the jump, not the victory (HUD._on_game_won leaves it the screen).
func _on_won_jump() -> void:
	var gs = _get_game_state()
	if gs and gs.has_method("has_next_station") and gs.has_next_station() and station_jump != null:
		station_jump.depart(self)

## The navigation meshes, baked from this level's own colliders. See NavMaps.gd.
##
## Main joins the source group rather than the meshes being told about individual nodes:
## a bake then picks up the ground, the hills, the cabin, the traps and every wall as
## they are, with no list to keep in step.
var nav_maps: NavMaps = null
## What the run has been -- each raid's account, and where his time went (v0.6 T8, T9).
var run_stats: RunStats = null
## The night's hunters, up from the river (NightProwl, GAME-DESIGN 9.3).
var night_prowl: NightProwl = null
## What a wreck's din brings when it is searched (Din, GAME-DESIGN 9.3).
var din: Din = null

## The fog of war over the field (FogOfWar, GAME-DESIGN 9.3), laid afresh for each run.
var fog: FogOfWar = null
## Watching every animal for a twitch, and writing each one up (TwitchWatch).
var twitch_watch: TwitchWatch = null

func _ensure_twitch_watch() -> void:
	if twitch_watch == null or not is_instance_valid(twitch_watch):
		twitch_watch = TwitchWatch.new()
		twitch_watch.name = "TwitchWatch"
		add_child(twitch_watch)

func _ensure_fog() -> void:
	if fog == null or not is_instance_valid(fog):
		fog = FogOfWar.new()
		fog.name = "FogOfWar"
		add_child(fog)
	var cfg = _get_config()
	fog.revealed = false
	fog.setup(float(cfg.terrain().get("field_half", 22.0)) if (cfg and "TERRAIN" in cfg) else 22.0)
	# A game without the fog of war (CUSTOM_GAME "fog"): the whole valley in sight from the start.
	var gs_fog = _get_game_state()
	if gs_fog and gs_fog.has_method("rule") and not bool(gs_fog.rule("fog")):
		fog.revealed = true
		if fog.has_method("_paint"):
			fog._paint(1.0)
		if fog.has_method("_hide_the_unseen"):
			fog._hide_the_unseen()

func _ensure_nav_maps() -> void:
	if not is_in_group(NavMaps.SOURCE_GROUP):
		add_to_group(NavMaps.SOURCE_GROUP)
	if nav_maps != null and is_instance_valid(nav_maps):
		return
	nav_maps = NavMaps.new()
	nav_maps.name = "NavMaps"
	add_child(nav_maps)

## Where the view is standing. See scripts/core/CameraRig.gd -- four numbers rather than
## a transform, so that "not closer than 8 metres", "not tilted past 85 degrees" and
## "back to the opening shot" are all things that can actually be said.
var camera_rig: CameraRig = null

func _ensure_camera_rig() -> void:
	if camera_rig != null or camera == null or not is_instance_valid(camera):
		return
	var cfg = _get_config()
	camera_rig = CameraRig.new(cfg)
	# Adopted, not configured: the scene's Camera3D is still what decides where the game
	# opens, and it is what R goes back to.
	camera_rig.adopt(camera)
	# Where the world ends, and how high the ground is -- the valley's own numbers.
	if cfg and "TERRAIN" in cfg:
		var t: Dictionary = cfg.terrain()
		var field_half: float = float(t.get("field_half", 22.0))
		var outer_half: float = float(t.get("outskirts_half", 110.0))
		var margin: float = float(cfg.CAMERA.get("focus_margin", 8.0)) if "CAMERA" in cfg else 8.0
		camera_rig.bounds_half = field_half + margin
		# The ground as drawn, wobble and all: the smooth shape let the camera dip up to two
		# metres into a rise of the valley wall.
		var ground := TerrainBuilder.ground_noise(cfg)
		camera_rig.ground_height = func(x: float, z: float) -> float:
			return TerrainBuilder.ground_height(x, z, field_half, outer_half, t, ground)

func _process(delta: float) -> void:
	_ensure_camera_rig()
	_handle_camera_keys(delta)
	VisualLibrary.take_warmed()

func _init_level_coordinates() -> void:
	var cfg = _get_config()
	var map_layout: Dictionary = _map()
	if not map_layout.is_empty():
		core_cell = map_layout.get("default_core_cell", Vector2i(0, 0))
		nest_cell = map_layout.get("default_nest_cell", Vector2i(0, -9))

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

	if run_stats == null:
		run_stats = RunStats.new()
		run_stats.name = "RunStats"
		add_child(run_stats)

	if night_prowl == null:
		night_prowl = NightProwl.new()
		night_prowl.name = "NightProwl"
		add_child(night_prowl)
	night_prowl.dinos_container = dinos_container
	# What a wreck's din brings (Din): out of the river, the guards woken, a few in from the edge.
	if din == null:
		din = Din.new()
		din.name = "Din"
		add_child(din)
	din.night_prowl = night_prowl
	din.wave_manager = wave_manager
	din.dinos_container = dinos_container

	# 6. Discover Path Waypoints
	_discover_waypoints()

	# 7. HUD
	if hud == null:
		hud = find_child("HUD", true, false) as CanvasLayer

func _discover_waypoints() -> void:
	waypoints.clear()
	var path_node = find_child("Path", true, false)
	# The map's own way from its nest to its cabin (below); the scene's markers are the small
	# valley's, for a level with no map.
	if path_node and _map().is_empty():
		for child in path_node.get_children():
			if child is Marker3D:
				waypoints.append(child.global_position)

	if waypoints.is_empty():
		_init_level_coordinates()
		var col_x: int = 0
		var cfg = _get_config()
		if not _map().is_empty():
			col_x = int(_map().get("path_column_x", 0))
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
		# The map's other ways in, for the beacon's final wave.
		var entries: Array[Vector3] = []
		if grid_manager and grid_manager.has_method("cell_to_world"):
			for cell in _map().get("entries", []):
				entries.append(grid_manager.cell_to_world(cell))
		wave_manager.entry_positions = entries
		# Its edge behind the nest, where a raid's numbers past the nest's party come in.
		var edges: Array[Vector3] = []
		if grid_manager and grid_manager.has_method("cell_to_world"):
			for cell in _map().get("reinforce_from", []):
				edges.append(grid_manager.cell_to_world(cell))
		wave_manager.reinforce_positions = edges
	# The river side of the field, where the night's hunters come up (MAPS.<id>.prowl_from).
	if night_prowl:
		var banks: Array[Vector3] = []
		if grid_manager and grid_manager.has_method("cell_to_world"):
			for cell in _map().get("prowl_from", []):
				banks.append(grid_manager.cell_to_world(cell))
		night_prowl.origins = banks

## The animals this run can field, read ahead on the engine's loading threads (VisualLibrary.warm): its raiders
## from the first day and the later ones, the nest's guards, its bosses, what comes up out of the river at night.
## The first of each species to come out stalled the game a seventh of a second reading its model and skin.
func _warm_the_cast() -> void:
	var map: Dictionary = _map()
	var species: Dictionary = {}
	for id in (map.get("raiders", {}) as Dictionary):
		species[String(id)] = true
	for later in map.get("raiders_by_day", []):
		for id in (later.get("raiders", {}) as Dictionary):
			species[String(id)] = true
	for key in ["guards", "minor_boss", "boss"]:
		if String(map.get(key, "")) != "":
			species[String(map[key])] = true
	for id in (map.get("prowlers", {}) as Dictionary):
		species[String(id)] = true
	var keys: Array = []
	for id in species:
		keys.append("dino/%s" % id)
	VisualLibrary.warm(keys)

## Where the bug report is, by its path: it is in the development build only -- the release export leaves out
## everything under res://scripts/dev/ (export_presets.cfg; tools/build.py) -- so nothing the release ships
## may name it, or the release would not load.
const BUG_REPORT_SCRIPT := "res://scripts/dev/BugReport.gd"

## The bug report -- its key and its button (BugReport, Config.CONTROLS.bug_report_key) -- in a development
## build only: where the build shipped it, and the build is a debug one. A release has no such thing (v0.6
## round seven, the player: "release版本没有这个功能和按钮，这在你的build file或者build script得区分").
func _add_bug_report() -> void:
	if not OS.is_debug_build() or get_node_or_null("BugReport") != null or not ResourceLoader.exists(BUG_REPORT_SCRIPT):
		return
	var report: Node = (load(BUG_REPORT_SCRIPT) as GDScript).new()
	report.set("main", self)
	add_child(report)

func _wire_signals() -> void:
	if hud:
		if not hud.build_requested.is_connected(on_build_selected):
			hud.build_requested.connect(on_build_selected)
		if not hud.restart_requested.is_connected(restart_game):
			hud.restart_requested.connect(restart_game)
		if hud.has_signal("home_view_requested") and not hud.home_view_requested.is_connected(reset_camera):
			hud.home_view_requested.connect(reset_camera)
		# The hand-drawn map clicked (MiniMap): the view goes there.
		if "minimap" in hud and hud.minimap != null and not hud.minimap.look_requested.is_connected(look_at_ground):
			hud.minimap.look_requested.connect(look_at_ground)
	var eb = _get_event_bus()
	if eb and eb.has_signal("phase_changed"):
		if not eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.connect(_on_phase_changed)
	if eb and eb.has_signal("cabin_view_changed") and not eb.cabin_view_changed.is_connected(_on_cabin_view_changed):
		eb.cabin_view_changed.connect(_on_cabin_view_changed)
	if eb and eb.has_signal("wreck_located") and not eb.wreck_located.is_connected(_on_wreck_located):
		eb.wreck_located.connect(_on_wreck_located)
	if eb and eb.has_signal("building_completed") and not eb.building_completed.is_connected(_on_tower_finished):
		eb.building_completed.connect(_on_tower_finished)

## A stage mended has heard where the wreck holding `part` lies (Config.WRECKS): its smoke goes up -- seen
## rising -- and the mist round it becomes seen ground, so the place shows by night too. Nothing for a wreck
## already searched (found by walking onto it).
func _on_wreck_located(part: String) -> void:
	var wreck: Node3D = wreck_of(part)
	if wreck == null or bool(wreck.get("is_depleted")):
		return
	var smoke: Node3D = _smoke_container()
	var smoking: bool = false
	for s in smoke.get_children():
		if s is WreckSmoke and (s as WreckSmoke).wreck == wreck:
			smoking = true
	if not smoking:
		smoke.add_child(WreckSmoke.make(wreck, false))
	var cfg = _get_config()
	if fog != null and is_instance_valid(fog) and cfg and "WRECKS" in cfg:
		fog.mark_seen(wreck.global_position, float(cfg.WRECKS.get("located_seen", 0.0)))

## The wreck that holds `part` on the field, or null.
func wreck_of(part: String) -> Node3D:
	if resource_nodes_container == null:
		return null
	for n in resource_nodes_container.get_children():
		if n is Node3D and String(n.get("resource_type")) == part:
			return n as Node3D
	return null

func _on_phase_changed(phase: int) -> void:
	if phase != 0:
		cancel_building_selection()

# ==============================================================================
# Entity Setup & Placement
# ==============================================================================

## Sets up initial level entities: CoreCampfire and Dinosaur Nest.
func setup_level() -> void:
	spawn_terrain()
	setup_initial_entities()
	spawn_resource_nodes()
	scatter_opening_stock()
	_ensure_fog()
	_ensure_twitch_watch()
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
	#
	# The cabin runs south and east from its tile (_cabin_centre), and takes the cells of the
	# building grid round its middle (Config.BUILDINGS.core.cells).
	var cfg_core = _get_config()
	if current_core == null or not is_instance_valid(current_core):
		var core_pos: Vector3
		var core_marker = find_child("CoreSpawn", true, false)
		if core_marker is Node3D and _map().is_empty() and grid_manager and grid_manager.has_method("world_to_cell") and grid_manager.has_method("cell_to_world"):
			core_cell = grid_manager.world_to_cell(core_marker.global_position)
			core_pos = _cabin_centre(core_cell)
		elif grid_manager and grid_manager.has_method("cell_to_world"):
			core_pos = _cabin_centre(core_cell)
		else:
			core_pos = Vector3(1.0, 0.0, 1.0)

		var core = core_campfire_script.new()
		core.name = "CoreCampfire"
		core.add_to_group("core")
		core.setup("core", core_cell)
		core.position = core_pos
		buildings_container.add_child(core)

		if grid_manager and grid_manager.has_method("occupy_building"):
			grid_manager.occupy_building(core, grid_manager.footprint_cells("core", grid_manager.world_to_build_cell(core_pos)))
			# Its own cell is the one it was placed at.
			core.cell_pos = core_cell
		current_core = core

	# 2. Place Nest (Scene Marker -> Config Fallback -> Grid Snapping)
	if current_nest == null or not is_instance_valid(current_nest):
		var nest_pos: Vector3
		var nest_marker = find_child("NestSpawn", true, false)
		if nest_marker is Node3D and _map().is_empty() and grid_manager and grid_manager.has_method("world_to_cell") and grid_manager.has_method("cell_to_world"):
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

		# Nothing is built on the nest, nor at its mouth: the cells of its tile are its.
		if grid_manager and grid_manager.has_method("occupy_building"):
			grid_manager.occupy_building(nest, grid_manager.build_cells_in_tile(nest_cell))
		current_nest = nest

		if current_nest.has_method("spawn_guards"):
			current_nest.spawn_guards(guards_container if is_instance_valid(guards_container) else self)
	_place_extra_nests()

	# 3. Place Hero (Modern Person), a step south of the cabin, by its door.
	if hero == null or not is_instance_valid(hero):
		var hero_pos = Vector3(1.0, 0.0, 3.0)
		if current_core != null and is_instance_valid(current_core) and current_core.has_method("door_outside"):
			hero_pos = current_core.door_outside()
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

## A harder game's other nests (the run's map: "nests", how many; "nest_cells", where the others are, in the
## order they are opened -- Config.CUSTOM_GAME "difficulty"): each its tile, its guards and its party of every raid
## (WaveManager.nest_positions), found in the fog like the first.
func _place_extra_nests() -> void:
	for n in extra_nests:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.queue_free()
	extra_nests.clear()
	var mouths: Array[Vector3] = []
	if wave_manager and is_instance_valid(wave_manager):
		mouths.append(wave_manager.nest_spawn_position)
	var cells: Array = _map().get("nest_cells", [])
	var more: int = mini(maxi(0, int(_map().get("nests", 1)) - 1), cells.size())
	for i in range(more):
		if grid_manager == null or not grid_manager.has_method("cell_to_world"):
			break
		var cell: Vector2i = cells[i]
		var nest = nest_script.new()
		nest.name = "Nest%d" % (i + 2)
		nest.add_to_group("nest")
		nest.setup(cell)
		nest.position = grid_manager.cell_to_world(cell)
		(nest_holder if is_instance_valid(nest_holder) else self).add_child(nest)
		if grid_manager.has_method("occupy_building"):
			grid_manager.occupy_building(nest, grid_manager.build_cells_in_tile(cell))
		if nest.has_method("spawn_guards"):
			nest.spawn_guards(guards_container if is_instance_valid(guards_container) else self)
		extra_nests.append(nest)
		mouths.append(nest.global_position)
	if wave_manager and is_instance_valid(wave_manager):
		wave_manager.nest_positions = mouths if mouths.size() > 1 else ([] as Array[Vector3])

## The middle of the block of `span` x `span` tiles that runs south and east from `cell`.
## For a one-tile building, the middle of its tile.
## Where the cabin's middle stands for its tile `cell`: its north wall half a cell into the tile --
## where the pod's always was, so a raid coming down from the nest meets the line it always met --
## and its box running south from there, on whole cells of the building grid; its middle as far
## east as the three-metre cabin's was, the module running out either side of it.
func _cabin_centre(cell: Vector2i) -> Vector3:
	var cfg = _get_config()
	var s: float = float(cfg.BUILD_CELL) if cfg and "BUILD_CELL" in cfg else 1.0
	var half: float = float(cfg.get_building_half("core").y) if cfg else 1.5
	var inset: float = s * 0.5 + half
	return grid_manager.cell_to_world_origin(cell) + Vector3(inset, 0.0, inset)

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

## Lays the map's hills: cells nobody walks through and nothing is built on.
##
## Terrain goes down before anything else, because everything after it -- where the
## cabin sits, where the trees are, where a raid can get through -- is placed on
## the assumption that the ground is already what it is.
##
## The blocks are placeholders. v0.5 replaces them with real hills; what matters
## here is that the rule and the shape are the same object, so the thing the player
## sees is exactly the thing that stops them.
func spawn_terrain() -> void:
	var cfg = _get_config()
	if cfg == null or _map().is_empty() or grid_manager == null:
		return
	var cells: Array = _map().get("default_blocked_cells", [])
	if grid_manager.has_method("set_blocked_cells"):
		grid_manager.set_blocked_cells(cells)

	if terrain_container == null:
		terrain_container = find_child("Terrain", true, false) as Node3D
	if terrain_container == null:
		terrain_container = Node3D.new()
		terrain_container.name = "Terrain"
		add_child(terrain_container)
	for child in terrain_container.get_children():
		terrain_container.remove_child(child)
		child.queue_free()

	var tile: float = float(cfg.TILE_SIZE) if "TILE_SIZE" in cfg else 2.0
	var height: float = float(_map().get("hill_height", 2.2))

	# The set, so each hill can ask who its neighbours are. Their shared corners are
	# computed from the same four cells on both sides, which is what makes two hills
	# meet without a crack between them.
	var blocked: Dictionary = {}
	for c in cells:
		if c is Vector2i:
			blocked[c] = true

	_rebuild_ground(cfg)
	_scatter_ground_cover(cfg)
	_raise_volcanoes(cfg)
	_bring_in_the_herds(cfg)
	_lay_the_river(cfg)

	# The mound under the crags is the valley floor rising, so it wears the valley floor:
	# the same material, one instance for every hill, over vertex colours worked out by
	# the ground's own function (TerrainBuilder.build_hill_cell).
	var hill_mat := _ground_material(cfg)

	for c in cells:
		if not (c is Vector2i):
			continue
		var hill := StaticBody3D.new()
		hill.name = "Hill_%d_%d" % [c.x, c.y]
		hill.collision_layer = 1      # world/obstacle, the same layer the ground is on
		hill.collision_mask = 0
		hill.position = grid_manager.cell_to_world(c)

		# The collider stays the cell-sized box it always was, deliberately. The grid is
		# the truth about who can walk where, so collision is built from the declared
		# cell and never measured off the art. The mesh only ever sits INSIDE that box,
		# never outside it -- art that overhung a free cell would stop things at nothing
		# visible, which is the one direction this must not fail in.
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(tile, height, tile)
		shape.shape = box
		shape.position = Vector3(0.0, height * 0.5, 0.0)
		hill.add_child(shape)
		# Solid to the bake too, or the floor inside the box is an island the nearest walkable
		# point to the hill lands on.
		NavMaps.mark_solid(hill, tile * 0.5, height)

		# A LOW SHARED MOUND, with crags standing on it. The mound is the old height
		# field kept at a fraction of its height: neighbouring cells still meet without a
		# crack, so a ridge of blocked cells reads as one continuous rise -- the thing the
		# player sees is still exactly the thing that stops them. On its own, at full
		# height, a single cell came out as a cosine dome peaked in the middle, and every
		# lone hill on the map stood there like a grey tent.
		var rocks: Array = _rock_formations(cfg)
		var base_height: float = height * float(_map().get("hill_base_fraction", 0.12)) if not rocks.is_empty() else height
		var mi := MeshInstance3D.new()
		mi.name = "Mound"
		mi.mesh = TerrainBuilder.build_hill_cell(c, blocked, tile, base_height, cfg, hill.position)
		mi.material_override = hill_mat
		hill.add_child(mi)
		if not rocks.is_empty():
			# Which formation and which way round, from the cell itself: the same hill
			# every launch, and no two neighbours obviously the same stone.
			#
			# Turned a quarter at a time, INSIDE a holder, and then the holder is fitted:
			# the fit measures the stone as turned, so whichever way it faces it stands
			# centred in its cell and inside it. Turned after fitting -- and by any angle --
			# it swung round its own origin rather than its middle, and its corners reached
			# past the cell: rock drawn over ground the grid says is open.
			var pick: int = absi(c.x * 73856093 ^ c.y * 19349663) % rocks.size()
			var holder := Node3D.new()
			holder.name = "Rocks"
			hill.add_child(holder)
			var art: Node3D = (rocks[pick] as PackedScene).instantiate()
			holder.add_child(art)
			art.rotation.y = float(absi(c.x * 31 + c.y * 17) % 4) * PI * 0.5
			VisualLibrary.fit(holder, Vector3(tile * 0.96, height * 0.96, tile * 0.96), "feet")
			var rock_mat := GroundCover.cover_material()
			for m in holder.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = rock_mat

		terrain_container.add_child(hill)

## The volcanoes on the skyline (Config.VOLCANOES, scripts/fx/Volcano.gd).
##
## In their own node for the same reason the ground cover is: terrain_container is the
## hills, which are gameplay, and the tests count them against the blocked cells.
func _raise_volcanoes(cfg) -> void:
	var holder := get_node_or_null("Volcanoes")
	if holder != null:
		remove_child(holder)
		holder.queue_free()
	if cfg == null or not ("VOLCANOES" in cfg):
		return
	holder = Node3D.new()
	holder.name = "Volcanoes"
	add_child(holder)
	for spec in cfg.VOLCANOES.get("cones", []):
		holder.add_child(Volcano.build(spec, cfg))

## The plant-eaters on the valley walls (Config.HERDS, scripts/fx/Herds.gd), in their own
## node like the volcanoes and the ground cover: nothing the level counts as its own.
func _bring_in_the_herds(cfg) -> void:
	var old := get_node_or_null("Herds")
	if old != null:
		remove_child(old)
		old.queue_free()
	if cfg == null or not ("HERDS" in cfg):
		return
	add_child(Herds.build(cfg))

## The river past the field's west edge (Config.TERRAIN.river, scripts/fx/River.gd): the
## water lying in its channel, horsetails along its banks, boulders in its white water,
## and stepping stones down the bank from the water spot. The channel itself is part of
## the ground (TerrainBuilder.ground_height). None of this collides or is on the grid, and
## all of it is in its own node like the herds: nothing the level counts as its own.
func _lay_the_river(cfg) -> void:
	var old := get_node_or_null("River")
	if old != null:
		remove_child(old)
		old.queue_free()
	if cfg == null or not ("TERRAIN" in cfg):
		return
	var river: River = TerrainBuilder.river_of(cfg.terrain())
	if river == null:
		return
	var spec: Dictionary = cfg.terrain()["river"]
	var field_half: float = float(cfg.terrain().get("field_half", 22.0))
	var holder := Node3D.new()
	holder.name = "River"
	add_child(holder)

	var water_spec: Dictionary = spec.get("water", {})
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = river.water_mesh(water_spec, float(cfg.terrain().get("outskirts_half", 110.0)))
	var mat := River.water_material(water_spec)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(water)
	if water.is_inside_tree():
		River.flow_tween(water, mat, water_spec)
	else:
		water.ready.connect(func() -> void: River.flow_tween(water, mat, water_spec), CONNECT_ONE_SHOT)

	var seed_value: int = int(spec.get("seed", 1))
	var n: int = 0
	for path in spec.get("reeds", []):
		var m: Mesh = GroundCover.flora_mesh(String(path))
		if m != null:
			holder.add_child(_multimesh("Reeds_%d" % n, m, GroundCover.flora_material(),
				river.bank_placements(seed_value + 11 + n, int(spec.get("reed_count", 150)),
					float(spec.get("reed_from", -0.35)), float(spec.get("reed_to", 1.8)),
					field_half, Vector2(0.8, 1.3)), true))
		n += 1
	var rock := GroundCover.flora_mesh(String(spec.get("boulders", "")))
	if rock != null:
		holder.add_child(_multimesh("Boulders", rock, GroundCover.cover_material(),
			river.boulder_placements(seed_value + 31, int(spec.get("boulder_count", 30)),
				spec.get("boulder_scale", Vector2(0.35, 0.8))), true))
	# The stepping stones, from each water spot down to the water.
	var stones: Array[Transform3D] = []
	for item in _map().get("default_resource_nodes", []):
		if String(item.get("type", "")) == "water" and grid_manager != null:
			stones.append_array(river.landing_placements(grid_manager.cell_to_world(item["cell"]),
				int(spec.get("landing_stones", 3)), field_half))
	if not stones.is_empty():
		var slab := GroundCover.stone(0.42, seed_value + 51, Color(0.44, 0.42, 0.38))
		holder.add_child(_multimesh("Landing", slab, GroundCover.cover_material(), stones, true))

## One MultiMeshInstance3D of `mesh` at every transform given.
func _multimesh(node_name: String, mesh: Mesh, material: Material, placements: Array[Transform3D], shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = placements.size()
	for i in range(placements.size()):
		mm.set_instance_transform(i, placements[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Turns a water spot to face the river, so its stepping-off stone is on the water side.
func _face_the_river(node: Node3D, at: Vector3) -> void:
	var cfg = _get_config()
	if cfg == null or not ("TERRAIN" in cfg):
		return
	var river: River = TerrainBuilder.river_of(cfg.terrain())
	if river == null:
		return
	var to: Vector2 = river.curve.get_closest_point(Vector2(at.x, at.z)) - Vector2(at.x, at.z)
	if to.length() > 0.01:
		node.rotation.y = atan2(to.x, to.y)

## The crags a hillside cell wears (tools/generate_props.py), or none when the art is
## missing -- in which case the cell keeps the full-height mound it always had.
func _rock_formations(cfg) -> Array:
	var out: Array = []
	for pth in _map().get("hill_rocks", []):
		var packed: PackedScene = VisualLibrary.scene_at(String(pth))
		if packed != null:
			out.append(packed)
	return out

## The ground's surface: vertex colour for the broad strokes, and a triplanar noise
## texture over the top for the grain.
##
## The vertex colours alone left the field a painted surface -- correct hue, no soil.
## Detail texture plus a normal map is what lets the low sun rake across it and makes it
## read as dirt rather than as a colour. Generated rather than authored, so there is no
## image file to keep in step with anything.
func _ground_material(cfg) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE          # the mesh carries its own colour, per vertex
	mat.vertex_color_use_as_albedo = true
	# The colours baked into the mesh are written the way COLORS declares them, which is
	# sRGB. Without this they are taken as linear and every one of them comes out pale --
	# the whole valley washed to grey on the first attempt.
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0        # soil and grass have no gloss at all
	mat.metallic = 0.0

	var t: Dictionary = cfg.terrain() if "TERRAIN" in cfg else {}
	var scale: float = float(t.get("detail_scale", 2.4))
	var strength: float = float(t.get("detail_strength", 0.35))
	var bumpiness: float = float(t.get("detail_bumpiness", 0.85))

	mat.detail_enabled = true
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = _noise_texture(int(t.get("noise_seed", 1)) + 11, 1.0 / maxf(0.2, scale), false, strength)
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1

	mat.normal_enabled = true
	mat.normal_scale = bumpiness
	mat.normal_texture = _noise_texture(int(t.get("noise_seed", 1)) + 29, 1.0 / maxf(0.2, scale), true, 1.0)

	# Triplanar, because the ground mesh has no UVs of its own and the valley walls are
	# steep enough that a flat projection would smear down them. In WORLD space, so a hill
	# wearing this material carries the same grain on across the line where it meets the
	# ground -- in its own space, each hill's grain started over at its centre.
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / maxf(0.2, scale)
	return mat

## A seeded noise texture. `as_normal` asks the engine for a normal map instead of a
## greyscale one; `contrast` pulls a plain albedo texture back towards white so the
## detail multiplies rather than darkens everything it touches.
func _noise_texture(seed_value: int, frequency: float, as_normal: bool, contrast: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency * 0.04
	noise.fractal_octaves = 4

	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = as_normal
	if not as_normal:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 1.0, 1.0).lerp(Color(0.45, 0.42, 0.36), contrast))
		ramp.set_color(1, Color.WHITE)
		tex.color_ramp = ramp
	return tex

## Replaces the flat plane the level ships with by the valley floor and the land around
## it, and widens the ground collider to match the flat part.
##
## The collider only needs to cover ground anything stands on, which is the flat field:
## the rising outskirts are scenery nobody reaches.
func _rebuild_ground(cfg) -> void:
	var ground := find_child("Ground", true, false) as MeshInstance3D
	if ground == null:
		return
	ground.mesh = TerrainBuilder.build_ground(cfg)
	ground.material_override = _ground_material(cfg)
	# The scene still gives the flat plane it ships with a material of its own. The override
	# above is what draws the ground, and the leftover did worse than nothing: the valley's
	# mesh is kept for the next level (TerrainBuilder.build_ground), so it outlives this node,
	# and a node freed while its mesh lives on leaves the renderer holding that material after
	# it has gone -- an engine error every time a level is freed.
	for i in range(ground.get_surface_override_material_count()):
		ground.set_surface_override_material(i, null)

	var field_half: float = 22.0
	if "TERRAIN" in cfg:
		field_half = float(cfg.terrain().get("field_half", field_half))
	for node in ground.find_children("*", "CollisionShape3D", true, false):
		var col := node as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			var ground_box := BoxShape3D.new()
			ground_box.size = Vector3(field_half * 2.0, 0.2, field_half * 2.0)
			col.shape = ground_box

## Grass, ferns, pebbles and the odd fallen log over the flat field.
##
## All of it scenery: no collision, nothing on the grid, and every piece placed from a
## fixed seed so the same meadow comes back every launch and two screenshots can be
## compared. Cells the level has claimed are kept clear, so the cabin and the nest are
## not standing in a bush.
func _scatter_ground_cover(cfg) -> void:
	if cfg == null or not ("GROUND_COVER" in cfg):
		return
	# The map's own over the valley's (MAPS.<id>.ground_cover): station 2's drier, sparser sedge.
	var cover: Dictionary = cfg.GROUND_COVER.duplicate()
	cover.merge(_map().get("ground_cover", {}), true)
	var field_half: float = float(cfg.terrain().get("field_half", 22.0)) if "TERRAIN" in cfg else 22.0

	# Its own node, NOT inside terrain_container. The hills in there are gameplay -- the
	# tests count them against the blocked cells -- and scenery filed among them made
	# "one hill per blocked cell" come out one too many. Cover is not terrain, it is
	# what is lying on it.
	var holder := get_node_or_null("GroundCover")
	if holder != null:
		remove_child(holder)
		holder.queue_free()
	holder = Node3D.new()
	holder.name = "GroundCover"
	add_child(holder)

	# Where not to put anything: the cells the level itself uses.
	var claimed: Array = []
	for c in _map().get("default_blocked_cells", []):
		claimed.append(grid_manager.cell_to_world(c))
	for item in _map().get("default_resource_nodes", []):
		claimed.append(grid_manager.cell_to_world(item["cell"]))
	claimed.append(grid_manager.cell_to_world(_map()["default_core_cell"]))
	claimed.append(grid_manager.cell_to_world(_map()["default_nest_cell"]))

	var mat := GroundCover.cover_material()
	var seed_value: int = int(cover.get("seed", 7723))
	var clear: float = float(cover.get("clear_radius", 2.2))

	var grass := GroundCover.blade_clump(
		float(cover.get("grass_height", 0.42)), float(cover.get("grass_width", 0.05)),
		int(cover.get("grass_blades", 7)),
		cover.get("grass_base", Color(0.2, 0.26, 0.13)), cover.get("grass_tip", Color(0.47, 0.55, 0.26)))
	holder.add_child(GroundCover.scatter(cfg, grass, mat, int(cover.get("grass_count", 5200)),
		field_half, claimed, clear * 0.5, seed_value, Vector2(0.7, 1.5), false))

	var ferns := GroundCover.fern(
		float(cover.get("fern_height", 0.95)), int(cover.get("fern_fronds", 7)),
		cover.get("fern_stem", Color(0.18, 0.25, 0.12)), cover.get("fern_leaf", Color(0.33, 0.47, 0.2)))
	holder.add_child(GroundCover.scatter(cfg, ferns, mat, int(cover.get("fern_count", 420)),
		field_half, claimed, clear, seed_value + 1, Vector2(0.75, 1.35), true))

	var pebbles := GroundCover.stone(float(cover.get("pebble_radius", 0.16)), seed_value + 2,
		cover.get("pebble_color", Color(0.42, 0.40, 0.36)))
	holder.add_child(GroundCover.scatter(cfg, pebbles, mat, int(cover.get("pebble_count", 900)),
		field_half, claimed, clear * 0.4, seed_value + 3, Vector2(0.6, 1.8), false))

	# Fallen trunks: the modelled ones when they are there, the procedural log when not.
	var log_paths: Array = cover.get("log_meshes", [])
	var modelled: Array = []
	for pth in log_paths:
		var lm: Mesh = GroundCover.flora_mesh(String(pth))
		if lm != null:
			modelled.append(lm)
	if modelled.is_empty():
		var logs := GroundCover.fallen_log(
			float(cover.get("log_length", 3.2)), float(cover.get("log_radius", 0.28)),
			cover.get("log_bark", Color(0.27, 0.21, 0.15)), cover.get("log_core", Color(0.47, 0.39, 0.28)))
		holder.add_child(GroundCover.scatter(cfg, logs, mat, int(cover.get("log_count", 14)),
			field_half, claimed, clear * 1.6, seed_value + 4, Vector2(0.8, 1.3), true))
	else:
		var each: int = maxi(1, int(cover.get("log_count", 14)) / modelled.size())
		for i in range(modelled.size()):
			holder.add_child(GroundCover.scatter(cfg, modelled[i], GroundCover.cover_material(), each,
				field_half, claimed, clear * 1.6, seed_value + 4 + i * 7, Vector2(0.85, 1.15), true))

	_scatter_flora(cfg, cover, holder, field_half, claimed, clear, seed_value)

## The Jurassic plants, generated by tools/generate_flora.py: ferns and horsetails on the
## field, tree ferns and cycads at its edge, monkey-puzzles up the valley walls.
##
## Every variant is its own MultiMesh -- one draw per variant however many are planted
## -- and a missing file simply plants nothing, so a checkout without the art still runs.
func _scatter_flora(cfg: Node, cover: Dictionary, holder: Node3D, field_half: float,
		claimed: Array, clear: float, seed_value: int) -> void:
	var low := GroundCover.flora_material()
	var tall := GroundCover.flora_material(float(cover.get("flora_fade_near", 11.0)))
	var n: int = 0
	for path in cover.get("flora_ground_ferns", []):
		var m: Mesh = GroundCover.flora_mesh(String(path))
		if m != null:
			holder.add_child(GroundCover.scatter(cfg, m, low, int(cover.get("flora_ground_fern_count", 200)),
				field_half, claimed, clear * 0.6, seed_value + 20 + n, Vector2(0.7, 1.3), false))
		n += 1
	for path in cover.get("flora_horsetails", []):
		var m: Mesh = GroundCover.flora_mesh(String(path))
		if m != null:
			holder.add_child(GroundCover.scatter(cfg, m, low, int(cover.get("flora_horsetail_count", 100)),
				field_half, claimed, clear * 0.6, seed_value + 40 + n, Vector2(0.7, 1.25), true))
		n += 1
	for path in cover.get("flora_edge_trees", []):
		var m: Mesh = GroundCover.flora_mesh(String(path))
		if m != null:
			holder.add_child(GroundCover.scatter_band(cfg, m, tall, int(cover.get("flora_edge_count", 24)),
				field_half, float(cover.get("flora_edge_from", 3.0)), float(cover.get("flora_edge_to", 22.0)),
				seed_value + 60 + n, Vector2(0.8, 1.25), true, 1.6))
		n += 1
	for path in cover.get("flora_skyline_trees", []):
		var m: Mesh = GroundCover.flora_mesh(String(path))
		if m != null:
			holder.add_child(GroundCover.scatter_band(cfg, m, tall, int(cover.get("flora_skyline_count", 20)),
				field_half, float(cover.get("flora_skyline_from", 12.0)), float(cover.get("flora_skyline_to", 46.0)),
				seed_value + 80 + n, Vector2(0.85, 1.2), true, 1.8))
		n += 1
	# The cliffs: columnar basalt set into the mountainside, facing in.
	var rock := GroundCover.cover_material()
	for path in cover.get("cliff_rocks", []):
		var m: Mesh = GroundCover.flora_mesh(String(path))
		if m != null:
			holder.add_child(GroundCover.multimesh_of(m, rock,
				GroundCover.cliff_placements(cfg, field_half, seed_value + 100 + n, m.get_aabb()), true))
		n += 1

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
	var smoke: Node3D = _smoke_container()
	for child in smoke.get_children():
		smoke.remove_child(child)
		child.queue_free()

	var nodes_def: Array = []
	var cfg = _get_config()
	if _map().has("default_resource_nodes"):
		nodes_def = _map()["default_resource_nodes"]
	else:
		nodes_def = [
			{"type": "wood", "cell": Vector2i(-4, -2)},
			{"type": "wood", "cell": Vector2i(4, -2)},
			{"type": "stone", "cell": Vector2i(-4, -6)},
			{"type": "stone", "cell": Vector2i(4, -6)},
			{"type": "water", "cell": Vector2i(-11, -4)}
		]

	var t_size: float = 2.0
	if cfg and "TILE_SIZE" in cfg:
		t_size = float(cfg.TILE_SIZE)

	var gs_nodes = _get_game_state()
	var wrecks_wanted: bool = gs_nodes == null or not gs_nodes.has_method("goal_kind") or String(gs_nodes.goal_kind()) == "beacon"
	for item in nodes_def:
		# The ship's wrecks hold the beacon's parts: a whole cabin's beacon wants none (GAMES.custom), so none
		# lies about, smoking, to be searched.
		if not wrecks_wanted and cfg and "RESOURCE_NODES" in cfg and bool(cfg.RESOURCE_NODES.get(String(item["type"]), {}).get("smoke", false)):
			continue
		var node = resource_node_script.new(item["type"], item["cell"])
		node.name = "ResourceNode_%s_%d_%d" % [item["type"], item["cell"].x, item["cell"].y]
		var world_pos = grid_manager.cell_to_world(item["cell"]) if grid_manager else Vector3(float(item["cell"].x) * t_size, 0.0, float(item["cell"].y) * t_size)
		node.position = world_pos
		if String(item["type"]) == "water":
			_face_the_river(node, world_pos)
		resource_nodes_container.add_child(node)
		if grid_manager and grid_manager.has_method("occupy_resource_cell"):
			grid_manager.occupy_resource_cell(item["cell"], node)
		# A wreck not yet searched smoulders, and its smoke is seen over the mist (WreckSmoke): not the
		# wreck's own child, which the fog hides until it is seen. Only one whose place is known: the first
		# stage's; the others' go up as the stages before them are mended (Config.WRECKS, _on_wreck_located).
		if cfg and "RESOURCE_NODES" in cfg and bool(cfg.RESOURCE_NODES.get(String(item["type"]), {}).get("smoke", false)) \
				and (gs_nodes == null or not gs_nodes.has_method("wreck_located") or gs_nodes.wreck_located(String(item["type"]))):
			smoke.add_child(WreckSmoke.make(node))

## Where the wrecks' smoke is raised (WreckSmoke): beside the nodes, not among them.
func _smoke_container() -> Node3D:
	var holder: Node3D = get_node_or_null("WreckSmoke") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "WreckSmoke"
		add_child(holder)
	return holder

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
	var stock: Dictionary = _map().get("opening_stock", {})
	if stock.is_empty():
		return
	var piles: int = maxi(1, int(cfg.DROPS.get("opening_piles", 1)))
	# Measured from the cabin's ends: it is seven metres long.
	var radius: float = float(cfg.get_building_footprint("core")) * 0.5 + float(cfg.DROPS.get("opening_ring_gap", 4.0))
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
# Right-clicking a building
# ==============================================================================

## The first tower finished with nothing in it, the run is told -- once -- what fills it (AmmoTower): what it takes,
## made at the workbench (or the meat in the stock), and that he loads it walking past. A tower nobody loads does
## nothing, and nothing else on the screen says so before the raid comes.
var _told_to_load: bool = false

func _on_tower_finished(b: Node) -> void:
	if _told_to_load or b == null or not is_instance_valid(b) or not b.has_method("accepts") or b.has_ammo():
		return
	_told_to_load = true
	var cfg = _get_config()
	var kinds: Array = b.accepts()
	var first: String = String(kinds[0]) if not kinds.is_empty() else ""
	var what: String = tr(String(cfg.AMMO.get(first, {}).get("name", first))) if cfg else first
	var made: bool = cfg != null and cfg.has_method("is_made") and cfg.is_made(first)
	_hint("HINT_TOWER_NEEDS_AMMO" if made else "HINT_TOWER_NEEDS_MEAT", [String(b.get_localized_name()), what])

## Right-click always does one thing, immediately, and never puts anything up to
## click through. It was briefly a menu when a building had several sensible
## answers, and that was worse: right-click is easy to hit by accident, and a box
## appearing under the cursor every time you misclick is a bad trade for the rare
## case where you wanted the second option.
##
## So the fast, irreversible-free actions live here -- walk over, finish the
## blueprint, go inside -- and everything with a cost or a consequence (repair,
## demolish) lives behind left-click, on the panel, where it is chosen on purpose.
func right_click_building(b: Node, at: Vector3) -> void:
	if b == null or not is_instance_valid(b) or hero == null or not is_instance_valid(hero):
		return
	if _is_cabin(b):
		order_enter_cabin()
		return
	# Work waiting on him -- a blueprint, or an upgrade already paid for -- is what a
	# right-click on it means.
	if ("is_constructed" in b and not b.is_constructed) or (b.has_method("is_upgrading") and b.is_upgrading()):
		hero.order_build(b, true)
		return
	# A tower that wants loading, and the stock has what it takes: loading it (AmmoTower) -- nothing spent that
	# is not put into it.
	if b.has_method("wants_load") and b.wants_load() and hero.has_method("order_load"):
		hero.order_load(b)
		return
	hero.move_to(at if at != Vector3.ZERO else b.global_position)

# ==============================================================================
# The cabin: walking in and out of it
# ==============================================================================
#
# v0.6 round three: "人进入船舱应该只能从船舱入口处进去……进入船舱之后，应该也是同样的人在船舱里面，而不是只是
# 一个贴图". The cabin is a room on the map (CoreCampfire): he walks in through its door and is
# inside it, the same man in the same world, and the view follows him in -- the roof fading
# (the cabin's doing) and the camera easing in over the room (this). It was a room parked two
# hundred metres under the map, and going in moved the camera there.

## True while the given node is the cabin the player can walk into.
func _is_cabin(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("core"):
		return true
	return "building_type" in node and String(node.building_type) == "core"

## Sends the Hero in: through the door, just inside it (CoreCampfire.door_inside). Right-
## clicking the cabin means this -- the same "right-click a thing to act on it" as everything
## else. A cabin fenced off from him says so rather than sending him to press against the fence.
func order_enter_cabin() -> bool:
	if hero == null or not is_instance_valid(hero) or current_core == null or not is_instance_valid(current_core):
		return false
	if not current_core.has_method("door_inside"):
		return false
	var inside: Vector3 = current_core.door_inside()
	if nav_maps != null and is_instance_valid(nav_maps) and nav_maps.is_ready() \
			and not nav_maps.is_reachable(hero.global_position, inside, NavMaps.For.HERO):
		_hint("HINT_CABIN_SHUT")
		return false
	hero.move_to(inside)
	return true

## Sends him out, to stand in front of the door.
func order_leave_cabin() -> bool:
	if hero == null or not is_instance_valid(hero) or current_core == null or not is_instance_valid(current_core):
		return false
	if not current_core.has_method("door_outside"):
		return false
	hero.move_to(current_core.door_outside())
	return true

## In front of the door, outside: where he stands to go in and comes out to.
func cabin_door() -> Vector3:
	if current_core == null or not is_instance_valid(current_core) or not current_core.has_method("door_outside"):
		return Vector3.ZERO
	return current_core.door_outside()

## He has gone in or come out (the cabin says, CoreCampfire._set_hero_inside): the camera eases
## in over the room, or back out to where it was (Config.CABIN inside_camera_distance,
## camera_ease_seconds). The world goes on either way.
func _on_cabin_view_changed(inside: bool) -> void:
	in_cabin = inside
	_ensure_camera_rig()
	if camera_rig == null or camera == null or not is_instance_valid(camera):
		return
	var cfg = _get_config()
	var from := {"focus": camera_rig.focus, "distance": camera_rig.distance}
	var to: Dictionary = {}
	if inside:
		_view_before_cabin = from
		var at: Vector3 = current_core.global_position if (current_core and is_instance_valid(current_core)) else camera_rig.focus
		to = {"focus": at, "distance": float(cfg.CABIN.get("inside_camera_distance", 11.0)) if cfg else 11.0}
	elif not _view_before_cabin.is_empty():
		to = _view_before_cabin
		_view_before_cabin = {}
	if to.is_empty():
		return
	if _camera_ease != null and _camera_ease.is_valid():
		_camera_ease.kill()
	var seconds: float = float(cfg.CABIN.get("camera_ease_seconds", 0.6)) if cfg else 0.6
	if not is_inside_tree() or seconds <= 0.0:
		_ease_view(1.0, from, to)
		return
	_camera_ease = create_tween()
	_camera_ease.tween_method(func(t: float): _ease_view(t, from, to), 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Where the view was before he went in, to go back to when he comes out.
var _view_before_cabin: Dictionary = {}
var _camera_ease: Tween = null

func _ease_view(t: float, from: Dictionary, to: Dictionary) -> void:
	if camera_rig == null or camera == null or not is_instance_valid(camera):
		return
	camera_rig.focus = (from["focus"] as Vector3).lerp(to["focus"], t)
	camera_rig.distance = lerpf(float(from["distance"]), float(to["distance"]), t)
	camera_rig.apply_to(camera)

## A bench clicked: the Hero goes to stand at it, in front of it, facing it -- in through the
## door if he is outside ("点一个工作台 → 人走过去 → 面板出现它的菜单"). The panel shows its menu (the
## click's selection does that).
func _walk_to_bench(bench: Node) -> void:
	if hero == null or not is_instance_valid(hero) or not (bench is Node3D):
		return
	if "current_state" in hero and int(hero.current_state) == 4:
		return          # DEAD
	var cfg = _get_config()
	var size: Vector3 = cfg.get_visual_size("station/" + String(bench.station_id)) if (cfg and "station_id" in bench) else Vector3.ONE
	var front: Vector3 = (bench as Node3D).global_position + Vector3(0.0, 0.0, size.z * 0.5 + float(cfg.HERO.get("width", 0.8)) * 0.5 + 0.1)
	hero.move_to(front)
	OrderMarker.spawn(self, front, "move")

# ==============================================================================
# Interactive & Programmatic Building Placement
# ==============================================================================

func on_build_selected(type_id: String) -> void:
	# A different tool drops whatever the last one was in the middle of: a drag started
	# with the fence must never be let go of as a run of traps.
	_end_drag()
	current_build_type = type_id
	_reach_asked.clear()
	_rebuild_build_preview(type_id)
	if _faces(type_id):
		_hint("HINT_TOWER_TURN")
	elif _turns(type_id):
		_hint("HINT_WALL_TURN")

func cancel_building_selection() -> void:
	current_build_type = ""
	_end_drag()
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
	return gs.can_afford(cost)

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
			zoom_camera(_zoom_step())
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(-_zoom_step())
			get_viewport().set_input_as_handled()
			return

	# Letting go lays the fence. One that was never dragged anywhere lays a single
	# stake, so the old click-one-at-a-time still works exactly as it did.
	if event is InputEventMouseButton and not event.pressed and event.button_index == place_btn 			and _drag_from != NOT_DRAGGING:
		# Not `_run_to(...) if _dragging else [_drag_from]`: an array literal inside a
		# ternary is NOT typed from the variable it lands in, so a plain click assigned an
		# untyped Array to an Array[Vector2i] -- a runtime error on every single-stake
		# placement, which crashed the game.
		var cells: Array[Vector2i] = [_drag_from]
		var faces: int = _placement_facing
		if _dragging:
			cells = _run_to(event.position)
			faces = _run_facing(event.position)
		_end_drag()
		_commit_run(cells, faces)
		get_viewport().set_input_as_handled()
		return

	# Dragging: the ghosts follow the run rather than the cursor.
	if event is InputEventMouseMotion and _drag_from != NOT_DRAGGING:
		if not _dragging and event.position.distance_to(_drag_from_px) >= _drag_number("drag_threshold_px", 6.0):
			_dragging = true
		if _dragging:
			_show_run_preview(_run_to(event.position))
			get_viewport().set_input_as_handled()
			return

	# Build preview follows the cursor while a building type is selected
	if event is InputEventMouseMotion and current_build_type != "" and not _dragging 			and not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_update_build_preview(event.position)

	# Otherwise the cursor outlines whatever it is over, so the player can see what a
	# click would act on before making it.
	if event is InputEventMouseMotion and current_build_type == "" and not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_update_hover(event.position)

	# Middle-drag moves the view: sliding it across the ground, or -- with Shift held --
	# swinging it round whatever is in the middle of the screen.
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_ensure_camera_rig()
		if camera_rig != null and camera != null:
			if event.shift_pressed:
				camera_rig.orbit_drag(event.relative)
			else:
				camera_rig.pan_drag(event.relative)
			camera_rig.apply_to(camera)
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
				zoom_camera(_zoom_step())
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_PAGEDOWN or event.keycode == KEY_MINUS:
				zoom_camera(-_zoom_step())
				get_viewport().set_input_as_handled()
				return

	# A trap or a section of wall in hand turns with R (CONTROLS.trap_turn_key) -- ahead of the
	# camera's reset, which has the same key the rest of the time.
	if event is InputEventKey and event.pressed and not event.echo and _turns(current_build_type) \
			and event.keycode == int(controls.get("trap_turn_key", KEY_R)) \
			and not (event.ctrl_pressed or event.meta_pressed):
		turn_placement(-1 if event.shift_pressed else 1)
		get_viewport().set_input_as_handled()
		return

	# Back to the opening view, for when the player has turned themselves round.
	if event is InputEventKey and event.pressed and not event.echo 			and event.keycode == int(controls.get("camera_reset_key", KEY_R)) 			and not (event.ctrl_pressed or event.meta_pressed):
		reset_camera()
		get_viewport().set_input_as_handled()
		return

	# His card in full, and shut again (Config.CONTROLS.details_key; HUD.toggle_hero_details).
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == int(controls.get("details_key", KEY_C)) \
			and not (event.ctrl_pressed or event.meta_pressed):
		if hud and is_instance_valid(hud) and hud.has_method("toggle_hero_details"):
			hud.toggle_hero_details()
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
	# ESC peels off one layer at a time: the build ghost first, then a submenu of his card,
	# then a pinned selection, and only when there is nothing left to cancel does it open the menu.
	if event is InputEventKey and event.pressed and event.keycode == cancel_key:
		get_viewport().set_input_as_handled()
		if hud and is_instance_valid(hud) and hud.has_method("is_pause_menu_open") and hud.is_pause_menu_open():
			hud.toggle_pause_menu()
			return
		if current_build_type != "":
			cancel_building_selection()
			return
		var eb = _get_event_bus()
		var panel = _get_option_panel()
		# Then a submenu of his card (build, eat), as its Back button does -- or his card open in full.
		if panel != null and is_instance_valid(panel) and panel.has_method("in_submenu") and panel.in_submenu():
			panel._on_back_pressed()
			return
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
		if current_build_type != "":
			cancel_building_selection()
			get_viewport().set_input_as_handled()
			return
		if not _selected_unit_takes_orders():
			get_viewport().set_input_as_handled()
			return
		var hit_pos = _raycast_ground(event.position)
		if hit_pos != null and hero != null and is_instance_valid(hero):
			var cell = grid_manager.world_to_cell(hit_pos) if grid_manager else Vector2i.ZERO
			var res_node = get_resource_node_at_cell(cell)
			# By point, not by tile: several stakes share a tile, and the tile only
			# remembers one of them.
			var b = grid_manager.building_at_point(hit_pos) if grid_manager else null
			# Every order leaves a ring where it was given (OrderMarker): walk, work, fight.
			if res_node != null and is_instance_valid(res_node):
				if hero.has_method("can_harvest") and not hero.can_harvest(res_node):
					_hint_need_tool(res_node)
				else:
					hero.order_harvest(res_node)
					OrderMarker.spawn(self, res_node.global_position, "work")
			elif b != null and is_instance_valid(b):
				right_click_building(b, hit_pos)
				OrderMarker.spawn(self, hit_pos, "work")
			else:
				var hit_obj = _raycast_object(event.position)
				if hit_obj != null and is_instance_valid(hit_obj):
					if hit_obj.is_in_group("resource_nodes") or ("resource_type" in hit_obj):
						if hero.has_method("can_harvest") and not hero.can_harvest(hit_obj):
							_hint_need_tool(hit_obj)
						else:
							hero.order_harvest(hit_obj)
							OrderMarker.spawn(self, hit_obj.global_position, "work")
					elif hit_obj.is_in_group("dinos"):
						hero.order_attack(hit_obj)
						OrderMarker.spawn(self, hit_obj.global_position, "attack")
					elif hit_obj.is_in_group("buildings") or _is_cabin(hit_obj):
						right_click_building(hit_obj, hit_pos)
						OrderMarker.spawn(self, hit_pos, "work")
					else:
						hero.move_to(hit_pos)
						OrderMarker.spawn(self, hit_pos, "move")
				else:
					hero.move_to(hit_pos)
					OrderMarker.spawn(self, hit_pos, "move")
		get_viewport().set_input_as_handled()
		return

	# Left-click (Default build place button / Unit selection)
	if event is InputEventMouseButton and event.pressed and event.button_index == place_btn:
		if current_build_type == "":
			var hit_obj = _raycast_object(event.position)
			var eb = _get_event_bus()
			if hit_obj != null and is_instance_valid(hit_obj) and (hit_obj.is_in_group("selectable") or hit_obj.is_in_group("hero") or hit_obj.is_in_group("buildings")):
				if eb and eb.has_signal("unit_selected"):
					eb.unit_selected.emit(hit_obj)
				# A bench is worked where it stands: he goes to it.
				if hit_obj.is_in_group("stations"):
					_walk_to_bench(hit_obj)
			else:
				if eb and eb.has_signal("unit_deselected"):
					eb.unit_deselected.emit()
			get_viewport().set_input_as_handled()
			return

		var hit_pos = _raycast_ground(event.position)
		if hit_pos != null:
			if _is_dragged_out(current_build_type):
				# A fence is DRAGGED. Nothing is laid on the press: the player may be
				# about to pull out a run, and a stake dropped under the finger before
				# they have moved is one they did not ask for. A press that never moves
				# far enough lays exactly one on release, so a click still works.
				_drag_from = grid_manager.world_to_build_cell(hit_pos)
				_drag_from_px = event.position
				_dragging = false
				if build_preview != null and is_instance_valid(build_preview):
					build_preview.visible = false
			else:
				# The exact point clicked, not just the tile: a stake snaps to the finer
				# grid and needs to know where inside the tile the player actually pointed.
				try_place_at_cell(grid_manager.world_to_cell(hit_pos), hit_pos)
		get_viewport().set_input_as_handled()
		return

# ==============================================================================
# Dragging out a wall
# ==============================================================================
#
# Press where the fence starts, drag to where it ends, let go. Clicking a hundred stakes
# one at a time is not a decision a hundred times over; it is the same decision a hundred
# times, and every building game solved it the same way.
#
# NOTHING NEW UNDERNEATH IT. The run is GridManager's own line traversal asked at the
# building grid's scale instead of the tile's, every section goes down through the same
# try_place_at_cell as a single click, and the ghosts are the same Building.make_body the
# single ghost already used. What is actually new is three pieces
# of state and the rule about when a press becomes a drag.

## Where the finger went down, in cells of the building grid, or NOT_DRAGGING.
var _drag_from: Vector2i = Vector2i(2147483647, 2147483647)
var _drag_from_px: Vector2 = Vector2.ZERO
## True once the cursor has moved far enough that this is a drag and not a click.
var _dragging: bool = false
## The ghosts of the run, rebuilt whenever the cursor moves to a different cell.
var _run_preview: Node3D = null
var _run_cells: Array[Vector2i] = []

const NOT_DRAGGING := Vector2i(2147483647, 2147483647)

## Whether this kind of building is laid in runs: the kinds Config.BUILD_DRAG names -- a fence and every
## wall, and a patch of spikes (v0.6 round seven, the player: "地刺这种也可以连续建造"). Derived from the KIND
## rather than declared building by building, because the kind is already the category the rest of the
## rules are written against -- so a new sort of barrier, or a better spike, gets this for free. Not a gate:
## it is a wall, but where it goes is a decision about one spot, and a run of gates is a hole.
func _is_dragged_out(type_id: String) -> bool:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_building_kind"):
		return false
	if cfg.has_method("hero_passes") and cfg.hero_passes(type_id):
		return false
	var kinds: Array = cfg.BUILD_DRAG.get("kinds", ["wall"]) if ("BUILD_DRAG" in cfg) else ["wall"]
	return kinds.has(String(cfg.get_building_kind(type_id)))

func _drag_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	if cfg and "BUILD_DRAG" in cfg and cfg.BUILD_DRAG is Dictionary:
		return float(cfg.BUILD_DRAG.get(key, fallback))
	return fallback

## The build cells a run from `_drag_from` to the cursor would cover, already filtered to the
## ones a section of wall can stand in -- paid for or not: the ones the stock does not stretch to
## are shown red and not laid (_run_plan).
##
## Blocked cells are SKIPPED rather than cutting the run short: dragging a fence past a
## rock should give a fence either side of the rock, which is what the player meant, and
## it means the ghosts are exactly what will be built -- what you see is what you get.
func _run_to(screen_pos: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _drag_from == NOT_DRAGGING or current_build_type == "" or grid_manager == null:
		return out
	var hit = _raycast_ground(screen_pos)
	if hit == null:
		return out
	# CENTRE TO CENTRE, not centre to wherever the cursor happens to be. A line that runs
	# exactly along a cell boundary is ambiguous -- the traversal may take either side of it --
	# and two runs drawn to the same corner then land in different rows and the corner is left
	# open. Snapping both ends puts the line through the middle of cells.
	var from_world: Vector3 = grid_manager.build_cell_to_world(_drag_from)
	var to_world: Vector3 = grid_manager.build_cell_to_world(grid_manager.world_to_build_cell(hit))
	var line: Array[Vector2i] = grid_manager.build_cells_on_line(from_world, to_world)
	var cap: int = int(_drag_number("max_run", 120.0))
	for cell in line:
		if out.size() >= cap:
			break
		if build_system != null and build_system.can_stand_at(current_build_type, cell):
			out.append(cell)
	return out

## How a run stands, in the order it was dragged: the sections he can get to, paid for while the stock
## lasts ("going": green in the preview, as a single ghost that would go down is); the ones he can get to
## that the stock does not stretch to ("short"); and the ones he cannot get to ("unreached"). Both of those
## are red (v0.6 round six: "连续建造的时候，如果材料不够的pending就显示红色"), and while any section is red
## none of the run goes down (_commit_run; round seven: "我要的效果是all or nothing").
func _run_plan(cells: Array[Vector2i]) -> Dictionary:
	var budget: int = build_system.affordable_count(current_build_type) if build_system != null else 0
	var going: Array[Vector2i] = []
	var short: int = 0
	var unreached: int = 0
	for cell in cells:
		if not _can_reach_cell(cell):
			unreached += 1
		elif going.size() < budget:
			going.append(cell)
		else:
			short += 1
	return {"going": going, "short": short, "unreached": unreached}

## The way a run dragged to the cursor faces: along the longer of its two spans -- a section of it
## standing alone (a rock either side) runs the way the rest of the line does.
func _run_facing(screen_pos: Vector2) -> int:
	var hit = _raycast_ground(screen_pos)
	if hit == null or _drag_from == NOT_DRAGGING:
		return _placement_facing
	var span: Vector2i = grid_manager.world_to_build_cell(hit) - _drag_from
	if span == Vector2i.ZERO:
		return _placement_facing
	return 0 if absi(span.x) >= absi(span.y) else 1

func _show_run_preview(cells: Array[Vector2i]) -> void:
	if cells == _run_cells and _run_preview != null and is_instance_valid(_run_preview):
		return
	_run_cells = cells.duplicate()
	_clear_run_preview()
	if cells.is_empty():
		return
	_run_preview = Node3D.new()
	_run_preview.name = "RunPreview"
	add_child(_run_preview)
	var faces: int = _run_facing(get_viewport().get_mouse_position())
	var plan: Dictionary = _run_plan(cells)
	var going_up: Array[Vector2i] = plan["going"]
	for cell in cells:
		var body: Node3D = Building.make_body(current_build_type)
		body.position = grid_manager.build_cell_to_world(cell)
		# Dressed as it will stand: joined to the rest of the run and to what is already built.
		_dress_ghost(body, cell, cells, faces)
		# Green where the section would go down, as a single ghost is; red where he cannot get to it, or
		# past what the stock pays for -- and then none of the run goes down (_commit_run).
		for mi in _meshes_in(body):
			mi.material_override = _make_preview_material(_ghost_colour(going_up.has(cell)))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_run_preview.add_child(body)
	_preview_neighbours(going_up)
	# What it will cost, before the wood is spent rather than after -- or why none of it would go.
	if int(plan["short"]) > 0:
		# Of the whole run as dragged -- the count the line on letting go says.
		_hint("HINT_RUN_SHORT", [going_up.size(), cells.size()])
	elif int(plan["unreached"]) > 0:
		_hint("HINT_RUN_UNREACHABLE")
	else:
		_hint_run(cells.size())

func _clear_run_preview() -> void:
	if _run_preview != null and is_instance_valid(_run_preview):
		_run_preview.queue_free()
	_run_preview = null
	_restore_neighbours()

func _hint_run(count: int) -> void:
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(current_build_type):
		return
	var cost: Dictionary = cfg.BUILDINGS[current_build_type].get("cost", {})
	var parts: PackedStringArray = []
	for res_id in cost:
		parts.append("%d %s" % [int(cost[res_id]) * count, tr("RESOURCE_" + String(res_id).to_upper())])
	if hud and is_instance_valid(hud) and hud.has_method("show_hint"):
		hud.show_hint(tr("HINT_DRAG_RUN") % [count, ", ".join(parts)])

## Lays the run -- all of it, or none of it (v0.6 round seven, the player: "墙连续建造，材料不够现在是会显示红色
## 了，但是按左键还是会把能造得造下去，我要的效果是all or nothing，有红色的时候点下去会有一行小字说明材料不够，白色
## 部分也没法造下去"). While a section is red (_run_plan) -- past what the stock pays for, or where he cannot get
## to -- nothing goes down, nothing is paid, and the hint at the top says why; with none red, every
## section goes down, in the order it was dragged. A run of one is a click, refused and said as a click is
## (try_place_at_cell: the spot taken, where he cannot get to, then the price).
##
## Each section goes down through the same call a single click makes, so paying for it, registering it on
## the grid, telling the Hero and rebaking the navigation mesh all happen exactly as they always did.
func _commit_run(cells: Array[Vector2i], faces: int = -1) -> int:
	if cells.is_empty():
		return 0
	if cells.size() > 1:
		var plan: Dictionary = _run_plan(cells)
		if int(plan["short"]) > 0:
			_reach_asked.clear()
			_hint("HINT_RUN_SHORT_NONE", [cells.size(), _missing_for(current_build_type, cells.size())])
			return 0
		if int(plan["unreached"]) > 0:
			_reach_asked.clear()
			_hint("HINT_RUN_UNREACHABLE_NONE", [int(plan["unreached"])])
			return 0
	var laid: int = 0
	for cell in cells:
		if current_build_type == "":
			break                          # the wallet emptied and build mode dropped
		var at: Vector3 = grid_manager.build_cell_to_world(cell)
		if try_place_at_cell(grid_manager.world_to_cell(at), at, faces) != null:
			laid += 1
	_reach_asked.clear()
	return laid

## What the stock is short of for `count` of `type_id`, in words -- "14 wood, 2 stone" -- or "" when it is
## short of nothing.
func _missing_for(type_id: String, count: int) -> String:
	var cfg = _get_config()
	var gs = _get_game_state()
	if cfg == null or gs == null or not cfg.BUILDINGS.has(type_id):
		return ""
	var cost: Dictionary = cfg.BUILDINGS[type_id].get("cost", {})
	var parts: PackedStringArray = []
	for res_id in cost:
		var short: int = int(cost[res_id]) * count - int(gs.resources.get(res_id, 0))
		if short > 0:
			parts.append("%d %s" % [short, tr("RESOURCE_" + String(res_id).to_upper())])
	return ", ".join(parts)

## The ghost's colour: green where it would go down, red where it would not (Config.BUILD_GHOST) -- one pair
## for a single ghost and every section of a run.
func _ghost_colour(goes: bool) -> Color:
	var cfg = _get_config()
	var ghost: Dictionary = cfg.BUILD_GHOST if (cfg and "BUILD_GHOST" in cfg) else {}
	return ghost.get("go", Color.GREEN) if goes else ghost.get("no", Color.RED)

## Dresses a ghost as the building will stand -- by the code the building dresses itself with: a
## palisade's runs towards the walls beside `cell` (built, or in `planned`), and straight along the
## way it `faces` with none; a gate across the line of the wall it is in.
func _dress_ghost(body: Node3D, cell: Vector2i, planned: Array = [], faces: int = -1) -> void:
	if faces < 0:
		faces = _placement_facing
	var near: Dictionary = Wall.neighbours_of(grid_manager, cell, null, planned)
	Wall.dress(body, near, faces)
	var cfg = _get_config()
	if cfg and cfg.has_method("hero_passes") and cfg.hero_passes(current_build_type):
		body.rotation.y = Gate.across(near, faces)

## Shows the sections of wall already beside `planned` as they will stand once it is up: the end
## of a fence turning the corner into a new run, a lone post becoming part of a line. The ghost
## alone only told half of it -- what was built changed shape the moment the new piece went down.
func _preview_neighbours(planned: Array) -> void:
	_restore_neighbours()
	if grid_manager == null or planned.is_empty() or not _is_wall_kind(current_build_type):
		return
	for cell in planned:
		for run in Wall.RUNS:
			var there: Vector2i = cell + Wall.RUNS[run]
			if planned.has(there):
				continue
			var b: Node = grid_manager.building_in_build_cell(there)
			if b == null or _redressed.has(b) or not Wall.is_wall(b) or not b.has_method("refresh_joins"):
				continue
			b.refresh_joins(planned)
			_redressed.append(b)

## Puts back what _preview_neighbours dressed for the moment.
func _restore_neighbours() -> void:
	for b in _redressed:
		if b != null and is_instance_valid(b) and b.has_method("refresh_joins"):
			b.refresh_joins()
	_redressed.clear()

## Whether the Hero can get close enough to `cell` to raise the building in hand there
## (Hero.can_reach_to_build). Asked once per cell per gesture (_reach_asked). With no Hero to ask,
## nobody says no.
func _can_reach_cell(cell: Vector2i) -> bool:
	if _reach_asked.has(cell):
		return bool(_reach_asked[cell])
	var yes: bool = true
	if hero != null and is_instance_valid(hero) and hero.has_method("can_reach_to_build") and grid_manager != null:
		yes = bool(hero.can_reach_to_build(current_build_type, grid_manager.footprint_centre(current_build_type, cell)))
	_reach_asked[cell] = yes
	return yes

func _end_drag() -> void:
	_drag_from = NOT_DRAGGING
	_dragging = false
	_run_cells.clear()
	_clear_run_preview()

## Places the currently selected building type at `cell` and keeps the build mode
## alive so the player can lay down a whole row of blueprints in one go, dropping
## it only when the next one is no longer affordable. The Hero picks the blueprints
## up one at a time. Returns the blueprint, or null if the spot was rejected.
func try_place_at_cell(cell: Vector2i, at_world: Variant = null, faces: int = -1) -> Node:
	if current_build_type == "" or build_system == null:
		return null

	# The spot taken -- by a building, a tree, a rock, a hillside -- is said as such, before the
	# price is looked at: it is the nearer reason. Somebody standing there is not a reason: the
	# order goes down and waits for them (Building.add_build_progress).
	var spot: Vector2i = build_system.build_cell_for(cell, at_world)
	if grid_manager and not grid_manager.can_build_on(grid_manager.footprint_cells(current_build_type, spot)):
		_hint("HINT_CELL_OCCUPIED")
		return null
	# Nor is a spot he could never get to: an order he cannot carry out is not placed.
	if not _can_reach_cell(spot):
		_hint("HINT_UNREACHABLE")
		return null

	var placed = build_system.place_at(current_build_type, spot, buildings_container, true,
		_placement_facing if faces < 0 else faces)
	if placed != null:
		if hero != null and is_instance_valid(hero):
			hero.order_build(placed, false)
		if not _can_afford_building(current_build_type):
			cancel_building_selection()
		return placed

	# Rejected. Say why when it was the price.
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs and cfg and cfg.BUILDINGS.has(current_build_type):
		if not gs.can_afford(cfg.BUILDINGS[current_build_type].get("cost", {})):
			_hint("HINT_NO_RESOURCES")
	return null

## The map this run is played on (GameState.map_data): where everything stands and what
## lies by the cabin at the start. Config.MAPS holds every map; which one is the run's.
## The game this level plays, and so its map (GameState.game, Config.GAMES) -- when this is the game
## itself, the level the player launched: ours on the large valley, or what the start screen chose. A level a
## test or a tool builds plays the default, the small valley (v0.6 round four: "测试的时候可以用小地图，我玩的
## 时候用大地图").
func _choose_the_map() -> void:
	var gs = _get_game_state()
	if gs == null or not _plays_the_players_map():
		return
	# The launch plays our game (Config.GAMES.campaign) till the start screen chooses another; the run it builds
	# is the game's, on the game's map.
	if String(gs.game_id()) == "":
		gs.play("campaign")
	gs.reset_game()

## Whether this level is the game the player launched (its main scene), not one a script built.
func _plays_the_players_map() -> bool:
	return is_inside_tree() and get_tree().current_scene == self

func _map() -> Dictionary:
	var gs = _get_game_state()
	if gs and gs.has_method("map_data"):
		var m: Dictionary = gs.map_data()
		if not m.is_empty():
			return m
	var cfg = _get_config()
	return cfg.map_data() if (cfg and cfg.has_method("map_data")) else {}

func _hint(key: String, args: Array = []) -> void:
	if hud and is_instance_valid(hud) and hud.has_method("show_hint"):
		hud.show_hint(tr(key) % args if not args.is_empty() else tr(key))

## Why he cannot cut `node` yet: which tool, where it is made, what it costs.
func _hint_need_tool(node: Node) -> void:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("missing_tool_hint") or not ("resource_type" in node):
		return
	if hud and is_instance_valid(hud) and hud.has_method("show_hint"):
		var gs_known = _get_game_state()
		var known: Callable = gs_known.knows if (gs_known and gs_known.has_method("knows")) else Callable()
		hud.show_hint(String(cfg.missing_tool_hint(String(node.resource_type), known)), UiTheme.toast_seconds("read"))

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

## The camera the player is looking through: the map's, inside the cabin as out of it.
func _active_camera() -> Camera3D:
	return camera

# ==============================================================================
# What the cursor is over
# ==============================================================================

## One ring, moved to whatever the cursor is on. Deliberately not a second ring on
## every entity: there is only ever one cursor.
var _hover_ring: SelectionRing3D = null
var _hovered: Node = null

## Outlines the thing under the cursor, in a different colour from the selection ring.
##
## Asked for because of the stakes: one is 0.62m wide, a fence is a row of them, and at
## eighteen metres up there was no way to tell which one a click would hit -- or whether
## it would hit one at all rather than the ground behind it.
##
## Only while something is selected, because that is when a click does anything.
func _update_hover(screen_pos: Vector2) -> void:
	var want: Node = null
	if _selected_unit_takes_orders() or _has_selection():
		var hit = _raycast_object(screen_pos)
		if hit != null and is_instance_valid(hit) and _is_hoverable(hit):
			want = hit
		elif grid_manager != null:
			# The ray can slip past something as thin as a stake and land on the ground
			# behind it, so the grid gets asked about the point as well.
			var ground = _raycast_ground(screen_pos)
			if ground != null:
				var b = grid_manager.building_at_point(ground)
				if b != null and is_instance_valid(b) and _is_hoverable(b):
					want = b
	_show_hover(want)

func _has_selection() -> bool:
	var panel = hud.find_child("OptionPanel", true, false) if (hud and is_instance_valid(hud)) else null
	if panel == null or not is_instance_valid(panel) or not ("selected_unit" in panel):
		return false
	return panel.selected_unit != null and is_instance_valid(panel.selected_unit)

func _is_hoverable(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node3D):
		return false
	# Out of sight in the fog (FogOfWar): not there to be pointed at.
	if not (node as Node3D).is_visible_in_tree():
		return false
	if "is_destroyed" in node and node.is_destroyed:
		return false
	for group in ["buildings", "dinos", "hero", "selectable", "resource_nodes", "stations"]:
		if node.is_in_group(group):
			return true
	return false

func _show_hover(node: Node) -> void:
	if node == _hovered:
		if _hover_ring != null and node != null and is_instance_valid(node):
			_hover_ring.global_position = (node as Node3D).global_position
		return
	_hovered = node
	_lift(node)
	if node == null or not is_instance_valid(node):
		if _hover_ring != null:
			_hover_ring.set_shown(false)
		return
	if _hover_ring == null:
		_hover_ring = SelectionRing3D.new()
		_hover_ring.name = "HoverRing"
		add_child(_hover_ring)
		var cfg = _get_config()
		var tint: Color = Color(1.0, 1.0, 1.0, 0.55)
		if cfg and "FEEDBACK" in cfg:
			tint = cfg.FEEDBACK.get("hover_ring_color", tint)
		_hover_ring.override_color(tint)
	# Matched to the thing's OWN selection ring where it has one, so hovering and
	# selecting outline the same shape at the same size and only the colour differs.
	var shape: int = SelectionRing3D.Shape.ROUND
	var size: float = 1.0
	var depth: float = -1.0
	if "selection_ring" in node and node.selection_ring != null and is_instance_valid(node.selection_ring):
		shape = int(node.selection_ring.shape)
		size = float(node.selection_ring.base_size)
		depth = float(node.selection_ring.base_depth)
	elif "building_type" in node:
		var cfg2 = _get_config()
		shape = SelectionRing3D.Shape.BOX
		var half: Vector2 = cfg2.get_building_half(String(node.building_type)) if cfg2 else Vector2.ONE * 0.5
		size = half.x * 2.0
		depth = half.y * 2.0
	_hover_ring.configure(shape, size, depth)
	_hover_ring.global_position = (node as Node3D).global_position
	_hover_ring.set_shown(true)

## What can be worked lifts a little under the cursor (UI-POLISH T21, the player: "能点的和不能点的要分得
## 开……悬停时的一点反应"): a faint warm wash over the tree or the rock (Config.FEEDBACK.hover_lift_color),
## gone when the cursor leaves. The ring under it says what a click would pick; this, that the thing is
## there to be worked and not the valley. Only its body (ResourceNode "Body") -- not its ring or its bar --
## and never over a wash already on it (Fx: a flash).
var _lifted: Array[MeshInstance3D] = []
var _lift_mat: StandardMaterial3D = null

func _lift(node: Node) -> void:
	for m in _lifted:
		if is_instance_valid(m) and m.material_overlay == _lift_mat:
			m.material_overlay = null
	_lifted.clear()
	if node == null or not is_instance_valid(node) or not node.is_in_group("resource_nodes"):
		return
	var body: Node = node.find_child("Body", false, false)
	if body == null:
		return
	if _lift_mat == null:
		var cfg = _get_config()
		_lift_mat = StandardMaterial3D.new()
		_lift_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lift_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_lift_mat.albedo_color = cfg.FEEDBACK.get("hover_lift_color", Color(0.1, 0.08, 0.05)) if (cfg and "FEEDBACK" in cfg) \
			else Color(0.1, 0.08, 0.05)
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if mesh.material_overlay == null:
			mesh.material_overlay = _lift_mat
			_lifted.append(mesh)

## What is lifted under the cursor now (for a test).
func lifted() -> Array[MeshInstance3D]:
	return _lifted

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

	# Nothing was hit, which since v0.5 happens over most of the screen: the ground the
	# player can SEE runs out to the valley walls, and the ground COLLIDER only covers
	# the flat playfield. Clicking the visible land beyond it hit nothing at all, so no
	# order was ever issued and the Hero simply stood there -- looking for all the world
	# like broken pathfinding.
	#
	# Falling back to the ground plane means a click always produces a point. Whether
	# the Hero can get to it is the pathfinder's business, and it now walks as far as it
	# can rather than refusing.
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null                      # looking along the horizon; no intersection
	var t: float = -from.y / dir.y
	if t <= 0.0:
		return null                      # the plane is behind the camera
	return from + dir * t

## What a click at `screen_pos` means: the thing pointed at, which is not always the first
## surface the ray meets.
##
## v0.6 feedback: "人经常选中不了". The ray used to stop at whatever it met first, and a tree
## is clicked by its whole crown seen from above (Config.LAYER_PICK) -- so a man chopping it,
## standing under that crown, could not be pointed at at all, and the cabin's walls hid him
## the same way. Now somebody near the cursor is taken first (_unit_near_cursor), and
## otherwise the ray goes on through what it meets and the one taken is by rank
## (_pick_rank): a building before a tree it stands under.
func _raycast_object(screen_pos: Vector2) -> Node:
	var unit: Node = _unit_near_cursor(screen_pos)
	if unit != null:
		return unit
	var best: Node = null
	var best_rank: int = 1 << 30
	for hit in _objects_along_ray(screen_pos):
		var rank: int = _pick_rank(hit)
		if rank < best_rank:
			best_rank = rank
			best = hit
	return best

## Everything the ray from `screen_pos` passes through before the ground, nearest first --
## each one the thing that was hit, not the part of it (a tree's trunk is a body of its own).
func _objects_along_ray(screen_pos: Vector2) -> Array[Node]:
	var out: Array[Node] = []
	var cam := _active_camera()
	if cam == null or not is_inside_tree() or get_world_3d() == null:
		return out
	var space_state = get_world_3d().direct_space_state
	var from = cam.project_ray_origin(screen_pos)
	var query = PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * 1000.0)
	query.collision_mask = _pick_mask()
	var exclude: Array[RID] = []
	for i in range(int(_controls().get("pick_depth", 6))):
		query.exclude = exclude
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty() or not result.has("collider"):
			break
		var thing: Node = _pickable_owner(result["collider"])
		if thing == null:
			break        # the ground or a hillside: nothing behind it can be seen
		if not out.has(thing):
			out.append(thing)
		exclude.append(result["rid"])
	return out

## The layers a pointer looks at. Blueprints are on a layer of their own so they can be
## pointed at without being in anyone's way, walls on theirs, and a tree is clicked by its
## crown (Config.LAYER_PICK).
func _pick_mask() -> int:
	var cfg = _get_config()
	var mask: int = 1 | 2 | 4 | 8
	if cfg:
		mask |= int(cfg.LAYER_BLUEPRINT) | int(cfg.LAYER_WALL) | int(cfg.LAYER_PICK) | int(cfg.LAYER_NEST) 			| int(cfg.LAYER_GATE)
	return mask

## The thing `collider` belongs to -- itself, or the entity it is a part of -- or null for
## what is only ground.
func _pickable_owner(collider: Variant) -> Node:
	var node: Node = collider as Node
	for i in range(3):
		if node == null:
			return null
		if _is_hoverable(node):
			return node
		node = node.get_parent()
	return null

## Which of several things under the cursor a click means: the lower, the sooner. Somebody
## before a bench or a building, and a building before the tree whose crown hangs over it.
func _pick_rank(node: Node) -> int:
	if node.is_in_group("hero"):
		return 0
	if node.is_in_group("dinos"):
		return 1
	if node.is_in_group("stations"):
		return 2
	if node.is_in_group("buildings") or _is_cabin(node):
		return 3
	if node.is_in_group("resource_nodes"):
		return 4
	return 5

## The Hero or a dinosaur the cursor is on or just beside, nearest the cursor first -- or
## null. By where their bodies are on the screen rather than by the ray, so a raptor is not a
## thing that has to be hit exactly from eighteen metres up (Config.CONTROLS.pick_slop_px).
func _unit_near_cursor(screen_pos: Vector2) -> Node:
	var cam := _active_camera()
	if cam == null or not is_inside_tree():
		return null
	var cfg = _get_config()
	var slop: float = float(_controls().get("pick_slop_px", 8.0))
	var best: Node = null
	var best_d: float = INF
	for group_name in ["hero", "dinos"]:
		for unit in get_tree().get_nodes_in_group(group_name):
			if not (unit is Node3D) or not is_instance_valid(unit) or not (unit as Node3D).is_visible_in_tree():
				continue
			if ("is_dead" in unit and unit.is_dead) or ("current_state" in unit and group_name == "hero" and int(unit.current_state) == 4):
				continue
			var size: Vector3 = _unit_size(unit, cfg)
			var foot: Vector3 = (unit as Node3D).global_position
			var middle: Vector3 = foot + Vector3(0.0, size.y * 0.5, 0.0)
			if cam.is_position_behind(middle):
				continue
			var at: Vector2 = cam.unproject_position(middle)
			# How big the body is on the screen: its height, and its width at its middle.
			var up: float = at.distance_to(cam.unproject_position(foot + Vector3(0.0, size.y, 0.0)))
			var across: float = at.distance_to(cam.unproject_position(middle + cam.global_transform.basis.x * size.x * 0.5))
			var reach: Vector2 = Vector2(across + slop, up + slop)
			var off: Vector2 = screen_pos - at
			var d: float = Vector2(off.x / maxf(1.0, reach.x), off.y / maxf(1.0, reach.y)).length()
			if d <= 1.0 and d < best_d:
				best_d = d
				best = unit
	return best

## How big a unit is, as Config declares it: the Hero's size, or his species'.
func _unit_size(unit: Node, cfg: Node) -> Vector3:
	if cfg == null or not cfg.has_method("get_visual_size"):
		return Vector3(0.8, 1.2, 0.8)
	if unit.is_in_group("hero"):
		return cfg.get_visual_size("hero")
	if "dino_type" in unit:
		return cfg.get_visual_size("dino/" + String(unit.dino_type))
	return Vector3(0.8, 1.0, 0.8)

func _controls() -> Dictionary:
	var cfg = _get_config()
	return cfg.CONTROLS if (cfg and "CONTROLS" in cfg and cfg.CONTROLS is Dictionary) else {}

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
	# The same game again, on the same level (a new game -- another map, age, nests -- is built afresh from the
	# start screen, StartScreen).
	cancel_building_selection()
	if in_cabin:
		_on_cabin_view_changed(false)
	if run_stats and is_instance_valid(run_stats):
		run_stats.reset()
	if night_prowl and is_instance_valid(night_prowl):
		night_prowl.reset()
	if din and is_instance_valid(din):
		din.reset()

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

## Closer to or further from the point being looked at. Positive is closer.
##
## It used to slide the camera along its own forward vector and clamp the HEIGHT it ended
## up at, which quietly does two wrong things: the point being looked at drifts with
## every notch, so zooming in walks the view off whatever you were studying, and a clamp
## in metres of height becomes a different zoom range at every tilt -- which matters now
## that the tilt can change.
func zoom_camera(amount: float) -> void:
	_ensure_camera_rig()
	if camera_rig == null or camera == null or not is_instance_valid(camera):
		return
	camera_rig.zoom_by(amount)
	camera_rig.apply_to(camera)

## Puts the view back where the scene opened it.
func reset_camera() -> void:
	_ensure_camera_rig()
	if camera_rig == null or camera == null or not is_instance_valid(camera):
		return
	camera_rig.reset()
	camera_rig.apply_to(camera)

## The view over `at` on the ground, as the player had it turned and zoomed (the hand-drawn map clicked, MiniMap).
func look_at_ground(at: Vector3) -> void:
	_ensure_camera_rig()
	if camera_rig == null or camera == null or not is_instance_valid(camera):
		return
	camera_rig.look_at_ground(at)
	camera_rig.apply_to(camera)

func _zoom_step() -> float:
	var cfg = _get_config()
	if cfg and "CAMERA" in cfg and cfg.CAMERA is Dictionary:
		return float(cfg.CAMERA.get("zoom_step", 2.2))
	return 2.2

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

## The keys that can be HELD: panning, turning and tilting all want to be smooth, so
## they are read every frame rather than waiting for a key event to repeat.
## Whether the cursor is over the window (the engine's mouse-enter and -exit): edge panning waits
## for it, so a cursor that left by an edge -- or never came, as in a headless run -- does not
## drift the view.
var _mouse_in_window: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in_window = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in_window = false

func _handle_camera_keys(delta: float) -> void:
	if camera_rig == null or camera == null or not is_instance_valid(camera):
		return
	var cfg = _get_config()
	var controls: Dictionary = cfg.CONTROLS if (cfg and "CONTROLS" in cfg and cfg.CONTROLS is Dictionary) else {}

	var pan_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_vec.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_vec.y -= 1.0
	# The cursor at the window's edge, as the arrow keys (CameraRig.edge_direction) -- only while
	# it is over the window and the window has the focus.
	if _mouse_in_window and DisplayServer.window_is_focused():
		var vp := get_viewport()
		pan_vec += camera_rig.edge_direction(vp.get_mouse_position(), vp.get_visible_rect().size)
	camera_rig.pan_keys(pan_vec, delta)

	var turn: float = 0.0
	if Input.is_key_pressed(int(controls.get("camera_rotate_left_key", KEY_Q))):
		turn -= 1.0
	if Input.is_key_pressed(int(controls.get("camera_rotate_right_key", KEY_E))):
		turn += 1.0
	camera_rig.rotate_keys(turn, delta)

	var lean: float = 0.0
	if Input.is_key_pressed(int(controls.get("camera_tilt_up_key", KEY_F))):
		lean += 1.0
	if Input.is_key_pressed(int(controls.get("camera_tilt_down_key", KEY_V))):
		lean -= 1.0
	camera_rig.tilt_keys(lean, delta)

	camera_rig.apply_to(camera)

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

	# The ghost is drawn by the same code as the real building, so it can never
	# promise a shape the finished thing does not have -- a cube standing in for a
	# stake told the player nothing about what was going down.
	var body: Node3D = Building.make_body(type_id)
	build_preview.add_child(body)
	build_preview_mesh = _first_mesh_in(body)
	for mi in _meshes_in(body):
		mi.material_override = _make_preview_material(Color.WHITE)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The ground a facing tower acts on, laid out before it is paid for (_show_zone): the log tower's lane ahead of
	# it, as wide as a log is long; the catapult's patch, out where it throws.
	if _faces(type_id):
		var zone := MeshInstance3D.new()
		zone.name = "LanePreview"
		zone.material_override = _make_preview_material(_lane_colour(), 0.35)
		zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var row: Dictionary = cfg.BUILDINGS[type_id]
		if row.has("zone_distance"):
			var disc := CylinderMesh.new()
			disc.top_radius = float(row.get("zone_radius", 2.0))
			disc.bottom_radius = disc.top_radius
			disc.height = 0.04
			zone.mesh = disc
		else:
			var plane := PlaneMesh.new()
			plane.size = Vector2(float(row.get("lane_width", 1.0)), 1.0)
			zone.mesh = plane
		build_preview.add_child(zone)

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

## Area of effect a pending building would have, as a ring: what a building with a reach declares.
## A facing tower shows its lane or patch as well (_show_zone).
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
		return _reach_colour()
	return Color(0.4, 0.8, 0.4)

func _meshes_in(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes_in(child))
	return out

func _first_mesh_in(node: Node) -> MeshInstance3D:
	var all := _meshes_in(node)
	return all[0] if not all.is_empty() else null

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
		_preview_cell = Vector2i(999999, 999999)
		_restore_neighbours()
		return

	# Everything snaps to the building grid (Config.BUILD_CELL): the ghost stands in the cell the
	# building would, dressed as it would stand there.
	var snap: Vector2i = grid_manager.world_to_build_cell(hit)
	build_preview.visible = true
	if snap == _preview_cell:
		return
	_preview_cell = snap
	_reach_asked.clear()
	build_preview.global_position = grid_manager.footprint_centre(current_build_type, snap)
	var ghost: Node = build_preview.find_child("Body", false, false)
	if ghost is Node3D:
		_dress_ghost(ghost as Node3D, snap)
		if _faces(current_build_type):
			(ghost as Node3D).rotation.y = AmmoTower.facing_yaw(_placement_facing)
	_show_zone(snap)

	# Nobody standing there matters (try_place_at_cell); whether he could get there to build it does,
	# and is said.
	var ok: bool = _can_afford_building(current_build_type)
	if ok and build_system and build_system.has_method("can_place_at"):
		ok = bool(build_system.can_place_at(current_build_type, snap))
	if ok and not _can_reach_cell(snap):
		ok = false
		_hint("HINT_UNREACHABLE")
	if ok:
		_preview_neighbours([snap])
	else:
		_restore_neighbours()

	_tint_ghost(ok)

## Tints every piece of the ghost green where it would go down and red where not (_ghost_colour), not just the first:
## a body is whatever Building.make_body() returns, a loaded scene once there is art. What it would act on keeps its
## own colour, the reach's (_reach_colour), whether or not it can go down: its ring, and its lane or patch -- which
## is the mesh itself, not something holding one, and was tinted the ghost's green with the rest (the player:
## "能攻击的范围应该显示蓝色而不是绿色").
func _tint_ghost(ok: bool) -> void:
	if build_preview == null or not is_instance_valid(build_preview):
		return
	var tint: Color = _ghost_colour(ok)
	var lanes: Node = build_preview.find_child("LanePreview", false, false)
	for mi in _meshes_in(build_preview):
		if mi != build_preview_ring and mi != lanes and (lanes == null or not lanes.is_ancestor_of(mi)):
			mi.material_override = _make_preview_material(tint)

## Lays the ghost's zone out the way the next tower will face from `snap`: the log tower's lane from its front
## edge out `lane` cells -- as far as the first thing built across its middle, as its logs will roll (LogTower) --
## and the catapult's patch at its distance.
func _show_zone(snap: Vector2i) -> void:
	var zone: MeshInstance3D = build_preview.find_child("LanePreview", false, false) as MeshInstance3D if build_preview else null
	if zone == null:
		return
	var cfg = _get_config()
	var row: Dictionary = cfg.BUILDINGS.get(current_build_type, {}) if cfg else {}
	var dir: Vector3 = AmmoTower.facing_dir(_placement_facing)
	if row.has("zone_distance"):
		zone.position = dir * float(row["zone_distance"]) + Vector3(0.0, 0.05, 0.0)
		zone.visible = true
		return
	var size: int = int(cfg.get_building_cells(current_build_type))
	var step: Vector2i = AmmoTower.FACINGS[posmod(_placement_facing, AmmoTower.FACINGS.size())]
	var first: int = (size + 1) / 2
	var run: int = 0
	for k in range(first, first + int(row.get("lane", 0))):
		var c: Vector2i = snap + step * k
		if not grid_manager.is_build_cell_ground(c):
			break
		var b: Node = grid_manager.building_in_build_cell(c)
		if b != null and not ("building_type" in b and cfg.walk_over(String(b.building_type))):
			break
		run += 1
	zone.visible = run > 0
	var length: float = float(run) * float(cfg.BUILD_CELL)
	var half: float = float(cfg.get_building_half(current_build_type).y)
	(zone.mesh as PlaneMesh).size = Vector2(float(row.get("lane_width", 1.0)), maxf(0.01, length))
	zone.rotation.y = AmmoTower.facing_yaw(_placement_facing)
	zone.position = dir * (half + length * 0.5) + Vector3(0.0, 0.04, 0.0)

## Turns the tower in hand a quarter (`step` quarters, clockwise), and the ghost and its zone with
## it, where the cursor is.
func turn_placement(step: int = 1) -> void:
	_placement_facing = posmod(_placement_facing + step, AmmoTower.FACINGS.size())
	_preview_cell = Vector2i(999999, 999999)
	if build_preview != null and is_instance_valid(build_preview) and build_preview.visible:
		_update_build_preview(get_viewport().get_mouse_position())

## Whether a building of `type_id` faces a way it acts (Config.faces): the log tower, the catapult.
func _faces(type_id: String) -> bool:
	var cfg = _get_config()
	return type_id != "" and cfg != null and cfg.has_method("faces") and bool(cfg.faces(type_id))

func _is_wall_kind(type_id: String) -> bool:
	var cfg = _get_config()
	return type_id != "" and cfg != null and cfg.has_method("get_building_kind") \
		and String(cfg.get_building_kind(type_id)) == "wall"

## Whether R turns a building of `type_id` in hand: a trap, and a wall -- a section with no wall
## beside it runs along the way it faces (Wall.runs_shown), a gate stands across it.
func _turns(type_id: String) -> bool:
	return _faces(type_id) or _is_wall_kind(type_id)

## What a tower acts on, wherever it is shown (Config.FEEDBACK.reach_color): the lane and the patch under a ghost, as its ring.
func _lane_colour() -> Color:
	return _reach_colour()

func _reach_colour() -> Color:
	var cfg = _get_config()
	if cfg and "FEEDBACK" in cfg:
		return cfg.FEEDBACK.get("reach_color", Color(0.35, 0.65, 1.0))
	return Color(0.35, 0.65, 1.0)




func _clear_build_preview() -> void:
	_restore_neighbours()
	if build_preview and is_instance_valid(build_preview):
		build_preview.queue_free()
	build_preview = null
	build_preview_mesh = null
	build_preview_ring = null
	_preview_cell = Vector2i(999999, 999999)
