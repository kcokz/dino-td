# res://scripts/entities/ProwlerDino.gd
class_name ProwlerDino
extends "res://scripts/entities/Dino.gd"

## What hunts by night and fears fire (GAME-DESIGN 9.3; v0.6 round four, the player: "不用火把，晚上更多的
## 夜行动物袭击（怕火把但是不怕暗淡灯光的船舱）"): the phytosaur, up out of the river in the dark (Config.DINOS,
## behaviour "prowl"; NightProwl sends them).
##
## In the dark it comes straight for the Hero when he is near (PROWL.hunts_within) and otherwise for the
## cabin -- whose dim windows it does not mind -- biting what is in its way, as any raider does. Him shut in the
## cabin, it goes at the cabin (Dino._is_target_valid: the lit room it does not come into), from a side no fire
## lights (would_stand_at) -- a campfire by the cabin keeps it off as far as its light goes. But it
## will not come into a fire's light, nor the light of the torch in his hand (lights): what it wants in
## one it waits for just outside the light's edge, in the dark (PROWL.edge_out) -- what sees only by firelight
## does not see it there, a tower at night -- facing in, and paces along the edge a few steps at a time, its
## eyes catching the light (the eye-shine): they are what is seen of it. Found
## deeper in, as the torch comes at it, it backs out to the edge -- the nearest part of it it can reach,
## round the light where straight back is the field's end or a wall -- and with nowhere left to go it
## turns at bay on the one who cornered it for a while (PROWL.at_bay_seconds), then tries again. At
## first light it goes back to the river it came up from (go_home).

## Every one out, for NightProwl to count.
const GROUP: String = "prowlers"

## Where it came up out of the river: where it goes back to at first light.
var home: Vector3 = Vector3.INF
## Brought up by a wreck's din (Din), whatever the hour: out of its hours it goes back to the river once the
## man has been out of its reach PROWL.drawn_linger seconds.
var drawn: bool = false
var _drawn_idle: float = 0.0
## The light whose edge it keeps to, {"at": Vector3, "radius": float}, or empty in the dark.
var _wary: Dictionary = {}
## Whether it is inside that light further than it will stand, and backing out.
var _backing_out: bool = false
## Where round the light it keeps (radians, about the light's middle), INF until it has a place; how
## long before it paces on; which way round it goes.
var _edge_angle: float = INF
var _edge_clock: float = 0.0
var _edge_way: float = 0.0
## Where it backs out to (_way_out), INF with nowhere to go; the furthest out from the light's middle it
## has got while backing out, and how long since it got any further; how long it is still at bay.
var _escape: Vector3 = Vector3.INF
var _backing_best: float = 0.0
var _backing_clock: float = 0.0
var at_bay_left: float = 0.0
## Its eyes' own material, lit when a light is near (the eye-shine), and how bright they are now; and
## the glint of each, what is seen of them from the game's camera (_glint).
var _eyes: Array[StandardMaterial3D] = []
var eye_shine: float = 0.0
var _glint_mat: StandardMaterial3D = null
var glints: Array[MeshInstance3D] = []

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	if home == Vector3.INF:
		home = global_position

## Its body (re)built -- as it is each time its species is set in the tree (Dino.setup) -- its eyes are
## found again on the new one: found once, on a body since thrown away, they shone where nobody saw.
func _ensure_body() -> void:
	super._ensure_body()
	_find_the_eyes()

func _physics_process(delta: float) -> void:
	at_bay_left = maxf(0.0, at_bay_left - delta)
	super._physics_process(delta)
	_shine()

# ==============================================================================
# What it wants
# ==============================================================================

## The Hero when he is near and in the dark -- or, at bay, in his light as he is; else whatever is in its
## way, and the cabin at its road's end.
func _preferred_target() -> Node:
	var hero := _hero_within(hero_interest_range())
	if hero != null and (at_bay_left > 0.0 or ProwlerDino.light_over(get_tree(), (hero as Node3D).global_position).is_empty()):
		return hero
	return _nearest_building_within(building_interest_range())

func hero_interest_range() -> float:
	return _prowl("hunts_within", 8.0)

