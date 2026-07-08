extends Node

@export var frame_count : int = 1

var _frames : Array[Node]
var _current_frame : int = 0

var activeframe : TileMapLayer:
	set(new_value):
		if activeframe:
			activeframe.visible = false
		activeframe = new_value
		activeframe.visible = true
	get:
		return activeframe

func _ready() -> void:
	_frames = get_children()

func _process(delta: float) -> void:
	activeframe = _frames[(_current_frame / frame_count) % _frames.size()]
	_current_frame += 1
