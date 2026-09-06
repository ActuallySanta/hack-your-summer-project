class_name GameManager
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const START_ROOM_UID = "uid://djrq87v0sx3lq" #Docking Station
const START_POS = Vector2(158, 834)
const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

const PICKUP_FUSE_ID = "Fuse"
const PICKUP_GUN_ID = "Gun"
const PICKUP_JETPACK_ID = "Jetpack"
const PICKUP_WRENCH_ID = "Wrench"

@onready var _player : Player = $Player
@onready var _camera : Camera2D = $Camera2D
@onready var _hud : GameHUD = $HUD

@export var cameraDeadzone := Vector2(0, 0)
@export var death_respawn_delay := 2.0
@export var artificial_load_time := 0.0
@export var allow_save_anywhere := false
@export var use_custom_save := false
@export_file var save_room := START_ROOM_UID
## Which [DebugSpawnPoint] in [member save_room] to start on. Drop one in the room and
## drag it where you want; [member save_pos] is only used when the room has no marker
## with this id.
@export var save_spawn_id : StringName = &"default"
## Fallback spawn coordinate, used when [member save_room] holds no [DebugSpawnPoint]
## matching [member save_spawn_id].
@export var save_pos := Vector2(3000, 483)
@export_enum("Uncollected", "Collected", "Powered") var save_fuse_state : int
@export_enum("Uncollected", "Basic", "Allen") var wrench_collection_state : String
@export_enum("Uncollected", "Stun", "Plasma") var gun_collection_state : String
@export var save_has_jetpack : bool

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
# Hard bounds easing (see _eased_camera_bounds). _bounds_eased is what the camera
# is actually held inside this frame, on its way to _bounds_target.
var _bounds_ready := false
var _bounds_roomless := false
var _bounds_eased := Rect2()
var _bounds_start := Rect2()
var _bounds_target := Rect2()
var _bounds_progress := 1.0
var _bounds_rate := 1.5
# Slowest shift rate among the boundaries that changed during the last bounds pass,
# or 0 when none did.
var _bounds_change_rate := 0.0
# The camera centre this script has worked out, before any [CameraEffects] shake or
# pan is added. Everything internal reads and writes this rather than the camera, so
# an effect in flight cannot be mistaken for where the shot actually is.
var _camera_pos := Vector2.ZERO
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
	_camera_pos = _camera.position
	# We place the camera every frame and clamp it; CameraEffects must not write its
	# own offset on top, or a shake would show the outside of a room.
	CameraEffects.use_external_applier(true)
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
	_reset_world_state()
	await load_room(room_id)
	await get_tree().create_timer(artificial_load_time).timeout

	# The custom save's spawn is resolved after the room is up, because the marker it
	# prefers lives in the room.
	if use_custom_save and !ignore_custom_save:
		save.set_value("player_pos", _custom_spawn_position())
	_player.global_position = save.get_value("player_pos", START_POS)
	_player_positioned = true
	_restore_world_state()
	_player.respawn()
	GlobalSignals.player_spawned.emit()
	LevelManager.set_checkpoint(room_id, _player.position, false)
	if use_custom_save and !ignore_custom_save:
		# Not a save in the ordinary sense: it writes down the custom start so that
		# dying reverts to it, exactly as dying reverts to a save station.
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
	_reset_world_state()
	await load_room(START_ROOM_UID)
	await get_tree().create_timer(artificial_load_time).timeout
	_player.global_position = START_POS
	_player_positioned = true
	_restore_world_state()
	_player.respawn()
	GlobalSignals.player_spawned.emit()
	# The one save outside a save station, and the same job the station does: it writes
	# down where a death reverts to. Without it, dying before reaching the first station
	# would load whatever the previous playthrough left on disk.
	save_game(0, false)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	isInGame = true
	_hud.hide_load_screen()

