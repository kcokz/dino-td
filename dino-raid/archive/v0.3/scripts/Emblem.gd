class_name Emblem
## The pictures on the help cards, drawn rather than photographed: meat and its smell, a noise, a drop of
## blood, the rings of a call, a cloud of ash, an egg cracking.


## Draws `kind`'s picture into `r` of `ci` (call from its _draw).
static func paint(ci: CanvasItem, kind: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.4
	match kind:
		"scent":
			var meat := Color(0.62, 0.2, 0.15)
			ci.draw_circle(c + Vector2(s * 0.15, s * 0.5), s * 0.36, meat)
			ci.draw_circle(c + Vector2(-s * 0.25, s * 0.58), s * 0.26, meat.darkened(0.25))
			ci.draw_circle(c + Vector2(s * 0.28, s * 0.38), s * 0.1, Color(0.95, 0.85, 0.8, 0.8))
			for k in 3:
				var smell := PackedVector2Array()
				for j in 14:
					var t := j / 13.0
					smell.append(c + Vector2((k - 1) * s * 0.42 + sin(t * TAU) * s * 0.11, s * 0.08 - t * s * 0.95))
				ci.draw_polyline(smell, Color(0.98, 0.72, 0.6, 0.95), 3.0, true)
		"noise":
			var dust := Color(0.97, 0.88, 0.66)
			ci.draw_circle(c, s * 0.2, dust)
			for k in 14:
				var a := TAU * k / 14.0
				var from := s * (0.34 if k % 2 == 0 else 0.48)
				ci.draw_line(c + Vector2(cos(a), sin(a)) * from, c + Vector2(cos(a), sin(a)) * s, dust,
					4.0 if k % 2 == 0 else 2.5, true)
		"blood":
			var drop := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				drop.append(c + Vector2(sin(t) * sin(t * 0.5) * s * 0.95, -cos(t) * s))
			ci.draw_colored_polygon(drop, Color(0.7, 0.06, 0.05))
			ci.draw_circle(c + Vector2(-s * 0.22, s * 0.3), s * 0.13, Color(1.0, 0.6, 0.55, 0.55))
		"call":
			var at := c + Vector2(-s * 0.7, 0.0)
			var gold := Color(1.0, 0.86, 0.5)
			ci.draw_circle(at, s * 0.15, gold)
			for k in 3:
				ci.draw_arc(at, s * (0.45 + 0.42 * k), -0.8, 0.8, 24, Color(gold, 1.0 - 0.25 * k), 4.0 + k, true)
		"ash":
			var grey := Color(0.66, 0.65, 0.63)
			for p in [Vector2(-0.45, 0.05), Vector2(0.0, -0.22), Vector2(0.45, 0.05), Vector2(-0.2, 0.2), Vector2(0.25, 0.22)]:
				ci.draw_circle(c + p * s, s * 0.42, grey)
			for i in 7:
				var x := -0.6 + 0.2 * i
				ci.draw_circle(c + Vector2(x * s, s * (0.85 + 0.12 * (i % 2))), s * 0.05, Color(0.25, 0.25, 0.25))
		"quicken":
			var egg := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0
				egg.append(c + Vector2(cos(a) * s * 0.55, sin(a) * s * 0.75 + (s * 0.08 if sin(a) > 0 else 0.0)))
			ci.draw_colored_polygon(egg, Color(0.95, 0.9, 0.78))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.05), c + Vector2(-s * 0.2, s * 0.12),
				c + Vector2(0.0, -s * 0.12), c + Vector2(s * 0.22, s * 0.1), c + Vector2(s * 0.52, -s * 0.06)]),
				Color(0.35, 0.22, 0.1), 2.5, true)
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.5
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.88, c + Vector2(cos(a), sin(a)) * s * 1.08,
					Color(1.0, 0.9, 0.5), 3.0, true)
