# res://tests/test_v07_the_towers.gd
# The 2026-10-02 rebuild of the defences, the player: "防御每个类别要不一样，作用要明显不同，大小也要不一致（但是要是墙的倍
# 数，这样可以连着墙），而且要intuitive，基本上造之前玩家大概就知道是什么作用".
#
# FOUR TOWERS, EACH ITS OWN JOB. The bow tower shoots one at a time all round it -- the ring of bows is its look,
# its reach is a circle, nothing on it turns to aim. The log tower rolls a log down the lane in front of it when
# something walks in: everything it rolls over is slowed and shoved back, and hardly hurt; the heavy ones only by
# a log weighted with stone. The catapult (with stone) throws at a patch of ground ahead of it and hits everything
# there. The bait rack shoots nothing: what eats meat goes to it and eats until it is full. Each shoots only what
# it is loaded with: empty, it does nothing.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

const TOWERS: Array[String] = ["bow_tower", "log_tower", "bait_rack", "catapult"]

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	if game_state_node != null and "is_paused" in game_state_node:
		game_state_node.is_paused = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _row(type_id: String) -> Dictionary:
	return config_node.BUILDINGS[type_id]

func _ammo(ammo_id: String) -> Dictionary:
	return config_node.AMMO[ammo_id]

## A grid and a bare field with a mesh over it (nav_fixture), and a BuildSystem on them.
func _field() -> Array:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	return [gm, bs]

## `type_id` finished with its middle at build cell `cell`, facing `facing`; loaded with `ammo` from the stock
## (as much as it holds) unless that is "".
func _tower(bs: Node, type_id: String, cell: Vector2i, facing: int = 0, ammo: String = "") -> Node:
	stock_everything()
	var t = bs.place_at(type_id, cell, _world, false, facing)
	assert_not_null(t, "%s goes down at %s" % [type_id, str(cell)])
	if t == null:
		return null
	if not t.is_constructed:
		t.complete_construction()
	if ammo != "":
		t.set_ammo(ammo)
		t.load_from_stock()
	return t

