# res://tests/test_v06_the_opening.gd
# v0.6 feedback on the opening: "初始木栅栏强度很低，需要把迅猛龙强度稍微调低，船舱血量提升到100，
# 这样船舱的攻击能打败初始迅猛龙" and "除了木栅栏需要再想一个初始的防御建筑".
#
# The cabin stands a hundred hits and shoots what comes near it -- enough for the first
# raid, not for a big one -- and the opening has a second defence made of wood: a bow tower,
# weaker than the crossbow tower that comes with stone and bone.
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
	clear_drops()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _row(type_id: String) -> Dictionary:
	return config_node.BUILDINGS[type_id]

func _dps(type_id: String) -> float:
	return float(_row(type_id)["damage"]) * float(_row(type_id)["fire_rate"])

## Seconds for a building of `type_id` to shoot `count` raptors dead, one after another.
func _seconds_to_kill(type_id: String, count: int) -> float:
	var shots_each: float = ceil(raptor_stat("hp") / float(_row(type_id)["damage"]))
	return float(count) * shots_each / float(_row(type_id)["fire_rate"])

# ==============================================================================
# 1. The cabin
# ==============================================================================

func test_01_the_cabin_shoots_what_comes_near_it() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var cabin = main.current_core
	assert_almost_eq(float(cabin.max_hp), core_hp(), 0.001, "The cabin stands as many hits as Config says")
	assert_almost_eq(float(cabin.attack_range), float(_row("core")["range"]), 0.001, "It has a gun, with the reach Config gives it")
	var raptor = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(raptor)
	main.add_child(raptor)
	raptor.setup("raptor")
	raptor.set_physics_process(false)
	raptor.global_position = cabin.global_position + Vector3(float(_row("core")["range"]) * 0.6, 0.0, 0.0)
	await wait_physics_frames(2)
	await wait_seconds(1.0 / float(_row("core")["fire_rate"]) + 0.3)
	assert_lt(float(raptor.current_hp), raptor_stat("hp"), "A raptor that comes near is shot")
	assert_not_null(cabin.find_child("Head", true, false), "From the gun on its roof")

func test_02_by_itself_it_outlasts_the_first_raid_and_not_a_big_one() -> void:
	# Worst case -- every raptor biting the whole time it takes the gun to kill them all.
	var first: int = int(config_node.WAVES["base_count"])
	var first_bites: float = float(first) * raptor_stat("damage") * _seconds_to_kill("core", first)
	assert_lt(first_bites, core_hp(), "The first raid, all of it biting, cannot bring the cabin down before its gun is done")
	var big: int = int(ceil(float(first + int(config_node.WAVES["count_per_wave"]) * (int(config_node.WAVES["big_every"]) - 1))
		* float(config_node.WAVES["big_multiplier"])))
	var big_bites: float = float(big) * raptor_stat("damage") * _seconds_to_kill("core", big)
	assert_gt(big_bites, core_hp(), "A big raid could: the cabin alone is not a defence")

# ==============================================================================
# 2. The bow tower
# ==============================================================================

func test_03_the_opening_has_a_tower_made_of_wood() -> void:
	assert_has(config_node.BUILDABLE_TYPES, "bow_tower", "The bow tower is on the build menu")
	var cost: Dictionary = _row("bow_tower")["cost"]
	assert_eq(cost.keys(), ["wood"], "Wood and nothing else: it can be built from the first minute")
	assert_eq(String(config_node.get_building_kind("bow_tower")), "tower", "And it shoots")
	assert_lte(total_price_of("bow_tower"), opening_wood(), "The opening's wood pays for one")

func test_04_it_shoots_less_than_the_crossbow_and_more_than_a_stake() -> void:
	assert_lt(_dps("bow_tower"), _dps("tower"), "Slower than the crossbow tower it gives way to")
	assert_lt(float(_row("bow_tower")["range"]), float(_row("tower")["range"]), "And not as far")
	assert_gt(_dps("bow_tower"), config_node.get_contact_dps("wall"), "But it does more than a stake's spikes")
	assert_gt(total_price_of("bow_tower"), total_price_of("wall"), "And costs more than a stake")

func test_05_its_bow_turns_to_what_it_shoots() -> void:
	var body: Node3D = VisualLibrary.make("building/bow_tower")
	_cleanup_nodes.append(body)
	assert_true(VisualLibrary.has_art("building/bow_tower"), "It is a model")
	var head := body.find_child("Head", true, false)
	assert_not_null(head, "Its bow is a part that turns")
	if head:
		assert_not_null(head.find_child("Muzzle", true, false), "And shoots from the arrow's point")
