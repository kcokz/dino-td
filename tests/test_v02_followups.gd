# res://tests/test_v02_followups.gd
# Test suite for the v0.2 follow-up changes:
# 1. Legacy HUD build buttons removed; building lives only on the Hero Option Panel.
# 2. Config.UI drives HUD / panel / world-label sizing (no hardcoded font sizes).
# 3. Phase-era top-bar controls (AP, deploy countdown, phase, end-deployment) hidden.
# 4. All producer machinery draws from real ResourceNodes within harvest_range,
#    and produces nothing when there is no source in range.
# 5. Stone and Water are visible in the HUD, not just Wood.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var hud_packed: PackedScene = null
var option_panel_script: GDScript = null
var producer_building_script: GDScript = null
var lumber_hut_script: GDScript = null
var resource_node_script: GDScript = null
var hero_script: GDScript = null
var build_system_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		hud_packed = load("res://scenes/ui/HUD.tscn")
	option_panel_script = _load_script("res://scripts/ui/OptionPanel.gd")
	producer_building_script = _load_script("res://scripts/entities/ProducerBuilding.gd")
	lumber_hut_script = _load_script("res://scripts/entities/LumberHut.gd")
	resource_node_script = _load_script("res://scripts/entities/ResourceNode.gd")
	hero_script = _load_script("res://scripts/entities/Hero.gd")
	build_system_script = _load_script("res://scripts/core/BuildSystem.gd")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func after_each() -> void:
	for node in _cleanup_nodes:
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.free()
	_cleanup_nodes.clear()
	super.after_each()

func _load_script(path: String) -> GDScript:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is GDScript:
			return res
	return null

func _spawn_hud() -> Node:
	var hud = hud_packed.instantiate()
	_cleanup_nodes.append(hud)
	tree.root.add_child(hud)
	return hud

# ==============================================================================
# 1. Legacy HUD build buttons are gone
# ==============================================================================

func test_01_hud_has_no_legacy_build_buttons() -> void:
	assert_not_null(hud_packed, "HUD.tscn must exist")
	var hud = _spawn_hud()
	await wait_frames(1)

	# The three per-building top-bar buttons were removed in favour of the Option Panel.
	for prop in ["build_tower_btn", "build_wall_btn", "build_lumber_btn"]:
		assert_false(prop in hud, "HUD must no longer expose '%s'" % prop)
	for node_name in ["BuildTowerBtn", "BuildWallBtn", "BuildLumberHutBtn"]:
		assert_null(hud.find_child(node_name, true, false),
			"HUD scene must not contain a '%s' node" % node_name)

func test_02_phase_era_controls_are_hidden() -> void:
	assert_not_null(hud_packed, "HUD.tscn must exist")
	var hud = _spawn_hud()
	await wait_frames(1)

	# v0.2 removed deploy/attack/produce phases, so these describe nothing actionable.
	assert_false(hud.ap_label.visible, "AP label hidden (AP was removed in v0.1)")
	assert_false(hud.deploy_timer_label.visible, "Deploy countdown hidden (no phases in v0.2)")
	assert_false(hud.phase_label.visible, "Phase label hidden (no phases in v0.2)")
	assert_false(hud.end_action_btn.visible, "End-deployment button hidden (no phases in v0.2)")
	assert_false(hud.wave_label.visible, "Wave label hidden (hidden concept in v0.2 continuous mode)")

func test_03_build_menu_is_driven_by_config_buildable_types() -> void:
	assert_not_null(option_panel_script, "OptionPanel.gd must exist")
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_true("BUILDABLE_TYPES" in config_node, "Config must declare BUILDABLE_TYPES")

	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(panel)
	tree.root.add_child(hero)

	panel.select_target(hero)
	panel._on_build_pressed()

	# One button per buildable type, plus Back.
	var expected: int = config_node.BUILDABLE_TYPES.size() + 1
	assert_eq(panel.button_container.get_child_count(), expected,
		"Build menu shows %d buttons (one per BUILDABLE_TYPES entry plus Back)" % expected)

	# Quarry and Hunting Hut are registered in BuildSystem, so they must be reachable.
	assert_has(config_node.BUILDABLE_TYPES, "quarry", "Quarry is offered in the build menu")
	assert_has(config_node.BUILDABLE_TYPES, "hunting_hut", "Hunting Hut is offered in the build menu")
	for b_type in config_node.BUILDABLE_TYPES:
		assert_has(build_system_script.SCRIPT_PATHS, b_type,
			"Buildable type '%s' must have an entity script registered" % b_type)

# ==============================================================================
# 2. Config-driven presentation sizing
# ==============================================================================

func test_04_config_ui_drives_hud_font_sizes() -> void:
	assert_true("UI" in config_node, "Config must declare a UI section")
	var expected: int = int(config_node.UI.get("hud_font_size", 0))
	assert_gt(expected, 0, "Config.UI.hud_font_size must be set")

	var hud = _spawn_hud()
	await wait_frames(1)

	for lbl in [hud.wood_label, hud.wave_label, hud.core_hp_label, hud.hero_hp_label]:
		assert_not_null(lbl, "HUD label must exist")
		assert_eq(lbl.get_theme_font_size("font_size"), expected,
			"HUD label font size comes from Config.UI.hud_font_size")

func test_05_config_ui_drives_world_label_sizing() -> void:
	assert_not_null(lumber_hut_script, "LumberHut.gd must exist")
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	await wait_frames(1)

	assert_not_null(hut.label_3d, "Building must carry a Label3D")
	assert_eq(hut.label_3d.font_size, int(config_node.UI.get("world_label_font_size", 0)),
		"World label font size comes from Config.UI")
	assert_almost_eq(hut.label_3d.pixel_size, float(config_node.UI.get("world_label_pixel_size", 0.0)),
		0.0001, "World label pixel size comes from Config.UI")
	assert_eq(hut.label_3d.fixed_size, bool(config_node.UI.get("world_label_fixed_size", false)),
		"World label fixed_size comes from Config.UI")

func test_06_option_panel_sizing_from_config() -> void:
	var panel = option_panel_script.new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	await wait_frames(1)

	var expected_size: Vector2 = config_node.UI.get("option_panel_size", Vector2.ZERO)
	assert_eq(panel.custom_minimum_size, expected_size, "Option Panel size comes from Config.UI")
	assert_eq(panel.title_label.get_theme_font_size("font_size"),
		int(config_node.UI.get("panel_title_font_size", 0)),
		"Option Panel title font size comes from Config.UI")

# ==============================================================================
# 3. Machinery harvests real resource nodes
# ==============================================================================

