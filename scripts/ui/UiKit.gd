# res://scripts/ui/UiKit.gd
class_name UiKit
extends RefCounted

## The interface's recurring pieces, built one way everywhere: an icon, a labelled bar, a
## priced card, and what a job at a bench says about itself. The command card and the cabin
## screen both offer jobs; built twice, they would drift apart, and a player would learn two
## ways to read one price.
##
## Styling is the theme's (UiTheme): these only put pieces together.

## An icon at a size, centred and kept square.
static func icon_rect(icon_name: String, px: int, node_name: String = "") -> TextureRect:
	var r := TextureRect.new()
	if node_name != "":
		r.name = node_name
	r.texture = UiTheme.icon(icon_name)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A thing's portrait at the portrait size (UiTheme.portrait, by its Config.VISUALS key), or
## its icon where it has none.
static func portrait_rect(key: String, icon_name: String, node_name: String = "") -> TextureRect:
	var r := icon_rect(icon_name, UiTheme.portrait_size(), node_name)
	var shot: Texture2D = UiTheme.portrait(key)
	if shot:
		r.texture = shot
	return r

## A bar with its figure at the right end: [row, bar, figure].
static func bar_row(prefix: String, variation: StringName = &"HealthBar") -> Array:
	var row := HBoxContainer.new()
	row.name = prefix + "Row"
	var bar := ProgressBar.new()
	bar.name = prefix + "Bar"
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size = Vector2(0, UiTheme.thickness("bar"))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var text := Label.new()
	text.name = prefix + "Text"
	text.theme_type_variation = &"SmallNumberLabel"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.custom_minimum_size = Vector2(UiTheme.width("figure"), 0)
	row.add_child(text)
	return [row, bar, text]

