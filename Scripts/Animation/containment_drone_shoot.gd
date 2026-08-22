@tool
extends Node2D

@export var reset : bool = false:
	set(value):
		if value == true:
			glow_brighter = 0
			timer = 0

@onready var tileMapLayer := $Laser
@onready var bright := $Laser/TileMapLayerBright
@onready var dim := $Laser/TileMapLayerDim
@onready var shootSprite := $BIGGUNSHOOT

var timer : float
var glow_brighter : bool = false

var offsets := {
	0: 1,
	1: 0,
	2: -1,
	3: 0
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer = 0

func _process(delta: float) -> void:
	timer -= delta
	while timer < 0:
		glow_brighter = !glow_brighter
		shootSprite.set_horizontal_offset(0 if glow_brighter else 4)
		bright.z_index = 1000 if glow_brighter else -1000
		dim.visible = -1000 if glow_brighter else 1000
		tileMapLayer.position.y = offsets[ shootSprite.anim_frame ]
		timer += shootSprite.ANIM_FRAME_SECONDS
