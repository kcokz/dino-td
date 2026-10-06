# res://tests/test_v07_a_light_that_moves.gd
# The twitch watch on the bot's first nights once the cabin stopped shooting (2026-10-02; the debug-agent's TASK-037: "火把边
# idle↔walk 的 flicker"，"栅栏边 BREACH 的 shake/mill"): phytosaurs drawn walking, standing, walking at the edge of his torch,
# and shaking and milling at the fences they meant to bite through. His torch goes where he goes and burns down, and each
# thought the phytosaur took it for a light a little way off from the last.
#
# So it holds its ground at a light's edge while the edge is near it (PROWL.edge_hold); what it goes for is lit with a
# margin (PROWL.lit_margin); and across a light it goes round, one way, without standing (PROWL.round_step_degrees). Each is
# played as the game plays it -- the animal on its own mind, the physics running, at the game's fastest -- with the
# level's own twitch watch looking on.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _reports: Array = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.reset_game()
	_reports.clear()
	var eb = tree.root.get_node("EventBus")
	if not eb.twitch_detected.is_connected(_on_twitch):
		eb.twitch_detected.connect(_on_twitch)

func after_each() -> void:
	Engine.time_scale = 1.0
	var eb = tree.root.get_node("EventBus")
	if eb.twitch_detected.is_connected(_on_twitch):
		eb.twitch_detected.disconnect(_on_twitch)
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

func _on_twitch(record: Dictionary) -> void:
	_reports.append(record)

## A level at night with only the test's animals in it: no raids, nothing sent up out of the river.
func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	main.night_prowl.process_mode = Node.PROCESS_MODE_DISABLED
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	return main

func _prowl() -> Dictionary:
	return config_node.PROWL

func _tw() -> Dictionary:
	return config_node.TWITCH

func _species() -> String:
	return String(game_state_node.map_data()["prowlers"].keys()[0])

func _at(part: String) -> float:
	return float(config_node.DAY["parts"][part])

func _set_clock(t: float, day: int = 1) -> void:
	game_state_node.day_clock = float(day - 1) * float(config_node.DAY["length"]) + t
	game_state_node._run_the_day(0.0)

func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## The game's fastest speed (UI.game_speeds): the bot's, and where the reports came from.
func _fastest() -> float:
	var most: float = 1.0
	for s in config_node.UI["game_speeds"]:
		most = maxf(most, float(s))
	return most

## A phytosaur put down at `at`, making for the cabin, on its own mind.
func _phytosaur(main: Node, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(_species()))).new()
	d.setup(_species())
	d.home = at
	d.waypoints = [at, main.current_core.global_position] as Array[Vector3]
	d.position = at
	main.dinos_container.add_child(d)
	d.setup(_species())
	return d

## The Hero at `at`, still -- the test moves him -- with a phytosaur that has his scent in the dark where it would wait
## at the edge of his torch's light (PROWL.edge_out), and then his torch alight: what it is after is in his light, and it
## keeps to its edge.
func _scented_then_lit(main: Node, at: Vector3) -> Node:
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = at
	var torch: float = float(config_node.FIRE["torch"]["light"])
	var d = _phytosaur(main, at + Vector3(-(torch + float(_prowl()["edge_out"])), 0.0, 0.0))
	d._think()
	assert_eq(d.current_target, hero, "(the man in the dark is what it is after)")
	stock_everything()
	assert_true(hero.light_torch(), "(then his torch alight)")
	assert_almost_eq(float(hero.torch_light()), torch, 0.001, "(as far as a torch lights, FIRE.torch.light)")
	return d

## The Hero, still -- the test moves him -- with his torch alight.
func _torch_lit(main: Node, at: Vector3) -> float:
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = at
	stock_everything()
	assert_true(hero.light_torch(), "(his torch alight)")
	return float(hero.torch_light())

## A lit campfire at `at`.
func _campfire(main: Node, at: Vector3) -> Node:
	stock_everything()
	var fire = main.build_system.place_at("campfire", main.grid_manager.world_to_build_cell(at), main.buildings_container)
	fire._tend(99.0)
	return fire

## He goes in, and stays: inside the room, the cabin told so.
func _shut_in(main: Node) -> void:
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.door_inside()
	main.current_core.recheck_hero()
	assert_true(bool(main.current_core.hero_inside), "(he is in the cabin)")

## The game run for `seconds` of its own time at its fastest, `each` called every physics frame with the frame's time.
func _play(seconds: float, each: Callable) -> void:
	Engine.time_scale = _fastest()
	var dt: float = Engine.time_scale / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds:
		await tree.physics_frame
		t += dt
		each.call(dt)
	Engine.time_scale = 1.0

