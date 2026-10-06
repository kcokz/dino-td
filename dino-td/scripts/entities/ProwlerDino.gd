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
##
## A light that moves -- the torch he carries about as he works, burning down -- is the one light, wherever it is now
## and however far it reaches (light_now): at its edge it holds its ground while the edge stays near it
## (PROWL.edge_hold), and what it goes for is lit only with a margin (PROWL.lit_margin). Its way across a light, it
## goes round it, one way (_next_step_towards). The twitch watch caught it walking and standing by turns at his
## torch's edge, and milling at the fence it meant to bite through while his torch came and went over its place.

## Every one out, for NightProwl to count.
const GROUP: String = "prowlers"

## Where it came up out of the river: where it goes back to at first light.
var home: Vector3 = Vector3.INF
## Brought up by a wreck's din (Din), whatever the hour: out of its hours it goes back to the river once the
## man has been out of its reach PROWL.drawn_linger seconds.
var drawn: bool = false
var _drawn_idle: float = 0.0
## The light whose edge it keeps to as it was when it last thought -- {"at": Vector3, "radius": float, "by": the fire
## or the man whose light it is} (lights) -- or empty in the dark. Where it is now and how far it reaches are asked of
## what is burning (light_now).
var _wary: Dictionary = {}
## Whether it is inside that light further than it will stand, and backing out.
var _backing_out: bool = false
## Where round the light it keeps (radians, about the light's middle), INF until it has a place; how
## long before it paces on; which way round it goes; and whether it is on its way to that place, as against
## holding its ground near it (PROWL.edge_hold).
var _edge_angle: float = INF
var _edge_clock: float = 0.0
var _edge_way: float = 0.0
var _to_the_edge: bool = false
## Whether it is keeping PROWL.give_ground further out than where it waits: given ground to a light come onto it.
var _giving_ground: bool = false
## Seconds it has stood where it came to (PROWL.stand_at_least); and, on its way to its place, where it last got any
## further and how long since (PROWL.stalled_seconds).
var _stood_for: float = 0.0
var _going_from: Vector3 = Vector3.INF
var _going_for: float = 0.0
## The light as it was last frame -- where, and how far out it keeps from it -- (INF with none yet), and which way
## and how fast it has been moving on lately, metres a second, the man's steps to and fro evened out
## (PROWL.follow_seconds).
var _light_was: Vector3 = Vector3.INF
var _edge_was: float = 0.0
var _light_drift: Vector2 = Vector2.ZERO
## Whether it takes the light to be moving on: from when it is going faster than a walk is drawn from until it is going
## slower than standing is (ANIMATIONS.moving_speed, still_speed) -- the animator's own margin, so it does not take it
## to be moving on and not by turns as the man works three steps one way and three back.
var _light_moving_on: bool = false
## Whether the light moved this very frame faster than a walk is drawn from: a torch burning down moves every frame, a
## man stepping along a fence by fits and starts.
var _light_moving_now: bool = false
## A light lying across its way, which it is going round (_next_step_towards): "by" what is burning, "way" 1 round
## it the way the angle about its middle grows and -1 the other, "turned" once it has turned back for a way that was
## shut, "aim" its next place round it and where the light was ("at_light", "rim") when it chose that -- or empty.
var _round: Dictionary = {}
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

## The smell of meat on a rack (BaitRack) stops it to eat -- but not backing out of a light, nor turned at bay: held to
## eat deep in a fire's light as it backed out, it got no further out, took itself for cornered and turned at bay on a
## man shut in the cabin, swinging its head at him (the twitch watch, the bot's second night).
func eat_for(seconds: float, rack_at: Vector3) -> void:
	if at_bay_left > 0.0 or (_backing_out and not _wary.is_empty()):
		return
	super.eat_for(seconds, rack_at)

