extends SubViewportContainer

@onready var matrix_model_skeleton := $SubViewport/Matrix/Armature/Skeleton3D
@onready var colliders := $Colliders
@onready var camera := $SubViewport/Camera3D

var size_of_cam : Vector2
var num_bones : int = 29

func _ready() -> void:
	print("== Begin test ==")
	size_of_cam = camera.get_camera_size_in_world()
	# -- THIS IS A TEST RUN --
	for i in num_bones:
		print("  Update: ", i)
		update_bone( i )
	
	print("Done test!")

func update_bone(index: int) -> void:
	print("    Getting 3d...")
	var bone_pos_3d = matrix_model_skeleton.get_bone_pos_from_index(index)
	print("    Convert to 2d...")
	var bone_pos_2d = convert_2D_to_3D( bone_pos_3d )
	print("    Setting pos...")
	colliders.set_bone_pos( index, bone_pos_2d )

## Using the dimensions of the camera and the dimensions of the viewport,
## combined with the knowledge that the topleft of both should be (0,0),
## we can transform the position of a bone relative to the camera
## into the 2D space of the subviewportContainer
func convert_2D_to_3D(position3D: Vector3) -> Vector2:
	var pos_as_raw_2D : Vector2 = Vector2(position3D.x, position3D.y)
	var adjusted_for_camera_size = pos_as_raw_2D / size_of_cam
	return pos_as_raw_2D * size
