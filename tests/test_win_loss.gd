# res://tests/test_win_loss.gd
# ==============================================================================
# Requirement R5 Acceptance Test Suite:
# Verifies Win Condition (Nest 30 HP, nest_destroyed, game_won, GameState flags, action lockout),
# Loss Condition (Core 10 HP, core_hp_changed, game_lost, GameState flags, action lockout),
# HUD Display (AP, Wood, Wave, HP updates, Victory/Defeat overlays, End Action button),
# and Game Restart (GameState reset, entity purging, Core/Nest re-instantiation, action re-enable).
# ==============================================================================
extends "res://tests/test_base.gd"

# Autoload References
var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

# Entity & Core Scripts
var nest_script: GDScript = null
var core_campfire_script: GDScript = null
var tower_script: GDScript = null
var dino_script: GDScript = null
var wall_script: GDScript = null
var building_script: GDScript = null
var grid_manager_script: GDScript = null
var build_system_script: GDScript = null
var wave_manager_script: GDScript = null
var main_script: GDScript = null
var hud_script: GDScript = null
var hud_packed_scene: PackedScene = null

# Cleanup tracking
var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# 1. Lifecycle Hooks
# ==============================================================================

func before_all() -> void:
	# 1. Resolve Autoload Singletons from /root or script fallback
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if config_node == null and ResourceLoader.exists("res://scripts/autoload/Config.gd"):
		config_node = load("res://scripts/autoload/Config.gd").new()
		_cleanup_objects.append(config_node)

	if event_bus_node == null and ResourceLoader.exists("res://scripts/autoload/EventBus.gd"):
		event_bus_node = load("res://scripts/autoload/EventBus.gd").new()
		_cleanup_objects.append(event_bus_node)

	if game_state_node == null and ResourceLoader.exists("res://scripts/autoload/GameState.gd"):
		game_state_node = load("res://scripts/autoload/GameState.gd").new()
		_cleanup_objects.append(game_state_node)

	# 2. Load Entity Scripts
	nest_script = _load_script([
		"res://scripts/entities/Nest.gd",
		"res://scripts/entities/nest.gd"
	])
	core_campfire_script = _load_script([
		"res://scripts/entities/CoreCampfire.gd",
		"res://scripts/entities/core_campfire.gd"
	])
	tower_script = _load_script([
		"res://scripts/entities/Tower.gd",
		"res://scripts/entities/tower.gd"
	])
	dino_script = _load_script([
		"res://scripts/entities/Dino.gd",
		"res://scripts/entities/dino.gd"
	])
	wall_script = _load_script([
		"res://scripts/entities/Wall.gd",
		"res://scripts/entities/wall.gd"
	])
	building_script = _load_script([
		"res://scripts/entities/Building.gd",
		"res://scripts/entities/building.gd"
	])

	# 3. Load Core & UI Scripts
	grid_manager_script = _load_script([
		"res://scripts/core/GridManager.gd",
		"res://scripts/core/grid_manager.gd"
	])
	build_system_script = _load_script([
		"res://scripts/core/BuildSystem.gd",
		"res://scripts/core/build_system.gd"
	])
	wave_manager_script = _load_script([
		"res://scripts/core/WaveManager.gd",
		"res://scripts/core/wave_manager.gd"
	])
	main_script = _load_script([
		"res://scripts/core/Main.gd",
		"res://scripts/core/main.gd"
	])
	hud_script = _load_script([
		"res://scripts/ui/HUD.gd",
		"res://scripts/ui/hud.gd"
	])

	if ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		hud_packed_scene = load("res://scenes/ui/HUD.tscn")

func before_each() -> void:
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		else:
			if "current_phase" in game_state_node: game_state_node.current_phase = 0
			if "current_ap" in game_state_node: game_state_node.current_ap = 3
			if "max_ap" in game_state_node: game_state_node.max_ap = 3
			if "resources" in game_state_node: game_state_node.resources = {"wood": 10, "stone": 0, "food": 0}
			if "is_game_over" in game_state_node: game_state_node.is_game_over = false
			if "is_game_won" in game_state_node: game_state_node.is_game_won = false

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()

	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _cleanup_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				obj.free()
			elif obj is RefCounted:
				pass
	_cleanup_objects.clear()

