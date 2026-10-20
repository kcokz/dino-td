class_name Geo
## Small geometry helpers shared by the scenes.


## The bounds of everything visible under `node`, in `node`'s own space.
static func bounds(node: Node, xf: Transform3D = Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var first := true
	if node is VisualInstance3D:
		box = xf * (node as VisualInstance3D).get_aabb()
		first = false
	for child in node.get_children():
		var child_xf := xf * (child as Node3D).transform if child is Node3D else xf
		var b := bounds(child, child_xf)
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


## Where the camera's ray through a screen point meets the ground (y = 0), or null.
static func ground_point(camera: Camera3D, screen: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t


## Flat distance on the ground between two points.
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
