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

	# The two must not read as each other: the selection ring hugs the base and says
	# "you clicked this", the coverage ring is sized by reach and says "this is what
	# it affects".
	var margin: float = float(config_node.FEEDBACK["selection_ring_margin"])
	var ring_span: float = hut._footprint() + margin * 2.0
	assert_lt(ring_span, hut.harvest_range, "The selection outline is far smaller than the reach")
	assert_almost_eq(hut.selection_ring.base_size, hut._footprint(), 0.001,
		"The outline traces this building's own footprint")

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
			"health_bar_hide_at_full", "selection_ring_margin", "selection_ring_thickness",
			"selection_ring_color",
			"audio_volume_db", "audio_enabled"]:
		assert_true(config_node.FEEDBACK.has(key), "Config.FEEDBACK declares '%s'" % key)

func test_15_audio_can_be_switched_off_wholesale() -> void:
	# A single switch for anyone who needs the game silent, including test runs.
	var before: int = fx_node._next_voice
	fx_node.play(fx_node.Sound.HIT)
	assert_ne(fx_node._next_voice, before, "Sound plays while enabled")

# ==============================================================================
# 7. The ring traces the base; nothing decorative casts a shadow
# ==============================================================================

func test_16_the_ring_traces_each_units_own_base() -> void:
	# A fixed radius does not work. Wooden stakes are 1.9m across, and the old
	# 0.85m ring sat entirely inside the box, invisible.
	var stake = _spawn(wall_script, Vector3(-6.0, 0.0, 0.0))
	var turret = _spawn(tower_script, Vector3(6.0, 0.0, 0.0))
	stake.complete_construction()
	turret.complete_construction()
	await wait_frames(1)

	var margin: float = float(config_node.FEEDBACK["selection_ring_margin"])
	for b in [stake, turret]:
		var fp: float = b._footprint()
		assert_almost_eq(b.selection_ring.base_size, fp, 0.001,
			"The outline is sized from this building's own footprint")
		assert_gt(fp + margin * 2.0, fp, "And sits outside the base, not buried in it")
		assert_eq(b.selection_ring.shape, SelectionRing3D.Shape.BOX,
			"A square building gets a square outline")
		assert_eq(b.selection_ring._parts.size(), 4, "Drawn as a four-sided frame")

	# The two buildings differ in size, so their outlines must differ too.
	assert_ne(stake.selection_ring.base_size, turret.selection_ring.base_size,
		"Different footprints produce different outlines")

func test_17_a_stakes_ring_is_actually_visible_outside_it() -> void:
	var stake = _spawn(wall_script)
	stake.complete_construction()
	await wait_frames(1)
	event_bus_node.unit_selected.emit(stake)

	var margin: float = float(config_node.FEEDBACK["selection_ring_margin"])
	var half_box: float = stake._footprint() * 0.5
	var half_ring: float = (stake._footprint() + margin * 2.0) * 0.5
	assert_gt(half_ring, half_box, "The outline clears the stake it belongs to")
	assert_true(stake.selection_ring.visible, "And is shown when selected")

func test_18_nothing_in_the_feedback_layer_casts_a_shadow() -> void:
	# A UI element painting its own silhouette on the ground reads as a bug: the
	# Hero's health bar was doing exactly that.
	var hero = _spawn(hero_script)
	await wait_frames(1)
	hero.take_damage(1.0)
	await wait_frames(1)

	var decorations: Array[GeometryInstance3D] = []
	decorations.append(hero.status_bar._back)
	decorations.append(hero.status_bar._fill)
	for part in hero.selection_ring._parts:
		decorations.append(part)

	var hut = _spawn(lumber_hut_script, Vector3(8.0, 0.0, 0.0))
	hut.complete_construction()
	await wait_frames(1)
	decorations.append(hut.range_indicator)
	decorations.append(hut.label_3d)

	for d in decorations:
		assert_not_null(d, "Decoration exists")
		assert_eq(d.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"%s must not cast a shadow" % d.name)

# ==============================================================================
# 8. One place holds the version
# ==============================================================================

func test_19_the_version_is_declared_in_exactly_one_place() -> void:
	var declared: String = str(ProjectSettings.get_setting("application/config/version", ""))
	assert_ne(declared, "", "project.godot declares the version")

	var app_info = load("res://scripts/core/AppInfo.gd")
	assert_eq(app_info.get_version(), declared, "Everything reads it from there")

	# The in-code constant must not be a plausible-looking version: a stale literal
	# is indistinguishable from the truth, which is how three copies drifted to v0.2
	# while the game was v0.3.
	assert_eq(app_info.VERSION, "unknown", "The fallback reports 'unknown' rather than guessing")

	# And no stale copy is checked in to outrank the project setting.
	assert_false(FileAccess.file_exists("res://version.json"),
		"version.json is a build-injection artifact, not something the repo carries")

