# res://scripts/autoload/GameState.gd
extends Node

## Authoritative Runtime Game State & Turn State Machine for Defend Dinosaur v0.0
## Manages phases, AP pool, resource inventory, wave tracking, and transaction safety.

# ==============================================================================
# 1. Enums & State Definitions
# ==============================================================================
enum Phase {
	DEPLOY = 0,
	PLAN = 0,
	ATTACK = 1,
	PRODUCE = 2
}

# ==============================================================================
# 2. Canonical State Variables
# ==============================================================================
var current_phase: Phase = Phase.DEPLOY

## v0.2 runs as one continuous real-time state: there is no deploy countdown and no
## attack/produce phase to switch into, so the phase stays pinned at DEPLOY and every
## legacy `current_phase` guard becomes a no-op. The legacy turn machine is kept intact
## behind this flag so the v0.0/v0.1 suites can still drive it explicitly.
var continuous_mode: bool = false
var current_ap: int = 3
var max_ap: int = 3
var resources: Dictionary = {}
var wave_number: int = 0
var dino_stat_multipliers: Dictionary = {}
var is_game_over: bool = false
var is_game_won: bool = false
var nests_alive: int = 1
var active_buildings: Array[Node] = []
var _produce_timer: Timer = null

# v0.1 Real-Time Deployment & Pause & Infinite AP
var deploy_length: float = 90.0
var remaining_deploy_time: float = 90.0
var is_paused: bool = false
var infinite_ap: bool = false

# ==============================================================================
# 3. Compatibility Aliases (Ensures 100% interoperability with specs & tests)
# ==============================================================================
var ap: int:
	get: return current_ap
	set(v): current_ap = v

var ap_max: int:
	get: return max_ap
	set(v): max_ap = v

var wave_n: int:
	get: return wave_number
	set(v): wave_number = v

var dino_multipliers: Dictionary:
	get: return dino_stat_multipliers
	set(v): dino_stat_multipliers = v

# ==============================================================================
# 4. Engine Lifecycle
# ==============================================================================
func _init() -> void:
	resources = _default_resources()
	dino_stat_multipliers = {"hp": 1.0, "damage": 1.0, "speed": 1.0}
	current_ap = 3
	max_ap = 3
	is_game_over = false
	is_game_won = false
	deploy_length = 90.0
	remaining_deploy_time = 90.0
	is_paused = false

func _ready() -> void:
	set_process(true)
	_connect_event_bus()
	reset_game()
	print("[GameState] Initialized. Phase: %s, AP: %d/%d, Deploy: %.1fs, Resources: %s" % [
		Phase.keys()[current_phase], current_ap, max_ap, remaining_deploy_time, str(resources)
	])

func _process(delta: float) -> void:
	if is_game_over:
		return
	if continuous_mode:
		return
	if current_phase == Phase.DEPLOY:
		if not is_paused:
			remaining_deploy_time = maxf(0.0, remaining_deploy_time - delta)
			var eb = _get_event_bus()
			if eb and eb.has_signal("deploy_time_changed"):
				eb.deploy_time_changed.emit(remaining_deploy_time, deploy_length)
			if remaining_deploy_time <= 0.0:
				advance_phase()

# ==============================================================================
# 5. Internal Node Resolvers & Signal Helpers
# ==============================================================================
func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	return null

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb:
		if eb.has_signal("wave_started") and not eb.wave_started.is_connected(_on_wave_started):
			eb.wave_started.connect(_on_wave_started)
		if eb.has_signal("wave_ended") and not eb.wave_ended.is_connected(_on_wave_ended):
			eb.wave_ended.connect(_on_wave_ended)
		if eb.has_signal("nest_destroyed") and not eb.nest_destroyed.is_connected(_on_nest_destroyed):
			eb.nest_destroyed.connect(_on_nest_destroyed)
		if eb.has_signal("game_won") and not eb.game_won.is_connected(_on_game_won):
			eb.game_won.connect(_on_game_won)
		if eb.has_signal("game_lost") and not eb.game_lost.is_connected(_on_game_lost):
			eb.game_lost.connect(_on_game_lost)
		if eb.has_signal("building_placed") and not eb.building_placed.is_connected(register_building):
			eb.building_placed.connect(register_building)
		if eb.has_signal("building_destroyed") and not eb.building_destroyed.is_connected(unregister_building):
			eb.building_destroyed.connect(unregister_building)
		if eb.has_signal("hero_died") and not eb.hero_died.is_connected(_on_hero_died):
			eb.hero_died.connect(_on_hero_died)

