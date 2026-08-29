extends CharacterBody2D

## Step costs kept as ints so the A* search can stay integer only
const _STRAIGHT_COST : int = 10
const _DIAGONAL_COST : int = 14
const _NEIGHBOUR_OFFSETS : Array[ Vector2i ] = [
	Vector2i( 1, 0 ), Vector2i( -1, 0 ), Vector2i( 0, 1 ), Vector2i( 0, -1 ),
	Vector2i( 1, 1 ), Vector2i( 1, -1 ), Vector2i( -1, 1 ), Vector2i( -1, -1 ),
]
## How far from a blocked cell we will look for a stand-in cell
const _NEAREST_WALKABLE_RADIUS : int = 16

@export var obstacle_tilemaps : Array[ TileMapLayer ]
@export var transfer_cutoff : float = 16.0
## Fraction of speed kept when we clip a wall; 0.0 just slides along it instead.
## Middling values grind against the wall, so prefer a firm bounce or none at all
@export_range( 0.0, 1.0 ) var wall_bounce : float = 0.8

@onready var navigator := $Navigator
@onready var sprite := $Sprite2D

var room_map : Array[ Array ]
## Cell coord of room_map[ 0 ][ 0 ] in the reference tilemap's cell space
var room_map_origin : Vector2i
## Width / height of room_map in cells
var room_map_size : Vector2i
var target_node : RepairNode
var pathing_in_order : Array[ Vector2 ]

func _ready() -> void:
	navigator.ignore_target = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Get the target
	if target_node == null:
		var path = create_path()
		pathing_in_order = path
		navigator.ignore_target = true # Waypoint following only happens in manual movement
	if target_node == null or pathing_in_order.is_empty():
		return # Nothing to repair
	# Nav to target
	if close_to_pos(pathing_in_order[ 0 ]) and pathing_in_order.size() > 1:
		pathing_in_order.remove_at(0) # The last waypoint is the target, so never drop it
	navigator.set_target_pos(pathing_in_order[ 0 ])
	# Do end sequence
	if close_to_pos(target_node.global_position) and not target_node.on_repair_end.is_connected( reset ):
		target_node.start_repairs()
		navigator.ignore_target = false # Causes navigators to slow_stop
		target_node.on_repair_end.connect( reset )

## The navigator only decides a velocity; the body is what actually moves, so walls stop us
func _physics_process(_delta: float) -> void:
	var intended : Vector2 = navigator.get_nav_velocity()
	velocity = intended
	move_and_slide()

	var hit := get_last_slide_collision()
	if hit != null and wall_bounce > 0.0:
		navigator.set_nav_velocity( intended.bounce( hit.get_normal() ) * wall_bounce )
	else:
		# move_and_slide already stripped whatever was heading into the wall
		navigator.set_nav_velocity( velocity )
	navigator.set_nav_position( global_position )

func reset() -> void:
	if is_instance_valid( target_node ) and target_node.on_repair_end.is_connected( reset ):
		target_node.on_repair_end.disconnect( reset )
	target_node = null

func close_to_pos(global_pos: Vector2) -> bool:
	return (global_position - global_pos).length() <= transfer_cutoff

func create_path() -> Array[ Vector2 ]:
	if target_node == null:
		target_node = find_closest_repair_node()
	if target_node == null:
		return [ global_position ] # Nothing to repair, hold position

	var fallback : Array[ Vector2 ] = [ target_node.global_position ]
	if not _has_reference_tilemap():
		return fallback # No obstacles known, head straight at it

	if room_map.is_empty():
		build_room_map()
	if room_map.is_empty():
		return fallback

	var start := _nearest_walkable_cell( _global_to_cell( global_position ) )
	var goal := _nearest_walkable_cell( _global_to_cell( target_node.global_position ) )
	if start == Vector2i.MAX or goal == Vector2i.MAX:
		return fallback

	var cell_path := _find_cell_path( start, goal )
	if cell_path.is_empty():
		return fallback

	var path := _cells_to_turns( cell_path )
	if path.is_empty():
		return fallback
	# The end is a cord as well, but the node itself is more precise than its cell
	path[ path.size() - 1 ] = target_node.global_position
	return path

