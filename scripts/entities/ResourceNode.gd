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
## Whether the player has this one picked, and how long its figure stays up after a stroke on it.
var _picked: bool = false
var _worked_for: float = 0.0
## Strokes put into the unit still coming out (strokes_each): a wreck's search so far.
var _struck: int = 0

func _init(p_type: String = "wood", p_cell: Vector2i = Vector2i.ZERO) -> void:
	resource_type = p_type
	cell_pos = p_cell

func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("selectable")
	_ensure_components()
	setup(resource_type, cell_pos)
	_connect_event_bus()
	set_process(false)

func _exit_tree() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("locale_changed"):
		if eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)
	for pair in [["unit_selected", _on_unit_selected], ["unit_deselected", _on_unit_deselected]]:
		if eb and is_instance_valid(eb) and eb.has_signal(pair[0]) and eb.is_connected(pair[0], pair[1]):
			eb.disconnect(pair[0], pair[1])

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("locale_changed"):
		if not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)
	for pair in [["unit_selected", _on_unit_selected], ["unit_deselected", _on_unit_deselected]]:
		if eb and eb.has_signal(pair[0]) and not eb.is_connected(pair[0], pair[1]):
			eb.connect(pair[0], pair[1])

# ------------------------------------------------------------------------------
# Its name and what is left in it, over it: only when it matters (v0.6 round three: "界面质感在于
# 细节，要和网页游戏区分开"). Every tree and rock wore "Wood 150 / 150" all the time -- a field of
# captions, cut through by the fronds. It shows while the node is picked, and for a few seconds
# after each stroke on it (Config.FEEDBACK.node_label_seconds); the rest of the time the hover ring
# and the panel say what it is.
# ------------------------------------------------------------------------------

func _on_unit_selected(unit: Node) -> void:
	_picked = unit == self
	_show_label()

func _on_unit_deselected() -> void:
	_picked = false
	_show_label()

func _show_label() -> void:
	if label_3d != null:
		label_3d.visible = _picked or _worked_for > 0.0
	set_process(_worked_for > 0.0)

func _process(delta: float) -> void:
	_worked_for = maxf(0.0, _worked_for - delta)
	if _worked_for <= 0.0:
		_show_label()

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
	# How much the valley holds (CUSTOM_GAME "resources"): a tree, a rock that much more or less -- not a wreck's
	# one part.
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else _game_state_anywhere()
	if gs and gs.has_method("run_scale") and max_capacity > 1:
		max_capacity = maxi(1, int(round(float(max_capacity) * float(gs.run_scale("resource_amount")))))

	current_amount = max_capacity
	is_depleted = (current_amount <= 0)
	_struck = 0
	_ensure_components()
	_update_visuals()
	_update_label()

## `amount` strokes' worth of work on it; returns what came out. Every stroke brings a tree's wood
## in; a wreck's part comes out only at the last of its search's strokes (strokes_each).
func harvest(amount: int = 1) -> int:
	if is_depleted or current_amount <= 0:
		return 0
	var yield_amt: int = 0
	var work: int = strokes_each()
	if work > 1:
		_struck += maxi(0, amount)
		# Every stroke of a search is heard (Din: the din of metal carries).
		var eb_din = _get_event_bus()
		if eb_din and eb_din.has_signal("wreck_struck"):
			eb_din.wreck_struck.emit(self, mini(_struck, work), work)
		if _struck >= work:
			_struck = 0
			yield_amt = 1
	else:
		yield_amt = mini(amount, current_amount)
	current_amount -= yield_amt
	if current_amount <= 0:
		current_amount = 0
		is_depleted = true
		# Rebuild, not just recolour: the cut-out state is a different model now.
		if is_inside_tree():
			_ensure_body()
		_update_visuals()
	_update_label()
	var cfg = _get_config()
	_worked_for = float(cfg.FEEDBACK.get("node_label_seconds", 3.0)) if (cfg and "FEEDBACK" in cfg) else 3.0
	_show_label()
	return yield_amt

## Strokes of work each unit takes to come out (RESOURCE_NODES "strokes"): one for a tree or a rock,
## ten for a wreck, whose one part comes out of a search.
func strokes_each() -> int:
	return maxi(1, int(_node_row().get("strokes", 1)))

## What is left in it and what it held, in strokes for a search, in units for the rest: what its
## label and its card count down.
func _left() -> int:
	var work: int = strokes_each()
	return current_amount * work - _struck if work > 1 else current_amount

func _whole() -> int:
	return max_capacity * strokes_each()

func get_localized_name() -> String:
	var cfg = _get_config()
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(resource_type):
		var raw_key = cfg.RESOURCE_NODES[resource_type].get("name", resource_type)
		return TranslationServer.translate(raw_key)
	return TranslationServer.translate("RESOURCE_" + resource_type.to_upper())

## How big this kind of node is, as Config declares it. A tree is tall, an outcrop is
## low and wide, a pool is almost flat -- and until v0.5 all three were the same
## cylinder, because the size lived in this file instead of in Config.
## Whether this node blocks by a trunk narrower than what it is clicked by.
func has_trunk() -> bool:
	return float(_node_row().get("trunk_radius", 0.0)) > 0.0

