# res://debug-agent/tools/probe.gd -- debug-agent's own targeted checks.
#
#   godot --path . --resolution 1600x900 --script res://debug-agent/tools/probe.gd -- <probe> ...
#
# Each probe loads a fresh level, drives it through the game's own API (like tools/playtest.gd),
# and prints one line per verdict:  [probe] <name> PASS|FAIL|INFO: <detail>
# Frames go to $DA_OUT (default res://debug-agent/runs/adhoc). Read-only on the game: nothing
# here is saved anywhere but under debug-agent/.
extends SceneTree

const SETTLE_FRAMES := 30
var OUT_DIR: String = OS.get_environment("DA_OUT") if OS.get_environment("DA_OUT") != "" else "res://debug-agent/runs/adhoc"
var _main: Node = null
var _probe: String = ""
var _shot: int = 0

func _init() -> void:
	await process_frame   # autoloads (I18n) must be in the tree first -- see tools/playtest.gd rule 1
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var names: Array = []
	for a in OS.get_cmdline_user_args():
		names.append(String(a))
	if names.is_empty():
		names = ["all"]
	if names == ["all"]:
		names = ["stage_wave_size", "stage_first", "pause_snapshot", "cabin_sortie", "launch_button", "gate_traffic", "build_under_him", "after_the_jump", "pause_raid", "kit_row", "boss_drops"]
	for n in names:
		_probe = n
		await _fresh_level()
		match n:
			"stage_wave_size": await _p_stage_wave_size()
			"stage_first": await _p_stage_first()
			"pause_snapshot": await _p_pause_snapshot()
			"cabin_sortie": await _p_cabin_sortie()
			"launch_button": await _p_launch_button()
			"gate_traffic": await _p_gate_traffic()
			"build_under_him": await _p_build_under_him()
			"after_the_jump": await _p_after_the_jump()
			"pause_raid": await _p_pause_raid()
			"kit_row": await _p_kit_row()
			"round5": await _p_round5()
			"round5_shots": await _p_round5_shots()
			"corridor": await _p_corridor()
			"corner_look": await _p_corner_look()
			"wrecks_look": await _p_wrecks_look()
			"wreck_search": await _p_wreck_search()
			"commands_order": await _p_commands_order()
			"worked_look": await _p_worked_look()
			"restart_twice": await _p_restart_twice()
			"kit_slots": await _p_kit_slots()
			"bitten_on_the_way": await _p_bitten_on_the_way()
			"fire_night": await _p_fire_night()
			"prowl": await _p_prowl()
			"raid_count": await _p_raid_count()
			"mist_hours": await _p_mist_hours()
			"edge_plain": await _p_edge_raid("plain")
			"edge_nest_watched": await _p_edge_raid("nest_watched")
			"edge_edge_watched": await _p_edge_raid("edge_watched")
			"edge_final": await _p_edge_raid("final")
			"guard_warn": await _p_guard_warn()
			"reach_all": await _p_reach_all()
			"settings_map": await _p_settings_map()
			"routes": await _p_routes()
			"fence_in_their_way": await _p_fence_in_their_way()
			"build_hitch": await _p_build_hitch()
			"gaps": await _p_gaps()
			"boss_rams": await _p_boss_rams()
			"defeat_guard": await _p_defeat("guard")
			"defeat_raider": await _p_defeat("raider")
			"defeat_alone": await _p_defeat("alone")
			"defeat_cabin": await _p_defeat("cabin")
			"herocard_keys": await _p_herocard_keys()
			"nest_stone_east": await _p_nest_stone("east")
			"nest_stone_west": await _p_nest_stone("west")
			"mist": await _p_mist()
			"ring_traps": await _p_ring_traps()
			"black_fog": await _p_black_fog()
			"fps": await _p_fps()
			"twitch_cam": await _p_twitch_cam()
			"quiet": await _p_quiet()
			"build_under_dino": await _p_build_under_dino()
			"guards": await _p_guards()
			"fog": await _p_fog()
			"dusk_raid": await _p_dusk_raid()
			"edge_pan": await _p_edge_pan()
			"half_fence": await _p_half_fence(false)
			"half_fence_bare": await _p_half_fence(true)
			"boss_drops": await _p_boss_drops()
			_: _say("INFO", "unknown probe")
		_tear_down()
	quit(0)

# ------------------------------------------------------------------------------
# Probes
# ------------------------------------------------------------------------------

## A beacon stage repaired while a BIG raid's warning is running (GAME-DESIGN 8.3, as decided after
## BUG-001: the stage's small raid comes ON TOP -- its own clock and warning, stage_waves' count, no
## leader; the clock's raids, their count and the big raid's turn unchanged; a raid out is fought
## first). Follows the whole sequence: raid 3, then the stage's raid, then the clock's raid 4.
func _p_stage_wave_size() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var log: Array = []
	var clock := {"t": 0.0}
	var on_warn := func(left): log.append("%5.1fs warning (%.0fs)" % [clock["t"], left])
	# The roster is read as the raid sets out: it empties as they step out.
	var rosters: Array = []
	var on_start := func(n, big):
		log.append("%5.1fs wave_started n=%d big=%s roster=%s stage=%s" % [clock["t"], n, big, str(wm.wave_roster), wm.stage_wave])
		rosters.append({"stage": wm.stage_wave, "roster": wm.wave_roster.duplicate(), "big": big})
	var on_stage := func(size): log.append("%5.1fs stage_wave_started(%d)" % [clock["t"], size])
	var on_end := func(n): log.append("%5.1fs wave_ended n=%d (gs.wave_number %d)" % [clock["t"], n, gs.wave_number])
	eb.raid_warning.connect(on_warn)
	eb.wave_started.connect(on_start)
	eb.stage_wave_started.connect(on_stage)
	eb.wave_ended.connect(on_end)
	# Control: the same moment with no stage repaired, for raid 3's roster.
	wm.elapsed_time = 300.0
	wm.current_wave = 2
	gs.wave_number = 2
	var control: Array = wm.roster_for(3, wm.get_wave_dino_count(3))
	# Five minutes in, raid 2 held, raid 3 (big) 12 s away and announced; stage 1 repaired now.
	wm.raid_timer = 12.0
	wm.warning_emitted = true
	gs.finish_beacon_job(String(gs.beacon_next_job()))
	log.append("  0.0s stage 1 repaired (raid 3 due in 12 s)")
	# Raid 3's own warning was given before the probe began (warning_emitted above): as if at 0 s.
	log.append("  0.0s warning (12s) [given before the probe]")
	var raid3: Array = []
	var stage: Array = []
	var raid4: Array = []
	var hud_said: String = ""
	while clock["t"] < 240.0 and raid4.is_empty():
		await _advance(0.5)
		clock["t"] += 0.5
		if wm.is_wave_active and wm.dinos_spawned_count >= wm.dinos_to_spawn:
			# The line holds: everything the raid sent dies once it is all out.
			var last: Dictionary = rosters[rosters.size() - 1]
			if last["stage"] and stage.is_empty():
				stage = last["roster"]
				hud_said = _hud_wave_text()
			elif not last["stage"] and raid3.is_empty():
				raid3 = last["roster"]
			elif not last["stage"] and not raid3.is_empty() and not stage.is_empty():
				raid4 = last["roster"]
				break
			await _advance(1.0)
			clock["t"] += 1.0
			for d in get_nodes_in_group("dinos"):
				if is_instance_valid(d) and not (d is GuardDino):
					d.take_damage(99999.0)
	for c in [[eb.raid_warning, on_warn], [eb.wave_started, on_start], [eb.stage_wave_started, on_stage], [eb.wave_ended, on_end]]:
		(c[0] as Signal).disconnect(c[1])
	for line in log:
		_say("INFO", line)
	_say("INFO", "HUD wave line during the stage raid: '%s' (expected '%s')" % [hud_said, tr("HUD_STAGE_WAVE")])
	var alpha: String = String(gs.map_data()["minor_boss"])
	# Raid 3's rank and file are drawn with the run's dice (RAIDS.intensity_*): the control is its
	# count before them, so "the same" is: the alpha at its head and no fewer than the dice allow.
	var ok3: bool = raid3.has(alpha) and raid3.size() - 1 >= int(round((control.size() - 1) * 0.5))
	var ok_stage: bool = stage.size() == int(gs.map_data()["beacon"]["stage_waves"][0]) and not stage.has(alpha)
	_say("PASS" if ok3 else "FAIL", "raid 3 in the stage's shadow: %d %s, control %d" % [raid3.size(), "with the alpha" if raid3.has(alpha) else "NO alpha", control.size()])
	_say("PASS" if ok_stage else "FAIL", "the stage's own raid after it: %s" % str(stage))
	_say("PASS" if hud_said == tr("HUD_STAGE_WAVE") else "FAIL", "HUD names the stage raid")
	_say("PASS" if not raid4.is_empty() else "FAIL", "the clock's raid 4 still comes after: %s" % str(raid4))
	_check_warnings(log)

## Every warning against the raid that followed it: one warning per raid, and "N s" true to 1 s.
## `log` lines are the timeline printed above ("  7.0s warning (15s)", " 11.5s wave_started ...").
func _check_warnings(log: Array) -> void:
	var events: Array = []
	for line in log:
		var t: float = float(String(line).strip_edges().split("s ")[0])
		if String(line).contains("warning ("):
			var left: float = float(String(line).split("warning (")[1].split("s)")[0])
			events.append(["warn", t, left])
		elif String(line).contains(" wave_started n="):
			events.append(["start", t, 0.0])
	var bad: Array = []
	var pending: Array = []
	for e in events:
		if e[0] == "warn":
			pending.append(e)
		else:
			if pending.is_empty():
				bad.append("raid at %.1fs had no warning" % e[1])
			elif pending.size() > 1:
				bad.append("raid at %.1fs had %d warnings" % [e[1], pending.size()])
			else:
				var said: float = float(pending[0][1]) + float(pending[0][2])
				if absf(said - float(e[1])) > 1.0:
					bad.append("warned at %.1fs for %.0fs (-> %.1fs), came at %.1fs" % [pending[0][1], pending[0][2], said, e[1]])
			pending.clear()
	_say("PASS" if bad.is_empty() else "FAIL", "warnings: one per raid, true to 1 s%s" % (("; " + "; ".join(bad)) if not bad.is_empty() else ""))

## TASK-007 the other way round: a stage repaired with the clock's raid 30 s off and unannounced --
## the stage's raid (22 s) is warned of first and alone; the clock's is warned of again after it.
func _p_stage_first() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var log: Array = []
	var clock := {"t": 0.0}
	var on_warn := func(left): log.append("%5.1fs warning (%.0fs)" % [clock["t"], left])
	var on_start := func(n, big): log.append("%5.1fs wave_started n=%d big=%s roster=%s stage=%s" % [clock["t"], n, big, str(wm.wave_roster), wm.stage_wave])
	eb.raid_warning.connect(on_warn)
	eb.wave_started.connect(on_start)
	gs.day_clock = 110.0
	wm.elapsed_time = 120.0
	wm.current_wave = 1
	gs.wave_number = 1
	wm.raid_timer = 30.0
	wm.warning_emitted = false
	gs.finish_beacon_job(String(gs.beacon_next_job()))
	log.append("  0.0s stage 1 repaired (raid 2 due in 30 s)")
	var starts := 0
	while clock["t"] < 200.0 and starts < 2:
		await _advance(0.5)
		clock["t"] += 0.5
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		if wm.is_wave_active and wm.dinos_spawned_count >= wm.dinos_to_spawn:
			starts += 1
			await _advance(1.0)
			clock["t"] += 1.0
			for d in get_nodes_in_group("dinos"):
				if is_instance_valid(d) and not (d is GuardDino):
					d.take_damage(99999.0)
			while wm.is_wave_active and clock["t"] < 200.0:
				await _advance(0.5)
				clock["t"] += 0.5
	eb.raid_warning.disconnect(on_warn)
	eb.wave_started.disconnect(on_start)
	for line in log:
		_say("INFO", line)
	_check_warnings(log)

func _hud_wave_text() -> String:
	for n in _all(_main):
		if "wave_label" in n and n.wave_label is Label:
			return (n.wave_label as Label).text
	return "(no HUD wave_label found)"

## GAME-DESIGN 3: 暂停就是定格 -- units, raids, timers, animations, world sounds all hold still.
func _p_pause_snapshot() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	var hero = _main.hero
	wm.start_wave(1, 4)
	hero.move_to(_main.current_core.global_position + Vector3(6, 0, 6))
	await _advance(4.0)
	var before := _snapshot()
	gs.set_paused(true)
	await _shoot("paused_a")
	for i in range(180):
		await process_frame
	var after := _snapshot()
	await _shoot("paused_b")
	var moved: Array = []
	for k in before:
		if not after.has(k):
			moved.append("%s (gone)" % k)
		elif typeof(before[k]) == TYPE_VECTOR3 and (before[k] as Vector3).distance_to(after[k]) > 0.001:
			moved.append("%s %s -> %s" % [k, before[k], after[k]])
		elif typeof(before[k]) == TYPE_FLOAT and absf(float(before[k]) - float(after[k])) > 0.001:
			moved.append("%s %.3f -> %.3f" % [k, before[k], after[k]])
	gs.set_paused(false)
	_say("PASS" if moved.is_empty() else "FAIL", "%d of %d tracked values changed during 3 s of pause%s" % [moved.size(), before.size(), (": " + "; ".join(moved.slice(0, 12))) if not moved.is_empty() else ""])

func _snapshot() -> Dictionary:
	var s := {}
	var wm = _main.wave_manager
	s["raid_timer"] = float(wm.raid_timer)
	s["elapsed"] = float(wm.elapsed_time)
	s["hero"] = (_main.hero as Node3D).global_position
	var i := 0
	for d in get_nodes_in_group("dinos"):
		if d is Node3D:
			s["dino%d@%s" % [i, d.name]] = (d as Node3D).global_position
			i += 1
	for n in _all(_main):
		if n is AnimationPlayer and (n as AnimationPlayer).is_playing():
			s["anim:" + str(_main.get_path_to(n))] = float((n as AnimationPlayer).current_animation_position)
		elif n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).playing:
			s["sound:" + str(_main.get_path_to(n))] = float((n as AudioStreamPlayer3D).get_playback_position())
		elif n is Timer and not (n as Timer).is_stopped():
			s["timer:" + str(_main.get_path_to(n))] = float((n as Timer).time_left)
	return s

## GAME-DESIGN 8.1: 人在舱里不会自己出去打 -- idle inside, he only meets what is on his side of the
## wall; a raider biting the cabin's back wall must not draw him out.
func _p_cabin_sortie() -> void:
	var cabin = _main.current_core
	var hero = _main.hero
	_main._walk_to_bench(cabin.station("workbench"))
	var t := 0.0
	while not cabin.hero_inside and t < 30.0:
		await _advance(0.25)
		t += 0.25
	if not cabin.hero_inside:
		_say("FAIL", "could not get him into the cabin in 30 s")
		return
	await _advance(2.0)
	var cfg := root.get_node("Config")
	var species: String = String(root.get_node("GameState").map_data()["raiders"].keys()[0])
	var d = load(String(cfg.get_dino_script_path(species))).new()
	_main.add_child(d)
	d.setup(species)
	var core: Vector3 = (cabin as Node3D).global_position
	d.global_position = core + Vector3(0.0, 0.0, -3.2)   # behind the back (north) wall
	d.set_waypoints([core])
	var left := false
	var worst := ""
	t = 0.0
	while t < 20.0:
		await _advance(0.25)
		t += 0.25
		if not cabin.hero_inside:
			left = true
			worst = "left the cabin at %.1fs (state %d)" % [t, int(hero.current_state)]
			break
	await _portrait("sortie_end", core, 10.0)
	_say("FAIL" if left else "PASS", worst if left else "stayed inside 20 s with a %s biting the back wall" % species)

## The launch pressed the way a player presses it: the beacon's bench selected, its button clicked.
## Once launched there is nothing left to launch -- the button must not stay on the card.
func _p_launch_button() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var bench = _main.current_core.station("beacon")
	_main._walk_to_bench(bench)
	var t := 0.0
	while not _main.current_core.hero_inside and t < 30.0:
		await _advance(0.25)
		t += 0.25
	for i in range(int(gs.beacon_stage_count())):
		gs.finish_beacon_job(String(gs.beacon_next_job()))
	eb.unit_selected.emit(bench)
	await _advance(0.5)
	var label: String = tr("BEACON_LAUNCH_NAME")
	var before: Array = _visible_buttons(label)
	if before.is_empty():
		_say("FAIL", "no visible '%s' button on the bench's card before launching" % label)
		return
	(before[0] as BaseButton).pressed.emit()
	await _advance(1.0)
	var launched: bool = gs.is_beacon_launched()
	var after1: int = _visible_buttons(label).size()
	await _advance(10.0)
	var after10: int = _visible_buttons(label).size()
	await _shoot("after_launch")
	_say("INFO", "launched: %s; '%s' buttons visible: before %d, 1 s after %d, 11 s after %d" % [launched, label, before.size(), after1, after10])
	_say("FAIL" if (launched and after10 > 0) else "PASS", "launch button %s after the launch" % ("STILL SHOWN" if after10 > 0 else "gone"))
	if after10 > 0:
		var charge_before: float = float(gs.beacon_charge)
		var steps_before: int = int(gs.beacon_steps)
		(_visible_buttons(label)[0] as BaseButton).pressed.emit()
		await _advance(1.0)
		_say("INFO", "pressed again: beacon_steps %d -> %d, charge %.1f -> %.1f, bench job '%s'" % [steps_before, int(gs.beacon_steps), charge_before, float(gs.beacon_charge), String(bench.active_recipe)])
		eb.unit_selected.emit(_main.hero)
		await _advance(0.5)
		eb.unit_selected.emit(bench)
		await _advance(0.5)
		_say("INFO", "after selecting the hero and the bench again: %d launch buttons visible" % _visible_buttons(label).size())
		await _shoot("reselected")

func _visible_buttons(text: String) -> Array:
	var out: Array = []
	for n in _all(root):
		if n is Button and (n as Button).is_visible_in_tree():
			var s: String = (n as Button).text
			for c in n.get_children():
				if c is Label:
					s += " " + (c as Label).text
			if s.to_lower().contains(text.to_lower()):
				out.append(n)
	return out

## GAME-DESIGN 3 墙挡所有人: a ring of palisade round the cabin, a gate at its door. He goes in and
## out through the gate ten times without sticking; a raider sent at the cabin never gets through it.
func _p_gate_traffic() -> void:
	var cabin = _main.current_core
	var hero = _main.hero
	var gm = _main.grid_manager
	var gate_cell: Vector2i = _ring_round_the_cabin()
	var gate_at: Vector3 = gm.build_cell_to_world(gate_cell)
	var built := 0
	for b in gm.get_all_buildings():
		if is_instance_valid(b) and "building_type" in b and String(b.building_type) in ["wall", "gate"]:
			built += 1
	_say("INFO", "ring: %d sections incl. the gate (%s)" % [built, "gate up" if gm.building_in_build_cell(gate_cell) != null else "NO GATE"])
	_main.nav_maps.rebake()
	await _advance(1.0)
	var outside: Vector3 = gate_at + Vector3(0.0, 0.0, 5.0)
	var worst := 0.0
	var stuck: Array = []
	for trip in range(10):
		var goal: Vector3 = cabin.door_inside() if trip % 2 == 0 else outside
		hero.move_to(goal)
		var t := 0.0
		var still := 0.0
		var was: Vector3 = hero.global_position
		var arrived := false
		while t < 25.0:
			await _advance(0.25)
			t += 0.25
			var moved: float = hero.global_position.distance_to(was)
			was = hero.global_position
			still = (still + 0.25) if (moved < 0.02 and int(hero.current_state) == 1) else 0.0
			if still >= 2.0 and stuck.size() < 5:
				stuck.append("trip %d stood still 2 s at %s" % [trip, str(gm.world_to_build_cell(hero.global_position))])
				still = -999.0
			var there: bool = cabin.hero_inside if trip % 2 == 0 else hero.global_position.distance_to(goal) < 0.8
			if there:
				arrived = true
				break
		worst = maxf(worst, t)
		if not arrived:
			stuck.append("trip %d (%s) never arrived in 25 s, at %s" % [trip, "in" if trip % 2 == 0 else "out", str(gm.world_to_build_cell(hero.global_position))])
			await _shoot("stuck_trip_%d" % trip)
	_say("FAIL" if not stuck.is_empty() else "PASS", "10 trips through the gate, slowest %.1f s%s" % [worst, ("; " + "; ".join(stuck)) if not stuck.is_empty() else ""])
	# The gate is a wall to a raider.
	hero.move_to(cabin.door_inside())
	await _advance(6.0)
	var species: String = String(root.get_node("GameState").map_data()["raiders"].keys()[0])
	var d = load(String(root.get_node("Config").get_dino_script_path(species))).new()
	_main.add_child(d)
	d.setup(species)
	d.max_hp = 9999.0
	d.current_hp = 9999.0
	d.global_position = outside
	d.set_waypoints([(cabin as Node3D).global_position])
	var closest := 99.0
	var gate = gm.building_in_build_cell(gate_cell)
	for i in range(80):
		await _advance(0.25)
		if not is_instance_valid(d):
			break
		var f: Vector3 = (d as Node3D).global_position - gate_at
		# How far inside the ring line it got (the gate's north edge is +0.5 m in).
		closest = minf(closest, f.z)
	await _portrait("raider_at_gate", gate_at, 9.0)
	var gate_hp: String = ("%.1f/%.1f" % [gate.current_hp, gate.max_hp]) if is_instance_valid(gate) else "gone"
	_say("FAIL" if closest < -0.6 else "PASS", "a raider at the gate for 20 s got to %.2f m from the gate line (negative = inside); gate hp %s" % [closest, gate_hp])

## Puts up a ring of palisade one cell out round the cabin, a gate at the door; returns the gate's cell.
func _ring_round_the_cabin() -> Vector2i:
	var cfg := root.get_node("Config")
	var gm = _main.grid_manager
	var centre: Vector2i = gm.world_to_build_cell(_main.current_core.global_position)
	var half := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
	var gate_cell: Vector2i = centre + Vector2i(0, half.y + 1)
	_build_at("gate", gate_cell)
	for x in range(-half.x - 1, half.x + 2):
		for z in [-half.y - 1, half.y + 1]:
			var c: Vector2i = centre + Vector2i(x, z)
			if c != gate_cell:
				_build_at("wall", c)
	for z in range(-half.y, half.y + 1):
		for x in [-half.x - 1, half.x + 1]:
			_build_at("wall", centre + Vector2i(x, z))
	return gate_cell

## place_at CHARGES the price: paid here first, or nothing goes up (the first gate_traffic and
## half_fence runs "passed" with no fence at all -- a lesson: count what was built).
func _build_at(type_id: String, cell: Vector2i) -> Node:
	var gs := root.get_node("GameState")
	for r in root.get_node("Config").BUILDINGS[type_id].get("cost", {}):
		gs.resources[r] = int(gs.resources.get(r, 0)) + int(root.get_node("Config").BUILDINGS[type_id]["cost"][r])
	var b = _main.build_system.place_at(type_id, cell, _main.buildings_container, true, 0)
	if b == null:
		_say("INFO", "could not place %s at %s" % [type_id, str(cell)])
	if b != null and b.has_method("complete_construction"):
		b.complete_construction()
	return b

## GAME-DESIGN 3 放置不看人: a palisade ordered on the cell he is standing in goes down; he steps out
## of it first, and it closes once he is clear. Ordered the way a click orders it.
func _p_build_under_him() -> void:
	var gs := root.get_node("GameState")
	var gm = _main.grid_manager
	var hero = _main.hero
	gs.resources["wood"] = 20
	var spot: Vector3 = _main.current_core.global_position + Vector3(4.0, 0.0, 5.0)
	hero.move_to(spot)
	await _advance(6.0)
	var cell: Vector2i = gm.world_to_build_cell(hero.global_position)
	_main.on_build_selected("wall")
	var at: Vector3 = gm.build_cell_to_world(cell)
	var b = _main.try_place_at_cell(gm.world_to_cell(at), at)
	_main.cancel_building_selection()
	if b == null:
		_say("FAIL", "the order on his own cell %s was refused" % str(cell))
		return
	var t := 0.0
	while t < 20.0 and not b.is_constructed:
		await _advance(0.25)
		t += 0.25
	var his: Vector2i = gm.world_to_build_cell(hero.global_position)
	if not b.is_constructed:
		await _shoot("not_closed")
	_say("PASS" if b.is_constructed and his != cell else "FAIL", "palisade on his cell %s: %s after %.1f s; he now stands in %s" % [str(cell), "built" if b.is_constructed else "NOT built", t, str(his)])

## After the jump (game won): what still moves. Informational -- the design says nothing, but a
## run whose stock or kill count still changes under the summary screen reads as a bug.
func _p_after_the_jump() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	var hero = _main.hero
	wm.start_wave(1, 4)
	await _advance(6.0)
	for i in range(int(gs.beacon_stage_count()) + 1):
		gs.finish_beacon_job(String(gs.beacon_next_job()))
	gs.charge_beacon(100000.0)
	await _advance(0.5)
	var before := _snapshot()
	var res_before: Dictionary = gs.resources.duplicate()
	hero.move_to(hero.global_position + Vector3(5.0, 0.0, 0.0))
	await _advance(5.0)
	var after := _snapshot()
	var moved: Array = []
	for k in before:
		if String(k).begins_with("dino") or k == "hero":
			if after.has(k) and (before[k] as Vector3).distance_to(after[k]) > 0.05:
				moved.append(String(k).split("@")[0])
	await _shoot("after_the_jump")
	_say("INFO", "game over: %s; paused tree: %s; 5 s after the jump these still moved: %s; stock changed: %s" % [gs.is_game_over, paused, str(moved), str(res_before != gs.resources)])

