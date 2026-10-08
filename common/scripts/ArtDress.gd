class_name ArtDress
## Puts the right material on the shared art. Ported from dino-td's VisualLibrary._dress and GroundCover.
##
## THE PLANTS AND PROPS ARE COLOURED BY THEIR VERTICES (common/tools/generate_flora.py, generate_props.py),
## and a GLB brought in as a scene keeps the material the importer gave it -- which does not use vertex colour
## as albedo: the plant stands white. The dinosaurs' skins are baked to images and keep their own materials,
## but their eyes are coloured by vertices too, so those surfaces are only told to read them.


## A plant: its own vertex colours, lit through from behind, drawn from both sides.
static func flora(art: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	mat.backlight_enabled = true
	mat.backlight = Color(0.22, 0.30, 0.10)
	_override(art, mat)


## A prop: its own vertex colours, matte. A part made to glow keeps its own lit material.
static func prop(art: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	_override(art, mat)


## A dinosaur (or anything textured): every surface that has vertex colours is told to read them. The
## materials are the model's own, shared by every copy -- told once, told for all.
static func read_vertex_colours(art: Node) -> void:
	for mi: MeshInstance3D in _meshes(art):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			if (mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) == 0:
				continue
			var sm := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if sm != null and not sm.vertex_color_use_as_albedo:
				sm.vertex_color_use_as_albedo = true


static func _override(art: Node, mat: Material) -> void:
	for mi: MeshInstance3D in _meshes(art):
		if not _glows(mi):
			mi.material_override = mat


static func _glows(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	for i in mi.mesh.get_surface_count():
		var sm := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if sm != null and sm.emission_enabled:
			return true
	return false


static func _meshes(art: Node) -> Array:
	var found: Array = art.find_children("*", "MeshInstance3D", true, false)
	if art is MeshInstance3D:
		found.append(art)
	return found
