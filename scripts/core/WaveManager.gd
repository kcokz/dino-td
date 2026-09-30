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
## Every nest's mouth, the first the nest_spawn_position's (Main places them): a harder game has more nests
## (Config.CUSTOM_GAME "difficulty"), and a raid is shared out among them. Empty: the one nest.
@export var nest_positions: Array[Vector3] = []
@export var waypoints: Array[Vector3] = []
## Where else raiders step out, besides the nest: the map's `entries`, in the world (Main
## places them). Only the beacon's final wave uses them.
@export var entry_positions: Array[Vector3] = []
## The valley's edge behind the nest (MAPS.reinforce_from): where a raid's numbers past the nest's
## party come in (Config.RAIDS.nest_most).
@export var reinforce_positions: Array[Vector3] = []

var current_wave: int = 0
var dinos_to_spawn: int = 0
var dinos_spawned_count: int = 0
var dinos_alive_count: int = 0
## Who the wave in progress sends, in order, popped as each one steps out (v0.6): a big
## wave is led by the map's lesser boss; the beacon's final wave ends with the map's boss.
var wave_roster: Array[String] = []
var is_wave_active: bool = false
## The beacon's final wave is under way (GAME-DESIGN 8.3): from its launch to the jump there
## are no more ordinary raids, only the one stream -- see start_final_wave.
var final_wave: bool = false
## Of this raid, how many have stepped out of the nests, and whose turn it is at the edge (_next_origin) -- and
## among the nests.
var _from_nest: int = 0
var _edge_turn: int = 0
var _nest_turn: int = 0
## Whether the map's boss has come to close a rescue game (start_next_raid).
var _finale_sent: bool = false
## Whose turn among the nest and the day's other ways in the next of a raid is (ways_now).
var _way_turn: int = 0
## Whose turn it is among the valley's ways in, for what a repaired stage stirs up: kept from one
## stage's raid to the next, so each way in has its turn over the run -- the south-east's too, the
## way past the third wreck (Config.WRECKS).
var _stage_turn: int = 0

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
	# Found by what says where a raid comes from (HUD: the warning names every way in).
	add_to_group("wave_manager")
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
	var gs = _get_game_state()
	if gs and "is_game_over" in gs and gs.is_game_over:
		return
	# Launched, and the valley not answered yet: the grace counts down, and no raid sets out in it.
	if _final_countdown > 0.0:
		_final_countdown -= delta
		if gs:
			gs.final_wave_in = maxf(0.0, _final_countdown)
		if _final_countdown <= 0.0:
			_final_countdown = 0.0
			if gs:
				gs.final_wave_in = -1.0
			start_final_wave()
		return
	if not auto_raid_enabled or is_wave_active or final_wave:
		return
	# Out of the raiders' hours no raid is counted down to, and none sets out (GAME-DESIGN 9.3). One
	# warned of is called off (the HUD's count stood still at its last second all night) and warned of
	# again once they are out.
	if not raiders_out():
		if warning_emitted or _stirred_warned:
			warning_emitted = false
			_stirred_warned = false
			var eb_off = _get_event_bus()
			if eb_off and eb_off.has_signal("raid_warning"):
				eb_off.raid_warning.emit(0.0)
		return

	elapsed_time += delta
	# The raid a repaired stage stirred up, on its own clock and with its own warning -- on top of
	# the raids the clock sends (start_stage_wave). Two raids may be counting down at once: only
	# the one to come first is warned of, and a warning given before a raid that went first is
	# given again once that raid is over (debug-agent BUG-004: the stage's warning was given under
	# a big raid's, and the stage's raid came after the big one with none).
	if _stirred > 0:
		_stirred_in -= delta
		var eb_stage = _get_event_bus()
		if not _stirred_warned and _stirred_in <= _warning_lead() and _stirred_in <= raid_timer:
			_stirred_warned = true
			if eb_stage and eb_stage.has_signal("raid_warning"):
				eb_stage.raid_warning.emit(maxf(0.0, _stirred_in))
		if _stirred_in <= 0.0:
			start_stage_wave()
			return
	raid_timer -= delta

	var eb = _get_event_bus()
	var clock_first: bool = _stirred <= 0 or raid_timer < _stirred_in
	if clock_first and not warning_emitted and raid_timer <= _warning_lead() and raid_timer > 0.0:
		warning_emitted = true
		if eb and eb.has_signal("raid_warning"):
			eb.raid_warning.emit(maxf(0.0, raid_timer))
		if eb and eb.has_signal("boss_warning"):
			for boss in upcoming_bosses():
				eb.boss_warning.emit(boss)

	if raid_timer <= 0.0:
		warning_emitted = false
		start_next_raid()

