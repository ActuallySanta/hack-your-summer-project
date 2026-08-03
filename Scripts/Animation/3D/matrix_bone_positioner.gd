extends SubViewportContainer

@onready var sub_viewport := $SubViewport
@onready var matrix_model_skeleton := $SubViewport/Matrix/Armature/Skeleton3D
@onready var colliders := $Colliders
@onready var camera : Camera3D = $SubViewport/Camera3D

var size_of_cam : Vector2

func _ready() -> void:
	size_of_cam = camera.get_camera_size_in_world()

func _process(_delta: float) -> void:
	for i in matrix_model_skeleton.get_bone_count():
		update_bone( i )

func update_bone(index: int) -> void:
	var bone_pos_3d : Vector3 = matrix_model_skeleton.get_bone_pos_from_index(index)
	colliders.set_bone_pos(index, convert_3D_to_2D(bone_pos_3d, size_of_cam))

## Since camera will never change dimenstions, 
## and SubViewportContainer will also never change dimensions,
## and we know for an absolute fact that they are supposed to represent
## sane area of space,we can just transform the coordinates of position 
## in the camera
func convert_3D_to_2D(position3D: Vector3, cam_size: Vector2) -> Vector2:
	# Into camera space, so the camera's position and rotation are accounted for.
	var local := camera.global_transform.affine_inverse() * position3D
	# Normalise to -0.5..0.5, flipping Y because 3D is Y-up and 2D is Y-down.
	var ndc := Vector2(local.x / cam_size.x, -local.y / cam_size.y)
	return (ndc + Vector2(0.5, 0.5)) * size
