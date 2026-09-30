# res://tests/test_v06_the_raid_mind.gd
# v0.6 feedback, round two, 6: "恐龙攻击还是有问题，比如守卫恐龙攻击人之后，人开始逃跑，恐龙会追，追到一个
# 地方就会回去，有的恐龙会回去，但有的会卡在一些防御不动了，或者直接在防御的周围抽搐，我需要更专业的恐龙
# 进攻逻辑，永远不要抽搐或者傻掉这类情况" -- and 4, "所有单位都不能重叠".
#
# A dinosaur is the engine's walker now (Dino.gd): the server's route on a baked mesh, its
# avoidance, and a round body the engine collides -- with one small mind on top whose every
# change has a margin. What is asserted here is what the player saw go wrong: twitching (a
# heading that snaps), dithering (taking hold and letting go by turns), standing for ever, and
# bodies inside one another -- and that a guard neither runs at a wall its man is behind nor
# stays out when it cannot get home.
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

func _ai(key: String) -> float:
	return float(config_node.DINO_AI[key])

## A bare field with a mesh over it (nav_fixture), kept for cleanup.
func _field() -> Node3D:
	var world: Node3D = await nav_fixture()
	_cleanup_nodes.append(world)
	return world

func _raptor(at: Vector3, parent: Node) -> Node:
	var d = load(String(config_node.get_dino_script_path("raptor"))).new("raptor")
	parent.add_child(d)
	d.setup("raptor")
	d.global_position = at
	_cleanup_nodes.append(d)
	return d

## A finished stake at `at`, in the field's bake.
func _stake(world: Node3D, at: Vector3) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	world.add_child(w)
	w.setup("wall")
	w.position = at
	w.complete_construction()
	return w

# ==============================================================================
# 1. No twitch: the heading turns, it never snaps
# ==============================================================================

func test_01_a_heading_turns_at_its_turning_speed() -> void:
	var world := await _field()
	var d = _raptor(Vector3.ZERO, world)
	await wait_physics_frames(2)
	d.rotation.y = 0.0
	# Asked to face straight behind it, in one frame it turns no further than a frame's worth.
	var frame: float = 1.0 / 60.0
	d._turn_towards(Vector3(0.0, 0.0, 1.0), frame)
	assert_almost_eq(absf(d.rotation.y), deg_to_rad(_ai("turn_speed")) * frame, 0.0001,
		"One frame turns it one frame's worth (Config.DINO_AI.turn_speed)")
	for i in range(120):
		d._turn_towards(Vector3(0.0, 0.0, 1.0), frame)
	assert_almost_eq(absf(wrapf(d.rotation.y, -PI, PI)), PI, 0.01, "and keeps turning until it faces there")

func test_02_marching_through_a_crowd_nobody_snaps_round() -> void:
	# Six raptors walked through each other's way for two seconds of real frames: at no frame
	# does any heading jump by more than the turning speed allows. The old heading was set outright
	# every frame from a velocity the solver nudges about -- which is what a twitch is.
	var world := await _field()
	var raid: Array = []
	for i in range(6):
		var from := Vector3(-3.0 + float(i) * 1.2, 0.0, 6.0 if i % 2 == 0 else -6.0)
		var d = _raptor(from, world)
		d.set_waypoints([Vector3(3.0 - float(i) * 1.2, 0.0, -from.z)])
		raid.append(d)
	await wait_physics_frames(2)
	var limit: float = deg_to_rad(_ai("turn_speed")) / float(Engine.physics_ticks_per_second) + 0.001
	var headings: Array = raid.map(func(d): return d.rotation.y)
	var worst: float = 0.0
	for frame in range(120):
		await wait_physics_frames(1)
		for i in range(raid.size()):
			worst = maxf(worst, absf(wrapf(raid[i].rotation.y - headings[i], -PI, PI)))
			headings[i] = raid[i].rotation.y
	assert_lte(worst, limit, "No heading ever turned faster than it turns (worst %.3f rad in a frame)" % worst)

# ==============================================================================
# 2. Nothing inside anything
# ==============================================================================

