class_name Game
extends Node3D
## The game (GAME-DESIGN 17): the homeland built from the shop, and the battles its army fights by itself, on one
## screen. A run starts with an ark to choose and lands in the rainforest. A round: the place has its way, the
## buildings bring in gold, biomass and genes, the shelf is stocked and the nests hatch this round's army; the player
## buys -- buildings, raises, gene affixes, potions -- or keeps what is bought for later, puts down what was kept, and
## takes potions, watching the army change; then sends it out; the battle fights itself, and the army is gone with it.
## Won: gold, alien genes, a potion; lost: the homeland is hurt; either way, interest on the gold kept, and one of
## three offers, free. Five rounds hold a place, the last against its boss; a place held brings a relic, and the ark
## moves on -- carrying all the gold and what the player packs, no more than the stash holds -- to the volcano. How
## the battle will end is worked out and shown before it is fought, and again with the offer, the good or the potion
## pointed at.
##
## Every player action goes through act(what, data). Coloured blocks stand in for what will be.

signal departed

enum Phase { BUSY, PLAN, FIGHT, PACK, MOVE, DONE }

const HOME_AT := Vector3(0, 0, 4.0)
const HOME_DIST := 44.0
const FIGHT_AT := Vector3(0, 0, -79.0)
const FIGHT_DIST := 25.0
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
var forecast := {}                # this round's battle as things stand: {result, left, total, harm}
var preview := {}                 # the same with what is taken up (or the potion pointed at) used; {} when none
var effects := {}                 # plot -> [short lines]: what that would change there (for Tags)
var pack_plots := {}              # packing: plot -> true, the buildings the ark takes
var pack_kept := {}               # packing: stash place -> true, the goods kept that it takes

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
var _potion := -1                 # the potion pointed at, or -1


func _ready() -> void:
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
	_begin()


func _process(delta: float) -> void:
	if _fighting:
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

## The one door for a player's action: "buy" {slot, at}, "store" {slot}, "place" {slot, at}, "reroll", "potion"
## {slot}, "fight"; while packing, "pack" {at} or {kept} and "depart". Whether it happened.
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
			var ev := home.buy(int(data.get("slot", -1)), data.get("at", true))
			if ev.is_empty():
				return false
			held = -1
			_changed(ev)
			hud.deal(home.shelf)
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
			var ev := home.place(int(data.get("slot", -1)), data.get("at", true))
			if ev.is_empty():
				return false
			held_k = -1
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
		"potion":
			var ev := home.use_potion(int(data.get("slot", -1)))
			if ev.is_empty():
				return false
			_potion = -1
			_changed(ev)
			return true
		"fight":
			_fight()
			return true
	return false


## The offer at shelf place i taken up (again: put down -- or, for one used at once, bought).
func hold(i: int) -> void:
	if phase != Phase.PLAN or i < 0 or i >= home.shelf.size() or home.shelf[i] == null:
		return
	if held == i and Content.offer(home.shelf[i]).target == "none" and not home.targets(i).is_empty():
		act("buy", {"slot": i, "at": true})
		return
	held = -1 if held == i else i
	held_k = -1
	refresh()


## The good at stash place k taken up (again: put down).
func hold_kept(k: int) -> void:
	if phase != Phase.PLAN or k < 0 or k >= home.stash.size():
		return
	held_k = -1 if held_k == k else k
	held = -1
	refresh()


## The potion place k pointed at (its forecast shown), or -1.
func aim_potion(k: int) -> void:
	_potion = k if phase == Phase.PLAN and k < home.potions.size() else -1
	refresh()


