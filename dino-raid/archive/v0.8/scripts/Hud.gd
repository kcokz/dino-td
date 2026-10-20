class_name Hud
extends CanvasLayer
## What the player holds and reads (GAME-DESIGN 17), all over the homeland on one screen: the shop's shelf along the
## bottom; the stash -- the goods kept for later -- above the gold at the bottom left, with a place to keep the offer
## taken up; the gold, the potions, the button that restocks the shelf, the button that sends the army out; the place,
## its rule, the round, the homeland's health, the biomass and genes, this round's army and the relics at the top left;
## who comes this battle and the next, how this battle will go as things stand, and what the cursor points at, at the
## top right; a battle's count and clock; when a place is held, the relic to choose and what the ark carries on (and
## what the homeland will eat and make with it); when the ark lands, the new place's rule and ground. It shows; Game
## decides.

signal chosen(value: Variant)

const SHELF_SCALE := 0.84
const HOVER_SCALE := 1.15
const KEPT_SCALE := 0.42
const WIN := Color(0.55, 1.0, 0.5)
const LOSE := Color(1.0, 0.48, 0.4)
const CREAM := Color(0.98, 0.93, 0.82)
const GOLD := Color(1.0, 0.82, 0.25)
const BOSS := Color(0.95, 0.4, 0.3)

var game: Game
var _root: Control
var _hand: Control
var _cards: Array = []           # CardView, one for each place on the shelf
var _kept: Array = []            # CardView, one for each good in the stash
var _kept_for := ""
var _kept_label: Label
var _store_slot: Control
var _hovered: CardView
var _gold: Control
var _reroll: Button
var _go: Button
var _corner: VBoxContainer
var _title: Label
var _rule: Label
var _hp: Control
var _res: Label
var _army: Label
var _buffs: Label
var _relics: HBoxContainer
var _relics_shown := -1
var _relic_hover := ""
var _potions: Array = []         # the potion places, Controls
var _potion_hover := -1
var _right: VBoxContainer
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
var _pack: PanelContainer
var _pack_text: Label
var _pack_food: Label
var _overlay: Control
var _shade: ColorRect
var _stowed := false             # the shelf put away below the screen (in a battle, or while packing)
var screen := ""                 # the title of the screen up, "" when none (for tools)
var offered: Array = []          # what the screen up offers to choose from: offers, relic or ark ids (for tools)


func setup(p_game: Game) -> void:
	game = p_game
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: where we are and its rule, the homeland, the resources, this round's army and buffs; the relics beside.
	_corner = VBoxContainer.new()
	_corner.position = Vector2(18, 10)
	_corner.add_theme_constant_override("separation", 4)
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_corner)
	_title = _label("", 24, Fonts.serif(900), CREAM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_corner.add_child(_title)
	_rule = _label("", 14, Fonts.serif(700), Color(0.95, 0.78, 0.55))
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_corner.add_child(_rule)
	_hp = Control.new()
	_hp.custom_minimum_size = Vector2(250, 30)
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp.draw.connect(_draw_hp)
	_corner.add_child(_hp)
	_res = _label("", 16, Fonts.serif(700), Color(0.92, 0.9, 0.8))
	_res.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_corner.add_child(_res)
	_army = _label("", 16, Fonts.serif(700), Color(0.92, 0.86, 0.74))
	_army.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_corner.add_child(_army)
	_buffs = _label("", 16, Fonts.serif(700), Color(1.0, 0.8, 0.45))
	_buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_corner.add_child(_buffs)
	_relics = HBoxContainer.new()
	_relics.position = Vector2(300, 10)
	_relics.add_theme_constant_override("separation", 6)
	_root.add_child(_relics)

	# Top right: who comes, and how it will go; under them, what the cursor points at.
	_right = VBoxContainer.new()
	var right := _right
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
	_info.position = Vector2(18, 190)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_root.add_child(_info)
	_info_text = _label("", 15, Fonts.serif(500), Color(0.96, 0.92, 0.84))
	_info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_text.custom_minimum_size = Vector2(300, 0)
	_info.add_child(_info_text)

	# Bottom left: the stash's count, and the place to keep the offer taken up (the stash's cards go in under the shelf).
	_kept_label = _label("", 15, Fonts.serif(800), Color(0.85, 0.95, 0.8))
	_kept_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_kept_label)
	_store_slot = Control.new()
	_store_slot.custom_minimum_size = CardView.SIZE * KEPT_SCALE
	_store_slot.size = CardView.SIZE * KEPT_SCALE
	_store_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_store_slot.draw.connect(_draw_store_slot)
	_store_slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game.act("store", {"slot": game.held}))
	_store_slot.visible = false
	_root.add_child(_store_slot)

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
	_go.pressed.connect(func() -> void: game.act("depart" if game.phase == Game.Phase.PACK else "fight"))
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

	# Packing: what the ark carries on.
	_pack = PanelContainer.new()
	_pack.add_theme_stylebox_override("panel", _panel(Color(0.07, 0.065, 0.06, 0.92), Color(0.95, 0.75, 0.35), 14))
	_pack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pack.position = Vector2(-40, -36)
	_pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack.visible = false
	_root.add_child(_pack)
	var pack_box := VBoxContainer.new()
	pack_box.add_theme_constant_override("separation", 4)
	_pack.add_child(pack_box)
	_pack_text = _label("", 18, Fonts.serif(700), CREAM)
	pack_box.add_child(_pack_text)
	_pack_food = _label("", 17, Fonts.serif(800), WIN)
	pack_box.add_child(_pack_food)

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
	_shade = ColorRect.new()
	_shade.color = Color(0.01, 0.01, 0.015)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.modulate.a = 0.0
	_root.add_child(_shade)


