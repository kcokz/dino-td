# res://scripts/entities/Dino.gd
class_name Dino
extends CharacterBody3D

## A dinosaur: a body that walks and bites, and a mind that decides where.
##
## v0.6 round two: "恐龙攻击还是有问题……有的会卡在一些防御不动了，或者直接在防御的周围抽搐，我需要更
## 专业的恐龙进攻逻辑，永远不要抽搐或者傻掉".
##
## The one it replaces moved by adding to its position every frame, with nothing physical to
## stop it, and was held in the world by five hand-written corrections -- snapped back onto the
## walking mesh, shoved out of other dinosaurs, slid off hillsides, stopped by a grid line check
## that disagreed with the mesh, turned by look_at every frame -- each pulling its own way, which
## from outside is a twitch; and where two of them cancelled out it stood still for ever. Rule 8
## in AGENT-TASKS.md, once more: those were the price of not using what the engine has.
##
## So now it is what the engine gives a walker, and a small mind on top:
##   * the WAY is the navigation server's route on a baked mesh (NavMaps), and the steering
##     round the others is its avoidance (an RVO agent on the world's map);
##   * the BODY is a round collider moved by the engine's collision (move_and_collide, sliding
##     along what it meets), so nothing overlaps anything and nothing walks through a wall
##     (Config.DINO_AI.collides_with);
##   * the MIND is one state machine (Mode) with a margin on every change of mind: it takes hold
##     at its reach and lets go only past it (reach_release), it thinks a few times a second
##     rather than every frame, it turns at a turning speed rather than snapping -- so nothing
##     can flip back and forth from one frame to the next;
##   * and it WATCHES ITS OWN HEADWAY: a dinosaur that has made none for a while looks at what is
##     holding it. A building in its way is bitten -- at once if it is not a wall, and a wall once
##     going round has failed twice -- and a crowd is waited out. It cannot stand still for ever,
##     which is the "傻掉" this replaces.
##
## What a species WANTS -- a trap, the Hero, the nearest wall -- is the one thing a behaviour
## subclass overrides (_preferred_target and the interest ranges): PackDino, SiegeDino.
## GuardDino is the nest's guards: a different mind on the same body.

enum State {
	WALKING = 0,
	ATTACKING = 1,
	DEAD = 2
}

## What it is doing, as opposed to what it looks like it is doing (State, which the animator
## reads):
##   MARCH   on the way to the cabin, by its waypoints
##   ENGAGE  going for something worth biting on the way -- a trap shooting at it, the Hero
##   ATTACK  standing at it and biting
##   BREACH  the way to the cabin is shut, and it is going for the building that shuts it
enum Mode {
	MARCH = 0,
	ENGAGE = 1,
	ATTACK = 2,
	BREACH = 3,
}

# ==============================================================================
# Configuration & Properties
# ==============================================================================
@export var dino_type: String = "raptor"
@export var max_hp: float = 3.0
@export var current_hp: float = 3.0
@export var speed: float = 4.0
@export var damage: float = 1.0
@export var attack_rate: float = 1.0
@export var arrival_threshold: float = 0.3
@export var lane_offset: float = 0.0

# Compatibility aliases
var move_speed: float:
	get: return speed
	set(v): speed = v

var attack_damage: float:
	get: return damage
	set(v): damage = v

var current_state: State = State.WALKING:
	set(v):
		if current_state != v:
			current_state = v
			if animator != null and is_instance_valid(animator):
				animator.play_state(current_state)

var animator: ActorAnimator = null
var state: State:
	get: return current_state
	set(v): current_state = v

var mode: Mode = Mode.MARCH

var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0

var current_target: Node = null
var target_building: Node:
	get: return current_target
	set(v): current_target = v

var assigned_slot: Vector3 = Vector3.ZERO
var is_dead: bool = false
var is_blocked: bool = false
var is_initialized: bool = false
var has_reached_destination: bool = false
var current_multipliers: Dictionary = {}

# Static building attack slots registry
static var _building_slots: Dictionary = {}

# Compatibility aliases
var has_reached_core: bool:
	get: return has_reached_destination
	set(v): has_reached_destination = v

var _stats_configured: bool:
	get: return is_initialized
	set(v): is_initialized = v

var _applied_multipliers: Dictionary:
	get: return current_multipliers
	set(v): current_multipliers = v

## The steering round the others: the navigation server's avoidance agent, on the world's map,
## where every dinosaur's is -- so they all steer round each other, whichever mesh each walks.
##
## A raw agent rather than a NavigationAgent3D node: the node never handed the velocity asked of
## it to the server (the server's agent stood at zero, and so did every answer -- measured, a
## raptor that moved one frame and stopped), while an agent set up here answers at once.
var _agent: RID = RID()
## Half its declared width: what it steers round others with, and how far its body reaches.
var _avoid_radius: float = 0.4
## The avoidance solver's last answer, and the requests made and answered. The solver answers
## on the navigation server's own step, so an answer trails its request by a frame -- and only
## by a frame. A test stepping an animal by hand, with no physics running, would otherwise be
## handed an answer from long ago and stand still; a request with no answer moves at what it
## asked for.
var _safe_velocity: Vector3 = Vector3.ZERO
var _requests: int = 0
var _answered: int = -1
## The route it is following, asked of the navigation server (NavMaps.path): its corners, the one
## it is heading for, and the goal it was asked for -- a new route costs a query, so only a goal
## that has really moved asks for one (Config.DINO_AI.regoal_distance).
var _route: PackedVector3Array = PackedVector3Array()
var _route_index: int = 0
var _nav_goal: Vector3 = Vector3.INF

## Its clocks. Thinking a few times a second rather than every frame is half of what keeps a
## mind from flickering; each animal starts at its own phase, so a raid does not all think on
## one frame.
var _think_clock: float = 0.0
var _route_clock: float = 0.0
var _bite_clock: float = 0.0
## The last answer to "is the way to the cabin shut", and the building shutting it.
var _way_sealed: bool = false
var _blocked_by: Node = null
## A building it has decided to go THROUGH because it could not get round it (_unstick): kept
## until it falls, whatever the route says -- or it would take hold and let go by turns.
var _stubborn: Node = null
## "Is what it wants shut away from it" (_shut_away), remembered for each thing it has asked
## about: instance id -> [asked at, by _mind_clock; the answer; the wall between].
var _shut_known: Dictionary = {}
## Seconds this animal has been thinking: what _shut_known's answers are dated by.
var _mind_clock: float = 0.0
## Headway: where it stood when the window opened, how long the window has run, and how many
## windows in a row it has made none.
var _headway_from: Vector3 = Vector3.INF
var _headway_clock: float = 0.0
var _stuck_count: int = 0
## Waiting its turn in a crowd: while this runs it stands rather than shoving (_unstick).
var _patience: float = 0.0
## Its own dice for when it next thinks, seeded once from the run's (GameState.rng), so a raid
## drifts out of step without every thought drawing on the run's dice.
var _mind_dice: RandomNumberGenerator = null

var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var status_bar: Node3D = null
var selection_ring: Node3D = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init(p_type: String = "raptor") -> void:
	dino_type = p_type

func _ready() -> void:
	add_to_group("dinos")
	_apply_collision_configuration()
	_ensure_components()
	_connect_event_bus()
	if not is_initialized:
		_load_config_stats()
	_mind_dice = RandomNumberGenerator.new()
	_mind_dice.seed = _dice().randi()
	# Its first thought is at once -- an animal put down beside the Hero goes for him on the frame
	# it lands -- and after that each thinks at its own moments (_next_think).
	_think_clock = 0.0
	_route_clock = 0.0
	# Not all on the same beat: the first call anywhere in its first stretch (SOUNDS.call_every).
	_call_clock = _next_call() * _voice_dice.randf()

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_destroyed"):
		if not eb.building_destroyed.is_connected(_on_building_destroyed):
			eb.building_destroyed.connect(_on_building_destroyed)
	# Something went up: the route it is on may run through it now. Asked again on the next step,
	# which is after the meshes are baked again (NavMaps rebakes on the same signal, in _process).
	if eb and eb.has_signal("building_completed"):
		if not eb.building_completed.is_connected(_on_world_changed):
			eb.building_completed.connect(_on_world_changed)
	if eb and eb.has_signal("boss_arrived"):
		if not eb.boss_arrived.is_connected(_on_boss_arrived):
			eb.boss_arrived.connect(_on_boss_arrived)

func _exit_tree() -> void:
	if _agent.is_valid():
		NavigationServer3D.free_rid(_agent)
		_agent = RID()
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("building_destroyed"):
		if eb.building_destroyed.is_connected(_on_building_destroyed):
			eb.building_destroyed.disconnect(_on_building_destroyed)
	if eb and is_instance_valid(eb) and eb.has_signal("building_completed"):
		if eb.building_completed.is_connected(_on_world_changed):
			eb.building_completed.disconnect(_on_world_changed)
	if eb and is_instance_valid(eb) and eb.has_signal("boss_arrived"):
		if eb.boss_arrived.is_connected(_on_boss_arrived):
			eb.boss_arrived.disconnect(_on_boss_arrived)
	if current_target != null:
		release_attack_slot(current_target, self)
	assigned_slot = Vector3.ZERO

