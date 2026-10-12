class_name Hud
extends CanvasLayer
## What the player holds and reads (GAME-DESIGN 12): the hand fanned along the bottom, the energy, the draw and
## discard piles, the button that sends the units out; the level, the round, the homeland's health and the yard at
## the top left; who comes this battle and the next, and how this battle will go as things stand, at the top
## right; what the cursor points at; a battle's count and clock; and the cards to win between battles. It shows;
## Game decides.

signal chosen(value: Variant)

const HAND_SCALE := 0.84
const HOVER_SCALE := 1.15
const WIN := Color(0.55, 1.0, 0.5)
const LOSE := Color(1.0, 0.48, 0.4)
const CREAM := Color(0.98, 0.93, 0.82)

var game: Game
var _root: Control
var _hand: Control
var _cards: Array = []           # CardView, in hand order
var _hovered: CardView
var _energy: Control
var _draw: Label
var _discard: Label
var _go: Button
var _title: Label
var _hp: Control
var _yard: Label
var _buffs: Label
var _waves: VBoxContainer
var _waves_for := ""
var _forecast: PanelContainer
var _fc_head: Label
var _fc_line: Label
var _fc_more: Label
var _info: PanelContainer
var _info_text: Label
var _hint: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _battle: PanelContainer
var _battle_text: Label
var _speed: Button
var _overlay: Control
var screen := ""                 # the title of the screen up between battles, "" when none (for tools)


func setup(p_game: Game) -> void:
	game = p_game
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: where we are, the homeland, the yard, this battle's buffs.
	var corner := VBoxContainer.new()
	corner.position = Vector2(18, 10)
	corner.add_theme_constant_override("separation", 4)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(corner)
	_title = _label("", 24, Fonts.serif(900), CREAM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_title)
	_hp = Control.new()
	_hp.custom_minimum_size = Vector2(250, 30)
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp.draw.connect(_draw_hp)
	corner.add_child(_hp)
	_yard = _label("", 16, Fonts.serif(700), Color(0.92, 0.86, 0.74))
	_yard.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_yard)
	_buffs = _label("", 16, Fonts.serif(700), Color(1.0, 0.8, 0.45))
	_buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_buffs)

	# Top right: who comes, and how it will go.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-18, 10)
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	_waves = VBoxContainer.new()
	_waves.add_theme_constant_override("separation", 6)
	_waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_waves)
	_forecast = PanelContainer.new()
	_forecast.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.065, 0.06, 0.9), Color(0.72, 0.55, 0.32), 10))
	_forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forecast.custom_minimum_size = Vector2(250, 0)
	right.add_child(_forecast)
	var fc := VBoxContainer.new()
	fc.add_theme_constant_override("separation", 2)
	_forecast.add_child(fc)
	_fc_head = _label("", 14, Fonts.serif(600), Color(0.9, 0.84, 0.72))
	_fc_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_head)
	_fc_line = _label("", 24, Fonts.serif(900), WIN)
	_fc_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_line)
	_fc_more = _label("", 14, Fonts.serif(600), Color(0.85, 0.8, 0.7))
	_fc_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_more)

	# Middle left: what the cursor points at.
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.065, 0.06, 0.9), Color(0.72, 0.55, 0.32), 12))
	_info.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_info.position = Vector2(18, -70)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_root.add_child(_info)
	_info_text = _label("", 15, Fonts.serif(500), Color(0.96, 0.92, 0.84))
	_info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_text.custom_minimum_size = Vector2(250, 0)
	_info.add_child(_info_text)

	# Bottom: the hand, the energy, the piles, the button.
	_hand = Control.new()
	_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hand)
	_energy = Control.new()
	_energy.custom_minimum_size = Vector2(120, 140)
	_energy.size = Vector2(120, 140)
	_energy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_energy.position = Vector2(22, -214)
	_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy.draw.connect(_draw_energy)
	_root.add_child(_energy)
	_draw = _pile("抽牌堆", Control.PRESET_BOTTOM_LEFT, Vector2(30, -62))
	_discard = _pile("弃牌堆", Control.PRESET_BOTTOM_RIGHT, Vector2(-112, -62))
	_go = _button("出战！", Vector2(188, 64), 26)
	_go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_go.position = Vector2(-214, -150)
	_go.pressed.connect(func() -> void: game.act("fight"))
	_root.add_child(_go)
	_hint = _label("", 17, Fonts.serif(700), Color(1.0, 0.93, 0.75))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position = Vector2(0, -236)
	_root.add_child(_hint)

	# A battle: the count and the clock, and the speed.
	_battle = PanelContainer.new()
	_battle.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.065, 0.06, 0.88), Color(0.72, 0.55, 0.32), 10))
	_battle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_battle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_battle.position = Vector2(0, 12)
	_battle.visible = false
	_root.add_child(_battle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_battle.add_child(row)
	_battle_text = _label("", 22, Fonts.serif(800), CREAM)
	row.add_child(_battle_text)
	_speed = _button("快进", Vector2(96, 40), 17)
	_speed.pressed.connect(func() -> void:
		game.speed = 3.0 if game.speed < 2.0 else 1.0
		_speed.text = "正常" if game.speed > 1.0 else "快进")
	row.add_child(_speed)

	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.position.y = -120
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_title = _label("", 40, Fonts.serif(900), Color(1.0, 0.95, 0.82))
	_banner.add_child(_banner_title)
	_banner_sub = _label("", 19, Fonts.serif(600), Color(0.95, 0.88, 0.75))
	_banner.add_child(_banner_sub)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)


