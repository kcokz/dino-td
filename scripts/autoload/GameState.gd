# res://scripts/autoload/GameState.gd
extends Node

## Authoritative Runtime Game State & Turn State Machine for Defend Dinosaur v0.0
## Manages phases, AP pool, resource inventory, wave tracking, and transaction safety.

# ==============================================================================
# 1. Enums & State Definitions
# ==============================================================================
enum Phase {
	PLAN = 0,
	ATTACK = 1,
	PRODUCE = 2
}

# ==============================================================================
# 2. Canonical State Variables
# ==============================================================================
var current_phase: Phase = Phase.PLAN
var current_ap: int = 3
var max_ap: int = 3
var resources: Dictionary = {}
var wave_number: int = 0
var dino_stat_multipliers: Dictionary = {}
var is_game_over: bool = false
var is_game_won: bool = false
var nests_alive: int = 1
var active_buildings: Array[Node] = []

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
	resources = {"wood": 10, "stone": 0, "food": 0}
	dino_stat_multipliers = {"hp": 1.0, "damage": 1.0, "speed": 1.0}
	current_ap = 3
	max_ap = 3
	is_game_over = false
	is_game_won = false

func _ready() -> void:
	_connect_event_bus()
	reset_game()
	print("[GameState] Initialized. Phase: %s, AP: %d/%d, Resources: %s" % [
		Phase.keys()[current_phase], current_ap, max_ap, str(resources)
	])

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
	is_game_over = false
	is_game_won = false
	current_phase = Phase.PLAN
	var cfg = _get_config()
	if cfg:
		max_ap = cfg.get("BASE_AP") if "BASE_AP" in cfg else 3
		resources = cfg.get("INITIAL_RESOURCES").duplicate(true) if "INITIAL_RESOURCES" in cfg else {"wood": 10, "stone": 0, "food": 0}
		dino_stat_multipliers = cfg.get("INITIAL_DINO_MULTIPLIERS").duplicate(true) if "INITIAL_DINO_MULTIPLIERS" in cfg else {"hp": 1.0, "damage": 1.0, "speed": 1.0}
		nests_alive = cfg.get("INITIAL_NESTS_ALIVE") if "INITIAL_NESTS_ALIVE" in cfg else 1
	else:
		max_ap = 3
		resources = {"wood": 10, "stone": 0, "food": 0}
		dino_stat_multipliers = {"hp": 1.0, "damage": 1.0, "speed": 1.0}
		nests_alive = 1
	current_ap = max_ap
	wave_number = 0
	active_buildings.clear()
	
	_emit_phase_changed(current_phase)
	_emit_ap_changed(current_ap, max_ap)
	_emit_resources_changed(resources)

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

# ==============================================================================
# 8. Action Point (AP) Transactions & Capacity
# ==============================================================================
## Checks whether player has at least amount AP available.
func can_spend_ap(amount: int) -> bool:
	return not is_game_over and amount >= 0 and current_ap >= amount

## Deducts AP if sufficient. Returns true on success, false otherwise.
func spend_ap(amount: int) -> bool:
	if not can_spend_ap(amount):
		return false
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
			reset_ap()
		Phase.ATTACK:
			pass
		Phase.PRODUCE:
			_emit_produce_phase()

## Compatibility alias for set_phase.
func change_phase(new_phase: int) -> void:
	if new_phase < Phase.PLAN or new_phase > Phase.PRODUCE:
		push_error("[GameState] Invalid phase: %d" % new_phase)
		return
	set_phase(new_phase as Phase)

## Triggered by HUD "End Action" button to conclude planning and unleash horde.
func trigger_end_action() -> void:
	if current_phase == Phase.PLAN and not is_game_over:
		advance_phase()

## Alias for trigger_end_action.
func end_plan_phase() -> void:
	trigger_end_action()

## Concludes production and transitions back to PLAN phase.
func end_produce_phase() -> void:
	if current_phase == Phase.PRODUCE and not is_game_over:
		advance_phase()

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
