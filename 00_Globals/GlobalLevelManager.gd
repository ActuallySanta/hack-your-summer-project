extends Node

var curr_tilemap_bounds : Array[ Vector2 ]
signal TileMapBoundsChanged( bounds : Array[ Vector2 ] )

func ChangeTilemapBounds( bounds : Array[ Vector2 ] ) -> void:
	curr_tilemap_bounds = bounds
	TileMapBoundsChanged.emit( bounds )
