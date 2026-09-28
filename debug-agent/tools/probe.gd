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
		names = ["stage_wave_size", "pause_snapshot", "cabin_sortie", "launch_button", "gate_traffic", "build_under_him", "after_the_jump"]
	for n in names:
		_probe = n
		await _fresh_level()
		match n:
			"stage_wave_size": await _p_stage_wave_size()
			"pause_snapshot": await _p_pause_snapshot()
			"cabin_sortie": await _p_cabin_sortie()
			"launch_button": await _p_launch_button()
			"gate_traffic": await _p_gate_traffic()
			"build_under_him": await _p_build_under_him()
			"after_the_jump": await _p_after_the_jump()
			_: _say("INFO", "unknown probe")
		_tear_down()
	quit(0)

# ------------------------------------------------------------------------------
# Probes
# ------------------------------------------------------------------------------

## A beacon stage repaired while the next raid's warning is already running: GAME-DESIGN 8.3 says
## the stage's small raid "顶替下一次普通来袭" ~20 s later. Measures how big the next raid then is,
## against the same raid with no stage repaired. Run with the next raid a BIG one (wave 3).
func _p_stage_wave_size() -> void:
	var sizes := {}
	for with_stage in [false, true]:
		await _fresh_level()
		var gs := root.get_node("GameState")
		var wm = _main.wave_manager
		# Five minutes in, raid 2 held, raid 3 (big, alpha at its head) 12 s away and announced.
		wm.elapsed_time = 300.0
		wm.current_wave = 2
		gs.wave_number = 2
		wm.raid_timer = 12.0
		wm.warning_emitted = true
		var ordinary: int = wm.raid_size(3)
		if with_stage:
			gs.finish_beacon_job(String(gs.beacon_next_job()))
		var started := {"n": -1}
		root.get_node("EventBus").wave_started.connect(func(n, _big): started["n"] = n)
		var t := 0.0
		while started["n"] < 0 and t < 40.0:
			await _advance(0.25)
			t += 0.25
		sizes[with_stage] = {"roster": wm.wave_roster.duplicate(), "after": t, "ordinary_estimate": ordinary}
	var a: Array = sizes[false]["roster"]
	var b: Array = sizes[true]["roster"]
	_say("INFO", "no stage: raid 3 = %d %s after %.1fs" % [a.size(), str(a), sizes[false]["after"]])
	_say("INFO", "stage 1 repaired during the warning: raid 3 = %d %s after %.1fs" % [b.size(), str(b), sizes[true]["after"]])
	_say("FAIL" if b.size() < a.size() else "PASS", "repairing a stage %s the imminent big raid (%d -> %d)" % ["SHRANK" if b.size() < a.size() else "did not shrink", a.size(), b.size()])

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

func _build_at(type_id: String, cell: Vector2i) -> Node:
	var b = _main.build_system.place_at(type_id, cell, _main.buildings_container, true, 0)
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
