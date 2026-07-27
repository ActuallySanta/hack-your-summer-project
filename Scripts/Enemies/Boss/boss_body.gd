extends Node3D

@onready var top_foot: MeshInstance3D = $"Top Foot"
@onready var bottom_foot: MeshInstance3D = $"Bottom Foot"
@onready var top_leg_joint: MeshInstance3D = $"Top Leg Joint"
@onready var bottom_leg_joint: MeshInstance3D = $"Bottom Leg Joint"

@export var Limbs : Array[Node3D]

@export var xMoveAmp : float = .5
@export var xMoveFreq : float = 2.5

@export var yMoveAmp : float = .25
@export var yMoveFreq : float = 1.25

@export var randVariance : float = 1.5

var moveTimer := 0.0
func _process(delta: float) -> void:
	#Move the body parts
	moveTimer+= delta
	
	for i in Limbs.size():
		var xPos : float = sin((moveTimer+i+1)*xMoveFreq) *xMoveAmp
		var yPos : float = sin((moveTimer+i+1)*yMoveFreq) *yMoveAmp
		Limbs[i].position.x = xPos
		Limbs[i].position.y = yPos
		
