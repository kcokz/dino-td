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

var is_dead: bool = false
var is_blocked: bool = false
var is_initialized: bool = false
var has_reached_destination: bool = false
var current_multipliers: Dictionary = {}

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
	if not is_initialized:
		_load_config_stats()
	elif attack_timer and is_instance_valid(attack_timer):
		if attack_rate > 0.0:
			attack_timer.wait_time = maxf(0.1, 1.0 / attack_rate)
		else:
			attack_timer.wait_time = 1.0

func _exit_tree() -> void:
	if attack_timer and is_instance_valid(attack_timer):
		attack_timer.stop()

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

func _orient_to_next_waypoint() -> void:
	if not is_inside_tree():
		return
	if current_waypoint_index < waypoints.size():
		var target_pos: Vector3 = waypoints[current_waypoint_index]
		var diff: Vector3 = target_pos - global_position
		diff.y = 0.0
		if diff.length() <= arrival_threshold and current_waypoint_index + 1 < waypoints.size():
			target_pos = waypoints[current_waypoint_index + 1]
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

	# 1. Check frontal RayCast3D for obstacle buildings
	var obstacle = check_obstacle()
	if obstacle != null:
		on_obstacle_detected(obstacle)
		return

	# 2. Check waypoint navigation
	if current_waypoint_index >= waypoints.size():
		_reach_destination()
		return

	var target_pos: Vector3 = waypoints[current_waypoint_index]
	var diff: Vector3 = target_pos - global_position
	diff.y = 0.0

	var dist: float = diff.length()
	if dist <= arrival_threshold:
		current_waypoint_index += 1
		if current_waypoint_index >= waypoints.size():
			_reach_destination()
			return
		target_pos = waypoints[current_waypoint_index]
		diff = target_pos - global_position
		diff.y = 0.0
		dist = diff.length()

	var dir: Vector3 = diff.normalized()
	velocity = dir * speed
	if diff.length_squared() > 0.001:
		look_at(global_position + dir, Vector3.UP)

	global_position += velocity * delta

func _process_attacking(_delta: float) -> void:
	velocity = Vector3.ZERO

	# Verify target validity
	if not _is_target_valid(current_target):
		current_target = null
		var next_obstacle = check_obstacle()
		if next_obstacle != null:
			current_target = next_obstacle
		else:
			on_obstacle_cleared()

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

func on_obstacle_detected(obstacle: Node) -> void:
	is_blocked = true
	current_state = State.ATTACKING
	current_target = obstacle
	velocity = Vector3.ZERO
	if attack_timer and is_instance_valid(attack_timer) and attack_timer.is_inside_tree():
		if attack_timer.is_stopped():
			attack_timer.start()

func on_obstacle_cleared() -> void:
	is_blocked = false
	current_state = State.WALKING
	current_target = null
	if attack_timer and is_instance_valid(attack_timer) and not attack_timer.is_stopped():
		attack_timer.stop()

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
	if target is Node and "building_type" in target and target.building_type == "tower":
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