## The man in the dark is what it is out for ("没火的人是植龙的首要目标"): above any building -- the cabin it may have
## set out for among them. His equal, he was never taken over it (Dino._outranks): two stood at a campfire's edge
## staring in at the cabin while he quarried four metres off in the dark, and the fire looked like enough to keep
## the night off (the player's bug report, 2026-10-01: "篝火范围不知道是不是有点大，我在旁边采石头，植龙就看着，
## 也不来进攻"). Lit, he is as any raider ranks him.
func _rank(node: Node) -> int:
	if node != null and is_instance_valid(node) and node.is_in_group("hero") and is_inside_tree() \
			and ProwlerDino.light_over(get_tree(), (node as Node3D).global_position).is_empty():
		return 3
	return super._rank(node)

## Struck by him, it turns on him (_turn_at_bay: PROWL.at_bay_seconds), the light or no -- a crocodile struck
## snaps back -- and then backs out to the dark again: the light keeps it from coming in, not from striking back
## (the player's bug report, 2026-10-01: "这时候我进攻恐龙它们都不会还手？似乎有点不合理"). Hurt by a trap, it
## does not know who did it.
func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if is_dead or going_home or not is_inside_tree() or at_bay_left > 0.0:
		return
	var hero: Node = get_tree().get_first_node_in_group("hero")
	if hero != null and is_instance_valid(hero) and hero.get("target_enemy") == self:
		_turn_at_bay()

func building_interest_range() -> float:
	return 2.0

## A place to bite from that a fire lights is not one it stands at (lights): round the cabin it takes one in the dark --
## the player: "如果人晚上就躲在舱内，植龙在没有篝火cover下会撞击船舱，有篝火处植龙就不会靠近了". Where it would stand for
## it, that is: at the cabin, out from the wall by its snout (Dino._snout_out).
func would_stand_at(spot: Vector3, building: Node = null) -> bool:
	var at: Vector3 = _snout_out(building, spot) if _is_hollow(building) else spot
	if is_inside_tree() and not ProwlerDino.light_over(get_tree(), at).is_empty():
		return false
	return super.would_stand_at(spot, building)

# ==============================================================================
# Keeping out of the light
# ==============================================================================

## Thinks as any raider does, and then asks whether a light is in the way: it is inside one further
## than it will stand (backing out), or what it is going for is in one (keeping to its edge).
func _think() -> void:
	if going_home:
		super._think()
		return
	if drawn and not _its_hours():
		if _hero_within(hero_interest_range()) != null:
			_drawn_idle = 0.0
		else:
			_drawn_idle += _ai("think_seconds", 0.25)
			if _drawn_idle >= _prowl("drawn_linger", 20.0):
				go_home(home)
				return
	if at_bay_left > 0.0:
		# At bay: no light holds it back.
		_keep_to({}, false)
		super._think()
		return
	var inside: Dictionary = ProwlerDino.light_over(get_tree(), global_position, -_prowl("flee_inside", 1.6))
	if not inside.is_empty():
		_keep_to(inside, true)
		_escape = _way_out(inside["at"], float(inside["radius"]) + _prowl("edge_out", 0.5))
		return
	super._think()
	var goal: Vector3 = _engage_spot() if (current_target != null and mode != Mode.MARCH) else _journey_goal()
	var lit: Dictionary = ProwlerDino.light_over(get_tree(), goal)
	if not lit.is_empty() and mode != Mode.MARCH and assigned_slot != Vector3.ZERO and _is_building(current_target):
		# Its place at a building lit -- a fire made up since it took it: another round it in the dark, if there is
		# one (would_stand_at); with none, it waits at the light's edge.
		release_attack_slot(current_target, self)
		assigned_slot = claim_attack_slot(current_target, self)
		goal = _engage_spot()
		lit = ProwlerDino.light_over(get_tree(), goal)
	if lit.is_empty():
		_keep_to({}, false)
	else:
		_keep_to(lit, false)