## A `species` standing still at `at`: its own mind switched off, so it is where it is put and the tower is
## what is being tested. Hard to kill, so what hits it is counted in what it has lost.
func _animal(species: String, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	_world.add_child(d)
	d.setup(species)
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = Vector3(at.x, 0.0, at.z)
	d.set_physics_process(false)
	return d

func _lost(d: Node) -> float:
	return 999.0 - float(d.current_hp)

## Physics frames until `done` says so, or `seconds` have gone by.
func _until(done: Callable, seconds: float) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds and not bool(done.call()):
		await tree.physics_frame
		t += dt

# ==============================================================================
# 1. Four towers, each its own
# ==============================================================================

func test_01_four_towers_each_its_own_job_size_and_ammunition() -> void:
	var kinds: Dictionary = {}
	for t in TOWERS:
		assert_has(config_node.BUILDABLE_TYPES, t, "%s is on the build menu" % t)
		var row: Dictionary = _row(t)
		kinds[String(row["kind"])] = t
		assert_gte(int(config_node.get_building_cells(t)), 2, "%s is bigger than a stake: a wall's multiple" % t)
		assert_eq(config_node.get_building_size(t).x, config_node.get_building_size(t).y,
			"%s is square, so turning it never changes the cells it takes" % t)
		assert_gt(float(row["height"]), float(config_node.HERO["height"]), "%s stands taller than him" % t)
		assert_gt(int(config_node.ammo_capacity(t)), 0, "%s holds something" % t)
		assert_false(config_node.ammo_accepts(t).is_empty(), "%s takes some kind of ammunition" % t)
		for id in config_node.ammo_accepts(t):
			assert_true(config_node.AMMO.has(id), "%s's %s is ammunition" % [t, id])
			assert_eq(String(_ammo(id)["for"]), String(row["kind"]), "%s is for %s's kind" % [id, t])
			assert_has(config_node.RESOURCES, id, "%s is kept in the stock" % id)
		# Its upgrades are bigger stores of the same tower.
		var at: String = t
		var held: int = int(config_node.ammo_capacity(t))
		var level: int = int(config_node.tower_level(t))
		while not config_node.upgrade_targets(at).is_empty():
			var next: String = String(config_node.upgrade_targets(at)[0])
			assert_eq(String(_row(next)["kind"]), String(row["kind"]), "%s is still a %s" % [next, t])
			assert_eq(int(config_node.get_building_cells(next)), int(config_node.get_building_cells(t)), "%s stands in the same cells" % next)
			assert_gt(int(config_node.ammo_capacity(next)), held, "%s holds more than %s" % [next, at])
			assert_eq(int(config_node.tower_level(next)), level + 1, "%s is a level up" % next)
			held = int(config_node.ammo_capacity(next))
			level += 1
			at = next
		assert_gt(level, 1, "%s can be upgraded to a bigger store" % t)
	assert_eq(kinds.size(), TOWERS.size(), "each tower is its own kind")
	# What shoots is what the raiders go for; the meat is not.
	for kind in ["bow", "roller", "thrower"]:
		assert_has(config_node.DINO_AI["shooter_kinds"], kind, "a raider shot at goes for the %s" % kind)
	assert_not_has(config_node.DINO_AI["shooter_kinds"], "bait", "nothing is shot by the bait rack")
	# Bigger takes longer to put up than its price alone would say.
	assert_gt(float(config_node.size_time_factor("catapult")), float(config_node.size_time_factor("bow_tower")),
		"the catapult's four cells take longer than the bow tower's two")
	# Stone only once there is a pick.
	assert_true(_row("catapult")["cost"].has("stone"), "the catapult is built with stone")
	for t in ["bow_tower", "log_tower", "bait_rack"]:
		assert_false(_row(t)["cost"].has("stone"), "%s is wood: built before there is stone" % t)

# ==============================================================================
# 2. Empty, it does nothing
# ==============================================================================

func test_02_empty_a_tower_does_nothing() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0))
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -2.0))
	assert_false(bow.has_ammo(), "built, it holds nothing")
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 3.0)
	assert_eq(_lost(d), 0.0, "and shoots nothing at what stands under it")
	assert_ne(String(bow.get_display_info().get("status", "")), "", "its card says it is empty")

# ==============================================================================
# 3. The bow tower
# ==============================================================================

func test_03_the_bow_tower_shoots_all_round_one_at_a_time() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), 0, "arrow_wood")
	assert_eq(bow.rounds(), int(config_node.ammo_capacity("bow_tower")), "loaded as full as it holds")
	var reach: float = float(_row("bow_tower")["range"])
	var here: Vector3 = bow.global_position
	var round_it: Array = []
	for dir in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		round_it.append(_animal("raptor", here + dir * (reach - 1.0)))
	var beyond = _animal("raptor", here + Vector3(1.0, 0.0, 0.0).normalized() * (reach + 1.5) + Vector3(0.0, 0.0, 3.0))
	var shots: int = round_it.size()
	var arrow: float = float(_ammo("arrow_wood")["damage"])
	# Each, hit, is taken away -- as one killed would be -- and the next is shot, wherever round it it stands.
	var left: Array = round_it.duplicate()
	for k in shots:
		await _until(func():
			for d in left:
				if _lost(d) > 0.0:
					return true
			return false, float(_row("bow_tower")["fire_seconds"]) * 2.0)
		var hit: Node = null
		for d in left:
			if _lost(d) > 0.0:
				hit = d
		assert_not_null(hit, "shot %d hits one round it" % (k + 1))
		if hit == null:
			return
		assert_almost_eq(_lost(hit), arrow, 0.001, "one at %s is hit by an arrow" % str(hit.global_position - here))
		left.erase(hit)
		hit.remove_from_group("dinos")
	assert_eq(_lost(beyond), 0.0, "what is beyond its reach is not")
	assert_eq(bow.rounds(), int(config_node.ammo_capacity("bow_tower")) - shots, "an arrow spent on each")

