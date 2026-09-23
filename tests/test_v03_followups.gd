# res://tests/test_v03_followups.gd
# v0.3 follow-ups, all three of them about how a building reads and what it does:
# 1. Build time is felt: the curve is superlinear, so price differences bite.
#    (The curve itself is asserted in test_v02_followups; here we only check that
#    a placed building inherits it.)
# 2. Size says what a thing is: stakes are wide and low, a turret narrow and tall.
# 3. Stakes bite: getting past a fence costs health, so it is a weapon and not
#    only a delay.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var wall_script: GDScript = null
var tower_script: GDScript = null
var dino_script: GDScript = null
var hero_script: GDScript = null
var option_panel_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	wall_script = _load_script("res://scripts/entities/Wall.gd")
	tower_script = _load_script("res://scripts/entities/Tower.gd")
	dino_script = _load_script("res://scripts/entities/Dino.gd")
	hero_script = _load_script("res://scripts/entities/Hero.gd")
	option_panel_script = _load_script("res://scripts/ui/OptionPanel.gd")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	# v0.4 gates the turret behind a blueprint and stone behind a pick. This suite is
	# about something else, so it starts with the cabin's work already done rather
	# than walking that chain in every test.
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _load_script(path: String) -> GDScript:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is GDScript:
			return res
	return null

func _spawn(script: GDScript, pos: Vector3 = Vector3.ZERO) -> Node:
	var n = script.new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = pos
	return n

## A stake that has been finished, and so is armed.
func _stake(pos: Vector3 = Vector3.ZERO) -> Node:
	var w = _spawn(wall_script, pos)
	w.complete_construction()
	return w

## A live raptor. Parked far away by default, so it is only ever in reach of a
## stake when a test deliberately puts it there.
func _raptor(pos: Vector3 = Vector3(50.0, 0.0, 50.0)) -> Node:
	var d = _spawn(dino_script, pos)
	d.setup("raptor")
	return d

func _wall_cfg(key: String, fallback: float) -> float:
	return float(config_node.BUILDINGS["wall"].get(key, fallback))

# ==============================================================================
# 1. Size: stakes wide and low, turret narrow and tall
# ==============================================================================

func test_01_a_turret_is_taller_than_a_stake_and_a_stake_is_wider() -> void:
	# The pair was the wrong way round: stakes towered over a squat turret, so the
	# thing that matters least on the field looked like the thing that matters most.
	var stake_w: float = config_node.get_building_footprint("wall")
	var tower_w: float = config_node.get_building_footprint("tower")
	var stake_h: float = config_node.get_building_height("wall")
	var tower_h: float = config_node.get_building_height("tower")

	assert_lt(stake_w, tower_w, "One stake is a small thing beside a turret")
	assert_gt(tower_h, stake_h, "A turret stands taller than a stake")
	assert_gt(tower_h, config_node.BUILDING_HEIGHT_DEFAULT,
		"A turret is taller than an ordinary shed, not merely equal to one")
	assert_lt(stake_h, config_node.BUILDING_HEIGHT_DEFAULT,
		"A stake is something you look over, not a building")

func test_02_nothing_seals_a_tile_on_its_own_any_more() -> void:
	# Height is free; width is not. Making the turret tall must not have quietly
	# turned it into a barrier able to seal the Hero in.
	assert_false(config_node.is_barrier_building("tower"),
		"A turret leaves a lane, so a ring of them is not a cage")
	# Stakes were the one exception, and are not any more: a stake is 0.62m wide, and
	# what closes a way is a RUN of them rather than the first one placed.
	assert_false(config_node.is_barrier_building("wall"),
		"Nor does one stake, which is 0.62m of a 2m tile")

	for b_type in config_node.BUILDABLE_TYPES:
		var lane: float = config_node.TILE_SIZE - config_node.get_building_footprint(b_type)
		assert_gt(lane, float(config_node.HERO.get("width", 0.8)),
			"The gap beside a %s is wider than the Hero" % b_type)

