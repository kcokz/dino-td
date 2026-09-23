class_name CameraRig
extends RefCounted

## Where the camera is standing, as four numbers instead of a transform.
##
## A building game lets you look at your base from wherever you like, and this one could
## only ever look at it from one bearing. That is not only a convenience: a fixed bearing
## HIDES THINGS. A stake is 0.95m and the cabin is 1.9m, so from the one angle the game
## offered, the near side of the cabin covered the ground behind it -- and a ring of
## stakes that is the same 0.523m from the cabin on all four sides read as flush on one
## side and a gap on the other. There was no way to look again from somewhere else.
##
## FOUR NUMBERS, NOT A TRANSFORM:
##
##   focus     the point on the ground the view is built around
##   yaw       which way round the compass it is looking from
##   tilt      how far above the horizon it is, in degrees (positive, 90 = straight down)
##   distance  how far back it sits
##
## Everything the player does is one of those four changing, which is why they are the
## state. A transform cannot be clamped sensibly -- "not closer than 8 metres" and "not
## tilted past 85 degrees" are statements about these numbers and nothing else -- and it
## cannot be reset, because there is nothing in a matrix that says where it came from.
##
## THE ENGINE HAS NO CAMERA CONTROLLER (rule 8 in AGENT-TASKS.md, and the reason it is
## named here): Camera3D is a viewpoint and Node3D is a transform, and what sits between
## them for a strategy game is arithmetic. There is nothing to reach for. What IS reached
## for is Camera3D.look_at, so no rotation is built by hand.

## The point on the ground the view is built around.
var focus: Vector3 = Vector3.ZERO
## Which way round the compass, in degrees.
var yaw: float = 0.0
## Degrees above the horizon: 90 looks straight down, 0 looks along the ground.
var tilt: float = 45.0
## Metres from the focus.
var distance: float = 25.0

## What `reset` goes back to, taken from the scene when the rig adopted the camera.
var _home: Dictionary = {}

## How far from the centre of the world the focus may go on either axis, in metres.
## INF until the level says otherwise, so a rig built on its own (a test) is unbounded.
##
## THE VIEW HAD NO EDGE. Holding an arrow key panned the focus off the end of the valley
## and into nothing, and it kept going for as long as the key was held. Bounded in the
## four numbers rather than on the camera's position, because the focus is the thing
## the player is moving -- clamping the camera would let the view slide while the camera
## stuck, which feels like the controls breaking.
var bounds_half: float = INF

## How high the ground is at a point, for keeping the camera out of the valley wall.
## Empty until the level provides one.
var ground_height: Callable = Callable()

func _init(cfg: Object = null) -> void:
	_cfg = cfg

var _cfg: Object = null

func _num(key: String, fallback: float) -> float:
	if _cfg != null and "CAMERA" in _cfg and _cfg.CAMERA is Dictionary:
		return float(_cfg.CAMERA.get(key, fallback))
	return fallback

# ==============================================================================
# Taking over a camera, and giving it back
# ==============================================================================