func _process(_delta: float) -> void:
	_layout()
	_info.position = Vector2(_root.size.x - 18.0 - _info.size.x, _right.position.y + _right.size.y + 10.0)
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
			tip = "%s（%s）\n%s" % [r.name, "首领遗物" if r.get("boss", false) else "化石遗物", r.says]
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
	if _hovered and not _hovered in _cards and not _hovered in _kept:
		_hovered = null
	refresh()


## The stash, as small cards (in under the shelf's): made again whenever what is in it changes.
func _refresh_kept() -> void:
	var home: Home = game.home
	var key := str(home.stash)
	if key == _kept_for:
		return
	_kept_for = key
	for v in _kept:
		if v == _hovered:
			_hovered = null
		v.queue_free()
	_kept = []
	for k in home.stash.size():
		var v := CardView.new()
		_root.add_child(v)
		_root.move_child(v, _hand.get_index())
		v.setup(home.stash[k], true)
		v.clicked.connect(_on_card)
		v.hovered.connect(_on_hover)
		v.scale = Vector2.ONE * KEPT_SCALE
		v.position = _kept_at(k, false) - v.pivot_offset
		_kept.append(v)


## Everyone goes out (or the ark is packing): the shelf is put away below the screen.
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
	var packing := game.phase == Game.Phase.PACK
	var away := fighting or game.phase == Game.Phase.MOVE     # the army out, or the ark in the air
	_refresh_kept()
	for i in _cards.size():
		var v: CardView = _cards[i]
		if not v.sold:
			v.set_state(planning and not home.targets(i).is_empty(), game.held == i)
	for k in _kept.size():
		var v: CardView = _kept[k]
		if packing:
			v.set_state(game.pack_kept.has(k), game.pack_kept.has(k))
		else:
			v.set_state(planning and not home.stash_targets(k).is_empty(), game.held_k == k)
	_go.disabled = not (planning or packing)
	_go.visible = not away
	_go.text = "出发！" if packing else "出战！"
	var price := home.reroll_price()
	_reroll.text = "刷新（%s）" % ("免费" if price == 0 else "%d 金" % price)
	_reroll.disabled = not planning or home.gold < price
	_reroll.visible = not away and not packing
	_gold.visible = not fighting
	_gold.queue_redraw()
	_hp.queue_redraw()
	_title.text = "%s · 第 %d / %d 轮" % [Content.LEVELS[run.level].name, run.round, run.rounds()]
	var rule: Dictionary = Content.RULES[Content.LEVELS[run.level].rule]
	_rule.text = "%s：%s" % [rule.name, rule.says]
	_res.text = "生物质 %d/%d（+%d）  基因 %d/%d（+%d）  外星基因 %d" % [home.biomass, home.biomass_max(),
		home.income_biomass(), home.genes, home.genes_max(), home.income_genes(), home.alien]
	var army := home.army()
	_army.text = "这一轮出战 %d 只，吃 %d 生物质" % [army.size(), home.army_food()] if not fighting else ""
	_army.visible = not away and not packing
	for slot in _potions:
		slot.queue_redraw()
		slot.visible = not away and not packing
	_buffs.text = _buff_text(home.buffs)
	_buffs.visible = _buffs.text != ""
	_battle.visible = fighting and not game.at_home
	var taking: int = game.pack_plots.size() + game.pack_kept.size()
	_kept_label.text = ("带走 %d / %d" % [taking, home.stash_size()]) if packing else ("存货 %d / %d" % [home.stash.size(), home.stash_size()])
	_kept_label.visible = not away
	for v in _kept:
		v.visible = not away
	_store_slot.visible = planning and game.held >= 0 and home.can_store(game.held)
	_store_slot.queue_redraw()
	_waves.visible = not away and not packing
	_pack.visible = packing
	if packing:
		_pack_text.text = "搬家！点建筑和存货，选要带走的（最多 %d 样，已选 %d）\n金币、生物质、基因全带上，没选的留在这里。选好了点「出发！」" % [
			home.stash_size(), taking]
		var food: Array = game.pack_food()
		_pack_food.text = "到了那边（算上方舟自带的红巢和培养池）：兵每轮要吃 %d 生物质，池子每轮产 %d%s" % [food[0], food[1],
			"——不够吃" if int(food[0]) > int(food[1]) else ""]
		_pack_food.add_theme_color_override("font_color", LOSE if int(food[0]) > int(food[1]) else WIN)
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


