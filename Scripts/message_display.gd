class_name MsgQueue extends Node

var _queued_messages : Array[ String ]

#region Message management
func has_message() -> bool:
	return _queued_messages.size() > 0

func append_message(new_msg: String) -> void:
	_queued_messages.push_back(new_msg)

func get_front_message() -> String:
	return _queued_messages[ 0 ]

func pop_next() -> String:
	return _queued_messages.pop_at( 0 )
#endregion

#region Common Text appendings
func add_log_pop_up(log_name: String) -> void:
	append_message("_dot  $HIGH_ON Logging Data... $ $NEWLINE, " + log_name)

func add_using_map(area_name: String) -> void:
	append_message("_circ  Downloading $HIGH_ON " + area_name + " $ Map Data...")

func add_saving_data() -> void:
	append_message("_box  Saving Game...")
