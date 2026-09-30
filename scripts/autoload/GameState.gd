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
var resources: Dictionary = {}
var wave_number: int = 0
var dino_stat_multipliers: Dictionary = {}
var is_game_over: bool = false
var is_game_won: bool = false
## How the run was lost (the debug-agent's BUG-011): "cabin" -- broken open -- or "hero" -- he fell;
## "" while it is not, or when nothing said.
var lost_to: String = ""
## What killed him, when it was at his side (Hero.die): {"type": its Config.DINOS id, "guard": whether
## it was guarding its nest} -- or nothing.
var hero_killer: Dictionary = {}
var active_buildings: Array[Node] = []

## Everything the Hero has made at the cabin, as a set of permanent flags. Not an
## inventory: there is no count, no durability and nothing to carry -- a flag is
## either set or it is not, and set means usable. That is what keeps the cabin
## from turning into a bag.
var unlocks: Dictionary = {}

## The materials this run has turned up (v0.6 feedback: "需要有隐藏，层层打开机制"): what the
## map hands out at the start, and each one the first time it comes into the stock. What
## can be built and made, what the resource bar shows and what a material is said to be for
## all wait on these -- the run unfolds a material at a time rather than laying everything
## out at once, missing pieces and all.
var known: Dictionary = {}

## The meal he is living on (v0.6, GAME-DESIGN 4.5): its boost and how long it has left --
## {"dish", "method", "build_speed", "move_speed", "max_hp", "seconds_left", "seconds_total"}
## -- or empty when he is not fed. One meal at a time: eating again replaces it.
var fed: Dictionary = {}

## Meals cooked and not yet eaten (v0.6 round two: "吃饭也是一个图标，点进去呢就有吃的东西"):
## "dish/method" -> how many. The kitchen cooks into this; he eats from it, wherever he is,
## when the player says (Hero.order_eat). A meal keeps the way it was cooked: roast meat
## does not become seared because a pot has been made since.
var meals: Dictionary = {}

## The run (v0.6, GAME-DESIGN 12): which map it is played on, and the seed every chance in
## it is drawn from. Everything in play that is left to chance draws from `rng` -- never
## from the engine's global randf -- so one seed replays one run: a seed can be shared,
## and a bug can be replayed. Decoration keeps generators of its own.
var map_id: String = ""
## The map the player's runs are played on (Main._choose_the_map, from the settings page), kept
## across a restart; empty, the default -- the small valley, which the tests and tools play.
var chosen_map_id: String = ""
var run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## How far along the beacon is (v0.6, GAME-DESIGN 8.3): how many of its steps are done --
## the run's map's repair stages, then the launch (Config.beacon_jobs) -- and, once it is
## launched, how many seconds it has charged. That is all there is to remember about it.
var beacon_steps: int = 0
var beacon_charge: float = 0.0
## Seconds until the final wave sets out, counting down from the launch (MAPS.beacon.launch_grace;
## WaveManager counts it); -1 when none is coming, or it has come.
var final_wave_in: float = -1.0

## The map this run is played on (Config.MAPS).
func map_data() -> Dictionary:
	var cfg = _get_config()
	return cfg.map_data(map_id) if (cfg and cfg.has_method("map_data")) else {}
var _produce_timer: Timer = null

# v0.1 Real-Time Deployment & Pause
var deploy_length: float = 90.0
var remaining_deploy_time: float = 90.0
## Whether the game is paused -- and the pause is the engine's: the tree is paused, and everything
## in it that does not say otherwise holds exactly where it is, every unit, building, drop, raid
## and clock, with nothing of its own to check (v0.6 round three: "pause就得像take snapshot一样，不能有
## 任何状态在改变……应该写成每个单位都继承的"). It asked this flag unit by unit before, and what did not
## ask -- the cabin's gun, the animations -- went on. What answers while paused says so itself:
## the interface (HUD, PauseMenu), the camera and the player's orders (Main), the interface's
## sounds (Fx).
var is_paused: bool = false:
	set(value):
		is_paused = value
		if is_inside_tree():
			get_tree().paused = value

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
	_stage_raid = false
	day_clock = float(_day().get("start", 0.0))
	_day_part = day_part()
	is_game_over = false
	is_game_won = false
	deploy_length = 90.0
	remaining_deploy_time = 90.0
	is_paused = false

