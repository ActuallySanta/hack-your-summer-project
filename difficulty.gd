class_name DifficultyManager extends Node

signal on_difficulty_changed

enum DifficultyID {
	Easy,
	Standard,
	Hard,
	BullShit
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

func is_at_least(difficulty_level: DifficultyID) -> bool: return current_difficulty >= difficulty_level
func is_higher_than(difficulty_level: DifficultyID) -> bool: return current_difficulty > difficulty_level
func is_at_most(difficulty_level: DifficultyID) -> bool: return current_difficulty <= difficulty_level
func is_lower_than(difficulty_level: DifficultyID) -> bool: return current_difficulty < difficulty_level

func _input(event: InputEvent) -> void:
	if not Cheats.cheats: return
	if not event is InputEventKey: return
	if not event.is_pressed(): return
	var selection : int = event.keycode - 49
	if selection < 0 or selection >= DifficultyID.size(): return
	current_difficulty = selection as DifficultyID
	on_difficulty_changed.emit()
