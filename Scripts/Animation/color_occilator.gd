class_name ColorOccilator extends Occilator

@export_group("Color")
@export var start_color : Color
@export var end_color : Color

func setup() -> void:
	pass

func occilate() -> void:
	modulate = start_color.lerp(end_color, occilation_sin * occilation_sin)
