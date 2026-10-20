class_name Hud
extends CanvasLayer
## What the player sees over the field: the cards in hand; the three cards on offer every so often, while the
## battle waits; what a nest or a building is doing, under the mouse. It shows; Battle decides.

const CARD := Vector2(112, 150)
const BIG := Vector2(180, 236)

var battle: Battle
var _hand: Array[Button] = []
var _bar: ProgressBar
var _panel: PanelContainer
var _title: Label
var _offers: Array[Button] = []
var _info: PanelContainer
var _info_text: Label
var _end: PanelContainer
var _end_label: Label
var _end_note: Label
var _chosen := -1            # with a full hand: the offer kept, waiting for the hand card it is to replace
var _shown_hand: Array = []
var _shown_offer: Array = []


func setup(p_battle: Battle) -> void:
	battle = p_battle
	process_mode = Node.PROCESS_MODE_ALWAYS  # the offer is chosen while the battle waits
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 12
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)

	var timer := HBoxContainer.new()
	timer.alignment = BoxContainer.ALIGNMENT_CENTER
	timer.add_theme_constant_override("separation", 8)
	bottom.add_child(timer)
	timer.add_child(_label("下次挑牌", 14))
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 12)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.max_value = 1.0
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.75, 0.4)
	_bar.add_theme_stylebox_override("fill", fill)
	timer.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(row)
	for i in Battle.HAND:
		var b := _card(CARD, 15, 11)
		b.toggle_mode = true
		var key := _label(str(i + 1), 11)
		key.position = Vector2(8, 4)
		key.modulate.a = 0.6
		b.add_child(key)
		b.pressed.connect(_on_hand.bind(i))
		row.add_child(b)
		_hand.append(b)

	# The offer: three cards in the middle of the screen, while the battle waits.
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), 0, 0.82, 22))
	_panel.visible = false
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_title = _label("", 22)
	box.add_child(_title)
	var three := HBoxContainer.new()
	three.alignment = BoxContainer.ALIGNMENT_CENTER
	three.add_theme_constant_override("separation", 16)
	box.add_child(three)
	for i in 3:
		var b := _card(BIG, 22, 15)
		b.toggle_mode = true
		var key := _label(str(i + 1), 13)
		key.position = Vector2(10, 6)
		key.modulate.a = 0.6
		b.add_child(key)
		b.pressed.connect(_on_offer.bind(i))
		three.add_child(b)
		_offers.append(b)
	var skip := Button.new()
	skip.text = "都不要"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 16)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void: battle.act(0, "choose", {"offer": -1}))
	box.add_child(skip)

	# What is under the mouse.
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), 0, 0.78, 10))
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	root.add_child(_info)
	_info_text = _label("", 15)
	_info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.add_child(_info_text)

	_end = PanelContainer.new()
	_end.set_anchors_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), 0, 0.82, 26))
	_end.visible = false
	root.add_child(_end)
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 14)
	_end.add_child(end_box)
	_end_label = _label("", 30)
	end_box.add_child(_end_label)
	_end_note = _label("", 17)
	end_box.add_child(_end_note)
	var again := Button.new()
	again.text = "再来一局"
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_size_override("font_size", 20)
	again.pressed.connect(func() -> void: battle.get_tree().reload_current_scene())
	end_box.add_child(again)


func _process(_delta: float) -> void:
	if _shown_hand != battle.hand:
		_shown_hand = battle.hand.duplicate()
		for i in _hand.size():
			_dress(_hand[i], battle.hand[i] if i < battle.hand.size() else "")
	var choosing := not battle.offer.is_empty()
	for i in _hand.size():
		var b := _hand[i]
		var held := i < battle.hand.size()
		b.disabled = not held or (choosing and _chosen < 0)
		b.set_pressed_no_signal(not choosing and battle.placing == i)
		b.modulate = Color(1.0, 0.72, 0.66) if choosing and _chosen >= 0 and held else Color.WHITE
	_bar.value = 1.0 - battle.offer_in() / Battle.OFFER_EVERY
	if not choosing:
		_panel.visible = false
		_chosen = -1
		return
	if not _panel.visible or _shown_offer != battle.offer:
		_shown_offer = battle.offer.duplicate()
		_chosen = -1
		for i in _offers.size():
			_dress(_offers[i], battle.offer[i])
		_panel.visible = true
		_info.visible = false
	for i in _offers.size():
		_offers[i].set_pressed_no_signal(i == _chosen)
	if battle.hand.size() < Battle.HAND:
		_title.text = "挑一张牌"
	elif _chosen < 0:
		_title.text = "手里满了：挑一张，再点下面一张手牌换掉"
	else:
		_title.text = "点下面一张手牌，换成「%s」" % Cards.ALL[battle.offer[_chosen]].name


