class_name Game
extends Node3D
## The game (GAME-DESIGN 17-28): the homeland built from blueprints, and the battles its army fights by itself, on one
## screen. It opens on the title (Menu) over a homeland at dusk; Esc pauses. A run lands in the rainforest; each place
## is begun with nothing built, a nest picked from three. A round goes in parts (GAME-DESIGN 26, Content.phases), each
## said as it comes. The start: the round's pay and the interest on the gold kept come in. The player's: the player
## researches techs for research points (the tech tree, GAME-DESIGN 29), builds from the blueprints had (the build bar;
## GAME-DESIGN 27), raises buildings (clicked: a nest raised elite), sticks gene affixes on nests
## -- where a building works lit blue as it is placed (GAME-DESIGN 28) -- then is done. The making, by itself: the
## buildings bring in research points and gold, and the nests hatch this round's young -- each out of its nest to stand
## in the yard as it will stand in battle. The battle, by itself: the young go out and fight, and are gone with it;
## research points, won or lost; won, gold; lost, the homeland is hurt. Twelve rounds hold a place, the last against its
## boss; then the run goes on to the next place picked on the map, where the homeland is made afresh, carrying nothing.
## How the battle will end is worked out (for the tools and F3) before it is fought, and again with the good or the
## choice pointed at.
##
## Every player action goes through act(what, data). Coloured blocks stand in for what will be.

signal departed
signal player_done                # the player's part of the round over ("fight")
signal fight_over                 # the battle fought to its end

enum Phase { BUSY, PLAN, FIGHT, MOVE, DONE, TITLE }

const HOME_AT := Vector3(0, 0, 4.0)
const HOME_DIST := 44.0
const FIGHT_AT := Vector3(0, 0, -79.0)
const FIGHT_DIST := 18.0
const PITCH := 54.0
const OK_TINT := Color(0.42, 0.86, 0.4)
const SWAP_TINT := Color(0.95, 0.65, 0.3)
const HOT_TINT := Color(0.8, 1.0, 0.55)
const BAD_TINT := Color(0.95, 0.42, 0.34)
const LOOK_TINT := Color(0.86, 0.79, 0.64)

var run: Run
var home: Home
var world: World
var camera: Camera3D
var home_view: HomeView
var fight_view: FightView
var tags: Tags
var hud: Hud
var phase := Phase.BUSY
var held := -1                    # the shelf place taken up, or -1
var hover := {"plot": HomeView.NOWHERE, "unit": "", "pen": -1}     # pen: a star dinosaur's pen (HomeView)
var fight: Fight                  # the battle being fought, or null
var speed := 1.0
var at_home := true               # the camera is over the homeland (not the battle field)
var forecast := {}                # this round's battle as things stand: {result, left, total, harm, loot}
var preview := {}                 # the same with what is taken up used; {} when none
var effects := {}                 # plot -> [short lines]: what that would change there (for Tags)
var pending := {}                 # a building clicked, to be raised: {at}; {} if none

var aimed := ""                   # pointed at on the HUD, to show what it would do: "raise", the raise waiting

var menu: Menu
var going := -1                   # the place picked on the map to move on to

## How the battle will end, shown (the forecast) -- for finding what breaks, not for playing: F3.
static var debug := false

## Whether the scene opens on the title (the game starting, or "回主菜单") or straight into a new run ("重新开始").
static var show_title := true

var _tags_layer: CanvasLayer
var _showcase: HomeView           # the homeland to look at under the title
var _orbit := 0.6                 # the title's camera, going slowly round
var _cam_at := HOME_AT
var _cam_dist := HOME_DIST
var _drag := false
var _acc := 0.0
var _fighting := false
var _shake := 0.0
var _version := 0                 # goes up whenever the homeland changes
var part := ""                    # the part of the round it is in (Content.PHASES); "" between rounds
var _ahead: Home                  # the homeland as this round's making and eating will leave it (ahead), as of _ahead_at
var _ahead_at := -1
var _fits := {}                   # where each good can go (fits_of), as of _fits_at
var _fits_at := -1
var _forecast_at := -1
var _preview_key := ""
var _preview := {}
var _effects := {}


func _ready() -> void:
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			Style.juice(n))
	Settings.load_all()
	speed = 3.0 if Settings.fast else 1.0
	add_child(Sound.new())
	add_child(Portraits.new())
	if Run.current == null:
		Run.current = Run.new()
	run = Run.current
	home = run.home
	world = World.new()
	add_child(world)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.5
	camera.far = 700.0
	add_child(camera)
	_place_camera()
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_tags_layer = layer
	tags = Tags.new()
	tags.game = self
	layer.add_child(tags)
	home_view = HomeView.new()
	home_view.tags = tags
	add_child(home_view)
	home_view.setup(home)
	fight_view = FightView.new()
	fight_view.tags = tags
	add_child(fight_view)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	menu = Menu.new()
	add_child(menu)
	menu.setup(self)
	Portraits.warm()
	Art.warm()
	if show_title:
		_title()
	else:
		Sound.air(true)
		_begin()


func _process(delta: float) -> void:
	if phase == Phase.TITLE:
		_orbit += delta * 0.035
		var target := Vector3(0, 1.0, 6.0)
		camera.position = target + Vector3(sin(_orbit) * 46.0, 18.0 + sin(_orbit * 2.0) * 1.2, cos(_orbit) * 46.0)
		camera.look_at(target + Vector3(0, 2.5, 0), Vector3.UP)
		return
	if _fighting:
		fight_view.pace = speed
		_acc += delta * speed
		while _acc >= Fight.STEP and not fight.over:
			_acc -= Fight.STEP
			fight_view.show_events(fight.step())
		if fight.over:
			_fighting = false
			fight_over.emit()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
	_place_camera()


