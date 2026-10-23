class_name HomeView
extends Node3D
## The homeland on screen (GAME-DESIGN 17, 19, 24): its plots on the ground of the place it stands in -- the battle
## line's two rows on top, their earth warmer, a low strip between them and the rest; the special ground behind (a pond,
## an old tree, a vein of ore, a pool of lava) as it is -- each building made after its card's painting (Kit), bigger
## and more to it at each level, a nest's affixes as glowing samples before it, a crest of the new species' colour when
## they make one, a gold ring for each time it was made elite. To the south the yard, laid out as the battle line: this
## round's army stands there as it will stand in battle, each unit hatched from its nest's door, gone with the battle.
## West of it all the star dinosaurs' pens (GAME-DESIGN 24), each star standing in its own -- asleep while it goes
## without (none while the stars are put away, Content.STARS_ON). Where a building works (GAME-DESIGN 28) glows blue
## over its plots while it is placed or pointed at.

const TILE := 4.0
const PLOT := 3.6
const PLOT_TOP := 0.15
const YARD_Z := 11.0              # where the yard's front row stands...
const YARD_ROW := 2.4             # ...and the row behind it, this much further south
const YARD_SPREAD := 1.05         # between a nest's units side by side
const YARD_TURN := 0.75           # a dinosaur in the yard looks south-east: at the camera, its side showing
const NOWHERE := Vector2i(-1, -1)
const ELITE_GOLD := Color(1.0, 0.8, 0.25)
const PENNANT := Color(1.0, 0.93, 0.72)  # flown over a nest whose gift works where it stands
## Where a building works (Game: Home.reach), lit blue (the player, 2026-10-22: "摆放的时候要有蓝色的hover来表示建筑作用
## 范围"): light laid over each plot of it -- a bright edge along its frame, its corners brighter still, a faint wash
## inside, breathing a little -- light, not a colour, so that it reads apart from a pond's water.
const REACH_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.22, 0.52, 1.0, 1.0);
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = max(d.x, d.y);
	float edge = smoothstep(0.82, 0.95, e) * (1.0 - smoothstep(0.99, 1.0, e));
	float corner = smoothstep(0.7, 0.95, min(d.x, d.y)) * edge;
	float beat = 0.78 + 0.22 * sin(TIME * 3.2);
	ALBEDO = tint.rgb * (0.12 + edge * 1.5 + corner * 1.2) * beat;
}
"""
## The star dinosaurs' pens, a column west of the homeland (Content.PENS of them), the first nearest the battle line.
const PEN_AT := [Vector3(-18.5, 0.0, -4.0), Vector3(-18.5, 0.0, 0.2), Vector3(-18.5, 0.0, 4.4), Vector3(-18.5, 0.0, 8.6),
	Vector3(-18.5, 0.0, 12.8)]
const PEN := 3.4                  # a pen's side
## How long each star stands in its pen (metres, nose to tail): the small ones small, the great ones filling it.
const STAR_LENGTH := {"mother": 2.3, "doctor": 1.7, "shield": 1.8, "saver": 1.6, "belly": 3.0, "tri": 2.4, "scar": 2.0,
	"fisher": 2.4, "bounty": 2.3, "horn": 2.3, "spitter": 1.9, "oldking": 2.7, "sickle": 2.2, "neck": 3.1, "queen": 2.7,
	"firstbird": 1.7, "warlord": 3.0, "titan": 3.2}
## Until each star has a model of its own (the shared library's species made Nintendo-style), the one of ours it
## looks most like stands in for it, banded in its own colours.
const STAND_IN := {"mother": "white", "doctor": "mutant", "shield": "green", "saver": "white", "belly": "thunder",
	"tri": "green", "scar": "red", "fisher": "green", "bounty": "gold", "horn": "white", "spitter": "blue",
	"oldking": "titan", "sickle": "miasma", "neck": "thunder", "queen": "white", "firstbird": "mutant", "warlord": "titan",
	"titan": "thunder"}

var home: Home
var tags: Tags
var tints := {}                   # plot -> Color, lit by Game (where a good taken up can go)
var reach: Array = []             # the plots lit blue by Game: where the building placed or pointed at works
var _plot_mats := {}              # plot -> StandardMaterial3D
var _reach_marks := {}            # plot -> MeshInstance3D: its blue glow
var _ground := {}                 # plot -> Node3D: what stands on special ground
var _buildings := {}              # plot -> {node, look}
var _units := {}                  # army unit id -> Node3D
var _order: Array = []            # army unit ids, as they stand in the yard
var _pens: Array = []             # Node3D, a pen each (its star under it, named "Star")
var _pens_for := ""


func setup(p_home: Home) -> void:
	home = p_home
	# Each plot a raised bed (the player chose a Zelda-like homeland, 2026-10-20): a frame of planks, a post at each
	# corner, earth inside it, grained as the ground is -- the frames all one mesh.
	var frames := Kit.Maker.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var plank := Color(0.56, 0.4, 0.26)
	for y in Home.ROWS:
		for x in Home.COLS:
			var p := Vector2i(x, y)
			var slab := MeshInstance3D.new()
			slab.mesh = Blocks.rounded(Vector3(PLOT - 0.2, 0.2, PLOT - 0.2))
			slab.position = plot_pos(p) + Vector3(0, PLOT_TOP - 0.1, 0)
			var m := Ground.earth_material(Color.WHITE)
			slab.material_override = m
			_plot_mats[p] = m
			add_child(slab)
			var c := plot_pos(p)
			for side in 4:
				var turn := side * PI * 0.5
				var shade := plank.lerp(Color(0.46, 0.34, 0.22), rng.randf())
				frames.put(Kit.box(Vector3(PLOT, 0.2, 0.14)), Transform3D(Basis(Vector3.UP, turn),
					c + Vector3(0, PLOT_TOP - 0.02, PLOT * 0.5 - 0.05).rotated(Vector3.UP, turn)), Kit.paint(), shade)
				frames.put(Kit.box(Vector3(0.2, 0.3, 0.2)), Transform3D(Basis(Vector3.UP, turn),
					c + Vector3(PLOT * 0.5 - 0.06, PLOT_TOP + 0.02, PLOT * 0.5 - 0.06).rotated(Vector3.UP, turn)), Kit.paint(), shade.darkened(0.12))
	var frame_node := MeshInstance3D.new()
	frame_node.mesh = frames.mesh()
	add_child(frame_node)
	var glow := ShaderMaterial.new()
	glow.shader = Shader.new()
	glow.shader.code = REACH_SHADER
	for p in _plot_mats:
		var mark := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(PLOT, PLOT)
		mark.mesh = plane
		mark.material_override = glow
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.position = plot_pos(p) + Vector3(0, PLOT_TOP + 0.11, 0)
		mark.visible = false
		add_child(mark)
		_reach_marks[p] = mark
	# A post-and-rail fence along the yard's north side; a log lying where the battle line ends.
	var fence_z := YARD_Z - 1.3
	var span := Home.COLS * TILE + 1.0
	var wood := Color(0.42, 0.31, 0.2)
	for i in int(span / 2.0) + 1:
		var x := -span * 0.5 + i * 2.0
		add_child(Blocks.cylinder(0.08, 0.7, wood.darkened(0.1), Vector3(x, 0.35, fence_z), 0.07))
	for h in [0.28, 0.55]:
		add_child(Blocks.box(Vector3(span, 0.07, 0.07), wood, Vector3(0, h, fence_z)))
	var line_z := plot_pos(Vector2i(0, Content.FRONT_ROWS)).z - TILE * 0.5
	var log_piece := Blocks.cylinder(0.14, Home.COLS * TILE, Color(0.36, 0.26, 0.17), Vector3(0, PLOT_TOP + 0.04, line_z), 0.13)
	log_piece.rotation.z = PI * 0.5
	add_child(log_piece)
	for k in Content.PENS if Content.STARS_ON else 0:
		var pen := _make_pen()
		pen.position = PEN_AT[k]
		add_child(pen)
		_pens.append(pen)
	lay_ground()
	refresh_buildings(false)
	refresh_pens()


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
	else:
		h = {"tree": 5.0, "toadstool": 2.4, "glacier": 2.2, "ruin": 2.6, "wreck": 1.6}.get(home.terrain.get(p, ""), h)
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
## a pond (reeds in a mire, a palm by an oasis, shells in a tide pool), a great tree, toadstools, a fossil in the ice,
## broken pillars; nuggets in a vein of ore, crystals in one of ice; a crust on the lava, a wreck's ribs.
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
			"pond", "mire", "oasis", "tidepool":
				var water := Blocks.box(Vector3(2.7, 0.04, 2.7), col, Vector3(0, 0.02, 0))
				water.material_override = Blocks.glow(col, 0.3)
				node.add_child(water)
				var stone := {"pond": Color(0.55, 0.55, 0.52), "mire": Color(0.28, 0.26, 0.2), "oasis": Color(0.8, 0.7, 0.5),
					"tidepool": Color(0.92, 0.88, 0.8)}[t] as Color
				for i in 6:
					var a: float = TAU * i / 6.0 + k
					node.add_child(Blocks.rock(Vector3(0.6, 0.36, 0.5), stone, Vector3(cos(a) * 1.65, -0.04, sin(a) * 1.65), a))
				if t == "mire":
					for i in 7:
						var a: float = TAU * i / 7.0 + k * 0.4
						node.add_child(Blocks.cone(0.14, 0.9 + (i % 3) * 0.35, Color(0.42, 0.46, 0.22), Vector3(cos(a) * 1.2, 0, sin(a) * 1.2)))
				elif t == "oasis":
					var palm := Blocks.palm(2.8, Color(0.5, 0.36, 0.2), Color(0.25, 0.55, 0.22), 0.6, 2.3)
					palm.position = Vector3(1.3, 0, -1.3)
					palm.scale = Vector3.ONE * 0.8
					node.add_child(palm)
				elif t == "tidepool":
					for i in 3:
						node.add_child(Blocks.ball(0.18, Color(1.0, 0.75, 0.7), Vector3(-0.8 + i * 0.8, 0.08, 0.4 * (i % 2))))
			"toadstool":
				for i in 3:
					var at := Vector3(-0.9 + i * 0.9, 0, (i % 2) * 0.7 - 0.3)
					var tall := 0.8 + 0.5 * float((k + i) % 3)
					node.add_child(Blocks.box(Vector3(0.22, tall, 0.22), Color(0.92, 0.88, 0.8), at + Vector3(0, tall * 0.5, 0)))
					node.add_child(Blocks.dome(0.55 + i * 0.12, col, at + Vector3(0, tall, 0)))
			"glacier":
				# A great block of ice, crystals about it, the bones of something frozen in its face.
				var ice := Blocks.box(Vector3(2.6, 1.8, 2.2), col, Vector3(0, 0.9, 0))
				ice.material_override = Blocks.glow(col, 0.25)
				node.add_child(ice)
				for i in 4:
					var a: float = TAU * i / 4.0 + 0.6 + k
					node.add_child(Blocks.crystal(0.5, 1.2 + (i % 2) * 0.6, col.lightened(0.2), Vector3(cos(a) * 1.25, 0, sin(a) * 1.05),
						Vector2(sin(a) * 0.3, -cos(a) * 0.3), 0.3))
				node.add_child(Blocks.box(Vector3(1.4, 0.2, 0.3), Color(0.92, 0.9, 0.84), Vector3(0, 1.0, 1.12)))
				node.add_child(Blocks.box(Vector3(0.25, 0.6, 0.3), Color(0.92, 0.9, 0.84), Vector3(-0.5, 1.0, 1.12)))
			"ruin":
				for sx in [-0.9, 0.9]:
					var tall := 2.2 if sx < 0 else 1.4
					node.add_child(Blocks.cylinder(0.32, tall, col, Vector3(sx, tall * 0.5, 0)))
					node.add_child(Blocks.box(Vector3(0.8, 0.2, 0.8), col.darkened(0.1), Vector3(sx, 0.1, 0)))
				var lintel := Blocks.box(Vector3(2.4, 0.4, 0.7), col.darkened(0.1), Vector3(0.2, 0.2, 0.9))
				lintel.rotation.y = 0.3
				node.add_child(lintel)
			"ice_ore":
				for i in 6:
					var a: float = TAU * i / 6.0 + k * 0.7
					node.add_child(Blocks.crystal(0.34, 0.8 + (i % 3) * 0.35, Color(0.7, 0.88, 1.0), Vector3(cos(a) * 0.85, 0, sin(a) * 0.85),
						Vector2(sin(a) * 0.35, -cos(a) * 0.35), 0.6))
			"wreck":
				for i in 4:
					var rib := Blocks.box(Vector3(0.2, 1.1, 0.25), col, Vector3(-1.0 + i * 0.66, 0.5, 0.0))
					rib.rotation.z = 0.35 if i % 2 == 0 else -0.35
					node.add_child(rib)
				node.add_child(Blocks.box(Vector3(2.6, 0.25, 0.7), col.darkened(0.2), Vector3(0, 0.12, 0.6)))
				node.add_child(Blocks.box(Vector3(0.18, 1.6, 0.18), col.darkened(0.3), Vector3(0.3, 0.8, -0.6)))
			"tree":
				# An old tree: a broad crown on a thick trunk, its roots spread over the plot.
				var old := Blocks.tree(3.4, 3.6, Color(0.36, 0.25, 0.16), Color(0.2, 0.42, 0.18), 7 + k)
				old.rotation.y = 0.3 + k
				node.add_child(old)
				for i in 3:
					var a: float = TAU * i / 3.0 + 0.4 + k
					var root_arm := Blocks.blob(Vector3(1.1, 0.3, 0.36), Color(0.36, 0.25, 0.16), Vector3(cos(a) * 0.55, 0.06, sin(a) * 0.55))
					root_arm.rotation.y = -a
					node.add_child(root_arm)
			"ore":
				for i in 5:
					var a: float = TAU * i / 5.0 + k * 0.7
					var r := 0.7 + 0.5 * float((k + i) % 3) / 2.0
					var nug := Blocks.rock(Vector3(0.44, 0.36, 0.38), Color(1.0, 0.78, 0.25), Vector3(cos(a) * r, -0.02, sin(a) * r), a)
					nug.material_override = Blocks.glow(Color(1.0, 0.78, 0.25), 0.5)
					node.add_child(nug)
				node.add_child(Blocks.rock(Vector3(1.1, 0.6, 0.9), Color(0.3, 0.26, 0.22), Vector3(-0.9, 0, 0.9), 0.7))
			"lava":
				for i in 3:
					var crust := Blocks.box(Vector3(0.9, 0.12, 0.7), Color(0.16, 0.12, 0.1), Vector3(-1.0 + i * 1.0, 0.06, (i - 1) * 0.8 * (1 if k % 2 == 0 else -1)))
					crust.rotation.y = i + k
					node.add_child(crust)
		add_child(node)
		_ground[p] = node
	paint()


## Lights the plots in tints; the rest their own colour (lava glows of itself); the plots in reach glowing blue.
func paint() -> void:
	for p in _reach_marks:
		_reach_marks[p].visible = p in reach
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
		var lit := home.trait_on(p) and home.trait_of(p) in ["swarm", "guard", "cover", "alone"]
		var look := "%s/%d/%s/%s/%s" % [b.kind, b.level, ",".join(b.affixes), ",".join(b.path), lit]
		if _buildings.has(p) and _buildings[p].look == look:
			continue
		var grow := 0.05
		if _buildings.has(p):
			grow = 0.6 if _buildings[p].look.get_slice("/", 0) == b.kind else 0.05
			_buildings[p].node.queue_free()
		var node := _building(b, lit)
		node.position = plot_pos(p) + Vector3(0, PLOT_TOP, 0)
		add_child(node)
		_buildings[p] = {"node": node, "look": look}
		if pop:
			node.scale = Vector3(1, grow, 1)
			var tw := node.create_tween()
			tw.tween_property(node, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A building as its card's painting shows it (Kit), and on a nest what is its own: a gold ring round its foot for
## each time it was made elite; its affixes as glowing samples on little brass stands at its front corner; when they
## make a new species, a brass post with a globe of that species' colour; a pale pennant when its gift works where it
## stands (`lit`).
static func _building(b: Dictionary, lit := false) -> Node3D:
	var kind: String = b.kind
	var root := Kit.building(kind, int(b.level))
	var height := float(root.get_meta("height", 1.5))
	var info: Dictionary = Content.BUILDINGS[kind]
	if info.has("nest"):
		for k in b.path.count("elite"):
			var ring := MeshInstance3D.new()
			ring.mesh = Kit.ring(1.58, 0.09, 40)
			ring.material_override = Blocks.glow(ELITE_GOLD, 0.6)
			ring.position = Vector3(0, 0.08 + 0.16 * k, 0)
			root.add_child(ring)
		var affixes: Array = b.affixes
		for i in affixes.size():
			var ac: Color = Content.AFFIXES[affixes[i]].color
			var at := Vector3(-1.25 + i * 0.38, 0.0, 1.3)
			root.add_child(Blocks.cylinder(0.05, 0.42, Color(0.85, 0.65, 0.3), at + Vector3(0, 0.21, 0)))
			var orb := Blocks.ball(0.15, ac, at + Vector3(0, 0.55, 0))
			orb.material_override = Blocks.glow(ac, 0.9)
			root.add_child(orb)
		var sp := Content.species(info.nest, affixes)
		if not sp.used.is_empty():
			var sc: Color = Content.UNITS[sp.kind].color
			root.add_child(Blocks.cylinder(0.06, 1.4, Color(0.85, 0.65, 0.3), Vector3(1.3, 0.7, -1.2)))
			var crest := Blocks.ball(0.32, sc, Vector3(1.3, 1.55, -1.2))
			crest.material_override = Blocks.glow(sc, 1.1)
			root.add_child(crest)
		if lit:
			root.add_child(Blocks.cylinder(0.04, 2.0, Color(0.45, 0.32, 0.2), Vector3(-1.35, 1.0, -1.3)))
			var pennant := Blocks.box(Vector3(0.62, 0.38, 0.04), PENNANT, Vector3(-1.02, 1.78, -1.3))
			pennant.material_override = Blocks.glow(PENNANT, 0.5)
			root.add_child(pennant)
	root.set_meta("height", height)
	return root


# -- The star dinosaurs' pens ----------------------------------------------------------------------------------------

## The stars in their pens made again when who is where (or who went without) changes.
func refresh_pens() -> void:
	var key := str(home.stars) + str(home.hungry)
	if key != _pens_for:
		_pens_for = key
		for k in _pens.size():
			var pen: Node3D = _pens[k]
			var old := pen.get_node_or_null("Star")
			if old != null:
				old.name = "Gone"
				old.queue_free()
			if k < home.stars.size():
				var star := star_model(home.stars[k].id)
				star.name = "Star"
				star.position = Vector3(0.1, 0.1, 0.2)
				star.rotation.y = YARD_TURN
				pen.add_child(star)
				if k in home.hungry and Creatures.is_model(star):
					Creatures.play(star, "sleep")


## Which pen the cursor is on, or -1.
func pen_at(cam: Camera3D, at: Vector2) -> int:
	for k in _pens.size():
		if _screen_rect(cam, _pens[k]).grow(4.0).has_point(at):
			return k
	return -1


## Star dinosaur `id` as it stands in its pen: its own model (Creatures.star), as long as its kind is big (STAR_LENGTH);
## until it has one, the one of ours it looks most like (STAND_IN), banded in its own colours, a little bigger.
static func star_model(id: String) -> Node3D:
	var own := Creatures.star(id, float(STAR_LENGTH.get(id, 2.0)))
	if own != null:
		return own
	var s: Dictionary = Content.STARS[id]
	var n := Creatures.make(1.25, s.back, false, [], str(STAND_IN.get(id, "white")))
	if n.has_meta("paint"):
		var paint := n.get_meta("paint") as ShaderMaterial
		paint.set_shader_parameter("mark_color", s.back)
		paint.set_shader_parameter("mark_amount", 0.9)
		paint.set_shader_parameter("bands", 4.0)
	return n


## A pen: a square of low post-and-rail fence open at the front, a patch of fresh grass inside, a trough at its back.
static func _make_pen() -> Node3D:
	var root := Node3D.new()
	var wood := Color(0.48, 0.35, 0.22)
	var half := PEN * 0.5
	var turf := MeshInstance3D.new()
	turf.mesh = Blocks.rounded(Vector3(PEN - 0.2, 0.08, PEN - 0.2))
	turf.material_override = Ground.earth_material(Color(0.36, 0.52, 0.24))
	turf.position = Vector3(0, 0.04, 0)
	root.add_child(turf)
	for side in 4:
		var turn := side * PI * 0.5
		for i in 4:
			var f := -half + i * PEN / 3.0
			if side == 0 and i in [1, 2]:
				continue                      # the way in, at the front
			var at: Vector3 = Vector3(f, 0, half).rotated(Vector3.UP, turn)
			root.add_child(Blocks.cylinder(0.07, 0.75, wood.darkened(0.1), at + Vector3(0, 0.37, 0), 0.06))
		for h in [0.32, 0.6]:
			if side == 0:
				for x in [-half + PEN / 6.0, half - PEN / 6.0]:
					var rail := Blocks.box(Vector3(PEN / 3.0, 0.06, 0.06), wood, Vector3(x, h, half).rotated(Vector3.UP, turn))
					rail.rotation.y = turn
					root.add_child(rail)
			else:
				var rail := Blocks.box(Vector3(PEN, 0.06, 0.06), wood, Vector3(0, h, half).rotated(Vector3.UP, turn))
				rail.rotation.y = turn
				root.add_child(rail)
	root.add_child(Blocks.box(Vector3(1.1, 0.28, 0.42), wood.lightened(0.1), Vector3(0.6, 0.14, -half + 0.45)))
	root.add_child(Blocks.box(Vector3(0.9, 0.06, 0.26), Color(0.5, 0.7, 0.3), Vector3(0.6, 0.29, -half + 0.45)))
	return root


## The homeland made afresh (a new place): every building as it now is, at once.
func rebuild() -> void:
	for p in _buildings:
		_buildings[p].node.queue_free()
	_buildings.clear()
	refresh_buildings(false)


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
		tw.tween_callback(func() -> void:
			n.rotation.y = PI
			Creatures.play(n, "run", 1.4))
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
	var n := Creatures.make(float(s.size), Content.UNITS[u.kind].color, false, u.affixes, u.kind, int(u.get("elite", 0)))
	if Creatures.is_model(n):
		n.rotation.y = YARD_TURN
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
	Creatures.flash(n, Color(1.0, 0.9, 0.5), 1.2)


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