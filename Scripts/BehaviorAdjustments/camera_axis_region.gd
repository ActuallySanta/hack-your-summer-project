@tool
class_name CameraAxisRegion
extends Area2D

## A polygon region that locks the camera to one axis and eases it onto the
## region's centre line on the other.
##
## Add this to a room, give it one or more [CollisionPolygon2D] children, and draw
## the polygon over the part of the room the effect should cover. The polygon may
## stick out past the room's geometry (a triangular "feeler" poking into the next
## cell is the usual trick) so the camera starts correcting before the player is
## actually in the corridor.
##
## While a region holds control:
## [br]- The [b]preserved[/b] axis follows the player as normal.
## [br]- The [b]locked[/b] axis (the other one) eases from wherever the camera was
## when control began to the region's centre line, reaching it after
## [code]1.0 / centering_rate[/code] seconds no matter how far it had to travel.
## A camera that is already centred therefore doesn't move at all, and one with a
## lot of ground to make up simply moves faster.
##
## The polygon is assumed to be symmetrical about the preserved axis, so the
## centre line is taken from the polygon's bounding box. Override it with
## [member use_center_override] if that isn't true.
##
## [b]Taking control.[/b] Being inside the polygon only makes a region a candidate.
## It actually takes control when the player is inside it [i]and[/i] moving in one
## of its [member claim_directions]. That is what keeps a feeler from grabbing the
## camera when the player only brushes through it: walking back out, or straight
## across, never matches a claim direction, so nothing happens. Once a region has
## control it keeps it until the player leaves its polygon or another region
## claims, regardless of which way the player then moves.
##
## So [member claim_directions] should list the ways a player can enter this
## region [i]meaning it[/i]. For a left-hand corridor whose feeler pokes right into
## a big room, that is just Left. For two regions meeting at the corner of an
## L-shaped shaft, the vertical one takes Left and Down while the horizontal one
## takes Up and Right, so each corner approach hands over to the right one.
##
## The rectangular hard bounds from [method RoomInstance.adjust_camera_limits] are
## still applied afterwards in game.gd, so a region can never scroll the view past
## the edge of the room.

## Group that game.gd scans each frame to find the active regions.
const GROUP := &"camera_axis_region"

## Bit values for [member claim_directions], matching the export flag order.
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 4
const DIR_DOWN := 8

## The axis the camera keeps following the player on. The other axis is the one
## eased onto this region's centre line.
enum PreservedAxis {
	HORIZONTAL, ## Follow the player left/right; centre the camera vertically.
	VERTICAL, ## Follow the player up/down; centre the camera horizontally.
}

@export var preserved_axis := PreservedAxis.HORIZONTAL:
	set(value):
		preserved_axis = value
		if Engine.is_editor_hint():
			queue_redraw()

## Which movement directions let this region take control of the camera. See the
## class notes: these are the directions a player travels when they enter this
## region on purpose. Leaving this empty disables the region.
@export_flags("Left", "Right", "Up", "Down") var claim_directions := DIR_LEFT | DIR_RIGHT | DIR_UP | DIR_DOWN

## How quickly the camera slides onto the centre line, in "centrings per second":
## the move always completes in [code]1.0 / centering_rate[/code] seconds, so a
## bigger gap is covered at a proportionally higher speed. 1.0 is a leisurely one
## second; raise it to snap into place, lower it to drift.
@export_range(0.1, 8.0, 0.05, "or_greater") var centering_rate := 1.5

## Rate used when handing the locked axis back to normal following after the
## player leaves. 0 or less reuses [member centering_rate].
@export_range(0.0, 8.0, 0.05, "or_greater") var release_rate := 0.0

## Movement below this speed (pixels/second) doesn't count as travelling in a
## direction, so standing still never claims the camera.
@export_range(0.0, 200.0, 1.0, "or_greater") var movement_deadzone := 8.0

## Breaks ties when the player is inside more than one region that could claim
## the camera on the same frame. Higher wins.
@export var claim_priority := 0

