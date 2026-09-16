# res://tests/test_v02_realtime_and_systems.gd
# Comprehensive Integration Test Suite for Defend Dinosaur v0.2:
# 1. Native Godot i18n Localization (strings.csv, I18n autoload, zh_CN / en)
# 2. Map Natural Resources & Harvesting (ResourceNode, capacity limits, exhaustion)
# 3. Machinery Tending System (LumberHut 40s timer, 1s wood payout, timeout stops production)
# 4. Hero Work Tasks (Harvesting resource nodes, Tending lumber huts)
# 5. Building Demolition with 50% Resource Refund
# 6. In-World 3D Building & Resource Labels (Label3D status, percentage, operating)
# 7. Unified Selection & RTS Option Panel (Command card, two-level hero build, contextual actions)
# 8. Continuous Raids, 15s Raid Warning Banner & Dino Threat Priority Targeting
# 9. Game Speed Controls (1x, 2x, 3x)
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null
var i18n_node: Object = null

var resource_node_script: GDScript = null
var hero_script: GDScript = null
var lumber_hut_script: GDScript = null
var wall_script: GDScript = null
var tower_script: GDScript = null
var dino_script: GDScript = null
var wave_mgr_script: GDScript = null
var option_panel_script: GDScript = null
var hud_script: GDScript = null
var grid_mgr_script: GDScript = null
var build_system_script: GDScript = null
var producer_building_script: GDScript = null
var main_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")
		i18n_node = tree.root.get_node_or_null("I18n")

	resource_node_script = _load_script(["res://scripts/entities/ResourceNode.gd"])
	hero_script = _load_script(["res://scripts/entities/Hero.gd"])
	lumber_hut_script = _load_script(["res://scripts/entities/LumberHut.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd"])
	dino_script = _load_script(["res://scripts/entities/Dino.gd"])
	wave_mgr_script = _load_script(["res://scripts/core/WaveManager.gd"])
	option_panel_script = _load_script(["res://scripts/ui/OptionPanel.gd"])
	hud_script = _load_script(["res://scripts/ui/HUD.gd"])
	grid_mgr_script = _load_script(["res://scripts/core/GridManager.gd"])
	build_system_script = _load_script(["res://scripts/core/BuildSystem.gd"])
	producer_building_script = _load_script(["res://scripts/entities/ProducerBuilding.gd"])
	main_script = _load_script(["res://scripts/core/Main.gd"])

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	Engine.time_scale = 1.0

func after_each() -> void:
	Engine.time_scale = 1.0
	for node in _cleanup_nodes:
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.free()
	_cleanup_nodes.clear()
	clear_drops()   # v0.3: production leaves piles behind, and they are not the next test's
	super.after_each()

## Seconds of operation needed for `type_id` to bank `units` of `res_id`,
## derived from Config so a balance pass does not invalidate these tests.
func _secs_for(type_id: String, res_id: String, units: int) -> float:
	var rate: float = 0.5
	if config_node and "BUILDINGS" in config_node and config_node.BUILDINGS.has(type_id):
		rate = float(config_node.BUILDINGS[type_id].get("produces_per_sec", {}).get(res_id, 0.5))
	return float(units) / maxf(rate, 0.01)

## Seconds the Hero must spend to hand-harvest `units` from a node of `res_type`.
func _hand_secs_for(res_type: String, units: int) -> float:
	var rate: float = 1.0
	if config_node and "RESOURCE_NODES" in config_node and config_node.RESOURCE_NODES.has(res_type):
		rate = float(config_node.RESOURCE_NODES[res_type].get("harvest_rate", 1.0))
	return float(units) / maxf(rate, 0.01)

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

# ==============================================================================
# Feature 1: Native Godot i18n Localization
# ==============================================================================

