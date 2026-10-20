class_name Board
## Where the battle's tiles are in the world: TILE metres a side, the board centred on the origin, row 0 (our
## end) nearest the camera at +z, the robots' end far off at -z.

const TILE := 5.0
const NOWHERE := Vector2i(-1, -1)


static func world(p: Vector2i) -> Vector3:
	return Vector3((p.x - (Rules.COLS - 1) * 0.5) * TILE, 0.0, ((Rules.ROWS - 1) * 0.5 - p.y) * TILE)


## The tile under a point on the ground, or NOWHERE.
static func tile(at: Vector3) -> Vector2i:
	var x := floori(at.x / TILE + Rules.COLS * 0.5)
	var y := floori(Rules.ROWS * 0.5 - at.z / TILE)
	var p := Vector2i(x, y)
	return p if x >= 0 and x < Rules.COLS and y >= 0 and y < Rules.ROWS else NOWHERE


## The board's corner nearest -x, -z, and its size, on the ground.
static func rect() -> Rect2:
	return Rect2(-Rules.COLS * TILE * 0.5, -Rules.ROWS * TILE * 0.5, Rules.COLS * TILE, Rules.ROWS * TILE)
