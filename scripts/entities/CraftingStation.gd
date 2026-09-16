# res://scripts/entities/CraftingStation.gd
class_name CraftingStation
extends StaticBody3D

## A bench in the cabin. The workbench turns materials into abilities, the kitchen
## turns meat into blueprints, and both are this same class with a different id --
## adding a third station is a Config entry plus a node in the cabin scene, not a
## new system.
##
## What a station makes is a **permanent flag**, never an object: unlocked means
## usable, so there is no bag to open, nothing to carry and nothing to lose. That
## is the line that stops the cabin becoming an inventory screen.
##
## Work costs real seconds and the world does not stop while they pass -- while
## the Hero is at the bench, nobody is holding the line. Leaving keeps the
## progress made so far, the same way an unfinished building keeps its.

const GROUP: String = "stations"

@export var station_id: String = "workbench"

var active_recipe: String = ""
var progress: float = 0.0          # seconds of work done on active_recipe
var mesh_instance: MeshInstance3D = null
var label_3d: Label3D = null
var selection_ring: Node3D = null

func _init(p_station: String = "") -> void:
	if p_station != "":
		station_id = p_station

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group("selectable")
	_ensure_components()
	_refresh_label()

# ==============================================================================
# Making things
# ==============================================================================

## Recipes this bench offers, straight from Config.
func recipes() -> Array[String]:
	var cfg = _get_config()
	if cfg and cfg.has_method("recipes_at"):
		return cfg.recipes_at(station_id)
	return []

## Whether `recipe_id` is worth offering: it belongs here, and it has not already
## been made. A recipe whose flag is already set is finished forever.
func can_offer(recipe_id: String) -> bool:
	var data: Dictionary = recipe_data(recipe_id)
	if data.is_empty() or String(data.get("station", "")) != station_id:
		return false
	var gs = _get_game_state()
	if gs and gs.has_method("has_unlock") and gs.has_unlock(String(data.get("unlocks", ""))):
		return false
	return true

## Whether the warehouse currently holds what `recipe_id` costs.
func can_afford(recipe_id: String) -> bool:
	var gs = _get_game_state()
	if gs == null or not ("resources" in gs):
		return false
	for res_id in inputs_of(recipe_id):
		if int(gs.resources.get(res_id, 0)) < int(inputs_of(recipe_id)[res_id]):
			return false
	return true

## Begins work, spending the inputs up front. Returns false and changes nothing if
## the recipe is not on offer here or cannot be paid for.
##
## Inputs are spent at the start rather than on completion so that walking away
## mid-job costs something; the progress is kept, but the materials are already in
## the bench.
func begin(recipe_id: String) -> bool:
	if not can_offer(recipe_id) or not can_afford(recipe_id):
		return false
	if active_recipe == recipe_id:
		return true          # already working on exactly this
	if active_recipe != "":
		return false         # one job at a time; cancel is not a thing yet
	var gs = _get_game_state()
	if gs and gs.has_method("spend_resources"):
		if not gs.spend_resources(inputs_of(recipe_id)):
			return false
	elif gs and "resources" in gs:
		for res_id in inputs_of(recipe_id):
			gs.resources[res_id] = int(gs.resources.get(res_id, 0)) - int(inputs_of(recipe_id)[res_id])
	active_recipe = recipe_id
	progress = 0.0
	_refresh_label()
	return true

## Advances the current job by `delta` seconds. Public so the cabin drives it only
## while the Hero is actually standing there, and so a test can drive it without
## waiting on the clock. Returns the unlock granted this tick, or "".
func work(delta: float) -> String:
	if active_recipe == "" or delta <= 0.0:
		return ""
	progress += delta
	if progress < time_of(active_recipe):
		_refresh_label()
		return ""

	var done: String = active_recipe
	var unlock: String = String(recipe_data(done).get("unlocks", ""))
	active_recipe = ""
	progress = 0.0
	var gs = _get_game_state()
	if gs and gs.has_method("grant_unlock"):
		gs.grant_unlock(unlock)
	var fx = _get_fx()
	if fx and fx.has_method("play") and "Sound" in fx and fx.Sound.has("BUILD_DONE"):
		fx.play(fx.Sound.BUILD_DONE)
	_refresh_label()
	return unlock

