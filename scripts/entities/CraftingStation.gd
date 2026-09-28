# res://scripts/entities/CraftingStation.gd
class_name CraftingStation
extends StaticBody3D

## A bench in the cabin. The workbench turns materials into tools, the kitchen makes
## the pots he cooks in and cooks his meals, the beacon's bench repairs and launches the
## beacon, and all three are this same class with a different id -- adding a station is a
## Config entry plus a node in the cabin scene, not a new system.
##
## What a station makes is a **permanent flag**, never an object: unlocked means
## usable, so there is no bag to open, nothing to carry and nothing to lose. That
## is the line that stops the cabin becoming an inventory screen. A meal (Config.
## DISHES) is not a flag, and it is not an object either: it is eaten the moment it is
## done (GAME-DESIGN 4.5: no bag, no stored food). A step of the beacon (Config.
## beacon_job) is neither: finishing it moves the run towards its end (GameState).
##
## Work costs real seconds and the world does not stop while they pass -- while
## the Hero is at the bench, nobody is holding the line. Leaving keeps the
## progress made so far, the same way an unfinished building keeps its.

const GROUP: String = "stations"

@export var station_id: String = "workbench"

var active_recipe: String = ""
var progress: float = 0.0          # seconds of work done on active_recipe
var mesh_instance: MeshInstance3D = null
## The bench's model (Config.VISUALS "station/<id>", tools/generate_cabin.py), or null while
## it has none and is drawn as a box.
var body: Node3D = null
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
	var eb = _get_event_bus()
	if eb:
		for sig in _PART_SIGNALS:
			if eb.has_signal(sig) and not eb.is_connected(sig, _on_run_changed):
				eb.connect(sig, _on_run_changed)

func _exit_tree() -> void:
	var eb = _get_event_bus()
	if eb:
		for sig in _PART_SIGNALS:
			if eb.has_signal(sig) and eb.is_connected(sig, _on_run_changed):
				eb.disconnect(sig, _on_run_changed)

## What moves the run on in a way a bench shows: a tool or a pot made, a stage of the
## beacon repaired, the beacon launched.
const _PART_SIGNALS: Array[String] = ["unlock_granted", "beacon_changed", "beacon_launched"]

func _on_run_changed(_arg = null) -> void:
	refresh_parts()

# ==============================================================================
# Making things
# ==============================================================================

## Recipes this bench offers, straight from Config.
func recipes() -> Array[String]:
	var cfg = _get_config()
	if cfg and cfg.has_method("recipes_at"):
		return cfg.recipes_at(station_id)
	return []

## The meals this bench cooks -- the kitchen's, and nobody else's.
func dishes() -> Array[String]:
	var cfg = _get_config()
	if cfg and cfg.has_method("dishes_at"):
		return cfg.dishes_at(station_id)
	return []

## Whether `job_id` is a meal rather than a recipe.
func is_dish(job_id: String) -> bool:
	var cfg = _get_config()
	return cfg != null and "DISHES" in cfg and cfg.DISHES.has(job_id)

## Whether `job_id` is one of the beacon's steps on the run's map.
func is_beacon_job(job_id: String) -> bool:
	return not _beacon_row(job_id).is_empty()

## Everything this bench does, in the order the cabin panel lists it: its recipes, its
## meals, and -- at the beacon's bench -- the beacon's next step. One step at a time and
## in order, so the panel always says what the beacon needs next (GAME-DESIGN 14.3).
func jobs() -> Array[String]:
	var out: Array[String] = recipes()
	out.append_array(dishes())
	var gs = _get_game_state()
	var step: String = String(gs.beacon_next_job()) if (gs and gs.has_method("beacon_next_job")) else ""
	if step != "" and String(_beacon_row(step).get("station", "")) == station_id:
		out.append(step)
	return out

## Whether `recipe_id` is worth offering: it belongs here, and it has not already
## been made. A recipe whose flag is already set is finished forever; a meal is
## cooked as often as there is meat for it.
func can_offer(recipe_id: String) -> bool:
	return _still_to_do(recipe_id) and (is_beacon_job(recipe_id) or _materials_known(recipe_id))

## Whether `recipe_id` belongs here and is still to be done, whatever the run has turned up:
## a meal always, the beacon's next step, a tool or pot not yet made.
func _still_to_do(recipe_id: String) -> bool:
	var data: Dictionary = recipe_data(recipe_id)
	if data.is_empty() or String(data.get("station", "")) != station_id:
		return false
	if is_dish(recipe_id):
		return true
	var gs = _get_game_state()
	if is_beacon_job(recipe_id):
		return gs != null and gs.has_method("beacon_next_job") and String(gs.beacon_next_job()) == recipe_id
	if gs and gs.has_method("has_unlock") and gs.has_unlock(String(data.get("unlocks", ""))):
		return false
	# A better one of its slot in his row already (Config.outclassed): the vest after the armour.
	var cfg = _get_config()
	if gs and cfg and cfg.has_method("outclassed") and "unlocks" in gs and cfg.outclassed(recipe_id, gs.unlocks):
		return false
	return true