func test_03_height_and_style_are_declared_in_config_not_in_the_mesh() -> void:
	for b_type in config_node.BUILDABLE_TYPES:
		assert_gt(config_node.get_building_height(b_type), 0.0,
			"%s resolves to a real height" % b_type)
	assert_eq(config_node.get_building_mesh_style("wall"), "spikes",
		"Stakes are drawn as stakes")
	assert_eq(config_node.get_building_mesh_style("tower"), "box",
		"Anything that does not ask for a style gets the plain block")
	assert_eq(config_node.get_building_mesh_style("no_such_building"), "box",
		"An unknown type falls back rather than failing")

func test_04_a_stake_is_one_small_sharpened_cone() -> void:
	# What one price buys is one stake, and what the player sees is one stake. It has
	# been three cones, five at a corner, and a tile-wide sharpened slab before now.
	#
	# Asked in terms of SHAPE rather than of which Mesh class drew it, since the stake
	# became a model (tools/generate_props.py): one mesh, as wide and as tall as Config
	# declares, standing on the ground, and narrow at the top -- sharpened.
	var stake = _stake()
	await wait_frames(1)

	var body = stake.find_child("Body", false, false)
	assert_not_null(body, "Stakes are drawn in their own holder")
	var meshes: Array[MeshInstance3D] = body_meshes(stake)
	assert_eq(meshes.size(), 1, "One stake, one piece")
	if meshes.is_empty():
		return

	var h: float = config_node.get_building_height("wall")
	var d: float = config_node.get_spike_diameter("wall")
	var bounds: AABB = VisualLibrary.visual_bounds(body)
	assert_lte(bounds.size.x, d + 0.01, "No wider than Config declares")
	assert_lte(bounds.size.z, d + 0.01, "In either direction")
	assert_almost_eq(bounds.size.y, h, 0.02, "As tall as the declared height")
	assert_almost_eq(bounds.position.y, 0.0, 0.01, "Standing on the ground, not in it")
	assert_lt(top_to_base_width(meshes[0]), 0.35, "Sharpened: its top is a fraction of its width")
	assert_lt(d, float(config_node.TILE_SIZE) * 0.5, "And small")

func test_04b_the_ghost_is_the_same_shape_as_the_thing_it_promises() -> void:
	# A cube standing in for a stake told the player nothing about what was going down,
	# and a ghost that drew a different number of cones from the placed stake was worse:
	# it promised the wrong shape rather than no shape. Both are one call now -- for every
	# buildable, whether it is one piece like a stake or two like the turret, whose head
	# turns on its stand.
	for b_type in config_node.BUILDABLE_TYPES:
		var type_id := String(b_type)
		var body: Node3D = Building.make_body(type_id)
		var meshes: Array[MeshInstance3D] = body_meshes(body)
		assert_gt(meshes.size(), 0, "%s ghost is drawn as something" % type_id)

		# The same model the placed building is drawn with -- the very same Mesh, piece
		# for piece.
		var placed: Node = null
		match type_id:
			"wall":
				placed = _stake(Vector3(30.0, 0.0, 0.0))
			"tower":
				placed = _spawn(tower_script, Vector3(34.0, 0.0, 0.0))
				placed.complete_construction()
		assert_not_null(placed, "This test knows how to place a %s" % type_id)
		if placed == null:
			body.free()
			continue
		var real: Array[MeshInstance3D] = body_meshes(placed)
		assert_eq(meshes.size(), real.size(), "%s ghost has as many pieces as the real one" % type_id)
		for i in range(mini(meshes.size(), real.size())):
			assert_eq(meshes[i].mesh, real[i].mesh, "%s ghost piece %d is the real one's" % [type_id, i])

		if config_node.get_building_mesh_style(type_id) == "spikes":
			assert_eq(meshes.size(), 1, "One stake, one piece")
			if not meshes.is_empty():
				assert_lt(top_to_base_width(meshes[0]), 0.35, "%s ghost is sharpened too" % type_id)
		body.free()

