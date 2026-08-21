class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://djrq87v0sx3lq" #Docking Station
const START_POS = Vector2(158, 834)
const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

const PICKUP_FUSE_ID = "Fuse"
const PICKUP_GUN_ID = "Gun"
const PICKUP_JETPACK_ID = "Jetpack"

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
@export_enum("Uncollected", "Collected", "Powered") var save_fuse_state : int
@export var save_has_gun : bool
@export var save_has_jetpack : bool
@export var save_has_plasma_gun : bool

## Player speeds above this (pixels/second) are teleports (room change, respawn),
## not travel, so they never claim a camera region.
const CAMERA_TELEPORT_SPEED := 4000.0

var save : SaveManager
var isInGame : bool = false
var paused : bool = false
# Camera axis region state (see _apply_camera_axis_regions).
var _axis_region: CameraAxisRegion = null
# Axes _axis_region drives, as CameraAxisRegion.AXIS_* flags.
var _axis_locked := CameraAxisRegion.AXIS_Y
var _axis_start := Vector2.ZERO
var _axis_progress := 0.0
var _axis_rate := 1.0
# Hand-back of locked axes to normal following, tracked per axis. _release_axes
# holds the axes still easing back, _release_ignore those among them that are
# still exempt from the hard bounds.
var _release_axes := 0
var _release_ignore := 0
var _release_start := Vector2.ZERO
var _release_progress := Vector2.ZERO
var _release_rate := Vector2.ONE
var _prev_player_pos := Vector2.ZERO
var _prev_player_valid := false
# False while a room is being swapped in and the player has not been placed in it
# yet. See _physics_tick().
var _player_positioned := false

# I know this is just replicating the global script feature, but 
# this way allows us to still easily use the custom save system
static var instance : GameManager

func _ready() -> void:
	if !instance:
		instance = self
	else:
		printerr("Multiple GameManager instances detected")
	# Regions loaded inside a room find us through this to claim the camera on
	# arrival, before the first frame in the room is drawn.
	add_to_group(CameraAxisRegion.CONTROLLER_GROUP)
	_hud.start_new_game.connect(_new_game)
	_hud.load_game.connect(_load_game)
	_hud.quit_game.connect(get_tree().quit)
	_hud.resume_game.connect(resume_game)
	GlobalSignals.OnBossDie.connect(end_game)
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

## Reports the player's position to MetSys, which explores the cell they are standing
## in. Skipped until the player has actually been placed in the current room.
##
## MetSys picks up a room the instant its scene enters the tree, but load_room() only
## returns some frames later and the player is positioned after that. Every physics
## frame in between would otherwise report the position the player still holds from
## the previous room (or from the editor, on the first load) as a position in the new
## room's coordinates, exploring a cell they never entered.
func _physics_tick() -> void:
	if not _player_positioned:
		return
	super()

func _load_game(ignore_custom_save := false) -> void:
	get_tree().paused = false
	paused = false
	_hud.hide_menus()
	_hud.show_load_screen()
	# save.load_from_text should automatically call MetSys.set_save_data()
	# but if there's no save data (i.e. it's a fresh save), that won't happen
	# so set empty save data first to make sure there's at least something
	MetSys.set_save_data()
	if use_custom_save and !ignore_custom_save:
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
	
	_player.set_gun(
		"plasma" if save.get_value("plasma_gun_collected") else "stun"
	)
	var room_id = save.get_value("current_room", START_ROOM_UID)
	_player_positioned = false
	await load_room(room_id)
	await get_tree().create_timer(artificial_load_time).timeout
	_player.global_position = save.get_value("player_pos", START_POS)
	_player_positioned = true
	_player.respawn()
	GlobalSignals.player_spawned.emit()
	LevelManager.set_checkpoint(room_id, _player.position, false)
	if use_custom_save:
		save_game(0, false)
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
	_player.disable_gun()
	_player.disable_jetpack()
	_player_positioned = false
	await load_room(START_ROOM_UID)
	await get_tree().create_timer(artificial_load_time).timeout
	_player.global_position = START_POS
	_player_positioned = true
	_player.respawn()
	GlobalSignals.player_spawned.emit()
	save_game(0, false)
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
	
	save.set_value("plasma_gun_collected", save_has_plasma_gun)

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
	# The old room's regions are about to be freed, and the player teleports across
	# the boundary, so drop all camera state instead of easing across the seam.
	reset_camera_axis_state()
	#print("Entering room " + new_room)