## A place to bite from that a fire lights is not one it stands at (lights): round the cabin it takes one in the dark --
## the player: "如果人晚上就躲在舱内，植龙在没有篝火cover下会撞击船舱，有篝火处植龙就不会靠近了". Where it would stand for
## it, that is: at the cabin, out from the wall by its snout (Dino._snout_out). Taken in the dark, it is kept until a
## light is on it by more than PROWL.lit_margin (_think).
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
		_escape = _way_out(inside["at"], _edge_of(inside))
		return
	super._think()
	var goal: Vector3 = _engage_spot() if (current_target != null and mode != Mode.MARCH) else _journey_goal()
	# Lit with a margin (PROWL.lit_margin): going for what it wants, it is lit only once a light is on it by more than the
	# margin; waiting at a light's edge for it, it is dark again only once it is out of every light. The places round the
	# cabin at the edge of the torch he carried about inside were lit and dark by turns, and it went from one to the
	# other at every thought.
	var margin: float = 0.0 if not _wary.is_empty() else -_prowl("lit_margin", 1.0)
	var lit: Dictionary = ProwlerDino.light_over(get_tree(), goal, margin)
	if not lit.is_empty() and mode != Mode.MARCH and assigned_slot != Vector3.ZERO and _is_building(current_target):
		# Its place at a building lit -- a fire made up since it took it, his torch come near: another round it in the
		# dark, if there is one (would_stand_at); with none, it waits at the light's edge.
		release_attack_slot(current_target, self)
		assigned_slot = claim_attack_slot(current_target, self)
		goal = _engage_spot()
		lit = ProwlerDino.light_over(get_tree(), goal, margin)
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
	# A new light, or none: a new place at its edge -- and so too backed out of one, where it got to. The same light,
	# wherever he has carried it and however far it reaches now (same_light), keeps it where it was round it: taken for
	# a new light at every thought as his torch burnt down, it took a new place a hand's breadth in each time, and
	# walked to it and stood, twice a second (the twitch watch: flicker).
	if light.is_empty() or was.is_empty() or not ProwlerDino.same_light(was, light) or (was_backing and not backing_out):
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
	# The light as it is now -- carried on, burning down -- or out since it last thought, and it is in the dark.
	var light: Dictionary = ProwlerDino.light_now(_wary)
	if light.is_empty():
		_keep_to({}, false)
		super._act(delta)
		return
	if mode == Mode.ATTACK:
		_set_mode(Mode.ENGAGE if current_target != null else Mode.MARCH)
	var centre: Vector3 = light["at"]
	var edge: float = _edge_of(light)
	if _backing_out:
		# Getting any further out? Cornered -- straight back the field's end, round the edge nothing it
		# can reach, or no further out for a while -- it turns at bay (the debug-agent's BUG-018: backed
		# into the field's corner by the torch it stood in the light at his feet, still, for seven seconds).
		var gap: float = _flat(global_position).distance_to(_flat(centre))
		if gap > _backing_best + 0.05:
			_backing_best = gap
			_backing_clock = 0.0
		elif held_left <= 0.0:
			# Held where it is -- knocked down, eating -- is not cornered: it is not trying to get out.
			_backing_clock += delta
		if _escape == Vector3.INF or _backing_clock >= _prowl("cornered_seconds", 1.2):
			_turn_at_bay()
			return
		_travel(_escape, delta, _prowl("back_out_pace", 1.3))
		return
	var from: Vector3 = global_position - centre
	# Near its place at the edge: in the dark, and no more than PROWL.edge_hold further out than where it would wait, here
	# (straight out from the light's middle through where it stands, out of every light: _in_the_dark). Near it, it holds
	# its ground -- for the man's steps about with his torch, for each hand's breadth it burns down -- and walks only to
	# pace along the edge, once the light is on it, or once the edge is further off: it walked to a new place at every
	# step he took at a bench by the door, and stood, and walked, twice a second (the twitch watch: flicker).
	var out_here := Vector3(from.x, 0.0, from.z)
	if out_here.length() < 0.01:
		out_here = Vector3(1.0, 0.0, 0.0)
	var lit: bool = not ProwlerDino.light_over(get_tree(), global_position).is_empty()
	var place_here: Vector3 = _in_the_dark(centre + out_here.normalized() * _keeping(edge))
	var near_it: bool = not lit and _flat(global_position).distance_to(_flat(place_here)) <= _prowl("edge_hold", 0.8)
	if _edge_angle == INF:
		# First to the nearest of the edge, before any pacing along it.
		_edge_angle = atan2(from.z, from.x)
		_edge_clock = _pause()
		_to_the_edge = true
		_giving_ground = false
		_light_was = Vector3.INF
		_light_drift = Vector2.ZERO
		_light_moving_on = false
	_watch_the_light(centre, edge, delta)
	# The light moving on -- burning down, carried off at a working man's pace, a step at a time, at it or away -- faster
	# than a walk is drawn from (ANIMATIONS.moving_speed): on its way to the edge, it keeps after it at its pace rather
	# than catching it up and standing. Caught up with by turns, it walked and stood by turns, a step for each of his and
	# for each hand's breadth the torch burnt down (the twitch watch: flicker).
	var moving_on: bool = _light_moving_on
	if not _to_the_edge:
		_stood_for += delta
		# Its wait is a wait where it stands (PROWL.pace_every), from where it has come to, however long the walk there:
		# counted from setting off, a long walk -- the light moving on meanwhile -- left a second's stand before the
		# next, and it walked the edge back and forth, six metres in six seconds and back where it began (the twitch
		# watch: mill); a walk back to the edge, the torch come at it, left none, and it walked on along it at once.
		_edge_clock -= delta
		if not near_it and (lit or _stood_for >= _prowl("stand_at_least", 2.0)):
			# The edge gone off it -- the torch come at it or carried off, burnt down: to the edge again, straight
			# out or in from where it stands; the light come onto it, it gives ground with room to spare
			# (PROWL.give_ground). Given back no more than to where it waits, a man stepping at it a step at a time had it
			# out of his light and in it again at every step, a walk and a stand for each (the twitch watch: flicker).
			# In the dark it stands a while first, wherever its place has gone (PROWL.stand_at_least).
			_edge_angle = atan2(from.z, from.x)
			_giving_ground = lit
			_to_the_edge = true
		elif _edge_clock <= 0.0:
			# On along the edge from where it stands, wherever the light has gone round it meanwhile.
			_edge_angle = atan2(from.z, from.x)
			var next: float = _next_edge_angle()
			_edge_clock = _pause()          # with nowhere along it to go, another wait where it is
			_to_the_edge = next != _edge_angle
			_edge_angle = next
	var spot: Vector3 = _in_the_dark(centre + Vector3(cos(_edge_angle), 0.0, sin(_edge_angle)) * _keeping(edge))
	spot.y = global_position.y
	# Caught up with it, it keeps after a light that is moving on and moving now; with one that is still -- the man
	# between one step and the next -- it holds its ground, and the next step is one it may let go by (edge_hold). Kept
	# after while it stood still, it was drawn standing and walking by turns at every step he took along the fence.
	var keep_after: bool = moving_on and _light_moving_now
	if _to_the_edge and (keep_after or _flat(global_position).distance_to(_flat(spot)) > _ai("spot_slack", 0.4)) \
			and not _stalled(delta):
		# Along the edge, a wary step; to it from further off, its own pace; after the light moving on, near it, the
		# light's pace -- no slower than a walk is drawn at.
		var pace: float = _prowl("wary_pace", 0.5) if near_it else 1.0
		if moving_on and near_it:
			pace = clampf(_light_drift.length() / maxf(0.1, speed), _walk_drawn_from() / maxf(0.1, speed), 1.0)
		_travel(spot, delta, pace)
		return
	# There, or near enough to hold its ground: facing into the light, at what it wants -- a fresh wait, come to it; the
	# meat, while it eats (Dino.eat_for).
	if _to_the_edge:
		_edge_clock = _pause()
		_stood_for = 0.0
	_to_the_edge = false
	_going_from = Vector3.INF
	var look: Vector3 = (current_target as Node3D).global_position \
		if (current_target is Node3D and is_instance_valid(current_target)) else centre
	if _eating_at != Vector3.INF:
		look = _eating_at
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
	var light: Dictionary = ProwlerDino.light_now(_wary) if not _wary.is_empty() else {}
	if light.is_empty():
		return false
	var c: Vector3 = light["at"]
	return _standable(_flat(_in_the_dark(c + Vector3(cos(angle), 0.0, sin(angle)) * _edge_of(light))))

