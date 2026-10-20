class_name Nest
extends Unit
## A clutch of eggs in its plot (GAME-DESIGN 5.3). They hatch one at a time: in the card's time when the eggs
## have all they need, twice as long for each thing missing, and not at all while there is fighting right by
## them. The first out is the biggest and the rest keep near it. Hatched out, it is an empty nest a new egg
## card can go in. The robots come for the nests: lose them all and the battle is lost.

const HP := 600.0
const LOUD_NEAR := 6.0       # fighting this close and the eggs keep still
const QUIET_REACH := 14.0    # what a tyrannosaur's eggs call quiet: no fighting nearer than this...
const QUIET_SECS := 4.0      # ...for this long
const WARM := 1.5            # a compost heap beside it hatches its eggs this much sooner
const ROCK_FROM := 0.7       # the egg about to hatch rocks through the last of its time

var plot := Vector2i.ZERO
var card := ""               # the egg card last planted in it
var left := 0                # eggs still to hatch
var progress := 0.0          # of the next egg, 0 to 1
var missing: Array = []      # what its eggs need and do not have, at the last look
var stopped := false         # fighting right by it

var _c: Dictionary
var _lead: Dino = null       # the first out of this clutch
var _ground: Node3D
var _eggs: Array[MeshInstance3D] = []
var _lean: Array[Basis] = []
var _rate := 0.0
var _look_in := 0.0

static var _shells := {}


func setup(p_battle: Node, p_plot: Vector2i, at: Vector3) -> void:
	battle = p_battle
	team = "dino"
	plot = p_plot
	max_hp = HP
	hp = HP
	radius = 1.4
	aim_height = 0.3
	position = at
	make_bar(1.6, 2.2, false)


## A new clutch in it: the card's eggs, in a scrape the size of their kind's.
func lay(p_card: String) -> void:
	card = p_card
	_c = Cards.ALL[card]
	left = _c.eggs
	progress = 0.0
	_lead = null
	_look_in = 0.0
	if _ground:
		_ground.queue_free()
	_ground = Node3D.new()
	_ground.rotation.y = randf() * TAU
	add_child(_ground)
	_dig(_c.nest)
	_eggs.clear()
	_lean.clear()
	var n: int = _c.eggs
	for i in n:
		var egg := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = _c.size * 0.36
		m.height = _c.size
		m.radial_segments = 12
		m.rings = 6
		egg.mesh = m
		egg.material_override = _shell(false)
		var lean := Basis()
		if n > 1:
			var a := TAU * i / n
			egg.position = Vector3(cos(a), 0.0, sin(a)) * _c.nest * 0.3
			lean = Basis(Vector3(sin(a), 0.0, -cos(a)), 0.35)  # leaning out from the middle
		egg.position.y = _c.size * 0.36
		egg.basis = lean
		_ground.add_child(egg)
		_eggs.append(egg)
		_lean.append(lean)


func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_bar()
	if left <= 0 or battle.over:
		return
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = 0.25
		_look()
	progress += _rate * delta
	_rock()
	if progress >= 1.0:
		progress = 0.0
		_hatch()


## How fast the next egg comes on, from what is round the nest now.
func _look() -> void:
	missing = []
	for need in _c.needs:
		var has: bool
		if need == "quiet":
			has = not battle.loud_near(global_position, QUIET_REACH, QUIET_SECS)
		else:
			has = battle.garden.beside(plot, need)
		if not has:
			missing.append(need)
	stopped = battle.loud_near(global_position, LOUD_NEAR, 1.5)
	var warm: float = WARM if battle.garden.beside(plot, "compost") else 1.0
	_rate = 0.0 if stopped else pow(0.5, missing.size()) * warm / _c.hatch


## The egg about to hatch rocks, harder as its time comes.
func _rock() -> void:
	var i := left - 1
	var k := clampf((progress - ROCK_FROM) / (1.0 - ROCK_FROM), 0.0, 1.0)
	if k <= 0.0 or stopped:
		_eggs[i].basis = _lean[i]
		return
	var t: float = battle.clock
	_eggs[i].basis = _lean[i] * Basis(Vector3.FORWARD, sin(t * 16.0) * 0.25 * k)


func _hatch() -> void:
	left -= 1
	var egg := _eggs[left]
	egg.basis = _lean[left]
	egg.scale = Vector3(1.0, 0.45, 1.0)
	egg.position.y = _c.size * 0.1
	egg.material_override = _shell(true)
	var out := _ground.basis * Vector3(egg.position.x, 0.0, egg.position.z)
	var dir := out.normalized() if out.length() > 0.01 else Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	var lead: Dino = _lead if Unit.standing(_lead) else null
	var d: Dino = battle.born(_c.species, global_position + dir * (_c.nest + 0.5), dir, lead)
	if lead == null:
		_lead = d
	battle.sound("wood_hit_1", global_position, -6.0)


## What it is doing, for the player who points at it.
func describe() -> String:
	var lines := PackedStringArray()
	if left > 0:
		lines.append("%s：还有 %d 个" % [_c.name, left])
		if stopped:
			lines.append("旁边在打仗，蛋不动了")
		for need in _c.needs:
			if need == "quiet":
				lines.append("太吵了，孵得慢" if need in missing else "够安静")
			else:
				var what: String = Cards.NEEDS[need]
				lines.append(("缺%s，孵得慢" % what) if need in missing else ("挨着%s" % what))
		if battle.garden.beside(plot, "compost"):
			lines.append("挨着堆肥草堆，孵得快")
	else:
		lines.append("空窝：能再种一窝蛋")
	if hp < max_hp:
		lines.append("窝被打坏了：%d / %d" % [ceili(hp), int(max_hp)])
	return "\n".join(lines)


func _on_die() -> void:
	left = 0
	battle.nest_lost(self)
	battle.sound("wood_break", global_position, 0.0)
	var trod := _matte(Color(0.1, 0.08, 0.07))
	for mi in _ground.get_children():
		(mi as MeshInstance3D).material_override = trod
	for egg in _eggs:
		egg.visible = false
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(self, "position:y", -0.3, 1.5)
	tw.tween_callback(_gone)


## The plot is free again.
func _gone() -> void:
	if battle.garden.things.get(plot) == self:
		battle.garden.things.erase(plot)
	queue_free()


## A shallow bowl scraped in the sand, with a low rim of the earth thrown out of it.
func _dig(r: float) -> void:
	var scrape := MeshInstance3D.new()
	var dish := CylinderMesh.new()
	dish.top_radius = r
	dish.bottom_radius = r * 1.06
	dish.height = 0.06
	scrape.mesh = dish
	scrape.material_override = _matte(Color(0.2, 0.15, 0.1))
	scrape.position.y = 0.03
	_ground.add_child(scrape)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.85
	ring.outer_radius = r * 1.15
	rim.mesh = ring
	rim.scale = Vector3(1.0, 0.4, 1.0)
	rim.position.y = 0.04
	rim.material_override = _matte(Color(0.45, 0.35, 0.2))
	_ground.add_child(rim)


func _shell(open: bool) -> StandardMaterial3D:
	var key := card + ("_open" if open else "")
	if not _shells.has(key):
		var c: Color = _c.shell
		var m := StandardMaterial3D.new()
		m.albedo_color = c.darkened(0.35) if open else c
		m.roughness = 0.55
		_shells[key] = m
	return _shells[key]


func _matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
