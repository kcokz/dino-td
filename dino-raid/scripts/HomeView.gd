class_name HomeView
extends Node3D
## The homeland on screen (GAME-DESIGN 12): its plots; on them a block for each building -- a tier more for each
## level, a door on those that make units -- and to the south the yard, a square for each unit the homeland can
## keep, a block on each one it has. It shows Home; the events of a round or of a card it plays out in order.

const TILE := 4.0
const PLOT := 3.6
const PLOT_TOP := 0.15
const YARD_Z := 11.0
const YARD_TOP := 0.09
const SLOT := 1.7
const PER_ROW := 10
const NOWHERE := Vector2i(-1, -1)
const PLOT_COLOUR := Color(0.62, 0.53, 0.39)
const SLOT_COLOUR := Color(0.56, 0.47, 0.34)

var home: Home
var tags: Tags
var tints := {}                   # plot -> Color, lit by Game (where a held card can go)
var unit_tints := {}              # unit id -> Color
var _plot_mats := {}              # plot -> StandardMaterial3D
var _buildings := {}              # plot -> {node, kind, level}
var _units := {}                  # unit id -> Node3D
var _stars := {}                  # unit id -> the stars its block was made with
var _order: Array = []            # unit ids, as they stand in the yard
var _slots: Array = []            # MeshInstance3D, one for each place in the yard
var _slot_mats: Array = []
var _out := false                 # the units are out fighting


func setup(p_home: Home) -> void:
	home = p_home
	for y in Home.ROWS:
		for x in Home.COLS:
			var p := Vector2i(x, y)
			var slab := Blocks.box(Vector3(PLOT, 0.1, PLOT), PLOT_COLOUR, plot_pos(p) + Vector3(0, PLOT_TOP - 0.05, 0))
			var m := StandardMaterial3D.new()
			m.albedo_color = PLOT_COLOUR
			m.roughness = 0.9
			slab.material_override = m
			_plot_mats[p] = m
			add_child(slab)
	# A fence round the yard.
	var fence := Color(0.45, 0.33, 0.2)
	var half := PER_ROW * SLOT * 0.5 + 0.5
	add_child(Blocks.box(Vector3(half * 2.0, 0.5, 0.12), fence, Vector3(0, 0.3, YARD_Z - SLOT * 0.5 - 0.35)))
	refresh_buildings(false)
	_refresh_slots()
	for u in home.units:
		var n := _new_unit(u)
		n.position = slot_pos(_order.size())
		_order.append(u.id)


static func plot_pos(p: Vector2i) -> Vector3:
	return Vector3((p.x - (Home.COLS - 1) * 0.5) * TILE, 0.0, (p.y - (Home.ROWS - 1) * 0.5) * TILE)


static func slot_pos(i: int) -> Vector3:
	return Vector3((i % PER_ROW - (PER_ROW - 1) * 0.5) * SLOT, YARD_TOP, YARD_Z + (i / PER_ROW) * SLOT)


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
	var h := 0.0
	if _buildings.has(p):
		h = float(_buildings[p].node.get_meta("height", 1.5))
	return plot_pos(p) + Vector3(0, PLOT_TOP + h, 0)


func unit_node(id: int) -> Node3D:
	return _units.get(id)


func unit_ids() -> Array:
	return _units.keys()


# -- Buildings -----------------------------------------------------------------------------------------------

