# res://tests/test_v07_the_dark_and_the_ram.gd
# The player's two bug reports of 2026-10-04:
#   20:14 "人站在火周围，植龙不敢靠近，但是箭塔就能看到植龙，所以就可以白嫖植龙，一个个点杀，这个是个漏洞"
#   20:18 "有个恐龙离船舱很远，但有进攻动作，这是撞击吗，撞击需要真的撞的动作，而且要贴着船舱，不然像隔山打牛"
#
# THE DARK: a phytosaur kept from what it wants by a light waits just outside its edge, in the dark (PROWL.edge_out) --
# and out of every light, where they overlap -- so what sees only by firelight, a tower at night, does not see it there.
# Its eyes are what is seen of it.
#
# THE RAM: at the cabin an animal rams from where the blow lands -- its middle out from the hull (Config.hull_outline,
# not the box, whose corners are air) as far as its snout reaches at the height of its ram (Dino.ram_front, read off
# the clip), less DINO_AI.ram_into -- and from nowhere further off. At the height of the blow the tip of its head is at
# the hull.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	Dino.clear_all_attack_slots()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	await nav_settled(main)
	return main

func _set_clock(part: String, into: float = 10.0) -> void:
	game_state_node.day_clock = float(config_node.DAY["parts"][part]) + into
	game_state_node._run_the_day(0.0)