func _on_world_changed(_building: Node = null) -> void:
	_nav_goal = Vector3.INF
	_route_clock = _rebake_grace()

## How long after the world changes shape it asks again whether the way is shut: long enough for
## the meshes to be baked again (NavMaps does it in the frame's _process, after this animal's
## physics step) -- asked sooner, it gets the old answer and keeps it for a whole recheck.
func _rebake_grace() -> float:
	return _ai("rebake_grace", 0.1)

## Whatever came down, it looks again at once rather than at its next thought: a fence that falls
## is the moment a raid pours through.
func _on_building_destroyed(building: Node) -> void:
	if building == null:
		return
	release_all_building_slots(building)
	if current_target == building:
		_let_go()
	if _blocked_by == building:
		_blocked_by = null
	if _stubborn == building:
		_stubborn = null
	_route_clock = _rebake_grace()
	_think_clock = _rebake_grace()
	_nav_goal = Vector3.INF

# ==============================================================================
# Attack Slot System
# ==============================================================================
## Places round a building to stand while biting it, so a raid rings a building rather than
## piling onto the one face nearest the path. A place, not a promise: reaching the building
## from it is still asked of _target_in_reach.

static func claim_attack_slot(building: Node, dino: Node) -> Vector3:
	if building == null or not is_instance_valid(building) or not (building is Node3D):
		return Vector3.ZERO
	var b_id: int = building.get_instance_id()
	if not _building_slots.has(b_id):
		_init_building_slots(building as Node3D)
	var slots: Array = _building_slots[b_id]
	var dino_id: int = dino.get_instance_id()

	# Check if this dino already holds a claimed slot
	for s in slots:
		if s.get("dino_id", 0) == dino_id:
			return s["pos"]

	var dino_pos: Vector3 = (dino as Node3D).global_position
	var near_first := func(a: int, b: int) -> bool:
		return dino_pos.distance_squared_to(slots[a]["pos"]) < dino_pos.distance_squared_to(slots[b]["pos"])
	# The free places, the inner ring before the outer, the nearest first in each; then the taken.
	var inner: Array = []
	var outer: Array = []
	var taken: Array = []
	for i in range(slots.size()):
		if slots[i].get("dino_id", 0) != 0:
			taken.append(i)
		elif i < 8:
			inner.append(i)
		else:
			outer.append(i)
	inner.sort_custom(near_first)
	outer.sort_custom(near_first)
	taken.sort_custom(near_first)
	# Only a place it can get to (can_stand_at): the nearest as the crow flies may be behind a fence
	# from it -- the back of a cabin walled behind -- where it would stand out of reach for ever.
	for i in inner + outer:
		if not dino.has_method("can_stand_at") or bool(dino.can_stand_at(slots[i]["pos"])):
			slots[i]["dino_id"] = dino_id
			return slots[i]["pos"]
	# Every place it can get to is taken: the nearest of those, shared, and the crowd sorts it out;
	# with none it can get to, the building itself.
	for i in taken:
		if not dino.has_method("can_stand_at") or bool(dino.can_stand_at(slots[i]["pos"])):
			return slots[i]["pos"]
	return (building as Node3D).global_position

static func release_attack_slot(building: Node, dino: Node) -> void:
	if building == null or not is_instance_valid(building):
		return
	var b_id: int = building.get_instance_id()
	if not _building_slots.has(b_id):
		return
	var dino_id: int = dino.get_instance_id()
	var slots: Array = _building_slots[b_id]
	for s in slots:
		if s.get("dino_id", 0) == dino_id:
			s["dino_id"] = 0
			break

static func release_all_building_slots(building: Node) -> void:
	if building == null:
		return
	var b_id: int = building.get_instance_id()
	_building_slots.erase(b_id)

static func clear_all_attack_slots() -> void:
	_building_slots.clear()

## Sixteen places a dinosaur can stand while chewing on a building, eight close and eight
## further out, measured from the building's FACE (Config.get_attack_slot_radius). Any that
## lands in a hill is dropped: a slot inside the scenery is a dinosaur standing in the scenery.
static func _init_building_slots(building: Node3D) -> void:
	var b_id: int = building.get_instance_id()
	var slots: Array = []
	var center: Vector3 = building.global_position
	var cfg_slots = building.get_node_or_null("/root/Config")
	var b_type: String = String(building.building_type) if ("building_type" in building) else ""
	var r_inner: float = 1.6
	var r_outer: float = 2.6
	if cfg_slots != null and cfg_slots.has_method("get_attack_slot_radius") and b_type != "":
		r_inner = float(cfg_slots.get_attack_slot_radius(b_type, false))
		r_outer = float(cfg_slots.get_attack_slot_radius(b_type, true))
	var half: float = 0.5
	if cfg_slots != null and cfg_slots.has_method("get_building_footprint") and b_type != "":
		half = float(cfg_slots.get_building_footprint(b_type)) * 0.5
	var standoff_inner: float = r_inner - half
	var standoff_outer: float = r_outer - half

	var gm_slots: Node = null
	if building.is_inside_tree():
		gm_slots = building.get_tree().get_first_node_in_group("grid_manager")

	for i in range(8):
		var angle: float = float(i) * (PI / 4.0)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var offset: Vector3 = _slot_offset(cfg_slots, b_type, dir, half, standoff_inner)
		if _slot_is_standable(gm_slots, center + offset):
			slots.append({ "pos": center + offset, "dino_id": 0 })

	for i in range(8):
		var angle: float = (float(i) + 0.5) * (PI / 4.0)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var offset: Vector3 = _slot_offset(cfg_slots, b_type, dir, half, standoff_outer)
		if _slot_is_standable(gm_slots, center + offset):
			slots.append({ "pos": center + offset, "dino_id": 0 })

	_building_slots[b_id] = slots

## A place to stand `standoff` out from a building's face, heading out from its middle along
## `dir`: where the ray leaves its box, then straight out from the face it leaves by -- or from
## the corner, out along the corner. Along the ray alone, a slot off the long side of the cabin
## stood closer to it than its standoff.
static func _slot_offset(cfg: Node, b_type: String, dir: Vector3, half: float, standoff: float) -> Vector3:
	var exit: Vector3 = dir * _extent_along(cfg, b_type, dir, half)
	var box := Vector2(half, half)
	if cfg != null and cfg.has_method("get_building_half") and b_type != "":
		box = cfg.get_building_half(b_type)
	var out := Vector3(signf(dir.x) if absf(exit.x) >= box.x - 0.001 else 0.0, 0.0,
		signf(dir.z) if absf(exit.z) >= box.y - 0.001 else 0.0)
	if out.length_squared() < 0.0001:
		out = dir
	return exit + out.normalized() * standoff

## How far a building's outside is from its middle, heading along `dir`.
static func _extent_along(cfg: Node, b_type: String, dir: Vector3, half: float) -> float:
	if cfg != null and cfg.has_method("building_extent_along") and b_type != "":
		return float(cfg.building_extent_along(b_type, dir))
	return half

static func _slot_is_standable(gm: Node, at: Vector3) -> bool:
	if gm == null or not is_instance_valid(gm) or not gm.has_method("is_cell_blocked"):
		return true
	return not gm.is_cell_blocked(gm.world_to_cell(at))

static func _safe_float(val: Variant, default_val: float = 1.0) -> float:
	if val == null:
		return default_val
	if val is float or val is int:
		var f: float = float(val)
		if is_nan(f) or is_inf(f):
			return default_val
		return f
	if val is String and (val as String).is_valid_float():
		var f: float = (val as String).to_float()
		if is_nan(f) or is_inf(f):
			return default_val
		return f
	return default_val

## Configures stats from Config and applies GameState multipliers.
func setup(type_id: String = "raptor", stat_multipliers: Dictionary = {}) -> void:
	dino_type = type_id
	is_initialized = true
	current_multipliers = stat_multipliers.duplicate()

	var mult_hp: float = _safe_float(stat_multipliers.get("hp"), 1.0)
	var mult_dmg: float = _safe_float(stat_multipliers.get("damage"), 1.0)
	var mult_spd: float = _safe_float(stat_multipliers.get("speed"), 1.0)

	var cfg = _get_config()
	if cfg and "DINOS" in cfg and cfg.DINOS.has(type_id):
		var data: Dictionary = cfg.DINOS[type_id]
		max_hp = float(data.get("hp", 3.0)) * mult_hp
		current_hp = max_hp
		damage = float(data.get("damage", 1.0)) * mult_dmg
		speed = float(data.get("speed", 4.0)) * mult_spd
		attack_rate = float(data.get("attack_rate", 1.0))
	else:
		max_hp = 3.0 * mult_hp
		current_hp = max_hp
		damage = 1.0 * mult_dmg
		speed = 4.0 * mult_spd
		attack_rate = 1.0

	# The species is only known here, and how big it is comes with it: the body, the collider
	# and the walker are refitted -- otherwise every species keeps the default's size, which is
	# how the big theropod spent four versions being small.
	_refresh_walker()
	if is_inside_tree():
		_refit_to_size()

