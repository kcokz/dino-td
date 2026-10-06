# res://scripts/fx/ImpactRain.gd
class_name ImpactRain
extends Node3D

## THE END OF THE CRETACEOUS (GAME-DESIGN 7.2, station 4: "高潮：小行星。最后一天，撞击溅出的玻璃小球像雨一样落下；北达科他州
## 的 Tanis 化石点保存的就是撞击之后的那一刻。信标充能和撞击倒计时同时在走"): on a map whose `climax` is an impact
## (MAPS.hell_creek), once the beacon is launched. A streak of fire across the sky, a flash and a long boom with the
## ground shaking -- the impact, thousands of kilometres away -- and some seconds later the molten glass it threw up
## comes down over the valley until the jump, thicker as the charge goes on: each bead a bright point streaking down
## with a hiss, a puff of dust where it lands, scalding what is there -- a dinosaur, the man, a wooden building, a
## little each. A share of them falls round the man; in the cabin he is out of it (CoreCampfire.hero_inside). Gone with
## the run.

var _cfg: Dictionary = {}
var _main: Node = null
var _clock: float = 0.0
var _until_next: float = 0.0
var _rng := RandomNumberGenerator.new()
var _streak: MeshInstance3D = null
var _bead_mesh: CylinderMesh = null
var _bead_mat: StandardMaterial3D = null
## Beads on their way down: [node, from, to, seconds left, seconds in all].
var _falling: Array = []

## The rain begun on `main` (Main, on the beacon's launch), as `cfg` (MAPS.<id>.climax) has it.
static func begin(main: Node, cfg: Dictionary) -> ImpactRain:
	var rain := ImpactRain.new()
	rain.name = "ImpactRain"
	rain._cfg = cfg
	rain._main = main
	main.add_child(rain)
	return rain

func _ready() -> void:
	_rng.randomize()
	_until_next = float(_cfg.get("delay", 8.0))
	# Each bead drawn as what the eye sees of it falling: a short bright streak along its way (a tapered rod along its
	# own Y, turned onto its fall).
	_bead_mesh = CylinderMesh.new()
	var w: float = float(_cfg.get("bead_size", 0.07))
	_bead_mesh.top_radius = w * 0.4
	_bead_mesh.bottom_radius = w
	_bead_mesh.height = float(_cfg.get("streak_length", 1.6))
	_bead_mesh.radial_segments = 5
	_bead_mesh.rings = 1
	_bead_mat = StandardMaterial3D.new()
	_bead_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bead_mat.albedo_color = _cfg.get("colour", Color(1.0, 0.55, 0.15))
	_bead_mat.emission_enabled = true
	_bead_mat.emission = _cfg.get("colour", Color(1.0, 0.55, 0.15))
	_bead_mat.emission_energy_multiplier = 3.0
	# Glowing through the valley's haze, as a fire does.
	_bead_mat.disable_fog = true
	_the_impact()

## The impact, far off: the streak across the sky, the flash, the boom and the shaking, and what he is told.
func _the_impact() -> void:
	var fx = get_node_or_null("/root/Fx")
	var at: Vector3 = _cabin_at()
	if fx and fx.has_method("play_at"):
		fx.play_at("impact_boom", at + Vector3(0.0, 2.0, 0.0))
	# The streak: a long thin bright bar high over the valley's west, fading.
	_streak = MeshInstance3D.new()
	_streak.name = "Streak"
	var bar := BoxMesh.new()
	bar.size = Vector3(2.0, 2.0, 200.0)
	_streak.mesh = bar
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.6, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.4)
	mat.emission_energy_multiplier = 6.0
	mat.disable_fog = true
	_streak.material_override = mat
	add_child(_streak)
	# Where the view looks, far off over the valley's rim and up: what the game's camera sees of the sky, low at the top of
	# the screen -- across it, falling to the horizon.
	# High in the sky ahead of where the view looks, across it and falling -- seen by a view tilted up to the sky; the
	# game's own looks down at the valley and sees none of it, so the light of the impact fills the screen a moment
	# (_flash_the_screen) and the view shakes (_shake_left).
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var ahead := Vector3(0.0, 0.0, -1.0)
	var side := Vector3(1.0, 0.0, 0.0)
	if cam != null:
		var f: Vector3 = -cam.global_transform.basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			ahead = Vector3(f.x, 0.0, f.z).normalized()
		side = Vector3(-ahead.z, 0.0, ahead.x)
	var mid: Vector3 = at + ahead * float(_cfg.get("streak_far", 150.0)) + Vector3(0.0, float(_cfg.get("streak_high", 60.0)), 0.0)
	_streak.global_position = mid
	_streak.look_at(mid + side * 100.0 + Vector3(0.0, -35.0, 0.0), Vector3.UP)
	_flash_the_screen()
	_shake_left = float(_cfg.get("shake_seconds", 1.6))
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		var tw := create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, float(_cfg.get("streak_seconds", 4.0)))
		tw.tween_callback(func(): if is_instance_valid(_streak): _streak.visible = false)
	else:
		_streak.visible = false
	var sun: DirectionalLight3D = _main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D if _main else null
	if sun != null and is_inside_tree() and DisplayServer.get_name() != "headless":
		var e: float = sun.light_energy
		var flash := create_tween()
		flash.tween_property(sun, "light_energy", e * 2.2, 0.15)
		flash.tween_property(sun, "light_energy", e, 1.2)
	var rig = _main.get("camera_rig") if _main else null
	if rig != null and rig.has_method("shake"):
		rig.shake(float(_cfg.get("shake", 0.35)), float(_cfg.get("shake_seconds", 2.0)))
	var hud = _main.get("hud") if _main else null
	if hud != null and hud.has_method("show_hint"):
		hud.show_hint(tr("HINT_IMPACT"), UiTheme.toast_seconds("long"), "warning")