func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## A `species` put down at `at` making for the cabin, its body still (the test drives it).
func _animal(main: Node, species: String, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	d.setup(species)
	if "home" in d:
		d.home = at
	d.waypoints = [at, main.current_core.global_position] as Array[Vector3]
	d.position = at
	main.dinos_container.add_child(d)
	d.setup(species)
	d.max_hp = 9999.0
	d.current_hp = 9999.0
	d.set_physics_process(false)
	return d

## `d` thinking and walking for up to `seconds`, a physics frame at a time -- until `until` says so, if given.
func _drive(d: Node, seconds: float, until: Callable = Callable()) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds and is_instance_valid(d):
		d.advance_towards_waypoint(dt)
		t += dt
		if until.is_valid() and bool(until.call()):
			return
		await tree.physics_frame

## How far the tip of `d`'s head is from the cabin's hull, on the ground (inside it, less than nought) -- the bone at its
## tip (Head_end) and as much of its body as reaches past that.
func _tip_from_hull(d: Node, cabin: Node3D) -> float:
	var sk: Skeleton3D = d.find_child("Body", false, false).find_children("*", "Skeleton3D", true, false)[0]
	var bone: int = sk.find_bone("Head_end")
	var to_me: Transform3D = d.global_transform.affine_inverse() * sk.global_transform
	var past: float = float(d.front_reach()) + (to_me * sk.get_bone_global_rest(bone).origin).z
	var ahead: Vector3 = -d.global_transform.basis.z.normalized()
	var tip: Vector3 = sk.global_transform * sk.get_bone_global_pose(bone).origin + ahead * past
	var c: Vector3 = cabin.global_position
	var on: Vector3 = d._hull_point(cabin, tip)
	var inside: bool = Geometry2D.is_point_in_polygon(Vector2(tip.x - c.x, tip.z - c.z), config_node.hull_outline("core"))
	return _flat_gap(tip, on) * (-1.0 if inside else 1.0)

# ==============================================================================
# The dark
# ==============================================================================

func test_01_kept_off_by_his_torch_it_waits_in_the_dark_and_no_tower_sees_it() -> void:
	var main = await _level()
	_set_clock("night")
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = main.current_core.global_position + Vector3(-8.0, 0.0, 8.0)
	stock_everything()
	var bow = main.build_system.place_at("bow_tower", main.grid_manager.world_to_build_cell(hero.global_position + Vector3(4.0, 0.0, 0.0)),
		main.buildings_container, true)
	assert_not_null(bow, "(a bow tower beside him)")
	bow.complete_construction()
	bow.set_ammo("arrow_wood")
	bow.load_from_stock()
	var d = _animal(main, "phytosaur", hero.global_position + Vector3(-2.5, 0.0, 0.0))
	d._think()
	assert_eq(d.current_target, hero, "(in the dark it goes for him)")
	assert_true(hero.light_torch(), "(his torch lit)")
	var torch: float = float(hero.torch_light())
	await _drive(d, 5.0)
	assert_true(d.is_wary(), "It keeps off his light")
	# Waiting there, pacing along the edge as it does: in the dark all the while, and the tower beside him blind to it.
	var lit_for: float = 0.0
	var seen: bool = false
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	for i in int(8.0 / dt):
		d.advance_towards_waypoint(dt)
		if not ProwlerDino.light_over(tree, d.global_position).is_empty():
			lit_for += dt
		seen = seen or bool(bow.can_see(d)) or bow.target_in_reach() == d
		if i % 4 == 0:
			await tree.physics_frame
	assert_almost_eq(lit_for, 0.0, 0.05, "Waiting at his light it stands in the dark, outside its edge (%.2f s lit)" % lit_for)
	assert_gt(_flat_gap(d.global_position, hero.global_position), torch, "out past the light's edge")
	assert_lt(_flat_gap(d.global_position, hero.global_position), torch + float(config_node.PROWL["edge_out"]) + 1.2,
		"but at it, not off in the dark")
	assert_false(seen, "A tower at night does not see it there (TOWERS.dark_parts): no shooting it for nothing")
	d._face_now(hero.global_position)
	d._shine()
	assert_gt(float(d.eye_shine), 0.9, "Its eyes are what is seen of it")

func test_02_where_lights_overlap_it_waits_out_of_them_all() -> void:
	# His torch by the campfire: the torch's edge is inside the fire's light.
	var main = await _level()
	_set_clock("night")
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	stock_everything()
	var fire = main.build_system.place_at("campfire", main.grid_manager.world_to_build_cell(main.current_core.door_outside() + Vector3(-3.0, 0.0, 5.0)),
		main.buildings_container)
	fire._tend(99.0)
	var light: float = float(fire.light_radius())
	assert_gt(light, 0.0, "(the fire burning)")
	hero.global_position = fire.global_position + Vector3(light * 0.5, 0.0, 0.0)
	assert_true(hero.light_torch(), "(his torch lit by the fire)")
	var torch: float = float(hero.torch_light())
	var d = _animal(main, "phytosaur", hero.global_position + Vector3(light + torch + 4.0, 0.0, 0.0))
	var out: float = float(config_node.PROWL["edge_out"])
	var steps: int = 16
	for k in steps:
		var a: float = TAU * float(k) / float(steps)
		var spot: Vector3 = d._in_the_dark(hero.global_position + Vector3(cos(a), 0.0, sin(a)) * (torch + out))
		assert_true(ProwlerDino.light_over(tree, spot, out - 0.02).is_empty(),
			"Where it would wait round his torch, %d degrees round, is out of both lights (%s)" % [int(rad_to_deg(a)), spot])

# ==============================================================================
# The ram
# ==============================================================================

func test_03_the_ram_s_reach_is_read_off_its_clip() -> void:
	# The clip carries the head past where it rests: measured here by skinning the body by hand at each moment of the
	# clip, against what the animal reads off the clip's keys.
	var main = await _level()
	var clip: String = String(config_node.ANIMATIONS["dino_batter"])
	for species in ["desmatosuchus", "coelophysis", "phytosaur"]:
		var d = _animal(main, species, main.current_core.global_position + Vector3(20.0, 0.0, 20.0))
		await wait_frames(2)
		var ap: AnimationPlayer = d.animator.animation_player
		var anim: Animation = d.animator.animation_for(clip)
		assert_not_null(anim, "%s has a ram to read" % species)
		if anim == null:
			continue
		ap.play(ap.find_animation(anim))
		var furthest: float = -INF
		for k in 25:
			ap.seek(anim.length * float(k) / 24.0, true)
			furthest = maxf(furthest, _skinned_front(d))
		assert_gt(float(d.ram_front()), float(d.front_reach()) + 0.05, "%s: its ram carries its head past where it rests" % species)
		assert_almost_eq(float(d.ram_front()), furthest, 0.06,
			"%s: as far as its body reaches at the height of its ram (%.2f, skinned %.2f)" % [species, float(d.ram_front()), furthest])

## How far ahead of its middle `d`'s body reaches as it is posed now, each vertex skinned by hand (the renderer's skinning
## is not to be had in a headless run).
func _skinned_front(d: Node3D) -> float:
	var inv: Transform3D = d.global_transform.affine_inverse()
	var best: float = -INF
	for m in d.find_child("Body", false, false).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or String(mi.name).begins_with("Glint"):
			continue
		var sk: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var mats: Array = []
		if sk != null and mi.skin != null:
			for i in mi.skin.get_bind_count():
				var b: int = mi.skin.get_bind_bone(i)
				if b < 0:
					b = sk.find_bone(mi.skin.get_bind_name(i))
				mats.append(sk.get_bone_global_pose(b) * mi.skin.get_bind_pose(i))
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			var per: int = (bones as PackedInt32Array).size() / verts.size() if (not mats.is_empty() and bones != null) else 0
			for vi in verts.size():
				var world: Vector3
				if per > 0:
					var acc := Vector3.ZERO
					for k in per:
						var w: float = weights[vi * per + k]
						if w > 0.0:
							acc += (mats[bones[vi * per + k]] * verts[vi]) * w
					world = sk.global_transform * acc
				else:
					world = mi.global_transform * verts[vi]
				best = maxf(best, -(inv * world).z)
	return best

func test_04_where_the_report_had_it_it_does_not_ram_it_goes_on_to_where_the_blow_lands() -> void:
	# The report's Desmatosuchus, in a raid by day: at the cabin's north-east corner, 2.4 m off the box's corner, ramming.
	var main = await _level()
	_set_clock("day")
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(0.0, 0.0, 16.0)
	var cabin: Node3D = main.current_core
	var d = _animal(main, "desmatosuchus", cabin.global_position + Vector3(5.14, 0.0, -3.29))
	await wait_frames(2)
	d._face_now(d._bite_point(cabin))
	assert_false(d._target_in_reach(cabin), "From where the report had it, the hull is out of its reach: it does not ram the air")
	await _drive(d, 12.0, func() -> bool: return int(d.mode) == int(Dino.Mode.ATTACK))
	assert_eq(int(d.mode), int(Dino.Mode.ATTACK), "It goes on, and rams")
	var off: float = _flat_gap(d.global_position, d._hull_point(cabin, d.global_position)) - float(d._ram_stand())
	var ai: Dictionary = config_node.DINO_AI
	assert_lte(off, float(ai["ram_short"]), "from where the blow lands on the hull: no further off (%+.2f m)" % off)
	assert_gte(off, -float(ai["ram_near"]), "nor nearer, its head through the wall (%+.2f m)" % off)

func test_05_at_the_height_of_the_blow_the_tip_of_its_head_is_at_the_hull() -> void:
	# Round the cabin -- a long wall, an end, a corner, where the box's corner is air -- each that rams it, at the
	# height of the blow, has the tip of its head at the hull: not short of it, not through it.
	var main = await _level()
	_set_clock("day")
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(0.0, 0.0, 16.0)
	var cabin: Node3D = main.current_core
	var into: float = float(config_node.DINO_AI["ram_into"])
	var cast: Array = [["desmatosuchus", Vector3(9.0, 0.0, -5.0), "at the north-east corner"],
		["coelophysis", Vector3(-1.0, 0.0, -9.0), "at the north wall"],
		["postosuchus", Vector3(11.0, 0.0, 0.5), "at the east end"]]
	for row in cast:
		var d = _animal(main, String(row[0]), cabin.global_position + (row[1] as Vector3))
		_cleanup_nodes.append(d)
		await _drive(d, 16.0, func() -> bool: return int(d.mode) == int(Dino.Mode.ATTACK))
		assert_eq(int(d.mode), int(Dino.Mode.ATTACK), "%s rams the cabin %s" % [row[0], row[2]])
		# Turned to aim the blow (ram_hook), then a ram and a half, the gap from the tip of its head to the hull at each
		# moment.
		await _drive(d, 0.5)
		var nearest: float = INF
		var length: float = float(d.animator.animation_player.current_animation_length)
		var since: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < int(maxf(1.0, length) * 1500.0):
			nearest = minf(nearest, _tip_from_hull(d, cabin))
			await tree.process_frame
		assert_lt(nearest, 0.08, "%s %s: at the height of the blow the tip of its head is at the hull (%.2f m off)" % [row[0], row[2], nearest])
		assert_gt(nearest, -(into + 0.15), "%s %s: and not through it (%.2f m in)" % [row[0], row[2], -nearest])
		d.queue_free()