## Its twitch reports, each as what was counted and what it had been doing: its last changes of clip, and the light it
## was keeping to or going round (ProwlerDino.debug_state).
func _reports_on(d: Node) -> Array:
	var out: Array = []
	for r in _reports:
		if int(r["dino"]["id"]) == d.get_instance_id():
			out.append("%s (%s; clips %s; light %s; round %s; frames %s)" % [String(r["kind"]), JSON.stringify(r["window"]),
				JSON.stringify(r["trail"]["clips"]), JSON.stringify(r["dino"].get("light")), JSON.stringify(r["dino"].get("round")),
				JSON.stringify(r["trail"]["frames"])])
	return out

## Times it set off walking -- standing, then drawn moving (ActorAnimator.is_moving) -- counted by `count`, a frame at a time.
class Walks:
	var was: bool = false
	var starts: int = 0
	func count(d: Node) -> void:
		var moving: bool = d.animator != null and bool(d.animator.is_moving)
		if moving and not was:
			starts += 1
		was = moving

## However many seconds of pacing it might do (PROWL.pace_every, the shortest wait): the walks a phytosaur keeping to an
## edge sets off on in `seconds`, and the one to its place.
func _pacing_walks(seconds: float) -> int:
	return int(ceil(seconds / float(_prowl()["pace_every"][0]))) + 1

# ==============================================================================
# 1. At the edge of his torch
# ==============================================================================

func test_01_at_his_torchs_edge_it_holds_its_ground_while_he_works() -> void:
	# The bot at a bench by the cabin's door: a step one way and back, again and again, his torch in his hand.
	var main = await _level()
	var at: Vector3 = main.current_core.global_position + Vector3(-9.0, 0.0, 9.0)
	var d = _scented_then_lit(main, at)
	var torch: float = float(main.hero.torch_light())
	var edge: float = torch + float(_prowl()["edge_out"])
	var step: float = float(_prowl()["edge_hold"]) * 0.6
	var every: float = float(_tw()["window"]) * 0.25
	var seconds: float = float(_tw()["window"]) * 5.0
	var walks := Walks.new()
	var deepest: Array = [INF]
	var clock: Array = [0.0]
	await _play(seconds, func(dt: float) -> void:
		clock[0] += dt
		main.hero.global_position = at + Vector3(step if int(clock[0] / every) % 2 == 1 else 0.0, 0.0, 0.0)
		walks.count(d)
		deepest[0] = minf(deepest[0], _flat_gap(d.global_position, main.hero.global_position)))
	assert_true(d.is_wary(), "It keeps to his torch's edge")
	assert_eq(d.current_target, main.hero, "after him still")
	assert_eq(_reports_on(d), [], "and nothing it does there is a twitch")
	assert_lte(walks.starts, _pacing_walks(seconds),
		"It walks no more than it paces along the edge: his steps about, less than PROWL.edge_hold, it stands through")
	assert_gt(deepest[0], torch - float(_prowl()["flee_inside"]), "It was never deeper in his light than it flees from")
	var gap: float = _flat_gap(d.global_position, main.hero.global_position)
	assert_almost_eq(gap, edge, float(_prowl()["edge_hold"]) + float(config_node.DINO_AI["spot_slack"]), "at the edge")

func test_02_as_his_torch_burns_down_it_follows_the_edge_in_and_comes_when_it_is_out() -> void:
	var main = await _level()
	var at: Vector3 = main.current_core.global_position + Vector3(-9.0, 0.0, 9.0)
	var d = _scented_then_lit(main, at)
	var torch: float = float(main.hero.torch_light())
	await _play(float(_tw()["window"]), func(_dt: float) -> void: pass)
	assert_true(d.is_wary(), "(it keeps to his torch's edge)")
	# Its last seconds: it dims from here (FIRE.torch.fade_seconds), burnt down as the game burns it.
	var fade: float = float(config_node.FIRE["torch"]["fade_seconds"])
	main.hero.torch_left = fade
	var walks := Walks.new()
	var walks_lit: Array = [0]
	await _play(fade + float(_tw()["window"]), func(dt: float) -> void:
		main.hero._burn_the_torch(dt)
		walks.count(d)
		if main.hero.torch_light() > 0.0:
			walks_lit[0] = walks.starts)
	assert_almost_eq(float(main.hero.torch_light()), 0.0, 0.0001, "(his torch is out)")
	assert_eq(_reports_on(d), [], "Nothing it did as the light shrank was a twitch")
	# The edge comes in a light's width over the fade: a walk for every PROWL.edge_hold of it at most, not a step a thought.
	assert_lte(walks_lit[0], int(ceil(torch / float(_prowl()["edge_hold"]))),
		"It went in after the edge a walk at a time, not a step and a stop at every thought")
	assert_false(d.is_wary(), "The torch out, it keeps to no edge")
	assert_eq(d.current_target, main.hero, "and the man in the dark is what it comes for")

