## Walkable routes through the room the player is currently in.
##
## Anything that has to cross a room without flying through its walls asks here for a
## list of points to travel along, instead of carrying a copy of the grid and the A*
## that goes with it. One grid is built per room and shared, so a room full of drones
## costs the same to path as a room with one.
##
## [b]What counts as a wall[/b] is the [constant WALL_GROUP] group: every
## [TileMapLayer] in it is blocked ground, and nothing else is. No node here is named
## or exported anywhere -- a room becomes pathable by putting its solid tile layers in
## that group in the editor, the same way [code]"Geometry"[/code] already marks the
## layers the player collides with.
##
## [b]When the grid is rebuilt.[/b] Never on a timer. It is marked stale when MetSys
## changes room ([signal MetroidvaniaSystem.room_changed]) or when [method mark_dirty]
## is called, and the rebuild itself happens on the next call to [method find_path].
## That matters because a room change is announced before the new room's scene has
## finished loading: rebuilding on the signal would read the room being torn down.
## Waiting until someone actually asks means the layers we read are the ones in the
## tree right now. The set of layers in the group is compared on every request too, so
## a room whose layers appear late -- or a wall destroyed and removed -- is picked up
## without anyone having to say so.
##
## [b]If there is no grid[/b] (no room loaded, no layer in the group, or the target
## walled off), [method find_path] answers with the destination on its own. Callers
## then head straight at it, which is what they would have done without a pathfinder
## and is always safe to follow.
extends Node

#region Configuration

## The group holding every [TileMapLayer] that blocks pathfinding.
const WALL_GROUP := &"PathFindingWalls"

## Cost of a step to an edge-sharing neighbour. Paired with [constant DIAGONAL_COST]
## as a 10:14 approximation of 1:sqrt(2), kept in integers so A* never accumulates
## float error.
const STRAIGHT_COST := 10
## Cost of a step to a corner-sharing neighbour.
const DIAGONAL_COST := 14

## How far out [method _nearest_walkable_cell] will search for open ground, in cells.
## Only reached when the asker or its target is standing inside a wall; a bigger
## radius would let a body buried deep in solid rock path out of it, which is not
## worth spending a search on.
const NEAREST_WALKABLE_RADIUS := 16

const _NEIGHBOUR_OFFSETS : Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

#endregion

#region The grid

## Emitted after the grid has been rebuilt, whether or not it found any walls.
signal grid_rebuilt

## Open ground, indexed [code][x][y][/code] from [member _origin]. [code]true[/code]
## is walkable. Empty when there is nothing to path over.
var _walkable : Array[Array]

## Cell coordinates of [code]_walkable[0][0][/code], in [member _reference]'s grid.
var _origin : Vector2i
var _size : Vector2i

## The layer whose grid every cell coordinate here is expressed in. Layers can sit at
## different scales and offsets, so one of them has to be the authority and the rest
## are mapped onto it.
var _reference : TileMapLayer

## The layers the current grid was built from, in the order they were read. Compared
## against the group on every request to notice a room that has swapped underneath us.
var _layers : Array[TileMapLayer]

var _dirty : bool = true

func _ready() -> void:
	# Deferred for the same reason the grid is built lazily: the room named by this
	# signal is not in the tree yet when it fires.
	MetSys.room_changed.connect(_on_room_changed, CONNECT_DEFERRED)

func _on_room_changed(_new_room: String) -> void:
	mark_dirty()

## Throws the current grid away. The next [method find_path] reads the room again.
## Call this after changing the world in a way that adds or removes solid tiles.
func mark_dirty() -> void:
	_dirty = true

#endregion

#region Asking for a route

## Points to travel through to get from [param from] to [param to] without crossing a
## wall, the destination last and the starting point never included.
##
## Only the corners are returned -- the cells where the route changes direction --
## because the straight runs between them need no steering. The final point is
## [param to] exactly rather than the centre of the cell it stands in, so arriving at
## the end of the path means arriving at the thing that was asked for.
##
## Answers [code][ to ][/code] when it cannot do better than a straight line: no room
## loaded, no walls in [constant WALL_GROUP], or nothing walkable joining the two.
func find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var direct : Array[Vector2] = [to]
	_ensure_grid()
	if _walkable.is_empty():
		return direct

	var start := _nearest_walkable_cell(global_to_cell(from))
	var goal := _nearest_walkable_cell(global_to_cell(to))
	if start == Vector2i.MAX or goal == Vector2i.MAX:
		return direct

	var cells := _find_cell_path(start, goal)
	if cells.is_empty():
		return direct

	var turns := _cells_to_turns(cells)
	if turns.is_empty():
		return direct
	turns[turns.size() - 1] = to
	return turns

