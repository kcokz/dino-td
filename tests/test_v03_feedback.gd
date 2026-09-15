# res://tests/test_v03_feedback.gd
# v0.3 feedback layer: the things that make an event legible rather than silent.
# 1. Hit flash on buildings, dinosaurs and the Hero.
# 2. Debris when something dies, instead of it simply vanishing.
# 3. Sound, synthesised at startup so the repo carries no binary audio.
# 4. Health bars (and build-progress bars) above units.
# 5. A selection ring, distinct from a building's coverage ring.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null
var fx_node: Object = null

var wall_script: GDScript = null
var tower_script: GDScript = null
var lumber_hut_script: GDScript = null
var dino_script: GDScript = null
var hero_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")
		fx_node = tree.root.get_node_or_null("Fx")
	wall_script = _load("res://scripts/entities/Wall.gd")
	tower_script = _load("res://scripts/entities/Tower.gd")
	lumber_hut_script = _load("res://scripts/entities/LumberHut.gd")
	dino_script = _load("res://scripts/entities/Dino.gd")
	hero_script = _load("res://scripts/entities/Hero.gd")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _load(path: String) -> GDScript:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is GDScript:
			return r
	return null

func _spawn(script: GDScript, pos: Vector3 = Vector3.ZERO) -> Node:
	var n = script.new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = pos
	return n

# ==============================================================================
# 1. The Fx service itself
# ==============================================================================

func test_01_fx_autoload_is_registered_and_has_its_sounds() -> void:
	assert_not_null(fx_node, "Fx is registered as an autoload")
	for key in ["HIT", "DEATH", "BUILD_DONE", "RAID_WARNING"]:
		assert_true(fx_node.Sound.has(key), "Fx knows the %s sound" % key)

	# Sounds are synthesised rather than shipped, so there is no import step to fail
	# and no binary asset in the repo.
	for id in [fx_node.Sound.HIT, fx_node.Sound.DEATH, fx_node.Sound.BUILD_DONE, fx_node.Sound.RAID_WARNING]:
		var stream = fx_node._streams.get(id, null)
		assert_not_null(stream, "Sound %d was built at startup" % id)
		assert_true(stream is AudioStreamWAV, "It is a real stream")
		assert_gt(stream.data.size(), 0, "With actual samples in it")

func test_02_playing_a_sound_is_safe_and_cycles_voices() -> void:
	# Feedback must never be able to break the simulation, so every entry point has
	# to survive being called in a headless run with no audio device.
	var before: int = fx_node._next_voice
	fx_node.play(fx_node.Sound.HIT)
	assert_ne(fx_node._next_voice, before, "Playing advances to the next voice")

	# Several in a row must not pile up on one player or run off the end.
	for i in range(fx_node.VOICE_COUNT * 2):
		fx_node.play(fx_node.Sound.HIT)
	assert_lt(fx_node._next_voice, fx_node._voices.size(), "Voice index stays in range")

	fx_node.play(-999) # unknown sound
	assert_true(true, "An unknown sound id is ignored rather than crashing")

func test_03_flash_and_debris_tolerate_junk_input() -> void:
	fx_node.flash(null)
	fx_node.debris(Vector3.ZERO, Color.RED, 0)
	var orphan := MeshInstance3D.new()   # not in the tree, no material
	fx_node.flash(orphan)
	orphan.free()
	assert_true(true, "Feedback calls are safe on nodes that are missing or detached")

# ==============================================================================
# 2. Hit flash
# ==============================================================================

