class_name DifficultyManager extends Node

enum DifficultyID {
	Easy,
	Standard,
	Hard,
	BullShit
}

var _diff_settings : Dictionary[ DifficultyID, DifficultyType ] = {
	DifficultyID.Easy : DifficultyType.new(true, false, 1.0, 2.0, 3.0, 1.5),
	DifficultyID.Standard : DifficultyType.new(true, false, 1.0, 1.0, 1.5, 1.0),
	DifficultyID.Hard : DifficultyType.new(true, true, 3.0/2, 0.5, 1.0, 0.9),
	DifficultyID.BullShit : DifficultyType.new(false, true, 4, 1/3.0, 0.75, 0.8),
}

var current_difficulty : DifficultyID

func get_setting() -> DifficultyType: 
	return _diff_settings[ current_difficulty ]
