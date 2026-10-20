class_name Game
extends Node3D
## The game (GAME-DESIGN 17-22): the homeland built from the shop, and the battles its army fights by itself, on one
## screen. It opens on the title (Menu) over a homeland at dusk; Esc pauses. A run starts with an ark to choose and
## lands in the rainforest. A round: the place has its way, the
## buildings bring in gold, biomass and genes, the shelf is stocked and the nests hatch this round's army -- standing
## in the yard as it will stand in battle, where their nests stand on the battle line; the player buys -- buildings,
## raises (a nest's as a choice: one more, or elite), gene affixes -- or keeps what is bought for later, puts down what
## was kept, takes a kind out of the shop, builds the wonder, watching the army change; then sends it out; the battle
## fights itself, and the army is gone with it. Won: gold and research points; lost: the homeland is hurt; either way,
## interest on the gold kept, and one of three cards for the deck the shop draws from -- or gold instead. Round 3 is
## against the place's mini-boss, and after it the deck can be cut and upgraded. Five rounds hold a place, the last
## against its boss; a
## place held brings a relic, and the ark moves on -- carrying all the gold, the wonder and what the player packs, no
## more than the stash holds -- to the volcano. How the battle will end is worked out and shown before it is fought,
## and again with the offer, the good, the choice or the wonder pointed at.
##
## Every player action goes through act(what, data). Coloured blocks stand in for what will be.

signal departed

enum Phase { BUSY, PLAN, FIGHT, PACK, MOVE, DONE, TITLE }

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
const PACK_TINT := Color(1.0, 0.8, 0.3)

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
var held_k := -1                  # the stash place taken up, or -1
var hover := {"plot": HomeView.NOWHERE, "unit": ""}
var fight: Fight                  # the battle being fought, or null
var speed := 1.0
var at_home := true               # the camera is over the homeland (not the battle field)
var forecast := {}                # this round's battle as things stand: {result, left, total, harm, loot}
var preview := {}                 # the same with what is taken up used; {} when none
var effects := {}                 # plot -> [short lines]: what that would change there (for Tags)
var pack_plots := {}              # packing: plot -> true, the buildings the ark takes
var pack_kept := {}               # packing: stash place -> true, the goods kept that it takes
var pending := {}                 # a nest's raise waiting for its choice: {from: "buy" or "place", slot, at}; {} if none

var aimed := ""                   # pointed at on the HUD, to show what it would do: a raise's choice, or a wonder

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
			_after_fight()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
	_place_camera()


# -- What the player does --------------------------------------------------------------------------------------

## The one door for a player's action: "buy" {slot, at, choice}, "store" {slot}, "place" {slot, at, choice},
## "choose" {choice} (for the raise waiting), "remove" {slot}, "wonder" {id}, "reroll", "fight"; while packing, "pack"
## {at} or {kept} and "depart". Whether it happened.
func act(what: String, data := {}) -> bool:
	if phase == Phase.PACK:
		match what:
			"pack":
				return _toggle_pack(data)
			"depart":
				_depart()
				return true
		return false
	if phase != Phase.PLAN:
		return false
	match what:
		"buy":
			var ev := home.buy(int(data.get("slot", -1)), data.get("at", true), str(data.get("choice", "count")))
			if ev.is_empty():
				return false
			held = -1
			pending = {}
			_changed(ev)
			hud.deal(home.shelf)
			return true
		"choose":
			if pending.is_empty():
				return false
			var p := pending
			pending = {}
			aimed = ""
			return act(p.from, {"slot": p.slot, "at": p.at, "choice": data.get("choice", "count")})

		"wonder":
			var ev := home.build_wonder(str(data.get("id", "")))
			if ev.is_empty():
				return false
			aimed = ""
			home_view.show_wonder(true)
			_changed(ev)
			return true
		"store":
			var ev := home.store(int(data.get("slot", -1)))
			if ev.is_empty():
				return false
			held = -1
			_changed(ev)
			hud.deal(home.shelf)
			return true
		"place":
			var ev := home.place(int(data.get("slot", -1)), data.get("at", true), str(data.get("choice", "count")))
			if ev.is_empty():
				return false
			held_k = -1
			pending = {}
			_changed(ev)
			return true
		"reroll":
			if not run.reroll():
				return false
			held = -1
			_version += 1
			hud.deal(home.shelf)
			refresh()
			return true
		"fight":
			_fight()
			return true
	return false


