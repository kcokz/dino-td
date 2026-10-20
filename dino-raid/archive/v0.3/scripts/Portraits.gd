class_name Portraits
## A picture for a card, taken in the game from the thing itself: a dinosaur side-on and facing the enemy, a
## building from above at a slant -- so every card looks alike, and a new one has its picture the moment it
## has a model.


static func take(owner: Node, scene: PackedScene, px := 160) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	owner.add_child(vp)

	var model := scene.instantiate() as Node3D
	model.rotation.y = -PI * 0.5 + 0.35
	vp.add_child(model)
	var box := Geo.bounds(model, model.transform)
	var side := maxf(box.size.x, box.size.y) * 1.08

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = side
	cam.position = box.get_center() + Vector3(0.0, 0.0, 60.0)
	cam.far = 200.0
	vp.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.8)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	return vp.get_texture()


## A picture of `model` (made for it, and kept by the picture), looked down on at `pitch` degrees.
static func take_node(owner: Node, model: Node3D, px := 160, pitch := 38.0) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	owner.add_child(vp)
	vp.add_child(model)
	var box := Geo.bounds(model, model.transform)
	var a := deg_to_rad(pitch)
	var tall := box.size.y * cos(a) + box.size.z * sin(a)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(box.size.x, tall) * 1.1
	cam.position = box.get_center() + Vector3(0.0, sin(a), cos(a)) * 60.0
	cam.rotation = Vector3(-a, 0.0, 0.0)
	cam.far = 200.0
	vp.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.8)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	return vp.get_texture()