func _keep_to(light: Dictionary, backing_out: bool) -> void:
	var was: Dictionary = _wary
	var was_backing: bool = _backing_out and not was.is_empty()
	_wary = light
	# A light in the way ends a lunge: it keeps out of it (Config.DINO_AI.bursts).
	if not light.is_empty():
		_drop_burst()
	_backing_out = backing_out
	if backing_out and not was_backing:
		_backing_best = _flat(global_position).distance_to(_flat(light["at"]))
		_backing_clock = 0.0
	# A new light, or none: a new place at its edge. The same light moving -- the torch coming on -- keeps
	# it where it was round it, so it gives ground straight back rather than stepping aside.
	if light.is_empty() or was.is_empty() or float(was["radius"]) != float(light["radius"]) \
			or (was["at"] as Vector3).distance_to(light["at"]) > float(light["radius"]):
		_edge_angle = INF
	# Out of the light's reach again: a fresh window for its headway -- it was not failing to get
	# anywhere while it waited at the edge.
	if light.is_empty() and not was.is_empty():
		_headway_clock = 0.0
		_headway_from = global_position

## It lunges only in the dark or at bay -- never keeping to a light's edge or backing out of it, which would
## have it backing out of a torch at a lunge's pace (Config.DINO_AI.bursts).
func _may_burst() -> bool:
	return _wary.is_empty() and super._may_burst()

func _burst_pace() -> float:
	return 1.0 if not _wary.is_empty() else super._burst_pace()

## In the dark, as any raider; at a light, keeping to its edge or backing out to it.
func _act(delta: float) -> void:
	if going_home or _wary.is_empty():
		super._act(delta)
		return
	if mode == Mode.ATTACK:
		_set_mode(Mode.ENGAGE if current_target != null else Mode.MARCH)
	var centre: Vector3 = _wary["at"]
	var edge: float = float(_wary["radius"]) + _prowl("edge_out", 0.5)
	if _backing_out:
		# Getting any further out? Cornered -- straight back the field's end, round the edge nothing it
		# can reach, or no further out for a while -- it turns at bay (the debug-agent's BUG-018: backed
		# into the field's corner by the torch it stood in the light at his feet, still, for seven seconds).
		var gap: float = _flat(global_position).distance_to(_flat(centre))
		if gap > _backing_best + 0.05:
			_backing_best = gap
			_backing_clock = 0.0
		else:
			_backing_clock += delta
		if _escape == Vector3.INF or _backing_clock >= _prowl("cornered_seconds", 1.2):
			_turn_at_bay()
			return
		_travel(_escape, delta, _prowl("back_out_pace", 1.3))
		return
	var from: Vector3 = global_position - centre
	if _edge_angle == INF:
		# First to the nearest of the edge, before any pacing along it.
		_edge_angle = atan2(from.z, from.x)
		_edge_clock = _pause()
	_edge_clock -= delta
	var spot: Vector3 = _in_the_dark(centre + Vector3(cos(_edge_angle), 0.0, sin(_edge_angle)) * edge)
	var at_the_edge: bool = absf(_flat(global_position).distance_to(_flat(centre)) - _flat(spot).distance_to(_flat(centre))) <= 1.0
	if _edge_clock <= 0.0 and at_the_edge:
		_edge_angle = _next_edge_angle()
		_edge_clock = _pause()
		spot = _in_the_dark(centre + Vector3(cos(_edge_angle), 0.0, sin(_edge_angle)) * edge)
	spot.y = global_position.y
	if _flat(global_position).distance_to(_flat(spot)) > _ai("spot_slack", 0.4):
		# Along the edge, a wary step; to it from further off, its own pace.
		_travel(spot, delta, _prowl("wary_pace", 0.5) if at_the_edge else 1.0)
	else:
		# There: facing into the light, at what it wants.
		var look: Vector3 = (current_target as Node3D).global_position \
			if (current_target is Node3D and is_instance_valid(current_target)) else centre
		_drive(Vector3.ZERO, delta, look, true)