## The offer at shelf place i taken up (again: put down).
func hold(i: int) -> void:
	if phase != Phase.PLAN or i < 0 or i >= home.shelf.size() or home.shelf[i] == null:
		return
	held = -1 if held == i else i
	held_k = -1
	pending = {}
	refresh()


## What the HUD points at, to show what it would do: "count" or "elite" (the raise waiting), a wonder's id, or "".
func aim(what: String) -> void:
	aimed = what
	refresh()


## Lets go of whatever is taken up, waiting or pointed at.
func _let_go() -> void:
	held = -1
	held_k = -1
	pending = {}
	aimed = ""
	refresh()


## The good at stash place k taken up (again: put down).
func hold_kept(k: int) -> void:
	if phase != Phase.PLAN or k < 0 or k >= home.stash.size():
		return
	held_k = -1 if held_k == k else k
	held = -1
	pending = {}
	refresh()



func _changed(ev: Array) -> void:
	_version += 1
	for e in ev:
		match e.t:
			"built", "replaced", "raised", "affixed":
				home_view.refresh_buildings()
				if e.t == "replaced":
					tags.float_text(HomeView.plot_pos(e.at) + Vector3.UP * 3.0, Lang.t("退 %d 金") % e.back, Color(1.0, 0.8, 0.4))
				if e.t == "raised" and e.get("choice", "") == "elite":
					tags.float_text(home_view.top(e.at) + Vector3.UP * 1.5, Lang.t("精英！"), HomeView.ELITE_GOLD, 28)
				if e.t == "affixed":
					var b: Dictionary = home.buildings[e.at]
					var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
					if e.affix in sp.used:
						tags.float_text(home_view.top(e.at) + Vector3.UP * 1.5, Lang.t("进化！%s") % Lang.t(Content.UNITS[sp.kind].name),
							(Content.UNITS[sp.kind].color as Color).lightened(0.3), 28)
			"stored":
				tags.float_text(Vector3(-8, 3.0, HomeView.YARD_Z - 2.0), Lang.t("存起来了"), Color(0.6, 1.0, 0.55), 22)
			"wonder":
				tags.float_text(HomeView.WONDER_AT + Vector3(0.0, 3.0, 3.0), Lang.t("%s 造好了！") % Lang.t(Content.WONDERS[e.id].name),
					Content.WONDERS[e.id].color, 30)
	home_view.sync_army(home.army())
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
		if k >= KEY_1 and k < KEY_1 + home.shelf.size():
			hold(k - KEY_1)
		elif k == KEY_ESCAPE:
			if held >= 0 or held_k >= 0 or not pending.is_empty():
				_let_go()
			else:
				pause()
		elif k == KEY_F3:
			debug = not debug
			refresh()
		elif k == KEY_SPACE or k == KEY_ENTER:
			act("depart" if phase == Phase.PACK else "fight")


func _click() -> void:
	if phase == Phase.PACK:
		if hover.plot != HomeView.NOWHERE and home.buildings.has(hover.plot):
			act("pack", {"at": hover.plot})
		return
	var good := _taken()
	if phase != Phase.PLAN or good.is_empty():
		return
	var at: Variant = _aim(Content.offer(good))
	if at == null:
		return
	var fits := home.targets(held) if held >= 0 else home.stash_targets(held_k)
	var c := Content.offer(good)
	var raise_nest: bool = c.type == "raise" and at in fits and Content.is_nest(home.buildings[at].kind)
	var plus_nest: bool = c.type == "build" and c.plus and Content.is_nest(c.builds) and at in fits and not good.has("packed")
	if raise_nest or plus_nest:
		# A nest's raise (an upgraded nest's, put down at level 2, too): one more, or elite -- the HUD asks which.
		pending = {"from": "buy" if held >= 0 else "place", "slot": held if held >= 0 else held_k, "at": at}
		refresh()
		return
	if held >= 0:
		act("buy", {"slot": held, "at": at})
	else:
		act("place", {"slot": held_k, "at": at})


