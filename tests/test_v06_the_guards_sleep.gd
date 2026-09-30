# res://tests/test_v06_the_guards_sleep.gd
# The player's choice, v0.6 round five: "夜里睡，靠太近或火光照到会醒" -- "举火把防植龙、却会弄醒守卫，成了
# 取舍" (the debug-agent's BUG-023: day and night the guards were the same, while the night's hint said
# the Coelophysis slept, and the battery behind the nest could only be had by killing all three).
#
# Out of its hours a guard lies down about its post. What is AT it wakes it -- the Hero right beside
# it, a light on it, a blow -- and it is up alone: a call does not wake a sleeping guard, so they come
# one at a time. Up, it is a guard as by day, and lies down again once nothing has kept it up a while.
# At first light they are up.
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
	main.wave_manager.auto_raid_enabled = false
	if main.night_prowl != null:
		main.night_prowl.enabled = false
	return main

func _guards_cfg() -> Dictionary:
	return config_node.NEST_GUARDS

## The nest's guards at their posts, hard to kill; him too, and still -- far off, where nothing sees
## him.
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
	main.hero.global_position = main.current_core.global_position
	return guards

func _to(part: String, into: float = 10.0) -> void:
	game_state_node.day_clock = float(config_node.DAY["parts"][part]) + into
	game_state_node._run_the_day(0.0)

func _a_thought() -> void:
	var seconds: float = float(config_node.DINO_AI["think_seconds"]) * 1.2 + 0.1
	await wait_physics_frames(int(ceil(seconds * float(Engine.physics_ticks_per_second))))

func _asleep(g: Node) -> bool:
	return int(g.guard_state) == int(g.GuardState.SLEEPING)

## Him `gap` metres out from `g`, on the far side from the nest.
func _him_off(main: Node, g: Node, gap: float) -> void:
	var out: Vector3 = g.global_position - main.current_nest.global_position
	out.y = 0.0
	main.hero.global_position = g.global_position + out.normalized() * gap

## Night, and every guard lying down.
func _all_asleep(main: Node) -> Array:
	var guards: Array = _the_nests_guards(main)
	_to("night")
	await _a_thought()
	return guards

func test_01_out_of_its_hours_it_lies_down_and_sleeps() -> void:
	var main = await _level()
	var guards: Array = _the_nests_guards(main)
	await _a_thought()
	for g in guards:
		assert_false(_asleep(g), "By day %s is up about its post" % g.name)
	var hours: Array = config_node.DINOS[String(guards[0].dino_type)]["hours"]
	assert_false(hours.has("night"), "(a guard's kind keeps the day's hours)")
	_to("night")
	await _a_thought()
	for g in guards:
		assert_true(_asleep(g), "At night %s lies down" % g.name)
		assert_eq(int(g.current_state), int(g.State.SLEEPING), "and is drawn so")
	await wait_seconds(1.0)
	for g in guards:
		assert_lt(g.global_position.distance_to(g.post_position), float(_guards_cfg()["post_radius"]) + 0.5,
			"%s lies still about its post" % g.name)
		if g.animator != null and g.animator.animation_player != null:
			assert_eq(String(g.animator.current_clip), String(config_node.ANIMATIONS["dino"]["SLEEPING"]),
				"%s plays its sleep" % g.name)

func test_02_the_man_passing_by_does_not_wake_it_right_beside_it_does() -> void:
	var main = await _level()
	var guards: Array = await _all_asleep(main)
	var g = guards[0]
	var near: float = float(_guards_cfg()["wake_within"])
	assert_lt(near, float(g.aggro_radius), "(it has to be come much nearer asleep than awake)")
	_him_off(main, g, near + 1.0)
	await _a_thought()
	await _a_thought()
	for other in guards:
		assert_true(_asleep(other), "Past %s at %.1f m, in the dark: it sleeps on" % [other.name, near + 1.0])
	_him_off(main, g, near * 0.7)
	await _a_thought()
	assert_false(_asleep(g), "Right beside it, it wakes")
	assert_eq(int(g.guard_state), int(g.GuardState.THREATENING), "and turns on him")
	assert_eq(g.chase_target, main.hero, "(him)")

