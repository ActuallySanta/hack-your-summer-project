extends Control

@onready var dialogue_box: Control = $"Dialogue Box"
@onready var speaker_portait: TextureRect = $"Dialogue Box/Speaker Portait"
@onready var dialogue_text: Label = $"Dialogue Box/Dialogue Text"
@onready var speaker_name: Label = $"Dialogue Box/Background/Speaker Name"


var conversationContents : Array[String]
var conversationSpeaker : Array[DialogueSpeaker]
var conversationSpeakerEmotion : Array[DialogueSpeaker.Emotions]

var isSpeaking : bool = false

func _input(event: InputEvent) -> void:
	if(isSpeaking and event.is_action_pressed("Dialogue Continue")):
		PresentLine()

func _ready() -> void:
	GlobalSignals.OnDialogueBegin.connect(BeginDialogue)
	dialogue_box.visible = false

func BeginDialogue(_conversation : Dialogue_Conversation):
	dialogue_box.visible = true
	isSpeaking = true
	print(_conversation.conversationContents)
	for entry in _conversation.conversationContents:
		conversationContents.push_back(entry.entryText)
		conversationSpeaker.push_back(entry.speaker)
		conversationSpeakerEmotion.push_back(entry.speakerEmotion)
	PresentLine()
	pass

func PresentLine():
	if(conversationContents.size() == 0):
		EndDialogue()
		return
	
	print(conversationContents.size())
	dialogue_text.text = conversationContents.pop_front()
	
	var speaker : DialogueSpeaker = conversationSpeaker.pop_front()
	var speakerEmotion : DialogueSpeaker.Emotions = conversationSpeakerEmotion.pop_front()
	speaker_name.text = speaker.speakerName
	
	#Gets the correct image based on the given emotion
	speaker_portait.texture = speaker.characterPortraits[speakerEmotion]
	

func EndDialogue():
	isSpeaking = false
	dialogue_box.visible = false
	GlobalSignals.OnDialogueEnd.emit()
	pass
