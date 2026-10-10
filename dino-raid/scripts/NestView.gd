class_name NestView
extends Node3D
## A nest in the sand: a shallow scrape with a rim of thrown-out earth and the eggs in it, as many as are
## still to hatch. The ones due at the end of this turn rock.

static var _shells := {}

var id := 0
var tile := Vector2i.ZERO
var species := ""
var hp := 0
var max_hp := 0
var due := false                 # hatching at the end of this turn: the eggs rock

var _eggs: Array[MeshInstance3D] = []
var _lean: Array[Basis] = []
var _scrape: Node3D


func setup(n: Dictionary) -> void:
	id = n.id
	tile = n.pos
	hp = n.hp
	max_hp = Rules.NEST_HP
	position = Board.world(tile)
	refill(n)


## The eggs the state says are in it, of the kind it says.
func refill(n: Dictionary) -> void:
	species = n.species
	if _scrape:
		_scrape.queue_free()
	_eggs.clear()
	_lean.clear()
	_scrape = Node3D.new()
	_scrape.rotation.y = randf() * TAU
	add_child(_scrape)
	var size: float = {"coelophysis": 0.24, "triceratops": 0.42, "tyrannosaurus": 0.55}.get(species, 0.3)
	var shell: Color = {"coelophysis": Color(0.88, 0.84, 0.72), "triceratops": Color(0.8, 0.79, 0.74),
		"tyrannosaurus": Color(0.56, 0.47, 0.39)}.get(species, Color(0.85, 0.82, 0.74))
	var radius := 1.5
	_dig(radius)
	var count := mini(8, int(n.eggs) * maxi(1, int(n.pack)))
	for i in count:
		var egg := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = size * 0.36
		m.height = size
		m.radial_segments = 12
		m.rings = 6
		egg.mesh = m
		egg.material_override = _shell(shell, false)
		var lean := Basis()
		if count > 1:
			var a := TAU * i / count
			egg.position = Vector3(cos(a), 0.0, sin(a)) * radius * (0.3 if count < 5 else 0.36)
			lean = Basis(Vector3(sin(a), 0.0, -cos(a)), 0.35)
		egg.position.y = size * 0.36
		egg.basis = lean
		_scrape.add_child(egg)
		_eggs.append(egg)
		_lean.append(lean)


func egg_count() -> int:
	return _eggs.size()


## Eggs crack: `n` of them open.
func crack(n: int) -> void:
	for i in mini(n, _eggs.size()):
		var egg: MeshInstance3D = _eggs.pop_back()
		_lean.pop_back()
		egg.scale = Vector3(1.0, 0.45, 1.0)
		egg.position.y *= 0.3
		var c: Color = (egg.material_override as StandardMaterial3D).albedo_color
		egg.material_override = _shell(c.darkened(0.35), true)


func _process(_delta: float) -> void:
	for i in _eggs.size():
		if due:
			var t := Time.get_ticks_msec() * 0.001
			_eggs[i].basis = _lean[i] * Basis(Vector3.FORWARD, sin(t * 14.0 + i) * 0.22)
		else:
			_eggs[i].basis = _lean[i]


## Trampled flat: the eggs smashed, the scrape dark.
func lost() -> void:
	for egg in _eggs:
		egg.visible = false
	var trod := StandardMaterial3D.new()
	trod.albedo_color = Color(0.1, 0.08, 0.07)
	for mi in _scrape.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = trod
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(self, "position:y", -0.4, 1.0)
	tw.tween_callback(queue_free)


func _dig(r: float) -> void:
	var scrape := MeshInstance3D.new()
	var dish := CylinderMesh.new()
	dish.top_radius = r
	dish.bottom_radius = r * 1.06
	dish.height = 0.06
	scrape.mesh = dish
	scrape.material_override = _matte(Color(0.22, 0.17, 0.11))
	scrape.position.y = 0.03
	_scrape.add_child(scrape)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.85
	ring.outer_radius = r * 1.18
	ring.rings = 24
	rim.mesh = ring
	rim.scale = Vector3(1.0, 0.42, 1.0)
	rim.position.y = 0.05
	rim.material_override = _matte(Color(0.5, 0.4, 0.25))
	_scrape.add_child(rim)
	for i in 7:
		var a := TAU * i / 7.0 + randf_range(-0.3, 0.3)
		var twig := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.03
		stick.bottom_radius = 0.035
		stick.height = randf_range(0.5, 0.9)
		twig.mesh = stick
		twig.material_override = _matte(Color(0.3, 0.21, 0.12))
		twig.position = Vector3(cos(a), 0.0, sin(a)) * r * 1.02 + Vector3.UP * 0.12
		twig.rotation = Vector3(PI * 0.5, a + randf_range(-0.6, 0.6), 0.0)
		_scrape.add_child(twig)


static func _shell(c: Color, open: bool) -> StandardMaterial3D:
	var key := "%s%s" % [c.to_html(), open]
	if not _shells.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.55
		_shells[key] = m
	return _shells[key]


static func _matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
