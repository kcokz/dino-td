# res://scripts/entities/Nest.gd
class_name Nest
extends StaticBody3D

## The dinosaurs' nest: where the raids come out of, guarded by the animals that live
## there. Stationary, at the enemy spawn origin (0, 0, -18) / cell (0, -9), on physics
## its own layer (Config.LAYER_NEST).
##
## It cannot be destroyed (v0.6, decided -- Config.NEST): it has no hit points, so nothing
## can hurt it and nothing aims at it. v0.0-v0.5 were won by knocking it down, which came
## to walking a turret up to its face; a run is won by the beacon now (GameState).

# ==============================================================================
# Exported Properties
# ==============================================================================
@export var cell_pos: Vector2i = Vector2i(0, -9)

var guard_dinos: Array[Node] = []

# Child components
var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	collision_layer = _nest_layer()
	collision_mask = 0

func _ready() -> void:
	add_to_group("nest")
	collision_layer = _nest_layer()
	collision_mask = 0
	_ensure_components()

## The nest's own layer (Config.LAYER_NEST): clicked, and in nobody's way -- the raid comes out
## of it, and the dinosaurs' bodies collide on the layer it used to share with them.
func _nest_layer() -> int:
	var cfg = _get_config()
	return int(cfg.LAYER_NEST) if (cfg and "LAYER_NEST" in cfg) else 256

## Spawns NEST_GUARDS.count guard dinosaurs in orbit around the nest.
func spawn_guards(target_parent: Node = null) -> void:
	var p = target_parent if target_parent != null else get_parent()
	if p == null or not is_instance_valid(p):
		return
	var cfg = _get_config()
	var count: int = 3
	var post_radius: float = 3.0
	if cfg and "NEST_GUARDS" in cfg and cfg.NEST_GUARDS is Dictionary:
		count = int(cfg.NEST_GUARDS.get("count", 3))
		post_radius = float(cfg.NEST_GUARDS.get("post_radius", 3.0))

	var guard_script = load("res://scripts/entities/GuardDino.gd")
	if guard_script == null:
		return
	# The map's own animal (its "guards"): the Triassic valley's are Coelophysis.
	var species: String = "raptor"
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	var map: Dictionary = gs.map_data() if (gs and gs.has_method("map_data")) else (cfg.map_data() if cfg else {})
	if cfg and cfg.DINOS.has(String(map.get("guards", ""))):
		species = String(map["guards"])

	for i in range(count):
		var guard = guard_script.new(species)
		guard.name = "GuardDino_%d" % i
		var angle = (float(i) / float(maxi(1, count))) * TAU
		var offset = Vector3(cos(angle) * post_radius, 0.0, sin(angle) * post_radius)
		var post_pos = global_position + offset
		p.add_child(guard)
		guard.setup_post(post_pos)
		guard_dinos.append(guard)

## Where it stands, as a cell.
func setup(cell: Vector2i) -> void:
	cell_pos = cell

# ==============================================================================
# Procedural Component Fallbacks (Headless & Programmatic Creation)
# ==============================================================================

## How big the nest is, as Config declares it -- bigger than anything the player builds,
## because it is what the whole map is pointed at.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size(art_key())
	return Vector3(2.0, 1.2, 2.0)

## Which nest it is drawn as: its own species' -- the map's guards' (VISUALS "nest/<species>",
## GAME-DESIGN 9.3: each species' nest is its own) -- or the mound, for one with none of its own.
func art_key() -> String:
	var cfg = _get_config()
	if cfg and cfg.has_method("map_data") and "VISUALS" in cfg:
		var key: String = "nest/" + String(cfg.map_data().get("guards", ""))
		if cfg.VISUALS.has(key):
			return key
	return "nest"

## (Re)builds the visible body and points `mesh_instance` at it. The entrance marker is
## left alone on purpose: it is not part of the nest's body, it is the mouth the raid
## comes out of, and the waves read its position.
func _ensure_body() -> void:
	var existing := find_child("Body", false, false)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var body: Node3D = VisualLibrary.make(art_key())
	add_child(body)
	mesh_instance = null
	for node in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node as MeshInstance3D
		break

func _ensure_components() -> void:
	# 1. CollisionShape3D (BoxShape3D 2x1.2x2 at (0, 0.6, 0))
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	var size: Vector3 = _declared_size()
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		add_child(collision_shape)

	# 2. The body, from the one place that knows what things look like. The collider is
	# built from the SAME declared size rather than measured off the art, because a
	# turret's reach is checked against the collider.
	_ensure_body()

	# 3. Entrance Marker (Blackbox cave mouth) -- only on the placeholder. The modelled
	# nest has its own burrow, and a black box stuck on the front of it was a second,
	# square mouth beside the real one.
	if VisualLibrary.has_art("nest"):
		return
	var has_entrance: bool = false
	for child in get_children():
		if child.name == "EntranceMarker":
			has_entrance = true
			break
	if not has_entrance:
		var entrance = MeshInstance3D.new()
		entrance.name = "EntranceMarker"
		var e_mesh = BoxMesh.new()
		e_mesh.size = Vector3(0.8, 0.6, 0.2)
		entrance.mesh = e_mesh
		entrance.position = Vector3(0.0, 0.3, 1.01)
		var e_mat = StandardMaterial3D.new()
		e_mat.albedo_color = Color(0.05, 0.05, 0.05)
		entrance.material_override = e_mat
		add_child(entrance)

# ==============================================================================
# Autoload Resolvers
# ==============================================================================

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
