class_name Game
extends Node3D
## The game (GAME-DESIGN 14): the homeland built with cards, and the battles its army fights by itself. A round: the
## buildings bring in energy, biomass and genes, and the nests hatch this round's army; the player plays cards --
## builds, raises, gene affixes -- and potions, watching the army change; then sends it out; the battle fights itself,
## and the army is gone with it. Won: alien genes, a potion, a card; lost: the homeland is hurt; ten rounds hold a
## level, and a level held opens a row of land. How the battle will end is worked out and shown before it is fought,
## and again with the card or potion pointed at.
##
## Every player action goes through act(what, data). Coloured blocks stand in for what will be.

enum Phase { BUSY, PLAN, FIGHT, DONE }

const HOME_AT := Vector3(0, 0, 5.0)
const HOME_DIST := 44.0
const FIGHT_AT := Vector3(0, 0, -79.0)
const FIGHT_DIST := 25.0
const PITCH := 54.0
const OK_TINT := Color(0.42, 0.86, 0.4)
const SWAP_TINT := Color(0.95, 0.65, 0.3)
const HOT_TINT := Color(0.8, 1.0, 0.55)
const BAD_TINT := Color(0.95, 0.42, 0.34)
const LOOK_TINT := Color(0.86, 0.79, 0.64)

var run: Run
var home: Home
var camera: Camera3D
var home_view: HomeView
var fight_view: FightView
var tags: Tags
var hud: Hud
var phase := Phase.BUSY
var held := -1                    # the hand card taken up, or -1
var hover := {"plot": HomeView.NOWHERE, "unit": ""}
var fight: Fight                  # the battle being fought, or null
var speed := 1.0
var at_home := true               # the camera is over the homeland (not the battle field)
var forecast := {}                # this round's battle as things stand: {result, left, total, harm}
var preview := {}                 # the same with the held card (or the potion pointed at) used; {} when none
var effects := {}                 # plot -> [short lines]: what the held card would change there (for Tags)

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
	add_child(World.new())
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


## A run's first round begins with the deck laid out, to see what there is to play with.
func _begin() -> void:
	if run.level == 0 and run.round == 1 and not run.shown:
		run.shown = true
		await get_tree().process_frame
		await hud.choose("你的牌", "一开始有这 %d 张。每轮手牌补到 %d 张，没打的牌留在手里。抽牌堆、弃牌堆随时点开看" % [run.deck().size(),
			Home.HAND], Hud._sorted(run.deck()), ["开始"], false, false)
	_start_round()


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

## The one door for a player's action: "play" {slot, at}, "potion" {slot}, "fight". Whether it happened.
func act(what: String, data := {}) -> bool:
	if phase != Phase.PLAN:
		return false
	match what:
		"play":
			var ev := home.play(int(data.get("slot", -1)), data.get("at", true))
			if ev.is_empty():
				return false
			held = -1
			_changed(ev)
			hud.deal(home.hand)
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


## The hand card i taken up (again: put down -- or, for a card that needs no target, played).
func hold(i: int) -> void:
	if phase != Phase.PLAN or i < 0 or i >= home.hand.size():
		return
	if held == i and Content.card(home.hand[i]).target == "none" and not home.targets(i).is_empty():
		act("play", {"slot": i, "at": true})
		return
	held = -1 if held == i else i
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
					tags.float_text(HomeView.plot_pos(e.at) + Vector3.UP * 3.0, "退 %d 能量" % e.back, Color(1.0, 0.8, 0.4))
			"gained":
				var what := ("基因 +%d" % e.genes) if int(e.genes) > 0 else ("生物质 +%d" % e.biomass)
				tags.float_text(Vector3(0, 3.0, HomeView.YARD_Z - 2.0), what, Color(0.6, 1.0, 0.8), 24)
			"potion":
				tags.float_text(Vector3(0, 3.0, HomeView.YARD_Z - 2.0), Content.POTIONS[e.potion].name,
					Content.POTIONS[e.potion].color, 26)
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
				if held >= 0:
					held = -1
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
		if k >= KEY_1 and k < KEY_1 + Home.HAND:
			hold(k - KEY_1)
		elif k == KEY_ESCAPE and held >= 0:
			held = -1
			refresh()
		elif k == KEY_SPACE or k == KEY_ENTER:
			act("fight")


func _click() -> void:
	if phase != Phase.PLAN or held < 0 or held >= home.hand.size():
		return
	var at: Variant = _aim(Content.card(home.hand[held]))
	if at != null:
		act("play", {"slot": held, "at": at})


func _hover_at(pos: Vector2) -> void:
	var h := {"plot": HomeView.NOWHERE, "unit": ""}
	if at_home:
		h = home_view.pick(camera, pos, _want())
	if h.plot != hover.plot or h.unit != hover.unit:
		hover = h
		refresh()


## What the cursor should find, for the card held.
func _want() -> String:
	if phase != Phase.PLAN or held < 0 or held >= home.hand.size():
		return "any"
	match Content.card(home.hand[held]).target:
		"tile":
			return "tile"
		"building", "nest":
			return "building"
	return "any"