## Whether `at` is ground it can stand on -- not the field's end, a wall, a hill: its own map has ground there, near
## enough (PROWL.way_out_slack).
func _standable(at: Vector2) -> bool:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return true
	var ground: Vector3 = maps.closest_point(Vector3(at.x, global_position.y, at.y), _map_kind())
	return _flat(ground).distance_to(at) <= _prowl("way_out_slack", 0.6)

## How the light it keeps to has moved since last frame -- its middle, and how far out from it the edge is -- into
## which way and how fast it has been moving on lately (_light_drift: over PROWL.follow_seconds, so a man stepping to
## and fro on the spot comes to nothing and one working his way along comes to his pace).
func _watch_the_light(centre: Vector3, edge: float, delta: float) -> void:
	if _light_was != Vector3.INF and delta > 0.0:
		var out := Vector2.from_angle(_edge_angle)
		var moved: Vector2 = (_flat(centre) - _flat(_light_was)) + out * (edge - _edge_was)
		_light_drift = _light_drift.lerp(moved / delta, clampf(delta / maxf(0.01, _prowl("follow_seconds", 2.0)), 0.0, 1.0))
		_light_moving_now = moved.length() / delta > _walk_drawn_from()
	_light_was = centre
	_edge_was = edge
	if _light_moving_on and _light_drift.length() < _anim("still_speed", 0.15):
		_light_moving_on = false
	elif not _light_moving_on and _light_drift.length() > _walk_drawn_from():
		_light_moving_on = true

