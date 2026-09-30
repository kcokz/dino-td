# res://tests/test_v06_the_sculpted_cast.gd
# The player, 2026-09-30: "恐龙目前模型做的都粗糙，我需要它们更精致", and then "精修恐龙blender形象，每个恐龙都要修". The
# first map's cast is built anew (tools/generate_dinos.py): each on bones of its own, a smooth body lofted from the
# snout to the tail with its muscles on it, its skin -- scales, a dark back, pale belly, each species' marks --
# baked to a colour and a relief image; eyes, teeth and claws of its own, and every clip the game plays.
#
# Everything expected is read from the models and Config.
extends "res://tests/test_base.gd"

## The species the valley's raids and nights are made of -- and the later maps': the feathered raptors, the
## tyrannosaur, the pterosaur.
const CAST := ["coelophysis", "coelophysis_alpha", "hesperosuchus", "phytosaur", "postosuchus",
	"raptor", "raptor_alpha", "big_theropod", "pterosaur"]

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
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

func _art(key: String) -> Node3D:
	var art: Node3D = VisualLibrary.make(key)
	_cleanup_nodes.append(art)
	return art

func _meshes(art: Node) -> Array:
	return art.find_children("*", "MeshInstance3D", true, false)

func test_01_each_wears_its_skin_baked_to_images() -> void:
	# Its skin a colour image and a relief image (tools/dino_skin.py); its eyes a material of their own that
	# reads the colours at their vertices (VISUALS material "skin").
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var meshes: Array = _meshes(art)
		assert_gt(meshes.size(), 0, "%s has its model" % species)
		var skins: int = 0
		var colours: Dictionary = {}
		var dark: int = 0
		for m in meshes:
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
				assert_not_null(mat, "%s's surfaces have their materials" % species)
				if mat == null:
					continue
				if String(mat.resource_name).begins_with("Eye"):
					assert_true(mat.vertex_color_use_as_albedo, "%s's eyes read the colours at their vertices" % species)
					continue
				skins += 1
				assert_not_null(mat.albedo_texture, "%s's skin has its colour image" % species)
				assert_true(mat.normal_enabled and mat.normal_texture != null, "%s's skin has its relief image" % species)
				if mat.albedo_texture == null:
					continue
				var img: Image = mat.albedo_texture.get_image()
				if img.is_compressed():
					img.decompress()
				for y in range(0, img.get_height(), 8):
					for x in range(0, img.get_width(), 8):
						var c: Color = img.get_pixel(x, y)
						# The square's unused corners are black; the skin is not.
						if c.get_luminance() < 0.01:
							continue
						colours[Color(snappedf(c.r, 0.05), snappedf(c.g, 0.05), snappedf(c.b, 0.05))] = true
						if c.get_luminance() < 0.2:
							dark += 1
		assert_gt(skins, 0, "%s has its skin" % species)
		# Painted, not one flat colour: a dark back, pale belly, marks, each scale a shade apart.
		assert_gt(colours.size(), 20, "%s is painted in many shades (%d)" % [species, colours.size()])
		assert_gt(dark, 0, "%s has its dark back and marks" % species)

func test_02_each_has_two_eyes_of_their_own() -> void:
	# The eyes a material of their own ("Eye"), which the night's eye-shine lights (ProwlerDino), in a mesh
	# of their own -- one material reading the same colours as the skin's came out of the exporter white.
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var sides: Array = [0, 0]
		for m in _meshes(art):
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(i)
				if mat == null or not String(mat.resource_name).begins_with("Eye"):
					continue
				var verts: PackedVector3Array = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
				var mid: float = 0.0
				for v in verts:
					mid += v.x
				mid /= maxf(1.0, float(verts.size()))
				for v in verts:
					sides[0 if v.x < mid else 1] += 1
				var cols: PackedColorArray = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
				var pupil: bool = false
				for c in cols:
					if c.get_luminance() < 0.05:
						pupil = true
				assert_true(pupil, "%s's eyes have a pupil" % species)
		assert_gt(sides[0], 20, "%s has a left eye" % species)
		assert_gt(sides[1], 20, "%s has a right eye" % species)

func test_03_every_clip_is_still_there() -> void:
	var wanted: Array = []
	for state in config_node.ANIMATIONS["dino"]:
		var clip: String = String(config_node.ANIMATIONS["dino"][state])
		if clip != "" and not wanted.has(clip) and clip != "sleep":
			wanted.append(clip)
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var players: Array = art.find_children("*", "AnimationPlayer", true, false)
		assert_gt(players.size(), 0, "%s is animated" % species)
		if players.is_empty():
			continue
		var player := players[0] as AnimationPlayer
		for clip in wanted:
			assert_true(player.has_animation(clip), "%s plays %s" % [species, clip])

