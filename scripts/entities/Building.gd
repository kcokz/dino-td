# res://scripts/entities/Building.gd
class_name Building
extends StaticBody3D

## Base entity class for all stationary structures.
## Extends StaticBody3D on Physics Layer 2 ("Buildings") to provide collision for dinos.

@export var building_type: String = ""
@export var max_hp: float = 10.0
@export var current_hp: float = 10.0
@export var cell_pos: Vector2i = Vector2i.ZERO

@export var build_time: float = 2.0
@export var build_progress: float = 1.0
@export var is_constructed: bool = true

var is_destroyed: bool = false

func _init(p_type: String = "") -> void:
	if p_type != "":
		setup(p_type)

func _ready() -> void:
	_ensure_physics_and_visuals()
	_update_construction_state()

## Configures building stats from Config.BUILDINGS dictionary.
func setup(type_id: String, p_cell: Vector2i = Vector2i.ZERO) -> void:
	building_type = type_id
	cell_pos = p_cell
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(type_id):
		var data: Dictionary = cfg.BUILDINGS[type_id]
		max_hp = float(data.get("hp", 10.0))
		current_hp = max_hp
		build_time = float(data.get("build_time", 2.0))

# ==============================================================================
# Construction & Semi-finished Progress (v0.1)
# ==============================================================================

## Starts construction mode, turning the building into an unconstructed blueprint.
func start_construction(time_required: float = -1.0) -> void:
	var cfg = _get_config()
	if time_required >= 0.0:
		build_time = time_required
	elif cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(building_type):
		build_time = float(cfg.BUILDINGS[building_type].get("build_time", 2.0))
	
	if build_time <= 0.0:
		complete_construction()
		return
	
	is_constructed = false
	build_progress = 0.0
	_update_construction_state()
	var eb = _get_event_bus()
	if eb and eb.has_signal("build_progress_updated"):
		eb.build_progress_updated.emit(self, build_progress)

## Advances construction progress by delta_time. Returns true when 100% finished.
func add_build_progress(delta_time: float) -> bool:
	if is_constructed:
		return true
	if build_time <= 0.0:
		complete_construction()
		return true
	
	build_progress = minf(1.0, build_progress + (delta_time / build_time))
	var eb = _get_event_bus()
	if eb and eb.has_signal("build_progress_updated"):
		eb.build_progress_updated.emit(self, build_progress)
	
	if build_progress >= 1.0:
		complete_construction()
		return true
	
	_update_visuals_progress()
	return false

## Finalizes construction, restoring collision layer and full interactivity.
func complete_construction() -> void:
	is_constructed = true
	build_progress = 1.0
	_update_construction_state()
	var eb = _get_event_bus()
	if eb and eb.has_signal("build_progress_updated"):
		eb.build_progress_updated.emit(self, 1.0)

func _update_construction_state() -> void:
	if is_constructed:
		collision_layer = 2
		for child in get_children():
			if child is CollisionShape3D:
				child.disabled = false
	else:
		collision_layer = 0
		for child in get_children():
			if child is CollisionShape3D:
				child.disabled = true
	_update_visuals_progress()

func _update_visuals_progress() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat = child.material_override
			if mat is StandardMaterial3D:
				if is_constructed:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.albedo_color.a = 1.0
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = 0.4 + 0.5 * build_progress

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
