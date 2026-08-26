## Base for every piece of the player that used to be a region of player.gd.
##
## The player is the manager: it owns the shared state (inputs, move state, facing,
## the collider swap) and calls into its components in a fixed order each physics
## frame. A component owns one behaviour and nothing else, reads the player for the
## state it needs, and writes back only through the player's own API.
##
## Components are found by type rather than by node name, so re-ordering or renaming
## them in the scene changes nothing, and a component that is simply deleted from the
## scene takes its whole feature out with it -- see [method Player.get_component].
##
## [Node2D] rather than [Node] because several of them need a transform (the mantle's
## stand-in sprite, the health component's hurtbox); the ones that do not pay nothing
## for having one.
class_name PlayerComponent
extends Node2D

## The player this component belongs to. Set by [method bind] before any of the
## update hooks run, so it is safe to read from all of them.
var player: Player

## Whether this component does anything. A disabled component keeps its state but is
## skipped by every update hook, which is how a feature is switched off for testing
## without taking the node out of the scene.
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
