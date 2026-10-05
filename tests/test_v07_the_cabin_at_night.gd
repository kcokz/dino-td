# res://tests/test_v07_the_cabin_at_night.gd
# The player's bug reports, 2026-10-04: "晚上植龙的逻辑不够聪明，而且crappy，人躲在cabin里它们头会伸进cabin，但没有进攻效
# 果"; "这个角度不仅植龙会卡住，人还不能移动"; and "植龙晚上不进攻cabin的吗？" -- then: "可以加一个属性，护甲，船舱的护甲比人高很
# 多……人造的塔护甲比船舱低但是比人高，恐龙也有护甲"; "因为舱内有灯光……植龙不会靠近，但如果人晚上就躲在舱内，植龙在没有篝火
# cover下会撞击船舱，有篝火处植龙就不会靠近了".
#
# In the cabin he is nobody's: what came for him goes at the cabin -- with its snout at the wall, not through it, never
# from in front of the door, and from a side no fire lights -- and a bite at the hull is what gets through its armour
# (Config.ARMOR). He can always come out. A dark night of it leaves the cabin standing.
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
	Engine.time_scale = 1.0
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	await nav_settled(main)
	return main

func _species() -> String:
	return String(game_state_node.map_data()["prowlers"].keys()[0])

func _at(part: String) -> float:
	return float(config_node.DAY["parts"][part])

func _set_clock(t: float, day: int = 1) -> void:
	game_state_node.day_clock = float(day - 1) * float(config_node.DAY["length"]) + t
	game_state_node._run_the_day(0.0)

func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## He goes in, and stays: inside the room, the cabin told so.
func _shut_in(main: Node) -> void:
	main.hero.global_position = main.current_core.door_inside()
	main.current_core.recheck_hero()
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(bool(main.current_core.hero_inside), "(he is in the cabin)")

## A phytosaur put down at `at`, making for the cabin, driven by hand.
func _phytosaur(main: Node, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(_species()))).new()
	d.setup(_species())
	d.home = at
	d.waypoints = [at, main.current_core.global_position] as Array[Vector3]
	d.position = at
	main.dinos_container.add_child(d)
	d.setup(_species())
	d.set_physics_process(false)
	return d

func _drive(d: Node, seconds: float) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	var i: int = 0
	while t < seconds and is_instance_valid(d):
		d.advance_towards_waypoint(dt)
		t += dt
		i += 1
		if i % 4 == 0:
			await tree.physics_frame

## A lit campfire `off` from the cabin's middle.
func _campfire(main: Node, off: Vector3) -> Node:
	stock_everything()
	var at: Vector3 = main.current_core.global_position + off
	var fire = main.build_system.place_at("campfire", main.grid_manager.world_to_build_cell(at), main.buildings_container)
	fire._tend(99.0)
	return fire

## How much of a bite of `amount` gets into `node`, from Config.ARMOR.
func _through(node: Object, amount: float) -> float:
	var scale: float = float(config_node.ARMOR["scale"])
	return amount * scale / (scale + float(config_node.armour_of(node)))

func test_01_armour_the_hull_most_the_towers_some_him_none() -> void:
	var main = await _level()
	var cabin = main.current_core
	var by_kind: Dictionary = config_node.ARMOR["by_kind"]
	assert_almost_eq(float(config_node.armour_of(cabin)), float(by_kind["core"]), 0.001, "The cabin's armour is its kind's")
	assert_almost_eq(float(config_node.armour_of(main.hero)), float(config_node.ARMOR["hero"]), 0.001, "his is his")
	stock_everything()
	var tower = main.build_system.place_at("bow_tower", main.grid_manager.world_to_build_cell(cabin.global_position + Vector3(14.0, 0.0, 12.0)),
		main.buildings_container, true)
	assert_not_null(tower, "(a bow tower put up away from the cabin)")
	tower.complete_construction()
	assert_gt(float(config_node.armour_of(cabin)), float(config_node.armour_of(tower)), "The hull is harder than a tower")
	assert_gt(float(config_node.armour_of(tower)), float(config_node.armour_of(main.hero)), "and a tower than a man (\"比船舱低但是比人高\")")
	# What gets through: the same blow, less into what is harder.
	assert_almost_eq(float(config_node.through_armour(main.hero, 8.0)), _through(main.hero, 8.0), 0.0001, "Into him, the blow as armour leaves it")
	assert_lt(float(config_node.through_armour(cabin, 8.0)), float(config_node.through_armour(tower, 8.0)), "less into the hull than a tower")
	assert_almost_eq(float(config_node.through_armour(cabin, 8.0)), _through(cabin, 8.0), 0.0001, "scale / (scale + armour) of it")
	var d = _phytosaur(main, cabin.global_position + Vector3(-12.0, 0.0, -6.0))
	assert_almost_eq(float(config_node.armour_of(d)), float(config_node.DINOS[_species()].get("armour", 0.0)), 0.001,
		"An animal's is its species'")
	# A bite, then, at the cabin: what gets through its armour is what it loses.
	_set_clock(_at("night") + 10.0)
	_shut_in(main)
	d.global_position = cabin.global_position + Vector3(-float(config_node.get_building_half("core").x) - float(d.front_reach()) + 0.2, 0.0, 0.0)
	d.current_target = cabin
	var hp: float = cabin.current_hp
	d.attack_target(cabin)
	assert_almost_eq(hp - cabin.current_hp, _through(cabin, float(d.damage)), 0.0001, "A bite at the hull: what its armour lets through")

