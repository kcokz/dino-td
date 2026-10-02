# res://scripts/core/Din.gd
class_name Din
extends Node

## THE DIN OF A WRECK SEARCHED (GAME-DESIGN 9.3, "信标变成冒险"; v0.6 round five, the player: "信标残骸里捡东西虽然花时间
## 但是没有危险，感觉时间花的很无聊，周围的守卫恐龙并不会进攻" -- chosen: "翻找的响声引来附近的恐龙"). Metal knocked
## about carries: at some strokes of a search (RESOURCE_NODES.<wreck>.din.at) something comes, as many as that
## stroke's count -- the longer he is at it, the more:
##   river   out of the river by the wreck, in their hours: phytosaurs (NightProwl.send_one_from), for him --
##           by day they lie in the river, and nothing comes (v0.6 round six)
##   guards  at the nest: the sleeping guards nearest the wreck, woken one by one (GuardDino.wake)
##   edge    down the valley: a few of the map's raiders in from the nearest way in, by the wreck, if it is
##           their hours (Config.keeps_hours) -- at night the pack sleeps, and nothing comes
## What comes for the din is not a raid's: it is not counted in one (group "drawn"). It is said once a search
## what the noise has done (EventBus.hero_spoke is his; the hint is the HUD's: din_carried).

var night_prowl: Node = null
var wave_manager: Node = null
var dinos_container: Node = null
## The wrecks whose din has been said this search, by instance id.
var _said: Dictionary = {}
## The species of what the din last brought (the screen shows its face: HUD._on_din_carried).
var _brought: String = ""

const GROUP_DRAWN: String = "drawn"

func _ready() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("wreck_struck") and not eb.wreck_struck.is_connected(_on_wreck_struck):
		eb.wreck_struck.connect(_on_wreck_struck)

func reset() -> void:
	_said.clear()

## A stroke of a search: `struck` of the part's strokes so far. At a stroke the wreck's din names, what it
## draws comes.
func _on_wreck_struck(wreck: Node, struck: int, _of: int) -> void:
	if wreck == null or not is_instance_valid(wreck) or not ("resource_type" in wreck):
		return
	var cfg = get_node_or_null("/root/Config")
	if cfg == null:
		return
	var din: Dictionary = cfg.RESOURCE_NODES.get(String(wreck.resource_type), {}).get("din", {})
	if din.is_empty():
		return
	var at: Array = din.get("at", [])
	var i: int = at.find(struck)
	if i < 0:
		return
	var counts: Array = din.get("count", [])
	var count: int = int(counts[i]) if i < counts.size() else 1
	_brought = ""
	var came: int = answer(wreck, String(din.get("draws", "")), count)
	if came > 0 and not _said.has(wreck.get_instance_id()):
		_said[wreck.get_instance_id()] = true
		var eb = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("din_carried"):
			eb.din_carried.emit(wreck, String(din.get("draws", "")), _brought)

## What the din at `wreck` brings, `count` of it; how many came.
func answer(wreck: Node, draws: String, count: int) -> int:
	match draws:
		"river":
			return _from_the_river(wreck, count)
		"guards":
			return _wake_the_guards(wreck, count)
		"edge":
			return _from_the_edge(wreck, count)
	return 0

## Out of the water by the wreck: from the place along the river nearest it, in their hours. By day the night's
## hunters lie in the river and the din brings none up (v0.6 round six, the player: "如果植龙是夜行动物，那么白天翻天线
## 不该出来吧？……但是最终，人应该能去拿天线"); at night one comes -- slower than he is on land (DINOS.phytosaur.speed),
## but for its lunge from close (DINO_AI.bursts): he gets away if he goes when he sees it.
func _from_the_river(wreck: Node, count: int) -> int:
	if night_prowl == null or not is_instance_valid(night_prowl) or not night_prowl.has_method("send_one_from"):
		return 0
	if night_prowl.has_method("in_their_hours") and not bool(night_prowl.in_their_hours()):
		return 0
	var at: Vector3 = _nearest((wreck as Node3D).global_position, night_prowl.origins)
	if at == Vector3.INF:
		return 0
	var came: int = 0
	for k in count:
		var d: Node = night_prowl.send_one_from(at + Vector3(0.0, 0.0, 1.2 * float(k)))
		if d != null:
			d.add_to_group(GROUP_DRAWN)
			if "drawn" in d:
				d.drawn = true
			d.came_from = "din: " + String(d.came_from)
			_brought = String(d.dino_type)
			came += 1
	return came

## The sleeping guards nearest the wreck, `count` of them, one by one.
func _wake_the_guards(wreck: Node, count: int) -> int:
	if not is_inside_tree():
		return 0
	var here: Vector3 = (wreck as Node3D).global_position
	var asleep: Array = []
	for g in get_tree().get_nodes_in_group("guard_dinos"):
		if is_instance_valid(g) and g.has_method("is_asleep") and g.is_asleep():
			asleep.append(g)
	asleep.sort_custom(func(a, b): return here.distance_squared_to((a as Node3D).global_position) \
		< here.distance_squared_to((b as Node3D).global_position))
	var hero: Node3D = get_tree().get_first_node_in_group("hero") as Node3D
	var came: int = 0
	for g in asleep.slice(0, count):
		g.wake(hero)
		_brought = String(g.dino_type)
		came += 1
	return came

## A few of the map's raiders in from the way into the valley nearest the wreck that nobody sees, by the
## wreck and on to the cabin -- in their hours only.
func _from_the_edge(wreck: Node, count: int) -> int:
	var cfg = get_node_or_null("/root/Config")
	var gs = get_node_or_null("/root/GameState")
	if wave_manager == null or not is_instance_valid(wave_manager) or cfg == null or gs == null:
		return 0
	var here: Vector3 = (wreck as Node3D).global_position
	var ways: Array = wave_manager.entry_positions.duplicate()
	ways.sort_custom(func(a, b): return here.distance_squared_to(a) < here.distance_squared_to(b))
	var origin: Vector3 = Vector3.INF
	for w in ways:
		if not wave_manager._watched(w):
			origin = w
			break
	if origin == Vector3.INF:
		return 0
	var core: Node3D = get_tree().get_first_node_in_group("core") as Node3D
	var came: int = 0
	for k in count:
		var species: String = String(wave_manager._species_to_spawn())
		if species == "" or not cfg.keeps_hours(species, String(gs.day_part())):
			continue
		var d: Node = wave_manager._instantiate_for_species(species)
		if d == null:
			continue
		var multipliers: Dictionary = gs.dino_stat_multipliers if "dino_stat_multipliers" in gs else {}
		d.setup(species, multipliers)
		var road: Array[Vector3] = [origin, here]
		if core != null:
			road.append(core.global_position)
		d.waypoints = road
		d.position = origin + Vector3(0.9 * float(k), 0.0, 0.0)
		if d.has_method("hurry_in"):
			d.hurry_in(float(cfg.RAIDS.get("edge_hurry", 1.0)))
		d.came_from = "din: " + String(wave_manager.origin_name(origin, true))
		var parent: Node = dinos_container if (dinos_container != null and is_instance_valid(dinos_container)) else self
		parent.add_child(d)
		d.setup(species, multipliers)
		d.add_to_group(GROUP_DRAWN)
		_brought = species
		var eb = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("dino_spawned"):
			eb.dino_spawned.emit(d)
		came += 1
	return came

func _nearest(to: Vector3, places: Array) -> Vector3:
	var best: Vector3 = Vector3.INF
	for p in places:
		if best == Vector3.INF or to.distance_squared_to(p) < to.distance_squared_to(best):
			best = p
	return best