func test_03b_an_arrow_at_what_is_gone_lands_on_nothing() -> void:
	# The playtest bot: two arrows let go at one animal, the first killed it, and the second's landing was a
	# script error -- it was bound to an animal already freed.
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), 0, "arrow_wood")
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -(float(_row("bow_tower")["range"]) - 0.5)))
	var other = _animal("raptor", bow.global_position + Vector3(4.0, 0.0, 0.0))
	assert_true(bow.loose_at(d), "an arrow is let go at it")
	_cleanup_nodes.erase(d)
	d.free()
	await wait_physics_frames(int(float(Engine.physics_ticks_per_second) * float(_row("bow_tower")["range"]) / float(config_node.TOWERS["arrow_speed"])) + 10)
	assert_eq(_lost(other), 0.0, "it comes down on nothing, and nothing else is hit for it")

func test_04_nothing_on_it_turns_to_aim() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), 0, "arrow_wood")
	var body: Node3D = bow.get_node_or_null("Body") as Node3D
	assert_not_null(body, "it has a body")
	var turned: Vector3 = body.rotation
	var here: Vector3 = bow.global_position
	# The bow that faces it is the one of the eight nearest its bearing.
	for i in 8:
		var bearing: float = float(i) * PI * 0.25
		var at: Vector3 = here + Vector3(sin(bearing), 0.0, -cos(bearing)) * 3.0
		assert_eq(bow.bow_facing(at), i, "bow %d faces bearing %d degrees" % [i, i * 45])
	var d = _animal("raptor", here + Vector3(2.0, 0.0, 2.0))
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 3.0)
	assert_gt(_lost(d), 0.0, "it shot")
	assert_eq(body.rotation, turned, "and nothing on it turned to aim")

func test_05_a_bone_arrow_goes_on_through_a_column() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), 0, "arrow_bone")
	assert_eq(String(bow.ammo_type), "arrow_bone", "set to bone arrows")
	var here: Vector3 = bow.global_position
	var pierce: int = int(_ammo("arrow_bone")["pierce"])
	var step: float = float(config_node.TOWERS["pierce_reach"]) / float(pierce)
	var column: Array = []
	for k in pierce + 1:
		column.append(_animal("raptor", here + Vector3(0.0, 0.0, -2.0 - step * float(k))))
	await _until(func(): return _lost(column[0]) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 2.0)
	var dmg: float = float(_ammo("arrow_bone")["damage"])
	for k in pierce:
		assert_almost_eq(_lost(column[k]), dmg, 0.001, "the %d-th in the column is hit by the one arrow" % (k + 1))
	assert_eq(_lost(column[pierce]), 0.0, "and no more than its pierce")

# ==============================================================================
# 4. The log tower
# ==============================================================================

func test_06_the_log_tower_rolls_its_lane_slowing_and_shoving_back() -> void:
	var f: Array = await _field()
	var logs = await _tower(f[1], "log_tower", Vector2i(0, 0), 0, "log_round")
	var fwd: Vector3 = logs.forward()
	assert_almost_eq(fwd.dot(Vector3.FORWARD), 1.0, 0.001, "set facing north, it faces north")
	var lane: float = float(_row("log_tower")["lane"]) * float(config_node.BUILD_CELL)
	assert_almost_eq(logs.lane_length(), lane, 0.001, "its lane runs its length on open ground")
	var origin: Vector3 = logs.lane_origin()
	var in_lane = _animal("raptor", origin + fwd * (lane * 0.5))
	var aside = _animal("raptor", origin + fwd * (lane * 0.5) + Vector3.RIGHT * (logs.lane_width() * 0.5 + 1.0))
	var before: int = logs.uses_left
	await _until(func(): return _lost(in_lane) > 0.0, lane / float(_row("log_tower")["roll_speed"]) + 1.0)
	var row: Dictionary = _ammo("log_round")
	assert_eq(logs.uses_left, before - 1, "one log let go")
	assert_almost_eq(_lost(in_lane), float(row["damage"]), 0.001, "what is in the lane is hurt a little")
	assert_almost_eq(float(in_lane.trap_pace), float(row["slow"]), 0.001, "and slowed")
	assert_true(in_lane.is_shoved(), "and shoved")
	assert_gt(in_lane._shove.normalized().dot(fwd), 0.99, "back the way the log rolls")
	var was: Vector3 = in_lane.global_position
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	while in_lane._shoved(dt):
		pass
	assert_almost_eq((in_lane.global_position - was).dot(fwd), float(row["push"]), 0.15, "as far as the log shoves")
	assert_eq(_lost(aside), 0.0, "what is beside the lane is not touched")

