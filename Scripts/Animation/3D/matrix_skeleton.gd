class_name MatrixSkele extends Skeleton3D

## Helper script to find the position of bones of the skeleton 

var name_to_index : Dictionary[ String, int ]

func _ready() -> void:
	print(get_bone_count())
	for i in get_bone_count():
		name_to_index[ get_bone_name( i ) ] = i


## Finds the tip of a bone in 3D global space
func get_bone_pos_from_index(bone_index: int) -> Vector3:
	return (global_transform * get_bone_global_pose(bone_index)).origin

## Finds the tip of a bone in 3D global space
func get_bone_pos_from_name(bone_name: String) -> Vector3:
	return get_bone_pos_from_index( name_to_index[ bone_name ] )
