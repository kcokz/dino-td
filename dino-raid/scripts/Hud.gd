class_name Hud
extends CanvasLayer
## What the player holds and reads (GAME-DESIGN 17, 18), all over the homeland on one screen: the shop's shelf along
## the bottom; the stash -- the goods kept for later -- above the gold at the bottom left, with a place to keep the offer
## taken up; the gold, the button that restocks the shelf, the button that sends the army out; the place,
## its rule, the round, the homeland's health, the biomass and genes, this round's army and the relics at the top left;
## who comes this battle and the next, how this battle will go as things stand, and what the cursor points at, at the
## top right; a battle's count and clock; when a place is held, the relic to choose and what the ark carries on (and
## what the homeland will eat and make with it); when the ark lands, the new place's rule and ground. All in the one
## look (Style, GAME-DESIGN 21). It shows; Game decides.

signal chosen(value: Variant)

const SHELF_SCALE := 0.84
const HOVER_SCALE := 1.15
const KEPT_SCALE := 0.42
const WIN := Style.JADE
const LOSE := Style.CORAL
const CREAM := Style.PARCHMENT
const GOLD := Style.GOLD_BRIGHT
const BOSS := Style.CORAL

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
var _corner_frame: PanelContainer
var _menu: Button
var _banner_rule: Control
var _title: Label
var _rule: Label
var _hp: Control
var _res: Label
var _army: Label
var _bonus: Label
var _deck_button: Button
var _choice: PanelContainer
var _wonder_box: VBoxContainer
var _wonder_title: Label
var _wonder_buttons := {}        # wonder id -> Button
var _wonder_hover := ""
var _relics: HBoxContainer
var _relics_shown := -1
var _relic_hover := ""

