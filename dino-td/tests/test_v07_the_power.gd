# res://tests/test_v07_the_power.gd
# The player, 2026-10-04: "通关游戏中不能无限玩，是因为船舱电能有限，给一个电能的圈绕在船舱的血量圈外面，电能耗尽游戏就输了"
# (GAME-DESIGN 8.1; Config.POWER).
#
# The cabin's battery runs down as the run goes; out, the run is lost, and the defeat says so. A ring round the cabin's
# medallion shows what is left, red when it runs low -- said once. Our own game only: a custom game has none.
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
		game_state_node.game = {}
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

## The seconds the battery lasts (POWER.lasts_days of DAY.length).
func _whole() -> float:
	return float(config_node.POWER["lasts_days"]) * float(config_node.DAY["length"])

func test_01_it_runs_down_as_the_run_goes() -> void:
	var gs = game_state_node
	assert_true(gs.uses_power(), "Our own game runs on the cabin's battery")
	assert_almost_eq(float(gs.power_left()), 1.0, 0.0001, "and starts it full")
	gs._use_power(_whole() * 0.25)
	assert_almost_eq(float(gs.power_left()), 0.75, 0.0001, "A quarter of its seconds gone, a quarter of it gone")
	assert_almost_eq(float(gs.power_days_left()), float(config_node.POWER["lasts_days"]) * 0.75, 0.001, "and the days left with it")
	gs.reset_game()
	assert_almost_eq(float(gs.power_left()), 1.0, 0.0001, "A new run, full again")

func test_02_run_out_the_run_is_lost_and_said_so() -> void:
	var main = await _level()
	var gs = game_state_node
	var lost: Array = []
	var eb = tree.root.get_node("EventBus")
	var hear := func() -> void: lost.append(true)
	eb.game_lost.connect(hear)
	gs._use_power(_whole() + 1.0)
	eb.game_lost.disconnect(hear)
	assert_almost_eq(float(gs.power_left()), 0.0, 0.0001, "Out")
	assert_true(bool(gs.is_game_over), "and the run is over")
	assert_eq(String(gs.lost_to), "power", "lost to the power")
	assert_eq(lost.size(), 1, "told once")
	assert_eq(main.hud._defeat_text(gs), tr("GAME_DEFEAT_POWER"), "and the defeat says the cabin's power ran out")
	var used: float = float(gs.power_used)
	gs._use_power(10.0)
	assert_almost_eq(float(gs.power_used), used, 0.0001, "Over, it goes no further")

func test_03_a_custom_game_has_none() -> void:
	var gs = game_state_node
	gs.play("custom", {"map": "small"})
	assert_false(gs.uses_power(), "A custom game ends as its settings say")
	gs._use_power(_whole() * 2.0)
	assert_almost_eq(float(gs.power_left()), 1.0, 0.0001, "and its cabin's power never runs down")
	assert_false(bool(gs.is_game_over), "nor loses it the run")
	gs.play("campaign")
	assert_true(gs.uses_power(), "Our own game does")

func test_04_a_ring_round_the_cabins_medallion_shows_it() -> void:
	var main = await _level()
	var hud = main.hud
	var gs = game_state_node
	var ring: TextureProgressBar = hud.core_power_ring
	assert_not_null(ring, "A ring round the cabin's medallion")
	assert_true(hud.core_vital.is_ancestor_of(ring), "on the cabin's medallion")
	assert_true(ring.visible, "shown in our own game")
	assert_almost_eq(ring.value, 1.0, 0.0001, "full")
	gs._use_power(_whole() * 0.4)
	await wait_frames(1)
	assert_almost_eq(ring.value, float(gs.power_left()), 0.002, "It shows what is left")
	assert_eq(ring.tint_progress, UiTheme.color("power"), "in the ship's light")
	assert_true(hud.core_vital.tooltip_text.find("%d" % int(round(float(gs.power_left()) * 100.0))) >= 0, "and the cabin's words say how much")
	# Run low: red, and said once.
	var low: float = float(config_node.POWER["low_below"])
	gs.power_used = _whole() * (1.0 - low) - 1.0
	gs._use_power(2.0)
	await wait_frames(1)
	assert_eq(ring.tint_progress, UiTheme.color("danger"), "Under %d%% it is red" % int(low * 100.0))
	assert_true(bool(hud._power_low_said), "and its running low is said")

func test_05_paused_it_does_not_run_down() -> void:
	var main = await _level()
	var gs = game_state_node
	var used: float = float(gs.power_used)
	tree.paused = true
	await wait_frames(10)
	tree.paused = false
	assert_almost_eq(float(gs.power_used), used, 0.0001, "Paused, none of it goes")