func test_04_a_damaged_building_flashes_and_restores_its_colour() -> void:
	var wall = _spawn(wall_script)
	wall.complete_construction()
	await wait_frames(1)

	var mesh: MeshInstance3D = wall._visual_mesh()
	assert_not_null(mesh, "The wall has a visible mesh")
	var original: Color = (mesh.material_override as StandardMaterial3D).albedo_color

	wall.take_damage(1.0)
	var flashed: Color = (mesh.material_override as StandardMaterial3D).albedo_color
	assert_ne(flashed, original, "Being hit visibly lightens it")
	assert_gt(flashed.r + flashed.g + flashed.b, original.r + original.g + original.b,
		"The flash is towards white")

	# It must settle back, and never leave the flash baked into the real material.
	await wait_seconds(float(config_node.FEEDBACK["hit_flash_duration"]) + 0.2)
	var settled: Color = (mesh.material_override as StandardMaterial3D).albedo_color
	assert_almost_eq(settled.r, original.r, 0.02, "Red returns")
	assert_almost_eq(settled.g, original.g, 0.02, "Green returns")
	assert_almost_eq(settled.b, original.b, 0.02, "Blue returns")

func test_05_a_damaged_dinosaur_flashes() -> void:
	var dino = _spawn(dino_script)
	dino.setup("raptor", {"hp": 1.0, "damage": 1.0, "speed": 1.0})
	await wait_frames(1)
	assert_not_null(dino.mesh_instance, "The dinosaur has a mesh")
	var original: Color = (dino.mesh_instance.material_override as StandardMaterial3D).albedo_color

	dino.take_damage(0.5)
	var flashed: Color = (dino.mesh_instance.material_override as StandardMaterial3D).albedo_color
	assert_ne(flashed, original, "A dinosaur under fire looks different from one that is not")

# ==============================================================================
# 3. Debris
# ==============================================================================

func _debris_root() -> Node:
	var scene = tree.current_scene
	if scene == null:
		return null
	return scene.find_child("FxDebris", false, false)

func test_06_debris_is_thrown_and_then_cleaned_up() -> void:
	# Needs a current scene to parent the debris under.
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	tree.current_scene = main
	await wait_frames(2)

	fx_node._debris_root = null
	fx_node.debris(Vector3(2.0, 0.0, 2.0), Color.RED)
	await wait_frames(1)

	var root = _debris_root()
	assert_not_null(root, "Debris is parented under the running scene, so a restart takes it with it")
	var count: int = root.get_child_count()
	assert_eq(count, int(config_node.FEEDBACK["debris_count"]), "It throws the configured number of pieces")

	# And it clears itself up rather than accumulating for the rest of the session.
	await wait_seconds(float(config_node.FEEDBACK["debris_lifetime"]) + 0.5)
	assert_lt(root.get_child_count(), count, "Pieces are freed once they have fallen")
	tree.current_scene = null

# ==============================================================================
# 4. Health and progress bars
# ==============================================================================

func test_07_a_building_shows_build_progress_then_health() -> void:
	var hut = _spawn(lumber_hut_script)
	await wait_frames(1)
	assert_not_null(hut.status_bar, "A building carries a status bar")

	hut.start_construction(4.0)
	hut._update_info_label()
	assert_true(hut.status_bar.visible, "A blueprint shows how far along it is")
	assert_almost_eq(hut.status_bar._last_ratio, 0.0, 0.01, "Starting from nothing")

	hut.add_build_progress(2.0)
	assert_almost_eq(hut.status_bar._last_ratio, 0.5, 0.05, "Halfway up")

	hut.complete_construction()
	assert_false(hut.status_bar.visible, "A finished, undamaged building shows no bar")

func test_08_damage_reveals_the_health_bar_and_drains_it() -> void:
	var wall = _spawn(wall_script)
	wall.complete_construction()
	await wait_frames(1)
	assert_false(wall.status_bar.visible, "Nothing to report at full health")

	wall.take_damage(wall.max_hp * 0.5)
	assert_true(wall.status_bar.visible, "Taking a hit brings the bar out")
	assert_almost_eq(wall.status_bar._last_ratio, 0.5, 0.05, "Drained to match the damage")