func _make_producer(type_id: String) -> Node:
	var p = producer_building_script.new(type_id)
	_cleanup_nodes.append(p)
	tree.root.add_child(p)
	p.setup(type_id, Vector2i.ZERO)
	p.complete_construction()
	p.position = Vector3.ZERO
	return p

func _make_node(res_type: String, dist: float) -> Node:
	var n = resource_node_script.new(res_type, Vector2i.ZERO)
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = Vector3(dist, 0.0, 0.0)
	return n

func test_07_producer_requires_a_source_in_range() -> void:
	var hut = _make_producer("lumber_hut")
	var before: int = int(game_state_node.resources.get("wood", 0))

	# No tree anywhere: operating but banking nothing.
	hut.tend(40.0)
	hut._process(10.0)
	assert_eq(int(game_state_node.resources.get("wood", 0)), before,
		"A producer with no source in range must not invent resources")
	assert_null(hut.target_source, "No source acquired when none exists")
	assert_true(hut.requires_source("wood"), "Wood is a map resource and must be sourced")

func test_08_producer_draws_down_the_node_it_harvests() -> void:
	var hut = _make_producer("lumber_hut")
	var tree_node = _make_node("wood", 3.0)
	var stock_before: int = tree_node.current_amount
	var wood_before: int = int(game_state_node.resources.get("wood", 0))

	var rate: float = float(config_node.BUILDINGS["lumber_hut"]["produces_per_sec"]["wood"])
	var secs: float = 10.0
	var expected: int = int(rate * secs)
	hut.tend(40.0)
	hut._process(secs)

	var gained: int = int(game_state_node.resources.get("wood", 0)) - wood_before
	assert_eq(gained, expected, "%ds at %s wood/s banks %d wood" % [int(secs), str(rate), expected])
	assert_eq(tree_node.current_amount, stock_before - gained,
		"Every banked unit came out of the tree's remaining amount")
	assert_eq(hut.target_source, tree_node, "Hut locked onto the in-range tree")

func test_09_source_outside_range_is_ignored() -> void:
	var hut = _make_producer("lumber_hut")
	var far: float = hut.harvest_range + 5.0
	var tree_node = _make_node("wood", far)
	var before: int = int(game_state_node.resources.get("wood", 0))

	hut.tend(40.0)
	hut._process(10.0)
	assert_eq(int(game_state_node.resources.get("wood", 0)), before,
		"A tree beyond harvest_range must not be harvested")
	assert_eq(tree_node.current_amount, tree_node.max_capacity, "Out-of-range tree untouched")

func test_10_producer_only_harvests_its_own_resource_type() -> void:
	var hut = _make_producer("lumber_hut")
	var rock = _make_node("stone", 2.0)
	var before: int = int(game_state_node.resources.get("wood", 0))

	hut.tend(40.0)
	hut._process(10.0)
	assert_eq(int(game_state_node.resources.get("wood", 0)), before,
		"A lumber hut must not harvest wood out of a stone outcrop")
	assert_eq(rock.current_amount, rock.max_capacity, "Stone node untouched by a lumber hut")

func test_11_producer_moves_on_when_its_node_is_exhausted() -> void:
	var hut = _make_producer("lumber_hut")
	var near = _make_node("wood", 2.0)
	var spare = _make_node("wood", 5.0)
	var rate: float = float(config_node.BUILDINGS["lumber_hut"]["produces_per_sec"]["wood"])
	# Run long enough to draw more than the 2 units left in the nearer tree,
	# whatever the configured rate happens to be.
	var secs: float = 5.0 / maxf(rate, 0.01)
	var want: int = int(rate * secs)
	assert_gt(want, 2, "This test needs to out-draw the nearer tree")
	# Leave only two units in the nearer tree so it runs dry mid-operation.
	near.harvest(near.current_amount - 2)
	var wood_before: int = int(game_state_node.resources.get("wood", 0))

	hut.tend(secs + 5.0)
	hut._process(secs)

	assert_true(near.is_depleted, "The nearer tree is exhausted")
	assert_eq(int(game_state_node.resources.get("wood", 0)) - wood_before, want,
		"Production continues by switching to the next tree in range")
	assert_eq(spare.current_amount, spare.max_capacity - (want - 2), "Remaining units came from the spare tree")

func test_12_quarry_and_hunting_hut_are_node_backed_producers() -> void:
	for pair in [["quarry", "stone"], ["hunting_hut", "water"]]:
		var type_id: String = pair[0]
		var res_id: String = pair[1]
		var machine = _make_producer(type_id)
		assert_true(machine is ProducerBuilding, "%s is a ProducerBuilding" % type_id)
		assert_gt(machine.harvest_range, 0.0, "%s has a harvest_range from Config" % type_id)
		assert_true(machine.requires_source(res_id), "%s must source %s from the map" % [type_id, res_id])

		var src = _make_node(res_id, 2.0)
		var before: int = int(game_state_node.resources.get(res_id, 0))
		machine.tend(40.0)
		machine._process(20.0)
		assert_gt(int(game_state_node.resources.get(res_id, 0)), before,
			"%s produces %s when a node is in range" % [type_id, res_id])
		assert_lt(src.current_amount, src.max_capacity, "%s drew down its %s node" % [type_id, res_id])

func test_13_status_text_reports_missing_and_active_sources() -> void:
	# The base class reports the generic wording...
	var generic = _make_producer("quarry")
	generic.tend(40.0)
	generic._process(0.1)
	var generic_status: String = generic._get_extra_status_text()
	assert_true(generic_status.contains(TranslationServer.translate("STATUS_NO_SOURCE_IN_RANGE")),
		"ProducerBuilding reports the generic missing-source wording (got '%s')" % generic_status)

	# ...and LumberHut overrides it with tree-specific wording.
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3(40.0, 0.0, 40.0) # far from the quarry's stone search
	hut.tend(40.0)
	hut._process(0.1)
	var no_src: String = hut._get_extra_status_text()
	assert_true(no_src.contains(TranslationServer.translate("STATUS_NO_TREES_IN_RANGE")),
		"LumberHut names the missing-tree condition (got '%s')" % no_src)

	var t = _make_node("wood", 2.0)
	t.position = hut.global_position + Vector3(2.0, 0.0, 0.0)
	hut._process(0.5)
	var with_src: String = hut._get_extra_status_text()
	assert_false(with_src.contains(TranslationServer.translate("STATUS_NO_TREES_IN_RANGE")),
		"Status stops warning once a tree is in range (got '%s')" % with_src)
	assert_true(with_src.contains(TranslationServer.translate("STATUS_CHOPPING_TREE").split(":")[0]),
		"Status switches to the chopping readout (got '%s')" % with_src)

