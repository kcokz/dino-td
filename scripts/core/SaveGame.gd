# res://scripts/core/SaveGame.gd
class_name SaveGame
extends RefCounted

## SAVING THE RUN (the player, 2026-10-04: "需要加一个保存功能游戏的功能"): the run as it stands, written to one file
## (Config.SAVE.path) from the pause menu, and played on from where it was from the start screen's Continue.
##
## WHEN: in a lull -- no raid out or about to set out from a beacon stage, no final wave, no raider or prowler on the
## field (a nest's guards are part of the valley, and kept), the run not over, no cinematic playing (why_not). So what
## is saved is the valley and what he has made of it, never an animal's mind half-way through a thought: the guards
## are put back where they stood, and think afresh.
##
## WHAT (snapshot): the game and its station, the run's seed and its dice where they had got to; the stock, the tools,
## what is known, the clock, the beacon, the cabin's power, the pinned goal; the next raid's clock and the ways in
## taken in turn, the night's prowl, the run's account; him (where, his health, his stamina, his torch); the cabin's
## health; every building (its type and middle cell, its facing, its health, how far it is built and raised, what is
## loaded in it, whether tonight's wood is paid); what is left in every tree, rock and wreck; every pile on the
## ground; which of each nest's guards live, and where; what has been seen through the mist and which nests found;
## the benches' work; the journal.
##
## HOW BACK (apply): the level is built as any run's is, from the same game and seed (the same valley), and then the
## saved run is laid over it -- the opening's piles taken up, the buildings put up again, the rest set.

const VERSION: int = 1
## The group the level is in (Main), for what saves it from outside it.
const LEVEL_GROUP: String = "level"

## Where a test writes instead of the player's file (tests/test_v07_the_save.gd): "" for the player's.
static var path_override: String = ""

static func path() -> String:
	if path_override != "":
		return path_override
	var cfg: Node = _config()
	return String(cfg.SAVE.get("path", "user://save.json")) if (cfg and "SAVE" in cfg) else "user://save.json"

static func exists() -> bool:
	return FileAccess.file_exists(path())

## The save, read: {} when there is none, or it is not one this version can read.
static func read() -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	return parsed

## Why the run in `main` cannot be saved now -- a strings.csv key -- or "" when it can.
static func why_not(main: Node) -> String:
	var gs: Node = _state()
	if main == null or not is_instance_valid(main) or gs == null:
		return "SAVE_NOT_NOW"
	if bool(gs.is_game_over):
		return "SAVE_NOT_OVER"
	if main.get("station_jump") != null and main.station_jump.is_running():
		return "SAVE_NOT_NOW"
	var wm: Node = main.get("wave_manager")
	if wm != null and (bool(wm.is_wave_active) or int(wm._stirred) > 0 or bool(wm.final_wave)):
		return "SAVE_NOT_RAID"
	for d in main.get_tree().get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not bool(d.get("is_dead")) and not (d is GuardDino):
			return "SAVE_NOT_DINOS"
	return ""

## Written, if it may be (why_not): true when it was.
static func save(main: Node) -> bool:
	if why_not(main) != "":
		return false
	var file := FileAccess.open(path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot(main)))
	file.close()
	return true