var _right: VBoxContainer
var _waves: VBoxContainer
var _waves_for := ""
var _forecast: PanelContainer
var _fc_head: Label
var _fc_line: Label
var _fc_loot: Label
var _fc_more: Label
var _info: PanelContainer
var _info_text: Label
var _hint: Label
var _banner: PanelContainer
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
	_root.theme = Style.theme()
	add_child(_root)
	var edges := ColorRect.new()
	edges.set_anchors_preset(Control.PRESET_FULL_RECT)
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var em := ShaderMaterial.new()
	em.shader = Style.edge_shader()
	edges.material = em
	_root.add_child(edges)

	# Top left, on a panel of ink: where we are and its rule, the homeland, the resources, this round's army; the
	# relics beside.
	_corner_frame = PanelContainer.new()
	var frame := Style.panel(14.0)
	frame.top = Color(0.045, 0.06, 0.065, 0.74)
	frame.bottom = Color(0.03, 0.04, 0.045, 0.6)
	frame.shade = 0.25
	_corner_frame.add_theme_stylebox_override("panel", frame)
	_corner_frame.position = Vector2(12, 8)
	_corner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_corner_frame)
	_corner = VBoxContainer.new()
	_corner.add_theme_constant_override("separation", 4)
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_frame.add_child(_corner)
	_title = _label("", 24, Fonts.serif(900), Style.GOLD_BRIGHT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title)
	_relics = HBoxContainer.new()
	_relics.add_theme_constant_override("separation", 6)
	_relics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relics.alignment = BoxContainer.ALIGNMENT_END
	title_row.add_child(_relics)
	_corner.add_child(title_row)
	_rule = _label("", 14, Fonts.serif(700), Color(0.93, 0.8, 0.6))
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
	_bonus = _label("", 15, Fonts.serif(800), Style.AMBER)
	_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bonus.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_bonus.custom_minimum_size = Vector2(340, 0)
	_corner.add_child(_bonus)

	# Under it: the wonders on offer this run -- one can be built.
	_wonder_box = VBoxContainer.new()
	_wonder_box.add_theme_constant_override("separation", 6)
	_root.add_child(_wonder_box)
	_wonder_title = _label("奇观（一局只能造一座）", 15, Fonts.serif(800), Style.GOLD_BRIGHT)
	_wonder_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wonder_box.add_child(_wonder_title)
	var wonder_row := HBoxContainer.new()
	wonder_row.add_theme_constant_override("separation", 8)
	_wonder_box.add_child(wonder_row)
	for id in game.home.wonders:
		var w: Dictionary = Content.WONDERS[id]
		var b := _button("%s · %d 金" % [w.name, w.price], Vector2(160, 38), 16)
		b.add_theme_color_override("font_color", (w.color as Color).lerp(Style.PARCHMENT, 0.55))
		b.mouse_entered.connect(func() -> void:
			_wonder_hover = id
			game.aim(id))
		b.mouse_exited.connect(func() -> void:
			if _wonder_hover == id:
				_wonder_hover = ""
				game.aim(""))
		b.pressed.connect(func() -> void: game.act("wonder", {"id": id}))
		wonder_row.add_child(b)
		_wonder_buttons[id] = b


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
	_forecast.add_theme_stylebox_override("panel", Style.panel(14.0))
	_forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forecast.custom_minimum_size = Vector2(250, 0)
	right.add_child(_forecast)
	var fc := VBoxContainer.new()
	fc.add_theme_constant_override("separation", 2)
	_forecast.add_child(fc)
	_fc_head = _label("", 14, Fonts.serif(600), Style.PARCHMENT_DIM)
	_fc_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_head)
	_fc_line = _label("", 24, Fonts.serif(900), WIN)
	_fc_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_line)
	_fc_loot = _label("", 16, Fonts.serif(800), Style.AMBER)
	_fc_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_loot)
	_fc_more = _label("", 14, Fonts.serif(600), Style.PARCHMENT_DIM)
	_fc_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fc.add_child(_fc_more)

	# What the cursor points at.
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", Style.panel(14.0))
	_info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_info.position = Vector2(18, 190)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_root.add_child(_info)
	_info_text = _label("", 15, Fonts.serif(500), Style.PARCHMENT)
	_info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_text.custom_minimum_size = Vector2(300, 0)
	_info.add_child(_info_text)

	# Bottom left: the stash's count, and the place to keep the offer taken up (the stash's cards go in under the shelf).
	_kept_label = _label("", 15, Fonts.serif(800), Style.PARCHMENT)
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

	# Bottom: the shelf, the gold, the buttons.
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
	_reroll = _button("刷新", Vector2(188, 50), 19)
	_reroll.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_reroll.position = Vector2(-214, -218)
	_reroll.pressed.connect(func() -> void: game.act("reroll"))
	_root.add_child(_reroll)
	_deck_button = _button("牌库", Vector2(188, 44), 17)
	_deck_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_deck_button.position = Vector2(-214, -272)
	_deck_button.pressed.connect(func() -> void: show_deck())
	_root.add_child(_deck_button)
	_go = _button("出战！", Vector2(188, 64), 26, true)
	_go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_go.position = Vector2(-214, -150)
	_go.pressed.connect(func() -> void: game.act("depart" if game.phase == Game.Phase.PACK else "fight"))
	_root.add_child(_go)
	# Bottom left, under the gold: the pause menu (Esc does the same).
	_menu = _button("菜单", Vector2(96, 34), 15)
	_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_menu.position = Vector2(24, -50)
	_menu.pressed.connect(func() -> void: game.pause())
	_root.add_child(_menu)
	_hint = _label("", 17, Fonts.serif(700), Style.GOLD_BRIGHT)
	_hint.add_theme_stylebox_override("normal", Style.Streak.new(8.0))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position = Vector2(-60, -236)
	_root.add_child(_hint)

	# A battle: the count and the clock, and the speed.
	_battle = PanelContainer.new()
	_battle.add_theme_stylebox_override("panel", Style.panel(14.0))
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

	# A nest's raise: one more, or elite.
	_choice = PanelContainer.new()
	_choice.add_theme_stylebox_override("panel", Style.panel(14.0, true))
	_choice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_choice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice.position = Vector2(-40, -262)
	_choice.visible = false
	_root.add_child(_choice)
	var choice_row := HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 14)
	_choice.add_child(choice_row)
	choice_row.add_child(_label("这个巢升级：", 18, Fonts.serif(800), CREAM))
	for pair in [["count", "多孵 1 只"], ["elite", "变精英（血 ×%s、攻击 ×%s、大一号）" % [Content._num(Content.ELITE_HP),
			Content._num(Content.ELITE_ATK)]]]:
		var b := _button(pair[1], Vector2(150, 46), 17)
		var choice: String = pair[0]
		b.mouse_entered.connect(func() -> void: game.aim(choice))
		b.mouse_exited.connect(func() -> void:
			if game.aimed == choice:
				game.aim(""))
		b.pressed.connect(func() -> void: game.act("choose", {"choice": choice}))
		choice_row.add_child(b)

	# Packing: what the ark carries on.
	_pack = PanelContainer.new()
	_pack.add_theme_stylebox_override("panel", Style.panel(16.0, true))
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

	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", Style.Streak.new(14.0))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.position.y = -120
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	var banner_box := VBoxContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_theme_constant_override("separation", 2)
	_banner.add_child(banner_box)
	_banner_title = _label("", 46, Fonts.serif(900), Style.GOLD_BRIGHT)
	_banner_title.add_theme_constant_override("outline_size", 10)
	banner_box.add_child(_banner_title)
	_banner_rule = Control.new()
	_banner_rule.custom_minimum_size = Vector2(460, 14)
	_banner_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rule.draw.connect(func() -> void: Style.rule(_banner_rule, Vector2(230, 7), 460.0))
	banner_box.add_child(_banner_rule)
	_banner_sub = _label("", 20, Fonts.serif(700), Style.PARCHMENT)
	banner_box.add_child(_banner_sub)

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
	_wonder_box.position = Vector2(18.0, _corner_frame.position.y + _corner_frame.size.y + 10.0)
	var tip := game.describe() if _hovered == null and not _overlay.visible else ""
	if not _overlay.visible:
		if _relic_hover != "":
			var r: Dictionary = Content.RELICS[_relic_hover]
			tip = "%s（%s）\n%s" % [r.name, "首领遗物" if r.get("boss", false) else "化石遗物", r.says]
		elif _wonder_hover != "":
			var w: Dictionary = Content.WONDERS[_wonder_hover]
			tip = "%s（奇观）\n%s\n%d 金。一局只能造一座，搬家也带着%s" % [w.name, w.says, w.price,
				"" if game.home.gold >= int(w.price) else "（还差 %d 金）" % (int(w.price) - game.home.gold)]
	_info.visible = tip != ""
	if tip != "" and _info_text.text != tip:
		_info_text.text = tip
		# Smaller type when it would run down into the buttons at the bottom right.
		var room := _root.size.y - 290.0 - _info.position.y - 24.0
		for px in [15, 14, 13]:
			_info_text.add_theme_font_size_override("font_size", px)
			if _info_text.get_line_count() * _info_text.get_line_height() <= room:
				break
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
			v.setup_sold("已买")
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
			v.genes_shown = home.genes_cost(v.c)
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
	_menu.visible = not fighting
	_gold.visible = not fighting
	_gold.queue_redraw()
	_hp.queue_redraw()
	_title.text = "%s · 第 %d / %d 轮" % [Content.LEVELS[run.place].name, run.round, run.rounds()]
	var rule: Dictionary = Content.RULES[Content.LEVELS[run.place].rule]
	_rule.text = "%s：%s" % [rule.name, rule.says]
	_res.text = "生物质 %d/%d（+%d）  研究点数 %d/%d（+%d）" % [home.biomass, home.biomass_max(),
		home.income_biomass(), home.genes, home.genes_max(), home.income_genes()]
	var army := home.army()
	_army.text = "这一轮出战 %d 只，吃 %d 生物质" % [army.size(), home.army_food()] if not fighting else ""
	_army.visible = not away and not packing
	_bonus.text = game.bonuses()
	_bonus.visible = _bonus.text != "" and not away and not packing
	_deck_button.visible = not away and not packing
	_deck_button.disabled = not planning
	_deck_button.text = "牌库（%d 张）" % home.deck.size()
	_choice.visible = planning and not game.pending.is_empty()
	_wonder_box.visible = not away and not packing and not home.wonders.is_empty()
	_wonder_title.text = ("奇观：%s（已造）" % Content.WONDERS[home.wonder].name) if home.wonder != "" else "奇观（一局只能造一座）"
	for id in _wonder_buttons:
		var b: Button = _wonder_buttons[id]
		b.visible = home.wonder == ""
		b.disabled = not planning or not home.can_build_wonder(id)
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
		_pack_text.text = "搬家去%s！点建筑和存货，选要带走的（最多 %d 样，已选 %d）\n金币、生物质、研究点数、牌库全带上，没选的留在这里。选好了点「出发！」" % [
			Content.LEVELS[maxi(0, game.going)].name, home.stash_size(), taking]
		var food: Array = game.pack_food()
		_pack_food.text = "到了那边（算上方舟自带的红巢和培养池）：兵每轮要吃 %d 生物质，池子每轮产 %d%s" % [food[0], food[1],
			"——不够吃" if int(food[0]) > int(food[1]) else ""]
		_pack_food.add_theme_color_override("font_color", LOSE if int(food[0]) > int(food[1]) else WIN)
	_hint.text = game.hint()
	_hint.visible = _hint.text != ""
	_refresh_relics()
	_refresh_waves()
	_refresh_forecast()



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
			# A medallion: a dark rim ringed in gold (coral for a boss's), the fossil's colour in it, its first word.
			var c := Vector2(17, 17)
			icon.draw_circle(c + Vector2(0, 2), 16.5, Color(0, 0, 0, 0.45))
			icon.draw_circle(c, 16.5, Style.INK_DEEP)
			icon.draw_arc(c, 15.0, 0.0, TAU, 40, BOSS if r.get("boss", false) else Style.GOLD, 1.8, true)
			icon.draw_circle(c, 12.0, (r.color as Color).darkened(0.15))
			icon.draw_circle(c + Vector2(-3, -4), 5.0, Color(1, 1, 1, 0.16))
			var f := Fonts.serif(900)
			var ch: String = r.name.left(1)
			var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			icon.draw_string(f, Vector2(17 - w * 0.5, 22.5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Style.INK_DEEP))
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
	if run.round + ahead in Content.MINI_ROUNDS:
		return "（小首领）"
	return "（大波）" if run.big(ahead) else ""


