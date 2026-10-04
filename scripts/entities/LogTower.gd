# res://scripts/entities/LogTower.gd
class_name LogTower
extends "res://scripts/entities/AmmoTower.gd"

## 滚木塔 THE LOG TOWER (Config.BUILDINGS kind "roller"; GAME-DESIGN 6.0, the 2026-10-02 rebuild; the player: "方向
## 是向前方滚木（有个类似滑滑梯的坡，向下滚木）……滚木作用，减速所有范围内的恐龙单位，并有推回效果，伤害低，滚木要长一
## 点，不然范围太小没作用，也是通过恐龙触碰触发"): a cradle of logs on a frame, a ramp down its front
## (tools/generate_props.py log_tower: Log0..Log3 in the cradle, a Lever). Its LANE is the ground in front of it --
## from its front edge `lane` cells out the way it faces, as far as the first thing built across the middle of it
## (what is stepped over, the spikes, is no stop), and `lane_width` metres across. Something walking into the lane
## lets a log go: it comes down the ramp and rolls the lane at `roll_speed`, and everything it rolls over is
## slowed, shoved back the way the log is going and hurt a little -- each once a roll -- as the log is (Config.AMMO);
## the heavy ones are only shoved by a log weighted with stone. A log every `roll_seconds` at most.

## Seconds before it can let another log go.
var cooldown: float = 0.0
## The logs rolling now: {node, along (metres from its front edge), hit (instance ids), row}.
var _rolls: Array = []
## Metres of lane before it (_lane_length), worked out again now and then: something may be built across it.
var _lane_m: float = -1.0
var _lane_clock: float = 0.0

func _number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.BUILDINGS.get(building_type, {}).get(key, fallback)) if (cfg and "BUILDINGS" in cfg) else fallback

## How thick a log is, half across (Config.TOWERS.log_radius): it rolls on that, and turns as it rolls.
func _log_radius() -> float:
	return float(_towers("log_radius", 0.2))

## Its front edge's middle, on the ground, in the world: where the logs come off the ramp.
func lane_origin() -> Vector3:
	var cfg = _get_config()
	var half: float = float(cfg.get_building_half(building_type).y) if cfg else 1.5
	var o: Vector3 = global_position + forward() * half
	return Vector3(o.x, global_position.y, o.z)

func lane_width() -> float:
	return _number("lane_width", 3.0)

## Its lane, picked (AmmoTower.set_range_visible): as wide as a log is long, from its front edge as far as it runs.
func _show_zone() -> bool:
	_lane_m = -1.0
	var length: float = lane_length()
	if length <= 0.0:
		return false
	var plane := PlaneMesh.new()
	plane.size = Vector2(lane_width(), length)
	var zone: MeshInstance3D = _zone_mesh(plane)
	zone.global_position = lane_origin() + forward() * (length * 0.5) + Vector3(0.0, 0.04, 0.0)
	zone.global_rotation = Vector3(0.0, facing_yaw(facing), 0.0)
	return true

## It sees down its lane to the end.
func sight_radius() -> float:
	var cfg = _get_config()
	var half: float = float(cfg.get_building_half(building_type).y) if cfg else 1.5
	return half + lane_length()

## How far its lane runs, in metres: `lane` cells, or to the first cell along its middle that something built
## stands in (what is walked over does not stop a log) or that is not ground.
func lane_length() -> float:
	if _lane_m < 0.0:
		_lane_m = _work_out_lane()
	return _lane_m

func _work_out_lane() -> float:
	var cells: int = int(_number("lane", 6.0))
	var cfg = _get_config()
	var gm: Node = get_tree().get_first_node_in_group("grid_manager") if is_inside_tree() else null
	if gm == null or cfg == null:
		return float(cells)
	var rows: Array = LogTower.lane_rows(gm, global_position, float(cfg.get_building_half(building_type).y), facing,
		int(cfg.get_building_cells(building_type)), cells)
	return float(LogTower.lane_run(gm, cfg, rows, self)) * float(cfg.BUILD_CELL)

## The cells under the middle of a log tower's lane, a row for each cell out from its front edge (`rows` of them),
## the tower standing with its middle at `centre`, `half` metres from it to its front edge: in each row the one cell
## in line with its middle, for a tower an odd number of cells across -- and for an even one, whose middle runs along
## the line between two columns, the cells either side of that line: a log as long as the lane is wide rolls over
## both, and something built in either stops it. (Its own cells by its own middle were a guess: a 2 x 2 tower's middle
## is a corner, and the column looked down was not the one the wall was in.) Shared with the ghost (Main._show_zone).
static func lane_rows(gm: Node, centre: Vector3, half: float, facing_index: int, size: int, rows: int) -> Array:
	var dir: Vector3 = facing_dir(facing_index)
	var side := Vector3(-dir.z, 0.0, dir.x)
	var cell: float = float(gm.build_cell_size())
	var aside: Array = [0.0] if size % 2 == 1 else [-0.5 * cell, 0.5 * cell]
	var out: Array = []
	for k in range(rows):
		var at: Vector3 = centre + dir * (half + (float(k) + 0.5) * cell)
		var row: Array = []
		for a in aside:
			row.append(gm.world_to_build_cell(at + side * float(a)))
		out.append(row)
	return out