# ==============================================================================
# 4. Stone and Water are visible in the HUD
# ==============================================================================

func test_14_hud_shows_every_live_resource() -> void:
	var hud = _spawn_hud()
	await wait_frames(1)

	assert_not_null(hud.stone_label, "HUD must have a Stone label")
	assert_not_null(hud.water_label, "HUD must have a Water label")

	hud._on_resources_changed({"wood": 7, "stone": 4, "water": 9})
	assert_eq(hud.wood_label.text, tr("HUD_WOOD") % 7, "Wood readout updated")
	assert_eq(hud.stone_label.text, tr("HUD_STONE") % 4, "Stone readout updated")
	assert_eq(hud.water_label.text, tr("HUD_WATER") % 9, "Water readout updated")
	assert_true(hud.stone_label.visible, "Stone readout is visible to the player")
	assert_true(hud.water_label.visible, "Water readout is visible to the player")

# ==============================================================================
# 5. Build preview, coverage rings and the retired phase machine
# ==============================================================================

func test_15_build_preview_ghost_follows_selection() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(main_packed, "Main.tscn must exist")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	assert_null(main.build_preview, "No ghost exists before a building type is selected")

	main.on_build_selected("tower")
	assert_not_null(main.build_preview, "Selecting a type creates the ghost")
	assert_not_null(main.build_preview_mesh, "Ghost has a body the player can see")
	assert_not_null(main.build_preview_ring, "A tower ghost shows its coverage ring")

	main.cancel_building_selection()
	await wait_frames(1)
	assert_true(main.build_preview == null or not is_instance_valid(main.build_preview),
		"Cancelling the selection removes the ghost")

func test_16_preview_ring_size_matches_the_building() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	# A wall has no area of effect, so it gets no ring.
	main.on_build_selected("wall")
	assert_eq(main._preview_range_for("wall"), 0.0, "A wall has no coverage range")
	assert_null(main.build_preview_ring, "A wall ghost draws no ring")

	# A tower's ring is its attack range; a producer's is its harvest range.
	assert_almost_eq(main._preview_range_for("tower"),
		float(config_node.BUILDINGS["tower"]["range"]), 0.001,
		"Tower preview ring uses its Config attack range")
	assert_almost_eq(main._preview_range_for("lumber_hut"),
		float(config_node.BUILDINGS["lumber_hut"]["harvest_range"]), 0.001,
		"Producer preview ring uses its Config harvest range")

func test_17_tower_and_producer_expose_coverage_rings() -> void:
	var tower_script: GDScript = load("res://scripts/entities/Tower.gd")
	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	await wait_frames(1)
	assert_almost_eq(tower._get_display_range(), tower.attack_range, 0.001,
		"Tower reports its attack range as its coverage")
	assert_not_null(tower.range_indicator, "Tower builds a coverage ring")
	assert_false(tower.range_indicator.visible, "Ring is hidden until the tower is selected")
	tower.set_range_visible(true)
	assert_true(tower.range_indicator.visible, "Selecting the tower shows its range")

	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	await wait_frames(1)
	assert_almost_eq(hut._get_display_range(), hut.harvest_range, 0.001,
		"Producer reports its harvest range as its coverage")

	# A wall has no area of effect and therefore no ring at all.
	var wall_script: GDScript = load("res://scripts/entities/Wall.gd")
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	await wait_frames(1)
	assert_eq(wall._get_display_range(), 0.0, "A wall has no coverage range")
	assert_null(wall.range_indicator, "A wall builds no ring")

func test_18_selecting_a_producer_highlights_what_it_covers() -> void:
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3.ZERO
	await wait_frames(1)

	var near_node = _make_node("wood", hut.harvest_range * 0.5)
	var far_node = _make_node("wood", hut.harvest_range + 6.0)
	await wait_frames(1)

	hut.set_range_visible(true)
	assert_true(near_node.is_highlighted, "A node inside the ring is highlighted")
	assert_false(far_node.is_highlighted, "A node outside the ring is not")

	hut.set_range_visible(false)
	assert_false(near_node.is_highlighted, "Deselecting clears the highlight")

func test_19_continuous_mode_retires_the_phase_machine() -> void:
	# v0.2 is one continuous state: the deploy countdown must not run and must
	# never flip the phase into ATTACK, which used to block building mid-raid.
	game_state_node.continuous_mode = true
	game_state_node.current_phase = 0
	var before: float = float(game_state_node.remaining_deploy_time)

	for i in range(10):
		game_state_node._process(30.0) # 300s: far past any deploy_length

	assert_eq(int(game_state_node.current_phase), 0, "Phase stays put in continuous mode")
	assert_almost_eq(float(game_state_node.remaining_deploy_time), before, 0.001,
		"The deploy countdown does not tick in continuous mode")

	# With the flag off, the legacy turn machine still behaves as v0.1 expects.
	game_state_node.continuous_mode = false
	game_state_node.current_phase = 0
	game_state_node._process(1.0)
	assert_lt(float(game_state_node.remaining_deploy_time), before,
		"The legacy countdown still ticks when continuous mode is off")

func test_20_reset_game_clears_continuous_mode() -> void:
	# GameState is an autoload; leaking this flag would silently change the rules
	# for every test (and every restart) that runs afterwards.
	game_state_node.continuous_mode = true
	game_state_node.reset_game()
	assert_false(game_state_node.continuous_mode, "reset_game() restores the default mode")

# ==============================================================================
# 6. Opening balance is playable
# ==============================================================================

func test_21_opening_wallet_affords_a_first_economy_building() -> void:
	# A wallet that cannot cover the cheapest producer leaves the player staring at
	# a disabled build menu on turn one, with nothing to do but hand-harvest.
	var wallet: int = int(config_node.INITIAL_RESOURCES.get("wood", 0))
	var cheapest_producer: int = -1
	var cheapest_name: String = ""
	for b_type in config_node.BUILDABLE_TYPES:
		var data: Dictionary = config_node.BUILDINGS[b_type]
		if not data.has("produces_per_sec"):
			continue
		var c: int = int(data.get("cost", {}).get("wood", 0))
		if cheapest_producer < 0 or c < cheapest_producer:
			cheapest_producer = c
			cheapest_name = b_type

	assert_gt(cheapest_producer, 0, "At least one buildable producer must exist")
	assert_gte(wallet, cheapest_producer,
		"Opening wood (%d) must cover the cheapest producer '%s' (%d)" % [wallet, cheapest_name, cheapest_producer])

