extends TileMapLayer

const OFFSETS = [ Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

## Converts types of tile interactions to their atlas y-coord
const NAME_TO_ATLAS : Dictionary[ StringName, int ] = {
	"any": 0, 
	"wrench": 1,
	"plasma_bullet": 2,
	"stun_bullet": 3,
	"step_on_tile": 4,
}
const READABLE :Dictionary[ int, StringName ] = {
	0: "any", 
	1:"wrench",
	2:"plasma_bullet",
	3:"stun_bullet",
	4:"step_on_tile",
}

@export var destroy_neighbors : bool = false
@export var destruction_offset_seconds : float = 0.1
var list_of_broken_cords : Array[ BreakableTileData ]

func _perform_test() -> void:
	print(" == Breakable Test ==")
	var breakable_test : BreakableTileData = BreakableTileData.new(Vector2i(12, 1), 0, Vector2i.ZERO, 0.3)
	set_cell_with(breakable_test.coord, breakable_test.get_default())
	for i in 30:
		print(breakable_test)
		await get_tree().create_timer(0.1).timeout
		var out = breakable_test.iterate(0.1)
		if out > 4:
			out = 8 - out
		elif out == -2:
			set_cell_with(breakable_test.coord, breakable_test.get_default())
			break
		set_cell_with(breakable_test.coord, Vector2i(out, breakable_test.break_type))
	
	print("Test complete: ", breakable_test)

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
		
		set_cell_with( tile_data.coord, Vector2i( index, tile_data.break_type ) )
	
	# Descending, so removing one index doesn't shift the ones still to come.
	to_remove.reverse()
	for i in to_remove:
		list_of_broken_cords.remove_at( i )

func set_cell_with(coords: Vector2i, index: Vector2i) -> void:
	set_cell( coords, 0, index )

## The area a cell covers, in this layer's local space.
func cell_rect(coords: Vector2i) -> Rect2:
	var size := Vector2( tile_set.tile_size )
	# map_to_local returns the centre of the cell.
	return Rect2( map_to_local( coords ) - size * 0.5, size )


## Sets up a tile to be broken
func destroy_tile(coords: Vector2i, attempt_type: StringName, foreground : TileMapLayer) -> void:
	# base case(s)
	if not does_tile_exist( coords ):
		return
	for i in list_of_broken_cords:
		if i.coord == coords:
			return
	
	foreground.set_cell(coords, -1)
	var atlas_coords = get_cell_atlas_coords( coords )
	if atlas_coords.y != 0 and atlas_coords.y != NAME_TO_ATLAS[ attempt_type ]:
		print("Can't break a ", READABLE[ atlas_coords.y ], " with a ", attempt_type )
		return
	list_of_broken_cords.append( BreakableTileData.new( coords, atlas_coords.y ) )
	
	# Handle neighbor destruction
	if not destroy_neighbors:
		return
	await get_tree().create_timer(destruction_offset_seconds).timeout
	# recursive case(s)
	for i in OFFSETS:
		destroy_tile( coords + i, attempt_type, foreground )

func does_tile_exist(coords: Vector2i) -> bool:
	return get_cell_source_id( coords ) != -1
