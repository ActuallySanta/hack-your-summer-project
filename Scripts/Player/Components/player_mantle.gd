## Supplementary movement: vaulting up onto a ledge, and where an edge grab will go.
##
## Pressing jump while walking into a ledge one tile high vaults onto it instead of
## jumping. The player is frozen for the length of the vault and then moved a tile
## across and a tile up in one step, which is why the camera has to be led there
## separately -- see [method _start_camera].
##
## [b]Reach.[/b] [member reach_distance] is how far from the wall the vault still
## starts. It used to be a few pixels, so the player had to be flat against the wall,
## which fights the instinct to press jump as you approach. Widen it in the inspector
## until it feels right; the check that the ledge is a real ledge is separate from it,
## so nothing else loosens as it grows.
##
## [b]What counts as a ledge.[/b] The target cell has to be solid right across its
## top face, not merely drawn -- [method PlayerGeometry.has_solid_top]. A cell holding
## a half-height or sloped tile is drawn like any other and used to pass, which is the
## rare vault onto a partial tile that landed the player inside the geometry.
class_name PlayerMantle
extends PlayerComponent

## Emitted the moment control comes back, which is up to
## [member early_control_frames] before the animation finishes.
signal mantle_control_returned
## Emitted when the vault's animation has played out.
signal mantle_finished

@export_group("Reach")
## How far the leading edge of the active collider may be from the wall face and
## still vault, in pixels. Larger is more forgiving.
@export_range(0.0, 48.0, 0.5, "or_greater") var reach_distance := 26.0
## Tiles up the vault moves the player. One, and the geometry checks assume one.
@export var mantle_height_tiles := 1
@export_flags_2d_physics var geometry_layers := 1

@export_group("Timing")
## Animation frames of control handed back before the vault's animation ends.
##
## The vault reads a touch slow, and every sprite on the sheet shares one frame rate,
## so the choice was cutting a frame (a redraw) or giving the frame back to the
## player. This gives it back: the player can move or jump while the last frame or
## two of the vault is still on screen. Set to 0 for the old behaviour.
@export_range(0, 4, 1) var early_control_frames := 1

@export_group("Camera")
## Whether the shot leads the vault. The player's body does not move until the vault
## ends, so without this the camera sits still and then jumps a tile with them.
@export var animate_camera := true
## How long the shot takes to reach where the player will come up. Shorter than the
## vault, so it has settled before they arrive.
@export var camera_lead_seconds := 0.25

@export_group("Nodes")
## The stand-in sprite played during the vault. Hidden the rest of the time.
@export var mantle_sprite: AnimatedSprite2D
@export var mantle_animation: StringName = &"Small Climb"

var _active := false
## Set once control has come back but the animation is still playing.
var _visual_only := false
var _direction := 1
## Where the mantle sprite lives while it plays out the last frames on its own.
var _sprite_home: Node
var _sprite_home_position := Vector2.ZERO

func _bind() -> void:
	if mantle_sprite == null:
		mantle_sprite = get_node_or_null(^"MantleSprite") as AnimatedSprite2D
	if mantle_sprite == null:
		printerr("PlayerMantle: no mantle sprite assigned; vaults will have no visual.")
		return
	_sprite_home = mantle_sprite.get_parent()
	_sprite_home_position = mantle_sprite.position
	mantle_sprite.visible = false
	mantle_sprite.animation_finished.connect(_on_animation_finished)

## True while the player is committed to a vault and nothing else should drive them.
func is_active() -> bool:
	return _active

## Tries to start a vault in the direction the player is pushing. Returns whether one
## started, so the jump can go ahead unchanged when it did not.
func try_mantle() -> bool:
	if not component_enabled or _active or not player.is_on_floor():
		return false
	# Vault the way the player is pushing, not the way they happen to face, so
	# standing still against a ledge and tapping jump is an ordinary jump.
	if is_zero_approx(player.move_input):
		return false

	var direction := 1 if player.move_input > 0.0 else -1
	var foreground := PlayerGeometry.foreground(get_tree())
	if foreground == null:
		return false

	var here := PlayerGeometry.map_coords(foreground, player.global_position)
	var ledge := Vector2i(here.x + direction, here.y)
	var world := player.get_world_2d()
	var exclude: Array[RID] = [player.get_rid()]

	# A ledge is a cell with a floor on top of it and room above it. Both halves
	# matter: the first is what makes a half-tile fail, the second is what stops a
	# vault into a ceiling.
	if not PlayerGeometry.has_solid_top(world, foreground, ledge, geometry_layers, exclude):
		return false
	var headroom: Array[Vector2i] = []
	for step in mantle_height_tiles:
		headroom.append(Vector2i(ledge.x, ledge.y - 1 - step))
	if not PlayerGeometry.are_cells_clear(world, foreground, headroom, geometry_layers, exclude):
		return false
	if not _within_reach(foreground, ledge, direction):
		return false

	_begin(direction)
	return true

## True when the active collider's leading edge is within [member reach_distance] of
## the near face of [param ledge].
func _within_reach(foreground: TileMapLayer, ledge: Vector2i, direction: int) -> bool:
	var bounds := player.collision_manager.get_bounds()
	var lead_edge := maxf(bounds[0].x, bounds[1].x) if direction > 0 else minf(bounds[0].x, bounds[1].x)

	var rect := PlayerGeometry.cell_rect(foreground, ledge)
	var wall_face := rect.position.x if direction > 0 else rect.end.x
	return absf(wall_face - lead_edge) <= reach_distance