func test_01_i18n_runtime_switching_and_translation() -> void:
	assert_not_null(i18n_node, "I18n autoload must be registered")
	var initial_locale = i18n_node.get_current_locale()

	# Test switching to English
	i18n_node.set_locale("en")
	assert_eq(i18n_node.get_current_locale(), "en", "Current locale switched to en")
	assert_eq(tr("BUILDING_WALL_NAME"), "Wooden Stakes", "Wall translated in English")
	assert_eq(tr("CMD_BUILD"), "Build", "Build command translated in English")

	# Test switching to Chinese
	i18n_node.set_locale("zh_CN")
	assert_eq(i18n_node.get_current_locale(), "zh_CN", "Current locale switched to zh_CN")
	assert_eq(tr("BUILDING_WALL_NAME"), "木栅栏", "Wall translated in Simplified Chinese")
	assert_eq(tr("CMD_BUILD"), "建造", "Build command translated in Simplified Chinese")

	# Restore initial locale
	i18n_node.set_locale(initial_locale)

# ==============================================================================
# Feature 2: Natural Resource Nodes & Capacity Exhaustion
# ==============================================================================

func test_02_resource_node_harvest_and_exhaustion() -> void:
	assert_not_null(resource_node_script, "ResourceNode.gd must exist")
	var node = resource_node_script.new()
	_cleanup_nodes.append(node)
	tree.root.add_child(node)

	node.setup("wood", Vector2i(3, 4), 30)
	assert_eq(node.resource_type, "wood", "Resource type is wood")
	assert_eq(node.max_capacity, 30, "Max capacity is 30")
	assert_eq(node.current_amount, 30, "Current amount starts full at 30")
	assert_false(node.is_depleted, "Node starts not depleted")

	# Harvest partial
	var harvested_1 = node.harvest(10)
	assert_eq(harvested_1, 10, "Harvested 10 wood successfully")
	assert_eq(node.current_amount, 20, "Remaining wood is 20")
	assert_false(node.is_depleted, "Still not depleted")

	# Harvest remainder to exhaustion
	var harvested_2 = node.harvest(25)
	assert_eq(harvested_2, 20, "Only 20 remaining could be harvested")
	assert_eq(node.current_amount, 0, "Current amount is 0")
	assert_true(node.is_depleted, "Node is now depleted")

	# Harvest on depleted node returns 0
	var harvested_3 = node.harvest(5)
	assert_eq(harvested_3, 0, "Depleted node yields 0 resources")

# ==============================================================================
# Feature 3 & 4: Hero Harvesting & Deposit into GameState
# ==============================================================================

func test_03_hero_harvest_order_and_deposit() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(resource_node_script, "ResourceNode.gd must exist")

	var hero = hero_script.new()
	var res_node = resource_node_script.new()
	_cleanup_nodes.append(hero)
	_cleanup_nodes.append(res_node)
	tree.root.add_child(hero)
	tree.root.add_child(res_node)

	hero.position = Vector3.ZERO
	res_node.position = Vector3(1.0, 0.0, 0.0) # Within harvest range 1.8m
	res_node.setup("stone", Vector2i(1, 0), 20)

	var init_stone: int = int(game_state_node.resources.get("stone", 0))
	var init_earned: int = earned_total("stone")

	# Order harvest
	hero.order_harvest(res_node)
	assert_eq(int(hero.current_state), int(hero_script.State.HARVESTING), "Hero enters HARVESTING state")

	# Harvest long enough to cut at least one unit at the configured rate.
	var harvest_secs: float = _hand_secs_for("stone", 1) + 0.5
	hero._physics_process(harvest_secs * 0.5)
	hero._physics_process(harvest_secs * 0.5)

	# v0.3: even what the Hero digs up himself lands on the ground first, so there
	# is one rule for every resource instead of one for hands and one for machines.
	# He is standing on it, so the sweep at the top of his next step banks it.
	assert_gt(earned_total("stone"), init_earned, "Harvesting produced stone")
	hero._physics_process(0.016)
	assert_gt(int(game_state_node.resources.get("stone", 0)), init_stone,
		"And carrying it is what puts it in the warehouse")

# ==============================================================================
# Feature 5: Machinery Tending (LumberHut)
# ==============================================================================

