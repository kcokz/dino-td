class_name HomeView
extends Node3D
## The homeland on screen (GAME-DESIGN 17, 19): its plots on the ground of the place the ark has landed in -- the
## battle line's two rows on top, their earth warmer, a low strip between them and the rest; the special ground behind
## (a pond, an old tree, a vein of ore, a pool of lava) as it is -- a block for each building, taller or bigger for each
## level, a nest's affixes as little blocks on its roof, a crest of the new species' colour when they make one, a gold
## band for each time it was made elite; the wonder, once built, beside the homeland. To the south the yard, laid out
## as the battle line: this round's army stands there as it will stand in battle, each unit hatched from its nest's door,
## gone with the battle. When a place is held the ark comes down: what is packed rises into it, the rest is left; in the
## next place it sets down what it brings.

const TILE := 4.0
const PLOT := 3.6
const PLOT_TOP := 0.15
const YARD_Z := 11.0              # where the yard's front row stands...
const YARD_ROW := 1.7             # ...and the row behind it, this much further south
const YARD_SPREAD := 1.05         # between a nest's units side by side
const NOWHERE := Vector2i(-1, -1)
const WONDER_AT := Vector3(-17.0, 0.0, 2.0)  # beside the homeland, west of the rows behind the battle line
const ELITE_GOLD := Color(1.0, 0.8, 0.25)
const ARK_AT := Vector3(0, 8.5, 2.0)    # where the ark hangs over the homeland while it loads and unloads

var home: Home
var tags: Tags
var tints := {}                   # plot -> Color, lit by Game (where a good taken up can go)
var _plot_mats := {}              # plot -> StandardMaterial3D
var _ground := {}                 # plot -> Node3D: what stands on special ground
var _buildings := {}              # plot -> {node, look}
var _units := {}                  # army unit id -> Node3D
var _order: Array = []            # army unit ids, as they stand in the yard
var _ark: Node3D
var _wonder: Node3D


func setup(p_home: Home) -> void:
	home = p_home
	for y in Home.ROWS:
		for x in Home.COLS:
			var p := Vector2i(x, y)
			var slab := Blocks.box(Vector3(PLOT, 0.1, PLOT), Color.WHITE, plot_pos(p) + Vector3(0, PLOT_TOP - 0.05, 0))
			var m := StandardMaterial3D.new()
			m.roughness = 0.9
			slab.material_override = m
			_plot_mats[p] = m
			add_child(slab)
	# A fence along the yard's north side; a low strip where the battle line ends.
	add_child(Blocks.box(Vector3(Home.COLS * TILE + 1.0, 0.5, 0.12), Color(0.45, 0.33, 0.2), Vector3(0, 0.3, YARD_Z - 1.3)))
	var line_z := plot_pos(Vector2i(0, Content.FRONT_ROWS)).z - TILE * 0.5
	add_child(Blocks.box(Vector3(Home.COLS * TILE, 0.12, 0.3), Color(0.24, 0.18, 0.13), Vector3(0, PLOT_TOP + 0.02, line_z)))
	_ark = _make_ark()
	_ark.visible = false
	add_child(_ark)
	lay_ground()
	refresh_buildings(false)
	show_wonder(false)


static func plot_pos(p: Vector2i) -> Vector3:
	return Vector3((p.x - (Home.COLS - 1) * 0.5) * TILE, 0.0, (p.y - (Home.ROWS - 1) * 0.5) * TILE)


## Where unit u (Home.army's) stands in the yard: the yard laid out as the battle line -- each nest's units in its
## column, the front row's nearest the homeland, a nest's units side by side, more behind them when there are many.
static func yard_pos(u: Dictionary) -> Vector3:
	var n := mini(int(u.get("of", 1)), 3)
	var slot := int(u.get("slot", 0))
	var x := (float(u.get("lane", 0.0)) - (Home.COLS - 1) * 0.5) * TILE + ((slot % 3) - (n - 1) * 0.5) * YARD_SPREAD
	var z := YARD_Z + float(u.get("row", 0)) * YARD_ROW + (slot / 3) * 0.7
	return Vector3(x, World.GROUND_TOP, z)


