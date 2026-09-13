# res://scripts/entities/GuardDino.gd
class_name GuardDino
extends "res://scripts/entities/Dino.gd"

## Guard Dinosaur Entity stationed around the Dinosaur Nest for Defend Dinosaur v0.1.
## Roams around its assigned post during DEPLOY phase.
## Aggroes on Hero (or encroaching player buildings) within aggro_radius.
## Leashes back to post if chased beyond leash_radius.

enum GuardState {
	POST_ROAM = 0,
	AGGRO_CHASE = 1,
	ATTACKING = 2,
	RETURNING = 3
}

# ==============================================================================
# Configuration & Properties
# ==============================================================================
@export var post_radius: float = 3.0
@export var aggro_radius: float = 6.0
@export var leash_radius: float = 12.0

var guard_state: GuardState = GuardState.POST_ROAM
var post_position: Vector3 = Vector3.ZERO
var roam_target: Vector3 = Vector3.ZERO
var roam_timer: float = 0.0
var chase_target: Node3D = null
var guard_attack_timer: float = 0.0

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init(p_type: String = "raptor") -> void:
	super(p_type)

func _ready() -> void:
	super._ready()
	add_to_group("guard_dinos")
	add_to_group("enemies")
	_load_guard_config()
	if post_position == Vector3.ZERO:
		post_position = global_position
	roam_target = post_position

func _load_guard_config() -> void:
	var cfg = _get_config()
	if cfg and "NEST_GUARDS" in cfg and cfg.NEST_GUARDS is Dictionary:
		post_radius = float(cfg.NEST_GUARDS.get("post_radius", 3.0))
		aggro_radius = float(cfg.NEST_GUARDS.get("aggro_radius", 6.0))
		leash_radius = float(cfg.NEST_GUARDS.get("leash_radius", 12.0))

func setup_post(post_pos: Vector3) -> void:
	post_position = post_pos
	global_position = post_pos
	roam_target = post_pos

# ==============================================================================
# Physics Process & AI State Machine
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	if _is_paused():
		return

	match guard_state:
		GuardState.POST_ROAM:
			_process_post_roam(delta)
		GuardState.AGGRO_CHASE:
			_process_aggro_chase(delta)
		GuardState.ATTACKING:
			_process_guard_attacking(delta)
		GuardState.RETURNING:
			_process_returning(delta)

	_apply_dino_separation(delta)

func _process_post_roam(delta: float) -> void:
	# 1. Search for Hero or threats within aggro_radius
	var target = _detect_threat()
	if target != null:
		chase_target = target
		guard_state = GuardState.AGGRO_CHASE
		return

	# 2. Roam around post_position
	roam_timer -= delta
	if roam_timer <= 0.0:
		roam_timer = randf_range(2.0, 4.0)
		var angle = randf() * TAU
		var dist = randf_range(0.5, post_radius)
		roam_target = post_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	var diff = roam_target - global_position
	diff.y = 0.0
	if diff.length() > 0.3:
		var dir = diff.normalized()
		velocity = dir * (speed * 0.4)
		look_at(global_position + dir, Vector3.UP)
		global_position += velocity * delta
	else:
		velocity = Vector3.ZERO

func _process_aggro_chase(delta: float) -> void:
	# 1. Verify chase target
	if not _is_threat_valid(chase_target):
		chase_target = null
		guard_state = GuardState.RETURNING
		return

	# 2. Leash check
	var dist_from_post = global_position.distance_to(post_position)
	if dist_from_post > leash_radius:
		chase_target = null
		guard_state = GuardState.RETURNING
		return

	# 3. Move toward target
	var diff = chase_target.global_position - global_position
	diff.y = 0.0
	var dist = diff.length()
	if dist <= 1.3:
		velocity = Vector3.ZERO
		guard_state = GuardState.ATTACKING
		return

	var dir = diff.normalized()
	velocity = dir * speed
	look_at(global_position + dir, Vector3.UP)
	global_position += velocity * delta

func _process_guard_attacking(delta: float) -> void:
	velocity = Vector3.ZERO
	if not _is_threat_valid(chase_target):
		chase_target = null
		guard_state = GuardState.RETURNING
		return

	var dist = global_position.distance_to(chase_target.global_position)
	if dist > 1.8:
		guard_state = GuardState.AGGRO_CHASE
		return

	# Face target
	var diff = chase_target.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	# Attack tick
	guard_attack_timer -= delta
	if guard_attack_timer <= 0.0:
		var wait_time: float = 1.0 / maxf(0.1, attack_rate)
		guard_attack_timer = wait_time
		if chase_target.has_method("take_damage"):
			chase_target.take_damage(damage)

func _process_returning(delta: float) -> void:
	# Check if another threat wanders too close while returning
	var threat = _detect_threat()
	if threat != null:
		chase_target = threat
		guard_state = GuardState.AGGRO_CHASE
		return

	var diff = post_position - global_position
	diff.y = 0.0
	if diff.length() <= 0.4:
		velocity = Vector3.ZERO
		guard_state = GuardState.POST_ROAM
		return

	var dir = diff.normalized()
	velocity = dir * speed
	look_at(global_position + dir, Vector3.UP)
	global_position += velocity * delta

# ==============================================================================
# Threat Detection & Validity
# ==============================================================================

func _detect_threat() -> Node3D:
	if not is_inside_tree():
		return null

	# Primary threat: Hero
	var heroes = get_tree().get_nodes_in_group("hero")
	for h in heroes:
		if h is Node3D and _is_threat_valid(h):
			var dist = global_position.distance_to(h.global_position)
			if dist <= aggro_radius:
				return h

	# Secondary threat: Buildings close to nest
	var buildings = get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if b is Node3D and _is_threat_valid(b) and ("is_constructed" in b and b.is_constructed):
			var dist = global_position.distance_to(b.global_position)
			if dist <= (aggro_radius * 0.7):
				return b

	return null

func _is_threat_valid(threat: Variant) -> bool:
	if threat == null or typeof(threat) != TYPE_OBJECT or not is_instance_valid(threat):
		return false
	if not (threat is Node3D):
		return false
	if threat.is_queued_for_deletion():
		return false
	if not threat.visible:
		return false
	if "current_state" in threat and threat.current_state == 4: # Hero.State.DEAD
		return false
	if "is_destroyed" in threat and threat.is_destroyed:
		return false
	if "current_hp" in threat and threat.current_hp <= 0.0:
		return false
	return true

func _is_paused() -> bool:
	var gs = _get_game_state()
	return gs != null and "is_paused" in gs and bool(gs.is_paused)