func _on_pickup_collected(pickup: Pickup) -> void:
	match pickup.type:
		Pickup.PickupType.Jetpack:
			_player.enable_jetpack()
		Pickup.PickupType.Fuse:
			pass
		Pickup.PickupType.StunGun:
			_player.enable_gun()
			PlayerManager.player.set_gun("stun")
		Pickup.PickupType.PlasmaGun:
			save.set_value("plasma_gun_collected", true)
			PlayerManager.player.set_gun("plasma")
		_:
			print("No action defined for pickup " + pickup.get_type_as_str())

func _push_blocking_cyborg() -> void:
	save.set_value("cyborg_pushed", true)

func _restore_station_power() -> void:
	save.set_value("station_powered", true)

func _process(_delta: float) -> void:
	
	if(!isInGame):
		return
	var bounds := _camera_bounds()
	var camPos := _camera.position
	var playerPos := _player.position
	var posDiff := camPos - playerPos
	if abs(posDiff.x) > cameraDeadzone.x:
		camPos.x = playerPos.x + (cameraDeadzone.x * sign(posDiff.x))
	if abs(posDiff.y) > cameraDeadzone.y:
		camPos.y = playerPos.y + (cameraDeadzone.y * sign(posDiff.y))
	camPos = _apply_camera_axis_regions(camPos, bounds, _delta)
	_camera.position = camPos
	
	if allow_save_anywhere and Input.is_action_just_pressed(&"debug_save"):
		save_game(0, false)
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

static func is_cyborg_pushed() -> bool:
	if !instance or !instance.save:
		print("No save data found, cannot determine push status.")
		return false
	return true

static func is_station_powered() -> bool:
	if !instance or !instance.save:
		print("No save data found, cannot determine power status.")
		return false
	return instance.save.get_value("station_powered", false)

#region Camera bounds and axis regions
## Camera2D's own limits are pushed this far out on an axis we don't want it to
## clamp, since our clamping is the authority and the two must not fight.
const CAMERA_LIMIT_OPEN := 10000000

## The rectangle the camera's view is kept inside: the current room's bounds, cut
## back by every [CameraHardBoundary] that applies right now.
##
## Everything that places the camera goes through this, so a boundary is as hard
## as a room edge. Without a room loaded, nothing is bounded.
func _camera_bounds() -> Rect2:
	var room := MetSys.get_current_room_instance()
	if not room:
		return Rect2(Vector2.ONE * -CAMERA_LIMIT_OPEN, Vector2.ONE * (CAMERA_LIMIT_OPEN * 2))
	var rect := Rect2(Vector2.ZERO, room.get_size())
	var focus := _player.global_position
	for node in get_tree().get_nodes_in_group(CameraHardBoundary.GROUP):
		var boundary := node as CameraHardBoundary
		if boundary.is_active():
			rect = boundary.apply_to(rect, focus)
	return rect

## Applies whichever [CameraAxisRegion] currently holds the camera, then re-applies
## the hard bounds so they stay the final authority on every axis that is not
## exempt from them.
##
## A region is a candidate while the player stands inside its polygon, and takes
## control when the player is also moving in one of its claim directions. Control
## then persists until the player leaves the polygon or another region claims. On
## every change of hands the blend restarts from the camera's current position, so
## a hand-over behaves exactly like a fresh entry (see [CameraAxisRegion]).
func _apply_camera_axis_regions(cam_center: Vector2, bounds: Rect2, delta: float) -> Vector2:
	var movement := _player_movement(PlayerManager.player, delta)

	# A region freed under us (room unloaded) just stops holding the camera.
	if _axis_region != null and not is_instance_valid(_axis_region):
		_axis_region = null

	# One pass: does the active region still hold the player, and does anything
	# inside the player's polygons want to claim the camera this frame?
	var claimant: CameraAxisRegion = null
	var active_holds := false
	for node in get_tree().get_nodes_in_group(CameraAxisRegion.GROUP):
		var region := node as CameraAxisRegion
		if not region.contains_player():
			continue
		if region == _axis_region:
			active_holds = true
		if region.accepts_movement(movement) and (claimant == null or region.claim_priority > claimant.claim_priority):
			claimant = region

	if claimant != null and claimant != _axis_region:
		_begin_axis_region(claimant)
	elif _axis_region != null and not active_holds:
		_end_axis_region()

	var result := cam_center
	if _axis_region != null:
		_axis_progress = minf(_axis_progress + _axis_rate * delta, 1.0)
		var target := _axis_region.get_center_point()
		var weight := smoothstep(0.0, 1.0, _axis_progress)
		for axis in 2:
			if _axis_locked & (1 << axis):
				result[axis] = lerpf(_axis_start[axis], target[axis], weight)
	for axis in 2:
		var bit := 1 << axis
		if not (_release_axes & bit):
			continue
		# Ease from where the axis was parked back onto normal following, which is
		# what cam_center already holds for that axis.
		_release_progress[axis] = minf(_release_progress[axis] + _release_rate[axis] * delta, 1.0)
		result[axis] = lerpf(_release_start[axis], cam_center[axis],
			smoothstep(0.0, 1.0, _release_progress[axis]))
		if _release_progress[axis] >= 1.0:
			_release_axes &= ~bit
			_release_ignore &= ~bit

	var exempt := _bounds_exempt_axes()
	_apply_camera_limits(bounds, exempt)
	return _clamp_view_to_rect(result, _half_view(), bounds, exempt)

