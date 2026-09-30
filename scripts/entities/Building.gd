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
var status_bar: Node3D = null
var selection_ring: Node3D = null
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
	# The last stroke waits for its ground to be clear: a building that went solid round a
	# dinosaur or the Hero would hold it inside for good. What is in the way is said on its panel.
	var in_the_way: Node = unit_in_the_way() if build_progress >= 1.0 else null
	if in_the_way != null:
		build_progress = _held_progress()
	_blocked_by = in_the_way
	var eb = _get_event_bus()
	if eb and eb.has_signal("build_progress_updated"):
		eb.build_progress_updated.emit(self, build_progress)

	if build_progress >= 1.0:
		complete_construction()
		return true
	
	_update_visuals_progress()
	_update_info_label()
	return false

## What stood in the way of its last stroke, the last time one was struck, or null.
var _blocked_by: Node = null

## The Hero or a dinosaur whose body is in this building's cells, or null: its box against theirs
## (Config.gap_to_building), their own half-width.
func unit_in_the_way() -> Node:
	if not is_inside_tree():
		return null
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("gap_to_building"):
		return null
	for group_name in ["hero", "dinos"]:
		for unit in get_tree().get_nodes_in_group(group_name):
			if unit == null or not is_instance_valid(unit) or not (unit is Node3D):
				continue
			if "is_dead" in unit and unit.is_dead:
				continue
			var half: float = 0.4
			if unit.is_in_group("hero"):
				half = float(cfg.HERO.get("width", 0.8)) * 0.5
			elif "dino_type" in unit and cfg.has_method("get_visual_size"):
				half = float(cfg.get_visual_size("dino/" + String(unit.dino_type)).x) * 0.5
			if float(cfg.gap_to_building((unit as Node3D).global_position, building_type, global_position)) < half:
				return unit
	return null

## How far a building waiting for its ground to clear is held: a hair short of done, so the next
## stroke once it is clear finishes it.
func _held_progress() -> float:
	return 1.0 - 0.001

## Finalizes construction, restoring collision layer and full interactivity.
func complete_construction() -> void:
	var was_under_construction: bool = not is_constructed
	is_constructed = true
	build_progress = 1.0
	if was_under_construction:
		_sound("build_done")
	_update_construction_state()
	_update_info_label()
	var eb = _get_event_bus()
	if eb and eb.has_signal("build_progress_updated"):
		eb.build_progress_updated.emit(self, 1.0)
	# The world just changed shape. See EventBus.building_completed -- without this the
	# navigation meshes never learn that a blueprint has become a wall.
	if was_under_construction and eb and eb.has_signal("building_completed"):
		eb.building_completed.emit(self)

## Finished work is solid. Unfinished work is CLICKABLE BUT SOLID TO NOBODY.
##
## A blueprint used to get layer 0 and a disabled shape, which does stop it blocking
## anyone -- and also makes it invisible to the click raycast, so a half-built stake
## could not be clicked to carry on with. Walk away from one and the work was stranded.
##
## Config.LAYER_BLUEPRINT is looked for by the picking ray and by nothing else, so a
## blueprint can be pointed at without ever being in anybody's way.
func _update_construction_state() -> void:
	var cfg = _get_config()
	var blueprint_layer: int = int(cfg.LAYER_BLUEPRINT) if (cfg and "LAYER_BLUEPRINT" in cfg) else 16
	var solid_layer: int = 2
	# A wall is on a layer of its own (Config.LAYER_WALL), and a gate -- the wall the Hero walks
	# through -- on another (LAYER_GATE), which his body and his mesh leave out.
	if cfg and cfg.has_method("walk_over") and cfg.walk_over(building_type):
		# In nobody's way: only on the layer it is pointed at by (Config.LAYER_PICK), which no body is
		# stopped by and no mesh is carved for.
		solid_layer = int(cfg.LAYER_PICK) if "LAYER_PICK" in cfg else 64
	elif cfg and "LAYER_WALL" in cfg and cfg.has_method("get_building_kind"):
		if cfg.has_method("hero_passes") and cfg.hero_passes(building_type):
			solid_layer = int(cfg.LAYER_GATE)
		elif String(cfg.get_building_kind(building_type)) == "wall":
			solid_layer = int(cfg.LAYER_WALL)
	collision_layer = solid_layer if is_constructed else blueprint_layer
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
	_update_visuals_progress()
	_update_avoidance()

