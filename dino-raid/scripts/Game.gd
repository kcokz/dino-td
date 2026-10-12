class_name Game
extends Node3D
## The framework (GAME-DESIGN 12): the homeland built with cards, and the battles its units fight by themselves.
## A round: the nests make what is due; the player plays cards -- builds, buffs, upgrades -- and sends everyone
## out; the battle fights itself; who comes back stays. Lost, the homeland is hurt; won, a card to take; ten
## rounds hold a level. How the battle will end is worked out and shown before it is fought, and again with the
## card held played where it points.
##
## Every player action goes through act(what, data). Coloured blocks stand in for what will be.

enum Phase { BUSY, PLAN, FIGHT, DONE }

const HOME_AT := Vector3(0, 0, 5.5)
const HOME_DIST := 40.0
const FIGHT_AT := Vector3(0, 0, -79.0)
const FIGHT_DIST := 25.0
const PITCH := 54.0
const OK_TINT := Color(0.42, 0.86, 0.4)
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
var hover := {"plot": HomeView.NOWHERE, "unit": -1}
var fight: Fight                  # the battle being fought, or null
var speed := 1.0
var at_home := true               # the camera is over the homeland (not the battle field)
var forecast := {}                # this round's battle as things stand: {result, left, total, harm}
var preview := {}                 # the same with the held card played where it points; {} when there is none

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

## The one door for a player's action: "play" {slot, at}, "fight". Whether it happened.
func act(what: String, data := {}) -> bool:
	if phase != Phase.PLAN:
		return false
	match what:
		"play":
			var ev := home.play(int(data.get("slot", -1)), data.get("at", true))
			if ev.is_empty():
				return false
			held = -1
			_version += 1
			hud.deal(home.hand)
			home_view.play_events(ev)
			refresh()
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
	var h := {"plot": HomeView.NOWHERE, "unit": -1}
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
		"building", "producer":
			return "building"
		"unit":
			return "unit"
	return "any"


## What the held card would go on, under the cursor: a plot, a unit id, true for a card that needs no target, or
## null.
func _aim(c: Dictionary) -> Variant:
	match c.target:
		"none":
			return true
		"unit":
			return hover.unit if hover.unit >= 0 else null
	return hover.plot if hover.plot != HomeView.NOWHERE else null


# -- What is shown --------------------------------------------------------------------------------------------

## The forecast worked out again where the homeland changed, the plots and units the held card can go on lit,
## the one it points at brighter (and the forecast with it played there), the HUD brought up to date.
func refresh() -> void:
	var tints := {}
	var unit_tints := {}
	preview = {}
	if phase == Phase.PLAN:
		if _forecast_at != _version:
			forecast = _work_out(home)
			_forecast_at = _version
		if held >= 0 and held < home.hand.size():
			var c := Content.card(home.hand[held])
			var fits := home.targets(held)
			for t in fits:
				if t is Vector2i:
					tints[t] = OK_TINT
				elif t is int:
					unit_tints[t] = OK_TINT
			var at: Variant = _aim(c)
			if at != null and at in fits:
				if at is Vector2i:
					tints[at] = HOT_TINT
				elif at is int:
					unit_tints[at] = HOT_TINT
				var key := "%d|%s|%d" % [held, str(at), _version]
				if key != _preview_key:
					var h := home.clone()
					h.play(held, at)
					_preview = _work_out(h)
					_preview_key = key
				preview = _preview
			elif at is Vector2i:
				tints[at] = BAD_TINT
		elif hover.plot != HomeView.NOWHERE:
			tints[hover.plot] = LOOK_TINT
	home_view.tints = tints
	home_view.unit_tints = unit_tints
	home_view.paint()
	hud.refresh()


## How this round's battle ends if fought by `h` -- the same rules, so the same end.
func _work_out(h: Home) -> Dictionary:
	var f := Fight.make(h, run.wave(), run.power())
	var total := f.alive("ours").size()
	f.run()
	return {"result": f.result, "left": f.alive("ours").size(), "total": total,
		"harm": 0 if f.result == "won" else maxi(0, f.harm() - h.block())}


## What to do with the card held, said over the hand: "" when none is held.
func hint() -> String:
	if phase != Phase.PLAN or held < 0 or held >= home.hand.size():
		return ""
	var c := Content.card(home.hand[held])
	if home.energy < int(c.cost):
		return "力气不够（要 %d 点）" % c.cost
	if home.targets(held).is_empty():
		return "现在没有地方用得上"
	var say: String = {"tile": "点一块空地", "building": "点一座建筑（3 级的不能再升）", "producer": "点一个巢",
		"unit": "点院子里的一个兵", "none": "再点一下这张牌，或点一下地面，就打出"}[c.target]
	return say + " · 右键放下"