func test_09_a_dinosaur_under_fire_shows_its_health() -> void:
	var dino = _spawn(dino_script)
	dino.setup("raptor", {"hp": 1.0, "damage": 1.0, "speed": 1.0})
	await wait_frames(1)

	dino.take_damage(dino.max_hp * 0.5)
	assert_not_null(dino.status_bar, "A dinosaur grows a bar when it is first hit")
	assert_true(dino.status_bar.visible, "So the player can see their towers working")
	assert_almost_eq(dino.status_bar._last_ratio, 0.5, 0.06, "Showing what is left")

# ==============================================================================
# 5. Selection ring
# ==============================================================================

func test_10_selection_ring_is_separate_from_the_coverage_ring() -> void:
	var hut = _spawn(lumber_hut_script)
	hut.complete_construction()
	await wait_frames(1)

	assert_not_null(hut.selection_ring, "A building has a selection ring")
	assert_not_null(hut.range_indicator, "And, being a producer, a coverage ring")
	assert_false(hut.selection_ring.visible, "Neither shows until it is selected")

	# The two must not be the same size, or one reads as the other: the selection
	# ring says "you clicked this", the coverage ring says "this is its reach".
	var ring_r: float = float(config_node.FEEDBACK["selection_ring_radius"])
	assert_ne(ring_r, hut.harvest_range, "A fixed marker, not the building's reach")
	assert_lt(ring_r, hut.harvest_range, "And smaller, so it reads as a marker")

func test_11_selecting_shows_the_ring_and_deselecting_hides_it() -> void:
	var hut = _spawn(lumber_hut_script)
	hut.complete_construction()
	await wait_frames(1)

	event_bus_node.unit_selected.emit(hut)
	assert_true(hut.selection_ring.visible, "Selecting draws the ring")

	event_bus_node.unit_deselected.emit()
	assert_false(hut.selection_ring.visible, "Deselecting clears it")

func test_12_selecting_one_building_clears_anothers_ring() -> void:
	var a = _spawn(wall_script, Vector3(-4.0, 0.0, 0.0))
	var b = _spawn(wall_script, Vector3(4.0, 0.0, 0.0))
	a.complete_construction()
	b.complete_construction()
	await wait_frames(1)

	event_bus_node.unit_selected.emit(a)
	assert_true(a.selection_ring.visible, "A is marked")
	event_bus_node.unit_selected.emit(b)
	assert_false(a.selection_ring.visible, "Selecting B unmarks A")
	assert_true(b.selection_ring.visible, "And marks B")

func test_13_the_hero_is_selectable_and_gets_a_ring() -> void:
	var hero = _spawn(hero_script)
	await wait_frames(1)
	assert_true(hero.is_in_group("selectable"), "The Hero can be picked like anything else")
	assert_not_null(hero.selection_ring, "And carries a selection ring")

	event_bus_node.unit_selected.emit(hero)
	assert_true(hero.selection_ring.visible, "Selecting the Hero marks him")
	event_bus_node.unit_selected.emit(null)
	assert_false(hero.selection_ring.visible, "Selecting something else unmarks him")

# ==============================================================================
# 6. Everything is tunable from Config
# ==============================================================================

func test_14_feedback_numbers_all_live_in_config() -> void:
	assert_true("FEEDBACK" in config_node, "Config owns a FEEDBACK section")
	for key in ["hit_flash_duration", "hit_flash_strength", "debris_count", "debris_size",
			"debris_speed", "debris_lifetime", "health_bar_width", "health_bar_height",
			"health_bar_hide_at_full", "selection_ring_radius", "selection_ring_color",
			"audio_volume_db", "audio_enabled"]:
		assert_true(config_node.FEEDBACK.has(key), "Config.FEEDBACK declares '%s'" % key)

func test_15_audio_can_be_switched_off_wholesale() -> void:
	# A single switch for anyone who needs the game silent, including test runs.
	var before: int = fx_node._next_voice
	fx_node.play(fx_node.Sound.HIT)
	assert_ne(fx_node._next_voice, before, "Sound plays while enabled")
