# res://tests/test_v07_the_towers.gd
# The 2026-10-02 rebuild of the defences, the player: "防御每个类别要不一样，作用要明显不同，大小也要不一致（但是要是墙的倍
# 数，这样可以连着墙），而且要intuitive，基本上造之前玩家大概就知道是什么作用". And v0.7 (GAME-DESIGN 3.0): "投石机样子显得很
# 蠢，而且我发现这几个tower，在其他defend游戏里都是可以很好的互相配合，模样也很接近……投石干脆和滚木都做成一个圈内都能进攻，
# 然后基座模型一样大".
#
# FOUR TOWERS, ONE SET. Each stands on the same plinth two cells a side and acts all round it within a circle --
# nothing faces a way, nothing is turned in hand. Each its own job: the bow tower shoots one at a time all round it, and
# only it reaches what flies; the drop tower swings round and drops a log on what is at its foot -- crushed, knocked
# flat, shoved off, the heavy ones only by a weighted log; the catapult turns and throws into the thick of a crowd,
# never at its own foot; the bait rack holds what eats meat a few seconds as it passes, once each. Each shoots only what
# it is loaded with: empty, it does nothing. A level up holds more and hits harder, and is paid for in stone, then bone.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

const TOWERS: Array[String] = ["bow_tower", "drop_tower", "bait_rack", "catapult"]

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

func _turn() -> float:
	return float(config_node.TOWERS["turn_seconds"])

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

## `type_id` finished with its middle at build cell `cell`; loaded with `ammo` from the stock (as much as it holds)
## unless that is "".
func _tower(bs: Node, type_id: String, cell: Vector2i, ammo: String = "") -> Node:
	stock_everything()
	var t = bs.place_at(type_id, cell, _world, false)
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

func _heavy() -> String:
	for species in config_node.DINOS:
		if bool(config_node.DINOS[species].get("heavy", false)):
			return String(species)
	return ""

# ==============================================================================
# 1. Four towers, one set
# ==============================================================================

func test_01_four_towers_one_set_each_its_own_job() -> void:
	var kinds: Dictionary = {}
	var cells: int = int(config_node.get_building_cells("bow_tower"))
	for t in TOWERS:
		assert_has(config_node.BUILDABLE_TYPES, t, "%s is on the build menu" % t)
		var row: Dictionary = _row(t)
		kinds[String(row["kind"])] = t
		assert_eq(int(config_node.get_building_cells(t)), cells, "%s stands on the same plinth as the rest" % t)
		assert_gt(float(row.get("range", 0.0)), 0.0, "%s acts within a circle round it" % t)
		assert_false(row.has("faces"), "%s faces no way: it is not turned in hand" % t)
		assert_gt(float(row["height"]), float(config_node.HERO["height"]), "%s stands taller than him" % t)
		assert_gt(int(config_node.ammo_capacity(t)), 0, "%s holds something" % t)
		for id in config_node.ammo_accepts(t):
			assert_eq(String(_ammo(id)["for"]), String(row["kind"]), "%s is for %s's kind" % [id, t])
			assert_has(config_node.RESOURCES, id, "%s is kept in the stock" % id)
		# A level up: the same tower, holding more and hitting harder -- stone for the second, bone for the third.
		var two: String = String(config_node.upgrade_targets(t)[0])
		var three: String = String(config_node.upgrade_targets(two)[0])
		assert_eq(int(config_node.tower_level(three)), 3, "%s goes up to a third level" % t)
		assert_true(config_node.upgrade_cost(t, two).has("stone"), "%s's second level is paid for in stone" % t)
		assert_false(config_node.upgrade_cost(t, two).has("bone"), "not bone")
		assert_true(config_node.upgrade_cost(two, three).has("bone"), "%s's third in bone" % t)
		assert_gt(int(config_node.ammo_capacity(two)), int(config_node.ammo_capacity(t)), "%s holds more" % two)
		assert_gt(int(config_node.ammo_capacity(three)), int(config_node.ammo_capacity(two)), "%s more again" % three)
		if String(row["kind"]) != "bait":
			assert_gt(float(config_node.damage_factor(two)), float(config_node.damage_factor(t)), "%s hits harder" % two)
			assert_gt(float(config_node.damage_factor(three)), float(config_node.damage_factor(two)), "%s harder again" % three)
		for lv in [two, three]:
			assert_eq(String(_row(lv)["kind"]), String(row["kind"]), "%s is still a %s" % [lv, t])
			assert_eq(int(config_node.get_building_cells(lv)), cells, "%s stands in the same cells" % lv)
	assert_eq(kinds.size(), TOWERS.size(), "each tower is its own kind")
	# What shoots is what the raiders go for; the meat is not.
	for kind in ["bow", "drop", "thrower"]:
		assert_has(config_node.DINO_AI["shooter_kinds"], kind, "a raider shot at goes for the %s" % kind)
	assert_not_has(config_node.DINO_AI["shooter_kinds"], "bait", "nothing is shot by the bait rack")
	# What pierces is the bow's; what crushes -- the log, the stone -- goes into the armoured whole (ARMOR).
	assert_eq(config_node.ARMOR["piercing"], ["bow"], "only the arrow pierces")
	# Stone only once there is a pick.
	assert_true(_row("catapult")["cost"].has("stone"), "the catapult is built with stone")
	for t in ["bow_tower", "drop_tower", "bait_rack"]:
		assert_false(_row(t)["cost"].has("stone"), "%s is wood: built before there is stone" % t)
	assert_gt(float(_row("catapult").get("min_range", 0.0)), 0.0, "the catapult cannot throw at its own foot")
	assert_lt(float(_row("drop_tower")["range"]), float(_row("catapult")["min_range"]),
		"what is too near the catapult is where a drop tower reaches")

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
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
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
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -(float(_row("bow_tower")["range"]) - 0.5)))
	var other = _animal("raptor", bow.global_position + Vector3(4.0, 0.0, 0.0))
	assert_true(bow.loose_at(d), "an arrow is let go at it")
	_cleanup_nodes.erase(d)
	d.free()
	await wait_physics_frames(int(float(Engine.physics_ticks_per_second) * float(_row("bow_tower")["range"]) / float(config_node.TOWERS["arrow_speed"])) + 10)
	assert_eq(_lost(other), 0.0, "it comes down on nothing, and nothing else is hit for it")

