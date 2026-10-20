class_name Hud
extends CanvasLayer
## What the player holds and sees over the battle (GAME-DESIGN 9): the hand of cards fanned at the bottom, the
## energy in an amber stone, the draw and discard piles, the button that ends the turn; the turn and the waves
## still to come along the top; what the cursor points at; and between levels, the cards to win, to upgrade and
## to take out. It shows; Battle decides.

const HAND_SCALE := 0.84
const HOVER_SCALE := 1.18

var battle: Battle
var _root: Control
var _hand: Control
var _cards: Array = []           # CardView, in hand order
var _hovered: CardView
var _energy: Control
var _draw: Label
var _discard: Label
var _end: Button
var _turn: Label
var _waves: HBoxContainer
var _level: Label
var _info: PanelContainer
var _info_text: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _overlay: Control


func setup(p_battle: Battle) -> void:
	battle = p_battle
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_hand = Control.new()
	_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hand)

	_energy = Control.new()
	_energy.custom_minimum_size = Vector2(120, 120)
	_energy.size = Vector2(120, 120)
	_energy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_energy.position = Vector2(22, -196)
	_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy.draw.connect(_draw_energy)
	_root.add_child(_energy)

	_draw = _pile("抽牌堆", Control.PRESET_BOTTOM_LEFT, Vector2(30, -62))
	_discard = _pile("弃牌堆", Control.PRESET_BOTTOM_RIGHT, Vector2(-112, -62))

	_end = Button.new()
	_end.text = "结束回合"
	_end.focus_mode = Control.FOCUS_NONE
	_end.add_theme_font_override("font", Fonts.serif(800))
	_end.add_theme_font_size_override("font_size", 24)
	_end.add_theme_color_override("font_color", Color(0.18, 0.11, 0.05))
	_end.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.02))
	_end.add_theme_color_override("font_disabled_color", Color(0.35, 0.3, 0.25))
	_end.add_theme_stylebox_override("normal", _plate(Color(0.95, 0.72, 0.34), Color(0.45, 0.28, 0.12)))
	_end.add_theme_stylebox_override("hover", _plate(Color(1.0, 0.8, 0.42), Color(0.55, 0.34, 0.14)))
	_end.add_theme_stylebox_override("pressed", _plate(Color(0.85, 0.62, 0.28), Color(0.45, 0.28, 0.12)))
	_end.add_theme_stylebox_override("disabled", _plate(Color(0.42, 0.38, 0.33), Color(0.25, 0.22, 0.2)))
	_end.custom_minimum_size = Vector2(188, 64)
	_end.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end.position = Vector2(-214, -150)
	_end.pressed.connect(func() -> void: battle.act(0, "end", {}))
	_root.add_child(_end)

	var corner := VBoxContainer.new()
	corner.position = Vector2(20, 12)
	corner.add_theme_constant_override("separation", 0)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(corner)
	_level = _label("", 17, Fonts.serif(700), Color(0.98, 0.92, 0.8))
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_level)
	_turn = _label("", 30, Fonts.serif(900), Color(1.0, 0.95, 0.85))
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_turn)

	var waves := VBoxContainer.new()
	waves.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	waves.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	waves.position = Vector2(-18, 12)
	waves.alignment = BoxContainer.ALIGNMENT_BEGIN
	waves.add_theme_constant_override("separation", 6)
	waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(waves)
	var heading := _label("机器人要来", 15, Fonts.serif(700), Color(0.75, 0.93, 1.0))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	waves.add_child(heading)
	_waves = HBoxContainer.new()
	_waves.alignment = BoxContainer.ALIGNMENT_END
	_waves.add_theme_constant_override("separation", 6)
	waves.add_child(_waves)

	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.065, 0.06, 0.88), Color(0.72, 0.55, 0.32), 12))
	_info.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_info.position = Vector2(18, -60)
	_info.custom_minimum_size = Vector2(260, 0)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_root.add_child(_info)
	_info_text = _label("", 15, Fonts.serif(500), Color(0.96, 0.92, 0.84))
	_info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_text.custom_minimum_size = Vector2(236, 0)
	_info.add_child(_info_text)

	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.position.y = -90
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_title = _label("", 34, Fonts.serif(900), Color(1.0, 0.95, 0.82))
	_banner.add_child(_banner_title)
	_banner_sub = _label("", 18, Fonts.serif(600), Color(0.95, 0.88, 0.75))
	_banner.add_child(_banner_sub)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)


