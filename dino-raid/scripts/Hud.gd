class_name Hud
extends CanvasLayer
## What the player holds and reads (GAME-DESIGN 17, 18, 24), all over the homeland on one screen: the shop's shelf
## along the bottom, a star dinosaur on offer after it; the goods the hoarder keeps for later in a row over the
## buttons; the gold, the button that restocks the shelf, the button that sends the army out; the place, the round, the
## homeland's health, the biomass and genes at the top left; who comes this battle and the next, how this battle will
## go as things stand, and what the cursor points at, at the top right; a battle's count and clock; a star dinosaur's
## own screen (to sell it); when a place is held, the star to choose and the map; at a new place, its painting and its
## ground. All in the one look (Style, GAME-DESIGN 21). It shows; Game decides.

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
var _hovered: CardView
var _gold: Control
var _reroll: HudParts.RoundButton
var _go: HudParts.RoundButton
var _left: VBoxContainer           # top left: the crest, the purse, the relics and the schools' gifts, the wonders
var _crest: HudParts.Crest
var _purse: HudParts.Purse
var _menu: HudParts.RoundButton
var _banner_rule: Control
var _army: HudParts.ArmyTag
var _deck_button: HudParts.RoundButton
var _choice: PanelContainer
var _track: HudParts.Track         # the round's parts, at the top
var _choice_buttons := {}         # "count", "elite" -> its button

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
var _battle: HBoxContainer
var _versus: HudParts.Versus
var _speed: HudParts.RoundButton
var _point := ""                 # what of the HUD's own the cursor points at (_point_tip), "" nothing
var _point_count := 0            # ...a monster of a wave: how many of it
var _star_card: CardView         # the star dinosaur on offer, after the shelf (null: none)
var _overlay: Control
var _shade: ColorRect
var _stowed := false             # the shelf put away below the screen (in a battle)
var screen := ""                 # the title of the screen up, "" when none (for tools)
var offered: Array = []          # what the screen up offers to choose from: offers, star or place ids (for tools)