## Finished, it is in the raiders' steering too (Config.DINO_AI.building_avoidance_layers): an
## outline of its box the engine's avoidance steers them round. Steering round each other, they knew
## nothing of walls, and a raptor squeezed at a fence corner was steered into the fence and swung its
## head there (the debug-agent's BUG-009). The outline is its box less the steering's margin
## (DINO_AI.avoid_margin), so a body still comes up against its face and the places to bite it from
## are clear of it. The Hero's steering leaves it out -- he goes through his gates -- and so does a
## siege animal's (Dino.walks_round_walls). A blueprint is in nobody's way.
func _update_avoidance() -> void:
	var cfg = _get_config()
	var layers: int = int(cfg.DINO_AI.get("building_avoidance_layers", 0)) if (cfg and "DINO_AI" in cfg) else 0
	var obstacle := find_child("AvoidObstacle", false, false) as NavigationObstacle3D
	if obstacle == null:
		if layers == 0 or not is_constructed or is_destroyed or not cfg.has_method("get_building_half"):
			return
		if cfg.has_method("walk_over") and cfg.walk_over(building_type):
			return
		var margin: float = float(cfg.DINO_AI.get("avoid_margin", 0.1))
		var half: Vector2 = cfg.get_building_half(building_type) - Vector2.ONE * margin
		half = Vector2(maxf(half.x, margin), maxf(half.y, margin))
		obstacle = NavigationObstacle3D.new()
		obstacle.name = "AvoidObstacle"
		obstacle.affect_navigation_mesh = false
		obstacle.avoidance_layers = layers
		obstacle.height = _building_height()
		obstacle.vertices = PackedVector3Array([Vector3(-half.x, 0.0, -half.y), Vector3(half.x, 0.0, -half.y),
			Vector3(half.x, 0.0, half.y), Vector3(-half.x, 0.0, half.y)])
		add_child(obstacle)
	obstacle.avoidance_enabled = is_constructed and not is_destroyed

## A blueprint is drawn translucent and fills in as it goes up.
##
## This walks the body rather than only the direct children: every visible mesh
## lives inside the "Body" node make_body() returns, so looking one level deep meant
## no building has actually faded since make_body was introduced -- blueprints were
## indistinguishable from finished work.
func _update_visuals_progress() -> void:
	for child in _body_meshes():
		var mat = child.material_override
		if mat is StandardMaterial3D and not CabinArt.owns(mat):
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

## Subclass hook triggered upon taking non-fatal or fatal damage. Feedback only:
## until v0.3 this was empty, so a building being chewed on gave the player nothing
## to see or hear.
##
## Every piece of the body flashes, not just the first: a stake is several cones, and
## lighting one of three would read as a graphical fault rather than as a hit.
func _on_damaged(_amount: float) -> void:
	var fx = _get_fx()
	if fx == null:
		return
	for mesh in _body_meshes():
		fx.flash(mesh)
	_sound_hit()

## Bitten, it sounds of what it is made of: timber, stone, the cabin's plate (SOUNDS.hit_by_building).
func _sound_hit() -> void:
	var cfg = _get_config()
	var id: String = "wood_hit"
	if cfg and "SOUNDS" in cfg:
		id = String(cfg.SOUNDS.get("hit_by_building", {}).get(String(building_type), cfg.SOUNDS.get("hit_default", id)))
	_sound(id)

