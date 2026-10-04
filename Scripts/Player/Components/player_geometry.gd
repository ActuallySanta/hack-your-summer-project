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

## Layers of breakable blocks. As far as the player is concerned a block is part of the
## foreground -- one you can climb is a ledge, one in the way is in the way -- whichever
## layer it happens to be drawn on.
const BREAKABLE_GROUP := &"BreakAbles"

## Any other tile layer a room wants the vault to treat as solid. Put the layer in this
## group in the editor; nothing else needs wiring.
const MANTLE_GROUP := &"MantleGeometry"

## How far inside a cell's top edge [method has_solid_top] samples for solid.
const TOP_PROBE_DEPTH := 3.0

## Where across a cell's width [method has_solid_top] samples, as fractions of the
## cell. The ends are inset so a tile that is solid across its top still passes when
## its neighbour is empty and the query lands a hair over the seam.
const TOP_PROBE_SPREAD : Array[ float ] = [ 0.12, 0.3, 0.5, 0.7, 0.88 ]

## How many overlaps [method shape_is_blocked] will look through. More than one,
## because the first few can all be one-way platforms it has to see past.
const MAX_SHAPE_HITS := 8

static func foreground(tree: SceneTree) -> TileMapLayer:
	return tree.get_first_node_in_group(GEOMETRY_GROUP) as TileMapLayer

## The cell of [param layer] that [param global_point] falls in.
static func map_coords(layer: TileMapLayer, global_point: Vector2) -> Vector2i:
	if layer == null:
		return Vector2i.MIN
	return layer.local_to_map(layer.to_local(global_point))

## Every tile layer the vault treats as solid: the room's foreground, its breakable
## blocks, and anything in [constant MANTLE_GROUP].
##
## [param visible_only] leaves out hidden layers, for asking what can be climbed onto:
## rooms toggle layers for animation, and a layer nobody can see is not somewhere to
## vault to. What is [i]in the way[/i] is a different question, because hiding a
## [TileMapLayer] does not switch its collision off -- that is
## [member TileMapLayer.collision_enabled] -- so a hidden layer can still be something
## the player would come up inside.
static func solid_layers(tree: SceneTree, visible_only := true) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	for group in [GEOMETRY_GROUP, BREAKABLE_GROUP, MANTLE_GROUP]:
		for node in tree.get_nodes_in_group(group):
			var layer := node as TileMapLayer
			if layer == null or found.has(layer):
				continue
			if visible_only and not layer.is_visible_in_tree():
				continue
			found.append(layer)
	return found

## True when any of [param layers] has a tile drawn at [param global_point].
##
## A cheap "is anything drawn here" test and nothing more: it says nothing about whether
## what is there has a collider. Asked by world position rather than by cell, because
## layers from two rooms can be loaded at once and only share a grid within a room.
static func has_tile_at(layers: Array[TileMapLayer], global_point: Vector2) -> bool:
	for layer in layers:
		if layer.get_cell_source_id(map_coords(layer, global_point)) != -1:
			return true
	return false

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
		if _hit_blocks_sideways(hit, global_point):
			return true
	return false

## True when [param shape], placed at [param transform], overlaps anything that could
## actually hold the player out of that space.
##
## The shape-sized [method is_blocking_wall], and it exists for the same reason: a
## one-way platform is a collider like any other, so a plain
## [method PhysicsDirectSpaceState2D.intersect_shape] counts the underside of a crate
## as a ceiling. That is what put the player into a crawl every time they walked past a
## shelf of them.
##
## A tile hit is answered by the cells the shape covers rather than by the hit itself,
## because a [TileMapLayer] reports the whole quadrant as one body -- see
## [method _coords_for_tile_hit] for the same problem in the point version.
static func shape_is_blocked(world: World2D, shape: Shape2D, transform: Transform2D, mask: int, exclude: Array[RID] = []) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = exclude

	var bounds := transform * shape.get_rect()
	for hit in world.direct_space_state.intersect_shape(query, MAX_SHAPE_HITS):
		var tiles := hit.get("collider") as TileMapLayer
		if tiles == null:
			if not _hit_shape_is_one_way(hit):
				return true
		elif _layer_blocks_rect(tiles, bounds):
			return true
	return false

static func _layer_blocks_rect(layer: TileMapLayer, bounds: Rect2) -> bool:
	var first := map_coords(layer, bounds.position)
	var last := map_coords(layer, bounds.end)
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var coords := Vector2i(x, y)
			# Borders excluded, so a collider resting exactly on a cell's edge is
			# beside that cell rather than inside it.
			if tile_blocks(layer, coords) and cell_rect(layer, coords).intersects(bounds):
				return true
	return false