func _changed(ev: Array) -> void:
	_version += 1
	for e in ev:
		match e.t:
			"built", "replaced", "raised", "affixed":
				home_view.refresh_buildings()
				if e.t == "replaced":
					tags.float_text(HomeView.plot_pos(e.at) + Vector3.UP * 3.0, "退 %d 金" % e.back, Color(1.0, 0.8, 0.4))
				if e.t == "affixed":
					var b: Dictionary = home.buildings[e.at]
					var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
					if e.affix in sp.used:
						tags.float_text(home_view.top(e.at) + Vector3.UP * 1.5, "进化！%s" % Content.UNITS[sp.kind].name,
							(Content.UNITS[sp.kind].color as Color).lightened(0.3), 28)
			"stored":
				tags.float_text(Vector3(-8, 3.0, HomeView.YARD_Z - 2.0), "存起来了", Color(0.6, 1.0, 0.55), 22)
			"gained":
				var what := ("基因 +%d" % e.genes) if int(e.genes) > 0 else ("生物质 +%d" % e.biomass)
				tags.float_text(Vector3(0, 3.0, HomeView.YARD_Z - 2.0), what, Color(0.6, 1.0, 0.8), 24)
			"potion", "potion_got":
				tags.float_text(Vector3(0, 3.0, HomeView.YARD_Z - 2.0), ("买到 " if e.t == "potion_got" else "") +
					Content.POTIONS[e.potion].name, Content.POTIONS[e.potion].color, 26)
			"mended":
				tags.float_text(Vector3(0, 3.0, 0), "家园 +%d" % e.amount, Color(0.5, 1.0, 0.5), 28)
	home_view.sync_army(home.army())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag:
			_cam_at += Vector3(-event.relative.x, 0, -event.relative.y) * _cam_dist * 0.0016
		_hover_at(event.position)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_click()
			MOUSE_BUTTON_RIGHT:
				if held >= 0 or held_k >= 0:
					held = -1
					held_k = -1
					refresh()
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
		elif k == KEY_ESCAPE and (held >= 0 or held_k >= 0):
			held = -1
			held_k = -1
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


## What the good taken up would go on, under the cursor: a plot, true for one used at once, or null.
func _aim(c: Dictionary) -> Variant:
	if c.target == "none":
		return true
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
		tags.float_text(Vector3(0, 4.0, 0), "装满了：最多 %d 样，先放下一样" % home.stash_size(), Color(1.0, 0.6, 0.4), 22)
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
	run.move_on(goods)
	pack_plots.clear()
	pack_kept.clear()
	world.dress(run.level)
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
func refresh() -> void:
	var tints := {}
	preview = {}
	effects = {}
	if phase == Phase.PLAN:
		if _forecast_at != _version:
			forecast = _work_out(home)
			_forecast_at = _version
		var good := _taken()
		if not good.is_empty():
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
		elif _potion >= 0 and _potion < home.potions.size():
			var k := _potion
			_try("potion%d" % k, func(h: Home) -> void: h.use_potion(k))
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
	var f := Fight.make(h.army(), h.buffs, run.wave(), run.power())
	var total := f.alive("ours").size()
	f.run()
	return {"result": f.result, "left": f.alive("ours").size(), "total": total,
		"harm": 0 if f.result == "won" else maxi(0, f.harm() - h.block())}