func setup(p_game: Game) -> void:
	game = p_game
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Style.theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS    # the made frames shown at half their size
	add_child(_root)
	var edges := ColorRect.new()
	edges.set_anchors_preset(Control.PRESET_FULL_RECT)
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var em := ShaderMaterial.new()
	em.shader = Style.edge_shader()
	edges.material = em
	_root.add_child(edges)

	# Top left: where we are, and what the homeland has. (Its star dinosaurs stand in their pens beside it: HomeView.)
	_left = VBoxContainer.new()
	_left.position = Vector2(16, 12)
	_left.add_theme_constant_override("separation", 6)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_left)
	_crest = HudParts.Crest.new()
	_crest.mouse_entered.connect(func() -> void: _point = "place")
	_crest.mouse_exited.connect(func() -> void: _point = "")
	_left.add_child(_crest)
	_purse = HudParts.Purse.new()
	_purse.pointed.connect(func(which: String) -> void: _point = which)
	_left.add_child(_purse)


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
	_info_text.autowrap_mode = Style.wrap()
	_info_text.custom_minimum_size = Vector2(300, 0)
	_info.add_child(_info_text)

	# Bottom: the shelf, the gold, the buttons.
	_hand = Control.new()
	_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hand)
	_gold = Control.new()
	_gold.custom_minimum_size = Vector2(130, 56)
	_gold.size = Vector2(130, 56)
	_gold.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gold.position = Vector2(20, -258)
	_gold.mouse_filter = Control.MOUSE_FILTER_PASS
	_gold.mouse_entered.connect(func() -> void: _point = "gold")
	_gold.mouse_exited.connect(func() -> void: _point = "")
	_gold.draw.connect(_draw_gold)
	_root.add_child(_gold)
	# Bottom right: the deck and a fresh shelf, round buttons; the great seal that sends the army out, the army over it.
	_deck_button = _round(HudParts.RoundButton.new(Icons.DECK, "牌库", 26.0), Vector2(-265, -230), "deck")
	_deck_button.pressed.connect(func() -> void: show_deck())
	_reroll = _round(HudParts.RoundButton.new(Icons.REFRESH, "刷新", 26.0), Vector2(-265, -138), "reroll")
	_reroll.pressed.connect(func() -> void: game.act("reroll"))
	_go = _round(HudParts.RoundButton.new(Icons.BATTLE, "出战！", 50.0, true), Vector2(-172, -184), "")
	_go.pressed.connect(func() -> void: game.act("fight"))
	_army = HudParts.ArmyTag.new()
	_army.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_army.position = Vector2(-180, -222)
	_army.mouse_entered.connect(func() -> void: _point = "army")
	_army.mouse_exited.connect(func() -> void: _point = "")
	_root.add_child(_army)
	# Bottom left, under the gold: the pause menu (Esc does the same).
	_menu = HudParts.RoundButton.new(Icons.MENU, "菜单", 17.0)
	_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_menu.position = Vector2(46, -70)
	_menu.pressed.connect(func() -> void: game.pause())
	_root.add_child(_menu)
	_hint = _label("", 17, Fonts.serif(700), Style.GOLD_BRIGHT)
	_hint.add_theme_stylebox_override("normal", Style.Streak.new(8.0))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.autowrap_mode = Style.wrap()
	_hint.custom_minimum_size = Vector2(780, 0)
	_hint.position = Vector2(-60, -236)
	_root.add_child(_hint)

	# The round's parts, the one it is in lit (at home; the battle has its own bar there).
	_track = HudParts.Track.new()
	_track.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_track.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_track.position = Vector2(-_track.size.x * 0.5, 8)
	_root.add_child(_track)

	# A battle: our side and theirs either side of the clock, and the speed.
	_battle = HBoxContainer.new()
	_battle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_battle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_battle.position = Vector2(0, 6)
	_battle.alignment = BoxContainer.ALIGNMENT_CENTER
	_battle.add_theme_constant_override("separation", 2)
	_battle.visible = false
	_root.add_child(_battle)
	_versus = HudParts.Versus.new()
	_battle.add_child(_versus)
	_speed = HudParts.RoundButton.new(Icons.SPEED, "快进", 18.0)
	_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed.pressed.connect(func() -> void:
		game.speed = 3.0 if game.speed < 2.0 else 1.0
		_speed.caption = "正常" if game.speed > 1.0 else "快进"
		_speed.queue_redraw())
	_battle.add_child(_speed)

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
	for pair in [["count", "多孵 1 只"], ["elite", "变精英"]]:
		var b := _button(pair[1], Vector2(150, 46), 17)
		var choice: String = pair[0]
		_choice_buttons[choice] = b
		b.mouse_entered.connect(func() -> void: game.aim(choice))
		b.mouse_exited.connect(func() -> void:
			if game.aimed == choice:
				game.aim(""))
		b.pressed.connect(func() -> void: game.act("choose", {"choice": choice}))
		choice_row.add_child(b)

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
	var tip := game.describe() if _hovered == null and not _overlay.visible else ""
	if not _overlay.visible:
		if _point != "":
			tip = _point_tip()
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
		_versus.ours = f.alive("ours").size()
		_versus.theirs = f.alive("theirs").size()
		_versus.left = maxf(0.0, Fight.LIMIT - f.time)
		_versus.limit = Fight.LIMIT
		_versus.queue_redraw()


## The shelf, as cards: a place still showing what it showed keeps its card (so nothing jumps); a place bought from
## shows an empty frame; a restocked one, the new offer. Brought back up if it was put away.
## The language changed: what was put together in words made again -- the cards, the wonders, the waves -- the rest
## follows by itself (words shown as they are change with the language).
func relanguage() -> void:
	for v in _cards + _kept + ([_star_card] if _star_card != null else []):
		if not is_instance_valid(v):
			continue
		var card := v as CardView
		if card.star != "":
			card.setup_star(card.star)
		elif not card.sold and not card.ci.is_empty():
			card.setup(card.ci, card.kept)
		card.queue_redraw()
	for l in [_hint, _info_text]:
		(l as Label).autowrap_mode = Style.wrap()
	_waves_for = ""
	refresh()


