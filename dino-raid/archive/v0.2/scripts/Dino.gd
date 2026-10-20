class_name Dino
extends Unit
## A dinosaur on the field. Nobody orders it: it does what its kind does (Species.ALL).
##
## A meat-eater goes for a robot it can see; else follows the smell of meat; else looks into a noise; else
## keeps with its clutch. A plant-eater grazes, bolts from a noise -- trampling what is in its way -- comes to
## a mating call, and the hot-tempered ones turn on whatever hurt them. The small hunters keep clear of a
## tyrannosaur, which eats them when there is nothing better. The smell of blood sends a hunter into a frenzy.
##
## It hatches from a nest (Nest): the first out of a clutch is the biggest, and the rest keep near it.
##
## Moving is the engine's: each frame it says where it would like to go (Avoider) and the avoidance answers
## with a velocity that does not walk into its neighbours.

enum Mode { IDLE, SEEK, HUNT, FLEE, STAMPEDE, FOLLOW }

const THINK_EVERY := 0.25
const WANDER := 4.0
const LOOPED := ["idle", "walk", "run", "graze", "sleep"]
const BIG := 1.12            # the first out of a clutch: this much bigger...
const BIG_HP := 1.25         # ...and this much tougher
const KEEP_NEAR := 9.0       # the rest run after it once it is off somewhere and this far
const FRENZY_SIGHT := 30.0   # a hunter in a frenzy sees robots this far off,
const FRENZY_PACE := 1.25    # runs this much faster, and bites twice as often

var kind := ""
var s: Dictionary
var mode := Mode.IDLE
var target: Unit = null
var length := 1.0
var reach := 1.0
## The first out of its clutch, which it keeps near; null for that one itself.
var leader: Dino = null

var _goal := Vector3.ZERO
var _seeking: Node = null         # the Scent or Call it goes to; null when it is a noise it looks into
var _home := Vector3.ZERO
var _heading := Vector3.ZERO
var _mode_until := 0.0
var _trampled := {}
var _angry_at: Unit = null
var _angry_until := 0.0
var _noise_at := Vector3.ZERO
var _noise_until := 0.0
var _frenzy_until := 0.0
var _rage: GPUParticles3D

var _model: Node3D
var _anim: AnimationPlayer
var _avoid: Avoider
var _paces: Dictionary
var _clip := ""
var _bite_ready := 0.0
var _busy_until := 0.0
var _think_in := 0.0
var _wander_at := 0.0
var _wander_goal := Vector3.ZERO
var _turn := 6.0
var _delta := 1.0 / 60.0


func setup(p_battle: Node, p_kind: String, scene: PackedScene, at: Vector3, facing: Vector3) -> void:
	battle = p_battle
	kind = p_kind
	s = Species.ALL[kind]
	team = "dino"
	max_hp = s.hp
	hp = max_hp
	_paces = s.get("paces", Species.DRAWN)

	_model = scene.instantiate() as Node3D
	add_child(_model)
	ArtDress.read_vertex_colours(_model)
	var box := Geo.bounds(_model)
	length = box.size.z
	radius = clampf(length * 0.15, 0.35, 3.5)
	reach = length * 0.3 + 0.4
	aim_height = box.size.y * 0.6
	_turn = clampf(30.0 / length, 2.0, 10.0)
	_model.position.y = -box.position.y
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clip in LOOPED:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

	position = at
	_home = at
	_wander_goal = at
	rotation.y = atan2(-facing.x, -facing.z)

	_avoid = Avoider.new(self, radius, _move)

	make_bar(box.size.y + 0.5, clampf(length * 0.2, 0.7, 3.0), false)
	_play("idle", 1.0)


## Out of its egg. The first of a clutch (no leader) is the biggest; the rest keep near it.
func hatch(p_leader: Dino) -> void:
	leader = p_leader
	var grown := 1.0
	if leader == null:
		grown = BIG
		max_hp *= BIG_HP
		hp = max_hp
		radius *= BIG
		reach *= BIG
		NavigationServer3D.agent_set_radius(_avoid.rid, radius)
	scale = Vector3.ONE * grown * 0.4
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * grown, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_call("alert")


## The smell of blood: a hunter goes wild for a while -- sees further, runs faster, bites twice as often.
func frenzy(secs: float) -> void:
	if dead or s.diet != "meat":
		return
	_frenzy_until = battle.clock + secs
	_think_in = 0.0
	_call("alert")
	if _rage == null:
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = maxf(0.5, length * 0.3)
		mat.direction = Vector3.UP
		mat.spread = 30.0
		mat.initial_velocity_min = 0.3
		mat.initial_velocity_max = 0.8
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.5
		mat.scale_max = 1.2
		mat.color_ramp = Fx.ramp(Color(0.6, 0.05, 0.04), 0.45)
		_rage = Fx.particles(mat, 16, 1.2)
		_rage.position.y = aim_height
		add_child(_rage)
	_rage.emitting = true


