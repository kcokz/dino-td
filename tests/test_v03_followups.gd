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

	assert_gt(stake_w, tower_w, "A stake fence is wider than a turret")
	assert_gt(tower_h, stake_h, "A turret stands taller than a stake")
	assert_gt(tower_h, config_node.BUILDING_HEIGHT_DEFAULT,
		"A turret is taller than an ordinary shed, not merely equal to one")
	assert_lt(stake_h, config_node.BUILDING_HEIGHT_DEFAULT,
		"A stake is something you look over, not a building")

func test_02_the_turret_is_narrow_enough_to_walk_past() -> void:
	# Height is free; width is not. Making the turret tall must not have quietly
	# turned it into a barrier able to seal the Hero in.
	assert_false(config_node.is_barrier_building("tower"),
		"A turret leaves a lane, so a ring of them is not a cage")
	assert_true(config_node.is_barrier_building("wall"),
		"A stake fence still closes up, which is the whole point of it")

	var lane: float = config_node.TILE_SIZE - config_node.get_building_footprint("tower")
	assert_gt(lane, float(config_node.HERO.get("width", 0.8)),
		"The gap beside a turret is wider than the Hero")

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

func test_04_one_wood_buys_exactly_one_stake() -> void:
	# It used to be drawn as three uprights, which told the player they were
	# getting three things for the price of one.
	var stake = _stake()
	await wait_frames(1)

	var body = stake.find_child("Body", false, false)
	assert_not_null(body, "Stakes are drawn in their own holder")
	var uprights: Array = []
	for c in body.get_children():
		if c is MeshInstance3D:
			uprights.append(c)
	assert_eq(uprights.size(), 1, "One wood, one stake")
	assert_eq(cost_of("wall"), 1, "And it does cost exactly one wood")

	var h: float = config_node.get_building_height("wall")
	var fp: float = config_node.get_building_footprint("wall")
	var mesh: PrismMesh = uprights[0].mesh as PrismMesh
	assert_not_null(mesh, "Drawn sharpened rather than as a plain block")
	assert_almost_eq(mesh.size.y, h, 0.001, "As tall as the declared height")
	assert_almost_eq(uprights[0].position.y, h * 0.5, 0.001, "Standing on the ground, not in it")

	# The visible stake is as wide as the space it actually blocks. A thin post
	# with a tile-wide collision box stops dinosaurs at a wall nobody can see.
	assert_almost_eq(mesh.size.x, fp, 0.001, "As wide as the ground it occupies")

func test_04b_the_ghost_is_the_same_shape_as_the_thing_it_promises() -> void:
	# A cube standing in for a stake told the player nothing about what was going
	# down. The ghost and the building are drawn by the same code now.
	for b_type in config_node.BUILDABLE_TYPES:
		var body: Node3D = Building.make_body(String(b_type))
		var meshes: Array = []
		for c in body.get_children():
			if c is MeshInstance3D:
				meshes.append(c)
		assert_eq(meshes.size(), 1, "%s is drawn from one mesh" % b_type)

		var want_prism: bool = config_node.get_building_mesh_style(String(b_type)) == "spikes"
		assert_eq(meshes[0].mesh is PrismMesh, want_prism,
			"%s is drawn in the style Config declares" % b_type)

		var size: Vector3 = meshes[0].mesh.size
		assert_almost_eq(size.x, config_node.get_building_footprint(String(b_type)), 0.001,
			"%s ghost is as wide as the real thing" % b_type)
		assert_almost_eq(size.y, config_node.get_building_height(String(b_type)), 0.001,
			"%s ghost is as tall as the real thing" % b_type)
		body.free()

func test_05_an_ordinary_building_is_still_one_block_of_the_declared_size() -> void:
	var tower = _spawn(tower_script)
	tower.complete_construction()
	await wait_frames(1)

	var mesh: MeshInstance3D = tower._visual_mesh()
	assert_not_null(mesh, "The turret has a visible mesh")
	var box := mesh.mesh as BoxMesh
	assert_not_null(box, "Drawn as a single block")
	assert_almost_eq(box.size.x, config_node.get_building_footprint("tower"), 0.001, "As wide as declared")
	assert_almost_eq(box.size.y, config_node.get_building_height("tower"), 0.001, "As tall as declared")

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
	# A dinosaur attacking a building stops at the inner attack ring. A reach
	# derived from the stake's own width alone would leave it just out of range,
	# and the fence would be decorative.
	var stake = _stake()
	await wait_frames(1)
	assert_gte(stake.contact_range, config_node.DINO_ATTACK_SLOT_RADIUS_INNER,
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
	var dino = _raptor(Vector3(stake.contact_range * 0.5, 0.0, 0.0))
	await wait_frames(1)

	var before: float = dino.current_hp
	var step: float = stake.contact_tick * 0.4
	stake._physics_process(step)
	stake._physics_process(step)
	assert_eq(dino.current_hp, before, "Part of a tick draws no blood")

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
