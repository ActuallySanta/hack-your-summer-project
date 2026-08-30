class_name RepairerSpriteAnimator extends Sprite2D

const SPRITE_COORD_ACCESS_VECTORS : Dictionary[ StringName, Vector2i ] = {
	"UP": Vector2i(2, 2),
	"UR": Vector2i(0, 2),
	"RI": Vector2i(3, 2),
	"DR": Vector2i(0, 1),
	"DO": Vector2i(2, 1),
	"DL": Vector2i(1, 1),
	"LE": Vector2i(3, 1),
	"UL": Vector2i(1, 2)
}

## The drone with its thrusters off. Not a direction, so it is not in the table above
## and is only ever reached through [method show_deactivated].
const DEACTIVATED_COORDS := Vector2i(0, 0)

const DIRS_ACCESS : Array[ StringName ] = [
	"UP",
	"UR",
	"RI",
	"DR",
	"DO",
	"DL",
	"LE",
	"UL"
]

var dirs : Array[ Vector2 ] = [ 
	Vector2.UP, 
	Vector2(1,-1).normalized(), # UP RIGHT
	Vector2.RIGHT, 
	Vector2(1,1).normalized(),  # DOWN RIGHT
	Vector2.DOWN, 
	Vector2(-1,1).normalized(), # DOWN LEFT
	Vector2.LEFT, 
	Vector2(-1,-1).normalized() # UP LEFT
]

var sprite_velocity_helper : StringName
var dirty : bool = false

func _process(delta: float) -> void:
	if dirty:
		frame_coords = SPRITE_COORD_ACCESS_VECTORS[ sprite_velocity_helper ]
		dirty = false
	

## Shows the powered-down frame and clears any direction still waiting to be applied,
## so a stun that lands in the same frame as a heading change still reads as stunned.
func show_deactivated() -> void:
	dirty = false
	frame_coords = DEACTIVATED_COORDS

## Sets the Direction, minor optimization to
## avoid going the full way around the circle when not needed
func get_closest_dir(normalized_vector: Vector2) -> void:
	var closest_dist : float = INF
	var closest_dir : StringName = "UP"
	for i in dirs.size():
		var current_dist = (normalized_vector - dirs[ i ]).length()
		if current_dist < closest_dist:
			closest_dist = current_dist
			closest_dir = DIRS_ACCESS[ i ]
	
	dirty = true
	sprite_velocity_helper = closest_dir
