extends SceneTree
## tools/render_portraits.gd -- a portrait of everything the command card and a bench can show,
## rendered from its own model.
##
##   godot --path . --script res://tools/render_portraits.gd [-- hero building/wall ...]
##
## (Not --headless: it needs the renderer, as tools/playtest.gd does.)
##
## v0.6: "还是没到优秀游戏的质感". A good RTS puts the unit itself in its panel -- turned a
## little towards you, lit like a studio shot, standing out of the dark of its frame -- where
## this one had a flat icon. So each model Config.VISUALS declares for Config.PORTRAITS'
## kinds is made the way the game makes it (VisualLibrary.make: its model, fitted to its
## size), posed (the Hero in his idle clip, not his rig's T), and photographed on a stage of
## its own: a warm key from the upper left -- where the interface's own light comes from --
## a cool fill, and a rim of light from behind that lifts its silhouette off the dark socket
## it is shown in. The background is left clear; the socket is the backdrop.
##
## How big a portrait is and where it goes are Config's (PORTRAITS); how each subject is
## framed is here, as a model's look is in tools/generate_props.py.
##
## The same stage renders each material's icon from the pile the game drops of it
## (Config.RENDERED_ICONS): seen from above, small, and ringed with a dark edge -- as the drawn
## icons are -- so it reads at the size of a price.

## How much bigger a portrait is rendered than it is saved: edges smoothed by shrinking.
const SUPERSAMPLE := 2
## A long lens, as for a portrait: little distortion, the subject filling the frame.
const FOV := 26.0
## Frames it waits for a stage to draw -- shaders compile on the first.
const SETTLE := 8

## How each kind of subject is framed: the view's turn about it (yaw, degrees, from the front
## the game's own camera looks at), how far above it looks down (pitch), and how much room is
## left round it. "bust" frames the top of a figure -- head and shoulders -- between "from"
## and "to" (shares of its height) rather than all of it.
const FRAMING := {
	"hero": {"mode": "bust", "from": 0.7, "to": 1.03, "yaw": 200.0, "pitch": -4.0, "room": 1.0},
	"building": {"mode": "whole", "yaw": 32.0, "pitch": -24.0, "room": 0.94},
	"node": {"mode": "whole", "yaw": 32.0, "pitch": -20.0, "room": 1.04},
	"station": {"mode": "whole", "yaw": 20.0, "pitch": -16.0, "room": 0.92},
	"drop": {"mode": "whole", "yaw": 35.0, "pitch": -40.0, "room": 0.84},
	# An animal by its head (the sculpted cast, tools/triassic_bodies.py): framed round its Head bone, posed,
	# `centre` of the way from the bone to its end's, `span` head-lengths about it; seen from `yaw` degrees
	# round from its side towards its front.
	"dino": {"mode": "head", "centre": 0.5, "span": 0.62, "yaw": 48.0, "pitch": -8.0, "room": 1.0},
}
## A subject framed otherwise than its kind.
const FRAMING_FOR := {
	# A snout a skull and more long, the eyes at its back.
	"dino/phytosaur": {"mode": "head", "centre": 0.55, "span": 0.85, "yaw": 42.0, "pitch": -14.0, "room": 1.0},
	"dino/hesperosuchus": {"mode": "head", "centre": 0.45, "span": 0.6, "yaw": 46.0, "pitch": -8.0, "room": 1.0},
	"node/wood": {"mode": "bust", "from": 0.35, "to": 1.02, "yaw": 32.0, "pitch": -14.0, "room": 1.0},
	# A rock is wide and low: framed round it, not round the sphere that holds it.
	"node/stone": {"mode": "whole", "yaw": 32.0, "pitch": -20.0, "room": 0.82},
}

## A subject drawn in another colour than its model's: a boss's cut is the haunch the game drops
## for meat, and only its colour sets it apart -- darker and richer (Config.RESOURCE_COLORS).
const TINT_FOR := {
	"drop/prime_meat": Color(0.8, 0.42, 0.5),
}

