# res://tests/test_v06_the_interface.gd
# UI-POLISH: the interface drawn as one thing -- one theme from Config.THEME's tokens (its faces
# are test_v06_the_faces', its materials test_v06_the_frames'), an icon for everything the player meets --
# and the two screens it is read on most: the command card in the corner, and the cabin.
#
# Everything expected is read from Config or from the theme built from it.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var _cleanup_nodes: Array[Node] = []

## The files that draw the interface. None of them sizes text by hand (UI-POLISH T1).
const UI_SCRIPTS: Array[String] = [
	"res://scripts/ui/HUD.gd",
	"res://scripts/ui/OptionPanel.gd",
	"res://scripts/ui/PauseMenu.gd",
	"res://scripts/ui/CabinScreen.gd",
	"res://scripts/ui/UiKit.gd",
]

## The glyphs the interface draws on its buttons, toasts and cards.
const GLYPHS: Array[String] = ["pause", "play", "menu", "build", "upgrade", "repair", "demolish",
	"back", "clock", "warning", "lock", "info", "check", "fed", "signal"]

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
		game_state_node.is_paused = false
		game_state_node.reset_game()
	super.after_each()

func _keep(node: Node) -> Node:
	_cleanup_nodes.append(node)
	return node

func _hud() -> Node:
	var hud = _keep(load("res://scenes/ui/HUD.tscn").instantiate())
	tree.root.add_child(hud)
	await wait_frames(1)
	return hud

func _level() -> Node:
	var main = await fresh_level()
	_keep(main)
	return main

# ==============================================================================
# 1. One theme, one face, an icon for everything
# ==============================================================================

func test_01_the_interface_is_one_theme_built_from_the_tokens() -> void:
	var hud = await _hud()
	var theme: Theme = hud.root_control.theme
	assert_not_null(theme, "The HUD's root carries the theme, and everything under it inherits it")
	if theme == null:
		return
	var tokens: Dictionary = config_node.THEME
	assert_eq(theme.default_font_size, int(tokens["font_sizes"]["body"]), "Body text is the ladder's body step")
	assert_eq(theme.get_color("font_color", "Label"), tokens["colors"]["text"], "Text is the text colour")
	for variation in [&"HeadingLabel", &"TitleLabel", &"NumberLabel", &"HudPanel", &"CardButton",
			&"AccentButton", &"DangerButton", &"HealthBar", &"BuildBar", &"SolidPanel"]:
		assert_true(theme.get_type_variation_base(variation) != &"", "The theme has a %s" % variation)
	assert_eq(theme.get_font_size("font_size", "HeadingLabel"), int(tokens["font_sizes"]["heading"]),
		"A heading is the ladder's heading step")

func test_03_everything_the_player_meets_has_an_icon() -> void:
	var names: Array[String] = []
	for res_id in config_node.RESOURCES:
		names.append(String(res_id))
	for type_id in config_node.BUILDINGS:
		names.append(String(type_id))
	for station_id in config_node.STATIONS:
		names.append(String(station_id))
	names.append_array(GLYPHS)
	names.append_array(["hero", "core"])
	for name in names:
		assert_not_null(UiTheme.icon(name), "%s has an icon" % name)
	for res_type in config_node.RESOURCE_NODES:
		assert_not_null(UiTheme.node_icon(String(res_type)), "A %s node has an icon of its own" % res_type)

func test_04_no_text_is_sized_by_hand() -> void:
	# UI-POLISH T1: a size is a step on the theme's ladder, asked for by kind of text. A
	# size set on one label is where the forty slightly different sizes came from.
	for path in UI_SCRIPTS:
		var src: String = FileAccess.get_file_as_string(path)
		assert_gt(src.length(), 0, "%s is there to read" % path)
		assert_false(src.contains("add_theme_font_size_override"), "%s sizes no text by hand" % path)
		assert_false(src.contains("StyleBoxFlat.new()"), "%s styles no panel by hand" % path)

# ==============================================================================
# 2. The command card
# ==============================================================================

func test_06_the_command_card_grows_upward_from_its_corner() -> void:
	var main = await _level()
	var panel: Control = main.hud.option_panel
	panel.set_selected_unit(main.hero)
	await wait_frames(2)
	var screen: Rect2 = main.hud.root_control.get_global_rect()
	var margin: float = float(config_node.UI["option_panel_margin"])
	var hero_rect: Rect2 = panel.get_global_rect()
	assert_almost_eq(hero_rect.end.x, screen.end.x - margin, 1.0, "Its right edge is the margin in from the screen's")
	assert_almost_eq(hero_rect.end.y, screen.end.y - margin, 1.0, "And so is its bottom edge")
	assert_almost_eq(hero_rect.size.x, float(config_node.UI["option_panel_size"].x), 1.0, "It is as wide as Config says")
	# The build menu holds more: the card grows up, its corner where it was.
	panel.current_menu = "build"
	panel._refresh_ui()
	await wait_frames(2)
	var build_rect: Rect2 = panel.get_global_rect()
	assert_gt(build_rect.size.y, hero_rect.size.y, "The build menu is taller than the Hero's card")
	assert_almost_eq(build_rect.end.y, hero_rect.end.y, 1.0, "And its bottom has not moved: it grew upward")
	assert_gte(build_rect.position.y, screen.position.y, "All of it still on the screen")
	# And back: it shrinks again rather than keeping the height it had.
	panel.current_menu = "default"
	panel._refresh_ui()
	await wait_frames(2)
	assert_almost_eq(panel.get_global_rect().size.y, hero_rect.size.y, 1.0, "Back to the Hero's card, back to its height")