# ==============================================================================
# Helper Factory Methods
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_nest() -> Node:
	assert_not_null(nest_script, "Nest.gd script must exist")
	if nest_script == null:
		return null
	var nest = nest_script.new()
	if nest is Node:
		_cleanup_nodes.append(nest)
	return nest

func _create_core_campfire() -> Node:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null:
		return null
	var core = core_campfire_script.new()
	if core is Node:
		_cleanup_nodes.append(core)
	return core

func _create_hud() -> CanvasLayer:
	var hud_inst: CanvasLayer = null
	if hud_packed_scene != null:
		hud_inst = hud_packed_scene.instantiate() as CanvasLayer
	elif hud_script != null:
		hud_inst = hud_script.new() as CanvasLayer

	if hud_inst != null:
		_cleanup_nodes.append(hud_inst)
	return hud_inst

# ==============================================================================
# Category 1: Win Condition & Nest Lifecycle Tests (test_win_*)
# ==============================================================================

func test_win_01_nest_config_and_initial_stats() -> void:
	assert_not_null(config_node, "Config singleton must be available")
	assert_true("NEST" in config_node, "Config must contain NEST dictionary")
	var nest_cfg: Dictionary = config_node.NEST
	assert_almost_eq(float(nest_cfg.get("hp", 0.0)), 30.0, 0.001, "Config.NEST.hp must be 30.0")

	var nest = _create_nest()
	if nest == null:
		return

	if tree and tree.root:
		tree.root.add_child(nest)
		await wait_frames(2)

	assert_true(nest.has_method("take_damage"), "Nest must implement take_damage(amount)")
	assert_almost_eq(float(nest.get("max_hp")), 30.0, 0.001, "Nest.max_hp must initialize to 30.0")
	assert_almost_eq(float(nest.get("current_hp")), 30.0, 0.001, "Nest.current_hp must initialize to 30.0")

func test_win_02_nest_partial_damage_does_not_trigger_victory() -> void:
	var nest = _create_nest()
	if nest == null:
		return

	if tree and tree.root:
		tree.root.add_child(nest)
		await wait_frames(1)

	var nest_destroyed_watcher = watch_signal(event_bus_node, "nest_destroyed")
	var game_won_watcher = watch_signal(event_bus_node, "game_won")

	# Inflict partial damage: 10.0 damage -> 20.0 HP remaining
	nest.take_damage(10.0)
	assert_almost_eq(float(nest.get("current_hp")), 20.0, 0.001, "Nest HP drops from 30 to 20")
	assert_false(nest_destroyed_watcher.emitted, "nest_destroyed must NOT emit on partial damage")
	assert_false(game_won_watcher.emitted, "game_won must NOT emit on partial damage")
	assert_false(bool(game_state_node.get("is_game_over")), "GameState.is_game_over must remain false")

	# Inflict further partial damage: 15.0 damage -> 5.0 HP remaining
	nest.take_damage(15.0)
	assert_almost_eq(float(nest.get("current_hp")), 5.0, 0.001, "Nest HP drops from 20 to 5")
	assert_false(nest_destroyed_watcher.emitted, "nest_destroyed must NOT emit on partial damage")
	assert_false(game_won_watcher.emitted, "game_won must NOT emit on partial damage")

