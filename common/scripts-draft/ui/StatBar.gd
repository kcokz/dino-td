# res://scripts/ui/StatBar.gd
class_name StatBar
extends Control

## One of his stats on his sheet (OptionPanel): how much of it he has, as a share of the bar, in the
## stat's own colour. It was a bar in three parts while meals and armour raised his health past his
## own (v0.6 round two); since v0.7 nothing does (GAME-DESIGN 3.0: the healing pod mends him, it does
## not raise him).
##
## Drawn with the theme's own trough and pigments (UiTheme: the ProgressBar's background, a bar
## variation's fill), so it is the same object as every other bar in the interface.

## How far it reaches, 0..1 of the bar.
var base_ratio: float = 0.0
## The bar variation it is painted as (UiTheme: HealthBar, WarnBar, ...).
var fill_variation: StringName = &"HealthBar"

func _init() -> void:
	custom_minimum_size = Vector2(0, UiTheme.thickness("bar"))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Sets how far it reaches, as a share of the bar, and what it is painted as.
func set_values(base: float, variation: StringName = &"") -> void:
	if variation != &"":
		fill_variation = variation
	base_ratio = clampf(base, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var whole := Rect2(Vector2.ZERO, size)
	var trough: StyleBox = get_theme_stylebox("background", "ProgressBar")
	if trough:
		draw_style_box(trough, whole)
	if base_ratio > 0.0:
		var own: StyleBox = get_theme_stylebox("fill", fill_variation)
		if own:
			draw_style_box(own, Rect2(Vector2.ZERO, Vector2(size.x * base_ratio, size.y)))