## Takes camera control for [param region] with its axes already sitting on their
## centre, and moves the camera there immediately.
##
## Called by a region that finds the player inside it as its room resolves, which
## happens before the first frame in that room is drawn. There is no previous shot
## to ease out of in that situation, so easing would just look like the camera
## drifting into place after the room appears.
func snap_to_camera_axis_region(region: CameraAxisRegion) -> void:
	if not is_instance_valid(_camera):
		return
	_begin_axis_region(region)
	# Nothing to travel: the shot starts at its destination.
	_axis_progress = 1.0
	_release_axes = 0
	_release_ignore = 0

	var pos := _camera.position
	var target := region.get_center_point()
	for axis in 2:
		if _axis_locked & (1 << axis):
			pos[axis] = target[axis]
	# The hard bounds have to win here too, and the room may not have been measured
	# yet this frame, so take them fresh.
	var bounds := _camera_bounds()
	var exempt := _bounds_exempt_axes()
	_apply_camera_limits(bounds, exempt)
	_camera.position = _clamp_view_to_rect(pos, _half_view(), bounds, exempt)

## Hands the camera to [param region], measuring its slide from where the camera
## actually is right now.
func _begin_axis_region(region: CameraAxisRegion) -> void:
	var previous := _axis_region
	var previous_axes := _axis_locked if previous != null else 0
	_axis_region = region
	_axis_locked = region.get_locked_axes()
	_axis_start = _camera.position
	_axis_progress = 0.0
	_axis_rate = region.centering_rate

	# Axes the outgoing region drove and this one does not (rounding the corner of
	# an L-shaped shaft, or leaving a point region for a line one) ease back into
	# normal following.
	var freed := previous_axes & ~_axis_locked
	if freed != 0:
		_release_freed_axes(freed, previous)
	# We are driving these again, so an in-flight hand-back of them is moot.
	_release_axes &= ~_axis_locked
	_release_ignore &= ~_axis_locked

## Drops camera control and eases the locked axes back into normal following.
func _end_axis_region() -> void:
	var region := _axis_region
	_axis_region = null
	_release_freed_axes(_axis_locked, region)

func _release_freed_axes(axes: int, region: CameraAxisRegion) -> void:
	var rate := region.get_release_rate()
	var ignores := region.ignore_hard_boundaries
	for axis in 2:
		var bit := 1 << axis
		if not (axes & bit):
			continue
		_release_axes |= bit
		_release_start[axis] = _camera.position[axis]
		_release_progress[axis] = 0.0
		_release_rate[axis] = rate
		# Keep the exemption for the whole hand-back, so an axis parked outside the
		# bounds eases back inside instead of snapping to them on release.
		if ignores:
			_release_ignore |= bit
		else:
			_release_ignore &= ~bit

## The axes currently allowed out of the hard bounds, as CameraAxisRegion.AXIS_*
## flags. Only regions with [member CameraAxisRegion.ignore_hard_boundaries] grant
## this, and only for the axes they drive.
func _bounds_exempt_axes() -> int:
	var exempt := 0
	if _axis_region != null and _axis_region.ignore_hard_boundaries:
		exempt |= _axis_locked
	return exempt | (_release_ignore & _release_axes)

## Mirrors [param bounds] onto the camera's own limits, which Godot applies to the
## view on top of anything we do. Axes we place ourselves keep their limits open,
## so the camera is never clamped twice by two different rules: the exempt ones,
## and any span too narrow to fit the view, which [method _clamp_view_to_rect]
## centres instead.
func _apply_camera_limits(bounds: Rect2, exempt_axes: int) -> void:
	var half_view := _half_view()
	for axis in 2:
		var lo := -CAMERA_LIMIT_OPEN
		var hi := CAMERA_LIMIT_OPEN
		if not (exempt_axes & (1 << axis)) and bounds.size[axis] >= half_view[axis] * 2.0:
			lo = int(floorf(bounds.position[axis]))
			hi = int(ceilf(bounds.end[axis]))
		if axis == 0:
			_camera.limit_left = lo
			_camera.limit_right = hi
		else:
			_camera.limit_top = lo
			_camera.limit_bottom = hi