func test_07_a_wall_across_its_lane_stops_the_log() -> void:
	var f: Array = await _field()
	var logs = await _tower(f[1], "log_tower", Vector2i(0, 0), 0, "log_round")
	var size: int = int(config_node.get_building_cells("log_tower"))
	var first: int = (size + 1) / 2
	stock_everything()
	var wall = f[1].place_at("wall", Vector2i(0, -(first + 2)), _world, false)
	assert_not_null(wall, "a stake across its lane")
	wall.complete_construction()
	logs._lane_m = -1.0
	assert_almost_eq(logs.lane_length(), 2.0 * float(config_node.BUILD_CELL), 0.001, "the lane stops at the stake")
	var spikes = f[1].place_at("ground_spikes", Vector2i(1, -(first + 1)), _world, false)
	assert_not_null(spikes, "spikes in the lane")
	logs._lane_m = -1.0
	assert_almost_eq(logs.lane_length(), 2.0 * float(config_node.BUILD_CELL), 0.001, "what is walked over does not stop it")

func test_08_only_a_stone_weighted_log_shoves_the_heavy_ones() -> void:
	var heavy: String = ""
	for species in config_node.DINOS:
		if bool(config_node.DINOS[species].get("heavy", false)):
			heavy = String(species)
			break
	assert_ne(heavy, "", "there is something heavy in the valley")
	assert_true(bool(_ammo("roller_stone").get("moves_heavy", false)), "the stone roller moves the heavy ones")
	assert_false(bool(_ammo("log_round").get("moves_heavy", false)), "a plain log does not")
	var f: Array = await _field()
	var logs = await _tower(f[1], "log_tower", Vector2i(0, 0), 0, "log_round")
	var lane: float = logs.lane_length()
	var big = _animal(heavy, logs.lane_origin() + logs.forward() * (lane * 0.5))
	await _until(func(): return _lost(big) > 0.0, lane / float(_row("log_tower")["roll_speed"]) + 1.0)
	assert_gt(_lost(big), 0.0, "the log rolls into the %s" % heavy)
	assert_false(big.is_shoved(), "and does not shove it")
	logs.set_ammo("roller_stone")
	logs.load_from_stock()
	logs.cooldown = 0.0
	big.current_hp = 999.0
	await _until(func(): return _lost(big) > 0.0, lane / float(_row("log_tower")["roll_speed"]) + float(_row("log_tower")["roll_seconds"]) + 1.0)
	assert_true(big.is_shoved(), "a log weighted with stone does")

# ==============================================================================
# 5. The catapult
# ==============================================================================

func test_09_the_catapult_smashes_a_patch_ahead_of_it() -> void:
	var f: Array = await _field()
	var cat = await _tower(f[1], "catapult", Vector2i(0, 0), 1, "shot_stone")
	assert_almost_eq(cat.forward().dot(Vector3.RIGHT), 1.0, 0.001, "set facing east, it faces east")
	var centre: Vector3 = cat.zone_centre()
	assert_almost_eq(Vector2(centre.x - cat.global_position.x, centre.z - cat.global_position.z).length(),
		float(_row("catapult")["zone_distance"]), 0.001, "its patch is its distance out")
	var row: Dictionary = _ammo("shot_stone")
	var crowd: Array = [_animal("raptor", centre), _animal("raptor", centre + Vector3(0.0, 0.0, float(row["splash"]) * 0.6))]
	var outside = _animal("raptor", centre + Vector3(0.0, 0.0, float(row["splash"]) + float(_row("catapult")["zone_radius"]) + 1.0))
	await _until(func(): return _lost(crowd[0]) > 0.0, float(_row("catapult")["flight_seconds"]) + 1.0)
	for d in crowd:
		assert_almost_eq(_lost(d), float(row["damage"]), 0.001, "everything where it lands is hit")
		assert_gt(float(d.held_left), 0.0, "and knocked flat a moment")
	assert_eq(_lost(outside), 0.0, "what is away from the patch is not")
	assert_eq(cat.rounds(), int(config_node.ammo_capacity("catapult")) - 1, "a shot spent")

