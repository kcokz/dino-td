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
	cam.current = true
	await _shoot(beat)
	cam.current = false
	if was != null and is_instance_valid(was):
		was.current = true
	cam.queue_free()