## The good taken up -- from the shelf or the stash -- or {} when none is.
func _taken() -> Dictionary:
	if held >= 0 and held < home.shelf.size() and home.shelf[held] != null:
		return home.shelf[held]
	if held_k >= 0 and held_k < home.stash.size():
		return home.stash[held_k]
	return {}


func _hover_at(pos: Vector2) -> void:
	var h := {"plot": HomeView.NOWHERE, "unit": ""}
	if at_home:
		h = home_view.pick(camera, pos, _want())
	if h.plot != hover.plot or h.unit != hover.unit:
		hover = h
		refresh()


## What the cursor should find, for the good taken up.
func _want() -> String:
	if phase == Phase.PACK:
		return "building"
	var good := _taken()
	if phase != Phase.PLAN or good.is_empty():
		return "any"
	match Content.offer(good).target:
		"tile":
			return "tile"
		"building", "nest":
			return "building"
	return "any"


## What the good taken up would go on, under the cursor: a plot, or null.
func _aim(_c: Dictionary) -> Variant:
	return hover.plot if hover.plot != HomeView.NOWHERE else null


# -- Packing and moving on --------------------------------------------------------------------------------------

## A building or a kept good put in the ark or taken out again -- no more than the stash holds.
func _toggle_pack(data: Dictionary) -> bool:
	var plot := data.has("at")
	var key: Variant = data.get("at") if plot else int(data.get("kept", -1))
	var list := pack_plots if plot else pack_kept
	if plot and not home.buildings.has(key) or not plot and (int(key) < 0 or int(key) >= home.stash.size()):
		return false
	if list.has(key):
		list.erase(key)
	elif pack_plots.size() + pack_kept.size() >= home.stash_size():
		tags.float_text(Vector3(0, 4.0, 0), Lang.t("装满了：最多 %d 样，先放下一样") % home.stash_size(), Color(1.0, 0.6, 0.4), 22)
		return false
	else:
		list[key] = true
	refresh()
	return true


## The goods the ark takes as things stand.
func packed_goods() -> Array:
	return run.packable().filter(func(g: Dictionary) -> bool:
		return g.has("from") and pack_plots.has(g.from) or g.has("kept") and pack_kept.has(int(g.kept)))


## What the homeland in the next place would eat and make each round, with what the ark takes and what it sets down
## of itself: [biomass its nests' units eat, biomass its pools make] -- at their levels, before neighbours and ground.
func pack_food() -> Array:
	return Run.food_of(packed_goods())


## Packing on the homeland: the ark's load picked -- to begin with, what is worth most, fed (Run.default_goods) -- until
## the player sets out.
func _pack() -> void:
	phase = Phase.PACK
	held = -1
	held_k = -1
	pack_plots.clear()
	pack_kept.clear()
	for g in run.default_goods():
		if g.has("from"):
			pack_plots[g.from] = true
		else:
			pack_kept[int(g.kept)] = true
	hud.stow()
	refresh()
	await departed


## Setting out: the ark comes down and takes what was packed, the rest is left; it flies to the next place and sets
## down what the ark itself brings there -- the packed goods wait in the stash.
func _depart() -> void:
	var goods := packed_goods()
	phase = Phase.MOVE
	refresh()
	await home_view.ark_down()
	await home_view.load_up(pack_plots.keys())
	await home_view.ark_up()
	await hud.fade(true)
	run.move_on(goods, going)
	pack_plots.clear()
	pack_kept.clear()
	world.dress(run.place)
	home_view.lay_ground()
	_version += 1
	refresh()
	await hud.fade(false)
	await home_view.ark_down()
	await home_view.set_down()
	await home_view.ark_up()
	departed.emit()


