# res://scripts/core/WaveManager.gd
class_name WaveManager
extends Node3D

## Wave Manager for Defend Dinosaur v0.0.
## Controls wave progression, sequential dinosaur spawning, and wave completion tracking.
## Coordinates with GameState and EventBus.

# ==============================================================================
# Configuration & State
# ==============================================================================
@export var spawn_interval: float = 0.8
@export var base_count: int = 2
@export var count_per_wave: int = 1
@export var big_every: int = 3
@export var big_multiplier: float = 2.0
@export var nest_spawn_position: Vector3 = Vector3.ZERO
@export var waypoints: Array[Vector3] = []

var current_wave: int = 0
var dinos_to_spawn: int = 0
var dinos_spawned_count: int = 0
var dinos_alive_count: int = 0
var is_wave_active: bool = false

# Compatibility alias for tests
var dinos_alive: int:
	get: return dinos_alive_count
	set(v): dinos_alive_count = v

# Containers & Nodes
var spawn_timer: Timer = null
var dinos_container: Node = null
var dino_script: GDScript = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	_load_waves_config()

func _ready() -> void:
	_load_waves_config()
	_ensure_components()
	_connect_event_bus()

func _exit_tree() -> void:
	_disconnect_event_bus()
	if spawn_timer and is_instance_valid(spawn_timer):
		spawn_timer.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_event_bus()
		if spawn_timer and is_instance_valid(spawn_timer):
			spawn_timer.stop()

func _load_waves_config() -> void:
	var cfg = _get_config()
	if cfg and "WAVES" in cfg:
		var w_cfg: Dictionary = cfg.WAVES
		base_count = int(w_cfg.get("base_count", 2))
		count_per_wave = int(w_cfg.get("count_per_wave", 1))
		big_every = int(w_cfg.get("big_every", 3))
		big_multiplier = float(w_cfg.get("big_multiplier", 2.0))
		spawn_interval = float(w_cfg.get("spawn_interval", 0.8))

	if spawn_timer:
		spawn_timer.wait_time = spawn_interval

func _ensure_components() -> void:
	# 1. Spawn Timer
	for child in get_children():
		if child is Timer and child.name == "SpawnTimer":
			spawn_timer = child
			break
	if spawn_timer == null:
		spawn_timer = Timer.new()
		spawn_timer.name = "SpawnTimer"
		spawn_timer.wait_time = spawn_interval
		spawn_timer.one_shot = false
		spawn_timer.autostart = false
		add_child(spawn_timer)
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# 2. Dinos container
	if dinos_container == null:
		if is_inside_tree():
			var root_main = get_tree().root.get_node_or_null("Main")
			if root_main and root_main.has_node("Dinos"):
				dinos_container = root_main.get_node("Dinos")
		if dinos_container == null:
			dinos_container = self

	# 3. Dino script loader
	if dino_script == null and ResourceLoader.exists("res://scripts/entities/Dino.gd"):
		dino_script = load("res://scripts/entities/Dino.gd")

	# 4. Resolve Waypoints if empty
	if waypoints.is_empty() and is_inside_tree():
		_discover_scene_waypoints()

func _discover_scene_waypoints() -> void:
	var root_main = get_tree().root.get_node_or_null("Main")
	if root_main and root_main.has_node("Map/Path"):
		var path_node = root_main.get_node("Map/Path")
		var pts: Array[Vector3] = []
		for child in path_node.get_children():
			if child is Marker3D:
				pts.append(child.global_position)
		if not pts.is_empty():
			waypoints = pts

	if nest_spawn_position == Vector3.ZERO and root_main and root_main.has_node("Map/NestSpawn"):
		nest_spawn_position = root_main.get_node("Map/NestSpawn").global_position

# ==============================================================================
# Signal Connections (EventBus)
# ==============================================================================

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb:
		if eb.has_signal("phase_changed") and not eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.connect(_on_phase_changed)
		if eb.has_signal("dino_died") and not eb.dino_died.is_connected(_on_dino_died):
			eb.dino_died.connect(_on_dino_died)

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("phase_changed") and eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.disconnect(_on_phase_changed)
		if eb.has_signal("dino_died") and eb.dino_died.is_connected(_on_dino_died):
			eb.dino_died.disconnect(_on_dino_died)