func _process(_delta: float) -> void:
	_layout()
	var tip := ""
	if battle.planning and _hovered == null:
		tip = battle.describe(battle.hover)
	_info.visible = tip != ""
	if tip != "" and _info_text.text != tip:
		_info_text.text = tip
		_info.reset_size()


## The cards of `hand`, as cards (those already shown kept, so they do not jump).
func deal(hand: Array) -> void:
	var keep := {}
	for v in _cards:
		keep[v] = true
	var out: Array = []
	var free: Array = _cards.duplicate()
	for ci in hand:
		var found: CardView = null
		for v in free:
			if v.ci == ci:
				found = v
				break
		if found:
			free.erase(found)
			out.append(found)
		else:
			var v := CardView.new()
			_hand.add_child(v)
			v.setup(ci, battle.card_picture(ci.id))
			v.position = Vector2(60, _root.size.y)
			v.scale = Vector2.ONE * 0.3
			v.clicked.connect(_on_card)
			v.hovered.connect(_on_hover)
			out.append(v)
	for v in free:
		_fly_off(v, Vector2(_root.size.x - 90, _root.size.y))
	_cards = out
	refresh()


## The turn ends: what is left in hand goes to the discard pile.
func discard() -> void:
	for v in _cards:
		_fly_off(v, Vector2(_root.size.x - 90, _root.size.y))
	_cards = []
	_hovered = null
	refresh()


func _fly_off(v: CardView, to: Vector2) -> void:
	var tw := v.create_tween()
	tw.set_parallel()
	tw.tween_property(v, "position", to - v.pivot_offset, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(v, "scale", Vector2.ONE * 0.25, 0.3)
	tw.tween_property(v, "rotation", 0.6, 0.3)
	tw.chain().tween_callback(v.queue_free)


func refresh() -> void:
	var s: BattleState = battle.state
	for i in _cards.size():
		var v: CardView = _cards[i]
		var c := Rules.card(v.ci)
		v.set_state(s.energy >= int(c.cost) and battle.planning, battle.held == i)
	_draw.text = "%d" % s.draw.size()
	_discard.text = "%d" % s.discard.size()
	_end.disabled = not battle.planning
	_energy.queue_redraw()
	_turn.text = "第 %d 回合" % s.turn
	_level.text = "第 %d 关 · %s" % [s.level + 1, Rules.LEVELS[s.level].name]
	for ch in _waves.get_children():
		ch.queue_free()
	var shown := 0
	for t in range(s.turn + 1, s.turn + 8):
		var wave := Rules.wave(s.level, t)
		if wave.is_empty():
			continue
		_waves.add_child(_wave_chip(t - s.turn, wave))
		shown += 1
		if shown >= 3:
			break


func _wave_chip(after: int, wave: Array) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.1, 0.13, 0.88), Color(0.35, 0.85, 1.0, 0.8), 6))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	row.add_child(_label("下回合" if after == 1 else "%d 回合后" % after, 15, Fonts.serif(700), Color(0.75, 0.93, 1.0)))
	var counts := {}
	for k in wave:
		counts[k] = counts.get(k, 0) + 1
	for k in counts:
		var pic := TextureRect.new()
		pic.texture = battle.robot_picture(k)
		pic.custom_minimum_size = Vector2(30, 30)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(pic)
		row.add_child(_label("×%d" % counts[k], 17, Fonts.numbers(), Color(1, 1, 1)))
	return chip