func _ready() -> void:
	set_process(true)
	_connect_event_bus()
	reset_game()
	print("[GameState] Initialized. Phase: %s, Deploy: %.1fs, Resources: %s" % [
		Phase.keys()[current_phase], remaining_deploy_time, str(resources)
	])

func _process(delta: float) -> void:
	if is_game_over:
		return
	wear_off(delta)
	charge_beacon(delta)
	_run_the_day(delta)
	if continuous_mode:
		return
	if current_phase == Phase.DEPLOY:
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
		if eb.has_signal("stage_wave_started") and not eb.stage_wave_started.is_connected(_on_stage_wave_started):
			eb.stage_wave_started.connect(_on_stage_wave_started)
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
## A new run. `p_seed` replays a run exactly; left out, every run is a fresh one.
func reset_game(p_seed: int = -1) -> void:
	_cancel_produce_timer()
	is_game_over = false
	is_game_won = false
	lost_to = ""
	hero_killer = {}
	var cfg_run = _get_config()
	map_id = chosen_map_id if chosen_map_id != "" else (String(cfg_run.DEFAULT_MAP_ID) if (cfg_run and "DEFAULT_MAP_ID" in cfg_run) else "")
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	run_seed = int(rng.seed)
	# GameState is an autoload, so this flag would otherwise leak from any test that
	# instantiates Main into every test that runs after it. Main re-enables it in
	# setup_level(), which runs after reset_game() on the restart path.
	continuous_mode = false
	current_phase = Phase.PLAN
	var cfg = _get_config()
	if cfg:
		resources = cfg.get("INITIAL_RESOURCES").duplicate(true) if "INITIAL_RESOURCES" in cfg else _default_resources()
		dino_stat_multipliers = cfg.get("INITIAL_DINO_MULTIPLIERS").duplicate(true) if "INITIAL_DINO_MULTIPLIERS" in cfg else {"hp": 1.0, "damage": 1.0, "speed": 1.0}
	else:
		resources = _default_resources()
		dino_stat_multipliers = {"hp": 1.0, "damage": 1.0, "speed": 1.0}
	wave_number = 0
	active_buildings.clear()
	unlocks.clear()
	known.clear()
	for res_id in map_data().get("opening_stock", {}):
		known[String(res_id)] = true
	_set_fed({})
	_set_meals({})
	beacon_steps = 0
	beacon_charge = 0.0
	goal = {}
	final_wave_in = -1.0
	drop_misses.clear()
	_stage_raid = false
	nest_found = false
	# The run lands in its first morning (Config.DAY.start).
	day_clock = float(_day().get("start", 0.0))
	_day_part = day_part()

	var time_cfg: Dictionary = cfg.get("TIME") if (cfg and "TIME" in cfg and cfg.TIME is Dictionary) else {}
	deploy_length = float(time_cfg.get("deploy_length", 90.0))
	remaining_deploy_time = deploy_length
	is_paused = false
	
	_emit_phase_changed(current_phase)
	_emit_resources_changed(resources)
	var eb = _get_event_bus()
	if eb and eb.has_signal("deploy_time_changed"):
		eb.deploy_time_changed.emit(remaining_deploy_time, deploy_length)

## How many chance drops of each resource have missed running (Config.DROPS.pity_after).
var drop_misses: Dictionary = {}