## A block for each building there is, made again where one has been built or raised (rising up).
func refresh_buildings(pop := true) -> void:
	for p in home.buildings:
		var b: Dictionary = home.buildings[p]
		if _buildings.has(p) and _buildings[p].kind == b.kind and _buildings[p].level == int(b.level):
			continue
		var was := 0.05
		if _buildings.has(p):
			was = float(_buildings[p].level) / float(b.level)
			_buildings[p].node.queue_free()
		var node := _building(b.kind, int(b.level))
		node.position = plot_pos(p) + Vector3(0, PLOT_TOP, 0)
		add_child(node)
		_buildings[p] = {"node": node, "kind": b.kind, "level": int(b.level)}
		if pop:
			node.scale = Vector3(1, was, 1)
			var tw := node.create_tween()
			tw.tween_property(node, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh_slots()


func _building(kind: String, level: int) -> Node3D:
	var root := Node3D.new()
	var b: Dictionary = Content.BUILDINGS[kind]
	var c: Color = b.color
	var l: Dictionary = b.levels[level - 1]
	var height := 0.0
	match kind:
		"pen":
			# A fence round the plot, higher for each level, a post at each corner.
			height = 0.5 + 0.3 * level
			for side in 4:
				var along := side % 2 == 0
				var off := 1.5 * (1.0 if side < 2 else -1.0)
				var at := Vector3(0, height * 0.5, off) if along else Vector3(off, height * 0.5, 0)
				var size := Vector3(3.1, height, 0.16) if along else Vector3(0.16, height, 3.1)
				root.add_child(Blocks.box(size, c, at))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					root.add_child(Blocks.box(Vector3(0.3, height + 0.3, 0.3), c.darkened(0.3),
						Vector3(sx * 1.5, (height + 0.3) * 0.5, sz * 1.5)))
			height += 0.3
		"farm":
			# A silo, taller for each level, and a shed.
			height = 1.4 + 0.7 * level
			root.add_child(Blocks.cylinder(0.85, height, c, Vector3(0.6, height * 0.5, -0.3)))
			root.add_child(Blocks.cylinder(0.95, 0.7, c.darkened(0.35), Vector3(0.6, height + 0.35, -0.3), 0.0))
			root.add_child(Blocks.box(Vector3(1.4, 1.1, 1.6), c.darkened(0.15), Vector3(-0.8, 0.55, 0.5)))
			height += 0.7
		"nursery":
			# A warm dome, bigger for each level.
			var r := 1.0 + 0.22 * level
			root.add_child(Blocks.dome(r, c, Vector3.ZERO))
			root.add_child(Blocks.box(Vector3(0.8, 0.7, 0.4), c.darkened(0.4), Vector3(0, 0.35, r - 0.1)))
			height = r
		"wall":
			# A thick wall across the middle of the plot, higher for each level, with teeth along its top.
			height = 1.0 + 0.5 * level
			root.add_child(Blocks.box(Vector3(3.2, height, 1.2), c, Vector3(0, height * 0.5, 0)))
			for i in 4:
				root.add_child(Blocks.box(Vector3(0.5, 0.4, 1.2), c.darkened(0.2), Vector3(-1.2 + i * 0.8, height + 0.2, 0)))
			height += 0.4
		_:
			# Tiers, one for each level.
			for i in level:
				var w := 3.0 - i * 0.6
				var h := 1.1 if i == 0 else 0.75
				root.add_child(Blocks.box(Vector3(w, h, w), c.lightened(i * 0.07), Vector3(0, height + h * 0.5, 0)))
				root.add_child(Blocks.box(Vector3(w + 0.04, 0.08, w + 0.04), c.darkened(0.35), Vector3(0, height + h - 0.04, 0)))
				height += h
	if l.has("makes"):
		root.add_child(Blocks.box(Vector3(0.9, 0.8, 0.08), Color(0.12, 0.09, 0.07), Vector3(0, 0.4, 1.52)))
	root.set_meta("height", height)
	return root


# -- The yard ------------------------------------------------------------------------------------------------

## A square for each place in the yard: as many as the homeland can keep.
func _refresh_slots() -> void:
	var room := home.room()
	while _slots.size() < room:
		var m := StandardMaterial3D.new()
		m.albedo_color = SLOT_COLOUR
		m.roughness = 0.95
		var s := Blocks.box(Vector3(1.45, 0.04, 1.45), SLOT_COLOUR, slot_pos(_slots.size()) - Vector3(0, 0.02, 0))
		s.material_override = m
		add_child(s)
		_slots.append(s)
		_slot_mats.append(m)
	while _slots.size() > room:
		_slots.pop_back().queue_free()
		_slot_mats.pop_back()


func _new_unit(u: Dictionary) -> Node3D:
	# Two plays shown at once may both make a block for the same unit: the older one goes.
	if _units.has(u.id) and is_instance_valid(_units[u.id]):
		_units[u.id].queue_free()
	var s := Content.stats("ours", u.kind, int(u.star))
	var n := Blocks.creature(float(s.size), Content.UNITS[u.kind].color)
	add_child(n)
	_units[u.id] = n
	_stars[u.id] = int(u.star)
	return n


## The events of a round's start or of a card, played out: each unit made comes out of its nest's door and hops to
## its place in the yard; three alike run together and become one of a star more; a nest with no room says so.
func play_events(ev: Array) -> void:
	var told_full := false
	for e in ev:
		match e.t:
			"made":
				var u: Dictionary = e.unit
				var n := _new_unit(u)
				n.position = _door(e.by)
				n.scale = Vector3.ONE * 0.3
				_order.append(u.id)
				_hop(n, slot_pos(_order.size() - 1), 0.5)
				var grow := n.create_tween()
				grow.tween_property(n, "scale", Vector3.ONE, 0.3)
				await get_tree().create_timer(0.22).timeout
			"merged":
				await _merge(e)
			"full":
				if tags and not told_full:
					tags.float_text(Vector3(0, 1.2, YARD_Z - 1.2), "院子满了，巢没法生产", Color(1.0, 0.55, 0.3), 24)
					told_full = true
					await get_tree().create_timer(0.2).timeout
			"built", "raised":
				refresh_buildings()
				await get_tree().create_timer(0.3).timeout
			"trained":
				var n: Node3D = _units.get(e.id)
				if n:
					_flash(n, Color(1.0, 0.85, 0.4))
					if tags:
						tags.float_text(n.position + Vector3.UP * 1.6, "变强了", Color(1.0, 0.85, 0.4))
			"starred":
				var n: Node3D = _units.get(e.id)
				if n and tags:
					tags.float_text(n.position + Vector3.UP * 1.8, "升星！", Color(1.0, 0.85, 0.3))
			"mended":
				if tags:
					tags.float_text(Vector3(0, 3.0, 0), "家园 +%d" % e.amount, Color(0.5, 1.0, 0.5), 28)
	if not ev.is_empty():
		await get_tree().create_timer(0.3).timeout   # the last hops land first
	settle()


func _merge(e: Dictionary) -> void:
	await get_tree().create_timer(0.3).timeout       # the three are all there first
	var meet := Vector3.ZERO
	var n := 0
	for id in e.from:
		if _units.has(id):
			meet += _units[id].position
			n += 1
	meet = meet / n if n > 0 else slot_pos(_order.size())
	meet.y = YARD_TOP
	for id in e.from:
		_order.erase(id)
		_stars.erase(id)
		if _units.has(id):
			var old: Node3D = _units[id]
			_units.erase(id)
			var tw := old.create_tween()
			tw.tween_property(old, "position", meet, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(old, "scale", Vector3.ONE * 0.2, 0.08)
			tw.tween_callback(old.queue_free)
	await get_tree().create_timer(0.36).timeout
	var u: Dictionary = e.unit
	var big := _new_unit(u)
	big.position = meet
	big.scale = Vector3.ONE * 0.2
	_order.append(u.id)
	var pop := big.create_tween()
	pop.tween_property(big, "scale", Vector3.ONE * 1.3, 0.18).set_ease(Tween.EASE_OUT)
	pop.tween_property(big, "scale", Vector3.ONE, 0.16)
	_flash(big, Color(1.0, 0.9, 0.5))
	if tags:
		tags.float_text(meet + Vector3.UP * 2.0, "三合一，升星！", Color(1.0, 0.85, 0.3), 24)
	await get_tree().create_timer(0.4).timeout


## Everyone to where the homeland has them: the gone (fallen) shrink away, a unit whose stars changed is made
## again, one without a block gets one.
func settle() -> void:
	var ids: Array = home.units.map(func(u: Dictionary) -> int: return int(u.id))
	for id in _units.keys():
		if not id in ids:
			var gone: Node3D = _units[id]
			_units.erase(id)
			_stars.erase(id)
			var tw := gone.create_tween()
			tw.tween_property(gone, "scale", Vector3.ONE * 0.05, 0.3)
			tw.tween_callback(gone.queue_free)
	for i in home.units.size():
		var u: Dictionary = home.units[i]
		var n: Node3D = _units.get(u.id)
		if n != null and _stars.get(u.id, 1) != int(u.star):
			var at := n.position
			n.queue_free()
			n = _new_unit(u)
			n.position = at
			_flash(n, Color(1.0, 0.9, 0.5))
		elif n == null:
			n = _new_unit(u)
			n.position = slot_pos(i)
			n.scale = Vector3.ONE * 0.2
		n.visible = not _out
		var tw := n.create_tween().set_parallel()
		if n.position.distance_to(slot_pos(i)) > 0.05:
			tw.tween_property(n, "position", slot_pos(i), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector3.ONE, 0.25)
	_order = ids
	_refresh_slots()


## Out to battle: every unit hops north off the yard and is gone from it.
func go_out() -> void:
	_out = true
	var k := 0
	for id in _order:
		var n: Node3D = _units.get(id)
		if n == null:
			continue
		var tw := n.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(n, "position", n.position + Vector3(0, 0, -2.5), 0.3)
		tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.05, 0.3)
		tw.tween_callback(n.hide)
		k += 1


## Back from battle: who came back stands in the yard again.
func come_back() -> void:
	_out = false
	for id in _units:
		var n: Node3D = _units[id]
		n.show()
		n.scale = Vector3.ONE * 0.05
	settle()


func _door(p: Vector2i) -> Vector3:
	return plot_pos(p) + Vector3(0, PLOT_TOP, 1.7)


## Jumps n to `to` in an arc.
func _hop(n: Node3D, to: Vector3, time: float) -> void:
	var from := n.position
	var arc := func(t: float) -> void:
		if is_instance_valid(n):
			n.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.6
	var tw := n.create_tween()
	tw.tween_method(arc, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE)


func _flash(n: Node3D, c: Color) -> void:
	var m := Blocks.body_of(n).material_override as StandardMaterial3D
	m.emission = c
	m.emission_energy_multiplier = 1.2
	var tw := n.create_tween()
	tw.tween_property(m, "emission_energy_multiplier", 0.0, 0.5)


## Lights the plots and yard places in tints and unit_tints; the rest as they are.
func paint() -> void:
	for p in _plot_mats:
		var m: StandardMaterial3D = _plot_mats[p]
		var c: Color = tints.get(p, PLOT_COLOUR)
		m.albedo_color = c
		m.emission_enabled = tints.has(p)
		m.emission = c * 0.35
	for i in _slot_mats.size():
		var id: int = _order[i] if i < _order.size() else -1
		var m: StandardMaterial3D = _slot_mats[i]
		var c: Color = unit_tints.get(id, SLOT_COLOUR)
		m.albedo_color = c
		m.emission_enabled = unit_tints.has(id)
		m.emission = c * 0.45


# -- Pointing ------------------------------------------------------------------------------------------------

## What is under the screen point, for what is wanted ("tile": a plot by the ground; "building": a building's
## block, else the plot; "unit": a unit in the yard; "any": a unit, a building or a plot):
## {"plot": Vector2i or NOWHERE, "unit": id or -1}.
func pick(cam: Camera3D, at: Vector2, want := "any") -> Dictionary:
	var out := {"plot": NOWHERE, "unit": -1}
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
			var r := maxf(14.0, sp.distance_to(cam.unproject_position(c + cam.global_basis.x * edge * 0.75)))
			var d := sp.distance_to(at)
			if d <= r and d < best:
				best = d
				out.unit = id
		if out.unit >= 0 or want == "unit":
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
