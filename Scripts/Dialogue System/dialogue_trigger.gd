extends Area2D
@export var loadedConversation : Dialogue_Conversation


func _on_body_entered(body: Node2D) -> void:
	if(body is Player):
		print("Began Dialogue")
		GlobalSignals.OnDialogueBegin.emit(loadedConversation)
