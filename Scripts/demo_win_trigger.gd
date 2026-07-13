extends Area2D

#If the player enters the area, switch to the game complete screen
func _on_body_entered(body: Node2D) -> void:
	if(body is Player):
		Game.end_game()
