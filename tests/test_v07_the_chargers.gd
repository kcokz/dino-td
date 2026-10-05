# res://tests/test_v07_the_chargers.gd
# The player, 2026-10-04: "恐龙进攻船舱是出于对不明物体的恐惧……食草恐龙也可以进攻船舱因为受到惊吓" (GAME-DESIGN 3.0).
#
# THE FRIGHTENED CHARGERS: plant-eaters the capsule's fall frightened -- Desmatosuchus at the first station, the
# Stegosaurus at the second -- come with the raids to ram the strange thing that fell into their valley. Armoured: an
# arrow goes into them a quarter of itself, what crushes goes in whole. At the cabin through what is in the way, the
# man no matter to them. And afraid of fire: in a fire's light they turn tail and run off the field, not killed.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

const CHARGERS: Array[String] = ["desmatosuchus", "stegosaurus"]

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _row(species: String) -> Dictionary:
	return config_node.DINOS[species]

func _field() -> void:
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)

## A `species` put down at `at`, its mind on but its body still (a test drives its thinking).
func _animal(species: String, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	_world.add_child(d)
	d.setup(species)
	d.global_position = Vector3(at.x, 0.0, at.z)
	d.set_physics_process(false)
	return d

func _raiders_from(map: Dictionary, species: String) -> int:
	for step in map.get("raiders_by_day", []):
		if Dictionary(step.get("raiders", {})).has(species):
			return int(step["from_day"])
	return -1

## The first raid `species` comes with on `map`: the first step of its raiders_by_day that has it, and that step's
## `from_raid`, or the first raid of its day.
func _from_raid(map: Dictionary, species: String) -> int:
	for step in map.get("raiders_by_day", []):
		if Dictionary(step.get("raiders", {})).has(species):
			return int(step.get("from_raid", 0)) if int(step.get("from_raid", 0)) > 0 else 1000 * int(step["from_day"])
	return -1

func test_01_the_chargers_are_armoured_plant_eaters_with_the_raids() -> void:
	for species in CHARGERS:
		var row: Dictionary = _row(species)
		assert_eq(String(row["behaviour"]), "charger", "%s charges" % species)
		assert_true(bool(row.get("armored", false)), "%s is armoured" % species)
		assert_eq(String(config_node.get_dino_script_path(species)), "res://scripts/entities/ChargerDino.gd",
			"%s is a ChargerDino" % species)
		assert_gt(int(row["drops"].get("food", 0)), 0, "%s leaves meat" % species)
		assert_gt(int(row["drops"].get("bone", 0)), 0, "and bone")
		assert_true(VisualLibrary.has_art("dino/%s" % species), "%s is drawn as itself" % species)
		assert_false(Dictionary(row.get("gaits", {})).is_empty(), "%s strides at its own paces" % species)
	assert_gt(_from_raid(config_node.map_data("valley"), "desmatosuchus"), 1,
		"Desmatosuchus comes with the first station's raids, from the second (the first is the pack alone: supply)")
	assert_gt(_raiders_from(config_node.map_data("morrison"), "stegosaurus"), 1,
		"the Stegosaurus with the second's")
	assert_true(bool(_row("stegosaurus").get("heavy", false)), "the Stegosaurus is heavy: only a weighted log shoves it")

func test_02_arrows_hardly_hurt_it_and_what_crushes_does() -> void:
	await _field()
	var d = _animal("desmatosuchus", Vector3.ZERO)
	var arrow: Dictionary = config_node.AMMO["arrow_wood"]
	var log_row: Dictionary = config_node.AMMO["log_round"]
	assert_almost_eq(float(AmmoTower.armour_factor(d, arrow)), float(config_node.ARMOR["pierce"]), 0.001,
		"an arrow goes in a quarter of itself")
	assert_almost_eq(float(AmmoTower.armour_factor(d, log_row)), 1.0, 0.001, "a dropped log whole")
	assert_almost_eq(float(AmmoTower.armour_factor(d, config_node.AMMO["shot_stone"])), 1.0, 0.001, "a thrown stone whole")

func test_03_it_goes_for_what_stands_in_its_way_not_the_man() -> void:
	await _field()
	var d = _animal("desmatosuchus", Vector3.ZERO)
	assert_eq(float(d.hero_interest_range()), 0.0, "the man is no matter to it")
	assert_false(d.walks_round_walls(), "and it goes through a wall, not round it")
	assert_gt(float(d.building_interest_range()), 2.0, "it is here for what is built")

func test_04_in_a_fires_light_it_turns_and_runs() -> void:
	await _field()
	var d = _animal("desmatosuchus", Vector3(0.0, 0.0, 0.0))
	d.came_in_at = Vector3(30.0, 0.0, 0.0)
	d._think()
	assert_false(d.going_home, "nothing burning, it comes on")
	var patch = FirePatch.ignite(_world, Vector3(1.0, 0.0, 0.0), config_node.AMMO["fire_pot"])
	_cleanup_nodes.append(patch)
	await wait_frames(1)
	d._think()
	assert_true(d.frightened, "in a fire's light, it takes fright")
	assert_true(d.going_home, "and runs")
	assert_false(d.is_dead, "not killed")
	var last: Vector3 = d.waypoints[d.waypoints.size() - 1]
	assert_lt(Vector2(last.x - 30.0, last.z).length(), 0.5, "off the field the way it came")

func test_05_a_cold_campfire_does_not_turn_it() -> void:
	await _field()
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	stock_everything()
	var fire = bs.place_at("campfire", Vector2i(0, 0), _world, false)
	assert_not_null(fire, "a campfire")
	if fire == null:
		return
	fire.complete_construction()
	assert_eq(float(fire.light_radius()), 0.0, "by day it is not lit")
	var d = _animal("desmatosuchus", fire.global_position + Vector3(1.5, 0.0, 0.0))
	d._think()
	assert_false(d.frightened, "a cold fire frightens nothing")

func test_05b_the_first_raid_is_the_pack_alone_then_the_armoured_come_more_by_the_day() -> void:
	# The player, 2026-10-04 ("落木塔和弓塔就按照你说的，调整"): the bow tower's counter, sooner and more.
	# Our own game, whatever an earlier test left the run's settings at (a custom game's longer day).
	game_state_node.game = {}
	game_state_node.reset_game()
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var wm = main.wave_manager
	wm.auto_raid_enabled = false
	var steps: Array = game_state_node.map_data().get("raiders_by_day", [])
	var share := func(day: int, raid: int) -> float:
		var length: float = float(config_node.DAY["length"]) * float(game_state_node.run_scale("day_length"))
		game_state_node.day_clock = length * float(day - 1) + 10.0
		game_state_node._run_the_day(0.0)
		assert_eq(int(game_state_node.day_number()), day, "(the clock on day %d)" % day)
		wm.current_wave = raid
		var n: int = 0
		for i in 400:
			if wm._species_to_spawn() == "desmatosuchus":
				n += 1
		return float(n) / 400.0
	var weight := func(day: int, raid: int) -> float:
		var out: Dictionary = game_state_node.map_data().get("raiders", {})
		for step in steps:
			if int(step.get("from_day", 1)) <= day and int(step.get("from_raid", 0)) <= raid:
				out = step["raiders"]
		var total: float = 0.0
		for k in out:
			total += float(out[k])
		return float(out.get("desmatosuchus", 0.0)) / total
	assert_almost_eq(share.call(1, 1), 0.0, 0.0001, "The first raid is the pack alone: the run's supply")
	assert_gt(weight.call(1, 2), 0.0, "From the second raid the armoured come")
	assert_almost_eq(share.call(1, 2), weight.call(1, 2), 0.06, "as many as the map says (%.2f)" % weight.call(1, 2))
	assert_gt(weight.call(2, 6), weight.call(1, 2), "and more from the second day")
	assert_almost_eq(share.call(2, 6), weight.call(2, 6), 0.06, "(%.2f)" % weight.call(2, 6))

func test_06_its_strides_are_drawn_at_its_own_pace() -> void:
	await _field()
	var d = _animal("desmatosuchus", Vector3.ZERO)
	await wait_frames(1)
	assert_not_null(d.animator, "it has an animator")
	if d.animator != null:
		assert_eq(d.animator.own_gaits, _row("desmatosuchus")["gaits"], "its own paces, not a raptor's")
