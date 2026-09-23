# res://scripts/entities/Tower.gd
class_name Tower
extends "res://scripts/entities/Building.gd"

## Automated Defense Turret for Defend Dinosaur v0.0.
## Detects enemy dinosaurs within 5.0m radius, selects nearest target,
## and deals periodic damage via take_damage(amount).

# ==============================================================================
# Configuration & Properties
# ==============================================================================
@export var attack_range: float = 5.0
@export var damage: float = 1.0
@export var fire_rate: float = 1.0
## Degrees a second the head turns to follow its target (Config BUILDINGS.tower).
@export var turn_speed: float = 300.0

# Compatibility aliases
var range: float:
	get: return attack_range
	set(v): attack_range = v

var attack_damage: float:
	get: return damage
	set(v): damage = v

var current_target: Node3D = null
var targets_in_range: Array = []

# The part of the model that turns, found on the art rather than built here: see
# _turret_head.
var _head: Node3D = null
var tracked_enemies: Array[Node3D] = []

# Child components
var detection_area: Area3D = null
var detection_shape: CollisionShape3D = null
var fire_timer: Timer = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	super("tower")
	building_type = "tower"
	max_hp = 20.0
	current_hp = 20.0
	_load_tower_config()

func _ready() -> void:
	super._ready()
	_load_tower_config()
	_ensure_detection_components()

func _exit_tree() -> void:
	super._exit_tree()
	if fire_timer and is_instance_valid(fire_timer):
		fire_timer.stop()

func setup(type_id: String = "tower", p_cell: Vector2i = Vector2i.ZERO) -> void:
	super.setup(type_id, p_cell)
	_load_tower_config()

func _load_tower_config() -> void:
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has("tower"):
		var data: Dictionary = cfg.BUILDINGS["tower"]
		max_hp = float(data.get("hp", 20.0))
		current_hp = max_hp
		attack_range = float(data.get("range", 5.0))
		damage = float(data.get("damage", 1.0))
		fire_rate = float(data.get("fire_rate", 1.0))
		turn_speed = float(data.get("turn_speed", 300.0))

	if fire_timer:
		fire_timer.wait_time = maxf(0.1, 1.0 / fire_rate)
	if detection_shape and detection_shape.shape is SphereShape3D:
		detection_shape.shape.radius = attack_range

# ==============================================================================
# Target Acquisition & Range Detection
# ==============================================================================

func scan_targets() -> void:
	acquire_target()

func acquire_nearest_target() -> Node3D:
	return acquire_target()

## Scans, filters, and returns the nearest valid enemy in range.
func acquire_target() -> Node3D:
	if not is_constructed:
		current_target = null
		return null

	var candidates: Array[Node3D] = []
	var seen: Dictionary = {}

	# 1. Inspect targets_in_range
	for item in targets_in_range:
		if _is_target_valid(item):
			if not seen.has(item):
				seen[item] = true
				candidates.append(item)

	# 2. Inspect overlapping bodies in Area3D
	if detection_area and is_instance_valid(detection_area) and detection_area.is_inside_tree():
		for body in detection_area.get_overlapping_bodies():
			if body is Node3D and _is_target_valid(body):
				if not seen.has(body):
					seen[body] = true
					candidates.append(body)
		for area in detection_area.get_overlapping_areas():
			if area is Node3D and _is_target_valid(area):
				if not seen.has(area):
					seen[area] = true
					candidates.append(area)

	# 3. Clean stale references from targets_in_range and tracked_enemies
	var valid_list: Array = []
	for item in targets_in_range:
		if _is_target_valid(item):
			valid_list.append(item)
	targets_in_range = valid_list

	var valid_tracked: Array[Node3D] = []
	for enemy in tracked_enemies:
		if _is_target_valid(enemy):
			valid_tracked.append(enemy)
	tracked_enemies = valid_tracked

	if candidates.is_empty():
		current_target = null
		return null

	# 4. Sort by Euclidean distance to tower ascending
	var tower_pos: Vector3 = global_position
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var dist_a: float = tower_pos.distance_squared_to(a.global_position)
		var dist_b: float = tower_pos.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)

	current_target = candidates[0]
	return current_target

