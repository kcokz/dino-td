# res://scripts/ui/OptionPanel.gd
class_name OptionPanel
extends PanelContainer

## The command card: bottom right, whatever is selected -- the Hero when nothing else is.
##
## Top to bottom (UI-POLISH T10, T11):
##   * who it is: a portrait (its icon), its name, and what kind of thing it is;
##   * how it is: a health bar, and a second, slanted bar for work under way -- building,
##     upgrading, a job at a bench -- told apart by shape as well as colour. The Hero has three
##     bars of his own instead -- health, build speed, walk speed -- with a meal's boost gold on
##     the end of each, and what he is living on and for how long (v0.6 round two: "人的界面面板上
##     还要有显示血量、建造速度、移动速度，分别都有一个血条……boost 要比较清楚地显示");
##   * what it says: the one line only it can add (a stake's bite, what a rock needs);
##   * what it can do: its commands -- his as icons, Build and Eat -- and on the build page one
##     card per building with its price as icons along the bottom, red where the warehouse falls
##     short and a lock on the card when it cannot be paid -- never colour alone; on the eat page
##     one card per meal cooked, what it does along the bottom.
##
## The panel is as tall as what it holds and grows upward from the corner; it used to be a
## fixed box with its lower half empty. Everything is styled by UiTheme through type
## variations; nothing here picks a colour or a size.
##
## His card stands one of three ways (view) -- v0.6 round four: "surviver面板太大，大部分时间都是要选着
## 这个人到处采到处造，这个面板就一直占着游戏版面……有没有方法既方便建造有不要一直显示着这个面板？". The
## games that keep the screen clear show a hero's commands and bring the rest when it is asked for:
## Diablo IV's character sheet on C; the build menu of Age of Empires IV or StarCraft II, which
## comes up off its button and goes once a building is in hand. His two commands, Build and Eat,
## are tiles of their own in the corner (HeroCommands), there all the while and never moving
## ("最好建造和吃的两个图标不要变动位置，就在右下角原处"); the card stands on them (stand_on):
##   * "none", the rest of the time: no card. His health and his meal are on his medallion at the
##     bottom left (HUD) all the while;
##   * "menu": one of his menus (Build, Eat), come up off its tile -- what it offers and the line
##     about the entry under the cursor, nothing of him. A building taken in hand puts it away;
##   * "full" (details_open -- Config.CONTROLS.details_key, or his medallion): his sheet -- his
##     portrait, his bars, his meal, his kit, what he is doing. No commands: those are below.
## Anything else chosen shows its whole card, above his tiles too.

signal build_option_selected(building_type: String)
signal action_triggered(action_name: String, target_node: Node)
## What it shows has changed (_settle): his commands below take the number keys or give them up
## (HUD, leaves_keys).
signal card_changed()

var selected_unit: Node = null
var current_menu: String = "default" # "default", "build" or "eat"
## Whether his card is open in full (show_details), rather than his commands alone. A new subject,
## or the selection cleared, shuts it.
var details_open: bool = false
## What the card stands on: his commands in the corner (HUD). It is pinned above them while they show.
var below: Control = null
## Put away at the end of the run (HUD.set_shut): nothing is chosen any more.
var shut: bool = false
## How many of the card's commands are on the number keys (_mark_keys).
var _keyed: int = 0

## True while the status line is showing the detail for whatever the cursor is
## over. The per-unit status ticker runs every quarter second and would otherwise
## wipe a hover message almost as soon as it appeared -- which read as the reason
## flashing up and vanishing.
var _hover_detail_shown: bool = false

# UI Nodes
var header: HBoxContainer = null
var portrait: TextureRect = null
var title_label: Label = null
var subtitle_label: Label = null
var hp_row: Control = null
var hp_bar: ProgressBar = null
var hp_text: Label = null
var work_row: Control = null
var work_bar: ProgressBar = null
var work_text: Label = null
var status_label: Label = null
var separator: HSeparator = null
var button_container: GridContainer = null
## The Hero's own block: a StatBar and its figure for each of "hp", "build" and "move", and the
## row that says what meal he is living on.
var hero_stats: VBoxContainer = null
var _stat_rows: Dictionary = {}
var boost_row: HBoxContainer = null
var boost_text: Label = null
var boost_bar: ProgressBar = null
## His abilities, a square each (Config.abilities), and which ones it shows now.
var ability_row: HFlowContainer = null
var _abilities_shown: Array[String] = []
var _last_refresh_time: float = 0.0
var _shown_unit: Node = null
var _shown_view: String = ""

func _init() -> void:
	custom_minimum_size = _panel_size()

func _ready() -> void:
	_ensure_components()
	_connect_event_bus()
	_refresh_ui()

func _exit_tree() -> void:
	_disconnect_event_bus()

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb:
		if eb.has_signal("unit_selected") and not eb.unit_selected.is_connected(_on_unit_selected):
			eb.unit_selected.connect(_on_unit_selected)
		if eb.has_signal("unit_deselected") and not eb.unit_deselected.is_connected(_on_unit_deselected):
			eb.unit_deselected.connect(_on_unit_deselected)
		if eb.has_signal("locale_changed") and not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)
		if eb.has_signal("resources_changed") and not eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.connect(_on_resources_changed)
		if eb.has_signal("material_discovered") and not eb.material_discovered.is_connected(_on_material_discovered):
			eb.material_discovered.connect(_on_material_discovered)
		if eb.has_signal("meals_changed") and not eb.meals_changed.is_connected(_on_meals_changed):
			eb.meals_changed.connect(_on_meals_changed)

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("unit_selected") and eb.unit_selected.is_connected(_on_unit_selected):
			eb.unit_selected.disconnect(_on_unit_selected)
		if eb.has_signal("unit_deselected") and eb.unit_deselected.is_connected(_on_unit_deselected):
			eb.unit_deselected.disconnect(_on_unit_deselected)
		if eb.has_signal("locale_changed") and eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)
		if eb.has_signal("resources_changed") and eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.disconnect(_on_resources_changed)
		if eb.has_signal("material_discovered") and eb.material_discovered.is_connected(_on_material_discovered):
			eb.material_discovered.disconnect(_on_material_discovered)
		if eb.has_signal("meals_changed") and eb.meals_changed.is_connected(_on_meals_changed):
			eb.meals_changed.disconnect(_on_meals_changed)

