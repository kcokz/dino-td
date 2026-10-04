# res://scripts/entities/AmmoTower.gd
class_name AmmoTower
extends "res://scripts/entities/Building.gd"

## A TOWER (Config.BUILDINGS kinds "bow", "roller", "thrower", "bait"; GAME-DESIGN 6.0, the 2026-10-02 rebuild): what
## every tower shares -- what it is loaded with and how much of it, which way it faces, and the parts of its model
## that show how full it is and how big a store it has. What it does with what it is loaded with is its kind's
## (BowTower, LogTower, Catapult, BaitRack).
##
## LOADED BY HIM (the player: "工作台做，专门的弹药系统，每个塔都可以放不同的弹药，不同的数量，还能升级扩张数量"; and
## why it is loaded at all: "现在已经有的小机关其实也是自动化的……它就自己能自己重新trigger了，似乎有点自欺欺人了"). A
## tower holds rounds of one kind of ammunition at a time (Config.AMMO), made at the workbench and kept in the stock
## until he loads it -- walking past it, or sent to it (Hero; Config.AMMO_LOADING). Empty, it does nothing. Which
## kind is the player's to choose on its card; it keeps to that kind, and the first time takes the first of its
## kinds the stock has. A bigger store is an upgrade (BUILDINGS <id>_2, _3: the same tower, its `level`).
##
## A meat on the bait rack is several bites (Config.AMMO "uses"): what it holds is counted in uses, and shown in
## rounds -- a piece of meat half eaten is still a piece on the rack.

## The four ways a tower can face, clockwise from north, as steps on the building grid; Body built facing north.
const FACINGS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const GROUP: String = "ammo_towers"

## Which way it faces (FACINGS): given before it enters the tree (BuildSystem.place_at). Only a tower that faces
## (Config.faces) turns its body; the others stand as built.
@export var facing: int = 0
## The kind of ammunition it is set to (Config.AMMO id), "" until it has had any.
var ammo_type: String = ""
## Uses left in it (rounds -- or bites, for meat).
var uses_left: int = 0

## The turn about the vertical that points a body built facing north at `f` (FACINGS order).
static func facing_yaw(f: int) -> float:
	return -float(posmod(f, FACINGS.size())) * PI * 0.5

## The way `f` faces, flat, in the world: north is -Z.
static func facing_dir(f: int) -> Vector3:
	var step: Vector2i = FACINGS[posmod(f, FACINGS.size())]
	return Vector3(float(step.x), 0.0, float(step.y))

func _ready() -> void:
	add_to_group(GROUP)
	super._ready()
	_face_body()
	_dress()

func setup(type_id: String, p_cell: Vector2i = Vector2i.ZERO) -> void:
	super.setup(type_id, p_cell)
	# A bigger store keeps what was in the smaller; a smaller never holds more than it takes.
	if ammo_type != "":
		uses_left = mini(uses_left, capacity() * uses_each(ammo_type))

# ==============================================================================
# What it holds
# ==============================================================================

## The kinds of ammunition it takes (Config.ammo_accepts), in the order its card lists them.
func accepts() -> Array[String]:
	var cfg = _get_config()
	return cfg.ammo_accepts(building_type) if (cfg and cfg.has_method("ammo_accepts")) else ([] as Array[String])

## How many rounds it holds.
func capacity() -> int:
	var cfg = _get_config()
	return int(cfg.ammo_capacity(building_type)) if (cfg and cfg.has_method("ammo_capacity")) else 0

func uses_each(ammo_id: String) -> int:
	var cfg = _get_config()
	return int(cfg.ammo_uses(ammo_id)) if (cfg and cfg.has_method("ammo_uses")) else 1

## Rounds in it now: a round is in it while any use of it is left.
func rounds() -> int:
	if ammo_type == "" or uses_left <= 0:
		return 0
	return int(ceil(float(uses_left) / float(uses_each(ammo_type))))

func has_ammo() -> bool:
	return uses_left > 0 and ammo_type != ""

## Rounds it has room for.
func room() -> int:
	return maxi(0, capacity() - rounds())