## Bool grid covering every obstacle tilemap; false means a tile occupies that cell
func build_room_map() -> void:
	room_map = []
	room_map_size = Vector2i.ZERO
	if not _has_reference_tilemap():
		return

	var reference : TileMapLayer = obstacle_tilemaps[ 0 ]
	var blocked := {}
	var minimum := Vector2i.MAX
	var maximum := Vector2i.MIN
	for layer in obstacle_tilemaps:
		if not is_instance_valid( layer ):
			continue
		for cell in layer.get_used_cells():
			var mapped := cell
			if layer != reference: # Other layers can sit on a different transform
				mapped = reference.local_to_map( reference.to_local( layer.to_global( layer.map_to_local( cell ) ) ) )
			blocked[ mapped ] = true
			minimum.x = min( minimum.x, mapped.x )
			minimum.y = min( minimum.y, mapped.y )
			maximum.x = max( maximum.x, mapped.x )
			maximum.y = max( maximum.y, mapped.y )
	if blocked.is_empty():
		return

	room_map_origin = minimum
	room_map_size = maximum - minimum + Vector2i.ONE
	for x in room_map_size.x:
		var column : Array[ bool ] = []
		column.resize( room_map_size.y )
		column.fill( true )
		room_map.append( column )
	for cell in blocked:
		var local : Vector2i = cell - room_map_origin
		room_map[ local.x ][ local.y ] = false

func _has_reference_tilemap() -> bool:
	return obstacle_tilemaps.size() > 0 and is_instance_valid( obstacle_tilemaps[ 0 ] )

func _global_to_cell(global_pos: Vector2) -> Vector2i:
	var reference : TileMapLayer = obstacle_tilemaps[ 0 ]
	return reference.local_to_map( reference.to_local( global_pos ) )

func _cell_to_global(cell: Vector2i) -> Vector2:
	var reference : TileMapLayer = obstacle_tilemaps[ 0 ]
	return reference.to_global( reference.map_to_local( cell ) )

func _is_walkable(cell: Vector2i) -> bool:
	var local : Vector2i = cell - room_map_origin
	if local.x < 0 or local.y < 0 or local.x >= room_map_size.x or local.y >= room_map_size.y:
		return false # Outside of the mapped room
	return room_map[ local.x ][ local.y ]

## Closest free cell to the one given, so a drone or node inside a wall can still path
func _nearest_walkable_cell(cell: Vector2i) -> Vector2i:
	if _is_walkable( cell ):
		return cell
	for radius in range( 1, _NEAREST_WALKABLE_RADIUS + 1 ):
		for x in range( cell.x - radius, cell.x + radius + 1 ):
			for y in range( cell.y - radius, cell.y + radius + 1 ):
				if abs( x - cell.x ) != radius and abs( y - cell.y ) != radius:
					continue # Only the ring at this radius
				var candidate := Vector2i( x, y )
				if _is_walkable( candidate ):
					return candidate
	return Vector2i.MAX

