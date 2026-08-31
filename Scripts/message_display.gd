class_name MsgQueue extends Node

var _queued_messages : Array[ String ]

func append_message(new_msg: String) -> void:
	_queued_messages.push_back(new_msg)

func get_front_message() -> String:
	return _queued_messages[ 0 ]

func pop_next() -> String:
	return _queued_messages.pop_at( 0 )
