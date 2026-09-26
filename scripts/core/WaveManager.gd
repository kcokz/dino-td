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
## Who the wave in progress sends, in order, popped as each one steps out (v0.6): a big
## wave is led by the map's lesser boss, and the raid on the boss's beat is followed by it.
var wave_roster: Array[String] = []
## How many times the map's boss has come on its beat (GAME-DESIGN 7.5: once, mid-game).
var boss_raids_sent: int = 0
var is_wave_active: bool = false

# v0.2 Continuous Random Raids
var raid_timer: float = 60.0
var warning_lead_time: float = 15.0
var warning_emitted: bool = false
var elapsed_time: float = 0.0
var auto_raid_enabled: bool = false

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
	set_process(true)
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

func _process(delta: float) -> void:
	if not auto_raid_enabled or is_wave_active:
		return
	var gs = _get_game_state()
	if gs and ("is_paused" in gs and gs.is_paused or "is_game_over" in gs and gs.is_game_over):
		return

	elapsed_time += delta
	raid_timer -= delta

	var eb = _get_event_bus()
	if not warning_emitted and raid_timer <= warning_lead_time and raid_timer > 0.0:
		warning_emitted = true
		if eb and eb.has_signal("raid_warning"):
			eb.raid_warning.emit(maxf(0.0, raid_timer))
		if eb and eb.has_signal("boss_warning"):
			for boss in upcoming_bosses():
				eb.boss_warning.emit(boss)

	if raid_timer <= 0.0:
		warning_emitted = false
		start_next_raid()

func _load_waves_config() -> void:
	var cfg = _get_config()
	if cfg and "WAVES" in cfg:
		var w_cfg: Dictionary = cfg.WAVES
		base_count = int(w_cfg.get("base_count", 2))
		count_per_wave = int(w_cfg.get("count_per_wave", 1))
		big_every = int(w_cfg.get("big_every", 3))
		big_multiplier = float(w_cfg.get("big_multiplier", 2.0))
		spawn_interval = float(w_cfg.get("spawn_interval", 0.8))

	raid_timer = _first_raid()
	if cfg and "RAIDS" in cfg:
		warning_lead_time = float(cfg.RAIDS.get("warning_lead_time", 15.0))

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

## Starts next raid in continuous real-time mode with dynamic intensity scaling and jitter.
func start_next_raid() -> void:
	var gs = _get_game_state()
	var next_n: int = (gs.wave_number + 1) if gs else (current_wave + 1)

	var cfg = _get_config()
	var per_min: float = 0.15
	var jitter_range: float = 0.3
	if cfg and "RAIDS" in cfg:
		per_min = float(cfg.RAIDS.get("intensity_per_minute", 0.15))
		jitter_range = float(cfg.RAIDS.get("intensity_jitter", 0.3))

	var minutes: float = elapsed_time / 60.0
	var intensity_baseline: float = 1.0 + minutes * per_min
	var jitter: float = _rng().randf_range(-jitter_range, jitter_range)
	var multiplier: float = maxf(0.5, intensity_baseline * (1.0 + jitter))

	var base_cnt: int = get_wave_dino_count(next_n)
	var final_count: int = maxi(1, int(round(float(base_cnt) * multiplier)))

	var with_boss: bool = boss_is_due()
	if with_boss:
		boss_raids_sent += 1
	start_wave(next_n, final_count, with_boss)

## Resets raid timers and state for continuous real-time mode (v0.2).
func reset_raid_state() -> void:
	elapsed_time = 0.0
	var cfg = _get_config()
	var lead_time: float = 15.0
	if cfg and "RAIDS" in cfg:
		lead_time = float(cfg.RAIDS.get("warning_lead_time", 15.0))
	raid_timer = _first_raid()
	warning_lead_time = lead_time
	warning_emitted = false
	boss_raids_sent = 0
	wave_roster.clear()

func _reset_raid_timer() -> void:
	var cfg = _get_config()
	var min_i: float = 45.0
	var max_i: float = 90.0
	if cfg and "RAIDS" in cfg:
		var r_cfg: Dictionary = cfg.RAIDS
		min_i = float(r_cfg.get("interval_min", 45.0))
		max_i = float(r_cfg.get("interval_max", 90.0))
	raid_timer = _rng().randf_range(min_i, max_i)
	warning_emitted = false

## Starts a specific wave number. Optionally accepts override_count -- the rank and
## file; a big wave's leader and the map's boss (`with_boss`) come on top of them.
func start_wave(wave_num: int, override_count: int = -1, with_boss: bool = false) -> void:
	if is_wave_active:
		if spawn_timer and is_instance_valid(spawn_timer):
			spawn_timer.stop()

	current_wave = wave_num
	wave_roster = roster_for(wave_num, override_count if override_count > 0 else get_wave_dino_count(wave_num), with_boss)
	dinos_to_spawn = wave_roster.size()
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

	if dinos_spawned_count >= dinos_to_spawn:
		if spawn_timer:
			spawn_timer.stop()

## Which species this one is: drawn from the run's map (its "raiders", by weight), with
## the run's own dice, so the same seed sends the same animals.
func _species_to_spawn() -> String:
	var raiders: Dictionary = _map().get("raiders", {})
	var total: float = 0.0
	for species in raiders:
		total += maxf(0.0, float(raiders[species]))
	if total <= 0.0:
		return "raptor"
	var roll: float = _rng().randf() * total
	for species in raiders:
		roll -= maxf(0.0, float(raiders[species]))
		if roll < 0.0:
			return String(species)
	return String(raiders.keys().back())