# ==============================================================================
# 3. The cabin
# ==============================================================================

func test_07_inside_every_bench_is_a_card_offering_its_jobs() -> void:
	var main = await _level()
	stock_everything()
	main.enter_cabin()
	await wait_frames(2)
	var screen: Control = main.hud.cabin_screen
	assert_true(screen.visible and screen.is_open, "Inside, the cabin's screen is up")
	var stations: Array = main.cabin_interior.stations
	assert_eq(stations.size(), config_node.STATIONS.size(), "Every bench is in the room")
	for station in stations:
		var station_id: String = String(station.station_id)
		var card: Node = screen.find_child("Bench_%s" % station_id, true, false)
		assert_not_null(card, "%s has a card" % station_id)
		if card == null:
			continue
		for job_id in station.jobs():
			if not station.can_offer(String(job_id)):
				continue
			var btn: Button = card.find_child("Job_%s" % job_id, true, false) as Button
			assert_not_null(btn, "%s offers %s" % [station_id, job_id])
			if btn:
				assert_false(btn.disabled, "With everything in stock, %s can be started" % job_id)
	main.leave_cabin()
	await wait_frames(1)
	assert_false(screen.visible, "Outside, it is gone")

func test_08_repaired_the_launch_is_the_one_thing_to_press() -> void:
	var main = await _level()
	for i in range(int(game_state_node.beacon_stage_count())):
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	main.enter_cabin()
	await wait_frames(2)
	var card: Node = main.hud.cabin_screen.find_child("Bench_%s" % String(config_node.BEACON_STATION), true, false)
	assert_not_null(card, "The beacon has a card")
	if card == null:
		return
	var launch: Button = card.find_child("Job_%s" % String(config_node.BEACON_LAUNCH), true, false) as Button
	assert_not_null(launch, "Repaired, the launch is on offer")
	if launch == null:
		return
	assert_eq(launch.theme_type_variation, &"AccentButton", "Drawn as the call to action, not as a purchase")
	assert_false(launch.disabled, "And it can be pressed")
	assert_ne((card.find_child("Status", true, false) as Label).text, "", "The bench says where the beacon has got to")

func test_09_inside_the_stock_stays_readable() -> void:
	# The cabin's backdrop frosts whatever is drawn before it. It is drawn first, so what it
	# frosts is the room -- the stock, the vitals and a raid's warning stay sharp on top.
	var hud = await _hud()
	var cabin_at: int = hud.cabin_screen.get_index()
	for name in ["TopBar", "Toasts"]:
		var node: Node = hud.root_control.get_node_or_null(name)
		assert_not_null(node, "The HUD has its %s" % name)
		if node:
			assert_lt(cabin_at, node.get_index(), "%s is drawn over the cabin's screen" % name)

func test_10_a_big_stock_pushes_the_vitals_over_rather_than_under() -> void:
	# The top row is one container: however wide the stock gets, nothing in it overlaps.
	var hud = await _hud()
	var huge: Dictionary = {}
	for res_id in config_node.RESOURCES:
		huge[String(res_id)] = 99999
	hud._on_resources_changed(huge)
	await wait_frames(2)
	var stock: Rect2 = hud.root_control.find_child("ResourcePanel", true, false).get_global_rect()
	var vitals: Rect2 = hud.root_control.find_child("VitalsPanel", true, false).get_global_rect()
	var controls: Rect2 = hud.root_control.find_child("ControlsPanel", true, false).get_global_rect()
	assert_lte(stock.end.x, vitals.position.x, "The stock ends before the vitals begin")
	assert_lte(vitals.end.x, controls.position.x, "And the vitals before the controls")

func test_11_a_toast_stands_under_the_top_row_and_clear_of_the_cabin_dock() -> void:
	# Inside, the room fills the screen and the dock keeps to the bottom: a toast stands
	# where it does outside -- under the top row, in the middle -- over the room.
	var main = await _level()
	main.enter_cabin()
	main.hud.show_hint(tr("CABIN_SUBTITLE"))
	await wait_frames(2)
	var toast: Rect2 = main.hud.hint_toast.get_global_rect()
	var dock: Rect2 = main.hud.cabin_screen.find_child("Dock", true, false).get_global_rect()
	var top_row: Rect2 = main.hud.root_control.find_child("VitalsPanel", true, false).get_global_rect()
	var middle: float = main.hud.root_control.get_global_rect().get_center().x
	assert_lte(toast.end.y, dock.position.y, "Inside, a toast is clear of the dock")
	assert_gte(toast.position.y, top_row.end.y, "And under the top row")
	assert_almost_eq(toast.get_center().x, middle, 1.0, "In the middle of the screen")
	main.leave_cabin()
	await wait_frames(2)
	var outside: Rect2 = main.hud.hint_toast.get_global_rect()
	var vitals: Rect2 = main.hud.root_control.find_child("VitalsPanel", true, false).get_global_rect()
	assert_gte(outside.position.y, vitals.end.y, "Outside, it is back under the top row")
	assert_almost_eq(outside.get_center().x, middle, 1.0, "And in the middle of the screen")
