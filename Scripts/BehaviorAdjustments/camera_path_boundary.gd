@tool
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

## Polygons whose |area| are below this (pixels^2) are treated as a line/point.
const LINE_AREA_EPSILON := 1.0

## Half-width (as a fraction of the smaller cell dimension) given to 1-cell-wide
## corridors when auto-generating. A single polygon can't be a true line in one
## place and an area (corner triangles) in another, so corridors get a hair of
## width; the camera centre still effectively rides the centreline.
const CORRIDOR_WIDTH_FACTOR := 0

## Editor button: rebuilds the child polygon from this room's MetSys cell layout.
## Assigned in _enter_tree so a stale serialized null can't leave it Nil.
@export_tool_button("Generate From Room Cells") var _generate_button: Callable

## Cached polygon points in global space.
var _points: PackedVector2Array = PackedVector2Array()

## True when the polygon has no usable area, so it acts as a line/point.
var _is_line := true

func _enter_tree() -> void:
	# Bind the tool button here so it is always a valid Callable when clicked.
	if Engine.is_editor_hint():
		_generate_button = generate_from_cells

func _ready() -> void:
	if Engine.is_editor_hint():
		return
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

#region Auto-generation from MetSys cells
## Editor tool: rebuilds the child polygon from this room's MetSys cell layout,
## following these rules (see the class notes for the trade-offs):
## [br]- A single cell becomes a point; a straight 1-wide room becomes a line.
## [br]- Rectangular blocks become the rectangle spanning their corner-cell centres.
## [br]- Turns (L-corners) get a right triangle cutting the corner, with a spare
## vertex at the hypotenuse midpoint for manual tweaking.
## [br]- T/cross junctions become a diamond through the neighbour-cell centres.
## [br]Assumes simply-connected rooms (no "donut" cell around an empty middle).
func generate_from_cells() -> void:
	if not Engine.is_editor_hint():
		return
	var cells := _read_room_cells()
	if cells.is_empty():
		push_warning("CameraPathBoundary: no MetSys cells for this room. Save the scene and assign it on the map first.")
		return

	var cell_size: Vector2 = MetSys.settings.in_game_cell_size
	var room_points := _generate_points(cells, cell_size)

	var col := _get_or_create_polygon_child()
	# Room-local points (RoomInstance sits at origin) -> the polygon node's local space.
	var inv := col.global_transform.affine_inverse()
	var poly_points := PackedVector2Array()
	for p in room_points:
		poly_points.append(inv * p)

	col.polygon = poly_points
	rebuild()
	print("CameraPathBoundary: generated %d points from %d cells." % [poly_points.size(), cells.size()])

## Reads this room's cells from MetSys and returns them as local (0-based) coords.
func _read_room_cells() -> Array:
	var scene_path := ""
	if owner and not owner.scene_file_path.is_empty():
		scene_path = owner.scene_file_path
	elif get_tree() and get_tree().edited_scene_root:
		scene_path = get_tree().edited_scene_root.scene_file_path
	if scene_path.is_empty():
		return []

	var cells3: Array = MetSys.map_data.get_cells_assigned_to_path(scene_path)
	if cells3.is_empty():
		return []

	var min_cell := Vector2i(1 << 30, 1 << 30)
	for c in cells3:
		min_cell.x = mini(min_cell.x, c.x)
		min_cell.y = mini(min_cell.y, c.y)

	var local: Array = []
	for c in cells3:
		local.append(Vector2i(c.x - min_cell.x, c.y - min_cell.y))
	return local

## Builds the room-local polygon points for the given local cells.
func _generate_points(cells: Array, cell_size: Vector2) -> PackedVector2Array:
	if cells.size() == 1:
		return PackedVector2Array([_cell_center(cells[0], cell_size)])

	# Straight 1-wide room -> a true line (zero area).
	var line := _straight_line_points(cells, cell_size)
	if not line.is_empty():
		return line

	var cellset := {}
	for c in cells:
		cellset[c] = true

	var midpoints: Array = []
	var pieces := _build_pieces(cells, cellset, cell_size, midpoints)
	if pieces.is_empty():
		return PackedVector2Array()

	var ring := _union_pieces(pieces)
	return _insert_corner_midpoints(ring, midpoints)

## Returns the two endpoint centres if every cell shares a row or a column, else [].
func _straight_line_points(cells: Array, cell_size: Vector2) -> PackedVector2Array:
	var first: Vector2i = cells[0]
	var same_x := true
	var same_y := true
	for c in cells:
		if c.x != first.x:
			same_x = false
		if c.y != first.y:
			same_y = false
	if not (same_x or same_y):
		return PackedVector2Array()

	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c in cells:
		if c.x < lo.x or c.y < lo.y:
			lo = c
		if c.x > hi.x or c.y > hi.y:
			hi = c
	return PackedVector2Array([_cell_center(lo, cell_size), _cell_center(hi, cell_size)])

