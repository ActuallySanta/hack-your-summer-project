class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://esk4fom87pxl" #Cryo Room
const START_POS = Vector2(1000, 483)
const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

@onready var _player : Player = $Player
@onready var _camera : Camera2D = $Camera2D
@onready var _hud : GameHUD = $HUD

@export var cameraDeadzone := Vector2(0, 0)
@export var death_respawn_delay := 2.0
@export var artificial_load_time := 0.0
@export var allow_save_anywhere := false
@export var use_custom_save := false
@export_file var save_room := START_ROOM_UID
@export var save_pos := Vector2(3000, 483)
@export var save_has_jetpack : bool

var save
var isInGame : bool = false

func _ready() -> void:
	_hud.start_new_game.connect(_new_game)
	_hud.load_game.connect(_load_game)
	_hud.quit_game.connect(get_tree().quit)
	_init_metsys_and_objects()
	isInGame = false
	#if using a custom save, skip the main menu and head straight to the game
	if use_custom_save:
		_load_game()
	else:
		_hud.show_menu(GameHUD.MenuType.MainMenu)

#initialize metsys and its modules
func _init_metsys_and_objects() -> void:
	MetSys.reset_state()
	set_player(_player)
	add_module("RoomTransitions.gd")
	MetSys.room_changed.connect(_on_room_changed)
	_player.pickup_collected.connect(_on_pickup_collected)
	_player.save_station_used.connect(save_game.bind(0))
	#prevent player from acting while game is loading
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.reset_all_inputs()

func _load_game() -> void:
	_hud.hide_menus()
	_hud.show_load_screen()
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
	await get_tree().create_timer(artificial_load_time).timeout
	_player.global_position = save.get_value("player_pos", START_POS)
	LevelManager.set_checkpoint(room_id, _player.position, false)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	isInGame = true
	_hud.hide_load_screen()


func _new_game():
	_hud.hide_menus()
	_hud.show_load_screen()
	MetSys.set_save_data()
	save = SaveManager.new()
	_player.disable_jetpack()
	await load_room(START_ROOM_UID)
	await get_tree().create_timer(artificial_load_time).timeout
	_player.global_position = START_POS
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	isInGame = true
	_hud.hide_load_screen()

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
			PlayerManager.player.enable_jetpack()
			var checkpoint := get_tree().get_first_node_in_group(&"jetpack_checkpoint") as Node2D
			if checkpoint:
				LevelManager.set_checkpoint(MetSys.get_current_room_name(), checkpoint.global_position, true)
		_:
			print("No action defined for pickup " + pickup.get_type_as_str())

func _process(_delta: float) -> void:
	
	if(!isInGame):
		return
	MetSys.get_current_room_instance().adjust_camera_limits(_camera)
	var camPos := _camera.position
	var playerPos := PlayerManager.player.position
	var posDiff := camPos - playerPos
	if abs(posDiff.x) > cameraDeadzone.x:
		camPos.x = playerPos.x + (cameraDeadzone.x * sign(posDiff.x))
	if abs(posDiff.y) > cameraDeadzone.y:
		camPos.y = playerPos.y + (cameraDeadzone.y * sign(posDiff.y))
	_camera.position = camPos
	
	if allow_save_anywhere and Input.is_action_just_pressed(&"debug_save"):
		save_game(0)

#Add any other variables you need as you save them, they will be saved as a dictionary
func save_game(save_index: int, set_checkpoint := true) -> void:
	print("Saving")
	save.set_value("player_pos", PlayerManager.player.global_position)
	save.save_as_text("user://save" + str(save_index) +".sav")
	if not set_checkpoint:
		return
		
	var checkpoint := get_tree().get_first_node_in_group(&"save_checkpoint") as Node2D
	if not checkpoint:
		printerr("Checkpoint not found in save room. Player will not return here on death.")
		return
	LevelManager.set_checkpoint(MetSys.get_current_room_name(), checkpoint.global_position, false)

func respawn_player_at_checkpoint() -> void:
	await load_room(LevelManager.checkpoint_room)
	PlayerManager.player.global_position = LevelManager.checkpoint_pos
	PlayerManager.player._facingRight = !LevelManager.checkpoint_facing_left
	PlayerManager.player.respawn()

func _on_player_death(_anim_duration: float) -> void:
	await get_tree().create_timer(death_respawn_delay).timeout
	_hud.fade_in_death_screen()
	await _hud.death_screen_fade_complete
	await respawn_player_at_checkpoint()
	_hud.fade_out_death_screen()
	

func end_game():
	PlayerManager.player.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.show_load_screen()
	_hud.show_menu(GameHUD.MenuType.GameComplete)
	_hud.hide_load_screen()