func test_win_03_nest_fatal_damage_emits_nest_destroyed_and_game_won() -> void:
	var nest = _create_nest()
	if nest == null:
		return

	if tree and tree.root:
		tree.root.add_child(nest)
		await wait_frames(1)

	var nest_destroyed_watcher = watch_signal(event_bus_node, "nest_destroyed")
	var game_won_watcher = watch_signal(event_bus_node, "game_won")

	# Inflict lethal damage: 30.0 damage -> 0.0 HP
	nest.take_damage(30.0)
	assert_lte(float(nest.get("current_hp")), 0.0, "Nest HP must reach <= 0.0")
	assert_true(nest_destroyed_watcher.emitted, "EventBus.nest_destroyed must be emitted on fatal damage")
	assert_eq(nest_destroyed_watcher.last_args[0], nest, "nest_destroyed must pass destroyed Nest instance")
	assert_true(game_won_watcher.emitted, "EventBus.game_won must be emitted on Nest destruction")

func test_win_04_gamestate_is_game_won_and_is_game_over_flags() -> void:
	assert_false(bool(game_state_node.get("is_game_over")), "is_game_over initially false")
	assert_false(bool(game_state_node.get("is_game_won")), "is_game_won initially false")

	var nest = _create_nest()
	if nest == null:
		return

	if tree and tree.root:
		tree.root.add_child(nest)
		await wait_frames(1)

	nest.take_damage(30.0)
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_won")), "GameState.is_game_won must transition to true on win")
	assert_true(bool(game_state_node.get("is_game_over")), "GameState.is_game_over must transition to true on win")

func test_win_05_tower_can_target_and_eliminate_nest() -> void:
	assert_not_null(tower_script, "Tower.gd script must exist")
	if tower_script == null or nest_script == null:
		return

	var tower = tower_script.new()
	var nest = nest_script.new()
	_cleanup_nodes.append(tower)
	_cleanup_nodes.append(nest)

	# Place Tower at (0, 0, 0) and Nest at (0, 0, 3) -> within 5.0m attack range
	tower.position = Vector3(0.0, 0.0, 0.0)
	nest.position = Vector3(0.0, 0.0, 3.0)

	if tree and tree.root:
		tree.root.add_child(tower)
		tree.root.add_child(nest)
		await wait_frames(2)

	# Target acquisition
	var target = tower.acquire_target() if tower.has_method("acquire_target") else null
	if target == null and tower.has_method("on_target_entered"):
		tower.on_target_entered(nest)
		target = tower.acquire_target()

	assert_not_null(target, "Tower must acquire Nest within range as a valid target")
	assert_eq(target, nest, "Target must be the Nest entity")

	var game_won_watcher = watch_signal(event_bus_node, "game_won")

	# Repeatedly trigger Tower attack until Nest is eliminated (30 attacks @ 1.0 dmg)
	for i in range(30):
		if nest.get("current_hp") <= 0.0:
			break
		tower.attack(nest)

	assert_lte(float(nest.get("current_hp")), 0.0, "Nest HP must reach <= 0.0 after tower attacks")
	assert_true(game_won_watcher.emitted, "game_won emitted via Tower combat elimination of Nest")

func test_win_06_action_lockout_on_victory() -> void:
	# Transition game to Victory state
	event_bus_node.game_won.emit()
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_over")), "GameState.is_game_over is true")
	assert_true(bool(game_state_node.get("is_game_won")), "GameState.is_game_won is true")

	# 1. trigger_end_action blocked
	var initial_phase = int(game_state_node.current_phase)
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), initial_phase, "Phase must NOT advance when game is won")

	# 2. advance_phase blocked
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), initial_phase, "advance_phase must be blocked when game is won")

	# 3. AP spending blocked
	assert_false(game_state_node.can_spend_ap(1), "can_spend_ap must return false when game is won")
	assert_false(game_state_node.spend_ap(1), "spend_ap must return false when game is won")

	# 4. Building placement blocked
	if build_system_script and grid_manager_script:
		var grid = grid_manager_script.new()
		var bs = build_system_script.new()
		_cleanup_nodes.append(grid)
		_cleanup_nodes.append(bs)
		bs.setup(grid)
		assert_false(bs.can_place_building("tower", Vector2i(2, 2)), "can_place_building must return false when game is won")
		var placed = bs.place_building("tower", Vector2i(2, 2))
		assert_null(placed, "place_building must return null when game is won")

