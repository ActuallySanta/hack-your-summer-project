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
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var ground_check: ShapeCast2D = $GroundCheck
@onready var physics_body: CollisionShape2D = $"Physics Body"
@onready var target_range_check: ShapeCast2D = $"Target Range Check"

var isFlipped : bool

func _ready() -> void:
	bt_player.blackboard.set_var("canAttack",true)
	hurtbox.hit.connect(takeDamage)

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
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if bt_player.blackboard.get_var("state") == "hurt":
		move_and_slide()
		return
	
	if ground_check.get_collision_count() == 0:
		update_flip(scale.x * -1)
		switch_state("idle")
	
	# Player interactions
	if not player_detection_check.collision_result.find(playerReference):
		move_and_slide()
		return
	
	switch_state(
		"patrolling" if not can_see_player() 
		else "attacking" if target_range_check.collision_result.find(playerReference)
		else "chasing"
	)
	
	move_and_slide()

func getValidPos() -> Vector2:
	var currWanderDistance : float = randf_range(-wanderDistance,wanderDistance)
	target_location_check.target_position.x = currWanderDistance
	
	var collisionPoint : Vector2 = target_location_check.get_collision_point()
	var collisionWidth = (physics_body.shape as CapsuleShape2D).radius
	if target_location_check.is_colliding():
		return collisionPoint + (collisionPoint.direction_to(position) * collisionWidth/2)
	else:
		return Vector2(position.x + currWanderDistance,position.y)
	
func takeDamage(_hurtBox: Hurtbox, _hit_info: HitInfo, _source: Hitbox):
	switch_state("hurt")

func can_see_player() -> bool:
	return player_obstruction_check.is_colliding() and player_obstruction_check.get_collider() == playerReference

func switch_state(state_name: String) -> void:
	bt_player.blackboard.set_var("state", state_name)
	bt_player.restart()