## TASK-001 (GAME-DESIGN 3 暂停就是定格), in the case the player reported: a raid biting the cabin,
## the cabin's gun firing, a meal's clock running. Paused 10 s: every transform, bone pose, animation,
## timer, world sound and hit point in the level stays put -- while the camera still pans and turns,
## a card still opens its submenu and the pause menu still opens. Unpaused, it all moves again.
func _p_pause_raid() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	var cabin = _main.current_core
	var hero = _main.hero
	gs.fed = {"dish": "meat", "method": "roast", "build_speed": 1.3, "move_speed": 1.0, "max_hp": 0.0, "seconds_left": 90.0, "seconds_total": 90.0}
	_main._walk_to_bench(cabin.station("workbench"))
	wm.start_wave(1, 6)
	var t := 0.0
	while t < 60.0 and cabin.current_hp >= cabin.max_hp - 0.01:
		await _advance(0.5)
		t += 0.5
		for d in get_nodes_in_group("dinos"):
			if is_instance_valid(d) and not (d is GuardDino) and d.max_hp < 999.0:
				d.max_hp = 9999.0
				d.current_hp = 9999.0
	await _advance(2.0)
	var biting: int = 0
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and int(d.current_state) == int(d.State.ATTACKING):
			biting += 1
	_say("INFO", "set-up: cabin %.1f/%.0f after %.1f s, %d raiders biting, fed %.1f s left" % [cabin.current_hp, cabin.max_hp, t, biting, float(gs.fed.get("seconds_left", -1.0))])
	var before := _deep_snapshot()
	gs.set_paused(true)
	await _shoot("paused_raid")
	# Ten seconds of the player doing things while paused.
	var rig = _main.camera_rig
	var focus0: Vector3 = rig.focus
	var yaw0: float = float(rig.yaw)
	_key(KEY_A, true)
	for i in range(60):
		await process_frame
	_key(KEY_A, false)
	_key(KEY_Q, true)
	for i in range(30):
		await process_frame
	_key(KEY_Q, false)
	var panned: float = rig.focus.distance_to(focus0)
	var turned: float = absf(float(rig.yaw) - yaw0)
	root.get_node("EventBus").unit_selected.emit(hero)
	for i in range(10):
		await process_frame
	var build_btn: Array = _visible_buttons(tr("CMD_BUILD")) if tr("CMD_BUILD") != "HERO_CMD_BUILD" else []
	if build_btn.is_empty():
		build_btn = _visible_buttons("Build")
	var submenu := false
	if not build_btn.is_empty():
		(build_btn[0] as BaseButton).pressed.emit()
		for i in range(10):
			await process_frame
		submenu = not _visible_buttons(tr("BUILDING_WALL_NAME")).is_empty()
	var hud = _find_with_method(_main, "toggle_pause_menu")
	var menu_open := false
	if hud != null:
		hud.toggle_pause_menu()
		for i in range(10):
			await process_frame
		menu_open = not _visible_buttons(tr("MENU_RESUME")).is_empty() if tr("MENU_RESUME") != "PAUSE_RESUME" else _any_visible_popup()
		await _shoot("paused_menu")
		hud.toggle_pause_menu()
	for i in range(600 - 110):
		await process_frame
	var after := _deep_snapshot()
	var changed := _diff(before, after)
	_say("PASS" if changed.is_empty() else "FAIL", "10 s paused: %d of %d level values changed%s" % [changed.size(), before.size(), (": " + "; ".join(changed.slice(0, 15))) if not changed.is_empty() else ""])
	_say("PASS" if panned > 0.5 and turned > 0.01 else "FAIL", "camera while paused: panned %.2f m, turned %.3f rad" % [panned, turned])
	_say("PASS" if submenu else "FAIL", "the hero's card opened the build submenu while paused (build button found: %s)" % (not build_btn.is_empty()))
	_say("PASS" if menu_open else "FAIL", "the pause menu opened while paused")
	gs.set_paused(false)
	if gs.is_paused:
		gs.set_paused(false)
	await _advance(3.0)
	var resumed := _diff(after, _deep_snapshot())
	_say("PASS" if resumed.size() > 10 else "FAIL", "3 s after resuming: %d values moved on (paused: %s)" % [resumed.size(), gs.is_paused])

func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _find_with_method(n: Node, m: String) -> Node:
	for c in _all(n):
		if c.has_method(m):
			return c
	return null

func _any_visible_popup() -> bool:
	for n in _all(root):
		if n is Control and (n as Control).is_visible_in_tree() and String(n.name).to_lower().contains("pause"):
			return true
	return false

## Everything in the level that moves, at full precision: transforms (not the camera's), bone poses,
## animation clocks, timers, world sounds, hit points, and the run's clocks.
func _deep_snapshot() -> Dictionary:
	var s := {}
	var gs := root.get_node("GameState")
	s["gs.fed_left"] = float(gs.fed.get("seconds_left", -1.0))
	s["gs.beacon_charge"] = float(gs.beacon_charge)
	s["gs.final_wave_in"] = float(gs.final_wave_in)
	s["wm.raid_timer"] = float(_main.wave_manager.raid_timer)
	for n in _all(_main):
		if n is Camera3D or n is Control or n is CanvasLayer:
			continue
		var key: String = str(_main.get_path_to(n))
		if n is Node3D and (n as Node3D).is_inside_tree():
			var tf: Transform3D = (n as Node3D).global_transform
			s["xf:" + key] = "%.4f,%.4f,%.4f|%.4f,%.4f,%.4f" % [tf.origin.x, tf.origin.y, tf.origin.z, tf.basis.x.x, tf.basis.x.z, tf.basis.z.x]
		if n is Skeleton3D:
			var sk := n as Skeleton3D
			var acc := 0.0
			for b in range(sk.get_bone_count()):
				var q: Quaternion = sk.get_bone_pose_rotation(b)
				acc += q.x * 1.0 + q.y * 3.0 + q.z * 7.0 + sk.get_bone_pose_position(b).length()
			s["bones:" + key] = "%.5f" % acc
		if n is AnimationPlayer and (n as AnimationPlayer).is_playing():
			s["anim:" + key] = "%.4f" % (n as AnimationPlayer).current_animation_position
		if n is Timer and not (n as Timer).is_stopped():
			s["timer:" + key] = "%.4f" % (n as Timer).time_left
		if n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).playing:
			s["sound:" + key] = "%.3f" % (n as AudioStreamPlayer3D).get_playback_position()
		if "current_hp" in n:
			s["hp:" + key] = "%.4f" % float(n.current_hp)
	return s

func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in a:
		if not b.has(k):
			out.append("%s gone" % k)
		elif str(a[k]) != str(b[k]):
			out.append("%s %s -> %s" % [k, str(a[k]), str(b[k])])
	for k in b:
		if not a.has(k):
			out.append("%s new" % k)
	return out

## TASK-003 part 1-2: every workbench item made at the bench, in an order that tests the replacing:
## the bone spear before the stone one, the bone armour before the vest. After each: his row
## (Config.kit), what the bench still offers, and his hit points, speed and damage against RECIPES.
func _p_kit_row() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var cabin = _main.current_core
	var hero = _main.hero
	var wb = cabin.station("workbench")
	for r in ["wood", "stone", "bone", "hide"]:
		gs.resources[r] = 60
		gs.known[r] = true
	_main._walk_to_bench(wb)
	var t := 0.0
	while not cabin.hero_inside and t < 30.0:
		await _advance(0.25)
		t += 0.25
	Engine.time_scale = 4.0
	var bad: Array = []
	for job in ["stone_pick", "stone_axe", "bone_spear", "bone_armor", "quarry_pick", "hide_boots"]:
		if not wb.can_offer(job):
			bad.append("%s not on offer when it should be" % job)
			continue
		if not wb.begin(job):
			bad.append("%s refused" % job)
			continue
		t = 0.0
		while String(wb.active_recipe) != "" and t < 40.0:
			await _advance(0.25)
			t += 0.25
		var row: Dictionary = cfg.kit(gs.unlocks)
		var offered: Array = []
		for j in wb.jobs():
			if wb.can_offer(String(j)):
				offered.append(String(j))
		_say("INFO", "made %s -> row %s | still offered %s | hp %.1f/%.1f speed %.2f damage %.2f" % [job, str(row), str(offered), hero.current_hp, hero.max_hp, hero.speed, hero.damage])
		if job == "bone_spear" and offered.has("stone_spear"):
			bad.append("stone spear still offered after the bone spear")
		if job == "bone_armor" and offered.has("hide_vest"):
			bad.append("hide vest still offered after the bone armour")
		if job == "quarry_pick" and String(row.get("pick", "")) != "quarry_pick":
			bad.append("the stone pick did not replace the bone pick in the row")
	Engine.time_scale = 1.0
	var want_hp: float = float(cfg.HERO["hp"]) + float(cfg.RECIPES["bone_armor"]["max_hp"])
	var want_speed: float = float(cfg.HERO["move_speed"]) * float(cfg.RECIPES["hide_boots"]["move_speed"])
	var want_dmg: float = float(cfg.HERO["damage"]) * float(cfg.RECIPES["bone_spear"]["damage"])
	if not is_equal_approx(hero.base_max_hp, want_hp):
		bad.append("base max hp %.2f, RECIPES say %.2f" % [hero.base_max_hp, want_hp])
	if not is_equal_approx(hero.speed, want_speed):
		bad.append("speed %.2f, RECIPES say %.2f" % [hero.speed, want_speed])
	if not is_equal_approx(hero.damage, want_dmg):
		bad.append("damage %.2f, RECIPES say %.2f" % [hero.damage, want_dmg])
	if cfg.kit(gs.unlocks).size() != 5:
		bad.append("row has %d of 5 slots filled" % cfg.kit(gs.unlocks).size())
	# His card with the whole row, the three-part health bar (his own, the armour, a meal).
	gs.fed = {"dish": "meat", "method": "sear", "build_speed": 1.3, "move_speed": 1.0, "max_hp": 2.0, "seconds_left": 90.0, "seconds_total": 90.0}
	hero.current_hp = hero.max_hp * 0.8
	root.get_node("EventBus").unit_selected.emit(hero)
	await _advance(1.0)
	await _shoot("his_card")
	root.get_node("EventBus").unit_selected.emit(wb)
	await _advance(0.5)
	await _portrait("workbench_model", (wb as Node3D).global_position, 2.2)
	_say("PASS" if bad.is_empty() else "FAIL", "all six made; %s" % ("row, offers and stats as RECIPES say" if bad.is_empty() else "; ".join(bad)))

## TASK-003 part 3: the first map's alpha and its boss leave hide and bone, no prime meat; the hide
## is picked up and turns up in the top bar.
func _p_boss_drops() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	var found: Dictionary = {}
	var spots := {"minor_boss": core + Vector3(-6.0, 0.0, 6.0), "boss": core + Vector3(6.0, 0.0, 6.0)}
	for role in spots:
		var species: String = String(gs.map_data()[role])
		var d = load(String(cfg.get_dino_script_path(species))).new()
		_main.add_child(d)
		d.setup(species)
		d.global_position = spots[role]
		await _advance(0.5)
		d.take_damage(99999.0)
		await _advance(2.0)
		var got: Dictionary = {}
		for item in get_nodes_in_group(DropItem.GROUP):
			if (item as Node3D).global_position.distance_to(spots[role]) < 4.0:
				got[item.resource_type] = int(got.get(item.resource_type, 0)) + int(item.amount)
		found[species] = got
		_say("INFO", "%s (%s) left %s; Config says %s" % [species, role, str(got), str(cfg.DINOS[species].get("drops", {}))])
	var ok := true
	for sp in found:
		if found[sp].has("prime_meat") or not found[sp].has("hide") or not found[sp].has("bone"):
			ok = false
	var hide0: int = int(gs.resources.get("hide", 0))
	hero.move_to(spots["minor_boss"])
	await _advance(6.0)
	var hide1: int = int(gs.resources.get("hide", 0))
	await _shoot("hide_in_the_bar")
	_say("PASS" if ok else "FAIL", "boss drops: %s" % str(found))
	_say("PASS" if hide1 > hide0 else "FAIL", "walking over the alpha's drop: hide %d -> %d" % [hide0, hide1])

## TASK-002: a fence hugging the cabin's back (the nest side) and its east end, open west and at the
## door -- the player's half-built ring -- against a BIG raid (the alpha and ten). Every raider (not
## the nest's guards) watched on its own: the longest it stood still neither biting nor walking,
## and how often it swung back and forth on the spot ("抽搐"). `bare` leaves the fence out.
func _p_half_fence(bare: bool) -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var gm = _main.grid_manager
	var wm = _main.wave_manager
	var cabin = _main.current_core
	var centre: Vector3 = cabin.global_position
	if not bare:
		var c: Vector2i = gm.world_to_build_cell(centre)
		var h := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
		for x in range(-h.x - 1, h.x + 2):
			_build_at("wall", c + Vector2i(x, -h.y - 1))
		for z in range(-h.y, h.y + 2):
			_build_at("wall", c + Vector2i(h.x + 1, z))
		var walls := 0
		for b in gm.get_all_buildings():
			if is_instance_valid(b) and "building_type" in b and String(b.building_type) == "wall":
				walls += 1
		_say("INFO", "fence sections standing: %d" % walls)
		for i in range(10):
			await process_frame
		_main.nav_maps.rebake()
		for i in range(10):
			await process_frame
	gs.day_clock = 110.0
	wm.auto_raid_enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	# DA_HERO_IN: the Hero inside at the bench, out of the raid's way (else he stands by the door,
	# and what crowds there may be crowding him).
	if OS.get_environment("DA_HERO_IN") != "":
		_main._walk_to_bench(cabin.station("workbench"))
		var tin := 0.0
		while not cabin.hero_inside and tin < 20.0:
			await _advance(0.25)
			tin += 0.25
		_say("INFO", "the Hero is inside: %s" % cabin.hero_inside)
	wm.start_wave(3, 10)
	var stall_now: Dictionary = {}
	var stall_max: Dictionary = {}
	var stall_at: Dictionary = {}
	var last_yaw: Dictionary = {}
	var last_pos: Dictionary = {}
	var spot_flips: Dictionary = {}
	var spot_where: Dictionary = {}
	var spot_log: Dictionary = {}
	var last_turn: Dictionary = {}
	var flips: Dictionary = {}
	var biting_at_15: int = -1
	var t := 0.0
	while t < 60.0:
		await _advance(0.25)
		t += 0.25
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		var biting := 0
		for d in get_nodes_in_group("dinos"):
			if not is_instance_valid(d) or d.is_in_group("guard_dinos") or ("is_dead" in d and d.is_dead):
				continue
			var id: int = d.get_instance_id()
			if int(d.mode) == 2 and d.current_target == cabin:
				biting += 1
			var still: bool = (d.velocity as Vector3).length() < 0.1 and int(d.mode) != 2
			stall_now[id] = (float(stall_now.get(id, 0.0)) + 0.25) if still else 0.0
			if float(stall_now[id]) > float(stall_max.get(id, 0.0)):
				stall_max[id] = stall_now[id]
				stall_at[id] = "%s mode %d target %s at %.1fs" % [str(gm.world_to_build_cell((d as Node3D).global_position)), int(d.mode), (String(d.current_target.building_type) if d.current_target != null and is_instance_valid(d.current_target) and "building_type" in d.current_target else str(d.current_target)), t]
			var yaw: float = (d as Node3D).global_rotation.y
			if last_yaw.has(id):
				var turn: float = wrapf(yaw - float(last_yaw[id]), -PI, PI)
				var moved: float = (d as Node3D).global_position.distance_to(last_pos.get(id, (d as Node3D).global_position))
				if absf(turn) > deg_to_rad(20.0):
					if last_turn.has(id) and signf(turn) != signf(float(last_turn[id])):
						flips[id] = int(flips.get(id, 0)) + 1
						# On the spot: a swing back while it has all but stood still -- the twitch.
						if moved < 0.15:
							spot_flips[id] = int(spot_flips.get(id, 0)) + 1
							spot_where[id] = "%s mode %d at %.1fs" % [str(gm.world_to_build_cell((d as Node3D).global_position)), int(d.mode), t]
							var tgt = d.current_target
							var tname: String = (String(tgt.building_type) if tgt != null and is_instance_valid(tgt) and "building_type" in tgt else (String(tgt.name) if tgt != null and is_instance_valid(tgt) else "none"))
							spot_log[id] = spot_log.get(id, []) + ["%.2fs turn %+.0f deg mode %d target %s pos %.2f,%.2f v %.2f" % [t, rad_to_deg(turn), int(d.mode), tname, (d as Node3D).global_position.x, (d as Node3D).global_position.z, (d.velocity as Vector3).length()]]
					last_turn[id] = turn
			last_yaw[id] = yaw
			last_pos[id] = (d as Node3D).global_position
		if is_equal_approx(t, 15.0):
			biting_at_15 = biting
			await _portrait("t15", centre, 14.0)
		if is_equal_approx(t, 35.0):
			await _portrait("t35", centre, 14.0)
		if is_equal_approx(t, 18.5) or is_equal_approx(t, 19.0):
			await _portrait("west_end_%d" % int(t * 10), centre + Vector3(-3.5, 0.0, 0.5), 5.0)
		# The cabin's south-west corner, by the door, where one waits and swings (BUG-005/008): a close
		# strip of five a quarter-second apart.
		if t >= 19.0 and t <= 20.0 and OS.get_environment("DA_FILM_CORNER") != "":
			await _portrait("sw_corner_%03d" % int(t * 100), centre + Vector3(-5.0, 0.0, 1.6), 3.0)
	var worst := 0.0
	var worst_what := ""
	for id in stall_max:
		if float(stall_max[id]) > worst:
			worst = stall_max[id]
			worst_what = stall_at[id]
	var most_flips := 0
	for id in flips:
		most_flips = maxi(most_flips, int(flips[id]))
	var alive := 0
	var at_cabin := 0
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos") and not ("is_dead" in d and d.is_dead):
			alive += 1
			if int(d.mode) == 2 and d.current_target == cabin:
				at_cabin += 1
	var layout: String = "bare" if bare else "back+east fence"
	_say("INFO", "cabin at %.2f,%.2f; its cell %s; size %s cells" % [centre.x, centre.z, str(gm.world_to_build_cell(centre)), str(cfg.get_building_size("core"))])
	_say("INFO", "%s, big raid (%d): biting the cabin at 15 s: %d; at 60 s: %d of %d" % [layout, wm.dinos_to_spawn, biting_at_15, at_cabin, alive])
	_say("PASS" if worst <= 10.0 else "FAIL", "%s: longest a raider stood still not biting: %.1f s (%s)" % [layout, worst, worst_what])
	var most_spot := 0
	var spot_what := ""
	var worst_id := 0
	for id in spot_flips:
		if int(spot_flips[id]) > most_spot:
			most_spot = spot_flips[id]
			spot_what = spot_where[id]
			worst_id = id
	if most_spot > 3:
		for line in spot_log.get(worst_id, []):
			_say("INFO", "  twitch: " + line)
	_say("INFO", "%s: most back-and-forth swings by one raider while moving about: %d" % [layout, most_flips])
	_say("PASS" if most_spot <= 3 else "FAIL", "%s: most swings back ON THE SPOT (<0.15 m moved) by one raider in 60 s: %d %s" % [layout, most_spot, spot_what])

## TASK-004 part 1 (GAME-DESIGN 3 视角): the cursor within `edge_pan_margin` px of the window's edge
## pans the view that way, as fast as the arrow keys; the corners go diagonally; the middle, the
## top bar's buttons and a cursor outside the window leave it be. MOVES THE REAL CURSOR (warp_mouse)
## for about ten seconds -- run it alone, with the game window in front.
func _p_edge_pan() -> void:
	var rig = _main.camera_rig
	var vp := root.get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	var results := {}
	DisplayServer.window_move_to_foreground()
	var entered := {"n": 0}
	root.mouse_entered.connect(func(): entered["n"] += 1)
	vp.warp_mouse(Vector2(-40.0, size.y / 2.0))
	await _advance(0.3)
	vp.warp_mouse(size / 2.0)
	await _advance(0.5)
	_say("INFO", "window focused: %s; viewport %s; root saw mouse_entered %d time(s); Main._mouse_in_window = %s" % [DisplayServer.window_is_focused(), str(size), entered["n"], str(_main.get("_mouse_in_window"))])
	if OS.get_environment("DA_FORCE_IN") != "":
		_main.set("_mouse_in_window", true)
		_say("INFO", "FORCED Main._mouse_in_window = true for this run")
	# The keys, for the speed to match: A held one second.
	vp.warp_mouse(size / 2.0)
	await _advance(0.5)
	var f0: Vector3 = rig.focus
	_key(KEY_A, true)
	await _advance(1.0)
	_key(KEY_A, false)
	var by_key: float = rig.focus.distance_to(f0)
	var spots := {
		"middle": size / 2.0,
		"left edge": Vector2(2.0, size.y / 2.0),
		"right edge": Vector2(size.x - 2.0, size.y / 2.0),
		"top-left corner": Vector2(2.0, 2.0),
		"top bar button (y 30)": Vector2(size.x - 60.0, 30.0),
		"7 px in from the left": Vector2(7.0, size.y / 2.0),
		"outside, left": Vector2(-40.0, size.y / 2.0),
	}
	for name in spots:
		vp.warp_mouse(spots[name])
		await _advance(0.3)
		var a: Vector3 = rig.focus
		await _advance(1.0)
		var d: Vector3 = rig.focus - a
		results[name] = d
		_say("INFO", "%s at %s: focus moved %.2f m (%.2f, %.2f)" % [name, str(spots[name]), d.length(), d.x, d.z])
	vp.warp_mouse(size / 2.0)
	var ok := true
	var notes: Array = []
	for still in ["middle", "top bar button (y 30)", "7 px in from the left", "outside, left"]:
		if (results[still] as Vector3).length() > 0.05:
			ok = false
			notes.append("%s moved the view" % still)
	for moving in ["left edge", "right edge", "top-left corner"]:
		if (results[moving] as Vector3).length() < 0.5 * by_key:
			ok = false
			notes.append("%s hardly moved it" % moving)
	var ratio: float = (results["left edge"] as Vector3).length() / maxf(0.001, by_key)
	if absf(ratio - 1.0) > 0.15:
		notes.append("left edge %.2f x the A key's speed" % ratio)
		ok = false
	var l: Vector3 = results["left edge"]
	var r: Vector3 = results["right edge"]
	if l.dot(r) > 0.0:
		ok = false
		notes.append("left and right edges pan the same way")
	var c: Vector3 = results["top-left corner"]
	if absf(c.normalized().dot(l.normalized())) > 0.9:
		ok = false
		notes.append("the corner is not diagonal")
	_say("INFO", "A key for 1 s: %.2f m" % by_key)
	_say("PASS" if ok else "FAIL", "edge panning%s" % ((": " + "; ".join(notes)) if not notes.is_empty() else ": edges pan at the keys' speed, corner diagonal, middle/top bar/7 px/outside still"))

## TASK-006 (GAME-DESIGN 9.3): at dusk the raid out turns for the nest, bites nothing on the way and
## is gone there, dropping nothing; none of it is out in the night. A BIG raid set out two seconds
## before dusk -- still stepping out of the nest one at a time when dusk comes.
func _p_dusk_raid() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var cabin = _main.current_core
	var dusk: float = float(root.get_node("Config").DAY["parts"]["dusk"])
	var night: float = float(root.get_node("Config").DAY["parts"]["night"])
	# DA_DUSK_LEAD: how long before dusk the raid sets out (2 s: still stepping out at dusk; 25 s:
	# all out and at the cabin when dusk comes).
	var lead: float = float(OS.get_environment("DA_DUSK_LEAD")) if OS.get_environment("DA_DUSK_LEAD") != "" else 2.0
	gs.day_clock = dusk - lead
	_say("INFO", "raid sets out %.0f s before dusk" % lead)
	# No defence here: the cabin is made to outlast the raid, so it is the dusk that ends it.
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	wm.start_wave(3, 10)
	var home := {"n": 0}
	var on_home := func(_d): home["n"] += 1
	eb.dino_went_home.connect(on_home)
	var drops0: int = get_nodes_in_group(DropItem.GROUP).size()
	var hp0: float = cabin.current_hp
	var late: Dictionary = {}          # raiders that stepped out after dusk began
	var seen: Dictionary = {}
	var biting_after: Array = []
	var t := 0.0
	var ended_at := -1.0
	var hp_at_dusk := -1.0
	while t < 60.0 + lead:
		await _advance(0.25)
		t += 0.25
		var part: String = String(gs.day_part())
		if hp_at_dusk < 0.0 and part != "day":
			hp_at_dusk = cabin.current_hp
		for d in get_nodes_in_group("dinos"):
			if not is_instance_valid(d) or d.is_in_group("guard_dinos") or ("is_dead" in d and d.is_dead):
				continue
			var id: int = d.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				if part != "day":
					late[id] = "%.2f" % gs.day_clock
			if part != "day" and float(gs.day_clock) > dusk + 1.0 and not d.going_home:
				if biting_after.size() < 6 and int(d.mode) == 2:
					biting_after.append("%s biting %s at clock %.1f" % [d.name, (String(d.current_target.building_type) if d.current_target != null and is_instance_valid(d.current_target) and "building_type" in d.current_target else "?"), gs.day_clock])
		if ended_at < 0.0 and not wm.is_wave_active:
			ended_at = float(gs.day_clock)
	eb.dino_went_home.disconnect(on_home)
	var out_at_night := 0
	var not_going := 0
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos") and not ("is_dead" in d and d.is_dead):
			out_at_night += 1
			if not d.going_home:
				not_going += 1
	await _portrait("night_after_the_raid", cabin.global_position + Vector3(0.0, 0.0, -4.0), 16.0)
	_say("INFO", "roster %d; stepped out after dusk began: %d; went home: %d; cabin %.1f -> %.1f at dusk -> %.1f; new drops %d; clock now %.1f (%s)" % [seen.size(), late.size(), home["n"], hp0, hp_at_dusk, cabin.current_hp, get_nodes_in_group(DropItem.GROUP).size() - drops0, gs.day_clock, gs.day_part()])
	_say("PASS" if late.is_empty() else "FAIL", "nobody stepped out of the nest after dusk began (%d did)" % late.size())
	_say("PASS" if not_going == 0 and out_at_night == 0 else "FAIL", "into the night (clock %.0f, night from %.0f): %d raiders still out, %d of them not going home" % [gs.day_clock, night, out_at_night, not_going])
	_say("PASS" if biting_after.is_empty() else "FAIL", "after dusk: %s" % ("nobody bit anything" if biting_after.is_empty() else "; ".join(biting_after)))
	_say("PASS" if ended_at >= 0.0 and ended_at <= dusk + 30.0 else "FAIL", "the raid ended at clock %.1f (dusk %.0f, wanted within 30 s)" % [ended_at, dusk])

