# res://scripts/entities/DropItem.gd
class_name DropItem
extends Node3D

## A pile of something lying on the ground, waiting for the Hero to walk over it.
##
## v0.3 routes every resource through one of these. Before, resources arrived two
## unrelated ways -- hand-harvesting walked a number into the warehouse, and a
## tended machine simply made the number go up on its own. Now a dinosaur leaves
## meat, a machine leaves what it cut at its feet, and the opening stock is
## scattered by the cabin: "one body holds up a whole base" is only true if the
## body carries the goods as well as building with them.
##
## Three things this deliberately is not:
##   * not a physics body and not on the grid -- a drop must never block building
##     or pathing, which is why it is a plain Node3D with no collision at all;
##   * not selectable -- it is collected by walking over it, so turning drops into
##     one more thing to click would only move the clicking around;
##   * not perishable by default -- see the note on Config.DROPS.lifetime.
##
## Every number lives in Config.DROPS.

const GROUP: String = "drops"
const CONTAINER_NAME: String = "Drops"
## The level's own drop container joins this group. Name lookup alone is not
## enough: a scene scatters its opening stock from _ready(), which runs before
## SceneTree.current_scene has been assigned, so "look under the running scene"
## would miss the container the level had already made and stash everything under
## the tree root instead -- where a restart's sweep would never find it.
const CONTAINER_GROUP: String = "drops_container"

var resource_type: String = "wood"
var amount: int = 1
var age: float = 0.0
var lifetime: float = 0.0          # 0 = never rots
var is_collected: bool = false

var mesh_instance: MeshInstance3D = null
var label_3d: Label3D = null

var _base_y: float = 0.0

# ==============================================================================
# Creation
# ==============================================================================

## Puts `amount` of `res_id` on the ground at `world_pos`, merging into a pile of
## the same kind that is already there rather than carpeting the field in singles.
## Returns the pile the resources ended up in.
##
## `context` is any node in the tree -- the caller does not have to know where
## drops are kept.
static func spawn(context: Node, world_pos: Vector3, res_id: String, p_amount: int = 1) -> DropItem:
	if context == null or not is_instance_valid(context) or not context.is_inside_tree():
		return null
	if p_amount <= 0 or res_id.is_empty():
		return null

	var existing: DropItem = _find_pile_to_join(context, world_pos, res_id)
	if existing != null:
		existing.add_amount(p_amount)
		_announce(context, res_id, p_amount, existing.global_position)
		return existing

	var drop := DropItem.new()
	drop.name = "Drop_%s" % res_id
	drop.resource_type = res_id
	drop.amount = p_amount
	var holder: Node = _container(context)
	if holder == null:
		drop.free()
		return null
	holder.add_child(drop)
	drop.global_position = world_pos
	drop._base_y = world_pos.y
	drop._toss()
	_announce(context, res_id, p_amount, world_pos)
	return drop

## Scatters `p_amount` over `count` piles around `world_pos`, which is what a
## death or an opening stockpile looks like rather than one tidy cube.
static func spawn_scattered(context: Node, world_pos: Vector3, res_id: String, p_amount: int, count: int = 1) -> Array:
	var piles: Array = []
	if p_amount <= 0:
		return piles
	var n: int = clampi(count, 1, p_amount)
	var radius: float = _cfg(context, "scatter_radius", 0.8)
	var per: int = p_amount / n
	var extra: int = p_amount % n
	for i in range(n):
		var share: int = per + (1 if i < extra else 0)
		if share <= 0:
			continue
		var angle: float = randf() * TAU
		var dist: float = sqrt(randf()) * radius
		var at: Vector3 = world_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var pile := spawn(context, at, res_id, share)
		if pile != null and not piles.has(pile):
			piles.append(pile)
	return piles