func test_03_a_crowd_never_stands_inside_itself() -> void:
	# Eight raptors sent at one point from all round it: bodies meet there and push, and at no
	# frame are two closer than their own width (less the solver's contact margin).
	var world := await _field()
	var raid: Array = []
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var d = _raptor(Vector3(cos(a) * 5.0, 0.0, sin(a) * 5.0), world)
		d.set_waypoints([Vector3.ZERO])
		raid.append(d)
	var width: float = float(config_node.get_visual_size("dino/raptor").x)
	await wait_physics_frames(2)
	var closest: float = INF
	for frame in range(150):
		await wait_physics_frames(1)
		for i in range(raid.size()):
			for j in range(i + 1, raid.size()):
				var p: Vector3 = raid[i].global_position
				var q: Vector3 = raid[j].global_position
				closest = minf(closest, Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)))
	assert_gte(closest, width - 0.02, "Never closer than their width (closest %.3f m)" % closest)

func test_04_the_hero_in_its_way_is_walked_round_or_bitten_never_walked_into() -> void:
	# He stands in its way. It never stands inside him (its body collides with his), and it never
	# stands there for good either: it gets round him, or -- held up by him time and again -- it
	# bites the man in its way (Dino._unstick), whether or not its species came for him.
	var world := await _field()
	var hero = load("res://scripts/entities/Hero.gd").new()
	world.add_child(hero)
	_cleanup_nodes.append(hero)
	hero.global_position = Vector3.ZERO
	# A species with no business with him (the plain habit), so what is tested is his being in
	# the way, not its going for him.
	var d = load("res://scripts/entities/Dino.gd").new("raptor")
	world.add_child(d)
	_cleanup_nodes.append(d)
	d.setup("raptor")
	# He swings at anything that comes within his reach; this one has to live through it.
	d.max_hp = 9999.0
	d.current_hp = 9999.0
	d.global_position = Vector3(0.0, 0.0, 5.0)
	d.set_waypoints([Vector3(0.0, 0.0, -5.0)])
	await wait_physics_frames(2)
	assert_ne(int(d.collision_mask) & int(config_node.LAYER_HERO), 0, "Its body collides with his")
	var touching: float = float(config_node.get_visual_size("dino/raptor").x) * 0.5 		+ float(config_node.HERO["width"]) * 0.5
	var closest: float = INF
	var window: float = _ai("stuck_window")
	for frame in range(int(ceil(window * 4.0 * float(Engine.physics_ticks_per_second)))):
		await wait_physics_frames(1)
		var p: Vector3 = d.global_position
		closest = minf(closest, Vector2(p.x, p.z).distance_to(Vector2.ZERO))
	assert_gte(closest, touching - 0.02, "It never stands inside him (closest %.3f m)" % closest)
	var past: bool = d.global_position.z < -touching
	var biting: bool = d.current_target == hero
	assert_true(past or biting, "It got round him, or it is going for him -- it is not standing there (z %.2f)" % d.global_position.z)

# ==============================================================================
# 3. No dithering, no standing for ever
# ==============================================================================

func test_05_it_lets_go_only_past_its_reach() -> void:
	var world := await _field()
	var d = _raptor(Vector3.ZERO, world)
	var hero = load("res://scripts/entities/Hero.gd").new()
	world.add_child(hero)
	_cleanup_nodes.append(hero)
	hero.set_physics_process(false)
	await wait_physics_frames(2)
	d.set_physics_process(false)
	var reach: float = float(d.attack_reach()) + float(config_node.HERO["width"]) * 0.5
	hero.global_position = Vector3(reach * 0.9, 0.0, 0.0)
	d.on_obstacle_detected(hero)
	assert_eq(int(d.mode), int(d.Mode.ATTACK), "In reach, it bites")
	# A step back that is still inside the margin is not an escape.
	hero.global_position = Vector3(reach + _ai("reach_release") * 0.5, 0.0, 0.0)
	d._hold_and_bite(1.0 / 60.0)
	assert_eq(int(d.mode), int(d.Mode.ATTACK), "A step back inside the margin: it keeps biting")
	hero.global_position = Vector3(reach + _ai("reach_release") + 0.1, 0.0, 0.0)
	d._hold_and_bite(1.0 / 60.0)
	assert_ne(int(d.mode), int(d.Mode.ATTACK), "Past the margin, it lets go of the bite")

