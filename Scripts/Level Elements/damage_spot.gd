class_name DamageSpot
extends Node2D

## A patch of ground that keeps hurting whatever is standing in it.
##
## It used to call [method Hitbox.reset] every physics frame, on the reasoning that
## clearing the "already hit" list would let the hit land again. It does not:
## [signal Area2D.area_entered] only fires when a target [i]arrives[/i], so something
## standing still in the spot was hurt exactly once and then stood there safely.
## [member Hitbox.hit_cooldown] is the working version of the same idea -- the hitbox
## sweeps what is inside it and re-arms each target on a timer.

## How often a target standing in the spot is hurt, in seconds.
@export var damage_interval := 0.5

@onready var hitbox := $Hitbox as Hitbox

func _ready() -> void:
	hitbox.hit_cooldown = damage_interval