static func plot_at(w: Vector3) -> Vector2i:
	var x := roundi(w.x / TILE + (Home.COLS - 1) * 0.5)
	var y := roundi(w.z / TILE + (Home.ROWS - 1) * 0.5)
	if x < 0 or x >= Home.COLS or y < 0 or y >= Home.ROWS:
		return NOWHERE
	var c := plot_pos(Vector2i(x, y))
	if absf(w.x - c.x) > TILE * 0.5 or absf(w.z - c.z) > TILE * 0.5:
		return NOWHERE
	return Vector2i(x, y)


## The top of the building at p (where words go over it) -- or of the tree standing there.
func top(p: Vector2i) -> Vector3:
	var h := 0.6
	if _buildings.has(p):
		h = float(_buildings[p].node.get_meta("height", 1.5))
	elif home.terrain.get(p, "") == "tree":
		h = 5.0
	return plot_pos(p) + Vector3(0, PLOT_TOP + h, 0)


func unit_node(id: String) -> Node3D:
	return _units.get(id)


# -- The ground -------------------------------------------------------------------------------------------------

## A plot's own colour: its special ground's, or the place's tilled earth -- warmer on the battle line.
func plot_colour(p: Vector2i) -> Color:
	var t: String = home.terrain.get(p, "")
	if t != "":
		return Content.TERRAIN[t].color
	var earth := (Content.LEVELS[home.region].ground as Color).lightened(0.22)
	return earth.lerp(Color(0.66, 0.42, 0.3), 0.4) if Home.front(p) else earth


## The ground laid for the place the ark is in: each plot its colour, the special ones dressed -- water and stones in
## a pond, a great tree, nuggets in a vein of ore, a crust on the lava.
func lay_ground() -> void:
	for n in _ground.values():
		n.queue_free()
	_ground.clear()
	for p in _plot_mats:
		var t: String = home.terrain.get(p, "")
		if t == "":
			continue
		var node := Node3D.new()
		node.position = plot_pos(p) + Vector3(0, PLOT_TOP, 0)
		var col: Color = Content.TERRAIN[t].color
		var k: int = p.x * 7 + p.y * 3
		match t:
			"pond":
				var water := Blocks.box(Vector3(2.7, 0.04, 2.7), col, Vector3(0, 0.02, 0))
				water.material_override = Blocks.glow(col, 0.3)
				node.add_child(water)
				for i in 6:
					var a: float = TAU * i / 6.0 + k
					node.add_child(Blocks.box(Vector3(0.45, 0.22, 0.4), Color(0.55, 0.55, 0.52), Vector3(cos(a) * 1.65, 0.1, sin(a) * 1.65)))
			"tree":
				node.add_child(Blocks.box(Vector3(0.75, 3.4, 0.75), Color(0.36, 0.25, 0.16), Vector3(0, 1.7, 0)))
				var top1 := Blocks.box(Vector3(3.2, 1.4, 3.2), Color(0.17, 0.38, 0.16), Vector3(0, 3.7, 0))
				top1.rotation.y = 0.3 + k
				node.add_child(top1)
				var top2 := Blocks.box(Vector3(2.1, 1.0, 2.1), Color(0.24, 0.48, 0.2), Vector3(0.2, 4.8, -0.1))
				top2.rotation.y = 0.8 + k
				node.add_child(top2)
				for side in [-1.0, 1.0]:
					var foot := Blocks.box(Vector3(1.0, 0.3, 0.3), Color(0.36, 0.25, 0.16), Vector3(side * 0.6, 0.15, 0.2 * side))
					foot.rotation.y = side * 0.6
					node.add_child(foot)
			"ore":
				for i in 5:
					var a: float = TAU * i / 5.0 + k * 0.7
					var r := 0.7 + 0.5 * float((k + i) % 3) / 2.0
					var nug := Blocks.box(Vector3(0.38, 0.3, 0.32), Color(1.0, 0.78, 0.25), Vector3(cos(a) * r, 0.1, sin(a) * r))
					nug.material_override = Blocks.glow(Color(1.0, 0.78, 0.25), 0.5)
					nug.rotation.y = a
					node.add_child(nug)
				node.add_child(Blocks.box(Vector3(0.9, 0.4, 0.7), Color(0.3, 0.26, 0.22), Vector3(-0.9, 0.18, 0.9)))
			"lava":
				for i in 3:
					var crust := Blocks.box(Vector3(0.9, 0.12, 0.7), Color(0.16, 0.12, 0.1), Vector3(-1.0 + i * 1.0, 0.06, (i - 1) * 0.8 * (1 if k % 2 == 0 else -1)))
					crust.rotation.y = i + k
					node.add_child(crust)
		add_child(node)
		_ground[p] = node
	paint()


