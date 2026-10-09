class_name AlphaOccilator extends Occilator

@export var starting_alpha : float
@export var end_alpha : float

func setup() -> void:
	pass

func occilate() -> void:
	modulate.a = lerp(starting_alpha, end_alpha, occilation_sin)