# ==============================================================================
# 6. The bait rack
# ==============================================================================

func test_10_meat_on_the_rack_draws_what_eats_it_until_it_is_full() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	await nav_settled(main)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var cell: Vector2i = main.grid_manager.world_to_build_cell(door + Vector3(6.0, 0.0, 6.0))
	var rack = main.build_system.place_at("bait_rack", cell, main.buildings_container, false)
	assert_not_null(rack, "a bait rack goes down by the cabin")
	rack.complete_construction()
	rack.set_ammo("food")
	rack.load_from_stock()
	assert_true(rack.has_meat(), "meat on it")
	assert_eq(rack.uses_left, int(config_node.ammo_capacity("bait_rack")) * int(_ammo("food")["uses"]),
		"a piece of meat is so many bites")
	await nav_settled(main)
	var eater: String = ""
	for species in config_node.DINOS:
		if config_node.takes_bait(String(species)) and String(config_node.DINOS[species].get("behaviour", "")) == "pack":
			eater = String(species)
			break
	var d = load(String(config_node.get_dino_script_path(eater))).new()
	_cleanup_nodes.append(d)
	main.dinos_container.add_child(d)
	d.setup(eater)
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = rack.global_position + Vector3(float(_row("bait_rack")["range"]) * 0.6, 0.0, 0.0)
	d.set_waypoints([main.current_core.global_position])
	var bites: int = int(config_node.BAIT["bites_to_eat"])
	var full_at: int = rack.uses_left - bites
	await _until(func(): return rack.uses_left <= full_at, 40.0)
	assert_eq(rack.uses_left, full_at, "the %s came to the meat and ate its fill" % eater)
	assert_true(d._is_full(), "and is full")
	await _until(func(): return d.current_target != rack, 3.0)
	assert_ne(d.current_target, rack, "full, it goes on its way")
	assert_null(d._bait_near(), "and does not turn for meat again a while")
	assert_almost_eq(_lost(d), 0.0, 0.001, "eating hurt nothing")

# ==============================================================================
# 7. What every tower shares: a blueprint, a pause, its facing, what goes for it
# ==============================================================================

func test_12_a_tower_still_being_built_holds_nothing_and_does_nothing() -> void:
	var f: Array = await _field()
	stock_everything()
	var bow = f[1].place_at("bow_tower", Vector2i(0, 0), _world, true)
	assert_not_null(bow, "ordered")
	assert_false(bow.is_constructed, "only ordered")
	assert_false(bow.wants_load(), "an order is not loaded")
	assert_eq(bow.load_from_stock(), 0, "nothing goes into it")
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -2.0))
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 2.0)
	assert_eq(_lost(d), 0.0, "and it shoots nothing")
	bow.complete_construction()
	bow.set_ammo("arrow_wood")
	assert_gt(bow.load_from_stock(), 0, "finished, it is loaded")
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 2.0)
	assert_gt(_lost(d), 0.0, "and it shoots")

func test_13_a_paused_game_shoots_nothing() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), 0, "arrow_wood")
	game_state_node.is_paused = true
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -2.0))
	await wait_physics_frames(int(float(Engine.physics_ticks_per_second) * float(_row("bow_tower")["fire_seconds"])))
	assert_eq(_lost(d), 0.0, "paused, nothing is let go")
	game_state_node.is_paused = false
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 2.0)
	assert_gt(_lost(d), 0.0, "unpaused, it is")