func _process(delta: float) -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or bool(gs.is_game_over) or not gs.is_beacon_launched():
		_shake(0.0)
		queue_free()
		return
	_clock += delta
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		_shake(_shake_left / maxf(0.01, float(_cfg.get("shake_seconds", 1.6))))
	_fall(delta)
	_until_next -= delta
	while _until_next <= 0.0:
		_drop_one()
		var rate: float = lerpf(float(_cfg.get("rate_from", 1.5)), float(_cfg.get("rate_to", 6.0)), _charged())
		_until_next += 1.0 / maxf(0.1, rate)

## How far the charge has got, 0..1: the beads come thicker as it goes on.
func _charged() -> float:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("beacon_seconds_left"):
		return 0.0
	var total: float = float(gs.map_data().get("beacon", {}).get("charge_seconds", 0.0))
	return clampf(1.0 - float(gs.beacon_seconds_left()) / maxf(1.0, total), 0.0, 1.0)

## One bead let go: round the man (its share of them, near_man_share), else anywhere over the field.
func drop_at(to: Vector3) -> void:
	var bead := MeshInstance3D.new()
	bead.mesh = _bead_mesh
	bead.material_override = _bead_mat
	bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bead)
	var slant: float = float(_cfg.get("slant", 0.35))
	var height: float = float(_cfg.get("fall_height", 45.0))
	var from: Vector3 = to + Vector3(height * slant, height, -height * slant * 0.5)
	bead.global_position = from
	# Its rod along its fall: its own Y onto the way down.
	var down: Vector3 = (to - from).normalized()
	bead.global_transform.basis = Basis(Quaternion(Vector3.UP, -down))
	var secs: float = float(_cfg.get("fall_seconds", 0.7))
	_falling.append([bead, from, to, secs, secs])

func _drop_one() -> void:
	var hero = _main.get("hero") if _main else null
	var half: float = float(_cfg.get("field_half", 40.0))
	var to: Vector3
	if hero != null and is_instance_valid(hero) and _rng.randf() < float(_cfg.get("near_man_share", 0.3)):
		var r: float = float(_cfg.get("near_man", 6.0)) * sqrt(_rng.randf())
		var a: float = _rng.randf() * TAU
		to = (hero as Node3D).global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	else:
		var c: Vector3 = _cabin_at()
		to = Vector3(c.x + _rng.randf_range(-half, half), 0.0, c.z + _rng.randf_range(-half, half))
	to.y = 0.0
	drop_at(to)

func _fall(delta: float) -> void:
	for i in range(_falling.size() - 1, -1, -1):
		var f: Array = _falling[i]
		var bead: MeshInstance3D = f[0]
		f[3] = float(f[3]) - delta
		var t: float = 1.0 - clampf(float(f[3]) / float(f[4]), 0.0, 1.0)
		if is_instance_valid(bead):
			bead.global_position = (f[1] as Vector3).lerp(f[2], t)
		if float(f[3]) <= 0.0:
			_falling.remove_at(i)
			if is_instance_valid(bead):
				bead.queue_free()
			land(f[2])

