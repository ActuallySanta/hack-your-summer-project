## Everything that decides what the player looks like.
##
## Nothing else in the player touches [AnimationPlayer], the sprite's frame, or its
## flip. Components [i]ask[/i] for a look -- [method request_pose] for the standing
## state, [method request_action] for a one-shot -- and this decides what actually
## plays. That is the whole point of the split: an animation problem is now in one
## file, and a movement component cannot leave the sprite in a state nobody owns.
##
## [b]Why an AnimationPlayer and not an AnimationTree.[/b] The tree drove poses
## through transition nodes whose [code]transition_request[/code] only takes effect
## on the [i]next[/i] process, so every re-entry into a sub-state played that
## sub-state's default for a frame first. That is what put a standing frame in the
## middle of turning around while crouched. Playing a named animation outright cannot
## do that.
##
## [b]Missing animations.[/b] [method resolve] falls back rather than failing, so a
## look that has not been drawn yet plays the nearest thing that has (see
## [member fallbacks]). Adding the real animation to the [AnimationPlayer] under the
## name that was asked for is the whole of the work -- no code changes, no new wiring.
class_name PlayerAnimator
extends PlayerComponent

## Emitted when a one-shot finishes and the pose takes over again.
signal action_finished(action: StringName)

@export_group("Nodes")
@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D

@export_group("Animations")
## Played when a request cannot be resolved at all -- neither the name asked for nor
## anything it falls back to exists.
@export var default_animation: StringName = &"idle"

## What to play when the animation asked for is not in the [AnimationPlayer] yet.
##
## Resolution follows the chain, so [code]swing_crouch -> crouch[/code] means a crouch
## swing shows the player still crouched instead of snapping upright. Draw the real
## animation, add it to the [AnimationPlayer] under the key's name, and it takes over
## with no other change.
@export var fallbacks: Dictionary[StringName, StringName] = {
	&"walk": &"run",
	&"crawl_turn": &"crawl",
	&"crawl_shoot": &"crouch_shoot",
	&"wall_cling_shot": &"jump_shoot",
	&"wall_slide": &"jump",
	&"wall_push": &"jump_start",
	&"jump_start": &"jump",
	&"jetpack_idle": &"jetpack",
	&"land": &"idle",
}

## Looks drawn holding a wall in front of the character.
##
## The player faces [i]away[/i] from the wall they are about to push off, so these
## read backwards under the ordinary flip and are mirrored back. Kept as a set rather
## than asked of the wall jump, because it is a fact about how the frames were drawn.
const WALL_LOOKS: Array[StringName] = [&"wall_slide", &"wall_push", &"wall_cling_shot"]

## Logs each unresolved name once, so a look that is silently falling back is visible
## in the output rather than only on screen.
@export var warn_on_fallback := true

@export_group("Reference-texture sprites")
## Swaps the character over to the palette-indexed sprite pipeline: the sheet stores
## a lookup index per pixel and the colours live in a tiny reference image, so a
## reskin is one small texture rather than another copy of every sheet.
##
## Off until the sheets have actually been baked -- see
## [code]Tools/bake_reference_sprite.gd[/code] and [PlayerReferenceSprite]. An
## un-baked sheet run through the shader comes out as garbage colours, which is why
## this is opt-in rather than automatic.
@export var use_reference_textures := false

## The palette this player is currently wearing. Swapping it reskins every animation
## at once, since the sheets only store indices into it.
@export var reference_texture: Texture2D:
	set(value):
		reference_texture = value
		if is_instance_valid(_reference):
			_reference.set_reference(value)

## The pose that plays whenever no one-shot is running. Held rather than replayed, so
## asking for the pose that is already up does not restart it.
var _pose: StringName = &""

## The one-shot currently locking out the pose, or empty.
var _action: StringName = &""
var _action_timer := 0.0

var _reference: PlayerReferenceSprite
var _warned: Dictionary[StringName, bool] = {}
## The two independent reasons the body sprite can be off screen, kept apart so
## neither can undo the other.
var _body_hidden_by_owner := false
var _body_hidden_by_blink := false
## Where the sprite sits when nothing has pinned it somewhere else.
var _sprite_home := Vector2.ZERO
var _sprite_anchor := Vector2.ZERO
var _anchored := false
## Set by [method request_held_action]: nothing may replace the look while it is up.
var _action_held := false

