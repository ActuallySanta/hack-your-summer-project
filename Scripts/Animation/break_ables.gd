extends TileMapLayer

const OFFSETS = [ Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

@export var destroy_neighbors : bool = false
@export var destruction_offset_seconds : float = 0.1
var list_of_broken_cords : Array[ BreakableTileData ]

func _process(delta: float) -> void:
	var to_remove : Array[ int ]
	# Go over array
	for i in list_of_broken_cords.size():
		# Grt data and iterate
		var tile_data = list_of_broken_cords[ i ]
		var iteration_result = tile_data.iterate( delta )
		
		if iteration_result == -1:
			continue
		var index : int = -1
		if iteration_result == -2: # If should regen, make it so and remove
			if PlayerOverlap.with_rect( cell_rect( tile_data.coord ), global_transform ):
				# The block would reappear inside the player, so break it again
				# and let it run the whole animation before trying once more.
				tile_data.reset()
				index = 1
			else:
				index = 0
				to_remove.append( i )
		elif iteration_result < 6:
			index =  iteration_result + 1
		elif iteration_result > 6:
			index = 5 - (iteration_result - 8)
		
		set_cell( tile_data.coord, 0, Vector2i( index, 0) )
	
	# Descending, so removing one index doesn't shift the ones still to come.
	to_remove.reverse()
	for i in to_remove:
		list_of_broken_cords.remove_at( i )

## The area a cell covers, in this layer's local space.
func cell_rect(coords: Vector2i) -> Rect2:
	var size := Vector2( tile_set.tile_size )
	# map_to_local returns the centre of the cell.
	return Rect2( map_to_local( coords ) - size * 0.5, size )


## Sets up a tile to be broken
func destroy_tile(coords: Vector2i, foreground : TileMapLayer) -> void:
	# base case(s)
	if not does_tile_exist( coords ):
		return
	for i in list_of_broken_cords:
		if i.coord == coords:
			return
	
	# Algorithm
	foreground.set_cell(coords, -1)
	var atlas_coords = get_cell_atlas_coords( coords )
	set_cell( coords, 0, Vector2i(1,0))
	list_of_broken_cords.append( BreakableTileData.new( coords, atlas_coords) )
	if not destroy_neighbors:
		return
	
	await get_tree().create_timer(destruction_offset_seconds).timeout
	# recursive case(s)
	
	for i in OFFSETS:
		destroy_tile( coords + i, foreground )

func does_tile_exist(coords: Vector2i) -> bool:
	return get_cell_source_id( coords ) != -1