## The row of what it is loaded with (Config.AMMO), {} empty.
func ammo_row() -> Dictionary:
	var cfg = _get_config()
	return cfg.AMMO.get(ammo_type, {}) if (cfg and "AMMO" in cfg and ammo_type != "") else {}

## What he would load it with now: the kind it is set to, or -- set to none -- the first of its kinds the stock has.
func kind_to_load() -> String:
	if ammo_type != "" and accepts().has(ammo_type):
		return ammo_type
	var gs = _get_game_state()
	for id in accepts():
		if gs != null and int(gs.resources.get(id, 0)) > 0:
			return id
	return ""

func _stock_of(ammo_id: String) -> int:
	var gs = _get_game_state()
	return int(gs.resources.get(ammo_id, 0)) if (gs != null and ammo_id != "") else 0

## Whether loading it would do anything: standing, finished, with room, and the stock holding what it is set to.
func wants_load() -> bool:
	if not is_constructed or is_destroyed or is_queued_for_deletion() or room() <= 0:
		return false
	return _stock_of(kind_to_load()) > 0

## Loads it from the stock with what it is set to, as much as it has room for and the stock holds; the rounds
## loaded (0 for none).
func load_from_stock() -> int:
	if not wants_load():
		return 0
	var kind: String = kind_to_load()
	var n: int = mini(room(), _stock_of(kind))
	var gs = _get_game_state()
	if n <= 0 or gs == null or not gs.spend_resources({kind: n}):
		return 0
	ammo_type = kind
	uses_left += n * uses_each(kind)
	_sound("reload")
	_ammo_changed()
	return n

## Sets it to take `ammo_id` from now on: what was in it of another kind goes back to the stock (whole rounds of
## it -- a half-eaten piece of meat is eaten). False for a kind it does not take.
func set_ammo(ammo_id: String) -> bool:
	if not accepts().has(ammo_id):
		return false
	if ammo_id == ammo_type:
		return true
	var back: int = int(floor(float(uses_left) / float(uses_each(ammo_type)))) if ammo_type != "" else 0
	var gs = _get_game_state()
	if back > 0 and gs != null and gs.has_method("add_resources"):
		gs.add_resources({ammo_type: back})
	ammo_type = ammo_id
	uses_left = 0
	_ammo_changed()
	return true

## Spends one use of what it holds -- a round shot, a bite eaten. False with nothing in it.
func take_use() -> bool:
	if uses_left <= 0:
		return false
	uses_left -= 1
	_ammo_changed()
	return true

func _ammo_changed() -> void:
	_show_ammo()
	_update_info_label()
	var eb = _get_event_bus()
	if eb and eb.has_signal("tower_ammo_changed"):
		eb.tower_ammo_changed.emit(self)

## Taken down: what is loaded in it goes back to the stock with him -- he takes it out as he takes it apart.
func demolish() -> void:
	if not is_destroyed and is_constructed and ammo_type != "":
		var back: int = int(floor(float(uses_left) / float(uses_each(ammo_type))))
		var gs = _get_game_state()
		if back > 0 and gs != null and gs.has_method("add_resources"):
			gs.add_resources({ammo_type: back})
		uses_left = 0
	super.demolish()

# ==============================================================================
# Its body
# ==============================================================================

## Finished and standing.
func _is_live() -> bool:
	return not (is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion())

func _faces() -> bool:
	var cfg = _get_config()
	return cfg != null and cfg.has_method("faces") and bool(cfg.faces(building_type))

## The way it faces, flat, in the world.
func forward() -> Vector3:
	return facing_dir(facing) if _faces() else Vector3(0.0, 0.0, -1.0)

func set_facing(f: int) -> void:
	facing = posmod(f, FACINGS.size())
	_face_body()

func _face_body() -> void:
	var body: Node3D = get_node_or_null("Body") as Node3D
	if body != null:
		body.rotation.y = facing_yaw(facing) if _faces() else 0.0

## One of Config.TOWERS, what the towers share.
func _towers(key: String, fallback: Variant) -> Variant:
	var cfg = _get_config()
	return cfg.TOWERS.get(key, fallback) if (cfg and "TOWERS" in cfg) else fallback

# ==============================================================================
# What it acts on, shown while it is picked
# ==============================================================================