func test_03_struck_at_his_torchs_edge_it_goes_at_him_not_round_his_light() -> void:
	# The player, 2026-10-01: "这时候我进攻恐龙它们都不会还手？" -- struck, it turns on him (ProwlerDino._turn_at_bay), the
	# light or no. Its way round a light (PROWL.round_step_degrees) is not for him: it went round his torch's edge instead of at him.
	var main = await _level()
	var at: Vector3 = main.current_core.global_position + Vector3(-9.0, 0.0, 9.0)
	var d = _scented_then_lit(main, at)
	await _play(float(_tw()["bucket"]) * 2.0, func(_dt: float) -> void: pass)
	assert_true(d.is_wary(), "(at his torch's edge)")
	main.hero.target_enemy = d
	d.take_damage(0.01)
	main.hero.target_enemy = null
	assert_gt(float(d.at_bay_left), 0.0, "(struck by him, it turns on him)")
	var closest: Array = [INF]
	await _play(float(_prowl()["at_bay_seconds"]), func(_dt: float) -> void:
		closest[0] = minf(closest[0], _flat_gap(d.global_position, main.hero.global_position)))
	assert_lte(closest[0], float(d.attack_reach()) + float(config_node.HERO["width"]) * 0.5 + float(config_node.DINO_AI["reach_release"]),
		"It came at him and to within its bite before it was done")

# ==============================================================================
# 2. A light across its way
# ==============================================================================

func test_04_a_fire_across_its_way_it_goes_round_one_way_without_standing() -> void:
	# The bot's campfire before the cabin, a phytosaur coming at the cabin's dark side from straight beyond it: its way
	# lay across the light's middle, and it stood at the edge (the twitch watch: flicker, shake, fidget).
	var main = await _level()
	_shut_in(main)
	var cabin: Vector3 = main.current_core.global_position
	var fire = _campfire(main, cabin + Vector3(-9.0, 0.0, 9.0))
	var light: float = float(fire.light_radius())
	var start: Vector3 = fire.global_position + Vector3(-(light + 3.0), 0.0, 0.0)
	var beyond: Vector3 = fire.global_position + Vector3(light + 3.0, 0.0, 0.0)
	var d = _phytosaur(main, start)
	# Its road runs on past the fire before the cabin: a bend beyond it, straight across the light from where it stands.
	d.waypoints = [start, beyond, cabin] as Array[Vector3]
	var speed: float = float(config_node.DINOS[_species()]["speed"])
	var most: float = (PI * light + 2.0 * 3.0) / speed * 2.0
	var still: Array = [0.0]
	var longest: Array = [0.0]
	var deepest: Array = [INF]
	var turned: Array = [0.0, 0.0]
	var bearing: Array = [INF]
	var got_by: Array = [false]
	await _play(most, func(dt: float) -> void:
		if got_by[0]:
			return
		var gap: float = _flat_gap(d.global_position, fire.global_position)
		deepest[0] = minf(deepest[0], gap)
		var moving: float = Vector2(d.velocity.x, d.velocity.z).length()
		still[0] = still[0] + dt if moving < float(config_node.DINO_AI["turn_min_speed"]) else 0.0
		longest[0] = maxf(longest[0], still[0])
		var b: float = Vector2(d.global_position.x - fire.global_position.x, d.global_position.z - fire.global_position.z).angle()
		if bearing[0] != INF and gap <= light + 3.5:
			var turn: float = wrapf(b - bearing[0], -PI, PI)
			turned[0 if turn > 0.0 else 1] += absf(turn)
		bearing[0] = b
		got_by[0] = d.global_position.x > fire.global_position.x + light * 0.5)
	assert_true(got_by[0], "It got round the fire's light to the far side, in less than twice the time round it at its pace")
	assert_lt(longest[0], float(config_node.DINO_AI["stuck_window"]),
		"and never stood on the way longer than it takes to know itself stuck (%.2f s)" % longest[0])
	# Back the other way by less than a swing the twitch watch would count (TWITCH.swing_min_deg).
	assert_lte(minf(turned[0], turned[1]), deg_to_rad(float(config_node.TWITCH["swing_min_deg"])),
		"It went round one way, not this way and that (%.0f and %.0f degrees)" % [rad_to_deg(turned[0]), rad_to_deg(turned[1])])
	assert_gt(deepest[0], light - float(_prowl()["flee_inside"]), "It was never deeper in the light than it flees from")
	assert_eq(_reports_on(d), [], "Nothing it did on the way round was a twitch")

# ==============================================================================
# 3. What it goes for, lit with a margin
# ==============================================================================

