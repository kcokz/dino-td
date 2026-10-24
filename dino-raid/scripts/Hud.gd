class_name Hud
extends CanvasLayer
## What the player holds and reads (GAME-DESIGN 17, 18, 24, 27, 28), all over the homeland on one screen: the build
## bar along the bottom (a star dinosaur on offer after it, while there are stars); the gold and the interest it would
## bring, the button that sends the army out; the place, the round, the homeland's health, the population and the
## research points at the top left; who comes this battle and the next, and what the cursor points at, at the top
## right; a battle's count and clock; after a round, the blueprints to unlock one of; when a place is held, the map;
## at a new place, its painting and its ground, and its first nest to pick. All in the one look (Style, GAME-DESIGN
## 21). It shows; Game decides.

signal chosen(value: Variant)

const TECH_W := 74.0               # the tech tree's columns, at most...
const TECH_H := 96.0               # ...and rows

const WIN := Style.JADE
const LOSE := Style.CORAL
const CREAM := Style.PARCHMENT
const GOLD := Style.GOLD_BRIGHT
const BOSS := Style.CORAL

var game: Game
var _root: Control
var _bar: PanelContainer           # the build bar (GAME-DESIGN 27): the blueprints had, by group, and the star on offer
var _bar_groups := {}             # group (Content.GROUPS, and "star") -> its row of things
var _bar_for := ""                # what the bar was made for: the blueprints had, the star on offer, the language
var _plans: Array = []            # HudParts.Plan, one for each blueprint had (game.home.plans' order)
var _star_plan: HudParts.Plan     # the star dinosaur on offer (null: none)
var _bar_hot := ""                # what of the bar the cursor points at: "p<i>" (plans[i]), "star", or ""
var _bar_tip: PanelContainer      # a word over the bar on what is pointed at
var _bar_drop := 0.0              # how far below its place the bar is, coming in (enter)
var _bar_tip_text: Label
var _gold: Control
var _go: HudParts.RoundButton
var _tech: HudParts.RoundButton    # opens the tech tree (by the bar's left end)
var _left: VBoxContainer           # top left: the crest, the purse, the relics and the schools' gifts, the wonders
var _crest: HudParts.Crest
var _purse: HudParts.Purse
var _menu: HudParts.RoundButton
var _banner_rule: Control
var _army: HudParts.ArmyTag
var _choice: PanelContainer        # a building clicked: how it can be raised
var _choice_box: VBoxContainer
var _choice_for := ""
var _track: HudParts.Track         # the round's parts, at the top