## TASK-008 (GAME-DESIGN 9.3 迷雾): the three states of a cell, what is hidden, the nest found once and
## what finding it changes in the raid warning, the sight shrinking at dusk and night, and the cost.
func _p_fog() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var cfg := root.get_node("Config")
	var wm = _main.wave_manager
	var fog = _main.fog
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var nest: Node3D = get_first_node_in_group("nest") as Node3D
	var bad: Array = []
	gs.day_clock = 100.0
	await _advance(1.0)
	# 1. The opening: light round the cabin, dark beyond; the nest and its guards not drawn.
	var far: Vector3 = core + Vector3(16.0, 0.0, 0.0)
	var guards_shown := 0
	for d in get_nodes_in_group("guard_dinos"):
		if (d as Node3D).visible:
			guards_shown += 1
	_say("INFO", "opening: shade at the cabin %.2f, 16 m east %.2f (unseen %.2f); nest drawn %s; guards drawn %d; nest %.1f m from the cabin" % [fog.shade_at(core), fog.shade_at(far), float(cfg.FOG["unseen"]), nest.visible, guards_shown, nest.global_position.distance_to(core)])
	if fog.shade_at(core) > 0.05 or fog.shade_at(far) < 0.8 or nest.visible or guards_shown > 0:
		bad.append("opening not dark beyond / nest or guards drawn")
	await _shoot("opening")
	# 2. The raid warning before the nest is found.
	var warns: Array = []
	var on_warn := func(left): warns.append(left)
	eb.raid_warning.connect(on_warn)
	wm.raid_timer = wm.warning_lead_time + float(cfg.FOG["found_nest_warning"]) + 3.0
	wm.warning_emitted = false
	var tw := 0.0
	while warns.is_empty() and tw < 20.0:
		await _advance(0.25)
		tw += 0.25
	await _advance(0.5)
	var text_before: String = _banner_text()
	var lead_before: float = float(warns[0]) if not warns.is_empty() else -1.0
	await _shoot("warning_before")
	wm.raid_timer = 200.0
	wm.warning_emitted = false
	# 3. A walk east and back: seen but out of sight is dim and shows no animals.
	hero.move_to(far)
	await _advance(7.0)
	hero.move_to(core + Vector3(0.0, 0.0, 4.0))
	await _advance(7.0)
	var species: String = String(gs.map_data()["raiders"].keys()[0])
	var d = load(String(cfg.get_dino_script_path(species))).new()
	_main.add_child(d)
	d.setup(species)
	d.max_hp = 9999.0
	d.current_hp = 9999.0
	d.global_position = far
	d.set_waypoints([far])
	await _advance(1.0)
	_say("INFO", "after the walk: 16 m east seen %s, in sight %s, shade %.2f (seen %.2f); a raider there drawn: %s" % [fog.is_seen(far), fog.is_in_sight(far), fog.shade_at(far), float(cfg.FOG["seen"]), d.visible])
	if not fog.is_seen(far) or fog.is_in_sight(far) or absf(fog.shade_at(far) - float(cfg.FOG["seen"])) > 0.1 or d.visible:
		bad.append("walked-over ground not dim-and-empty")
	# The hidden raider under the cursor: hover and right-click find nothing.
	var cam: Camera3D = _main._active_camera()
	var at: Vector2 = cam.unproject_position(d.global_position + Vector3(0.0, 0.5, 0.0))
	var picked = _main._raycast_object(at)
	_say("INFO", "hidden raider at screen %s: picked %s" % [str(at), str(picked)])
	if picked == d:
		bad.append("a hidden raider can be picked")
	d.queue_free()
	await _shoot("walked")
	# 4. The nest: walk at it; found once, said once.
	var found := {"n": 0, "dist": -1.0}
	var on_found := func(_n):
		found["n"] += 1
		found["dist"] = (hero as Node3D).global_position.distance_to(nest.global_position)
	eb.nest_found.connect(on_found)
	hero.move_to(nest.global_position + (core - nest.global_position).normalized() * 6.0)
	var t := 0.0
	while found["n"] == 0 and t < 30.0:
		await _advance(0.25)
		t += 0.25
	var hint_up: bool = not _visible_labels(tr("HINT_NEST_FOUND").left(12)).is_empty()
	await _shoot("nest_found")
	await _portrait("the_nest", nest.global_position, 7.0)
	hero.move_to(core + Vector3(0.0, 0.0, 4.0))
	await _advance(12.0)
	guards_shown = 0
	for g in get_nodes_in_group("guard_dinos"):
		if (g as Node3D).visible:
			guards_shown += 1
	_say("INFO", "nest_found fired %d time(s), at %.1f m (hero sight %.0f m); hint shown %s; back home: nest drawn %s, guards drawn %d" % [found["n"], found["dist"], float(cfg.FOG["sight"]["hero"]), hint_up, nest.visible, guards_shown])
	if found["n"] != 1 or not hint_up or not nest.visible or guards_shown > 0 or found["dist"] > float(cfg.FOG["sight"]["hero"]) + 1.0:
		bad.append("nest finding")
	# 5. The raid warning after: seen setting out, and earlier.
	warns.clear()
	wm.raid_timer = wm.warning_lead_time + float(cfg.FOG["found_nest_warning"]) + 3.0
	wm.warning_emitted = false
	tw = 0.0
	while warns.is_empty() and tw < 20.0:
		await _advance(0.25)
		tw += 0.25
	await _advance(0.5)
	var text_after: String = _banner_text()
	var lead_after: float = float(warns[0]) if not warns.is_empty() else -1.0
	await _shoot("warning_after")
	eb.raid_warning.disconnect(on_warn)
	eb.nest_found.disconnect(on_found)
	_say("INFO", "warning before: %.1f s, banner [%s]" % [lead_before, text_before.replace(char(10), " / ")])
	_say("INFO", "warning after:  %.1f s, banner [%s]" % [lead_after, text_after.replace(char(10), " / ")])
	if not text_before.contains(tr("HUD_RAID_FROM").split("%")[0].strip_edges()) or not text_after.contains(tr("HUD_RAID_SEEN")) or absf((lead_after - lead_before) - float(cfg.FOG["found_nest_warning"])) > 1.0:
		bad.append("warning text or lead")
	wm.raid_timer = 200.0
	# 6. Sight by the hour: the furthest point east of him in sight, day / dusk / night.
	hero.move_to(core + Vector3(0.0, 0.0, 8.0))
	await _advance(4.0)
	var reach := {}
	for part in ["day", "dusk", "night"]:
		gs.day_clock = float(cfg.DAY["parts"][part]) + 360.0 + 5.0
		await _advance(0.5)
		var r := 0.0
		for i in range(1, 30):
			var p: Vector3 = hero.global_position + Vector3(float(i) * 0.5, 0.0, 0.0)
			if fog.is_in_sight(p):
				r = float(i) * 0.5
		reach[part] = r
		await _shoot("sight_" + part)
	_say("INFO", "sight east of him: day %.1f m, dusk %.1f m, night %.1f m (Config: %.1f, x%.1f, x%.1f)" % [reach["day"], reach["dusk"], reach["night"], float(cfg.FOG["sight"]["hero"]), float(cfg.FOG["dusk"]), float(cfg.FOG["night"])])
	var want_day: float = float(cfg.FOG["sight"]["hero"])
	for part in ["day", "dusk", "night"]:
		var want: float = want_day * (1.0 if part == "day" else float(cfg.FOG[part]))
		if absf(float(reach[part]) - want) > 1.01:
			bad.append("sight at %s %.1f, want %.1f" % [part, reach[part], want])
	# 7. The cost: process time per frame with the fog drawing, and with it stopped.
	gs.day_clock = 100.0 + 360.0 * 2.0
	var blocks: Array = []
	for k in range(4):
		fog.set_process(k % 2 == 0)
		hero.move_to(core + Vector3(-8.0 if k % 2 == 0 else 8.0, 0.0, 8.0))
		var st: Array = await _frame_stats(1.5)
		blocks.append("%s mean %.1f max %.1f ms" % ["fog on " if k % 2 == 0 else "fog off", st[0], st[1]])
	fog.set_process(true)
	# The fog's own work, timed directly, once.
	var u0: int = Time.get_ticks_usec()
	fog._look()
	var u1: int = Time.get_ticks_usec()
	fog._paint(0.1)
	var u2: int = Time.get_ticks_usec()
	fog._hide_the_unseen()
	var u3: int = Time.get_ticks_usec()
	_say("INFO", "fog grid %d x %d cells of %.1f m; one update: look %.2f ms, paint %.2f ms, hide %.2f ms" % [fog.cells, fog.cells, fog.cell, (u1 - u0) / 1000.0, (u2 - u1) / 1000.0, (u3 - u2) / 1000.0])
	_say("INFO", "process time per frame, 1.5 s blocks: " + " | ".join(blocks))
	_say("PASS" if bad.is_empty() else "FAIL", "fog of war: %s" % ("all as TASK-008 says" if bad.is_empty() else "; ".join(bad)))

func _frame_stats(seconds: float) -> Array:
	var total := 0.0
	var worst := 0.0
	var n := 0
	for i in range(int(seconds * 60.0)):
		await process_frame
		var ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		total += ms
		worst = maxf(worst, ms)
		n += 1
	return [total / maxf(1.0, float(n)), worst]

func _frame_ms(seconds: float) -> float:
	var total := 0.0
	var n := 0
	for i in range(int(seconds * 60.0)):
		await process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		n += 1
	return total / maxf(1.0, float(n))

func _banner_text() -> String:
	for n in _all(_main):
		if "raid_warning_banner" in n and n.raid_warning_banner != null:
			var b = n.raid_warning_banner
			return String(b.text) if b.is_visible_in_tree() else "(banner hidden) " + String(b.text)
	return "(no banner)"

func _visible_labels(fragment: String) -> Array:
	var out: Array = []
	for n in _all(root):
		if (n is Label or n is RichTextLabel) and (n as CanvasItem).is_visible_in_tree() and String(n.text).contains(fragment):
			out.append(n)
	return out

## GAME-DESIGN 3 守卫恐龙 + 0c1f442 (a nest is defended by all its guards at once). Three cases:
##   A. a building put up near a guard's post (NEST_GUARDS.building_aggro_share): does a guard go and
##      bite it, or turn back and forth between chasing it and going home?
##   B. he comes near the nest: all its guards come; he goes back into his fenced ring by the gate:
##      they give up and go home, and do not chew his ring.
##   C. a guard's post is fenced in while it is out after him: it settles at the nearest place it can
##      stand, and does not push at the fence.
func _p_guards() -> void:
	var gs := root.get_node("GameState")
	var gm = _main.grid_manager
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	gs.day_clock = 60.0
	var guards: Array = get_nodes_in_group("guard_dinos")
	var nest: Node3D = get_first_node_in_group("nest") as Node3D
	var posts: Array = []
	for g in guards:
		posts.append(str(gm.world_to_build_cell(g.post_position)))
	_say("INFO", "%d guards, posts %s; nest at %s" % [guards.size(), ", ".join(posts), str(gm.world_to_build_cell(nest.global_position))])
	# --- A. A stake 3 m from the first guard's post, on the side away from the nest.
	var g0 = guards[0]
	var away: Vector3 = (g0.post_position - nest.global_position)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	var stake_cell: Vector2i = gm.world_to_build_cell(g0.post_position + away * 3.0)
	var stake = _build_at("set_crossbow", stake_cell)
	_main.nav_maps.rebake()
	await _advance(1.0)
	if stake == null:
		_say("INFO", "A: could not put a set crossbow at %s; trying a palisade" % str(stake_cell))
		stake = _build_at("wall", stake_cell)
		_main.nav_maps.rebake()
		await _advance(1.0)
	var flips := {}
	var last := {}
	var hp0: float = stake.current_hp if stake != null else -1.0
	var t := 0.0
	while t < 30.0 and stake != null and is_instance_valid(stake) and not stake.is_destroyed:
		await _advance(0.25)
		t += 0.25
		for g in guards:
			if not is_instance_valid(g):
				continue
			var st: int = int(g.guard_state)
			var id: int = g.get_instance_id()
			if last.has(id) and int(last[id]) != st:
				flips[id] = int(flips.get(id, 0)) + 1
			last[id] = st
	var most := 0
	for id in flips:
		most = maxi(most, int(flips[id]))
	var hp1: float = stake.current_hp if (stake != null and is_instance_valid(stake)) else 0.0
	await _portrait("A_stake_by_the_post", g0.post_position, 9.0)
	_say("INFO", "A: %s at %s, 3 m from a post: hp %.1f -> %.1f in %.1f s; most state changes by one guard: %d" % [String(stake.building_type) if stake != null and is_instance_valid(stake) else "(gone)", str(stake_cell), hp0, hp1, t, most])
	_say("PASS" if (hp1 < hp0 or most <= 4) else "FAIL", "A: guards against a building by their post: %s" % ("bitten" if hp1 < hp0 else ("left alone, quietly" if most <= 4 else "NOT bitten, and %d changes of mind in 30 s (chase <-> home)" % most)))
	if stake != null and is_instance_valid(stake) and not stake.is_destroyed:
		stake.queue_free()
		_main.nav_maps.rebake()
	var alive: Array = []
	for g in guards:
		if is_instance_valid(g) and not ("is_dead" in g and g.is_dead):
			g.max_hp = 9999.0
			g.current_hp = 9999.0
			alive.append(g)
	_say("INFO", "after A: %d of %d guards alive (the crossbow shoots them too)" % [alive.size(), guards.size()])
	guards = alive
	await _advance(8.0)
	# --- B. A ring round the cabin with a gate; he walks at the nest, then home through the gate.
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	_ring_round_the_cabin()
	_main.nav_maps.rebake()
	await _advance(0.5)
	var ring: Array = []
	for b in gm.get_all_buildings():
		if is_instance_valid(b) and "building_type" in b and String(b.building_type) in ["wall", "gate"]:
			ring.append(b)
	var ring_hp0 := 0.0
	for b in ring:
		ring_hp0 += b.current_hp
	hero.move_to(nest.global_position + (core - nest.global_position).normalized() * 5.0)
	var chasing := 0
	t = 0.0
	while t < 15.0 and chasing < guards.size():
		await _advance(0.25)
		t += 0.25
		chasing = 0
		for g in guards:
			if is_instance_valid(g) and int(g.guard_state) in [1, 2]:
				chasing += 1
	_say("INFO", "B: he is %.1f m from the nest; guards after him: %d of %d after %.1f s" % [hero.global_position.distance_to(nest.global_position), chasing, guards.size(), t])
	_main._walk_to_bench(cabin.station("workbench"))
	t = 0.0
	while not cabin.hero_inside and t < 30.0:
		await _advance(0.25)
		t += 0.25
	var at_ring := 0.0
	for i in range(80):
		await _advance(0.25)
		for g in guards:
			if is_instance_valid(g) and (g as Node3D).global_position.distance_to(core) < 6.0 and int(g.guard_state) != 3:
				at_ring += 0.25
	var ring_hp1 := 0.0
	for b in ring:
		ring_hp1 += b.current_hp if is_instance_valid(b) else 0.0
	var states: Array = []
	for g in guards:
		if not is_instance_valid(g):
			continue
		states.append("%d@%.1fm" % [int(g.guard_state), (g as Node3D).global_position.distance_to(g.post_position)])
	await _portrait("B_after_he_went_in", core, 14.0)
	_say("INFO", "B: 20 s after he got in: guards (state@m from post) %s; guard-seconds spent at his ring not going home: %.1f; ring hp %.1f -> %.1f" % [", ".join(states), at_ring, ring_hp0, ring_hp1])
	_say("PASS" if ring_hp1 >= ring_hp0 - 0.01 and at_ring < 6.0 else "FAIL", "B: guards give him up at his fence and do not chew it")
	# --- C. Out after him, a guard's post fenced in; he goes home; it settles near its post.
	var g1 = guards[guards.size() - 1]
	var post: Vector3 = g1.post_position
	var pc: Vector2i = gm.world_to_build_cell(post)
	hero.move_to(core + Vector3(0.0, 0.0, 6.0))
	await _advance(1.0)
	g1._begin_chase(hero, false)
	await _advance(3.0)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if absi(dx) == 2 or absi(dz) == 2:
				_build_at("wall", pc + Vector2i(dx, dz))
	_main.nav_maps.rebake()
	await _advance(0.5)
	_main._walk_to_bench(cabin.station("workbench"))
	var pos_log: Array = []
	var bite := 0.0
	for i in range(120):
		await _advance(0.25)
		pos_log.append((g1 as Node3D).global_position)
		if int(g1.current_state) == int(g1.State.ATTACKING) and g1.current_target != null and is_instance_valid(g1.current_target) and "building_type" in g1.current_target:
			bite += 0.25
	var wander := 0.0
	for i in range(pos_log.size() - 40, pos_log.size() - 1):
		wander += (pos_log[i] as Vector3).distance_to(pos_log[i + 1])
	var settled_at: float = (g1 as Node3D).global_position.distance_to(post)
	await _portrait("C_post_fenced_in", post, 8.0)
	_say("INFO", "C: post %s fenced in; 30 s later the guard is %.1f m from it, state %d, new post %s m off the old; walked %.1f m in the last 10 s; seconds biting a building %.1f" % [str(pc), settled_at, int(g1.guard_state), "%.1f" % g1.post_position.distance_to(post), wander, bite])
	_say("PASS" if bite < 1.0 and int(g1.guard_state) == 0 else "FAIL", "C: a guard walled off from its post makes a new one and does not push at the fence")

## GAME-DESIGN 3 放置不看人, the animal's half: a palisade ordered on the cell a dinosaur stands in goes
## down as an order; he builds it to just short of done and it waits there, its card saying something
## is standing where it goes; the animal gone, it closes.
func _p_build_under_dino() -> void:
	var gs := root.get_node("GameState")
	var gm = _main.grid_manager
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	gs.resources["wood"] = 20
	gs.day_clock = 60.0
	var cell: Vector2i = gm.world_to_build_cell(core + Vector3(0.0, 0.0, 6.0))
	var at: Vector3 = gm.build_cell_to_world(cell)
	var species: String = String(gs.map_data()["raiders"].keys()[0])
	var d = load(String(root.get_node("Config").get_dino_script_path(species))).new()
	_main.add_child(d)
	d.setup(species)
	d.global_position = at
	d.max_hp = 9999.0
	d.current_hp = 9999.0
	await _advance(0.2)
	# Held where it stands: it neither walks off nor bites -- the cell stays taken.
	d.set_physics_process(false)
	d.set_process(false)
	_main.on_build_selected("wall")
	var b = _main.try_place_at_cell(gm.world_to_cell(at), at)
	_main.cancel_building_selection()
	if b == null:
		_say("FAIL", "the order on the dinosaur's cell %s was refused (3 章: 人或恐龙站着的格子照样能下单)" % str(cell))
		d.queue_free()
		return
	var t := 0.0
	while t < 20.0 and not b.is_constructed:
		await _advance(0.25)
		t += 0.25
	var status: String = String(b._waiting_status()) if b.has_method("_waiting_status") else "?"
	var prog: String = ("%.2f" % float(b.build_progress)) if "build_progress" in b else "?"
	_say("INFO", "with the dinosaur on it, after %.1f s: built %s, progress %s, card status '%s', hero state %d" % [t, b.is_constructed, prog, status, int(hero.current_state)])
	root.get_node("EventBus").unit_selected.emit(b)
	await _advance(0.5)
	await _shoot("waiting_for_the_animal")
	var waited_ok: bool = not b.is_constructed and status == tr("STATUS_WAITING_CLEAR")
	d.queue_free()
	t = 0.0
	while t < 10.0 and not b.is_constructed:
		await _advance(0.25)
		t += 0.25
	_say("PASS" if waited_ok and b.is_constructed else "FAIL", "palisade on a standing dinosaur's cell: waited %s with the right words, then closed %s (%.1f s after it went)" % [waited_ok, b.is_constructed, t])

## TASK-010, looking for false alarms: what should never be called a twitch. 90 s of a quiet day --
## the nest's guards wandering their posts, the Hero chopping -- then an ordinary raid chewing a
## sealed ring round the cabin (biting a wall it cannot go round is the rule, GAME-DESIGN 3). Every
## TwitchWatch report is printed with what the animal was doing, to be judged true or false.
func _p_quiet() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var hero = _main.hero
	var reports: Array = []
	var phase := {"now": "quiet"}
	var on_twitch := func(rec):
		var d: Dictionary = rec.get("dino", {})
		reports.append("%s: #%s %s %s %s at %s -> %s" % [phase["now"], rec.get("n"), rec.get("kind"), d.get("species"), d.get("mode"), str(d.get("pos")), str((d.get("target") if d.get("target") != null else {}).get("type", "-"))])
	if eb.has_signal("twitch_detected"):
		eb.twitch_detected.connect(on_twitch)
	else:
		_say("INFO", "no EventBus.twitch_detected on this commit")
	gs.day_clock = 60.0
	wm.auto_raid_enabled = false
	var tree: Node = null
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood" and (tree == null or (n as Node3D).global_position.distance_to(hero.global_position) < (tree as Node3D).global_position.distance_to(hero.global_position)):
			tree = n
	if tree != null:
		hero.order_harvest(tree)
	await _advance(90.0)
	var quiet_n: int = reports.size()
	phase["now"] = "raid at a sealed ring"
	_ring_round_the_cabin()
	_main.nav_maps.rebake()
	_main._walk_to_bench(_main.current_core.station("workbench"))
	await _advance(8.0)
	wm.start_wave(2, 6)
	await _advance(45.0)
	await _shoot("quiet_raid")
	if eb.has_signal("twitch_detected"):
		eb.twitch_detected.disconnect(on_twitch)
	for r in reports:
		_say("INFO", r)
	_say("PASS" if quiet_n == 0 else "FAIL", "90 s of a quiet day (guards wandering, him chopping): %d twitch reports" % quiet_n)
	_say("INFO", "an ordinary raid at a sealed ring: %d twitch reports (each above to be judged)" % (reports.size() - quiet_n))

## TASK-010, judging reports by eye: an ordinary big raid on the bare cabin, and the first few
## TwitchWatch reports each filmed -- four close-ups of that animal a third of a second apart,
## from above -- so a report can be called true or false from the pictures (contact_sheet.gd).
func _p_twitch_cam() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var cabin = _main.current_core
	var queue: Array = []
	var on_twitch := func(rec):
		if queue.size() < 4:
			queue.append(rec)
	eb.twitch_detected.connect(on_twitch)
	gs.day_clock = 110.0
	wm.auto_raid_enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(6.0)
	wm.start_wave(3, 10)
	var t := 0.0
	var filmed := 0
	while t < 60.0 and filmed < 4:
		await _advance(0.25)
		t += 0.25
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		if queue.size() > filmed:
			var rec: Dictionary = queue[filmed]
			var id: int = int(rec.get("dino", {}).get("id", 0))
			var d: Node3D = instance_from_id(id) as Node3D if id != 0 else null
			_say("INFO", "report #%s %s %s at %s, filming" % [rec.get("n"), rec.get("kind"), rec.get("dino", {}).get("mode"), str(rec.get("dino", {}).get("pos"))])
			for k in range(4):
				if d == null or not is_instance_valid(d):
					break
				await _portrait("r%s_%s_%d" % [rec.get("n"), rec.get("kind"), k], d.global_position, 3.5)
				await _advance(0.3)
			filmed += 1
	eb.twitch_detected.disconnect(on_twitch)
	_say("INFO", "%d reports filmed in %.1f s of raid" % [filmed, t])

## TASK-012 (7817a1e): the fog as a last full-screen layer -- never seen is black, the far walls and
## the sky too; seen and out of sight is dimmed; in sight is untouched; the interface is never dimmed.
## Every picture through the game's own camera (a portrait camera leaves the layer out).
func _p_black_fog() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var hero = _main.hero
	var rig = _main.camera_rig
	var core: Vector3 = _main.current_core.global_position
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	await _advance(1.5)
	await _shoot("A_opening")
	_say("INFO", "A opening: %s" % _black_share())
	# B. To the river bank where he draws water, and back: the way walked dim, the rest black.
	var water: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "water":
			water = n
	var bank: Vector3 = water.global_position if water != null else core + Vector3(-18.0, 0.0, -6.0)
	hero.move_to(bank)
	var t := 0.0
	while t < 20.0 and hero.global_position.distance_to(bank) > 2.5:
		await _advance(0.5)
		t += 0.5
	_say("INFO", "at the river bank %s after %.1f s (%.1f m off)" % [str(bank), t, hero.global_position.distance_to(bank)])
	_look_at(bank, 16.0)
	await _advance(1.0)
	await _shoot("C_river_in_sight")
	hero.move_to(core + Vector3(0.0, 0.0, 4.5))
	await _advance(12.0)
	_look_at((bank + core) * 0.5, 34.0)
	await _advance(1.0)
	await _shoot("B_walked_and_back")
	_say("INFO", "B walked and back: %s" % _black_share())
	# D. Dusk and night, the default view over the cabin.
	for part in ["dusk", "night"]:
		gs.day_clock = float(cfg.DAY["parts"][part]) + 5.0
		_look_at(core, 25.0)
		await _advance(1.5)
		await _shoot("D_" + part)
		_say("INFO", "D %s: %s" % [part, _black_share()])
	gs.day_clock = 100.0 + 360.0
	# E. Zoomed right out and panned to the field's east edge: beyond it, nothing.
	var half: float = float(cfg.TERRAIN.get("field_half", 22.0))
	_look_at(core + Vector3(half, 0.0, 0.0), 45.0)
	await _advance(1.5)
	await _shoot("E_edge_zoomed_out")
	_say("INFO", "E field edge, zoomed out: %s" % _black_share())

## Puts the game's camera over `at`, `distance` off, through its own rig.
func _look_at(at: Vector3, distance: float) -> void:
	var rig = _main.camera_rig
	rig.focus = Vector3(at.x, 0.0, at.z)
	rig.distance = distance
	rig.apply_to(_main.camera)

## How much of the world part of the screen is black: the viewport less the top bar and the card.
func _black_share() -> String:
	var img: Image = root.get_viewport().get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var black := 0
	var n := 0
	for y in range(int(h * 0.1), int(h * 0.95), 6):
		for x in range(int(w * 0.02), int(w * 0.62), 6):
			var c: Color = img.get_pixel(x, y)
			n += 1
			if c.get_luminance() < 0.02:
				black += 1
	return "%.0f%% of the world view black" % (100.0 * black / maxf(1.0, float(n)))