## The pile a new drop should join: one of the same kind within merge_radius, or
## -- once the ground is at its cap -- the nearest pile of that kind anywhere.
## The cap limits how many *piles* exist, never how much the player keeps.
static func _find_pile_to_join(context: Node, world_pos: Vector3, res_id: String) -> DropItem:
	var all: Array = context.get_tree().get_nodes_in_group(GROUP)
	var merge_radius: float = _cfg(context, "merge_radius", 0.0)
	var at_cap: bool = all.size() >= int(_cfg(context, "max_on_ground", 200))

	var nearest: DropItem = null
	var nearest_dist: float = INF
	for d in all:
		if not (d is DropItem) or not is_instance_valid(d) or d.is_collected:
			continue
		if d.resource_type != res_id or not d.is_inside_tree():
			continue
		var dist: float = d.global_position.distance_to(world_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = d

	if nearest == null:
		return null
	if merge_radius > 0.0 and nearest_dist <= merge_radius:
		return nearest
	if at_cap:
		return nearest
	return null

## Drops live under the running scene, so restarting a level takes them with it.
## The level declares its own container (see CONTAINER_GROUP); a bare test tree
## has neither, and one is made under the tree root.
static func _container(context: Node) -> Node:
	var tree_ref := context.get_tree()
	if tree_ref == null:
		return null

	# A level's own container wins over the ad-hoc one a bare tree gets. They are
	# told apart by where they hang: the fallback below is always a child of the
	# tree root, and a level's container never is.
	var fallback: Node = null
	for holder in tree_ref.get_nodes_in_group(CONTAINER_GROUP):
		if not is_instance_valid(holder) or not holder.is_inside_tree():
			continue
		if holder.get_parent() == tree_ref.root:
			if fallback == null:
				fallback = holder
		else:
			return holder
	if fallback != null:
		return fallback

	var host: Node = tree_ref.current_scene
	if host == null or not is_instance_valid(host):
		host = tree_ref.root
	if host == null:
		return null
	var holder: Node = host.get_node_or_null(CONTAINER_NAME)
	if holder == null:
		holder = Node3D.new()
		holder.name = CONTAINER_NAME
		holder.add_to_group(CONTAINER_GROUP)
		host.add_child(holder)
	return holder

static func _announce(context: Node, res_id: String, p_amount: int, world_pos: Vector3) -> void:
	if context == null or not context.is_inside_tree():
		return
	var eb: Node = context.get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("resource_dropped"):
		eb.resource_dropped.emit(res_id, p_amount, world_pos)

static func _cfg(context: Node, key: String, fallback: float) -> float:
	var cfg: Node = null
	if context != null and context.is_inside_tree():
		cfg = context.get_node_or_null("/root/Config")
	if cfg == null and Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg and "DROPS" in cfg:
		return float(cfg.DROPS.get(key, fallback))
	return fallback

# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	add_to_group(GROUP)
	lifetime = _cfg(self, "lifetime", 0.0)
	_base_y = global_position.y
	_ensure_visuals()
	_refresh_label()

func _process(delta: float) -> void:
	if is_collected or lifetime <= 0.0:
		return
	var gs := _get_game_state()
	if gs and ("is_paused" in gs and gs.is_paused or "is_game_over" in gs and gs.is_game_over):
		return
	age += delta
	if age >= lifetime:
		rot()

## What is left when a drop has been on the ground too long. Only reachable when
## Config.DROPS.lifetime is above 0.
func rot() -> void:
	if is_collected:
		return
	is_collected = true
	remove_from_group(GROUP)
	queue_free()

# ==============================================================================
# Collection
# ==============================================================================

## Hands this pile over and banks it. Returns how much was collected, 0 if there
## was nothing left to take -- so a second collector in the same frame gets
## nothing rather than a duplicate of the same wood.
func collect(collector: Node = null) -> int:
	if is_collected or amount <= 0:
		return 0
	is_collected = true
	remove_from_group(GROUP)   # out of reach before the flight animation even starts

	var taken: int = amount
	var gs := _get_game_state()
	if gs and gs.has_method("add_resource"):
		gs.add_resource(resource_type, taken)
	elif gs and "resources" in gs:
		gs.resources[resource_type] = gs.resources.get(resource_type, 0) + taken

	var eb := _get_event_bus()
	if eb and eb.has_signal("resource_picked_up"):
		eb.resource_picked_up.emit(resource_type, taken, collector)

	var fx := _get_fx()
	if fx and fx.has_method("play") and "Sound" in fx and fx.Sound.has("PICKUP"):
		fx.play(fx.Sound.PICKUP)

	_fly_to(collector)
	return taken

func add_amount(extra: int) -> void:
	if extra <= 0 or is_collected:
		return
	amount += extra
	_refresh_label()

# ==============================================================================
# Presentation
# ==============================================================================

func _ensure_visuals() -> void:
	var size: float = _cfg(self, "size", 0.3)
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size
		mesh_instance.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _colour()
		mesh_instance.material_override = mat
		# A pile of wood must not darken the ground it is lying on.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.position = Vector3(0.0, size * 0.5, 0.0)
		add_child(mesh_instance)

	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.outline_modulate = Color(0, 0, 0, 0.9)
		label_3d.position = Vector3(0.0, size * 1.6, 0.0)
		label_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_label_sizing(label_3d)
		add_child(label_3d)

## Single units carry no label: a field of "1"s is noise, a pile of "12" is
## information.
func _refresh_label() -> void:
	if label_3d == null or not is_instance_valid(label_3d):
		return
	var min_amount: int = int(_cfg(self, "label_min_amount", 2))
	if amount >= min_amount:
		label_3d.text = str(amount)
		label_3d.visible = true
	else:
		label_3d.text = ""
		label_3d.visible = false

func _apply_label_sizing(lbl: Label3D) -> void:
	var cfg := _get_config()
	if cfg == null or not ("UI" in cfg):
		return
	var fs: int = int(cfg.UI.get("world_label_font_size", 48))
	lbl.font_size = fs
	lbl.pixel_size = float(cfg.UI.get("world_label_pixel_size", 0.005))
	lbl.fixed_size = bool(cfg.UI.get("world_label_fixed_size", false))
	lbl.outline_size = maxi(1, int(round(fs / 6.0)))

func _colour() -> Color:
	var cfg := _get_config()
	if cfg and cfg.has_method("get_resource_color"):
		return cfg.get_resource_color(resource_type)
	return Color(0.7, 0.7, 0.7)

## A short hop as it lands, so a drop reads as having been thrown out of something
## rather than having always been there.
func _toss() -> void:
	if not is_inside_tree() or mesh_instance == null:
		return
	var height: float = _cfg(self, "toss_height", 0.0)
	var time: float = _cfg(self, "toss_time", 0.0)
	if height <= 0.0 or time <= 0.0:
		return
	var up: Vector3 = mesh_instance.position + Vector3(0.0, height, 0.0)
	var down: Vector3 = mesh_instance.position
	var tw := create_tween()
	tw.tween_property(mesh_instance, "position", up, time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh_instance, "position", down, time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## The pile is already banked by the time this runs; this only stops it vanishing
## on the spot, which reads as the drop never having been collected at all.
func _fly_to(collector: Node) -> void:
	if not is_inside_tree():
		queue_free()
		return
	var time: float = _cfg(self, "fly_time", 0.0)
	if time <= 0.0 or collector == null or not is_instance_valid(collector) or not (collector is Node3D):
		queue_free()
		return
	if label_3d and is_instance_valid(label_3d):
		label_3d.visible = false
	var target: Vector3 = (collector as Node3D).global_position + Vector3(0.0, 0.6, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

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
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("EventBus")
	return null

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
