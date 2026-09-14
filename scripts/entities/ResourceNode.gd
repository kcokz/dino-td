# res://scripts/entities/ResourceNode.gd
class_name ResourceNode
extends StaticBody3D

## Natural resource node entity (Wood, Stone, Water) for Defend Dinosaur v0.2.
## Placed on the map with capacity limits; can be harvested by the Hero.
## When depleted, transforms into a depleted visual state and yields no more resources.

@export var resource_type: String = "wood"
@export var max_capacity: int = 30
@export var current_amount: int = 30
@export var harvest_rate: float = 1.0
@export var cell_pos: Vector2i = Vector2i.ZERO

var is_depleted: bool = false
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var label_3d: Label3D = null

func _init(p_type: String = "wood", p_cell: Vector2i = Vector2i.ZERO) -> void:
	resource_type = p_type
	cell_pos = p_cell

func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("selectable")
	_ensure_components()
	setup(resource_type, cell_pos)
	_connect_event_bus()

func _exit_tree() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("locale_changed"):
		if eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("locale_changed"):
		if not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_new_locale: String) -> void:
	_update_label()

func setup(type_id: String, p_cell: Vector2i = Vector2i.ZERO, p_capacity: int = -1) -> void:
	resource_type = type_id
	cell_pos = p_cell
	var cfg = _get_config()
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(type_id):
		var data: Dictionary = cfg.RESOURCE_NODES[type_id]
		max_capacity = int(data.get("capacity", 30))
		harvest_rate = float(data.get("harvest_rate", 1.0))
	
	if p_capacity > 0:
		max_capacity = p_capacity

	current_amount = max_capacity
	is_depleted = (current_amount <= 0)
	_ensure_components()
	_update_visuals()
	_update_label()

func harvest(amount: int = 1) -> int:
	if is_depleted or current_amount <= 0:
		return 0
	var yield_amt: int = mini(amount, current_amount)
	current_amount -= yield_amt
	if current_amount <= 0:
		current_amount = 0
		is_depleted = true
		_update_visuals()
	_update_label()
	return yield_amt

func get_localized_name() -> String:
	var cfg = _get_config()
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(resource_type):
		var raw_key = cfg.RESOURCE_NODES[resource_type].get("name", resource_type)
		return TranslationServer.translate(raw_key)
	return TranslationServer.translate("RESOURCE_" + resource_type.to_upper())

func _ensure_components() -> void:
	# 1. CollisionShape3D on layer 1 (World / Obstacles)
	collision_layer = 1
	collision_mask = 0
	if collision_shape == null:
		collision_shape = find_child("CollisionShape3D", true, false) as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var shape = CylinderShape3D.new()
		shape.radius = 0.8
		shape.height = 1.0
		collision_shape.shape = shape
		collision_shape.position = Vector3(0.0, 0.5, 0.0)
		add_child(collision_shape)

	# 2. MeshInstance3D
	if mesh_instance == null:
		mesh_instance = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.7
		cyl.bottom_radius = 0.85
		cyl.height = 1.0
		mesh_instance.mesh = cyl
		mesh_instance.position = Vector3(0.0, 0.5, 0.0)
		add_child(mesh_instance)

	# 3. Floating 3D Label (Billboard Mode)
	if label_3d == null:
		label_3d = find_child("Label3D", true, false) as Label3D
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.font_size = 20
		label_3d.outline_size = 4
		label_3d.outline_modulate = Color(0, 0, 0, 0.9)
		label_3d.position = Vector3(0.0, 1.4, 0.0)
		add_child(label_3d)

func _update_visuals() -> void:
	if mesh_instance == null:
		return
	var mat = StandardMaterial3D.new()
	var cfg = _get_config()
	var col = Color(0.4, 0.4, 0.4)
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(resource_type):
		var data: Dictionary = cfg.RESOURCE_NODES[resource_type]
		col = data.get("depleted_color", Color(0.3, 0.3, 0.3)) if is_depleted else data.get("color", Color(0.5, 0.5, 0.5))
	
	mat.albedo_color = col
	mesh_instance.material_override = mat

	if is_depleted:
		mesh_instance.scale = Vector3(0.9, 0.35, 0.9)
		if collision_shape:
			collision_shape.scale = Vector3(0.9, 0.35, 0.9)
	else:
		mesh_instance.scale = Vector3.ONE
		if collision_shape:
			collision_shape.scale = Vector3.ONE

func _update_label() -> void:
	if label_3d == null:
		return
	var status_text: String
	if is_depleted:
		status_text = TranslationServer.translate("STATUS_DEPLETED")
		label_3d.modulate = Color(0.7, 0.7, 0.7, 0.8)
		label_3d.text = "%s\n[%s]" % [get_localized_name(), status_text]
	else:
		label_3d.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_3d.text = "%s\n%d / %d" % [get_localized_name(), current_amount, max_capacity]

func get_display_info() -> Dictionary:
	return {
		"title": get_localized_name(),
		"type": "resource_node",
		"resource_type": resource_type,
		"current_amount": current_amount,
		"max_capacity": max_capacity,
		"is_depleted": is_depleted,
		"status": TranslationServer.translate("STATUS_DEPLETED") if is_depleted else "%d / %d" % [current_amount, max_capacity]
	}

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
