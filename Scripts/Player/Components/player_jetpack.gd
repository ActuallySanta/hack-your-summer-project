## The jetpack.
##
## [b]Its own key.[/b] It used to fire on Jump, which meant the two could never be
## told apart: a jump at a ledge fired the jetpack, and a jetpack burst near a ledge
## tried to vault. It now runs on its own action ([member thrust_action], bound to
## Ctrl), so mantling and thrusting are separate decisions the player gets to make.
##
## [b]Its own look.[/b] Thrusting asks the animator for [code]jetpack[/code], which is
## a frame of the character sheet like everything else. There used to be a second
## sprite worn over the player for the pack itself; the sheet draws it now.
class_name PlayerJetpack
extends PlayerComponent

signal thrust_started
signal thrust_stopped

@export_group("Thrust")
## Input action that fires the jetpack. Deliberately not Jump.
@export var thrust_action: StringName = &"Jetpack"
## Upward acceleration at a standstill, before drag.
@export var net_acceleration := 1800.0
## Speed the thrust fades out at, so the climb tops out rather than running away.
@export var max_speed := 800.0

@export_group("Animation")
@export var thrust_animation: StringName = &"jetpack"

var _unlocked := false
## Held off by something in the world (a ladder) without touching the unlock, so
## leaving that thing cannot hand the player a jetpack they never picked up.
var _suppressed := false
var _thrusting := false

func _bind() -> void:
	set_unlocked(false)

## Whether the player has the jetpack at all.
func is_unlocked() -> bool:
	return _unlocked

func set_unlocked(unlocked: bool) -> void:
	_unlocked = unlocked
	if not unlocked:
		_stop()

func is_thrusting() -> bool:
	return _thrusting

## Holds the jetpack off without forgetting that the player owns one.
func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed
	if suppressed:
		_stop()

func physics_update(delta: float) -> void:
	var wanted := _unlocked and not _suppressed and component_enabled and player.can_act() \
		and Input.is_action_pressed(thrust_action)

	if wanted != _thrusting:
		_thrusting = wanted
		if wanted:
			thrust_started.emit()
		else:
			thrust_stopped.emit()

	if not _thrusting:
		return

	# Thrust minus the drag it gains as it approaches max_speed, on top of gravity so
	# the number in the inspector is the net climb rather than a figure gravity has
	# already taken a bite out of.
	var drag := -player.velocity.y / max_speed
	player.velocity.y -= (player.get_gravity().y + net_acceleration * (1.0 - drag)) * delta

func _stop() -> void:
	if not _thrusting:
		return
	_thrusting = false
	thrust_stopped.emit()

func on_respawn() -> void:
	_stop()
