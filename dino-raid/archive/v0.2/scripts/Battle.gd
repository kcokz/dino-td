class_name Battle
extends Node3D
## One battle -- the second validation build (GAME-DESIGN 8). Our ground on the left, in plots; the robots'
## base on the right.
##
## Every so often three cards are offered and the player keeps one, while the battle waits: eggs to plant,
## buildings to put up beside them, help to let loose on the field. The eggs hatch into wild dinosaurs that
## nobody orders -- the player steers them only by what they are, and only with cards: the smell of meat draws
## the hunters, a noise sends the plant-eaters bolting the other way over whatever stands there. Meanwhile the
## robots come for the nests in waves, mustering at their gate first. Break their core to win; lose every nest
## and it is lost.
##
## Every player action goes through act(player, what, data), so a second player can come in by the same door.

const FIELD := Rect2(-36, -16, 72, 32)   # x, z on the ground
const CORE_AT := Vector3(32, 0, 0)
const TURRETS := [Vector3(14, 0, -7), Vector3(14, 0, 7), Vector3(23, 0, 0)]
const FIRST_NEST := Vector2i(1, 2)       # the clutch the battle starts with

const HAND := 4
const OFFER_FIRST := 1.0
const OFFER_EVERY := 20.0
const NOISE_REACH := 16.0
const BLOOD_REACH := 14.0
const BLOOD_SECS := 10.0
const WAVE_FIRST := 45.0
const WAVE_EVERY := 25.0
const WAVE_GROWS := 75.0                 # one more walker to a wave every this many seconds
const LOUD_KEEP := 5.0                   # seconds fighting is remembered (Nest: quiet, hatching)

var clock := 0.0
var over := false
var won := false
var hand: Array = []                     # cards kept, at most HAND
var offer: Array = []                    # three cards while the player chooses; the battle waits
var placing := -1                        # the hand card the player is about to put down, or -1
var garden: Garden
var dinos: Array = []
var robots: Array = []
var nests: Array = []
var scents: Array = []
var calls: Array = []
var clouds: Array = []
var core: Robot
var waves := 0
var hatched := {}                        # species -> how many hatched, for the playtest's account
var taken := {}                          # card -> how often it was kept, likewise
var fallen := {}                         # who died, by kind, likewise

var _owed := 0                           # offers owed at once: a turret fell
var _next_offer := OFFER_FIRST
var _next_wave := WAVE_FIRST
var _gate: Array = []                    # the walkers mustered for the next wave
var _gate_size := 0
var _gate_every := 1.0
var _gate_next := 0.0
var _loud: Array = []                    # [where, when] of fighting lately, oldest first
var _scenes := {}
var _pictures := {}
var _streams := {}
var _heard := {}
var _rig: CameraRig
var _hud: Hud
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D


func _ready() -> void:
	randomize()
	_stage()
	_rig = CameraRig.new()
	_rig.position = Vector3(-1, 0, 5)  # the whole field, our ground clear of the hand
	_rig.process_mode = Node.PROCESS_MODE_ALWAYS  # looking round while the battle waits
	add_child(_rig)
	garden = Garden.new()
	add_child(garden)
	garden.setup()
	for at in TURRETS:
		var t := _add_robot(Robot.Kind.TURRET, at)
		t.died.connect(func(_u: Unit) -> void: _owed += 1)  # an outpost taken: one more offer
	core = _add_robot(Robot.Kind.CORE, CORE_AT)
	core.died.connect(func(_u: Unit) -> void: _end(true))
	_plant("egg_coelophysis", FIRST_NEST)
	_plan_wave()
	_make_marker()
	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(self)


func _physics_process(delta: float) -> void:
	if over:
		return
	clock += delta
	while not _loud.is_empty() and clock - float(_loud[0][1]) > LOUD_KEEP:
		_loud.pop_front()
	if _owed > 0 or clock >= _next_offer:
		if _owed > 0:
			_owed -= 1
		else:
			_next_offer = clock + OFFER_EVERY
		_open_offer()
		return
	_muster()
	if clock >= _next_wave:
		_send_wave()


