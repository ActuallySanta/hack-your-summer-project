extends Area2D

func _ready() -> void:
	var tile_map = get_parent() 
	if not tile_map or not tile_map.has_method("get_used_rect"):
		return
		
	var used_rect: Rect2i = tile_map.get_used_rect()
	var cell_size: Vector2 = tile_map.tile_set.tile_size
	
	var map_local_pos: Vector2 = Vector2(used_rect.position) * cell_size
	var map_pixel_size: Vector2 = Vector2(used_rect.size) * cell_size
	
	var shape_node = $CollisionShape2D
	
	# FIX: Break resource sharing so the shape responds to unique sizing/positioning
	if shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate()
		
	if shape_node.shape is RectangleShape2D:
		shape_node.shape.size = map_pixel_size
		shape_node.position = Vector2.ZERO # Forces it to stay glued to the Area2D center
	
	position = map_local_pos + (map_pixel_size / 2.0)