## A* over the free cells of room_map; returns every cell walked, start included
func _find_cell_path(start: Vector2i, goal: Vector2i) -> Array[ Vector2i ]:
	if start == goal:
		return [ start ]

	var came_from := {}
	var cost_so_far := { start: 0 }
	var visited := {}
	var frontier : Array[ Vector3i ] = []
	_heap_push( frontier, Vector3i( _heuristic( start, goal ), start.x, start.y ) )

	while frontier.size() > 0:
		var top := _heap_pop( frontier )
		var current := Vector2i( top.y, top.z )
		if visited.has( current ):
			continue
		visited[ current ] = true
		if current == goal:
			return _reconstruct_cells( came_from, current )

		for offset in _NEIGHBOUR_OFFSETS:
			var next : Vector2i = current + offset
			if not _is_walkable( next ):
				continue
			var diagonal : bool = offset.x != 0 and offset.y != 0
			if diagonal: # Never squeeze through the corner between two tiles
				if not _is_walkable( Vector2i( current.x + offset.x, current.y ) ):
					continue
				if not _is_walkable( Vector2i( current.x, current.y + offset.y ) ):
					continue
			var step : int = _DIAGONAL_COST if diagonal else _STRAIGHT_COST
			var tentative : int = cost_so_far[ current ] + step
			if cost_so_far.has( next ) and tentative >= cost_so_far[ next ]:
				continue
			cost_so_far[ next ] = tentative
			came_from[ next ] = current
			_heap_push( frontier, Vector3i( tentative + _heuristic( next, goal ), next.x, next.y ) )

	return [] # Walled off from the target

func _heuristic(from: Vector2i, to: Vector2i) -> int:
	var dx : int = abs( to.x - from.x )
	var dy : int = abs( to.y - from.y )
	return _STRAIGHT_COST * ( dx + dy ) + ( _DIAGONAL_COST - 2 * _STRAIGHT_COST ) * min( dx, dy )

func _reconstruct_cells(came_from: Dictionary, current: Vector2i) -> Array[ Vector2i ]:
	var cells : Array[ Vector2i ] = [ current ]
	while came_from.has( current ):
		current = came_from[ current ]
		cells.push_front( current )
	return cells

## Keeps only the cells where the path changes direction, plus the final cell
func _cells_to_turns(cells: Array[ Vector2i ]) -> Array[ Vector2 ]:
	var turns : Array[ Vector2 ] = []
	if cells.size() < 2:
		if cells.size() == 1:
			turns.append( _cell_to_global( cells[ 0 ] ) )
		return turns

	for i in range( 1, cells.size() ):
		var direction : Vector2i = cells[ i ] - cells[ i - 1 ]
		var is_last : bool = i == cells.size() - 1
		if is_last or ( cells[ i + 1 ] - cells[ i ] ) != direction:
			turns.append( _cell_to_global( cells[ i ] ) )
	return turns

func _heap_push(heap: Array[ Vector3i ], item: Vector3i) -> void:
	heap.append( item )
	var i : int = heap.size() - 1
	while i > 0:
		var parent : int = ( i - 1 ) / 2
		if heap[ parent ].x <= heap[ i ].x:
			return
		var swap : Vector3i = heap[ parent ]
		heap[ parent ] = heap[ i ]
		heap[ i ] = swap
		i = parent

func _heap_pop(heap: Array[ Vector3i ]) -> Vector3i:
	var top : Vector3i = heap[ 0 ]
	var last : Vector3i = heap.pop_back()
	if heap.is_empty():
		return top

	heap[ 0 ] = last
	var i : int = 0
	while true:
		var smallest : int = i
		var left : int = i * 2 + 1
		var right : int = left + 1
		if left < heap.size() and heap[ left ].x < heap[ smallest ].x:
			smallest = left
		if right < heap.size() and heap[ right ].x < heap[ smallest ].x:
			smallest = right
		if smallest == i:
			break
		var swap : Vector3i = heap[ smallest ]
		heap[ smallest ] = heap[ i ]
		heap[ i ] = swap
		i = smallest
	return top

func find_closest_repair_node() -> RepairNode:
	var repairable_nodes := get_tree().get_nodes_in_group("Repairable")
	if repairable_nodes.size() == 0:
		return null
	var closest : RepairNode = repairable_nodes[0]
	var dist_to_curr : float = (global_position - closest.global_position).length()
	for i in repairable_nodes:
		var dist = (global_position - i.global_position).length()
		if dist < dist_to_curr:
			closest = i
			dist_to_curr = dist
	return closest