## Left-click is the only thing that changes what the panel shows. Right-click
## gives the Hero an order and deliberately leaves the panel alone, so inspecting
## and commanding never interfere with each other.
func _on_unit_selected(unit: Node) -> void:
	set_selected_unit(unit)

func _on_unit_deselected() -> void:
	clear_selection()

## A meal cooked or eaten: his commands' count, and the eat page, are made again -- only while
## they are what is shown.
func _on_meals_changed(_meals: Dictionary) -> void:
	if selected_unit != null and selected_unit == _get_hero() and current_menu != "build":
		_refresh_ui()

func _on_locale_changed(_locale: String) -> void:
	_show_abilities(true)
	_refresh_ui()

## The wallet changed, so what the player can afford changed with it. Only the
## enabled state and the prices are touched -- rebuilding the menu here would throw away
## whichever entry the cursor is currently over, and with it the detail line.
func _on_resources_changed(_res: Dictionary) -> void:
	refresh_build_affordability()

## A material has turned up: what is built of it joins the menu, if the menu is open and
## now shows more -- rebuilt only then, so an entry the cursor is on is not thrown away.
func _on_material_discovered(_res_id: String) -> void:
	if current_menu == "build" and _shown_buildables() != _menu_types:
		_refresh_ui()

## What the build menu shows now, in order.
var _menu_types: Array = []

## What the build menu offers: every buildable whose materials the run has turned up
## (GameState.knows_all) -- stakes and the bow tower from the first minute, bone stakes
## once there is bone, and so on. What is still to come is not shown (v0.6).
func _shown_buildables() -> Array:
	var cfg = _get_config()
	var gs = _get_game_state()
	var out: Array = []
	for b_type in (cfg.BUILDABLE_TYPES if (cfg and "BUILDABLE_TYPES" in cfg) else ["wall"]):
		var cost: Dictionary = cfg.BUILDINGS[b_type].get("cost", {}) if cfg else {}
		if gs == null or not gs.has_method("knows_all") or gs.knows_all(cost):
			out.append(b_type)
	return out

func refresh_build_affordability() -> void:
	if current_menu != "build" or button_container == null:
		return
	var cfg = _get_config()
	var buildable: Array = _shown_buildables()
	var children: Array = button_container.get_children()
	for i in range(buildable.size()):
		if i >= children.size():
			break
		var btn = children[i]
		if btn is Button:
			var b_type: String = String(buildable[i])
			btn.disabled = not _can_afford(b_type)
			_fill_price_row(btn, cfg.BUILDINGS[b_type].get("cost", {}))

func set_selected_unit(unit: Node) -> void:
	if unit != selected_unit:
		details_open = false
	selected_unit = unit
	current_menu = "default"
	_hover_detail_shown = false
	_refresh_ui()

func select_target(target: Node) -> void:
	set_selected_unit(target)

func clear_selection() -> void:
	# Fallback to hero if present
	var hero = _get_hero()
	if hero != null and is_instance_valid(hero) and not hero.is_queued_for_deletion():
		selected_unit = hero
	else:
		selected_unit = null
	current_menu = "default"
	details_open = false
	_refresh_ui()

func deselect() -> void:
	selected_unit = null
	current_menu = "default"
	details_open = false
	_refresh_ui()

var selected_target: Node:
	get: return selected_unit
	set(v): selected_unit = v

var current_menu_level: int:
	get: return 2 if current_menu == "build" else 1

func _on_build_pressed() -> void:
	show_menu("build")

func _on_eat_pressed() -> void:
	show_menu("eat")

## He eats the meal `key` (Hero.order_eat), and the card goes back to his commands.
func _trigger_eat(key: String) -> void:
	var hero = _get_hero()
	if hero != null and is_instance_valid(hero) and hero.has_method("order_eat"):
		hero.order_eat(key)
	current_menu = "default"
	_refresh_ui()

## One step back: out of one of his menus, to his card as it stood; else his card in full, shut.
func _on_back_pressed() -> void:
	if current_menu != "default":
		current_menu = "default"
	else:
		details_open = false
	_refresh_ui()

## Whether the card has something the cancel key closes: one of his menus (build, eat), or his sheet.
func in_submenu() -> bool:
	return current_menu != "default" or showing_details()

## How the card stands now: for him, "none" (no card -- his commands are below it), "menu" (one of his
## menus) or "full" (his sheet); anything else's card is always "full".
func view() -> String:
	if not shows_him():
		return "full"
	if current_menu != "default":
		return "menu"
	return "full" if details_open else "none"

## Whether his sheet is open now: not one of his menus, and not nothing.
func showing_details() -> bool:
	return shows_him() and view() == "full"

## His sheet, or no card (HUD.toggle_hero_details: the details key, his medallion).
func show_details(open: bool) -> void:
	details_open = open
	current_menu = "default"
	_refresh_ui()

## One of his menus -- "build", "eat" -- come up off its tile (HUD, his commands); "default" shuts it.
func show_menu(menu: String) -> void:
	current_menu = menu
	_refresh_ui()

## Whether his menu `menu` is what the card shows.
func showing_menu(menu: String) -> bool:
	return shows_him() and current_menu == menu

## Whether the card is his, rather than something else's.
func shows_him() -> bool:
	return selected_unit != null and is_instance_valid(selected_unit) and selected_unit == _get_hero()

## Whether the number keys are left to his commands below: nothing shown, or nothing on them here.
func leaves_keys() -> bool:
	return not visible or _keyed == 0

## Stands on `node` -- his commands in the corner -- and is pinned above it from now on.
func stand_on(node: Control) -> void:
	below = node
	_pin()

## Put away at the end of the run, and back at a restart.
func set_shut(yes: bool) -> void:
	shut = yes
	_settle()

func _process(delta: float) -> void:
	# Whatever the panel was showing has gone (destroyed, depleted): fall back to
	# the Hero, who is the resting subject.
	if selected_unit != null and (not is_instance_valid(selected_unit) or selected_unit.is_queued_for_deletion()):
		clear_selection()
		return
	if selected_unit == null:
		# The panel is built before Main spawns the Hero, so the first refresh finds
		# nothing. Keep trying until he exists.
		var hero = _get_hero()
		if hero != null and is_instance_valid(hero):
			set_selected_unit(hero)
		return
	_last_refresh_time += delta
	if _last_refresh_time >= UiTheme.number("refresh_seconds"):
		_last_refresh_time = 0.0
		_update_status_display()

# ==============================================================================
# Construction
# ==============================================================================

