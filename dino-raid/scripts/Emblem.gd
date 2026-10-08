class_name Emblem
extends Control
## The picture on a help card, drawn: meat and its smell, a noise, a drop of blood, the rings of a call, a
## cloud of ash.

var kind := ""


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	match kind:
		"scent":
			var meat := Color(0.6, 0.2, 0.15)
			draw_circle(c + Vector2(r * 0.12, r * 0.6), r * 0.34, meat)
			draw_circle(c + Vector2(-r * 0.22, r * 0.66), r * 0.26, meat.darkened(0.2))
			for k in 3:
				var smell := PackedVector2Array()
				for j in 12:
					var t := j / 11.0
					smell.append(c + Vector2((k - 1) * r * 0.42 + sin(t * TAU) * r * 0.1, r * 0.2 - t * r * 0.95))
				draw_polyline(smell, Color(0.88, 0.55, 0.45, 0.9), 3.0, true)
		"noise":
			var dust := Color(0.88, 0.8, 0.62)
			draw_circle(c, r * 0.2, dust)
			for k in 12:
				var a := TAU * k / 12.0
				var from := r * (0.36 if k % 2 == 0 else 0.5)
				draw_line(c + Vector2(cos(a), sin(a)) * from, c + Vector2(cos(a), sin(a)) * r, dust, 4.0 if k % 2 == 0 else 2.5, true)
		"blood":
			var drop := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				drop.append(c + Vector2(sin(t) * sin(t * 0.5) * r * 0.95, -cos(t) * r))
			draw_colored_polygon(drop, Color(0.62, 0.06, 0.05))
			draw_circle(c + Vector2(-r * 0.22, r * 0.3), r * 0.13, Color(1.0, 0.6, 0.55, 0.5))
		"call":
			var at := c + Vector2(-r * 0.7, 0.0)
			var gold := Color(0.95, 0.82, 0.45)
			draw_circle(at, r * 0.14, gold)
			for k in 3:
				draw_arc(at, r * (0.45 + 0.42 * k), -0.8, 0.8, 24, Color(gold, 1.0 - 0.25 * k), 4.0 + k, true)
		"ash":
			var grey := Color(0.55, 0.54, 0.52)
			for p in [Vector2(-0.45, 0.05), Vector2(0.0, -0.22), Vector2(0.45, 0.05), Vector2(-0.2, 0.2), Vector2(0.25, 0.22)]:
				draw_circle(c + p * r, r * 0.42, grey)
			for i in 7:
				var x := -0.6 + 0.2 * i
				draw_circle(c + Vector2(x * r, r * (0.85 + 0.12 * (i % 2))), r * 0.05, Color(0.3, 0.3, 0.3))