## Whether one chance drop of `res_id` (Config.DINOS[..].drop_chance) falls: at `chance`, on the
## run's dice -- but never after `pity_after` misses running, and never missing the first of the
## run, so chance leaves him more but never stuck.
func roll_drop(res_id: String, chance: float) -> bool:
	var cfg = _get_config()
	var pity: int = int(cfg.DROPS.get("pity_after", 1)) if (cfg and "DROPS" in cfg) else 1
	var missed: int = int(drop_misses.get(res_id, pity))
	var falls: bool = missed >= pity or rng.randf() < chance
	drop_misses[res_id] = 0 if falls else missed + 1
	return falls

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

## Deposits earned resources into player inventory and broadcasts update. A material the
## run had not turned up before is announced (material_discovered) once the stock shows it.
func add_resources(gains: Dictionary) -> void:
	var newly: Array[String] = []
	for res_id in gains:
		if not resources.has(res_id):
			continue
		var val = gains[res_id]
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_FLOAT:
			continue
		var amount: int = int(val)
		if amount > 0:
			if not knows(String(res_id)):
				newly.append(String(res_id))
			resources[res_id] = resources[res_id] + amount
			known[String(res_id)] = true
	_emit_resources_changed(resources)
	var eb = _get_event_bus()
	for res_id in newly:
		if eb and eb.has_signal("material_discovered"):
			eb.material_discovered.emit(res_id)

## Adds a single resource by name.
func add_resource(res_id: String, amount: int) -> void:
	add_resources({res_id: amount})


## Whether this run has turned `res_id` up -- or has it in the stock now, which is the same
## thing however it got there.
func knows(res_id: String) -> bool:
	return bool(known.get(res_id, false)) or int(resources.get(res_id, 0)) > 0

## Whether every material `cost` takes has turned up: what shows a building, a recipe or a
## meal on offer.
func knows_all(cost: Dictionary) -> bool:
	for res_id in cost:
		if not knows(String(res_id)):
			return false
	return true

# ==============================================================================
# 7b. Unlocks (v0.4): what the Hero has made at the cabin
# ==============================================================================

## Whether `unlock_id` has been made. Everything asks this rather than keeping its
## own copy, so an ability and the UI that offers it can never disagree.
func has_unlock(unlock_id: String) -> bool:
	return unlock_id != "" and bool(unlocks.get(unlock_id, false))

## Records an unlock and announces it. Granting one twice is a no-op, so a recipe
## finishing again cannot double-count.
func grant_unlock(unlock_id: String) -> bool:
	if unlock_id == "" or has_unlock(unlock_id):
		return false
	unlocks[unlock_id] = true
	var eb = _get_event_bus()
	if eb and eb.has_signal("unlock_granted"):
		eb.unlock_granted.emit(unlock_id)
	# Made, it is no longer something to aim at.
	var cfg = _get_config()
	if String(goal.get("kind", "")) == "job" and cfg and "RECIPES" in cfg \
			and String(cfg.RECIPES.get(String(goal.get("id", "")), {}).get("unlocks", "")) == unlock_id:
		unpin_goal()
	return true

# ==============================================================================
# 7c. Tools and meals (v0.6): how fast the one body works
# ==============================================================================
## Every rate that matters is the Hero's own -- one body holds up the whole base -- so
## "getting better" means him working faster: tools for good, meals for a while
## (GAME-DESIGN 4.6). These are the only places the factors are worked out; the Hero
## multiplies by them and the UI names them.

## How much each stroke on a `res_id` node brings in, from the tools he has made.
func harvest_multiplier(res_id: String) -> float:
	var cfg = _get_config()
	return float(cfg.harvest_speed(res_id, unlocks)) if cfg and cfg.has_method("harvest_speed") else 1.0

## How fast he raises and mends, from what he last ate.
func build_multiplier() -> float:
	return float(fed.get("build_speed", 1.0))

## How fast he walks, from what he last ate.
func move_multiplier() -> float:
	return float(fed.get("move_speed", 1.0))

## Hit points he has over his own while he is fed.
func max_hp_bonus() -> float:
	return float(fed.get("max_hp", 0.0))