## Executes destruction sequence: signals EventBus, marks is_destroyed, queues free.
func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	_spawn_destruction_fx()
	_on_before_destroy()
	# Out of the world at once. The meshes are baked again this very frame, on the signal below
	# (NavMaps), and a building still standing in the physics while it waited to be freed was baked
	# in as solid -- the gap a fallen wall left did not open until something else was built.
	collision_layer = 0
	var obstacle: Node = find_child("BakeObstacle", false, false)
	if obstacle is NavigationObstacle3D:
		(obstacle as NavigationObstacle3D).affect_navigation_mesh = false
	_update_avoidance()

	var eb = _get_event_bus()
	if eb and eb.has_signal("building_destroyed"):
		eb.building_destroyed.emit(self)
	
	queue_free()

## Subclass hook executed immediately before building_destroyed signal.
func _on_before_destroy() -> void:
	pass

## Restores HP up to max_hp.
## Whether this building is worth working on: finished, standing, and short of
## full health.
func needs_repair() -> bool:
	return is_constructed and not is_destroyed and current_hp < max_hp

## How much of the building is missing, 0..1.
func damage_fraction() -> float:
	if max_hp <= 0.0 or not needs_repair():
		return 0.0
	return clampf((max_hp - current_hp) / max_hp, 0.0, 1.0)

## The bill: the building's own price scaled by how much of it is missing, rounded
## up, in every resource it was built from.
##
## Scaling the real price is what keeps this honest -- mending can never cost more
## than building the thing again, and a scratch costs the minimum rather than a
## flat fee. Rounding up means the cheapest possible repair is one unit, which is
## also why a one-wood stake is not worth mending: replacing it is the same price
## and it comes back at full health.
func repair_cost() -> Dictionary:
	var out: Dictionary = {}
	var fraction: float = damage_fraction()
	if fraction <= 0.0:
		return out
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(building_type):
		return out
	for res_id in cfg.BUILDINGS[building_type].get("cost", {}):
		var price: int = int(cfg.BUILDINGS[building_type]["cost"][res_id])
		var owed: int = int(ceil(price * fraction))
		if owed > 0:
			out[res_id] = mini(owed, price)   # never more than building it again
	return out

## The bill added up, for a menu that has one line to say it in.
func repair_price_total() -> int:
	var sum: int = 0
	for res_id in repair_cost():
		sum += int(repair_cost()[res_id])
	return sum

## How long the Hero has to stand there. Derived from the size of the bill, so
## patching a scratch is quick and rebuilding most of a turret is not.
func repair_seconds() -> float:
	var cfg = _get_config()
	var per: float = 1.2
	if cfg and "REPAIR" in cfg:
		per = float(cfg.REPAIR.get("seconds_per_unit", per))
	return maxf(0.1, per * float(repair_price_total()))

## Pays the bill and puts the building back to full. One transaction at the end of
## the work: walking away costs the time spent and nothing else, so there is never
## a half-paid building to reason about.
##
## The bill is worked out again here rather than trusted from when the job started,
## so damage taken during the repair is charged for rather than mended free.
func finish_repair() -> bool:
	if not needs_repair():
		return false
	var owed: Dictionary = repair_cost()
	var gs = _get_game_state()
	if gs == null or owed.is_empty():
		return false
	if gs.has_method("spend_resources"):
		if not gs.spend_resources(owed):
			return false
	elif "resources" in gs:
		for res_id in owed:
			if int(gs.resources.get(res_id, 0)) < int(owed[res_id]):
				return false
		for res_id in owed:
			gs.resources[res_id] = int(gs.resources[res_id]) - int(owed[res_id])
	heal(max_hp - current_hp)
	return true

func heal(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)
	_update_info_label()

# ==============================================================================
# Upgrading where it stands (v0.6)
# ==============================================================================
## The building this one is being turned into, and how far the work has got (0..1).
##
## An upgrade is paid for when it is ordered -- the deal a blueprint gets -- and the old
## building keeps working the whole time the Hero builds the new one onto it: upgrading
## costs him time and materials, never a hole in the defence (GAME-DESIGN 6.1: a line of
## buildings upgrades in place).
var upgrading_to: String = ""
var upgrade_progress: float = 0.0

