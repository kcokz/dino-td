# res://tests/test_v06_close_up_it_is_quicker.gd
# The player, 2026-10-02: "我可以直接去捡，恐龙追不上人，它们上来，跑就行了" -- chosen "追人时会冲刺": a hunter
# bursts and a man endures. Set on him and close, a Coelophysis (or a nest's guard, or a Velociraptor) dashes
# faster than he walks for a few seconds, the dash ending in a bite; then it is winded, slower than he is, and
# cannot dash again till it has its wind back. So close up he cannot get away, and seen coming from further off
# he can. The phytosaur, slower than he is on land, lunges from very close -- never at a light's edge.
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
		game_state_node.reset_game(7)

func after_each() -> void:
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

func _burst_of(species: String) -> Dictionary:
	var kind: String = String(config_node.DINOS[species].get("burst", ""))
	return config_node.DINO_AI["bursts"].get(kind, {}) if kind != "" else {}

func _hero_speed() -> float:
	return float(config_node.HERO["move_speed"])

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	await nav_settled(main)
	# He is walked by the test, straight away from it; he does not fight back or walk off.
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	return main

## The man out on the open ground in front of the cabin, and a raider `gap` metres behind him -- between him
## and the cabin -- set on him.
func _raider_behind(main: Node, species: String, gap: float) -> Node:
	var start: Vector3 = main.current_core.door_outside() + Vector3(0.0, 0.0, 3.0)
	main.hero.global_position = start
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	main.dinos_container.add_child(d)
	d.setup(species)
	d.global_position = start - Vector3(0.0, 0.0, gap)
	d.set_waypoints([main.current_core.global_position])
	d._take(main.hero, d.Mode.ENGAGE)
	return d

## Walks him straight away from the cabin at his own speed for `seconds`, a physics frame at a time; returns
## the twitch reports made about `d` meanwhile.
func _walk_him_away(main: Node, d: Node, seconds: float, speed: float) -> int:
	var reports: Array = [0]
	var eb = tree.root.get_node("EventBus")
	var id: int = d.get_instance_id()
	var count := func(r: Dictionary) -> void:
		if int(r.get("dino", {}).get("id", -1)) == id:
			reports[0] += 1
	eb.twitch_detected.connect(count)
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds:
		main.hero.global_position += Vector3(0.0, 0.0, speed * dt)
		await tree.physics_frame
		t += dt
	eb.twitch_detected.disconnect(count)
	return int(reports[0])

# ==============================================================================
# 1. The numbers
# ==============================================================================

func test_01_close_up_a_hunter_is_quicker_than_he_walks_and_after_it_slower() -> void:
	var bursts: Dictionary = config_node.DINO_AI["bursts"]
	for species in config_node.DINOS:
		var kind: String = String(config_node.DINOS[species].get("burst", ""))
		if kind == "":
			continue
		assert_true(bursts.has(kind), "%s's burst (%s) is one Config gives" % [species, kind])
		var b: Dictionary = bursts[kind]
		var own: float = float(config_node.DINOS[species]["speed"])
		assert_gt(own * float(b["pace"]), _hero_speed(), "%s bursting is quicker than he walks" % species)
		assert_lt(own * float(b["winded_pace"]), _hero_speed(), "%s winded is slower than he walks" % species)
		assert_gt(float(b["rest"]), float(b["seconds"]), "%s is winded longer than it bursts" % species)
		# From anywhere in its burst's reach it gets to him before the burst is out.
		var d = load(String(config_node.get_dino_script_path(species))).new()
		d.setup(species)
		var bite_reach: float = float(d.attack_reach()) + float(config_node.HERO["width"]) * 0.5
		d.free()
		assert_gte((own * float(b["pace"]) - _hero_speed()) * float(b["seconds"]), float(b["within"]) - bite_reach,
			"%s closes its burst's reach on him walking away" % species)
	for species in ["coelophysis", "coelophysis_alpha", "raptor", "raptor_alpha", "phytosaur"]:
		assert_false(_burst_of(species).is_empty(), "%s bursts" % species)
	var guards: String = String(config_node.map_data()["guards"])
	assert_false(_burst_of(guards).is_empty(), "and so do the nest's guards (%s)" % guards)
	assert_true(_burst_of("hesperosuchus").is_empty(), "The runner, always quicker, has none")
	assert_true(_burst_of("postosuchus").is_empty(), "nor the siege boss, which never goes for him")

# ==============================================================================
# 2. A raider set on him
# ==============================================================================