# -- What is shown --------------------------------------------------------------------------------------------

## The forecast worked out again where the homeland changed; the plots the good taken up can go on lit (orange where
## it would pull a building down), the one it points at brighter, and the forecast and what changes with it there;
## while packing, the buildings the ark takes lit gold; the HUD brought up to date.
## The language changed (Settings): the screen's words made again.
func relanguage() -> void:
	hud.relanguage()
	refresh()


func refresh() -> void:
	var tints := {}
	preview = {}
	effects = {}
	if phase == Phase.PLAN:
		if _forecast_at != _version:
			forecast = _work_out(home)
			_forecast_at = _version
		var good := _taken()
		if not pending.is_empty():
			tints[pending.at] = HOT_TINT
			if aimed in ["count", "elite"]:
				var p := pending
				var choice := aimed
				var buy_it: bool = p.from == "buy"
				_try("%s%d|%s|%s" % [p.from, p.slot, str(p.at), choice], func(h: Home) -> void:
					if buy_it:
						h.buy(p.slot, p.at, choice)
					else:
						h.place(p.slot, p.at, choice))
		elif Content.WONDERS.has(aimed):
			var id := aimed
			_try("wonder" + id, func(h: Home) -> void: h.build_wonder(id))
		elif not good.is_empty():
			var c := Content.offer(good)
			var fits := home.targets(held) if held >= 0 else home.stash_targets(held_k)
			for t in fits:
				if t is Vector2i:
					tints[t] = SWAP_TINT if c.type == "build" and home.buildings.has(t) else OK_TINT
			var at: Variant = _aim(c)
			if at != null and at in fits:
				if at is Vector2i:
					tints[at] = HOT_TINT
				if held >= 0:
					var i := held
					_try("buy%d|%s" % [i, str(at)], func(h: Home) -> void: h.buy(i, at))
				else:
					var k := held_k
					_try("place%d|%s" % [k, str(at)], func(h: Home) -> void: h.place(k, at))
			elif at is Vector2i and home.is_open(at):
				tints[at] = BAD_TINT
		elif hover.plot != HomeView.NOWHERE and home.is_open(hover.plot):
			tints[hover.plot] = LOOK_TINT
	elif phase == Phase.PACK:
		for p in pack_plots:
			tints[p] = PACK_TINT
		if hover.plot != HomeView.NOWHERE and home.buildings.has(hover.plot) and not pack_plots.has(hover.plot):
			tints[hover.plot] = LOOK_TINT
	home_view.tints = tints
	home_view.paint()
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


## How this round's battle ends if fought by `h` -- the same rules, so the same end.
func _work_out(h: Home) -> Dictionary:
	var f := Fight.make(h.army(), run.wave(), run.power())
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
				if int(sb.atk_bonus) != int(sa.atk_bonus):
					lines.append(Lang.t("攻击 %+d") % (int(sb.atk_bonus) - int(sa.atk_bonus)))
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
		for pair in [[Lang.t("金币"), b.income_gold() - a.income_gold(), Lang.t("/轮")], [Lang.t("生物质"), b.income_biomass() - a.income_biomass(), Lang.t("/轮")],
				[Lang.t("研究点数"), b.income_genes() - a.income_genes(), Lang.t("/轮")], [Lang.t("利息上限"), b.interest_max() - a.interest_max(), ""],
				[Lang.t("家园血"), b.hp_max() - a.hp_max(), ""]]:
			if int(pair[1]) != 0:
				lines.append("%s %+d%s" % [pair[0], pair[1], pair[2]])
		if not lines.is_empty():
			out[p] = lines
	return out


func _made(h: Home) -> Dictionary:
	var out := {}
	for u in h.army():
		out[u.nest] = int(out.get(u.nest, 0)) + 1
	return out


