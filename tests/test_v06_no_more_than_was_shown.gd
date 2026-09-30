# res://tests/test_v06_no_more_than_was_shown.gd
# The player, v0.6 round six: "连续建造的时候，如果材料不够的pending就显示红色，然后点击会提示没法造材料不够，这样
# 不会出现造下去的比pending的少". A fence dragged further than the stock stretches: the sections past it are red in the
# preview, and on letting go only the white ones go down -- the rest said to be short of materials. It used to show
# every section white and lay as many as the wood paid for: three of the ten it showed.
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
	unlock_all()

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
	# Where he happens to be standing is not what this is about: clear of the run, able to reach it.
	main.hero.global_position = cabin_at(main) + Vector3(0.0, 0.0, 20.0)
	await wait_frames(2)
	return main

## Enough in the stock for `n` sections of fence, and no more.
func _stock_for(n: int) -> void:
	var cost: Dictionary = config_node.BUILDINGS["wall"]["cost"]
	for res_id in cost:
		game_state_node.resources[res_id] = int(cost[res_id]) * n

## A run of fence north of the cabin as a drag lays it out (Main._run_to): every cell a section can stand in.
func _run(main: Node) -> Array[Vector2i]:
	var gm = main.grid_manager
	var core: Vector3 = cabin_at(main)
	main.current_build_type = "wall"
	var out: Array[Vector2i] = []
	for cell in gm.build_cells_on_line(gm.build_cell_to_world(gm.world_to_build_cell(core + Vector3(-6.0, 0.0, -8.0))),
			gm.build_cell_to_world(gm.world_to_build_cell(core + Vector3(6.0, 0.0, -8.0)))):
		if main.build_system.can_stand_at("wall", cell):
			out.append(cell)
	return out

## Whether a ghost of the run is drawn white -- going up -- rather than red.
func _white(main: Node, ghost: Node) -> bool:
	for mi in main._meshes_in(ghost):
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or mat.albedo_color.g < 0.9:
			return false
	return true

func _stakes(main: Node) -> int:
	var n: int = 0
	for b in main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and str(b.get("building_type")) == "wall":
			n += 1
	return n

func test_01_past_the_stock_the_run_is_red() -> void:
	var main = await _level()
	_stock_for(3)
	var cells: Array[Vector2i] = _run(main)
	assert_gt(cells.size(), 6, "(a run longer than the stock: %d sections)" % cells.size())
	main._show_run_preview(cells)
	var ghosts: Array = main._run_preview.get_children()
	assert_eq(ghosts.size(), cells.size(), "Every section of the run is shown")
	for i in ghosts.size():
		assert_eq(_white(main, ghosts[i]), i < 3, "Section %d is %s" % [i + 1, "white: paid for" if i < 3 else "red: past the stock"])
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_SHORT") % [3, cells.size()], "and it says so (%s)" % main.hud.hint_label.text)
	main._end_drag()

func test_02_let_go_only_the_white_go_down_and_the_rest_is_said() -> void:
	var main = await _level()
	_stock_for(3)
	var cells: Array[Vector2i] = _run(main)
	var before: int = _stakes(main)
	assert_eq(main._commit_run(cells), 3, "What was white is laid")
	assert_eq(_stakes(main) - before, 3, "(and stands there)")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_SHORT_LAID") % [3, cells.size() - 3],
		"The rest is said to be short of materials (%s)" % main.hud.hint_label.text)

func test_03_with_nothing_in_hand_it_is_all_red_and_nothing_is_laid() -> void:
	var main = await _level()
	_stock_for(0)
	var cells: Array[Vector2i] = _run(main)
	assert_false(cells.is_empty(), "The run is laid out over the ground all the same")
	main._show_run_preview(cells)
	var white: int = 0
	for ghost in main._run_preview.get_children():
		if _white(main, ghost):
			white += 1
	assert_eq(white, 0, "every section of it red")
	main._end_drag()
	main.current_build_type = "wall"
	var before: int = _stakes(main)
	assert_eq(main._commit_run(cells), 0, "Let go, nothing is laid")
	assert_eq(_stakes(main), before, "(nothing stands)")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_NO_RESOURCES"), "and it says why (%s)" % main.hud.hint_label.text)

func test_04_as_many_go_down_as_were_shown_white() -> void:
	var main = await _level()
	for n in [1, 2, 5]:
		_stock_for(n)
		var cells: Array[Vector2i] = _run(main)
		main._show_run_preview(cells)
		var white: int = 0
		for ghost in main._run_preview.get_children():
			if _white(main, ghost):
				white += 1
		main._end_drag()
		main.current_build_type = "wall"
		assert_eq(main._commit_run(cells), white, "With %d sections' worth in hand: as many laid as shown white (%d)" % [n, white])
		assert_eq(white, mini(n, cells.size()), "(%d white of %d)" % [white, cells.size()])

func test_05_the_stock_is_counted_by_its_scarcest_material() -> void:
	var main = await _level()
	var bs = main.build_system
	_stock_for(4)
	assert_eq(bs.affordable_count("wall"), 4, "Four sections' worth: four")
	var cost: Dictionary = config_node.BUILDINGS["wall"]["cost"]
	var first: String = String(cost.keys()[0])
	game_state_node.resources[first] = int(cost[first]) * 2
	assert_eq(bs.affordable_count("wall"), 2, "the scarcest of what it takes decides")
	_stock_for(0)
	var cell: Vector2i = _run(main)[0]
	assert_true(bs.can_stand_at("wall", cell), "Nothing in hand, a section can still stand there -- shown red")
	assert_false(bs.can_place_at("wall", cell), "but is not placed")
