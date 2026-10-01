# res://tests/test_v06_no_more_than_was_shown.gd
# The player, v0.6 round six: "连续建造的时候，如果材料不够的pending就显示红色，然后点击会提示没法造材料不够，这样
# 不会出现造下去的比pending的少". And round seven: "墙连续建造，材料不够现在是会显示红色了，但是按左键还是会把能造得造下
# 去，我要的效果是all or nothing，有红色的时候点下去会有一行小字说明材料不够，白色部分也没法造下去，而且白色部分应该就变成
# 绿色，和单个一样"; "地刺这种也可以连续建造".
#
# A run dragged further than the stock stretches: the sections it pays for are green -- the green of a single ghost
# that would go down -- and the sections past it red, and the line says so. Let go with any section red, and none of
# the run goes down: nothing paid, and a line saying it is short of materials, and by how much. With none red, all of
# it goes down. Spikes are dragged out as a fence is.
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

## Enough in the stock for `n` of `type_id`, and no more.
func _stock_for(n: int, type_id: String = "wall") -> void:
	for res_id in config_node.RESOURCES:
		game_state_node.resources[String(res_id)] = 0
	var cost: Dictionary = config_node.BUILDINGS[type_id]["cost"]
	for res_id in cost:
		game_state_node.resources[res_id] = int(cost[res_id]) * n

## A run `north` metres north of the cabin as a drag lays it out (Main._run_to): every cell a `type_id` can
## stand in.
func _run(main: Node, type_id: String = "wall", north: float = 8.0) -> Array[Vector2i]:
	var gm = main.grid_manager
	var core: Vector3 = cabin_at(main)
	main.current_build_type = type_id
	var out: Array[Vector2i] = []
	for cell in gm.build_cells_on_line(gm.build_cell_to_world(gm.world_to_build_cell(core + Vector3(-6.0, 0.0, -north))),
			gm.build_cell_to_world(gm.world_to_build_cell(core + Vector3(6.0, 0.0, -north)))):
		if main.build_system.can_stand_at(type_id, cell):
			out.append(cell)
	return out

## Whether every piece of a ghost is drawn in `colour` (its alpha aside).
func _drawn_in(main: Node, ghost: Node, colour: Color) -> bool:
	var meshes: Array = main._meshes_in(ghost)
	if meshes.is_empty():
		return false
	for mi in meshes:
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if mat == null:
			return false
		var c: Color = mat.albedo_color
		if not (is_equal_approx(c.r, colour.r) and is_equal_approx(c.g, colour.g) and is_equal_approx(c.b, colour.b)):
			return false
	return true

func _green() -> Color:
	return config_node.BUILD_GHOST["go"]

func _red() -> Color:
	return config_node.BUILD_GHOST["no"]

func _standing(main: Node, type_id: String = "wall") -> int:
	var n: int = 0
	for b in main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and str(b.get("building_type")) == type_id:
			n += 1
	return n

func test_01_past_the_stock_the_run_is_red_and_the_rest_green_as_a_single_ghost_is() -> void:
	var main = await _level()
	_stock_for(3)
	var cells: Array[Vector2i] = _run(main)
	assert_gt(cells.size(), 6, "(a run longer than the stock: %d sections)" % cells.size())
	main._show_run_preview(cells)
	var ghosts: Array = main._run_preview.get_children()
	assert_eq(ghosts.size(), cells.size(), "Every section of the run is shown")
	for i in ghosts.size():
		if i < 3:
			assert_true(_drawn_in(main, ghosts[i], _green()), "Section %d is green: paid for" % (i + 1))
		else:
			assert_true(_drawn_in(main, ghosts[i], _red()), "Section %d is red: past the stock" % (i + 1))
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_SHORT") % [3, cells.size()], "and it says so (%s)" % main.hud.hint_label.text)
	main._end_drag()

func test_02_let_go_with_any_red_and_none_of_it_goes_down() -> void:
	var main = await _level()
	_stock_for(3)
	var cells: Array[Vector2i] = _run(main)
	var before: int = _standing(main)
	var stock: Dictionary = game_state_node.resources.duplicate()
	assert_eq(main._commit_run(cells), 0, "Not one section is laid -- not even the green ones")
	await wait_frames(2)
	assert_eq(_standing(main), before, "(nothing stands)")
	assert_eq(game_state_node.resources, stock, "and nothing is paid")
	var missing: String = main._missing_for("wall", cells.size())
	assert_ne(missing, "", "(it is short of something)")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_SHORT_NONE") % [cells.size(), missing],
		"A line says it is short of materials, and by how much (%s)" % main.hud.hint_label.text)
	var cost: Dictionary = config_node.BUILDINGS["wall"]["cost"]
	for res_id in cost:
		var short: int = int(cost[res_id]) * (cells.size() - 3)
		assert_true(missing.contains(str(short)), "(%d %s short for the whole run: %s)" % [short, res_id, missing])

func test_03_with_nothing_in_hand_it_is_all_red_and_nothing_is_laid() -> void:
	var main = await _level()
	_stock_for(0)
	var cells: Array[Vector2i] = _run(main)
	assert_false(cells.is_empty(), "The run is laid out over the ground all the same")
	main._show_run_preview(cells)
	for ghost in main._run_preview.get_children():
		assert_true(_drawn_in(main, ghost, _red()), "every section of it red")
	main._end_drag()
	main.current_build_type = "wall"
	var before: int = _standing(main)
	assert_eq(main._commit_run(cells), 0, "Let go, nothing is laid")
	assert_eq(_standing(main), before, "(nothing stands)")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_SHORT_NONE") % [cells.size(), main._missing_for("wall", cells.size())],
		"and it says why (%s)" % main.hud.hint_label.text)