## What to do with the good taken up, said over the shelf: "" when none is.
func hint() -> String:
	if phase != Phase.PLAN:
		return ""
	if not pending.is_empty():
		return Lang.t("选一样：多孵 1 只，还是变精英 · 右键算了")
	var good := _taken()
	if good.is_empty():
		return ""
	var c := Content.offer(good)
	var p: Vector2i = hover.plot
	if held_k >= 0:
		if home.stash_targets(held_k).is_empty():
			return Lang.t("现在没有地方放得下")
		match c.target:
			"tile":
				if p != HomeView.NOWHERE and home.buildings.has(p) and home.buildings[p].kind != c.builds:
					return Lang.t("拆掉%s，放下%s（退 %d 金）· 右键放回去") % [Lang.t(Content.BUILDINGS[home.buildings[p].kind].name), c.name,
						int(Content.BUILDINGS[home.buildings[p].kind].cost) / 2]
				return Lang.t("点一块地放下%s（已经是你的，不要钱）· 右键放回去") % c.name
			"nest":
				return Lang.t("点一个还有空词条位的巢贴上%s（不要钱）· 右键放回去") % c.name
		return ""
	if home.genes < home.genes_cost(c):
		return Lang.t("研究点数不够（要 %d）") % home.genes_cost(c)
	if c.type != "raise" and home.gold < home.price(held):
		return Lang.t("金币不够（要 %d）") % home.price(held)
	if home.targets(held).is_empty():
		return Lang.t("现在没有地方用得上") if c.type != "raise" else Lang.t("金币不够升任何一座（升几级的，就要几加 %d）") % Content.RAISE
	var say := ""
	match c.target:
		"tile":
			if p != HomeView.NOWHERE and home.buildings.has(p) and home.buildings[p].kind != c.builds:
				var was: String = home.buildings[p].kind
				say = Lang.t("拆掉%s换成%s（%d 金，退 %d 金）") % [Lang.t(Content.BUILDINGS[was].name), c.name, home.price(held),
					int(Content.BUILDINGS[was].cost) / 2]
			else:
				say = Lang.t("点一块空地造%s（%d 金）；点一座别的建筑，就拆了换成它") % [c.name, home.price(held)]
		"building":
			if p != HomeView.NOWHERE and home.buildings.has(p) and int(home.buildings[p].level) < Content.LEVEL_MAX:
				var b: Dictionary = home.buildings[p]
				say = Lang.t("%s升到 %d 级（%d 金）%s") % [Lang.t(Content.BUILDINGS[b.kind].name), int(b.level) + 1, home.price(held, p),
					Lang.t("，点了再选多孵还是精英") if Content.is_nest(b.kind) else ""]
			else:
				say = Lang.t("点一座建筑升一级（最多 %d 级；几级升上去，就要几加 %d 金）") % [Content.LEVEL_MAX, Content.RAISE]
		"nest":
			say = Lang.t("点一个还有空词条位的巢（%d 金）") % home.price(held)
	if home.can_store(held):
		say += Lang.t("；或点左下的空格存起来（%d 金）") % home.store_price(held)
	return say + Lang.t(" · 右键放下")


## What the cursor points at, for the panel: "" for nothing.
func describe() -> String:
	if not at_home or phase == Phase.DONE or phase == Phase.MOVE:
		return ""
	if hover.unit != "":
		for u in home.army():
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
	if phase == Phase.PACK:
		text = (Lang.t("点一下：留下，不带走\n") if pack_plots.has(p) else Lang.t("点一下：带走\n")) + text
	return text