func _is_target_valid(target: Variant) -> bool:
	if target == null or typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return false
	if not (target is Node):
		return false
	if target.is_queued_for_deletion():
		return false
	if target == self:
		return false
	# Defense towers must never attack friendly units or structures (Hero, Core, Walls, Producers, etc.)
	if target.name == "Hero" or target.is_in_group("hero") or target.is_in_group("players") or ("is_hero" in target and target.is_hero):
		return false
	if target is Building or target.is_in_group("buildings") or target.is_in_group("friendly"):
		return false
	if "is_destroyed" in target and target.is_destroyed:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	if "current_state" in target and int(target.current_state) == 2: # State.DEAD
		return false
	if "current_hp" in target and target.current_hp <= 0.0:
		return false
	if not target.has_method("take_damage"):
		return false
	if not (target is Node3D):
		return false

	# Range distance check
	var dist: float = global_position.distance_to(target.global_position)
	return dist <= (attack_range + 0.1)

# ==============================================================================
# Combat Execution & Timers
# ==============================================================================

func attack(target: Node3D = null) -> void:
	if target != null:
		fire_at_target(target)
	else:
		fire()

func fire() -> void:
	_on_fire_timer_timeout()

func fire_at_target(target: Node3D) -> void:
	fire_at(target)

## Deals damage to target and spawns visual feedback.
func fire_at(target: Node3D) -> void:
	if not _is_target_valid(target):
		if current_target == target:
			current_target = null
		return

	# Facing it before the shot, not after: the tracer comes out of the barrels, and the
	# barrels are pointing at what was hit.
	aim_at(target.global_position)
	target.take_damage(damage)
	_spawn_visual_bullet_effect(target.global_position)

	# If target died or became invalid, clear current_target
	if not _is_target_valid(target):
		if current_target == target:
			current_target = null

func _on_fire_timer_timeout() -> void:
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return

	# Re-verify target or acquire new nearest
	if current_target == null or not _is_target_valid(current_target):
		current_target = acquire_target()

	if current_target != null:
		fire_at(current_target)

## Visual placeholder effect for projectile attack.
func _spawn_visual_bullet_effect(target_pos: Vector3) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return

	var origin: Vector3 = shot_origin()
	var tracer = ImmediateMesh.new()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = tracer

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.2) # Bright yellow bullet streak
	mesh_inst.material_override = mat

	tracer.clear_surfaces()
	tracer.surface_begin(Mesh.PRIMITIVE_LINES)
	tracer.surface_add_vertex(origin - global_position)
	tracer.surface_add_vertex(target_pos - global_position + Vector3(0.0, 0.4, 0.0))
	tracer.surface_end()

	add_child(mesh_inst)

	# Connected to the tracer's own queue_free rather than to a closure holding it: if the
	# turret goes first, taking the tracer with it, the engine drops the connection, where
	# the closure used to be called with a freed capture.
	var tree_ref = get_tree()
	if tree_ref:
		tree_ref.create_timer(0.1).timeout.connect(mesh_inst.queue_free)
	else:
		mesh_inst.queue_free()

# ==============================================================================
# The head: turning to face what it shoots
# ==============================================================================

func _process(delta: float) -> void:
	_track_target(delta)

## The part of the turret that turns -- a node called Head on its art
## (tools/generate_props.py sentry), with a Muzzle at the end of its barrels -- or null
## when the art has none, the placeholder box for one. Found on the art rather than
## built here, so a bought model only has to name its parts to turn the same way.
func _turret_head() -> Node3D:
	if _head == null or not is_instance_valid(_head) or not is_ancestor_of(_head):
		_head = find_child("Head", true, false) as Node3D
	return _head

## The angle that points the head's barrels (-Z, the way a node faces) at `world_point`,
## worked out in the head's parent's space so the art's own scale and placing cancel out.
func _heading_to(head: Node3D, world_point: Vector3) -> float:
	var parent := head.get_parent() as Node3D
	var local: Vector3 = parent.to_local(world_point) if parent != null else world_point
	var d: Vector3 = local - head.position
	return atan2(-d.x, -d.z)

## Swings the head round towards the current target, at `turn_speed`. Seen turning, a
## turret tells the player which dinosaur it has picked.
func _track_target(delta: float) -> void:
	if not is_constructed or is_destroyed:
		return
	if current_target == null or not _is_target_valid(current_target):
		return
	var head := _turret_head()
	if head == null:
		return
	head.rotation.y = rotate_toward(head.rotation.y, _heading_to(head, current_target.global_position),
		deg_to_rad(turn_speed) * delta)