func _ensure_components() -> void:
	name = "OptionPanel"
	theme_type_variation = &"HudPanel"
	# Pinned to the bottom-right corner by that corner: the box is as wide as Config says
	# and exactly as tall as what is in it, growing upward as it fills.
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = _panel_size()
	_pin()

	var main_vbox = find_child("MainVBox", true, false) as VBoxContainer
	if main_vbox == null:
		main_vbox = VBoxContainer.new()
		main_vbox.name = "MainVBox"
		add_child(main_vbox)

	if title_label == null:
		header = HBoxContainer.new()
		header.name = "Header"
		main_vbox.add_child(header)
		var frame := PanelContainer.new()
		frame.name = "PortraitFrame"
		frame.theme_type_variation = &"InsetPanel"
		header.add_child(frame)
		portrait = TextureRect.new()
		portrait.name = "Portrait"
		portrait.custom_minimum_size = Vector2.ONE * UiTheme.portrait_size()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(portrait)
		var names := VBoxContainer.new()
		names.name = "Names"
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)   # a name and its kind read as one block
		header.add_child(names)
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.theme_type_variation = &"HeadingLabel"
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_label.text = tr("OPTION_UNIT_INFO")
		names.add_child(title_label)
		subtitle_label = Label.new()
		subtitle_label.name = "SubtitleLabel"
		subtitle_label.theme_type_variation = &"CaptionLabel"
		names.add_child(subtitle_label)

	if hp_row == null:
		var bars := UiKit.bar_row("Hp")
		bars[0].visible = false
		main_vbox.add_child(bars[0])
		hp_row = bars[0]
		hp_bar = bars[1]
		hp_text = bars[2]
		var work := UiKit.bar_row("Work", &"BuildBar")
		work[0].visible = false
		main_vbox.add_child(work[0])
		work_row = work[0]
		work_bar = work[1]
		work_text = work[2]
		work_text.theme_type_variation = &"CaptionLabel"

	if hero_stats == null:
		_build_hero_stats(main_vbox)

	if status_label == null:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.theme_type_variation = &"MutedLabel"
		status_label.text = tr("OPTION_DEFAULT_STATUS")
		# This line carries the longest text in the game -- a locked building says
		# what it is waiting on -- and a Label with no wrapping simply runs off the
		# panel and the player never reads the half that matters.
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(status_label)

	if separator == null:
		separator = HSeparator.new()
		separator.name = "HSeparator"
		main_vbox.add_child(separator)

	if button_container == null:
		button_container = GridContainer.new()
		button_container.name = "ButtonContainer"
		button_container.columns = 1
		main_vbox.add_child(button_container)

# ==============================================================================
# What is shown
# ==============================================================================

func _update_status_display() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	# A bench's commands are made again when what it offers has changed by itself -- a job done,
	# a stage of the beacon repaired, the beacon launched (debug-agent BUG-002: the launch stayed
	# on the card after the launch, until the bench was chosen again).
	if current_menu != "build" and selected_unit.has_method("can_offer") and _offer_of(selected_unit) != _station_offer:
		_refresh_ui()
		return
	var info: Dictionary = selected_unit.get_display_info() if selected_unit.has_method("get_display_info") else {}
	_show_vitals(info)
	if current_menu != "default" or _hover_detail_shown:
		return # this line is a menu's -- the hovered entry's detail, or what to pick -- not a unit's status
	if title_label:
		title_label.text = info.get("title", "")
	_set_status(String(info.get("status", "")))

## His block: a row for each of his three stats -- its icon, named in its tooltip; its bar; its
## figure -- and the row for the meal he is living on: its name, how long it has left, and a thin
## bar running down with it.
func _build_hero_stats(into: VBoxContainer) -> void:
	hero_stats = VBoxContainer.new()
	hero_stats.name = "HeroStats"
	hero_stats.visible = false
	hero_stats.add_theme_constant_override("separation", UiTheme.space("xs"))
	into.add_child(hero_stats)
	for spec in [["hp", "heart", "STAT_HP_NAME"], ["build", "build", "STAT_BUILD_NAME"], ["move", "walk", "STAT_MOVE_NAME"]]:
		var row := HBoxContainer.new()
		row.name = String(spec[0]).capitalize() + "Stat"
		var icon := UiKit.icon_rect(String(spec[1]), UiTheme.icon_size("s"), "Icon")
		icon.modulate = UiTheme.color("text_muted")
		icon.tooltip_text = tr(String(spec[2]))
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(icon)
		var bar := StatBar.new()
		bar.name = "Bar"
		row.add_child(bar)
		var figure := Label.new()
		figure.name = "Figure"
		figure.theme_type_variation = &"SmallNumberLabel"
		figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		figure.custom_minimum_size = Vector2(UiTheme.width("figure"), 0)
		row.add_child(figure)
		hero_stats.add_child(row)
		_stat_rows[String(spec[0])] = row
	boost_row = HBoxContainer.new()
	boost_row.name = "BoostRow"
	boost_row.visible = false
	var fed := UiKit.icon_rect("fed", UiTheme.icon_size("s"), "Icon")
	fed.modulate = UiTheme.color("boost")
	boost_row.add_child(fed)
	boost_text = Label.new()
	boost_text.name = "Text"
	boost_text.theme_type_variation = &"CaptionLabel"
	boost_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boost_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	boost_row.add_child(boost_text)
	boost_bar = ProgressBar.new()
	boost_bar.name = "Left"
	boost_bar.theme_type_variation = &"BoostBar"
	boost_bar.show_percentage = false
	boost_bar.min_value = 0.0
	boost_bar.max_value = 1.0
	boost_bar.step = 0.0
	boost_bar.custom_minimum_size = Vector2(UiTheme.width("figure"), UiTheme.thickness("bar"))
	boost_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boost_row.add_child(boost_bar)
	hero_stats.add_child(boost_row)
	ability_row = HFlowContainer.new()
	ability_row.name = "Abilities"
	ability_row.add_theme_constant_override("h_separation", UiTheme.space("xs"))
	ability_row.add_theme_constant_override("v_separation", UiTheme.space("xs"))
	hero_stats.add_child(ability_row)
	_abilities_shown.clear()
	_show_abilities(true)

