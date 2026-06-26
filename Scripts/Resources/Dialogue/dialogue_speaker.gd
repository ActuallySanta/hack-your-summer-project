class_name DialogueSpeaker
extends Resource

enum Emotions{
	Neutral,
	Happy,
	Angry,
	Sad,
	Annoyed
}

@export var characterPortraits : Dictionary[Emotions,Texture2D]
@export var speakingSFX : AudioStream
@export var speakerName: String