## Builds the filled convex primitives (squares, corridor strips, triangles,
## diamonds) whose union is the allowed region. Appends turn midpoints to [param midpoints].
func _build_pieces(cells: Array, cellset: Dictionary, cell_size: Vector2, midpoints: Array) -> Array:
	var pieces: Array = []
	var w := maxf(1.0, minf(cell_size.x, cell_size.y) * CORRIDOR_WIDTH_FACTOR)

	# (1) Filled square per 2x2 block -> fills rectangular areas of any size.
	for c in cells:
		if cellset.has(c + Vector2i(1, 0)) and cellset.has(c + Vector2i(0, 1)) and cellset.has(c + Vector2i(1, 1)):
			pieces.append(PackedVector2Array([
				_cell_center(c, cell_size),
				_cell_center(c + Vector2i(1, 0), cell_size),
				_cell_center(c + Vector2i(1, 1), cell_size),
				_cell_center(c + Vector2i(0, 1), cell_size)]))

	# (2) Thin strip bridging every adjacency (right & down avoids duplicates).
	for c in cells:
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cellset.has(c + dir):
				var strip := _thin_rect(_cell_center(c, cell_size), _cell_center(c + dir, cell_size), w)
				if not strip.is_empty():
					pieces.append(strip)

	# (3) Corner triangles at turns, diamonds at T/cross junctions.
	for c in cells:
		var nbs := _neighbor_dirs(c, cellset)
		if nbs.size() == 2 and nbs[0] + nbs[1] != Vector2i.ZERO:
			# Perpendicular neighbours -> an L turn.
			var a := _cell_center(c + nbs[0], cell_size)
			var b := _cell_center(c + nbs[1], cell_size)
			pieces.append(PackedVector2Array([a, _cell_center(c, cell_size), b]))
			midpoints.append((a + b) * 0.5)
		elif nbs.size() >= 3:
			var center := _cell_center(c, cell_size)
			var pts: Array = []
			for n in nbs:
				pts.append(_cell_center(c + n, cell_size))
			pieces.append(_sort_ccw(pts, center))

	return pieces

## Unions all pieces into one ring, tolerating pieces added in any order.
func _union_pieces(pieces: Array) -> PackedVector2Array:
	var rings: Array = []
	for piece in pieces:
		if piece.size() < 3:
			continue
		var current: PackedVector2Array = piece
		var merged := true
		while merged:
			merged = false
			for i in range(rings.size()):
				var res := Geometry2D.merge_polygons(rings[i], current)
				if res.size() == 1: # 1 ring back == the two overlapped and joined
					current = res[0]
					rings.remove_at(i)
					merged = true
					break
		rings.append(current)

	# The connected region's outline is the largest-area ring.
	var best := PackedVector2Array()
	var best_area := -1.0
	for r in rings:
		var a := absf(_polygon_area(r))
		if a > best_area:
			best_area = a
			best = r
	return best

## Best-effort: drops a spare vertex on the polygon edge nearest each turn midpoint.
func _insert_corner_midpoints(ring: PackedVector2Array, midpoints: Array) -> PackedVector2Array:
	if ring.size() < 3:
		return ring
	var result := ring
	for m in midpoints:
		var count := result.size()
		var best_i := -1
		var best_q := Vector2.ZERO
		var best_d := INF
		for i in count:
			var a := result[i]
			var b := result[(i + 1) % count]
			var q := Geometry2D.get_closest_point_to_segment(m, a, b)
			var d: float = m.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best_i = i
				best_q = q
		if best_i >= 0:
			var a := result[best_i]
			var b := result[(best_i + 1) % count]
			if best_q.distance_to(a) > 0.5 and best_q.distance_to(b) > 0.5:
				result.insert(best_i + 1, best_q)
	return result

## Local-space centre of a local cell coordinate.
func _cell_center(cell: Vector2i, cell_size: Vector2) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

## The 4-directional offsets of a cell's present neighbours.
func _neighbor_dirs(cell: Vector2i, cellset: Dictionary) -> Array:
	var dirs: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cellset.has(cell + d):
			dirs.append(d)
	return dirs

## A thin rectangle along p->q, extended slightly past both ends so unions connect.
func _thin_rect(p: Vector2, q: Vector2, half_width: float) -> PackedVector2Array:
	var dir := q - p
	if dir.length() < 0.0001:
		return PackedVector2Array()
	dir = dir.normalized()
	var perp := dir.orthogonal() * half_width
	var ext := dir * half_width
	var a := p - ext
	var b := q + ext
	return PackedVector2Array([a + perp, b + perp, b - perp, a - perp])

## Points sorted counter-clockwise around a centre, as a convex polygon.
func _sort_ccw(pts: Array, center: Vector2) -> PackedVector2Array:
	var arr := pts.duplicate()
	arr.sort_custom(func(x, y): return (x - center).angle() < (y - center).angle())
	var out := PackedVector2Array()
	for p in arr:
		out.append(p)
	return out

## Finds an existing [CollisionPolygon2D] child, or creates one owned by the scene.
func _get_or_create_polygon_child() -> CollisionPolygon2D:
	for child in get_children():
		if child is CollisionPolygon2D:
			return child
	var col := CollisionPolygon2D.new()
	add_child(col)
	col.owner = owner if owner else get_tree().edited_scene_root
	col.name = "GeneratedCameraPath"
	return col
#endregion