func test_04_lumber_hut_machinery_tending_lifecycle() -> void:
	assert_not_null(lumber_hut_script, "LumberHut.gd must exist")
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()

	assert_false(hut.is_operating, "LumberHut initially idle (not operating)")

	var init_wood: int = earned_total("wood")
	var init_banked: int = int(game_state_node.resources.get("wood", 0))

	# 5 seconds pass without tending -> 0 wood produced
	hut._process(5.0)
	assert_eq(earned_total("wood"), init_wood, "No wood produced while untended")

	# Tended but with no tree in range: machinery runs yet makes nothing.
	hut.tend(40.0)
	assert_true(hut.is_operating, "LumberHut is now operating after tending")
	assert_almost_eq(hut.operation_timer, 40.0, 0.1, "Operation timer set to 40.0s")
	hut._process(1.0)
	hut._process(1.0)
	assert_eq(earned_total("wood"), init_wood,
		"Nothing produced while operating with no tree in harvest range")
	assert_null(hut.target_source, "No source acquired when none is in range")

	# Plant a tree inside harvest_range, then the same 2s at 0.5 wood/s yields 1 wood.
	var tree_node = resource_node_script.new("wood", Vector2i(0, 1))
	_cleanup_nodes.append(tree_node)
	tree.root.add_child(tree_node)
	tree_node.position = hut.global_position + Vector3(2.0, 0.0, 0.0)
	var tree_before: int = tree_node.current_amount

	var one_wood_secs: float = _secs_for("lumber_hut", "wood", 1)
	hut.tend(one_wood_secs + 5.0)
	hut._process(one_wood_secs * 0.5)
	hut._process(one_wood_secs * 0.5)
	assert_eq(earned_total("wood"), init_wood + 1, "Produced 1 wood at the configured rate")
	assert_eq(int(game_state_node.resources.get("wood", 0)), init_banked,
		"Which is lying beside the hut, not in the warehouse -- nobody has fetched it")
	assert_eq(ground_total("wood"), 1, "One pile, waiting to be carried")
	assert_eq(tree_node.current_amount, tree_before - 1, "The wood came out of the tree's remaining amount")
	assert_eq(hut.target_source, tree_node, "Hut locked onto the nearby tree as its source")

	# Advance until operation timer expires (38 remaining seconds)
	hut._process(38.0)
	assert_false(hut.is_operating, "LumberHut stops operating after timer expires")
	assert_eq(hut.operation_timer, 0.0, "Operation timer is 0.0s")

# ==============================================================================
# Feature 6: Hero Tending Action Order
# ==============================================================================

func test_05_hero_order_tend_lumber_hut() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(lumber_hut_script, "LumberHut.gd must exist")

	var hero = hero_script.new()
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hero)
	_cleanup_nodes.append(hut)
	tree.root.add_child(hero)
	tree.root.add_child(hut)
	hut.complete_construction()

	hero.position = Vector3.ZERO
	hut.position = Vector3(1.0, 0.0, 0.0)

	assert_false(hut.is_operating, "Hut starts idle")

	hero.order_tend(hut)
	assert_eq(int(hero.current_state), int(hero_script.State.TENDING), "Hero enters TENDING state")

	# Advance tending progress by 2.0s (required tending duration)
	hero._physics_process(1.0)
	hero._physics_process(1.1)

	assert_true(hut.is_operating, "LumberHut activated after Hero completed tending")
	assert_eq(int(hero.current_state), 0, "Hero returns to IDLE after completing tending")

# ==============================================================================
# Feature 7: Building Demolition & 50% Refund
# ==============================================================================

func test_06_building_demolish_and_half_refund() -> void:
	assert_not_null(wall_script, "Wall.gd must exist")
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.setup("wall")
	wall.complete_construction()

	var init_wood: int = int(game_state_node.resources.get("wood", 0))

	# Demolishing a completed wall gives back half its Config cost (min 1) -- as
	# rubble on the ground since v0.3, not as a number. The refund was the last way
	# resources reached the warehouse without passing through the Hero.
	var refund: int = maxi(1, int(cost_of("wall") / 2))
	assert_eq(int(wall.demolition_refund().get("wood", 0)), refund, "Half the build cost comes back")
	wall.demolish()
	assert_true(wall.is_destroyed, "Building is marked destroyed on demolish")
	assert_eq(int(game_state_node.resources.get("wood", 0)), init_wood, "But not straight into the warehouse")
	assert_eq(ground_total("wood"), refund, "It is lying in the rubble, waiting to be picked up")