## The cards fanned along the bottom; the one under the cursor lifted and larger, the one held raised.
func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var w := _root.size.x
	var h := _root.size.y
	var gap := 128.0
	for i in n:
		var v: CardView = _cards[i]
		var off := i - (n - 1) * 0.5
		var x := w * 0.5 + off * gap
		var y := h + 52.0 + absf(off) * absf(off) * 5.0
		var rot := deg_to_rad(off * 3.5)
		var k := HAND_SCALE
		if v == _hovered:
			y -= 96.0
			rot = 0.0
			k = HOVER_SCALE
		elif battle.held == i:
			y -= 40.0
			rot = 0.0
		var to := Vector2(x, y) - v.pivot_offset
		v.position = v.position.lerp(to, 0.3)
		v.rotation = lerpf(v.rotation, rot, 0.3)
		v.scale = v.scale.lerp(Vector2.ONE * k, 0.3)
		v.z_index = 10 if v == _hovered else i


func _on_card(v: CardView) -> void:
	var i := _cards.find(v)
	if i >= 0:
		battle.hold(i)
		refresh()


func _on_hover(v: CardView, on: bool) -> void:
	if on:
		_hovered = v
	elif _hovered == v:
		_hovered = null


## A word across the middle of the screen, fading.
func banner(title: String, sub := "") -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.1)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


# -- Between levels ----------------------------------------------------------------------------------------------

## The battle is over: on to the cards won, or back to the start.
func finish(won: bool) -> void:
	var run: RunState = battle.run
	if not won:
		_screen("恐龙蛋窝全被毁了……", "这一局到这里了", [], [["重新开始", func() -> void: _new_run()]])
		return
	if run.last_level():
		_screen("全部打通了！", "时光机一个不剩", [], [["再玩一遍", func() -> void: _new_run()]])
		return
	_pick_card()


func _pick_card() -> void:
	var run: RunState = battle.run
	var offer := run.offer()
	var cards: Array = []
	for id in offer:
		cards.append({"id": id, "up": false})
	_screen("过关了！", "挑一张新牌放进牌堆", cards, [["不要了", func() -> void: _upgrade()]], func(ci: Dictionary) -> void:
		run.deck.append(ci.duplicate())
		_upgrade())


func _upgrade() -> void:
	var run: RunState = battle.run
	var can: Array = run.deck.filter(func(ci: Dictionary) -> bool: return not ci.get("up", false))
	if can.is_empty():
		_remove()
		return
	_screen("升级一张牌", "点一张，它就变成 +", run.deck, [["不升级", func() -> void: _remove()]], func(ci: Dictionary) -> void:
		if not ci.get("up", false):
			ci.up = true
			_remove())


func _remove() -> void:
	var run: RunState = battle.run
	_screen("去掉一张牌？", "牌少了，好牌转得快。也可以不去", run.deck, [["不去掉", func() -> void: _next()]],
		func(ci: Dictionary) -> void:
			if run.deck.size() > 5:
				run.deck.erase(ci)
			_next())


func _next() -> void:
	battle.run.level += 1
	battle.get_tree().reload_current_scene()


func _new_run() -> void:
	RunState.current = null
	battle.get_tree().reload_current_scene()