func _on_phase_changed(phase: int) -> void:
	# Phase 1 == ATTACK
	if phase == 1:
		start_next_wave()

# ==============================================================================
# Wave Calculations
# ==============================================================================

func get_wave_count(wave_num: int) -> int:
	return get_wave_dino_count(wave_num)

func calculate_wave_dinos(wave_num: int) -> int:
	return get_wave_dino_count(wave_num)

## Calculates total dinosaur count for wave wave_num.
func get_wave_dino_count(wave_num: int) -> int:
	var w: int = maxi(1, wave_num)
	var base: int = base_count + (w - 1) * count_per_wave
	if is_big_wave(w):
		return int(floor(float(base) * big_multiplier))
	return base

## Checks if wave wave_num triggers horde multiplier.
func is_big_wave(wave_num: int) -> bool:
	return (big_every > 0) and (wave_num > 0) and (wave_num % big_every == 0)

# ==============================================================================
# Wave Execution & Spawning
# ==============================================================================

## Starts next wave derived from GameState or internal counter.
func start_next_wave() -> void:
	var gs = _get_game_state()
	var next_n: int = (gs.wave_number + 1) if gs else (current_wave + 1)
	start_wave(next_n)

## Starts a specific wave number.
func start_wave(wave_num: int) -> void:
	if is_wave_active:
		if spawn_timer and is_instance_valid(spawn_timer):
			spawn_timer.stop()

	current_wave = wave_num
	dinos_to_spawn = get_wave_dino_count(current_wave)
	dinos_spawned_count = 0
	dinos_alive_count = dinos_to_spawn
	is_wave_active = true

	var is_big: bool = is_big_wave(current_wave)

	var eb = _get_event_bus()
	if eb and eb.has_signal("wave_started"):
		eb.wave_started.emit(current_wave, is_big)

	if spawn_timer:
		spawn_timer.start(spawn_interval)

func _on_spawn_timer_timeout() -> void:
	if not is_wave_active:
		if spawn_timer:
			spawn_timer.stop()
		return

	if dinos_spawned_count < dinos_to_spawn:
		_spawn_single_dino()
		dinos_spawned_count += 1

	if dinos_spawned_count >= dinos_to_spawn:
		if spawn_timer:
			spawn_timer.stop()

## Instantiates and provisions a single Dino entity.
func spawn_dino() -> Node:
	return _spawn_single_dino()

func _spawn_single_dino() -> Node:
	var dino: Node = null
	if dino_script:
		dino = dino_script.new()
	elif ResourceLoader.exists("res://scripts/entities/Dino.gd"):
		dino_script = load("res://scripts/entities/Dino.gd")
		dino = dino_script.new()

	if dino == null:
		push_error("[WaveManager] Failed to instantiate Dino entity.")
		return null

	var gs = _get_game_state()
	var multipliers: Dictionary = gs.dino_stat_multipliers if gs else {}

	if dino.has_method("setup"):
		dino.setup("raptor", multipliers)
	if "waypoints" in dino:
		dino.waypoints = waypoints.duplicate()
	if "position" in dino:
		dino.position = nest_spawn_position

	# Add to container
	var target_parent = dinos_container if is_instance_valid(dinos_container) else self
	target_parent.add_child(dino)

	# Belt-and-suspenders: re-affirm multipliers after entering scene tree
	if dino.has_method("setup"):
		dino.setup("raptor", multipliers)

	var eb = _get_event_bus()
	if eb and eb.has_signal("dino_spawned"):
		eb.dino_spawned.emit(dino)

	return dino

# ==============================================================================
# Completion Tracking
# ==============================================================================

func _on_dino_died(_dino: Node) -> void:
	if not is_wave_active:
		return

	dinos_alive_count = maxi(0, dinos_alive_count - 1)
	_check_wave_completion()

func _check_wave_completion() -> void:
	if dinos_alive_count <= 0:
		_end_wave()

func _end_wave() -> void:
	if not is_wave_active:
		return
	is_wave_active = false

	if spawn_timer and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	var eb = _get_event_bus()
	if eb and eb.has_signal("wave_ended"):
		eb.wave_ended.emit(current_wave)

# ==============================================================================
# Resolvers
# ==============================================================================

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

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
