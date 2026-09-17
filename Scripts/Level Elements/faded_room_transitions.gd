## Room transitions that happen behind a screen fade.
##
## Replaces the stock MetSys module (Template/Scripts/Modules/RoomTransitions.gd),
## which does the whole change the instant the player crosses a room boundary: the old
## room is pulled out of the tree, the new one is loaded, and the player is shifted by
## the distance between the two. All of that is on screen, and it takes as many frames
## as the load does, so the seam between two rooms is the one place in the game where
## the machinery shows.
##
## Here the crossing only [i]starts[/i] the change. [RoomTransitionFade] covers the
## screen first, the swap happens while there is nothing to see, and the fade clears
## again on the new room. The player cannot be hurt for any of it, because none of it
## is something they could have reacted to.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

var player: Node2D

## True from the crossing until the new room is up. MetSys reports a room change per
## cell boundary crossed and the player keeps walking while the screen fades, so a
## second report can arrive mid-transition; the swap already in flight is the one that
## counts, and the player's position within the new room is corrected by the swap
## itself either way.
var _transitioning := false

func _initialize() -> void:
	player = game.player
	assert(player)
	MetSys.room_changed.connect(_on_room_changed, CONNECT_DEFERRED)

func _on_room_changed(target_room: String) -> void:
	if target_room == MetSys.get_current_room_name():
		# This can happen when teleporting to another room.
		return
	if _transitioning:
		return

	_transitioning = true
	_set_invulnerable(true)

	GlobalSignals.room_transition.emit()
	await GlobalSignals.room_transition_faded_out

	await _swap_room(target_room)

	_set_invulnerable(false)
	_transitioning = false
	GlobalSignals.room_transition_complete.emit()

## Takes the old room out, brings [param target_room] in, and moves the player by the
## distance between the two rooms' origins so they come out of the boundary where they
## went into it.
func _swap_room(target_room: String) -> void:
	var prev_room_instance := MetSys.get_current_room_instance()
	if prev_room_instance:
		prev_room_instance.get_parent().remove_child(prev_room_instance)

	await game.load_room(target_room)

	if prev_room_instance:
		player.position -= MetSys.get_current_room_instance().get_room_position_offset(prev_room_instance)
		prev_room_instance.queue_free()

func _set_invulnerable(invulnerable: bool) -> void:
	var p := player as Player
	if p == null or not is_instance_valid(p.health):
		return
	p.health.ignore_effects = invulnerable
