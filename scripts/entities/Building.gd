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
var label_3d: Label3D = null
var range_indicator: MeshInstance3D = null

## Order this blueprint was laid down in. The Hero works through pending blueprints
## oldest-first, so a row of stakes goes up in the order the player clicked them
## rather than in whatever order happens to be closest to him.
static var _next_build_order: int = 0
var build_order: int = -1

func _init(p_type: String = "") -> void:
	if p_type != "":
		setup(p_type)

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("selectable")
	_ensure_physics_and_visuals()
	_update_construction_state()
	_connect_event_bus()
	_create_range_indicator()
	_connect_selection_events()
	_update_info_label()

func _exit_tree() -> void:
	_disconnect_selection_events()
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
	_update_info_label()

## Configures building stats from Config.BUILDINGS dictionary.
func setup(type_id: String, p_cell: Vector2i = Vector2i.ZERO) -> void:
	building_type = type_id
	cell_pos = p_cell
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(type_id):
		var data: Dictionary = cfg.BUILDINGS[type_id]
		max_hp = float(data.get("hp", 10.0))
		current_hp = max_hp
		build_time = _resolve_build_time()
	_update_info_label()

# ==============================================================================
# Construction & Semi-finished Progress (v0.1)
# ==============================================================================

## Starts construction mode, turning the building into an unconstructed blueprint.
func start_construction(time_required: float = -1.0) -> void:
	var cfg = _get_config()
	if time_required >= 0.0:
		build_time = time_required
	elif cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(building_type):
		build_time = _resolve_build_time()
	
	if build_time <= 0.0:
		complete_construction()
		return
	
	is_constructed = false
	build_progress = 0.0
	if build_order < 0:
		build_order = _next_build_order
		_next_build_order += 1
	_update_construction_state()
	_update_info_label()
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
	_update_info_label()
	return false

## Finalizes construction, restoring collision layer and full interactivity.
func complete_construction() -> void:
	is_constructed = true
	build_progress = 1.0
	_update_construction_state()
	_update_info_label()
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
	_update_info_label()
	
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
	_update_info_label()

func demolish() -> void:
	if is_destroyed:
		return
	if is_constructed:
		var cfg = _get_config()
		if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(building_type):
			var cost: Dictionary = cfg.BUILDINGS[building_type].get("cost", {})
			var refund: Dictionary = {}
			for res_name in cost:
				refund[res_name] = maxi(1, int(cost[res_name] / 2))
			var gs = _get_game_state()
			if gs and gs.has_method("add_resources"):
				gs.add_resources(refund)
	destroy()

func get_localized_name() -> String:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_name"):
		return cfg.get_building_name(building_type)
	return TranslationServer.translate("BUILDING_" + building_type.to_upper() + "_NAME")

func _get_extra_status_text() -> String:
	return ""

func _update_info_label() -> void:
	if label_3d == null:
		return
	var b_name = get_localized_name()
	if not is_constructed:
		label_3d.modulate = Color(1.0, 0.85, 0.3)
		label_3d.text = "%s\n[ %d%% ]" % [b_name, int(build_progress * 100.0)]
	else:
		var extra = _get_extra_status_text()
		if extra != "":
			label_3d.modulate = Color(0.4, 0.9, 0.4)
			label_3d.text = "%s\n%s" % [b_name, extra]
		elif current_hp < max_hp:
			label_3d.modulate = Color(1.0, 0.4, 0.4)
			label_3d.text = "%s\n%d / %d HP" % [b_name, int(ceil(current_hp)), int(ceil(max_hp))]
		else:
			label_3d.modulate = Color(1.0, 1.0, 1.0)
			label_3d.text = b_name