# -- What the player does --------------------------------------------------------------------------------------

## The one door for a player's action: "research" {id} (a tech of the tree), "build" {plan, at} (the blueprint
## plans[plan] built on `at`), "raise" {at} (the building at `at` a level up -- a nest elite), "choose" (the building
## clicked raised), "star" (the star on offer bought), "sell" {pen}, "fight". Whether it happened.
func act(what: String, data := {}) -> bool:
	if phase != Phase.PLAN:
		return false
	match what:
		"research":
			if not home.research(str(data.get("id", ""))):
				return false
			_changed([{"t": "researched", "id": data.id}])
			return true
		"build":
			var i := int(data.get("plan", -1))
			if i < 0 or i >= home.plans.size():
				return false
			var ev := home.build_plan(home.plans[i], data.get("at", HomeView.NOWHERE))
			if ev.is_empty():
				return false
			_changed(ev)
			# Still taken up while there is somewhere more for it.
			if fits_of(i).is_empty():
				held = -1
				refresh()
			return true
		"raise":
			var ev := home.raise(data.get("at", HomeView.NOWHERE))
			if ev.is_empty():
				return false
			pending = {}
			aimed = ""
			_changed(ev)
			return true
		"choose":
			if pending.is_empty():
				return false
			return act("raise", {"at": pending.at})
		"star":
			var ev := home.buy_star()
			if ev.is_empty():
				return false
			_changed(ev)
			return true
		"sell":
			var ev := home.sell_star(int(data.get("pen", -1)))
			if ev.is_empty():
				return false
			_changed(ev)
			return true
		"fight":
			player_done.emit()
			return true
	return false


## The blueprint plans[i] taken up from the build bar (again: put down).
func hold(i: int) -> void:
	if phase != Phase.PLAN or i < 0 or i >= home.plans.size():
		return
	held = -1 if held == i else i
	pending = {}
	refresh()


## What the HUD points at, to show what it would do: "raise" (the raise waiting), or "".
func aim(what: String) -> void:
	aimed = what
	refresh()


## Lets go of whatever is taken up, waiting or pointed at.
func _let_go() -> void:
	held = -1
	pending = {}
	aimed = ""
	refresh()