## Whether a grid exists to path over. A caller that behaves differently when there is
## nothing to route around can ask, but it does not have to: [method find_path] is
## safe to call either way.
func has_grid() -> bool:
	_ensure_grid()
	return not _walkable.is_empty()

## Whether [param global_pos] is standing in open ground. False when there is no grid,
## which is the same answer a position outside the mapped room gets.
func is_walkable_position(global_pos: Vector2) -> bool:
	_ensure_grid()
	if _walkable.is_empty():
		return false
	return _is_walkable(global_to_cell(global_pos))

## The cell of the current grid that [param global_pos] falls in. Only meaningful
## while a grid exists; mostly useful for debug drawing.
func global_to_cell(global_pos: Vector2) -> Vector2i:
	if not is_instance_valid(_reference):
		return Vector2i.MAX
	return _reference.local_to_map(_reference.to_local(global_pos))

## The centre of [param cell], in world coordinates.
func cell_to_global(cell: Vector2i) -> Vector2:
	if not is_instance_valid(_reference):
		return Vector2.ZERO
	return _reference.to_global(_reference.map_to_local(cell))

#endregion

#region Building the grid

## Rebuilds the grid if the room has changed since it was built.
##
## The comparison is against the group itself rather than against the MetSys room
## name, because the group is what the grid is actually made of: a layer freed with
## the old room, or added after the load finished, changes the answer even when the
## room name has not moved.
func _ensure_grid() -> void:
	var layers := _current_wall_layers()
	if not _dirty and layers == _layers:
		return
	_rebuild(layers)

## Every live [TileMapLayer] in [constant WALL_GROUP].
##
## Nodes on their way out are skipped: during a room transition the room being freed
## and the room being loaded are both in the tree for a moment, and merging the two
## would put the old room's walls into the new room's grid.
func _current_wall_layers() -> Array[TileMapLayer]:
	var layers : Array[TileMapLayer] = []
	for node in get_tree().get_nodes_in_group(WALL_GROUP):
		var layer := node as TileMapLayer
		if layer == null or layer.is_queued_for_deletion() or not layer.is_inside_tree():
			continue
		layers.append(layer)
	return layers

## Bool grid covering every wall layer; [code]false[/code] means a tile occupies that
## cell. Sized to the tiles that exist, so an empty room costs nothing.
func _rebuild(layers: Array[TileMapLayer]) -> void:
	_dirty = false
	_layers = layers
	_walkable = []
	_size = Vector2i.ZERO
	_reference = null
	if layers.is_empty():
		grid_rebuilt.emit()
		return

	_reference = layers[0]
	var blocked := {}
	var minimum := Vector2i.MAX
	var maximum := Vector2i.MIN
	for layer in layers:
		for cell in layer.get_used_cells():
			var mapped : Vector2i = cell
			if layer != _reference: # Other layers can sit on a different transform
				mapped = _reference.local_to_map(_reference.to_local(layer.to_global(layer.map_to_local(cell))))
			blocked[mapped] = true
			minimum.x = mini(minimum.x, mapped.x)
			minimum.y = mini(minimum.y, mapped.y)
			maximum.x = maxi(maximum.x, mapped.x)
			maximum.y = maxi(maximum.y, mapped.y)
	if blocked.is_empty():
		_reference = null
		grid_rebuilt.emit()
		return

	_origin = minimum
	_size = maximum - minimum + Vector2i.ONE
	for x in _size.x:
		var column : Array[bool] = []
		column.resize(_size.y)
		column.fill(true)
		_walkable.append(column)
	for cell in blocked:
		var local : Vector2i = cell - _origin
		_walkable[local.x][local.y] = false
	grid_rebuilt.emit()

func _is_walkable(cell: Vector2i) -> bool:
	var local : Vector2i = cell - _origin
	if local.x < 0 or local.y < 0 or local.x >= _size.x or local.y >= _size.y:
		return false # Outside of the mapped room
	return _walkable[local.x][local.y]

