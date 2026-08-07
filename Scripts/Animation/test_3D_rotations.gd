extends Node3D

@onready var top_arm_target: Node3D = $"../Top Arm Target"
@onready var bottom_arm_target: Node3D = $"../Bottom Arm Target"

@export var moveAmpY : float = .25
@export var moveAmpX : float = .15
@export var ampMax : float = .35
@export var moveFreq : float
var moveTimer : float = 0.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	moveFreq = randf_range(0,moveFreq)
	moveAmpX = randf_range(moveAmpX,ampMax)
	moveAmpY = randf_range(moveAmpY,ampMax)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	moveTimer+=delta
	bottom_arm_target.position.y = moveAmpY*sin(moveTimer/moveFreq)
	bottom_arm_target.position.x = -moveAmpX*sin(moveTimer/moveFreq)
	
	top_arm_target.position.y = -moveAmpY*sin(moveTimer/moveFreq)
	top_arm_target.position.x = moveAmpX*sin(moveTimer/moveFreq)
	
	rotation.x+=delta*randf_range(1,2.5)
	rotation.z += delta*randf_range(1,2.5)
	pass