func test_06_shut_in_with_nowhere_to_go_it_bites_its_way_out() -> void:
	# The last word against standing still for ever: an animal with no way to where it is going
	# goes through what is in the way.
	var world := await _field()
	var ring: Array = []
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	for w in run_of_stakes(world, gm, Vector3(-2.0, 0.0, -2.0), Vector3(2.0, 0.0, -2.0)):
		ring.append(w)
	for w in run_of_stakes(world, gm, Vector3(2.0, 0.0, -2.0), Vector3(2.0, 0.0, 2.0)):
		ring.append(w)
	for w in run_of_stakes(world, gm, Vector3(2.0, 0.0, 2.0), Vector3(-2.0, 0.0, 2.0)):
		ring.append(w)
	for w in run_of_stakes(world, gm, Vector3(-2.0, 0.0, 2.0), Vector3(-2.0, 0.0, -2.0)):
		ring.append(w)
	await rebake_fixture()
	var d = _raptor(Vector3.ZERO, world)
	d.set_waypoints([Vector3(0.0, 0.0, 12.0)])
	var bitten: bool = false
	for frame in range(360):
		await wait_physics_frames(1)
		if int(d.current_state) == int(d.State.ATTACKING) and d._is_wall(d.current_target):
			bitten = true
			break
	assert_true(bitten, "Within six seconds it is biting the ring that shuts it in")

func test_07_a_paused_game_is_paused_for_the_raid_too() -> void:
	var world := await _field()
	var d = _raptor(Vector3.ZERO, world)
	d.set_waypoints([Vector3(0.0, 0.0, 10.0)])
	await wait_physics_frames(10)
	var gs = game_state_node
	gs.set_paused(true)
	await wait_physics_frames(1)
	var held: Vector3 = d.global_position
	await wait_physics_frames(30)
	assert_true(bool(gs.is_paused), "The game is paused")
	assert_almost_eq(d.global_position.distance_to(held), 0.0, 0.001, "and the raid stands where it was")
	gs.set_paused(false)
	await wait_physics_frames(10)
	assert_gt(d.global_position.distance_to(held), 0.1, "Unpaused, it walks on")

# ==============================================================================
# 4. The guards
# ==============================================================================

func _guard(world: Node, post: Vector3) -> Node:
	var g = load("res://scripts/entities/GuardDino.gd").new()
	world.add_child(g)
	_cleanup_nodes.append(g)
	g.setup("raptor")
	g.setup_post(post)
	return g