## Lights the plots in tints; the rest their own colour (lava glows of itself).
func paint() -> void:
	for p in _plot_mats:
		var m: StandardMaterial3D = _plot_mats[p]
		var base := plot_colour(p)
		var lit := tints.has(p)
		m.albedo_color = tints[p] if lit else base
		m.emission_enabled = lit or home.terrain.get(p, "") == "lava"
		m.emission = (tints[p] as Color) * 0.35 if lit else base
		m.emission_energy_multiplier = 1.0 if lit else 0.55


# -- Buildings -------------------------------------------------------------------------------------------------

## A block for each building there is, made again where one has been built, raised or affixed (rising up).
func refresh_buildings(pop := true) -> void:
	for p in _buildings.keys():
		if not home.buildings.has(p):
			_buildings[p].node.queue_free()
			_buildings.erase(p)
	for p in home.buildings:
		var b: Dictionary = home.buildings[p]
		var look := "%s/%d/%s/%s" % [b.kind, b.level, ",".join(b.affixes), ",".join(b.path)]
		if _buildings.has(p) and _buildings[p].look == look:
			continue
		var grow := 0.05
		if _buildings.has(p):
			grow = 0.6 if _buildings[p].look.get_slice("/", 0) == b.kind else 0.05
			_buildings[p].node.queue_free()
		var node := _building(b)
		node.position = plot_pos(p) + Vector3(0, PLOT_TOP, 0)
		add_child(node)
		_buildings[p] = {"node": node, "look": look}
		if pop:
			node.scale = Vector3(1, grow, 1)
			var tw := node.create_tween()
			tw.tween_property(node, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _building(b: Dictionary) -> Node3D:
	var kind: String = b.kind
	var lv := int(b.level)
	var affixes: Array = b.affixes
	var root := Node3D.new()
	var info: Dictionary = Content.BUILDINGS[kind]
	var c: Color = info.color
	var height := 0.0
	if info.has("nest"):
		# A tier for each level; a door; a gold band at its front corner for each time it was made elite; its affixes
		# on the roof; a crest when they make a new species.
		for i in lv:
			var w := 3.0 - i * 0.6
			var h := 1.1 if i == 0 else 0.7
			root.add_child(Blocks.box(Vector3(w, h, w), c.lightened(i * 0.08), Vector3(0, height + h * 0.5, 0)))
			root.add_child(Blocks.box(Vector3(w + 0.04, 0.08, w + 0.04), c.darkened(0.35), Vector3(0, height + h - 0.04, 0)))
			height += h
		root.add_child(Blocks.box(Vector3(0.9, 0.8, 0.08), Color(0.12, 0.09, 0.07), Vector3(0, 0.4, 1.52)))
		for k in b.path.count("elite"):
			var band := Blocks.cylinder(0.42, 0.2, ELITE_GOLD, Vector3(-1.05, 1.2 + k * 0.32, 1.05))
			band.material_override = Blocks.glow(ELITE_GOLD, 0.6)
			root.add_child(band)
			for s in 4:
				var a := TAU * s / 4.0 + 0.4
				root.add_child(Blocks.box(Vector3(0.1, 0.22, 0.1), ELITE_GOLD, Vector3(-1.05 + cos(a) * 0.36, 1.4 + k * 0.32,
					1.05 + sin(a) * 0.36)))
		for i in affixes.size():
			var ac: Color = Content.AFFIXES[affixes[i]].color
			var cube := Blocks.box(Vector3(0.42, 0.42, 0.42), ac, Vector3(-0.55 + (i % 3) * 0.55, height + 0.21, 0.4 - (i / 3) * 0.55))
			if affixes[i] in ["plasma", "flame"]:
				cube.material_override = Blocks.glow(ac)
			root.add_child(cube)
		if not affixes.is_empty():
			height += 0.42
		var sp := Content.species(info.nest, affixes)
		if not sp.used.is_empty():
			var sc: Color = Content.UNITS[sp.kind].color
			root.add_child(Blocks.box(Vector3(0.12, 0.9, 0.12), Color(0.2, 0.16, 0.12), Vector3(0.95, height + 0.45, -0.7)))
			var crest := Blocks.ball(0.42, sc, Vector3(0.95, height + 1.1, -0.7))
			crest.material_override = Blocks.glow(sc, 1.1)
			root.add_child(crest)
			height += 0.6
	else:
		match kind:
			"pool", "spore_pool":
				var rim := 0.35 + 0.08 * lv
				root.add_child(Blocks.box(Vector3(3.2, rim, 3.2), c.darkened(0.45), Vector3(0, rim * 0.5, 0)))
				var water := Blocks.box(Vector3(2.8, 0.06, 2.8), c, Vector3(0, rim + 0.01, 0))
				water.material_override = Blocks.glow(c, 0.35)
				root.add_child(water)
				height = rim
				if kind == "spore_pool":
					for k in 2 + lv:
						root.add_child(Blocks.ball(0.32, Color(0.78, 0.82, 0.38), Vector3(-0.9 + k * 1.8 / (1 + lv), rim + 0.2,
							0.5 if k % 2 == 0 else -0.5)))
					height = rim + 0.5
			"horde_totem":
				var tall := 2.2 + 0.4 * lv
				root.add_child(Blocks.box(Vector3(1.6, 0.3, 1.6), c.darkened(0.45), Vector3(0, 0.15, 0)))
				root.add_child(Blocks.box(Vector3(0.35, tall, 0.35), Color(0.35, 0.25, 0.18), Vector3(0, tall * 0.5, 0)))
				for k in 1 + lv:
					root.add_child(Blocks.box(Vector3(0.6, 0.45, 0.55), Color(0.9, 0.85, 0.75), Vector3(0, 0.7 + k * 0.62, 0.05)))
				root.add_child(Blocks.box(Vector3(1.0, 0.7, 0.06), c, Vector3(0.55, tall - 0.4, 0)))
				height = tall
			"gene_bank":
				var tall := 1.5 + 0.3 * lv
				root.add_child(Blocks.box(Vector3(2.0, 0.35, 2.0), c.darkened(0.45), Vector3(0, 0.175, 0)))
				var glass := Blocks.cylinder(0.75, tall, c, Vector3(0, 0.35 + tall * 0.5, 0))
				glass.material_override = Blocks.glow(c, 0.5)
				root.add_child(glass)
				for k in 3 + 2 * lv:
					root.add_child(Blocks.ball(0.13, Color(0.95, 1.0, 0.95), Vector3(cos(k * 1.3) * 0.82, 0.6 + k * 0.28, sin(k * 1.3) * 0.82)))
				height = 0.35 + tall
			"vault":
				var h := 1.1 + 0.15 * lv
				root.add_child(Blocks.box(Vector3(2.6, h, 2.2), Color(0.4, 0.38, 0.36), Vector3(0, h * 0.5, 0)))
				var door := Blocks.cylinder(0.55, 0.1, c, Vector3(0, h * 0.5, 1.12))
				door.rotation.x = PI * 0.5
				door.material_override = Blocks.glow(c, 0.6)
				root.add_child(door)
				for k in lv:
					root.add_child(Blocks.cylinder(0.3, 0.12, c, Vector3(-0.6 + k * 0.6, h + 0.06, 0)))
				height = h + 0.2
			"market":
				root.add_child(Blocks.box(Vector3(2.6, 0.8, 1.4), Color(0.5, 0.36, 0.22), Vector3(0, 0.4, 0.2)))
				for sx in [-1.2, 1.2]:
					for sz in [-0.5, 0.9]:
						root.add_child(Blocks.box(Vector3(0.12, 1.9, 0.12), Color(0.4, 0.3, 0.2), Vector3(sx, 0.95, sz)))
				for k in 4:
					root.add_child(Blocks.box(Vector3(0.7, 0.12, 1.8), c if k % 2 == 0 else Color(0.95, 0.92, 0.85),
						Vector3(-1.05 + k * 0.7, 1.95 + 0.1 * lv, 0.2)))
				for k in lv + 1:
					root.add_child(Blocks.box(Vector3(0.35, 0.3, 0.35), [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9),
						Color(0.95, 0.8, 0.3)][k % 3], Vector3(-0.8 + k * 0.55, 0.95, 0.2)))
				height = 2.2
			"champion_hall":
				var h := 1.2 + 0.2 * lv
				root.add_child(Blocks.box(Vector3(2.8, 0.25, 2.4), Color(0.85, 0.82, 0.78), Vector3(0, 0.125, 0)))
				for sx in [-1.1, -0.37, 0.37, 1.1]:
					root.add_child(Blocks.cylinder(0.16, h, Color(0.92, 0.9, 0.86), Vector3(sx, 0.25 + h * 0.5, 0.9)))
				root.add_child(Blocks.box(Vector3(2.8, h, 1.4), c.darkened(0.2), Vector3(0, 0.25 + h * 0.5, -0.4)))
				root.add_child(Blocks.box(Vector3(3.0, 0.3, 2.6), c, Vector3(0, 0.25 + h + 0.15, 0)))
				var crown := Blocks.cylinder(0.45, 0.3, ELITE_GOLD, Vector3(0, 0.25 + h + 0.45, 0))
				crown.material_override = Blocks.glow(ELITE_GOLD, 0.7)
				root.add_child(crown)
				height = 0.25 + h + 0.7
			"watchtower":
				var tall := 2.6 + 0.5 * lv
				root.add_child(Blocks.box(Vector3(0.9, tall, 0.9), Color(0.45, 0.4, 0.36), Vector3(0, tall * 0.5, 0)))
				root.add_child(Blocks.box(Vector3(1.5, 0.7, 1.5), c, Vector3(0, tall + 0.35, 0)))
				root.add_child(Blocks.cylinder(1.0, 0.6, c.darkened(0.3), Vector3(0, tall + 1.0, 0), 0.0))
				height = tall + 1.3
			"vanguard":
				var h := 1.4 + 0.25 * lv
				root.add_child(Blocks.cylinder(1.35, h, c, Vector3(0, h * 0.5, 0), 0.0))
				for k in 1 + lv:
					root.add_child(Blocks.box(Vector3(0.5, 0.7, 0.08), Color(0.62, 0.64, 0.7), Vector3(-0.75 + k * 0.5, 0.4, 1.25)))
				height = h
			"sampler":
				var tall := 1.6 + 0.3 * lv
				root.add_child(Blocks.box(Vector3(1.8, 0.5, 1.8), c.darkened(0.3), Vector3(0, 0.25, 0)))
				root.add_child(Blocks.cylinder(0.32, tall, c, Vector3(0, tall * 0.5, 0)))
				var dish := Blocks.cylinder(0.85, 0.1, c.lightened(0.3), Vector3(0, tall + 0.1, 0.1))
				dish.rotation.x = 0.5
				root.add_child(dish)
				height = tall + 0.4
			"mine":
				var h := 1.0 + 0.2 * lv
				root.add_child(Blocks.box(Vector3(2.4, h, 2.4), Color(0.3, 0.3, 0.32), Vector3(0, h * 0.5, 0)))
				var core := Blocks.cylinder(0.55, 0.8, c, Vector3(0, h + 0.4, 0))
				core.material_override = Blocks.glow(c, 1.4)
				root.add_child(core)
				height = h + 0.8
			"forge":
				var h := 1.2 + 0.2 * lv
				root.add_child(Blocks.box(Vector3(2.6, h, 2.2), Color(0.28, 0.24, 0.22), Vector3(0, h * 0.5, 0)))
				var mouth := Blocks.box(Vector3(1.0, 0.6, 0.08), Color(1.0, 0.5, 0.15), Vector3(0, 0.45, 1.12))
				mouth.material_override = Blocks.glow(Color(1.0, 0.5, 0.15), 2.0)
				root.add_child(mouth)
				var chimney := 1.0 + 0.3 * lv
				root.add_child(Blocks.box(Vector3(0.6, chimney, 0.6), c.darkened(0.3), Vector3(0.8, h + chimney * 0.5, -0.5)))
				height = h + chimney
			"stabilizer":
				var tall := 1.8 + 0.25 * lv
				root.add_child(Blocks.box(Vector3(1.4, 0.4, 1.4), c.darkened(0.4), Vector3(0, 0.2, 0)))
				root.add_child(Blocks.cylinder(0.28, tall, c.darkened(0.15), Vector3(0, tall * 0.5, 0)))
				for k in 2:
					var ring := Blocks.cylinder(0.8, 0.08, c, Vector3(0, tall * (0.55 + 0.3 * k), 0))
					ring.material_override = Blocks.glow(c, 0.9)
					root.add_child(ring)
				height = tall
	root.set_meta("height", height)
	return root