## How far out from its middle this node is in anybody's way: its trunk, or its whole
## declared width. What the Hero stands against to work it.
func block_radius() -> float:
	var trunk: float = float(_node_row().get("trunk_radius", 0.0))
	return trunk if trunk > 0.0 else _declared_size().x * 0.5

func _node_row() -> Dictionary:
	var cfg = _get_config()
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(resource_type):
		return cfg.RESOURCE_NODES[resource_type]
	return {}

func _pick_layer() -> int:
	var cfg = _get_config()
	return int(cfg.LAYER_PICK) if (cfg and "LAYER_PICK" in cfg) else 64

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
	# 1. CollisionShape3D on layer 1 (World / Obstacles) -- or, for a thing whose trunk is
	# narrower than its crown, the crown-sized shape on the picking layer and a trunk that
	# blocks (Config.LAYER_PICK).
	var trunk: float = block_radius() if has_trunk() else 0.0
	collision_layer = _pick_layer() if trunk > 0.0 else 1
	collision_mask = 0
	if collision_shape == null:
		collision_shape = find_child("CollisionShape3D", false, false) as CollisionShape3D
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
	if trunk > 0.0 and find_child("Trunk", false, false) == null:
		var stem := StaticBody3D.new()
		stem.name = "Trunk"
		stem.collision_layer = 1
		stem.collision_mask = 0
		var stem_shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = trunk
		cyl.height = size.y
		stem_shape.shape = cyl
		stem_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		stem.add_child(stem_shape)
		add_child(stem)

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
		label_3d.position = Vector3(0.0, 1.7, 0.0)
		UiTheme.style_world_label(label_3d)
		label_3d.visible = false
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

	# Only tint a body that has nothing to say for itself. A real model carries its own
	# colours -- bark, fronds, stone -- and painting the whole thing one flat green was
	# turning a cycad into a green cylinder and an outcrop into a grey lump, which is
	# most of the reason they still looked like placeholders after they stopped being
	# placeholders.
	if not _has_model():
		var mat = StandardMaterial3D.new()
		mat.albedo_color = col
		for node in find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi != null:
				mi.material_override = mat

	# Being cut out is said by the model itself now -- a stump with splinters, a quarry
	# with rubble round it -- so squashing it is only for the plain placeholder.
	var squash: Vector3 = Vector3.ONE
	if is_depleted and not _has_model():
		squash = Vector3(0.9, 0.35, 0.9)
	var body := find_child("Body", false, false)
	if body is Node3D:
		(body as Node3D).scale = squash
	if collision_shape:
		collision_shape.scale = squash

## Whether this node is drawn by a real model rather than by a primitive.
func _has_model() -> bool:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_placeholder_style"):
		return false
	var style: String = String(cfg.get_placeholder_style("node/" + resource_type))
	return not (style in ["box", "cylinder", "cone", "spikes"])

func _update_label() -> void:
	if label_3d == null:
		return
	var status_text: String
	if is_depleted:
		status_text = TranslationServer.translate(String(_node_row().get("depleted_text", "STATUS_DEPLETED")))
		label_3d.modulate = Color(0.7, 0.7, 0.7, 0.8)
		label_3d.text = "%s\n[%s]" % [get_localized_name(), status_text]
	else:
		label_3d.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_3d.text = "%s\n%d / %d" % [get_localized_name(), _left(), _whole()]

func get_display_info() -> Dictionary:
	var info: Dictionary = {
		"title": get_localized_name(),
		"type": "resource_node",
		"resource_type": resource_type,
		"current_amount": _left(),
		"max_capacity": _whole(),
		"is_depleted": is_depleted,
		"status": _panel_status(),
	}
	# What kind of thing it is, when it is not simply a place to gather: a wreck of the ship.
	if _node_row().has("kind"):
		info["kind_text"] = String(_node_row()["kind"])
	return info

## The line under a node's reserve bar: that it is spent, what it takes before bare hands
## can work it (Config.missing_tool_hint), or how to set him to it.
func _panel_status() -> String:
	if is_depleted:
		return TranslationServer.translate(String(_node_row().get("depleted_text", "STATUS_DEPLETED")))
	# A wreck says what is in it and how long the search is.
	var hint: String = String(_node_row().get("hint", ""))
	if hint != "":
		return TranslationServer.translate(hint) % [TranslationServer.translate("RESOURCE_%s" % resource_type.to_upper()),
			int(round(float(strokes_each()) / maxf(0.1, harvest_rate)))]
	var cfg = _get_config()
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if cfg and cfg.has_method("harvest_requires_unlock"):
		var flag: String = String(cfg.harvest_requires_unlock(resource_type))
		if flag != "" and not (gs and gs.has_method("has_unlock") and gs.has_unlock(flag)):
			var known: Callable = gs.knows if (gs and gs.has_method("knows")) else Callable()
			return String(cfg.missing_tool_hint(resource_type, known))
	return TranslationServer.translate("NODE_HINT")

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

## Whether this node still has something to give. Asked by the Hero and by the
## build preview, so "is this worth harvesting" is answered in exactly one place.
func is_available() -> bool:
	return not is_depleted and current_amount > 0 and not is_queued_for_deletion()

## GameState, from anywhere -- a node not yet in the tree too (setup runs before it is added).
func _game_state_anywhere() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameState") if loop is SceneTree else null