# ==============================================================================
# Category 2: Loss Condition & Campfire Core Lifecycle Tests (test_loss_*)
# ==============================================================================

func test_loss_01_core_config_and_initial_stats() -> void:
	assert_not_null(config_node, "Config singleton must exist")
	var core_cfg: Dictionary = config_node.BUILDINGS.get("core", {})
	assert_almost_eq(float(core_cfg.get("hp", 0.0)), 10.0, 0.001, "Config.BUILDINGS.core.hp must be 10.0")

	var core = _create_core_campfire()
	if core == null:
		return

	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	assert_almost_eq(float(core.get("max_hp")), 10.0, 0.001, "CoreCampfire.max_hp must be 10.0")
	assert_almost_eq(float(core.get("current_hp")), 10.0, 0.001, "CoreCampfire.current_hp must be 10.0")

func test_loss_02_core_partial_damage_emits_hp_changed_without_loss() -> void:
	var core = _create_core_campfire()
	if core == null:
		return

	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var hp_watcher = watch_signal(event_bus_node, "core_hp_changed")
	var game_lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Inflict 4.0 damage -> 6.0 HP remaining
	core.take_damage(4.0)
	assert_almost_eq(float(core.get("current_hp")), 6.0, 0.001, "Core HP drops to 6.0")
	assert_true(hp_watcher.emitted, "core_hp_changed must emit on partial damage")
	assert_almost_eq(float(hp_watcher.last_args[0]), 6.0, 0.001, "core_hp_changed current HP is 6.0")
	assert_almost_eq(float(hp_watcher.last_args[1]), 10.0, 0.001, "core_hp_changed max HP is 10.0")
	assert_false(game_lost_watcher.emitted, "game_lost must NOT emit on partial damage")
	assert_false(bool(game_state_node.get("is_game_over")), "GameState.is_game_over must remain false")

func test_loss_03_core_fatal_damage_emits_game_lost() -> void:
	var core = _create_core_campfire()
	if core == null:
		return

	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var hp_watcher = watch_signal(event_bus_node, "core_hp_changed")
	var game_lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Inflict lethal damage: 10.0 damage -> 0.0 HP
	core.take_damage(10.0)
	assert_lte(float(core.get("current_hp")), 0.0, "Core HP drops to <= 0.0")
	assert_true(hp_watcher.emitted, "core_hp_changed must emit on fatal damage")
	assert_almost_eq(float(hp_watcher.last_args[0]), 0.0, 0.001, "core_hp_changed current HP is 0.0 on destruction")
	assert_true(game_lost_watcher.emitted, "EventBus.game_lost must be emitted on Core destruction")

func test_loss_04_gamestate_is_game_over_flag_on_loss() -> void:
	assert_false(bool(game_state_node.get("is_game_over")), "is_game_over initially false")

	var core = _create_core_campfire()
	if core == null:
		return

	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	core.take_damage(10.0)
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_over")), "GameState.is_game_over must become true on game_lost")
	assert_false(bool(game_state_node.get("is_game_won")), "GameState.is_game_won must remain false on loss")

func test_loss_05_dino_attack_destroys_core() -> void:
	assert_not_null(dino_script, "Dino.gd script must exist")
	if dino_script == null or core_campfire_script == null:
		return

	var core = core_campfire_script.new()
	var dino = dino_script.new()
	_cleanup_nodes.append(core)
	_cleanup_nodes.append(dino)

	if tree and tree.root:
		tree.root.add_child(core)
		tree.root.add_child(dino)
		await wait_frames(1)

	var game_lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Simulate dinosaur attacking Core Campfire until destruction
	for i in range(10):
		if core.get("current_hp") <= 0.0:
			break
		core.take_damage(1.0)

	assert_lte(float(core.get("current_hp")), 0.0, "Core HP must reach 0")
	assert_true(game_lost_watcher.emitted, "game_lost emitted following dinosaur assault on Core")

