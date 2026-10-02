# res://scripts/entities/CoreCampfire.gd
class_name CoreCampfire
extends "res://scripts/entities/Building.gd"

## The cabin: the crew module of the ship that brought the Hero here. The run's objective -- its
## loss is the game lost -- and since v0.6 round three a room he walks into.
##
## IT DOES NOT SHOOT (the player, 2026-10-02: "家里不需要任何防御就能顶住，cabin的自动射击得取消了，太厉害").
## It was a turret (Tower.gd) and its gun killed what came up to it, so a raid could be sat out
## inside with nothing built. The gun on its engine end is dead now -- the lifeboat's battery keeps
## the lights and the benches and no more -- and is not drawn (show_the_beacon): what keeps a raid
## off the cabin is what he builds and he himself.
##
## "栅栏围了一圈船舱之后，人在船舱外面还是能直接进到船舱，这个不合理，而且人进入船舱应该只能从船舱入口处进去，
## 还应该有个进入的效果，船舱应该外形和内置一致，进入船舱之后，应该也是同样的人在船舱里面". It was a box on the
## map and a room parked two hundred metres under it, and going in moved the camera there. Now
## there is one module (tools/generate_cabin.py module), the size of the room:
##
##   * ITS WALLS ARE SOLID AND ITS INSIDE IS NOT. The hull is colliders where the hull is drawn
##     (Config.CABIN.module); the ends past the room are solid. He walks about inside it.
##   * THE DOOR IS THE WAY IN, AND ONLY FOR HIM. The doorway is a body on the gate layer
##     (Config.LAYER_GATE), which his body and his map leave out and a raid's do not, and the
##     room is solid on every map but his (NavMaps.HERO_ONLY_GROUP). A fence round the cabin
##     shuts him out as it shuts out anybody.
##   * GOING IN SHOWS. The door slides open as he comes up and shuts behind him; while he is
##     inside, the roof and the front wall above the sill fade and the camera eases in
##     (Main._on_cabin_view_changed), and the benches are his, where they stand.
##   * THE BENCHES STAND IN IT (CraftingStation), each where the model marks it, and work while
##     he is inside -- the world outside running all the while.
##
## The inside is one module now; the ship is put back together a module at a time, a map at a
## time (GAME-DESIGN 8.2), docked at the ports the model marks at its ends ("port_west",
## "port_east").

var _last_emitted_hp: float = -1.0

## The benches in the room, one per Config.STATIONS.
var stations: Array[Node] = []
## Whether he is inside it, and the tweens fading its roof and sliding its door.
var hero_inside: bool = false
var _fade_tween: Tween = null
var _door_tween: Tween = null
var _door_open: bool = false
var _door: Node3D = null
var _door_shut_x: float = 0.0
var _room_sensor: Area3D = null
var _door_sensor: Area3D = null
var _lights: Array[OmniLight3D] = []
var _light_time: float = 0.0

func _init() -> void:
	super()
	setup("core")       # the cabin's own numbers

func _ready() -> void:
	add_to_group(NavMaps.HERO_ONLY_GROUP)
	# Its walls before the building's own box: a building with shapes of its own is not given a
	# solid block of its cells (Building._ensure_physics_and_visuals).
	_build_hull()
	super._ready()
	_emit_core_hp_changed()
	_dress_the_art()
	_ensure_stations()
	_ensure_sensors()
	# The mast on its roof is as far up as the beacon (CabinArt): now, and whenever a step is done.
	show_the_beacon()
	var eb = _get_event_bus()
	if eb and eb.has_signal("beacon_changed") and not eb.beacon_changed.is_connected(_on_beacon_changed):
		eb.beacon_changed.connect(_on_beacon_changed)

func _exit_tree() -> void:
	super._exit_tree()
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("beacon_changed") and eb.beacon_changed.is_connected(_on_beacon_changed):
		eb.beacon_changed.disconnect(_on_beacon_changed)

func _on_beacon_changed(_steps_done: int) -> void:
	show_the_beacon()

## Shows the parts of its model named for the beacon's steps as far as they are done -- the bent
## antenna until the first stage, a pole, then its stays, then the dish, each with its lamp, and
## the dish's throat alight once it is launched (Config.beacon_jobs, GameState.beacon_steps).
func show_the_beacon() -> void:
	var body: Node = _body()
	var gs = _get_game_state()
	var cfg = _get_config()
	if body == null or gs == null or cfg == null or not cfg.has_method("beacon_jobs"):
		return
	var steps: Array = cfg.beacon_jobs(gs.map_data())
	var done: int = int(gs.beacon_steps)
	CabinArt.show_parts(body, func(job: String) -> bool: return steps.has(job),
		func(job: String) -> bool: return steps.find(job) < done)
	# The dead gun on the engine end is not drawn (it does not shoot: the class's head) -- a gun on the
	# roof that never fired would say it guards the cabin. After the parts: they show all that is not a job.
	var gun := body.find_child("Head", true, false) as Node3D
	if gun != null:
		gun.visible = false

