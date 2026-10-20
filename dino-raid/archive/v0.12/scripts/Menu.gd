class_name Menu
extends CanvasLayer
## The game's own screens, over everything (GAME-DESIGN 21), in the one look (Style): the title -- the game's name
## over the homeland at dusk, a short list to pick from -- the pause menu, the codex, the settings, and asking before a
## run is thrown away. Each shows, waits, and says what was picked; Game decides what follows.

signal _picked(what: String)
signal _settings_closed
signal _codex_closed

const VERSION := "v0.12"
const NAME := "DINO RAID"
const SUBTITLE := "基因方舟　·　异星虫群"

var game: Game
var screen := ""                  # what is up: "title", "pause", "" (for Game and the tools)
var _root: Control
var _screen: Control
var _settings: Control
var _confirm: Control
var _codex: Control
var _fade: ColorRect

static var _logo_shader: Shader


func setup(p_game: Game) -> void:
	game = p_game
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Style.theme()
	add_child(_root)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		return
	if _confirm != null:
		_picked.emit("no")
	elif _codex != null:
		_codex_closed.emit()
	elif _settings != null:
		_settings_closed.emit()
	elif screen == "pause":
		_picked.emit("resume")
	else:
		return
	get_viewport().set_input_as_handled()


# -- Screens ---------------------------------------------------------------------------------------------------

## The title: the name over the land, then what to do -- "new" or "quit" (the settings open and close in place).
func title() -> String:
	var s := _open("title")
	s.add_child(_veil(_vignette()))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(col)
	col.add_child(_gap(64))
	var logo := VBoxContainer.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.add_theme_constant_override("separation", 4)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(logo)
	logo.add_child(_ornament(380))
	logo.add_child(_logo(NAME))
	var sub := Style.label(SUBTITLE, 25, 700, Style.PARCHMENT)
	sub.add_theme_font_override("font", _spaced(Fonts.serif(700), 4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(sub)
	logo.add_child(_gap(6))
	logo.add_child(_ornament(560))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	var list := _list([["开始新的一局", "new"], ["图鉴", "codex"], ["设置", "settings"], ["退出游戏", "quit"]], 26)
	col.add_child(list)
	col.add_child(_gap(72))
	var v := Style.label(VERSION, 15, 600, Style.PARCHMENT_DIM)
	v.add_theme_font_override("font", Fonts.display())
	s.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	# In from the dark: the land, the name, then the list.
	logo.modulate.a = 0.0
	list.modulate.a = 0.0
	var tw := s.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(logo, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(list, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _focus_first(list))
	while true:
		var what: String = await _picked
		if what == "settings":
			await settings()
			_focus_first(list)
			continue
		if what == "codex":
			await codex()
			_focus_first(list)
			continue
		if what == "quit" and not await confirm("退出游戏？"):
			_focus_first(list)
			continue
		_close()
		return what
	return ""


## The pause menu over the game, the game stopped under it: "resume", "restart", "menu" or "quit" -- the last three
## asked again, as they throw the run away.
func pause() -> String:
	var s := _open("pause")
	s.add_child(_veil(_blur()))
	var box := _panel_box(s, "暂停")
	var list := _list([["继续", "resume"], ["图鉴", "codex"], ["设置", "settings"], ["重新开始这一局", "restart"],
		["回主菜单", "menu"], ["退出游戏", "quit"]], 22)
	box.add_child(list)
	_focus_first(list)
	while true:
		var what: String = await _picked
		match what:
			"settings":
				await settings()
				_focus_first(list)
				continue
			"codex":
				await codex()
				_focus_first(list)
				continue
			"restart", "menu", "quit":
				var ask: String = {"restart": "重新开始？这一局就不要了", "menu": "回主菜单？这一局就不要了",
					"quit": "退出游戏？这一局就不要了"}[what]
				if not await confirm(ask):
					_focus_first(list)
					continue
		_close()
		return what
	return ""


## The settings, over whatever is up, until closed (kept as they are changed).
func settings() -> void:
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_settings)
	_settings.add_child(_veil(_blur()))
	var box := _panel_box(_settings, "设置")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	_setting_row(grid, "全屏", _pair(Settings.fullscreen, func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply()))
	var volume := HBoxContainer.new()
	volume.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.volume
	slider.custom_minimum_size = Vector2(220, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var said := Style.label("%d" % Settings.volume, 17, 700, Style.GOLD_BRIGHT)
	said.custom_minimum_size = Vector2(40, 0)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.volume = int(v)
		said.text = "%d" % int(v)
		Settings.apply())
	volume.add_child(slider)
	volume.add_child(said)
	_setting_row(grid, "音量", volume)
	_setting_row(grid, "按钮声", _pair(Settings.clicks, func(on: bool) -> void: Settings.clicks = on))
	_setting_row(grid, "开战就快进", _pair(Settings.fast, func(on: bool) -> void:
		Settings.fast = on
		if game != null:
			game.speed = 3.0 if on else 1.0))
	box.add_child(_gap(6))
	var back := Button.new()
	back.text = "返回"
	back.theme_type_variation = "Primary"
	back.custom_minimum_size = Vector2(180, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: _settings_closed.emit())
	box.add_child(back)
	back.grab_focus()
	await _settings_closed
	Settings.save()
	_settings.queue_free()
	_settings = null


## Asked before something that cannot be undone: whether it is meant.
func confirm(text: String) -> bool:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_confirm)
	_confirm.add_child(_veil(_blur()))
	var box := _panel_box(_confirm, "")
	var l := Style.label(text, 21, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	var no := Button.new()
	no.text = "算了"
	no.custom_minimum_size = Vector2(150, 46)
	no.pressed.connect(func() -> void: _picked.emit("no"))
	var yes := Button.new()
	yes.text = "确定"
	yes.theme_type_variation = "Primary"
	yes.custom_minimum_size = Vector2(150, 46)
	yes.pressed.connect(func() -> void: _picked.emit("yes"))
	row.add_child(no)
	row.add_child(yes)
	no.grab_focus()
	var what: String = await _picked
	_confirm.queue_free()
	_confirm = null
	return what == "yes"


## The screen going dark, or light again.
func fade(dark: bool, time := 0.8) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if dark else Control.MOUSE_FILTER_IGNORE
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0 if dark else 0.0, time)
	await tw.finished


func black() -> void:
	_fade.modulate.a = 1.0


# -- Pieces ----------------------------------------------------------------------------------------------------

func _open(what: String) -> Control:
	_close()
	screen = what
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_screen)
	return _screen