func test_02_close_up_he_cannot_walk_away_from_it() -> void:
	var main = await _level()
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var b: Dictionary = _burst_of(species)
	var d = _raider_behind(main, species, float(b["within"]) * 0.75)
	var full: float = float(main.hero.current_hp)
	var twitches: int = await _walk_him_away(main, d, float(b["seconds"]) + 0.5, _hero_speed())
	assert_lt(float(main.hero.current_hp), full, "From close behind him, it catches him walking away and bites")
	assert_eq(float(d.speed), float(config_node.DINOS[species]["speed"]), "Its own pace is never changed")
	assert_eq(twitches, 0, "and the chase is no twitch")

func test_03_winded_after_its_burst_it_falls_behind() -> void:
	var main = await _level()
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var b: Dictionary = _burst_of(species)
	var d = _raider_behind(main, species, float(b["within"]) * 0.75)
	var full: float = float(main.hero.current_hp)
	var bite: float = float(config_node.DINOS[species]["damage"])
	var twitches: int = await _walk_him_away(main, d, float(b["seconds"]) + float(b["rest"]), _hero_speed())
	assert_almost_eq(float(main.hero.current_hp), full - bite, 0.001, "One bite, at the end of its burst -- no more")
	assert_eq(twitches, 0, "and no twitch in the chase")
	var state: Dictionary = d.debug_state()
	assert_true(state.has("burst") and state.has("winded"), "What a report says of it has its burst and its wind")

func test_04_seen_coming_from_further_off_he_gets_away() -> void:
	var main = await _level()
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var b: Dictionary = _burst_of(species)
	var d = _raider_behind(main, species, float(b["within"]) + 0.6)
	var full: float = float(main.hero.current_hp)
	await _walk_him_away(main, d, float(b["seconds"]) + 1.0, _hero_speed())
	assert_eq(float(main.hero.current_hp), full, "Out of its burst's reach, walking away, he is not caught")
	assert_false(d.bursting(), "and it never burst")

# ==============================================================================
# 3. A guard, a phytosaur
# ==============================================================================

func test_05_a_guard_bursts_only_after_him() -> void:
	var main = await _level()
	var species: String = String(config_node.map_data()["guards"])
	var b: Dictionary = _burst_of(species)
	var g = load("res://scripts/entities/GuardDino.gd").new()
	_cleanup_nodes.append(g)
	main.add_child(g)
	g.setup(species)
	var start: Vector3 = main.current_core.door_outside() + Vector3(0.0, 0.0, 3.0)
	main.hero.global_position = start
	g.setup_post(start - Vector3(0.0, 0.0, float(b["within"]) * 0.75))
	g.global_position = start - Vector3(0.0, 0.0, float(b["within"]) * 0.75)
	g._begin_threat(main.hero, false)
	g._consider_burst()
	assert_false(g.bursting(), "Warning him off, it does not burst")
	g._begin_chase(main.hero, false)
	var full: float = float(main.hero.current_hp)
	await _walk_him_away(main, g, float(b["seconds"]) + 0.5, _hero_speed())
	assert_lt(float(main.hero.current_hp), full, "After him, from close, it catches him walking away")
	g._go_home()
	assert_false(g.bursting(), "Gone home, its burst is dropped")

func test_06_a_phytosaur_lunges_from_close_but_never_at_a_lights_edge() -> void:
	var main = await _level()
	var b: Dictionary = _burst_of("phytosaur")
	var d = load(String(config_node.get_dino_script_path("phytosaur"))).new()
	_cleanup_nodes.append(d)
	main.dinos_container.add_child(d)
	d.setup("phytosaur")
	d.set_physics_process(false)
	var start: Vector3 = main.current_core.door_outside() + Vector3(0.0, 0.0, 3.0)
	main.hero.global_position = start
	d.global_position = start - Vector3(0.0, 0.0, float(b["within"]) + 1.0)
	d._take(main.hero, d.Mode.ENGAGE)
	d._consider_burst()
	assert_false(d.bursting(), "Further off than its lunge, it does not lunge")
	d.global_position = start - Vector3(0.0, 0.0, float(b["within"]) * 0.8)
	d._wary = {"at": start, "radius": 6.0}
	d._consider_burst()
	assert_false(d.bursting(), "Keeping to a light's edge, it does not")
	assert_eq(float(d._burst_pace()), 1.0, "and goes at its own pace there")
	d._wary = {}
	d._consider_burst()
	assert_true(d.bursting(), "In the dark and close, it lunges")
	assert_almost_eq(float(d._burst_pace()), float(b["pace"]), 0.001, "at its lunge's pace")
	d._keep_to({"at": start, "radius": 6.0}, true)
	assert_false(d.bursting(), "A light in the way ends it")
