class_name DifficultyManager extends Node

signal on_difficulty_changed

const EASY : DifficultyID = DifficultyID.Easy
const STANDARD : DifficultyID = DifficultyID.Standard
const HARD : DifficultyID = DifficultyID.Hard
const BULLSHIT : DifficultyID = DifficultyID.BullShit

static func is_higher_than(difficulty_level: DifficultyID) -> bool: return Difficulty.current_difficulty > difficulty_level
static func is_lower_than(difficulty_level: DifficultyID) -> bool: return Difficulty.current_difficulty < difficulty_level
static func is_at_least(difficulty_level: DifficultyID) -> bool: return Difficulty.current_difficulty >= difficulty_level
static func is_at_most(difficulty_level: DifficultyID) -> bool: return Difficulty.current_difficulty <= difficulty_level

static func get_curr_diff() -> DifficultyID: return Difficulty.current_difficulty
static func get_curr_setting() -> DifficultyType: return Difficulty.get_setting()
static func scale_with_mode(base_value: float, factor: float) -> float: return get_curr_diff() * factor + base_value
static func pick_from_difficulty(set_of_choices: Array): 
	var index : int = get_curr_diff()
	index = clamp( index, 0, set_of_choices.size() - 1 )
	return set_of_choices[ index ]

enum DifficultyID {
	Easy,
	Standard,
	Hard,
	BullShit,
}

var _diff_settings : Dictionary[ DifficultyID, DifficultyType ] = {
	DifficultyID.Easy : DifficultyType.new(true, false, 1.0, 2.0, 3.0, 1.5, 6),
	DifficultyID.Standard : DifficultyType.new(true, false, 1.0, 1.0, 1.5, 1.0, 5),
	DifficultyID.Hard : DifficultyType.new(true, true, 3.0/2, 1/3.0, 1.0, 0.9, 4),
	DifficultyID.BullShit : DifficultyType.new(false, true, 2, 0.6, 0.75, 0.8, 3),
}

var current_difficulty : DifficultyID = DifficultyID.Standard

func get_setting() -> DifficultyType: 
	return _diff_settings[ current_difficulty ]

func _input(event: InputEvent) -> void:
	if not Cheats.cheats: return
	if not event is InputEventKey: return
	if not event.is_pressed(): return
	var selection : int = event.keycode - 49
	if selection < 0 or selection >= DifficultyID.size(): return
	current_difficulty = selection as DifficultyID
	on_difficulty_changed.emit()