func deal(shelf: Array) -> void:
	_stowed = false
	var out: Array = []
	var dealt := 0                 # new cards so far: each flies from the deck a little after the one before
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
			# Dealt from the deck (its pile at the bottom right): face down, small, turned aside; it waits its turn,
			# flies to its place and turns over as it lands.
			var deck := _deck_button.global_position + Vector2(_deck_button.size.x * 0.5, 30.0) - _hand.global_position
			v.position = deck - v.pivot_offset
			v.scale = Vector2.ONE * 0.24
			v.rotation = -0.7
			v.set_meta("deal_at", Time.get_ticks_msec() + dealt * 85)
			v.turn_over(0.16 + dealt * 0.085, 0.3)
			dealt += 1
		out.append(v)
	for i in range(shelf.size(), _cards.size()):
		_fly_off(_cards[i], false)
	_cards = out
	# The star dinosaur on offer, after the shelf: dealt like the rest; bought, it rises off; restocked, it drops.
	var star: String = game.home.star_offer
	if _star_card != null and _star_card.star != star:
		_fly_off(_star_card, star == "")
		_star_card = null
	if _star_card == null and star != "":
		var v := CardView.new()
		_hand.add_child(v)
		v.setup_star(star)
		v.clicked.connect(_on_card)
		v.hovered.connect(_on_hover)
		var deck := _deck_button.global_position + Vector2(_deck_button.size.x * 0.5, 30.0) - _hand.global_position
		v.position = deck - v.pivot_offset
		v.scale = Vector2.ONE * 0.24
		v.rotation = -0.7
		v.set_meta("deal_at", Time.get_ticks_msec() + dealt * 85)
		v.turn_over(0.16 + dealt * 0.085, 0.3)
		_star_card = v
	if _hovered and not _hovered in _cards and not _hovered in _kept and _hovered != _star_card:
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
	var away := fighting or game.phase == Game.Phase.MOVE     # the army out, or on the way to the next place
	_refresh_kept()
	var used := home.pop_used()
	var cap := home.pop_cap()
	for i in _cards.size():
		var v: CardView = _cards[i]
		if not v.sold:
			v.genes_shown = home.genes_cost(v.c)
			v.pop_need = Content.pop_of(v.c)
			v.purse = {"gold": home.gold, "genes": home.genes, "used": used, "cap": cap}
			v.set_state(planning and not game.fits_of(i).is_empty(), game.held == i)
	for k in _kept.size():
		var v: CardView = _kept[k]
		v.pop_need = Content.pop_of(v.c)
		v.purse = {"used": used, "cap": cap}
		v.set_state(planning and not game.fits_of(k, true).is_empty(), game.held_k == k)
	if _star_card != null:
		_star_card.purse = {"gold": home.gold, "used": used, "cap": cap}
		if _star_card.star != "":
			_star_card.pop_need = home.star_need(_star_card.star)
		_star_card.set_state(planning and home.can_buy_star(), false)
	_go.disabled = not planning
	_go.visible = not away
	_go.queue_redraw()
	var price := home.reroll_price()
	_reroll.cost = price
	_reroll.enough = home.gold >= price
	_reroll.disabled = not planning or home.gold < price
	_reroll.visible = not away
	_reroll.queue_redraw()
	_menu.visible = not fighting
	_gold.visible = not fighting
	_gold.queue_redraw()
	var lv: Dictionary = Content.LEVELS[run.place]
	_crest.place_name = Lang.t(lv.name)
	_crest.glyph = Icons.PLACES[run.place] if run.place < Icons.PLACES.size() else ""
	_crest.round = run.round
	_crest.rounds = run.rounds()
	_crest.minis = Content.MINI_ROUNDS
	_crest.queue_redraw()
	_purse.hp = home.hp
	_purse.hp_max = home.hp_max()
	_purse.pop_used = used
	_purse.pop_cap = cap
	_purse.research = home.genes
	_purse.queue_redraw()
	_army.count = game.army_now().size()
	_army.food = Home.food_of(game.army_now())
	_army.visible = not away
	_army.queue_redraw()
	_deck_button.visible = not away
	_deck_button.disabled = not planning
	_deck_button.count = str(home.deck.size())
	_deck_button.queue_redraw()
	_choice.visible = planning and not game.pending.is_empty()
	_track.part = game.part
	_track.visible = not away and game.phase != Game.Phase.DONE
	_track.queue_redraw()
	if _choice.visible:
		_choice_buttons.count.disabled = not game.count_fits()
	_battle.visible = fighting and not game.at_home
	for k in _kept.size():
		_kept[k].visible = not away and planning
	_waves.visible = not away
	_hint.text = game.hint()
	_hint.visible = _hint.text != ""
	_refresh_waves()
	_refresh_forecast()