func test_22_opening_wallet_does_not_trivially_buy_the_whole_defence() -> void:
	# The flip side: the opening should not hand the player a tower plus an economy,
	# or the first real decision never happens.
	var wallet: int = int(config_node.INITIAL_RESOURCES.get("wood", 0))
	var tower: int = cost_of("tower")
	var hut: int = cost_of("lumber_hut")
	assert_lt(wallet, tower + hut,
		"Opening wood (%d) must force a choice between a tower (%d) and an economy building (%d)" % [wallet, tower, hut])

# ==============================================================================
# 7. Left-click inspects, right-click acts -- and the two never interfere
# ==============================================================================

func _panel_and_hero() -> Array:
	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	tree.root.add_child(panel)
	await wait_frames(1)
	return [panel, hero]

func test_23_panel_rests_on_the_hero() -> void:
	var pair = await _panel_and_hero()
	var panel = pair[0]
	var hero = pair[1]
	panel._process(0.0)
	assert_eq(panel.selected_unit, hero, "With nothing clicked the panel shows the Hero")

func test_24_ordering_the_hero_around_does_not_change_the_panel() -> void:
	# Right-click is a command, not an inspection. Sending the Hero to work on
	# something must leave the panel exactly where the player left it.
	var pair = await _panel_and_hero()
	var panel = pair[0]
	var hero = pair[1]
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3(2.0, 0.0, 0.0)
	await wait_frames(1)

	assert_eq(panel.selected_unit, hero, "Resting on the Hero")
	hero.order_tend(hut)
	panel._process(0.0)
	assert_eq(panel.selected_unit, hero, "Giving an order does not pull the panel onto the target")

	hero.order_stop()
	panel._process(0.0)
	assert_eq(panel.selected_unit, hero, "Still on the Hero once the job ends")

func test_25_left_click_is_what_changes_the_panel() -> void:
	var pair = await _panel_and_hero()
	var panel = pair[0]
	var hero = pair[1]
	var tower_script: GDScript = load("res://scripts/entities/Tower.gd")
	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	await wait_frames(1)

	panel._on_unit_selected(tower)
	assert_eq(panel.selected_unit, tower, "Left-clicking a turret shows the turret")

	# And it stays there: nothing the Hero does pulls it away.
	panel._process(0.0)
	assert_eq(panel.selected_unit, tower, "The panel stays on what the player clicked")

	panel._on_unit_selected(hero)
	assert_eq(panel.selected_unit, hero, "Left-clicking the Hero shows the Hero")

func test_26_clicking_empty_ground_returns_to_the_hero() -> void:
	var pair = await _panel_and_hero()
	var panel = pair[0]
	var hero = pair[1]
	var tower_script: GDScript = load("res://scripts/entities/Tower.gd")
	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	await wait_frames(1)

	panel._on_unit_selected(tower)
	panel._on_unit_deselected()
	assert_eq(panel.selected_unit, hero, "Deselecting falls back to the Hero")

func test_27_a_selected_unit_that_disappears_falls_back_to_the_hero() -> void:
	var pair = await _panel_and_hero()
	var panel = pair[0]
	var hero = pair[1]
	var wall_script: GDScript = load("res://scripts/entities/Wall.gd")
	var wall = wall_script.new()
	tree.root.add_child(wall)
	wall.complete_construction()
	await wait_frames(1)

	panel._on_unit_selected(wall)
	assert_eq(panel.selected_unit, wall, "Showing the wall")

	wall.queue_free()
	await wait_frames(2)
	panel._process(0.0)
	assert_eq(panel.selected_unit, hero, "Panel falls back to the Hero")

# ==============================================================================
# 8. Build time derives from price; stakes queue up in a row
# ==============================================================================

func test_28_build_time_is_a_function_of_price() -> void:
	# Cost is the single number a designer tunes; time follows from it.
	assert_true(config_node.has_method("get_build_time"), "Config exposes get_build_time()")

	# The invariant is that time tracks price, not that any two particular buildings
	# sit in a given order -- prices move with every balance pass.
	assert_lt(config_node.get_build_time("wall"), config_node.get_build_time("lumber_hut"),
		"Cheap stakes go up faster than a lumber hut")
	for a in config_node.BUILDABLE_TYPES:
		for b in config_node.BUILDABLE_TYPES:
			if cost_of(String(a)) < cost_of(String(b)):
				assert_lte(config_node.get_build_time(String(a)), config_node.get_build_time(String(b)),
					"%s is cheaper than %s, so it may not take longer" % [a, b])

	# The relationship is the stated formula, not an accident of hand-tuning.
	var per: float = float(config_node.BUILD_SECONDS_PER_RESOURCE)
	var floor_t: float = float(config_node.BUILD_TIME_MIN)
	for b_type in config_node.BUILDABLE_TYPES:
		var cost_sum: float = 0.0
		for res_id in config_node.BUILDINGS[b_type].get("cost", {}):
			cost_sum += float(config_node.BUILDINGS[b_type]["cost"][res_id])
		assert_almost_eq(config_node.get_build_time(b_type), maxf(floor_t, cost_sum * per), 0.001,
			"%s build time follows the price formula" % b_type)

	# No building may restate a build_time of its own, or the two can drift apart.
	for b_type in config_node.BUILDINGS:
		assert_false(config_node.BUILDINGS[b_type].has("build_time"),
			"%s must not hardcode build_time; it is derived from cost" % b_type)

func test_29_a_building_takes_its_derived_build_time() -> void:
	var wall_script: GDScript = load("res://scripts/entities/Wall.gd")
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	await wait_frames(1)
	assert_almost_eq(wall.build_time, config_node.get_build_time("wall"), 0.001,
		"A placed building uses the derived time, not a per-building field")

func test_30_stakes_are_cheap_enough_to_lay_a_row() -> void:
	# The point of one-wood stakes is that a whole fence is affordable in one go.
	var stake: int = cost_of("wall")
	assert_eq(stake, 1, "A wooden stake costs one wood")
	var wallet: int = int(config_node.INITIAL_RESOURCES.get("wood", 0))
	assert_gte(wallet / stake, 10, "The opening wallet affords at least ten stakes")

