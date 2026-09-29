# res://scripts/ui/HeroCommands.gd
class_name HeroCommands
extends HBoxContainer

## His commands, as tiles in the bottom right corner (v0.6 round four: "最好建造和吃的两个图标不要变动位
## 置，就在右下角原处"). What they open -- his menus -- and every other card stand above them
## (OptionPanel.stand_on), as a menu comes up off its button in the games that keep the screen clear.
##
## BUILD AT THE RIGHT, AND THE REST IN THE ORDER THEY BECOME HIS (v0.6 round four, the player: "Build 按钮
## 放最右边，哪个能力先解锁放哪个在靠右，以此类推，吃一开始隐藏因为没有食物，火把也是"). Build is there from the
## first; each other command comes in to the left of those there already when it first can be used --
## Eat when there is first a meal to eat, Torch with the first dusk -- and stays where it came for the
## rest of the run, greyed out while it cannot be pressed (no meal; daylight; no wood), so nothing to
## its left ever moves. Its key is its place: the first command key Build's, the next the first to come,
## and so on (Config.CONTROLS.command_keys).
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
## The commands there, in the order they came: "build" first, then as each became his.
var came: Array[String] = []
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
	_pin()
	_keys_live = true
	reset()
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("meals_changed"):
			eb.meals_changed.connect(func(_meals: Dictionary): refresh())
		# And at once whatever changes what a tile says: the wood in the stock, the part of the day, a
		# torch lit or burnt out. Waiting for the next refresh, the torch's came up a few seconds after
		# the dusk was said, and a press on it the moment the wood came in was lost (the debug-agent's
		# check 17: "夜里第一次按 3 常常没反应，第二次按就点着").
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

## A run begun: Build alone, at the right end, the rest to come as they become his.
func reset() -> void:
	came.clear()
	came.append("build")
	move_child(build_button, -1)
	eat_button.visible = false
	torch_button.visible = false
	set_keys_live(_keys_live)
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

## The tile of the command `id`: "build", "eat", "torch".
func tile(id: String) -> Button:
	return {"build": build_button, "eat": eat_button, "torch": torch_button}.get(id, null)

## A command become his: its tile comes in to the left of those there already -- the corner grows
## leftwards, so none of them moves -- and takes the next key.
func _come(id: String) -> void:
	if came.has(id):
		return
	var btn: Button = tile(id)
	if btn == null:
		return
	came.append(id)
	move_child(btn, 0)
	btn.visible = true
	set_keys_live(_keys_live)
	# Seen as it comes: it grows in, lit, and the light fades (the debug-agent's TASK-024).
	UiKit.come_in(btn)

## The key of the command `id` as the keyboard writes it: its place among those come -- one not come
## yet, the place it would come to -- or "" past the last key.
func key_of(id: String) -> String:
	var at: int = came.find(id)
	if at < 0:
		at = came.size()
	var keys: Array = _keys()
	return OS.get_keycode_string(int(keys[at])) if at < keys.size() else ""

func _keys() -> Array:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else Engine.get_main_loop().root.get_node_or_null("Config")
	return cfg.CONTROLS.get("command_keys", []) if (cfg and "CONTROLS" in cfg) else []

## Whether the first command keys press the tiles there, each wearing its key -- in the order they
## came: not while the card above has commands on the keys of its own.
func set_keys_live(live: bool) -> void:
	_keys_live = live
	var keys: Array = _keys()
	for id in ["build", "eat", "torch"]:
		var btn: Button = tile(id)
		if btn == null:
			continue
		var at: int = came.find(id)
		var keyed: bool = live and at >= 0 and at < keys.size()
		if keyed:
			UiKit.key_shortcut(btn, int(keys[at]))
			UiKit.keycap(btn, OS.get_keycode_string(int(keys[at])))
		else:
			btn.shortcut = null
		var cap: Control = btn.get_node_or_null("Keycap") as Control
		if cap:
			cap.visible = keyed

func keys_live() -> bool:
	return _keys_live

## The tile whose menu is open stays pressed in: "build", "eat", or "" for neither.
func mark_open(menu: String) -> void:
	build_button.set_pressed_no_signal(menu == "build")
	eat_button.set_pressed_no_signal(menu == "eat")

## Each tile as things stand: whether a command has become his (Eat, the first meal; Torch, the first
## dusk), and whether it can be pressed now. Not out of the tree: a level taken down but not yet freed
## still heard the stock change, and asked for the Hero outside the tree (the debug-agent's check of
## 7dd3f34, thirty lines of it in the bot's log).
func refresh() -> void:
	if eat_button == null or not is_inside_tree():
		return
	var gs = get_node_or_null("/root/GameState")
	var meals: int = 0
	if gs and "meals" in gs:
		for key in gs.meals:
			meals += int(gs.meals[key])
	if meals > 0:
		_come("eat")
	var badge: Label = eat_button.get_node_or_null("Badge") as Label
	if badge:
		badge.text = str(meals)
		# None cooked: its 0 in the colour of what he is short of, as a price he cannot pay is.
		if meals <= 0:
			badge.add_theme_color_override("font_color", UiTheme.color("ink_short"))
		else:
			badge.remove_theme_color_override("font_color")
	var hero: Node = get_tree().get_first_node_in_group("hero")
	var eating: bool = hero != null and is_instance_valid(hero) and hero.has_method("is_eating") and bool(hero.is_eating())
	eat_button.disabled = meals <= 0 or eating
	_refresh_torch(hero)

## The torch's tile: come with the first dusk, greyed out by day and while one burns, its badge the
## seconds a lit one has left.
func _refresh_torch(hero: Node) -> void:
	if torch_button == null:
		return
	var has_hero: bool = hero != null and is_instance_valid(hero) and hero.has_method("can_light_torch")
	var left: float = float(hero.torch_left) if (has_hero and "torch_left" in hero) else 0.0
	var gs = get_node_or_null("/root/GameState")
	var cfg = get_node_or_null("/root/Config")
	var burns: Array = cfg.FIRE.get("burns", ["dusk", "night"]) if (cfg and "FIRE" in cfg) else ["dusk", "night"]
	var dark: bool = gs != null and gs.has_method("day_part") and String(gs.day_part()) in burns
	if has_hero and (dark or left > 0.0):
		_come("torch")
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