## The stock's key for `dish_id` cooked by `method`.
static func meal_key(dish_id: String, method: String) -> String:
	return "%s/%s" % [dish_id, method]

## A meal put by, cooked the best way his vessels allow now (Config.cooking_method). Returns
## its key.
func stock_meal(dish_id: String) -> String:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("cooking_method") or not cfg.DISHES.has(dish_id):
		return ""
	var key: String = meal_key(dish_id, String(cfg.cooking_method(unlocks).get("id", "")))
	var now: Dictionary = meals.duplicate()
	now[key] = int(now.get(key, 0)) + 1
	_set_meals(now)
	return key

## How many of the meal `key` are cooked and waiting.
func meal_count(key: String) -> int:
	return int(meals.get(key, 0))

## What is in the stock, in the order Config lists dishes and cooking methods: one
## {"key", "dish", "method", "count"} for each meal there is at least one of.
func meals_in_stock() -> Array:
	var out: Array = []
	var cfg = _get_config()
	if cfg == null:
		return out
	for dish_id in cfg.DISHES:
		for method in cfg.COOKING_METHODS:
			var key: String = meal_key(String(dish_id), String(method.get("id", "")))
			if meal_count(key) > 0:
				out.append({"key": key, "dish": String(dish_id), "method": String(method.get("id", "")),
					"count": meal_count(key)})
	return out

## He eats one of the meal `key` from the stock. Returns what it did (as eat), or {} when there
## is none of it.
func eat_meal(key: String) -> Dictionary:
	if meal_count(key) <= 0:
		return {}
	var parts: PackedStringArray = key.split("/")
	if parts.size() != 2:
		return {}
	var now: Dictionary = meals.duplicate()
	now[key] = meal_count(key) - 1
	if int(now[key]) <= 0:
		now.erase(key)
	_set_meals(now)
	return eat(parts[0], parts[1])

func _set_meals(value: Dictionary) -> void:
	if value == meals:
		return
	meals = value
	var eb = _get_event_bus()
	if eb and eb.has_signal("meals_changed"):
		eb.meals_changed.emit(meals)

## He eats `dish_id` -- cooked by `method`, or the best way his vessels allow when none is
## named (Config.meal_of). Heals are the Hero's business and go out on the bus; a meal with a
## lasting boost makes him fed, replacing whatever he was fed on before. Returns the meal, or
## {} for an unknown dish.
func eat(dish_id: String, method: String = "") -> Dictionary:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("meal_of"):
		return {}
	var meal: Dictionary = cfg.meal_cooked(dish_id, method) if method != "" else cfg.meal_of(dish_id, unlocks)
	if meal.is_empty():
		return {}
	var seconds: float = float(meal.get("fed_seconds", 0.0))
	if seconds > 0.0:
		_set_fed({
			"dish": dish_id,
			"method": String(meal.get("method", "")),
			"build_speed": float(meal.get("build_speed", 1.0)),
			"move_speed": float(meal.get("move_speed", 1.0)),
			"max_hp": float(meal.get("max_hp", 0.0)),
			"seconds_left": seconds,
			"seconds_total": seconds,
		})
	var eb = _get_event_bus()
	if eb and eb.has_signal("meal_eaten"):
		eb.meal_eaten.emit(meal)
	return meal

## Counts the meal down by `delta` seconds of game time, and lets it go when it is done.
## Called every frame the game runs; public so a test can pass time without waiting.
func wear_off(delta: float) -> void:
	if fed.is_empty() or delta <= 0.0:
		return
	fed["seconds_left"] = float(fed.get("seconds_left", 0.0)) - delta
	if float(fed["seconds_left"]) <= 0.0:
		_set_fed({})

func _set_fed(value: Dictionary) -> void:
	if value.is_empty() and fed.is_empty():
		return
	fed = value
	var eb = _get_event_bus()
	if eb and eb.has_signal("fed_changed"):
		eb.fed_changed.emit(fed)