func test_05_a_turret_is_drawn_inside_its_declared_size() -> void:
	# It was one block of exactly the declared size. It is a model now
	# (tools/generate_props.py, sentry), fitted INTO that size: no wider than the ground it
	# occupies, as tall as declared, standing on the ground.
	var tower = _spawn(tower_script)
	tower.complete_construction()
	await wait_frames(1)

	var body = tower.find_child("Body", false, false)
	assert_not_null(body, "The turret has a body")
	if body == null:
		return
	var bounds: AABB = VisualLibrary.visual_bounds(body)
	var footprint: float = config_node.get_building_footprint("tower")
	assert_lte(bounds.size.x, footprint + 0.01, "No wider than its footprint")
	assert_lte(bounds.size.z, footprint + 0.01, "In either direction")
	assert_almost_eq(bounds.size.y, config_node.get_building_height("tower"), 0.05, "As tall as declared")
	assert_almost_eq(bounds.position.y, 0.0, 0.01, "Standing on the ground, not in it")

func test_06_labels_and_bars_sit_above_the_building_they_belong_to() -> void:
	# A fixed label height reads as floating over a low building and buried in a
	# tall one, so both must follow the building's own height.
	var stake = _stake()
	var tower = _spawn(tower_script, Vector3(20.0, 0.0, 0.0))
	await wait_frames(1)

	for b in [stake, tower]:
		var h: float = config_node.get_building_height(b.building_type)
		assert_gt(b.label_3d.position.y, h, "%s's name clears its own roof" % b.building_type)
		assert_gt(b.status_bar.position.y, h, "%s's bar clears its own roof" % b.building_type)
	assert_gt(tower.label_3d.position.y, stake.label_3d.position.y,
		"The taller building carries its name higher")

# ==============================================================================
# 2. Stakes bite
# ==============================================================================

func test_07_stakes_declare_a_bite_and_agree_with_config_about_it() -> void:
	var stake = _stake()
	await wait_frames(1)

	assert_gt(stake.contact_damage, 0.0, "Stakes are sharpened")
	assert_almost_eq(stake.contact_dps(), config_node.get_contact_dps("wall"), 0.0001,
		"The stake and the build menu quote the same figure")
	assert_almost_eq(stake.contact_dps(), _wall_cfg("contact_damage", 0.0) / _wall_cfg("contact_tick", 1.0),
		0.0001, "Damage per second is damage per tick over the tick")
	assert_eq(config_node.get_contact_dps("tower"), 0.0,
		"A building that is not sharpened bites nothing")
	assert_eq(config_node.get_contact_dps("no_such_building"), 0.0,
		"An unknown type is answered rather than crashed on")

func test_08_the_bite_reaches_where_a_dinosaur_actually_stands() -> void:
	# A dinosaur attacking a building stops at the inner attack ring, so the spikes have
	# to reach that ring or the fence is decorative.
	#
	# Against THE STAKE'S OWN ring, not the global constant. That constant is 1.6m, which
	# is where an attacker stood back when every building filled a 2m tile -- 1.3m clear
	# of a 0.62m cone, and the reason a raid appeared to stop short of the fence and do
	# nothing. Both numbers come from the building's own size now.
	var stake = _stake()
	await wait_frames(1)
	var ring: float = float(config_node.get_attack_slot_radius("wall", false))
	assert_lt(ring, float(config_node.DINO_ATTACK_SLOT_RADIUS_INNER),
		"A stake is small, so its attackers stand closer than the old fixed ring")
	assert_gte(stake.contact_range, ring,
		"Whatever is chewing on the stakes is within reach of them")
	assert_lt(stake.contact_range, float(config_node.BUILDINGS["tower"].get("range", 5.0)),
		"But it is contact, not a turret's field of fire")

func test_09_a_dinosaur_against_the_stakes_takes_damage() -> void:
	var stake = _stake()
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	var before: float = dino.current_hp
	var hits: int = stake.damage_touching_dinos()
	assert_eq(hits, 1, "The dinosaur pressed against the stakes is caught by them")
	assert_almost_eq(dino.current_hp, before - stake.contact_damage, 0.0001,
		"And loses exactly one tick of health")

func test_10_a_dinosaur_clear_of_the_stakes_takes_none() -> void:
	var stake = _stake()
	var dino = _raptor(Vector3(stake.contact_range * 2.0, 0.0, 0.0))
	await wait_frames(1)

	var before: float = dino.current_hp
	assert_eq(stake.damage_touching_dinos(), 0, "Nothing is in reach")
	assert_eq(dino.current_hp, before, "So nothing is hurt")

