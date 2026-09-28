# res://scripts/entities/Wall.gd
class_name Wall
extends "res://scripts/entities/Building.gd"

## A section of wall: a metre cell of the building grid, filled (Config.BUILD_CELL).
##
## v0.6 round two: "重新设计墙，让墙体逻辑简单清晰，墙必须让它们和别的建筑能更贴合". A wall is one
## cell, whole: a run of them has nothing to slip between, it stands flush against whatever is in
## the next cell, and it stops everybody -- the Hero included; his way through is a gate (Gate.gd).
##
## A PALISADE JOINS THE WALLS BESIDE IT. Its art is a post of sharpened logs in the middle of the
## cell and a run of them out to each side (tools/generate_props.py palisade); the runs towards
## the walls in the four cells beside it are shown, so a line of sections is one palisade and a
## corner is a corner. Walls only -- a palisade, a stone wall, a gate -- and not the cabin or a
## trap: a fence laid along the cabin was a fence with a corner in it ("贴着船舱建造就会变成有拐角的
## 栅栏"). With no wall beside it a section is a straight one, along the way it faces (`facing`:
## R turns it while it is placed, and a dragged run faces along the drag) -- it was all four runs,
## an X on open ground. Only the art depends on the neighbours: the collider is the whole cell
## whatever is shown. (The v0.4 fence that redrew itself from its neighbours broke because its
## SHAPE did.)
##
## WHAT THE GHOST SHOWS IS WHAT GOES UP ("pending的样子就是造下去的样子"): the build preview dresses its
## ghosts with this same code and the same neighbours, and shows the sections beside them dressed
## as they will be once it is built (Main._preview_neighbours).
##
## SHARPENED: whatever presses against it is hurt the whole time it is there (a chip, not a kill:
## Config.BUILDINGS.wall), body to body -- whoever is against it (Config.CONTACT_REACH), and
## nobody walking past. A fence does this, not each section: the animal takes one tick's worth
## however many sections are against it (Dino.spikes_touch). The damage lands on a fixed tick,
## on simulated time, so it scales with the HUD's speed like everything else.

## The art's runs, and the cell each one reaches towards.
const RUNS: Dictionary = {
	"Run_E": Vector2i(1, 0),
	"Run_W": Vector2i(-1, 0),
	"Run_S": Vector2i(0, 1),
	"Run_N": Vector2i(0, -1),
}

var contact_damage: float = 0.0
var contact_tick: float = 0.5

## Which way it faces (Trap.FACINGS): a wall facing north or south runs east to west, one facing
## east or west runs north to south. Only a section with no wall beside it goes by it (dress).
@export var facing: int = 0

## How far from its middle, straight out from a face, a raptor-sized body still touches it
## (touches): half the section, half a raptor, and Config.CONTACT_REACH. For callers that want a
## distance rather than to ask.
var contact_range: float:
	get:
		var cfg = _get_config()
		if cfg == null:
			return 1.0
		var half_raptor: float = float(cfg.get_visual_size("dino/raptor").x) * 0.5 if cfg.has_method("get_visual_size") else 0.4
		return float(cfg.get_building_footprint(building_type)) * 0.5 + half_raptor + float(cfg.CONTACT_REACH)

func _init() -> void:
	super("wall")
	building_type = "wall"
	_load_contact_config()

func _ready() -> void:
	super._ready()
	_load_contact_config()
	set_physics_process(contact_damage > 0.0)
	_connect_neighbour_events()
	refresh_joins.call_deferred()

func _exit_tree() -> void:
	super._exit_tree()
	var eb = _get_event_bus()
	if eb == null or not is_instance_valid(eb):
		return
	for sig in ["building_placed", "building_destroyed"]:
		if eb.has_signal(sig) and eb.is_connected(sig, _on_neighbour_changed):
			eb.disconnect(sig, _on_neighbour_changed)

func setup(type_id: String = "wall", p_cell: Vector2i = Vector2i.ZERO) -> void:
	super.setup(type_id, p_cell)
	_load_contact_config()