func _load_custom_save() -> void:
	save = SaveManager.new()
	save.set_value("current_room", save_room)
	# A placeholder: the real one is taken from the room's DebugSpawnPoint once the
	# room is loaded, in _load_game.
	save.set_value("player_pos", save_pos)
	save.set_value("station_powered", save_fuse_state == 2)
	
	if save_fuse_state > 0:
		MetSys.save_data.stored_objects[PICKUP_FUSE_ID] = true
	if gun_collection_state.contains("Stun"):
		MetSys.save_data.stored_objects[PICKUP_GUN_ID] = true
	if save_has_jetpack:
		MetSys.save_data.stored_objects[PICKUP_JETPACK_ID] = true
	
	save.set_value("plasma_gun_collected", gun_collection_state.contains("Plasma"))

func get_save_path(save_index: int) -> StringName:
	return "user://save" + str(save_index) +".sav"

#region Restoring the world to the last save
func _reset_world_state() -> void:
	MusicManager.restore_automatic_assignment()

## Puts back what the loaded save says, [b]after[/b] the room is up.
##
## This half needs the room to already be there: the map panels are redrawn here, and
## they draw around where the player now is.
func _restore_world_state() -> void:
	_restore_map_state()

func _restore_map_state() -> void:
	# Regions a map station revealed are replayed from the save rather than trusted to
	# survive as per-cell discovery data, so the two can never disagree.
	for code in get_revealed_map_regions():
		MapRegions.reveal(code)
	# Everything that draws the map redraws now, on the data that was just loaded.
	MetSys.map_updated.emit()
#endregion

#region Custom-save spawn
## Group every [DebugSpawnPoint] joins, so a room's markers can be found once it is
## loaded without the room having to wire anything up.
const SPAWN_POINT_GROUP := &"debug_spawn_point"

## Where the custom save should drop the player in the room it has just loaded.
##
## Prefers a [DebugSpawnPoint] marker in the room whose id matches
## [member save_spawn_id] -- a marker can be dragged around in the room scene and
## seen, which typing coordinates into [member save_pos] cannot. Falls back to
## [member save_pos] when the room has no matching marker.
func _custom_spawn_position() -> Vector2:
	var markers := get_tree().get_nodes_in_group(SPAWN_POINT_GROUP)
	for node in markers:
		var marker := node as DebugSpawnPoint
		if marker and marker.id == save_spawn_id:
			return marker.global_position

	if not markers.is_empty():
		var names := markers.map(func(m): return str(m.id))
		printerr("GameManager: no spawn point with id \"%s\" in this room. It has: %s. Using save_pos." % [save_spawn_id, ", ".join(names)])
	return save_pos
#endregion

func pause_game() -> void:
	# Before the tree stops, or the map freezes on screen over the menu.
	_hud.force_close_map()
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

func _on_pickup_collected(pickup: Pickup) -> void:
	match pickup.type:
		Pickup.PickupType.Jetpack:
			PlayerManager.player.enable_jetpack()
		Pickup.PickupType.Fuse:
			pass
		Pickup.PickupType.StunGun:
			PlayerManager.player.enable_gun()
			PlayerManager.player.set_gun("stun")
		Pickup.PickupType.PlasmaGun:
			save.set_value("plasma_gun_collected", true)
			PlayerManager.player.set_gun("plasma")
		Pickup.PickupType.AllenWrench:
			save.set_value("allen_wrench_collected", true)
		_:
			printerr("No action defined for pickup " + pickup.get_type_as_str())

func _push_blocking_cyborg() -> void:
	save.set_value("cyborg_pushed", true)

func _restore_station_power() -> void:
	save.set_value("station_powered", true)

func _process(_delta: float) -> void:
	if(!isInGame):
		return
	var bounds := _eased_camera_bounds(_delta)
	var camPos := _follow_centre(_player.position)
	camPos = _apply_camera_axis_regions(camPos, bounds, _delta)
	_place_camera(camPos, bounds, _bounds_exempt_axes())
	
	# Development tool. Saving is otherwise a save station and nothing else, because a
	# death is meant to cost the player everything since the last one.
	if allow_save_anywhere and OS.is_debug_build() and Input.is_action_just_pressed(&"debug_save"):
		save_game(0, false)
	if Input.is_action_just_pressed("pause"):
		if paused:
			resume_game()
		else:
			pause_game()
		

#region Saved player values
## Key the set of collected health extenders is kept under. It is a set of object ids
## rather than a count on purpose -- see [PlayerHealthComponent] for why.
const HEALTH_UPGRADE_KEY := "health_upgrades"

