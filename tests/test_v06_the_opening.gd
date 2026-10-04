# res://tests/test_v06_the_opening.gd
# v0.6 feedback on the opening: "初始木栅栏强度很低，需要把迅猛龙强度稍微调低，船舱血量提升到100，
# 这样船舱的攻击能打败初始迅猛龙" and "除了木栅栏需要再想一个初始的防御建筑".
#
# The cabin stands a hundred hits -- and since 2026-10-02 shoots nothing ("家里不需要任何防御就能顶住，
# cabin的自动射击得取消了，太厉害"): left alone, the first raid brings it down before dusk, and he can
# save it -- and the opening has a second defence made of wood: a bow tower, and the wooden arrows
# the workbench makes for it of wood, weaker than the bone-tipped ones that come with the raids' bone.
# It shoots only what he has loaded it with (the 2026-10-02 rebuild of the defences: "现在已经有的小机关
# 其实也是自动化的……它就自己能自己重新trigger了，似乎有点自欺欺人了"). The trip bow it replaces, a trap
# that re-armed itself, went with the traps; before that the opening's was a bow tower that aimed by
# itself, until v0.6 round two ("Bow tower作为初始防御太过于强大……防御装置自动可以攻击需要合理解释").
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

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
	clear_drops()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _row(type_id: String) -> Dictionary:
	return config_node.BUILDINGS[type_id]

func _ammo(ammo_id: String) -> Dictionary:
	return config_node.AMMO[ammo_id]

## Damage a second to one animal from the bow tower shooting `ammo_id`, as fast as it lets an arrow go.
func _dps(ammo_id: String) -> float:
	return float(_ammo(ammo_id)["damage"]) / float(_row("bow_tower")["fire_seconds"])

# ==============================================================================
# 1. The cabin
# ==============================================================================

func test_01_the_cabin_shoots_nothing() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var cabin = main.current_core
	assert_almost_eq(float(cabin.max_hp), core_hp(), 0.001, "The cabin stands as many hits as Config says")
	assert_false("attack_range" in cabin, "It has no gun")
	assert_eq(String(cabin._panel_status()), "", "and its card gives no rate of fire")
	var raptor = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(raptor)
	main.add_child(raptor)
	raptor.setup("raptor")
	raptor.set_physics_process(false)
	raptor.global_position = cabin.global_position + Vector3(config_node.get_building_half("core").x + 1.5, 0.0, 0.0)
	await wait_physics_frames(2)
	await wait_seconds(2.0)
	assert_almost_eq(float(raptor.current_hp), raptor_stat("hp"), 0.001, "A raptor that comes up to it is not shot")

func test_02_left_alone_the_first_raid_brings_it_down_before_dusk_and_he_can_save_it() -> void:
	# Every raptor of the first raid biting it, nothing in their way: the cabin is down before the day
	# is -- a raid is not sat out inside (the player, 2026-10-02: "家里不需要任何防御就能顶住").
	var first: int = int(config_node.WAVES["base_count"])
	var falls_in: float = core_hp() / (float(first) * raptor_stat("damage") * raptor_stat("attack_rate"))
	var parts: Dictionary = config_node.DAY["parts"]
	var daylight: float = float(parts["dusk"]) - float(config_node.DAY["start"]) - float(config_node.map_data()["beats"]["first_raid"])
	assert_lt(falls_in, daylight, "Left alone, the first raid brings the cabin down before dusk takes it home")
	# He, at it, kills them one by one long before that.
	var hits_each: float = ceil(raptor_stat("hp") / float(config_node.HERO["damage"]))
	var he_takes: float = float(first) * hits_each * float(config_node.HERO["attack_rate"])
	assert_lt(he_takes * 2.0, falls_in, "He has time to come out and kill them all, twice over")

# ==============================================================================
# 2. The bow tower
# ==============================================================================

func test_03_the_opening_has_a_tower_made_of_wood_and_arrows_of_wood_for_it() -> void:
	assert_has(config_node.BUILDABLE_TYPES, "bow_tower", "The bow tower is on the build menu")
	var cost: Dictionary = _row("bow_tower")["cost"]
	assert_eq(cost.keys(), ["wood"], "Wood and nothing else: it can be built from the first minute")
	assert_eq(String(config_node.get_building_kind("bow_tower")), "bow", "A bow tower: it shoots what comes within its reach")
	assert_gt(float(_row("bow_tower")["range"]), 0.0, "all round it")
	assert_false(_row("bow_tower").has("faces"), "no way to face it when it is set down: it turns to what it shoots")
	# It shoots only what it is loaded with: the arrows, made at the workbench.
	assert_has(config_node.ammo_accepts("bow_tower"), "arrow_wood", "It shoots wooden arrows")
	var arrows: Dictionary = config_node.RECIPES["arrow_wood"]
	assert_eq(String(arrows["station"]), "workbench", "made at the workbench")
	assert_eq(arrows["inputs"].keys(), ["wood"], "of wood alone")
	assert_lte(total_price_of("bow_tower") + int(arrows["inputs"]["wood"]), opening_wood(),
		"The opening's wood pays for one and a batch of its arrows")

func test_04_a_wooden_arrow_does_less_than_a_bone_tipped_one_and_more_than_a_stake() -> void:
	assert_has(config_node.ammo_accepts("bow_tower"), "arrow_bone", "The same tower takes bone-tipped arrows")
	assert_true(config_node.RECIPES["arrow_bone"]["inputs"].has("bone"), "which come with the raids' bone")
	assert_lt(_dps("arrow_wood"), _dps("arrow_bone"), "Less to one animal than the bone-tipped arrows it gives way to")
	assert_lte(int(_ammo("arrow_wood").get("pierce", 1)), 1, "And one animal an arrow,")
	assert_gt(int(_ammo("arrow_bone").get("pierce", 1)), 1, "where a bone point goes on through those behind it")
	# What holds it back is its arrows -- it shoots no more than he has loaded it with -- not how hard they hit:
	# one wooden arrow kills one of the first raids' animals (Config.AMMO.arrow_wood).
	for species in config_node.map_data()["raiders"]:
		assert_gte(float(_ammo("arrow_wood")["damage"]), float(config_node.DINOS[species]["hp"]),
			"One wooden arrow kills a %s of the first raids" % species)
	assert_gt(_dps("arrow_wood"), config_node.get_contact_dps("wall"), "But it does more than a stake's spikes")
	assert_gt(total_price_of("bow_tower"), total_price_of("wall"), "And costs more than a stake")

func test_05_eight_bows_round_it_and_an_arrow_on_each() -> void:
	var body: Node3D = VisualLibrary.make("building/bow_tower")
	_cleanup_nodes.append(body)
	assert_true(VisualLibrary.has_art("building/bow_tower"), "It is a model")
	for i in 8:
		assert_not_null(body.find_child("Bow%d" % i, true, false), "With a bow to each point of the compass (Bow%d)" % i)
		assert_not_null(body.find_child("Arrow%d" % i, true, false), "and an arrow on it (BowTower.gd hides it as it shoots)")
	assert_not_null(body.find_child("Quiver", true, false), "And its spare arrows by them, shown while it has any")
