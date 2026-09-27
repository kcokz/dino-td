# res://tests/test_v06_portraits.gd
# v0.6: "还是没到优秀游戏的质感". A good RTS shows the unit itself in its panel, where this one had
# a flat icon: each thing the command card and a bench's card can show has a portrait rendered
# from its own model (Config.PORTRAITS, tools/render_portraits.gd) -- the Hero's head and
# shoulders, a building in three-quarter view -- on a clear ground, the socket its backdrop.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

## The Config.VISUALS keys that are to have portraits.
func _subjects() -> Array:
	var out: Array = []
	for key in config_node.VISUALS:
		if Array(config_node.PORTRAITS["kinds"]).has(String(key).get_slice("/", 0)):
			out.append(String(key))
	return out

func test_01_everything_the_panels_can_show_has_its_portrait() -> void:
	var spec: Dictionary = config_node.PORTRAITS
	var px: int = int(spec["size"]) * int(spec["scale"])
	var subjects: Array = _subjects()
	assert_true(subjects.has("hero"), "The Hero has one")
	for key in subjects:
		assert_not_null(UiTheme.portrait(key), "%s has a portrait" % key)
		var path: String = String(spec["dir"]) + String(key).replace("/", "_") + ".png"
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(img, "%s's portrait is there to look at" % key)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		assert_eq(img.get_size(), Vector2i(px, px), "%s's is rendered at %dx the size it is shown" % [key, int(spec["scale"])])
		# Clear round the edge -- the socket it sits in is its backdrop -- and the thing in
		# the middle, not an empty render.
		for corner in [Vector2i(0, 0), Vector2i(px - 1, 0)]:
			assert_eq(img.get_pixelv(corner).a, 0.0, "%s's portrait is clear at its top corners" % key)
		var solid: int = 0
		for y in range(px * 3 / 8, px * 5 / 8):
			for x in range(px * 3 / 8, px * 5 / 8):
				if img.get_pixel(x, y).a > 0.5:
					solid += 1
		assert_gt(solid, 0, "%s stands in the middle of its portrait" % key)

func test_02_the_command_card_shows_the_hero_and_a_building_themselves() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	await wait_frames(1)
	assert_eq(panel.portrait.texture, UiTheme.portrait("hero"), "The Hero's panel shows the Hero himself")
	assert_eq(panel.portrait.custom_minimum_size, Vector2.ONE * float(config_node.PORTRAITS["size"]),
		"at the portrait size Config gives")
	var cabin: Node = main.find_child("CoreCampfire", true, false)
	assert_not_null(cabin, "The level has its cabin")
	if cabin:
		panel.select_target(cabin)
		await wait_frames(1)
		assert_eq(panel.portrait.texture, UiTheme.portrait("building/core"), "The cabin's panel shows the cabin")

func test_03_a_bench_in_the_cabin_shows_itself() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.enter_cabin()
	await wait_frames(1)
	var screen = main.hud.cabin_screen
	for station_id in config_node.STATIONS:
		screen.select(String(station_id))
		var card: Node = screen.find_child("Bench_%s" % station_id, true, false)
		assert_not_null(card, "%s has its card" % station_id)
		if card == null:
			continue
		var shot: TextureRect = card.find_child("Portrait", true, false) as TextureRect
		assert_not_null(shot, "%s's card shows its portrait" % station_id)
		if shot:
			assert_eq(shot.texture, UiTheme.portrait("station/%s" % station_id), "%s is shown as itself" % station_id)

func test_04_a_thing_with_no_portrait_keeps_its_icon() -> void:
	assert_null(UiTheme.portrait("building/no_such_thing"), "Nothing to show for a thing never rendered")
	var r: TextureRect = UiKit.portrait_rect("building/no_such_thing", "wall")
	_cleanup_nodes.append(r)
	assert_eq(r.texture, UiTheme.icon("wall"), "so its icon stands in")
	assert_eq(r.custom_minimum_size, Vector2.ONE * float(config_node.PORTRAITS["size"]), "at the same size")
