extends Occilator

@export var peak : float = 1.5
@export var dip : float = 0.5

func setup() -> void:
	peak = (peak - dip) * 0.5 # Since we're doing stupid maths add this helpful factor


func occilate() -> void:
	scale.y = (occilation_sin + 1) * peak + dip