func _emit_core_hp_changed() -> void:
	if _last_emitted_hp == current_hp:
		return
	_last_emitted_hp = current_hp
	var eb = _get_event_bus()
	if eb and eb.has_signal("core_hp_changed"):
		eb.core_hp_changed.emit(current_hp, max_hp)

func _on_damaged(_amount: float) -> void:
	_emit_core_hp_changed()
	# Heard, not flashed: the whole hull going white at every bite would be all the finale is.
	_sound_hit()

func _on_before_destroy() -> void:
	super._on_before_destroy()
	_emit_core_hp_changed()
	var gs = _get_game_state()
	if gs != null and gs.is_game_over:
		return
	if gs != null and "lost_to" in gs:
		gs.lost_to = "cabin"
	var eb = _get_event_bus()
	if eb and eb.has_signal("game_lost"):
		eb.game_lost.emit()

# ==============================================================================
# The hull
# ==============================================================================

## The module's measures (Config.CABIN.module): the room's half-extents, the walls' thickness,
## the door.
func _module() -> Dictionary:
	var cfg = _get_config()
	return cfg.CABIN.get("module", {}) if (cfg and "CABIN" in cfg) else {}

func _half() -> Vector2:
	var cfg = _get_config()
	return cfg.get_building_half(building_type) if (cfg and cfg.has_method("get_building_half")) else Vector2(3.5, 1.5)

func room_half() -> Vector2:
	return _module().get("room", Vector2(2.8, 1.3))

func _door_spec() -> Dictionary:
	return _module().get("door", {"x": 0.0, "width": 1.2, "height": 1.8})

## Solid boxes where the hull is: the north wall, the south wall either side of the door, and the
## two ends past the room. Shapes of this body, so they are on its layer and in every bake. The
## doorway is a body of its own on the gate layer (DoorWay), open to him alone.
func _build_hull() -> void:
	if find_child("Hull_N", false, false) != null:
		return
	var half: Vector2 = _half()
	var room: Vector2 = room_half()
	var h: float = _building_height()
	var door: Dictionary = _door_spec()
	var dx: float = float(door.get("x", 0.0))
	var dw: float = float(door.get("width", 1.2)) * 0.5
	var wall_z: float = (half.y + room.y) * 0.5
	var wall_d: float = half.y - room.y
	_add_box("Hull_N", Vector3(half.x * 2.0, h, wall_d), Vector3(0.0, h * 0.5, -wall_z))
	var west_w: float = (dx - dw) + half.x
	var east_w: float = half.x - (dx + dw)
	_add_box("Hull_SW", Vector3(west_w, h, wall_d), Vector3(-half.x + west_w * 0.5, h * 0.5, wall_z))
	_add_box("Hull_SE", Vector3(east_w, h, wall_d), Vector3(half.x - east_w * 0.5, h * 0.5, wall_z))
	var end_w: float = half.x - room.x
	for side in [-1.0, 1.0]:
		_add_box("Hull_W" if side < 0.0 else "Hull_E", Vector3(end_w, h, room.y * 2.0),
			Vector3(side * (room.x + end_w * 0.5), h * 0.5, 0.0))
	# The doorway: a raid's wall, his way in.
	var way := StaticBody3D.new()
	way.name = "DoorWay"
	var cfg = _get_config()
	way.collision_layer = int(cfg.LAYER_GATE) if (cfg and "LAYER_GATE" in cfg) else 128
	way.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(dw * 2.0, h, wall_d)
	shape.shape = box
	shape.position = Vector3(dx, h * 0.5, wall_z)
	way.add_child(shape)
	add_child(way)