## What this building becomes when upgraded, or "" at the end of its line.
func upgrade_target() -> String:
	var cfg = _get_config()
	return String(cfg.upgrade_target(building_type)) if (cfg and cfg.has_method("upgrade_target")) else ""

## Everything it can become where it stands (Config.upgrade_targets): a fence, bone stakes or a
## stone wall (GAME-DESIGN 6.0).
func upgrade_targets() -> Array[String]:
	var cfg = _get_config()
	return cfg.upgrade_targets(building_type) if (cfg and cfg.has_method("upgrade_targets")) else ([] as Array[String])

## Finished, standing, with somewhere further up its line to go -- `target`, or anywhere, with none
## named -- and not already on its way.
func can_upgrade(target: String = "") -> bool:
	if not is_constructed or is_destroyed or upgrading_to != "":
		return false
	var all: Array[String] = upgrade_targets()
	return not all.is_empty() if target == "" else all.has(target)

func is_upgrading() -> bool:
	return upgrading_to != ""

## What turning it into `target` costs (the first it can become, with none named): the difference
## between this building's price and that one's.
func upgrade_cost(target: String = "") -> Dictionary:
	var cfg = _get_config()
	return cfg.upgrade_cost(building_type, target) if (cfg and cfg.has_method("upgrade_cost")) else {}

## Pays for turning it into `target` (the first it can become, with none named) and marks the work
## as there to be done. False, with nothing spent, when it cannot become that or the warehouse
## cannot pay for it.
func begin_upgrade(target: String = "") -> bool:
	if target == "":
		target = upgrade_target()
	if not can_upgrade(target):
		return false
	var gs = _get_game_state()
	if gs == null or not gs.has_method("spend_resources") or not gs.spend_resources(upgrade_cost(target)):
		return false
	upgrading_to = target
	upgrade_progress = 0.0
	_update_info_label()
	return true

## Advances the upgrade by `delta` seconds of the Hero's work. True once it is done -- or
## when there was nothing to do.
func add_upgrade_progress(delta: float) -> bool:
	if not is_upgrading():
		return true
	var cfg = _get_config()
	var total: float = float(cfg.get_upgrade_time(building_type, upgrading_to)) if (cfg and cfg.has_method("get_upgrade_time")) else 0.0
	upgrade_progress = 1.0 if total <= 0.0 else minf(1.0, upgrade_progress + maxf(0.0, delta) / total)
	if upgrade_progress >= 1.0:
		_finish_upgrade()
		return true
	_update_info_label()
	return false

## Becomes the new building: its numbers (a tower's rate and range come with setup), as
## much of its health as the old one had, and its own body if it is drawn differently.
func _finish_upgrade() -> void:
	var was: String = building_type
	var health: float = (current_hp / max_hp) if max_hp > 0.0 else 1.0
	var to: String = upgrading_to
	upgrading_to = ""
	upgrade_progress = 0.0
	if _takes_another_body(to):
		_become(to, health)
		return
	setup(to, cell_pos)
	current_hp = max_hp * health
	_rebuild_body(was)
	_after_upgrade()
	_sound("build_done")
	_update_info_label()
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_upgraded"):
		eb.building_upgraded.emit(self)

## Whether what it becomes is another kind of thing, made of another script (BuildSystem.script_for): a
## stone wall with a crossbow set into it shoots, and a wall does not.
func _takes_another_body(to: String) -> bool:
	var mine: Script = get_script() as Script
	var path: String = BuildSystem.script_for(to)
	return mine != null and path != "" and mine.resource_path != path

