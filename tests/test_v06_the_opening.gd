# res://tests/test_v06_the_opening.gd
# v0.6 feedback on the opening: "初始木栅栏强度很低，需要把迅猛龙强度稍微调低，船舱血量提升到100，
# 这样船舱的攻击能打败初始迅猛龙" and "除了木栅栏需要再想一个初始的防御建筑".
#
# The cabin stands a hundred hits and shoots what comes near it -- enough for the first
# raid, not for a big one -- and the opening has a second defence made of wood: a trip bow,
# weaker than the set crossbow that comes with stone and bone. It was a bow tower that aimed by
# itself, until v0.6 round two ("Bow tower作为初始防御太过于强大……防御装置自动可以攻击需要合理解释").
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

## Damage a second to one animal: the cabin's gun at its rate of fire, a trap as fast as it is
## re-armed.
func _dps(type_id: String) -> float:
	var row: Dictionary = _row(type_id)
	if row.has("fire_rate"):
		return float(row["damage"]) * float(row["fire_rate"])
	return float(row["damage"]) / float(row["rearm_seconds"])

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
# 2. The trip bow
# ==============================================================================

func test_03_the_opening_has_a_trap_made_of_wood() -> void:
	assert_has(config_node.BUILDABLE_TYPES, "trip_bow", "The trip bow is on the build menu")
	var cost: Dictionary = _row("trip_bow")["cost"]
	assert_eq(cost.keys(), ["wood"], "Wood and nothing else: it can be set from the first minute")
	assert_eq(String(config_node.get_building_kind("trip_bow")), "trap", "A trap: an animal on its wire looses it")
	assert_false(_row("trip_bow").has("range"), "It aims at nothing")
	assert_lte(total_price_of("trip_bow"), opening_wood(), "The opening's wood pays for one")

func test_04_it_does_less_than_the_set_crossbow_and_more_than_a_stake() -> void:
	assert_lt(_dps("trip_bow"), _dps("set_crossbow"), "Less to one animal than the set crossbow it gives way to")
	assert_lt(int(_row("trip_bow")["lane"]), int(_row("set_crossbow")["lane"]), "Along a shorter wire")
	assert_false(bool(_row("trip_bow")["pierce"]), "And one animal a shot, where the crossbow's bolt goes through them all")
	assert_lt(float(_row("trip_bow")["damage"]), raptor_stat("hp"), "One arrow does not kill a raptor")
	assert_gt(_dps("trip_bow"), config_node.get_contact_dps("wall"), "But it does more than a stake's spikes")
	assert_gt(total_price_of("trip_bow"), total_price_of("wall"), "And costs more than a stake")

func test_05_its_string_is_drawn_and_an_arrow_is_on_it() -> void:
	var body: Node3D = VisualLibrary.make("building/trip_bow")
	_cleanup_nodes.append(body)
	assert_true(VisualLibrary.has_art("building/trip_bow"), "It is a model")
	assert_not_null(body.find_child("String", true, false), "With a string the game draws back (Trap.gd)")
	assert_not_null(body.find_child("Arrow", true, false), "And an arrow on it")
