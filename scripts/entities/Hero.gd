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

var current_path: Array[Vector3] = []
var current_path_index: int = 0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var is_hero: bool = true

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
	# 1. Target building check
	if target_building != null:
		if not is_instance_valid(target_building) or ("is_destroyed" in target_building and target_building.is_destroyed):
			target_building = null
			_continue_to_next_pending_building_or_idle()
			return
		if _is_in_build_range(global_position, target_building):
			velocity = Vector3.ZERO
			current_state = State.BUILDING
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
		if target_building != null and is_instance_valid(target_building):
			if _is_in_build_range(global_position, target_building):
				current_state = State.BUILDING
			else:
				_plan_path_to_building(target_building)
				if current_path_index >= current_path.size():
					current_state = State.IDLE
		else:
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
			# If obstacle is the target building or within build range, transition to building
			if target_building != null and (col.get_collider() == target_building or _is_in_build_range(global_position, target_building, 0.2)):
				velocity = Vector3.ZERO
				current_state = State.BUILDING
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
			if target_building != null and is_instance_valid(target_building):
				if _is_in_build_range(global_position, target_building, 0.2):
					velocity = Vector3.ZERO
					current_state = State.BUILDING
					return
				_plan_path_to_building(target_building)
			elif target_enemy != null and _is_enemy_valid(target_enemy):
				_plan_path(target_enemy.global_position)
			else:
				_plan_path(target_destination)
	else:
		_stuck_timer = 0.0
	_last_pos = global_position

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

	if target_building.has_method("add_build_progress"):
		var completed = target_building.add_build_progress(delta)
		if completed:
			target_building = null
			_continue_to_next_pending_building_or_idle()
	else:
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
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)

# ==============================================================================
# Navigation & Range Detection
# ==============================================================================

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

func _plan_path(dest: Vector3, ignore_b: Node = null) -> void:
	target_destination = dest
	target_destination.y = global_position.y
	current_path.clear()
	current_path_index = 0
	_stuck_timer = 0.0
	_last_pos = global_position

	var gm = _get_grid_manager()
	if gm and gm.has_method("find_path"):
		var pts = gm.find_path(global_position, target_destination, ignore_b)
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
			if gm.is_cell_walkable(adj_cell, b):
				var edge_pt = b_pos + Vector3(float(off.x) * stand_dist, 0.0, float(off.y) * stand_dist)
				candidates.append(edge_pt)

		if gm.is_cell_walkable(cell, b):
			candidates.append(b_pos)

		candidates.sort_custom(func(a: Vector3, b_pt: Vector3) -> bool:
			return global_position.distance_squared_to(a) < global_position.distance_squared_to(b_pt)
		)

		for cand in candidates:
			var path = gm.find_path(global_position, cand, b)
			if path.size() > 0:
				current_path = path
				current_path_index = 0
				target_destination = path[path.size() - 1]
				_stuck_timer = 0.0
				_last_pos = global_position
				return

	# Fallback
	_plan_path(b_pos, b)

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

	var nearest: Node = null
	var min_dist_sq: float = 999999.0
	for b in unfinished:
		var d_sq = global_position.distance_squared_to(b.global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			nearest = b
	return nearest

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

func move_to(dest: Vector3) -> void:
	if current_state == State.DEAD:
		return
	target_building = null
	target_enemy = null
	_plan_path(dest)
	current_state = State.MOVING

func order_build(building: Node, force: bool = false) -> void:
	if current_state == State.DEAD:
		return
	if building == null or not is_instance_valid(building):
		current_state = State.IDLE
		return
	if not force and current_state == State.BUILDING and target_building != null and is_instance_valid(target_building) and target_building != building:
		return
	target_building = building
	target_enemy = null

	if _is_in_build_range(global_position, building):
		velocity = Vector3.ZERO
		current_state = State.BUILDING
		return

	_plan_path_to_building(building)
	current_state = State.MOVING

func order_attack(enemy: Node3D) -> void:
	if current_state == State.DEAD:
		return
	target_building = null
	target_enemy = enemy
	if enemy and is_instance_valid(enemy):
		_plan_path(enemy.global_position)
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
			collision_layer = 4 # Layer 3: Hero/Player
			collision_mask = 3 # Layer 1 Ground + Layer 2 Buildings
			current_state = State.IDLE

# ==============================================================================
# Visual & Physics Setup
# ==============================================================================

func _ensure_components() -> void:
	collision_layer = 4 # Layer 3: Hero/Player
	collision_mask = 3  # Layer 1 Ground + Layer 2 Buildings

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

func _get_grid_manager() -> Node:
	if is_inside_tree():
		var gms = get_tree().get_nodes_in_group("grid_manager")
		if gms.size() > 0 and is_instance_valid(gms[0]):
			return gms[0]
		if get_tree().root:
			return get_tree().root.find_child("GridManager", true, false)
	return null
