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
@export var targeting: String = "blocker_then_core"
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

static func _init_building_slots(building: Node3D) -> void:
	var b_id: int = building.get_instance_id()
	var slots: Array = []
	var center: Vector3 = building.global_position
	var r_inner: float = 1.6
	var r_outer: float = 2.6

	# 8 inner perimeter slots
	for i in range(8):
		var angle: float = float(i) * (PI / 4.0)
		var offset = Vector3(sin(angle) * r_inner, 0.0, cos(angle) * r_inner)
		slots.append({ "pos": center + offset, "dino_id": 0 })

	# 8 outer secondary ring slots
	for i in range(8):
		var angle: float = (float(i) + 0.5) * (PI / 4.0)
		var offset = Vector3(sin(angle) * r_outer, 0.0, cos(angle) * r_outer)
		slots.append({ "pos": center + offset, "dino_id": 0 })

	_building_slots[b_id] = slots

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
		targeting = String(data.get("targeting", "blocker_then_core"))
	else:
		max_hp = 3.0 * mult_hp
		current_hp = max_hp
		damage = 1.0 * mult_dmg
		speed = 4.0 * mult_spd
		attack_rate = 1.0
		targeting = "blocker_then_core"

	if attack_timer and is_instance_valid(attack_timer):
		if attack_rate > 0.0:
			attack_timer.wait_time = maxf(0.1, 1.0 / attack_rate)
		else:
			attack_timer.wait_time = 1.0

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

	# 1. Direct frontal RayCast3D for obstacle buildings
	var obstacle = check_obstacle()
	if obstacle != null:
		on_obstacle_detected(obstacle)
		return

	# 1a. Threat Priority Target Check (v0.2: Tower > Buildings > Hero)
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
		if _is_target_valid(ally_tgt):
			var dist_to_tgt = global_position.distance_to(ally_tgt.global_position)
			if dist_to_tgt <= 1.8:
				on_obstacle_detected(ally_tgt)
				return
			# Claim a perimeter attack slot around ally's target
			if assigned_slot == Vector3.ZERO:
				assigned_slot = claim_attack_slot(ally_tgt, self)
				current_target = ally_tgt

	# 1c. If navigating toward an assigned attack slot:
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

	var dir: Vector3 = diff.normalized()

	# If an attacking ally is ahead, inject lateral steering bias so rear dinos flank
	if attacking_ally != null:
		var wp_idx: int = mini(current_waypoint_index, waypoints.size() - 1)
		var perp = _get_path_normal(wp_idx)
		var side: float = 1.0 if (global_position.x >= attacking_ally.global_position.x) else -1.0
		if absf(global_position.x - attacking_ally.global_position.x) < 0.05:
			side = 1.0 if (get_instance_id() % 2 == 0) else -1.0
		dir = (dir + perp * (side * 0.75)).normalized()

	# Anti-tailgating: check if another ally is directly in front
	var speed_throttle: float = 1.0
	var front_dino = _find_immediate_front_dino(1.4)
	if front_dino != null:
		var to_front = front_dino.global_position - global_position
		to_front.y = 0.0
		var d_front = to_front.length()
		var side: float = 1.0 if (global_position.x >= front_dino.global_position.x) else -1.0
		if absf(global_position.x - front_dino.global_position.x) < 0.05:
			side = 1.0 if (get_instance_id() % 2 == 0) else -1.0
		dir = (dir + Vector3(side * 0.8, 0.0, 0.0)).normalized()
		if d_front < 1.15:
			speed_throttle = clampf((d_front - 0.88) / 0.27, 0.0, 1.0)

	# Pure steering separation velocity (no hard teleportation)
	var sep_force: Vector3 = _calculate_steering_separation()
	velocity = (dir * (speed * speed_throttle) + sep_force).limit_length(speed)

	if velocity.length_squared() > 0.001:
		look_at(global_position + velocity.normalized(), Vector3.UP)

	global_position += velocity * delta
	_clamp_to_corridor(delta)
	_resolve_dino_overlaps()

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

	# Verify target validity
	if not _is_target_valid(current_target):
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

