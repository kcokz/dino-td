# res://scripts/entities/Hero.gd
class_name Hero
extends CharacterBody3D

## Modern Person / Hero Entity for Defend Dinosaur v0.1.
## Avatar representing the time-traveler constructor.
## Moves in real-time, approaches blueprints to construct them,
## can attack nest guards/nest in DEPLOY phase, takes damage, and triggers Game Over on death.

enum State {
	IDLE = 0,
	MOVING = 1,
	BUILDING = 2,
	ATTACKING = 3,
	DEAD = 4,
	HARVESTING = 5,
	EATING = 6,
}

# ==============================================================================
# Configuration & Properties
# ==============================================================================
@export var max_hp: float = 10.0
## His own hit points, without a meal's boost: Config.HERO.hp and his armour's (Config.kit).
## max_hp is this and whatever the meal he is living on adds (GameState.max_hp_bonus).
var base_max_hp: float = 10.0
@export var current_hp: float = 10.0
@export var speed: float = 4.0
@export var damage: float = 1.0
@export var attack_rate: float = 1.0
@export var attack_range: float = 2.0
@export var build_range: float = 1.5

var current_state: State = State.IDLE:
	set(v):
		if current_state != v:
			# Anything else he is told to do puts the meal down, uneaten (order_eat).
			if current_state == State.EATING:
				_put_the_meal_down()
			current_state = v
			if animator != null and is_instance_valid(animator):
				animator.play_state(current_state)

var animator: ActorAnimator = null
var target_destination: Vector3 = Vector3.ZERO
var target_building: Node = null
var target_enemy: Node3D = null
var target_resource_node: Node = null
var attack_cooldown: float = 0.0
var harvest_timer: float = 0.0
var repair_timer: float = 0.0

var current_path: Array[Vector3] = []
var current_path_index: int = 0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var status_bar: Node3D = null
var selection_ring: Node3D = null
var is_hero: bool = true
var continuous_mode: bool = false
## His place in the dinosaurs' steering: an avoidance agent on the world's map, where theirs are,
## told where he is and how he is moving every frame, so they steer round him rather than walking
## into him and standing there (v0.6 round two). Above them in priority
## (HERO.avoidance_priority): they give way, he goes where he is sent.
var _agent: RID = RID()
var has_provoked_dinos: bool = false
var provoke_timer: float = 0.0

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init() -> void:
	_load_config()

func _ready() -> void:
	add_to_group("hero")
	add_to_group("players")
	add_to_group("selectable")
	_ensure_components()
	_ensure_feedback_nodes(2.0, true)
	var ring_w: float = 0.8
	var cfg_ring = _get_config()
	if cfg_ring and "HERO" in cfg_ring:
		ring_w = float(cfg_ring.HERO.get("width", 0.8))
	_configure_selection_ring(ring_w)
	# Without this the bar keeps whatever state it was built in and shows at full
	# health, which is exactly what it is supposed to stay out of the way for.
	_refresh_health_bar()
	_connect_feedback_events()
	# What he says as he goes (HeroVoice).
	if find_child("Voice", false, false) == null:
		var voice := HeroVoice.new()
		voice.name = "Voice"
		voice.hero = self
		add_child(voice)
	_load_config()
	_connect_event_bus()

func _load_config() -> void:
	var cfg = _get_config()
	if cfg:
		if "HERO" in cfg and cfg.HERO is Dictionary:
			base_max_hp = float(cfg.HERO.get("hp", 10.0))
			max_hp = base_max_hp
			current_hp = max_hp
			speed = float(cfg.HERO.get("move_speed", 4.0))
			damage = float(cfg.HERO.get("damage", 1.0))
			attack_rate = float(cfg.HERO.get("attack_rate", 1.0))
			attack_range = float(cfg.HERO.get("attack_range", 2.0))
		if "TIME" in cfg and cfg.TIME is Dictionary:
			build_range = float(cfg.TIME.get("build_range", 1.5))
	_apply_kit()
	current_hp = max_hp

## His row (Config.kit, GAME-DESIGN 9.3): armour's hit points over his own, boots' stride, a
## weapon's blows, on Config.HERO's and for good -- only the best of each slot. Worked out again
## whenever he makes something; `grow` gives him the new armour whole, as a meal's hit points are.
func _apply_kit(grow: bool = false) -> void:
	var cfg = _get_config()
	if cfg == null or not ("HERO" in cfg) or not cfg.has_method("kit_bonus"):
		return
	var gs = _get_game_state()
	var owned: Dictionary = gs.unlocks if (gs and "unlocks" in gs) else {}
	base_max_hp = float(cfg.HERO.get("hp", 10.0)) + float(cfg.kit_bonus(owned, "max_hp"))
	speed = float(cfg.HERO.get("move_speed", 4.0)) * float(cfg.kit_bonus(owned, "move_speed"))
	damage = float(cfg.HERO.get("damage", 1.0)) * float(cfg.kit_bonus(owned, "damage"))
	var was: float = max_hp
	max_hp = base_max_hp + (float(gs.max_hp_bonus()) if (gs and gs.has_method("max_hp_bonus")) else 0.0)
	if grow and max_hp > was and current_state != State.DEAD:
		current_hp += max_hp - was
	current_hp = minf(current_hp, max_hp)

func _on_unlock_granted(_unlock_id: String) -> void:
	var was: float = max_hp
	_apply_kit(true)
	if not is_equal_approx(was, max_hp):
		_refresh_health_bar()
		var eb = _get_event_bus()
		if eb and eb.has_signal("hero_hp_changed"):
			eb.hero_hp_changed.emit(current_hp, max_hp)

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("phase_changed"):
		if not eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.connect(_on_phase_changed)
	if eb and eb.has_signal("meal_eaten"):
		if not eb.meal_eaten.is_connected(_on_meal_eaten):
			eb.meal_eaten.connect(_on_meal_eaten)
	if eb and eb.has_signal("fed_changed"):
		if not eb.fed_changed.is_connected(_on_fed_changed):
			eb.fed_changed.connect(_on_fed_changed)
	if eb and eb.has_signal("unlock_granted"):
		if not eb.unlock_granted.is_connected(_on_unlock_granted):
			eb.unlock_granted.connect(_on_unlock_granted)

func _exit_tree() -> void:
	if _agent.is_valid():
		NavigationServer3D.free_rid(_agent)
		_agent = RID()
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("phase_changed"):
		if eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.disconnect(_on_phase_changed)
	if eb and is_instance_valid(eb) and eb.has_signal("meal_eaten"):
		if eb.meal_eaten.is_connected(_on_meal_eaten):
			eb.meal_eaten.disconnect(_on_meal_eaten)
	if eb and is_instance_valid(eb) and eb.has_signal("fed_changed"):
		if eb.fed_changed.is_connected(_on_fed_changed):
			eb.fed_changed.disconnect(_on_fed_changed)
	if eb and is_instance_valid(eb) and eb.has_signal("unlock_granted"):
		if eb.unlock_granted.is_connected(_on_unlock_granted):
			eb.unlock_granted.disconnect(_on_unlock_granted)

