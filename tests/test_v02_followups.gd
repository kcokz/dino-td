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
