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

func test_06_the_command_card_grows_upward_from_his_commands() -> void:
	# The card stands on his commands in the corner (v0.6 round four), and grows upward from there.
	var main = await _level()
	var panel: Control = main.hud.option_panel
	var commands: Control = main.hud.hero_commands
	var node: Node = main.get_tree().get_nodes_in_group("resource_nodes")[0]
	panel.set_selected_unit(node)
	await wait_frames(2)
	var screen: Rect2 = main.hud.root_control.get_global_rect()
	var margin: float = float(config_node.UI["option_panel_margin"])
	var node_rect: Rect2 = panel.get_global_rect()
	assert_almost_eq(node_rect.end.x, screen.end.x - margin, 1.0, "Its right edge is the margin in from the screen's")
	assert_lte(node_rect.end.y, commands.get_global_rect().position.y, "Its foot is above his commands")
	assert_almost_eq(node_rect.size.x, float(config_node.UI["option_panel_size"].x), 1.0, "It is as wide as Config says")
	# The build menu holds more: the card grows up, its foot where it was.
	panel.set_selected_unit(main.hero)
	panel.show_menu("build")
	await wait_frames(2)
	var build_rect: Rect2 = panel.get_global_rect()
	assert_gt(build_rect.size.y, node_rect.size.y, "The build menu is taller than a tree's card")
	assert_almost_eq(build_rect.end.y, node_rect.end.y, 1.0, "And its bottom has not moved: it grew upward")
	assert_gte(build_rect.position.y, screen.position.y, "All of it still on the screen")
	# And back: it shrinks again rather than keeping the height it had.
	panel.set_selected_unit(node)
	await wait_frames(2)
	assert_almost_eq(panel.get_global_rect().size.y, node_rect.size.y, 1.0, "Back to the tree's card, back to its height")

# ==============================================================================
# 3. The cabin
# ==============================================================================

func test_07_every_bench_chosen_offers_its_jobs_on_the_card() -> void:
	# The benches stand in the cabin; one clicked is shown on the command card like anything else
	# (v0.6 round three: it was a dock of its own along the bottom of a room under the map).
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	var stations: Array = main.current_core.stations
	assert_eq(stations.size(), config_node.STATIONS.size(), "Every bench is in the cabin")
	for station in stations:
		var station_id: String = String(station.station_id)
		panel.select_target(station)
		await wait_frames(1)
		for job_id in station.jobs():
			if not station.can_offer(String(job_id)):
				continue
			var btn: Button = panel.button_container.find_child("Job_%s" % job_id, true, false) as Button
			assert_not_null(btn, "%s offers %s" % [station_id, job_id])
			if btn:
				assert_false(btn.disabled, "With everything in stock, %s can be started" % job_id)

func test_08_repaired_the_launch_is_the_one_thing_to_press() -> void:
	var main = await _level()
	for i in range(int(game_state_node.beacon_stage_count())):
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	var panel = main.hud.option_panel
	var bench: Node = main.current_core.station(String(config_node.BEACON_STATION))
	panel.select_target(bench)
	await wait_frames(2)
	var launch: Button = panel.button_container.find_child("Job_%s" % String(config_node.BEACON_LAUNCH), true, false) as Button
	assert_not_null(launch, "Repaired, the launch is on offer")
	if launch == null:
		return
	assert_eq(launch.theme_type_variation, &"AccentButton", "Drawn as the call to action, not as a purchase")
	assert_false(launch.disabled, "And it can be pressed")
	assert_ne(String(bench.get_display_info()["status"]), "", "The bench says where the beacon has got to")

func test_10_a_big_stock_stays_clear_of_the_cabins_medallion() -> void:
	# The strip's left holds the stock, its right the controls, and the cabin's medallion
	# hangs from its middle: however big the counts get, none of the three runs into another.
	var hud = await _hud()
	# The most a run can hold: four figures of every material -- the valleys hold a couple of
	# thousand wood at most, every tree's reserve together (RESOURCE_NODES.capacity) -- and the
	# beacon's parts one each, all three found and not yet fitted (test_v06_wrecks).
	var huge: Dictionary = {}
	for res_id in config_node.RESOURCES:
		huge[String(res_id)] = 1 if config_node.is_part(String(res_id)) else 9999
	hud._on_resources_changed(huge)
	await wait_frames(2)
	var stock: Rect2 = hud.root_control.find_child("ResourcePanel", true, false).get_global_rect()
	var cabin: Rect2 = hud.root_control.find_child("CabinEmblem", true, false).get_global_rect()
	var controls: Rect2 = hud.root_control.find_child("ControlsPanel", true, false).get_global_rect()
	assert_lte(stock.end.x, cabin.position.x, "The stock ends before the cabin's medallion begins")
	assert_lte(cabin.end.x, controls.position.x, "And the medallion before the controls")