## Key the set of revealed map regions is kept under, as [MapRegions] codes.
const REVEALED_REGIONS_KEY := "revealed_map_regions"

## Records that a map station revealed [param code]'s region, and reports whether that
## was news. Called by the station as it is used; replayed on load by
## [method _restore_map_state].
static func register_map_region_revealed(code: String) -> bool:
	var revealed = get_saved_value(REVEALED_REGIONS_KEY, [])
	var codes: Array = revealed if revealed is Array else []
	if codes.has(code):
		return false
	codes.append(code)
	set_saved_value(REVEALED_REGIONS_KEY, codes)
	return true

static func get_revealed_map_regions() -> Array:
	var revealed = get_saved_value(REVEALED_REGIONS_KEY, [])
	return revealed if revealed is Array else []

## Reads a value out of the loaded save, for the player's components to restore
## themselves from. Returns [param fallback] when there is no save yet (the menu).
static func get_saved_value(key: String, fallback: Variant = null) -> Variant:
	if not instance or not instance.save:
		return fallback
	return instance.save.get_value(key, fallback)

## Writes a value into the loaded save. It reaches disk on the next [method save_game],
## which is what keeps an upgrade and the pickup that granted it reverting together.
static func set_saved_value(key: String, value: Variant) -> void:
	if not instance or not instance.save:
		printerr("GameManager: no save loaded, cannot store \"%s\"." % key)
		return
	instance.save.set_value(key, value)

## How many health extenders the save says have been collected.
static func get_health_upgrade_count() -> int:
	var collected = get_saved_value(HEALTH_UPGRADE_KEY, [])
	return (collected as Array).size() if collected is Array else 0

## Records that the extender with [param object_id] has been collected, and reports
## whether that was news.
##
## Storing the ids rather than a running total is what makes this safe to call twice.
## A pickup that reappears because the run was never saved can be taken again, and
## the second take adds nothing, because the id is already in the set.
static func register_health_upgrade(object_id: String) -> bool:
	if object_id.is_empty():
		printerr("GameManager: a health extender has no object id; it cannot be tracked.")
		return false
	var collected = get_saved_value(HEALTH_UPGRADE_KEY, [])
	var ids: Array = collected if collected is Array else []
	if ids.has(object_id):
		return false
	ids.append(object_id)
	set_saved_value(HEALTH_UPGRADE_KEY, ids)
	return true
#endregion

static func is_object_collected(name : String) -> bool:
	if !MetSys.save_data:
		printerr("No save data found, cannot determine object collection status.")
		return false
	return MetSys.save_data.stored_objects.get(name, false)

static func is_station_powered() -> bool:
	if !instance or !instance.save:
		printerr("No save data found, cannot determine power status.")
		return false
	return instance.save.get_value("station_powered", false)

#region Camera bounds and axis regions
## Camera2D's own limits are pushed this far out on an axis we don't want it to
## clamp, since our clamping is the authority and the two must not fight.
const CAMERA_LIMIT_OPEN := 10000000

## An edge of the hard bounds travelling slower than this (pixels/second) is
## followed as it moves rather than eased after, because there is no cut to hide.
## Above it, the change is treated as a boundary switching on, off, or jumping.
const CAMERA_BOUNDS_TRACK_SPEED := 1200.0

## Rate used to ease a bounds change that no [CameraHardBoundary] accounted for.
const CAMERA_BOUNDS_SHIFT_RATE := 1.5