# ==============================================================================
# State Machine & Movement
# ==============================================================================

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if provoke_timer > 0.0:
		provoke_timer -= delta
		if provoke_timer <= 0.0:
			has_provoked_dinos = false

	# Sweeping the ground happens whatever the Hero is otherwise doing, and before
	# the state machine: walking past a pile while on the way to a build site
	# should still pick it up.
	sweep_for_drops()

	if not continuous_mode and _get_current_phase() != 0: # Only restricted during legacy DEPLOY phase
		return

	var was_at: Vector3 = global_position
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.BUILDING:
			_process_building(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.HARVESTING:
			_process_harvesting(delta)
		State.EATING:
			_process_eating(delta)
	_report_pace(was_at, delta)

## Tells the animator how far he really went this frame, so a walk is shown only while he
## is walking (ActorAnimator.update_motion).
func _report_pace(was_at: Vector3, delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := global_position - was_at
	moved.y = 0.0
	_tell_the_steering(moved / delta)
	if animator == null or not is_instance_valid(animator):
		return
	animator.update_motion(moved.length() / delta, delta)

## Where he is and how he is going, for the dinosaurs' steering (see _agent).
func _tell_the_steering(moving: Vector3) -> void:
	if not _agent.is_valid():
		if not is_inside_tree() or get_world_3d() == null:
			return
		_agent = NavigationServer3D.agent_create()
		NavigationServer3D.agent_set_map(_agent, get_world_3d().navigation_map)
		NavigationServer3D.agent_set_avoidance_enabled(_agent, true)
		var cfg = _get_config()
		NavigationServer3D.agent_set_radius(_agent, float(cfg.HERO.get("width", 0.8)) * 0.5 if cfg else 0.4)
		NavigationServer3D.agent_set_avoidance_priority(_agent,
			float(cfg.HERO.get("avoidance_priority", 1.0)) if cfg else 1.0)
		NavigationServer3D.agent_set_max_speed(_agent, maxf(0.1, walk_speed()))
	NavigationServer3D.agent_set_position(_agent, global_position)
	NavigationServer3D.agent_set_velocity(_agent, moving)

# ==============================================================================
# Carrying things home
# ==============================================================================

## Picks up every drop within reach. Collection is automatic on purpose: making
## the player click each pile would only move the clicking around, and the point
## of routing resources through the Hero is that he has to *be there*, not that
## he has to be told.
##
## Returns how many units were banked, which is what the tests measure.
func sweep_for_drops() -> int:
	if not is_inside_tree() or current_state == State.DEAD:
		return 0
	var radius: float = _pickup_radius()
	if radius <= 0.0:
		return 0
	var banked: int = 0
	for d in get_tree().get_nodes_in_group("drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion() or not (d is Node3D):
			continue
		if "is_collected" in d and d.is_collected:
			continue
		if not d.has_method("collect"):
			continue
		if global_position.distance_to((d as Node3D).global_position) <= radius:
			banked += int(d.collect(self))
	return banked

func _pickup_radius() -> float:
	var cfg = _get_config()
	if cfg and "DROPS" in cfg:
		return float(cfg.DROPS.get("pickup_radius", 1.6))
	return 1.6

func _process_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Check for nearby guard dinos or enemies to auto-engage
	if target_enemy == null or not _is_enemy_valid(target_enemy):
		target_enemy = _find_nearest_enemy(attack_range)
		if target_enemy != null:
			current_state = State.ATTACKING

func _check_and_transition_interaction_target(extra_buffer: float, collider: Node = null) -> bool:
	if target_building != null:
		if not is_instance_valid(target_building) or ("is_destroyed" in target_building and target_building.is_destroyed):
			target_building = null
			_continue_to_next_pending_building_or_idle()
			return true
		if (collider != null and collider == target_building) or _is_in_build_range(global_position, target_building, extra_buffer):
			velocity = Vector3.ZERO
			current_state = State.BUILDING
			return true

	elif target_resource_node != null:
		if not is_instance_valid(target_resource_node) or ("is_depleted" in target_resource_node and target_resource_node.is_depleted):
			target_resource_node = null
			current_state = State.IDLE
			return true
		# At his arm's length exactly: the slack is for staying at the work once he has
		# started (_process_harvesting), not for starting it -- with it he began chopping
		# a stride short of the tree.
		if (collider != null and collider == target_resource_node) or _is_in_node_range(global_position, target_resource_node):
			velocity = Vector3.ZERO
			current_state = State.HARVESTING
			harvest_timer = 0.0
			return true

	return false

func _replan_current_target_path() -> void:
	if target_building != null and is_instance_valid(target_building):
		_plan_path_to_building(target_building)
	elif target_resource_node != null and is_instance_valid(target_resource_node):
		_plan_path_to_node(target_resource_node)
	elif target_enemy != null and _is_enemy_valid(target_enemy):
		_plan_path(target_enemy.global_position)
	else:
		_plan_path(target_destination)

func _process_moving(delta: float) -> void:
	# 1. Target interaction check
	if _check_and_transition_interaction_target(0.4):
		return

	# 2. Target enemy check
	elif target_enemy != null:
		if not _is_enemy_valid(target_enemy):
			target_enemy = null
			current_state = State.IDLE
			return
		var dist_to_e = global_position.distance_to(target_enemy.global_position)
		if dist_to_e <= attack_range:
			velocity = Vector3.ZERO
			current_state = State.ATTACKING
			return

	# 3. Ensure path is not empty
	if current_path.is_empty():
		current_path = [target_destination]
		current_path_index = 0

	# Advance waypoints if close enough
	while current_path_index < current_path.size():
		var wp = current_path[current_path_index]
		var d_wp = Vector2(global_position.x - wp.x, global_position.z - wp.z).length()
		var threshold = 0.15 if current_path_index == current_path.size() - 1 else 0.3
		if d_wp <= threshold:
			current_path_index += 1
		else:
			break

	# Check if all waypoints reached
	if current_path_index >= current_path.size():
		velocity = Vector3.ZERO
		if _check_and_transition_interaction_target(0.4):
			return
		# A plain walk ends where it was going -- there is nothing to get in range of. It used to
		# be planned again from where he stood, a route a hand long whose ends were both already
		# reached, every frame: he stood "walking" for ever, and the idle watch that has him hit
		# back at whatever bites him never came round (found playing, v0.6 round three).
		if target_building == null and target_resource_node == null and target_enemy == null:
			current_state = State.IDLE
			return
		_replan_current_target_path()
		if current_path_index >= current_path.size():
			current_state = State.IDLE
		return

	# Move toward current waypoint
	var target_pt = current_path[current_path_index]
	var diff = target_pt - global_position
	diff.y = 0.0

	var dir = diff.normalized()
	velocity = dir * walk_speed()
	if dir.length_squared() > 0.001:
		look_at(global_position + dir, Vector3.UP)

	var motion = velocity * delta
	if is_inside_tree() and get_world_3d() != null:
		var col = move_and_collide(motion)
		if col != null:
			if _check_and_transition_interaction_target(0.2, col.get_collider()):
				return
			# Slide along the obstacle surface
			var slide_normal = col.get_normal()
			slide_normal.y = 0.0
			if slide_normal.length_squared() > 0.001:
				slide_normal = slide_normal.normalized()
				var remainder = col.get_remainder()
				var slide_motion = remainder.slide(slide_normal)
				move_and_collide(slide_motion)
	else:
		global_position += motion

	# 4. Stuck detection & auto-recovery
	var moved_dist = global_position.distance_to(_last_pos)
	if moved_dist < (walk_speed() * delta * 0.2):
		_stuck_timer += delta
		if _stuck_timer >= 0.4:
			_stuck_timer = 0.0
			if _check_and_transition_interaction_target(0.2):
				return
			# Replanning cannot help a man standing INSIDE something solid: the route is
			# fine, the physics is what is refusing. Push him out first.
			if _push_out_of_anything_solid():
				return
			if _abandon_unreachable_building():
				return
			_replan_current_target_path()
	else:
		_stuck_timer = 0.0
	_last_pos = global_position

## Shoves the Hero clear of any finished building he is standing inside, and reports
## whether he had to be.
##
## THE LAST LINE OF DEFENCE, and it exists because the first line failed in the field: a
## stake built on top of him left him walking on the spot at full speed, for ever, with
## a perfectly good path in hand. move_and_collide cannot resolve a body that is already
## overlapping, and no amount of replanning is going to change that.
##
## A building does not go solid round somebody standing in it (Building.add_build_progress), so
## this should never fire. It stays because "should never" is what the last one was too, and
## being nudged a few centimetres is a great deal better than being retired from the game.
func _push_out_of_anything_solid() -> bool:
	var gm = _get_grid_manager()
	if gm == null or not gm.has_method("get_all_buildings"):
		return false
	var cfg = _get_config()
	var half_me: float = float(cfg.HERO.get("width", 0.8)) * 0.5 if cfg else 0.4

	for b in gm.get_all_buildings():
		if b == null or not is_instance_valid(b) or not (b is Node3D):
			continue
		if "is_constructed" in b and not b.is_constructed:
			continue          # a blueprint is not solid and never traps anyone
		if "is_destroyed" in b and b.is_destroyed:
			continue
		if cfg and "building_type" in b and cfg.has_method("is_hollow") and cfg.is_hollow(String(b.building_type)):
			continue          # the cabin: its inside is his, and its walls are bodies of their own
		var half_it: float = 0.5
		if cfg and "building_type" in b:
			half_it = float(cfg.get_building_footprint(String(b.building_type))) * 0.5
		var away: Vector3 = global_position - (b as Node3D).global_position
		away.y = 0.0
		var gap: float = away.length()
		var clearance: float = half_me + half_it
		# Clear of its walls is clear of it: out along a diagonal a square reaches further
		# than half its width, and inside the cabin's corners the circle said "clear".
		if cfg and cfg.has_method("gap_to_building") and "building_type" in b:
			if float(cfg.gap_to_building(global_position, String(b.building_type), (b as Node3D).global_position)) >= half_me:
				continue
			if gap > 0.0001:
				clearance = float(cfg.building_extent_along(String(b.building_type), away / gap)) + half_me
		elif gap >= clearance:
			continue
		# Straight out along the shortest way, plus a hair so it does not re-trigger.
		# The gap is measured BEFORE picking a fallback direction: reading it afterwards
		# gave the length of the fallback instead, which made the push negative and shoved
		# him further in.
		if gap < 0.01:
			away = Vector3(1.0, 0.0, 0.0)
			gap = 0.0
		global_position += away.normalized() * (clearance - gap + 0.05)
		return true
	return false

func _process_building(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_building == null or not is_instance_valid(target_building) or target_building.is_destroyed:
		target_building = null
		_continue_to_next_pending_building_or_idle()
		return

	if not _is_in_build_range(global_position, target_building, 0.5):
		_plan_path_to_building(target_building)
		current_state = State.MOVING
		return

	# Standing in what he is raising -- it was ordered where he stood (v0.6 round three): a step
	# out of it first, or it could never be finished (a building does not go solid round a body,
	# Building.add_build_progress).
	if "is_constructed" in target_building and not target_building.is_constructed and _inside_of(target_building):
		_step_out_of(target_building, delta)
		return

	# Face the building
	var diff = target_building.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	# Building and mending are the same verb -- he walks over and works on it with
	# a hammer. Which one happens is the building's business, not the order's: an
	# unfinished thing gets raised, a damaged one gets patched. A good meal speeds
	# both, because they are the same work.
	var work: float = delta * work_rate()
	# And it is heard: a knock every so often while he is at it (Config.SOUNDS.hammer_every).
	_hammer_clock += delta
	var every: float = _sound_number("hammer_every", 0.55)
	if _hammer_clock >= every:
		_hammer_clock -= every
		_sound_at("hammer", (target_building as Node3D).global_position)
	if "is_constructed" in target_building and target_building.is_constructed:
		# An upgrade under way comes before any patching: it is new work, and paid for.
		if target_building.has_method("is_upgrading") and target_building.is_upgrading():
			if target_building.add_upgrade_progress(work):
				target_building = null
				_continue_to_next_pending_building_or_idle()
			return
		_work_on_repair(work)
		return
	if target_building.has_method("add_build_progress"):
		var completed = target_building.add_build_progress(work)
		if completed:
			target_building = null
			_continue_to_next_pending_building_or_idle()
	else:
		_continue_to_next_pending_building_or_idle()

## Whether his body is in `b`'s cells.
func _inside_of(b: Node) -> bool:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("gap_to_building") or not ("building_type" in b):
		return false
	var half_me: float = float(cfg.HERO.get("width", 0.8)) * 0.5
	return float(cfg.gap_to_building(global_position, String(b.building_type), (b as Node3D).global_position)) < half_me

## A step out of `b` at his walking pace, across the nearest of its edges that is open: in the
## middle of a row of fence, the sections either side may already be up, and straight out along
## the row is into one of them.
func _step_out_of(b: Node, delta: float) -> void:
	var cfg = _get_config()
	var half_it: Vector2 = cfg.get_building_half(String(b.building_type))
	var half_me: float = float(cfg.HERO.get("width", 0.8)) * 0.5
	var off: Vector3 = global_position - (b as Node3D).global_position
	var ways: Array = []
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var half_along: float = half_it.x if absf(dir.x) > 0.5 else half_it.y
		ways.append([half_along + half_me - off.dot(dir), dir])
	ways.sort_custom(func(a, c): return a[0] < c[0])
	var out: Vector3 = ways[0][1]
	for way in ways:
		if not test_move(global_transform, way[1] * float(way[0])):
			out = way[1]
			break
	velocity = out * walk_speed()
	look_at(global_position + out, Vector3.UP)
	move_and_collide(velocity * delta)

## Mending: he stands there for as long as the job is worth, and the bill is paid
## when the work is done. Walking away costs the time spent and nothing else --
## there is never a half-paid building to explain.
func _work_on_repair(delta: float) -> void:
	if not target_building.has_method("needs_repair") or not target_building.needs_repair():
		target_building = null
		repair_timer = 0.0
		_continue_to_next_pending_building_or_idle()
		return
	repair_timer += delta
	var needed: float = float(target_building.repair_seconds()) if target_building.has_method("repair_seconds") else 1.0
	if repair_timer < needed:
		return
	repair_timer = 0.0
	if target_building.has_method("finish_repair"):
		target_building.finish_repair()
	target_building = null
	_continue_to_next_pending_building_or_idle()

func _process_attacking(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_enemy == null or not _is_enemy_valid(target_enemy):
		target_enemy = null
		# The next one in reach, if the pack is still on him; then back to the work he left.
		if not _resume_work.is_empty():
			var next_one: Node3D = _find_nearest_enemy(attack_range + 0.3)
			if next_one != null:
				target_enemy = next_one
				return
			if _take_up_work_again():
				return
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > (attack_range + 0.5):
		current_state = State.MOVING
		return

	# Face enemy
	var diff = target_enemy.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	attack_cooldown -= delta
	if attack_cooldown <= 0.0:
		attack_cooldown = attack_rate
		has_provoked_dinos = true
		var p_dur: float = 5.0
		var cfg = _get_config()
		if cfg and "HERO" in cfg:
			p_dur = float(cfg.HERO.get("provoke_duration", 5.0))
		provoke_timer = p_dur
		if target_enemy.has_method("take_damage"):
			_sound_at("strike", target_enemy.global_position + Vector3(0.0, 0.6, 0.0))
			target_enemy.take_damage(damage)

func _process_harvesting(delta: float) -> void:
	velocity = Vector3.ZERO
	if target_resource_node == null or not is_instance_valid(target_resource_node):
		target_resource_node = null
		current_state = State.IDLE
		return

	if "is_depleted" in target_resource_node and target_resource_node.is_depleted:
		target_resource_node = null
		current_state = State.IDLE
		return

	if not _is_in_node_range(global_position, target_resource_node, 0.4):
		_plan_path_to_node(target_resource_node)
		current_state = State.MOVING
		return

	# Face the node
	var diff = target_resource_node.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		look_at(global_position + diff.normalized(), Vector3.UP)

	harvest_timer += delta
	var rate: float = 1.0
	if "harvest_rate" in target_resource_node:
		rate = float(target_resource_node.harvest_rate)
	var interval = 1.0 / maxf(rate, 0.1)

	while harvest_timer >= interval:
		harvest_timer -= interval
		if target_resource_node == null or not is_instance_valid(target_resource_node):
			break
		var res_type: String = target_resource_node.resource_type if "resource_type" in target_resource_node else "wood"
		# His tools make every stroke count for more, and the pile says so when he picks
		# it up: the axe he made is felt, and seen, each time he uses it (GAME-DESIGN 4.6).
		var stroke: int = _stroke_yield(res_type)
		# Each stroke is heard as what it strikes: an axe in wood, a pick on stone (SOUNDS.harvest).
		var cfg_s = _get_config()
		if cfg_s and "SOUNDS" in cfg_s and cfg_s.SOUNDS.get("harvest", {}).has(res_type):
			_sound_at(String(cfg_s.SOUNDS["harvest"][res_type]), (target_resource_node as Node3D).global_position)
		var yielded: int = target_resource_node.harvest(stroke) if (stroke > 0 and target_resource_node.has_method("harvest")) else 0
		if yielded > 0:
			# Even what the Hero digs up himself lands on the ground first. He is
			# standing on it, so his own sweep takes it a frame later and it feels
			# the same as banking it -- but there is now exactly one way resources
			# get into the warehouse, instead of one rule for hands and another
			# for machines.
			var pile: DropItem = DropItem.spawn(self, global_position, res_type, yielded)
			if pile != null:
				pile.note = _stroke_note(res_type)

		if "is_depleted" in target_resource_node and target_resource_node.is_depleted:
			target_resource_node = null
			current_state = State.IDLE
			break

## What one stroke brings in: one unit, times his tools (GameState.harvest_multiplier).
## A factor that is not whole carries over from stroke to stroke, so x1.5 comes in as
## 1, 2, 1, 2 -- the rhythm of the work stays the same and the piles get bigger.
var _stroke_carry: float = 0.0

func _stroke_yield(res_id: String) -> int:
	var gs = _get_game_state()
	var factor: float = float(gs.harvest_multiplier(res_id)) if gs and gs.has_method("harvest_multiplier") else 1.0
	_stroke_carry += maxf(factor, 0.0)
	var whole: int = int(floor(_stroke_carry + 0.0001))
	_stroke_carry -= float(whole)
	return whole

## Which of his tools made a stroke on `res_id` count for more, in words; "" by hand.
func _stroke_note(res_id: String) -> String:
	var cfg = _get_config()
	var gs = _get_game_state()
	if cfg == null or not cfg.has_method("harvest_note") or gs == null or not ("unlocks" in gs):
		return ""
	return String(cfg.harvest_note(res_id, gs.unlocks))

func _is_in_build_range(pos: Vector3, b: Node, extra_buffer: float = 0.0) -> bool:
	if b == null or not is_instance_valid(b):
		return false
	return _in_build_range_of(pos, b.global_position, String(b.building_type) if "building_type" in b else "", extra_buffer)

## Close enough to work on a `type_id` standing at `b_pos` -- one that is there, or one that is
## only in hand (can_reach_to_build).
func _in_build_range_of(pos: Vector3, b_pos: Vector3, type_id: String, extra_buffer: float = 0.0) -> bool:
	# Check 1: Euclidean distance to center
	var dist_center = pos.distance_to(b_pos)
	if dist_center <= (build_range + extra_buffer):
		return true

	# Check 2: 2D bounding box distance to the building's own box -- all of its cells: the cabin
	# stands in a block of them (Config.get_building_half).
	var half_box := Vector2(0.5, 0.5)
	var cfg_fp = _get_config()
	if cfg_fp and cfg_fp.has_method("get_building_half") and type_id != "":
		half_box = cfg_fp.get_building_half(type_id)
	var dx = maxf(0.0, absf(pos.x - b_pos.x) - half_box.x)
	var dz = maxf(0.0, absf(pos.z - b_pos.z) - half_box.y)
	var dist_box = sqrt(dx * dx + dz * dz)
	var max_box_dist = maxf(0.6, build_range - minf(half_box.x, half_box.y) + 0.2) + extra_buffer
	return dist_box <= max_box_dist

## Close enough to work `node`: body to body, his arm's length from what blocks -- a
## tree's trunk, a rock's side (ResourceNode.block_radius). It was two metres and a
## bit from the middle, whatever the thing was, and he chopped trees from out under the
## crown.
func _is_in_node_range(pos: Vector3, node: Node, extra_buffer: float = 0.0) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var flat: Vector3 = pos - node.global_position
	flat.y = 0.0
	var blocks: float = float(node.block_radius()) if node.has_method("block_radius") else 0.8
	var cfg = _get_config()
	var me: float = float(cfg.HERO.get("width", 0.8)) * 0.5 if (cfg and "HERO" in cfg) else 0.4
	var reach: float = float(cfg.HERO.get("harvest_reach", 0.45)) if (cfg and "HERO" in cfg) else 0.45
	return flat.length() <= blocks + me + reach + extra_buffer

func _plan_path_to_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_plan_path_to_building(node)

func _plan_path(dest: Vector3, ignore_b: Node = null) -> void:
	target_destination = dest
	target_destination.y = global_position.y
	current_path.clear()
	current_path_index = 0
	_stuck_timer = 0.0
	_last_pos = global_position

	var pts: Array[Vector3] = _route_to(target_destination, ignore_b)
	if pts.size() > 0:
		current_path = pts
		current_path_index = 0
		return

	current_path = [target_destination]
	current_path_index = 0

## His way to a point, from the mesh baked WITHOUT HIS OWN FENCE IN IT.
##
## walls_are_open, which for the mesh is not a flag threaded through a pathfinder but the
## other of the two bakes: layer 32 is simply absent from it. See Config.LAYER_WALL. His
## collision mask leaves walls out too, so the route and the physics cannot disagree --
## and a route that goes the long way round something he can walk straight through looks
## exactly like broken pathfinding.
func _route_to(dest: Vector3, _ignore_b: Node = null) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return pts     # no mesh: _plan_path falls back to walking straight at it
	for pt in maps.path(global_position, dest, true):
		pts.append(pt)
	return pts

func _nav_maps() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(NavMaps.GROUP)

func _plan_path_to_building(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	var b_pos = b.global_position
	b_pos.y = global_position.y
	# To the side of it he is on. The middle of a building is equally far from all of its
	# walls, and the mesh settles that tie the same way whichever side he comes from: sent
	# to mend the cabin from its door, he walked round to its back wall to do it. Aiming at
	# the point of its box nearest him keeps him on his own side.
	var cfg_side = _get_config()
	if cfg_side and cfg_side.has_method("get_building_half") and "building_type" in b:
		var half: Vector2 = cfg_side.get_building_half(String(b.building_type))
		var from_it: Vector3 = global_position - b_pos
		b_pos += Vector3(clampf(from_it.x, -half.x, half.x), 0.0, clampf(from_it.z, -half.y, half.y))

	# WHERE THE ROUTE ENDS IS WHERE HE CAN WORK FROM. A building is carved out of the
	# mesh, so a route to its centre stops at the edge of the carve -- which is a
	# stand-point beside it, arrived at from whichever side he is coming from.
	#
	# This replaces a scan of four cardinal offsets, each tested for a walkable
	# neighbour, each pathed to, sorted by distance, first success taken. That scan was
	# answering "where can somebody of my size stand next to this" with a hand-written
	# rule, and a bake answers it by construction. Measured: the route ends 0.92m from
	# the cabin's centre and 0.20m from a stake's, both inside build range, where the
	# grid handed back a single waypoint at the building's own centre and let him walk
	# into it.
	var maps := _nav_maps()
	if maps != null and maps.is_ready():
		var route: PackedVector3Array = maps.path(global_position, b_pos, true)
		if not route.is_empty() and _is_in_build_range(route[route.size() - 1], b):
			current_path.clear()
			for pt in route:
				current_path.append(pt)
			current_path_index = 0
			target_destination = current_path[current_path.size() - 1]
			_stuck_timer = 0.0
			_last_pos = global_position
			return

	_plan_path(b_pos, b)

## Next blueprint the Hero should work on: the one queued earliest.
## Work that is paid for and waiting on him: a blueprint, or an upgrade under way.
func _is_unfinished_work(b: Node) -> bool:
	if "is_constructed" in b and not b.is_constructed:
		return true
	return b.has_method("is_upgrading") and b.is_upgrading()

func _find_nearest_unfinished_building() -> Node:
	if not is_inside_tree():
		return null
	var unfinished: Array[Node] = []
	var gm = _get_grid_manager()
	if gm and gm.has_method("get_all_buildings"):
		for b in gm.get_all_buildings():
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				if _is_unfinished_work(b):
					if not ("is_destroyed" in b and b.is_destroyed):
						unfinished.append(b)

	if unfinished.is_empty():
		for group_name in ["buildings", "blueprints"]:
			for node in get_tree().get_nodes_in_group(group_name):
				if is_instance_valid(node) and not node.is_queued_for_deletion():
					if _is_unfinished_work(node):
						if not ("is_destroyed" in node and node.is_destroyed):
							if not unfinished.has(node):
								unfinished.append(node)

	if unfinished.is_empty():
		return null

	# A blueprint he cannot walk to is not work he can do. Without this he takes the
	# oldest one, fails to reach it, replans, and does it again forever -- which is
	# exactly what happens when the player lays several rows at once and a finished
	# stake ends up between him and the rest of the queue.
	#
	# Skipping it rather than dropping it: the rest of the row still goes up, and the
	# unreachable one is picked up again the moment a way opens (demolish one stake
	# and it is next in line). If NONE of them can be reached he keeps trying the
	# oldest, which is the honest thing -- he is fenced in, and walking into the
	# fence is at least visible. Going idle would hide it and leave him asleep after
	# the player opened the fence again.
	var reachable: Array[Node] = _reachable_among(unfinished)
	if not reachable.is_empty():
		unfinished = reachable

	# Oldest blueprint first: when the player lays a row of stakes, they go up in
	# the order they were clicked. Nearest-first looks arbitrary from the outside,
	# because the Hero's position is not something the player was thinking about.
	var best: Node = null
	var best_order: int = -1
	var best_dist_sq: float = 0.0
	for b in unfinished:
		var order: int = int(b.build_order) if "build_order" in b else -1
		var d_sq: float = global_position.distance_squared_to(b.global_position)
		if best == null:
			best = b
			best_order = order
			best_dist_sq = d_sq
			continue
		# Fall back to distance only between blueprints with no order stamp.
		if order >= 0 and best_order >= 0:
			if order < best_order:
				best = b
				best_order = order
				best_dist_sq = d_sq
		elif order >= 0 and best_order < 0:
			best = b
			best_order = order
			best_dist_sq = d_sq
		elif order < 0 and best_order < 0 and d_sq < best_dist_sq:
			best = b
			best_dist_sq = d_sq
	return best

## Whether he can get near enough to `b` to work on it.
##
## THE ROUTE IS THE ANSWER, and "near enough" is build range rather than the building's
## centre -- which is the honest form of the question, because he never stands on a
## building. Asking whether its centre is reachable means asking whether he can stand
## inside a thing that is solid: the mesh stops him a body's width short of every
## building, and a wide enough one would then read as unreachable while he was standing
## against it with his hammer out.
## Whether he could get close enough to raise a `type_id` at `at` -- asked of one that is not there
## yet, by the build preview: an order he could never carry out is refused, and why is said (v0.6
## round three: "如果人没法完成这个pending建造……那就提示没法建造的原因"). The same question as
## _can_work_on. Nothing to ask it of -- no mesh yet -- is a yes.
func can_reach_to_build(type_id: String, at: Vector3) -> bool:
	if _in_build_range_of(global_position, at, type_id):
		return true
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return true
	var route: PackedVector3Array = maps.path(global_position, at, true)
	return not route.is_empty() and _in_build_range_of(route[route.size() - 1], at, type_id)

func _can_work_on(b: Node) -> bool:
	if b == null or not is_instance_valid(b) or not (b is Node3D):
		return false
	var route: Array[Vector3] = _route_to((b as Node3D).global_position, b)
	if route.is_empty():
		return false
	return _is_in_build_range(route[route.size() - 1], b)

## Which of `candidates` he can actually walk to. Empty means nothing could be asked,
## and the caller then does not filter at all.
func _reachable_among(candidates: Array[Node]) -> Array[Node]:
	var out: Array[Node] = []
	if _nav_maps() == null:
		return out
	for b in candidates:
		if _can_work_on(b):
			out.append(b)
	return out

## Being wedged against something is the one moment worth asking whether the
## blueprint he is walking to can be reached at all. If it cannot and other work
## can, he moves on instead of grinding against the stake in front of it.
func _abandon_unreachable_building() -> bool:
	if target_building == null or not is_instance_valid(target_building):
		return false
	if not ("is_constructed" in target_building) or bool(target_building.is_constructed):
		return false
	if _can_work_on(target_building):
		return false
	var next_b = _find_nearest_unfinished_building()
	if next_b == null or next_b == target_building:
		return false
	target_building = null
	order_build(next_b, true)
	return true

func _continue_to_next_pending_building_or_idle() -> void:
	target_building = null
	var next_b = _find_nearest_unfinished_building()
	if next_b != null:
		order_build(next_b)
	else:
		current_state = State.IDLE

# ==============================================================================
# Orders API
# ==============================================================================

## Drops every outstanding target. Each order starts by calling this so a new
## command fully replaces the previous one -- move_to() used to clear only some of
## them, which let a half-finished harvest quietly drag the Hero back and made him
## look unresponsive.
func _clear_orders() -> void:
	target_building = null
	target_enemy = null
	target_resource_node = null
	_resume_work = {}

func move_to(dest: Vector3) -> void:
	if current_state == State.DEAD:
		return
	_clear_orders()
	_plan_path(dest)
	current_state = State.MOVING

func order_build(building: Node, force: bool = false) -> void:
	if current_state == State.DEAD:
		return
	if building == null or not is_instance_valid(building):
		current_state = State.IDLE
		return
	# A non-forced order must not retarget a Hero who already has a blueprint in
	# hand. Guarding only the BUILDING state let every fresh click steal him while
	# he was still WALKING to the previous one, so a row went up in reverse order.
	if not force and target_building != null and is_instance_valid(target_building) 			and not target_building.is_queued_for_deletion() 			and "is_constructed" in target_building and not target_building.is_constructed 			and target_building != building 			and current_state in [State.BUILDING, State.MOVING]:
		return
	_clear_orders()
	target_building = building

	if _is_in_build_range(global_position, building):
		velocity = Vector3.ZERO
		current_state = State.BUILDING
		return

	_plan_path_to_building(building)
	current_state = State.MOVING

## Sends the Hero to work on a damaged building. It is deliberately the same order
## as raising a blueprint -- one verb, and the building decides what the hammer is
## for.
func order_repair(building: Node) -> void:
	repair_timer = 0.0
	order_build(building, true)

## Sends the Hero to build an upgrade onto a building: the same order again, because
## it is the same work -- the building says what the hammer is for.
func order_upgrade(building: Node) -> void:
	order_build(building, true)

func order_attack(enemy: Node3D) -> void:
	if current_state == State.DEAD:
		return
	_clear_orders()
	target_enemy = enemy
	if enemy and is_instance_valid(enemy):
		_plan_path(enemy.global_position)
	current_state = State.MOVING

## Whether the Hero has what it takes to work this node at all. Stone needs a
## pick, and the pick is made at the cabin -- so "can I cut this" is a question
## about what he has made, not about where he is standing.
func can_harvest(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not ("resource_type" in node):
		return false
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("harvest_requires_unlock"):
		return true
	var needed: String = String(cfg.harvest_requires_unlock(String(node.resource_type)))
	if needed == "":
		return true
	var gs = _get_game_state()
	return gs != null and gs.has_method("has_unlock") and gs.has_unlock(needed)

func order_harvest(node: Node) -> void:
	if current_state == State.DEAD:
		return
	if node == null or not is_instance_valid(node):
		current_state = State.IDLE
		return
	if "is_depleted" in node and node.is_depleted:
		current_state = State.IDLE
		return
	if not can_harvest(node):
		return

	_clear_orders()
	target_resource_node = node

	if _is_in_node_range(global_position, node):
		velocity = Vector3.ZERO
		current_state = State.HARVESTING
		harvest_timer = 0.0
		return

	_plan_path_to_node(node)
	current_state = State.MOVING

func order_stop() -> void:
	_clear_orders()
	current_path.clear()
	current_path_index = 0
	velocity = Vector3.ZERO
	if current_state != State.DEAD:
		current_state = State.IDLE

func get_display_info() -> Dictionary:
	var name_str = TranslationServer.translate("HERO_NAME")
	var gs = _get_game_state()
	return {
		"title": name_str,
		"type": "hero",
		"hp": current_hp,
		"max_hp": max_hp,
		# The meal's part of it, drawn in the boost's colour on his panel; his armour's, in leather.
		"base_max_hp": base_max_hp,
		"natural_max_hp": _natural_max_hp(),
		# How fast he walks and works, and how much of it is the meal's (his panel's bars).
		"move_speed": walk_speed(),
		"base_move_speed": speed,
		"build_speed": work_rate(),
		"eating": eating_left(),
		"fed": gs.fed.duplicate() if (gs and "fed" in gs) else {},
		# His health is the card's bar; the line under it says what he can be told to do -- or,
		# while he eats, how long he has still to go.
		"status": (TranslationServer.translate("HERO_EATING") % eating_left()) if is_eating() \
			else TranslationServer.translate("HERO_HINT"),
	}

# ==============================================================================
# Combat & Damage
# ==============================================================================

## Back up by `amount`, never past his full health. A meal is the only thing that
## does this (GAME-DESIGN 4.5).
func heal(amount: float) -> void:
	if current_state == State.DEAD or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)
	_refresh_health_bar()
	var eb = _get_event_bus()
	if eb and eb.has_signal("hero_hp_changed"):
		eb.hero_hp_changed.emit(current_hp, max_hp)

func _on_meal_eaten(meal: Dictionary) -> void:
	heal(float(meal.get("heal", 0.0)))

# ==============================================================================
# Eating (v0.6 round two: "做完之后也没有吃的动作……人也没有明显吃了肉之后的状态转化效果")
# ==============================================================================

## The meal in his hand while he eats it: its key in the stock (GameState.meals), and how long
## he has still to go.
var _meal_in_hand: String = ""
var _eat_left: float = 0.0
var _meat: Node3D = null
var _aura: MeshInstance3D = null

## He eats one of the meal `key` from the stock: stops where he is, takes it in his hand and eats
## for Config.EATING.eat_seconds -- his hand to his mouth, the meat in it -- and the meal, and its
## boost, are his when he has finished. Any other order before then puts it down uneaten. Returns
## whether he began; he cannot eat what has not been cooked.
func order_eat(key: String) -> bool:
	if current_state == State.DEAD:
		return false
	var gs = _get_game_state()
	if gs == null or not gs.has_method("meal_count") or int(gs.meal_count(key)) <= 0:
		return false
	_clear_orders()
	current_path.clear()
	current_path_index = 0
	velocity = Vector3.ZERO
	current_state = State.IDLE      # whatever he was eating before is put down first
	_meal_in_hand = key
	_eat_left = _eating_number("eat_seconds", 2.5)
	current_state = State.EATING
	_sound_at("eat", global_position + Vector3(0.0, 1.0, 0.0))
	_take_the_meal(key)
	return true

## Whether he is eating right now.
func is_eating() -> bool:
	return current_state == State.EATING

## Seconds of eating left, or 0 when he is not eating.
func eating_left() -> float:
	return _eat_left if current_state == State.EATING else 0.0

func _process_eating(delta: float) -> void:
	_eat_left -= delta
	if _eat_left > 0.0:
		return
	var key: String = _meal_in_hand
	current_state = State.IDLE
	var gs = _get_game_state()
	var meal: Dictionary = gs.eat_meal(key) if (gs and gs.has_method("eat_meal")) else {}
	if not meal.is_empty():
		_show_the_boost(meal)

## The meat in his hand: the pile the game drops of it, small, held in the hand his clip brings
## to his mouth (Config.EATING.prop_bone).
func _take_the_meal(key: String) -> void:
	_put_the_meal_away()
	var cfg = _get_config()
	var body: Node = find_child("Body", false, false)
	if cfg == null or body == null:
		return
	var skeletons: Array = body.find_children("*", "Skeleton3D", true, false)
	var dish: String = key.get_slice("/", 0)
	var eats: Dictionary = cfg.DISHES.get(dish, {}).get("inputs", {})
	if skeletons.is_empty() or eats.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone: String = String(cfg.EATING.get("prop_bone", "hand_r")) if "EATING" in cfg else "hand_r"
	if skeleton.find_bone(bone) < 0:
		return
	var hold := BoneAttachment3D.new()
	hold.name = "MealInHand"
	hold.bone_name = bone
	skeleton.add_child(hold)
	var meat: Node3D = VisualLibrary.make("drop/" + String(eats.keys()[0]))
	hold.add_child(meat)
	# As big across as Config says, whatever the rig's own scale: the hand carries the fit the
	# model was given to stand 1.2 m tall.
	var across: float = maxf(0.001, VisualLibrary.visual_bounds(meat).get_longest_axis_size())
	var inherited: float = maxf(0.001, hold.global_transform.basis.get_scale().x)
	meat.scale = Vector3.ONE * (_eating_number("prop_size", 0.24) / (across * inherited))
	_meat = hold

func _put_the_meal_away() -> void:
	if _meat != null and is_instance_valid(_meat):
		_meat.queue_free()
	_meat = null

## Stopped before the end: nothing is eaten, and the meal stays in the stock.
func _put_the_meal_down() -> void:
	_meal_in_hand = ""
	_eat_left = 0.0
	_put_the_meal_away()

## What the meal did, where the player is looking: a burst in the boost's colour and its effects
## in words rising off him (Config.describe_meal), and the sound of it going in.
func _show_the_boost(meal: Dictionary) -> void:
	var fx = _get_fx()
	var cfg = _get_config()
	if fx == null:
		return
	var colour: Color = UiTheme.color("boost")
	fx.debris(global_position + Vector3(0.0, 0.8, 0.0), colour)
	if cfg and cfg.has_method("describe_meal"):
		fx.floating_text(global_position + Vector3(0.0, 1.2, 0.0), cfg.describe_meal(meal), colour)
	fx.play(fx.Sound.PICKUP)

## The boost's hit points: over his own while he is fed, full when he eats -- and gone again,
## with any of them he was living on, when it wears off. And the ring at his feet that says he
## is fed.
func _on_fed_changed(fed: Dictionary) -> void:
	var was: float = max_hp
	max_hp = base_max_hp + float(fed.get("max_hp", 0.0))
	if max_hp > was and current_state != State.DEAD:
		current_hp += max_hp - was
	current_hp = minf(current_hp, max_hp)
	_refresh_health_bar()
	var eb = _get_event_bus()
	if eb and eb.has_signal("hero_hp_changed"):
		eb.hero_hp_changed.emit(current_hp, max_hp)
	_show_aura(not fed.is_empty())

## A ring of the boost's colour at his feet, while he is fed (Config.EATING.aura_radius).
func _show_aura(on: bool) -> void:
	if on and (_aura == null or not is_instance_valid(_aura)):
		var r: float = _eating_number("aura_radius", 0.55)
		var ring := TorusMesh.new()
		ring.inner_radius = r * 0.88
		ring.outer_radius = r
		ring.rings = 32
		ring.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var colour: Color = UiTheme.color("boost")
		mat.albedo_color = Color(colour.r, colour.g, colour.b, 0.75)
		_aura = MeshInstance3D.new()
		_aura.name = "FedAura"
		_aura.mesh = ring
		_aura.material_override = mat
		_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aura.scale = Vector3(1.0, 0.15, 1.0)          # flat on the ground
		_aura.position = Vector3(0.0, 0.03, 0.0)
		add_child(_aura)
	if _aura != null and is_instance_valid(_aura):
		_aura.visible = on

func _eating_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	if cfg and "EATING" in cfg:
		return float(cfg.EATING.get(key, fallback))
	return fallback

## How fast he raises and mends: 1.0, or more on a good meal (GameState.build_multiplier).
func work_rate() -> float:
	var gs = _get_game_state()
	return float(gs.build_multiplier()) if gs and gs.has_method("build_multiplier") else 1.0

## His hit points bare: Config.HERO's, without armour or a meal.
func _natural_max_hp() -> float:
	var cfg = _get_config()
	return float(cfg.HERO.get("hp", 10.0)) if (cfg and "HERO" in cfg) else base_max_hp

## Metres a second he walks: his own pace, or more on a good meal.
func walk_speed() -> float:
	var gs = _get_game_state()
	return speed * (float(gs.move_multiplier()) if gs and gs.has_method("move_multiplier") else 1.0)

## Sound `id` in the world at `where` (Fx.play_at).
func _sound_at(id: String, where: Vector3) -> void:
	var fx = _get_fx()
	if fx and fx.has_method("play_at"):
		fx.play_at(id, where)

func _sound_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.SOUNDS.get(key, fallback)) if (cfg and "SOUNDS" in cfg) else fallback

## How far into the next knock of his hammer he is (Config.SOUNDS.hammer_every).
var _hammer_clock: float = 0.0

func take_damage(amount: float) -> void:
	if current_state == State.DEAD or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	_ensure_feedback_nodes(2.0, true)
	_refresh_health_bar()
	var fx = _get_fx()
	if fx:
		fx.flash(mesh_instance)
	_sound_at("hero_hurt", global_position + Vector3(0.0, 1.0, 0.0))
	var eb = _get_event_bus()
	if eb and eb.has_signal("hero_hp_changed"):
		eb.hero_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		die()
		return
	_hit_back()

## Bitten at his work, he turns on what is biting him (found playing, v0.6 round three: quarrying
## by the nest, the guards bit him from twelve hit points to none while he went on swinging at
## the rock). Only at work -- a walk the player sent him on, a meal, a fight already under way
## are the player's to change -- and only at what is in his reach. The work is remembered and
## taken up again when nothing is left to fight (_process_attacking).
func _hit_back() -> void:
	if current_state != State.HARVESTING and current_state != State.BUILDING:
		return
	var biter: Node3D = _find_nearest_enemy(attack_range + 0.3)
	if biter == null:
		return
	_resume_work = {"node": target_resource_node, "building": target_building}
	target_resource_node = null
	target_building = null
	target_enemy = biter
	current_state = State.ATTACKING

## What he was doing when he turned to fight (_hit_back): a node he was working, a building he
## was raising or mending.
var _resume_work: Dictionary = {}

## Back to it, once the fight is over: the node, or the building, if it is still there to work.
func _take_up_work_again() -> bool:
	var work: Dictionary = _resume_work
	_resume_work = {}
	var node = work.get("node")
	if node != null and is_instance_valid(node) and not ("is_depleted" in node and node.is_depleted):
		order_harvest(node)
		return true
	var b = work.get("building")
	if b != null and is_instance_valid(b) and not ("is_destroyed" in b and b.is_destroyed):
		order_build(b, true)
		return true
	return false

func die() -> void:
	if current_state == State.DEAD:
		return
	# What bit him last is at his side: the defeat screen says what killed him (the debug-agent's
	# BUG-011).
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs != null and "hero_killer" in gs:
		var within: float = float(cfg.HERO.get("killer_within", 3.0)) if cfg else 3.0
		var killer: Node3D = _find_nearest_enemy(within)
		gs.hero_killer = {} if killer == null else \
			{"type": String(killer.get("dino_type")), "guard": killer.is_in_group("guard_dinos")}
	current_state = State.DEAD
	velocity = Vector3.ZERO
	var eb = _get_event_bus()
	if eb and eb.has_signal("hero_died"):
		eb.hero_died.emit()

func _is_enemy_valid(enemy: Variant) -> bool:
	if enemy == null or typeof(enemy) != TYPE_OBJECT or not is_instance_valid(enemy):
		return false
	if not (enemy is Node3D):
		return false
	if enemy.is_queued_for_deletion():
		return false
	if "is_destroyed" in enemy and enemy.is_destroyed:
		return false
	if "is_dead" in enemy and enemy.is_dead:
		return false
	if "current_state" in enemy and int(enemy.current_state) == 2: # Dino.State.DEAD
		return false
	if "current_hp" in enemy and enemy.current_hp <= 0.0:
		return false
	return true

func _find_nearest_enemy(max_dist: float) -> Node3D:
	if not is_inside_tree():
		return null
	var candidates: Array[Node3D] = []
	# Not the nest: it cannot be hurt (v0.6), and a man swinging at it would stand there
	# for the rest of the run.
	for group_name in ["guard_dinos", "dinos"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node3D and _is_enemy_valid(node):
				if not candidates.has(node):
					candidates.append(node)
	# Only what is on his side of the cabin's wall (found playing, v0.6 round three: sheltering at
	# the workbench in a raid, he went out after a raptor biting the back wall, into the pack). To
	# go out and fight is the player's call (order_attack).
	var cabin: Node = get_tree().get_first_node_in_group("core")
	var walled: bool = cabin != null and cabin.has_method("is_inside")
	var inside: bool = walled and bool(cabin.is_inside(global_position))
	var nearest: Node3D = null
	var min_dist_sq: float = max_dist * max_dist
	for cand in candidates:
		if walled and bool(cabin.is_inside(cand.global_position)) != inside:
			continue
		var d_sq = global_position.distance_squared_to(cand.global_position)
		if d_sq <= min_dist_sq:
			min_dist_sq = d_sq
			nearest = cand
	return nearest

# ==============================================================================
# Phase Reaction (v0.1: Hero hidden and invincible during ATTACK phase)
# ==============================================================================

func _on_phase_changed(phase: int) -> void:
	if continuous_mode:
		return
	if phase == 1: # Phase.ATTACK
		visible = false
		collision_layer = 0
		collision_mask = 0
		target_building = null
		target_enemy = null
		if current_state != State.DEAD:
			current_state = State.IDLE
	elif phase == 0: # Phase.DEPLOY
		if current_state != State.DEAD:
			visible = true
			collision_layer = _layer("LAYER_HERO", 4)
			collision_mask = _his_mask()
			current_state = State.IDLE

# ==============================================================================
# Visual & Physics Setup
# ==============================================================================

## How big the Hero is, as Config declares it: one figure for the collider and the body
## both, so a model dropped in later is exactly as wide as the thing a fence stops.
func _declared_size() -> Vector3:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_visual_size"):
		return cfg.get_visual_size("hero")
	return Vector3(0.8, 1.6, 0.8)

## (Re)builds the visible body and points `mesh_instance` at it, which the feedback
## layer flashes and the HUD tints.
func _ensure_body() -> void:
	var existing := find_child("Body", false, false)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var body: Node3D = VisualLibrary.make("hero")
	add_child(body)
	mesh_instance = null
	for node in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node as MeshInstance3D
		break
	if animator != null and is_instance_valid(animator):
		animator.refresh_animation_player()
		animator.play_state(current_state)

func _ensure_components() -> void:
	# His own layer, and what he bumps into: the ground's obstacles, buildings, and -- since v0.6
	# round two -- his own walls ("人不能再穿过墙了"; his way through is a gate, whose layer this
	# leaves out) and the dinosaurs, which bump into him back ("所有单位都不能重叠").
	collision_layer = _layer("LAYER_HERO", 4)
	collision_mask = _his_mask()

	if collision_shape == null:
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

	if animator == null:
		animator = ActorAnimator.new()
		animator.name = "ActorAnimator"
		add_child(animator)
		animator.setup(self, "hero")
	else:
		animator.refresh_animation_player()

	# The body comes from the one place that knows what things look like. The collider
	# above is built from the SAME declared size rather than measured off the art,
	# because the collider is gameplay -- it is what a fence stops -- and art that
	# disagrees with its collider is the bug this project keeps having to fix.
	_ensure_body()

# ==============================================================================
# Resolvers
# ==============================================================================

## What his body bumps into: everything solid but a gate.
func _his_mask() -> int:
	return _layer("LAYER_GROUND", 1) | _layer("LAYER_BUILDING", 2) | _layer("LAYER_WALL", 32) | _layer("LAYER_DINO", 8)

## A collision layer by its Config name.
func _layer(key: String, fallback: int) -> int:
	var cfg = _get_config()
	return int(cfg.get(key)) if (cfg and key in cfg) else fallback

func _get_current_phase() -> int:
	var gs = _get_game_state()
	if gs and "current_phase" in gs:
		return int(gs.current_phase)
	return 0

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

func _get_grid_manager() -> Node:
	if is_inside_tree():
		var gms = get_tree().get_nodes_in_group("grid_manager")
		if gms.size() > 0 and is_instance_valid(gms[0]):
			return gms[0]
		if get_tree().root:
			return get_tree().root.find_child("GridManager", true, false)
	return null

## The thing the Hero is currently working on (or walking towards), or null when
## he has nothing queued. The Option Panel follows this so the player watches the
## job in progress without having to click it, and gets the Hero back when it ends.
func get_active_task_target() -> Node:
	match current_state:
		State.BUILDING:
			return target_building if is_instance_valid(target_building) else null
		State.HARVESTING:
			return target_resource_node if is_instance_valid(target_resource_node) else null
		State.MOVING:
			# En route: show whatever he is on his way to, if anything.
			for t in [target_building, target_resource_node]:
				if t != null and is_instance_valid(t):
					return t
	return null
# ==============================================================================
# Feedback layer (v0.3)
# ==============================================================================

func _ensure_feedback_nodes(bar_height: float, want_ring: bool) -> void:
	if status_bar == null or not is_instance_valid(status_bar):
		status_bar = find_child("StatusBar", true, false)
	if status_bar == null:
		var bar_script = load("res://scripts/fx/StatusBar3D.gd")
		if bar_script:
			status_bar = bar_script.new()
			status_bar.name = "StatusBar"
			status_bar.position = Vector3(0.0, bar_height, 0.0)
			add_child(status_bar)
	if want_ring and (selection_ring == null or not is_instance_valid(selection_ring)):
		selection_ring = find_child("SelectionRing", true, false)
		if selection_ring == null:
			var ring_script = load("res://scripts/fx/SelectionRing3D.gd")
			if ring_script:
				selection_ring = ring_script.new()
				selection_ring.name = "SelectionRing"
				add_child(selection_ring)

func _refresh_health_bar() -> void:
	if status_bar == null or not is_instance_valid(status_bar):
		return
	var ratio: float = (current_hp / max_hp) if max_hp > 0.0 else 0.0
	var hide_full: bool = true
	var cfg = _get_config()
	if cfg and "FEEDBACK" in cfg:
		hide_full = bool(cfg.FEEDBACK.get("health_bar_hide_at_full", true))
	status_bar.visible = not (hide_full and ratio >= 0.999)
	status_bar.set_ratio(ratio, Color(0.85, 0.3, 0.25, 0.95) if ratio < 0.35 else Color(0.3, 0.85, 0.35, 0.95))

func set_selected_visual(on: bool) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("set_shown"):
		selection_ring.set_shown(on)

func _connect_feedback_events() -> void:
	var eb = _get_event_bus()
	if eb == null:
		return
	if eb.has_signal("unit_selected") and not eb.unit_selected.is_connected(_on_fx_unit_selected):
		eb.unit_selected.connect(_on_fx_unit_selected)
	if eb.has_signal("unit_deselected") and not eb.unit_deselected.is_connected(_on_fx_unit_deselected):
		eb.unit_deselected.connect(_on_fx_unit_deselected)

func _on_fx_unit_selected(unit: Node) -> void:
	set_selected_visual(unit == self)

func _on_fx_unit_deselected() -> void:
	set_selected_visual(false)

func _get_fx() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Fx")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Fx")
	return null
## A thin circle at its feet: a unit, not a building (Config.FEEDBACK.unit_ring_*).
func _configure_selection_ring(base_size: float) -> void:
	if selection_ring and is_instance_valid(selection_ring) and selection_ring.has_method("configure"):
		selection_ring.configure(SelectionRing3D.Shape.ROUND, base_size)
