extends BrightnessOccilator

@export_group("Color")
@export var start_color : Color
@export var end_color : Color

func _ready() -> void:
	_half_cycle_timer = cycle_seconds / 2
	_start_color = start_color
	_end_color = end_color
	_occilation_amount = TAU / cycle_seconds