func _load_contact_config() -> void:
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(building_type):
		return
	var data: Dictionary = cfg.BUILDINGS[building_type]
	contact_damage = maxf(0.0, float(data.get("contact_damage", 0.0)))
	contact_tick = maxf(0.05, float(data.get("contact_tick", 0.5)))

# ==============================================================================
# Joining what is beside it
# ==============================================================================

func _connect_neighbour_events() -> void:
	var eb = _get_event_bus()
	if eb == null:
		return
	for sig in ["building_placed", "building_destroyed"]:
		if eb.has_signal(sig) and not eb.is_connected(sig, _on_neighbour_changed):
			eb.connect(sig, _on_neighbour_changed)

## Something went up or came down: if it was beside this section, the runs are looked at again --
## deferred, so the grid has taken it in or let it go first.
func _on_neighbour_changed(other: Node) -> void:
	if other == self or other == null or not is_instance_valid(other) or not (other is Node3D):
		return
	if not is_inside_tree():
		return
	if not is_wall(other):
		return        # only walls are joined
	# Beside it: its own half cell, one cell, and the other's half width.
	var other_half: float = _cell_size() * 0.5
	var cfg = _get_config()
	if cfg != null and "building_type" in other:
		other_half = float(cfg.get_building_footprint(String(other.building_type))) * 0.5
	var reach: float = _cell_size() * 1.5 + other_half
	var gap: Vector3 = (other as Node3D).global_position - global_position
	if maxf(absf(gap.x), absf(gap.z)) <= reach:
		refresh_joins.call_deferred()

## Shows the runs towards the walls beside it (Wall.dress) -- and towards the cells in `planned`,
## for the build preview's moment of showing it as it will be (Main._preview_neighbours).
func refresh_joins(planned: Array = []) -> void:
	if not is_inside_tree():
		return
	var body: Node = find_child("Body", false, false)
	if body == null:
		return
	dress(body, neighbours_of(_grid(), _grid().world_to_build_cell(global_position) if _grid() else Vector2i.ZERO, self, planned), facing)

## Which of the four cells beside `cell` hold a WALL -- a palisade, a stone wall, a gate, built or
## ordered -- other than `me`, or are among `extra` (a run being laid), keyed by run.
static func neighbours_of(gm: Node, cell: Vector2i, me: Node = null, extra: Array = []) -> Dictionary:
	var near: Dictionary = {}
	for run in RUNS:
		var there: Vector2i = cell + RUNS[run]
		var b: Node = gm.building_in_build_cell(there) if gm != null else null
		near[run] = (b != null and b != me and is_wall(b)) or extra.has(there)
	return near

## Whether `b` is a wall of any sort (Config.BUILDINGS kind "wall").
static func is_wall(b: Node) -> bool:
	if b == null or not is_instance_valid(b) or not ("building_type" in b):
		return false
	var cfg: Node = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	return cfg != null and cfg.has_method("get_building_kind") and String(cfg.get_building_kind(String(b.building_type))) == "wall"

## The runs a section shows, given the walls `near` it and the way it `faces`: the runs towards
## its neighbours; at the end of a line, the run to its one neighbour and the one opposite -- a
## straight section; with none, the two along the way it faces.
static func runs_shown(near: Dictionary, faces: int) -> Dictionary:
	var count: int = 0
	for run in RUNS:
		if near.get(run, false):
			count += 1
	var shown: Dictionary = {}
	for run in RUNS:
		var on: bool = bool(near.get(run, false))
		if count == 0:
			on = (run == "Run_E" or run == "Run_W") if posmod(faces, 2) == 0 else (run == "Run_N" or run == "Run_S")
		elif count == 1:
			on = on or bool(near.get(_opposite(run), false))
		shown[run] = on
	return shown