## Its ring (Building's coverage ring: the bow tower's reach, the bait rack's) in the colour of what a tower acts on
## (Config.FEEDBACK.reach_color), not the brown its placeholder was drawn in -- over the grass that read green.
func _get_range_indicator_color() -> Color:
	var cfg = _get_config()
	var ui: Dictionary = cfg.UI if (cfg and "UI" in cfg) else {}
	var c: Color = ui.get("reach_color", Color(0.35, 0.65, 1.0))
	return Color(c.r, c.g, c.b, float(ui.get("reach_alpha", 0.22)))

## Picked, it shows what it acts on: its ring (Building), and -- a tower that acts ahead of it -- the ground it acts
## on there (_show_zone): the log tower's lane, the catapult's patch. They were shown only under the ghost.
func set_range_visible(p_visible: bool) -> void:
	super.set_range_visible(p_visible)
	if not p_visible:
		if _zone_holder != null and is_instance_valid(_zone_holder):
			_zone_holder.visible = false
		return
	if is_constructed and _show_zone():
		_zone_holder.visible = true

## Lays out the ground it acts on ahead of it (`_zone_mesh`); false for a tower that has none -- its ring is it.
func _show_zone() -> bool:
	return false

## A mesh lying on the ground in the reach colour, held clear of the building's own meshes (Building._body_meshes:
## what fades with a blueprint and flashes when bitten is the tower, not what it is showing).
var _zone_holder: Node3D = null
func _zone_mesh(mesh: Mesh) -> MeshInstance3D:
	if _zone_holder == null or not is_instance_valid(_zone_holder):
		_zone_holder = Node3D.new()
		_zone_holder.name = "ZoneShown"
		add_child(_zone_holder)
		var zone := MeshInstance3D.new()
		zone.name = "Zone"
		zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = _get_range_indicator_color()
		zone.material_override = mat
		_zone_holder.add_child(zone)
	var shown := _zone_holder.get_node("Zone") as MeshInstance3D
	shown.mesh = mesh
	return shown

## A part of its model by name, or null (the art is a kit of named parts: tools/generate_props.py).
func part(part_name: String) -> Node3D:
	var body: Node = get_node_or_null("Body")
	return body.find_child(part_name, true, false) as Node3D if body != null else null

## The model shown as what it is: its store's racks for its level, and how full it is.
func _dress() -> void:
	var cfg = _get_config()
	var level: int = int(cfg.tower_level(building_type)) if (cfg and cfg.has_method("tower_level")) else 1
	for lv in [2, 3]:
		var store: Node3D = part("Store%d" % lv)
		if store != null:
			store.visible = level >= lv
	_show_ammo()

## How full it is, on the model: the kind's own (the quiver, the logs in the cradle, the meat on the rack).
func _show_ammo() -> void:
	pass

## As many of `prefix`0..`count`-1 shown as its share of the store fills, at least one while it has any.
func _show_share(prefix: String, count: int) -> void:
	var share: float = float(rounds()) / float(maxi(1, capacity()))
	var shown: int = 0 if rounds() <= 0 else clampi(int(ceil(share * float(count))), 1, count)
	for i in count:
		var p: Node3D = part("%s%d" % [prefix, i])
		if p != null:
			p.visible = i < shown

## Upgraded to a bigger store: the same model (Config.VISUALS), turned and dressed again.
func _rebuild_body(old_type: String) -> void:
	super._rebuild_body(old_type)
	_face_body()
	_dress()

func _after_upgrade() -> void:
	super._after_upgrade()
	_dress()

## What one round of what it is loaded with is seen going as (Config.AMMO "prop"; VISUALS "prop/<prop>"), made fresh.
func _flying_model() -> Node3D:
	var prop: String = String(ammo_row().get("prop", ""))
	return VisualLibrary.make("prop/" + prop) if prop != "" else Node3D.new()

# ==============================================================================
# What it can hit
# ==============================================================================

## How far round it it sees (FogOfWar), in metres from its middle: as far as it acts -- its kind's to say.
func sight_radius() -> float:
	return 0.0