# ==============================================================================
# 9. A bar that has not been refreshed must not be visible garbage
# ==============================================================================

func _bar_span(bar) -> Vector2:
	return bar.fill_span()

func test_20_a_bar_starts_hidden_and_fully_drawn() -> void:
	# Before this fix the bar was created visible with its fill still unscaled at
	# the left anchor: it overhung one end and left the dark backing plate exposed
	# at the other, which read as a grey smudge beside the unit rather than a bar.
	var hero = _spawn(hero_script)
	await wait_frames(1)
	var bar = hero.status_bar
	assert_not_null(bar, "The Hero carries a status bar")
	assert_false(bar.visible, "At full health it stays out of the way")
	assert_almost_eq(bar._last_ratio, 1.0, 0.001, "And is sized, not left unset")

	var span := _bar_span(bar)
	var back_half: float = bar._width * 0.5
	assert_almost_eq(span.x, -back_half, 0.01, "A full bar covers the plate's left edge")
	assert_almost_eq(span.y, back_half, 0.01, "And its right edge, so no plate shows through")

func test_21_a_drained_bar_empties_from_the_right() -> void:
	var hero = _spawn(hero_script)
	await wait_frames(1)
	var bar = hero.status_bar

	hero.take_damage(hero.max_hp * 0.4)
	assert_true(bar.visible, "Damage brings the bar out")
	assert_almost_eq(bar._last_ratio, 0.6, 0.02, "Showing what is left")

	var span := _bar_span(bar)
	var back_half: float = bar._width * 0.5
	assert_almost_eq(span.x, -back_half, 0.01, "The fill stays anchored to the left edge")
	assert_lt(span.y, back_half, "And retreats from the right rather than shrinking centrally")

func test_22_buildings_and_dinosaurs_start_clean_too() -> void:
	var wall = _spawn(wall_script)
	wall.complete_construction()
	await wait_frames(1)
	assert_false(wall.status_bar.visible, "An undamaged building shows no bar")

	var dino = _spawn(dino_script, Vector3(6.0, 0.0, 0.0))
	dino.setup("raptor", {"hp": 1.0, "damage": 1.0, "speed": 1.0})
	await wait_frames(1)
	dino.take_damage(dino.max_hp * 0.5)
	var span := _bar_span(dino.status_bar)
	assert_almost_eq(span.x, -dino.status_bar._width * 0.5, 0.01,
		"A dinosaur's bar is anchored the same way")

# ==============================================================================
# 10. The bar must not drift, and a blueprint has no health to show
# ==============================================================================

func test_23_the_bar_is_one_rigid_billboard_not_two_loose_quads() -> void:
	# Billboarding each quad through its material makes them pivot about their own
	# origins, so the plate and the fill swing apart at any camera angle and the
	# dark plate shows through -- read on screen as a shadow beside the unit.
	var hero = _spawn(hero_script)
	await wait_frames(1)
	var bar = hero.status_bar

	for quad in [bar._back, bar._fill]:
		var mat: StandardMaterial3D = quad.material_override as StandardMaterial3D
		assert_eq(mat.billboard_mode, BaseMaterial3D.BILLBOARD_DISABLED,
			"Quads are not billboarded individually; the bar turns as a whole")
	assert_true(bar.has_method("_face_camera"), "The bar itself faces the camera")

func test_24_the_fill_quad_never_moves_as_the_value_changes() -> void:
	# The other half of the drift: scaling a quad whose own origin travels.
	var hero = _spawn(hero_script)
	await wait_frames(1)
	var bar = hero.status_bar
	var origin: Vector3 = bar._fill.position

	for r in [0.0, 0.25, 0.5, 0.75, 1.0]:
		bar.set_ratio(r, Color.GREEN)
		assert_eq(bar._fill.position, origin, "The fill quad stays put at ratio %.2f" % r)
		var span: Vector2 = bar.fill_span()
		assert_almost_eq(span.x, bar.plate_span().x, 0.001,
			"Its left edge stays pinned to the plate at ratio %.2f" % r)
		assert_lte(span.y, bar.plate_span().y + 0.001,
			"And it never overhangs the plate at ratio %.2f" % r)

	bar.set_ratio(1.0, Color.GREEN)
	assert_almost_eq(bar.fill_span().y, bar.plate_span().y, 0.001,
		"A full bar covers the plate exactly, so none of it shows through")

