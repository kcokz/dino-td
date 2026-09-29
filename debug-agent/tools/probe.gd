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
	gs.day_clock = 80.0
	_main.wave_manager.auto_raid_enabled = false
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