func _unit_text(u: Dictionary) -> String:
	var s := Content.unit_stats(u)
	var nest: Dictionary = home.buildings.get(u.nest, {})
	var from := Lang.t("巨兽笼放出来的") if nest.is_empty() else Lang.t("%s %d 级孵的") % [Lang.t(Content.BUILDINGS[nest.kind].name), int(nest.level)]
	var lines: Array = [Lang.t("%s%s（%s，站%s）") % [Lang.t("精英") if int(u.get("elite", 0)) > 0 else "", Lang.t(s.name), from,
		Lang.t("前排") if int(u.get("row", 0)) == 0 else Lang.t("后排")],
		Lang.t("血 %d · 攻击 %d · %s 秒打一下 · 够得着 %s 米") % [s.hp, s.atk, _num(s.every), _num(s.range)]]
	var more: Array = []
	if int(s.armor) > 0:
		more.append(Lang.t("护甲 %d") % s.armor)
	if int(s.pierce) > 0:
		more.append(Lang.t("每下多 %d，不管护甲") % s.pierce)
	if float(s.splash) > 0.0:
		more.append(Lang.t("一打一片（%s 米）") % _num(s.splash))
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
	lines.append(Lang.t("吃 %d 生物质，只活这一仗") % int(Content.UNITS[u.kind].food) if not u.free else Lang.t("只活这一仗（恐龙蛋化石多孵的，不吃生物质）"))
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
			lines.append(Lang.t("孵%s：%s（每只吃 %d 生物质）") % [Lang.t(unit.name), Lang.t(unit.role), unit.food])
		var t: Dictionary = Content.TRAITS[info.trait]
		var need := home.trait_need(p)
		var state := "" if t.when == "" else (Lang.t("生效") if need == "" else Lang.t("没生效（%s）") % need)
		lines.append(Lang.t("本事「%s」%s：%s") % [Lang.t(t.name), state, Lang.t(t.does)])
		var made := int(_made(home).get(p, 0))
		var want := home.count(p)
		lines.append(Lang.t("这一轮孵 %d 只%s，打仗时站%s") % [made, (Lang.t("（生物质不够，少 %d）") % (want - made)) if made < want else "",
			Lang.t("前排") if p.y == 0 else Lang.t("后排")])
		var e := int(s.elite)
		if e > 0:
			lines.append(Lang.t("精英%s：血 ×%s、攻击 ×%s、大一号") % ["×%d" % e if e > 1 else "", Content._num(pow(Content.ELITE_HP, e)),
				Content._num(pow(Content.ELITE_ATK, e))])
		var given: Array = []
		if e > 0 and home._sum("elite") > 0:
			given.append(Lang.t("冠军殿：精英再 +%d%%") % home._sum("elite"))
		if p.y == 0 and home._sum("front") > 0:
			given.append(Lang.t("前锋营：前排血 +%d%%") % home._sum("front"))
		if maxf(float(Content.UNITS[s.kind].range), float(s.range)) >= 3.0 and home._sum("ranged") > 0:
			given.append(Lang.t("瞭望塔：每下多 %d，不管护甲") % home._sum("ranged"))
		if not given.is_empty():
			lines.append(Lang.t("，").join(given))
		var names: Array = b.affixes.map(func(a: String) -> String: return Lang.t(Content.AFFIXES[a].name))
		lines.append(Lang.t("词条：%s（还能贴 %d 个）") % [Lang.t("、").join(names) if not names.is_empty() else Lang.t("没有"), home.slots(p) - b.affixes.size()])
		if not s.evolved:
			for pair in Content.could_become(b.affixes):
				lines.append(Lang.t("再贴上%s，会进化成%s") % [Lang.t(Content.AFFIXES[pair[0]].name), Lang.t(Content.UNITS[pair[1]].name)])
	if int(b.level) < Content.LEVEL_MAX:
		lines.append(Lang.t("升到 %d 级：%s") % [int(b.level) + 1, Lang.t("多孵 1 只，或者变精英") if Content.is_nest(b.kind)
			else Content.level_text(b.kind, int(b.level) + 1)])
	return "\n".join(lines)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


