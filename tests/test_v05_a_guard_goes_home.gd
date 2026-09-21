# res://tests/test_v05_a_guard_goes_home.gd
# A nest guard that has been pulled off its post goes back to it.
#
# Reported as "守卫恐龙追着人跑了一段之后停下不回去了" -- it chases you for a while, then
# stops, and never goes home.
#
# AGGRO IS MEASURED FROM THE GUARD AND THE LEASH FROM ITS POST, and at the edge those two
# disagree. Pulled past its leash with the player standing a few metres away, the guard
# alternated RETURNING and AGGRO_CHASE on consecutive frames: returning saw a threat
# inside its aggro radius and gave chase, chasing saw itself past the leash and turned
# back. BOTH of those branches return before moving, so it did neither. Measured: six
# seconds of it, 180 frames in each state, 0.000m travelled -- neither going home nor
# attacking, which is the worst of the three things it could be doing.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

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
	super.after_each()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

## A guard on a post well clear of everything else, and the Hero it is about to chase.
func _guard_and_hero(main: Node, post: Vector3) -> Array:
	var g = load("res://scripts/entities/GuardDino.gd").new()
	_cleanup_nodes.append(g)
	main.add_child(g)
	g.setup("raptor")
	g.setup_post(post)
	g.max_hp = 9999.0
	g.current_hp = 9999.0
	var hero = main.hero
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	return [g, hero]

# ==============================================================================
# 1. The freeze
# ==============================================================================

func test_01_a_guard_past_its_leash_walks_home_even_with_the_player_standing_there() -> void:
	var main = _level()
	await wait_frames(6)
	var post := Vector3(0.0, 0.0, -26.0)
	var pair := _guard_and_hero(main, post)
	var guard = pair[0]
	var hero = pair[1]
	await wait_frames(2)

	# Exactly the reported situation: dragged past the leash, player a few metres off.
	guard.global_position = post + Vector3(0.0, 0.0, guard.leash_radius + 1.0)
	var standing_at: Vector3 = post + Vector3(0.0, 0.0, guard.leash_radius + 4.0)
	hero.global_position = standing_at
	assert_lt(guard.global_position.distance_to(hero.global_position), guard.aggro_radius,
		"The player is well inside what the guard would normally chase")
	assert_gt(guard.global_position.distance_to(post), guard.leash_radius,
		"And the guard is past the end of its leash")

	var started_at: Vector3 = guard.global_position
	for step in range(360):
		hero.global_position = standing_at      # the player does not move
		await wait_physics_frames(1)

	assert_gt(started_at.distance_to(guard.global_position), 1.0,
		"Six seconds later it has actually gone somewhere")
	assert_lt(guard.global_position.distance_to(post), guard.leash_radius,
		"And what it went to was its post")

func test_02_it_does_not_take_up_a_chase_it_would_have_to_abandon() -> void:
	# The rule, stated on its own. Being out of reach is a property of the THREAT, not of
	# which state the guard happens to be in, which is why it is not a special case in
	# the returning branch.
	var main = _level()
	await wait_frames(6)
	var post := Vector3(0.0, 0.0, -26.0)
	var pair := _guard_and_hero(main, post)
	var guard = pair[0]
	var hero = pair[1]
	await wait_frames(2)

	guard.global_position = post
	hero.global_position = post + Vector3(0.0, 0.0, guard.leash_radius + 2.0)
	assert_false(guard._worth_chasing(hero), "Beyond the leash is not worth setting off for")

	hero.global_position = post + Vector3(0.0, 0.0, guard.leash_radius - 2.0)
	assert_true(guard._worth_chasing(hero), "Inside it is")

# ==============================================================================
# 2. And it still does its job
# ==============================================================================

func test_03_it_still_chases_somebody_who_walks_up_to_the_nest() -> void:
	# The fix must not turn the guard into scenery. Somebody standing next to its post is
	# exactly what it is there for.
	var main = _level()
	await wait_frames(6)
	var post := Vector3(0.0, 0.0, -26.0)
	var pair := _guard_and_hero(main, post)
	var guard = pair[0]
	var hero = pair[1]
	await wait_frames(2)

	guard.global_position = post
	hero.global_position = post + Vector3(0.0, 0.0, guard.aggro_radius * 0.5)
	await wait_physics_frames(3)

	assert_eq(int(guard.guard_state), int(guard.GuardState.AGGRO_CHASE),
		"It comes after him")
	var gap: float = guard.global_position.distance_to(hero.global_position)
	for step in range(120):
		await wait_physics_frames(1)
	assert_lt(guard.global_position.distance_to(hero.global_position), gap,
		"And closes the distance")

func test_04_the_leash_is_what_stops_it_and_the_numbers_are_in_config() -> void:
	assert_true(config_node.NEST_GUARDS.has("post_radius"), "Config declares the post")
	assert_true(config_node.NEST_GUARDS.has("aggro_radius"), "And what it notices")
	assert_true(config_node.NEST_GUARDS.has("leash_radius"), "And how far it will go")
	assert_gt(float(config_node.NEST_GUARDS["leash_radius"]),
		float(config_node.NEST_GUARDS["aggro_radius"]),
		"A leash shorter than the aggro radius would be a guard that can never reach anything")
