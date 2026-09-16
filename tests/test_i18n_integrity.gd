# res://tests/test_i18n_integrity.gd
extends "res://tests/test_base.gd"

## Unit & Integration Test Suite for Defend Dinosaur v0.2 i18n & Localization (T8.1 ~ T8.6).

const CSV_PATH: String = "res://translations/strings.csv"

var i18n_node: Node = null

func before_all() -> void:
	if tree != null and tree.root != null:
		i18n_node = tree.root.get_node_or_null("I18n")
	if i18n_node == null and ResourceLoader.exists("res://scripts/autoload/I18n.gd"):
		i18n_node = load("res://scripts/autoload/I18n.gd").new()
		if tree and tree.root:
			tree.root.add_child(i18n_node)

func after_all() -> void:
	# Ensure default locale is restored to 'en'
	if i18n_node and i18n_node.has_method("set_locale"):
		i18n_node.set_locale("en")

func test_01_csv_file_exists_and_parseable() -> void:
	assert_true(FileAccess.file_exists(CSV_PATH), "strings.csv must exist at %s" % CSV_PATH)
	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_not_null(file, "strings.csv must be readable")
	var headers = file.get_csv_line()
	assert_gte(headers.size(), 3, "CSV must have at least 3 columns (id, en, zh_CN)")
	assert_eq(headers[0], "id", "Header col 0 must be 'id'")
	assert_eq(headers[1], "en", "Header col 1 must be 'en'")
	assert_eq(headers[2], "zh_CN", "Header col 2 must be 'zh_CN'")

func test_02_key_set_parity_and_no_empty_values() -> void:
	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_not_null(file, "strings.csv must be openable")
	var headers = file.get_csv_line()
	var row_count = 0

	var required_keys = [
		"BUILDING_CORE_NAME", "BUILDING_TOWER_NAME", "BUILDING_WALL_NAME",
		"DINO_RAPTOR_NAME", "DINO_BIG_THEROPOD_NAME", "DINO_PTEROSAUR_NAME", "DINO_GUARD_NAME",
		"RESOURCE_WOOD", "RESOURCE_STONE", "RESOURCE_WATER", "HERO_NAME", "NEST_NAME",
		"GAME_VICTORY_TITLE", "GAME_DEFEAT_TITLE", "BTN_RESTART",
		"CMD_BUILD", "CMD_STOP", "CMD_HARVEST"
	]

	var discovered_keys: Dictionary = {}

	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 3:
			continue
		var k = row[0].strip_edges()
		if k.is_empty():
			continue
		row_count += 1
		var en_val = row[1].strip_edges()
		var zh_val = row[2].strip_edges()

		assert_ne(en_val, "", "Key '%s' must not have empty 'en' translation" % k)
		assert_ne(zh_val, "", "Key '%s' must not have empty 'zh_CN' translation" % k)
		discovered_keys[k] = true

	assert_gt(row_count, 30, "strings.csv should have at least 30 translation rows (found %d)" % row_count)

	for req in required_keys:
		assert_true(discovered_keys.has(req), "Required key '%s' must be present in strings.csv" % req)

func test_03_default_english_translations() -> void:
	if i18n_node and i18n_node.has_method("set_locale"):
		i18n_node.set_locale("en")

	var tower_name = tr("BUILDING_TOWER_NAME")
	assert_eq(tower_name, "Auto Turret", "In 'en' locale, BUILDING_TOWER_NAME must be 'Auto Turret'")

	var core_name = tr("BUILDING_CORE_NAME")
	assert_eq(core_name, "Abandoned Cabin", "In 'en' locale, BUILDING_CORE_NAME must be 'Abandoned Cabin'")

	var restart_btn = tr("BTN_RESTART")
	assert_eq(restart_btn, "Restart", "In 'en' locale, BTN_RESTART must be 'Restart'")

func test_04_dynamic_locale_switching_to_chinese() -> void:
	assert_not_null(i18n_node, "I18n autoload must exist")
	if i18n_node == null: return

	var locale_watcher = null
	var eb = tree.root.get_node_or_null("EventBus") if tree and tree.root else null
	if eb:
		locale_watcher = watch_signal(eb, "locale_changed")

	# Switch to zh_CN
	i18n_node.set_locale("zh_CN")
	assert_eq(i18n_node.get_locale(), "zh_CN", "I18n.get_locale() must return 'zh_CN'")

	if locale_watcher:
		assert_true(locale_watcher.emitted, "EventBus.locale_changed must be emitted on switch")

	# Verify instant reactive translations in zh_CN
	assert_eq(tr("BUILDING_TOWER_NAME"), "自动哨位", "In 'zh_CN', BUILDING_TOWER_NAME must be '自动哨位'")
	assert_eq(tr("BUILDING_CORE_NAME"), "废弃船舱", "In 'zh_CN', BUILDING_CORE_NAME must be '废弃船舱'")
	assert_eq(tr("BUILDING_WALL_NAME"), "木栅栏", "In 'zh_CN', BUILDING_WALL_NAME must be '木栅栏'")
	assert_eq(tr("DINO_RAPTOR_NAME"), "迅猛龙", "In 'zh_CN', DINO_RAPTOR_NAME must be '迅猛龙'")
	assert_eq(tr("BTN_RESTART"), "重新开始", "In 'zh_CN', BTN_RESTART must be '重新开始'")

	# Switch back to en
	i18n_node.set_locale("en")
	assert_eq(i18n_node.get_locale(), "en", "I18n.get_locale() must return 'en'")
	assert_eq(tr("BUILDING_TOWER_NAME"), "Auto Turret", "Switched back to 'en': Auto Turret")

func test_05_locale_persistence() -> void:
	assert_not_null(i18n_node, "I18n autoload must exist")
	if i18n_node == null: return

	i18n_node.save_saved_locale("zh_CN")
	var loaded = i18n_node.load_saved_locale()
	assert_eq(loaded, "zh_CN", "Saved preference 'zh_CN' correctly loaded from settings")

	i18n_node.save_saved_locale("en")
	var loaded_en = i18n_node.load_saved_locale()
	assert_eq(loaded_en, "en", "Saved preference 'en' correctly loaded from settings")