## Points the head straight at `world_point`, now.
func aim_at(world_point: Vector3) -> void:
	var head := _turret_head()
	if head != null:
		head.rotation.y = _heading_to(head, world_point)

## Where a shot leaves from: the end of the barrels when the art has them, and a point
## over the middle of the turret when it does not.
func shot_origin() -> Vector3:
	var head := _turret_head()
	if head != null:
		var muzzle := head.find_child("Muzzle", true, false) as Node3D
		if muzzle != null:
			return muzzle.global_position
	return global_position + Vector3(0.0, 1.0, 0.0)

# ==============================================================================
# Signal Callbacks
# ==============================================================================

func on_target_entered(body: Variant) -> void:
	_on_body_entered(body)

func on_target_exited(body: Variant) -> void:
	_on_body_exited(body)

func on_target_died(body: Variant) -> void:
	if targets_in_range.has(body):
		targets_in_range.erase(body)
	if tracked_enemies.has(body):
		tracked_enemies.erase(body)
	if current_target == body:
		current_target = acquire_target()

func _on_body_entered(body: Variant) -> void:
	if _is_target_valid(body):
		if not targets_in_range.has(body):
			targets_in_range.append(body)
		if not tracked_enemies.has(body):
			tracked_enemies.append(body)
		if current_target == null:
			current_target = acquire_target()

func _on_body_exited(body: Variant) -> void:
	if targets_in_range.has(body):
		targets_in_range.erase(body)
	if tracked_enemies.has(body):
		tracked_enemies.erase(body)
	if current_target == body:
		current_target = acquire_target()

# ==============================================================================
# Procedural Component Fallbacks (Headless & Scene Support)
# ==============================================================================

func _ensure_detection_components() -> void:
	# 1. Detection Area3D
	for child in get_children():
		if child is Area3D and child.name == "DetectionArea":
			detection_area = child
			break
	if detection_area == null:
		detection_area = Area3D.new()
		detection_area.name = "DetectionArea"
		detection_area.collision_layer = 0
		# Mask: Layer 3 (Dinos: 4) | Layer 4 (Nest/Enemies: 8) = 12
		detection_area.collision_mask = 12
		detection_area.input_ray_pickable = false
		add_child(detection_area)

	# 2. CollisionShape3D Sphere (radius = 5.0m)
	for child in detection_area.get_children():
		if child is CollisionShape3D:
			detection_shape = child
			break
	if detection_shape == null:
		detection_shape = CollisionShape3D.new()
		detection_shape.name = "RangeShape"
		var sphere = SphereShape3D.new()
		sphere.radius = attack_range
		detection_shape.shape = sphere
		detection_shape.position = Vector3(0.0, 0.5, 0.0)
		detection_area.add_child(detection_shape)

	# 3. Hook Area3D signals
	if not detection_area.body_entered.is_connected(_on_body_entered):
		detection_area.body_entered.connect(_on_body_entered)
	if not detection_area.body_exited.is_connected(_on_body_exited):
		detection_area.body_exited.connect(_on_body_exited)
	if not detection_area.area_entered.is_connected(_on_body_entered):
		detection_area.area_entered.connect(_on_body_entered)
	if not detection_area.area_exited.is_connected(_on_body_exited):
		detection_area.area_exited.connect(_on_body_exited)

	# 4. Fire Rate Timer (1.0s)
	for child in get_children():
		if child is Timer and child.name == "FireTimer":
			fire_timer = child
			break
	if fire_timer == null:
		fire_timer = Timer.new()
		fire_timer.name = "FireTimer"
		fire_timer.wait_time = maxf(0.1, 1.0 / fire_rate)
		fire_timer.one_shot = false
		fire_timer.autostart = true
		add_child(fire_timer)
		fire_timer.timeout.connect(_on_fire_timer_timeout)

func _on_before_destroy() -> void:
	super._on_before_destroy()
	if fire_timer and is_instance_valid(fire_timer):
		fire_timer.stop()
	targets_in_range.clear()
	tracked_enemies.clear()
	current_target = null

# ==============================================================================
# Coverage ring (Building base draws it; this only states size and colour)
# ==============================================================================

func _get_display_range() -> float:
	return attack_range

func _get_range_indicator_color() -> Color:
	return Color(0.35, 0.65, 1.0, 0.16)
