extends Area2D
@export var loadedConversation : Dialogue_Conversation
@export var chooseToStart : bool = false
@export var canReRead: bool = false
@export var hasBeenRead: bool = false
var inRange: bool = false

func _on_body_entered(body: Node2D) -> void:
	if(body is Player):
		inRange = true

func _input(event: InputEvent) -> void:
	if(inRange and !PlayerManager.inDialogue and (canReRead or (!canReRead and !hasBeenRead))):
		if(!chooseToStart or (event.is_action_pressed("Dialogue Begin") and chooseToStart)):
			hasBeenRead = true
			GlobalSignals.OnDialogueBegin.emit(loadedConversation)
		


func _on_body_exited(body: Node2D) -> void:
	if(body is Player):
		inRange = false