## Becomes `to` by a new building of it going up in its cells, as whole as this one was (`health`), and
## facing out from the cabin if it faces at all -- and this one gone without a fall: building_upgraded is
## said of the new one, and nothing of this one being destroyed, for it was not.
func _become(to: String, health: float) -> void:
	var gm: Node = get_tree().get_first_node_in_group("grid_manager") if is_inside_tree() else null
	var parent: Node = get_parent()
	if gm == null or parent == null or not gm.has_method("cells_of"):
		return
	var script: Script = load(BuildSystem.script_for(to)) as Script
	if script == null:
		return
	var cells: Array = gm.cells_of(self)
	var fresh: Node = script.new()
	fresh.setup(to, cell_pos)
	fresh.position = position
	if "facing" in fresh:
		fresh.facing = _facing_out()
	gm.vacate_building(self)
	is_destroyed = true
	collision_layer = 0
	_update_avoidance()
	parent.add_child(fresh)
	gm.occupy_building(fresh, cells)
	if fresh.has_method("complete_construction"):
		fresh.complete_construction()
	fresh.current_hp = fresh.max_hp * clampf(health, 0.0, 1.0)
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_upgraded"):
		eb.building_upgraded.emit(fresh)
	queue_free()

## Which way out of the cabin it stands (Trap.FACINGS): the facing nearest the way from the cabin's middle
## to it -- a crossbow set into a wall looks out of the wall.
func _facing_out() -> int:
	var core: Node3D = get_tree().get_first_node_in_group("core") as Node3D if is_inside_tree() else null
	if core == null:
		return 0
	var out: Vector3 = global_position - core.global_position
	var best: int = 0
	var best_dot: float = -INF
	var facings: Array = [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)]
	for i in facings.size():
		var d: float = (facings[i] as Vector2).dot(Vector2(out.x, out.z))
		if d > best_dot:
			best_dot = d
			best = i
	return best

## What else changes with what it is: whose way it stands in (a campfire is stepped over, the brazier
## it becomes is not: Config.walk_over) -- its layer and the steering round it. A kind with more of its
## own to change (Fire: its flame) adds to this.
func _after_upgrade() -> void:
	# Its box the size of what it is now: a campfire's hand-high ring raised into a chest-high
	# brazier stood no higher to the navigation mesh, and the way across climbed over it.
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var fp: float = _footprint()
			var h: float = _building_height()
			((child as CollisionShape3D).shape as BoxShape3D).size = Vector3(fp, h, fp)
			(child as CollisionShape3D).position = Vector3(0.0, h * 0.5, 0.0)
	_update_construction_state()

## Swaps the body for the one this type declares -- only when it is a different thing to
## draw, so a tower II still in the tower's model keeps its head turned at its target.
func _rebuild_body(old_type: String) -> void:
	var cfg = _get_config()
	if cfg and "VISUALS" in cfg:
		var before: Dictionary = cfg.VISUALS.get("building/" + old_type, {})
		var after: Dictionary = cfg.VISUALS.get("building/" + building_type, {})
		if String(before.get("scene", "")) == String(after.get("scene", "")) \
				and String(before.get("placeholder", "")) == String(after.get("placeholder", "")):
			return
	var old: Node = get_node_or_null("Body")
	if old != null:
		remove_child(old)
		old.queue_free()
	_build_body_mesh()

## Takes the building down and leaves half its price in the rubble. Since v0.3 the
## refund is dropped rather than banked -- it was the last way resources reached
## the warehouse without passing through the Hero's hands, and he is standing right
## there anyway, so in play it feels the same.
func demolish() -> void:
	if is_destroyed:
		return
	if is_constructed:
		for res_name in demolition_refund():
			var amount: int = int(demolition_refund()[res_name])
			if amount > 0 and is_inside_tree():
				DropItem.spawn_scattered(self, global_position, String(res_name), amount, amount)
	destroy()

## Half of what it cost, rounded so taking down even the cheapest thing gives
## something back.
func demolition_refund() -> Dictionary:
	var refund: Dictionary = {}
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(building_type):
		return refund
	var cost: Dictionary = cfg.BUILDINGS[building_type].get("cost", {})
	for res_name in cost:
		refund[res_name] = maxi(1, int(cost[res_name] / 2))
	return refund