## His row: a square for each slot (Config.KIT_SLOTS) -- pick, axe, weapon, armour, boots --
## holding the best he has made of it (Config.kit): its own icon, and on hover its name and what
## it does (Config.recipe_effect_text). An empty one says what goes there and where it is made.
## Rebuilt only when what he has changes.
func _show_abilities(force: bool = false) -> void:
	if ability_row == null:
		return
	var cfg = _get_config()
	var gs = _get_game_state()
	var owned: Array[String] = []
	if cfg and gs and "unlocks" in gs:
		owned = cfg.abilities(gs.unlocks)
	if not force and owned == _abilities_shown:
		return
	_abilities_shown = owned.duplicate()
	for child in ability_row.get_children():
		ability_row.remove_child(child)
		child.queue_free()
	var held: Dictionary = cfg.kit(gs.unlocks) if (cfg and gs and "unlocks" in gs) else {}
	var slot_ids: Array = cfg.KIT_SLOTS if cfg else []
	for slot_id in slot_ids:
		var slot := PanelContainer.new()
		slot.theme_type_variation = &"InsetPanel"
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		if held.has(slot_id):
			var recipe_id: String = String(held[slot_id])
			slot.name = "Ability_" + recipe_id
			slot.add_child(UiKit.icon_rect(recipe_id, UiTheme.icon_size("l"), "Icon"))
			var effect: String = String(cfg.recipe_effect_text(recipe_id))
			var name_text: String = tr(String(cfg.RECIPES[recipe_id].get("name", recipe_id)))
			slot.tooltip_text = (tr("ABILITY_TIP") % [name_text, effect]) if effect != "" else name_text
		else:
			slot.name = "EmptySlot_" + String(slot_id)
			# Not a black hole: the gilt lozenge of the rules, faint at its middle, as an empty
			# slot on the D4 / Elden Ring bars keeps a mark of what goes there.
			var blank := TextureRect.new()
			blank.name = "Mark"
			blank.texture = UiTheme.surface_texture("ornament")
			blank.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			blank.custom_minimum_size = Vector2.ONE * UiTheme.icon_size("l")
			blank.modulate = Color(1.0, 1.0, 1.0, UiTheme.number("empty_mark_alpha"))
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(blank)
			slot.modulate = Color(1.0, 1.0, 1.0, 0.55)
			slot.tooltip_text = tr("KIT_EMPTY_" + String(slot_id).to_upper())
		ability_row.add_child(slot)

## One of his stats: his own part and the whole, as shares of its bar; its figure, gold while a
## meal is raising it.
func _set_stat(key: String, own: float, whole: float, variation: StringName, figure: String, boosted: bool, worn: float = -1.0) -> void:
	var row: Node = _stat_rows.get(key)
	if row == null:
		return
	(row.get_node("Bar") as StatBar).set_values(own, whole, variation, worn)
	var label := row.get_node("Figure") as Label
	label.text = figure
	label.theme_type_variation = &"BoostNumberLabel" if boosted else &"SmallNumberLabel"

## His three bars and his meal, from what he reports (Hero.get_display_info). Each bar ends at
## the most the best meal in the game would make of it (Config.best_meal), so his own part is
## a length to be raised and the gold is how much this meal raises it.
func _show_hero_stats(info: Dictionary) -> void:
	var cfg = _get_config()
	# Health: his own hit points in the health colour, his armour's in leather, and those the meal
	# adds, gold.
	var max_hp: float = maxf(0.001, float(info.get("max_hp", 1.0)))
	var own_max: float = float(info.get("base_max_hp", max_hp))
	var natural: float = float(info.get("natural_max_hp", own_max))
	var hp: float = float(info.get("hp", 0.0))
	_set_stat("hp", minf(hp, natural) / max_hp, hp / max_hp, UiTheme.health_bar(hp / max_hp),
		UiKit.fraction_text(hp, max_hp), max_hp > own_max + 0.001, minf(hp, own_max) / max_hp)
	# Building: his own pace is x1.
	var best_build: float = maxf(1.0, float(cfg.best_meal("build_speed")) if cfg else 1.0)
	var build: float = float(info.get("build_speed", 1.0))
	_set_stat("build", 1.0 / best_build, build / best_build, &"BeaconBar",
		tr("STAT_BUILD_VALUE") % (cfg.factor_text(build) if cfg else str(build)), build > 1.0001)
	# Walking: his own stride, in metres a second -- boots and all -- against the best he can have.
	var own_walk: float = maxf(0.001, float(info.get("base_move_speed", 1.0)))
	var walk: float = float(info.get("move_speed", own_walk))
	var best_walk: float = own_walk
	if cfg:
		var best_boots: float = 1.0
		for recipe_id in cfg.RECIPES:
			best_boots = maxf(best_boots, float(cfg.RECIPES[recipe_id].get("move_speed", 1.0)))
		best_walk = float(cfg.HERO.get("move_speed", own_walk)) * best_boots * maxf(1.0, float(cfg.best_meal("move_speed")))
		best_walk = maxf(best_walk, walk)
	_set_stat("move", own_walk / best_walk, walk / best_walk, &"BeaconBar",
		tr("STAT_MOVE_VALUE") % walk, walk > own_walk + 0.001)
	# The meal he is living on, and how long it has left.
	var fed: Dictionary = info.get("fed", {})
	_show_abilities()
	boost_row.visible = not fed.is_empty()
	if not fed.is_empty():
		var left: float = maxf(0.0, float(fed.get("seconds_left", 0.0)))
		var secs: int = int(ceil(left))
		boost_text.text = tr("FED_LINE") % [_meal_name(String(fed.get("dish", "")), String(fed.get("method", ""))),
			secs / 60, secs % 60]
		boost_bar.value = clampf(left / maxf(0.001, float(fed.get("seconds_total", 1.0))), 0.0, 1.0)

## "Roast meat", "Seared prime meat": a meal named for how it was cooked (Config.COOKING_METHODS).
func _meal_name(dish_id: String, method_id: String) -> String:
	var cfg = _get_config()
	if cfg == null or not cfg.DISHES.has(dish_id):
		return ""
	var title: String = tr(String(cfg.DISHES[dish_id].get("name", dish_id)))
	for method in cfg.COOKING_METHODS:
		if String(method.get("id", "")) == method_id:
			var fmt: String = tr(String(method.get("name", "")))
			return (fmt % title) if "%s" in fmt else title
	return title