#region Running the vault
func _begin(direction: int) -> void:
	# The previous vault's stand-in may still be playing out its last frames, parked in
	# the world where it was handed back. Take it home before setting it up again:
	# otherwise the position set below is written in world space rather than the
	# player's, the sprite is left behind wherever the last vault ended, and the body
	# sprite it hides stays hidden -- so the character simply vanishes for a few frames.
	# Two vaults in quick succession is exactly what early control invites, so this has
	# to be handled rather than prevented.
	if _visual_only:
		_end_visual()

	_active = true
	_visual_only = false
	_direction = direction
	player.velocity = Vector2.ZERO
	player.facing_right = direction > 0

	player.animator.set_body_visible(false)
	if is_instance_valid(mantle_sprite):
		mantle_sprite.flip_h = direction < 0
		mantle_sprite.position = Vector2(_sprite_home_position.x * direction, _sprite_home_position.y)
		mantle_sprite.visible = true
		mantle_sprite.frame = 0
		mantle_sprite.play(mantle_animation)

	_start_camera()

func physics_update(_delta: float) -> void:
	if not _active or early_control_frames <= 0:
		return
	if _elapsed_frames() >= _total_frames() - early_control_frames:
		_hand_back_control()

## Where the player ends up, relative to where they started.
func _displacement() -> Vector2:
	return Vector2(player.tile_size * _direction, -player.tile_size * mantle_height_tiles)

## Moves the player onto the ledge and gives them back to their own components,
## leaving the vault's sprite to finish on its own.
func _hand_back_control() -> void:
	if not _active or _visual_only:
		return
	_visual_only = true
	_active = false

	# Where the stand-in is standing right now, read before the player moves out from
	# under it. The climb animation draws the whole vault -- feet on the lower ledge in
	# the first frame, standing on the upper one in the last -- so every frame of it
	# belongs at the position the vault started from. Reparenting after the teleport
	# kept the sprite's *new* global transform instead, which carried the last frame a
	# tile up and across with the player: a mid-climb pose hanging in the air above the
	# ledge for the rest of the animation.
	var stand_in_playing := is_instance_valid(mantle_sprite) and mantle_sprite.is_playing()
	var stand_in_anchor := mantle_sprite.global_transform if stand_in_playing else Transform2D()

	player.position += _displacement()
	# The camera was led to exactly this offset, so dropping it in the same frame the
	# player covers the distance is what keeps the world still.
	if animate_camera:
		CameraEffects.set_pan(Vector2.ZERO)

	# The stand-in is still playing. Left as a child it would be dragged along by the
	# teleport and by whatever the player does next, so it is handed to the world for
	# its last frames and taken back when it is done.
	if stand_in_playing:
		var world_parent := player.get_parent()
		if world_parent != null:
			mantle_sprite.reparent(world_parent, true)
			mantle_sprite.global_transform = stand_in_anchor
	else:
		_end_visual()

	# Come out of the vault crouched. Where there is headroom the player stands up on
	# the very next frame anyway; where there is not, a one-tile gap keeps them down
	# instead of standing them into the ceiling.
	player.enter_state(Player.MoveState.Crouching)
	mantle_control_returned.emit()

func _on_animation_finished() -> void:
	if _active:
		# early_control_frames is 0, so the animation ending is the vault ending.
		_hand_back_control()
	_end_visual()

func _end_visual() -> void:
	_visual_only = false
	if is_instance_valid(mantle_sprite):
		if mantle_sprite.get_parent() != _sprite_home and _sprite_home != null:
			mantle_sprite.reparent(_sprite_home, false)
		mantle_sprite.visible = false
		mantle_sprite.position = _sprite_home_position
	player.animator.set_body_visible(true)
	mantle_finished.emit()

func on_respawn() -> void:
	if _active or _visual_only:
		_active = false
		_end_visual()
		if animate_camera:
			CameraEffects.set_pan(Vector2.ZERO)
#endregion

#region Camera
## Leads the shot to where the player is about to come up.
##
## The body does not move until the vault ends, so the camera has nothing to follow;
## it is pushed there by hand over [member camera_lead_seconds] and the offset is
## dropped the instant the player actually covers the same distance. This lives in
## [CameraEffects] rather than here because the camera belongs to the whole game --
## a boss, a cutscene and a vault all want to move the shot, and only one of them
## should own how.
func _start_camera() -> void:
	if not animate_camera:
		return
	CameraEffects.pan_to(_displacement(), camera_lead_seconds, CameraEffects.Ease.EASE_OUT)
#endregion

#region Frame maths
func _total_frames() -> int:
	if not is_instance_valid(mantle_sprite) or mantle_sprite.sprite_frames == null:
		return 0
	return mantle_sprite.sprite_frames.get_frame_count(mantle_animation)

func _elapsed_frames() -> float:
	if not is_instance_valid(mantle_sprite):
		return 0.0
	return mantle_sprite.frame + mantle_sprite.frame_progress
#endregion
