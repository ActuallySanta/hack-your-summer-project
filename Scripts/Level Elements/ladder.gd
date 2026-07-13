extends Node2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if(body is Player):
		PlayerManager.player.canClimb = true
		PlayerManager.player.disable_jetpack()
	pass # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
	if(body is Player):
		PlayerManager.player.canClimb = false
		PlayerManager.player.enable_jetpack()
	pass # Replace with function body.
