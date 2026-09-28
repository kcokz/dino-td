# res://scripts/ui/BossBar.gd
class_name BossBar
extends VBoxContainer

## A boss's own bar (v0.6 round three: "往精致游戏上靠近，比如学习暗黑破坏神4的那种界面风格，或者艾尔登环"):
## when a leader or the map's boss takes the field (EventBus.boss_arrived), its name and a long bar
## low in the middle of the field, the way those games give a boss its own -- so the fight of the
## run reads as one, and how far it has to go is in view wherever the camera is. A hit leaves the
## part it took lit a moment before it drains away (the trail), so a big blow reads as big.
##
## One boss at a time: the last to arrive, while it lives, then whichever other is still
## standing. When the last falls, its empty bar stays a moment and fades.
##
## How long the trail waits and how fast it drains, how long an empty bar stays: Config.THEME
## ("boss_trail_hold", "boss_trail_drain", "boss_bar_linger"). Where it stands: HUD.

## The boss it follows, or null.
var boss: Node = null
## What that boss has left, 0..1 of its bar.
var ratio: float = 0.0
## The lit part behind it, 0..1: what a hit took, waiting and then draining down to `ratio`.
var trail: float = 0.0

var name_label: Label = null
var bar: Control = null

var _bosses: Array[Node] = []
var _trail_wait: float = 0.0
var _gone_for: float = -1.0
var _fade: Tween = null

func _init() -> void:
	name = "BossBar"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UiTheme.space("xs"))
	name_label = Label.new()
	name_label.name = "BossName"
	name_label.theme_type_variation = &"BossNameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	bar = Control.new()
	bar.name = "BossHealth"
	bar.custom_minimum_size = Vector2(0, UiTheme.thickness("boss_bar"))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	add_child(bar)

func _ready() -> void:
	var eb = _event_bus()
	if eb and eb.has_signal("boss_arrived") and not eb.boss_arrived.is_connected(follow):
		eb.boss_arrived.connect(follow)

func _exit_tree() -> void:
	var eb = _event_bus()
	if eb and eb.has_signal("boss_arrived") and eb.boss_arrived.is_connected(follow):
		eb.boss_arrived.disconnect(follow)

## A boss has taken the field: its bar, full, in place of whatever was shown.
func follow(dino: Node) -> void:
	if dino == null or not is_instance_valid(dino):
		return
	if not _bosses.has(dino):
		_bosses.append(dino)
	_show(dino)

func _show(dino: Node) -> void:
	boss = dino
	ratio = _share(dino)
	trail = ratio
	_trail_wait = 0.0
	_gone_for = -1.0
	var cfg = _config()
	var species: String = String(dino.get("dino_type"))
	name_label.text = String(cfg.get_dino_name(species)) if (cfg and cfg.has_method("get_dino_name")) else species
	if not visible or (_fade and _fade.is_running()):
		_fade_to(1.0)
	bar.queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	if boss != null and (not is_instance_valid(boss) or bool(boss.get("is_dead"))):
		_fallen()
	if boss != null:
		var now: float = _share(boss)
		if now < ratio - 0.0001:
			# Hit: the trail waits while the blows keep coming, and only then drains.
			_trail_wait = UiTheme.number("boss_trail_hold")
		ratio = now
	if trail > ratio:
		if _trail_wait > 0.0:
			_trail_wait -= delta
		else:
			trail = maxf(ratio, trail - UiTheme.number("boss_trail_drain") * delta)
	else:
		trail = ratio
	if _gone_for >= 0.0:
		_gone_for += delta
		if _gone_for >= UiTheme.number("boss_bar_linger") and not (_fade and _fade.is_running()):
			_gone_for = -1.0
			_fade_to(0.0)
	bar.queue_redraw()

## Its boss is down: the next still standing, or an empty bar that stays a moment and goes.
func _fallen() -> void:
	ratio = 0.0
	boss = null
	for i in range(_bosses.size() - 1, -1, -1):
		var other: Node = _bosses[i]
		if not is_instance_valid(other) or bool(other.get("is_dead")):
			_bosses.remove_at(i)
	if not _bosses.is_empty():
		_show(_bosses.back())
		return
	_gone_for = 0.0

func _share(dino: Node) -> float:
	var whole: float = float(dino.get("max_hp"))
	return clampf(float(dino.get("current_hp")) / whole, 0.0, 1.0) if whole > 0.0 else 0.0

func _fade_to(alpha: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	if alpha > 0.0:
		visible = true
	if not is_inside_tree():
		modulate.a = alpha
		visible = alpha > 0.0
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, UiTheme.number("fade_seconds"))
	if alpha <= 0.0:
		_fade.tween_callback(func(): visible = false)

## The theme's own trough and pigments (UiTheme), as every bar in the interface: the lit trail in
## the warning's amber behind, what it has left in the boss's crimson over it.
func _draw_bar() -> void:
	var whole := Rect2(Vector2.ZERO, bar.size)
	var trough: StyleBox = bar.get_theme_stylebox("background", "ProgressBar")
	if trough:
		bar.draw_style_box(trough, whole)
	if trail > ratio:
		var lit: StyleBox = bar.get_theme_stylebox("fill", "WarnBar")
		if lit:
			bar.draw_style_box(lit, Rect2(Vector2.ZERO, Vector2(bar.size.x * trail, bar.size.y)))
	if ratio > 0.0:
		var red: StyleBox = bar.get_theme_stylebox("fill", "BossLifeBar")
		if red:
			bar.draw_style_box(red, Rect2(Vector2.ZERO, Vector2(bar.size.x * ratio, bar.size.y)))

func _config() -> Node:
	return get_tree().root.get_node_or_null("Config") if is_inside_tree() else null

func _event_bus() -> Node:
	return get_tree().root.get_node_or_null("EventBus") if is_inside_tree() else null
