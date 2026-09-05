class_name Enemy
extends CharacterBody2D

const SPEED:float = 50

@export var attackCooldown: float = 1.5
@export var wanderDistance : float = 50.0
@export var stunDuration : float = 2.5
@export var health_component : HealthComponent
@export var hurtbox: Hurtbox
@onready var mainScene : Node = get_tree().current_scene
@onready var visual: Sprite2D = $Flasher/Visual
@onready var flasher : Flasher = $Flasher
@onready var player_detection_check: ShapeCast2D = $"Player Detection Check"
@onready var player_obstruction_check: RayCast2D = $"Player Obstruction Check"
@onready var playerReference : CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var target_location_check: RayCast2D = $"Target Location Check"
@onready var bt_player: BTPlayer = $BTPlayer
@onready var ground_check: ShapeCast2D = $GroundCheck
@onready var physics_body: CollisionShape2D = $"Physics Body"
@onready var target_range_check: ShapeCast2D = $"Target Range Check"

var isFlipped : bool

func get_dir() -> StringName:
	return "L" if isFlipped else "R"

func _ready() -> void:
	bt_player.blackboard.set_var("canAttack",true)
	hurtbox.hit.connect(takeDamage)

func move(targetPos : Vector2, delta :float):
	var dir : Vector2 = Vector2(targetPos.x - global_position.x,0).normalized()
	
	velocity.x = dir.x * SPEED
	update_flip(dir.x)

func update_flip(dir:float):
	if is_zero_approx(dir):
		return # No direction requested, keep the current facing
	isFlipped = dir < 0
	# A mirrored Node2D is stored back as rotation PI with a negative Y scale, so both
	# have to be rewritten - setting scale.x alone turns the body 180 degrees instead
	rotation = 0
	scale = Vector2(-1.0 if isFlipped else 1.0, 1.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if bt_player.blackboard.get_var("state") == "hurt":
		move_and_slide()
		return
	
	switch_state(read_state())
	move_and_slide()

func read_state() -> String:
	if not can_see_player():
		return "patrolling"
	target_range_check.force_shapecast_update()
	return "attacking" if shapeCast_hit_playerRef(target_range_check) else "chasing"

func has_ground_ahead() -> bool:
	ground_check.force_shapecast_update() # A cast that just entered the tree has no result yet
	return ground_check.get_collision_count() > 0

func get_patrol_target() -> Vector2:
	var distance : float = randf_range(wanderDistance * 0.5, wanderDistance)

	# The cast is a child of a body that mirrors itself to turn, so a positive local
	# target_position.x always points the way the enemy is facing
	target_location_check.target_position.x = distance
	target_location_check.force_raycast_update()

	var reach : float = distance
	if target_location_check.is_colliding():
		var body_radius : float = (physics_body.shape as CapsuleShape2D).radius
		var wall_gap : float = absf(target_location_check.get_collision_point().x - global_position.x)
		reach = maxf(wall_gap - body_radius, 0.0)

	var facing : float = -1.0 if isFlipped else 1.0
	return Vector2(global_position.x + facing * reach, global_position.y)

func takeDamage(_hurtBox: Hurtbox, _hit_info: HitInfo, source: Hitbox):
	if source.has_method("get_damage_type"):
		var dmg_type : StringName = source.get_damage_type()
		if dmg_type == "stun_bullet":
			switch_state("hurt")
			return
	flasher.flash()

func can_see_player() -> bool:
	return player_obstruction_check.is_colliding() and player_obstruction_check.get_collider() == playerReference

func shapeCast_hit_playerRef(variable: ShapeCast2D) -> bool:
	if variable.collision_result.size() < 1:
		return false
	
	var playerRID = playerReference.get_rid()
	for collision in variable.collision_result:
		if collision[ "rid" ] == playerRID:
			return true
		
	return false

func switch_state(state_name: String) -> void:
	bt_player.blackboard.set_var("state", state_name)
