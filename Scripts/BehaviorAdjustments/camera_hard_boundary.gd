@tool
class_name CameraHardBoundary
extends Area2D
## A line the camera's view is not allowed to cross.
##
## Hard boundaries shrink the rectangle the camera is kept inside, which
## otherwise is just the room's own bounds, so everything that reads those bounds
## treats a boundary exactly like a room edge: following, the centring done by a
## [CameraAxisRegion], and the placement of the camera on entering a room.
## Only a region with [member CameraAxisRegion.ignore_hard_boundaries] set may
## cross one.
##
## Add [CollisionPolygon2D] children to make the boundary apply only while the
## player stands inside them; with no collision children it applies everywhere in
## the room. Note that a boundary can leave the camera less room than the screen
## is wide, and then the view is centred in what is left and spills past both
## sides, the same as it does in a room smaller than the screen.

const GROUP := &"camera_hard_boundary"

enum Orientation {
	VERTICAL, ## A vertical line, so it limits the camera horizontally.
	HORIZONTAL, ## A horizontal line, so it limits the camera vertically.
}

enum CameraSide {
	PLAYER, ## Whichever side the player is on, so the line can be crossed by walking through it.
	BEFORE, ## Left of / above the line: it acts as the room's right or bottom edge.
	AFTER, ## Right of / below the line: it acts as the room's left or top edge.
}

## Whether this is a vertical or a horizontal line. The line runs through the
## node's own position, so drag the node to place it.
@export var orientation := Orientation.VERTICAL:
	set(value):
		orientation = value
		if Engine.is_editor_hint():
			queue_redraw()

## Which side of the line the camera is held on.
@export var camera_side := CameraSide.PLAYER:
	set(value):
		camera_side = value
		if Engine.is_editor_hint():
			queue_redraw()

## Lets the boundary be switched off from a script, e.g. once a door opens.
@export var enabled := true:
	set(value):
		enabled = value
		if Engine.is_editor_hint():
			queue_redraw()

@export_group("Editor preview")
## How long the drawn line is when the boundary has no collision polygons to
## span. Has no effect in game.
@export var preview_length := 2304.0:
	set(value):
		preview_length = value
		if Engine.is_editor_hint():
			queue_redraw()

var _bounds := Rect2()
var _has_bounds := false
var _has_area := false
var _shapes: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		return
	monitoring = false
	monitorable = false
	rebuild()
	add_to_group(GROUP)

func rebuild() -> void:
	_bounds = Rect2()
	_has_bounds = false
	_has_area = false
	if not Engine.is_editor_hint():
		_shapes = PlayerOverlap.collect_shapes(self)
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			_has_area = true
		var col := child as CollisionPolygon2D
		if col == null or col.polygon.size() < 3:
			continue
		for point in col.polygon:
			var global_point: Vector2 = col.global_transform * point
			if _has_bounds:
				_bounds = _bounds.expand(global_point)
			else:
				_bounds = Rect2(global_point, Vector2.ZERO)
				_has_bounds = true

## The Vector2 component this boundary limits: 0 for a vertical line, 1 for a
## horizontal one.
func get_axis() -> int:
	return 0 if orientation == Orientation.VERTICAL else 1

## The global coordinate of the line on the axis it limits.
func get_line_position() -> float:
	return global_position[get_axis()]

## True while this boundary is shrinking the camera's bounds. A boundary with an
## area only counts while the player is inside it.
func is_active() -> bool:
	if not enabled:
		return false
	if not _has_area:
		return true
	return PlayerOverlap.with_shapes(_shapes)

## Returns [param rect] cut back to the side of the line the camera is held on.
## [param focus] is the position the side is judged from in [constant CameraSide.PLAYER]
## mode, i.e. the player's. Never returns a rect with a negative size: a line
## outside the rect entirely collapses it against the nearer edge.
func apply_to(rect: Rect2, focus: Vector2) -> Rect2:
	var axis := get_axis()
	var line := get_line_position()
	var lo := rect.position[axis]
	var hi := rect.end[axis]

	var side := camera_side
	if side == CameraSide.PLAYER:
		side = CameraSide.BEFORE if focus[axis] <= line else CameraSide.AFTER

	if side == CameraSide.BEFORE:
		hi = maxf(lo, minf(hi, line))
	else:
		lo = minf(hi, maxf(lo, line))

	var result_position := rect.position
	var result_size := rect.size
	result_position[axis] = lo
	result_size[axis] = hi - lo
	return Rect2(result_position, result_size)

#region Editor preview
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		rebuild()
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var axis := get_axis()
	var across := 1 - axis
	var color := Color(1.0, 0.35, 0.3, 0.85 if enabled else 0.3)

	# Span the area the boundary applies in, or a plain length when it has none.
	var from := global_position
	var to := global_position
	if _has_bounds:
		from[across] = _bounds.position[across]
		to[across] = _bounds.end[across]
	else:
		from[across] -= preview_length * 0.5
		to[across] += preview_length * 0.5
	from = to_local(from)
	to = to_local(to)
	draw_line(from, to, color, 3.0)

	# Ticks reaching into the side the camera may not show. In PLAYER mode either
	# side can end up off-limits, depending on where the player is.
	var tick := Vector2.ZERO
	tick[axis] = 28.0
	var directions: Array[float] = [1.0, -1.0]
	if camera_side == CameraSide.BEFORE:
		directions = [1.0]
	elif camera_side == CameraSide.AFTER:
		directions = [-1.0]
	var faded := Color(color, color.a * 0.55)
	for i in 9:
		var base := from.lerp(to, float(i) / 8.0)
		for direction in directions:
			draw_line(base, base + tick * direction, faded, 2.0)
#endregion