func test_11_damage_lands_on_a_tick_not_every_frame() -> void:
	# Per-frame damage would make the fence as strong as the machine is fast.
	var stake = _stake()
	# Only the reports this test makes. Left running, the stake also reports on every
	# physics step the engine takes, and after a slow frame -- a model loading in the test
	# before this one -- the engine takes several at once to catch up: enough contact on
	# top of the test's own to tip "part of a tick" over into a whole one, some runs and
	# not others.
	stake.set_physics_process(false)
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	# THREE FRAMES, not three calls in one. What the stake reports is how long it has
	# been against the animal, and the animal counts that once per frame however many
	# stakes are saying it -- so simulating the passage of time now means letting time
	# pass. See Dino.spikes_touch.
	var before: float = dino.current_hp
	var step: float = stake.contact_tick * 0.4
	stake._physics_process(step)
	await wait_physics_frames(1)
	stake._physics_process(step)
	assert_eq(dino.current_hp, before, "Part of a tick draws no blood")

	await wait_physics_frames(1)
	stake._physics_process(step)
	assert_almost_eq(dino.current_hp, before - stake.contact_damage, 0.0001,
		"A full tick's worth does")

func test_12_an_unfinished_stake_has_no_points_on_it_yet() -> void:
	var stake = _spawn(wall_script)
	stake.start_construction()
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	var before: float = dino.current_hp
	stake._physics_process(stake.contact_tick * 2.0)
	assert_eq(dino.current_hp, before, "A blueprint is a plan, not a weapon")

	stake.complete_construction()
	stake._physics_process(stake.contact_tick)
	assert_lt(dino.current_hp, before, "Finishing it arms it")

func test_13_a_paused_game_does_not_grind_anyone_down() -> void:
	var stake = _stake()
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	game_state_node.is_paused = true
	var before: float = dino.current_hp
	stake._physics_process(stake.contact_tick * 3.0)
	assert_eq(dino.current_hp, before, "Reading the map is not a fight")

	game_state_node.is_paused = false
	stake._physics_process(stake.contact_tick)
	assert_lt(dino.current_hp, before, "Unpausing resumes it")

func test_14_stakes_only_bite_the_attacking_side() -> void:
	var stake = _stake()
	var hero = _spawn(hero_script, Vector3(stake.contact_range * 0.3, 0.0, 0.0))
	var other = _stake(Vector3(stake.contact_range * 0.4, 0.0, 0.0))
	await wait_frames(1)

	var hero_before: float = hero.current_hp
	var other_before: float = other.current_hp
	assert_eq(stake.damage_touching_dinos(), 0, "Nothing hostile is in reach")
	assert_eq(hero.current_hp, hero_before, "The Hero walks his own fence unharmed")
	assert_eq(other.current_hp, other_before, "And stakes do not saw at each other")

func test_15_a_dead_dinosaur_is_not_hit_again() -> void:
	var stake = _stake()
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	dino.take_damage(dino.max_hp)
	assert_true(dino.is_dead, "The dinosaur is down")
	assert_eq(stake.damage_touching_dinos(), 0, "A corpse is not a target")

func test_16_destroyed_stakes_stop_biting() -> void:
	var stake = _stake()
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	stake.is_destroyed = true
	var before: float = dino.current_hp
	stake._physics_process(stake.contact_tick * 2.0)
	assert_eq(dino.current_hp, before, "Broken stakes are just splinters")

# ==============================================================================
# 3. The bite is a chip, not a kill
# ==============================================================================

func test_17_chewing_through_a_stake_costs_a_raptor_dearly_but_not_fatally() -> void:
	# The fence must be worth its wood without replacing the turret. A raptor that
	# spends as long as it takes to break one stake comes out alive and nearly
	# dead, which leaves the finishing to a turret or to the Hero.
	var raptor: Dictionary = config_node.DINOS["raptor"]
	var incoming: float = float(raptor["damage"]) * float(raptor["attack_rate"])
	assert_gt(incoming, 0.0, "A raptor does chew on what blocks it")

	var seconds_to_break: float = float(config_node.BUILDINGS["wall"]["hp"]) / incoming
	var taken: float = seconds_to_break * config_node.get_contact_dps("wall")

	assert_lt(taken, float(raptor["hp"]), "A raptor survives the stake it destroys")
	assert_gt(taken, float(raptor["hp"]) * 0.5, "But only just -- the fence is not decoration")