func _add_box(node_name: String, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = node_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	add_child(shape)

## Where the room is, for the navigation maps: solid on every map but his (NavMaps.HERO_ONLY_GROUP).
func hero_only_box() -> Array:
	return [global_position, room_half(), _building_height()]

## Whether `pos` is in the room.
func is_inside(pos: Vector3) -> bool:
	var local: Vector3 = pos - global_position
	var room: Vector2 = room_half()
	return absf(local.x) <= room.x and absf(local.z) <= room.y

## In front of the door, outside: where he goes to go in and is sent to come out
## (Config.CABIN.door_standoff).
func door_outside() -> Vector3:
	var door: Dictionary = _door_spec()
	return global_position + Vector3(float(door.get("x", 0.0)), 0.0, _half().y + _cabin_number("door_standoff", 0.8))

## Just inside the door: where "go in" takes him (Config.CABIN.inside_step).
func door_inside() -> Vector3:
	var door: Dictionary = _door_spec()
	return global_position + Vector3(float(door.get("x", 0.0)), 0.0, room_half().y - _cabin_number("inside_step", 0.8))

func _cabin_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.CABIN.get(key, fallback)) if (cfg and "CABIN" in cfg) else fallback

# ==============================================================================
# The art: glass, lights, the door
# ==============================================================================

func _body() -> Node:
	return find_child("Body", false, false)

## The windows given glass, the lamp and the fire lit (CabinArt), the door found.
func _dress_the_art() -> void:
	var body: Node = _body()
	if body == null:
		return
	var cfg = _get_config()
	var glass_col: Color = cfg.CABIN.get("glass_color", Color(0.6, 0.8, 0.9, 0.25)) if (cfg and "CABIN" in cfg) else Color(0.6, 0.8, 0.9, 0.25)
	for mi in CabinArt.parts(body):
		if String(mi.name).ends_with("glass"):
			mi.material_override = CabinArt.glass_material(glass_col)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CabinArt.light_glows(body, cfg.CABIN.get("glow_lights", {}) if (cfg and "CABIN" in cfg) else {})
	_lights = CabinArt.lights_under(body)
	_door = body.find_child("door", true, false) as Node3D
	if _door != null:
		_door_shut_x = _door.position.x

## The parts that fade while he is inside: every mesh whose name begins "fade_".
func _fading_parts() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mi in CabinArt.parts(_body()):
		if String(mi.name).begins_with("fade_"):
			out.append(mi)
	return out

## Fades the roof and the front wall above the sill, or brings them back (Config.CABIN
## fade_transparency, fade_seconds). Faded, they cast no shadow either: the room is lit.
func set_roof_faded(faded: bool, instant: bool = false) -> void:
	var to: float = _cabin_number("fade_transparency", 0.88) if faded else 0.0
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var parts := _fading_parts()
	for mi in parts:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if faded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if instant or not is_inside_tree():
		for mi in parts:
			mi.transparency = to
		return
	_fade_tween = create_tween().set_parallel(true)
	for mi in parts:
		_fade_tween.tween_property(mi, "transparency", to, _cabin_number("fade_seconds", 0.4))

## How far the roof is faded now: 0 opaque, towards 1 gone.
func roof_transparency() -> float:
	var parts := _fading_parts()
	return parts[0].transparency if not parts.is_empty() else 0.0

## Slides the door open (east, into the wall beside the opening) or shut.
func set_door_open(open: bool) -> void:
	if open == _door_open:
		return
	_door_open = open
	if _door == null or not is_inside_tree():
		return
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	var slide: float = float(_door_spec().get("width", 1.2)) + 0.05
	_door_tween = create_tween()
	_door_tween.tween_property(_door, "position:x", _door_shut_x + (slide if open else 0.0),
		_cabin_number("door_slide_seconds", 0.35)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func is_door_open() -> bool:
	return _door_open

# ==============================================================================
# Him coming and going
# ==============================================================================

## Two rings that notice him -- the engine's Area3D, on his layer and no other: one round the
## door, which opens it; one filling the room, which is him being inside.
func _ensure_sensors() -> void:
	if _room_sensor != null:
		return
	var cfg = _get_config()
	var hero_layer: int = int(cfg.LAYER_HERO) if (cfg and "LAYER_HERO" in cfg) else 4
	var h: float = _building_height()
	var room: Vector2 = room_half()
	_room_sensor = _sensor("RoomSensor", hero_layer)
	# Short of the room by half of him all round, so that his body touching it is his middle in
	# the room -- what is_inside asks.
	var half_him: float = float(cfg.HERO.get("width", 0.8)) * 0.5 if (cfg and "HERO" in cfg) else 0.4
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(0.1, (room.x - half_him) * 2.0), h, maxf(0.1, (room.y - half_him) * 2.0))
	(_room_sensor.get_child(0) as CollisionShape3D).shape = box
	(_room_sensor.get_child(0) as CollisionShape3D).position = Vector3(0.0, h * 0.5, 0.0)
	_room_sensor.body_entered.connect(_on_room_entered)
	_room_sensor.body_exited.connect(_on_room_exited)
	_door_sensor = _sensor("DoorSensor", hero_layer)
	var ball := SphereShape3D.new()
	ball.radius = _cabin_number("door_open_radius", 1.6)
	(_door_sensor.get_child(0) as CollisionShape3D).shape = ball
	(_door_sensor.get_child(0) as CollisionShape3D).position = Vector3(float(_door_spec().get("x", 0.0)), 0.6, _half().y)
	_door_sensor.body_entered.connect(_on_door_approached)
	_door_sensor.body_exited.connect(_on_door_left)