func _refresh_waves() -> void:
	var run: Run = game.run
	var key := "%d/%d" % [run.level, run.round]
	if key == _waves_for:
		return
	_waves_for = key
	for ch in _waves.get_children():
		ch.queue_free()
	_waves.add_child(_wave_card(Lang.t("这一仗"), _big(run, 0), run.wave(), true))
	if run.round < run.rounds():
		_waves.add_child(_wave_card(Lang.t("下一仗"), _big(run, 1), run.wave(1), false))


## What a wave is, if more than any other: a boss's, a mini-boss's, a big one ("" none).
func _big(run: Run, ahead: int) -> String:
	if run.round + ahead >= run.rounds():
		return Lang.t("首领")
	if run.round + ahead in Content.MINI_ROUNDS:
		return Lang.t("小首领")
	return Lang.t("大波") if run.big(ahead) else ""


## A wave as a card (HudParts.WaveCard): pointed at, a monster in it is told about.
func _wave_card(title: String, tag: String, wave: Array, now: bool) -> Control:
	var card := HudParts.WaveCard.new()
	card.setup(title, tag, Content.danger(wave, game.run.power()), now, wave)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.pointed.connect(func(kind: String) -> void:
		_point = ("e:" + kind) if kind != "" else ""
		for pair in card.kinds:
			if pair[0] == kind:
				_point_count = int(pair[1]))
	return card


## What the HUD's own figure pointed at is (_point).
func _point_tip() -> String:
	var home: Home = game.home
	var run: Run = game.run
	if _point.begins_with("e:"):
		var e: Dictionary = Content.ENEMIES[_point.substr(2)]
		return Lang.t("%s ×%d") % [Lang.t(e.name), _point_count]
	match _point:
		"place":
			return "%s\n%s" % [Lang.t(Content.LEVELS[run.place].name), _ground_text(run.place)]
		"hp":
			return Lang.t("家园 %d / %d\n打输了会掉，掉光这一局就输了") % [home.hp, home.hp_max()]
		"pop":
			return Lang.t("人口 %d / %d\n每轮产的生物质养得活这么多：兵吃 %d，明星恐龙吃 %d") % [home.pop_used(), home.pop_cap(),
				home.pop_used() - home.star_food(), home.star_food()]
		"research":
			return Lang.t("研究点数 %d\n生产时 +%d；贴词条、强化牌要花") % [home.genes, home.income_genes()]
		"gold":
			return Lang.t("金币 %d\n开始时 +%d，利息 +%d；生产时 +%d") % [home.gold, Home.INCOME, home.interest(),
				home.income_gold()]
		"army":
			var said := Lang.t("这一轮出战 %d 只，吃 %d 生物质") % [game.ahead().fighters.size(),
				Home.food_of(game.ahead().fighters)]
			var more := game.bonuses()
			return said + ("\n" + more if more != "" else "")
		"deck":
			return Lang.t("牌库（%d 张）") % home.deck.size()
		"reroll":
			var price := home.reroll_price()
			return Lang.t("刷新（%s）") % (Lang.t("免费") if price == 0 else Lang.t("%d 金") % price)
	return ""


## A round button put at `at` from the bottom right corner; pointed at, `point` is told about.
func _round(b: HudParts.RoundButton, at: Vector2, point: String) -> HudParts.RoundButton:
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = at
	if point != "":
		b.mouse_entered.connect(func() -> void: _point = point)
		b.mouse_exited.connect(func() -> void: _point = "")
	_root.add_child(b)
	return b


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
	_fc_loot.text = Lang.t("拾荒兽带回 %d 金%s") % [loot, (Lang.t("（现在 %d）") % was) if not p.is_empty() and was != loot else ""]
	_fc_more.text = (Lang.t("现在是：") + _verdict(f)) if not p.is_empty() else "（每一仗都照规矩打，结果算得出来）"