## Whether, on its way to its place at the edge, it has got no further for PROWL.stalled_seconds -- its place inside a
## tree or a rock, the route there ending short of it: it is as near as it gets, and holds its ground there. Pressed on at
## it, it stood with its legs still going, and walked on again at the light's next move (the twitch watch: flicker).
func _stalled(delta: float) -> bool:
	var stalled: float = _prowl("stalled_seconds", 0.25)
	# Any further in that time than it would go at the pace it is drawn standing at (ANIMATIONS.still_speed) is getting on.
	if _going_from == Vector3.INF or _flat(global_position).distance_to(_flat(_going_from)) > _anim("still_speed", 0.15) * stalled:
		_going_from = global_position
		_going_for = 0.0
		return false
	_going_for += delta
	return _going_for >= stalled

## The pace a walk is drawn from (Config.ANIMATIONS.moving_speed): slower, it is drawn standing.
func _walk_drawn_from() -> float:
	return _anim("moving_speed", 0.35)

func _anim(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.ANIMATIONS.get(key, fallback)) if (cfg and "ANIMATIONS" in cfg) else fallback

## How far out from a light's middle it keeps, waiting `edge` out: as far, or PROWL.give_ground further, given ground.
func _keeping(edge: float) -> float:
	return edge + (_prowl("give_ground", 0.7) if _giving_ground else 0.0)

## How far out from a light's middle it waits: PROWL.edge_out outside its edge, in the dark.
func _edge_of(light: Dictionary) -> float:
	return float(light["radius"]) + _prowl("edge_out", 0.5)

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

## The next corner of its way -- round a light that lies across it, not through it. Going for the cabin past
## the torch, it would walk into the light, back out of it, and walk in again.
##
## Round it one way -- the shorter to where it is going, chosen once (_round) -- for as long as the light lies across
## its way: from place to place round its edge, each PROWL.round_step_degrees further round and kept till it is reached
## (DINO_AI.waypoint_reach) or the light has moved on, by the engine's route there and its steering round the others,
## as anywhere (_route_towards). It stepped round a fifth of a right angle at a time from where it stood, towards its
## way's next corner: with the way straight across the light's middle that was no step at all, and it stood at the edge
## as long as the way lay so, moving a hand's breadth whenever the torch did (the twitch watch, the bot's first nights:
## flicker, shake, fidget); and a place worked out afresh every frame fell on one side of a tower's foot and then the
## other, and it stepped back and forth between them. Not for a light it keeps to the edge of or is backing out of
## (_act); not at bay -- it goes at him, the light or no, and went round his torch's edge instead; not on its way home.
func _next_step_towards(goal: Vector3) -> Vector3:
	var step: Vector3 = super._next_step_towards(goal)
	if not is_inside_tree() or going_home or at_bay_left > 0.0 or not _wary.is_empty():
		_round = {}
		return step
	var here: Vector2 = _flat(global_position)
	for light in ProwlerDino.lights(get_tree()):
		var c: Vector2 = _flat(light["at"])
		var rim: float = _edge_of(light)
		if here.distance_to(c) < float(light["radius"]) - _prowl("flee_inside", 1.6):
			continue            # deep in it: backing out is its own business (_act)
		if not ProwlerDino.passes_within(here, _flat(step), c, rim - 0.1):
			continue            # its way passes clear of it
		if _round.is_empty() or not ProwlerDino.same_light(_round, light):
			var to_go: float = wrapf((_flat(goal) - c).angle() - (here - c).angle(), -PI, PI)
			_round = {"by": light.get("by"), "way": 1.0 if to_go >= 0.0 else -1.0, "turned": false}
		# Its place round it: kept till it gets there, or the light has moved on from where it was when it chose.
		var moved: bool = not _round.has("aim") or c.distance_to(_round["at_light"]) + absf(rim - float(_round["rim"])) \
			> _ai("waypoint_reach", 1.0)
		if moved or here.distance_to(_round["aim"]) <= _ai("waypoint_reach", 1.0):
			_round["aim"] = _next_round_place(here, c, rim)
			_round["at_light"] = c
			_round["rim"] = rim
			# And its way on asked afresh from here: the corner it had been making for, across the light, was behind it by
			# the time it was round, and it turned back for it into the light.
			_nav_goal = Vector3.INF
		_round["at"] = light["at"]
		_round["radius"] = light["radius"]
		return _route_towards(_round["aim"], step.y)
	if not _round.is_empty():
		_round = {}
		_nav_goal = Vector3.INF
	return step

