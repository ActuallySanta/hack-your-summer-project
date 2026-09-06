class_name PlayerComponent
extends Node2D

var player: Player

@export var component_enabled := true

## Called once by the player, from its own [method Node._ready], before anything has
## run a frame. Components must not reach for the player before this.
func bind(owning_player: Player) -> void:
	player = owning_player
	_bind()

## Override for setup that needs [member player]. Runs during the player's _ready().
func _bind() -> void:
	pass

## Runs inside the player's [method Node._physics_process], before [method move_and_slide].
## The order components run in is [member Player.COMPONENT_ORDER].
func physics_update(_delta: float) -> void:
	pass

## Runs inside the player's [method Node._physics_process], after [method move_and_slide],
## when the results of the move (real velocity, floor and wall contact) can be read.
func post_move_update(_delta: float) -> void:
	pass

## Runs inside the player's [method Node._process], for anything that should be as
## smooth as the frame rate rather than tied to the physics step.
func frame_update(_delta: float) -> void:
	pass

## Called when the player is placed rather than moved: a load, or a checkpoint
## respawn. Anything a component is holding mid-action should be dropped here.
func on_respawn() -> void:
	pass