func get_localized_name() -> String:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_name"):
		return cfg.get_building_name(building_type)
	return TranslationServer.translate("BUILDING_" + building_type.to_upper() + "_NAME")

func _get_extra_status_text() -> String:
	return ""

func _update_info_label() -> void:
	_update_status_bar()
	if label_3d == null:
		return
	var b_name = get_localized_name()
	if not is_constructed:
		label_3d.modulate = Color(1.0, 0.85, 0.3)
		label_3d.text = "%s\n[ %d%% ]" % [b_name, int(build_progress * 100.0)]
	elif is_upgrading():
		var cfg_up = _get_config()
		var to_name: String = String(cfg_up.get_building_name(upgrading_to)) if cfg_up else upgrading_to
		label_3d.modulate = Color(1.0, 0.85, 0.3)
		label_3d.text = "%s\n[ %d%% ]" % [to_name, int(upgrade_progress * 100.0)]
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

	# Nothing to report, nothing on screen -- the same rule the health bar already
	# follows. It became urgent the moment stakes could be built close together: a
	# twenty-stake fence put twenty floating names across the middle of the screen, and
	# each one said "Wooden Stakes" about a thing that is obviously a wooden stake.
	#
	# Since v0.6 round three, hurt or going up is not enough either: the bar over it already
	# says so, and a raid on the fence hung "Palisade 2 / 8 HP" in red over every section it bit,
	# overlapping, the way a debug overlay looks ("要和网页游戏区分开"). The words show while it is
	# the one picked -- and while it says something only it can (_get_extra_status_text).
	var worth_saying: bool = _picked or _get_extra_status_text() != ""
	var hide_idle: bool = true
	var cfg_label = _get_config()
	if cfg_label and "FEEDBACK" in cfg_label:
		hide_idle = bool(cfg_label.FEEDBACK.get("name_label_hide_when_idle", true))
	label_3d.visible = worth_saying or not hide_idle

## Health once built, construction progress before that. Hidden at full health so
## an untouched base is not covered in bars.
func _update_status_bar() -> void:
	if status_bar == null or not is_instance_valid(status_bar):
		return
	if not is_constructed:
		status_bar.visible = true
		status_bar.set_ratio(build_progress, Color(1.0, 0.82, 0.25, 0.95))
		return
	# An upgrade under way shows its progress the way construction does: it is building.
	if is_upgrading():
		status_bar.visible = true
		status_bar.set_ratio(upgrade_progress, Color(1.0, 0.82, 0.25, 0.95))
		return
	var ratio: float = (current_hp / max_hp) if max_hp > 0.0 else 0.0
	var hide_full: bool = true
	var cfg = _get_config()
	if cfg and "FEEDBACK" in cfg:
		hide_full = bool(cfg.FEEDBACK.get("health_bar_hide_at_full", true))
	status_bar.visible = not (hide_full and ratio >= 0.999)
	status_bar.set_ratio(ratio, Color(0.85, 0.3, 0.25, 0.95) if ratio < 0.35 else Color(0.3, 0.85, 0.35, 0.95))

## The selection ring says "this is what you clicked". The coverage ring, handled
## separately, says "this is what it affects" -- keeping them distinct matters.
func set_selected_visual(on: bool) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("set_shown"):
		selection_ring.set_shown(on)
	if _picked != on:
		_picked = on
		_update_info_label()

## Whether this is the one the player has picked: its words show over it only then.
var _picked: bool = false

