# res://tests/test_v07_the_tower_tops.gd
# The player, 2026-10-05: "把后面几关都先做起来，主要是科技树升级部分".
#
# THE BOW TOWER'S TOP, ONE OF TWO (GAME-DESIGN 6.1 rule 2: "每条线的最后一级分叉，二选一……比如弩塔最后分成连弩和床弩"):
# iron on the third level's tower -- the repeater, quick and near, for a swarm; or the ballista, which turns to the
# toughest thing in its long reach and drives a bolt through it and on into what is behind. And a way up is offered
# only where what it takes can be had: no iron at a station that cannot make any, no bricks before the kiln.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

const TOPS: Array[String] = ["bow_tower_repeater", "bow_tower_ballista"]

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

func _tower(bs: Node, type_id: String, cell: Vector2i, ammo: String) -> Node:
	stock_everything()
	var t = bs.place_at(type_id, cell, _world, false)
	assert_not_null(t, "%s goes down" % type_id)
	if t == null:
		return null
	if not t.is_constructed:
		t.complete_construction()
	t.set_ammo(ammo)
	t.load_from_stock()
	return t

## A raptor standing still at `at`, hard to kill, `hp` of it left.
func _animal(at: Vector3, hp: float = 999.0) -> Node:
	var d = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(d)
	_world.add_child(d)
	d.setup("raptor")
	d.max_hp = 999.0
	d.current_hp = hp
	d.global_position = Vector3(at.x, 0.0, at.z)
	d.set_physics_process(false)
	return d

func _until(done: Callable, seconds: float) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds and not bool(done.call()):
		await tree.physics_frame
		t += dt

func test_01_the_third_level_goes_one_of_two_ways_for_iron() -> void:
	var ways: Array = config_node.upgrade_targets("bow_tower_3")
	for top in TOPS:
		assert_has(ways, top, "The third level's bow tower can become the %s" % top)
		assert_eq(config_node.upgrade_cost("bow_tower_3", top).keys(), ["iron"], "for iron alone (4.1 rule 2: one material a step)")
		assert_eq(int(config_node.tower_level(top)), 4, "a fourth level")
		assert_eq(String(_row(top)["kind"]), "bow", "still a bow tower")
		assert_eq(int(config_node.get_building_cells(top)), int(config_node.get_building_cells("bow_tower")), "on the same plinth")
		assert_true(config_node.upgrade_targets(top).is_empty(), "and the end of its line: the choice is for good")
		assert_true(ResourceLoader.exists(String(config_node.ICON_DIR) + "bow_tower.svg"), "(drawn as the bow tower)")
		for word in [String(_row(top)["name"])]:
			assert_ne(tr(word), word, "%s is named" % top)
	var three: Dictionary = _row("bow_tower_3")
	var rep: Dictionary = _row("bow_tower_repeater")
	var bal: Dictionary = _row("bow_tower_ballista")
	assert_lt(float(rep["fire_seconds"]), float(three["fire_seconds"]), "The repeater shoots quicker")
	assert_lt(float(rep["range"]), float(three["range"]), "and nearer")
	assert_gt(float(bal["range"]), float(three["range"]), "The ballista reaches further")
	assert_gt(float(bal["fire_seconds"]), float(three["fire_seconds"]), "and shoots slower")
	assert_gt(float(bal["damage_factor"]), float(three["damage_factor"]), "and harder")
	assert_gt(int(bal.get("pierce", 1)), 1, "driving its bolt on through")
	# The two ways are worth something: a quicker tower is not simply worse than the third level.
	var dps3: float = float(three["damage_factor"]) / float(three["fire_seconds"])
	assert_gt(float(rep["damage_factor"]) / float(rep["fire_seconds"]), dps3, "the repeater does more in a minute than the third level")

