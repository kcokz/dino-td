class_name Portraits
extends Node
## The cards' pictures, taken from the models (GAME-DESIGN 21): a building as it stands on the homeland -- a nest with
## the creature it hatches in front of it -- an affix on a creature, a raise as a nest grown tall; each set on a little
## stage of its own, lit warm from above, photographed once and kept. Asked for before it is taken, a picture comes
## later: the one asking is told.

const SIZE := Vector2i(252, 164)

static var me: Portraits
static var _cache := {}           # key -> Texture2D

var _vp: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _queue: Array = []            # [key, maker: Callable]
var _waiting := {}                # key -> [Callable(Texture2D)]
var _busy := false


func _ready() -> void:
	me = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.64)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 28, 0)
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.45
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -120, 0)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.45
	_vp.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 28.0
	_vp.add_child(_camera)
	_stage = Node3D.new()
	_vp.add_child(_stage)


## The picture of an offer (Content.offer) -- null until it has been taken; then `done` is told it.
static func of_offer(c: Dictionary, done: Callable) -> Texture2D:
	return picture(key_of(c), done)


## The picture under `key` -- "b:kind:level:path:affixes" a building, "a:affix", "raise", "u:kind" one of our
## creatures, "e:kind" a monster, "w:id" a wonder -- null until it has been taken; then `done` is told it.
static func picture(key: String, done: Callable) -> Texture2D:
	if key == "":
		return null
	if _cache.has(key):
		return _cache[key]
	if me != null:
		me._ask(key, done)
	return null


static func key_of(c: Dictionary) -> String:
	match str(c.get("type", "")):
		"build":
			return "b:%s:%d:%s:%s" % [c.builds, int(c.get("level", 1)), ",".join(c.get("path", [])), ",".join(c.get("affixes", []))]
		"affix":
			return "a:" + str(c.affix)
		"raise":
			return "raise"
	return ""


## Every kind of building and affix, the raise, every creature, monster and wonder, taken now, so no card or codex
## entry waits for its picture.
static func warm() -> void:
	if me == null:
		return
	for kind in Content.BUILDINGS:
		me._ask("b:%s:1::" % kind, Callable())
	for a in Content.AFFIXES:
		me._ask("a:" + a, Callable())
	me._ask("raise", Callable())
	for kind in Content.UNITS:
		me._ask("u:" + kind, Callable())
	for kind in Content.ENEMIES:
		me._ask("e:" + kind, Callable())
	for id in Content.WONDERS:
		me._ask("w:" + id, Callable())


func _ask(key: String, done: Callable) -> void:
	if _cache.has(key):
		if done.is_valid():
			done.call(_cache[key])
		return
	if not _waiting.has(key):
		_waiting[key] = []
		_queue.append(key)
	if done.is_valid():
		_waiting[key].append(done)
	if not _busy:
		_work()


func _work() -> void:
	_busy = true
	while not _queue.is_empty():
		var key: String = _queue.pop_front()
		var node := _model(key)
		if node == null:
			_waiting.erase(key)
			continue
		_stage.add_child(node)
		_frame(node)
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var tex := ImageTexture.create_from_image(_vp.get_texture().get_image())
		_cache[key] = tex
		node.queue_free()
		for done in _waiting.get(key, []):
			if (done as Callable).is_valid():
				done.call(tex)
		_waiting.erase(key)
	_busy = false


## What a key shows, built as a model: a building (and a nest's creature before it), an affix worn by a red, a raise.
func _model(key: String) -> Node3D:
	var root := Node3D.new()
	if key == "raise":
		root.add_child(HomeView._building({"kind": "nest_red", "level": 3, "path": ["count", "count"], "affixes": []}))
		return root
	if key.begins_with("u:") or key.begins_with("e:"):
		var kind := key.substr(2)
		var theirs := key.begins_with("e:")
		var info: Dictionary = (Content.ENEMIES if theirs else Content.UNITS)[kind]
		var n := Creatures.make(float(info.size), info.color, theirs, [], kind, 0)
		n.rotation.y = Creatures.PORTRAIT_TURN if Creatures.is_model(n) else 0.9
		root.add_child(n)
		return root
	if key.begins_with("w:"):
		root.add_child(HomeView.wonder_node(key.substr(2)))
		return root
	if key.begins_with("a:"):
		var a := key.substr(2)
		var red: Dictionary = Content.UNITS.red
		var n := Creatures.make(1.0, red.color, false, [a], "red", 0, 1.7)
		n.rotation.y = Creatures.PORTRAIT_TURN if Creatures.is_model(n) else 1.0
		root.add_child(n)
		if Creatures.is_model(n):
			root.set_meta("crop_tail", 0.4 if a != "poison" else 0.0)
		return root
	var bits := key.substr(2).split(":")
	var kind := bits[0]
	if not Content.BUILDINGS.has(kind):
		return null
	var path: Array = Array(bits[2].split(",", false)) if bits.size() > 2 else []
	var affixes: Array = Array(bits[3].split(",", false)) if bits.size() > 3 else []
	var b := {"kind": kind, "level": int(bits[1]), "path": path, "affixes": affixes}
	var building := HomeView._building(b)
	root.add_child(building)
	var info: Dictionary = Content.BUILDINGS[kind]
	if info.has("nest"):
		var sp := Content.species(info.nest, affixes)
		var u: Dictionary = Content.UNITS[sp.kind]
		var edge := float(u.size) * pow(Content.ELITE_SIZE, path.count("elite"))
		var n := Creatures.make(edge, u.color, false, affixes.filter(func(x: String) -> bool: return not x in sp.used),
			sp.kind, path.count("elite"))
		n.position = Vector3(1.3, 0.0, 2.3)
		n.rotation.y = Creatures.PORTRAIT_TURN if Creatures.is_model(n) else 0.75
		root.add_child(n)
	return root


## The camera set to take in all of `node`, from in front, a little to the right and above.
func _frame(node: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	# An affix's picture: the tail (off to the left) left out, so the creature is bigger and what it wears shows.
	var cut := box.size.x * float(node.get_meta("crop_tail", 0.0))
	box.position.x += cut
	box.size.x -= cut
	var center := box.get_center()
	var radius := maxf(0.5, box.size.length() * 0.5)
	var dir := Vector3(0.5, 0.55, 1.0).normalized()
	var dist := radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.8
	_camera.position = center + dir * dist
	_camera.look_at(center, Vector3.UP)
