@tool
class_name MovingPlatform extends TileMapLayer

## A TileMapLayer that carries whatever is riding it.
##
## This node does not move itself: parent it to a [Path] (or drop it into that
## path's [member Path.nodes_to_move]) and the path drives it from A to B.
## All this script does is make players and enemies stick to it, for any
## movement direction the path produces.
##
## The tiles painted here need a physics layer on the TileSet, same as any
## other piece of level geometry -- that is what entities actually stand on.

enum CarryMode {
	## Only carry a body whose floor is this platform. The usual choice.
	GROUNDED_ON_PLATFORM,
	## Carry a body touching any face of this platform, floor/wall/ceiling.
	ANY_CONTACT,
	## Carry every body inside the detection area, contact or not.
	OVERLAP,
}

@export_category("Riders")
## Physics layers scanned for riders. Defaults to "player" (2) and "enemies" (3).
@export_flags_2d_physics var rider_mask : int = 0b110:
	set(value):
		rider_mask = value
		if is_instance_valid(_detector):
			_detector.collision_mask = value
@export var carry_mode : CarryMode = CarryMode.GROUNDED_ON_PLATFORM
## How far past the painted tiles a body still counts as riding the platform.
@export_range(0.0, 32.0, 0.5, "or_greater") var surface_margin : float = 3.0
## Sweep riders with move_and_collide instead of teleporting them, so the
## platform cannot shove them through walls.
@export var sweep_riders : bool = true

@export_category("Motion")
## Whether riders are carried. Independent of TileMapLayer's own [member
## TileMapLayer.enabled], which turns the whole layer off.
@export var carry_enabled : bool = true
## The path writes our position on render frames, riders move on physics frames.
## When on, we hold that position back and commit it during the physics step so
## the two stay in lockstep instead of visibly sliding against each other.
@export var sync_to_physics : bool = true
## Movement larger than this in a single physics frame is treated as a teleport
## and riders are left behind. Covers the path's initial snap onto its first
## point. Set to 0 to always carry.
@export var teleport_threshold : float = 64.0

## Distance moved during the last physics frame, for anything that wants to
## inherit the platform's momentum (a jump off a rising platform, say).
var last_motion : Vector2

var _detector : Area2D
var _committed_position : Vector2
var _pending_position : Vector2
var _last_global_position : Vector2

func _ready() -> void:
	_committed_position = position
	_pending_position = position
	_last_global_position = global_position
	if Engine.is_editor_hint():
		return
	# Run _process after the path has written our position for this frame, and
	# _physics_process before riders run their own movement for this step.
	process_priority = 1000
	process_physics_priority = -1000
	rebuild_detector()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not sync_to_physics:
		return
	# Stash whatever the path just wrote and rewind to the last committed step.
	_pending_position = position
	position = _committed_position

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if sync_to_physics:
		position = _pending_position
	_committed_position = position

	var motion := global_position - _last_global_position
	_last_global_position = global_position
	last_motion = motion

	if not carry_enabled or motion.is_zero_approx():
		return
	if teleport_threshold > 0.0 and motion.length() > teleport_threshold:
		return
	_carry_riders(motion)

## Velocity of the platform in pixels/second, based on the last physics frame.
func get_platform_velocity() -> Vector2:
	var step := get_physics_process_delta_time()
	return last_motion / step if step > 0.0 else Vector2.ZERO

## Regenerates the rider detection area. Call this if the painted tiles change
## at runtime.
func rebuild_detector() -> void:
	if is_instance_valid(_detector):
		remove_child(_detector)
		_detector.queue_free()

	_detector = Area2D.new()
	_detector.name = "RiderDetector"
	_detector.collision_layer = 0
	_detector.collision_mask = rider_mask
	_detector.monitorable = false
	add_child(_detector)

	for rect in _collect_detection_rects():
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.position = rect.get_center()
		_detector.add_child(shape)

func _carry_riders(motion: Vector2) -> void:
	if not is_instance_valid(_detector):
		return

	# Collect first, then move. Moving a body can change what the others are
	# touching, and we want every rider judged against the same frame.
	var riders : Array[Node2D] = []
	for body in _detector.get_overlapping_bodies():
		if body == self or not body is Node2D:
			continue
		if _is_riding(body):
			riders.append(body)

	for rider in riders:
		if sweep_riders and rider is PhysicsBody2D:
			(rider as PhysicsBody2D).move_and_collide(motion)
		else:
			rider.global_position += motion

func _is_riding(body: Node2D) -> bool:
	if carry_mode == CarryMode.OVERLAP:
		return true

	# Anything without slide data to inspect falls back to plain overlap.
	if not body is CharacterBody2D:
		return true

	var character := body as CharacterBody2D
	if carry_mode == CarryMode.GROUNDED_ON_PLATFORM and not character.is_on_floor():
		return false

	# Slide collisions are from the rider's last move_and_slide, which already
	# ran before we did this frame.
	for i in character.get_slide_collision_count():
		var collision := character.get_slide_collision(i)
		var collider := collision.get_collider()
		var collider_node := collider as Node
		# Also accept a collision body parented under us, in case the collision
		# lives on a child node rather than on the tiles themselves.
		if collider != self and (collider_node == null or not is_ancestor_of(collider_node)):
			continue
		if carry_mode == CarryMode.ANY_CONTACT:
			return true
		if collision.get_normal().dot(character.up_direction) > 0.0:
			return true
	return false

## Builds a rectangle per horizontal run of painted cells, grown by the surface
## margin, so an arbitrarily shaped platform is covered with few shapes.
func _collect_detection_rects() -> Array[Rect2]:
	var rects : Array[Rect2] = []
	if tile_set == null:
		return rects

	var cell_size := Vector2(tile_set.tile_size)
	var square := tile_set.tile_shape == TileSet.TILE_SHAPE_SQUARE

	var rows : Dictionary = {}
	for cell in get_used_cells():
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)

	for key in rows:
		var row : int = key
		var columns : Array = rows[key]
		columns.sort()
		var run_start : int = columns[0]
		var run_end : int = columns[0]
		# One extra iteration so the final run gets flushed.
		for i in range(1, columns.size() + 1):
			var at_end := i >= columns.size()
			if not at_end and square and columns[i] == run_end + 1:
				run_end = columns[i]
				continue
			var first := map_to_local(Vector2i(run_start, row))
			var last := map_to_local(Vector2i(run_end, row))
			var rect := Rect2(first - cell_size * 0.5, last - first + cell_size)
			rects.append(rect.grow(surface_margin))
			if not at_end:
				run_start = columns[i]
				run_end = columns[i]
	return rects

func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	if tile_set == null:
		warnings.append("Assign a TileSet, otherwise there is nothing to ride.")
	elif tile_set.get_physics_layers_count() == 0:
		warnings.append("This TileSet has no physics layer, so entities will fall straight through the platform. Add one under TileSet > Physics Layers and give the tiles a collision polygon.")
	if not get_parent() is Path:
		warnings.append("Not a child of a Path. The platform will not move unless a Path drives it (parent it to one, or add it to that path's Nodes To Move).")
	return warnings