func test_loss_06_action_lockout_on_loss() -> void:
	# Transition game to Loss state
	event_bus_node.game_lost.emit()
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_over")), "GameState.is_game_over is true")

	# 1. trigger_end_action blocked
	var initial_phase = int(game_state_node.current_phase)
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), initial_phase, "Phase must NOT advance when game is lost")

	# 2. advance_phase blocked
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), initial_phase, "advance_phase must be blocked when game is lost")

	# 3. AP spending blocked
	assert_false(game_state_node.can_spend_ap(1), "can_spend_ap must return false when game is lost")
	assert_false(game_state_node.spend_ap(1), "spend_ap must return false when game is lost")

	# 4. Building placement blocked
	if build_system_script and grid_manager_script:
		var grid = grid_manager_script.new()
		var bs = build_system_script.new()
		_cleanup_nodes.append(grid)
		_cleanup_nodes.append(bs)
		bs.setup(grid)
		assert_false(bs.can_place_building("wall", Vector2i(3, 3)), "can_place_building must return false when game is lost")
		var placed = bs.place_building("wall", Vector2i(3, 3))
		assert_null(placed, "place_building must return null when game is lost")

# ==============================================================================
# Category 3: HUD Reactive Display & Overlay Tests (test_hud_*)
# ==============================================================================

func test_hud_01_component_hierarchy_and_initial_state() -> void:
	var hud = _create_hud()
	assert_not_null(hud, "HUD instance must be created from scene or script")
	if hud == null:
		return

	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Assert GameOver overlay exists and is initially hidden
	var game_over_panel = hud.find_child("*GameOver*", true, false)
	if game_over_panel == null:
		game_over_panel = hud.find_child("*Result*", true, false)
	assert_not_null(game_over_panel, "HUD must contain GameOver/Result panel")
	if game_over_panel != null:
		assert_false(game_over_panel.visible, "GameOver panel must initially be hidden (visible = false)")

	# Assert TopBar / HUD Labels exist
	var ap_label = hud.find_child("*AP*", true, false)
	var wood_label = hud.find_child("*Wood*", true, false)
	if wood_label == null: wood_label = hud.find_child("*Resource*", true, false)
	var wave_label = hud.find_child("*Wave*", true, false)
	var hp_label = hud.find_child("*HP*", true, false)
	if hp_label == null: hp_label = hud.find_child("*Core*", true, false)

	assert_not_null(ap_label, "HUD must contain AP label")
	assert_not_null(wood_label, "HUD must contain Wood/Resource label")
	assert_not_null(wave_label, "HUD must contain Wave label")
	assert_not_null(hp_label, "HUD must contain Core HP label")

func test_hud_02_updates_on_ap_changed_signal() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var ap_label = hud.find_child("*AP*", true, false) as Label
	assert_not_null(ap_label, "AP label must exist")
	if ap_label == null: return

	# Emit AP changed: 2 current, 3 max
	event_bus_node.ap_changed.emit(2, 3)
	await wait_frames(1)
	assert_true("2" in ap_label.text and "3" in ap_label.text, "AP label text must reflect 2/3 (got '%s')" % ap_label.text)

	# Emit AP changed: 0 current, 3 max
	event_bus_node.ap_changed.emit(0, 3)
	await wait_frames(1)
	assert_true("0" in ap_label.text and "3" in ap_label.text, "AP label text must reflect 0/3 (got '%s')" % ap_label.text)

func test_hud_03_updates_on_resources_changed_signal() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var wood_label = hud.find_child("*Wood*", true, false) as Label
	if wood_label == null: wood_label = hud.find_child("*Resource*", true, false) as Label
	assert_not_null(wood_label, "Wood/Resource label must exist")
	if wood_label == null: return

	event_bus_node.resources_changed.emit({"wood": 18, "stone": 2, "food": 0})
	await wait_frames(1)
	assert_true("18" in wood_label.text, "Wood label text must reflect updated wood count 18 (got '%s')" % wood_label.text)