## Its next place round a light round `c` whose edge it keeps `rim` out, the way it goes round (_round) -- on ground it
## can stand on and get to; that way shut (the field's end, a hill, a fence run on round it: no further round), the
## other way, once. Something standing in the way is no shut way: the route goes round it -- turned back for a tower's
## foot, it walked the light's edge one way and back again.
func _next_round_place(here: Vector2, c: Vector2, rim: float) -> Vector2:
	var way: float = float(_round["way"])
	var place: Vector2 = _ground_near(_out_of_the_light(_round_place(here, c, rim, way)))
	var shut: float = deg_to_rad(_prowl("round_shut_degrees", 3.0))
	if bool(_round["turned"]) or (_round_gain(c, here, place, way) >= shut and _gets_to(place)):
		return place
	var other: Vector2 = _ground_near(_out_of_the_light(_round_place(here, c, rim, -way)))
	if _round_gain(c, here, other, -way) >= shut and _gets_to(other):
		_round["way"] = -way
		_round["turned"] = true
		return other
	return place

## The place PROWL.round_step_degrees round a light round `c` from `here` the way `way` (1 the way the angle about its
## middle grows) -- or, further off than that, where its line from here touches the light -- far enough out that the way
## there does not cut into its edge (`rim`).
func _round_place(here: Vector2, c: Vector2, rim: float, way: float) -> Vector2:
	var step: float = deg_to_rad(_prowl("round_step_degrees", 40.0))
	var out: float = rim / cos(step * 0.5)
	var gap: float = here.distance_to(c)
	var by: float = maxf(step, acos(clampf(out / maxf(gap, 0.001), -1.0, 1.0)))
	return c + Vector2.from_angle((here - c).angle() + way * by) * out

## `at` out of every light (_in_the_dark): going round one light, its places round it are not in another -- his torch
## by the campfire.
func _out_of_the_light(at: Vector2) -> Vector2:
	return _flat(_in_the_dark(Vector3(at.x, global_position.y, at.y)))

## How far round a light round `c` the way `way` (radians) `to` is from `from`.
static func _round_gain(c: Vector2, from: Vector2, to: Vector2, way: float) -> float:
	return wrapf((to - c).angle() - (from - c).angle(), -PI, PI) * way

## The ground it can stand on nearest `at` (its own map), or `at` with no map to ask.
func _ground_near(at: Vector2) -> Vector2:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return at
	return _flat(maps.closest_point(Vector3(at.x, global_position.y, at.y), _map_kind()))

## Whether it can get to `at` from where it stands (can_stand_at).
func _gets_to(at: Vector2) -> bool:
	return can_stand_at(Vector3(at.x, global_position.y, at.y))

## The next corner of the way to `aim`, its place round a light (_next_step_towards): the engine's route there, round
## whatever is built between -- straight at it, the steering held it still at a tower's foot that stood in the way, a
## second and more -- or `aim` itself, with no map to ask.
func _route_towards(aim: Vector2, y: float) -> Vector3:
	var to := Vector3(aim.x, y, aim.y)
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return to
	var near: float = _ai("path_desired_distance", 0.5)
	for corner in maps.path(global_position, to, _map_kind()):
		if _flat(corner).distance_to(_flat(global_position)) > near:
			return Vector3(corner.x, y, corner.z)
	return to