func get_display_info() -> Dictionary:
	var status_str = ""
	if not is_constructed:
		var raw = tr("STATUS_CONSTRUCTING")
		status_str = (raw % int(build_progress * 100.0)) if ("%" in raw) else raw
	else:
		var raw = tr("STATUS_HP")
		status_str = (raw % [int(ceil(current_hp)), int(ceil(max_hp))]) if ("%" in raw) else raw

	return {
		"title": get_localized_name(),
		"type": "building",
		"building_type": building_type,
		"hp": current_hp,
		"max_hp": max_hp,
		"is_constructed": is_constructed,
		"build_progress": build_progress,
		"status": status_str
	}

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
		var fp: float = _footprint()
		box.size = Vector3(fp, 1.0, fp)
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
		var fp_m: float = _footprint()
		box_mesh.size = Vector3(fp_m, 1.0, fp_m)
		mesh_inst.mesh = box_mesh
		mesh_inst.position = Vector3(0.0, 0.5, 0.0)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_placeholder_color()
		mesh_inst.material_override = mat
		add_child(mesh_inst)

	# 4. Add Label3D if missing (v0.2 In-World 3D Building Text & Info)
	if label_3d == null:
		label_3d = find_child("Label3D", true, false) as Label3D
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.outline_modulate = Color(0, 0, 0, 0.9)
		label_3d.position = Vector3(0.0, 1.8, 0.0)
		_apply_label_sizing(label_3d)
		add_child(label_3d)

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

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
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
	lbl.font_size = fs
	lbl.pixel_size = px
	lbl.fixed_size = fixed
	lbl.outline_size = maxi(1, int(round(fs / 6.0)))


# ==============================================================================
# Coverage ring (shown while this building is selected)
# ==============================================================================

## Radius of this building's area of effect, in metres. 0 means "no ring".
## Towers override with their attack range; producers with their harvest range.
func _get_display_range() -> float:
	return 0.0

func _get_range_indicator_color() -> Color:
	var c := _get_placeholder_color()
	return Color(c.r, c.g, c.b, 0.16)

func _create_range_indicator() -> void:
	var r := _get_display_range()
	if r <= 0.0:
		return
	if range_indicator == null:
		range_indicator = find_child("RangeIndicator", true, false) as MeshInstance3D
	if range_indicator != null:
		return
	range_indicator = MeshInstance3D.new()
	range_indicator.name = "RangeIndicator"
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.05
	range_indicator.mesh = cyl
	range_indicator.position = Vector3(0.0, 0.05, 0.0)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _get_range_indicator_color()
	range_indicator.material_override = mat
	range_indicator.visible = false
	add_child(range_indicator)

func set_range_visible(p_visible: bool) -> void:
	if range_indicator and is_instance_valid(range_indicator):
		range_indicator.visible = p_visible
	_highlight_covered_nodes(p_visible)

## Lights up the resource nodes this building's ring actually covers, so the player
## can see at a glance what a producer is working with.
func _highlight_covered_nodes(on: bool) -> void:
	var r := _get_display_range()
	if r <= 0.0 or not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(n) or not n.has_method("set_highlighted"):
			continue
		if on and global_position.distance_to(n.global_position) <= r:
			n.set_highlighted(true)
		elif not on:
			n.set_highlighted(false)

func _connect_selection_events() -> void:
	var eb = _get_event_bus()
	if eb == null:
		return
	if eb.has_signal("unit_selected") and not eb.unit_selected.is_connected(_on_unit_selected):
		eb.unit_selected.connect(_on_unit_selected)
	if eb.has_signal("unit_deselected") and not eb.unit_deselected.is_connected(_on_unit_deselected):
		eb.unit_deselected.connect(_on_unit_deselected)

func _disconnect_selection_events() -> void:
	var eb = _get_event_bus()
	if eb == null or not is_instance_valid(eb):
		return
	if eb.has_signal("unit_selected") and eb.unit_selected.is_connected(_on_unit_selected):
		eb.unit_selected.disconnect(_on_unit_selected)
	if eb.has_signal("unit_deselected") and eb.unit_deselected.is_connected(_on_unit_deselected):
		eb.unit_deselected.disconnect(_on_unit_deselected)

func _on_unit_selected(unit: Node) -> void:
	set_range_visible(unit == self)

func _on_unit_deselected() -> void:
	set_range_visible(false)

## Construction time is derived from the building's price (Config.get_build_time),
## so cost is the single number a designer tunes.
func _resolve_build_time() -> float:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_build_time"):
		return float(cfg.get_build_time(building_type))
	return 2.0

## Side length of this building's box. Derived from Config so the gap between two
## neighbouring buildings always stays wider than the Hero (see BUILDING_CLEARANCE).
func _footprint() -> float:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_footprint"):
		return float(cfg.get_building_footprint())
	return 1.0
