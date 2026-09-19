# res://scripts/entities/Dino.gd
class_name Dino
extends CharacterBody3D

## Dinosaur Enemy Entity for Defend Dinosaur v0.0.
## Navigates along waypoints towards the Campfire Core.
## Uses RayCast3D to detect and attack blocking buildings (Walls, Core, etc.).

enum State {
	WALKING = 0,
	ATTACKING = 1,
	DEAD = 2
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

var current_state: State = State.WALKING
var state: State:
	get: return current_state
	set(v): current_state = v

var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0

## Steps around the landscape, when the straight line is not available. Recomputed
## only when the goal changes or the route runs out, so open ground costs nothing.
var nav_path: Array[Vector3] = []

## How long between asking the grid whether there is a way round. Flooding the grid
## every frame for every dinosaur in a raid would be the most expensive thing in the
## game; a fraction of a second is imperceptible and costs nothing.
const ROUTE_RECHECK_SECONDS: float = 0.4
var _route_checked_at: float = -999.0
var _blocked_by: Node = null
var _way_sealed: bool = false
var _nav_goal: Vector3 = Vector3.INF
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

# Internal child nodes
var raycast: RayCast3D = null
var attack_timer: Timer = null
var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var status_bar: Node3D = null
var selection_ring: Node3D = null
var _shape_query: PhysicsShapeQueryParameters3D = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init(p_type: String = "raptor") -> void:
	dino_type = p_type

func _ready() -> void:
	add_to_group("dinos")
	_ensure_components()
	_apply_collision_configuration()
	_connect_event_bus()
	if not is_initialized:
		_load_config_stats()
	elif attack_timer and is_instance_valid(attack_timer):
		if attack_rate > 0.0:
			attack_timer.wait_time = maxf(0.1, 1.0 / attack_rate)
		else:
			attack_timer.wait_time = 1.0

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_destroyed"):
		if not eb.building_destroyed.is_connected(_on_building_destroyed):
			eb.building_destroyed.connect(_on_building_destroyed)

func _exit_tree() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("building_destroyed"):
		if eb.building_destroyed.is_connected(_on_building_destroyed):
			eb.building_destroyed.disconnect(_on_building_destroyed)
	if current_target != null:
		release_attack_slot(current_target, self)
	assigned_slot = Vector3.ZERO
	if attack_timer and is_instance_valid(attack_timer):
		attack_timer.stop()

func _on_building_destroyed(building: Node) -> void:
	if building == null:
		return
	release_all_building_slots(building)
	if current_target == building or (assigned_slot != Vector3.ZERO and is_instance_valid(current_target) and current_target == building):
		on_obstacle_cleared()

# ==============================================================================
# Attack Slot System (v0.1 Industry Best-Practice Perimeter Encircling)
# ==============================================================================

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
	var best_idx: int = -1
	var min_dist_sq: float = 1e9

	# 1. Inner Ring Priority (0..7)
	for i in range(mini(8, slots.size())):
		if slots[i].get("dino_id", 0) == 0:
			var d_sq = dino_pos.distance_squared_to(slots[i]["pos"])
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_idx = i

	# 2. Outer Ring Priority (8..15)
	if best_idx == -1:
		for i in range(8, slots.size()):
			if slots[i].get("dino_id", 0) == 0:
				var d_sq = dino_pos.distance_squared_to(slots[i]["pos"])
				if d_sq < min_dist_sq:
					min_dist_sq = d_sq
					best_idx = i

	if best_idx != -1:
		slots[best_idx]["dino_id"] = dino_id
		return slots[best_idx]["pos"]

	# Fallback if all 16 slots are occupied: queue behind closest slot
	return (building as Node3D).global_position + Vector3(0.0, 0.0, -2.6)

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

## Sixteen places a dinosaur can stand while chewing on a building. Any of them
## that lands in a hill is dropped: a slot inside the scenery is a dinosaur
## standing in the scenery.
static func _init_building_slots(building: Node3D) -> void:
	var b_id: int = building.get_instance_id()
	var slots: Array = []
	var center: Vector3 = building.global_position
	var r_inner: float = 1.6
	var r_outer: float = 2.6

	var gm_slots: Node = null
	if building.is_inside_tree():
		gm_slots = building.get_tree().get_first_node_in_group("grid_manager")

	# 8 inner perimeter slots
	for i in range(8):
		var angle: float = float(i) * (PI / 4.0)
		var offset = Vector3(sin(angle) * r_inner, 0.0, cos(angle) * r_inner)
		if _slot_is_standable(gm_slots, center + offset):
			slots.append({ "pos": center + offset, "dino_id": 0 })

	# 8 outer secondary ring slots
	for i in range(8):
		var angle: float = (float(i) + 0.5) * (PI / 4.0)
		var offset = Vector3(sin(angle) * r_outer, 0.0, cos(angle) * r_outer)
		if _slot_is_standable(gm_slots, center + offset):
			slots.append({ "pos": center + offset, "dino_id": 0 })

	_building_slots[b_id] = slots

## Whether something could actually stand at `at`. A building tucked against a
## hill loses the slots behind it, which is exactly right: those are places no
## dinosaur can reach, and offering them would park one inside the scenery.
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

	if attack_timer and is_instance_valid(attack_timer):
		if attack_rate > 0.0:
			attack_timer.wait_time = maxf(0.1, 1.0 / attack_rate)
		else:
			attack_timer.wait_time = 1.0