## How long until the raid warned of sets out -- the first of them, the clock's or the one a stage
## stirred up -- or -1 with none warned of. The HUD counts it down (raid_line).
func warned_raid_in() -> float:
	var left: float = maxf(0.0, raid_timer) if warning_emitted else -1.0
	if _stirred > 0 and _stirred_warned and (left < 0.0 or _stirred_in < left):
		left = maxf(0.0, _stirred_in)
	return left

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
		if eb.has_signal("dino_went_home") and not eb.dino_went_home.is_connected(_on_dino_went_home):
			eb.dino_went_home.connect(_on_dino_went_home)
		if eb.has_signal("day_part_changed") and not eb.day_part_changed.is_connected(_on_day_part_changed):
			eb.day_part_changed.connect(_on_day_part_changed)
		if eb.has_signal("beacon_launched") and not eb.beacon_launched.is_connected(_on_beacon_launched):
			eb.beacon_launched.connect(_on_beacon_launched)
		if eb.has_signal("beacon_changed") and not eb.beacon_changed.is_connected(_on_beacon_changed):
			eb.beacon_changed.connect(_on_beacon_changed)

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("phase_changed") and eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.disconnect(_on_phase_changed)
		if eb.has_signal("dino_died") and eb.dino_died.is_connected(_on_dino_died):
			eb.dino_died.disconnect(_on_dino_died)
		if eb.has_signal("dino_went_home") and eb.dino_went_home.is_connected(_on_dino_went_home):
			eb.dino_went_home.disconnect(_on_dino_went_home)
		if eb.has_signal("day_part_changed") and eb.day_part_changed.is_connected(_on_day_part_changed):
			eb.day_part_changed.disconnect(_on_day_part_changed)
		if eb.has_signal("beacon_launched") and eb.beacon_launched.is_connected(_on_beacon_launched):
			eb.beacon_launched.disconnect(_on_beacon_launched)
		if eb.has_signal("beacon_changed") and eb.beacon_changed.is_connected(_on_beacon_changed):
			eb.beacon_changed.disconnect(_on_beacon_changed)

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

## Starts next raid in continuous real-time mode with dynamic intensity scaling and jitter. A game won by holding
## out for rescue (GameState.goal_kind "rescue") has no final wave: the map's boss comes with the first raid of the
## last day instead -- the last thing to hold out against.
func start_next_raid() -> void:
	var next_n: int = _next_wave_number()
	var finale: bool = _finale_due()
	if finale:
		_finale_sent = true
	start_wave(next_n, raid_size(next_n), finale)

## Whether the next raid brings a rescue game's boss: the last day come, and it not yet sent.
func _finale_due() -> bool:
	var gs = _get_game_state()
	if _finale_sent or gs == null or not gs.has_method("goal_kind") or String(gs.goal_kind()) != "rescue":
		return false
	return int(gs.rescue_days()) > 0 and int(gs.day_number()) >= int(gs.rescue_days()) \
		and _is_species(String(_map().get("boss", "")))

## The small raid repaired stages have stirred up, still to come (its size, or 0), the seconds
## till it sets out, and whether its warning has been given; and whether the raid out now is one.
var _stirred: int = 0
var _stirred_in: float = 0.0
var _stirred_warned: bool = false
var stage_wave: bool = false
## Seconds of the launch's grace left before the final wave sets out; 0 when none is counting.
var _final_countdown: float = 0.0

## A stage of the beacon repaired: its hum carries down the valley, and a small raid comes of it
## (MAPS.beacon.stage_waves), `stage_wave_delay` seconds on, with its own warning -- on top of the
## raids the clock sends (start_stage_wave). A raid out then is fought first; this one follows it.
## Two stages repaired close together stir up the two raids as one.
func _on_beacon_changed(steps_done: int) -> void:
	var gs = _get_game_state()
	var stages: int = int(gs.beacon_stage_count()) if (gs and gs.has_method("beacon_stage_count")) else 0
	if steps_done < 1 or steps_done > stages or final_wave:
		return
	var sizes: Array = _map().get("beacon", {}).get("stage_waves", [])
	if steps_done - 1 >= sizes.size():
		return
	_stirred += int(sizes[steps_done - 1])
	_stirred_in = float(_map().get("beacon", {}).get("stage_wave_delay", 20.0))
	_stirred_warned = false