func _init() -> void:
	await process_frame      # the autoloads, Config among them, join the tree first
	var cfg: Node = root.get_node("Config")
	var spec: Dictionary = cfg.PORTRAITS
	var px: int = int(spec["size"]) * int(spec["scale"])
	var dir: String = String(spec["dir"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	for key in cfg.VISUALS:
		var k: String = String(key)
		if not Array(spec["kinds"]).has(k.get_slice("/", 0)):
			continue
		if not wanted.is_empty() and not wanted.has(k):
			continue
		var img: Image = await _render(k, px)
		var path: String = dir + k.replace("/", "_") + ".png"
		img.save_png(path)
		print("[portrait] ", path, " ", img.get_size())
	var icons: Dictionary = cfg.RENDERED_ICONS
	var ipx: int = int(icons["size"]) * int(icons["scale"])
	var idir: String = String(icons["dir"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(idir))
	for key in cfg.VISUALS:
		var k: String = String(key)
		if not Array(icons["kinds"]).has(k.get_slice("/", 0)):
			continue
		if not wanted.is_empty() and not wanted.has(k):
			continue
		var img: Image = await _render(k, ipx)
		img = _outlined(img, float(icons["edge"]) * float(icons["scale"]))
		var path: String = idir + k.get_slice("/", 1) + ".png"
		img.save_png(path)
		print("[icon] ", path, " ", img.get_size())
	quit()

## `img` ringed with a dark edge `width` pixels wide, round its silhouette: what lets an icon
## read on a pale card and a dark strip alike.
func _outlined(img: Image, width: float) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var reach: int = int(ceil(width))
	var ink := Color(0.07, 0.05, 0.04)
	for y in h:
		for x in w:
			var near: float = 0.0
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var sx: int = x + dx
					var sy: int = y + dy
					if sx < 0 or sy < 0 or sx >= w or sy >= h:
						continue
					var dist: float = Vector2(dx, dy).length()
					if dist > width + 0.5:
						continue
					var cover: float = clampf(width + 0.5 - dist, 0.0, 1.0)
					near = maxf(near, img.get_pixel(sx, sy).a * cover)
			var c: Color = img.get_pixel(x, y)
			var a: float = c.a + near * (1.0 - c.a)
			if a <= 0.0:
				continue
			var rgb: Color = (c * c.a + ink * near * (1.0 - c.a)) / a
			out.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))
	return out

func _framing(key: String) -> Dictionary:
	return FRAMING_FOR.get(key, FRAMING.get(key.get_slice("/", 0), FRAMING["building"]))

func _render(key: String, px: int) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(px, px) * SUPERSAMPLE
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.4, 0.37)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)

	var subject: Node3D = VisualLibrary.make(key)
	if TINT_FOR.has(key):
		for node in subject.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var tinted := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				tinted.albedo_color *= Color(TINT_FOR[key])
				mi.material_override = tinted
	view.add_child(subject)
	_pose(subject)
	await process_frame
	var box: AABB = VisualLibrary.visual_bounds(subject)
	var frame: Dictionary = _framing(key)
	var height: float = maxf(box.size.y, 0.01)
	var region := box
	if String(frame["mode"]) == "bust":
		# A figure's rest shape can be as wide as it is tall (the Hero's rig stands in a T), so
		# a bust is framed by height alone, over his middle.
		var low: float = box.position.y + height * float(frame["from"])
		var high: float = box.position.y + height * float(frame["to"])
		var side: float = high - low
		var mid := box.get_center()
		region = AABB(Vector3(mid.x - side * 0.5, low, mid.z - side * 0.5), Vector3(side, side, side))
	var target: Vector3 = region.get_center()
	var radius: float = region.size.length() * 0.5
	if String(frame["mode"]) == "bust":
		radius = region.size.y * 0.5 * 1.15
	var yaw: float = float(frame["yaw"])
	var head: Dictionary = _head_of(subject, float(frame.get("centre", 0.45))) if String(frame["mode"]) == "head" else {}
	if not head.is_empty():
		target = head["centre"]
		radius = float(head["length"]) * float(frame.get("span", 1.0))
		# Round from its side towards its front: the side facing the camera's +Z.
		var fwd: Vector3 = head["forward"]
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		var look: Vector3 = side * cos(deg_to_rad(yaw)) + fwd * sin(deg_to_rad(yaw))
		yaw = rad_to_deg(atan2(look.x, look.z))
	var distance: float = radius / sin(deg_to_rad(FOV * 0.5)) * float(frame["room"])

	# The stage turns with the view, so every subject is lit alike whichever way it is seen.
	var rig := Node3D.new()
	rig.position = target
	rig.rotation_degrees.y = yaw
	view.add_child(rig)
	var pitch: float = deg_to_rad(float(frame["pitch"]))
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = maxf(0.01, distance * 0.05)
	cam.far = distance * 10.0
	rig.add_child(cam)
	cam.position = Vector3(0.0, -sin(pitch) * distance, cos(pitch) * distance)
	cam.look_at(target)
	cam.current = true
	_light(rig, target, Vector3(-1.1, 1.3, 1.0), Color(1.0, 0.92, 0.8), 1.35, true)    # key, upper left
	_light(rig, target, Vector3(1.3, 0.35, 0.7), Color(0.62, 0.72, 0.88), 0.4, false)  # fill, cool
	_light(rig, target, Vector3(0.5, 1.1, -1.4), Color(1.0, 0.95, 0.85), 1.7, false)   # rim, behind

	for i in SETTLE:
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	view.queue_free()
	await process_frame
	return img

## An animal's head, posed: `centre` of the way from its Head bone to its end's, which way it points, and
## how long it is -- or empty, for what has no head bone.
func _head_of(subject: Node, centre: float) -> Dictionary:
	for node in subject.find_children("*", "Skeleton3D", true, false):
		var sk := node as Skeleton3D
		var h: int = sk.find_bone("Head")
		var e: int = sk.find_bone("Head_end")
		if h < 0 or e < 0:
			continue
		var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(h).origin
		var b: Vector3 = sk.global_transform * sk.get_bone_global_pose(e).origin
		return {"centre": a.lerp(b, centre), "forward": (b - a).normalized(), "length": a.distance_to(b)}
	return {}

## A directional light shining from `from` (in the stage's own turn) onto the subject.
func _light(rig: Node3D, target: Vector3, from: Vector3, colour: Color, energy: float, shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.shadow_enabled = shadow
	rig.add_child(light)
	light.position = from.normalized()
	light.look_at(target)

## Posed as the game shows it: the first clip that is an idle, a little way in. A rig's rest
## pose is a T nobody sees in play.
func _pose(subject: Node) -> void:
	for node in subject.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		var clip: String = ""
		for name in player.get_animation_list():
			if String(name).to_lower().contains("idle"):
				clip = String(name)
				break
		if clip == "" and not player.get_animation_list().is_empty():
			clip = String(player.get_animation_list()[0])
		if clip != "":
			player.play(clip)
			player.seek(0.6, true)
			player.pause()
