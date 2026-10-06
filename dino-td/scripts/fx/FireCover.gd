# res://scripts/fx/FireCover.gd
class_name FireCover
extends Node3D

## WHAT THE FIRES COVER, while a fire is being put down or one is picked (the player, 2026-10-05: "campfire控制的区域可以
## 用蓝色显示出来，包括cover的建筑"): every fire's ground in the reach's blue -- each fire's own ring (Fire's reach at
## night), and the one in hand the ghost's (Main) -- and outlined in it, each building whose every place to be bitten
## from lies in a fire's light: a prowler will not stand in a light to bite (ProwlerDino.would_stand_at; the player:
## "如果人晚上就躲在舱内，植龙在没有篝火cover下会撞击船舱，有篝火处植龙就不会靠近了"), so what is lit all round is out of
## its reach at night. Shown only then: by night the light itself is seen, and a ring always on is a marker on the
## world (GAME-DESIGN 9.3).

## The fire in hand, if one is being put down: where it would stand, and how far it would light.
var _ghost_at: Variant = null
var _ghost_reach: float = 0.0
## Whether a fire is the one picked.
var _picked_fire: bool = false
## The outlines drawn now, one a building covered.
var _marks: Array[Node3D] = []

func _ready() -> void:
	name = "FireCover"
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("unit_selected") and not eb.unit_selected.is_connected(_on_unit_selected):
			eb.unit_selected.connect(_on_unit_selected)
		if eb.has_signal("unit_deselected") and not eb.unit_deselected.is_connected(_on_unit_deselected):
			eb.unit_deselected.connect(_on_unit_deselected)

## A fire in hand at `at` (on the ground where the ghost stands), lighting `reach` metres at night -- or, `at` null,
## none any more.
func placing(at: Variant, reach: float = 0.0) -> void:
	_ghost_at = at if at is Vector3 else null
	_ghost_reach = reach
	for f in _fires():
		f.set_range_visible(_ghost_at != null or _picked_fire)
	_refresh()

## Whether it shows now: a fire being put down, or one picked.
func showing() -> bool:
	return _picked_fire or _ghost_at != null

## The buildings outlined now, as covered.
func covered() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m in _marks:
		if is_instance_valid(m) and m.has_meta(&"covers"):
			var b = m.get_meta(&"covers")
			if b is Node3D and is_instance_valid(b):
				out.append(b)
	return out

func _on_unit_selected(unit: Node) -> void:
	_picked_fire = unit is Fire
	_refresh()

func _on_unit_deselected() -> void:
	_picked_fire = false
	_refresh()

func _fires() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		if f is Fire and is_instance_valid(f) and not bool(f.is_destroyed):
			out.append(f)
	return out

## Every fire's light as it will be at night -- [{at, radius}] -- the one in hand among them.
func night_lights() -> Array:
	var out: Array = []
	for f in _fires():
		var r: float = float(f.night_reach())
		if r > 0.0:
			out.append({"at": (f as Node3D).global_position, "radius": r})
	if _ghost_at is Vector3 and _ghost_reach > 0.0:
		out.append({"at": _ghost_at, "radius": _ghost_reach})
	return out

## Whether `building` is covered by `lights`: every place it would be bitten from (Dino.ring_round, the places a raid
## takes round it to bite: Config.DINO_STANDOFF_INNER out from its faces) inside one of them.
static func covers(lights: Array, building: Node3D, cfg: Node) -> bool:
	if lights.is_empty() or building == null or cfg == null:
		return false
	var half: Vector2 = cfg.get_building_half(String(building.get("building_type")))
	var spacing: float = float(cfg.DINO_AI.get("slot_spacing", 1.0)) if "DINO_AI" in cfg else 1.0
	for offset in Dino.ring_round(half, float(cfg.DINO_STANDOFF_INNER), spacing):
		var spot: Vector3 = building.global_position + offset
		var lit: bool = false
		for light in lights:
			var at: Vector3 = light["at"]
			if Vector2(spot.x - at.x, spot.z - at.z).length() < float(light["radius"]):
				lit = true
				break
		if not lit:
			return false
	return true

## The outlines drawn again: none, or one round each building the fires (and the one in hand) cover -- what a raid
## bites, not the fires themselves nor what is walked over.
func _refresh() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()
	if not showing() or not is_inside_tree():
		return
	var cfg: Node = get_node_or_null("/root/Config")
	if cfg == null:
		return
	var lights: Array = night_lights()
	var fb: Dictionary = cfg.FEEDBACK if "FEEDBACK" in cfg else {}
	var blue: Color = fb.get("reach_color", Color(0.35, 0.65, 1.0))
	var tint := Color(blue.r, blue.g, blue.b, float(fb.get("cover_outline_alpha", 0.85)))
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Node3D) or not is_instance_valid(b) or b is Fire or bool(b.get("is_destroyed")):
			continue
		var row: Dictionary = cfg.BUILDINGS.get(String(b.get("building_type")), {})
		if row.is_empty() or bool(row.get("walk_over", false)):
			continue
		if not FireCover.covers(lights, b, cfg):
			continue
		var ring := SelectionRing3D.new()
		ring.name = "Covered"
		ring.set_meta(&"covers", b)
		add_child(ring)
		ring.override_color(tint)
		var half: Vector2 = cfg.get_building_half(String(b.get("building_type")))
		ring.configure(SelectionRing3D.Shape.BOX, half.x * 2.0, half.y * 2.0)
		ring.global_position = (b as Node3D).global_position
		ring.rotation.y = (b as Node3D).global_rotation.y
		ring.set_shown(true)
		_marks.append(ring)