func test_04_paid_for_whole_it_is_all_green_and_all_of_it_goes_down() -> void:
	var main = await _level()
	# A row for each pass, one north of the other.
	for pass_spare in [[8.0, 0], [10.0, 2]]:
		var cells: Array[Vector2i] = _run(main, "wall", float(pass_spare[0]))
		_stock_for(cells.size() + int(pass_spare[1]))
		main._show_run_preview(cells)
		for ghost in main._run_preview.get_children():
			assert_true(_drawn_in(main, ghost, _green()), "With the whole run's worth (+%d), every section green" % int(pass_spare[1]))
		main._end_drag()
		main.current_build_type = "wall"
		var before: int = _standing(main)
		assert_eq(main._commit_run(cells), cells.size(), "and every section goes down")
		await wait_frames(2)
		assert_eq(_standing(main) - before, cells.size(), "(and stands)")
	var last: Array[Vector2i] = _run(main, "wall", 12.0)
	_stock_for(maxi(last.size() - 1, 0))
	main.current_build_type = "wall"
	assert_eq(main._commit_run(last), 0, "One section's worth short, none of it goes down")

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

func test_06_a_single_ghost_and_a_run_are_one_green() -> void:
	# "白色部分应该就变成绿色，和单个一样": the run's sections that will go down were white.
	var main = await _level()
	_stock_for(5)
	var cells: Array[Vector2i] = _run(main)
	main.on_build_selected("wall")
	await wait_frames(1)
	var at: Vector3 = main.grid_manager.build_cell_to_world(cells[0])
	main._update_build_preview(main.camera.unproject_position(at))
	assert_true(main.build_preview != null and main.build_preview.visible, "(the single ghost is up)")
	if main.build_preview != null:
		var body: Node = main.build_preview.find_child("Body", false, false)
		assert_true(body != null and _drawn_in(main, body, _green()), "A single ghost that would go down is green")
	main._drag_from = cells[0]
	main._dragging = true
	main._show_run_preview(cells.slice(0, 4))
	var ghosts: Array = main._run_preview.get_children()
	assert_eq(ghosts.size(), 4, "(a run of four)")
	for ghost in ghosts:
		assert_true(_drawn_in(main, ghost, _green()), "and so is every section of a run that would")
	main._end_drag()

func test_07_a_section_he_cannot_get_to_keeps_the_whole_run_back() -> void:
	var main = await _level()
	var cells: Array[Vector2i] = _run(main)
	_stock_for(cells.size())
	cells = _run(main)
	var far: Vector2i = cells[cells.size() / 2]
	# As if the river were there: the Hero is asked once per cell for a gesture (Main._can_reach_cell).
	main._reach_asked[far] = false
	main._show_run_preview(cells)
	var red: int = 0
	for ghost in main._run_preview.get_children():
		if _drawn_in(main, ghost, _red()):
			red += 1
	assert_eq(red, 1, "The one he cannot get to is red")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_UNREACHABLE"), "and the line says so")
	main._end_drag()
	main.current_build_type = "wall"
	main._reach_asked[far] = false
	var before: int = _standing(main)
	assert_eq(main._commit_run(cells), 0, "Let go, none of the run goes down")
	assert_eq(_standing(main), before, "(nothing stands)")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_RUN_UNREACHABLE_NONE") % [1], "and it says why (%s)" % main.hud.hint_label.text)

func test_08_spikes_are_dragged_out_as_a_fence_is() -> void:
	# "地刺这种也可以连续建造".
	var main = await _level()
	var kinds: Array = config_node.BUILD_DRAG["kinds"]
	for type_id in config_node.BUILDINGS:
		var kind: String = String(config_node.get_building_kind(String(type_id)))
		if kind == "spikes":
			assert_true(main._is_dragged_out(String(type_id)), "%s is dragged out" % type_id)
		elif not kinds.has(kind):
			assert_false(main._is_dragged_out(String(type_id)), "%s (%s) is placed one at a time" % [type_id, kind])
	var cells: Array[Vector2i] = _run(main, "ground_spikes")
	_stock_for(cells.size(), "ground_spikes")
	cells = _run(main, "ground_spikes")
	assert_gt(cells.size(), 6, "(a strip of %d)" % cells.size())
	main._drag_from = cells[0]
	main._dragging = true
	main._show_run_preview(cells)
	for ghost in main._run_preview.get_children():
		assert_true(_drawn_in(main, ghost, _green()), "Paid for, the strip is green")
	main._end_drag()
	main.current_build_type = "ground_spikes"
	var before: int = _standing(main, "ground_spikes")
	assert_eq(main._commit_run(cells), cells.size(), "Let go, the whole strip goes down")
	await wait_frames(2)
	assert_eq(_standing(main, "ground_spikes") - before, cells.size(), "(a patch on every cell of it)")
	var more: Array[Vector2i] = []
	for cell in cells:
		more.append(cell + Vector2i(0, -2))
	_stock_for(more.size() - 1, "ground_spikes")
	main.current_build_type = "ground_spikes"
	assert_eq(main._commit_run(more), 0, "and as a fence, a strip short of a patch goes down not at all")
