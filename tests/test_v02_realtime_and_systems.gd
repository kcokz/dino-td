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
	super.after_each()

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
	assert_eq(tr("BUILDING_WALL_NAME"), "Wood Wall", "Wall translated in English")
	assert_eq(tr("CMD_BUILD"), "Build", "Build command translated in English")

	# Test switching to Chinese
	i18n_node.set_locale("zh_CN")
	assert_eq(i18n_node.get_current_locale(), "zh_CN", "Current locale switched to zh_CN")
	assert_eq(tr("BUILDING_WALL_NAME"), "木墙", "Wall translated in Simplified Chinese")
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

	var init_stone = game_state_node.resources.get("stone", 0)

	# Order harvest
	hero.order_harvest(res_node)
	assert_eq(int(hero.current_state), int(hero_script.State.HARVESTING), "Hero enters HARVESTING state")

	# Simulate 1.5 seconds of harvesting
	hero._physics_process(1.0)
	hero._physics_process(0.5)

	var current_stone = game_state_node.resources.get("stone", 0)
	assert_gt(current_stone, init_stone, "Stone resources deposited into GameState from harvesting")

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

	var init_wood = game_state_node.resources.get("wood", 10)

	# 5 seconds pass without tending -> 0 wood produced
	hut._process(5.0)
	assert_eq(game_state_node.resources.get("wood", 10), init_wood, "No wood produced while untended")

	# Hero tends the hut for 40 seconds
	hut.tend(40.0)
	assert_true(hut.is_operating, "LumberHut is now operating after tending")
	assert_almost_eq(hut.operation_timer, 40.0, 0.1, "Operation timer set to 40.0s")

	# 2 seconds of operation -> +2 wood
	hut._process(1.0)
	hut._process(1.0)
	assert_eq(game_state_node.resources.get("wood", 10), init_wood + 2, "Produced 2 wood during 2s of operation")

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

	var init_wood = game_state_node.resources.get("wood", 10)

	# Demolishing completed wall (cost 2 wood) refunds 50% (1 wood)
	wall.demolish()
	assert_true(wall.is_destroyed, "Building is marked destroyed on demolish")
	assert_eq(game_state_node.resources.get("wood", 10), init_wood + 1, "50% refund (1 wood) deposited into GameState")

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