func test_04_nothing_on_the_bow_tower_turns_to_aim() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
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
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_bone")
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
# 4. The drop tower
# ==============================================================================

func test_06_the_drop_tower_drops_on_what_is_at_its_foot() -> void:
	var f: Array = await _field()
	var drop = await _tower(f[1], "drop_tower", Vector2i(0, 0), "log_round")
	var reach: float = float(_row("drop_tower")["range"])
	var here: Vector3 = drop.global_position
	var at_foot = _animal("raptor", here + Vector3(reach * 0.7, 0.0, 0.0))
	var beyond = _animal("raptor", here + Vector3(0.0, 0.0, reach + float(_ammo("log_round")["splash"]) + 1.0))
	var before: int = drop.uses_left
	await _until(func(): return _lost(at_foot) > 0.0, _turn() + float(_row("drop_tower")["fall_seconds"]) + 1.0)
	var row: Dictionary = _ammo("log_round")
	assert_eq(drop.uses_left, before - 1, "one log dropped")
	assert_almost_eq(_lost(at_foot), float(row["damage"]), 0.001, "what is at its foot is crushed")
	assert_gt(float(at_foot.held_left), 0.0, "knocked flat a moment")
	assert_true(at_foot.is_shoved(), "and shoved")
	assert_gt(at_foot._shove.normalized().dot(Vector3.RIGHT), 0.99, "off away from the tower")
	var was: Vector3 = at_foot.global_position
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	while at_foot._shoved(dt):
		pass
	assert_almost_eq((at_foot.global_position - was).dot(Vector3.RIGHT), float(row["push"]), 0.15, "as far as the log shoves")
	assert_eq(_lost(beyond), 0.0, "what is beyond its reach is not touched")
	assert_gt(drop.forward().dot(Vector3.RIGHT), 0.9, "its boom swung round to the east to drop it")