func test_04_they_are_drawn_round_not_faceted() -> void:
	# The stretched Quaternius animals were a few thousand flat facets; these are smooth, and many times that.
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var verts: int = 0
		for m in _meshes(art):
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				verts += (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		assert_gt(verts, 6000, "%s is drawn in some detail (%d vertices)" % [species, verts])

# ==============================================================================
# Their faces (tools/render_portraits.gd, Config.PORTRAITS "dino")
# ==============================================================================

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func test_05_each_has_a_face() -> void:
	for species in CAST:
		assert_not_null(UiTheme.portrait("dino/" + species), "%s has its portrait, by its head" % species)

func test_06_a_boss_on_the_field_is_shown_by_its_face() -> void:
	var main = await _level()
	var boss = load(String(config_node.get_dino_script_path("postosuchus"))).new()
	_cleanup_nodes.append(boss)
	# On the field, as a boss that arrives is: what hears of it reads where it is (BugReport).
	main.dinos_container.add_child(boss)
	boss.setup("postosuchus")
	boss.set_physics_process(false)
	tree.root.get_node("EventBus").boss_arrived.emit(boss)
	await wait_frames(1)
	assert_eq(main.hud.hint_icon.texture, UiTheme.portrait("dino/postosuchus"), "The line that it is here wears its face")
	assert_gt(main.hud.hint_icon.custom_minimum_size.x, float(UiTheme.icon_size("m")), "(bigger than an icon)")
	main.hud.show_hint("plain", 1.0, "info")
	assert_eq(main.hud.hint_icon.custom_minimum_size.x, float(UiTheme.icon_size("m")), "and a plain line an icon's size again")

func test_07_killed_he_sees_what_killed_him() -> void:
	var main = await _level()
	game_state_node.lost_to = "hero"
	game_state_node.hero_killer = {"type": "phytosaur", "guard": false}
	main.hud._show_game_over("FALLEN", "", false)
	assert_eq(main.hud.result_icon.texture, UiTheme.portrait("dino/phytosaur"), "Its face over the verdict")
	game_state_node.lost_to = "cabin"
	game_state_node.hero_killer = {}
	main.hud._show_game_over("FALLEN", "", false)
	assert_ne(main.hud.result_icon.texture, UiTheme.portrait("dino/phytosaur"), "(the cabin lost: no face)")

func test_09_every_species_is_drawn_from_the_new_cast() -> void:
	# Built by tools/generate_dinos.py, one .gltf a species, its skin read as the "skin" material says -- no
	# Quaternius animal left.
	for kind in config_node.DINOS:
		var entry: Dictionary = config_node.VISUALS.get("dino/" + String(kind), {})
		var scene: String = String(entry.get("scene", ""))
		assert_true(scene.begins_with("res://assets/models/dinos/") and scene.ends_with(".gltf"),
			"The %s is drawn from the new cast (%s)" % [kind, scene])
		assert_eq(String(entry.get("material", "")), "skin", "The %s's eyes read their colours" % kind)
		assert_true(ResourceLoader.exists(scene), "(its model is there: %s)" % scene)

func test_10_the_pterosaur_folds_its_wings() -> void:
	# The wing finger folded up along the arm from the knuckle, moving with the hand it grows from.
	var art: Node3D = _art("dino/pterosaur")
	var skeletons: Array = art.find_children("*", "Skeleton3D", true, false)
	assert_gt(skeletons.size(), 0, "(it has its skeleton)")
	if skeletons.is_empty():
		return
	var sk := skeletons[0] as Skeleton3D
	for side in ["L", "R"]:
		var first: int = sk.find_bone("Wing1." + side)
		assert_gt(first, -1, "A wing finger on its %s" % side)
		if first < 0:
			continue
		assert_eq(sk.get_bone_name(sk.get_bone_parent(first)), "Hand." + side, "growing from its hand (%s)" % side)
		var tip: int = sk.find_bone("Wing4." + side)
		var hand: int = sk.find_bone("Hand." + side)
		# Folded: its tip up over the hand's top (the wrist), not out along the ground.
		assert_gt(sk.get_bone_global_rest(tip).origin.y, sk.get_bone_global_rest(hand).origin.y,
			"folded up along the arm (%s)" % side)

func test_08_what_a_wrecks_din_brought_is_named() -> void:
	# The din says what came, so the line about it wears its face (HUD._on_din_carried).
	var main = await _level()
	var said = watch_signal(tree.root.get_node("EventBus"), "din_carried")
	var wreck: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.get("resource_type")) == "antenna":
			wreck = n
	assert_not_null(wreck, "(the antenna's wreck)")
	if wreck == null:
		return
	var din: Dictionary = config_node.RESOURCE_NODES["antenna"]["din"]
	# At night: by day the phytosaurs lie in the river and the din brings none (v0.6 round six).
	game_state_node.day_clock = float(config_node.DAY["parts"]["night"]) + 10.0
	game_state_node._run_the_day(0.0)
	for i in int(din["at"][0]):
		wreck.harvest(1)
	await wait_frames(2)
	assert_eq(said.emit_count, 1, "(the din carried)")
	if said.emit_count > 0:
		var species: String = String(said.last_args[2]) if said.last_args.size() > 2 else ""
		assert_ne(species, "", "It names what came")
		assert_not_null(UiTheme.portrait("dino/" + species), "and what came has a face (%s)" % species)