func test_08_a_guard_does_not_run_at_a_wall_its_man_is_behind() -> void:
	# He is close enough to chase, but on the far side of a closed ring: there is no way to
	# him, so there is no chase -- a guard running at the wall and grinding there is the
	# "卡在一些防御不动了" that was reported.
	var world := await _field()
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	for pair in [[Vector3(-2, 0, -2), Vector3(2, 0, -2)], [Vector3(2, 0, -2), Vector3(2, 0, 2)],
			[Vector3(2, 0, 2), Vector3(-2, 0, 2)], [Vector3(-2, 0, 2), Vector3(-2, 0, -2)]]:
		run_of_stakes(world, gm, pair[0], pair[1])
	await rebake_fixture()
	var hero = load("res://scripts/entities/Hero.gd").new()
	world.add_child(hero)
	_cleanup_nodes.append(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3.ZERO
	var g = _guard(world, Vector3(0.0, 0.0, -2.0 - float(config_node.NEST_GUARDS["aggro_radius"]) * 0.6))
	assert_lt(g.global_position.distance_to(hero.global_position), float(g.aggro_radius), "He is within its aggro")
	for frame in range(60):
		await wait_physics_frames(1)
	# (The stakes themselves are near enough the nest to be fair game -- a guard goes for what is
	# built by its post -- but not the man it cannot get at.)
	assert_ne(g.chase_target, hero, "But it does not go for him through the wall")

func test_09_a_guard_it_cannot_get_home_makes_its_home_where_it_is() -> void:
	# Walled off from its post, it does not push at the wall for ever: once going home has failed
	# for a couple of headway windows, where it stands is its post.
	var world := await _field()
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	var post := Vector3(0.0, 0.0, 0.0)
	for pair in [[Vector3(-2, 0, -2), Vector3(2, 0, -2)], [Vector3(2, 0, -2), Vector3(2, 0, 2)],
			[Vector3(2, 0, 2), Vector3(-2, 0, 2)], [Vector3(-2, 0, 2), Vector3(-2, 0, -2)]]:
		run_of_stakes(world, gm, pair[0], pair[1])
	await rebake_fixture()
	var g = _guard(world, post)
	g.global_position = Vector3(0.0, 0.0, 6.0)      # outside the ring its post is inside
	g._go_home()
	var settled: bool = false
	var window: float = _ai("stuck_window")
	var frames: int = int(ceil(window * 5.0 * float(Engine.physics_ticks_per_second)))
	for frame in range(frames):
		await wait_physics_frames(1)
		if int(g.guard_state) == int(g.GuardState.POST_ROAM) or g.post_position.distance_to(post) > 0.5:
			settled = true
			break
	assert_true(settled, "It settles somewhere it can stand rather than pushing at the wall")
	assert_false(Vector2(g.global_position.x, g.global_position.z).length() < 1.5,
		"and it is not inside the ring it could not get into")

func test_10_a_trap_it_cannot_get_round_to_is_got_at_through_the_wall() -> void:
	# v0.6 round three, "摆成这样的时候，恐龙进攻又会傻站着不攻击了，挨trip bow的打": traps in a yard inside
	# a sealed ring. The raid went for them, stood at the fence nearest them -- in a crowd, which
	# never bites a fence it might go round -- and was shot where it stood. What it cannot get
	# round to it gets at through the wall between.
	var world := await _field()
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	var ring: Array = []
	for leg in [[Vector3(-2.0, 0.0, -2.0), Vector3(2.0, 0.0, -2.0)], [Vector3(2.0, 0.0, -2.0), Vector3(2.0, 0.0, 2.0)],
			[Vector3(2.0, 0.0, 2.0), Vector3(-2.0, 0.0, 2.0)], [Vector3(-2.0, 0.0, 2.0), Vector3(-2.0, 0.0, -2.0)]]:
		for w in run_of_stakes(world, gm, leg[0], leg[1]):
			ring.append(w)
	var trap = load("res://scripts/entities/Tower.gd").new()
	world.add_child(trap)
	var trap_cell: Vector2i = gm.world_to_build_cell(Vector3.ZERO)
	trap.setup("set_crossbow", gm.world_to_cell(gm.build_cell_to_world(trap_cell)))
	trap.position = gm.build_cell_to_world(trap_cell)
	trap.complete_construction()
	gm.occupy_building(trap, [trap_cell])
	# Wanted for what it is (a shooter, Config.DINO_AI.shooter_kinds), not for having shot: held
	# still, so it kills nobody before the test has seen what they do.
	trap.process_mode = Node.PROCESS_MODE_DISABLED
	await rebake_fixture()
	# A pack outside, the trap in its interest, on its way somewhere the ring does not shut off.
	var pack: Array = []
	for x in [-0.7, 0.0, 0.7]:
		var d = _raptor(Vector3(x, 0.0, -4.3), world)
		d.set_waypoints([Vector3(0.0, 0.0, 12.0)])
		pack.append(d)
	assert_eq(pack[1]._preferred_target(), trap, "The trap inside is what it wants")
	var bitten: bool = false
	var waited_on_it: bool = false
	for frame in range(int(6.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		for d in pack:
			if not is_instance_valid(d):
				continue
			waited_on_it = waited_on_it or d.current_target == trap
			if int(d.current_state) == int(d.State.ATTACKING) and ring.has(d.current_target):
				bitten = true
		if bitten:
			break
	assert_false(waited_on_it, "None of them goes for the trap it cannot get round to")
	assert_true(bitten, "Within six seconds one of them is biting the ring between it and the trap")

func test_11_a_fence_at_the_cabins_back_is_gone_round() -> void:
	# v0.6 round three, "即使没有完全包裹住cabin，恐龙实际攻击效果很差，因为大多数都在后面转来转去，而且还是
	# 有抽搐的情况，判断路径不聪明": a fence hugging the cabin's back -- the side the raid comes from -- and
	# its east end. The road ends in the cabin, and the mesh brought the raid as near to that as it
	# could get: behind the fence, out of reach, where it milled until the cabin's gun had killed
	# it all. It goes round to a place it can bite from.
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	var gm = main.grid_manager
	var core: Node3D = main.current_core
	var c: Vector2i = gm.world_to_build_cell(core.global_position)
	var h := Vector2i((config_node.get_building_size("core") - Vector2i.ONE) / 2)
	var cells: Array[Vector2i] = []
	for x in range(-h.x - 1, h.x + 2):
		cells.append(c + Vector2i(x, -h.y - 1))
	for z in range(-h.y, h.y + 2):
		cells.append(c + Vector2i(h.x + 1, z))
	stock_everything()
	var standing: int = 0
	for cell in cells:
		var w = main.build_system.place_at("wall", cell, main.buildings_container, true)
		if w != null:
			w.complete_construction()
			standing += 1
	assert_eq(standing, cells.size(), "The fence stands, every section of it")
	main.nav_maps.rebake()
	await wait_frames(8)
	assert_true(main.nav_maps.is_reachable(main.wave_manager.nest_spawn_position, core.global_position, false),
		"There is a way round to the cabin")
	# Hard to kill, so the cabin's own gun does not end the raid before it is seen what it does.
	game_state_node.dino_stat_multipliers["hp"] = 50.0
	main.wave_manager.auto_raid_enabled = false
	# A big raid: it is the crowd that milled -- a crowd never bites a fence it might go round.
	main.wave_manager.start_wave(1, 12)
	var most: int = 0
	for frame in range(int(20.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		var biting: int = 0
		for d in tree.get_nodes_in_group("dinos"):
			if is_instance_valid(d) and not d.is_in_group("guard_dinos") and int(d.current_state) == int(d.State.ATTACKING) 					and d.current_target == core:
				biting += 1
		most = maxi(most, biting)
		if most >= 3:
			break
	assert_gte(most, 3, "Within twenty seconds the raid is biting the cabin -- three at once -- not milling behind the fence")

func test_12_waiting_its_turn_it_moves_in_when_a_place_frees() -> void:
	# Waiting at the crowd's edge while every place to bite from is taken, it moves in when one frees
	# (it stood out of reach to the end of a raid before) -- at a building that is not shooting at it.
	var world := await _field()
	var wall = _stake(world, Vector3.ZERO)
	await rebake_fixture()
	var dino_script = load("res://scripts/entities/Dino.gd")
	var d = _raptor(Vector3(0.0, 0.0, 3.0), world)
	d.set_physics_process(false)
	var others: Array[Node3D] = []
	for i in 32:
		var o := Node3D.new()
		world.add_child(o)
		others.append(o)
	for o in others:
		if dino_script.free_inner_slot(wall, o) != Vector3.ZERO:
			dino_script.claim_attack_slot(wall, o)
	d.current_target = wall
	d.assigned_slot = dino_script.claim_attack_slot(wall, d)
	d._unstick()
	assert_eq(d.current_target, wall, "Every place taken, it keeps to what it came for")
	assert_gt(float(d._patience), 0.0, "and waits its turn")
	for o in others:
		dino_script.release_attack_slot(wall, o)
	d._patience = 0.0
	d._unstick()
	assert_true(dino_script.holds_attack_slot(wall, d), "A place freed, it takes it")
	assert_lt(float(config_node.gap_to_building(d.assigned_slot, "wall", wall.global_position)),
		float(config_node.DINO_STANDOFF_INNER) + 0.01, "one it can bite from")
	dino_script.clear_all_attack_slots()

func test_12b_it_does_not_wait_its_turn_under_a_traps_fire() -> void:
	# The debug-agent's BUG-009: ten raptors went for the one crossbow nearest the nest, which two
	# could bite, and the rest milled at the fence corner under its fire. Every place round a trap
	# taken, it leaves that trap be a while and chooses again.
	var world := await _field()
	var trap = load("res://scripts/entities/Tower.gd").new()
	world.add_child(trap)
	trap.setup("set_crossbow")
	trap.position = Vector3.ZERO
	trap.complete_construction()
	trap.process_mode = Node.PROCESS_MODE_DISABLED
	await rebake_fixture()
	var dino_script = load("res://scripts/entities/Dino.gd")
	var others: Array[Node3D] = []
	for i in 32:
		var o := Node3D.new()
		world.add_child(o)
		others.append(o)
		dino_script.claim_attack_slot(trap, o)
	var d = _raptor(Vector3(0.0, 0.0, 3.0), world)
	await wait_physics_frames(int(2.0 * float(Engine.physics_ticks_per_second)))
	assert_ne(d.current_target, trap, "Every place round it taken, it does not queue under its fire")
	assert_true(d._is_crowded(trap), "it leaves that one be a while")
	assert_eq(d._preferred_target(), null, "and chooses something else -- here, nothing: the road on")
	dino_script.clear_all_attack_slots()

func test_12d_a_place_where_the_others_wait_round_a_trap_is_no_better() -> void:
	# The ring round a trap where raiders wait for a place to bite from is under its fire as much as
	# the queue beyond it: they milled there (BUG-009). A raider that gets only a place there leaves
	# the trap be too.
	var world := await _field()
	var trap = load("res://scripts/entities/Tower.gd").new()
	world.add_child(trap)
	trap.setup("set_crossbow")
	trap.position = Vector3.ZERO
	trap.complete_construction()
	trap.process_mode = Node.PROCESS_MODE_DISABLED
	await rebake_fixture()
	var dino_script = load("res://scripts/entities/Dino.gd")
	# Every place to bite it from taken; the ring where they wait, free.
	for i in 32:
		var o := Node3D.new()
		world.add_child(o)
		if dino_script.free_inner_slot(trap, o) != Vector3.ZERO:
			dino_script.claim_attack_slot(trap, o)
	var d = _raptor(Vector3(0.0, 0.0, 3.0), world)
	await wait_physics_frames(int(2.0 * float(Engine.physics_ticks_per_second)))
	assert_ne(d.current_target, trap, "A place in the ring where the others wait is no place to wait")
	assert_true(d._is_crowded(trap), "it leaves that one be a while")
	dino_script.clear_all_attack_slots()

func test_12c_it_goes_for_the_trap_that_shot_it() -> void:
	# Not the nearest trap to it: the one hurting it (BUG-009).
	var world := await _field()
	var near_one = load("res://scripts/entities/Tower.gd").new()
	var shooter = load("res://scripts/entities/Tower.gd").new()
	for t in [near_one, shooter]:
		world.add_child(t)
		t.setup("set_crossbow")
		t.complete_construction()
		t.process_mode = Node.PROCESS_MODE_DISABLED
	near_one.position = Vector3(1.5, 0.0, 0.0)
	shooter.position = Vector3(-3.0, 0.0, 0.0)
	await rebake_fixture()
	var d = _raptor(Vector3(0.5, 0.0, 2.0), world)
	d.set_physics_process(false)
	assert_eq(d._preferred_target(), near_one, "Unshot, it goes for the nearest trap")
	d.shot_by(shooter)
	assert_eq(d._preferred_target(), shooter, "shot, for the one that shot it")
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()

# ==============================================================================
# 13. Held up long against a wall between it and where it is going, it goes through
# ==============================================================================

## A raptor up against `wall`, making for `goal` by a route round it that gets it no nearer
## (Dino._way_left stays put): what a line of them jammed in a corridor is to each of them.
func _held_at(world: Node3D, at: Vector3, goal: Vector3) -> Node:
	var d = _raptor(at, world)
	d.set_physics_process(false)
	d._nav_goal = goal
	d._route = PackedVector3Array([at, at + Vector3(3.0, 0.0, -1.0), goal])
	d._route_index = 1
	return d

func test_13_held_up_long_against_a_wall_between_it_and_its_goal_it_goes_through() -> void:
	# The player's report, 2026-09-29: "恐龙大波会在走廊（两行栅栏中间徘徊）" -- a raid's worth in single file
	# up a one-metre corridor to a one-cell gap milled up and down it, walking a lot and getting no
	# nearer, and a crowd never bites a wall it could go round.
	var world := await _field()
	var wall = _stake(world, Vector3(0.0, 0.0, -1.0))
	await rebake_fixture()
	var d = _held_at(world, Vector3.ZERO, Vector3(0.0, 0.0, -6.0))
	await wait_physics_frames(2)
	var step: float = 0.25
	var jam: float = _ai("jam_seconds")
	var t: float = 0.0
	while t + step < jam:
		d._watch_for_a_jam(step)
		t += step
	assert_ne(d.current_target, wall, "Not before it has been held up the while")
	d._watch_for_a_jam(step * 2.0)
	assert_eq(d.current_target, wall, "Held up that long, it goes through the wall between it and where it is going")
	assert_eq(int(d.mode), int(d.Mode.BREACH), "to break it")
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()

func test_13b_one_getting_nearer_or_with_the_wall_beside_it_goes_round() -> void:
	var world := await _field()
	var ahead = _stake(world, Vector3(6.0, 0.0, -1.0))
	var beside = _stake(world, Vector3(-5.0, 0.0, 0.0))
	await rebake_fixture()
	var jam: float = _ai("jam_seconds")
	# Getting nearer all the while: however long it takes, it is not held up.
	var going = _held_at(world, Vector3(6.0, 0.0, 0.0), Vector3(6.0, 0.0, -6.0))
	going._route = PackedVector3Array([going.global_position, Vector3(6.0, 0.0, -6.0)])
	going._route_index = 1
	await wait_physics_frames(2)
	for i in int(ceil(jam / 0.25)) + 4:
		going.global_position.z -= float(config_node.DINO_AI["jam_progress"]) * 1.2
		going._watch_for_a_jam(0.25)
	assert_ne(going.current_target, ahead, "Getting nearer all the while, it is not held up")
	# The wall beside it, not in its way: held up or not, it is not what is between it and its goal.
	var aside = _held_at(world, Vector3(-4.0, 0.0, 0.0), Vector3(-4.0, 0.0, -6.0))
	await wait_physics_frames(2)
	var t: float = 0.0
	while t < jam + 0.5:
		aside._watch_for_a_jam(0.25)
		t += 0.25
	assert_ne(aside.current_target, beside, "A wall beside it is not what is in its way")
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()

func test_13c_waiting_in_a_queue_behind_a_wall_it_is_held_up_too() -> void:
	# The debug-agent's BUG-025: in the player's corridor a raid stood in a queue seventy seconds, one
	# biting the cabin at a time, and no wall was bitten: each one's place at the cabin was handed about
	# and its way asked afresh after getting nowhere (_unstick), and either put the clock back; and none
	# was up against the fence -- a queue waits a body's length behind the one ahead.
	var world := await _field()
	var reach: float = _ai("jam_reach")
	var between = _stake(world, Vector3(0.0, 0.0, -(0.5 + reach * 0.8)))
	var behind = _stake(world, Vector3(0.0, 0.0, 0.5 + reach * 0.8))
	await rebake_fixture()
	var d = _held_at(world, Vector3.ZERO, Vector3(0.0, 0.0, -6.0))
	await wait_physics_frames(2)
	assert_null(d._building_pressed_against(), "(it is not up against either)")
	var step: float = 0.25
	var jam: float = _ai("jam_seconds")
	var t: float = 0.0
	var k: int = 0
	while t < jam - step:
		k += 1
		# Its place handed about, and a fresh way asked for now and then, by turns.
		d._nav_goal = Vector3.INF if k % 5 == 0 else Vector3(float(k % 3) * 1.5 - 1.5, 0.0, -6.0)
		d._watch_for_a_jam(step)
		t += step
	assert_ne(d.current_target, between, "(not before it has waited the while)")
	d._watch_for_a_jam(step * 2.0)
	assert_eq(d.current_target, between, "Waiting that long, it goes through the wall between it and where it is going")
	assert_ne(d.current_target, behind, "(not the one behind it)")
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
