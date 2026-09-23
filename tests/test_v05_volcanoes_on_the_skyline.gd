# res://tests/test_v05_volcanoes_on_the_skyline.gd
# The volcanoes: where they stand, what they are, and what they are not allowed to do.
#
# Asked for under landform -- "地貌：火山、河流、峭壁" (VERSION.md) -- as part of making the
# valley feel like the age of dinosaurs. They are the far end of the scenery: seen from
# the field, never reached, never in the way of anything.
extends "res://tests/test_base.gd"

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _cones() -> Array:
	return config_node.VOLCANOES["cones"]

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

## The average height of the cone `r` metres out, round the whole circle, so a gully or
## a bump in one direction cannot decide a test about the shape.
func _mean_height(spec: Dictionary, r: float) -> float:
	var total: float = 0.0
	for k in range(36):
		total += Volcano.height_at(spec, config_node, r, TAU * float(k) / 36.0)
	return total / 36.0

# ==============================================================================
# 1. Where they stand
# ==============================================================================

func test_01_no_volcano_shows_through_the_valley() -> void:
	# Wherever the valley has ground, the cone is under it. The foot of a cone reaching
	# in under the valley wall is fine -- that is how it comes to rise from the land beyond
	# the rim rather than sit on a plate -- but a slope of ash poking up through the forest
	# on the valley wall, or through the field, would be a mountain inside the map.
	var t: Dictionary = config_node.TERRAIN
	var field_half: float = float(t["field_half"])
	var outer: float = float(t["outskirts_half"])
	var wobble: float = float(t["rim_noise"])    # how much lower the ground can be than its smooth shape
	var sampled: int = 0
	for spec in _cones():
		var poked: int = 0
		var x: float = -outer
		while x <= outer:
			var z: float = -outer
			while z <= outer:
				var cone: float = Volcano.world_height_at(spec, config_node, x, z)
				if cone > -INF:
					sampled += 1
					if cone > TerrainBuilder.ground_height(x, z, field_half, outer, t, null) - wobble:
						poked += 1
				z += 4.0
			x += 4.0
		assert_eq(poked, 0, "Volcano %d stays under the valley's ground wherever the valley has ground" % int(spec["seed"]))
	assert_gt(sampled, 0, "And at least one foot does reach in under the valley wall, so this checked something")

func test_02_every_volcano_stands_well_above_the_rim() -> void:
	# On the skyline, not behind it: the rim of the valley is what the view looks over.
	var t: Dictionary = config_node.TERRAIN
	var rim_top: float = float(t["rim_rise"]) + float(t["rim_noise"])
	for spec in _cones():
		var lip: float = Volcano.centre_of(spec, config_node).y + _mean_height(spec, float(spec["crater"]))
		assert_gt(lip, rim_top * 2.0, "Volcano %d stands well clear of the valley rim" % int(spec["seed"]))

func test_03_the_camera_can_see_as_far_as_the_volcanoes() -> void:
	var main = _level()
	await wait_frames(2)
	var cam: Camera3D = main.camera
	assert_not_null(cam, "The level has a camera")
	if cam == null:
		return
	for spec in _cones():
		assert_lt(float(spec["distance"]) + float(spec["radius"]), cam.far,
			"All of volcano %d is inside the far plane" % int(spec["seed"]))

func test_04_tilting_the_opening_view_up_finds_one() -> void:
	# The opening camera looks steeply down and sees no horizon. Turning the view is how
	# the player finds the skyline, and the big volcano stands where they are already
	# looking, so tilting up is enough.
	var main = _level()
	await wait_frames(2)
	var rig = main.camera_rig
	assert_not_null(rig, "The level has a camera rig")
	if rig == null:
		return
	var nearest: float = 180.0
	for spec in _cones():
		nearest = minf(nearest, absf(angle_difference(deg_to_rad(float(spec["bearing"])), deg_to_rad(rig.yaw))))
	assert_lt(rad_to_deg(nearest), 30.0, "A volcano stands within 30 degrees of where the opening view looks")

# ==============================================================================
# 2. What they are
# ==============================================================================

