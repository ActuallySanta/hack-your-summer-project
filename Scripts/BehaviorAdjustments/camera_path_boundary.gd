class_name CameraPathBoundary
extends Area2D

## Confines the camera's CENTRE point to an allowed region for non-rectangular rooms.
##
## Attach this to an [Area2D] with a single [CollisionPolygon2D] child. The polygon
## describes where the camera's centre is allowed to be; each frame the desired
## centre is projected to the nearest allowed point. Because projecting a point to
## a region is non-expansive, this can never amplify jitter the way a rectangle
## push-out can around corners.
##
## Unlike the room outline, you draw this INSET from the walls by roughly half a
## screen (the centre can't reach a wall without the view spilling past it), so it
## is less intuitive to author, but very stable.
##
## A single polygon represents both cases:
## [br]- Shape (the polygon has area): the centre may sit anywhere inside it; if it
## strays out it snaps to the edge.
## [br]- Line (a 2-point segment, collinear points, or a single point — i.e. zero
## area): the centre is locked to that segment/point. Use this for corridors where
## the camera should only scroll along one axis, or a fully fixed camera.
##
## The rectangular hard bounds still win (enforced in game.gd), so this can never
## expose out-of-room space.

## Group that game.gd scans each frame to find the active path boundaries.
const GROUP := &"camera_path_boundary"

## Polygons whose |area| is below this (pixels^2) are treated as a line/point.
const LINE_AREA_EPSILON := 1.0

## Cached polygon points in global space.
var _points: PackedVector2Array = PackedVector2Array()

## True when the polygon has no usable area, so it acts as a line/point.
var _is_line := true

func _ready() -> void:
	# We only need the polygon for geometry, not physics interactions.
	monitoring = false
	monitorable = false
	rebuild()
	add_to_group(GROUP)

## Rebuilds the cached points from the first [CollisionPolygon2D] child.
## Call this manually if the polygon is edited or the node is moved at runtime.
func rebuild() -> void:
	_points = PackedVector2Array()
	_is_line = true
	for child in get_children():
		var col := child as CollisionPolygon2D
		if col == null or col.polygon.size() < 1:
			continue
		for point in col.polygon:
			_points.append(col.global_transform * point)
		break # single polygon per room
	_is_line = _points.size() < 3 or absf(_polygon_area(_points)) < LINE_AREA_EPSILON

## Returns the desired camera centre projected into the allowed region.
func constrain_center(center: Vector2) -> Vector2:
	if _points.is_empty():
		return center
	if _points.size() == 1:
		return _points[0]
	# A filled shape allows anything inside it; only project when outside.
	if not _is_line and Geometry2D.is_point_in_polygon(center, _points):
		return center
	return _closest_point_on_edges(center)

## Closest point to [param p] on any of the polygon's edges (treated as closed;
## for a line/point the degenerate edges collapse onto the segment harmlessly).
func _closest_point_on_edges(p: Vector2) -> Vector2:
	var best := _points[0]
	var best_dist := INF
	var count := _points.size()
	for i in count:
		var a := _points[i]
		var b := _points[(i + 1) % count]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_squared_to(q)
		if d < best_dist:
			best_dist = d
			best = q
	return best

## Signed area of the polygon via the shoelace formula.
func _polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	var count := poly.size()
	for i in count:
		var p1 := poly[i]
		var p2 := poly[(i + 1) % count]
		area += p1.x * p2.y - p2.x * p1.y
	return area * 0.5
