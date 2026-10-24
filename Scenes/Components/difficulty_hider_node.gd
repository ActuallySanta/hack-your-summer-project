## Nodes under this object only appear if the current difficulty is in the difficulty array
##
class_name DifficultySelector extends Node2D

@export_enum("Easy","Standard", "Hard", "Bullshit") var difficulty : Array[ int ]

func _ready() -> void:
	var choosen_options := difficulty as Array[ Difficulty.DifficultyID ]
	var current_difficulty := Difficulty.current_difficulty
	for option in choosen_options:
		if current_difficulty == option:
			visible = true
			modulate.a = 1.0
			return
	queue_free()
