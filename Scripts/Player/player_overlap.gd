class_name PlayerOverlap
## Synchronous tests for whether the player's body is inside a region right now.
##
## These deliberately go around the physics server, which cannot answer the
## question at the moments callers need it. It only reports an overlap after a
## step has run with the player at its current position, which is several frames
## after a spawn; the player leaves the physics space entirely while it is
## disabled during a load (CollisionObject2D.disable_mode defaults to
## DISABLE_MODE_REMOVE); and a region that is about to be filled in has no
## collider to report on in the first place. Testing shapes directly costs a few
## SAT checks and is always answerable on the frame it is asked.

## The player's shapes, rebuilt whenever the player instance changes. Held by
## instance id rather than by reference so a freed player can't be read from.
static var _player_shapes : Array = []
static var _player_shapes_source : int = 0

## True if the player's body overlaps [param shape] placed at
## [param shape_transform].
static func with_shape(shape: Shape2D, shape_transform: Transform2D) -> bool:
	for theirs in _player_body_shapes():
		if theirs[1].disabled:
			continue
		if shape.collide(shape_transform, theirs[0], theirs[1].global_transform):
			return true
	return false

## True if the player's body overlaps any of [param shapes], which are pairs as
## returned by [method collect_shapes].
static func with_shapes(shapes: Array) -> bool:
	for mine in shapes:
		if mine[1].disabled:
			continue
		if with_shape(mine[0], mine[1].global_transform):
			return true
	return false

## True if the player's body overlaps [param rect], which is given in the local
## space of [param rect_transform].
static func with_rect(rect: Rect2, rect_transform: Transform2D) -> bool:
	var box := RectangleShape2D.new()
	box.size = rect.size
	# A RectangleShape2D is centred on its transform's origin.
	return with_shape(box, rect_transform.translated_local(rect.get_center()))

## Collects a collision object's shapes as [shape, owner node] pairs. The owner
## comes along so its live global transform and disabled flag can be read on
## every test. Building this is not free, so cache the result and reuse it.
static func collect_shapes(collision_object: Node) -> Array:
	var shapes := []
	for child in collision_object.get_children():
		if child is CollisionShape2D:
			if child.shape:
				shapes.append([child.shape, child])
		elif child is CollisionPolygon2D:
			# A CollisionPolygon2D owns no Shape2D, so rebuild the convex pieces
			# the physics server would have made from it.
			for piece in Geometry2D.decompose_polygon_in_convex(child.polygon):
				var convex := ConvexPolygonShape2D.new()
				# Via the point cloud, so the winding comes out right whichever
				# way the polygon happened to be drawn in the editor.
				convex.set_point_cloud(piece)
				shapes.append([convex, child])
	return shapes

static func _player_body_shapes() -> Array:
	var player := PlayerManager.player
	if not is_instance_valid(player) or not player.is_inside_tree():
		return []
	# The player swaps between a walking, crouching and jumping shape, so the
	# pairs are cached but their disabled flags are read on every test.
	if player.get_instance_id() != _player_shapes_source:
		_player_shapes_source = player.get_instance_id()
		_player_shapes = collect_shapes(player)
	return _player_shapes
