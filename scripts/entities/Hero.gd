# res://scripts/entities/Hero.gd
class_name Hero
extends CharacterBody3D

## Modern Person / Hero Entity for Defend Dinosaur v0.1.
## Avatar representing the time-traveler constructor.
## Moves in real-time, approaches blueprints to construct them,
## can attack nest guards/nest in DEPLOY phase, takes damage, and triggers Game Over on death.

enum State {
	IDLE = 0,
	MOVING = 1,
	BUILDING = 2,
	ATTACKING = 3,
	DEAD = 4,
	HARVESTING = 5,
}

# ==============================================================================
# Configuration & Properties
# ==============================================================================
@export var max_hp: float = 10.0
@export var current_hp: float = 10.0
@export var speed: float = 4.0
@export var damage: float = 1.0
@export var attack_rate: float = 1.0
@export var attack_range: float = 2.0
@export var build_range: float = 1.5

var current_state: State = State.IDLE:
	set(v):
		if current_state != v:
			current_state = v
			if animator != null and is_instance_valid(animator):
				animator.play_state(current_state)

var animator: ActorAnimator = null
var target_destination: Vector3 = Vector3.ZERO
var target_building: Node = null
var target_enemy: Node3D = null
var target_resource_node: Node = null
var attack_cooldown: float = 0.0
var harvest_timer: float = 0.0
var repair_timer: float = 0.0

var current_path: Array[Vector3] = []
var current_path_index: int = 0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var status_bar: Node3D = null
var selection_ring: Node3D = null
var is_hero: bool = true
var continuous_mode: bool = false
var has_provoked_dinos: bool = false
var provoke_timer: float = 0.0

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	_load_config()

func _ready() -> void:
	add_to_group("hero")
	add_to_group("players")
	add_to_group("selectable")
	_ensure_components()
	_ensure_feedback_nodes(2.0, true)
	var ring_w: float = 0.8
	var cfg_ring = _get_config()
	if cfg_ring and "HERO" in cfg_ring:
		ring_w = float(cfg_ring.HERO.get("width", 0.8))
	_configure_selection_ring(ring_w)
	# Without this the bar keeps whatever state it was built in and shows at full
	# health, which is exactly what it is supposed to stay out of the way for.
	_refresh_health_bar()
	_connect_feedback_events()
	_load_config()
	_connect_event_bus()

func _load_config() -> void:
	var cfg = _get_config()
	if cfg:
		if "HERO" in cfg and cfg.HERO is Dictionary:
			max_hp = float(cfg.HERO.get("hp", 10.0))
			current_hp = max_hp
			speed = float(cfg.HERO.get("move_speed", 4.0))
			damage = float(cfg.HERO.get("damage", 1.0))
			attack_rate = float(cfg.HERO.get("attack_rate", 1.0))
			attack_range = float(cfg.HERO.get("attack_range", 2.0))
		if "TIME" in cfg and cfg.TIME is Dictionary:
			build_range = float(cfg.TIME.get("build_range", 1.5))

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("phase_changed"):
		if not eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.connect(_on_phase_changed)

func _exit_tree() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("phase_changed"):
		if eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.disconnect(_on_phase_changed)