func test_07_only_a_stone_weighted_log_shoves_the_heavy_ones() -> void:
	var heavy: String = _heavy()
	assert_ne(heavy, "", "there is something heavy in the valley")
	assert_true(bool(_ammo("roller_stone").get("moves_heavy", false)), "the stone-weighted log moves the heavy ones")
	assert_false(bool(_ammo("log_round").get("moves_heavy", false)), "a plain log does not")
	var f: Array = await _field()
	var drop = await _tower(f[1], "drop_tower", Vector2i(0, 0), "log_round")
	var big = _animal(heavy, drop.global_position + Vector3(0.0, 0.0, -float(_row("drop_tower")["range"]) * 0.7))
	await _until(func(): return _lost(big) > 0.0, _turn() + float(_row("drop_tower")["fall_seconds"]) + 1.0)
	assert_gt(_lost(big), 0.0, "the log comes down on the %s" % heavy)
	assert_false(big.is_shoved(), "and does not shove it")
	drop.set_ammo("roller_stone")
	drop.load_from_stock()
	drop.cooldown = 0.0
	big.current_hp = 999.0
	await _until(func(): return _lost(big) > 0.0,
		_turn() + float(_row("drop_tower")["fall_seconds"]) + float(_row("drop_tower")["drop_seconds"]) + 1.0)
	assert_true(big.is_shoved(), "a log weighted with stone does")

func test_08_what_crushes_goes_into_the_armoured_whole() -> void:
	var armoured: String = ""
	for species in config_node.DINOS:
		if bool(config_node.DINOS[species].get("armored", false)):
			armoured = String(species)
			break
	assert_ne(armoured, "", "something in the valley is armoured")
	var f: Array = await _field()
	var drop = await _tower(f[1], "drop_tower", Vector2i(0, 0), "log_round")
	var d = _animal(armoured, drop.global_position + Vector3(float(_row("drop_tower")["range"]) * 0.6, 0.0, 0.0))
	await _until(func(): return _lost(d) > 0.0, _turn() + float(_row("drop_tower")["fall_seconds"]) + 1.0)
	assert_almost_eq(_lost(d), float(_ammo("log_round")["damage"]), 0.001, "a log goes into the %s whole" % armoured)

# ==============================================================================
# 5. The catapult
# ==============================================================================

func test_09_the_catapult_throws_all_round_into_a_crowd_not_at_its_foot() -> void:
	var f: Array = await _field()
	var cat = await _tower(f[1], "catapult", Vector2i(0, 0), "shot_stone")
	var row: Dictionary = _ammo("shot_stone")
	var here: Vector3 = cat.global_position
	var mid: float = (float(_row("catapult")["min_range"]) + float(_row("catapult")["range"])) * 0.5
	var crowd: Array = [_animal("raptor", here + Vector3(-mid, 0.0, 0.0)),
		_animal("raptor", here + Vector3(-mid, 0.0, float(row["splash"]) * 0.6))]
	var lone = _animal("raptor", here + Vector3(mid, 0.0, 0.0))
	var too_near = _animal("raptor", here + Vector3(0.0, 0.0, -float(_row("catapult")["min_range"]) * 0.5))
	var aim: Vector3 = cat.aim_point()
	assert_lt(Vector2(aim.x - crowd[0].global_position.x, aim.z - crowd[0].global_position.z).length(), float(row["splash"]),
		"it aims at the thick of them")
	assert_false(cat.animals_in_reach().has(too_near), "what is at its own foot it cannot throw at")
	await _until(func(): return _lost(crowd[0]) > 0.0, _turn() + float(_row("catapult")["flight_seconds"]) + 1.0)
	for d in crowd:
		assert_almost_eq(_lost(d), float(row["damage"]), 0.001, "everything where it lands is hit")
		assert_gt(float(d.held_left), 0.0, "and knocked flat a moment")
	assert_eq(_lost(lone), 0.0, "the one on its own is not")
	assert_eq(_lost(too_near), 0.0, "nor what is too near")
	assert_eq(cat.rounds(), int(config_node.ammo_capacity("catapult")) - 1, "a shot spent")
	assert_gt(cat.forward().dot(Vector3.LEFT), 0.9, "its turntable turned to the west to throw")

# ==============================================================================
# 6. The bait rack
# ==============================================================================

func _eater() -> String:
	for species in config_node.DINOS:
		if config_node.takes_bait(String(species)) and not bool(config_node.DINOS[species].get("flies", false)):
			return String(species)
	return ""

