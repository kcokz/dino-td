# res://scripts/ui/HeroCommands.gd
class_name HeroCommands
extends HBoxContainer

## His two commands, Build and Eat, as tiles in the bottom right corner: there all the while, and
## never moving (v0.6 round four: "最好建造和吃的两个图标不要变动位置，就在右下角原处"). What they open
## -- his menus -- and every other card stand above them (OptionPanel.stand_on), as a menu comes up off
## its button in the games that keep the screen clear.
##
## And in the dark a third, Torch, to the left of them, so they do not move (GAME-DESIGN 9.3: "人举着
## 火把"): shown from dusk to first light and while a torch burns, its badge the seconds it has left,
## not to be pressed while one burns or there is no wood for it (Hero.can_light_torch).
##
## The number keys press them while the card above has no commands on the keys of its own
## (set_keys_live); while it has, the keys are its, and the tiles' keycaps go, so no key is shown
## twice. A tile whose menu is open stays pressed in (mark_open). Styled by UiTheme like the rest:
## nothing here picks a colour or a size.

signal build_pressed()
signal eat_pressed()
signal torch_pressed()

var build_button: Button = null
var eat_button: Button = null
var torch_button: Button = null
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
	torch_button = UiKit.command_button(tr("CMD_TORCH"), UiTheme.icon("torch"), func(): torch_pressed.emit(), _torch_tip(), 0)
	torch_button.name = "TorchCommand"
	add_child(torch_button)
	move_child(torch_button, 0)
	_pin()
	set_keys_live(true)
	refresh()
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("meals_changed"):
			eb.meals_changed.connect(func(_meals: Dictionary): refresh())
		# And at once whatever changes what the torch's tile says: the wood in the stock, the part of the
		# day, a torch lit or burnt out. Waiting for the next refresh, it came up a few seconds after the
		# dusk was said, and a press on it the moment the wood came in was lost (the debug-agent's check
		# 17: "夜里第一次按 3 常常没反应，第二次按就点着").
		if eb.has_signal("resources_changed"):
			eb.resources_changed.connect(func(_stock: Dictionary): refresh())
		if eb.has_signal("day_part_changed"):
			eb.day_part_changed.connect(func(_part: String, _day: int): refresh())
		if eb.has_signal("torch_changed"):
			eb.torch_changed.connect(func(_lit: bool): refresh())
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
	for i in 3:
		var btn: Button = [build_button, eat_button, torch_button][i]
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
	_refresh_torch(hero)

## The torch's tile: there in the dark and while one burns, its seconds left on its badge.
func _refresh_torch(hero: Node) -> void:
	if torch_button == null:
		return
	var has_hero: bool = hero != null and is_instance_valid(hero) and hero.has_method("can_light_torch")
	var left: float = float(hero.torch_left) if (has_hero and "torch_left" in hero) else 0.0
	var gs = get_node_or_null("/root/GameState")
	var cfg = get_node_or_null("/root/Config")
	var burns: Array = cfg.FIRE.get("burns", ["dusk", "night"]) if (cfg and "FIRE" in cfg) else ["dusk", "night"]
	var dark: bool = gs != null and gs.has_method("day_part") and String(gs.day_part()) in burns
	torch_button.visible = has_hero and (dark or left > 0.0)
	torch_button.disabled = not has_hero or not bool(hero.can_light_torch())
	var badge: Label = torch_button.get_node_or_null("Badge") as Label
	if badge:
		badge.visible = left > 0.0
		badge.text = str(int(ceil(left)))

func _retext() -> void:
	build_button.text = tr("CMD_BUILD")
	build_button.tooltip_text = tr("TIP_CMD_BUILD")
	eat_button.text = tr("CMD_EAT")
	eat_button.tooltip_text = tr("TIP_CMD_EAT")
	torch_button.text = tr("CMD_TORCH")
	torch_button.tooltip_text = _torch_tip()

## What a torch costs and does, from its numbers (Config.FIRE.torch).
func _torch_tip() -> String:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else Engine.get_main_loop().root.get_node_or_null("Config")
	var torch: Dictionary = cfg.FIRE.get("torch", {}) if (cfg and "FIRE" in cfg) else {}
	return tr("TIP_CMD_TORCH") % [int(torch.get("cost", {}).get("wood", 1)), int(torch.get("seconds", 60.0)),
		int(torch.get("light", 7.0))]