func _unhandled_input(event: InputEvent) -> void:
	if battle.offer.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	if _chosen >= 0 and k >= KEY_1 and k < KEY_1 + Battle.HAND:
		_on_hand(k - KEY_1)
	elif k >= KEY_1 and k < KEY_1 + _offers.size():
		_on_offer(k - KEY_1)
	elif k == KEY_ESCAPE:
		_chosen = -1
	else:
		return
	get_viewport().set_input_as_handled()


func _on_hand(i: int) -> void:
	if not battle.offer.is_empty():
		if _chosen >= 0:
			battle.act(0, "choose", {"offer": _chosen, "replace": i})
		return
	battle.pick(i)


func _on_offer(i: int) -> void:
	if battle.hand.size() < Battle.HAND:
		battle.act(0, "choose", {"offer": i})
	else:
		_chosen = -1 if _chosen == i else i


## What a nest or building under the mouse is doing ("" for nothing there).
func show_info(text: String) -> void:
	if text == "" or not battle.offer.is_empty():
		_info.visible = false
		return
	if _info_text.text != text:
		_info_text.text = text
		_info.reset_size()
	var m := get_viewport().get_mouse_position() + Vector2(18, 18)
	var view := get_viewport().get_visible_rect().size
	_info.position = Vector2(minf(m.x, view.x - _info.size.x - 4), minf(m.y, view.y - _info.size.y - 4))
	_info.visible = true


func show_end(won: bool, note: String) -> void:
	_panel.visible = false
	_info.visible = false
	_end_label.text = "机器人基地被打爆了！" if won else "恐龙蛋窝全被毁了……"
	_end_note.text = note
	_end.visible = true


# -- Cards -------------------------------------------------------------------------------------------------

## A card: its picture (or a drawn mark for help), its name, and what it does.
func _card(size: Vector2, name_px: int, text_px: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_top = 8
	box.offset_right = -6
	box.offset_bottom = -6
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	b.add_child(box)
	var pic := TextureRect.new()
	pic.name = "Pic"
	pic.custom_minimum_size = Vector2(0, size.y * 0.48)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var mark := Emblem.new()
	mark.name = "Mark"
	mark.custom_minimum_size = Vector2(0, size.y * 0.48)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mark)
	var title := _label("", name_px)
	title.name = "Name"
	box.add_child(title)
	var text := _label("", text_px)
	text.name = "Text"
	text.modulate = Color(1, 1, 1, 0.82)
	box.add_child(text)
	_skin(b, Color(0.5, 0.5, 0.5))
	return b


func _dress(b: Button, card: String) -> void:
	var pic := b.get_node("Box/Pic") as TextureRect
	var mark := b.get_node("Box/Mark") as Emblem
	var title := b.get_node("Box/Name") as Label
	var text := b.get_node("Box/Text") as Label
	if card == "":
		pic.texture = null
		pic.visible = true
		mark.visible = false
		title.text = ""
		text.text = ""
		_skin(b, Color(0.4, 0.4, 0.4))
		return
	var c: Dictionary = Cards.ALL[card]
	var tex: Texture2D = battle.card_picture(card)
	pic.texture = tex
	pic.visible = tex != null
	mark.visible = tex == null
	mark.kind = card
	mark.queue_redraw()
	title.text = c.name
	text.text = c.text
	_skin(b, Cards.EDGE[c.type])


func _skin(b: Button, edge: Color) -> void:
	var lit := Color(1.0, 0.95, 0.7)
	b.add_theme_stylebox_override("normal", _box(edge, 2, 0.86))
	b.add_theme_stylebox_override("hover", _box(edge.lightened(0.25), 3, 0.92))
	b.add_theme_stylebox_override("pressed", _box(lit, 4, 0.95))
	b.add_theme_stylebox_override("hover_pressed", _box(lit, 4, 0.95))
	b.add_theme_stylebox_override("disabled", _box(edge.darkened(0.45), 2, 0.7))


func _box(edge: Color, width: int, alpha: float, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.08, alpha)
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(pad)
	return sb


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