## Where to back out of a light round `centre` to, `edge` metres out: straight out from its middle if it
## can stand there, else the nearest part of the edge it can -- round it, where straight back is the
## field's end, a wall, a hill -- and can get to (NavMaps). INF with none: cornered.
func _way_out(centre: Vector3, edge: float) -> Vector3:
	var maps := _nav_maps()
	var from: Vector3 = global_position - centre
	var a0: float = atan2(from.z, from.x)
	var steps: int = maxi(4, int(_prowl("way_out_tries", 12.0)))
	var tried: int = 0
	for k in steps:
		# Straight out first, then a step either side, and so on round.
		var turn: float = TAU / float(steps) * float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)
		var spot: Vector3 = _in_the_dark(centre + Vector3(cos(a0 + turn), 0.0, sin(a0 + turn)) * edge)
		spot.y = global_position.y
		if maps == null or not maps.is_ready():
			return spot
		var ground: Vector3 = maps.closest_point(spot, _map_kind())
		if _flat(ground).distance_to(_flat(spot)) > _prowl("way_out_slack", 0.6):
			continue            # the field's end, a wall, a hill: nowhere to stand
		tried += 1
		if maps.is_reachable(global_position, ground, _map_kind()):
			return Vector3(ground.x, spot.y, ground.z)
		if tried >= 3:
			break
	return Vector3.INF

## Cornered: it goes for the one who cornered it, the light or no, for PROWL.at_bay_seconds -- then backs
## out again if it still can.
func _turn_at_bay() -> void:
	at_bay_left = _prowl("at_bay_seconds", 3.0)
	_backing_clock = 0.0
	_keep_to({}, false)
	# At him, whatever it was going for: turned on him, it would otherwise keep to the cabin it had
	# (no swapping for its equal, Dino._outranks) and bite that at his feet.
	var hero := _hero_within(hero_interest_range())
	if hero != null:
		_take(hero, Mode.ENGAGE)
	_alert()
	_think_clock = 0.0

## A step round the light from where it keeps (PROWL.pace_step_degrees), the way it has been going,
## and now and then the other way.
##
## Never to a place it cannot stand -- inside the cabin, a wall, a hill -- which it walked at and back
## from along the edge, eight metres in six seconds by the cabin's end (the debug-agent's TASK-022):
## it turns the other way, and with neither way open it stays.
func _next_edge_angle() -> float:
	if _edge_way == 0.0:
		_edge_way = 1.0 if _dice().randf() < 0.5 else -1.0
	elif _dice().randf() < _prowl("turn_back_chance", 0.3):
		_edge_way = -_edge_way
	var step: float = deg_to_rad(_prowl("pace_step_degrees", 25.0))
	for way in [_edge_way, -_edge_way]:
		var angle: float = _edge_angle + step * way
		if _can_stand_on_the_edge(angle):
			_edge_way = way
			return angle
	return _edge_angle

## Whether the edge of the light it keeps to, round at `angle`, is ground it can stand on.
func _can_stand_on_the_edge(angle: float) -> bool:
	if _wary.is_empty():
		return false
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return true
	var edge: float = float(_wary["radius"]) + _prowl("edge_out", 0.5)
	var spot: Vector3 = _in_the_dark((_wary["at"] as Vector3) + Vector3(cos(angle), 0.0, sin(angle)) * edge)
	var ground: Vector3 = maps.closest_point(spot, _map_kind())
	return _flat(ground).distance_to(_flat(spot)) <= _prowl("way_out_slack", 0.6)

## `spot` out of every light it is in: pushed straight out from each one's middle to its edge and PROWL.edge_out more,
## a few times over, for lights that overlap -- his torch by the campfire. Where it waits is in the dark.
func _in_the_dark(spot: Vector3) -> Vector3:
	if not is_inside_tree():
		return spot
	var out: float = _prowl("edge_out", 0.5)
	for i in 3:
		var lit: Dictionary = ProwlerDino.light_over(get_tree(), spot, out - 0.01)
		if lit.is_empty():
			break
		var at: Vector3 = lit["at"]
		var from := Vector3(spot.x - at.x, 0.0, spot.z - at.z)
		if from.length() < 0.01:
			from = Vector3(1.0, 0.0, 0.0)
		var y: float = spot.y
		spot = at + from.normalized() * (float(lit["radius"]) + out)
		spot.y = y
	return spot