## What the cursor points at, for the panel: "" for nothing.
func describe() -> String:
	if not at_home or phase == Phase.DONE:
		return ""
	if hover.unit >= 0:
		var u: Variant = home.unit(hover.unit)
		return _unit_text(u) if u != null else ""
	var p: Vector2i = hover.plot
	if p == HomeView.NOWHERE:
		return ""
	if not home.buildings.has(p):
		return "空地：造建筑的牌可以造在这里"
	return _building_text(p)


func _unit_text(u: Dictionary) -> String:
	var s := Content.stats("ours", u.kind, int(u.star), int(u.bonus_hp), int(u.bonus_atk))
	var lines: Array = ["%s · %d 星" % [s.name, u.star], "血 %d · 攻击 %d · %s 秒打一下" % [s.hp, s.atk, _num(s.every)]]
	var more: Array = ["够得着 %s 米" % _num(s.range)]
	if int(s.armor) > 0:
		more.append("护甲 %d" % s.armor)
	if float(s.splash) > 0.0:
		more.append("一打一片（%s 米）" % _num(s.splash))
	if int(s.heal) > 0:
		more.append("每下回血 %d" % s.heal)
	lines.append(" · ".join(more))
	lines.append(Content.UNITS[u.kind].role)
	if int(u.bonus_hp) > 0 or int(u.bonus_atk) > 0:
		lines.append("练过：血 +%d，攻击 +%d" % [u.bonus_hp, u.bonus_atk])
	if int(u.star) < 3:
		var same := home.units.filter(func(o: Dictionary) -> bool: return o.kind == u.kind and o.star == u.star).size()
		lines.append("再来 %d 个一样的，三个合成一个 %d 星" % [Content.MERGE - same, int(u.star) + 1])
	return "\n".join(lines)


func _building_text(p: Vector2i) -> String:
	var b: Dictionary = home.buildings[p]
	var info: Dictionary = Content.BUILDINGS[b.kind]
	var lines: Array = ["%s · %d 级" % [info.name, b.level], Content.building_text(b.kind, int(b.level))]
	var l := home.level_of(p)
	if l.has("makes"):
		if home.units.size() >= home.room():
			lines.append("院子满了：造围栏才能多养")
		else:
			lines.append("下一轮开始时生产" if int(b.wait) <= 1 else "还要 %d 轮才生产" % b.wait)
		var sooner := int(l.every) - home.every(p)
		if sooner > 0:
			lines.append("旁边有暖巢：早 %d 轮" % sooner)
		var drill := 0
		for q in home.around(p):
			if home.buildings.has(q):
				drill += int(home.level_of(q).get("drill", 0))
		if drill > 0:
			lines.append("旁边有训练场：生产的兵攻击 +%d" % drill)
	if int(b.level) < 3:
		lines.append("升到 %d 级：%s" % [int(b.level) + 1, Content.building_text(b.kind, int(b.level) + 1)])
	return "\n".join(lines)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


# -- The round --------------------------------------------------------------------------------------------------

func _start_round() -> void:
	phase = Phase.BUSY
	held = -1
	refresh()
	var sub := "敌人更强了" if run.round == 1 and run.level > 0 else "巢里在生产"
	hud.banner("%s · 第 %d 轮" % [Content.LEVELS[run.level].name, run.round], sub)
	await get_tree().create_timer(0.6).timeout
	var ev := run.start_round()
	hud.refresh()
	await home_view.play_events(ev)
	phase = Phase.PLAN
	held = -1
	_version += 1
	hud.deal(home.hand)
	refresh()


func _fight() -> void:
	phase = Phase.FIGHT
	held = -1
	refresh()
	hud.send_off()
	fight = run.fight()
	fight_view.setup(fight)
	home_view.go_out()
	await get_tree().create_timer(0.4).timeout
	await _fly(FIGHT_AT, FIGHT_DIST, 1.0)
	at_home = false
	hud.refresh()
	hud.banner("开战", "我方 %d 个，敌方 %d 个" % [fight.alive("ours").size(), fight.alive("theirs").size()])
	await get_tree().create_timer(0.7).timeout
	_acc = 0.0
	_fighting = true


func _after_fight() -> void:
	var result := fight.result
	await get_tree().create_timer(0.7).timeout
	var out := run.finish(fight)
	match result:
		"won":
			hud.banner("赢了！", ("倒下的 %d 个养好伤回来了" % out.fallen) if int(out.fallen) > 0 else "一个兵也没倒下")
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
	home_view.come_back()
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


## A level held: a card to take, one to upgrade, one to take out; then on to the next level.
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