# -- What the player does ----------------------------------------------------------------------------------

## The one door for a player's action. Returns whether it happened.
func act(_player: int, what: String, data: Dictionary) -> bool:
	if over:
		return false
	match what:
		"choose":
			return _choose(data.get("offer", -1), data.get("replace", -1))
		"play":
			var slot: int = data.slot
			var at: Vector3 = data.at
			if not offer.is_empty() or slot < 0 or slot >= hand.size() or not can_play(hand[slot], at):
				return false
			var card: String = hand[slot]
			hand.remove_at(slot)
			_play(card, at)
			return true
	return false


## Whether `card` can go at `at`: an egg in an empty plot or an empty nest, a building in an empty plot, help
## anywhere on the field.
func can_play(card: String, at: Vector3) -> bool:
	match Cards.ALL[card].type:
		"egg":
			var p := garden.plot_at(at)
			if p == Garden.NOWHERE:
				return false
			var t: Node = garden.things.get(p)
			return t == null or (t is Nest and Unit.standing(t) and (t as Nest).left == 0)
		"building":
			var p := garden.plot_at(at)
			return p != Garden.NOWHERE and not garden.things.has(p)
	return FIELD.has_point(Vector2(at.x, at.z))


## Seconds to the next three cards.
func offer_in() -> float:
	return maxf(0.0, _next_offer - clock)


## A card chosen in the hand: the next click on the field puts it down. Choosing it again lets it be.
func pick(slot: int) -> void:
	if over or not offer.is_empty() or slot < 0 or slot >= hand.size():
		return
	placing = -1 if placing == slot else slot


## One of the cards on offer kept (none, for i < 0); with a full hand it takes the place of hand[replace].
func _choose(i: int, replace: int) -> bool:
	if offer.is_empty():
		return false
	if i >= 0:
		if i >= offer.size():
			return false
		var card: String = offer[i]
		if hand.size() < HAND:
			hand.append(card)
		elif replace >= 0 and replace < hand.size():
			hand[replace] = card
		else:
			return false
		taken[card] = taken.get(card, 0) + 1
	offer = []
	get_tree().paused = false
	return true


func _open_offer() -> void:
	offer = Cards.offer()
	placing = -1
	garden.hide_placing()
	_marker.visible = false
	get_tree().paused = true


func _play(card: String, at: Vector3) -> void:
	match Cards.ALL[card].type:
		"egg":
			_plant(card, garden.plot_at(at))
		"building":
			var p := garden.plot_at(at)
			var b := Building.new()
			add_child(b)
			b.setup(self, card, p, garden.centre(p))
			garden.things[p] = b
			sound("build_done", b.global_position, -2.0)
		_:
			match card:
				"scent":
					var sc := Scent.new()
					add_child(sc)
					sc.setup(self, at, scene("res://common/assets/models/props/drop_food_a.glb"))
					scents.append(sc)
				"noise":
					_noise(at)
				"blood":
					_blood(at)
				"call":
					var c := Call.new()
					add_child(c)
					c.setup(self, at)
					calls.append(c)
				"ash":
					var a := Ash.new()
					add_child(a)
					a.setup(self, at)
					clouds.append(a)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k < KEY_1 + HAND:
			pick(k - KEY_1)
		elif k == KEY_ESCAPE:
			placing = -1
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_RIGHT:
			placing = -1
		elif b.button_index == MOUSE_BUTTON_LEFT and placing >= 0:
			var at: Variant = Geo.ground_point(_rig.camera, b.position)
			if at != null and act(0, "play", {"slot": placing, "at": at}):
				placing = -1