## The run in `main`, as plain data (JSON's: numbers, strings, arrays, dictionaries).
static func snapshot(main: Node) -> Dictionary:
	var gs: Node = _state()
	var data: Dictionary = {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"day": int(gs.day_number()),
		"game": (gs.game as Dictionary).duplicate(true),
		"station": int(gs.station),
		# Sixty-four bits: as words, which JSON's numbers would round.
		"run_seed": str(gs.run_seed),
		"rng_state": str(gs.rng.state),
	}
	data["state"] = {
		"resources": (gs.resources as Dictionary).duplicate(),
		"unlocks": (gs.unlocks as Dictionary).duplicate(),
		"known": (gs.known as Dictionary).duplicate(),
		"dino_stat_multipliers": (gs.dino_stat_multipliers as Dictionary).duplicate(),
		"beacon_steps": int(gs.beacon_steps),
		"beacon_charge": float(gs.beacon_charge),
		"goal": (gs.goal as Dictionary).duplicate(true),
		"day_clock": float(gs.day_clock),
		"nest_found": bool(gs.nest_found),
		"power_used": float(gs.power_used),
		"drop_misses": (gs.drop_misses as Dictionary).duplicate(),
		"wave_number": int(gs.wave_number),
		"stage_raid": bool(gs._stage_raid),
	}
	var wm: Node = main.wave_manager
	data["raids"] = {"raid_timer": float(wm.raid_timer), "warning_emitted": bool(wm.warning_emitted),
		"elapsed_time": float(wm.elapsed_time), "current_wave": int(wm.current_wave), "from_nest": int(wm._from_nest),
		"edge_turn": int(wm._edge_turn), "nest_turn": int(wm._nest_turn), "way_turn": int(wm._way_turn),
		"stage_turn": int(wm._stage_turn), "finale_sent": bool(wm._finale_sent)}
	var prowl: Node = main.get("night_prowl")
	if prowl != null:
		data["prowl"] = {"clock": float(prowl._clock), "came_tonight": int(prowl.came_tonight), "turn": int(prowl._turn),
			"was_out": bool(prowl._was_out)}
	var stats: Node = main.get("run_stats")
	if stats != null:
		data["stats"] = {"run_seconds": float(stats.run_seconds), "raids_held": int(stats.raids_held), "killed": int(stats.killed),
			"seconds_by_activity": (stats.seconds_by_activity as Dictionary).duplicate()}
	var hero: Node3D = main.hero
	data["hero"] = {"pos": _v(hero.global_position), "turn": float(hero.rotation.y), "hp": float(hero.current_hp),
		"stamina": float(hero.stamina), "torch_left": float(hero.torch_left)}
	data["cabin"] = {"hp": float(main.current_core.current_hp)}
	var buildings: Array = []
	for b in main.buildings_container.get_children():
		if b == main.current_core or not is_instance_valid(b) or b.is_queued_for_deletion() or not ("building_type" in b) \
				or bool(b.get("is_destroyed")):
			continue
		var centre: Variant = _centre_cell(main, b)
		if centre == null:
			continue
		var row: Dictionary = {"type": String(b.building_type), "cell": [(centre as Vector2i).x, (centre as Vector2i).y],
			"hp": float(b.current_hp), "built": bool(b.is_constructed), "progress": float(b.build_progress),
			"order": int(b.build_order), "upgrading_to": String(b.upgrading_to), "upgrade_progress": float(b.upgrade_progress)}
		if "facing" in b:
			row["facing"] = int(b.facing)
		if b is AmmoTower:
			row["ammo"] = String(b.ammo_type)
			row["uses"] = int(b.uses_left)
		if b is Fire:
			row["paid_night"] = int(b._paid_night)
		buildings.append(row)
	data["buildings"] = buildings
	var nodes: Array = []
	for n in main.resource_nodes_container.get_children():
		if is_instance_valid(n) and "current_amount" in n:
			nodes.append({"name": String(n.name), "amount": int(n.current_amount), "depleted": bool(n.is_depleted),
				"struck": int(n._struck)})
	data["nodes"] = nodes
	var drops: Array = []
	for p in main.get_tree().get_nodes_in_group(DropItem.GROUP):
		if is_instance_valid(p) and not bool(p.is_collected) and not p.is_queued_for_deletion():
			drops.append({"type": String(p.resource_type), "amount": int(p.amount), "pos": _v(p.global_position), "note": String(p.note)})
	data["drops"] = drops
	var nests: Array = []
	for nest in _nests(main):
		var alive: Array = []
		for i in nest.guard_dinos.size():
			var g = nest.guard_dinos[i]
			if g != null and is_instance_valid(g) and not bool(g.get("is_dead")) and not g.is_queued_for_deletion():
				alive.append({"i": i, "hp": float(g.current_hp), "pos": _v(g.global_position), "post": _v(g.post_position)})
		nests.append({"nest": String(nest.name), "guards": alive, "found": bool(nest.get_meta(&"found", false))})
	data["nests"] = nests
	if main.get("fog") != null:
		data["fog"] = Marshalls.raw_to_base64(main.fog._seen)
	var benches: Array = []
	for st in main.current_core.stations:
		if is_instance_valid(st) and not (st is HealingPod) and "active_recipe" in st:
			benches.append({"id": String(st.station_id), "job": String(st.active_recipe), "progress": float(st.progress)})
	data["benches"] = benches
	var hud: Node = main.get("hud")
	if hud != null and "_journal" in hud:
		data["journal"] = (hud._journal as Array).duplicate(true)
	return data