@export_group("Centre Line")
## Use [member center_override] instead of the polygon's bounding-box centre.
## Only needed when the polygon isn't symmetrical about the preserved axis.
@export var use_center_override := false:
	set(value):
		use_center_override = value
		if Engine.is_editor_hint():
			queue_redraw()

## Global coordinate of the centre line on the locked axis: a Y value for a
## horizontal region, an X value for a vertical one.
@export var center_override := 0.0:
	set(value):
		center_override = value
		if Engine.is_editor_hint():
			queue_redraw()

## Cached polygons in global space, one entry per [CollisionPolygon2D] child.
var _polygons: Array[PackedVector2Array] = []

## Bounding box of every cached polygon, in global space.
var _bounds := Rect2()

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		return
	# The region is pure geometry; game.gd point-tests it rather than relying on
	# physics callbacks, so overlaps stay correct across teleports and respawns.
	monitoring = false
	monitorable = false
	rebuild()
	add_to_group(GROUP)

## Rebuilds the cached polygons from the current [CollisionPolygon2D] children.
## Call this if a polygon is edited or the node is moved at runtime.
func rebuild() -> void:
	_polygons.clear()
	_bounds = Rect2()
	var first := true
	for child in get_children():
		var col := child as CollisionPolygon2D
		if col == null or col.polygon.size() < 3:
			continue
		var points := PackedVector2Array()
		for point in col.polygon:
			var global_point: Vector2 = col.global_transform * point
			points.append(global_point)
			if first:
				_bounds = Rect2(global_point, Vector2.ZERO)
				first = false
			else:
				_bounds = _bounds.expand(global_point)
		_polygons.append(points)

## The axis index the camera is centred on: 0 for X, 1 for Y.
func get_locked_axis() -> int:
	return 1 if preserved_axis == PreservedAxis.HORIZONTAL else 0

## Global coordinate the locked axis is eased toward.
func get_center_value() -> float:
	if use_center_override:
		return center_override
	var axis := get_locked_axis()
	return _bounds.position[axis] + _bounds.size[axis] * 0.5

## Rate to use when handing the locked axis back to normal following.
func get_release_rate() -> float:
	return release_rate if release_rate > 0.0 else centering_rate

## Whether [param point] (global) is inside any of this region's polygons.
func contains_point(point: Vector2) -> bool:
	# Grown by a pixel because Rect2.has_point() excludes the far edges, and a
	# player standing exactly on the polygon's boundary should still count.
	if not _bounds.grow(1.0).has_point(point):
		return false
	for polygon in _polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false

## Whether [param movement] (global pixels/second) is one of the directions that
## lets this region take control.
func accepts_movement(movement: Vector2) -> bool:
	if claim_directions == 0:
		return false
	if movement.x < -movement_deadzone and claim_directions & DIR_LEFT:
		return true
	if movement.x > movement_deadzone and claim_directions & DIR_RIGHT:
		return true
	if movement.y < -movement_deadzone and claim_directions & DIR_UP:
		return true
	if movement.y > movement_deadzone and claim_directions & DIR_DOWN:
		return true
	return false

#region Editor preview
func _process(_delta: float) -> void:
	# The centre line follows the polygon as it is dragged, so keep it fresh while
	# authoring. Editor-only: _ready() never enables processing in game.
	if Engine.is_editor_hint():
		rebuild()
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or _polygons.is_empty():
		return
	# Draw the centre line the camera will be pulled onto, spanning the polygon.
	var color := Color(0.4, 0.9, 1.0, 0.85)
	var center := get_center_value()
	var from: Vector2
	var to: Vector2
	if preserved_axis == PreservedAxis.HORIZONTAL:
		from = Vector2(_bounds.position.x, center)
		to = Vector2(_bounds.end.x, center)
	else:
		from = Vector2(center, _bounds.position.y)
		to = Vector2(center, _bounds.end.y)
	var inv := global_transform.affine_inverse()
	draw_line(inv * from, inv * to, color, 3.0)
#endregion