func _wave_chip(name: String, wave: Array, now: bool) -> Control:
	var chip := PanelContainer.new()
	var box := Style.panel(9.0)
	box.cut = 6.0
	box.edge = Style.CORAL if now else Style.GOLD_DIM
	box.rule = Color(box.edge, 0.3)
	box.studs = now
	chip.add_theme_stylebox_override("panel", box)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	row.add_child(_label(name, 15, Fonts.serif(800), Color(1.0, 0.8, 0.7) if now else Style.PARCHMENT_DIM))
	# How dangerous it looks: skulls (Content.danger) -- not whether it will be won.
	var n := Content.danger(wave, game.run.power())
	var skulls := Control.new()
	skulls.custom_minimum_size = Vector2(n * 17 + 2, 18)
	skulls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sc := Style.CORAL if now else Color(Style.CORAL, 0.6)
	skulls.draw.connect(func() -> void:
		for i in n:
			_skull(skulls, Vector2(9 + i * 17, 9), sc))
	row.add_child(skulls)
	var counts := {}
	for k in wave:
		counts[k] = counts.get(k, 0) + 1
	for k in counts:
		var mark := Control.new()
		mark.custom_minimum_size = Vector2(16, 16)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var mc: Color = Content.ENEMIES[k].color
		mark.draw.connect(func() -> void: Style.diamond(mark.get_canvas_item(), Vector2(8, 8), 7.5, mc, Color(0, 0, 0, 0.35)))
		row.add_child(mark)
		row.add_child(_label("%s×%d" % [Content.ENEMIES[k].name, counts[k]], 15, Fonts.serif(700), Style.PARCHMENT))
	return chip