func _clamp_to_corridor(delta: float = 0.05) -> void:
	# Encircled or attacking dinos are exempted from path corridor constraint
	if current_target != null or assigned_slot != Vector3.ZERO:
		return
	if waypoints.is_empty():
		return

	var cfg = _get_config()
	var max_lat: float = cfg.DINO_MAX_LATERAL_OFFSET if (cfg and "DINO_MAX_LATERAL_OFFSET" in cfg) else 0.6
	var wp_idx: int = mini(current_waypoint_index, waypoints.size() - 1)
	var centerline_pos: Vector3 = waypoints[wp_idx]
	var perp: Vector3 = _get_path_normal(wp_idx)
	if perp.length_squared() > 0.001:
		var to_dino: Vector3 = global_position - centerline_pos
		to_dino.y = 0.0
		var lat_dist: float = to_dino.dot(perp)
		if absf(lat_dist) > max_lat:
			var excess: float = lat_dist - signf(lat_dist) * max_lat
			var max_step: float = maxf(0.1, speed * delta * 1.5)
			var return_step: float = minf(absf(excess), max_step)
			global_position -= perp * signf(excess) * return_step

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
func _find_threat_priority_target() -> Node:
	if not is_inside_tree():
		return null

	var hero = get_tree().get_first_node_in_group("hero")
	var is_hero_provoked: bool = hero != null and is_instance_valid(hero) and "has_provoked_dinos" in hero and bool(hero.has_provoked_dinos)
	var hero_dist: float = global_position.distance_to(hero.global_position) if (hero and is_instance_valid(hero)) else 999.0

	var buildings = get_tree().get_nodes_in_group("buildings")
	var nearest_tower: Node = null
	var min_tower_dist: float = 4.5

	var nearest_other_building: Node = null
	var min_b_dist: float = 2.0

	for b in buildings:
		if not is_instance_valid(b) or not _is_target_valid(b):
			continue
		var dist = global_position.distance_to(b.global_position)
		if "building_type" in b and b.building_type == "tower":
			if dist <= min_tower_dist:
				min_tower_dist = dist
				nearest_tower = b
		elif dist <= min_b_dist:
			min_b_dist = dist
			nearest_other_building = b

	# If Hero provoked dinos, Hero threat matches Tower!
	if is_hero_provoked and hero_dist <= 4.0:
		if nearest_tower == null or hero_dist < min_tower_dist:
			if _is_target_valid(hero):
				return hero

	if nearest_tower != null:
		return nearest_tower

	if nearest_other_building != null:
		return nearest_other_building

	# If no towers or buildings nearby, but Hero is close (<= 3.0m)
	if hero != null and is_instance_valid(hero) and hero_dist <= 3.0 and _is_target_valid(hero):
		return hero

	return null

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
	if _is_target_valid(current_target):
		attack_target(current_target)
		if not _is_target_valid(current_target):
			current_target = null
			_process_attacking(0.0)
	else:
		on_obstacle_cleared()

func attack_target(target: Node) -> void:
	if _is_target_valid(target):
		target.take_damage(damage)

## Deducts damage from current_hp. Emits dino_died and frees on fatal hit.
func take_damage(amount: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	if is_nan(amount) or is_inf(amount) or amount <= 0.0:
		return

	current_hp = maxf(0.0, current_hp - amount)
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

	var eb = _get_event_bus()
	if eb and eb.has_signal("dino_died"):
		eb.dino_died.emit(self)

	queue_free()

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

func _ensure_components() -> void:
	# 1. CollisionShape3D
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, 0.4, 0.0)
		add_child(collision_shape)

	# 2. MeshInstance3D
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.8, 0.8, 0.8)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3(0.0, 0.4, 0.0)

		var mat = StandardMaterial3D.new()
		var cfg = _get_config()
		mat.albedo_color = cfg.COLORS.get("raptor", Color(0.9, 0.15, 0.15)) if (cfg and "COLORS" in cfg) else Color(0.9, 0.15, 0.15)
		mesh_instance.material_override = mat
		add_child(mesh_instance)

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
