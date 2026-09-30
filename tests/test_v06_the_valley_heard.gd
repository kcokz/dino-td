# res://tests/test_v06_the_valley_heard.gd
# v0.6 round three: "你就做音效吧，恐龙音效不同恐龙尽量不同，这样有区分度，人自己也需要有些滚动的话在移动的
# 时候idle的时候说，做事情说做的事情等".
#
# The valley is heard: every animal of the first map has a voice of its own -- a call now and then,
# an alert as it goes for something, its bite, its hurt, its death, and the boss a roar as it
# comes -- and the voices are told apart by ear (a small theropod high, its leader lower, the
# Postosuchus lowest of all). His work is heard as what it strikes; a building bitten sounds of
# what it is made of; the raid is heard from the nest. And he talks: a line of the moment over
# his head, never the same one twice running, not all the time.
#
# Sound is played in the world (Fx.play_at) and said on Fx.played -- what the tests listen for,
# as a headless run has no audio device. Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var fx_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _heard: Array = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
		fx_node = tree.root.get_node_or_null("Fx")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()
	_heard.clear()
	fx_node._last_in_class.clear()
	# And the valley quiet: calls from the suite before still playing held a class's room ("max"), and a
	# pack's one call here was none.
	for p in fx_node._players:
		(p as AudioStreamPlayer3D).stop()
	if not fx_node.played.is_connected(_on_played):
		fx_node.played.connect(_on_played)

func after_each() -> void:
	if fx_node.played.is_connected(_on_played):
		fx_node.played.disconnect(_on_played)
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _on_played(id: String, at: Vector3) -> void:
	_heard.append([id, at])