# ==============================================================================
# 7d. The beacon (v0.6): the run's main line, and the only way to win it
# ==============================================================================
## GAME-DESIGN 8.3: repaired at the cabin a stage at a time, launched when the player
## chooses, and then it charges while the whole valley comes for the cabin. Full charge is
## the jump, and the run is won -- nothing else wins it now; the nest cannot be destroyed.

## The step the cabin can work on next -- the next stage, then the launch -- or "" once it
## is launched (and on a map without a beacon).
func beacon_next_job() -> String:
	var jobs: Array[String] = _beacon_jobs()
	return jobs[beacon_steps] if beacon_steps < jobs.size() else ""

# ==============================================================================
# The pinned goal (GAME-DESIGN 6.0 rule 4)
# ==============================================================================
## One thing the player wants next, whose price the material bar counts against (v0.6 round six, the
## player: "也很难做规划"; chosen: "钉住一个目标"): a building off the menu, a way up for one that stands,
## a job at a bench -- {"kind": "build" | "upgrade" | "job", "id": ..., "from": the type an upgrade is
## from} -- or {} with none. One at a time.
var goal: Dictionary = {}

## Pins `g` -- or unpins it, if it is what is pinned already (EventBus.goal_changed).
func pin_goal(g: Dictionary) -> void:
	goal = {} if (g.is_empty() or is_pinned(g)) else g.duplicate()
	_say_goal()

func unpin_goal() -> void:
	if goal.is_empty():
		return
	goal = {}
	_say_goal()

## What was pinned is paid for -- a building ordered off the menu, a way up begun (BuildSystem.place_at,
## Building.begin_upgrade): it is no longer something to aim at (v0.6 round six, the player chose "下单就取消";
## it hung on after it was built). A job at a bench goes when it is made (grant_unlock); a stage of the beacon
## hands on to the next.
func goal_paid(g: Dictionary) -> void:
	if is_pinned(g):
		unpin_goal()

## Whether `g` is the goal pinned.
func is_pinned(g: Dictionary) -> bool:
	return not g.is_empty() and not goal.is_empty() and String(g.get("kind", "")) == String(goal.get("kind", "")) \
		and String(g.get("id", "")) == String(goal.get("id", "")) and String(g.get("from", "")) == String(goal.get("from", ""))

## What the goal costs now: a building its price, a way up the difference (Config.upgrade_cost), a
## job at a bench its inputs -- a step up his row at the difference (Config.recipe_price), a beacon
## step its own. {} with none pinned.
func goal_price() -> Dictionary:
	var cfg = _get_config()
	if goal.is_empty() or cfg == null:
		return {}
	var id: String = String(goal.get("id", ""))
	match String(goal.get("kind", "")):
		"build":
			return cfg.BUILDINGS.get(id, {}).get("cost", {})
		"upgrade":
			return cfg.upgrade_cost(String(goal.get("from", "")), id)
		"job":
			if cfg.RECIPES.has(id):
				return cfg.recipe_price(id, unlocks)
			if "DISHES" in cfg and cfg.DISHES.has(id):
				return cfg.DISHES[id].get("inputs", {})
			return cfg.beacon_job(map_data(), id).get("inputs", {})
	return {}

## What the goal is called, as the bar says it.
func goal_name() -> String:
	var cfg = _get_config()
	if goal.is_empty() or cfg == null:
		return ""
	var id: String = String(goal.get("id", ""))
	match String(goal.get("kind", "")):
		"build", "upgrade":
			return String(cfg.get_building_name(id))
		"job":
			if cfg.RECIPES.has(id):
				return TranslationServer.translate(String(cfg.RECIPES[id].get("name", id)))
			if "DISHES" in cfg and cfg.DISHES.has(id):
				return TranslationServer.translate(String(cfg.DISHES[id].get("name", id)))
			var row: Dictionary = cfg.beacon_job(map_data(), id)
			var title: String = TranslationServer.translate(String(row.get("name", id)))
			var args: Array = row.get("name_args", [])
			return (title % args) if (not args.is_empty() and "%" in title) else title
	return ""