var _right: VBoxContainer
var _waves: VBoxContainer
var _lane_map: HudParts.LaneMap   # under the waves: how the wave pointed at stands in the six lanes
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
var _overlay: Control
var _shade: ColorRect
var _stowed := false             # the build bar put away (in a battle)
var screen := ""                 # the title of the screen up, "" when none (for tools)
var teching := false             # the tech tree is up
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
	_lane_map = HudParts.LaneMap.new()
	right.add_child(_lane_map)
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

	# Bottom: the build bar, the gold, the buttons.
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", Style.panel(16.0))
	_root.add_child(_bar)
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 22)
	_bar.add_child(groups)
	for g in Content.GROUPS.keys() + ["star"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		groups.add_child(col)
		var head := _label(Content.GROUPS[g] if g != "star" else "明星", 13, Fonts.serif(800), Style.PARCHMENT_DIM)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		_bar_groups[g] = {"col": col, "row": row}
	_bar_tip = PanelContainer.new()
	_bar_tip.add_theme_stylebox_override("panel", Style.panel(10.0))
	_bar_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_tip.visible = false
	_root.add_child(_bar_tip)
	_bar_tip_text = _label("", 14, Fonts.serif(600), Style.PARCHMENT)
	_bar_tip_text.autowrap_mode = Style.wrap()
	_bar_tip_text.custom_minimum_size = Vector2(260, 0)
	_bar_tip.add_child(_bar_tip_text)
	_gold = Control.new()
	_gold.custom_minimum_size = Vector2(150, 76)
	_gold.size = Vector2(150, 76)
	_gold.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gold.position = Vector2(20, -258)
	_gold.mouse_filter = Control.MOUSE_FILTER_PASS
	_gold.mouse_entered.connect(func() -> void: _point = "gold")
	_gold.mouse_exited.connect(func() -> void: _point = "")
	_gold.draw.connect(_draw_gold)
	_root.add_child(_gold)
	# Bottom right: the great seal that sends the army out, the army over it.
	_go = _round(HudParts.RoundButton.new(Icons.BATTLE, "出战！", 50.0, true), Vector2(-172, -184), "")
	_go.pressed.connect(func() -> void: game.act("fight"))
	# By the bar's left end (placed with it, _process): the tech tree, the research points at its shoulder.
	_tech = HudParts.RoundButton.new(Icons.RESEARCH, "科技", 24.0)
	_tech.pressed.connect(func() -> void: open_tech())
	_tech.mouse_entered.connect(func() -> void: _point = "research")
	_tech.mouse_exited.connect(func() -> void: _point = "")
	_root.add_child(_tech)
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

	# A building clicked: how it can be raised (made for each building, _refresh_choice).
	_choice = PanelContainer.new()
	_choice.add_theme_stylebox_override("panel", Style.panel(14.0, true))
	_choice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_choice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice.position = Vector2(-40, -150)
	_choice.visible = false
	_root.add_child(_choice)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	_choice.add_child(_choice_box)

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
	# The bar at the foot of the screen, a little left of the middle, whatever it holds (it grows as blueprints come) --
	# smaller when it would reach the buttons at either side.
	_bar.reset_size()
	var k := minf(1.0, (_root.size.x - 460.0) / maxf(1.0, _bar.size.x))
	_bar.scale = Vector2.ONE * k
	_bar.position = Vector2((_root.size.x - _bar.size.x * k) * 0.5 - 40.0, _root.size.y - _bar.size.y * k - 14.0 + _bar_drop)
	_tech.position = Vector2(_bar.position.x - _tech.size.x - 6.0, _bar.position.y + (_bar.size.y * k - _tech.size.y) * 0.5)
	_tech.modulate.a = _bar.modulate.a
	_place_bar_tip()
	_info.position = Vector2(_root.size.x - 18.0 - _info.size.x, _right.position.y + _right.size.y + 10.0)
	var tip := game.describe() if _bar_hot == "" and not _overlay.visible else ""
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


## The language changed: what was put together in words made again -- the cards, the wonders, the waves -- the rest
## follows by itself (words shown as they are change with the language).
func relanguage() -> void:
	_bar_for = ""
	_choice_for = ""
	for g in _bar_groups:
		var head: Label = _bar_groups[g].col.get_child(0)
		head.text = Lang.t(Content.GROUPS[g] if g != "star" else "明星")
	for l in [_hint, _info_text, _bar_tip_text]:
		(l as Label).autowrap_mode = Style.wrap()
	_waves_for = ""
	refresh()


## The build bar made again when what is on it changes -- the blueprints had, the star on offer: each a round picture,
## in its group (Content.group_of), the star after them; groups with nothing in them hidden.
func _refresh_bar() -> void:
	var home: Home = game.home
	var key := "%s|%s|%s" % [str(home.plans), home.star_offer, Lang.english()]
	if key != _bar_for:
		_bar_for = key
		for g in _bar_groups:
			for c in _bar_groups[g].row.get_children():
				c.queue_free()
		_plans = []
		_star_plan = null
		_bar_hot = ""
		for i in home.plans.size():
			var o := Content.offer({"id": home.plans[i]})
			var b := HudParts.Plan.new()
			b.key = ("b_" + str(o.builds)) if o.type == "build" else ("a_" + str(o.affix))
			b.rarity = int(o.rarity)
			b.glyph = str(o.name).left(1)
			var at := i
			b.pressed.connect(func() -> void: game.hold(at))
			b.mouse_entered.connect(func() -> void: _bar_hot = "p%d" % at)
			b.mouse_exited.connect(func() -> void:
				if _bar_hot == "p%d" % at:
					_bar_hot = "")
			_bar_groups[Content.group_of(home.plans[i])].row.add_child(b)
			_plans.append(b)
		if home.star_offer != "":
			var s: Dictionary = Content.STARS[home.star_offer]
			_star_plan = HudParts.Plan.new()
			_star_plan.key = "s_" + home.star_offer
			_star_plan.rarity = int(s.rarity)
			_star_plan.glyph = Lang.t(s.name).left(1)
			_star_plan.pressed.connect(func() -> void: game.act("star"))
			_star_plan.mouse_entered.connect(func() -> void: _bar_hot = "star")
			_star_plan.mouse_exited.connect(func() -> void:
				if _bar_hot == "star":
					_bar_hot = "")
			_bar_groups.star.row.add_child(_star_plan)
		for g in _bar_groups:
			var n: int = _bar_groups[g].row.get_child_count()
			_bar_groups[g].col.visible = n > 0 and not (g == "star" and home.star_offer == "")
	var planning := game.phase == Game.Phase.PLAN
	for i in _plans.size():
		var b: HudParts.Plan = _plans[i]
		var o := Content.offer({"id": home.plans[i]})
		b.price = home.price_at(o, null)
		b.pop = Content.pop_of(o)
		b.lit = planning and not game.fits_of(i).is_empty()
		b.held = game.held == i
		b.queue_redraw()
	if _star_plan != null:
		_star_plan.price = int(Content.STARS[home.star_offer].price)
		_star_plan.pop = home.star_need(home.star_offer)
		_star_plan.lit = planning and home.can_buy_star()
		_star_plan.queue_redraw()


## The word over the bar on what it points at, placed over it -- or hidden.
func _place_bar_tip() -> void:
	var b: HudParts.Plan = null
	var said := ""
	if _bar.visible and not _overlay.visible:
		if _bar_hot == "star" and _star_plan != null:
			b = _star_plan
			said = _star_tip()
		elif _bar_hot.begins_with("p"):
			var i := int(_bar_hot.substr(1))
			if i < _plans.size():
				b = _plans[i]
				said = _plan_tip(i)
	_bar_tip.visible = b != null and said != ""
	if not _bar_tip.visible:
		return
	if _bar_tip_text.text != said:
		_bar_tip_text.text = said
		_bar_tip.reset_size()
	var at := b.global_position - _root.global_position
	var top := _bar.global_position.y - _root.global_position.y
	_bar_tip.position = Vector2(clampf(at.x + b.size.x * 0.5 - _bar_tip.size.x * 0.5, 12.0, _root.size.x - _bar_tip.size.x - 12.0),
		top - _bar_tip.size.y - 10.0)


## What the blueprint plans[i] is, what it asks, and -- when it cannot be built now -- why.
func _plan_tip(i: int) -> String:
	var home: Home = game.home
	var id: String = home.plans[i]
	var o := Content.offer({"id": id})
	var asks: Array = [Lang.t("%d 金") % home.price_at(o, null)]
	var need := Content.pop_of(o)
	if need > 0:
		asks.append(Lang.t("%d 人口") % need)
	elif need < 0:
		asks.append(Lang.t("人口上限 +%d") % -need)
	var lines: Array = [str(o.name), Content.offer_text(o), Lang.t("、").join(asks)]
	if o.type == "build" and Content.BUILDINGS[o.builds].has("reach"):
		lines.append(Lang.t("管：%s") % Lang.t(Content.REACH[Content.BUILDINGS[o.builds].reach]))
	if game.phase == Game.Phase.PLAN and game.fits_of(i).is_empty():
		if not home.affordable(id):
			lines.append(Lang.t("金币不够（你有 %d）") % home.gold)
		elif home.pop_blocks({"id": id}):
			lines.append(Lang.t("人口不够（现在 %d/%d）") % [home.pop_used(), home.pop_cap()])
		else:
			lines.append(Lang.t("现在没有地方造"))
	return "\n".join(lines)


## What the star on offer is, what it asks, and why it cannot be had now.
func _star_tip() -> String:
	var home: Home = game.home
	var s: Dictionary = Content.STARS[home.star_offer]
	var lines: Array = [Lang.t("%s（%s，%s）") % [Lang.t(s.name), Lang.t(s.kind), Lang.t(Content.DIETS[s.diet])], Lang.t(s.says),
		Lang.t("%d 金、%d 人口") % [int(s.price), home.star_need(home.star_offer)]]
	if game.phase == Game.Phase.PLAN and not home.can_buy_star():
		if home.stars.size() >= Content.PENS:
			lines.append(Lang.t("围栏满了"))
		elif home.gold < int(s.price):
			lines.append(Lang.t("金币不够（你有 %d）") % home.gold)
		else:
			lines.append(Lang.t("人口不够（现在 %d/%d）") % [home.pop_used(), home.pop_cap()])
	return "\n".join(lines)


## The building clicked (game.pending): its name and level, and a button for each way it can be raised, with its
## price -- pointed at, the forecast shows what it would do; the ways it cannot be raised greyed. A plot not open yet
## clicked: a button to open it (_refresh_open).
func _refresh_choice() -> void:
	var home: Home = game.home
	var at: Variant = game.pending.get("at")
	var shut: bool = at != null and home.plot_of.has(at) and not home.is_open(at)
	_choice.visible = game.phase == Game.Phase.PLAN and at != null and (home.buildings.has(at) or shut)
	if not _choice.visible:
		_choice_for = ""
		return
	if shut:
		_refresh_open(home.plot_of[at])
		return
	var b: Dictionary = home.buildings[at]
	var key := "%s|%d|%d|%d|%d" % [str(at), int(b.level), home.gold, home.pop_used(), home.pop_cap()]
	if key == _choice_for:
		return
	_choice_for = key
	for c in _choice_box.get_children():
		c.queue_free()
	var top := int(b.level) >= Content.LEVEL_MAX
	var title := Lang.t("%s，%d 级") % [Lang.t(Content.BUILDINGS[b.kind].name), int(b.level)] if top \
		else Lang.t("%s：%d 级 → %d 级（%d 金）") % [Lang.t(Content.BUILDINGS[b.kind].name), int(b.level), int(b.level) + 1,
			home.raise_price(at)]
	var head := _label(title, 16, Fonts.serif(800), Style.GOLD_BRIGHT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_box.add_child(head)
	if top:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_choice_box.add_child(row)
	var button := _button("变精英" if Content.is_nest(b.kind) else Lang.t("升到 %d 级") % (int(b.level) + 1), Vector2(150, 46), 17)
	button.disabled = not game.raise_fits()
	button.mouse_entered.connect(func() -> void: game.aim("raise"))
	button.mouse_exited.connect(func() -> void:
		if game.aimed == "raise":
			game.aim(""))
	button.pressed.connect(func() -> void: game.act("choose"))
	row.add_child(button)
	if Content.is_nest(b.kind):
		var says := _label(Content.level_text(b.kind, int(b.level) + 1), 14, Fonts.serif(600), Style.PARCHMENT_DIM)
		_choice_box.add_child(says)


## A plot not open yet clicked (game.pending; GAME-DESIGN 33): how big it is, and a button to open it for its price --
## greyed when it is too far from the open ones or there is not the gold for it, and why.
func _refresh_open(id: String) -> void:
	var home: Home = game.home
	var key := "open|%s|%d|%d" % [id, home.gold, home.opened.size()]
	if key == _choice_for:
		return
	_choice_for = key
	for c in _choice_box.get_children():
		c.queue_free()
	var head := _label(Lang.t("没开的地：%d 格") % home.plot_cells(id).size(), 16, Fonts.serif(800), Style.GOLD_BRIGHT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_box.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_child(row)
	var button := _button(Lang.t("开地（%d 金）") % home.open_price(id), Vector2(170, 46), 17)
	button.disabled = not home.can_open(id)
	button.pressed.connect(func() -> void: game.act("open", {"plot": id}))
	row.add_child(button)
	var why := Lang.t("开了就能造。挨着的建筑才互相加成，隔着空地就断了")
	if not home.reachable(id):
		why = Lang.t("离开着的地太远：先开它旁边的地")
	elif home.gold < home.open_price(id):
		why = Lang.t("金币不够（你有 %d）") % home.gold
	var says := _label(why, 14, Fonts.serif(600), Style.PARCHMENT_DIM)
	_choice_box.add_child(says)


## Everyone goes out: the build bar put away.
func stow() -> void:
	_stowed = true
	_bar_hot = ""
	refresh()


func refresh() -> void:
	var run: Run = game.run
	var home: Home = game.home
	var planning := game.phase == Game.Phase.PLAN
	var fighting := game.phase == Game.Phase.FIGHT
	var away := fighting or game.phase == Game.Phase.MOVE     # the army out, or on the way to the next place
	if planning:
		_stowed = false
	var used := home.pop_used()
	var cap := home.pop_cap()
	_refresh_bar()
	_bar.visible = not away and not _stowed and game.phase != Game.Phase.DONE
	_go.disabled = not planning
	_go.visible = not away
	_tech.visible = _bar.visible
	_tech.disabled = not planning
	_tech.count = str(home.genes)
	_tech.queue_redraw()
	_go.queue_redraw()
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
	_refresh_choice()
	_track.part = game.part
	_track.visible = not away and game.phase != Game.Phase.DONE
	_track.queue_redraw()
	_battle.visible = fighting and not game.at_home
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
	_lane_map.put_away()
	for ch in _waves.get_children():
		ch.queue_free()
	_waves.add_child(_wave_card(Lang.t("这一仗"), _big(run, 0), run.wave(), true, run.wave_lanes(), _plan_name(run, 0)))
	if run.round < run.rounds():
		_waves.add_child(_wave_card(Lang.t("下一仗"), _big(run, 1), run.wave(1), false, run.wave_lanes(1), _plan_name(run, 1)))


## The plan a wave comes in, in words (Content.FORMATIONS): a flank with its side.
func _plan_name(run: Run, ahead: int) -> String:
	var r := run.round + ahead
	var plan := Content.formation_of(run.place, run.level, r)
	var said := Lang.t(Content.FORMATIONS[plan].name)
	if plan == "flank":
		said += Lang.t("（从右边来）") if Content.from_right(run.place, run.level, r) else Lang.t("（从左边来）")
	return said


## What a wave is, if more than any other: a boss's, a mini-boss's, a big one ("" none).
func _big(run: Run, ahead: int) -> String:
	if run.round + ahead >= run.rounds():
		return Lang.t("首领")
	if run.round + ahead in Content.MINI_ROUNDS:
		return Lang.t("小首领")
	return Lang.t("大波") if run.big(ahead) else ""


## A wave as a card (HudParts.WaveCard): pointed at, a monster in it is told about, and how they stand in the six
## lanes is shown under the cards (v0.15: the player, 2026-10-23: "保留右上角小图标，hover上去可以显示一个怪物的排列").
func _wave_card(title: String, tag: String, wave: Array, now: bool, lanes: Array, plan: String) -> Control:
	var card := HudParts.WaveCard.new()
	card.setup(title, tag, Content.danger(wave, game.run.power()), now, wave, lanes, plan)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.mapped.connect(func(on: bool) -> void:
		if on:
			_lane_map.show_for(card)
		elif _lane_map.card == card:
			_lane_map.put_away())
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
			return Lang.t("人口 %d / %d\n兵占的位置，用不掉也攒不下。上限：家园自带 %d，培养池、孢子池再加") % [home.pop_used(),
				home.pop_cap(), Content.HOME_POP]
		"research":
			return Lang.t("研究点数 %d\n只用来解锁新图纸。每打一仗 +%d，输赢都有（大波、首领 +%d）；采样站每轮 +%d") % [home.genes, Run.LOOT,
				Run.LOOT * 2, home.income_genes()]
		"gold":
			return Lang.t("金币 %d\n造、升级、贴词条用。每轮开始 +%d；生产时 +%d\n存着有利息：每 %d 金下一轮多 1 金，最多 %d（现在 +%d）") % [
				home.gold, Home.INCOME, home.income_gold(), Content.INTEREST_STEP, home.interest_max(), home.interest()]
		"army":
			var said := Lang.t("这一轮出战 %d 只，占 %d 人口") % [game.ahead().fighters.size(),
				Home.food_of(game.ahead().fighters)]
			var more := game.bonuses()
			return said + ("\n" + more if more != "" else "")
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


## What place `level`'s map is like, in a line (GAME-DESIGN 33).
func _ground_text(level: int) -> String:
	return Lang.t("地块：%s") % Lang.t(Content.LEVELS[level].lay)


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
	view.custom_minimum_size = Vector2(300, 112)
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
	# Its homeland's map (GAME-DESIGN 33): the plots, the one open from the start gold.
	var plan := Control.new()
	plan.custom_minimum_size = Vector2(300, Home.ROWS * 15.0 + 4.0)
	plan.set_meta("place", -1)
	plan.draw.connect(func() -> void:
		var pl := int(plan.get_meta("place"))
		if pl < 0:
			return
		var m := Home.map_of(pl)
		var cell := 15.0
		var o := Vector2((plan.size.x - Home.COLS * cell) * 0.5, 2.0)
		for p in m:
			var r := Rect2(o + Vector2(p) * cell, Vector2(cell, cell)).grow(-1.5)
			for pair in [[Vector2i.RIGHT, SIDE_RIGHT], [Vector2i.LEFT, SIDE_LEFT], [Vector2i.UP, SIDE_TOP], [Vector2i.DOWN, SIDE_BOTTOM]]:
				if m.get(p + (pair[0] as Vector2i), "") == m[p]:
					r = r.grow_side(pair[1], 1.5)
			plan.draw_rect(r, Color(Style.GOLD_BRIGHT, 0.85) if m[p] == Content.START_PLOT else Color(Style.PARCHMENT, 0.4), true))
	dbox.add_child(plan)
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
		plan.set_meta("place", p)
		plan.queue_redraw()
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


## What a place is like, for the map: its homeland's map (GAME-DESIGN 33), who comes there.
func _place_text(p: int) -> String:
	var lv: Dictionary = Content.LEVELS[p]
	var m := Home.map_of(p)
	var plots := {}
	for c in m:
		plots[m[c]] = true
	var ground: Array = [Lang.t("地块：%s（%d 块地，共 %d 格）") % [Lang.t(lv.lay), plots.size(), m.size()]]
	var foes: Array = lv.mix.map(func(m: Array) -> String: return Lang.t(Content.ENEMIES[m[0]].name))
	var minis: Array = lv.minis.map(func(k: String) -> String: return Lang.t(Content.ENEMIES[k].name))
	return Lang.t("%s\n\n会来：%s\n小首领：%s\n首领：%s") % ["\n".join(ground), Lang.t("、").join(foes),
		Lang.t("、").join(minis), Lang.t(Content.ENEMIES[lv.boss].name)]


## The tech tree (科技树, GAME-DESIGN 29), opened while the player builds (the 科技 button by the bar, or T): its three
## parts side by side (Content.TECH_PANELS), each of its lines a tree -- a tech under the one it needs, a line between
## them, bright where the one above is had. A tech had says 已有; one that can be researched is lit, with its price in
## research points (red when there are not enough); one its line has not come to yet is grey. Pointed at, a line under
## the parts says what it is and what it asks; clicked, it is researched if it can be -- as many as there are research
## points for. Closed with the button or Esc.
func open_tech() -> void:
	if game.phase != Game.Phase.PLAN or _overlay.visible:
		return
	var home: Home = game.home
	game._let_go()
	teching = true
	var box := _open(Lang.t("科技"), "")
	var sub: Label = box.get_child(1)
	# Each part laid out first, so that the columns can be as wide as the screen allows them all.
	var layouts: Array = []
	var columns := 0.0
	for panel in Content.TECH_PANELS:
		var slots := {}
		var next := [0.0]
		for root in Content.TECH_PANELS[panel]:
			if home.tech_here(root):
				_tech_layout(root, 0, slots, next)
		layouts.append([panel, slots, next[0]])
		columns += next[0]
	var w := minf(TECH_W, (_root.size.x - 240.0) / maxf(1.0, columns))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var info := _label("", 16, Fonts.serif(600), Style.PARCHMENT)
	info.custom_minimum_size = Vector2(760, 40)
	info.autowrap_mode = Style.wrap()
	var nodes := {}                  # id -> HudParts.TechNode
	var canvases: Array = []
	var show := func() -> void:
		sub.text = Lang.t("你有 %d 研究点数。研究过的，这个地方一直能造") % home.genes
		for id in nodes:
			var n: HudParts.TechNode = nodes[id]
			n.had = id in home.plans
			n.open = home.tech_open(id)
			n.shut = home.tech_shut(id)
			n.enough = home.genes >= Home.tech_cost(id)
			n.queue_redraw()
		for c in canvases:
			(c as Control).queue_redraw()
	for layout in layouts:
		var slots: Dictionary = layout[1]
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", Style.panel(14.0))
		row.add_child(frame)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		frame.add_child(col)
		col.add_child(_label(Lang.t(layout[0]), 17, Fonts.serif(800), Style.GOLD_BRIGHT))
		var depth := 0
		for id in slots:
			depth = maxi(depth, int(slots[id].y))
		var canvas := Control.new()
		canvas.custom_minimum_size = Vector2(float(layout[2]) * w, (depth + 1) * TECH_H)
		col.add_child(canvas)
		canvases.append(canvas)
		for id in slots:
			var o := Content.offer({"id": id})
			var n := HudParts.TechNode.new()
			n.key = ("b_" + str(o.builds)) if o.type == "build" else ("a_" + str(o.affix))
			n.glyph = str(o.name).left(1)
			n.title = str(o.name)
			n.cost = Home.tech_cost(id)
			n.rarity = int(o.rarity)
			n.position = Vector2(float(slots[id].x) * w + (w - n.size.x) * 0.5, float(slots[id].y) * TECH_H)
			canvas.add_child(n)
			nodes[id] = n
			var tech: String = id
			n.mouse_entered.connect(func() -> void: info.text = _tech_tip(tech))
			n.mouse_exited.connect(func() -> void: info.text = "")
			n.pressed.connect(func() -> void:
				if game.act("research", {"id": tech}):
					info.text = _tech_tip(tech)
					show.call())
		# The lines: from each tech down to those that need it, bright where it is had.
		canvas.draw.connect(func() -> void:
			for id in slots:
				var up := Home.tech_needs(id)
				if not slots.has(up):
					continue
				var a: Vector2 = nodes[up].position + Vector2(nodes[up].size.x * 0.5, nodes[up].size.y - 2.0)
				var b: Vector2 = nodes[id].position + Vector2(nodes[id].size.x * 0.5, 4.0)
				var mid := (a.y + b.y) * 0.5
				var col_line := Color(Style.GOLD_BRIGHT, 0.85) if up in home.plans else Color(Style.GOLD_DIM, 0.4)
				canvas.draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b]), col_line, 1.6, true)
			# Where a line forks in two, one of the two only: 或 between them.
			for id in slots:
				var other := Home.tech_other(id)
				if other == "" or not slots.has(other) or other < id:
					continue
				var c: Vector2 = (nodes[id].position + nodes[other].position) * 0.5 + Vector2(nodes[id].size.x * 0.5, 30.0)
				canvas.draw_circle(c, 9.0, Color(0.05, 0.04, 0.03, 0.95), true, -1.0, true)
				canvas.draw_arc(c, 9.0, 0.0, TAU, 24, Color(Style.CORAL, 0.9), 1.0, true)
				HudParts.words(canvas, c, Lang.t("或"), 11, Style.CORAL, Fonts.serif(800), 0, 2))
	box.add_child(info)
	var done := _button("好了", Vector2(180, 48), 19, true)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func() -> void: chosen.emit("close"))
	box.add_child(done)
	show.call()
	while await chosen != "close":
		pass
	teching = false
	_close()
	game.refresh()