## Whether the way from `from` to `to` passes within `reach` of `c`.
static func passes_within(from: Vector2, to: Vector2, c: Vector2, reach: float) -> bool:
	var seg: Vector2 = to - from
	var t: float = clampf((c - from).dot(seg) / maxf(0.0001, seg.length_squared()), 0.0, 1.0)
	return (from + seg * t).distance_to(c) < reach

## Whether it is keeping to a light's edge now.
func is_wary() -> bool:
	return not _wary.is_empty() and not going_home

## What a report says of it (Dino.debug_state; the twitch watch, the bug report), and of the lights: the one whose edge
## it keeps to as it is now -- where round it it keeps, whether it is on its way there or holding its ground, whether
## backing out -- the one it is going round and which way, and how long it is still at bay. The reports from the bot's
## first nights said where it was going and not that a torch stood between.
func debug_state() -> Dictionary:
	var out: Dictionary = super.debug_state()
	var light: Dictionary = ProwlerDino.light_now(_wary) if not _wary.is_empty() else {}
	out["light"] = null if light.is_empty() else {"at": _xz(light["at"]), "radius": snappedf(float(light["radius"]), 0.01),
		"edge_angle": snappedf(rad_to_deg(_edge_angle), 0.1) if _edge_angle != INF else null, "to_the_edge": _to_the_edge,
		"backing_out": _backing_out}
	out["round"] = null if _round.is_empty() else {"at": _xz(_round["at"]), "way": int(_round["way"]), "turned": bool(_round["turned"])}
	out["at_bay"] = snappedf(at_bay_left, 0.01)
	return out

## Every light it will not come into: each fire burning (Fire, its light_radius), and the torch in the
## Hero's hand (Hero.torch_light) -- {"at": Vector3, "radius": float, "by": the fire, or him}. The cabin's dim
## windows are not among them.
static func lights(tree: SceneTree) -> Array:
	var out: Array = []
	if tree == null:
		return out
	for f in tree.get_nodes_in_group(Fire.GROUP):
		if f is Node3D and is_instance_valid(f) and f.has_method("light_radius"):
			var r: float = float(f.light_radius())
			if r > 0.0:
				out.append({"at": (f as Node3D).global_position, "radius": r, "by": f})
	# A fire pot's burning ground (FirePatch): a fire like any other.
	for p in tree.get_nodes_in_group(FirePatch.GROUP):
		if p is Node3D and is_instance_valid(p) and p.has_method("light_radius"):
			var pr: float = float(p.light_radius())
			if pr > 0.0:
				out.append({"at": (p as Node3D).global_position, "radius": pr, "by": p})
	var hero = tree.get_first_node_in_group("hero")
	if hero is Node3D and is_instance_valid(hero) and hero.has_method("torch_light"):
		var t: float = float(hero.torch_light())
		if t > 0.0:
			out.append({"at": (hero as Node3D).global_position, "radius": t, "by": hero})
	return out

## `light` (one of lights()) as it is now -- where its fire burns or the man has carried it, how far it reaches -- or
## empty once it is out or gone. One with nothing named for it (`by`), as it was.
static func light_now(light: Dictionary) -> Dictionary:
	var by = light.get("by")
	if by == null:
		return light
	if not is_instance_valid(by) or not (by is Node3D):
		return {}
	var reach: float = float(by.torch_light()) if by.has_method("torch_light") else float(by.light_radius())
	if reach <= 0.0:
		return {}
	return {"at": (by as Node3D).global_position, "radius": reach, "by": by}

## Whether two of lights() are the one light: the same fire, the same man's torch, however far it reaches now and
## wherever he has carried it. Ones with nothing named for them (`by`) are the one light where they are the same.
static func same_light(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var by_a = a.get("by")
	var by_b = b.get("by")
	if by_a != null or by_b != null:
		return is_same(by_a, by_b)
	return (a["at"] as Vector3).distance_to(b["at"]) < 0.01 and absf(float(a["radius"]) - float(b["radius"])) < 0.01

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
	_round = {}
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