func test_31_placement_mode_survives_until_the_next_one_is_unaffordable() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	var stake: int = cost_of("wall")
	game_state_node.resources["wood"] = stake * 3
	main.on_build_selected("wall")
	assert_not_null(main.build_preview, "The ghost is up while laying stakes")

	# Three clicks in a row leave three blueprints and never drop the build mode.
	var placed: Array[Node] = []
	for i in range(3):
		var b = main.try_place_at_cell(Vector2i(6 + i, 6))
		assert_not_null(b, "Stake %d placed" % (i + 1))
		placed.append(b)
		if i < 2:
			assert_eq(main.current_build_type, "wall", "Build mode survives placement %d" % (i + 1))

	# The wallet is empty now, so the mode drops on its own.
	assert_eq(main.current_build_type, "", "Build mode ends when the next stake is unaffordable")
	assert_true(main.build_preview == null or not is_instance_valid(main.build_preview),
		"The ghost goes away with the build mode")

	# Every stake is a blueprint waiting for the Hero, not a finished wall.
	for b in placed:
		assert_false(b.is_constructed, "Each stake is left as a blueprint for the Hero to raise")

# ==============================================================================
# 9. Right-click obeys the selection; ESC menu
# ==============================================================================

func test_32_right_click_commands_the_hero_whatever_is_on_screen() -> void:
	# A single avatar means right-click is always his order. Inspecting a turret
	# must never cost the player the ability to move him -- that is what stranded
	# the Hero when a tree was selected.
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	var panel = main._get_option_panel()
	assert_not_null(panel, "Main can find the Option Panel")
	assert_false(main.has_method("_is_hero_selected"),
		"The selection no longer gates whether the Hero takes orders")

	# Whatever the panel happens to be showing, ordering him still works.
	var tower_script: GDScript = load("res://scripts/entities/Tower.gd")
	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	await wait_frames(1)
	panel._on_unit_selected(tower)

	var dest := Vector3(6.0, 0.0, 6.0)
	main.hero.move_to(dest)
	assert_ne(int(main.hero.current_state), int(hero_script.State.IDLE),
		"The Hero accepts a move order while a turret is being inspected")
	assert_eq(panel.selected_unit, tower, "And the order did not disturb the panel")

func test_33_pause_menu_opens_pauses_and_restores() -> void:
	var hud = _spawn_hud()
	await wait_frames(1)
	assert_not_null(hud.pause_menu, "HUD hosts a pause menu")
	var menu = hud.pause_menu

	assert_false(menu.is_open, "Menu starts closed")
	assert_false(menu.visible, "Menu starts hidden")

	game_state_node.continuous_mode = true
	game_state_node.set_paused(false)
	hud.toggle_pause_menu()
	assert_true(menu.is_open, "ESC opens the menu")
	assert_true(bool(game_state_node.is_paused), "Opening the menu pauses the world behind it")

	hud.toggle_pause_menu()
	assert_false(menu.is_open, "ESC closes it again")
	assert_false(bool(game_state_node.is_paused), "Closing lifts the pause the menu applied")

func test_34_menu_does_not_unpause_a_game_the_player_paused() -> void:
	var hud = _spawn_hud()
	await wait_frames(1)
	var menu = hud.pause_menu

	game_state_node.continuous_mode = true
	game_state_node.set_paused(true) # the player paused it themselves
	menu.open()
	menu.close()
	assert_true(bool(game_state_node.is_paused), "Closing the menu leaves the player's own pause intact")
	game_state_node.set_paused(false)

func test_35_menu_has_three_entries_and_a_language_picker() -> void:
	var hud = _spawn_hud()
	await wait_frames(1)
	var menu = hud.pause_menu

	menu.open()
	for btn in [menu.resume_btn, menu.settings_btn, menu.quit_btn]:
		assert_not_null(btn, "Root menu entry exists")
		assert_true(btn.visible, "Root menu entry is shown: %s" % btn.name)
	assert_false(menu.language_row.visible, "Language lives on the settings page, not the root menu")

	menu.open_settings()
	assert_true(menu.language_row.visible, "Settings shows the language picker")
	assert_true(menu.back_btn.visible, "Settings offers a way back")
	assert_false(menu.resume_btn.visible, "Root entries are hidden on the settings page")
	assert_gte(menu.language_picker.item_count, 2, "Both supported locales are offered")

	menu.back_to_root()
	assert_true(menu.resume_btn.visible, "Back returns to the root menu")
	menu.close()

func test_36_language_picker_switches_locale() -> void:
	var hud = _spawn_hud()
	await wait_frames(1)
	var menu = hud.pause_menu
	var i18n = tree.root.get_node_or_null("I18n")
	assert_not_null(i18n, "I18n autoload exists")
	var before: String = i18n.get_current_locale()

	menu.open()
	menu.open_settings()
	# Pick whichever entry is not the current locale.
	for i in range(menu.language_picker.item_count):
		if String(menu.language_picker.get_item_metadata(i)) != before:
			menu._on_language_selected(i)
			break
	assert_ne(i18n.get_current_locale(), before, "Choosing a language switches the locale")

	i18n.set_locale(before)
	menu.close()

# ==============================================================================
# 10. Build menu reads at a glance
# ==============================================================================

func _build_menu() -> Array:
	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	tree.root.add_child(panel)
	await wait_frames(1)
	panel.select_target(hero)
	panel._on_build_pressed()
	return [panel, hero]

func test_37_unaffordable_entries_are_disabled_not_just_labelled() -> void:
	# Affordability should be visible without comparing numbers on every button.
	game_state_node.resources["wood"] = cost_of("wall") # enough for a stake, nothing else
	var pair = await _build_menu()
	var panel = pair[0]

	var seen: Dictionary = {}
	var idx: int = 0
	for b_type in config_node.BUILDABLE_TYPES:
		var btn = panel.button_container.get_child(idx)
		seen[b_type] = btn
		idx += 1

	assert_false(seen["wall"].disabled, "A stake is affordable, so its entry is live")
	assert_true(seen["tower"].disabled, "A turret is out of reach, so its entry is greyed out")

	# Paying for it lights the entry back up.
	game_state_node.resources["wood"] = cost_of("tower")
	panel._refresh_ui()
	assert_false(panel.button_container.get_child(1).disabled, "The turret entry lights up once affordable")

func test_38_detail_line_reports_cost_and_build_time() -> void:
	game_state_node.resources["wood"] = 999
	var pair = await _build_menu()
	var panel = pair[0]

	# Nothing hovered: the line prompts instead of showing a stale unit status.
	assert_eq(panel.status_label.text, tr("BUILD_HINT_PICK"), "The build page prompts when nothing is hovered")

	panel._show_build_detail("tower")
	var detail: String = str(panel.status_label.text)
	assert_true(detail.contains(str(cost_of("tower"))), "Detail names the cost (got '%s')" % detail)
	var secs: String = "%.1f" % config_node.get_build_time("tower")
	assert_true(detail.contains(secs) or detail.contains(secs.replace(".", ",")),
		"Detail names the derived build time (got '%s')" % detail)