## Dresses a palisade's art for the walls beside it (runs_shown). Static, so the build preview
## dresses its ghosts the same way. A body without runs (a stone wall) is left as it is.
static func dress(body: Node, near: Dictionary, faces: int = 0) -> void:
	var shown: Dictionary = runs_shown(near, faces)
	for run in RUNS:
		var part: Node = body.find_child(run, true, false)
		if part == null or not (part is Node3D):
			continue
		(part as Node3D).visible = bool(shown[run])

static func _opposite(run: String) -> String:
	return {"Run_E": "Run_W", "Run_W": "Run_E", "Run_S": "Run_N", "Run_N": "Run_S"}[run]

func _grid() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("grid_manager")

func _cell_size() -> float:
	var cfg = _get_config()
	return float(cfg.BUILD_CELL) if (cfg and "BUILD_CELL" in cfg) else 1.0

# ==============================================================================
# Contact damage
# ==============================================================================

func _physics_process(delta: float) -> void:
	if not _stakes_are_live():
		return
	# Reported every frame rather than ticked here. The wall says "I am against you, for this
	# long"; how long it takes to draw blood is counted by the animal, once, however many
	# sections are saying it. See Dino.spikes_touch.
	report_contact(delta)

## A blueprint has no points on it yet, and a paused game must not grind anyone down while the
## player is reading the map.
func _stakes_are_live() -> bool:
	if contact_damage <= 0.0:
		return false
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return false
	return not _is_paused()

## One report of contact to everything of the attacking side pressed against it. Public so a test
## can drive one without waiting on the clock.
func report_contact(delta: float) -> int:
	if not is_inside_tree():
		return 0
	var hit_count: int = 0
	for d in get_tree().get_nodes_in_group("dinos"):
		if not _is_contact_target(d) or not touches(d):
			continue
		if d.has_method("spikes_touch"):
			if d.spikes_touch(contact_damage, contact_tick, delta):
				hit_count += 1
		else:
			d.take_damage(contact_damage)
			hit_count += 1
	return hit_count

## Whether `d` is against this section, body to body: its own half-width from the section's box,
## and a hand's breadth more (Config.CONTACT_REACH).
func touches(d: Node) -> bool:
	var cfg = _get_config()
	if cfg == null or not (d is Node3D):
		return false
	var half: float = 0.4
	if "dino_type" in d and cfg.has_method("get_visual_size"):
		half = float(cfg.get_visual_size("dino/" + String(d.dino_type)).x) * 0.5
	var reach: float = float(cfg.CONTACT_REACH) if "CONTACT_REACH" in cfg else 0.15
	return float(cfg.gap_to_building((d as Node3D).global_position, building_type, global_position)) <= half + reach

## One whole tick's worth of contact, delivered now. What a test means by "drive a tick without
## waiting on the clock", and the number it returns is how many animals it drew blood from.
func damage_touching_dinos() -> int:
	return report_contact(contact_tick)

func _is_contact_target(target: Variant) -> bool:
	if target == null or typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return false
	if not (target is Node3D) or target.is_queued_for_deletion() or not target.is_inside_tree():
		return false
	if "is_dead" in target and target.is_dead:
		return false
	if "current_hp" in target and target.current_hp <= 0.0:
		return false
	return target.has_method("take_damage")

## Damage per second while something is against it. The single place that figure is worked out:
## the build menu and the tests both read it from here.
func contact_dps() -> float:
	if contact_tick <= 0.0:
		return 0.0
	return contact_damage / contact_tick

func _is_paused() -> bool:
	var gs = _get_game_state()
	return gs != null and "is_paused" in gs and bool(gs.is_paused)

# ==============================================================================
# Presentation
# ==============================================================================

## Appends the stakes' bite to the usual HP line, so a player who selects a section can see why
## it is worth building rather than having to infer it from corpses.
func get_display_info() -> Dictionary:
	var info: Dictionary = super.get_display_info()
	info["contact_dps"] = contact_dps()
	return info

## A sharpened section's line: what it does to what touches it.
func _panel_status() -> String:
	if contact_dps() <= 0.0:
		return ""
	var raw: String = tr("STATUS_CONTACT_DAMAGE")
	return (raw % contact_dps()) if "%" in raw else raw