## What differs between two homelands, building by building, as short lines: more or fewer hatched, a new species,
## hardier, harder hitting, faster, an affix, more affix places; and at the plot of a building that brings something
## in, what it brings.
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
				lines.append("%+d 只" % d)
			if a.buildings.has(p) and a.buildings[p].kind == kind:
				var sa := a.spec_of(p)
				var sb := b.spec_of(p)
				if sb.kind != sa.kind:
					lines.append("进化：" + Content.UNITS[sb.kind].name)
				var q := float(Content.level(kind, int(b.buildings[p].level)).quality)
				var hp := roundi((float(sb.hp_mult) - float(sa.hp_mult)) / q * 100.0)
				if hp != 0:
					lines.append("血 %+d%%" % hp)
				if int(sb.atk_bonus) != int(sa.atk_bonus):
					lines.append("攻击 %+d" % (int(sb.atk_bonus) - int(sa.atk_bonus)))
				if int(sb.haste) != int(sa.haste):
					lines.append("快 %+d%%" % (int(sb.haste) - int(sa.haste)))
				for af in sb.affixes:
					if not af in sa.affixes:
						lines.append("+" + Content.AFFIXES[af].name)
				if b.slots(p) != a.slots(p):
					lines.append("词条位 %+d" % (b.slots(p) - a.slots(p)))
		if not lines.is_empty():
			out[p] = lines
	for p in b.buildings:
		if a.buildings.has(p) and a.buildings[p].kind == b.buildings[p].kind and a.buildings[p].level == b.buildings[p].level:
			continue
		var lines: Array = out.get(p, [])
		for pair in [["金币", b.income_gold() - a.income_gold(), "/轮"], ["生物质", b.income_biomass() - a.income_biomass(), "/轮"],
				["基因", b.income_genes() - a.income_genes(), "/轮"], ["挡", b.block() - a.block(), ""],
				["家园血", b.hp_max() - a.hp_max(), ""]]:
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
	if phase == Phase.PACK:
		return ""
	var good := _taken()
	if phase != Phase.PLAN or good.is_empty():
		return ""
	var c := Content.offer(good)
	var p: Vector2i = hover.plot
	if held_k >= 0:
		if home.stash_targets(held_k).is_empty():
			return "现在没有地方放得下"
		match c.target:
			"tile":
				if p != HomeView.NOWHERE and home.buildings.has(p) and home.buildings[p].kind != c.builds:
					return "拆掉%s，放下%s（退 %d 金）· 右键放回去" % [Content.BUILDINGS[home.buildings[p].kind].name, c.name,
						int(Content.BUILDINGS[home.buildings[p].kind].cost) / 2]
				return "点一块地放下%s（已经是你的，不要钱）· 右键放回去" % c.name
			"nest":
				return "点一个还有空词条位的巢贴上%s（不要钱）· 右键放回去" % c.name
		return ""
	if home.genes < int(c.get("genes", 0)):
		return "基因不够（要 %d）" % c.genes
	if home.alien < int(c.get("alien", 0)):
		return "外星基因不够（要 %d，打赢了才有）" % c.alien
	if c.type != "raise" and home.gold < home.price(held):
		return "金币不够（要 %d）" % home.price(held)
	if home.targets(held).is_empty():
		return "现在没有地方用得上" if c.type != "raise" else "金币不够升任何一座（升几级的，就要几加 %d）" % Content.RAISE
	var say := ""
	match c.target:
		"tile":
			if p != HomeView.NOWHERE and home.buildings.has(p) and home.buildings[p].kind != c.builds:
				var was: String = home.buildings[p].kind
				say = "拆掉%s换成%s（%d 金，退 %d 金）" % [Content.BUILDINGS[was].name, c.name, home.price(held),
					int(Content.BUILDINGS[was].cost) / 2]
			else:
				say = "点一块空地造%s（%d 金）；点一座别的建筑，就拆了换成它" % [c.name, home.price(held)]
		"building":
			if p != HomeView.NOWHERE and home.buildings.has(p) and int(home.buildings[p].level) < Content.LEVEL_MAX:
				say = "%s升到 %d 级（%d 金）" % [Content.BUILDINGS[home.buildings[p].kind].name, int(home.buildings[p].level) + 1,
					home.price(held, p)]
			else:
				say = "点一座建筑升一级（最多 %d 级；几级升上去，就要几加 %d 金）" % [Content.LEVEL_MAX, Content.RAISE]
		"nest":
			say = "点一个还有空词条位的巢（%d 金）" % home.price(held)
		_:
			say = "再点一下就买（%d 金）" % home.price(held)
	if home.can_store(held):
		say += "；或点左下的空格存起来"
	return say + " · 右键放下"


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
			return "%s\n%s" % [Content.TERRAIN[ground].name, Content.TERRAIN[ground].says]
		return "空地：建筑可以造在这里"
	var text := _building_text(p)
	if ground != "":
		text += "\n建在%s上：%s" % [Content.TERRAIN[ground].name, Content.TERRAIN[ground].says]
	if phase == Phase.PACK:
		text = ("点一下：留下，不带走\n" if pack_plots.has(p) else "点一下：带走\n") + text
	return text