## Whether every material `recipe_id` takes has turned up in this run (GameState.knows):
## until then it is not on offer -- the pick is not shown before the bone (v0.6). The
## beacon's steps are exempt: they are the run's goal, and always say what they need.
func _materials_known(recipe_id: String) -> bool:
	var gs = _get_game_state()
	return gs == null or not gs.has_method("knows_all") or gs.knows_all(inputs_of(recipe_id))

## Whether this bench has work still to come, waiting only on a material to turn up.
func waiting_on_materials() -> bool:
	for job in jobs():
		if _still_to_do(String(job)) and not is_beacon_job(String(job)) and not _materials_known(String(job)):
			return true
	return false

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
## waiting on the clock. Returns the unlock granted this tick, or "" -- including
## when what finished was a meal, which goes into his stock to be eaten when the player
## says (GameState.stock_meal; v0.6 round two -- it used to be eaten on the spot).
func work(delta: float) -> String:
	if active_recipe == "" or delta <= 0.0:
		return ""
	progress += delta
	if progress < time_of(active_recipe):
		_refresh_label()
		return ""

	var done: String = active_recipe
	var unlock: String = ""
	active_recipe = ""
	progress = 0.0
	var gs = _get_game_state()
	if is_dish(done):
		if gs and gs.has_method("stock_meal"):
			gs.stock_meal(done)
	elif is_beacon_job(done):
		if gs and gs.has_method("finish_beacon_job"):
			gs.finish_beacon_job(done)
	else:
		unlock = String(recipe_data(done).get("unlocks", ""))
		if gs and gs.has_method("grant_unlock"):
			gs.grant_unlock(unlock)
	# Heard as what it was: a meal off the fire, a tool off the bench, the beacon's tone.
	var fx = _get_fx()
	if fx and fx.has_method("play_at") and is_inside_tree():
		var id: String = "craft_done"
		if is_dish(done):
			id = "cook_done"
		elif is_beacon_job(done):
			var cfg = _get_config()
			id = "beacon_launch" if (cfg and done == String(cfg.BEACON_LAUNCH)) else "beacon_stage"
		fx.play_at(id, global_position + Vector3(0.0, 0.8, 0.0))
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

## A job's row -- a recipe's, a meal's or a beacon step's; they have the same shape
## (station, inputs, time, name), which is what lets one bench take any of them.
func recipe_data(recipe_id: String) -> Dictionary:
	var cfg = _get_config()
	if cfg and "RECIPES" in cfg and cfg.RECIPES.has(recipe_id):
		return cfg.RECIPES[recipe_id]
	if cfg and "DISHES" in cfg and cfg.DISHES.has(recipe_id):
		return cfg.DISHES[recipe_id]
	return _beacon_row(recipe_id)

## A beacon step's row, from the map this run is played on.
func _beacon_row(job_id: String) -> Dictionary:
	var cfg = _get_config()
	var gs = _get_game_state()
	if cfg == null or not cfg.has_method("beacon_job") or gs == null or not gs.has_method("map_data"):
		return {}
	return cfg.beacon_job(gs.map_data(), job_id)

func inputs_of(recipe_id: String) -> Dictionary:
	return recipe_data(recipe_id).get("inputs", {})

func time_of(recipe_id: String) -> float:
	return float(recipe_data(recipe_id).get("time", 0.0))

## A meal is named for how it will be cooked -- roast meat, seared meat -- which is his
## best pot's doing, not the dish's (Config.COOKING_METHODS).
func recipe_name(recipe_id: String) -> String:
	var key: String = String(recipe_data(recipe_id).get("name", recipe_id))
	var title: String = TranslationServer.translate(key)
	var args: Array = recipe_data(recipe_id).get("name_args", [])
	if not args.is_empty() and "%" in title:
		return title % args
	if not is_dish(recipe_id):
		return title
	var fmt: String = TranslationServer.translate(String(meal_preview(recipe_id).get("method_name", "")))
	return (fmt % title) if "%s" in fmt else title

## What eating `dish_id` would do, cooked the way his pots allow right now.
func meal_preview(dish_id: String) -> Dictionary:
	var cfg = _get_config()
	var gs = _get_game_state()
	if cfg == null or not cfg.has_method("meal_of"):
		return {}
	var owned: Dictionary = gs.unlocks if (gs and "unlocks" in gs) else {}
	var meal: Dictionary = cfg.meal_of(dish_id, owned)
	meal["method_name"] = String(cfg.cooking_method(owned).get("name", ""))
	return meal

func get_localized_name() -> String:
	return TranslationServer.translate("STATION_%s_NAME" % station_id.to_upper())

# ==============================================================================
# Selection panel
# ==============================================================================

