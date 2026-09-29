# res://tests/test_v06_the_twitch_watch.gd
# v0.6 round four: "我觉得你需要做一个恐龙抽搐detector，如果恐龙抽搐，它就立刻report一些debug 信息，这个在
# release的时候甚至可以作为telemetry".
#
# Every animal on the field is watched for what a player sees as a twitch (TwitchWatch,
# Config.TWITCH), and one that twitches is reported at once -- to the log, to the bus and to a file
# of JSON lines: what it has in mind, its route, what is round it, its last seconds -- and, in a
# debug build, marked on the field with the report's number. A raid about its business is not.
#
# Each twitch is played on an animal whose own mind is stopped, moved by the test frame by frame.
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _reports: Array = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.reset_game()
	_reports.clear()
	var eb = tree.root.get_node("EventBus")
	if not eb.twitch_detected.is_connected(_on_twitch):
		eb.twitch_detected.connect(_on_twitch)

func after_each() -> void:
	var eb = tree.root.get_node("EventBus")
	if eb.twitch_detected.is_connected(_on_twitch):
		eb.twitch_detected.disconnect(_on_twitch)
	if game_state_node != null:
		game_state_node.is_paused = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _on_twitch(record: Dictionary) -> void:
	_reports.append(record)

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _tw() -> Dictionary:
	return config_node.TWITCH

## A raider on the field with its own mind stopped: only the test moves it.
func _raider(main: Node, at: Vector3) -> Node3D:
	var species: String = String(game_state_node.map_data()["raiders"].keys()[0])
	var d = load(String(config_node.get_dino_script_path(species))).new()
	main.dinos_container.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = at
	return d

## Physics frames for `seconds` of game time and a bucket or two more, for the last to be judged.
func _frames_for(seconds: float) -> int:
	return int(ceil((seconds + float(_tw()["bucket"]) * 2.0) * float(Engine.physics_ticks_per_second)))

func _reports_on(d: Node, kind: String = "") -> Array:
	var out: Array = []
	for r in _reports:
		if int(r["dino"]["id"]) == d.get_instance_id() and (kind == "" or String(r["kind"]) == kind):
			out.append(r)
	return out

## Well away from the cabin and its gun, where nothing else is.
func _clear_ground(main: Node) -> Vector3:
	return main.current_core.global_position + Vector3(-10.0, 0.0, 8.0)

## Steps it back and forth on the spot, a leg long enough to be seen each way, for `frames`.
func _jitter(d: Node3D, at: Vector3, frames: int) -> void:
	var leg: float = float(_tw()["leg_min"]) * 2.0
	for i in frames:
		await wait_physics_frames(1)
		d.global_position = at + Vector3(leg if i % 2 == 0 else 0.0, 0.0, 0.0)

# ==============================================================================
# 1. What counts
# ==============================================================================

func test_01_stepping_back_and_forth_on_the_spot_is_jitter_and_the_report_says_why() -> void:
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	await _jitter(d, at, _frames_for(float(_tw()["window"])))
	var got: Array = _reports_on(d, "jitter")
	assert_eq(got.size(), 1, "Stepping back and forth on the spot is reported -- once")
	if got.is_empty():
		return
	var r: Dictionary = got[0]
	assert_gte(int(r["window"]["jitter"]), int(_tw()["jitter_flips"]), "It counted the steps back")
	assert_lte(float(r["window"]["net"]), float(_tw()["jitter_net"]), "and that it got nowhere")
	for key in ["species", "mode", "target", "route", "waypoint", "pressed", "stuck", "velocity", "in_sight"]:
		assert_true(r["dino"].has(key), "The report says its %s" % key)
	assert_eq(String(r["dino"]["species"]), String(d.dino_type), "whose it is")
	assert_eq(String(r["game"]["map"]), String(game_state_node.map_id), "which map")
	assert_ne(String(r["game"]["version"]), "", "which build")
	assert_true(r["near"].has("animals") and r["near"].has("buildings"), "what was round it")
	assert_eq((r["trail"]["frames"] as Array).size(), int(_tw()["frames"]), "and its last frames")
	assert_gt((r["trail"]["buckets"] as Array).size(), 0, "and its last seconds")
	assert_true(JSON.stringify(r) != "", "all of it plain values, for a line of JSON")

func test_02_its_heading_swinging_back_and_forth_is_shake() -> void:
	# The debug-agent's BUG-005: "左右各摆 48°", in half a metre, for seconds.
	var main = await _level()
	var d = _raider(main, _clear_ground(main))
	var swing: float = deg_to_rad(float(_tw()["swing_min_deg"]) * 2.0)
	for i in _frames_for(float(_tw()["window"])):
		await wait_physics_frames(1)
		d.rotation.y += (swing / 4.0) * (1.0 if (i / 4) % 2 == 0 else -1.0)
	assert_eq(_reports_on(d, "shake").size(), 1, "A heading swung back and forth on the spot is reported")