func set_waypoints(wps: Array) -> void:
	waypoints.clear()
	for p in wps:
		if p is Vector3:
			waypoints.append(p)
	current_waypoint_index = 0
	has_reached_destination = false
	_face_now(_journey_goal())

# ==============================================================================
# Physics Processing: the mind, then the body
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	var was_at: Vector3 = global_position
	advance_towards_waypoint(delta)
	_report_pace(was_at, delta)
	_call_clock -= delta
	if _call_clock <= 0.0:
		_call_clock = _next_call()
		say("call")

## Tells the animator how far it really went this frame: a raptor held up at a gap stands
## rather than running on the spot (ActorAnimator.update_motion).
func _report_pace(was_at: Vector3, delta: float) -> void:
	if animator == null or not is_instance_valid(animator) or delta <= 0.0:
		return
	var moved := global_position - was_at
	moved.y = 0.0
	animator.update_motion(moved.length() / delta, delta)

## One step of the whole animal: think if it is time to, then act on it. Public, and under its
## old name, so a test can drive a dinosaur a frame at a time.
func advance_towards_waypoint(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	_think_clock -= delta
	_route_clock -= delta
	_mind_clock += delta
	if _think_clock <= 0.0:
		_think_clock = _next_think()
		_think()
	_act(delta)

## Seconds to its next thought: the declared interval, give or take a fifth, so a raid that
## spawned together drifts out of step.
func _next_think() -> float:
	var every: float = _ai("think_seconds", 0.25)
	if _mind_dice == null:
		return every
	return every * _mind_dice.randf_range(0.8, 1.2)

# ==============================================================================
# The mind
# ==============================================================================

## What to do next. Called a few times a second (Config.DINO_AI.think_seconds).
##
## In this order, each step only if the one before left it free:
##   1. what it is going for is still worth it, or it lets go;
##   2. something nearby outranks what it has (a trap shooting at it outranks a stake), or it
##      keeps what it has -- a mind that chose afresh on every thought would swap between two
##      equal targets on every one;
##   3. with nothing to bite on the way: is the way to the cabin shut? Then the building
##      shutting it is what to go for (BREACH). Otherwise, on to the cabin.
func _think() -> void:
	_unstack()
	# Going home, its hours over: nothing to stop for on the way (go_home).
	if going_home:
		return
	if current_target != null and not _still_wanted(current_target):
		_let_go()
	var want: Node = _find_threat_priority_target()
	if want != null and want != current_target and _outranks(want, current_target):
		_take(want, Mode.BREACH if _is_wall(want) else Mode.ENGAGE)
	if current_target == null:
		var blocker: Node = _building_in_the_way()
		if blocker != null:
			_take(blocker, Mode.BREACH)
		else:
			_set_mode(Mode.MARCH)

## Carries out the current mode for one frame.
func _act(delta: float) -> void:
	match mode:
		Mode.ATTACK:
			_hold_and_bite(delta)
		Mode.ENGAGE, Mode.BREACH:
			if not _is_target_valid(current_target):
				_let_go()
				_march(delta)
			elif _target_in_reach(current_target):
				# At the cabin, it says so once (dino_reached_core).
				if current_target == _cabin():
					_reach_destination()
				else:
					_begin_attack()
			else:
				_travel(_engage_spot(), delta)
		_:
			_march(delta)
	_watch_headway(delta)

## Still worth going for? Gone, or no longer what made it interesting -- the Hero walked off, a
## wall stopped being in the way -- and it is let go.
func _still_wanted(target: Node) -> bool:
	if not _is_target_valid(target):
		return false
	if target == _stubborn:
		return true
	if not _should_bite(target):
		return false
	# Shut away from where it stands: let go -- what it wants is got at through the wall between,
	# found again on this thought (_find_threat_priority_target).
	if _shut_away(target):
		return false
	# The Hero is chased only while he stays near, or loud (PackDino.hero_interest_range).
	if target.is_in_group("hero"):
		var keep: float = hero_interest_range() + _ai("chase_slack", 2.0)
		return _hero_is_provoking() or global_position.distance_to((target as Node3D).global_position) <= keep
	return true

## Whether `want` is worth dropping `have` for: always, for nothing; otherwise only for
## something ranked higher (_rank) -- never for its equal, which is what keeps a raptor between
## two stakes from swapping on every thought.
func _outranks(want: Node, have: Node) -> bool:
	if have == null or not _is_target_valid(have):
		return true
	return _rank(want) > _rank(have)

## How much it cares about a thing, for _outranks: the Hero when he is loud, then what is
## shooting at it, then any building.
func _rank(node: Node) -> int:
	if node == null:
		return 0
	if node.is_in_group("hero"):
		return 3 if _hero_is_provoking() else 1
	if _is_shooter(node):
		return 2
	return 1

## Two put down on the very same spot: the engine recovers a body from inside another along the
## way out, and from dead centre there is none -- the pair stays one inside the other (measured:
## 0.000 m apart a second later). A nudge along a heading of its own breaks the tie, and the
## engine's recovery does the rest. Anything short of dead centre is the engine's already.
func _unstack() -> void:
	if not is_inside_tree():
		return
	var within: float = _ai("stacked_within", 0.05)
	for other in get_tree().get_nodes_in_group("dinos"):
		if other == self or not (other is Node3D) or ("is_dead" in other and other.is_dead):
			continue
		if _flat(global_position).distance_to(_flat((other as Node3D).global_position)) <= within:
			var heading: float = float(get_instance_id() % 628) * 0.01
			_move_body(Vector3(cos(heading), 0.0, sin(heading)) * _avoid_radius)
			return

## Commits to `target`: a place to stand at it, and the mode.
func _take(target: Node, new_mode: Mode) -> void:
	if current_target != null and current_target != target:
		release_attack_slot(current_target, self)
	if target != current_target and target != null:
		_alert()
	current_target = target
	assigned_slot = claim_attack_slot(target, self) if _is_building(target) else Vector3.ZERO
	_set_mode(new_mode)

## Drops what it was going for, and goes on to the cabin.
func _let_go() -> void:
	if current_target != null:
		release_attack_slot(current_target, self)
	if current_target == _stubborn:
		_stubborn = null
	current_target = null
	assigned_slot = Vector3.ZERO
	is_blocked = false
	_set_mode(Mode.MARCH)

func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	current_state = State.ATTACKING if new_mode == Mode.ATTACK else State.WALKING
	# A new mind is a new window for headway: it has not been failing at THIS yet.
	_headway_clock = 0.0
	_headway_from = global_position
	if new_mode != Mode.ATTACK:
		_stuck_count = 0

## Standing at what it bites, biting it.
func _begin_attack() -> void:
	is_blocked = true
	_set_mode(Mode.ATTACK)
	# Half an interval to the first bite: quick, but not on the frame it arrives.
	_bite_clock = _bite_interval() * 0.5
	velocity = Vector3.ZERO

func _bite_interval() -> float:
	return 1.0 / maxf(0.1, attack_rate)

# ==============================================================================
# The body
# ==============================================================================

## On the way to the cabin, by its waypoints. The last waypoint is the cabin: when the cabin is
## in reach it is bitten, and the first time says so on the bus (dino_reached_core).
func _march(delta: float) -> void:
	if going_home:
		_walk_home(delta)
		return
	var cabin: Node = _cabin()
	if cabin != null and _target_in_reach(cabin):
		_reach_destination()
		return
	_skip_reached_waypoints()
	# The last leg is the cabin: gone for as the thing to bite, from a place round it there is a way
	# to (claim_attack_slot) -- not as the end of the road, which the mesh brought it as near to as
	# it could get: behind a fence at the cabin's back, out of reach, where a raid milled for the
	# whole of it (v0.6 round three: "大多数都在后面转来转去，而且还是有抽搐的情况，判断路径不聪明").
	if cabin != null and current_waypoint_index >= waypoints.size() - 1:
		_take(cabin, Mode.ENGAGE)
		return
	# No cabin to bite (a bare fixture): the end of the road is the destination, reached when it is
	# stood on (arrival_threshold) -- and passed, as far as the count of waypoints goes.
	if cabin == null and not waypoints.is_empty() and current_waypoint_index >= waypoints.size() - 1:
		if current_waypoint_index >= waypoints.size() \
				or _flat(global_position).distance_to(_flat(waypoints[waypoints.size() - 1])) <= arrival_threshold:
			current_waypoint_index = waypoints.size()
			_reach_destination()
			_drive(Vector3.ZERO, delta, Vector3.INF)
			return
	_travel(_journey_goal(), delta)

## Walks past the waypoints it has reached: an intermediate one counts as reached from a little
## way off (Config.DINO_AI.waypoint_reach) -- a crowd cannot all stand on one point, and the ones
## that could not would otherwise mill round it.
func _skip_reached_waypoints() -> void:
	var reach: float = _ai("waypoint_reach", 1.0)
	while current_waypoint_index < waypoints.size() - 1:
		if _flat(global_position).distance_to(_flat(_lane_point(current_waypoint_index))) > reach:
			return
		current_waypoint_index += 1

## Heads for `goal`, along the agent's route, at `pace` of its speed.
func _travel(goal: Vector3, delta: float, pace: float = 1.0) -> void:
	if goal == Vector3.INF:
		_drive(Vector3.ZERO, delta, Vector3.INF)
		return
	var step: Vector3 = _next_step_towards(goal)
	var to: Vector3 = step - global_position
	to.y = 0.0
	var desired := Vector3.ZERO
	if to.length() > 0.05 and _patience <= 0.0:
		desired = to.normalized() * speed * pace
	_drive(desired, delta, goal)

## The next corner of the route to `goal` -- or `goal` itself, when there is no mesh to ask.
##
## The route is the navigation server's (NavMaps.path, funnelled: the corners a person would
## draw), asked again only when the goal has moved (Config.DINO_AI.regoal_distance) or the animal
## has been pushed off it (path_max_distance). Where the route stops short of the goal -- the goal
## is inside something, or shut away -- it heads for the route's end, the nearest it can stand:
## there it gets nowhere, and what is holding it is dealt with (_unstick).
func _next_step_towards(goal: Vector3) -> Vector3:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return goal
	if _nav_goal == Vector3.INF or _flat(_nav_goal).distance_to(_flat(goal)) > _ai("regoal_distance", 0.3) \
			or _route.is_empty() or _off_route():
		_nav_goal = goal
		_route = maps.path(global_position, goal, _map_kind())
		_route_index = 1
	var near: float = _ai("path_desired_distance", 0.5)
	while _route_index < _route.size() and _flat(global_position).distance_to(_flat(_route[_route_index])) <= near:
		_route_index += 1
	if _route_index < _route.size():
		return _route[_route_index]
	if _route.is_empty():
		return goal
	var end: Vector3 = _route[_route.size() - 1]
	return goal if _flat(end).distance_to(_flat(goal)) <= near else end

## Whether it has been pushed further off the leg of its route it is on than
## Config.DINO_AI.path_max_distance -- by the others, or round a corner -- and should ask again.
func _off_route() -> bool:
	if _route_index <= 0 or _route_index >= _route.size():
		return false
	var a: Vector2 = _flat(_route[_route_index - 1])
	var b: Vector2 = _flat(_route[_route_index])
	var p: Vector2 = _flat(global_position)
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t) > _ai("path_max_distance", 2.0)