func test_02_in_the_cabin_he_is_nobodys_and_they_go_at_the_cabin() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	var cabin = main.current_core
	_shut_in(main)
	var hero_hp: float = main.hero.current_hp
	var d = _phytosaur(main, cabin.global_position + Vector3(-14.0, 0.0, 2.0))
	assert_false(d._is_target_valid(main.hero), "Shut in the cabin, he is nobody's to bite")
	var cabin_hp: float = cabin.current_hp
	await _drive(d, 14.0)
	assert_eq(d.current_target, cabin, "What came for him goes at the cabin")
	assert_lt(cabin.current_hp, cabin_hp, "and bites it -- to effect")
	assert_almost_eq(main.hero.current_hp, hero_hp, 0.0001, "He is not bitten through its walls")
	# He comes out: he is its again.
	main.hero.process_mode = Node.PROCESS_MODE_INHERIT
	main.hero.global_position = cabin.door_outside()
	cabin.recheck_hero()
	assert_false(bool(cabin.hero_inside), "(he is out)")
	assert_true(d._is_target_valid(main.hero), "Out in the dark, he is its quarry again")

func test_03_it_bites_the_cabin_with_its_snout_at_the_wall_not_through_it() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	var cabin = main.current_core
	_shut_in(main)
	var d = _phytosaur(main, cabin.global_position + Vector3(-14.0, 0.0, 2.0))
	await _drive(d, 14.0)
	assert_eq(int(d.mode), int(Dino.Mode.ATTACK), "It is biting the cabin")
	var front: float = float(d.front_reach())
	assert_gt(front, float(d._avoid_radius) + 1.0, "(its snout is far ahead of its middle)")
	var gap: float = float(config_node.gap_to_building(d.global_position, "core", cabin.global_position))
	assert_gt(gap, front - float(config_node.DINO_AI["snout_into"]) - 0.6, "Its middle stands out from the wall by its snout")
	# Its snout, the way it faces, is at the wall: not in the room.
	var nose: Vector3 = d.global_position - d.global_transform.basis.z.normalized() * front
	assert_false(cabin.is_inside(nose), "its head is not in the room with him")
	assert_lt(float(config_node.gap_to_building(nose, "core", cabin.global_position)), 0.8, "but at its wall")

func test_04_nothing_bites_from_in_front_of_the_door_and_he_can_come_out() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	var cabin = main.current_core
	Dino.clear_all_attack_slots()
	var d = _phytosaur(main, cabin.door_outside() + Vector3(0.0, 0.0, 6.0))
	Dino.claim_attack_slot(cabin, d)
	for s in Dino.attack_slots()[cabin.get_instance_id()]:
		assert_false(cabin.at_the_door(s["pos"]), "No place round the cabin to bite from is in front of its door")
	Dino.release_attack_slot(cabin, d)
	_shut_in(main)
	await _drive(d, 16.0)
	assert_false(cabin.at_the_door(d.global_position), "Come at the door, it goes round to bite from beside it")
	assert_eq(int(d.mode), int(Dino.Mode.ATTACK), "(biting)")
	# A second at the door: from there a bite does not reach.
	var e = _phytosaur(main, cabin.door_outside() + Vector3(0.0, 0.0, 2.0))
	assert_false(e._target_in_reach(cabin), "From in front of the door, the cabin is not bitten")
	e.queue_free()
	# And he walks out, and away.
	main.hero.process_mode = Node.PROCESS_MODE_INHERIT
	d.set_physics_process(false)
	main.order_leave_cabin()
	var out: bool = false
	for i in range(int(4.0 * float(Engine.physics_ticks_per_second))):
		await tree.physics_frame
		if not bool(cabin.hero_inside) and _flat_gap(main.hero.global_position, cabin.door_outside()) < 0.6:
			out = true
			break
	assert_true(out, "He comes out of the door while they bite the cabin")