static func _hit_blocks_sideways(hit: Dictionary, global_point: Vector2) -> bool:
	var tiles := hit.get("collider") as TileMapLayer
	if tiles == null:
		# A plain body. One-way is a per-shape flag on CollisionShape2D/CollisionPolygon2D;
		# a body whose hit shape is one-way is no more a wall than a one-way tile is.
		return not _hit_shape_is_one_way(hit)
	return tile_blocks(tiles, _coords_for_tile_hit(tiles, hit, global_point))

## Which cell a tile hit actually came from.
##
## [b]Not from the body RID.[/b] A [TileMapLayer] merges every cell in a physics
## quadrant into a single body, so one RID stands for a whole block of tiles and
## [method TileMapLayer.get_coords_for_body_rid] answers with the quadrant's first
## cell -- almost always an empty one, which has no tile data and so reads as "not
## one-way". That is why a one-way platform still counted as a wall however carefully
## it was checked: the cell being asked about was never the cell that was hit.
##
## The queried point is inside the tile whose collider answered, so the cell it falls
## in is the answer. The RID stays as a fallback for a probe sitting exactly on a seam,
## where the point lands in the empty cell next door.
static func _coords_for_tile_hit(layer: TileMapLayer, hit: Dictionary, global_point: Vector2) -> Vector2i:
	var coords := map_coords(layer, global_point)
	if layer.get_cell_tile_data(coords) != null:
		return coords
	return layer.get_coords_for_body_rid(hit.get("rid", RID()))

static func _hit_shape_is_one_way(hit: Dictionary) -> bool:
	var body := hit.get("collider") as CollisionObject2D
	if body == null:
		return false
	var owner_id: int = body.shape_find_owner(hit.get("shape", 0))
	var shape_node := body.shape_owner_get_owner(owner_id)
	return shape_node != null and shape_node.get("one_way_collision") == true

## True when the tile at [param coords] carries collision that can stop something from
## any direction -- a wall, a ceiling, a floor you cannot pass through.
##
## Two kinds of cell answer false, for different reasons. A one-way tile only ever
## stops a body coming at it from its one blocking direction, so it is not a wall to
## stand against and not a ceiling to crouch under. A tile drawn with no collision
## polygon at all is decoration, and blocks nothing whatever it looks like.
static func tile_blocks(layer: TileMapLayer, coords: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(coords)
	if data == null or layer.tile_set == null:
		return false

	for physics_layer in layer.tile_set.get_physics_layers_count():
		for polygon in data.get_collision_polygons_count(physics_layer):
			if not data.is_collision_polygon_one_way(physics_layer, polygon):
				return true
	return false

## True when the cell at [param coords] of [param grid] is solid right across its top
## face, and one of [param layers] has a tile there.
##
## The plain "is there a tile here" test is not enough to mantle on: a decorative
## tile has no collider at all, and a half-height or sloped tile only covers part of
## its cell, so a vault onto it lands the player inside the geometry or in mid-air.
## Sampling across the whole top edge is what makes a partial tile fail the test --
## which is the rare case where a mantle onto nothing used to be possible.
static func has_solid_top(world: World2D, grid: TileMapLayer, layers: Array[TileMapLayer], coords: Vector2i, mask: int, exclude: Array[RID] = []) -> bool:
	if grid == null:
		return false
	var rect := cell_rect(grid, coords)
	if not has_tile_at(layers, rect.get_center()):
		return false

	var probe_y := rect.position.y + TOP_PROBE_DEPTH
	for fraction in TOP_PROBE_SPREAD:
		var probe := Vector2(rect.position.x + rect.size.x * fraction, probe_y)
		if not is_point_solid(world, probe, mask, exclude):
			return false
	return true

## True when nothing in [param cells] of [param grid] is solid, so there is room to
## come up into it. Only cells where one of [param layers] has a tile are checked.
static func are_cells_clear(world: World2D, grid: TileMapLayer, layers: Array[TileMapLayer], cells: Array[Vector2i], mask: int, exclude: Array[RID] = []) -> bool:
	if grid == null:
		return true
	for coords in cells:
		var rect := cell_rect(grid, coords)
		if not has_tile_at(layers, rect.get_center()):
			continue
		# A tile that is drawn but has no collider (decoration in front of a gap) is
		# not in the way, so the collider is what is asked about rather than the cell.
		for fraction in TOP_PROBE_SPREAD:
			var probe := Vector2(rect.position.x + rect.size.x * fraction, rect.get_center().y)
			if is_point_solid(world, probe, mask, exclude):
				return false
	return true