func test_39_detail_line_says_what_is_missing_when_broke() -> void:
	var short_by: int = maxi(0, cost_of("tower") - 1)
	game_state_node.resources["wood"] = short_by
	var pair = await _build_menu()
	var panel = pair[0]

	panel._show_build_detail("tower")
	var detail: String = str(panel.status_label.text)
	assert_true(detail.contains(str(cost_of("tower"))), "Says what the turret costs")
	assert_true(detail.contains(str(short_by)), "Says what the player actually has")
	assert_gt(panel.status_label.modulate.r, panel.status_label.modulate.g,
		"The shortfall is tinted red rather than left for the player to notice")

func test_40_unit_status_does_not_overwrite_the_build_detail() -> void:
	game_state_node.resources["wood"] = 999
	var pair = await _build_menu()
	var panel = pair[0]

	panel._show_build_detail("lumber_hut")
	var detail: String = str(panel.status_label.text)
	# The per-unit status ticker must leave the build page's line alone.
	panel._update_status_display()
	assert_eq(str(panel.status_label.text), detail, "Build detail survives the status refresh")

# ==============================================================================
# 11. Blueprint order and menu placement
# ==============================================================================

func test_41_blueprints_are_built_in_the_order_they_were_placed() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	game_state_node.resources["wood"] = cost_of("wall") * 5
	main.on_build_selected("wall")

	# Lay stakes walking away from the Hero, so "nearest" and "first" disagree:
	# the far one is clicked first and must still be raised first.
	var far = main.try_place_at_cell(Vector2i(8, 8))
	var mid = main.try_place_at_cell(Vector2i(4, 4))
	var near = main.try_place_at_cell(Vector2i(2, 2))
	assert_not_null(far, "First stake placed")
	assert_not_null(mid, "Second stake placed")
	assert_not_null(near, "Third stake placed")

	assert_lt(far.build_order, mid.build_order, "Stakes are stamped in click order")
	assert_lt(mid.build_order, near.build_order, "Stakes are stamped in click order")

	main.hero.global_position = near.global_position
	var next_up = main.hero._find_nearest_unfinished_building()
	assert_eq(next_up, far, "The Hero starts with the stake clicked first, not the closest one")

func test_42_pause_menu_is_centred_not_cornered() -> void:
	var hud = _spawn_hud()
	await wait_frames(1)
	var menu = hud.pause_menu
	menu.open()
	await wait_frames(2)

	# Measure where it actually lands. The structural check (panel inside a
	# CenterContainer) passed while the menu still sat in the corner, because the
	# menu itself was 0x0: set_anchors_preset() recomputes offsets to PRESERVE the
	# current rect, so a control that starts empty stays empty.
	var view: Vector2 = menu.get_viewport_rect().size
	assert_gt(menu.size.x, 0.0, "The menu Control fills its parent rather than collapsing to 0x0")
	assert_almost_eq(menu.size.x, view.x, 1.0, "Menu spans the viewport width")
	assert_almost_eq(menu.size.y, view.y, 1.0, "Menu spans the viewport height")

	var centre: Vector2 = menu.panel.global_position + menu.panel.size * 0.5
	assert_almost_eq(centre.x, view.x * 0.5, 2.0, "Panel is horizontally centred")
	assert_almost_eq(centre.y, view.y * 0.5, 2.0, "Panel is vertically centred")
	assert_not_null(menu.find_child("Dimmer", true, false),
		"A dimmed backdrop makes the menu read as a modal layer")
	menu.close()

# ==============================================================================
# 12. Trapping, scenery selection, and the walking-Hero retarget bug
# ==============================================================================

func test_43_ordinary_buildings_leave_a_lane_wider_than_the_hero() -> void:
	# Workshops must never be able to box the Hero in by accident, so two of them
	# on neighbouring tiles always leave a gap he fits through.
	var tile: float = float(config_node.TILE_SIZE)
	var hero_w: float = float(config_node.HERO.get("width", 0.8))
	var default_fp: float = float(config_node.get_default_building_footprint())

	assert_gt(tile - default_fp, hero_w, "The default footprint leaves the Hero a lane")
	assert_almost_eq((tile - default_fp) - hero_w, float(config_node.BUILDING_CLEARANCE), 0.001,
		"The slack is exactly the configured clearance")

	for b_type in ["tower", "lumber_hut", "quarry", "hunting_hut"]:
		assert_false(config_node.is_barrier_building(b_type),
			"%s is a workshop, not a barrier" % b_type)
		assert_gt(tile - config_node.get_building_footprint(b_type), hero_w,
			"Two %s side by side still leave a lane" % b_type)

	# And the entity uses its own type's number rather than restating a size.
	var tower_script: GDScript = load("res://scripts/entities/Tower.gd")
	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	await wait_frames(1)
	var shape: CollisionShape3D = null
	for child in tower.get_children():
		if child is CollisionShape3D:
			shape = child
			break
	assert_not_null(shape, "A building has a collision shape")
	assert_almost_eq(shape.shape.size.x, config_node.get_building_footprint("tower"), 0.001,
		"Its footprint comes from its own Config entry")

func test_43b_stakes_are_a_barrier_that_actually_closes() -> void:
	# A fence only reads as a fence, and only stops anything, if neighbouring
	# stakes close up instead of leaving a Hero-sized hole between them.
	var tile: float = float(config_node.TILE_SIZE)
	var hero_w: float = float(config_node.HERO.get("width", 0.8))
	var fp: float = float(config_node.get_building_footprint("wall"))

	assert_true(config_node.is_barrier_building("wall"), "Stakes are a barrier")
	assert_lt(tile - fp, hero_w, "Two neighbouring stakes leave no lane for the Hero")
	assert_lte(fp, tile, "A stake still fits inside its own tile")

	var wall_script: GDScript = load("res://scripts/entities/Wall.gd")
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	await wait_frames(1)
	var shape: CollisionShape3D = null
	for child in wall.get_children():
		if child is CollisionShape3D:
			shape = child
			break
	assert_almost_eq(shape.shape.size.x, fp, 0.001, "The stake is built at its barrier footprint")