func test_03_a_torch_wakes_it_from_the_edge_of_its_light() -> void:
	var main = await _level()
	var guards: Array = await _all_asleep(main)
	var g = guards[0]
	game_state_node.add_resources({"wood": 10})
	assert_true(main.hero.light_torch(), "(a torch alight in his hand)")
	var reach: float = float(main.hero.torch_light())
	assert_gt(reach, float(_guards_cfg()["wake_within"]) + 1.0, "(it lights further than he would wake it by walking up)")
	_him_off(main, g, reach - 0.5)
	await _a_thought()
	assert_false(_asleep(g), "Its light on it, it wakes")

func test_04_woken_it_is_up_alone_the_rest_sleep_on() -> void:
	var main = await _level()
	var guards: Array = await _all_asleep(main)
	var g = guards[0]
	g.wake(main.hero)
	# However close he comes to it -- close enough that it comes for him and calls -- the others,
	# asleep, do not hear it.
	main.hero.global_position = g.global_position + (g.global_position - main.current_nest.global_position).normalized() * 1.0
	for i in 4:
		await _a_thought()
	assert_false(_asleep(g), "(the one woken is up)")
	var slept: int = 0
	for other in guards:
		if other != g and _asleep(other) and other.global_position.distance_to(main.hero.global_position) > float(_guards_cfg()["wake_within"]):
			slept += 1
	assert_gt(slept, 0, "Its nest sleeps on through its call")
	for other in guards:
		if other != g:
			other.answer_call(main.hero)
			other.answer_threat(main.hero)
			if other.global_position.distance_to(main.hero.global_position) > float(_guards_cfg()["wake_within"]):
				assert_true(_asleep(other), "%s is not called up" % other.name)

func test_05_struck_asleep_it_wakes_and_goes_for_him() -> void:
	var main = await _level()
	var guards: Array = await _all_asleep(main)
	var g = guards[0]
	_him_off(main, g, float(_guards_cfg()["wake_within"]) + 1.0)
	g.take_damage(0.1)
	assert_false(_asleep(g), "A blow wakes it")
	assert_eq(int(g.guard_state), int(g.GuardState.AGGRO_CHASE), "and it goes for him")

func test_06_up_a_while_it_lies_down_again_and_at_first_light_they_are_up() -> void:
	var main = await _level()
	var guards: Array = await _all_asleep(main)
	var g = guards[0]
	g.wake(null)
	assert_false(_asleep(g), "(woken)")
	await wait_seconds(float(_guards_cfg()["stay_up"]) * 0.5)
	assert_false(_asleep(g), "Up a while")
	await wait_seconds(float(_guards_cfg()["stay_up"]) * 0.5 + 1.0)
	assert_true(_asleep(g), "and down again, nothing about")
	_to("day", 5.0)
	await _a_thought()
	for other in guards:
		assert_false(_asleep(other), "At first light %s is up" % other.name)
		assert_eq(int(other.current_state), int(other.State.WALKING), "(drawn standing)")

func test_07_the_guards_kind_has_a_sleep_of_its_own() -> void:
	# Upright and belly-down, its own clip -- not the death's, on its side: a sleeping guard must not read
	# as a dead one (tools/generate_triassic.py add_sleep).
	var clip: String = String(config_node.ANIMATIONS["dino"]["SLEEPING"])
	assert_ne(clip, String(config_node.ANIMATIONS["dino"]["DEAD"]), "Sleep is not death")
	assert_true((config_node.ANIMATIONS["looping"] as Array).has(clip), "and goes round, a slow breath")
	var main = await _level()
	var g = _the_nests_guards(main)[0]
	var player: AnimationPlayer = g.animator.animation_player if g.animator != null else null
	assert_not_null(player, "(its body has clips)")
	if player != null:
		assert_true(player.has_animation(clip), "Its body has the clip")
