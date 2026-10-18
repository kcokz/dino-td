class_name Hud
extends CanvasLayer
## What the player holds and reads (GAME-DESIGN 16), all over the homeland on one screen: the shop's shelf along the
## bottom (the gifts at its front), the gold, the potions, the button that restocks the shelf, the button that sends
## the army out; the level, the round, the homeland's health, the biomass and genes, this round's army and
## the relics at the top left; who comes this battle and the next, and how this battle will go as things stand, at the
## top right; what the cursor points at; a battle's count and clock; and the relic to choose when a level is held. It
## shows; Game decides.

signal chosen(value: Variant)

const SHELF_SCALE := 0.84
const HOVER_SCALE := 1.15
const WIN := Color(0.55, 1.0, 0.5)
const LOSE := Color(1.0, 0.48, 0.4)
const CREAM := Color(0.98, 0.93, 0.82)
const GOLD := Color(1.0, 0.82, 0.25)

var game: Game
var _root: Control
var _hand: Control
var _cards: Array = []           # CardView, one for each place on the shelf
var _hovered: CardView
var _gold: Control
var _reroll: Button
var _go: Button
var _title: Label
var _hp: Control
var _res: Label
var _army: Label
var _buffs: Label
var _relics: HBoxContainer
var _relics_shown := -1
var _relic_hover := ""
var _potions: Array = []         # the potion places, Controls
var _potion_hover := -1
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
var _stowed := false             # the shelf put away below the screen (in a battle)
var screen := ""                 # the title of the screen up, "" when none (for tools)


func setup(p_game: Game) -> void:
	game = p_game
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: where we are, the homeland, the resources, this round's army and buffs; the relics beside.
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
	_res = _label("", 16, Fonts.serif(700), Color(0.92, 0.9, 0.8))
	_res.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_res)
	_army = _label("", 16, Fonts.serif(700), Color(0.92, 0.86, 0.74))
	_army.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_army)
	_buffs = _label("", 16, Fonts.serif(700), Color(1.0, 0.8, 0.45))
	_buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner.add_child(_buffs)
	_relics = HBoxContainer.new()
	_relics.position = Vector2(284, 44)
	_relics.add_theme_constant_override("separation", 6)
	_root.add_child(_relics)

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

	# What the cursor points at.
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.065, 0.06, 0.9), Color(0.72, 0.55, 0.32), 12))
	_info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_info.position = Vector2(18, 178)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_root.add_child(_info)
	_info_text = _label("", 15, Fonts.serif(500), Color(0.96, 0.92, 0.84))
	_info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_text.custom_minimum_size = Vector2(250, 0)
	_info.add_child(_info_text)

	# Bottom: the shelf, the gold, the potions, the buttons.
	_hand = Control.new()
	_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hand)
	_gold = Control.new()
	_gold.custom_minimum_size = Vector2(120, 150)
	_gold.size = Vector2(120, 150)
	_gold.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gold.position = Vector2(22, -232)
	_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold.draw.connect(_draw_gold)
	_root.add_child(_gold)
	for k in Content.POTION_SLOTS:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.size = Vector2(46, 46)
		slot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		slot.position = Vector2(-206 + k * 60, -282)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.draw.connect(_draw_potion.bind(k))
		slot.mouse_entered.connect(func() -> void:
			_potion_hover = k
			game.aim_potion(k))
		slot.mouse_exited.connect(func() -> void:
			if _potion_hover == k:
				_potion_hover = -1
				game.aim_potion(-1))
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				game.act("potion", {"slot": k}))
		_root.add_child(slot)
		_potions.append(slot)
	_reroll = _button("刷新", Vector2(188, 50), 19)
	_reroll.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_reroll.position = Vector2(-214, -218)
	_reroll.pressed.connect(func() -> void: game.act("reroll"))
	_root.add_child(_reroll)
	_go = _button("出战！", Vector2(188, 64), 26)
	_go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_go.position = Vector2(-214, -150)
	_go.pressed.connect(func() -> void: game.act("fight"))
	_root.add_child(_go)
	_hint = _label("", 17, Fonts.serif(700), Color(1.0, 0.93, 0.75))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position = Vector2(-60, -236)
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
	if not _overlay.visible:
		var home: Home = game.home
		if _potion_hover >= 0:
			tip = ""
			if _potion_hover < home.potions.size():
				var pt: Dictionary = Content.POTIONS[home.potions[_potion_hover]]
				tip = "%s\n%s\n点一下就用（不要钱）" % [pt.name, pt.says]
		elif _relic_hover != "":
			var r: Dictionary = Content.RELICS[_relic_hover]
			tip = "%s（化石遗物）\n%s" % [r.name, r.says]
	_info.visible = tip != ""
	if tip != "" and _info_text.text != tip:
		_info_text.text = tip
		_info.reset_size()
	if _battle.visible and game.fight != null:
		var f: Fight = game.fight
		_battle_text.text = "我方 %d  对  敌方 %d   ·   还剩 %d 秒" % [f.alive("ours").size(), f.alive("theirs").size(),
			ceili(maxf(0.0, Fight.LIMIT - f.time))]


