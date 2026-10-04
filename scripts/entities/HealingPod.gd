# res://scripts/entities/HealingPod.gd
class_name HealingPod
extends "res://scripts/entities/CraftingStation.gd"

## THE HEALING POD (Config.POD; GAME-DESIGN 3.0 -- the player, 2026-10-04: "睡觉就能回血不错……把未来船舱的睡觉装置科
## 幻化，有类似泡营养液式的身体完全恢复（七龙珠的泡水装置），这样就不用吃东西喝水"): the ship's regeneration tank, standing
## in the cabin where the kitchen stood (tools/generate_cabin.py pod). He climbs in through its hatch and floats in the
## fluid, and his body mends -- POD.heal_per_second hit points a second, till he is whole -- and the fluid feeds him:
## there is no eating and no drinking in the game. Its one job is a REST, on offer while he is hurt and paid for in
## time alone: while he floats in it nothing else in the room is worked (CoreCampfire) and nothing outside is done.
## Sent anywhere else, he climbs out (Hero._clear_orders), keeping what it mended; whole, it lets him out.
##
## Its tank is clicked, not walked round: what is solid of it is on the picking layer alone (Config.LAYER_PICK), so he
## can stand in it, and the walking mesh is not carved round it.

const REST: String = "rest"
## The station id it stands as in the cabin (Config.STATIONS).
const STATION: String = "pod"

func _init(p_station: String = STATION) -> void:
	super._init(p_station)

## The cabin's pod, or null: what the Rest command in his corner sends him to (HeroCommands, HUD).
static func of(tree: SceneTree) -> HealingPod:
	if tree == null:
		return null
	for st in tree.get_nodes_in_group(GROUP):
		if st is HealingPod and is_instance_valid(st):
			return st as HealingPod
	return null

func _ensure_components() -> void:
	super._ensure_components()
	var cfg = _get_config()
	collision_layer = int(cfg.LAYER_PICK) if (cfg and "LAYER_PICK" in cfg) else 64

func _pod(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.POD.get(key, fallback)) if (cfg and "POD" in cfg) else fallback

func _hero() -> Node:
	return get_tree().get_first_node_in_group("hero") if is_inside_tree() else null

## How much of him is missing: his hit points to his most.
func _missing() -> float:
	var hero = _hero()
	if hero == null or not ("current_hp" in hero) or not ("max_hp" in hero):
		return 0.0
	if "current_state" in hero and int(hero.current_state) == Hero.State.DEAD:
		return 0.0
	return maxf(0.0, float(hero.max_hp) - float(hero.current_hp))

## A rest, while he is hurt.
func recipes() -> Array[String]:
	return [REST] as Array[String]

func jobs() -> Array[String]:
	return recipes()

func can_offer(recipe_id: String) -> bool:
	return recipe_id == REST and _missing() > 0.0

func can_afford(recipe_id: String) -> bool:
	return recipe_id == REST

func waiting_on_materials() -> bool:
	return false

func inputs_of(_recipe_id: String) -> Dictionary:
	return {}

## As long as it takes to mend what is missing of him.
func time_of(recipe_id: String) -> float:
	if recipe_id != REST:
		return 0.0
	return _missing() / maxf(0.01, _pod("heal_per_second", 2.0))

func recipe_name(_recipe_id: String) -> String:
	return TranslationServer.translate("POD_REST")

func recipe_data(recipe_id: String) -> Dictionary:
	if recipe_id != REST:
		return {}
	return {"station": station_id, "inputs": {}, "time": time_of(REST), "name": "POD_REST"}

func job_done(_job_id: String) -> bool:
	return false

## What it is for -- or, with him whole, that there is nothing to mend.
func _purpose() -> String:
	return TranslationServer.translate("STATION_POD_DESC" if _missing() > 0.0 else "POD_WHOLE")

## Begun, he is sent to it to climb in (Hero.order_rest). Nothing to pay.
func begin(recipe_id: String) -> bool:
	if not can_offer(recipe_id):
		return false
	var hero = _hero()
	if hero == null or not hero.has_method("order_rest") or not hero.order_rest(self):
		return false
	active_recipe = REST
	progress = 0.0
	_refresh_label()
	return true

## The point in front of its hatch, on the room's floor: where he steps out to, whole.
func front() -> Vector3:
	var cfg = _get_config()
	var depth: float = float(cfg.get_visual_size("station/" + station_id).z) if (cfg and cfg.has_method("get_visual_size")) else 1.0
	var width: float = float(cfg.HERO.get("width", 0.8)) if (cfg and "HERO" in cfg) else 0.8
	var out: Vector3 = global_transform.basis.z
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 0.0001 else Vector3.BACK
	return global_position + out * (depth * 0.5 + width * 0.5 + 0.1)

## Whether he is floating in it now.
func occupied() -> bool:
	var hero = _hero()
	return hero != null and hero.has_method("is_resting_in") and bool(hero.is_resting_in(self))

## Whether it has him: floating in it, or on his way to it. While it has, nothing else in the cabin is worked
## (CoreCampfire).
func holds_him() -> bool:
	var hero = _hero()
	return active_recipe == REST and hero != null and hero.has_method("rest_pod") and hero.rest_pod() == self

## Sent anywhere else before he was whole, he has climbed out: the rest is over, and what it mended is his.
func _process(_delta: float) -> void:
	if active_recipe == REST and not holds_him():
		_stop()

## He mends while he floats in it: POD.heal_per_second a second; whole, it lets him out.
func work(delta: float) -> String:
	if active_recipe != REST or delta <= 0.0 or not occupied():
		return ""
	var hero = _hero()
	progress += delta
	hero.heal(_pod("heal_per_second", 2.0) * delta)
	if _missing() <= 0.0:
		_stop()
		var fx = _get_fx()
		if fx and fx.has_method("play_at") and is_inside_tree():
			fx.play_at("craft_done", global_position + Vector3(0.0, 0.8, 0.0))
		hero.climb_out()
	_refresh_label()
	return ""

func _stop() -> void:
	active_recipe = ""
	progress = 0.0
	_refresh_label()

## Its work bar is how whole he is.
func ratio() -> float:
	var hero = _hero()
	if active_recipe != REST or hero == null:
		return 0.0
	return clampf(float(hero.current_hp) / maxf(0.01, float(hero.max_hp)), 0.0, 1.0)
