# res://scripts/entities/Nest.gd
class_name Nest
extends StaticBody3D

## Enemy Dinosaur Nest Objective for Defend Dinosaur v0.0.
## Stationary entity located at the enemy spawn origin (0, 0, -18) / cell (0, -9).
## Physics Layer 4 ("Nest", collision_layer = 8). Targetable and attackable by Tower.
## Destruction triggers EventBus.nest_destroyed and EventBus.game_won.

# ==============================================================================
# Signals & Exported Properties
# ==============================================================================
signal hp_changed(current: float, max_hp: float)

@export var max_hp: float = 30.0
@export var current_hp: float = 30.0
@export var cell_pos: Vector2i = Vector2i(0, -9)

var is_destroyed: bool = false
var guard_dinos: Array[Node] = []

# Child components
var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	_load_nest_config()
	collision_layer = 8
	collision_mask = 0

func _ready() -> void:
	add_to_group("nest")
	add_to_group("nests")
	add_to_group("enemies")
	_load_nest_config()
	collision_layer = 8
	collision_mask = 0
	_ensure_components()

## Spawns NEST_GUARDS.count guard dinosaurs in orbit around the nest.
func spawn_guards(target_parent: Node = null) -> void:
	var p = target_parent if target_parent != null else get_parent()
	if p == null or not is_instance_valid(p):
		return
	var cfg = _get_config()
	var count: int = 3
	var post_radius: float = 3.0
	if cfg and "NEST_GUARDS" in cfg and cfg.NEST_GUARDS is Dictionary:
		count = int(cfg.NEST_GUARDS.get("count", 3))
		post_radius = float(cfg.NEST_GUARDS.get("post_radius", 3.0))

	var guard_script = load("res://scripts/entities/GuardDino.gd")
	if guard_script == null:
		return

	for i in range(count):
		var guard = guard_script.new()
		guard.name = "GuardDino_%d" % i
		var angle = (float(i) / float(maxi(1, count))) * TAU
		var offset = Vector3(cos(angle) * post_radius, 0.0, sin(angle) * post_radius)
		var post_pos = global_position + offset
		p.add_child(guard)
		guard.setup_post(post_pos)
		guard_dinos.append(guard)

## Flexible setup helper supporting both setup(cell), setup(hp, cell), or setup().
func setup(arg1: Variant = null, arg2: Variant = null) -> void:
	if arg1 is Vector2i:
		cell_pos = arg1
		if arg2 is float or arg2 is int:
			max_hp = float(arg2)
			current_hp = max_hp
	elif arg1 is float or arg1 is int:
		if float(arg1) > 0.0:
			max_hp = float(arg1)
			current_hp = max_hp
		if arg2 is Vector2i:
			cell_pos = arg2
	elif arg1 == null:
		_load_nest_config()

func _load_nest_config() -> void:
	var cfg = _get_config()
	if cfg and "NEST" in cfg and cfg.NEST.has("hp"):
		max_hp = float(cfg.NEST["hp"])
		current_hp = max_hp
	else:
		max_hp = 30.0
		current_hp = 30.0

# ==============================================================================
# Combat & Damage Handling
# ==============================================================================

## Validates amount and deducts HP. When HP <= 0, triggers destroy().
func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0 or is_nan(amount) or is_inf(amount):
		return

	current_hp = maxf(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		destroy()

## Restores HP up to max_hp.
func heal(amount: float) -> void:
	if is_destroyed or amount <= 0.0 or is_nan(amount) or is_inf(amount):
		return
	current_hp = minf(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

## Executes nest destruction sequence: emits signals and queues node deletion.
func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	for g in guard_dinos:
		if is_instance_valid(g):
			g.queue_free()
	guard_dinos.clear()

	var eb = _get_event_bus()
	if eb:
		if eb.has_signal("nest_destroyed"):
			eb.nest_destroyed.emit(self)
		if eb.has_signal("game_won"):
			var gs = _get_game_state()
			if gs == null or not gs.is_game_over:
				eb.game_won.emit()

	queue_free()

# ==============================================================================
# Procedural Component Fallbacks (Headless & Programmatic Creation)
# ==============================================================================

## How big the nest is, as Config declares it -- bigger than anything the player builds,
## because it is what the whole map is pointed at.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size("nest")
	return Vector3(2.0, 1.2, 2.0)

## (Re)builds the visible body and points `mesh_instance` at it. The entrance marker is
## left alone on purpose: it is not part of the nest's body, it is the mouth the raid
## comes out of, and the waves read its position.
func _ensure_body() -> void:
	var existing := find_child("Body", false, false)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var body: Node3D = VisualLibrary.make("nest")
	add_child(body)
	mesh_instance = null
	for node in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node as MeshInstance3D
		break

func _ensure_components() -> void:
	# 1. CollisionShape3D (BoxShape3D 2x1.2x2 at (0, 0.6, 0))
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

	# 2. The body, from the one place that knows what things look like. The collider is
	# built from the SAME declared size rather than measured off the art, because a
	# turret's reach is checked against the collider.
	_ensure_body()

	# 3. Entrance Marker (Blackbox cave mouth) -- only on the placeholder. The modelled
	# nest has its own burrow, and a black box stuck on the front of it was a second,
	# square mouth beside the real one.
	if VisualLibrary.has_art("nest"):
		return
	var has_entrance: bool = false
	for child in get_children():
		if child.name == "EntranceMarker":
			has_entrance = true
			break
	if not has_entrance:
		var entrance = MeshInstance3D.new()
		entrance.name = "EntranceMarker"
		var e_mesh = BoxMesh.new()
		e_mesh.size = Vector3(0.8, 0.6, 0.2)
		entrance.mesh = e_mesh
		entrance.position = Vector3(0.0, 0.3, 1.01)
		var e_mat = StandardMaterial3D.new()
		e_mat.albedo_color = Color(0.05, 0.05, 0.05)
		entrance.material_override = e_mat
		add_child(entrance)

# ==============================================================================
# Autoload Resolvers
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