func _refresh_forecast() -> void:
	var f: Dictionary = game.forecast
	var p: Dictionary = game.preview
	_forecast.visible = Game.debug and game.phase == Game.Phase.PLAN and not f.is_empty()
	if not _forecast.visible:
		return
	var shown := p if not p.is_empty() else f
	_fc_head.text = "这样以后，这一仗会：" if not p.is_empty() else "照现在这样，这一仗会："
	_fc_line.text = _verdict(shown)
	_fc_line.add_theme_color_override("font_color", WIN if shown.result == "won" else LOSE)
	var loot := int(shown.get("loot", 0))
	var was := int(f.get("loot", 0))
	_fc_loot.visible = loot > 0 or was > 0
	_fc_loot.text = "拾荒兽带回 %d 金%s" % [loot, ("（现在 %d）" % was) if not p.is_empty() and was != loot else ""]
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
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	for id in Content.ARKS:
		var a: Dictionary = Content.ARKS[id]
		var b := _tile(a.name, a.says.replace("。", "\n"), Style.AMBER, Vector2(272, 190))
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
	var box := _open("到了%s！" % lv.name, "撑过 %d 轮：第 %s 轮来小首领，最后一轮是首领" % [Content.ROUNDS,
		"、".join(Content.MINI_ROUNDS.map(func(r: int) -> String: return str(r)))])
	var lines: Array = ["%s：%s" % [rule.name, rule.says]] + ground
	if level == 0:
		lines.push_front("阵地：家园最上面两排只能造巢。兵打仗时就站在巢的位置，最上面一排在最前")
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Style.panel(26.0))
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sheet)
	var text := _label("\n".join(lines), 19, Fonts.serif(600), Style.PARCHMENT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_theme_constant_override("line_spacing", 8)
	sheet.add_child(text)
	var b := _button("开始", Vector2(190, 54), 21, true)
	b.pressed.connect(func() -> void: chosen.emit("开始"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	await chosen
	_close()


## The relics offered when a place is held, one to choose -- a boss's ringed red, with what it costs: its id.
func choose_relic(ids: Array) -> String:
	var box := _open("%s守住了！" % Content.LEVELS[game.run.place].name, "选一件遗物，整局都有用。红边的是首领留下的：很强，但有代价")
	offered = ids.duplicate()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for id in ids:
		var r: Dictionary = Content.RELICS[id]
		var boss: bool = r.get("boss", false)
		var b := _tile(r.name, ("首领遗物\n" if boss else "化石遗物\n") + r.says.replace("；", "\n"), r.color, Vector2(250, 190),
			BOSS if boss else Style.GOLD)
		b.pressed.connect(func() -> void: chosen.emit(id))
		row.add_child(b)
	var v: Variant = await chosen
	_close()
	return str(v)


## A skull, `at` its middle: how dangerous a wave looks.
func _skull(c: Control, at: Vector2, col: Color) -> void:
	c.draw_circle(at + Vector2(0, -1.5), 6.5, col)
	c.draw_rect(Rect2(at + Vector2(-4, 2), Vector2(8, 5)), col)
	for sx in [-2.6, 2.6]:
		c.draw_circle(at + Vector2(sx, -1.5), 1.9, Style.INK_DEEP)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, 0.8), at + Vector2(-1.2, 2.8), at + Vector2(1.2, 2.8)]), Style.INK_DEEP)
	for tx in [-2.0, 0.0, 2.0]:
		c.draw_line(at + Vector2(tx, 4.6), at + Vector2(tx, 7.0), Style.INK_DEEP, 1.0)