## A screen over the battle: a title, cards to click (on_card), buttons.
func _screen(title: String, sub: String, cards: Array, buttons: Array, on_card := Callable()) -> void:
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.visible = true
	_hand.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.02, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_overlay.add_child(box)
	box.add_child(_label(title, 44, Fonts.serif(900), Color(1.0, 0.92, 0.72)))
	box.add_child(_label(sub, 19, Fonts.serif(600), Color(0.92, 0.86, 0.74)))
	if not cards.is_empty():
		var grid := GridContainer.new()
		grid.columns = mini(cards.size(), 7)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(grid)
		var k := 1.0 if cards.size() <= 3 else 0.72
		for ci in cards:
			var slot := Control.new()
			slot.custom_minimum_size = CardView.SIZE * k
			grid.add_child(slot)
			var v := CardView.new()
			slot.add_child(v)
			v.setup(ci, battle.card_picture(ci.id))
			v.pivot_offset = Vector2.ZERO
			v.scale = Vector2.ONE * k
			var upgrading := title.begins_with("升级")
			v.set_state(not (upgrading and ci.get("up", false)), false)
			if on_card.is_valid():
				v.clicked.connect(func(_v: CardView) -> void: on_card.call(ci))
			if upgrading and not ci.get("up", false):
				# Pointed at, it shows what it would become.
				v.hovered.connect(func(view: CardView, on: bool) -> void:
					view.ci = {"id": ci.id, "up": on}
					view.c = Rules.card(view.ci)
					view.queue_redraw())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for b in buttons:
		var button := Button.new()
		button.text = b[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(170, 52)
		button.add_theme_font_override("font", Fonts.serif(800))
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color(0.18, 0.11, 0.05))
		button.add_theme_stylebox_override("normal", _plate(Color(0.95, 0.72, 0.34), Color(0.45, 0.28, 0.12)))
		button.add_theme_stylebox_override("hover", _plate(Color(1.0, 0.8, 0.42), Color(0.55, 0.34, 0.14)))
		button.add_theme_stylebox_override("pressed", _plate(Color(0.85, 0.62, 0.28), Color(0.45, 0.28, 0.12)))
		button.pressed.connect(b[1])
		row.add_child(button)


# -- Pieces ------------------------------------------------------------------------------------------------------

## The energy: an amber stone, filled as far as there is energy, the number on it.
func _draw_energy() -> void:
	var s: BattleState = battle.state
	var c := Vector2(60, 60)
	_energy.draw_circle(c, 56.0, Color(0.06, 0.05, 0.04, 0.92))
	_energy.draw_arc(c, 56.0, 0.0, TAU, 48, Color(0.72, 0.53, 0.3), 3.0, true)
	var frac := float(s.energy) / Rules.ENERGY_MAX
	var fill := Color(1.0, 0.68, 0.22)
	_energy.draw_arc(c, 47.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, fill, 9.0, true)
	_energy.draw_circle(c, 38.0, Color(0.16, 0.1, 0.05))
	var f := Fonts.numbers()
	var text := "%d" % s.energy
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
	_energy.draw_string_outline(f, c + Vector2(-w * 0.5, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, 5, Color(0, 0, 0, 0.9))
	_energy.draw_string(f, c + Vector2(-w * 0.5, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, fill)
	var cap := "/ %d" % Rules.ENERGY_MAX
	var cw := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_energy.draw_string(f, c + Vector2(-cw * 0.5, 33), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.9, 0.7, 0.8))
	var lf := Fonts.serif(700)
	var lw := lf.get_string_size("力气", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_energy.draw_string_outline(lf, Vector2(60 - lw * 0.5, 128), "力气", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
	_energy.draw_string(lf, Vector2(60 - lw * 0.5, 128), "力气", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.9, 0.7))


## A pile of cards: a little stack and how many are in it.
func _pile(name: String, preset: int, at: Vector2) -> Label:
	var box := HBoxContainer.new()
	box.set_anchors_preset(preset)
	box.position = at
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(26, 34)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.draw.connect(func() -> void:
		for k in 3:
			var r := Rect2(Vector2(k * 2.0, 6.0 - k * 3.0), Vector2(20, 28))
			stack.draw_rect(r, Color(0.2, 0.15, 0.1))
			stack.draw_rect(r, Color(0.72, 0.53, 0.3), false, 1.5))
	box.add_child(stack)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	box.add_child(col)
	var count := _label("0", 22, Fonts.numbers(), Color(1, 0.95, 0.85))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(count)
	var label := _label(name, 12, Fonts.serif(600), Color(0.9, 0.82, 0.68))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(label)
	return count


func _label(text: String, size_px: int, f: Font, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size_px / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(bg: Color, edge: Color, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(pad)
	return sb


func _plate(face: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = edge
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(10)
	return sb