## The shelf, as cards: a place still showing what it showed keeps its card (so nothing jumps); a place bought from
## shows an empty frame; a restocked one, the new offer. Brought back up if it was put away.
func deal(shelf: Array) -> void:
	_stowed = false
	var out: Array = []
	for i in shelf.size():
		var oi: Variant = shelf[i]
		var old: CardView = _cards[i] if i < _cards.size() else null
		if old != null and ((oi == null and old.sold) or (oi != null and not old.sold and old.ci == oi)):
			out.append(old)
			continue
		var v := CardView.new()
		_hand.add_child(v)
		if oi == null:
			v.setup_sold()
		else:
			v.setup(oi)
			v.clicked.connect(_on_card)
			v.hovered.connect(_on_hover)
		if old != null:
			v.position = old.position
			v.scale = old.scale
			_fly_off(old, oi == null)
		else:
			v.position = Vector2(_root.size.x * 0.5, _root.size.y + 40.0)
			v.scale = Vector2.ONE * 0.3
		out.append(v)
	for i in range(shelf.size(), _cards.size()):
		_fly_off(_cards[i], false)
	_cards = out
	if _hovered and not _hovered in _cards:
		_hovered = null
	refresh()


## Everyone goes out: the shelf is put away below the screen.
func stow() -> void:
	_stowed = true
	_hovered = null
	refresh()