## What the held card would go on, under the cursor: a plot, true for a card that needs no target, or null.
func _aim(c: Dictionary) -> Variant:
	if c.target == "none":
		return true
	return hover.plot if hover.plot != HomeView.NOWHERE else null


# -- What is shown --------------------------------------------------------------------------------------------

## The forecast worked out again where the homeland changed; the plots the held card can go on lit (orange where it
## would pull a building down), the one it points at brighter, and the forecast and what changes with it played
## there; the HUD brought up to date.
func refresh() -> void:
	var tints := {}
	preview = {}
	effects = {}
	if phase == Phase.PLAN:
		if _forecast_at != _version:
			forecast = _work_out(home)
			_forecast_at = _version
		if held >= 0 and held < home.hand.size():
			var c := Content.card(home.hand[held])
			var fits := home.targets(held)
			for t in fits:
				if t is Vector2i:
					tints[t] = SWAP_TINT if c.type == "build" and home.buildings.has(t) else OK_TINT
			var at: Variant = _aim(c)
			if at != null and at in fits:
				if at is Vector2i:
					tints[at] = HOT_TINT
				_try("card%d|%s" % [held, str(at)], func(h: Home) -> void: h.play(held, at))
			elif at is Vector2i and home.is_open(at):
				tints[at] = BAD_TINT
		elif _potion >= 0 and _potion < home.potions.size():
			var k := _potion
			_try("potion%d" % k, func(h: Home) -> void: h.use_potion(k))
		elif hover.plot != HomeView.NOWHERE and home.is_open(hover.plot):
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


