# res://scripts/ui/StatBar.gd
class_name StatBar
extends Control

## A bar in two parts, for something a meal can raise: what he has of his own, in the stat's own
## colour, and the meal's boost on top of it in the boost's (the theme's "BoostBar").
##
## v0.6 round two: "人的界面面板上还要有显示血量、建造速度、移动速度，分别都有一个血条。然后吃了饭之后会有
## 一个 boost，那个 boost 要比较清楚地显示在移动速度、血量上面". One bar, two pigments, so the gain is the
## length of gold at the end of it -- not a number to compare with one remembered from before.
##
## Drawn with the theme's own trough and pigments (UiTheme: the ProgressBar's background, a bar
## variation's fill), so it is the same object as every other bar in the interface.

## How far his own part reaches, 0..1 of the bar.
var base_ratio: float = 0.0
## How far the whole reaches, boost and all, 0..1 -- never short of base_ratio.
var total_ratio: float = 0.0
## The bar variation his own part is painted as (UiTheme: HealthBar, WarnBar, ...).
var fill_variation: StringName = &"HealthBar"

func _init() -> void:
	custom_minimum_size = Vector2(0, UiTheme.thickness("bar"))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Sets both parts, as shares of the bar, and what his own part is painted as.
func set_values(base: float, total: float, variation: StringName = &"") -> void:
	var b: float = clampf(base, 0.0, 1.0)
	var t: float = clampf(maxf(total, base), 0.0, 1.0)
	if variation != &"":
		fill_variation = variation
	if is_equal_approx(b, base_ratio) and is_equal_approx(t, total_ratio):
		queue_redraw()
		return
	base_ratio = b
	total_ratio = t
	queue_redraw()

## Whether any of it is the meal's.
func has_boost() -> bool:
	return total_ratio > base_ratio + 0.0001

func _draw() -> void:
	var whole := Rect2(Vector2.ZERO, size)
	var trough: StyleBox = get_theme_stylebox("background", "ProgressBar")
	if trough:
		draw_style_box(trough, whole)
	# The boost first, the whole length, and his own part over it: what shows of the gold is
	# exactly the meal's.
	if has_boost():
		var gold: StyleBox = get_theme_stylebox("fill", "BoostBar")
		if gold:
			draw_style_box(gold, Rect2(Vector2.ZERO, Vector2(size.x * total_ratio, size.y)))
	if base_ratio > 0.0:
		var own: StyleBox = get_theme_stylebox("fill", fill_variation)
		if own:
			draw_style_box(own, Rect2(Vector2.ZERO, Vector2(size.x * base_ratio, size.y)))