# -- The wonder -----------------------------------------------------------------------------------------------------

## The wonder built, standing beside the homeland (rising up when just built).
func show_wonder(pop := true) -> void:
	if _wonder:
		_wonder.queue_free()
		_wonder = null
	if home.wonder == "":
		return
	var c: Color = Content.WONDERS[home.wonder].color
	var root := Node3D.new()
	root.add_child(Blocks.box(Vector3(6.0, 0.4, 6.0), Color(0.55, 0.52, 0.48), Vector3(0, 0.2, 0)))
	match home.wonder:
		"brood":
			root.add_child(Blocks.dome(2.6, c, Vector3(0, 0.4, 0)))
			for k in 3:
				root.add_child(Blocks.dome(0.9, c.lightened(0.2), Vector3(cos(k * 2.1) * 2.3, 0.4, sin(k * 2.1) * 2.3)))
		"gold_city":
			for k in 3:
				var h: float = [4.0, 5.5, 3.5][k]
				var tower := Blocks.box(Vector3(1.4, h, 1.4), c, Vector3(-1.8 + k * 1.8, 0.4 + h * 0.5, 0))
				root.add_child(tower)
				root.add_child(Blocks.cylinder(0.9, 1.0, c.lightened(0.2), Vector3(-1.8 + k * 1.8, 0.4 + h + 0.5, 0), 0.0))
		"evo_tower":
			for k in 6:
				var ring := Blocks.cylinder(1.4 - k * 0.15, 0.9, c if k % 2 == 0 else c.darkened(0.3), Vector3(0, 0.85 + k * 0.9, 0))
				ring.material_override = Blocks.glow(c, 0.4 + 0.15 * k) if k % 2 == 0 else Blocks.mat(c.darkened(0.3))
				root.add_child(ring)
		"banner":
			root.add_child(Blocks.box(Vector3(0.35, 7.0, 0.35), Color(0.35, 0.28, 0.2), Vector3(0, 3.9, 0)))
			root.add_child(Blocks.box(Vector3(3.0, 2.0, 0.08), c, Vector3(1.65, 6.2, 0)))
		"titan":
			for sx in [-2.4, 2.4]:
				for sz in [-2.4, 2.4]:
					root.add_child(Blocks.box(Vector3(0.3, 4.2, 0.3), Color(0.3, 0.28, 0.28), Vector3(sx, 2.5, sz)))
			root.add_child(Blocks.box(Vector3(5.1, 0.3, 5.1), Color(0.3, 0.28, 0.28), Vector3(0, 4.6, 0)))
			root.add_child(Blocks.box(Vector3(2.6, 2.6, 2.6), c, Vector3(0, 1.7, 0)))
	root.position = WONDER_AT
	add_child(root)
	_wonder = root
	if pop:
		root.scale = Vector3(1, 0.05, 1)
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -- The ark --------------------------------------------------------------------------------------------------------

