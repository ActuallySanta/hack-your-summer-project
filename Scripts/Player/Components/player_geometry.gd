## Questions about the level the player's components keep having to ask.
##
## All static, all synchronous, and all phrased in world (global) coordinates, so a
## component can ask them at any point in a frame without caring where the physics
## step is up to.
##
## The important one is [method is_blocking_wall]: a point query reports a one-way
## platform's collider exactly like a wall's, because a one-way tile [i]is[/i] a
## collider -- it is only the contact normal that decides whether it stops you. Any
## test that means "is there a wall here" has to look past the raw hit at whether
## the thing hit could stop horizontal movement at all, or standing inside a wide
## one-way platform reads as standing against a wall.
class_name PlayerGeometry

## The room's solid tile layer. Rooms put exactly one layer in this group.
const GEOMETRY_GROUP := &"Geometry"

## How far inside a cell's top edge [method has_solid_top] samples for solid.
const TOP_PROBE_DEPTH := 3.0

## Where across a cell's width [method has_solid_top] samples, as fractions of the
## cell. The ends are inset so a tile that is solid across its top still passes when
## its neighbour is empty and the query lands a hair over the seam.
const TOP_PROBE_SPREAD : Array[ float ] = [ 0.12, 0.3, 0.5, 0.7, 0.88 ]

static func foreground(tree: SceneTree) -> TileMapLayer:
	return tree.get_first_node_in_group(GEOMETRY_GROUP) as TileMapLayer

## The cell of [param layer] that [param global_point] falls in.
static func map_coords(layer: TileMapLayer, global_point: Vector2) -> Vector2i:
	if layer == null:
		return Vector2i.MIN
	return layer.local_to_map(layer.to_local(global_point))

## True when [param coords] holds no tile at all on [param layer].
##
## This is a cheap "is anything drawn here" test and nothing more. It says nothing
## about whether what is there has a collider, which is why anything that cares about
## being able to stand on a tile asks [method has_solid_top] instead.
static func is_cell_empty(layer: TileMapLayer, coords: Vector2i) -> bool:
	return layer == null or layer.get_cell_source_id(coords) == -1

## The rectangle [param coords] covers, in global space.
static func cell_rect(layer: TileMapLayer, coords: Vector2i) -> Rect2:
	var size := Vector2(layer.tile_set.tile_size) * layer.global_scale
	var centre := layer.to_global(layer.map_to_local(coords))
	return Rect2(centre - size * 0.5, size)

## Every collider overlapping [param global_point] on [param mask].
static func points_hits(world: World2D, global_point: Vector2, mask: int, exclude: Array[RID] = []) -> Array[Dictionary]:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_point
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = exclude
	return world.direct_space_state.intersect_point(query, 8)

## True when anything at all is solid at [param global_point].
static func is_point_solid(world: World2D, global_point: Vector2, mask: int, exclude: Array[RID] = []) -> bool:
	return not points_hits(world, global_point, mask, exclude).is_empty()

## True when something at [param global_point] could actually stop sideways movement.
##
## One-way tiles are skipped: they only ever stop a body coming at them from their
## one blocking direction, so standing inside a platform that is several tiles wide
## is not standing against a wall, however many colliders the point query finds.
static func is_blocking_wall(world: World2D, global_point: Vector2, mask: int, exclude: Array[RID] = []) -> bool:
	for hit in points_hits(world, global_point, mask, exclude):
		if _hit_blocks_sideways(hit):
			return true
	return false

static func _hit_blocks_sideways(hit: Dictionary) -> bool:
	var tiles := hit.get("collider") as TileMapLayer
	if tiles == null:
		# A plain body. One-way is a per-shape flag on CollisionShape2D/CollisionPolygon2D;
		# a body whose hit shape is one-way is no more a wall than a one-way tile is.
		return not _hit_shape_is_one_way(hit)
	return not tile_is_all_one_way(tiles, tiles.get_coords_for_body_rid(hit.get("rid", RID())))

static func _hit_shape_is_one_way(hit: Dictionary) -> bool:
	var body := hit.get("collider") as CollisionObject2D
	if body == null:
		return false
	var owner_id: int = body.shape_find_owner(hit.get("shape", 0))
	var shape_node := body.shape_owner_get_owner(owner_id)
	return shape_node != null and shape_node.get("one_way_collision") == true

## True when every collision polygon on the tile at [param coords] is one-way, so the
## tile cannot block anything approaching from the side or from below.
##
## An empty cell answers false: there is nothing there to be one-way, and callers
## already have [method is_cell_empty] for that question.
static func tile_is_all_one_way(layer: TileMapLayer, coords: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(coords)
	if data == null or layer.tile_set == null:
		return false

	var found_any := false
	for physics_layer in layer.tile_set.get_physics_layers_count():
		for polygon in data.get_collision_polygons_count(physics_layer):
			found_any = true
			if not data.is_collision_polygon_one_way(physics_layer, polygon):
				return false
	return found_any

## True when the cell at [param coords] is solid right across its top face.
##
## The plain "is there a tile here" test is not enough to mantle on: a decorative
## tile has no collider at all, and a half-height or sloped tile only covers part of
## its cell, so a vault onto it lands the player inside the geometry or in mid-air.
## Sampling across the whole top edge is what makes a partial tile fail the test --
## which is the rare case where a mantle onto nothing used to be possible.
static func has_solid_top(world: World2D, layer: TileMapLayer, coords: Vector2i, mask: int, exclude: Array[RID] = []) -> bool:
	if layer == null or is_cell_empty(layer, coords):
		return false

	var rect := cell_rect(layer, coords)
	var probe_y := rect.position.y + TOP_PROBE_DEPTH
	for fraction in TOP_PROBE_SPREAD:
		var probe := Vector2(rect.position.x + rect.size.x * fraction, probe_y)
		if not is_point_solid(world, probe, mask, exclude):
			return false
	return true

## True when nothing in the column of [param cells] is solid, so there is room to
## come up into it.
static func are_cells_clear(world: World2D, layer: TileMapLayer, cells: Array[Vector2i], mask: int, exclude: Array[RID] = []) -> bool:
	for coords in cells:
		if is_cell_empty(layer, coords):
			continue
		# A tile that is drawn but has no collider (decoration in front of a gap) is
		# not in the way, so the collider is what is asked about rather than the cell.
		var rect := cell_rect(layer, coords)
		for fraction in TOP_PROBE_SPREAD:
			var probe := Vector2(rect.position.x + rect.size.x * fraction, rect.get_center().y)
			if is_point_solid(world, probe, mask, exclude):
				return false
	return true