## Builds a dinosaur from the class its habit calls for -- a pack raptor and a
## siege theropod are different classes, and two species with the same habit share
## one outright.
func _instantiate_for_species(type_id: String) -> Node:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_dino_script_path"):
		return null
	var path: String = String(cfg.get_dino_script_path(type_id))
	if not ResourceLoader.exists(path):
		return null
	var script = load(path)
	return script.new() if script is GDScript else null

## Instantiates and provisions a single Dino entity.
func spawn_dino() -> Node:
	return _spawn_single_dino()

func _spawn_single_dino() -> Node:
	var species: String = String(wave_roster.pop_front()) if not wave_roster.is_empty() else _species_to_spawn()
	var dino: Node = _instantiate_for_species(species)
	if dino == null and dino_script:
		dino = dino_script.new()

	if dino == null:
		push_error("[WaveManager] Failed to instantiate Dino entity.")
		return null

	var gs = _get_game_state()
	var multipliers: Dictionary = gs.dino_stat_multipliers if gs else {}

	# As the species it is. This said "raptor" whatever came out of the nest -- invisible
	# while only raptors raided, and a raptor's hit points on a tyrannosaur once others did.
	if dino.has_method("setup"):
		dino.setup(species, multipliers)

	var cfg = _get_config()
	var lane_offsets: Array = cfg.DINO_LANE_OFFSETS if (cfg and "DINO_LANE_OFFSETS" in cfg) else [-0.35, 0.35, 0.0]
	var offset: float = 0.0
	if not lane_offsets.is_empty():
		offset = float(lane_offsets[dinos_spawned_count % lane_offsets.size()])
	dinos_spawned_count += 1

	if "lane_offset" in dino:
		dino.lane_offset = offset
	if "waypoints" in dino:
		dino.waypoints = waypoints.duplicate()
	if "position" in dino:
		var spawn_offset = Vector3(offset, 0.0, 0.0)
		if waypoints.size() >= 2:
			var seg: Vector3 = waypoints[1] - waypoints[0]
			seg.y = 0.0
			if seg.length_squared() > 0.001:
				var perp: Vector3 = seg.normalized().cross(Vector3.UP).normalized()
				spawn_offset = perp * offset
		dino.position = nest_spawn_position + spawn_offset

	# Add to container
	var target_parent = dinos_container if is_instance_valid(dinos_container) else self
	target_parent.add_child(dino)

	# Belt-and-suspenders: re-affirm multipliers after entering scene tree
	if dino.has_method("setup"):
		dino.setup(species, multipliers)

	var eb = _get_event_bus()
	if eb and eb.has_signal("dino_spawned"):
		eb.dino_spawned.emit(dino)
	if eb and eb.has_signal("boss_arrived") and _is_boss(species):
		eb.boss_arrived.emit(dino)

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

	if auto_raid_enabled:
		_reset_raid_timer()

# ==============================================================================
# Resolvers
# ==============================================================================

## Who a wave sends, in order: the lesser boss at the head of a big wave, `count` raiders
## drawn from the map, and -- when it is the boss's turn -- the map's boss behind them all.
func roster_for(wave_num: int, count: int, with_boss: bool = false) -> Array[String]:
	var roster: Array[String] = []
	var minor: String = String(_map().get("minor_boss", ""))
	if is_big_wave(wave_num) and _is_species(minor):
		roster.append(minor)
	for i in range(maxi(0, count)):
		roster.append(_species_to_spawn())
	var boss: String = String(_map().get("boss", ""))
	if with_boss and _is_species(boss):
		roster.append(boss)
	return roster

## Whether the next raid is the one the map's boss comes with: its beat has passed and it
## has not come yet.
func boss_is_due() -> bool:
	var beat: float = float(_map().get("beats", {}).get("boss_raid", -1.0))
	return beat >= 0.0 and elapsed_time >= beat and boss_raids_sent == 0 and _is_species(String(_map().get("boss", "")))

## The bosses the coming raid brings -- what the warning names.
func upcoming_bosses() -> Array[String]:
	var out: Array[String] = []
	var gs = _get_game_state()
	var next_n: int = (gs.wave_number + 1) if gs else (current_wave + 1)
	var minor: String = String(_map().get("minor_boss", ""))
	if is_big_wave(next_n) and _is_species(minor):
		out.append(minor)
	var boss: String = String(_map().get("boss", ""))
	if boss_is_due():
		out.append(boss)
	return out

func _is_species(species: String) -> bool:
	var cfg = _get_config()
	return species != "" and cfg != null and "DINOS" in cfg and cfg.DINOS.has(species)

func _is_boss(species: String) -> bool:
	var cfg = _get_config()
	return _is_species(species) and String(cfg.DINOS[species].get("boss", "")) != ""

## The run's map (GameState.map_data): who raids here, and when the first of them comes.
func _map() -> Dictionary:
	var gs = _get_game_state()
	if gs and gs.has_method("map_data"):
		return gs.map_data()
	var cfg = _get_config()
	return cfg.map_data() if (cfg and cfg.has_method("map_data")) else {}

## Seconds from landing to the first raid: the map's beat table (GAME-DESIGN 9.2).
func _first_raid() -> float:
	return float(_map().get("beats", {}).get("first_raid", 60.0))

## The run's dice (GameState.rng). Every chance in a raid is drawn from them, so a seed
## replays a run; the engine's global randf would have made every run unrepeatable.
var _own_rng: RandomNumberGenerator = null

func _rng() -> RandomNumberGenerator:
	var gs = _get_game_state()
	if gs and "rng" in gs and gs.rng is RandomNumberGenerator:
		return gs.rng
	if _own_rng == null:
		_own_rng = RandomNumberGenerator.new()
	return _own_rng

var config_override: Object = null

func _get_config() -> Object:
	if config_override != null:
		return config_override
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
