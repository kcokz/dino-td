# res://scripts/core/NightProwl.gd
class_name NightProwl
extends Node

## The night's hunters (GAME-DESIGN 9.3: "夜里：……危险换成了河边：植龙沿岸巡，基地离河近就会被摸上来"; v0.6
## round four, the player: "不用火把，晚上更多的夜行动物袭击（怕火把但是不怕暗淡灯光的船舱）"): in the hours the
## map's prowlers keep (Config.DINOS.<id>.hours -- the phytosaur's, the night) one comes up out of the
## river every so often (Config.PROWL.every) at the map's river side (MAPS.<id>.prowl_from), and makes
## for the Hero and the cabin (ProwlerDino). How many are out at once is the camp's doing: with a fire
## burning by the cabin (PROWL.lit_within) a few, dark more (PROWL.most_lit, most_dark) -- "不点火，夜里
## 摸上来的就多". None comes up where he can see it (FogOfWar.sees). At first light they go back to the
## river (ProwlerDino.go_home). Apart from the raids: a raid's count is its own (WaveManager).

## Where they come up: the field's river side (Main, from MAPS.<id>.prowl_from).
var origins: Array[Vector3] = []
var dinos_container: Node = null
## Whether they come at all: off for a level built without a map.
var enabled: bool = true
## Seconds to the next one; how many have come up tonight; whose turn among the origins it is.
var _clock: float = 0.0
var came_tonight: int = 0
var _turn: int = 0
var _was_out: bool = false

func _ready() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("day_part_changed") and not eb.day_part_changed.is_connected(_on_day_part_changed):
		eb.day_part_changed.connect(_on_day_part_changed)

func reset() -> void:
	_clock = _number("first_after", 8.0)
	came_tonight = 0
	_turn = 0
	_was_out = false

func _process(delta: float) -> void:
	if not enabled or origins.is_empty():
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and (("is_game_over" in gs and gs.is_game_over) or ("is_paused" in gs and gs.is_paused)):
		return
	var out: bool = prowling_hours()
	if out and not _was_out:
		# The night has come: the first a while into it.
		_clock = _number("first_after", 8.0)
		came_tonight = 0
	_was_out = out
	if not out:
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = _number("every", 18.0)
	# In pairs (PROWL.pair): the second up beside the first.
	if out_now() < most_now():
		var first: Node = send_one()
		if first != null:
			for k in range(1, maxi(1, int(_number("pair", 1)))):
				if out_now() >= most_now():
					break
				send_one_from((first as Node3D).global_position + Vector3(0.0, 0.0, 1.2 * float(k)))

## Whether it is the hours one of the map's prowlers keeps.
func prowling_hours() -> bool:
	var gs = get_node_or_null("/root/GameState")
	var cfg = get_node_or_null("/root/Config")
	if gs == null or cfg == null or not gs.has_method("day_part"):
		return false
	var part: String = String(gs.day_part())
	for species in _prowlers():
		if cfg.keeps_hours(String(species), part):
			return true
	return false

## Whether the camp is lit: a fire burning within PROWL.lit_within of the cabin. The cabin's own dim
## windows are not a fire.
func camp_lit() -> bool:
	if not is_inside_tree():
		return false
	var core = get_tree().get_first_node_in_group("core")
	if not (core is Node3D):
		return false
	var within: float = _number("lit_within", 10.0)
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		if f is Node3D and is_instance_valid(f) and f.has_method("light_radius") and float(f.light_radius()) > 0.0:
			if (f as Node3D).global_position.distance_to((core as Node3D).global_position) <= within:
				return true
	return false

## How many may be out at once now: a few with the camp lit, more with it dark.
func most_now() -> int:
	return int(_number("most_lit", 1)) if camp_lit() else int(_number("most_dark", 3))

## How many are out now, not dead and not on their way home.
func out_now() -> int:
	var n: int = 0
	if not is_inside_tree():
		return n
	for d in get_tree().get_nodes_in_group(ProwlerDino.GROUP):
		if is_instance_valid(d) and not bool(d.get("is_dead")) and not bool(d.get("going_home")):
			n += 1
	return n

## One up out of the river, at the next place along it nobody sees (FogOfWar.sees) -- or, every one
## watched, none this time -- heading for the cabin.
func send_one() -> Node:
	var at: Variant = _next_origin()
	if at == null:
		return null
	return send_one_from(at)

## One up out of the river at `at`, seen or not -- a wreck's din brings one up where it is heard (Din) --
## heading for the cabin.
func send_one_from(at: Vector3) -> Node:
	var species: String = _species()
	var cfg = get_node_or_null("/root/Config")
	if species == "" or cfg == null:
		return null
	var script = load(String(cfg.get_dino_script_path(species)))
	if not (script is GDScript):
		return null
	var d: Node = script.new()
	var gs = get_node_or_null("/root/GameState")
	var multipliers: Dictionary = gs.dino_stat_multipliers if (gs and "dino_stat_multipliers" in gs) else {}
	d.setup(species, multipliers)
	d.home = at
	var road: Array[Vector3] = [at as Vector3]
	var core = get_tree().get_first_node_in_group("core") if is_inside_tree() else null
	if core is Node3D:
		road.append((core as Node3D).global_position)
	d.waypoints = road
	d.position = at
	var parent: Node = dinos_container if (dinos_container != null and is_instance_valid(dinos_container)) else self
	parent.add_child(d)
	d.setup(species, multipliers)
	came_tonight += 1
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dino_spawned"):
		eb.dino_spawned.emit(d)
	return d

func _next_origin() -> Variant:
	var fog: Node = get_tree().get_first_node_in_group(FogOfWar.GROUP) if is_inside_tree() else null
	for k in origins.size():
		var at: Vector3 = origins[(_turn + k) % origins.size()]
		if fog == null or not fog.has_method("sees") or not bool(fog.sees(at)):
			_turn += k + 1
			return at
	return null

## The prowler it sends: one of the map's (MAPS.<id>.prowlers), by weight, on the run's dice
## (GameState.rng) -- so a seed replays a night as it does a raid.
func _species() -> String:
	var weights: Dictionary = _prowlers()
	var total: float = 0.0
	for s in weights:
		total += float(weights[s])
	if total <= 0.0:
		return ""
	var gs = get_node_or_null("/root/GameState")
	var dice: RandomNumberGenerator = gs.rng if (gs and "rng" in gs and gs.rng is RandomNumberGenerator) else null
	var pick: float = (dice.randf() if dice != null else 0.0) * total
	for s in weights:
		pick -= float(weights[s])
		if pick <= 0.0:
			return String(s)
	return String(weights.keys()[0])

func _prowlers() -> Dictionary:
	var gs = get_node_or_null("/root/GameState")
	var map: Dictionary = gs.map_data() if (gs and gs.has_method("map_data")) else {}
	return map.get("prowlers", {})

## The night's over for the ones out: back to the river, each its own way (ProwlerDino.go_home).
func _on_day_part_changed(part: String, _day: int) -> void:
	var cfg = get_node_or_null("/root/Config")
	if cfg == null or not is_inside_tree():
		return
	for d in get_tree().get_nodes_in_group(ProwlerDino.GROUP):
		if is_instance_valid(d) and d.has_method("go_home") and not cfg.keeps_hours(String(d.dino_type), part):
			d.go_home(d.home)

func _number(key: String, fallback: float) -> float:
	var cfg = get_node_or_null("/root/Config")
	return float(cfg.PROWL.get(key, fallback)) if (cfg and "PROWL" in cfg) else fallback