## The small raid a repaired stage stirred up (debug-agent BUG-001: it stood in for the clock's
## next raid, at its own size -- so a stage repaired in a big raid's warning halved the big raid,
## and repairing the beacon eased the pressure it was meant to add). Now it comes on top: its own
## count and no leader, and the raid count, the leader's turn and the clock's next raid left
## where they were -- that one is still to come when this is over.
func start_stage_wave() -> void:
	var size: int = _stirred
	_stirred = 0
	_stirred_warned = false
	# The clock's next raid, if it was warned of already, is warned of again once this is over.
	warning_emitted = false
	if is_wave_active and spawn_timer and is_instance_valid(spawn_timer):
		spawn_timer.stop()
	stage_wave = true
	_from_nest = 0
	_edge_turn = 0
	var roster: Array[String] = []
	for i in range(maxi(0, size)):
		roster.append(_species_to_spawn())
	wave_roster = roster
	dinos_to_spawn = roster.size()
	dinos_spawned_count = 0
	dinos_alive_count = dinos_to_spawn
	is_wave_active = true
	var eb = _get_event_bus()
	if eb and eb.has_signal("wave_started"):
		eb.wave_started.emit(current_wave, false)
	if eb and eb.has_signal("stage_wave_started"):
		eb.stage_wave_started.emit(size)
	if spawn_timer:
		spawn_timer.start(spawn_interval)

## Launched: the final wave comes after the map's grace (MAPS.beacon.launch_grace), said on the
## bus and counted down in GameState.final_wave_in -- at once if there is none.
func _on_beacon_launched() -> void:
	var grace: float = float(_map().get("beacon", {}).get("launch_grace", 0.0))
	_stirred = 0
	if grace <= 0.0:
		start_final_wave()
		return
	_final_countdown = grace
	var gs = _get_game_state()
	if gs:
		gs.final_wave_in = grace
	var eb = _get_event_bus()
	if eb and eb.has_signal("final_wave_warning"):
		eb.final_wave_warning.emit(grace)

## How many raiders wave `wave_num` sends if it sets out now: its count, scaled by how far
## into the run it is (RAIDS.intensity_per_minute) and by the run's dice either way.
func raid_size(wave_num: int) -> int:
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
	# How hard the game is (CUSTOM_GAME "difficulty"): the raids that much bigger.
	var scale: float = float(gs_scale("raid_size"))
	var sized: int = maxi(1, int(round(float(get_wave_dino_count(wave_num)) * multiplier * scale)))
	# The valley holds so many (MAPS.<id>.raid_most): a raid grows to it and no further.
	var most: int = int(_map().get("raid_most", 0))
	return mini(sized, most) if most > 0 else sized

## The beacon's final wave (GAME-DESIGN 8.3), set out when it is launched: the whole valley
## comes for the cabin, and keeps coming until the jump.
##
## ONE wave for the whole charge, streamed rather than sent: `final_raids` ordinary raids'
## worth, sized as a raid would be now -- so putting the launch off makes the end harder --
## stepping out one after another, with no gaps, over the first `stream_share` of the
## charge. Each takes the next way out in turn, the nest and then every entry of the map,
## so the base the player built facing the nest needs a back as well. The map's boss is
## last of all, and the share left over is its time to arrive: the finale is a fight.
##
## A raid still under way is folded in rather than dropped -- whoever is already out keeps
## counting towards the wave; whoever had not stepped out yet is part of the stream now.
func start_final_wave() -> void:
	if final_wave:
		return
	var beacon: Dictionary = _map().get("beacon", {})
	var still_out: int = 0
	if is_wave_active:
		still_out = maxi(0, dinos_alive_count - (dinos_to_spawn - dinos_spawned_count))
	var next_n: int = _next_wave_number()
	var count: int = maxi(1, int(round(float(raid_size(next_n)) * float(beacon.get("final_raids", 1.0)))))
	final_wave = true
	start_wave(next_n, count, true)
	dinos_alive_count += still_out
	# Over the charge that is left once the grace is out (launch_grace), so the boss, last, still
	# has its time to reach the cabin before the jump.
	var fight: float = maxf(0.0, float(beacon.get("charge_seconds", 0.0)) - float(beacon.get("launch_grace", 0.0)))
	var stream: float = fight * float(beacon.get("stream_share", 1.0))
	if spawn_timer and stream > 0.0:
		spawn_timer.start(maxf(0.05, stream / float(maxi(1, dinos_to_spawn))))