## The gene ark: a long hull, a band of light, the vault on top, an engine at each end.
func _make_ark() -> Node3D:
	var ark := Node3D.new()
	ark.add_child(Blocks.box(Vector3(12, 2.2, 5), Color(0.55, 0.58, 0.62), Vector3.ZERO))
	ark.add_child(Blocks.box(Vector3(9, 1.2, 4), Color(0.42, 0.45, 0.5), Vector3(0, 1.6, 0)))
	var band := Blocks.box(Vector3(12.1, 0.25, 5.1), Color(0.4, 0.95, 0.8), Vector3(0, -0.3, 0))
	band.material_override = Blocks.glow(Color(0.4, 0.95, 0.8), 1.5)
	ark.add_child(band)
	var vault := Blocks.dome(1.6, Color(0.5, 0.9, 0.8), Vector3(0, 2.2, 0))
	vault.material_override = Blocks.glow(Color(0.5, 0.9, 0.8), 0.6)
	ark.add_child(vault)
	for sx in [-1.0, 1.0]:
		ark.add_child(Blocks.cylinder(0.8, 1.2, Color(0.3, 0.3, 0.33), Vector3(sx * 4.5, -1.6, 0)))
		var jet := Blocks.cylinder(0.6, 1.0, Color(0.5, 0.85, 1.0), Vector3(sx * 4.5, -2.6, 0), 0.0)
		jet.rotation.x = PI
		jet.material_override = Blocks.glow(Color(0.5, 0.85, 1.0), 2.5)
		ark.add_child(jet)
	return ark


