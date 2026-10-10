class_name DinoView
extends UnitView
## A dinosaur, or a pack of them in one tile -- life-size models (Species), the first of a pack in its
## alpha's colours. A pack shows its count: when the battle says a body is lost, one falls.

const LOOPED := ["idle", "walk", "run", "graze", "sleep"]

var models: Array[Node3D] = []
var _anims: Array = []
var _paces := {}
var _rage: GPUParticles3D


func setup(p_battle: Node, u: Dictionary) -> void:
	setup_base(p_battle, u)
	var st: Dictionary = Species.ALL[kind]
	_paces = st.get("paces", Species.DRAWN)
	var spots := _formation(bodies)
	for i in bodies:
		var path := Species.scene_path(kind)
		if i == 0 and u.pack and ResourceLoader.exists(Species.scene_path(kind + "_alpha")):
			path = Species.scene_path(kind + "_alpha")
		var model := (battle.scene(path) as PackedScene).instantiate() as Node3D
		ArtDress.read_vertex_colours(model)
		var holder := Node3D.new()
		holder.position = spots[i]
		holder.rotation.y = randf_range(-0.25, 0.25)
		add_child(holder)
		holder.add_child(model)
		var box := Geo.bounds(model)
		model.position.y = -box.position.y
		blob(Vector3.ZERO, clampf(maxf(box.size.x, box.size.z) * 0.42, 0.7, 4.5), holder)
		models.append(holder)
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim:
			for clip in LOOPED:
				if anim.has_animation(clip):
					anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_anims.append(anim)
		aim = maxf(aim, box.size.y * 0.6)
		top = maxf(top, box.size.y + 0.4)
	if u.lead and bodies == 1:
		scale = Vector3.ONE * 1.1
	watch()
	_play("idle")


## Standing, it watches the far end, where the robots come from: seen from our end, three-quarters on.
func watch() -> void:
	face(Board.world(Rules.MACHINE_AT) - position)


func sync(u: Dictionary) -> void:
	super.sync(u)
	watch()


## Where the bodies of a pack stand in their tile.
func _formation(n: int) -> Array:
	if n <= 1:
		return [Vector3.ZERO]
	var out: Array = []
	var cols := 2
	var rows := ceili(n / 2.0)
	for i in n:
		var c := i % cols
		var r := i / cols
		var x := (c - 0.5) * 1.9 + randf_range(-0.25, 0.25)
		var z := (r - (rows - 1) * 0.5) * 1.6 + randf_range(-0.25, 0.25)
		out.append(Vector3(x, 0.0, z))
	return out


func _speed() -> float:
	return RUN


func _moving(on: bool) -> void:
	if on:
		_play("run", clampf(RUN / float(_paces.run), 0.6, 3.0))
	else:
		_play("idle")


## A bite at what stands at `at`; returns at the moment it lands.
func strike(at: Vector3) -> void:
	face(at - global_position)
	_play("attack", 1.3, true)
	await get_tree().create_timer(0.32).timeout


## How many are left standing, from the hit points.
func take(dmg: int) -> void:
	super.take(dmg)
	if bodies > 1 or models.size() > 1:
		var body_hp: int = Rules.DINOS[kind].hp
		var left := ceili(float(hp) / body_hp)
		while models.size() > maxi(left, 1) and models.size() > 1:
			_fall(models.pop_back(), _anims.pop_back())
		bodies = left


func _fall(holder: Node3D, anim: AnimationPlayer) -> void:
	if anim and anim.has_animation("death"):
		anim.play("death", 0.1)
	var tw := holder.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(holder, "position:y", -3.0, 1.6)
	tw.tween_callback(holder.queue_free)


func die() -> void:
	if _rage:
		_rage.emitting = false
	_play("death", 1.0, true)
	battle.dino_sound(kind, "death", global_position)
	await get_tree().create_timer(0.5).timeout
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(self, "position:y", -4.0, 1.6)
	tw.tween_callback(queue_free)


## Out of the egg: grown from small, quickly.
func hatch_in() -> void:
	var full := scale
	scale = full * 0.3
	var tw := create_tween()
	tw.tween_property(self, "scale", full, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	battle.dino_sound(kind, "alert", global_position)
	await tw.finished


## Red haze while it is in a frenzy.
func rage(on: bool) -> void:
	if on and _rage == null:
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.6
		mat.direction = Vector3.UP
		mat.spread = 30.0
		mat.initial_velocity_min = 0.3
		mat.initial_velocity_max = 0.9
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.6
		mat.scale_max = 1.4
		mat.color_ramp = Fx.ramp(Color(0.65, 0.05, 0.04), 0.5)
		_rage = Fx.particles(mat, 20, 1.2)
		_rage.position.y = aim
		add_child(_rage)
	if _rage:
		_rage.emitting = on


func _play(clip: String, pace := 1.0, restart := false) -> void:
	for anim in _anims:
		if anim == null or not anim.has_animation(clip):
			continue
		anim.speed_scale = pace
		if anim.current_animation != clip or restart:
			anim.play(clip, 0.15)
			if restart:
				anim.seek(0.0, true)
	if clip == "attack":
		var t := get_tree().create_timer(0.75)
		t.timeout.connect(func() -> void:
			if is_instance_valid(self) and hp > 0:
				_play("idle"))