func _unit_text(u: Dictionary) -> String:
	var s := Content.unit_stats(u, home.buffs)
	var nest: Dictionary = home.buildings.get(u.nest, {})
	var lines: Array = ["%s（%s %d 级孵的）" % [s.name, Content.BUILDINGS[nest.kind].name if not nest.is_empty() else "",
		int(nest.get("level", 1))], "血 %d · 攻击 %d · %s 秒打一下 · 够得着 %s 米" % [s.hp, s.atk, _num(s.every), _num(s.range)]]
	var more: Array = []
	if int(s.armor) > 0:
		more.append("护甲 %d" % s.armor)
	if int(s.pierce) > 0:
		more.append("每下多 %d，不管护甲" % s.pierce)
	if float(s.splash) > 0.0:
		more.append("一打一片（%s 米）" % _num(s.splash))
	if int(s.heal) > 0:
		more.append("每下回血 %d" % s.heal)
	if int(s.burst) > 0:
		more.append("倒下时炸一圈（%d）" % s.burst)
	if s.dive:
		more.append("会飞，打后排")
	if not more.is_empty():
		lines.append(" · ".join(more))
	lines.append(Content.UNITS[u.kind].role)
	lines.append("吃 %d 生物质，只活这一仗" % int(Content.UNITS[u.kind].food) if not u.free else "只活这一仗（药剂或遗物孵的，不吃生物质）")
	return "\n".join(lines)


func _building_text(p: Vector2i) -> String:
	var b: Dictionary = home.buildings[p]
	var info: Dictionary = Content.BUILDINGS[b.kind]
	var lines: Array = ["%s · %d 级" % [info.name, b.level], Content.building_text(b.kind, int(b.level))]
	if Content.is_nest(b.kind):
		var s := home.spec_of(p)
		if s.evolved:
			var sp := Content.species(info.nest, b.affixes)
			lines.append("进化了：孵的是%s（%s）" % [Content.UNITS[s.kind].name, "+".join(sp.used.map(func(a: String) -> String:
				return Content.AFFIXES[a].name))])
		var made := int(_made(home).get(p, 0))
		var want := home.count(p) + int(home.buffs.get("breed", 0))
		lines.append("这一轮孵 %d 只%s" % [made, ("（生物质不够，少 %d）" % (want - made)) if made < want else ""])
		var given: Array = []
		var hp := roundi((float(s.hp_mult) / float(Content.level(b.kind, int(b.level)).quality) - 1.0) * 100.0)
		if hp != 0:
			given.append("血 %+d%%" % hp)
		var drill := int(s.atk_bonus)
		for af in b.affixes:
			if not af in Content.species(info.nest, b.affixes).used:
				drill -= int(Content.AFFIXES[af].get("atk", 0))
		if drill != 0:
			given.append("攻击 %+d" % drill)
		if int(s.haste) != 0:
			given.append("快 %d%%" % s.haste)
		if not given.is_empty():
			lines.append("旁边给它：" + "，".join(given))
		var names: Array = b.affixes.map(func(a: String) -> String: return Content.AFFIXES[a].name)
		lines.append("词条：%s（还能贴 %d 个）" % ["、".join(names) if not names.is_empty() else "没有", home.slots(p) - b.affixes.size()])
		if not s.evolved:
			for pair in Content.could_become(b.affixes):
				lines.append("再贴上%s，会进化成%s" % [Content.AFFIXES[pair[0]].name, Content.UNITS[pair[1]].name])
	if int(b.level) < Content.LEVEL_MAX:
		lines.append("升到 %d 级：%s" % [int(b.level) + 1, Content.level_text(b.kind, int(b.level) + 1)])
	return "\n".join(lines)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


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
	await hud.arrive(run.level)
	_start_round()