func _heard_ids() -> Array:
	var out: Array = []
	for h in _heard:
		out.append(h[0])
	return out

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _animal(species: String, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = at
	return d

## Zero crossings a second of a sound's first file: a plain measure of how high it is.
func _brightness(id: String) -> float:
	var table: Dictionary = config_node.SOUNDS
	var path: String = String(table["dir"]) + String(table["sounds"][id]["files"][0]) + ".wav"
	var f := FileAccess.open(path, FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	var n: int = int((bytes.size() - 44) / 2.0)
	var crossings: int = 0
	var was: bool = true
	for i in n:
		var now: bool = bytes.decode_s16(44 + i * 2) >= 0
		if i > 0 and now != was:
			crossings += 1
		was = now
	return float(crossings) / (float(n) / 22050.0)

# ==============================================================================
# 1. Every animal of the map has a voice, and they are told apart
# ==============================================================================

func test_01_every_animal_of_the_map_has_its_own_voice() -> void:
	var map: Dictionary = config_node.map_data()
	var sounds: Dictionary = config_node.SOUNDS["sounds"]
	var fighters: Array = map["raiders"].keys() + [map["minor_boss"], map["boss"], map["guards"]]
	for species in fighters:
		var d = _animal(String(species), Vector3(30.0, 0.0, 30.0))
		for kind in ["call", "alert", "bite", "hurt", "death"]:
			assert_true(sounds.has(d.voice() + "_" + kind), "%s has a %s" % [species, kind])
	var boss = _animal(String(map["boss"]), Vector3(34.0, 0.0, 30.0))
	assert_true(sounds.has(boss.voice() + "_roar"), "and the map's boss a roar to come in with")
	for herd in config_node.HERDS["herds"]:
		assert_true(sounds.has(String(herd["species"]) + "_call"), "The herds on the valley walls call too")

func test_02_the_voices_are_told_apart_by_ear() -> void:
	var map: Dictionary = config_node.map_data()
	var small: float = _brightness(String(map["raiders"].keys()[0]) + "_call")
	var leader: float = _brightness(String(map["minor_boss"]) + "_call")
	var boss: float = _brightness(String(map["boss"]) + "_call")
	assert_gt(small, leader * 1.3, "The small theropod is well above its leader (%.0f vs %.0f)" % [small, leader])
	assert_gt(leader, boss * 3.0, "and its leader far above the Postosuchus (%.0f vs %.0f)" % [leader, boss])
	var herd: float = _brightness(String(config_node.HERDS["herds"][0]["species"]) + "_call")
	assert_ne(snappedf(herd, 100.0), snappedf(small, 100.0), "The grazers sound like neither")

# ==============================================================================
# 2. They are heard doing what they do
# ==============================================================================

func test_03_an_animal_is_heard_biting_hurt_and_dying_from_where_it_is() -> void:
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var d = _animal(species, Vector3(20.0, 0.0, 12.0))
	d.take_damage(d.max_hp * 0.3)
	assert_true(_heard_ids().has(d.voice() + "_hurt"), "Hurt, it cries out")
	var cry: Vector3 = _heard[_heard.size() - 1][1]
	assert_lt(Vector2(cry.x - 20.0, cry.z - 12.0).length(), 0.01, "from where it stands")
	fx_node._last_in_class.clear()
	assert_true(d.say("bite"), "Its bite is its own")
	fx_node._last_in_class.clear()
	d.take_damage(d.max_hp * 10.0)
	assert_true(_heard_ids().has(d.voice() + "_death"), "and so is its death")

func test_04_the_boss_is_heard_across_the_valley_as_it_comes() -> void:
	var boss = _animal(String(config_node.map_data()["boss"]), Vector3(-20.0, 0.0, -25.0))
	tree.root.get_node("EventBus").boss_arrived.emit(boss)
	assert_true(_heard_ids().has(boss.voice() + "_roar"), "It comes in with its roar")
	var roar: Dictionary = config_node.SOUNDS["sounds"][boss.voice() + "_roar"]
	assert_gt(float(roar.get("reach", 0.0)), 150.0, "heard from the far end of the valley")

func test_05_a_pack_is_not_a_wall_of_noise() -> void:
	var calls: Dictionary = config_node.SOUNDS["classes"]["call"]
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var said: int = 0
	for i in range(int(calls["max"]) + 4):
		var d = _animal(species, Vector3(10.0 + i, 0.0, 10.0))
		if d.say("call"):
			said += 1
	assert_eq(said, 1, "Twelve at once: one call, and the next only after %.2fs" % float(calls["gap"]))

# ==============================================================================
# 3. His work, the buildings, the raid
# ==============================================================================

func test_06_his_work_is_heard_as_what_it_strikes() -> void:
	var main = await _level()
	var hero = main.hero
	var tree_node: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood" and hero.can_harvest(n):
			tree_node = n
			break
	assert_not_null(tree_node, "A tree")
	hero.order_harvest(tree_node)
	for i in range(int(10.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if _heard_ids().has(String(config_node.SOUNDS["harvest"]["wood"])):
			break
	assert_true(_heard_ids().has(String(config_node.SOUNDS["harvest"]["wood"])), "An axe in wood, at the tree")

func test_07_a_building_bitten_sounds_of_what_it_is() -> void:
	var main = await _level()
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + Vector2i(4, 4)
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, false)
	if not wall.is_constructed:
		wall.complete_construction()
	fx_node._last_in_class.clear()
	wall.take_damage(0.5)
	assert_true(_heard_ids().has(String(config_node.SOUNDS["hit_default"])), "A fence bitten: timber")
	fx_node._last_in_class.clear()
	main.current_core.take_damage(0.5)
	assert_true(_heard_ids().has(String(config_node.SOUNDS["hit_by_building"]["core"])), "the cabin: its plate")

func test_08_the_raid_is_heard_from_the_nest() -> void:
	var main = await _level()
	var nest: Node3D = tree.get_first_node_in_group("nest") as Node3D
	assert_not_null(nest, "The nest")
	main.hud._raid_horn_sounded = false
	tree.root.get_node("EventBus").raid_warning.emit(15.0)
	var found: bool = false
	for h in _heard:
		if h[0] == "raid_warning":
			found = true
			assert_lt(Vector2(h[1].x - nest.global_position.x, h[1].z - nest.global_position.z).length(), 0.5,
				"The pack calling, from over by the nest")
	assert_true(found, "The raid's warning is heard")

# ==============================================================================
# 4. He talks
# ==============================================================================

func test_09_every_line_he_has_is_written_in_both_languages() -> void:
	var lines: Dictionary = config_node.BARKS["lines"]
	var zh: Translation = TranslationServer.get_translation_object("zh_CN")
	for situation in lines:
		for i in range(int(lines[situation]["count"])):
			var key: String = "BARK_%s_%d" % [String(situation).to_upper(), i + 1]
			assert_ne(tr(key), key, "%s is written" % key)
			if zh:
				assert_ne(String(zh.get_message(key)), "", "%s is written in Chinese" % key)

func test_10_a_line_goes_over_his_head() -> void:
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	assert_not_null(voice, "He has a voice")
	assert_true(voice.speak("hurt"), "Bitten, he says so")
	await wait_frames(1)
	var bubble: Control = main.hud.speech_bubble
	assert_true(bubble.visible, "over his head")
	var said: String = String(main.hud.speech_label.text)
	var matches: bool = false
	for i in range(int(config_node.BARKS["lines"]["hurt"]["count"])):
		if said == tr("BARK_HURT_%d" % (i + 1)):
			matches = true
	assert_true(matches, "one of his lines about being hurt (%s)" % said)
	var cam: Camera3D = main.get_viewport().get_camera_3d()
	var head: Vector2 = cam.unproject_position(main.hero.global_position + Vector3(0.0, float(config_node.UI["speech_above"]), 0.0))
	var box: Rect2 = bubble.get_global_rect()
	assert_lt(absf(box.get_center().x - head.x), box.size.x * 0.5 + 1.0, "right over him")
	assert_lt(box.end.y, head.y + 1.0, "above his head")

func test_11_not_all_the_time_and_never_the_same_line_twice_running() -> void:
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var eb = tree.root.get_node("EventBus")
	var keys: Array = []
	var ear := func(key: String, _s: float) -> void: keys.append(key)
	eb.hero_spoke.connect(ear)
	assert_true(voice.speak("tool"), "A line")
	assert_false(voice.speak("tool"), "and not straight away another, however many he has")
	var gap: float = float(config_node.BARKS["gap"])
	for i in 12:
		voice._clock += gap + float(config_node.BARKS["lines"]["tool"]["again"]) + 0.1
		voice.speak("tool")
	for i in range(1, keys.size()):
		assert_ne(keys[i], keys[i - 1], "Never the same line twice running")
	assert_gt(keys.size(), 6, "and he does keep talking, given the time (%d)" % keys.size())
	eb.hero_spoke.disconnect(ear)

func test_12_left_standing_he_talks_to_himself() -> void:
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var eb = tree.root.get_node("EventBus")
	var keys: Array = []
	var ear := func(key: String, _s: float) -> void: keys.append(key)
	eb.hero_spoke.connect(ear)
	main.hero.current_state = main.hero.State.IDLE
	var step: float = 0.5
	var waited: float = 0.0
	while waited < float(config_node.BARKS["idle_after"]) + 1.0:
		voice._process(step)
		waited += step
	var idle: bool = false
	for k in keys:
		if String(k).begins_with("BARK_IDLE_"):
			idle = true
	assert_true(idle, "Idle a while, he says something to himself (%s)" % [keys])
	eb.hero_spoke.disconnect(ear)

func test_13_sent_to_a_tree_he_may_say_what_he_is_doing() -> void:
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var eb = tree.root.get_node("EventBus")
	var keys: Array = []
	var ear := func(key: String, _s: float) -> void: keys.append(key)
	eb.hero_spoke.connect(ear)
	# What he is doing picks the situation; whether he speaks is its chance -- here, every time.
	var harvest: Dictionary = config_node.BARKS["harvest"]
	var situation: String = String(harvest["wood"])
	voice._dice.seed = 1
	var tree_node: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood" and main.hero.can_harvest(n):
			tree_node = n
			break
	main.hero.target_resource_node = tree_node
	var spoke: bool = false
	for attempt in 40:
		voice._said_at.clear()
		voice._last_said_at = -1000.0
		voice._state_was = -1
		main.hero.current_state = main.hero.State.HARVESTING
		voice._process(0.01)
		for k in keys:
			if String(k).begins_with("BARK_%s_" % situation.to_upper()):
				spoke = true
		if spoke:
			break
	assert_true(spoke, "At a tree, now and then, a line about the wood")
	eb.hero_spoke.disconnect(ear)

func test_14_what_he_was_after_freed_under_him_is_no_crash() -> void:
	# Found by the full suite: a raptor freed while it was still his target, and the voice read it
	# into a typed variable -- a script error, which in the game is a crash.
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var raptor = _animal(String(config_node.map_data()["raiders"].keys()[0]), main.hero.global_position + Vector3(3.0, 0.0, 0.0))
	main.hero.target_enemy = raptor
	main.hero.current_state = main.hero.State.ATTACKING
	voice._process(0.1)
	raptor.free()
	voice._process(0.1)
	voice._state_was = -1
	main.hero.current_state = main.hero.State.MOVING
	voice._process(0.1)
	assert_true(true, "He goes on, and so does the game")

func test_15_the_bubble_is_as_small_as_its_words() -> void:
	# Found in a screenshot: after a long line, a short one stood in a bubble as tall as the screen.
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var hud = main.hud
	var eb = tree.root.get_node("EventBus")
	eb.hero_spoke.emit("BARK_IDLE_1", 3.0)
	await wait_frames(3)
	eb.hero_spoke.emit("BARK_MOVE_2", 3.0)
	await wait_frames(3)
	var line: float = float(hud.speech_label.get_line_height())
	assert_lt(hud.speech_bubble.size.y, line * 3.0, "A short line in a bubble one line high (%.0f px, a line is %.0f)" % [hud.speech_bubble.size.y, line])
	eb.hero_spoke.emit("BARK_IDLE_1", 3.0)
	await wait_frames(3)
	assert_lte(hud.speech_bubble.size.x, float(config_node.UI["speech_max_width"]) + 80.0, "A long one wraps at the most")
	assert_lt(hud.speech_bubble.size.y, line * 6.0, "into a few lines, not a column")
	assert_true(voice != null, "his voice")

func test_16_the_night_hunter_and_the_runner_have_voices_of_their_own() -> void:
	# Sound polish (the player, 2026-09-30: "你有什么界面和声音的精做就开始吧"): the phytosaur and the
	# Hesperosuchus were Postosuchus's own recordings, pitched up.
	var sounds: Dictionary = config_node.SOUNDS["sounds"]
	for species in ["phytosaur", "hesperosuchus"]:
		for kind in ["call", "alert", "bite", "hurt", "death"]:
			for f in sounds[species + "_" + kind]["files"]:
				assert_true(String(f).begins_with(species), "%s's %s is its own (%s)" % [species, kind, f])
	var runner: float = _brightness("hesperosuchus_call")
	var night: float = _brightness("phytosaur_call")
	var boss: float = _brightness("postosuchus_call")
	assert_gt(runner, night * 3.0, "The little runner barks high, the phytosaur growls low (%.0f vs %.0f)" % [runner, night])
	assert_ne(snappedf(night, 50.0), snappedf(boss, 50.0), "and the phytosaur is not the Postosuchus (%.0f vs %.0f)" % [night, boss])
	# A phytosaur landing is heard where it lands (NightProwl.send_one_from).
	assert_true(sounds.has("river_splash"), "The river is heard broken")
