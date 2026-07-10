class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://esk4fom87pxl" #Cryo Room
const START_POS = Vector2(1000, 483)
const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

@onready var _camera : Camera2D = $Camera2D
@onready var _player : Player = $Player
@onready var _hud : GameHUD = $HUD

@export var cameraDeadzone := Vector2(0, 0)
@export var artificial_load_time := 2.0
@export var use_custom_save := false
@export_file var save_room := START_ROOM_UID
@export var save_pos := Vector2(3000, 483)
@export var save_has_jetpack : bool

var save

func _ready() -> void:
	_hud.show_load_screen()
	_init_metsys_and_objects()
	await _load_game()
	_hud.hide_load_screen()

#initialize metsys and its modules
func _init_metsys_and_objects() -> void:
	MetSys.reset_state()
	set_player(_player)
	add_module("RoomTransitions.gd")
	MetSys.room_changed.connect(_on_room_changed)
	_player.pickup_collected.connect(_on_pickup_collected)
	#prevent player from acting while game is loading
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.reset_all_inputs()

func _load_game() -> void:
	print("Begin load")
	# save.load_from_text should automatically call MetSys.set_save_data()
	# but if there's no save data (i.e. it's a fresh save), that won't happen
	# so set empty save data first to make sure there's at least something
	MetSys.set_save_data()
	if use_custom_save:
		_load_custom_save()
	else:
		save = SaveManager.new()
		save.load_from_text(get_save_path(0))
		
	if save.get_value("jetpack_collected", false):
		_player.enable_jetpack()
	else:
		_player.disable_jetpack()
	var room_id = save.get_value("current_room", START_ROOM_UID)
	await load_room(room_id)
	_player.position = save.get_value("player_pos", START_POS)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	print("Finish load")
	await get_tree().create_timer(artificial_load_time).timeout

func _load_custom_save() -> void:
	save = SaveManager.new()
	if save_room:
		save.set_value("current_room", save_room)
	save.set_value("player_pos", save_pos)
	save.set_value("jetpack_collected", save_has_jetpack)

func get_save_path(save_index: int) -> StringName:
	return "user://save" + str(save_index) +".sav"

func _on_room_changed(new_room: String) -> void:
	save.set_value("current_room", new_room)
	print("Entering room " + new_room)

func _on_pickup_collected(pickup: Pickup) -> void:
	match pickup.type:
		Pickup.PickupType.Jetpack:
			save.set_value("jetpack_collected", true)
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
	
	if Input.is_action_just_pressed(&"debug_save"):
		save_game(0)

#Add any other variables you need as you save them, they will be saved as a dictionary
func save_game(saveIndex: int) -> void:
	print("Saving")
	save.set_value("player_pos", _player.position)
	save.save_as_text("user://save" + str(saveIndex) +".sav")