## The player's travel this frame in global pixels/second. Teleports (room change,
## respawn) are reported as no movement so they cannot claim a region.
func _player_movement(player: Node2D, delta: float) -> Vector2:
	var pos := player.global_position
	var movement := Vector2.ZERO
	if _prev_player_valid and delta > 0.0:
		movement = (pos - _prev_player_pos) / delta
		if movement.length() > CAMERA_TELEPORT_SPEED:
			movement = Vector2.ZERO
	_prev_player_pos = pos
	_prev_player_valid = true
	return movement

## Forgets all camera region state, so the next frame starts from scratch. Used on
## room changes, where the old regions are freed and the player teleports.
func reset_camera_axis_state() -> void:
	_axis_region = null
	_release_axes = 0
	_release_ignore = 0
	_prev_player_valid = false
	# MetSys can report the room change after the new room's regions have already
	# resolved, so re-resolve rather than leaving the camera unclaimed until the
	# player next moves. Deferred, because on a transition the room this belongs
	# to is still being loaded.
	_resolve_camera_arrival.call_deferred()

## Gives the camera to whichever loaded region the player is already standing in,
## centred and without easing. A no-op when they are not in one.
func _resolve_camera_arrival() -> void:
	var best: CameraAxisRegion = null
	for node in get_tree().get_nodes_in_group(CameraAxisRegion.GROUP):
		var region := node as CameraAxisRegion
		if region.contains_player() and (best == null or region.claim_priority > best.claim_priority):
			best = region
	if best != null:
		snap_to_camera_axis_region(best)

## Half the camera's view, in world pixels.
func _half_view() -> Vector2:
	return _camera.get_viewport_rect().size * 0.5 / _camera.zoom

## Clamps a camera centre so its view rectangle stays within [param rect]. Axes in
## [param exempt_axes] are left alone. If the rect is smaller than the view on an
## axis, the view is centred there.
func _clamp_view_to_rect(center: Vector2, half_view: Vector2, rect: Rect2, exempt_axes := 0) -> Vector2:
	var result := center
	var lo := rect.position + half_view
	var hi := rect.end - half_view
	for axis in 2:
		if exempt_axes & (1 << axis):
			continue
		if lo[axis] <= hi[axis]:
			result[axis] = clampf(center[axis], lo[axis], hi[axis])
		else:
			result[axis] = (rect.position[axis] + rect.end[axis]) * 0.5
	return result
#endregion

#Add any other variables you need as you save them, they will be saved as a dictionary
func save_game(save_index: int = 0, set_checkpoint := true) -> void:
	print("Saving")
	save.set_value("player_pos", _player.global_position)
	save.set_value("current_room", MetSys.get_current_room_name())
	if set_checkpoint:
		var checkpoint := get_tree().get_first_node_in_group(&"save_checkpoint") as Node2D
		if not checkpoint:
			printerr("Checkpoint not found in save room. Using current player position instead.")
			LevelManager.set_checkpoint(MetSys.get_current_room_name(), _player.global_position, false)
		else:
			LevelManager.set_checkpoint(MetSys.get_current_room_name(), checkpoint.global_position, false)
			save.set_value("player_pos", checkpoint.global_position)
		
	save.save_as_text("user://save" + str(save_index) +".sav")

func respawn_player_at_checkpoint() -> void:
	_player_positioned = false
	await load_room(LevelManager.checkpoint_room)
	PlayerManager.player.global_position = LevelManager.checkpoint_pos
	_player_positioned = true
	PlayerManager.player._facingRight = !LevelManager.checkpoint_facing_left
	PlayerManager.player.respawn()
	GlobalSignals.player_spawned.emit()

func _on_player_death(_anim_duration: float) -> void:
	await get_tree().create_timer(death_respawn_delay).timeout
	_hud.show_menu(GameHUD.MenuType.GameOver)
	

func end_game():
	PlayerManager.player.process_mode = Node.PROCESS_MODE_DISABLED
	
	_hud.show_load_screen()
	_hud.show_menu(GameHUD.MenuType.GameComplete)
	_hud.hide_load_screen()
