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
##
## [b]The sprite.[/b] The vault used to have its own [AnimatedSprite2D] standing in
## for the body. It lives on the character sheet now like everything else, so the
## vault asks the animator for it and pins the sprite to the block while it plays:
## those frames are drawn around the block, which fills one corner of the frame,
## rather than around the character.
class_name PlayerMantle
extends PlayerComponent

## Emitted the moment control comes back, which is up to
## [member early_control_frames] before the animation would have finished.
signal mantle_control_returned
## Emitted when the vault is over. The same moment as [signal mantle_control_returned]
## now that no animation outlives it.
signal mantle_finished

@export_group("Reach")
## How far the leading edge of the active collider may be from the wall face and
## still vault, in pixels. Larger is more forgiving.
@export_range(0.0, 48.0, 0.5, "or_greater") var reach_distance := 26.0
## Tiles up the vault moves the player. One, and the geometry checks assume one.
@export var mantle_height_tiles := 1
@export_flags_2d_physics var geometry_layers := 1

@export_group("Timing")
## Animation frames cut from the end of the vault, handing control back that much
## sooner.
##
## The vault reads a touch slow, and every sprite on the sheet shares one frame rate,
## so the choice was cutting a frame (a redraw) or giving the frame back to the
## player. This gives it back. Set to 0 to play the vault out in full.
@export_range(0, 4, 1) var early_control_frames := 1
## How long one frame of the vault is on screen. Matches the rate the animation was
## authored at -- see [constant ManualAnim.ANIM_FRAME_SECONDS].
@export var seconds_per_animation_frame := 0.1

@export_group("Camera")
## Whether the shot leads the vault. The player's body does not move until the vault
## ends, so without this the camera sits still and then jumps a tile with them.
@export var animate_camera := true
## How long the shot takes to reach where the player will come up. Zero matches the
## part of the vault the player sits through, so the pan lands exactly as control
## comes back.
@export var camera_lead_seconds := 0.0

@export_group("Animation")
@export var mantle_animation: StringName = &"mantle"

var _active := false
var _direction := 1
var _elapsed := 0.0
## The cell being climbed, in world space. The vault's frames are drawn around it.
var _ledge_rect := Rect2()

func _bind() -> void:
	# Shown whatever the scene says. Components are logic and get hidden in the editor
	# to keep the 2D view clear; a hidden [CanvasItem] hides its children too, and this
	# one used to own the vault's sprite. It does not any more, but keeping this shown
	# costs nothing and keeps that trap shut.
	show()

## True while the player is committed to a vault and nothing else should drive them.
func is_active() -> bool:
	return _active

## Tries to start a vault in the direction the player is pushing. Returns whether one
## started, so the jump can go ahead unchanged when it did not.
func try_mantle() -> bool:
	if not component_enabled or _active or not player.is_grounded():
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

	_ledge_rect = PlayerGeometry.cell_rect(foreground, ledge)
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
	_active = true
	_direction = direction
	_elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.facing_right = direction > 0

	player.animator.request_action(mantle_animation)
	player.animator.set_sprite_anchor(_sprite_anchor())
	_start_camera()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= _control_seconds():
		_hand_back_control()

## Where the sprite sits for the length of the vault, in the player's own space.
##
## The frames are drawn around the block rather than around the character: the block
## fills the quarter of the frame the player is climbing towards, and the character is
## drawn up and back from it. Placing that quarter exactly on the cell being climbed
## lines the vault up whether the player started flush against the ledge or
## [member reach_distance] short of it.
##
## The frame is two tiles across and two down at the sprite's scale and is centred on
## the sprite, so the corner quarter starts at the sprite's own position -- which
## makes the anchor simply the corner of the ledge cell, mirrored with the character.
func _sprite_anchor() -> Vector2:
	var corner_x := _ledge_rect.position.x if _direction > 0 else _ledge_rect.end.x
	return Vector2(corner_x, _ledge_rect.position.y) - player.global_position

## Where the player ends up, relative to where they started.
func _displacement() -> Vector2:
	return Vector2(player.tile_size * _direction, -player.tile_size * mantle_height_tiles)

## The vault as authored.
func _vault_seconds() -> float:
	return maxf(player.animator.animation_length(mantle_animation), seconds_per_animation_frame)

## The part of it the player actually sits through.
func _control_seconds() -> float:
	var cut := early_control_frames * seconds_per_animation_frame
	return maxf(_vault_seconds() - cut, seconds_per_animation_frame)

## Moves the player onto the ledge and gives them back to their own components.
func _hand_back_control() -> void:
	if not _active:
		return
	_active = false

	# The sprite comes off the block and the vault ends together. It used to play its
	# last frames on a second sprite left behind in the world, which is what the
	# stand-in existed for; on one sheet there is nothing to leave behind, so the cut
	# frames are simply not shown.
	player.animator.clear_sprite_anchor()
	player.animator.cancel_action()

	player.position += _displacement()
	# The camera was led to exactly this offset, so dropping it in the same frame the
	# player covers the distance is what keeps the world still.
	if animate_camera:
		CameraEffects.set_pan(Vector2.ZERO)

	# Come out of the vault crouched. Where there is headroom the player stands up on
	# the very next frame anyway; where there is not, a one-tile gap keeps them down
	# instead of standing them into the ceiling.
	player.enter_state(Player.MoveState.Crouching)
	mantle_control_returned.emit()
	mantle_finished.emit()

func on_respawn() -> void:
	if not _active:
		return
	_active = false
	player.animator.clear_sprite_anchor()
	player.animator.cancel_action()
	if animate_camera:
		CameraEffects.set_pan(Vector2.ZERO)
#endregion

#region Camera
## Leads the shot to where the player is about to come up.
##
## The body does not move until the vault ends, so the camera has nothing to follow;
## it is pushed there by hand and the offset is dropped the instant the player
## actually covers the same distance. This lives in [CameraEffects] rather than here
## because the camera belongs to the whole game -- a boss, a cutscene and a vault all
## want to move the shot, and only one of them should own how.
func _start_camera() -> void:
	if not animate_camera:
		return
	# Only as far as the shot can actually go. Against a wall, in a room one screen
	# wide, or on an axis a region is holding, there is nowhere for it to follow the
	# vault to, and panning there animates a move that cannot happen.
	var lead := _camera_lead()
	if lead.is_zero_approx():
		return
	CameraEffects.pan_to(lead, _lead_seconds(), CameraEffects.Ease.EASE_OUT)

## The part of the vault's displacement the camera is allowed to follow.
##
## Asked of whoever owns the camera, because the limits are theirs -- the room bounds,
## every [CameraHardBoundary] cutting into them, and any [CameraAxisRegion] holding an
## axis -- and because asking one question covers all of them at once rather than
## listing the cases here and letting them drift apart. Falls back to the whole
## displacement when there is no game around this: a test harness, or the player scene
## opened on its own.
func _camera_lead() -> Vector2:
	var manager := GameManager.instance
	if manager == null:
		return _displacement()
	return manager.camera_lead_for(player.global_position + _displacement())

## How long the pan runs for. Defaults to the part of the vault the player sits
## through, so it arrives on the frame [method _hand_back_control] drops it.
func _lead_seconds() -> float:
	if camera_lead_seconds > 0.0:
		return camera_lead_seconds
	return _control_seconds()
#endregion