func test_14_r_turns_a_facing_tower_in_hand_and_its_ghost_lays_out_its_ground() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	stock_everything()
	assert_false(main._faces("bow_tower"), "the bow tower faces no way: it shoots all round")
	assert_false(main._faces("bait_rack"), "nor does the bait rack")
	assert_true(main._faces("log_tower"), "the log tower does")
	assert_true(main._faces("catapult"), "and the catapult")
	main.on_build_selected("log_tower")
	assert_eq(int(main._placement_facing), 0, "it starts facing north")
	main.turn_placement(1)
	assert_eq(int(main._placement_facing), 1, "R turns it a quarter, clockwise")
	main.turn_placement(-1)
	main.turn_placement(-1)
	assert_eq(int(main._placement_facing), 3, "Shift+R turns it back, round past north")
	main.turn_placement(2)
	var gm = main.grid_manager
	var snap: Vector2i = gm.tile_centre_build_cell(FREE_TILE)
	main._show_zone(snap)
	var zone: MeshInstance3D = main.build_preview.find_child("LanePreview", false, false) as MeshInstance3D
	assert_not_null(zone, "its ghost lays out its lane")
	if zone == null:
		return
	assert_true(zone.visible, "shown")
	assert_gt(zone.position.x, float(config_node.get_building_half("log_tower").x) - 0.001, "out ahead of it, to the east")
	assert_almost_eq(zone.position.z, 0.0, 0.001, "in line with it")
	var placed = main.try_place_at_cell(Vector2i.ZERO, gm.build_cell_to_world(snap))
	assert_not_null(placed, "it goes down where the ghost was")
	if placed != null:
		assert_eq(int(placed.facing), 1, "facing the way it was turned")
	main.on_build_selected("catapult")
	main._show_zone(snap + Vector2i(0, 12))
	var patch: MeshInstance3D = main.build_preview.find_child("LanePreview", false, false) as MeshInstance3D
	assert_not_null(patch, "the catapult's ghost lays out its patch")
	if patch != null:
		assert_almost_eq(Vector2(patch.position.x, patch.position.z).length(), float(_row("catapult")["zone_distance"]), 0.001,
			"its distance out")
		# The ground it acts on in the reach's blue, not the ghost's go-green (the player: "能攻击的范围应该显示蓝色而不是绿色").
		main._tint_ghost(true)
		var reach: Color = config_node.FEEDBACK["reach_color"]
		var lane_mat := patch.material_override as StandardMaterial3D
		assert_true(Color(lane_mat.albedo_color, 1.0).is_equal_approx(Color(reach, 1.0)), "its patch in blue, where it can go down")
		main._tint_ghost(false)
		lane_mat = patch.material_override as StandardMaterial3D
		assert_true(Color(lane_mat.albedo_color, 1.0).is_equal_approx(Color(reach, 1.0)), "and where it cannot")

func test_15_a_bigger_store_keeps_its_facing() -> void:
	var f: Array = await _field()
	var logs = await _tower(f[1], "log_tower", Vector2i(0, 0), 2, "log_round")
	stock_everything()
	var to: String = String(config_node.upgrade_targets("log_tower")[0])
	assert_true(logs.begin_upgrade(to), "the upgrade is started")
	logs.add_upgrade_progress(1000.0)
	await wait_frames(2)
	assert_eq(String(logs.building_type), to, "it is the bigger one now")
	assert_eq(int(logs.facing), 2, "still facing south")
	var body: Node3D = logs.find_child("Body", false, false) as Node3D
	assert_almost_eq(body.rotation.y, AmmoTower.facing_yaw(2), 0.001, "its body turned the same way")