## Moves the body at `desired` (flat, metres a second), after the solver has had its say, and
## turns it -- to where it is going, or, when it is not going anywhere, to `look_at_point`.
func _drive(desired: Vector3, delta: float, look_at_point: Vector3) -> void:
	_patience = maxf(0.0, _patience - delta)
	var v: Vector3 = _avoid(desired)
	velocity = Vector3(v.x, 0.0, v.z)
	var y: float = global_position.y
	if is_inside_tree() and get_world_3d() != null:
		_move_body(velocity * delta)
	else:
		global_position += velocity * delta
	global_position.y = y
	var moving: Vector3 = velocity if velocity.length() > _ai("turn_min_speed", 0.3) else Vector3.ZERO
	if moving != Vector3.ZERO:
		_turn_towards(moving, delta)
	elif look_at_point != Vector3.INF:
		_turn_towards(look_at_point - global_position, delta)

## Moves the body by `motion`, sliding along what it meets: the engine's collision
## (move_and_collide), up to Config.DINO_AI.slide_steps times, so a body grazing a wall or a
## neighbour keeps going along it. By the frame's own delta rather than move_and_slide's physics
## step, so an animal driven by hand goes as far as the game would take it.
func _move_body(motion: Vector3) -> void:
	var left: Vector3 = motion
	for i in range(int(_ai("slide_steps", 4))):
		# Even standing still it is moved once: moving is where the engine recovers a body from
		# inside another -- two put down on one spot are pushed apart by standing there.
		if i > 0 and left.length_squared() < 0.00000001:
			return
		var hit: KinematicCollision3D = move_and_collide(left)
		if hit == null:
			return
		var normal: Vector3 = hit.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.000001:
			return
		left = hit.get_remainder().slide(normal.normalized())
		left.y = 0.0

## The solver's safe version of `wanted`: steered round the others (the engine's RVO).
func _avoid(wanted: Vector3) -> Vector3:
	if not _agent.is_valid():
		return wanted
	NavigationServer3D.agent_set_position(_agent, global_position)
	NavigationServer3D.agent_set_velocity(_agent, wanted)
	_requests += 1
	if _requests - _answered > 1:
		return wanted          # no fresh answer: the first frame, or nothing is ticking
	return _safe_velocity

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	_answered = _requests

## Turns towards `dir` at its turning speed (Config.DINO_AI.turn_speed). Never a snap: an animal
## whose heading was set outright, every frame, to a velocity the solver nudges about turned
## with every nudge -- which is the twitch.
func _turn_towards(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var want: float = atan2(-dir.x, -dir.z)
	var step: float = deg_to_rad(_ai("turn_speed", 540.0)) * maxf(0.0, delta)
	rotation.y = rotation.y + clampf(wrapf(want - rotation.y, -PI, PI), -step, step)

## Faces `point` at once, for the moment it is put down somewhere.
func _face_now(point: Vector3) -> void:
	if point == Vector3.INF or not is_inside_tree():
		return
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(-dir.x, -dir.z)

## Standing at what it bites: facing it, biting on the clock, and letting go only when it is gone
## or has moved PAST its reach by a margin (Config.DINO_AI.reach_release). One step back from the
## Hero is not an escape; and a raptor that let go at the very reach it took hold at would let go
## and take hold on alternate frames.
func _hold_and_bite(delta: float) -> void:
	velocity = Vector3.ZERO
	if not _is_target_valid(current_target):
		_let_go()
		return
	if not _target_in_reach(current_target, _ai("reach_release", 0.35)):
		_out_of_reach()
		return
	_turn_towards((current_target as Node3D).global_position - global_position, delta)
	_bite_clock -= delta
	if _bite_clock <= 0.0:
		_bite_clock += _bite_interval()
		perform_attack()

## What it was biting is past its reach: after it, if it is still worth it (_still_wanted) --
## the Hero stepping back is still the Hero -- and otherwise let go. Nothing is bitten from across
## the map, and nothing is followed there.
func _out_of_reach() -> void:
	if _still_wanted(current_target):
		_set_mode(Mode.BREACH if _is_wall(current_target) else Mode.ENGAGE)
	else:
		_let_go()

## Where to stand to bite what it is going for: its slot round a building, or the thing itself
## when it walks about.
func _engage_spot() -> Vector3:
	if assigned_slot != Vector3.ZERO:
		return assigned_slot
	if current_target != null and is_instance_valid(current_target) and current_target is Node3D:
		return (current_target as Node3D).global_position
	return _journey_goal()

## HEADWAY. Every window (Config.DINO_AI.stuck_window) a travelling animal is asked how far it
## got, and one that got nowhere is looked at (_unstick). One biting, or waiting on purpose, is
## not travelling.
func _watch_headway(delta: float) -> void:
	if mode == Mode.ATTACK or _patience > 0.0:
		_headway_clock = 0.0
		_headway_from = global_position
		return
	if _headway_from == Vector3.INF:
		_headway_from = global_position
	_headway_clock += delta
	if _headway_clock < _ai("stuck_window", 1.2):
		return
	var moved: float = _flat(global_position).distance_to(_flat(_headway_from))
	_headway_clock = 0.0
	_headway_from = global_position
	if moved >= _ai("stuck_distance", 0.25):
		_stuck_count = 0
		return
	_stuck_count += 1
	_unstick()

## Whether it is on its way back to the nest, its hours over (go_home).
var going_home: bool = false

## Its hours are over (Config.DINOS.<id>.hours, GAME-DESIGN 9.3): it lets go of what it was at and
## goes back to the nest, and is gone there -- not killed, nothing left behind.
func go_home(nest: Vector3) -> void:
	if is_dead or going_home:
		return
	_let_go()
	going_home = true
	set_waypoints([nest])
	_nav_goal = Vector3.INF

## On its way home: along its route to the nest, and gone once there (EventBus.dino_went_home).
func _walk_home(delta: float) -> void:
	if waypoints.is_empty():
		return
	var nest: Vector3 = waypoints[waypoints.size() - 1]
	if _flat(global_position).distance_to(_flat(nest)) <= _ai("home_reach", 2.0):
		var eb = _get_event_bus()
		if eb and eb.has_signal("dino_went_home"):
			eb.dino_went_home.emit(self)
		queue_free()
		return
	_travel(nest, delta)

## It has got nowhere. What is holding it?
##   * a building it is pressed against: bitten -- at once if it is not a wall (a target, and
##     right there), a wall once going round has failed twice, and at once by anything that does
##     not go round walls at all. It keeps at it until the building falls (_stubborn);
##   * nothing built -- the others, in a crowd at a gap: it waits its turn a moment
##     (Config.DINO_AI.patience) rather than shoving, which in a jam is a shuffle; and then a
##     fresh route, in case the old one went stale.
func _unstick() -> void:
	# Going home it bites nothing: it only asks its way again.
	if going_home:
		_nav_goal = Vector3.INF
		return
	var holder: Node = _building_pressed_against()
	var crowd: int = _bodies_pressed_against()
	if holder != null and holder != current_target:
		# A wall it could go round is bitten only when the WALL is what stops it -- nobody else
		# pressed against it, and still nowhere after several tries. A raptor in a crowd at a
		# fence is held up by the crowd, and chewing the fence would be the "stops at a fence it
		# could walk round" this was written against.
		var wall_holds_it: bool = _is_wall(holder) and walks_round_walls()
		if not wall_holds_it or (crowd == 0 and _stuck_count >= int(_ai("wall_patience", 3))):
			_stubborn = holder
			_take(holder, Mode.BREACH)
			return
	if holder != null and holder == current_target and not _target_in_reach(holder):
		# Pressed against what it is going for and still out of reach: its slot is on the far
		# side. The face it is at is as good as any.
		release_attack_slot(holder, self)
		assigned_slot = Vector3.ZERO
	elif current_target != null and _is_building(current_target) and not _target_in_reach(current_target):
		# Going for a building, out of its reach and getting nowhere: waiting in the outer ring, or
		# at a place it could not get to after all. It chooses again -- the inner ring first, and
		# only a place it can get to (claim_attack_slot) -- so it moves in as the raid thins. It stood
		# in the outer ring, out of reach, to the end of the raid before (found playing, v0.6 round
		# three), two of those places behind the fence at the cabin's back.
		release_attack_slot(current_target, self)
		assigned_slot = claim_attack_slot(current_target, self)
	# Held up by the Hero himself, standing in its way, time and again: he is what is in the way,
	# and what is in the way is bitten -- whether or not this species came for him.
	var man: Node = _hero_pressed_against()
	if man != null and man != current_target and _stuck_count >= 2 and _is_target_valid(man):
		_take(man, Mode.ENGAGE)
		return
	if crowd > 0:
		_patience = _ai("patience", 0.8)
	_nav_goal = Vector3.INF

## The building its body is up against, favouring the one ahead of it, or null. Asked of the
## physics space, which is what is actually stopping it.
func _building_pressed_against() -> Node:
	if not is_inside_tree() or get_world_3d() == null:
		return null
	var query := _touch_query(_building_layers())
	var goal: Vector3 = _engage_spot() if current_target != null else _journey_goal()
	var ahead: Vector3 = _flat3(goal - global_position).normalized() if goal != Vector3.INF else Vector3.ZERO
	var best: Node = null
	var best_score: float = -INF
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var b: Node = _building_of(hit.get("collider"))
		if b == null or not _is_target_valid(b):
			continue
		var to: Vector3 = _flat3((b as Node3D).global_position - global_position)
		var score: float = -to.length() + (to.normalized().dot(ahead) if to.length() > 0.001 else 0.0)
		if score > best_score:
			best_score = score
			best = b
	return best

## The Hero, if its body is up against him, or null.
func _hero_pressed_against() -> Node:
	if not is_inside_tree() or get_world_3d() == null:
		return null
	for hit in get_world_3d().direct_space_state.intersect_shape(_touch_query(_cfg_int("LAYER_HERO", 4)), 4):
		var body: Node = hit.get("collider") as Node
		if body != null and body.is_in_group("hero"):
			return body
	return null

## How many other walkers its body is up against.
func _bodies_pressed_against() -> int:
	if not is_inside_tree() or get_world_3d() == null:
		return 0
	var query := _touch_query(_cfg_int("LAYER_DINO", 8) | _cfg_int("LAYER_HERO", 4))
	return get_world_3d().direct_space_state.intersect_shape(query, 8).size()

## A ball a little bigger than its body, at its middle, looking at `mask`.
func _touch_query(mask: int) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _avoid_radius + _ai("press_reach", 0.3)
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, _probe_height(), 0.0))
	query.collision_mask = mask
	query.exclude = [get_rid()]
	return query

