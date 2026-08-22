@tool
class_name ManualAnim extends Sprite2D

const ANIM_FRAME_SECONDS := 0.1

@export var anim_offset : Vector2i = Vector2i(0,0)
@export var anim_jump : int = 1
@export var frames_in_sequence : int = 4
@export var anim_speed_adjust : float = 1
@export var start_paused : bool = false:
		set(new_value):
			start_paused = new_value
			make_paused(new_value)

@export var reset : bool = false:
	set(value):
		if value == true:
			anim_frame = 0
			timer = 0

var is_anim_paused : bool
var timer : float
var anim_frame : int

func iteration() -> void:
	frame_coords = Vector2i(anim_offset.x + (anim_frame * anim_jump), anim_offset.y)

func _ready() -> void:
	is_anim_paused = start_paused
	anim_frame = 0
	timer = 0.0

func _process(delta: float) -> void:
	if is_anim_paused:
		return
	timer -= delta
	while timer < 0:
		anim_frame = (anim_frame + 1) % frames_in_sequence
		iteration()
		timer += max(ANIM_FRAME_SECONDS, anim_speed_adjust)

#region Getters and Setters

func make_paused(paused_state: bool) -> void:
	is_anim_paused = paused_state

func set_anim_mode(new_y_level: int) -> void:
	anim_offset.y = max(0, new_y_level)

func set_horizontal_offset(new_offset: int) -> void:
	anim_offset.x = new_offset

#endregion