## What the command card shows: its health as a bar, work under way -- going up, or being
## upgraded -- as a second bar ("work", 0..1, with what the work is), and under them the one
## line only this building has to say (_panel_status: a tower's fire, a stake's bite).
func get_display_info() -> Dictionary:
	var info: Dictionary = {
		"title": get_localized_name(),
		"type": "building",
		"building_type": building_type,
		"hp": current_hp,
		"max_hp": max_hp,
		"is_constructed": is_constructed,
		"build_progress": build_progress,
		"status": _panel_status() if is_constructed else _waiting_status(),
	}
	if not is_constructed:
		info["work"] = build_progress
		info["work_label"] = tr("WORK_CONSTRUCTING")
	elif is_upgrading():
		info["work"] = upgrade_progress
		info["work_label"] = tr("WORK_UPGRADING")
	return info

## The line under a building's bars: nothing, unless it has something of its own to say.
func _panel_status() -> String:
	return ""

## An order held back from its last stroke says why: somebody is standing where it goes.
func _waiting_status() -> String:
	if _blocked_by != null and is_instance_valid(_blocked_by):
		return tr("STATUS_WAITING_CLEAR")
	return ""

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
		var h: float = _building_height()
		box.size = Vector3(fp, h, fp)
		col.shape = box
		col.position = Vector3(0.0, h * 0.5, 0.0)
		add_child(col)
	
	# 2b. Marked out of the navigation bake, if it is wide enough to have room inside.
	_ensure_bake_obstacle()

	# 3. Add the body if missing. A "spikes" body is a holder of uprights rather
	# than a MeshInstance3D of its own, so it has to be recognised by name or a
	# second call here would quietly draw a second fence on top of the first.
	var has_mesh = false
	for child in get_children():
		if child is MeshInstance3D or (child is Node3D and child.name == "Body"):
			has_mesh = true
			break
	if not has_mesh:
		_build_body_mesh()

	# 4. Add Label3D if missing (v0.2 In-World 3D Building Text & Info)
	if label_3d == null:
		label_3d = find_child("Label3D", true, false) as Label3D
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.position = Vector3(0.0, _building_height() + 0.8, 0.0)
		UiTheme.style_world_label(label_3d)
		add_child(label_3d)

	# 5. Status bar and selection ring (v0.3 feedback layer)
	if status_bar == null:
		status_bar = find_child("StatusBar", true, false)
	if status_bar == null:
		var bar_script = load("res://scripts/fx/StatusBar3D.gd")
		if bar_script:
			status_bar = bar_script.new()
			status_bar.name = "StatusBar"
			status_bar.position = Vector3(0.0, _building_height() + 0.55, 0.0)
			add_child(status_bar)

	if selection_ring == null:
		selection_ring = find_child("SelectionRing", true, false)
	if selection_ring == null:
		var ring_script = load("res://scripts/fx/SelectionRing3D.gd")
		if ring_script:
			selection_ring = ring_script.new()
			selection_ring.name = "SelectionRing"
			add_child(selection_ring)
	# The outline traces the building's own box -- seven by three for the cabin.
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("configure"):
		var half: Vector2 = _get_config().get_building_half(building_type) if _get_config() else Vector2.ONE * 0.5
		selection_ring.configure(SelectionRing3D.Shape.BOX, half.x * 2.0, half.y * 2.0)

## The visible body. Height is what makes a building read as imposing -- widening
## one eats into the lane the Hero needs to get past, while height costs nothing.
## "spikes" draws a row of thin uprights instead of a block, so stakes look like
## stakes driven into the ground while still occupying the whole tile.
func _build_body_mesh() -> void:
	add_child(make_body(building_type))

## The visible body for `type_id`, as a node the caller parents wherever it likes.
##
## Static and type-keyed on purpose: the real building and the ghost that promises it
## are drawn by the same code, so a preview can never show a shape the finished thing
## does not have.
##
## Since v0.5 it is one line, because the seam moved: VisualLibrary answers "what does
## this look like" for everything in the game, and a model arriving is a line of
## Config.VISUALS rather than an edit here. This stays as a named entry point because
## callers ask the question about a BUILDING type, and the key is not their business.
## No arrangement argument any more: a stake is one cone whatever is beside it, so
## there is nothing about a building's body that depends on its neighbours.
static func make_body(type_id: String) -> Node3D:
	return VisualLibrary.make("building/" + type_id)

