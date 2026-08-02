class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://esk4fom87pxl" #Cryo Room
const START_POS = Vector2(1000, 483)
const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

const PICKUP_FUSE_ID = "Fuse"
const PICKUP_GUN_ID = "Gun"
const PICKUP_JETPACK_ID = "Jetpack"

@onready var _player : Player = $Player
@onready var _camera : Camera2D = $Camera2D
@onready var _hud : GameHUD = $HUD

@export var cameraDeadzone := Vector2(0, 0)
## How quickly the camera eases out of soft (non-rectangular) boundaries.
## Higher is snappier, lower is smoother. This is the "soft" end of the scale;
## each boundary's own [member SoftCameraBoundary.resistance] blends between this
## smoothing (0.0) and an instant, uncrossable push-out (1.0).
@export var cameraSoftSmoothing := 10.0
## When a camera-path projection jumps farther than this (pixels) in one frame,
## ease across it over [member cameraPathSmoothTime] instead of snapping. Below it,
## normal following stays crisp; jumps bigger than a screen (room changes) snap.
@export var cameraPathJumpThreshold := 48.0
## Seconds to ease across a detected camera-path corner jump.
@export var cameraPathSmoothTime := 0.5
@export var death_respawn_delay := 2.0
@export var artificial_load_time := 0.0
@export var allow_save_anywhere := false
@export var use_custom_save := false
@export_file var save_room := START_ROOM_UID
@export var save_pos := Vector2(3000, 483)
@export_enum("Uncollected", "Collected", "Powered") var save_fuse_state : int
@export var save_has_gun : bool
@export var save_has_jetpack : bool

var save : SaveManager
var isInGame : bool = false
var paused : bool = false
# Camera-path jump smoothing state (see _smooth_path_jump).
var _path_pos: Vector2
var _path_from: Vector2
var _path_active := false
var _path_elapsed := 0.0
var _path_initialized := false

# I know this is just replicating the global script feature, but 
# this way allows us to still easily use the custom save system
static var instance : GameManager

func _ready() -> void:
	if !instance:
		instance = self
	else:
		printerr("Multiple GameManager instances detected")
	_hud.start_new_game.connect(_new_game)
	_hud.load_game.connect(_load_game)
	_hud.quit_game.connect(get_tree().quit)
	_hud.resume_game.connect(resume_game)
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
	_player.death_start.connect(_on_player_death)
	#prevent player from acting while game is loading
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.reset_all_inputs()
	
	GlobalSignals.RestoreStationPower.connect(_restore_station_power)

func _load_game() -> void:
	get_tree().paused = false
	paused = false
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
		
	if is_object_collected(PICKUP_JETPACK_ID):
		_player.enable_jetpack()
	else:
		_player.disable_jetpack()
		
	if is_object_collected(PICKUP_GUN_ID):
		player.enable_gun()
	else:
		player.disable_gun()
	
	var room_id = save.get_value("current_room", START_ROOM_UID)
	await load_room(room_id)
	await get_tree().create_timer(artificial_load_time).timeout
	_player.global_position = save.get_value("player_pos", START_POS)
	LevelManager.set_checkpoint(room_id, _player.position, false)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	isInGame = true
	_hud.hide_load_screen()


func _new_game():
	get_tree().paused = false
	paused = false
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
	save.set_value("current_room", save_room)
	save.set_value("player_pos", save_pos)
	print(save_fuse_state)
	save.set_value("station_powered", save_fuse_state == 2)
	
	if save_fuse_state > 0:
		MetSys.save_data.stored_objects[PICKUP_FUSE_ID] = true
	if save_has_gun:
		MetSys.save_data.stored_objects[PICKUP_GUN_ID] = true
	if save_has_jetpack:
		MetSys.save_data.stored_objects[PICKUP_JETPACK_ID] = true
	

func get_save_path(save_index: int) -> StringName:
	return "user://save" + str(save_index) +".sav"

func pause_game() -> void:
	get_tree().paused = true
	_hud.show_menu(GameHUD.MenuType.Pause)
	paused = true

func resume_game() -> void:
	get_tree().paused = false
	_hud.hide_menus()
	paused = false

func _on_room_changed(new_room: String) -> void:
	save.set_value("current_room", new_room)
	# Force the camera-path smoother to snap on the next frame instead of sliding
	# across the room boundary during a transition.
	_path_initialized = false
	#print("Entering room " + new_room)

func _on_pickup_collected(pickup: Pickup) -> void:
	match pickup.type:
		Pickup.PickupType.Jetpack:
			_player.enable_jetpack()
			var checkpoint := get_tree().get_first_node_in_group(&"jetpack_checkpoint") as Node2D
			if checkpoint:
				LevelManager.set_checkpoint(MetSys.get_current_room_name(), checkpoint.global_position, true)
		Pickup.PickupType.Fuse:
			pass
		Pickup.PickupType.StunGun:
			_player.enable_gun()
		_:
			print("No action defined for pickup " + pickup.get_type_as_str())

func _restore_station_power() -> void:
	save.set_value("station_powered", true)

func _process(_delta: float) -> void:
	
	if(!isInGame):
		return
	MetSys.get_current_room_instance().adjust_camera_limits(_camera)
	var camPos := _camera.position
	var playerPos := _player.position
	var posDiff := camPos - playerPos
	if abs(posDiff.x) > cameraDeadzone.x:
		camPos.x = playerPos.x + (cameraDeadzone.x * sign(posDiff.x))
	if abs(posDiff.y) > cameraDeadzone.y:
		camPos.y = playerPos.y + (cameraDeadzone.y * sign(posDiff.y))
	camPos = _apply_soft_camera_bounds(camPos, _delta)
	camPos = _apply_camera_path_bounds(camPos, _delta)
	_camera.position = camPos
	
	if allow_save_anywhere and Input.is_action_just_pressed(&"debug_save"):
		save_game(0)
	if Input.is_action_just_pressed("pause"):
		if paused:
			resume_game()
		else:
			pause_game()
		

