# res://scripts/ui/HeroCommands.gd
class_name HeroCommands
extends HBoxContainer

## His two commands, Build and Eat, as tiles in the bottom right corner: there all the while, and
## never moving (v0.6 round four: "最好建造和吃的两个图标不要变动位置，就在右下角原处"). What they open
## -- his menus -- and every other card stand above them (OptionPanel.stand_on), as a menu comes up off
## its button in the games that keep the screen clear.
##
## The number keys press them while the card above has no commands on the keys of its own
## (set_keys_live); while it has, the keys are its, and the tiles' keycaps go, so no key is shown
## twice. A tile whose menu is open stays pressed in (mark_open). Styled by UiTheme like the rest:
## nothing here picks a colour or a size.

signal build_pressed()
signal eat_pressed()

var build_button: Button = null
var eat_button: Button = null
var _keys_live: bool = false
var _clock: float = 0.0

func _ready() -> void:
	name = "HeroCommands"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UiTheme.space("s"))
	build_button = UiKit.command_button(tr("CMD_BUILD"), UiTheme.icon("hammer"), func(): build_pressed.emit(), tr("TIP_CMD_BUILD"))
	build_button.name = "BuildCommand"
	add_child(build_button)
	eat_button = UiKit.command_button(tr("CMD_EAT"), UiTheme.icon("roast"), func(): eat_pressed.emit(), tr("TIP_CMD_EAT"), 0)
	eat_button.name = "EatCommand"
	add_child(eat_button)
	for btn in [build_button, eat_button]:
		btn.toggle_mode = true
	_pin()
	set_keys_live(true)
	refresh()
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("meals_changed"):
			eb.meals_changed.connect(func(_meals: Dictionary): refresh())
		if eb.has_signal("locale_changed"):
			eb.locale_changed.connect(func(_locale: String): _retext())

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= UiTheme.number("refresh_seconds"):
		_clock = 0.0
		refresh()

## In the bottom right corner, the card's margin in from the screen's edges, as big as the tiles.
func _pin() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var cfg = get_node_or_null("/root/Config")
	var margin: float = float(cfg.UI.get("option_panel_margin", 16.0)) if (cfg and "UI" in cfg) else 16.0
	offset_left = -margin
	offset_right = -margin
	offset_top = -margin
	offset_bottom = -margin

## Whether the first command keys press Build and Eat, each tile wearing its key: not while the card
## above has commands on the keys of its own.
func set_keys_live(live: bool) -> void:
	_keys_live = live
	var cfg = get_node_or_null("/root/Config")
	var keys: Array = cfg.CONTROLS.get("command_keys", []) if (cfg and "CONTROLS" in cfg) else []
	for i in 2:
		var btn: Button = build_button if i == 0 else eat_button
		if btn == null:
			continue
		if live and i < keys.size():
			UiKit.key_shortcut(btn, int(keys[i]))
			UiKit.keycap(btn, OS.get_keycode_string(int(keys[i])))
		else:
			btn.shortcut = null
		var cap: Control = btn.get_node_or_null("Keycap") as Control
		if cap:
			cap.visible = live

func keys_live() -> bool:
	return _keys_live

## The tile whose menu is open stays pressed in: "build", "eat", or "" for neither.
func mark_open(menu: String) -> void:
	build_button.set_pressed_no_signal(menu == "build")
	eat_button.set_pressed_no_signal(menu == "eat")

## The meals cooked on Eat's badge -- nothing to press when there are none, or while he eats.
func refresh() -> void:
	if eat_button == null:
		return
	var gs = get_node_or_null("/root/GameState")
	var meals: int = 0
	if gs and "meals" in gs:
		for key in gs.meals:
			meals += int(gs.meals[key])
	var badge: Label = eat_button.get_node_or_null("Badge") as Label
	if badge:
		badge.text = str(meals)
	var hero: Node = get_tree().get_first_node_in_group("hero") if is_inside_tree() else null
	var eating: bool = hero != null and is_instance_valid(hero) and hero.has_method("is_eating") and bool(hero.is_eating())
	eat_button.disabled = meals <= 0 or eating

func _retext() -> void:
	build_button.text = tr("CMD_BUILD")
	build_button.tooltip_text = tr("TIP_CMD_BUILD")
	eat_button.text = tr("CMD_EAT")
	eat_button.tooltip_text = tr("TIP_CMD_EAT")