## Frames a second with vsync off: the default view idle, then with a raid of ten on the field.
func _p_fps() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _advance(2.0)
	var idle: float = await _fps_over(5.0)
	_main.current_core.max_hp = 100000.0
	_main.current_core.current_hp = 100000.0
	wm.start_wave(3, 10)
	await _advance(8.0)
	var raid: float = await _fps_over(5.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_say("INFO", "frames a second, vsync off, %s: idle %.0f, raid of 11 %.0f" % [str(root.get_viewport().get_visible_rect().size), idle, raid])

func _fps_over(seconds: float) -> float:
	var t0: int = Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - t0 < int(seconds * 1000000.0):
		await process_frame
		frames += 1
	return float(frames) / seconds

## TASK-011's second part: the layout of `siege:4:12:1` -- a sealed ring of palisade 6.5 m round the
## cabin with four set crossbows in its nest side, facing out -- and a raid of twelve. What the raid
## does at the ring: an overhead picture at 12 s and 20 s, and the first four twitch reports filmed.
func _p_ring_traps() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var cfg := root.get_node("Config")
	var gm = _main.grid_manager
	var wm = _main.wave_manager
	var cabin = _main.current_core
	var centre: Vector3 = cabin.global_position
	var ring: Array[Vector2i] = []
	var seen := {}
	var around: int = int(ceil(TAU * 6.5 / float(cfg.BUILD_CELL))) * 4
	for i in range(around):
		var a: float = TAU * float(i) / float(around)
		var cell: Vector2i = gm.world_to_build_cell(centre + Vector3(sin(a) * 6.5, 0.0, -cos(a) * 6.5))
		if not seen.has(cell):
			seen[cell] = true
			ring.append(cell)
	var traps := {}
	# DA_NO_TRAPS: the ring alone, sealed -- the raid has to bite through it.
	for i in range(0 if OS.get_environment("DA_NO_TRAPS") != "" else 4):
		var a: float = deg_to_rad(-80.0 + 160.0 * (float(i) + 0.5) / 4.0)
		var out := Vector2(sin(a), -cos(a))
		var nearest: Vector2i = ring[0]
		for c in ring:
			var d: Vector3 = gm.build_cell_to_world(c) - centre
			var n: Vector3 = gm.build_cell_to_world(nearest) - centre
			if Vector2(d.x, d.z).normalized().dot(out) > Vector2(n.x, n.z).normalized().dot(out):
				nearest = c
		traps[nearest] = (1 if out.x > 0.0 else 3) if absf(out.x) > absf(out.y) else (2 if out.y > 0.0 else 0)
	for c in traps:
		for r in cfg.BUILDINGS["set_crossbow"]["cost"]:
			gs.resources[r] = int(gs.resources.get(r, 0)) + int(cfg.BUILDINGS["set_crossbow"]["cost"][r])
		var b = _main.build_system.place_at("set_crossbow", c, _main.buildings_container, true, int(traps[c]))
		if b != null:
			b.complete_construction()
	for c in ring:
		if not traps.has(c):
			_build_at("wall", c)
	_main.nav_maps.rebake()
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(6.0)
	var queue: Array = []
	var on_twitch := func(rec):
		if queue.size() < 4:
			queue.append(rec)
	eb.twitch_detected.connect(on_twitch)
	gs.day_clock = 110.0
	wm.auto_raid_enabled = false
	wm.start_wave(1, 12)
	var t := 0.0
	var filmed := 0
	while t < 40.0 and wm.is_wave_active:
		await _advance(0.25)
		t += 0.25
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		if is_equal_approx(t, 12.0) or is_equal_approx(t, 20.0) or (OS.get_environment("DA_NO_TRAPS") != "" and (is_equal_approx(t, 9.0) or is_equal_approx(t, 15.0))):
			await _portrait("overhead_%ds" % int(t), centre + Vector3(-1.0, 0.0, -9.0), 16.0)
			var modes := {}
			for dd in get_nodes_in_group("dinos"):
				if is_instance_valid(dd) and not dd.is_in_group("guard_dinos"):
					var m: String = ["march", "engage", "attack", "breach"][int(dd.mode)] if int(dd.mode) < 4 else str(dd.mode)
					modes[m] = int(modes.get(m, 0)) + 1
			_say("INFO", "%.0f s: raiders by mode %s; ring sections standing %d" % [t, str(modes), _count_walls()])
		if queue.size() > filmed and filmed < 4:
			var rec: Dictionary = queue[filmed]
			var d: Node3D = instance_from_id(int(rec.get("dino", {}).get("id", 0))) as Node3D
			_say("INFO", "report #%s %s %s -> %s at %s, filming" % [rec.get("n"), rec.get("kind"), rec.get("dino", {}).get("mode"), str((rec.get("dino", {}).get("target") if rec.get("dino", {}).get("target") != null else {}).get("type", "-")), str(rec.get("dino", {}).get("pos"))])
			for k in range(4):
				if d == null or not is_instance_valid(d):
					break
				await _portrait("r%s_%s_%d" % [rec.get("n"), rec.get("kind"), k], d.global_position, 3.5)
				await _advance(0.3)
			filmed += 1
	eb.twitch_detected.disconnect(on_twitch)
	_say("INFO", "raid over %s after %.1f s; %d reports filmed" % [not wm.is_wave_active, t, filmed])

## TASK-014 (7426dbc): the fog of war as the valley's mist. The opening hint said once (in DA_LANG,
## default the saved language); a tree in the mist not drawn and not to be picked, yet walked to --
## and there, drawn and cut; pictures of the opening, the walk, noon, dusk and night through the
## game's own camera.
func _p_mist() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	if OS.get_environment("DA_LANG") != "":
		TranslationServer.set_locale(OS.get_environment("DA_LANG"))
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	var hint: String = tr("HINT_FOG")
	var frag: String = hint.left(8)
	var seen_at: Array = []
	var t := 0.0
	while t < 12.0:
		await _advance(0.25)
		t += 0.25
		if not _visible_labels(frag).is_empty():
			seen_at.append(t)
		if is_equal_approx(t, 5.0):
			await _shoot("A_opening_hint_" + TranslationServer.get_locale())
	_say("INFO", "hint '%s' on screen from %.2f s to %.2f s (%d samples)" % [frag, seen_at[0] if not seen_at.is_empty() else -1.0, seen_at[seen_at.size() - 1] if not seen_at.is_empty() else -1.0, seen_at.size()])
	# What the mist hides: resource nodes drawn or not.
	var drawn := 0
	var hidden: Array = []
	for n in get_nodes_in_group("resource_nodes"):
		if (n as Node3D).is_visible_in_tree():
			drawn += 1
		else:
			hidden.append(n)
	_say("INFO", "resource nodes drawn %d, hidden in the mist %d" % [drawn, hidden.size()])
	# A tree in the mist: not pickable; walked to; then drawn and cut.
	var tree: Node3D = null
	for n in hidden:
		if String(n.resource_type) == "wood" and (tree == null or (n as Node3D).global_position.distance_to(core) < tree.global_position.distance_to(core)):
			tree = n
	if tree != null:
		_look_at(tree.global_position, 20.0)
		await _advance(0.5)
		var at: Vector2 = _main._active_camera().unproject_position(tree.global_position + Vector3(0.0, 1.5, 0.0))
		var picked = _main._raycast_object(at)
		_say("INFO", "a tree in the mist at %s: drawn %s; under the cursor: %s" % [str(tree.global_position), tree.is_visible_in_tree(), str(picked)])
		await _shoot("B_tree_in_the_mist")
		hero.move_to(tree.global_position + (core - tree.global_position).normalized() * 1.2)
		var tw := 0.0
		while tw < 25.0 and not tree.is_visible_in_tree():
			await _advance(0.25)
			tw += 0.25
		var wood0: int = int(gs.resources.get("wood", 0))
		hero.order_harvest(tree)
		await _advance(6.0)
		_say("INFO", "walked there: tree drawn %s after %.1f s; wood %d -> %d while cutting" % [tree.is_visible_in_tree(), tw, wood0, int(gs.resources.get("wood", 0))])
		_say("PASS" if picked != tree and tree.is_visible_in_tree() and int(gs.resources.get("wood", 0)) > wood0 else "FAIL", "a tree in the mist: not pickable, walked to, then drawn and cut")
	hero.move_to(core + Vector3(0.0, 0.0, 4.5))
	await _advance(10.0)
	_look_at(core + Vector3(-4.0, 0.0, -4.0), 30.0)
	await _advance(1.0)
	await _shoot("C_walked_and_back_noon")
	for part in ["dusk", "night"]:
		gs.day_clock = float(cfg.DAY["parts"][part]) + 5.0
		_look_at(core, 25.0)
		await _advance(1.5)
		await _shoot("D_" + part)
	gs.day_clock = 100.0 + 360.0
	var half: float = float(cfg.TERRAIN.get("field_half", 22.0))
	_look_at(core + Vector3(half, 0.0, 0.0), 45.0)
	await _advance(1.5)
	await _shoot("E_edge_zoomed_out")
	_say("INFO", "hint samples after 12 s: still on screen %s" % (not _visible_labels(frag).is_empty()))

## The stones by the nest (MAPS.valley default_resource_nodes, GAME-DESIGN 9.2: "巢边的两块还在，离危险更近")
## since 0c1f442 ("a nest is defended by all its guards at once"): the Hero at full health with the
## bone pick, sent to quarry each nest-side stone in turn, from the cabin, as a click sends him --
## how long he lasts, what came at him, and whether he lives. `which` picks the stone: the nearest
## to the nest on the east or west.
func _p_nest_stone(which: String) -> void:
	var gs := root.get_node("GameState")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	var nest: Node3D = get_first_node_in_group("nest") as Node3D
	gs.day_clock = float(OS.get_environment("DA_CLOCK")) if OS.get_environment("DA_CLOCK") != "" else 80.0
	_main.wave_manager.auto_raid_enabled = false
	if _main.get("night_prowl") != null:
		_main.night_prowl.enabled = false
	gs.grant_unlock("harvest_stone")
	var stone: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) != "stone":
			continue
		var p: Vector3 = (n as Node3D).global_position
		if (which == "east" and p.x < core.x) or (which == "west" and p.x >= core.x):
			continue
		if stone == null or p.distance_to(nest.global_position) < stone.global_position.distance_to(nest.global_position):
			stone = n
	var posts: Array = []
	for g in get_nodes_in_group("guard_dinos"):
		posts.append("%.1f m" % g.post_position.distance_to(stone.global_position))
	_say("INFO", "%s stone at %s: %.1f m from the nest; guard posts %s from it; hero hp %.0f" % [which, str(stone.global_position), stone.global_position.distance_to(nest.global_position), ", ".join(posts), hero.current_hp])
	hero.order_harvest(stone)
	var t := 0.0
	var first_bite := -1.0
	var max_chasing := 0
	var stone0: int = int(gs.resources.get("stone", 0))
	while t < 40.0 and not gs.is_game_over:
		await _advance(0.25)
		t += 0.25
		var chasing := 0
		for g in get_nodes_in_group("guard_dinos"):
			if is_instance_valid(g) and int(g.guard_state) in [1, 2]:
				chasing += 1
		max_chasing = maxi(max_chasing, chasing)
		if first_bite < 0.0 and hero.current_hp < hero.max_hp:
			first_bite = t
			await _shoot("%s_first_bite" % which)
	var alive: int = 0
	for g in get_nodes_in_group("guard_dinos"):
		if is_instance_valid(g) and not ("is_dead" in g and g.is_dead):
			alive += 1
	_say("INFO", "%s stone: first bite at %.1f s; up to %d guards after him at once; after %.1f s: hero %s (hp %.1f), game over %s, guards left %d, stone got %d" % [which, first_bite, max_chasing, t, "DEAD" if hero.current_hp <= 0.0 else "alive", hero.current_hp, gs.is_game_over, alive, int(gs.resources.get("stone", 0)) - stone0])

## TASK-015 (69f127e): Build and Eat fixed in the corner, his card only when asked for. The keys as a
## player presses them -- real key events through the engine -- and after each, what is open, what is
## picked, what is in hand, where the two tiles are, and how many "1"s and "2"s the screen shows.
func _p_herocard_keys() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var hud = _main.hud
	var hero = _main.hero
	var gm = _main.grid_manager
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	gs.resources["wood"] = 40
	gs.known["wood"] = true
	# Two meals put by: with none, Eat is off (nothing to press) and 2 rightly does nothing.
	gs.meals["meat/roast"] = 2
	# A bitten stake and a whole one, to pick later.
	var core: Vector3 = _main.current_core.global_position
	var bitten = _build_at("wall", gm.world_to_build_cell(core + Vector3(-5.0, 0.0, 5.0)))
	var whole = _build_at("wall", gm.world_to_build_cell(core + Vector3(-5.0, 0.0, 7.0)))
	bitten.current_hp = bitten.max_hp * 0.4
	await _advance(0.5)
	var rects := {}
	var bad: Array = []
	var step := func(name: String) -> Dictionary:
		var st := _card_state()
		rects[name] = st["tiles"]
		_say("INFO", "%-28s %s" % [name, str(st)])
		return st
	eb.unit_selected.emit(hero)
	await _advance(0.3)
	var s0: Dictionary = step.call("hero picked")
	if s0["details"] or s0["menu"] != "default":
		bad.append("picking him opened a card")
	await _press(KEY_1)
	var s1: Dictionary = step.call("1")
	if s1["menu"] != "build":
		bad.append("1 did not open the build menu")
	await _press(KEY_1)
	var s2: Dictionary = step.call("1 again (first building)")
	if s2["in_hand"] == "" or s2["menu"] == "build":
		bad.append("1 in the menu did not take a building and close it")
	await _shoot("in_hand")
	await _press(KEY_ESCAPE)
	var s3: Dictionary = step.call("Esc")
	if s3["in_hand"] != "":
		bad.append("Esc did not drop the building in hand")
	await _press(KEY_1)
	await _press(KEY_C)
	var s4: Dictionary = step.call("1 then C")
	if not s4["details"] or s4["menu"] == "build":
		bad.append("C in the build menu did not turn it into his card")
	await _shoot("details_card")
	await _press(KEY_C)
	var s5: Dictionary = step.call("C again")
	if s5["details"]:
		bad.append("C again did not close his card")
	await _click_emblem()
	var s6: Dictionary = step.call("click the medallion")
	if not s6["details"]:
		bad.append("the medallion did not open his card")
	await _press(KEY_ESCAPE)
	var s7: Dictionary = step.call("Esc (card open)")
	if s7["details"]:
		bad.append("Esc did not close his card")
	if s7["pause_menu"]:
		bad.append("Esc with his card open opened the game menu (the card was not open)")
		await _press(KEY_ESCAPE)
	await _press(KEY_ESCAPE)
	var s7b: Dictionary = step.call("Esc (him picked, nothing open)")
	_say("INFO", "Esc with only him picked: game menu %s, still picked '%s'" % [s7b["pause_menu"], s7b["picked"]])
	if s7b["pause_menu"]:
		await _press(KEY_ESCAPE)
	eb.unit_selected.emit(hero)
	await _advance(0.3)
	await _press(KEY_2)
	var s8: Dictionary = step.call("2")
	if s8["menu"] != "eat":
		bad.append("2 did not open the eat menu")
	# With a menu open the number keys are the menu's (1-6 choose); clicking the tile again closes it.
	_main.hud.hero_commands.eat_button.pressed.emit()
	await _advance(0.3)
	var s9: Dictionary = step.call("Eat clicked again")
	if s9["menu"] == "eat":
		bad.append("clicking Eat again did not close the eat menu")
	await _press(KEY_2)
	await _press(KEY_1)
	await _advance(0.5)
	var s9b: Dictionary = step.call("2, then 1 (a meal)")
	_say("INFO", "eating after choosing a meal: %s; meals left %s" % [hero.is_eating() if hero.has_method("is_eating") else "?", str(gs.meals)])
	if s9b["menu"] == "eat":
		bad.append("choosing a meal did not close the eat menu")
	await _advance(3.0)
	# The bitten stake: its card over the tiles; 1 is Repair, the tiles unmarked.
	eb.unit_selected.emit(bitten)
	await _advance(0.3)
	var s12: Dictionary = step.call("bitten stake picked")
	await _shoot("bitten_stake")
	var hero_state0: int = int(hero.current_state)
	await _press(KEY_1)
	await _advance(0.5)
	var s13: Dictionary = step.call("1 on the bitten stake")
	_say("INFO", "hero state before %d after %d (2 = building/mending); his target %s" % [hero_state0, int(hero.current_state), str(hero.get("build_target"))])
	if s13["menu"] == "build":
		bad.append("1 on a bitten stake opened the build menu instead of Repair")
	# The whole stake: only Demolish on it -- 1 and 2 stay Build and Eat.
	hero.order_stop()
	eb.unit_selected.emit(whole)
	await _advance(0.3)
	var s14: Dictionary = step.call("whole stake picked")
	await _press(KEY_1)
	var s15: Dictionary = step.call("1 on a whole stake")
	if s15["menu"] != "build":
		bad.append("1 with a whole stake picked did not open Build")
	# Build clicked with the stake picked: he is picked and his build menu opens.
	await _press(KEY_ESCAPE)
	var s15b: Dictionary = step.call("Esc (build menu)")
	if s15b["pause_menu"]:
		await _press(KEY_ESCAPE)
	eb.unit_selected.emit(whole)
	await _advance(0.3)
	hud.hero_commands.build_button.pressed.emit()
	await _advance(0.3)
	var s16: Dictionary = step.call("Build clicked, stake picked")
	if s16["menu"] != "build" or s16["picked"] != String(hero.name):
		bad.append("clicking Build with a stake picked did not pick him and open Build")
	# The tiles never move.
	var first: String = str(rects["hero picked"])
	for k in rects:
		if str(rects[k]) != first:
			bad.append("the tiles moved at '%s': %s vs %s" % [k, str(rects[k]), first])
	for k in rects:
		pass
	_say("PASS" if bad.is_empty() else "FAIL", "hero card and keys: %s" % ("all as TASK-015 says" if bad.is_empty() else "; ".join(bad)))

func _count_walls() -> int:
	var n := 0
	for b in _main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and "building_type" in b and String(b.building_type) == "wall" and not b.is_destroyed:
			n += 1
	return n

func _press(code: int) -> void:
	_key(code, true)
	for i in range(3):
		await process_frame
	_key(code, false)
	for i in range(8):
		await process_frame

func _click_emblem() -> void:
	var em: Control = _main.hud.find_child("HeroEmblem", true, false) as Control
	if em == null:
		_say("INFO", "no HeroEmblem")
		return
	var at: Vector2 = em.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		# In the viewport's own coordinates: the window may be scaled over it (2560 over 1280).
		root.push_input(ev, true)
		for i in range(4):
			await process_frame

## What the corner shows now.
func _card_state() -> Dictionary:
	var hud = _main.hud
	var op = hud.option_panel
	var hc = hud.hero_commands
	var sel = op.selected_unit if ("selected_unit" in op) else null
	var ones := 0
	var twos := 0
	for n in _all(hud):
		if n is Label and (n as Label).is_visible_in_tree():
			var t: String = (n as Label).text.strip_edges()
			if t == "1":
				ones += 1
			elif t == "2":
				twos += 1
	var pause_up := false
	for n in _all(root):
		if n is Control and (n as Control).is_visible_in_tree() and String(n.name).to_lower().contains("pause") and (n as Control).get_global_rect().size.x > 100:
			pause_up = true
	return {
		"menu": String(op.current_menu),
		"details": bool(op.showing_details()),
		"card_shown": bool(op.is_visible_in_tree()),
		"picked": String(sel.name) if sel != null and is_instance_valid(sel) else "",
		"in_hand": String(_main.current_build_type),
		"keys_on_tiles": bool(hc.keys_live()),
		"ones": ones, "twos": twos,
		"tiles": [hc.build_button.get_global_rect(), hc.eat_button.get_global_rect()],
		"pause_menu": pause_up,
	}

## TASK-016 (72b27c8, BUG-011): the defeat screen names the rule the run was lost on. `how`: "guard"
## (killed beside a nest guard), "raider" (beside a raiding Coelophysis), "alone" (nobody within
## HERO.killer_within), "cabin" (the cabin broken). Run several in one launch: each is a fresh run,
## so a screen carrying the last run's words shows here.
func _p_defeat(how: String) -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var hero = _main.hero
	var cabin = _main.current_core
	if OS.get_environment("DA_LANG") != "":
		TranslationServer.set_locale(OS.get_environment("DA_LANG"))
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	var before: Dictionary = {}
	for n in _all(_main.hud):
		if n is Label and (n as Label).is_visible_in_tree():
			before[(n as Label).text] = true
	match how:
		"guard":
			var g: Node3D = get_nodes_in_group("guard_dinos")[0] as Node3D
			hero.global_position = g.global_position + Vector3(1.2, 0.0, 0.0)
			await _advance(0.2)
			hero.take_damage(9999.0)
		"raider":
			var species: String = String(gs.map_data()["raiders"].keys()[0])
			var d = load(String(cfg.get_dino_script_path(species))).new()
			_main.add_child(d)
			d.setup(species)
			d.global_position = hero.global_position + Vector3(1.5, 0.0, 0.0)
			await _advance(0.2)
			hero.take_damage(9999.0)
		"alone":
			hero.take_damage(9999.0)
		"cabin":
			cabin.take_damage(99999.0)
	await _advance(1.5)
	var said: Array = []
	for n in _all(_main.hud):
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text.length() > 3 and not before.has((n as Label).text):
			said.append((n as Label).text.replace(char(10), " / "))
	await _shoot("defeat_%s_%s" % [how, TranslationServer.get_locale()])
	_say("INFO", "%s: game over %s; the screen says: %s" % [how, gs.is_game_over, " | ".join(said)])

## TASK-017, what buildings as avoidance obstacles might break: (A) a one-cell gap between two runs
## of palisade -- a raider sent through it gets through; (B) a one-cell lane between the cabin's west
## end and a palisade laid parallel to it -- a raider walks the lane end to end. The cells are the
## game's (BUILD_CELL, 1 m); a raider is 0.8 m wide (GAME-DESIGN 3: "一格空地就是一条路").
func _p_gaps() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var gm = _main.grid_manager
	var core: Vector3 = _main.current_core.global_position
	var cc: Vector2i = gm.world_to_build_cell(core)
	var h := Vector2i((cfg.get_building_size("core") - Vector2i.ONE) / 2)
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	# A: a wall across open ground south of the cabin, x from cc.x-6 to cc.x+6 at z = cc.y+6, with a
	# one-cell gap at cc.x.
	var zA: int = cc.y + h.y + 5
	for x in range(cc.x - 6, cc.x + 7):
		if x != cc.x:
			_build_at("wall", Vector2i(x, zA))
	# B: a run of palisade one cell off the cabin's west end, from its north row to its south row:
	# the lane is the column between the cabin and the run.
	# (Beside the cabin a raider rightly stops to bite the cabin at the lane's mouth, so the lane is
	# laid in open ground east of it: two parallel runs, the lane between them.)
	# B is its own layout (below, after A): a sealed square round the cabin whose one way in is a
	# lane one cell wide and four long, running out east from a gap in its east side.
	var xB: int = 0
	_main.nav_maps.rebake()
	await _advance(0.5)
	var species: String = String(gs.map_data()["raiders"].keys()[0])
	var results := {}
	for case in ["A_gap", "B_lane"]:
		var from: Vector3
		var to: Vector3
		if case == "A_gap":
			from = gm.build_cell_to_world(Vector2i(cc.x - 3, zA + 3))
			to = gm.build_cell_to_world(Vector2i(cc.x + 3, zA - 2))
		else:
			# Clear A away and lay B.
			for b in gm.get_all_buildings():
				if is_instance_valid(b) and "building_type" in b and String(b.building_type) == "wall":
					b.queue_free()
			await _advance(0.2)
			var x0: int = cc.x - h.x - 3
			var x1: int = cc.x + h.x + 3
			var z0: int = cc.y - h.y - 3
			var z1: int = cc.y + h.y + 3
			for x in range(x0, x1 + 1):
				_build_at("wall", Vector2i(x, z0))
				_build_at("wall", Vector2i(x, z1))
			for z in range(z0 + 1, z1):
				_build_at("wall", Vector2i(x0, z))
				if z != cc.y:
					_build_at("wall", Vector2i(x1, z))
			for x in range(x1 + 1, x1 + 5):
				_build_at("wall", Vector2i(x, cc.y - 1))
				_build_at("wall", Vector2i(x, cc.y + 1))
			_main.nav_maps.rebake()
			await _advance(0.5)
			xB = x1
			from = gm.build_cell_to_world(Vector2i(x1 + 7, cc.y))
			to = core
		var reachable: bool = _main.nav_maps.is_reachable(from, to, false)
		var d = load(String(cfg.get_dino_script_path(species))).new()
		_main.add_child(d)
		d.setup(species)
		d.max_hp = 9999.0
		d.current_hp = 9999.0
		d.global_position = from
		d.set_waypoints([to])
		var t := 0.0
		var best: float = from.distance_to(to)
		# What counts: through the gap -- on the far side of the fence line; into the lane -- at its
		# middle. (Near the cabin a raider rightly turns to bite it; getting there is the question.)
		var mid: Vector3 = gm.build_cell_to_world(Vector2i(xB + 1, cc.y))
		var through := false
		while t < 25.0:
			await _advance(0.25)
			t += 0.25
			var p: Vector3 = (d as Node3D).global_position
			best = minf(best, p.distance_to(to))
			if case == "A_gap" and p.z < gm.build_cell_to_world(Vector2i(cc.x, zA)).z - 0.6:
				through = true
			if case == "B_lane" and p.x < gm.build_cell_to_world(Vector2i(xB, cc.y)).x - 0.6:
				through = true
			if through:
				break
		var bit: String = ""
		if d.current_target != null and is_instance_valid(d.current_target) and "building_type" in d.current_target:
			bit = " (biting a %s)" % String(d.current_target.building_type)
		results[case] = "on the raid's mesh: %s; %s after %.1f s%s" % [reachable, "GOT THROUGH" if through else "did not get through", t, bit]
		await _portrait(case, (from + to) * 0.5, 9.0)
		d.queue_free()
		await _advance(0.5)
	for k in results:
		_say("INFO", "%s: %s" % [k, results[k]])
	var ok: bool = results["A_gap"].contains("GOT THROUGH") and results["B_lane"].contains("GOT THROUGH")
	_say("PASS" if ok else "FAIL", "a raider through a one-cell gap and down a one-cell lane")

## TASK-017: the map's boss (siege behaviour) still goes THROUGH a wall -- rams it -- rather than round:
## a sealed ring 6.5 m round the cabin, the boss put down outside it on the nest side.
func _p_boss_rams() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var gm = _main.grid_manager
	var core: Vector3 = _main.current_core.global_position
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	var seen := {}
	var around: int = int(ceil(TAU * 6.5 / float(cfg.BUILD_CELL))) * 4
	var ring: Array = []
	for i in range(around):
		var a: float = TAU * float(i) / float(around)
		var cell: Vector2i = gm.world_to_build_cell(core + Vector3(sin(a) * 6.5, 0.0, -cos(a) * 6.5))
		if not seen.has(cell):
			seen[cell] = true
			var b = _build_at("wall", cell)
			if b != null:
				ring.append(b)
	_main.nav_maps.rebake()
	await _advance(0.5)
	var boss: String = String(gs.map_data()["boss"])
	var d = load(String(cfg.get_dino_script_path(boss))).new()
	_main.add_child(d)
	d.setup(boss)
	d.max_hp = 9999.0
	d.current_hp = 9999.0
	var start: Vector3 = core + Vector3(0.0, 0.0, -11.0)
	d.global_position = start
	d.set_waypoints([core])
	var t := 0.0
	var walked := 0.0
	var last: Vector3 = start
	var first_bite := -1.0
	var bitten: String = ""
	while t < 40.0:
		await _advance(0.25)
		t += 0.25
		walked += (d as Node3D).global_position.distance_to(last)
		last = (d as Node3D).global_position
		if first_bite < 0.0 and int(d.current_state) == int(d.State.ATTACKING) and d.current_target != null and is_instance_valid(d.current_target):
			first_bite = t
			bitten = String(d.current_target.building_type) if "building_type" in d.current_target else str(d.current_target)
	var lost := 0
	for b in ring:
		if not is_instance_valid(b) or b.is_destroyed:
			lost += 1
	await _portrait("boss_at_the_ring", core + Vector3(0.0, 0.0, -6.0), 12.0)
	_say("INFO", "%s from %.1f m out: first bite at %.1f s on a %s; walked %.1f m in %.1f s; ring sections lost %d of %d" % [boss, start.distance_to(core), first_bite, bitten, walked, t, lost, ring.size()])
	_say("PASS" if first_bite >= 0.0 and first_bite < 15.0 and walked < 15.0 else "FAIL", "the boss rams the ring rather than going round it")