## What of the goal's price the stock is still short of: {res_id: how many more}.
func goal_short() -> Dictionary:
	var out: Dictionary = {}
	var price: Dictionary = goal_price()
	for res_id in price:
		var more: int = int(price[res_id]) - int(resources.get(res_id, 0))
		if more > 0:
			out[res_id] = more
	return out

## A beacon step that costs nothing -- the launch -- is a decision, not something to save up for.
func _beacon_row_free(job_id: String) -> bool:
	var cfg = _get_config()
	return cfg == null or cfg.beacon_job(map_data(), job_id).get("inputs", {}).is_empty()

func _say_goal() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("goal_changed"):
		eb.goal_changed.emit(goal)

## How many repair stages the beacon has, and how many of them stand repaired.
func beacon_stage_count() -> int:
	return maxi(0, _beacon_jobs().size() - 1)

func beacon_stages_done() -> int:
	return mini(beacon_steps, beacon_stage_count())

func is_beacon_launched() -> bool:
	var jobs: Array[String] = _beacon_jobs()
	return not jobs.is_empty() and beacon_steps >= jobs.size()

## A step finished at the cabin: a stage stands repaired, or -- the last step -- the beacon
## is switched on and starts to charge. Only the next step counts: one already done, or a
## stage out of turn, changes nothing and returns false.
func finish_beacon_job(job_id: String) -> bool:
	if is_game_over or job_id == "" or job_id != beacon_next_job():
		return false
	beacon_steps += 1
	# The beacon's next step pinned: done, the one after it is what is aimed at now.
	if String(goal.get("kind", "")) == "job" and String(goal.get("id", "")) == job_id:
		var next: String = beacon_next_job()
		if next != "" and not _beacon_row_free(next):
			pin_goal({"kind": "job", "id": next})
		else:
			unpin_goal()
	var eb = _get_event_bus()
	if eb and eb.has_signal("beacon_changed"):
		eb.beacon_changed.emit(beacon_steps)
	if is_beacon_launched() and eb and eb.has_signal("beacon_launched"):
		eb.beacon_launched.emit()
	return true

## How much of the charge is done, 0..1.
func beacon_charge_ratio() -> float:
	var total: float = _charge_seconds()
	return clampf(beacon_charge / total, 0.0, 1.0) if total > 0.0 else 0.0

## Seconds of charging left until the jump.
func beacon_seconds_left() -> float:
	return maxf(0.0, _charge_seconds() - beacon_charge)

## Charges the launched beacon by `delta` seconds of game time. At full charge the capsule
## jumps and the run is won. Called every frame the game runs; public so a test can pass
## time without waiting.
func charge_beacon(delta: float) -> void:
	# `not (delta > 0.0)` rather than `delta <= 0.0`: NaN fails every comparison, and a NaN
	# let in here would leave the charge NaN -- a run that could never be won.
	if beacon_steps <= 0 or not (delta > 0.0) or is_game_over or not is_beacon_launched():
		return
	beacon_charge = minf(_charge_seconds(), beacon_charge + delta)
	if beacon_charge >= _charge_seconds():
		_emit_game_won()

func _beacon_jobs() -> Array[String]:
	var cfg = _get_config()
	if cfg and cfg.has_method("beacon_jobs"):
		return cfg.beacon_jobs(map_data())
	return []

func _charge_seconds() -> float:
	return float(map_data().get("beacon", {}).get("charge_seconds", 0.0))