func test_16_what_shoots_at_a_raider_is_what_it_goes_for() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), 0, "arrow_wood")
	var rack = await _tower(f[1], "bait_rack", Vector2i(6, 0))
	var spikes = f[1].place_at("ground_spikes", Vector2i(0, 4), _world, false)
	var d = _animal("raptor", bow.global_position + Vector3(2.5, 0.0, -2.5))
	await wait_frames(1)
	assert_true(d._is_shooter(bow), "the bow tower is what shoots at it")
	assert_false(d._is_shooter(rack), "the bait rack shoots nothing")
	assert_false(d._is_shooter(spikes), "nor do spikes")
	d.shot_by(bow)
	assert_eq(d._shot_lately(), bow, "shot at, it knows what shot it")
	d._think()
	assert_eq(d.current_target, bow, "and goes for the tower")

func test_17_he_does_not_set_off_his_own_log_tower() -> void:
	var f: Array = await _field()
	var logs = await _tower(f[1], "log_tower", Vector2i(0, 0), 0, "log_round")
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	_world.add_child(hero)
	hero.global_position = logs.lane_origin() + logs.forward() * 2.0
	hero.set_physics_process(false)
	var before: int = logs.uses_left
	await wait_physics_frames(6)
	assert_false(logs.someone_in_lane(), "he is not what the lane waits for")
	assert_eq(logs.uses_left, before, "no log let go for him")

## Picked, a tower shows what it acts on in the reach's blue (Config.FEEDBACK.reach_color; the player: "能攻击的范围应该显示蓝色
## 而不是绿色"): the bow tower its ring, the log tower its lane, the catapult its patch -- not only under the ghost.
func test_18_picked_it_shows_what_it_acts_on_in_blue() -> void:
	var f: Array = await _field()
	var reach: Color = config_node.FEEDBACK["reach_color"]
	var bow = await _tower(f[1], "bow_tower", Vector2i(-8, 0), 0, "arrow_wood")
	var logs = await _tower(f[1], "log_tower", Vector2i(0, 0), 1, "log_round")
	var cat = await _tower(f[1], "catapult", Vector2i(0, 8), 0, "shot_stone")
	for t in [bow, logs, cat]:
		t.set_range_visible(true)
	assert_true(bow.range_indicator.visible, "the bow tower its ring")
	var ring_mat := bow.range_indicator.material_override as StandardMaterial3D
	assert_true(Color(ring_mat.albedo_color, 1.0).is_equal_approx(Color(reach, 1.0)), "in blue")
	for t in [logs, cat]:
		var zone := t.get_node_or_null("ZoneShown/Zone") as MeshInstance3D
		assert_not_null(zone, "%s lays out the ground it acts on" % t.building_type)
		if zone == null:
			continue
		assert_true(zone.is_visible_in_tree(), "shown while it is picked")
		var mat := zone.material_override as StandardMaterial3D
		assert_true(Color(mat.albedo_color, 1.0).is_equal_approx(Color(reach, 1.0)), "in blue")
	var lane := logs.get_node("ZoneShown/Zone") as MeshInstance3D
	var along: Vector3 = lane.global_position - logs.lane_origin()
	assert_gt(along.dot(logs.forward()), 0.0, "the lane out ahead of the log tower, the way it faces")
	assert_almost_eq((lane.mesh as PlaneMesh).size.x, float(logs.lane_width()), 0.001, "as wide as a log is long")
	var spot := cat.get_node("ZoneShown/Zone") as MeshInstance3D
	assert_almost_eq(Vector2(spot.global_position.x - cat.zone_centre().x, spot.global_position.z - cat.zone_centre().z).length(),
		0.0, 0.01, "the catapult's patch where it throws")
	for t in [bow, logs, cat]:
		t.set_range_visible(false)
	assert_false(logs.get_node("ZoneShown").visible, "and gone when it is not")

func test_11_what_does_not_eat_meat_is_not_drawn() -> void:
	for species in config_node.DINOS:
		var habit: String = String(config_node.DINOS[species].get("behaviour", ""))
		assert_eq(bool(config_node.takes_bait(String(species))), config_node.BAIT["eaters"].has(habit),
			"%s goes to meat by its habit (%s)" % [species, habit])
	assert_false(config_node.BAIT["eaters"].has("siege"), "the siege boss does not leave what it is about")
