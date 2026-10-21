extends SceneTree
## The 3D models each painting is drawn over (tools/paint_cards.py): every card's subject -- each building (a nest with
## the creature it hatches), the raise, each affix on a red raptor -- every creature of ours, every monster, every
## wonder, photographed as the card pictures are (Portraits) but large, on a clear background, each saved as
## <key>.png in the folder given. Args: <out dir> [keys...] (none: all of them)
##
##   Godot --path dino-raid --script res://tools/paint_sources.gd -- C:/Users/jobzk/ai/src

var out := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var keys: Array = args.slice(1)
	if keys.is_empty():
		for kind in Content.BUILDINGS:
			keys.append("b:%s:1::" % kind)
		keys.append("raise")
		for a in Content.AFFIXES:
			keys.append("a:" + a)
		for kind in Content.UNITS:
			keys.append("u:" + kind)
		for kind in Content.ENEMIES:
			keys.append("e:" + kind)
		for id in Content.WONDERS:
			keys.append("w:" + id)
	_go(keys)


func _go(keys: Array) -> void:
	var p := Portraits.new()
	root.add_child(p)
	await process_frame
	p._vp.size = Vector2i(1216, 800)
	p._vp.msaa_3d = Viewport.MSAA_8X
	for key: String in keys:
		var node: Node3D = p._model(key)
		if node == null:
			print("SKIP ", key)
			continue
		p._stage.add_child(node)
		p._frame(node)
		p._vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := p._vp.get_texture().get_image()
		var file := key.replace(":", "_").trim_suffix("__").trim_suffix("_")
		img.save_png("%s/%s.png" % [out, file])
		print("shot ", file)
		node.queue_free()
		await process_frame
	quit()