## The relics held, as little fossils by the place's name (a boss's ringed red); pointed at, the panel says what each
## does.
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
			icon.draw_circle(Vector2(17, 17), 16.0, BOSS if r.get("boss", false) else Color(0.08, 0.07, 0.06, 0.9))
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
	_waves.add_child(_wave_chip("这一仗" + _big(run, 0), run.wave(), true))
	if run.round < run.rounds():
		_waves.add_child(_wave_chip("下一仗" + _big(run, 1), run.wave(1), false))


func _big(run: Run, ahead: int) -> String:
	if run.round + ahead >= run.rounds():
		return "（首领）"
	return "（大波）" if run.big(ahead) else ""


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
	_fc_head.text = "这样以后，这一仗会：" if not p.is_empty() else "照现在这样，这一仗会："
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


## Where the stash's k-th card stands (its bottom middle).
func _kept_at(k: int, lifted: bool) -> Vector2:
	var w := CardView.SIZE.x * KEPT_SCALE
	return Vector2(22.0 + w * 0.5 + k * (w + 6.0), _root.size.y - 240.0 - (14.0 if lifted else 0.0))


## The shelf laid out flat along the bottom, between the gold and the buttons; the stash in a row above the gold; the
## card pointed at lifted and larger, the one taken up raised.
func _layout() -> void:
	var w := _root.size.x
	var h := _root.size.y
	var n := _cards.size()
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
		_move(v, Vector2(x, y), k, 10 if v == _hovered else i)
	for k in _kept.size():
		var v: CardView = _kept[k]
		var at := _kept_at(k, game.held_k == k or game.phase == Game.Phase.PACK and game.pack_kept.has(k))
		var s := KEPT_SCALE
		if v == _hovered:
			s = SHELF_SCALE
			at.x = maxf(at.x, 18.0 + CardView.SIZE.x * s * 0.5)
		_move(v, at, s, 20 if v == _hovered else 0)
	var top := _kept_at(0, false).y - CardView.SIZE.y * KEPT_SCALE - 22.0
	_kept_label.position = Vector2(22.0, top)
	_store_slot.position = _kept_at(_kept.size(), false) - Vector2(CardView.SIZE.x * KEPT_SCALE * 0.5, CardView.SIZE.y * KEPT_SCALE)


func _move(v: CardView, to_bottom: Vector2, k: float, z: int) -> void:
	var to := to_bottom - v.pivot_offset
	v.position = v.position.lerp(to, 0.3)
	v.rotation = lerpf(v.rotation, 0.0, 0.3)
	v.scale = v.scale.lerp(Vector2.ONE * k, 0.3)
	v.z_index = z


func _on_card(v: CardView) -> void:
	var i := _cards.find(v)
	if i >= 0:
		game.hold(i)
		return
	var k := _kept.find(v)
	if k >= 0:
		if game.phase == Game.Phase.PACK:
			game.act("pack", {"kept": k})
		else:
			game.hold_kept(k)


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


## The screen going dark (or light again), while the ark is between places.
func fade(dark: bool, time := 0.7) -> void:
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP if dark else Control.MOUSE_FILTER_IGNORE
	var tw := _shade.create_tween()
	tw.tween_property(_shade, "modulate:a", 1.0 if dark else 0.0, time)
	await tw.finished


# -- Screens ---------------------------------------------------------------------------------------------------

## The arks a run can start with, one to choose: its id.
func choose_ark() -> String:
	var box := _open("选一艘方舟", "方舟带着基因库出发，落到哪里，就在哪里建家园")
	offered = Content.ARKS.keys()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for id in Content.ARKS:
		var a: Dictionary = Content.ARKS[id]
		var b := _button("%s\n%s" % [a.name, a.says.replace("。", "\n")], Vector2(260, 130), 18)
		b.pressed.connect(func() -> void: chosen.emit(id))
		row.add_child(b)
	var v: Variant = await chosen
	_close()
	return str(v)