## Where the next of this raid steps out, and whether that is the valley's edge: the nest for the
## first of it (Config.RAIDS.nest_most) -- a hunting party of the nest, not all of it -- and the rest
## from the edge, in turn: behind the nest (reinforce_positions), and in the beacon's final wave every
## edge (entry_positions too). v0.6 round four, the player: "我认为巢穴不应该出来太多，如果需要很多恐龙，
## 比如信标恐龙就应该来自边界".
##
## And nothing steps out where he can see it (v0.6 round four: "raid的时候直接冒出新的恐龙似乎有点奇
## 怪"): the nest watched, its party comes in from the edge behind it instead; a way in at the edge
## watched, the next one nobody sees; every way in behind the nest watched, it comes round by the
## valley's other ways in (entry_positions) -- in the small valley the edge is two metres behind the
## nest, and standing before the nest he saw all of it, and a raid stepped out in front of him anyway
## (the debug-agent's BUG-014). With every way in watched it waits, unseen, for one not to be: [] --
## nothing steps out this time (_on_spawn_timer_timeout tries again).
func _next_origin() -> Array:
	# What a repaired stage stirs up comes in from the valley's ends, not out of the nest: its hum
	# carries down the valley and what answers it comes by the ways in (MAPS.entries; the player:
	# "信标恐龙就应该来自边界"), each in turn, none that is watched.
	if stage_wave and not final_wave:
		for k in entry_positions.size():
			var way_in: Vector3 = entry_positions[(_stage_turn + k) % entry_positions.size()]
			if not _watched(way_in):
				_stage_turn += k + 1
				return [way_in, true]
	# More ways in as the days go (MAPS.<id>.ways_by_day): the raid shared out between the nest and each of
	# them in turn -- one from the nest, one from the east, and so on; a way that is watched gives its turn to
	# the nest's.
	if not final_wave and not stage_wave:
		var ways: Array[String] = ways_now()
		if not ways.is_empty():
			var turn: int = _way_turn % (ways.size() + 1)
			_way_turn += 1
			if turn > 0:
				var way_in: Vector3 = entry_toward(ways[turn - 1])
				if way_in != Vector3.INF and not _watched(way_in):
					return [way_in, true]
	var edges: Array[Vector3] = edge_origins()
	var mouths: Array[Vector3] = nests()
	if _from_nest < _nest_most() * mouths.size():
		for k in mouths.size():
			var mouth: Vector3 = mouths[(_nest_turn + k) % mouths.size()]
			if edges.is_empty() or not _watched(mouth):
				_nest_turn += k + 1
				_from_nest += 1
				return [mouth, false]
	for k in edges.size():
		var at: Vector3 = edges[(_edge_turn + k) % edges.size()]
		if not _watched(at):
			_edge_turn += k + 1
			return [at, true]
	for k in entry_positions.size():
		var at: Vector3 = entry_positions[(_edge_turn + k) % entry_positions.size()]
		if not edges.has(at) and not _watched(at):
			_edge_turn += k + 1
			return [at, true]
	return []