func _close() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	screen = ""


## A list of lines to pick ([words, what]) in the title's way: lit when pointed at or chosen with the keys.
func _list(items: Array, size_px: int) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_theme_constant_override("separation", 6)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.theme_type_variation = "Choice"
		b.add_theme_font_size_override("font_size", size_px)
		b.custom_minimum_size = Vector2(size_px * 14, size_px * 2.1)
		b.focus_mode = Control.FOCUS_ALL
		var what: String = item[1]
		b.pressed.connect(func() -> void: _picked.emit(what))
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		# Lit while it is the one chosen, by the pointer or the keys -- drawn as its own look, so it shows either way.
		b.focus_entered.connect(func() -> void: b.add_theme_stylebox_override("normal", Style.theme().get_stylebox("hover", "Choice")))
		b.focus_exited.connect(func() -> void: b.remove_theme_stylebox_override("normal"))
		list.add_child(b)
	return list


func _focus_first(list: Control) -> void:
	if is_instance_valid(list) and list.get_child_count() > 0:
		(list.get_child(0) as Control).grab_focus()


## A panel in the middle of `under`, crested, its heading on top (none for ""): the box to fill.
func _panel_box(under: Control, heading: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	under.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(30.0, true))
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	if heading != "":
		var h := Style.heading(heading, 30)
		h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(h)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	var tw := panel.create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return box