static func is_object_collected(name : String) -> bool:
	if !MetSys.save_data:
		print("No save data found, cannot determine object collection status.")
		return false
	return MetSys.save_data.stored_objects.get(name, false)

static func is_station_powered() -> bool:
	if !instance or !instance.save:
		print("No save data found, cannot determine power status.")
		return false
	return instance.save.get_value("station_powered")

#region Soft camera bounds
## Pushes the camera centre out of any registered non-rectangular soft boundaries,
## while keeping the visible rectangle inside the room's hard (rectangular) limits.
## The hard limits always win, so a soft bound can never expose out-of-room space.
##
## Each boundary owns its own smoothing and blends it with the instant push-out by
## its [member SoftCameraBoundary.resistance], so a rigid boundary keeps the camera
## out for any reason while soft ones ease in and out of corners. Corrections are
## measured from the hard-clamped baseline, so they stay stateless and jitter-free.
func _apply_soft_camera_bounds(cam_center: Vector2, delta: float) -> Vector2:
	var boundaries := get_tree().get_nodes_in_group(SoftCameraBoundary.GROUP)
	# adjust_camera_limits() was already called this frame, so the limits are current.
	var hard_rect := Rect2(
		_camera.limit_left, _camera.limit_top,
		_camera.limit_right - _camera.limit_left,
		_camera.limit_bottom - _camera.limit_top)
	var half_view := _camera.get_viewport_rect().size * 0.5 / _camera.zoom

	# Crisp hard clamp is the baseline every boundary's correction is measured against.
	var hard := _clamp_view_to_rect(cam_center, half_view, hard_rect)

	var correction := Vector2.ZERO
	for boundary in boundaries:
		correction += (boundary as SoftCameraBoundary).get_correction(hard, half_view, delta, cameraSoftSmoothing)

	# Final hard clamp is instant, so no boundary's correction can expose a hard bound.
	return _clamp_view_to_rect(hard + correction, half_view, hard_rect)

## Confines the camera centre to any registered camera-path boundaries (the
## alternative approach: the polygon dictates where the centre may go), then
## re-applies the rectangular hard bounds so they remain the final authority.
func _apply_camera_path_bounds(cam_center: Vector2, delta: float) -> Vector2:
	var boundaries := get_tree().get_nodes_in_group(CameraPathBoundary.GROUP)
	if boundaries.is_empty():
		# Re-arm so re-entering a path room snaps rather than smoothing from a stale pos.
		_path_initialized = false
		return cam_center

	var result := cam_center
	for boundary in boundaries:
		result = (boundary as CameraPathBoundary).constrain_center(result)

	var hard_rect := Rect2(
		_camera.limit_left, _camera.limit_top,
		_camera.limit_right - _camera.limit_left,
		_camera.limit_bottom - _camera.limit_top)
	var half_view := _camera.get_viewport_rect().size * 0.5 / _camera.zoom
	var target := _clamp_view_to_rect(result, half_view, hard_rect)
	return _smooth_path_jump(target, half_view, delta)

## Band-aid smoothing for the camera-path projection: normal following passes
## through untouched, but a jump larger than [member cameraPathJumpThreshold]
## (yet smaller than a screen — i.e. not a room-change teleport) is eased across
## over [member cameraPathSmoothTime] seconds so corners don't snap.
func _smooth_path_jump(target: Vector2, half_view: Vector2, delta: float) -> Vector2:
	# Jumps bigger than roughly half a screen are teleports (room change / respawn) -> snap.
	var snap_limit := half_view.length()

	if not _path_initialized:
		_path_pos = target
		_path_initialized = true
		_path_active = false
		return _path_pos

	var jump := target.distance_to(_path_pos)

	if _path_active:
		if jump > snap_limit:
			_path_active = false
			_path_pos = target
			return _path_pos
		_path_elapsed += delta
		var t := 1.0 if cameraPathSmoothTime <= 0.0 else clampf(_path_elapsed / cameraPathSmoothTime, 0.0, 1.0)
		_path_pos = _path_from.lerp(target, smoothstep(0.0, 1.0, t))
		if t >= 1.0:
			_path_active = false
			_path_pos = target
		return _path_pos

	if jump > cameraPathJumpThreshold and jump <= snap_limit:
		# Begin easing across this corner jump (and take the first step now).
		_path_active = true
		_path_from = _path_pos
		_path_elapsed = delta
		var t := 1.0 if cameraPathSmoothTime <= 0.0 else clampf(_path_elapsed / cameraPathSmoothTime, 0.0, 1.0)
		_path_pos = _path_from.lerp(target, smoothstep(0.0, 1.0, t))
		return _path_pos

	# Small everyday follow, or an outright teleport -> track exactly.
	_path_pos = target
	return _path_pos

## Clamps a camera centre so its view rectangle stays within [param rect].
## If the room is smaller than the view on an axis, the view is centred there.
func _clamp_view_to_rect(center: Vector2, half_view: Vector2, rect: Rect2) -> Vector2:
	var result := center
	var lo := rect.position + half_view
	var hi := rect.end - half_view
	if lo.x <= hi.x:
		result.x = clampf(center.x, lo.x, hi.x)
	else:
		result.x = (rect.position.x + rect.end.x) * 0.5
	if lo.y <= hi.y:
		result.y = clampf(center.y, lo.y, hi.y)
	else:
		result.y = (rect.position.y + rect.end.y) * 0.5
	return result
#endregion

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
