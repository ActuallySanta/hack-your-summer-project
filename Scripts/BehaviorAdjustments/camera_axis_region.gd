@tool
class_name CameraAxisRegion
extends Area2D

const GROUP := &"camera_axis_region"
const CONTROLLER_GROUP := &"camera_axis_controller"

const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 4
const DIR_DOWN := 8

enum PreservedAxis {
	HORIZONTAL, ## Follow the player left/right; center the camera vertically.
	VERTICAL, ## Follow the player up/down; center the camera horizontally.
}

@export var preserved_axis := PreservedAxis.HORIZONTAL:
	set(value):
		preserved_axis = value
		if Engine.is_editor_hint():
			queue_redraw()

## Which movement directions let this region take control of the camera. 
## Leaving this empty disables the region.
@export_flags("Left", "Right", "Up", "Down") var claim_directions := DIR_LEFT | DIR_RIGHT | DIR_UP | DIR_DOWN

## How quickly the camera slides onto the centre line
@export_range(0.1, 8.0, 0.05, "or_greater") var centering_rate := 1.5

## Rate used when handing the locked axis back to normal following after the
## player leaves. 0 or less reuses [member centering_rate].
@export_range(0.0, 8.0, 0.05, "or_greater") var release_rate := 0.0

## Movement below this speed (pixels/second) doesn't count as travelling in a direction
@export_range(0.0, 200.0, 1.0, "or_greater") var movement_deadzone := 8.0
@export var claim_priority := 0

@export_group("Center Line")
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

var _bounds := Rect2()
var _has_bounds := false
var _shapes: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		return
	monitoring = false
	monitorable = false
	rebuild()
	add_to_group(GROUP)
	if _shapes.is_empty():
		push_warning("CameraAxisRegion %s has no collision polygons, so it will never claim the camera." % name)

	_claim_on_arrival()
	_claim_on_arrival.call_deferred()
	GlobalSignals.player_spawned.connect(_claim_on_arrival)

func rebuild() -> void:
	_bounds = Rect2()
	_has_bounds = false
	if not Engine.is_editor_hint():
		_shapes = PlayerOverlap.collect_shapes(self)
	for child in get_children():
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

func get_locked_axis() -> int:
	return 1 if preserved_axis == PreservedAxis.HORIZONTAL else 0

func get_center_value() -> float:
	if use_center_override:
		return center_override
	var axis := get_locked_axis()
	return _bounds.position[axis] + _bounds.size[axis] * 0.5

func get_release_rate() -> float:
	return release_rate if release_rate > 0.0 else centering_rate

func contains_player() -> bool:
	return PlayerOverlap.with_shapes(_shapes)

func _claim_on_arrival() -> void:
	if not is_inside_tree() or not contains_player():
		return
	var controller := get_tree().get_first_node_in_group(CONTROLLER_GROUP)
	if controller and controller.has_method(&"snap_to_camera_axis_region"):
		controller.snap_to_camera_axis_region(self)

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
	if Engine.is_editor_hint():
		rebuild()
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or not _has_bounds:
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