## The two bars, from what the selected thing reports about itself -- or, for the Hero, his block.
func _show_vitals(info: Dictionary) -> void:
	if hp_row == null:
		return
	var is_hero: bool = String(info.get("type", "")) == "hero"
	if hero_stats != null:
		hero_stats.visible = is_hero and view() == "full"
	if is_hero:
		hp_row.visible = false
		work_row.visible = false
		_show_hero_stats(info)
		return
	# Health, or what is left in a resource node -- the same bar, read the same way.
	var has_hp: bool = info.has("max_hp") and float(info.get("max_hp", 0.0)) > 0.0 and bool(info.get("is_constructed", true))
	var has_reserve: bool = info.has("max_capacity") and float(info.get("max_capacity", 0.0)) > 0.0
	hp_row.visible = has_hp or has_reserve
	if has_hp:
		var ratio: float = clampf(float(info["hp"]) / float(info["max_hp"]), 0.0, 1.0)
		hp_bar.value = ratio
		hp_bar.theme_type_variation = UiTheme.health_bar(ratio)
		hp_text.text = UiKit.fraction_text(float(info["hp"]), float(info["max_hp"]))
	elif has_reserve:
		hp_bar.value = clampf(float(info.get("current_amount", 0)) / float(info["max_capacity"]), 0.0, 1.0)
		hp_bar.theme_type_variation = &"BeaconBar"
		hp_text.text = UiKit.fraction_text(float(info.get("current_amount", 0)), float(info["max_capacity"]))
	# Work under way: a building going up or being upgraded, a job at a bench.
	var work: float = float(info.get("work", -1.0))
	work_row.visible = work >= 0.0
	if work >= 0.0:
		work_bar.value = clampf(work, 0.0, 1.0)
		work_text.text = UiKit.work_text(String(info.get("work_label", "")), work)

func _set_status(text: String) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.visible = text != "" and view() != "none"

func _refresh_ui() -> void:
	_ensure_components()
	if selected_unit == null or not is_instance_valid(selected_unit):
		var hero = _get_hero()
		if hero != null and is_instance_valid(hero):
			selected_unit = hero

	if selected_unit == null or not is_instance_valid(selected_unit):
		_set_header(TranslationServer.translate("OPTION_STATUS"), "", null)
		_show_vitals({})
		_set_status("")
		_clear_buttons()
		_settle()
		return

	var info: Dictionary = {}
	if selected_unit.has_method("get_display_info"):
		info = selected_unit.get_display_info()
	else:
		info = {"title": selected_unit.name, "type": "generic", "status": ""}

	var unit_type: String = String(info.get("type", ""))
	_set_header(String(info.get("title", selected_unit.name)), _kind_text(info), _portrait(info))
	_show_vitals(info)
	_set_status(String(info.get("status", "")))

	_clear_buttons()
	match unit_type:
		"hero":
			_populate_hero_buttons()
		"building":
			_populate_building_buttons()
		"resource_node":
			_populate_resource_buttons()
		"station":
			_populate_station_buttons()
		_:
			pass
	_settle()

func _set_header(title: String, kind: String, tex: Texture2D) -> void:
	if title_label:
		title_label.text = title
	if subtitle_label:
		subtitle_label.text = kind
		subtitle_label.visible = kind != ""
	if portrait:
		portrait.texture = tex
		portrait.get_parent().visible = tex != null

## What kind of thing it is, under its name.
func _kind_text(info: Dictionary) -> String:
	if info.has("kind_text"):
		return tr(String(info["kind_text"]))
	match String(info.get("type", "")):
		"hero":
			return tr("PANEL_KIND_HERO")
		"building":
			if String(info.get("building_type", "")) == "core":
				return tr("PANEL_KIND_CABIN")
			return tr("PANEL_KIND_BUILDING") if bool(info.get("is_constructed", true)) else tr("PANEL_KIND_BLUEPRINT")
		"resource_node":
			return tr("PANEL_KIND_NODE")
		"station":
			return tr("PANEL_KIND_STATION")
	return ""

## Who it is: its portrait, rendered from its model (Config.PORTRAITS) -- or, for a thing
## with none, its icon.
func _portrait(info: Dictionary) -> Texture2D:
	var shot: Texture2D = UiTheme.portrait(_visual_key(info))
	if shot:
		return shot
	match String(info.get("type", "")):
		"hero":
			return UiTheme.icon("hero")
		"building":
			return UiTheme.icon(String(info.get("building_type", "")))
		"resource_node":
			return UiTheme.node_icon(String(info.get("resource_type", "")))
		"station":
			return UiTheme.icon(String(info.get("station_id", "")))
	return null

## The Config.VISUALS key of what `info` describes: what it looks like, and so its portrait.
func _visual_key(info: Dictionary) -> String:
	match String(info.get("type", "")):
		"hero":
			return "hero"
		"building":
			return "building/%s" % String(info.get("building_type", ""))
		"resource_node":
			return "node/%s" % String(info.get("resource_type", ""))
		"station":
			return "station/%s" % String(info.get("station_id", ""))
	return ""

## The box's own rect is a line along the corner's bottom edge -- no height of its own --
## so the engine makes it exactly as tall as what it holds, growing upward, and shrinking
## again when it holds less. (Resizing it by hand instead kept its top edge where it was
## and pushed its bottom off the screen.) The edge is the top of his commands, while they show.
func _pin() -> void:
	var margin: float = _panel_margin()
	var lift: float = 0.0
	if below != null and is_instance_valid(below) and below.visible:
		lift = below.get_combined_minimum_size().y + UiTheme.space("s")
	offset_left = -(_panel_size().x + margin)
	offset_right = -margin
	offset_top = -(margin + lift)
	offset_bottom = -(margin + lift)

## After the content changes: drop the separator when there is nothing under it, and fade
## the new content in -- a transition, not a hard cut (UI-POLISH T10).
func _settle() -> void:
	var how: String = view()
	if header:
		header.visible = how == "full"
	if separator and button_container:
		separator.visible = button_container.get_child_count() > 0
	# Nothing open for him is no card at all: his commands are below, his health and his meal on his
	# medallion.
	visible = how != "none" and not shut
	_mark_keys()
	_pin()
	if _shown_unit != selected_unit or _shown_view != how:
		_shown_unit = selected_unit
		_shown_view = how
		if is_inside_tree():
			modulate.a = UiTheme.number("settle_alpha")
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 1.0, UiTheme.number("fade_seconds"))
	card_changed.emit()

