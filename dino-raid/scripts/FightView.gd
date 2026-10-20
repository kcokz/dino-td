class_name FightView
extends Node3D
## A battle on screen (GAME-DESIGN 14, 17, 23): every fighter where Fight has it (Creatures: ours as their dinosaurs,
## theirs as blocks), facing the other side or the way it runs, running while it moves and standing when it stops; a
## flier flies. The striker bites (a lunge) or shoots (its shot flies, Effects); when the blow lands what it hits
## flashes, flinches and throws sparks, and its number rises. A heal flies green and rises round the healed. The
## fallen fall when the blow that felled them lands, in a puff of dust (ours) or spores (theirs); one that bursts throws
## out a fireball, a ring of dust and shakes the camera; one that breaks lets out the smaller ones it held.

const HEAL := Color(0.45, 1.0, 0.5)
const OUR_SPARKS := Color(1.0, 0.8, 0.42)      # where ours bite
const THEIR_SPARKS := Color(1.0, 0.4, 0.3)     # where theirs bite ours
## The shot each kind throws (Effects.SHOTS); any other: "ours" or "theirs".
const SHOT_OF := {"blue": "spit", "scav": "stone", "miasma": "poison", "salamander": "fire"}

var fight: Fight
var tags: Tags
var pace := 1.0                   # how fast the battle runs (Game.speed): the creatures' clips keep up
var _nodes := {}                  # fighter id -> Node3D
var _due := {}                    # fighter id -> when (msec) the last blow at it lands: it falls no sooner


func setup(f: Fight) -> void:
	clear()
	fight = f
	for u in f.units:
		_add(u)


func _add(u: Dictionary) -> Node3D:
	var c: Color = (Content.UNITS if u.side == "ours" else Content.ENEMIES)[u.kind].color
	var n := Creatures.make(float(u.size), c, u.side == "theirs", u.affixes, u.kind, int(u.get("elite", 0)))
	n.rotation.y = _facing(u)
	n.position = place(u)
	add_child(n)
	_nodes[u.id] = n
	return n


func clear() -> void:
	for n in _nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_due.clear()
	fight = null


## Where a fighter stands in the world (a flier, in the air).
static func place(u: Dictionary) -> Vector3:
	var p: Vector2 = u.pos
	return World.ARENA + Vector3(p.x, World.GROUND_TOP + (1.4 if u.dive else 0.0), p.y)


func node(id: int) -> Node3D:
	return _nodes.get(id)


## The scavengers standing at the end, each with the gold it brings back over it.
func show_loot() -> void:
	if fight == null:
		return
	for u in fight.alive("ours"):
		var n: Node3D = _nodes.get(u.id)
		if u.get("scavenge", false) and n:
			tags.float_text(n.position + Vector3.UP * (float(u.size) + 0.8), Lang.t("+%d 金") % Content.SCAVENGE,
				Color(1.0, 0.82, 0.3), 22)


func _process(delta: float) -> void:
	if fight == null:
		return
	var k := 1.0 - exp(-delta * 14.0)
	var turn := 1.0 - exp(-delta * 8.0)
	for u in fight.units:
		if int(u.hp) <= 0:
			continue
		var n: Node3D = _nodes.get(u.id)
		if n == null:
			continue
		var to := place(u)
		var step := to - n.position
		step.y = 0.0
		var moving := step.length() > 0.04
		n.position = n.position.lerp(to, k)
		var want := atan2(step.x, step.z) if moving else _facing(u)
		n.rotation.y = lerp_angle(n.rotation.y, want, turn)
		Creatures.pace(n, moving, pace)


## Which way a fighter looks while it stands: at the other side.
static func _facing(u: Dictionary) -> float:
	return PI * 0.5 if u.side == "ours" else -PI * 0.5


