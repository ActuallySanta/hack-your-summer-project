class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://esk4fom87pxl" #Cryo Room

@onready var _camera : Camera2D = $Camera2D
@onready var _player : Player = $Player

@export var cameraDeadzone := Vector2(0, 0)

func _ready() -> void:
	_init_metsys_and_objects()
	_load_game()

#initialize metsys and its modules
func _init_metsys_and_objects() -> void:
	MetSys.reset_state()
	set_player(_player)
	add_module("RoomTransitions.gd")
	MetSys.room_changed.connect(_on_room_changed)
	_player.pickup_collected.connect(_on_pickup_collected)

func _load_game() -> void:
	MetSys.set_save_data() #insert MetSys save data here
	load_room(START_ROOM_UID)

func _on_room_changed(_new_room: String) -> void:
	pass

func _on_pickup_collected(pickup: Pickup) -> void:
	match pickup.type:
		Pickup.PickupType.Jetpack:
			_player.enable_jetpack()
		_:
			print("No action defined for pickup " + pickup.get_type_as_str())

func _process(_delta: float) -> void:
	MetSys.get_current_room_instance().adjust_camera_limits(_camera)
	var camPos := _camera.position
	var playerPos := _player.position
	var posDiff := camPos - playerPos
	if abs(posDiff.x) > cameraDeadzone.x:
		camPos.x = playerPos.x + (cameraDeadzone.x * sign(posDiff.x))
	if abs(posDiff.y) > cameraDeadzone.y:
		camPos.y = playerPos.y + (cameraDeadzone.y * sign(posDiff.y))
	_camera.position = camPos