func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_bar()
	_delta = delta
	if battle.over:
		_avoid.ask(global_position, Vector3.ZERO)
		return
	if _rage and _rage.emitting and not _frenzied():
		_rage.emitting = false
	_think_in -= delta
	if _think_in <= 0.0:
		_think_in = THINK_EVERY * randf_range(0.8, 1.2)
		_think()
	_avoid.ask(global_position, _desire())


## What to do, from what it sees, smells and hears. Runs a few times a second.
func _think() -> void:
	var now: float = battle.clock
	if (mode == Mode.FLEE or mode == Mode.STAMPEDE) and now < _mode_until:
		return
	if not Unit.standing(leader):
		leader = null
	if s.diet == "meat":
		_think_hunter(now)
	else:
		_think_grazer(now)


func _think_hunter(now: float) -> void:
	if s.get("small", false):
		var rex: Dino = battle.nearest_dino(global_position, 7.0, func(d: Dino) -> bool: return d.s.get("apex", false))
		if rex:
			_flee(global_position - rex.global_position, 1.5, false)
			return
	var foe: Unit = battle.nearest_robot(global_position, FRENZY_SIGHT if _frenzied() else s.sight)
	if foe:
		_hunt(foe)
		return
	if mode == Mode.HUNT and Unit.standing(target) and target is Robot:
		return  # it saw this one and goes on after it
	var scent: Node = battle.scent_for(global_position, s.smell)
	if scent:
		if mode != Mode.SEEK or _seeking != scent:
			if mode != Mode.SEEK:
				_call("alert")
			_seeking = scent
			_goal = scent.position + _jitter(2.0)
			mode = Mode.SEEK
		return
	if s.get("apex", false):
		var prey: Dino = battle.nearest_dino(global_position, 10.0, func(d: Dino) -> bool: return d.s.get("small", false))
		if prey:
			_hunt(prey)
			return
	if now < _noise_until:
		if mode != Mode.SEEK or _seeking != null:
			_seeking = null
			_goal = _noise_at + _jitter(3.0)
			mode = Mode.SEEK
		return
	if _follow():
		return
	_settle()


func _think_grazer(now: float) -> void:
	if s.temper == "fight" and Unit.standing(_angry_at) and now < _angry_until:
		_hunt(_angry_at)
		return
	var call: Node = battle.call_for(global_position)
	if call:
		if mode != Mode.SEEK or _seeking != call:
			if mode != Mode.SEEK:
				_call("alert")
			_seeking = call
			_goal = call.position + _jitter(3.0)
			mode = Mode.SEEK
		return
	if _follow():
		return
	_settle()


## After the first of its clutch, when that has gone off somewhere. Whether it went.
func _follow() -> bool:
	if leader == null:
		return false
	if leader.mode != Mode.IDLE and Geo.flat(leader.global_position, global_position) > KEEP_NEAR:
		if mode != Mode.FOLLOW:
			mode = Mode.FOLLOW
			target = null
			_seeking = null
		return true
	return mode == Mode.FOLLOW  # on its way still: _desire says when it is there


## Back to wandering, round wherever it is now.
func _settle() -> void:
	if mode != Mode.IDLE:
		mode = Mode.IDLE
		target = null
		_seeking = null
		_home = global_position
		_wander_goal = global_position


func _hunt(foe: Unit) -> void:
	if target != foe:
		target = foe
		if mode != Mode.HUNT:
			_call("alert")
	mode = Mode.HUNT


func _flee(away: Vector3, secs: float, stampede: bool) -> void:
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_heading = away.normalized()
	mode = Mode.STAMPEDE if stampede else Mode.FLEE
	_mode_until = battle.clock + secs
	_trampled.clear()
	target = null


func _frenzied() -> bool:
	return battle.clock < _frenzy_until