func _emit_phase_changed(phase_val: int) -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("phase_changed"):
		eb.phase_changed.emit(phase_val)

func _emit_ap_changed(cur: int, max_val: int) -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("ap_changed"):
		eb.ap_changed.emit(cur, max_val)

func _emit_resources_changed(res_dict: Dictionary) -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("resources_changed"):
		eb.resources_changed.emit(res_dict)

func _emit_produce_phase() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("produce_phase"):
		eb.produce_phase.emit()

func _emit_game_won() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("game_won"):
		eb.game_won.emit()

func _emit_game_lost() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("game_lost"):
		eb.game_lost.emit()

# ==============================================================================
# 6. Game Lifecycle & Full Reset
# ==============================================================================
## Fully restores pristine starting game state from Config constants.
func reset_game() -> void:
	_cancel_produce_timer()
	is_game_over = false
	is_game_won = false
	infinite_ap = false
	# GameState is an autoload, so this flag would otherwise leak from any test that
	# instantiates Main into every test that runs after it. Main re-enables it in
	# setup_level(), which runs after reset_game() on the restart path.
	continuous_mode = false
	current_phase = Phase.PLAN
	var cfg = _get_config()
	if cfg:
		max_ap = cfg.get("BASE_AP") if "BASE_AP" in cfg else 3
		resources = cfg.get("INITIAL_RESOURCES").duplicate(true) if "INITIAL_RESOURCES" in cfg else _default_resources()
		dino_stat_multipliers = cfg.get("INITIAL_DINO_MULTIPLIERS").duplicate(true) if "INITIAL_DINO_MULTIPLIERS" in cfg else {"hp": 1.0, "damage": 1.0, "speed": 1.0}
		nests_alive = cfg.get("INITIAL_NESTS_ALIVE") if "INITIAL_NESTS_ALIVE" in cfg else 1
	else:
		max_ap = 3
		resources = _default_resources()
		dino_stat_multipliers = {"hp": 1.0, "damage": 1.0, "speed": 1.0}
		nests_alive = 1
	current_ap = max_ap
	wave_number = 0
	active_buildings.clear()
	
	var time_cfg: Dictionary = cfg.get("TIME") if (cfg and "TIME" in cfg and cfg.TIME is Dictionary) else {}
	deploy_length = float(time_cfg.get("deploy_length", 90.0))
	remaining_deploy_time = deploy_length
	is_paused = false
	
	_emit_phase_changed(current_phase)
	_emit_ap_changed(current_ap, max_ap)
	_emit_resources_changed(resources)
	var eb = _get_event_bus()
	if eb and eb.has_signal("deploy_time_changed"):
		eb.deploy_time_changed.emit(remaining_deploy_time, deploy_length)

## Alias for reset_game to initialize play.
func start_game() -> void:
	reset_game()

# ==============================================================================
# 7. Resource Inventory Transactions
# ==============================================================================
## Checks whether inventory contains sufficient resources for given cost dictionary.
func can_afford(cost: Dictionary) -> bool:
	if is_game_over:
		return false
	for res_id in cost:
		if not resources.has(res_id):
			return false
		var val = cost[res_id]
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_FLOAT:
			return false
		var required: int = int(val)
		if required < 0:
			return false
		if resources.get(res_id, 0) < required:
			return false
	return true

## Semantic alias for can_afford.
func has_resources(cost: Dictionary) -> bool:
	return can_afford(cost)

## Atomically deducts cost from resources if affordable. Returns true on success.
func spend_resources(cost: Dictionary) -> bool:
	if is_game_over or not can_afford(cost):
		return false
	for res_id in cost:
		if resources.has(res_id):
			resources[res_id] -= int(cost[res_id])
	_emit_resources_changed(resources)
	return true

## Deposits earned resources into player inventory and broadcasts update.
func add_resources(gains: Dictionary) -> void:
	for res_id in gains:
		if not resources.has(res_id):
			continue
		var val = gains[res_id]
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_FLOAT:
			continue
		var amount: int = int(val)
		if amount > 0:
			resources[res_id] = resources[res_id] + amount
	_emit_resources_changed(resources)

## Adds a single resource by name.
func add_resource(res_id: String, amount: int) -> void:
	add_resources({res_id: amount})


# ==============================================================================
# 8. Action Point (AP) Transactions & Capacity
# ==============================================================================
## Checks whether player has at least amount AP available.
func can_spend_ap(amount: int) -> bool:
	if is_game_over:
		return false
	if infinite_ap:
		return true
	return amount >= 0 and current_ap >= amount