	# The species is only known here, and how big it is comes with it. _ensure_components
	# ran in _ready() against whatever dino_type was then, so the body and the collider
	# are refitted now -- otherwise every species keeps the default's size, which is
	# exactly how the big theropod spent four versions being small.
	if is_inside_tree():
		_refit_to_size()

func set_waypoints(wps: Array) -> void:
	waypoints.clear()
	for p in wps:
		if p is Vector3:
			waypoints.append(p)
	current_waypoint_index = 0
	has_reached_destination = false
	_orient_to_next_waypoint()

func _get_path_normal(target_index: int) -> Vector3:
	if waypoints.is_empty():
		return Vector3.RIGHT
	var seg: Vector3 = Vector3.ZERO
	if target_index > 0 and target_index < waypoints.size():
		seg = waypoints[target_index] - waypoints[target_index - 1]
	elif waypoints.size() >= 2:
		seg = waypoints[1] - waypoints[0]
	seg.y = 0.0
	if seg.length_squared() < 0.001:
		return Vector3.RIGHT
	var fwd: Vector3 = seg.normalized()
	return fwd.cross(Vector3.UP).normalized()

## A unit vector square across `heading`, pointing away from `other`.
##
## Which way "aside" is depends on where you are GOING. This used to be hard-coded to
## world X -- step aside by moving east or west, whatever direction the raid was
## travelling. For a raid coming down the Z axis that happens to be right; for one coming
## along X it means stepping forwards or backwards into the very dinosaur being avoided,
## and for a fence on the diagonal it is wrong by degrees the whole way.
func _step_around(other: Node3D, heading: Vector3) -> Vector3:
	var fwd: Vector3 = heading
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = _get_path_normal(mini(current_waypoint_index, maxi(0, waypoints.size() - 1))).cross(Vector3.DOWN)
		if fwd.length_squared() < 0.001:
			fwd = Vector3.FORWARD
	var perp: Vector3 = fwd.normalized().cross(Vector3.UP).normalized()
	if other == null or not is_instance_valid(other):
		return perp
	var to_other: Vector3 = other.global_position - global_position
	to_other.y = 0.0
	var lean: float = perp.dot(to_other)
	if absf(lean) < 0.05:
		# Dead ahead: the two of them must not both pick the same way or they stay nose
		# to nose. The instance id is arbitrary and, being fixed, is also stable -- they
		# will not swap sides next frame and start again.
		return perp * (1.0 if (get_instance_id() % 2 == 0) else -1.0)
	return perp * (-1.0 if lean > 0.0 else 1.0)

## How slowly a dinosaur may be made to walk by the one in front. Never zero.
func _crowd_floor() -> float:
	var cfg = _get_config()
	if cfg and "DINO_CROWD_MIN_THROTTLE" in cfg:
		return float(cfg.DINO_CROWD_MIN_THROTTLE)
	return 0.4

func _get_lane_target_pos(target_index: int) -> Vector3:
	if target_index >= waypoints.size():
		return global_position
	var base_pos: Vector3 = waypoints[target_index]
	if absf(lane_offset) > 0.001:
		var perp: Vector3 = _get_path_normal(target_index)
		return base_pos + perp * lane_offset
	return base_pos

func _orient_to_next_waypoint() -> void:
	if not is_inside_tree():
		return
	if current_waypoint_index < waypoints.size():
		var target_pos: Vector3 = _get_lane_target_pos(current_waypoint_index)
		var diff: Vector3 = target_pos - global_position
		diff.y = 0.0
		if diff.length() <= arrival_threshold and current_waypoint_index + 1 < waypoints.size():
			target_pos = _get_lane_target_pos(current_waypoint_index + 1)
			diff = target_pos - global_position
			diff.y = 0.0
		if diff.length_squared() > 0.001:
			look_at(global_position + diff.normalized(), Vector3.UP)

func _update_raycast_reach(delta: float = 0.0) -> void:
	if raycast and is_instance_valid(raycast):
		var reach: float = maxf(1.2, speed * delta * 2.0)
		raycast.target_position = Vector3(0.0, 0.0, -reach)

# ==============================================================================
# Physics Processing & State Machine
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return