func test_10_meat_holds_what_passes_a_few_seconds_once() -> void:
	var f: Array = await _field()
	var rack = await _tower(f[1], "bait_rack", Vector2i(0, 0), "food")
	assert_true(rack.has_meat(), "meat on it")
	assert_eq(rack.uses_left, int(config_node.ammo_capacity("bait_rack")) * int(_ammo("food")["uses"]),
		"a piece of meat is so many bites")
	var eater: String = _eater()
	assert_ne(eater, "", "something eats meat")
	var reach: float = float(_row("bait_rack")["range"])
	var far = _animal(eater, rack.global_position + Vector3(reach + 2.0, 0.0, 0.0))
	var before: int = rack.uses_left
	var d = _animal(eater, rack.global_position + Vector3(reach * 0.6, 0.0, 0.0))
	await wait_physics_frames(2)
	assert_eq(rack.uses_left, before - 1, "the %s passing by stopped and took a bite" % eater)
	assert_almost_eq(float(d.held_left), float(config_node.BAIT["eat_seconds"]), 0.1, "held there eating")
	assert_eq(far.held_left, 0.0, "what is further off is not drawn to it")
	await wait_physics_frames(10)
	assert_eq(rack.uses_left, before - 1, "and it stops once: it does not stop for meat again")
	assert_almost_eq(_lost(d), 0.0, 0.001, "eating hurt nothing")

func test_11_what_does_not_eat_meat_does_not_stop() -> void:
	for species in config_node.DINOS:
		var habit: String = String(config_node.DINOS[species].get("behaviour", ""))
		assert_eq(bool(config_node.takes_bait(String(species))), config_node.BAIT["eaters"].has(habit),
			"%s stops for meat by its habit (%s)" % [species, habit])
	assert_false(config_node.BAIT["eaters"].has("siege"), "the siege boss does not leave what it is about")

# ==============================================================================
# 7. What every tower shares: a blueprint, a pause, its level, what goes for it, its reach shown
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
	# Finished, it comes loaded: a full magazine of what its price paid for (Config.ammo_comes_with).
	assert_eq(String(bow.ammo_type), String(config_node.ammo_comes_with("bow_tower")), "finished, it comes loaded")
	assert_eq(bow.rounds(), bow.capacity(), "full")
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 2.0)
	assert_gt(_lost(d), 0.0, "and it shoots")

func test_13_a_paused_game_shoots_nothing() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
	game_state_node.is_paused = true
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -2.0))
	await wait_physics_frames(int(float(Engine.physics_ticks_per_second) * float(_row("bow_tower")["fire_seconds"])))
	assert_eq(_lost(d), 0.0, "paused, nothing is let go")
	game_state_node.is_paused = false
	await _until(func(): return _lost(d) > 0.0, float(_row("bow_tower")["fire_seconds"]) * 2.0)
	assert_gt(_lost(d), 0.0, "unpaused, it is")

func test_14_no_tower_is_turned_in_hand_and_its_ghost_shows_its_reach() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	stock_everything()
	var reach: Color = config_node.FEEDBACK["reach_color"]
	for t in TOWERS:
		assert_false(main._turns(t), "%s is not turned with R: it acts all round it" % t)
		main.on_build_selected(t)
		var ring: MeshInstance3D = main.build_preview_ring
		assert_not_null(ring, "%s's ghost shows its reach" % t)
		if ring == null:
			continue
		assert_almost_eq((ring.mesh as CylinderMesh).top_radius, float(_row(t)["range"]), 0.001, "as far as %s reaches" % t)
		for ok in [true, false]:
			main._tint_ghost(ok)
			var mat := ring.material_override as StandardMaterial3D
			assert_true(Color(mat.albedo_color, 1.0).is_equal_approx(Color(reach, 1.0)),
				"in blue, where it can go down and where not (the player: \"能攻击的范围应该显示蓝色而不是绿色\")")
		var inner: MeshInstance3D = main.build_preview.find_child(main.ZONE_PREVIEW, false, false) as MeshInstance3D
		if t == "catapult":
			assert_not_null(inner, "the catapult's ghost shows the ground too near to throw at")
			if inner != null:
				assert_almost_eq((inner.mesh as CylinderMesh).top_radius, float(_row(t)["min_range"]), 0.001, "as far as that")
		else:
			assert_null(inner, "%s has nothing too near" % t)
	main.cancel_building_selection()

