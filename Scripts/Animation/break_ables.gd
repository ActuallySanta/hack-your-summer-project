extends TileMapLayer

var list_of_broken_cords : Array[ BreakableTileData ]

func _process(delta: float) -> void:
	var to_remove : Array[ int ]
	# Go over array
	for i in list_of_broken_cords.size():
		# Grt data and iterate
		var tile_data = list_of_broken_cords[ i ]
		var iteration_result = tile_data.iterate( delta )
		
		if iteration_result == -10:
			continue
		var index : int = -1
		if iteration_result == -5:
			index = 1
		elif iteration_result == -4:
			index = 2
		elif iteration_result == -3:
			index = 3
		elif iteration_result == -2:
			index = 4
		elif iteration_result == -1:
			index = 5
		elif iteration_result == 1: # If destroyed make it so
			index = 6
		elif iteration_result == 2: # If should regen, make it so and remove
			index = 0
			to_remove.append( i )
		
		set_cell( tile_data.coord, 0, Vector2i( index, 0) )
	
	for i in to_remove:
		list_of_broken_cords.remove_at( i )

## Sets up a tile to be broken
func destroy_tile(coords: Vector2i) -> void:
	var atlas_coords = get_cell_atlas_coords( coords )
	for i in list_of_broken_cords:
		if i.coord == coords:
			return
	
	set_cell( coords, 0, Vector2i(1,0))
	list_of_broken_cords.append( BreakableTileData.new( coords, atlas_coords) )
	print("  Setup complete!")