## What the schools do for this round's army as a whole, said plainly (for the HUD): "" when nothing.
func bonuses() -> String:
	var parts: Array = []
	var n := home.army().size()
	var more := 0
	for p in home.buildings:
		if home.buildings[p].kind == "horde_totem":
			var each := int(home.level_of(p).per)
			more = each - n % each if more == 0 else mini(more, each - n % each)
	if more > 0:
		parts.append(Lang.t("兽群：出战 %d 只，全体攻击 +%d；再多 %d 只 +%d") % [n, home.horde_bonus(n), more,
			home.horde_bonus(n + more) - home.horde_bonus(n)])
	if home._sum("elite") > 0:
		parts.append(Lang.t("冠军殿：精英 +%d%%") % home._sum("elite"))
	if home._sum("ranged") > 0:
		parts.append(Lang.t("瞭望塔：远程每下多 %d，不管护甲") % home._sum("ranged"))
	if home._sum("front") > 0:
		parts.append(Lang.t("前锋营：前排血 +%d%%") % home._sum("front"))
	if home.wonder == "banner":
		parts.append(Lang.t("万兽战旗：全体攻击 +2、血 +25%"))
	return "\n".join(parts)


# -- The run ----------------------------------------------------------------------------------------------------

## The run's start: the ark chosen (when it has not been), the place it lands in, the first round.
func _begin() -> void:
	refresh()
	if run.ark == "":
		var id := await hud.choose_ark()
		run.choose_ark(id)
		home_view.lay_ground()
		home_view.refresh_buildings(true)
		_version += 1
		refresh()
	await hud.arrive(run.place)
	_start_round()


func _start_round() -> void:
	phase = Phase.BUSY
	held = -1
	held_k = -1
	pending = {}
	aimed = ""
	refresh()
	var sub := Lang.t("进账，商店换货，孵兵")
	if run.round == 1 and run.level > 0:
		sub = Lang.t("新地方。带来的东西在左下，点它放下；新放的池子下一轮才产生物质")
	elif run.round >= run.rounds():
		sub = Lang.t("首领来了")
	elif run.round in Content.MINI_ROUNDS:
		sub = Lang.t("小首领来了。打完可以整理牌库")
	elif run.big():
		sub = Lang.t("大波要来了")
	hud.banner(Lang.t("%s · 第 %d 轮") % [Lang.t(Content.LEVELS[run.place].name), run.round], sub)
	await get_tree().create_timer(0.6).timeout
	var ev := run.start_round()
	var said_at := Vector3(0, 2.5, HomeView.YARD_Z - 2.0)
	for e in ev:
		match e.t:
			"income":
				var said: Array = [Lang.t("金币 +%d") % e.gold]
				if int(e.biomass) > 0:
					said.append(Lang.t("生物质 +%d") % e.biomass)
				if int(e.genes) > 0:
					said.append(Lang.t("研究点数 +%d") % e.genes)
				tags.float_text(said_at, "  ".join(said), Color(0.6, 1.0, 0.8), 22)
			"rotted":
				if int(e.amount) > 0:
					tags.float_text(said_at + Vector3(0, 1.5, 0), Lang.t("潮湿：生物质烂了 %d") % e.amount, Color(0.75, 0.85, 0.5), 20)
			"ash":
				tags.float_text(Vector3(0, 4.0, 0), Lang.t("火山灰：家园 −%d") % e.amount, Color(1.0, 0.55, 0.4), 24)
			"mended":
				tags.float_text(Vector3(0, 3.0, 0), Lang.t("颈盾：家园 +%d") % e.amount, Color(0.5, 1.0, 0.5), 24)
	_version += 1
	home_view.sync_army(home.army())
	await get_tree().create_timer(0.5).timeout
	phase = Phase.PLAN
	held = -1
	held_k = -1
	hud.deal(home.shelf)
	refresh()


func _fight() -> void:
	phase = Phase.FIGHT
	held = -1
	held_k = -1
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