func _process(_delta: float) -> void:
	var at: Variant = null
	if not over:
		at = Geo.ground_point(_rig.camera, get_viewport().get_mouse_position())
	_marker.visible = false
	if placing >= hand.size():
		placing = -1
	if placing < 0 or over:
		garden.hide_placing()
		var t: Node = garden.things.get(garden.plot_at(at)) if at != null else null
		_hud.show_info(t.describe() if t != null and t.has_method("describe") else "")
		return
	_hud.show_info("")
	var card: String = hand[placing]
	var type: String = Cards.ALL[card].type
	if type != "help":
		var ok := at != null and can_play(card, at)
		garden.show_placing(at, type == "building", ok)
		if ok and type == "egg":
			_hud.show_info(_egg_hint(card, garden.plot_at(at)))
		return
	garden.hide_placing()
	if at != null:
		var reach := {"scent": Scent.START, "noise": NOISE_REACH, "blood": BLOOD_REACH, "call": 4.0, "ash": Ash.RADIUS}
		_ring(at, reach[card], can_play(card, at))


## What an egg card would have in plot `p`, while it is being put down: "" when it needs nothing there.
func _egg_hint(card: String, p: Vector2i) -> String:
	var c: Dictionary = Cards.ALL[card]
	var lines := PackedStringArray()
	for need in c.needs:
		if need == "quiet":
			var noisy := loud_near(garden.centre(p), Nest.QUIET_REACH, Nest.QUIET_SECS)
			lines.append("太吵了，会孵得慢" if noisy else "够安静")
		else:
			var what: String = Cards.NEEDS[need]
			lines.append(("挨着%s" % what) if garden.beside(p, need) else ("缺%s，会孵得慢" % what))
	if garden.beside(p, "compost"):
		lines.append("挨着堆肥草堆，会孵得快")
	return "" if lines.is_empty() else "\n".join(lines)


func _ring(at: Vector3, r: float, ok: bool) -> void:
	_marker.visible = true
	_marker.position = at + Vector3.UP * 0.05
	_marker.scale = Vector3.ONE * r
	_marker_mat.albedo_color = Color(0.5, 1.0, 0.5, 0.7) if ok else Color(1.0, 0.35, 0.3, 0.7)


# -- The robots' side --------------------------------------------------------------------------------------

## The next wave mustering at the gate, one walker at a time: how many are coming can be seen there.
func _muster() -> void:
	if _gate.size() < _gate_size and clock >= _gate_next:
		_gate_next = clock + _gate_every
		var r := _add_robot(Robot.Kind.WALKER, _gate_spot(_gate.size()))
		r.waiting = true
		_gate.append(r)


func _send_wave() -> void:
	waves += 1
	for r in _gate:
		if Unit.standing(r):
			(r as Robot).march()
	_gate.clear()
	sound("reload", CORE_AT, 6.0)
	_next_wave = clock + WAVE_EVERY
	_plan_wave()


func _plan_wave() -> void:
	_gate_size = 2 + int(_next_wave / WAVE_GROWS)
	_gate_every = (_next_wave - clock) * 0.8 / _gate_size
	_gate_next = clock


## Where the i-th walker of a wave waits: in ranks either side of the core.
func _gate_spot(i: int) -> Vector3:
	var side := -1.0 if i % 2 == 0 else 1.0
	var k := i / 2
	return CORE_AT + Vector3(-5.5 + (k % 4) * 1.7, 0.0, side * (6.5 + (k / 4) * 1.7))


# -- Who is where ------------------------------------------------------------------------------------------

func nearest_robot(at: Vector3, reach: float) -> Robot:
	var best: Robot = null
	var best_d := INF
	for r: Robot in robots:
		var d := Geo.flat(r.global_position, at) - r.radius
		if d <= reach and d < best_d and r.alive():
			best = r
			best_d = d
	return best


## The nearest living dinosaur within reach, of those `which` accepts.
func nearest_dino(at: Vector3, reach: float, which := Callable()) -> Dino:
	var best: Dino = null
	var best_d := INF
	for d: Dino in dinos:
		if not d.alive() or (which.is_valid() and not which.call(d)):
			continue
		var gap := Geo.flat(d.global_position, at) - d.radius
		if gap <= reach and gap < best_d and Geo.flat(d.global_position, at) > 0.01:
			best = d
			best_d = gap
	return best


func nearest_nest(at: Vector3) -> Nest:
	var best: Nest = null
	var best_d := INF
	for n: Nest in nests:
		var d := Geo.flat(n.global_position, at)
		if d < best_d:
			best = n
			best_d = d
	return best