## Closest open cell to the one given, so a body or a target standing inside a wall
## can still be pathed to. [constant Vector2i.MAX] when there is none within
## [constant NEAREST_WALKABLE_RADIUS].
func _nearest_walkable_cell(cell: Vector2i) -> Vector2i:
	if cell == Vector2i.MAX:
		return Vector2i.MAX
	if _is_walkable(cell):
		return cell
	for radius in range(1, NEAREST_WALKABLE_RADIUS + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			for y in range(cell.y - radius, cell.y + radius + 1):
				if absi(x - cell.x) != radius and absi(y - cell.y) != radius:
					continue # Only the ring at this radius
				var candidate := Vector2i(x, y)
				if _is_walkable(candidate):
					return candidate
	return Vector2i.MAX

#endregion

#region A*

## A* over the open cells, returning every cell walked with the start included, or
## nothing when the goal is walled off.
func _find_cell_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		return [start]

	var came_from := {}
	var cost_so_far := {start: 0}
	var visited := {}
	var frontier : Array[Vector3i] = []
	_heap_push(frontier, Vector3i(_heuristic(start, goal), start.x, start.y))

	while frontier.size() > 0:
		var top := _heap_pop(frontier)
		var current := Vector2i(top.y, top.z)
		if visited.has(current):
			continue
		visited[current] = true
		if current == goal:
			return _reconstruct_cells(came_from, current)

		for offset in _NEIGHBOUR_OFFSETS:
			var next : Vector2i = current + offset
			if not _is_walkable(next):
				continue
			var diagonal : bool = offset.x != 0 and offset.y != 0
			if diagonal: # Never squeeze through the corner between two tiles
				if not _is_walkable(Vector2i(current.x + offset.x, current.y)):
					continue
				if not _is_walkable(Vector2i(current.x, current.y + offset.y)):
					continue
			var step : int = DIAGONAL_COST if diagonal else STRAIGHT_COST
			var tentative : int = cost_so_far[current] + step
			if cost_so_far.has(next) and tentative >= cost_so_far[next]:
				continue
			cost_so_far[next] = tentative
			came_from[next] = current
			_heap_push(frontier, Vector3i(tentative + _heuristic(next, goal), next.x, next.y))

	return [] # Walled off from the target

## Octile distance, in the same 10:14 units the steps are counted in, so it never
## overestimates and A* stays optimal.
func _heuristic(from: Vector2i, to: Vector2i) -> int:
	var dx : int = absi(to.x - from.x)
	var dy : int = absi(to.y - from.y)
	return STRAIGHT_COST * (dx + dy) + (DIAGONAL_COST - 2 * STRAIGHT_COST) * mini(dx, dy)

func _reconstruct_cells(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var cells : Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
	return cells

## Keeps only the cells where the route changes direction, plus the final one. The
## start is dropped: whoever asked is already standing there.
func _cells_to_turns(cells: Array[Vector2i]) -> Array[Vector2]:
	var turns : Array[Vector2] = []
	if cells.size() < 2:
		if cells.size() == 1:
			turns.append(cell_to_global(cells[0]))
		return turns

	for i in range(1, cells.size()):
		var direction : Vector2i = cells[i] - cells[i - 1]
		var is_last : bool = i == cells.size() - 1
		if is_last or (cells[i + 1] - cells[i]) != direction:
			turns.append(cell_to_global(cells[i]))
	return turns

#endregion

#region Binary heap

# A plain array kept as a min-heap on the priority packed into x, with the cell in y
# and z. Godot has no priority queue, and re-sorting the frontier on every push costs
# more than maintaining the heap does.

func _heap_push(heap: Array[Vector3i], item: Vector3i) -> void:
	heap.append(item)
	var i : int = heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent : int = (i - 1) / 2
		if heap[parent].x <= heap[i].x:
			return
		var swap : Vector3i = heap[parent]
		heap[parent] = heap[i]
		heap[i] = swap
		i = parent

func _heap_pop(heap: Array[Vector3i]) -> Vector3i:
	var top : Vector3i = heap[0]
	var last : Vector3i = heap.pop_back()
	if heap.is_empty():
		return top

	heap[0] = last
	var i : int = 0
	while true:
		var smallest : int = i
		var left : int = i * 2 + 1
		var right : int = left + 1
		if left < heap.size() and heap[left].x < heap[smallest].x:
			smallest = left
		if right < heap.size() and heap[right].x < heap[smallest].x:
			smallest = right
		if smallest == i:
			break
		var swap : Vector3i = heap[smallest]
		heap[smallest] = heap[i]
		heap[i] = swap
		i = smallest
	return top

#endregion