func ratio() -> float:
	var total: float = time_of(active_recipe)
	if active_recipe == "" or total <= 0.0:
		return 0.0
	return clampf(progress / total, 0.0, 1.0)

# ==============================================================================
# Recipe lookups -- every one of them goes through Config
# ==============================================================================

func recipe_data(recipe_id: String) -> Dictionary:
	var cfg = _get_config()
	if cfg and "RECIPES" in cfg and cfg.RECIPES.has(recipe_id):
		return cfg.RECIPES[recipe_id]
	return {}

func inputs_of(recipe_id: String) -> Dictionary:
	return recipe_data(recipe_id).get("inputs", {})

func time_of(recipe_id: String) -> float:
	return float(recipe_data(recipe_id).get("time", 0.0))

func recipe_name(recipe_id: String) -> String:
	var key: String = String(recipe_data(recipe_id).get("name", recipe_id))
	return TranslationServer.translate(key)

func get_localized_name() -> String:
	return TranslationServer.translate("STATION_%s_NAME" % station_id.to_upper())

# ==============================================================================
# Selection panel
# ==============================================================================

func get_display_info() -> Dictionary:
	var status: String = tr("CABIN_HINT_PICK_STATION")
	if active_recipe != "":
		var raw: String = tr("CRAFT_IN_PROGRESS")
		status = (raw % [recipe_name(active_recipe), int(ratio() * 100.0)]) if ("%" in raw) else raw
	return {
		"title": get_localized_name(),
		"type": "station",
		"station_id": station_id,
		"status": status,
		"active_recipe": active_recipe,
		"progress": ratio(),
	}

func set_selected_visual(on: bool) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("set_shown"):
		selection_ring.set_shown(on)

# ==============================================================================
# Presentation
# ==============================================================================

func _ensure_components() -> void:
	collision_layer = 2      # same layer as buildings, so the same click raycast finds it
	collision_mask = 0

	var size := Vector3(1.4, 1.0, 0.9)
	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
	if not has_shape:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		col.position = Vector3(0.0, size.y * 0.5, 0.0)
		add_child(col)

	if mesh_instance == null:
		mesh_instance = find_child("MeshInstance3D", false, false) as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _colour()
		mesh_instance.material_override = mat
		mesh_instance.position = Vector3(0.0, size.y * 0.5, 0.0)
		add_child(mesh_instance)

	if label_3d == null:
		label_3d = find_child("Label3D", false, false) as Label3D
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.outline_modulate = Color(0, 0, 0, 0.9)
		label_3d.position = Vector3(0.0, size.y + 0.5, 0.0)
		label_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cfg = _get_config()
		if cfg and "UI" in cfg:
			label_3d.font_size = int(cfg.UI.get("world_label_font_size", 48))
			label_3d.pixel_size = float(cfg.UI.get("world_label_pixel_size", 0.005))
			label_3d.fixed_size = bool(cfg.UI.get("world_label_fixed_size", false))
			label_3d.outline_size = maxi(1, int(round(label_3d.font_size / 6.0)))
		add_child(label_3d)

	if selection_ring == null:
		selection_ring = find_child("SelectionRing", false, false)
	if selection_ring == null:
		var ring_script = load("res://scripts/fx/SelectionRing3D.gd")
		if ring_script:
			selection_ring = ring_script.new()
			selection_ring.name = "SelectionRing"
			add_child(selection_ring)
	if selection_ring and selection_ring.has_method("configure"):
		selection_ring.configure(SelectionRing3D.Shape.BOX, maxf(size.x, size.z))

func _refresh_label() -> void:
	if label_3d == null or not is_instance_valid(label_3d):
		return
	if active_recipe == "":
		label_3d.text = get_localized_name()
		label_3d.modulate = Color(1, 1, 1)
	else:
		label_3d.text = "%s\n[ %d%% ]" % [recipe_name(active_recipe), int(ratio() * 100.0)]
		label_3d.modulate = Color(1.0, 0.85, 0.3)

func _colour() -> Color:
	match station_id:
		"kitchen": return Color(0.72, 0.36, 0.26)
		"workbench": return Color(0.55, 0.45, 0.32)
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

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
