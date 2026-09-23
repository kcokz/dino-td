# res://scripts/fx/Herds.gd
class_name Herds
extends Node3D

## Plant-eaters grazing on the lower valley walls: sauropods, hadrosaurs, a few
## triceratops and stegosaurs (Quaternius, CC0; tools/convert_quaternius.py).
##
## The raid is what the player fights; these are what makes the valley a place where
## dinosaurs LIVE rather than a stage they walk onto. So they are scenery and nothing
## else: no collider, no group, not on the grid, nowhere a turret or a raid can see, and
## outside the field where nobody walks.
##
## They amble. Each grazes a while on its idle clip, turns, walks a few metres on its walk
## clip, and grazes again -- all done with Tweens bound to the animal, so there is no
## steering here at all, and when an animal goes its tween goes with it (a tween owned by
## anything else calls back into a freed node; see Fx.gd).

var _cfg: Node = null
var _rng := RandomNumberGenerator.new()
var _ground_noise: FastNoiseLite = null

static func build(cfg: Node) -> Herds:
	var herds := Herds.new()
	herds.name = "Herds"
	herds._cfg = cfg
	return herds

func _ready() -> void:
	if _cfg == null or not ("HERDS" in _cfg):
		return
	_rng.seed = int(_cfg.HERDS.get("seed", 1))
	for spec in _cfg.HERDS.get("herds", []):
		_place_herd(spec)

## Where the herd grazes: `bearing` on the camera rig's compass, like the volcanoes, and
## `distance` metres out from the middle of the valley.
static func centre_of(spec: Dictionary) -> Vector3:
	var bearing: float = deg_to_rad(float(spec.get("bearing", 0.0)))
	return Vector3(-sin(bearing), 0.0, -cos(bearing)) * float(spec.get("distance", 36.0))

func _place_herd(spec: Dictionary) -> void:
	var path: String = String(spec.get("scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if not (packed is PackedScene):
		return
	var centre: Vector3 = centre_of(spec)
	var spread: float = float(spec.get("spread", 5.0))
	for i in range(int(spec.get("count", 1))):
		var animal := Node3D.new()
		animal.name = "%s_%d" % [String(spec.get("species", "animal")), i]
		add_child(animal)
		var art: Node3D = (packed as PackedScene).instantiate()
		animal.add_child(art)
		# Sized by LENGTH, on one scale for the whole valley: the in-game T-Rex is the ruler,
		# and a sauropod is twice its length whatever its pose makes its height.
		var bounds: AABB = VisualLibrary.visual_bounds(art)
		if bounds.size.z > 0.001:
			VisualLibrary.place(art, float(spec.get("length", 2.5)) / bounds.size.z, "feet")
		var home := centre + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * spread
		home.y = _ground(home)
		animal.position = home
		animal.rotation.y = _rng.randf_range(0.0, TAU)
		var player := _player_of(art)
		if player == null:
			continue
		for clip in ["idle", "walk"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.play("idle")
		# Not all in step: a herd that breathes in unison reads as one animal copied.
		player.seek(_rng.randf_range(0.0, player.get_animation("idle").length), true)
		_amble(animal, player, home, float(spec.get("speed", 0.5)))

## One graze and one short walk, then the next -- chained through the tween's own
## callback, on a tween bound to the animal.
func _amble(animal: Node3D, player: AnimationPlayer, home: Vector3, speed: float) -> void:
	if not is_instance_valid(animal) or not is_instance_valid(player):
		return
	var graze: Vector2 = _cfg.HERDS.get("graze_time", Vector2(5.0, 12.0))
	var radius: float = float(_cfg.HERDS.get("wander_radius", 3.0))
	var angle: float = _rng.randf_range(0.0, TAU)
	var target: Vector3 = home + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(0.35, 1.0) * radius
	target.y = _ground(target)
	var walk_time: float = animal.position.distance_to(target) / maxf(0.05, speed)
	var tw := animal.create_tween()
	tw.tween_interval(_rng.randf_range(graze.x, graze.y))
	tw.tween_callback(func():
		var ahead := Vector3(target.x, animal.position.y, target.z)
		if animal.position.distance_to(ahead) > 0.05:
			animal.look_at(ahead, Vector3.UP)
		player.play("walk", 0.3))
	tw.tween_property(animal, "position", target, walk_time)
	tw.tween_callback(func():
		player.play("idle", 0.3)
		_amble(animal, player, home, speed))

func _player_of(art: Node) -> AnimationPlayer:
	var found: Array = art.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null

## The ground as drawn, wobble and all (TerrainBuilder.ground_noise).
func _ground(at: Vector3) -> float:
	var t: Dictionary = _cfg.TERRAIN if "TERRAIN" in _cfg else {}
	if _ground_noise == null:
		_ground_noise = TerrainBuilder.ground_noise(_cfg)
	return TerrainBuilder.ground_height(at.x, at.z, float(t.get("field_half", 22.0)),
		float(t.get("outskirts_half", 110.0)), t, _ground_noise)