## An entry with a price (UI-POLISH T11): its icon and name up top, and along the bottom one
## chip per material -- the material's icon and how many. Its text is its name, so it is found
## and read by name like any button.
static func card_button(text: String, icon: Texture2D, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.theme_type_variation = &"CardButton"
	btn.custom_minimum_size = Vector2(0, UiTheme.height("card"))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.pressed.connect(callback)
	var row := HBoxContainer.new()
	row.name = "PriceRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# One line of small figures inside the card's stitches (UiTheme.card_inset; a line is its
	# size plus a little leading).
	var inset: Vector2i = UiTheme.card_inset()
	row.offset_left = inset.x
	row.offset_right = -inset.x
	row.offset_bottom = -float(inset.y)
	row.offset_top = row.offset_bottom - float(UiTheme.font_size("small") + UiTheme.space("xs") + UiTheme.space("hair"))
	btn.add_child(row)
	return btn

## The price chips on a card, the count red where the warehouse is short -- and, when the card
## cannot be pressed, a lock at the end of the row, so "can't" is a shape and not just a colour.
## `extra` is any word to add at the end (a job's time). A card is a pale hide: its figures
## are in ink (the Card* labels).
static func fill_price_row(btn: Button, price: Dictionary, extra: String = "") -> void:
	var row: HBoxContainer = btn.get_node_or_null("PriceRow")
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var gs = _state()
	for res_id in price:
		row.add_child(icon_rect(String(res_id), UiTheme.icon_size("s")))
		var n := Label.new()
		var short: bool = gs != null and int(gs.resources.get(res_id, 0)) < int(price[res_id])
		n.theme_type_variation = &"CardShortLabel" if short else &"CardNumberLabel"
		n.text = str(int(price[res_id]))
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(n)
	if extra != "":
		var clock := icon_rect("clock", UiTheme.icon_size("xs"))
		clock.modulate = UiTheme.color("ink_faint")
		row.add_child(clock)
		var t := Label.new()
		t.theme_type_variation = &"CardCaptionLabel"
		t.text = extra
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
	if btn.disabled:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		var lock := icon_rect("lock", UiTheme.icon_size("xs"), "Lock")
		lock.modulate = UiTheme.color("ink_faint")
		row.add_child(lock)

## A command on a unit's card, as the games do it: a square of hide with the command's icon
## filling it and its word under the icon, what it does in a tooltip, and -- for a command that
## spends something counted -- the count on a badge in its corner (v0.6 round two: "Build 可以作为
## 一个图标……吃饭也是一个图标").
static func command_button(text: String, icon: Texture2D, callback: Callable, tooltip: String = "", badge: int = -1) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon
	btn.theme_type_variation = &"TileButton"
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.expand_icon = true
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(UiTheme.height("tile") * UiTheme.number("command_aspect"), UiTheme.height("tile"))
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	if badge >= 0:
		var count := Label.new()
		count.name = "Badge"
		count.theme_type_variation = &"CardNumberLabel"
		count.text = str(badge)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		var inset: Vector2i = UiTheme.card_inset()
		count.offset_right = -inset.x
		count.offset_top = inset.y
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		btn.add_child(count)
	return btn

## Appears rather than blinks on: a quick fade and a little growth (UI-POLISH T10, T14).
static func pop_in(node: Control) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * UiTheme.number("pop_scale")
	var tw := node.create_tween().set_parallel(true)
	var t: float = UiTheme.number("pop_seconds")
	tw.tween_property(node, "modulate:a", 1.0, t)
	tw.tween_property(node, "scale", Vector2.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A command just become his, into the corner (HeroCommands): it grows in, lit (THEME tints "come"),
## and the light fades over "come_seconds" -- seen as it arrives, where it had only been there the
## next time one looked (the debug-agent's TASK-024: "新按钮出现时注意得到吗：不太注意得到").
static func come_in(node: Control) -> void:
	if node == null or not node.is_inside_tree():
		return
	var at: Vector2 = node.size if node.size.x > 0.0 else node.get_combined_minimum_size()
	node.pivot_offset = at * 0.5
	var small: Vector2 = Vector2.ONE * UiTheme.number("come_scale")
	# After its container has laid it out, not before: a container sets its children's scale back to
	# one as it lays them out, and it grew in from its full size (the debug-agent's BUG-024). The
	# tween starts from the small size, whatever the scale is when it takes its first step.
	node.set_deferred("scale", small)
	node.modulate = UiTheme.tint("come")
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, UiTheme.number("pop_seconds") * 2.0).from(small) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate", Color.WHITE, UiTheme.number("come_seconds")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## A key as the engine's shortcut for a button (BaseButton.shortcut): the key presses it, and
## it flashes as though clicked -- and does nothing while it cannot be pressed or is hidden. The
## key is on the button already (keycap), so it is not added to the tooltip as well.
static func key_shortcut(btn: Button, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	var s := Shortcut.new()
	s.events = [ev]
	btn.shortcut = s
	btn.shortcut_in_tooltip = false

## The key that presses a command, on a chip in its corner (KeycapLabel): top left on a tile,
## whose badge is top right; on a card, at the end of its price row -- the row gives way to it,
## so a long name keeps the width it had and the lock of a card not yet affordable stands just
## before it; at the right end of a plain command. Sized by what it says: its offsets meet,
## and it grows away from the corner to fit.
static func keycap(btn: Button, key_text: String) -> Label:
	var cap: Label = btn.get_node_or_null("Keycap") as Label
	if cap == null:
		cap = Label.new()
		cap.name = "Keycap"
		cap.theme_type_variation = &"KeycapLabel"
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cap)
	cap.text = key_text
	var inset: Vector2i = UiTheme.card_inset()
	var row: Control = btn.get_node_or_null("PriceRow") as Control
	match btn.theme_type_variation:
		&"TileButton":
			cap.set_anchors_preset(Control.PRESET_TOP_LEFT)
			cap.grow_horizontal = Control.GROW_DIRECTION_END
			cap.grow_vertical = Control.GROW_DIRECTION_END
			cap.offset_left = inset.x
			cap.offset_right = inset.x
			cap.offset_top = inset.y
			cap.offset_bottom = inset.y
		&"CardButton":
			cap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			cap.grow_vertical = Control.GROW_DIRECTION_BOTH
			cap.offset_right = -inset.x
			cap.offset_left = -inset.x
			cap.offset_top = row.offset_top if row else -float(inset.y)
			cap.offset_bottom = row.offset_bottom if row else -float(inset.y)
			if row:
				row.offset_right = -inset.x - cap.get_combined_minimum_size().x - UiTheme.space("xs")
		_:
			cap.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			cap.grow_vertical = Control.GROW_DIRECTION_BOTH
			cap.offset_right = -inset.x
			cap.offset_left = -inset.x
			cap.offset_top = 0.0
			cap.offset_bottom = 0.0
	return cap

## The row along a card's foot (card_button) as one line of words instead of prices: what a
## meal does, where a building says what it costs.
static func fill_caption_row(btn: Button, text: String) -> void:
	var row: HBoxContainer = btn.get_node_or_null("PriceRow")
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var t := Label.new()
	t.theme_type_variation = &"CardCaptionLabel"
	t.text = text
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(t)

## A plain command: its icon before its word, full width, one height.
static func action_button(text: String, icon: Texture2D, callback: Callable, variation: StringName = &"") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.theme_type_variation = variation
	btn.custom_minimum_size = Vector2(0, UiTheme.height("command"))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.pressed.connect(callback)
	return btn

## "7 / 10": what is left of a whole -- health, a node's reserve. Rounded up, so a sliver
## of health left never reads as none.
static func fraction_text(current: float, whole: float) -> String:
	return "%d / %d" % [int(ceil(current)), int(ceil(whole))]

## "Upgrading  40%": the words on a work bar -- what the work is, and how far along.
static func work_text(label: String, ratio: float) -> String:
	return "%s  %d%%" % [label, int(clampf(ratio, 0.0, 1.0) * 100.0)]

## "12s": how long a job keeps him at the bench, for the card's price row.
static func seconds_text(seconds: float) -> String:
	return TranslationServer.translate("TIME_SECONDS") % int(round(seconds))

## A job's icon: a meal is its meat, a beacon step is the beacon, a tool is what it works on,
## anything else is the bench's own.
static func job_icon(station: Node, job_id: String) -> Texture2D:
	# A dish is drawn as it comes out, cooked (Config.dish_icon): what goes in is its price row.
	if station.has_method("is_dish") and station.is_dish(job_id):
		var cfg_dish = _config()
		if cfg_dish and cfg_dish.has_method("dish_icon"):
			return UiTheme.icon(String(cfg_dish.dish_icon(job_id)))
		for res_id in station.inputs_of(job_id):
			return UiTheme.icon(String(res_id))
	if station.has_method("is_beacon_job") and station.is_beacon_job(job_id):
		return UiTheme.icon("beacon")
	var cfg = _config()
	if cfg and "RECIPES" in cfg and cfg.RECIPES.has(job_id):
		# A tool drawn for itself is shown as itself -- the icon it has in his ability slots.
		var own: Texture2D = UiTheme.icon(job_id)
		if own != null:
			return own
		var speeds: Dictionary = cfg.RECIPES[job_id].get("harvest_speed", {})
		for res_id in speeds:
			return UiTheme.icon(String(res_id))
		if cfg.has_method("harvest_requires_unlock"):
			for res_id in cfg.RESOURCE_NODES:
				if String(cfg.harvest_requires_unlock(String(res_id))) == String(cfg.RECIPES[job_id].get("unlocks", "")):
					return UiTheme.icon(String(res_id))
		for method in cfg.COOKING_METHODS:
			if String(method.get("vessel", "")) == String(cfg.RECIPES[job_id].get("unlocks", "")):
				return UiTheme.icon("kitchen")
	return UiTheme.icon(String(station.station_id)) if "station_id" in station else null

## What a job at a bench costs, takes and does, for whichever entry the cursor is over: the
## same shape as the build menu's line, because it answers the same question. Returns
## [text, tone], tone being "" (plain), "short" (cannot be paid) or "warn" (the launch).
static func job_detail(station: Node, job_id: String) -> Array:
	var costs: PackedStringArray = []
	for res_id in station.inputs_of(job_id):
		costs.append("%d %s" % [int(station.inputs_of(job_id)[res_id]), TranslationServer.translate("RESOURCE_%s" % String(res_id).to_upper())])
	var cost_text: String = ", ".join(costs)
	var cfg = _config()
	var is_meal: bool = station.has_method("is_dish") and station.is_dish(job_id)
	if cfg and "BEACON_LAUNCH" in cfg and job_id == String(cfg.BEACON_LAUNCH):
		# The launch costs nothing; what it asks for is nerve, so it says what is coming.
		return [launch_detail(), "warn"]
	if is_meal and station.can_afford(job_id) and cfg and cfg.has_method("describe_meal"):
		return [TranslationServer.translate("MEAL_DETAIL_FORMAT") % [station.recipe_name(job_id), cost_text,
			station.time_of(job_id), cfg.describe_meal(station.meal_preview(job_id))], ""]
	if station.can_afford(job_id):
		return [TranslationServer.translate("CRAFT_DETAIL_FORMAT") % [station.recipe_name(job_id), cost_text, station.time_of(job_id)], ""]
	return [TranslationServer.translate("CRAFT_DETAIL_UNAFFORDABLE") % [station.recipe_name(job_id), cost_text]
		+ sources_text(station.inputs_of(job_id)), "short"]

## What launching the beacon brings: how long it charges, that the whole valley comes from
## every side, and who comes last (GAME-DESIGN 8.3).
static func launch_detail() -> String:
	var cfg = _config()
	var gs = _state()
	var map: Dictionary = gs.map_data() if (gs and gs.has_method("map_data")) else {}
	var seconds: int = int(round(float(map.get("beacon", {}).get("charge_seconds", 0.0))))
	var boss: String = String(map.get("boss", ""))
	var boss_name: String = String(cfg.get_dino_name(boss)) if (cfg and boss != "") else ""
	return TranslationServer.translate("BEACON_LAUNCH_DETAIL") % [seconds / 60, seconds % 60, boss_name]

## One line per material in `price` he is short of and cannot simply go and pick up:
## which tool it takes, or that only the dead leave it (Config.source_hint) -- the reason
## chain, "stone <- bone pick <- 1 bone", said where the price is (GAME-DESIGN 9.2).
static func sources_text(price: Dictionary) -> String:
	var cfg = _config()
	var gs = _state()
	if cfg == null or gs == null or not cfg.has_method("source_hint"):
		return ""
	var lines: String = ""
	for res_id in price:
		if int(gs.resources.get(res_id, 0)) >= int(price[res_id]):
			continue
		var hint: String = String(cfg.source_hint(String(res_id), gs.unlocks, gs.knows if gs.has_method("knows") else Callable()))
		if hint != "":
			lines += "\n" + hint
	return lines

## The tint a detail line takes for its tone.
static func tone_color(tone: String) -> Color:
	match tone:
		"short":
			return UiTheme.color("danger_text")
		"warn":
			return UiTheme.color("warning")
	return Color.WHITE

static func _config() -> Node:
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

static func _state() -> Node:
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
