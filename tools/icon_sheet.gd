# res://tools/icon_sheet.gd
#
# Every icon in assets/icons on one sheet, at the sizes the interface draws them and on a
# dark and a light ground, so they are judged where they will be seen (UI-POLISH T17).
#
#   godot --path . --script res://tools/icon_sheet.gd
#
# Writes screenshots/icon_sheet.png. Not a test: it asserts nothing.
extends SceneTree

const SIZES: Array[int] = [20, 32, 56]

func _init() -> void:
	await process_frame
	var names: Array[String] = []
	var dir := DirAccess.open("res://assets/icons")
	for f in dir.get_files():
		if f.ends_with(".svg"):
			names.append(f.get_basename())
	names.sort()
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var cell := Vector2(120, 170)
	var cols: int = 10
	for half in range(2):
		var ground := ColorRect.new()
		ground.color = Color(0.07, 0.098, 0.114) if half == 0 else Color(0.62, 0.66, 0.52)
		ground.position = Vector2(0, half * (cell.y * ceili(float(names.size()) / cols)))
		ground.size = Vector2(cell.x * cols, cell.y * ceili(float(names.size()) / cols))
		canvas.add_child(ground)
		for i in range(names.size()):
			var origin := ground.position + Vector2((i % cols) * cell.x, (i / cols) * cell.y)
			var tex: Texture2D = load("res://assets/icons/%s.svg" % names[i])
			var x: float = 6.0
			for s in SIZES:
				var r := TextureRect.new()
				r.texture = tex
				r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				r.position = origin + Vector2(x, 10 + (56 - s))
				r.size = Vector2(s, s)
				canvas.add_child(r)
				x += s + 4
			var l := Label.new()
			l.text = names[i]
			l.position = origin + Vector2(6, 120)
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", Color.WHITE if half == 0 else Color.BLACK)
			canvas.add_child(l)
	for i in range(8):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/icon_sheet.png")
	print("[icon_sheet] %d icons -> screenshots/icon_sheet.png" % names.size())
	quit()
