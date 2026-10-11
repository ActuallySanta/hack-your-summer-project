class_name DifficultyManager extends Node

static func get_curr_diff() -> DifficultyID: return Difficulty.current_difficulty
static func get_curr_setting() -> DifficultyType: return Difficulty.get_setting()
static func scale_with_mode(base_value: float, factor: float) -> float:  
	return get_curr_diff() * factor + base_value
static func pick_from_difficulty(set_of_choices: Array): 
	var index : int = get_curr_diff()
	index = clamp( index, 0, set_of_choices.size() - 1 )
	return set_of_choices[ get_curr_diff() ]

enum DifficultyID {
	Easy,
	Standard,
	Hard,
	BullShit,
}

var _diff_settings : Dictionary[ DifficultyID, DifficultyType ] = {
	DifficultyID.Easy : DifficultyType.new(true, false, 1.0, 2.0, 3.0, 1.5),
	DifficultyID.Standard : DifficultyType.new(true, false, 1.0, 1.0, 1.5, 1.0),
	DifficultyID.Hard : DifficultyType.new(true, true, 3.0/2, 1/3.0, 1.0, 0.9),
	DifficultyID.BullShit : DifficultyType.new(false, true, 4, 0.5, 0.75, 0.8),
}

var current_difficulty : DifficultyID = DifficultyID.Standard

func get_setting() -> DifficultyType: 
	return _diff_settings[ current_difficulty ]