## Where the hard bounds are heading: the current room's bounds, cut back by every
## [CameraHardBoundary] that applies right now.
##
## Everything that places the camera goes through this, so a boundary is as hard as
## a room edge. Without a room loaded, nothing is bounded. Pass [param track_changes]
## on the once-a-frame call to note which boundaries changed, which is what decides
## the rate the camera eases across at.
func _camera_bounds(track_changes := false) -> Rect2:
	var room := MetSys.get_current_room_instance()
	_bounds_roomless = room == null
	if _bounds_roomless:
		return Rect2(Vector2.ONE * -CAMERA_LIMIT_OPEN, Vector2.ONE * (CAMERA_LIMIT_OPEN * 2))
	var rect := Rect2(Vector2.ZERO, room.get_size())
	var focus := _player.global_position
	if track_changes:
		_bounds_change_rate = 0.0
	for node in get_tree().get_nodes_in_group(CameraHardBoundary.GROUP):
		var boundary := node as CameraHardBoundary
		var active := boundary.is_active()
		if track_changes and boundary.poll_state_change(active):
			# Several can change on the same frame, and the gentlest reading of that
			# is the slowest of them.
			_bounds_change_rate = boundary.shift_rate if _bounds_change_rate <= 0.0 \
				else minf(_bounds_change_rate, boundary.shift_rate)
		if active:
			rect = boundary.apply_to(rect, focus)
	return rect

## The bounds the camera is actually held inside this frame.
##
## A boundary switching on or off, or being moved in one step, would otherwise cut
## the shot to a new position the moment it happened. Instead the bounds themselves
## slide to their new shape on the same smoothstep the regions centre on, so the
## camera is carried across by the edge that holds it and the two systems read as
## one. Nothing waits on the player here: unlike a region, which needs them walking
## its way before it claims, a boundary starts easing the moment it changes.
func _eased_camera_bounds(delta: float) -> Rect2:
	var target := _camera_bounds(true)
	# Nothing to ease from on the first frame in a room, or while there is no room.
	if not _bounds_ready or _bounds_roomless:
		_settle_camera_bounds(target)
		_bounds_ready = not _bounds_roomless
		return _bounds_eased

	if target != _bounds_target:
		var speed := _rect_edge_change(_bounds_target, target) / maxf(delta, 0.0001)
		if speed > CAMERA_BOUNDS_TRACK_SPEED:
			# Restart from where the bounds have actually reached, so a second change
			# mid-slide picks up from the current shape instead of jumping back.
			_bounds_start = _bounds_eased
			_bounds_progress = 0.0
			_bounds_rate = _bounds_change_rate if _bounds_change_rate > 0.0 else CAMERA_BOUNDS_SHIFT_RATE
		_bounds_target = target

	if _bounds_progress < 1.0:
		_bounds_progress = minf(_bounds_progress + _bounds_rate * delta, 1.0)
		_bounds_eased = _lerp_rect(_bounds_start, _bounds_target, smoothstep(0.0, 1.0, _bounds_progress))
	else:
		_bounds_eased = _bounds_target
	return _bounds_eased

## Puts the hard bounds at [param rect] with nothing in flight, for the moments the
## camera is placed rather than moved: arriving in a room, or respawning.
func _settle_camera_bounds(rect: Rect2) -> void:
	_bounds_ready = true
	_bounds_eased = rect
	_bounds_start = rect
	_bounds_target = rect
	_bounds_progress = 1.0

## The furthest any one edge moved between two bounds rects.
func _rect_edge_change(from: Rect2, to: Rect2) -> float:
	var moved := (to.position - from.position).abs()
	var end_moved := (to.end - from.end).abs()
	return maxf(maxf(moved.x, moved.y), maxf(end_moved.x, end_moved.y))

## Blends two bounds rects edge by edge, so an edge that isn't moving stays put.
func _lerp_rect(from: Rect2, to: Rect2, weight: float) -> Rect2:
	var start := from.position.lerp(to.position, weight)
	var end := from.end.lerp(to.end, weight)
	return Rect2(start, end - start)

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

	var pos := _camera_pos
	var target := region.get_center_point()
	for axis in 2:
		if _axis_locked & (1 << axis):
			pos[axis] = target[axis]
	# The hard bounds have to win here too, and the room may not have been measured
	# yet this frame, so take them fresh. Arriving somewhere is a placement rather
	# than a move, so they settle where they are instead of sliding in from whatever
	# shape the last room left behind.
	var bounds := _camera_bounds()
	if not _bounds_roomless:
		_settle_camera_bounds(bounds)
	var exempt := _bounds_exempt_axes()
	_apply_camera_limits(bounds, exempt)
	_place_camera(_clamp_view_to_rect(pos, _half_view(), bounds, exempt), bounds, exempt)