func _bind() -> void:
	if animation_player == null:
		animation_player = player.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if sprite == null:
		sprite = player.get_node_or_null(^"Character") as Sprite2D
	if animation_player == null or sprite == null:
		printerr("PlayerAnimator: needs both an AnimationPlayer and a Sprite2D.")
		return

	_sprite_home = sprite.position
	_anchored = false
	animation_player.animation_finished.connect(_on_animation_finished)
	if use_reference_textures:
		_reference = PlayerReferenceSprite.new()
		_reference.name = &"ReferenceSprite"
		add_child(_reference)
		_reference.attach(sprite, reference_texture)

#region Requests
## Asks for the player's resting look -- standing, crawling, falling.
##
## Ignored while a one-shot is running; the pose that was asked for last is what
## comes back when the one-shot ends, so a component can keep asking every frame
## without having to know what else is playing.
func request_pose(pose: StringName, speed_scale := 1.0) -> void:
	if _pose == pose and is_equal_approx(animation_player.speed_scale, speed_scale):
		return
	_pose = pose
	if _action.is_empty():
		_play(pose, speed_scale)

## Plays a one-shot -- a swing, a shot, a hurt, a death -- over the top of the pose.
##
## [param min_duration] holds the last frame for at least that long when the
## animation itself is shorter, which is what stops a two-frame placeholder from
## flickering past inside a longer action.
## [param from_time] starts the animation partway in rather than at its first frame.
##
## Returns false when [param action] is already running and [param interrupt] is off,
## so a caller can tell a refused re-fire from an accepted one.
func request_action(action: StringName, min_duration := 0.0, from_time := 0.0, interrupt := true) -> bool:
	# A held look is the last word until something explicitly takes it back. Death is
	# the one that uses it, and everything else the player does carries on happening
	# around a corpse: landing on the ground a frame after dying used to play the
	# landing frames straight over the death pose.
	if _action_held:
		return false
	if not _action.is_empty() and not interrupt:
		return false

	var resolved := resolve(action)
	if resolved.is_empty():
		return false

	_action = resolved
	_play(resolved, 1.0, from_time)
	_action_timer = maxf(animation_length(resolved) - from_time, min_duration)
	return true

## Plays a one-shot and leaves it on its last frame instead of handing the pose back
## when it ends.
##
## Death is what this exists for: the animation running out is the player lying on the
## floor, not a cue to stand up again. An ordinary [method request_action] ends on its
## own, and the pose waiting behind it -- idle -- is what came back and put the body
## on its feet a second after it died.
##
## Held until [method cancel_action], the next [method request_action], or
## [method on_respawn].
func request_held_action(action: StringName) -> bool:
	_action_held = false
	if not request_action(action):
		return false
	_action_timer = INF
	_action_held = true
	return true

## Ends the running one-shot early and puts the pose back.
func cancel_action() -> void:
	if _action.is_empty():
		return
	_action_held = false
	var was := _action
	_action = &""
	_action_timer = 0.0
	_play(_pose)
	action_finished.emit(was)

## Pins the sprite to a spot in the player's own space, for an animation drawn around
## something in the world rather than around the player.
##
## The vault is the one that needs it: its frames are drawn with the block being
## climbed filling the bottom quarter of the frame, so the sprite belongs on the block
## and not on the player, who does not move until the vault ends.
func set_sprite_anchor(local_position: Vector2) -> void:
	# Where it was is remembered on the way in rather than cached once, because the
	# manager moves the sprite too: the air collider is shorter than the walking one
	# and the visuals follow it down (see Player._align_visuals_to_collider).
	if not _anchored:
		_sprite_home = sprite.position
	_sprite_anchor = local_position
	_anchored = true
	if is_instance_valid(sprite):
		sprite.position = _sprite_anchor

## Puts the sprite back where the manager had it.
func clear_sprite_anchor() -> void:
	if _anchored and is_instance_valid(sprite):
		sprite.position = _sprite_home
	_anchored = false

## Which way the sprite should face this frame.
##
## The way the player is facing, except for the looks drawn holding a wall: see
## [constant WALL_LOOKS].
func _sprite_faces_right() -> bool:
	var look := _action if not _action.is_empty() else _pose
	if look in WALL_LOOKS:
		return not player.facing_right
	return player.facing_right