## A step's events, shown.
func show_events(ev: Array) -> void:
	var lands := {}               # striker id -> seconds until its blow lands (one bite or one shot a step)
	for e in ev:
		match e.t:
			"hit":
				var a: Variant = fight.unit(e.from)
				var b: Variant = fight.unit(e.to)
				var na: Node3D = _nodes.get(e.from)
				var nb: Node3D = _nodes.get(e.to)
				if a == null or b == null or na == null or nb == null:
					continue
				if not lands.has(e.from):
					lands[e.from] = _strike(a, na, nb)
				var wait: float = lands[e.from]
				_due[e.to] = maxi(int(_due.get(e.to, 0)), Time.get_ticks_msec() + int(wait * 1000.0))
				_after(wait, _struck.bind(e, a, b, na, nb))
			"heal":
				var na: Node3D = _nodes.get(e.from)
				var nb: Node3D = _nodes.get(e.to)
				if na == null or nb == null:
					continue
				var from := _chest(na)
				var to := _chest(nb)
				var wait := 0.0
				if Vector2(to.x - from.x, to.z - from.z).length() > 0.3:      # a healer mending itself: nothing flies
					wait = Effects.flight(from, to, "heal", pace)
					Effects.fly(self, from, to, "heal", wait)
				_after(wait, _healed.bind(nb, int(e.amount)))
			"die":
				var n: Node3D = _nodes.get(e.id)
				if n:
					var u: Variant = fight.unit(e.id)
					var wait := maxf(0.0, (int(_due.get(e.id, 0)) - Time.get_ticks_msec()) / 1000.0)
					_after(wait, _fallen.bind(n, u != null and u.side == "theirs"))
			"burst":
				var p: Vector2 = e.at
				var ground := World.ARENA + Vector3(p.x, World.GROUND_TOP, p.y)
				Effects.fireball(self, ground + Vector3.UP * 0.6, ground, float(e.radius))
				Effects.shake(get_viewport().get_camera_3d(), 0.16, 0.3)
				if tags:
					tags.float_text(ground + Vector3.UP * 2.1, Lang.t("炸！"), Color(1.0, 0.6, 0.2), 22)
			"spawn":
				var n := _add(e.unit)
				n.scale = Vector3.ONE * 0.2
				var tw := n.create_tween()
				tw.tween_property(n, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				Effects.puff(self, n.position + Vector3.UP * 0.3, Effects.SPORES, 0.6, 6, 0.6)


## The striker's blow begun -- a bite (it lunges) or a shot (it flies) -- and how long until it lands.
func _strike(a: Dictionary, na: Node3D, nb: Node3D) -> float:
	if float(a.range) < 3.0:
		Creatures.lunge(na, nb.position - na.position, pace)
		return 0.07 / pace
	var ahead := Vector3(sin(na.rotation.y), 0.0, cos(na.rotation.y)) * float(a.size) * 0.45
	var from := na.position + ahead + Vector3.UP * Creatures.height(na) * 0.75
	var to := _chest(nb)
	var look: String = SHOT_OF.get(a.kind, "ours" if a.side == "ours" else "theirs")
	var t := Effects.flight(from, to, look, pace)
	Effects.fly(self, from, to, look, t)
	if Creatures.is_model(na):
		Creatures.busy(na, "attack", pace)
	return t


## A blow landing on `nb`: it flashes and flinches, sparks fly (the more, the harder the blow), its number rises.
func _struck(e: Dictionary, a: Dictionary, b: Dictionary, na: Node3D, nb: Node3D) -> void:
	if not is_instance_valid(nb):
		return
	Creatures.flash(nb, Color.WHITE, 0.6)
	if Creatures.is_model(nb) and not Creatures.is_busy(nb) and int(b.hp) > 0:
		Creatures.busy(nb, "batter", pace)
	var c: Color = OUR_SPARKS if a.side == "ours" else THEIR_SPARKS
	if float(a.range) >= 3.0:
		c = Effects.SHOTS[SHOT_OF.get(a.kind, "ours" if a.side == "ours" else "theirs")].color
	Effects.sparks(self, _chest(nb), c, clampf(0.6 + float(e.dmg) / 8.0, 0.7, 1.6))
	if tags:
		var words := Color(1.0, 0.4, 0.32) if b.side == "ours" else Color(1.0, 0.96, 0.86)
		tags.float_text(nb.position + Vector3.UP * (float(b.size) + 0.5), "-%d" % e.dmg, words, 18)
		if e.get("charge", false) and is_instance_valid(na):
			tags.float_text(na.position + Vector3.UP * (float(a.size) + 1.2), Lang.t("冲锋！"), Color(1.0, 0.85, 0.4), 20)


## A heal landing: the healed glows green, motes rise round it, its number rises.
func _healed(nb: Node3D, amount: int) -> void:
	if not is_instance_valid(nb):
		return
	Creatures.flash(nb, HEAL, 0.8)
	Effects.motes(self, nb.position, HEAL, Creatures.height(nb))
	if tags:
		tags.float_text(nb.position + Vector3.UP * 1.6, "+%d" % amount, HEAL, 18)


## One fallen: it falls, in a puff of dust (ours) or of spores (theirs).
func _fallen(n: Node3D, theirs: bool) -> void:
	if not is_instance_valid(n):
		return
	Creatures.fall(n, pace)
	var size := clampf(Creatures.height(n), 0.6, 2.0)
	Effects.puff(self, n.position + Vector3.UP * 0.25, Effects.SPORES if theirs else Effects.DUST, size)


## Where a blow strikes a fighter: halfway up it.
static func _chest(n: Node3D) -> Vector3:
	return n.position + Vector3.UP * Creatures.height(n) * 0.5


## `f` called `secs` from now (at once if none).
func _after(secs: float, f: Callable) -> void:
	if secs <= 0.005:
		f.call()
		return
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(f)