func test_02_the_ballista_turns_to_the_toughest_in_its_reach_and_drives_through() -> void:
	var f: Array = await _field()
	var bal = _tower(f[1], "bow_tower_ballista", Vector2i(0, 0), "arrow_wood")
	if bal == null:
		return
	var here: Vector3 = bal.global_position
	var reach: float = float(_row("bow_tower_ballista")["range"])
	var weak = _animal(here + Vector3(2.5, 0.0, 0.0), 100.0)
	var tough = _animal(here + Vector3(0.0, 0.0, -reach * 0.6), 900.0)
	var pierce: int = int(_row("bow_tower_ballista")["pierce"])
	var step: float = float(config_node.TOWERS["pierce_reach"]) / float(pierce)
	var behind: Array = []
	for k in pierce:
		behind.append(_animal(tough.global_position + Vector3(0.0, 0.0, -step * float(k + 1) * 0.9), 500.0))
	await wait_physics_frames(2)
	assert_almost_eq(float(tough.current_hp), 900.0, 0.001, "It does not shoot at once: it turns to aim first")
	await _until(func(): return float(tough.current_hp) < 900.0, float(config_node.TOWERS["turn_seconds"]) + 2.0)
	var dmg: float = float(config_node.AMMO["arrow_wood"]["damage"]) * float(config_node.damage_factor("bow_tower_ballista"))
	assert_almost_eq(900.0 - float(tough.current_hp), dmg, 0.01, "It shot the toughest in its reach, a bolt's worth")
	assert_almost_eq(float(weak.current_hp), 100.0, 0.001, "not the nearer, weaker one")
	for k in pierce - 1:
		assert_almost_eq(500.0 - float(behind[k].current_hp), dmg, 0.01, "the bolt went on into the %d-th behind it" % (k + 1))
	assert_almost_eq(float(behind[pierce - 1].current_hp), 500.0, 0.001, "and no further than its pierce")

func test_03_the_repeater_shoots_quick() -> void:
	var f: Array = await _field()
	var rep = _tower(f[1], "bow_tower_repeater", Vector2i(0, 0), "arrow_wood")
	if rep == null:
		return
	var d = _animal(rep.global_position + Vector3(3.0, 0.0, 0.0))
	var secs: float = float(_row("bow_tower_repeater")["fire_seconds"])
	var one: float = float(config_node.AMMO["arrow_wood"]["damage"]) * float(config_node.damage_factor("bow_tower_repeater"))
	await _until(func(): return 999.0 - float(d.current_hp) >= one * 3.0 - 0.01, secs * 3.0 + 1.5)
	assert_gte(999.0 - float(d.current_hp), one * 3.0 - 0.01, "Three bolts in little more than three of its beats")
	assert_lt(secs * 3.0, float(_row("bow_tower_3")["fire_seconds"]) * 2.0, "where the third level would have shot not twice")

func test_04_a_way_up_is_offered_only_where_what_it_takes_can_be_had() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	stock_everything()
	for res_id in ["iron", "brick"]:
		game_state_node.resources[res_id] = 0
		game_state_node.known.erase(res_id)
	assert_false(game_state_node.within_reach({"iron": 1}), "No iron to be had on the first station's map")
	assert_false(game_state_node.within_reach({"brick": 1}), "nor bricks")
	assert_true(game_state_node.within_reach({"stone": 1, "bone": 1}), "stone and bone are, by work")
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + Vector2i(5, 5)
	stock_everything()
	game_state_node.resources["iron"] = 0
	game_state_node.resources["brick"] = 0
	game_state_node.known.erase("iron")
	game_state_node.known.erase("brick")
	var tower = main.build_system.place_at("bow_tower_3", cell, main.buildings_container, false)
	if tower == null:
		return
	tower.complete_construction()
	var panel = main.hud.option_panel
	tree.root.get_node("EventBus").unit_selected.emit(tower)
	await wait_frames(1)
	var ways: Node = panel.button_container.find_child(String(panel.UPGRADES_NAME), true, false)
	assert_null(ways, "At the first station the third level's card offers no top: nothing there makes iron")
	game_state_node.add_resource("iron", 3)
	panel._refresh_ui()
	await wait_frames(1)
	ways = panel.button_container.find_child(String(panel.UPGRADES_NAME), true, false)
	assert_not_null(ways, "Iron come by, both ways up are offered")
	if ways != null:
		var names: Array = []
		for btn in ways.get_children():
			names.append(String((btn as Button).text))
		for top in TOPS:
			assert_has(names, String(config_node.get_building_name(top)), "the %s among them" % top)