# ==============================================================================
# State Machine & Movement
# ==============================================================================

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	if _is_paused():
		return

	if provoke_timer > 0.0:
		provoke_timer -= delta
		if provoke_timer <= 0.0:
			has_provoked_dinos = false

	# Sweeping the ground happens whatever the Hero is otherwise doing, and before
	# the state machine: walking past a pile while on the way to a build site
	# should still pick it up.
	sweep_for_drops()

	if not continuous_mode and _get_current_phase() != 0: # Only restricted during legacy DEPLOY phase
		return

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.BUILDING:
			_process_building(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.HARVESTING:
			_process_harvesting(delta)

# ==============================================================================
# Carrying things home
# ==============================================================================

## Picks up every drop within reach. Collection is automatic on purpose: making
## the player click each pile would only move the clicking around, and the point
## of routing resources through the Hero is that he has to *be there*, not that
## he has to be told.
##
## Returns how many units were banked, which is what the tests measure.
func sweep_for_drops() -> int:
	if not is_inside_tree() or current_state == State.DEAD:
		return 0
	var radius: float = _pickup_radius()
	if radius <= 0.0:
		return 0
	var banked: int = 0
	for d in get_tree().get_nodes_in_group("drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion() or not (d is Node3D):
			continue
		if "is_collected" in d and d.is_collected:
			continue
		if not d.has_method("collect"):
			continue
		if global_position.distance_to((d as Node3D).global_position) <= radius:
			banked += int(d.collect(self))
	return banked

func _pickup_radius() -> float:
	var cfg = _get_config()
	if cfg and "DROPS" in cfg:
		return float(cfg.DROPS.get("pickup_radius", 1.6))
	return 1.6

func _process_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Check for nearby guard dinos or enemies to auto-engage
	if target_enemy == null or not _is_enemy_valid(target_enemy):
		target_enemy = _find_nearest_enemy(attack_range)
		if target_enemy != null:
			current_state = State.ATTACKING

func _check_and_transition_interaction_target(extra_buffer: float, collider: Node = null) -> bool:
	if target_building != null:
		if not is_instance_valid(target_building) or ("is_destroyed" in target_building and target_building.is_destroyed):
			target_building = null
			_continue_to_next_pending_building_or_idle()
			return true
		if (collider != null and collider == target_building) or _is_in_build_range(global_position, target_building, extra_buffer):
			velocity = Vector3.ZERO
			current_state = State.BUILDING
			return true

	elif target_resource_node != null:
		if not is_instance_valid(target_resource_node) or ("is_depleted" in target_resource_node and target_resource_node.is_depleted):
			target_resource_node = null
			current_state = State.IDLE
			return true
		if (collider != null and collider == target_resource_node) or _is_in_node_range(global_position, target_resource_node, extra_buffer):
			velocity = Vector3.ZERO
			current_state = State.HARVESTING
			harvest_timer = 0.0
			return true

	return false

func _replan_current_target_path() -> void:
	if target_building != null and is_instance_valid(target_building):
		_plan_path_to_building(target_building)
	elif target_resource_node != null and is_instance_valid(target_resource_node):
		_plan_path_to_node(target_resource_node)
	elif target_enemy != null and _is_enemy_valid(target_enemy):
		_plan_path(target_enemy.global_position)
	else:
		_plan_path(target_destination)

func _process_moving(delta: float) -> void:
	# 1. Target interaction check
	if _check_and_transition_interaction_target(0.4):
		return

	# 2. Target enemy check
	elif target_enemy != null:
		if not _is_enemy_valid(target_enemy):
			target_enemy = null
			current_state = State.IDLE
			return
		var dist_to_e = global_position.distance_to(target_enemy.global_position)
		if dist_to_e <= attack_range:
			velocity = Vector3.ZERO
			current_state = State.ATTACKING
			return

	# 3. Ensure path is not empty
	if current_path.is_empty():
		current_path = [target_destination]
		current_path_index = 0

	# Advance waypoints if close enough
	while current_path_index < current_path.size():
		var wp = current_path[current_path_index]
		var d_wp = Vector2(global_position.x - wp.x, global_position.z - wp.z).length()
		var threshold = 0.15 if current_path_index == current_path.size() - 1 else 0.3
		if d_wp <= threshold:
			current_path_index += 1
		else:
			break

	# Check if all waypoints reached
	if current_path_index >= current_path.size():
		velocity = Vector3.ZERO
		if _check_and_transition_interaction_target(0.4):
			return
		_replan_current_target_path()
		if current_path_index >= current_path.size():
			current_state = State.IDLE
		return

	# Move toward current waypoint
	var target_pt = current_path[current_path_index]
	var diff = target_pt - global_position
	diff.y = 0.0

	var dir = diff.normalized()
	velocity = dir * speed
	if dir.length_squared() > 0.001:
		look_at(global_position + dir, Vector3.UP)

	var motion = velocity * delta
	if is_inside_tree() and get_world_3d() != null:
		var col = move_and_collide(motion)
		if col != null:
			if _check_and_transition_interaction_target(0.2, col.get_collider()):
				return
			# Slide along the obstacle surface
			var slide_normal = col.get_normal()
			slide_normal.y = 0.0
			if slide_normal.length_squared() > 0.001:
				slide_normal = slide_normal.normalized()
				var remainder = col.get_remainder()
				var slide_motion = remainder.slide(slide_normal)
				move_and_collide(slide_motion)
	else:
		global_position += motion

	# 4. Stuck detection & auto-recovery
	var moved_dist = global_position.distance_to(_last_pos)
	if moved_dist < (speed * delta * 0.2):
		_stuck_timer += delta
		if _stuck_timer >= 0.4:
			_stuck_timer = 0.0
			if _check_and_transition_interaction_target(0.2):
				return
			# Replanning cannot help a man standing INSIDE something solid: the route is
			# fine, the physics is what is refusing. Push him out first.
			if _push_out_of_anything_solid():
				return
			if _abandon_unreachable_building():
				return
			_replan_current_target_path()
	else:
		_stuck_timer = 0.0
	_last_pos = global_position

## Shoves the Hero clear of any finished building he is standing inside, and reports
## whether he had to be.
##
## THE LAST LINE OF DEFENCE, and it exists because the first line failed in the field: a
## stake built on top of him left him walking on the spot at full speed, for ever, with
## a perfectly good path in hand. move_and_collide cannot resolve a body that is already
## overlapping, and no amount of replanning is going to change that.
##
## Placement now refuses to put a building on somebody, so this should never fire. It
## stays because "should never" is what the last one was too, and being nudged a few
## centimetres is a great deal better than being retired from the game.
func _push_out_of_anything_solid() -> bool:
	var gm = _get_grid_manager()
	if gm == null or not gm.has_method("get_all_buildings"):
		return false
	var cfg = _get_config()
	var half_me: float = float(cfg.HERO.get("width", 0.8)) * 0.5 if cfg else 0.4

	for b in gm.get_all_buildings():
		if b == null or not is_instance_valid(b) or not (b is Node3D):
			continue
		if "is_constructed" in b and not b.is_constructed:
			continue          # a blueprint is not solid and never traps anyone
		if "is_destroyed" in b and b.is_destroyed:
			continue
		var half_it: float = 0.5
		if cfg and "building_type" in b:
			half_it = float(cfg.get_building_footprint(String(b.building_type))) * 0.5
		var away: Vector3 = global_position - (b as Node3D).global_position
		away.y = 0.0
		var gap: float = away.length()
		var clearance: float = half_me + half_it
		if gap >= clearance:
			continue
		# Straight out along the shortest way, plus a hair so it does not re-trigger.
		# The gap is measured BEFORE picking a fallback direction: reading it afterwards
		# gave the length of the fallback instead, which made the push negative and shoved
		# him further in.
		if gap < 0.01:
			away = Vector3(1.0, 0.0, 0.0)
			gap = 0.0
		global_position += away.normalized() * (clearance - gap + 0.05)
		return true
	return false

func _process_building(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_building == null or not is_instance_valid(target_building) or target_building.is_destroyed:
		target_building = null
		_continue_to_next_pending_building_or_idle()
		return

	if not _is_in_build_range(global_position, target_building, 0.5):
		_plan_path_to_building(target_building)
		current_state = State.MOVING
		return

	# Face the building
	var diff = target_building.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	# Building and mending are the same verb -- he walks over and works on it with
	# a hammer. Which one happens is the building's business, not the order's: an
	# unfinished thing gets raised, a damaged one gets patched.
	if "is_constructed" in target_building and target_building.is_constructed:
		_work_on_repair(delta)
		return
	if target_building.has_method("add_build_progress"):
		var completed = target_building.add_build_progress(delta)
		if completed:
			target_building = null
			_continue_to_next_pending_building_or_idle()
	else:
		_continue_to_next_pending_building_or_idle()

## Mending: he stands there for as long as the job is worth, and the bill is paid
## when the work is done. Walking away costs the time spent and nothing else --
## there is never a half-paid building to explain.
func _work_on_repair(delta: float) -> void:
	if not target_building.has_method("needs_repair") or not target_building.needs_repair():
		target_building = null
		repair_timer = 0.0
		_continue_to_next_pending_building_or_idle()
		return
	repair_timer += delta
	var needed: float = float(target_building.repair_seconds()) if target_building.has_method("repair_seconds") else 1.0
	if repair_timer < needed:
		return
	repair_timer = 0.0
	if target_building.has_method("finish_repair"):
		target_building.finish_repair()
	target_building = null
	_continue_to_next_pending_building_or_idle()

func _process_attacking(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_enemy == null or not _is_enemy_valid(target_enemy):
		target_enemy = null
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > (attack_range + 0.5):
		current_state = State.MOVING
		return

	# Face enemy
	var diff = target_enemy.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	attack_cooldown -= delta
	if attack_cooldown <= 0.0:
		attack_cooldown = attack_rate
		has_provoked_dinos = true
		var p_dur: float = 5.0
		var cfg = _get_config()
		if cfg and "HERO" in cfg:
			p_dur = float(cfg.HERO.get("provoke_duration", 5.0))
		provoke_timer = p_dur
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)

func _process_harvesting(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_resource_node == null or not is_instance_valid(target_resource_node):
		target_resource_node = null
		current_state = State.IDLE
		return

	if "is_depleted" in target_resource_node and target_resource_node.is_depleted:
		target_resource_node = null
		current_state = State.IDLE
		return

	if not _is_in_node_range(global_position, target_resource_node, 0.4):
		_plan_path_to_node(target_resource_node)
		current_state = State.MOVING
		return

	# Face the node
	var diff = target_resource_node.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	harvest_timer += delta
	var rate: float = 1.0
	if "harvest_rate" in target_resource_node:
		rate = float(target_resource_node.harvest_rate)
	var interval = 1.0 / maxf(rate, 0.1)

	while harvest_timer >= interval:
		harvest_timer -= interval
		if target_resource_node == null or not is_instance_valid(target_resource_node):
			break
		var res_type: String = target_resource_node.resource_type if "resource_type" in target_resource_node else "wood"
		var yielded: int = target_resource_node.harvest(1) if target_resource_node.has_method("harvest") else 0
		if yielded > 0:
			# Even what the Hero digs up himself lands on the ground first. He is
			# standing on it, so his own sweep takes it a frame later and it feels
			# the same as banking it -- but there is now exactly one way resources
			# get into the warehouse, instead of one rule for hands and another
			# for machines.
			DropItem.spawn(self, global_position, res_type, yielded)

		if "is_depleted" in target_resource_node and target_resource_node.is_depleted:
			target_resource_node = null
			current_state = State.IDLE
			break

func _is_in_build_range(pos: Vector3, b: Node, extra_buffer: float = 0.0) -> bool:
	if b == null or not is_instance_valid(b):
		return false
	var b_pos = b.global_position
	# Check 1: Euclidean distance to center
	var dist_center = pos.distance_to(b_pos)
	if dist_center <= (build_range + extra_buffer):
		return true

	# Check 2: 2D bounding box distance to building cell perimeter
	var half_size: float = 1.0
	var gm = _get_grid_manager()
	if gm and "tile_size" in gm:
		half_size = float(gm.tile_size) * 0.5
	var dx = maxf(0.0, absf(pos.x - b_pos.x) - half_size)
	var dz = maxf(0.0, absf(pos.z - b_pos.z) - half_size)
	var dist_box = sqrt(dx * dx + dz * dz)
	var max_box_dist = maxf(0.6, build_range - half_size + 0.2) + extra_buffer
	return dist_box <= max_box_dist

func _is_in_node_range(pos: Vector3, node: Node, extra_buffer: float = 0.0) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var dist = pos.distance_to(node.global_position)
	return dist <= (build_range + 0.8 + extra_buffer)

func _plan_path_to_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_plan_path_to_building(node)

func _plan_path(dest: Vector3, ignore_b: Node = null) -> void:
	target_destination = dest
	target_destination.y = global_position.y
	current_path.clear()
	current_path_index = 0
	_stuck_timer = 0.0
	_last_pos = global_position

	var gm = _get_grid_manager()
	if gm and gm.has_method("find_path"):
		# walls_are_open: his own fence is not a thing to route around. See
		# Config.LAYER_WALL -- the physics agrees, and this keeps the route agreeing with
		# it. A route that goes the long way round something he can walk straight through
		# looks exactly like broken pathfinding.
		var pts = gm.find_path(global_position, target_destination, ignore_b, false, true)
		if pts.size() > 0:
			current_path = pts
			current_path_index = 0
			return

	current_path = [target_destination]
	current_path_index = 0

func _plan_path_to_building(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	var b_pos = b.global_position
	b_pos.y = global_position.y

	var gm = _get_grid_manager()
	if gm and gm.has_method("find_path") and gm.has_method("world_to_cell") and gm.has_method("is_cell_walkable"):
		var cell = gm.world_to_cell(b_pos)
		var stand_dist: float = minf(build_range * 0.7, 1.0)
		# Candidate approach points:
		# 1. 4 cardinal edge stand-points within build range facing open adjacent cells
		# 2. Target building center itself
		var candidates: Array[Vector3] = []
		var offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for off in offsets:
			var adj_cell = cell + off
			if gm.is_cell_walkable(adj_cell, b, false, true):
				var edge_pt = b_pos + Vector3(float(off.x) * stand_dist, 0.0, float(off.y) * stand_dist)
				candidates.append(edge_pt)

		if gm.is_cell_walkable(cell, b, false, true):
			candidates.append(b_pos)

		candidates.sort_custom(func(a: Vector3, b_pt: Vector3) -> bool:
			return global_position.distance_squared_to(a) < global_position.distance_squared_to(b_pt)
		)

		for cand in candidates:
			var path = gm.find_path(global_position, cand, b, false, true)
			if path.size() > 0:
				current_path = path
				current_path_index = 0
				target_destination = path[path.size() - 1]
				_stuck_timer = 0.0
				_last_pos = global_position
				return

	# Fallback
	_plan_path(b_pos, b)

## Next blueprint the Hero should work on: the one queued earliest.
func _find_nearest_unfinished_building() -> Node:
	if not is_inside_tree():
		return null
	var unfinished: Array[Node] = []
	var gm = _get_grid_manager()
	if gm and gm.has_method("get_all_buildings"):
		for b in gm.get_all_buildings():
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				if "is_constructed" in b and not b.is_constructed:
					if not ("is_destroyed" in b and b.is_destroyed):
						unfinished.append(b)

	if unfinished.is_empty():
		for group_name in ["buildings", "blueprints"]:
			for node in get_tree().get_nodes_in_group(group_name):
				if is_instance_valid(node) and not node.is_queued_for_deletion():
					if "is_constructed" in node and not node.is_constructed:
						if not ("is_destroyed" in node and node.is_destroyed):
							if not unfinished.has(node):
								unfinished.append(node)

	if unfinished.is_empty():
		return null

	# A blueprint he cannot walk to is not work he can do. Without this he takes the
	# oldest one, fails to reach it, replans, and does it again forever -- which is
	# exactly what happens when the player lays several rows at once and a finished
	# stake ends up between him and the rest of the queue.
	#
	# Skipping it rather than dropping it: the rest of the row still goes up, and the
	# unreachable one is picked up again the moment a way opens (demolish one stake
	# and it is next in line). If NONE of them can be reached he keeps trying the
	# oldest, which is the honest thing -- he is fenced in, and walking into the
	# fence is at least visible. Going idle would hide it and leave him asleep after
	# the player opened the fence again.
	var reachable: Array[Node] = _reachable_among(unfinished)
	if not reachable.is_empty():
		unfinished = reachable

	# Oldest blueprint first: when the player lays a row of stakes, they go up in
	# the order they were clicked. Nearest-first looks arbitrary from the outside,
	# because the Hero's position is not something the player was thinking about.
	var best: Node = null
	var best_order: int = -1
	var best_dist_sq: float = 0.0
	for b in unfinished:
		var order: int = int(b.build_order) if "build_order" in b else -1
		var d_sq: float = global_position.distance_squared_to(b.global_position)
		if best == null:
			best = b
			best_order = order
			best_dist_sq = d_sq
			continue
		# Fall back to distance only between blueprints with no order stamp.
		if order >= 0 and best_order >= 0:
			if order < best_order:
				best = b
				best_order = order
				best_dist_sq = d_sq
		elif order >= 0 and best_order < 0:
			best = b
			best_order = order
			best_dist_sq = d_sq
		elif order < 0 and best_order < 0 and d_sq < best_dist_sq:
			best = b
			best_dist_sq = d_sq
	return best

## Which of `candidates` he can actually walk to. Empty means there was no grid to
## ask, and the caller then does not filter at all.
##
## The grid answers each one by flooding out from the blueprint, so "no" is only
## returned when the blueprint really is sitting in a closed pocket.
func _reachable_among(candidates: Array[Node]) -> Array[Node]:
	var out: Array[Node] = []
	var gm = _get_grid_manager()
	if gm == null or not gm.has_method("is_reachable"):
		return out
	for b in candidates:
		if b is Node3D and gm.is_reachable(global_position, (b as Node3D).global_position, 400, true):
			out.append(b)
	return out

## Being wedged against something is the one moment worth asking whether the
## blueprint he is walking to can be reached at all. If it cannot and other work
## can, he moves on instead of grinding against the stake in front of it.
func _abandon_unreachable_building() -> bool:
	if target_building == null or not is_instance_valid(target_building):
		return false
	if not ("is_constructed" in target_building) or bool(target_building.is_constructed):
		return false
	var gm = _get_grid_manager()
	if gm == null or not gm.has_method("is_reachable"):
		return false
	if gm.is_reachable(global_position, target_building.global_position, 400, true):
		return false
	var next_b = _find_nearest_unfinished_building()
	if next_b == null or next_b == target_building:
		return false
	target_building = null
	order_build(next_b, true)
	return true

func _continue_to_next_pending_building_or_idle() -> void:
	target_building = null
	var next_b = _find_nearest_unfinished_building()
	if next_b != null:
		order_build(next_b)
	else:
		current_state = State.IDLE

# ==============================================================================
# Orders API
# ==============================================================================

## Drops every outstanding target. Each order starts by calling this so a new
## command fully replaces the previous one -- move_to() used to clear only some of
## them, which let a half-finished harvest quietly drag the Hero back and made him
## look unresponsive.
func _clear_orders() -> void:
	target_building = null
	target_enemy = null
	target_resource_node = null

func move_to(dest: Vector3) -> void:
	if current_state == State.DEAD:
		return
	_clear_orders()
	_plan_path(dest)
	current_state = State.MOVING

func order_build(building: Node, force: bool = false) -> void:
	if current_state == State.DEAD:
		return
	if building == null or not is_instance_valid(building):
		current_state = State.IDLE
		return
	# A non-forced order must not retarget a Hero who already has a blueprint in
	# hand. Guarding only the BUILDING state let every fresh click steal him while
	# he was still WALKING to the previous one, so a row went up in reverse order.
	if not force and target_building != null and is_instance_valid(target_building) 			and not target_building.is_queued_for_deletion() 			and "is_constructed" in target_building and not target_building.is_constructed 			and target_building != building 			and current_state in [State.BUILDING, State.MOVING]:
		return
	_clear_orders()
	target_building = building

	if _is_in_build_range(global_position, building):
		velocity = Vector3.ZERO
		current_state = State.BUILDING
		return

	_plan_path_to_building(building)
	current_state = State.MOVING

## Sends the Hero to work on a damaged building. It is deliberately the same order
## as raising a blueprint -- one verb, and the building decides what the hammer is
## for.
func order_repair(building: Node) -> void:
	repair_timer = 0.0
	order_build(building, true)

func order_attack(enemy: Node3D) -> void:
	if current_state == State.DEAD:
		return
	_clear_orders()
	target_enemy = enemy
	if enemy and is_instance_valid(enemy):
		_plan_path(enemy.global_position)
	current_state = State.MOVING

## Whether the Hero has what it takes to work this node at all. Stone needs a
## pick, and the pick is made at the cabin -- so "can I cut this" is a question
## about what he has made, not about where he is standing.
func can_harvest(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not ("resource_type" in node):
		return false
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("harvest_requires_unlock"):
		return true
	var needed: String = String(cfg.harvest_requires_unlock(String(node.resource_type)))
	if needed == "":
		return true
	var gs = _get_game_state()
	return gs != null and gs.has_method("has_unlock") and gs.has_unlock(needed)

func order_harvest(node: Node) -> void:
	if current_state == State.DEAD:
		return
	if node == null or not is_instance_valid(node):
		current_state = State.IDLE
		return
	if "is_depleted" in node and node.is_depleted:
		current_state = State.IDLE
		return
	if not can_harvest(node):
		return

	_clear_orders()
	target_resource_node = node

	if _is_in_node_range(global_position, node):
		velocity = Vector3.ZERO
		current_state = State.HARVESTING
		harvest_timer = 0.0
		return

	_plan_path_to_node(node)
	current_state = State.MOVING

func order_stop() -> void:
	_clear_orders()
	current_path.clear()
	current_path_index = 0
	velocity = Vector3.ZERO
	if current_state != State.DEAD:
		current_state = State.IDLE

func get_display_info() -> Dictionary:
	var name_str = TranslationServer.translate("HERO_NAME")
	return {
		"title": name_str,
		"type": "hero",
		"hp": current_hp,
		"max_hp": max_hp,
		"status": TranslationServer.translate("STATUS_HP") % [int(ceil(current_hp)), int(ceil(max_hp))]
	}

# ==============================================================================
# Combat & Damage
# ==============================================================================

func take_damage(amount: float) -> void:
	if current_state == State.DEAD or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	_ensure_feedback_nodes(2.0, true)
	_refresh_health_bar()
	var fx = _get_fx()
	if fx:
		fx.flash(mesh_instance)
		fx.play(fx.Sound.HIT)
	var eb = _get_event_bus()
	if eb and eb.has_signal("hero_hp_changed"):
		eb.hero_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		die()

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	velocity = Vector3.ZERO
	var eb = _get_event_bus()
	if eb and eb.has_signal("hero_died"):
		eb.hero_died.emit()

func _is_enemy_valid(enemy: Variant) -> bool:
	if enemy == null or typeof(enemy) != TYPE_OBJECT or not is_instance_valid(enemy):
		return false
	if not (enemy is Node3D):
		return false
	if enemy.is_queued_for_deletion():
		return false
	if "is_destroyed" in enemy and enemy.is_destroyed:
		return false
	if "is_dead" in enemy and enemy.is_dead:
		return false
	if "current_state" in enemy and int(enemy.current_state) == 2: # Dino.State.DEAD
		return false
	if "current_hp" in enemy and enemy.current_hp <= 0.0:
		return false
	return true

func _find_nearest_enemy(max_dist: float) -> Node3D:
	if not is_inside_tree():
		return null
	var candidates: Array[Node3D] = []
	for group_name in ["guard_dinos", "nest", "dinos"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node3D and _is_enemy_valid(node):
				if not candidates.has(node):
					candidates.append(node)
	var nearest: Node3D = null
	var min_dist_sq: float = max_dist * max_dist
	for cand in candidates:
		var d_sq = global_position.distance_squared_to(cand.global_position)
		if d_sq <= min_dist_sq:
			min_dist_sq = d_sq
			nearest = cand
	return nearest

# ==============================================================================
# Phase Reaction (v0.1: Hero hidden and invincible during ATTACK phase)
# ==============================================================================

func _on_phase_changed(phase: int) -> void:
	if continuous_mode:
		return
	if phase == 1: # Phase.ATTACK
		visible = false
		collision_layer = 0
		collision_mask = 0
		target_building = null
		target_enemy = null
		if current_state != State.DEAD:
			current_state = State.IDLE
	elif phase == 0: # Phase.DEPLOY
		if current_state != State.DEAD:
			visible = true
			collision_layer = 4 # Layer 3: Hero/Player
			collision_mask = 3 # Layer 1 Ground + Layer 2 Buildings
			current_state = State.IDLE

# ==============================================================================
# Visual & Physics Setup
# ==============================================================================

## How big the Hero is, as Config declares it: one figure for the collider and the body
## both, so a model dropped in later is exactly as wide as the thing a fence stops.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size("hero")
	return Vector3(0.8, 1.6, 0.8)

## (Re)builds the visible body and points `mesh_instance` at it, which the feedback
## layer flashes and the HUD tints.
func _ensure_body() -> void:
	var existing := find_child("Body", false, false)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var body: Node3D = VisualLibrary.make("hero")
	add_child(body)
	mesh_instance = null
	for node in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node as MeshInstance3D
		break
	if animator != null and is_instance_valid(animator):
		animator.refresh_animation_player()
		animator.play_state(current_state)

func _ensure_components() -> void:
	collision_layer = 4 # Layer 3: Hero/Player
	collision_mask = 3  # Layer 1 Ground + Layer 2 Buildings

	if collision_shape == null:
		for child in get_children():
			if child is CollisionShape3D:
				collision_shape = child
				break
	var size: Vector3 = _declared_size()
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		add_child(collision_shape)

	if animator == null:
		animator = ActorAnimator.new()
		animator.name = "ActorAnimator"
		add_child(animator)
		animator.setup(self, "hero")
	else:
		animator.refresh_animation_player()

	# The body comes from the one place that knows what things look like. The collider
	# above is built from the SAME declared size rather than measured off the art,
	# because the collider is gameplay -- it is what a fence stops -- and art that
	# disagrees with its collider is the bug this project keeps having to fix.
	_ensure_body()

# ==============================================================================
# Resolvers
# ==============================================================================

func _is_paused() -> bool:
	var gs = _get_game_state()
	return gs != null and "is_paused" in gs and bool(gs.is_paused)

func _get_current_phase() -> int:
	var gs = _get_game_state()
	if gs and "current_phase" in gs:
		return int(gs.current_phase)
	return 0

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
	if is_inside_tree():
		var gms = get_tree().get_nodes_in_group("grid_manager")
		if gms.size() > 0 and is_instance_valid(gms[0]):
			return gms[0]
		if get_tree().root:
			return get_tree().root.find_child("GridManager", true, false)
	return null

## The thing the Hero is currently working on (or walking towards), or null when
## he has nothing queued. The Option Panel follows this so the player watches the
## job in progress without having to click it, and gets the Hero back when it ends.
func get_active_task_target() -> Node:
	match current_state:
		State.BUILDING:
			return target_building if is_instance_valid(target_building) else null
		State.HARVESTING:
			return target_resource_node if is_instance_valid(target_resource_node) else null
		State.MOVING:
			# En route: show whatever he is on his way to, if anything.
			for t in [target_building, target_resource_node]:
				if t != null and is_instance_valid(t):
					return t
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

func _connect_feedback_events() -> void:
	var eb = _get_event_bus()
	if eb == null:
		return
	if eb.has_signal("unit_selected") and not eb.unit_selected.is_connected(_on_fx_unit_selected):
		eb.unit_selected.connect(_on_fx_unit_selected)
	if eb.has_signal("unit_deselected") and not eb.unit_deselected.is_connected(_on_fx_unit_deselected):
		eb.unit_deselected.connect(_on_fx_unit_deselected)

func _on_fx_unit_selected(unit: Node) -> void:
	set_selected_visual(unit == self)

func _on_fx_unit_deselected() -> void:
	set_selected_visual(false)

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
func _configure_selection_ring(base_size: float) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("configure"):
		selection_ring.configure(SelectionRing3D.Shape.BOX, base_size)