## The deck the shop draws from, laid out to look at (while planning) -- upgraded cards marked +.
func show_deck() -> void:
	if screen != "":
		return
	var home: Home = game.home
	var cards: Array = home.deck.map(func(card: Dictionary) -> Dictionary: return Home._good(card))
	await choose("牌库（%d 张）" % cards.size(), "商店每轮从这里抽货。每轮打完可以加一张；小首领打完可以删、可以强化", cards, ["关闭"], false)


## After a place's mini-boss: the deck laid out to work on -- a card picked, then cut (gold, dearer each time) or
## upgraded (research points); or done. What was asked: {cut: k} or {upgrade: k} (k: the card's place in the deck), or
## "完成".
func workshop() -> Variant:
	var home: Home = game.home
	var box := _open("整理牌库", "删一张 %d 金（每删一张，下一张贵 %d 金）；强化一张 %d 研究点数。现在有 %d 金、%d 研究点数" % [
		home.cut_price(), Content.CUT_STEP, Content.UPGRADE, home.gold, home.genes])
	offered = home.deck.duplicate(true)
	var grid := GridContainer.new()
	grid.columns = mini(home.deck.size(), 9)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	var k := 0.66 if home.deck.size() <= 18 else 0.56
	var views: Array = []
	var picked := {"k": -1}
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var cut := _button("删掉这张（%d 金）" % home.cut_price(), Vector2(210, 50), 18)
	var up := _button("强化这张（%d 研究点数）" % Content.UPGRADE, Vector2(250, 50), 18)
	var done := _button("完成", Vector2(170, 50), 19, true)
	var update := func() -> void:
		var p: int = picked.k
		cut.disabled = p < 0 or home.gold < home.cut_price()
		up.disabled = p < 0 or not home.can_upgrade(p)
		for i in views.size():
			(views[i] as CardView).set_state(true, i == p)
	for i in home.deck.size():
		var slot := Control.new()
		slot.custom_minimum_size = CardView.SIZE * k
		grid.add_child(slot)
		var v := CardView.new()
		slot.add_child(v)
		v.setup(Home._good(home.deck[i]))
		v.pivot_offset = Vector2.ZERO
		v.scale = Vector2.ONE * k
		var at := i
		v.clicked.connect(func(_v: CardView) -> void:
			picked.k = at
			update.call())
		views.append(v)
	# Pointed at, the upgrade shows the card picked as it would be.
	up.mouse_entered.connect(func() -> void:
		if picked.k >= 0 and not up.disabled:
			(views[picked.k] as CardView).show_as({"id": home.deck[picked.k].id, "plus": true}))
	up.mouse_exited.connect(func() -> void:
		if picked.k >= 0:
			(views[picked.k] as CardView).show_as(Home._good(home.deck[picked.k])))
	cut.pressed.connect(func() -> void: chosen.emit({"cut": picked.k}))
	up.pressed.connect(func() -> void: chosen.emit({"upgrade": picked.k}))
	done.pressed.connect(func() -> void: chosen.emit("完成"))
	row.add_child(cut)
	row.add_child(up)
	row.add_child(done)
	box.add_child(row)
	update.call()
	var answer: Variant = await chosen
	_close()
	return answer