func _verdict(f: Dictionary) -> String:
	if f.result == "won":
		return Lang.t("赢，站着的还有 %d / %d 个") % [f.left, f.total]
	if int(f.total) == 0:
		return Lang.t("没有兵出战，家园 −%d") % f.harm
	if f.result == "time":
		return Lang.t("拖到时间算输，家园 −%d") % f.harm
	return Lang.t("输，家园 −%d") % f.harm


## Where the stash's k-th card stands (its bottom middle): in a row leftward from over the buttons.
func _kept_at(k: int, lifted: bool) -> Vector2:
	var w := CardView.SIZE.x * KEPT_SCALE
	return Vector2(_root.size.x - 330.0 - k * (w + 8.0), _root.size.y - 250.0 - (14.0 if lifted else 0.0))


## The shelf laid out flat along the bottom, between the gold and the buttons, the star on offer after it; the stash
## in a row over the buttons; the card pointed at lifted and larger, the one taken up raised.
func _layout() -> void:
	var w := _root.size.x
	var h := _root.size.y
	var n := _cards.size()
	var all := n + (1 if _star_card != null else 0)
	var gap := minf(150.0, (w - 640.0) / maxf(1.0, all - 1))
	var shelf := _cards.duplicate()
	if _star_card != null:
		shelf.append(_star_card)
	for i in shelf.size():
		var v: CardView = shelf[i]
		if v.modulate.a < 0.99 and v.mouse_filter == Control.MOUSE_FILTER_IGNORE and not v.sold:
			continue
		if v.has_meta("deal_at") and Time.get_ticks_msec() < int(v.get_meta("deal_at")):
			continue
		var off := i - (all - 1) * 0.5
		var x := w * 0.5 - 70.0 + off * gap + (16.0 if v == _star_card else 0.0)
		var y := h + 40.0 + (260.0 if _stowed else 0.0)
		var k := SHELF_SCALE
		var tilt := 0.0
		if v == _hovered:
			y -= 110.0
			k = HOVER_SCALE
			# Leaning a little toward where the cursor is on it.
			var local := (_root.get_local_mouse_position().x - x) / (CardView.SIZE.x * k)
			tilt = clampf(local, -0.5, 0.5) * 0.09
		elif game.held == i:
			y -= 44.0
		else:
			# At rest, the cards drift a hair up and down, each in its own time.
			y += sin(Time.get_ticks_msec() * 0.0016 + i * 1.3) * 2.0
		_move(v, Vector2(x, y), k, 10 if v == _hovered else i, tilt)
	for k in _kept.size():
		var v: CardView = _kept[k]
		var at := _kept_at(k, game.held_k == k)
		var s := KEPT_SCALE
		if v == _hovered:
			s = SHELF_SCALE
			at.x = maxf(at.x, 18.0 + CardView.SIZE.x * s * 0.5)
		_move(v, at, s, 20 if v == _hovered else 0)


func _move(v: CardView, to_bottom: Vector2, k: float, z: int, tilt := 0.0) -> void:
	var to := to_bottom - v.pivot_offset
	v.position = v.position.lerp(to, 0.3)
	v.rotation = lerpf(v.rotation, tilt, 0.25)
	v.scale = v.scale.lerp(Vector2.ONE * k, 0.3)
	v.z_index = z


func _on_card(v: CardView) -> void:
	if v == _star_card:
		game.act("star")
		return
	var i := _cards.find(v)
	if i >= 0:
		game.hold(i)
		return
	var k := _kept.find(v)
	if k >= 0:
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


## The screen going dark (or light again), on the way between places.
func fade(dark: bool, time := 0.7) -> void:
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP if dark else Control.MOUSE_FILTER_IGNORE
	var tw := _shade.create_tween()
	tw.tween_property(_shade, "modulate:a", 1.0 if dark else 0.0, time)
	await tw.finished