## Seconds it waits where it is before pacing on (PROWL.pace_every, between the two).
func _pause() -> float:
	var every: Array = _prowl_list("pace_every", [3.0, 5.0])
	return _dice().randf_range(float(every[0]), float(every[1]))

## The next corner of its way -- round a light that stands across it, not through it: along the light's
## edge, a little way round towards where it is going at a time. Going for the cabin past the torch, it
## would walk into the light, back out of it, and walk in again.
func _next_step_towards(goal: Vector3) -> Vector3:
	var step: Vector3 = super._next_step_towards(goal)
	if not is_inside_tree() or going_home:
		return step
	var here: Vector2 = _flat(global_position)
	var to: Vector2 = _flat(step)
	for light in ProwlerDino.lights(get_tree()):
		var c: Vector2 = _flat(light["at"])
		var rim: float = float(light["radius"]) + _prowl("edge_out", 0.5)
		var from_c: float = here.distance_to(c)
		if from_c < rim - 0.3:
			continue            # inside it: backing out is its own business (_act)
		var seg: Vector2 = to - here
		var t: float = clampf((c - here).dot(seg) / maxf(0.0001, seg.length_squared()), 0.0, 1.0)
		if (here + seg * t).distance_to(c) >= rim - 0.1:
			continue            # its way passes clear of it
		var a_here: float = (here - c).angle()
		var turn: float = clampf(wrapf((to - c).angle() - a_here, -PI, PI), -0.35, 0.35)
		var round_it: Vector2 = c + Vector2.from_angle(a_here + turn) * maxf(rim, from_c)
		return Vector3(round_it.x, step.y, round_it.y)
	return step

## Whether it is keeping to a light's edge now.
func is_wary() -> bool:
	return not _wary.is_empty() and not going_home

## Every light it will not come into: each fire burning (Fire, its light_radius), and the torch in the
## Hero's hand (Hero.torch_light) -- {"at": Vector3, "radius": float}. The cabin's dim windows are not
## among them.
static func lights(tree: SceneTree) -> Array:
	var out: Array = []
	if tree == null:
		return out
	for f in tree.get_nodes_in_group(Fire.GROUP):
		if f is Node3D and is_instance_valid(f) and f.has_method("light_radius"):
			var r: float = float(f.light_radius())
			if r > 0.0:
				out.append({"at": (f as Node3D).global_position, "radius": r})
	# A fire pot's burning ground (FirePatch): a fire like any other.
	for p in tree.get_nodes_in_group(FirePatch.GROUP):
		if p is Node3D and is_instance_valid(p) and p.has_method("light_radius"):
			var pr: float = float(p.light_radius())
			if pr > 0.0:
				out.append({"at": (p as Node3D).global_position, "radius": pr})
	var hero = tree.get_first_node_in_group("hero")
	if hero is Node3D and is_instance_valid(hero) and hero.has_method("torch_light"):
		var t: float = float(hero.torch_light())
		if t > 0.0:
			out.append({"at": (hero as Node3D).global_position, "radius": t})
	return out

## The light `point` is in -- within its radius and `margin` more (less, for a margin below nought) --
## the nearest to its middle of them if more than one, or empty.
static func light_over(tree: SceneTree, point: Vector3, margin: float = 0.0) -> Dictionary:
	var best: Dictionary = {}
	var best_gap: float = INF
	for light in lights(tree):
		var at: Vector3 = light["at"]
		var gap: float = Vector2(point.x - at.x, point.z - at.z).length()
		if gap < float(light["radius"]) + margin and gap < best_gap:
			best_gap = gap
			best = light
	return best

# ==============================================================================
# Going home
# ==============================================================================

## Whether it is its hours (Config.DINOS.<id>.hours): the phytosaur's are the night's.
func _its_hours() -> bool:
	var gs = get_node_or_null("/root/GameState")
	var cfg = _get_config()
	if gs == null or cfg == null or not gs.has_method("day_part"):
		return true
	return bool(cfg.keeps_hours(dino_type, String(gs.day_part())))

## Its hours over: back to the river it came up from, whatever it is told (the raids' manager says the
## nest).
func go_home(_nest: Vector3) -> void:
	_wary = {}
	super.go_home(home if home != Vector3.INF else _nest)

