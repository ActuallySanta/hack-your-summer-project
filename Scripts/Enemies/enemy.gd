class_name Enemy
extends CharacterBody2D

const SPEED:float = 50

@export var attackCooldown: float = 1.5
@export var wanderDistance : float = 50.0
@export var stunDuration : float = 2.5

@onready var mainScene : Node = get_tree().current_scene
@onready var visual: Sprite2D = $Visual
@onready var player_detection_check: ShapeCast2D = $"Player Detection Check"
@onready var player_obstruction_check: RayCast2D = $"Player Obstruction Check"
@onready var playerReference : CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var target_location_check: RayCast2D = $"Target Location Check"
@onready var bt_player: BTPlayer = $BTPlayer

var isFlipped : bool

func _ready() -> void:
	bt_player.blackboard.set_var("canAttack",true)

func move(targetPos : Vector2, delta :float):
	var dir : Vector2 = Vector2(targetPos.x - global_position.x,0).normalized()
	
	velocity.x = dir.x * SPEED
	update_flip(dir.x)

func update_flip(dir:float):
	var doFlip : bool = dir<0
	if(doFlip != isFlipped):
		scale.x =-1
	else:
		scale.x = 1
	isFlipped = doFlip

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if(player_detection_check.collision_result.find(playerReference)):
		if(player_obstruction_check.is_colliding() && player_obstruction_check.get_collider() == playerReference):
			bt_player.blackboard.set_var("state","attacking")
			bt_player.restart()
		else:
			bt_player.blackboard.set_var("state","patrolling")
	
	move_and_slide()

func getValidPos() -> Vector2:
	
	var currWanderDistance : float = randf_range(-wanderDistance,wanderDistance)
	target_location_check.target_position.x = currWanderDistance
	
	var collisionPoint:Vector2 = target_location_check.get_collision_point()
	
	if(target_location_check.is_colliding()):
		return  collisionPoint + collisionPoint.direction_to(position)
	else:
		return Vector2(position.x + currWanderDistance,position.y)
	
	return Vector2.ZERO
