class_name Battle
extends Node3D
## One battle of a run (GAME-DESIGN 9), turn by turn. The rules are Sim's; this shows them.
##
## While the player plans, the whole coming turn is worked out on a copy and drawn on the board -- who walks
## where, who strikes whom for how much, what will fall, which eggs hatch -- and a card held over a tile shows
## the turn as it would be with that card played there. Ending the turn plays Sim's events out one by one,
## the same events the plan showed; then the next turn's cards are dealt.
##
## Every player action goes through act(player, what, data), so a second player can come in by the same door.

const PITCH := 44.0
const NEAR := 18.0
const FAR := 80.0
const DINO_MOVE := Color(0.98, 0.58, 0.1, 0.9)
const ROBOT_MOVE := Color(0.92, 0.16, 0.1, 0.88)
const BOLT := Color(1.0, 0.38, 0.04, 0.95)

var run: RunState
var state: BattleState
var camera: Camera3D
var planning := false
var views := {}                  # unit id -> UnitView
var nest_views := {}             # nest id -> NestView
var building_views := {}         # building id -> Building
var held := -1                   # the hand card being aimed, or -1
var hover := Board.NOWHERE

var _canyon: Canyon
var _arrows: Arrows
var _marks: Marks
var _hud: Hud
var _lures: Array = []           # Lure views
var _cam_at := Vector3(0, 0, 6.0)
var _cam_dist := 47.0
var _drag := false
var _shake := 0.0
var _scenes := {}
var _streams := {}
var _heard := {}
var _pictures := {}


func _ready() -> void:
	randomize()
	if RunState.current == null:
		RunState.current = RunState.new()
	run = RunState.current
	_canyon = Canyon.new()
	add_child(_canyon)
	_canyon.build(scene)
	camera = Camera3D.new()
	camera.fov = 44.0
	camera.near = 0.5
	camera.far = 700.0
	add_child(camera)
	_place_camera()
	state = Sim.new_battle(run.level, run.deck, run.rng)
	_arrows = Arrows.new()
	add_child(_arrows)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_marks = Marks.new()
	_marks.battle = self
	_marks.font = Fonts.serif(700)
	_marks.bold = Fonts.numbers()
	layer.add_child(_marks)
	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(self)
	_reconcile()
	_ambience()
	_hud.banner("第 %d 关 · %s" % [run.level + 1, Rules.LEVELS[run.level].name], "打掉远处的时光机")
	_begin_planning()


## The valley's own sound under everything, round and round.
func _ambience() -> void:
	var stream := _stream("ambience_valley")
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -16.0
	add_child(p)
	p.finished.connect(p.play)
	p.play()