## The place the ark has landed in: its name, its rule, its special ground; dismissed with a button.
func arrive(level: int) -> void:
	var lv: Dictionary = Content.LEVELS[level]
	var rule: Dictionary = Content.RULES[lv.rule]
	var ground: Array = []
	for t in lv.terrain:
		ground.append("%s：%s" % [Content.TERRAIN[t].name, Content.TERRAIN[t].says])
	var box := _open("到了%s！" % lv.name, "撑过 %d 轮，最后一轮是首领" % int(lv.rounds))
	box.add_child(_label("%s：%s\n%s" % [rule.name, rule.says, "\n".join(ground)], 19, Fonts.serif(700), Color(0.98, 0.9, 0.72)))
	var b := _button("开始", Vector2(170, 52), 20)
	b.pressed.connect(func() -> void: chosen.emit("开始"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	await chosen
	_close()


## The relics offered when a place is held, one to choose -- a boss's ringed red, with what it costs: its id.
func choose_relic(ids: Array) -> String:
	var box := _open("%s守住了！" % Content.LEVELS[game.run.level].name, "选一件遗物，整局都有用。红边的是首领留下的：很强，但有代价")
	offered = ids.duplicate()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for id in ids:
		var r: Dictionary = Content.RELICS[id]
		var boss: bool = r.get("boss", false)
		var b := _button("%s%s\n%s" % ["首领遗物 · " if boss else "", r.name, r.says.replace("；", "\n")], Vector2(240, 120), 18)
		b.add_theme_stylebox_override("normal", _plate(r.color.lightened(0.25), BOSS if boss else r.color.darkened(0.4), 6 if boss else 3))
		b.add_theme_stylebox_override("hover", _plate(r.color.lightened(0.4), BOSS if boss else r.color.darkened(0.4), 6 if boss else 3))
		b.pressed.connect(func() -> void: chosen.emit(id))
		row.add_child(b)
	var v: Variant = await chosen
	_close()
	return str(v)


## A screen over everything: a title, cards (to click, when `pick`), buttons. What was clicked: the card's offer or
## the button's words.
func choose(title: String, sub: String, cards: Array, buttons: Array, pick := true) -> Variant:
	var box := _open(title, sub)
	offered = cards.duplicate()
	if not cards.is_empty():
		var grid := GridContainer.new()
		grid.columns = mini(cards.size(), 8)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(grid)
		var k := 1.0 if cards.size() <= 3 else 0.72
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
	var v: Variant = await chosen
	_close()
	return v


## The overlay up, with a title and a line under it: the box to put the rest in.
func _open(title: String, sub: String) -> VBoxContainer:
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
	return box


func _close() -> void:
	screen = ""
	offered = []
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.visible = false
	_hand.visible = true


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


## The place to keep the offer taken up: a dashed frame, "存起来" and its price.
func _draw_store_slot() -> void:
	var r := Rect2(Vector2.ZERO, _store_slot.size)
	_store_slot.draw_rect(r, Color(0.1, 0.2, 0.1, 0.6))
	var edge := Color(0.6, 1.0, 0.55)
	for i in 8:
		var t0 := i / 8.0
		var t1 := t0 + 0.06
		_store_slot.draw_line(Vector2(r.size.x * t0, 0), Vector2(r.size.x * t1, 0), edge, 2.0)
		_store_slot.draw_line(Vector2(r.size.x * t0, r.size.y), Vector2(r.size.x * t1, r.size.y), edge, 2.0)
		_store_slot.draw_line(Vector2(0, r.size.y * t0), Vector2(0, r.size.y * t1), edge, 2.0)
		_store_slot.draw_line(Vector2(r.size.x, r.size.y * t0), Vector2(r.size.x, r.size.y * t1), edge, 2.0)
	var home: Home = game.home
	var i := game.held
	var price := home.price(i) if i >= 0 and i < home.shelf.size() and home.shelf[i] != null else 0
	var f := Fonts.serif(800)
	for line in [["存起来", 36.0, 15], ["%d 金" % price, 58.0, 14]]:
		var lw := f.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2]).x
		_store_slot.draw_string_outline(f, Vector2((r.size.x - lw) * 0.5, line[1]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2],
			4, Color(0, 0, 0, 0.9))
		_store_slot.draw_string(f, Vector2((r.size.x - lw) * 0.5, line[1]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2], edge)


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


func _plate(face: Color, edge: Color, width := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(10)
	return sb