## Whether the Hero or his buildings see `at` now (FogOfWar.sees).
func _watched(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var fog: Node = get_tree().get_first_node_in_group(FogOfWar.GROUP)
	return fog != null and fog.has_method("sees") and bool(fog.sees(at))

## Every edge a raider of this raid may come in from: behind the nest, and in the final wave every
## way into the valley.
func edge_origins() -> Array[Vector3]:
	var out: Array[Vector3] = reinforce_positions.duplicate()
	if final_wave:
		out.append_array(entry_positions)
	return out

## Every nest's mouth: the one nest's, or all a harder game has (nest_positions).
func nests() -> Array[Vector3]:
	if nest_positions.is_empty():
		return [nest_spawn_position]
	return nest_positions

## The nest nearest `at` -- the one a raider goes home to.
func nearest_nest(at: Vector3) -> Vector3:
	var best: Vector3 = nest_spawn_position
	var best_d: float = INF
	for mouth in nests():
		var d: float = Vector2(mouth.x - at.x, mouth.z - at.z).length()
		if d < best_d:
			best_d = d
			best = mouth
	return best

## One of this run's multipliers (GameState.run_scale; CUSTOM_GAME "scale"), 1 without a GameState.
func gs_scale(key: String) -> float:
	var gs = _get_game_state()
	return float(gs.run_scale(key)) if (gs and gs.has_method("run_scale")) else 1.0

func _nest_most() -> int:
	var cfg = _get_config()
	return int(cfg.RAIDS.get("nest_most", 5)) if (cfg and "RAIDS" in cfg) else 5

func _next_wave_number() -> int:
	var gs = _get_game_state()
	return (gs.wave_number + 1) if gs else (current_wave + 1)

## Resets raid timers and state for continuous real-time mode (v0.2).
func reset_raid_state() -> void:
	elapsed_time = 0.0
	final_wave = false
	_stirred = 0
	_stirred_in = 0.0
	_stirred_warned = false
	stage_wave = false
	_final_countdown = 0.0
	_from_nest = 0
	_edge_turn = 0
	_nest_turn = 0
	_finale_sent = false
	_stage_turn = 0
	var cfg = _get_config()
	var lead_time: float = 15.0
	if cfg and "RAIDS" in cfg:
		lead_time = float(cfg.RAIDS.get("warning_lead_time", 15.0))
	raid_timer = _first_raid()
	warning_lead_time = lead_time
	warning_emitted = false
	wave_roster.clear()

func _reset_raid_timer() -> void:
	var cfg = _get_config()
	var min_i: float = 45.0
	var max_i: float = 90.0
	if cfg and "RAIDS" in cfg:
		var r_cfg: Dictionary = cfg.RAIDS
		min_i = float(r_cfg.get("interval_min", 45.0))
		max_i = float(r_cfg.get("interval_max", 90.0))
	# And that much oftener, or seldomer (CUSTOM_GAME "difficulty").
	raid_timer = _rng().randf_range(min_i, max_i) * float(gs_scale("raid_interval"))
	warning_emitted = false

## Starts a specific wave number. Optionally accepts override_count -- the rank and
## file; a big wave's leader and the map's boss (`with_boss`) come on top of them.
func start_wave(wave_num: int, override_count: int = -1, with_boss: bool = false) -> void:
	if is_wave_active:
		if spawn_timer and is_instance_valid(spawn_timer):
			spawn_timer.stop()

	current_wave = wave_num
	_from_nest = 0
	_edge_turn = 0
	_way_turn = 0
	# A stage's raid still to come is warned of again once this one is over (_process).
	_stirred_warned = false
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
	# Nobody steps out once the run is over. The beacon's final wave is still streaming out
	# at the jump by design, and would have gone on filling the valley behind the result.
	var gs = _get_game_state()
	if not is_wave_active or (gs and "is_game_over" in gs and gs.is_game_over):
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
	var raiders: Dictionary = _raiders_now()
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

## Who raids now: the map's raiders, or the latest of its raiders_by_day begun (GameState.day_number) --
## from the third day on the valley's, a runner for every three of the pack.
func _raiders_now() -> Dictionary:
	var out: Dictionary = _map().get("raiders", {})
	var best_day: int = -1
	var day: int = _day_now()
	for step in _map().get("raiders_by_day", []):
		var from_day: int = int(step.get("from_day", 1))
		if from_day <= day and from_day > best_day:
			best_day = from_day
			out = step.get("raiders", out)
	return out

## The ways in, other than the nest's, that raids come by now (MAPS.<id>.ways_by_day): points of the
## compass, the latest begun.
func ways_now() -> Array[String]:
	var out: Array[String] = []
	var best_day: int = -1
	var day: int = _day_now()
	for step in _map().get("ways_by_day", []):
		var from_day: int = int(step.get("from_day", 1))
		if from_day <= day and from_day > best_day:
			best_day = from_day
			out.clear()
			for w in step.get("ways", []):
				out.append(String(w))
	return out

func _day_now() -> int:
	var gs = _get_game_state()
	return int(gs.day_number()) if (gs and gs.has_method("day_number")) else 1

## The way into the valley (entry_positions) that lies most toward `side` from the cabin ("E", "S", ...).
## Whether a party can come in by the way into the valley on `side` now: there is one, and nobody sees it --
## a way that is watched gives its turn to the nest's (_next_origin).
func way_open(side: String) -> bool:
	var at: Vector3 = entry_toward(side)
	return at != Vector3.INF and not _watched(at)

func entry_toward(side: String) -> Vector3:
	var dirs: Dictionary = {"N": Vector2(0.0, -1.0), "NE": Vector2(1.0, -1.0), "E": Vector2(1.0, 0.0), "SE": Vector2(1.0, 1.0),
		"S": Vector2(0.0, 1.0), "SW": Vector2(-1.0, 1.0), "W": Vector2(-1.0, 0.0), "NW": Vector2(-1.0, -1.0)}
	var want: Vector2 = (dirs.get(side, Vector2.ZERO) as Vector2).normalized()
	var core: Node3D = get_tree().get_first_node_in_group("core") as Node3D if is_inside_tree() else null
	var from: Vector3 = core.global_position if core != null else Vector3.ZERO
	var best: Vector3 = Vector3.INF
	var best_dot: float = -INF
	for at in entry_positions:
		var d := Vector2(at.x - from.x, at.z - from.z)
		if d.length() < 0.01:
			continue
		var dot: float = d.normalized().dot(want)
		if dot > best_dot:
			best_dot = dot
			best = at
	return best

## Which way a raider came in, as the bug report says it (Dino.came_from): out of the nest, from the edge
## behind it, or by the way into the valley on that side of the cabin.
func origin_name(at: Vector3, from_the_edge: bool) -> String:
	if not from_the_edge:
		return "nest"
	if reinforce_positions.has(at):
		return "behind the nest"
	return "edge " + side_of(at)

## The side of the cabin `at` is on, by the compass -- N, NE, E ... as entry_toward reads them (north is -z).
func side_of(at: Vector3) -> String:
	var core: Node3D = get_tree().get_first_node_in_group("core") as Node3D if is_inside_tree() else null
	var from: Vector3 = core.global_position if core != null else Vector3.ZERO
	var d := Vector2(at.x - from.x, at.z - from.z)
	if d.length() < 0.01:
		return "here"
	var sides: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	return sides[wrapi(roundi(d.angle() / (PI / 4.0)), 0, 8)]

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
	# Out of the nest and down the path -- or, past the nest's party, in from the valley's edge,
	# straight for the cabin at the path's end (hills are steered round: Dino._steer_target),
	# hurrying while nobody sees it (Dino.hurry_in). Every way in watched, none steps out yet.
	var next: Array = _next_origin()
	if next.is_empty():
		return null
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

	var origin: Vector3 = next[0]
	var from_the_edge: bool = bool(next[1])
	if "came_from" in dino:
		dino.came_from = origin_name(origin, from_the_edge)
	var route: Array[Vector3] = waypoints.duplicate()
	# The path runs from the first nest; out of another, or in from the edge, it is straight for its end.
	if (from_the_edge or origin != nest_spawn_position) and not waypoints.is_empty():
		route = [origin, waypoints.back()]
	if from_the_edge and dino.has_method("hurry_in"):
		dino.hurry_in(float(cfg.RAIDS.get("edge_hurry", 1.0)) if (cfg and "RAIDS" in cfg) else 1.0)
	if "lane_offset" in dino:
		dino.lane_offset = offset
	if "waypoints" in dino:
		dino.waypoints = route
	if "position" in dino:
		var spawn_offset = Vector3(offset, 0.0, 0.0)
		if route.size() >= 2:
			var seg: Vector3 = route[1] - route[0]
			seg.y = 0.0
			if seg.length_squared() > 0.001:
				var perp: Vector3 = seg.normalized().cross(Vector3.UP).normalized()
				spawn_offset = perp * offset
		dino.position = origin + spawn_offset

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
	# Only the raid's own: a nest's guard killed in the middle of a raid, or a night's hunter (NightProwl),
	# is not one of it -- and was counted off it, so a raid could be over with its animals still out.
	if _dino != null and is_instance_valid(_dino) and (_dino.is_in_group("guard_dinos") or _dino.is_in_group("prowlers") \
			or _dino.is_in_group("drawn")):
		return

	dinos_alive_count = maxi(0, dinos_alive_count - 1)
	_check_wave_completion()

## One of the raid back at the nest, its hours over: out of the raid as one killed is, with
## nothing left behind.
func _on_dino_went_home(dino: Node) -> void:
	_on_dino_died(dino)

## How long before a raid sets out it is warned of: RAIDS.warning_lead_time, and longer once the
## nest is found -- its setting out is seen (Config.FOG.found_nest_warning, GAME-DESIGN 9.3).
func _warning_lead() -> float:
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs and "nest_found" in gs and bool(gs.nest_found) and cfg and "FOG" in cfg:
		return warning_lead_time + float(cfg.FOG.get("found_nest_warning", 0.0))
	return warning_lead_time

## Whether the map's raiders keep this hour (Config.DINOS.<id>.hours, GAME-DESIGN 9.3): a raid sets
## out, and is counted down to, only in the hours one of them keeps. Coelophysis hunted by day, so
## the first map's raids come by day, and none in the dusk or the night.
func raiders_out() -> bool:
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs == null or not gs.has_method("day_part") or cfg == null or not cfg.has_method("keeps_hours"):
		return true
	var part: String = String(gs.day_part())
	for species in _map().get("raiders", {}):
		if cfg.keeps_hours(String(species), part):
			return true
	return false

## A part of the day begun: the raiders whose hours are over go home, the raid out and all -- at
## dusk the Coelophysis go back to their nest (GAME-DESIGN 9.3) -- and those of the raid still in
## the nest stay there (_keep_to_hours). Not the beacon's last wave: the valley was woken for it.
func _on_day_part_changed(part: String, _day: int) -> void:
	var cfg = _get_config()
	if final_wave or cfg == null or not cfg.has_method("keeps_hours") or not is_inside_tree():
		return
	for d in get_tree().get_nodes_in_group("dinos"):
		if not is_instance_valid(d) or d.is_in_group("guard_dinos") or d.is_in_group("prowlers") or not d.has_method("go_home"):
			continue
		if not cfg.keeps_hours(String(d.dino_type), part):
			d.go_home(nearest_nest((d as Node3D).global_position))
	if is_wave_active:
		_keep_to_hours(part)

## The raid's animals still in the nest whose hours are over do not step out (debug-agent BUG-006:
## a raid setting out just before dusk went on stepping out after it, one every spawn_interval, and
## those came for the cabin into the night -- 100 down to 2.8). They are taken off the roster and
## out of the raid's count, which may be the end of it: it is over when the last one out is home.
func _keep_to_hours(part: String) -> void:
	var cfg = _get_config()
	var left: Array[String] = []
	for species in wave_roster:
		if cfg.keeps_hours(String(species), part):
			left.append(String(species))
	var kept_in: int = wave_roster.size() - left.size()
	if kept_in <= 0:
		return
	wave_roster = left
	dinos_to_spawn -= kept_in
	dinos_alive_count = maxi(0, dinos_alive_count - kept_in)
	if dinos_spawned_count >= dinos_to_spawn and spawn_timer and is_instance_valid(spawn_timer):
		spawn_timer.stop()
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

	var was_stage: bool = stage_wave
	stage_wave = false
	var eb = _get_event_bus()
	if eb and eb.has_signal("wave_ended"):
		eb.wave_ended.emit(current_wave)

	# After a raid of the clock's the next is drawn afresh; after a stage's, the clock's next raid
	# is where it was, and still to come.
	if auto_raid_enabled and not was_stage:
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

## The bosses the coming raid brings -- what the warning names: the lesser one, at the head of
## a big wave. The map's boss comes with no raid: it is seen once, last of all in the beacon's
## final wave (GAME-DESIGN 7.5; v0.6 round three: "中段的小boss不应该把最后的大boss形象暴露").
func upcoming_bosses() -> Array[String]:
	var out: Array[String] = []
	var gs = _get_game_state()
	var next_n: int = (gs.wave_number + 1) if gs else (current_wave + 1)
	var minor: String = String(_map().get("minor_boss", ""))
	if is_big_wave(next_n) and _is_species(minor):
		out.append(minor)
	if _finale_due():
		out.append(String(_map().get("boss", "")))
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
