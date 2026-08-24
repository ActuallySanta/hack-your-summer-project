class_name PieRand extends Node

static func Roll(options: Dictionary) -> Variant:
	var total := 0.0
	for weight in options.values():
		total += weight
	
	var roll := randf_range(0, total)
	
	for item in options:
		var weight : float = options[item]
		if roll < weight:
			return item
		roll -= weight
	
	return "ERROR"
