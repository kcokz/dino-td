# res://scripts/entities/Workshop.gd
class_name Workshop
extends "res://scripts/entities/Building.gd"

## A workshop out in the open (GAME-DESIGN 5.4: "火大的加工在船舱外面：窑、炼铁炉、水车。窑火和炉烟不适合放进船舱；放在
## 外面，它们就是要守的建筑，被拆了就得重造"): the kiln that fires clay into bricks (station 2), the bloomery that smelts bog
## iron (station 3) -- a building he raises, and a bench he works at (Config.BUILDINGS kind "workshop").
##
## Its jobs are a bench's (CraftingStation, `station`, its id BUILDINGS.<id>.station; Config.RECIPES "station"): what it
## makes and what that costs, paid when a job is begun -- and he is sent to it then. The job goes on only while he
## stands at it working (5.4 rule 3: "加工要人在场才推进"; Hero._process_building), and walking away keeps what is done,
## as at the workbench. What it makes goes into the stock (5.4 rule 4: the fuel is taken from it, nobody stokes).
## While it works its fire shows: its model's own Flame part, and a fire's flame and glow at it (Fire.make_flame).

const GROUP: String = "workshops"

## Its bench: the jobs, their prices and their progress -- bare (no body, no click of its own: the click is the
## building's).
var station: CraftingStation = null
var _flame: GPUParticles3D = null
var _light: OmniLight3D = null
## When he last worked at it (Time.get_ticks_msec): a moment ago is "now" (is_tended).
var _tended_at: int = -100000
var _clock: float = 0.0
var _fire_shown: bool = false

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	_ensure_station()
	_make_the_fire()
	_show_the_fire(false)

func _process(delta: float) -> void:
	_clock += delta
	var burning: bool = is_working()
	if burning != _fire_shown:
		_show_the_fire(burning)
	if burning and _light != null:
		_light.light_energy = Fire.flicker_energy(_fire_cfg(), _clock + float(get_instance_id() % 97))
	if burning:
		_pump()

## The bellows (the bloomery's BellowsL and BellowsR, BUILDINGS.<id>.pump_*): up and down about their hinges by turns
## while it works -- the hide bags blowing the fire.
var _bellows_rest: Dictionary = {}

func _pump() -> void:
	var degrees: float = float(_row().get("pump_degrees", 0.0))
	if degrees <= 0.0:
		return
	var period: float = maxf(0.1, float(_row().get("pump_seconds", 1.0)))
	var k: int = 0
	for name in ["BellowsL", "BellowsR"]:
		var part: Node3D = find_child(name, true, false) as Node3D
		if part != null:
			if not _bellows_rest.has(name):
				_bellows_rest[name] = part.rotation
			var swing: float = deg_to_rad(degrees) * sin(TAU * _clock / period + PI * float(k))
			part.rotation = (_bellows_rest[name] as Vector3) + Vector3(swing, 0.0, 0.0)
		k += 1

func _ensure_station() -> void:
	if station != null:
		return
	station = CraftingStation.new(String(_row().get("station", building_type)))
	station.bare = true
	station.name = "Station"
	add_child(station)

# ==============================================================================
# Its jobs
# ==============================================================================

## Whether a job is begun here and waits on him: it stands finished, and something is under way at its bench.
func has_job() -> bool:
	return is_constructed and not is_destroyed and station != null and String(station.active_recipe) != ""

## A job begun here (its card): paid for at its bench, and he is sent to it. False, and nothing paid, when the bench
## will not take it (unaffordable, another under way, not finished standing).
func begin(recipe_id: String) -> bool:
	if not is_constructed or is_destroyed or station == null or not station.begin(recipe_id):
		return false
	_send_him()
	return true

## A stroke of his work at it (Hero, standing at it): the job goes on by `delta`. True once there is no job left --
## done now, or none to do.
func work(delta: float) -> bool:
	if not has_job():
		return true
	_tended_at = Time.get_ticks_msec()
	station.work(delta)
	return String(station.active_recipe) == ""

## Whether he is at it working now: he worked it a moment ago.
func is_tended() -> bool:
	return Time.get_ticks_msec() - _tended_at < 300

## Whether its fire is going: a job under way, and he at it.
func is_working() -> bool:
	return has_job() and is_tended()

func _send_him() -> void:
	if not is_inside_tree():
		return
	var hero: Node = get_tree().get_first_node_in_group("hero")
	if hero != null and hero.has_method("order_build"):
		hero.order_build(self, true)

## Pulled down or broken, the job in it is lost with it: its bench goes with the building.
func destroy() -> void:
	_show_the_fire(false)
	super.destroy()

# ==============================================================================
# The card
# ==============================================================================

## A building's card -- its health, its repair -- with its bench's work under way, and, while that waits on him, that
## it does (CraftingStation.get_display_info says it the bench's way).
func get_display_info() -> Dictionary:
	var info: Dictionary = super.get_display_info()
	if is_constructed and not is_upgrading() and has_job():
		info["work"] = station.ratio()
		info["work_label"] = station.recipe_name(String(station.active_recipe))
		info["status"] = "" if is_tended() else tr("STATION_ONLY_BESIDE_HIM")
	elif is_constructed and station != null:
		info["status"] = String(station.get_display_info().get("status", ""))
	return info

# ==============================================================================
# Its fire
# ==============================================================================

func _make_the_fire() -> void:
	var fire: Dictionary = _fire_cfg()
	var at: float = float(_row().get("flame_height", 0.3))
	if _flame == null:
		_flame = Fire.make_flame(fire, float(_row().get("flame_size", 1.0)))
		_flame.name = "WorkFlame"
		_flame.position = Vector3(0.0, at, 0.0)
		add_child(_flame)
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "WorkLight"
		_light.position = Vector3(0.0, at + float(fire.get("light_above", 0.4)), 0.0)
		_light.light_color = fire.get("light_color", Color(1.0, 0.6, 0.3))
		_light.omni_range = float(_row().get("light", 3.0))
		_light.omni_attenuation = float(fire.get("light_attenuation", 1.2))
		_light.shadow_enabled = false
		add_child(_light)

## Its fire shown or not: the particles and the glow, and its model's Flame part -- the particles and the glow where
## that part is (the kiln's stoke-hole, the bloomery's throat), else `flame_height` up its middle.
func _show_the_fire(on: bool) -> void:
	_fire_shown = on
	var at: Node3D = _flame_part()
	if at != null and _flame != null and _flame.is_inside_tree() and at.is_inside_tree():
		_flame.global_position = at.global_position
		if _light != null:
			_light.global_position = at.global_position + Vector3(0.0, float(_fire_cfg().get("light_above", 0.4)), 0.0)
	if _flame != null:
		_flame.emitting = on
		_flame.visible = on
	if _light != null:
		_light.visible = on
	for part in find_children("Flame*", "Node3D", true, false):
		if part != _flame and part != _light:
			(part as Node3D).visible = on

## Its model's own fire (the part named Flame), or null for a model with none.
func _flame_part() -> Node3D:
	for part in find_children("Flame*", "Node3D", true, false):
		if part != _flame and part != _light:
			return part as Node3D
	return null

func _row() -> Dictionary:
	var cfg = _get_config()
	return cfg.BUILDINGS.get(building_type, {}) if (cfg and "BUILDINGS" in cfg) else {}

func _fire_cfg() -> Dictionary:
	var cfg = _get_config()
	return cfg.FIRE if (cfg and "FIRE" in cfg) else {}