func is_action_playing(action: StringName = &"") -> bool:
	if action.is_empty():
		return not _action.is_empty()
	return _action == resolve(action)

func current_action() -> StringName:
	return _action

func current_pose() -> StringName:
	return _pose
#endregion

#region Resolution
## The animation that will actually play for [param wanted]: itself if it exists,
## otherwise whatever it falls back to, otherwise [member default_animation].
func resolve(wanted: StringName) -> StringName:
	var name := wanted
	# Bounded by the table's own size, so a fallback loop cannot hang the game.
	for _step in fallbacks.size() + 1:
		if has_animation(name):
			if name != wanted:
				_warn_fallback(wanted, name)
			return name
		if not fallbacks.has(name):
			break
		name = fallbacks[name]

	if has_animation(default_animation):
		_warn_fallback(wanted, default_animation)
		return default_animation
	_warn_fallback(wanted, &"")
	return &""

func has_animation(name: StringName) -> bool:
	return not name.is_empty() and animation_player != null and animation_player.has_animation(name)

func animation_length(name: StringName) -> float:
	if not has_animation(name):
		return 0.0
	return animation_player.get_animation(name).length

func _warn_fallback(wanted: StringName, used: StringName) -> void:
	if not warn_on_fallback or _warned.has(wanted):
		return
	_warned[wanted] = true
	if used.is_empty():
		printerr("PlayerAnimator: no animation for \"%s\" and no default to fall back on." % wanted)
	else:
		print("PlayerAnimator: no \"%s\" animation yet, playing \"%s\" instead." % [wanted, used])
#endregion

#region Sprite
## Hides or shows the character sheet, for the moments something else is standing in
## for it (the mantle's own sprite).
func set_body_visible(shown: bool) -> void:
	_body_hidden_by_owner = not shown
	_refresh_body_visibility()

## Blinks the character during invulnerability. Kept here rather than in the health
## component so the sprite has exactly one owner -- and so a blink cannot uncover the
## body in the middle of a vault, which two independent writers of [code]visible[/code]
## would otherwise do to each other.
func set_body_hidden_for_blink(hidden: bool) -> void:
	_body_hidden_by_blink = hidden
	_refresh_body_visibility()

func _refresh_body_visibility() -> void:
	if is_instance_valid(sprite):
		sprite.visible = not (_body_hidden_by_owner or _body_hidden_by_blink)

## Swaps the palette every animation reads its colours out of. No-op unless
## [member use_reference_textures] is on.
func set_reference_texture(texture: Texture2D) -> void:
	reference_texture = texture

## Recolours one entry of the palette in place, for effects that only touch part of
## the player (a burn, a powered-up wrench) without a whole new texture.
func set_reference_pixel(index: Vector2i, colour: Color) -> void:
	if is_instance_valid(_reference):
		_reference.set_pixel(index, colour)
#endregion

func frame_update(delta: float) -> void:
	if is_instance_valid(sprite):
		sprite.flip_h = not _sprite_faces_right()
		if _anchored:
			sprite.position = _sprite_anchor

	if _action.is_empty():
		return
	_action_timer -= delta
	if _action_timer <= 0.0:
		var was := _action
		_action = &""
		_play(_pose)
		action_finished.emit(was)

func on_respawn() -> void:
	clear_sprite_anchor()
	_action_held = false
	_action = &""
	_action_timer = 0.0
	_pose = &""

func _play(name: StringName, speed_scale := 1.0, from_time := 0.0) -> void:
	var resolved := resolve(name)
	if resolved.is_empty():
		return
	animation_player.speed_scale = speed_scale
	# Same animation, new start point: play() alone would ignore the request.
	if animation_player.current_animation == resolved and from_time > 0.0:
		animation_player.seek(from_time, true)
		return
	animation_player.play(resolved)
	if from_time > 0.0:
		animation_player.seek(from_time, true)

## A one-shot that runs out of animation before its hold does keeps its last frame,
## so only the ones that finish on time are ended here.
func _on_animation_finished(finished: StringName) -> void:
	if _action.is_empty() or finished != _action or _action_timer > 0.0:
		return
	_action_held = false
	var was := _action
	_action = &""
	_play(_pose)
	action_finished.emit(was)
