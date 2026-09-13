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
	DEAD = 4
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

var current_state: State = State.IDLE
var target_destination: Vector3 = Vector3.ZERO
var target_building: Node = null
var target_enemy: Node3D = null
var attack_cooldown: float = 0.0

var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	_load_config()

func _ready() -> void:
	add_to_group("hero")
	add_to_group("players")
	_ensure_components()
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
	if _get_current_phase() != 0: # Only active during DEPLOY (phase 0)
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

func _process_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Check for nearby guard dinos or enemies to auto-engage
	if target_enemy == null or not _is_enemy_valid(target_enemy):
		target_enemy = _find_nearest_enemy(attack_range)
		if target_enemy != null:
			current_state = State.ATTACKING

func _process_moving(delta: float) -> void:
	# If tasked to build, check if in range
	if target_building != null and is_instance_valid(target_building):
		if "is_destroyed" in target_building and target_building.is_destroyed:
			target_building = null
			current_state = State.IDLE
			return
		target_destination = target_building.global_position
		var dist_to_b = global_position.distance_to(target_destination)
		if dist_to_b <= build_range:
			velocity = Vector3.ZERO
			current_state = State.BUILDING
			return
	
	# If tasked to attack enemy, check if in range
	elif target_enemy != null and _is_enemy_valid(target_enemy):
		target_destination = target_enemy.global_position
		var dist_to_e = global_position.distance_to(target_destination)
		if dist_to_e <= attack_range:
			velocity = Vector3.ZERO
			current_state = State.ATTACKING
			return

	# Move toward destination
	var diff = target_destination - global_position
	diff.y = 0.0
	if diff.length() <= 0.15:
		velocity = Vector3.ZERO
		current_state = State.IDLE
		return

	var dir = diff.normalized()
	velocity = dir * speed
	if dir.length_squared() > 0.001:
		look_at(global_position + dir, Vector3.UP)

	global_position += velocity * delta

func _process_building(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_building == null or not is_instance_valid(target_building) or target_building.is_destroyed:
		target_building = null
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target_building.global_position)
	if dist > (build_range + 0.5):
		current_state = State.MOVING
		return

	# Face the building
	var diff = target_building.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	if target_building.has_method("add_build_progress"):
		var completed = target_building.add_build_progress(delta)
		if completed:
			target_building = null
			current_state = State.IDLE
	else:
		current_state = State.IDLE

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
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)

# ==============================================================================
# Orders API
# ==============================================================================

func move_to(dest: Vector3) -> void:
	if current_state == State.DEAD:
		return
	target_building = null
	target_enemy = null
	target_destination = dest
	target_destination.y = global_position.y
	current_state = State.MOVING

func order_build(building: Node) -> void:
	if current_state == State.DEAD:
		return
	target_building = building
	target_enemy = null
	if building and is_instance_valid(building):
		target_destination = building.global_position
		target_destination.y = global_position.y
	current_state = State.MOVING

func order_attack(enemy: Node3D) -> void:
	if current_state == State.DEAD:
		return
	target_building = null
	target_enemy = enemy
	if enemy and is_instance_valid(enemy):
		target_destination = enemy.global_position
		target_destination.y = global_position.y
	current_state = State.MOVING

# ==============================================================================
# Combat & Damage
# ==============================================================================

func take_damage(amount: float) -> void:
	if current_state == State.DEAD or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
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
			collision_layer = 4
			collision_mask = 1
			current_state = State.IDLE

# ==============================================================================
# Visual & Physics Setup
# ==============================================================================

func _ensure_components() -> void:
	collision_layer = 4 # Layer 3: Hero/Player
	collision_mask = 1  # Layer 1: Ground

	if collision_shape == null:
		for child in get_children():
			if child is CollisionShape3D:
				collision_shape = child
				break
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = Vector3(0.8, 1.6, 0.8)
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, 0.8, 0.0)
		add_child(collision_shape)

	if mesh_instance == null:
		for child in get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.8, 1.6, 0.8)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3(0.0, 0.8, 0.0)

		var mat = StandardMaterial3D.new()
		var cfg = _get_config()
		if cfg and "COLORS" in cfg and cfg.COLORS.has("caveman"):
			mat.albedo_color = cfg.COLORS["caveman"]
		else:
			mat.albedo_color = Color(0.1, 0.8, 0.8)
		mesh_instance.material_override = mat
		add_child(mesh_instance)

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