func _sensor(node_name: String, mask: int) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = 0
	area.collision_mask = mask
	area.monitorable = false
	area.input_ray_pickable = false
	area.add_child(CollisionShape3D.new())
	add_child(area)
	return area

func _on_door_approached(body: Node) -> void:
	if body != null and body.is_in_group("hero"):
		set_door_open(true)

func _on_door_left(body: Node) -> void:
	if body != null and body.is_in_group("hero"):
		set_door_open(false)

func _on_room_entered(body: Node) -> void:
	if body != null and body.is_in_group("hero"):
		_set_hero_inside(true)

func _on_room_exited(body: Node) -> void:
	if body != null and body.is_in_group("hero"):
		_set_hero_inside(false)

## He has come in or gone out: the roof fades or comes back, the benches are caught up on what
## they show, and the rest of the game is told (EventBus.cabin_view_changed).
func _set_hero_inside(inside: bool) -> void:
	if inside == hero_inside:
		return
	hero_inside = inside
	set_roof_faded(inside)
	if inside:
		for st in stations:
			if is_instance_valid(st) and st.has_method("refresh_parts"):
				st.refresh_parts()
	var eb = _get_event_bus()
	if eb and eb.has_signal("cabin_view_changed"):
		eb.cabin_view_changed.emit(inside)

## Asks the room whether he is in it now, rather than waiting for it to say: for a Hero put
## inside or taken out between physics frames (a restart, a test).
func recheck_hero() -> void:
	var inside: bool = false
	if is_inside_tree():
		for h in get_tree().get_nodes_in_group("hero"):
			if is_instance_valid(h) and h is Node3D and is_inside((h as Node3D).global_position):
				inside = true
	_set_hero_inside(inside)

# ==============================================================================
# The benches
# ==============================================================================

## One CraftingStation per Config.STATIONS, standing where the module's model marks it
## ("spot_<id>"), with its back to the back wall.
func _ensure_stations() -> void:
	stations.clear()
	var cfg = _get_config()
	var ids: Array = cfg.STATIONS if (cfg and "STATIONS" in cfg) else []
	var script = load("res://scripts/entities/CraftingStation.gd")
	var room: Vector2 = room_half()
	for i in range(ids.size()):
		var id: String = String(ids[i])
		var st: Node = find_child("Station_%s" % id, false, false)
		if st == null and script != null:
			st = script.new(id)
			st.name = "Station_%s" % id
			# Along the back wall in a row, unless the model says where.
			var along: float = -room.x + room.x * 2.0 * (float(i) + 0.5) / float(ids.size())
			var size: Vector3 = cfg.get_visual_size("station/" + id) if cfg.has_method("get_visual_size") else Vector3.ONE
			st.position = Vector3(along, 0.0, -room.y + size.z * 0.5)
			var spot: Node3D = spot_of(id)
			if spot != null:
				st.position = to_local(spot.global_position)
			add_child(st)
		if st != null:
			stations.append(st)

## Where the module's model says the bench `station_id` stands, or null.
func spot_of(station_id: String) -> Node3D:
	var body: Node = _body()
	return body.find_child("spot_%s" % station_id, true, false) as Node3D if body else null

func station(station_id: String) -> Node:
	for st in stations:
		if is_instance_valid(st) and "station_id" in st and String(st.station_id) == station_id:
			return st
	return null

## Benches with a job under way.
func busy_stations() -> Array[Node]:
	var out: Array[Node] = []
	for st in stations:
		if is_instance_valid(st) and "active_recipe" in st and String(st.active_recipe) != "":
			out.append(st)
	return out

## Work goes on at the benches while he is in here and not otherwise -- the same deal an
## unfinished building gets: walking out keeps what is done, and nothing moves in an empty room.
func _process(delta: float) -> void:
	_light_time += delta
	CabinArt.animate(_lights, _light_time)
	if not hero_inside:
		return
	var gs = _get_game_state()
	if gs and "is_game_over" in gs and gs.is_game_over:
		return
	for st in stations:
		if is_instance_valid(st) and st.has_method("work"):
			st.work(delta)

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