	match current_state:
		State.WALKING:
			advance_towards_waypoint(delta)
		State.ATTACKING:
			_process_attacking(delta)

## Advances along waypoints. Checks for obstacles and Core arrival.
func advance_towards_waypoint(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return

	# Pre-orient towards movement target
	_orient_to_next_waypoint()

	# Dynamically scale raycast reach to prevent tunneling under high speeds
	_update_raycast_reach(delta)

	# 0. THE WAY THROUGH.
	#
	# A dinosaur walks round a building if it can, and bites it if it cannot. That is
	# the whole rule, and it replaces the state this used to get into: pressed against a
	# fence, target lost, neither moving nor attacking, for as long as you cared to
	# watch. Measured at nine seconds of standing perfectly still in a sealed corridor.
	#
	# It also makes a fence mean something other than hit points. A wall that can be
	# walked round funnels the raid, and where the player puts it finally matters; a wall
	# that seals the way is the thing the raid has to chew through. Before this, every
	# fence was the second case whether the player wanted it or not.
	var blocker := _building_in_the_way()
	if blocker != null:
		if global_position.distance_to(blocker.global_position) <= 1.8:
			on_obstacle_detected(blocker)
			return
		# Not there yet. Biting something fourteen metres away is the same standing-still
		# the whole rule exists to remove, so what happens instead is that the thing in
		# the way becomes the thing to WALK AT -- and it goes through the attack slots, so
		# a raid arrives spread around the fence rather than queued behind one stake.
		if current_target != blocker:
			if current_target != null:
				release_attack_slot(current_target, self)
			current_target = blocker
			assigned_slot = claim_attack_slot(blocker, self)

	# 1. Something directly in front. Only worth stopping for if biting it is the right
	# answer -- a fence with a gate in it is walked round, not eaten.
	var obstacle = check_obstacle()
	if obstacle != null and _should_bite(obstacle):
		on_obstacle_detected(obstacle)
		return

	# 1a. Threat Priority Target Check (v0.2: Tower > Buildings > Hero)
	#
	# _find_threat_priority_target already drops a wall that is not in the way, so this
	# cannot claim a slot on a fence it has no reason to touch. It used to: the bite was
	# gated and the TARGETING was not, so a raid would claim slots on a fence it would
	# never bite, walk to them, be released for having a way round, and claim them again
	# -- hovering a slot-radius short of the stakes, neither attacking nor arriving. That
	# is what "stops some way off and does nothing" was.
	var threat_tgt = _find_threat_priority_target()
	if threat_tgt != null:
		var dist_to_threat = global_position.distance_to(threat_tgt.global_position)
		if dist_to_threat <= 1.8:
			on_obstacle_detected(threat_tgt)
			return
		if assigned_slot == Vector3.ZERO:
			assigned_slot = claim_attack_slot(threat_tgt, self)
			current_target = threat_tgt

	# 1b. Dynamic Flanking & Attack Slots for Large Flocks (10+ Dinos):
	var attacking_ally = _find_front_attacking_ally()
	if attacking_ally != null and "current_target" in attacking_ally and attacking_ally.current_target != null:
		var ally_tgt = attacking_ally.current_target
		# Joining in only counts if the thing being eaten is worth eating. Following an
		# ally onto a fence with a way round it is the same oscillation, one step removed.
		if _is_target_valid(ally_tgt) and _should_bite(ally_tgt):
			var dist_to_tgt = global_position.distance_to(ally_tgt.global_position)
			if dist_to_tgt <= 1.8:
				on_obstacle_detected(ally_tgt)
				return
			# Claim a perimeter attack slot around ally's target
			if assigned_slot == Vector3.ZERO:
				assigned_slot = claim_attack_slot(ally_tgt, self)
				current_target = ally_tgt

	# 1c. If navigating toward an assigned attack slot:
	#
	# A slot on a wall that is no longer in the way -- the player pulled a stake, or this
	# one was claimed before a gap opened -- is let go here rather than walked all the
	# way to and abandoned on arrival.
	if assigned_slot != Vector3.ZERO and _is_wall(current_target) and not _should_bite(current_target):
		release_attack_slot(current_target, self)
		current_target = null
		assigned_slot = Vector3.ZERO
	if assigned_slot != Vector3.ZERO and current_target != null and _is_target_valid(current_target):
		var diff_slot = assigned_slot - global_position
		diff_slot.y = 0.0
		var dist_slot = diff_slot.length()
		var dist_to_tgt = global_position.distance_to(current_target.global_position)
		if dist_slot <= 0.45 or dist_to_tgt <= 1.8:
			on_obstacle_detected(current_target)
			return

		var slot_dir = diff_slot.normalized()
		if attacking_ally != null:
			var side: float = 1.0 if (global_position.x >= attacking_ally.global_position.x) else -1.0
			if absf(global_position.x - attacking_ally.global_position.x) < 0.05:
				side = 1.0 if (get_instance_id() % 2 == 0) else -1.0
			slot_dir = (slot_dir + Vector3(side * 0.75, 0.0, 0.0)).normalized()

		var sep_steer = _calculate_steering_separation()
		velocity = (slot_dir * speed + sep_steer).limit_length(speed)
		if velocity.length_squared() > 0.001:
			look_at(global_position + velocity.normalized(), Vector3.UP)
		global_position += velocity * delta
		_resolve_dino_overlaps()
		return

	# 2. Check waypoint navigation
	if current_waypoint_index >= waypoints.size():
		_reach_destination()
		return

	# A waypoint the player has built on top of is not a place to walk to. Skip to the
	# next one rather than steering at a spot inside a fence forever.
	#
	# This is what a wall across the road used to do: the route runs down the path
	# column, a stake lands on a waypoint, and every dinosaur in the raid walks up to
	# the near side of it and stops -- not attacking, because there was a way round, and
	# not moving, because the place it was told to go is inside a building.
	_skip_unwalkable_waypoints()
	if current_waypoint_index >= waypoints.size():
		_reach_destination()
		return

	var target_pos: Vector3 = _get_lane_target_pos(current_waypoint_index)
	var diff: Vector3 = target_pos - global_position
	diff.y = 0.0

	var dist: float = diff.length()
	if dist <= arrival_threshold:
		current_waypoint_index += 1
		if current_waypoint_index >= waypoints.size():
			_reach_destination()
			return
		target_pos = _get_lane_target_pos(current_waypoint_index)
		diff = target_pos - global_position
		diff.y = 0.0
		dist = diff.length()

	# Head for the next step of a route around the landscape -- on open ground that
	# is the waypoint itself, so nothing changes.
	var steer_pos: Vector3 = _steer_target(target_pos)
	var steer_diff: Vector3 = steer_pos - global_position
	steer_diff.y = 0.0
	var dir: Vector3 = steer_diff.normalized() if steer_diff.length_squared() > 0.001 else diff.normalized()

	# If an attacking ally is ahead, lean around it rather than queueing behind it.
	if attacking_ally != null:
		dir = (dir + _step_around(attacking_ally, dir) * 0.75).normalized()

	# Anti-tailgating: yield to whoever is directly in front, and go round them.
	#
	# THE YIELD MUST NEVER REACH ZERO. It used to, and in a pack that is a deadlock: each
	# dinosaur is stopped by the one ahead, so nobody has the speed left to get out of
	# anyone's way, and the jam has no reason to ever clear. Twenty of them measured nine
	# standing still, one for ten unbroken seconds. At five it hardly showed, which is why
	# it survived three rounds of looking at this -- A CROWD IS A DIFFERENT PROBLEM FROM A
	# QUEUE, and a raid is a crowd.
	var speed_throttle: float = 1.0
	var front_dino = _find_immediate_front_dino(1.4)
	if front_dino != null:
		var to_front: Vector3 = front_dino.global_position - global_position
		to_front.y = 0.0
		dir = (dir + _step_around(front_dino, dir) * 0.8).normalized()
		if to_front.length() < 1.15:
			speed_throttle = clampf((to_front.length() - 0.88) / 0.27, _crowd_floor(), 1.0)

	# Pure steering separation velocity (no hard teleportation)
	var sep_force: Vector3 = _calculate_steering_separation()
	velocity = (dir * (speed * speed_throttle) + sep_force).limit_length(speed)

	if velocity.length_squared() > 0.001:
		look_at(global_position + velocity.normalized(), Vector3.UP)

	var was_at: Vector3 = global_position
	global_position += velocity * delta
	_keep_off_the_hills(was_at)
	_resolve_dino_overlaps()

## Where to actually head, given that a hill may be in the way.
##
## On open ground this returns the goal itself and nothing changes -- the flocking,
## flanking and tailgating behaviour all still apply to a straight run. Only when
## the landscape blocks the line does it fall back to a route around it, which is
## what makes terrain a tactical object: a hill decides where a raid can come
## from, and that is what finally gives stake and turret placement an answer.
func _steer_target(goal: Vector3) -> Vector3:
	if _line_is_clear(global_position, goal):
		nav_path.clear()
		_nav_goal = Vector3.INF
		return goal

	var gm := _get_grid_manager()
	if gm == null or not gm.has_method("find_path"):
		return goal

	if _nav_goal.distance_squared_to(goal) > 0.25 or nav_path.is_empty():
		_nav_goal = goal
		# terrain_only = false: route around BUILDINGS as well as hills. Dinosaurs used
		# to ignore buildings entirely and walk into them, on the theory that politely
		# going around a fence made the fence pointless. That had it backwards -- a fence
		# you cannot walk round is what makes a fence worth placing, and one you can is a
		# funnel. What stops a wall being ignored is _building_in_the_way, not blindness.
		var pts: Array = gm.find_path(global_position, goal, null, false)
		nav_path.clear()
		for pt in pts:
			nav_path.append(pt)

	# Drop the steps already reached.
	while not nav_path.is_empty() and global_position.distance_to(nav_path[0]) <= arrival_threshold:
		nav_path.remove_at(0)
	if nav_path.is_empty():
		return goal
	return nav_path[0]

## Whether a dinosaur can walk straight from a to b without meeting anything solid.
##
## Buildings count now, not only hillside. They did not before, and the result was a
## dinosaur that believed a straight line through a fence was clear, walked into it, and
## stayed there.
func _line_is_clear(from_pos: Vector3, to_pos: Vector3) -> bool:
	return _first_solid_on_line(from_pos, to_pos, true) == Vector2i(2147483647, 2147483647)

## The first cell along the segment that cannot be walked through, or a sentinel when
## the whole line is clear. `include_buildings` separates "is the way open" from "is the
## landscape in the way", which the attack-slot code still wants to ask on its own.
##
## Handed to the grid, which walks the CELLS the line crosses. This used to sample the
## line every metre and decide for itself what counted as solid, and it was wrong twice
## over: it could step clean over the corner of a hill, and it called a tile solid on the
## strength of it being OCCUPIED -- so a tile holding one stake, which the pathfinder
## routes straight through, read as a wall. A walker caught between a line check and a
## pathfinder that disagree does not go round and does not stop: it walks into the thing,
## gets pushed back, and repeats.
func _first_solid_on_line(from_pos: Vector3, to_pos: Vector3, include_buildings: bool) -> Vector2i:
	var none := Vector2i(2147483647, 2147483647)
	var gm := _get_grid_manager()
	if gm == null or not gm.has_method("first_solid_on_line"):
		return none
	if from_pos.distance_to(to_pos) <= 0.001:
		return none
	return gm.first_solid_on_line(from_pos, to_pos, not include_buildings, null,
		gm.world_to_cell(global_position))

## The building this dinosaur has to go through, or null when there is a way round.
##
## Two questions, in this order, because the second one is the expensive one:
##   1. is anything solid on the straight line at all? (cheap, and usually no)
##   2. if so, is there a route around it? (a flood, so it is throttled)
##
## Only when the answer is "something is in the way AND there is no way round" does the
## thing in the way become a target. A fence with a gap in it is walked round.
func _building_in_the_way() -> Node:
	_refresh_route()
	if _blocked_by != null and is_instance_valid(_blocked_by):
		return _blocked_by
	return null

## Whether there is no way round at all. The question a wall is judged by.
func _way_is_sealed() -> bool:
	_refresh_route()
	return _way_sealed

## Works out, at most a few times a second, whether the way ahead is open and what is
## standing in it.
##
## Throttled because the answer costs a flood of the grid. Doing it per dinosaur per
## frame during a raid would be the most expensive thing in the game, and a fence coming
## down half a second late is not something anyone can see.
func _refresh_route() -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _route_checked_at < ROUTE_RECHECK_SECONDS:
		if _blocked_by != null and not is_instance_valid(_blocked_by):
			_blocked_by = null
			_way_sealed = false
		return
	_route_checked_at = now
	_blocked_by = null
	_way_sealed = false

	var gm := _get_grid_manager()
	if gm == null or not gm.has_method("is_reachable"):
		return
	# The JOURNEY goal, never the thing currently targeted. Asking "can I reach my
	# target" is self-referential -- a target is always reachable, because it is where
	# you are standing by the time you bite it -- so a wall judged that way is never in
	# the way, gets released, gets re-targeted, and the raid oscillates on the spot.
	var goal: Vector3 = _journey_goal()
	if goal == Vector3.INF:
		return

	var hit: Vector2i = _first_solid_on_line(global_position, goal, true)
	if hit == Vector2i(2147483647, 2147483647):
		return                      # clear line; nothing to decide
	if gm.is_reachable(global_position, goal):
		return                      # something is in the way, but there is a way round

	_way_sealed = true
	# The nearest BUILDING on the line, which is not always the nearest solid thing: a
	# hillside can be what seals the way, and a hillside is not something to bite. Then
	# _blocked_by stays null, nothing is attacked, and the partial path takes it as close
	# as the map allows -- which is the right answer to "sealed by the landscape".
	_blocked_by = _first_building_on_line(global_position, goal)

## The nearest finished building standing on the line, or null.
func _first_building_on_line(from_pos: Vector3, to_pos: Vector3) -> Node:
	var gm := _get_grid_manager()
	if gm == null or not gm.has_method("cells_on_line"):
		return null
	var here: Vector2i = gm.world_to_cell(global_position)
	for cell in gm.cells_on_line(from_pos, to_pos):
		if cell == here or gm.is_cell_walkable(cell):
			continue
		var b = gm.get_building_at(cell)
		if b != null and is_instance_valid(b) and not ("is_destroyed" in b and b.is_destroyed):
			return b
	return null

## Whether stopping to bite this is the right thing to do.
##
## A WALL IS ONLY WORTH BITING WHEN IT IS ACTUALLY IN THE WAY. If there is a way round
## it, go round -- that is what makes a fence a funnel that decides where the raid
## arrives, rather than a sack of hit points that every raid chews through in the same
## place. Anything else -- a turret, the wreck -- is attacked on its own merits, because
## those are targets rather than obstacles.
##
## This is the rule that was missing. A dinosaur with a clear way round would still stop
## at the first stake its raycast touched, so five of them met a fence with an open gate
## and four stood there eating it.
func _should_bite(node: Variant) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not _is_wall(node):
		return true
	if not walks_round_walls():
		return true
	return _way_is_sealed()

## Whether this species goes round a wall when it could.
##
## True for anything that reacts to what the player has built -- which is what the rule
## about fences is for, and what a raid of raptors is.
##
## A siege dinosaur says no, and that is not an exception bolted on: walking THROUGH the
## defence instead of around it is the whole of its design, and the contrast with a pack
## is what makes defending against the two different problems. Making the rule universal
## would have left "siege" as a word in a comment.
func walks_round_walls() -> bool:
	return true

func _is_wall(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not ("building_type" in node):
		return false
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg):
		return false
	var type_id: String = String(node.building_type)
	if not cfg.BUILDINGS.has(type_id):
		return false
	return String(cfg.BUILDINGS[type_id].get("kind", "")) == "wall"

## Advances past any waypoint that now stands inside something solid.
##
## The last waypoint is never skipped: it is the destination, and if the player has
## walled the core in then that wall is exactly what the raid should be chewing -- which
## _building_in_the_way will then say, because the way really is sealed.
func _skip_unwalkable_waypoints() -> void:
	var gm := _get_grid_manager()
	if gm == null or not gm.has_method("is_cell_walkable"):
		return
	while current_waypoint_index < waypoints.size() - 1:
		var cell: Vector2i = gm.world_to_cell(waypoints[current_waypoint_index])
		if gm.is_cell_walkable(cell):
			return
		current_waypoint_index += 1

## Where this dinosaur is trying to get to right now -- what it is steering at.
func _current_goal() -> Vector3:
	if current_target != null and is_instance_valid(current_target) and current_target is Node3D:
		return (current_target as Node3D).global_position
	return _journey_goal()

## Where it is going, as opposed to what it has stopped for. The core, by way of its
## waypoints, whatever it happens to be biting on the way.
##
## The two have to be different questions. "Is the way sealed" means "is the way to
## where I am GOING sealed", and a raid that answers it against whatever it last
## targeted can never see a wall as being in the way at all.
func _journey_goal() -> Vector3:
	if waypoints.is_empty():
		return Vector3.INF
	var idx: int = clampi(current_waypoint_index, 0, waypoints.size() - 1)
	return waypoints[idx]

## Undoes a step that would have ended inside a hill. Separation and flanking both
## push sideways, and neither of them knows about the landscape -- this is the one
## place that guarantees nothing ever ends up standing in the scenery.
## Undoes a step that would have ended inside a hill -- but SLIDES along it first.
##
## Reverting outright and zeroing the velocity turns any disagreement between "where I
## am steering" and "where I can stand" into a permanent freeze: the same step is tried,
## refused and retried every frame for ever. That is not a theoretical worry, it is what
## a raid did at the two hills either side of the approach, in full view, for as long as
## the game was left running.
##
## Sliding means the worst case is a dinosaur that grazes a hillside and keeps going,
## rather than one that stops being part of the game.
func _keep_off_the_hills(previous: Vector3) -> void:
	var gm := _get_grid_manager()
	if gm == null or not gm.has_method("is_cell_blocked"):
		return
	if not gm.is_cell_blocked(gm.world_to_cell(global_position)):
		return
	var attempted: Vector3 = global_position
	# Keep whichever single axis of the step was allowed. One of them usually is: what
	# stops a walker is a wall face, and a wall face only blocks one direction.
	for slide in [Vector3(attempted.x, previous.y, previous.z),
			Vector3(previous.x, previous.y, attempted.z)]:
		if not gm.is_cell_blocked(gm.world_to_cell(slide)):
			global_position = slide
			return
	global_position = previous
	velocity = Vector3.ZERO

func _get_grid_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("grid_manager")

func _find_immediate_front_dino(max_dist: float = 1.4) -> Node3D:
	if not is_inside_tree():
		return null
	var dinos = get_tree().get_nodes_in_group("dinos")
	var fwd = -global_transform.basis.z.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD

	var best_dino: Node3D = null
	var min_d: float = max_dist

	for other in dinos:
		if other == self or not is_instance_valid(other) or not (other is Node3D):
			continue
		if not other.is_inside_tree():
			continue
		if "is_dead" in other and other.is_dead:
			continue
		if "current_state" in other and other.current_state == State.DEAD:
			continue

		var to_other = other.global_position - global_position
		to_other.y = 0.0
		var dist = to_other.length()
		if dist > 0.01 and dist < min_d:
			var dir_to = to_other / dist
			if fwd.dot(dir_to) > 0.35:
				min_d = dist
				best_dino = other

	return best_dino

func _process_attacking(_delta: float) -> void:
	velocity = Vector3.ZERO

	# A target that is gone, or one that has walked away. The second case used to be
	# missing entirely: a dinosaur went on standing in front of something it could
	# no longer touch, which is what "the raid goes stupid after the Hero pulls
	# away" looked like from the outside.
	# A wall that has stopped being in the way -- somebody demolished a stake, or the
	# dinosaur ate through one and a gap appeared -- stops being a target. Without this
	# the first one to start chewing would chew to the end no matter what opened up.
	if _is_target_valid(current_target) and _is_wall(current_target) and not _way_is_sealed():
		release_attack_slot(current_target, self)
		current_target = null
		assigned_slot = Vector3.ZERO
		on_obstacle_cleared()
		return

	if not _is_target_valid(current_target) or not _target_in_reach(current_target):
		if current_target != null:
			release_attack_slot(current_target, self)
		current_target = null
		assigned_slot = Vector3.ZERO
		var next_obstacle = check_obstacle()
		if next_obstacle != null:
			current_target = next_obstacle
			assigned_slot = claim_attack_slot(next_obstacle, self)
		else:
			on_obstacle_cleared()
	# ATTACKING stance is exempt from separation forces (anti-jitter fix)

## Whether `target` is close enough to bite. Everything that deals damage asks
## this: an attack with no sense of distance is an attack that follows its victim
## across the map.
func _target_in_reach(target: Variant) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		return false
	return global_position.distance_to((target as Node3D).global_position) <= attack_reach()

## How far this dinosaur can reach. Overridable, so a big one can bite from
## further away than a small one.
func attack_reach() -> float:
	var cfg = _get_config()
	if cfg and "DINO_ATTACK_REACH" in cfg:
		return float(cfg.DINO_ATTACK_REACH)
	return 2.2

## Calculates Reynolds-style steering separation force (steers velocity, no position teleporting).
func _calculate_steering_separation() -> Vector3:
	if not is_inside_tree() or is_dead or current_state == State.DEAD:
		return Vector3.ZERO
	var dinos = get_tree().get_nodes_in_group("dinos")
	if dinos.size() <= 1:
		return Vector3.ZERO

	var cfg = _get_config()
	var min_dist: float = cfg.DINO_SEPARATION_MIN_DIST if (cfg and "DINO_SEPARATION_MIN_DIST" in cfg) else 1.15
	var steer: Vector3 = Vector3.ZERO

	for other in dinos:
		if other == self or not is_instance_valid(other) or not (other is Node3D):
			continue
		if not other.is_inside_tree():
			continue
		if "is_dead" in other and other.is_dead:
			continue
		if "current_state" in other and other.current_state == State.DEAD:
			continue

		var diff: Vector3 = global_position - other.global_position
		diff.y = 0.0
		var dist_sq: float = diff.length_squared()
		if dist_sq < min_dist * min_dist:
			var dist: float = sqrt(dist_sq)
			if dist > 0.001:
				var push_mag: float = (min_dist - dist) / min_dist
				var push_dir: Vector3 = diff / dist
				if absf(diff.x) < 0.35:
					var side: float = 1.0 if (global_position.x >= other.global_position.x) else -1.0
					if absf(diff.x) < 0.01:
						side = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
					push_dir.x += side * 0.5
					push_dir = push_dir.normalized()
				steer += push_dir * push_mag * speed * 0.75
			else:
				var side: float = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
				steer += Vector3(side * speed * 0.75, 0.0, 0.0)

	return steer

## Strict anti-penetration relaxation preventing dino 3D models from overlapping.
func _resolve_dino_overlaps() -> void:
	if not is_inside_tree() or is_dead or current_state == State.DEAD:
		return
	var dinos = get_tree().get_nodes_in_group("dinos")
	if dinos.size() <= 1:
		return

	var min_dist: float = 0.88
	for _pass in range(2):
		for other in dinos:
			if other == self or not is_instance_valid(other) or not (other is Node3D):
				continue
			if not other.is_inside_tree():
				continue
			if "is_dead" in other and other.is_dead:
				continue
			if "current_state" in other and other.current_state == State.DEAD:
				continue

			var diff: Vector3 = global_position - other.global_position
			diff.y = 0.0
			var dist: float = diff.length()
			if dist < min_dist:
				var overlap: float = min_dist - dist
				var push_dir: Vector3
				if dist > 0.001:
					push_dir = diff / dist
				else:
					var side: float = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
					push_dir = Vector3(side, 0.0, 0.0)

				if "current_state" in other and other.current_state == State.ATTACKING:
					if current_state != State.ATTACKING:
						global_position += push_dir * overlap
				elif current_state == State.ATTACKING:
					pass
				else:
					global_position += push_dir * (overlap * 0.5)

## Soft flocking separation fallback for compatibility.
func _apply_dino_separation(delta: float) -> void:
	if current_state == State.ATTACKING or delta <= 0.0:
		return
	var steer = _calculate_steering_separation()
	if steer.length_squared() > 0.001:
		global_position += steer.limit_length(speed) * delta
	_resolve_dino_overlaps()

func check_obstacle() -> Node:
	if raycast == null or not is_instance_valid(raycast):
		_ensure_components()
	if raycast == null or not is_instance_valid(raycast):
		return null
	if not raycast.is_inside_tree():
		return null
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if _is_target_valid(collider):
			return collider
		if collider is Node and collider.get_parent() and _is_target_valid(collider.get_parent()):
			return collider.get_parent()

	# Multi-ray and volume checks using DirectSpaceState
	if is_inside_tree() and get_world_3d():
		var space_state = get_world_3d().direct_space_state
		var reach: float = maxf(1.2, speed * 0.15)
		var forward = -global_transform.basis.z.normalized()
		var right = global_transform.basis.x.normalized()
		var center_origin = global_position + Vector3(0.0, 0.4, 0.0)

		# 1. Lateral multi-ray detection across body width (left: -0.35m, right: +0.35m)
		var offsets = [-0.35, 0.35]
		for offset in offsets:
			var ray_from = center_origin + right * offset
			var ray_to = ray_from + forward * reach
			var ray_query = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 2)
			ray_query.collide_with_bodies = true
			ray_query.collide_with_areas = true
			var hit = space_state.intersect_ray(ray_query)
			if not hit.is_empty():
				var collider = hit.get("collider")
				if _is_target_valid(collider):
					return collider
				if collider is Node and collider.get_parent() and _is_target_valid(collider.get_parent()):
					return collider.get_parent()

