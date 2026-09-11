# res://scripts/entities/Building.gd
class_name Building
extends StaticBody3D

## Base entity class for all stationary structures.
## Extends StaticBody3D on Physics Layer 2 ("Buildings") to provide collision for dinos.

@export var building_type: String = ""
@export var max_hp: float = 10.0
@export var current_hp: float = 10.0
@export var cell_pos: Vector2i = Vector2i.ZERO

var is_destroyed: bool = false

func _init(p_type: String = "") -> void:
	if p_type != "":
		setup(p_type)

func _ready() -> void:
	_ensure_physics_and_visuals()

## Configures building stats from Config.BUILDINGS dictionary.
func setup(type_id: String, p_cell: Vector2i = Vector2i.ZERO) -> void:
	building_type = type_id
	cell_pos = p_cell
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(type_id):
		var data: Dictionary = cfg.BUILDINGS[type_id]
		max_hp = float(data.get("hp", 10.0))
		current_hp = max_hp

## Deducts damage from current_hp. Destroys entity if HP reaches <= 0.
func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	
	current_hp = maxf(0.0, current_hp - amount)
	_on_damaged(amount)
	
	if current_hp <= 0.0:
		destroy()

## Subclass hook triggered upon taking non-fatal or fatal damage.
func _on_damaged(_amount: float) -> void:
	pass

## Executes destruction sequence: signals EventBus, marks is_destroyed, queues free.
func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	_on_before_destroy()
	
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_destroyed"):
		eb.building_destroyed.emit(self)
	
	queue_free()

## Subclass hook executed immediately before building_destroyed signal.
func _on_before_destroy() -> void:
	pass

## Restores HP up to max_hp.
func heal(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)

# ==============================================================================
# Procedural Mesh & Collision Generation (Placeholder Fallback)
# ==============================================================================

func _ensure_physics_and_visuals() -> void:
	# 1. Physics Layer 2 ("Buildings")
	collision_layer = 2
	collision_mask = 0
	
	# 2. Add CollisionShape3D if missing
	var has_shape = false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1.8, 1.0, 1.8)
		col.shape = box
		col.position = Vector3(0.0, 0.5, 0.0)
		add_child(col)
	
	# 3. Add MeshInstance3D if missing
	var has_mesh = false
	for child in get_children():
		if child is MeshInstance3D:
			has_mesh = true
			break
	if not has_mesh:
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1.8, 1.0, 1.8)
		mesh_inst.mesh = box_mesh
		mesh_inst.position = Vector3(0.0, 0.5, 0.0)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_placeholder_color()
		mesh_inst.material_override = mat
		add_child(mesh_inst)

func _get_placeholder_color() -> Color:
	var cfg = _get_config()
	if cfg and "COLORS" in cfg and cfg.COLORS.has(building_type):
		return cfg.COLORS[building_type]
	match building_type:
		"core": return Color(0.9, 0.3, 0.1)
		"wall": return Color(0.5, 0.35, 0.2)
		"lumber_hut": return Color(0.15, 0.7, 0.3)
		"tower": return Color(0.2, 0.5, 0.9)
		_: return Color(0.6, 0.6, 0.6)

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