# ==============================================================================
# Feature 8: In-World 3D Labels
# ==============================================================================

func test_07_in_world_3d_building_and_resource_labels() -> void:
	assert_not_null(wall_script, "Wall.gd must exist")
	assert_not_null(resource_node_script, "ResourceNode.gd must exist")

	# Test building label during construction
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.setup("wall")
	wall.start_construction(4.0)

	assert_not_null(wall.label_3d, "Building has Label3D child")
	assert_true(wall.label_3d.text.contains("[ 0% ]"), "Label shows 0% at start of construction")

	wall.add_build_progress(2.0)
	assert_true(wall.label_3d.text.contains("[ 50% ]"), "Label shows 50% mid-construction")

	wall.complete_construction()
	assert_false(wall.label_3d.text.contains("%"), "Label does not show percentage once completed")

	# Test resource node label
	var res = resource_node_script.new()
	_cleanup_nodes.append(res)
	tree.root.add_child(res)
	res.setup("stone", Vector2i(0, 0), 25)

	assert_not_null(res.label_3d, "ResourceNode has Label3D child")
	assert_true(res.label_3d.text.contains("25 / 25"), "ResourceNode label shows capacity fraction")

# ==============================================================================
# Feature 9: Selection & RTS Option Panel (Command Card)
# ==============================================================================

func test_08_option_panel_two_level_command_hierarchy() -> void:
	assert_not_null(option_panel_script, "OptionPanel.gd must exist")
	assert_not_null(hero_script, "Hero.gd must exist")

	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(panel)
	tree.root.add_child(hero)

	# 1. Select Hero -> Level 1 menu (Build, Stop)
	panel.select_target(hero)
	assert_true(panel.visible, "Panel is visible when Hero selected")
	assert_eq(panel.current_menu_level, 1, "Menu is at Level 1")

	# 2. Click Build button -> Transitions to Level 2 menu
	panel._on_build_pressed()
	assert_eq(panel.current_menu_level, 2, "Menu entered Level 2 (Building catalog)")

	# 3. Click Back button -> Transitions back to Level 1 menu
	panel._on_back_pressed()
	assert_eq(panel.current_menu_level, 1, "Menu returned to Level 1")

	# 4. Deselect resets to default (Hero if exists in tree)
	panel.deselect()
	assert_eq(panel.selected_target, hero, "Deselect defaults to Hero selection")

# ==============================================================================
# Feature 10: Realtime Raid Timer & 15s Pre-Raid Warning Banner
# ==============================================================================

func test_09_wave_manager_realtime_raid_and_warning() -> void:
	assert_not_null(wave_mgr_script, "WaveManager.gd must exist")
	var wm = wave_mgr_script.new()
	_cleanup_nodes.append(wm)
	tree.root.add_child(wm)

	var warning_watcher = watch_signal(event_bus_node, "raid_warning")

	# Enable auto raids for this test
	wm.auto_raid_enabled = true
	wm.warning_emitted = false

	# Set raid timer to 16.0s (just outside warning window)
	wm.raid_timer = 16.0
	wm._process(0.5) # Now 15.5s -> no warning
	assert_false(warning_watcher.emitted, "No warning emitted above 15 seconds")

	# Advance past 15.0s mark (15.5 - 1.0 = 14.5s)
	wm._process(1.0)
	assert_true(warning_watcher.emitted, "raid_warning signal emitted when <= 15s remain")

# ==============================================================================
# Feature 11: Dino Threat Priority Targeting
# ==============================================================================