## What differs between two homelands, building by building, as short lines: more or fewer hatched, hardier, harder
## hitting, an affix, more affix places; and at the plot of a building that brings something in, what it brings.
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
				var q := float(Content.level(kind, int(b.buildings[p].level)).quality)
				var hp := roundi((float(sb.hp_mult) - float(sa.hp_mult)) / q * 100.0)
				if hp != 0:
					lines.append("血 %+d%%" % hp)
				if int(sb.atk_bonus) != int(sa.atk_bonus):
					lines.append("攻击 %+d" % (int(sb.atk_bonus) - int(sa.atk_bonus)))
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
		for pair in [["能量", b.income_energy() - a.income_energy(), "/轮"], ["生物质", b.income_biomass() - a.income_biomass(), "/轮"],
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


## What to do with the card held, said over the hand: "" when none is held.
func hint() -> String:
	if phase != Phase.PLAN or held < 0 or held >= home.hand.size():
		return ""
	var c := Content.card(home.hand[held])
	if home.energy < int(c.cost):
		return "能量不够（要 %d 点）" % c.cost
	if home.genes < int(c.get("genes", 0)):
		return "基因不够（要 %d）" % c.genes
	if home.alien < int(c.get("alien", 0)):
		return "外星基因不够（要 %d，打赢了才有）" % c.alien
	if home.targets(held).is_empty():
		return "现在没有地方用得上"
	var say := ""
	match c.target:
		"tile":
			var p: Vector2i = hover.plot
			if p != HomeView.NOWHERE and home.buildings.has(p) and home.buildings[p].kind != c.builds:
				var was: String = home.buildings[p].kind
				say = "拆掉%s换成这个（退 %d 能量）" % [Content.BUILDINGS[was].name, int(Content.BUILDINGS[was].cost) / 2]
			else:
				say = "点一块空地（点一座别的建筑，就拆了换成这个）"
		"building":
			say = "点一座建筑，升一级（最多 %d 级）" % Content.LEVEL_MAX
		"nest":
			say = "点一个还有空词条位的巢"
		_:
			say = "再点一下这张牌，或点一下地面，就打出"
	return say + " · 右键放下"


## What the cursor points at, for the panel: "" for nothing.
func describe() -> String:
	if not at_home or phase == Phase.DONE:
		return ""
	if hover.unit != "":
		for u in home.army():
			if u.id == hover.unit:
				return _unit_text(u)
		return ""
	var p: Vector2i = hover.plot
	if p == HomeView.NOWHERE:
		return ""
	if not home.is_open(p):
		return "荒地：还没开出来。每过一关，家园多开一排地"
	if not home.buildings.has(p):
		return "空地：造建筑的牌可以造在这里"
	return _building_text(p)


func _unit_text(u: Dictionary) -> String:
	var s := Content.unit_stats(u, home.buffs)
	var nest: Dictionary = home.buildings.get(u.nest, {})
	var lines: Array = ["%s（%s %d 级孵的）" % [s.name, Content.BUILDINGS[nest.kind].name if not nest.is_empty() else "",
		int(nest.get("level", 1))], "血 %d · 攻击 %d · %s 秒打一下 · 够得着 %s 米" % [s.hp, s.atk, _num(s.every), _num(s.range)]]
	var more: Array = []
	if int(s.armor) > 0:
		more.append("护甲 %d" % s.armor)
	if float(s.splash) > 0.0:
		more.append("一打一片（%s 米）" % _num(s.splash))
	if int(s.heal) > 0:
		more.append("每下回血 %d" % s.heal)
	if s.dive:
		more.append("会飞，打后排")
	if not more.is_empty():
		lines.append(" · ".join(more))
	lines.append(Content.UNITS[u.kind].role)
	lines.append("只活这一仗" + ("（药剂孵的，不吃生物质）" if u.free else ""))
	return "\n".join(lines)


func _building_text(p: Vector2i) -> String:
	var b: Dictionary = home.buildings[p]
	var info: Dictionary = Content.BUILDINGS[b.kind]
	var lines: Array = ["%s · %d 级" % [info.name, b.level], Content.building_text(b.kind, int(b.level))]
	if Content.is_nest(b.kind):
		var made := int(_made(home).get(p, 0))
		var want := home.count(p) + int(home.buffs.get("breed", 0))
		lines.append("这一轮孵 %d 只%s" % [made, ("（生物质不够，少 %d）" % (want - made)) if made < want else ""])
		var s := home.spec_of(p)
		var given: Array = []
		var hp := roundi((float(s.hp_mult) / float(Content.level(b.kind, int(b.level)).quality) - 1.0) * 100.0)
		if hp != 0:
			given.append("血 %+d%%" % hp)
		var drill := int(s.atk_bonus)
		for af in b.affixes:
			drill -= int(Content.AFFIXES[af].get("atk", 0))
		if drill != 0:
			given.append("攻击 %+d" % drill)
		if not given.is_empty():
			lines.append("旁边的建筑给它：" + "，".join(given))
		var names: Array = b.affixes.map(func(a: String) -> String: return Content.AFFIXES[a].name)
		lines.append("词条：%s（还能贴 %d 个）" % ["、".join(names) if not names.is_empty() else "没有", home.slots(p) - b.affixes.size()])
	if int(b.level) < Content.LEVEL_MAX:
		lines.append("升到 %d 级：%s" % [int(b.level) + 1, Content.building_text(b.kind, int(b.level) + 1)])
	return "\n".join(lines)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


# -- The round --------------------------------------------------------------------------------------------------

func _start_round() -> void:
	phase = Phase.BUSY
	held = -1
	_potion = -1
	refresh()
	var sub := "敌人更强了，家园多了一排地" if run.round == 1 and run.level > 0 else ("大波要来了" if run.big() else "收资源，孵兵")
	hud.banner("%s · 第 %d 轮" % [Content.LEVELS[run.level].name, run.round], sub)
	await get_tree().create_timer(0.6).timeout
	var ev := run.start_round()
	for e in ev:
		match e.t:
			"income":
				var said: Array = []
				if int(e.biomass) > 0:
					said.append("生物质 +%d" % e.biomass)
				if int(e.genes) > 0:
					said.append("基因 +%d" % e.genes)
				if not said.is_empty():
					tags.float_text(Vector3(0, 2.5, HomeView.YARD_Z - 2.0), "  ".join(said), Color(0.6, 1.0, 0.8), 22)
			"brewed":
				tags.float_text(home_view.top(e.at) + Vector3.UP, "配好：" + Content.POTIONS[e.potion].name,
					Content.POTIONS[e.potion].color, 20)
	_version += 1
	home_view.sync_army(home.army())
	await get_tree().create_timer(0.5).timeout
	phase = Phase.PLAN
	held = -1
	hud.deal(home.hand)
	refresh()


func _fight() -> void:
	phase = Phase.FIGHT
	held = -1
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
			var got: Array = ["外星基因 +%d" % out.alien]
			for k in out.loot:
				got.append(Content.POTIONS[k].name)
			hud.banner("赢了！", "得到：" + "，".join(got))
		"time":
			hud.banner("拖到时间，算输", "家园 −%d" % out.took)
		_:
			hud.banner("输了", "家园 −%d" % out.took)
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
	if out.level_won:
		if run.last_level():
			phase = Phase.DONE
			refresh()
			await hud.choose("全部守住了！", "三关都撑过来了", [], ["再玩一遍"])
			_new_run()
			return
		await _level_rewards()
	elif result == "won":
		await _card_reward("这一仗赢了")
	_start_round()


func _card_reward(title: String) -> void:
	var offer: Array = run.offer().map(func(id: String) -> Dictionary: return {"id": id, "up": false})
	var v: Variant = await hud.choose(title, "挑一张牌放进牌堆", offer, ["不要"])
	if v is Dictionary:
		run.take(v.id)


## A level held: a card to take, one to upgrade, one to take out; then on to the next level, a row more of land.
func _level_rewards() -> void:
	await _card_reward("%s守住了！" % Content.LEVELS[run.level].name)
	if run.deck().any(func(ci: Dictionary) -> bool: return not ci.up):
		var up: Variant = await hud.choose("升级一张牌", "点一张，它就变成 +（指着它，看它会变成什么样）", run.deck(), ["不升级"], true)
		if up is Dictionary and not up.up:
			run.upgrade(up)
	if run.deck().size() > Home.HAND:
		var out: Variant = await hud.choose("去掉一张牌？", "牌少了，好牌来得勤。也可以不去", run.deck(), ["不去掉"])
		if out is Dictionary:
			run.remove(out)
	run.next_level()
	home_view.open_rows()


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