# ==============================================================================
# The eye-shine (GAME-DESIGN 9.3: "火光照到的黑暗边上能看见眼睛反光——鳄类的眼睛夜里真的会反光")
# ==============================================================================

## Its eyes' material ("Eye", tools/dino_body.py), made its own so they shine alone. The ones
## made for a body since thrown away are kept, not let go: a body is rebuilt in the frame it was built
## (Dino.setup, as it is sent), and let go, their material was freed while the renderer still drew the
## old body with it ("material is null").
func _find_the_eyes() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := m as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for i in mesh_node.mesh.get_surface_count():
			var mat: Material = mesh_node.get_active_material(i)
			if mat == null or not String(mat.resource_name).begins_with("Eye"):
				continue
			var own: StandardMaterial3D = (mat.duplicate() as StandardMaterial3D) if mat is StandardMaterial3D else StandardMaterial3D.new()
			own.emission_enabled = true
			own.emission = _prowl_color("eye_color", Color(1.0, 0.45, 0.15))
			own.emission_energy_multiplier = 0.0
			mesh_node.set_surface_override_material(i, own)
			_eyes.append(own)
			_make_glints(mesh_node, i)

## A glint over each eye (PROWL.glint_size across, the eye's colour, brighter than white where it is
## brightest so it glows): the eyes themselves are a few centimetres, a pixel or two from the game's
## camera and lost at twelve metres (the debug-agent's TASK-021). Each follows the head, over the eye's
## middle, drawn over the head it sits in, and faces the camera; how bright is the eye-shine's (_shine).
## How much of the shine comes back to where the light is, by how far it is looking that way (`toward`: 1
## straight at it, 0 side on, -1 away): all of it looking at it, PROWL.eye_side side on, none looking away.
func _looking_at_it(toward: float) -> float:
	var side: float = _prowl("eye_side", 0.6)
	if toward >= 0.0:
		return lerpf(side, 1.0, smoothstep(0.0, 0.6, toward))
	return lerpf(side, 0.0, smoothstep(0.0, 0.35, -toward))

func _make_glints(mesh_node: MeshInstance3D, surface: int) -> void:
	for g in glints:
		if is_instance_valid(g):
			g.queue_free()
	glints.clear()
	var skeleton: Skeleton3D = mesh_node.get_parent() as Skeleton3D
	if skeleton == null or not is_inside_tree():
		return
	var head: int = skeleton.find_bone(String(_prowl_text("eye_bone", "Head")))
	if head < 0:
		return
	var verts: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var mid: Vector3 = Vector3.ZERO
	for v in verts:
		mid += v
	mid /= float(verts.size())
	var sides: Array = [Vector3.ZERO, Vector3.ZERO]
	var counts: Array = [0, 0]
	for v in verts:
		var k: int = 0 if v.x < mid.x else 1
		sides[k] += v
		counts[k] += 1
	# From the mesh's space to the head bone's: the skin's own bind pose for it, which is what moves the
	# eyes -- the bone's rest put the glints at its hips.
	var to_bone: Transform3D = skeleton.get_bone_global_rest(head).affine_inverse()
	var skin: Skin = mesh_node.skin
	if skin != null:
		for b in skin.get_bind_count():
			var named: String = String(skin.get_bind_name(b))
			if named == skeleton.get_bone_name(head) or (named == "" and skin.get_bind_bone(b) == head):
				to_bone = skin.get_bind_pose(b)
				break
	var hold := BoneAttachment3D.new()
	hold.name = "EyeGlints"
	hold.bone_name = skeleton.get_bone_name(head)
	skeleton.add_child(hold)
	if _glint_mat == null:
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glint_mat.billboard_keep_scale = true
		_glint_mat.no_depth_test = true
		_glint_mat.albedo_texture = Fire._soft_disc()
		_glint_mat.disable_receive_shadows = true
	var across: float = _prowl("glint_size", 0.3) / maxf(0.0001, skeleton.global_transform.basis.get_scale().x)
	for k in 2:
		if counts[k] == 0:
			continue
		var quad := QuadMesh.new()
		quad.size = Vector2(across, across)
		var g := MeshInstance3D.new()
		g.name = "Glint%d" % k
		g.mesh = quad
		g.material_override = _glint_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.position = to_bone * (sides[k] / float(counts[k]))
		hold.add_child(g)
		glints.append(g)