func test_15_a_level_up_hits_harder() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0))
	var d = _animal("raptor", bow.global_position + Vector3(0.0, 0.0, -30.0))
	var row: Dictionary = _ammo("arrow_wood")
	bow.strike(d, row)
	assert_almost_eq(_lost(d), float(row["damage"]), 0.001, "at its first level, what the arrow does")
	stock_everything()
	var to: String = String(config_node.upgrade_targets("bow_tower")[0])
	assert_true(bow.begin_upgrade(to), "the upgrade is started")
	bow.add_upgrade_progress(1000.0)
	await wait_frames(2)
	var up: Node = null
	for n in tree.get_nodes_in_group(AmmoTower.GROUP):
		if is_instance_valid(n) and String(n.building_type) == to:
			up = n
	if up == null and String(bow.building_type) == to:
		up = bow
	assert_not_null(up, "it is the second level now")
	if up == null:
		return
	d.current_hp = 999.0
	up.strike(d, row)
	assert_almost_eq(_lost(d), float(row["damage"]) * float(config_node.damage_factor(to)), 0.001, "a level up, harder")

func test_16_what_shoots_at_a_raider_is_what_it_goes_for() -> void:
	var f: Array = await _field()
	var bow = await _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
	var drop = await _tower(f[1], "drop_tower", Vector2i(-8, 0), "log_round")
	var empty = await _tower(f[1], "drop_tower", Vector2i(-8, 6))
	var rack = await _tower(f[1], "bait_rack", Vector2i(8, 0))
	var spikes = f[1].place_at("ground_spikes", Vector2i(0, 4), _world, false)
	var d = _animal("raptor", bow.global_position + Vector3(2.5, 0.0, -2.5))
	await wait_frames(1)
	assert_true(d._is_shooter(bow), "the bow tower is what shoots at it")
	assert_true(d._is_shooter(drop), "and the drop tower")
	assert_false(d._is_shooter(empty), "but not one with nothing in it: it shoots nothing, a fence to them")
	assert_false(d._is_shooter(rack), "the bait rack shoots nothing")
	assert_false(d._is_shooter(spikes), "nor do spikes")
	d.shot_by(bow)
	assert_eq(d._shot_lately(), bow, "shot at, it knows what shot it")
	d._think()
	assert_eq(d.current_target, bow, "and goes for the tower")

func test_17_the_drop_tower_drops_on_no_man() -> void:
	var f: Array = await _field()
	var drop = await _tower(f[1], "drop_tower", Vector2i(0, 0), "log_round")
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	_world.add_child(hero)
	hero.global_position = drop.global_position + Vector3(1.5, 0.0, 0.0)
	hero.set_physics_process(false)
	var before: int = drop.uses_left
	await wait_physics_frames(int((_turn() + 0.5) * float(Engine.physics_ticks_per_second)))
	assert_null(drop.target_in_reach(), "he is not what it drops on")
	assert_eq(drop.uses_left, before, "no log dropped for him")

## Picked, a tower shows what it acts on in the reach's blue (Config.FEEDBACK.reach_color): its ring -- and the catapult
## the ground too near to throw at inside it -- not only under the ghost.
func test_18_picked_it_shows_its_reach_in_blue() -> void:
	var f: Array = await _field()
	var reach: Color = config_node.FEEDBACK["reach_color"]
	var bow = await _tower(f[1], "bow_tower", Vector2i(-8, 0), "arrow_wood")
	var drop = await _tower(f[1], "drop_tower", Vector2i(0, 0), "log_round")
	var cat = await _tower(f[1], "catapult", Vector2i(0, 10), "shot_stone")
	for t in [bow, drop, cat]:
		t.set_range_visible(true)
		assert_true(t.range_indicator.visible, "%s shows its ring" % t.building_type)
		var ring_mat := t.range_indicator.material_override as StandardMaterial3D
		assert_true(Color(ring_mat.albedo_color, 1.0).is_equal_approx(Color(reach, 1.0)), "in blue")
	var inner := cat.get_node_or_null("ZoneShown/Zone") as MeshInstance3D
	assert_not_null(inner, "the catapult shows the ground too near to throw at")
	if inner != null:
		assert_true(inner.is_visible_in_tree(), "shown while it is picked")
		assert_almost_eq((inner.mesh as CylinderMesh).top_radius, float(_row("catapult")["min_range"]), 0.001, "as far as that")
	assert_null(drop.get_node_or_null("ZoneShown"), "the drop tower's ring is all it acts on")
	for t in [bow, drop, cat]:
		t.set_range_visible(false)
	assert_false(cat.get_node("ZoneShown").visible, "and gone when it is not")