## The velocity it would like this frame.
func _desire() -> Vector3:
	var now: float = battle.clock
	var run: float = s.run * (FRENZY_PACE if _frenzied() else 1.0)
	match mode:
		Mode.FLEE, Mode.STAMPEDE:
			if now >= _mode_until:
				_settle()
				return Vector3.ZERO
			if mode == Mode.STAMPEDE:
				_trample()
			return _heading * s.run
		Mode.HUNT:
			if not Unit.standing(target):
				_settle()
				return Vector3.ZERO
			var to := target.global_position - global_position
			to.y = 0.0
			if to.length() - target.radius - radius * 0.5 <= reach:
				_face(to)
				_bite()
				return Vector3.ZERO
			return to.normalized() * run
		Mode.SEEK:
			var to := _goal - global_position
			to.y = 0.0
			if to.length() < 1.5:
				if is_instance_valid(_seeking):
					# There: nose about inside the smell (or round the call), and stay round here after.
					_goal = _seeking.position + _jitter(_seeking.radius * 0.4)
					_home = global_position
				else:
					_noise_until = 0.0
					_settle()
				return Vector3.ZERO
			return to.normalized() * run
		Mode.FOLLOW:
			if leader == null:
				_settle()
				return Vector3.ZERO
			var to := leader.global_position - global_position
			to.y = 0.0
			if to.length() < KEEP_NEAR * 0.5:
				_settle()
				return Vector3.ZERO
			return to.normalized() * s.run
		_:
			if now >= _wander_at:
				_wander_at = now + randf_range(3.0, 7.0)
				var centre := leader.global_position if Unit.standing(leader) else _home
				_wander_goal = centre + _jitter(WANDER)
			var to := _wander_goal - global_position
			to.y = 0.0
			if to.length() < 0.8:
				return Vector3.ZERO
			return to.normalized() * s.walk


## The avoidance's answer: move by it. Nothing moves while the battle waits for the player.
func _move(v: Vector3) -> void:
	if dead or not can_process():
		return
	v.y = 0.0
	position += v * _delta
	position = battle.clamp_to_field(position, radius)
	var speed := v.length()
	if speed > 0.2:
		_face(v)
	if battle.clock < _busy_until:
		return
	if speed < 0.2:
		var graze: bool = s.diet == "plant" and mode == Mode.IDLE and _anim != null and _anim.has_animation("graze")
		_play("graze" if graze else "idle", 1.0)
	elif speed < (s.walk + s.run) * 0.5:
		_play("walk", clampf(speed / _paces.walk, 0.5, 2.2))
	else:
		_play("run", clampf(speed / _paces.run, 0.5, 2.2))


func _face(dir: Vector3) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, _turn * _delta))


func _bite() -> void:
	var now: float = battle.clock
	if s.bite <= 0 or now < _bite_ready:
		return
	var every: float = s.bite_every * (0.5 if _frenzied() else 1.0)
	_bite_ready = now + every
	_busy_until = now + minf(every * 0.8, 0.9)
	_play("attack", s.bite_every / every, true)
	battle.loud(target.global_position)
	target.hurt(s.bite, self)
	_call("bite")


## While bolting, everything robotic in its way takes a hit -- once each.
func _trample() -> void:
	for r: Unit in battle.robots:
		if r.alive() and not _trampled.has(r) and Geo.flat(r.global_position, global_position) < radius + r.radius + 1.0:
			_trampled[r] = true
			battle.loud(r.global_position)
			r.hurt(s.trample, self)
			battle.sound("stone_impact", global_position, 2.0)


## A noise nearby: a plant-eater bolts away from it; a hunter comes to see.
func hear(at: Vector3) -> void:
	if dead:
		return
	if s.diet == "plant":
		_flee(global_position - at, 6.0, true)
		_call("alert")
	else:
		_noise_at = at
		_noise_until = battle.clock + 8.0
		_think_in = 0.0


func _on_hurt(from: Unit) -> void:
	if not Unit.standing(from):
		return
	var now: float = battle.clock
	_call("hurt")
	if s.diet == "plant":
		if s.temper == "fight":
			_angry_at = from
			_angry_until = now + 8.0
			if mode != Mode.STAMPEDE:
				_think_in = 0.0
		elif mode != Mode.STAMPEDE:
			_flee(global_position - from.global_position, 4.0, true)
	elif from is Dino and s.get("small", false):
		_flee(global_position - from.global_position, 2.0, false)
	elif from is Robot and mode != Mode.HUNT:
		_hunt(from)  # shot at, it goes for the shooter


func _on_die() -> void:
	_avoid.release()
	if _rage:
		_rage.emitting = false
	_play("death", 1.0, true)
	_call("death")
	battle.unit_gone(self)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(self, "position:y", -4.0, 3.0)
	tw.tween_callback(queue_free)


func _play(clip: String, pace: float, restart := false) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.speed_scale = pace
	if clip != _clip or restart:
		_clip = clip
		_anim.play(clip, 0.2)
		if restart:
			_anim.seek(0.0, true)


## A sound of its own: <kind>_<what>.wav, or a call when it has none for that.
func _call(what: String) -> void:
	battle.sound_of(kind, what, global_position)


func _jitter(r: float) -> Vector3:
	var a := randf() * TAU
	return Vector3(cos(a), 0.0, sin(a)) * randf() * r