		# 2. Volume intersection check for dinos touching or penetrating building geometry
		if _shape_query:
			_shape_query.transform = Transform3D(global_transform.basis, center_origin)
			var shape_hits = space_state.intersect_shape(_shape_query, 1)
			if not shape_hits.is_empty():
				var collider = shape_hits[0].get("collider")
				if _is_target_valid(collider):
					return collider
				if collider is Node and collider.get_parent() and _is_target_valid(collider.get_parent()):
					return collider.get_parent()

	return null

## Threat-based Aggro (v0.2): Tower > Other Buildings > Hero (unless Hero provoked dinos).
## What this dinosaur would rather be biting than walking past, or null for
## "nothing in particular -- carry on to the cabin".
##
## This is the one piece of a dinosaur that differs by species, so it is the one
## piece a subclass overrides. The base is the plain answer: whatever is close
## enough to be in the way. PackDino and SiegeDino sharpen it in opposite
## directions -- see those files.
## What this dinosaur will actually stop for, or null.
##
## DO NOT OVERRIDE THIS. Override _preferred_target instead -- this method exists to put
## the rule somewhere a species cannot get past.
##
## "Worth stopping for" is _should_bite: a turret or the wreck always, a wall only when
## it actually blocks the way. Filtering HERE rather than at the moment of biting is the
## point -- a target is something you commit to, claim a slot on and walk towards, and
## committing to something you will not bite is how a raid ends up milling about in
## front of a fence it could simply have walked around.
##
## The rule used to live in the body of this method, and PackDino and SiegeDino both
## REPLACED that body. Every raptor in the game is a PackDino, so the rule applied to
## nothing that ever attacked anybody, and the fence-milling went on being reported
## through three rounds of fixes -- each of which was measured against the base class and
## each of which worked, on the base class.
func _find_threat_priority_target() -> Node:
	if not is_inside_tree():
		return null
	var want: Node = _preferred_target()
	return want if _should_bite(want) else null

## What this species WANTS to stop for, before the rule is applied. The surface a
## behaviour subclass overrides.
func _preferred_target() -> Node:
	return _nearest_building_within(building_interest_range())

# ==============================================================================
# What a species wants -- the surface a behaviour subclass overrides
# ==============================================================================

## How far off its path this kind of dinosaur will look for a building to bite.
func building_interest_range() -> float:
	return 2.0

## How far it will look for the Hero, and whether it cares at all. Zero means it
## walks past him: something the size of a house has no reason to stop for one man.
func hero_interest_range() -> float:
	return 0.0

## Whether a tower is worth a detour, and from how far. Zero means it is just
## another building.
func tower_interest_range() -> float:
	return 0.0

func _nearest_building_within(radius: float, only_type: String = "") -> Node:
	if radius <= 0.0 or not is_inside_tree():
		return null
	var best: Node = null
	var best_dist: float = radius
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or not _is_target_valid(b):
			continue
		if only_type != "" and (not ("building_type" in b) or String(b.building_type) != only_type):
			continue
		var dist: float = global_position.distance_to(b.global_position)
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

func _find_front_attacking_ally() -> Node:
	if not is_inside_tree():
		return null
	var dinos = get_tree().get_nodes_in_group("dinos")
	var fwd = -global_transform.basis.z.normalized()
	fwd.y = 0.0
	for other in dinos:
		if other == self or not is_instance_valid(other) or not (other is Node3D):
			continue
		if "current_state" in other and int(other.current_state) == 1: # State.ATTACKING
			var to_other = other.global_position - global_position
			to_other.y = 0.0
			var dist = to_other.length()
			if dist > 0.01 and dist <= 2.5:
				if fwd.dot(to_other.normalized()) > 0.2:
					return other
	return null

func on_obstacle_detected(obstacle: Node) -> void:
	is_blocked = true
	current_state = State.ATTACKING
	current_target = obstacle
	velocity = Vector3.ZERO
	if obstacle is Node3D:
		var look_tgt = (obstacle as Node3D).global_position
		look_tgt.y = global_position.y
		if global_position.distance_squared_to(look_tgt) > 0.001:
			look_at(look_tgt, Vector3.UP)
	if attack_timer and is_instance_valid(attack_timer) and attack_timer.is_inside_tree():
		if attack_timer.is_stopped():
			attack_timer.start()

func on_obstacle_cleared() -> void:
	if current_target != null:
		release_attack_slot(current_target, self)
	is_blocked = false
	current_state = State.WALKING
	current_target = null
	assigned_slot = Vector3.ZERO
	if attack_timer and is_instance_valid(attack_timer) and not attack_timer.is_stopped():
		attack_timer.stop()
	_resolve_dino_overlaps()

func _is_target_valid(target: Variant) -> bool:
	if target == null or typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return false
	if not (target is Node):
		return false
	if target.is_queued_for_deletion():
		return false
	if "is_destroyed" in target and target.is_destroyed:
		return false
	if "current_hp" in target and target.current_hp <= 0.0:
		return false
	if not target.has_method("take_damage"):
		return false
	return true

func _reach_destination() -> void:
	velocity = Vector3.ZERO
	if not has_reached_destination:
		has_reached_destination = true
		var eb = _get_event_bus()
		if eb and eb.has_signal("dino_reached_core"):
			eb.dino_reached_core.emit(self)

