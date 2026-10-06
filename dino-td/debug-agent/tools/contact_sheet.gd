# Tiles a run's frames into contact sheets (2 columns x 3 rows), so a run is read in a few images.
#   godot --headless --path . --script res://debug-agent/tools/contact_sheet.gd -- <frames dir> <out prefix> [tile width]
# Frames are taken in file-name order: sheet N holds frames 6N..6N+5, left to right, top to bottom.
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1]
	var w: int = int(args[2]) if args.size() > 2 else 900
	var files: Array = []
	for f in DirAccess.get_files_at(src):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	var cols := 2
	var per := 6
	for page in range(0, files.size(), per):
		var tiles: Array = []
		for f in files.slice(page, page + per):
			var im := Image.load_from_file(src.path_join(f))
			im.convert(Image.FORMAT_RGB8)
			im.resize(w, int(im.get_height() * w / float(im.get_width())), Image.INTERPOLATE_BILINEAR)
			tiles.append(im)
		var h: int = 0
		for t in tiles:
			h = maxi(h, t.get_height())
		var rows: int = (tiles.size() + cols - 1) / cols
		var sheet := Image.create(cols * w, rows * h, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			var t: Image = tiles[i]
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i((i % cols) * w, (i / cols) * h))
		var path := "%s_%02d.png" % [out, page / per]
		sheet.save_png(path)
		print("%s  <- %s" % [path, ", ".join(files.slice(page, page + per))])
	quit(0)
