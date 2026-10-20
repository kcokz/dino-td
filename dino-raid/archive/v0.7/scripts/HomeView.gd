class_name HomeView
extends Node3D
## The homeland on screen (GAME-DESIGN 14): its plots -- the rows not yet opened still wild -- a block for each
## building, taller or bigger for each level, its affixes shown as little blocks on a nest's roof; and to the south
## the yard, where this round's army stands: each unit hatched from its nest's door, gone with the battle.

const TILE := 4.0
const PLOT := 3.6
const PLOT_TOP := 0.15
const YARD_Z := 12.5
const SLOT := 1.6
const PER_ROW := 12
const NOWHERE := Vector2i(-1, -1)
const PLOT_COLOUR := Color(0.62, 0.53, 0.39)
const WILD_COLOUR := Color(0.29, 0.37, 0.22)

var home: Home
var tags: Tags
var tints := {}                   # plot -> Color, lit by Game (where a held card can go)
var _plot_mats := {}              # plot -> StandardMaterial3D
var _wild := {}                   # plot -> Node3D: the brush on a plot not yet opened
var _buildings := {}              # plot -> {node, look}
var _units := {}                  # army unit id -> Node3D
var _order: Array = []            # army unit ids, as they stand in the yard


func setup(p_home: Home) -> void:
	home = p_home
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in Home.ROWS:
		for x in Home.COLS:
			var p := Vector2i(x, y)
			var slab := Blocks.box(Vector3(PLOT, 0.1, PLOT), PLOT_COLOUR, plot_pos(p) + Vector3(0, PLOT_TOP - 0.05, 0))
			var m := StandardMaterial3D.new()
			m.roughness = 0.9
			slab.material_override = m
			_plot_mats[p] = m
			add_child(slab)
			if not home.is_open(p):
				m.albedo_color = WILD_COLOUR
				var brush := Node3D.new()
				for k in 3:
					var h := rng.randf_range(0.4, 1.1)
					var bush := Blocks.box(Vector3(rng.randf_range(0.6, 1.2), h, rng.randf_range(0.6, 1.2)),
						Color(0.2, 0.33, 0.17).lerp(Color(0.32, 0.42, 0.22), rng.randf()),
						Vector3(rng.randf_range(-1.1, 1.1), PLOT_TOP + h * 0.5, rng.randf_range(-1.1, 1.1)))
					bush.rotation.y = rng.randf() * TAU
					brush.add_child(bush)
				brush.position = plot_pos(p)
				add_child(brush)
				_wild[p] = brush
			else:
				m.albedo_color = PLOT_COLOUR
	# A fence along the yard's north side.
	add_child(Blocks.box(Vector3(PER_ROW * SLOT + 1.0, 0.5, 0.12), Color(0.45, 0.33, 0.2), Vector3(0, 0.3, YARD_Z - SLOT * 0.5 - 0.5)))
	refresh_buildings(false)


static func plot_pos(p: Vector2i) -> Vector3:
	return Vector3((p.x - (Home.COLS - 1) * 0.5) * TILE, 0.0, (p.y - (Home.ROWS - 1) * 0.5) * TILE)


static func slot_pos(i: int) -> Vector3:
	return Vector3((i % PER_ROW - (PER_ROW - 1) * 0.5) * SLOT, World.GROUND_TOP, YARD_Z + (i / PER_ROW) * SLOT)


static func plot_at(w: Vector3) -> Vector2i:
	var x := roundi(w.x / TILE + (Home.COLS - 1) * 0.5)
	var y := roundi(w.z / TILE + (Home.ROWS - 1) * 0.5)
	if x < 0 or x >= Home.COLS or y < 0 or y >= Home.ROWS:
		return NOWHERE
	var c := plot_pos(Vector2i(x, y))
	if absf(w.x - c.x) > TILE * 0.5 or absf(w.z - c.z) > TILE * 0.5:
		return NOWHERE
	return Vector2i(x, y)


## The top of the building at p (where words go over it).
func top(p: Vector2i) -> Vector3:
	var h := 0.6
	if _buildings.has(p):
		h = float(_buildings[p].node.get_meta("height", 1.5))
	return plot_pos(p) + Vector3(0, PLOT_TOP + h, 0)


func unit_node(id: String) -> Node3D:
	return _units.get(id)


# -- Land ------------------------------------------------------------------------------------------------------

