extends Camera3D

## A Helper script that lets you get the orthographic camera's width and height in pixels

func get_camera_size_in_world() -> Vector2:
	var aspect = get_viewport().get_visible_rect().size.aspect()
	
	var cam_width: float
	var cam_height: float
	
	if keep_aspect == Camera3D.KEEP_HEIGHT:
		cam_height = size
		cam_width = size * aspect
	else:
		cam_width = size
		cam_height = size / aspect
		
	return Vector2(cam_width, cam_height)