## The building a collider belongs to, if it is one.
func _building_of(collider: Variant) -> Node:
	var node: Node = collider as Node
	for i in range(3):
		if node == null:
			return null
		if node.is_in_group("buildings") or node.is_in_group("core"):
			return node
		node = node.get_parent()
	return null

## What it is up against, for callers that ask. The physics' answer.
func check_obstacle() -> Node:
	return _building_pressed_against()

# ==============================================================================
# The way to the cabin, and what shuts it
# ==============================================================================

## Whether there is no way to the cabin at all. The question a wall is judged by: a wall with a
## way round it is a funnel and is walked round; only a wall that shuts the way is bitten.
##
## Asked of the mesh the animal walks, and no more than every Config.DINO_AI.route_check_seconds:
## the answer costs a route, and a fence coming down half a second late is not something anyone
## can see.
func _way_is_sealed() -> bool:
	if _route_clock > 0.0:
		return _way_sealed
	_route_clock = _ai("route_check_seconds", 1.0)
	_way_sealed = false
	var goal: Vector3 = _cabin_goal()
	if goal == Vector3.INF:
		return false
	_way_sealed = not _there_is_a_way_round(goal)
	if not _way_sealed:
		_blocked_by = null
	return _way_sealed

## The building to go through when the way is shut, or null when it is open.
##
## THE WALL IN THE WAY IS THE FIRST ONE ON THE ROUTE THAT IGNORES WALLS. The siege mesh
## (NavMaps.For.SIEGE) is baked with walls left out, so its route to the cabin runs straight
## through them -- and the first wall that route crosses is the one between this animal and the
## cabin. A hillside is never the answer: it cannot be bitten, and the siege mesh goes round it.
func _building_in_the_way() -> Node:
	if not walks_round_walls() or not _way_is_sealed():
		return null
	if _blocked_by != null and is_instance_valid(_blocked_by) and _is_target_valid(_blocked_by):
		return _blocked_by
	_blocked_by = _first_wall_on_the_way(_cabin_goal())
	return _blocked_by

## Whether sent to `spot` it would get there: the end of its route to it is the spot itself, near
## enough (Config.DINO_AI.slot_stand_slack) -- not the nearest it could get, the far side of a
## fence from it. With no mesh to ask, it can.
func can_stand_at(spot: Vector3) -> bool:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready() or not is_inside_tree():
		return true
	var route: PackedVector3Array = maps.path(global_position, spot, _map_kind())
	if route.is_empty():
		return false
	return _flat(route[route.size() - 1]).distance_to(_flat(spot)) <= _ai("slot_stand_slack", 0.5)

## Whether there is any route to `goal` on this animal's own mesh.
func _there_is_a_way_round(goal: Vector3) -> bool:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return true    # nothing to ask, so nothing is sealed
	return maps.is_reachable(global_position, goal, _map_kind())

## The first building the wall-less route to `goal` passes through.
func _first_wall_on_the_way(goal: Vector3) -> Node:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready() or not is_inside_tree() or goal == Vector3.INF:
		return null
	var route: PackedVector3Array = maps.path(global_position, goal, NavMaps.For.SIEGE)
	if route.size() < 2:
		route = PackedVector3Array([global_position, goal])
	var space := get_world_3d().direct_space_state
	var lift := Vector3(0.0, _probe_height(), 0.0)
	for i in range(route.size() - 1):
		var query := PhysicsRayQueryParameters3D.create(route[i] + lift, route[i + 1] + lift, _building_layers())
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var b: Node = _building_of(hit.get("collider"))
		if b != null and _is_target_valid(b):
			return b
	return null

## Which mesh this animal walks: round walls, or -- a siege animal -- through them.
func _map_kind() -> int:
	return NavMaps.For.RAID if walks_round_walls() else NavMaps.For.SIEGE

## Whether stopping to bite this is the right thing to do.
##
## A WALL IS ONLY WORTH BITING WHEN IT IS ACTUALLY IN THE WAY. If there is a way round it, go
## round -- that is what makes a fence a funnel that decides where the raid arrives, rather than
## a sack of hit points every raid chews through in the same place. Anything else -- a trap, the
## wreck -- is attacked on its own merits: those are targets, not obstacles.
func _should_bite(node: Variant) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not _is_wall(node):
		return true
	if not walks_round_walls():
		return true
	# The wall between it and something it wants that is shut away (_shut_away) is in the way as
	# surely as one that shuts the way to the cabin.
	return _way_is_sealed() or _is_the_way_through(node)

## Whether what it wants -- a trap shooting at it from inside a sealed ring, the Hero behind a
## fence -- has no way round to it on the mesh this animal walks; and so (_wall_before) the wall
## to go through: the first the route that ignores walls passes (_first_wall_on_the_way). Found
## playing (v0.6 round three, "摆成这样的时候，恐龙进攻又会傻站着不攻击了"): a raid went for the traps in
## a yard inside the ring, stood at the fence nearest them -- in a crowd, which never bites a fence
## it might go round (_unstick) -- and was shot where it stood. Asked of the mesh no more than every
## Config.DINO_AI.route_check_seconds for the same target.
func _shut_away(target: Variant) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node3D) or not walks_round_walls():
		return false
	if _is_wall(target) or not is_inside_tree():
		return false
	var id: int = (target as Node).get_instance_id()
	var known: Array = _shut_known.get(id, [])
	if not known.is_empty() and _mind_clock - float(known[0]) < _ai("route_check_seconds", 1.0) \
			and (not bool(known[1]) or _is_target_valid(known[2])):
		return bool(known[1])
	var goal: Vector3 = (target as Node3D).global_position
	var shut: bool = not _there_is_a_way_round(goal)
	if _shut_known.size() >= 8:
		_shut_known.clear()
	_shut_known[id] = [_mind_clock, shut, _first_wall_on_the_way(goal) if shut else null]
	return shut

