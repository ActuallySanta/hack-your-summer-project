class_name SoftCameraBoundary
extends Area2D

## A "soft" camera boundary for non-rectangular rooms.
##
## Attach this to an [Area2D] and give it one or more [CollisionPolygon2D] children.
## Each polygon marks a region of space the camera's visible rectangle must NOT
## overlap (i.e. the empty corners of a non-rectangular room that the rectangular
## "hard" bounds would otherwise expose). Concave polygons are supported.
##
## The boundary registers itself into the [constant GROUP] group on load, so the
## camera loop in game.gd discovers it automatically. Because it lives inside the
## room scene and MetSys only keeps the current room loaded, it needs no external
## wiring or bookkeeping to stay working.
##
## These are "soft" bounds: the camera obeys them as much as it can, but the
## rectangular hard bounds always win (see game.gd), so a soft bound can never
## push the view past a hard bound.

## Group that game.gd scans each frame to find the active boundaries.
const GROUP := &"soft_camera_boundary"

## How many push-out passes to run. Multiple passes let neighbouring convex
## pieces (from a concave polygon) resolve without the camera getting stuck.
const MAX_PASSES := 8

## How firmly the camera resists entering this region.
## [br]0.0 = soft: the push-out is fully smoothed, so the camera eases out of
## corners (and may briefly dip in during fast moves). This is the default and
## matches the original behaviour.
## [br]1.0 = rigid: the push-out is applied instantly, so the camera can never
## enter this region for any reason (short of the rectangular hard bounds, which
## always win). Values in between blend the two.
@export_range(0.0, 1.0, 0.05) var resistance := 0.0

## Cached convex pieces, in global space, of every child polygon.
var _convex_pieces: Array[PackedVector2Array] = []

## This boundary's own smoothed correction, eased toward the raw push-out each
## frame. Blended with the raw push-out by [member resistance].
var _smoothed_correction := Vector2.ZERO

func _ready() -> void:
	# We only need the polygons for geometry, not physics interactions.
	monitoring = false
	monitorable = false
	rebuild()
	add_to_group(GROUP)

## Rebuilds the cached convex pieces from the current [CollisionPolygon2D] children.
## Call this manually if a polygon is edited or the node is moved at runtime.
func rebuild() -> void:
	_convex_pieces.clear()
	for child in get_children():
		var col := child as CollisionPolygon2D
		if col == null or col.polygon.size() < 3:
			continue
		# Transform to global space first; an affine transform preserves convexity,
		# so decomposing afterwards is safe.
		var global_points := PackedVector2Array()
		for point in col.polygon:
			global_points.append(col.global_transform * point)
		for piece in Geometry2D.decompose_polygon_in_convex(global_points):
			if piece.size() >= 3:
				_convex_pieces.append(piece)

## Returns this boundary's correction (an offset to add to [param baseline_center])
## for this frame, already blended between smoothed (soft) and instant (rigid) by
## [member resistance]. [param baseline_center] is the hard-clamped camera centre;
## measuring from it keeps the result stateless and stable (no feedback jitter).
func get_correction(baseline_center: Vector2, half_view: Vector2, delta: float, soft_speed: float) -> Vector2:
	var raw := push_view_out(baseline_center, half_view) - baseline_center
	# Ease our own smoothed correction toward the raw push-out (frame-rate independent).
	var soft_t := 1.0 if soft_speed <= 0.0 else 1.0 - exp(-soft_speed * delta)
	_smoothed_correction = _smoothed_correction.lerp(raw, soft_t)
	# resistance = 0 -> use the smoothed (soft) value; 1 -> use the raw (instant) value.
	return _smoothed_correction.lerp(raw, resistance)

## Given a desired camera centre (global) and the camera's half view-size (world
## units), returns a centre nudged so the view rectangle no longer overlaps any
## forbidden region. Does not enforce the hard bounds; game.gd does that after.
func push_view_out(center: Vector2, half_view: Vector2) -> Vector2:
	var result := center
	for _pass in MAX_PASSES:
		var moved := false
		for piece in _convex_pieces:
			var mtv := _mtv_aabb_vs_convex(result, half_view, piece)
			if mtv != Vector2.ZERO:
				result += mtv
				moved = true
		if not moved:
			break
	return result

## Minimum translation vector that moves the axis-aligned view rectangle
## (centred at [param center], half-size [param half]) out of the convex polygon
## [param poly]. Returns [constant Vector2.ZERO] if they do not overlap.
func _mtv_aabb_vs_convex(center: Vector2, half: Vector2, poly: PackedVector2Array) -> Vector2:
	# SAT: test the rectangle's two axes plus every polygon edge normal. If any
	# axis separates the shapes there is no overlap; otherwise the smallest
	# overlap is the shortest way to push the rectangle out.
	var axes: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN]
	var count := poly.size()
	for i in count:
		var edge := poly[(i + 1) % count] - poly[i]
		if edge.length_squared() > 0.000001:
			axes.append(Vector2(edge.y, -edge.x).normalized())

	var min_overlap := INF
	var mtv := Vector2.ZERO
	for axis in axes:
		# Rectangle projects to a radius of |axis.x|*half.x + |axis.y|*half.y.
		var radius := absf(axis.x) * half.x + absf(axis.y) * half.y
		var rect_mid := axis.dot(center)
		var rect_min := rect_mid - radius
		var rect_max := rect_mid + radius

		var poly_min := INF
		var poly_max := -INF
		for v in poly:
			var d := axis.dot(v)
			poly_min = minf(poly_min, d)
			poly_max = maxf(poly_max, d)

		var overlap := minf(rect_max, poly_max) - maxf(rect_min, poly_min)
		if overlap <= 0.0:
			return Vector2.ZERO # separating axis found -> no collision
		if overlap < min_overlap:
			min_overlap = overlap
			# Push the rectangle to whichever side keeps it away from the polygon.
			var poly_mid := (poly_min + poly_max) * 0.5
			var dir := -1.0 if rect_mid < poly_mid else 1.0
			mtv = axis * dir * overlap
	return mtv
