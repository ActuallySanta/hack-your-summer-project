extends Camera3D

## A Helper script that lets you get the orthographic cameras
## width and height in world units

func get_camera_size_in_world() -> Vector2:
	# This just checks if somethings is true, if it's not CRASH
	assert(projection == Camera3D.PROJECTION_ORTHOGONAL,
		"get_camera_size_in_world() is only meaningful for an orthographic camera.")
	var aspect := get_viewport().get_texture().get_size().aspect()

	var cam_width: float
	var cam_height: float
	
	if keep_aspect == Camera3D.KEEP_HEIGHT:
		cam_height = size
		cam_width = size * aspect
	else:
		cam_width = size
		cam_height = size / aspect
		
	return Vector2(cam_width, cam_height)