## Whether `d` is an animal a tower may hit: alive, a dinosaur, in the world.
static func is_quarry(d: Variant) -> bool:
	if d == null or typeof(d) != TYPE_OBJECT or not is_instance_valid(d) or not (d is Node3D):
		return false
	if (d as Node).is_queued_for_deletion() or not (d as Node).is_in_group("dinos"):
		return false
	if "is_dead" in d and d.is_dead:
		return false
	return d.has_method("take_damage")

## Whether `d` is in the air (Config.DINOS.<id>.flies): the bow reaches it, nothing on the ground does.
func flies(d: Node) -> bool:
	var cfg = _get_config()
	if cfg == null or not ("dino_type" in d) or not cfg.DINOS.has(String(d.dino_type)):
		return false
	return bool(cfg.DINOS[String(d.dino_type)].get("flies", false))

## Whether `d` is one of the heavy ones (Config.DINOS.<id>.heavy): a log does not shove it unless it is weighted.
func is_heavy(d: Node) -> bool:
	var cfg = _get_config()
	if cfg == null or not ("dino_type" in d) or not cfg.DINOS.has(String(d.dino_type)):
		return false
	return bool(cfg.DINOS[String(d.dino_type)].get("heavy", false))

## Hits `d` as `row` says (Config.AMMO): its damage -- a quarter of it, an arrow into an armoured animal (Config.ARMOR)
## -- and, it knows what hit it, the tower is what it goes for (Dino.shot_by, DINO_AI.shooter_kinds).
func strike(d: Node, row: Dictionary) -> void:
	if not is_quarry(d):
		return
	if d.has_method("shot_by"):
		d.shot_by(self)
	d.take_damage(float(row.get("damage", 0.0)) * AmmoTower.armour_factor(d, row))

## How much of `row`'s damage goes into `d` (Config.ARMOR): all of it, but what pierces (an arrow) into what is armoured.
static func armour_factor(d: Node, row: Dictionary) -> float:
	var cfg = Engine.get_main_loop().root.get_node_or_null("Config") if Engine.get_main_loop() is SceneTree else null
	if cfg == null or not ("ARMOR" in cfg) or d == null or not ("dino_type" in d):
		return 1.0
	if not bool(cfg.DINOS.get(String(d.dino_type), {}).get("armored", false)):
		return 1.0
	if not Array(cfg.ARMOR.get("piercing", [])).has(String(row.get("for", ""))):
		return 1.0
	return float(cfg.ARMOR.get("pierce", 0.25))

## Whether it can see `d` to act on it (GAME-DESIGN 3.0, rule 3): always by day and at dusk; in the dark
## (Config.TOWERS.dark_parts) only an animal a light is on -- a fire, his torch, a burning patch of ground
## (ProwlerDino.lights).
func can_see(d: Node) -> bool:
	if not is_dark():
		return true
	return is_inside_tree() and d is Node3D \
		and not ProwlerDino.light_over(get_tree(), (d as Node3D).global_position).is_empty()

## Whether it is dark now (Config.TOWERS.dark_parts).
func is_dark() -> bool:
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs == null or not gs.has_method("day_part"):
		return false
	return Array(_towers("dark_parts", ["night"])).has(String(gs.day_part()))

# ==============================================================================
# Presentation
# ==============================================================================

## Its line under its bars: nothing while it holds some -- its card's magazine says what and how much (OptionPanel) --
## and empty, what would fill it.
func _panel_status() -> String:
	if not is_constructed:
		return ""
	var cfg = _get_config()
	if has_ammo():
		return ""
	var kind: String = kind_to_load()
	if kind != "":
		return tr("STATUS_TOWER_EMPTY_STOCKED")
	var first: String = accepts()[0] if not accepts().is_empty() else ""
	var kind_name: String = tr(String(cfg.AMMO.get(first, {}).get("name", first))) if (cfg and first != "") else ""
	# What is made at the workbench says so; what is not -- the meat -- says only what it takes.
	if cfg and cfg.has_method("makes_ammo") and cfg.makes_ammo(first):
		return tr("STATUS_TOWER_EMPTY") % kind_name
	return tr("STATUS_TOWER_EMPTY_RAW") % kind_name

func get_display_info() -> Dictionary:
	var info: Dictionary = super.get_display_info()
	info["ammo"] = {"type": ammo_type, "rounds": rounds(), "capacity": capacity(), "uses": uses_left}
	return info