## The game the save was of, chosen again with its seed and station, and the run laid over the level built for it
## (Main._ready: GameState.pending_load) -- the scene built afresh, as any game chosen on the start screen is.
static func continue_game(tree: SceneTree) -> bool:
	var data: Dictionary = read()
	var gs: Node = _state()
	if data.is_empty() or gs == null:
		return false
	var game: Dictionary = data.get("game", {})
	gs.play(String(game.get("id", "campaign")), game.get("settings", {}), String(data.get("run_seed", "-1")).to_int())
	gs.station = int(data.get("station", 0))
	gs.crash_landing = false
	gs.launch_straight_in = false
	gs.pending_load = data
	if tree != null and tree.current_scene != null:
		tree.reload_current_scene()
	return true

## The saved run laid over the level `main` has just built for its game and seed (see the class's words).
static func apply(main: Node, data: Dictionary) -> void:
	var gs: Node = _state()
	var eb: Node = _bus()
	var st: Dictionary = data.get("state", {})
	# The opening's piles taken up: the save has its own.
	for p in main.get_tree().get_nodes_in_group(DropItem.GROUP):
		if is_instance_valid(p):
			p.get_parent().remove_child(p)
			p.free()
	# The buildings put up again -- paid for from a stock that is set as saved at the end.
	var plenty: Dictionary = {}
	var cfg: Node = _config()
	for res_id in cfg.RESOURCES:
		plenty[String(res_id)] = 1000000
	gs.resources = plenty
	for row in data.get("buildings", []):
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		var built: bool = bool(row.get("built", true))
		var b: Node = main.build_system.place_at(String(row["type"]), cell, main.buildings_container, not built, int(row.get("facing", 0)))
		if b == null:
			push_warning("[SaveGame] could not put back a %s at %s" % [String(row["type"]), str(cell)])
			continue
		b.current_hp = float(row.get("hp", b.current_hp))
		if not built:
			b.build_progress = float(row.get("progress", 0.0))
		b.build_order = int(row.get("order", b.build_order))
		b.upgrading_to = String(row.get("upgrading_to", ""))
		b.upgrade_progress = float(row.get("upgrade_progress", 0.0))
		if b is AmmoTower and String(row.get("ammo", "")) != "":
			b.ammo_type = String(row["ammo"])
			b.uses_left = int(row.get("uses", 0))
			b._ammo_changed()
		if b is Fire:
			b._paid_night = int(row.get("paid_night", -1))
		if b.has_method("_update_info_label"):
			b._update_info_label()
	var core: Node = main.current_core
	core.current_hp = float(data.get("cabin", {}).get("hp", core.current_hp))
	core._emit_core_hp_changed()
	# What is left in the trees, the rocks, the wrecks.
	for row in data.get("nodes", []):
		var n: Node = main.resource_nodes_container.get_node_or_null(NodePath(String(row["name"])))
		if n == null:
			continue
		n.current_amount = int(row.get("amount", n.current_amount))
		n.is_depleted = bool(row.get("depleted", false))
		n._struck = int(row.get("struck", 0))
		n._ensure_body()
		n._update_visuals()
		n._update_label()
	# The piles on the ground.
	for row in data.get("drops", []):
		var pile: Node = DropItem.spawn(main, _to_v(row["pos"]), String(row["type"]), int(row["amount"]))
		if pile != null and String(row.get("note", "")) != "":
			pile.note = String(row["note"])
	# Each nest's guards: those that were dead, gone again; those alive, where they stood.
	for row in data.get("nests", []):
		var nest: Node = null
		for candidate in _nests(main):
			if String(candidate.name) == String(row["nest"]):
				nest = candidate
		if nest == null:
			continue
		var alive: Dictionary = {}
		for g_row in row.get("guards", []):
			alive[int(g_row["i"])] = g_row
		for i in nest.guard_dinos.size():
			var g = nest.guard_dinos[i]
			if g == null or not is_instance_valid(g):
				continue
			if not alive.has(i):
				g.get_parent().remove_child(g)
				g.free()
				continue
			var g_row: Dictionary = alive[i]
			g.current_hp = float(g_row.get("hp", g.current_hp))
			g.global_position = _to_v(g_row["pos"])
			g.post_position = _to_v(g_row.get("post", g_row["pos"]))
		if bool(row.get("found", false)):
			nest.set_meta(&"found", true)
	# Him.
	var hero: Node3D = main.hero
	var h: Dictionary = data.get("hero", {})
	hero.global_position = _to_v(h.get("pos", _v(hero.global_position)))
	hero.rotation.y = float(h.get("turn", hero.rotation.y))
	hero.current_hp = float(h.get("hp", hero.current_hp))
	hero.stamina = float(h.get("stamina", hero.stamina))
	hero.torch_left = float(h.get("torch_left", 0.0))
	if float(hero.torch_left) > 0.0:
		hero._hold_the_torch()
	hero._refresh_health_bar()
	hero._tell_stamina()
	if eb:
		eb.hero_hp_changed.emit(hero.current_hp, hero.max_hp)
	core.recheck_hero()
	# The run's own numbers.
	gs.unlocks = st.get("unlocks", {})
	gs.known = st.get("known", {})
	gs.dino_stat_multipliers = st.get("dino_stat_multipliers", gs.dino_stat_multipliers)
	gs.beacon_steps = int(st.get("beacon_steps", 0))
	gs.beacon_charge = float(st.get("beacon_charge", 0.0))
	gs.day_clock = float(st.get("day_clock", gs.day_clock))
	gs._day_part = gs.day_part()
	gs.nest_found = bool(st.get("nest_found", false))
	gs.power_used = float(st.get("power_used", 0.0))
	var misses: Dictionary = {}
	for k in (st.get("drop_misses", {}) as Dictionary):
		misses[k] = int(st["drop_misses"][k])
	gs.drop_misses = misses
	gs.wave_number = int(st.get("wave_number", 0))
	gs._stage_raid = bool(st.get("stage_raid", false))
	gs.goal = st.get("goal", {})
	if eb and eb.has_signal("goal_changed"):
		eb.goal_changed.emit(gs.goal)
	var stock: Dictionary = {}
	for res_id in cfg.RESOURCES:
		stock[String(res_id)] = int((st.get("resources", {}) as Dictionary).get(String(res_id), 0))
	gs.resources = stock
	# The beacon as it stands, and the wrecks it has told of.
	core.show_the_beacon()
	for n in main.resource_nodes_container.get_children():
		if is_instance_valid(n) and "resource_type" in n and cfg.RESOURCE_NODES.get(String(n.resource_type), {}).has("found") \
				and not bool(n.is_depleted) and bool(gs.wreck_located(String(n.resource_type))):
			main._on_wreck_located(String(n.resource_type))
	# What has been seen through the mist.
	if main.get("fog") != null and data.has("fog"):
		var seen: PackedByteArray = Marshalls.base64_to_raw(String(data["fog"]))
		if seen.size() == main.fog._seen.size():
			main.fog._seen = seen
			main.fog._look()
			main.fog._paint(1.0)
			main.fog._hide_the_unseen()
	# The benches' work.
	for row in data.get("benches", []):
		var bench: Node = core.station(String(row["id"]))
		if bench != null:
			bench.active_recipe = String(row.get("job", ""))
			bench.progress = float(row.get("progress", 0.0))
	# The next raid's clock, the ways in in turn, the night's prowl, the run's account.
	var wm: Node = main.wave_manager
	var r: Dictionary = data.get("raids", {})
	wm.raid_timer = float(r.get("raid_timer", wm.raid_timer))
	wm.warning_emitted = bool(r.get("warning_emitted", false))
	wm.elapsed_time = float(r.get("elapsed_time", 0.0))
	wm.current_wave = int(r.get("current_wave", 0))
	wm._from_nest = int(r.get("from_nest", 0))
	wm._edge_turn = int(r.get("edge_turn", 0))
	wm._nest_turn = int(r.get("nest_turn", 0))
	wm._way_turn = int(r.get("way_turn", 0))
	wm._stage_turn = int(r.get("stage_turn", 0))
	wm._finale_sent = bool(r.get("finale_sent", false))
	var prowl: Node = main.get("night_prowl")
	if prowl != null and data.has("prowl"):
		var p: Dictionary = data["prowl"]
		prowl._clock = float(p.get("clock", 0.0))
		prowl.came_tonight = int(p.get("came_tonight", 0))
		prowl._turn = int(p.get("turn", 0))
		prowl._was_out = bool(p.get("was_out", false))
	var stats: Node = main.get("run_stats")
	if stats != null and data.has("stats"):
		var s: Dictionary = data["stats"]
		stats.run_seconds = float(s.get("run_seconds", 0.0))
		stats.raids_held = int(s.get("raids_held", 0))
		stats.killed = int(s.get("killed", 0))
		stats.seconds_by_activity = s.get("seconds_by_activity", {})
	# The journal, and the goal his.
	var hud: Node = main.get("hud")
	if hud != null and "_journal" in hud:
		hud._journal = data.get("journal", [])
		hud._objective_given = true
		hud._refresh_beacon_label()
		hud._render_journal()
		if hud.has_method("_refresh_minimap"):
			hud._refresh_minimap()
	if eb:
		eb.resources_changed.emit(gs.resources)
		if eb.has_signal("power_changed"):
			eb.power_changed.emit(gs.power_left())
	# The dice where they had got to: what comes next comes as it would have.
	gs.run_seed = String(data.get("run_seed", str(gs.run_seed))).to_int()
	gs.rng.state = String(data.get("rng_state", str(gs.rng.state))).to_int()

## Main's nests: its own and a harder game's others.
static func _nests(main: Node) -> Array:
	var out: Array = []
	if main.get("current_nest") != null and is_instance_valid(main.current_nest):
		out.append(main.current_nest)
	var extra: Variant = main.get("extra_nests")
	if extra is Array:
		for n in extra:
			if n != null and is_instance_valid(n):
				out.append(n)
	return out

## The build cell a building stands with its middle in (GridManager.footprint_cells, the other way): its least cell and
## half its size less one -- its position, for an even size, is on a corner between cells.
static func _centre_cell(main: Node, b: Node) -> Variant:
	var cells: Array = main.grid_manager.cells_of(b)
	if cells.is_empty():
		return null
	var least := Vector2i(cells[0])
	for c in cells:
		least = Vector2i(mini(least.x, (c as Vector2i).x), mini(least.y, (c as Vector2i).y))
	var size: Vector2i = _config().get_building_size(String(b.building_type))
	return least + Vector2i((size.x - 1) / 2, (size.y - 1) / 2)

static func _v(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _to_v(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if (a is Array and (a as Array).size() >= 3) else Vector3.ZERO

static func _state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameState") if tree else null

static func _bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("EventBus") if tree else null

static func _config() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Config") if tree else null