## TASK-018 (30c4d1a), run with DA_MAP=valley_large. Which of the ridge's ways a raid from the nest
## takes (the x each raider crosses the ridge's line at), and whether a raider set down at each of the
## final wave's entries reaches the cabin.
func _p_routes() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var nest: Node3D = get_first_node_in_group("nest") as Node3D
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(8.0)
	_say("INFO", "map %s: cabin %s, nest %s (%.1f m); entries %s" % [String(gs.map_data().get("name", "?")), str(core), str(nest.global_position), nest.global_position.distance_to(core), str(wm.entry_positions)])
	# The ridge's line: tile rows -12/-13 of the large valley (tiles are 2 m), just south of it.
	var ridge_z: float = -22.0
	# DA_BLOCK_MIDDLE: palisade across the ridge's wide middle way (tiles x -2..4 -> metres -5..10).
	if OS.get_environment("DA_BLOCK_MIDDLE") != "":
		var gm = _main.grid_manager
		var put := 0
		for x in range(-6, 12):
			for z in [-25, -24]:
				if _build_at("wall", gm.world_to_build_cell(Vector3(float(x) + 0.5, 0.0, float(z) + 0.5))) != null:
					put += 1
		_main.nav_maps.rebake()
		await _advance(2.0)
		_say("INFO", "middle way fenced: %d stakes" % put)
	var crossed := {}
	var reached := {}
	var band := {}
	wm.start_wave(2, 9)
	var t := 0.0
	var last := {}
	while t < 60.0:
		await _advance(0.25)
		t += 0.25
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		for d in get_nodes_in_group("dinos"):
			if not is_instance_valid(d) or d.is_in_group("guard_dinos"):
				continue
			var id: int = d.get_instance_id()
			var p: Vector3 = (d as Node3D).global_position
			if last.has(id) and float(last[id].z) < ridge_z and p.z >= ridge_z and not crossed.has(id):
				crossed[id] = p.x
			# The way it went through the ridge band: its x range while z is in -30..-18.
			if p.z > -30.0 and p.z < -18.0:
				var r: Array = band.get(id, [INF, -INF, INF, -INF])
				band[id] = [minf(r[0], p.x), maxf(r[1], p.x), minf(r[2], p.z), maxf(r[3], p.z)]
			last[id] = p
			if int(d.mode) == 2 and d.current_target == cabin and not reached.has(id):
				reached[id] = t
		if is_equal_approx(t, 14.0):
			_look_at((nest.global_position + core) * 0.5, 45.0)
			await _advance(0.2)
			await _shoot("raid_at_the_ridge")
	var ways := {"west": 0, "middle": 0, "east": 0}
	for id in crossed:
		var x: float = float(crossed[id])
		ways["west" if x < -5.0 else ("east" if x > 10.0 else "middle")] += 1
	var xs: Array = []
	for id in crossed:
		xs.append("%.0f" % float(crossed[id]))
	if OS.get_environment("DA_BLOCK_MIDDLE") != "":
		_say("INFO", "fence sections standing after the raid: %d" % _count_walls())
	for id in band:
		var r: Array = band[id]
		_say("INFO", "  a raider in the ridge band: x %.1f..%.1f, z %.1f..%.1f" % [r[0], r[1], r[2], r[3]])
	_say("INFO", "raid of 9 from the nest: crossed the ridge line (z %.0f) at x = %s -> %s; reached the cabin %d of 9 (first at %.1f s)" % [ridge_z, ", ".join(xs), str(ways), reached.size(), (reached.values().min() if not reached.is_empty() else -1.0)])
	# The final wave's entries: one raider from each, sent at the cabin.
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos"):
			d.queue_free()
	await _advance(0.5)
	var species: String = String(gs.map_data()["raiders"].keys()[0])
	var cfg := root.get_node("Config")
	var from_entry := {}
	for e in wm.entry_positions:
		var d = load(String(cfg.get_dino_script_path(species))).new()
		_main.add_child(d)
		d.setup(species)
		d.max_hp = 9999.0
		d.current_hp = 9999.0
		d.global_position = e
		d.set_waypoints([core])
		from_entry[d] = {"from": e, "at": -1.0}
	t = 0.0
	while t < 60.0:
		await _advance(0.25)
		t += 0.25
		for d in from_entry:
			if float(from_entry[d]["at"]) < 0.0 and is_instance_valid(d) and int(d.mode) == 2 and d.current_target == cabin:
				from_entry[d]["at"] = t
	var lines: Array = []
	var all_ok := true
	for d in from_entry:
		var at: float = float(from_entry[d]["at"])
		lines.append("from %s: %s" % [str(from_entry[d]["from"]), ("biting the cabin at %.1f s" % at) if at >= 0.0 else "NOT at the cabin in 60 s (at %s)" % str((d as Node3D).global_position if is_instance_valid(d) else "gone")])
		all_ok = all_ok and at >= 0.0
	_say("INFO", "entries: " + "; ".join(lines))
	_say("PASS" if all_ok and reached.size() >= 7 else "FAIL", "routes: the raid through the ridge and every entry to the cabin")

## TASK-018 (5): palisade built across a raid's way while it walks -- the navmesh bakes in the
## background, so for some frames the raid walks on the old one. Nobody should end up inside the new
## stakes or pressed against them for good.
func _p_fence_in_their_way() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	var gm = _main.grid_manager
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var nest: Node3D = get_first_node_in_group("nest") as Node3D
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(6.0)
	wm.start_wave(2, 8)
	# When the first is a third of the way from the cabin to the nest, a line across their way.
	var dir: Vector3 = (nest.global_position - core).normalized()
	var line_at: Vector3 = core + dir * 7.0
	var t := 0.0
	var built := false
	var walls: Array = []
	var inside := 0
	var inside_what: Array = []
	var t_built := 0.0
	while t < 50.0:
		await _advance(0.25 if built else 0.05)
		t += 0.25 if built else 0.05
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		if not built:
			for d in get_nodes_in_group("dinos"):
				if is_instance_valid(d) and not d.is_in_group("guard_dinos") and (d as Node3D).global_position.distance_to(line_at) < 6.0:
					built = true
			if built:
				t_built = t
				var c: Vector2i = gm.world_to_build_cell(line_at)
				var side := Vector2i(1, 0) if absf(dir.z) > absf(dir.x) else Vector2i(0, 1)
				for k in range(-6, 7):
					var b = _build_at("wall", c + side * k)
					if b != null:
						walls.append(b)
				_say("INFO", "at %.1f s, %d stakes put up across their way at %s" % [t, walls.size(), str(line_at)])
				await _shoot("stakes_up")
			continue
		for d in get_nodes_in_group("dinos"):
			if not is_instance_valid(d) or d.is_in_group("guard_dinos"):
				continue
			for w in walls:
				if is_instance_valid(w) and not w.is_destroyed and _flat3((d as Node3D).global_position).distance_to(_flat3(w.global_position)) < 0.35:
					inside += 1
					if inside_what.size() < 4:
						inside_what.append("%.1f s at %s" % [t - t_built, str((d as Node3D).global_position)])
	await _portrait("after_the_stakes", line_at, 12.0)
	_say("INFO", "raid samples inside a stake's cell (< 0.35 m from its middle): %d %s" % [inside, str(inside_what)])
	_say("PASS" if inside == 0 else "FAIL", "stakes put up across a raid's way: nobody walked into them")