func test_10_dino_threat_priority_targeting() -> void:
	assert_not_null(dino_script, "Dino.gd must exist")
	assert_not_null(tower_script, "Tower.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")
	assert_not_null(hero_script, "Hero.gd must exist")

	var dino = dino_script.new()
	var tower = tower_script.new()
	var wall = wall_script.new()
	var hero = hero_script.new()

	_cleanup_nodes.append(dino)
	_cleanup_nodes.append(tower)
	_cleanup_nodes.append(wall)
	_cleanup_nodes.append(hero)

	tree.root.add_child(dino)
	tree.root.add_child(tower)
	tree.root.add_child(wall)
	tree.root.add_child(hero)

	tower.setup("tower")
	tower.complete_construction()
	wall.setup("wall")
	wall.complete_construction()

	dino.position = Vector3.ZERO
	# Defensive tower at 3.5m is prioritized over standard wall at 2.0m
	tower.position = Vector3(3.5, 0.0, 0.0)
	wall.position = Vector3(2.0, 0.0, 0.0)
	hero.position = Vector3(1.0, 0.0, 0.0)

	# 1. Unprovoked Hero: Tower is threat priority over Wall and Hero
	var target = dino._find_threat_priority_target()
	assert_eq(target, tower, "Dino prioritizes defensive Tower over other entities")

	# 2. Hero provokes dinos by attacking
	hero.has_provoked_dinos = true
	var prov_target = dino._find_threat_priority_target()
	# Hero is 1m away (closer than tower at 3.5m) and has provoked dinos
	assert_eq(prov_target, hero, "Dino targets provoked Hero who attacked them")

# ==============================================================================
# Feature 12: HUD Speed Controls (1x, 2x, 3x)
# ==============================================================================

func test_11_hud_game_speed_controls() -> void:
	assert_not_null(hud_script, "HUD.gd must exist")
	var hud = hud_script.new()
	_cleanup_nodes.append(hud)
	tree.root.add_child(hud)

	var speed_watcher = watch_signal(event_bus_node, "game_speed_changed")

	assert_eq(hud.current_speed, 1.0, "HUD starts at 1.0x speed")
	assert_eq(Engine.time_scale, 1.0, "Engine time_scale starts at 1.0")

	# Cycle speed -> 2.0x
	hud._on_speed_button_pressed()
	assert_eq(hud.current_speed, 2.0, "Speed advanced to 2.0x")
	assert_eq(Engine.time_scale, 2.0, "Engine time_scale is 2.0")
	assert_true(speed_watcher.emitted, "game_speed_changed signal emitted")

	# Cycle speed -> 3.0x
	hud._on_speed_button_pressed()
	assert_eq(hud.current_speed, 3.0, "Speed advanced to 3.0x")
	assert_eq(Engine.time_scale, 3.0, "Engine time_scale is 3.0")

	# Cycle speed -> wraps to 1.0x
	hud._on_speed_button_pressed()
	assert_eq(hud.current_speed, 1.0, "Speed wrapped back to 1.0x")
	assert_eq(Engine.time_scale, 1.0, "Engine time_scale restored to 1.0")

# ==============================================================================
# Feature 13: Config-Driven Raid Interval Verification (Finding 1)
# ==============================================================================

func test_12_config_raid_interval_override_effective() -> void:
	assert_not_null(wave_mgr_script, "WaveManager.gd must exist")
	assert_not_null(config_node, "Config autoload must exist")

	var wm = wave_mgr_script.new()
	_cleanup_nodes.append(wm)
	tree.root.add_child(wm)

	# 1. Verify default range from Config.RAIDS
	var min_i = float(config_node.RAIDS["interval_min"])
	var max_i = float(config_node.RAIDS["interval_max"])
	wm._reset_raid_timer()
	assert_true(wm.raid_timer >= min_i and wm.raid_timer <= max_i, "Default raid timer respects Config.RAIDS [%.1f, %.1f]" % [min_i, max_i])

	# 2. Test override with custom config
	var mock_cfg = RefCounted.new()
	var script = GDScript.new()
	script.source_code = "extends RefCounted\nvar RAIDS: Dictionary = {'interval_min': 10.0, 'interval_max': 12.0}\n"
	script.reload()
	mock_cfg.set_script(script)

	wm.config_override = mock_cfg
	wm._reset_raid_timer()
	assert_true(wm.raid_timer >= 10.0 and wm.raid_timer <= 12.0, "Raid timer dynamically respects overridden interval_min/max [10, 12]")

# ==============================================================================
# Feature 14: Dynamic Producer Building & Quarry Tending (Findings 4, 5, 6)
# ==============================================================================