## A bead comes down at `at`: what is within its reach is scalded -- the dinosaurs, the man out in the open, a building a
## little -- and a puff of dust and a hiss where it fell.
func land(at: Vector3) -> void:
	var reach: float = float(_cfg.get("radius", 0.8))
	var dmg: float = float(_cfg.get("damage", 2.0))
	var flat := Vector2(at.x, at.z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not (d is Node3D) or not d.has_method("take_damage") or bool(d.get("is_dead")):
			continue
		var p: Vector3 = (d as Node3D).global_position
		if flat.distance_to(Vector2(p.x, p.z)) <= reach:
			d.take_damage(dmg)
	var hero = _main.get("hero") if _main else null
	if hero != null and is_instance_valid(hero) and not _sheltered():
		var hp: Vector3 = (hero as Node3D).global_position
		if flat.distance_to(Vector2(hp.x, hp.z)) <= reach and hero.has_method("take_damage"):
			hero.take_damage(dmg, false)
	var hit_b: float = float(_cfg.get("building_damage", 1.0))
	if hit_b > 0.0:
		for b in get_tree().get_nodes_in_group("buildings"):
			if not (b is Node3D) or not b.has_method("take_damage") or String(b.get("building_type")) == "core":
				continue
			var bp: Vector3 = (b as Node3D).global_position
			if flat.distance_to(Vector2(bp.x, bp.z)) <= reach + 0.5:
				b.take_damage(hit_b)
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("debris"):
		fx.debris(at, _cfg.get("colour", Color(1.0, 0.55, 0.15)), 4)
	_flash_at(at)
	if fx and fx.has_method("play_at") and _rng.randf() < float(_cfg.get("heard_share", 0.35)):
		fx.play_at("impact_bead", at)

## Where a bead lands, a quick hot glow on the ground round it -- seen from where the game looks -- and the bead itself
## left there a moment, glowing and going dull (`ember_seconds`).
func _flash_at(at: Vector3) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var ember := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = float(_cfg.get("bead_size", 0.09)) * 1.3
	ball.height = ball.radius * 2.0
	ball.radial_segments = 6
	ball.rings = 3
	ember.mesh = ball
	var mat: StandardMaterial3D = _bead_mat.duplicate()
	ember.material_override = mat
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ember)
	ember.global_position = at + Vector3(0.0, ball.radius * 0.6, 0.0)
	var cool := ember.create_tween()
	cool.tween_property(mat, "emission_energy_multiplier", 0.0, float(_cfg.get("ember_seconds", 2.5)))
	cool.parallel().tween_property(mat, "albedo_color", Color(0.15, 0.1, 0.08), float(_cfg.get("ember_seconds", 2.5)))
	cool.tween_callback(ember.queue_free)
	var glow := OmniLight3D.new()
	glow.light_color = _cfg.get("colour", Color(1.0, 0.55, 0.15))
	glow.omni_range = float(_cfg.get("flash_range", 2.5))
	glow.light_energy = float(_cfg.get("flash_energy", 3.0))
	glow.shadow_enabled = false
	add_child(glow)
	glow.global_position = at + Vector3(0.0, 0.4, 0.0)
	var tw := glow.create_tween()
	tw.tween_property(glow, "light_energy", 0.0, float(_cfg.get("flash_seconds", 0.35)))
	tw.tween_callback(glow.queue_free)

## Seconds of the ground shaking still to come (the view shaken, _shake).
var _shake_left: float = 0.0

## The view shaken by the impact, `amount` of the way from its worst to still: the camera's own offsets jolted, so its
## rig is left where it is.
func _shake(amount: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var most: float = float(_cfg.get("shake", 0.35)) * amount
	cam.h_offset = _rng.randf_range(-most, most)
	cam.v_offset = _rng.randf_range(-most, most)

## The light of the impact filling the screen a moment, and going: what the game's view, looking down at the valley,
## sees of a fireball in a sky it does not show.
func _flash_the_screen() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.name = "ImpactFlash"
	layer.layer = 50
	add_child(layer)
	var sheet := ColorRect.new()
	sheet.color = _cfg.get("flash_colour", Color(1.0, 0.86, 0.66, 0.75))
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sheet)
	var tw := sheet.create_tween()
	tw.tween_property(sheet, "color:a", 0.0, float(_cfg.get("flash_screen_seconds", 1.6))).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)

## Whether the man is in the cabin, out of it.
func _sheltered() -> bool:
	var core = _main.get("current_core") if _main else null
	return core != null and is_instance_valid(core) and bool(core.get("hero_inside"))

func _cabin_at() -> Vector3:
	var core = _main.get("current_core") if _main else null
	return (core as Node3D).global_position if (core != null and is_instance_valid(core)) else Vector3.ZERO