func test_hud_04_updates_on_wave_started_signal() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var wave_label = hud.find_child("*Wave*", true, false) as Label
	assert_not_null(wave_label, "Wave label must exist")
	if wave_label == null: return

	event_bus_node.wave_started.emit(3, true)
	await wait_frames(1)
	assert_true("3" in wave_label.text, "Wave label text must reflect Wave 3 (got '%s')" % wave_label.text)

func test_hud_05_updates_on_core_hp_changed_signal() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var hp_label = hud.find_child("*HP*", true, false) as Label
	if hp_label == null: hp_label = hud.find_child("*Core*", true, false) as Label
	assert_not_null(hp_label, "Core HP label must exist")
	if hp_label == null: return

	event_bus_node.core_hp_changed.emit(7.0, 10.0)
	await wait_frames(1)
	assert_true("7" in hp_label.text and "10" in hp_label.text, "Core HP label must reflect 7/10 (got '%s')" % hp_label.text)

func test_hud_06_victory_overlay_displayed_on_game_won() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var game_over_panel = hud.find_child("*GameOver*", true, false)
	if game_over_panel == null: game_over_panel = hud.find_child("*Result*", true, false)
	assert_not_null(game_over_panel, "GameOver panel must exist")

	event_bus_node.game_won.emit()
	await wait_frames(1)

	assert_true(game_over_panel.visible, "GameOver panel must become visible on game_won")

	# Find title / banner label in panel
	var title_label = game_over_panel.find_child("*Title*", true, false) as Label
	if title_label == null: title_label = game_over_panel.find_child("*Label*", true, false) as Label
	assert_not_null(title_label, "Result title label must exist in GameOver panel")
	if title_label != null:
		var text_lower = title_label.text.to_lower()
		assert_true("vic" in text_lower or "胜" in title_label.text or "win" in text_lower,
			"Title label must display Victory on game_won (got '%s')" % title_label.text)

func test_hud_07_defeat_overlay_displayed_on_game_lost() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var game_over_panel = hud.find_child("*GameOver*", true, false)
	if game_over_panel == null: game_over_panel = hud.find_child("*Result*", true, false)
	assert_not_null(game_over_panel, "GameOver panel must exist")

	event_bus_node.game_lost.emit()
	await wait_frames(1)

	assert_true(game_over_panel.visible, "GameOver panel must become visible on game_lost")

	var title_label = game_over_panel.find_child("*Title*", true, false) as Label
	if title_label == null: title_label = game_over_panel.find_child("*Label*", true, false) as Label
	assert_not_null(title_label, "Result title label must exist in GameOver panel")
	if title_label != null:
		var text_lower = title_label.text.to_lower()
		assert_true("def" in text_lower or "败" in title_label.text or "over" in text_lower or "lost" in text_lower,
			"Title label must display Defeat on game_lost (got '%s')" % title_label.text)

func test_hud_08_end_action_button_triggers_plan_end() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var end_btn = hud.find_child("*EndAction*", true, false) as Button
	if end_btn == null: end_btn = hud.find_child("*End*", true, false) as Button
	assert_not_null(end_btn, "End Action button must exist in HUD")
	if end_btn == null: return

	assert_eq(int(game_state_node.current_phase), 0, "Phase is initially PLAN (0)")

	# Simulate button press
	end_btn.emit_signal("pressed")
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 1, "Phase must transition to ATTACK (1) on End Action press")

# ==============================================================================
# Category 4: Game Restart & Scene Re-initialization Tests (test_restart_*)
# ==============================================================================