func scent_for(at: Vector3, smell: float) -> Scent:
	var best: Scent = null
	var best_d := INF
	for sc: Scent in scents:
		var d := Geo.flat(sc.position, at)
		if d <= smell and d < best_d:
			best = sc
			best_d = d
	return best


func call_for(at: Vector3) -> Call:
	var best: Call = null
	var best_d := INF
	for c: Call in calls:
		var d := Geo.flat(c.position, at)
		if d <= Call.REACH and d < best_d:
			best = c
			best_d = d
	return best


func in_ash(at: Vector3) -> bool:
	for a: Ash in clouds:
		if Geo.flat(a.position, at) <= Ash.RADIUS:
			return true
	return false


## Fighting here, now: a shot, a bite. Eggs near it keep still (Nest).
func loud(at: Vector3) -> void:
	_loud.append([at, clock])


## Whether there was fighting within `reach` of `at` in the last `secs` seconds.
func loud_near(at: Vector3, reach: float, secs: float) -> bool:
	for i in range(_loud.size() - 1, -1, -1):
		var e: Array = _loud[i]
		if clock - float(e[1]) > secs:
			return false
		if Geo.flat(e[0], at) <= reach:
			return true
	return false


func clamp_to_field(p: Vector3, r: float) -> Vector3:
	p.x = clampf(p.x, FIELD.position.x + r, FIELD.end.x - r)
	p.z = clampf(p.z, FIELD.position.y + r, FIELD.end.y - r)
	p.y = 0.0
	return p


func unit_gone(u: Unit) -> void:
	dinos.erase(u)
	robots.erase(u)
	var who: String = (u as Dino).kind if u is Dino else Robot.Kind.keys()[(u as Robot).kind].to_lower()
	fallen[who] = fallen.get(who, 0) + 1


func nest_lost(n: Nest) -> void:
	nests.erase(n)
	if nests.is_empty():
		_end(false)


# -- Making things -----------------------------------------------------------------------------------------

## A dinosaur out of its egg at `at`. Without a leader it is the first of its clutch: the biggest, and in the
## alpha's colours where its kind has them.
func born(kind: String, at: Vector3, facing: Vector3, lead: Dino) -> Dino:
	var path := Species.scene_path(kind)
	if lead == null and ResourceLoader.exists(Species.scene_path(kind + "_alpha")):
		path = Species.scene_path(kind + "_alpha")
	var d := Dino.new()
	add_child(d)
	d.setup(self, kind, scene(path), clamp_to_field(at, 0.5), facing)
	d.hatch(lead)
	dinos.append(d)
	hatched[kind] = hatched.get(kind, 0) + 1
	return d


func _plant(card: String, p: Vector2i) -> void:
	var nest := garden.things.get(p) as Nest
	if nest == null:
		nest = Nest.new()
		add_child(nest)
		nest.setup(self, p, garden.centre(p))
		garden.things[p] = nest
		nests.append(nest)
	nest.lay(card)
	sound("pickup", nest.global_position, -4.0)


## A noise: the plant-eaters near it bolt the other way; the hunters come to see.
func _noise(at: Vector3) -> void:
	var dust := Fx.dust_ring(at, NOISE_REACH)
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)
	sound("impact_boom", at, 4.0)
	loud(at)
	for d: Dino in dinos.duplicate():
		if d.alive() and Geo.flat(d.global_position, at) <= NOISE_REACH:
			d.hear(at)


## The smell of blood: every hunter near it goes wild for a while.
func _blood(at: Vector3) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5
	mat.direction = Vector3.UP
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.5
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 2.5
	mat.scale_max = 5.0
	mat.color_ramp = Fx.ramp(Color(0.5, 0.04, 0.03), 0.45)
	var mist := Fx.particles(mat, 80, 3.0)
	mist.one_shot = true
	mist.explosiveness = 0.85
	mist.position = at + Vector3.UP * 0.6
	add_child(mist)
	mist.emitting = true
	mist.finished.connect(mist.queue_free)
	for d: Dino in dinos:
		if d.s.diet == "meat" and Geo.flat(d.global_position, at) <= BLOOD_REACH:
			d.frenzy(BLOOD_SECS)