	# Check for Campfire Core in front or find in tree to attack it
	var obstacle = check_obstacle()
	if obstacle != null:
		on_obstacle_detected(obstacle)
	else:
		if is_inside_tree():
			var core = get_tree().get_first_node_in_group("core")
			if core == null:
				core = get_tree().root.find_child("CoreCampfire", true, false)
			if _is_target_valid(core):
				on_obstacle_detected(core)

# ==============================================================================
# Combat & Damage Handling
# ==============================================================================

func _on_attack_timer_timeout() -> void:
	if current_state != State.ATTACKING or is_dead:
		return
	perform_attack()

func perform_attack() -> void:
	if not _is_target_valid(current_target):
		on_obstacle_cleared()
		return
	if not _target_in_reach(current_target):
		# It moved out of range. Let go and get back to what it was doing rather
		# than hammering something it cannot touch.
		_process_attacking(0.0)
		return
	attack_target(current_target)
	if not _is_target_valid(current_target):
		current_target = null
		_process_attacking(0.0)

func attack_target(target: Node) -> void:
	# Reach is checked here as well as in the state machine, so nothing can deal
	# damage at a distance by calling this directly.
	if _is_target_valid(target) and _target_in_reach(target):
		target.take_damage(damage)

## Deducts damage from current_hp. Emits dino_died and frees on fatal hit.
func take_damage(amount: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	if is_nan(amount) or is_inf(amount) or amount <= 0.0:
		return

	current_hp = maxf(0.0, current_hp - amount)
	_on_hit_fx()
	if is_nan(current_hp) or is_inf(current_hp) or current_hp <= 0.0:
		die()

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

	if attack_timer and is_instance_valid(attack_timer):
		attack_timer.stop()

	_on_death_fx()
	spawn_death_drops()

	var eb = _get_event_bus()
	if eb and eb.has_signal("dino_died"):
		eb.dino_died.emit(self)

	queue_free()

## Leaves meat where it fell. This is the only source of food in the game, and the
## reason a raid is worth walking out to after it is over rather than just
## surviving. What is left is declared in Config.DINOS[type].drops.
func spawn_death_drops() -> Array:
	var made: Array = []
	if not is_inside_tree():
		return made
	var cfg = _get_config()
	if cfg == null or not ("DINOS" in cfg) or not cfg.DINOS.has(dino_type):
		return made
	var drops: Dictionary = cfg.DINOS[dino_type].get("drops", {})
	for res_id in drops:
		var n: int = int(drops[res_id])
		if n <= 0:
			continue
		for pile in DropItem.spawn_scattered(self, global_position, String(res_id), n, n):
			made.append(pile)
	return made

# ==============================================================================
# Procedural Component Fallbacks (Headless & Scene Support)
# ==============================================================================

func _apply_collision_configuration() -> void:
	# Layer 3 ("Dinos" bit 2 = 4) | Layer 4 ("Nest/Enemies" bit 3 = 8) = 12
	collision_layer = 12
	collision_mask = 0

func _load_config_stats() -> void:
	if not current_multipliers.is_empty():
		setup(dino_type, current_multipliers)
	else:
		var gs = _get_game_state()
		var mults = gs.dino_stat_multipliers if (gs and "dino_stat_multipliers" in gs) else {}
		setup(dino_type, mults)

## How big this species is, as Config declares it. Read rather than assumed: the big
## theropod has declared 1.6 metres since v0.2 and was drawn and collided at 0.8,
## because nothing ever read the number.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size("dino/" + (dino_type if dino_type != "" else "raptor"))
	return Vector3.ONE * 0.8

## (Re)builds the visible body and points `mesh_instance` at it.
##
## `mesh_instance` stays a MeshInstance3D because the feedback layer flashes it and the
## HUD tints it. With real art there may be several meshes; the first one is the handle,
## and they share a material so a flash still reaches all of them.
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

## The collider follows the declared size too, so a species that is bigger really is
## bigger to everything that touches it.
func _refit_to_size() -> void:
	var size: Vector3 = _declared_size()
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box := BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	if raycast != null:
		raycast.position = Vector3(0.0, size.y * 0.5, 0.0)
	_ensure_body()

func _ensure_components() -> void:
	# 1. CollisionShape3D
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	var size: Vector3 = _declared_size()
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		add_child(collision_shape)

	# 2. The body, from the one place that knows what things look like. Collision above
	# is built from the SAME declared size rather than from the art, because collision
	# is gameplay -- it decides what a bite can reach -- and art that disagrees with its
	# collider is the bug this project keeps having to fix.
	_ensure_body()

	# 3. Obstacle RayCast3D (1.2m forward, Layer 2 "Buildings")
	for child in get_children():
		if child is RayCast3D:
			raycast = child
			break
	if raycast == null:
		raycast = RayCast3D.new()
		raycast.name = "ObstacleRayCast"
		raycast.target_position = Vector3(0.0, 0.0, -1.2) # Facing forward in local space
		raycast.position = Vector3(0.0, 0.4, 0.0)
		add_child(raycast)

	raycast.collision_mask = 2 # Layer 2: Buildings
	raycast.collide_with_bodies = true
	raycast.collide_with_areas = true
	raycast.hit_from_inside = true
	raycast.enabled = true

	# 4. Attack Timer (1.0s interval)
	for child in get_children():
		if child is Timer and child.name == "AttackTimer":
			attack_timer = child
			break
	if attack_timer == null:
		attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		attack_timer.wait_time = maxf(0.1, 1.0 / attack_rate)
		attack_timer.one_shot = false
		attack_timer.autostart = false
		add_child(attack_timer)
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	# 5. Cached Shape Query for Volume Obstacle Detection
	if _shape_query == null:
		_shape_query = PhysicsShapeQueryParameters3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		_shape_query.shape = box
		_shape_query.collision_mask = 2 # Layer 2: Buildings
		_shape_query.collide_with_bodies = true
		_shape_query.collide_with_areas = true

# ==============================================================================
# Resolvers
# ==============================================================================

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

# ==============================================================================
# Feedback hooks (v0.3)
# ==============================================================================

## A dinosaur taking fire used to look identical to one that was not: the numbers
## changed and nothing on screen did.
func _on_hit_fx() -> void:
	_ensure_feedback_nodes(1.1, false)
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
	fx.play(fx.Sound.DEATH)

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
# ==============================================================================
# Feedback layer (v0.3)
# ==============================================================================

func _ensure_feedback_nodes(bar_height: float, want_ring: bool) -> void:
	if status_bar == null or not is_instance_valid(status_bar):
		status_bar = find_child("StatusBar", true, false)
	if status_bar == null:
		var bar_script = load("res://scripts/fx/StatusBar3D.gd")
		if bar_script:
			status_bar = bar_script.new()
			status_bar.name = "StatusBar"
			status_bar.position = Vector3(0.0, bar_height, 0.0)
			add_child(status_bar)
	if want_ring and (selection_ring == null or not is_instance_valid(selection_ring)):
		selection_ring = find_child("SelectionRing", true, false)
		if selection_ring == null:
			var ring_script = load("res://scripts/fx/SelectionRing3D.gd")
			if ring_script:
				selection_ring = ring_script.new()
				selection_ring.name = "SelectionRing"
				add_child(selection_ring)

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
func _configure_selection_ring(base_size: float) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("configure"):
		selection_ring.configure(SelectionRing3D.Shape.BOX, base_size)
