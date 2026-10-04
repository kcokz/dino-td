# res://tests/test_v06_the_status_bar.gd
# v0.6 feedback: "状态栏的那个版面还是显得像网页游戏，还是没有达到我说的精致的标准".
#
# Three plates floating along the top were a web page's navigation, whatever they were made
# of. The status bar is a game's now: one strip along the top edge (Config.THEME.surfaces
# "strip") with the materials in round sockets at its left -- their icons rendered from the
# piles the game drops (Config.RENDERED_ICONS) -- the speeds, pause and menu as round buttons
# at its right, and hung from its middle the cabin's medallion, its health a ring round its
# portrait. The engineer's medallion stands at the bottom left; a click on it picks him.
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

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	await wait_frames(2)
	return main

func _rect(hud: Node, name: String) -> Rect2:
	var node: Control = hud.root_control.find_child(name, true, false) as Control
	return node.get_global_rect() if node else Rect2()

func test_01_one_strip_runs_along_the_top_edge() -> void:
	var main = await _level()
	var strip: Control = main.hud.root_control.find_child("TopBar", true, false) as Control
	assert_not_null(strip, "The status bar has its strip")
	if strip == null:
		return
	var screen: Rect2 = main.hud.root_control.get_global_rect()
	var at: Rect2 = strip.get_global_rect()
	assert_almost_eq(at.position.y, screen.position.y, 0.5, "It runs along the top edge")
	assert_almost_eq(at.size.x, screen.size.x, 0.5, "the whole width of the screen")
	assert_almost_eq(at.size.y, float(config_node.UI["strip_height"]), 0.5, "as tall as Config says")
	assert_eq(strip.theme_type_variation, &"StripPanel", "a strip of leather, rimmed along its bottom")
	for name in ["ResourcePanel", "ControlsPanel"]:
		var part: Rect2 = _rect(main.hud, name)
		assert_true(at.encloses(part), "%s is on the strip" % name)
	assert_lt(_rect(main.hud, "ResourcePanel").get_center().x, screen.get_center().x, "the stock at its left")
	assert_gt(_rect(main.hud, "ControlsPanel").get_center().x, screen.get_center().x, "the controls at its right")

func test_02_the_cabins_medallion_hangs_from_its_middle_and_rings_its_health() -> void:
	var main = await _level()
	var hud = main.hud
	var screen: Rect2 = hud.root_control.get_global_rect()
	var cabin: Rect2 = _rect(hud, "CabinEmblem")
	var strip: Rect2 = _rect(hud, "TopBar")
	assert_almost_eq(cabin.get_center().x, screen.get_center().x, 1.0, "It hangs from the middle of the strip")
	assert_lt(cabin.position.y, strip.end.y, "over the strip")
	assert_gt(cabin.end.y, strip.end.y, "and down from it")
	assert_true(hud.core_hp_bar is TextureProgressBar, "Its health is a ring")
	assert_eq(hud.core_hp_bar.fill_mode, TextureProgressBar.FILL_CLOCKWISE, "filling round it")
	var whole: float = float(config_node.BUILDINGS["core"]["hp"])
	var eb = tree.root.get_node("EventBus")
	eb.core_hp_changed.emit(whole * 0.25, whole)
	await wait_frames(1)
	assert_almost_eq(hud.core_hp_bar.value, 0.25, 0.001, "The ring is as full as the cabin is whole")
	assert_eq(hud.core_hp_bar.tint_progress, UiTheme.health_color(0.25), "in the colour its health is")
	assert_eq(hud.core_hp_label.text, config_node.shown_pair(whole * 0.25, whole), "its figures on the plate under it (as shown)")
	var face: TextureRect = hud.core_vital.find_child("Portrait", true, false) as TextureRect
	assert_not_null(face, "It shows the cabin")
	if face:
		assert_eq(face.texture, UiTheme.portrait("building/core"), "its own portrait")

func test_03_the_engineers_medallion_stands_at_the_bottom_left_and_picks_him() -> void:
	var main = await _level()
	var hud = main.hud
	var screen: Rect2 = hud.root_control.get_global_rect()
	var mine: Control = hud.root_control.find_child("HeroEmblem", true, false) as Control
	assert_not_null(mine, "The engineer has his medallion")
	if mine == null:
		return
	var at: Rect2 = mine.get_global_rect()
	assert_lt(at.get_center().x, screen.get_center().x, "at the left")
	assert_gt(at.get_center().y, screen.get_center().y, "at the bottom")
	assert_true(hud.hero_hp_bar is TextureProgressBar, "His health is a ring too")
	var told = watch_signal(tree.root.get_node("EventBus"), "unit_selected")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	mine.gui_input.emit(click)
	await wait_frames(1)
	assert_eq(told.emit_count, 1, "A click on it picks him")
	if told.emit_count > 0:
		assert_eq(told.last_args[0], main.hero, "him")

func test_04_the_controls_are_round_and_the_speed_it_runs_at_is_lit() -> void:
	var main = await _level()
	var hud = main.hud
	for btn in hud.speed_buttons + [hud.pause_btn, hud.menu_btn]:
		assert_eq(btn.theme_type_variation, &"RoundButton", "%s is a round button" % btn.name)
	assert_eq(hud.pause_btn.text, "", "Pause says it with its glyph")
	assert_ne(hud.pause_btn.tooltip_text, "", "and its words are its tooltip")
	hud.speed_buttons[1].pressed.emit()
	await wait_frames(1)
	assert_true(hud.speed_buttons[1].button_pressed, "The speed it runs at is lit")
	assert_false(hud.speed_buttons[0].button_pressed, "and the others not")
	hud.set_game_speed(1.0)

func test_05_a_materials_icon_is_rendered_from_its_pile() -> void:
	var spec: Dictionary = config_node.RENDERED_ICONS
	var px: int = int(spec["size"]) * int(spec["scale"])
	for res_id in config_node.RESOURCES:
		var key: String = "drop/%s" % res_id
		if not config_node.VISUALS.has(key):
			continue
		var path: String = String(spec["dir"]) + String(res_id) + ".png"
		assert_true(ResourceLoader.exists(path), "%s has an icon rendered from its pile" % res_id)
		var tex: Texture2D = UiTheme.icon(String(res_id))
		assert_not_null(tex, "and the interface uses it")
		if tex:
			assert_eq(tex.resource_path, path, "%s's icon is the rendered one, not the drawn" % res_id)
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			img.convert(Image.FORMAT_RGBA8)
			assert_eq(img.get_size(), Vector2i(px, px), "rendered at %dx the size it is drawn for" % int(spec["scale"]))
			assert_eq(img.get_pixel(0, 0).a, 0.0, "on a clear ground")
	assert_eq(UiTheme.icon("pause").resource_path.get_extension(), "svg", "A glyph with nothing to render stays drawn")