func test_13_quarry_tending_produces_stone_dynamically() -> void:
	assert_not_null(producer_building_script, "ProducerBuilding.gd must exist")
	assert_not_null(hero_script, "Hero.gd must exist")

	var quarry = producer_building_script.new("quarry")
	var hero = hero_script.new()
	_cleanup_nodes.append(quarry)
	_cleanup_nodes.append(hero)
	tree.root.add_child(quarry)
	tree.root.add_child(hero)

	quarry.setup("quarry", Vector2i(2, 2))
	quarry.complete_construction()

	assert_eq(quarry.get_tend_duration(), 40.0, "Quarry tend duration from Config is 40.0s")
	assert_eq(quarry.get_tend_time(), 2.5, "Quarry tend time from Config is 2.5s")

	# Hero approaches quarry and tends it
	hero.position = Vector3.ZERO
	quarry.position = Vector3(1.0, 0.0, 0.0)
	hero.order_tend(quarry)
	assert_eq(int(hero.current_state), int(hero_script.State.TENDING), "Hero enters TENDING")

	# Advance 2.5s tending duration
	hero._physics_process(1.5)
	hero._physics_process(1.1)
	assert_true(quarry.is_operating, "Quarry is operating after 2.5s Hero tending")

	# Quarries must draw from a real stone outcrop inside harvest_range.
	var rock = resource_node_script.new("stone", Vector2i(3, 2))
	_cleanup_nodes.append(rock)
	tree.root.add_child(rock)
	rock.position = quarry.global_position + Vector3(3.0, 0.0, 0.0)

	var init_stone: int = earned_total("stone")
	var three_stone_secs: float = _secs_for("quarry", "stone", 3)
	quarry.tend(three_stone_secs + 5.0)
	quarry._process(three_stone_secs)
	assert_eq(earned_total("stone"), init_stone + 3, "Quarry produces 3 stone at the configured rate")
	# The Hero is at the origin and the quarry 1m away, so the stone piles up at
	# the quarry's side; it reaches the warehouse when somebody carries it.
	assert_eq(ground_total("stone"), 3, "Cut and stacked, not banked")

# ==============================================================================
# Feature 15: GridManager Natural Resource Obstacle (Finding 3)
# ==============================================================================

func test_14_grid_manager_resource_obstacle_blocks_building_and_pathfinding() -> void:
	assert_not_null(grid_mgr_script, "GridManager.gd must exist")
	assert_not_null(build_system_script, "BuildSystem.gd must exist")
	assert_not_null(resource_node_script, "ResourceNode.gd must exist")

	var gm = grid_mgr_script.new()
	var bs = build_system_script.new()
	var res = resource_node_script.new("wood", Vector2i(3, 3))
	_cleanup_nodes.append(gm)
	_cleanup_nodes.append(bs)
	_cleanup_nodes.append(res)
	tree.root.add_child(gm)
	tree.root.add_child(bs)
	tree.root.add_child(res)

	bs.setup(gm, null)

	# Register resource node in GridManager
	gm.occupy_resource_cell(Vector2i(3, 3), res)
	assert_true(gm.is_resource_at_cell(Vector2i(3, 3)), "GridManager tracks resource at (3, 3)")
	assert_false(gm.is_cell_walkable(Vector2i(3, 3)), "Cell (3, 3) is NOT walkable due to resource node")
	assert_false(bs.can_place_building("wall", Vector2i(3, 3)), "BuildSystem prevents placing building on resource cell")

# ==============================================================================
# Feature 16: Raid State Reset on Game Restart (Finding 8)
# ==============================================================================

func test_15_restart_game_resets_raid_timer_and_warning() -> void:
	assert_not_null(wave_mgr_script, "WaveManager.gd must exist")
	var wm = wave_mgr_script.new()
	_cleanup_nodes.append(wm)
	tree.root.add_child(wm)

	wm.auto_raid_enabled = true
	wm.elapsed_time = 50.0
	wm.raid_timer = 10.0
	wm.warning_emitted = true

	# Reset raid state
	wm.reset_raid_state()
	var expected_delay: float = float(config_node.RAIDS.get("first_raid_delay", 60.0))
	assert_eq(wm.raid_timer, expected_delay, "Raid timer reset to first_raid_delay")
	assert_false(wm.warning_emitted, "warning_emitted reset to false")
	assert_eq(wm.elapsed_time, 0.0, "elapsed_time reset to 0.0")

