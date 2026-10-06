# res://tests/test_v06_the_guards_warn.gd
# The debug-agent's DOC-004: once a nest's guards came at him together, the stone by the nest was
# death in six seconds for a man who had not seen them. The player chose: they warn first. The
# first to see him inside its aggro radius stands, faces him, snaps at the air and calls; the guards
# of its nest turn to him too. Backed off past the radius and a margin, he is let be; closer than
# threat_close, or striking one, or staying out the warning, and they all come. A building put up
# by the nest does not back off, and is gone for at once. The HUD says what a warning means, once a
# run.
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
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _guards_cfg() -> Dictionary:
	return config_node.NEST_GUARDS

## The nest's guards at their posts, hard to kill; him too.
func _the_nests_guards(main: Node) -> Array:
	var guards: Array = []
	for g in main.current_nest.guard_dinos:
		if is_instance_valid(g):
			g.global_position = g.post_position
			g.max_hp = 9999.0
			g.current_hp = 9999.0
			guards.append(g)
	main.hero.max_hp = 9999.0
	main.hero.current_hp = 9999.0
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	return guards

## Him `gap` metres out from `g`'s post, on the far side from the nest.
func _him_off(main: Node, g: Node, gap: float) -> void:
	var out: Vector3 = g.post_position - main.current_nest.global_position
	out.y = 0.0
	main.hero.global_position = g.post_position + out.normalized() * gap

func _a_thought() -> void:
	var seconds: float = float(config_node.DINO_AI["think_seconds"]) * 1.2 + 0.1
	await wait_physics_frames(int(ceil(seconds * float(Engine.physics_ticks_per_second))))

func _warning(g: Node) -> bool:
	return int(g.guard_state) == int(g.GuardState.THREATENING)

func _after_him(g: Node) -> bool:
	return int(g.guard_state) == int(g.GuardState.AGGRO_CHASE) or int(g.guard_state) == int(g.GuardState.ATTACKING)

## The heading it looks along, on the ground (its forward is -Z).
func _looking(g: Node3D) -> Vector3:
	return Vector3(-sin(g.rotation.y), 0.0, -cos(g.rotation.y))

func test_01_seen_inside_its_radius_he_is_warned_not_bitten() -> void:
	var main = await _level()
	var guards: Array = _the_nests_guards(main)
	var first = guards[0]
	var told = watch_signal(tree.root.get_node("EventBus"), "guards_warned")
	_him_off(main, first, first.aggro_radius * 0.8)
	await _a_thought()
	for g in guards:
		assert_true(_warning(g), "%s warns him off" % g.name)
		assert_false(_after_him(g), "%s does not come for him yet" % g.name)
	assert_eq(told.emit_count, 1, "Said once, by the first to see him")
	var hp: float = float(main.hero.current_hp)
	await wait_seconds(float(_guards_cfg()["threat_seconds"]) * 0.5)
	var to_him: Vector3 = main.hero.global_position - first.global_position
	to_him.y = 0.0
	assert_lt(rad_to_deg(_looking(first).angle_to(to_him)), 15.0, "It faces him")
	assert_lt(first.global_position.distance_to(first.post_position), float(_guards_cfg()["post_radius"]) + 0.5,
		"standing its ground")
	assert_eq(float(main.hero.current_hp), hp, "Nobody bites him during the warning")

func test_02_backed_off_he_is_let_be() -> void:
	var main = await _level()
	var guards: Array = _the_nests_guards(main)
	var first = guards[0]
	_him_off(main, first, first.aggro_radius * 0.8)
	await _a_thought()
	assert_true(_warning(first), "Warned")
	_him_off(main, first, first.aggro_radius + float(_guards_cfg()["calm_margin"]) + 1.0)
	await wait_seconds(float(_guards_cfg()["threat_seconds"]) + 0.5)
	for g in guards:
		assert_eq(int(g.guard_state), int(g.GuardState.POST_ROAM), "%s back about its post" % g.name)
		assert_null(g.chase_target, "%s after nobody" % g.name)

func test_03_closer_still_and_they_all_come_at_once() -> void:
	var main = await _level()
	var guards: Array = _the_nests_guards(main)
	var first = guards[0]
	_him_off(main, first, first.aggro_radius * 0.8)
	await _a_thought()
	assert_true(_warning(first), "Warned")
	_him_off(main, first, float(_guards_cfg()["threat_close"]) * 0.5)
	await _a_thought()
	for g in guards:
		assert_true(_after_him(g), "%s comes for him before the warning is out" % g.name)

func test_04_struck_during_the_warning_and_they_all_come() -> void:
	var main = await _level()
	var guards: Array = _the_nests_guards(main)
	var first = guards[0]
	_him_off(main, first, first.aggro_radius * 0.8)
	await _a_thought()
	assert_true(_warning(first), "Warned")
	first.take_damage(1.0)
	for g in guards:
		assert_true(_after_him(g), "%s comes for him: one of them was struck" % g.name)

func test_05_he_stays_out_the_warning_and_they_all_come() -> void:
	var main = await _level()
	var guards: Array = _the_nests_guards(main)
	var first = guards[0]
	_him_off(main, first, first.aggro_radius * 0.8)
	await _a_thought()
	await wait_seconds(float(_guards_cfg()["threat_seconds"]) + float(config_node.DINO_AI["think_seconds"]) * 1.2 + 0.2)
	for g in guards:
		assert_true(_after_him(g), "%s comes for him: he stayed" % g.name)

func test_06_a_building_by_the_nest_is_gone_for_without_a_warning() -> void:
	var main = await _level()
	stock_everything()
	var guards: Array = _the_nests_guards(main)
	var first = guards[0]
	_him_off(main, first, first.leash_radius * 3.0)
	var out: Vector3 = first.post_position - main.current_nest.global_position
	out.y = 0.0
	var at: Vector3 = first.post_position + out.normalized() * first.aggro_radius * float(_guards_cfg()["building_aggro_share"]) * 0.6
	var cell: Vector2i = main.grid_manager.world_to_build_cell(at)
	var tower = main.build_system.place_at("bow_tower", cell, main.buildings_container, true)
	assert_not_null(tower, "(a bow tower by the nest)")
	if tower == null:
		return
	tower.complete_construction()
	await _a_thought()
	assert_eq(int(first.guard_state), int(first.GuardState.AGGRO_CHASE), "Gone for at once")
	assert_eq(first.chase_target, tower, "the tower")

func test_07_what_a_warning_means_is_said_once_a_run() -> void:
	var main = await _level()
	var hud = main.hud
	var eb = tree.root.get_node("EventBus")
	assert_false(bool(hud._guards_warning_said), "Nothing said yet")
	eb.guards_warned.emit(null)
	assert_true(bool(hud._guards_warning_said), "Said the first time")
	var toasts: Node = hud.find_child("Toasts", true, false)
	var shown: int = toasts.get_child_count() if toasts else 0
	eb.guards_warned.emit(null)
	assert_eq(toasts.get_child_count() if toasts else 0, shown, "Not again that run")
	hud.reset_hud()
	assert_false(bool(hud._guards_warning_said), "A new run hears it again")
	assert_ne(tr("HINT_GUARDS_WARN"), "HINT_GUARDS_WARN", "(written down)")
