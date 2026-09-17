# res://tests/test_v04_dino_behaviour.gd
# v0.4: a dinosaur's habits live in its class, and an attack has a reach.
#
# Two bugs came out of the same hole. An attack had no notion of distance, so once
# something latched onto the Hero it kept hurting him from anywhere on the map, and
# it kept standing in front of a target it could no longer touch -- which is what
# "the raid goes stupid after the Hero pulls away" looked like from outside.
#
# The habits are a class rather than a flag so two species that fight the same way
# share one outright: a second small pack species is a Config entry and no code.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var wall_script: GDScript = null
var tower_script: GDScript = null
var hero_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	wall_script = load("res://scripts/entities/Wall.gd")
	tower_script = load("res://scripts/entities/Tower.gd")
	hero_script = load("res://scripts/entities/Hero.gd")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	clear_drops()
	Dino.clear_all_attack_slots()
	super.after_each()

func _dino(type_id: String, at: Vector3 = Vector3.ZERO) -> Node:
	var script: GDScript = load(config_node.get_dino_script_path(type_id))
	var d = script.new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.position = at
	d.setup(type_id)
	return d

func _spawn(script: GDScript, at: Vector3) -> Node:
	var n = script.new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = at
	if n.has_method("complete_construction"):
		n.complete_construction()
	return n

# ==============================================================================
# 1. An attack has a reach
# ==============================================================================

func test_01_nothing_is_bitten_from_across_the_map() -> void:
	# The bug: the Hero walked away and went on taking damage until he died.
	var dino = _dino("raptor", Vector3.ZERO)
	var hero = _spawn(hero_script, Vector3(40.0, 0.0, 0.0))
	await wait_frames(1)

	dino.on_obstacle_detected(hero)
	var hp_before: float = hero.current_hp
	dino.perform_attack()
	assert_eq(hero.current_hp, hp_before, "Out of reach is out of reach")

	assert_null(dino.current_target, "Finding him out of reach, it lets go rather than hammering away")

	# He comes back within reach and it re-engages.
	hero.global_position = dino.global_position + Vector3(dino.attack_reach() * 0.5, 0.0, 0.0)
	dino.on_obstacle_detected(hero)
	dino.perform_attack()
	assert_lt(hero.current_hp, hp_before, "Close enough, and it bites")

func test_02_a_target_that_walks_away_is_let_go() -> void:
	# The other half of the same bug: it stood frozen in front of something it
	# could not touch instead of getting on with the raid.
	var dino = _dino("raptor", Vector3.ZERO)
	var hero = _spawn(hero_script, Vector3(1.0, 0.0, 0.0))
	await wait_frames(1)

	dino.on_obstacle_detected(hero)
	assert_eq(int(dino.current_state), int(dino.State.ATTACKING), "It is on him")

	hero.global_position = Vector3(40.0, 0.0, 0.0)
	dino._process_attacking(0.0)
	assert_null(dino.current_target, "It lets go")
	assert_eq(int(dino.current_state), int(dino.State.WALKING), "And goes back to the raid")

func test_03_reach_is_declared_not_guessed() -> void:
	assert_gt(config_node.DINO_ATTACK_REACH, config_node.DINO_ATTACK_SLOT_RADIUS_INNER,
		"A dinosaur standing in its attack slot can always reach what it is standing at")

# ==============================================================================
# 2. Habits are a class
# ==============================================================================

func test_04_every_species_is_built_from_the_class_its_habit_names() -> void:
	for type_id in config_node.DINOS:
		var path: String = config_node.get_dino_script_path(String(type_id))
		assert_true(ResourceLoader.exists(path), "%s is built from a script that exists" % type_id)
	assert_eq(config_node.get_dino_script_path("no_such_species"),
		"res://scripts/entities/Dino.gd", "An unknown species falls back to the plain one")

func test_05_two_species_with_one_habit_share_a_class() -> void:
	# The reason habits are classes: adding another small pack species should be a
	# Config entry and no code at all.
	assert_eq(config_node.get_dino_script_path("raptor"),
		config_node.get_dino_script_path("pterosaur"),
		"Raptor and pterosaur are both pack, so they are the same class")
	assert_ne(config_node.get_dino_script_path("raptor"),
		config_node.get_dino_script_path("big_theropod"),
		"A theropod fights differently, so it is a different one")

func test_06_a_pack_dinosaur_breaks_off_for_a_turret() -> void:
	var dino = _dino("raptor", Vector3.ZERO)
	var tower = _spawn(tower_script, Vector3(3.0, 0.0, 0.0))
	var wall = _spawn(wall_script, Vector3(1.0, 0.0, 0.0))
	await wait_frames(1)

	assert_eq(dino._find_threat_priority_target(), tower,
		"The thing shooting at it is what it wants, even with a fence closer")

func test_07_a_siege_dinosaur_walks_past_the_hero() -> void:
	# Something the size of a house has no reason to stop for one man.
	var dino = _dino("big_theropod", Vector3.ZERO)
	var hero = _spawn(hero_script, Vector3(1.5, 0.0, 0.0))
	hero.has_provoked_dinos = true
	await wait_frames(1)

	assert_eq(dino.hero_interest_range(), 0.0, "It has no interest in him")
	assert_null(dino._find_threat_priority_target(), "Even provoked, he is not a target")

	var wall = _spawn(wall_script, Vector3(2.0, 0.0, 0.0))
	await wait_frames(1)
	assert_eq(dino._find_threat_priority_target(), wall, "A building is another matter")

func test_08_a_pack_dinosaur_does_come_for_a_provoking_hero() -> void:
	var dino = _dino("raptor", Vector3.ZERO)
	var hero = _spawn(hero_script, Vector3(1.0, 0.0, 0.0))
	hero.has_provoked_dinos = true
	await wait_frames(1)

	assert_eq(dino._find_threat_priority_target(), hero, "A pack notices you")

func test_09_a_bigger_dinosaur_reaches_further() -> void:
	var small = _dino("raptor", Vector3.ZERO)
	var big = _dino("big_theropod", Vector3(30.0, 0.0, 0.0))
	await wait_frames(1)
	assert_gt(big.attack_reach(), small.attack_reach(), "Size tells in what it can touch")

func test_10_the_shared_machinery_stayed_shared() -> void:
	# Movement, health, drops and death are the base class's business; a habit
	# subclass should add wants and nothing else.
	var pack = _dino("raptor", Vector3(50.0, 0.0, 50.0))
	await wait_frames(1)
	for method in ["take_damage", "die", "spawn_death_drops", "advance_towards_waypoint", "_steer_target"]:
		assert_true(pack.has_method(method), "PackDino inherits %s" % method)
	pack.take_damage(pack.max_hp)
	assert_true(pack.is_dead, "And dies like any other")
	assert_gt(ground_total("bone"), 0, "Leaving what its species drops")