func _building_height() -> float:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_height"):
		return float(cfg.get_building_height(building_type))
	return 1.0

## Every mesh that IS the building, which is the whole of the "Body" holder plus, for
## anything authored without one, its own direct meshes.
##
## Deliberately not a recursive sweep of the node: the status bar, the selection ring
## and the coverage ring are all meshes hanging off a building without being part of
## it. Fading them with a blueprint, or flashing them when it is bitten, would put
## the feedback layer inside the thing it is reporting on.
func _body_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var body := find_child("Body", false, false)
	if body != null:
		for node in body.find_children("*", "MeshInstance3D", true, false):
			out.append(node as MeshInstance3D)
	for child in get_children():
		if child is MeshInstance3D and child != range_indicator:
			out.append(child)
	return out

func _mesh_style() -> String:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_mesh_style"):
		return String(cfg.get_building_mesh_style(building_type))
	return "box"

func _get_placeholder_color() -> Color:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_color"):
		return cfg.get_building_color(building_type)
	return Color(0.6, 0.6, 0.6)

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
	range_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_indicator.visible = false
	add_child(range_indicator)

func set_range_visible(p_visible: bool) -> void:
	if range_indicator and is_instance_valid(range_indicator):
		range_indicator.visible = p_visible





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
	set_selected_visual(unit == self)

func _on_unit_deselected() -> void:
	set_selected_visual(false)
	set_range_visible(false)

## Construction time is derived from the building's price (Config.get_build_time),
## so cost is the single number a designer tunes.
func _resolve_build_time() -> float:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_build_time"):
		return float(cfg.get_build_time(building_type))
	return 2.0

## Marks this building's box out of the navigation bake as a solid (NavMaps.mark_solid), when it
## is more than a cell across: under the cabin's roof the bake found a floor with headroom, and
## the nearest walkable point to the cabin was always in there, where no route can go.
##
## ONLY FOR WHAT IS WIDER THAN A CELL. An obstacle is carved out of EVERY mesh, whatever it was
## baked for -- so on a gate it shut the Hero's own way through it, and on a wall it put walls
## into the siege mesh, which is baked to have none. The sliver of island a metre of wall leaves
## on its top is thrown away by the bake itself (Config.NAV.region_min_size).
func _ensure_bake_obstacle() -> void:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_building_cells"):
		return
	if int(cfg.get_building_cells(building_type)) <= 1:
		return
	# A building with an inside -- the cabin -- is walls and a room, not a block (CoreCampfire).
	if cfg.has_method("is_hollow") and cfg.is_hollow(building_type):
		return
	NavMaps.mark_solid(self, _footprint() * 0.5, _building_height())

## Side length of this building's box: its cells of the building grid (Config.BUILD_CELL).
func _footprint() -> float:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_footprint"):
		return float(cfg.get_building_footprint(building_type))
	return 1.0

# ==============================================================================
# Feedback hooks
# ==============================================================================

## The first mesh that IS the building. The same answer _body_meshes gives, because it
## asks it: this used to look one level into Body and no deeper, which was right while
## every building was primitives -- and found nothing the moment the stake became a model,
## whose mesh sits a level further down inside the imported scene.
func _visual_mesh() -> MeshInstance3D:
	var meshes := _body_meshes()
	return meshes[0] if not meshes.is_empty() else null

## Throws debris in this building's own colour as it comes down.
func _spawn_destruction_fx() -> void:
	var fx = _get_fx()
	if fx == null or not is_inside_tree():
		return
	fx.debris(global_position, _get_placeholder_color())
	_sound("wood_break")

## Sound `id` where it stands (Fx.play_at).
func _sound(id: String) -> void:
	var fx = _get_fx()
	if fx and fx.has_method("play_at") and is_inside_tree():
		fx.play_at(id, global_position + Vector3(0.0, 0.5, 0.0))

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