func test_43c_being_fenced_in_is_undone_by_demolishing() -> void:
	# Barriers can seal the Hero in, which is the point; the way out is to pull one
	# down. Demolishing must free the tile so he can walk through it.
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)
	game_state_node.resources["wood"] = 999

	var centre := Vector2i(6, 6)
	main.hero.global_position = main.grid_manager.cell_to_world(centre)
	main.on_build_selected("wall")

	var ring: Array[Node] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var b = main.try_place_at_cell(centre + Vector2i(dx, dy))
			if b != null:
				b.complete_construction()
				ring.append(b)
	assert_eq(ring.size(), 8, "The Hero is ringed by eight stakes")

	for b in ring:
		assert_true(main.grid_manager.is_cell_occupied(b.cell_pos), "Every ring tile is occupied")

	# Pull one down and that tile opens up again.
	var door = ring[0]
	var door_cell: Vector2i = door.cell_pos
	door.demolish()
	# Read the flag before the node is actually freed a frame later.
	assert_true(door.is_destroyed, "The stake comes down")
	await wait_frames(2)
	assert_false(main.grid_manager.is_cell_occupied(door_cell),
		"Demolishing frees the tile, so the Hero has a way out")

func test_44_inspecting_a_tree_does_not_strand_the_hero() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)
	var panel = main._get_option_panel()

	var node = resource_node_script.new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	node.position = Vector3(3.0, 0.0, 0.0)
	await wait_frames(1)

	# Left-click the tree to read it...
	panel._on_unit_selected(node)
	assert_eq(panel.selected_unit, node, "Left-click shows the tree's status")

	# ...and the Hero is still perfectly commandable.
	main.hero.order_harvest(node)
	assert_ne(int(main.hero.current_state), int(hero_script.State.IDLE),
		"The Hero still takes orders while a tree is being inspected")

func test_45_trees_offer_no_redundant_harvest_button() -> void:
	var panel = option_panel_script.new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	var node = resource_node_script.new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	await wait_frames(1)

	panel._on_unit_selected(node)
	assert_eq(panel.button_container.get_child_count(), 0,
		"A tree carries no command buttons; right-click already harvests it")

func test_46_a_new_click_does_not_steal_a_hero_already_walking_to_a_blueprint() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	game_state_node.resources["wood"] = cost_of("wall") * 4
	main.on_build_selected("wall")

	var first = main.try_place_at_cell(Vector2i(9, 9))
	assert_not_null(first, "First stake placed")
	# He is walking to it, not yet building it -- the state the old guard missed.
	assert_eq(int(main.hero.current_state), int(hero_script.State.MOVING), "Hero sets off towards it")

	var second = main.try_place_at_cell(Vector2i(3, 3))
	assert_not_null(second, "Second stake placed")
	assert_eq(main.hero.target_building, first,
		"A stake clicked while he is still walking must not steal him from the first")

# ==============================================================================
# 13. A new order fully replaces the previous one
# ==============================================================================

func _hero_in_world() -> Array:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)
	game_state_node.resources["wood"] = 999
	return [main, main.hero]

func test_47_every_order_clears_the_previous_one() -> void:
	# The Hero tracks four possible targets. Five order functions used to re-list
	# them by hand and move_to() only cleared two, so a half-finished tend or
	# harvest quietly dragged him back and he looked unresponsive.
	var pair = await _hero_in_world()
	var main = pair[0]
	var hero = pair[1]

	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3(4.0, 0.0, 2.0)
	var node = resource_node_script.new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	node.position = Vector3(-4.0, 0.0, 2.0)
	await wait_frames(1)

	var targets := ["target_building", "target_enemy", "target_resource_node", "target_tend_building"]

	# Whichever order came before, a move order must leave nothing behind.
	for setup in [func(): hero.order_tend(hut), func(): hero.order_harvest(node)]:
		setup.call()
		hero.move_to(Vector3(-10.0, 0.0, 8.0))
		for t in targets:
			assert_null(hero.get(t), "move_to() clears %s" % t)

	# And the same in the other direction: tending must drop a harvest.
	hero.order_harvest(node)
	hero.order_tend(hut)
	assert_null(hero.target_resource_node, "order_tend() drops an outstanding harvest")
	assert_eq(hero.target_tend_building, hut, "and takes the machine as its target")

func test_48_a_move_order_mid_tend_is_actually_obeyed() -> void:
	var pair = await _hero_in_world()
	var main = pair[0]
	var hero = pair[1]

	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3(4.0, 0.0, 2.0)
	await wait_frames(1)

	hero.order_tend(hut)
	for i in range(120):
		hero._physics_process(1.0 / 60.0)

	var dest := Vector3(-14.0, 0.0, 6.0)
	hero.move_to(dest)
	for i in range(600):
		hero._physics_process(1.0 / 60.0)

	var to_dest: float = hero.global_position.distance_to(dest)
	var to_hut: float = hero.global_position.distance_to(hut.global_position)
	assert_lt(to_dest, to_hut, "He walks where he was sent, not back to the machine")
	assert_lt(to_dest, 2.0, "And he actually arrives")

# ==============================================================================
# 14. Standardized Interaction-Aware Highlight & Stop Button Removal
# ==============================================================================

func test_49_hero_level_1_menu_only_has_build_button() -> void:
	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(panel)
	tree.root.add_child(hero)
	await wait_frames(1)

	panel.select_target(hero)
	assert_eq(panel.current_menu, "default", "Starts at default level-1 menu")
	# Level 1 menu now offers only [ Build ], Stop button is removed as redundant
	assert_eq(panel.button_container.get_child_count(), 1, "Level 1 menu has exactly 1 button")
	var btn = panel.button_container.get_child(0)
	assert_eq(btn.text, tr("CMD_BUILD"), "The single button is Build")

func test_50_lumber_hut_only_highlights_wood_nodes() -> void:
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3.ZERO
	await wait_frames(1)

	var near_tree = _make_node("wood", hut.harvest_range * 0.5)
	var near_rock = _make_node("stone", hut.harvest_range * 0.5)
	var near_water = _make_node("water", hut.harvest_range * 0.5)
	await wait_frames(1)

	hut.set_range_visible(true)
	assert_true(near_tree.is_highlighted, "A tree inside lumber hut ring is highlighted")
	assert_false(near_rock.is_highlighted, "A rock inside lumber hut ring is NOT highlighted")
	assert_false(near_water.is_highlighted, "Water inside lumber hut ring is NOT highlighted")

	hut.set_range_visible(false)
	assert_false(near_tree.is_highlighted, "Deselecting unhighlights the tree")

