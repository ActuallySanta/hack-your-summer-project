class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://esk4fom87pxl" #Cryo Room

func _ready() -> void:
	init_metsys()
	load_game()

#initialize metsys and its modules
func init_metsys() -> void:
	MetSys.reset_state()
	set_player($Player)
	add_module("RoomTransitions.gd")

func load_game() -> void:
	MetSys.set_save_data() #insert MetSys save data here
	load_room(START_ROOM_UID)

func _process(delta: float) -> void:
	pass
