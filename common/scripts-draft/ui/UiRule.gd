# res://scripts/ui/UiRule.gd
class_name UiRule
extends StyleBox

## A rule across a panel (HSeparator): a line of bone cut into the leather, fading out towards
## either end (Config.THEME.surfaces "rule"), and -- under a title -- a carved tooth at its middle
## ("ornament"): the one flourish a panel carries, kept where the eye already is.
##
## A StyleBox of its own because a nine-cut image puts whatever is in its middle piece at every
## repeat along it; the tooth has to be drawn once, at the middle of whatever width the rule is.

## The line, cut in nine and stretched along; drawn at its own height, centred on the rect.
var line: StyleBox = null
var line_height: float = 0.0
## The tooth at the middle, or null for a plain rule.
var ornament: Texture2D = null

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if line:
		var h: float = line_height if line_height > 0.0 else rect.size.y
		line.draw(to_canvas_item, Rect2(rect.position.x, rect.get_center().y - h * 0.5, rect.size.x, h))
	if ornament:
		var size: Vector2 = ornament.get_size()
		ornament.draw(to_canvas_item, (rect.get_center() - size * 0.5).round())