## Lays out tech `id` and those that come of it: the leaves left to right (next[0] the next free column), a tech over the
## middle of those under it. slots: id -> Vector2(column, depth). Its column.
func _tech_layout(id: String, depth: int, slots: Dictionary, next: Array) -> float:
	var under: Array = Content.OFFERS.keys().filter(func(k: String) -> bool:
		return Home.tech_needs(k) == id and game.home.tech_here(k))
	var col := 0.0
	if under.is_empty():
		col = next[0]
		next[0] += 1.0
	else:
		for k in under:
			col += _tech_layout(k, depth + 1, slots, next)
		col /= under.size()
	slots[id] = Vector2(col, depth)
	return col


## What tech `id` is and what it asks, for the line under the tree.
func _tech_tip(id: String) -> String:
	var home: Home = game.home
	var o := Content.offer({"id": id})
	var build := (Lang.t("造一座 %d 金") if o.type == "build" else Lang.t("贴一个 %d 金")) % int(o.price)
	var state := ""
	var other := Home.tech_other(id)
	if id in home.plans:
		state = Lang.t("已经有了。%s") % build
	elif home.tech_shut(id):
		state = Lang.t("和%s二选一，这个地方已经选了%s") % [Content.offer({"id": other}).name, Content.offer({"id": other}).name]
	elif not home.tech_open(id):
		state = Lang.t("要先研究%s") % Content.offer({"id": Home.tech_needs(id)}).name
	else:
		state = Lang.t("研究要 %d 研究点数（你有 %d）。研究以后，%s") % [Home.tech_cost(id), home.genes, build]
	if other != "" and not id in home.plans and not home.tech_shut(id):
		state += Lang.t("。和%s二选一：选了一个，另一个这个地方就不能研究了") % Content.offer({"id": other}).name
	return Lang.t("%s：%s\n%s") % [o.name, Content.offer_text(o), state]


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
		[_army, Vector2(320, 0), 0.2], [_go, Vector2(340, 0), 0.32], [_menu, Vector2(0, 160), 0.22]]
	# The bar comes up from below to wherever it sits then (_process places it: it grows as blueprints come).
	_bar_drop = 220.0
	_bar.modulate.a = 0.0
	var bar_in := _bar.create_tween().set_parallel()
	bar_in.tween_property(self, "_bar_drop", 0.0, 0.6).set_delay(0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar_in.tween_property(_bar, "modulate:a", 1.0, 0.3).set_delay(0.26)
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
	_bar.visible = false
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
	refresh()


# -- Pieces -----------------------------------------------------------------------------------------------------

## The gold: a big coin, the gold by it; under it, always, the interest it would bring at the next round's start kept
## as it is (the player, 2026-10-22: "攒钱还是应该有利息……最多 +5，金币旁一直显示").
func _draw_gold() -> void:
	var home: Home = game.home
	HudParts.veil(_gold, Rect2(-8, 0, 160, 76), 0.5, 18.0)
	Icons.draw(_gold, Icons.GOLD, Vector2(26, 28), 40.0)
	HudParts.words(_gold, Vector2(52, 28), str(home.gold), 30, Style.GOLD_BRIGHT, Fonts.numbers(), -1, 5)
	HudParts.words(_gold, Vector2(8, 62), Lang.t("下轮利息 +%d") % home.interest(), 15, Style.AMBER, Fonts.serif(700), -1, 3)


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