# -- Screens ---------------------------------------------------------------------------------------------------

## A painting (tools/paint_cards.py: assets/art/<key>.<ext>), or null when there is none yet.
static func _art(key: String, ext := "jpg") -> Texture2D:
	return Art.of(key, ext)


## The place come to: its painting, its special ground in a line; dismissed with a button.
func arrive(level: int) -> void:
	var lv: Dictionary = Content.LEVELS[level]
	var box := _open(Lang.t("到了%s！") % Lang.t(lv.name), "")
	# The place painted (tools/paint_cards.py), in a hairline frame; under it what special ground lies about -- what
	# makes its homeland unlike another's. How its rounds go is there to be seen (the crest).
	var view := Control.new()
	view.custom_minimum_size = Vector2(640, 330)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pic := _art("place_" + PLACE_KEYS[clampi(level, 0, 5)])
	view.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, view.size)
		if pic != null:
			var ts := pic.get_size()
			var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
			var shown := r.size / k
			view.draw_texture_rect_region(pic, r, Rect2((ts - shown) * 0.5, shown))
		Style.hairline_rect(view.get_canvas_item(), r, Color(Style.GOLD, 0.5), Color(Style.GOLD_BRIGHT, 0.95), 12.0))
	box.add_child(view)
	var says := _label(_ground_text(level), 18, Fonts.serif(700), Style.PARCHMENT)
	box.add_child(says)
	var b := _button("开始", Vector2(190, 54), 21, true)
	b.pressed.connect(func() -> void: chosen.emit("开始"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	await chosen
	_close()
	enter()


## The special ground of place `level`, in a line: what lies about there.
func _ground_text(level: int) -> String:
	var names: Array = []
	for t in Content.LEVELS[level].terrain:
		names.append(Lang.t(Content.TERRAIN[t].name))
	return Lang.t("这里有：%s") % Lang.t("、").join(names)


## A star dinosaur shown to choose (HudParts.Showcase): its painting, or a medallion of its colour; its name, what it
## eats under it; what it does when pointed at.
func _star_item(id: String, note := "") -> HudParts.Showcase:
	var s: Dictionary = Content.STARS[id]
	var eats := Lang.t("每轮吃 %d") % int(s.eat) if int(s.eat) > 0 else Lang.t("不吃生物质")
	var item := HudParts.Showcase.new(_art("s_" + id), Lang.t(s.name), note if note != "" else eats,
		Lang.t("%s · %s · %s") % [Lang.t(s.kind), Lang.t(Content.DIETS[s.diet]), Lang.t(CardView.RARITY[int(s.rarity)])] + "\n" +
		Lang.t(s.says).replace("；", "\n").replace("; ", "\n"), false, Vector2(230, 330))
	item.tint = s.back
	item.glyph = Lang.t(s.name).left(1)
	item.note_short = int(s.rarity) == 3
	return item


## A star's pen pointed at and clicked: the star's own page, to sell it or keep it. "sell" or "".
func pen_menu(k: int) -> String:
	var home: Home = game.home
	var id: String = home.stars[k].id
	var hungry := k in home.hungry
	var can_sell := home.can_sell_star(k)
	var note := Lang.t("这一轮没吃饱，本事没起作用") if hungry else ""
	if not can_sell:
		note = Lang.t("它产的生物质养着别的，卖了人口就不够了")
	var box := _open(Lang.t(Content.STARS[id].name), note)
	var item := _star_item(id)
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_held(item))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var sell := _button(Lang.t("卖掉（+%d 金）") % home.sell_price(k), Vector2(190, 46), 18)
	sell.disabled = not can_sell
	sell.pressed.connect(func() -> void: chosen.emit("sell"))
	row.add_child(sell)
	var keep := _button("留着", Vector2(150, 46), 18, true)
	keep.pressed.connect(func() -> void: chosen.emit(""))
	row.add_child(keep)
	var v: Variant = await chosen
	_close()
	return str(v)


## A skull, `at` its middle: how dangerous a wave looks.
func _skull(c: Control, at: Vector2, col: Color) -> void:
	HudParts.skull(c, at, col)


## The deck the shop draws from, laid out to look at (while planning) -- upgraded cards marked +.
func show_deck() -> void:
	if screen != "":
		return
	var home: Home = game.home
	var cards: Array = home.deck.map(func(card: Dictionary) -> Dictionary: return Home._good(card))
	await choose(Lang.t("牌库（%d 张）") % cards.size(), "商店每轮从这里抽货。每轮打完可以加一张；小首领打完可以删、可以强化", cards, ["关闭"], false)


## After a place's mini-boss: the deck laid out to work on -- a card picked, then cut (gold, dearer each time) or
## upgraded (research points); or done. What was asked: {cut: k} or {upgrade: k} (k: the card's place in the deck), or
## "完成".
func workshop() -> Variant:
	var home: Home = game.home
	var box := _open("整理牌库", Lang.t("删一张 %d 金（每删一张，下一张贵 %d 金）；强化一张 %d 研究点数。现在有 %d 金、%d 研究点数") % [
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
	var cut := _button(Lang.t("删掉这张（%d 金）") % home.cut_price(), Vector2(210, 50), 18)
	var up := _button(Lang.t("强化这张（%d 研究点数）") % Content.UPGRADE, Vector2(250, 50), 18)
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
	var box := _open("下一站去哪？", "越往右越难。到了那里，家园重新建")
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
	# The place pointed at, painted, over its name.
	var view := Control.new()
	view.custom_minimum_size = Vector2(300, 170)
	view.set_meta("place", -1)
	view.draw.connect(func() -> void:
		var pic := _art("place_" + PLACE_KEYS[clampi(int(view.get_meta("place")), 0, 5)]) if int(view.get_meta("place")) >= 0 else null
		var r := Rect2(Vector2.ZERO, view.size)
		if pic != null:
			var ts := pic.get_size()
			var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
			var shown := r.size / k
			view.draw_texture_rect_region(pic, r, Rect2((ts - shown) * 0.5, shown))
		Style.hairline_rect(view.get_canvas_item(), r, Color(Style.GOLD, 0.45), Color(Style.GOLD_BRIGHT, 0.9), 10.0))
	dbox.add_child(view)
	var heading := _label("指着一处看看", 26, Fonts.serif(900), Style.GOLD_BRIGHT)
	dbox.add_child(heading)
	var text := _label("", 16, Fonts.serif(500), Style.PARCHMENT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = Style.wrap()
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
		view.set_meta("place", p)
		view.queue_redraw()
	map.draw.connect(func() -> void:
		var f := Fonts.serif(800)
		for t in run.map.size():
			var head := Lang.t("第 %d 关") % (t + 1)
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
				# Its own painting in a round window, a hairline round it -- faded where the ark can no longer go.
				map.draw_circle(c + Vector2(0, 3), 35.0, Color(0, 0, 0, 0.45))
				var pic := _art("place_" + PLACE_KEYS[clampi(p, 0, 5)])
				if pic != null:
					HudParts.window(map, c, 34.0, pic, 1.0, Vector2(0.5, 0.5),
						Color.WHITE if been or next else Color(0.45, 0.45, 0.45))
				else:
					map.draw_circle(c, 34.0, col)
				map.draw_arc(c, 34.0, 0.0, TAU, 56, Color(Style.GOLD_BRIGHT if been or next else Style.GOLD_DIM, 0.85), 1.2, true)
				var word: String = Lang.t(Content.LEVELS[p].name)
				var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
				map.draw_string_outline(f, c + Vector2(-ww * 0.5, 8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
				map.draw_string(f, c + Vector2(-ww * 0.5, 8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Style.PARCHMENT)
				if been and t == run.level:
					var tag := Lang.t("我们在这里")
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
			go.text = Lang.t("去%s") % Lang.t(Content.LEVELS[place].name)
			show.call(place)
			map.queue_redraw())
		map.add_child(b)
	go.pressed.connect(func() -> void: chosen.emit(pick.place))
	var v: Variant = await chosen
	_close()
	return int(v)


## The paintings of the places (Content.LEVELS, in order): assets/art/place_<key>.
const PLACE_KEYS := ["rain", "lava", "bog", "ice", "sand", "sea"]


## What a place is like, for the map: its special ground, who comes there.
func _place_text(p: int) -> String:
	var lv: Dictionary = Content.LEVELS[p]
	var ground: Array = []
	for t in lv.terrain:
		ground.append(Lang.t("%s：%s") % [Lang.t(Content.TERRAIN[t].name), Lang.t(Content.TERRAIN[t].says)])
	var foes: Array = lv.mix.map(func(m: Array) -> String: return Lang.t(Content.ENEMIES[m[0]].name))
	var minis: Array = lv.minis.map(func(k: String) -> String: return Lang.t(Content.ENEMIES[k].name))
	return Lang.t("%s\n\n会来：%s\n小首领：%s\n首领：%s") % ["\n".join(ground), Lang.t("、").join(foes),
		Lang.t("、").join(minis), Lang.t(Content.ENEMIES[lv.boss].name)]


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
		var i := 0
		for oi in cards:
			var slot := Control.new()
			slot.custom_minimum_size = CardView.SIZE * k
			grid.add_child(slot)
			var v := CardView.new()
			slot.add_child(v)
			v.setup(oi)
			# Turning about its middle: placed so that, k times its size, it fills the slot.
			v.pivot_offset = CardView.SIZE * 0.5
			v.scale = Vector2.ONE * k
			_fly_in(v, CardView.SIZE * 0.5 * (k - 1.0), i, cards.size())
			v.turn_over(0.24 + i * 0.09, 0.3)
			i += 1
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


## A control put in a holder of its size (in a row), so that it can fly about inside it as the row stays put.
func _held(c: Control) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = c.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(c)
	return holder


## `node` flying up into its place (`to`) from below the screen, the `i`-th of `n` -- each a little after the one
## before, from a little to its side, turning straight as it comes, overshooting a touch.
func _fly_in(node: Control, to: Vector2, i: int, n: int) -> void:
	node.pivot_offset = node.custom_minimum_size * 0.5 if node.pivot_offset == Vector2.ZERO else node.pivot_offset
	var spread := i - (n - 1) * 0.5
	node.position = to + Vector2(-spread * 60.0, 520.0)
	node.rotation = -spread * 0.22 + (0.18 if i % 2 == 0 else -0.18)
	node.modulate.a = 0.0
	var d := 0.08 + i * 0.09
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, "position", to, 0.55).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", 0.0, 0.55).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.16).set_delay(d)


## The HUD coming in round the homeland (a place begun): the crest and the purse from the left, the waves from the
## right, the coin up from below, the buttons in from the right -- one after another.
func enter() -> void:
	var parts: Array = [[_left, Vector2(-420, 0), 0.0], [_right, Vector2(380, 0), 0.08], [_gold, Vector2(0, 260), 0.14],
		[_army, Vector2(320, 0), 0.2], [_deck_button, Vector2(320, 0), 0.24], [_reroll, Vector2(320, 0), 0.28],
		[_go, Vector2(340, 0), 0.32], [_menu, Vector2(0, 160), 0.22]]
	for part in parts:
		var c: Control = part[0]
		var at := c.position
		c.position = at + (part[1] as Vector2)
		c.modulate.a = 0.0
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "position", at, 0.6).set_delay(part[2]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(part[2])


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
	# It comes up out of the blur: fading in, growing the last little way to its size.
	box.modulate.a = 0.0
	box.scale = Vector2.ONE * 0.965
	box.resized.connect(func() -> void: box.pivot_offset = box.size * 0.5)
	var tw := box.create_tween().set_parallel()
	tw.tween_property(box, "modulate:a", 1.0, 0.22)
	tw.tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shade.modulate.a = 0.0
	tw.tween_property(shade, "modulate:a", 1.0, 0.2)
	return box


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
	HudParts.veil(_gold, Rect2(-8, 0, 140, 56), 0.5, 18.0)
	Icons.draw(_gold, Icons.GOLD, Vector2(26, 28), 40.0)
	HudParts.words(_gold, Vector2(52, 28), str(home.gold), 30, Style.GOLD_BRIGHT, Fonts.numbers(), -1, 5)


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



