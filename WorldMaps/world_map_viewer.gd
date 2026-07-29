extends Node2D

@export var moveSpeed : float = 5
@export var fastMoveSpeed : float = 20

var _bounds : Rect2
var _camera : Camera2D
var _position 

func _ready() -> void:
	await get_tree().process_frame
	_camera = get_viewport().get_camera_2d()
	
	var combined_rect: Rect2
	var first = true
	
	for node in get_tree().current_scene.get_children():
		if not (node is Sprite2D or node is TextureRect):
			continue
		
		# Get local rect and transform it to global/world space
		var global_rect = node.get_global_transform() * node.get_rect()
		if first:
			combined_rect = global_rect
			first = false
		else:
			combined_rect = combined_rect.merge(global_rect)
			
	_bounds = combined_rect


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
		print("No cam.")
		return
	
	var cam_pos := _camera.global_position
	var movement_vector : Vector2
	if Input.is_action_pressed("Left"):
		movement_vector.x -= 1
	if Input.is_action_pressed("Right"):
		movement_vector.x += 1
	if Input.is_action_pressed("Up"):
		movement_vector.y -= 1
	if Input.is_action_pressed("Down"):
		movement_vector.y += 1
	
	cam_pos += movement_vector.normalized() * (moveSpeed if Input.is_action_pressed("Jump") else fastMoveSpeed)
	var adjusted = cam_pos.clamp(_bounds.position, _bounds.end)
	_camera.global_position = cam_pos
	
	if Input.is_action_just_pressed("Scroll Up"):
		_camera.zoom += Vector2(0.5, 0.5)
	elif Input.is_action_just_pressed("Scroll Down"):
		_camera.zoom -= Vector2(0.5, 0.5)
