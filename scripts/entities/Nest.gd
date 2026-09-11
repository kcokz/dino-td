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

func _ensure_components() -> void:
	# 1. CollisionShape3D (BoxShape3D 2x1.2x2 at (0, 0.6, 0))
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = Vector3(2.0, 1.2, 2.0)
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, 0.6, 0.0)
		add_child(collision_shape)

	# 2. MeshInstance3D (BoxMesh 2x1.2x2 at (0, 0.6, 0) with purple material)
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(2.0, 1.2, 2.0)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3(0.0, 0.6, 0.0)

		var mat = StandardMaterial3D.new()
		var cfg = _get_config()
		mat.albedo_color = cfg.COLORS.get("nest", Color(0.4, 0.1, 0.5)) if (cfg and "COLORS" in cfg) else Color(0.4, 0.1, 0.5)
		mesh_instance.material_override = mat
		add_child(mesh_instance)

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