## The number keys press the card's commands in the order they stand (Config.CONTROLS.command_keys),
## each marked with its key in a corner (UiKit.keycap). What cannot be taken back -- a demolish,
## the beacon's launch -- is left off the keys, and skipped in the count, so a key always means
## the same kind of thing; Back is the cancel key's (Main._unhandled_input peels a submenu off).
func _mark_keys() -> void:
	if button_container == null:
		return
	var cfg = _get_config()
	var controls: Dictionary = cfg.CONTROLS if cfg else {}
	var keys: Array = controls.get("command_keys", [])
	var n: int = 0
	_keyed = 0
	for child in button_container.get_children():
		var btn := child as Button
		if btn == null:
			continue
		if btn.name == BACK_NAME:
			UiKit.keycap(btn, tr("KEY_CANCEL"))
			continue
		if btn.theme_type_variation in [&"DangerButton", &"AccentButton"]:
			continue
		if n < keys.size():
			UiKit.key_shortcut(btn, int(keys[n]))
			UiKit.keycap(btn, OS.get_keycode_string(int(keys[n])))
			_keyed += 1
		n += 1

## What the Back command is called on the card, so the cancel key can find it and keys skip it.
const BACK_NAME := &"BackCommand"

func _clear_buttons() -> void:
	if button_container == null:
		return
	for child in button_container.get_children():
		button_container.remove_child(child)
		child.queue_free()

## A plain command: full width, an icon in front of its word.
func _create_action_button(text: String, callback: Callable, icon_name: String = "", variation: StringName = &"") -> Button:
	var btn := UiKit.action_button(text, UiTheme.icon(icon_name), callback, variation)
	button_container.add_child(btn)
	return btn

## An entry with a price (UiKit.card_button), added to the card's commands.
func _create_card_button(text: String, icon: Texture2D, price: Dictionary, callback: Callable) -> Button:
	var btn := UiKit.card_button(text, icon, callback)
	button_container.add_child(btn)
	_fill_price_row(btn, price)
	return btn

func _fill_price_row(btn: Button, price: Dictionary, extra: String = "") -> void:
	UiKit.fill_price_row(btn, price, extra)

## His menus. His commands themselves -- Build, and Eat with the meals cooked on a badge (v0.6 round
## two) -- are tiles of their own under the card (HeroCommands), and his sheet has none.
func _populate_hero_buttons() -> void:
	if current_menu == "eat":
		# One card per meal cooked: named for how it was cooked, how many, and what it does.
		button_container.columns = 1
		var cfg = _get_config()
		var gs = _get_game_state()
		var stock: Array = gs.meals_in_stock() if (gs and gs.has_method("meals_in_stock")) else []
		_set_status(tr("EAT_NOTHING") if stock.is_empty() else tr("EAT_HINT_PICK"))
		for entry in stock:
			var key: String = String(entry["key"])
			var dish: String = String(entry["dish"])
			var icon: Texture2D = UiTheme.icon(String(cfg.dish_icon(dish))) if cfg else null
			var btn := _create_card_button("%s ×%d" % [_meal_name(dish, String(entry["method"])), int(entry["count"])],
				icon, {}, func(): _trigger_eat(key))
			UiKit.fill_caption_row(btn, cfg.describe_meal(cfg.meal_cooked(dish, String(entry["method"]))) if cfg else "")
		var back := _create_action_button(TranslationServer.translate("CMD_BACK"), _on_back_pressed, "back", &"GhostButton")
		back.name = BACK_NAME
		back.custom_minimum_size = Vector2(0, UiTheme.height("card"))
	elif current_menu == "build":
		# Level 2: one card per buildable the run has turned up the materials for, then [ Back ]
		button_container.columns = 2
		var cfg = _get_config()
		var buildable: Array = _shown_buildables()
		_menu_types = buildable
		_clear_build_detail()
		# The card carries the name and the price; the cost in words and the build time go
		# in the detail line, shown for whichever card the cursor is over.
		for b_type in buildable:
			var price: Dictionary = cfg.BUILDINGS[b_type].get("cost", {}) if cfg else {}
			var btn := _create_card_button(_building_name(b_type), UiTheme.icon(String(b_type)), {}, func():
				_trigger_build(b_type)
			)
			btn.disabled = not _can_afford(b_type)
			_fill_price_row(btn, price)
			btn.mouse_entered.connect(func(): _show_build_detail(b_type))
			btn.focus_entered.connect(func(): _show_build_detail(b_type))
			btn.mouse_exited.connect(_clear_build_detail)

		var back := _create_action_button(TranslationServer.translate("CMD_BACK"), func():
			current_menu = "default"
			_refresh_ui()
		, "back", &"GhostButton")
		back.name = BACK_NAME
		back.custom_minimum_size = Vector2(0, UiTheme.height("card"))

## Cost and build time for the hovered entry, or a prompt when nothing is hovered.
## Anything that bites what touches it says so here: a stake fence only reads as a
## weapon rather than a speed bump if the player learns it before paying for it.
func _show_build_detail(b_type: String) -> void:
	if status_label == null:
		return
	_hover_detail_shown = true
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(b_type):
		return
	var b_name: String = _building_name(b_type)
	if _can_afford(b_type):
		var secs: float = float(cfg.get_build_time(b_type)) if cfg.has_method("get_build_time") else 0.0
		var dps: float = float(cfg.get_contact_dps(b_type)) if cfg.has_method("get_contact_dps") else 0.0
		var row: Dictionary = cfg.BUILDINGS[b_type]
		if String(row.get("kind", "")) == "trap":
			# What a trap does is what it does to what walks its lane (Trap.gd).
			var key: String = "BUILD_DETAIL_FORMAT_TRAP_PIERCE" if bool(row.get("pierce", false)) else "BUILD_DETAIL_FORMAT_TRAP"
			_set_status(tr(key) % [b_name, _cost_text(b_type), secs, float(row.get("damage", 0.0)),
				int(row.get("lane", 0)), float(row.get("rearm_seconds", 0.0))])
		elif String(row.get("kind", "")) == "fire":
			# What a fire does is light the night, and what it costs is wood every night (Fire.gd).
			_set_status(tr("BUILD_DETAIL_FORMAT_FIRE") % [b_name, _cost_text(b_type), secs,
				float(row.get("light", 0.0)), int(row.get("fuel", 0))])
		elif dps > 0.0:
			_set_status(tr("BUILD_DETAIL_FORMAT_DAMAGE") % [b_name, _cost_text(b_type), secs, dps])
		else:
			_set_status(tr("BUILD_DETAIL_FORMAT") % [b_name, _cost_text(b_type), secs])
		status_label.modulate = Color.WHITE
	else:
		# Name what is actually short. A set crossbow is bought with stone and bone, so
		# "need 4 stone" was a lie the moment the player had the stone and no bone.
		# And where the short things come from, when that is the real obstacle.
		_set_status(tr("BUILD_DETAIL_UNAFFORDABLE") % [b_name, _missing_text(b_type)] \
			+ _sources_text(cfg.BUILDINGS[b_type].get("cost", {})))
		status_label.modulate = UiKit.tone_color("short")

