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

## Group game.gd puts itself in so a region loaded inside a room can hand it the
## camera the moment the room resolves. Declared here so the dependency only runs
## one way: game.gd knows this class, this class only knows a group name.
const CONTROLLER_GROUP := &"camera_axis_controller"

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

## Bounding box of every [CollisionPolygon2D] child, in global space. The centre
## line is taken from this.
var _bounds := Rect2()

## False when there is no polygon to take a centre line from.
var _has_bounds := false

## Our shapes as [PlayerOverlap] pairs, cached once and re-read through their
## owners' live transforms on every test.
var _shapes: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		return
	# Overlap goes through PlayerOverlap rather than body_entered/exited, because
	# the physics server cannot report an overlap that already exists when a room
	# finishes loading - see PlayerOverlap for why. So our own signals are unused.
	monitoring = false
	monitorable = false
	rebuild()
	add_to_group(GROUP)
	if _shapes.is_empty():
		push_warning("CameraAxisRegion %s has no collision polygons, so it will never claim the camera." % name)

	# A room can load with the player already standing in here - arriving through
	# a transition, respawning, or loading a save. There is nothing to ease from in
	# that case, so the shot simply starts centred. Resolve it now and again once
	# the frame's work is done but before it is drawn, because a transition shifts
	# the player onto its entrance immediately after loading us.
	_claim_on_arrival()
	_claim_on_arrival.call_deferred()
	GlobalSignals.player_spawned.connect(_claim_on_arrival)

## Rebuilds the cached polygons from the current [CollisionPolygon2D] children.
## Call this if a polygon is edited or the node is moved at runtime.
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

## Whether the player's body currently overlaps this region.
func contains_player() -> bool:
	return PlayerOverlap.with_shapes(_shapes)

## Hands the camera straight to this region, already centred, if the player is
## standing in it as the room resolves. Direction doesn't gate this: claim
## directions exist to stop a feeler grabbing the camera off a passer-by, and
## a player who arrives inside the region has already committed to it.
func _claim_on_arrival() -> void:
	if not is_inside_tree() or not contains_player():
		return
	var controller := get_tree().get_first_node_in_group(CONTROLLER_GROUP)
	if controller and controller.has_method(&"snap_to_camera_axis_region"):
		controller.snap_to_camera_axis_region(self)

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