func test_18_a_stake_is_not_a_cheaper_turret() -> void:
	var tower: Dictionary = config_node.BUILDINGS["tower"]
	var tower_dps: float = float(tower.get("damage", 0.0)) * float(tower.get("fire_rate", 0.0))
	assert_gt(tower_dps, config_node.get_contact_dps("wall"),
		"A turret out-damages a stake, or nobody would ever pay for one")
	assert_lt(cost_of("wall"), cost_of("tower"),
		"And the stake stays the cheap thing you lay out by the row")

func test_19_a_big_dinosaur_shrugs_the_fence_off() -> void:
	# Stakes wear down a swarm; something the size of a house is meant to walk
	# through them, which is what stops them being the only defence needed.
	var big: Dictionary = config_node.DINOS["big_theropod"]
	var incoming: float = float(big["damage"]) * float(big["attack_rate"])
	var seconds_to_break: float = float(config_node.BUILDINGS["wall"]["hp"]) / incoming
	var taken: float = seconds_to_break * config_node.get_contact_dps("wall")
	assert_lt(taken, float(big["hp"]) * 0.25, "A big theropod barely notices a stake")

# ==============================================================================
# 4. The player is told before paying
# ==============================================================================

func _build_menu() -> Array:
	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	tree.root.add_child(panel)
	await wait_frames(1)
	panel.select_target(hero)
	panel._on_build_pressed()
	return [panel, hero]

func test_20_the_build_menu_says_that_stakes_bite() -> void:
	pay_for(["wall", "tower"], 999)
	var pair = await _build_menu()
	var panel = pair[0]

	panel._show_build_detail("wall")
	var detail: String = str(panel.status_label.text)
	var dps: String = "%.1f" % config_node.get_contact_dps("wall")
	assert_true(detail.contains(dps) or detail.contains(dps.replace(".", ",")),
		"The stake's damage is on the line before the wood is spent (got '%s')" % detail)

	# A building with no bite must not sprout an empty damage figure.
	panel._show_build_detail("tower")
	var plain: String = str(panel.status_label.text)
	assert_false(plain.contains("%.1f" % config_node.get_contact_dps("wall")),
		"A turret's line carries no bite figure (got '%s')" % plain)
	assert_true(plain.contains("%.1f" % config_node.get_build_time("tower"))
		or plain.contains(("%.1f" % config_node.get_build_time("tower")).replace(".", ",")),
		"But it does carry its build time (got '%s')" % plain)

func test_21_a_selected_stake_reports_its_bite() -> void:
	var stake = _stake()
	await wait_frames(1)

	var info: Dictionary = stake.get_display_info()
	assert_has(info, "contact_dps", "A stake reports what it does to what touches it")
	assert_almost_eq(float(info["contact_dps"]), config_node.get_contact_dps("wall"), 0.0001,
		"And reports the same figure as everything else")
	var shown: String = "%.1f" % stake.contact_dps()
	assert_true(str(info["status"]).contains(shown) or str(info["status"]).contains(shown.replace(".", ",")),
		"The panel line carries it too (got '%s')" % info["status"])

# ==============================================================================
# 5. Build time is inherited, not restated
# ==============================================================================

func test_22_a_placed_stake_takes_the_time_config_says_it_does() -> void:
	var stake = _spawn(wall_script)
	stake.start_construction()
	await wait_frames(1)
	assert_almost_eq(stake.build_time, config_node.get_build_time("wall"), 0.001,
		"A stake is raised in the time the price implies")

	var tower = _spawn(tower_script, Vector3(20.0, 0.0, 0.0))
	tower.start_construction()
	await wait_frames(1)
	assert_gt(tower.build_time, stake.build_time,
		"And the expensive thing keeps the player waiting longer")