func test_05_every_volcano_has_a_crater() -> void:
	for spec in _cones():
		var lip: float = _mean_height(spec, float(spec["crater"]))
		var floor_h: float = Volcano.height_at(spec, config_node, 0.0, 0.0)
		assert_lt(floor_h, lip - 1.0, "Volcano %d has a crater to smoke out of" % int(spec["seed"]))

func test_06_the_flanks_steepen_towards_the_top() -> void:
	# A straight-sided cone reads as a traffic cone at any distance; a stratovolcano's
	# flanks sweep up. Measured as the fall over the same ten metres near the top and near
	# the foot.
	for spec in _cones():
		var crater: float = float(spec["crater"])
		var radius: float = float(spec["radius"])
		var near_top: float = _mean_height(spec, crater + 5.0) - _mean_height(spec, crater + 15.0)
		var near_foot: float = _mean_height(spec, radius - 25.0) - _mean_height(spec, radius - 15.0)
		assert_gt(near_top, near_foot * 2.0, "Volcano %d is steeper up high than down low" % int(spec["seed"]))

func test_07_none_of_it_is_solid() -> void:
	# The ground cover's first rule, and for the same reason: scenery never collides and
	# is never on the grid.
	var main = _level()
	await wait_frames(2)
	var holder: Node = main.get_node_or_null("Volcanoes")
	assert_not_null(holder, "The level raises its volcanoes")
	if holder == null:
		return
	assert_eq(holder.get_child_count(), _cones().size(), "One for every cone Config declares")
	var bodies: int = 0
	for n in holder.find_children("*", "", true, false):
		if n is CollisionObject3D or n is CollisionShape3D:
			bodies += 1
	assert_eq(bodies, 0, "Not one collider in any of them")
	assert_eq(main.terrain_container.get_child_count(), config_node.MAP["default_blocked_cells"].size(),
		"And the hills are still exactly the blocked cells -- the volcanoes are not filed among them")

# ==============================================================================
# 3. The smoke
# ==============================================================================

func test_08_the_smoke_is_already_rising_when_the_level_loads() -> void:
	# A plume that visibly starts when the level loads is a set piece being switched on,
	# not a mountain that has been smoking for a thousand years.
	for spec in _cones():
		var v: Node3D = Volcano.build(spec, config_node)
		_cleanup_nodes.append(v)
		var smoke := v.get_node_or_null("Smoke") as GPUParticles3D
		assert_not_null(smoke, "Volcano %d smokes" % int(spec["seed"]))
		if smoke == null:
			continue
		assert_gte(smoke.preprocess, smoke.lifetime, "Already a whole lifetime of smoke before the first frame")
		assert_almost_eq(smoke.position.y, float(spec["height"]), 0.001, "Out of the top of the cone")

func test_09_the_smoke_is_not_culled_while_it_is_on_screen() -> void:
	# Particles are culled by a box declared up front, not by where they are. Too small a
	# box and the whole plume blinks out whenever the crater itself leaves the screen --
	# which, with the crater near the top of any view that shows it, is most of the time.
	for spec in _cones():
		var v: Node3D = Volcano.build(spec, config_node)
		_cleanup_nodes.append(v)
		var smoke := v.get_node_or_null("Smoke") as GPUParticles3D
		if smoke == null:
			continue
		var pm := smoke.process_material as ParticleProcessMaterial
		var t: float = smoke.lifetime
		# The furthest a puff can get in a lifetime: flying out at the top of its speed,
		# at the edge of its spread, and pushed by the wind (the material's gravity) all
		# the way. Worked out from what the particles are actually given, not copied
		# from the code that sizes the box.
		var fastest: float = pm.initial_velocity_max
		var up: float = fastest * t + 0.5 * maxf(0.0, pm.gravity.y) * t * t
		var side: float = fastest * sin(deg_to_rad(pm.spread)) * t \
			+ 0.5 * Vector2(pm.gravity.x, pm.gravity.z).length() * t * t
		var box: AABB = smoke.visibility_aabb
		assert_gte(box.end.y, up, "The box reaches as high as the plume can rise")
		assert_gte(box.end.x, side, "And as far as it can drift one way")
		assert_gte(box.end.z, side, "And the other")
		assert_lte(box.position.x, -side, "Whichever way the wind is set")
		assert_lte(box.position.z, -side, "On either axis")