func test_05_a_fire_by_the_cabin_it_goes_at_the_dark_side() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	var cabin = main.current_core
	_shut_in(main)
	# A campfire off the cabin's west end: that end lit, the east end dark.
	var fire = _campfire(main, Vector3(-float(config_node.get_building_half("core").x) - 2.5, 0.0, 2.5))
	var light: float = float(fire.light_radius())
	assert_gt(light, 1.0, "(the fire burns)")
	var d = _phytosaur(main, cabin.global_position + Vector3(0.0, 0.0, -14.0))
	await _drive(d, 20.0)
	assert_eq(d.current_target, cabin, "It still goes at the cabin")
	assert_true(ProwlerDino.light_over(tree, d.global_position).is_empty(), "from where no fire lights it")
	assert_true(ProwlerDino.light_over(tree, d._engage_spot()).is_empty(), "its place there in the dark")

## A dark night, measured: the hero shut in the cabin from dusk to dawn, no fire, the night's phytosaurs at it as
## NightProwl sends them -- the cabin is still standing at first light.
func test_06_a_dark_night_at_the_cabin_leaves_it_standing() -> void:
	var main = await _level()
	var cabin = main.current_core
	_set_clock(_at("night") - 0.5)
	_shut_in(main)
	var hp: float = cabin.current_hp
	Engine.time_scale = 4.0
	var sent: int = 0
	var bitten_from: Dictionary = {}
	while String(game_state_node.day_part()) != "day" and is_instance_valid(cabin) and not bool(cabin.is_destroyed):
		await tree.physics_frame
		sent = maxi(sent, tree.get_nodes_in_group(ProwlerDino.GROUP).size())
		for p in tree.get_nodes_in_group(ProwlerDino.GROUP):
			if int(p.mode) == int(Dino.Mode.ATTACK):
				bitten_from[p.get_instance_id()] = true
	Engine.time_scale = 1.0
	var lost: float = hp - (cabin.current_hp if is_instance_valid(cabin) else 0.0)
	print("  [MEASURE] a dark night: %d phytosaurs out at most, %d bit the cabin; it lost %.1f of %.0f (%.0f%%) -- %.1f raw" % [
		sent, bitten_from.size(), lost, hp, 100.0 * lost / hp, lost / _through(cabin, 1.0)])
	assert_gt(bitten_from.size(), 0, "They came at the cabin")
	assert_gt(lost, 0.0, "and it was bitten")
	assert_true(is_instance_valid(cabin) and not bool(cabin.is_destroyed), "A dark night of it leaves the cabin standing")

## The same night with a campfire before the cabin: half as many come up (PROWL.most_lit), none bites from where its
## light is, and the cabin loses less than a dark night's worth.
func test_07_a_fire_before_it_halves_the_night() -> void:
	var main = await _level()
	var cabin = main.current_core
	_set_clock(_at("night") - 0.5)
	_shut_in(main)
	var fire = _campfire(main, Vector3(-3.0, 0.0, float(config_node.get_building_half("core").y) + 2.5))
	assert_true(main.night_prowl.camp_lit(), "(the camp is lit)")
	var hp: float = cabin.current_hp
	Engine.time_scale = 4.0
	var sent: int = 0
	var lit_biters: int = 0
	while String(game_state_node.day_part()) != "day" and is_instance_valid(cabin) and not bool(cabin.is_destroyed):
		await tree.physics_frame
		fire._tend(99.0)
		sent = maxi(sent, tree.get_nodes_in_group(ProwlerDino.GROUP).size())
		for p in tree.get_nodes_in_group(ProwlerDino.GROUP):
			if int(p.mode) == int(Dino.Mode.ATTACK) and not ProwlerDino.light_over(tree, p.global_position).is_empty():
				lit_biters += 1
	Engine.time_scale = 1.0
	var lost: float = hp - cabin.current_hp
	print("  [MEASURE] a night with a campfire: %d out at most; it lost %.1f of %.0f (%.0f%%)" % [sent, lost, hp, 100.0 * lost / hp])
	assert_true(sent <= int(config_node.PROWL["most_lit"]), "No more came up than may by a fire")
	assert_eq(lit_biters, 0, "None bit the cabin from where the fire lit it")
	var dark_most: float = _through(cabin, float(config_node.DINOS[_species()]["damage"]) * float(config_node.DINOS[_species()]["attack_rate"])) \
		* float(config_node.PROWL["most_dark"]) * (float(config_node.DAY["length"]) - _at("night"))
	assert_lt(lost, dark_most * 0.5, "and it lost less than half of what four could do in the dark")