# ==============================================================================
# Feature 17: UI English & Chinese Cleanliness (Finding 2)
# ==============================================================================

func test_16_ui_locale_english_no_chinese_and_chinese_no_english_leak() -> void:
	assert_not_null(hud_script, "HUD.gd must exist")
	assert_not_null(option_panel_script, "OptionPanel.gd must exist")
	assert_not_null(i18n_node, "I18n autoload must exist")

	var hud = hud_script.new()
	var panel = option_panel_script.new()
	_cleanup_nodes.append(hud)
	_cleanup_nodes.append(panel)
	tree.root.add_child(hud)
	tree.root.add_child(panel)

	# 1. Test in English
	i18n_node.set_locale("en")
	hud.reset_hud()
	assert_false(hud.end_action_btn.text.contains("提前结束"), "English HUD does not contain Chinese characters")
	assert_false(hud.pause_btn.text.contains("暂停"), "English Pause button does not contain Chinese characters")
	assert_eq(hud.end_action_btn.text, "Early End Deploy", "English End Deploy button text is correct")

	# 2. Test in Chinese
	i18n_node.set_locale("zh_CN")
	hud.reset_hud()
	assert_true(hud.end_action_btn.text.contains("提前结束"), "Chinese HUD displays translated button text")
	assert_true(hud.pause_btn.text.contains("暂停"), "Chinese HUD displays translated Pause text")

	# Restore English
	i18n_node.set_locale("en")

# ==============================================================================
# Feature 18: Real Tree Harvesting in Range (v0.2 Follow-up Item 4)
# ==============================================================================

func test_17_lumber_hut_real_tree_harvesting_and_target_switching() -> void:
	assert_not_null(lumber_hut_script, "LumberHut.gd must exist")
	assert_not_null(resource_node_script, "ResourceNode.gd must exist")

	var hut = lumber_hut_script.new()
	var tree_near = resource_node_script.new("wood")
	var tree_far = resource_node_script.new("wood")
	var tree_out_of_range = resource_node_script.new("wood")

	_cleanup_nodes.append(hut)
	_cleanup_nodes.append(tree_near)
	_cleanup_nodes.append(tree_far)
	_cleanup_nodes.append(tree_out_of_range)

	tree.root.add_child(hut)
	tree.root.add_child(tree_near)
	tree.root.add_child(tree_far)
	tree.root.add_child(tree_out_of_range)

	hut.complete_construction()
	hut.position = Vector3.ZERO

	tree_near.position = Vector3(3.0, 0.0, 0.0)
	tree_near.setup("wood", Vector2i(1, 0), 2) # Near tree: 2 wood

	tree_far.position = Vector3(7.0, 0.0, 0.0)
	tree_far.setup("wood", Vector2i(3, 0), 5) # Far tree: 5 wood

	tree_out_of_range.position = Vector3(25.0, 0.0, 0.0) # > 12.0m away
	tree_out_of_range.setup("wood", Vector2i(12, 0), 10)

	# 1. Nearest tree is chosen (tree_near at 3m < tree_far at 7m)
	var found_tree = hut.find_nearest_tree()
	assert_eq(found_tree, tree_near, "Lumber Hut selects the closest tree within range")

	# 2. Tend hut and harvest 2 wood (depleting tree_near)
	var init_wood: int = earned_total("wood")
	hut.tend(40.0)

	var per_wood: float = _secs_for("lumber_hut", "wood", 1)
	hut._process(per_wood)
	assert_eq(tree_near.current_amount, 1, "First tree depleted by 1 wood")
	assert_eq(earned_total("wood"), init_wood + 1, "A first unit of wood exists")

	hut._process(per_wood)
	assert_eq(tree_near.current_amount, 0, "First tree fully depleted")
	assert_true(tree_near.is_depleted, "First tree is marked depleted")
	assert_eq(earned_total("wood"), init_wood + 2, "A second unit of wood exists")

	# 3. Next tick automatically switches to tree_far
	hut._process(per_wood)
	assert_eq(hut.target_tree, tree_far, "Lumber Hut switched to the next nearest tree")
	assert_eq(tree_far.current_amount, 4, "Second tree was harvested")
	assert_eq(earned_total("wood"), init_wood + 3, "And a third, from the second tree")

	# 4. Exhaust second tree
	tree_far.harvest(4)
	assert_true(tree_far.is_depleted, "Second tree is now depleted")

	# 5. When no trees remain in range, no wood is harvested even though out-of-range tree has 10 wood
	var wood_before: int = earned_total("wood")
	hut._process(10.0)
	assert_eq(earned_total("wood"), wood_before, "No wood harvested when all trees in range are depleted")
	assert_eq(tree_out_of_range.current_amount, 10, "Out of range tree remains untouched")
	assert_null(hut.find_nearest_tree(), "No tree found in range")
	assert_true(hut.get_display_info()["status"].contains("No trees in range") or hut.get_display_info()["status"].contains("范围内无可用树木"), "Status indicates no trees in range")

