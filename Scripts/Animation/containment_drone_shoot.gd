@tool
extends Node2D

## The beam is driven entirely off BIGGUNSHOOT's own anim_frame. Do not give
## this node a second timer: the sprite gets paused (pause_sprite_animations)
## and its frame time gets stretched (anim_speed_adjust, which the "accelerate"
## animation ramps 0.2 -> 0.0), and a parallel timer drifts a frame out of sync
## every time either of those happens.

const BRIGHT_STRIP := 0
const DIM_STRIP := 4

@export var reset : bool = false:
	set(value):
		if value == true:
			_last_frame = -1

@onready var tileMapLayer := $Laser
@onready var bright := $Laser/TileMapLayerBright
@onready var dim := $Laser/TileMapLayerDim
@onready var shootSprite := $BIGGUNSHOOT

var offsets := {
	0: 0,
	1: 1,
	2: 0,
	3: -1
}

var _last_frame : int = -1

func _ready() -> void:
	# Godot runs a parent before its children at equal priority; bumping ours
	# puts us after BIGGUNSHOOT so anim_frame is the frame it just moved to.
	process_priority = 1
	_last_frame = -1

func _process(_delta: float) -> void:
	var anim_frame : int = shootSprite.anim_frame
	if anim_frame == _last_frame:
		return
	_last_frame = anim_frame
	
	var glow_brighter := anim_frame % 2 == 0
	shootSprite.set_horizontal_offset(BRIGHT_STRIP if glow_brighter else DIM_STRIP)
	# Re-stamp frame_coords so the strip we just picked lands on this frame
	# instead of the next one the sprite advances to.
	shootSprite.iteration()
	bright.z_index = 1000 if glow_brighter else -1000
	dim.z_index = -1000 if glow_brighter else 1000
	tileMapLayer.position.y = offsets.get(anim_frame, 0)