## A {resource: amount} bill, written out for a button or a status line.
func _amounts_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res_id in amounts:
		parts.append("%d %s" % [int(amounts[res_id]), _resource_name(String(res_id))])
	return ", ".join(parts)

## What an upgrade changes, number by number -- "re-arms in 4s -> 2.5s · HP 16 -> 22" --
## with its price and how long the work is. Only what actually changes is listed.
const _UPGRADE_STATS: Array[String] = ["rearm_seconds", "lane", "damage", "hp"]

func upgrade_detail_text(unit: Node, to_type: String = "") -> String:
	var cfg = _get_config()
	if cfg == null or unit == null or not is_instance_valid(unit) or not unit.has_method("upgrade_target"):
		return ""
	var from: Dictionary = cfg.BUILDINGS.get(String(unit.building_type), {})
	if to_type == "":
		to_type = unit.upgrade_target()
	var to: Dictionary = cfg.BUILDINGS.get(to_type, {})
	var parts: PackedStringArray = []
	for stat in _UPGRADE_STATS:
		if from.has(stat) and to.has(stat) and float(from[stat]) != float(to[stat]):
			parts.append(tr("STAT_%s" % stat.to_upper()) % [cfg.factor_text(float(from[stat])), cfg.factor_text(float(to[stat]))])
	return tr("UPGRADE_DETAIL_FORMAT") % [_building_name(to_type), _amounts_text(unit.upgrade_cost(to_type)),
		float(cfg.get_upgrade_time(String(unit.building_type), to_type)), " · ".join(parts)]

func _show_upgrade_detail(unit: Node, to_type: String = "") -> void:
	if status_label == null:
		return
	_hover_detail_shown = true
	_set_status(upgrade_detail_text(unit, to_type))
	status_label.modulate = Color.WHITE

## What a building costs, in every resource it asks for.
func _cost_text(b_type: String) -> String:
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(b_type):
		return ""
	return _amounts_text(cfg.BUILDINGS[b_type].get("cost", {}))

## How much of each resource is still missing, and nothing about the ones that are
## already covered.
func _missing_text(b_type: String) -> String:
	var cfg = _get_config()
	var gs = _get_game_state()
	if cfg == null or gs == null or not cfg.BUILDINGS.has(b_type):
		return ""
	var parts: PackedStringArray = []
	for res_id in cfg.BUILDINGS[b_type].get("cost", {}):
		var short: int = int(cfg.BUILDINGS[b_type]["cost"][res_id]) - int(gs.resources.get(res_id, 0))
		if short > 0:
			parts.append("%d %s" % [short, _resource_name(String(res_id))])
	return ", ".join(parts)

## Where the short materials come from (UiKit.sources_text): the reason chain at the price.
func _sources_text(price: Dictionary) -> String:
	return UiKit.sources_text(price)

func _clear_build_detail() -> void:
	_hover_detail_shown = false
	if status_label == null:
		return
	_set_status(tr("BUILD_HINT_PICK"))
	status_label.modulate = Color.WHITE

func _building_name(b_type: String) -> String:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_name"):
		return String(cfg.get_building_name(b_type))
	return b_type

func _can_afford(b_type: String) -> bool:
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs == null or cfg == null or not cfg.BUILDINGS.has(b_type):
		return false
	if gs.has_method("can_afford"):
		return bool(gs.can_afford(cfg.BUILDINGS[b_type].get("cost", {})))
	return true

## A building's own menu: the things with a cost or a consequence. Right-click
## deliberately does not offer these -- it is too easy to hit by accident -- so
## mending and demolishing are chosen here, on purpose, with the price on the
## button.
func _populate_building_buttons() -> void:
	button_container.columns = 1
	# Upgrading where it stands (v0.6): the price on the button, and on hover the numbers
	# that change -- before and after is the whole of the choice. Paid when chosen, like a
	# blueprint, and the Hero goes straight over to build it. One button for each thing it can
	# become (v0.6 round six, GAME-DESIGN 6.0: a fence becomes bone stakes or a stone wall), each
	# named, with its own price.
	if selected_unit.has_method("can_upgrade") and selected_unit.can_upgrade():
		var unit: Node = selected_unit
		for to_type in unit.upgrade_targets():
			var target: String = String(to_type)
			var up_text: String = tr("CMD_UPGRADE_TO") % [_building_name(target), _amounts_text(unit.upgrade_cost(target))]
			var up_btn := _create_action_button(up_text, func():
				if not is_instance_valid(unit) or not unit.begin_upgrade(target):
					return
				var hero = _get_hero()
				if hero and is_instance_valid(hero) and hero.has_method("order_upgrade"):
					hero.order_upgrade(unit)
				action_triggered.emit("upgrade", unit)
				_refresh_ui()
			, "upgrade")
			var gs_up = _get_game_state()
			up_btn.disabled = gs_up == null or not gs_up.has_method("can_afford") or not gs_up.can_afford(unit.upgrade_cost(target))
			up_btn.mouse_entered.connect(func(): _show_upgrade_detail(unit, target))
			up_btn.focus_entered.connect(func(): _show_upgrade_detail(unit, target))
			up_btn.mouse_exited.connect(_clear_craft_detail)

	if selected_unit.has_method("needs_repair") and selected_unit.needs_repair():
		# The bill is listed in what it actually costs: a set crossbow is mended with
		# stone and bone, so "N stone" would be the same lie the build menu used to tell.
		var raw: String = tr("CMD_REPAIR")
		var cost_text: String = _amounts_text(selected_unit.repair_cost()) if selected_unit.has_method("repair_cost") else ""
		var btn := _create_action_button((raw % cost_text) if ("%" in raw) else raw, func():
			var hero = _get_hero()
			if hero and is_instance_valid(hero) and hero.has_method("order_repair") and is_instance_valid(selected_unit):
				hero.order_repair(selected_unit)
				action_triggered.emit("repair", selected_unit)
		, "repair")
		btn.disabled = not _can_pay_a_repair_step()

	# The cabin itself cannot be pulled down: it is the game.
	if selected_unit.has_method("demolish") and not ("building_type" in selected_unit and String(selected_unit.building_type) == "core"):
		_create_action_button(TranslationServer.translate("CMD_DEMOLISH"), func():
			if selected_unit and is_instance_valid(selected_unit) and selected_unit.has_method("demolish"):
				var unit_to_demolish = selected_unit
				clear_selection()
				unit_to_demolish.demolish()
		, "demolish", &"DangerButton")

