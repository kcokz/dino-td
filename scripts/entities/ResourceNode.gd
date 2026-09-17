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

## How big this kind of node is, as Config declares it. A tree is tall, an outcrop is
## low and wide, a pool is almost flat -- and until v0.5 all three were the same
## cylinder, because the size lived in this file instead of in Config.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size("node/" + (resource_type if resource_type != "" else "wood"))
	return Vector3(1.6, 1.0, 1.6)

## (Re)builds the visible body and points `mesh_instance` at it.
##
## `variant` carries whether it has been cut out, so that when the art arrives a
## depleted tree can be a different model rather than the same tree in grey. Today both
## variants resolve to the same placeholder and only the colour differs -- see
## _update_visuals -- but the seam is here, which is what task 3 in AGENT-TASKS.md needs.
func _ensure_body() -> void:
	var existing := find_child("Body", false, false)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var key: String = "node/" + (resource_type if resource_type != "" else "wood")
	var body: Node3D = VisualLibrary.make(key, "depleted" if is_depleted else "full")
	add_child(body)
	mesh_instance = null
	for node in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node as MeshInstance3D
		break

func _ensure_components() -> void:
	# 1. CollisionShape3D on layer 1 (World / Obstacles)
	collision_layer = 1
	collision_mask = 0
	if collision_shape == null:
		collision_shape = find_child("CollisionShape3D", true, false) as CollisionShape3D
	var size: Vector3 = _declared_size()
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var shape = CylinderShape3D.new()
		shape.radius = size.x * 0.5
		shape.height = size.y
		collision_shape.shape = shape
		collision_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		add_child(collision_shape)

	# 2. The body, from the one place that knows what things look like. The collider is
	# built from the SAME declared size rather than measured off the art, because the
	# collider is what the grid and the Hero's reach agree on.
	_ensure_body()

	# 3. Floating 3D Label (Billboard Mode)
	if label_3d == null:
		label_3d = find_child("Label3D", true, false) as Label3D
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.outline_modulate = Color(0, 0, 0, 0.9)
		label_3d.position = Vector3(0.0, 1.7, 0.0)
		_apply_label_sizing(label_3d)
		add_child(label_3d)

## Colour and stature say whether there is anything left here.
##
## Applied to the whole body rather than to one mesh: since v0.5 the body is whatever
## VisualLibrary hands back, which may be several meshes sharing a material, and will be
## a model soon. Scaling the holder rather than a mesh inside it is what keeps that true.
##
## Colour is still doing the work of saying "cut out", which is thin -- a depleted tree
## should be a different shape, not a grey one. The seam for that is already here (the
## body is built with a "full" / "depleted" variant); see task 3 in AGENT-TASKS.md.
func _update_visuals() -> void:
	var cfg = _get_config()
	var col = Color(0.4, 0.4, 0.4)
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(resource_type):
		var data: Dictionary = cfg.RESOURCE_NODES[resource_type]
		col = data.get("depleted_color", Color(0.3, 0.3, 0.3)) if is_depleted else data.get("color", Color(0.5, 0.5, 0.5))

	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi != null:
			mi.material_override = mat

	var squash: Vector3 = Vector3(0.9, 0.35, 0.9) if is_depleted else Vector3.ONE
	var body := find_child("Body", false, false)
	if body is Node3D:
		(body as Node3D).scale = squash
	if collision_shape:
		collision_shape.scale = squash

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

## Applies Config.UI sizing so world-space text stays readable at any zoom.
func _apply_label_sizing(lbl: Label3D) -> void:
	var fs: int = 64
	var px: float = 0.0045
	var fixed: bool = true
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		fs = int(cfg.UI.get("world_label_font_size", fs))
		px = float(cfg.UI.get("world_label_pixel_size", px))
		fixed = bool(cfg.UI.get("world_label_fixed_size", fixed))
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lbl.font_size = fs
	lbl.pixel_size = px
	lbl.fixed_size = fixed
	lbl.outline_size = maxi(1, int(round(fs / 6.0)))

## Whether this node still has something to give. Asked by the Hero and by the
## build preview, so "is this worth harvesting" is answered in exactly one place.
func is_available() -> bool:
	return not is_depleted and current_amount > 0 and not is_queued_for_deletion()