func _changed(ev: Array) -> void:
	_version += 1
	for e in ev:
		match e.t:
			"built", "replaced", "raised", "affixed":
				home_view.refresh_buildings()
				if e.t == "replaced":
					tags.float_text(HomeView.plot_pos(e.at) + Vector3.UP * 3.0, Lang.t("退 %d 金") % e.back, Color(1.0, 0.8, 0.4))
				if e.t == "raised" and e.get("elite", false):
					tags.float_text(home_view.top(e.at) + Vector3.UP * 1.5, Lang.t("精英！"), HomeView.ELITE_GOLD, 28)
				if e.t == "affixed":
					var b: Dictionary = home.buildings[e.at]
					var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
					if e.affix in sp.used:
						tags.float_text(home_view.top(e.at) + Vector3.UP * 1.5, Lang.t("进化！%s") % Lang.t(Content.UNITS[sp.kind].name),
							(Content.UNITS[sp.kind].color as Color).lightened(0.3), 28)
			"stored":
				tags.float_text(_pen_of("keep") + Vector3(0, 3.0, 0), Lang.t("囤囤收好了"), Color(0.6, 1.0, 0.55), 22)
			"star":
				home_view.refresh_pens()
				tags.float_text(HomeView.PEN_AT[home.stars.size() - 1] + Vector3(0, 3.2, 0),
					Lang.t("%s来了！") % Lang.t(Content.STARS[e.id].name), (Content.STARS[e.id].back as Color).lightened(0.4), 26)
			"sold":
				home_view.refresh_pens()
				tags.float_text(HomeView.PEN_AT[0] + Vector3(0, 3.2, 4.0), Lang.t("%s走了，+%d 金") % [Lang.t(Content.STARS[e.id].name),
					e.gold], Color(1.0, 0.8, 0.4), 24)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.TITLE:
		return
	if event is InputEventMouseMotion:
		if _drag:
			_cam_at += Vector3(-event.relative.x, 0, -event.relative.y) * _cam_dist * 0.0016
		_hover_at(event.position)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_click()
			MOUSE_BUTTON_RIGHT:
				_let_go()
			MOUSE_BUTTON_WHEEL_UP:
				_cam_dist = maxf(18.0, _cam_dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cam_dist = minf(80.0, _cam_dist * 1.1)
			MOUSE_BUTTON_MIDDLE:
				_drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_drag = false
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if hud.screen != "":
			# A screen up (the tech tree): only Esc, to close it.
			if k == KEY_ESCAPE and hud.teching:
				hud.chosen.emit("close")
			return
		if k >= KEY_1 and k < KEY_1 + mini(home.plans.size(), 9):
			hold(k - KEY_1)
		elif k == KEY_ESCAPE:
			if held >= 0 or not pending.is_empty():
				_let_go()
			else:
				pause()
		elif k == KEY_F3:
			debug = not debug
			refresh()
		elif k == KEY_T:
			hud.open_tech()
		elif k == KEY_SPACE or (k == KEY_ENTER and not event.alt_pressed):
			act("fight")


func _click() -> void:
	var pen := int(hover.get("pen", -1))
	if pen >= 0:
		# A star's pen: its own screen (to sell it).
		if phase == Phase.PLAN and pen < home.stars.size():
			_pen_screen(pen)
		return
	if phase != Phase.PLAN:
		return
	var at: Variant = _aim()
	if held >= 0:
		if at != null:
			act("build", {"plan": held, "at": at})
		return
	# Nothing taken up: a building clicked is to be raised -- the HUD asks how, a nest's either way (GAME-DESIGN 27).
	pending = {"at": at} if at != null and home.buildings.has(at) and pending.get("at") != at else {}
	aimed = ""
	refresh()


## The blueprint taken up, as a card ({id}), or {} when none is.
func _taken() -> Dictionary:
	return {"id": home.plans[held]} if held >= 0 and held < home.plans.size() else {}


func _hover_at(pos: Vector2) -> void:
	var h := {"plot": HomeView.NOWHERE, "unit": "", "pen": -1}
	if at_home:
		var pen := home_view.pen_at(camera, pos) if phase == Phase.PLAN else -1
		if pen >= 0:
			h.pen = pen
		else:
			h = home_view.pick(camera, pos, _want())
			h.pen = -1
	if h.plot != hover.plot or h.unit != hover.unit or h.pen != int(hover.get("pen", -1)):
		hover = h
		refresh()


## A star dinosaur's own screen (its pen clicked): sold, or kept.
func _pen_screen(pen: int) -> void:
	_let_go()
	if await hud.pen_menu(pen) == "sell":
		act("sell", {"pen": pen})
	refresh()


## Where the pen of the star that does `key` (Content.STARS) stands; the first pen's place if there is none.
func _pen_of(key: String) -> Vector3:
	for k in home.stars.size():
		if Content.STARS[home.stars[k].id].has(key):
			return HomeView.PEN_AT[k]
	return HomeView.PEN_AT[0]


## What the cursor should find, for the good taken up.
func _want() -> String:
	var good := _taken()
	if phase != Phase.PLAN or good.is_empty():
		return "any"
	return "tile" if Content.offer(good).target == "tile" else "building"


## What the blueprint taken up would go on (or the building clicked to raise), under the cursor: a plot, or null.
func _aim() -> Variant:
	return hover.plot if hover.plot != HomeView.NOWHERE else null


# -- Moving on --------------------------------------------------------------------------------------------------

## On to the place picked on the map: the screen goes dark, the homeland is made afresh there, the screen comes up on
## it.
func _move() -> void:
	phase = Phase.MOVE
	held = -1
	refresh()
	await hud.fade(true)
	run.move_on(going)
	world.dress(run.place)
	home_view.lay_ground()
	home_view.rebuild()
	home_view.refresh_pens()
	_version += 1
	refresh()
	await hud.fade(false)


# -- What is shown --------------------------------------------------------------------------------------------

## The forecast worked out again where the homeland changed; the plots the good taken up can go on lit (orange where
## it would pull a building down), the one it points at brighter, and the forecast and what changes with it there; the
## plots where a building works (Home.reach) blue -- the one being placed, or the one clicked or pointed at; the HUD
## brought up to date.
## The language changed (Settings): the screen's words made again.
func relanguage() -> void:
	hud.relanguage()
	refresh()


func refresh() -> void:
	var tints := {}
	var reach: Array = []
	preview = {}
	effects = {}
	if phase == Phase.PLAN:
		if _forecast_at != _version:
			forecast = _work_out(home)
			_forecast_at = _version
		var good := _taken()
		if not pending.is_empty():
			tints[pending.at] = HOT_TINT
			reach = Home.reach(home.buildings[pending.at].kind, pending.at)
			if aimed == "raise":
				var at: Vector2i = pending.at
				_try("raise|%s" % str(at), func(h: Home) -> void: h.raise(at))
		elif not good.is_empty():
			var c := Content.offer(good)
			var fits := fits_of(held)
			for t in fits:
				tints[t] = SWAP_TINT if c.type == "build" and home.buildings.has(t) else OK_TINT
			var at: Variant = _aim()
			if at != null and at in fits:
				tints[at] = HOT_TINT
				if c.type == "build":
					reach = Home.reach(c.builds, at)
				var id: String = good.id
				_try("build%s|%s" % [id, str(at)], func(h: Home) -> void: h.build_plan(id, at))
			elif at is Vector2i and home.is_open(at):
				tints[at] = BAD_TINT
		elif hover.plot != HomeView.NOWHERE and home.is_open(hover.plot):
			tints[hover.plot] = LOOK_TINT
			if home.buildings.has(hover.plot):
				reach = Home.reach(home.buildings[hover.plot].kind, hover.plot)
	home_view.tints = tints
	home_view.reach = reach
	home_view.paint()
	home_view.refresh_pens()
	hud.refresh()


## The forecast and the changes with `what` done to a copy of the homeland (worked out once for each thing tried).
func _try(key: String, what: Callable) -> void:
	key += "|%d" % _version
	if key != _preview_key:
		var h := home.clone()
		what.call(h)
		_preview = _work_out(h)
		_effects = _changes(home, h)
		_preview_key = key
	preview = _preview
	effects = _effects


## How this round's battle ends if fought by `h` once its round is made and eaten -- the same rules, so the same end.
func _work_out(h: Home) -> Dictionary:
	var f := Fight.make(h.settled().fighters, run.wave(), run.power())
	var total := f.alive("ours").size()
	f.run()
	return {"result": f.result, "left": f.alive("ours").size(), "total": total,
		"harm": 0 if f.result == "won" else maxi(0, f.harm()), "loot": f.scavenged()}


## What differs between two homelands, building by building, as short lines: more or fewer hatched, a new species,
## elite, hardier, harder hitting, faster, an affix, more affix places; and at the plot of a building that brings
## something in, what it brings.
func _changes(a: Home, b: Home) -> Dictionary:
	var out := {}
	var made_a := _made(a)
	var made_b := _made(b)
	for p in b.buildings:
		var lines: Array = []
		var kind: String = b.buildings[p].kind
		if Content.is_nest(kind):
			var d := int(made_b.get(p, 0)) - int(made_a.get(p, 0))
			if d != 0:
				lines.append(Lang.t("%+d 只") % d)
			var gift := b.trait_of(p)
			if gift in ["swarm", "guard", "cover", "alone"]:
				var was: bool = a.buildings.has(p) and a.buildings[p].kind == kind and a.trait_on(p)
				if b.trait_on(p) != was:
					lines.append(Lang.t("%s本事「%s」") % ["+" if b.trait_on(p) else "−", Lang.t(Content.TRAITS[gift].name)])
			if a.buildings.has(p) and a.buildings[p].kind == kind:
				var sa := a.spec_of(p)
				var sb := b.spec_of(p)
				if sb.kind != sa.kind:
					lines.append(Lang.t("进化：") + Lang.t(Content.UNITS[sb.kind].name))
				if int(sb.elite) > int(sa.elite):
					lines.append(Lang.t("精英"))
				var hp := roundi((float(sb.hp_mult) / float(sa.hp_mult) - 1.0) * 100.0)
				if hp != 0:
					lines.append(Lang.t("血 %+d%%") % hp)
				var atk := roundi((float(sb.atk_mult) / float(sa.atk_mult) - 1.0) * 100.0)
				if atk != 0:
					lines.append(Lang.t("攻击 %+d%%") % atk)
				if int(sb.atk_bonus) != int(sa.atk_bonus):
					lines.append(Lang.t("攻击 %+d") % (int(sb.atk_bonus) - int(sa.atk_bonus)))
				if int(sb.pierce) != int(sa.pierce):
					lines.append(Lang.t("每下 %+d，不管护甲") % (int(sb.pierce) - int(sa.pierce)))
				if int(sb.haste) != int(sa.haste):
					lines.append(Lang.t("快 %+d%%") % (int(sb.haste) - int(sa.haste)))
				for af in sb.affixes:
					if not af in sa.affixes:
						lines.append("+" + Lang.t(Content.AFFIXES[af].name))
				if b.slots(p) != a.slots(p):
					lines.append(Lang.t("词条位 %+d") % (b.slots(p) - a.slots(p)))
		if not lines.is_empty():
			out[p] = lines
	for p in b.buildings:
		if a.buildings.has(p) and a.buildings[p].kind == b.buildings[p].kind and a.buildings[p].level == b.buildings[p].level:
			continue
		var lines: Array = out.get(p, [])
		for pair in [[Lang.t("金币"), b.income_gold() - a.income_gold(), Lang.t("/轮")], [Lang.t("人口上限"), b.income_biomass() - a.income_biomass(), ""],
				[Lang.t("研究点数"), b.income_genes() - a.income_genes(), Lang.t("/轮")], [Lang.t("利息上限"), b.interest_max() - a.interest_max(), ""],
				[Lang.t("家园血"), b.hp_max() - a.hp_max(), ""]]:
			if int(pair[1]) != 0:
				lines.append("%s %+d%s" % [pair[0], pair[1], pair[2]])
		if not lines.is_empty():
			out[p] = lines
	return out


## How many each nest of `h` will send to fight this round.
func _made(h: Home) -> Dictionary:
	var out := {}
	for u in h.settled().fighters:
		out[u.nest] = int(out.get(u.nest, 0)) + 1
	return out


## What to do with the good taken up, said over the shelf: "" when none is.
## A word at the screen's foot while a blueprint is taken up or a building is to be raised -- only what the lit plots
## do not show already (the player, 2026-10-20: "数字，文字都尽量去除"): why it cannot go anywhere, what a swap would
## knock down; how a building clicked can be raised.
func hint() -> String:
	if phase != Phase.PLAN:
		return ""
	if not pending.is_empty():
		var at: Vector2i = pending.at
		var b: Dictionary = home.buildings[at]
		if int(b.level) >= Content.LEVEL_MAX:
			return Lang.t("已经是最高级")
		if home.gold < home.raise_price(at):
			return Lang.t("金币不够")
		return ""
	var good := _taken()
	if good.is_empty():
		return ""
	var c := Content.offer(good)
	var p: Vector2i = hover.plot
	var swap: bool = c.target == "tile" and p != HomeView.NOWHERE and home.buildings.has(p) and home.buildings[p].kind != c.builds
	if fits_of(held).is_empty():
		if not home.affordable(good.id):
			return Lang.t("金币不够")
		return Lang.t("人口不够") if home.pop_blocks(good) else Lang.t("现在没有地方用得上")
	if swap:
		return Lang.t("换掉%s（退 %d 金）") % [Lang.t(Content.BUILDINGS[home.buildings[p].kind].name),
			int(Content.BUILDINGS[home.buildings[p].kind].cost) / 2]
	return ""


## What the cursor points at, for the panel: "" for nothing.
func describe() -> String:
	if not at_home or phase == Phase.DONE or phase == Phase.MOVE:
		return ""
	var pen := int(hover.get("pen", -1))
	if pen >= 0:
		return _pen_text(pen)
	if hover.unit != "":
		for u in home.brood:
			if u.id == hover.unit:
				return _unit_text(u)
		return ""
	var p: Vector2i = hover.plot
	if p == HomeView.NOWHERE:
		return ""
	var ground: String = home.terrain.get(p, "")
	if not home.buildings.has(p):
		if ground != "":
			return "%s\n%s" % [Lang.t(Content.TERRAIN[ground].name), Lang.t(Content.TERRAIN[ground].says)]
		if Home.front(p):
			return Lang.t("阵地（%s）：只能造巢。巢造在这里，它孵的兵打仗时就站在这里") % (Lang.t("前排") if p.y == 0 else Lang.t("后排"))
		return Lang.t("后方：巢以外的建筑造在这里")
	var text := _building_text(p)
	if ground != "":
		text += Lang.t("\n建在%s上：%s") % [Lang.t(Content.TERRAIN[ground].name), Lang.t(Content.TERRAIN[ground].says)]
	return text


## A pen pointed at: its star -- what it is, what it does, what it eats and whether it went without -- or that it is
## empty.
func _pen_text(pen: int) -> String:
	if pen >= home.stars.size():
		return Lang.t("空围栏：能养一只明星恐龙（每轮来一只，在建造栏最右边）")
	var s: Dictionary = Content.STARS[home.stars[pen].id]
	var lines: Array = [Lang.t("%s（%s，%s）") % [Lang.t(s.name), Lang.t(s.kind), Lang.t(Content.DIETS[s.diet])], Lang.t(s.says)]
	if s.has("grow_boss") or s.has("grow_round"):
		lines.append(Lang.t("现在长到 +%d") % int(home.stars[pen].grow))
	if pen in home.hungry:
		lines.append(Lang.t("这一轮没吃饱，本事没起作用"))
	elif int(s.eat) > 0:
		lines.append(Lang.t("每轮吃 %d 生物质") % int(s.eat))
	lines.append(Lang.t("点一下：看看，或者卖掉"))
	return "\n".join(lines)


func _unit_text(u: Dictionary) -> String:
	var s := Content.unit_stats(u)
	var nest: Dictionary = home.buildings.get(u.nest, {})
	var from := Lang.t("泰坦带来的") if nest.is_empty() else Lang.t("%s %d 级孵的") % [Lang.t(Content.BUILDINGS[nest.kind].name), int(nest.level)]
	var lines: Array = [Lang.t("%s%s（%s，站%s）") % [Lang.t("精英") if int(u.get("elite", 0)) > 0 else "", Lang.t(s.name), from,
		Lang.t("前排") if int(u.get("row", 0)) == 0 else Lang.t("后排")],
		Lang.t("血 %d · 攻击 %d · %s 秒打一下 · 够得着 %s 米") % [s.hp, s.atk, _num(s.every), _num(s.range)]]
	var more: Array = []
	if int(s.armor) > 0:
		more.append(Lang.t("护甲 %d（每挨一下少掉 %d）") % [s.armor, s.armor])
	if int(s.pierce) > 0:
		more.append(Lang.t("每下多 %d，不管护甲") % s.pierce)
	if float(s.splash) > 0.0:
		more.append(Lang.t("一打一片（旁边 %s 米挨一半）") % _num(s.splash))
	if int(s.heal) > 0:
		more.append(Lang.t("每下回血 %d") % s.heal)
	if int(s.burst) > 0:
		more.append(Lang.t("倒下时炸一圈（%d）") % s.burst)
	if s.dive:
		more.append(Lang.t("会飞，打后排"))
	if s.charge:
		more.append(Lang.t("开战第一下双倍"))
	if u.get("guard", false):
		more.append(Lang.t("护住身后同一列"))
	var ahead := Vector2i(int(u.lane), 0)
	if int(u.get("row", 0)) == 1 and home.trait_of(ahead) == "guard" and home.trait_on(ahead):
		more.append(Lang.t("身前有绿兵护着"))
	if u.get("care", false):
		more.append(Lang.t("只给同一列回血"))
	if u.get("scavenge", false):
		more.append(Lang.t("打完还站着，带回 %d 金") % Content.SCAVENGE)
	if not more.is_empty():
		lines.append(" · ".join(more))
	lines.append(Lang.t(Content.UNITS[u.kind].role))
	lines.append(Lang.t("占 %d 人口，只活这一仗") % int(Content.UNITS[u.kind].food) if not u.free else Lang.t("只活这一仗（慈母多孵的，不吃生物质）"))
	return "\n".join(lines)


func _building_text(p: Vector2i) -> String:
	var b: Dictionary = home.buildings[p]
	var info: Dictionary = Content.BUILDINGS[b.kind]
	var lines: Array = [Lang.t("%s · %d 级") % [Lang.t(info.name), b.level]]
	if not Content.is_nest(b.kind):
		lines.append(Content.building_text(b.kind, int(b.level)))
	else:
		var s := home.spec_of(p)
		if s.evolved:
			var sp := Content.species(info.nest, b.affixes)
			lines.append(Lang.t("进化了：孵的是%s（%s）") % [Lang.t(Content.UNITS[s.kind].name), "+".join(sp.used.map(func(a: String) -> String:
				return Lang.t(Content.AFFIXES[a].name)))])
		else:
			var unit: Dictionary = Content.UNITS[info.nest]
			lines.append(Lang.t("孵%s：%s（每只占 %d 人口）") % [Lang.t(unit.name), Lang.t(unit.role), unit.food])
		var t: Dictionary = Content.TRAITS[info.trait]
		var need := home.trait_need(p)
		var state := "" if t.when == "" else (Lang.t("生效") if need == "" else Lang.t("没生效（%s）") % need)
		lines.append(Lang.t("本事「%s」%s：%s") % [Lang.t(t.name), state, Lang.t(t.does)])
		var made := int(_made(home).get(p, 0))
		var want := home.count(p)
		lines.append(Lang.t("这一轮孵 %d 只%s，打仗时站%s") % [made, (Lang.t("（人口不够，少 %d）") % (want - made)) if made < want else "",
			Lang.t("前排") if p.y == 0 else Lang.t("后排")])
		var e := int(s.elite)
		if e > 0:
			lines.append(Lang.t("精英%s：血 ×%s、攻击 ×%s、大一号") % ["×%d" % e if e > 1 else "", Content._num(pow(Content.ELITE_HP, e)),
				Content._num(pow(Content.ELITE_ATK, e))])
		var given: Array = []
		if e > 0 and home._given("elite", p) > 0:
			given.append(Lang.t("冠军殿：精英再 +%d%%") % home._given("elite", p))
		if p.y == 0 and home._given("front", p) > 0:
			given.append(Lang.t("前锋营：前排血 +%d%%") % home._given("front", p))
		if maxf(float(Content.UNITS[s.kind].range), float(s.range)) >= 3.0 and home._given("ranged", p) > 0:
			given.append(Lang.t("瞭望塔：每下多 %d，不管护甲") % home._given("ranged", p))
		var horde := home.horde_bonus(army_now().size(), p)
		if horde > 0:
			given.append(Lang.t("兽群图腾：攻击 +%d") % horde)
		if not given.is_empty():
			lines.append(Lang.t("，").join(given))
		var names: Array = b.affixes.map(func(a: String) -> String: return Lang.t(Content.AFFIXES[a].name))
		lines.append(Lang.t("词条：%s（还能贴 %d 个）") % [Lang.t("、").join(names) if not names.is_empty() else Lang.t("没有"), home.slots(p) - b.affixes.size()])
		if not s.evolved:
			for pair in Content.could_become(b.affixes):
				lines.append(Lang.t("再贴上%s，会进化成%s") % [Lang.t(Content.AFFIXES[pair[0]].name), Lang.t(Content.UNITS[pair[1]].name)])
	if int(b.level) < Content.LEVEL_MAX:
		lines.append(Lang.t("升到 %d 级：%s") % [int(b.level) + 1, Content.level_text(b.kind, int(b.level) + 1)])
		lines.append(Lang.t("点一下升级（%d 金）") % home.raise_price(p))
	return "\n".join(lines)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


## What the army's size does for it, said plainly (for the HUD): what each horde totem gives the nests in front of
## it; "" when nothing. (What the other buildings give, a nest says itself.)
func bonuses() -> String:
	var parts: Array = []
	var n := ahead().fighters.size()
	for p in home.buildings:
		if home.buildings[p].kind == "horde_totem":
			var each := int(home.level_of(p).per)
			parts.append(Lang.t("兽群图腾：出战 %d 只，它前面三列的兵攻击 +%d；再多 %d 只 +1") % [n, n / each, each - n % each])
	# What the fed stars do for the army.
	for k in home.stars.size():
		if k in home.hungry:
			continue
		var s: Dictionary = Content.STARS[home.stars[k].id]
		if s.has("grow_boss"):
			if int(home.stars[k].grow) > 0:
				parts.append(Lang.t("%s：全体攻击 +%d") % [Lang.t(s.name), int(home.stars[k].grow)])
		elif s.has("front_armor") or s.has("red_atk") or s.has("haste") or s.has("reach") or s.has("atk") or s.has("weak") \
				or s.has("count") or s.has("titan"):
			parts.append(Lang.t("%s：%s") % [Lang.t(s.name), Lang.t(s.says)])
	return "\n".join(parts)


# -- The run ----------------------------------------------------------------------------------------------------

## The run's start: the place it lands in, its first nest, then its rounds.
func _begin() -> void:
	refresh()
	await hud.arrive(run.place)
	await _first_nest()
	_play()


## A place begun (GAME-DESIGN 28): nothing built there yet, its first nest picked from three, had for nothing.
func _first_nest() -> void:
	var cards := run.nest_offer()
	if cards.is_empty():
		return
	var v: Variant = await hud.choose("选第一个巢", "这里什么都还没有，家园从这个巢开始建", cards, [])
	run.take_first(v.id)
	_version += 1
	refresh()


## The run's rounds, one after another, each its parts in turn (Content.phases; more parts can come between them);
## after the battle, what it brings -- the next place after a boss -- till the run is over.
func _play() -> void:
	while true:
		for part in Content.phases():
			match part:
				"start":
					await _start_round()
				"play":
					await _player_part()
				"make":
					await _make()
				"eat":
					await _eat()
				"fight":
					await _fight()
		if not await _after_fight():
			return


## The start of a round (GAME-DESIGN 26): its number said, the round's pay and the interest on the gold kept said over
## the homeland, the shelf stocked.
func _start_round() -> void:
	phase = Phase.BUSY
	part = "start"
	held = -1
	pending = {}
	aimed = ""
	refresh()
	var sub := ""
	if run.round == 1 and run.level > 0:
		sub = Lang.t("新地方，家园从头建")
	elif run.round >= run.rounds():
		sub = Lang.t("首领来了")
	elif run.round in Content.MINI_ROUNDS:
		sub = Lang.t("小首领来了")
	elif run.big():
		sub = Lang.t("大波要来了")
	hud.banner(Lang.t("第 %d 轮") % run.round, sub)
	await get_tree().create_timer(0.6).timeout
	for e in run.start_round():
		if e.t == "pay":
			var said: Array = [Lang.t("金币 +%d") % e.gold]
			if int(e.interest) > 0:
				said.append(Lang.t("利息 +%d") % e.interest)
			tags.float_text(Vector3(0, 2.5, HomeView.YARD_Z - 2.0), "  ".join(said), Color(1.0, 0.85, 0.45), 22)
	_version += 1
	refresh()


## The player's part (GAME-DESIGN 26): the shelf dealt; buying and building till the player is done ("fight").
func _player_part() -> void:
	phase = Phase.PLAN
	part = "play"
	held = -1
	refresh()
	await player_done


## The homeland as this round's making and eating will leave it (Home.settled) while the player is at it: the young
## that will fight, what the stars will have eaten -- for the forecast and what is said of the army. Else the homeland
## itself.
func ahead() -> Home:
	if phase != Phase.PLAN:
		return home
	if _ahead_at != _version:
		_ahead = home.settled()
		_ahead_at = _version
	return _ahead


## This round's young: in the player's part, those that will fight (ahead); after the making, those hatched, till the
## eating has fed them; then those fed.
func army_now() -> Array:
	if phase == Phase.PLAN:
		return ahead().fighters
	return home.fighters if not home.fighters.is_empty() else home.brood


## Where the blueprint plans[i] can go (Home.targets), worked out once while the homeland stays as it is.
func fits_of(i: int) -> Array:
	if _fits_at != _version:
		_fits = {}
		_fits_at = _version
	if not _fits.has(i):
		_fits[i] = home.targets(home.plans[i]) if i >= 0 and i < home.plans.size() else []
	return _fits[i]


## Whether the building clicked can be raised (gold, the top level).
func raise_fits() -> bool:
	return not pending.is_empty() and home.can_raise(pending.at)


## The making (GAME-DESIGN 26): what the buildings bring in, said over the homeland; then the nests hatch this round's
## young, each out of its nest to its place in the yard. With no eating part to the round (the stars put away,
## Content.phases), the young are fed here all the same -- those fed are the ones that fight.
func _make() -> void:
	phase = Phase.BUSY
	part = "make"
	held = -1
	pending = {}
	aimed = ""
	hud.stow()
	refresh()
	hud.banner(Lang.t("生产"))
	await get_tree().create_timer(0.5).timeout
	for e in run.make():
		match e.t:
			"income":
				var said: Array = []
				if int(e.genes) > 0:
					said.append(Lang.t("研究点数 +%d") % e.genes)
				if int(e.gold) > 0:
					said.append(Lang.t("金币 +%d") % e.gold)
				if not said.is_empty():
					tags.float_text(Vector3(0, 2.5, HomeView.YARD_Z - 2.0), "  ".join(said), Color(0.6, 1.0, 0.8), 22)
			"mended":
				tags.float_text(Vector3(0, 3.0, 0), Lang.t("铁背：家园 +%d") % e.amount, Color(0.5, 1.0, 0.5), 24)
	if not "eat" in Content.phases():
		run.eat()
	_version += 1
	refresh()
	home_view.sync_army(home.brood)
	await get_tree().create_timer(1.2).timeout


## The eating (GAME-DESIGN 26): what the stars and the young eat, said over the homeland; any young not fed go back
## into their nests.
func _eat() -> void:
	part = "eat"
	refresh()
	hud.banner(Lang.t("消耗"))
	await get_tree().create_timer(0.5).timeout
	for e in run.eat():
		match e.t:
			"fed":
				var fed_at := HomeView.PEN_AT[2] + Vector3(0, 3.0, 0)
				if int(e.ate) > 0:
					tags.float_text(fed_at, Lang.t("明星恐龙吃了 %d 生物质") % e.ate, Color(0.7, 1.0, 0.6), 20)
				if not (e.hungry as Array).is_empty():
					var names: Array = e.hungry.map(func(id: String) -> String: return Lang.t(Content.STARS[id].name))
					tags.float_text(fed_at + Vector3(0, 1.4, 0), Lang.t("%s没吃饱，这一轮不干活") % Lang.t("、").join(names),
						Color(1.0, 0.6, 0.45), 20)
			"young":
				var said := Lang.t("兵吃了 %d 生物质") % e.ate
				if int(e.behind) > 0:
					said += Lang.t("，%d 只没吃上，回巢") % e.behind
				tags.float_text(Vector3(0, 2.5, HomeView.YARD_Z - 2.0), said, Color(0.7, 1.0, 0.6), 20)
			"ash":
				tags.float_text(Vector3(0, 4.0, 0), Lang.t("镰刀：家园 −%d") % e.amount, Color(1.0, 0.55, 0.4), 24)
	_version += 1
	refresh()
	home_view.sync_army(home.fighters)
	await get_tree().create_timer(0.9).timeout


## The battle (GAME-DESIGN 26): the young fed go out and fight, till it is fought to its end.
func _fight() -> void:
	phase = Phase.FIGHT
	part = "fight"
	held = -1
	refresh()
	hud.stow()
	fight = run.fight()
	fight_view.setup(fight)
	home_view.go_out()
	await get_tree().create_timer(0.4).timeout
	await _fly(FIGHT_AT, FIGHT_DIST, 1.0)
	at_home = false
	hud.refresh()
	hud.banner(Lang.t("开战"), Lang.t("我方 %d 只，敌方 %d 只") % [fight.alive("ours").size(), fight.alive("theirs").size()])
	await get_tree().create_timer(0.7).timeout
	_acc = 0.0
	_fighting = true
	await fight_over


## After the battle, its part of the round still: what it brought (research points, won or lost; won, gold; lost, the
## homeland hurt; what the scavengers bring back). Then the run's end, or the next place after a boss. Whether the run
## goes on.
func _after_fight() -> bool:
	var result := fight.result
	fight_view.show_loot()
	await get_tree().create_timer(0.7).timeout
	var out := run.finish(fight)
	var also: Array = [Lang.t("研究点数 +%d") % out.research]
	if int(out.scavenged) > 0:
		also.append(Lang.t("拾荒 +%d 金") % out.scavenged)
	match result:
		"won":
			hud.banner(Lang.t("赢了！"), Lang.t("得到：") + Lang.t("，").join([Lang.t("金币 +%d") % out.gold] + also))
		"time":
			hud.banner(Lang.t("拖到时间，算输"), Lang.t("，").join([Lang.t("家园 −%d") % out.took] + also))
		_:
			hud.banner(Lang.t("输了"), Lang.t("，").join([Lang.t("家园 −%d") % out.took] + also))
	await get_tree().create_timer(1.6).timeout
	await _fly(HOME_AT, HOME_DIST, 1.0)
	at_home = true
	phase = Phase.BUSY
	fight_view.clear()
	fight = null
	hud.refresh()
	if int(out.took) > 0:
		_shake = 1.0
		tags.float_text(Vector3(0, 4.0, 0), Lang.t("家园 −%d") % out.took, Color(1.0, 0.42, 0.34), 34)
		await get_tree().create_timer(1.0).timeout
	if run.over:
		phase = Phase.DONE
		refresh()
		var again: Variant = await hud.choose("家园被毁了……", Lang.t("撑到了%s第 %d 轮") % [Lang.t(Content.LEVELS[run.place].name), run.round],
			[], ["再来一局", "回主菜单"])
		_new_run(again == "回主菜单")
		return false
	if out.level_won and run.last_level():
		phase = Phase.DONE
		refresh()
		var names: Array = run.path.map(func(p: int) -> String: return Lang.t(Content.LEVELS[p].name))
		var again: Variant = await hud.choose("全部守住了！", Lang.t("%s都撑过来了，家园还剩 %d 血") % [Lang.t("、").join(names), home.hp], [],
			["再玩一遍", "回主菜单"])
		_new_run(again == "回主菜单")
		return false
	part = ""
	refresh()
	if out.level_won:
		await _level_end()
	return true


## A place held: the next place picked on the map and gone to -- the homeland made afresh there, carrying nothing --
## and its painting and ground.
func _level_end() -> void:
	refresh()
	going = await hud.choose_place(run)
	await _move()
	await hud.arrive(run.place)
	await _first_nest()


## A new run: straight in, or (`to_title`) by way of the title.
func _new_run(to_title := false) -> void:
	show_title = to_title
	Run.current = null
	get_tree().paused = false
	get_tree().reload_current_scene()


# -- The title and the pause menu ------------------------------------------------------------------------------

## The title over a homeland at dusk, the camera going slowly round it; then the run begins, or the game ends.
func _title() -> void:
	phase = Phase.TITLE
	hud.visible = false
	_tags_layer.visible = false
	home_view.visible = false
	_showcase = HomeView.new()
	add_child(_showcase)
	_showcase.setup(showcase())
	_showcase.sync_army(_showcase.home.army(), false)
	world.dusk(true)
	world.motes(true)
	Sound.air(true, 3.0)
	menu.black()
	menu.fade(false, 1.8)
	var what := await menu.title()
	if what == "quit":
		get_tree().quit()
		return
	await menu.fade(true, 0.7)
	_showcase.queue_free()
	_showcase = null
	world.motes(false)
	world.dusk(false)
	home_view.visible = true
	hud.visible = true
	_tags_layer.visible = true
	phase = Phase.BUSY
	show_title = false
	_place_camera()
	menu.fade(false, 0.7)
	_begin()


## The game stopped under the pause menu; then on again, or a new run, or the title, or the end.
func pause() -> void:
	if phase == Phase.TITLE or menu.screen != "":
		return
	_let_go()
	get_tree().paused = true
	var what := await menu.pause()
	get_tree().paused = false
	match what:
		"restart":
			_new_run()
		"menu":
			_new_run(true)
		"quit":
			get_tree().quit()


## A homeland to look at under the title: the battle line laid out for the nests' gifts -- greens guarding, reds
## swarming, a gold alone, a blue under cover -- the rows behind built up, a pond, an old tree.
static func showcase() -> Home:
	var h := Home.new(RandomNumberGenerator.new())
	h.buildings.clear()
	h.terrain = {Vector2i(0, 2): "pond", Vector2i(5, 3): "tree"}
	# [plot, kind, nest's choices or a level, affixes]
	for step in [[Vector2i(0, 0), "nest_green", ["elite"], ["shell"]], [Vector2i(1, 0), "nest_red", ["elite"], ["blade", "wings"]],
			[Vector2i(2, 0), "nest_red", ["elite", "elite"], ["flame", "blade"]], [Vector2i(3, 0), "nest_green", [], []],
			[Vector2i(4, 0), "nest_red", [], []], [Vector2i(5, 0), "nest_gold", ["elite"], []],
			[Vector2i(0, 1), "nest_white", [], []], [Vector2i(1, 1), "nest_red", [], ["hide"]],
			[Vector2i(2, 1), "nest_red", [], ["haste"]], [Vector2i(3, 1), "nest_blue", ["elite"], ["acid"]],
			[Vector2i(4, 1), "nest_scav", [], []], [Vector2i(5, 1), "nest_mutant", [], ["acid", "poison"]],
			[Vector2i(0, 2), "pool", 3, []], [Vector2i(1, 2), "sampler", 2, []], [Vector2i(2, 2), "horde_totem", 1, []],
			[Vector2i(3, 2), "watchtower", 2, []], [Vector2i(4, 2), "mine", 2, []], [Vector2i(5, 2), "champion_hall", 1, []],
			[Vector2i(0, 3), "spore_pool", 2, []], [Vector2i(1, 3), "vault", 1, []], [Vector2i(2, 3), "stabilizer", 1, []],
			[Vector2i(3, 3), "gene_bank", 1, []], [Vector2i(4, 3), "vanguard", 2, []]]:
		h.build(step[0], step[1])
		var b: Dictionary = h.buildings[step[0]]
		if step[2] is Array:
			b.path = step[2].duplicate()
			b.level = 1 + b.path.size()
		else:
			b.level = step[2]
		b.affixes = step[3].duplicate()
	h.biomass = 80
	return h


# -- The camera ---------------------------------------------------------------------------------------------------

func _place_camera() -> void:
	var pitch := deg_to_rad(PITCH)
	var at := _cam_at
	if _shake > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		at += Vector3(sin(t * 47.0), 0, cos(t * 39.0)) * _shake * 0.35
	camera.position = at + Vector3(0, sin(pitch), cos(pitch)) * _cam_dist
	camera.look_at(at, Vector3.UP)


func _fly(to: Vector3, dist: float, time: float) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_cam_at", to, time)
	tw.tween_property(self, "_cam_dist", dist, time)
	await tw.finished