# ==============================================================================
# Feature 19: Camera Zoom and Clamping Bounds (v0.2 Follow-up Item 3)
# ==============================================================================

func test_18_camera_zoom_and_clamping() -> void:
	assert_not_null(main_script, "Main.gd must exist")
	var main = main_script.new()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	main._ensure_scene_dependencies()

	var cam = main.camera
	assert_not_null(cam, "Camera exists in Main")

	var init_y = cam.global_position.y
	assert_almost_eq(init_y, 18.0, 0.1, "Initial camera height is ~18.0m")

	# Zoom in (moves camera forward and downward)
	main.zoom_camera(4.0)
	assert_lt(cam.global_position.y, init_y, "Camera zoomed in closer to the ground")

	# Extreme zoom in clamped at 6.0m
	for i in range(20):
		main.zoom_camera(5.0)
	assert_gte(cam.global_position.y, 6.0, "Camera zoom in clamped at min height >= 6.0m")

	# Extreme zoom out clamped at 32.0m
	for i in range(30):
		main.zoom_camera(-5.0)
	assert_lte(cam.global_position.y, 32.0, "Camera zoom out clamped at max height <= 32.0m")

# ==============================================================================
# Feature 20: HUD Cleanliness & In-World Label Sizes (v0.2 Follow-up Items 1 & 2)
# ==============================================================================

func test_19_hud_no_legacy_buttons_and_larger_option_panel() -> void:
	var hud_scene = load("res://scenes/ui/HUD.tscn")
	assert_not_null(hud_scene, "HUD.tscn must be loadable")
	var hud_inst = hud_scene.instantiate()
	_cleanup_nodes.append(hud_inst)
	tree.root.add_child(hud_inst)

	# Verify BottomBar is gone from the scene
	assert_null(hud_inst.find_child("BottomBar", true, false), "BottomBar was removed from HUD scene")

	# OptionPanel has larger minimum dimensions
	var panel = option_panel_script.new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	assert_gte(panel.custom_minimum_size.x, 300.0, "OptionPanel width >= 300")
	assert_gte(panel.custom_minimum_size.y, 200.0, "OptionPanel height >= 200")

func test_20_in_world_label3d_enlarged_fonts() -> void:
	var wall = wall_script.new()
	var res = resource_node_script.new("wood")
	_cleanup_nodes.append(wall)
	_cleanup_nodes.append(res)
	tree.root.add_child(wall)
	tree.root.add_child(res)

	assert_not_null(wall.label_3d, "Building has Label3D")
	assert_gte(wall.label_3d.font_size, 32, "Building Label3D font_size >= 32")
	assert_gte(wall.label_3d.outline_size, 5, "Building Label3D outline_size >= 5")

	assert_not_null(res.label_3d, "ResourceNode has Label3D")
	assert_gte(res.label_3d.font_size, 32, "ResourceNode Label3D font_size >= 32")
	assert_gte(res.label_3d.outline_size, 5, "ResourceNode Label3D outline_size >= 5")
