class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://esk4fom87pxl" #Cryo Room

@onready var camera : Camera2D = $Camera2D

@export var cameraDeadzone := Vector2(0, 0)

func _ready() -> void:
	_init_metsys()
	_load_game()

#initialize metsys and its modules
func _init_metsys() -> void:
	MetSys.reset_state()
	set_player($Player)
	add_module("RoomTransitions.gd")
	MetSys.room_changed.connect(_on_room_changed)

func _load_game() -> void:
	MetSys.set_save_data() #insert MetSys save data here
	load_room(START_ROOM_UID)

func _on_room_changed(_new_room: String) -> void:
	pass

func _process(_delta: float) -> void:
	MetSys.get_current_room_instance().adjust_camera_limits(camera)
	var camPos := camera.position
	var playerPos := player.position
	var posDiff := camPos - playerPos
	print("posDiff: " + str(posDiff))
	if abs(posDiff.x) > cameraDeadzone.x:
		print("Adjusting cam X")
		camPos.x = playerPos.x + (cameraDeadzone.x * sign(posDiff.x))
	if abs(posDiff.y) > cameraDeadzone.y:
		print("Adjusting cam X")
		camPos.y = playerPos.y + (cameraDeadzone.y * sign(posDiff.y))
	camera.position = camPos