func get_display_info() -> Dictionary:
	# Idle, a bench says what it is for -- or that it has nothing to make -- except the beacon's,
	# which says where the beacon has got to: that is the run's main line (GAME-DESIGN 14.3),
	# so it is the first thing it says.
	var status: String = _beacon_status()
	if status == "":
		status = _purpose()
	var info: Dictionary = {
		"title": get_localized_name(),
		"type": "station",
		"station_id": station_id,
		"status": status,
		"active_recipe": active_recipe,
		"progress": ratio(),
	}
	# A job under way is the work bar, and what it is -- and, while he is out of the cabin, that
	# it waits for him to come back (CoreCampfire works the benches only while he is inside).
	if active_recipe != "":
		info["work"] = ratio()
		info["work_label"] = recipe_name(active_recipe)
		info["status"] = "" if _he_is_here() else TranslationServer.translate("STATION_ONLY_WITH_HIM")
	return info

## What the bench is for, or that it has nothing to make -- yet, when new materials would bring
## new work.
func _purpose() -> String:
	for job_id in jobs():
		if can_offer(job_id):
			return TranslationServer.translate("STATION_%s_DESC" % station_id.to_upper())
	return TranslationServer.translate("STATION_NOTHING_YET" if waiting_on_materials() else "STATION_NOTHING")

## Whether the Hero is in the cabin this bench stands in.
func _he_is_here() -> bool:
	var cabin: Node = get_parent()
	return cabin != null and "hero_inside" in cabin and bool(cabin.hero_inside)

## Which parts of the bench's model show: the tools made hang on the board, the pot stands
## on the fire once it is made, the beacon's mast is as far up as its stages (CabinArt).
func refresh_parts() -> void:
	if body != null and is_instance_valid(body):
		CabinArt.show_parts(body, _is_job, job_done)

## Whether `job_id` is done for good in this run: a tool's or a pot's flag is held, a stage
## of the beacon stands repaired, the beacon is launched. A meal never is -- it is cooked
## again -- and neither is anything that is not a job.
func job_done(job_id: String) -> bool:
	var gs = _get_game_state()
	if gs == null:
		return false
	if is_beacon_job(job_id):
		var cfg = _get_config()
		var steps: Array = cfg.beacon_jobs(gs.map_data()) if (cfg and cfg.has_method("beacon_jobs")) else []
		var at: int = steps.find(job_id)
		return at >= 0 and at < int(gs.beacon_steps)
	var flag: String = String(recipe_data(job_id).get("unlocks", ""))
	return flag != "" and gs.has_method("has_unlock") and gs.has_unlock(flag)

func _is_job(job_id: String) -> bool:
	return not recipe_data(job_id).is_empty()

func set_selected_visual(on: bool) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("set_shown"):
		selection_ring.set_shown(on)

# ==============================================================================
# Presentation
# ==============================================================================

func _ensure_components() -> void:
	collision_layer = 2      # same layer as buildings, so the same click raycast finds it
	collision_mask = 0

	# Clicked by its declared size, and drawn as the model Config names fitted to that same
	# size -- or a box of it while there is no model.
	var key: String = "station/%s" % station_id
	var cfg_size = _get_config()
	var size: Vector3 = cfg_size.get_visual_size(key) if (cfg_size and cfg_size.has_method("get_visual_size")) else Vector3.ONE
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

	if body == null and mesh_instance == null and VisualLibrary.has_art(key):
		body = VisualLibrary.make(key)
		add_child(body)
		CabinArt.light_glows(body, _glow_lights())
		refresh_parts()
	if body == null and mesh_instance == null:
		mesh_instance = find_child("MeshInstance3D", false, false) as MeshInstance3D
	if body == null and mesh_instance == null:
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

	# A name floating over a box says which box is which. A bench that looks like itself needs
	# none -- and the cabin's dock names it anyway.
	if label_3d == null:
		label_3d = find_child("Label3D", false, false) as Label3D
	if label_3d == null and body == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.position = Vector3(0.0, size.y + 0.5, 0.0)
		UiTheme.style_world_label(label_3d)
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
		selection_ring.configure(SelectionRing3D.Shape.BOX, size.x, size.z)

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
		"beacon": return Color(0.25, 0.52, 0.66)   # the ship's own kit, not something he made
		_: return Color(0.6, 0.6, 0.6)

## Where the beacon has got to, in words, when this is the bench it is worked at -- or "".
func _beacon_status() -> String:
	var cfg = _get_config()
	var gs = _get_game_state()
	if cfg == null or gs == null or not cfg.has_method("beacon_status") or not ("BEACON_STATION" in cfg):
		return ""
	if String(cfg.BEACON_STATION) != station_id:
		return ""
	return String(cfg.beacon_status(gs.map_data(), int(gs.beacon_steps), float(gs.beacon_charge)))

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

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null

## The lights the glowing parts of the benches carry (Config.CABIN.glow_lights).
func _glow_lights() -> Dictionary:
	var cfg = _get_config()
	return cfg.CABIN.get("glow_lights", {}) if (cfg and "CABIN" in cfg) else {}

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