# ==============================================================================
# 8. The Standing Buildings
# ==============================================================================
## Drops anything that has been freed. Buildings unregister themselves as they die,
## but a node freed some other way -- a test, a level teardown -- would otherwise sit
## in this list for the rest of the run.
func _prune_buildings() -> void:
	var valid_buildings: Array[Node] = []
	for b in active_buildings:
		if is_instance_valid(b):
			valid_buildings.append(b)
	active_buildings = valid_buildings

## Tracks an instantiated building for lifecycle management.
func register_building(building: Node) -> void:
	if building and not active_buildings.has(building):
		active_buildings.append(building)
		_prune_buildings()

## Untracks a destroyed building.
func unregister_building(building: Node) -> void:
	if building and active_buildings.has(building):
		active_buildings.erase(building)
		_prune_buildings()

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
	if cfg and "PRODUCE_DELAY" in cfg:
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
	_stage_raid = false

# ==============================================================================
# The day (Config.DAY, GAME-DESIGN 9.3)
# ==============================================================================

## Seconds of game time since the run's first light. Run on in _process, so a paused game's clock
## holds with everything else.
var day_clock: float = 0.0
## The part of the day it was last said to be (EventBus.day_part_changed).
var _day_part: String = ""

func _day() -> Dictionary:
	var cfg = _get_config()
	return cfg.DAY if (cfg and "DAY" in cfg) else {"length": 360.0, "parts": {"day": 0.0}, "start": 0.0}

## Seconds into today, from its first light.
func time_of_day() -> float:
	return fposmod(day_clock, float(_day().get("length", 360.0)))

## Which day of the run it is, the first being 1.
func day_number() -> int:
	return int(floor(day_clock / float(_day().get("length", 360.0)))) + 1

## "day", "dusk" or "night" (Config.DAY.parts): the latest part begun by this time of day.
func day_part() -> String:
	var t: float = time_of_day()
	var best: String = "day"
	var best_at: float = -1.0
	var parts: Dictionary = _day().get("parts", {"day": 0.0})
	for part in parts:
		var at: float = float(parts[part])
		if at <= t and at > best_at:
			best_at = at
			best = String(part)
	return best

## The clock on by `delta`, and a new part of the day said when it begins.
func _run_the_day(delta: float) -> void:
	day_clock += delta
	var part: String = day_part()
	if part != _day_part:
		_day_part = part
		var eb = _get_event_bus()
		if eb and eb.has_signal("day_part_changed"):
			eb.day_part_changed.emit(part, day_number())

## Whether the nest has been found (FogOfWar: it came into sight): its raids are seen setting out.
var nest_found: bool = false

## Whether the raid out is one a repaired beacon stage stirred up (EventBus.stage_wave_started).
var _stage_raid: bool = false

func _on_stage_wave_started(_size: int) -> void:
	_stage_raid = true

func _on_wave_ended(n: int) -> void:
	if is_game_over:
		return
	var cfg = _get_config()
	var waves_cfg: Dictionary = cfg.get("WAVES") if (cfg and "WAVES" in cfg) else {}
	var big_every: int = waves_cfg.get("big_every", 3)
	# A beacon stage's raid ends with the number of the raid before it (WaveManager.start_stage_wave):
	# after a big one, it is not a second big raid.
	var stage_raid: bool = _stage_raid
	_stage_raid = false
	if big_every > 0 and n > 0 and n % big_every == 0 and not stage_raid:
		var enhance: Dictionary = waves_cfg.get("enhance_after_big", {})
		# No tougher than the valley's toughest (MAPS.<id>.toughest): they grow to it and no further.
		var toughest: float = float(map_data().get("toughest", 0.0)) if has_method("map_data") else 0.0
		for stat in enhance:
			if dino_stat_multipliers.has(stat):
				var grown: float = float(dino_stat_multipliers[stat]) * float(enhance[stat])
				dino_stat_multipliers[stat] = minf(grown, maxf(toughest, float(dino_stat_multipliers[stat]))) if toughest > 0.0 else grown
	set_phase(Phase.PRODUCE)

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
		lost_to = "hero"
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