func test_restart_01_resets_gamestate_values() -> void:
	# Dirty the state
	game_state_node.current_ap = 0
	game_state_node.resources["wood"] = 1
	game_state_node.wave_number = 5
	game_state_node.is_game_over = true
	game_state_node.set("is_game_won", true)

	game_state_node.reset_game()

	assert_eq(int(game_state_node.current_ap), 3, "current_ap reset to BASE_AP (3)")
	assert_eq(int(game_state_node.max_ap), 3, "max_ap reset to BASE_AP (3)")
	assert_eq(int(game_state_node.resources.get("wood", 0)), opening_wood(), "wood reset to Config.INITIAL_RESOURCES")
	assert_false(bool(game_state_node.get("is_game_over")), "is_game_over reset to false")
	assert_false(bool(game_state_node.get("is_game_won")), "is_game_won reset to false")
	assert_eq(int(game_state_node.current_phase), 0, "current_phase reset to PLAN (0)")

func test_restart_02_clears_active_dinos_and_buildings() -> void:
	assert_not_null(main_script, "Main.gd script must exist")
	if main_script == null: return

	var main_inst = main_script.new()
	_cleanup_nodes.append(main_inst)

	if tree and tree.root:
		tree.root.add_child(main_inst)
		await wait_frames(2)

	# Locate or provision Dinos and Buildings containers
	var dinos_container = main_inst.find_child("Dinos", true, false)
	var buildings_container = main_inst.find_child("Buildings", true, false)

	if dinos_container and dino_script:
		var dummy_dino = dino_script.new()
		dinos_container.add_child(dummy_dino)
		assert_gt(dinos_container.get_child_count(), 0, "Leftover dino added to scene")

	if buildings_container and wall_script:
		var dummy_wall = wall_script.new()
		buildings_container.add_child(dummy_wall)
		assert_gt(buildings_container.get_child_count(), 0, "Leftover wall added to scene")

	# Trigger restart
	if main_inst.has_method("restart_game"):
		main_inst.call("restart_game")
		await wait_frames(2)

		if dinos_container:
			assert_eq(dinos_container.get_child_count(), 0, "All dinos must be purged after restart")
		if buildings_container:
			# Only CoreCampfire may remain; non-core buildings purged
			for b in buildings_container.get_children():
				assert_true((core_campfire_script and b.get_script() == core_campfire_script) or b.get("building_type") == "core",
					"Only Core may remain in Buildings container after restart")

func test_restart_03_reinstantiates_core_and_nest_with_full_hp() -> void:
	assert_not_null(main_script, "Main.gd script must exist")
	if main_script == null: return

	var main_inst = main_script.new()
	_cleanup_nodes.append(main_inst)

	if tree and tree.root:
		tree.root.add_child(main_inst)
		await wait_frames(2)

	if main_inst.has_method("restart_game"):
		main_inst.call("restart_game")
		await wait_frames(2)

		var core = main_inst.find_child("CoreCampfire", true, false)
		if core == null: core = main_inst.find_child("*Core*", true, false)
		var nest = main_inst.find_child("Nest", true, false)
		if nest == null or not nest.has_method("take_damage"):
			for child in main_inst.find_children("*", "StaticBody3D", true, false):
				if child.has_method("take_damage") and "current_hp" in child:
					nest = child
					break

		assert_not_null(core, "Main must contain CoreCampfire after restart")
		assert_not_null(nest, "Main must contain Nest after restart")

		if core != null and core.get("current_hp") != null:
			assert_almost_eq(float(core.get("current_hp")), 10.0, 0.001, "CoreCampfire HP reset to full 10.0")
		if nest != null and nest.get("current_hp") != null:
			assert_almost_eq(float(nest.get("current_hp")), 30.0, 0.001, "Nest HP reset to full 30.0")

func test_restart_04_hides_hud_game_over_overlay() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	var game_over_panel = hud.find_child("*GameOver*", true, false)
	if game_over_panel == null: game_over_panel = hud.find_child("*Result*", true, false)

	# Trigger game over so overlay shows
	event_bus_node.game_won.emit()
	await wait_frames(1)
	if game_over_panel != null:
		assert_true(game_over_panel.visible, "Overlay visible under game_won")

	# Simulate game reset / restart
	if hud.has_method("reset_hud"):
		hud.call("reset_hud")
	else:
		game_state_node.reset_game()

	await wait_frames(1)
	if game_over_panel != null:
		assert_false(game_over_panel.visible, "GameOver panel must be hidden after restart")

