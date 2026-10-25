extends Node

## Emitted when [member facesForward] is switched on or off.
signal faces_forward_changed(on: bool)

var player : Player
var inDialogue: bool = false
var canMove : bool = true
var canAttack : bool = true

## Turns the player to face the camera and holds them there: no moving, no attacking,
## and the forward-facing frame shown over every other look the player has.
##
## A lock of its own rather than another way of setting [member canMove] or
## [member canAttack], so whatever else changes those while it is on -- a menu handing
## canMove back, a room transition -- cannot let the player loose early. Switching it
## off lifts only this lock; if nothing else is holding the player, they can move again.
##
## Only ever set from code: nothing the player presses turns it on or off.
var facesForward : bool = false:
	set(value):
		if value == facesForward:
			return
		facesForward = value
		faces_forward_changed.emit(value)