func _setting_row(grid: GridContainer, name: String, control: Control) -> void:
	var l := Style.label(name, 19, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	grid.add_child(control)


## Two buttons, 开 and 关, one lit: `on` the first time, then whichever was pressed (said to `changed`).
func _pair(on: bool, changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for pair in [["开", true], ["关", false]]:
		var b := Button.new()
		b.text = pair[0]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "Toggle"
		b.custom_minimum_size = Vector2(76, 40)
		b.button_pressed = pair[1] == on
		var value: bool = pair[1]
		b.pressed.connect(func() -> void: changed.call(value))
		row.add_child(b)
	return row


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A gold rule with diamonds, `width` across.
func _ornament(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 14)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Style.rule(c, Vector2(c.size.x * 0.5, 7), c.size.x, Style.GOLD))
	return c


## The game's name: wide-set capitals in old gold, a light sweeping over them now and then, a shadow under them.
func _logo(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _spaced(Fonts.display(), 16))
	l.add_theme_font_size_override("font_size", 96)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_constant_override("shadow_outline_size", 10)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _logo_shader == null:
		_logo_shader = Shader.new()
		_logo_shader.code = """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.0, 0.96, 0.8, 1.0);
uniform vec4 low_col : source_color = vec4(0.78, 0.55, 0.24, 1.0);
uniform vec2 extent = vec2(900.0, 130.0);
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (COLOR.r < 0.5) {
		COLOR = vec4(COLOR.rgb, COLOR.a * tex.a);
	} else {
		float t = clamp((local.y - extent.y * 0.22) / (extent.y * 0.62), 0.0, 1.0);
		vec3 col = mix(top_col.rgb, low_col.rgb, t);
		float sweep = mod(TIME * 0.11, 1.0) * 2.2 - 0.6;
		float d = abs(local.x / extent.x - sweep + (local.y / extent.y) * 0.18);
		col += vec3(1.0, 0.95, 0.8) * smoothstep(0.07, 0.0, d) * 0.5;
		COLOR = vec4(col, tex.a * COLOR.a);
	}
}
"""
	var m := ShaderMaterial.new()
	m.shader = _logo_shader
	l.material = m
	l.resized.connect(func() -> void: m.set_shader_parameter("extent", l.size))
	return l


## A face set wider apart.
func _spaced(base: Font, px: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = px
	return fv


## Over all of the screen, drawing with `shader`.
func _veil(shader: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## The land darkened at the edges, and more at the foot where the list is -- the title's frame.
func _vignette() -> Shader:
	return Style.vignette_shader()


## What is behind, blurred and darkened -- under a panel.
func _blur() -> Shader:
	return Style.blur_shader()


# -- The codex -------------------------------------------------------------------------------------------------

## The codex: all there is, by kind -- our creatures, nests and buildings, gene affixes, relics, the monsters, the
## wonders -- each with its picture taken from the model, what it is, and its numbers. Pointed at or clicked, an entry
## is shown large beside the shelf. Until closed.
func codex() -> void:
	_codex = Control.new()
	_codex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_codex)
	_codex.add_child(_veil(_blur()))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	_codex.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var head := Style.heading("图鉴", 34)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.custom_minimum_size = Vector2(176, 0)
	body.add_child(tabs)
	var shelf := PanelContainer.new()
	shelf.add_theme_stylebox_override("panel", Style.panel(14.0))
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", Style.panel(20.0, true))
	detail.custom_minimum_size = Vector2(380, 0)
	body.add_child(detail)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 8)
	detail.add_child(dbox)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(336, 206)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dbox.add_child(pic)
	var medal := Control.new()
	medal.custom_minimum_size = Vector2(336, 206)
	medal.visible = false
	dbox.add_child(medal)
	var title := Style.label("", 28, 900, Style.GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dbox.add_child(title)
	var kind := Style.label("", 15, 700, Style.PARCHMENT_DIM)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dbox.add_child(kind)
	var line := _ornament(300)
	dbox.add_child(line)
	var text := Style.label("", 16, 500, Style.PARCHMENT)
	text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text.custom_minimum_size = Vector2(336, 0)
	text.add_theme_constant_override("line_spacing", 6)
	dbox.add_child(text)
	var shown := {"entry": {}}
	var show := func(e: Dictionary) -> void:
		shown.entry = e
		title.text = e.name
		kind.text = e.kind
		text.text = e.text
		medal.visible = e.has("medal")
		pic.visible = not e.has("medal")
		pic.texture = null
		if e.has("medal"):
			medal.set_meta("medal", e.medal)
			medal.queue_redraw()
		else:
			pic.texture = Portraits.picture(e.key, func(t: Texture2D) -> void:
				if is_instance_valid(pic) and shown.entry == e:
					pic.texture = t)
	medal.draw.connect(func() -> void: _medal(medal, medal.get_meta("medal", {}), 78.0))
	var pages := [["我们的兵", _units_page()], ["巢和建筑", _buildings_page()], ["基因词条", _affixes_page()],
		["遗物", _relics_page()], ["怪物", _monsters_page()], ["奇观", _wonders_page()]]
	var tab_buttons: Array = []
	var open_page := func(k: int) -> void:
		for ch in grid.get_children():
			ch.queue_free()
		for i in tab_buttons.size():
			var tb: Button = tab_buttons[i]
			if i == k:
				tb.add_theme_stylebox_override("normal", Style.theme().get_stylebox("hover", "Choice"))
			else:
				tb.remove_theme_stylebox_override("normal")
		for e in pages[k][1]:
			grid.add_child(_codex_tile(e, show))
		scroll.scroll_vertical = 0
		if not pages[k][1].is_empty():
			show.call(pages[k][1][0])
	for k in pages.size():
		var tb := Button.new()
		tb.text = pages[k][0]
		tb.theme_type_variation = "Choice"
		tb.add_theme_font_size_override("font_size", 20)
		tb.custom_minimum_size = Vector2(176, 48)
		tb.focus_mode = Control.FOCUS_NONE
		var page := k
		tb.pressed.connect(func() -> void: open_page.call(page))
		tabs.add_child(tb)
		tab_buttons.append(tb)
	var back := Button.new()
	back.text = "返回"
	back.theme_type_variation = "Primary"
	back.custom_minimum_size = Vector2(190, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: _codex_closed.emit())
	col.add_child(back)
	open_page.call(0)
	back.grab_focus()
	await _codex_closed
	_codex.queue_free()
	_codex = null


## An entry on the codex's shelf: its picture and its name -- pointed at or clicked, shown large.
func _codex_tile(e: Dictionary, show: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(134, 118)
	b.focus_mode = Control.FOCUS_NONE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 8
	col.offset_bottom = -6
	if e.has("medal"):
		var m := Control.new()
		m.custom_minimum_size = Vector2(0, 76)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.draw.connect(func() -> void: _medal(m, e.medal, 30.0))
		col.add_child(m)
	else:
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(0, 76)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture = Portraits.picture(e.key, func(tex: Texture2D) -> void:
			if is_instance_valid(t):
				t.texture = tex)
		col.add_child(t)
	var l := Style.label(e.name, 15, 800, Style.PARCHMENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	b.mouse_entered.connect(func() -> void: show.call(e))
	b.pressed.connect(func() -> void: show.call(e))
	return b


## A relic's medallion, `r` across its middle: a dark rim ringed in gold (coral for a boss's), the fossil's colour, its
## first word.
func _medal(c: Control, m: Dictionary, r: float) -> void:
	if m.is_empty():
		return
	var at := c.size * 0.5
	c.draw_circle(at + Vector2(0, r * 0.08), r * 1.08, Color(0, 0, 0, 0.45))
	c.draw_circle(at, r * 1.06, Style.INK_DEEP)
	c.draw_arc(at, r * 0.98, 0.0, TAU, 64, Style.CORAL if m.boss else Style.GOLD, maxf(2.0, r * 0.07), true)
	c.draw_circle(at, r * 0.8, (m.color as Color).darkened(0.12))
	c.draw_circle(at + Vector2(-r * 0.2, -r * 0.25), r * 0.3, Color(1, 1, 1, 0.14))
	var f := Fonts.serif(900)
	var px := int(r * 0.9)
	var w := f.get_string_size(m.word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	c.draw_string(f, at + Vector2(-w * 0.5, px * 0.36), m.word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Style.INK_DEEP)


# -- The codex's pages: entries {key (Portraits) or medal, name, kind, text} ------------------------------------

func _units_page() -> Array:
	var out: Array = []
	for kind in Content.UNITS:
		var u: Dictionary = Content.UNITS[kind]
		var from := ""
		var gift := ""
		for b in Content.BUILDINGS:
			if Content.BUILDINGS[b].get("nest", "") == kind:
				from = "%s孵的" % Content.BUILDINGS[b].name
				var t: Dictionary = Content.TRAITS[Content.BUILDINGS[b].trait]
				gift = "\n巢的本事「%s」：%s%s" % [t.name, t.does, ("（%s）" % t.when) if t.when != "" else ""]
		for r in Content.RECIPES:
			if r.makes == kind:
				from = "进化来的：%s + %s" % [Content.AFFIXES[r.affixes[0]].name, Content.AFFIXES[r.affixes[1]].name]
		if kind == "titan":
			from = "奇观巨兽笼放出来的"
		out.append({"key": "u:" + kind, "name": u.name, "kind": from, "text": "%s\n%s\n%s%s" % [u.role, _stats(u),
			"不吃生物质" if int(u.food) == 0 else "每只吃 %d 生物质" % u.food, gift]})
	return out


func _buildings_page() -> Array:
	var out: Array = []
	for kind in Content.BUILDINGS:
		var b: Dictionary = Content.BUILDINGS[kind]
		var where := "巢 · 阵地" if b.has("nest") else "后方"
		if b.has("school"):
			where += " · " + Content.SCHOOLS[b.school].name
		if b.has("region"):
			where += " · 只在" + Content.LEVELS[int(b.region)].name
		var text := ""
		if b.has("nest"):
			var t: Dictionary = Content.TRAITS[b.trait]
			text = "孵%s。\n本事「%s」：%s%s\n升级：多孵 1 只，或者变精英" % [Content.UNITS[b.nest].name, t.name, t.does,
				("（%s）" % t.when) if t.when != "" else ""]
		else:
			var lines: Array = []
			for lv in range(1, Content.LEVEL_MAX + 1):
				lines.append("%d 级：%s" % [lv, Content.building_text(kind, lv)])
			text = "\n".join(lines)
		out.append({"key": "b:%s:1::" % kind, "name": b.name, "kind": "%s · %d 金" % [where, int(b.cost)], "text": text})
	return out


func _affixes_page() -> Array:
	var out: Array = []
	for a in Content.AFFIXES:
		var af: Dictionary = Content.AFFIXES[a]
		var with: Array = []
		for r in Content.RECIPES:
			if a in r.affixes:
				var other: String = r.affixes[1] if r.affixes[0] == a else r.affixes[0]
				with.append("和%s凑在一个巢上：进化成%s" % [Content.AFFIXES[other].name, Content.UNITS[r.makes].name])
		var offer: Dictionary = Content.OFFERS.get("a_" + a, {})
		var cost := "%d 金 · %d 基因%s" % [int(offer.get("price", 0)), int(offer.get("genes", 0)),
			(" · %d 外星基因" % int(offer.alien)) if offer.has("alien") else ""]
		out.append({"key": "a:" + a, "name": af.name, "kind": "基因词条 · " + cost, "text": "贴上的巢，孵的兵%s。%s" % [af.says,
			("\n" + "\n".join(with)) if not with.is_empty() else ""]})
	return out


func _relics_page() -> Array:
	var out: Array = []
	for id in Content.RELICS:
		var r: Dictionary = Content.RELICS[id]
		var boss: bool = r.get("boss", false)
		out.append({"medal": {"color": r.color, "boss": boss, "word": r.name.left(1)}, "name": r.name,
			"kind": "首领遗物：很强，但有代价" if boss else "化石遗物", "text": r.says.replace("；", "\n")})
	return out


func _monsters_page() -> Array:
	var out: Array = []
	for kind in Content.ENEMIES:
		var m: Dictionary = Content.ENEMIES[kind]
		var where: Array = []
		for lv in Content.LEVELS:
			if lv.get("boss", "") == kind:
				where.append("%s的首领" % lv.name)
			for mix in lv.mix:
				if mix[0] == kind:
					where.append(lv.name)
		for other in Content.ENEMIES:
			if Content.ENEMIES[other].get("split", "") == kind:
				where.append("%s倒下时裂出来" % Content.ENEMIES[other].name)
		var more: Array = [_stats(m)]
		if m.has("split"):
			more.append("倒下时裂成 %d 只%s" % [int(m.splits), Content.ENEMIES[m.split].name])
		more.append("打输时，每只还站着的让家园掉 %d 血" % int(m.harm))
		out.append({"key": "e:" + kind, "name": m.name, "kind": "、".join(where) if not where.is_empty() else "异星虫群",
			"text": "\n".join(more)})
	return out


func _wonders_page() -> Array:
	var out: Array = []
	for id in Content.WONDERS:
		var w: Dictionary = Content.WONDERS[id]
		out.append({"key": "w:" + id, "name": w.name, "kind": "奇观 · %d 金 · 一局只能造一座" % int(w.price), "text": w.says})
	return out


## A fighter's numbers, said plainly.
func _stats(s: Dictionary) -> String:
	var bits: Array = ["血 %d" % int(s.hp), "攻击 %d" % int(s.atk), "%s 秒打一下" % _n(float(s.every)),
		"够得着 %s 米" % _n(float(s.range))]
	if int(s.get("armor", 0)) > 0:
		bits.append("护甲 %d" % int(s.armor))
	if float(s.get("splash", 0.0)) > 0.0:
		bits.append("一打一片（%s 米）" % _n(float(s.splash)))
	if int(s.get("heal", 0)) > 0:
		bits.append("每下回血 %d" % int(s.heal))
	if int(s.get("pierce", 0)) > 0:
		bits.append("每下多 %d，不管护甲" % int(s.pierce))
	if int(s.get("burst", 0)) > 0:
		bits.append("倒下时炸一圈（%d）" % int(s.burst))
	if s.get("dive", false):
		bits.append("会飞，打后排")
	return " · ".join(bits)


func _n(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)