## The wall between it and `target`, as _shut_away last found it, or null.
func _wall_before(target: Node) -> Node:
	var known: Array = _shut_known.get(target.get_instance_id(), [])
	var wall: Variant = known[2] if (not known.is_empty() and bool(known[1])) else null
	return wall if _is_target_valid(wall) else null

## Whether `wall` is what stands between it and something it wants that was, when last asked,
## shut away -- so going through it is going somewhere.
func _is_the_way_through(wall: Node) -> bool:
	for id in _shut_known:
		var known: Array = _shut_known[id]
		if bool(known[1]) and known[2] == wall:
			return true
	return false

## Whether this species goes round a wall when it could. A siege dinosaur says no: walking
## THROUGH the defence instead of around it is the whole of its design.
func walks_round_walls() -> bool:
	return true

func _is_wall(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not ("building_type" in node):
		return false
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_building_kind"):
		return false
	return String(cfg.get_building_kind(String(node.building_type))) == "wall"

func _is_building(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and (node.is_in_group("buildings") or node.is_in_group("core"))

## Whether `node` is something that shoots -- what a pack leaves its path for
## (Config.DINO_AI.shooter_kinds).
func _is_shooter(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not ("building_type" in node):
		return false
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_building_kind"):
		return false
	return String(cfg.get_building_kind(String(node.building_type))) in _ai_list("shooter_kinds", ["trap"])

## Where it is going, as opposed to what it has stopped for: the current waypoint, or the cabin.
func _journey_goal() -> Vector3:
	if waypoints.is_empty():
		return _cabin_goal()
	return _lane_point(clampi(current_waypoint_index, 0, waypoints.size() - 1))

## A waypoint moved sideways by this animal's lane -- so a raid comes down a road abreast rather
## than single file -- except the last, which is the cabin itself.
func _lane_point(index: int) -> Vector3:
	var base_pos: Vector3 = waypoints[index]
	if index >= waypoints.size() - 1 or absf(lane_offset) <= 0.001 or waypoints.size() < 2:
		return base_pos
	var seg: Vector3 = waypoints[mini(index + 1, waypoints.size() - 1)] - waypoints[maxi(index - 1, 0)]
	seg.y = 0.0
	if seg.length_squared() < 0.001:
		return base_pos
	return base_pos + seg.normalized().cross(Vector3.UP).normalized() * lane_offset

## The cabin's middle, or where the waypoints end without one.
func _cabin_goal() -> Vector3:
	var cabin: Node = _cabin()
	if cabin != null:
		return (cabin as Node3D).global_position
	if not waypoints.is_empty():
		return waypoints[waypoints.size() - 1]
	return Vector3.INF

func _cabin() -> Node:
	if not is_inside_tree():
		return null
	var core = get_tree().get_first_node_in_group("core")
	return core if _is_target_valid(core) else null

## At the cabin: says so once, and bites it.
func _reach_destination() -> void:
	velocity = Vector3.ZERO
	if not has_reached_destination:
		has_reached_destination = true
		var eb = _get_event_bus()
		if eb and eb.has_signal("dino_reached_core"):
			eb.dino_reached_core.emit(self)
	var cabin: Node = _cabin()
	if cabin != null:
		_take(cabin, Mode.ENGAGE)
		if _target_in_reach(cabin):
			_begin_attack()

## Whether `target` is close enough to bite: body to body, a building measured to its own walls
## (Config.gap_to_building) -- a circle of half its footprint sits inside a square's corners, and
## against the cabin a raptor at a corner could not bite what it stood against. `slack` is added
## past the reach, for letting go (reach_release).
##
## STOPPING TO BITE AND BEING ABLE TO BITE ARE ONE QUESTION, asked here and nowhere else.
func _target_in_reach(target: Variant, slack: float = 0.0) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		return false
	var cfg = _get_config()
	if "building_type" in target and cfg != null and cfg.has_method("gap_to_building"):
		return float(cfg.gap_to_building(global_position, String(target.building_type),
			(target as Node3D).global_position)) <= attack_reach() + slack
	var gap: float = _flat(global_position).distance_to(_flat((target as Node3D).global_position))
	return gap <= attack_reach() + _half_width_of(target as Node) + slack

## Half the width of whatever is being bitten, so that reach is measured body to body.
func _half_width_of(target: Node) -> float:
	var cfg = _get_config()
	if cfg == null:
		return 0.5
	if "building_type" in target and cfg.has_method("get_building_footprint"):
		return float(cfg.get_building_footprint(String(target.building_type))) * 0.5
	if target.is_in_group("hero"):
		return float(cfg.HERO.get("width", 0.8)) * 0.5
	if "dino_type" in target and cfg.has_method("get_visual_size"):
		return float(cfg.get_visual_size("dino/" + String(target.dino_type)).x) * 0.5
	return 0.5

## How far past its own middle this dinosaur can strike: its own half-width and the strike past
## its nose (Config.DINO_STRIKE). Overridable, so a big one reaches further.
func attack_reach() -> float:
	var cfg = _get_config()
	var strike: float = float(cfg.DINO_STRIKE) if (cfg and "DINO_STRIKE" in cfg) else 0.35
	return _avoid_radius + strike

# ==============================================================================
# What a species wants -- the surface a behaviour subclass overrides
# ==============================================================================

## What this dinosaur will actually stop for, or null.
##
## DO NOT OVERRIDE THIS. Override _preferred_target instead -- this method exists to put the rule
## about walls somewhere a species cannot get past.
func _find_threat_priority_target() -> Node:
	if not is_inside_tree():
		return null
	var want: Node = _preferred_target()
	if not _should_bite(want):
		return null
	# Shut away behind a wall: the wall is what to go for -- and with nothing built between, only
	# the lie of the land, it is not to be had at all.
	if _shut_away(want):
		return _wall_before(want)
	return want

## What this species WANTS to stop for, before the rule is applied.
func _preferred_target() -> Node:
	return _nearest_building_within(building_interest_range())

## How far off its path this kind of dinosaur will look for a building to bite.
func building_interest_range() -> float:
	return 2.0

## How far it will look for the Hero, and whether it cares at all.
func hero_interest_range() -> float:
	return 0.0

## Whether a trap -- what shoots at it -- is worth a detour, and from how far.
func trap_interest_range() -> float:
	return 0.0

## The nearest finished building within `radius` -- only shooters with `only_kind` "shooter", only
## one type with a type id -- measured to its walls, so a big building is as near as its face.
func _nearest_building_within(radius: float, only_kind: String = "") -> Node:
	if radius <= 0.0 or not is_inside_tree():
		return null
	var cfg = _get_config()
	var best: Node = null
	var best_dist: float = radius
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or not _is_target_valid(b):
			continue
		if only_kind == "shooter" and not _is_shooter(b):
			continue
		if only_kind != "" and only_kind != "shooter":
			if not ("building_type" in b) or String(b.building_type) != only_kind:
				continue
		var dist: float = global_position.distance_to(b.global_position)
		if cfg != null and cfg.has_method("gap_to_building") and "building_type" in b:
			dist = float(cfg.gap_to_building(global_position, String(b.building_type), b.global_position))
		if dist <= best_dist:
			best_dist = dist
			best = b
	return best

func _hero_within(radius: float) -> Node:
	if radius <= 0.0 or not is_inside_tree():
		return null
	var hero = get_tree().get_first_node_in_group("hero")
	if hero == null or not is_instance_valid(hero) or not _is_target_valid(hero):
		return null
	return hero if global_position.distance_to(hero.global_position) <= radius else null

## Whether the Hero has just made himself the loudest thing on the field.
func _hero_is_provoking() -> bool:
	if not is_inside_tree():
		return false
	var hero = get_tree().get_first_node_in_group("hero")
	if hero == null or not is_instance_valid(hero):
		return false
	if not ("has_provoked_dinos" in hero) or not bool(hero.has_provoked_dinos):
		return false
	var radius: float = 4.0
	var cfg = _get_config()
	if cfg and "HERO" in cfg:
		radius = float(cfg.HERO.get("provoke_radius", radius))
	return global_position.distance_to(hero.global_position) <= radius

# ==============================================================================
# Biting
# ==============================================================================

## Takes `obstacle` as what it bites, now. For callers that decide it for the animal.
func on_obstacle_detected(obstacle: Node) -> void:
	if obstacle == null or not is_instance_valid(obstacle):
		return
	_take(obstacle, Mode.ENGAGE)
	_face_now((obstacle as Node3D).global_position if obstacle is Node3D else Vector3.INF)
	_begin_attack()

func on_obstacle_cleared() -> void:
	_let_go()

## One attack-state step, for callers that drive it by hand.
func _process_attacking(delta: float) -> void:
	_hold_and_bite(delta)

func _is_target_valid(target: Variant) -> bool:
	if target == null or typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return false
	if not (target is Node):
		return false
	if target.is_queued_for_deletion():
		return false
	if "is_destroyed" in target and target.is_destroyed:
		return false
	# ORDERING A FENCE IS NOT HAVING ONE: a blueprint is nobody's target (Config.LAYER_BLUEPRINT).
	if "is_constructed" in target and not target.is_constructed:
		return false
	if "current_hp" in target and target.current_hp <= 0.0:
		return false
	if target.is_in_group("hero") and "current_state" in target and int(target.current_state) == 4:
		return false
	if not target.has_method("take_damage"):
		return false
	return true

func perform_attack() -> void:
	if not _is_target_valid(current_target):
		_let_go()
		return
	if not _target_in_reach(current_target, _ai("reach_release", 0.35)):
		_out_of_reach()
		return
	attack_target(current_target)
	if not _is_target_valid(current_target):
		_let_go()

func attack_target(target: Node) -> void:
	# Reach is checked here as well as in the mind, so nothing can deal damage at a distance by
	# calling this directly.
	if _is_target_valid(target) and _target_in_reach(target, _ai("reach_release", 0.35)):
		target.take_damage(damage)
		say("bite")

## How long this animal has spent against spikes; which physics frame it last heard from one; and
## the longest stretch reported in that frame.
var _spike_accum: float = 0.0
var _spike_frame: int = -1
var _spike_frame_delta: float = 0.0

## Spikes have been against this animal for `delta` of simulated time.
##
## A FENCE IS ONE SITUATION, NOT THREE, AND IT KEEPS ONE CLOCK. Every stake reports; the animal
## counts, once, however many are reporting: a denser fence is harder to get THROUGH, not a
## bigger multiplier. The clock runs on simulated time, so it scales with Engine.time_scale (the
## HUD's speed) like everything else.
func spikes_touch(amount: float, tick: float, delta: float) -> bool:
	if is_dead or current_state == State.DEAD:
		return false
	var frame: int = Engine.get_physics_frames()
	var reported: float = maxf(0.0, delta)
	if frame == _spike_frame:
		# Several stakes, one moment: the LONGEST of them counts and the rest count for nothing.
		if reported <= _spike_frame_delta:
			return false
		_spike_accum += reported - _spike_frame_delta
		_spike_frame_delta = reported
	else:
		_spike_frame = frame
		_spike_frame_delta = reported
		_spike_accum += reported
	if _spike_accum < maxf(0.01, tick):
		return false
	# Zeroed rather than decremented: one chip per tick, never a burst saved up from a long frame.
	_spike_accum = 0.0
	take_damage(amount)
	return true

func take_damage(amount: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	if is_nan(amount) or is_inf(amount) or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	_on_hit_fx()
	if is_nan(current_hp) or is_inf(current_hp) or current_hp <= 0.0:
		die()
		return
	var now: int = Time.get_ticks_msec()
	if now - _hurt_said_at >= int(_sound_number("hurt_every", 0.7) * 1000.0):
		_hurt_said_at = now
		say("hurt")

## Executes fatal death sequence.
func die() -> void:
	if is_dead or current_state == State.DEAD:
		return
	if current_target != null:
		release_attack_slot(current_target, self)
	assigned_slot = Vector3.ZERO
	is_dead = true
	current_state = State.DEAD
	set_physics_process(false)
	velocity = Vector3.ZERO
	# Out of everybody's way at once: a body that has fallen is not something to walk round.
	collision_layer = 0
	collision_mask = 0
	if _agent.is_valid():
		NavigationServer3D.agent_set_avoidance_enabled(_agent, false)

	_on_death_fx()
	spawn_death_drops()

	var eb = _get_event_bus()
	if eb and eb.has_signal("dino_died"):
		eb.dino_died.emit(self)

	queue_free()

## Leaves meat where it fell. This is the only source of food in the game, and the reason a raid
## is worth walking out to after it is over rather than just surviving. What is left is declared
## in Config.DINOS[type].drops.
func spawn_death_drops() -> Array:
	var made: Array = []
	if not is_inside_tree():
		return made
	var cfg = _get_config()
	if cfg == null or not ("DINOS" in cfg) or not cfg.DINOS.has(dino_type):
		return made
	var drops: Dictionary = cfg.DINOS[dino_type].get("drops", {})
	var chances: Dictionary = cfg.DINOS[dino_type].get("drop_chance", {})
	var gs = _get_game_state()
	for res_id in drops:
		var n: int = int(drops[res_id])
		# The rank and file leave each thing only by chance (drop_chance, GameState.roll_drop).
		if chances.has(res_id) and gs and gs.has_method("roll_drop"):
			var fell: int = 0
			for i in n:
				if gs.roll_drop(String(res_id), float(chances[res_id])):
					fell += 1
			n = fell
		if n <= 0:
			continue
		for pile in DropItem.spawn_scattered(self, global_position, String(res_id), n, n):
			made.append(pile)
	return made

# ==============================================================================
# The walker: body, collider, agent
# ==============================================================================

## A dinosaur's own layer, and everything it bumps into: the ground's obstacles, buildings, walls,
## gates, the Hero and the others (Config.DINO_AI.collides_with).
func _apply_collision_configuration() -> void:
	collision_layer = _cfg_int("LAYER_DINO", 8)
	var mask: int = 0
	for layer in _ai_list("collides_with", []):
		mask |= _cfg_int(String(layer), 0)
	collision_mask = mask
	# Seen from above, sliding along what it meets: no floor, no gravity, nothing to climb.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0

func _building_layers() -> int:
	return _cfg_int("LAYER_BUILDING", 2) | _cfg_int("LAYER_WALL", 32) | _cfg_int("LAYER_GATE", 0)

func _load_config_stats() -> void:
	if not current_multipliers.is_empty():
		setup(dino_type, current_multipliers)
	else:
		var gs = _get_game_state()
		var mults = gs.dino_stat_multipliers if (gs and "dino_stat_multipliers" in gs) else {}
		setup(dino_type, mults)

## How big this species is, as Config declares it.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size("dino/" + (dino_type if dino_type != "" else "raptor"))
	return Vector3.ONE * 0.8

## (Re)builds the visible body and points `mesh_instance` at it.
func _ensure_body() -> void:
	var existing := find_child("Body", false, false)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var body: Node3D = VisualLibrary.make("dino/" + (dino_type if dino_type != "" else "raptor"))
	add_child(body)
	mesh_instance = null
	for node in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node as MeshInstance3D
		break
	if animator != null and is_instance_valid(animator):
		animator.refresh_animation_player()
		animator.play_state(current_state)

## The collider follows the declared size, so a bigger species really is bigger to everything that
## touches it.
func _refit_to_size() -> void:
	if collision_shape != null:
		collision_shape.shape = _body_shape()
		collision_shape.position = _body_offset()
	_refresh_walker()
	_ensure_body()

## Its body: ROUND, as wide and as tall as Config declares. A box's corners caught in gaps its
## sides fitted through -- a 0.8 m box is 1.13 m corner to corner -- and on a body that slides
## along what it meets, a corner is a snag. Lifted off the ground a hair
## (Config.DINO_AI.ground_clearance), so the ground it stands on is never something it is pressed
## against.
func _body_shape() -> CylinderShape3D:
	var size: Vector3 = _declared_size()
	var round_body := CylinderShape3D.new()
	round_body.radius = size.x * 0.5
	round_body.height = size.y
	return round_body

func _body_offset() -> Vector3:
	return Vector3(0.0, _ai("ground_clearance", 0.08) + _declared_size().y * 0.5, 0.0)

## How high it looks for what it is pressed against: below the top of the lowest thing that stops
## it (Config.DINO_PROBE_HEIGHT).
func _probe_height() -> float:
	var cfg = _get_config()
	var cap: float = float(cfg.DINO_PROBE_HEIGHT) if (cfg and "DINO_PROBE_HEIGHT" in cfg) else 0.4
	return minf(_declared_size().y * 0.5, cap)

func _ensure_components() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
	collision_shape.shape = _body_shape()
	collision_shape.position = _body_offset()

	if animator == null:
		animator = ActorAnimator.new()
		animator.name = "ActorAnimator"
		add_child(animator)
		animator.setup(self, "dino")
	else:
		animator.refresh_animation_player()

	# The body, from the one place that knows what things look like. The collider above is built
	# from the SAME declared size rather than from the art, because collision is gameplay -- it
	# decides what a bite can reach -- and art that disagrees with its collider is the bug this
	# project keeps having to fix.
	_ensure_body()
	_ensure_walker()

## The agent that steers it round the others. Everything it needs is declared in Config, and its
## radius is the dinosaur's own.
func _ensure_walker() -> void:
	if _agent.is_valid() or not is_inside_tree():
		_refresh_walker()
		return
	_agent = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_avoidance_enabled(_agent, true)
	NavigationServer3D.agent_set_avoidance_callback(_agent, Callable(self, "_on_velocity_computed"))
	var cfg = _get_config()
	NavigationServer3D.agent_set_max_neighbors(_agent,
		int(cfg.DINO_AVOID_MAX_NEIGHBOURS) if (cfg and "DINO_AVOID_MAX_NEIGHBOURS" in cfg) else 10)
	NavigationServer3D.agent_set_neighbor_distance(_agent,
		float(cfg.DINO_AVOID_NEIGHBOURS) if (cfg and "DINO_AVOID_NEIGHBOURS" in cfg) else 4.0)
	NavigationServer3D.agent_set_time_horizon_agents(_agent,
		float(cfg.DINO_AVOID_TIME_HORIZON) if (cfg and "DINO_AVOID_TIME_HORIZON" in cfg) else 1.2)
	# Below the Hero's (Config.DINO_AI.avoidance_priority): they steer round him, he does not
	# steer round them.
	NavigationServer3D.agent_set_avoidance_priority(_agent, _ai("avoidance_priority", 0.5))
	_refresh_walker()

## Size, speed and map for the agent, once the species is known. The map is the world's own,
## which every dinosaur's agent is on whatever mesh it walks, so all of them steer round each
## other.
func _refresh_walker() -> void:
	var cfg = _get_config()
	_avoid_radius = 0.4
	if cfg and cfg.has_method("get_visual_size"):
		_avoid_radius = maxf(0.2, float(cfg.get_visual_size("dino/" + dino_type).x) * 0.5)
	_nav_goal = Vector3.INF
	if not _agent.is_valid():
		return
	# A little wider to the solver than its body (Config.DINO_AI.avoid_margin): steering that aims
	# to pass a neighbour at exactly body-to-body has nothing left when they meet, and gives out --
	# measured, a raptor sliding past the Hero slowed to a stop at his shoulder and stood there.
	NavigationServer3D.agent_set_radius(_agent, _avoid_radius + _ai("avoid_margin", 0.1))
	NavigationServer3D.agent_set_height(_agent, _declared_size().y)
	NavigationServer3D.agent_set_max_speed(_agent, maxf(0.1, speed))
	if is_inside_tree() and get_world_3d() != null:
		NavigationServer3D.agent_set_map(_agent, get_world_3d().navigation_map)
		NavigationServer3D.agent_set_position(_agent, global_position)

func _nav_maps() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(NavMaps.GROUP)

# ==============================================================================
# Resolvers
# ==============================================================================

func _ai(key: String, fallback: float) -> float:
	var cfg = _get_config()
	if cfg and "DINO_AI" in cfg:
		return float(cfg.DINO_AI.get(key, fallback))
	return fallback

func _ai_list(key: String, fallback: Array) -> Array:
	var cfg = _get_config()
	if cfg and "DINO_AI" in cfg:
		return cfg.DINO_AI.get(key, fallback)
	return fallback

func _cfg_int(key: String, fallback: int) -> int:
	var cfg = _get_config()
	if cfg and key in cfg:
		return int(cfg.get(key))
	return fallback

static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

static func _flat3(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

## The run's dice (GameState.rng), or a throwaway set outside a run.
func _dice() -> RandomNumberGenerator:
	var gs = _get_game_state()
	if gs != null and "rng" in gs and gs.rng is RandomNumberGenerator:
		return gs.rng
	return RandomNumberGenerator.new()

func _get_config() -> Node:
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

func _get_grid_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("grid_manager")

# ==============================================================================
# Its voice (v0.6 round three: "恐龙音效不同恐龙尽量不同，这样有区分度")
# ==============================================================================

## Seconds to its next call on the march or at its post (Config.SOUNDS.call_every), counted in
## the game's own time, so a paused raid is a quiet one.
var _call_clock: float = -1.0
var _alert_said_at: int = -100000
var _hurt_said_at: int = -100000
## Its own dice for when it calls: decoration, never the run's (GameState.rng).
var _voice_dice: RandomNumberGenerator = null

## What its sounds are called: Config.DINOS[..].voice, or its own name -- the voice's sounds are
## "<voice>_call", "_alert", "_bite", "_hurt", "_death" and, for a boss, "_roar" (Config.SOUNDS).
func voice() -> String:
	var cfg = _get_config()
	if cfg and "DINOS" in cfg and cfg.DINOS.has(dino_type):
		return String(cfg.DINOS[dino_type].get("voice", dino_type))
	return dino_type

## Says `kind` from where its head is: heard from its side of the screen, fainter the further off
## (Fx.play_at). False if not -- no such sound for it, or its kind are all talking already.
func say(kind: String) -> bool:
	var fx = _get_fx()
	if fx == null or not fx.has_method("play_at") or not is_inside_tree():
		return false
	return fx.play_at(voice() + "_" + kind, global_position + Vector3(0.0, _declared_size().y * 0.7, 0.0))

## Calls out as it goes for something new -- not again for a while (SOUNDS.alert_every).
func _alert() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _alert_said_at < int(_sound_number("alert_every", 8.0) * 1000.0):
		return
	_alert_said_at = now
	say("alert")

func _next_call() -> float:
	if _voice_dice == null:
		_voice_dice = RandomNumberGenerator.new()
		_voice_dice.randomize()
	var every: Vector2 = Vector2(6.0, 15.0)
	var cfg = _get_config()
	if cfg and "SOUNDS" in cfg:
		every = cfg.SOUNDS.get("call_every", every)
	return _voice_dice.randf_range(every.x, every.y)

## A boss taking the field is heard across the valley: its roar, or its alert if it has none.
func _on_boss_arrived(dino: Node) -> void:
	if dino != self or is_dead:
		return
	if not say("roar"):
		say("alert")

func _sound_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.SOUNDS.get(key, fallback)) if (cfg and "SOUNDS" in cfg) else fallback

# ==============================================================================
# Feedback hooks (v0.3)
# ==============================================================================

## A dinosaur taking fire used to look identical to one that was not.
func _on_hit_fx() -> void:
	_ensure_feedback_nodes(_declared_size().y + _feedback_number("health_bar_lift", 0.2), false)
	_refresh_health_bar()
	var fx = _get_fx()
	if fx:
		fx.flash(mesh_instance)

## Dinosaurs used to simply vanish on death.
func _on_death_fx() -> void:
	var fx = _get_fx()
	if fx == null or not is_inside_tree():
		return
	var colour := Color(0.9, 0.15, 0.15)
	var cfg = _get_config()
	if cfg and "COLORS" in cfg and cfg.COLORS.has(dino_type):
		colour = cfg.COLORS[dino_type]
	fx.debris(global_position, colour)
	say("death")

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null

func _ensure_feedback_nodes(bar_height: float, want_ring: bool) -> void:
	if status_bar == null or not is_instance_valid(status_bar):
		status_bar = find_child("StatusBar", true, false)
	if status_bar == null:
		var bar_script = load("res://scripts/fx/StatusBar3D.gd")
		if bar_script:
			status_bar = bar_script.new()
			status_bar.name = "StatusBar"
			status_bar.position = Vector3(0.0, bar_height, 0.0)
			status_bar.size_scale = boss_bar_scale()
			add_child(status_bar)
	if want_ring and (selection_ring == null or not is_instance_valid(selection_ring)):
		selection_ring = find_child("SelectionRing", true, false)
		if selection_ring == null:
			var ring_script = load("res://scripts/fx/SelectionRing3D.gd")
			if ring_script:
				selection_ring = ring_script.new()
				selection_ring.name = "SelectionRing"
				add_child(selection_ring)

## How much longer than an ordinary animal's its bar is drawn: a boss's stands out over it
## (Config.FEEDBACK.boss_bar_scale, by DINOS[..].boss), where a bar across the screen would not
## belong in a game that looks like the world.
func boss_bar_scale() -> float:
	var cfg = _get_config()
	if cfg == null or not cfg.DINOS.has(dino_type):
		return 1.0
	var rank: String = String(cfg.DINOS[dino_type].get("boss", ""))
	return float(cfg.FEEDBACK.get("boss_bar_scale", {}).get(rank, 1.0)) if rank != "" else 1.0

func _feedback_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.FEEDBACK.get(key, fallback)) if (cfg and "FEEDBACK" in cfg) else fallback

func _refresh_health_bar() -> void:
	if status_bar == null or not is_instance_valid(status_bar):
		return
	var ratio: float = (current_hp / max_hp) if max_hp > 0.0 else 0.0
	var hide_full: bool = true
	var cfg = _get_config()
	if cfg and "FEEDBACK" in cfg:
		hide_full = bool(cfg.FEEDBACK.get("health_bar_hide_at_full", true))
	status_bar.visible = not (hide_full and ratio >= 0.999)
	status_bar.set_ratio(ratio, Color(0.85, 0.3, 0.25, 0.95) if ratio < 0.35 else Color(0.3, 0.85, 0.35, 0.95))

func set_selected_visual(on: bool) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("set_shown"):
		selection_ring.set_shown(on)

## A thin circle at its feet: a unit, not a building (Config.FEEDBACK.unit_ring_*).
func _configure_selection_ring(base_size: float) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("configure"):
		selection_ring.configure(SelectionRing3D.Shape.ROUND, base_size)