func _start_round() -> void:
	phase = Phase.BUSY
	held = -1
	held_k = -1
	_potion = -1
	refresh()
	var sub := "进账，商店换货，孵兵"
	if run.round == 1 and run.level > 0:
		sub = "新地方，敌人更强了。带来的东西在左下，点它放下"
	elif run.round >= run.rounds():
		sub = "首领来了"
	elif run.big():
		sub = "大波要来了"
	hud.banner("%s · 第 %d 轮" % [Content.LEVELS[run.level].name, run.round], sub)
	await get_tree().create_timer(0.6).timeout
	var ev := run.start_round()
	var said_at := Vector3(0, 2.5, HomeView.YARD_Z - 2.0)
	for e in ev:
		match e.t:
			"income":
				var said: Array = ["金币 +%d" % e.gold]
				if int(e.biomass) > 0:
					said.append("生物质 +%d" % e.biomass)
				if int(e.genes) > 0:
					said.append("基因 +%d" % e.genes)
				tags.float_text(said_at, "  ".join(said), Color(0.6, 1.0, 0.8), 22)
			"rotted":
				if int(e.amount) > 0:
					tags.float_text(said_at + Vector3(0, 1.5, 0), "潮湿：生物质烂了 %d" % e.amount, Color(0.75, 0.85, 0.5), 20)
			"ash":
				tags.float_text(Vector3(0, 4.0, 0), "火山灰：家园 −%d" % e.amount, Color(1.0, 0.55, 0.4), 24)
			"mended":
				tags.float_text(Vector3(0, 3.0, 0), "藤蔓：家园 +%d" % e.amount, Color(0.5, 1.0, 0.5), 24)
			"brewed":
				tags.float_text(home_view.top(e.at) + Vector3.UP, "配好：" + Content.POTIONS[e.potion].name,
					Content.POTIONS[e.potion].color, 20)
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
	_potion = -1
	refresh()
	hud.stow()
	fight = run.fight()
	fight_view.setup(fight)
	home_view.go_out()
	await get_tree().create_timer(0.4).timeout
	await _fly(FIGHT_AT, FIGHT_DIST, 1.0)
	at_home = false
	hud.refresh()
	hud.banner("开战", "我方 %d 只，敌方 %d 只" % [fight.alive("ours").size(), fight.alive("theirs").size()])
	await get_tree().create_timer(0.7).timeout
	_acc = 0.0
	_fighting = true


func _after_fight() -> void:
	var result := fight.result
	await get_tree().create_timer(0.7).timeout
	var out := run.finish(fight)
	match result:
		"won":
			var got: Array = ["金币 +%d" % out.gold, "外星基因 +%d" % out.alien]
			for k in out.loot:
				got.append(Content.POTIONS[k].name)
			if int(out.interest) > 0:
				got.append("利息 +%d" % out.interest)
			hud.banner("赢了！", "得到：" + "，".join(got))
		"time":
			hud.banner("拖到时间，算输", "家园 −%d%s" % [out.took, ("，利息 +%d" % out.interest) if int(out.interest) > 0 else ""])
		_:
			hud.banner("输了", "家园 −%d%s" % [out.took, ("，利息 +%d" % out.interest) if int(out.interest) > 0 else ""])
	await get_tree().create_timer(1.6).timeout
	await _fly(HOME_AT, HOME_DIST, 1.0)
	at_home = true
	phase = Phase.BUSY
	fight_view.clear()
	fight = null
	hud.refresh()
	if int(out.took) > 0:
		_shake = 1.0
		tags.float_text(Vector3(0, 4.0, 0), "家园 −%d" % out.took, Color(1.0, 0.42, 0.34), 34)
		await get_tree().create_timer(1.0).timeout
	if run.over:
		phase = Phase.DONE
		refresh()
		await hud.choose("家园被毁了……", "撑到了%s第 %d 轮" % [Content.LEVELS[run.level].name, run.round], [], ["重新开始"])
		_new_run()
		return
	if out.level_won and run.last_level():
		phase = Phase.DONE
		refresh()
		var names: Array = Content.LEVELS.map(func(l: Dictionary) -> String: return l.name)
		await hud.choose("全部守住了！", "%s都撑过来了，家园还剩 %d 血" % ["和".join(names), home.hp], [], ["再玩一遍"])
		_new_run()
		return
	await _gift()
	if out.level_won:
		await _level_end()
	_start_round()


## After each round: one of three offers, free -- into the stash (or, for one used at once, used).
func _gift() -> void:
	var gifts := run.gift_offer()
	if gifts.is_empty():
		return
	var full := home.stash.size() >= home.stash_size()
	var sub := "不要钱。放进左下的存货，什么时候放下都行" + ("（存货满了，最早的一样会被挤掉）" if full else "")
	var v: Variant = await hud.choose("挑一样，送你", sub, gifts, ["不要"])
	if v is Dictionary:
		var ev := run.take_gift(v)
		if not ev.is_empty():
			_changed(ev)
		else:
			refresh()


## A place held: a relic to choose, then the move -- what to carry picked on the homeland, the ark down to load it, on
## to the next place, the ark setting down what it brings -- and the new place's rule and ground.
func _level_end() -> void:
	var id := await hud.choose_relic(run.relic_offer())
	run.take_relic(id)
	refresh()
	await _pack()
	await hud.arrive(run.level)


func _new_run() -> void:
	Run.current = null
	get_tree().reload_current_scene()


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