## Deducts AP if sufficient. Returns true on success, false otherwise.
func spend_ap(amount: int) -> bool:
	if not can_spend_ap(amount):
		return false
	if infinite_ap:
		return true
	current_ap -= amount
	_emit_ap_changed(current_ap, max_ap)
	return true

## Resets current AP to max_ap (typically called entering PLAN phase).
func reset_ap() -> void:
	current_ap = max_ap
	_emit_ap_changed(current_ap, max_ap)

## Recalculates max_ap by summing Config.BASE_AP and living building ap_bonuses.
func recalculate_max_ap() -> void:
	var bonus: int = 0
	var valid_buildings: Array[Node] = []
	for b in active_buildings:
		if is_instance_valid(b):
			valid_buildings.append(b)
			if "ap_bonus" in b:
				bonus += int(b.ap_bonus)
	active_buildings = valid_buildings
	var cfg = _get_config()
	var base_ap: int = cfg.get("BASE_AP") if (cfg and "BASE_AP" in cfg) else 3
	max_ap = maxi(1, base_ap + bonus)
	current_ap = mini(current_ap, max_ap)
	_emit_ap_changed(current_ap, max_ap)

## Tracks an instantiated building for capacity and lifecycle management.
func register_building(building: Node) -> void:
	if building and not active_buildings.has(building):
		active_buildings.append(building)
		recalculate_max_ap()

## Untracks a destroyed building.
func unregister_building(building: Node) -> void:
	if building and active_buildings.has(building):
		active_buildings.erase(building)
		recalculate_max_ap()

# ==============================================================================
# 9. Turn State Machine & Phase Transitions
# ==============================================================================
## Advances state machine cycle: PLAN (0) -> ATTACK (1) -> PRODUCE (2) -> PLAN (0).
func advance_phase() -> void:
	if is_game_over:
		return
	match current_phase:
		Phase.PLAN:
			set_phase(Phase.ATTACK)
		Phase.ATTACK:
			set_phase(Phase.PRODUCE)
		Phase.PRODUCE:
			set_phase(Phase.PLAN)
		_:
			set_phase(Phase.PLAN)

## Directly sets the game phase and executes required lifecycle triggers.
func set_phase(new_phase: Phase) -> void:
	if is_game_over:
		return
	var phase_val: int = int(new_phase)
	if phase_val < Phase.PLAN or phase_val > Phase.PRODUCE:
		push_error("[GameState] Invalid phase: %s" % str(new_phase))
		return
	current_phase = new_phase
	_emit_phase_changed(current_phase)
	
	match current_phase:
		Phase.PLAN:
			_cancel_produce_timer()
			reset_ap()
			var cfg = _get_config()
			var time_cfg: Dictionary = cfg.get("TIME") if (cfg and "TIME" in cfg and cfg.TIME is Dictionary) else {}
			deploy_length = float(time_cfg.get("deploy_length", 90.0))
			remaining_deploy_time = deploy_length
			is_paused = false
			var eb = _get_event_bus()
			if eb and eb.has_signal("deploy_time_changed"):
				eb.deploy_time_changed.emit(remaining_deploy_time, deploy_length)
		Phase.ATTACK:
			_cancel_produce_timer()
			is_paused = false
		Phase.PRODUCE:
			_cancel_produce_timer()
			is_paused = false
			_emit_produce_phase()
			_schedule_auto_end_produce()

## Compatibility alias for set_phase.
func change_phase(new_phase: int) -> void:
	if new_phase < Phase.PLAN or new_phase > Phase.PRODUCE:
		push_error("[GameState] Invalid phase: %d" % new_phase)
		return
	set_phase(new_phase as Phase)

## Toggles pause during DEPLOY phase. Returns new pause state.
func toggle_pause() -> bool:
	var cfg = _get_config()
	var allow: bool = true
	if cfg and "TIME" in cfg and cfg.TIME is Dictionary:
		allow = bool(cfg.TIME.get("allow_pause", true))
	if not allow or is_game_over or (not continuous_mode and current_phase != Phase.DEPLOY):
		return is_paused
	is_paused = !is_paused
	var eb = _get_event_bus()
	if eb and eb.has_signal("pause_toggled"):
		eb.pause_toggled.emit(is_paused)
	return is_paused