func test_03_its_mind_going_back_and_forth_is_dither() -> void:
	var main = await _level()
	var d = _raider(main, _clear_ground(main))
	for i in _frames_for(float(_tw()["window"])):
		await wait_physics_frames(1)
		d.current_target = main.current_core if (i / 10) % 2 == 0 else main.hero
	assert_eq(_reports_on(d, "dither").size(), 1, "Going for a thing, letting go, going for it is reported")

func test_04_drawn_walking_and_standing_by_turns_is_flicker() -> void:
	var main = await _level()
	var d = _raider(main, _clear_ground(main))
	assert_not_null(d.animator, "It is drawn by an animator")
	if d.animator == null:
		return
	for i in _frames_for(float(_tw()["window"])):
		await wait_physics_frames(1)
		d.animator.current_clip = "walk" if (i / 6) % 2 == 0 else "idle"
	assert_eq(_reports_on(d, "flicker").size(), 1, "Walk, stand, walk is reported")

func test_05_asking_to_walk_and_getting_nowhere_is_push() -> void:
	# "全速顶着什么": longer than its own rules let it -- it bites a wall it is against by then.
	assert_gte(float(_tw()["push_window"]),
		float(config_node.DINO_AI["stuck_window"]) * float(config_node.DINO_AI["wall_patience"]),
		"A push is reported only once its own rules have had their say")
	var main = await _level()
	var d = _raider(main, _clear_ground(main))
	d.velocity = Vector3(float(_tw()["push_speed"]) * 2.0, 0.0, 0.0)
	for i in _frames_for(float(_tw()["push_window"])):
		await wait_physics_frames(1)
	assert_eq(_reports_on(d, "push").size(), 1, "Asking to walk and standing still is reported")

func test_06_round_and_round_getting_nowhere_is_mill_but_not_after_the_hero() -> void:
	# "转来转去".
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	var radius: float = float(_tw()["mill_net"]) * 0.45
	var seconds: float = float(_tw()["mill_window"])
	var pace: float = float(_tw()["mill_path"]) / seconds * 1.5
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var angle: float = 0.0
	for i in _frames_for(seconds):
		await wait_physics_frames(1)
		angle += pace / radius * dt
		d.global_position = at + Vector3(cos(angle), 0.0, sin(angle)) * radius
		d.rotation.y = -angle
	assert_eq(_reports_on(d, "mill").size(), 1, "Walking round and round and getting nowhere is reported")
	var chaser = _raider(main, at + Vector3(4.0, 0.0, 0.0))
	chaser.current_target = main.hero
	for i in _frames_for(seconds):
		await wait_physics_frames(1)
		angle += pace / radius * dt
		chaser.global_position = at + Vector3(4.0, 0.0, 0.0) + Vector3(cos(angle), 0.0, sin(angle)) * radius
	assert_eq(_reports_on(chaser, "mill").size(), 0, "Not one after the Hero: it goes round what he goes round")

# ==============================================================================
# 2. And what does not
# ==============================================================================

func test_07_a_raid_about_its_business_is_not_reported() -> void:
	# The other half of a watch: a plain raid walking to the cabin and biting it, and the nest's
	# guards about their posts, twitch at nothing.
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = false
	main.current_core.max_hp = 99999.0
	main.current_core.current_hp = 99999.0
	# He is off to one side and cannot be killed: what the raid does about him is its business.
	main.hero.max_hp = 99999.0
	main.hero.current_hp = 99999.0
	main.hero.global_position = main.current_core.global_position + Vector3(14.0, 0.0, 14.0)
	wm.start_wave(1, 5)
	for i in _frames_for(20.0):
		await wait_physics_frames(1)
	var raid: int = 0
	for d in tree.get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos"):
			raid += 1
	assert_gt(raid, 0, "(the raid is out)")
	for r in _reports:
		assert_true(false, "Nothing to report: %s" % JSON.stringify({"kind": r["kind"], "window": r["window"],
			"dino": {"species": r["dino"]["species"], "mode": r["dino"]["mode"], "pos": r["dino"]["pos"]}}))

func test_08_once_reported_it_waits_out_the_cooldown() -> void:
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	await _jitter(d, at, _frames_for(float(_tw()["window"]) + float(_tw()["cooldown"]) * 0.5))
	assert_eq(_reports_on(d, "jitter").size(), 1, "Still at it within the cooldown: not reported again")