## The map, after a place is held: the run's levels in three columns -- the places come to lit, the roads on from here
## gold -- and the next level's two places to pick one of: pointed at or clicked, what it is like is shown beside it;
## "去这里" goes. The place picked (Content.LEVELS).
func choose_place(run: Run) -> int:
	var box := _open("下一站去哪？", "越往右越难。选好了，再回家园挑要带走的东西")
	offered = run.next_places()
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	box.add_child(body)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Style.panel(18.0))
	body.add_child(frame)
	var map := Control.new()
	map.custom_minimum_size = Vector2(620, 360)
	frame.add_child(map)
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", Style.panel(20.0, true))
	detail.custom_minimum_size = Vector2(340, 0)
	body.add_child(detail)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 8)
	detail.add_child(dbox)
	var heading := _label("指着一处看看", 26, Fonts.serif(900), Style.GOLD_BRIGHT)
	dbox.add_child(heading)
	var text := _label("", 16, Fonts.serif(500), Style.PARCHMENT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text.custom_minimum_size = Vector2(300, 0)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("line_spacing", 6)
	dbox.add_child(text)
	var go := _button("去这里", Vector2(220, 52), 21, true)
	go.disabled = true
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dbox.add_child(go)
	var pick := {"place": -1, "near": -1}
	var cols := [90.0, 310.0, 530.0]
	var at := {}
	for t in run.map.size():
		var places: Array = run.map[t]
		for i in places.size():
			at[places[i]] = Vector2(cols[t], 190.0 if places.size() == 1 else 120.0 + i * 150.0)
	var show := func(p: int) -> void:
		heading.text = Content.LEVELS[p].name
		text.text = _place_text(p)
	map.draw.connect(func() -> void:
		var f := Fonts.serif(800)
		for t in run.map.size():
			var head := "第 %d 关" % (t + 1)
			var w := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			map.draw_string(f, Vector2(cols[t] - w * 0.5, 26), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.PARCHMENT_DIM)
			for k in t + 1:
				_skull(map, Vector2(cols[t] - t * 8.5 + k * 17, 46), Color(Style.CORAL, 0.75))
		# The roads: gold on from where the ark is, faint beyond.
		for t in run.map.size() - 1:
			for a in run.map[t]:
				for b in run.map[t + 1]:
					var from: Vector2 = at[a]
					var to: Vector2 = at[b]
					var on: bool = t == run.level and a == run.place
					var lit: bool = on and (b == pick.place or b == pick.near)
					var col := Style.GOLD_BRIGHT if lit else (Color(Style.GOLD, 0.8) if on else Color(Style.GOLD_DIM, 0.35))
					var n := int(from.distance_to(to) / 12.0)
					for s in n:
						if s % 2 == 0:
							map.draw_line(from.lerp(to, float(s) / n), from.lerp(to, float(s + 1) / n), col, 3.0 if lit else 2.0, true)
		# The places: a medallion each -- lit where the ark has been, dim where it can no longer go.
		for t in run.map.size():
			for p in run.map[t]:
				var c: Vector2 = at[p]
				var been: bool = t < run.path.size() and run.path[t] == p
				var next: bool = t == run.level + 1
				var col: Color = Content.LEVELS[p].color
				if not been and not next:
					col = col.lerp(Color(0.2, 0.2, 0.2), 0.55)
				if p == pick.place or p == pick.near:
					for g in 4:
						map.draw_arc(c, 38.0 + g * 3.0, 0.0, TAU, 48, Color(Style.GOLD_BRIGHT, 0.35 * (1.0 - g / 4.0)), 3.0, true)
				map.draw_circle(c + Vector2(0, 3), 36.0, Color(0, 0, 0, 0.45))
				map.draw_circle(c, 36.0, Style.INK_DEEP)
				map.draw_arc(c, 34.0, 0.0, TAU, 56, Style.GOLD if been or next else Style.GOLD_DIM, 2.0, true)
				map.draw_circle(c, 29.0, col)
				var word: String = Content.LEVELS[p].name
				var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
				map.draw_string_outline(f, c + Vector2(-ww * 0.5, 8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
				map.draw_string(f, c + Vector2(-ww * 0.5, 8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Style.PARCHMENT)
				if been and t == run.level:
					var tag := "方舟在这里"
					var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
					map.draw_string(f, c + Vector2(-tw * 0.5, 58), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.GOLD_BRIGHT))
	# The next level's places, to point at and pick.
	for p in run.next_places():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 84)
		b.size = Vector2(84, 84)
		b.position = (at[p] as Vector2) - Vector2(42, 42)
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		var place: int = p
		b.mouse_entered.connect(func() -> void:
			pick.near = place
			show.call(place)
			map.queue_redraw())
		b.mouse_exited.connect(func() -> void:
			pick.near = -1
			if pick.place >= 0:
				show.call(pick.place)
			map.queue_redraw())
		b.pressed.connect(func() -> void:
			pick.place = place
			go.disabled = false
			go.text = "去%s" % Content.LEVELS[place].name
			show.call(place)
			map.queue_redraw())
		map.add_child(b)
	go.pressed.connect(func() -> void: chosen.emit(pick.place))
	var v: Variant = await chosen
	_close()
	return int(v)


## What a place is like, for the map: its rule, its special ground, who comes there.
func _place_text(p: int) -> String:
	var lv: Dictionary = Content.LEVELS[p]
	var rule: Dictionary = Content.RULES[lv.rule]
	var ground: Array = []
	for t in lv.terrain:
		ground.append("%s：%s" % [Content.TERRAIN[t].name, Content.TERRAIN[t].says])
	var foes: Array = lv.mix.map(func(m: Array) -> String: return Content.ENEMIES[m[0]].name)
	var minis: Array = lv.minis.map(func(k: String) -> String: return Content.ENEMIES[k].name)
	return "%s：%s\n\n%s\n\n会来：%s\n小首领：%s\n首领：%s" % [rule.name, rule.says, "\n".join(ground), "、".join(foes),
		"、".join(minis), Content.ENEMIES[lv.boss].name]


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
	for k in buttons.size():
		var b: String = buttons[k]
		var button := _button(b, Vector2(180, 52), 20, k == 0 and cards.is_empty())
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
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = Style.blur_shader()
	shade.material = m
	_overlay.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_overlay.add_child(box)
	var head := Style.heading(title, 42)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(head)
	box.add_child(_label(sub, 19, Fonts.serif(600), Style.PARCHMENT_DIM))
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.25)
	return box


## A choice drawn as a tile: a diamond of its colour, its name over a rule, then what it does -- a button, lit when
## pointed at (its edge `edge`: coral for a boss's).
func _tile(name: String, says: String, accent: Color, size: Vector2, edge := Style.GOLD) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed"]:
		var box := Style.button(s)
		box.cut = 12.0
		box.inset = 5.0
		if edge != Style.GOLD:
			box.edge = edge.lightened(0.2) if s == "hover" else edge
			box.rule = Color(edge, 0.45)
			box.glow = Color(edge, 0.35) if s == "hover" else box.glow
		b.add_theme_stylebox_override(s, box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -14
	var gem := Control.new()
	gem.custom_minimum_size = Vector2(0, 18)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.draw.connect(func() -> void: Style.diamond(gem.get_canvas_item(), Vector2(gem.size.x * 0.5, 9), 8.0, accent, Style.INK_DEEP))
	col.add_child(gem)
	var title := _label(name, 23, Fonts.serif(900), Style.GOLD_BRIGHT)
	col.add_child(title)
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func() -> void: Style.rule(line, Vector2(line.size.x * 0.5, 5), line.size.x * 0.8, Color(edge, 0.8)))
	col.add_child(line)
	var text := _label(says, 16, Fonts.serif(600), Style.PARCHMENT)
	text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text.add_theme_constant_override("line_spacing", 4)
	col.add_child(text)
	return b


func _close() -> void:
	screen = ""
	offered = []
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.visible = false
	_hand.visible = true


# -- Pieces -----------------------------------------------------------------------------------------------------

## The gold: a big coin, struck with a ring and four diamonds, the gold on it in Roman figures; under it, what comes in
## each round and the interest on what is kept.
func _draw_gold() -> void:
	var home: Home = game.home
	var c := Vector2(60, 58)
	_gold.draw_circle(c + Vector2(0, 4), 53.0, Color(0, 0, 0, 0.4))
	_gold.draw_circle(c, 53.0, Color(0.15, 0.1, 0.04))
	_gold.draw_circle(c, 50.5, Color(0.58, 0.41, 0.14))
	for i in 9:
		_gold.draw_circle(c + Vector2(-0.6, -0.8) * i, 47.0 - i * 4.4, Color(0.74, 0.54, 0.2).lerp(Color(1.0, 0.86, 0.5), i / 8.0))
	_gold.draw_arc(c, 40.0, 0.0, TAU, 64, Color(0.5, 0.33, 0.1, 0.85), 1.6, true)
	_gold.draw_arc(c, 43.0, 0.0, TAU, 64, Color(1.0, 0.93, 0.7, 0.35), 1.0, true)
	for k in 4:
		Style.diamond(_gold.get_canvas_item(), c + Vector2.from_angle(PI * 0.25 + k * PI * 0.5) * 40.0, 3.2, Color(0.5, 0.33, 0.1))
	_gold.draw_arc(c, 46.0, PI * 1.05, PI * 1.45, 16, Color(1, 1, 1, 0.4), 3.0, true)
	var f := Fonts.display(900)
	var text := "%d" % home.gold
	var size_px := 38 if text.length() < 3 else 30
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_gold.draw_string(f, c + Vector2(-w * 0.5, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1.0, 0.95, 0.75, 0.55))
	_gold.draw_string(f, c + Vector2(-w * 0.5, 12.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.3, 0.17, 0.02))
	var lf := Fonts.serif(700)
	for line in [["金币 · 每轮 +%d" % home.income_gold(), 128.0], ["存着，利息 +%d" % home.interest(), 146.0]]:
		var lw := lf.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_gold.draw_string_outline(lf, Vector2(60 - lw * 0.5, line[1]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
		_gold.draw_string(lf, Vector2(60 - lw * 0.5, line[1]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.GOLD_BRIGHT)


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



## The homeland's health: a bar in a gold-ruled groove, jade -- coral when low.
func _draw_hp() -> void:
	var home: Home = game.home
	var r := Rect2(Vector2(2, 4), Vector2(250, 22))
	var ci := _hp.get_canvas_item()
	Style.fill(ci, r.grow(2.0), 5.0, Color(0.02, 0.025, 0.03, 0.95), Color(0.06, 0.07, 0.07, 0.95))
	var frac := clampf(float(home.hp) / maxf(1.0, home.hp_max()), 0.0, 1.0)
	var col := Style.CORAL if frac < 0.35 else Color(0.36, 0.72, 0.48)
	if frac > 0.0:
		Style.fill(ci, Rect2(r.position, Vector2(maxf(8.0, r.size.x * frac), r.size.y)), 4.0, col.lightened(0.18), col.darkened(0.3))
	Style.ring(ci, r.grow(2.0), 5.0, Style.GOLD, 1.2)
	var f := Fonts.serif(800)
	var text := "家园 %d / %d" % [home.hp, home.hp_max()]
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_hp.draw_string_outline(f, Vector2(r.get_center().x - w * 0.5, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	_hp.draw_string(f, Vector2(r.get_center().x - w * 0.5, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


## A button in the house style (Style.theme) -- `primary` amber, for what sends things on.
func _button(text: String, min_size: Vector2, size_px: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	if primary:
		b.theme_type_variation = "Primary"
	b.add_theme_font_size_override("font_size", size_px)
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