func _flat3(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## TASK-018 (4): a line of twelve stakes put up one after another, and the longest frame in the two
## seconds after each -- the rebake used to hold the game 0.11 s (small) / 0.6 s (large).
func _p_build_hitch() -> void:
	var gs := root.get_node("GameState")
	var gm = _main.grid_manager
	var core: Vector3 = _main.current_core.global_position
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	await _advance(1.0)
	var worst := 0.0
	var worsts: Array = []
	var c: Vector2i = gm.world_to_build_cell(core + Vector3(-6.0, 0.0, 6.0))
	for k in range(12):
		_build_at("wall", c + Vector2i(k, 0))
		var last: int = Time.get_ticks_usec()
		var w := 0.0
		for i in range(120):
			await process_frame
			var now: int = Time.get_ticks_usec()
			w = maxf(w, (now - last) / 1000.0)
			last = now
		worsts.append("%.0f" % w)
		worst = maxf(worst, w)
	_say("INFO", "longest frame after each of 12 stakes (ms): %s" % ", ".join(worsts))
	_say("PASS" if worst < 50.0 else "FAIL", "putting up stakes: the longest frame %.0f ms" % worst)

## TASK-018 (7): the settings page's map row, and a restart after choosing -- through the real main
## scene (current_scene), since only it reads the setting. WRITES the player's settings file
## (game/map_size): the caller backs it up and puts it back.
func _p_settings_map() -> void:
	if OS.get_environment("DA_LANG") != "":
		TranslationServer.set_locale(OS.get_environment("DA_LANG"))
	current_scene = _main
	var gs := root.get_node("GameState")
	_say("INFO", "first run: map %s, field half %s" % [String(gs.get("map_id") if "map_id" in gs else gs.get("chosen_map_id")), str(_field_half())])
	var hud = _main.hud
	hud.toggle_pause_menu()
	await _advance(0.3)
	var pm: Node = _find_with_method(hud, "open_settings")
	if pm == null:
		pm = _find_with_method(root, "open_settings")
	pm.open_settings()
	await _advance(0.5)
	var picker: OptionButton = pm.get("map_picker") as OptionButton
	var items: Array = []
	for i in picker.item_count:
		items.append(picker.get_item_text(i))
	_say("INFO", "the map row: items %s, selected '%s', tooltip '%s'" % [str(items), picker.get_item_text(picker.selected), picker.tooltip_text])
	await _shoot("settings_" + TranslationServer.get_locale())
	for want in ["large", "small"]:
		var cfg := root.get_node("Config")
		var idx: int = cfg.MAP_SIZES.keys().find(want)
		picker.select(idx)
		picker.item_selected.emit(idx)
		await _advance(0.2)
		# Restart as the game-over and pause menus do.
		current_scene.restart_game()
		for i in range(40):
			await process_frame
		_main = current_scene
		await _advance(1.0)
		var nest: Node3D = get_first_node_in_group("nest") as Node3D
		_say("INFO", "chose %s, restarted: current scene %s, field half %s, nest %.1f m from the cabin" % [want, current_scene.name, str(_field_half()), nest.global_position.distance_to(_main.current_core.global_position) if nest != null and _main.current_core != null else -1.0])
		if want == "large":
			await _shoot("large_after_restart")
		hud = _main.hud
		hud.toggle_pause_menu()
		await _advance(0.3)
		pm = _find_with_method(root, "open_settings")
		pm.open_settings()
		await _advance(0.3)
		picker = pm.get("map_picker") as OptionButton

func _field_half() -> float:
	var gs := root.get_node("GameState")
	var m: Dictionary = gs.map_data() if gs.has_method("map_data") else {}
	return float(m.get("terrain", {}).get("field_half", root.get_node("Config").TERRAIN.get("field_half", 0.0)))

## TASK-018 follow-up (DA_MAP=valley_large): every resource node on the map worked, from the cabin --
## the Hero sent to each in turn (the pick granted, so stone counts too), and whether he gets to work
## on it. Then the ridge and the rock field photographed with the fog lifted, for the eye.
func _p_reach_all() -> void:
	var gs := root.get_node("GameState")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	gs.grant_unlock("harvest_stone")
	# The guards would make the nest's stones a fight, not a walk: out of the way for this.
	for g in get_nodes_in_group("guard_dinos"):
		g.queue_free()
	var bad: Array = []
	var n := 0
	for node in get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(node) or String(node.resource_type) == "water" or OS.get_environment("DA_PHOTOS_ONLY") != "":
			continue
		n += 1
		hero.global_position = core + Vector3(0.0, 0.0, 4.5)
		hero.order_stop()
		await _advance(0.3)
		var p: Vector3 = (node as Node3D).global_position
		hero.order_harvest(node)
		var t := 0.0
		while t < 40.0 and int(hero.current_state) != 5:
			await _advance(0.25)
			t += 0.25
		var line: String = "%s at %s (%.0f m): %s" % [String(node.resource_type), str(p), p.distance_to(core), ("working after %.1f s" % t) if int(hero.current_state) == 5 else "NOT reached in 40 s (stuck at %s, state %d)" % [str(hero.global_position), int(hero.current_state)]]
		_say("INFO", line)
		if int(hero.current_state) != 5:
			bad.append(line)
	_say("PASS" if bad.is_empty() else "FAIL", "%d resource nodes, every one worked from the cabin%s" % [n, "" if bad.is_empty() else ": " + "; ".join(bad)])
	# The places, with the fog lifted, at noon.
	gs.day_clock = 120.0
	var fog = _main.fog
	fog.reveal_all()
	for spot in [["ridge", Vector3(2.0, 0.0, -24.0), 40.0], ["rock_field", Vector3(29.0, 0.0, -24.0), 26.0], ["woods_sw", Vector3(-26.0, 0.0, 16.0), 26.0], ["whole", Vector3(0.0, 0.0, -6.0), 45.0]]:
		_look_at(spot[1], float(spot[2]))
		await _advance(0.5)
		await _shoot("place_" + String(spot[0]))

## TASK-019 part 1 (5c887f9, DOC-004 choice A): the nest's guards warn before they come. A: he walks
## at the east nest-side stone; the moment they warn he turns back -- they let him go, nobody bitten.
## B: he walks in again and stays -- two seconds on they all come. The hint is said once a run.
func _p_guard_warn() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	if OS.get_environment("DA_LANG") != "":
		TranslationServer.set_locale(OS.get_environment("DA_LANG"))
	gs.day_clock = 80.0
	_main.wave_manager.auto_raid_enabled = false
	gs.grant_unlock("harvest_stone")
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	var stone: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "stone" and (n as Node3D).global_position.x > core.x and (n as Node3D).global_position.z < core.z - 8.0:
			stone = n
	var warns := {"n": 0, "t": -1.0}
	var clock := {"t": 0.0}
	var on_warn := func(_g):
		warns["n"] += 1
		if float(warns["t"]) < 0.0:
			warns["t"] = clock["t"]
	eb.guards_warned.connect(on_warn)
	var hint: String = tr("HINT_GUARDS_WARN").left(10)
	var hint_seen := 0
	var hint_was := false
	for case in ["A_back_away", "B_stay"]:
		warns["t"] = -1.0
		clock["t"] = 0.0
		hero.global_position = core + Vector3(0.0, 0.0, -4.0)
		hero.order_stop()
		await _advance(3.0)
		var hp0: float = hero.current_hp
		if case == "A_back_away":
			hero.order_harvest(stone)
		else:
			# B: clearly inside the ring -- 4.5 m from the nearest guard's post, on the cabin side,
			# and held there (the east stone is ~7.8 m off, on the ring's edge: a guard wandering back
			# to its post can leave him outside it, and let him be).
			var near_post: Vector3 = Vector3.INF
			for g in get_nodes_in_group("guard_dinos"):
				if is_instance_valid(g) and (near_post == Vector3.INF or g.post_position.distance_to(core) < near_post.distance_to(core)):
					near_post = g.post_position
			hero.move_to(near_post + (core - near_post).normalized() * 4.5)
		var threatening := 0
		var shot := false
		var chased_at := -1.0
		var backed := false
		while clock["t"] < 30.0:
			await _advance(0.1)
			clock["t"] += 0.1
			var up: bool = not _visible_labels(hint).is_empty()
			if up and not hint_was:
				hint_seen += 1
			hint_was = up
			var th := 0
			var ch := 0
			for g in get_nodes_in_group("guard_dinos"):
				if not is_instance_valid(g):
					continue
				if int(g.guard_state) == 4:
					th += 1
				elif int(g.guard_state) in [1, 2]:
					ch += 1
			threatening = maxi(threatening, th)
			if float(warns["t"]) >= 0.0 and not shot:
				var vis: Array = []
				for g in get_nodes_in_group("guard_dinos"):
					if is_instance_valid(g) and int(g.guard_state) == 4:
						vis.append("%.1f m from him, drawn %s, in his sight %s" % [_flat3(g.global_position).distance_to(_flat3(hero.global_position)), g.is_visible_in_tree(), _main.fog.is_in_sight(g.global_position)])
				_say("INFO", "%s: at the warning (clock %.0f, %s): the warning guards %s" % [case, gs.day_clock, gs.day_part(), str(vis)])
				shot = true
				await _portrait("%s_warning" % case, (stone.global_position + get_first_node_in_group("nest").global_position) * 0.5, 9.0)
			if case == "A_back_away" and float(warns["t"]) >= 0.0 and not backed:
				backed = true
				hero.move_to(core + Vector3(0.0, 0.0, -2.0))
			if ch > 0 and chased_at < 0.0:
				chased_at = clock["t"]
			if case == "A_back_away" and backed and clock["t"] > float(warns["t"]) + 8.0:
				break
			if case == "B_stay" and chased_at >= 0.0 and clock["t"] > chased_at + 2.0:
				break
		var states: Array = []
		for g in get_nodes_in_group("guard_dinos"):
			if is_instance_valid(g):
				states.append(int(g.guard_state))
		_say("INFO", "%s: warned at %.1f s (%.1f m from the nest's nearest post); up to %d guards threatening at once; first to come at him at %s; bitten %.1f; guards now %s" % [case, warns["t"], _nearest_post(hero), threatening, ("%.1f s" % chased_at) if chased_at >= 0.0 else "never", hp0 - hero.current_hp, str(states)])
		if case == "A_back_away":
			_say("PASS" if chased_at < 0.0 and hp0 - hero.current_hp < 0.01 else "FAIL", "A: warned, he backed away, they let him go")
		else:
			var gap: float = chased_at - float(warns["t"])
			_say("PASS" if chased_at >= 0.0 and gap > 1.5 and gap < 2.8 else "FAIL", "B: warned, he stayed -- they came %.1f s after the warning" % gap)
		hero.order_stop()
		hero.global_position = core + Vector3(0.0, 0.0, -2.0)
		await _advance(10.0)
	eb.guards_warned.disconnect(on_warn)
	_say("PASS" if hint_seen == 1 else "FAIL", "the warning's hint on screen %d time(s) in the run (want 1); guards_warned fired %d time(s)" % [hint_seen, warns["n"]])

func _nearest_post(hero: Node3D) -> float:
	var best := INF
	for g in get_nodes_in_group("guard_dinos"):
		if is_instance_valid(g):
			best = minf(best, hero.global_position.distance_to(g.post_position))
	return best

## TASK-019 parts 2-5 (d9b75e9). `where`: "plain" -- nobody near the nest; "nest_watched" -- he
## stands looking at the nest; "edge_watched" -- he stands on the first edge way in. A raid of 14 sets
## out; each raider's first position says where it came from (the nest, or which edge); an edge one's
## speed is sampled while unseen and far, and while seen; and anyone who turns back -- getting 6 m
## further from the cabin over 5 s -- is counted.
func _p_edge_raid(where: String) -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var wm = _main.wave_manager
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var fog = _main.fog
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	for g in get_nodes_in_group("guard_dinos"):
		g.queue_free()
	var nest_at: Vector3 = wm.nest_spawn_position
	if where == "final":
		wm.final_wave = true
	var edges: Array = wm.edge_origins().duplicate() if wm.has_method("edge_origins") else wm.reinforce_positions.duplicate()
	match where:
		"nest_watched":
			hero.global_position = nest_at + (core - nest_at).normalized() * 6.0
		"edge_watched":
			hero.global_position = edges[0] + (core - edges[0]).normalized() * 3.0
		_:
			_main._walk_to_bench(cabin.station("workbench"))
	await _advance(6.0)
	_say("INFO", "%s: nest %s (seen by him: %s); edges behind it %s (first seen: %s); hero at %s" % [where, str(nest_at), fog.sees(nest_at) if fog.has_method("sees") else "?", str(edges), fog.sees(edges[0]) if fog.has_method("sees") else "?", str(hero.global_position)])
	var size := 30 if where == "final" else 14
	wm.start_wave(3, size)
	var origin := {}
	var popped: Array = []
	var hurried_seen: Array = []
	var fast_unseen := 0
	var back := {}
	var hist := {}
	var t := 0.0
	var dt := 0.05 if where == "nest_watched" else 0.25
	var fast_seen := {}
	var step := 0
	while t < (70.0 if where == "final" else 45.0):
		await _advance(dt)
		t += dt
		step += 1
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		for d in get_nodes_in_group("dinos"):
			if not is_instance_valid(d) or d.is_in_group("guard_dinos"):
				continue
			var id: int = d.get_instance_id()
			var p: Vector3 = (d as Node3D).global_position
			if not origin.has(id):
				var o := "?"
				if p.distance_to(nest_at) < 3.0:
					o = "nest"
				else:
					for k in edges.size():
						if p.distance_to(edges[k]) < 3.0:
							o = "edge%d" % k
				origin[id] = o
				# Stepped out where he can see it?
				if fog.is_in_sight(p):
					if popped.size() == 1:
						_look_at(hero.global_position.lerp(p, 0.5), 16.0)
						await _advance(0.1)
						await _shoot("%s_stepped_out_in_sight" % where)
					popped.append("%s at %s, %.1f m from him" % [o, str(p), p.distance_to(hero.global_position)])
			var v: float = Vector3(d.velocity.x, 0.0, d.velocity.z).length()
			var seen: bool = fog.is_in_sight(p)
			if seen and v > float(d.speed) * 1.3 and String(origin[id]).begins_with("edge"):
				fast_seen[id] = float(fast_seen.get(id, 0.0)) + dt
			if step % int(round(0.25 / dt)) != 0:
				continue
			if float(d.get("hurry")) > 1.0 and v > float(d.speed) * 1.3:
				if seen:
					hurried_seen.append("%.1f m/s at %s, %.1f m from the cabin" % [v, str(p), p.distance_to(core)])
				else:
					fast_unseen += 1
			var h: Array = hist.get(id, [])
			h.append(p.distance_to(core))
			if h.size() > 20:
				h.pop_front()
			hist[id] = h
			if h.size() == 20 and float(h[19]) - float(h.min()) > 6.0 and not bool(d.get("going_home")):
				back[id] = "%.1f s: %.1f m further from the cabin than 5 s ago, at %s" % [t, float(h[19]) - float(h.min()), str(p)]
	var counts := {}
	for id in origin:
		counts[origin[id]] = int(counts.get(origin[id], 0)) + 1
	_say("INFO", "%s: raid of %d -- came from %s (edges: %s)" % [where, size, str(counts), str(edges)])
	_say("INFO", "%s: samples running at double pace unseen %d; seen running at double pace: %d %s" % [where, fast_unseen, hurried_seen.size(), str(hurried_seen.slice(0, 3))])
	var worst_fast := 0.0
	for id in fast_seen:
		worst_fast = maxf(worst_fast, float(fast_seen[id]))
	_say("INFO", "%s: edge raiders seen going faster than 1.3x their pace: %d, the longest %.2f s in all (sampled every %.2f s)" % [where, fast_seen.size(), worst_fast, dt])
	_say("INFO", "%s: turned back (not going home): %d %s" % [where, back.size(), str(back.values().slice(0, 3))])
	_say("INFO", "%s: stepped out in his sight: %d %s" % [where, popped.size(), str(popped.slice(0, 3))])
	var ok := true
	match where:
		"plain":
			ok = int(counts.get("nest", 0)) <= int(cfg.RAIDS.get("nest_most", 5))
		"nest_watched":
			ok = int(counts.get("nest", 0)) == 0
		"edge_watched":
			ok = int(counts.get("edge0", 0)) == 0
		"final":
			ok = int(counts.get("nest", 0)) <= int(cfg.RAIDS.get("nest_most", 5)) and counts.size() == edges.size() + 1 and not counts.has("?")
	_say("PASS" if ok and hurried_seen.is_empty() and back.is_empty() and popped.is_empty() else "FAIL", "%s: where they came from, nobody stepping out in sight, nobody seen running, nobody turning back" % where)

## TASK-020 (04b79b1): the mist lit by the land under it, by the hour. He walks a round (west, south,
## east) so there is "been there" mist on screen, comes back, and at noon, dusk and night the opening
## camera is photographed and measured: every sampled pixel of the field is put to its world point
## (the ground plane) and sorted by what the fog says of it -- in sight, seen (thin mist), never seen
## (thick mist) -- keeping only points whose neighbours 1.5 m round say the same, so the soft edges
## do not count. The mean brightness of each layer, bright spots in the mist (samples far above
## its median), and how much the mist changes between two frames of a still camera (flicker). Then
## the camera zoomed out and lowered to the horizon, three frames, for the sky and the valley walls.
func _p_mist_hours() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	for off in [Vector3(-14.0, 0.0, 0.0), Vector3(-10.0, 0.0, 10.0), Vector3(0.0, 0.0, 14.0), Vector3(10.0, 0.0, 10.0), Vector3(14.0, 0.0, 0.0)]:
		var to: Vector3 = core + off
		hero.move_to(to)
		var tw := 0.0
		while tw < 12.0 and _flat3(hero.global_position).distance_to(_flat3(to)) > 1.5:
			await _advance(0.25)
			tw += 0.25
	hero.move_to(core + Vector3(0.0, 0.0, 4.5))
	await _advance(8.0)
	var rig = _main.camera_rig
	var parts: Dictionary = cfg.DAY["parts"]
	var verdicts: Array = []
	var kept := {}
	for hour in [["noon", 120.0], ["dusk", float(parts["dusk"]) + 12.0], ["night", float(parts["night"]) + 40.0]]:
		gs.day_clock = float(hour[1])
		rig.reset()
		rig.apply_to(_main.camera)
		await _advance(2.0)
		var m: Dictionary = _mist_layers()
		await _advance(0.2)
		var m2: Dictionary = _mist_layers()
		var flick: float = _layer_diff(m, m2)
		kept[hour[0]] = [hour[1], m]
		await _shoot("mist_" + String(hour[0]))
		var s: float = float(m["sight"][0])
		var thin: float = float(m["thin"][0])
		var thick: float = float(m["thick"][0])
		_say("INFO", "%s (clock %.0f, %s): brightness in sight %.3f (n %d), thin mist %.3f (n %d), thick mist %.3f (n %d); thick/sight %.2f, thin/sight %.2f; bright spots in the mist %d %s; mist change between two still frames %.4f" % [hour[0], gs.day_clock, gs.day_part(), s, int(m["sight"][1]), thin, int(m["thin"][1]), thick, int(m["thick"][1]), thick / maxf(0.001, s), thin / maxf(0.001, s), (m["spots"] as Array).size(), str((m["spots"] as Array).slice(0, 3)), flick])
		if hour[0] == "noon":
			verdicts.append(["noon: the mist not near-white (thick < 0.75) and not far brighter than the land (thick/sight <= 1.5)", thick < 0.75 and thick / maxf(0.001, s) <= 1.5])
		else:
			verdicts.append(["%s: both mists darker than what he sees" % hour[0], thick < s and thin < s])
		verdicts.append(["%s: three layers apart (thick and thin differ by 5%%+)" % hour[0], absf(thick - thin) / maxf(0.001, maxf(thick, thin)) >= 0.05])
		verdicts.append(["%s: no bright spots, no flicker (< 0.01)" % hour[0], (m["spots"] as Array).is_empty() and flick < 0.01])
	# The same pixels with the fog lifted: how bright the land under each layer is without it -- the
	# mist's own factor (Config.DAY.light mist) is mist / this.
	_main.fog.reveal_all()
	for key in kept:
		gs.day_clock = float(kept[key][0])
		rig.reset()
		rig.apply_to(_main.camera)
		await _advance(2.0)
		var img: Image = root.get_viewport().get_texture().get_image()
		var bare := {"sight": [0.0, 0], "thin": [0.0, 0], "thick": [0.0, 0]}
		var px: Dictionary = kept[key][1]["px"]
		for at in px:
			var c: Color = img.get_pixel(at.x, at.y)
			bare[px[at][0]][0] += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			bare[px[at][0]][1] += 1
		var line: Array = []
		for layer in ["sight", "thin", "thick"]:
			var under: float = float(bare[layer][0]) / maxf(1.0, float(bare[layer][1]))
			var with_fog: float = float(kept[key][1][layer][0])
			line.append("%s %.3f -> %.3f (x%.2f)" % [layer, under, with_fog, with_fog / maxf(0.001, under)])
		_say("INFO", "%s, the land with no fog -> with it: %s" % [key, ", ".join(line)])
		await _shoot("bare_" + String(key))
	# Zoomed out and lowered to the horizon, three frames, noon and night.
	for hour in [["noon", 120.0], ["night", float(parts["night"]) + 40.0]]:
		gs.day_clock = float(hour[1])
		rig.reset()
		rig.distance = 45.0
		rig.tilt_by(-90.0)
		rig.rotate_by(30.0)
		rig.apply_to(_main.camera)
		await _advance(1.5)
		var frames: Array = []
		for i in 3:
			frames.append(root.get_viewport().get_texture().get_image())
			await _advance(0.1)
		var worst := 0.0
		for i in range(1, 3):
			worst = maxf(worst, _image_diff(frames[i - 1], frames[i], 0.0, 0.45))
		await _shoot("horizon_" + String(hour[0]))
		_say("INFO", "%s at the horizon (tilt %.0f, distance %.0f): change between frames in the top 45%% of the screen %.4f" % [hour[0], rig.tilt, rig.distance, worst])
		verdicts.append(["%s at the horizon: no flicker (< 0.01)" % hour[0], worst < 0.01])
	for v in verdicts:
		_say("PASS" if v[1] else "FAIL", v[0])

## The field on screen sorted by the fog, brightness per layer; see _p_mist_hours.
func _mist_layers() -> Dictionary:
	var fog = _main.fog
	var cam: Camera3D = _main._active_camera()
	var img: Image = root.get_viewport().get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var k: float = float(w) / root.get_viewport().get_visible_rect().size.x
	var acc := {"sight": [0.0, 0], "thin": [0.0, 0], "thick": [0.0, 0]}
	var mist_samples: Array = []
	var layer_px := {}
	var centre: Vector3 = _main.current_core.global_position
	var half: float = float(root.get_node("GameState").map_data().get("terrain", {}).get("field_half", root.get_node("Config").TERRAIN.get("field_half", 22.0)))
	for y in range(int(h * 0.12), int(h * 0.8), 8):
		for x in range(int(w * 0.05), int(w * 0.78), 8):
			var sp := Vector2(x, y) / k
			var o: Vector3 = cam.project_ray_origin(sp)
			var d: Vector3 = cam.project_ray_normal(sp)
			if d.y > -0.02:
				continue
			var p: Vector3 = o + d * (-o.y / d.y)
			if absf(p.x - centre.x) > half or absf(p.z - centre.z) > half:
				continue
			var layer: String = _layer_of(fog, p)
			var same := true
			for e in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
				if _layer_of(fog, p + e) != layer:
					same = false
					break
			if not same:
				continue
			var c: Color = img.get_pixel(x, y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			acc[layer][0] += l
			acc[layer][1] += 1
			layer_px[Vector2i(x, y)] = [layer, l]
			if layer != "sight":
				mist_samples.append([l, p])
	var out := {}
	for layer in acc:
		out[layer] = [float(acc[layer][0]) / maxf(1.0, float(acc[layer][1])), int(acc[layer][1])]
	var ls: Array = []
	for s in mist_samples:
		ls.append(float(s[0]))
	ls.sort()
	var med: float = float(ls[ls.size() / 2]) if not ls.is_empty() else 0.0
	var spots: Array = []
	for s in mist_samples:
		if med > 0.0 and float(s[0]) > med * 1.6 and float(s[0]) - med > 0.12:
			spots.append("%.2f at (%.0f, %.0f)" % [float(s[0]), (s[1] as Vector3).x, (s[1] as Vector3).z])
	out["spots"] = spots
	out["px"] = layer_px
	return out

func _layer_of(fog, p: Vector3) -> String:
	return "sight" if fog.is_in_sight(p) else ("thin" if fog.is_seen(p) else "thick")

## Mean brightness change of the mist pixels between two measures of a still camera.
func _layer_diff(a: Dictionary, b: Dictionary) -> float:
	var total := 0.0
	var n := 0
	for key in a["px"]:
		if b["px"].has(key) and String(a["px"][key][0]) != "sight":
			total += absf(float(a["px"][key][1]) - float(b["px"][key][1]))
			n += 1
	return total / maxf(1.0, float(n))

## Mean brightness change between two frames, over the rows from `top` to `bottom` (shares of height).
func _image_diff(a: Image, b: Image, top: float, bottom: float) -> float:
	var total := 0.0
	var n := 0
	for y in range(int(a.get_height() * top) + int(a.get_height() * 0.08), int(a.get_height() * bottom), 8):
		for x in range(0, a.get_width(), 8):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			total += absf((ca.r + ca.g + ca.b) - (cb.r + cb.g + cb.b)) / 3.0
			n += 1
	return total / maxf(1.0, float(n))

## TASK-021 (772b9c9) parts 2-4: fire and the torch, the prowlers kept off (NightProwl disabled).
## Night 1, no fire: how far he sees (the moon) and the cabin; the torch tile and key 3, its badge,
## the light round him, the burnt-out word; the torch held walking and cutting. Day 2: a campfire and a
## brazier by the cabin; dusk 2 lights them and takes the night's wood once; how far round each is
## seen. First light puts them out. Dusk 3 with no wood: not lit, said once; wood brought, lit.
func _p_fire_night() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	var fog = _main.fog
	var gm = _main.grid_manager
	_main.wave_manager.auto_raid_enabled = false
	if _main.night_prowl:
		_main.night_prowl.enabled = false
	for g in get_nodes_in_group("guard_dinos"):
		g.queue_free()
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	if OS.get_environment("DA_LANG") != "":
		TranslationServer.set_locale(OS.get_environment("DA_LANG"))
		eb.locale_changed.emit(OS.get_environment("DA_LANG"))
	var cmds: Node = _find_with_method(root, "_refresh_torch")
	var tb: Button = cmds.get("torch_button") as Button if cmds else null
	var first_dusk: String = _after_fmt(tr("HINT_DUSK_FIRST"))
	var starved_txt: String = _after_fmt(tr("HINT_FIRE_STARVED"))
	var torch_out_txt: String = tr("HINT_TORCH_OUT").left(8)
	var starved := {"n": 0}
	eb.fire_starved.connect(func(_f): starved["n"] += 1)
	# --- Day 1, then dusk 1: the tile, the first dusk's word.
	gs.day_clock = 230.0
	hero.global_position = core + Vector3(0.0, 0.0, 12.0)
	hero.order_stop()
	await _advance(1.0)
	var tile_day: bool = tb != null and tb.is_visible_in_tree()
	gs.day_clock = 238.5
	var said_first := false
	var t := 0.0
	while t < 4.0:
		await _advance(0.25)
		t += 0.25
		if OS.get_environment("DA_DUSK_SHOT") != "" and not said_first and not _visible_labels(first_dusk).is_empty():
			await _shoot("first_dusk_hint_" + TranslationServer.get_locale())
		said_first = said_first or not _visible_labels(first_dusk).is_empty()
	var tile_dusk: bool = tb != null and tb.is_visible_in_tree()
	_say("INFO", "torch tile: by day %s, at dusk %s; the first dusk's word on fire on screen %s ('%s')" % [tile_day, tile_dusk, said_first, first_dusk])
	_say("PASS" if (not tile_day) and tile_dusk and said_first else "FAIL", "the torch tile only in the dark; the first dusk speaks of fire")
	# --- Night 1, no fire: how far he and the cabin see.
	gs.day_clock = 300.0
	await _advance(1.5)
	var his: Array = _sight_radius(fog, hero.global_position, [0, 45, 90, 135, 180, 225, 270, 315])
	var cab: Array = _sight_radius(fog, core, [180, 225, 270, 315, 0])
	_say("INFO", "night 1, no fire: he sees %.2f-%.2f m round him (FOG night %.2f x his 10 m); the cabin %.2f-%.2f m" % [his[0], his[1], float(cfg.FOG.get("night", 0.0)) if "FOG" in cfg else -1.0, cab[0], cab[1]])
	await _look_and_shoot(hero.global_position, 14.0, "night1_no_fire")
	# --- The torch: key 3.
	gs.resources["wood"] = 0
	gs.add_resource("wood", 5)
	await _advance(0.1)
	await _press(KEY_3)
	await _advance(0.5)
	var badge: Label = tb.get_node_or_null("Badge") as Label if tb else null
	_say("INFO", "key 3: torch_left %.1f, wood 5 -> %d; tile disabled %s, badge '%s' shown %s" % [hero.torch_left, int(gs.resources.get("wood", 0)), tb.disabled if tb else false, badge.text if badge else "?", badge.visible if badge else false])
	if hero.torch_left <= 0.0:
		_say("INFO", "key 3 did nothing: can_light_torch %s, window focused %s, hero state %d, focus owner %s, tile shortcut %s, keys live %s; pressing the tile instead" % [hero.can_light_torch(), DisplayServer.window_is_focused(), int(hero.current_state), str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() else "none", str(tb.shortcut != null), str(cmds.keys_live())])
		var hints_up: Array = _visible_labels(tr("HINT_NIGHT").left(4))
		await _press(KEY_3)
		await _advance(0.5)
		_say("INFO", "key 3 again: torch_left %.1f (the night hint was up: %d labels)" % [hero.torch_left, hints_up.size()])
		if hero.torch_left <= 0.0:
			tb.pressed.emit()
		await _advance(0.5)
		_say("INFO", "the tile pressed: torch_left %.1f, wood %d" % [hero.torch_left, int(gs.resources.get("wood", 0))])
	var lit_ok: bool = hero.torch_left > 55.0 and int(gs.resources.get("wood", 0)) == 4 and tb != null and tb.disabled
	await _advance(1.0)
	var tor: Array = _sight_radius(fog, hero.global_position, [0, 45, 90, 135, 180, 225, 270, 315])
	_say("INFO", "torch: he sees %.2f-%.2f m round him (torch light %.1f)" % [tor[0], tor[1], hero.torch_light()])
	await _look_and_shoot(hero.global_position, 10.0, "torch_standing")
	# Held walking and cutting.
	hero.move_to(core + Vector3(8.0, 0.0, 12.0))
	await _advance(1.2)
	await _look_and_shoot(hero.global_position, 7.0, "torch_walking")
	var tree: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood" and (tree == null or (n as Node3D).global_position.distance_to(hero.global_position) < tree.global_position.distance_to(hero.global_position)):
			tree = n
	if tree:
		hero.order_harvest(tree)
		var tw := 0.0
		while tw < 20.0 and int(hero.current_state) != 5:
			await _advance(0.25)
			tw += 0.25
		await _advance(1.0)
		await _look_and_shoot(hero.global_position, 7.0, "torch_cutting")
		hero.order_stop()
	# Burnt out: the badge counting, then the word.
	hero.torch_left = 8.0
	await _advance(3.0)
	var badge_mid: String = badge.text if badge else "?"
	var out_said := false
	var out_shot := false
	t = 0.0
	while t < 8.0:
		await _advance(0.25)
		t += 0.25
		if not out_shot and not _visible_labels(torch_out_txt).is_empty():
			out_shot = true
			await _shoot("torch_out_hint_" + TranslationServer.get_locale())
		out_said = out_said or not _visible_labels(torch_out_txt).is_empty()
	_say("INFO", "torch near its end: badge '%s' with ~5 s left; burnt out: torch_left %.1f, the word said %s, tile shown %s enabled %s" % [badge_mid, hero.torch_left, out_said, tb.is_visible_in_tree() if tb else false, not tb.disabled if tb else false])
	_say("PASS" if lit_ok and out_said and hero.torch_left <= 0.0 and tb.is_visible_in_tree() and not tb.disabled else "FAIL", "the torch: key 3 lights it for a wood, the tile counts down, it burns out and says so")
	# --- Day 2: a campfire and a brazier by the cabin.
	gs.day_clock = 360.0 + 200.0
	await _advance(1.0)
	var tile_day2: bool = tb != null and tb.is_visible_in_tree()
	var camp = _build_at("campfire", gm.world_to_build_cell(core + Vector3(6.0, 0.0, 3.0)))
	var braz = _build_at("brazier", gm.world_to_build_cell(core + Vector3(-6.0, 0.0, 3.0)))
	await _advance(1.0)
	if camp == null or braz == null:
		_say("FAIL", "could not build the fires")
		return
	gs.resources["wood"] = 10
	_say("INFO", "day 2: tile shown %s; campfire lit %s, brazier lit %s; wood 10" % [tile_day2, camp.lit, braz.lit])
	var day_out: bool = not camp.lit and not braz.lit
	gs.day_clock = 360.0 + 238.5
	await _advance(4.0)
	var w_dusk: int = int(gs.resources.get("wood", 0))
	_say("INFO", "dusk 2: campfire lit %s (light %.1f), brazier lit %s (light %.1f); wood 10 -> %d (want 10 - 2 - 3 = 5)" % [camp.lit, camp.light_radius(), braz.lit, braz.light_radius(), w_dusk])
	await _look_and_shoot(core + Vector3(0.0, 0.0, 3.0), 18.0, "fires_dusk2")
	gs.day_clock = 360.0 + 300.0
	hero.global_position = core + Vector3(0.0, 0.0, 16.0)
	hero.order_stop()
	await _advance(2.0)
	var w_night: int = int(gs.resources.get("wood", 0))
	var cs: Array = _sight_radius(fog, camp.global_position, [300, 330, 0, 30, 60])
	var bs: Array = _sight_radius(fog, braz.global_position, [120, 150, 180, 210, 240])
	_say("INFO", "night 2: wood %d (still %d?); round the campfire seen %.2f-%.2f m (lights %.0f); round the brazier %.2f-%.2f m (lights %.0f)" % [w_night, w_dusk, cs[0], cs[1], camp.light_radius(), bs[0], bs[1], braz.light_radius()])
	await _look_and_shoot(core + Vector3(0.0, 0.0, 3.0), 22.0, "fires_night2")
	await _look_and_shoot(camp.global_position, 6.0, "campfire_close")
	await _look_and_shoot(braz.global_position, 6.0, "brazier_close")
	# --- First light.
	gs.day_clock = 720.0 + 2.0
	await _advance(3.0)
	var dawn_out: bool = not camp.lit and not braz.lit
	_say("INFO", "first light: campfire lit %s, brazier lit %s; wood %d" % [camp.lit, braz.lit, int(gs.resources.get("wood", 0))])
	# --- Dusk 3 with no wood.
	gs.resources["wood"] = 0
	var n0: int = starved["n"]
	gs.day_clock = 720.0 + 238.5
	var shown := 0
	var was := false
	t = 0.0
	while t < 10.0:
		await _advance(0.25)
		t += 0.25
		var up: bool = not _visible_labels(starved_txt).is_empty()
		if up and not was:
			shown += 1
		was = up
	var starved_lit: bool = camp.lit or braz.lit
	gs.resources["wood"] = 10
	await _advance(3.0)
	_say("INFO", "dusk 3, no wood: lit %s; fire_starved %d, the word on screen %d time(s); wood 10 brought: campfire %s, brazier %s, wood now %d" % [starved_lit, starved["n"] - n0, shown, camp.lit, braz.lit, int(gs.resources.get("wood", 0))])
	_say("PASS" if day_out and camp.lit and braz.lit and w_dusk == 5 and w_night == 5 and dawn_out else "FAIL", "the fires: out by day, lit at dusk, the night's wood taken once, out at first light")
	_say("PASS" if not starved_lit and shown == 1 and camp.lit and braz.lit and int(gs.resources.get("wood", 0)) == 5 else "FAIL", "no wood: not lit, said once; wood brought, lit")
	_say("PASS" if absf(his[1] - 4.5) <= 1.0 and tor[0] >= 6.0 and cs[0] >= 6.0 and bs[0] >= 9.0 else "FAIL", "what is seen at night: about 4.5 m by the moon, the torch and the fires as far as they light")

## TASK-021 part 5 (7f8ee65): the phytosaurs. DA_PROWL: "dark" -- three nights, no fire, he at the bench
## inside the cabin; "lit" -- a campfire 5 m from the cabin; "torch" -- he out by the cabin with a
## torch, walking at the first one; the torch burnt out, then. Each: how many come up and where,
## how many out at once, what they go for and bite, the cabin's health, the nearest any comes to a
## light's middle, the eye-shine at the edge, and at first light whether all go home.
func _p_prowl() -> void:
	var mode: String = OS.get_environment("DA_PROWL") if OS.get_environment("DA_PROWL") != "" else "dark"
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var gm = _main.grid_manager
	_main.wave_manager.auto_raid_enabled = false
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	gs.resources["wood"] = 40
	var fire: Node = null
	if mode == "lit":
		fire = _build_at("campfire", gm.world_to_build_cell(core + Vector3(0.0, 0.0, 5.0)))
	if mode == "torch":
		hero.global_position = core + Vector3(-3.0, 0.0, 5.0)
		hero.order_stop()
	else:
		_main._walk_to_bench(cabin.station("workbench"))
	await _advance(6.0)
	var came: Array = []
	var from: Dictionary = {}
	var on_spawn := func(d):
		if d.is_in_group("prowlers"):
			came.append(d)
			from[d.get_instance_id()] = (d as Node3D).global_position
	eb.dino_spawned.connect(on_spawn)
	var nights: int = int(OS.get_environment("DA_NIGHTS")) if OS.get_environment("DA_NIGHTS") != "" else (3 if mode == "dark" else 1)
	var all_ok := true
	for night in nights:
		var base: float = 360.0 * night
		gs.day_clock = base + 268.0
		await _advance(1.0)
		if not is_instance_valid(cabin):
			break
		var hp0: float = cabin.current_hp
		var most := 0
		var goes_for := {}
		var nearest_light := INF
		var inside_samples := 0
		var wary_samples := 0
		var shine_samples := 0
		var torch_phase := "none"
		var dist_log: Array = []
		var walls0: int = _count_walls()
		var t := 0.0
		var shot := false
		var at_cabin := -1.0
		var life := {}
		var cornered: Array = []
		while gs.day_part() == "night" or gs.day_part() == "dusk":
			await _advance(0.25)
			t += 0.25
			var out := 0
			for d in get_nodes_in_group("prowlers"):
				if not is_instance_valid(d) or d.is_dead:
					continue
				if not d.going_home:
					out += 1
				var tg = d.current_target
				var what: String = "nothing" if tg == null or not is_instance_valid(tg) else (String(tg.building_type) if "building_type" in tg else ("hero" if tg.is_in_group("hero") else String(tg.name)))
				goes_for[what] = int(goes_for.get(what, 0)) + 1
				if at_cabin < 0.0 and tg == cabin and int(d.mode) == 2:
					at_cabin = t
				var lid: int = d.get_instance_id()
				if not life.has(lid):
					life[lid] = {"up": t, "bite": -1.0, "home": -1.0, "hp": d.current_hp}
				if float(life[lid]["bite"]) < 0.0 and int(d.mode) == 2:
					life[lid]["bite"] = t
				if float(life[lid]["home"]) < 0.0 and d.going_home:
					life[lid]["home"] = t
				life[lid]["last"] = t
				if d.current_hp < float(life[lid].get("hp_now", d.current_hp)) and int(life[lid].get("hits", 0)) < 3:
					life[lid]["hits"] = int(life[lid].get("hits", 0)) + 1
					var near: Array = []
					for o in get_nodes_in_group("dinos"):
						if o != d and is_instance_valid(o) and (o as Node3D).global_position.distance_to(d.global_position) < 4.0:
							near.append("%s %.1f m" % [String(o.dino_type), (o as Node3D).global_position.distance_to(d.global_position)])
					for b in get_nodes_in_group("buildings"):
						if is_instance_valid(b) and (b as Node3D).global_position.distance_to(d.global_position) < 6.0:
							near.append("%s %.1f m" % [String(b.building_type), (b as Node3D).global_position.distance_to(d.global_position)])
					_say("INFO", "a phytosaur hurt %.1f -> %.1f at %.1f s, at %s: he %.1f m off (state %d, inside %s); near it: %s" % [float(life[lid].get("hp_now", 0.0)), d.current_hp, t, str(d.global_position), _flat3(hero.global_position).distance_to(_flat3(d.global_position)), int(hero.current_state), str(cabin.hero_inside), ", ".join(near)])
				life[lid]["hp_now"] = d.current_hp
				if mode == "torch" and hero.torch_light() > 0.0 and _flat3(d.global_position).distance_to(_flat3(hero.global_position)) < 2.0 and cornered.size() < 3:
					cornered.append("at %s (he at %s), mode %d, wary %s, velocity %.2f" % [str(d.global_position), str(hero.global_position), int(d.mode), d.is_wary(), Vector3(d.velocity.x, 0, d.velocity.z).length()])
				for light in ProwlerDino.lights(self):
					var gap: float = Vector2(d.global_position.x - light["at"].x, d.global_position.z - light["at"].z).length()
					nearest_light = minf(nearest_light, gap - float(light["radius"]))
					if gap < float(light["radius"]) - float(cfg.PROWL.get("flee_inside", 1.6)) - 0.3:
						inside_samples += 1
				if d.is_wary():
					wary_samples += 1
					if d.eye_shine > 0.2:
						shine_samples += 1
					var near_l: Dictionary = ProwlerDino.light_over(self, d.global_position, 1.5)
					if not shot and mode != "dark" and not near_l.is_empty() and t > 20.0:
						shot = true
						await _look_and_shoot((d.global_position + (near_l["at"] as Vector3)) * 0.5, 12.0, "%s_at_the_edge" % mode)
						await _look_and_shoot(d.global_position, 6.0, "%s_eyes_close" % mode)
						await _look_and_shoot(d.global_position, 25.0, "%s_eyes_default" % mode)
			most = maxi(most, out)
			if mode == "torch":
				var first: Node3D = null
				for d in get_nodes_in_group("prowlers"):
					if is_instance_valid(d) and not d.is_dead and not d.going_home:
						first = d
						break
				if first != null:
					var gap_h: float = _flat3(first.global_position).distance_to(_flat3(hero.global_position))
					if torch_phase == "none" and gap_h < 14.0:
						torch_phase = "lit"
						hero.light_torch()
						_say("INFO", "torch: lit with the first %.1f m off" % gap_h)
					if torch_phase == "lit":
						hero.move_to(first.global_position)
						dist_log.append("%.1f" % gap_h)
						if dist_log.size() == 60:
							torch_phase = "out"
							hero.torch_left = 0.5
							hero.order_stop()
							_say("INFO", "torch: 15 s walking at it, the distance every 0.25 s: %s" % " ".join(dist_log))
							dist_log = []
					elif torch_phase == "out":
						dist_log.append("%.1f" % gap_h)
						if dist_log.size() == 40:
							torch_phase = "done"
							_say("INFO", "torch out: the next 10 s: %s; he was bitten to %.0f/%.0f" % [" ".join(dist_log), hero.current_hp, hero.max_hp])
			if t > 200.0:
				break
		var alive: Array = []
		for d in came:
			if is_instance_valid(d) and not d.is_dead:
				alive.append(d)
		var origins: Array = []
		for id in from:
			origins.append("(%.0f, %.0f)" % [from[id].x, from[id].z])
		_say("INFO", "%s night %d: came up %d so far in all from %s; most out at once %d; going for (samples) %s; cabin %.0f -> %.0f; walls lost %d; the first biting the cabin %.1f s into the dusk" % [mode, night + 1, came.size(), ", ".join(origins.slice(0, 8)), most, str(goes_for), hp0, cabin.current_hp if is_instance_valid(cabin) else 0.0, walls0 - _count_walls(), at_cabin])
		var lines: Array = []
		for lid in life:
			var L: Dictionary = life[lid]
			lines.append("up %.0f bite %.0f home %.0f last seen %.0f hp %.0f->%.0f" % [L["up"], L["bite"], L["home"], L["last"], L["hp"], L.get("hp_now", -1.0)])
		_say("INFO", "%s night %d, each one: %s" % [mode, night + 1, "; ".join(lines)])
		if not cornered.is_empty():
			_say("INFO", "torch: within 2 m of him with the torch lit: %s" % "; ".join(cornered))
		if mode != "dark":
			_say("INFO", "%s: nearest any came to a light's edge %.2f m (negative is inside); samples deeper than it stands %d; wary samples %d, eyes shining in %d" % [mode, nearest_light, inside_samples, wary_samples, shine_samples])
		# First light: they go home.
		await _advance(0.5)
		var t2 := 0.0
		while t2 < 60.0:
			var left := 0
			for d in get_nodes_in_group("prowlers"):
				if is_instance_valid(d) and not d.is_dead:
					left += 1
			if left == 0:
				break
			await _advance(0.5)
			t2 += 0.5
		var stuck: Array = []
		for d in get_nodes_in_group("prowlers"):
			if is_instance_valid(d) and not d.is_dead:
				stuck.append("%s going_home %s home %s" % [str(d.global_position), d.going_home, str(d.home)])
		_say("INFO", "%s night %d: first light -- all gone after %.1f s; still out after 60 s: %d %s" % [mode, night + 1, t2, stuck.size(), str(stuck.slice(0, 3))])
		var ok: bool = stuck.is_empty()
		if mode == "lit":
			ok = ok and most <= 1 and inside_samples == 0 and wary_samples > 0 and shine_samples > wary_samples / 2
		all_ok = all_ok and ok
		if not is_instance_valid(cabin) or cabin.current_hp <= 0.0:
			_say("INFO", "the cabin fell on night %d" % (night + 1))
			break
	_say("PASS" if all_ok else "FAIL", "the phytosaurs (%s): %s" % [mode, "at most one out, never in the light, eyes shining at its edge, all home at first light" if mode == "lit" else "all home at first light"])

## TASK-021 part 6: a raid's count is its own -- guards killed while it is out do not end it early.
func _p_raid_count() -> void:
	var gs := root.get_node("GameState")
	var wm = _main.wave_manager
	var cabin = _main.current_core
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(4.0)
	var spawned: Array = []
	var on_spawn := func(d):
		if not d.is_in_group("guard_dinos") and not d.is_in_group("prowlers"):
			spawned.append(d)
	root.get_node("EventBus").dino_spawned.connect(on_spawn)
	var ended := {"at": -1.0}
	wm.start_wave(2, 6)
	await _advance(2.0)
	var guards: int = 0
	for g in get_nodes_in_group("guard_dinos"):
		if is_instance_valid(g) and not g.is_dead:
			g.take_damage(99999.0)
			guards += 1
	var tw := 0.0
	while tw < 40.0 and spawned.size() < 6:
		await _advance(0.5)
		tw += 0.5
	await _advance(1.0)
	var raiders: Array = []
	for d in spawned:
		if is_instance_valid(d) and not d.is_dead:
			raiders.append(d)
	_say("INFO", "raid of 6 set out; %d guards killed as it went; %d raiders stepped out in %.1f s (%d alive), the wave active %s" % [guards, spawned.size(), tw + 3.0, raiders.size(), wm.is_wave_active])
	var active_while_out := true
	for i in raiders.size():
		raiders[i].take_damage(99999.0)
		await _advance(0.5)
		if i < raiders.size() - 1 and not wm.is_wave_active:
			active_while_out = false
			_say("INFO", "the wave ended with %d raiders still out" % (raiders.size() - 1 - i))
	await _advance(3.0)
	_say("INFO", "every raider killed: the wave active %s" % wm.is_wave_active)
	_say("PASS" if raiders.size() == 6 and active_while_out and not wm.is_wave_active else "FAIL", "a raid ends at its own count, the guards killed or not")

## How far round `at` is seen now: along each of `dirs` (degrees), the first point not seen, in 0.25 m
## steps -- [least, most].
func _sight_radius(fog, at: Vector3, dirs: Array) -> Array:
	var lo := INF
	var hi := 0.0
	for a in dirs:
		var dir := Vector3(cos(deg_to_rad(float(a))), 0.0, sin(deg_to_rad(float(a))))
		var r := 0.0
		while r < 25.0 and fog.sees(at + dir * (r + 0.25)):
			r += 0.25
		lo = minf(lo, r)
		hi = maxf(hi, r)
	return [lo, hi]

func _look_and_shoot(at: Vector3, distance: float, beat: String) -> void:
	_look_at(at, distance)
	await _advance(0.3)
	await _shoot(beat)

## The text of a line with a %s/%d in it, from after the first -- what shows whatever is put there.
func _after_fmt(s: String) -> String:
	for mark in ["%s", "%d"]:
		var i: int = s.find(mark)
		if i >= 0:
			var rest: String = s.substr(i + 2).strip_edges()
			if rest.length() >= 6:
				return rest.left(10)
			return s.left(i).strip_edges().left(10)
	return s.left(10)

## Found in a large-valley play:25 (7f8ee65): walking to a tree at night he was bitten from ten to none by
## phytosaurs, walking on the spot, never turning on them ("fight 0%"). Here: night, one phytosaur set
## down half way between him and a tree 9 m off, and he is sent to cut it. Every 0.25 s: his state, his
## health, how far the phytosaur is, how fast he goes -- does he turn on it, or walk on the spot.
func _p_bitten_on_the_way() -> void:
	var gs := root.get_node("GameState")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	_main.wave_manager.auto_raid_enabled = false
	_main.night_prowl.enabled = false
	gs.day_clock = 300.0
	hero.global_position = core + Vector3(0.0, 0.0, 5.0)
	hero.order_stop()
	await _advance(1.0)
	var tree: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		var dd: float = (n as Node3D).global_position.distance_to(hero.global_position)
		if String(n.resource_type) == "wood" and dd > 7.0 and (tree == null or dd < tree.global_position.distance_to(hero.global_position)):
			tree = n
	var o: Array[Vector3] = [hero.global_position.lerp(tree.global_position, 0.5)]
	_main.night_prowl.origins = o
	var p = _main.night_prowl.send_one()
	p.global_position = hero.global_position.lerp(tree.global_position, 0.55)
	await _advance(0.1)
	var hp0: float = hero.current_hp
	hero.order_harvest(tree)
	var log: Array = []
	var fought := false
	var t := 0.0
	while t < 12.0 and int(hero.current_state) != 4:
		await _advance(0.25)
		t += 0.25
		if int(hero.current_state) == 3:
			fought = true
		if log.size() < 24:
			log.append("%.2f:%d hp%.1f d%.1f v%.1f" % [t, int(hero.current_state), hero.current_hp, _flat3(hero.global_position).distance_to(_flat3(p.global_position)) if is_instance_valid(p) else -1.0, Vector3(hero.velocity.x, 0, hero.velocity.z).length()])
	_say("INFO", "tree %.1f m off, the phytosaur between; every 0.25 s (time:state hp distance speed): %s" % [tree.global_position.distance_to(core + Vector3(0.0, 0.0, 5.0)), " ".join(log)])
	_say("INFO", "after %.1f s: his state %d, health %.1f -> %.1f, turned on it %s, it alive %s" % [t, int(hero.current_state), hp0, hero.current_hp, fought, is_instance_valid(p) and not p.is_dead])
	_say("PASS" if fought or hero.current_hp >= hp0 - 1.0 else "FAIL", "bitten on his way to work, he turns on what bites him")

## GAME-DESIGN 3 "能力槽": the hero card's row of five, read off the real card -- each slot's name and hover
## text with nothing made, and again with one of each made (the unlocks granted). An empty one should
## say what goes there and where it is made; a held one its name and what it does. In DA_LANG.
func _p_kit_slots() -> void:
	var gs := root.get_node("GameState")
	if OS.get_environment("DA_LANG") != "":
		TranslationServer.set_locale(OS.get_environment("DA_LANG"))
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	await _advance(1.0)
	var panel: Node = _find_with_method(root, "_show_abilities")
	if panel == null:
		_say("FAIL", "no hero card with _show_abilities")
		return
	if panel.has_method("show_hero"):
		panel.show_hero(_main.hero)
	await _press(KEY_C)
	await _advance(0.5)
	var bad: Array = []
	for phase in ["empty", "made"]:
		if phase == "made":
			for u in ["bone_pick", "stone_axe", "bone_spear", "bone_armor", "hide_boots"]:
				gs.grant_unlock(u)
			panel._show_abilities(true)
			await _advance(0.5)
		var row: Node = panel.get("ability_row")
		var lines: Array = []
		for slot in row.get_children():
			var tip: String = String((slot as Control).tooltip_text)
			lines.append("%s: '%s'" % [slot.name, tip])
			if tip.strip_edges() == "" or tip.contains("KIT_") or tip.contains("RECIPE_") or tip.contains("%"):
				bad.append("%s %s: '%s'" % [phase, slot.name, tip])
			if phase == "made" and not tip.contains("—"):
				bad.append("%s %s says no effect: '%s'" % [phase, slot.name, tip])
		_say("INFO", "%s (%s): %d slots: %s" % [phase, TranslationServer.get_locale(), row.get_child_count(), "; ".join(lines)])
		await _shoot("kit_%s_%s" % [phase, TranslationServer.get_locale()])
	_say("PASS" if bad.is_empty() else "FAIL", "the kit row's hover texts%s" % ("" if bad.is_empty() else ": " + "; ".join(bad)))

## 7dd3f34: the game's own restart (Main.restart_game, as the game-over and pause menus call it), twice,
## then wood coming in -- does the old HUD's command row still answer, from outside the tree?
func _p_restart_twice() -> void:
	current_scene = _main
	var gs := root.get_node("GameState")
	for i in 2:
		_say("INFO", "restart %d" % (i + 1))
		current_scene.restart_game()
		for k in range(40):
			await process_frame
		_main = current_scene
		await _advance(1.0)
	_say("INFO", "wood coming in after two restarts")
	gs.add_resource("wood", 3)
	await _advance(1.0)
	var rows := 0
	for n in _all(root):
		if n.name == "HeroCommands":
			rows += 1
	_say("INFO", "HeroCommands nodes in the tree now: %d; orphan nodes %d" % [rows, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])

## TASK-023 (eb21574): what can be worked, told from the valley by what it is. In DA_MAP's valley: the
## opening camera at noon and at dusk (as the player sees it, and the fog lifted); the nearest tree and
## the nearest stone close up, whole and worked out; the hover lift -- the mouse put over a tree and a
## stone by real motion events, the lifted meshes counted and the brightness round it measured with and
## without; a sweep of the cursor across the field, frame by frame, for flicker; the camera round the
## cabin at four headings, for the taller trees in the way.
func _p_worked_look() -> void:
	var gs := root.get_node("GameState")
	var hero = _main.hero
	var core: Vector3 = _main.current_core.global_position
	var fog = _main.fog
	var rig = _main.camera_rig
	gs.day_clock = 120.0
	_main.wave_manager.auto_raid_enabled = false
	if _main.night_prowl:
		_main.night_prowl.enabled = false
	gs.grant_unlock("harvest_stone")
	await _advance(1.0)
	# The opening camera, noon and dusk, as seen and with everything seen.
	for hour in [["noon", 120.0], ["dusk", 252.0]]:
		gs.day_clock = float(hour[1])
		rig.reset()
		rig.apply_to(_main.camera)
		await _advance(1.5)
		await _shoot("open_%s" % hour[0])
	# The nearest tree and stone.
	var tree: Node3D = null
	var stone: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		var d: float = (n as Node3D).global_position.distance_to(core)
		if String(n.resource_type) == "wood" and (tree == null or d < tree.global_position.distance_to(core)):
			tree = n
		if String(n.resource_type) == "stone" and (stone == null or d < stone.global_position.distance_to(core)):
			stone = n
	gs.day_clock = 120.0
	fog.reveal_all()
	await _advance(1.0)
	rig.reset()
	rig.apply_to(_main.camera)
	await _advance(0.5)
	await _shoot("open_noon_revealed")
	# Hover: the cursor over each, by motion events.
	for node in [tree, stone]:
		_look_at(node.global_position, 14.0)
		await _advance(0.5)
		var at: Vector2 = _main._active_camera().unproject_position(node.global_position + Vector3(0.0, 0.8, 0.0))
		_move_mouse(Vector2(20.0, 400.0))
		await _advance(0.3)
		var before: float = _lum_round(at, 40)
		await _shoot("%s_no_hover" % node.resource_type)
		_move_mouse(at)
		await _advance(0.3)
		var after: float = _lum_round(at, 40)
		await _shoot("%s_hover" % node.resource_type)
		_say("INFO", "hover over the %s at %s: lifted meshes %d; brightness round it %.3f -> %.3f (x%.2f)" % [node.resource_type, str(node.global_position), _main.lifted().size(), before, after, after / maxf(0.001, before)])
		_move_mouse(Vector2(20.0, 400.0))
		await _advance(0.2)
		_say("INFO", "cursor away: lifted %d" % _main.lifted().size())
	# A sweep across the field: frame by frame, how many frames lift something and how often it changes.
	rig.reset()
	rig.apply_to(_main.camera)
	await _advance(0.5)
	var vs: Vector2 = root.get_visible_rect().size
	var changes := 0
	var lifted_frames := 0
	var last := -1
	for i in 120:
		_move_mouse(Vector2(vs.x * (0.1 + 0.6 * float(i) / 119.0), vs.y * 0.45))
		await process_frame
		var n: int = _main.lifted().size()
		if n > 0:
			lifted_frames += 1
		if last >= 0 and (n > 0) != (last > 0):
			changes += 1
		last = n
	_say("INFO", "a sweep across the field in 120 frames: lifted in %d frames, on/off changes %d" % [lifted_frames, changes])
	_move_mouse(Vector2(20.0, 400.0))
	# Worked out: the tree cut down, the stone quarried to nothing.
	for node in [tree, stone]:
		while not node.is_depleted:
			node.harvest(100)
		await _advance(0.5)
		_look_at(node.global_position, 9.0)
		await _advance(0.4)
		await _shoot("%s_worked_out" % node.resource_type)
		_say("INFO", "%s worked out: depleted %s, still in the group %s, pickable %s" % [node.resource_type, node.is_depleted, node.is_in_group("resource_nodes"), node.is_available() if node.has_method("is_available") else "?"])
	# The camera round the cabin: is the cabin or a fight hidden by the trees.
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		rig.reset()
		rig.rotate_by(yaw)
		rig.apply_to(_main.camera)
		await _advance(0.5)
		await _shoot("round_the_cabin_%d" % int(yaw))

func _move_mouse(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	root.push_input(ev, true)

## Mean brightness of the screen in a square `half` px round `at` (viewport coordinates).
func _lum_round(at: Vector2, half: int) -> float:
	var img: Image = root.get_viewport().get_texture().get_image()
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x
	var cx: int = int(at.x * k)
	var cy: int = int(at.y * k)
	var total := 0.0
	var n := 0
	for y in range(maxi(0, cy - half), mini(img.get_height(), cy + half), 2):
		for x in range(maxi(0, cx - half), mini(img.get_width(), cx + half), 2):
			var c: Color = img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return total / maxf(1.0, float(n))

## TASK-024 (592bac4): the corner's commands in the order they became his. DA_ORDER "dusk_first" (the
## first dusk before any meal) or "meal_first" (a meal cooked by day, then the dusk). At each step:
## which tiles show, left to right, each one's key and its screen x; Build's place must never move. The
## first dusk's words name the torch's own key; the keys press what they wear; by day the torch stays,
## greyed; eaten out, Eat stays greyed with 0. A menu open or a mended-wall card up: the keycaps go and
## come back the same. A language change there and back (I18n, not saved): nothing moves, the next dusk
## says nothing twice. A restart: Build alone again.
func _p_commands_order() -> void:
	var order: String = OS.get_environment("DA_ORDER") if OS.get_environment("DA_ORDER") != "" else "dusk_first"
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	var hero = _main.hero
	gs.day_clock = 100.0
	_main.wave_manager.auto_raid_enabled = false
	if _main.night_prowl:
		_main.night_prowl.enabled = false
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	await _advance(1.0)
	var cmds: Node = _find_with_method(root, "key_of")
	var bad: Array = []
	var build_x: float = (cmds.build_button as Control).global_position.x
	var check_build := func(when: String):
		var x: float = (cmds.build_button as Control).global_position.x
		if absf(x - build_x) > 0.5:
			bad.append("%s: Build moved %.1f -> %.1f" % [when, build_x, x])
	_say("INFO", "%s -- start: %s" % [order, _corner(cmds)])
	if _corner(cmds) != "build[1]":
		bad.append("start: %s, want build[1] alone" % _corner(cmds))
	await _press(KEY_1)
	await _advance(0.3)
	var build_opened: bool = cmds.build_button.button_pressed
	var keys_live_in_menu: bool = cmds.keys_live()
	await _press(KEY_ESCAPE)
	await _advance(0.3)
	_say("INFO", "key 1: the build menu open %s (keys live while it is: %s); closed: keys live %s, %s" % [build_opened, keys_live_in_menu, cmds.keys_live(), _corner(cmds)])
	if not build_opened:
		bad.append("key 1 did not open the build menu")
	var dish: String = String(cfg.DISHES.keys()[0])
	var hint_key := ""
	for step in (["dusk", "meal"] if order == "dusk_first" else ["meal", "dusk"]):
		if step == "meal":
			gs.stock_meal(dish)
			await _advance(0.5)
		else:
			gs.day_clock = 238.5
			var t := 0.0
			var frag: String = _after_fmt(tr("HINT_DUSK_FIRST"))
			while t < 4.0:
				await _advance(0.25)
				t += 0.25
				for l in _visible_labels(frag):
					hint_key = String(l.text)
			gs.add_resource("wood", 5)
			await _advance(0.3)
		check_build.call("after the %s" % step)
		_say("INFO", "%s -- after the %s: %s" % [order, step, _corner(cmds)])
	var want: String = "eat[3] torch[2] build[1]" if order == "dusk_first" else "torch[3] eat[2] build[1]"
	if _corner(cmds) != want:
		bad.append("both come: %s, want %s" % [_corner(cmds), want])
	var tk: String = cmds.key_of("torch")
	var said_key: bool = hint_key.contains("(%s)" % tk) or hint_key.contains("（%s）" % tk)
	_say("INFO", "the first dusk's words name key %s: %s ('%s')" % [tk, said_key, hint_key.right(60)])
	if not said_key:
		bad.append("the first dusk's words do not name the torch's key %s" % tk)
	# Each key presses what it wears.
	await _press(_keycode(tk))
	await _advance(0.5)
	var torch_ok: bool = hero.torch_left > 0.0
	var ek: String = cmds.key_of("eat")
	await _press(_keycode(ek))
	await _advance(0.3)
	var eat_ok: bool = cmds.eat_button.button_pressed
	await _press(KEY_ESCAPE)
	await _advance(0.3)
	_say("INFO", "key %s lit the torch %s; key %s opened Eat %s" % [tk, torch_ok, ek, eat_ok])
	if not torch_ok or not eat_ok:
		bad.append("a key did not press its tile (torch %s, eat %s)" % [torch_ok, eat_ok])
	# By day: the torch stays, greyed; its key does nothing. Eaten out: Eat stays, greyed, 0.
	hero.torch_left = 0.0
	gs.day_clock = 360.0 + 5.0
	await _advance(1.0)
	var wood0: int = int(gs.resources.get("wood", 0))
	await _press(_keycode(tk))
	await _advance(0.3)
	gs.meals = {}
	eb.meals_changed.emit(gs.meals)
	await _advance(0.5)
	var badge: Label = cmds.eat_button.get_node_or_null("Badge") as Label
	_say("INFO", "day 2: torch shown %s disabled %s, its key lit it %s (wood %d -> %d); Eat shown %s disabled %s badge '%s'; %s" % [cmds.torch_button.is_visible_in_tree(), cmds.torch_button.disabled, hero.torch_left > 0.0, wood0, int(gs.resources.get("wood", 0)), cmds.eat_button.is_visible_in_tree(), cmds.eat_button.disabled, badge.text if badge else "?", _corner(cmds)])
	if not cmds.torch_button.is_visible_in_tree() or not cmds.torch_button.disabled or hero.torch_left > 0.0:
		bad.append("by day the torch tile is not there greyed, or its key lit it")
	if not cmds.eat_button.is_visible_in_tree() or not cmds.eat_button.disabled:
		bad.append("eaten out, Eat is not there greyed")
	check_build.call("day 2")
	# A mended-wall card up: repair on key 1, the corner's keycaps gone and back the same.
	var wall = _build_at("wall", _main.grid_manager.world_to_build_cell(_main.current_core.global_position + Vector3(6.0, 0.0, 6.0)))
	wall.take_damage(wall.max_hp * 0.5)
	eb.unit_selected.emit(wall)
	await _advance(0.5)
	var live_card: bool = cmds.keys_live()
	eb.unit_deselected.emit()
	await _advance(0.5)
	_say("INFO", "a bitten wall's card up: corner keys live %s; put down: live %s, %s" % [live_card, cmds.keys_live(), _corner(cmds)])
	if live_card or not cmds.keys_live():
		bad.append("the corner's keys did not give way to the card and come back")
	# Language there and back (not saved), then the next dusk.
	var before: String = _corner(cmds)
	var i18n := root.get_node("I18n")
	var was: String = TranslationServer.get_locale()
	i18n.set_locale("zh_CN" if not was.begins_with("zh") else "en", false)
	await _advance(0.5)
	var mid: String = _corner(cmds)
	i18n.set_locale(was, false)
	await _advance(0.5)
	_say("INFO", "language %s -> other -> back: %s | %s | %s" % [was, before, mid, _corner(cmds)])
	if mid != before or _corner(cmds) != before:
		bad.append("a language change moved the corner: %s / %s / %s" % [before, mid, _corner(cmds)])
	check_build.call("after the language change")
	var first_again := false
	var frag2: String = _after_fmt(tr("HINT_DUSK_FIRST"))
	gs.day_clock = 360.0 + 238.5
	var t2 := 0.0
	while t2 < 4.0:
		await _advance(0.25)
		t2 += 0.25
		first_again = first_again or not _visible_labels(frag2).is_empty()
	_say("INFO", "dusk 2: the first dusk's words again %s" % first_again)
	if first_again:
		bad.append("the first dusk's words said again after a language change")
	await _shoot("corner_%s" % order)
	# A restart: Build alone.
	current_scene = _main
	current_scene.restart_game()
	for k in range(40):
		await process_frame
	_main = current_scene
	await _advance(1.0)
	var cmds2: Node = _find_with_method(root, "key_of")
	_say("INFO", "after a restart: %s" % _corner(cmds2))
	if _corner(cmds2) != "build[1]":
		bad.append("after a restart: %s" % _corner(cmds2))
	_say("PASS" if bad.is_empty() else "FAIL", "the corner's commands (%s)%s" % [order, "" if bad.is_empty() else ": " + "; ".join(bad)])

## The corner's tiles shown, left to right, each with the key it wears: "eat[3] torch[2] build[1]".
func _corner(cmds: Node) -> String:
	var out: Array = []
	for c in cmds.get_children():
		if c is Button and (c as Control).is_visible_in_tree():
			var id: String = {"BuildCommand": "build", "EatCommand": "eat", "TorchCommand": "torch"}.get(String(c.name), String(c.name))
			out.append("%s[%s]" % [id, cmds.key_of(id)])
	return " ".join(out)

func _keycode(text: String) -> int:
	return OS.find_keycode_from_string(text)

## TASK-025 (ee5c5dc): the ship's wrecks. The three smokes from the opening camera at noon, zoomed out and
## round at four headings, at dusk and at night; then each wreck close with the fog lifted, the cursor on
## it (the lift), and its card's line.
func _p_wrecks_look() -> void:
	var gs := root.get_node("GameState")
	var rig = _main.camera_rig
	var core: Vector3 = _main.current_core.global_position
	gs.day_clock = 120.0
	_main.wave_manager.auto_raid_enabled = false
	if _main.night_prowl:
		_main.night_prowl.enabled = false
	await _advance(2.0)
	var wrecks: Array = _wrecks()
	var lines: Array = []
	for w in wrecks:
		var smoke: Node = null
		for s in get_nodes_in_group("wreck_smoke"):
			if s.wreck == w:
				smoke = s
		lines.append("%s at %s (%.0f m from the cabin): drawn %s, smoke %s" % [w.resource_type, str(w.global_position), w.global_position.distance_to(core), w.is_visible_in_tree(), "smoking" if smoke != null and smoke.is_smoking() else "none"])
	_say("INFO", "wrecks: %s" % "; ".join(lines))
	rig.reset()
	rig.apply_to(_main.camera)
	await _advance(1.0)
	await _shoot("smoke_open_noon")
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		rig.reset()
		rig.distance = 45.0
		rig.rotate_by(yaw)
		rig.apply_to(_main.camera)
		await _advance(0.8)
		await _shoot("smoke_far_%d" % int(yaw))
	for hour in [["dusk", 252.0], ["night", 310.0]]:
		gs.day_clock = float(hour[1])
		rig.reset()
		rig.distance = 45.0
		rig.apply_to(_main.camera)
		await _advance(1.5)
		await _shoot("smoke_%s" % hour[0])
	gs.day_clock = 360.0 + 120.0
	_main.fog.reveal_all()
	await _advance(1.0)
	for w in wrecks:
		_look_at(w.global_position, 12.0)
		await _advance(0.5)
		var at: Vector2 = _main._active_camera().unproject_position(w.global_position + Vector3(0.0, 0.5, 0.0))
		_move_mouse(at)
		await _advance(0.3)
		var info: Dictionary = w.get_display_info()
		_say("INFO", "%s close: lifted %d under the cursor; picked by a click %s; card '%s' / '%s'" % [w.resource_type, _main.lifted().size(), str(_main._raycast_object(at) == w), String(info.get("kind_text", "")), String(info.get("status", ""))])
		await _shoot("wreck_%s" % w.resource_type)
		_move_mouse(Vector2(20.0, 400.0))

## TASK-025: DA_PART's wreck (antenna, battery or board) searched from the cabin, at DA_CLOCK (default
## noon), prowlers and guards as the map has them. A raptor set on him while he searches (DA_BITE=1).
## Then the part repairs its stage at the beacon, and what that stirs up comes in by the ways in.
func _p_wreck_search() -> void:
	var part: String = OS.get_environment("DA_PART") if OS.get_environment("DA_PART") != "" else "antenna"
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	gs.day_clock = float(OS.get_environment("DA_CLOCK")) if OS.get_environment("DA_CLOCK") != "" else 120.0
	wm.auto_raid_enabled = false
	if OS.get_environment("DA_STEPS") != "":
		gs.beacon_steps = int(OS.get_environment("DA_STEPS"))
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	var w: Node3D = null
	for n in _wrecks():
		if String(n.resource_type) == part:
			w = n
	var warned := {"n": 0}
	eb.guards_warned.connect(func(_g): warned["n"] += 1)
	var found_said: String = tr("HINT_FOUND_PART").left(6)
	hero.global_position = core + Vector3(0.0, 0.0, 4.5)
	hero.order_stop()
	if OS.get_environment("DA_TORCH") != "":
		gs.add_resource("wood", 3)
		hero.light_torch()
	await _advance(0.5)
	var hp0: float = hero.current_hp
	if OS.get_environment("DA_GRANT") != "":
		gs.add_resource(part, 1)
	else:
		hero.order_harvest(w)
	var t := 0.0
	var began := -1.0
	var got := -1.0
	var said := false
	var bitten := false
	var fought := false
	var resumed := false
	var biter: Node = null
	var states: Array = []
	while t < 90.0 and int(hero.current_state) != 4:
		await _advance(0.25)
		t += 0.25
		var st: int = int(hero.current_state)
		if began < 0.0 and st == 5:
			began = t
			await _look_and_shoot(w.global_position, 9.0, "%s_searching" % part)
		if began >= 0.0 and OS.get_environment("DA_BITE") != "" and biter == null and not bitten and t > began + 3.0:
			biter = load(String(cfg.get_dino_script_path("coelophysis"))).new()
			_main.add_child(biter)
			biter.setup("coelophysis")
			biter.global_position = hero.global_position + Vector3(1.2, 0.0, 0.0)
			biter.set_waypoints([hero.global_position])
			_say("INFO", "a raptor set on him %.1f s into the search" % (t - began))
		if biter != null:
			if hero.current_hp < hp0:
				bitten = true
			if st == 3:
				fought = true
			if fought and st == 5 and (not is_instance_valid(biter) or biter.is_dead):
				resumed = true
		said = said or not _visible_labels(found_said).is_empty()
		if got < 0.0 and int(gs.resources.get(part, 0)) > 0:
			got = t
		if states.is_empty() or states[states.size() - 1] != st:
			states.append(st)
		if got >= 0.0 and t > got + 2.0:
			break
		if OS.get_environment("DA_GRANT") != "" and got >= 0.0:
			break
	var chip: Control = _main.hud.resource_chips.get(part)
	var smoke_on := false
	for s in get_nodes_in_group("wreck_smoke"):
		if s.wreck == w and s.is_smoking():
			smoke_on = true
	_say("INFO", "%s at %s (clock %.0f %s): walked %.1f s, searching from then %.1f s to the part in the stock; states %s; guards warned %d; hp %.1f -> %.1f; found said %s; chip shown %s; smoke still %s; searched %s" % [part, str(w.global_position), gs.day_clock, gs.day_part(), began, (got - began) if got >= 0.0 else -1.0, str(states), warned["n"], hp0, hero.current_hp, said, chip.visible if chip else false, smoke_on, w.is_depleted])
	if biter != null:
		_say("INFO", "the raptor: bitten %s, he fought %s, took the search up again %s" % [bitten, fought, resumed])
	await _look_and_shoot(w.global_position, 9.0, "%s_searched" % part)
	if got < 0.0:
		_say("FAIL", "%s: the part never reached the stock (he is %s)" % [part, "dead" if int(hero.current_state) == 4 else "alive"])
		return
	# The beacon: this stage with and without its part.
	var bench = cabin.station(String(cfg.BEACON_STATION))
	var job: String = String(gs.beacon_next_job())
	var inputs: Dictionary = cfg.beacon_job(gs.map_data(), job)["inputs"]
	var need: String = ""
	for r in inputs:
		if cfg.is_part(String(r)):
			need = String(r)
		else:
			gs.add_resource(String(r), int(inputs[r]))
	if need != part:
		_say("INFO", "the next stage (%s) takes %s, not %s -- the stage's line is not tried" % [job, need, part])
		_say("PASS", "%s searched out and in the stock" % part)
		return
	var had: int = int(gs.resources.get(part, 0))
	gs.resources[part] = 0
	var without: bool = bench.can_afford(job)
	gs.resources[part] = had
	_main._walk_to_bench(bench)
	var t3 := 0.0
	while not cabin.hero_inside and t3 < 30.0:
		await _advance(0.25)
		t3 += 0.25
	var origins: Array = []
	var came: Array = []
	var on_spawn := func(d):
		if not d.is_in_group("guard_dinos") and not d.is_in_group("prowlers"):
			came.append(d)
			origins.append("(%.0f, %.0f)" % [(d as Node3D).global_position.x, (d as Node3D).global_position.z])
	eb.dino_spawned.connect(on_spawn)
	var began_job: bool = bench.begin(job)
	var t4 := 0.0
	while t4 < 60.0 and String(bench.active_recipe) != "":
		await _advance(0.5)
		t4 += 0.5
	await _advance(1.0)
	var stirred: int = int(wm.get("_stirred"))
	if stirred > 0:
		wm.start_stage_wave()
	await _advance(40.0)
	_say("INFO", "the stage stirred up %d (started by hand; its own countdown runs with the clock's raids)" % stirred)
	var at_cabin := 0
	for d in came:
		if is_instance_valid(d) and int(d.mode) == 2 and d.current_target == cabin:
			at_cabin += 1
	_say("INFO", "the beacon: stage %s without the %s affordable %s; begun %s, done in %.1f s; %s left %d, chip shown %s; stirred up %d from %s; biting the cabin 20 s on %d; nest %s" % [job, part, without, began_job, t4, part, int(gs.resources.get(part, 0)), chip.visible if chip else false, came.size(), ", ".join(origins), at_cabin, str(wm.nest_spawn_position)])
	_say("PASS" if (not without) and began_job and int(gs.resources.get(part, 0)) == 0 else "FAIL", "%s: searched out, into the stock, and it repairs its stage" % part)

func _wrecks() -> Array:
	var out: Array = []
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) in ["antenna", "battery", "board"]:
			out.append(n)
	return out

## TASK-026 (f3fbc72): the corner's tiles seen arriving, and plainly dull when he cannot give them. The
## torch tile's coming in at the first dusk, frame by frame (its scale, the brightness of its square,
## Build's x); then each tile's brightness can / cannot at noon, dusk and night with Eat's 0; then a
## bitten wall's card with its buttons (Repair can, Upgrade cannot).
func _p_corner_look() -> void:
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var hero = _main.hero
	gs.day_clock = 230.0
	_main.wave_manager.auto_raid_enabled = false
	if _main.night_prowl:
		_main.night_prowl.enabled = false
	await _advance(1.0)
	var cmds: Node = _find_with_method(root, "key_of")
	var build_x: float = cmds.build_button.global_position.x
	var base_torch: float = -1.0
	gs.day_clock = 239.9
	var frames: Array = []
	var moved := false
	var shots := 0
	var t0: int = Time.get_ticks_msec()
	var t := 0.0
	while t < 2.2:
		await process_frame
		t = float(Time.get_ticks_msec() - t0) / 1000.0
		if absf(cmds.build_button.global_position.x - build_x) > 0.5:
			moved = true
		var tb: Button = cmds.torch_button
		if tb.is_visible_in_tree():
			frames.append("%.2f:s%.2f l%.2f" % [t, tb.scale.x, _lum_rect(tb.get_global_rect())])
			if shots < 4 and (frames.size() == 2 or frames.size() == 12 or frames.size() == 30 or frames.size() == 70):
				shots += 1
				await _shoot("torch_coming_%d" % frames.size())
	_say("INFO", "the torch tile coming in (time:scale brightness): %s" % " ".join(frames.slice(0, 40)))
	# The Eat tile's coming in, every frame, its own scale and tint.
	var eb2 := root.get_node("EventBus")
	gs.stock_meal(String(root.get_node("Config").DISHES.keys()[0]))
	var eat_frames: Array = []
	for i in 24:
		await process_frame
		var eb_: Button = cmds.eat_button
		eat_frames.append("%d:vis%s s%.2f m(%.2f,%.2f,%.2f)" % [i, str(eb_.is_visible_in_tree()).left(1), eb_.scale.x, eb_.modulate.r, eb_.modulate.g, eb_.modulate.b])
	_say("INFO", "the Eat tile coming in, frame by frame (scale, modulate): %s" % " ".join(eat_frames))
	_say("INFO", "Build moved while it came in: %s" % moved)
	# Can and cannot: Build can; the torch by day cannot; Eat with no meals cannot.
	gs.stock_meal(String(root.get_node("Config").DISHES.keys()[0]))
	await _advance(2.5)
	gs.meals = {}
	eb.meals_changed.emit(gs.meals)
	for hour in [["noon", 360.0 + 120.0], ["dusk", 360.0 + 252.0], ["night", 360.0 + 310.0]]:
		gs.day_clock = float(hour[1])
		gs.resources["wood"] = 0
		eb.resources_changed.emit(gs.resources)
		await _advance(1.0)
		var line: Array = []
		for id in ["eat", "torch", "build"]:
			var b: Button = cmds.tile(id)
			line.append("%s %s %.3f" % [id, "cannot" if b.disabled else "can", _lum_rect(b.get_global_rect())])
		var badge: Label = cmds.eat_button.get_node_or_null("Badge") as Label
		var badge_col: Color = badge.get_theme_color("font_color") if badge else Color.BLACK
		_say("INFO", "%s: %s; Eat's badge '%s' colour %s" % [hour[0], ", ".join(line), badge.text if badge else "?", str(badge_col)])
		await _shoot("corner_%s" % hour[0])
	# A bitten wall's card: Repair can, Upgrade cannot.
	gs.day_clock = 360.0 * 2 + 120.0
	var wall = _build_at("set_crossbow", _main.grid_manager.world_to_build_cell(_main.current_core.global_position + Vector3(6.0, 0.0, 6.0)))
	wall.take_damage(wall.max_hp * 0.5)
	gs.resources["wood"] = 2
	gs.resources["stone"] = 2
	gs.resources["bone"] = 1
	eb.resources_changed.emit(gs.resources)
	eb.unit_selected.emit(wall)
	await _advance(0.8)
	var panel: Node = _find_with_method(root, "_show_abilities")
	var bl: Array = []
	for b in _all(panel):
		if b is Button and (b as Control).is_visible_in_tree() and String((b as Button).text) != "":
			bl.append("'%s' %s %.3f" % [(b as Button).text, "cannot" if (b as Button).disabled else "can", _lum_rect((b as Control).get_global_rect())])
	_say("INFO", "a bitten crossbow's card: %s" % "; ".join(bl))
	await _shoot("crossbow_card")

## Mean brightness of the screen over `r` (viewport coordinates).
func _lum_rect(r: Rect2) -> float:
	var img: Image = root.get_viewport().get_texture().get_image()
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x
	var total := 0.0
	var n := 0
	for y in range(int(r.position.y * k), int(r.end.y * k), 3):
		for x in range(int(r.position.x * k), int(r.end.x * k), 3):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c: Color = img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return total / maxf(1.0, float(n))

## TASK-027 (22743e4) 1: the player's corridor -- two rings of palisade round the cabin a cell apart (a
## one-metre corridor), the outer open at its west end, the inner short one cell on its east side: the
## raid's one way in. DA_RAID raiders (default 12) from the nest, too tough to die to the cabin's gun;
## every half second what they are doing, the stakes standing, the first to bite a wall and the first at
## the cabin; an overhead picture at 15 s and 40 s.
func _p_corridor() -> void:
	var n_raid: int = int(OS.get_environment("DA_RAID")) if OS.get_environment("DA_RAID") != "" else 12
	var gs := root.get_node("GameState")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var gm = _main.grid_manager
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	if _main.get("night_prowl") != null:
		_main.night_prowl.enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	var c: Vector2i = gm.world_to_build_cell(core)
	var stakes: Array = []
	for ring in [[2, "inner"], [4, "outer"]]:
		var m: int = int(ring[0])
		for x in range(c.x - 3 - m, c.x + 4 + m):
			for z in range(c.y - 1 - m, c.y + 2 + m):
				var edge: bool = x == c.x - 3 - m or x == c.x + 3 + m or z == c.y - 1 - m or z == c.y + 1 + m
				if not edge:
					continue
				if ring[1] == "outer" and x == c.x - 3 - m and absi(z - c.y) <= 1:
					continue        # the outer ring open at its west end
				if ring[1] == "inner" and x == c.x + 3 + m and z == c.y:
					continue        # the inner ring short one cell on its east side
				var b = _build_at("wall", Vector2i(x, z))
				if b != null:
					stakes.append(b)
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(8.0)
	_say("INFO", "corridor: %d stakes (cabin cell %s); raid of %d" % [stakes.size(), str(c), n_raid])
	var tough := func(d):
		if not d.is_in_group("guard_dinos") and not d.is_in_group("prowlers"):
			d.max_hp = 9999.0
			d.current_hp = 9999.0
	eb.dino_spawned.connect(tough)
	wm.start_wave(2, n_raid)
	var t := 0.0
	var first_bite := -1.0
	var first_bite_at := ""
	var first_cabin := -1.0
	var at_cabin_most := 0
	var line: Array = []
	while t < 90.0:
		await _advance(0.5)
		t += 0.5
		gs.day_clock = minf(float(gs.day_clock), 150.0)
		var modes := {}
		var at_cabin := 0
		for d in get_nodes_in_group("dinos"):
			if not is_instance_valid(d) or d.is_in_group("guard_dinos") or d.is_dead:
				continue
			var mname: String = String(d.Mode.keys()[int(d.mode)]).to_lower()
			modes[mname] = int(modes.get(mname, 0)) + 1
			var tg = d.current_target
			if first_bite < 0.0 and tg != null and is_instance_valid(tg) and "building_type" in tg and String(tg.building_type) == "wall" and int(d.mode) in [2, 3]:
				first_bite = t
				first_bite_at = "%s" % str((tg as Node3D).global_position)
			if tg == cabin and int(d.mode) == 2:
				at_cabin += 1
		if first_cabin < 0.0 and at_cabin > 0:
			first_cabin = t
		at_cabin_most = maxi(at_cabin_most, at_cabin)
		var standing := 0
		for w in stakes:
			if is_instance_valid(w) and not w.is_destroyed:
				standing += 1
		if int(t * 2.0) % 10 == 0:
			line.append("%.0fs %s stakes %d cabin %d" % [t, str(modes), standing, at_cabin])
		if is_equal_approx(t, 40.0):
			var who: Array = []
			for d in get_nodes_in_group("dinos"):
				if is_instance_valid(d) and not d.is_in_group("guard_dinos") and not d.is_dead and who.size() < 12:
					var tg2 = d.current_target
					who.append("(%.1f,%.1f) %s ->%s jam %s v%.2f slot %s" % [d.global_position.x, d.global_position.z, String(d.Mode.keys()[int(d.mode)]), (String(tg2.building_type) if tg2 != null and is_instance_valid(tg2) and "building_type" in tg2 else "-"), str(d.debug_state().get("jammed_for", "?")) if d.has_method("debug_state") else "?", Vector3(d.velocity.x, 0, d.velocity.z).length(), str(d.get("assigned_slot"))])
			_say("INFO", "at 40 s: " + " | ".join(who))
		if is_equal_approx(t, 15.0) or is_equal_approx(t, 40.0):
			_look_at(core, 26.0)
			await _advance(0.1)
			await _shoot("corridor_%ds" % int(t))
	var lost := 0
	for w in stakes:
		if not is_instance_valid(w) or w.is_destroyed:
			lost += 1
	for l in line:
		_say("INFO", "  " + l)
	_say("INFO", "corridor, raid of %d: first bit a stake at %.1f s %s; first at the cabin %.1f s; most at the cabin at once %d; stakes lost %d of %d" % [n_raid, first_bite, first_bite_at, first_cabin, at_cabin_most, lost, stakes.size()])

## TASK-027 (22743e4) 2-11: the round-five fixes, one after another on one level.
func _p_round5() -> void:
	var gs := root.get_node("GameState")
	var cfg := root.get_node("Config")
	var eb := root.get_node("EventBus")
	var wm = _main.wave_manager
	var gm = _main.grid_manager
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var rig = _main.camera_rig
	var fog = _main.fog
	gs.day_clock = 100.0
	wm.auto_raid_enabled = false
	_main.night_prowl.enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	hero.max_hp = 9999.0
	hero.current_hp = 9999.0
	await _advance(1.0)
	# 2. The view home: the camera sent far, the cabin's medallion clicked.
	rig.focus = core + Vector3(25.0, 0.0, 20.0)
	rig.apply_to(_main.camera)
	await _advance(0.3)
	var cv: Control = _main.hud.core_vital
	var cap: Label = cv.find_child("Keycap", true, false) as Label
	var at: Vector2 = cv.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		root.push_input(ev, true)
		await process_frame
	await _advance(0.5)
	var by_click: Vector3 = rig.focus
	rig.focus = core + Vector3(25.0, 0.0, 20.0)
	rig.apply_to(_main.camera)
	await _advance(0.3)
	await _press(KEY_R)
	await _advance(0.5)
	_say("INFO", "2. R from 32 m off: focus %.1f m from the cabin; the click's focus and R's are %.2f m apart" % [_flat3(rig.focus).distance_to(_flat3(core)), _flat3(rig.focus).distance_to(_flat3(by_click))])
	_say("INFO", "2. the medallion clicked with the view 32 m off: the view's focus now %.1f m from the cabin; its key chip '%s' shown %s" % [_flat3(rig.focus).distance_to(_flat3(core)), cap.text if cap else "?", cap.is_visible_in_tree() if cap else false])
	await _shoot("medallion_home")
	# 3. No "twitch#" over any head: a raid at the cabin a while.
	var tough := func(d):
		if not d.is_in_group("guard_dinos"):
			d.max_hp = 9999.0
			d.current_hp = 9999.0
	eb.dino_spawned.connect(tough)
	wm.start_wave(2, 6)
	await _advance(25.0)
	var marks := 0
	for n in _all(root):
		if n is Label3D and String((n as Label3D).text).to_lower().contains("twitch"):
			marks += 1
	_say("INFO", "3. twitch marks over heads with DINO_TWITCH_MARKS %s: %d" % ["set" if OS.has_environment("DINO_TWITCH_MARKS") else "unset", marks])
	# 4. At night, no fire, a raider at each end of the cabin: drawn?
	var ends: Array = []
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos") and not d.is_dead and ends.size() < 2:
			ends.append(d)
	var half_x: float = float(cfg.get_building_half("core").x) if cfg.has_method("get_building_half") else 3.5
	gs.day_clock = 300.0
	for i in ends.size():
		ends[i].set_physics_process(false)
		ends[i].global_position = core + Vector3((half_x + 0.8) * (1.0 if i == 0 else -1.0), 0.0, 0.0)
	await _advance(1.5)
	var drawn: Array = []
	for d in ends:
		if is_instance_valid(d):
			drawn.append("at (%.1f, %.1f): drawn %s, in sight %s" % [d.global_position.x, d.global_position.z, d.is_visible_in_tree(), fog.is_in_sight(d.global_position)])
	_say("INFO", "4. night, raiders at the cabin's ends: %s" % "; ".join(drawn))
	_look_at(core, 14.0)
	await _advance(0.2)
	await _shoot("night_cabin_ends")
	gs.day_clock = 360.0 + 2.0
	await _advance(1.5)
	var dawn: Array = []
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos") and not d.is_dead and d.global_position.distance_to(core) < 10.0:
			dawn.append("(%.1f,%.1f) drawn %s" % [d.global_position.x, d.global_position.z, d.is_visible_in_tree()])
	_say("INFO", "4. first light, raiders near the cabin: %s" % ", ".join(dawn))
	for d in get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos"):
			d.queue_free()
	await _advance(1.0)
	gs.day_clock = 360.0 + 100.0
	# 7. Through a campfire, not through a brazier.
	gs.resources["wood"] = 20
	gs.resources["stone"] = 20
	var camp = _build_at("campfire", gm.world_to_build_cell(core + Vector3(0.0, 0.0, 9.0)))
	var braz = _build_at("brazier", gm.world_to_build_cell(core + Vector3(0.0, 0.0, 13.0)))
	await _advance(2.0)
	for f in [camp, braz]:
		var fp: Vector3 = f.global_position
		hero.global_position = fp + Vector3(-4.0, 0.0, 0.0)
		hero.order_stop()
		await _advance(0.3)
		hero.move_to(fp + Vector3(4.0, 0.0, 0.0))
		var nearest := INF
		var tw := 0.0
		while tw < 6.0:
			await _advance(0.1)
			tw += 0.1
			nearest = minf(nearest, _flat3(hero.global_position).distance_to(_flat3(fp)))
		var raptor = load(String(cfg.get_dino_script_path("coelophysis"))).new()
		_main.add_child(raptor)
		raptor.setup("coelophysis")
		raptor.global_position = fp + Vector3(-4.0, 0.0, 0.0)
		raptor.set_waypoints([fp + Vector3(4.0, 0.0, 0.0), fp + Vector3(8.0, 0.0, 0.0)])
		var rnear := INF
		tw = 0.0
		while tw < 6.0:
			await _advance(0.1)
			tw += 0.1
			if is_instance_valid(raptor):
				rnear = minf(rnear, _flat3(raptor.global_position).distance_to(_flat3(fp)))
		if is_instance_valid(raptor):
			raptor.queue_free()
		_say("INFO", "7. %s at %s: he came within %.2f m of its middle walking across; a raptor within %.2f m" % [f.building_type, str(fp), nearest, rnear])
	# 8. A crossbow flush against each end of the cabin, built by him from outside.
	var c: Vector2i = gm.world_to_build_cell(core)
	var hs: Vector2i = (cfg.get_building_size("core") - Vector2i.ONE) / 2
	for side in [1, -1]:
		var cell := Vector2i(c.x + side * (hs.x + 1), c.y)
		for r in cfg.BUILDINGS["set_crossbow"].get("cost", {}):
			gs.resources[r] = int(gs.resources.get(r, 0)) + int(cfg.BUILDINGS["set_crossbow"]["cost"][r])
		var b = _main.build_system.place_at("set_crossbow", cell, _main.buildings_container, true, 0)
		if b == null:
			_say("INFO", "8. could not place a crossbow at %s" % str(cell))
			continue
		hero.global_position = core + Vector3(side * 6.0, 0.0, 4.0)
		hero.order_stop()
		await _advance(0.3)
		hero.order_build(b)
		var inside := false
		var tb := 0.0
		var stood: Vector3 = Vector3.INF
		while tb < 30.0 and not b.is_constructed:
			await _advance(0.25)
			tb += 0.25
			inside = inside or cabin.hero_inside
			if int(hero.current_state) == 2:
				stood = hero.global_position
		_say("INFO", "8. crossbow at the %s end %s: built %s in %.1f s; he went inside the cabin %s; he built from %s" % ["east" if side == 1 else "west", str(cell), b.is_constructed, tb, inside, str(stood)])
	# 9. A walk to where he cannot get: inside a small closed ring. How long does he run on the spot?
	var ring_c: Vector2i = gm.world_to_build_cell(core + Vector3(-10.0, 0.0, 8.0))
	for x in range(ring_c.x - 1, ring_c.x + 2):
		for z in range(ring_c.y - 1, ring_c.y + 2):
			if x != ring_c.x or z != ring_c.y:
				_build_at("wall", Vector2i(x, z))
	await _advance(2.0)
	hero.global_position = core + Vector3(-10.0, 0.0, 14.0)
	hero.order_stop()
	await _advance(0.5)
	hero.move_to(gm.build_cell_to_world(ring_c))
	var tr_ := 0.0
	var on_spot := 0.0
	var last: Vector3 = hero.global_position
	var stopped := -1.0
	while tr_ < 15.0:
		await _advance(0.25)
		tr_ += 0.25
		var moved: float = _flat3(hero.global_position).distance_to(_flat3(last))
		last = hero.global_position
		if int(hero.current_state) == 1 and moved < 0.05:
			on_spot += 0.25
		if stopped < 0.0 and int(hero.current_state) == 0:
			stopped = tr_
	_say("INFO", "9. sent inside a closed ring: stopped walking at %.2f s; on the spot (walking, not moving) %.2f s in all; he stands %.1f m from its middle" % [stopped, on_spot, _flat3(hero.global_position).distance_to(_flat3(gm.build_cell_to_world(ring_c)))])
	# 11. F9: a report, three quick ones, one paused.
	var dir := "user://bugreports"
	var before: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	await _press(KEY_QUOTELEFT)
	await _advance(0.5)
	var after: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	var fresh: Array = []
	for f in after:
		if not before.has(f):
			fresh.append(f)
	var summary := "none"
	for f in fresh:
		if String(f).ends_with(".json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
			if j is Dictionary:
				var keys: Array = (j as Dictionary).keys()
				var h: Dictionary = j.get("hero", {}) if j.get("hero") is Dictionary else {}
				var dl = j.get("dinos", [])
				summary = "keys %s; hero keys %s; dinos %d; events %d" % [str(keys), str(h.keys()), (dl as Array).size() if dl is Array else -1, (j.get("events", []) as Array).size() if j.get("events") is Array else -1]
	_say("INFO", "11. F9: new files %s; %s; said on screen %s" % [str(fresh), summary, not _visible_labels("bugreport").is_empty() or not _visible_labels("bug-").is_empty()])
	for i in 3:
		await _press(KEY_QUOTELEFT)
	await _advance(0.5)
	var after3: PackedStringArray = DirAccess.get_files_at(dir)
	gs.set("is_paused", true)
	paused = true
	await _press(KEY_QUOTELEFT)
	for i in 10:
		await process_frame
	paused = false
	gs.set("is_paused", false)
	var after4: PackedStringArray = DirAccess.get_files_at(dir)
	_say("INFO", "11. three quick F9s: files %d -> %d; one while paused: -> %d" % [after.size(), after3.size(), after4.size()])

## TASK-027 5, 6, 10: pictures -- first light and dusk from the opening camera; the nearest sandstone at
## noon, dusk and night; at night the cabin's gun at a phytosaur (three frames as it is hit), and the
## eyes at a campfire's edge.
func _p_round5_shots() -> void:
	var gs := root.get_node("GameState")
	var hero = _main.hero
	var cabin = _main.current_core
	var core: Vector3 = cabin.global_position
	var rig = _main.camera_rig
	_main.wave_manager.auto_raid_enabled = false
	_main.night_prowl.enabled = false
	cabin.max_hp = 100000.0
	cabin.current_hp = 100000.0
	for hour in [["dawn", 360.0 + 8.0], ["morning", 360.0 + 40.0], ["noon", 360.0 + 120.0], ["dusk_in", 360.0 + 245.0], ["dusk_late", 360.0 + 264.0]]:
		gs.day_clock = float(hour[1])
		rig.reset()
		rig.apply_to(_main.camera)
		await _advance(1.2)
		await _shoot("light_%s" % hour[0])
	var stone: Node3D = null
	for n in get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "stone" and (stone == null or (n as Node3D).global_position.distance_to(core) < stone.global_position.distance_to(core)):
			stone = n
	_main.fog.reveal_all()
	for hour in [["noon", 720.0 + 120.0], ["dusk", 720.0 + 252.0], ["night", 720.0 + 310.0]]:
		gs.day_clock = float(hour[1])
		_look_at(stone.global_position, 9.0)
		await _advance(1.0)
		await _shoot("sandstone_%s" % hour[0])
	# The gun at night.
	gs.day_clock = 1080.0 + 300.0
	_main._walk_to_bench(cabin.station("workbench"))
	await _advance(4.0)
	var o: Array[Vector3] = [core + Vector3(-9.0, 0.0, 0.0)]
	_main.night_prowl.origins = o
	var p = _main.night_prowl.send_one()
	p.max_hp = 9999.0
	p.current_hp = 9999.0
	var t := 0.0
	var hp0: float = p.current_hp
	while t < 30.0 and is_instance_valid(p) and p.current_hp >= hp0:
		await _advance(0.1)
		t += 0.1
	_look_at(p.global_position.lerp(core, 0.5), 12.0)
	var frames_n: int = int(OS.get_environment("DA_GUN_FRAMES")) if OS.get_environment("DA_GUN_FRAMES") != "" else 3
	for i in frames_n:
		await _advance(0.1)
		await _shoot("gun_at_night_%02d" % i)
	_say("INFO", "5. the gun first hit the phytosaur %.1f s after it came up, at %s" % [t, str(p.global_position) if is_instance_valid(p) else "?"])
	# The eyes at a campfire's edge.
	p.queue_free()
	gs.resources["wood"] = 10
	var camp = _build_at("campfire", _main.grid_manager.world_to_build_cell(core + Vector3(0.0, 0.0, 5.0)))
	await _advance(2.0)
	var q = _main.night_prowl.send_one()
	var t2 := 0.0
	while t2 < 40.0 and is_instance_valid(q) and not q.is_wary():
		await _advance(0.25)
		t2 += 0.25
	await _advance(3.0)
	_look_at(q.global_position, 8.0)
	await _advance(0.2)
	await _shoot("eyes_close")
	_look_at(q.global_position.lerp(camp.global_position, 0.5), 20.0)
	await _advance(0.2)
	await _shoot("eyes_20m")
	_say("INFO", "5. eyes: the phytosaur wary at the fire's edge after %.1f s, eye_shine %.2f" % [t2, q.eye_shine if is_instance_valid(q) else -1.0])

# ------------------------------------------------------------------------------
# Plumbing (same rules as tools/playtest.gd: frames and physics ticks, never wall-clock)
# ------------------------------------------------------------------------------

func _say(verdict: String, text: String) -> void:
	print("[probe] %s %s: %s" % [_probe, verdict, text])

func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out

func _fresh_level() -> void:
	_tear_down()
	var gs := root.get_node_or_null("GameState")
	# DA_MAP: the map to build (since TASK-018: "valley_large"); a scripted level is the small valley
	# unless told otherwise.
	if gs and OS.get_environment("DA_MAP") != "" and "chosen_map_id" in gs:
		gs.chosen_map_id = OS.get_environment("DA_MAP")
	if gs and gs.has_method("reset_game"):
		gs.reset_game()
	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)
	for i in range(SETTLE_FRAMES):
		await process_frame

func _tear_down() -> void:
	if _main != null and is_instance_valid(_main):
		root.remove_child(_main)
		_main.queue_free()
	_main = null

func _advance(seconds: float) -> void:
	for i in range(int(round(seconds * 60.0))):
		await physics_frame

func _shoot(beat: String) -> void:
	for i in range(6):
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s_%s.png" % [OUT_DIR, _shot, _probe, beat]
	if img.save_png(path) == OK:
		_shot += 1
		print("[probe] frame %s" % path)

func _portrait(beat: String, at: Vector3, distance: float) -> void:
	var cam := Camera3D.new()
	_main.add_child(cam)
	cam.position = at + Vector3(0.0, distance, distance * 0.28)
	cam.look_at(at + Vector3(0.0, 0.6, 0.0), Vector3.UP)
	var was: Camera3D = _main.camera
	# A close-up is of the model: the fog lifted for it and put back after, as tools/playtest.gd does.
	var fog = _main.get("fog")
	var lifted: bool = fog != null and is_instance_valid(fog) and not bool(fog.revealed)
	if lifted:
		fog.revealed = true
		fog._paint(1.0)
		fog._hide_the_unseen()
	cam.current = true
	await _shoot(beat)
	cam.current = false
	if lifted:
		fog.revealed = false
	if was != null and is_instance_valid(was):
		was.current = true
	cam.queue_free()