## The ark comes down over the homeland.
func ark_down() -> void:
	_ark.visible = true
	_ark.position = Vector3(0, 60, -20)
	var tw := create_tween()
	tw.tween_property(_ark, "position", ARK_AT, 1.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished


## The ark goes up and away.
func ark_up() -> void:
	var tw := create_tween()
	tw.tween_property(_ark, "position", Vector3(0, 70, -40), 1.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await tw.finished
	_ark.visible = false


## Loading up: the buildings at `taken` rise into the ark; the rest are left behind -- they sink away.
func load_up(taken: Array) -> void:
	if _buildings.is_empty():
		return
	var tw := create_tween().set_parallel()
	var k := 0
	for p in _buildings:
		var node: Node3D = _buildings[p].node
		if p in taken:
			tw.tween_property(node, "position", _ark.position + Vector3(0, -1.0, 0), 0.9).set_delay(k * 0.15) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(node, "scale", Vector3.ONE * 0.15, 0.9).set_delay(k * 0.15)
			k += 1
		else:
			tw.tween_property(node, "scale", Vector3(1, 0.04, 1), 1.0).set_delay(0.4)
	await tw.finished
	for p in _buildings:
		_buildings[p].node.queue_free()
	_buildings.clear()


## Setting down: each building there is now drops from the ark to its plot.
func set_down() -> void:
	refresh_buildings(false)
	if _buildings.is_empty():
		return
	var tw := create_tween().set_parallel()
	var k := 0
	for p in _buildings:
		var node: Node3D = _buildings[p].node
		var to := node.position
		node.position = _ark.position + Vector3(0, -1.0, 0)
		node.scale = Vector3.ONE * 0.15
		tw.tween_property(node, "position", to, 0.8).set_delay(k * 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_delay(k * 0.25)
		k += 1
	await tw.finished


# -- The yard ------------------------------------------------------------------------------------------------------

## The yard shows `army` (Home.army) where each unit will stand in battle: a unit new to it hatches from its nest's
## door and hops to its place, one by one; one no longer in it shrinks away; one that looks different now is made
## again; the rest walk to their places.
func sync_army(army: Array, hatch := true) -> void:
	var ids := {}
	var k := 0
	for i in army.size():
		var u: Dictionary = army[i]
		ids[u.id] = true
		var look := _look(u)
		var to := yard_pos(u)
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
				_hatch(n, to, k * 0.07)
				k += 1
				continue
			n.position = to
		if n.position.distance_to(to) > 0.05:
			var tw := n.create_tween()
			tw.tween_property(n, "position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	return "%s/%s/%d" % [u.kind, ",".join(u.affixes), int(u.get("elite", 0))]


func _new_unit(u: Dictionary, look: String) -> Node3D:
	var s := Content.unit_stats(u)
	var n := Blocks.creature(float(s.size), Content.UNITS[u.kind].color, false, u.affixes, u.kind, int(u.get("elite", 0)))
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