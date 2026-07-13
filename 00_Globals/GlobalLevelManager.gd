extends Node

var curr_tilemap_bounds : Array[ Vector2 ]
var checkpoint_room : String
var checkpoint_pos : Vector2
var checkpoint_facing_left : bool

signal TileMapBoundsChanged( bounds : Array[ Vector2 ] )

func ChangeTilemapBounds( bounds : Array[ Vector2 ] ) -> void:
	curr_tilemap_bounds = bounds
	TileMapBoundsChanged.emit( bounds )

func set_checkpoint(room: String, pos: Vector2, facing_left: bool):
	checkpoint_room = room
	checkpoint_pos = pos
	checkpoint_facing_left = facing_left