## Hands the camera to [param region], measuring its slide from where the camera
## actually is right now.
func _begin_axis_region(region: CameraAxisRegion) -> void:
	var previous := _axis_region
	var previous_axes := _axis_locked if previous != null else 0
	_axis_region = region
	_axis_locked = region.get_locked_axes()
	_axis_start = _camera_pos
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
		_release_start[axis] = _camera_pos[axis]
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

## The centre the camera wants for a player at [param player_position], before the
## bounds, the boundaries or an axis region have had their say.
func _follow_centre(player_position: Vector2) -> Vector2:
	var centre := _camera_pos
	var diff := centre - player_position
	if absf(diff.x) > cameraDeadzone.x:
		centre.x = player_position.x + cameraDeadzone.x * signf(diff.x)
	if absf(diff.y) > cameraDeadzone.y:
		centre.y = player_position.y + cameraDeadzone.y * signf(diff.y)
	return centre

## How far the shot would actually travel if the player were at [param world_position]
## instead of where they are, per axis.
##
## Anything that leads the camera somewhere the player has not gone yet asks this
## rather than working from the distance the player is about to cover. A vault moves
## the player a tile across and a tile up; the camera follows only the part of that
## the room allows. Pressed against a wall it has nowhere to go sideways; in a room one
## screen wide it never moves sideways at all; a [CameraAxisRegion] holding an axis
## owns that axis outright and gives back nothing. Every one of those comes back as a
## zero on that axis, so "no movement", "horizontal only" and "vertical only" all fall
## out of the same question instead of having to be listed and kept in step.
##
## Leading by the raw distance and letting [method _place_camera] clamp it away is not
## the same thing. That looks identical only when the whole of the lead is allowed:
## when part of it is, the shot eases against a distance it cannot cover, so it travels
## at full speed and stops dead against the limit rather than settling into where it is
## really going.
func camera_lead_for(world_position: Vector2) -> Vector2:
	if not isInGame or _player == null or _camera == null:
		return Vector2.ZERO

	var bounds := _bounds_eased if _bounds_ready else _camera_bounds()
	var exempt := _bounds_exempt_axes()
	var half := _half_view()
	var here := _clamp_view_to_rect(_follow_centre(_player.position), half, bounds, exempt)
	var there := _clamp_view_to_rect(_follow_centre(world_position), half, bounds, exempt)
	var lead := there - here

	# An axis a region is driving is not ours to lead. The region decides where that
	# axis sits and eases it there itself, so a pan laid over the top is a fight the
	# region wins a moment later.
	if _axis_region != null:
		for axis in 2:
			if _axis_locked & (1 << axis):
				lead[axis] = 0.0
	return lead

## Puts the camera at [param center], with whatever [CameraEffects] is adding folded
## in and clamped by the same rules.
##
## This is the only place the camera's transform is written. Shake and pan used to go
## straight onto [member Camera2D.offset], which Godot adds after the limits have been
## applied -- so an effect near a room edge showed the outside of the room, and it was
## the one thing in the game that could break the bounds. Adding the effect to the
## centre and clamping the sum instead means a shake is simply worn down by whatever
## edge it is pushing against.
##
## [member Camera2D.offset] is held at zero for the same reason: it is a second way to
## move the shot that nothing here can see.
func _place_camera(center: Vector2, bounds: Rect2, exempt_axes: int) -> void:
	_camera_pos = center
	_camera.offset = Vector2.ZERO
	_camera.position = _clamp_view_to_rect(
		center + CameraEffects.get_effect_offset(), _half_view(), bounds, exempt_axes)

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
	# The next room's bounds are a different shape entirely, so they are taken as
	# read rather than eased across the seam.
	_bounds_ready = false
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

func _on_player_death(_anim_duration: float) -> void:
	await get_tree().create_timer(death_respawn_delay).timeout
	_hud.show_menu(GameHUD.MenuType.GameOver)
	

func end_game():
	PlayerManager.player.process_mode = Node.PROCESS_MODE_DISABLED
	
	_hud.show_load_screen()
	_hud.show_menu(GameHUD.MenuType.GameComplete)
	_hud.hide_load_screen()