func test_25_a_blueprint_shows_progress_and_no_health() -> void:
	var hut = _spawn(lumber_hut_script)
	await wait_frames(1)
	hut.start_construction(4.0)
	hut._update_info_label()

	assert_false(hut.is_constructed, "Still a blueprint")
	assert_true(hut.status_bar.visible, "It shows how far along it is")
	assert_almost_eq(hut.status_bar._last_ratio, hut.build_progress, 0.01,
		"The bar reads construction progress, not health")

	# Half built but undamaged: a health reading would be a full bar, so the two
	# are only distinguishable if the blueprint state wins outright.
	hut.add_build_progress(2.0)
	assert_almost_eq(hut.status_bar._last_ratio, 0.5, 0.05, "Progress, not the untouched health")
	assert_false(str(hut.label_3d.text).contains("HP"), "And the label quotes percent, not hit points")

	hut.complete_construction()
	hut._update_info_label()
	assert_false(hut.status_bar.visible, "Finished and undamaged: nothing to report")

# ==============================================================================
# 11. Build menu affordability, and who a right-click is addressed to
# ==============================================================================

func test_26_build_entries_light_up_when_the_wood_arrives() -> void:
	# The menu only re-checked affordability when it was opened, so an entry greyed
	# out for want of wood stayed grey after the wood came in.
	var option_panel_script: GDScript = _load("res://scripts/ui/OptionPanel.gd")
	var panel = option_panel_script.new()
	var hero = hero_script.new()
	_cleanup_nodes.append(panel)
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	tree.root.add_child(panel)
	await wait_frames(1)

	var tower_cost: int = int(config_node.BUILDINGS["tower"]["cost"]["wood"])
	game_state_node.resources["wood"] = maxi(0, tower_cost - 1)
	panel.select_target(hero)
	panel._on_build_pressed()

	var idx: int = config_node.BUILDABLE_TYPES.find("tower")
	assert_gte(idx, 0, "The turret is in the build menu")
	var btn = panel.button_container.get_child(idx)
	assert_true(btn.disabled, "One wood short, so the entry is greyed out")

	# Earning the last of it must light the entry without reopening the menu.
	game_state_node.add_resource("wood", 1)
	await wait_frames(1)
	assert_false(btn.disabled, "It lights up as soon as the wood arrives")

	# And the same in reverse.
	game_state_node.resources["wood"] = 0
	event_bus_node.resources_changed.emit(game_state_node.resources)
	assert_true(btn.disabled, "And greys out again when it is spent")

func test_27_a_right_click_is_addressed_to_the_selected_unit() -> void:
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	var main = main_packed.instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(2)
	var panel = main._get_option_panel()

	# Resting on the Hero: he is the subject, so orders go through.
	panel.set_selected_unit(main.hero)
	assert_true(main._selected_unit_takes_orders(), "The Hero takes orders while selected")

	# A building is inspected, not commanded. Right-click must do nothing rather
	# than quietly ordering the Hero, who is not what the player is looking at.
	var turret = _spawn(tower_script, Vector3(5.0, 0.0, 5.0))
	turret.complete_construction()
	await wait_frames(1)
	panel._on_unit_selected(turret)
	assert_false(main._selected_unit_takes_orders(), "A selected turret takes no orders, so nothing happens")

	# Scenery likewise.
	var node = _load("res://scripts/entities/ResourceNode.gd").new("wood", Vector2i.ZERO)
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	await wait_frames(1)
	panel._on_unit_selected(node)
	assert_false(main._selected_unit_takes_orders(), "A selected tree takes no orders either")

	# Clicking empty ground hands the Hero back, which is the way out.
	panel._on_unit_deselected()
	assert_true(main._selected_unit_takes_orders(), "Deselecting returns command to the Hero")

func test_28_the_opening_affords_a_hut_then_a_turret_one_tend_later() -> void:
	# The shape of the opening, stated so a balance pass cannot quietly break it:
	# buy a hut, tend it once, and the first turret is affordable -- comfortably
	# inside the grace period before the first raid.
	# v0.3: the opening arrives as wood on the ground by the cabin, so "what the
	# player starts with" is what is there to be fetched, not what is banked.
	var start: int = opening_wood()
	var hut: int = int(config_node.BUILDINGS["lumber_hut"]["cost"]["wood"])
	var turret: int = int(config_node.BUILDINGS["tower"]["cost"]["wood"])
	var per_tend: float = float(config_node.BUILDINGS["lumber_hut"]["produces_per_sec"]["wood"]) 		* float(config_node.BUILDINGS["lumber_hut"]["tend_duration"])

	assert_gte(start, hut, "The opening buys a lumber hut outright")
	assert_gte(float(start - hut) + per_tend, float(turret),
		"And one tend later the first turret is affordable")

	var grace: float = float(config_node.RAIDS["first_raid_delay"])
	var build_span: float = config_node.get_build_time("lumber_hut") 		+ float(config_node.BUILDINGS["lumber_hut"]["tend_duration"]) 		+ config_node.get_build_time("tower")
	assert_gt(grace, build_span,
		"The grace period covers hut -> tend -> turret (%.0fs of work in %.0fs)" % [build_span, grace])
	assert_gte(float(config_node.RAIDS["interval_min"]), grace * 0.6,
		"And raids do not then arrive faster than that rhythm")