func _process(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if v != Vector2.ZERO:
		_pan(v.normalized() * 30.0 * delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		_place_camera()


# -- What the player does ----------------------------------------------------------------------------------

## The one door for a player's action. Returns whether it happened.
func act(_player: int, what: String, data: Dictionary) -> bool:
	if not planning:
		return false
	match what:
		"play":
			var i: int = data.slot
			var at: Vector2i = data.at
			var ci: Dictionary = state.hand[i] if i >= 0 and i < state.hand.size() else {}
			if ci.is_empty() or not Sim.play(state, i, at):
				return false
			held = -1
			_played(ci, at)
			return true
		"end":
			_end_turn()
			return true
	return false


## The hand card i taken up to aim (again to put it down).
func hold(i: int) -> void:
	if not planning:
		return
	held = -1 if held == i or i >= state.hand.size() else i
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag:
			_pan(-event.relative * _cam_dist * 0.0016)
		var p := _tile_under(event.position)
		if p != hover:
			hover = p
			refresh()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if planning and held >= 0 and hover != Board.NOWHERE:
					act(0, "play", {"slot": held, "at": hover})
			MOUSE_BUTTON_RIGHT:
				held = -1
				refresh()
			MOUSE_BUTTON_WHEEL_UP:
				_cam_dist = maxf(NEAR, _cam_dist * 0.9)
				_place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_cam_dist = minf(FAR, _cam_dist * 1.1)
				_place_camera()
			MOUSE_BUTTON_MIDDLE:
				_drag = true
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		_drag = false
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k < KEY_1 + Rules.HAND:
			hold(k - KEY_1)
		elif k == KEY_ESCAPE:
			held = -1
			refresh()
		elif k == KEY_SPACE or k == KEY_ENTER:
			act(0, "end", {})


func _tile_under(screen: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Board.NOWHERE
	var t := -from.y / dir.y
	return Board.tile(from + dir * t) if t > 0.0 else Board.NOWHERE


# -- The plan, shown ---------------------------------------------------------------------------------------

func _begin_planning() -> void:
	planning = true
	held = -1
	_hud.deal(state.hand)
	refresh()


## Works the coming turn out again and draws it: with the held card played on the tile under the cursor, when
## it can go there.
func refresh() -> void:
	if not planning:
		return
	var s := state
	if held >= 0 and hover != Board.NOWHERE and held < state.hand.size():
		var c := Rules.card(state.hand[held])
		if state.energy >= int(c.cost) and Sim.fits(state, c, hover):
			s = state.clone()
			Sim.play(s, held, hover)
	_read_plan(s, Sim.preview(s))
	_paint_tiles()
	for nv in nest_views.values():
		var n: Variant = state.nest(nv.id)
		nv.due = n != null and int(n.eggs) > 0 and Sim.turns_left(state, n) == 0 and not Sim.paused(state, n)
	_hud.refresh()


func _read_plan(s: BattleState, ev: Array) -> void:
	var at := {}
	for u in s.units:
		at[u.id] = u.pos
	var dmg := {}
	var deal := {}
	var dies := {}
	var nest_dmg := {}
	var nest_lost := {}
	var paths: Array = []
	var lines: Array = []
	for e in ev:
		match e.t:
			"hatch", "spawn":
				at[e.unit.id] = e.unit.pos
			"move", "charge":
				var side: String = _side_of(s, e.id)
				var pts: Array = [Board.world(at.get(e.id, Vector2i.ZERO))]
				for p in e.path:
					pts.append(Board.world(p))
				if pts.size() > 1:
					var bolt: bool = e.t == "charge"
					paths.append({"points": pts, "colour": BOLT if bolt else (DINO_MOVE if side == "dino" else ROBOT_MOVE),
						"width": 1.0 if bolt else 0.55, "head": true})
				if not e.path.is_empty():
					at[e.id] = e.path[-1]
				if e.t == "charge":
					for h in e.hits:
						dmg[h.target] = dmg.get(h.target, 0) + int(h.dmg)
						deal[e.id] = deal.get(e.id, 0) + int(h.dmg)
			"bite", "shoot":
				deal[e.id] = deal.get(e.id, 0) + int(e.dmg)
				var robot: bool = e.t == "shoot"
				var from := Board.world(at.get(e.id, Vector2i.ZERO))
				if e.has("target"):
					dmg[e.target] = dmg.get(e.target, 0) + int(e.dmg)
					lines.append({"from": from, "to": Board.world(at.get(e.target, Vector2i.ZERO)),
						"colour": ROBOT_MOVE if robot else DINO_MOVE, "width": 0.22})
				elif e.has("nest"):
					nest_dmg[e.nest] = nest_dmg.get(e.nest, 0) + int(e.dmg)
					var n: Variant = s.nest(int(e.nest))
					if n != null:
						lines.append({"from": from, "to": Board.world(n.pos), "colour": ROBOT_MOVE, "width": 0.22})
			"die":
				dies[e.id] = true
			"nest_lost":
				nest_lost[e.id] = true
	_marks.shown = {"dmg": dmg, "deal": deal, "dies": dies, "nest_dmg": nest_dmg, "nest_lost": nest_lost}
	_arrows.show_plan(paths, lines)


func _side_of(s: BattleState, id: int) -> String:
	var u: Variant = s.unit(id)
	return u.side if u != null else "dino"


## The tiles lit on the canyon floor: where the held card can go (and what it would reach from the tile under
## the cursor), the ash still hanging.
func _paint_tiles() -> void:
	_canyon.clear_marks()
	for a in state.ashes:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var q: Vector2i = a.pos + Vector2i(dx, dy)
				if Sim.inside(q):
					_canyon.mark(q, Color(0.55, 0.55, 0.55, 0.35))
	if held >= 0 and held < state.hand.size():
		var c := Rules.card(state.hand[held])
		var where := Sim.targets(state, held)
		for p in where:
			_canyon.mark(p, Color(0.42, 0.95, 0.5, 0.32))
		if hover != Board.NOWHERE:
			var reach: int = {"noise": int(c.get("reach", 0)), "blood": int(c.get("reach", 0)), "ash": 1}.get(c.id, -1)
			if reach > 0 and hover in where:
				for y in Rules.ROWS:
					for x in Rules.COLS:
						if Sim.dist(Vector2i(x, y), hover) <= reach:
							_canyon.mark(Vector2i(x, y), Color(1.0, 0.85, 0.4, 0.38))
			_canyon.mark(hover, Color(0.6, 1.0, 0.6, 0.85) if hover in where else Color(1.0, 0.32, 0.28, 0.5))
	elif hover != Board.NOWHERE:
		_canyon.mark(hover, Color(1.0, 1.0, 1.0, 0.28))
	_canyon.show_marks()


## What the player is pointing at, for the hint panel: "" for nothing there.
func describe(p: Vector2i) -> String:
	if p == Board.NOWHERE:
		return ""
	var u: Variant = Sim.unit_at(state, p)
	if u != null:
		if u.side == "dino":
			var st: Dictionary = Rules.DINOS[u.kind]
			var head := "%s%s" % [st.name, (" ×%d" % u.bodies) if u.pack else ("（头领）" if u.lead else "")]
			var bite: int = int(st.bite) * int(u.bodies) * (2 if int(u.frenzy) > 0 else 1)
			var lines := [head, "生命 %d / %d · 一口 %d · 走 %d 格 · 看 %d 格" % [u.hp, u.max, bite, st.move, st.sight], st.rule]
			if int(u.frenzy) > 0:
				lines.append("发狂中：还剩 %d 回合" % u.frenzy)
			if st.get("apex", false):
				lines.append("吃饱了（腐肉坑在 2 格内）" if Sim.fed(state, u) else "饿着")
			return "\n".join(lines)
		var rt: Dictionary = Rules.ROBOTS[u.kind]
		var info := "生命 %d / %d" % [u.hp, u.max]
		if int(rt.shot) > 0:
			info += " · 打 %d · 射程 %d 格%s" % [rt.shot, Sim._reach(state, u), (" · 走 %d 格" % rt.move) if int(rt.move) > 0 else ""]
		return "\n".join([rt.name, info, rt.rule])
	var n: Variant = Sim.nest_at(state, p)
	if n != null:
		var lines := ["蛋窝 · 生命 %d / %d" % [n.hp, Rules.NEST_HP]]
		if int(n.eggs) > 0:
			var named: String = Rules.DINOS[n.species].name
			var what := ("%s蛋：一窝 %d 只" % [named, n.pack]) if int(n.pack) > 1 else ("%s蛋：还有 %d 个" % [named, n.eggs])
			var left := Sim.turns_left(state, n)
			lines.append(what + ("，这回合结束就孵出" if left == 0 else "，还要 %d 回合孵出" % (left + 1)))
			for need in n.needs:
				if need == "quiet":
					lines.append("3 格内有机器人，不孵" if Sim.paused(state, n) else "够安静")
				else:
					lines.append(("挨着%s" if Sim.beside(state, n.pos, need) else "缺%s：慢一倍") % Rules.NEEDS[need])
		else:
			lines.append("空窝：能再下一窝蛋")
		return "\n".join(lines)
	var b: Variant = Sim.building_at(state, p)
	if b != null:
		var c := Rules.card({"id": b.kind, "up": b.up})
		return "%s · 生命 %d\n%s" % [c.name, b.hp, Rules.text(c)]
	if state.rocks.has(p):
		return "石头：谁都过不去"
	return ""


# -- The turn, played out -----------------------------------------------------------------------------------

func _end_turn() -> void:
	planning = false
	held = -1
	_canyon.clear_marks()
	_canyon.show_marks()
	_arrows.show_plan([], [])
	_marks.shown = {}
	_hud.discard()
	var ev := Sim.end_turn(state)
	await _play(ev)
	_reconcile()
	if state.over:
		await get_tree().create_timer(0.8).timeout
		_hud.finish(state.won)
		return
	Sim.start_turn(state, run.rng)
	var came := ev.filter(func(e: Dictionary) -> bool: return e.t == "spawn").size()
	if came > 0:
		_hud.banner("机器人来了 %d 个" % came, "")
	_begin_planning()


func _play(ev: Array) -> void:
	for e in ev:
		match e.t:
			"hatch":
				var nv: Variant = nest_views.get(e.nest)
				if nv:
					nv.crack(int(e.unit.bodies) if e.unit.pack else 1)
				sound("wood_hit_1", Board.world(e.unit.pos), -2.0)
				var v := _add_view(e.unit)
				await (v as DinoView).hatch_in()
			"spawn":
				var v := _add_view(e.unit)
				await (v as RobotView).arrive()
			"move":
				var v: Variant = views.get(e.id)
				if v:
					await v.walk(e.path)
			"charge":
				await _charge(e)
			"bite":
				var v: Variant = views.get(e.id)
				var t: Variant = views.get(e.target)
				if v and t:
					await v.strike(t.aim_point())
					_hit(t, int(e.dmg))
					dino_sound(v.kind, "bite", t.global_position)
					await _wait(0.25)
			"shoot":
				await _shoot(e)
			"die":
				var v: Variant = views.get(e.id)
				if v:
					views.erase(e.id)
					await v.die()
			"nest_lost":
				var nv: Variant = nest_views.get(e.id)
				if nv:
					nest_views.erase(e.id)
					nv.lost()
					sound("wood_break", nv.global_position, 2.0)
					await _wait(0.4)
			"building_lost":
				var bv: Variant = building_views.get(e.id)
				if bv:
					building_views.erase(e.id)
					bv.lost()
			"heal":
				var v: Variant = views.get(e.id)
				if v:
					v.heal(int(e.amount))
					_marks.float_text(v.aim_point(), "+%d" % e.amount, Color(0.5, 1.0, 0.5))
			"won":
				_shake = 1.0
	await _wait(0.3)


func _shoot(e: Dictionary) -> void:
	var v: Variant = views.get(e.id)
	if v == null:
		return
	var at := Vector3.ZERO
	var t: Variant = null
	if e.has("target"):
		t = views.get(e.target)
		if t == null:
			return
		at = t.aim_point()
	elif e.has("nest"):
		t = nest_views.get(e.nest)
		if t == null:
			return
		at = t.global_position + Vector3.UP * 0.4
	else:
		t = building_views.get(e.building)
		if t == null:
			return
		at = t.global_position + Vector3.UP * 1.0
	await v.fire(at)
	if e.has("target"):
		_hit(t, int(e.dmg))
	else:
		if e.has("nest"):
			t.hp = maxi(0, t.hp - int(e.dmg))
		sparks(at)
		_marks.float_text(at, "-%d" % e.dmg, Color(1.0, 0.35, 0.3))
	await _wait(0.2)


## A plant-eater bolting: tile by tile, trampling what is in its way as it comes to it.
func _charge(e: Dictionary) -> void:
	var v: Variant = views.get(e.id)
	if v == null:
		return
	dino_sound(v.kind, "alert", v.global_position)
	for k in e.path.size() + 1:
		for h in e.hits:
			if int(h.step) == k:
				var t: Variant = views.get(h.target)
				if t:
					_hit(t, int(h.dmg))
					sound("stone_impact", t.global_position, 2.0)
		if k < e.path.size():
			await v.walk([e.path[k]])
	await _wait(0.15)


func _hit(t: Node, dmg: int) -> void:
	t.take(dmg)
	_marks.float_text(t.aim_point(), "-%d" % dmg, Color(1.0, 0.35, 0.3))


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _played(ci: Dictionary, at: Vector2i) -> void:
	var c := Rules.card(ci)
	var w := Board.world(at)
	match c.type:
		"egg":
			sound("pickup", w, -2.0)
		"building":
			sound("build_done", w, -2.0)
		_:
			match c.id:
				"noise":
					Lure.bang(self, w, 6.0)
					sound("impact_boom", w, 2.0)
				"blood":
					burst(w + Vector3.UP * 0.8, 0.6, Color(0.6, 0.05, 0.04))
					sound("tyrannosaurus_bite", w, -4.0)
				"call":
					sound("triceratops_call_1", w, 2.0)
				"ash":
					sound("landing", w, -2.0)
				"quicken":
					sound("craft_done", w, -2.0)
				"scent":
					sound("pickup", w, -2.0)
	_reconcile()
	_hud.deal(state.hand)
	refresh()


# -- Keeping the pictures true to the state ------------------------------------------------------------------

func _reconcile() -> void:
	var seen := {}
	for u in state.units:
		seen[u.id] = true
		var v: Variant = views.get(u.id)
		if v == null or not is_instance_valid(v):
			v = _add_view(u)
		else:
			v.sync(u)
		if v is DinoView:
			v.rage(int(u.frenzy) > 0)
	for id in views.keys():
		if not seen.has(id):
			var v: Variant = views[id]
			views.erase(id)
			if is_instance_valid(v):
				v.queue_free()
	var nests_seen := {}
	for n in state.nests:
		nests_seen[n.id] = true
		var nv: Variant = nest_views.get(n.id)
		if nv == null:
			nv = NestView.new()
			add_child(nv)
			nv.setup(n)
			nest_views[n.id] = nv
		elif nv.species != n.species or nv.egg_count() != _eggs_shown(n):
			nv.refill(n)
		nv.hp = n.hp
	for id in nest_views.keys():
		if not nests_seen.has(id):
			nest_views[id].lost()
			nest_views.erase(id)
	var bs := {}
	for b in state.buildings:
		bs[b.id] = true
		if not building_views.has(b.id):
			var bv := Building.new()
			add_child(bv)
			bv.setup(scene, b)
			building_views[b.id] = bv
	for id in building_views.keys():
		if not bs.has(id):
			building_views[id].lost()
			building_views.erase(id)
	var want: Array = []
	for e in state.scents:
		want.append(["scent", e.pos])
	for e in state.ashes:
		want.append(["ash", e.pos])
	for e in state.noises:
		want.append(["noise", e.pos])
	for e in state.calls:
		want.append(["call", e.pos])
	for l in _lures.duplicate():
		var key := [l.kind, l.tile]
		if key in want:
			want.erase(key)
		else:
			_lures.erase(l)
			l.spend()
	for key in want:
		var l := Lure.new()
		add_child(l)
		l.setup(scene, key[0], key[1])
		_lures.append(l)


func _eggs_shown(n: Dictionary) -> int:
	return mini(8, int(n.eggs) * maxi(1, int(n.pack)))


func _add_view(u: Dictionary) -> UnitView:
	var v: UnitView
	if u.side == "dino":
		v = DinoView.new()
		add_child(v)
		(v as DinoView).setup(self, u)
	else:
		v = RobotView.new()
		add_child(v)
		(v as RobotView).setup(self, u)
	views[u.id] = v
	return v


# -- The camera ------------------------------------------------------------------------------------------------

func _place_camera() -> void:
	var a := deg_to_rad(PITCH)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.6
	camera.position = _cam_at + Vector3(0.0, sin(a), cos(a)) * _cam_dist + shake
	camera.rotation = Vector3(-a, 0.0, 0.0)


func _pan(d: Vector2) -> void:
	_cam_at.x = clampf(_cam_at.x + d.x, -12.0, 12.0)
	_cam_at.z = clampf(_cam_at.z + d.y, -20.0, 18.0)
	_place_camera()


# -- Pictures, scenes and sounds ----------------------------------------------------------------------------------

## The picture on a card: an egg's dinosaur, a building as it stands; none for help (Emblem draws those).
func card_picture(id: String) -> Texture2D:
	if not _pictures.has(id):
		var c: Dictionary = Rules.CARDS[id]
		match c.type:
			"egg":
				_pictures[id] = Portraits.take(self, scene(Species.scene_path(c.species)), 192)
			"building":
				_pictures[id] = Portraits.take_node(self, Building.look(id, scene, 7), 192)
			_:
				_pictures[id] = null
	return _pictures[id]


## A robot's likeness, for the waves still to come.
func robot_picture(kind: String) -> Texture2D:
	var key := "robot_" + kind
	if not _pictures.has(key):
		var v := RobotView.new()
		v.setup(self, {"id": 0, "kind": kind, "side": "robot", "hp": 1, "max": 1, "bodies": 1, "pos": Vector2i.ZERO})
		v.position = Vector3.ZERO
		v.rotation.y = PI + 0.5
		_pictures[key] = Portraits.take_node(self, v, 128, 14.0)
	return _pictures[key]


func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


func sound(name: String, at: Vector3, db := 0.0) -> void:
	var stream := _stream(name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 40.0
	p.max_distance = 400.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


## A dinosaur's own sound for `what` (alert, bite, hurt, death), not more than a few a second of a kind.
func dino_sound(kind: String, what: String, at: Vector3) -> void:
	var key := kind + what
	var now := Time.get_ticks_msec()
	if now < int(_heard.get(key, 0)):
		return
	_heard[key] = now + 350
	var tries := {"alert": ["alert", "roar", "call_1", "snort"], "bite": ["bite", "bite_1", "ram"],
		"hurt": ["hurt", "hurt_1"], "death": ["death"]}
	for t in tries.get(what, [what]):
		if _stream(kind + "_" + t):
			sound(kind + "_" + t, at, -1.0)
			return


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := "res://common/assets/audio/%s.wav" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]


# -- Effects -----------------------------------------------------------------------------------------------------

## A shot's streak of light, there for a blink, and a flash at the muzzle.
func beam(from: Vector3, to: Vector3, colour: Color) -> void:
	var dir := to - from
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = dir.length()
	cyl.radial_segments = 6
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(x, y, x.cross(y)), from + dir * 0.5)
	flash_at(from, colour)
	get_tree().create_timer(0.09).timeout.connect(mi.queue_free)


func flash_at(at: Vector3, colour: Color) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 3.0
	light.omni_range = 6.0
	add_child(light)
	light.global_position = at
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.25)
	tw.tween_callback(light.queue_free)


func sparks(at: Vector3) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 75.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 9.0
	mat.gravity = Vector3(0, -14, 0)
	mat.scale_min = 0.12
	mat.scale_max = 0.22
	mat.color_ramp = Fx.ramp(Color(1.0, 0.75, 0.3), 1.0)
	var p := Fx.particles(mat, 22, 0.6)
	p.one_shot = true
	p.explosiveness = 1.0
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## A burst of fire and smoke: a robot breaking up (size 1), the time machine (bigger).
func burst(at: Vector3, size := 1.0, colour := Color(1.0, 0.55, 0.2)) -> void:
	var fire := ParticleProcessMaterial.new()
	fire.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.6 * size
	fire.direction = Vector3.UP
	fire.spread = 180.0
	fire.initial_velocity_min = 2.0 * size
	fire.initial_velocity_max = 6.0 * size
	fire.damping_min = 3.0
	fire.damping_max = 5.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.scale_min = 1.2 * size
	fire.scale_max = 2.6 * size
	fire.color_ramp = Fx.ramp(colour, 0.95)
	var p := Fx.particles(fire, int(40 * size), 0.9)
	p.one_shot = true
	p.explosiveness = 0.95
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	var smoke := ParticleProcessMaterial.new()
	smoke.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8 * size
	smoke.direction = Vector3.UP
	smoke.spread = 40.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.5
	smoke.gravity = Vector3(0.3, 0.6, 0)
	smoke.scale_min = 1.6 * size
	smoke.scale_max = 3.2 * size
	smoke.color_ramp = Fx.ramp(Color(0.16, 0.15, 0.14), 0.7)
	var s := Fx.particles(smoke, int(26 * size), 2.6)
	s.one_shot = true
	s.explosiveness = 0.7
	add_child(s)
	s.global_position = at
	s.emitting = true
	s.finished.connect(s.queue_free)
	flash_at(at, colour)
	sparks(at)
	_shake = maxf(_shake, 0.25 * size)