func _after_fight() -> void:
	var result := fight.result
	fight_view.show_loot()
	await get_tree().create_timer(0.7).timeout
	var out := run.finish(fight)
	var also: Array = []
	if int(out.scavenged) > 0:
		also.append(Lang.t("拾荒 +%d 金") % out.scavenged)
	if int(out.interest) > 0:
		also.append(Lang.t("利息 +%d") % out.interest)
	match result:
		"won":
			var won: Array = [Lang.t("金币 +%d") % out.gold]
			if int(out.research) > 0:
				won.append(Lang.t("研究点数 +%d") % out.research)
			hud.banner(Lang.t("赢了！"), Lang.t("得到：") + Lang.t("，").join(won + also))
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
		return
	if out.level_won and run.last_level():
		phase = Phase.DONE
		refresh()
		var names: Array = run.path.map(func(p: int) -> String: return Lang.t(Content.LEVELS[p].name))
		var again: Variant = await hud.choose("全部守住了！", Lang.t("%s都撑过来了，家园还剩 %d 血") % [Lang.t("、").join(names), home.hp], [],
			["再玩一遍", "回主菜单"])
		_new_run(again == "回主菜单")
		return
	await _reward()
	if run.was_mini():
		await _workshop()
	if out.level_won:
		await _level_end()
	_start_round()


## After each round: one of three cards into the deck (the shop will offer it, at its price) -- or gold instead.
func _reward() -> void:
	var cards := run.reward_offer()
	if cards.is_empty():
		return
	var v: Variant = await hud.choose("挑一张，加进牌库", "以后商店会从牌库里拿出来卖，照原价买", cards,
		[Lang.t("不要牌，拿 %d 金") % Content.REWARD_GOLD])
	if v is Dictionary:
		run.take_reward(v.id)
	else:
		run.take_reward_gold()
	refresh()


## After a place's mini-boss: the deck laid out, to cut cards from (gold, dearer each time) and upgrade (research
## points) until done.
func _workshop() -> void:
	while true:
		var v: Variant = await hud.workshop()
		if not v is Dictionary:
			break
		if v.has("cut"):
			home.cut(int(v.cut))
		elif v.has("upgrade"):
			home.upgrade(int(v.upgrade))
		refresh()


## A place held: a relic to choose, then the move -- what to carry picked on the homeland, the ark down to load it, on
## to the next place, the ark setting down what it brings -- and the new place's rule and ground.
func _level_end() -> void:
	var id := await hud.choose_relic(run.relic_offer())
	run.take_relic(id)
	refresh()
	going = await hud.choose_place(run)
	await _pack()
	await hud.arrive(run.place)


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
	for step in [[Vector2i(0, 0), "nest_green", ["count"], ["shell"]], [Vector2i(1, 0), "nest_red", ["elite"], ["blade", "wings"]],
			[Vector2i(2, 0), "nest_red", ["count", "count"], ["flame", "blade"]], [Vector2i(3, 0), "nest_green", ["count"], []],
			[Vector2i(4, 0), "nest_red", [], []], [Vector2i(5, 0), "nest_gold", ["elite"], []],
			[Vector2i(0, 1), "nest_white", [], []], [Vector2i(1, 1), "nest_red", ["count"], ["hide"]],
			[Vector2i(2, 1), "nest_red", [], ["haste"]], [Vector2i(3, 1), "nest_blue", ["count"], ["acid"]],
			[Vector2i(4, 1), "nest_scav", ["count"], []], [Vector2i(5, 1), "nest_mutant", ["count"], ["acid", "poison"]],
			[Vector2i(0, 2), "pool", 3, []], [Vector2i(1, 2), "sampler", 2, []], [Vector2i(2, 2), "horde_totem", 1, []],
			[Vector2i(3, 2), "watchtower", 2, []], [Vector2i(4, 2), "mine", 2, []], [Vector2i(5, 2), "champion_hall", 1, []],
			[Vector2i(0, 3), "spore_pool", 2, []], [Vector2i(1, 3), "vault", 1, []], [Vector2i(2, 3), "stabilizer", 1, []],
			[Vector2i(3, 3), "market", 1, []], [Vector2i(4, 3), "vanguard", 2, []]]:
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
