class_name State extends Node

# Stores a reference to the player that this state belongs to
static var player : Player 

func _ready() -> void:
	pass # Replace with function body.


## what happens when the player enters this State?
func Enter() -> void:
	pass

## what happens when the player exits this State?
func Exit() -> void:
	pass
	
func Process(_delta : float ) -> State:
	return null
	
func Physics(_delta : float ) -> State:
	return null
	
func HandleInput(_event : InputEvent ) -> State:
	return null
