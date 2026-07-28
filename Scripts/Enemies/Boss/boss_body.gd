extends Node3D

@onready var camera_3d: Camera3D = $Camera3D

@export var Limbs : Array[Node3D]
var limbDir : Array = [1,-1,1,-1]

@export var xMoveAmp : float = .5
@export var xMoveFreq : float = 2.5

@export var yMoveAmp : float = .25
@export var yMoveFreq : float = 1.25

@export var bodyMoveAmp: float = .25
@export var bodyMoveFreq: float = 1


var moveTimer := 0.0
func _process(delta: float) -> void:
	#Move the body parts
	moveTimer+= delta
	
	for i in Limbs.size():
		var xPos : float = sin(limbDir[i]*(moveTimer+i+1)*xMoveFreq) *xMoveAmp
		var yPos : float = sin((limbDir[i]*-1)*(moveTimer+i+1)*yMoveFreq) *yMoveAmp
		Limbs[i].position.x = xPos
		Limbs[i].position.y = yPos
	
	self.global_position.x = sin(moveTimer*bodyMoveFreq)*bodyMoveAmp
	print(global_position.x)