## Sets pause state explicitly during DEPLOY phase.
func set_paused(p: bool) -> bool:
	var cfg = _get_config()
	var allow: bool = true
	if cfg and "TIME" in cfg and cfg.TIME is Dictionary:
		allow = bool(cfg.TIME.get("allow_pause", true))
	if not allow or is_game_over or (not continuous_mode and current_phase != Phase.DEPLOY):
		return is_paused
	if is_paused != p:
		is_paused = p
		var eb = _get_event_bus()
		if eb and eb.has_signal("pause_toggled"):
			eb.pause_toggled.emit(is_paused)
	return is_paused

## Triggered to immediately conclude DEPLOY phase and unleash horde.
func trigger_early_end_deploy() -> void:
	if current_phase == Phase.DEPLOY and not is_game_over:
		advance_phase()

## Alias for trigger_early_end_deploy.
func end_deploy_phase() -> void:
	trigger_early_end_deploy()

## Triggered by HUD "End Action" button to conclude planning/deploy and unleash horde.
func trigger_end_action() -> void:
	trigger_early_end_deploy()

## Alias for trigger_end_action.
func end_plan_phase() -> void:
	trigger_end_action()

## Concludes production and transitions back to PLAN phase.
func end_produce_phase() -> void:
	_cancel_produce_timer()
	if current_phase == Phase.PRODUCE and not is_game_over:
		advance_phase()

func _schedule_auto_end_produce() -> void:
	if not is_inside_tree():
		return
	var cfg = _get_config()
	var duration: float = 1.0
	if cfg and "MAP" in cfg and cfg.MAP is Dictionary:
		duration = float(cfg.MAP.get("produce_duration", 1.0))
	elif cfg and "PRODUCE_DELAY" in cfg:
		duration = float(cfg.PRODUCE_DELAY)
	
	if duration <= 0.0:
		return
	
	if _produce_timer == null or not is_instance_valid(_produce_timer):
		_produce_timer = Timer.new()
		_produce_timer.name = "ProduceAutoTimer"
		_produce_timer.one_shot = true
		_produce_timer.timeout.connect(_on_produce_timer_timeout)
		add_child(_produce_timer)
	
	_produce_timer.start(duration)

func _on_produce_timer_timeout() -> void:
	if current_phase == Phase.PRODUCE and not is_game_over:
		end_produce_phase()

func _cancel_produce_timer() -> void:
	if _produce_timer and is_instance_valid(_produce_timer) and not _produce_timer.is_stopped():
		_produce_timer.stop()


# ==============================================================================
# 10. Reactive Event Handlers (EventBus Listeners)
# ==============================================================================
func _on_wave_started(n: int, _is_big: bool) -> void:
	wave_number = maxi(0, n)

func _on_wave_ended(n: int) -> void:
	if is_game_over:
		return
	var cfg = _get_config()
	var waves_cfg: Dictionary = cfg.get("WAVES") if (cfg and "WAVES" in cfg) else {}
	var big_every: int = waves_cfg.get("big_every", 3)
	if big_every > 0 and n > 0 and n % big_every == 0:
		var enhance: Dictionary = waves_cfg.get("enhance_after_big", {})
		for stat in enhance:
			if dino_stat_multipliers.has(stat):
				dino_stat_multipliers[stat] *= float(enhance[stat])
	set_phase(Phase.PRODUCE)

func _on_nest_destroyed(_nest: Node) -> void:
	nests_alive = maxi(0, nests_alive - 1)
	if nests_alive <= 0 and not is_game_over:
		_emit_game_won()

func _on_game_won() -> void:
	if is_game_over:
		return
	is_game_won = true
	is_game_over = true

func _on_game_lost() -> void:
	if is_game_over or is_game_won:
		return
	is_game_won = false
	is_game_over = true

func _on_hero_died() -> void:
	if not is_game_over:
		_emit_game_lost()

## Zeroed resource wallet covering every id in Config.RESOURCES.
## Used only when Config is unavailable: a wallet that is missing a key would make
## add_resources() silently discard gains of that resource.
func _default_resources() -> Dictionary:
	var out: Dictionary = {}
	var cfg = _get_config()
	if cfg and "RESOURCES" in cfg:
		for res_id in cfg.RESOURCES:
			out[res_id] = 0
		if cfg and "INITIAL_RESOURCES" in cfg:
			for res_id in cfg.INITIAL_RESOURCES:
				out[res_id] = cfg.INITIAL_RESOURCES[res_id]
		return out
	return {"wood": 10, "stone": 0, "water": 0, "food": 0}