## Reads the four numbers off a camera already pointed somewhere.
##
## THE SCENE STILL DECIDES WHERE THE GAME OPENS. The framing is not a constant in Config:
## it is whatever scenes/Main.tscn has the Camera3D set to, read back here. So moving the
## camera in the editor still moves the opening shot, and "reset the view" means "back to
## what the scene said" rather than "back to a number somebody typed twice".
func adopt(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	var forward: Vector3 = -cam.global_transform.basis.z
	tilt = rad_to_deg(asin(clampf(-forward.y, -1.0, 1.0)))
	yaw = rad_to_deg(atan2(-forward.x, -forward.z))
	# Where that view meets the ground. A camera pointed at or above the horizon has no
	# ground point at all, so it gets a sane distance rather than an infinite one.
	var down: float = -forward.y
	distance = (cam.global_position.y / down) if down > 0.05 else _num("max_distance", 45.0)
	distance = clampf(distance, _num("min_distance", 8.0), _num("max_distance", 45.0))
	tilt = clampf(tilt, _num("min_tilt_degrees", 15.0), _num("max_tilt_degrees", 85.0))
	focus = cam.global_position + forward * distance
	focus.y = 0.0
	_home = {"focus": focus, "yaw": yaw, "tilt": tilt, "distance": distance}

## Puts the camera where the four numbers say.
func apply_to(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	var at: Vector3 = focus + offset()
	# Never inside the ground. Turning a zoomed-out, low view towards the valley wall
	# would otherwise put the camera in the hillside, looking at the inside of it.
	if ground_height.is_valid():
		var floor_y: float = float(ground_height.call(at.x, at.z)) + _num("ground_clearance", 2.5)
		if at.y < floor_y:
			at.y = floor_y
	cam.global_position = at
	# look_at rather than a hand-built basis: the one piece of this the engine does have.
	cam.look_at(focus, Vector3.UP)

## Where the camera sits relative to the focus.
func offset() -> Vector3:
	var back := Vector3(0.0, 0.0, 1.0)
	back = back.rotated(Vector3.RIGHT, deg_to_rad(-tilt))
	back = back.rotated(Vector3.UP, deg_to_rad(yaw))
	return back * distance

## Back to the view the scene opened on.
func reset() -> void:
	if _home.is_empty():
		return
	focus = _home["focus"]
	yaw = _home["yaw"]
	tilt = _home["tilt"]
	distance = _home["distance"]

func home() -> Dictionary:
	return _home.duplicate()

# ==============================================================================
# What the player does to it
# ==============================================================================

## How much faster things move when the camera is further out. Panning a metre per pixel
## is right at one zoom level and wrong at every other one; a base scrolled at a fixed
## rate crawls when you pull back to look at the whole map.
func _zoom_scale() -> float:
	var home_distance: float = float(_home.get("distance", distance)) if not _home.is_empty() else distance
	return distance / maxf(1.0, home_distance)

## Slides the view across the ground. `amount` is in the SCREEN's terms -- x is right, y
## is away -- and is turned into world movement by the current bearing, which is the
## whole reason it lives here: once the camera can turn, "press D to go right" has to
## mean right ON SCREEN or the controls stop making sense the moment you rotate.
func pan(amount: Vector2, metres: float) -> void:
	if amount == Vector2.ZERO:
		return
	var a: float = deg_to_rad(yaw)
	var right := Vector3(cos(a), 0.0, -sin(a))
	var away := Vector3(-sin(a), 0.0, -cos(a))
	focus += (right * amount.x + away * amount.y) * metres
	_keep_in_bounds()

## Holds the focus inside the world. A square, because the playfield is one.
func _keep_in_bounds() -> void:
	if is_inf(bounds_half):
		return
	focus.x = clampf(focus.x, -bounds_half, bounds_half)
	focus.z = clampf(focus.z, -bounds_half, bounds_half)

## Held-key panning, in metres per second at the opening distance.
func pan_keys(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	pan(direction.normalized(), _num("pan_speed", 18.0) * _zoom_scale() * delta)

## Dragging the view under the cursor, in metres per pixel at the opening distance.
func pan_drag(pixels: Vector2) -> void:
	pan(Vector2(-pixels.x, pixels.y), _num("drag_pan", 0.015) * _zoom_scale())

## Swings the view round the focus.
func rotate_by(degrees: float) -> void:
	yaw = wrapf(yaw + degrees, -180.0, 180.0)

## Raises or lowers the eye. Clamped short of straight down and short of the horizon:
## at 90 every silhouette is lost, and at 0 the ground plane disappears edge-on.
func tilt_by(degrees: float) -> void:
	tilt = clampf(tilt + degrees,
		_num("min_tilt_degrees", 15.0), _num("max_tilt_degrees", 85.0))

## Closer to or further from the focus. Positive is closer, so a wheel notch forward
## means "in", which is what every other game does.
func zoom_by(metres: float) -> void:
	distance = clampf(distance - metres,
		_num("min_distance", 8.0), _num("max_distance", 45.0))

## One wheel notch or one press of a zoom key.
func zoom_step(direction: float) -> void:
	zoom_by(_num("zoom_step", 2.2) * direction)

## Held-key turning and tilting, in degrees per second.
func rotate_keys(direction: float, delta: float) -> void:
	if direction != 0.0:
		rotate_by(_num("rotate_speed", 110.0) * direction * delta)

func tilt_keys(direction: float, delta: float) -> void:
	if direction != 0.0:
		tilt_by(_num("tilt_speed", 55.0) * direction * delta)

## Dragging to orbit, in degrees per pixel.
func orbit_drag(pixels: Vector2) -> void:
	rotate_by(-_num("drag_rotate", 0.35) * pixels.x)
	tilt_by(_num("drag_tilt", 0.25) * pixels.y)

## Moves the view onto something without changing how it is being looked at.
func look_at_point(where: Vector3) -> void:
	focus = Vector3(where.x, 0.0, where.z)
	_keep_in_bounds()