func test_05_its_place_at_the_cabin_is_kept_while_the_torch_inside_wobbles() -> void:
	# The bot asleep in the pod and up again, by turns, a step back and forth in the room, his torch alight: the places
	# round the cabin at its edge were lit and dark by turns, and a phytosaur went from one to the other at every thought.
	var main = await _level()
	_shut_in(main)
	stock_everything()
	assert_true(main.hero.light_torch(), "(his torch alight, in the cabin)")
	var inside: Vector3 = main.hero.global_position
	var step: float = float(_prowl()["lit_margin"]) * 0.9
	var every: float = float(_tw()["window"]) * 0.25
	var cabin: Vector3 = main.current_core.global_position
	var half: Vector2 = config_node.get_building_half("core")
	var d = _phytosaur(main, cabin + Vector3(-(half.x + 9.0), 0.0, 0.0))
	var places: Array = []
	var clock: Array = [0.0]
	var deepest: Array = [INF]
	await _play(float(_tw()["mill_window"]) * 2.5, func(dt: float) -> void:
		clock[0] += dt
		main.hero.global_position = inside + Vector3(0.0, 0.0, -step if int(clock[0] / every) % 2 == 1 else 0.0)
		var slot: Vector3 = d.assigned_slot
		if slot != Vector3.ZERO and (places.is_empty() or (places[places.size() - 1] as Vector3).distance_to(slot) > 0.01):
			places.append(slot)
		deepest[0] = minf(deepest[0], _flat_gap(d.global_position, main.hero.global_position)))
	assert_true(bool(main.current_core.hero_inside), "(he stayed in)")
	assert_eq(_reports_on(d), [], "Nothing it did at the cabin was a twitch")
	assert_lte(places.size(), 2, "It kept its place round the cabin while his steps came to less than PROWL.lit_margin (%s)" % str(places))
	assert_gt(deepest[0], float(main.hero.torch_light()) - float(_prowl()["flee_inside"]), "and was never deep in his light")

func test_06_at_a_ring_of_fence_with_him_inside_it_and_his_torch_it_bites_or_waits_without_milling() -> void:
	# The bot mending the ring round the cabin by night, his torch alight, a step at a time along its inside: a phytosaur
	# outside, the way to the cabin shut, went for the fence and back out of his light by turns (BREACH: shake, mill).
	var main = await _level()
	var cabin: Vector3 = main.current_core.global_position
	var half: Vector2 = config_node.get_building_half("core")
	var radius: float = half.length() + float(config_node.BUILD_CELL) * 2.0
	stock_everything()
	var ring: Array[Node] = ring_in_level(main, cabin, radius, true, 0.0)
	assert_gt(ring.size(), 0, "(a ring of fence round the cabin, a gate in it at the door)")
	await nav_settled(main)
	var along: Vector3 = cabin + Vector3(-(radius - float(config_node.BUILD_CELL) * 1.5), 0.0, 0.0)
	var torch: float = _torch_lit(main, along)
	assert_false(bool(main.current_core.is_inside(along)), "(he is in the ring, out of the cabin)")
	var d = _phytosaur(main, cabin + Vector3(-(radius + torch + 2.0), 0.0, 0.0))
	var step: float = float(config_node.BUILD_CELL)
	var every: float = float(_tw()["window"]) * 0.5
	var clock: Array = [0.0]
	var deepest: Array = [INF]
	var deep_for: Array = [0.0, 0.0]
	var bit_a_fence: Array = [false]
	var flee_at: float = torch - float(_prowl()["flee_inside"])
	await _play(float(_tw()["mill_window"]) * 3.0, func(dt: float) -> void:
		clock[0] += dt
		# Along the ring's inside and back, a fence's width at a time: a step his light takes at it all at once.
		var k: int = int(clock[0] / every) % 6
		main.hero.global_position = along + Vector3(0.0, 0.0, step * float(k if k <= 3 else 6 - k))
		var gap: float = _flat_gap(d.global_position, main.hero.global_position)
		deepest[0] = minf(deepest[0], gap)
		deep_for[0] = deep_for[0] + dt if (gap < flee_at and float(d.at_bay_left) <= 0.0) else 0.0
		deep_for[1] = maxf(deep_for[1], deep_for[0])
		bit_a_fence[0] = bit_a_fence[0] or (int(d.mode) == int(Dino.Mode.ATTACK) and ring.has(d.current_target)))
	print("  [MEASURE] at the ring: %s, %s, deepest in his light %.2f m of %.2f" % [
		"bit a fence" if bit_a_fence[0] else "never bit", "wary" if d.is_wary() else "dark", torch - deepest[0], torch])
	assert_eq(_reports_on(d), [], "Nothing it did at the ring -- biting, or waiting at his light's edge -- was a twitch")
	assert_lt(deep_for[1], float(_prowl()["cornered_seconds"]),
		"His light come at it a step at a time, it was never deeper in it than it flees from for longer than it takes to know itself cornered (%.2f s)" % deep_for[1])