## Rows opened since: their brush cleared, their ground turned.
func open_rows() -> void:
	for p in _wild.keys():
		if not home.is_open(p):
			continue
		var brush: Node3D = _wild[p]
		_wild.erase(p)
		var tw := brush.create_tween()
		tw.tween_property(brush, "scale", Vector3(1, 0.02, 1), 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(brush.queue_free)
		var m: StandardMaterial3D = _plot_mats[p]
		var turn := create_tween()
		turn.tween_property(m, "albedo_color", PLOT_COLOUR, 0.8)


# -- Buildings -------------------------------------------------------------------------------------------------

## A block for each building there is, made again where one has been built, raised or affixed (rising up).
func refresh_buildings(pop := true) -> void:
	for p in _buildings.keys():
		if not home.buildings.has(p):
			_buildings[p].node.queue_free()
			_buildings.erase(p)
	for p in home.buildings:
		var b: Dictionary = home.buildings[p]
		var look := "%s/%d/%s" % [b.kind, b.level, ",".join(b.affixes)]
		if _buildings.has(p) and _buildings[p].look == look:
			continue
		var grow := 0.05
		if _buildings.has(p):
			grow = 0.6 if _buildings[p].look.get_slice("/", 0) == b.kind else 0.05
			_buildings[p].node.queue_free()
		var node := _building(b.kind, int(b.level), b.affixes)
		node.position = plot_pos(p) + Vector3(0, PLOT_TOP, 0)
		add_child(node)
		_buildings[p] = {"node": node, "look": look}
		if pop:
			node.scale = Vector3(1, grow, 1)
			var tw := node.create_tween()
			tw.tween_property(node, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _building(kind: String, lv: int, affixes: Array) -> Node3D:
	var root := Node3D.new()
	var info: Dictionary = Content.BUILDINGS[kind]
	var c: Color = info.color
	var height := 0.0
	if info.has("nest"):
		# Tiers: one, two from level 3, three at level 5; a door; its affixes on the roof.
		var tiers := 1 + (1 if lv >= 3 else 0) + (1 if lv >= 5 else 0)
		for i in tiers:
			var w := 3.0 - i * 0.6
			var h := 1.1 if i == 0 else 0.7
			root.add_child(Blocks.box(Vector3(w, h, w), c.lightened(i * 0.08), Vector3(0, height + h * 0.5, 0)))
			root.add_child(Blocks.box(Vector3(w + 0.04, 0.08, w + 0.04), c.darkened(0.35), Vector3(0, height + h - 0.04, 0)))
			height += h
		root.add_child(Blocks.box(Vector3(0.9, 0.8, 0.08), Color(0.12, 0.09, 0.07), Vector3(0, 0.4, 1.52)))
		for i in affixes.size():
			var ac: Color = Content.AFFIXES[affixes[i]].color
			var cube := Blocks.box(Vector3(0.42, 0.42, 0.42), ac, Vector3(-0.55 + i * 0.55, height + 0.21, 0.4))
			if affixes[i] == "plasma":
				cube.material_override = Blocks.glow(ac)
			root.add_child(cube)
		if not affixes.is_empty():
			height += 0.42
	else:
		match kind:
			"pool":
				var rim := 0.35 + 0.08 * lv
				root.add_child(Blocks.box(Vector3(3.2, rim, 3.2), c.darkened(0.45), Vector3(0, rim * 0.5, 0)))
				var water := Blocks.box(Vector3(2.8, 0.06, 2.8), c, Vector3(0, rim + 0.01, 0))
				water.material_override = Blocks.glow(c, 0.35)
				root.add_child(water)
				height = rim
			"sampler":
				var tall := 1.6 + 0.3 * lv
				root.add_child(Blocks.box(Vector3(1.8, 0.5, 1.8), c.darkened(0.3), Vector3(0, 0.25, 0)))
				root.add_child(Blocks.cylinder(0.32, tall, c, Vector3(0, tall * 0.5, 0)))
				var dish := Blocks.cylinder(0.85, 0.1, c.lightened(0.3), Vector3(0, tall + 0.1, 0.1))
				dish.rotation.x = 0.5
				root.add_child(dish)
				height = tall + 0.4
			"power":
				var h := 1.0 + 0.2 * lv
				root.add_child(Blocks.box(Vector3(2.4, h, 2.4), Color(0.3, 0.3, 0.32), Vector3(0, h * 0.5, 0)))
				var core := Blocks.cylinder(0.55, 0.8, c, Vector3(0, h + 0.4, 0))
				core.material_override = Blocks.glow(c, 1.4)
				root.add_child(core)
				height = h + 0.8
			"gym":
				var post := 1.3 + 0.2 * lv
				root.add_child(Blocks.box(Vector3(3.0, 0.3, 3.0), c, Vector3(0, 0.15, 0)))
				for sx in [-1.1, 1.1]:
					root.add_child(Blocks.box(Vector3(0.25, post, 0.25), c.darkened(0.3), Vector3(sx, 0.3 + post * 0.5, 0)))
				root.add_child(Blocks.box(Vector3(2.5, 0.18, 0.18), c.lightened(0.3), Vector3(0, 0.3 + post, 0)))
				height = post + 0.5
			"stabilizer":
				var tall := 1.8 + 0.25 * lv
				root.add_child(Blocks.box(Vector3(1.4, 0.4, 1.4), c.darkened(0.4), Vector3(0, 0.2, 0)))
				root.add_child(Blocks.cylinder(0.28, tall, c.darkened(0.15), Vector3(0, tall * 0.5, 0)))
				for k in 2:
					var ring := Blocks.cylinder(0.8, 0.08, c, Vector3(0, tall * (0.55 + 0.3 * k), 0))
					ring.material_override = Blocks.glow(c, 0.9)
					root.add_child(ring)
				height = tall
			"lab":
				var r := 1.05 + 0.1 * lv
				root.add_child(Blocks.dome(r, c, Vector3.ZERO))
				root.add_child(Blocks.cylinder(0.18, 1.0, c.darkened(0.4), Vector3(0.6, r * 0.6 + 0.3, -0.4)))
				var window := Blocks.box(Vector3(0.7, 0.4, 0.1), c.lightened(0.4), Vector3(0, 0.45, r - 0.12))
				window.material_override = Blocks.glow(c.lightened(0.4), 0.8)
				root.add_child(window)
				height = r
			"store":
				var h := 1.0 + 0.15 * lv
				root.add_child(Blocks.box(Vector3(3.0, h, 2.2), c, Vector3(0, h * 0.5, 0)))
				root.add_child(Blocks.box(Vector3(3.2, 0.2, 2.5), c.darkened(0.35), Vector3(0, h + 0.1, 0)))
				root.add_child(Blocks.box(Vector3(1.0, 0.8, 0.08), c.darkened(0.55), Vector3(0, 0.4, 1.12)))
				height = h + 0.2
			"wall":
				var h := 0.9 + 0.3 * lv
				root.add_child(Blocks.box(Vector3(3.4, h, 1.2), c, Vector3(0, h * 0.5, 0)))
				for i in 4:
					root.add_child(Blocks.box(Vector3(0.5, 0.4, 1.2), c.darkened(0.2), Vector3(-1.2 + i * 0.8, h + 0.2, 0)))
				height = h + 0.4
	root.set_meta("height", height)
	return root


# -- The yard ------------------------------------------------------------------------------------------------------

## The yard shows `army` (Home.army): a unit new to it hatches from its nest's door and hops to its place, one by one;
## one no longer in it shrinks away; one that looks different now is made again; the rest walk to their places.
func sync_army(army: Array, hatch := true) -> void:
	var ids := {}
	var k := 0
	for i in army.size():
		var u: Dictionary = army[i]
		ids[u.id] = true
		var look := _look(u)
		var n: Node3D = _units.get(u.id)
		if n != null and n.get_meta("look", "") != look:
			var at := n.position
			n.queue_free()
			n = _new_unit(u, look)
			n.position = at
			_flash(n)
		elif n == null:
			n = _new_unit(u, look)
			if hatch and home.buildings.has(u.nest):
				n.position = _door(u.nest)
				n.scale = Vector3.ONE * 0.3
				n.visible = false
				_hatch(n, slot_pos(i), k * 0.07)
				k += 1
				continue
			n.position = slot_pos(i)
		if n.position.distance_to(slot_pos(i)) > 0.05:
			var tw := n.create_tween()
			tw.tween_property(n, "position", slot_pos(i), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for id in _units.keys():
		if not ids.has(id):
			var gone: Node3D = _units[id]
			_units.erase(id)
			var tw := gone.create_tween()
			tw.tween_property(gone, "scale", Vector3.ONE * 0.05, 0.25)
			tw.tween_callback(gone.queue_free)
	_order = army.map(func(u: Dictionary) -> String: return u.id)


## Out to battle: every unit hops north off the yard and is gone -- this round's army does not come back.
func go_out() -> void:
	var k := 0
	for id in _order:
		var n: Node3D = _units.get(id)
		if n == null:
			continue
		var tw := n.create_tween()
		tw.tween_interval(k * 0.03)
		tw.tween_property(n, "position", n.position + Vector3(0, 0, -3.0), 0.3)
		tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.05, 0.3)
		tw.tween_callback(n.queue_free)
		k += 1
	_units.clear()
	_order.clear()


func _look(u: Dictionary) -> String:
	return "%s/%s/%.2f" % [u.kind, ",".join(u.affixes), float(u.atk_mult)]


func _new_unit(u: Dictionary, look: String) -> Node3D:
	var s := Content.unit_stats(u)
	var n := Blocks.creature(float(s.size), Content.UNITS[u.kind].color, false, u.affixes)
	n.set_meta("look", look)
	add_child(n)
	_units[u.id] = n
	return n


func _hatch(n: Node3D, to: Vector3, delay: float) -> void:
	var from := n.position
	var arc := func(t: float) -> void:
		if is_instance_valid(n):
			n.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.6
	var tw := n.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(n.show)
	tw.tween_property(n, "scale", Vector3.ONE, 0.2)
	tw.parallel().tween_method(arc, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)


func _door(p: Vector2i) -> Vector3:
	return plot_pos(p) + Vector3(0, PLOT_TOP, 1.7)


func _flash(n: Node3D) -> void:
	var m := Blocks.body_of(n).material_override as StandardMaterial3D
	m.emission = Color(1.0, 0.9, 0.5)
	m.emission_energy_multiplier = 1.2
	var tw := n.create_tween()
	tw.tween_property(m, "emission_energy_multiplier", 0.0, 0.5)


## Lights the plots in tints; the rest as they are (the wild ones never lit).
func paint() -> void:
	for p in _plot_mats:
		if not home.is_open(p) or _wild.has(p):
			continue
		var m: StandardMaterial3D = _plot_mats[p]
		var c: Color = tints.get(p, PLOT_COLOUR)
		m.albedo_color = c
		m.emission_enabled = tints.has(p)
		m.emission = c * 0.35


# -- Pointing ------------------------------------------------------------------------------------------------------

## What is under the screen point, for what is wanted ("tile": a plot by the ground; "building": a building's block,
## else the plot; "unit": a unit in the yard; "any": a unit, a building or a plot): {"plot": Vector2i or NOWHERE,
## "unit": id or ""}.
func pick(cam: Camera3D, at: Vector2, want := "any") -> Dictionary:
	var out := {"plot": NOWHERE, "unit": ""}
	if want == "unit" or want == "any":
		var best := INF
		for id in _units:
			var n: Node3D = _units[id]
			if not n.visible:
				continue
			var edge := float(n.get_meta("edge", 1.0))
			var c := n.global_position + Vector3.UP * edge * 0.5
			if cam.is_position_behind(c):
				continue
			var sp := cam.unproject_position(c)
			var r := maxf(12.0, sp.distance_to(cam.unproject_position(c + cam.global_basis.x * edge * 0.75)))
			var d := sp.distance_to(at)
			if d <= r and d < best:
				best = d
				out.unit = id
		if out.unit != "" or want == "unit":
			return out
	if want == "building" or want == "any":
		var near := INF
		for p in _buildings:
			var node: Node3D = _buildings[p].node
			if _screen_rect(cam, node).has_point(at):
				var d := cam.global_position.distance_to(node.global_position)
				if d < near:
					near = d
					out.plot = p
		if out.plot != NOWHERE:
			return out
	var g: Variant = Geo.ground_point(cam, at)
	if g != null:
		out.plot = plot_at(g)
	return out


func _screen_rect(cam: Camera3D, node: Node3D) -> Rect2:
	var box := Geo.bounds(node)
	var r := Rect2()
	var first := true
	for i in 8:
		var corner := node.global_transform * box.get_endpoint(i)
		if cam.is_position_behind(corner):
			continue
		var sp := cam.unproject_position(corner)
		if first:
			r = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			r = r.expand(sp)
	return r