func test_51_quarry_only_highlights_stone_nodes() -> void:
	var quarry_script: GDScript = load("res://scripts/entities/ProducerBuilding.gd")
	var quarry = quarry_script.new("quarry")
	_cleanup_nodes.append(quarry)
	tree.root.add_child(quarry)
	quarry.complete_construction()
	quarry.position = Vector3.ZERO
	await wait_frames(1)

	var near_tree = _make_node("wood", quarry.harvest_range * 0.5)
	var near_rock = _make_node("stone", quarry.harvest_range * 0.5)
	await wait_frames(1)

	quarry.set_range_visible(true)
	assert_false(near_tree.is_highlighted, "A tree inside quarry ring is NOT highlighted")
	assert_true(near_rock.is_highlighted, "A rock inside quarry ring IS highlighted")

	quarry.set_range_visible(false)
	assert_false(near_rock.is_highlighted, "Deselecting unhighlights the rock")

func test_52_tower_highlights_no_resource_nodes() -> void:
	var tower_script: GDScript = load("res://scripts/entities/Tower.gd")
	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	tower.complete_construction()
	tower.position = Vector3.ZERO
	await wait_frames(1)

	var near_tree = _make_node("wood", tower.attack_range * 0.5)
	var near_rock = _make_node("stone", tower.attack_range * 0.5)
	await wait_frames(1)

	tower.set_range_visible(true)
	assert_false(near_tree.is_highlighted, "Tower range does not highlight trees")
	assert_false(near_rock.is_highlighted, "Tower range does not highlight rocks")

func test_53_build_preview_only_highlights_relevant_resource_type() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)

	var tree_node = _make_node("wood", 3.0)
	var rock_node = _make_node("stone", 3.0)
	await wait_frames(1)

	# Selecting lumber hut preview: only tree lights up
	main.on_build_selected("lumber_hut")
	main.build_preview.global_position = Vector3.ZERO
	main._refresh_preview_highlights()
	assert_true(tree_node.is_highlighted, "Lumber hut preview highlights nearby tree")
	assert_false(rock_node.is_highlighted, "Lumber hut preview ignores nearby rock")

	# Cancelling clears preview highlights
	main.cancel_building_selection()
	assert_false(tree_node.is_highlighted, "Cancelling preview clears highlight")

	# Selecting tower preview: neither lights up
	main.on_build_selected("tower")
	main.build_preview.global_position = Vector3.ZERO
	main._refresh_preview_highlights()
	assert_false(tree_node.is_highlighted, "Tower preview does not highlight tree")
	assert_false(rock_node.is_highlighted, "Tower preview does not highlight rock")
	main.cancel_building_selection()

func test_54_depleted_resource_nodes_are_not_highlighted() -> void:
	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3.ZERO
	await wait_frames(1)

	var depleted_tree = _make_node("wood", hut.harvest_range * 0.5)
	depleted_tree.current_amount = 0
	depleted_tree.is_depleted = true
	await wait_frames(1)

	hut.set_range_visible(true)
	assert_false(depleted_tree.is_highlighted, "A depleted tree has no effect and is not highlighted")

func test_55_reselecting_a_building_still_highlights_a_shared_node() -> void:
	# Two huts whose ranges overlap the same tree. `unit_selected` fans out to every
	# building in an arbitrary order, so with one highlight list per building the
	# newly selected hut lit the tree and the previously selected one then cleared
	# its stale list and switched it straight back off.
	var a = lumber_hut_script.new()
	var b = lumber_hut_script.new()
	_cleanup_nodes.append(a)
	_cleanup_nodes.append(b)
	tree.root.add_child(a)
	tree.root.add_child(b)
	a.complete_construction()
	b.complete_construction()
	a.position = Vector3(-3.0, 0.0, 0.0)
	b.position = Vector3(3.0, 0.0, 0.0)

	var shared = resource_node_script.new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(shared)
	tree.root.add_child(shared)
	shared.position = Vector3.ZERO
	await wait_frames(1)

	for step in [a, b, a, b]:
		event_bus_node.unit_selected.emit(step)
		assert_true(shared.is_highlighted,
			"The shared tree stays lit for whichever hut is selected, in any order")

	event_bus_node.unit_deselected.emit()
	assert_false(shared.is_highlighted, "Deselecting clears it")

func test_56_highlights_survive_a_selected_building_being_destroyed() -> void:
	var hut = lumber_hut_script.new()
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = Vector3.ZERO
	var t = resource_node_script.new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(t)
	tree.root.add_child(t)
	t.position = Vector3(2.0, 0.0, 0.0)
	await wait_frames(1)

	event_bus_node.unit_selected.emit(hut)
	assert_true(t.is_highlighted, "Tree lit while the hut is selected")

	hut.queue_free()
	await wait_frames(2)
	assert_false(t.is_highlighted, "A destroyed building does not leave its highlights behind")

func test_57_a_producer_without_an_explicit_declaration_still_derives_its_types() -> void:
	# Config.get_interactable_resource_types() falls back to deriving from what a
	# producer makes. Every shipped producer declares the field, so exercise the
	# fallback directly rather than leaving it as untested, unreachable code.
	assert_true(config_node.has_method("get_interactable_resource_types"),
		"Config owns the rule for what a building type interacts with")

	# Declared types win.
	assert_eq(config_node.get_interactable_resource_types("lumber_hut"), ["wood"] as Array[String],
		"A lumber hut interacts with wood")
	assert_eq(config_node.get_interactable_resource_types("quarry"), ["stone"] as Array[String],
		"A quarry interacts with stone")

	# Things with no resource interaction say so plainly.
	assert_true(config_node.get_interactable_resource_types("tower").is_empty(),
		"A turret interacts with no resource node")
	assert_true(config_node.get_interactable_resource_types("wall").is_empty(),
		"Stakes interact with no resource node")
	assert_true(config_node.get_interactable_resource_types("not_a_building").is_empty(),
		"An unknown type is handled rather than crashing")

func test_58_depleted_nodes_report_themselves_unavailable() -> void:
	# One place answers "is this worth harvesting / highlighting", so the building,
	# the build preview and the producer cannot drift apart on the question.
	var node = resource_node_script.new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	await wait_frames(1)

	assert_true(node.is_available(), "A fresh tree is available")
	node.harvest(node.current_amount)
	assert_true(node.is_depleted, "Stripping it marks it depleted")
	assert_false(node.is_available(), "And it reports itself unavailable")

	var hut = lumber_hut_script.new()
	_cleanup_nodes.append(hut)
	tree.root.add_child(hut)
	hut.complete_construction()
	hut.position = node.global_position
	await wait_frames(1)
	assert_false(hut.can_interact_with(node), "A hut will not claim a stripped tree")
