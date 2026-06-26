extends Area2D
@export var loadedConversation : Dialogue_Conversation

var inRange: bool = false

func _on_body_entered(body: Node2D) -> void:
	if(body is Player):
		inRange = true

func _input(event: InputEvent) -> void:
	if(event.is_action_pressed("Dialogue Begin") and inRange and !PlayerManager.inDialogue):
		print("Began Dialogue")
		GlobalSignals.OnDialogueBegin.emit(loadedConversation)
		


func _on_body_exited(body: Node2D) -> void:
	if(body is Player):
		inRange = false