## How many of `rows` (lane_rows) a log rolls before something stops it: ground under every cell of a row, and
## nothing built in any of them but what is walked over (the spikes) -- or `own`, the tower itself.
static func lane_run(gm: Node, cfg: Node, rows: Array, own: Node = null) -> int:
	var run: int = 0
	for row in rows:
		for c in row:
			if not gm.is_build_cell_ground(c):
				return run
			var b: Node = gm.building_in_build_cell(c)
			if b != null and b != own and not ("building_type" in b and cfg.walk_over(String(b.building_type))):
				return run
		run += 1
	return run

## Where `point` is on its lane: [metres along from its front edge, metres aside from its middle line].
func lane_coords(point: Vector3) -> Vector2:
	var off: Vector3 = point - lane_origin()
	off.y = 0.0
	var dir: Vector3 = forward()
	var along: float = off.dot(dir)
	return Vector2(along, (off - dir * along).length())

## Whether an animal stands in its lane, on the ground.
## Something it can see in its lane (AmmoTower.can_see: in the dark, only what a light is on).
func someone_in_lane() -> bool:
	for d in animals_in_lane(0.0, lane_length()):
		if can_see(d):
			return true
	return false

func animals_in_lane(from_m: float, to_m: float) -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var half: float = lane_width() * 0.5
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d) or flies(d):
			continue
		var at: Vector2 = lane_coords((d as Node3D).global_position)
		if at.x >= from_m and at.x <= to_m and at.y <= half:
			out.append(d)
	return out

func _physics_process(delta: float) -> void:
	_roll_on(delta)
	if not _is_live():
		return
	_lane_clock -= delta
	if _lane_clock <= 0.0:
		_lane_clock = float(_towers("lane_check_seconds", 1.0))
		_lane_m = _work_out_lane()
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0 or not has_ammo():
		return
	if someone_in_lane():
		let_go()

## Lets a log go down the ramp. False with none in it.
func let_go() -> bool:
	var row: Dictionary = ammo_row()
	var model: Node3D = _flying_model()
	if not take_use():
		model.free()
		return false
	cooldown = _number("roll_seconds", 3.0)
	var holder := Node3D.new()
	holder.name = "RollingLog"
	holder.add_child(model)
	get_parent().add_child(holder)
	holder.global_position = lane_origin() + Vector3(0.0, _log_radius(), 0.0)
	holder.rotation.y = facing_yaw(facing)
	_rolls.append({"node": holder, "along": 0.0, "hit": {}, "row": row})
	var lever: Node3D = part("Lever")
	if lever != null and DisplayServer.get_name() != "headless":
		var rest: Vector3 = lever.rotation
		var times: Array = _towers("lever_seconds", [0.1, 0.6])
		var tw := lever.create_tween()
		tw.tween_property(lever, "rotation", rest + Vector3(float(_towers("lever_throw", -0.6)), 0.0, 0.0), float(times[0]))
		tw.tween_property(lever, "rotation", rest, float(times[1]))
	_sound("log_roll")
	return true

## The logs rolling: on down the lane, over what is in it, gone at its end.
func _roll_on(delta: float) -> void:
	if _rolls.is_empty():
		return
	var speed: float = _number("roll_speed", 6.0)
	var dir: Vector3 = forward()
	var end: float = lane_length()
	var keep: Array = []
	for r in _rolls:
		var node: Node3D = r["node"]
		if not is_instance_valid(node):
			continue
		var was: float = float(r["along"])
		var now: float = minf(end, was + speed * delta)
		r["along"] = now
		node.global_position = lane_origin() + dir * now + Vector3(0.0, _log_radius(), 0.0)
		var body: Node3D = node.get_child(0) as Node3D if node.get_child_count() > 0 else null
		if body != null:
			body.rotate_object_local(Vector3.RIGHT, -speed * delta / _log_radius())
		var reach: float = float(_towers("log_hit_reach", 0.6))
		for d in animals_in_lane(was - reach, now + reach):
			var id: int = (d as Object).get_instance_id()
			if r["hit"].has(id):
				continue
			r["hit"][id] = true
			_bowl_over(d, r["row"], dir)
		if now >= end - 0.001:
			node.queue_free()
			continue
		keep.append(r)
	_rolls = keep

## What a log does to `d`: hurt a little, slowed, and shoved on the way the log goes -- the heavy ones only by a
## weighted log.
func _bowl_over(d: Node, row: Dictionary, dir: Vector3) -> void:
	strike(d, row)
	if not AmmoTower.is_quarry(d):
		return
	if d.has_method("slow_for"):
		d.slow_for(float(row.get("slow", 0.5)), float(row.get("slow_seconds", 2.0)))
	if d.has_method("knock_back") and (bool(row.get("moves_heavy", false)) or not is_heavy(d)):
		d.knock_back(dir * float(row.get("push", 1.5)), float(row.get("push_seconds", 0.35)))

## Logs in the cradle, as many as it is full.
func _show_ammo() -> void:
	_show_share("Log", 4)

func _exit_tree() -> void:
	for r in _rolls:
		if is_instance_valid(r["node"]):
			(r["node"] as Node).queue_free()
	_rolls.clear()
	super._exit_tree()
