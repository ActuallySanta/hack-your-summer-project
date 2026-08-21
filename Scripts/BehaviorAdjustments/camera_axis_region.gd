@tool
class_name CameraAxisRegion
extends Area2D

const GROUP := &"camera_axis_region"
const CONTROLLER_GROUP := &"camera_axis_controller"

const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 4
const DIR_DOWN := 8

## Bit flags naming the axes a region drives. Match the component indices of a
## Vector2, so AXIS_X is 1 << 0 and AXIS_Y is 1 << 1.
const AXIS_X := 1
const AXIS_Y := 2

enum LockMode {
	LINE, ## Pin one axis to a centre line; the other keeps following the player.
	POINT, ## Pin both axes: the camera sits on a single point while the region holds it.
}

enum PreservedAxis {
	HORIZONTAL, ## Follow the player left/right; centre the camera vertically.
	VERTICAL, ## Follow the player up/down; centre the camera horizontally.
}

## Whether this region restricts the camera to a line or to a single point.
## A point region has no preserved axis: it drives both.
@export var lock_mode := LockMode.LINE:
	set(value):
		lock_mode = value
		notify_property_list_changed()
		if Engine.is_editor_hint():
			queue_redraw()

## Which axis keeps following the player. Line regions only.
@export var preserved_axis := PreservedAxis.HORIZONTAL:
	set(value):
		preserved_axis = value
		if Engine.is_editor_hint():
			queue_redraw()

## Which movement directions let this region take control of the camera. 
## Leaving this empty disables the region.
@export_flags("Left", "Right", "Up", "Down") var claim_directions := DIR_LEFT | DIR_RIGHT | DIR_UP | DIR_DOWN

## How quickly the camera slides onto the centre line or point
@export_range(0.1, 8.0, 0.05, "or_greater") var centering_rate := 1.5

## Rate used when handing the locked axes back to normal following after the
## player leaves. 0 or less reuses [member centering_rate].
@export_range(0.0, 8.0, 0.05, "or_greater") var release_rate := 0.0

## Movement below this speed (pixels/second) doesn't count as travelling in a direction
@export_range(0.0, 200.0, 1.0, "or_greater") var movement_deadzone := 8.0
@export var claim_priority := 0

## Lets the axes this region drives leave the hard bounds, both the room's own
## rectangle and any [CameraHardBoundary]. Use it to frame a shot that has to sit
## partly outside the room, and make sure whatever the camera then shows is
## something you want seen. Axes this region doesn't drive stay bounded, and the
## exemption lasts until the hand-back to normal following finishes, so the
## camera eases back inside instead of snapping.
@export var ignore_hard_boundaries := false

@export_group("Centre")
## Use [member center_override] instead of the polygon's bounding-box centre.
## Only needed when the polygon isn't symmetrical about the axes being driven.
@export var use_center_override := false:
	set(value):
		use_center_override = value
		if Engine.is_editor_hint():
			queue_redraw()

## Global coordinate the camera is pinned to. Only the components of the axes
## this region drives are read: the Y of a horizontal line region, the X of a
## vertical one, and both for a point region.
@export var center_override := Vector2.ZERO:
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

func _validate_property(property: Dictionary) -> void:
	# A point region drives both axes, so there is nothing to preserve. Kept out of
	# the inspector rather than out of the scene, so switching back restores it.
	if property.name == &"preserved_axis" and lock_mode == LockMode.POINT:
		property.usage = PROPERTY_USAGE_NO_EDITOR

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

## The axes this region drives, as a mask of [constant AXIS_X] and [constant AXIS_Y].
func get_locked_axes() -> int:
	if lock_mode == LockMode.POINT:
		return AXIS_X | AXIS_Y
	return AXIS_Y if preserved_axis == PreservedAxis.HORIZONTAL else AXIS_X

## The global point the camera is pinned to. Components belonging to axes this
## region doesn't drive are the polygon centre and go unused.
func get_center_point() -> Vector2:
	var center := _bounds.get_center()
	if use_center_override:
		var locked := get_locked_axes()
		if locked & AXIS_X:
			center.x = center_override.x
		if locked & AXIS_Y:
			center.y = center_override.y
	return center

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
	# Draw where the camera will be pulled to, spanning the polygon.
	var color := Color(0.4, 0.9, 1.0, 0.85)
	var center := get_center_point()
	if lock_mode == LockMode.POINT:
		# A crosshair, since neither axis is free to follow the player.
		var arm := maxf(24.0, minf(_bounds.size.x, _bounds.size.y) * 0.1)
		draw_line(to_local(center - Vector2(arm, 0)), to_local(center + Vector2(arm, 0)), color, 3.0)
		draw_line(to_local(center - Vector2(0, arm)), to_local(center + Vector2(0, arm)), color, 3.0)
		draw_arc(to_local(center), arm * 0.45, 0.0, TAU, 24, color, 2.0)
		return
	var from: Vector2
	var to: Vector2
	if preserved_axis == PreservedAxis.HORIZONTAL:
		from = Vector2(_bounds.position.x, center.y)
		to = Vector2(_bounds.end.x, center.y)
	else:
		from = Vector2(center.x, _bounds.position.y)
		to = Vector2(center.x, _bounds.end.y)
	draw_line(to_local(from), to_local(to), color, 3.0)
#endregion
