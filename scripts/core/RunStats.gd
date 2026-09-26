# res://scripts/core/RunStats.gd
class_name RunStats
extends Node

## What a run has been, told back to the player (v0.6 T8, T9).
##
## Two accounts, kept by listening to the bus, so nothing that fights, builds or dies has
## to know this exists:
##   * each raid: how many were killed, what they left on the ground and which of his
##     buildings went down. Said when the raid is over (EventBus.raid_summary), so a raid
##     ends with its account rather than with silence (GAME-DESIGN 14.3, "what did that
##     cost me").
##   * the whole run: how long, how many raids held, how many killed, and where the Hero's
##     time went -- walking, gathering, building, fighting, in the cabin. The design's own
##     target is gathering under four tenths of it (GAME-DESIGN 4.6); this is what measures
##     it. The result screen shows it, and the log prints it when a run ends.

const GROUP: String = "run_stats"
## Where his time can go, in the order it is told.
const ACTIVITIES: Array[String] = ["walk", "gather", "build", "fight", "cabin", "idle"]

var run_seconds: float = 0.0
var raids_held: int = 0
var killed: int = 0
var seconds_by_activity: Dictionary = {}

var _in_raid: bool = false
var _raid_killed: int = 0
var _raid_drops: Dictionary = {}
var _raid_lost: Dictionary = {}
var _inside: bool = false
var _told: bool = false

func _ready() -> void:
	add_to_group(GROUP)
	reset()
	var eb = _bus()
	if eb == null:
		return
	eb.wave_started.connect(_on_wave_started)
	eb.wave_ended.connect(_on_wave_ended)
	eb.dino_died.connect(_on_dino_died)
	eb.building_destroyed.connect(_on_building_destroyed)
	eb.cabin_view_changed.connect(_on_cabin_view_changed)
	eb.game_won.connect(_on_run_over)
	eb.game_lost.connect(_on_run_over)

func _exit_tree() -> void:
	var eb = _bus()
	if eb == null:
		return
	for pair in [[eb.wave_started, _on_wave_started], [eb.wave_ended, _on_wave_ended],
			[eb.dino_died, _on_dino_died], [eb.building_destroyed, _on_building_destroyed],
			[eb.cabin_view_changed, _on_cabin_view_changed], [eb.game_won, _on_run_over],
			[eb.game_lost, _on_run_over]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])

## A new run: every account back to nothing.
func reset() -> void:
	run_seconds = 0.0
	raids_held = 0
	killed = 0
	seconds_by_activity.clear()
	for a in ACTIVITIES:
		seconds_by_activity[a] = 0.0
	_in_raid = false
	_inside = false
	_told = false
	_start_raid()

## Game time only: a paused game, or one that is over, is not time he spent.
func _process(delta: float) -> void:
	var gs = _state()
	if gs == null or gs.is_game_over or gs.is_paused:
		return
	run_seconds += delta
	var activity: String = _activity()
	if activity != "":
		seconds_by_activity[activity] = float(seconds_by_activity.get(activity, 0.0)) + delta

## What he is doing this moment: in the cabin, or whatever his state says out here.
func _activity() -> String:
	if _inside:
		return "cabin"
	var hero = get_tree().get_first_node_in_group("hero") if is_inside_tree() else null
	if hero == null or not ("current_state" in hero):
		return ""
	match int(hero.current_state):
		Hero.State.MOVING:
			return "walk"
		Hero.State.HARVESTING:
			return "gather"
		Hero.State.BUILDING:
			return "build"
		Hero.State.ATTACKING:
			return "fight"
		Hero.State.IDLE:
			return "idle"
	return ""

## Each activity's share of his time, 0..1, in ACTIVITIES order.
func time_shares() -> Dictionary:
	var total: float = 0.0
	for a in ACTIVITIES:
		total += float(seconds_by_activity.get(a, 0.0))
	var out: Dictionary = {}
	for a in ACTIVITIES:
		out[a] = float(seconds_by_activity.get(a, 0.0)) / total if total > 0.0 else 0.0
	return out

# ==============================================================================
# Raids
# ==============================================================================

func _start_raid() -> void:
	_raid_killed = 0
	_raid_drops.clear()
	_raid_lost.clear()

func _on_wave_started(_n: int, _is_big: bool) -> void:
	_start_raid()
	_in_raid = true

## A raider down: counted, and what it leaves is what its species leaves (Config.DINOS).
## The nest's guards are not the raid.
func _on_dino_died(dino: Node) -> void:
	if dino == null or not is_instance_valid(dino) or dino.is_in_group("guard_dinos"):
		return
	killed += 1
	_raid_killed += 1
	var cfg = _config()
	var species: String = String(dino.dino_type) if "dino_type" in dino else ""
	if cfg == null or not cfg.DINOS.has(species):
		return
	var drops: Dictionary = cfg.DINOS[species].get("drops", {})
	for res_id in drops:
		_raid_drops[res_id] = int(_raid_drops.get(res_id, 0)) + int(drops[res_id])

## One of his buildings brought down during a raid. Pulled down by him is not lost: that
## is a demolition, and it leaves the building with hit points to spare.
func _on_building_destroyed(building: Node) -> void:
	if not _in_raid or building == null or not is_instance_valid(building):
		return
	if not ("building_type" in building) or ("current_hp" in building and float(building.current_hp) > 0.0):
		return
	var type_id: String = String(building.building_type)
	_raid_lost[type_id] = int(_raid_lost.get(type_id, 0)) + 1

func _on_wave_ended(n: int) -> void:
	_in_raid = false
	var gs = _state()
	if gs != null and gs.is_game_over:
		return
	raids_held += 1
	var eb = _bus()
	if eb and eb.has_signal("raid_summary"):
		eb.raid_summary.emit(raid_summary(n))

## The raid just fought, as the HUD tells it: {"wave", "killed", "drops", "lost"}.
func raid_summary(n: int) -> Dictionary:
	return {"wave": n, "killed": _raid_killed, "drops": _raid_drops.duplicate(), "lost": _raid_lost.duplicate()}

func _on_cabin_view_changed(inside: bool) -> void:
	_inside = inside

## The log's line for the run (T9: the playtest numbers), printed as it ends.
func _on_run_over() -> void:
	# Once: a loss arriving after a win is ignored by GameState, but it is still a signal.
	if _told:
		return
	_told = true
	var parts: PackedStringArray = []
	var shares: Dictionary = time_shares()
	for a in ACTIVITIES:
		parts.append("%s %d%%" % [a, int(round(float(shares[a]) * 100.0))])
	print("[run] %d:%02d, %d raids held, %d killed; his time: %s" % [
		int(run_seconds) / 60, int(run_seconds) % 60, raids_held, killed, ", ".join(parts)])

# ==============================================================================
# Resolvers
# ==============================================================================

func _bus() -> Node:
	return get_node_or_null("/root/EventBus") if is_inside_tree() else null

func _state() -> Node:
	return get_node_or_null("/root/GameState") if is_inside_tree() else null

func _config() -> Node:
	return get_node_or_null("/root/Config") if is_inside_tree() else null