func test_09_paused_nothing_is_watched() -> void:
	# The pause is a snapshot (test_v06_pause_is_a_snapshot): the watch stops with the game.
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	game_state_node.is_paused = true
	await _jitter(d, at, _frames_for(float(_tw()["window"])))
	assert_eq(_reports_on(d).size(), 0, "Nothing is counted while the game is paused")

# ==============================================================================
# 3. Where a report goes
# ==============================================================================

func test_10_a_report_is_a_line_of_json_in_the_launchs_file() -> void:
	var dir: String = "user://twitch_watch_test"
	TwitchWatch.to_file = true
	TwitchWatch.file_dir = dir
	TwitchWatch.file_path = ""
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	await _jitter(d, at, _frames_for(float(_tw()["window"])))
	var path: String = TwitchWatch.file_path
	TwitchWatch.to_file = false
	TwitchWatch.file_dir = ""
	TwitchWatch.file_path = ""
	assert_true(path.begins_with(dir) and FileAccess.file_exists(path), "The launch's file is written")
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert_eq(lines.size(), 2, "A line to say which launch, and a line for the report")
	if lines.size() == 2:
		var head = JSON.parse_string(lines[0])
		var record = JSON.parse_string(lines[1])
		assert_true(head is Dictionary and head.has("launch") and head.has("version"), "The launch: when, and which build")
		assert_true(record is Dictionary and String(record.get("kind", "")) == "jitter", "The report, as it was reported")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func test_11_in_a_debug_build_it_is_marked_with_the_reports_number() -> void:
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	await _jitter(d, at, _frames_for(float(_tw()["window"])))
	var got: Array = _reports_on(d, "jitter")
	assert_eq(got.size(), 1, "(reported)")
	if got.is_empty() or not OS.is_debug_build():
		return
	var mark: Label3D = d.get_node_or_null("TwitchMark") as Label3D
	assert_not_null(mark, "It is marked on the field")
	if mark != null:
		assert_eq(mark.text, tr("TWITCH_MARK") % int(got[0]["n"]), "with the report's number")
	for i in _frames_for(float(_tw()["mark_seconds"])):
		await wait_physics_frames(1)
	assert_null(d.get_node_or_null("TwitchMark"), "for a moment")

func test_12_standing_and_swinging_its_head_slowly_is_fidget() -> void:
	# The debug-agent's BUG-008: "原地一动不动、每秒来回摆一次头，摆了 22 秒，没有报告" -- each swing
	# lapsed in the stand before the next (settle), and SHAKE never counted to three.
	var main = await _level()
	var d = _raider(main, _clear_ground(main))
	var swing: float = deg_to_rad(float(_tw()["swing_min_deg"]) * 1.5)
	var per: int = int(Engine.physics_ticks_per_second)       # a swing each second: turned, then still
	for i in _frames_for(float(_tw()["fidget_window"]) + 1.0):
		await wait_physics_frames(1)
		var phase: int = i % per
		if phase < 6:
			d.rotation.y += (swing / 6.0) * (1.0 if (i / per) % 2 == 0 else -1.0)
	assert_eq(_reports_on(d, "fidget").size(), 1, "Standing still, its head going each way every second, is reported")
	assert_eq(_reports_on(d, "shake").size(), 0, "(not as SHAKE: it stood between)")

func test_12b_turning_for_home_is_not_milling() -> void:
	# The debug-agent's BUG-015: at the first moment of dusk six raiders on their way in were reported
	# milling -- three seconds towards the cabin, the turn, three seconds back towards the nest: a long
	# path, and nowhere net. Turned for home, an animal is watched afresh.
	var main = await _level()
	var at: Vector3 = _clear_ground(main)
	var d = _raider(main, at)
	var seconds: float = float(_tw()["mill_window"])
	var pace: float = float(_tw()["mill_path"]) / seconds * 1.5
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var frames: int = _frames_for(seconds)
	var x: float = 0.0
	for i in frames:
		await wait_physics_frames(1)
		if i == frames / 2:
			d.going_home = true
		x += pace * dt * (1.0 if i < frames / 2 else -1.0)
		d.global_position = at + Vector3(x, 0.0, 0.0)
	assert_eq(_reports_on(d, "mill").size(), 0, "Out and back again, turned for home, is not milling")

func test_13_one_turn_and_back_after_a_long_stand_is_not_fidget() -> void:
	var main = await _level()
	var d = _raider(main, _clear_ground(main))
	var swing: float = deg_to_rad(float(_tw()["swing_min_deg"]) * 2.0)
	for i in _frames_for(float(_tw()["fidget_window"]) + 1.0):
		await wait_physics_frames(1)
		if i < 6:
			d.rotation.y += swing / 6.0
		elif i >= 180 and i < 186:
			d.rotation.y -= swing / 6.0
	assert_eq(_reports_on(d).size(), 0, "A turn, a long stand and a turn back is a raptor looking about")