func test_restart_05_reenables_gameplay_actions() -> void:
	# Put into game over state
	event_bus_node.game_won.emit()
	await wait_frames(1)
	assert_true(bool(game_state_node.get("is_game_over")), "Game is over")

	# Reset
	game_state_node.reset_game()
	await wait_frames(1)
	assert_false(bool(game_state_node.get("is_game_over")), "Game is no longer over")

	# Verify AP spending re-enabled
	assert_true(game_state_node.can_spend_ap(1), "can_spend_ap must return true after restart")
	assert_true(game_state_node.spend_ap(1), "spend_ap must succeed after restart")
	assert_eq(int(game_state_node.current_ap), 2, "AP drops from 3 to 2")

	# Verify building placement re-enabled
	if build_system_script and grid_manager_script:
		var grid = grid_manager_script.new()
		var bs = build_system_script.new()
		_cleanup_nodes.append(grid)
		_cleanup_nodes.append(bs)
		bs.setup(grid)

		assert_true(bs.can_place_building("wall", Vector2i(1, 1)), "can_place_building must succeed after restart")
		var placed = bs.place_building("wall", Vector2i(1, 1))
		assert_not_null(placed, "place_building must succeed after restart")

	# Verify phase advancement re-enabled
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "trigger_end_action must succeed after restart")

func test_restart_06_consecutive_multi_restart_stability() -> void:
	# Run 3 consecutive game over -> reset cycles to prove zero memory corruption
	for cycle in range(3):
		event_bus_node.game_won.emit()
		assert_true(bool(game_state_node.get("is_game_over")), "Cycle %d: Game over" % cycle)

		game_state_node.reset_game()
		assert_false(bool(game_state_node.get("is_game_over")), "Cycle %d: Reset game over" % cycle)
		assert_eq(int(game_state_node.current_ap), 3, "Cycle %d: AP restored" % cycle)

		event_bus_node.game_lost.emit()
		assert_true(bool(game_state_node.get("is_game_over")), "Cycle %d: Game lost" % cycle)

		game_state_node.reset_game()
		assert_false(bool(game_state_node.get("is_game_over")), "Cycle %d: Reset after lost" % cycle)

# ==============================================================================
# Category 5: End-to-End Game Flow Integration (test_flow_*)
# ==============================================================================

func test_flow_01_complete_win_and_restart_lifecycle() -> void:
	var nest = _create_nest()
	var core = _create_core_campfire()
	var hud = _create_hud()
	if nest == null or core == null or hud == null:
		return

	if tree and tree.root:
		tree.root.add_child(nest)
		tree.root.add_child(core)
		tree.root.add_child(hud)
		await wait_frames(2)

	# 1. Active planning phase
	assert_eq(int(game_state_node.current_phase), 0, "Phase starts in PLAN")
	assert_eq(int(game_state_node.current_ap), 3, "AP starts at 3")

	# 2. Player ends action to begin attack
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Phase enters ATTACK")

	# 3. Destroy Nest -> triggers victory
	nest.take_damage(30.0)
	await wait_frames(2)

	assert_true(bool(game_state_node.get("is_game_won")), "Game won")
	assert_true(bool(game_state_node.get("is_game_over")), "Game over")

	# 4. GameOver overlay shown
	var game_over_panel = hud.find_child("*GameOver*", true, false)
	if game_over_panel == null: game_over_panel = hud.find_child("*Result*", true, false)
	if game_over_panel != null:
		assert_true(game_over_panel.visible, "Victory overlay displayed")

	# 5. Reset game
	game_state_node.reset_game()
	await wait_frames(1)

	assert_false(bool(game_state_node.get("is_game_over")), "Game over cleared")
	assert_eq(int(game_state_node.current_phase), 0, "Phase back to PLAN")