## How bright its eyes are. A light is what an eye shines back, and the shine is seen in the dark at the
## light's edge: full there and out to where it waits (PROWL.edge_out), dimming over PROWL.eye_reach metres
## further out, dark with no light near. In the light itself, past eye_lit_from, it fades over eye_lit_over metres: lit, it is
## seen, eyes and all -- at his feet in his torchlight its eyes burned full, two lamps (v0.6 round six, the
## player: "植龙晚上进攻眼睛还是像灯泡"). And the shine goes back the way the light came: looking at the
## light, full; side on, less (eye_side); looking away, none.
func _shine() -> void:
	var best: float = 0.0
	if is_inside_tree() and not is_dead:
		var reach: float = maxf(0.1, _prowl("eye_reach", 3.0))
		var waits: float = _prowl("edge_out", 0.5)
		var lit_from: float = _prowl("eye_lit_from", 1.0)
		var lit_over: float = maxf(0.1, _prowl("eye_lit_over", 1.5))
		var ahead: Vector3 = -global_transform.basis.z
		var looking := Vector2(ahead.x, ahead.z).normalized()
		for light in ProwlerDino.lights(get_tree()):
			var at: Vector3 = light["at"]
			var to_light := Vector2(at.x - global_position.x, at.z - global_position.z)
			var gap: float = to_light.length() - float(light["radius"])
			var edge: float = clampf(1.0 - maxf(0.0, gap - waits) / reach, 0.0, 1.0) if gap >= 0.0 \
				else clampf(1.0 - (-gap - lit_from) / lit_over, 0.0, 1.0)
			var toward: float = looking.dot(to_light.normalized()) if to_light.length() > 0.01 else 1.0
			best = maxf(best, edge * _looking_at_it(toward))
	eye_shine = best
	for mat in _eyes:
		mat.emission_energy_multiplier = best * _prowl("eye_energy", 4.0)
	if _glint_mat != null:
		var c: Color = _prowl_color("eye_color", Color(1.0, 0.45, 0.15))
		var e: float = _prowl("glint_energy", 2.5)
		_glint_mat.albedo_color = Color(c.r * e, c.g * e, c.b * e, best)
	# As big as the camera is far (PROWL.glint_per_metre): two small points up close, where the eyes are
	# seen -- one glint as big as its head was a lamp, not eyes -- and still a point at the game's
	# distance (the debug-agent's TASK-022).
	var cam: Camera3D = get_viewport().get_camera_3d() if (is_inside_tree() and not glints.is_empty()) else null
	var k: float = 1.0
	if cam != null and is_instance_valid(glints[0]):
		var far: float = cam.global_position.distance_to(glints[0].global_position)
		var across: float = clampf(far * _prowl("glint_per_metre", 0.008), _prowl("glint_least", 0.04), _prowl("glint_size", 0.3))
		k = across / maxf(0.001, _prowl("glint_size", 0.3))
	for g in glints:
		if is_instance_valid(g):
			g.visible = best > 0.01
			g.scale = Vector3.ONE * k

# ==============================================================================
# Its numbers (Config.PROWL)
# ==============================================================================

func _prowl(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.PROWL.get(key, fallback)) if (cfg and "PROWL" in cfg) else fallback

func _prowl_list(key: String, fallback: Array) -> Array:
	var cfg = _get_config()
	return cfg.PROWL.get(key, fallback) if (cfg and "PROWL" in cfg) else fallback

func _prowl_text(key: String, fallback: String) -> String:
	var cfg = _get_config()
	return String(cfg.PROWL.get(key, fallback)) if (cfg and "PROWL" in cfg) else fallback

func _prowl_color(key: String, fallback: Color) -> Color:
	var cfg = _get_config()
	return cfg.PROWL.get(key, fallback) if (cfg and "PROWL" in cfg) else fallback