func _process(_delta: float) -> void:
	_layout()
	var tip := game.describe() if _hovered == null and not _overlay.visible else ""
	_info.visible = tip != ""
	if tip != "" and _info_text.text != tip:
		_info_text.text = tip
		_info.reset_size()
	if _battle.visible and game.fight != null:
		var f: Fight = game.fight
		_battle_text.text = "我方 %d  对  敌方 %d   ·   还剩 %d 秒" % [f.alive("ours").size(), f.alive("theirs").size(),
			ceili(maxf(0.0, Fight.LIMIT - f.time))]


## The cards of `hand`, as cards (those already shown kept, so they do not jump).
func deal(hand: Array) -> void:
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
			v.setup(ci)
			v.position = Vector2(60, _root.size.y)
			v.scale = Vector2.ONE * 0.3
			v.clicked.connect(_on_card)
			v.hovered.connect(_on_hover)
			out.append(v)
	for v in free:
		_fly_off(v)
	_cards = out
	if _hovered and not _hovered in _cards:
		_hovered = null
	refresh()


## Everyone goes out: what is left in hand goes to the discard pile.
func send_off() -> void:
	for v in _cards:
		_fly_off(v)
	_cards = []
	_hovered = null
	refresh()


func _fly_off(v: CardView) -> void:
	var tw := v.create_tween()
	tw.set_parallel()
	tw.tween_property(v, "position", Vector2(_root.size.x - 90, _root.size.y) - v.pivot_offset, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(v, "scale", Vector2.ONE * 0.25, 0.3)
	tw.tween_property(v, "rotation", 0.6, 0.3)
	tw.chain().tween_callback(v.queue_free)


func refresh() -> void:
	var run: Run = game.run
	var home: Home = game.home
	var planning := game.phase == Game.Phase.PLAN
	var fighting := game.phase == Game.Phase.FIGHT
	for i in _cards.size():
		var v: CardView = _cards[i]
		var c := Content.card(v.ci)
		v.set_state(home.energy >= int(c.cost) and planning, game.held == i)
	_draw.text = "%d" % home.draw.size()
	_discard.text = "%d" % home.discard.size()
	_go.disabled = not planning
	_go.visible = not fighting
	_energy.visible = not fighting
	_draw.get_parent().get_parent().visible = not fighting
	_discard.get_parent().get_parent().visible = not fighting
	_energy.queue_redraw()
	_hp.queue_redraw()
	_title.text = "%s · 第 %d / %d 轮" % [Content.LEVELS[run.level].name, run.round, run.rounds()]
	var full := home.units.size() >= home.room()
	_yard.text = "院子：%d / %d 个兵%s" % [home.units.size(), home.room(), "（满了）" if full else ""]
	_yard.add_theme_color_override("font_color", Color(1.0, 0.6, 0.38) if full else Color(0.92, 0.86, 0.74))
	_buffs.text = _buff_text(home.buffs)
	_buffs.visible = _buffs.text != ""
	_battle.visible = fighting and not game.at_home
	_hint.text = game.hint()
	_refresh_waves()
	_refresh_forecast()


func _buff_text(b: Dictionary) -> String:
	var parts: Array = []
	if int(b.get("atk", 0)) > 0:
		parts.append("攻击 +%d" % b.atk)
	if int(b.get("armor", 0)) > 0:
		parts.append("护甲 +%d" % b.armor)
	if int(b.get("haste", 0)) > 0:
		parts.append("快 %d%%" % b.haste)
	return ("这一仗：" + "，".join(parts)) if not parts.is_empty() else ""


func _refresh_waves() -> void:
	var run: Run = game.run
	var key := "%d/%d" % [run.level, run.round]
	if key == _waves_for:
		return
	_waves_for = key
	for ch in _waves.get_children():
		ch.queue_free()
	_waves.add_child(_wave_chip("这一仗", run.wave(), true))
	if run.round < run.rounds():
		_waves.add_child(_wave_chip("下一仗", run.wave(1), false))


func _wave_chip(name: String, wave: Array, now: bool) -> Control:
	var chip := PanelContainer.new()
	var edge := Color(1.0, 0.45, 0.35, 0.9) if now else Color(0.7, 0.62, 0.55, 0.7)
	chip.add_theme_stylebox_override("panel", _panel(Color(0.09, 0.06, 0.06, 0.9), edge, 7))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	row.add_child(_label(name, 15, Fonts.serif(800), Color(1.0, 0.82, 0.72) if now else Color(0.85, 0.8, 0.74)))
	var counts := {}
	for k in wave:
		counts[k] = counts.get(k, 0) + 1
	for k in counts:
		var square := ColorRect.new()
		square.color = Content.ENEMIES[k].color
		square.custom_minimum_size = Vector2(18, 18)
		square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(square)
		row.add_child(_label("%s×%d" % [Content.ENEMIES[k].name, counts[k]], 15, Fonts.serif(700), Color(1, 1, 1)))
	return chip


func _refresh_forecast() -> void:
	var f: Dictionary = game.forecast
	var p: Dictionary = game.preview
	_forecast.visible = game.phase == Game.Phase.PLAN and not f.is_empty()
	if not _forecast.visible:
		return
	var shown := p if not p.is_empty() else f
	_fc_head.text = "打出这张牌，这一仗会：" if not p.is_empty() else "照现在这样，这一仗会："
	_fc_line.text = _verdict(shown)
	_fc_line.add_theme_color_override("font_color", WIN if shown.result == "won" else LOSE)
	_fc_more.text = ("现在是：" + _verdict(f)) if not p.is_empty() else "（每一仗都照规矩打，结果算得出来）"


func _verdict(f: Dictionary) -> String:
	if f.result == "won":
		return "赢，站着的还有 %d / %d 个" % [f.left, f.total]
	if int(f.total) == 0:
		return "没有兵出战，家园 −%d" % f.harm
	if f.result == "time":
		return "拖到时间算输，家园 −%d" % f.harm
	return "输，家园 −%d" % f.harm


func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var w := _root.size.x
	var h := _root.size.y
	var gap := minf(132.0, (w - 520.0) / maxf(1.0, n - 1))
	for i in n:
		var v: CardView = _cards[i]
		var off := i - (n - 1) * 0.5
		var x := w * 0.5 + off * gap
		var y := h + 52.0 + absf(off) * absf(off) * 5.0
		var rot := deg_to_rad(off * 3.5)
		var k := HAND_SCALE
		if v == _hovered:
			y -= 100.0
			rot = 0.0
			k = HOVER_SCALE
		elif game.held == i:
			y -= 44.0
			rot = 0.0
		var to := Vector2(x, y) - v.pivot_offset
		v.position = v.position.lerp(to, 0.3)
		v.rotation = lerpf(v.rotation, rot, 0.3)
		v.scale = v.scale.lerp(Vector2.ONE * k, 0.3)
		v.z_index = 10 if v == _hovered else i


func _on_card(v: CardView) -> void:
	var i := _cards.find(v)
	if i >= 0:
		game.hold(i)


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
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = _banner.create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(1.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


# -- Screens between battles ------------------------------------------------------------------------------------

## A screen over everything: a title, cards to click, buttons. What was clicked: the card (its dictionary) or
## the button's words.
func choose(title: String, sub: String, cards: Array, buttons: Array, upgrading := false) -> Variant:
	_screen(title, sub, cards, buttons, upgrading)
	var v: Variant = await chosen
	screen = ""
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.visible = false
	_hand.visible = true
	return v


func _screen(title: String, sub: String, cards: Array, buttons: Array, upgrading: bool) -> void:
	for ch in _overlay.get_children():
		ch.queue_free()
	screen = title
	_overlay.visible = true
	_hand.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.02, 0.74)
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
		grid.columns = mini(cards.size(), 8)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(grid)
		var k := 1.0 if cards.size() <= 3 else (0.72 if cards.size() <= 16 else 0.6)
		for ci in cards:
			var slot := Control.new()
			slot.custom_minimum_size = CardView.SIZE * k
			grid.add_child(slot)
			var v := CardView.new()
			slot.add_child(v)
			v.setup(ci)
			v.pivot_offset = Vector2.ZERO
			v.scale = Vector2.ONE * k
			var done: bool = upgrading and ci.get("up", false)
			v.set_state(not done, false)
			if not done:
				v.clicked.connect(func(_v: CardView) -> void: chosen.emit(ci))
			if upgrading and not done:
				# Pointed at, it shows what it would become.
				v.hovered.connect(func(view: CardView, on: bool) -> void: view.show_as({"id": ci.id, "up": on}))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for b in buttons:
		var button := _button(b, Vector2(170, 52), 20)
		button.pressed.connect(func() -> void: chosen.emit(b))
		row.add_child(button)


# -- Pieces -----------------------------------------------------------------------------------------------------

## The energy: an amber stone, filled as far as there is energy, the number on it.
func _draw_energy() -> void:
	var home: Home = game.home
	var c := Vector2(60, 60)
	_energy.draw_circle(c, 56.0, Color(0.06, 0.05, 0.04, 0.92))
	_energy.draw_arc(c, 56.0, 0.0, TAU, 48, Color(0.72, 0.53, 0.3), 3.0, true)
	var frac := float(home.energy) / Home.ENERGY_MAX
	var fill := Color(1.0, 0.68, 0.22)
	if frac > 0.0:
		_energy.draw_arc(c, 47.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, fill, 9.0, true)
	_energy.draw_circle(c, 38.0, Color(0.16, 0.1, 0.05))
	var f := Fonts.numbers()
	var text := "%d" % home.energy
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
	_energy.draw_string_outline(f, c + Vector2(-w * 0.5, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, 5, Color(0, 0, 0, 0.9))
	_energy.draw_string(f, c + Vector2(-w * 0.5, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, fill)
	var cap := "/ %d" % Home.ENERGY_MAX
	var cw := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_energy.draw_string(f, c + Vector2(-cw * 0.5, 33), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.9, 0.7, 0.8))
	var lf := Fonts.serif(700)
	var label := "力气 · 每轮 +%d" % home.income()
	var lw := lf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_energy.draw_string_outline(lf, Vector2(60 - lw * 0.5, 132), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
	_energy.draw_string(lf, Vector2(60 - lw * 0.5, 132), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.7))


## The homeland's health: a bar, red when low.
func _draw_hp() -> void:
	var home: Home = game.home
	var r := Rect2(Vector2(0, 3), Vector2(250, 24))
	_hp.draw_rect(r.grow(2.0), Color(0.05, 0.04, 0.03, 0.9))
	var frac := clampf(float(home.hp) / maxf(1.0, home.hp_max()), 0.0, 1.0)
	var col := Color(0.86, 0.3, 0.25) if frac < 0.35 else Color(0.42, 0.78, 0.36)
	_hp.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col)
	var f := Fonts.serif(800)
	var text := "家园 %d / %d" % [home.hp, home.hp_max()]
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_hp.draw_string_outline(f, Vector2(r.get_center().x - w * 0.5, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	_hp.draw_string(f, Vector2(r.get_center().x - w * 0.5, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


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


func _button(text: String, min_size: Vector2, size_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", Fonts.serif(800))
	b.add_theme_font_size_override("font_size", size_px)
	b.add_theme_color_override("font_color", Color(0.18, 0.11, 0.05))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.02))
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.3, 0.25))
	b.add_theme_stylebox_override("normal", _plate(Color(0.95, 0.72, 0.34), Color(0.45, 0.28, 0.12)))
	b.add_theme_stylebox_override("hover", _plate(Color(1.0, 0.8, 0.42), Color(0.55, 0.34, 0.14)))
	b.add_theme_stylebox_override("pressed", _plate(Color(0.85, 0.62, 0.28), Color(0.45, 0.28, 0.12)))
	b.add_theme_stylebox_override("disabled", _plate(Color(0.42, 0.38, 0.33), Color(0.25, 0.22, 0.2)))
	return b


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