func _add_robot(kind: Robot.Kind, at: Vector3) -> Robot:
	var r := Robot.new()
	add_child(r)
	r.setup(self, kind, at)
	r.rotation.y = PI * 0.5  # facing our side
	robots.append(r)
	return r


func _stage() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.33, 0.37, 0.24)
	grass.roughness = 1.0
	ground.material_override = grass
	add_child(ground)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.fog_enabled = true
	env.environment.fog_density = 0.0012
	add_child(env)

	# Ferns and cycads round the edge: a clearing, not a board.
	var plants := ["tree_fern_a", "tree_fern_b", "cycad_a", "cycad_b", "araucaria_a", "horsetail_a", "ground_fern_a"]
	for i in 70:
		var at := Vector3(randf_range(-60, 60), 0, randf_range(-40, 40))
		if absf(at.z) < 19.0 and absf(at.x) < 40.0:
			continue
		var p := scene("res://common/assets/models/flora/%s.glb" % plants[randi() % plants.size()]).instantiate() as Node3D
		p.position = at
		p.rotation.y = randf() * TAU
		p.scale = Vector3.ONE * randf_range(0.8, 1.3)
		ArtDress.flora(p)
		add_child(p)


func _make_marker() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 48
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


## The picture on a card: an egg's dinosaur, a building as it stands; none for help (Emblem draws those).
func card_picture(card: String) -> Texture2D:
	if not _pictures.has(card):
		var c: Dictionary = Cards.ALL[card]
		match c.type:
			"egg":
				_pictures[card] = Portraits.take(self, scene(Species.scene_path(c.species)))
			"building":
				_pictures[card] = Portraits.take_node(self, Building.look(card, scene, 7))
			_:
				_pictures[card] = null
	return _pictures[card]


func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func _end(p_won: bool) -> void:
	if over:
		return
	over = true
	won = p_won
	placing = -1
	offer = []
	get_tree().paused = false
	garden.hide_placing()
	sound("tyrannosaurus_roar" if won else "raid_warning", _rig.global_position, 0.0)
	var born_n := 0
	for k in hatched:
		born_n += hatched[k]
	var note := "用了 %d 分 %02d 秒，孵出 %d 只恐龙" % [int(clock) / 60, int(clock) % 60, born_n]
	# What was kept, most first: the playtest asks whether one card is always the one taken.
	var kept: Array = taken.keys()
	kept.sort_custom(func(a: String, b: String) -> bool: return taken[a] > taken[b])
	var names := PackedStringArray()
	for card in kept:
		names.append("%s %d" % [Cards.ALL[card].name, taken[card]])
	if not names.is_empty():
		note += "\n挑过：" + "、".join(names)
	_hud.show_end(won, note)


# -- Effects -----------------------------------------------------------------------------------------------

## A shot's streak of light, there for a blink.
func shot(from: Vector3, to: Vector3, colour: Color) -> void:
	var dir := to - from
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = dir.length()
	beam.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	beam.global_transform = Transform3D(Basis(x, y, x.cross(y)), from + dir * 0.5)
	get_tree().create_timer(0.07).timeout.connect(beam.queue_free)


func sound(name: String, at: Vector3, db := 0.0) -> void:
	var stream := _stream(name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 25.0
	p.max_distance = 200.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


## A dinosaur's own sound for `what` (alert, bite, hurt, death), at most a few times a second per kind --
## a pack does not shout in chorus.
func sound_of(kind: String, what: String, at: Vector3) -> void:
	var key := kind + what
	if clock < _heard.get(key, -1.0):
		return
	_heard[key] = clock + 0.4
	var tries := {
		"alert": ["alert", "roar", "call_1", "snort"],
		"bite": ["bite", "bite_1", "ram"],
		"hurt": ["hurt", "hurt_1"],
		"death": ["death"],
	}
	for t in tries.get(what, [what]):
		if _stream(kind + "_" + t):
			sound(kind + "_" + t, at, -2.0)
			return


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := "res://common/assets/audio/%s.wav" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]