## Resource nodes are scenery, not units: they take no orders. Right-clicking one
## while the Hero is selected already sends him to harvest it, so a button here
## would only be a second, slower way to do the same thing.
func _populate_resource_buttons() -> void:
	pass

## One card per job this bench still has to offer. A recipe already made is not listed
## at all -- an unlock is permanent, so a finished one is not a choice. The kitchen's meals
## come after its recipes: one per kind of meat, always on offer, named for however his
## best pot will cook it.
## What the bench shown offers as its commands were made: the jobs on offer, and whether it is at
## one (_update_status_display compares it with what it offers now).
var _station_offer: Array = []

func _offer_of(station: Node) -> Array:
	var out: Array = []
	var jobs: Array = station.jobs() if station.has_method("jobs") else station.recipes()
	for recipe_id in jobs:
		if station.can_offer(String(recipe_id)):
			out.append(String(recipe_id))
	out.append("active_recipe" in station and String(station.active_recipe) != "")
	return out

func _populate_station_buttons() -> void:
	var station := selected_unit
	if station == null or not is_instance_valid(station) or not station.has_method("recipes"):
		return
	_clear_craft_detail()
	var jobs: Array = station.jobs() if station.has_method("jobs") else station.recipes()
	var busy: bool = "active_recipe" in station and String(station.active_recipe) != ""
	_station_offer = _offer_of(station)
	# More than a few on offer -- the workbench, with everything for his row (v0.6 round three) --
	# and they stand two to a row, as the build menu's do: one to a row, they ran off the screen.
	var offered: int = 0
	for recipe_id in jobs:
		if station.can_offer(String(recipe_id)):
			offered += 1
	button_container.columns = 2 if offered > int(UiTheme.number("one_column_most")) else 1
	for recipe_id in jobs:
		var rid: String = String(recipe_id)
		if not station.can_offer(rid):
			continue
		var start := func():
			if is_instance_valid(station):
				station.begin(rid)
				_refresh_ui()
		# A job that costs nothing and takes no time is not a purchase but a decision -- the
		# beacon's launch -- and is drawn as the one thing to press.
		var decision: bool = station.inputs_of(rid).is_empty() and float(station.time_of(rid)) <= 0.0
		var btn: Button
		if decision:
			btn = UiKit.action_button(station.recipe_name(rid), UiTheme.icon("signal"), start, &"AccentButton")
			btn.custom_minimum_size.y = UiTheme.height("card")
			button_container.add_child(btn)
		else:
			btn = _create_card_button(station.recipe_name(rid), UiKit.job_icon(station, rid), {}, start)
			_fill_price_row(btn, station.inputs_of(rid), UiKit.seconds_text(station.time_of(rid)))
		btn.name = "Job_%s" % rid
		btn.disabled = busy or not station.can_afford(rid)
		btn.mouse_entered.connect(func(): _show_craft_detail(station, rid))
		btn.focus_entered.connect(func(): _show_craft_detail(station, rid))
		btn.mouse_exited.connect(_clear_craft_detail)

## What a job costs, takes and does, for whichever entry the cursor is over (UiKit.job_detail).
func _show_craft_detail(station: Node, recipe_id: String) -> void:
	if status_label == null or station == null or not is_instance_valid(station):
		return
	_hover_detail_shown = true
	var detail: Array = UiKit.job_detail(station, recipe_id)
	_set_status(String(detail[0]))
	status_label.modulate = UiKit.tone_color(String(detail[1]))

## What launching the beacon brings (UiKit.launch_detail).
func _launch_detail() -> String:
	return UiKit.launch_detail()

func _clear_craft_detail() -> void:
	_hover_detail_shown = false
	if status_label == null:
		return
	if selected_unit != null and is_instance_valid(selected_unit) and selected_unit.has_method("get_display_info"):
		_set_status(String(selected_unit.get_display_info().get("status", "")))
	else:
		_set_status(tr("CABIN_HINT_PICK_STATION"))
	status_label.modulate = Color.WHITE

## The whole bill has to be payable: repair is one transaction, so there is no
## point starting a job the warehouse cannot finish.
func _can_pay_a_repair_step() -> bool:
	var gs = _get_game_state()
	if gs == null or not ("resources" in gs) or selected_unit == null or not is_instance_valid(selected_unit):
		return false
	if not selected_unit.has_method("repair_cost"):
		return false
	var owed: Dictionary = selected_unit.repair_cost()
	for res_id in owed:
		if int(gs.resources.get(res_id, 0)) < int(owed[res_id]):
			return false
	return not owed.is_empty()

func _resource_name(res_id: String) -> String:
	return TranslationServer.translate("RESOURCE_%s" % res_id.to_upper())

func _trigger_build(type_id: String) -> void:
	build_option_selected.emit(type_id)
	var hud = _get_hud()
	if hud and is_instance_valid(hud) and hud.has_method("select_build_type"):
		hud.select_build_type(type_id)
	# A building in hand puts the menu away: the ground it goes on is what matters now, and it stays
	# in hand for as many as can be paid for (Main.try_place_at_cell). The menu is a key away for
	# the next.
	current_menu = "default"
	_refresh_ui()

func _get_hero() -> Node:
	if is_inside_tree():
		return get_tree().get_first_node_in_group("hero")
	return null

func _get_hud() -> Node:
	if is_inside_tree():
		return get_tree().root.find_child("HUD", true, false)
	return null

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("EventBus")
	return null

## The panel's width (Config.UI); its height is whatever it holds.
func _panel_size() -> Vector2:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return cfg.UI.get("option_panel_size", Vector2(400, 0))
	return Vector2(400, 0)

func _panel_margin() -> float:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return float(cfg.UI.get("option_panel_margin", 16.0))
	return 16.0

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