## A card leaving the shelf: bought, it rises and fades; restocked away, it drops.
func _fly_off(v: CardView, bought: bool) -> void:
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := v.create_tween()
	tw.set_parallel()
	tw.tween_property(v, "position", v.position + Vector2(0, -160 if bought else 220), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(v, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(v.queue_free)


func refresh() -> void:
	var run: Run = game.run
	var home: Home = game.home
	var planning := game.phase == Game.Phase.PLAN
	var fighting := game.phase == Game.Phase.FIGHT
	for i in _cards.size():
		var v: CardView = _cards[i]
		if not v.sold:
			v.set_state(planning and not home.targets(i).is_empty(), game.held == i)
	_go.disabled = not planning
	_go.visible = not fighting
	var price := home.reroll_price()
	_reroll.text = "刷新（%s）" % ("免费" if price == 0 else "%d 金" % price)
	_reroll.disabled = not planning or home.gold < price
	_reroll.visible = not fighting
	_gold.visible = not fighting
	_gold.queue_redraw()
	_hp.queue_redraw()
	_title.text = "%s · 第 %d / %d 轮" % [Content.LEVELS[run.level].name, run.round, run.rounds()]
	_res.text = "生物质 %d/%d（+%d）  基因 %d/%d（+%d）  外星基因 %d" % [home.biomass, home.biomass_max(),
		home.income_biomass(), home.genes, home.genes_max(), home.income_genes(), home.alien]
	var army := home.army()
	_army.text = "这一轮出战 %d 只，吃 %d 生物质" % [army.size(), home.army_food()] if not fighting else ""
	_army.visible = not fighting
	for slot in _potions:
		slot.queue_redraw()
		slot.visible = not fighting
	_buffs.text = _buff_text(home.buffs)
	_buffs.visible = _buffs.text != ""
	_battle.visible = fighting and not game.at_home
	_hint.text = game.hint()
	_refresh_relics()
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
	if int(b.get("breed", 0)) > 0:
		parts.append("每个巢多孵 %d 只" % b.breed)
	return ("这一轮：" + "，".join(parts)) if not parts.is_empty() else ""


## The relics held, as little fossils beside the homeland's health; pointed at, the panel says what each does.
func _refresh_relics() -> void:
	var home: Home = game.home
	if home.relics.size() == _relics_shown:
		return
	_relics_shown = home.relics.size()
	for ch in _relics.get_children():
		ch.queue_free()
	for id in home.relics:
		var r: Dictionary = Content.RELICS[id]
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.draw.connect(func() -> void:
			icon.draw_circle(Vector2(17, 17), 16.0, Color(0.08, 0.07, 0.06, 0.9))
			icon.draw_circle(Vector2(17, 17), 13.0, r.color)
			var f := Fonts.serif(900)
			var ch: String = r.name.left(1)
			var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			icon.draw_string(f, Vector2(17 - w * 0.5, 23), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.12, 0.08, 0.04)))
		icon.mouse_entered.connect(func() -> void: _relic_hover = id)
		icon.mouse_exited.connect(func() -> void:
			if _relic_hover == id:
				_relic_hover = "")
		_relics.add_child(icon)


func _refresh_waves() -> void:
	var run: Run = game.run
	var key := "%d/%d" % [run.level, run.round]
	if key == _waves_for:
		return
	_waves_for = key
	for ch in _waves.get_children():
		ch.queue_free()
	_waves.add_child(_wave_chip("这一仗" + ("（大波）" if run.big() else ""), run.wave(), true))
	if run.round < run.rounds():
		_waves.add_child(_wave_chip("下一仗" + ("（大波）" if run.big(1) else ""), run.wave(1), false))


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
	_fc_head.text = "买了以后，这一仗会：" if not p.is_empty() else "照现在这样，这一仗会："
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


## The shelf laid out flat along the bottom, between the gold and the buttons; the card pointed at lifted and larger,
## the one taken up raised.
func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var w := _root.size.x
	var h := _root.size.y
	var gap := minf(150.0, (w - 600.0) / maxf(1.0, n - 1))
	for i in n:
		var v: CardView = _cards[i]
		if v.modulate.a < 0.99 and v.mouse_filter == Control.MOUSE_FILTER_IGNORE and not v.sold:
			continue
		var off := i - (n - 1) * 0.5
		var x := w * 0.5 - 40.0 + off * gap
		var y := h + 40.0 + (260.0 if _stowed else 0.0)
		var k := SHELF_SCALE
		if v == _hovered:
			y -= 110.0
			k = HOVER_SCALE
		elif game.held == i:
			y -= 44.0
		var to := Vector2(x, y) - v.pivot_offset
		v.position = v.position.lerp(to, 0.3)
		v.rotation = lerpf(v.rotation, 0.0, 0.3)
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
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


# -- Screens ---------------------------------------------------------------------------------------------------

## The relics offered when a level is held, one to choose: its id.
func choose_relic(ids: Array) -> String:
	for ch in _overlay.get_children():
		ch.queue_free()
	screen = "选一块化石"
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
	box.add_theme_constant_override("separation", 18)
	_overlay.add_child(box)
	box.add_child(_label("%s守住了！" % Content.LEVELS[game.run.level].name, 44, Fonts.serif(900), Color(1.0, 0.92, 0.72)))
	box.add_child(_label("选一块化石，整局都有用。家园还会多开一排地", 19, Fonts.serif(600), Color(0.92, 0.86, 0.74)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for id in ids:
		var r: Dictionary = Content.RELICS[id]
		var b := _button("%s\n%s" % [r.name, r.says], Vector2(230, 110), 18)
		b.add_theme_stylebox_override("normal", _plate(r.color.lightened(0.25), r.color.darkened(0.4)))
		b.pressed.connect(func() -> void: chosen.emit(id))
		row.add_child(b)
	var v: Variant = await chosen
	screen = ""
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.visible = false
	_hand.visible = true
	return str(v)


## A screen over everything: a title, cards (to click, when `pick`), buttons. What was clicked: the card's offer or
## the button's words.
func choose(title: String, sub: String, cards: Array, buttons: Array, pick := true) -> Variant:
	_screen(title, sub, cards, buttons, pick)
	var v: Variant = await chosen
	screen = ""
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.visible = false
	_hand.visible = true
	return v


func _screen(title: String, sub: String, cards: Array, buttons: Array, pick: bool) -> void:
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
		grid.columns = mini(cards.size(), 10 if cards.size() > 16 else 8)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(grid)
		var k := 1.0 if cards.size() <= 3 else (0.72 if cards.size() <= 16 else (0.6 if cards.size() <= 30 else 0.5))
		for oi in cards:
			var slot := Control.new()
			slot.custom_minimum_size = CardView.SIZE * k
			grid.add_child(slot)
			var v := CardView.new()
			slot.add_child(v)
			v.setup(oi)
			v.pivot_offset = Vector2.ZERO
			v.scale = Vector2.ONE * k
			if pick:
				v.clicked.connect(func(_v: CardView) -> void: chosen.emit(oi))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for b in buttons:
		var button := _button(b, Vector2(170, 52), 20)
		button.pressed.connect(func() -> void: chosen.emit(b))
		row.add_child(button)


# -- Pieces -----------------------------------------------------------------------------------------------------

## The gold: a big coin with the gold on it; under it, what comes in each round and the interest on what is kept.
func _draw_gold() -> void:
	var home: Home = game.home
	var c := Vector2(60, 58)
	_gold.draw_circle(c, 54.0, Color(0.1, 0.07, 0.02, 0.95))
	_gold.draw_circle(c, 50.0, GOLD.darkened(0.35))
	_gold.draw_circle(c, 44.0, GOLD)
	_gold.draw_arc(c, 37.0, 0.0, TAU, 48, GOLD.darkened(0.25), 2.0, true)
	_gold.draw_circle(c + Vector2(-16, -18), 7.0, Color(1, 1, 1, 0.35))
	var f := Fonts.numbers()
	var text := "%d" % home.gold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_gold.draw_string(f, c + Vector2(-w * 0.5, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.3, 0.18, 0.0))
	var lf := Fonts.serif(700)
	for line in [["金币 · 每轮 +%d" % home.income_gold(), 128.0], ["存着，利息 +%d" % home.interest(), 146.0]]:
		var lw := lf.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_gold.draw_string_outline(lf, Vector2(60 - lw * 0.5, line[1]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
		_gold.draw_string(lf, Vector2(60 - lw * 0.5, line[1]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6))


## A potion place: an empty ring, or a flask of the potion's colour.
func _draw_potion(k: int) -> void:
	var slot: Control = _potions[k]
	var home: Home = game.home
	var c := Vector2(23, 23)
	slot.draw_circle(c, 22.0, Color(0.06, 0.05, 0.04, 0.9))
	slot.draw_arc(c, 22.0, 0.0, TAU, 32, Color(0.72, 0.53, 0.3) if k != _potion_hover else Color(1.0, 0.85, 0.45), 2.5, true)
	if k >= home.potions.size():
		return
	var col: Color = Content.POTIONS[home.potions[k]].color
	slot.draw_circle(c + Vector2(0, 4), 12.0, col)
	slot.draw_circle(c + Vector2(-4, 0), 3.5, Color(1, 1, 1, 0.5))
	slot.draw_rect(Rect2(c + Vector2(-4, -15), Vector2(8, 9)), col.darkened(0.2))
	slot.draw_rect(Rect2(c + Vector2(-5, -17), Vector2(10, 3)), Color(0.55, 0.4, 0.25))


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
