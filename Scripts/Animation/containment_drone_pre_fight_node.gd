class_name CDPreFightNode extends Node2D

@export var audioStream : AudioStreamPlayer2D

var _one_use_trigger : Area2D
var _cleared_nodes : Dictionary[ StringName, bool] = {
	"audio": false,
	"mute_trigger": false,
}

## Checks if any child needs to be cleared
func is_empty() -> bool:
	for i in _cleared_nodes:
		if not _cleared_nodes[ i ]:
			return false
	
	return true

func _clear_item(key: StringName) -> void:
	_cleared_nodes[ key ] = true
	if is_empty():
		queue_free()

func rawr() -> void:
	audioStream.play()
	await audioStream.finished
	audioStream.queue_free()
	_clear_item( "audio" )

func attach_collider(trigger: Area2D) -> void:
	if trigger == null:
		return
	trigger.body_entered.connect(area_collision)
	_one_use_trigger = trigger

func area_collision(_body: Node2D) -> void:
	MusicManager.set_background_track_from_name("NONE", "")
	_one_use_trigger.queue_free()
	_clear_item( "mute_trigger" )
